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

pub fn visitEachChildAndJSDoc(
    node: ast.NodeIndex,
    a: *ast.Ast,
    sourceFile: ast.NodeIndex,
    // Note: Zig uses contexts or fn pointers for visitors, depending on the architecture
) void {
    _ = node;
    _ = a;
    _ = sourceFile;
    @panic("TODO: visitEachChildAndJSDoc");
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
    @panic("TODO: findPrecedingTokenEx");
}

pub fn getStartOfNode(node: ast.NodeIndex, a: *ast.Ast, file: ast.NodeIndex, includeJSDoc: bool) u32 {
    _ = node;
    _ = a;
    _ = file;
    _ = includeJSDoc;
    @panic("TODO: getStartOfNode");
}

pub fn findNextToken(previousToken: ast.NodeIndex, a: *ast.Ast, parent: ast.NodeIndex, file: ast.NodeIndex) ast.NodeIndex {
    _ = previousToken;
    _ = a;
    _ = parent;
    _ = file;
    @panic("TODO: findNextToken");
}

pub fn findChildOfKind(containingNode: ast.NodeIndex, a: *ast.Ast, searchKind: kind, sourceFile: ast.NodeIndex) ast.NodeIndex {
    _ = containingNode;
    _ = a;
    _ = searchKind;
    _ = sourceFile;
    @panic("TODO: findChildOfKind");
}
