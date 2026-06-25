const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const types = @import("types.zig");
const checker = @import("checker.zig");
const binder = @import("../binder/binder.zig");
const core = @import("../core/core.zig");

// Links for jsx
pub const JSXLinks = struct {
    importRef: ast_gen.NodeIndex = 0,
};

pub const Tristate = enum(u8) {
    Unknown = 0,
    True = 1,
    False = 2,
};

// Links for declarations
pub const DeclarationLinks = struct {
    isVisible: Tristate = .Unknown, // if declaration is depended upon by exported declarations
};

pub const DeclarationFileLinks = struct {
    aliasesMarked: bool = false, // if file has had alias visibility marked
};

pub const SymbolAccessibilityResult = struct {
    accessibility: u32, // stub for printer.SymbolAccessibilityResult
    aliasesToMakeVisible: ?[]ast_gen.NodeIndex = null,
    errorSymbolName: ?[]const u8 = null,
    errorNode: ast_gen.NodeIndex = 0,
};

pub const TypeReferenceSerializationKind = enum(u32) {
    Unknown,
    TypeWithConstructSignatureAndValue,
    VoidNullableOrNeverType,
    NumberLikeType,
    BigIntLikeType,
    StringLikeType,
    BooleanType,
    ArrayLikeType,
    ESSymbolType,
    Promise,
    TypeWithCallSignature,
    ObjectType,
};

