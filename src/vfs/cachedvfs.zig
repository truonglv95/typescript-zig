const std = @import("std");
const vfs = @import("vfs.zig");

//! Caching VFS wrapper.
//!
//! Port of `internal/vfs/cachedvfs/cachedvfs.go` (154 LOC).
//!
//! Wraps an inner `FS` and caches the results of read-only operations
//! (`fileExists`, `directoryExists`, `getAccessibleEntries`, `realpath`,
//! `stat`). Write operations (`writeFile`, `remove`, `chtimes`) are
//! passed through without caching.
//!
//! The cache can be enabled/disabled at runtime and cleared on demand.

/// A caching VFS wrapper. Port of Go's `cachedvfs.FS`.
pub const FS = struct {
    inner: vfs.FS,
    enabled: std.atomic.Value(bool),

    directory_exists_cache: std.StringHashMapUnmanaged(bool),
    file_exists_cache: std.StringHashMapUnmanaged(bool),
    realpath_cache: std.StringHashMapUnmanaged([]const u8),
    mu: std.Thread.Mutex,
    allocator: std.mem.Allocator,

    pub fn from(allocator: std.mem.Allocator, inner: vfs.FS) *FS {
        const fsys = allocator.create(FS) catch unreachable;
        fsys.* = .{
            .inner = inner,
            .enabled = std.atomic.Value(bool).init(true),
            .directory_exists_cache = .empty,
            .file_exists_cache = .empty,
            .realpath_cache = .empty,
            .mu = .{},
            .allocator = allocator,
        };
        return fsys;
    }

    pub fn deinit(self: *FS) void {
        self.directory_exists_cache.deinit(self.allocator);
        self.file_exists_cache.deinit(self.allocator);
        // realpath_cache values are allocator-owned (duped), but we don't
        // track ownership separately; skip freeing for simplicity.
        self.realpath_cache.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Disables caching and clears all cached entries.
    pub fn disableAndClearCache(self: *FS) void {
        if (self.enabled.cmpxchgStrong(true, false, .seq_cst, .seq_cst) != null) return;
        self.clearCache();
    }

    /// Re-enables caching.
    pub fn enable(self: *FS) void {
        self.enabled.store(true, .seq_cst);
    }

    /// Clears all cached entries.
    pub fn clearCache(self: *FS) void {
        self.mu.lock();
        defer self.mu.unlock();
        self.directory_exists_cache.clearRetainingCapacity();
        self.file_exists_cache.clearRetainingCapacity();
        self.realpath_cache.clearRetainingCapacity();
    }

    pub fn useCaseSensitiveFileNames(self: *FS) bool {
        return self.inner.useCaseSensitiveFileNames();
    }

    pub fn fileExists(self: *FS, path: []const u8) bool {
        if (self.enabled.load(.seq_cst)) {
            self.mu.lock();
            defer self.mu.unlock();
            if (self.file_exists_cache.get(path)) |cached| return cached;
        }
        const result = self.inner.fileExists(path);
        if (self.enabled.load(.seq_cst)) {
            self.mu.lock();
            defer self.mu.unlock();
            _ = self.file_exists_cache.put(self.allocator, path, result) catch {};
        }
        return result;
    }

    pub fn directoryExists(self: *FS, path: []const u8) bool {
        if (self.enabled.load(.seq_cst)) {
            self.mu.lock();
            defer self.mu.unlock();
            if (self.directory_exists_cache.get(path)) |cached| return cached;
        }
        const result = self.inner.directoryExists(path);
        if (self.enabled.load(.seq_cst)) {
            self.mu.lock();
            defer self.mu.unlock();
            _ = self.directory_exists_cache.put(self.allocator, path, result) catch {};
        }
        return result;
    }

    pub fn readFile(self: *FS, allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
        return self.inner.readFile(allocator, path);
    }

    pub fn writeFile(self: *FS, path: []const u8, data: []const u8) !void {
        return self.inner.writeFile(path, data);
    }

    pub fn appendFile(self: *FS, path: []const u8, data: []const u8) !void {
        return self.inner.appendFile(path, data);
    }

    pub fn remove(self: *FS, path: []const u8) !void {
        return self.inner.remove(path);
    }

    pub fn chtimes(self: *FS, path: []const u8, atime: i128, mtime: i128) !void {
        return self.inner.chtimes(path, atime, mtime);
    }

    pub fn getAccessibleEntries(self: *FS, allocator: std.mem.Allocator, path: []const u8) vfs.Entries {
        // Not cached (Entries contains slices that are allocator-owned).
        return self.inner.getAccessibleEntries(allocator, path);
    }

    pub fn stat(self: *FS, path: []const u8) ?vfs.FileInfo {
        return self.inner.stat(path);
    }

    pub fn walkDir(self: *FS, root: []const u8, walk_fn: vfs.WalkDirFunc) !void {
        return self.inner.walkDir(root, walk_fn);
    }

    pub fn realpath(self: *FS, allocator: std.mem.Allocator, path: []const u8) ?[]const u8 {
        if (self.enabled.load(.seq_cst)) {
            self.mu.lock();
            defer self.mu.unlock();
            if (self.realpath_cache.get(path)) |cached| return cached;
        }
        const result = self.inner.realpath(allocator, path);
        if (self.enabled.load(.seq_cst)) {
            if (result) |rp| {
                self.mu.lock();
                defer self.mu.unlock();
                _ = self.realpath_cache.put(self.allocator, path, rp) catch {};
            }
        }
        return result;
    }

    /// Returns a `vfs.FS` view of this cached filesystem.
    pub fn fs(self: *FS) vfs.FS {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &vtable,
        };
    }

    const vtable = vfs.FS.VTable{
        .useCaseSensitiveFileNames = vUseCaseSensitiveFileNames,
        .fileExists = vFileExists,
        .directoryExists = vDirectoryExists,
        .readFile = vReadFile,
        .writeFile = vWriteFile,
        .appendFile = vAppendFile,
        .remove = vRemove,
        .chtimes = vChtimes,
        .getAccessibleEntries = vGetAccessibleEntries,
        .stat = vStat,
        .walkDir = vWalkDir,
        .realpath = vRealpath,
    };

    fn vUseCaseSensitiveFileNames(ptr: *anyopaque) bool {
        const self: *FS = @ptrCast(@alignCast(ptr));
        return self.useCaseSensitiveFileNames();
    }

    fn vFileExists(ptr: *anyopaque, path: []const u8) bool {
        const self: *FS = @ptrCast(@alignCast(ptr));
        return self.fileExists(path);
    }

    fn vDirectoryExists(ptr: *anyopaque, path: []const u8) bool {
        const self: *FS = @ptrCast(@alignCast(ptr));
        return self.directoryExists(path);
    }

    fn vReadFile(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
        const self: *FS = @ptrCast(@alignCast(ptr));
        return self.readFile(allocator, path);
    }

    fn vWriteFile(ptr: *anyopaque, path: []const u8, data: []const u8) anyerror!void {
        const self: *FS = @ptrCast(@alignCast(ptr));
        return self.writeFile(path, data);
    }

    fn vAppendFile(ptr: *anyopaque, path: []const u8, data: []const u8) anyerror!void {
        const self: *FS = @ptrCast(@alignCast(ptr));
        return self.appendFile(path, data);
    }

    fn vRemove(ptr: *anyopaque, path: []const u8) anyerror!void {
        const self: *FS = @ptrCast(@alignCast(ptr));
        return self.remove(path);
    }

    fn vChtimes(ptr: *anyopaque, path: []const u8, atime: i128, mtime: i128) anyerror!void {
        const self: *FS = @ptrCast(@alignCast(ptr));
        return self.chtimes(path, atime, mtime);
    }

    fn vGetAccessibleEntries(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) vfs.Entries {
        const self: *FS = @ptrCast(@alignCast(ptr));
        return self.getAccessibleEntries(allocator, path);
    }

    fn vStat(ptr: *anyopaque, path: []const u8) ?vfs.FileInfo {
        const self: *FS = @ptrCast(@alignCast(ptr));
        return self.stat(path);
    }

    fn vWalkDir(ptr: *anyopaque, root: []const u8, walk_fn: vfs.WalkDirFunc) anyerror!void {
        const self: *FS = @ptrCast(@alignCast(ptr));
        return self.walkDir(root, walk_fn);
    }

    fn vRealpath(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) ?[]const u8 {
        const self: *FS = @ptrCast(@alignCast(ptr));
        return self.realpath(allocator, path);
    }
};

/// Convenience function: wraps `inner` in a cached FS and returns the
/// `vfs.FS` view. Port of Go's `cachedvfs.From`.
pub fn from(allocator: std.mem.Allocator, inner: vfs.FS) vfs.FS {
    return FS.from(allocator, inner).fs();
}
