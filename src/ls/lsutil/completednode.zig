const std = @import("std");
const ast = @import("../../ast/ast.zig");
const astnav = @import("../../ast/ast_utils.zig");
const core = @import("../../core/core.zig");
const scanner = @import("../../scanner/scanner.zig");
const lsutil = @import("lsutil.zig");
const NodeIndex = ast.NodeIndex;

pub fn positionBelongsToNode(tree: *ast.Ast, candidate: NodeIndex, position: u32) bool {
    const candidatePos = tree.positions.items[candidate].pos;
    if (candidatePos > position) {
        @panic("Expected candidate.pos <= position");
    }
    const candidateEnd = tree.positions.items[candidate].end;
    return position < candidateEnd or !isCompletedNode(tree, candidate);
}

pub fn isCompletedNode(tree: *ast.Ast, n: NodeIndex) bool {
    if (n == ast.nullNode or astnav.nodeIsMissing(tree, n)) {
        return false;
    }
    
    const kind = tree.getNodeKind(n);
    switch (kind) {
        .ClassDeclaration,
        .InterfaceDeclaration,
        .EnumDeclaration,
        .ObjectLiteralExpression,
        .ObjectBindingPattern,
        .TypeLiteral,
        .Block,
        .ModuleBlock,
        .CaseBlock,
        .NamedImports,
        .NamedExports => return nodeEndsWith(tree, n, .CloseBraceToken),
        
        .CatchClause => {
            // TODO
            return true;
        },
        
        else => return true,
    }
}

pub fn nodeEndsWith(tree: *ast.Ast, n: NodeIndex, expectedLastToken: ast.Kind) bool {
    _ = tree;
    _ = n;
    _ = expectedLastToken;
    // TODO
    return false;
}

pub fn hasChildOfKind(tree: *ast.Ast, containingNode: NodeIndex, kind: ast.Kind) bool {
    _ = tree;
    _ = containingNode;
    _ = kind;
    // TODO
    return false;
}
