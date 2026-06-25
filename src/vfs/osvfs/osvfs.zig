const std = @import("std");

pub const OSVFS = struct {
    pub fn ReadFile(self: *OSVFS, allocator: std.mem.Allocator, filename: []const u8) ![]u8 {
        _ = self;
        _ = filename;
        return allocator.dupe(u8, "");
    }
};

var instance = OSVFS{};

pub fn FS() *OSVFS {
    return &instance;
}
