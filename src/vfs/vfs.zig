//! Virtual filesystem abstraction.
//!
//! Port of `internal/vfs/vfs.go` (88 LOC).
//!
//! `FS` is a file system abstraction backed by a vtable. Implementations
//! include:
//! - `osvfs` — OS-backed filesystem
//! - `cachedvfs` — caching wrapper
//! - `wrapvfs` — per-method override wrapper
//! - `trackingvfs` — records every accessed path (for watch mode)
//! - `iovfs` — wraps an `io/fs`-style filesystem
//! - `vfsmock` — mock for testing
//! - `vfstest` — in-memory map filesystem for testing

const std = @import("std");

/// Information about a file (port of Go's `fs.FileInfo`).
pub const FileInfo = struct {
    name: []const u8,
    size: u64,
    mode: u32,
    mod_time_unix_nano: i128,
    is_dir: bool,

    pub fn isDir(self: FileInfo) bool {
        return self.is_dir;
    }

    pub fn getName(self: FileInfo) []const u8 {
        return self.name;
    }

    pub fn getSize(self: FileInfo) u64 {
        return self.size;
    }

    pub fn getMode(self: FileInfo) u32 {
        return self.mode;
    }
};

/// A directory entry (port of Go's `fs.DirEntry`).
pub const DirEntry = struct {
    name: []const u8,
    is_dir: bool,
    type: u32, // FileMode

    pub fn isDirectory(self: DirEntry) bool {
        return self.is_dir;
    }

    pub fn getName(self: DirEntry) []const u8 {
        return self.name;
    }
};

/// The result of `getAccessibleEntries` — lists files, directories,
/// and symlinks in a directory.
pub const Entries = struct {
    files: []const []const u8 = &.{},
    directories: []const []const u8 = &.{},
    /// Names of entries that are symlinks (or reparse points on Windows).
    /// `null` means symlink info is not available.
    symlinks: ?std.StringHashMapUnmanaged(void) = null,
};

/// WalkDir callback function type. Receives the path, directory entry
/// (or null on error), and an optional error.
pub const WalkDirFunc = *const fn (path: []const u8, d: ?DirEntry, err: ?anyerror) anyerror!void;

/// SkipDir — returned from WalkDirFunc to skip the current directory's
/// children.
pub const skip_dir: anyerror = error.SkipDir;

/// SkipAll — returned from WalkDirFunc to stop walking entirely.
pub const skip_all: anyerror = error.SkipAll;

/// The virtual filesystem interface, backed by a vtable.
///
/// Port of Go's `FS` interface. Each method corresponds to a Go
/// interface method.
pub const FS = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        useCaseSensitiveFileNames: *const fn (ptr: *anyopaque) bool,
        fileExists: *const fn (ptr: *anyopaque, path: []const u8) bool,
        directoryExists: *const fn (ptr: *anyopaque, path: []const u8) bool,
        readFile: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) ?[]u8,
        writeFile: *const fn (ptr: *anyopaque, path: []const u8, data: []const u8) anyerror!void,
        appendFile: *const fn (ptr: *anyopaque, path: []const u8, data: []const u8) anyerror!void,
        remove: *const fn (ptr: *anyopaque, path: []const u8) anyerror!void,
        chtimes: *const fn (ptr: *anyopaque, path: []const u8, atime: i128, mtime: i128) anyerror!void,
        getAccessibleEntries: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) Entries,
        stat: *const fn (ptr: *anyopaque, path: []const u8) ?FileInfo,
        walkDir: *const fn (ptr: *anyopaque, root: []const u8, walk_fn: WalkDirFunc) anyerror!void,
        realpath: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) ?[]const u8,
    };

    pub fn useCaseSensitiveFileNames(self: FS) bool {
        return self.vtable.useCaseSensitiveFileNames(self.ptr);
    }

    pub fn fileExists(self: FS, path: []const u8) bool {
        return self.vtable.fileExists(self.ptr, path);
    }

    pub fn directoryExists(self: FS, path: []const u8) bool {
        return self.vtable.directoryExists(self.ptr, path);
    }

    pub fn readFile(self: FS, allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
        return self.vtable.readFile(self.ptr, allocator, path);
    }

    pub fn writeFile(self: FS, path: []const u8, data: []const u8) !void {
        return self.vtable.writeFile(self.ptr, path, data);
    }

    pub fn appendFile(self: FS, path: []const u8, data: []const u8) !void {
        return self.vtable.appendFile(self.ptr, path, data);
    }

    pub fn remove(self: FS, path: []const u8) !void {
        return self.vtable.remove(self.ptr, path);
    }

    pub fn chtimes(self: FS, path: []const u8, atime: i128, mtime: i128) !void {
        return self.vtable.chtimes(self.ptr, path, atime, mtime);
    }

    pub fn getAccessibleEntries(self: FS, allocator: std.mem.Allocator, path: []const u8) Entries {
        return self.vtable.getAccessibleEntries(self.ptr, allocator, path);
    }

    pub fn stat(self: FS, path: []const u8) ?FileInfo {
        return self.vtable.stat(self.ptr, path);
    }

    pub fn walkDir(self: FS, root: []const u8, walk_fn: WalkDirFunc) !void {
        return self.vtable.walkDir(self.ptr, root, walk_fn);
    }

    pub fn realpath(self: FS, allocator: std.mem.Allocator, path: []const u8) ?[]const u8 {
        return self.vtable.realpath(self.ptr, allocator, path);
    }
};
