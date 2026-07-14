const std = @import("std");
const ast = @import("../../ast/ast.zig");
const core = @import("../../core/core.zig");
// const debug = @import("../../core/debug.zig");
const printer = @import("../../printer/printer.zig");
const transformers = @import("../transformer.zig");
const emitresolver = @import("../../printer/emitresolver.zig");
const factory = @import("../../printer/factory.zig");
const emitcontext = @import("../../printer/emitcontext.zig");
const ast_utils = @import("../../ast/ast_utils.zig");

pub const MetadataSerializerContext = struct {
    currentLexicalScope: ast.NodeIndex = 0,
    currentNameScope: ast.NodeIndex = 0,
    serializingConditionalTypeBranch: bool = false,
};

pub const MetadataSerializer = struct {
    pub fn new(
        allocator: std.mem.Allocator,
        resolver: *emitresolver.EmitResolver,
        f: *factory.NodeFactory,
        ec: *@import("../../printer/emitcontext.zig").EmitContext,
        languageVersion: core.ScriptTarget,
        strictNullChecks: bool,
    ) !*MetadataSerializer {
        _ = allocator;
        return newMetadataSerializer(resolver, f, ec, languageVersion, strictNullChecks);
    }

    resolver: *emitresolver.EmitResolver,
    languageVersion: core.ScriptTarget,
    strictNullChecks: bool,
    f: *factory.NodeFactory,
    ec: *@import("../../printer/emitcontext.zig").EmitContext,
    c: MetadataSerializerContext,

    pub fn newMetadataSerializer(
        resolver: *emitresolver.EmitResolver,
        f: *factory.NodeFactory,
        ec: *@import("../../printer/emitcontext.zig").EmitContext,
        languageVersion: core.ScriptTarget,
        strictNullChecks: bool,
    ) !*MetadataSerializer {
        const s = try f.allocator.create(MetadataSerializer);
        s.* = .{
            .resolver = resolver,
            .languageVersion = languageVersion,
            .strictNullChecks = strictNullChecks,
            .f = f,
            .ec = ec,
            .c = .{},
        };
        return s;
    }

    pub fn setContext(self: *MetadataSerializer, ctx: MetadataSerializerContext) void {
        self.c = ctx;
    }

    pub fn serializeTypeOfNode(self: *MetadataSerializer, ctx: MetadataSerializerContext, node: ast.NodeIndex, container: ast.NodeIndex) ast.NodeIndex {
        const oldCtx = self.c;
        self.c = ctx;
        defer self.setContext(oldCtx);
        return self.serializeTypeOfNodeInternal(node, container);
    }

    pub fn serializeParameterTypesOfNode(self: *MetadataSerializer, ctx: MetadataSerializerContext, node: ast.NodeIndex, container: ast.NodeIndex) ast.NodeIndex {
        const oldCtx = self.c;
        self.c = ctx;
        defer self.setContext(oldCtx);
        return self.serializeParameterTypesOfNodeInternal(node, container);
    }

    pub fn serializeReturnTypeOfNode(self: *MetadataSerializer, ctx: MetadataSerializerContext, node: ast.NodeIndex) ast.NodeIndex {
        const oldCtx = self.c;
        self.c = ctx;
        defer self.setContext(oldCtx);
        return self.serializeReturnTypeOfNodeInternal(node);
    }

    fn serializeTypeOfNodeInternal(self: *MetadataSerializer, node: ast.NodeIndex, container: ast.NodeIndex) ast.NodeIndex {
        const tree = self.ec.tree;
        const nodeKind = tree.getNodeKind(node);
        switch (nodeKind) {
            .PropertyDeclaration, .Parameter => {
                return self.serializeTypeNode(ast_utils.getTypeNode(tree, node));
            },
            .GetAccessor, .SetAccessor => {
                return self.serializeTypeNode(getAccessorTypeNode(tree, node, container));
            },
            .ClassDeclaration, .ClassExpression, .MethodDeclaration => {
                return self.f.newIdentifier("Function");
            },
            else => {
                return self.f.newVoidZeroExpression();
            },
        }
    }

    fn serializeParameterTypesOfNodeInternal(self: *MetadataSerializer, node: ast.NodeIndex, container: ast.NodeIndex) ast.NodeIndex {
        var valueDeclaration: ast.NodeIndex = 0;
        if (ast_utils.isClassLike(self.ec.tree, node)) {
            valueDeclaration = ast_utils.getFirstConstructorWithBody(self.ec.tree, node);
        } else if (ast_utils.isFunctionLike(self.ec.tree.getNodeKind(node)) and ast_utils.nodeIsPresent(self.ec.tree, ast_utils.getBodyOfNode(self.ec.tree, node))) {
            valueDeclaration = node;
        }

        if (valueDeclaration == 0) {
            return self.f.newArrayLiteralExpression(self.f.newNodeList(&[_]ast.NodeIndex{}), false);
        }

        var expressions = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer expressions.deinit(self.f.allocator);

        const parameters = getParametersOfDecoratedDeclaration(self.ec.tree, valueDeclaration, container);
        const paramList = self.ec.tree.getNodeList(parameters);

        for (paramList, 0..) |parameter, i| {
            if (i == 0 and ast_utils.isIdentifier(self.ec.tree, ast_utils.getNameOfNode(self.ec.tree, parameter))) {
                const nameNode = ast_utils.getNameOfNode(self.ec.tree, parameter);
                if (std.mem.eql(u8, ast_utils.getTextOfNode(self.ec.tree, nameNode), "this")) {
                    continue;
                }
            }

            const tNode = ast_utils.getTypeNode(self.ec.tree, parameter);
            std.debug.print("parameter {d} typeNode: {d} tag: {any}\n", .{ i, tNode, self.ec.tree.getNodeKind(tNode) });

            if (ast_utils.getDotDotDotTokenOfParameter(self.ec.tree, parameter) != 0) {
                expressions.append(self.f.allocator, self.serializeTypeNode(ast_utils.getRestParameterElementType(self.ec.tree, ast_utils.getTypeNode(self.ec.tree, parameter)))) catch unreachable;
            } else {
                expressions.append(self.f.allocator, self.serializeTypeOfNodeInternal(parameter, container)) catch unreachable;
            }
        }

        return self.f.newArrayLiteralExpression(self.f.newNodeList(expressions.items), false);
    }

    fn serializeReturnTypeOfNodeInternal(self: *MetadataSerializer, node: ast.NodeIndex) ast.NodeIndex {
        if (ast_utils.isFunctionLike(self.ec.tree.getNodeKind(node)) and ast_utils.getTypeNode(self.ec.tree, node) != 0) {
            return self.serializeTypeNode(ast_utils.getTypeNode(self.ec.tree, node));
        } else if (ast_utils.isAsyncFunction(self.ec.tree, node)) {
            return self.f.newIdentifier("Promise");
        }
        return self.f.newVoidZeroExpression();
    }

    fn serializeTypeNode(self: *MetadataSerializer, node: ast.NodeIndex) ast.NodeIndex {
        if (node == 0) {
            return self.f.newIdentifier("Object");
        }

        const skippedNode = ast_utils.skipTypeParentheses(self.ec.tree, node);
        const nodeData = self.ec.tree.getNode(skippedNode);

        switch (nodeData) {
            .VoidKeyword, .UndefinedKeyword, .NeverKeyword => {
                return self.f.newVoidZeroExpression();
            },
            .FunctionType, .ConstructorType => {
                return self.f.newIdentifier("Function");
            },
            .ArrayType, .TupleType => {
                return self.f.newIdentifier("Array");
            },
            .TypePredicate => {
                if (ast_utils.getAssertsModifierOfTypePredicate(self.ec.tree, skippedNode) != 0) {
                    return self.f.newVoidZeroExpression();
                }
                return self.f.newIdentifier("Boolean");
            },
            .BooleanKeyword => {
                return self.f.newIdentifier("Boolean");
            },
            .TemplateLiteralType, .StringKeyword => {
                return self.f.newIdentifier("String");
            },
            .ObjectKeyword => {
                return self.f.newIdentifier("Object");
            },
            .LiteralType => {
                return self.serializeLiteralOfLiteralTypeNode(ast_utils.getLiteralOfLiteralTypeNode(self.ec.tree, skippedNode));
            },
            .NumberKeyword => {
                return self.f.newIdentifier("Number");
            },
            .BigIntKeyword => {
                return self.serializeBigIntConstructor();
            },
            .SymbolKeyword => {
                return self.f.newIdentifier("Symbol");
            },
            .TypeReference => {
                return self.serializeTypeReferenceNode(skippedNode);
            },
            .IntersectionType => {
                const types = self.ec.tree.getNodeList(ast_utils.getTypesOfNode(self.ec.tree, skippedNode));
                return self.serializeUnionOrIntersectionConstituents(types, true);
            },
            .UnionType => {
                const types = self.ec.tree.getNodeList(ast_utils.getTypesOfNode(self.ec.tree, skippedNode));
                return self.serializeUnionOrIntersectionConstituents(types, false);
            },
            .ConditionalType => {
                const oldState = self.c.serializingConditionalTypeBranch;
                self.c.serializingConditionalTypeBranch = true;
                defer self.c.serializingConditionalTypeBranch = oldState;

                var branches = [_]ast.NodeIndex{ ast_utils.getTrueTypeOfNode(self.ec.tree, skippedNode), ast_utils.getFalseTypeOfNode(self.ec.tree, skippedNode) };
                return self.serializeUnionOrIntersectionConstituents(&branches, false);
            },
            .TypeOperator => {
                if (ast_utils.getOperatorOfTypeOperator(self.ec.tree, skippedNode) == ast_utils.SyntaxKind.ReadonlyKeyword) {
                    return self.serializeTypeNode(ast_utils.getTypeNode(self.ec.tree, skippedNode));
                }
                return self.f.newIdentifier("Object");
            },
            .TypeQuery, .IndexedAccessType, .MappedType, .TypeLiteral, .AnyKeyword, .UnknownKeyword, .ThisType, .ImportType => {
                return self.f.newIdentifier("Object");
            },
            .JSDocAllType, .JSDocVariadicType => {
                return self.f.newIdentifier("Object");
            },
            .JSDocNullableType, .JSDocNonNullableType, .JSDocOptionalType => {
                return self.serializeTypeNode(ast_utils.getTypeNode(self.ec.tree, skippedNode));
            },
            else => {
                return self.f.newIdentifier("Object");
            },
        }
    }

    fn serializeUnionOrIntersectionConstituents(self: *MetadataSerializer, types: []const ast.NodeIndex, isIntersection: bool) ast.NodeIndex {
        var serializedType: ast.NodeIndex = 0;
        for (types) |typeNodeRaw| {
            const typeNode = ast_utils.skipTypeParentheses(self.ec.tree, typeNodeRaw);
            const typeNodeData = self.ec.tree.getNode(typeNode);

            if (typeNodeData == .NeverKeyword) {
                if (isIntersection) {
                    return self.f.newVoidZeroExpression();
                }
                continue;
            }

            if (typeNodeData == .UnknownKeyword) {
                if (!isIntersection) {
                    return self.f.newIdentifier("Object");
                }
                continue;
            }

            if (typeNodeData == .AnyKeyword) {
                return self.f.newIdentifier("Object");
            }

            if (!self.strictNullChecks and ((typeNodeData == .LiteralType and ast_utils.getLiteralKind(self.ec.tree, ast_utils.getLiteralOfLiteralTypeNode(self.ec.tree, typeNode)) == .NullKeyword) or typeNodeData == .UndefinedKeyword)) {
                continue;
            }

            const serializedConstituent = self.serializeTypeNode(typeNode);
            if (serializedConstituent != 0 and std.meta.activeTag(self.ec.tree.getNode(serializedConstituent)) == .Identifier and std.mem.eql(u8, ast_utils.getTextOfNode(self.ec.tree, serializedConstituent), "Object")) {
                return serializedConstituent;
            }

            if (serializedType != 0) {
                if (!self.equateSerializedTypeNodes(serializedType, serializedConstituent)) {
                    return self.f.newIdentifier("Object");
                }
            } else {
                serializedType = serializedConstituent;
            }
        }

        if (serializedType != 0) {
            return serializedType;
        }
        return self.f.newVoidZeroExpression();
    }

    fn serializeLiteralOfLiteralTypeNode(self: *MetadataSerializer, node: ast.NodeIndex) ast.NodeIndex {
        const nodeData = self.ec.tree.getNode(node);
        switch (nodeData) {
            .StringLiteral, .NoSubstitutionTemplateLiteral => {
                return self.f.newIdentifier("String");
            },
            .PrefixUnaryExpression => {
                const operand = ast_utils.getOperandOfNode(self.ec.tree, node);
                const operandData = self.ec.tree.getNode(operand);
                switch (operandData) {
                    .NumericLiteral, .BigIntLiteral => {
                        return self.serializeLiteralOfLiteralTypeNode(operand);
                    },
                    else => {
                        @panic("Bad Syntax Kind");
                    },
                }
            },
            .NumericLiteral => {
                return self.f.newIdentifier("Number");
            },
            .BigIntLiteral => {
                return self.serializeBigIntConstructor();
            },
            .TrueKeyword, .FalseKeyword => {
                return self.f.newIdentifier("Boolean");
            },
            .NullKeyword => {
                return self.f.newVoidZeroExpression();
            },
            else => {
                return 0;
            },
        }
        return 0;
    }

    fn serializeTypeReferenceNode(self: *MetadataSerializer, node: ast.NodeIndex) ast.NodeIndex {
        var serialScope = self.c.currentNameScope;
        if (serialScope == 0) {
            serialScope = self.c.currentLexicalScope;
        }

        const typeName = ast_utils.getTypeNameOfNode(self.ec.tree, node);
        const kind_val = self.resolver.getTypeReferenceSerializationKind(self.ec.parseNode(typeName), self.ec.parseNode(serialScope));

        _ = kind_val;
        return 0;
    }

    fn serializeBigIntConstructor(self: *MetadataSerializer) ast.NodeIndex {
        if (@intFromEnum(self.languageVersion) >= @intFromEnum(core.ScriptTarget.ES2020)) {
            return self.f.newIdentifier("BigInt");
        }
        return self.f.newConditionalExpression(
            self.f.newTypeCheck(self.f.newIdentifier("BigInt"), "function"),
            self.f.newToken(.{ .QuestionToken = {} }),
            self.f.newIdentifier("BigInt"),
            self.f.newToken(.{ .ColonToken = {} }),
            self.f.newIdentifier("Object"),
        );
    }

    fn serializeEntityNameAsExpression(self: *MetadataSerializer, node: ast.NodeIndex) ast.NodeIndex {
        const nodeData = self.ec.tree.getNode(node);
        switch (nodeData) {
            .Identifier => {
                const name = ast_utils.cloneNode(self.ec.tree, self.f, node);
                ast_utils.setLoc(self.ec.tree, name, ast_utils.getLoc(self.ec.tree, node));
                self.ec.unsetOriginal(name);
                ast_utils.setParent(self.ec.tree, name, self.ec.parseNode(self.c.currentLexicalScope));
                return name;
            },
            .QualifiedName => {
                return self.serializeQualifiedNameAsExpression(node);
            },
            else => return 0,
        }
    }

    fn serializeQualifiedNameAsExpression(self: *MetadataSerializer, node: ast.NodeIndex) ast.NodeIndex {
        return self.f.newPropertyAccessExpression(
            self.serializeEntityNameAsExpression(ast_utils.getLeftOfNode(self.ec.tree, node)),
            0, // questionDotToken
            ast_utils.getRightOfNode(self.ec.tree, node),
            ast_utils.NodeFlags.None,
        );
    }

    fn serializeEntityNameAsExpressionFallback(self: *MetadataSerializer, node: ast.NodeIndex) ast.NodeIndex {
        const nodeData = self.ec.tree.getNode(node);
        if (nodeData == .Identifier) {
            const copied = self.serializeEntityNameAsExpression(node);
            return self.createCheckedValue(copied, copied);
        }

        const left = ast_utils.getLeftOfNode(self.ec.tree, node);
        const leftData = self.ec.tree.getNode(left);
        if (leftData == .Identifier) {
            return self.createCheckedValue(self.serializeEntityNameAsExpression(left), self.serializeEntityNameAsExpression(node));
        }

        const leftFallback = self.serializeEntityNameAsExpressionFallback(left);
        const temp = self.f.newTempVariable();
        self.ec.addVariableDeclaration(temp);

        return self.f.newLogicalANDExpression(self.f.newLogicalANDExpression(ast_utils.getLeftOfNode(self.ec.tree, leftFallback), self.f.newStrictInequalityExpression(self.f.newAssignmentExpression(temp, ast_utils.getRightOfNode(self.ec.tree, leftFallback)), self.f.newVoidZeroExpression())), self.f.newPropertyAccessExpression(temp, 0, ast_utils.getRightOfNode(self.ec.tree, node), ast_utils.NodeFlags.None));
    }

    fn createCheckedValue(self: *MetadataSerializer, left: ast.NodeIndex, right: ast.NodeIndex) ast.NodeIndex {
        return self.f.newLogicalANDExpression(self.f.newStrictInequalityExpression(self.f.newTypeOfExpression(left), self.f.newStringLiteral("undefined", ast_utils.TokenFlags.None)), right);
    }

    fn equateSerializedTypeNodes(self: *MetadataSerializer, left: ast.NodeIndex, right: ast.NodeIndex) bool {
        if (transformers.isGeneratedIdentifier(self.ec, left)) {
            return transformers.isGeneratedIdentifier(self.ec, right);
        }
        if (ast_utils.isIdentifier(self.ec.tree, left)) {
            return ast_utils.isIdentifier(self.ec.tree, right) and std.mem.eql(u8, ast_utils.getTextOfNode(self.ec.tree, left), ast_utils.getTextOfNode(self.ec.tree, right));
        }
        if (ast_utils.isPropertyAccessExpression(self.ec.tree, left)) {
            return ast_utils.isPropertyAccessExpression(self.ec.tree, right) and
                self.equateSerializedTypeNodes(ast_utils.getExpressionOfNode(self.ec.tree, left), ast_utils.getExpressionOfNode(self.ec.tree, right)) and
                self.equateSerializedTypeNodes(ast_utils.getNameOfNode(self.ec.tree, left), ast_utils.getNameOfNode(self.ec.tree, right));
        }
        if (ast_utils.isVoidExpression(self.ec.tree, left)) {
            const leftExpr = ast_utils.getExpressionOfNode(self.ec.tree, left);
            const rightExpr = ast_utils.getExpressionOfNode(self.ec.tree, right);
            return ast_utils.isVoidExpression(self.ec.tree, right) and
                ast_utils.isNumericLiteral(self.ec.tree, leftExpr) and
                ast_utils.isNumericLiteral(self.ec.tree, rightExpr) and
                std.mem.eql(u8, ast_utils.getTextOfNode(self.ec.tree, leftExpr), "0") and
                std.mem.eql(u8, ast_utils.getTextOfNode(self.ec.tree, rightExpr), "0");
        }
        if (ast_utils.isStringLiteral(self.ec.tree, left)) {
            return ast_utils.isStringLiteral(self.ec.tree, right) and std.mem.eql(u8, ast_utils.getTextOfNode(self.ec.tree, left), ast_utils.getTextOfNode(self.ec.tree, right));
        }
        if (ast_utils.isTypeOfExpression(self.ec.tree, left)) {
            return ast_utils.isTypeOfExpression(self.ec.tree, right) and self.equateSerializedTypeNodes(ast_utils.getExpressionOfNode(self.ec.tree, left), ast_utils.getExpressionOfNode(self.ec.tree, right));
        }
        if (ast_utils.isParenthesizedExpression(self.ec.tree, left)) {
            return ast_utils.isParenthesizedExpression(self.ec.tree, right) and self.equateSerializedTypeNodes(ast_utils.getExpressionOfNode(self.ec.tree, left), ast_utils.getExpressionOfNode(self.ec.tree, right));
        }
        if (ast_utils.isConditionalExpression(self.ec.tree, left)) {
            return ast_utils.isConditionalExpression(self.ec.tree, right) and
                self.equateSerializedTypeNodes(ast_utils.getConditionOfNode(self.ec.tree, left), ast_utils.getConditionOfNode(self.ec.tree, right)) and
                self.equateSerializedTypeNodes(ast_utils.getWhenTrueOfNode(self.ec.tree, left), ast_utils.getWhenTrueOfNode(self.ec.tree, right)) and
                self.equateSerializedTypeNodes(ast_utils.getWhenFalseOfNode(self.ec.tree, left), ast_utils.getWhenFalseOfNode(self.ec.tree, right));
        }
        if (std.meta.activeTag(self.ec.tree.getNode(left)) == .BinaryExpression) {
            return std.meta.activeTag(self.ec.tree.getNode(right)) == .BinaryExpression and
                ast_utils.getOperatorTokenOfNode(self.ec.tree, left) == ast_utils.getOperatorTokenOfNode(self.ec.tree, right) and
                self.equateSerializedTypeNodes(ast_utils.getLeftOfNode(self.ec.tree, left), ast_utils.getLeftOfNode(self.ec.tree, right)) and
                self.equateSerializedTypeNodes(ast_utils.getRightOfNode(self.ec.tree, left), ast_utils.getRightOfNode(self.ec.tree, right));
        }
        return false;
    }
};

