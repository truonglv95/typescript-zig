const std = @import("std");
const event_pkg = @import("event.zig");
const debounce_pkg = @import("debounce.zig");
const canonicalize_pkg = @import("canonicalize.zig");

pub const Event = event_pkg.Event;
pub const EventKind = event_pkg.EventKind;
pub const EventList = event_pkg.EventList;
pub const Debounce = debounce_pkg.Debounce;
pub const canonicalizePath = canonicalize_pkg.canonicalizePath;

pub const Error = error{
    NilCallback,
    RootPath,
    NotAbsolute,
    Overflow,
    WatchTerminated,
    Unavailable,
    OutOfMemory,
};

pub const WatchCallback = *const fn (events: []const Event, err: ?anyerror, ctx: ?*anyopaque) void;

pub const WatchCallbackFn = struct {
    ctx: ?*anyopaque,
    cb: WatchCallback,
};

pub const WatchOptions = struct {
    ignore: ?*const fn (path: []const u8) bool = null,
    recursive: bool = false,
};

pub const Watch = struct {
    w: *Watcher,
    dw: *DirWatch,
    impl: *WatcherImpl,
    id: u64,
    cancelled: bool = false,
    mu: std.Thread.Mutex = .{},
    allocator: std.mem.Allocator,

    pub fn close(self: *Watch) void {
        self.mu.lock();
        defer self.mu.unlock();
        if (self.cancelled) return;
        self.cancelled = true;
        const last = self.dw.unwatch(self.id);
        if (last) {
            self.impl.watchRemove(self.dw);
            self.dw.unref(self.w);
        }
    }

    pub fn deinit(self: *Watch) void {
        self.close();
        self.allocator.destroy(self);
    }
};

pub const WatcherImpl = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        start: *const fn (ptr: *anyopaque) anyerror!void,
        run: *const fn (ptr: *anyopaque) anyerror!void,
        shutdown: *const fn (ptr: *anyopaque) void,
        watchAdd: *const fn (ptr: *anyopaque, w: *DirWatch) anyerror!void,
        watchRemove: *const fn (ptr: *anyopaque, w: *DirWatch) void,
        handleWatcherError: *const fn (ptr: *anyopaque, err: *DirWatchError) void,
        subscribe: *const fn (ptr: *anyopaque, w: *DirWatch) anyerror!void,
        closeWatch: *const fn (ptr: *anyopaque, w: *DirWatch) anyerror!void,
    };

    pub inline fn start(self: WatcherImpl) !void {
        return self.vtable.start(self.ptr);
    }
    pub inline fn run(self: WatcherImpl) !void {
        return self.vtable.run(self.ptr);
    }
    pub inline fn shutdown(self: WatcherImpl) void {
        self.vtable.shutdown(self.ptr);
    }
    pub inline fn watchAdd(self: WatcherImpl, w: *DirWatch) !void {
        return self.vtable.watchAdd(self.ptr, w);
    }
    pub inline fn watchRemove(self: WatcherImpl, w: *DirWatch) void {
        self.vtable.watchRemove(self.ptr, w);
    }
    pub inline fn handleWatcherError(self: WatcherImpl, err: *DirWatchError) void {
        self.vtable.handleWatcherError(self.ptr, err);
    }
    pub inline fn subscribe(self: WatcherImpl, w: *DirWatch) !void {
        return self.vtable.subscribe(self.ptr, w);
    }
    pub inline fn closeWatch(self: WatcherImpl, w: *DirWatch) !void {
        return self.vtable.closeWatch(self.ptr, w);
    }
};

pub const DirWatchError = struct {
    err: anyerror,
    dirWatch: *DirWatch,
};

pub const Callback = struct {
    id: u64,
    fn_cb: WatchCallbackFn,
    ignore: ?*const fn (path: []const u8) bool,
};

