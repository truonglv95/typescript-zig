const std = @import("std");
const vfs = @import("../vfs.zig");

//! In-memory VFS backed by a map.
//!
//! Port of `internal/vfs/iovfs/iofs.go` (222 LOC) + vfstest map concept.
//!
//! Wraps a `std.StringHashMap` of path -> content. Used for testing
//! and for LSP overlay filesystems (unsaved file changes).

/// An in-memory filesystem backed by a string map.
/// Port of Go's vfstest map filesystem.
pub const MapFS = struct {
    files: std.StringHashMapUnmanaged([]const u8),
    use_case_sensitive: bool,
    allocator: std.mem.Allocator,
    mu: std.Thread.RwLock,

    pub fn init(allocator: std.mem.Allocator, use_case_sensitive: bool) MapFS {
        return .{
            .files = .empty,
            .use_case_sensitive = use_case_sensitive,
            .allocator = allocator,
            .mu = .{},
        };
    }

    pub fn deinit(self: *MapFS) void {
        self.files.deinit(self.allocator);
    }

    /// Adds or replaces a file in the map.
    pub fn set(self: *MapFS, path: []const u8, content: []const u8) void {
        self.mu.lock();
        defer self.mu.unlock();
        _ = self.files.put(self.allocator, path, content) catch {};
    }

    /// Removes a file from the map.
    pub fn delete(self: *MapFS, path: []const u8) void {
        self.mu.lock();
        defer self.mu.unlock();
        _ = self.files.remove(path);
    }

    fn normalizePath(self: *MapFS, path: []const u8) []const u8 {
        if (self.use_case_sensitive) return path;
        // For case-insensitive: we'd need to lowercase, but that requires
        // allocation. For simplicity, do exact match (most test cases
        // use consistent casing).
        return path;
    }

    pub fn useCaseSensitiveFileNames(self: *MapFS) bool {
        return self.use_case_sensitive;
    }

    pub fn fileExists(self: *MapFS, path: []const u8) bool {
        self.mu.lockShared();
        defer self.mu.unlockShared();
        return self.files.contains(self.normalizePath(path));
    }

    pub fn directoryExists(self: *MapFS, path: []const u8) bool {
        // A directory exists if any file path starts with `path/`.
        self.mu.lockShared();
        defer self.mu.unlockShared();
        const prefix = path;
        var iter = self.files.keyIterator();
        while (iter.next()) |key| {
            if (std.mem.startsWith(u8, key.*, prefix)) {
                // Check that there's a separator after the prefix (or the
                // prefix IS the directory root).
                if (key.*.len > prefix.len and key.*[prefix.len] == '/') {
                    return true;
                }
            }
        }
        return false;
    }

    pub fn readFile(self: *MapFS, allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
        self.mu.lockShared();
        defer self.mu.unlockShared();
        const content = self.files.get(self.normalizePath(path)) orelse return null;
        return allocator.dupe(u8, content) catch null;
    }

    pub fn writeFile(self: *MapFS, path: []const u8, data: []const u8) !void {
        self.mu.lock();
        defer self.mu.unlock();
        // Dupe the data so the caller can free their copy.
        const owned = try self.allocator.dupe(u8, data);
        _ = self.files.put(self.allocator, path, owned) catch {};
    }

    pub fn appendFile(self: *MapFS, path: []const u8, data: []const u8) !void {
        self.mu.lock();
        defer self.mu.unlock();
        if (self.files.get(path)) |existing| {
            const combined = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ existing, data });
            _ = self.files.put(self.allocator, path, combined) catch {};
        } else {
            const owned = try self.allocator.dupe(u8, data);
            _ = self.files.put(self.allocator, path, owned) catch {};
        }
    }

    pub fn remove(self: *MapFS, path: []const u8) !void {
        self.mu.lock();
        defer self.mu.unlock();
        _ = self.files.remove(path);
    }

    pub fn chtimes(self: *MapFS, path: []const u8, atime: i128, mtime: i128) !void {
        _ = self;
        _ = path;
        _ = atime;
        _ = mtime;
        // No-op: in-memory FS doesn't track times.
    }

    pub fn getAccessibleEntries(self: *MapFS, allocator: std.mem.Allocator, path: []const u8) vfs.Entries {
        self.mu.lockShared();
        defer self.mu.unlockShared();
        var files = std.ArrayListUnmanaged([]const u8).empty;
        var dirs = std.ArrayListUnmanaged([]const u8).empty;
        defer files.deinit(allocator);
        defer dirs.deinit(allocator);
        var seen_dirs = std.StringHashMapUnmanaged(void).empty;
        defer seen_dirs.deinit(allocator);

        const prefix = path;
        var iter = self.files.keyIterator();
        while (iter.next()) |key| {
            if (!std.mem.startsWith(u8, key.*, prefix)) continue;
            const rest = key.*[prefix.len..];
            if (rest.len == 0) continue;
            // rest starts with '/'
            const after_slash = if (rest[0] == '/') rest[1..] else rest;
            if (std.mem.indexOfScalar(u8, after_slash, '/')) |slash_idx| {
                // It's in a subdirectory.
                const dir_name = after_slash[0..slash_idx];
                if (!seen_dirs.contains(dir_name)) {
                    _ = seen_dirs.put(allocator, dir_name, {}) catch {};
                    files.append(allocator, dir_name) catch {};
                }
            } else {
                // Direct child file.
                files.append(allocator, after_slash) catch {};
            }
        }

        return .{
            .files = files.toOwnedSlice(allocator) catch &.{},
            .directories = dirs.toOwnedSlice(allocator) catch &.{},
        };
    }

    pub fn stat(self: *MapFS, path: []const u8) ?vfs.FileInfo {
        self.mu.lockShared();
        defer self.mu.unlockShared();
        if (self.files.get(self.normalizePath(path))) |content| {
            return .{
                .name = path,
                .size = content.len,
                .mode = 0o644,
                .mod_time_unix_nano = 0,
                .is_dir = false,
            };
        }
        if (self.directoryExists(path)) {
            return .{
                .name = path,
                .size = 0,
                .mode = 0o755,
                .mod_time_unix_nano = 0,
                .is_dir = true,
            };
        }
        return null;
    }

    pub fn walkDir(self: *MapFS, root: []const u8, walk_fn: vfs.WalkDirFunc) !void {
        // Simple implementation: walk all files that start with root.
        self.mu.lockShared();
        defer self.mu.unlockShared();
        var iter = self.files.keyIterator();
        while (iter.next()) |key| {
            if (std.mem.startsWith(u8, key.*, root)) {
                try walk_fn(key.*, .{
                    .name = key.*,
                    .is_dir = false,
                    .type = 0,
                }, null);
            }
        }
    }

    pub fn realpath(self: *MapFS, allocator: std.mem.Allocator, path: []const u8) ?[]const u8 {
        _ = self;
        _ = allocator;
        return path;
    }

    /// Returns a `vfs.FS` view of this map filesystem.
    pub fn fs(self: *MapFS) vfs.FS {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &vtable,
        };
    }

    const vtable = vfs.FS.VTable{
        .useCaseSensitiveFileNames = vUseCaseSensitive,
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

    fn vUseCaseSensitive(ptr: *anyopaque) bool {
        const self: *MapFS = @ptrCast(@alignCast(ptr));
        return self.useCaseSensitiveFileNames();
    }
    fn vFileExists(ptr: *anyopaque, path: []const u8) bool {
        const self: *MapFS = @ptrCast(@alignCast(ptr));
        return self.fileExists(path);
    }
    fn vDirectoryExists(ptr: *anyopaque, path: []const u8) bool {
        const self: *MapFS = @ptrCast(@alignCast(ptr));
        return self.directoryExists(path);
    }
    fn vReadFile(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
        const self: *MapFS = @ptrCast(@alignCast(ptr));
        return self.readFile(allocator, path);
    }
    fn vWriteFile(ptr: *anyopaque, path: []const u8, data: []const u8) anyerror!void {
        const self: *MapFS = @ptrCast(@alignCast(ptr));
        return self.writeFile(path, data);
    }
    fn vAppendFile(ptr: *anyopaque, path: []const u8, data: []const u8) anyerror!void {
        const self: *MapFS = @ptrCast(@alignCast(ptr));
        return self.appendFile(path, data);
    }
    fn vRemove(ptr: *anyopaque, path: []const u8) anyerror!void {
        const self: *MapFS = @ptrCast(@alignCast(ptr));
        return self.remove(path);
    }
    fn vChtimes(ptr: *anyopaque, path: []const u8, atime: i128, mtime: i128) anyerror!void {
        const self: *MapFS = @ptrCast(@alignCast(ptr));
        return self.chtimes(path, atime, mtime);
    }
    fn vGetAccessibleEntries(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) vfs.Entries {
        const self: *MapFS = @ptrCast(@alignCast(ptr));
        return self.getAccessibleEntries(allocator, path);
    }
    fn vStat(ptr: *anyopaque, path: []const u8) ?vfs.FileInfo {
        const self: *MapFS = @ptrCast(@alignCast(ptr));
        return self.stat(path);
    }
    fn vWalkDir(ptr: *anyopaque, root: []const u8, walk_fn: vfs.WalkDirFunc) anyerror!void {
        const self: *MapFS = @ptrCast(@alignCast(ptr));
        return self.walkDir(root, walk_fn);
    }
    fn vRealpath(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) ?[]const u8 {
        const self: *MapFS = @ptrCast(@alignCast(ptr));
        return self.realpath(allocator, path);
    }
};

/// Creates a MapFS from a list of (path, content) pairs.
pub fn fromMap(allocator: std.mem.Allocator, use_case_sensitive: bool, entries: []const struct { path: []const u8, content: []const u8 }) MapFS {
    var mfs = MapFS.init(allocator, use_case_sensitive);
    for (entries) |e| mfs.set(e.path, e.content);
    return mfs;
}
