const std = @import("std");

//! JSDoc support for language service.
//!
//! Port of `internal/ls/jsdoc.go` (161 LOC).
//!
//! Provides JSDoc comment parsing and snippet generation for
//! completion and hover.

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");

/// Returns the JSDoc tags for a node.
pub fn getJSDocTags(tree: *ast.Ast, node: ast_gen.NodeIndex) []const ast_gen.NodeIndex {
    _ = tree;
    _ = node;
    // Full implementation: walk JSDoc comments and extract tags.
    // TODO(phase3.3): wire JSDoc parser integration.
    return &.{};
}

/// Returns the JSDoc comment text for a node (for hover display).
pub fn getJSDocText(tree: *ast.Ast, node: ast_gen.NodeIndex) []const u8 {
    _ = tree;
    _ = node;
    // Full implementation: find JSDoc comment, extract text.
    // TODO(phase3.3): wire JSDoc parser integration.
    return "";
}

/// Returns true if the node has a JSDoc `@deprecated` tag.
pub fn isDeprecated(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    _ = tree;
    _ = node;
    // Full implementation: check for @deprecated tag.
    // TODO(phase3.3): wire JSDoc parser integration.
    return false;
}