pub const EmitResolver = struct {
    chk: *checker.Checker,
    jsxLinks: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, JSXLinks) = .empty,
    declarationLinks: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, DeclarationLinks) = .empty,
    declarationFileLinks: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, DeclarationFileLinks) = .empty,

    pub fn init(chk: *checker.Checker) EmitResolver {
        return .{
            .chk = chk,
        };
    }

    pub fn deinit(self: *EmitResolver, allocator: std.mem.Allocator) void {
        self.jsxLinks.deinit(allocator);
        self.declarationLinks.deinit(allocator);
        self.declarationFileLinks.deinit(allocator);
    }

    pub fn getJsxFactoryEntity(self: *EmitResolver, location: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self; _ = location;
        return 0; // Stub
    }

    pub fn getJsxFragmentFactoryEntity(self: *EmitResolver, location: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self; _ = location;
        return 0; // Stub
    }

    pub fn isOptionalParameter(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        _ = self; _ = node;
        return false; // Stub
    }

    pub fn isLateBound(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        _ = self; _ = node;
        return false; // Stub
    }

    pub fn getEnumMemberValue(self: *EmitResolver, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self; _ = node;
        return 0; // Stub returning NodeIndex instead of evaluator.Result
    }

    pub fn isDeclarationVisible(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        _ = self; _ = node;
        return false; // Stub
    }

    pub fn precalculateDeclarationEmitVisibility(self: *EmitResolver, file: ast_gen.NodeIndex) void {
        _ = self; _ = file;
    }

    pub fn isEntityNameVisible(self: *EmitResolver, entityName: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex) SymbolAccessibilityResult {
        _ = self; _ = entityName; _ = enclosingDeclaration;
        return .{ .accessibility = 0 }; // Stub
    }

    pub fn isImplementationOfOverload(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        _ = self; _ = node;
        return false; // Stub
    }

    pub fn isImportRequiredByAugmentation(self: *EmitResolver, decl: ast_gen.NodeIndex) bool {
        _ = self; _ = decl;
        return false; // Stub
    }

    pub fn isDefinitelyReferenceToGlobalSymbolObject(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        _ = self; _ = node;
        return false; // Stub
    }

    pub fn requiresAddingImplicitUndefined(self: *EmitResolver, declaration: ast_gen.NodeIndex, symbol: ast_gen.SymbolIndex, enclosingDeclaration: ast_gen.NodeIndex) bool {
        _ = self; _ = declaration; _ = symbol; _ = enclosingDeclaration;
        return false; // Stub
    }

    pub fn requiresAddingImplicitUndefinedUnsafe(self: *EmitResolver, declaration: ast_gen.NodeIndex, symbol: ast_gen.SymbolIndex, enclosingDeclaration: ast_gen.NodeIndex) bool {
        _ = self; _ = declaration; _ = symbol; _ = enclosingDeclaration;
        return false; // Stub
    }

    pub fn isLiteralConstDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        _ = self; _ = node;
        return false; // Stub
    }

    pub fn isExpandoFunctionDeclarationUnsafe(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        _ = self; _ = node;
        return false; // Stub
    }

    pub fn isExpandoFunctionDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        _ = self; _ = node;
        return false; // Stub
    }

    pub fn isSymbolAccessible(self: *EmitResolver, symbol: ast_gen.SymbolIndex, enclosingDeclaration: ast_gen.NodeIndex, meaning: u32, shouldComputeAliasToMarkVisible: bool) SymbolAccessibilityResult {
        _ = self; _ = symbol; _ = enclosingDeclaration; _ = meaning; _ = shouldComputeAliasToMarkVisible;
        return .{ .accessibility = 0 }; // Stub
    }

    pub fn isReferencedAliasDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        _ = self; _ = node;
        return false; // Stub
    }

    pub fn isValueAliasDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        _ = self; _ = node;
        return false; // Stub
    }

    pub fn isTopLevelValueImportEqualsWithEntityName(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        _ = self; _ = node;
        return false; // Stub
    }

    pub fn markLinkedReferencesRecursively(self: *EmitResolver, file: ast_gen.NodeIndex) void {
        _ = self; _ = file;
    }

    pub fn getExternalModuleFileFromDeclaration(self: *EmitResolver, declaration: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self; _ = declaration;
        return 0; // Stub
    }

    pub fn getReferencedExportContainer(self: *EmitResolver, node: ast_gen.NodeIndex, prefixLocals: bool) ast_gen.NodeIndex {
        _ = self; _ = node; _ = prefixLocals;
        return 0; // Stub
    }

    pub fn setReferencedImportDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex, ref: ast_gen.NodeIndex) void {
        _ = self; _ = node; _ = ref;
    }

    pub fn getReferencedImportDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self; _ = node;
        return 0; // Stub
    }

    pub fn getReferencedValueDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self; _ = node;
        return 0; // Stub
    }

    pub fn getReferencedValueDeclarations(self: *EmitResolver, node: ast_gen.NodeIndex) []const ast_gen.NodeIndex {
        _ = self; _ = node;
        return &[_]ast_gen.NodeIndex{}; // Stub
    }

    pub fn isNameResolvable(self: *EmitResolver, location: ast_gen.NodeIndex, name: []const u8) bool {
        _ = self; _ = location; _ = name;
        return false; // Stub
    }

    pub fn getElementAccessExpressionName(self: *EmitResolver, expression: ast_gen.NodeIndex) []const u8 {
        _ = self; _ = expression;
        return ""; // Stub
    }

    pub fn getReferencedMemberValueDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self; _ = node;
        return 0; // Stub
    }

    pub fn createReturnTypeOfSignatureDeclaration(self: *EmitResolver, emitContext: anytype, signatureDeclaration: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: u32, internalFlags: u32, tracker: anytype) ast_gen.NodeIndex {
        _ = self; _ = emitContext; _ = signatureDeclaration; _ = enclosingDeclaration; _ = flags; _ = internalFlags; _ = tracker;
        return 0; // Stub
    }

    pub fn createTypeParametersOfSignatureDeclaration(self: *EmitResolver, emitContext: anytype, signatureDeclaration: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: u32, internalFlags: u32, tracker: anytype) []const ast_gen.NodeIndex {
        _ = self; _ = emitContext; _ = signatureDeclaration; _ = enclosingDeclaration; _ = flags; _ = internalFlags; _ = tracker;
        return &[_]ast_gen.NodeIndex{}; // Stub
    }

    pub fn createTypeOfDeclaration(self: *EmitResolver, emitContext: anytype, declaration: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: u32, internalFlags: u32, tracker: anytype) ast_gen.NodeIndex {
        _ = self; _ = emitContext; _ = declaration; _ = enclosingDeclaration; _ = flags; _ = internalFlags; _ = tracker;
        return 0; // Stub
    }

    pub fn createLiteralConstValue(self: *EmitResolver, emitContext: anytype, node: ast_gen.NodeIndex, tracker: anytype) ast_gen.NodeIndex {
        _ = self; _ = emitContext; _ = node; _ = tracker;
        return 0; // Stub
    }

    pub fn createTypeOfExpression(self: *EmitResolver, emitContext: anytype, expression: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: u32, internalFlags: u32, tracker: anytype) ast_gen.NodeIndex {
        _ = self; _ = emitContext; _ = expression; _ = enclosingDeclaration; _ = flags; _ = internalFlags; _ = tracker;
        return 0; // Stub
    }

    pub fn createLateBoundIndexSignatures(self: *EmitResolver, emitContext: anytype, container: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: u32, internalFlags: u32, tracker: anytype) []const ast_gen.NodeIndex {
        _ = self; _ = emitContext; _ = container; _ = enclosingDeclaration; _ = flags; _ = internalFlags; _ = tracker;
        return &[_]ast_gen.NodeIndex{}; // Stub
    }

    pub fn getEffectiveDeclarationFlags(self: *EmitResolver, node: ast_gen.NodeIndex, flags: u32) u32 {
        _ = self; _ = node; _ = flags;
        return 0; // Stub
    }

    pub fn getResolutionModeOverride(self: *EmitResolver, node: ast_gen.NodeIndex) u32 {
        _ = self; _ = node;
        return 0; // Stub
    }

    pub fn getConstantValue(self: *EmitResolver, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self; _ = node;
        return 0; // Stub
    }

    pub fn getTypeReferenceSerializationKind(self: *EmitResolver, typeName: ast_gen.NodeIndex, location: ast_gen.NodeIndex) TypeReferenceSerializationKind {
        _ = self; _ = typeName; _ = location;
        return .Unknown; // Stub
    }

    pub fn getPropertiesOfContainerFunction(self: *EmitResolver, node: ast_gen.NodeIndex) []const ast_gen.SymbolIndex {
        _ = self; _ = node;
        return &[_]ast_gen.SymbolIndex{}; // Stub
    }

    pub fn tryJSTypeNodeToTypeNode(self: *EmitResolver, emitContext: anytype, typeNode: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: u32, internalFlags: u32, tracker: anytype) ast_gen.NodeIndex {
        _ = self; _ = emitContext; _ = typeNode; _ = enclosingDeclaration; _ = flags; _ = internalFlags; _ = tracker;
        return 0; // Stub
    }

    pub fn getBaseDeclarationsForPropertyDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex) []const ast_gen.NodeIndex {
        _ = self; _ = node;
        return &[_]ast_gen.NodeIndex{}; // Stub
    }
}
;
