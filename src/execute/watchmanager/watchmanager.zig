//! Watch manager for `tsc --watch` mode.
//!
//! Port of `internal/execute/watchmanager/watchmanager.go` (341 LOC).
//!
//! Manages filesystem watches, accumulates change events, and signals
//! when a watch cycle should run.

const std = @import("std");

const fswatch = @import("../../fswatch/fswatch.zig");

/// A watched directory entry.
const WatchedDir = struct {
    recursive: bool,
    handle: ?*anyopaque = null,
};

/// Watch backend interface for abstracting the underlying fs watcher.
pub const WatchBackend = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        watchDirectory: *const fn (ptr: *anyopaque, dir: []const u8, recursive: bool) anyerror!?*anyopaque,
        close: *const fn (ptr: *anyopaque) void,
    };

    pub fn watchDirectory(self: WatchBackend, dir: []const u8, recursive: bool) !?*anyopaque {
        return self.vtable.watchDirectory(self.ptr, dir, recursive);
    }

    pub fn close(self: WatchBackend) void {
        self.vtable.close(self.ptr);
    }
};

/// Watch manager.
pub const WatchManager = struct {
    mu: std.Thread.Mutex,
    backend: ?WatchBackend = null,
    watched_dirs: std.StringHashMapUnmanaged(WatchedDir),
    do_cycle_flag: std.atomic.Value(bool),
    allocator: std.mem.Allocator,
    changed_mu: std.Thread.Mutex,
    changed_paths: std.StringHashMapUnmanaged(fswatch.EventKind),
    changed_overflow: bool,

    pub fn init(allocator: std.mem.Allocator) WatchManager {
        return .{
            .mu = .{},
            .watched_dirs = .empty,
            .do_cycle_flag = std.atomic.Value(bool).init(false),
            .allocator = allocator,
            .changed_mu = .{},
            .changed_paths = .empty,
            .changed_overflow = false,
        };
    }

    pub fn deinit(self: *WatchManager) void {
        self.watched_dirs.deinit(self.allocator);
        self.changed_paths.deinit(self.allocator);
    }

    pub fn setBackend(self: *WatchManager, b: WatchBackend) void {
        self.backend = b;
    }

    pub fn lock(self: *WatchManager) void {
        self.mu.lock();
    }

    pub fn unlock(self: *WatchManager) void {
        self.mu.unlock();
    }

    pub fn signalDoCycle(self: *WatchManager) void {
        self.do_cycle_flag.store(true, .seq_cst);
    }

    pub fn shouldDoCycle(self: *WatchManager) bool {
        return self.do_cycle_flag.swap(false, .seq_cst);
    }

    pub fn recordChange(self: *WatchManager, path: []const u8, kind: fswatch.EventKind) void {
        self.changed_mu.lock();
        defer self.changed_mu.unlock();
        _ = self.changed_paths.put(self.allocator, path, kind) catch {
            self.changed_overflow = true;
        };
    }

    pub fn drainEvents(self: *WatchManager) struct { changed: std.StringHashMapUnmanaged(fswatch.EventKind), overflow: bool } {
        self.changed_mu.lock();
        defer self.changed_mu.unlock();
        const result = .{ .changed = self.changed_paths, .overflow = self.changed_overflow };
        self.changed_paths = .empty;
        self.changed_overflow = false;
        return result;
    }

    pub fn watchDirectory(self: *WatchManager, dir: []const u8, recursive: bool) !void {
        self.mu.lock();
        defer self.mu.unlock();
        if (self.watched_dirs.contains(dir)) return;
        var handle: ?*anyopaque = null;
        if (self.backend) |b| {
            handle = try b.watchDirectory(dir, recursive);
        }
        _ = self.watched_dirs.put(self.allocator, dir, .{ .recursive = recursive, .handle = handle }) catch {};
    }

    pub fn unwatchDirectory(self: *WatchManager, dir: []const u8) void {
        self.mu.lock();
        defer self.mu.unlock();
        _ = self.watched_dirs.remove(dir);
    }

    pub fn closeAllWatches(self: *WatchManager) void {
        self.mu.lock();
        defer self.mu.unlock();
        self.watched_dirs.clearRetainingCapacity();
    }
};
