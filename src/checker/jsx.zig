const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const types = @import("types.zig");
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const CheckMode = checker_mod.CheckMode;

pub const JsxFlags = struct {
    pub const None: u32 = 0;
    pub const IntrinsicNamedElement: u32 = 1 << 0;
    pub const IntrinsicIndexedElement: u32 = 1 << 1;
    pub const IntrinsicElement: u32 = IntrinsicNamedElement | IntrinsicIndexedElement;
};

pub const JsxReferenceKind = enum(u32) {
    Component = 0,
    Function,
    Mixed,
};

pub const JsxElementLinks = struct {
    jsxFlags: u32 = JsxFlags.None,
    resolvedJsxElementAttributesType: types.TypeIndex = 0,
    jsxNamespace: ast_gen.SymbolIndex = 0,
    jsxImplicitImportContainer: ast_gen.SymbolIndex = 0,
};

pub const ContextFlags = u32;
pub const InferenceContext = opaque{}; // stub

pub fn checkJsxElement(c: anytype, node: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    _ = c;
    _ = node;
    _ = checkMode;
    return 0;
}

pub fn checkJsxElementDeferred(c: anytype, node: ast_gen.NodeIndex) void {
    _ = c;
    _ = node;
}

pub fn checkJsxExpression(c: anytype, node: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    _ = c;
    _ = node;
    _ = checkMode;
    return 0;
}

pub fn checkJsxSelfClosingElement(c: anytype, node: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    _ = c;
    _ = node;
    _ = checkMode;
    return 0;
}

pub fn checkJsxSelfClosingElementDeferred(c: anytype, node: ast_gen.NodeIndex) void {
    _ = c;
    _ = node;
}

pub fn checkJsxFragment(c: anytype, node: ast_gen.NodeIndex) types.TypeIndex {
    _ = c;
    _ = node;
    return 0;
}

pub fn checkJsxAttributes(c: anytype, node: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    _ = c;
    _ = node;
    _ = checkMode;
    return 0;
}

pub fn checkJsxOpeningLikeElementOrOpeningFragment(c: anytype, node: ast_gen.NodeIndex) void {
    _ = c;
    _ = node;
}

pub fn checkJsxPreconditions(c: anytype, errorNode: ast_gen.NodeIndex) void {
    _ = c;
    _ = errorNode;
}

pub fn checkJsxReturnAssignableToAppropriateBound(c: anytype, refKind: JsxReferenceKind, elemInstanceType: types.TypeIndex, openingLikeElement: ast_gen.NodeIndex) void {
    _ = c;
    _ = refKind;
    _ = elemInstanceType;
    _ = openingLikeElement;
}

pub fn inferJsxTypeArguments(c: anytype, node: ast_gen.NodeIndex, signature: types.SignatureIndex, checkMode: CheckMode, context: *InferenceContext) []types.TypeIndex {
    _ = c;
    _ = node;
    _ = signature;
    _ = checkMode;
    _ = context;
    return &[_]types.TypeIndex{};
}

pub fn getContextualTypeForJsxExpression(c: anytype, node: ast_gen.NodeIndex, contextFlags: ContextFlags) types.TypeIndex {
    _ = c;
    _ = node;
    _ = contextFlags;
    return 0;
}

pub fn getContextualTypeForJsxAttribute(c: anytype, attribute: ast_gen.NodeIndex, contextFlags: ContextFlags) types.TypeIndex {
    _ = c;
    _ = attribute;
    _ = contextFlags;
    return 0;
}

pub fn getContextualJsxElementAttributesType(c: anytype, node: ast_gen.NodeIndex, contextFlags: ContextFlags) types.TypeIndex {
    _ = c;
    _ = node;
    _ = contextFlags;
    return 0;
}

pub fn getContextualTypeForChildJsxExpression(c: anytype, node: ast_gen.NodeIndex, child: ast_gen.NodeIndex, contextFlags: ContextFlags) types.TypeIndex {
    _ = c;
    _ = node;
    _ = child;
    _ = contextFlags;
    return 0;
}

pub fn discriminateContextualTypeByJSXAttributes(c: anytype, node: ast_gen.NodeIndex, contextualType: types.TypeIndex) types.TypeIndex {
    _ = c;
    _ = node;
    _ = contextualType;
    return 0;
}

pub fn elaborateJsxComponents(c: anytype, node: ast_gen.NodeIndex, source: types.TypeIndex, target: types.TypeIndex, relation: types.RelationIndex, diagnosticOutput: anytype) bool {
    _ = c;
    _ = node;
    _ = source;
    _ = target;
    _ = relation;
    _ = diagnosticOutput;
    return false;
}

pub fn generateJsxChildren(c: anytype, node: ast_gen.NodeIndex, getInvalidTextDiagnostic: anytype) void {
    _ = c;
    _ = node;
    _ = getInvalidTextDiagnostic;
}

