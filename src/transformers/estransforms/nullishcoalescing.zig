//! Nullish coalescing operator (`??`) transformer.
//! Port of `internal/transformers/estransforms/nullishcoalescing.go` (49 LOC).
//!
//! Down-levels `a ?? b` to `a !== null && a !== undefined ? a : b` for
//! targets that don't support the nullish coalescing operator (pre-ES2020).

const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");

/// Checks if a binary expression uses the `??` operator.
pub fn isNullishCoalescingExpression(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    if (tree.getNodeKind(node) != .BinaryExpression) return false;
    const binary = tree.getNode(node).BinaryExpression;
    return tree.getNodeKind(binary.OperatorToken) == .QuestionQuestionToken;
}

/// Transforms `a ?? b` into a conditional expression.
/// TODO(phase1.3): wire NodeFactory for full transformation.
pub fn transformNullishCoalescing(node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    // Full implementation requires NodeFactory.NewConditionalExpression +
    // createNotNullCondition + temp variable for non-simple left side.
    return node;
}
