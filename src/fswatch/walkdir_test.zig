const std = @import("std");
const testing = std.testing;
const walkdir = @import("walkdir.zig");
const walkdir_unix = @import("walkdir_unix.zig");

const WalkDirFunc = *const fn (allocator: std.mem.Allocator, dir: []const u8, recursive: bool, fn_cb: walkdir.WalkFn) anyerror!void;

fn runWalkDirTest(allocator: std.mem.Allocator, test_fn: *const fn (allocator: std.mem.Allocator, walk: WalkDirFunc) anyerror!void) !void {
    const fns = [_]WalkDirFunc{ walkdir_unix.walkDir, walkdir.walkDirGeneric };
    for (fns) |f| {
        try test_fn(allocator, f);
    }
}

fn testWalkDirMissingDir(allocator: std.mem.Allocator, walk: WalkDirFunc) !void {
    const dir = "nonexistent_dir_walkdir_test_123";
    const err = walk(allocator, dir, true, .{});
    try testing.expectError(error.ENOENT, err);
}

fn testWalkDirNotADir(allocator: std.mem.Allocator, walk: WalkDirFunc) !void {
    const f = "file_walkdir_test_123";
    const file = try std.Io.Dir.cwd().createFile(f, .{});
    file.close(std.testing.io);
    defer std.Io.Dir.cwd().deleteFile(std.testing.io, f) catch {};

    const err = walk(allocator, f, true, .{});
    try testing.expectError(error.NotDir, err);
}

test "WalkDirMissingDir" {
    try runWalkDirTest(testing.allocator, testWalkDirMissingDir);
}

test "WalkDirNotADir" {
    try runWalkDirTest(testing.allocator, testWalkDirNotADir);
}
