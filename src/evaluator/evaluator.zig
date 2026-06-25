const std = @import("std");
const ast = @import("../ast/ast.zig");
const kind = @import("../ast/kind.zig");

// Placeholder for jsnum which is not fully ported yet
pub const jsnum = struct {
    pub const Number = f64;
    pub const PseudoBigInt = []const u8;

    pub fn fromString(s: []const u8) Number {
        return std.fmt.parseFloat(f64, s) catch std.math.nan(f64);
    }
};

pub const Value = union(enum) {
    None: void,
    String: []const u8,
    Number: jsnum.Number,
    Boolean: bool,
    PseudoBigInt: jsnum.PseudoBigInt,
};

pub const Result = struct {
    value: Value,
    isSyntacticallyString: bool,
    resolvedOtherFiles: bool,
    hasExternalReferences: bool,
};

pub fn newResult(value: Value, isSyntacticallyString: bool, resolvedOtherFiles: bool, hasExternalReferences: bool) Result {
    return .{
        .value = value,
        .isSyntacticallyString = isSyntacticallyString,
        .resolvedOtherFiles = resolvedOtherFiles,
        .hasExternalReferences = hasExternalReferences,
    };
}

pub const EvaluatorCallback = *const fn (ctx: ?*anyopaque, ast_tree: *ast.Ast, expr: ast.NodeIndex, location: ast.NodeIndex) Result;