pub const DirWatch = struct {
    dir: []const u8,
    recursive: bool = false,
    events: EventList,
    state: ?*anyopaque = null,
    
    mu: std.Thread.Mutex = .{},
    callbacks: std.ArrayList(Callback),
    debounce: ?*Debounce = null,
    nextCBID: u64 = 0,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, dir: []const u8, db: *Debounce) !*DirWatch {
        var dw = try allocator.create(DirWatch);
        dw.* = .{
            .dir = try allocator.dupe(u8, dir),
            .events = EventList.init(allocator),
            .callbacks = std.ArrayList(Callback).init(allocator),
            .debounce = db,
            .allocator = allocator,
        };
        try db.add(@intFromPtr(dw), dw, triggerCallbacksWrapper);
        return dw;
    }

    pub fn deinit(self: *DirWatch) void {
        self.destroyDebounce();
        self.events.deinit();
        self.callbacks.deinit();
        self.allocator.free(self.dir);
        self.allocator.destroy(self);
    }

    fn triggerCallbacksWrapper(ctx: *anyopaque) void {
        const self: *DirWatch = @ptrCast(@alignCast(ctx));
        self.triggerCallbacks();
    }

    pub fn destroyDebounce(self: *DirWatch) void {
        self.mu.lock();
        const db = self.debounce;
        self.debounce = null;
        self.mu.unlock();
        if (db) |d| {
            d.remove(@intFromPtr(self));
        }
    }

    pub fn notify(self: *DirWatch) void {
        self.mu.lock();
        const hasCBs = self.callbacks.items.len > 0;
        const hasEvents = self.events.size() > 0;
        const hasError = self.events.hasError();
        const db = self.debounce;
        self.mu.unlock();

        if (hasCBs and (hasEvents or hasError)) {
            if (db) |d| d.trigger();
        }
    }

    pub fn notifyError(self: *DirWatch, err: anyerror) void {
        self.mu.lock();
        const cbs = self.allocator.dupe(Callback, self.callbacks.items) catch return;
        self.callbacks.clearAndFree();
        self.mu.unlock();
        
        defer self.allocator.free(cbs);
        for (cbs) |cb| {
            cb.fn_cb.cb(&[_]Event{}, err, cb.fn_cb.ctx);
        }
    }

    pub fn triggerCallbacks(self: *DirWatch) void {
        self.mu.lock();
        const hasError = self.events.hasError();
        const hasEvents = self.events.size() > 0;
        if (self.callbacks.items.len == 0 or (!hasEvents and !hasError)) {
            self.mu.unlock();
            return;
        }

        const drain_res = self.events.drain() catch return;
        const events = drain_res.events;
        const err = drain_res.err;
        defer {
            for (events) |e| {
                self.allocator.free(e.path);
            }
            self.allocator.free(events);
        }

        const cbs = self.allocator.dupe(Callback, self.callbacks.items) catch { self.mu.unlock(); return; };
        const recursive = self.recursive;
        self.mu.unlock();
        defer self.allocator.free(cbs);

        for (cbs) |cb| {
            var cbEvents = std.ArrayList(Event).init(self.allocator);
            defer cbEvents.deinit();

            if (cb.ignore != null or !recursive) {
                for (events) |e| {
                    if (cb.ignore) |ig| {
                        if (ig(e.path)) continue;
                    }
                    if (!recursive and !isDirectChild(self.dir, e.path)) {
                        continue;
                    }
                    cbEvents.append(e) catch continue;
                }
            } else {
                for (events) |e| {
                    cbEvents.append(e) catch continue;
                }
            }

            if (cbEvents.items.len > 0 or err != null) {
                cb.fn_cb.cb(cbEvents.items, err, cb.fn_cb.ctx);
            }
        }
    }

    pub fn watch(self: *DirWatch, fn_cb: WatchCallbackFn, ignore: ?*const fn (path: []const u8) bool) !u64 {
        self.mu.lock();
        defer self.mu.unlock();
        self.nextCBID += 1;
        const id = self.nextCBID;
        try self.callbacks.append(.{ .id = id, .fn_cb = fn_cb, .ignore = ignore });
        return id;
    }

    pub fn unwatch(self: *DirWatch, id: u64) bool {
        self.mu.lock();
        defer self.mu.unlock();
        for (self.callbacks.items, 0..) |cb, i| {
            if (cb.id == id) {
                _ = self.callbacks.orderedRemove(i);
                return self.callbacks.items.len == 0;
            }
        }
        return false;
    }

    pub fn unref(self: *DirWatch, w: *Watcher) void {
        self.mu.lock();
        const empty = self.callbacks.items.len == 0;
        self.mu.unlock();
        if (empty) {
            w.removeDirWatch(self);
        }
    }
};

fn isDirectChild(dir: []const u8, path: []const u8) bool {
    if (!std.mem.startsWith(u8, path, dir)) return false;
    var rest = path[dir.len..];
    if (rest.len == 0) return false;
    if (rest[0] != '/' and rest[0] != std.fs.path.sep) return false;
    rest = rest[1..];
    return rest.len > 0 and std.mem.indexOfScalar(u8, rest, '/') == null and std.mem.indexOfScalar(u8, rest, std.fs.path.sep) == null;
}

