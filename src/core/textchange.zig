const std = @import("std");
const ast = @import("../ast/ast.zig");

pub const TextChange = struct {
    range: ast.TextRange,
    newText: []const u8,
};
