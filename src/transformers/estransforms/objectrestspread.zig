const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const ast_utils = @import("../../ast/ast_utils.zig");
const core = @import("../../core/core.zig");
const destructuring = @import("../destructuring.zig");
const transformer_mod = @import("../transformer.zig");
const visitor_mod = @import("../../ast/visitor.zig");

pub const ObjectRestTransformer = struct {
    transformer: *transformer_mod.Transformer,
    allocator: std.mem.Allocator,
    options: *core.CompilerOptions,

    pub fn new(allocator: std.mem.Allocator, opt: *transformer_mod.TransformOptions) !*transformer_mod.Transformer {
        const tx = try allocator.create(ObjectRestTransformer);
        tx.allocator = allocator;
        tx.options = opt.compilerOptions;
        tx.transformer = try transformer_mod.Transformer.init(allocator, visit, tx, opt.context);
        return tx.transformer;
    }

    fn visit(ctx: ?*anyopaque, v: *visitor_mod.NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        const self: *ObjectRestTransformer = @ptrCast(@alignCast(ctx.?));
        if (node == 0) return 0;
        const target = self.options.target orelse .ES2025;
        if (@intFromEnum(target) >= @intFromEnum(core.ScriptTarget.ES2018)) return v.visitEachChild(node);
        return switch (v.tree.getNode(node)) {
            .CatchClause => |n| self.transformCatchClause(v, node, n),
            .VariableStatement => |n| self.transformVariableStatement(v, node, n),
            else => v.visitEachChild(node),
        };
    }

    fn transformCatchClause(self: *ObjectRestTransformer, v: *visitor_mod.NodeVisitor, node: ast.NodeIndex, catch_clause: ast_gen.CatchClauseNode) ast.NodeIndex {
        const variable = catch_clause.VariableDeclaration orelse return v.visitEachChild(node);
        if (variable == 0) return v.visitEachChild(node);
        const variable_data = v.tree.getNode(variable).VariableDeclaration;
        if (!destructuring.containsObjectRestOrSpread(v.tree, variable_data.name)) return v.visitEachChild(node);

        const temp = self.transformer.factory.createTempVariable() catch unreachable;
        const temp_declaration = self.transformer.factory.newVariableDeclaration(temp, 0, 0, 0);
        const flattened = destructuring.flattenDestructuringBinding(self.transformer, variable, temp, .ObjectRest, false, true) catch unreachable;

        var declarations = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer declarations.deinit(self.allocator);
        self.appendFlattened(v, &declarations, flattened);
        const declaration_list = self.transformer.factory.newVariableDeclarationList(self.transformer.factory.newNodeList(declarations.items), 0);
        const variable_statement = self.transformer.factory.newVariableStatement(0, declaration_list);

        const visited_block = v.visitNode(catch_clause.Block);
        const block = v.tree.getNode(visited_block).Block;
        var statements = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer statements.deinit(self.allocator);
        statements.append(self.allocator, variable_statement) catch unreachable;
        statements.appendSlice(self.allocator, v.tree.getNodeList(block.Statements)) catch unreachable;
        const updated_block = self.transformer.factory.updateBlock(visited_block, block, self.transformer.factory.newNodeList(statements.items), true);
        return self.transformer.factory.updateCatchClause(node, catch_clause, temp_declaration, updated_block);
    }

    fn transformVariableStatement(self: *ObjectRestTransformer, v: *visitor_mod.NodeVisitor, node: ast.NodeIndex, statement: ast_gen.VariableStatementNode) ast.NodeIndex {
        const list = v.tree.getNode(statement.DeclarationList).VariableDeclarationList;
        var declarations = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer declarations.deinit(self.allocator);
        var changed = false;
        for (v.tree.getNodeList(list.Declarations)) |declaration| {
            const declaration_data = v.tree.getNode(declaration).VariableDeclaration;
            if (destructuring.containsObjectRestOrSpread(v.tree, declaration_data.name)) {
                changed = true;
                const flattened = destructuring.flattenDestructuringBinding(self.transformer, declaration, 0, .ObjectRest, false, false) catch unreachable;
                self.appendFlattened(v, &declarations, flattened);
            } else {
                declarations.append(self.allocator, v.visitNode(declaration)) catch unreachable;
            }
        }
        if (!changed) return v.visitEachChild(node);

        if (ast_utils.hasSyntacticModifier(v.tree, node, ast_utils.ModifierFlags.Export) and
            declarations.items.len == 1 and !bindingPatternDeclaresName(v.tree, v.tree.getNode(v.tree.getNodeList(list.Declarations)[0]).VariableDeclaration.name))
        {
            const flattened = v.tree.getNode(declarations.items[0]).VariableDeclaration;
            const first_temp = flattened.name;
            const hoisted = self.transformer.factory.newVariableStatement(
                0,
                self.transformer.factory.newVariableDeclarationList(
                    self.transformer.factory.newNodeList(&[_]ast.NodeIndex{self.transformer.factory.newVariableDeclaration(first_temp, 0, 0, 0)}),
                    0,
                ),
            );
            const exported_temp = self.transformer.factory.createTempVariable() catch unreachable;
            const assignment = self.transformer.factory.newAssignmentExpression(first_temp, flattened.Initializer orelse 0);
            const exported_decl = self.transformer.factory.newVariableDeclaration(exported_temp, 0, 0, assignment);
            const exported_list = self.transformer.factory.newVariableDeclarationList(self.transformer.factory.newNodeList(&[_]ast.NodeIndex{exported_decl}), list.Flags);
            const exported_statement = self.transformer.factory.updateVariableStatement(node, statement, statement.modifiers orelse 0, exported_list);
            return self.transformer.factory.newSyntaxList(&[_]ast.NodeIndex{ hoisted, exported_statement });
        }

        const updated_list = self.transformer.factory.newVariableDeclarationList(self.transformer.factory.newNodeList(declarations.items), list.Flags);
        return self.transformer.factory.updateVariableStatement(node, statement, statement.modifiers orelse 0, updated_list);
    }

    fn appendFlattened(self: *ObjectRestTransformer, v: *visitor_mod.NodeVisitor, output: *std.ArrayListUnmanaged(ast.NodeIndex), flattened: ast.NodeIndex) void {
        if (flattened == 0) return;
        if (v.tree.getNode(flattened) == .SyntaxList) {
            output.appendSlice(self.allocator, v.tree.getNodeList(v.tree.getNode(flattened).SyntaxList.Children)) catch unreachable;
        } else {
            output.append(self.allocator, flattened) catch unreachable;
        }
    }
};

fn bindingPatternDeclaresName(tree: *ast.Ast, node: ast.NodeIndex) bool {
    return switch (tree.getNode(node)) {
        .Identifier => true,
        .ObjectBindingPattern => |n| blk: {
            for (tree.getNodeList(n.Elements)) |element| {
                const target = destructuring.getTargetOfBindingOrAssignmentElement(tree, element);
                if (target != 0 and bindingPatternDeclaresName(tree, target)) break :blk true;
            }
            break :blk false;
        },
        .ArrayBindingPattern => |n| blk: {
            for (tree.getNodeList(n.Elements)) |element| {
                const target = destructuring.getTargetOfBindingOrAssignmentElement(tree, element);
                if (target != 0 and bindingPatternDeclaresName(tree, target)) break :blk true;
            }
            break :blk false;
        },
        else => false,
    };
}