pub const Watcher = struct {
    name: []const u8,
    mu: std.Thread.Mutex = .{},
    impl: ?WatcherImpl = null,
    factory: ?*const fn (allocator: std.mem.Allocator) anyerror!WatcherImpl = null,
    dirWatches: std.StringHashMap(*DirWatch),
    debounce: ?*Debounce = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, factory: ?*const fn (allocator: std.mem.Allocator) anyerror!WatcherImpl) Watcher {
        return .{
            .name = name,
            .factory = factory,
            .dirWatches = std.StringHashMap(*DirWatch).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn available(self: *const Watcher) bool {
        return self.factory != null;
    }

    pub fn hasFastRecursiveBackend(self: *const Watcher) bool {
        if (std.mem.eql(u8, self.name, "windows") or std.mem.eql(u8, self.name, "fsevents")) {
            return true;
        }
        return false;
    }

    pub fn getImpl(self: *Watcher) !WatcherImpl {
        self.mu.lock();
        if (self.impl) |impl| {
            self.mu.unlock();
            return impl;
        }
        const factory = self.factory;
        self.mu.unlock();

        if (factory == null) return Error.Unavailable;

        const impl = try factory.?(self.allocator);
        try impl.run();

        self.mu.lock();
        defer self.mu.unlock();
        if (self.impl) |existing| {
            impl.shutdown();
            return existing;
        }
        self.impl = impl;
        return impl;
    }

    fn getOrCreateDirWatch(self: *Watcher, dir: []const u8, recursive: bool) !*DirWatch {
        self.mu.lock();
        defer self.mu.unlock();
        if (self.debounce == null) {
            self.debounce = try Debounce.init(self.allocator);
        }
        
        var key_alloc: []u8 = undefined;
        var key: []const u8 = undefined;
        if (recursive) {
            key_alloc = try self.allocator.alloc(u8, dir.len + 10);
            @memcpy(key_alloc[0..dir.len], dir);
            @memcpy(key_alloc[dir.len..], "\x00recursive");
            key = key_alloc;
        } else {
            key = dir;
        }
        defer if (recursive) self.allocator.free(key_alloc);

        if (self.dirWatches.get(key)) |dw| {
            return dw;
        }
        const dw = try DirWatch.init(self.allocator, dir, self.debounce.?);
        dw.recursive = recursive;
        try self.dirWatches.put(try self.allocator.dupe(u8, key), dw);
        return dw;
    }

    pub fn removeDirWatch(self: *Watcher, dw: *DirWatch) void {
        self.mu.lock();
        defer self.mu.unlock();

        var key_alloc: []u8 = undefined;
        var key: []const u8 = undefined;
        if (dw.recursive) {
            key_alloc = self.allocator.alloc(u8, dw.dir.len + 10) catch return;
            @memcpy(key_alloc[0..dw.dir.len], dw.dir);
            @memcpy(key_alloc[dw.dir.len..], "\x00recursive");
            key = key_alloc;
        } else {
            key = dw.dir;
        }
        defer if (dw.recursive) self.allocator.free(key_alloc);

        if (self.dirWatches.get(key)) |existing| {
            if (existing == dw) {
                const k = self.dirWatches.getKey(key).?;
                _ = self.dirWatches.remove(key);
                self.allocator.free(k);
                dw.destroyDebounce();
                dw.deinit();
            }
        }
    }

    pub fn watchDirectory(self: *Watcher, dir: []const u8, fn_cb: WatchCallbackFn, opts: WatchOptions) !*Watch {
        if (!self.available()) return Error.Unavailable;
        
        var clean_dir = try std.fs.path.resolve(self.allocator, &[_][]const u8{dir});
        defer self.allocator.free(clean_dir);

        if (!std.fs.path.isAbsolute(clean_dir)) {
            return Error.NotAbsolute;
        }
        
        const canon_dir = try canonicalizePath(self.allocator, clean_dir);
        defer self.allocator.free(canon_dir);

        const dw = try self.getOrCreateDirWatch(canon_dir, opts.recursive);
        const id = try dw.watch(fn_cb, opts.ignore);

        const impl = self.getImpl() catch |err| {
            _ = dw.unwatch(id);
            dw.unref(self);
            return err;
        };

        impl.watchAdd(dw) catch |err| {
            _ = dw.unwatch(id);
            dw.unref(self);
            return err;
        };

        var watch_instance = try self.allocator.create(Watch);
        watch_instance.* = .{
            .w = self,
            .dw = dw,
            .impl = &self.impl.?,
            .id = id,
            .cancelled = false,
            .allocator = self.allocator,
        };
        return watch_instance;
    }

    pub fn watchFile(self: *Watcher, path: []const u8, fn_cb: WatchCallbackFn) !*Watch {
        if (!self.available()) return Error.Unavailable;

        var clean_path = try std.fs.path.resolve(self.allocator, &[_][]const u8{path});
        defer self.allocator.free(clean_path);

        if (!std.fs.path.isAbsolute(clean_path)) {
            return Error.NotAbsolute;
        }

        const canon_path = try canonicalizePath(self.allocator, clean_path);
        defer self.allocator.free(canon_path);

        const dir = std.fs.path.dirname(canon_path) orelse canon_path;
        if (std.mem.eql(u8, dir, canon_path)) {
            return Error.RootPath;
        }

        const wrapper_ctx = try self.allocator.create(FileCallbackCtx);
        wrapper_ctx.* = .{
            .target = try self.allocator.dupe(u8, canon_path),
            .original_cb = fn_cb,
            .allocator = self.allocator,
        };

        const wrapper_fn_cb = WatchCallbackFn{
            .ctx = wrapper_ctx,
            .cb = fileCallbackWrapper,
        };

        return self.watchDirectory(dir, wrapper_fn_cb, .{});
    }

    pub fn deinit(self: *Watcher) void {
        if (self.impl) |impl| {
            impl.shutdown();
        }
        var it = self.dirWatches.iterator();
        while (it.next()) |kv| {
            kv.value_ptr.*.deinit();
            self.allocator.free(kv.key_ptr.*);
        }
        self.dirWatches.deinit();
        if (self.debounce) |db| {
            db.deinit();
        }
    }
};

const FileCallbackCtx = struct {
    target: []const u8,
    original_cb: WatchCallbackFn,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *FileCallbackCtx) void {
        self.allocator.free(self.target);
        self.allocator.destroy(self);
    }
};

