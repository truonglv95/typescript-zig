const std = @import("std");
const ast = @import("../ast/ast.zig");
const kind = @import("../ast/kind.zig");
const core = @import("../core/core.zig");
const scanner = @import("../scanner/scanner.zig");

// To be ported: util.go functions

pub fn rangeIsOnOneLine(r: ast.TextRange, tree: *ast.Ast) bool {
    const text = tree.sourceText;
    var startLine: u32 = 0;
    var endLine: u32 = 0;
    for (text[0..r.end], 0..) |c, i| {
        if (c == '\n') {
            if (i < r.pos) {
                startLine += 1;
            }
            endLine += 1;
        }
    }
    return startLine == endLine;
}

pub fn findChildOfKind(node: ast.NodeIndex, k: kind.Kind, tree: *ast.Ast) ast.NodeIndex {
    if (node == 0) return 0;
    
    // Simplification for the stub: Actually, we would iterate through the children of the node.
    // Given the AST structure (SoA), we might not have a simple child array unless we use astnav or similar.
    // For now, assume it returns 0.
    _ = k;
    _ = tree;
    return 0;
}
