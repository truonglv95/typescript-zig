const std = @import("std");
const builtin = @import("builtin");

// ---------------------------------------------------------------------------
// fsevents_darwin.zig: macOS FSEvents backend (event processing)
// ---------------------------------------------------------------------------

const ffi = @import("fsevents_darwin_ffi.zig");
const watcher = @import("watcher.zig"); // Assuming watcherBase is here

pub const flagMustScanSubDirs: u32 = 0x00000001;
pub const flagUserDropped: u32 = 0x00000002;
pub const flagKernelDropped: u32 = 0x00000004;
pub const flagHistoryDone: u32 = 0x00000010;

pub const flagItemCreated: u32 = 0x00000100;
pub const flagItemRemoved: u32 = 0x00000200;
pub const flagItemInodeMetaMod: u32 = 0x00000400;
pub const flagItemRenamed: u32 = 0x00000800;
pub const flagItemModified: u32 = 0x00001000;
pub const flagItemFinderInfoMod: u32 = 0x00002000;
pub const flagItemChangeOwner: u32 = 0x00004000;
pub const flagItemXattrMod: u32 = 0x00008000;
pub const flagItemIsFile: u32 = 0x00010000;
pub const flagItemIsDir: u32 = 0x00020000;
pub const flagItemIsSymlink: u32 = 0x00040000;
pub const flagItemIsHardlink: u32 = 0x00100000;
pub const flagItemIsLastHardlink: u32 = 0x00200000;
pub const flagItemCloned: u32 = 0x00400000;

pub const cfStringEncodingUTF8: u32 = 0x08000100;

pub const eventIDSinceNow: u64 = 0xFFFFFFFFFFFFFFFF;

pub const ignoredFlags: u32 = flagItemIsHardlink | flagItemIsLastHardlink |
    flagItemIsSymlink | flagItemIsDir | flagItemIsFile | flagItemCloned;

pub const FsEventStreamContext = extern struct {
    version: isize,
    info: usize,
    retain: usize,
    release: usize,
    copyDescription: usize,
};

pub const FseventsState = struct {
    stream: std.atomic.Value(usize),
    cb: ?*ffi.StreamCallback,
};

pub const FsEventsBackend = struct {
    base: watcher.WatcherBase,

    pub fn init() FsEventsBackend {
        var b = FsEventsBackend{
            .base = undefined,
        };
        b.base.init(&b);
        return b;
    }

    pub fn start(self: *@This()) !void {
        self.base.notifyStarted();
    }

    pub fn startStream(self: *@This(), w: *watcher.DirWatch, since: u64) !void {
        if (checkWatcher(w)) |err| return err;

        var state = w.state.cast(FseventsState) orelse return error.MissingFSEventsState;

        const dir_c_str = try w.dir.cloneWithNull(self.base.allocator);
        defer self.base.allocator.free(dir_c_str);

        const cf_dir = ffi.cfStringCreate(0, @ptrCast(dir_c_str.ptr), cfStringEncodingUTF8);
        defer ffi.cfRelease(cf_dir);

        const paths_to_watch = ffi.cfArrayCreate(0, @ptrCast(&cf_dir), 1, 0);
        defer ffi.cfRelease(paths_to_watch);

        const cb = try ffi.StreamCallback.create(w, self.base.allocator);
        state.cb = cb;

        var ctx = FsEventStreamContext{
            .version = 0,
            .info = @intFromPtr(cb),
            .retain = 0,
            .release = 0,
            .copyDescription = 0,
        };

        const stream = ffi.fsEventStreamCreate(
            0,
            ffi.fsEventsCallbackAsmAddr,
            @ptrCast(&ctx),
            paths_to_watch,
            since,
            0.001,
        );

        if (stream == 0) {
            cb.close();
            state.cb = null;
            return error.StreamCreateNull;
        }

        ffi.fsEventStreamSetDispatchQueue(stream, cb.queue);
        if (ffi.fsEventStreamStart(stream) == 0) {
            ffi.fsEventStreamInvalidate(stream);
            ffi.fsEventStreamRelease(stream);
            cb.close();
            state.cb = null;
            return error.StreamStartFailed;
        }
        ffi.fsEventStreamFlushSync(stream);
        state.stream.store(stream, .seq_cst);
    }

    pub fn stopStream(self: *@This(), state: ?*FseventsState) void {
        _ = self;
        if (state == null) return;
        const s = state.?;
        const stream = s.stream.swap(0, .seq_cst);
        if (stream == 0) return;
        const cb = s.cb;
        teardownStream(stream, cb);
        s.cb = null;
    }

    pub fn subscribe(self: *@This(), w: *watcher.DirWatch) !void {
        const state = try self.base.allocator.create(FseventsState);
        state.* = .{
            .stream = std.atomic.Value(usize).init(0),
            .cb = null,
        };
        w.state = watcher.StatePtr.init(state);
        try self.startStream(w, eventIDSinceNow);
    }

    pub fn closeWatch(self: *@This(), w: *watcher.DirWatch) !void {
        const state = w.state.cast(FseventsState);
        w.state = watcher.StatePtr.null_ptr;
        if (state) |s| {
            self.stopStream(s);
            self.base.allocator.destroy(s);
        }
    }
};

