const std = @import("std");
const ast = @import("../../ast/ast.zig");
const astnav = @import("../../ast/ast_utils.zig");
const core = @import("../../core/core.zig");
const scanner = @import("../../scanner/scanner.zig");
const ast_kind = @import("../../ast/kind.zig");
const NodeIndex = ast.NodeIndex;

pub fn getLastChild(tree: *ast.Ast, node: NodeIndex) ?NodeIndex {
    const lastChildNode = getLastVisitedChild(tree, node);
    if (tree.getNodeKind(node) == .JSDoc and lastChildNode == null) {
        return null;
    }
    var tokenStartPos: u32 = 0;
    if (lastChildNode) |child| {
        tokenStartPos = tree.positions.items[child].end;
    } else {
        tokenStartPos = tree.positions.items[node].pos;
    }
    
    var scan = scanner.Scanner.init(tree.allocator, tree.sourceText);
    scan.resetPos(tokenStartPos);
    scan.setSkipTrivia(true);
    var startPos = tokenStartPos;
    const nodeEnd = tree.positions.items[node].end;
    
        var lastTokenNode: ?NodeIndex = null;
        while (startPos < nodeEnd) {
            const tokenKind = scan.getToken();
            const tokenFullStart: u32 = @intCast(scan.getTokenFullStart());
            const tokenEnd: u32 = @intCast(scan.getTokenEnd());
            lastTokenNode = getOrCreateToken(tree, tokenKind, tokenFullStart, tokenEnd, node);
            startPos = tokenEnd;
            scan.scan();
        }
        
        if (lastTokenNode) |tok| {
            return tok;
        }
    return lastChildNode;
}

pub fn getLastToken(tree: *ast.Ast, node: NodeIndex) ?NodeIndex {
    if (node == 0) return null;
    
    const kind = tree.getNodeKind(node);
    if (@import("../../ast/kind.zig").isTokenKind(kind) or astnav.isIdentifier(tree, node)) {
        return null;
    }
    
    assertHasRealPosition(tree, node);
    
    const lastChild = getLastChild(tree, node) orelse return null;
    
    const childKind = tree.getNodeKind(lastChild);
    if (@intFromEnum(childKind) < @intFromEnum(ast_kind.Kind.QualifiedName)) {
        return lastChild;
    } else {
        return getLastToken(tree, lastChild);
    }
}

pub fn getLastVisitedChild(tree: *ast.Ast, node: NodeIndex) ?NodeIndex {
    const VisitCtx = struct {
        tree: *ast.Ast,
        lastChild: ?NodeIndex,
        pub fn visitNode(self: *@This(), n: NodeIndex) anyerror!void {
            self.lastChild = n;
        }
        pub fn visitList(self: *@This(), list: u32) anyerror!void {
            for (self.tree.getNodeList(list)) |child| {
                try self.visitNode(child);
            }
        }
    };
    var ctx = VisitCtx{ .tree = tree, .lastChild = null };
    _ = ast.forEachChild(tree, node, &ctx) catch {};
    return ctx.lastChild;
}

pub fn getFirstToken(tree: *ast.Ast, node: NodeIndex) ?NodeIndex {
    const kind = tree.getNodeKind(node);
    if (astnav.isIdentifier(kind) or astnav.isTokenKind(kind)) {
        return null;
    }
    
    assertHasRealPosition(tree, node);
    var firstChild: ?NodeIndex = null;
    const VisitCtx = struct {
        tree: *ast.Ast,
        firstChild: *?NodeIndex,
        fn visit(ctx: *@This(), n: NodeIndex) bool {
            if (n == 0 or (ctx.tree.getNodeFlags(n) & astnav.NodeFlags.Reparsed) != 0) {
                return false;
            }
            ctx.firstChild.* = n;
            return true;
        }
    };
    var ctx = VisitCtx{ .tree = tree, .firstChild = &firstChild };
    _ = ast.forEachChild(tree, node, &ctx, VisitCtx.visit);

    var tokenEndPosition: u32 = 0;
    if (firstChild) |c| {
        tokenEndPosition = tree.positions.items[c].pos;
    } else {
        tokenEndPosition = tree.positions.items[node].end;
    }

    var scan = scanner.getScannerForSourceFile(tree, tree.positions.items[node].pos);
    var firstToken: ?NodeIndex = null;
    if (tree.positions.items[node].pos < tokenEndPosition) {
        const tokenKind = scan.token();
        const tokenFullStart = scan.tokenFullStart();
        const tokenEnd = scan.tokenEnd();
        firstToken = getOrCreateToken(tree, tokenKind, tokenFullStart, tokenEnd, node);
    }

    if (firstToken) |tok| {
        return tok;
    }
    if (firstChild == null) {
        return null;
    }
    const childKind = tree.getNodeKind(firstChild.?);
    if (@intFromEnum(childKind) < @intFromEnum(@import("../../ast/kind.zig").Kind.FirstNode)) {
        return firstChild;
    }
    return getFirstToken(tree, firstChild.?);
}

fn getOrCreateToken(tree: *ast.Ast, kind: ast_kind.Kind, fullStart: u32, end: u32, parent: ast.NodeIndex) ?ast.NodeIndex {
    const node = tree.pushTokenNode(kind) catch return null;
    tree.setNodePosition(node, fullStart, end);
    tree.setNodeParent(node, parent);
    return node;
}

pub fn assertHasRealPosition(tree: *ast.Ast, node: NodeIndex) void {
    const pos = tree.positions.items[node].pos;
    const end = tree.positions.items[node].end;
    if (pos < 0 or end < 0) {
        @panic("Node must have a real position for this operation.");
    }
}
