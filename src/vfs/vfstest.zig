const std = @import("std");
const vfs = @import("vfs.zig");

/// Port of vfstest/vfstest.go — in-memory map filesystem for testing.
/// This is a simplified port that provides the core MapFS functionality.

/// In-memory file entry.
pub const MapFile = struct {
    content: []const u8,
    is_dir: bool = false,
    mod_time_unix_nano: i128 = 0,
};

/// MapFS — an in-memory filesystem backed by a string map.
pub const MapFS = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    files: std.StringHashMapUnmanaged(MapFile) = .empty,
    use_case_sensitive: bool = true,
    start_time: i128 = 0,

    pub fn init(allocator: std.mem.Allocator, use_case_sensitive: bool) Self {
        return .{
            .allocator = allocator,
            .use_case_sensitive = use_case_sensitive,
            .start_time = std.time.nanoTimestamp(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.files.deinit(self.allocator);
    }

    /// Create from a map of paths to file contents.
    pub fn fromMap(allocator: std.mem.Allocator, files: anytype, use_case_sensitive: bool) !Self {
        var map_fs = Self.init(allocator, use_case_sensitive);
        var it = files.iterator();
        while (it.next()) |entry| {
            try map_fs.files.put(allocator, entry.key_ptr.*, .{
                .content = entry.value_ptr.*,
                .is_dir = false,
            });
        }
        return map_fs;
    }

    pub fn useCaseSensitiveFileNames(self: *const Self) bool {
        return self.use_case_sensitive;
    }

    pub fn fileExists(self: *const Self, path: []const u8) bool {
        return self.files.contains(path);
    }

    pub fn directoryExists(self: *const Self, path: []const u8) bool {
        if (self.files.get(path)) |file| return file.is_dir;
        return false;
    }

    pub fn readFile(self: *const Self, allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
        const file = self.files.get(path) orelse return null;
        return allocator.dupe(u8, file.content) catch null;
    }

    pub fn writeFile(self: *Self, path: []const u8, content: []const u8) !void {
        try self.files.put(self.allocator, path, .{
            .content = content,
            .is_dir = false,
        });
    }

    pub fn remove(self: *Self, path: []const u8) !void {
        _ = self.files.remove(path);
    }

    pub fn getAccessibleEntries(self: *const Self, allocator: std.mem.Allocator, dir_path: []const u8) vfs.Entries {
        var files = std.ArrayList([]const u8).empty;
        var dirs = std.ArrayList([]const u8).empty;

        var it = self.files.iterator();
        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            // Check if key starts with dir_path
            if (std.mem.startsWith(u8, key, dir_path)) {
                const rest = key[dir_path.len..];
                if (rest.len == 0) continue;
                // Check if it's a direct child
                if (std.mem.indexOfScalar(u8, rest, '/') == null) {
                    // Direct child
                    if (entry.value_ptr.is_dir) {
                        dirs.append(allocator, rest) catch {};
                    } else {
                        files.append(allocator, rest) catch {};
                    }
                }
            }
        }

        return .{
            .files = files.toOwnedSlice(allocator) catch &.{},
            .directories = dirs.toOwnedSlice(allocator) catch &.{},
        };
    }

    pub fn stat(self: *const Self, path: []const u8) ?vfs.FileInfo {
        const file = self.files.get(path) orelse return null;
        return .{
            .name = path,
            .size = file.content.len,
            .mode = if (file.is_dir) 0x80000000 else 0,
            .mod_time_unix_nano = file.mod_time_unix_nano,
            .is_dir = file.is_dir,
        };
    }

    pub fn realpath(self: *const Self, path: []const u8) ?[]const u8 {
        // MapFS doesn't have symlinks in this simplified version
        if (self.files.contains(path)) return path;
        return null;
    }

    pub fn mkdir(self: *Self, path: []const u8) !void {
        try self.files.put(self.allocator, path, .{
            .content = "",
            .is_dir = true,
        });
    }
};

/// Helper to create a MapFS from a list of file paths and contents.
pub fn createMapFS(allocator: std.mem.Allocator, use_case_sensitive: bool) MapFS {
    return MapFS.init(allocator, use_case_sensitive);
}

/// Backward-compatible VfsTest struct (simplified).
pub const VfsTest = MapFS;

/// Backward-compatible fromMap function.
pub fn fromMap(files: anytype, watch: bool) VfsTest {
    _ = files;
    _ = watch;
    return VfsTest.init(std.heap.page_allocator, true);
}

/// Backward-compatible symlink function.
pub fn symlink(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    _ = path;
    return try allocator.dupe(u8, "/dummy/symlink/target");
}
