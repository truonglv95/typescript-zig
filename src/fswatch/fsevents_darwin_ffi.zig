const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

// ---------------------------------------------------------------------------
// fsevents_darwin_ffi.zig: macOS FSEvents backend FFI
// ---------------------------------------------------------------------------

const watcher = @import("watcher.zig");

extern fn syscall_syscall6(fn_addr: usize, a1: usize, a2: usize, a3: usize, a4: usize, a5: usize, a6: usize) struct { r1: usize, r2: usize, err: usize };

pub var fse_CFRelease_trampoline_addr: usize = 0;
pub fn cfRelease(ref: usize) void {
    _ = syscall_syscall6(fse_CFRelease_trampoline_addr, ref, 0, 0, 0, 0, 0);
}

pub var fse_CFStringCreateWithCString_trampoline_addr: usize = 0;
pub fn cfStringCreate(allocator: usize, cstr: ?*const anyopaque, encoding: u32) usize {
    const ret = syscall_syscall6(fse_CFStringCreateWithCString_trampoline_addr, allocator, @intFromPtr(cstr), encoding, 0, 0, 0);
    return ret.r1;
}

pub var fse_CFArrayCreate_trampoline_addr: usize = 0;
pub fn cfArrayCreate(allocator: usize, values: ?*const anyopaque, count: usize, callbacks: usize) usize {
    const ret = syscall_syscall6(fse_CFArrayCreate_trampoline_addr, allocator, @intFromPtr(values), count, callbacks, 0, 0);
    return ret.r1;
}

pub var fse_CFArrayGetValueAtIndex_trampoline_addr: usize = 0;
pub fn cfArrayGetValueAtIndex(array: usize, index: usize) usize {
    const ret = syscall_syscall6(fse_CFArrayGetValueAtIndex_trampoline_addr, array, index, 0, 0, 0, 0);
    return ret.r1;
}

pub const cfStringNormalizationFormC = 2;

pub var fse_CFStringCreateMutableCopy_trampoline_addr: usize = 0;
pub fn cfStringCreateMutableCopy(allocator: usize, maxLength: usize, str: usize) usize {
    const ret = syscall_syscall6(fse_CFStringCreateMutableCopy_trampoline_addr, allocator, maxLength, str, 0, 0, 0);
    return ret.r1;
}

pub var fse_CFStringNormalize_trampoline_addr: usize = 0;
pub fn cfStringNormalize(mutStr: usize, form: usize) void {
    _ = syscall_syscall6(fse_CFStringNormalize_trampoline_addr, mutStr, form, 0, 0, 0, 0);
}

pub var fse_CFStringGetLength_trampoline_addr: usize = 0;
pub fn cfStringGetLength(str: usize) usize {
    const ret = syscall_syscall6(fse_CFStringGetLength_trampoline_addr, str, 0, 0, 0, 0, 0);
    return ret.r1;
}

pub var fse_CFStringGetMaximumSizeForEncoding_trampoline_addr: usize = 0;
pub fn cfStringGetMaximumSizeForEncoding(length: usize, encoding: u32) usize {
    const ret = syscall_syscall6(fse_CFStringGetMaximumSizeForEncoding_trampoline_addr, length, encoding, 0, 0, 0, 0);
    return ret.r1;
}

pub var fse_CFStringGetCString_trampoline_addr: usize = 0;
pub fn cfStringGetCString(str: usize, buf: ?*anyopaque, bufSize: usize, encoding: u32) bool {
    const ret = syscall_syscall6(fse_CFStringGetCString_trampoline_addr, str, @intFromPtr(buf), bufSize, encoding, 0, 0);
    return ret.r1 != 0;
}

pub fn isASCII(s: []const u8) bool {
    for (s) |b| {
        if (b >= 0x80) return false;
    }
    return true;
}

pub fn cfStringToNFC(src: usize, allocator: std.mem.Allocator) ![]const u8 {
    if (src == 0) return allocator.alloc(u8, 0);
    if (try cfStringNormalizedToGo(src, allocator)) |s| {
        return s;
    }
    return cfStringToGo(src, allocator);
}

