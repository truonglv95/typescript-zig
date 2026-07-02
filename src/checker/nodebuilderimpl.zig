const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const types = @import("types.zig");
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;

pub const Flags = packed struct(u32) {
    NoTruncation: bool = false,
    UseFullyQualifiedType: bool = false,
    UseAliasDefinedOutsideCurrentScope: bool = false,
    AllowQualifiedNameInPlaceOfIdentifier: bool = false,
    InInitialEntityName: bool = false,
    AllowNodeModulesRelativePaths: bool = false,
    UseInstantiationExpressions: bool = false,
    IgnoreErrors: bool = false,
    // Add other flags as necessary
    _padding: u24 = 0,
};

pub const InternalFlags = packed struct(u32) {
    WriteComputedProps: bool = false,
    _padding: u31 = 0,
};

pub const CompositeSymbolIdentity = packed struct(u65) {
    isConstructorNode: bool,
    symbolId: ast_gen.SymbolIndex,
    nodeId: ast_gen.NodeIndex,
};

pub const TrackedSymbolArgs = struct {
    symbol: ast_gen.SymbolIndex,
    enclosingDeclaration: ast_gen.NodeIndex,
    meaning: u32,
};

pub const SerializedTypeEntry = struct {
    node: ast_gen.NodeIndex,
    truncating: bool,
    addedLength: usize,
    trackedSymbols: []TrackedSymbolArgs,
};

pub const CompositeTypeCacheIdentity = struct {
    typeId: types.TypeIndex,
    flags: Flags,
    internalFlags: InternalFlags,
};

pub const NodeBuilderLinks = struct {
    serializedTypes: std.AutoHashMapUnmanaged(CompositeTypeCacheIdentity, SerializedTypeEntry) = .empty,
    fakeScopeForSignatureDeclaration: ?[]const u8 = null,
};

pub const NodeBuilderSymbolLinks = struct {
    specifierCache: std.StringHashMapUnmanaged([]const u8) = .empty,
};

pub const NodeBuilderContext = struct {
    approximateLength: usize = 0,
    maxTruncationLength: usize = 0,
    encounteredError: bool = false,
    truncating: bool = false,
    reportedDiagnostic: bool = false,
    flags: Flags = .{},
    internalFlags: InternalFlags = .{},
    depth: usize = 0,
    maxExpansionDepth: isize = -1,
    typeStack: std.ArrayListUnmanaged(types.TypeIndex) = .empty,
    canIncreaseExpansionDepth: bool = false,
    expansionTruncated: bool = false,
    enclosingDeclaration: ast_gen.NodeIndex = 0,
    enclosingFile: ast_gen.NodeIndex = 0,
    inferTypeParameters: std.ArrayListUnmanaged(types.TypeIndex) = .empty,
    visitedTypes: std.AutoHashMapUnmanaged(types.TypeIndex, void) = .empty,
    symbolDepth: std.AutoHashMapUnmanaged(CompositeSymbolIdentity, usize) = .empty,
    trackedSymbols: std.ArrayListUnmanaged(TrackedSymbolArgs) = .empty,
    // mapper: ?*TypeMapper = null,
    reverseMappedStack: std.ArrayListUnmanaged(ast_gen.SymbolIndex) = .empty,
    enclosingSymbolTypes: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.TypeIndex) = .empty,
    suppressReportInferenceFallback: bool = false,
    remappedSymbolReferences: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, ast_gen.SymbolIndex) = .empty,

    typeParameterNames: std.AutoHashMapUnmanaged(types.TypeIndex, ast_gen.NodeIndex) = .empty,
    typeParameterNamesByText: std.StringHashMapUnmanaged(void) = .empty,
    typeParameterNamesByTextNextNameCount: std.StringHashMapUnmanaged(usize) = .empty,
    typeParameterSymbolList: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, void) = .empty,
};

