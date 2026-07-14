const std = @import("std");
const ast = @import("../../ast/ast.zig");
const factory = @import("../../printer/factory.zig");
const kind = @import("../../ast/kind.zig");
const ast_utils = @import("../../ast/ast_utils.zig");

pub fn constantStringExpression(value: []const u8, f: *factory.NodeFactory) !ast.NodeIndex {
    return try f.newStringLiteral(value, 0);
}

pub fn constantNumberExpression(value: f64, f: *factory.NodeFactory) !ast.NodeIndex {
    if (std.math.isInf(value)) {
        if (value > 0) {
            return try f.newIdentifier("Infinity", 0);
        }
        const inf = try f.newIdentifier("Infinity", 0);
        return try f.newPrefixUnaryExpression(kind.Kind.MinusToken, inf);
    }
    if (std.math.isNan(value)) {
        return try f.newIdentifier("NaN", 0);
    }
    if (value < 0) {
        const inner = try constantNumberExpression(-value, f);
        return try f.newPrefixUnaryExpression(kind.Kind.MinusToken, inner);
    }
    
    // Convert f64 to string
    var buf: [64]u8 = undefined;
    const s = try std.fmt.bufPrint(&buf, "{d}", .{value});
    
    // We need to duplicate the string so it can be stored in the AST permanently
    const dup = try f.allocator.dupe(u8, s);
    return try f.newNumericLiteral(dup, 0);
}
