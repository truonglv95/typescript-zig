const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const NodeIndex = ast_gen.NodeIndex;
const types = @import("types.zig");
const TypeIndex = types.TypeIndex;
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const diagnostics_gen = @import("../diagnostics/diagnostics_generated.zig");

export fn dummy_force_typecheck() void {
    var c: Checker = undefined;
    _ = getTypeFromTypeNode(&c, 0);
}

pub fn getTypeFromTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    return getConditionalFlowTypeOfType(c, getTypeFromTypeNodeWorker(c, node), node);
}

pub fn getTypeFromTypeNodeWorker(c: *Checker, node: NodeIndex) TypeIndex {
    const kind = c.binder.ast.getKind(node);
    switch (kind) {
        .AnyKeyword, .JSDocAllType => return c.getAnyType() catch c.unknownTypeIndex orelse 0,
        .JSDocTypeExpression => {
            const typeNode = c.binder.ast.getNode(node).JSDocTypeExpression.Type;
            return getTypeFromTypeNode(c, typeNode);
        },
        .JSDocNonNullableType => {
            const typeNode = c.binder.ast.getNode(node).JSDocNonNullableType.Type;
            return getTypeFromTypeNode(c, typeNode);
        },
        .JSDocNullableType => {
            const typeNode = c.binder.ast.getNode(node).JSDocNullableType.Type;
            const t = getTypeFromTypeNode(c, typeNode);
            if (c.strictNullChecks) {
                return c.getNullableType(t, @import("types.zig").TypeFlags.Null);
            } else {
                return t;
            }
        },
        .JSDocVariadicType => {
            const varType = c.binder.ast.getNode(node).JSDocVariadicType.Type;
            return c.createArrayType(getTypeFromTypeNode(c, varType));
        },
        .JSDocOptionalType => {
            const typeNode = c.binder.ast.getNode(node).JSDocOptionalType.Type;
            return addOptionality(c, getTypeFromTypeNode(c, typeNode));
        },
        .UnknownKeyword => return c.getUnknownType() catch c.unknownTypeIndex orelse 0,
        .StringKeyword => return c.getStringType() catch c.unknownTypeIndex orelse 0,
        .NumberKeyword => return c.getNumberType() catch c.unknownTypeIndex orelse 0,
        .BigIntKeyword => return c.getBigIntType() catch c.unknownTypeIndex orelse 0,
        .BooleanKeyword => return c.getBooleanType() catch c.unknownTypeIndex orelse 0,
        .SymbolKeyword => return c.getEsSymbolType() catch c.unknownTypeIndex orelse 0,
        .VoidKeyword => return c.getVoidType() catch c.unknownTypeIndex orelse 0,
        .UndefinedKeyword => return c.getUndefinedType() catch c.unknownTypeIndex orelse 0,
        .NullKeyword => return c.getNullType() catch c.unknownTypeIndex orelse 0,
        .NeverKeyword => return c.getNeverType() catch c.unknownTypeIndex orelse 0,
        .ObjectKeyword => return c.getNonPrimitiveType() catch c.unknownTypeIndex orelse 0,
        .IntrinsicKeyword => return c.getIntrinsicMarkerType(),
        .ThisType, .ThisKeyword => return getTypeFromThisTypeNode(c, node),
        .LiteralType => return getTypeFromLiteralTypeNode(c, node),
        .TypeReference, .ExpressionWithTypeArguments => return getTypeFromTypeReference(c, node),
        .TypePredicate => {
            if (c.binder.ast.getNode(node).TypePredicate.AssertsModifier != 0) {
                return c.getVoidType() catch c.unknownTypeIndex orelse 0;
            }
            return c.getBooleanType() catch c.unknownTypeIndex orelse 0;
        },
        .TypeQuery => return getTypeFromTypeQueryNode(c, node),
        .ArrayType, .TupleType => return getTypeFromArrayOrTupleTypeNode(c, node),
        .OptionalType => return getTypeFromOptionalTypeNode(c, node),
        .UnionType => return getTypeFromUnionTypeNode(c, node),
        .IntersectionType => return getTypeFromIntersectionTypeNode(c, node),
        .NamedTupleMember => return getTypeFromNamedTupleTypeNode(c, node),
        .ParenthesizedType => {
            const typeNode = c.binder.ast.getNode(node).ParenthesizedType.Type;
            return getTypeFromTypeNode(c, typeNode);
        },
        .RestType => return getTypeFromRestTypeNode(c, node),
        .FunctionType, .ConstructorType, .TypeLiteral => return getTypeFromTypeLiteralOrFunctionOrConstructorTypeNode(c, node),
        .TypeOperator => return getTypeFromTypeOperatorNode(c, node),
        .IndexedAccessType => return getTypeFromIndexedAccessTypeNode(c, node),
        .TemplateLiteralType => return getTypeFromTemplateTypeNode(c, node),
        .MappedType => return getTypeFromMappedTypeNode(c, node),
        .ConditionalType => return getTypeFromConditionalTypeNode(c, node),
        .InferType => return getTypeFromInferTypeNode(c, node),
        .ImportType => return getTypeFromImportTypeNode(c, node),
        else => return c.errorTypeIndex orelse 0,
    }
}

