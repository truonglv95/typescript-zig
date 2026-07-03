const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const NodeIndex = ast_gen.NodeIndex;
const types = @import("types.zig");
const TypeIndex = types.TypeIndex;
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;

export fn dummy_force_typecheck() void {
    var c: Checker = undefined;
    _ = getTypeFromTypeNode(&c, 0);
}

pub fn getTypeFromTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    return c.getConditionalFlowTypeOfType(getTypeFromTypeNodeWorker(c, node), node);
}

fn getTypeFromTypeNodeWorker(c: *Checker, node: NodeIndex) TypeIndex {
    const kind = c.binder.ast.getKind(node);
    switch (kind) {
        .AnyKeyword, .JSDocAllType => return c.anyType,
        .JSDocNonNullableType => {
            const typeNode = c.binder.ast.getNode(node).Type.?;
            return getTypeFromTypeNode(c, typeNode);
        },
        .JSDocNullableType => {
            const typeNode = c.binder.ast.getNode(node).Type.?;
            const t = getTypeFromTypeNode(c, typeNode);
            if (c.strictNullChecks) {
                return c.getNullableType(t, types.TypeFlags.Null);
            } else {
                return t;
            }
        },
        .JSDocVariadicType => {
            const varType = c.binder.ast.getNode(node).AsJSDocVariadicType().Type;
            return c.createArrayType(getTypeFromTypeNode(c, varType));
        },
        .JSDocOptionalType => {
            const typeNode = c.binder.ast.getNode(node).Type.?;
            return c.addOptionality(getTypeFromTypeNode(c, typeNode));
        },
        .UnknownKeyword => return c.unknownType,
        .StringKeyword => return c.stringType,
        .NumberKeyword => return c.numberType,
        .BigIntKeyword => return c.bigintType,
        .BooleanKeyword => return c.booleanType,
        .SymbolKeyword => return c.esSymbolType,
        .VoidKeyword => return c.voidType,
        .UndefinedKeyword => return c.undefinedType,
        .NullKeyword => return c.nullType,
        .NeverKeyword => return c.neverType,
        .ObjectKeyword => return c.nonPrimitiveType,
        .IntrinsicKeyword => return c.intrinsicMarkerType,
        .ThisType, .ThisKeyword => return c.getTypeFromThisTypeNode(node),
        .LiteralType => return c.getTypeFromLiteralTypeNode(node),
        .TypeReference, .ExpressionWithTypeArguments => return c.getTypeFromTypeReference(node),
        .TypePredicate => {
            if (c.binder.ast.getNode(node).AsTypePredicateNode().AssertsModifier != 0) {
                return c.voidType;
            }
            return c.booleanType;
        },
        .TypeQuery => return c.getTypeFromTypeQueryNode(node),
        .ArrayType, .TupleType => return c.getTypeFromArrayOrTupleTypeNode(node),
        .OptionalType => return c.getTypeFromOptionalTypeNode(node),
        .UnionType => return c.getTypeFromUnionTypeNode(node),
        .IntersectionType => return c.getTypeFromIntersectionTypeNode(node),
        .NamedTupleMember => return c.getTypeFromNamedTupleTypeNode(node),
        .ParenthesizedType => {
            const typeNode = c.binder.ast.getNode(node).Type.?;
            return getTypeFromTypeNode(c, typeNode);
        },
        .RestType => return c.getTypeFromRestTypeNode(node),
        .FunctionType, .ConstructorType, .TypeLiteral => return c.getTypeFromTypeLiteralOrFunctionOrConstructorTypeNode(node),
        .TypeOperator => return c.getTypeFromTypeOperatorNode(node),
        .IndexedAccessType => return c.getTypeFromIndexedAccessTypeNode(node),
        .TemplateLiteralType => return c.getTypeFromTemplateTypeNode(node),
        .MappedType => return c.getTypeFromMappedTypeNode(node),
        .ConditionalType => return c.getTypeFromConditionalTypeNode(node),
        .InferType => return c.getTypeFromInferTypeNode(node),
        .ImportType => return c.getTypeFromImportTypeNode(node),
        else => return c.errorType,
    }
}

