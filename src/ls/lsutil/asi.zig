const std = @import("std");
const ast = @import("../../ast/ast.zig");
const astnav = @import("../../ast/ast_utils.zig"); // Might need to change to actual file if different
const scanner = @import("../../scanner/scanner.zig");

// To be fully implemented
pub fn positionIsASICandidate(tree: *ast.Ast, pos: u32, contextNode: ast.NodeIndex) bool {
    _ = tree;
    _ = pos;
    _ = contextNode;
    // TODO
    return false;
}
