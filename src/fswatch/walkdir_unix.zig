const std = @import("std");
const walkdir = @import("walkdir.zig");

pub fn walkDir(allocator: std.mem.Allocator, dir: []const u8, recursive: bool, fn_cb: walkdir.WalkFn) !void {
    return walkdir.walkDirGeneric(allocator, dir, recursive, fn_cb);
}
