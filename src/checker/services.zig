const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const NodeIndex = ast_gen.NodeIndex;
const types = @import("types.zig");
const TypeIndex = types.TypeIndex;
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const SymbolIndex = checker_mod.SymbolIndex;
const SignatureIndex = checker_mod.types.SignatureIndex;

pub fn getSymbolsInScope(c: *Checker, location: NodeIndex, meaning: u32) []const SymbolIndex {
    var symbols = std.AutoHashMap(SymbolIndex, void).init(c.allocator);
    var current: NodeIndex = location;

    while (current != 0) {
        if (c.binder.nodeLocals.getPtr(current)) |locals| {
            var it = locals.iterator();
            while (it.next()) |entry| {
                const sym = entry.value_ptr.*;
                if ((c.binder.symbols.items[sym].Flags & meaning) != 0) {
                    symbols.put(sym, {}) catch unreachable;
                }
            }
        }
        current = c.binder.ast.getNodeParent(current);
    }

    // Add globals
    // var itGlobals = c.globals.iterator();
    // while (itGlobals.next()) |entry| {
    //     const sym = entry.value_ptr.*;
    //     if ((c.binder.symbols.items[sym].Flags & meaning) != 0) {
    //         symbols.put(sym, {}) catch unreachable;
    //     }
    // }

    var result = std.ArrayListUnmanaged(SymbolIndex).empty;
    var it = symbols.keyIterator();
    while (it.next()) |sym| {
        result.append(c.allocator, sym.*) catch unreachable;
    }
    return result.toOwnedSlice(c.allocator) catch unreachable;
}

pub fn getExportsOfModule(c: *Checker, symbol: SymbolIndex) []const SymbolIndex {
    return c.getExportsOfModuleAsArray(symbol);
}

pub fn isValidPropertyAccess(c: *Checker, node: NodeIndex, propertyName: []const u8) bool {
    const kind = c.ast.getKind(node);
    if (kind == .PropertyAccessExpression) {
        const expr = c.ast.propertyAccessExpression_expression(node);
        const isSuper = c.ast.getKind(expr) == .SuperKeyword;
        return c.isValidPropertyAccessWithType(node, isSuper, propertyName, c.getWidenedType(c.checkExpression(expr)));
    } else if (kind == .QualifiedName) {
        const left = c.ast.qualifiedName_left(node);
        return c.isValidPropertyAccessWithType(node, false, propertyName, c.getWidenedType(c.checkExpression(left)));
    } else if (kind == .ImportType) {
        return c.isValidPropertyAccessWithType(node, false, propertyName, c.getTypeFromTypeNode(node));
    }
    unreachable;
}

pub fn isValidPropertyAccessForCompletions(c: *Checker, node: NodeIndex, t: TypeIndex, property: SymbolIndex) bool {
    const isSuper = c.ast.getKind(node) == .PropertyAccessExpression and c.ast.getKind(c.ast.propertyAccessExpression_expression(node)) == .SuperKeyword;
    return c.isPropertyAccessible(node, isSuper, false, t, property);
}

pub fn getAllPossiblePropertiesOfTypes(c: *Checker, types_arr: []const TypeIndex) []const SymbolIndex {
    const unionType = c.getUnionType(types_arr);
    if ((c.getTypeFlags(unionType) & types.TypeFlags.Union) == 0) {
        return c.getAugmentedPropertiesOfType(unionType);
    }

    var props = std.AutoHashMap(SymbolIndex, void).init(c.arena.allocator());
    for (types_arr) |memberType| {
        const augmentedProps = c.getAugmentedPropertiesOfType(memberType);
        for (augmentedProps) |p| {
            if (!props.contains(p)) {
                const prop = c.createUnionOrIntersectionProperty(unionType, c.ast.symbol_name(p), false);
                if (prop != 0) {
                    props.put(prop, {}) catch unreachable;
                }
            }
        }
    }

    var result = std.ArrayList(SymbolIndex).init(c.arena.allocator());
    var it = props.keyIterator();
    while (it.next()) |p| {
        result.append(p.*) catch unreachable;
    }
    return result.items;
}

pub fn isUnknownSymbol(c: *Checker, symbol: SymbolIndex) bool {
    return symbol == c.unknownSymbol;
}

pub fn isUndefinedSymbol(c: *Checker, symbol: SymbolIndex) bool {
    return symbol == c.undefinedSymbol;
}

pub fn isArgumentsSymbol(c: *Checker, symbol: SymbolIndex) bool {
    return symbol == c.argumentsSymbol;
}