pub fn getConditionalFlowTypeOfType(c: *Checker, t: TypeIndex, node: NodeIndex) TypeIndex {
    _ = c;
    _ = node;
    return t; // Default to returning the same type for now
}

fn getThisType(c: *Checker, node: NodeIndex) TypeIndex {
    _ = node;
    // TODO: implement getThisType
    return c.errorType;
}

pub fn getTypeFromThisTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        const parent = c.binder.ast.getNode(node).Parent;
        if (parent != null and c.binder.ast.getKind(parent.?) == .TypeQuery) {
            entry.value_ptr.resolvedType = c.errorType;
        } else {
            entry.value_ptr.resolvedType = getThisType(c, node);
        }
    }
    return entry.value_ptr.resolvedType;
}
pub fn getTypeFromLiteralTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        const literal = c.binder.ast.getNode(node).LiteralType.Literal;
        const checkedType = c.checkExpression(literal) catch c.errorType;
        entry.value_ptr.resolvedType = c.getRegularTypeOfLiteralType(checkedType);
    }
    return entry.value_ptr.resolvedType;
}
pub fn getTypeFromTypeReference(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }

    if (entry.value_ptr.resolvedType == 0) {
        if (isConstTypeReference(c, node) and c.binder.ast.getNode(node).Parent != null and c.binder.ast.isAssertionExpression(c.binder.ast.getNode(node).Parent.?)) {
            entry.value_ptr.resolvedType = c.unknownType;
        } else {
            const t = getIntendedTypeFromJSDocTypeReference(c, node);
            if (t != 0) {
                entry.value_ptr.resolvedType = t;
            } else {
                entry.value_ptr.resolvedType = getTypeReferenceType(c, node, getSymbolFromTypeReference(c, node));
            }
        }
    }

    return entry.value_ptr.resolvedType;
}

fn isConstTypeReference(c: *Checker, node: NodeIndex) bool {
    const kind = c.binder.ast.getKind(node);
    if (kind != .TypeReference) return false;
    const n = c.binder.ast.getNode(node).TypeReference;
    if (n.TypeArguments != null) return false;

    const typeName = n.TypeName;
    if (!c.binder.ast.isIdentifier(typeName)) return false;

    const text = c.binder.ast.getText(typeName);
    return std.mem.eql(u8, text, "const");
}

fn getTypeReferenceName(c: *Checker, node: NodeIndex) ?NodeIndex {
    const nodeObj = c.binder.ast.getNode(node);
    switch (nodeObj.kind) {
        .TypeReference => {
            return nodeObj.TypeReference.TypeName;
        },
        .ExpressionWithTypeArguments => {
            return nodeObj.ExpressionWithTypeArguments.Expression;
        },
        .JSDocTypedefTag, .JSDocCallbackTag, .JSDocEnumTag => {
            return nodeObj.JSDocTag.Name; // Note: Need to check if JSDocTag has Name field
        },
        .JSDocSignature => {
            if (nodeObj.Parent != null) {
                const parentObj = c.binder.ast.getNode(nodeObj.Parent.?);
                if (parentObj.kind == .JSDocCallbackTag) {
                    return parentObj.JSDocTag.Name;
                }
            }
        },
        else => {},
    }
    return null;
}

fn getIntendedTypeFromJSDocTypeReference(c: *Checker, node: NodeIndex) TypeIndex {
    const parent = c.binder.ast.getNode(node).Parent;
    if (parent != null and c.binder.ast.getKind(parent.?) == .JSDocTypeExpression) {
        const grandParent = c.binder.ast.getNode(parent.?).Parent;
        if (grandParent != null) {
            switch (c.binder.ast.getKind(grandParent.?)) {
                .JSDocReturnTag => {
                    // TODO: return c.getTypeFromJSDocReturnTag(grandParent.?)
                    return 0;
                },
                .JSDocParameterTag, .JSDocPropertyTag, .JSDocTypeTag, .JSDocTypedefTag, .JSDocCallbackTag => {
                    // TODO: return c.getTypeOfSymbol(c.getSymbolOfDeclaration(grandParent.?))
                    return 0;
                },
                else => {},
            }
        }
    }
    return 0;
}

