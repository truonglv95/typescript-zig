const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const ast_utils = @import("../../ast/ast_utils.zig");
const core = @import("../../core/core.zig");
const printer = @import("../../printer/printer.zig");
const emitresolver = @import("../../printer/emitresolver.zig");
const transformers = @import("../transformer.zig");
const visitor = @import("../../ast/visitor.zig");
const metadataserializer = @import("typeserializer.zig");

pub const USE_NEW_TYPE_METADATA_FORMAT = false;

pub const MetadataTransformer = struct {
    transformer: *transformers.Transformer,
    legacyDecorators: bool,
    resolver: *emitresolver.EmitResolver,

    serializer: *metadataserializer.MetadataSerializer,
    languageVersion: core.ScriptTarget,
    strictNullChecks: bool,
    parent: ast.NodeIndex,
    currentLexicalScope: ast.NodeIndex,

    pub fn new(allocator: std.mem.Allocator, opt: *transformers.TransformOptions) !*transformers.Transformer {
        var tx = try allocator.create(MetadataTransformer);
        tx.* = .{
            .transformer = undefined,
            .legacyDecorators = opt.compilerOptions.experimentalDecorators orelse false,
            .resolver = opt.emitResolver,
            .serializer = undefined,
            .languageVersion = opt.compilerOptions.target orelse .Latest,
            .strictNullChecks = opt.compilerOptions.strictNullChecks orelse false,
            .parent = 0,
            .currentLexicalScope = 0,
        };
        tx.transformer = try transformers.Transformer.init(allocator, visit, tx, opt.context);
        return tx.transformer;
    }

    fn visit(ctx: ?*anyopaque, v: *visitor.NodeVisitor, nodeIndex: ast.NodeIndex) ast.NodeIndex {
        _ = v;
        const tx: *MetadataTransformer = @ptrCast(@alignCast(ctx));
        if (nodeIndex == 0) return 0;

        const tree = tx.transformer.visitor.tree;
        std.debug.print("MetadataTransformer visiting: {any}\n", .{tree.getNodeKind(nodeIndex)});

        // if ((ast_utils.getSubtreeFacts(tree, nodeIndex) & ast_utils.SubtreeFacts.ContainsDecorators) == 0) {
        //     return nodeIndex;
        // }

        const nodeData = tree.getNode(nodeIndex);
        switch (nodeData) {
            .ClassDeclaration => |n| return tx.visitClassDeclaration(nodeIndex, n),
            .ClassExpression => |n| return tx.visitClassExpression(nodeIndex, n),
            .PropertyDeclaration => |n| return tx.visitPropertyDeclaration(nodeIndex, n),
            .MethodDeclaration => |n| return tx.visitMethodDeclaration(nodeIndex, n),
            .SetAccessor => |n| return tx.visitSetAccessor(nodeIndex, n),
            .GetAccessor => |n| return tx.visitGetAccessor(nodeIndex, n),
            .SourceFile => {
                tx.parent = 0;
                tx.currentLexicalScope = nodeIndex;
                tx.serializer = metadataserializer.MetadataSerializer.new(
                    std.heap.page_allocator,
                    tx.resolver,
                    tx.transformer.factory,
                    tx.transformer.emitContext,
                    tx.languageVersion,
                    tx.strictNullChecks,
                ) catch @panic("OOM");
                const updated = tx.transformer.visitor.visitEachChild(nodeIndex);
                tx.transformer.emitContext.addEmitHelpers(updated, tx.transformer.emitContext.readEmitHelpers());
                tx.parent = 0;
                tx.currentLexicalScope = 0;
                return updated;
            },
            .ModuleBlock, .Block, .CaseBlock => {
                const oldScope = tx.currentLexicalScope;
                tx.currentLexicalScope = nodeIndex;
                const updated = tx.transformer.visitor.visitEachChild(nodeIndex);
                tx.currentLexicalScope = oldScope;
                return updated;
            },
            else => return tx.transformer.visitor.visitEachChild(nodeIndex),
        }
    }

    fn visitClassExpression(tx: *MetadataTransformer, nodeIndex: ast.NodeIndex, node: ast_gen.ClassExpressionNode) ast.NodeIndex {
        const tree = tx.transformer.visitor.tree;
        const oldParent = tx.parent;
        tx.parent = nodeIndex;
        defer tx.parent = oldParent;

        if (!ast_utils.classOrConstructorParameterIsDecorated(tree, tx.legacyDecorators, nodeIndex)) {
            return tx.transformer.visitor.visitEachChild(nodeIndex);
        }

        const modifiers = tx.injectClassTypeMetadata(tx.transformer.visitor.visitNodesInternal(node.modifiers orelse 0), nodeIndex);
        return tx.transformer.factory.updateClassExpression(
            nodeIndex,
            node,
            modifiers,
            tx.transformer.visitor.visitNodeInternal(node.name orelse 0),
            tx.transformer.visitor.visitNodesInternal(node.TypeParameters orelse 0),
            tx.transformer.visitor.visitNodesInternal(node.HeritageClauses orelse 0),
            tx.transformer.visitor.visitNodesInternal(node.Members),
        );
    }

    fn visitClassDeclaration(tx: *MetadataTransformer, nodeIndex: ast.NodeIndex, node: ast_gen.ClassDeclarationNode) ast.NodeIndex {
        const tree = tx.transformer.visitor.tree;
        const oldParent = tx.parent;
        tx.parent = nodeIndex;
        defer tx.parent = oldParent;

        if (!ast_utils.classOrConstructorParameterIsDecorated(tree, tx.legacyDecorators, nodeIndex)) {
            return tx.transformer.visitor.visitEachChild(nodeIndex);
        }

        const modifiers = tx.injectClassTypeMetadata(tx.transformer.visitor.visitNodesInternal(node.modifiers orelse 0), nodeIndex);
        return tx.transformer.factory.updateClassDeclaration(
            nodeIndex,
            node,
            modifiers,
            tx.transformer.visitor.visitNodeInternal(node.name orelse 0),
            tx.transformer.visitor.visitNodesInternal(node.TypeParameters orelse 0),
            tx.transformer.visitor.visitNodesInternal(node.HeritageClauses orelse 0),
            tx.transformer.visitor.visitNodesInternal(node.Members),
        );
    }

    fn visitPropertyDeclaration(tx: *MetadataTransformer, nodeIndex: ast.NodeIndex, node: ast_gen.PropertyDeclarationNode) ast.NodeIndex {
        const tree = tx.transformer.visitor.tree;
        if (!ast_utils.hasDecorators(tree, nodeIndex)) {
            return tx.transformer.visitor.visitEachChild(nodeIndex);
        }

        const modifiers = tx.injectClassElementTypeMetadata(tx.transformer.visitor.visitNodesInternal(node.modifiers orelse 0), nodeIndex, tx.parent);
        return tx.transformer.factory.updatePropertyDeclaration(
            nodeIndex,
            node,
            modifiers,
            tx.transformer.visitor.visitNodeInternal(node.name),
            tx.transformer.visitor.visitNodeInternal(node.PostfixToken orelse 0),
            tx.transformer.visitor.visitNodeInternal(node.Type orelse 0),
            tx.transformer.visitor.visitNodeInternal(node.Initializer orelse 0),
        );
    }

    fn visitMethodDeclaration(tx: *MetadataTransformer, nodeIndex: ast.NodeIndex, node: ast_gen.MethodDeclarationNode) ast.NodeIndex {
        const tree = tx.transformer.visitor.tree;
        const decoratorsOfParams = ast_utils.getDecoratorsOfParameters(tree, nodeIndex, std.heap.page_allocator) catch @panic("OOM");
        defer std.heap.page_allocator.free(decoratorsOfParams);

        if (!ast_utils.hasDecorators(tree, nodeIndex) and decoratorsOfParams.len == 0) {
            return tx.transformer.visitor.visitEachChild(nodeIndex);
        }

        const modifiers = tx.injectClassElementTypeMetadata(tx.transformer.visitor.visitNodesInternal(node.modifiers orelse 0), nodeIndex, tx.parent);
        return tx.transformer.factory.updateMethodDeclaration(
            nodeIndex,
            node,
            modifiers,
            tx.transformer.visitor.visitNodeInternal(node.AsteriskToken orelse 0),
            tx.transformer.visitor.visitNodeInternal(node.name),
            tx.transformer.visitor.visitNodeInternal(node.PostfixToken orelse 0),
            tx.transformer.visitor.visitNodesInternal(node.TypeParameters orelse 0),
            tx.transformer.visitor.visitNodesInternal(node.Parameters),
            tx.transformer.visitor.visitNodeInternal(node.Type orelse 0),
            tx.transformer.visitor.visitNodeInternal(node.Body orelse 0),
        );
    }

    fn visitSetAccessor(tx: *MetadataTransformer, nodeIndex: ast.NodeIndex, node: ast_gen.SetAccessorDeclarationNode) ast.NodeIndex {
        const tree = tx.transformer.visitor.tree;
        const decoratorsOfParams = ast_utils.getDecoratorsOfParameters(tree, nodeIndex, std.heap.page_allocator) catch @panic("OOM");
        defer std.heap.page_allocator.free(decoratorsOfParams);

        if (!ast_utils.hasDecorators(tree, nodeIndex) and decoratorsOfParams.len == 0) {
            return tx.transformer.visitor.visitEachChild(nodeIndex);
        }

        const modifiers = tx.injectClassElementTypeMetadata(tx.transformer.visitor.visitNodesInternal(node.modifiers orelse 0), nodeIndex, tx.parent);
        return tx.transformer.factory.updateSetAccessorDeclaration(
            nodeIndex,
            node,
            modifiers,
            tx.transformer.visitor.visitNodeInternal(node.name),
            tx.transformer.visitor.visitNodesInternal(node.TypeParameters orelse 0),
            tx.transformer.visitor.visitNodesInternal(node.Parameters),
            tx.transformer.visitor.visitNodeInternal(node.Type orelse 0),
            tx.transformer.visitor.visitNodeInternal(node.Body orelse 0),
        );
    }

    fn visitGetAccessor(tx: *MetadataTransformer, nodeIndex: ast.NodeIndex, node: ast_gen.GetAccessorDeclarationNode) ast.NodeIndex {
        const tree = tx.transformer.visitor.tree;
        if (!ast_utils.hasDecorators(tree, nodeIndex)) {
            return tx.transformer.visitor.visitEachChild(nodeIndex);
        }

        const modifiers = tx.injectClassElementTypeMetadata(tx.transformer.visitor.visitNodesInternal(node.modifiers orelse 0), nodeIndex, tx.parent);
        return tx.transformer.factory.updateGetAccessorDeclaration(
            nodeIndex,
            node,
            modifiers,
            tx.transformer.visitor.visitNodeInternal(node.name),
            tx.transformer.visitor.visitNodesInternal(node.TypeParameters orelse 0),
            tx.transformer.visitor.visitNodesInternal(node.Parameters),
            tx.transformer.visitor.visitNodeInternal(node.Type orelse 0),
            tx.transformer.visitor.visitNodeInternal(node.Body orelse 0),
        );
    }

    fn injectClassTypeMetadata(tx: *MetadataTransformer, listIndex: ast.NodeIndex, nodeIndex: ast.NodeIndex) ast.NodeIndex {
        const metadata = tx.getTypeMetadata(nodeIndex, nodeIndex);
        std.debug.print("injectClassTypeMetadata, metadata len: {d}\n", .{metadata.len});
        if (metadata.len > 0) {
            const tree = tx.transformer.visitor.tree;
            for (metadata, 0..) |m, idx| {
                std.debug.print(" -> metadata[{d}] tag: {any}\n", .{ idx, tree.getNodeKind(m) });
            }
            var originalNodes: []const ast.NodeIndex = &[_]ast.NodeIndex{};
            if (listIndex != 0) {
                originalNodes = tree.getNodeList(listIndex);
            }
            if (originalNodes.len == 0) {
                const res = tx.transformer.factory.newModifierList(metadata);
                return res;
            }
            var modifiersArray = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            defer modifiersArray.deinit(std.heap.page_allocator);

            if (ast_utils.isModifier(tree, originalNodes[0])) {
                const kind = tree.getNodeKind(originalNodes[0]);
                if (kind == .DefaultKeyword or kind == .ExportKeyword) {
                    modifiersArray.append(std.heap.page_allocator, originalNodes[0]) catch @panic("OOM");
                    if (originalNodes.len > 1) {
                        const kind1 = tree.getNodeKind(originalNodes[1]);
                        if (kind1 == .DefaultKeyword or kind1 == .ExportKeyword) {
                            modifiersArray.append(std.heap.page_allocator, originalNodes[1]) catch @panic("OOM");
                        }
                    }
                }
            }
            const restStart = modifiersArray.items.len;

            for (originalNodes) |n| {
                if (ast_utils.isDecorator(tree, n)) {
                    modifiersArray.append(std.heap.page_allocator, n) catch @panic("OOM");
                }
            }

            for (metadata) |m| {
                modifiersArray.append(std.heap.page_allocator, m) catch @panic("OOM");
            }

            for (originalNodes[restStart..]) |n| {
                if (ast_utils.isModifier(tree, n)) {
                    modifiersArray.append(std.heap.page_allocator, n) catch @panic("OOM");
                }
            }

            const res = tx.transformer.factory.newModifierList(modifiersArray.items);
            return res;
        }
        return listIndex;
    }

    fn injectClassElementTypeMetadata(tx: *MetadataTransformer, listIndex: ast.NodeIndex, nodeIndex: ast.NodeIndex, containerIndex: ast.NodeIndex) ast.NodeIndex {
        const tree = tx.transformer.visitor.tree;
        if (!ast_utils.isClassLike(tree, containerIndex)) {
            return listIndex;
        }
        if (!ast_utils.classElementOrClassElementParameterIsDecorated(tree, tx.legacyDecorators, nodeIndex, containerIndex)) {
            return listIndex;
        }
        const metadata = tx.getTypeMetadata(nodeIndex, containerIndex);
        if (metadata.len > 0) {
            var originalNodes: []const ast.NodeIndex = &[_]ast.NodeIndex{};
            if (listIndex != 0) {
                originalNodes = tree.getNodeList(listIndex);
            }
            if (originalNodes.len == 0) {
                const res = tx.transformer.factory.newModifierList(metadata);
                return res;
            }
            var modifiersArray = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            defer modifiersArray.deinit(std.heap.page_allocator);

            for (originalNodes) |n| {
                if (ast_utils.isDecorator(tree, n)) {
                    modifiersArray.append(std.heap.page_allocator, n) catch @panic("OOM");
                }
            }

            for (metadata) |m| {
                modifiersArray.append(std.heap.page_allocator, m) catch @panic("OOM");
            }

            for (originalNodes) |n| {
                if (ast_utils.isModifier(tree, n)) {
                    modifiersArray.append(std.heap.page_allocator, n) catch @panic("OOM");
                }
            }

            const res = tx.transformer.factory.newModifierList(modifiersArray.items);
            return res;
        }
        return listIndex;
    }

    fn getTypeMetadata(tx: *MetadataTransformer, nodeIndex: ast.NodeIndex, containerIndex: ast.NodeIndex) []const ast.NodeIndex {
        if (!tx.legacyDecorators) {
            return &[_]ast.NodeIndex{};
        }
        if (USE_NEW_TYPE_METADATA_FORMAT) {
            return tx.getNewTypeMetadata(nodeIndex, containerIndex);
        }
        return tx.getOldTypeMetadata(nodeIndex, containerIndex);
    }

    fn getOldTypeMetadata(tx: *MetadataTransformer, nodeIndex: ast.NodeIndex, containerIndex: ast.NodeIndex) []const ast.NodeIndex {
        var decorators = std.ArrayListUnmanaged(ast.NodeIndex).empty;

        const tree = tx.transformer.visitor.tree;
        std.debug.print("getOldTypeMetadata nodeKind: {any}, shouldAddParamTypes: {}\n", .{ tree.getNodeKind(nodeIndex), tx.shouldAddParamTypesMetadata(nodeIndex) });

        if (tx.shouldAddTypeMetadata(nodeIndex)) {
            const ctx = metadataserializer.MetadataSerializerContext{
                .currentLexicalScope = tx.currentLexicalScope,
                .currentNameScope = containerIndex,
            };
            const typeNode = tx.serializer.serializeTypeOfNode(ctx, nodeIndex, containerIndex);
            const typeMetadata = tx.newMetadataHelper("design:type", typeNode);
            decorators.append(std.heap.page_allocator, tx.transformer.factory.newDecorator(typeMetadata)) catch @panic("OOM");
        }
        if (tx.shouldAddParamTypesMetadata(nodeIndex)) {
            const ctx = metadataserializer.MetadataSerializerContext{
                .currentLexicalScope = tx.currentLexicalScope,
                .currentNameScope = containerIndex,
            };
            const paramTypes = tx.serializer.serializeParameterTypesOfNode(ctx, nodeIndex, containerIndex);
            const paramTypesMetadata = tx.newMetadataHelper("design:paramtypes", paramTypes);
            decorators.append(std.heap.page_allocator, tx.transformer.factory.newDecorator(paramTypesMetadata)) catch @panic("OOM");
        }
        if (tx.shouldAddReturnTypeMetadata(nodeIndex)) {
            const ctx = metadataserializer.MetadataSerializerContext{
                .currentLexicalScope = tx.currentLexicalScope,
                .currentNameScope = containerIndex,
            };
            const retType = tx.serializer.serializeReturnTypeOfNode(ctx, nodeIndex);
            const returnTypeMetadata = tx.newMetadataHelper("design:returntype", retType);
            decorators.append(std.heap.page_allocator, tx.transformer.factory.newDecorator(returnTypeMetadata)) catch @panic("OOM");
        }
        return decorators.toOwnedSlice(std.heap.page_allocator) catch @panic("OOM");
    }

    fn getNewTypeMetadata(tx: *MetadataTransformer, nodeIndex: ast.NodeIndex, containerIndex: ast.NodeIndex) []const ast.NodeIndex {
        var properties = std.ArrayListUnmanaged(ast.NodeIndex).empty;

        if (tx.shouldAddTypeMetadata(nodeIndex)) {
            const ctx = metadataserializer.MetadataSerializerContext{
                .currentLexicalScope = tx.currentLexicalScope,
                .currentNameScope = containerIndex,
            };
            const typeNode = tx.serializer.serializeTypeOfNode(ctx, nodeIndex, containerIndex);
            properties.append(tx.transformer.factory.newPropertyAssignment(
                0, // modifiers
                tx.transformer.factory.newIdentifier("type"),
                0, // questionToken
                0, // colonToken
                tx.transformer.factory.newArrowFunction(
                    0, // modifiers
                    0, // typeParameters
                    tx.transformer.factory.newNodeList(&[_]ast.NodeIndex{}),
                    0, // type
                    0, // equalsGreaterThanToken
                    tx.transformer.factory.newToken(.EqualsGreaterThanToken),
                    typeNode,
                ),
            )) catch @panic("OOM");
        }

        if (tx.shouldAddParamTypesMetadata(nodeIndex)) {
            const ctx = metadataserializer.MetadataSerializerContext{
                .currentLexicalScope = tx.currentLexicalScope,
                .currentNameScope = containerIndex,
            };
            const paramTypes = tx.serializer.serializeParameterTypesOfNode(ctx, nodeIndex, containerIndex);
            properties.append(tx.transformer.factory.newPropertyAssignment(
                0, // modifiers
                tx.transformer.factory.newIdentifier("paramTypes"),
                0, // questionToken
                0, // colonToken
                tx.transformer.factory.newArrowFunction(
                    0, // modifiers
                    0, // typeParameters
                    tx.transformer.factory.newNodeList(&[_]ast.NodeIndex{}),
                    0, // type
                    0, // equalsGreaterThanToken
                    tx.transformer.factory.newToken(.EqualsGreaterThanToken),
                    paramTypes,
                ),
            )) catch @panic("OOM");
        }

        if (tx.shouldAddReturnTypeMetadata(nodeIndex)) {
            const ctx = metadataserializer.MetadataSerializerContext{
                .currentLexicalScope = tx.currentLexicalScope,
                .currentNameScope = containerIndex,
            };
            const retType = tx.serializer.serializeReturnTypeOfNode(ctx, nodeIndex);
            properties.append(tx.transformer.factory.newPropertyAssignment(
                0, // modifiers
                tx.transformer.factory.newIdentifier("returnType"),
                0, // questionToken
                0, // colonToken
                tx.transformer.factory.newArrowFunction(
                    0, // modifiers
                    0, // typeParameters
                    tx.transformer.factory.newNodeList(&[_]ast.NodeIndex{}),
                    0, // type
                    0, // equalsGreaterThanToken
                    tx.transformer.factory.newToken(.EqualsGreaterThanToken),
                    retType,
                ),
            )) catch @panic("OOM");
        }

        if (properties.items.len > 0) {
            const propertiesList = tx.transformer.factory.newNodeList(properties.items);
            const objectLiteral = tx.transformer.factory.newObjectLiteralExpression(propertiesList, true);
            const typeInfoMetadata = tx.transformer.factory.newMetadataHelper("design:typeinfo", objectLiteral);

            var res = std.heap.page_allocator.alloc(ast.NodeIndex, 1) catch @panic("OOM");
            res[0] = tx.transformer.factory.newDecorator(typeInfoMetadata);
            return res;
        }
        return &[_]ast.NodeIndex{};
    }

    fn shouldAddTypeMetadata(tx: *MetadataTransformer, nodeIndex: ast.NodeIndex) bool {
        const tree = tx.transformer.visitor.tree;
        switch (tree.getNodeKind(nodeIndex)) {
            .MethodDeclaration, .GetAccessor, .SetAccessor, .PropertyDeclaration => return true,
            else => return false,
        }
    }

    fn shouldAddReturnTypeMetadata(tx: *MetadataTransformer, nodeIndex: ast.NodeIndex) bool {
        const tree = tx.transformer.visitor.tree;
        return tree.getNodeKind(nodeIndex) == .MethodDeclaration;
    }

    fn shouldAddParamTypesMetadata(tx: *MetadataTransformer, nodeIndex: ast.NodeIndex) bool {
        const tree = tx.transformer.visitor.tree;
        switch (tree.getNodeKind(nodeIndex)) {
            .ClassDeclaration, .ClassExpression => return ast_utils.getFirstConstructorWithBody(tree, nodeIndex) != 0,
            .MethodDeclaration, .GetAccessor, .SetAccessor => return true,
            else => return false,
        }
    }

    fn newMetadataHelper(tx: *MetadataTransformer, key: []const u8, value: ast.NodeIndex) ast.NodeIndex {
        const helper = tx.transformer.factory.newMetadataHelper(key, value);
        const callNode = tx.transformer.visitor.tree.getNode(helper).CallExpression;
        tx.transformer.emitContext.setEmitFlags(callNode.Expression, @import("../../printer/emitflags.zig").EmitFlags.HelperName) catch unreachable;
        tx.transformer.emitContext.requestEmitHelper(&@import("../../printer/helpers.zig").metadataHelper);
        return helper;
    }
};
test "compile" {
    std.testing.refAllDecls(@This());
}