pub fn getConditionalFlowTypeOfType(c: *Checker, t: TypeIndex, node: NodeIndex) TypeIndex {
    // Guard: if t is 0 or out-of-bounds (garbage value), return 0.
    if (t == 0 or t >= c.typesList.items.len) return 0;
    var constraints: std.ArrayListUnmanaged(TypeIndex) = .empty;
    defer constraints.deinit(c.allocator);

    var covariant = true;
    var current = node;

    while (current != 0 and !ast_utils.isStatement(c.binder.ast, current) and c.binder.ast.getKind(current) != .JSDoc) {
        const parent = c.binder.ast.getNodeParent(current);
        if (parent == 0) break;

        if (ast_utils.isParameterDeclaration(c.binder.ast, parent)) {
            covariant = !covariant;
        }

        const tFlags = c.typesList.items[t].flags;
        const parentKind = c.binder.ast.getKind(parent);

        if ((covariant or (tFlags & types.TypeFlags.TypeVariable) != 0) and parentKind == .ConditionalType and current == c.binder.ast.getNode(parent).ConditionalType.TrueType) {
            const condNode = c.binder.ast.getNode(parent).ConditionalType;
            if (getImpliedConstraint(c, t, condNode.CheckType, condNode.ExtendsType)) |constraint| {
                constraints.append(c.allocator, constraint) catch @panic("OOM");
            }
        } else if ((tFlags & types.TypeFlags.TypeParameter) != 0 and parentKind == .MappedType) {
            const mappedNode = c.binder.ast.getNode(parent).MappedType;
            if (mappedNode.NameType == null and current == (mappedNode.Type orelse 0)) {
                const mappedType = getTypeFromTypeNode(c, parent);
                if (c.getTypeParameterFromMappedType(mappedType) == c.getActualTypeVariable(t)) {
                    const typeParameter = c.getHomomorphicTypeVariable(mappedType);
                    if (typeParameter != 0) {
                        if (c.getConstraintOfTypeParameter(typeParameter)) |cType| {
                            var every = true;
                            if ((c.typesList.items[cType].flags & types.TypeFlags.Union) != 0) {
                                for (c.getTypesFromUnion(cType)) |uType| {
                                    if (!c.isArrayOrTupleType(uType)) {
                                        every = false;
                                        break;
                                    }
                                }
                            } else {
                                every = c.isArrayOrTupleType(cType);
                            }

                            if (every) {
                                var numTypes = [_]TypeIndex{ c.numberTypeIndex orelse 0, c.numericStringTypeIndex orelse 0 };
                                const unionType = c.getUnionTypeFromArray(&numTypes);
                                constraints.append(c.allocator, unionType) catch @panic("OOM");
                            }
                        }
                    }
                }
            }
        }
        current = parent;
    }

    if (constraints.items.len != 0) {
        return c.getSubstitutionType(t, c.getIntersectionType(constraints.items));
    }
    return t;
}

fn getImpliedConstraint(c: *Checker, t: TypeIndex, checkNode: NodeIndex, extendsNode: NodeIndex) ?TypeIndex {
    if (isUnaryTupleTypeNode(c, checkNode) and isUnaryTupleTypeNode(c, extendsNode)) {
        const checkElement = c.binder.ast.getNodeList(c.binder.ast.getNode(checkNode).TupleType.Elements)[0];
        const extendsElement = c.binder.ast.getNodeList(c.binder.ast.getNode(extendsNode).TupleType.Elements)[0];
        return getImpliedConstraint(c, t, checkElement, extendsElement);
    }
    if (c.getActualTypeVariable(getTypeFromTypeNode(c, checkNode)) == c.getActualTypeVariable(t)) {
        return getTypeFromTypeNode(c, extendsNode);
    }
    return null;
}

fn isUnaryTupleTypeNode(c: *Checker, node: NodeIndex) bool {
    const kind = c.binder.ast.getKind(node);
    if (kind == .TupleType) {
        return c.binder.ast.getNodeList(c.binder.ast.getNode(node).TupleType.Elements).len == 1;
    }
    return false;
}

fn getThisType(c: *Checker, node: NodeIndex) TypeIndex {
    const container = ast_utils.getThisContainer(c.binder.ast, node, false, false);
    if (container != 0) {
        const parent = c.binder.ast.getNodeParent(container);
        if (parent != 0 and (ast_utils.isClassLike(c.binder.ast, parent) or ast_utils.isInterfaceDeclaration(c.binder.ast, parent))) {
            const isConstructor = ast_utils.isConstructorDeclaration(c.binder.ast, container);
            const containerBody = if (isConstructor) c.binder.ast.getNode(container).Constructor.Body orelse 0 else 0;
            if (!ast_utils.isStatic(c.binder.ast, container) and (!isConstructor or ast_utils.isNodeDescendantOf(c.binder.ast, node, containerBody))) {
                const parentSymbol = c.getSymbolOfDeclaration(parent);
                const declaredType = getDeclaredTypeOfClassOrInterface(c, parentSymbol);
                if (declaredType != 0) {
                    // Use existing thisType if already set on the Object type.
                    if (c.typesList.items[declaredType].data.Object.thisType) |this_tp| {
                        if (this_tp != 0) return this_tp;
                    }
                    // Otherwise create a new polymorphic `this` type:
                    // a TypeParameter with isThisType=true and
                    // constraint = the class/interface type.
                    const this_tp = c.createType(.{
                        .flags = @import("types.zig").TypeFlags.TypeParameter,
                        .objectFlags = @import("types.zig").ObjectFlags.Anonymous,
                        .symbol = parentSymbol,
                        .data = .{ .TypeParameter = .{
                            .constraintType = declaredType,
                            .isThisType = true,
                        } },
                    }) catch 0;
                    if (this_tp != 0) {
                        c.typesList.items[declaredType].data.Object.thisType = this_tp;
                        return this_tp;
                    }
                }
                return c.errorTypeIndex orelse 0;
            }
        }
    }
    c.reportError(node, &diagnostics_gen.A_this_type_is_available_only_in_a_non_static_member_of_a_class_or_interface);
    return c.errorTypeIndex orelse 0;
}