fn getSymbolFromTypeReference(c: *Checker, node: NodeIndex) ast_gen.SymbolIndex {
    var entry = c.symbolNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedSymbol == 0) {
        if (isConstTypeReference(c, node) and c.binder.ast.getNode(node).Parent != null and c.binder.ast.isAssertionExpression(c.binder.ast.getNode(node).Parent.?)) {
            entry.value_ptr.resolvedSymbol = c.unknownSymbol;
        } else {
            entry.value_ptr.resolvedSymbol = resolveTypeReferenceName(c, node, ast_gen.SymbolFlags.Type, false);
        }
    }
    return entry.value_ptr.resolvedSymbol;
}

fn resolveTypeReferenceName(c: *Checker, typeReference: NodeIndex, meaning: u32, ignoreErrors: bool) ast_gen.SymbolIndex {
    const name = getTypeReferenceName(c, typeReference);
    if (name == null) {
        return c.unknownSymbol;
    }
    const symbol = c.resolveEntityName(name.?, meaning, ignoreErrors, false, null);
    if (symbol != 0 and symbol != c.unknownSymbol) {
        return symbol;
    }
    if (ignoreErrors) {
        return c.unknownSymbol;
    }
    return getUnresolvedSymbolForEntityName(c, name.?);
}

fn getUnresolvedSymbolForEntityName(c: *Checker, name: NodeIndex) ast_gen.SymbolIndex {
    _ = name;
    // TODO: implement UnresolvedSymbol resolution and creation
    return c.unknownSymbol;
}

fn getTypeReferenceType(c: *Checker, node: NodeIndex, symbol: ast_gen.SymbolIndex) TypeIndex {
    if (symbol == c.unknownSymbol) {
        return c.errorType;
    }

    const flags = c.getSymbolFlags(symbol);
    if ((flags & (ast_gen.SymbolFlags.Class | ast_gen.SymbolFlags.Interface)) != 0) {
        return getTypeFromClassOrInterfaceReference(c, node, symbol);
    }
    if ((flags & ast_gen.SymbolFlags.TypeAlias) != 0) {
        return getTypeFromTypeAliasReference(c, node, symbol);
    }

    const res = tryGetDeclaredTypeOfSymbol(c, symbol);
    if (res != 0 and checkNoTypeArguments(c, node, symbol)) {
        return c.getRegularTypeOfLiteralType(res);
    }

    return c.errorType;
}

fn getTypeFromClassOrInterfaceReference(c: *Checker, node: NodeIndex, symbol: ast_gen.SymbolIndex) TypeIndex {
    const t = getDeclaredTypeOfClassOrInterface(c, getMergedSymbol(c, symbol));
    if (t == 0) return c.errorType; // safeguard

    // d := t.AsInterfaceType()
    // typeParameters := d.LocalTypeParameters()
    const typeParameters = getLocalTypeParameters(c, t);

    if (typeParameters.len != 0) {
        const typeArgsLen = getTypeArgumentsLength(c, node);
        const minTypeArgumentCount = getMinTypeArgumentCount(c, typeParameters);
        const isJs = c.binder.ast.isInJSFile(node);
        const isJsImplicitAny = !c.noImplicitAny and isJs;

        if (!isJsImplicitAny and (typeArgsLen < minTypeArgumentCount or typeArgsLen > typeParameters.len)) {
            // Diagnostics omitted for stub
            if (!isJs) {
                return c.errorType;
            }
        }

        if (c.binder.ast.getKind(node) == .TypeReference and isDeferredTypeReferenceNode(c, node, typeArgsLen != typeParameters.len)) {
            return createDeferredTypeReference(c, t, node, 0, 0);
        }

        const typeArgumentsFromNode = getTypeArgumentsFromNode(c, node);
        const localTypeArguments = fillMissingTypeArguments(c, typeArgumentsFromNode, typeParameters, minTypeArgumentCount, isJs);

        // typeArguments = append(d.OuterTypeParameters(), localTypeArguments...)
        const outerTypeParameters = getOuterTypeParameters(c, t);
        const typeArguments = appendTypeArrays(c, outerTypeParameters, localTypeArguments);

        return createTypeReferenceEx(c, t, typeArguments, types.ObjectFlags.FromTypeNode);
    }

    if (checkNoTypeArguments(c, node, symbol)) {
        return t;
    }
    return c.errorType;
}

