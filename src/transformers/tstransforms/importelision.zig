const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const ast_utils = @import("../../ast/ast_utils.zig");
const core = @import("../../core/core.zig");
const printer = @import("../../printer/printer.zig");
const transformers = @import("../transformer.zig");
const emitresolver = @import("../../printer/emitresolver.zig");
const visitor = @import("../../ast/visitor.zig");

pub const ImportElisionTransformer = struct {
    allocator: std.mem.Allocator,
    transformer: *transformers.Transformer,
    compilerOptions: *core.CompilerOptions,
    currentSourceFile: ?ast_gen.SourceFileNode,
    emitResolver: *emitresolver.EmitResolver,
    referenced_names: std.StringHashMapUnmanaged(void) = .empty,
    has_jsx: bool = false,

    pub fn new(allocator: std.mem.Allocator, opt: *transformers.TransformOptions) !*transformers.Transformer {
        const compilerOptions = opt.compilerOptions;
        if (compilerOptions.verbatimModuleSyntax orelse false) {
            @panic("ImportElisionTransformer should not be used with VerbatimModuleSyntax");
        }

        var tx = try allocator.create(ImportElisionTransformer);
        tx.* = .{
            .allocator = allocator,
            .transformer = undefined,
            .compilerOptions = compilerOptions,
            .currentSourceFile = null,
            .emitResolver = opt.emitResolver,
            .referenced_names = .empty,
            .has_jsx = false,
        };
        tx.transformer = try transformers.Transformer.init(allocator, visit, tx, opt.context);
        return tx.transformer;
    }

    fn visit(ctx: ?*anyopaque, v: *visitor.NodeVisitor, nodeIndex: ast.NodeIndex) ast.NodeIndex {
        _ = v;
        const tx: *ImportElisionTransformer = @ptrCast(@alignCast(ctx));
        if (nodeIndex == 0) return 0;

        const nodeData = tx.transformer.visitor.tree.getNode(nodeIndex);
        switch (nodeData) {
            .ImportEqualsDeclaration => {
                if (ast_utils.isExternalModuleImportEqualsDeclaration(tx.transformer.visitor.tree, nodeIndex)) {
                    if (!tx.shouldEmitAliasDeclaration(nodeIndex)) {
                        return 0;
                    }
                } else {
                    if (!tx.shouldEmitImportEqualsDeclarationByIndex(nodeIndex)) {
                        return 0;
                    }
                }
                return tx.transformer.visitor.visitEachChild(nodeIndex);
            },
            .ImportDeclaration => |n| {
                if (n.ImportClause) |ic| {
                    if (ic != 0) {
                        const importClause = tx.transformer.visitor.visitNodeInternal(ic);
                        if (importClause == 0) {
                            return 0;
                        }
                        return tx.transformer.factory.updateImportDeclaration(
                            nodeIndex,
                            n,
                            0, // modifiers
                            importClause,
                            n.ModuleSpecifier,
                            tx.transformer.visitor.visitNodeInternal(n.Attributes orelse 0),
                        );
                    }
                }
                return tx.transformer.visitor.visitEachChild(nodeIndex);
            },
            .ImportClause => |n| {
                const name = if (tx.shouldEmitAliasDeclaration(nodeIndex)) n.name orelse 0 else 0;
                const namedBindings = tx.transformer.visitor.visitNodeInternal(n.NamedBindings orelse 0);
                if (name == 0 and namedBindings == 0) {
                    return 0;
                }
                return tx.transformer.factory.updateImportClause(
                    nodeIndex,
                    n,
                    n.PhaseModifier orelse 0,
                    name,
                    namedBindings,
                );
            },
            .NamespaceImport => {
                if (!tx.shouldEmitAliasDeclaration(nodeIndex)) {
                    return 0;
                }
                return nodeIndex;
            },
            .NamedImports => |n| {
                const elements = tx.transformer.visitor.visitNodesInternal(n.Elements);
                const elementsList = tx.transformer.visitor.tree.getNodeList(elements);
                if (elementsList.len == 0) {
                    return 0;
                }
                return tx.transformer.factory.updateNamedImports(
                    nodeIndex,
                    n,
                    elements,
                );
            },
            .ImportSpecifier => {
                if (!tx.shouldEmitAliasDeclaration(nodeIndex)) {
                    return 0;
                }
                return nodeIndex;
            },
            .ExportAssignment => {
                if (!(tx.compilerOptions.verbatimModuleSyntax orelse false) and !tx.isValueAliasDeclaration(nodeIndex)) {
                    return 0;
                }
                return tx.transformer.visitor.visitEachChild(nodeIndex);
            },
            .ExportDeclaration => |n| {
                // `export * from` has no alias declaration to resolve and is
                // always a runtime module operation.
                if ((n.ExportClause orelse 0) == 0 and (n.ModuleSpecifier orelse 0) != 0 and n.IsTypeOnly == 0) {
                    return nodeIndex;
                }
                var exportClause: ?ast.NodeIndex = null;
                if (n.ExportClause) |ec| {
                    const res = tx.transformer.visitor.visitNodeInternal(ec);
                    if (res == 0) {
                        return 0;
                    }
                    exportClause = res;
                }
                return tx.transformer.factory.updateExportDeclaration(
                    nodeIndex,
                    n,
                    0, // modifiers
                    false, // isTypeOnly
                    exportClause orelse 0,
                    tx.transformer.visitor.visitNodeInternal(n.ModuleSpecifier orelse 0),
                    tx.transformer.visitor.visitNodeInternal(n.Attributes orelse 0),
                );
            },
            .NamedExports => |n| {
                const elements = tx.transformer.visitor.visitNodesInternal(n.Elements);
                const elementsList = tx.transformer.visitor.tree.getNodeList(elements);
                if (elementsList.len == 0) {
                    return 0;
                }
                return tx.transformer.factory.updateNamedExports(
                    nodeIndex,
                    n,
                    elements,
                );
            },
            .ExportSpecifier => {
                if (!tx.isValueAliasDeclaration(nodeIndex)) {
                    return 0;
                }
                return nodeIndex;
            },
            .SourceFile => |n| {
                const savedCurrentSourceFile = tx.currentSourceFile;
                tx.currentSourceFile = n;
                tx.referenced_names.clearRetainingCapacity();
                tx.has_jsx = false;
                var collector = RuntimeReferenceCollector{ .tx = tx };
                collector.visitNode(nodeIndex) catch unreachable;
                const result = tx.transformer.visitor.visitEachChild(nodeIndex);
                tx.currentSourceFile = savedCurrentSourceFile;
                return result;
            },
            .ModuleDeclaration, .ModuleBlock => {
                return tx.transformer.visitor.visitEachChild(nodeIndex);
            },
            else => return nodeIndex,
        }
    }

    fn shouldEmitAliasDeclaration(tx: *ImportElisionTransformer, nodeIndex: ast.NodeIndex) bool {
        const tree = tx.transformer.visitor.tree;
        const name = switch (tree.getNode(nodeIndex)) {
            .ImportClause => |n| n.name orelse return false,
            .NamespaceImport => |n| n.name,
            .ImportSpecifier => |n| n.name,
            .ImportEqualsDeclaration => |n| n.name,
            else => return tx.isReferencedAliasDeclaration(nodeIndex),
        };
        const text = ast_utils.getText(tree, name);
        if (tx.has_jsx and tx.compilerOptions.jsx == .React and std.mem.eql(u8, text, "React")) return true;
        return tx.referenced_names.contains(text);
    }

    fn shouldEmitImportEqualsDeclarationByIndex(tx: *ImportElisionTransformer, nodeIndex: ast.NodeIndex) bool {
        return tx.shouldEmitAliasDeclaration(nodeIndex) or (!tx.isCurrentExternalModule() and tx.isTopLevelValueImportEqualsWithEntityName(nodeIndex));
    }

    fn isCurrentExternalModule(tx: *ImportElisionTransformer) bool {
        if (tx.currentSourceFile) |sf| {
            return sf.ExternalModuleIndicator != null;
        }
        return false;
    }

    fn parseNode(tx: *ImportElisionTransformer, nodeIndex: ast.NodeIndex) ast.NodeIndex {
        const orig = tx.transformer.emitContext.getOriginal(nodeIndex);
        return if (orig != 0) orig else nodeIndex;
    }

    fn isReferencedAliasDeclaration(tx: *ImportElisionTransformer, nodeIndex: ast.NodeIndex) bool {
        const parsedNode = tx.parseNode(nodeIndex);
        if (parsedNode == 0) return true;
        return tx.emitResolver.IsReferencedAliasDeclaration(parsedNode);
    }

    fn isValueAliasDeclaration(tx: *ImportElisionTransformer, nodeIndex: ast.NodeIndex) bool {
        const parsedNode = tx.parseNode(nodeIndex);
        if (parsedNode == 0) return true;
        return tx.emitResolver.IsValueAliasDeclaration(parsedNode);
    }

    fn isTopLevelValueImportEqualsWithEntityName(tx: *ImportElisionTransformer, nodeIndex: ast.NodeIndex) bool {
        const parsedNode = tx.parseNode(nodeIndex);
        if (parsedNode != 0 and tx.emitResolver.IsTopLevelValueImportEqualsWithEntityName(parsedNode)) {
            return true;
        }
        return false;
    }
};

const RuntimeReferenceCollector = struct {
    tx: *ImportElisionTransformer,

    pub fn visitNode(self: *@This(), node: ast.NodeIndex) !void {
        if (node == 0) return;
        const tree = self.tx.transformer.visitor.tree;
        switch (tree.getNode(node)) {
            .ImportDeclaration, .ImportEqualsDeclaration => return,
            .Identifier => {
                self.tx.referenced_names.put(self.tx.allocator, ast_utils.getText(tree, node), {}) catch unreachable;
                return;
            },
            .JsxElement, .JsxSelfClosingElement, .JsxFragment => {
                self.tx.has_jsx = true;
                try ast.forEachChild(tree, node, self);
            },
            else => try ast.forEachChild(tree, node, self),
        }
    }

    pub fn visitList(self: *@This(), list: ast.NodeIndex) !void {
        for (self.tx.transformer.visitor.tree.getNodeList(list)) |node| try self.visitNode(node);
    }
};
