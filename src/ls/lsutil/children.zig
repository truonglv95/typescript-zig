const std = @import("std");
const ast = @import("../../ast/ast.zig");
const astnav = @import("../../ast/ast_utils.zig");
const core = @import("../../core/core.zig");
const scanner = @import("../../scanner/scanner.zig");
const NodeIndex = ast.NodeIndex;

pub fn getLastChild(tree: *ast.Ast, node: NodeIndex) ?NodeIndex {
    const lastChildNode = getLastVisitedChild(tree, node);
    // TODO: implement isJSDocSingleCommentNode
    // if (astnav.isJSDocSingleCommentNode(tree, node) and lastChildNode == null) {
    //     return null;
    // }
    
    var tokenStartPos: u32 = 0;
    if (lastChildNode) |child| {
        tokenStartPos = tree.positions.items[child].end;
    } else {
        tokenStartPos = tree.positions.items[node].pos;
    }
    
    const lastToken: ?NodeIndex = null;
    var scan = scanner.getScannerForSourceFile(tree, tokenStartPos);
    var startPos = tokenStartPos;
    const nodeEnd = tree.positions.items[node].end;
    
    while (startPos < nodeEnd) {
        const tokenKind = scan.token();
        const tokenFullStart = scan.tokenFullStart();
        const tokenEnd = scan.tokenEnd();
        // TODO: tree.getOrCreateToken
        // lastToken = tree.getOrCreateToken(tokenKind, tokenFullStart, tokenEnd, node, scan.tokenFlags());
        _ = tokenKind;
        _ = tokenFullStart;
        startPos = tokenEnd;
        scan.scan();
    }
    
    if (lastToken) |tok| {
        return tok;
    }
    return lastChildNode;
}

pub fn getLastToken(tree: *ast.Ast, node: NodeIndex) ?NodeIndex {
    if (node == ast.nullNode) return null;
    
    const kind = tree.getNodeKind(node);
    if (astnav.isTokenKind(kind) or astnav.isIdentifier(kind)) {
        return null;
    }
    
    assertHasRealPosition(tree, node);
    
    const lastChild = getLastChild(tree, node) orelse return null;
    
    const childKind = tree.getNodeKind(lastChild);
    if (@intFromEnum(childKind) < @intFromEnum(ast.Kind.FirstNode)) {
        return lastChild;
    } else {
        return getLastToken(tree, lastChild);
    }
}

pub fn getLastVisitedChild(tree: *ast.Ast, node: NodeIndex) ?NodeIndex {
    _ = tree;
    _ = node;
    // TODO: implement astnav.visitEachChildAndJSDoc equivalent
    return null;
}

pub fn getFirstToken(tree: *ast.Ast, node: NodeIndex) ?NodeIndex {
    const kind = tree.getNodeKind(node);
    if (astnav.isIdentifier(kind) or astnav.isTokenKind(kind)) {
        return null;
    }
    
    assertHasRealPosition(tree, node);
    // TODO
    return null;
}

pub fn assertHasRealPosition(tree: *ast.Ast, node: NodeIndex) void {
    const pos = tree.positions.items[node].pos;
    const end = tree.positions.items[node].end;
    if (astnav.positionIsSynthesized(pos) or astnav.positionIsSynthesized(end)) {
        @panic("Node must have a real position for this operation.");
    }
}