pub fn getNonOptionalType(c: *Checker, t: TypeIndex) TypeIndex {
    return c.removeOptionalTypeMarker(t);
}

pub fn getStringIndexType(c: *Checker, t: TypeIndex) TypeIndex {
    return c.getIndexTypeOfType(t, c.stringType);
}

pub fn getNumberIndexType(c: *Checker, t: TypeIndex) TypeIndex {
    return c.getIndexTypeOfType(t, c.numberType);
}

pub fn getElementTypeOfArrayType(c: *Checker, t: TypeIndex) TypeIndex {
    return c.getElementTypeOfArrayType(t);
}

pub fn getCallSignatures(c: *Checker, t: TypeIndex) []const SignatureIndex {
    return c.getSignaturesOfType(t, 0); // SignatureKind.Call
}

pub fn getConstructSignatures(c: *Checker, t: TypeIndex) []const SignatureIndex {
    return c.getSignaturesOfType(t, 1); // SignatureKind.Construct
}

pub fn getAliasTypeArguments(c: *Checker, node: NodeIndex) []const TypeIndex {
    return c.getAliasTypeArguments(node);
}

pub fn getTypeArguments(c: *Checker, t: TypeIndex) []const TypeIndex {
    return c.getTypeArguments(t);
}

pub fn getAliasedSymbol(c: *Checker, symbol: SymbolIndex) SymbolIndex {
    return c.getAliasedSymbol(symbol);
}

pub fn resolveName(c: *Checker, name: []const u8, location: NodeIndex, meaning: u32, excludeGlobals: bool) SymbolIndex {
    return c.resolveName(location, name, meaning, 0, true, excludeGlobals);
}

pub fn getSymbol(c: *Checker, node: NodeIndex) SymbolIndex {
    return c.ast.getSymbol(node);
}

pub fn getDeclaredTypeOfSymbol(c: *Checker, symbol: SymbolIndex) TypeIndex {
    return c.getDeclaredTypeOfSymbol(symbol);
}

pub fn getTypeOfSymbolAtLocation(c: *Checker, symbol: SymbolIndex, node: NodeIndex) TypeIndex {
    return c.getTypeOfSymbolAtLocation(symbol, node);
}

pub fn getContextualType(c: *Checker, node: NodeIndex, contextFlags: u32) TypeIndex {
    return c.getContextualType(node, contextFlags);
}

pub fn getFullyQualifiedName(c: *Checker, symbol: SymbolIndex) []const u8 {
    return c.getFullyQualifiedName(symbol);
}

pub fn getSignatureFromDeclaration(c: *Checker, declaration: NodeIndex) SignatureIndex {
    return c.getSignatureFromDeclaration(declaration);
}

pub fn isOptionalParameter(c: *Checker, node: NodeIndex) bool {
    return c.isOptionalParameter(node);
}

pub fn getConstantValue(c: *Checker, node: NodeIndex) ?f64 {
    return c.getConstantValue(node);
}

pub fn isImplementationOfOverload(c: *Checker, node: NodeIndex) ?bool {
    return c.isImplementationOfOverload(node);
}

pub fn getTypeAtLocation(c: *Checker, node: NodeIndex) TypeIndex {
    return c.getTypeAtLocation(node);
}

pub fn getReturnTypeOfSignature(c: *Checker, signature: SignatureIndex) TypeIndex {
    return c.getReturnTypeOfSignature(signature);
}

pub const ResolvedSignatureAndCandidates = struct {
    signature: SignatureIndex,
    candidates: []const SignatureIndex,
};

pub fn runWithoutResolvedSignatureCaching(c: *Checker, node: NodeIndex, comptime T: type, ctx: anytype, comptime callback: fn (*Checker, NodeIndex, @TypeOf(ctx)) T) T {
    // Port of runWithoutResolvedSignatureCaching
    // For now, since caching is minimal in Zig stub, we just execute the callback
    return callback(c, node, ctx);
}

pub fn getResolvedSignatureWorker(c: *Checker, node: NodeIndex, checkMode: u32, argumentCount: usize) ResolvedSignatureAndCandidates {
    _ = argumentCount; // We don't have apparentArgumentCount yet
    var candidatesOutArray = std.ArrayListUnmanaged(SignatureIndex).empty;
    defer candidatesOutArray.deinit(c.allocator);
    const res = c.getResolvedSignature(node, &candidatesOutArray, checkMode);

    var finalCandidates: []const SignatureIndex = &[_]SignatureIndex{};
    if (candidatesOutArray.items.len > 0) {
        finalCandidates = c.allocator.alloc(SignatureIndex, candidatesOutArray.items.len) catch unreachable;
        @memcpy(@constCast(finalCandidates.ptr), candidatesOutArray.items);
    }

    return .{
        .signature = res,
        .candidates = finalCandidates,
    };
}

