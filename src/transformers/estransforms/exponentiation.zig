//! Exponentiation operator (`**`) transformer.
//! Port of `internal/transformers/estransforms/exponentiation.go` (90 LOC).
//!
//! Down-levels `a ** b` to `Math.pow(a, b)` and `a **= b` to
//! `a = Math.pow(a, b)` for targets that don't support the
//! exponentiation operator (pre-ES2016).

const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");

/// Checks if a binary expression uses the `**` or `**=` operator.
pub fn isExponentiationExpression(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    if (tree.getNodeKind(node) != .BinaryExpression) return false;
    const binary = tree.getNode(node).BinaryExpression;
    const op_kind = tree.getNodeKind(binary.OperatorToken);
    return op_kind == .AsteriskAsteriskToken or op_kind == .AsteriskAsteriskEqualsToken;
}

/// Transforms `a ** b` into `Math.pow(a, b)`.
/// TODO(phase1.3): wire NodeFactory for full transformation.
pub fn transformExponentiation(node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    // Full implementation requires:
    // - For `a ** b`: create Math.pow(a, b) call expression
    // - For `a **= b`: create temp variables for element access targets,
    //   then assign Math.pow(temp, b)
    return node;
}
