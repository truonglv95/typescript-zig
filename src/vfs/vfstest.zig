const std = @import("std");
pub const VfsTest = struct {
    pub fn writeFile(self: *VfsTest, path: []const u8, content: []const u8) !void {
        _ = self;
        _ = path;
        _ = content;
    }
    pub fn remove(self: *VfsTest, path: []const u8) !void {
        _ = self;
        _ = path;
    }
    pub fn useCaseSensitiveFileNames(self: *VfsTest) bool {
        _ = self;
        return true;
    }
};
pub fn fromMap(files: anytype, watch: bool) VfsTest {
    _ = files; _ = watch;
    return .{};
}
pub fn symlink(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    _ = path;
    return try allocator.dupe(u8, "/dummy/symlink/target");
}