pub fn getResolvedSignatureForSignatureHelp(c: *Checker, node: NodeIndex, argumentCount: usize) ResolvedSignatureAndCandidates {
    const Ctx = struct {
        argumentCount: usize,
    };
    return runWithoutResolvedSignatureCaching(c, node, ResolvedSignatureAndCandidates, Ctx{ .argumentCount = argumentCount }, struct {
        fn callback(checker: *Checker, n: NodeIndex, ctx: Ctx) ResolvedSignatureAndCandidates {
            return getResolvedSignatureWorker(checker, n, 1, ctx.argumentCount); // 1 is CheckModeIsForSignatureHelp
        }
    }.callback);
}

pub fn forEachExportAndPropertyOfModule(c: *Checker, moduleSymbol: *anyopaque, cb: *anyopaque, arg2: *anyopaque) *anyopaque {
    _ = c;
    _ = moduleSymbol;
    _ = cb;
    _ = arg2;
    return undefined;
}

pub fn isValidPropertyAccessWithType(c: *Checker, node: *anyopaque, isSuper: *anyopaque, propertyName: *anyopaque, t: *anyopaque) *anyopaque {
    _ = c;
    _ = node;
    _ = isSuper;
    _ = propertyName;
    _ = t;
    return undefined;
}

pub fn getApparentProperties(c: *Checker, t: *anyopaque) *anyopaque {
    _ = c;
    _ = t;
    return undefined;
}

pub fn getAugmentedPropertiesOfType(c: *Checker, t: *anyopaque) *anyopaque {
    _ = c;
    _ = t;
    return undefined;
}

pub fn tryGetMemberInModuleExportsAndProperties(c: *Checker, memberName: *anyopaque, moduleSymbol: *anyopaque) *anyopaque {
    _ = c;
    _ = memberName;
    _ = moduleSymbol;
    return undefined;
}

pub fn tryGetMemberInModuleExports(c: *Checker, memberName: *anyopaque, moduleSymbol: *anyopaque) *anyopaque {
    _ = c;
    _ = memberName;
    _ = moduleSymbol;
    return undefined;
}

pub fn shouldTreatPropertiesOfExternalModuleAsExports(c: *Checker, resolvedExternalModuleType: *anyopaque) *anyopaque {
    _ = c;
    _ = resolvedExternalModuleType;
    return undefined;
}

pub fn skipAlias(c: *Checker, symbol: *anyopaque) *anyopaque {
    _ = c;
    _ = symbol;
    return undefined;
}

pub fn getRootSymbols(c: *Checker, symbol: *anyopaque) *anyopaque {
    _ = c;
    _ = symbol;
    return undefined;
}

pub fn getMappedTypeSymbolOfProperty(c: *Checker, symbol: *anyopaque) *anyopaque {
    _ = c;
    _ = symbol;
    return undefined;
}

pub fn getImmediateRootSymbols(c: *Checker, symbol: *anyopaque) *anyopaque {
    _ = c;
    _ = symbol;
    return undefined;
}

pub fn tryGetTarget(c: *Checker, symbol: *anyopaque) *anyopaque {
    _ = c;
    _ = symbol;
    return undefined;
}

pub fn getExportSymbolOfSymbol(c: *Checker, symbol: *anyopaque) *anyopaque {
    _ = c;
    _ = symbol;
    return undefined;
}

pub fn getExportSpecifierLocalTargetSymbol(c: *Checker, node: *anyopaque) *anyopaque {
    _ = c;
    _ = node;
    return undefined;
}

pub fn getShorthandAssignmentValueSymbol(c: *Checker, location: *anyopaque) *anyopaque {
    _ = c;
    _ = location;
    return undefined;
}

pub fn getSymbolsOfParameterPropertyDeclaration(c: *Checker, parameter: *anyopaque, parameterName: *anyopaque) *anyopaque {
    _ = c;
    _ = parameter;
    _ = parameterName;
    return undefined;
}

pub fn getLocalSymbolForExportSpecifier(c: *Checker, referenceLocation: *anyopaque, referenceSymbol: *anyopaque, exportSpecifier: *anyopaque) *anyopaque {
    _ = c;
    _ = referenceLocation;
    _ = referenceSymbol;
    _ = exportSpecifier;
    return undefined;
}

