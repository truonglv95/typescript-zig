const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");

// Exports interfaces and types defining the node builder - concrete implementations are on top of the checker, but these types and interfaces are used by the emit resolver in the printer
pub const SymbolTracker = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        trackSymbol: *const fn (ptr: *anyopaque, symbol: ast_gen.SymbolIndex, enclosingDeclaration: ast_gen.NodeIndex, meaning: u32) bool,
        reportInaccessibleThisError: *const fn (ptr: *anyopaque) void,
        reportPrivateInBaseOfClassExpression: *const fn (ptr: *anyopaque, propertyName: []const u8) void,
        reportInaccessibleUniqueSymbolError: *const fn (ptr: *anyopaque) void,
        reportCyclicStructureError: *const fn (ptr: *anyopaque) void,
        reportLikelyUnsafeImportRequiredError: *const fn (ptr: *anyopaque, specifier: []const u8, symbolName: []const u8) void,
        reportTruncationError: *const fn (ptr: *anyopaque) void,
        reportNonlocalAugmentation: *const fn (ptr: *anyopaque, containingFile: ast_gen.NodeIndex, parentSymbol: ast_gen.SymbolIndex, augmentingSymbol: ast_gen.SymbolIndex) void,
        reportNonSerializableProperty: *const fn (ptr: *anyopaque, propertyName: []const u8) void,

        reportInferenceFallback: *const fn (ptr: *anyopaque, node: ast_gen.NodeIndex) void,
        pushErrorFallbackNode: *const fn (ptr: *anyopaque, node: ast_gen.NodeIndex) void,
        popErrorFallbackNode: *const fn (ptr: *anyopaque) void,
    };

    pub inline fn trackSymbol(self: SymbolTracker, symbol: ast_gen.SymbolIndex, enclosingDeclaration: ast_gen.NodeIndex, meaning: u32) bool {
        return self.vtable.trackSymbol(self.ptr, symbol, enclosingDeclaration, meaning);
    }

    pub inline fn reportInaccessibleThisError(self: SymbolTracker) void {
        self.vtable.reportInaccessibleThisError(self.ptr);
    }

    pub inline fn reportPrivateInBaseOfClassExpression(self: SymbolTracker, propertyName: []const u8) void {
        self.vtable.reportPrivateInBaseOfClassExpression(self.ptr, propertyName);
    }

    pub inline fn reportInaccessibleUniqueSymbolError(self: SymbolTracker) void {
        self.vtable.reportInaccessibleUniqueSymbolError(self.ptr);
    }

    pub inline fn reportCyclicStructureError(self: SymbolTracker) void {
        self.vtable.reportCyclicStructureError(self.ptr);
    }

    pub inline fn reportLikelyUnsafeImportRequiredError(self: SymbolTracker, specifier: []const u8, symbolName: []const u8) void {
        self.vtable.reportLikelyUnsafeImportRequiredError(self.ptr, specifier, symbolName);
    }

    pub inline fn reportTruncationError(self: SymbolTracker) void {
        self.vtable.reportTruncationError(self.ptr);
    }

    pub inline fn reportNonlocalAugmentation(self: SymbolTracker, containingFile: ast_gen.NodeIndex, parentSymbol: ast_gen.SymbolIndex, augmentingSymbol: ast_gen.SymbolIndex) void {
        self.vtable.reportNonlocalAugmentation(self.ptr, containingFile, parentSymbol, augmentingSymbol);
    }

    pub inline fn reportNonSerializableProperty(self: SymbolTracker, propertyName: []const u8) void {
        self.vtable.reportNonSerializableProperty(self.ptr, propertyName);
    }

    pub inline fn reportInferenceFallback(self: SymbolTracker, node: ast_gen.NodeIndex) void {
        self.vtable.reportInferenceFallback(self.ptr, node);
    }

    pub inline fn pushErrorFallbackNode(self: SymbolTracker, node: ast_gen.NodeIndex) void {
        self.vtable.pushErrorFallbackNode(self.ptr, node);
    }

    pub inline fn popErrorFallbackNode(self: SymbolTracker) void {
        self.vtable.popErrorFallbackNode(self.ptr);
    }
};

