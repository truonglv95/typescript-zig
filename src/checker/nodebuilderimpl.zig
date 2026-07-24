const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const sym_mod = @import("../ast/symbol.zig");
const types = @import("types.zig");
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const factory_pkg = @import("../printer/factory.zig");
pub const nodecopy = @import("nodecopy.zig");
pub const nodebuilderscopes = @import("nodebuilderscopes.zig");
const scanner = @import("../scanner/scanner.zig");

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
        const type_symbol = b.c.getSymbolOfType(t);
        if (objectFlags & types.ObjectFlags.Anonymous != 0 and type_symbol != 0 and
            b.c.getSymbolFlags(type_symbol) & (sym_mod.SymbolFlags.Class | sym_mod.SymbolFlags.Enum | sym_mod.SymbolFlags.ValueModule | sym_mod.SymbolFlags.Function | sym_mod.SymbolFlags.Method) != 0)
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

    fn synthesizedFlags() u32 {
        return ast_utils.NodeFlags.Synthesized;
    }

    fn factory(b: *NodeBuilderImpl) factory_pkg.NodeFactory {
        var f = factory_pkg.NodeFactory.init(b.c.allocator, b.c.binder.ast);
        // Strings allocated by the factory (e.g. by `newIdentifier`) are
        // stored in AST nodes whose lifetime is tied to the binder/checker.
        // Track those allocations on the checker so they are freed when the
        // checker is destroyed — the factory itself is short-lived.
        f.ownedStringsTracker = &b.c.ownedStrings;
        return f;
    }

    fn createKeywordTypeNode(b: *NodeBuilderImpl, kind: ast_gen.NodeData) ast_gen.NodeIndex {
        return b.c.binder.ast.pushNode(kind) catch 0;
    }

    fn createLiteralTypeNode(b: *NodeBuilderImpl, literal: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return b.c.binder.ast.pushNode(.{
            .LiteralType = .{
                .Flags = synthesizedFlags(),
                .Literal = literal,
            },
        }) catch 0;
    }

    fn createPropertyNameNode(b: *NodeBuilderImpl, name: []const u8) ast_gen.NodeIndex {
        var f = factory(b);
        return f.newIdentifier(name);
    }

    fn primitiveTypeToTypeNode(b: *NodeBuilderImpl, typ: types.TypeIndex) ?ast_gen.NodeIndex {
        const typeData = &b.c.typesList.items[typ];
        const flags = typeData.flags;
        if (flags & types.TypeFlags.String != 0) return createKeywordTypeNode(b, .StringKeyword);
        if (flags & types.TypeFlags.Number != 0) return createKeywordTypeNode(b, .NumberKeyword);
        if (flags & types.TypeFlags.Boolean != 0) return createKeywordTypeNode(b, .BooleanKeyword);
        if (flags & types.TypeFlags.Void != 0) return createKeywordTypeNode(b, .VoidKeyword);
        if (flags & types.TypeFlags.Undefined != 0) return createKeywordTypeNode(b, .UndefinedKeyword);
        if (flags & types.TypeFlags.Null != 0) return createKeywordTypeNode(b, .NullKeyword);
        if (flags & types.TypeFlags.Any != 0) return createKeywordTypeNode(b, .AnyKeyword);
        if (flags & types.TypeFlags.Unknown != 0) return createKeywordTypeNode(b, .UnknownKeyword);
        if (flags & types.TypeFlags.Never != 0) return createKeywordTypeNode(b, .NeverKeyword);
        if (flags & types.TypeFlags.BigInt != 0) return createKeywordTypeNode(b, .BigIntKeyword);
        if (flags & types.TypeFlags.StringLiteral != 0) {
            var f = factory(b);
            const literal = f.newStringLiteral(typeData.data.StringLiteral.text, false);
            return createLiteralTypeNode(b, literal);
        }
        if (flags & types.TypeFlags.NumberLiteral != 0) {
            // IMPORTANT: do not free this string — it's stored in the AST node
            // and used later by the printer. Track it in checker.ownedStrings
            // so it's freed when the checker is deinitialized.
            const text = std.fmt.allocPrint(b.c.allocator, "{d}", .{typeData.data.NumberLiteral.value}) catch return null;
            b.c.ownedStrings.append(b.c.allocator, text) catch {};
            var f = factory(b);
            const literal = f.newNumericLiteral(text, 0);
            return createLiteralTypeNode(b, literal);
        }
        if (flags & types.TypeFlags.BooleanLiteral != 0) {
            var f = factory(b);
            const literal = if (typeData.data.BooleanLiteral.value) f.newTrueExpression() else f.newFalseExpression();
            return createLiteralTypeNode(b, literal);
        }
        if (flags & types.TypeFlags.TemplateLiteral != 0) {
            return createTemplateLiteralTypeNode(b, typ);
        }
        return null;
    }

    /// Build a TemplateLiteralType AST node from a TemplateLiteral type.
    /// The type has `texts` (head + tail strings) and a slice of types (one
    /// per span). The resulting AST node has Head (a NoSubstitutionTemplateLiteral
    /// or a literal token with the head text) and TemplateSpans (a list of
    /// TemplateLiteralTypeSpan nodes).
    fn createTemplateLiteralTypeNode(b: *NodeBuilderImpl, t: types.TypeIndex) ast_gen.NodeIndex {
        const typeData = &b.c.typesList.items[t];
        if (typeData.data != .TemplateLiteral) return 0;
        const tl = typeData.data.TemplateLiteral;
        if (tl.texts.len == 0) return 0;

        // Create the head as a NoSubstitutionTemplateLiteral node.
        const head_text = tl.texts[0];
        const head_node = b.c.binder.ast.pushNode(.{
            .NoSubstitutionTemplateLiteral = .{
                .Flags = synthesizedFlags(),
                .Text = head_text,
                .TokenFlags = 0,
                .RawText = head_text,
                .TemplateFlags = 0,
                .Symbol = 0,
            },
        }) catch return 0;

        // Build each span: type node + literal text (the next text segment).
        var span_nodes = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer span_nodes.deinit(b.c.allocator);
        // Template literal types are stored in tupleTypesPool (see
        // newTemplateLiteralType in checker.zig which appends to
        // tupleTypesPool).
        const types_pool = b.c.tupleTypesPool.items;
        const types_start = tl.typesStart;
        const types_len = tl.typesLen;
        var i: usize = 0;
        while (i < types_len and i + 1 < tl.texts.len) : (i += 1) {
            const type_idx = if (types_start + i < types_pool.len) types_pool[types_start + i] else 0;
            const type_node = if (type_idx != 0) b.typeToTypeNode(type_idx) else createKeywordTypeNode(b, .AnyKeyword);
            const tail_text = tl.texts[i + 1];
            const literal_node = b.c.binder.ast.pushNode(.{
                .NoSubstitutionTemplateLiteral = .{
                    .Flags = synthesizedFlags(),
                    .Text = tail_text,
                    .TokenFlags = 0,
                    .RawText = tail_text,
                    .TemplateFlags = 0,
                    .Symbol = 0,
                },
            }) catch return 0;
            const span_node = b.c.binder.ast.pushNode(.{
                .TemplateLiteralTypeSpan = .{
                    .Flags = synthesizedFlags(),
                    .Type = type_node,
                    .Literal = literal_node,
                },
            }) catch return 0;
            span_nodes.append(b.c.allocator, span_node) catch return 0;
        }
        const spans_list = b.c.binder.ast.pushNodeList(span_nodes.items) catch return 0;
        return b.c.binder.ast.pushNode(.{
            .TemplateLiteralType = .{
                .Flags = synthesizedFlags(),
                .Head = head_node,
                .TemplateSpans = spans_list,
            },
        }) catch 0;
    }

    fn symbolToTypeReferenceNode(b: *NodeBuilderImpl, sym: ast_gen.SymbolIndex, typeArguments: ?ast_gen.NodeIndex) ast_gen.NodeIndex {
        if (sym == 0) return 0;
        const nameNode = createPropertyNameNode(b, b.c.getSymbolName(sym));
        return b.c.binder.ast.pushNode(.{
            .TypeReference = .{
                .Flags = synthesizedFlags(),
                .TypeName = nameNode,
                .TypeArguments = typeArguments,
            },
        }) catch 0;
    }

    fn createTypeNodeFromObjectType(b: *NodeBuilderImpl, t: types.TypeIndex) ast_gen.NodeIndex {
        // Recursion guard: limit depth to prevent infinite recursion on
        // self-referential object types like `var a = { f: a }`.
        if (b.c.serializationLevel >= 20) return 0;
        b.c.serializationLevel += 1;
        defer b.c.serializationLevel -= 1;
        // Mark this type as visited for cycle detection.
        b.ctx.visitedTypes.put(b.c.allocator, t, {}) catch {};
        defer _ = b.ctx.visitedTypes.remove(t);
        const members = b.c.resolveStructuredTypeMembers(t);
        const properties = b.c.resolvedPropertiesPool.items[members.propertiesStart .. members.propertiesStart + members.propertiesLen];
        const index_infos = b.c.getIndexInfosOfType(t);

        var member_nodes = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer member_nodes.deinit(b.c.allocator);

        // Render properties as PropertySignature nodes.
        for (properties) |prop| {
            if (!b.c.symbolIsValue(prop)) continue;
            const prop_type = b.c.getTypeOfSymbol(prop) catch 0;
            const type_node = if (prop_type != 0) b.typeToTypeNode(prop_type) else createKeywordTypeNode(b, .AnyKeyword);
            const optional = (b.c.getSymbolFlags(prop) & sym_mod.SymbolFlags.Optional) != 0;
            // Detect readonly: either the symbol has CheckFlags.Readonly set
            // (e.g., a property with only a getter), or it has the `readonly`
            // modifier on its declaration, or it's an accessor with only a
            // getter.
            const is_readonly = b.c.isReadonlySymbol(prop) or
                blk: {
                    const sym_obj = b.c.binder.symbols.items[prop];
                    for (sym_obj.Declarations.items) |decl| {
                        if (decl != 0) {
                            const decl_data = b.c.binder.ast.getNode(decl);
                            const mods: u32 = switch (decl_data) {
                                .PropertySignature => |n| n.modifierFlags,
                                .PropertyDeclaration => |n| n.modifierFlags,
                                else => 0,
                            };
                            if ((mods & @import("../ast/ast_utils.zig").ModifierFlags.Readonly) != 0) break :blk true;
                        }
                    }
                    break :blk false;
                };
            const name_node = createPropertyNameNode(b, b.c.getSymbolName(prop));
            var f = factory(b);
            const readonly_token = if (is_readonly) f.newToken(.{ .ReadonlyKeyword = {} }) else null;
            var mods_list: ?u32 = null;
            if (readonly_token != null) {
                const mods_arr = [_]u32{readonly_token.?};
                mods_list = b.c.binder.ast.pushNodeList(&mods_arr) catch 0;
            }
            const member = b.c.binder.ast.pushNode(.{
                .PropertySignature = .{
                    .Flags = synthesizedFlags(),
                    .Symbol = 0,
                    .modifiers = mods_list,
                    .modifierFlags = if (is_readonly) @import("../ast/ast_utils.zig").ModifierFlags.Readonly else 0,
                    .name = name_node,
                    .PostfixToken = if (optional) f.newToken(.{ .QuestionToken = {} }) else null,
                    .Type = type_node,
                    .Initializer = null,
                },
            }) catch return 0;
            member_nodes.append(b.c.allocator, member) catch return 0;
        }

        // Render call signatures as CallSignature nodes.
        // For an object type like `{ (): string }`, this produces `(): string`
        // which the printer renders as `() => string`.
        const call_sigs = b.c.resolvedSignaturesPool.items[members.callSignaturesStart .. members.callSignaturesStart + members.callSignaturesLen];
        for (call_sigs) |sig_idx| {
            if (sig_idx == 0 or sig_idx >= b.c.signatures.items.len) continue;
            const sig = &b.c.signatures.items[sig_idx];
            const params_slice = b.c.signatureParameters.items[sig.parametersStart .. sig.parametersStart + sig.parametersLen];
            // Build parameter nodes.
            var param_nodes = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
            defer param_nodes.deinit(b.c.allocator);
            for (params_slice) |param_sym| {
                if (param_sym == 0) continue;
                const param_type = b.c.getTypeOfSymbol(param_sym) catch 0;
                const param_type_node = if (param_type != 0) b.typeToTypeNode(param_type) else createKeywordTypeNode(b, .AnyKeyword);
                const param_name = if (param_sym < b.c.binder.symbols.items.len) b.c.binder.symbols.items[param_sym].Name else "arg";
                const name_node = createPropertyNameNode(b, param_name);
                const param = b.c.binder.ast.pushNode(.{
                    .Parameter = .{
                        .Flags = synthesizedFlags(),
                        .Symbol = 0,
                        .modifiers = null,
                        .modifierFlags = 0,
                        .DotDotDotToken = null,
                        .name = name_node,
                        .QuestionToken = null,
                        .Type = param_type_node,
                        .Initializer = null,
                    },
                }) catch return 0;
                param_nodes.append(b.c.allocator, param) catch return 0;
            }
            const params_list = b.c.binder.ast.pushNodeList(param_nodes.items) catch return 0;
            // Build return type node.
            const ret_type = b.c.getReturnTypeOfSignature(sig);
            const ret_type_node = if (ret_type != 0) b.typeToTypeNode(ret_type) else createKeywordTypeNode(b, .VoidKeyword);
            const call_sig = b.c.binder.ast.pushNode(.{
                .CallSignature = .{
                    .Flags = synthesizedFlags(),
                    .Symbol = 0,
                    .TypeParameters = null,
                    .Parameters = params_list,
                    .Type = ret_type_node,
                    .FullSignature = null,
                },
            }) catch return 0;
            member_nodes.append(b.c.allocator, call_sig) catch return 0;
        }

        // Render construct signatures as ConstructSignature nodes.
        const ctor_sigs = b.c.resolvedSignaturesPool.items[members.constructSignaturesStart .. members.constructSignaturesStart + members.constructSignaturesLen];
        for (ctor_sigs) |sig_idx| {
            if (sig_idx == 0 or sig_idx >= b.c.signatures.items.len) continue;
            const sig = &b.c.signatures.items[sig_idx];
            const params_slice = b.c.signatureParameters.items[sig.parametersStart .. sig.parametersStart + sig.parametersLen];
            var param_nodes = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
            defer param_nodes.deinit(b.c.allocator);
            for (params_slice) |param_sym| {
                if (param_sym == 0) continue;
                const param_type = b.c.getTypeOfSymbol(param_sym) catch 0;
                const param_type_node = if (param_type != 0) b.typeToTypeNode(param_type) else createKeywordTypeNode(b, .AnyKeyword);
                const param_name = if (param_sym < b.c.binder.symbols.items.len) b.c.binder.symbols.items[param_sym].Name else "arg";
                const name_node = createPropertyNameNode(b, param_name);
                const param = b.c.binder.ast.pushNode(.{
                    .Parameter = .{
                        .Flags = synthesizedFlags(),
                        .Symbol = 0,
                        .modifiers = null,
                        .modifierFlags = 0,
                        .DotDotDotToken = null,
                        .name = name_node,
                        .QuestionToken = null,
                        .Type = param_type_node,
                        .Initializer = null,
                    },
                }) catch return 0;
                param_nodes.append(b.c.allocator, param) catch return 0;
            }
            const params_list = b.c.binder.ast.pushNodeList(param_nodes.items) catch return 0;
            const ret_type = b.c.getReturnTypeOfSignature(sig);
            const ret_type_node = if (ret_type != 0) b.typeToTypeNode(ret_type) else createKeywordTypeNode(b, .AnyKeyword);
            const ctor_sig = b.c.binder.ast.pushNode(.{
                .ConstructSignature = .{
                    .Flags = synthesizedFlags(),
                    .Symbol = 0,
                    .TypeParameters = null,
                    .Parameters = params_list,
                    .Type = ret_type_node,
                    .FullSignature = null,
                },
            }) catch return 0;
            member_nodes.append(b.c.allocator, ctor_sig) catch return 0;
        }

        // Render index signatures as IndexSignature nodes.
        // Index infos are stored in resolvedIndexInfosPool; the actual data
        // (keyType, valueType, etc.) is accessed via the IndexInfo struct.
        for (index_infos) |info| {
            // Build a Parameter node for the key: [name: keyType]
            const key_type_node = if (info.keyType != 0) b.typeToTypeNode(info.keyType) else createKeywordTypeNode(b, .StringKeyword);
            const value_type_node = if (info.valueType != 0) b.typeToTypeNode(info.valueType) else createKeywordTypeNode(b, .AnyKeyword);
            // Build the Parameter AST node: name: x, Type: keyType, dotDotDot: null, question: null, initializer: null.
            const key_name_node = createPropertyNameNode(b, "x");
            const key_param = b.c.binder.ast.pushNode(.{
                .Parameter = .{
                    .Flags = synthesizedFlags(),
                    .Symbol = 0,
                    .modifiers = null,
                    .modifierFlags = 0,
                    .DotDotDotToken = null,
                    .name = key_name_node,
                    .QuestionToken = null,
                    .Type = key_type_node,
                    .Initializer = null,
                },
            }) catch return 0;
            const params_list = b.c.binder.ast.pushNodeList(&.{key_param}) catch return 0;
            // Build the IndexSignature node with Parameters list and Type = value_type_node.
            const idx_sig = b.c.binder.ast.pushNode(.{
                .IndexSignature = .{
                    .Flags = synthesizedFlags(),
                    .Symbol = 0,
                    .modifiers = null,
                    .modifierFlags = if (info.isReadonly) @import("../ast/ast_utils.zig").ModifierFlags.Readonly else 0,
                    .TypeParameters = null,
                    .Parameters = params_list,
                    .Type = value_type_node,
                    .FullSignature = null,
                },
            }) catch return 0;
            member_nodes.append(b.c.allocator, idx_sig) catch return 0;
        }

        const members_list = b.c.binder.ast.pushNodeList(member_nodes.items) catch return 0;
        return b.c.binder.ast.pushNode(.{
            .TypeLiteral = .{
                .Flags = synthesizedFlags(),
                .Symbol = 0,
                .Members = members_list,
            },
        }) catch 0;
    }

    fn unionOrIntersectionTypeToTypeNode(b: *NodeBuilderImpl, typ: types.TypeIndex, isUnion: bool) ast_gen.NodeIndex {
        const constituents = if (isUnion) b.c.getTypesFromUnion(typ) else b.c.getTypesFromIntersection(typ);
        if (constituents.len == 0) return 0;
        if (constituents.len == 1) return b.typeToTypeNode(constituents[0]);

        var type_nodes = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer type_nodes.deinit(b.c.allocator);
        for (constituents) |constituent| {
            const type_node = b.typeToTypeNode(constituent);
            if (type_node == 0) return 0;
            type_nodes.append(b.c.allocator, type_node) catch return 0;
        }
        const list = b.c.binder.ast.pushNodeList(type_nodes.items) catch return 0;
        return b.c.binder.ast.pushNode(if (isUnion)
            .{ .UnionType = .{ .Flags = synthesizedFlags(), .Types = list } }
        else
            .{ .IntersectionType = .{ .Flags = synthesizedFlags(), .Types = list } }) catch 0;
    }

    pub fn typeToTypeNode(b: *NodeBuilderImpl, typ: types.TypeIndex) ast_gen.NodeIndex {
        if (typ == 0 or typ >= b.c.typesList.items.len) return 0;
        // Cycle detection: if we've already visited this type during
        // the current typeToString call, return anyType to break
        // infinite recursion on self-referential types like
        // `var a = { f: a }`.
        if (b.ctx.visitedTypes.get(typ) != null) {
            return createKeywordTypeNode(b, .AnyKeyword);
        }
        if (primitiveTypeToTypeNode(b, typ)) |node| return node;

        const typeData = &b.c.typesList.items[typ];
        const typeFlags = typeData.flags;
        const objectFlags = typeData.objectFlags;

        // Function types: return 0 so TypeToStringEx falls through to its
        // primitive Function fallback which renders (params) => retType.
        // Only do this for anonymous function expressions and arrow functions
        // (not named FunctionDeclarations which should be rendered as named types).
        if (typeData.data == .Function) {
            const fn_data = typeData.data.Function;
            if (fn_data.declarationNode != 0 and fn_data.declarationNode < b.c.binder.ast.nodes.len) {
                const decl_kind = b.c.binder.ast.getNodeKind(fn_data.declarationNode);
                // ArrowFunction and anonymous FunctionExpression (no name)
                // should use the (params) => retType rendering.
                if (decl_kind == .ArrowFunction) {
                    return 0;
                }
                if (decl_kind == .FunctionExpression) {
                    // Check if the FunctionExpression has a name — if it does,
                    // it's a named function expression and should keep its type
                    // literal rendering.
                    const fe = b.c.binder.ast.getNode(fn_data.declarationNode).FunctionExpression;
                    if (fe.name == null or fe.name.? == 0) {
                        return 0;
                    }
                }
                // FunctionType and ConstructorType nodes should also use
                // the (params) => retType rendering.
                if (decl_kind == .FunctionType or decl_kind == .ConstructorType) {
                    return 0;
                }
            }
        }

        if (typeFlags & types.TypeFlags.Union != 0) {
            return unionOrIntersectionTypeToTypeNode(b, typ, true);
        }
        if (typeFlags & types.TypeFlags.Intersection != 0) {
            return unionOrIntersectionTypeToTypeNode(b, typ, false);
        }
        if (typeFlags & types.TypeFlags.Object != 0) {
            if (objectFlags & types.ObjectFlags.Reference != 0) {
                const target = b.c.getTargetType(typ);
                if (b.c.isArrayType(typ)) {
                    const element_type = if (typeData.data == .Array)
                        typeData.data.Array.elementType
                    else
                        b.c.getTypeArguments(typ)[0];
                    const element_node = b.typeToTypeNode(element_type);
                    if (element_node == 0) return 0;
                    return b.c.binder.ast.pushNode(.{
                        .ArrayType = .{
                            .Flags = synthesizedFlags(),
                            .ElementType = element_node,
                        },
                    }) catch 0;
                }
                if (objectFlags & types.ObjectFlags.Tuple != 0) {
                    const tuple = typeData.data.Tuple;
                    const tuple_types = b.c.tupleTypesPool.items[tuple.typesStart .. tuple.typesStart + tuple.typesLen];
                    const tuple_infos = b.c.tupleElementInfos.items[tuple.elementInfosStart .. tuple.elementInfosStart + tuple.typesLen];
                    var element_nodes = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
                    defer element_nodes.deinit(b.c.allocator);
                    for (tuple_types, 0..) |element_type, i| {
                        var element_node = b.typeToTypeNode(element_type);
                        if (element_node == 0) return 0;
                        // If this tuple element has a label (NamedTupleMember),
                        // wrap it in a NamedTupleMember node so the printer
                        // renders `label: type` instead of just `type`.
                        if (i < tuple_infos.len) {
                            if (tuple_infos[i].labeledDeclaration) |ntm_node| {
                                if (ntm_node != 0 and b.c.binder.ast.getNodeKind(ntm_node) == .NamedTupleMember) {
                                    const orig_ntm = b.c.binder.ast.getNode(ntm_node).NamedTupleMember;
                                    // Reuse the original label name and dotdotdot/question tokens.
                                    element_node = b.c.binder.ast.pushNode(.{
                                        .NamedTupleMember = .{
                                            .Flags = synthesizedFlags(),
                                            .Symbol = 0,
                                            .DotDotDotToken = orig_ntm.DotDotDotToken,
                                            .name = orig_ntm.name,
                                            .QuestionToken = orig_ntm.QuestionToken,
                                            .Type = element_node,
                                        },
                                    }) catch element_node;
                                }
                            }
                        }
                        element_nodes.append(b.c.allocator, element_node) catch return 0;
                    }
                    const list = b.c.binder.ast.pushNodeList(element_nodes.items) catch return 0;
                    return b.c.binder.ast.pushNode(.{
                        .TupleType = .{
                            .Flags = synthesizedFlags(),
                            .Elements = list,
                        },
                    }) catch 0;
                }
                const sym = b.c.getSymbolOfType(target);
                const type_args = b.c.getTypeArguments(typ);
                const type_args_node = if (type_args.len > 0) blk: {
                    var arg_nodes = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
                    defer arg_nodes.deinit(b.c.allocator);
                    for (type_args) |arg| {
                        const arg_node = b.typeToTypeNode(arg);
                        if (arg_node == 0) return 0;
                        arg_nodes.append(b.c.allocator, arg_node) catch return 0;
                    }
                    break :blk b.c.binder.ast.pushNodeList(arg_nodes.items) catch return 0;
                } else null;
                return symbolToTypeReferenceNode(b, sym, type_args_node);
            }
            if (objectFlags & (types.ObjectFlags.Anonymous | types.ObjectFlags.Mapped) != 0) {
                // For anonymous object types with a symbol that has TypeLiteral
                // or ObjectLiteral flag, return 0 so TypeToStringEx falls
                // through to the custom rendering code that supports multiline
                // format and proper property type widening.
                // Only do this at the top level (serializationLevel == 0) to
                // prevent infinite recursion on self-referential types.
                if (b.c.serializationLevel == 0) {
                    if (typeData.symbol) |sym| {
                        if (sym != 0 and sym < b.c.binder.symbols.items.len) {
                            const sym_flags = b.c.binder.symbols.items[sym].Flags;
                            if ((sym_flags & (sym_mod.SymbolFlags.TypeLiteral | sym_mod.SymbolFlags.ObjectLiteral)) != 0) {
                                return 0;
                            }
                        }
                    }
                }
                return createTypeNodeFromObjectType(b, typ);
            }
            if (objectFlags & types.ObjectFlags.ClassOrInterface != 0) {
                return symbolToTypeReferenceNode(b, b.c.getSymbolOfType(typ), null);
            }
        }
        if (typeData.data == .Array) {
            const element_node = b.typeToTypeNode(typeData.data.Array.elementType);
            if (element_node == 0) return 0;
            return b.c.binder.ast.pushNode(.{
                .ArrayType = .{
                    .Flags = synthesizedFlags(),
                    .ElementType = element_node,
                },
            }) catch 0;
        }
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

pub fn newNodeBuilderImpl(ch: *anyopaque, e: *anyopaque, idToSymbol: *anyopaque) *anyopaque {
    _ = ch;
    _ = e;
    _ = idToSymbol;
    return undefined;
}

pub fn appendReferenceToType(b: *NodeBuilderImpl, root: *anyopaque, ref: *anyopaque) *anyopaque {
    _ = b;
    _ = root;
    _ = ref;
    return undefined;
}

pub fn getAccessStack(ref: *anyopaque) *anyopaque {
    _ = ref;
    return undefined;
}

pub fn isClassInstanceSide(c: *anyopaque, t: *anyopaque) bool {
    _ = c;
    _ = t;
    return false;
}

pub fn createElidedInformationPlaceholder(b: *NodeBuilderImpl) *anyopaque {
    _ = b;
    return undefined;
}

pub fn mapToTypeNodes(b: *NodeBuilderImpl, list: *anyopaque, isBareList: *anyopaque) *anyopaque {
    _ = b;
    _ = list;
    _ = isBareList;
    return undefined;
}

pub fn serializeTypeName(b: *NodeBuilderImpl, node: *anyopaque, isTypeOf: *anyopaque, typeArguments: *anyopaque) *anyopaque {
    _ = b;
    _ = node;
    _ = isTypeOf;
    _ = typeArguments;
    return undefined;
}

pub fn isIdentifierTypeReference(c: *Checker, nodeIndex: ast_gen.NodeIndex) bool {
    const node = c.binder.ast.nodes.get(nodeIndex);
    if (node != .TypeReference) return false;
    const typeName = node.TypeReference.TypeName;
    return c.binder.ast.nodes.get(typeName) == .Identifier;
}

pub fn typesAreSameReference(arg0: *anyopaque, b: *anyopaque) bool {
    _ = arg0;
    _ = b;
    return false;
}

pub fn setCommentRange(b: *NodeBuilderImpl, node: *anyopaque, range_: *anyopaque) void {
    _ = b;
    _ = node;
    _ = range_;
}

pub fn typeNodeIsEquivalentToType(b: *NodeBuilderImpl, annotatedDeclaration: *anyopaque, t: *anyopaque, typeFromTypeNode: *anyopaque) bool {
    _ = b;
    _ = annotatedDeclaration;
    _ = t;
    _ = typeFromTypeNode;
    return false;
}

pub fn existingTypeNodeIsNotReferenceOrIsReferenceWithCompatibleTypeArgumentCount(b: *NodeBuilderImpl, existing: *anyopaque, t: *anyopaque) bool {
    _ = b;
    _ = existing;
    _ = t;
    return false;
}

pub fn tryReuseExistingNonParameterTypeNode(b: *NodeBuilderImpl, existing: *anyopaque, t: *anyopaque, host: *anyopaque, annotationType: *anyopaque) *anyopaque {
    _ = b;
    _ = existing;
    _ = t;
    _ = host;
    _ = annotationType;
    return undefined;
}

pub fn getResolvedTypeWithoutAbstractConstructSignatures(b: *NodeBuilderImpl, t: *anyopaque) *anyopaque {
    _ = b;
    _ = t;
    return undefined;
}

pub fn symbolToName(b: *NodeBuilderImpl, symbol_: *anyopaque, meaning: *anyopaque, expectsIdentifier: *anyopaque) *anyopaque {
    _ = b;
    _ = symbol_;
    _ = meaning;
    _ = expectsIdentifier;
    return undefined;
}

pub fn createEntityNameFromSymbolChain(b: *NodeBuilderImpl, chain: *anyopaque, index: *anyopaque) *anyopaque {
    _ = b;
    _ = chain;
    _ = index;
    return undefined;
}

pub fn symbolToEntityNameNode(b: *NodeBuilderImpl, symbol_: *anyopaque) *anyopaque {
    _ = b;
    _ = symbol_;
    return undefined;
}

pub fn symbolToTypeNode(b: *NodeBuilderImpl, symbol_: *anyopaque, mask: *anyopaque, typeArguments: *anyopaque) *anyopaque {
    _ = b;
    _ = symbol_;
    _ = mask;
    _ = typeArguments;
    return undefined;
}

pub fn getTopmostIndexedAccessType(node: *anyopaque) *anyopaque {
    _ = node;
    return undefined;
}

pub fn createAccessFromSymbolChain(b: *NodeBuilderImpl, chain: *anyopaque, index: *anyopaque, stopper: *anyopaque, overrideTypeArguments: *anyopaque) *anyopaque {
    _ = b;
    _ = chain;
    _ = index;
    _ = stopper;
    _ = overrideTypeArguments;
    return undefined;
}

pub fn createExpressionFromSymbolChain(b: *NodeBuilderImpl, chain: *anyopaque, index: *anyopaque) *anyopaque {
    _ = b;
    _ = chain;
    _ = index;
    return undefined;
}

pub fn canUsePropertyAccess(name_: []const u8) bool {
    if (name_.len == 0) return false;
    if (std.mem.startsWith(u8, name_, "#")) {
        return name_.len > 1 and scanner.isIdentifierText(name_[1..], .Standard);
    }
    return scanner.isIdentifierText(name_, .Standard);
}

pub fn startsWithSingleOrDoubleQuote(str: []const u8) bool {
    return std.mem.startsWith(u8, str, "'") or std.mem.startsWith(u8, str, "\"");
}

pub fn startsWithSquareBracket(str: []const u8) bool {
    return std.mem.startsWith(u8, str, "[");
}

pub fn isDefaultBindingContext(c: *Checker, location: ast_gen.NodeIndex) bool {
    const node = c.binder.ast.nodes.get(location);
    return node == .SourceFile or ast_utils.isAmbientModule(&c.binder.ast, location);
}

pub fn getNameOfSymbolFromNameType(b: *NodeBuilderImpl, symbol_: *anyopaque) *anyopaque {
    _ = b;
    _ = symbol_;
    return undefined;
}

pub fn getNameOfSymbolAsWritten(b: *NodeBuilderImpl, symbol_: *anyopaque) *anyopaque {
    _ = b;
    _ = symbol_;
    return undefined;
}

pub fn getTypeParametersOfClassOrInterface(b: *NodeBuilderImpl, symbol_: *anyopaque) *anyopaque {
    _ = b;
    _ = symbol_;
    return undefined;
}

pub fn lookupTypeParameterNodes(b: *NodeBuilderImpl, chain: *anyopaque, index: *anyopaque) *anyopaque {
    _ = b;
    _ = chain;
    _ = index;
    return undefined;
}

pub fn lookupSymbolChain(b: *NodeBuilderImpl, symbol_: *anyopaque, meaning: *anyopaque, yieldModuleSymbol: *anyopaque) *anyopaque {
    _ = b;
    _ = symbol_;
    _ = meaning;
    _ = yieldModuleSymbol;
    return undefined;
}

pub fn lookupSymbolChainWorker(b: *NodeBuilderImpl, symbol_: *anyopaque, meaning: *anyopaque, yieldModuleSymbol: *anyopaque) *anyopaque {
    _ = b;
    _ = symbol_;
    _ = meaning;
    _ = yieldModuleSymbol;
    return undefined;
}

pub fn getSymbolChain(b: *NodeBuilderImpl, symbol_: *anyopaque, meaning: *anyopaque, endOfChain: *anyopaque, yieldModuleSymbol: *anyopaque) *anyopaque {
    _ = b;
    _ = symbol_;
    _ = meaning;
    _ = endOfChain;
    _ = yieldModuleSymbol;
    return undefined;
}

pub fn sortByBestName(a: *anyopaque, b: *anyopaque) i32 {
    _ = a;
    _ = b;
    return 0;
}

pub fn canHaveModuleSpecifier(node: *anyopaque) bool {
    _ = node;
    return false;
}

pub fn tryGetModuleSpecifierFromDeclaration(node: *anyopaque) *anyopaque {
    _ = node;
    return undefined;
}

pub fn tryGetModuleSpecifierFromDeclarationWorker(node: *anyopaque) *anyopaque {
    _ = node;
    return undefined;
}

pub fn getSpecifierForModuleSymbol(b: *NodeBuilderImpl, symbol_: *anyopaque, overrideImportMode: *anyopaque) *anyopaque {
    _ = b;
    _ = symbol_;
    _ = overrideImportMode;
    return undefined;
}

pub fn typeParameterToDeclarationWithConstraint(b: *NodeBuilderImpl, typeParameter: *anyopaque, constraintNode: *anyopaque) *anyopaque {
    _ = b;
    _ = typeParameter;
    _ = constraintNode;
    return undefined;
}

pub fn setTextRange(b: *NodeBuilderImpl, range_: *anyopaque, location: *anyopaque) *anyopaque {
    _ = b;
    _ = range_;
    _ = location;
    return undefined;
}

pub fn typeParameterShadowsOtherTypeParameterInScope(b: *NodeBuilderImpl, name_: *anyopaque, typeParameter: *anyopaque) bool {
    _ = b;
    _ = name_;
    _ = typeParameter;
    return false;
}

pub fn typeParameterToName(b: *NodeBuilderImpl, typeParameter: *anyopaque) *anyopaque {
    _ = b;
    _ = typeParameter;
    return undefined;
}

pub fn isMappedTypeHomomorphic(b: *NodeBuilderImpl, mapped: types.TypeIndex) bool {
    const t = &b.c.typesList.items[mapped];
    if (t.objectFlags & types.ObjectFlags.Mapped == 0) return false;
    if (t.objectFlags & types.ObjectFlags.Instantiated != 0) return false;
    if (t.data != .Mapped) return false;
    const declNode = t.data.Mapped.declaration;
    const node = b.c.binder.ast.nodes.get(declNode);
    if (node != .MappedType) return false;
    return node.MappedType.NameType == null;
}

pub fn isHomomorphicMappedTypeWithNonHomomorphicInstantiation(b: *NodeBuilderImpl, mapped: types.TypeIndex) bool {
    const t = &b.c.typesList.items[mapped];
    if (t.objectFlags & types.ObjectFlags.Mapped == 0) return false;
    if (t.objectFlags & types.ObjectFlags.Instantiated == 0) return false;
    if (t.alias != null and t.alias.?.typeArgumentsLen > 0) return false;
    if (t.data != .Mapped) return false;
    const declNode = t.data.Mapped.declaration;
    const node = b.c.binder.ast.nodes.get(declNode);
    if (node != .MappedType) return false;
    return node.MappedType.NameType == null;
}

pub fn createMappedTypeNodeFromType(b: *NodeBuilderImpl, t: *anyopaque) *anyopaque {
    _ = b;
    _ = t;
    return undefined;
}

pub fn typeToTypeNodeHelperWithPossibleReusableTypeNode(b: *NodeBuilderImpl, t: *anyopaque, typeNode: *anyopaque) *anyopaque {
    _ = b;
    _ = t;
    _ = typeNode;
    return undefined;
}

pub fn typeParametersToTypeParameterDeclarations(b: *NodeBuilderImpl, symbol_: *anyopaque) *anyopaque {
    _ = b;
    _ = symbol_;
    return undefined;
}

pub fn getEffectiveParameterDeclaration(c: *Checker, symbol_: ast_gen.SymbolIndex) ?ast_gen.NodeIndex {
    for (c.binder.symbols.items[symbol_].Declarations.items) |decl| {
        if (c.binder.ast.nodes.get(decl) == .Parameter) return decl;
    }
    return null;
}

pub fn parameterToParameterDeclarationName(b: *NodeBuilderImpl, parameterSymbol: *anyopaque, parameterDeclaration: *anyopaque) *anyopaque {
    _ = b;
    _ = parameterSymbol;
    _ = parameterDeclaration;
    return undefined;
}

pub fn cloneBindingName(b: *NodeBuilderImpl, node: *anyopaque) *anyopaque {
    _ = b;
    _ = node;
    return undefined;
}

pub fn serializeInferredReturnTypeForSignature(b: *NodeBuilderImpl, signature: *anyopaque, returnType: *anyopaque) *anyopaque {
    _ = b;
    _ = signature;
    _ = returnType;
    return undefined;
}

pub fn typePredicateToTypePredicateNodeHelper(b: *NodeBuilderImpl, typePredicate: *anyopaque) *anyopaque {
    _ = b;
    _ = typePredicate;
    return undefined;
}

pub fn signatureToSignatureDeclarationHelper(b: *NodeBuilderImpl, signature: *anyopaque, kind_: *anyopaque, options: *anyopaque) *anyopaque {
    _ = b;
    _ = signature;
    _ = kind_;
    _ = options;
    return undefined;
}

pub fn getExpandedParameters(sig: *anyopaque, skipUnionExpanding: *anyopaque) *anyopaque {
    _ = sig;
    _ = skipUnionExpanding;
    return undefined;
}

pub fn tryGetThisParameterDeclaration(b: *NodeBuilderImpl, signature: *anyopaque) *anyopaque {
    _ = b;
    _ = signature;
    return undefined;
}

pub fn isTriviallySerializableComputedName(b: *NodeBuilderImpl, e: *anyopaque) bool {
    _ = b;
    _ = e;
    return false;
}

pub fn indexInfoToObjectComputedNamesOrSignatureDeclaration(b: *NodeBuilderImpl, indexInfo: *anyopaque, typeNode: *anyopaque) *anyopaque {
    _ = b;
    _ = indexInfo;
    _ = typeNode;
    return undefined;
}

pub fn hasTypeAnnotation(declaration: *anyopaque) bool {
    _ = declaration;
    return false;
}

pub fn shouldUsePlaceholderForProperty(b: *NodeBuilderImpl, propertySymbol: ast_gen.SymbolIndex) bool {
    const symFlags = b.c.binder.symbols.items[propertySymbol].Flags;
    if (symFlags & (sym_mod.SymbolFlags.Property | sym_mod.SymbolFlags.Method) == 0) {
        return false;
    }
    const accessibility = checker_mod.Checker.isSymbolAccessible(b.c, propertySymbol, b.ctx.enclosingDeclaration, sym_mod.SymbolFlags.Type, false).accessibility;
    return accessibility != .Accessible;
}

pub fn trackComputedName(b: *NodeBuilderImpl, accessExpression: *anyopaque, enclosingDeclaration: *anyopaque) void {
    _ = b;
    _ = accessExpression;
    _ = enclosingDeclaration;
}

pub fn classifyPropertyName(name_: *anyopaque, stringNamed: *anyopaque, isMethod: *anyopaque) *anyopaque {
    _ = name_;
    _ = stringNamed;
    _ = isMethod;
    return undefined;
}

pub fn createPropertyNameNodeForIdentifierOrLiteral(b: *NodeBuilderImpl, name_: *anyopaque, singleQuote: *anyopaque, stringNamed: *anyopaque, isMethod: *anyopaque, symbol_: *anyopaque) *anyopaque {
    _ = b;
    _ = name_;
    _ = singleQuote;
    _ = stringNamed;
    _ = isMethod;
    _ = symbol_;
    return undefined;
}

pub fn isStringNamed(b: *NodeBuilderImpl, d: ast_gen.NodeIndex) bool {
    const name = ast_utils.getNameOfDeclaration(&b.c.binder.ast, d) orelse return false;
    const node = b.c.binder.ast.nodes.get(name);

    if (node == .ComputedPropertyName) {
        const expr = node.ComputedPropertyName.Expression;
        const t = b.c.checkExpression(expr, .Normal);
        return b.c.typesList.items[t].flags & types.TypeFlags.StringLike != 0;
    }
    if (node == .ElementAccessExpression) {
        const expr = node.ElementAccessExpression.ArgumentExpression;
        const t = b.c.checkExpression(expr, .Normal);
        return b.c.typesList.items[t].flags & types.TypeFlags.StringLike != 0;
    }
    return node == .StringLiteral;
}

pub fn isSingleQuotedStringNamed(b: *NodeBuilderImpl, d: ast_gen.NodeIndex) bool {
    const name = ast_utils.getNameOfDeclaration(&b.c.binder.ast, d) orelse return false;
    const node = b.c.binder.ast.nodes.get(name);
    if (node != .StringLiteral) return false;
    return node.StringLiteral.TokenFlags & scanner.TokenFlags.SingleQuote != 0;
}

pub fn getPropertyNameNodeForSymbol(b: *NodeBuilderImpl, symbol_: *anyopaque) *anyopaque {
    _ = b;
    _ = symbol_;
    return undefined;
}

pub fn getPropertyNameNodeForSymbolFromNameType(b: *NodeBuilderImpl, symbol_: *anyopaque, singleQuote: *anyopaque, stringNamed: *anyopaque, isMethod: *anyopaque) *anyopaque {
    _ = b;
    _ = symbol_;
    _ = singleQuote;
    _ = stringNamed;
    _ = isMethod;
    return undefined;
}

pub fn addPropertyToElementList(b: *NodeBuilderImpl, propertySymbol: *anyopaque, typeElements: *anyopaque) *anyopaque {
    _ = b;
    _ = propertySymbol;
    _ = typeElements;
    return undefined;
}

pub fn createTypeNodesFromResolvedType(b: *NodeBuilderImpl, resolvedType: *anyopaque) *anyopaque {
    _ = b;
    _ = resolvedType;
    return undefined;
}

pub fn getTypeAliasForTypeLiteral(c: *anyopaque, t: *anyopaque) *anyopaque {
    _ = c;
    _ = t;
    return undefined;
}

pub fn shouldWriteTypeOfFunctionSymbol(b: *NodeBuilderImpl, symbol_: *anyopaque, typeId: *anyopaque) bool {
    _ = b;
    _ = symbol_;
    _ = typeId;
    return false;
}

pub fn createAnonymousTypeNode(b: *NodeBuilderImpl, t: *anyopaque) *anyopaque {
    _ = b;
    _ = t;
    return undefined;
}

pub fn createAnonymousTypeNodeEx(b: *NodeBuilderImpl, t: *anyopaque, forceClassExpansion: *anyopaque, forceExpansion: *anyopaque) *anyopaque {
    _ = b;
    _ = t;
    _ = forceClassExpansion;
    _ = forceExpansion;
    return undefined;
}

pub fn getTypeFromTypeNode(b: *NodeBuilderImpl, node: *anyopaque, noMappedTypes: *anyopaque) *anyopaque {
    _ = b;
    _ = node;
    _ = noMappedTypes;
    return undefined;
}

pub fn typeToTypeNodeOrCircularityElision(b: *NodeBuilderImpl, t: *anyopaque) *anyopaque {
    _ = b;
    _ = t;
    return undefined;
}

pub fn conditionalTypeToTypeNode(b: *NodeBuilderImpl, _t: *anyopaque) *anyopaque {
    _ = b;
    _ = _t;
    return undefined;
}

pub fn getParentSymbolOfTypeParameter(b: *NodeBuilderImpl, typeParameter: *anyopaque) *anyopaque {
    _ = b;
    _ = typeParameter;
    return undefined;
}

pub fn typeReferenceToTypeNode(b: *NodeBuilderImpl, t: *anyopaque) *anyopaque {
    _ = b;
    _ = t;
    return undefined;
}

pub fn visitAndTransformType(b: *NodeBuilderImpl, t: *anyopaque, transform: *anyopaque) *anyopaque {
    _ = b;
    _ = t;
    _ = transform;
    _ = t;
    return undefined;
}

pub fn newStringLiteral(b: *NodeBuilderImpl, text: *anyopaque) *anyopaque {
    _ = b;
    _ = text;
    return undefined;
}

pub fn newStringLiteralEx(b: *NodeBuilderImpl, text: *anyopaque, isSingleQuote: *anyopaque) *anyopaque {
    _ = b;
    _ = text;
    _ = isSingleQuote;
    return undefined;
}

pub fn toTypeReferenceNode(b: *NodeBuilderImpl) *anyopaque {
    _ = b;
    return undefined;
}

pub fn newIdentifier(b: *NodeBuilderImpl, text: *anyopaque, symbol_: *anyopaque) *anyopaque {
    _ = b;
    _ = text;
    _ = symbol_;
    return undefined;
}

pub fn createAccessExpression(b: *NodeBuilderImpl, node: *anyopaque) *anyopaque {
    _ = b;
    _ = node;
    return undefined;
}

pub fn createExpressionWithTypeArguments(b: *NodeBuilderImpl, expr: *anyopaque, typeArguments: *anyopaque) *anyopaque {
    _ = b;
    _ = expr;
    _ = typeArguments;
    return undefined;
}

pub fn lookupInstantiatedTypeArgumentNodes(b: *NodeBuilderImpl, chain: *anyopaque, index: *anyopaque) *anyopaque {
    _ = b;
    _ = chain;
    _ = index;
    return undefined;
}

pub fn lookupExpressionChainTypeArgumentNodes(b: *NodeBuilderImpl, chain: *anyopaque, index: *anyopaque) *anyopaque {
    _ = b;
    _ = chain;
    _ = index;
    return undefined;
}

pub fn shouldWriteTypeParametersInQualifiedName(b: *NodeBuilderImpl, chain: *anyopaque, index: *anyopaque) bool {
    _ = b;
    _ = chain;
    _ = index;
    return false;
}
