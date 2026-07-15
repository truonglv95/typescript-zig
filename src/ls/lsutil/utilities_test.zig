const std = @import("std");
const ast = @import("../../ast/ast.zig");
const core = @import("../../core/core.zig");
const parser = @import("../../parser/parser.zig");
const utilities = @import("utilities.zig");

fn parseTS(allocator: std.mem.Allocator, text: []const u8) !*ast.Ast {
    _ = allocator;
    _ = text;
    return error.NotImplemented;
}

test "ProbablyUsesSemicolons" {
}
