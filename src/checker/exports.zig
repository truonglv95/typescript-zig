const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const NodeIndex = ast_gen.NodeIndex;
const types = @import("types.zig");
const TypeIndex = types.TypeIndex;
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const SymbolIndex = checker_mod.SymbolIndex;
const SignatureIndex = checker_mod.SignatureIndex;
const IndexInfoIndex = u32;

pub fn getStringType(c: *Checker) TypeIndex {
    return c.stringType;
}

pub fn getNumberType(c: *Checker) TypeIndex {
    return c.numberType;
}

pub fn getBooleanType(c: *Checker) TypeIndex {
    return c.booleanType;
}

pub fn getVoidType(c: *Checker) TypeIndex {
    return c.voidType;
}

pub fn getUndefinedType(c: *Checker) TypeIndex {
    return c.undefinedType;
}

pub fn getNullType(c: *Checker) TypeIndex {
    return c.nullType;
}

pub fn getAnyType(c: *Checker) TypeIndex {
    return c.anyType;
}

pub fn getErrorType(c: *Checker) TypeIndex {
    return c.errorType;
}

pub fn getNeverType(c: *Checker) TypeIndex {
    return c.neverType;
}

pub fn getUnknownType(c: *Checker) TypeIndex {
    return c.unknownType;
}

pub fn getBigIntType(c: *Checker) TypeIndex {
    return c.bigintType;
}

pub fn getESSymbolType(c: *Checker) TypeIndex {
    return c.esSymbolType;
}

pub fn getBaseTypeOfLiteralType(c: *Checker, t: TypeIndex) TypeIndex {
    return c.getBaseTypeOfLiteralType(t);
}

pub fn getUnknownSymbol(c: *Checker) SymbolIndex {
    return c.unknownSymbol;
}

pub fn getUnionType(c: *Checker, types_arr: []const TypeIndex) TypeIndex {
    return c.getUnionType(types_arr);
}

pub fn getNameTypeOfSymbol(c: *Checker, symbol: SymbolIndex) ?TypeIndex {
    if (c.valueSymbolLinks.get(symbol)) |link| {
        return link.nameType;
    }
    return null;
}

pub fn isTypeUsableAsPropertyName(c: *Checker, t: TypeIndex) bool {
    return c.isTypeUsableAsPropertyName(t);
}

pub fn getPropertyNameFromType(c: *Checker, t: TypeIndex) []const u8 {
    return c.getPropertyNameFromType(t);
}

pub fn getGlobalSymbol(c: *Checker, name: []const u8, meaning: u32, diagnostic: ?u32) SymbolIndex {
    return c.getGlobalSymbol(name, meaning, diagnostic);
}

pub fn getMergedSymbol(c: *Checker, symbol: SymbolIndex) SymbolIndex {
    return c.getMergedSymbol(symbol);
}

pub fn tryFindAmbientModule(c: *Checker, moduleName: []const u8) SymbolIndex {
    return c.tryFindAmbientModule(moduleName, true);
}

pub fn getImmediateAliasedSymbol(c: *Checker, symbol: SymbolIndex) SymbolIndex {
    return c.getImmediateAliasedSymbol(symbol);
}

pub fn getTypeOnlyAliasDeclaration(c: *Checker, symbol: SymbolIndex) NodeIndex {
    return c.getTypeOnlyAliasDeclaration(symbol);
}

pub fn resolveExternalModuleName(c: *Checker, moduleSpecifier: NodeIndex) SymbolIndex {
    return c.resolveExternalModuleName(moduleSpecifier, moduleSpecifier, true);
}

pub fn resolveExternalModuleSymbol(c: *Checker, moduleSymbol: SymbolIndex) SymbolIndex {
    return c.resolveExternalModuleSymbol(moduleSymbol, false);
}

pub fn getTypeFromTypeNode(c: *Checker, node: NodeIndex) TypeIndex {
    return c.getTypeFromTypeNode(node);
}

pub fn isArrayLikeType(c: *Checker, t: TypeIndex) bool {
    return c.isArrayLikeType(t);
}

pub fn getPropertiesOfType(c: *Checker, t: TypeIndex) []const SymbolIndex {
    return c.getPropertiesOfType(t);
}