pub fn getElaborationElementForJsxChild(c: anytype, child: ast_gen.NodeIndex, nameType: types.TypeIndex, getInvalidTextDiagnostic: anytype) void {
    _ = c;
    _ = child;
    _ = nameType;
    _ = getInvalidTextDiagnostic;
}

pub fn elaborateIterableOrArrayLikeTargetElementwise(c: anytype, iterator: anytype, source: types.TypeIndex, target: types.TypeIndex, relation: types.RelationIndex, diagnosticOutput: anytype) bool {
    _ = c;
    _ = iterator;
    _ = source;
    _ = target;
    _ = relation;
    _ = diagnosticOutput;
    return false;
}

pub fn getSuggestedSymbolForNonexistentJSXAttribute(c: *Checker, name: []const u8, containingType: types.TypeIndex) types.SymbolIndex {
    _ = c; _ = name; _ = containingType;
    return 0;
}

pub fn getJSXFragmentType(c: *Checker, node: ast_gen.NodeIndex) types.TypeIndex {
    _ = c; _ = node;
    return 0;
}

pub fn resolveJsxOpeningLikeElement(c: *Checker, node: ast_gen.NodeIndex, candidatesOutArray: anytype, checkMode: CheckMode) types.SignatureIndex {
    _ = c; _ = node; _ = candidatesOutArray; _ = checkMode;
    return 0;
}

pub fn checkApplicableSignatureForJsxCallLikeElement(c: *Checker, node: ast_gen.NodeIndex, signature: types.SignatureIndex, relation: types.RelationIndex, checkMode: CheckMode, reportErrors: bool, diagnosticOutput: anytype) bool {
    _ = c; _ = node; _ = signature; _ = relation; _ = checkMode; _ = reportErrors; _ = diagnosticOutput;
    return false;
}

pub fn createJsxAttributesTypeFromAttributesProperty(c: anytype, openingLikeElement: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    _ = c;
    _ = openingLikeElement;
    _ = checkMode;
    return 0;
}

pub fn checkJsxAttribute(c: *Checker, node: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    _ = c; _ = node; _ = checkMode;
    return 0;
}

pub fn checkJsxChildren(c: *Checker, node: ast_gen.NodeIndex, checkMode: CheckMode) []types.TypeIndex {
    _ = c; _ = node; _ = checkMode;
    return &[_]types.TypeIndex{};
}

pub fn getUninstantiatedJsxSignaturesOfType(c: anytype, elementType: types.TypeIndex, caller: ast_gen.NodeIndex) []types.SignatureIndex {
    _ = c;
    _ = elementType;
    _ = caller;
    return &[_]types.SignatureIndex{};
}

pub fn getEffectiveFirstArgumentForJsxSignature(c: *Checker, signature: types.SignatureIndex, node: ast_gen.NodeIndex) types.TypeIndex {
    _ = c; _ = signature; _ = node;
    return 0;
}

pub fn getJsxPropsTypeFromCallSignature(c: anytype, sig: types.SignatureIndex, context: ast_gen.NodeIndex) types.TypeIndex {
    _ = c;
    _ = sig;
    _ = context;
    return 0;
}

pub fn getJsxPropsTypeFromClassType(c: anytype, sig: types.SignatureIndex, context: ast_gen.NodeIndex) types.TypeIndex {
    _ = c;
    _ = sig;
    _ = context;
    return 0;
}

pub fn getJsxPropsTypeForSignatureFromMember(c: anytype, sig: types.SignatureIndex, forcedLookupLocation: []const u8) types.TypeIndex {
    _ = c;
    _ = sig;
    _ = forcedLookupLocation;
    return 0;
}

pub fn getJsxManagedAttributesFromLocatedAttributes(c: anytype, context: ast_gen.NodeIndex, ns: ast_gen.NodeIndex, attributesType: types.TypeIndex) types.TypeIndex {
    _ = c;
    _ = context;
    _ = ns;
    _ = attributesType;
    return 0;
}

pub fn instantiateAliasOrInterfaceWithDefaults(c: anytype, managedSym: ast_gen.NodeIndex, typeArguments: []types.TypeIndex, inJavaScript: bool) types.TypeIndex {
    _ = c;
    _ = managedSym;
    _ = typeArguments;
    _ = inJavaScript;
    return 0;
}

pub fn getJsxLibraryManagedAttributes(c: anytype, jsxNamespace: ast_gen.NodeIndex) ast_gen.NodeIndex {
    _ = c;
    _ = jsxNamespace;
    return 0;
}

pub fn getJsxElementTypeSymbol(c: anytype, jsxNamespace: ast_gen.NodeIndex) ast_gen.NodeIndex {
    _ = c;
    _ = jsxNamespace;
    return 0;
}

pub fn getJsxElementPropertiesName(c: anytype, jsxNamespace: ast_gen.NodeIndex) []const u8 {
    _ = c;
    _ = jsxNamespace;
    return "";
}

pub fn getJsxElementChildrenPropertyName(c: anytype, jsxNamespace: ast_gen.NodeIndex) []const u8 {
    _ = c;
    _ = jsxNamespace;
    return "";
}

