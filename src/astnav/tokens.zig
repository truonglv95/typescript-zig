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
    _ = excludeJSDoc;
    
    const Visitor = struct {
        tree: *ast.Ast,
        position: u32,
        found: ast.NodeIndex = 0,

        pub fn check(self: *@This(), node: ast.NodeIndex) bool {
            if (node == 0) return false;
            if (self.tree.getNodeEnd(node) <= self.position) {
                self.found = node;
            }
            return false;
        }
    };

    var visitor = Visitor{
        .tree = a,
        .position = position,
    };
    
    const root = if (startNode != 0) startNode else sourceFile;
    _ = @import("../ast/ast_utils.zig").forEachChildBool(a, root, &visitor, Visitor.check);
    return visitor.found;
}

pub fn getStartOfNode(node: ast.NodeIndex, a: *ast.Ast, file: ast.NodeIndex, includeJSDoc: bool) u32 {
    _ = file;
    _ = includeJSDoc;
    return a.getNodePos(node);
}

pub fn findNextToken(previousToken: ast.NodeIndex, a: *ast.Ast, parent: ast.NodeIndex, file: ast.NodeIndex) ast.NodeIndex {
    _ = file;
    const end_pos = a.getNodeEnd(previousToken);
    
    const Visitor = struct {
        tree: *ast.Ast,
        end_pos: u32,
        found: ast.NodeIndex = 0,

        pub fn check(self: *@This(), node: ast.NodeIndex) bool {
            if (self.found != 0) return true;
            if (node == 0) return false;
            if (self.tree.getNodePos(node) >= self.end_pos) {
                self.found = node;
                return true;
            }
            return false;
        }
    };

    var visitor = Visitor{
        .tree = a,
        .end_pos = end_pos,
    };
    
    _ = @import("../ast/ast_utils.zig").forEachChildBool(a, parent, &visitor, Visitor.check);
    return visitor.found;
}

pub fn findChildOfKind(containingNode: ast.NodeIndex, a: *ast.Ast, searchKind: kind, sourceFile: ast.NodeIndex) ast.NodeIndex {
    _ = sourceFile;
    if (std.meta.activeTag(a.getNode(containingNode)) == searchKind) {
        return containingNode;
    }

    const Visitor = struct {
        tree: *ast.Ast,
        searchKind: kind,
        found: ast.NodeIndex = 0,

        pub fn check(self: *@This(), node: ast.NodeIndex) bool {
            if (self.found != 0) return true;
            if (node == 0) return false;
            
            if (std.meta.activeTag(self.tree.getNode(node)) == self.searchKind) {
                self.found = node;
                return true;
            }
            return false;
        }
    };

    var visitor = Visitor{
        .tree = a,
        .searchKind = searchKind,
    };
    
    _ = @import("../ast/ast_utils.zig").forEachChildBool(a, containingNode, &visitor, Visitor.check);
    return visitor.found;
}