pub fn isExportSpecifierAlias(referenceLocation: *anyopaque, exportSpecifier: *anyopaque) *anyopaque {
    _ = referenceLocation;
    _ = exportSpecifier;
    return undefined;
}

pub fn getPossibleSymbolReferenceNodes(sourceFile: *anyopaque, symbolName: *anyopaque, container: *anyopaque) *anyopaque {
    _ = sourceFile;
    _ = symbolName;
    _ = container;
    return undefined;
}

pub fn getPossibleSymbolReferencePositions(sourceFile: *anyopaque, symbolName: *anyopaque, container: *anyopaque) *anyopaque {
    _ = sourceFile;
    _ = symbolName;
    _ = container;
    return undefined;
}

pub fn getTypeArgumentConstraint(c: *Checker, node: *anyopaque) *anyopaque {
    _ = c;
    _ = node;
    return undefined;
}

pub fn getUninstantiatedSignatures(c: *Checker, node: *anyopaque) *anyopaque {
    _ = c;
    _ = node;
    return undefined;
}

pub fn getTypeParameterConstraintForPositionAcrossSignatures(c: *Checker, signatures: *anyopaque, position: *anyopaque) *anyopaque {
    _ = c;
    _ = signatures;
    _ = position;
    return undefined;
}

pub fn isTypeInvalidDueToUnionDiscriminant(c: *Checker, contextualType: *anyopaque, obj: *anyopaque) *anyopaque {
    _ = c;
    _ = contextualType;
    _ = obj;
    return undefined;
}

pub fn getExportsAndPropertiesOfModule(c: *Checker, moduleSymbol: *anyopaque) *anyopaque {
    _ = c;
    _ = moduleSymbol;
    return undefined;
}

pub fn getExportsOfModuleAsArray(c: *Checker, moduleSymbol: *anyopaque) *anyopaque {
    _ = c;
    _ = moduleSymbol;
    return undefined;
}

pub fn getJsxIntrinsicTagNamesAt(c: *Checker, location: *anyopaque) *anyopaque {
    _ = c;
    _ = location;
    return undefined;
}

pub fn getContextualTypeForJsxAttribute(c: *Checker, attribute: *anyopaque) *anyopaque {
    _ = c;
    _ = attribute;
    return undefined;
}

pub fn getCandidateSignaturesForStringLiteralCompletions(c: *Checker, call: *anyopaque, editingArgument: *anyopaque) *anyopaque {
    _ = c;
    _ = call;
    _ = editingArgument;
    return undefined;
}

pub fn getTypeAtPosition(c: *Checker, s: *anyopaque, pos: *anyopaque) *anyopaque {
    _ = c;
    _ = s;
    _ = pos;
    return undefined;
}

pub fn getTypeParameterAtPosition(c: *Checker, s: *anyopaque, pos: *anyopaque) *anyopaque {
    _ = c;
    _ = s;
    _ = pos;
    return undefined;
}

pub fn getContextualTypeForArrayLiteralAtPosition(c: *Checker, contextualArrayType: *anyopaque, arrayLiteral: *anyopaque, position: *anyopaque) *anyopaque {
    _ = c;
    _ = contextualArrayType;
    _ = arrayLiteral;
    _ = position;
    return undefined;
}

pub fn isKnownGenericTypeName(name: *anyopaque) *anyopaque {
    _ = name;
    return undefined;
}

pub fn getFirstTypeArgumentFromKnownType(c: *Checker, t: *anyopaque) *anyopaque {
    _ = c;
    _ = t;
    return undefined;
}

pub fn getPropertySymbolsFromContextualType(c: *Checker, node: *anyopaque, contextualType: *anyopaque, unionSymbolOk: *anyopaque) *anyopaque {
    _ = c;
    _ = node;
    _ = contextualType;
    _ = unionSymbolOk;
    return undefined;
}

pub fn getPropertySymbolOfDestructuringAssignment(c: *Checker, location: *anyopaque) *anyopaque {
    _ = c;
    _ = location;
    return undefined;
}

pub fn getTypeOfAssignmentPattern(c: *Checker, expr: *anyopaque) *anyopaque {
    _ = c;
    _ = expr;
    return undefined;
}

pub fn isLibSymbolForHoverVerbosity(c: *Checker, symbol: *anyopaque) *anyopaque {
    _ = c;
    _ = symbol;
    return undefined;
}

pub fn isLibTypeForHoverVerbosity(c: *Checker, t: *anyopaque) *anyopaque {
    _ = c;
    _ = t;
    return undefined;
}