pub fn getPropertyOfType(c: *Checker, t: TypeIndex, name: []const u8) SymbolIndex {
    return c.getPropertyOfType(t, name);
}

pub fn typeHasCallOrConstructSignatures(c: *Checker, t: TypeIndex) bool {
    return c.typeHasCallOrConstructSignatures(t);
}

pub fn isPropertyAccessible(c: *Checker, node: NodeIndex, isSuper: bool, isWrite: bool, containingType: TypeIndex, property: SymbolIndex) bool {
    return c.isPropertyAccessible(node, isSuper, isWrite, containingType, property);
}

pub fn getTypeOfPropertyOfContextualType(c: *Checker, t: TypeIndex, name: []const u8) TypeIndex {
    return c.getTypeOfPropertyOfContextualType(t, name);
}

pub fn getDeclarationModifierFlagsFromSymbol(c: *Checker, s: SymbolIndex) u32 {
    return c.getDeclarationModifierFlagsFromSymbol(s);
}

pub fn wasCanceled(c: *Checker) bool {
    return c.wasCanceled();
}

pub fn getSignaturesOfType(c: *Checker, t: TypeIndex, kind: u8) []const SignatureIndex {
    return c.getSignaturesOfType(t, kind);
}

pub fn getDeclaredTypeOfSymbol(c: *Checker, symbol: SymbolIndex) TypeIndex {
    return c.getDeclaredTypeOfSymbol(symbol);
}

pub fn getTypeOfSymbol(c: *Checker, symbol: SymbolIndex) TypeIndex {
    return c.getTypeOfSymbol(symbol);
}

pub fn getConstraintOfTypeParameter(c: *Checker, typeParameter: TypeIndex) TypeIndex {
    return c.getConstraintOfTypeParameter(typeParameter);
}

pub fn getDefaultFromTypeParameter(c: *Checker, typeParameter: TypeIndex) TypeIndex {
    return c.getDefaultFromTypeParameter(typeParameter);
}

pub fn getResolutionModeOverride(c: *Checker, node: NodeIndex, reportErrors: bool) u32 {
    return c.getResolutionModeOverride(node, reportErrors);
}

pub fn getEffectiveDeclarationFlags(c: *Checker, n: NodeIndex, flagsToCheck: u32) u32 {
    return c.getEffectiveDeclarationFlags(n, flagsToCheck);
}

pub fn getBaseConstraintOfType(c: *Checker, t: TypeIndex) TypeIndex {
    return c.getBaseConstraintOfType(t);
}

pub fn isTupleType(c: *Checker, t: TypeIndex) bool {
    return c.isTupleType(t);
}

pub fn getReturnTypeOfSignature(c: *Checker, sig: SignatureIndex) TypeIndex {
    return c.getReturnTypeOfSignature(sig);
}

pub fn hasEffectiveRestParameter(c: *Checker, signature: SignatureIndex) bool {
    return c.hasEffectiveRestParameter(signature);
}

pub fn getLocalTypeParametersOfClassOrInterfaceOrTypeAlias(c: *Checker, symbol: SymbolIndex) []const TypeIndex {
    return c.getLocalTypeParametersOfClassOrInterfaceOrTypeAlias(symbol);
}

pub fn getContextualTypeForObjectLiteralElement(c: *Checker, element: NodeIndex, contextFlags: u32) TypeIndex {
    return c.getContextualTypeForObjectLiteralElement(element, contextFlags);
}

pub fn getExpandedParameters(c: *Checker, signature: SignatureIndex, skipUnionExpanding: bool) []const []const SymbolIndex {
    return c.getExpandedParameters(signature, skipUnionExpanding);
}

pub fn getResolvedSignature(c: *Checker, node: NodeIndex) SignatureIndex {
    return c.getResolvedSignature(node, 0, 0); // CheckModeNormal = 0
}

pub fn getTypeOfPropertyOfType(c: *Checker, t: TypeIndex, name: []const u8) TypeIndex {
    return c.getTypeOfPropertyOfType(t, name);
}