fn getMergedSymbol(c: *Checker, symbol: ast_gen.SymbolIndex) ast_gen.SymbolIndex {
    _ = c;
    _ = symbol;
    return 0;
}
fn getDeclaredTypeOfClassOrInterface(c: *Checker, symbol: ast_gen.SymbolIndex) TypeIndex {
    _ = c;
    _ = symbol;
    return 0;
}
fn getLocalTypeParameters(c: *Checker, t: TypeIndex) []const TypeIndex {
    _ = c;
    _ = t;
    return &[_]TypeIndex{};
}
fn getTypeArgumentsLength(c: *Checker, node: NodeIndex) usize {
    if (getTypeArgumentsNode(c, node)) |argsNode| {
        return c.binder.ast.getNodeList(argsNode).len;
    }
    return 0;
}

fn hasDefaultTypeParameter(c: *Checker, t: TypeIndex) bool {
    _ = c;
    _ = t;
    // TODO: implement hasDefaultTypeParameter
    return false;
}

fn getMinTypeArgumentCount(c: *Checker, typeParameters: []const TypeIndex) usize {
    var minTypeArgumentCount: usize = 0;
    for (typeParameters, 0..) |tp, i| {
        if (!hasDefaultTypeParameter(c, tp)) {
            minTypeArgumentCount = i + 1;
        }
    }
    return minTypeArgumentCount;
}
fn isDeferredTypeReferenceNode(c: *Checker, node: NodeIndex, diffLen: bool) bool {
    _ = c;
    _ = node;
    _ = diffLen;
    return false;
}
fn createDeferredTypeReference(c: *Checker, t: TypeIndex, node: NodeIndex, mapper: usize, alias: usize) TypeIndex {
    _ = c;
    _ = t;
    _ = node;
    _ = mapper;
    _ = alias;
    return 0;
}
fn getTypeArgumentsNode(c: *Checker, node: NodeIndex) ?NodeIndex {
    if (node == 0) return null;
    const nodeObj = c.binder.ast.getNode(node);
    return switch (nodeObj.kind) {
        .TypeReference => nodeObj.TypeReference.TypeArguments,
        .ExpressionWithTypeArguments => nodeObj.ExpressionWithTypeArguments.TypeArguments,
        .CallExpression => nodeObj.CallExpression.TypeArguments,
        .NewExpression => nodeObj.NewExpression.TypeArguments,
        .TaggedTemplateExpression => nodeObj.TaggedTemplateExpression.TypeArguments,
        .JsxOpeningElement => nodeObj.JsxOpeningElement.TypeArguments,
        .JsxSelfClosingElement => nodeObj.JsxSelfClosingElement.TypeArguments,
        .ImportType => nodeObj.ImportType.TypeArguments,
        else => null,
    };
}

fn getTypeArgumentsFromNode(c: *Checker, node: NodeIndex) []const TypeIndex {
    if (getTypeArgumentsNode(c, node)) |argsNode| {
        const argNodes = c.binder.ast.getNodeList(argsNode);
        if (argNodes.len == 0) return &[_]TypeIndex{};

        var typeArgs = c.allocator.alloc(TypeIndex, argNodes.len) catch @panic("OOM");
        for (argNodes, 0..) |argNode, i| {
            typeArgs[i] = c.getTypeFromTypeNode(argNode);
        }
        return typeArgs;
    }
    return &[_]TypeIndex{};
}

fn checkNoTypeArguments(c: *Checker, node: NodeIndex, symbol: ast_gen.SymbolIndex) bool {
    const typeArguments = getTypeArgumentsNode(c, node);
    if (typeArguments != null and c.binder.ast.getNodeList(typeArguments.?).len > 0) {
        // TODO: error reporting
        _ = symbol;
        return false;
    }
    return true;
}

