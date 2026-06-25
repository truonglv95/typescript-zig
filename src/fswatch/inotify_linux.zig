const std = @import("std");
const os = std.os;
const posix = std.posix;
const linux = std.os.linux;

const fswatch = @import("fswatch.zig"); // Assuming base definitions are here
// Note: You may need to adjust these imports and aliases depending on your base fswatch structure.

const inotifyMask: u32 = linux.IN.CREATE |
    linux.IN.DELETE |
    linux.IN.DELETE_SELF |
    linux.IN.MODIFY |
    linux.IN.MOVE_SELF |
    linux.IN.MOVED_FROM |
    linux.IN.MOVED_TO |
    linux.IN.DONT_FOLLOW |
    linux.IN.ONLYDIR |
    linux.IN.EXCL_UNLINK;

const inotifyBufferSize = 8192;

pub const inotifySubscription = struct {
    path: []const u8,
    dirWatch: *fswatch.dirWatch,
    wd: i32,
};

pub const inotifyBackend = struct {
    base: fswatch.watcherBase,

    pipeFDs: [2]i32,
    pipeWriteFD: std.atomic.Value(i32),
    inotify: i32,
    subscriptions: std.AutoHashMap(i32, std.ArrayList(*inotifySubscription)),
    endedSignal: std.Thread.ResetEvent,

    readBuf: []u8,
    watchersTouched: std.AutoHashMap(*fswatch.dirWatch, void),
    
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*inotifyBackend {
        var b = try allocator.create(inotifyBackend);
        b.* = .{
            .base = fswatch.watcherBase.init(b),
            .pipeFDs = .{ -1, -1 },
            .pipeWriteFD = std.atomic.Value(i32).init(-1),
            .inotify = -1,
            .subscriptions = std.AutoHashMap(i32, std.ArrayList(*inotifySubscription)).init(allocator),
            .endedSignal = std.Thread.ResetEvent{},
            .readBuf = try allocator.alloc(u8, inotifyBufferSize),
            .watchersTouched = std.AutoHashMap(*fswatch.dirWatch, void).init(allocator),
            .allocator = allocator,
        };
        return b;
    }

    pub fn start(b: *inotifyBackend) !void {
        try posix.pipe2(&b.pipeFDs, posix.O.CLOEXEC | posix.O.NONBLOCK);
        b.pipeWriteFD.store(b.pipeFDs[1], .seq_cst);
        
        defer {
            b.closeFDs();
            b.endedSignal.set();
        }

        b.inotify = try posix.inotify_init1(linux.IN.NONBLOCK | linux.IN.CLOEXEC);

        var pollfds = [_]posix.pollfd{
            .{ .fd = b.pipeFDs[0], .events = posix.POLL.IN, .revents = 0 },
            .{ .fd = b.inotify, .events = posix.POLL.IN, .revents = 0 },
        };

        b.base.notifyStarted();

        while (true) {
            const num_events = posix.poll(&pollfds, 500) catch |err| switch (err) {
                error.SignalInterrupt => continue,
                else => return err,
            };
            if (num_events == 0) continue;

            if (pollfds[0].revents != 0) {
                break;
            }
            if (pollfds[1].revents != 0) {
                try b.handleEvents();
            }
        }
    }

    pub fn closeFDs(b: *inotifyBackend) void {
        b.base.mu.lock();
        defer b.base.mu.unlock();

        if (b.pipeFDs[0] >= 0) {
            posix.close(b.pipeFDs[0]);
            b.pipeFDs[0] = -1;
        }
        const fd = b.pipeWriteFD.swap(-1, .seq_cst);
        if (fd >= 0) {
            posix.close(fd);
        }
        b.pipeFDs[1] = -1;
        if (b.inotify >= 0) {
            posix.close(b.inotify);
            b.inotify = -1;
        }
    }

    pub fn shutdown(b: *inotifyBackend) void {
        const fd = b.pipeWriteFD.load(.seq_cst);
        if (fd < 0) return;
        _ = posix.write(fd, "X") catch {};
        b.endedSignal.wait();
    }

    pub fn subscribe(b: *inotifyBackend, w: *fswatch.dirWatch) !void {
        if (!w.recursive) {
            _ = try b.watchDir(w, w.dir);
            return;
        }
        
        try fswatch.walkDir(w.dir, true, struct {
            b: *inotifyBackend,
            w: *fswatch.dirWatch,
            pub fn call(self: @This(), path: []const u8, isDir: bool) !void {
                if (!isDir) return;
                _ = try self.b.watchDir(self.w, path);
            }
        }{ .b = b, .w = w });
    }

    pub fn watchDir(b: *inotifyBackend, w: *fswatch.dirWatch, path: []const u8) !i32 {
        const wd = try posix.inotify_add_watch(b.inotify, path, inotifyMask);
        const sub = try b.allocator.create(inotifySubscription);
        sub.* = .{ .path = try b.allocator.dupe(u8, path), .dirWatch = w, .wd = wd };
        
        var entry = try b.subscriptions.getOrPut(wd);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(*inotifySubscription).init(b.allocator);
        }
        try entry.value_ptr.append(sub);
        return wd;
    }

    pub fn handleEvents(b: *inotifyBackend) !void {
        while (true) {
            const n = posix.read(b.inotify, b.readBuf) catch |err| switch (err) {
                error.WouldBlock => break,
                else => return err,
            };
            if (n == 0) break;

            var offset: usize = 0;
            while (offset < n) {
                const ev = @as(*align(1) linux.inotify_event, @ptrCast(&b.readBuf[offset]));
                const recordSize = @sizeOf(linux.inotify_event) + ev.len;
                var name: []const u8 = "";
                
                if (ev.len > 0) {
                    const nameBytes = b.readBuf[offset + @sizeOf(linux.inotify_event) .. offset + recordSize];
                    var nameLen: usize = 0;
                    while (nameLen < ev.len and nameBytes[nameLen] != 0) {
                        nameLen += 1;
                    }
                    name = nameBytes[0..nameLen];
                }

                if ((ev.mask & linux.IN.Q_OVERFLOW) != 0) {
                    b.base.mu.lock();
                    var it = b.subscriptions.valueIterator();
                    while (it.next()) |subs| {
                        for (subs.items) |sub| {
                            sub.dirWatch.events.setError(fswatch.ErrOverflow);
                            try b.watchersTouched.put(sub.dirWatch, {});
                        }
                    }
                    b.base.mu.unlock();
                    offset += recordSize;
                    continue;
                }

                try b.handleEvent(ev, name);
                offset += recordSize;
            }
        }
        
        var touchedIt = b.watchersTouched.keyIterator();
        while (touchedIt.next()) |w| {
            w.*.notify();
        }
        b.watchersTouched.clearRetainingCapacity();
    }

    fn handleEvent(b: *inotifyBackend, ev: *align(1) linux.inotify_event, name: []const u8) !void {
        b.base.mu.lock();
        defer b.base.mu.unlock();

        if (b.subscriptions.getPtr(ev.wd)) |subs| {
            for (subs.items) |s| {
                if (try b.handleSubscription(ev, name, s)) {
                    try b.watchersTouched.put(s.dirWatch, {});
                }
            }
        }
    }

    fn handleSubscription(b: *inotifyBackend, ev: *align(1) linux.inotify_event, name: []const u8, sub: *inotifySubscription) !bool {
        const w = sub.dirWatch;
        var path = sub.path;
        var allocated_path: ?[]u8 = null;
        defer if (allocated_path) |p| b.allocator.free(p);

        const isDir = (ev.mask & linux.IN.ISDIR) != 0;
        if (name.len > 0) {
            allocated_path = try std.fmt.allocPrint(b.allocator, "{s}/{s}", .{path, name});
            path = allocated_path.?;
        }

        if ((ev.mask & (linux.IN.CREATE | linux.IN.MOVED_TO)) != 0) {
            w.events.create(path);
            if (isDir and w.recursive) {
                try fswatch.walkDir(path, true, struct {
                    b: *inotifyBackend,
                    w: *fswatch.dirWatch,
                    pub fn call(self: @This(), p: []const u8, pIsDir: bool) !void {
                        if (!pIsDir) return;
                        _ = try self.b.watchDir(self.w, p);
                    }
                }{ .b = b, .w = w });
            }
        } else if ((ev.mask & linux.IN.MODIFY) != 0) {
            w.events.update(path);
        } else if ((ev.mask & (linux.IN.DELETE | linux.IN.DELETE_SELF | linux.IN.MOVED_FROM | linux.IN.MOVE_SELF)) != 0) {
            const isSelfEvent = (ev.mask & (linux.IN.DELETE_SELF | linux.IN.MOVE_SELF)) != 0;
            if (isSelfEvent and !std.mem.eql(u8, path, w.dir)) {
                return false;
            }
            if (isSelfEvent or isDir) {
                var removal_it = b.subscriptions.iterator();
                var to_delete = std.ArrayList(i32).init(b.allocator);
                defer to_delete.deinit();

                while (removal_it.next()) |entry| {
                    const wd = entry.key_ptr.*;
                    const list = entry.value_ptr;
                    var kept = std.ArrayList(*inotifySubscription).init(b.allocator);
                    for (list.items) |s| {
                        if (std.mem.eql(u8, s.path, path) or (s.path.len > path.len and s.path[path.len] == '/' and std.mem.eql(u8, s.path[0..path.len], path))) {
                            // Drop
                        } else {
                            try kept.append(s);
                        }
                    }
                    if (kept.items.len == 0) {
                        posix.inotify_rm_watch(b.inotify, wd) catch {};
                        try to_delete.append(wd);
                        list.deinit();
                        kept.deinit();
                    } else {
                        list.deinit();
                        entry.value_ptr.* = kept;
                    }
                }
                for (to_delete.items) |wd| {
                    _ = b.subscriptions.remove(wd);
                }
            }
            w.events.remove(path);
            if (isSelfEvent and std.mem.eql(u8, path, w.dir)) {
                w.events.setError(fswatch.ErrWatchTerminated);
            }
        }
        return true;
    }

    pub fn closeWatch(b: *inotifyBackend, w: *fswatch.dirWatch) !void {
        var firstErr: ?anyerror = null;
        var to_delete = std.ArrayList(i32).init(b.allocator);
        defer to_delete.deinit();

        var it = b.subscriptions.iterator();
        while (it.next()) |entry| {
            const wd = entry.key_ptr.*;
            const list = entry.value_ptr;
            
            var kept = std.ArrayList(*inotifySubscription).init(b.allocator);
            var removedAny = false;
            for (list.items) |s| {
                if (s.dirWatch == w) {
                    removedAny = true;
                } else {
                    try kept.append(s);
                }
            }
            if (!removedAny) {
                kept.deinit();
                continue;
            }
            if (kept.items.len == 0) {
                posix.inotify_rm_watch(b.inotify, wd) catch |err| {
                    if (firstErr == null) {
                        firstErr = err;
                    }
                };
                try to_delete.append(wd);
                list.deinit();
                kept.deinit();
            } else {
                list.deinit();
                entry.value_ptr.* = kept;
            }
        }
        for (to_delete.items) |wd| {
            _ = b.subscriptions.remove(wd);
        }
        if (firstErr) |e| return e;
    }
};
