const std = @import("std");
const ast = @import("../../ast/ast.zig");
const core = @import("../../core/core.zig");
const parser = @import("../../parser/parser.zig");
const utilities = @import("utilities.zig");

fn parseTS(allocator: std.mem.Allocator, text: []const u8) !*ast.Ast {
    _ = allocator;
    _ = text;
    // TODO: implement mock parser
    return error.NotImplemented;
}

test "ProbablyUsesSemicolons" {
    // TODO: implement tests
    // 1. mixed semicolons and ASI favors semicolons when ratio exceeds one fifth
    // 2. consistent ASI with no semicolons
    // 3. consistent semicolons
}