fn fillMissingTypeArguments(c: *Checker, typeArgumentsFromNode: []const TypeIndex, typeParameters: []const TypeIndex, minTypeArgumentCount: usize, isJs: bool) []const TypeIndex {
    const numTypeArguments = typeArgumentsFromNode.len;
    if (numTypeArguments == typeParameters.len) {
        return typeArgumentsFromNode;
    }

    var result = c.allocator.alloc(TypeIndex, typeParameters.len) catch @panic("OOM");
    @memcpy(result[0..numTypeArguments], typeArgumentsFromNode);

    if (isJs) {
        for (numTypeArguments..typeParameters.len) |i| {
            result[i] = c.anyType;
        }
        return result;
    }

    for (numTypeArguments..typeParameters.len) |i| {
        if (i < minTypeArgumentCount) {
            result[i] = c.errorType;
        } else {
            // TODO: c.getDefaultTypeArgumentType(isJs)(typeParameters[i])
            result[i] = c.errorType;
        }
    }
    return result;
}
fn getOuterTypeParameters(c: *Checker, t: TypeIndex) []const TypeIndex {
    _ = c;
    _ = t;
    return &[_]TypeIndex{};
}
fn appendTypeArrays(c: *Checker, arr1: []const TypeIndex, arr2: []const TypeIndex) []const TypeIndex {
    _ = c;
    _ = arr1;
    _ = arr2;
    return &[_]TypeIndex{};
}
fn createTypeReferenceEx(c: *Checker, t: TypeIndex, typeArguments: []const TypeIndex, objectFlags: u32) TypeIndex {
    _ = c;
    _ = t;
    _ = typeArguments;
    _ = objectFlags;
    return 0;
}

fn getTypeFromTypeAliasReference(c: *Checker, node: NodeIndex, symbol: ast_gen.SymbolIndex) TypeIndex {
    _ = c;
    _ = node;
    _ = symbol;
    return 0;
}
fn tryGetDeclaredTypeOfSymbol(c: *Checker, symbol: ast_gen.SymbolIndex) TypeIndex {
    _ = c;
    _ = symbol;
    return 0;
}

pub fn getTypeFromTypeQueryNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        const t = checkExpressionWithTypeArguments(c, node);
        entry.value_ptr.resolvedType = c.getRegularTypeOfLiteralType(getWidenedType(c, t));
    }
    return entry.value_ptr.resolvedType;
}

pub fn getTypeFromArrayOrTupleTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        const target = getArrayOrTupleTargetType(c, node);
        if (target == c.emptyGenericTypeIndex orelse 0) {
            entry.value_ptr.resolvedType = c.emptyObjectTypeIndex orelse 0;
        } else if (!(c.binder.ast.getKind(node) == .TupleType and coreSomeVariadic(c, node)) and isDeferredTypeReferenceNode(c, node, false)) {
            if (c.binder.ast.getKind(node) == .TupleType and getTupleElementsLen(c, node) == 0) {
                entry.value_ptr.resolvedType = target;
            } else {
                entry.value_ptr.resolvedType = createDeferredTypeReference(c, target, node, 0, 0);
            }
        } else {
            // Stubbed complex branch
            entry.value_ptr.resolvedType = target;
        }
    }
    return entry.value_ptr.resolvedType;
}

pub fn getTypeFromOptionalTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        entry.value_ptr.resolvedType = addOptionality(c, getTypeFromTypeNode(c, c.binder.ast.getNode(node).OptionalType.Type));
    }
    return entry.value_ptr.resolvedType;
}

pub fn getTypeFromNamedTupleTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        entry.value_ptr.resolvedType = getTypeFromTypeNode(c, c.binder.ast.getNode(node).NamedTupleMember.Type);
    }
    return entry.value_ptr.resolvedType;
}

pub fn getTypeFromRestTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        entry.value_ptr.resolvedType = getTypeFromTypeNode(c, c.binder.ast.getNode(node).RestType.Type);
    }
    return entry.value_ptr.resolvedType;
}

fn checkExpressionWithTypeArguments(c: *Checker, node: NodeIndex) TypeIndex {
    _ = c;
    _ = node;
    return 0;
}
fn getWidenedType(c: *Checker, t: TypeIndex) TypeIndex {
    _ = c;
    _ = t;
    return 0;
}
fn getArrayOrTupleTargetType(c: *Checker, node: NodeIndex) TypeIndex {
    _ = c;
    _ = node;
    return 0;
}
fn coreSomeVariadic(c: *Checker, node: NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}
fn getTupleElementsLen(c: *Checker, node: NodeIndex) usize {
    _ = c;
    _ = node;
    return 0;
}
fn addOptionality(c: *Checker, t: TypeIndex) TypeIndex {
    _ = c;
    _ = t;
    return 0;
}

