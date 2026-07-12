const std = @import("std");
const ast = @import("../ast/ast.zig");
const core = @import("../core/core.zig");
const scanner = @import("../scanner/scanner.zig");
const kind = @import("../ast/kind.zig").Kind;

const GetTouchingNodeVisitor = struct {
    tree: *ast.Ast,
    position: u32,
    found: ast.NodeIndex = 0,

    pub fn visitNode(self: *@This(), node: ast.NodeIndex) anyerror!void {
        if (self.found != 0) return;
        const pos = self.tree.getNodePos(node);
        const end = self.tree.getNodeEnd(node);

        if (pos <= self.position and self.position <= end) {
            var childVisitor = GetTouchingNodeVisitor{
                .tree = self.tree,
                .position = self.position,
                .found = 0,
            };
            try ast.forEachChild(self.tree, node, &childVisitor);
            if (childVisitor.found != 0) {
                self.found = childVisitor.found;
            } else {
                self.found = node;
            }
        }
    }

    pub fn visitList(self: *@This(), list: u32) anyerror!void {
        for (self.tree.getNodeList(list)) |child| {
            try self.visitNode(child);
            if (self.found != 0) break;
        }
    }
};

pub fn getTouchingPropertyName(sourceFile: ast.NodeIndex, a: *ast.Ast, position: u32) ast.NodeIndex {
    var visitor = GetTouchingNodeVisitor{
        .tree = a,
        .position = position,
        .found = 0,
    };
    visitor.visitNode(sourceFile) catch {};
    if (visitor.found == 0) return sourceFile;
    return visitor.found;
}

pub fn getTouchingToken(sourceFile: ast.NodeIndex, a: *ast.Ast, position: u32) ast.NodeIndex {
    return getTouchingPropertyName(sourceFile, a, position);
}

pub fn getTokenAtPosition(sourceFile: ast.NodeIndex, a: *ast.Ast, position: u32) ast.NodeIndex {
    return getTouchingPropertyName(sourceFile, a, position);
}

pub fn visitEachChildAndJSDoc(a: *ast.Ast, node: ast.NodeIndex) void {
    _ = a;
    _ = node;
}

pub fn findPrecedingToken(sourceFile: ast.NodeIndex, a: *ast.Ast, position: u32) ast.NodeIndex {
    _ = sourceFile;
    var best: ast.NodeIndex = 0;
    var max_end: u32 = 0;
    for (1..a.nodes.len) |i| {
        const idx: u32 = @intCast(i);
        const node_range = a.positions.items[idx];
        if (node_range.end <= position and node_range.end >= max_end) {
            const k = std.meta.activeTag(a.getNode(idx));
            if (@intFromEnum(k) <= 166) { // 166 is DeferKeyword, the last token
                if (node_range.end > max_end) {
                    max_end = node_range.end;
                    best = idx;
                }
            }
        }
    }
    return best;
}

pub fn findPrecedingTokenEx(sourceFile: ast.NodeIndex, a: *ast.Ast, position: u32, startNode: ast.NodeIndex, excludeJSDoc: bool) ast.NodeIndex {
    _ = sourceFile;
    _ = a;
    _ = position;
    _ = startNode;
    _ = excludeJSDoc;
    return 0; // TODO
}

pub fn getStartOfNode(node: ast.NodeIndex, a: *ast.Ast, file: ast.NodeIndex, includeJSDoc: bool) u32 {
    _ = file;
    _ = includeJSDoc;
    return a.getNodePos(node);
}

pub fn findNextToken(previousToken: ast.NodeIndex, a: *ast.Ast, parent: ast.NodeIndex, file: ast.NodeIndex) ast.NodeIndex {
    _ = previousToken;
    _ = a;
    _ = parent;
    _ = file;
    return 0; // TODO
}

pub fn findChildOfKind(containingNode: ast.NodeIndex, a: *ast.Ast, searchKind: kind, sourceFile: ast.NodeIndex) ast.NodeIndex {
    _ = containingNode;
    _ = a;
    _ = searchKind;
    _ = sourceFile;
    return 0; // TODO
}
