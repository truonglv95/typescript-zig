const std = @import("std");
const vfs = @import("vfs.zig");

//! Wrapping VFS that allows per-method overrides.
//!
//! Port of `internal/vfs/wrapvfs/wrapvfs.go` (132 LOC).
//!
//! Wraps an inner `FS` and allows individual methods to be replaced.
//! Methods that are not replaced delegate to the inner FS.

/// Optional function pointers for each FS method. `null` means "delegate
/// to inner FS". Port of Go's `wrapvfs.Replacements`.
pub const Replacements = struct {
    use_case_sensitive_file_names: ?*const fn () bool = null,
    file_exists: ?*const fn (path: []const u8) bool = null,
    read_file: ?*const fn (allocator: std.mem.Allocator, path: []const u8) ?[]u8 = null,
    write_file: ?*const fn (path: []const u8, data: []const u8) anyerror!void = null,
    append_file: ?*const fn (path: []const u8, data: []const u8) anyerror!void = null,
    remove: ?*const fn (path: []const u8) anyerror!void = null,
    chtimes: ?*const fn (path: []const u8, atime: i128, mtime: i128) anyerror!void = null,
    directory_exists: ?*const fn (path: []const u8) bool = null,
    get_accessible_entries: ?*const fn (allocator: std.mem.Allocator, path: []const u8) vfs.Entries = null,
    stat: ?*const fn (path: []const u8) ?vfs.FileInfo = null,
    walk_dir: ?*const fn (root: []const u8, walk_fn: vfs.WalkDirFunc) anyerror!void = null,
    realpath: ?*const fn (allocator: std.mem.Allocator, path: []const u8) ?[]const u8 = null,
};

/// A wrapping FS that delegates to replacements or the inner FS.
/// Port of Go's `wrappedFS`.
pub const WrappedFS = struct {
    inner: vfs.FS,
    replacements: Replacements,

    pub fn useCaseSensitiveFileNames(self: *WrappedFS) bool {
        if (self.replacements.use_case_sensitive_file_names) |f| return f();
        return self.inner.useCaseSensitiveFileNames();
    }

    pub fn fileExists(self: *WrappedFS, path: []const u8) bool {
        if (self.replacements.file_exists) |f| return f(path);
        return self.inner.fileExists(path);
    }

    pub fn directoryExists(self: *WrappedFS, path: []const u8) bool {
        if (self.replacements.directory_exists) |f| return f(path);
        return self.inner.directoryExists(path);
    }

    pub fn readFile(self: *WrappedFS, allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
        if (self.replacements.read_file) |f| return f(allocator, path);
        return self.inner.readFile(allocator, path);
    }

    pub fn writeFile(self: *WrappedFS, path: []const u8, data: []const u8) !void {
        if (self.replacements.write_file) |f| return f(path, data);
        return self.inner.writeFile(path, data);
    }

    pub fn appendFile(self: *WrappedFS, path: []const u8, data: []const u8) !void {
        if (self.replacements.append_file) |f| return f(path, data);
        return self.inner.appendFile(path, data);
    }

    pub fn remove(self: *WrappedFS, path: []const u8) !void {
        if (self.replacements.remove) |f| return f(path);
        return self.inner.remove(path);
    }

    pub fn chtimes(self: *WrappedFS, path: []const u8, atime: i128, mtime: i128) !void {
        if (self.replacements.chtimes) |f| return f(path, atime, mtime);
        return self.inner.chtimes(path, atime, mtime);
    }

    pub fn getAccessibleEntries(self: *WrappedFS, allocator: std.mem.Allocator, path: []const u8) vfs.Entries {
        if (self.replacements.get_accessible_entries) |f| return f(allocator, path);
        return self.inner.getAccessibleEntries(allocator, path);
    }

    pub fn stat(self: *WrappedFS, path: []const u8) ?vfs.FileInfo {
        if (self.replacements.stat) |f| return f(path);
        return self.inner.stat(path);
    }

    pub fn walkDir(self: *WrappedFS, root: []const u8, walk_fn: vfs.WalkDirFunc) !void {
        if (self.replacements.walk_dir) |f| return f(root, walk_fn);
        return self.inner.walkDir(root, walk_fn);
    }

    pub fn realpath(self: *WrappedFS, allocator: std.mem.Allocator, path: []const u8) ?[]const u8 {
        if (self.replacements.realpath) |f| return f(allocator, path);
        return self.inner.realpath(allocator, path);
    }

    /// Returns a `vfs.FS` view of this wrapped filesystem.
    pub fn fs(self: *WrappedFS) vfs.FS {
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
        const self: *WrappedFS = @ptrCast(@alignCast(ptr));
        return self.useCaseSensitiveFileNames();
    }

    fn vFileExists(ptr: *anyopaque, path: []const u8) bool {
        const self: *WrappedFS = @ptrCast(@alignCast(ptr));
        return self.fileExists(path);
    }

    fn vDirectoryExists(ptr: *anyopaque, path: []const u8) bool {
        const self: *WrappedFS = @ptrCast(@alignCast(ptr));
        return self.directoryExists(path);
    }

    fn vReadFile(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
        const self: *WrappedFS = @ptrCast(@alignCast(ptr));
        return self.readFile(allocator, path);
    }

    fn vWriteFile(ptr: *anyopaque, path: []const u8, data: []const u8) anyerror!void {
        const self: *WrappedFS = @ptrCast(@alignCast(ptr));
        return self.writeFile(path, data);
    }

    fn vAppendFile(ptr: *anyopaque, path: []const u8, data: []const u8) anyerror!void {
        const self: *WrappedFS = @ptrCast(@alignCast(ptr));
        return self.appendFile(path, data);
    }

    fn vRemove(ptr: *anyopaque, path: []const u8) anyerror!void {
        const self: *WrappedFS = @ptrCast(@alignCast(ptr));
        return self.remove(path);
    }

    fn vChtimes(ptr: *anyopaque, path: []const u8, atime: i128, mtime: i128) anyerror!void {
        const self: *WrappedFS = @ptrCast(@alignCast(ptr));
        return self.chtimes(path, atime, mtime);
    }

    fn vGetAccessibleEntries(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) vfs.Entries {
        const self: *WrappedFS = @ptrCast(@alignCast(ptr));
        return self.getAccessibleEntries(allocator, path);
    }

    fn vStat(ptr: *anyopaque, path: []const u8) ?vfs.FileInfo {
        const self: *WrappedFS = @ptrCast(@alignCast(ptr));
        return self.stat(path);
    }

    fn vWalkDir(ptr: *anyopaque, root: []const u8, walk_fn: vfs.WalkDirFunc) anyerror!void {
        const self: *WrappedFS = @ptrCast(@alignCast(ptr));
        return self.walkDir(root, walk_fn);
    }

    fn vRealpath(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) ?[]const u8 {
        const self: *WrappedFS = @ptrCast(@alignCast(ptr));
        return self.realpath(allocator, path);
    }
};

/// Wraps `inner` with the given `replacements` and returns a `vfs.FS` view.
/// Port of Go's `wrapvfs.Wrap`.
pub fn wrap(allocator: std.mem.Allocator, inner: vfs.FS, replacements: Replacements) vfs.FS {
    const w = allocator.create(WrappedFS) catch unreachable;
    w.* = .{ .inner = inner, .replacements = replacements };
    return w.fs();
}