pub fn cfStringNormalizedToGo(src: usize, allocator: std.mem.Allocator) !?[]const u8 {
    const mut = cfStringCreateMutableCopy(0, 0, src);
    if (mut == 0) return null;
    defer cfRelease(mut);
    cfStringNormalize(mut, cfStringNormalizationFormC);
    return cfStringToGo(mut, allocator);
}

pub fn cfStringToGo(src: usize, allocator: std.mem.Allocator) ![]const u8 {
    const length = cfStringGetLength(src);
    const bufSize = cfStringGetMaximumSizeForEncoding(length, @import("fsevents_darwin.zig").cfStringEncodingUTF8) + 1;
    const buf = try allocator.alloc(u8, bufSize);
    if (!cfStringGetCString(src, buf.ptr, bufSize, @import("fsevents_darwin.zig").cfStringEncodingUTF8)) {
        allocator.free(buf);
        return allocator.alloc(u8, 0);
    }
    var n: usize = 0;
    while (n < buf.len and buf[n] != 0) : (n += 1) {}
    
    // Copy to exact sized slice
    const result = try allocator.alloc(u8, n);
    @memcpy(result, buf[0..n]);
    allocator.free(buf);
    return result;
}

pub fn normalizeNFC(s: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    if (isASCII(s)) {
        const result = try allocator.alloc(u8, s.len);
        @memcpy(result, s);
        return result;
    }

    const cstr = try allocator.alloc(u8, s.len + 1);
    defer allocator.free(cstr);
    @memcpy(cstr[0..s.len], s);
    cstr[s.len] = 0;

    const src = cfStringCreate(0, cstr.ptr, @import("fsevents_darwin.zig").cfStringEncodingUTF8);
    if (src == 0) {
        const result = try allocator.alloc(u8, s.len);
        @memcpy(result, s);
        return result;
    }
    defer cfRelease(src);

    const normalized = try cfStringToNFC(src, allocator);
    if (normalized.len == 0) {
        allocator.free(normalized);
        const result = try allocator.alloc(u8, s.len);
        @memcpy(result, s);
        return result;
    }
    return normalized;
}

pub var fse_dispatch_queue_create_trampoline_addr: usize = 0;
pub fn dispatchQueueCreate(label: ?*const anyopaque) usize {
    const ret = syscall_syscall6(fse_dispatch_queue_create_trampoline_addr, @intFromPtr(label), 0, 0, 0, 0, 0);
    return ret.r1;
}

pub var fse_dispatch_release_trampoline_addr: usize = 0;
pub fn dispatchRelease(obj: usize) void {
    _ = syscall_syscall6(fse_dispatch_release_trampoline_addr, obj, 0, 0, 0, 0, 0);
}

pub var fse_dispatch_sync_f_trampoline_addr: usize = 0;
pub var fse_dispatch_noop_addr: usize = 0;
pub fn dispatchSync(queue: usize, context: usize, work: usize) void {
    _ = syscall_syscall6(fse_dispatch_sync_f_trampoline_addr, queue, context, work, 0, 0, 0);
}

pub var fse_FSEventStreamCreate_trampoline_addr: usize = 0;
pub fn fsEventStreamCreate(allocator: usize, callback: usize, ctx: ?*anyopaque, paths: usize, since: u64, latency: f64) usize {
    const ret = syscall_syscall6(
        fse_FSEventStreamCreate_trampoline_addr,
        allocator,
        callback,
        @intFromPtr(ctx),
        paths,
        since,
        @bitCast(latency),
    );
    return ret.r1;
}

pub var fse_FSEventStreamSetDispatchQueue_trampoline_addr: usize = 0;
pub fn fsEventStreamSetDispatchQueue(stream: usize, queue: usize) void {
    _ = syscall_syscall6(fse_FSEventStreamSetDispatchQueue_trampoline_addr, stream, queue, 0, 0, 0, 0);
}

pub var fse_FSEventStreamStart_trampoline_addr: usize = 0;
pub fn fsEventStreamStart(stream: usize) u8 {
    const ret = syscall_syscall6(fse_FSEventStreamStart_trampoline_addr, stream, 0, 0, 0, 0, 0);
    return @intCast(ret.r1);
}