pub fn getSetAccessorValueParameter(tree: *ast.Ast, node: ast.NodeIndex) ast.NodeIndex {
    if (node != 0) {
        const paramList = ast_utils.getParametersOfNode(tree, node);
        if (paramList.len > 0) {
            if (paramList.len >= 2 and ast_utils.isThisParameter(tree, paramList[0])) {
                return paramList[1];
            }
            return paramList[0];
        }
    }
    return 0;
}

pub fn getSetAccessorTypeAnnotationNode(tree: *ast.Ast, node: ast.NodeIndex) ast.NodeIndex {
    const p = getSetAccessorValueParameter(tree, node);
    if (p != 0) {
        const typeNode = ast_utils.getTypeNode(tree, p);
        if (typeNode != 0) {
            return typeNode;
        }
    }
    return 0;
}

pub fn getAccessorTypeNode(tree: *ast.Ast, node: ast.NodeIndex, container: ast.NodeIndex) ast.NodeIndex {
    const accessors = ast_utils.getAllAccessorDeclarations(tree, tree.getNodeList(ast_utils.getMembersOfNode(tree, container)), node);
    if (accessors.setAccessor != 0) {
        return getSetAccessorTypeAnnotationNode(tree, accessors.setAccessor);
    }
    if (accessors.getAccessor != 0) {
        return ast_utils.getTypeNode(tree, accessors.getAccessor);
    }
    return 0;
}

fn getParametersOfDecoratedDeclaration(tree: *ast.Ast, node: ast.NodeIndex, container: ast.NodeIndex) ast.NodeIndex {
    if (container != 0 and tree.getNode(node) == .GetAccessor) {
        const acc = ast_utils.getAllAccessorDeclarations(tree, tree.getNodeList(ast_utils.getMembersOfNode(tree, container)), node);
        if (acc.setAccessor != 0) {
            return ast_utils.parameters(tree, acc.setAccessor);
        }
    }
    return ast_utils.parameters(tree, node);
}
