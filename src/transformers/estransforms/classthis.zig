const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");

//! Class this assignment block detection.
//! Port of `internal/transformers/estransforms/classthis.go` (28 LOC).

/// Returns true if `node` is a `static {}` block containing only a single
/// assignment of the static `this` to the `_classThis` variable.
pub fn isClassThisAssignmentBlock(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
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
    // Check for assignment expression (x = this)
    if (tree.getNodeKind(expr) != .BinaryExpression) return false;
    const binary = tree.getNode(expr).BinaryExpression;
    const op_kind = tree.getNodeKind(binary.OperatorToken);
    if (op_kind != .EqualsToken) return false;
    // Left should be an identifier, right should be `this`
    if (tree.getNodeKind(binary.Left) != .Identifier) return false;
    if (tree.getNodeKind(binary.Right) != .ThisKeyword) return false;
    // TODO(phase1.3): check that left identifier matches the classThis
    // stored in the block's EmitNode. For now, accept any `x = this`.
    return true;
}