pub var fse_FSEventStreamFlushSync_trampoline_addr: usize = 0;
pub fn fsEventStreamFlushSync(stream: usize) void {
    _ = syscall_syscall6(fse_FSEventStreamFlushSync_trampoline_addr, stream, 0, 0, 0, 0, 0);
}

pub var fse_FSEventStreamStop_trampoline_addr: usize = 0;
pub fn fsEventStreamStop(stream: usize) void {
    _ = syscall_syscall6(fse_FSEventStreamStop_trampoline_addr, stream, 0, 0, 0, 0, 0);
}

pub var fse_FSEventStreamInvalidate_trampoline_addr: usize = 0;
pub fn fsEventStreamInvalidate(stream: usize) void {
    _ = syscall_syscall6(fse_FSEventStreamInvalidate_trampoline_addr, stream, 0, 0, 0, 0, 0);
}

pub var fse_FSEventStreamRelease_trampoline_addr: usize = 0;
pub fn fsEventStreamRelease(stream: usize) void {
    _ = syscall_syscall6(fse_FSEventStreamRelease_trampoline_addr, stream, 0, 0, 0, 0, 0);
}

pub var fse_free_trampoline_addr: usize = 0;
pub fn libcFree(ptr: usize) void {
    if (ptr != 0) {
        _ = syscall_syscall6(fse_free_trampoline_addr, ptr, 0, 0, 0, 0, 0);
    }
}

pub var fsEventsCallbackAsmAddr: usize = 0;

pub const FsEventsCallbackPayload = extern struct {
    numEvents: usize,
    paths: usize,
    flags: usize,

    pub fn close(self: *FsEventsCallbackPayload) void {
        if (self.paths != 0) cfRelease(self.paths);
        libcFree(self.flags);
        libcFree(@intFromPtr(self));
    }
};

pub const StreamCallback = struct {
    eventPipeWrite: usize,

    eventFile: std.fs.File,
    queue: usize,
    done: std.Thread.ResetEvent,
    dirWatch: *watcher.DirWatch,
    closed: std.atomic.Value(bool),

    pub fn create(w: *watcher.DirWatch, allocator: std.mem.Allocator) !*StreamCallback {
        var eventPipe: [2]posix.fd_t = undefined;
        try posix.pipe(&eventPipe);
        
        posix.fcntl(eventPipe[0], posix.F.SETFD, posix.FD_CLOEXEC) catch {};
        posix.fcntl(eventPipe[1], posix.F.SETFD, posix.FD_CLOEXEC) catch {};

        const label = "typescript.fswatch.fsevents.stream\x00";
        const queue = dispatchQueueCreate(label.ptr);
        if (queue == 0) {
            posix.close(eventPipe[0]);
            posix.close(eventPipe[1]);
            return error.StreamCreateNull;
        }

        const cb = try allocator.create(StreamCallback);
        cb.* = .{
            .eventPipeWrite = @intCast(eventPipe[1]),
            .eventFile = std.fs.File{ .handle = eventPipe[0] },
            .queue = queue,
            .done = std.Thread.ResetEvent{},
            .dirWatch = w,
            .closed = std.atomic.Value(bool).init(false),
        };

        const thread = try std.Thread.spawn(.{}, eventLoop, .{cb});
        thread.detach();

        return cb;
    }

    pub fn waitDispatchQueue(self: *StreamCallback) void {
        if (self.queue != 0) {
            dispatchSync(self.queue, 0, fse_dispatch_noop_addr);
        }
    }

    pub fn close(self: *StreamCallback) void {
        posix.close(@intCast(self.eventPipeWrite));
        self.done.wait();
        self.eventFile.close();
        if (self.queue != 0) {
            dispatchRelease(self.queue);
            self.queue = 0;
        }
        self.dirWatch.allocator.destroy(self);
    }

    fn eventLoop(self: *StreamCallback) void {
        defer self.done.set();
        var payload: ?*FsEventsCallbackPayload = null;
        const buf = std.mem.asBytes(&payload);

        while (true) {
            payload = null;
            const bytes_read = self.eventFile.readAll(buf) catch return;
            if (bytes_read != buf.len) return;

            @import("fsevents_darwin.zig").fsEventsCallback(self, payload);
        }
    }
};
