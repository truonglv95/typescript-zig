const std = @import("std");
const ast = @import("ast.zig");
const ast_gen = @import("ast_generated.zig");
const for_each = @import("for_each_child.zig");

const no_position: u32 = std.math.maxInt(u32);

/// Fill missing node start positions by propagating from descendants. Only `.pos` is
/// written; `.end` is left unchanged so emit formatting heuristics stay stable.
pub fn fillMissingNodePositions(tree: *ast.Ast, root: ast_gen.NodeIndex) void {
    if (root == 0) return;
    _ = fillNodeStart(tree, root);
    _ = fillNodeEnd(tree, root);
}

fn fillNodeStart(tree: *ast.Ast, node: ast_gen.NodeIndex) u32 {
    if (node == 0 or node >= tree.positions.items.len) return no_position;

    var min_child_pos: u32 = no_position;

    const Visitor = struct {
        tree: *ast.Ast,
        min_child_pos: *u32,

        pub fn visitNode(self: *@This(), child: ast_gen.NodeIndex) anyerror!void {
            const child_pos = fillNodeStart(self.tree, child);
            if (child_pos < self.min_child_pos.*) {
                self.min_child_pos.* = child_pos;
            }
        }

        pub fn visitList(self: *@This(), list: u32) anyerror!void {
            if (list == 0) return;
            for (self.tree.getNodeList(list)) |child| {
                try self.visitNode(child);
            }
        }
    };

    var visitor = Visitor{ .tree = tree, .min_child_pos = &min_child_pos };
    for_each.forEachChild(tree, node, &visitor) catch {};

    if (tree.positions.items[node].pos == 0 and min_child_pos != no_position) {
        tree.positions.items[node].pos = min_child_pos;
    }

    return tree.positions.items[node].pos;
}

fn fillNodeEnd(tree: *ast.Ast, node: ast_gen.NodeIndex) u32 {
    if (node == 0 or node >= tree.positions.items.len) return 0;

    var max_child_end: u32 = 0;

    const Visitor = struct {
        tree: *ast.Ast,
        max_child_end: *u32,

        pub fn visitNode(self: *@This(), child: ast_gen.NodeIndex) anyerror!void {
            const child_end = fillNodeEnd(self.tree, child);
            if (child_end > self.max_child_end.*) {
                self.max_child_end.* = child_end;
            }
        }

        pub fn visitList(self: *@This(), list: u32) anyerror!void {
            if (list == 0) return;
            for (self.tree.getNodeList(list)) |child| {
                try self.visitNode(child);
            }
        }
    };

    var visitor = Visitor{ .tree = tree, .max_child_end = &max_child_end };
    for_each.forEachChild(tree, node, &visitor) catch {};

    if (tree.positions.items[node].end == 0 and max_child_end != 0) {
        if (tree.getNodeKind(node) == .FunctionDeclaration) {
            std.debug.print("FunctionDeclaration max_child_end = {}\n", .{max_child_end});
        }
        tree.positions.items[node].end = max_child_end;
    }
    return tree.positions.items[node].end;
}