pub fn getNameFromJsxElementAttributesContainer(c: anytype, nameOfAttribPropContainer: []const u8, jsxNamespace: ast_gen.NodeIndex) []const u8 {
    _ = c;
    _ = nameOfAttribPropContainer;
    _ = jsxNamespace;
    return "";
}

pub fn getStaticTypeOfReferencedJsxConstructor(c: anytype, context: ast_gen.NodeIndex) types.TypeIndex {
    _ = c;
    _ = context;
    return 0;
}

pub fn getIntrinsicAttributesTypeFromStringLiteralType(c: anytype, t: types.TypeIndex, location: ast_gen.NodeIndex) types.TypeIndex {
    _ = c;
    _ = t;
    _ = location;
    return 0;
}

pub fn getJsxReferenceKind(c: *Checker, node: ast_gen.NodeIndex) JsxReferenceKind {
    _ = c; _ = node;
    return .Mixed;
}

pub fn createSignatureForJSXIntrinsic(c: *Checker, node: ast_gen.NodeIndex, result: types.TypeIndex) types.SignatureIndex {
    _ = c; _ = node; _ = result;
    return 0;
}
pub fn getJsxElementTypeTypeAt(c: anytype, location: ast_gen.NodeIndex) types.TypeIndex {
    _ = c;
    _ = location;
    return 0;
}

pub fn getJsxType(c: anytype, name: []const u8, location: ast_gen.NodeIndex) types.TypeIndex {
    _ = c;
    _ = name;
    _ = location;
    return 0;
}

pub fn getJsxNamespaceAt(c: anytype, location: ast_gen.NodeIndex) ast_gen.NodeIndex {
    _ = c;
    _ = location;
    return 0;
}

pub fn getJsxNamespace(c: *Checker, location: ast_gen.NodeIndex) []const u8 {
    _ = c; _ = location;
    return "";
}

pub fn getLocalJsxNamespace(c: anytype, file: ast_gen.NodeIndex) []const u8 {
    _ = c;
    _ = file;
    return "";
}

pub fn getJsxFactoryEntity(c: *Checker, location: ast_gen.NodeIndex) ast_gen.NodeIndex {
    _ = c; _ = location;
    return 0;
}

pub fn getJsxFragmentFactoryEntity(c: anytype, location: ast_gen.NodeIndex) ast_gen.NodeIndex {
    _ = c;
    _ = location;
    return 0;
}

pub fn parseIsolatedEntityName(c: anytype, name: []const u8) ast_gen.NodeIndex {
    _ = c;
    _ = name;
    return 0;
}

pub fn getJsxNamespaceContainerForImplicitImport(c: anytype, location: ast_gen.NodeIndex) ast_gen.NodeIndex {
    _ = c;
    _ = location;
    return 0;
}

pub fn getJSXRuntimeImportSpecifier(c: anytype, file: ast_gen.NodeIndex) void {
    _ = c;
    _ = file;
    return undefined;
}


pub fn isJsxIntrinsicTagName(c: *Checker, tagName: ast_gen.NodeIndex) bool {
    const isId = ast.isIdentifier(c.binder.ast, tagName);
    const isNamespaced = ast.isJsxNamespacedName(c.binder.ast, tagName);
    if (isId) {
        // const text = ast.getTextOfNode(c.binder.ast, tagName);
        // return scanner.isIntrinsicJsxName(text);
        return true; // stub
    }
    return isNamespaced;
}

pub fn isJsxOpeningLikeElement(c: *Checker, node: ast_gen.NodeIndex) bool {
    const kind = c.binder.ast.getNode(node);
    return kind == .JsxOpeningElement or kind == .JsxSelfClosingElement;
}

pub fn getTagName(c: *Checker, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const data = c.binder.ast.getNode(node);
    switch (data) {
        .JsxOpeningElement => |e| return e.TagName,
        .JsxSelfClosingElement => |e| return e.TagName,
        .JsxClosingElement => |e| return e.TagName,
        else => return 0,
    }
}

pub fn getAttributes(c: *Checker, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const data = c.binder.ast.getNode(node);
    switch (data) {
        .JsxOpeningElement => |e| return e.Attributes,
        .JsxSelfClosingElement => |e| return e.Attributes,
        else => return 0,
    }
}

pub fn isJsxAttributeLike(c: *Checker, node: ast_gen.NodeIndex) bool {
    const kind = ast.getKind(c.binder.ast, node);
    return kind == .JsxAttribute or kind == .JsxSpreadAttribute;
}

pub fn getNameText(c: *Checker, node: ast_gen.NodeIndex) []const u8 {
    _ = c; _ = node;
    return "";
}

pub fn getSliceIndex(slice: []const ast_gen.NodeIndex, item: ast_gen.NodeIndex) i32 {
    for (slice, 0..) |v, i| {
        if (v == item) return @intCast(i);
    }
    return -1;
}
