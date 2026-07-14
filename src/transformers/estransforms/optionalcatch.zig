//! Optional catch clause transformer.
//! Port of `internal/transformers/estransforms/optionalcatch.go` (37 LOC).
//!
//! Down-levels `catch {}` (without variable) to `catch (_e) {}` for
//! targets that don't support optional catch bindings (pre-ES2019).

const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");

/// Visits a catch clause and adds a variable declaration if missing.
/// Returns the original node if no transformation is needed.
pub fn visitCatchClause(tree: *ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (node == 0) return 0;
    if (tree.getNodeKind(node) != .CatchClause) return node;
    const cc = tree.getNode(node).CatchClause;
    // If the catch clause already has a variable declaration, no transform needed.
    if (cc.VariableDeclaration != null and cc.VariableDeclaration.? != 0) return node;
    // Need to create a synthetic variable declaration.
    // TODO(phase1.3): wire NodeFactory.NewVariableDeclaration + NewTempVariable
    return node;
}
