const std = @import("std");

pub fn countPathComponents(path: []const u8) usize {
    var initial: usize = 0;
    if (std.mem.startsWith(u8, path, "./")) {
        initial = 2;
    }
    return std.mem.count(u8, path[initial..], "/");
}
