const std = @import("std");

pub const embedded = false;

pub fn wrapFS(fs: anytype) @TypeOf(fs) {
    return fs;
}

pub fn IsBundled(path: []const u8) bool {
    _ = path;
    return false;
}
