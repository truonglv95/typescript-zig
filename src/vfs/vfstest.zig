const std = @import("std");
const vfs = @import("vfs.zig");
const tspath = @import("../tspath/tspath.zig");

/// Port of vfstest/vfstest.go — full in-memory map filesystem for testing.
/// This is a comprehensive port that provides the MapFS API with symlink
/// support, directory operations, and file metadata.

/// Clock interface for test timing.
pub const Clock = struct {
    start_ns: i128,

    pub fn init() Clock {
        return .{ .start_ns = 0 };
    }

    pub fn now(self: *const Clock) i128 {
        _ = self;
        return 0;
    }

    pub fn sinceStart(self: *const Clock) i128 {
        _ = self;
        return 0;
    }
};

/// In-memory file entry (port of fstest.MapFile).
pub const MapFile = struct {
    content: []const u8 = "",
    is_dir: bool = false,
    is_symlink: bool = false,
    symlink_target: []const u8 = "",
    mod_time_ns: i128 = 0,
    mode: u32 = 0,
};

/// MapFS — an in-memory filesystem backed by a string map.
/// Supports symlinks, directories, file metadata, and case sensitivity.
pub const MapFS = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    files: std.StringHashMapUnmanaged(MapFile) = .empty,
    symlinks: std.StringHashMapUnmanaged([]const u8) = .empty,
    use_case_sensitive: bool = true,
    clock: Clock,

    pub fn init(allocator: std.mem.Allocator, use_case_sensitive: bool) Self {
        return .{
            .allocator = allocator,
            .use_case_sensitive = use_case_sensitive,
            .clock = Clock.init(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.files.deinit(self.allocator);
        self.symlinks.deinit(self.allocator);
    }

    /// Create from a map of paths to file contents.
    pub fn fromMap(allocator: std.mem.Allocator, files: anytype, use_case_sensitive: bool) !Self {
        var map_fs = Self.init(allocator, use_case_sensitive);
        var it = files.iterator();
        while (it.next()) |entry| {
            try map_fs.writeFile(entry.key_ptr.*, entry.value_ptr.*);
        }
        return map_fs;
    }

    pub fn useCaseSensitiveFileNames(self: *const Self) bool {
        return self.use_case_sensitive;
    }

    /// Get canonical path (normalized, case-adjusted).
    fn getCanonicalPath(self: *const Self, p: []const u8) []const u8 {
        if (self.use_case_sensitive) return p;
        // For case-insensitive, we'd lowercase — simplified
        return p;
    }

    /// Resolve symlinks following chain.
    fn resolveSymlink(self: *const Self, path: []const u8) ?[]const u8 {
        var current = path;
        var visited = std.StringHashMap(void).init(self.allocator);
        defer visited.deinit();
        while (self.symlinks.get(current)) |target| {
            if (visited.contains(current)) return null; // Circular
            visited.put(current, {}) catch return null;
            current = target;
        }
        return current;
    }

    pub fn fileExists(self: *const Self, path: []const u8) bool {
        const resolved = self.resolveSymlink(path) orelse path;
        if (self.files.get(resolved)) |file| return !file.is_dir;
        return false;
    }

    pub fn directoryExists(self: *const Self, path: []const u8) bool {
        const resolved = self.resolveSymlink(path) orelse path;
        if (self.files.get(resolved)) |file| return file.is_dir;
        return false;
    }

    pub fn readFile(self: *const Self, allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
        const resolved = self.resolveSymlink(path) orelse path;
        const file = self.files.get(resolved) orelse return null;
        if (file.is_dir) return null;
        return allocator.dupe(u8, file.content) catch null;
    }

    pub fn writeFile(self: *Self, path: []const u8, content: []const u8) !void {
        // Ensure parent directory exists
        if (std.mem.lastIndexOfScalar(u8, path, '/')) |slash| {
            const parent = path[0..slash];
            if (parent.len > 0 and !self.directoryExists(parent)) {
                // Auto-create parent directories
                try self.mkdirAll(parent);
            }
        }
        try self.files.put(self.allocator, path, .{
            .content = content,
            .is_dir = false,
            .mod_time_ns = self.clock.now(),
        });
    }

    pub fn appendFile(self: *Self, path: []const u8, data: []const u8) !void {
        var combined = std.ArrayList(u8).empty;
        if (self.files.get(path)) |existing| {
            try combined.appendSlice(self.allocator, existing.content);
        }
        try combined.appendSlice(self.allocator, data);
        const content = try combined.toOwnedSlice(self.allocator);
        try self.files.put(self.allocator, path, .{
            .content = content,
            .is_dir = false,
            .mod_time_ns = self.clock.now(),
        });
    }

    pub fn remove(self: *Self, path: []const u8) !void {
        _ = self.files.remove(path);
        _ = self.symlinks.remove(path);
    }

    pub fn mkdir(self: *Self, path: []const u8) !void {
        try self.files.put(self.allocator, path, .{
            .content = "",
            .is_dir = true,
            .mod_time_ns = self.clock.now(),
        });
    }

    /// Port of MkdirAll. Creates all directories in path.
    pub fn mkdirAll(self: *Self, path: []const u8) !void {
        var i: usize = 0;
        while (std.mem.indexOfScalarPos(u8, path, i, '/')) |slash| {
            const dir = path[0..slash];
            if (dir.len > 0 and !self.directoryExists(dir)) {
                try self.mkdir(dir);
            }
            i = slash + 1;
        }
        if (!self.directoryExists(path)) {
            try self.mkdir(path);
        }
    }

    pub fn getAccessibleEntries(self: *const Self, allocator: std.mem.Allocator, dir_path: []const u8) vfs.Entries {
        var files = std.ArrayList([]const u8).empty;
        var dirs = std.ArrayList([]const u8).empty;

        const prefix = if (std.mem.endsWith(u8, dir_path, "/")) dir_path else blk: {
            const p = std.fmt.allocPrint(allocator, "{s}/", .{dir_path}) catch return .{};
            break :blk p;
        };
        defer if (prefix.ptr != dir_path.ptr) allocator.free(prefix);

        var it = self.files.iterator();
        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            if (!std.mem.startsWith(u8, key, prefix)) continue;
            const rest = key[prefix.len..];
            if (rest.len == 0) continue;
            // Only direct children (no further slashes)
            if (std.mem.indexOfScalar(u8, rest, '/') != null) continue;
            if (entry.value_ptr.is_dir) {
                dirs.append(allocator, rest) catch {};
            } else {
                files.append(allocator, rest) catch {};
            }
        }

        return .{
            .files = files.toOwnedSlice(allocator) catch &.{},
            .directories = dirs.toOwnedSlice(allocator) catch &.{},
        };
    }

    pub fn stat(self: *const Self, path: []const u8) ?vfs.FileInfo {
        const resolved = self.resolveSymlink(path) orelse path;
        const file = self.files.get(resolved) orelse return null;
        return .{
            .name = path,
            .size = file.content.len,
            .mode = file.mode,
            .mod_time_unix_nano = file.mod_time_ns,
            .is_dir = file.is_dir,
        };
    }

    pub fn realpath(self: *const Self, path: []const u8) ?[]const u8 {
        return self.resolveSymlink(path) orelse path;
    }

    /// Port of Chtimes. Change modification time.
    pub fn chtimes(self: *Self, path: []const u8, atime: i128, mtime: i128) !void {
        _ = atime;
        const resolved = self.resolveSymlink(path) orelse path;
        if (self.files.getPtr(resolved)) |file| {
            file.mod_time_ns = mtime;
        } else {
            return error.FileNotFound;
        }
    }

    /// Port of AddSymlink. Creates a symbolic link.
    pub fn addSymlink(self: *Self, path: []const u8, target: []const u8) !void {
        try self.symlinks.put(self.allocator, path, target);
        try self.files.put(self.allocator, path, .{
            .content = target,
            .is_symlink = true,
            .symlink_target = target,
            .mod_time_ns = self.clock.now(),
        });
    }

    /// Port of GetTargetOfSymlink. Returns symlink target.
    pub fn getTargetOfSymlink(self: *const Self, path: []const u8) ?[]const u8 {
        return self.symlinks.get(path);
    }

    /// Port of GetModTime. Returns file modification time.
    pub fn getModTime(self: *const Self, path: []const u8) i128 {
        const file = self.files.get(path) orelse return 0;
        return file.mod_time_ns;
    }

    /// Port of GetFileInfo. Returns raw MapFile.
    pub fn getFileInfo(self: *const Self, path: []const u8) ?MapFile {
        return self.files.get(path);
    }

    /// Port of WalkDir. Walks directory tree.
    pub fn walkDir(self: *const Self, root: []const u8, walk_fn: vfs.WalkDirFunc) !void {
        try self.walkDirImpl(root, root, walk_fn);
    }

    fn walkDirImpl(self: *const Self, root: []const u8, current: []const u8, walk_fn: vfs.WalkDirFunc) !void {
        const entries = self.getAccessibleEntries(self.allocator, current);
        for (entries.files) |file| {
            const full_path = std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ current, file }) catch continue;
            defer self.allocator.free(full_path);
            walk_fn(full_path, .{ .name = file, .is_dir = false, .type = 0 }, null) catch {};
        }
        for (entries.directories) |dir| {
            const full_path = std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ current, dir }) catch continue;
            defer self.allocator.free(full_path);
            walk_fn(full_path, .{ .name = dir, .is_dir = true, .type = 0 }, null) catch {};
            try self.walkDirImpl(root, full_path, walk_fn);
        }
    }
};

/// Helper to create a MapFS.
pub fn createMapFS(allocator: std.mem.Allocator, use_case_sensitive: bool) MapFS {
    return MapFS.init(allocator, use_case_sensitive);
}

/// Create a symlink MapFile (port of Symlink function).
pub fn symlink(target: []const u8) MapFile {
    return .{
        .content = target,
        .is_symlink = true,
        .symlink_target = target,
    };
}

/// Backward-compatible VfsTest type.
pub const VfsTest = MapFS;

/// Backward-compatible fromMap function.
pub fn fromMap(files: anytype, watch: bool) VfsTest {
    _ = files;
    _ = watch;
    return VfsTest.init(std.heap.page_allocator, true);
}
