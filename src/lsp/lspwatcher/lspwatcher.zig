const std = @import("std");
const fswatch = @import("../../fswatch/fswatch.zig");
const lsproto = @import("../../lsp/lsproto/lsproto.zig");
const vfs = @import("../../vfs/vfs.zig");
const logging = @import("../../project/logging/logging.zig");
const tspath = @import("../../tspath/tspath.zig");
const lsconv = @import("../../ls/lsconv/lsconv.zig");

pub const throttleWindow = 75 * std.time.ns_per_ms;

pub const WatcherBackend = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        watchDirectory: *const fn (
            ptr: *anyopaque,
            dir: []const u8,
            context: *anyopaque,
            callback: fswatch.WatchCallback,
            opts: []const fswatch.WatchOption,
        ) anyerror!fswatch.Subscription,
    };

    pub fn watchDirectory(
        self: WatcherBackend,
        dir: []const u8,
        context: *anyopaque,
        callback: fswatch.WatchCallback,
        opts: []const fswatch.WatchOption,
    ) !fswatch.Subscription {
        return self.vtable.watchDirectory(self.ptr, dir, context, callback, opts);
    }
};

pub const WatchIndex = u32;

pub const Watch = struct {
    requested_directory: []const u8,
    kind: lsproto.WatchKind,
    recursive: bool,

    subscription: ?fswatch.Subscription = null,
    watched_directory: []const u8 = "",
    watching_target: bool = false,
    closed: bool = false,
};