pub const NodeBuilderImpl = struct {
    c: *Checker,
    ctx: NodeBuilderContext,

    links: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, NodeBuilderLinks) = .empty,
    symbolLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, NodeBuilderSymbolLinks) = .empty,
    idToSymbol: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, ast_gen.SymbolIndex) = .empty,

    pub fn init(c: *Checker) NodeBuilderImpl {
        return .{
            .c = c,
            .ctx = .{},
        };
    }

    pub fn deinit(self: *NodeBuilderImpl) void {
        const allocator = self.c.allocator;
        self.ctx.typeStack.deinit(allocator);
        self.ctx.inferTypeParameters.deinit(allocator);
        self.ctx.visitedTypes.deinit(allocator);
        self.ctx.symbolDepth.deinit(allocator);
        self.ctx.trackedSymbols.deinit(allocator);
        self.ctx.reverseMappedStack.deinit(allocator);
        self.ctx.enclosingSymbolTypes.deinit(allocator);
        self.ctx.remappedSymbolReferences.deinit(allocator);
        self.ctx.typeParameterNames.deinit(allocator);
        self.ctx.typeParameterNamesByText.deinit(allocator);
        self.ctx.typeParameterNamesByTextNextNameCount.deinit(allocator);
        self.ctx.typeParameterSymbolList.deinit(allocator);

        var linkIt = self.links.iterator();
        while (linkIt.next()) |entry| {
            var val = entry.value_ptr;
            val.serializedTypes.deinit(allocator);
        }
        self.links.deinit(allocator);

        var symLinkIt = self.symbolLinks.iterator();
        while (symLinkIt.next()) |entry| {
            var val = entry.value_ptr;
            val.specifierCache.deinit(allocator);
        }
        self.symbolLinks.deinit(allocator);
        self.idToSymbol.deinit(allocator);
    }
    pub fn saveRestoreFlags(b: *NodeBuilderImpl) FlagsState {
        return .{
            .flags = b.ctx.flags,
            .internalFlags = b.ctx.internalFlags,
            .depth = b.ctx.depth,
        };
    }

    pub fn restoreFlags(b: *NodeBuilderImpl, state: FlagsState) void {
        b.ctx.flags = state.flags;
        b.ctx.internalFlags = state.internalFlags;
        b.ctx.depth = state.depth;
    }

    pub fn checkTruncationLength(b: *NodeBuilderImpl) bool {
        if (b.ctx.truncating) {
            return true;
        }
        var maxLength: usize = 0;
        if (b.ctx.flags.NoTruncation) {
            maxLength = 1_000_000;
        } else if (b.ctx.maxTruncationLength > 0) {
            maxLength = b.ctx.maxTruncationLength;
        } else {
            maxLength = 160;
        }
        b.ctx.truncating = b.ctx.approximateLength > maxLength;
        return b.ctx.truncating;
    }

    pub fn checkTruncationLengthIfExpanding(b: *NodeBuilderImpl) bool {
        if (b.ctx.maxExpansionDepth >= 0 and b.checkTruncationLength()) {
            b.ctx.expansionTruncated = true;
            return true;
        }
        return false;
    }

    pub fn isExpandableType(b: *NodeBuilderImpl, t: types.TypeIndex, isAlias: bool) bool {
        if (isAlias) {
            return !b.c.isLibSymbolForHoverVerbosity(b.c.getAliasSymbol(t));
        }
        if (b.c.isLibTypeForHoverVerbosity(t)) {
            return false;
        }
        const objectFlags = b.c.getObjectFlags(t);
        const typeFlags = b.c.getTypeFlags(t);
        if (typeFlags & types.TypeFlags.EnumLike != 0 or
            objectFlags & types.ObjectFlags.Reference != 0 or
            objectFlags & types.ObjectFlags.ClassOrInterface != 0)
        {
            return true;
        }
        const symbol = b.c.getSymbol(t);
        if (objectFlags & types.ObjectFlags.Anonymous != 0 and symbol != 0 and
            b.c.getSymbolFlags(symbol) & (types.SymbolFlags.Class | types.SymbolFlags.Enum | types.SymbolFlags.ValueModule | types.SymbolFlags.Function | types.SymbolFlags.Method) != 0)
        {
            return true;
        }
        return false;
    }

    pub fn isTypeOnStack(b: *NodeBuilderImpl, t: types.TypeIndex) bool {
        if (b.ctx.typeStack.items.len == 0) return false;
        for (b.ctx.typeStack.items[0 .. b.ctx.typeStack.items.len - 1]) |stackType| {
            if (stackType == t) {
                return true;
            }
        }
        return false;
    }

    pub fn shouldExpandType(b: *NodeBuilderImpl, t: types.TypeIndex, isAlias: bool) bool {
        if (b.ctx.maxExpansionDepth < 0) {
            return false;
        }
        if (!b.isExpandableType(t, isAlias)) {
            return false;
        }
        if (b.isTypeOnStack(t)) {
            return false;
        }
        if (b.ctx.depth < @as(usize, @intCast(b.ctx.maxExpansionDepth))) {
            return true;
        }
        b.ctx.canIncreaseExpansionDepth = true;
        return false;
    }

    pub fn isActivelyExpanding(b: *NodeBuilderImpl) bool {
        return b.ctx.maxExpansionDepth > 0 and b.ctx.depth < @as(usize, @intCast(b.ctx.maxExpansionDepth));
    }

    pub fn checkTypeExpandability(b: *NodeBuilderImpl, t: types.TypeIndex) void {
        if (b.ctx.maxExpansionDepth < 0 or t == 0 or b.ctx.canIncreaseExpansionDepth) {
            return;
        }
        b.ctx.typeStack.append(b.c.allocator, t) catch unreachable;
        if (b.c.getAliasSymbol(t) != 0) {
            _ = b.shouldExpandType(t, true);
        }
        if (!b.ctx.canIncreaseExpansionDepth) {
            _ = b.shouldExpandType(t, false);
        }
        _ = b.ctx.typeStack.pop();
        if (b.ctx.canIncreaseExpansionDepth) {
            return;
        }
        if (b.c.getObjectFlags(t) & types.ObjectFlags.Reference != 0) {
            const args = b.c.getTypeArguments(t);
            for (args) |arg| {
                b.checkTypeExpandability(arg);
                if (b.ctx.canIncreaseExpansionDepth) {
                    return;
                }
            }
        }
    }

    pub fn indexInfoToIndexSignatureDeclaration(b: *NodeBuilderImpl, info: types.IndexInfoIndex) ast_gen.NodeIndex {
        return b.indexInfoToIndexSignatureDeclarationHelper(info, 0);
    }

    pub fn indexInfoToIndexSignatureDeclarationHelper(b: *NodeBuilderImpl, info: types.IndexInfoIndex, typeNodeArg: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const name = b.c.getNameFromIndexInfo(info);
        _ = b.typeToTypeNode(b.c.getIndexInfoKeyType(info));

        // indexingParameter := b.f.NewParameterDeclaration(nil, nil, b.newIdentifier(name, nil /*symbol*/), nil, indexerTypeNode, nil)

        var typeNode = typeNodeArg;
        if (typeNode == 0) {
            const valueType = b.c.getIndexInfoValueType(info);
            if (valueType == 0) {
                // typeNode = b.f.NewKeywordTypeNode(ast.KindAnyKeyword)
                typeNode = 0;
            } else {
                typeNode = b.typeToTypeNode(valueType);
            }
        }

        if (b.c.getIndexInfoValueType(info) == 0 and b.ctx.flags.AllowEmptyIndexInfoType == false) {
            b.ctx.encounteredError = true;
        }

        b.ctx.approximateLength += name.len + 4;

        if (b.c.getIndexInfoIsReadonly(info)) {
            b.ctx.approximateLength += 9;
            // modifiers = b.f.NewModifierList([]*ast.Node{b.f.NewModifier(ast.KindReadonlyKeyword)})
        }

        return 0; // b.f.NewIndexSignatureDeclaration(modifiers, b.f.NewNodeList([]*ast.Node{indexingParameter}), typeNode)
    }

    pub fn serializeReturnTypeForSignature(b: *NodeBuilderImpl, signatureDeclaration: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = b;
        _ = signatureDeclaration;
        return 0;
    }

    pub fn serializeTypeParametersForSignature(b: *NodeBuilderImpl, signatureDeclaration: ast_gen.NodeIndex) []const ast_gen.NodeIndex {
        _ = b;
        _ = signatureDeclaration;
        return &[_]ast_gen.NodeIndex{};
    }

    pub fn serializeTypeForDeclaration(b: *NodeBuilderImpl, declarationArg: ast_gen.NodeIndex, symbolArg: ast_gen.SymbolIndex) ast_gen.NodeIndex {
        var declaration = declarationArg;
        var symbol = symbolArg;

        if (declaration == 0) {
            if (symbol != 0) {
                declaration = b.c.getValueDeclarationOfSymbol(symbol);
                if (declaration == 0) {
                    declaration = b.c.getFirstDeclarationOfSymbol(symbol);
                }
            }
        }
        if (symbol == 0) {
            symbol = b.c.getSymbolOfDeclaration(declaration);
        }

        var t: types.TypeIndex = 0;
        if (b.ctx.enclosingSymbolTypes.get(symbol)) |st| {
            t = st;
        } else {
            if (b.c.getSymbolFlags(symbol) & types.SymbolFlags.Accessor != 0 and b.c.getNodeKind(declaration) == ast_gen.SyntaxKind.SetAccessor) {
                t = b.c.instantiateType(b.c.getWriteTypeOfSymbol(symbol), 0);
            } else if (symbol != 0 and (b.c.getSymbolFlags(symbol) & (types.SymbolFlags.TypeLiteral | types.SymbolFlags.Signature) == 0)) {
                // b.c.getTypeOfSymbol returns !u32, so catch it (if it's an error type)
                const typeOfSym = b.c.getTypeOfSymbol(symbol) catch b.c.errorTypeIndex orelse 0;
                t = b.c.instantiateType(b.c.getWidenedLiteralType(typeOfSym), 0);
            } else {
                t = b.c.errorTypeIndex orelse 0;
            }
        }

        const flagsState = b.saveRestoreFlags();
        defer b.restoreFlags(flagsState);

        if (b.c.getTypeFlags(t) & types.TypeFlags.UniqueESSymbol != 0 and b.c.getSymbolOfType(t) == symbol) {
            b.ctx.flags.AllowUniqueESSymbolType = true;
        }

        const result: ast_gen.NodeIndex = b.typeToTypeNode(t);
        if (result == 0) {
            return 0; // fallback to AnyKeyword
        }
        return result;
    }

    pub fn serializeTypeForExpression(b: *NodeBuilderImpl, expr: ast_gen.NodeIndex) ast_gen.NodeIndex {
        // !!! TODO: shim, add node reuse
        const t = b.c.instantiateType(b.c.getWidenedType(b.c.getRegularTypeOfExpression(expr)), 0);
        return b.typeToTypeNode(t);
    }

    pub fn signatureToSignatureDeclaration(b: *NodeBuilderImpl, signature: types.SignatureIndex, kind: ast_gen.SyntaxKind) ast_gen.NodeIndex {
        _ = b;
        _ = signature;
        _ = kind;
        return 0;
    }

    pub fn expandSymbolForHover(b: *NodeBuilderImpl, symbol: ast_gen.SymbolIndex, meaning: types.SymbolFlags) []const ast_gen.NodeIndex {
        _ = b;
        _ = symbol;
        _ = meaning;
        return &[_]ast_gen.NodeIndex{};
    }

    pub fn symbolToEntityName(b: *NodeBuilderImpl, symbol: ast_gen.SymbolIndex, meaning: types.SymbolFlags) ast_gen.NodeIndex {
        _ = b;
        _ = symbol;
        _ = meaning;
        return 0;
    }

    pub fn symbolToExpression(b: *NodeBuilderImpl, symbol: ast_gen.SymbolIndex, meaning: types.SymbolFlags) ast_gen.NodeIndex {
        _ = b;
        _ = symbol;
        _ = meaning;
        return 0;
    }

    pub fn symbolToNode(b: *NodeBuilderImpl, symbol: ast_gen.SymbolIndex, meaning: types.SymbolFlags) ast_gen.NodeIndex {
        _ = b;
        _ = symbol;
        _ = meaning;
        return 0;
    }

    pub fn symbolToParameterDeclaration(b: *NodeBuilderImpl, symbol: ast_gen.SymbolIndex) ast_gen.NodeIndex {
        _ = b;
        _ = symbol;
        return 0;
    }

    pub fn symbolToTypeParameterDeclarations(b: *NodeBuilderImpl, symbol: ast_gen.SymbolIndex) []const ast_gen.NodeIndex {
        _ = b;
        _ = symbol;
        return &[_]ast_gen.NodeIndex{};
    }

    pub fn typeParameterToDeclaration(b: *NodeBuilderImpl, parameter: types.TypeIndex) ast_gen.NodeIndex {
        _ = b;
        _ = parameter;
        return 0;
    }

    pub fn typePredicateToTypePredicateNode(b: *NodeBuilderImpl, predicate: types.TypePredicateIndex) ast_gen.NodeIndex {
        _ = b;
        _ = predicate;
        return 0;
    }

    pub fn typeToTypeNode(b: *NodeBuilderImpl, typ: types.TypeIndex) ast_gen.NodeIndex {
        _ = b;
        _ = typ;
        return 0;
    }

    pub fn tryJSTypeNodeToTypeNode(b: *NodeBuilderImpl, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = b;
        _ = node;
        return 0;
    }
};

pub const FlagsState = struct {
    flags: Flags,
    internalFlags: InternalFlags,
    depth: usize,
};

pub const defaultMaximumTruncationLength = 160;
pub const noTruncationMaximumTruncationLength = 1_000_000;
