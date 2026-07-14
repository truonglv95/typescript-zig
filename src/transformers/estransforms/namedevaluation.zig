const std = @import("std");

//! Named evaluation transformer.
//!
//! Port of `internal/transformers/estransforms/namedevaluation.go` (537 LOC).
//!
//! Handles the "named evaluation" feature for anonymous function
//! definitions assigned to variables. In ES2015+, an anonymous function
//! or class expression assigned to a variable takes the variable's name:
//!
//!   `const f = function() {}` — `f.name` is `"f"`
//!   `const C = class {}` — `C.name` is `"C"`
//!
//! For targets that don't support this natively (pre-ES2015), we
//! inject a `__setFunctionName` helper call:
//!
//!   `const C = class {}` -> `const C = /*#__PURE__*/ __setFunctionName(class {}, "C")`

const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const ast_utils = @import("../../ast/ast_utils.zig");

/// Checks whether `node` is an anonymous function definition (ClassExpression,
/// FunctionExpression without name, or ArrowFunction).
///
/// Port of Go's `isAnonymousFunctionDefinition` (the core check without
/// the callback). Full Go version also takes a callback to inspect the
/// inner function definition; this port returns true for any anonymous
/// function definition.
pub fn isAnonymousFunctionDefinition(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    // Skip outer expressions (parentheses, type assertions, etc.)
    const skipped = skipOuterExpressions(tree, node);
    const kind = tree.getNodeKind(skipped);
    return switch (kind) {
        .ClassExpression => !classHasDeclaredOrExplicitlyAssignedName(tree, skipped),
        .FunctionExpression => {
            const fe = tree.getNode(skipped).FunctionExpression;
            return fe.name == null or fe.name.? == 0;
        },
        .ArrowFunction => true,
        else => false,
    };
}

/// Checks whether a class-like declaration has a declared name or contains
/// a `static {}` block with a `__setFunctionName` helper call.
///
/// Port of Go's `classHasDeclaredOrExplicitlyAssignedName`.
pub fn classHasDeclaredOrExplicitlyAssignedName(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    // Check if the class has a name.
    const kind = tree.getNodeKind(node);
    const name: ?u32 = switch (tree.getNode(node)) {
        .ClassDeclaration => |n| n.name,
        .ClassExpression => |n| n.name,
        else => null,
    };
    if (name != null and name.? != 0) return true;
    // Check for __setFunctionName helper block.
    return classHasExplicitlyAssignedName(tree, node);
}

/// Checks whether a class-like declaration contains a `static {}` block
/// with a single `__setFunctionName` call.
///
/// Port of Go's `classHasExplicitlyAssignedName`.
pub fn classHasExplicitlyAssignedName(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    const members_idx: u32 = switch (tree.getNode(node)) {
        .ClassDeclaration => |n| n.Members,
        .ClassExpression => |n| n.Members,
        else => return false,
    };
    if (members_idx == 0) return false;
    for (tree.getNodeList(members_idx)) |member| {
        if (isClassNamedEvaluationHelperBlock(tree, member)) return true;
    }
    return false;
}

/// Checks whether `node` is a `static {}` block containing only a single
/// call to `__setFunctionName`.
///
/// Port of Go's `isClassNamedEvaluationHelperBlock`.
pub fn isClassNamedEvaluationHelperBlock(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    if (tree.getNodeKind(node) != .ClassStaticBlockDeclaration) return false;
    const csb = tree.getNode(node).ClassStaticBlockDeclaration;
    const body = csb.Body;
    if (body == 0) return false;
    const body_data = tree.getNode(body);
    if (body_data != .Block) return false;
    const stmts = tree.getNodeList(body_data.Block.Statements);
    if (stmts.len != 1) return false;
    const stmt = stmts[0];
    if (tree.getNodeKind(stmt) != .ExpressionStatement) return false;
    const expr = tree.getNode(stmt).ExpressionStatement.Expression;
    if (expr == 0) return false;
    // Check if it's a call to __setFunctionName
    return isCallToHelper(tree, expr, "__setFunctionName");
}

/// Checks whether `node` is a call expression to the given helper function.
pub fn isCallToHelper(tree: *ast.Ast, node: ast_gen.NodeIndex, helper_name: []const u8) bool {
    if (node == 0) return false;
    if (tree.getNodeKind(node) != .CallExpression) return false;
    const call = tree.getNode(node).CallExpression;
    const expr = call.Expression;
    if (expr == 0) return false;
    // Check if the expression is an identifier matching helper_name.
    if (tree.getNodeKind(expr) == .Identifier) {
        const name_text = ast_utils.getText(tree, expr);
        return std.mem.eql(u8, name_text, helper_name);
    }
    return false;
}

/// Skips outer expressions (parenthesized, type assertions, non-null, etc.)
/// to find the inner expression. Port of Go's `ast.SkipOuterExpressions`.
pub fn skipOuterExpressions(tree: *ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    var current = node;
    while (current != 0) {
        const kind = tree.getNodeKind(current);
        switch (kind) {
            .ParenthesizedExpression => {
                const pe = tree.getNode(current).ParenthesizedExpression;
                current = pe.Expression;
            },
            .AsExpression => {
                const ae = tree.getNode(current).AsExpression;
                current = ae.Expression;
            },
            .TypeAssertionExpression => {
                const ta = tree.getNode(current).TypeAssertionExpression;
                current = ta.Expression;
            },
            .NonNullExpression => {
                const nn = tree.getNode(current).NonNullExpression;
                current = nn.Expression;
            },
            .PartiallyEmittedExpression => {
                const pe = tree.getNode(current).PartiallyEmittedExpression;
                current = pe.Expression;
            },
            else => return current,
        }
    }
    return current;
}

/// Creates a `__setFunctionName` call to assign a name to an anonymous
/// function/class expression.
///
/// Pattern: `__setFunctionName(expr, "name")`
///
/// TODO(phase1.3): wire NodeFactory for full implementation.
pub fn createSetFunctionNameCall(expr: ast_gen.NodeIndex, name: []const u8) ast_gen.NodeIndex {
    _ = expr;
    _ = name;
    // Full implementation requires:
    // - NodeFactory.NewCallExpression
    // - NodeFactory.NewIdentifier("__setFunctionName")
    // - NodeFactory.NewStringLiteral(name)
    return 0;
}