pub fn getTypeFromUnionTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        const typesNode = c.binder.ast.getNode(node).UnionType.Types.?;
        const nodes = c.binder.ast.getNodeList(typesNode);

        var mappedTypes = c.allocator.alloc(TypeIndex, nodes.len) catch @panic("OOM");
        for (nodes, 0..) |n, i| {
            mappedTypes[i] = getTypeFromTypeNode(c, n);
        }
        entry.value_ptr.resolvedType = c.getUnionTypeFromArray(mappedTypes);
    }
    return entry.value_ptr.resolvedType;
}
pub fn getTypeFromIntersectionTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        const typesNode = c.binder.ast.getNode(node).IntersectionType.Types.?;
        const nodes = c.binder.ast.getNodeList(typesNode);

        var mappedTypes = c.allocator.alloc(TypeIndex, nodes.len) catch @panic("OOM");
        for (nodes, 0..) |n, i| {
            mappedTypes[i] = getTypeFromTypeNode(c, n);
        }

        var noSupertypeReduction = false;
        if (mappedTypes.len == 2) {
            const emptyType = c.emptyTypeLiteralTypeIndex orelse 0;
            var emptyIndex: i32 = -1;
            if (mappedTypes[0] == emptyType) emptyIndex = 0;
            if (mappedTypes[1] == emptyType) emptyIndex = 1;

            if (emptyIndex >= 0) {
                const tIndex = if (emptyIndex == 0) mappedTypes[1] else mappedTypes[0];
                const tFlags = c.getTypeFlags(tIndex);
                if (tFlags & (types.TypeFlags.String | types.TypeFlags.Number | types.TypeFlags.BigInt) != 0 or
                    (tFlags & types.TypeFlags.TemplateLiteral != 0 and c.isPatternLiteralType(tIndex)))
                {
                    noSupertypeReduction = true;
                }
            }
        }

        // Ignore noSupertypeReduction for now
        entry.value_ptr.resolvedType = c.getIntersectionType(mappedTypes);
    }
    return entry.value_ptr.resolvedType;
}
pub fn getTypeFromTypeLiteralOrFunctionOrConstructorTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        const alias = getAliasForTypeNode(c, node);
        const sym = getSymbolOfNode(c, node);
        if (sym == 0 or (getMembersOfSymbol(c, sym).len == 0 and alias == 0)) {
            entry.value_ptr.resolvedType = c.emptyTypeLiteralTypeIndex orelse c.errorType;
        } else {
            const t = newObjectType(c, types.ObjectFlags.Anonymous, sym);
            // Handle alias if necessary
            entry.value_ptr.resolvedType = t;
        }
    }
    return entry.value_ptr.resolvedType;
}

pub fn getTypeFromTypeOperatorNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        const argTypeNode = c.binder.ast.getNode(node).Type.?;
        const kind = c.binder.ast.getNode(node).AsTypeOperatorNode().Operator;
        if (kind == ast_gen.SyntaxKind.KeyOfKeyword) {
            entry.value_ptr.resolvedType = c.getIndexType(getTypeFromTypeNode(c, argTypeNode));
        } else if (kind == ast_gen.SyntaxKind.UniqueKeyword) {
            if (c.binder.ast.getKind(argTypeNode) == .SymbolKeyword) {
                // entry.value_ptr.resolvedType = c.getESSymbolLikeTypeForNode(walkUpParenthesizedTypes(c, c.binder.ast.getNode(node).Parent));
                entry.value_ptr.resolvedType = c.errorType; // stub
            } else {
                entry.value_ptr.resolvedType = c.errorType;
            }
        } else if (kind == ast_gen.SyntaxKind.ReadonlyKeyword) {
            entry.value_ptr.resolvedType = getTypeFromTypeNode(c, argTypeNode);
        } else {
            entry.value_ptr.resolvedType = c.errorType;
        }
    }
    return entry.value_ptr.resolvedType;
}

pub fn getTypeFromIndexedAccessTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        const indexedNode = c.binder.ast.getNode(node).AsIndexedAccessTypeNode();
        const objectType = getTypeFromTypeNode(c, indexedNode.ObjectType);
        const indexType = getTypeFromTypeNode(c, indexedNode.IndexType);
        const potentialAlias = getAliasForTypeNode(c, node);
        entry.value_ptr.resolvedType = getIndexedAccessTypeEx(c, objectType, indexType, types.AccessFlags.None, node, potentialAlias);
    }
    return entry.value_ptr.resolvedType;
}

fn getAliasForTypeNode(c: *Checker, node: NodeIndex) usize {
    _ = c;
    _ = node;
    return 0;
}
fn getSymbolOfNode(c: *Checker, node: NodeIndex) ast_gen.SymbolIndex {
    _ = c;
    _ = node;
    return 0;
}
fn getMembersOfSymbol(c: *Checker, symbol: ast_gen.SymbolIndex) []const ast_gen.SymbolIndex {
    _ = c;
    _ = symbol;
    return &[_]ast_gen.SymbolIndex{};
}
fn newObjectType(c: *Checker, objectFlags: u32, symbol: ast_gen.SymbolIndex) TypeIndex {
    return c.createType(.{
        .flags = types.TypeFlags.Object,
        .objectFlags = objectFlags,
        .id = 0,
        .symbol = symbol,
        .alias = null,
        .data = .{ .Object = .{
            .propertiesStart = 0,
            .propertiesLen = 0,
            .callSignaturesStart = 0,
            .callSignaturesLen = 0,
            .constructSignaturesStart = 0,
            .constructSignaturesLen = 0,
            .stringIndexInfo = null,
            .numberIndexInfo = null,
        } },
    }) catch 0;
}
fn walkUpParenthesizedTypes(c: *Checker, node: NodeIndex) NodeIndex {
    _ = c;
    return node;
}
fn getIndexedAccessTypeEx(c: *Checker, objectType: TypeIndex, indexType: TypeIndex, accessFlags: u32, node: NodeIndex, potentialAlias: usize) TypeIndex {
    _ = accessFlags;
    _ = node;
    _ = potentialAlias;
    return c.getIndexedAccessType(objectType, indexType);
}

fn getTemplateLiteralType(c: *Checker, texts: [][]const u8, typesArr: []const TypeIndex) TypeIndex {
    _ = texts;
    _ = typesArr;
    return c.stringType;
}

pub fn getTypeFromTemplateTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        const spansNode = c.binder.ast.getNode(node).TemplateLiteralType.TemplateSpans.?;
        const spans = c.binder.ast.getNodeList(spansNode);

        var texts = c.allocator.alloc([]const u8, spans.len + 1) catch @panic("OOM");
        var mappedTypes = c.allocator.alloc(TypeIndex, spans.len) catch @panic("OOM");

        texts[0] = c.binder.ast.getText(c.binder.ast.getNode(node).TemplateLiteralType.Head);

        for (spans, 0..) |span, i| {
            texts[i + 1] = c.binder.ast.getText(c.binder.ast.getNode(span).TemplateLiteralTypeSpan.Literal);
            mappedTypes[i] = getTypeFromTypeNode(c, c.binder.ast.getNode(span).Type.?);
        }

        entry.value_ptr.resolvedType = getTemplateLiteralType(c, texts, mappedTypes);
    }
    return entry.value_ptr.resolvedType;
}
pub fn getTypeFromMappedTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        const sym = getSymbolOfNode(c, node);
        const t = newObjectType(c, types.ObjectFlags.Mapped, sym);
        // t.AsMappedType().declaration = node
        // t.alias = getAliasForTypeNode(c, node)
        entry.value_ptr.resolvedType = t;

        // Eagerly resolve the constraint type
        _ = c.getConstraintTypeFromMappedType(t);
    }
    return entry.value_ptr.resolvedType;
}

pub fn getTypeFromConditionalTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        const condNode = c.binder.ast.getNode(node).ConditionalType;
        const checkType = getTypeFromTypeNode(c, condNode.CheckType);

        const rootPtr = c.allocator.create(types.ConditionalRoot) catch @panic("OOM");
        rootPtr.* = types.ConditionalRoot{
            .node = node,
            .checkType = checkType,
            .extendsType = getTypeFromTypeNode(c, condNode.ExtendsType),
            .isDistributive = (c.getTypeFlags(checkType) & types.TypeFlags.TypeParameter) != 0,
            // .alias = ...
        };

        entry.value_ptr.resolvedType = getConditionalType(c, rootPtr, 0, false, 0);
    }
    return entry.value_ptr.resolvedType;
}