pub fn checkWatcher(w: *watcher.DirWatch) !void {
    const stat = std.fs.cwd().statFile(w.dir) catch |err| {
        return err;
    };
    if (stat.kind != .directory) {
        return error.NotDir;
    }
}

pub fn teardownStream(stream: usize, cb: ?*ffi.StreamCallback) void {
    ffi.fsEventStreamStop(stream);
    if (cb) |c| {
        ffi.fsEventStreamInvalidate(stream);
        c.waitDispatchQueue();
        c.close();
    } else {
        ffi.fsEventStreamInvalidate(stream);
    }
    ffi.fsEventStreamRelease(stream);
}

pub fn fsEventsCallback(cb: *ffi.StreamCallback, payload: ?*ffi.FsEventsCallbackPayload) void {
    defer if (payload) |p| p.close();

    if (cb.closed.load(.seq_cst)) {
        return;
    }

    if (payload == null or payload.?.paths == 0 or payload.?.flags == 0) {
        return;
    }

    const p = payload.?;
    const numEvents = p.numEvents;
    const paths = p.paths;
    const flags = p.flags;

    const w = cb.dirWatch;
    var deletedRoot = false;

    var i: usize = 0;
    while (i < numEvents) : (i += 1) {
        const flag_ptr = @as(*u32, @ptrFromInt(flags + i * @sizeOf(u32)));
        const flag = flag_ptr.*;

        const pathRef = ffi.cfArrayGetValueAtIndex(paths, i);
        const path = ffi.cfStringToNFC(pathRef, w.allocator) catch "";
        defer if (path.len > 0) w.allocator.free(path);

        if (path.len == 0) {
            continue;
        }

        const isRemoved = (flag & flagItemRemoved) != 0;
        const isRenamed = (flag & flagItemRenamed) != 0;
        const isCreated = (flag & flagItemCreated) != 0;
        const isDone = (flag & flagHistoryDone) != 0;

        if ((flag & flagMustScanSubDirs) != 0) {
            if ((flag & flagUserDropped) != 0) {
                w.events.setError(error.FSEventsUserDropped);
            } else if ((flag & flagKernelDropped) != 0) {
                w.events.setError(error.FSEventsKernelDropped);
            } else {
                w.events.setError(error.FSEventsTooMany);
            }
        }

        if (isDone) {
            w.notify();
            break;
        }

        if ((flag & ~ignoredFlags) == 0) {
            continue;
        }

        if (std.mem.eql(u8, path, w.dir) and !isRemoved and !isRenamed) {
            continue;
        }

        if (isRemoved and !isCreated) {
            w.events.remove(path);
            if (std.mem.eql(u8, path, w.dir)) {
                deletedRoot = true;
            }
        } else if (isRenamed or (isRemoved and isCreated)) {
            _ = std.fs.cwd().statFile(path) catch {
                w.events.remove(path);
                if (std.mem.eql(u8, path, w.dir)) {
                    deletedRoot = true;
                }
                continue;
            };
            w.events.update(path);
        } else {
            w.events.update(path);
        }
    }

    if (deletedRoot) {
        w.events.setError(error.WatchTerminated);
    }

    w.notify();

    if (deletedRoot) {
        cb.closed.store(true, .seq_cst);
    }
}
