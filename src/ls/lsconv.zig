pub const Converters = struct {
    pub fn lineAndCharacterToPosition(self: *Converters, file: anytype, position: anytype) u32 {
        _ = self; _ = file; _ = position; return 0;
    }
};

const std = @import("std");
pub fn fileNameToDocumentURI(allocator: std.mem.Allocator, filename: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "file://{s}", .{filename});
}