pub fn getTypeFromInferTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        entry.value_ptr.resolvedType = c.getDeclaredTypeOfTypeParameter(getSymbolOfNode(c, c.binder.ast.getNode(node).InferType.TypeParameter));
    }
    return entry.value_ptr.resolvedType;
}

pub fn getTypeFromImportTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        const isTypeOf = c.binder.ast.getNode(node).ImportType.IsTypeOf;
        if (isTypeOf) {
            entry.value_ptr.resolvedType = resolveImportTypeNode(c, node);
        } else {
            const sym = resolveImportTypeNodeSymbol(c, node);
            entry.value_ptr.resolvedType = getTypeReferenceType(c, node, sym);
        }
    }
    return entry.value_ptr.resolvedType;
}

fn getConditionalType(c: *Checker, root: *types.ConditionalRoot, mapper: usize, forConstraint: bool, alias: usize) TypeIndex {
    _ = c;
    _ = root;
    _ = mapper;
    _ = forConstraint;
    _ = alias;
    return 0;
}

fn resolveImportTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    _ = c;
    _ = node;
    return 0;
}
fn resolveImportTypeNodeSymbol(c: *Checker, node: NodeIndex) ast_gen.SymbolIndex {
    _ = c;
    _ = node;
    return 0;
}

pub fn resolveEntityName(c: *Checker, name: NodeIndex, meaning: u32, ignoreErrors: bool, dontResolveAlias: bool, location: ?NodeIndex) ast_gen.SymbolIndex {
    _ = dontResolveAlias; // TODO: port dontResolveAlias
    if (name == 0) return 0;

    var symbol: ast_gen.SymbolIndex = 0;
    const kind = c.binder.ast.getKind(name);

    if (kind == .Identifier) {
        // var message: ?*diagnostics.Message = null; // TODO: Diagnostics
        const resolveLocation = location orelse name;

        if (meaning == ast_gen.SymbolFlags.Namespace) {
            symbol = getMergedSymbol(c, c.resolveName(resolveLocation, c.binder.ast.getText(name), meaning, null, true, false));
            if (symbol == 0) {
                const alias = getMergedSymbol(c, c.resolveName(resolveLocation, c.binder.ast.getText(name), ast_gen.SymbolFlags.Alias, null, true, false));
                if (alias != 0 and std.mem.eql(u8, c.binder.ast.getSymbolName(alias), "export=")) {
                    symbol = c.binder.ast.getSymbolParent(alias) orelse 0;
                }
            }
        } else {
            symbol = getMergedSymbol(c, c.resolveName(resolveLocation, c.binder.ast.getText(name), meaning, null, true, false));
        }
    } else if (kind == .QualifiedName) {
        const qualified = c.binder.ast.getNode(name).QualifiedName;
        symbol = resolveQualifiedName(c, name, qualified.Left, qualified.Right, meaning, ignoreErrors, location);
    } else if (kind == .PropertyAccessExpression) {
        const access = c.binder.ast.getNode(name).PropertyAccessExpression;
        symbol = resolveQualifiedName(c, name, access.Expression, access.Name, meaning, ignoreErrors, location);
    } else {
        std.debug.panic("Unknown entity name kind", .{});
    }

    if (symbol != 0 and symbol != c.unknownSymbol) {
        // TODO: markSymbolOfAliasDeclarationIfTypeOnly
        // TODO: resolveAlias loop
    }

    return symbol;
}

fn resolveQualifiedName(c: *Checker, name: NodeIndex, left: NodeIndex, right: NodeIndex, meaning: u32, ignoreErrors: bool, location: ?NodeIndex) ast_gen.SymbolIndex {
    _ = c;
    _ = name;
    _ = left;
    _ = right;
    _ = meaning;
    _ = ignoreErrors;
    _ = location;
    return 0; // TODO: Implement resolveQualifiedName
}

test "force typecheck" {
    var c: Checker = undefined;
    _ = getTypeFromTypeReference(&c, 0);
}