fn fileCallbackWrapper(events: []const Event, err: ?anyerror, ctx: ?*anyopaque) void {
    const file_ctx: *FileCallbackCtx = @ptrCast(@alignCast(ctx.?));
    
    var filtered = std.ArrayList(Event).init(file_ctx.allocator);
    defer filtered.deinit();

    for (events) |e| {
        if (std.mem.eql(u8, e.path, file_ctx.target)) {
            filtered.append(e) catch continue;
        }
    }

    if (filtered.items.len > 0 or err != null) {
        file_ctx.original_cb.cb(filtered.items, err, file_ctx.original_cb.ctx);
    }
}

pub const WatcherBase = struct {
    mu: std.Thread.Mutex = .{},
    subscriptions: std.AutoHashMap(*DirWatch, void),
    started: bool = false,
    startCond: std.Thread.Condition = .{},
    startErr: ?anyerror = null,
    self_impl: WatcherImpl,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, self_impl: WatcherImpl) WatcherBase {
        return .{
            .subscriptions = std.AutoHashMap(*DirWatch, void).init(allocator),
            .self_impl = self_impl,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *WatcherBase) void {
        self.subscriptions.deinit();
    }

    pub fn notifyStarted(self: *WatcherBase) void {
        self.mu.lock();
        defer self.mu.unlock();
        if (!self.started) {
            self.started = true;
            self.startCond.broadcast();
        }
    }

    pub fn run(self: *WatcherBase) !void {
        const th = try std.Thread.spawn(.{}, runStartThread, .{self});
        th.detach();
        
        self.mu.lock();
        defer self.mu.unlock();
        while (!self.started) {
            self.startCond.wait(&self.mu);
        }
        if (self.startErr) |err| return err;
    }

    fn runStartThread(self: *WatcherBase) void {
        self.self_impl.start() catch |err| {
            self.handleStartError(err);
            return;
        };
    }

    pub fn handleStartError(self: *WatcherBase, err: anyerror) void {
        self.mu.lock();
        self.startErr = err;
        
        var subs = std.ArrayList(*DirWatch).init(self.allocator);
        defer subs.deinit();
        var it = self.subscriptions.keyIterator();
        while (it.next()) |w| {
            subs.append(w.*) catch continue;
        }
        self.mu.unlock();

        for (subs.items) |w| {
            w.notifyError(err);
        }
        self.notifyStarted();
    }

    pub fn watchAdd(self: *WatcherBase, w: *DirWatch) !void {
        self.mu.lock();
        if (self.subscriptions.contains(w)) {
            self.mu.unlock();
            return;
        }
        self.self_impl.subscribe(w) catch |err| {
            self.mu.unlock();
            return err;
        };
        try self.subscriptions.put(w, {});
        self.mu.unlock();
    }

    pub fn watchRemove(self: *WatcherBase, w: *DirWatch) void {
        self.mu.lock();
        if (!self.subscriptions.contains(w)) {
            self.mu.unlock();
            return;
        }
        _ = self.subscriptions.remove(w);
        self.self_impl.closeWatch(w) catch {};
        self.mu.unlock();
    }

    pub fn handleWatcherError(self: *WatcherBase, werr: *DirWatchError) void {
        self.watchRemove(werr.dirWatch);
        werr.dirWatch.notifyError(Error.WatchTerminated);
    }
};
