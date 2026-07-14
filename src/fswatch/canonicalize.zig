const std = @import("std");
const builtin = @import("builtin");

// canonicalizePath returns the path in the form the library uses for
// internal bookkeeping and event delivery.
pub fn canonicalizePath(allocator: std.mem.Allocator, p: []const u8) ![]const u8 {
    if (builtin.os.tag == .macos) {
        // TODO: implement normalizeNFC if needed, for now just dupe.
        return try allocator.dupe(u8, p);
    }
    return try allocator.dupe(u8, p);
}
