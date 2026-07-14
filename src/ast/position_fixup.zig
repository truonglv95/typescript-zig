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
}

fn fillNodeStart(tree: *ast.Ast, node: ast_gen.NodeIndex) u32 {
    if (node == 0 or node >= tree.positions.items.len) return no_position;

    var min_child_pos: u32 = no_position;

    const Visitor = struct {
        tree: *ast.Ast,
        min_child_pos: *u32,

        pub fn visitNode(self: *@This(), child: ast_gen.NodeIndex) anyerror!void {
            const child_pos = fillNodeStart(self.tree, child);
            if (child_pos != no_position) {
                self.min_child_pos.* = @min(self.min_child_pos.*, child_pos);
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

    const existing_pos = tree.positions.items[node].pos;
    if (existing_pos != 0) return existing_pos;

    if (min_child_pos != no_position) {
        tree.positions.items[node].pos = min_child_pos;
        return min_child_pos;
    }

    return no_position;
}
