const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const kind = @import("../../ast/kind.zig");
const core = @import("../../core/core.zig");
const transformer_mod = @import("../transformer.zig");
const visitor_mod = @import("../../ast/visitor.zig");
const ast_utils = @import("../../ast/ast_utils.zig");

pub const ESModuleTransformer = struct {
    allocator: std.mem.Allocator,
    transformer: *transformer_mod.Transformer,
    compilerOptions: *core.CompilerOptions,
    currentSourceFile: ast_gen.NodeIndex = 0,

    pub fn newESModuleTransformer(allocator: std.mem.Allocator, opt: *transformer_mod.TransformOptions) !*transformer_mod.Transformer {
        const tx = try allocator.create(ESModuleTransformer);
        tx.allocator = allocator;
        tx.compilerOptions = opt.compilerOptions;
        tx.currentSourceFile = 0;

        tx.transformer = try transformer_mod.Transformer.init(allocator, visit, tx, opt.context);
        return tx.transformer;
    }

    fn visit(ctx: ?*anyopaque, visitor: *visitor_mod.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const self = @as(*ESModuleTransformer, @ptrCast(@alignCast(ctx.?)));
        const tree = visitor.tree;

        if (node == 0) return 0;

        const nodeData = tree.getNode(node);
        switch (nodeData) {
            .SourceFile => {
                return self.visitSourceFile(visitor, node);
            },
            // We just need the empty `export {};` for now, so we won't rewrite imports
            else => {
                return visitor.visitEachChild(node);
            },
        }
    }

    fn visitSourceFile(self: *ESModuleTransformer, visitor: *visitor_mod.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = visitor.tree;
        const n = tree.getNode(node).SourceFile;

        const force_module = (self.compilerOptions.moduleDetection orelse .Auto) == .Force;
        if (ast_utils.isDeclarationFile(tree, node) or
            (!ast_utils.isExternalModule(tree, node) and !(self.compilerOptions.isolatedModules orelse false)))
        {
            if (!force_module) return node;
        }

        self.currentSourceFile = node;

        // This transformer currently only adds the external-module marker; it
        // does not rewrite module syntax. Revisiting every statement here can
        // re-run child visitors over already transformed imports and elide a
        // side-effect-only import. Preserve the source-file statements as-is.
        var result = node;
        const resultNode = tree.getNode(result).SourceFile;

        // If it's an external module, and module kind != Preserve, and no statements are external module indicators
        if ((ast_utils.isExternalModule(tree, result) or force_module) and
            (self.compilerOptions.module orelse .None) != .Preserve)
        {
            var hasExternalModuleIndicator = false;
            const statsList = tree.getNodeList(resultNode.Statements);
            for (statsList) |stat| {
                if (ast_utils.isExternalModuleIndicator(tree, stat)) {
                    hasExternalModuleIndicator = true;
                    break;
                }
            }

            if (!hasExternalModuleIndicator) {
                // Add empty export {}
                var statements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
                statements.appendSlice(self.allocator, statsList) catch unreachable;

                // Create empty NamedExports
                const emptyNamedExports = self.transformer.factory.createNamedExports(0);
                const emptyExportDecl = self.transformer.factory.createExportDeclaration(0, false, emptyNamedExports, 0, 0);

                statements.append(self.allocator, emptyExportDecl) catch unreachable;

                const statementsNode = self.transformer.factory.newNodeList(statements.items);

                result = self.transformer.factory.updateSourceFile(result, resultNode, statementsNode, n.EndOfFileToken);
            }
        }

        self.currentSourceFile = 0;
        return result;
    }
};