pub fn getContextualTypeForArgumentAtIndex(c: *Checker, node: NodeIndex, argIndex: usize) TypeIndex {
    return c.getContextualTypeForArgumentAtIndex(node, argIndex);
}

pub fn getIndexSignaturesAtLocation(c: *Checker, node: NodeIndex) []const NodeIndex {
    return c.getIndexSignaturesAtLocation(node);
}

pub fn getResolvedSymbol(c: *Checker, node: NodeIndex) SymbolIndex {
    return c.getResolvedSymbol(node);
}

pub fn getJsxNamespace(c: *Checker, location: NodeIndex) []const u8 {
    return c.getJsxNamespace(location);
}

pub fn getJsxFragmentFactory(c: *Checker, location: NodeIndex) []const u8 {
    const entity = c.getJsxFragmentFactoryEntity(location);
    if (entity != 0) {
        return c.ast.identifier_text(c.ast.getFirstIdentifier(entity));
    }
    return "";
}

pub fn resolveName(c: *Checker, name: []const u8, location: NodeIndex, meaning: u32, excludeGlobals: bool) SymbolIndex {
    return c.resolveName(location, name, meaning, 0, true, excludeGlobals);
}

pub fn getSymbolFlags(c: *Checker, symbol: SymbolIndex) u32 {
    return c.getSymbolFlags(symbol);
}

pub fn getBaseTypes(c: *Checker, t: TypeIndex) []const TypeIndex {
    return c.getBaseTypes(t);
}

pub fn getApparentType(c: *Checker, t: TypeIndex) TypeIndex {
    return c.getApparentType(t);
}

pub fn getBaseConstructorTypeOfClass(c: *Checker, t: TypeIndex) TypeIndex {
    return c.getBaseConstructorTypeOfClass(t);
}

pub fn getRestTypeOfSignature(c: *Checker, sig: SignatureIndex) TypeIndex {
    return c.getRestTypeOfSignature(sig);
}

pub fn getTypeArguments(c: *Checker, t: TypeIndex) []const TypeIndex {
    return c.getTypeArguments(t);
}

pub fn getIndexInfoOfType(c: *Checker, t: TypeIndex, keyType: TypeIndex) IndexInfoIndex {
    return c.getIndexInfoOfType(t, keyType);
}

pub fn getIndexInfosOfType(c: *Checker, t: TypeIndex) []const IndexInfoIndex {
    return c.getIndexInfosOfType(t);
}

pub fn isContextSensitive(c: *Checker, node: NodeIndex) bool {
    return c.isContextSensitive(node);
}

pub fn fillMissingTypeArguments(c: *Checker, typeArguments: []const TypeIndex, typeParameters: []const TypeIndex, minTypeArgumentCount: usize, isJavaScriptImplicitAny: bool) []const TypeIndex {
    return c.fillMissingTypeArguments(typeArguments, typeParameters, minTypeArgumentCount, isJavaScriptImplicitAny);
}

pub fn getMinTypeArgumentCount(c: *Checker, typeParameters: []const TypeIndex) usize {
    return c.getMinTypeArgumentCount(typeParameters);
}

pub fn getWidenedLiteralType(c: *Checker, t: TypeIndex) TypeIndex {
    return c.getWidenedLiteralType(t);
}

pub fn isTypeAssignableTo(c: *Checker, source: TypeIndex, target: TypeIndex) bool {
    return c.isTypeAssignableTo(source, target);
}

pub fn requiresAddingImplicitUndefined(c: *Checker, node: NodeIndex) bool {
    var enclosingDeclaration = c.ast.findAncestor(node, c.ast.isDeclaration);
    if (enclosingDeclaration == 0) {
        enclosingDeclaration = c.ast.getSourceFileOfNode(node);
    }
    const symbol = c.ast.getSymbol(node);
    if (symbol == 0) {
        return false;
    }
    return c.getEmitResolver().requiresAddingImplicitUndefined(node, symbol, enclosingDeclaration);
}

pub fn removeMissingOrUndefinedType(c: *Checker, t: TypeIndex) TypeIndex {
    return c.removeMissingOrUndefinedType(t);
}

pub fn getWidenedType(c: *Checker, t: TypeIndex) TypeIndex {
    return c.getWidenedType(t);
}
