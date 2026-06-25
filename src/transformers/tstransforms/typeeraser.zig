const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const kind = @import("../../ast/kind.zig");
const core = @import("../../core/core.zig");
const transformer_mod = @import("../transformer.zig");
const visitor_mod = @import("../../ast/visitor.zig");
const ast_utils = @import("../../ast/ast_utils.zig");

pub const TypeEraserTransformer = struct {
    transformer: *transformer_mod.Transformer,
    compilerOptions: *core.CompilerOptions,
    parentNode: ast_gen.NodeIndex = 0,
    currentNode: ast_gen.NodeIndex = 0,

    pub fn newTypeEraserTransformer(allocator: std.mem.Allocator, opt: *transformer_mod.TransformOptions) !*transformer_mod.Transformer {
        const tx = try allocator.create(TypeEraserTransformer);
        tx.compilerOptions = opt.compilerOptions;
        tx.parentNode = 0;
        tx.currentNode = 0;
        
        tx.transformer = try transformer_mod.Transformer.init(allocator, visit, tx, opt.context);
        return tx.transformer;
    }
    
    fn pushNode(self: *TypeEraserTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const grandparentNode = self.parentNode;
        self.parentNode = self.currentNode;
        self.currentNode = node;
        return grandparentNode;
    }

    fn popNode(self: *TypeEraserTransformer, grandparentNode: ast_gen.NodeIndex) void {
        self.currentNode = self.parentNode;
        self.parentNode = grandparentNode;
    }

    fn elide(self: *TypeEraserTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.transformer.emitContext.newNotEmittedStatement(node) catch 0;
    }

    fn visit(ctx: ?*anyopaque, visitor: *visitor_mod.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const self = @as(*TypeEraserTransformer, @ptrCast(@alignCast(ctx.?)));
        const tree = visitor.tree;

        if (node == 0) return 0;
        if (ast_utils.hasSyntacticModifier(tree, node, ast_utils.ModifierFlags.Ambient)) {
            return self.elide(node);
        }

        const grandparentNode = self.pushNode(node);
        defer self.popNode(grandparentNode);

        const nodeData = tree.getNode(node);
        switch (nodeData) {
            .PublicKeyword,
            .PrivateKeyword,
            .ProtectedKeyword,
            .AbstractKeyword,
            .OverrideKeyword,
            .ConstKeyword,
            .DeclareKeyword,
            .ReadonlyKeyword,
            .ArrayType,
            .TupleType,
            .OptionalType,
            .RestType,
            .TypeLiteral,
            .TypePredicate,
            .TypeParameter,
            .AnyKeyword,
            .UnknownKeyword,
            .BooleanKeyword,
            .StringKeyword,
            .NumberKeyword,
            .NeverKeyword,
            .VoidKeyword,
            .SymbolKeyword,
            .ConstructorType,
            .FunctionType,
            .TypeQuery,
            .TypeReference,
            .UnionType,
            .IntersectionType,
            .ConditionalType,
            .ParenthesizedType,
            .ThisType,
            .TypeOperator,
            .IndexedAccessType,
            .MappedType,
            .LiteralType,
            .IndexSignature => return 0,

            .InKeyword, .OutKeyword => {
                const parentData = tree.getNode(self.parentNode);
                if (ast_utils.isBinaryExpression(parentData)) {
                    return visitor.visitEachChild(node);
                }
                return 0;
            },

            .JSImportDeclaration => return 0,

            .TypeAliasDeclaration,
            .JSTypeAliasDeclaration,
            .InterfaceDeclaration,
            .NamespaceExportDeclaration => return self.elide(node),

            .ModuleDeclaration => |n| {
                const nameNode = tree.getNode(n.name);
                if (nameNode != .Identifier or
                    !ast_utils.isInstantiatedModule(tree, node, self.compilerOptions.preserveConstEnums orelse false) or
                    n.Body == null) {
                    return self.elide(node);
                }
                return visitor.visitEachChild(node);
            },

            .ExpressionWithTypeArguments => |n| {
                return self.transformer.factory.updateExpressionWithTypeArguments(
                    node,
                    n,
                    visitor.visitNodeInternal(n.Expression),
                    0, // typeArguments
                );
            },

            .PropertyDeclaration => |n| {
                if ((self.compilerOptions.experimentalDecorators orelse false) and ast_utils.hasSyntacticModifier(tree, node, ast_utils.ModifierFlags.Ambient | ast_utils.ModifierFlags.Abstract) and ast_utils.hasDecorators(tree, node)) {
                    return self.transformer.factory.updatePropertyDeclaration(
                        node,
                        n,
                        visitor.visitModifiersInternal(n.modifiers orelse 0),
                        visitor.visitNodeInternal(n.name),
                        0, // questionOrExclamationToken
                        0, // typeNode
                        visitor.visitNodeInternal(n.Initializer orelse 0),
                    );
                }
                if (ast_utils.hasSyntacticModifier(tree, node, ast_utils.ModifierFlags.Ambient | ast_utils.ModifierFlags.Abstract)) {
                    return 0;
                }
                return self.transformer.factory.updatePropertyDeclaration(
                    node,
                    n,
                    visitor.visitModifiersInternal(n.modifiers orelse 0),
                    visitor.visitNodeInternal(n.name),
                    0, // questionOrExclamationToken
                    0, // typeNode
                    visitor.visitNodeInternal(n.Initializer orelse 0),
                );
            },

            .Constructor => |n| {
                if (n.Body == null or n.Body.? == 0) {
                    return 0;
                }
                return self.transformer.factory.updateConstructorDeclaration(
                    node,
                    n,
                    0, // modifiers
                    0, // name
                    visitor.visitNodesInternal(n.Parameters),
                    0, // typeNode
                    visitor.visitNodeInternal(n.Body orelse 0),
                );
            },

            .MethodDeclaration => |n| {
                if (n.Body == null or n.Body.? == 0) {
                    return 0;
                }
                return self.transformer.factory.updateMethodDeclaration(
                    node,
                    n,
                    visitor.visitModifiersInternal(n.modifiers orelse 0),
                    n.AsteriskToken orelse 0,
                    visitor.visitNodeInternal(n.name),
                    0, // questionToken
                    0, // typeParameters
                    visitor.visitNodesInternal(n.Parameters),
                    0, // typeNode
                    visitor.visitNodeInternal(n.Body orelse 0),
                );
            },

            .GetAccessor => |n| {
                if ((n.Body == null or n.Body.? == 0) and ast_utils.hasSyntacticModifier(tree, node, ast_utils.ModifierFlags.Abstract)) {
                    return 0;
                }
                var body = visitor.visitNodeInternal(n.Body orelse 0);
                if (body == 0) {
                    body = self.transformer.factory.createBlock(0, false);
                }
                return self.transformer.factory.updateGetAccessorDeclaration(
                    node,
                    n,
                    visitor.visitModifiersInternal(n.modifiers orelse 0),
                    visitor.visitNodeInternal(n.name),
                    0, // typeParameters
                    visitor.visitNodesInternal(n.Parameters),
                    0, // typeNode
                    body,
                );
            },

            .SetAccessor => |n| {
                if ((n.Body == null or n.Body.? == 0) and ast_utils.hasSyntacticModifier(tree, node, ast_utils.ModifierFlags.Abstract)) {
                    return 0;
                }
                var body = visitor.visitNodeInternal(n.Body orelse 0);
                if (body == 0) {
                    body = self.transformer.factory.createBlock(0, false);
                }
                return self.transformer.factory.updateSetAccessorDeclaration(
                    node,
                    n,
                    visitor.visitModifiersInternal(n.modifiers orelse 0),
                    visitor.visitNodeInternal(n.name),
                    0, // typeParameters
                    visitor.visitNodesInternal(n.Parameters),
                    0, // typeNode
                    body,
                );
            },

            .VariableDeclaration => |n| {
                const updated = self.transformer.factory.updateVariableDeclaration(
                    node,
                    n,
                    visitor.visitNodeInternal(n.name),
                    0, // exclamationToken
                    0, // typeNode
                    visitor.visitNodeInternal(n.Initializer orelse 0),
                );
                if (n.Type != null and n.Type.? != 0) {
                    self.transformer.emitContext.setTypeNode(updated, n.Type.?);
                }
                return updated;
            },

            .HeritageClause => |n| {
                if (n.Token == @intFromEnum(kind.Kind.ImplementsKeyword)) {
                    return 0;
                }
                return self.transformer.factory.updateHeritageClause(
                    node,
                    n,
                    n.Token,
                    visitor.visitNodesInternal(n.Types),
                );
            },

            .ClassDeclaration => |n| {
                return self.transformer.factory.updateClassDeclaration(
                    node,
                    n,
                    visitor.visitModifiersInternal(n.modifiers orelse 0),
                    visitor.visitNodeInternal(n.name orelse 0),
                    0, // typeParameters
                    visitor.visitNodesInternal(n.HeritageClauses orelse 0),
                    visitor.visitNodesInternal(n.Members),
                );
            },

            .ClassExpression => |n| {
                return self.transformer.factory.updateClassExpression(
                    node,
                    n,
                    visitor.visitModifiersInternal(n.modifiers orelse 0),
                    visitor.visitNodeInternal(n.name orelse 0),
                    0, // typeParameters
                    visitor.visitNodesInternal(n.HeritageClauses orelse 0),
                    visitor.visitNodesInternal(n.Members),
                );
            },

            .FunctionDeclaration => |n| {
                if (n.Body == null or n.Body.? == 0) {
                    return self.elide(node);
                }
                return self.transformer.factory.updateFunctionDeclaration(
                    node,
                    n,
                    visitor.visitModifiersInternal(n.modifiers orelse 0),
                    n.AsteriskToken orelse 0,
                    visitor.visitNodeInternal(n.name orelse 0),
                    0, // typeParameters
                    visitor.visitNodesInternal(n.Parameters),
                    0, // typeNode
                    visitor.visitNodeInternal(n.Body orelse 0),
                );
            },

            .FunctionExpression => |n| {
                return self.transformer.factory.updateFunctionExpression(
                    node,
                    n,
                    visitor.visitModifiersInternal(n.modifiers orelse 0),
                    n.AsteriskToken orelse 0,
                    visitor.visitNodeInternal(n.name orelse 0),
                    0, // typeParameters
                    visitor.visitNodesInternal(n.Parameters),
                    0, // typeNode
                    visitor.visitNodeInternal(n.Body orelse 0),
                );
            },

            .ArrowFunction => |n| {
                return self.transformer.factory.updateArrowFunction(
                    node,
                    n,
                    visitor.visitModifiersInternal(n.modifiers orelse 0),
                    0, // typeParameters
                    visitor.visitNodesInternal(n.Parameters),
                    0, // typeNode
                    n.EqualsGreaterThanToken,
                    visitor.visitNodeInternal(n.Body orelse 0),
                );
            },

            .Parameter => |n| {
                std.debug.print("Parameter name: {s}\n", .{tree.getNode(n.name).Identifier.Text});
                if (ast_utils.isThisParameter(tree, node)) {
                    return 0;
                }
                var modifiers: ast.NodeIndex = 0;
                if (ast_utils.isParameterPropertyDeclaration(tree, node, self.parentNode)) {
                    modifiers = self.transformer.extractModifiers(n.modifiers orelse 0, ast_utils.ModifierFlags.ParameterPropertyModifier);
                }
                if (ast_utils.hasDecorators(tree, node)) {
                    // Stub for decorators handling
                }
                return self.transformer.factory.updateParameterDeclaration(
                    node,
                    n,
                    modifiers,
                    n.DotDotDotToken orelse 0,
                    visitor.visitNodeInternal(n.name),
                    0, // questionToken
                    0, // typeNode
                    visitor.visitNodeInternal(n.Initializer orelse 0),
                );
            },

            .CallExpression => |n| {
                return self.transformer.factory.updateCallExpression(
                    node,
                    n,
                    visitor.visitNodeInternal(n.Expression),
                    n.QuestionDotToken orelse 0,
                    0, // typeArguments
                    visitor.visitNodesInternal(n.Arguments),
                    n.Flags,
                );
            },

            .NewExpression => |n| {
                return self.transformer.factory.updateNewExpression(
                    node,
                    n,
                    visitor.visitNodeInternal(n.Expression),
                    0, // typeArguments
                    visitor.visitNodesInternal(n.Arguments orelse 0),
                );
            },

            .TaggedTemplateExpression => |n| {
                return self.transformer.factory.updateTaggedTemplateExpression(
                    node,
                    n,
                    visitor.visitNodeInternal(n.Tag),
                    n.QuestionDotToken orelse 0,
                    0, // typeArguments
                    visitor.visitNodeInternal(n.Template),
                    n.Flags,
                );
            },

            .NonNullExpression => |n| {
                return self.transformer.factory.newPartiallyEmittedExpression(visitor.visitNodeInternal(n.Expression));
            },
            .TypeAssertionExpression => |n| {
                return self.transformer.factory.newPartiallyEmittedExpression(visitor.visitNodeInternal(n.Expression));
            },
            .AsExpression => |n| {
                return self.transformer.factory.newPartiallyEmittedExpression(visitor.visitNodeInternal(n.Expression));
            },
            .SatisfiesExpression => |n| {
                return self.transformer.factory.newPartiallyEmittedExpression(visitor.visitNodeInternal(n.Expression));
            },

            .ParenthesizedExpression => |n| {
                if (!ast_utils.isJSDocTypeAssertion(tree, node)) {
                    const expression = ast_utils.skipOuterExpressions(tree, n.Expression, ast_utils.OEKAllExceptAssertionsOrExpressionsWithTypeArguments);
                    const exprData = tree.getNode(expression);
                    if (exprData == .TypeAssertionExpression or exprData == .AsExpression or exprData == .SatisfiesExpression) {
                        const partial = self.transformer.factory.newPartiallyEmittedExpression(visitor.visitNodeInternal(n.Expression));
                        return partial;
                    }
                }
                return visitor.visitEachChild(node);
            },

            .JsxSelfClosingElement => |n| {
                return self.transformer.factory.updateJsxSelfClosingElement(
                    node,
                    n,
                    visitor.visitNodeInternal(n.TagName),
                    0, // typeArguments
                    visitor.visitNodeInternal(n.Attributes),
                );
            },

            .JsxOpeningElement => |n| {
                return self.transformer.factory.updateJsxOpeningElement(
                    node,
                    n,
                    visitor.visitNodeInternal(n.TagName),
                    0, // typeArguments
                    visitor.visitNodeInternal(n.Attributes),
                );
            },

            .ImportEqualsDeclaration => |n| {
                if (n.IsTypeOnly != 0) {
                    return 0;
                }
                return visitor.visitEachChild(node);
            },

            .ImportDeclaration => |n| {
                if (n.ImportClause == 0 or n.ImportClause == null) {
                    return node;
                }
                const importClause = visitor.visitNodeInternal(n.ImportClause.?);
                if (importClause == 0) {
                    return 0;
                }
                return self.transformer.factory.updateImportDeclaration(
                    node,
                    n,
                    n.modifiers orelse 0,
                    importClause,
                    n.ModuleSpecifier,
                    n.Attributes orelse 0,
                );
            },

            .ImportClause => |n| {
                if (n.PhaseModifier != null and n.PhaseModifier.? == @intFromEnum(kind.Kind.TypeKeyword)) {
                    return 0;
                }
                const name = n.name orelse 0;
                const namedBindings = visitor.visitNodeInternal(n.NamedBindings orelse 0);
                if (name == 0 and namedBindings == 0) {
                    return 0;
                }
                return self.transformer.factory.updateImportClause(
                    node,
                    n,
                    n.PhaseModifier orelse 0,
                    name,
                    namedBindings,
                );
            },

            .NamedImports => |n| {
                const elementsList = tree.getNodeList(n.Elements);
                if (elementsList.len == 0) {
                    return node;
                }
                const elements = visitor.visitNodesInternal(n.Elements);
                const newElementsList = tree.getNodeList(elements);
                if (!(self.compilerOptions.verbatimModuleSyntax orelse false) and newElementsList.len == 0) {
                    return 0;
                }
                return self.transformer.factory.updateNamedImports(
                    node,
                    n,
                    elements,
                );
            },

            .ImportSpecifier => |n| {
                if (n.IsTypeOnly != 0) {
                    return 0;
                }
                return node;
            },

            .ExportDeclaration => |n| {
                if (n.IsTypeOnly != 0) {
                    return 0;
                }
                var exportClause: ast.NodeIndex = 0;
                if (n.ExportClause != null and n.ExportClause.? != 0) {
                    exportClause = visitor.visitNodeInternal(n.ExportClause.?);
                    if (exportClause == 0) {
                        return 0;
                    }
                }
                return self.transformer.factory.updateExportDeclaration(
                    node,
                    n,
                    0, // modifiers
                    false, // isTypeOnly
                    exportClause,
                    visitor.visitNodeInternal(n.ModuleSpecifier orelse 0),
                    visitor.visitNodeInternal(n.Attributes orelse 0),
                );
            },

            .NamedExports => |n| {
                const elementsList = tree.getNodeList(n.Elements);
                if (elementsList.len == 0) {
                    return node;
                }
                const elements = visitor.visitNodesInternal(n.Elements);
                const newElementsList = tree.getNodeList(elements);
                if (!(self.compilerOptions.verbatimModuleSyntax orelse false) and newElementsList.len == 0) {
                    return 0;
                }
                return self.transformer.factory.updateNamedExports(
                    node,
                    n,
                    elements,
                );
            },

            .ExportSpecifier => |n| {
                if (n.IsTypeOnly != 0) {
                    return 0;
                }
                return node;
            },

            .EnumDeclaration => {
                if (ast_utils.isEnumConst(tree, node)) {
                    return node;
                }
                return visitor.visitEachChild(node);
            },

            else => {
                return visitor.visitEachChild(node);
            }
        }
    }
};