pub const Watcher = struct {
    allocator: std.mem.Allocator,
    fs: vfs.FS,
    backend: WatcherBackend,
    on_changes_ctx: *anyopaque,
    on_changes: *const fn (ctx: *anyopaque, changes: []const lsproto.FileEvent) void,
    logger: logging.Logger,

    mutex: std.Thread.Mutex = .{},
    watches_map: std.StringHashMapUnmanaged(std.ArrayListUnmanaged(WatchIndex)) = .empty,
    watch_pool: std.MultiArrayList(Watch) = .{},
    closed: bool = false,

    pending: std.StringHashMapUnmanaged(lsproto.FileEvent) = .empty,
    flush_timer_armed: bool = false,

    pub fn init(
        allocator: std.mem.Allocator,
        fs_impl: vfs.FS,
        backend: WatcherBackend,
        on_changes_ctx: *anyopaque,
        on_changes: *const fn (ctx: *anyopaque, changes: []const lsproto.FileEvent) void,
        logger_impl: logging.Logger,
    ) Watcher {
        return .{
            .allocator = allocator,
            .fs = fs_impl,
            .backend = backend,
            .on_changes_ctx = on_changes_ctx,
            .on_changes = on_changes,
            .logger = logger_impl,
        };
    }

    pub fn deinit(self: *Watcher) void {
        self.mutex.lock();
        if (self.closed) {
            self.mutex.unlock();
            return;
        }
        self.closed = true;

        var iter = self.watches_map.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.watches_map.deinit(self.allocator);

        const subs = self.watch_pool.items(.subscription);
        for (subs) |sub| {
            if (sub) |s| {
                _ = s.close();
            }
        }
        self.watch_pool.deinit(self.allocator);

        var pending_iter = self.pending.iterator();
        while (pending_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.pending.deinit(self.allocator);

        self.mutex.unlock();
    }

    pub fn watchFiles(self: *Watcher, id: []const u8, file_system_watchers: []const lsproto.FileSystemWatcher) !void {
        self.mutex.lock();
        if (self.closed) {
            self.mutex.unlock();
            return error.Closed;
        }
        if (self.watches_map.contains(id)) {
            self.mutex.unlock();
            return error.AlreadyExists;
        }
        const id_dup = try self.allocator.dupe(u8, id);
        try self.watches_map.put(self.allocator, id_dup, .empty);
        self.mutex.unlock();

        var failed = false;
        var indices = std.ArrayList(WatchIndex).init(self.allocator);
        defer indices.deinit();

        for (file_system_watchers) |fsw| {
            var directory: []const u8 = undefined;
            if (watchRoot(self.allocator, fsw)) |root| {
                directory = root;
            } else {
                self.logger.logf("lspwatcher: skipping watcher \"{s}\": unrecognized pattern \"{s}\"", .{ id, watchPatternString(self.allocator, fsw) });
                continue;
            }

            const w = Watch{
                .requested_directory = directory,
                .kind = effectiveKind(fsw),
                .recursive = isRecursiveGlob(self.allocator, fsw),
            };

            const index = @as(WatchIndex, @intCast(self.watch_pool.len));
            try self.watch_pool.append(self.allocator, w);
            try indices.append(index);

            if (self.reconcile(index, false)) |_| {} else |err| {
                self.logger.logf("lspwatcher: failed to register watcher \"{s}\" for \"{s}\": {}", .{ id, directory, err });
                self.closeWatch(index);
                failed = true;
                break;
            }
        }

        self.mutex.lock();
        defer self.mutex.unlock();
        if (failed) {
            _ = self.unwatchFiles(id);
            return error.RegistrationFailed;
        } else {
            const list = self.watches_map.getPtr(id).?;
            try list.appendSlice(self.allocator, indices.items);
        }
    }

    pub fn unwatchFiles(self: *Watcher, id: []const u8) !void {
        self.mutex.lock();
        const kv = self.watches_map.fetchRemove(id);
        if (kv == null) {
            self.mutex.unlock();
            return error.NotFound;
        }
        var indices = kv.?.value;
        self.allocator.free(kv.?.key);
        self.mutex.unlock();

        for (indices.items) |index| {
            self.closeWatch(index);
        }
        indices.deinit(self.allocator);
    }

    fn closeWatch(self: *Watcher, index: WatchIndex) void {
        self.mutex.lock();
        const closed = self.watch_pool.items(.closed)[index];
        if (closed) {
            self.mutex.unlock();
            return;
        }
        self.watch_pool.items(.closed)[index] = true;
        const sub = self.watch_pool.items(.subscription)[index];
        self.watch_pool.items(.subscription)[index] = null;
        self.mutex.unlock();
        if (sub) |s| {
            _ = s.close();
        }
    }

    fn reconcile(self: *Watcher, index: WatchIndex, emit_synthetic_creates: bool) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        const w = self.watch_pool.get(index);
        var emit_syn = emit_synthetic_creates;

        while (true) {
            if (self.watch_pool.items(.closed)[index]) {
                return;
            }

            if (self.fs.directoryExists(w.requested_directory)) {
                if (w.watching_target and w.subscription != null) {
                    return;
                }
                const target_directory = self.fs.realpath(self.allocator, w.requested_directory);
                defer self.allocator.free(target_directory);
                
                var opts = std.ArrayList(fswatch.WatchOption).init(self.allocator);
                defer opts.deinit();
                if (w.recursive) {
                    try opts.append(fswatch.WatchOption.recursive());
                }

                const ctx = @as(*anyopaque, @ptrFromInt(@as(usize, index)));
                const sub = try self.backend.watchDirectory(target_directory, ctx, targetCallback, opts.items);
                
                const previous = w.subscription;
                self.watch_pool.items(.subscription)[index] = sub;
                self.watch_pool.items(.watched_directory)[index] = try self.allocator.dupe(u8, target_directory);
                self.watch_pool.items(.watching_target)[index] = true;

                if (previous) |p| {
                    _ = p.close();
                }
                
                if (emit_syn) {
                    self.emitSyntheticCreates(target_directory, w.requested_directory, w.kind, w.recursive);
                }
                return;
            }

            if (nearestExistingAncestor(self.allocator, self.fs, w.requested_directory)) |ancestor| {
                defer self.allocator.free(ancestor);
                const ancestor_dir = self.fs.realpath(self.allocator, ancestor);
                defer self.allocator.free(ancestor_dir);

                if (!w.watching_target and w.subscription != null and std.mem.eql(u8, self.watch_pool.items(.watched_directory)[index], ancestor_dir)) {
                    return;
                }

                const ctx = @as(*anyopaque, @ptrFromInt(@as(usize, index)));
                const sub = try self.backend.watchDirectory(ancestor_dir, ctx, ancestorCallback, &.{});

                const previous = w.subscription;
                self.watch_pool.items(.subscription)[index] = sub;
                self.watch_pool.items(.watched_directory)[index] = try self.allocator.dupe(u8, ancestor_dir);
                self.watch_pool.items(.watching_target)[index] = false;

                if (previous) |p| {
                    _ = p.close();
                }

                emit_syn = true;
            } else {
                if (w.subscription) |p| {
                    self.watch_pool.items(.subscription)[index] = null;
                    self.watch_pool.items(.watching_target)[index] = false;
                    _ = p.close();
                }
                return;
            }
        }
    }

    fn targetCallback(ctx: *anyopaque, events: []const fswatch.Event, err: ?anyerror) void {
        _ = ctx;
        _ = events;
        _ = err;
    }

    fn ancestorCallback(ctx: *anyopaque, events: []const fswatch.Event, err: ?anyerror) void {
        _ = ctx;
        _ = events;
        _ = err;
    }

    fn forwardEvents(self: *Watcher, watched_dir: []const u8, req_dir: []const u8, kind: lsproto.WatchKind, events: []const fswatch.Event) void {
        self.mutex.lock();
        if (self.closed) {
            self.mutex.unlock();
            return;
        }

        const opts = tspath.ComparePathsOptions{ .use_case_sensitive_file_names = self.fs.useCaseSensitiveFileNames() };
        for (events) |event| {
            var change_type: lsproto.FileChangeType = undefined;
            switch (event.kind) {
                .Update => {
                    if ((kind & (lsproto.WatchKind.Create | lsproto.WatchKind.Change)) == 0) continue;
                    change_type = .Changed;
                },
                .Delete => {
                    if ((kind & lsproto.WatchKind.Delete) == 0) continue;
                    change_type = .Deleted;
                },
                else => continue,
            }

            const path = remapEventPath(self.allocator, watched_dir, req_dir, tspath.normalizeSlashes(self.allocator, event.path), opts);
            defer self.allocator.free(path);

            const uri = lsconv.fileNameToDocumentURI(self.allocator, path);
            defer self.allocator.free(uri);

            if (!self.pending.contains(uri)) {
                self.pending.put(self.allocator, try self.allocator.dupe(u8, uri), .{ .uri = try self.allocator.dupe(u8, uri), .type = change_type }) catch {};
            }
        }
        self.scheduleFlushLocked();
        self.mutex.unlock();
    }

    fn emitSyntheticCreates(self: *Watcher, watched_dir: []const u8, req_dir: []const u8, kind: lsproto.WatchKind, recursive: bool) void {
        _ = self;
        _ = watched_dir;
        _ = req_dir;
        _ = kind;
        _ = recursive;
    }

    fn enqueueSyntheticCreates(self: *Watcher, paths: []const []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.closed) return;

        for (paths) |path| {
            const uri = lsconv.fileNameToDocumentURI(self.allocator, path);
            defer self.allocator.free(uri);

            if (!self.pending.contains(uri)) {
                self.pending.put(self.allocator, try self.allocator.dupe(u8, uri), .{ .uri = try self.allocator.dupe(u8, uri), .type = .Created }) catch {};
            }
        }
        self.scheduleFlushLocked();
    }

    fn scheduleFlushLocked(self: *Watcher) void {
        if (!self.flush_timer_armed) {
            self.flush_timer_armed = true;
        }
    }

    pub fn flush(self: *Watcher) void {
        self.mutex.lock();
        if (self.closed) {
            self.mutex.unlock();
            return;
        }

        var changes = std.ArrayList(lsproto.FileEvent).init(self.allocator);
        var pending_iter = self.pending.iterator();
        while (pending_iter.next()) |entry| {
            changes.append(entry.value_ptr.*) catch {};
            self.allocator.free(entry.key_ptr.*);
        }
        self.pending.clearRetainingCapacity();
        self.flush_timer_armed = false;
        self.mutex.unlock();

        if (changes.items.len > 0) {
            self.on_changes(self.on_changes_ctx, changes.items);
        }
        changes.deinit();
    }
};

