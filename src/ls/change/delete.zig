const std = @import("std");

//! Smart node deletion for code actions.
//!
//! Port of `internal/ls/change/delete.go` (270 LOC).
//!
//! Handles special cases when deleting AST nodes:
//! - Parameters (arrow functions with single param need `()`)
//! - Import declarations (preserve header comments)
//! - Binding elements (preserve commas in array patterns)
//! - Variable declarations (handle declaration lists)
//! - Type parameters (delete from lists)
//! - Export specifiers (delete from export clauses)

const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const tracker_mod = @import("tracker.zig");

/// Deletes a declaration node with smart handling for different node types.
/// Port of Go's `deleteDeclaration`.
pub fn deleteDeclaration(
    t: *tracker_mod.ChangeTracker,
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
) void {
    if (node == 0) return;
    const kind = tree.getNodeKind(node);
    switch (kind) {
        .Parameter => {
            // Handle arrow function with single parameter: `x => 1` -> `() => 1`
            const parent = tree.getNodeParent(node);
            if (parent != 0 and tree.getNodeKind(parent) == .ArrowFunction) {
                const params_idx = tree.getNode(parent).ArrowFunction.Parameters;
                const params = tree.getNodeList(params_idx);
                if (params.len == 1) {
                    // Replace parameter with `()`.
                    // TODO(phase3.2): wire t.replaceRangeWithText.
                } else {
                    deleteNodeInList(t, tree, node);
                }
            } else {
                deleteNodeInList(t, tree, node);
            }
        },
        .ImportDeclaration, .ImportEqualsDeclaration => {
            // Delete import, preserving header comments for first import.
            deleteNode(t, tree, node, .StartLine, .Include);
        },
        .BindingElement => {
            // Delete binding element, preserving comma in array patterns.
            deleteNodeInList(t, tree, node);
        },
        .VariableDeclaration => {
            // Delete variable from declaration list.
            deleteNodeInList(t, tree, node);
        },
        .TypeParameter => {
            deleteNodeInList(t, tree, node);
        },
        .ImportSpecifier, .ExportSpecifier => {
            // Delete specifier from named imports/exports.
            deleteNodeInList(t, tree, node);
        },
        else => {
            // Default: delete the node.
            deleteNode(t, tree, node, .StartLine, .Include);
        },
    }
}

/// Deletes a node from a comma-separated list (handling trailing/leading commas).
/// Port of Go's `deleteNodeInList`.
fn deleteNodeInList(t: *tracker_mod.ChangeTracker, tree: *ast.Ast, node: ast_gen.NodeIndex) void {
    _ = t;
    _ = tree;
    _ = node;
    // Full implementation:
    // 1. Find the parent list (Parameters, Imports, Exports, etc.)
    // 2. Determine if the node is first, middle, or last in the list
    // 3. Delete the node + appropriate comma + whitespace
    // TODO(phase3.2): wire full implementation.
}

/// Deletes a single node (not in a list).
/// Port of Go's `deleteNode`.
fn deleteNode(
    t: *tracker_mod.ChangeTracker,
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    leading: tracker_mod.LeadingTriviaOption,
    trailing: tracker_mod.TrailingTriviaOption,
) void {
    _ = t;
    _ = tree;
    _ = node;
    _ = leading;
    _ = trailing;
    // Full implementation:
    // 1. Compute the range to delete (including trivia based on options)
    // 2. Call t.deleteRange(range)
    // TODO(phase3.2): wire full implementation.
}