pub fn getTypeFromThisTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        const parent = c.binder.ast.getNodeParent(node);
        if (parent != 0 and c.binder.ast.getKind(parent) == .TypeQuery) {
            entry.value_ptr.resolvedType = c.errorTypeIndex orelse 0;
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
        const checkedType = c.checkExpressionAdHoc(literal) catch c.errorTypeIndex orelse 0;
        entry.value_ptr.resolvedType = c.getRegularTypeOfLiteralType(checkedType);
    }
    return entry.value_ptr.resolvedType;
}
pub fn getTypeFromTypeReference(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }

    // Retry if cached as 0 or errorType — resolution may have failed before
    // the SourceFile fallback was available.
    const should_retry = entry.value_ptr.resolvedType == 0 or
        entry.value_ptr.resolvedType == (c.errorTypeIndex orelse 0);
    if (should_retry) {
        const parent = c.binder.ast.getNodeParent(node);
        if (isConstTypeReference(c, node) and parent != 0 and (c.binder.ast.getKind(parent) == .TypeAssertionExpression or c.binder.ast.getKind(parent) == .AsExpression)) {
            entry.value_ptr.resolvedType = c.unknownTypeIndex orelse 0;
        } else {
            const t = getIntendedTypeFromJSDocTypeReference(c, node);
            if (t != 0) {
                entry.value_ptr.resolvedType = t;
            } else if (tryGetRecordTypeFromNode(c, node)) |recordType| {
                entry.value_ptr.resolvedType = recordType;
            } else {
                const sym = getSymbolFromTypeReference(c, node);
                if (sym != 0 and sym != c.unknownSymbol) {
                    const resolved = getTypeReferenceType(c, node, sym);
                    // Only cache if we found a real type (not errorType).
                    if (resolved != 0 and resolved != (c.errorTypeIndex orelse 0)) {
                        entry.value_ptr.resolvedType = resolved;
                    }
                }
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
    if (c.binder.ast.getKind(typeName) != .Identifier) return false;

    const text = ast_utils.getText(c.binder.ast, typeName);
    return std.mem.eql(u8, text, "const");
}

fn getTypeReferenceName(c: *Checker, node: NodeIndex) ?NodeIndex {
    const nodeObj = c.binder.ast.getNode(node);
    switch (c.binder.ast.getKind(node)) {
        .TypeReference => {
            return nodeObj.TypeReference.TypeName;
        },
        .ExpressionWithTypeArguments => {
            return nodeObj.ExpressionWithTypeArguments.Expression;
        },
        .JSDocTypedefTag => return nodeObj.JSDocTypedefTag.name orelse 0,
        .JSDocCallbackTag => return nodeObj.JSDocCallbackTag.name orelse 0,
        .JSDocSignature => {
            const parent = c.binder.ast.getNodeParent(node);
            if (parent != 0) {
                const parentObj = c.binder.ast.getNode(parent);
                if (c.binder.ast.getKind(parent) == .JSDocCallbackTag) {
                    return parentObj.JSDocCallbackTag.name orelse 0;
                }
            }
        },
        else => {},
    }
    return null;
}

fn getIntendedTypeFromJSDocTypeReference(c: *Checker, node: NodeIndex) TypeIndex {
    const parent = c.binder.ast.getNodeParent(node);
    if (parent != 0 and c.binder.ast.getKind(parent) == .JSDocTypeExpression) {
        const grandParent = c.binder.ast.getNodeParent(parent);
        if (grandParent != 0) {
            switch (c.binder.ast.getKind(grandParent)) {
                .JSDocReturnTag => {
                    // TODO: return c.getTypeFromJSDocReturnTag(grandParent)
                    return c.errorTypeIndex orelse 0;
                },
                .JSDocParameterTag, .JSDocPropertyTag, .JSDocTypeTag, .JSDocTypedefTag, .JSDocCallbackTag => {
                    const sym = c.getSymbolOfDeclaration(grandParent);
                    if (sym != 0) {
                        return c.getTypeOfSymbol(sym) catch c.errorTypeIndex orelse 0;
                    }
                    return c.errorTypeIndex orelse 0;
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
    // Retry if cached as 0 or unknownSymbol — the SourceFile fallback in
    // resolveTypeReferenceName may not have been tried on first attempt.
    if (entry.value_ptr.resolvedSymbol == 0 or entry.value_ptr.resolvedSymbol == c.unknownSymbol) {
        const parent = c.binder.ast.getNodeParent(node);
        if (isConstTypeReference(c, node) and parent != 0 and (c.binder.ast.getKind(parent) == .TypeAssertionExpression or c.binder.ast.getKind(parent) == .AsExpression)) {
            entry.value_ptr.resolvedSymbol = c.unknownSymbol;
        } else {
            const sym = resolveTypeReferenceName(c, node, @import("../ast/symbol.zig").SymbolFlags.Type, false);
            // Only update cache if we found a real symbol.
            if (sym != 0 and sym != c.unknownSymbol) {
                entry.value_ptr.resolvedSymbol = sym;
            }
        }
    }
    return entry.value_ptr.resolvedSymbol;
}

fn resolveLibSymbol(c: *Checker, name: []const u8, meaning: u32) ?ast_gen.SymbolIndex {
    const lib = c.default_lib_binder orelse return null;
    // Search the lib binder's symbols list.
    for (lib.symbols.items, 0..) |sym, i| {
        if (!std.mem.eql(u8, sym.Name, name)) continue;
        if ((sym.Flags & meaning) == 0) continue;
        const idx: ast_gen.SymbolIndex = @intCast(i);
        c.markLibSymbol(idx);
        return idx;
    }
    // Also search the lib binder's SourceFile locals (globals declared
    // at the top level of the lib file, e.g. `var Date: DateConstructor;`).
    if (lib.file != 0) {
        if (lib.nodeLocals.getPtr(lib.file)) |locals| {
            if (locals.get(name)) |sym_idx| {
                if (sym_idx != 0 and sym_idx < lib.symbols.items.len) {
                    const sym = lib.symbols.items[sym_idx];
                    if ((sym.Flags & meaning) != 0) {
                        c.markLibSymbol(sym_idx);
                        return sym_idx;
                    }
                }
            }
        }
    }
    return null;
}

fn resolveTypeReferenceName(c: *Checker, typeReference: NodeIndex, meaning: u32, ignoreErrors: bool) ast_gen.SymbolIndex {
    const nameNode = getTypeReferenceName(c, typeReference);
    if (nameNode == null or nameNode.? == 0) {
        return c.unknownSymbol;
    }
    const nameText = ast_utils.getTextOfNode(c.binder.ast, nameNode.?);
    const resolvedSymbol = checker_mod.resolveName(c, typeReference, nameText, meaning, null, true, false);
    if (resolvedSymbol != 0 and resolvedSymbol != c.unknownSymbol) {
        return resolvedSymbol;
    }
    // Fallback: search SourceFile locals and exports directly.
    const source_file = ast_utils.getSourceFileOfNode(c.binder.ast, typeReference);
    if (source_file != 0) {
        if (c.binder.nodeLocals.getPtr(source_file)) |sf_locals| {
            if (sf_locals.get(nameText)) |sf_sym| {
                if ((c.binder.symbols.items[sf_sym].Flags & meaning) != 0) {
                    return sf_sym;
                }
            }
        }
        if (c.binder.ast.getNodeSymbol(source_file)) |sf_sym| {
            if (c.binder.symbolExports.getPtr(sf_sym)) |sf_exports| {
                if (sf_exports.get(nameText)) |exp_sym| {
                    if ((c.binder.symbols.items[exp_sym].Flags & meaning) != 0) {
                        return exp_sym;
                    }
                }
            }
        }
        // Also try ALL binder symbols by name (brute force for missed cases).
        for (c.binder.symbols.items, 0..) |sym, i| {
            if (std.mem.eql(u8, sym.Name, nameText) and (sym.Flags & meaning) != 0) {
                return @intCast(i);
            }
        }
    }
    if (resolveLibSymbol(c, nameText, meaning)) |libSym| {
        return libSym;
    }
    if (ignoreErrors) {
        return c.unknownSymbol;
    }
    return getUnresolvedSymbolForEntityName(c, nameNode.?);
}

fn getSymbolPath(c: *Checker, symbol: ast_gen.SymbolIndex) []const u8 {
    const parent = c.binder.symbols.items[symbol].Parent;
    const name = c.binder.symbols.items[symbol].Name;
    if (parent != null and parent.? != 0) {
        const parentPath = getSymbolPath(c, parent.?);
        return std.fmt.allocPrint(c.allocator, "{s}.{s}", .{ parentPath, name }) catch unreachable;
    }
    return c.allocator.dupe(u8, name) catch unreachable;
}

fn getUnresolvedSymbolForEntityName(c: *Checker, name: NodeIndex) ast_gen.SymbolIndex {
    var identifier: NodeIndex = name;
    switch (c.binder.ast.getKind(name)) {
        .QualifiedName => {
            identifier = c.binder.ast.getNode(name).QualifiedName.Right;
        },
        .PropertyAccessExpression => {
            identifier = c.binder.ast.getNode(name).PropertyAccessExpression.name;
        },
        else => {},
    }
    const text = if (identifier != 0) ast_utils.getTextOfNode(c.binder.ast, identifier) else "";
    if (text.len > 0) {
        var parentSymbol: ast_gen.SymbolIndex = 0;
        switch (c.binder.ast.getKind(name)) {
            .QualifiedName => {
                parentSymbol = getUnresolvedSymbolForEntityName(c, c.binder.ast.getNode(name).QualifiedName.Left);
            },
            .PropertyAccessExpression => {
                parentSymbol = getUnresolvedSymbolForEntityName(c, c.binder.ast.getNode(name).PropertyAccessExpression.Expression);
            },
            else => {},
        }
        var path: []const u8 = undefined;
        if (parentSymbol != 0) {
            const pPath = getSymbolPath(c, parentSymbol);
            path = std.fmt.allocPrint(c.allocator, "{s}.{s}", .{ pPath, text }) catch unreachable;
        } else {
            path = text;
        }

        if (c.unresolvedSymbols.get(path)) |result| {
            return result;
        }

        const result = c.createSymbol(@import("../ast/symbol.zig").SymbolFlags.TypeAlias, text, @import("types.zig").CheckFlags.Unresolved);
        const dupedPath = c.allocator.dupe(u8, path) catch unreachable;
        c.unresolvedSymbols.put(c.allocator, dupedPath, result) catch unreachable;
        c.binder.symbols.items[result].Parent = parentSymbol;

        const entry = c.typeAliasLinks.getOrPut(c.allocator, result) catch unreachable;
        if (!entry.found_existing) entry.value_ptr.* = .{};
        entry.value_ptr.declaredType = c.errorTypeIndex orelse 0;

        return result;
    }
    return c.unknownSymbol;
}

fn getTypeReferenceType(c: *Checker, node: NodeIndex, symbol: ast_gen.SymbolIndex) TypeIndex {
    if (symbol == c.unknownSymbol) {
        return c.errorTypeIndex orelse 0;
    }

    const flags = c.getSymbolFlags(symbol);

    // TypeParameter: return the declared type of the type parameter.
    if ((flags & @import("../ast/symbol.zig").SymbolFlags.TypeParameter) != 0) {
        const res = tryGetDeclaredTypeOfSymbol(c, symbol);
        if (res != 0) return res;
        // Fallback: create a TypeParameter type with the symbol.
        return c.createType(.{
            .flags = @import("types.zig").TypeFlags.TypeParameter,
            .objectFlags = @import("types.zig").ObjectFlags.Anonymous,
            .id = 0,
            .symbol = symbol,
            .alias = null,
            .data = .{ .TypeParameter = .{} },
        }) catch c.errorTypeIndex orelse 0;
    }

    if ((flags & (@import("../ast/symbol.zig").SymbolFlags.Class | @import("../ast/symbol.zig").SymbolFlags.Interface)) != 0) {
        return getTypeFromClassOrInterfaceReference(c, node, symbol);
    }
    if ((flags & @import("../ast/symbol.zig").SymbolFlags.TypeAlias) != 0) {
        return getTypeFromTypeAliasReference(c, node, symbol);
    }

    const res = tryGetDeclaredTypeOfSymbol(c, symbol);
    if (res != 0 and checkNoTypeArguments(c, node, symbol)) {
        return c.getRegularTypeOfLiteralType(res);
    }

    return c.errorTypeIndex orelse 0;
}

pub fn getTypeFromClassOrInterfaceReference(c: *Checker, node: NodeIndex, symbol: ast_gen.SymbolIndex) TypeIndex {
    const t = getDeclaredTypeOfClassOrInterface(c, checker_mod.getMergedSymbol(c, symbol));
    if (t == 0) return c.errorTypeIndex orelse 0; // safeguard

    // d := t.AsInterfaceType()
    // typeParameters := d.LocalTypeParameters()
    const typeParameters = getLocalTypeParameters(c, t);

    if (typeParameters.len != 0) {
        const typeArgsLen = getTypeArgumentsLength(c, node);
        const minTypeArgumentCount = getMinTypeArgumentCount(c, typeParameters);
        const isJs = ast_utils.isInJSFile(c.binder.ast, node);
        const isJsImplicitAny = isJs and !c.noImplicitAny;

        if (!isJsImplicitAny and (typeArgsLen < minTypeArgumentCount or typeArgsLen > typeParameters.len)) {
            // Diagnostics omitted for stub
            if (!isJs) {
                return c.errorTypeIndex orelse 0;
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

        return createTypeReferenceEx(c, t, typeArguments, 0);
    }

    if (checkNoTypeArguments(c, node, symbol)) {
        return t;
    }
    return c.errorTypeIndex orelse 0;
}

fn getDeclaredTypeOfClassOrInterface(c: *Checker, symbol: ast_gen.SymbolIndex) TypeIndex {
    const flags = c.getSymbolFlags(symbol);
    const sym = @import("../ast/symbol.zig");
    const kind = if ((flags & sym.SymbolFlags.Class) != 0) types.ObjectFlags.Class else types.ObjectFlags.Interface;
    return newObjectType(c, kind, symbol);
}
fn getLocalTypeParameters(c: *Checker, t: TypeIndex) []const TypeIndex {
    // Port of Go's appendLocalTypeParametersOfClassOrInterfaceOrTypeAlias.
    // For class/interface/type-alias symbols, walks the declarations and
    // collects the declared type of each TypeParameter node.
    if (t == 0 or t >= c.typesList.items.len) return &[_]TypeIndex{};
    const typeData = c.typesList.items[t];
    const sym = typeData.symbol orelse return &[_]TypeIndex{};
    if (sym == 0 or sym >= c.binder.symbols.items.len) return &[_]TypeIndex{};

    const sym_obj = c.binder.symbols.items[sym];
    var collected = std.ArrayListUnmanaged(TypeIndex).empty;
    defer collected.deinit(c.allocator);
    for (sym_obj.Declarations.items) |decl_node| {
        if (decl_node == 0) continue;
        const kind = c.binder.ast.getKind(decl_node);
        var tp_list_id: u32 = 0;
        const decl_data = c.binder.ast.getNode(decl_node);
        switch (kind) {
            .InterfaceDeclaration => tp_list_id = decl_data.InterfaceDeclaration.TypeParameters orelse 0,
            .ClassDeclaration => tp_list_id = decl_data.ClassDeclaration.TypeParameters orelse 0,
            .ClassExpression => tp_list_id = decl_data.ClassExpression.TypeParameters orelse 0,
            .TypeAliasDeclaration => tp_list_id = decl_data.TypeAliasDeclaration.TypeParameters orelse 0,
            else => {},
        }
        if (tp_list_id == 0) continue;
        const tp_nodes = c.binder.ast.getNodeList(tp_list_id);
        for (tp_nodes) |tp_node| {
            if (tp_node == 0) continue;
            const tp_sym = c.binder.ast.getNodeSymbol(tp_node) orelse 0;
            if (tp_sym == 0) continue;
            const tp_type = c.getDeclaredTypeOfTypeParameter(tp_sym);
            if (tp_type != 0) {
                // Append unique.
                var found = false;
                for (collected.items) |existing| {
                    if (existing == tp_type) {
                        found = true;
                        break;
                    }
                }
                if (!found) collected.append(c.allocator, tp_type) catch {};
            }
        }
    }
    // Transfer ownership to the checker's arena so the slice outlives this
    // function call. Use a long-lived allocator (the checker allocator).
    const slice = c.allocator.dupe(TypeIndex, collected.items) catch return &[_]TypeIndex{};
    // Track for cleanup via ownedTypes? For now, leak — checker outlives
    // callers and this is called at most once per cached type reference.
    return slice;
}
fn getTypeArgumentsLength(c: *Checker, node: NodeIndex) usize {
    if (getTypeArgumentsNode(c, node)) |argsNode| {
        return c.binder.ast.getNodeList(argsNode).len;
    }
    return 0;
}

fn hasDefaultTypeParameter(c: *Checker, t: TypeIndex) bool {
    const symbol = c.getSymbolOfType(t);
    if (symbol != 0) {
        const symbolObj = c.binder.symbols.items[symbol];
        for (symbolObj.Declarations.items) |decl| {
            if (c.binder.ast.getKind(decl) == .TypeParameter) {
                const node = c.binder.ast.getNode(decl).TypeParameter;
                if (node.DefaultType != null and node.DefaultType.? != 0) {
                    return true;
                }
            }
        }
    }
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
    return switch (c.binder.ast.getKind(node)) {
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
            typeArgs[i] = getTypeFromTypeNode(c, argNode);
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

fn getDefaultFromTypeParameter(c: *Checker, t: TypeIndex) ?TypeIndex {
    if ((c.typesList.items[t].flags & types.TypeFlags.TypeParameter) == 0) {
        return null;
    }
    const defaultType = getResolvedTypeParameterDefault(c, t);
    if (defaultType != (c.noConstraintTypeIndex orelse 0) and defaultType != (c.circularConstraintTypeIndex orelse 0)) {
        return defaultType;
    }
    return null;
}

fn getResolvedTypeParameterDefault(c: *Checker, t: TypeIndex) TypeIndex {
    const tp = &c.typesList.items[t].data.TypeParameter;
    if (tp.resolvedDefaultType == null) {
        if (tp.target != null and tp.target.? != 0) {
            const targetDefault = getResolvedTypeParameterDefault(c, tp.target.?);
            if (targetDefault != (c.noConstraintTypeIndex orelse 0)) {
                tp.resolvedDefaultType = c.instantiateType(targetDefault, tp.mapper);
            } else {
                tp.resolvedDefaultType = c.noConstraintTypeIndex orelse 0;
            }
        } else {
            tp.resolvedDefaultType = c.resolvingDefaultTypeIndex orelse 0;
            var defaultType = c.noConstraintTypeIndex orelse 0;
            const symbol = c.typesList.items[t].symbol;
            if (symbol != null and symbol.? != 0) {
                const symObj = c.binder.symbols.items[symbol.?];
                for (symObj.Declarations.items) |decl| {
                    if (c.binder.ast.getKind(decl) == .TypeParameter) {
                        const node = c.binder.ast.getNode(decl).TypeParameter;
                        if (node.DefaultType != null and node.DefaultType.? != 0) {
                            defaultType = getTypeFromTypeNode(c, node.DefaultType.?);
                            break;
                        }
                    }
                }
            }
            if (tp.resolvedDefaultType == (c.resolvingDefaultTypeIndex orelse 0)) {
                tp.resolvedDefaultType = defaultType;
            }
        }
    } else if (tp.resolvedDefaultType == (c.resolvingDefaultTypeIndex orelse 0)) {
        tp.resolvedDefaultType = c.circularConstraintTypeIndex orelse 0;
    }
    return tp.resolvedDefaultType.?;
}

fn fillMissingTypeArguments(c: *Checker, typeArguments: []const TypeIndex, typeParameters: []const TypeIndex, minTypeArgumentCount: usize, isJs: bool) []const TypeIndex {
    const numTypeArguments = typeArguments.len;
    if (numTypeArguments == typeParameters.len) {
        return typeArguments;
    }

    var result = c.allocator.alloc(TypeIndex, typeParameters.len) catch @panic("OOM");
    @memcpy(result[0..numTypeArguments], typeArguments);

    if (isJs) {
        for (numTypeArguments..typeParameters.len) |i| {
            result[i] = c.anyTypeIndex orelse 0;
        }
        return result;
    }

    var mapper: types.TypeMapperIndex = 0;
    for (numTypeArguments..typeParameters.len) |i| {
        if (i < minTypeArgumentCount) {
            result[i] = c.errorTypeIndex orelse 0;
        } else {
            const defaultType = getDefaultFromTypeParameter(c, typeParameters[i]);
            if (defaultType != null) {
                if (mapper == 0) {
                    mapper = @import("checker.zig").makeArrayTypeMapper(c, typeParameters, result) catch 0;
                }
                result[i] = c.instantiateType(defaultType.?, mapper);
            } else {
                result[i] = getDefaultTypeArgumentType(c, isJs);
            }
        }
    }
    return result;
}
fn getDefaultTypeArgumentType(c: *Checker, isInJavaScriptFile: bool) TypeIndex {
    if (isInJavaScriptFile) {
        return c.anyTypeIndex orelse 0;
    }
    return c.unknownTypeIndex orelse 0;
}

fn getOuterTypeParameters(c: *Checker, t: TypeIndex) []const TypeIndex {
    // Outer type parameters come from the enclosing generic class when a
    // nested type declaration references the outer's type parameters. For
    // now we return an empty slice — top-level interfaces/classes have no
    // outer type parameters.
    _ = c;
    _ = t;
    return &[_]TypeIndex{};
}
fn appendTypeArrays(c: *Checker, arr1: []const TypeIndex, arr2: []const TypeIndex) []const TypeIndex {
    if (arr1.len == 0) return arr2;
    if (arr2.len == 0) return arr1;
    const total = arr1.len + arr2.len;
    const result = c.allocator.alloc(TypeIndex, total) catch return &[_]TypeIndex{};
    @memcpy(result[0..arr1.len], arr1);
    @memcpy(result[arr1.len..], arr2);
    return result;
}
fn createTypeReferenceEx(c: *Checker, t: TypeIndex, typeArguments: []const TypeIndex, objectFlags: u32) TypeIndex {
    // Delegate to the checker's createTypeReferenceEx.
    return c.createTypeReferenceEx(t, typeArguments, objectFlags) catch 0;
}

fn tryGetRecordTypeFromNode(c: *Checker, node: NodeIndex) ?TypeIndex {
    const nameNode = getTypeReferenceName(c, node);
    if (nameNode == null or nameNode.? == 0) return null;
    const nameText = ast_utils.getTextOfNode(c.binder.ast, nameNode.?);
    if (!std.mem.eql(u8, nameText, "Record")) return null;
    const typeArgs = getTypeArgumentsFromNode(c, node);
    if (typeArgs.len != 2) return null;
    const stringType = c.getStringType() catch return null;
    if (!c.isTypeIdenticalTo(typeArgs[0], stringType)) return null;
    return c.createObjectTypeWithStringIndexSignature(typeArgs[1]);
}

fn tryGetRecordInstantiation(c: *Checker, node: NodeIndex, symbol: ast_gen.SymbolIndex) ?TypeIndex {
    if (!std.mem.eql(u8, c.getSymbolName(symbol), "Record")) return null;
    return tryGetRecordTypeFromNode(c, node);
}

pub fn getTypeFromTypeAliasReference(c: *Checker, node: NodeIndex, symbol: ast_gen.SymbolIndex) TypeIndex {
    if (tryGetRecordInstantiation(c, node, symbol)) |recordType| {
        return recordType;
    }
    _ = c.getDeclaredTypeOfSymbol(symbol);
    const links = c.typeAliasLinks.getPtr(symbol);
    if (links) |l| {
        if (l.typeParameters.len != 0) {
            return c.getTypeAliasInstantiation(symbol, getTypeArgumentsFromNode(c, node), null);
        }
    }
    const t = c.getDeclaredTypeOfSymbol(symbol);
    if (checkNoTypeArguments(c, node, symbol)) {
        return t;
    }
    return c.errorTypeIndex orelse 0;
}
pub fn tryGetDeclaredTypeOfSymbol(c: *Checker, symbol: ast_gen.SymbolIndex) TypeIndex {
    return c.tryGetDeclaredTypeOfSymbol(symbol);
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
    const kind = c.binder.ast.getKind(node);
    if (kind == .ArrayType) {
        const arr = c.binder.ast.getNode(node).ArrayType;
        const elem_type = getTypeFromTypeNode(c, arr.ElementType);
        if (elem_type == 0) return 0;
        return c.createArrayType(elem_type);
    }
    if (kind == .TupleType) {
        // Build a proper tuple type from the element nodes.
        // Use the checker's getTypeOfNode which has the full TupleType case
        // (handles NamedTupleMember, OptionalType, RestType, and stores
        // labeledDeclaration for element labels).
        const tp = c.getTypeOfNode(node) catch 0;
        if (tp != 0) return tp;
        // Fallback: any[] (matches old behavior)
        return c.createArrayType(c.anyTypeIndex orelse 0);
    }
    return 0;
}
fn coreSomeVariadic(c: *Checker, node: NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}
fn getTupleElementsLen(c: *Checker, node: NodeIndex) usize {
    if (c.binder.ast.getKind(node) != .TupleType) return 0;
    const tuple = c.binder.ast.getNode(node).TupleType;
    if (tuple.Elements == 0) return 0;
    return c.binder.ast.getNodeList(tuple.Elements).len;
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
        const typesNode = c.binder.ast.getNode(node).UnionType.Types;
        const nodes = c.binder.ast.getNodeList(typesNode);

        var mappedTypes = c.allocator.alloc(TypeIndex, nodes.len) catch @panic("OOM");
        defer c.allocator.free(mappedTypes);
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
        const typesNode = c.binder.ast.getNode(node).IntersectionType.Types;
        const nodes = c.binder.ast.getNodeList(typesNode);

        var mappedTypes = c.allocator.alloc(TypeIndex, nodes.len) catch @panic("OOM");
        defer c.allocator.free(mappedTypes);
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
        if (c.binder.ast.getKind(node) == .FunctionType) {
            std.debug.print("\n[DEBUG] getTypeFromTypeLiteralOrFunctionOrConstructorTypeNode: FunctionType sym={d}\n", .{sym});
            if (sym != 0) {
                const has_members = symbolHasMembers(c, sym);
                std.debug.print("[DEBUG] symbolHasMembers={}\n", .{has_members});
            }
        }
        if (sym == 0 or (!symbolHasMembers(c, sym) and alias == 0)) {

            entry.value_ptr.resolvedType = c.emptyTypeLiteralTypeIndex orelse c.errorTypeIndex orelse 0;
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
        const typeOp = c.binder.ast.getNode(node).TypeOperator;
        const argTypeNode = typeOp.Type;
        const kind = typeOp.Operator;
        if (kind == @intFromEnum(@import("../ast/kind.zig").Kind.KeyOfKeyword)) {
            entry.value_ptr.resolvedType = c.getIndexType(getTypeFromTypeNode(c, argTypeNode));
        } else if (kind == @intFromEnum(@import("../ast/kind.zig").Kind.UniqueKeyword)) {
            if (c.binder.ast.getKind(argTypeNode) == .SymbolKeyword) {
                // entry.value_ptr.resolvedType = c.getESSymbolLikeTypeForNode(walkUpParenthesizedTypes(c, c.binder.ast.getNode(node).Parent));
                entry.value_ptr.resolvedType = c.errorTypeIndex orelse 0; // stub
            } else {
                entry.value_ptr.resolvedType = c.errorTypeIndex orelse 0;
            }
        } else if (kind == @intFromEnum(@import("../ast/kind.zig").Kind.ReadonlyKeyword)) {
            entry.value_ptr.resolvedType = getTypeFromTypeNode(c, argTypeNode);
        } else {
            entry.value_ptr.resolvedType = c.errorTypeIndex orelse 0;
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
        const indexedNode = c.binder.ast.getNode(node).IndexedAccessType;
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
    return checker_mod.getSymbolOfNode(c, node) orelse 0;
}
fn symbolHasMembers(c: *Checker, symbol: ast_gen.SymbolIndex) bool {
    if (symbol == 0) return false;
    if (c.binder.symbolMembers.get(symbol)) |members| {
        return members.count() > 0;
    }
    if (symbol < c.binder.symbols.items.len) {
        return c.binder.symbols.items[symbol].Members.count() > 0;
    }
    return false;
}
fn newObjectType(c: *Checker, objectFlags: u32, symbol: ast_gen.SymbolIndex) TypeIndex {
    return c.createType(.{
        .flags = types.TypeFlags.Object,
        .objectFlags = objectFlags,
        .id = 0,
        .symbol = symbol,
        .alias = null,
        .data = .{ .Object = .{
            .Symbol = symbol,
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
    return c.stringTypeIndex orelse 0;
}

pub fn getTypeFromTemplateTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    var entry = c.typeNodeLinks.getOrPut(c.allocator, node) catch @panic("OOM");
    if (!entry.found_existing) {
        entry.value_ptr.* = .{};
    }
    if (entry.value_ptr.resolvedType == 0) {
        const spansNode = c.binder.ast.getNode(node).TemplateLiteralType.TemplateSpans;
        const spans = c.binder.ast.getNodeList(spansNode);

        var texts = c.allocator.alloc([]const u8, spans.len + 1) catch @panic("OOM");
        defer c.allocator.free(texts);
        var mappedTypes = c.allocator.alloc(TypeIndex, spans.len) catch @panic("OOM");
        defer c.allocator.free(mappedTypes);

        texts[0] = ast_utils.getText(c.binder.ast, c.binder.ast.getNode(node).TemplateLiteralType.Head);

        for (spans, 0..) |span, i| {
            texts[i + 1] = ast_utils.getText(c.binder.ast, c.binder.ast.getNode(span).TemplateLiteralTypeSpan.Literal);
            mappedTypes[i] = getTypeFromTypeNode(c, c.binder.ast.getNode(span).TemplateLiteralTypeSpan.Type);
        }

        entry.value_ptr.resolvedType = c.getTemplateLiteralType(texts, mappedTypes);
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
        c.typesList.items[t].data = .{ .Mapped = .{
            .declaration = node,
            .typeParameter = 0,
            .templateType = 0,
        }};
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
        if (isTypeOf != 0) {
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
    if (name == 0) return 0;

    var symbol: ast_gen.SymbolIndex = 0;
    const kind = c.binder.ast.getKind(name);

    if (kind == .Identifier) {
        // var message: ?*diagnostics.Message = null; // TODO: Diagnostics
        const resolveLocation = location orelse name;

        if (meaning == @import("../ast/symbol.zig").SymbolFlags.Namespace) {
            symbol = checker_mod.getMergedSymbol(c, c.resolveName(resolveLocation, c.binder.ast.getText(name), meaning, null, true, false));
            if (symbol == 0) {
                const alias = checker_mod.getMergedSymbol(c, c.resolveName(resolveLocation, ast_utils.getText(c.binder.ast, name), @import("../ast/symbol.zig").SymbolFlags.Alias, null, true, false));
                if (alias != 0 and std.mem.eql(u8, c.binder.ast.getSymbolName(alias), "export=")) {
                    symbol = c.binder.ast.getSymbolParent(alias) orelse 0;
                }
            }
        } else {
            symbol = checker_mod.getMergedSymbol(c, c.resolveName(resolveLocation, c.binder.ast.getText(name), meaning, null, true, false));
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
        markSymbolOfAliasDeclarationIfTypeOnly(c, getAliasDeclarationFromName(c, name), 0);
        while ((c.binder.symbols.items[symbol].flags & meaning) == 0 and !dontResolveAlias and (c.binder.symbols.items[symbol].flags & @import("../ast/symbol.zig").SymbolFlags.Alias) != 0) {
            symbol = c.resolveAlias(symbol);
        }
    }

    return symbol;
}

fn getAliasDeclarationFromName(c: *Checker, name: NodeIndex) NodeIndex {
    var currentNode = name;
    while (true) {
        const parent = c.binder.ast.getNodeParent(currentNode);
        if (parent == 0) return 0;
        switch (c.binder.ast.getKind(parent)) {
            .ImportClause, .ImportSpecifier, .NamespaceImport, .ExportSpecifier, .ExportAssignment, .ImportEqualsDeclaration, .NamespaceExport => {
                return parent;
            },
            .QualifiedName => {
                currentNode = parent;
            },
            else => return 0,
        }
    }
}

fn markSymbolOfAliasDeclarationIfTypeOnly(c: *Checker, aliasDeclaration: NodeIndex, exportStarDeclaration: NodeIndex) bool {
    if (aliasDeclaration == 0 or !ast_utils.isDeclarationNode(c.binder.ast, aliasDeclaration)) {
        return false;
    }
    const sourceSymbol = c.getSymbolOfDeclaration(aliasDeclaration);
    if (sourceSymbol == 0) return false;

    const links = c.aliasSymbolLinks.getOrPutValue(c.allocator, sourceSymbol, .{}) catch @panic("OOM");
    if (links.value_ptr.typeOnlyDeclaration == null and ast_utils.isTypeOnlyImportOrExportDeclaration(c.binder.ast, aliasDeclaration)) {
        links.value_ptr.typeOnlyDeclaration = aliasDeclaration;
        return true;
    }
    if (links.value_ptr.typeOnlyDeclaration == null and exportStarDeclaration != 0) {
        links.value_ptr.typeOnlyDeclaration = exportStarDeclaration;
        return true;
    }
    return links.value_ptr.typeOnlyDeclaration != null;
}

fn resolveQualifiedName(c: *Checker, name: NodeIndex, left: NodeIndex, right: NodeIndex, meaning: u32, ignoreErrors: bool, location: ?NodeIndex) ast_gen.SymbolIndex {
    _ = name;
    const namespace = c.resolveEntityName(left, @import("../ast/symbol.zig").SymbolFlags.Namespace, ignoreErrors, false, location);
    if (namespace == 0 or ast_utils.nodeIsMissing(c.binder.ast, right)) {
        return 0;
    }
    if (namespace == c.unknownSymbol) {
        return namespace;
    }

    const valueDeclaration = c.getSymbolValueDeclaration(namespace);
    if (valueDeclaration != 0 and ast_utils.isInJSFile(c.binder.ast, valueDeclaration) and
        c.binder.ast.getKind(valueDeclaration) == .VariableDeclaration)
    {
        const initializer = c.binder.ast.getNodeInitializer(valueDeclaration);
        if (initializer != 0 and ast_utils.isRequireCall(c.binder.ast, initializer, true)) {
            // Check if require is not local
            const requireName = c.binder.ast.getText(c.binder.ast.getNodeExpression(initializer));
            const resolvedRequire = c.resolveName(c.binder.ast.getNodeExpression(initializer), requireName, @import("../ast/symbol.zig").SymbolFlags.Value, null, true, false);
            // c.requireSymbol is unknownSymbol in typescript-go stub (usually), or we check if it is ambient.
            // Simplified here to just check if ambient.
            var targetDeclarationKind: ast_gen.NodeKind = .Unknown;
            if (resolvedRequire != 0 and (c.binder.symbols.items[resolvedRequire].flags & @import("../ast/symbol.zig").SymbolFlags.Alias) == 0) {
                if ((c.binder.symbols.items[resolvedRequire].flags & @import("../ast/symbol.zig").SymbolFlags.Function) != 0) {
                    targetDeclarationKind = .FunctionDeclaration;
                } else if ((c.binder.symbols.items[resolvedRequire].flags & @import("../ast/symbol.zig").SymbolFlags.Variable) != 0) {
                    targetDeclarationKind = .VariableDeclaration;
                }
            }
            var isAmbient = false;
            if (targetDeclarationKind != .Unknown) {
                const decl = c.getDeclarationOfKind(resolvedRequire, targetDeclarationKind);
                if (decl != 0 and (c.binder.ast.getNodeFlags(decl) & ast_utils.NodeFlags.Ambient) != 0) {
                    isAmbient = true;
                }
            }
            if (resolvedRequire == c.requireSymbol or isAmbient) {
                // It is a valid require.
                const argsStart = c.binder.ast.getNodeArgumentsStart(initializer);
                if (argsStart > 0) {
                    const moduleName = c.binder.ast.nodes.items[argsStart];
                    const moduleSym = @import("exports.zig").resolveExternalModuleName(c, moduleName);
                    if (moduleSym != 0) {
                        const resolvedModuleSymbol = @import("exports.zig").resolveExternalModuleSymbol(c, moduleSym);
                        if (resolvedModuleSymbol != 0) {
                            namespace = resolvedModuleSymbol;
                        }
                    }
                }
            }
        }
    }

    const text = c.binder.ast.getText(right);
    var symbol = checker_mod.getMergedSymbol(c, c.getSymbol(c.getExportsOfSymbol(namespace), text, meaning));
    if (symbol == 0 and (c.binder.symbols.items[namespace].flags & @import("../ast/symbol.zig").SymbolFlags.Alias) != 0) {
        symbol = checker_mod.getMergedSymbol(c, c.getSymbol(c.getExportsOfSymbol(c.resolveAlias(namespace)), text, meaning));
    }

    if (symbol == 0) {
        if (!ignoreErrors) {
            // TODO: Error reporting
        }
    }
    return symbol;
}
