const std = @import("std");
const ast = @import("ast.zig");
const ast_gen = @import("ast_generated.zig");

pub const NodeVisitorHooks = struct {
    visitNode: ?*const fn (visitor: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex = null,
    visitToken: ?*const fn (visitor: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex = null,
    visitNodes: ?*const fn (visitor: *NodeVisitor, nodes: u32) u32 = null,
    visitModifiers: ?*const fn (visitor: *NodeVisitor, nodes: u32) u32 = null,
    visitEmbeddedStatement: ?*const fn (visitor: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex = null,
    visitIterationBody: ?*const fn (visitor: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex = null,
    visitParameters: ?*const fn (visitor: *NodeVisitor, nodes: u32) u32 = null,
    visitFunctionBody: ?*const fn (visitor: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex = null,
    visitTopLevelStatements: ?*const fn (visitor: *NodeVisitor, nodes: u32) u32 = null,
};

pub const NodeVisitor = struct {
    pub fn visitSlice(self: *NodeVisitor, a: anytype) []const ast_gen.NodeIndex {
        _ = self;
        _ = a;
        return &[_]ast_gen.NodeIndex{};
    }

    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    ctx: ?*anyopaque,
    emitContext: ?*anyopaque = null,
    visitFn: *const fn (ctx: ?*anyopaque, visitor: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex,
    hooks: NodeVisitorHooks,

    pub fn init(
        allocator: std.mem.Allocator,
        tree: *ast.Ast,
        ctx: ?*anyopaque,
        visitFn: *const fn (ctx: ?*anyopaque, visitor: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex,
        hooks: NodeVisitorHooks,
    ) NodeVisitor {
        return .{
            .allocator = allocator,
            .tree = tree,
            .ctx = ctx,
            .visitFn = visitFn,
            .hooks = hooks,
        };
    }

    pub fn visitSourceFile(self: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        return self.visitNodeInternal(node);
    }

    pub fn visitNode(self: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        if (node == 0) return 0;
        const visited = self.visitFn(self.ctx, self, node);

        if (visited != 0) {
            const vData = self.tree.getNode(visited);
            if (vData == .SyntaxList) {
                const children = self.tree.getNodeList(vData.SyntaxList.Children);
                if (children.len != 1) {
                    std.debug.panic("Expected only a single node to be written to output", .{});
                }
                const single = children[0];
                if (single != 0) {
                    const sData = self.tree.getNode(single);
                    if (sData == .SyntaxList) {
                        std.debug.panic("The result of visiting and lifting a Node may not be SyntaxList", .{});
                    }
                }
                return single;
            }
        }
        return visited;
    }

    pub fn visitEmbeddedStatement(self: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        if (node == 0) return 0;
        const visited = self.visitFn(self.ctx, self, node);
        if (visited == 0) return 0;
        return self.liftToBlock(visited);
    }

    pub fn visitNodes(self: *NodeVisitor, nodesIndex: u32) u32 {
        if (nodesIndex == 0) return 0;

        const nodes_slice = self.tree.getNodeList(nodesIndex);
        const nodes = self.allocator.alloc(ast.NodeIndex, nodes_slice.len) catch unreachable;
        defer self.allocator.free(nodes);
        @memcpy(nodes, nodes_slice);

        var changed = false;
        var result = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer result.deinit(self.allocator);

        for (nodes, 0..) |n, i| {
            const visited = self.visitFn(self.ctx, self, n);
            if (visited == 0 or visited != n) {
                result.appendSlice(self.allocator, nodes[0..i]) catch unreachable;
                changed = true;

                var nodeIter = n;
                var visitedIter = visited;
                var idx = i;

                while (true) {
                    if (visitedIter != 0) {
                        const vNode = self.tree.getNode(visitedIter);
                        if (std.meta.activeTag(vNode) == .SyntaxList) {
                            const children = self.tree.getNodeList(vNode.SyntaxList.Children);
                            for (children) |c| {
                                result.append(self.allocator, c) catch unreachable;
                            }
                        } else {
                            result.append(self.allocator, visitedIter) catch unreachable;
                        }
                    }

                    idx += 1;
                    if (idx >= nodes.len) break;

                    nodeIter = nodes[idx];
                    visitedIter = self.visitFn(self.ctx, self, nodeIter);
                }
                break;
            }
        }

        if (changed) {
            const hasTrailingComma = if (nodesIndex == 0) false else self.tree.listHasTrailingComma(nodesIndex);
            return self.tree.pushNodeListWithTrailingComma(result.items, hasTrailingComma) catch unreachable;
        }

        return nodesIndex;
    }

    pub fn visitModifiers(self: *NodeVisitor, nodesIndex: u32) u32 {
        if (nodesIndex == 0) return 0;
        return self.visitNodes(nodesIndex);
    }

    pub fn visitEachChild(self: *NodeVisitor, nodeIndex: ast.NodeIndex) ast.NodeIndex {
        const generated = @import("visit_each_child.zig");
        return generated.visitEachChild(self, nodeIndex);
    }

    // --- Hooks dispatch ---

    pub fn visitNodeInternal(self: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        if (self.hooks.visitNode) |hook| {
            return hook(self, node);
        }
        return self.visitNode(node);
    }

    pub fn visitEmbeddedStatementInternal(self: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        if (self.hooks.visitEmbeddedStatement) |hook| {
            return hook(self, node);
        }
        if (self.hooks.visitNode) |hook| {
            return self.liftToBlock(hook(self, node));
        }
        return self.visitEmbeddedStatement(node);
    }

    pub fn visitIterationBodyInternal(self: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        if (self.hooks.visitIterationBody) |hook| {
            return hook(self, node);
        }
        return self.visitEmbeddedStatementInternal(node);
    }

    pub fn visitFunctionBodyInternal(self: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        if (self.hooks.visitFunctionBody) |hook| {
            return hook(self, node);
        }
        return self.visitNodeInternal(node);
    }

    pub fn visitTokenInternal(self: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        if (self.hooks.visitToken) |hook| {
            return hook(self, node);
        }
        return self.visitNodeInternal(node);
    }

    pub fn visitNodesInternal(self: *NodeVisitor, nodes: u32) u32 {
        if (self.hooks.visitNodes) |hook| {
            return hook(self, nodes);
        }
        return self.visitNodes(nodes);
    }

    pub fn visitModifiersInternal(self: *NodeVisitor, nodes: u32) u32 {
        if (self.hooks.visitModifiers) |hook| {
            return hook(self, nodes);
        }
        return self.visitModifiers(nodes);
    }

    pub fn visitParametersInternal(self: *NodeVisitor, nodes: u32) u32 {
        if (self.hooks.visitParameters) |hook| {
            return hook(self, nodes);
        }
        return self.visitNodesInternal(nodes);
    }

    pub fn visitTopLevelStatementsInternal(self: *NodeVisitor, nodes: u32) u32 {
        if (self.hooks.visitTopLevelStatements) |hook| {
            return hook(self, nodes);
        }
        return self.visitNodesInternal(nodes);
    }

    fn liftToBlock(self: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        if (node == 0) return 0;
        const nData = self.tree.getNode(node);
        if (nData == .SyntaxList) {
            std.debug.panic("The result of visiting and lifting a Node may not be SyntaxList", .{});
        }

        return node;
    }
};