pub const Evaluator = struct {
    evaluateEntity: EvaluatorCallback,
    ctx: ?*anyopaque,
    outerExpressionsToSkip: u32,
    allocator: std.mem.Allocator,

    pub fn evaluate(self: *const Evaluator, ast_tree: *ast.Ast, expr: ast.NodeIndex, location: ast.NodeIndex) Result {
        var isSyntacticallyString = false;
        var resolvedOtherFiles = false;
        var hasExternalReferences = false;

        // TODO: SkipOuterExpressions is not implemented yet
        // expr = ast.SkipOuterExpressions(expr, outerExpressionsToSkip | ast.OEKParentheses);
        const skippedExpr = expr;

        const node = ast_tree.getNode(skippedExpr);
        const node_kind = std.meta.activeTag(node);

        switch (node_kind) {
            .PrefixUnaryExpression => {
                const unary = node.PrefixUnaryExpression;
                const result = self.evaluate(ast_tree, unary.Operand, location);
                resolvedOtherFiles = result.resolvedOtherFiles;
                hasExternalReferences = result.hasExternalReferences;

                if (result.value == .Number) {
                    const val = result.value.Number;
                    // Operator could be a NodeIndex pointing to a Token, so we need to get its kind
                    const operator_kind = std.meta.activeTag(ast_tree.getNode(unary.Operator));

                    switch (operator_kind) {
                        .PlusToken => return newResult(.{ .Number = val }, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences),
                        .MinusToken => return newResult(.{ .Number = -val }, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences),
                        .TildeToken => {
                            const int_val: i32 = @intFromFloat(val);
                            return newResult(.{ .Number = @floatFromInt(~int_val) }, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
                        },
                        else => {},
                    }
                }
            },
            .BinaryExpression => {
                const bin = node.BinaryExpression;
                const left = self.evaluate(ast_tree, bin.Left, location);
                const right = self.evaluate(ast_tree, bin.Right, location);
                
                const operator_node = ast_tree.getNode(bin.OperatorToken);
                const operator_kind = std.meta.activeTag(operator_node);

                isSyntacticallyString = (left.isSyntacticallyString or right.isSyntacticallyString) and operator_kind == .PlusToken;
                resolvedOtherFiles = left.resolvedOtherFiles or right.resolvedOtherFiles;
                hasExternalReferences = left.hasExternalReferences or right.hasExternalReferences;

                if (left.value == .Number and right.value == .Number) {
                    const leftNum = left.value.Number;
                    const rightNum = right.value.Number;
                    const leftInt: i32 = @intFromFloat(leftNum);
                    const rightInt: i32 = @intFromFloat(rightNum);

                    switch (operator_kind) {
                        .BarToken => return newResult(.{ .Number = @floatFromInt(leftInt | rightInt) }, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences),
                        .AmpersandToken => return newResult(.{ .Number = @floatFromInt(leftInt & rightInt) }, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences),
                        .GreaterThanGreaterThanToken => return newResult(.{ .Number = @floatFromInt(leftInt >> @intCast(rightInt & 0x1F)) }, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences),
                        .GreaterThanGreaterThanGreaterThanToken => {
                            const uLeftInt: u32 = @bitCast(leftInt);
                            return newResult(.{ .Number = @floatFromInt(uLeftInt >> @intCast(rightInt & 0x1F)) }, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
                        },
                        .LessThanLessThanToken => return newResult(.{ .Number = @floatFromInt(leftInt << @intCast(rightInt & 0x1F)) }, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences),
                        .CaretToken => return newResult(.{ .Number = @floatFromInt(leftInt ^ rightInt) }, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences),
                        .AsteriskToken => return newResult(.{ .Number = leftNum * rightNum }, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences),
                        .SlashToken => return newResult(.{ .Number = leftNum / rightNum }, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences),
                        .PlusToken => return newResult(.{ .Number = leftNum + rightNum }, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences),
                        .MinusToken => return newResult(.{ .Number = leftNum - rightNum }, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences),
                        .PercentToken => return newResult(.{ .Number = @mod(leftNum, rightNum) }, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences),
                        .AsteriskAsteriskToken => return newResult(.{ .Number = std.math.pow(f64, leftNum, rightNum) }, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences),
                        else => {},
                    }
                }

                if ((left.value == .String or left.value == .Number) and (right.value == .String or right.value == .Number) and operator_kind == .PlusToken) {
                    const leftStr = anyToString(self.allocator, left.value);
                    const rightStr = anyToString(self.allocator, right.value);
                    const combined = std.fmt.allocPrint(self.allocator, "{s}{s}", .{ leftStr, rightStr }) catch leftStr;
                    return newResult(.{ .String = combined }, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
                }
            },
            .StringLiteral, .NoSubstitutionTemplateLiteral => {
                // TODO: get text from AST node
                return newResult(.{ .String = "TODO_TEXT" }, true, false, false);
            },
            .TemplateExpression => {
                return self.evaluateTemplateExpression(ast_tree, skippedExpr, location);
            },
            .NumericLiteral => {
                // TODO: get text from AST node
                return newResult(.{ .Number = jsnum.fromString("0") }, false, false, false);
            },
            .Identifier => {
                return self.evaluateEntity(self.ctx, ast_tree, skippedExpr, location);
            },
            .ElementAccessExpression, .PropertyAccessExpression => {
                // TODO: ast.IsEntityNameExpression(expr.Expression())
                return self.evaluateEntity(self.ctx, ast_tree, skippedExpr, location);
            },
            else => {},
        }
        return newResult(.{ .None = {} }, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
    }

    fn evaluateTemplateExpression(self: *const Evaluator, ast_tree: *ast.Ast, expr: ast.NodeIndex, location: ast.NodeIndex) Result {
        // TODO: implement template expression evaluate
        _ = self;
        _ = ast_tree;
        _ = expr;
        _ = location;
        return newResult(.{ .String = "" }, true, false, false);
    }
};

pub fn anyToString(allocator: std.mem.Allocator, v: Value) []const u8 {
    switch (v) {
        .String => |s| return s,
        .Number => |n| return std.fmt.allocPrint(allocator, "{d}", .{n}) catch "",
        .Boolean => |b| return if (b) "true" else "false",
        .PseudoBigInt => |p| return p,
        .None => return "undefined",
    }
}

pub fn isTruthy(v: Value) bool {
    switch (v) {
        .String => |s| return s.len != 0,
        .Number => |n| return n != 0 and !std.math.isNan(n),
        .Boolean => |b| return b,
        .PseudoBigInt => |p| return p.len != 0,
        .None => return false,
    }
}