fn remapEventPath(allocator: std.mem.Allocator, watched: []const u8, req: []const u8, path: []const u8, opts: tspath.ComparePathsOptions) []const u8 {
    if (std.mem.eql(u8, watched, req)) {
        return allocator.dupe(u8, path) catch path;
    }
    if (tspath.containsPath(watched, path, opts)) {
        const relative = tspath.getRelativePathFromDirectory(watched, path, opts);
        if (relative.len == 0 or std.mem.eql(u8, relative, ".")) {
            return allocator.dupe(u8, req) catch req;
        }
        return tspath.combinePaths(allocator, req, relative);
    }
    return allocator.dupe(u8, path) catch path;
}

fn nearestExistingAncestor(allocator: std.mem.Allocator, fs: vfs.FS, dir: []const u8) ?[]const u8 {
    var current = allocator.dupe(u8, dir) catch return null;
    while (true) {
        if (fs.directoryExists(current)) {
            return current;
        }
        const parent = tspath.getDirectoryPath(allocator, current);
        if (std.mem.eql(u8, parent, current)) {
            allocator.free(parent);
            allocator.free(current);
            return null;
        }
        allocator.free(current);
        current = parent;
    }
}

fn watchRoot(allocator: std.mem.Allocator, fsw: lsproto.FileSystemWatcher) ?[]const u8 {
    _ = fsw;
    return allocator.dupe(u8, "") catch null;
}

fn watchPatternString(allocator: std.mem.Allocator, fsw: lsproto.FileSystemWatcher) []const u8 {
    _ = fsw;
    return allocator.dupe(u8, "") catch "";
}

fn isRecursiveGlob(allocator: std.mem.Allocator, fsw: lsproto.FileSystemWatcher) bool {
    _ = allocator;
    _ = fsw;
    return false;
}

fn effectiveKind(fsw: lsproto.FileSystemWatcher) lsproto.WatchKind {
    _ = fsw;
    return lsproto.WatchKind.Create | lsproto.WatchKind.Change | lsproto.WatchKind.Delete;
}