// NOTE: If modifying this enum, must modify `TypeFormatFlags` too!
pub const Flags = u32;

pub const FlagsNone: Flags = 0;
// Options
pub const FlagsNoTruncation: Flags = 1 << 0;
pub const FlagsWriteArrayAsGenericType: Flags = 1 << 1;
pub const FlagsGenerateNamesForShadowedTypeParams: Flags = 1 << 2;
pub const FlagsUseStructuralFallback: Flags = 1 << 3;
pub const FlagsForbidIndexedAccessSymbolReferences: Flags = 1 << 4;
pub const FlagsWriteTypeArgumentsOfSignature: Flags = 1 << 5;
pub const FlagsUseFullyQualifiedType: Flags = 1 << 6;
pub const FlagsUseOnlyExternalAliasing: Flags = 1 << 7;
pub const FlagsSuppressAnyReturnType: Flags = 1 << 8;
pub const FlagsWriteTypeParametersInQualifiedName: Flags = 1 << 9;
pub const FlagsMultilineObjectLiterals: Flags = 1 << 10;
pub const FlagsWriteClassExpressionAsTypeLiteral: Flags = 1 << 11;
pub const FlagsUseTypeOfFunction: Flags = 1 << 12;
pub const FlagsOmitParameterModifiers: Flags = 1 << 13;
pub const FlagsUseAliasDefinedOutsideCurrentScope: Flags = 1 << 14;
pub const FlagsUseSingleQuotesForStringLiteralType: Flags = 1 << 28;
pub const FlagsNoTypeReduction: Flags = 1 << 29;
pub const FlagsUseInstantiationExpressions: Flags = 1 << 30;
pub const FlagsOmitThisParameter: Flags = 1 << 25;
pub const FlagsWriteCallStyleSignature: Flags = 1 << 27;
// Error handling
pub const FlagsAllowThisInObjectLiteral: Flags = 1 << 15;
pub const FlagsAllowQualifiedNameInPlaceOfIdentifier: Flags = 1 << 16;
pub const FlagsAllowAnonymousIdentifier: Flags = 1 << 17;
pub const FlagsAllowEmptyUnionOrIntersection: Flags = 1 << 18;
pub const FlagsAllowEmptyTuple: Flags = 1 << 19;
pub const FlagsAllowUniqueESSymbolType: Flags = 1 << 20;
pub const FlagsAllowEmptyIndexInfoType: Flags = 1 << 21;
// Errors (cont.)
pub const FlagsAllowNodeModulesRelativePaths: Flags = 1 << 26;
pub const FlagsIgnoreErrors: Flags = FlagsAllowThisInObjectLiteral | FlagsAllowQualifiedNameInPlaceOfIdentifier | FlagsAllowAnonymousIdentifier | FlagsAllowEmptyUnionOrIntersection | FlagsAllowEmptyTuple | FlagsAllowEmptyIndexInfoType | FlagsAllowNodeModulesRelativePaths;
// State
pub const FlagsInObjectTypeLiteral: Flags = 1 << 22;
pub const FlagsInTypeAlias: Flags = 1 << 23;
pub const FlagsInInitialEntityName: Flags = 1 << 24;

// /** @internal */
pub const InternalFlags = i32;

pub const InternalFlagsNone: InternalFlags = 0;
pub const InternalFlagsWriteComputedProps: InternalFlags = 1 << 0;
pub const InternalFlagsNoSyntacticPrinter: InternalFlags = 1 << 1;
pub const InternalFlagsDoNotIncludeSymbolChain: InternalFlags = 1 << 2;
pub const InternalFlagsAllowUnresolvedNames: InternalFlags = 1 << 3;
