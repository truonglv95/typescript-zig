const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const ast = @import("../ast/ast.zig");
const symbol = @import("../ast/symbol.zig");
const binder = @import("../binder/binder.zig");
const nameresolver = @import("../binder/nameresolver.zig");
const types = @import("types.zig");
const flow = @import("flow.zig");
const ast_flow = @import("../ast/flow.zig");
const kind = @import("../ast/kind.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const diagnostics_gen = @import("../diagnostics/diagnostics_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
pub const utils = @import("utilities.zig");
pub const relater = @import("relater.zig");
pub const inference = @import("inference.zig");
pub const emitresolver = @import("emitresolver.zig");
pub const nodebuilder = @import("nodebuilder.zig");
pub const nodebuilderimpl = @import("nodebuilderimpl.zig");
pub const pseudochecker = @import("pseudotypenodebuilder.zig");
pub const grammarchecks = @import("grammarchecks.zig");
pub const jsx = @import("jsx.zig");

pub const EnumRelationKey = packed struct(u64) {
    sourceId: ast_gen.SymbolIndex,
    targetId: ast_gen.SymbolIndex,
};

pub const CheckMode = enum(u32) {
    Normal = 0,
    Contextual = 1 << 0,
    Inferential = 1 << 1,
    SkipContextSensitive = 1 << 2,
    SkipGenericFunctions = 1 << 3,
    IsForSignatureHelp = 1 << 4,
    RestBindingElement = 1 << 5,
    TypeOnly = 1 << 6,
    ForceTuple = 1 << 7,
};

pub const symbolaccessibility = @import("symbolaccessibility.zig");

pub const Checker = struct {
    pub const isTypeSymbolAccessible = symbolaccessibility.isTypeSymbolAccessible;
    pub const isValueSymbolAccessible = symbolaccessibility.isValueSymbolAccessible;
    pub const isSymbolAccessibleByFlags = symbolaccessibility.isSymbolAccessibleByFlags;
    pub const isSymbolAccessibleWorker = symbolaccessibility.isSymbolAccessibleWorker;
    pub const isAnySymbolAccessible = symbolaccessibility.isAnySymbolAccessible;
    pub const getQualifiedLeftMeaning = symbolaccessibility.getQualifiedLeftMeaning;
    pub const getWithAlternativeContainers = symbolaccessibility.getWithAlternativeContainers;
    pub const getAlternativeContainingModules = symbolaccessibility.getAlternativeContainingModules;
    pub const getVariableDeclarationOfObjectLiteral = symbolaccessibility.getVariableDeclarationOfObjectLiteral;
    pub const hasExternalModuleSymbol = symbolaccessibility.hasExternalModuleSymbol;
    pub const getExternalModuleContainer = symbolaccessibility.getExternalModuleContainer;
    pub const getFileSymbolIfFileSymbolExportEqualsContainer = symbolaccessibility.getFileSymbolIfFileSymbolExportEqualsContainer;
    pub const getContainersOfSymbol = symbolaccessibility.getContainersOfSymbol;
    pub const getAliasForSymbolInContainer = symbolaccessibility.getAliasForSymbolInContainer;
    pub const getAccessibleSymbolChain = symbolaccessibility.getAccessibleSymbolChain;
    pub const getAccessibleSymbolChainEx = symbolaccessibility.getAccessibleSymbolChainEx;
    pub const getAccessibleSymbolChainFromSymbolTable = symbolaccessibility.getAccessibleSymbolChainFromSymbolTable;
    pub const getSymbolTableAliases = symbolaccessibility.getSymbolTableAliases;
    pub const trySymbolTable = symbolaccessibility.trySymbolTable;
    pub const compareSymbolChainsWorker = symbolaccessibility.compareSymbolChainsWorker;
    pub const isUMDExportSymbol = symbolaccessibility.isUMDExportSymbol;
    pub const isNamespaceReexportDeclaration = symbolaccessibility.isNamespaceReexportDeclaration;
    pub const getCandidateListForSymbol = symbolaccessibility.getCandidateListForSymbol;
    pub const isAccessible = symbolaccessibility.isAccessible;
    pub const canQualifySymbol = symbolaccessibility.canQualifySymbol;
    pub const needsQualification = symbolaccessibility.needsQualification;
    pub const isPropertyOrMethodDeclarationSymbol = symbolaccessibility.isPropertyOrMethodDeclarationSymbol;
    pub const someSymbolTableInScope = symbolaccessibility.someSymbolTableInScope;
    pub const getClassExpressionNameTable = symbolaccessibility.getClassExpressionNameTable;
    pub const isSymbolAccessible = symbolaccessibility.isSymbolAccessible;

    allocator: std.mem.Allocator,
    binder: *binder.Binder,
    resolver: nameresolver.NameResolver,
    typesList: std.ArrayListUnmanaged(types.Type),

    unionTypesPool: std.ArrayListUnmanaged(types.TypeIndex),
    tupleTypesPool: std.ArrayListUnmanaged(types.TypeIndex),

    // Flow analysis state
    freeFlowState: ?*flow.FlowState = null,
    flowAnalysisDisabled: bool = false,
    flowInvocationCount: usize = 0,
    sharedFlows: std.ArrayListUnmanaged(flow.SharedFlow) = .empty,
    antecedentTypes: std.ArrayListUnmanaged(types.TypeIndex) = .empty,
    nodeFlowNodes: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, ast_flow.FlowNodeIndex) = .empty,
    symbolContainerLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.ContainingSymbolLinks) = .empty,

    lastFlowNode: ast_flow.FlowNodeIndex = 0,
    lastFlowNodeReachable: bool = false,
    flowNodeReachable: std.AutoHashMapUnmanaged(ast_flow.FlowNodeIndex, bool) = .empty,

    flowLoopCache: std.AutoHashMapUnmanaged(flow.FlowLoopKey, types.TypeIndex) = .empty,
    flowLoopStack: std.ArrayListUnmanaged(flow.FlowLoopInfo) = .empty,
    flowLoopTypes: std.ArrayListUnmanaged(types.TypeIndex) = .empty,
    inlineLevel: u32 = 0,

    // Cache for intrinsic types to avoid duplicates
    numberTypeIndex: ?u32 = null,
    anyTypeIndex: ?u32 = null,
    stringTypeIndex: ?u32 = null,
    booleanTypeIndex: ?u32 = null,
    voidTypeIndex: ?u32 = null,
    undefinedTypeIndex: ?u32 = null,
    nullTypeIndex: ?u32 = null,
    unknownTypeIndex: ?u32 = null,
    neverTypeIndex: ?u32 = null,
    bigintTypeIndex: ?u32 = null,
    trueTypeIndex: ?u32 = null,
    falseTypeIndex: ?u32 = null,
    objectTypeIndex: ?u32 = null,
    autoTypeIndex: ?u32 = null,
    autoArrayTypeIndex: ?u32 = null,
    nonPrimitiveTypeIndex: ?u32 = null,
    errorTypeIndex: ?u32 = null,

    identityRelation: relater.Relation = .{},
    assignableRelation: relater.Relation = .{},
    subtypeRelation: relater.Relation = .{},
    strictSubtypeRelation: relater.Relation = .{},
    comparableRelation: relater.Relation = .{},

    globalFunctionType: types.TypeIndex = 0,
    enumRelation: std.AutoHashMapUnmanaged(EnumRelationKey, relater.RelationComparisonResult) = .empty,

    inVarianceComputation: bool = false,

    strictNullChecks: bool = false,
    exactOptionalPropertyTypes: bool = false,
    freeRelater: ?*relater.Relater = null,
    typeToStringNodebuilder: ?*nodebuilder.NodeBuilder = null,

    // Inference state pool
    inferenceStates: std.ArrayListUnmanaged(inference.InferenceState) = .empty,
    freeInferenceState: ?u32 = null,
    inferenceContextInfos: std.ArrayListUnmanaged(types.InferenceContextInfo) = .empty,
    inferenceContexts: std.ArrayListUnmanaged(types.InferenceContext) = .empty,
    inferenceInfos: std.ArrayListUnmanaged(types.InferenceInfo) = .empty,

    // Added for EmitResolver
    enumMemberLinks: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, types.EnumMemberLink) = .empty,

    pub fn init(allocator: std.mem.Allocator, b: *binder.Binder) Checker {
        return .{
            .allocator = allocator,
            .binder = b,
            .resolver = nameresolver.NameResolver.init(b.ast, b, null),
            .typesList = std.ArrayListUnmanaged(types.Type).empty,
            .unionTypesPool = std.ArrayListUnmanaged(types.TypeIndex).empty,
            .tupleTypesPool = std.ArrayListUnmanaged(types.TypeIndex).empty,
        };
    }

    pub fn deinit(self: *Checker) void {
        self.typesList.deinit(self.allocator);
        self.unionTypesPool.deinit(self.allocator);
        self.tupleTypesPool.deinit(self.allocator);
        self.sharedFlows.deinit(self.allocator);
        self.antecedentTypes.deinit(self.allocator);
        self.nodeFlowNodes.deinit(self.allocator);
        self.flowNodeReachable.deinit(self.allocator);
        self.flowLoopCache.deinit(self.allocator);
        self.flowLoopStack.deinit(self.allocator);
        self.flowLoopTypes.deinit(self.allocator);
        self.identityRelation.deinit(self.allocator);
        self.assignableRelation.deinit(self.allocator);
        self.subtypeRelation.deinit(self.allocator);
        self.strictSubtypeRelation.deinit(self.allocator);
        self.comparableRelation.deinit(self.allocator);
        self.enumRelation.deinit(self.allocator);

        var current = self.freeFlowState;
        while (current) |f| {
            const next = f.next;
            f.reduceLabels.deinit(self.allocator);
            self.allocator.destroy(f);
            current = next;
        }

        for (self.inferenceStates.items) |*state| {
            state.deinit(self.allocator);
        }
        self.inferenceStates.deinit(self.allocator);
        self.inferenceContextInfos.deinit(self.allocator);

        for (self.inferenceContexts.items) |*ctx| {
            ctx.inferences.deinit(self.allocator);
            ctx.intraExpressionInferenceSites.deinit(self.allocator);
        }
        self.inferenceContexts.deinit(self.allocator);

        for (self.inferenceInfos.items) |*info| {
            info.candidates.deinit(self.allocator);
            info.contraCandidates.deinit(self.allocator);
        }
        self.inferenceInfos.deinit(self.allocator);
    }

    fn createType(self: *Checker, t: types.Type) !u32 {
        const index = @as(u32, @intCast(self.typesList.items.len));
        try self.typesList.append(self.allocator, t);
        return index;
    }

    // =========================================================================
    // Stubs for Relater
    // =========================================================================

    pub fn getParentOfSymbol(self: *Checker, sym: ast_gen.SymbolIndex) ast_gen.SymbolIndex {
        _ = self;
        return sym;
    }

    pub fn getPropertiesOfType(self: *Checker, t: types.TypeIndex) []const ast_gen.SymbolIndex {
        _ = self;
        _ = t;
        return &[_]ast_gen.SymbolIndex{};
    }

    pub fn getPropertyOfType(self: *Checker, tIdx: u32, name: []const u8) ?ast_gen.SymbolIndex {
        if (tIdx == 0 or tIdx >= self.typesList.items.len) return null;
        const typ = self.typesList.items[tIdx];
        if ((typ.flags & types.TypeFlags.Object) != 0) {
            if (typ.symbol) |symIdx| {
                if (self.binder.symbolMembers.getPtr(symIdx)) |members| {
                    if (members.get(name)) |propSymIdx| {
                        return propSymIdx;
                    }
                }
            }
        }
        return null;
    }

    pub fn getDeclaredTypeOfSymbol(self: *Checker, sym: ast_gen.SymbolIndex) types.TypeIndex {
        _ = sym;
        return self.anyTypeIndex.?;
    }

    pub fn symbolToString(self: *Checker, sym: ast_gen.SymbolIndex) []const u8 {
        _ = self;
        _ = sym;
        return "symbol";
    }

    pub fn TypeToStringEx(self: *Checker, t: types.TypeIndex, enclosingDeclaration: ?ast.NodeIndex, formatFlags: u32, tracer: ?*anyopaque) []const u8 {
        _ = self;
        _ = t;
        _ = enclosingDeclaration;
        _ = formatFlags;
        _ = tracer;
        return "type";
    }

    pub fn TypeToString(self: *Checker, t: types.TypeIndex) []const u8 {
        _ = self;
        _ = t;
        return "type";
    }

    pub fn getNodeBuilder(c: *Checker) *nodebuilder.NodeBuilder {
        if (c.typeToStringNodebuilder) |b| {
            return b;
        }
        c.typeToStringNodebuilder = c.getNodeBuilderEx();
        return c.typeToStringNodebuilder.?;
    }

    pub fn getNodeBuilderEx(c: *Checker) *nodebuilder.NodeBuilder {
        _ = c;
        // Stub implementation for now
        // var b = nodebuilder.newNodeBuilder(c);
        return undefined;
    }

    pub fn isPartialMappedType(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false; // Stub
    }

    pub fn isEmptyObjectType(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false; // Stub
    }

    pub fn getApparentType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn isTupleType(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false; // Stub
    }

    pub fn isEmptyArrayLiteralType(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false; // Stub
    }

    // =========================================================================
    // Stubs for Diagnostics
    // =========================================================================

    pub fn hasParseDiagnostics(c: *Checker, sourceFile: ast_gen.NodeIndex) bool {
        _ = c;
        _ = sourceFile;
        return false;
    }

    pub fn addDiagnostic(c: *Checker, diag: diagnostics.Diagnostic) void {
        c.binder.diagnosticsList.append(c.allocator, diag) catch {};
    }

    pub fn reportError(c: *Checker, node: ast_gen.NodeIndex, message: *const diagnostics_gen.Message) void {
        _ = c;
        _ = node;
        _ = message;
    }

    pub fn checkNodeDeferred(c: *Checker, node: ast_gen.NodeIndex) void {
        _ = c;
        _ = node;
    }

    pub fn checkExpressionEx(c: *Checker, node: ast_gen.NodeIndex, checkMode: types.CheckMode) types.TypeIndex {
        _ = node;
        _ = checkMode;
        return c.anyTypeIndex orelse 0;
    }

    pub fn isErrorType(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn getVariances(c: *Checker, t: types.TypeIndex) []const types.VarianceFlags {
        _ = c;
        _ = t;
        return &[_]types.VarianceFlags{}; // Stub
    }

    pub fn isArrayOrTupleType(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false; // Stub
    }

    pub fn isMutableTupleType(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false; // Stub
    }

    pub fn getIndexTypeOfTypeEx(c: *Checker, t: types.TypeIndex, indexType: types.TypeIndex, errorNode: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        _ = indexType;
        _ = errorNode;
        return undefined; // Stub
    }

    pub fn isGenericTupleType(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false; // Stub
    }

    pub fn compareTypesIdentical(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) types.Ternary {
        _ = c;
        _ = source;
        _ = target;
        return .False; // Stub
    }

    pub fn reportUnreliableMapper(c: *Checker, index: types.TypeMapperIndex) types.TypeMapperIndex {
        _ = c;
        return index;
    }

    pub fn reportUnmeasurableMapper(c: *Checker, index: types.TypeMapperIndex) types.TypeMapperIndex {
        _ = c;
        return index;
    }

    pub fn getCombinedMappedTypeOptionality(c: *Checker, t: types.TypeIndex) i32 {
        _ = c;
        _ = t;
        return 0; // Stub
    }

    pub fn getRootOfConditionalType(c: *Checker, t: types.TypeIndex) types.ConditionalRoot {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn getCheckTypeFromConditionalType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn getExtendsTypeFromConditionalType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn getTrueTypeFromConditionalType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn getFalseTypeFromConditionalType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn getBaseTypeFromSubstitutionType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn getConstraintFromSubstitutionType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn templateLiteralTextsEqual(c: *Checker, t1: types.TypeIndex, t2: types.TypeIndex) bool {
        _ = c;
        _ = t1;
        _ = t2;
        return false; // Stub
    }

    pub fn getTypesFromTemplateLiteralType(c: *Checker, t: types.TypeIndex) []const types.TypeIndex {
        _ = c;
        _ = t;
        return &[_]types.TypeIndex{}; // Stub
    }

    pub fn getSymbolFromStringMappingType(c: *Checker, t: types.TypeIndex) ast.symbolIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn getTargetTypeFromStringMappingType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn getObjectTypeFromIndexedAccessType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn getAliasSymbol(c: *Checker, t: types.TypeIndex) ast.symbolIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn getAliasTypeArguments(c: *Checker, t: types.TypeIndex) []const types.TypeIndex {
        _ = c;
        _ = t;
        return &[_]types.TypeIndex{}; // Stub
    }

    pub fn isMarkerType(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false; // Stub
    }

    pub fn getAliasVariances(c: *Checker, sym: ast.symbolIndex) []const types.VarianceFlags {
        _ = c;
        _ = sym;
        return &[_]types.VarianceFlags{}; // Stub
    }

    pub fn getMinTypeArgumentCount(c: *Checker, typeParameters: []const types.TypeIndex) usize {
        _ = c;
        _ = typeParameters;
        return 0; // Stub
    }

    pub fn getSymbolValueDeclaration(c: *Checker, sym: ast.symbolIndex) ast.NodeIndex {
        if (sym >= c.binder.symbols.items.len) return 0;
        return c.binder.symbols.items[sym].ValueDeclaration orelse 0;
    }

    pub fn fillMissingTypeArguments(c: *Checker, typeArguments: []const types.TypeIndex, typeParameters: []const types.TypeIndex, minParams: usize, nodeIsInJsFile: bool) []const types.TypeIndex {
        _ = c;
        _ = typeParameters;
        _ = minParams;
        _ = nodeIsInJsFile;
        return typeArguments; // Stub
    }

    pub fn isSingleElementGenericTupleType(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false; // Stub
    }

    pub fn getTargetTupleType(c: *Checker, t: types.TypeIndex) *types.TupleType {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn getTypeArguments(c: *Checker, t: types.TypeIndex) []const types.TypeIndex {
        _ = c;
        _ = t;
        return &[_]types.TypeIndex{}; // Stub
    }

    pub fn isMutableArrayOrTuple(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false; // Stub
    }

    pub fn getBaseConstraintOrType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        return t; // Stub
    }

    pub fn getIndexType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn getConstraintTypeFromMappedType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn getNameTypeFromMappedType(c: *Checker, t: types.TypeIndex) ?types.TypeIndex {
        _ = c;
        _ = t;
        return null; // Stub
    }

    pub fn getMappedTypeModifiers(c: *Checker, t: types.TypeIndex) types.MappedTypeModifiers {
        _ = c;
        _ = t;
        return .{}; // Stub
    }

    pub fn getTemplateTypeFromMappedType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn getIndexedAccessType(c: *Checker, objectType: types.TypeIndex, indexType: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = objectType;
        _ = indexType;
        return undefined; // Stub
    }

    pub fn getTypeParameterFromMappedType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn getConstraintOfTypeParameter(c: *Checker, t: types.TypeIndex) ?types.TypeIndex {
        _ = c;
        _ = t;
        return null; // Stub
    }

    pub fn getIndexedAccessTypeOrUndefined(c: *Checker, objectType: types.TypeIndex, indexType: types.TypeIndex, accessFlags: types.AccessFlags, context: ?ast.NodeIndex, declaration: ?ast.NodeIndex) ?types.TypeIndex {
        _ = c;
        _ = objectType;
        _ = indexType;
        _ = accessFlags;
        _ = context;
        _ = declaration;
        return null; // Stub
    }

    pub fn getKnownKeysOfTupleType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn getSimplifiedTypeOrConstraint(c: *Checker, t: types.TypeIndex) ?types.TypeIndex {
        _ = c;
        _ = t;
        return null; // Stub
    }

    pub fn getIndexTypeEx(c: *Checker, t: types.TypeIndex, indexFlags: types.IndexFlags) types.TypeIndex {
        _ = c;
        _ = t;
        _ = indexFlags;
        return undefined; // Stub
    }

    pub fn isGenericMappedType(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false; // Stub
    }

    pub fn isMappedTypeWithKeyofConstraintDeclaration(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false; // Stub
    }

    pub fn getApparentMappedTypeKeys(c: *Checker, nameType: types.TypeIndex, mappedType: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = nameType;
        _ = mappedType;
        return undefined; // Stub
    }

    pub fn getUnionTypeFromArray(c: *Checker, typesArr: []const types.TypeIndex) types.TypeIndex {
        return c.createUnionType(typesArr) catch c.getAnyType() catch 0;
    }

    pub fn getPermissiveInstantiation(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn getRestrictiveInstantiation(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
    }

    pub fn isTypeAssignableTo(self: *Checker, sourceIdx: types.TypeIndex, targetIdx: types.TypeIndex) anyerror!bool {
        var sourceT = self.typesList.items[sourceIdx];
        var targetT = self.typesList.items[targetIdx];

        if (types.isAssignableTo(&sourceT, &targetT)) return true;

        if (sourceT.flags & types.TypeFlags.Object != 0 and targetT.flags & types.TypeFlags.Object != 0) {
            if (targetT.symbol) |targetSymIdx| {
                if (self.binder.symbolMembers.getPtr(targetSymIdx)) |membersMap| {
                    var it = membersMap.iterator();
                    while (it.next()) |entry| {
                        const propName = entry.key_ptr.*;
                        const targetPropSymIdx = entry.value_ptr.*;
                        const targetPropTypeIdx = try self.getTypeOfSymbol(targetPropSymIdx);

                        if (self.getPropertyOfType(sourceIdx, propName)) |sourcePropSymIdx| {
                            const sourcePropTypeIdx = try self.getTypeOfSymbol(sourcePropSymIdx);
                            if (!try self.isTypeAssignableTo(sourcePropTypeIdx, targetPropTypeIdx)) {
                                return false;
                            }
                        } else {
                            return false;
                        }
                    }
                }
            }
            return true;
        }

        return false;
    }

    pub fn templateLiteralTypesDefinitelyUnrelated(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
        _ = c;
        _ = source;
        _ = target;
        return false; // Stub
    }

    pub fn instantiateType(c: *Checker, t: types.TypeIndex, mapper: types.TypeMapperIndex) types.TypeIndex {
        _ = c;
        _ = t;
        _ = mapper;
        return undefined; // Stub
    }

    pub fn isTypeMatchedByTemplateLiteralType(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, ctx: anytype, comptime isRelated: fn (ctx: anytype, source: types.TypeIndex, target: types.TypeIndex) types.Ternary) bool {
        _ = c;
        _ = source;
        _ = target;
        _ = ctx;
        _ = isRelated;
        return false; // Stub
    }

    pub fn isMemberOfStringMapping(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
        _ = c;
        _ = source;
        _ = target;
        return false; // Stub
    }

    pub fn extractTypesOfKind(c: *Checker, t: types.TypeIndex, kindMask: types.TypeFlagsInt) types.TypeIndex {
        _ = c;
        _ = t;
        _ = kindMask;
        return undefined; // Stub
    }

    pub fn getIntersectionType(c: *Checker, typesArr: []const types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = typesArr;
        return undefined; // Stub
    }

    pub fn getConstraintOfType(c: *Checker, t: types.TypeIndex) ?types.TypeIndex {
        _ = c;
        _ = t;
        return null; // Stub
    }

    pub fn getTypeWithThisArgument(c: *Checker, t: types.TypeIndex, thisArgument: types.TypeIndex, needApparentType: bool) types.TypeIndex {
        _ = c;
        _ = t;
        _ = thisArgument;
        _ = needApparentType;
        return undefined; // Stub
    }

    pub fn isMappedTypeGenericIndexedAccess(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false; // Stub
    }

    pub fn shouldDeferIndexType(c: *Checker, t: types.TypeIndex, indexFlags: types.IndexFlags) bool {
        _ = c;
        _ = t;
        _ = indexFlags;
        return false; // Stub
    }

    pub fn intersectTypes(c: *Checker, t1: types.TypeIndex, t2: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t1;
        _ = t2;
        return undefined; // Stub
    }

    pub fn newInferenceContext(c: *Checker, typeParameters: []const types.TypeIndex, signature: ?types.SignatureIndex, flags: types.InferenceFlags, comptime isRelatedToWorker: anytype) *types.InferenceContext {
        _ = c;
        _ = typeParameters;
        _ = signature;
        _ = flags;
        _ = isRelatedToWorker;
        return undefined; // Stub
    }

    pub fn inferTypes(c: *Checker, inferences: []types.InferenceInfoIndex, target: types.TypeIndex, source: types.TypeIndex, priority: types.InferencePriority, b: bool) void {
        _ = c;
        _ = inferences;
        _ = target;
        _ = source;
        _ = priority;
        _ = b;
    }

    pub fn isTypeIdenticalTo(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
        _ = c;
        _ = source;
        _ = target;
        return false; // Stub
    }

    pub fn getDefaultConstraintOfConditionalType(c: *Checker, t: types.TypeIndex) ?types.TypeIndex {
        _ = c;
        _ = t;
        return null; // Stub
    }

    pub fn hasNonCircularBaseConstraint(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false; // Stub
    }

    pub fn getConstraintOfDistributiveConditionalType(c: *Checker, t: types.TypeIndex) ?types.TypeIndex {
        _ = c;
        _ = t;
        return null; // Stub
    }

    pub fn getEnumMemberValue(self: *Checker, node: ast.NodeIndex) ast.NodeIndex {
        _ = self;
        return node;
    }

    pub fn valueToString(self: *Checker, value: anytype) []const u8 {
        _ = self;
        _ = value;
        return "value";
    }

    pub fn getDeclarationOfKind(self: *Checker, sym: ast_gen.SymbolIndex, kindValue: ast_gen.SyntaxKind) ast.NodeIndex {
        _ = self;
        _ = sym;
        _ = kindValue;
        return 0;
    }

    // =========================================================================
    // Intrinsic type getters
    // =========================================================================

    pub fn getNumberType(self: *Checker) !u32 {
        if (self.numberTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.Number, .objectFlags = 0, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.numberTypeIndex = idx;
        return idx;
    }

    pub fn getAnyType(self: *Checker) !u32 {
        if (self.anyTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.Any, .objectFlags = 0, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.anyTypeIndex = idx;
        return idx;
    }

    pub fn getStringType(self: *Checker) !u32 {
        if (self.stringTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.String, .objectFlags = 0, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.stringTypeIndex = idx;
        return idx;
    }

    pub fn getBooleanType(self: *Checker) !u32 {
        if (self.booleanTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.Boolean, .objectFlags = 0, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.booleanTypeIndex = idx;
        return idx;
    }

    pub fn getVoidType(self: *Checker) !u32 {
        if (self.voidTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.Void, .objectFlags = 0, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.voidTypeIndex = idx;
        return idx;
    }

    pub fn getUndefinedType(self: *Checker) !u32 {
        if (self.undefinedTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.Undefined, .objectFlags = 0, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.undefinedTypeIndex = idx;
        return idx;
    }

    pub fn getNullType(self: *Checker) !u32 {
        if (self.nullTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.Null, .objectFlags = 0, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.nullTypeIndex = idx;
        return idx;
    }

    pub fn getUnknownType(self: *Checker) !u32 {
        if (self.unknownTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.Unknown, .objectFlags = 0, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.unknownTypeIndex = idx;
        return idx;
    }

    pub fn getNeverType(self: *Checker) !u32 {
        if (self.neverTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.Never, .objectFlags = 0, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.neverTypeIndex = idx;
        return idx;
    }

    pub fn getBigIntType(self: *Checker) !u32 {
        if (self.bigintTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.BigInt, .objectFlags = 0, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.bigintTypeIndex = idx;
        return idx;
    }

    pub fn getTrueType(self: *Checker) !u32 {
        if (self.trueTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.BooleanLiteral, .objectFlags = 0, .id = 0, .symbol = null, .alias = null, .data = .{ .BooleanLiteral = .{ .value = true } } });
        self.trueTypeIndex = idx;
        return idx;
    }

    pub fn getFalseType(self: *Checker) !u32 {
        if (self.falseTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.BooleanLiteral, .objectFlags = 0, .id = 0, .symbol = null, .alias = null, .data = .{ .BooleanLiteral = .{ .value = false } } });
        self.falseTypeIndex = idx;
        return idx;
    }

    pub fn getObjectType(self: *Checker) !u32 {
        if (self.objectTypeIndex) |idx| return idx;
        const idx = try self.createType(.{
            .flags = types.TypeFlags.Object,
            .objectFlags = types.ObjectFlags.Anonymous,
            .id = 0,
            .symbol = null,
            .alias = null,
            .data = .{ .Object = std.mem.zeroes(types.ObjectTypeData) },
        });
        self.objectTypeIndex = idx;
        return idx;
    }

    // =========================================================================
    // Type of symbol / node
    // =========================================================================

    pub fn getTypeOfSymbol(self: *Checker, symIndex: u32) anyerror!u32 {
        const sym = self.binder.symbols.items[symIndex];
        var declaration_types = std.ArrayListUnmanaged(types.TypeIndex).empty;
        defer declaration_types.deinit(self.allocator);

        // Assignment declarations are used by the binder for JavaScript
        // expando properties, `this.x = value`, and CommonJS exports.  A
        // symbol may have several of them, so its inferred type is the union
        // of all right-hand sides rather than just its first declaration.
        for (sym.Declarations.items) |decl_index| {
            const declaration_type: ?types.TypeIndex = switch (self.binder.ast.getNode(decl_index)) {
                .BinaryExpression => |binary| switch (self.binder.ast.getNode(binary.OperatorToken)) {
                    .EqualsToken => try self.checkExpression(binary.Right),
                    else => null,
                },
                .TypeAliasDeclaration => |declaration| try self.getTypeOfNode(declaration.Type),
                .JSTypeAliasDeclaration => |declaration| try self.getTypeOfNode(declaration.Type),
                .InterfaceDeclaration => return try self.createType(.{
                    .flags = types.TypeFlags.Object,
                    .objectFlags = types.ObjectFlags.Interface,
                    .id = 0,
                    .symbol = symIndex,
                    .alias = null,
                    .data = .{ .Object = std.mem.zeroes(types.ObjectTypeData) },
                }),
                .ClassDeclaration, .ClassExpression => return try self.createType(.{
                    .flags = types.TypeFlags.Object,
                    .objectFlags = types.ObjectFlags.Class,
                    .id = 0,
                    .symbol = symIndex,
                    .alias = null,
                    .data = .{ .Object = std.mem.zeroes(types.ObjectTypeData) },
                }),
                else => null,
            };
            if (declaration_type) |type_index| {
                if (!containsTypeIndex(declaration_types.items, type_index)) {
                    try declaration_types.append(self.allocator, type_index);
                }
            }
        }
        if (declaration_types.items.len != 0) {
            return try self.createUnionType(declaration_types.items);
        }
        if (sym.ValueDeclaration) |declIndex| {
            return try self.getTypeOfNode(declIndex);
        }
        return try self.getAnyType();
    }

    pub fn getTypeOfNode(self: *Checker, nodeIndex: u32) anyerror!u32 {
        if (nodeIndex == 0) return try self.getAnyType();
        const node = self.binder.ast.getNode(nodeIndex);
        switch (node) {
            .Parameter => |p| {
                if (p.Type) |typeNodeIndex| {
                    return try self.getTypeOfNode(typeNodeIndex);
                }
                return try self.getAnyType();
            },
            .NumberKeyword => return try self.getNumberType(),
            .StringKeyword => return try self.getStringType(),
            .BooleanKeyword => return try self.getBooleanType(),
            .VoidKeyword => return try self.getVoidType(),
            .UndefinedKeyword => return try self.getUndefinedType(),
            .AnyKeyword => return try self.getAnyType(),
            .NullKeyword => return try self.getNullType(),
            .UnknownKeyword => return try self.getUnknownType(),
            .NeverKeyword => return try self.getNeverType(),
            .BigIntKeyword => return try self.getBigIntType(),
            .ObjectKeyword => return try self.getObjectType(),

            .VariableDeclaration => |decl| {
                if (decl.Type) |typeNode| return try self.getTypeOfNode(typeNode);
                if (decl.Initializer) |initExpr| return try self.checkExpression(initExpr);
                return try self.getAnyType();
            },
            .PropertyDeclaration => |p| {
                if (p.Type) |typeNode| return try self.getTypeOfNode(typeNode);
                if (p.Initializer) |initExpr| return try self.checkExpression(initExpr);
                return try self.getAnyType();
            },
            .PropertyAssignment => |p| {
                if (p.Type) |typeNode| {
                    if (typeNode != 0) return try self.getTypeOfNode(typeNode);
                }
                return try self.checkExpression(p.Initializer);
            },
            .PropertySignature => |ps| {
                if (ps.Type) |typeNode| {
                    if (typeNode != 0) return try self.getTypeOfNode(typeNode);
                }
                return try self.getAnyType();
            },
            .MethodDeclaration => |m| {
                if (m.Type) |t| return try self.getTypeOfNode(t);
                return try self.getAnyType();
            },
            .FunctionDeclaration => |f| {
                var retType: u32 = 0;
                if (f.Type != null and f.Type.? != 0) {
                    retType = try self.getTypeOfNode(f.Type.?);
                } else {
                    retType = try self.getAnyType();
                }

                var paramCount: u32 = 0;
                if (f.Parameters != 0) {
                    const params = self.binder.ast.getNodeList(f.Parameters);
                    paramCount = @intCast(params.len);
                }

                return try self.createType(.{
                    .flags = types.TypeFlags.Object,
                    .objectFlags = 0,
                    .id = 0,
                    .symbol = null,
                    .alias = null,
                    .data = .{ .Function = .{
                        .declarationNode = nodeIndex,
                        .returnType = retType,
                        .parameterCount = paramCount,
                    } },
                });
            },
            .ArrayType => |array| {
                const element_type = try self.getTypeOfNode(array.ElementType);
                return try self.createType(.{
                    .flags = types.TypeFlags.Object,
                    .objectFlags = types.ObjectFlags.Reference,
                    .id = 0,
                    .symbol = null,
                    .alias = null,
                    .data = .{ .Array = .{ .elementType = element_type } },
                });
            },
            .UnionType => |u| {
                const type_nodes = self.binder.ast.getNodeList(u.Types);
                var members = std.ArrayListUnmanaged(types.TypeIndex).empty;
                defer members.deinit(self.allocator);
                for (type_nodes) |type_node| try members.append(self.allocator, try self.getTypeOfNode(type_node));
                return try self.createUnionType(members.items);
            },
            .TupleType => |tuple| {
                const element_nodes = self.binder.ast.getNodeList(tuple.Elements);
                const start: u32 = @intCast(self.tupleTypesPool.items.len);
                for (element_nodes) |element| try self.tupleTypesPool.append(self.allocator, try self.getTypeOfNode(element));
                return try self.createType(.{
                    .flags = types.TypeFlags.Object,
                    .objectFlags = types.ObjectFlags.Reference | types.ObjectFlags.Tuple,
                    .id = 0,
                    .symbol = null,
                    .alias = null,
                    .data = .{ .Tuple = .{ .typesStart = start, .typesLen = @intCast(element_nodes.len) } },
                });
            },
            .TypeLiteral => |tl| {
                return try self.createType(.{
                    .flags = types.TypeFlags.Object,
                    .objectFlags = 0,
                    .id = 0,
                    .alias = null,
                    .symbol = if (tl.Symbol != 0) tl.Symbol else null,
                    .data = .{ .Object = std.mem.zeroes(types.ObjectTypeData) },
                });
            },
            .LiteralType => |lt| {
                return try self.getTypeOfNode(lt.Literal);
            },
            .ParenthesizedType => |parenthesized| return self.getTypeOfNode(parenthesized.Type),
            .TypeReference => |reference| {
                if (self.binder.ast.getNode(reference.TypeName) == .Identifier) {
                    const name = ast_utils.getText(self.binder.ast, reference.TypeName);
                    if (self.resolver.resolve(reference.TypeName, name, symbol.SymbolFlags.Type, null, false, false)) |sym_index| {
                        return try self.getTypeOfSymbol(sym_index);
                    }
                }
                return try self.getAnyType();
            },
            else => return try self.getAnyType(),
        }
    }

    // =========================================================================
    // checkExpression - thực hiện type checking cho expressions
    // =========================================================================

    pub fn checkExpression(self: *Checker, nodeIndex: u32) anyerror!u32 {
        const node = self.binder.ast.getNode(nodeIndex);
        switch (node) {
            // Literals
            .Identifier => |id| {
                if (self.resolver.resolve(nodeIndex, id.Text, symbol.SymbolFlags.Value, null, false, false)) |symIndex| {
                    return try self.getTypeOfSymbol(symIndex);
                }
                return try self.getAnyType();
            },
            .TrueKeyword => return try self.getTrueType(),
            .FalseKeyword => return try self.getFalseType(),
            .NullKeyword => return try self.getNullType(),
            .UndefinedKeyword => return try self.getUndefinedType(),

            .StringLiteral => |s| {
                return try self.createType(.{
                    .flags = types.TypeFlags.StringLiteral,
                    .objectFlags = 0,
                    .id = 0,
                    .symbol = null,
                    .alias = null,
                    .data = .{ .StringLiteral = .{ .text = s.Text } },
                });
            },
            .NumericLiteral => |n| {
                const value = std.fmt.parseFloat(f64, n.Text) catch 0.0;
                return try self.createType(.{
                    .flags = types.TypeFlags.NumberLiteral,
                    .objectFlags = 0,
                    .id = 0,
                    .symbol = null,
                    .alias = null,
                    .data = .{ .NumberLiteral = .{ .value = value } },
                });
            },
            .BigIntLiteral => |n| {
                return try self.createType(.{
                    .flags = types.TypeFlags.BigIntLiteral,
                    .objectFlags = 0,
                    .id = 0,
                    .symbol = null,
                    .alias = null,
                    .data = .{ .BigIntLiteral = .{ .text = n.Text } },
                });
            },
            .NoSubstitutionTemplateLiteral, .TemplateExpression => {
                return try self.getStringType();
            },
            .RegularExpressionLiteral => {
                // RegExp is an object type
                return try self.getObjectType();
            },

            // Arithmetic/logical binary expressions
            .BinaryExpression => |bin| {
                return try self.checkBinaryExpression(bin);
            },

            // Unary expressions
            .PrefixUnaryExpression => |pue| {
                const operandType = try self.checkExpression(pue.Operand);
                return try self.checkPrefixUnary(pue.Operator, operandType);
            },
            .PostfixUnaryExpression => |poe| {
                _ = try self.checkExpression(poe.Operand);
                return try self.getNumberType(); // ++ / -- always produce number
            },

            // Conditional / ternary
            .ConditionalExpression => |ce| {
                _ = try self.checkExpression(ce.Condition);
                const trueType = try self.checkExpression(ce.WhenTrue);
                const falseType = try self.checkExpression(ce.WhenFalse);
                return try self.getUnionType(trueType, falseType);
            },

            // Function types
            .FunctionExpression => |fe| {
                var retType: u32 = 0;
                if (fe.Type) |t| {
                    retType = try self.getTypeOfNode(t);
                } else {
                    retType = try self.getAnyType();
                }

                var paramCount: u32 = 0;
                if (fe.Parameters != 0) {
                    const params = self.binder.ast.getNodeList(fe.Parameters);
                    paramCount = @intCast(params.len);
                }

                return try self.createType(.{
                    .flags = types.TypeFlags.Object,
                    .objectFlags = 0,
                    .id = 0,
                    .symbol = null,
                    .alias = null,
                    .data = .{ .Function = .{
                        .declarationNode = nodeIndex,
                        .returnType = retType,
                        .parameterCount = paramCount,
                    } },
                });
            },
            .ArrowFunction => |af| {
                var retType: u32 = 0;
                if (af.Type) |t| {
                    retType = try self.getTypeOfNode(t);
                } else {
                    retType = try self.getAnyType();
                }

                var paramCount: u32 = 0;
                if (af.Parameters != 0) {
                    const params = self.binder.ast.getNodeList(af.Parameters);
                    paramCount = @intCast(params.len);
                }

                return try self.createType(.{
                    .flags = types.TypeFlags.Object,
                    .objectFlags = 0,
                    .id = 0,
                    .symbol = null,
                    .alias = null,
                    .data = .{ .Function = .{
                        .declarationNode = nodeIndex,
                        .returnType = retType,
                        .parameterCount = paramCount,
                    } },
                });
            },

            // Object/Array literals
            .ObjectLiteralExpression => |ole| {
                if (ole.Properties != 0) {
                    const props = self.binder.ast.getNodeList(ole.Properties);
                    for (props) |prop| {
                        _ = self.checkStatement(prop) catch {};
                    }
                }
                return try self.createType(.{
                    .flags = types.TypeFlags.Object,
                    .objectFlags = types.ObjectFlags.ObjectLiteral | types.ObjectFlags.FreshLiteral,
                    .id = 0,
                    .alias = null,
                    .symbol = if (ole.Symbol != 0) ole.Symbol else null,
                    .data = .{ .Object = std.mem.zeroes(types.ObjectTypeData) },
                });
            },
            .ArrayLiteralExpression => |ale| {
                var element_types = std.ArrayListUnmanaged(types.TypeIndex).empty;
                defer element_types.deinit(self.allocator);
                if (ale.Elements != 0) {
                    const elems = self.binder.ast.getNodeList(ale.Elements);
                    for (elems) |elem| try element_types.append(self.allocator, try self.checkExpression(elem));
                }
                const element_type = if (element_types.items.len == 0) try self.getNeverType() else try self.createUnionType(element_types.items);
                return try self.createType(.{
                    .flags = types.TypeFlags.Object,
                    .objectFlags = types.ObjectFlags.Reference | types.ObjectFlags.ArrayLiteral,
                    .id = 0,
                    .symbol = null,
                    .alias = null,
                    .data = .{ .Array = .{ .elementType = element_type } },
                });
            },

            // Property access
            .PropertyAccessExpression => |pae| {
                const objTypeIdx = try self.checkExpression(pae.Expression);
                const propNodeData = self.binder.ast.getNode(pae.name);
                if (std.meta.activeTag(propNodeData) == .Identifier) {
                    const propName = propNodeData.Identifier.Text;
                    if (self.getPropertyOfType(objTypeIdx, propName)) |propSym| {
                        return try self.getTypeOfSymbol(propSym);
                    }
                }
                return try self.getAnyType();
            },

            // Element access: arr[0]
            .ElementAccessExpression => |eae| {
                const objTypeIdx = try self.checkExpression(eae.Expression);
                const argTypeIdx = try self.checkExpression(eae.ArgumentExpression);

                if (argTypeIdx < self.typesList.items.len) {
                    const argType = self.typesList.items[argTypeIdx];
                    if (argType.flags & types.TypeFlags.StringLiteral != 0) {
                        const propName = argType.data.StringLiteral.text;
                        if (self.getPropertyOfType(objTypeIdx, propName)) |propSym| {
                            return try self.getTypeOfSymbol(propSym);
                        }
                    }
                }

                return try self.getAnyType();
            },

            // Call expression
            .CallExpression => |ce| {
                const calleeTypeIdx = try self.checkExpression(ce.Expression);

                var declNode: u32 = 0;
                var retType: u32 = 0;

                if (calleeTypeIdx < self.typesList.items.len) {
                    const calleeType = self.typesList.items[calleeTypeIdx];
                    if (std.meta.activeTag(calleeType.data) == .Function) {
                        declNode = calleeType.data.Function.declarationNode;
                        retType = calleeType.data.Function.returnType;
                    }
                }

                if (declNode != 0) {
                    const declNodeData = self.binder.ast.getNode(declNode);
                    var paramsId: u32 = 0;
                    switch (declNodeData) {
                        .FunctionDeclaration => |f| paramsId = f.Parameters,
                        .FunctionExpression => |f| paramsId = f.Parameters,
                        .ArrowFunction => |f| paramsId = f.Parameters,
                        .MethodDeclaration => |m| paramsId = m.Parameters,
                        else => {},
                    }

                    const params = if (paramsId != 0) self.binder.ast.getNodeList(paramsId) else &[_]u32{};
                    const args = if (ce.Arguments != 0) self.binder.ast.getNodeList(ce.Arguments) else &[_]u32{};

                    const minLen = @min(params.len, args.len);
                    for (0..minLen) |i| {
                        const paramData = self.binder.ast.getNode(params[i]);
                        if (std.meta.activeTag(paramData) == .Parameter) {
                            const param = paramData.Parameter;
                            const argTypeIdx = try self.checkExpression(args[i]);
                            var paramTypeIdx: u32 = 0;
                            if (param.Type != null and param.Type.? != 0) {
                                paramTypeIdx = try self.getTypeOfNode(param.Type.?);
                            } else {
                                paramTypeIdx = try self.getAnyType();
                            }

                            if (!try self.isTypeAssignableTo(argTypeIdx, paramTypeIdx)) {
                                const diag = diagnostics.Diagnostic{
                                    .nodeIndex = args[i],
                                    .message = &diagnostics_gen.Argument_of_type_0_is_not_assignable_to_parameter_of_type_1,
                                };
                                self.addDiagnostic(diag);
                            }
                        } else {
                            _ = try self.checkExpression(args[i]);
                        }
                    }
                    // Evaluate remaining args if any
                    for (minLen..args.len) |i| {
                        _ = try self.checkExpression(args[i]);
                    }

                    if (args.len < params.len) {
                        const diag = diagnostics.Diagnostic{
                            .nodeIndex = ce.Expression, // Usually reported on the callee
                            .message = &diagnostics_gen.Expected_0_arguments_but_got_1,
                        };
                        self.addDiagnostic(diag);
                    } else if (args.len > params.len) {
                        const diag = diagnostics.Diagnostic{
                            .nodeIndex = ce.Expression, // Usually reported on the callee
                            .message = &diagnostics_gen.Expected_0_arguments_but_got_1,
                        };
                        self.addDiagnostic(diag);
                    }
                } else {
                    if (ce.Arguments != 0) {
                        const args = self.binder.ast.getNodeList(ce.Arguments);
                        for (args) |arg| {
                            _ = try self.checkExpression(arg);
                        }
                    }
                }

                if (retType != 0) return retType;
                return try self.getAnyType();
            },

            // new expr(args)
            .NewExpression => |ne| {
                _ = try self.checkExpression(ne.Expression);
                if (ne.Arguments) |argsIdx| {
                    if (argsIdx != 0) {
                        const args = self.binder.ast.getNodeList(argsIdx);
                        for (args) |arg| {
                            _ = try self.checkExpression(arg);
                        }
                    }
                }
                return try self.getObjectType();
            },

            // Wrapping expressions
            .ParenthesizedExpression => |pe| {
                return try self.checkExpression(pe.Expression);
            },
            .AsExpression => |ae| {
                _ = try self.checkExpression(ae.Expression);
                return try self.getTypeOfNode(ae.Type);
            },
            .SatisfiesExpression => |se| {
                return try self.checkExpression(se.Expression);
            },
            .NonNullExpression => |nne| {
                return try self.checkExpression(nne.Expression);
            },
            .TypeAssertionExpression => |ta| {
                _ = try self.checkExpression(ta.Expression);
                return try self.getTypeOfNode(ta.Type);
            },

            // Unary with known return type
            .TypeOfExpression => {
                return try self.getStringType();
            },
            .VoidExpression => {
                return try self.getUndefinedType();
            },
            .AwaitExpression => |ae| {
                return try self.checkExpression(ae.Expression);
            },
            .YieldExpression => |ye| {
                if (ye.Expression) |expr| {
                    return try self.checkExpression(expr);
                }
                return try self.getAnyType();
            },
            .DeleteExpression => {
                return try self.getBooleanType();
            },
            .SpreadElement => |se| {
                return try self.checkExpression(se.Expression);
            },
            .JsxElement => {
                return jsx.checkJsxElement(self, nodeIndex, .Normal);
            },
            .JsxSelfClosingElement => {
                return jsx.checkJsxSelfClosingElement(self, nodeIndex, .Normal);
            },
            .JsxFragment => {
                return jsx.checkJsxFragment(self, nodeIndex);
            },
            .JsxExpression => {
                return jsx.checkJsxExpression(self, nodeIndex, .Normal);
            },
            .JsxAttributes => {
                return jsx.checkJsxAttributes(self, nodeIndex, .Normal);
            },

            // Template
            .TaggedTemplateExpression => {
                return try self.getAnyType();
            },

            // Class expression
            .ClassExpression => |ce| {
                if (ce.Members != 0) {
                    const members = self.binder.ast.getNodeList(ce.Members);
                    for (members) |mem| {
                        _ = self.checkStatement(mem) catch {};
                    }
                }
                return try self.createType(.{
                    .flags = types.TypeFlags.Object,
                    .objectFlags = types.ObjectFlags.Anonymous,
                    .id = 0,
                    .alias = null,
                    .symbol = if (ce.Symbol != 0) ce.Symbol else null,
                    .data = .{ .Object = std.mem.zeroes(types.ObjectTypeData) },
                });
            },

            else => return try self.getAnyType(),
        }
    }

    // =========================================================================
    // checkBinaryExpression - type của binary expression result
    // =========================================================================

    fn checkBinaryExpression(self: *Checker, bin: ast_gen.BinaryExpressionNode) !u32 {
        const leftTypeIdx = try self.checkExpression(bin.Left);
        const rightTypeIdx = try self.checkExpression(bin.Right);
        const leftType = if (leftTypeIdx < self.typesList.items.len)
            self.typesList.items[leftTypeIdx]
        else
            types.Type{ .flags = types.TypeFlags.Any, .objectFlags = 0, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } };
        const rightType = if (rightTypeIdx < self.typesList.items.len)
            self.typesList.items[rightTypeIdx]
        else
            types.Type{ .flags = types.TypeFlags.Any, .objectFlags = 0, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } };

        // Get operator token kind
        const opNode = self.binder.ast.getNode(bin.OperatorToken);

        if (opNode == .EqualsToken) {
            // Assignment expression

            // 1. Check if assigning to const
            // 1. Check if assigning to const
            const leftNodeData = self.binder.ast.getNode(bin.Left);
            if (std.meta.activeTag(leftNodeData) == .Identifier) {
                const idName = leftNodeData.Identifier.Text;
                if (self.resolver.resolve(bin.Left, idName, symbol.SymbolFlags.Value, null, false, false)) |symIndex| {
                    const sym = self.binder.symbols.items[symIndex];
                    if ((sym.Flags & symbol.SymbolFlags.BlockScopedVariable) != 0) {
                        if (sym.ValueDeclaration) |declIdx| {
                            const parentIdx = self.binder.ast.getNodeParent(declIdx);
                            const flags = ast_utils.getCombinedNodeFlags(self.binder.ast, parentIdx);
                            if ((flags & ast_utils.NodeFlags.Const) != 0) {
                                const diag = diagnostics.Diagnostic{
                                    .nodeIndex = bin.Left,
                                    .message = &diagnostics_gen.Cannot_assign_to_0_because_it_is_a_constant,
                                };
                                self.addDiagnostic(diag);
                            }
                        }
                    }
                }
            }

            // 2. Check type compatibility
            if (!try self.isTypeAssignableTo(rightTypeIdx, leftTypeIdx)) {
                // If not assignable, emit error 2322
                const diag = diagnostics.Diagnostic{
                    .nodeIndex = bin.Right,
                    .message = &diagnostics_gen.Type_0_is_not_assignable_to_type_1,
                };
                self.addDiagnostic(diag);
            }
            return rightTypeIdx;
        }

        const leftIsNumber = (leftType.flags & types.TypeFlags.NumberLike) != 0;
        const rightIsNumber = (rightType.flags & types.TypeFlags.NumberLike) != 0;
        const leftIsString = (leftType.flags & types.TypeFlags.StringLike) != 0;
        const rightIsString = (rightType.flags & types.TypeFlags.StringLike) != 0;

        const isArithmeticOperator = switch (opNode) {
            .MinusToken, .AsteriskToken, .SlashToken, .PercentToken, .AsteriskAsteriskToken => true,
            else => false,
        };

        if (isArithmeticOperator) {
            if (!leftIsNumber and (leftType.flags & types.TypeFlags.Any) == 0) {
                const diag = diagnostics.Diagnostic{
                    .nodeIndex = bin.Left,
                    .message = &diagnostics_gen.The_left_hand_side_of_an_arithmetic_operation_must_be_of_type_any_number_bigint_or_an_enum_type,
                };
                self.addDiagnostic(diag);
            }
            if (!rightIsNumber and (rightType.flags & types.TypeFlags.Any) == 0) {
                const diag = diagnostics.Diagnostic{
                    .nodeIndex = bin.Right,
                    .message = &diagnostics_gen.The_right_hand_side_of_an_arithmetic_operation_must_be_of_type_any_number_bigint_or_an_enum_type,
                };
                self.addDiagnostic(diag);
            }
            return try self.getNumberType();
        }

        // + operator: if either is string, result is string
        if (opNode == .PlusToken) {
            if (leftIsString or rightIsString) {
                return try self.getStringType();
            }
            return try self.getNumberType();
        }

        // Comparison operators: always return boolean
        // ===, !==, ==, !=, <, >, <=, >=, instanceof, in
        // (simplified: we check via flag combinations)
        if (leftIsNumber or leftIsString) {
            return try self.getBooleanType();
        }

        return try self.getAnyType();
    }

    // =========================================================================
    // checkPrefixUnary
    // =========================================================================

    fn checkPrefixUnary(self: *Checker, operatorNodeIdx: u32, operandTypeIdx: u32) !u32 {
        _ = operatorNodeIdx;
        _ = operandTypeIdx;
        // !, ~, +, -, ++ --
        // For ! -> boolean
        // For ~ -> number
        // For + -> number
        // For - -> number
        // TODO: check operator kind properly
        return try self.getAnyType();
    }

    // =========================================================================
    // getUnionType - tạo union của 2 types
    // =========================================================================

    fn getUnionType(self: *Checker, typeA: u32, typeB: u32) !u32 {
        return self.createUnionType(&.{ typeA, typeB });
    }

    fn createUnionType(self: *Checker, input_types: []const types.TypeIndex) !types.TypeIndex {
        if (input_types.len == 0) return self.getNeverType();
        var unique = std.ArrayListUnmanaged(types.TypeIndex).empty;
        defer unique.deinit(self.allocator);
        for (input_types) |type_index| {
            if (type_index < self.typesList.items.len and self.typesList.items[type_index].flags & types.TypeFlags.Union != 0 and self.typesList.items[type_index].data == .Union) {
                const union_data = self.typesList.items[type_index].data.Union;
                for (self.unionTypesPool.items[union_data.typesStart .. union_data.typesStart + union_data.typesLen]) |member| if (!containsTypeIndex(unique.items, member)) try unique.append(self.allocator, member);
            } else if (!containsTypeIndex(unique.items, type_index)) {
                try unique.append(self.allocator, type_index);
            }
        }
        if (unique.items.len == 1) return unique.items[0];
        const start = @as(u32, @intCast(self.unionTypesPool.items.len));
        try self.unionTypesPool.appendSlice(self.allocator, unique.items);

        return try self.createType(.{
            .flags = types.TypeFlags.Union,
            .objectFlags = 0,
            .id = 0,
            .symbol = null,
            .alias = null,
            .data = .{ .Union = .{ .typesStart = start, .typesLen = @intCast(unique.items.len) } },
        });
    }

    // =========================================================================
    // checkStatement
    // =========================================================================

    pub fn checkStatement(self: *Checker, nodeIndex: u32) anyerror!void {
        const node = self.binder.ast.getNode(nodeIndex);
        switch (node) {
            // Source file - entry point
            .SourceFile => |sf| {
                if (sf.Statements != 0) {
                    const stmts = self.binder.ast.getNodeList(sf.Statements);
                    for (stmts) |stmt| {
                        try self.checkStatement(stmt);
                    }
                }
            },

            // Block of statements
            .Block => |blk| {
                if (blk.Statements != 0) {
                    const stmts = self.binder.ast.getNodeList(blk.Statements);
                    for (stmts) |stmt| {
                        try self.checkStatement(stmt);
                    }
                }
            },

            // Variables
            .VariableStatement => |varStmt| {
                try self.checkStatement(varStmt.DeclarationList);
            },
            .VariableDeclarationList => |varList| {
                if (varList.Declarations != 0) {
                    const decls = self.binder.ast.getNodeList(varList.Declarations);
                    for (decls) |decl| {
                        try self.checkStatement(decl);
                    }
                }
            },
            .VariableDeclaration => |decl| {
                var initType: u32 = try self.getAnyType();
                if (decl.Initializer) |initExpr| {
                    initType = try self.checkExpression(initExpr);
                }

                if (decl.Type) |typeNode| {
                    const declaredType = try self.getTypeOfNode(typeNode);
                    // Type compatibility check
                    if (initType != 0 and declaredType != 0 and
                        initType < self.typesList.items.len and
                        declaredType < self.typesList.items.len)
                    {
                        if (!try self.isTypeAssignableTo(initType, declaredType)) {
                            // emit diagnostic: type mismatch 2322
                            const diag = diagnostics.Diagnostic{
                                .nodeIndex = nodeIndex,
                                .message = &diagnostics_gen.Type_0_is_not_assignable_to_type_1,
                            };
                            self.addDiagnostic(diag);
                        }
                    }
                }
            },

            // Functions
            .FunctionDeclaration => |f| {
                if (f.Body) |body| {
                    try self.checkStatement(body);
                }
                // Also check parameters
                if (f.Parameters != 0) {
                    const params = self.binder.ast.getNodeList(f.Parameters);
                    for (params) |param| {
                        _ = try self.getTypeOfNode(param);
                    }
                }
            },

            // Return statement
            .ReturnStatement => |ret| {
                var exprTypeIdx: u32 = 0;
                if (ret.Expression) |expr| {
                    exprTypeIdx = try self.checkExpression(expr);
                } else {
                    exprTypeIdx = try self.getUndefinedType();
                }

                // Find enclosing function
                var container: u32 = nodeIndex;
                var functionReturnTypeIdx: u32 = 0;
                while (container != 0) {
                    const parentIdx = self.binder.ast.getNodeParent(container);
                    container = parentIdx;
                    if (container == 0) break;

                    const containerData = self.binder.ast.getNode(container);
                    if (std.meta.activeTag(containerData) == .FunctionDeclaration) {
                        const f = containerData.FunctionDeclaration;
                        if (f.Type) |t| {
                            functionReturnTypeIdx = try self.getTypeOfNode(t);
                        } else {
                            functionReturnTypeIdx = try self.getAnyType();
                        }
                        break;
                    }
                }

                if (functionReturnTypeIdx != 0) {
                    if (!try self.isTypeAssignableTo(exprTypeIdx, functionReturnTypeIdx)) {
                        const diag = diagnostics.Diagnostic{
                            .nodeIndex = if (ret.Expression != null) ret.Expression.? else nodeIndex,
                            .message = &diagnostics_gen.Type_0_is_not_assignable_to_type_1,
                        };
                        self.addDiagnostic(diag);
                    }
                }
            },

            // Expression statement
            .ExpressionStatement => |es| {
                _ = try self.checkExpression(es.Expression);
            },

            // If statement
            .IfStatement => |ifs| {
                _ = try self.checkExpression(ifs.Expression);
                try self.checkStatement(ifs.ThenStatement);
                if (ifs.ElseStatement) |elseStmt| {
                    try self.checkStatement(elseStmt);
                }
            },

            // While loop
            .WhileStatement => |ws| {
                _ = try self.checkExpression(ws.Expression);
                try self.checkStatement(ws.Statement);
            },

            // Do-while loop
            .DoStatement => |ds| {
                try self.checkStatement(ds.Statement);
                _ = try self.checkExpression(ds.Expression);
            },

            // For loop
            .ForStatement => |fs| {
                if (fs.Initializer) |initializer_node| {
                    // init can be variable declaration list or expression
                    const initNode = self.binder.ast.getNode(initializer_node);
                    switch (initNode) {
                        .VariableDeclarationList => try self.checkStatement(initializer_node),
                        else => _ = try self.checkExpression(initializer_node),
                    }
                }
                if (fs.Condition) |cond| {
                    _ = try self.checkExpression(cond);
                }
                if (fs.Incrementor) |incr| {
                    _ = try self.checkExpression(incr);
                }
                try self.checkStatement(fs.Statement);
            },

            // For-in / For-of
            .ForInStatement, .ForOfStatement => |fio| {
                _ = try self.checkExpression(fio.Expression);
                try self.checkStatement(fio.Statement);
            },

            // Switch
            .SwitchStatement => |ss| {
                _ = try self.checkExpression(ss.Expression);
                try self.checkStatement(ss.CaseBlock);
            },
            .CaseBlock => |cb| {
                if (cb.Clauses != 0) {
                    const clauses = self.binder.ast.getNodeList(cb.Clauses);
                    for (clauses) |clause| {
                        try self.checkStatement(clause);
                    }
                }
            },
            .CaseClause => |cc| {
                _ = try self.checkExpression(cc.Expression);
                if (cc.Statements != 0) {
                    const stmts = self.binder.ast.getNodeList(cc.Statements);
                    for (stmts) |stmt| {
                        try self.checkStatement(stmt);
                    }
                }
            },
            .DefaultClause => |dc| {
                if (dc.Statements != 0) {
                    const stmts = self.binder.ast.getNodeList(dc.Statements);
                    for (stmts) |stmt| {
                        try self.checkStatement(stmt);
                    }
                }
            },

            // Throw
            .ThrowStatement => |ts| {
                _ = try self.checkExpression(ts.Expression);
            },

            // Try-catch-finally
            .TryStatement => |ts| {
                try self.checkStatement(ts.TryBlock);
                if (ts.CatchClause) |catchNode| {
                    try self.checkStatement(catchNode);
                }
                if (ts.FinallyBlock) |finallyNode| {
                    try self.checkStatement(finallyNode);
                }
            },
            .CatchClause => |cc| {
                try self.checkStatement(cc.Block);
            },

            // Classes
            .ClassDeclaration => |cd| {
                if (cd.Members != 0) {
                    const members = self.binder.ast.getNodeList(cd.Members);
                    for (members) |mem| {
                        try self.checkStatement(mem);
                    }
                }
            },
            .MethodDeclaration => |m| {
                if (m.Body) |body| {
                    try self.checkStatement(body);
                }
                if (m.Parameters != 0) {
                    const params = self.binder.ast.getNodeList(m.Parameters);
                    for (params) |param| {
                        _ = try self.getTypeOfNode(param);
                    }
                }
            },
            .Constructor => {},
            .GetAccessor => |ga| {
                if (ga.Body) |body| {
                    try self.checkStatement(body);
                }
            },
            .SetAccessor => |sa| {
                if (sa.Body) |body| {
                    try self.checkStatement(body);
                }
            },
            .PropertyDeclaration => |pd| {
                if (pd.Initializer) |pd_init| {
                    _ = try self.checkExpression(pd_init);
                }
            },

            // Labeled statement
            .LabeledStatement => |ls| {
                try self.checkStatement(ls.Statement);
            },

            // Export assignment: export = expr
            .ExportAssignment => |ea| {
                _ = try self.checkExpression(ea.Expression);
            },

            // ExpressionStatement cho arrow/function expressions
            .ArrowFunction, .FunctionExpression => {
                _ = try self.checkExpression(nodeIndex);
            },

            // Import/Export declarations (no type checking needed here)
            .ImportDeclaration, .ExportDeclaration, .JSImportDeclaration => {},

            // Interface/TypeAlias: type-only, no runtime checking
            .InterfaceDeclaration, .TypeAliasDeclaration, .JSTypeAliasDeclaration => {},

            // Enum
            .EnumDeclaration => |ed| {
                if (ed.Members != 0) {
                    const members = self.binder.ast.getNodeList(ed.Members);
                    for (members) |mem| {
                        const memNode = self.binder.ast.getNode(mem);
                        switch (memNode) {
                            .EnumMember => |em| {
                                if (em.Initializer) |initIdx| {
                                    _ = try self.checkExpression(initIdx);
                                }
                            },
                            else => {},
                        }
                    }
                }
            },

            // break / continue / debugger: nothing to check
            .BreakStatement, .ContinueStatement, .DebuggerStatement, .EmptyStatement => {},

            // Module block
            .ModuleBlock => |mb| {
                if (mb.Statements != 0) {
                    const stmts = self.binder.ast.getNodeList(mb.Statements);
                    for (stmts) |stmt| {
                        try self.checkStatement(stmt);
                    }
                }
            },

            // Property assignment trong object literal
            .PropertyAssignment => |pa| {
                _ = try self.checkExpression(pa.Initializer);
            },
            .ShorthandPropertyAssignment => |spa| {
                if (spa.ObjectAssignmentInitializer) |initExpr| {
                    _ = try self.checkExpression(initExpr);
                }
            },

            else => {},
        }
    }
    pub fn getTypesOfUnionOrIntersectionType(c: *Checker, t: types.TypeIndex) []const types.TypeIndex {
        _ = c;
        _ = t;
        return &[_]types.TypeIndex{}; // Stub
    }

    pub fn containsType(c: *Checker, typesList: []const types.TypeIndex, t: types.TypeIndex) bool {
        _ = c;
        _ = typesList;
        _ = t;
        return false; // Stub
    }

    pub fn getSymbolOfDeclaration(c: *Checker, decl: ast_gen.NodeIndex) types.symbolIndex {
        _ = c;
        _ = decl;
        return 0; // Stub
    }

    pub fn getSymbolCheckFlags(c: *Checker, sym: types.symbolIndex) u32 {
        _ = c;
        _ = sym;
        return 0; // Stub
    }

    pub fn computeEnumMemberValues(c: *Checker, node: ast_gen.NodeIndex) void {
        _ = c;
        _ = node;
    }

    pub fn getOriginOfUnionType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return 0; // Stub
    }

    pub fn getRegularTypeOfObjectLiteral(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return 0; // Stub
    }

    pub fn getRegularTypeOfLiteralType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return 0; // Stub
    }

    pub fn getFreshTypeOfLiteralType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return 0; // Stub
    }

    pub fn getMatchingUnionConstituentForType(c: *Checker, target: types.TypeIndex, source: types.TypeIndex) ?types.TypeIndex {
        _ = c;
        _ = target;
        _ = source;
        return null; // Stub
    }

    pub fn getBestMatchingType(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, comptime isRelatedToSimple: fn (ctx: anytype, source: types.TypeIndex, target: types.TypeIndex) types.Ternary) ?types.TypeIndex {
        _ = c;
        _ = source;
        _ = target;
        _ = isRelatedToSimple;
        return null; // Stub
    }

    pub fn findDiscriminantProperties(c: *Checker, sourceProperties: []const types.symbolIndex, target: types.TypeIndex) []const types.symbolIndex {
        _ = c;
        _ = sourceProperties;
        _ = target;
        return &[_]types.symbolIndex{}; // Stub
    }

    pub fn countTypes(c: *Checker, t: types.TypeIndex) usize {
        _ = c;
        _ = t;
        return 0; // Stub
    }

    pub fn distributedTypes(c: *Checker, t: types.TypeIndex) []const types.TypeIndex {
        _ = c;
        _ = t;
        return &[_]types.TypeIndex{}; // Stub
    }

    pub fn appendIfUniqueTypeIndex(c: *Checker, list: *std.ArrayList(types.TypeIndex), item: types.TypeIndex) void {
        _ = c;
        _ = list;
        _ = item;
        // Stub
    }

    pub fn getStartElementCount(c: *Checker, tupleType: *types.TupleType, flags: u32) usize {
        _ = c;
        _ = tupleType;
        _ = flags;
        return 0; // Stub
    }

    pub fn getEndElementCount(c: *Checker, tupleType: *types.TupleType, flags: u32) usize {
        _ = c;
        _ = tupleType;
        _ = flags;
        return 0; // Stub
    }

    pub fn removeMissingType(c: *Checker, t: types.TypeIndex, optional: bool) types.TypeIndex {
        _ = c;
        _ = t;
        _ = optional;
        return 0; // Stub
    }

    pub fn shouldReportUnmatchedPropertyError(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
        _ = c;
        _ = source;
        _ = target;
        return false; // Stub
    }

    pub fn getSymbolFlags(c: *Checker, sym: types.symbolIndex) u32 {
        _ = c;
        _ = sym;
        return 0; // Stub
    }

    pub fn isTypeRelatedTo(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, relation: *const relater.Relation) bool {
        _ = c;
        _ = source;
        _ = target;
        _ = relation;
        return false; // Stub
    }

    pub fn isSetAccessorSymbol(c: *Checker, sym: types.symbolIndex) bool {
        _ = c;
        _ = sym;
        return false; // Stub
    }

    pub fn isGetAccessorSymbol(c: *Checker, sym: types.symbolIndex) bool {
        _ = c;
        _ = sym;
        return false; // Stub
    }

    pub fn getErasedSignature(c: *Checker, signature: *types.Signature) *types.Signature {
        _ = c;
        return signature; // Stub
    }

    pub fn compareSignaturesRelated(c: *Checker, source: *types.Signature, target: *types.Signature, checkMode: types.SignatureCheckMode, reportErrors: bool, reportErrCtx: anytype, comptime reportErrFn: fn (ctx: @TypeOf(reportErrCtx), msg: types.DiagnosticMessage) void, isRelatedCtx: anytype, comptime isRelatedFn: fn (ctx: @TypeOf(isRelatedCtx), source: types.TypeIndex, target: types.TypeIndex, reportErrors: bool) types.Ternary, reportUnreliableCtx: anytype, comptime reportUnreliableFn: fn (ctx: @TypeOf(reportUnreliableCtx)) void) types.Ternary {
        _ = c;
        _ = source;
        _ = target;
        _ = checkMode;
        _ = reportErrors;
        _ = reportErrFn;
        _ = isRelatedFn;
        _ = reportUnreliableFn;
        return .False; // Stub
    }

    pub fn isObjectTypeWithInferableIndex(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false; // Stub
    }

    pub fn getIndexInfosOfType(c: *Checker, t: types.TypeIndex) []const types.IndexInfoIndex {
        _ = c;
        _ = t;
        return &[_]types.IndexInfoIndex{}; // Stub
    }

    pub fn getApplicableIndexInfo(c: *Checker, t: types.TypeIndex, keyType: types.TypeIndex) ?types.IndexInfoIndex {
        _ = c;
        _ = t;
        _ = keyType;
        return null; // Stub
    }

    pub fn compareSignaturesIdentical(c: *Checker, source: *types.Signature, target: *types.Signature, partialMatch: bool, ignoreThisTypes: bool, ignoreReturnTypes: bool, isRelatedCtx: anytype, comptime isRelatedFn: fn (ctx: @TypeOf(isRelatedCtx), source: types.TypeIndex, target: types.TypeIndex) types.Ternary) types.Ternary {
        _ = c;
        _ = source;
        _ = target;
        _ = partialMatch;
        _ = ignoreThisTypes;
        _ = ignoreReturnTypes;
        _ = isRelatedFn;
        return .False; // Stub
    }

    pub fn getIndexInfoKeyType(c: *Checker, info: types.IndexInfoIndex) types.TypeIndex {
        _ = c;
        _ = info;
        return 0; // Stub
    }

    pub fn getIndexInfoValueType(c: *Checker, info: types.IndexInfoIndex) types.TypeIndex {
        _ = c;
        _ = info;
        return 0; // Stub
    }

    pub fn isIgnoredJsxProperty(c: *Checker, source: types.TypeIndex, prop: types.symbolIndex) bool {
        _ = c;
        _ = source;
        _ = prop;
        return false; // Stub
    }

    pub fn isApplicableIndexType(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
        _ = c;
        _ = source;
        _ = target;
        return false; // Stub
    }

    pub fn getLiteralTypeFromProperty(c: *Checker, prop: types.symbolIndex, include: u32, stringify: bool) types.TypeIndex {
        _ = c;
        _ = prop;
        _ = include;
        _ = stringify;
        return 0; // Stub
    }

    pub fn getNonMissingTypeOfSymbol(c: *Checker, prop: types.symbolIndex) types.TypeIndex {
        _ = c;
        _ = prop;
        return 0; // Stub
    }

    pub fn getTypeWithFacts(c: *Checker, t: types.TypeIndex, facts: types.TypeFacts) types.TypeIndex {
        _ = c;
        _ = t;
        _ = facts;
        return 0; // Stub
    }

    pub fn getIndexInfoOfType(c: *Checker, source: types.TypeIndex, keyType: types.TypeIndex) ?types.IndexInfoIndex {
        _ = c;
        _ = source;
        _ = keyType;
        return null; // Stub
    }

    pub fn getIndexInfoIsReadonly(c: *Checker, info: types.IndexInfoIndex) bool {
        _ = c;
        _ = info;
        return false; // Stub
    }

    pub fn isTypeDerivedFrom(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
        const sourceFlags = c.getTypeFlags(source);
        const targetFlags = c.getTypeFlags(target);

        if (sourceFlags & types.TypeFlags.Union != 0) {
            const typesArr = c.getTypes(source);
            for (typesArr) |t| {
                if (!c.isTypeDerivedFrom(t, target)) {
                    return false;
                }
            }
            return true;
        } else if (targetFlags & types.TypeFlags.Union != 0) {
            const typesArr = c.getTypes(target);
            for (typesArr) |t| {
                if (c.isTypeDerivedFrom(source, t)) {
                    return true;
                }
            }
            return false;
        } else if (sourceFlags & types.TypeFlags.Intersection != 0) {
            const typesArr = c.getTypes(source);
            for (typesArr) |t| {
                if (c.isTypeDerivedFrom(t, target)) {
                    return true;
                }
            }
            return false;
        } else if (sourceFlags & types.TypeFlags.InstantiableNonPrimitive != 0) {
            var constraint = c.getBaseConstraintOfType(source);
            if (constraint == null) {
                constraint = c.unknownType;
            }
            return c.isTypeDerivedFrom(constraint.?, target);
        } else if (c.isEmptyAnonymousObjectType(target)) {
            return sourceFlags & (types.TypeFlags.Object | types.TypeFlags.NonPrimitive) != 0;
        } else if (target == c.globalObjectType) {
            return sourceFlags & (types.TypeFlags.Object | types.TypeFlags.NonPrimitive) != 0 and !c.isEmptyAnonymousObjectType(source);
        } else if (target == c.globalFunctionType) {
            return sourceFlags & types.TypeFlags.Object != 0 and c.isFunctionObjectType(source);
        } else {
            return c.hasBaseType(source, c.getTargetType(target)) or (c.isArrayType(target) and !c.isReadonlyArrayType(target) and c.isTypeDerivedFrom(source, c.globalReadonlyArrayType));
        }
    }

    pub fn isEmptyAnonymousObjectType(c: *Checker, t: types.TypeIndex) bool {
        if (t >= c.typesList.items.len) return false;
        const ty = c.typesList.items[t];
        return ty.data == .Object and
            (ty.objectFlags & types.ObjectFlags.Anonymous) != 0 and
            ty.data.Object.propertiesLen == 0;
    }

    pub fn isFunctionObjectType(c: *Checker, t: types.TypeIndex) bool {
        return t < c.typesList.items.len and c.typesList.items[t].data == .Function;
    }

    pub fn isArrayType(c: *Checker, t: types.TypeIndex) bool {
        return t < c.typesList.items.len and c.typesList.items[t].data == .Array;
    }

    pub fn isReadonlyArrayType(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false; // Stub
    }

    pub fn hasBaseType(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
        _ = c;
        _ = source;
        _ = target;
        return false; // Stub
    }

    pub fn isDistributionDependent(c: *Checker, root: *types.ConditionalRoot) bool {
        return root.isDistributive and (c.isTypeParameterPossiblyReferenced(root.checkType, root.node.TrueType) or c.isTypeParameterPossiblyReferenced(root.checkType, root.node.FalseType));
    }

    pub fn isTypeParameterPossiblyReferenced(c: *Checker, tp: types.TypeIndex, node: types.NodeIndex) bool {
        _ = c;
        _ = tp;
        _ = node;
        return false; // Stub
    }

    pub fn getValueDeclarationOfSymbol(c: *Checker, sym: types.symbolIndex) ast_gen.NodeIndex {
        if (sym >= c.binder.symbols.items.len) return 0;
        return c.binder.symbols.items[sym].ValueDeclaration orelse 0;
    }

    pub fn getFirstDeclarationOfSymbol(c: *Checker, sym: types.symbolIndex) ast_gen.NodeIndex {
        if (sym >= c.binder.symbols.items.len) return 0;
        const declarations = c.binder.symbols.items[sym].Declarations.items;
        return if (declarations.len == 0) 0 else declarations[0];
    }

    pub fn getNodeKind(c: *Checker, node: ast_gen.NodeIndex) ast_gen.SyntaxKind {
        _ = c;
        _ = node;
        return .Unknown; // Stub
    }

    pub fn getWriteTypeOfSymbol(c: *Checker, sym: types.symbolIndex) types.TypeIndex {
        _ = sym;
        return c.anyTypeIndex orelse 0; // Stub
    }

    pub fn getWidenedLiteralType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        return t; // Stub
    }

    pub fn getTypeFlags(c: *Checker, t: types.TypeIndex) u32 {
        return if (t < c.typesList.items.len) c.typesList.items[t].flags else types.TypeFlags.None;
    }

    pub fn getSymbolOfType(c: *Checker, t: types.TypeIndex) types.symbolIndex {
        if (t >= c.typesList.items.len) return 0;
        return c.typesList.items[t].symbol orelse 0;
    }

    pub fn reportUnreliableMapperStub(c: *Checker) void {
        _ = c; // Stub
    }
};

fn containsTypeIndex(items: []const types.TypeIndex, needle: types.TypeIndex) bool {
    for (items) |item| if (item == needle) return true;
    return false;
}

test "checker models tuple array and union types without collapsing to any" {
    const parser = @import("../parser/parser.zig");
    var parsed = parser.Parser.init(std.testing.allocator,
        \\type Pair = [number, string];
        \\const values: (number | string)[] = [1, "x"];
        \\const pair: Pair = [1, "x"];
    );
    defer parsed.deinit();
    const source_file = try parsed.parseSourceFile();
    var bound = try binder.Binder.init(std.testing.allocator, &parsed.ast);
    defer bound.deinit();
    try bound.bindSourceFile(source_file);
    var checker = Checker.init(std.testing.allocator, &bound);
    defer checker.deinit();

    const statements = parsed.ast.getNodeList(parsed.ast.getNode(source_file).SourceFile.Statements);
    const pair_type_node = parsed.ast.getNode(statements[0]).TypeAliasDeclaration.Type;
    const pair_type = try checker.getTypeOfNode(pair_type_node);
    try std.testing.expect(checker.typesList.items[pair_type].data == .Tuple);
    try std.testing.expectEqual(@as(u32, 2), checker.typesList.items[pair_type].data.Tuple.typesLen);

    const declaration_list = parsed.ast.getNode(statements[1]).VariableStatement.DeclarationList;
    const declaration = parsed.ast.getNodeList(parsed.ast.getNode(declaration_list).VariableDeclarationList.Declarations)[0];
    const array_type = try checker.getTypeOfNode(parsed.ast.getNode(declaration).VariableDeclaration.Type.?);
    try std.testing.expect(checker.typesList.items[array_type].data == .Array);
    const element_type = checker.typesList.items[array_type].data.Array.elementType;
    try std.testing.expect(checker.typesList.items[element_type].flags & types.TypeFlags.Union != 0);

    const inferred_array = try checker.checkExpression(parsed.ast.getNode(declaration).VariableDeclaration.Initializer.?);
    try std.testing.expect(checker.typesList.items[inferred_array].data == .Array);
    const inferred_element = checker.typesList.items[inferred_array].data.Array.elementType;
    try std.testing.expect(checker.typesList.items[inferred_element].flags & types.TypeFlags.Union != 0);

    const pair_declaration_list = parsed.ast.getNode(statements[2]).VariableStatement.DeclarationList;
    const pair_declaration = parsed.ast.getNodeList(parsed.ast.getNode(pair_declaration_list).VariableDeclarationList.Declarations)[0];
    const referenced_pair = try checker.getTypeOfNode(parsed.ast.getNode(pair_declaration).VariableDeclaration.Type.?);
    try std.testing.expect(checker.typesList.items[referenced_pair].data == .Tuple);
}

test "checker infers merged JavaScript this-property assignment types" {
    const parser = @import("../parser/parser.zig");
    var parsed = parser.Parser.init(std.testing.allocator,
        \\class Box {
        \\  constructor(flag) {
        \\    this.value = 1;
        \\    if (flag) this.value = "ready";
        \\  }
        \\}
    );
    defer parsed.deinit();
    parsed.setScriptKind(.JS);
    const source_file = try parsed.parseSourceFile();
    var bound = try binder.Binder.init(std.testing.allocator, &parsed.ast);
    defer bound.deinit();
    try bound.bindSourceFile(source_file);
    var checker = Checker.init(std.testing.allocator, &bound);
    defer checker.deinit();

    const statements = parsed.ast.getNodeList(parsed.ast.getNode(source_file).SourceFile.Statements);
    const class_symbol = parsed.ast.getNodeSymbol(statements[0]) orelse return error.ExpectedClassSymbol;
    const members = bound.symbolMembers.getPtr(class_symbol) orelse return error.ExpectedClassMembers;
    const value_symbol = members.get("value") orelse return error.ExpectedValueMember;
    const value_type = try checker.getTypeOfSymbol(value_symbol);
    try std.testing.expect(checker.typesList.items[value_type].flags & types.TypeFlags.Union != 0);
    const value_union = checker.typesList.items[value_type].data.Union;
    try std.testing.expectEqual(@as(u32, 2), value_union.typesLen);
}
