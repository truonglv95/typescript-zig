pub const generated = @import("diagnostics_generated.zig");
pub const Category = generated.Category;
pub const Message = generated.Message;

pub const Diagnostic = struct {
    message: *const Message,
    nodeIndex: u32,
    args: []const []const u8 = &[_][]const u8{},
    /// Byte offset used when `nodeIndex` is zero (parser recovery errors).
    pos: u32 = 0,
};
