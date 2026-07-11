const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const sym_mod = @import("../ast/symbol.zig");
const types = @import("types.zig");
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const factory_pkg = @import("../printer/factory.zig");

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
        return factory_pkg.NodeFactory.init(b.c.allocator, b.c.binder.ast);
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
            const text = std.fmt.allocPrint(b.c.allocator, "{d}", .{typeData.data.NumberLiteral.value}) catch return null;
            defer b.c.allocator.free(text);
            var f = factory(b);
            const literal = f.newNumericLiteral(text, 0);
            return createLiteralTypeNode(b, literal);
        }
        if (flags & types.TypeFlags.BooleanLiteral != 0) {
            var f = factory(b);
            const literal = if (typeData.data.BooleanLiteral.value) f.newTrueExpression() else f.newFalseExpression();
            return createLiteralTypeNode(b, literal);
        }
        return null;
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
        const members = b.c.resolveStructuredTypeMembers(t);
        const properties = b.c.resolvedPropertiesPool.items[members.propertiesStart .. members.propertiesStart + members.propertiesLen];

        var member_nodes = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer member_nodes.deinit(b.c.allocator);

        for (properties) |prop| {
            if (!b.c.symbolIsValue(prop)) continue;
            const prop_type = b.c.getTypeOfSymbol(prop) catch 0;
            const type_node = if (prop_type != 0) b.typeToTypeNode(prop_type) else createKeywordTypeNode(b, .AnyKeyword);
            const optional = (b.c.getSymbolFlags(prop) & sym_mod.SymbolFlags.Optional) != 0;
            const name_node = createPropertyNameNode(b, b.c.getSymbolName(prop));
            var f = factory(b);
            const member = b.c.binder.ast.pushNode(.{
                .PropertySignature = .{
                    .Flags = synthesizedFlags(),
                    .Symbol = 0,
                    .modifiers = null,
                    .modifierFlags = 0,
                    .name = name_node,
                    .PostfixToken = if (optional) f.newToken(.{ .QuestionToken = {} }) else null,
                    .Type = type_node,
                    .Initializer = null,
                },
            }) catch return 0;
            member_nodes.append(b.c.allocator, member) catch return 0;
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
        if (primitiveTypeToTypeNode(b, typ)) |node| return node;

        const typeData = &b.c.typesList.items[typ];
        const typeFlags = typeData.flags;
        const objectFlags = typeData.objectFlags;

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
                    var element_nodes = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
                    defer element_nodes.deinit(b.c.allocator);
                    for (tuple_types) |element_type| {
                        const element_node = b.typeToTypeNode(element_type);
                        if (element_node == 0) return 0;
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
