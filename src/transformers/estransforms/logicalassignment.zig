//! Logical assignment operator (`||=`, `&&=`, `??=`) transformer.
//! Port of `internal/transformers/estransforms/logicalassignment.go` (113 LOC).
//!
//! Down-levels `a ||= b` to `a || (a = b)`, `a &&= b` to `a && (a = b)`,
//! and `a ??= b` to `a ?? (a = b)` for targets that don't support
//! logical assignment operators (pre-ES2021).

const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");

/// Checks if a binary expression uses a logical assignment operator.
pub fn isLogicalAssignmentExpression(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    if (tree.getNodeKind(node) != .BinaryExpression) return false;
    const binary = tree.getNode(node).BinaryExpression;
    const op_kind = tree.getNodeKind(binary.OperatorToken);
    return op_kind == .BarBarEqualsToken or
        op_kind == .AmpersandAmpersandEqualsToken or
        op_kind == .QuestionQuestionEqualsToken;
}

/// Returns the non-assignment operator kind for a logical assignment.
/// `||=` -> `||`, `&&=` -> `&&`, `??=` -> `??`.
pub fn getNonAssignmentOperator(tree: *ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (node == 0) return 0;
    const binary = tree.getNode(node).BinaryExpression;
    const op_kind = tree.getNodeKind(binary.OperatorToken);
    return switch (op_kind) {
        .BarBarEqualsToken => .BarBarToken,
        .AmpersandAmpersandEqualsToken => .AmpersandAmpersandToken,
        .QuestionQuestionEqualsToken => .QuestionQuestionToken,
        else => .Unknown,
    };
}

/// Transforms `a ||= b` into `a || (a = b)`.
/// TODO(phase1.3): wire NodeFactory for full transformation.
pub fn transformLogicalAssignment(node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    // Full implementation requires:
    // - For access expressions (a.b, a[b]): create temp variable for the
    //   object to avoid double-evaluation
    // - Create conditional/assignment chain
    return node;
}
