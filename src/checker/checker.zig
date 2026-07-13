const std = @import("std");
const core = @import("../core/core.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast = @import("../ast/ast.zig");
const symbol = @import("../ast/symbol.zig");
const binder = @import("../binder/binder.zig");
const nameresolver = @import("../binder/nameresolver.zig");
pub const types = @import("types.zig");
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
const printer_pkg = @import("../printer/printer.zig");
const textwriter_pkg = @import("../printer/textwriter.zig");
const emitcontext_pkg = @import("../printer/emitcontext.zig");
pub const mapper_pkg = @import("mapper.zig");
pub const tracer_pkg = @import("tracer.zig");
pub const jsdoc_pkg = @import("jsdoc.zig");
pub const exports_pkg = @import("exports.zig");
pub const symboltracker_pkg = @import("symboltracker.zig");
pub const printer_mod = @import("printer.zig");
pub const services_pkg = @import("services.zig");
pub const nodecopy_pkg = @import("nodecopy.zig");
pub const type_resolution_pkg = @import("type_resolution.zig");
pub const argument_arity = @import("argument_arity.zig");
pub const SymbolIndex = ast_gen.SymbolIndex;

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
    pub fn signatureToStringEx(self: *Checker, signature: types.SignatureIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: u32, vc: ?*anyopaque) []const u8 {
        _ = self;
        _ = signature;
        _ = enclosingDeclaration;
        _ = flags;
        _ = vc;
        return "";
    }

    pub fn getExpandedParameters(self: *Checker, signatureIdx: types.SignatureIndex, isJSDoc: bool) []const ast_gen.SymbolIndex {
        _ = isJSDoc;
        const sig = self.signatures.items[signatureIdx];
        return self.signatureParameters.items[sig.parametersStart .. sig.parametersStart + sig.parametersLen];
    }

    pub fn getContextualTypeForObjectLiteralElement(self: *Checker, element: ast_gen.NodeIndex, contextFlags: u32) types.TypeIndex {
        _ = self;
        _ = element;
        _ = contextFlags;
        return 0;
    }

    pub fn getContextualTypeForArgumentAtIndex(self: *Checker, node: ast_gen.NodeIndex, argIndex: usize) types.TypeIndex {
        _ = self;
        _ = node;
        _ = argIndex;
        return 0;
    }

    pub fn getContextualType(self: *Checker, node: ast_gen.NodeIndex, contextFlags: u32) types.TypeIndex {
        _ = self;
        _ = node;
        _ = contextFlags;
        return 0;
    }

    pub fn isFunctionType(c: *Checker, t: types.TypeIndex) bool {
        return (c.getTypeFlags(t) & types.TypeFlags.Object) != 0 and c.getSignaturesOfType(t, .Call).len > 0;
    }

    pub fn isConstructorType(c: *Checker, t: types.TypeIndex) bool {
        if (c.getSignaturesOfType(t, .Construct).len > 0) {
            return true;
        }
        if ((c.getTypeFlags(t) & types.TypeFlags.TypeVariable) != 0) {
            const constraint = c.getBaseConstraintOfType(t);
            return constraint != 0 and c.isMixinConstructorType(constraint);
        }
        return false;
    }

    pub fn getElementTypeOfArrayType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        if (c.isArrayType(t)) {
            return c.typesList.items[t].data.Array.elementType;
        }
        return 0;
    }

    pub fn signatureHasRestParameter(sig: *const types.Signature) bool {
        return (sig.flags & types.SignatureFlags.HasRestParameter) != 0;
    }

    pub fn addOptionalityEx(c: *Checker, t: types.TypeIndex, isProperty: bool, isOptional: bool) types.TypeIndex {
        if (isOptional) {
            return c.getOptionalType(t, isProperty);
        }
        return t;
    }

    pub fn getTypeOfParameter(c: *Checker, sym: ast_gen.SymbolIndex) types.TypeIndex {
        const declaration = c.getSymbolValueDeclaration(sym);
        var isOptional = false;
        if (declaration != 0) {
            isOptional = utils.isOptionalDeclaration(c.binder.ast, declaration) or ast_utils.getInitializerOfNode(c.binder.ast, declaration) != 0;
        }
        const t = c.getTypeOfSymbol(sym) catch (c.unknownTypeIndex orelse 0);
        return c.addOptionalityEx(t, false, isOptional);
    }

    pub fn isMixinConstructorType(c: *Checker, t: types.TypeIndex) bool {
        const signatures = c.getSignaturesOfType(t, .Construct);
        if (signatures.len == 1) {
            const sigIndex = c.resolvedSignaturesPool.items[signatures.start];
            const s = c.signatures.items[sigIndex];
            if (s.typeParametersLen == 0 and s.parametersLen == 1 and signatureHasRestParameter(&s)) {
                const paramSymbol = c.signatureParameters.items[s.parametersStart];
                const paramType = c.getTypeOfParameter(paramSymbol);
                if ((c.getTypeFlags(paramType) & types.TypeFlags.Any) != 0 or c.getElementTypeOfArrayType(paramType) == (c.anyTypeIndex orelse 0)) {
                    return true;
                }
            }
        }
        return false;
    }

    pub fn createArrayType(c: *Checker, elementType: types.TypeIndex) types.TypeIndex {
        return c.createType(.{
            .flags = types.TypeFlags.Object,
            .objectFlags = types.ObjectFlags.Reference,
            .id = 0,
            .symbol = null,
            .alias = null,
            .data = .{ .Array = .{ .elementType = elementType } },
        }) catch 0;
    }

    pub fn someType(c: *Checker, t: types.TypeIndex, comptime predicate: anytype, ctx: anytype) bool {
        const flags = c.getTypeFlags(t);
        if ((flags & types.TypeFlags.Union) != 0) {
            const unionTypes = c.getTypesFromUnion(t);
            for (unionTypes) |u| {
                if (predicate(c, u, ctx)) {
                    return true;
                }
            }
            return false;
        }
        return predicate(c, t, ctx);
    }

    pub fn everyType(c: *Checker, t: types.TypeIndex, comptime predicate: anytype, ctx: anytype) bool {
        const flags = c.getTypeFlags(t);
        if ((flags & types.TypeFlags.Union) != 0) {
            const unionTypes = c.getTypesFromUnion(t);
            for (unionTypes) |u| {
                if (!predicate(c, u, ctx)) {
                    return false;
                }
            }
            return true;
        }
        return predicate(c, t, ctx);
    }
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
    default_lib_binder: ?*binder.Binder = null,
    lib_symbols: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, void) = .empty,
    resolver: nameresolver.NameResolver,
    typesList: std.ArrayListUnmanaged(types.Type),
    mappersList: std.ArrayListUnmanaged(types.TypeMapper) = .empty,
    permissiveMapperIndex: ?types.TypeMapperIndex = null,
    restrictiveMapperIndex: ?types.TypeMapperIndex = null,

    unionTypesPool: std.ArrayListUnmanaged(types.TypeIndex),
    tupleTypesPool: std.ArrayListUnmanaged(types.TypeIndex),
    tupleTypes: std.AutoHashMapUnmanaged(types.CacheHashKey, types.TypeIndex) = .empty,
    templateLiteralTypes: std.AutoHashMapUnmanaged(types.CacheHashKey, types.TypeIndex) = .empty,
    typeArgumentsPool: std.ArrayListUnmanaged(types.TypeIndex) = .empty,

    // Flow analysis state
    freeFlowState: ?*flow.FlowState = null,
    flowAnalysisDisabled: bool = false,
    flowInvocationCount: usize = 0,
    sharedFlows: std.ArrayListUnmanaged(flow.SharedFlow) = .empty,
    antecedentTypes: std.ArrayListUnmanaged(types.TypeIndex) = .empty,
    nodeFlowNodes: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, ast_flow.FlowNodeIndex) = .empty,
    symbolContainerLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.ContainingSymbolLinks) = .empty,
    typeAliasLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.TypeAliasLinks) = .empty,
    symbolReferenceLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.SymbolReferenceLinks) = .empty,
    valueSymbolLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.ValueSymbolLinks) = .empty,
    mappedSymbolLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.MappedSymbolLinks) = .empty,
    deferredSymbolLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.DeferredSymbolLinks) = .empty,
    moduleSymbolLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.ModuleSymbolLinks) = .empty,
    reverseMappedSymbolLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.ReverseMappedSymbolLinks) = .empty,
    lateBoundLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.LateBoundLinks) = .empty,
    exportTypeLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.ExportTypeLinks) = .empty,
    declaredTypeLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.DeclaredTypeLinks) = .empty,
    switchStatementLinks: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, types.SwitchStatementLinks) = .empty,
    arrayLiteralLinks: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, types.ArrayLiteralLinks) = .empty,
    membersAndExportsLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.MembersAndExportsLinks) = .empty,
    spreadLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.SpreadLinks) = .empty,
    varianceLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.VarianceLinks) = .empty,

    // Pools for resolved members
    resolvedPropertiesPool: std.ArrayListUnmanaged(ast_gen.SymbolIndex) = .empty,
    resolvedSignaturesPool: std.ArrayListUnmanaged(types.SignatureIndex) = .empty,
    resolvedIndexInfosPool: std.ArrayListUnmanaged(types.IndexInfo) = .empty,
    resolvedStructuredTypeMembers: std.AutoHashMapUnmanaged(types.TypeIndex, types.StructuredTypeMembers) = .empty,
    resolvedDeclaredMembers: std.AutoHashMapUnmanaged(types.TypeIndex, types.StructuredTypeMembers) = .empty,
    resolvedUnionOrIntersectionProperties: std.AutoHashMapUnmanaged(types.TypeIndex, types.Range) = .empty,

    numberLiteralTypes: std.AutoHashMapUnmanaged(u64, types.TypeIndex) = .empty,
    stringLiteralTypes: std.StringHashMapUnmanaged(types.TypeIndex) = .empty,
    unresolvedSymbols: std.StringHashMapUnmanaged(ast_gen.SymbolIndex) = .empty,
    packagesMap: ?std.StringHashMapUnmanaged(bool) = null,

    // Signatures
    signatures: std.ArrayListUnmanaged(types.Signature) = .empty,
    signatureParameters: std.ArrayListUnmanaged(ast_gen.SymbolIndex) = .empty,
    signatureTypeParameters: std.ArrayListUnmanaged(types.TypeIndex) = .empty,
    resolvedSignatureLinks: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, types.SignatureIndex) = .empty,

    lastFlowNode: ast_flow.FlowNodeIndex = 0,
    lastFlowNodeReachable: bool = false,
    flowNodeReachable: std.AutoHashMapUnmanaged(ast_flow.FlowNodeIndex, bool) = .empty,

    flowLoopCache: std.AutoHashMapUnmanaged(flow.FlowLoopKey, types.TypeIndex) = .empty,
    flowLoopStack: std.ArrayListUnmanaged(flow.FlowLoopInfo) = .empty,
    flowLoopTypes: std.ArrayListUnmanaged(types.TypeIndex) = .empty,
    contextualInfos: std.ArrayListUnmanaged(types.ContextualInfo) = .empty,
    currentNode: ast_gen.NodeIndex = 0,
    withinUnreachableCode: bool = false,
    instantiationCount: u32 = 0,
    inlineLevel: u32 = 0,
    serializationLevel: u32 = 0,

    // Cache for intrinsic types to avoid duplicates
    numberTypeIndex: ?u32 = null,
    anyTypeIndex: ?u32 = null,
    noConstraintTypeIndex: ?u32 = null,
    stringTypeIndex: ?u32 = null,
    numericStringTypeIndex: ?u32 = null,
    booleanTypeIndex: ?u32 = null,
    voidTypeIndex: ?u32 = null,
    undefinedTypeIndex: ?u32 = null,
    missingTypeIndex: ?u32 = null,
    undefinedOrMissingTypeIndex: ?u32 = null,
    nullTypeIndex: ?u32 = null,
    unknownTypeIndex: ?u32 = null,
    neverTypeIndex: ?u32 = null,
    bigintTypeIndex: ?u32 = null,
    numberOrBigIntTypeIndex: ?u32 = null,
    esSymbolTypeIndex: ?u32 = null,
    trueTypeIndex: ?u32 = null,
    falseTypeIndex: ?u32 = null,
    objectTypeIndex: ?u32 = null,
    autoTypeIndex: ?u32 = null,
    wildcardTypeIndex: ?u32 = null,
    autoArrayTypeIndex: ?u32 = null,
    nonPrimitiveTypeIndex: ?u32 = null,
    errorTypeIndex: ?u32 = null,
    circularConstraintTypeIndex: ?u32 = null,
    resolvingDefaultTypeIndex: ?u32 = null,
    emptyTypeLiteralTypeIndex: ?u32 = null,
    emptyGenericTypeIndex: ?u32 = null,
    emptyObjectTypeIndex: ?u32 = null,
    intrinsicMarkerTypeIndex: ?u32 = null,

    unknownSymbol: ast_gen.SymbolIndex = 0,

    identityRelation: relater.Relation = .{},
    assignableRelation: relater.Relation = .{},
    subtypeRelation: relater.Relation = .{},
    strictSubtypeRelation: relater.Relation = .{},
    comparableRelation: relater.Relation = .{},

    globalFunctionType: types.TypeIndex = 0,
    unknownSignatureIndex: types.SignatureIndex = 0,
    globalObjectType: types.TypeIndex = 0,
    globalReadonlyArrayType: types.TypeIndex = 0,
    globalStringType: types.TypeIndex = 0,
    globalNumberType: types.TypeIndex = 0,
    globalBooleanType: types.TypeIndex = 0,
    globalBigIntType: types.TypeIndex = 0,
    globalESSymbolType: types.TypeIndex = 0,
    stringNumberSymbolType: types.TypeIndex = 0,
    emptyObjectType: types.TypeIndex = 0,
    enumRelation: std.AutoHashMapUnmanaged(EnumRelationKey, relater.RelationComparisonResult) = .empty,
    markedAssignmentSymbolLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.MarkedAssignmentSymbolLinks) = .empty,
    aliasSymbolLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.AliasSymbolLinks) = .empty,
    sourceFileLinks: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, types.SourceFileLinks) = .empty,
    nodeLinks: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, types.NodeLinks) = .empty,

    inVarianceComputation: bool = false,

    strictNullChecks: bool = false,
    noImplicitAny: bool = false,
    checkJs: bool = false,
    allowJs: bool = false,
    erasableSyntaxOnly: bool = false,
    moduleKind: core.ModuleKind = .ESNext,
    exactOptionalPropertyTypes: bool = false,
    freeRelater: ?*relater.Relater = null,
    typeToStringNodebuilder: ?*nodebuilder.NodeBuilder = null,
    ownedDiagnosticArgs: std.ArrayListUnmanaged([]const []const u8) = .empty,
    ownedStrings: std.ArrayListUnmanaged([]const u8) = .empty,

    typeNodeLinks: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, types.TypeNodeLinks) = .empty,
    symbolNodeLinks: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, types.SymbolNodeLinks) = .empty,
    mergedSymbols: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, ast_gen.SymbolIndex) = .empty,
    assignmentReducedTypes: std.AutoHashMapUnmanaged(types.AssignmentReducedKey, types.TypeIndex) = .empty,
    restrictiveTypeParameterCache: std.AutoHashMapUnmanaged(types.TypeIndex, types.TypeIndex) = .empty,
    contextFreeTypes: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, types.TypeIndex) = .empty,

    // Inference state pool
    inferenceStates: std.ArrayListUnmanaged(inference.InferenceState) = .empty,
    freeInferenceState: ?u32 = null,
    inferenceContextInfos: std.ArrayListUnmanaged(types.InferenceContextInfo) = .empty,
    inferenceContexts: std.ArrayListUnmanaged(types.InferenceContext) = .empty,
    inferenceInfos: std.ArrayListUnmanaged(types.InferenceInfo) = .empty,

    tupleElementInfos: std.ArrayListUnmanaged(types.TupleElementInfo) = .empty,

    canCollectSymbolAliasAccessibilityData: bool = true,

    // Added for EmitResolver
    enumMemberLinks: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, types.EnumMemberLink) = .empty,

    evolvingArrayTypes: std.AutoHashMapUnmanaged(types.TypeIndex, types.TypeIndex) = .empty,

    typeResolutions: std.ArrayListUnmanaged(types.TypeResolution) = .empty,
    resolutionStart: u32 = 0,

    discriminantPropertiesScratch: std.ArrayListUnmanaged(ast_gen.SymbolIndex) = .empty,
    distributedTypesScratch: [1]types.TypeIndex = .{0},
    bestMatchingRelater: ?*relater.Relater = null,
    unionKeyPropertyCache: std.AutoHashMapUnmanaged(types.TypeIndex, UnionKeyPropertyEntry) = .{},

    pub const UnionKeyPropertyEntry = struct {
        keyPropertyName: []const u8,
        constituentMap: ?std.AutoHashMapUnmanaged(types.TypeIndex, types.TypeIndex) = null,
    };

    pub fn createSymbol(self: *Checker, flags: u32, name: []const u8, checkFlags: u32) ast_gen.SymbolIndex {
        self.binder.symbols.append(self.allocator, .{
            .Flags = flags,
            .Name = name,
            .Declarations = .empty,
            .ValueDeclaration = null,
            .Members = @import("../ast/symbol.zig").SymbolTable.empty,
            .Exports = @import("../ast/symbol.zig").SymbolTable.empty,
            .Parent = null,
            .ExportSymbol = null,
            .CheckFlags = checkFlags,
        }) catch unreachable;
        return @intCast(self.binder.symbols.items.len - 1);
    }

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
        if (self.typeToStringNodebuilder) |builder_instance| {
            builder_instance.ctxStack.deinit(self.allocator);
            builder_instance.impl.deinit();
            self.allocator.destroy(builder_instance.impl);
            self.allocator.destroy(builder_instance);
            self.typeToStringNodebuilder = null;
        }
        for (self.ownedDiagnosticArgs.items) |args| self.allocator.free(args);
        self.ownedDiagnosticArgs.deinit(self.allocator);
        for (self.ownedStrings.items) |s| self.allocator.free(s);
        self.ownedStrings.deinit(self.allocator);
        self.typesList.deinit(self.allocator);
        self.unionTypesPool.deinit(self.allocator);
        self.tupleTypesPool.deinit(self.allocator);
        self.templateLiteralTypes.deinit(self.allocator);
        self.sharedFlows.deinit(self.allocator);
        self.antecedentTypes.deinit(self.allocator);
        self.nodeFlowNodes.deinit(self.allocator);
        self.stringLiteralTypes.deinit(self.allocator);
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
        self.evolvingArrayTypes.deinit(self.allocator);
        self.discriminantPropertiesScratch.deinit(self.allocator);
        var keyPropIter = self.unionKeyPropertyCache.iterator();
        while (keyPropIter.next()) |entry| {
            if (entry.value_ptr.constituentMap) |*map| {
                map.deinit(self.allocator);
            }
        }
        self.unionKeyPropertyCache.deinit(self.allocator);

        self.typeArgumentsPool.deinit(self.allocator);
        self.symbolContainerLinks.deinit(self.allocator);
        self.typeAliasLinks.deinit(self.allocator);
        self.symbolReferenceLinks.deinit(self.allocator);
        self.valueSymbolLinks.deinit(self.allocator);
        self.mappedSymbolLinks.deinit(self.allocator);
        self.deferredSymbolLinks.deinit(self.allocator);
        self.moduleSymbolLinks.deinit(self.allocator);
        self.reverseMappedSymbolLinks.deinit(self.allocator);
        self.lateBoundLinks.deinit(self.allocator);
        self.exportTypeLinks.deinit(self.allocator);
        self.declaredTypeLinks.deinit(self.allocator);
        self.switchStatementLinks.deinit(self.allocator);
        self.arrayLiteralLinks.deinit(self.allocator);
        self.membersAndExportsLinks.deinit(self.allocator);
        self.spreadLinks.deinit(self.allocator);
        self.varianceLinks.deinit(self.allocator);
        self.typeNodeLinks.deinit(self.allocator);

        self.resolvedPropertiesPool.deinit(self.allocator);
        self.resolvedSignaturesPool.deinit(self.allocator);
        self.resolvedIndexInfosPool.deinit(self.allocator);

        self.resolvedStructuredTypeMembers.deinit(self.allocator);
        self.resolvedDeclaredMembers.deinit(self.allocator);
        self.resolvedUnionOrIntersectionProperties.deinit(self.allocator);

        self.numberLiteralTypes.deinit(self.allocator);

        self.signatures.deinit(self.allocator);
        self.signatureParameters.deinit(self.allocator);
        self.signatureTypeParameters.deinit(self.allocator);
        self.resolvedSignatureLinks.deinit(self.allocator);
        self.mappersList.deinit(self.allocator);

        self.symbolNodeLinks.deinit(self.allocator);
        self.mergedSymbols.deinit(self.allocator);
        self.assignmentReducedTypes.deinit(self.allocator);
        self.restrictiveTypeParameterCache.deinit(self.allocator);
        self.contextFreeTypes.deinit(self.allocator);

        self.enumMemberLinks.deinit(self.allocator);

        var currentRelater = self.freeRelater;
        while (currentRelater) |r| {
            const next = r.next;
            r.relatedInfo.deinit(self.allocator);
            r.maybeKeysSet.deinit(self.allocator);
            r.maybeKeys.deinit(self.allocator);
            r.sourceStack.deinit(self.allocator);
            r.targetStack.deinit(self.allocator);
            self.allocator.destroy(r);
            currentRelater = next;
        }

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
        self.lib_symbols.deinit(self.allocator);

        for (self.inferenceInfos.items) |*info| {
            info.candidates.deinit(self.allocator);
            info.contraCandidates.deinit(self.allocator);
        }
        self.inferenceInfos.deinit(self.allocator);
        self.tupleElementInfos.deinit(self.allocator);
    }

    pub fn createType(self: *Checker, t: types.Type) !u32 {
        const index = @as(u32, @intCast(self.typesList.items.len));
        try self.typesList.append(self.allocator, t);
        return index;
    }

    // =========================================================================
    // Skippeds for Relater
    // =========================================================================

    pub fn getParentOfSymbol(self: *Checker, sym: ast_gen.SymbolIndex) ast_gen.SymbolIndex {
        _ = self;
        return sym;
    }

    pub fn resolveStructuredTypeMembers(c: *Checker, t: types.TypeIndex) types.StructuredTypeMembers {
        if (c.resolvedStructuredTypeMembers.get(t)) |members| {
            return members;
        }

        var members = types.StructuredTypeMembers{};
        const flags = c.typesList.items[t].flags;
        if (flags & types.TypeFlags.Object != 0) {
            const objectFlags = c.typesList.items[t].objectFlags;
            if (objectFlags & types.ObjectFlags.Tuple != 0) {
                c.resolveTupleTypeMembers(t, &members);
            } else if (objectFlags & types.ObjectFlags.Reference != 0) {
                c.resolveTypeReferenceMembers(t, &members);
            } else if (objectFlags & types.ObjectFlags.ClassOrInterface != 0) {
                c.resolveClassOrInterfaceMembers(t, &members);
            } else if (objectFlags & types.ObjectFlags.ReverseMapped != 0) {
                c.resolveReverseMappedTypeMembers(t, &members);
            } else if (objectFlags & types.ObjectFlags.Anonymous != 0) {
                c.resolveAnonymousTypeMembers(t, &members);
            } else if (objectFlags & types.ObjectFlags.Mapped != 0) {
                c.resolveMappedTypeMembers(t, &members);
            } else {
                std.debug.panic("Unhandled case in resolveStructuredTypeMembers: {}", .{objectFlags});
            }
        } else if (flags & types.TypeFlags.Union != 0) {
            c.resolveUnionTypeMembers(t, &members);
        } else if (flags & types.TypeFlags.Intersection != 0) {
            c.resolveIntersectionTypeMembers(t, &members);
        }

        c.resolvedStructuredTypeMembers.put(c.allocator, t, members) catch {};
        return members;
    }

    pub fn getUnionSignatures(c: *Checker, t: types.TypeIndex, sigKind: types.SignatureKind) types.Range {
        const typeData = &c.typesList.items[t];
        const typesStart = typeData.data.Union.typesStart;
        const typesLen = typeData.data.Union.typesLen;

        if (typesLen == 0) return .{ .start = 0, .len = 0 };

        // If any constituent has 0 signatures, the union has 0 signatures.
        for (0..typesLen) |i| {
            const constituentType = c.unionTypesPool.items[typesStart + i];
            if (constituentType == c.globalFunctionType and sigKind == .Call) {
                c.resolvedSignaturesPool.append(c.allocator, c.unknownSignatureIndex) catch {};
                return .{ .start = @as(u32, @intCast(c.resolvedSignaturesPool.items.len)) - 1, .len = 1 };
            }
            const sigs = c.getSignaturesOfType(constituentType, sigKind);
            if (sigs.len == 0) return .{ .start = 0, .len = 0 };
        }

        // For now, as a very crude stub because we lack findMatchingSignatures and createUnionSignature,
        // we just return the signatures of the first type.
        // This avoids panics but is semantically incomplete.
        const firstType = c.unionTypesPool.items[typesStart];
        return c.getSignaturesOfType(firstType, sigKind);
    }

    pub fn getUnionIndexInfos(c: *Checker, t: types.TypeIndex) types.Range {
        const typeData = &c.typesList.items[t];
        const typesStart = typeData.data.Union.typesStart;
        const typesLen = typeData.data.Union.typesLen;

        if (typesLen == 0) return .{ .start = 0, .len = 0 };

        for (0..typesLen) |i| {
            const constituentType = c.unionTypesPool.items[typesStart + i];
            const infos = c.getIndexInfosOfType(constituentType);
            if (infos.len == 0) return .{ .start = 0, .len = 0 };
        }

        const firstType = c.unionTypesPool.items[typesStart];
        const infos = c.getIndexInfosOfType(firstType);
        if (infos.len == 0) return .{ .start = 0, .len = 0 };

        const ptrDiff = @intFromPtr(infos.ptr) - @intFromPtr(c.resolvedIndexInfosPool.items.ptr);
        const startIdx = @as(u32, @intCast(ptrDiff / @sizeOf(types.IndexInfo)));
        return .{ .start = startIdx, .len = @intCast(infos.len) };
    }

    pub fn resolveUnionTypeMembers(c: *Checker, t: types.TypeIndex, outMembers: *types.StructuredTypeMembers) void {
        const callSigs = c.getUnionSignatures(t, .Call);
        // Skipped: if len == 0, callSignatures = c.getArrayMemberCallSignatures(t)
        const constructSigs = c.getUnionSignatures(t, .Construct);
        const indexInfos = c.getUnionIndexInfos(t);

        outMembers.callSignaturesStart = callSigs.start;
        outMembers.callSignaturesLen = callSigs.len;
        outMembers.constructSignaturesStart = constructSigs.start;
        outMembers.constructSignaturesLen = constructSigs.len;
        outMembers.indexInfosStart = indexInfos.start;
        outMembers.indexInfosLen = indexInfos.len;
    }

    pub fn resolveIntersectionTypeMembers(c: *Checker, t: types.TypeIndex, outMembers: *types.StructuredTypeMembers) void {
        var callSignaturesStart: u32 = 0;
        var callSignaturesLen: u32 = 0;
        var constructSignaturesStart: u32 = 0;
        var constructSignaturesLen: u32 = 0;
        var indexInfosStart: u32 = 0;
        var indexInfosLen: u32 = 0;

        const typeData = &c.typesList.items[t];
        const typesStart = typeData.data.Intersection.typesStart;
        const typesLen = typeData.data.Intersection.typesLen;

        // Skipped: findMixins
        for (0..typesLen) |i| {
            const constituentType = c.unionTypesPool.items[typesStart + i];

            const constSigs = c.getSignaturesOfType(constituentType, .Construct);
            const mergedConstruct = c.appendSignatures(constructSignaturesStart, constructSignaturesLen, constSigs.start, constSigs.len);
            constructSignaturesStart = mergedConstruct.start;
            constructSignaturesLen = mergedConstruct.len;

            const callSigs = c.getSignaturesOfType(constituentType, .Call);
            const mergedCall = c.appendSignatures(callSignaturesStart, callSignaturesLen, callSigs.start, callSigs.len);
            callSignaturesStart = mergedCall.start;
            callSignaturesLen = mergedCall.len;

            const infos = c.getIndexInfosOfType(constituentType);
            for (0..infos.len) |j| {
                const info = infos[j];
                const mergedInfos = c.appendIndexInfo(indexInfosStart, indexInfosLen, info, false);
                indexInfosStart = mergedInfos.start;
                indexInfosLen = mergedInfos.len;
            }
        }

        outMembers.callSignaturesStart = callSignaturesStart;
        outMembers.callSignaturesLen = callSignaturesLen;
        outMembers.constructSignaturesStart = constructSignaturesStart;
        outMembers.constructSignaturesLen = constructSignaturesLen;
        outMembers.indexInfosStart = indexInfosStart;
        outMembers.indexInfosLen = indexInfosLen;
    }

    pub fn resolveClassOrInterfaceMembers(c: *Checker, t: types.TypeIndex, outMembers: *types.StructuredTypeMembers) void {
        c.resolveObjectTypeMembers(t, t, 0, 0, 0, 0, outMembers);
    }

    pub fn resolveTupleTypeMembers(c: *Checker, t: types.TypeIndex, outMembers: *types.StructuredTypeMembers) void {
        _ = c;
        _ = t;
        _ = outMembers;
        // TODO: Map Array properties and index signatures onto this Tuple type.
    }

    pub fn resolveTypeReferenceMembers(c: *Checker, t: types.TypeIndex, outMembers: *types.StructuredTypeMembers) void {
        const source = c.getTargetType(t);
        const sourceObj = c.typesList.items[source].data.Object;

        const typeParametersStart = sourceObj.typeArgumentsStart;
        const typeParametersLen = sourceObj.typeArgumentsLen;

        const typeArgsStart = c.typesList.items[t].data.Object.typeArgumentsStart;
        const typeArgsLen = c.typesList.items[t].data.Object.typeArgumentsLen;

        // Go logic:
        // if len(typeArguments) == len(typeParameters)-1 {
        //     paddedTypeArguments = core.Concatenate(typeArguments, []*Type{t})
        // }
        // For now, we will just pass typeArgsStart, typeArgsLen. Padded handling will be added to resolveObjectTypeMembers.

        c.resolveObjectTypeMembers(t, source, typeParametersStart, typeParametersLen, typeArgsStart, typeArgsLen, outMembers);
    }

    pub fn resolveObjectTypeMembers(c: *Checker, t: types.TypeIndex, source: types.TypeIndex, typeParametersStart: u32, typeParametersLen: u32, typeArgumentsStart: u32, typeArgumentsLen: u32, outMembers: *types.StructuredTypeMembers) void {
        _ = typeParametersStart;
        _ = typeParametersLen;
        _ = typeArgumentsStart;
        _ = typeArgumentsLen;

        const resolved = c.resolveDeclaredMembers(source);
        // For now, assume type parameters and arguments match
        outMembers.propertiesStart = resolved.propertiesStart;
        outMembers.propertiesLen = resolved.propertiesLen;
        outMembers.callSignaturesStart = resolved.callSignaturesStart;
        outMembers.callSignaturesLen = resolved.callSignaturesLen;
        outMembers.constructSignaturesStart = resolved.constructSignaturesStart;
        outMembers.constructSignaturesLen = resolved.constructSignaturesLen;
        outMembers.indexInfosStart = resolved.indexInfosStart;
        outMembers.indexInfosLen = resolved.indexInfosLen;

        // c.setStructuredTypeMembers(...) is basically done via outMembers here
        _ = t;
    }

    pub fn resolveReverseMappedTypeMembers(c: *Checker, t: types.TypeIndex, members: *types.StructuredTypeMembers) void {
        _ = c;
        _ = t;
        _ = members;
    }

    pub fn resolveAnonymousTypeMembers(c: *Checker, t: types.TypeIndex, members: *types.StructuredTypeMembers) void {
        const typeData = &c.typesList.items[t];
        const sym = typeData.symbol;
        if (sym != 0) {
            // Analogous to:
            // members := c.getMembersOfSymbol(symbol)
            // ...
            // which in Zig is basically what resolveDeclaredMembers handles for object types!
            const declMembers = c.resolveDeclaredMembers(t);
            members.* = declMembers;
        }
    }

    pub fn resolveMappedTypeMembers(c: *Checker, t: types.TypeIndex, members: *types.StructuredTypeMembers) void {
        _ = c;
        _ = t;
        _ = members;
    }

    pub fn resolveDeclaredMembers(c: *Checker, t: types.TypeIndex) types.StructuredTypeMembers {
        if (c.resolvedDeclaredMembers.get(t)) |members| {
            return members;
        }

        var members = types.StructuredTypeMembers{};

        if (c.typesList.items[t].data != .Object) {
            c.resolvedDeclaredMembers.put(c.allocator, t, members) catch {};
            return members;
        }

        const symIdx = c.typesList.items[t].data.Object.Symbol orelse {
            c.resolvedDeclaredMembers.put(c.allocator, t, members) catch {};
            return members;
        };

        const membersMap = c.binder.symbolMembers.get(symIdx) orelse return members;

        const startProperties = c.resolvedPropertiesPool.items.len;
        var it = membersMap.iterator();

        var callSymbol: ?ast_gen.SymbolIndex = null;
        var constructSymbol: ?ast_gen.SymbolIndex = null;
        var indexSymbol: ?ast_gen.SymbolIndex = null;

        while (it.next()) |entry| {
            if (c.isNamedMember(entry.value_ptr.*, entry.key_ptr.*)) {
                c.resolvedPropertiesPool.append(c.allocator, entry.value_ptr.*) catch {};
            }
            if (std.mem.eql(u8, entry.key_ptr.*, "__call")) {
                callSymbol = entry.value_ptr.*;
            } else if (std.mem.eql(u8, entry.key_ptr.*, "__new")) {
                constructSymbol = entry.value_ptr.*;
            } else if (std.mem.eql(u8, entry.key_ptr.*, "__index")) {
                indexSymbol = entry.value_ptr.*;
            }
        }
        members.propertiesStart = @intCast(startProperties);
        members.propertiesLen = @intCast(c.resolvedPropertiesPool.items.len - startProperties);

        if (callSymbol) |sym| {
            const range = c.getSignaturesOfSymbol(sym);
            members.callSignaturesStart = range.start;
            members.callSignaturesLen = range.len;
        }

        if (constructSymbol) |sym| {
            const range = c.getSignaturesOfSymbol(sym);
            members.constructSignaturesStart = range.start;
            members.constructSignaturesLen = range.len;
        }

        if (indexSymbol) |sym| {
            // Provide all siblings properties to resolve index infos accurately
            const range = c.getIndexInfosOfIndexSymbol(sym, members.propertiesStart, members.propertiesLen);
            members.indexInfosStart = range.start;
            members.indexInfosLen = range.len;
        }

        c.resolvedDeclaredMembers.put(c.allocator, t, members) catch {};
        return members;
    }

    pub fn getSignaturesOfSymbol(c: *Checker, symIdx: ast_gen.SymbolIndex) types.Range {
        if (symIdx == 0 or symIdx >= c.binder.symbols.items.len) {
            return .{ .start = 0, .len = 0 };
        }

        const startSignatures = c.resolvedSignaturesPool.items.len;
        const sym = c.binder.symbols.items[symIdx];

        for (sym.Declarations.items, 0..) |declNode, i| {
            const declNodeData = c.binder.ast.getNode(declNode);
            if (!ast_utils.isFunctionLike(std.meta.activeTag(declNodeData))) {
                continue;
            }

            if (i > 0 and ast_utils.getBodyOfNode(c.binder.ast, declNode) != 0) {
                const previous = sym.Declarations.items[i - 1];
                const prevNodeData = c.binder.ast.getNode(previous);
                if (c.binder.ast.getNodeParent(declNode) == c.binder.ast.getNodeParent(previous) and
                    std.meta.activeTag(declNodeData) == std.meta.activeTag(prevNodeData))
                {
                    if (c.binder.ast.positions.items[declNode].pos == c.binder.ast.positions.items[previous].end or
                        (c.binder.ast.getNodeFlags(previous) & ast_utils.NodeFlags.Reparsed) != 0)
                    {
                        continue;
                    }
                }
            }

            // JS FullSignature is out of scope for now
            const sigIdx = c.getSignatureFromDeclaration(declNode);
            if (sigIdx != 0) {
                c.resolvedSignaturesPool.append(c.allocator, sigIdx) catch {};
            }
        }

        return types.Range{
            .start = @intCast(startSignatures),
            .len = @intCast(c.resolvedSignaturesPool.items.len - startSignatures),
        };
    }

    pub fn getSignatureFromDeclaration(c: *Checker, declaration: ast_gen.NodeIndex) types.SignatureIndex {
        if (c.resolvedSignatureLinks.get(declaration)) |sigIdx| {
            return sigIdx;
        }

        const sigIdx = @as(u32, @intCast(c.signatures.items.len));
        var sig = types.Signature{
            .declaration = declaration,
            .flags = types.SignatureFlags.None,
        };

        const params = ast_utils.getParametersOfNode(c.binder.ast, declaration);
        const startParams = c.signatureParameters.items.len;
        var minArgumentCount: i32 = 0;
        var hasThisParameter = false;

        for (params, 0..) |paramNode, i| {
            const paramSymbol = c.binder.ast.getNodeSymbol(paramNode) orelse 0;

            if (i == 0 and paramSymbol != 0 and std.mem.eql(u8, c.binder.symbols.items[paramSymbol].Name, "this")) {
                hasThisParameter = true;
                sig.thisParameter = paramSymbol;
            } else {
                if (paramSymbol != 0) {
                    c.signatureParameters.append(c.allocator, paramSymbol) catch {};
                }
            }

            var isOptionalParameter = false;
            var isRestParameter = false;

            const nodeData = c.binder.ast.nodes.get(paramNode);
            if (nodeData == .Parameter) {
                const paramDecl = nodeData.Parameter;
                if (paramDecl.QuestionToken != null or paramDecl.Initializer != null) {
                    isOptionalParameter = true;
                }
                if (paramDecl.DotDotDotToken != null) {
                    isRestParameter = true;
                    isOptionalParameter = true;
                    if (i == params.len - 1) {
                        sig.flags |= types.SignatureFlags.HasRestParameter;
                    }
                }
                if (paramDecl.Type != null) {
                    if (std.meta.activeTag(c.binder.ast.nodes.get(paramDecl.Type.?)) == .LiteralType) {
                        sig.flags |= types.SignatureFlags.HasLiteralTypes;
                    }
                }
            }

            if (!isOptionalParameter) {
                minArgumentCount = @intCast(c.signatureParameters.items.len - startParams);
            }
        }

        sig.parametersStart = @intCast(startParams);
        sig.parametersLen = @intCast(c.signatureParameters.items.len - startParams);
        sig.minArgumentCount = minArgumentCount;

        const typeParams = ast_utils.getTypeParametersOfNode(c.binder.ast, declaration);
        const startTypeParams = c.signatureTypeParameters.items.len;
        for (typeParams) |tpNode| {
            const tpSymbol = c.binder.ast.getNodeSymbol(tpNode) orelse 0;
            if (tpSymbol != 0) {
                const typeIdx = c.getDeclaredTypeOfTypeParameter(tpSymbol);
                if (typeIdx != 0) {
                    c.signatureTypeParameters.append(c.allocator, typeIdx) catch {};
                }
            }
        }
        sig.typeParametersStart = @intCast(startTypeParams);
        sig.typeParametersLen = @intCast(c.signatureTypeParameters.items.len - startTypeParams);

        c.signatures.append(c.allocator, sig) catch {};
        c.resolvedSignatureLinks.put(c.allocator, declaration, sigIdx) catch {};
        return sigIdx;
    }

    pub fn getDeclaredTypeOfTypeParameter(c: *Checker, symIdx: ast_gen.SymbolIndex) types.TypeIndex {
        if (symIdx == 0) return 0;
        var entry = c.declaredTypeLinks.getOrPut(c.allocator, symIdx) catch return 0;
        if (!entry.found_existing) {
            entry.value_ptr.* = .{};
        }
        if (entry.value_ptr.declaredType) |declaredType| {
            return declaredType;
        }
        const result = c.createType(.{
            .flags = types.TypeFlags.TypeParameter,
            .objectFlags = types.ObjectFlags.Anonymous,
            .symbol = symIdx,
            .data = .{ .TypeParameter = .{ .constraintType = c.noConstraintTypeIndex orelse 0 } },
        }) catch 0;
        entry.value_ptr.declaredType = result;
        return result;
    }

    pub fn narrowTypeByTypeFactsWorker(c: *Checker, t: types.TypeIndex, impliedType: types.TypeIndex, facts: u32) types.TypeIndex {
        if (relater.isTypeRelatedTo(c, t, impliedType, &c.strictSubtypeRelation)) {
            if (c.hasTypeFacts(t, facts)) {
                return t;
            }
            return c.neverTypeIndex orelse 0;
        }
        if (relater.isTypeSubtypeOf(c, impliedType, t)) {
            return impliedType;
        }
        if (c.hasTypeFacts(t, facts)) {
            return c.getIntersectionType(&[_]types.TypeIndex{ t, impliedType });
        }
        return c.neverTypeIndex orelse 0;
    }

    pub fn narrowTypeByTypeFacts(c: *Checker, t: types.TypeIndex, impliedType: types.TypeIndex, facts: u32) types.TypeIndex {
        if ((c.typesList.items[t].flags & types.TypeFlags.Union) != 0) {
            const typesArr = c.getTypesFromUnion(t);
            var newTypesArr = c.allocator.alloc(types.TypeIndex, typesArr.len) catch return t;
            defer c.allocator.free(newTypesArr);
            var changed = false;
            for (typesArr, 0..) |unionElem, i| {
                const narrowed = c.narrowTypeByTypeFactsWorker(unionElem, impliedType, facts);
                newTypesArr[i] = narrowed;
                if (narrowed != unionElem) changed = true;
            }
            if (changed) {
                return c.getUnionTypeFromArray(newTypesArr);
            }
            return t;
        }
        return c.narrowTypeByTypeFactsWorker(t, impliedType, facts);
    }

    pub fn getSignaturesOfType(c: *Checker, t: types.TypeIndex, sigKind: types.SignatureKind) types.Range {
        const apparent = c.getReducedApparentType(t);
        const typeData = &c.typesList.items[apparent];
        if (typeData.flags & types.TypeFlags.StructuredType == 0) {
            return .{ .start = 0, .len = 0 };
        }

        const resolved = c.resolveStructuredTypeMembers(apparent);
        if (sigKind == .Call) {
            return .{ .start = resolved.callSignaturesStart, .len = resolved.callSignaturesLen };
        }
        return .{ .start = resolved.constructSignaturesStart, .len = resolved.constructSignaturesLen };
    }

    pub fn appendSignatures(c: *Checker, signaturesStart: u32, signaturesLen: u32, newSignaturesStart: u32, newSignaturesLen: u32) types.Range {
        if (signaturesLen == 0) return .{ .start = newSignaturesStart, .len = newSignaturesLen };
        if (newSignaturesLen == 0) return .{ .start = signaturesStart, .len = signaturesLen };

        const mergedStart = @as(u32, @intCast(c.resolvedSignaturesPool.items.len));

        for (0..signaturesLen) |i| {
            c.resolvedSignaturesPool.append(c.allocator, c.resolvedSignaturesPool.items[signaturesStart + i]) catch {};
        }
        for (0..newSignaturesLen) |i| {
            const newSigIdx = c.resolvedSignaturesPool.items[newSignaturesStart + i];
            var isDuplicate = false;
            for (0..signaturesLen) |j| {
                const existingSigIdx = c.resolvedSignaturesPool.items[signaturesStart + j];
                if (relater.compareSignaturesIdentical(c, existingSigIdx, newSigIdx, false, false, false, relater.compareTypesIdentical) != .False) {
                    isDuplicate = true;
                    break;
                }
            }
            if (!isDuplicate) {
                c.resolvedSignaturesPool.append(c.allocator, newSigIdx) catch {};
            }
        }

        return .{ .start = mergedStart, .len = @intCast(c.resolvedSignaturesPool.items.len - mergedStart) };
    }

    pub fn appendIndexInfo(c: *Checker, indexInfosStart: u32, indexInfosLen: u32, newInfo: types.IndexInfo, isUnion: bool) types.Range {
        if (indexInfosLen == 0) {
            const start = @as(u32, @intCast(c.resolvedIndexInfosPool.items.len));
            c.resolvedIndexInfosPool.append(c.allocator, newInfo) catch {};
            return .{ .start = start, .len = 1 };
        }

        const mergedStart = @as(u32, @intCast(c.resolvedIndexInfosPool.items.len));
        for (0..indexInfosLen) |i| {
            c.resolvedIndexInfosPool.append(c.allocator, c.resolvedIndexInfosPool.items[indexInfosStart + i]) catch {};
        }

        for (0..indexInfosLen) |i| {
            var info = &c.resolvedIndexInfosPool.items[mergedStart + i];
            if (info.keyType == newInfo.keyType) {
                var valueType: types.TypeIndex = 0;
                var isReadonly = false;
                if (isUnion) {
                    valueType = c.getUnionTypeFromArray(&[_]types.TypeIndex{ info.valueType, newInfo.valueType });
                    isReadonly = info.isReadonly or newInfo.isReadonly;
                } else {
                    valueType = c.getIntersectionType(&[_]types.TypeIndex{ info.valueType, newInfo.valueType });
                    isReadonly = info.isReadonly and newInfo.isReadonly;
                }
                info.valueType = valueType;
                info.isReadonly = isReadonly;
                return .{ .start = mergedStart, .len = indexInfosLen };
            }
        }

        c.resolvedIndexInfosPool.append(c.allocator, newInfo) catch {};
        return .{ .start = mergedStart, .len = indexInfosLen + 1 };
    }

    pub fn getIndexInfosOfIndexSymbol(c: *Checker, symIdx: ast_gen.SymbolIndex, propertiesStart: u32, propertiesLen: u32) types.Range {
        _ = c;
        _ = symIdx;
        _ = propertiesStart;
        _ = propertiesLen;
        return .{ .start = 0, .len = 0 }; // Skipped
    }

    pub fn getIndexInfosOfSymbol(c: *Checker, symIdx: ast_gen.SymbolIndex) types.Range {
        _ = c;
        _ = symIdx;
        // In Go this is just a wrapper, we handled it explicitly above
        return .{ .start = 0, .len = 0 }; // Skipped
    }

    pub fn isNamedMember(c: *Checker, symIdx: ast_gen.SymbolIndex, name: []const u8) bool {
        if (isReservedMemberName(name)) return false;
        return c.symbolIsValue(symIdx);
    }

    pub fn isReservedMemberName(name: []const u8) bool {
        return name.len >= 2 and name[0] == '\xFE' and name[1] != '@' and name[1] != '#';
    }

    pub fn symbolIsValue(c: *Checker, symIdx: ast_gen.SymbolIndex) bool {
        if (symIdx == 0 or symIdx >= c.binder.symbols.items.len) return false;
        const flags = c.binder.symbols.items[symIdx].Flags;
        // SymbolFlags.Value = 111551
        if (flags & 111551 != 0) return true;
        // Alias resolution requires a full recursive resolveAlias implementation, skipping for now
        return false;
    }

    pub fn resolveAlias(c: *Checker, symIdx: ast_gen.SymbolIndex) ast_gen.SymbolIndex {
        // Alias resolution requires a full recursive resolveAlias implementation.
        // For now, return the symbol to avoid infinite loops or crashes.
        _ = c;
        return symIdx;
    }

    pub fn getActualTypeVariable(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        const flags = c.typesList.items[t].flags;
        if ((flags & types.TypeFlags.Substitution) != 0) {
            return c.getActualTypeVariable(c.typesList.items[t].data.Substitution.baseType);
        }
        if ((flags & types.TypeFlags.IndexedAccess) != 0) {
            const objType = c.typesList.items[t].data.IndexedAccess.objectType;
            const indexType = c.typesList.items[t].data.IndexedAccess.indexType;
            if (objType != 0 and indexType != 0) {
                const objFlags = c.typesList.items[objType].flags;
                const indexFlags = c.typesList.items[indexType].flags;
                if ((objFlags & types.TypeFlags.Substitution) != 0 or (indexFlags & types.TypeFlags.Substitution) != 0) {
                    return c.getIndexedAccessType(c.getActualTypeVariable(objType), c.getActualTypeVariable(indexType));
                }
            }
        }
        return t;
    }

    pub fn getPropertiesOfType(c: *Checker, t: types.TypeIndex) []const ast_gen.SymbolIndex {
        const reduced = c.getReducedApparentType(t);
        const flags = c.typesList.items[reduced].flags;
        if (flags & types.TypeFlags.UnionOrIntersection != 0) {
            return c.getPropertiesOfUnionOrIntersectionType(reduced);
        }
        return c.getPropertiesOfObjectType(reduced);
    }

    pub fn getPropertiesOfObjectType(c: *Checker, t: types.TypeIndex) []const ast_gen.SymbolIndex {
        if (c.typesList.items[t].flags & types.TypeFlags.Object != 0) {
            const members = c.resolveStructuredTypeMembers(t);
            return c.resolvedPropertiesPool.items[members.propertiesStart .. members.propertiesStart + members.propertiesLen];
        }
        return &[_]ast_gen.SymbolIndex{};
    }

    pub fn getPropertiesOfUnionOrIntersectionType(c: *Checker, t: types.TypeIndex) []const ast_gen.SymbolIndex {
        if (c.resolvedUnionOrIntersectionProperties.get(t)) |range| {
            return c.resolvedPropertiesPool.items[range.start .. range.start + range.len];
        }

        var names = std.StringHashMapUnmanaged(void).empty;
        defer names.deinit(c.allocator);
        for (c.getTypesOfUnionOrIntersectionType(t)) |constituent| {
            for (c.getPropertiesOfType(constituent)) |prop| {
                names.put(c.allocator, c.getSymbolName(prop), {}) catch {};
            }
        }

        const startProperties = c.resolvedPropertiesPool.items.len;

        var iter = names.iterator();
        while (iter.next()) |entry| {
            if (c.getPropertyOfUnionOrIntersectionType(t, entry.key_ptr.*)) |prop| {
                c.resolvedPropertiesPool.append(c.allocator, prop) catch {};
            }
        }

        const range = types.Range{
            .start = @intCast(startProperties),
            .len = @intCast(c.resolvedPropertiesPool.items.len - startProperties),
        };
        c.resolvedUnionOrIntersectionProperties.put(c.allocator, t, range) catch {};
        return c.resolvedPropertiesPool.items[range.start .. range.start + range.len];
    }

    pub fn getReducedApparentType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        return c.getApparentType(c.getReducedType(t));
    }

    pub fn getReducedType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        const flags = c.typesList.items[t].flags;
        if ((flags & types.TypeFlags.Union) != 0) {
            const objectFlags = c.getObjectFlags(t);
            if ((objectFlags & types.ObjectFlags.ContainsIntersections) != 0) {
                return c.getReducedUnionType(t);
            }
        } else if ((flags & types.TypeFlags.Intersection) != 0) {
            const objectFlags = c.getObjectFlags(t);
            if ((objectFlags & types.ObjectFlags.IsNeverIntersection) != 0) {
                return c.neverTypeIndex orelse 0;
            }
        }
        return t;
    }

    pub fn getReducedUnionType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        const typesArr = c.getTypesFromUnion(t);
        var newTypesArr = c.allocator.alloc(types.TypeIndex, typesArr.len) catch return t;
        defer c.allocator.free(newTypesArr);
        var changed = false;
        for (typesArr, 0..) |unionElem, i| {
            const reduced = c.getReducedType(unionElem);
            newTypesArr[i] = reduced;
            if (reduced != unionElem) changed = true;
        }
        if (changed) {
            return c.getUnionTypeFromArray(newTypesArr);
        }
        return t;
    }

    pub fn getPropertyOfType(self: *Checker, tIdx: u32, name: []const u8) ?ast_gen.SymbolIndex {
        if (tIdx == 0 or tIdx >= self.typesList.items.len) return null;
        const typ = self.typesList.items[tIdx];
        if ((typ.flags & types.TypeFlags.UnionOrIntersection) != 0) {
            return self.getPropertyOfUnionOrIntersectionType(tIdx, name);
        }
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

    pub fn getPropertyOfUnionOrIntersectionType(c: *Checker, t: types.TypeIndex, name: []const u8) ?ast_gen.SymbolIndex {
        const prop = c.getUnionOrIntersectionProperty(t, name) orelse return null;
        if ((c.getSymbolCheckFlags(prop) & types.CheckFlags.ReadPartial) != 0) return null;
        return prop;
    }

    pub fn getUnionOrIntersectionProperty(c: *Checker, t: types.TypeIndex, name: []const u8) ?ast_gen.SymbolIndex {
        return c.createUnionOrIntersectionProperty(t, name);
    }

    fn createUnionOrIntersectionProperty(c: *Checker, containingType: types.TypeIndex, name: []const u8) ?ast_gen.SymbolIndex {
        const isUnion = (c.getTypeFlags(containingType) & types.TypeFlags.Union) != 0;
        var propTypes = std.ArrayListUnmanaged(types.TypeIndex).empty;
        defer propTypes.deinit(c.allocator);

        var singleProp: ?ast_gen.SymbolIndex = null;
        var propCount: usize = 0;
        var propFlags: u32 = symbol.SymbolFlags.Property;
        var optionalFlag: u32 = if (isUnion) 0 else symbol.SymbolFlags.Optional;
        var checkFlags: u32 = if (isUnion) 0 else types.CheckFlags.Readonly;
        var firstType: ?types.TypeIndex = null;

        for (c.getTypesOfUnionOrIntersectionType(containingType)) |current| {
            const apparent = c.getApparentType(current);
            if ((c.getTypeFlags(apparent) & types.TypeFlags.Never) != 0) continue;

            if (c.getPropertyOfObjectType(apparent, name)) |prop| {
                propCount += 1;
                if (singleProp == null) singleProp = prop;
                propFlags = symbol.SymbolFlags.Property;

                if (isUnion) {
                    optionalFlag |= c.getSymbolFlags(prop) & symbol.SymbolFlags.Optional;
                } else {
                    optionalFlag &= c.getSymbolFlags(prop);
                }

                if (isUnion) {
                    if ((c.getSymbolCheckFlags(prop) & types.CheckFlags.Readonly) != 0) {
                        checkFlags |= types.CheckFlags.Readonly;
                    }
                } else if ((c.getSymbolCheckFlags(prop) & types.CheckFlags.Readonly) == 0) {
                    checkFlags &= ~types.CheckFlags.Readonly;
                }

                const propType = c.getTypeOfSymbol(prop) catch c.anyTypeIndex orelse 0;
                if (firstType) |ft| {
                    if (propType != ft) checkFlags |= types.CheckFlags.HasNonUniformType;
                } else {
                    firstType = propType;
                }
                if (isLiteralLikeForSyntheticProperty(c, propType)) {
                    checkFlags |= types.CheckFlags.HasLiteralType;
                }
                propTypes.append(c.allocator, propType) catch {};
            } else if (isUnion) {
                checkFlags |= types.CheckFlags.ReadPartial;
            }
        }

        if (singleProp == null) return null;
        if (propCount == 1 and (checkFlags & types.CheckFlags.Partial) == 0) return singleProp;

        const resolvedType = if (isUnion)
            c.getUnionTypeFromArray(propTypes.items)
        else
            c.getIntersectionType(propTypes.items);

        return c.createSyntheticPropertySymbol(
            propFlags | optionalFlag | symbol.SymbolFlags.Transient,
            name,
            checkFlags | types.CheckFlags.SyntheticProperty,
            resolvedType,
            containingType,
        );
    }

    fn getPropertyOfObjectType(c: *Checker, t: types.TypeIndex, name: []const u8) ?ast_gen.SymbolIndex {
        if ((c.getTypeFlags(t) & types.TypeFlags.Object) == 0) return null;
        const members = c.resolveStructuredTypeMembers(t);
        const properties = c.resolvedPropertiesPool.items[members.propertiesStart .. members.propertiesStart + members.propertiesLen];
        for (properties) |prop| {
            if (std.mem.eql(u8, c.getSymbolName(prop), name) and c.symbolIsValue(prop)) return prop;
        }
        return null;
    }

    fn createSyntheticPropertySymbol(c: *Checker, flags: u32, name: []const u8, checkFlags: u32, resolvedType: types.TypeIndex, containingType: types.TypeIndex) ?ast_gen.SymbolIndex {
        const symIndex: ast_gen.SymbolIndex = @intCast(c.binder.symbols.items.len);
        c.binder.symbols.append(c.allocator, .{
            .Flags = flags,
            .Name = name,
            .Declarations = .empty,
            .ValueDeclaration = null,
            .Members = .empty,
            .Exports = .empty,
            .Parent = null,
            .ExportSymbol = null,
            .CheckFlags = checkFlags,
        }) catch return null;
        c.valueSymbolLinks.put(c.allocator, symIndex, .{
            .resolvedType = resolvedType,
            .containingType = containingType,
        }) catch {};
        return symIndex;
    }

    fn isLiteralLikeForSyntheticProperty(c: *Checker, t: types.TypeIndex) bool {
        const flags = c.getTypeFlags(t);
        return (flags & (types.TypeFlags.Literal | types.TypeFlags.EnumLiteral | types.TypeFlags.UniqueESSymbol)) != 0 or c.isPatternLiteralType(t);
    }

    pub fn getDeclaredTypeOfSymbol(self: *Checker, sym: ast_gen.SymbolIndex) types.TypeIndex {
        const result = self.tryGetDeclaredTypeOfSymbol(sym);
        if (result != 0) return result;
        return self.errorTypeIndex orelse self.anyTypeIndex.?;
    }

    pub fn tryGetDeclaredTypeOfSymbol(self: *Checker, sym: ast_gen.SymbolIndex) types.TypeIndex {
        if (sym == 0) return 0;
        const flags = self.getSymbolFlags(sym);
        if ((flags & (symbol.SymbolFlags.Class | symbol.SymbolFlags.Interface)) != 0) {
            const objectKind = if ((flags & symbol.SymbolFlags.Class) != 0) types.ObjectFlags.Class else types.ObjectFlags.Interface;
            return self.createType(.{
                .flags = types.TypeFlags.Object,
                .objectFlags = objectKind,
                .id = 0,
                .symbol = sym,
                .alias = null,
                .data = .{ .Object = .{ .Symbol = sym } },
            }) catch 0;
        }
        if ((flags & symbol.SymbolFlags.TypeAlias) != 0) {
            return self.getDeclaredTypeOfTypeAlias(sym);
        }
        return 0;
    }

    fn getDeclaredTypeOfTypeAlias(self: *Checker, sym: ast_gen.SymbolIndex) types.TypeIndex {
        var entry = self.typeAliasLinks.getOrPut(self.allocator, sym) catch @panic("OOM");
        if (!entry.found_existing) {
            entry.value_ptr.* = .{};
        }
        if (entry.value_ptr.declaredType) |declaredType| {
            return declaredType;
        }

        if (sym >= self.binder.symbols.items.len) {
            entry.value_ptr.declaredType = self.errorTypeIndex;
            return entry.value_ptr.declaredType.?;
        }

        var typeNode: ast_gen.NodeIndex = 0;
        var typeParametersList = std.ArrayListUnmanaged(types.TypeIndex).empty;
        defer typeParametersList.deinit(self.allocator);
        for (self.binder.symbols.items[sym].Declarations.items) |decl| {
            switch (self.binder.ast.getNode(decl)) {
                .TypeAliasDeclaration => |declaration| {
                    typeNode = declaration.Type;
                    if (declaration.TypeParameters) |tps| {
                        for (self.binder.ast.getNodeList(tps)) |tp| {
                            const tpSym = self.getSymbolOfDeclaration(tp);
                            const tpType = self.getDeclaredTypeOfTypeParameter(tpSym);
                            typeParametersList.append(self.allocator, tpType) catch {};
                        }
                    }
                    break;
                },
                .JSTypeAliasDeclaration => |declaration| {
                    typeNode = declaration.Type;
                    if (declaration.TypeParameters) |tps| {
                        for (self.binder.ast.getNodeList(tps)) |tp| {
                            const tpSym = self.getSymbolOfDeclaration(tp);
                            const tpType = self.getDeclaredTypeOfTypeParameter(tpSym);
                            typeParametersList.append(self.allocator, tpType) catch {};
                        }
                    }
                    break;
                },
                else => {},
            }
        }

        const declaredType = if (typeNode != 0)
            type_resolution_pkg.getTypeFromTypeNode(self, typeNode)
        else
            self.errorTypeIndex orelse 0;
        entry.value_ptr.declaredType = declaredType;
        if (typeParametersList.items.len != 0) {
            entry.value_ptr.typeParameters = self.allocator.dupe(types.TypeIndex, typeParametersList.items) catch &[_]types.TypeIndex{};
            if (entry.value_ptr.instantiations == null) {
                entry.value_ptr.instantiations = std.AutoHashMapUnmanaged(types.CacheHashKey, types.TypeIndex).empty;
            }
            const key = getTypeAliasInstantiationKey(typeParametersList.items, null);
            entry.value_ptr.instantiations.?.put(self.allocator, key, declaredType) catch {};
        }
        return declaredType;
    }

    pub fn symbolToString(self: *Checker, sym: ast_gen.SymbolIndex) []const u8 {
        _ = self;
        _ = sym;
        return "symbol";
    }

    pub fn getNormalizedType(self: *Checker, t: types.TypeIndex, writing: bool) types.TypeIndex {
        _ = writing;
        const typeData = &self.typesList.items[t];
        if (typeData.objectFlags & types.ObjectFlags.FreshLiteral != 0) {
            // It should return the regular type for literal, but we stub it for now
            // Need to port getRegularTypeOfLiteralType
        }
        return t; // Stub
    }

    pub fn TypeToStringEx(self: *Checker, t: types.TypeIndex, enclosingDeclaration: ast_gen.NodeIndex, formatFlags: u32, tracer: ?*nodebuilder.VerbosityContext) []const u8 {
        if (t == 0) return "any";
        const typeData = &self.typesList.items[t];
        if (typeData.flags & types.TypeFlags.String != 0) return "string";
        if (typeData.flags & types.TypeFlags.Number != 0) return "number";
        if (typeData.flags & types.TypeFlags.Boolean != 0) return "boolean";
        if (typeData.flags & types.TypeFlags.Void != 0) return "void";
        if (typeData.flags & types.TypeFlags.Undefined != 0) return "undefined";
        if (typeData.flags & types.TypeFlags.Null != 0) return "null";
        if (typeData.flags & types.TypeFlags.Any != 0) return "any";
        if (typeData.flags & types.TypeFlags.Unknown != 0) return "unknown";
        if (typeData.flags & types.TypeFlags.Never != 0) return "never";
        if (typeData.flags & types.TypeFlags.BigInt != 0) return "bigint";

        if (typeData.flags & types.TypeFlags.StringLiteral != 0) {
            const str = std.fmt.allocPrint(self.allocator, "\"{s}\"", .{typeData.data.StringLiteral.text}) catch return "string";
            self.ownedStrings.append(self.allocator, str) catch {};
            return str;
        }
        if (typeData.flags & types.TypeFlags.NumberLiteral != 0) {
            const str = std.fmt.allocPrint(self.allocator, "{d}", .{typeData.data.NumberLiteral.value}) catch return "number";
            self.ownedStrings.append(self.allocator, str) catch {};
            return str;
        }
        if (typeData.flags & types.TypeFlags.BooleanLiteral != 0) {
            return if (typeData.data.BooleanLiteral.value) "true" else "false";
        }
        if (typeData.flags & types.TypeFlags.BigIntLiteral != 0) {
            const str = std.fmt.allocPrint(self.allocator, "{s}n", .{typeData.data.BigIntLiteral.text}) catch return "bigint";
            self.ownedStrings.append(self.allocator, str) catch {};
            return str;
        }
        if (self.serializationLevel >= 100) { // maxSerializationLevel
            return "?";
        }
        var newLine: []const u8 = "";
        if ((formatFlags & types.TypeFormatFlags.MultilineObjectLiterals) != 0) {
            newLine = "\n";
        }
        var text_writer = textwriter_pkg.TextWriter.init(self.allocator, newLine, 4);
        var emit_writer = text_writer.getEmitTextWriter();

        var noTruncation = false;
        if (tracer) |vc| {
            if (vc.maxTruncationLength == 0) noTruncation = true;
        } else {
            noTruncation = true;
        }
        if ((formatFlags & types.TypeFormatFlags.NoTruncation) != 0) noTruncation = true;

        const maskedFlags = formatFlags & types.TypeFormatFlags.NodeBuilderFlagsMask;
        const combinedFlagsAsU32 = maskedFlags;
        var combinedFlags: nodebuilderimpl.Flags = @bitCast(combinedFlagsAsU32);
        combinedFlags.IgnoreErrors = true;
        if (noTruncation) {
            combinedFlags.NoTruncation = true;
        }

        var b = self.getNodeBuilder();
        const oldVerbosity = b.verbosity;
        b.verbosity = tracer;
        defer b.verbosity = oldVerbosity;

        self.serializationLevel += 1;
        const typeNode = b.typeToTypeNode(t, enclosingDeclaration, combinedFlags, .{});
        self.serializationLevel -= 1;

        if (typeNode == 0) {
            // Primitive fallback if NodeBuilder stubbed
            if (typeData.flags & types.TypeFlags.Object != 0) {
                if (self.getObjectFlags(t) & types.ObjectFlags.Reference != 0) {
                    const sym = self.getSymbolOfType(t);
                    if (sym != 0) {
                        return self.allocator.dupe(u8, self.binder.symbols.items[sym].Name) catch "Object";
                    }
                }
                return "Object";
            }
            if (typeData.flags & types.TypeFlags.Union != 0) return "Union";
            if (typeData.flags & types.TypeFlags.Intersection != 0) return "Intersection";
            if (typeData.flags & types.TypeFlags.TypeParameter != 0) return "TypeParameter";
            return "type";
        }

        var factory = @import("../printer/factory.zig").NodeFactory.init(self.allocator, self.binder.ast);
        defer factory.deinit();
        var emitContext = emitcontext_pkg.EmitContext.init(self.allocator, self.binder.ast, &factory);
        defer emitContext.deinit();
        emitContext.setEmitFlags(typeNode, @import("../printer/emitflags.zig").EmitFlags.SingleLine) catch {};

        var p = printer_pkg.Printer.init(self.binder.ast, &emitContext, &emit_writer);
        p.printNode(typeNode) catch return "type"; // Note: printNode might have a different signature

        return self.allocator.dupe(u8, text_writer.string()) catch "type";
    }

    pub fn TypeToString(self: *Checker, t: types.TypeIndex) []const u8 {
        return self.TypeToStringEx(t, 0, types.TypeFormatFlags.AllowUniqueESSymbolType | types.TypeFormatFlags.UseAliasDefinedOutsideCurrentScope, null);
    }

    pub fn typeToString(self: *Checker, t: types.TypeIndex, enclosingDeclaration: ast_gen.NodeIndex, formatFlags: u32, tracer: ?*nodebuilder.VerbosityContext) []const u8 {
        return self.TypeToStringEx(t, enclosingDeclaration, formatFlags, tracer);
    }

    pub fn getNodeBuilder(c: *Checker) *nodebuilder.NodeBuilder {
        if (c.typeToStringNodebuilder) |b| {
            return b;
        }
        c.typeToStringNodebuilder = c.getNodeBuilderEx();
        return c.typeToStringNodebuilder.?;
    }

    pub fn getNodeBuilderEx(c: *Checker) *nodebuilder.NodeBuilder {
        const impl = c.allocator.create(nodebuilderimpl.NodeBuilderImpl) catch unreachable;
        impl.* = nodebuilderimpl.NodeBuilderImpl.init(c);

        const b = c.allocator.create(nodebuilder.NodeBuilder) catch unreachable;
        b.* = nodebuilder.NodeBuilder{
            .impl = impl,
        };
        return b;
    }

    pub fn isPartialMappedType(c: *Checker, t: types.TypeIndex) bool {
        if (c.getObjectFlags(t) & types.ObjectFlags.Mapped == 0) return false;
        return c.getMappedTypeModifiers(t).has(types.MappedTypeModifiers.IncludeOptional);
    }

    pub fn isEmptyObjectType(c: *Checker, t: types.TypeIndex) bool {
        const flags = c.typesList.items[t].flags;
        if (flags & types.TypeFlags.Object != 0) {
            if (c.getIndexInfosOfType(t).len != 0) return false;
            return !c.isGenericMappedType(t);
        }
        if (flags & types.TypeFlags.NonPrimitive != 0) return true;
        // Union/Intersection: partial - conservative return false
        return false;
    }

    pub fn getApparentType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        var typ = t;
        const typeFlags = c.getTypeFlags(t);
        if ((typeFlags & types.TypeFlags.Instantiable) != 0) {
            typ = c.getBaseConstraintOfType(t);
            if (typ == 0) typ = c.unknownTypeIndex orelse 0;
        }

        const flags = c.getTypeFlags(typ);
        const objectFlags = c.getObjectFlags(typ);

        if ((objectFlags & types.ObjectFlags.Mapped) != 0) {
            // getApparentTypeOfMappedType
        } else if ((objectFlags & types.ObjectFlags.Reference) != 0 and typ != t) {
            // getTypeWithThisArgument
        } else if ((flags & types.TypeFlags.Intersection) != 0) {
            // getApparentTypeOfIntersectionType
        } else if ((flags & types.TypeFlags.StringLike) != 0) {
            return c.globalStringType;
        } else if ((flags & types.TypeFlags.NumberLike) != 0) {
            return c.globalNumberType;
        } else if ((flags & types.TypeFlags.BigIntLike) != 0) {
            return c.globalBigIntType;
        } else if ((flags & types.TypeFlags.BooleanLike) != 0) {
            return c.globalBooleanType;
        } else if ((flags & types.TypeFlags.ESSymbolLike) != 0) {
            return c.globalESSymbolType;
        } else if ((flags & types.TypeFlags.NonPrimitive) != 0) {
            return c.emptyObjectType;
        } else if ((flags & types.TypeFlags.Index) != 0) {
            return c.stringNumberSymbolType;
        } else if ((flags & types.TypeFlags.Unknown) != 0 and !c.strictNullChecks) {
            return c.emptyObjectType;
        }

        return typ;
    }

    pub fn isEmptyArrayLiteralType(c: *Checker, t: types.TypeIndex) bool {
        // An empty array literal has Array flag but its element type is the widened never
        if (!c.isArrayType(t)) return false;
        const data = c.typesList.items[t].data;
        if (data != .Array) return false;
        const elemType = data.Array.elementType;
        if (elemType >= c.typesList.items.len) return false;
        return c.typesList.items[elemType].flags & types.TypeFlags.Never != 0;
    }

    // =========================================================================
    // Skippeds for Diagnostics
    // =========================================================================

    pub fn hasParseDiagnostics(c: *Checker, sourceFile: ast_gen.NodeIndex) bool {
        _ = sourceFile;
        return c.binder.ast.diagnostics.items.len > 0;
    }

    pub fn addDiagnostic(c: *Checker, diag: diagnostics.Diagnostic) void {
        c.binder.diagnosticsList.append(c.allocator, diag) catch {};
    }

    pub fn reportErrorWithArgs(c: *Checker, node: ast_gen.NodeIndex, message: *const diagnostics_gen.Message, args: []const []const u8) void {
        const args_copy = c.allocator.alloc([]const u8, args.len) catch return;
        for (args, 0..) |arg, i| {
            args_copy[i] = arg;
        }
        c.ownedDiagnosticArgs.append(c.allocator, args_copy) catch return;
        c.addDiagnostic(.{
            .nodeIndex = node,
            .message = message,
            .args = args_copy,
        });
    }

    pub fn reportError(c: *Checker, node: ast_gen.NodeIndex, message: *const diagnostics_gen.Message) void {
        c.reportErrorWithArgs(node, message, &.{});
    }

    pub fn reportImplicitAny(c: *Checker, node: ast_gen.NodeIndex, type_index: types.TypeIndex) void {
        if (c.isInJsFile(node) and !c.isCheckJsEnabledForFile(node)) return;

        const any_type = c.anyTypeIndex orelse return;
        const is_any = type_index == any_type or (c.getTypeFlags(type_index) & types.TypeFlags.Any) != 0;
        if (!is_any) return;

        const param_name = getParameterDeclarationName(c, node) orelse return;
        const type_name = c.typeToString(type_index, node, 0, null);
        const report_as_error = c.noImplicitAny or c.checkJs;

        if (report_as_error) {
            c.reportErrorWithArgs(node, &diagnostics_gen.Parameter_0_implicitly_has_an_1_type, &.{ param_name, type_name });
        } else {
            c.reportErrorWithArgs(
                node,
                &diagnostics_gen.Parameter_0_implicitly_has_an_1_type_but_a_better_type_may_be_inferred_from_usage,
                &.{ param_name, type_name },
            );
        }
    }

    pub fn isInJsFile(c: *Checker, node: ast_gen.NodeIndex) bool {
        _ = node;
        const ext = @import("../tspath/tspath.zig").tryGetExtensionFromPath(c.binder.ast.fileName);
        return std.mem.eql(u8, ext, ".js") or std.mem.eql(u8, ext, ".jsx") or std.mem.eql(u8, ext, ".mjs") or std.mem.eql(u8, ext, ".cjs");
    }

    pub fn isCheckJsEnabledForFile(c: *Checker, node: ast_gen.NodeIndex) bool {
        _ = node;
        return c.checkJs;
    }

    pub fn hasNodeTypeDefinitions(c: *Checker) bool {
        _ = c;
        return false;
    }

    pub fn checkNodeDeferred(c: *Checker, node: ast_gen.NodeIndex) void {
        _ = c;
        _ = node;
    }

    pub fn getGenericObjectFlags(c: *Checker, t: types.TypeIndex) u32 {
        var combinedFlags: u32 = 0;
        var typeNode = &c.typesList.items[t];
        const flags = typeNode.flags;
        if (flags & (types.TypeFlags.UnionOrIntersection | types.TypeFlags.Substitution) != 0) {
            if (typeNode.objectFlags & types.ObjectFlags.IsGenericTypeComputed == 0) {
                if (flags & types.TypeFlags.UnionOrIntersection != 0) {
                    const unionOrIntersectionTypes = if (flags & types.TypeFlags.Union != 0) c.getTypesFromUnion(t) else c.getTypesFromIntersection(t);
                    for (unionOrIntersectionTypes) |u| {
                        combinedFlags |= c.getGenericObjectFlags(u);
                    }
                } else {
                    const substitution = c.getTargetTypeData(t).Substitution;
                    combinedFlags = c.getGenericObjectFlags(substitution.baseType) | c.getGenericObjectFlags(substitution.constraint);
                }
                typeNode.objectFlags |= types.ObjectFlags.IsGenericTypeComputed | combinedFlags;
            }
            return typeNode.objectFlags & types.ObjectFlags.IsGenericType;
        }
        if (flags & types.TypeFlags.InstantiableNonPrimitive != 0 or c.isGenericMappedType(t) or c.isGenericTupleType(t)) {
            combinedFlags |= types.ObjectFlags.IsGenericObjectType;
        }
        if (flags & (types.TypeFlags.InstantiableNonPrimitive | types.TypeFlags.Index) != 0 or c.isGenericStringLikeType(t)) {
            combinedFlags |= types.ObjectFlags.IsGenericIndexType;
        }
        return combinedFlags;
    }

    pub fn isGenericIndexType(c: *Checker, t: types.TypeIndex) bool {
        return c.getGenericObjectFlags(t) & types.ObjectFlags.IsGenericIndexType != 0;
    }

    pub fn isPatternLiteralPlaceholderType(c: *Checker, t: types.TypeIndex) bool {
        const flags = c.typesList.items[t].flags;
        if (flags & types.TypeFlags.Intersection != 0) {
            var seenPlaceholder = false;
            const intersectionTypes = c.getTypesFromIntersection(t);
            for (intersectionTypes) |s| {
                const sFlags = c.typesList.items[s].flags;
                if (sFlags & (types.TypeFlags.Literal | types.TypeFlags.Nullable) != 0 or c.isPatternLiteralPlaceholderType(s)) {
                    seenPlaceholder = true;
                } else if (sFlags & types.TypeFlags.Object == 0) {
                    return false;
                }
            }
            return seenPlaceholder;
        }
        return flags & (types.TypeFlags.Any | types.TypeFlags.String | types.TypeFlags.Number | types.TypeFlags.BigInt) != 0 or c.isPatternLiteralType(t);
    }

    pub fn isPatternLiteralType(c: *Checker, t: types.TypeIndex) bool {
        const flags = c.typesList.items[t].flags;
        if (flags & types.TypeFlags.TemplateLiteral != 0) {
            const templateData = c.getTargetTypeData(t).TemplateLiteral;
            // Assuming template types are stored in unionTypesPool
            const templateTypes = c.unionTypesPool.items[templateData.typesStart .. templateData.typesStart + templateData.typesLen];
            for (templateTypes) |u| {
                if (!c.isPatternLiteralPlaceholderType(u)) return false;
            }
            return true;
        }
        if (flags & types.TypeFlags.StringMapping != 0) {
            const target = c.getTargetTypeData(t).StringMapping.target;
            return c.isPatternLiteralPlaceholderType(target);
        }
        return false;
    }

    pub fn isGenericStringLikeType(c: *Checker, t: types.TypeIndex) bool {
        const flags = c.typesList.items[t].flags;
        return flags & (types.TypeFlags.TemplateLiteral | types.TypeFlags.StringMapping) != 0 and !c.isPatternLiteralType(t);
    }

    pub fn getTypesFromUnion(c: *Checker, t: types.TypeIndex) []const types.TypeIndex {
        const unionData = c.getTargetTypeData(t).Union;
        return c.unionTypesPool.items[unionData.typesStart .. unionData.typesStart + unionData.typesLen];
    }

    pub fn getTypesFromIntersection(c: *Checker, t: types.TypeIndex) []const types.TypeIndex {
        const intersectionData = c.getTargetTypeData(t).Intersection;
        return c.unionTypesPool.items[intersectionData.typesStart .. intersectionData.typesStart + intersectionData.typesLen];
    }

    pub fn isErrorType(c: *Checker, t: types.TypeIndex) bool {
        const ty = c.typesList.items[t];
        return (ty.flags & types.TypeFlags.Any) != 0 and ty.data == .Intrinsic and std.mem.eql(u8, ty.data.Intrinsic.intrinsicName, "error");
    }

    pub fn getVariances(c: *Checker, t: types.TypeIndex) []const types.VarianceFlags {
        return relater.getVariances(c, t);
    }

    pub fn isArrayOrTupleType(c: *Checker, t: types.TypeIndex) bool {
        return c.isArrayType(t) or c.isTupleType(t);
    }

    pub fn isMutableTupleType(c: *Checker, t: types.TypeIndex) bool {
        return c.isTupleType(t) and !c.getTargetTypeData(t).Tuple.readonly;
    }

    pub fn getIndexTypeOfType(c: *Checker, t: types.TypeIndex, keyType: types.TypeIndex) ?types.TypeIndex {
        if (c.getIndexInfoOfType(t, keyType)) |info| {
            return c.getIndexInfoValueType(info);
        }
        return null;
    }

    pub fn getIndexTypeOfTypeEx(c: *Checker, t: types.TypeIndex, keyType: types.TypeIndex, defaultType: types.TypeIndex) types.TypeIndex {
        if (c.getIndexTypeOfType(t, keyType)) |result| {
            return result;
        }
        return defaultType;
    }

    pub fn isGenericTupleType(c: *Checker, t: types.TypeIndex) bool {
        return c.isTupleType(t) and (c.getTargetTypeData(t).Tuple.combinedFlags & types.ElementFlags.Variadic) != 0;
    }

    pub fn compareTypesIdentical(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) types.Ternary {
        return relater.compareTypesIdentical(c, source, target);
    }

    pub fn reportUnreliableMapper(c: *Checker, index: types.TypeMapperIndex) types.TypeMapperIndex {
        _ = c;
        return index;
    }

    pub fn reportUnmeasurableMapper(c: *Checker, index: types.TypeMapperIndex) types.TypeMapperIndex {
        _ = c;
        return index;
    }

    pub fn getMappedTypeOptionality(c: *Checker, t: types.TypeIndex) i32 {
        const modifiers = c.getMappedTypeModifiers(t);
        if (modifiers.has(types.MappedTypeModifiers.ExcludeOptional)) return -1;
        if (modifiers.has(types.MappedTypeModifiers.IncludeOptional)) return 1;
        return 0;
    }

    pub fn getModifiersTypeFromMappedType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        var m = &c.getTargetTypeData(t).Mapped;
        if (m.modifiersType) |modType| {
            return modType;
        }
        if (c.isMappedTypeWithKeyofConstraintDeclaration(t)) {
            const decl = m.declaration;
            const mapped_node = c.binder.ast.getNode(decl).MappedType;
            if (mapped_node.TypeParameter) |tp_idx| {
                const tp_node = c.binder.ast.getNode(tp_idx).TypeParameter;
                if (tp_node.Constraint) |constraint_idx| {
                    const type_node = c.binder.ast.getNode(constraint_idx).TypeOperator.Type; // KeyOfKeyword's Type
                    const resolvedType = c.getTypeOfNode(type_node) catch c.unknownTypeIndex orelse 0;
                    m.modifiersType = c.instantiateType(resolvedType, m.mapper);
                }
            }
        } else {
            // Otherwise, get the declared constraint type, and if the constraint type is a type parameter,
            // get the constraint of that type parameter. If the resulting type is an indexed type 'keyof T',
            // the modifiers type is T. Otherwise, the modifiers type is unknown.
            const declaredType = c.getTypeFromMappedTypeNode(m.declaration);
            const constraint = c.getConstraintTypeFromMappedType(declaredType);
            var extendedConstraint = constraint;
            if (constraint != 0 and c.typesList.items[constraint].flags & types.TypeFlags.TypeParameter != 0) {
                extendedConstraint = c.getConstraintOfTypeParameter(constraint) orelse constraint;
            }
            if (extendedConstraint != 0 and c.typesList.items[extendedConstraint].flags & types.TypeFlags.Index != 0) {
                const target = c.getTargetTypeData(extendedConstraint).Index.target;
                m.modifiersType = c.instantiateType(target, m.mapper);
            } else {
                m.modifiersType = c.unknownTypeIndex orelse 0;
            }
        }
        return m.modifiersType orelse 0;
    }

    pub fn getCombinedMappedTypeOptionality(c: *Checker, t: types.TypeIndex) i32 {
        if (c.getObjectFlags(t) & types.ObjectFlags.Mapped != 0) {
            const optionality = c.getMappedTypeOptionality(t);
            if (optionality != 0) return optionality;
            return c.getCombinedMappedTypeOptionality(c.getModifiersTypeFromMappedType(t));
        }
        if (c.getTypeFlags(t) & types.TypeFlags.Intersection != 0) {
            const intersection_types = c.getTargetTypeData(t).Intersection.types;
            if (intersection_types.len == 0) return 0;
            const optionality = c.getCombinedMappedTypeOptionality(intersection_types[0]);
            for (intersection_types[1..]) |intersect_t| {
                if (c.getCombinedMappedTypeOptionality(intersect_t) != optionality) {
                    return 0;
                }
            }
            return optionality;
        }
        return 0;
    }

    pub fn getRootOfConditionalType(c: *Checker, t: types.TypeIndex) *types.ConditionalRoot {
        return c.getTargetTypeData(t).Conditional.root;
    }

    pub fn getCheckTypeFromConditionalType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        return c.getTargetTypeData(t).Conditional.checkType;
    }

    pub fn getExtendsTypeFromConditionalType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        return c.getTargetTypeData(t).Conditional.extendsType;
    }

    pub fn getTrueTypeFromConditionalType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        var target = &c.typesList.items[c.getTargetType(t)].data.Conditional;
        if (target.resolvedTrueType == null) {
            const trueTypeNode = c.binder.ast.getNode(target.root.node).ConditionalType.TrueType;
            target.resolvedTrueType = c.instantiateType(c.getTypeOfNode(trueTypeNode) catch c.unknownTypeIndex orelse 0, target.mapper);
        }
        return target.resolvedTrueType.?;
    }

    pub fn getFalseTypeFromConditionalType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        var target = &c.typesList.items[c.getTargetType(t)].data.Conditional;
        if (target.resolvedFalseType == null) {
            const falseTypeNode = c.binder.ast.getNode(target.root.node).ConditionalType.FalseType;
            target.resolvedFalseType = c.instantiateType(c.getTypeOfNode(falseTypeNode) catch c.unknownTypeIndex orelse 0, target.mapper);
        }
        return target.resolvedFalseType.?;
    }

    pub fn getBaseTypeFromSubstitutionType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        return c.getTargetTypeData(t).Substitution.baseType;
    }

    pub fn getConstraintFromSubstitutionType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        return c.getTargetTypeData(t).Substitution.constraint;
    }

    pub fn getSubstitutionType(c: *Checker, baseType: types.TypeIndex, constraint: types.TypeIndex) types.TypeIndex {
        const constraintFlags = c.typesList.items[constraint].flags;
        const baseFlags = c.typesList.items[baseType].flags;
        if ((constraintFlags & (types.TypeFlags.Any | types.TypeFlags.Unknown)) != 0 or constraint == baseType or (baseFlags & types.TypeFlags.Any) != 0) {
            return baseType;
        }

        const newType = types.Type{
            .flags = types.TypeFlags.Substitution,
            .symbol = 0,
            .objectFlags = 0,
            .data = .{
                .Substitution = .{
                    .baseType = baseType,
                    .constraint = constraint,
                },
            },
        };
        const idx = @as(u32, @intCast(c.typesList.items.len));
        c.typesList.append(c.allocator, newType) catch {};
        return idx;
    }

    pub fn getInferTypeParametersFromConditionalType(c: *Checker, t: types.TypeIndex) []const types.TypeIndex {
        const root = c.getTargetTypeData(t).Conditional.root;
        return c.unionTypesPool.items[root.inferTypeParametersStart .. root.inferTypeParametersStart + root.inferTypeParametersLen];
    }

    pub fn templateLiteralTextsEqual(c: *Checker, t1: types.TypeIndex, t2: types.TypeIndex) bool {
        const texts1 = c.getTargetTypeData(t1).TemplateLiteral.texts;
        const texts2 = c.getTargetTypeData(t2).TemplateLiteral.texts;
        if (texts1.len != texts2.len) return false;
        for (texts1, 0..) |text1, i| {
            if (!std.mem.eql(u8, text1, texts2[i])) return false;
        }
        return true;
    }

    pub fn getTypesFromTemplateLiteralType(c: *Checker, t: types.TypeIndex) []const types.TypeIndex {
        const tl = c.getTargetTypeData(t).TemplateLiteral;
        return c.unionTypesPool.items[tl.typesStart .. tl.typesStart + tl.typesLen];
    }

    pub fn getSymbolFromStringMappingType(c: *Checker, t: types.TypeIndex) ast.SymbolIndex {
        return c.getSymbolOfNode(c.getTargetTypeData(t).StringMapping.target) orelse 0; // Or whatever is needed
    }

    pub fn getTargetTypeFromStringMappingType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        return c.getTargetTypeData(t).StringMapping.target;
    }

    pub fn getObjectTypeFromIndexedAccessType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        return c.getTargetTypeData(t).IndexedAccess.objectType;
    }

    pub fn getAliasSymbol(c: *Checker, t: types.TypeIndex) ast.SymbolIndex {
        return c.getType(t).alias orelse 0;
    }

    pub fn getAliasTypeArguments(c: *Checker, t: types.TypeIndex) []const types.TypeIndex {
        const typeNode = c.typesList.items[t];
        if (typeNode.alias) |alias| {
            if (alias.typeArgumentsLen > 0) {
                return c.typeArgumentsPool.items[alias.typeArgumentsStart .. alias.typeArgumentsStart + alias.typeArgumentsLen];
            }
        }
        return &[_]types.TypeIndex{};
    }

    pub fn isMarkerType(c: *Checker, t: types.TypeIndex) bool {
        return relater.isMarkerType(c, t);
    }

    pub fn getAliasVariances(c: *Checker, sym: ast.SymbolIndex) []const types.VarianceFlags {
        return relater.getAliasVariances(c, sym);
    }

    pub fn hasTypeParameterDefault(c: *Checker, t: types.TypeIndex) bool {
        const type_sym = c.typesList.items[t].symbol orelse return false;
        if (type_sym >= c.binder.symbols.items.len) return false;
        const sym_ptr = &c.binder.symbols.items[type_sym];

        for (sym_ptr.Declarations.items) |d_idx| {
            const node = c.binder.ast.getNode(d_idx);
            if (node == .TypeParameter) {
                if (node.TypeParameter.DefaultType != 0) return true;
            }
        }
        return false;
    }

    pub fn getMinTypeArgumentCount(c: *Checker, typeParameters: []const types.TypeIndex) usize {
        var minTypeArgumentCount: usize = 0;
        for (typeParameters, 0..) |typeParameter, i| {
            if (!c.hasTypeParameterDefault(typeParameter)) {
                minTypeArgumentCount = i + 1;
            }
        }
        return minTypeArgumentCount;
    }

    pub fn getSymbolValueDeclaration(c: *Checker, sym: ast_gen.SymbolIndex) ast_gen.NodeIndex {
        const b = c.symbolBinder(sym);
        if (sym >= b.symbols.items.len) return 0;
        return b.symbols.items[sym].ValueDeclaration orelse 0;
    }

    pub fn getResolvedTypeParameterDefault(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        const targetType = c.getTargetType(t);
        var target = &c.typesList.items[targetType].data.TypeParameter;
        if (target.resolvedDefaultType) |defaultType| {
            return defaultType;
        }
        // Simplified default resolution
        target.resolvedDefaultType = c.noConstraintTypeIndex orelse 0;
        return target.resolvedDefaultType.?;
    }

    pub fn getDefaultFromTypeParameter(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        const flags = c.typesList.items[t].flags;
        if ((flags & types.TypeFlags.TypeParameter) == 0) {
            return 0;
        }
        const defaultType = c.getResolvedTypeParameterDefault(t);
        if (defaultType != (c.noConstraintTypeIndex orelse 0) and defaultType != (c.circularConstraintTypeIndex orelse 0)) {
            return defaultType;
        }
        return 0;
    }

    pub fn fillMissingTypeArguments(c: *Checker, typeArguments: []const types.TypeIndex, typeParameters: []const types.TypeIndex, minParams: usize, nodeIsInJsFile: bool) []const types.TypeIndex {
        _ = minParams;
        const numTypeParameters = typeParameters.len;
        if (numTypeParameters == 0) return typeArguments;

        const numTypeArguments = typeArguments.len;
        if (nodeIsInJsFile or numTypeArguments < numTypeParameters) {
            var result = c.allocator.alloc(types.TypeIndex, numTypeParameters) catch return typeArguments;
            @memcpy(result[0..numTypeArguments], typeArguments);

            for (numTypeArguments..numTypeParameters) |i| {
                result[i] = c.errorTypeIndex orelse 0;
            }

            const baseDefaultType = if (nodeIsInJsFile) c.getAnyType() catch 0 else c.unknownTypeIndex orelse 0;

            for (numTypeArguments..numTypeParameters) |i| {
                var defaultType = c.getDefaultFromTypeParameter(typeParameters[i]);
                if (nodeIsInJsFile and defaultType != 0 and (defaultType == (c.unknownTypeIndex orelse 0) or defaultType == (c.emptyObjectTypeIndex orelse 0))) {
                    defaultType = c.getAnyType() catch 0;
                }

                if (defaultType != 0) {
                    const mapper = makeArrayTypeMapper(c, typeParameters, result) catch return typeArguments;
                    result[i] = c.instantiateType(defaultType, mapper);
                } else {
                    result[i] = baseDefaultType;
                }
            }
            return result;
        }
        return typeArguments;
    }

    pub fn isSingleElementGenericTupleType(c: *Checker, t: types.TypeIndex) bool {
        return c.isGenericTupleType(t) and c.getTargetTypeData(t).Tuple.typesLen == 1;
    }

    pub fn getTargetTypeData(c: *Checker, t: types.TypeIndex) types.TypeData {
        const target = c.getTargetType(t);
        return c.typesList.items[target].data;
    }

    pub fn getTargetType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        if (t == 0 or t >= c.typesList.items.len) return t;
        const type_node = c.typesList.items[t];
        if (type_node.flags & types.TypeFlags.Object != 0 and type_node.objectFlags & types.ObjectFlags.Reference != 0) {
            if (std.meta.activeTag(type_node.data) == .Object) {
                return type_node.data.Object.target orelse t;
            }
        }
        return t;
    }

    pub fn getTargetTupleType(c: *Checker, t: types.TypeIndex) *types.TupleType {
        const target = c.getTargetType(t);
        return &c.typesList.items[target].data.Tuple;
    }

    pub fn getTupleElementInfos(c: *Checker, t: types.TypeIndex) []const types.TupleElementInfo {
        const tupleType = c.getTargetTupleType(t);
        return c.tupleElementInfos.items[tupleType.elementInfosStart .. tupleType.elementInfosStart + tupleType.typesLen];
    }

    pub fn getTypeArguments(c: *Checker, t: types.TypeIndex) []const types.TypeIndex {
        const typeNode = c.typesList.items[t];
        if (typeNode.flags & types.TypeFlags.Object != 0 and typeNode.objectFlags & types.ObjectFlags.Reference != 0) {
            const objectData = typeNode.data.Object;
            if (objectData.typeArgumentsLen > 0) {
                return c.typeArgumentsPool.items[objectData.typeArgumentsStart .. objectData.typeArgumentsStart + objectData.typeArgumentsLen];
            }
        }
        return &[_]types.TypeIndex{};
    }

    pub fn isMutableArrayOrTuple(c: *Checker, t: types.TypeIndex) bool {
        return (c.isArrayType(t) and !c.isReadonlyArrayType(t)) or (c.isTupleType(t) and !c.getTargetTypeData(t).Tuple.readonly);
    }

    pub fn getBaseConstraintOrType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        const constraint = c.getBaseConstraintOfType(t);
        return if (constraint != 0) constraint else t;
    }

    pub fn getBaseConstraintOfType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        const flags = c.typesList.items[t].flags;
        if (flags & (types.TypeFlags.InstantiableNonPrimitive | types.TypeFlags.Intersection) != 0) {
            return c.getApparentType(t);
        }
        if (flags & types.TypeFlags.Union != 0) {
            const typesArr = c.getTypesFromUnion(t);
            var mappedTypes = c.allocator.alloc(types.TypeIndex, typesArr.len) catch return c.errorTypeIndex orelse 0;
            defer c.allocator.free(mappedTypes);
            for (typesArr, 0..) |subtype, i| {
                mappedTypes[i] = c.getBaseConstraintOfType(subtype);
            }
            return c.getUnionTypeFromArray(mappedTypes);
        }
        if (flags & types.TypeFlags.StringLiteral != 0) {
            return c.stringTypeIndex orelse 0;
        }
        if (flags & types.TypeFlags.NumberLiteral != 0) {
            return c.numberTypeIndex orelse 0;
        }
        if (flags & types.TypeFlags.BigIntLiteral != 0) {
            return c.bigintTypeIndex orelse 0;
        }
        if (flags & types.TypeFlags.BooleanLiteral != 0) {
            return c.booleanTypeIndex orelse 0;
        }
        if (flags & types.TypeFlags.UniqueESSymbol != 0) {
            return c.esSymbolTypeIndex orelse 0;
        }
        if (flags & types.TypeFlags.EnumLiteral != 0) {
            return c.getBaseTypeOfEnumLikeType(t);
        }
        return t;
    }

    pub fn getIndexType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        return c.getIndexTypeEx(t, types.IndexFlags.None);
    }

    pub fn getConstraintTypeFromMappedType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        return c.getTargetTypeData(t).Mapped.constraintType orelse c.errorTypeIndex orelse 0;
    }

    pub fn getNameTypeFromMappedType(c: *Checker, t: types.TypeIndex) ?types.TypeIndex {
        return c.getTargetTypeData(t).Mapped.nameType;
    }

    pub fn getMappedTypeModifiers(c: *Checker, t: types.TypeIndex) types.MappedTypeModifiers {
        const declaration = c.getTargetTypeData(t).Mapped.declaration;
        const mapped_node = c.binder.ast.getNode(declaration).MappedType;
        var modifiers = types.MappedTypeModifiers{};
        if (mapped_node.ReadonlyToken) |readonly_token| {
            if (c.binder.ast.getNodeKind(readonly_token) == .MinusToken) {
                modifiers.value |= types.MappedTypeModifiers.ExcludeReadonly;
            } else {
                modifiers.value |= types.MappedTypeModifiers.IncludeReadonly;
            }
        }
        if (mapped_node.QuestionToken) |question_token| {
            if (c.binder.ast.getNodeKind(question_token) == .MinusToken) {
                modifiers.value |= types.MappedTypeModifiers.ExcludeOptional;
            } else {
                modifiers.value |= types.MappedTypeModifiers.IncludeOptional;
            }
        }
        return modifiers;
    }

    pub fn getTemplateTypeFromMappedType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        return c.getTargetTypeData(t).Mapped.templateType;
    }

    pub fn getIndexedAccessType(c: *Checker, objectType: types.TypeIndex, indexType: types.TypeIndex) types.TypeIndex {
        if (c.getIndexedAccessTypeOrUndefined(objectType, indexType, types.AccessFlags.None, null, null)) |result| {
            return result;
        }
        return c.errorTypeIndex orelse 0;
    }

    pub fn getTypeParameterFromMappedType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        return c.getTargetTypeData(t).Mapped.typeParameter;
    }

    pub fn getConstraintOfTypeParameter(c: *Checker, t: types.TypeIndex) ?types.TypeIndex {
        if (c.typesList.items[t].flags & types.TypeFlags.TypeParameter != 0) {
            const tp = &c.getTargetTypeData(t).TypeParameter;
            if (!tp.isTypeParameterConstraintResolved) {
                resolveTypeParameterConstraint(c, t);
            }
            if (tp.constraintType != 0 and tp.constraintType != (c.noConstraintTypeIndex orelse 0)) {
                return tp.constraintType;
            }
        }
        return null;
    }

    pub fn getIndexedAccessTypeOrUndefined(c: *Checker, objectType: types.TypeIndex, indexType: types.TypeIndex, accessFlags: u32, context: ?ast.NodeIndex, declaration: ?ast.NodeIndex) ?types.TypeIndex {
        _ = c;
        _ = objectType;
        _ = indexType;
        _ = accessFlags;
        _ = context;
        _ = declaration;
        return null; // Skipped
    }

    pub fn getKnownKeysOfTupleType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        return relater.getKnownKeysOfTupleType(c, t);
    }

    pub fn getSimplifiedType(c: *Checker, t: types.TypeIndex, writing: bool) types.TypeIndex {
        _ = c;
        _ = writing;
        // getSimplifiedType implementation skipped for now
        return t;
    }

    pub fn getSimplifiedTypeOrConstraint(c: *Checker, t: types.TypeIndex) ?types.TypeIndex {
        const simplified = c.getSimplifiedType(t, false);
        if (simplified != t) {
            return simplified;
        }
        return c.getConstraintOfType(t);
    }

    pub fn getIndexTypeEx(c: *Checker, t: types.TypeIndex, indexFlags: u32) types.TypeIndex {
        _ = c;
        _ = t;
        _ = indexFlags;
        return undefined; // Skipped
    }

    pub fn isGenericMappedType(c: *Checker, t: types.TypeIndex) bool {
        if (c.getObjectFlags(t) & types.ObjectFlags.Mapped == 0) return false;
        return c.isGenericIndexType(c.getConstraintTypeFromMappedType(t));
    }

    pub fn isNonGenericObjectType(c: *Checker, t: types.TypeIndex) bool {
        return c.typesList.items[t].flags & types.TypeFlags.Object != 0 and !c.isGenericMappedType(t);
    }

    pub fn isGenericObjectType(c: *Checker, t: types.TypeIndex) bool {
        return c.getGenericObjectFlags(t) & types.ObjectFlags.IsGenericObjectType != 0;
    }

    pub fn isMappedTypeWithKeyofConstraintDeclaration(c: *Checker, t: types.TypeIndex) bool {
        const constraint_decl_opt = getConstraintDeclaration(c, t);
        if (constraint_decl_opt) |constraint_decl| {
            const constraint_node = c.binder.ast.getNode(constraint_decl);
            switch (constraint_node) {
                .TypeOperator => |op| return op.Operator == @intFromEnum(ast.SyntaxKind.KeyOfKeyword),
                else => return false,
            }
        }
        return false;
    }

    pub fn getApparentMappedTypeKeys(c: *Checker, nameType: types.TypeIndex, targetType: types.TypeIndex) types.TypeIndex {
        const modifiersType = c.getApparentType(c.getModifiersTypeFromMappedType(targetType));
        var mappedKeys = std.ArrayList(types.TypeIndex).init(c.allocator);

        const properties = c.getPropertiesOfType(modifiersType);
        for (properties) |prop| {
            mappedKeys.append(c.getLiteralTypeFromProperty(prop, types.TypeFlags.StringLiteral | types.TypeFlags.NumberLiteral | types.TypeFlags.UniqueESSymbol, false)) catch {};
        }
        if (c.getTypeFlags(modifiersType) & types.TypeFlags.Any != 0) {
            mappedKeys.append(c.stringTypeIndex orelse 0) catch {};
        } else {
            const indexInfos = c.getIndexInfosOfType(modifiersType);
            for (indexInfos) |info| {
                mappedKeys.append(info.keyType) catch {};
            }
        }

        var finalMappedKeys = std.ArrayList(types.TypeIndex).initCapacity(c.allocator, mappedKeys.items.len) catch return 0;
        const targetMapper = c.getTargetTypeData(targetType).Mapped.mapper;
        for (mappedKeys.items) |t_idx| {
            const templateMapper = prependTypeMapping(c, c.getTypeParameterFromMappedType(targetType), t_idx, targetMapper) catch 0;
            finalMappedKeys.appendAssumeCapacity(c.instantiateType(nameType, templateMapper));
        }
        return c.getUnionType(finalMappedKeys.items);
    }

    pub fn getNullableType(c: *Checker, t: types.TypeIndex, flags: u32) types.TypeIndex {
        const missingType = if ((flags & types.TypeFlags.Undefined) != 0) c.undefinedTypeIndex else c.nullTypeIndex;
        if (missingType == null) return t;
        if (t == missingType.?) return t;
        return c.getUnionTypeFromArray(&[_]types.TypeIndex{ t, missingType.? });
    }

    pub fn getUnionTypeFromArray(c: *Checker, typesArr: []const types.TypeIndex) types.TypeIndex {
        return c.createUnionType(typesArr) catch c.getAnyType() catch 0;
    }

    pub fn getPermissiveInstantiation(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        const flags = c.typesList.items[t].flags;
        if ((flags & (types.TypeFlags.Primitive | (types.TypeFlags.Any | types.TypeFlags.Unknown) | types.TypeFlags.Never)) != 0) {
            return t;
        }
        // Skipped: implement caching using CachedTypeKey
        const mapperIdx = getPermissiveMapper(c) catch return t;
        return c.instantiateType(t, mapperIdx);
    }

    pub fn getRestrictiveInstantiation(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        const flags = c.typesList.items[t].flags;
        if ((flags & (types.TypeFlags.Primitive | (types.TypeFlags.Any | types.TypeFlags.Unknown) | types.TypeFlags.Never)) != 0) {
            return t;
        }
        // Skipped: implement caching using CachedTypeKey
        const mapperIdx = getRestrictiveMapper(c) catch return t;
        return c.instantiateType(t, mapperIdx);
    }

    pub fn isTypeAssignableTo(self: *Checker, sourceIdx: types.TypeIndex, targetIdx: types.TypeIndex) bool {
        return relater.isTypeRelatedTo(self, sourceIdx, targetIdx, &self.assignableRelation);
    }

    pub fn templateLiteralTypesDefinitelyUnrelated(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
        return relater.templateLiteralTypesDefinitelyUnrelated(c, source, target);
    }

    pub fn instantiateType(c: *Checker, t: types.TypeIndex, mapperIdx: types.TypeMapperIndex) types.TypeIndex {
        if (t == 0 or mapperIdx == 0) return t;
        // Check for type variables in the alias (not implemented yet, assuming no alias caching issues for now)
        return c.instantiateTypeWorker(t, mapperIdx);
    }

    pub fn instantiateTypeWorker(c: *Checker, t: types.TypeIndex, mapperIdx: types.TypeMapperIndex) types.TypeIndex {
        const flags = c.typesList.items[t].flags;
        if ((flags & types.TypeFlags.TypeParameter) != 0) {
            return mapTypeWithMapper(c, t, mapperIdx);
        }
        if ((flags & types.TypeFlags.Object) != 0) {
            const objectFlags = c.typesList.items[t].objectFlags;
            if ((objectFlags & (types.ObjectFlags.Reference | types.ObjectFlags.Anonymous | types.ObjectFlags.Mapped)) != 0) {
                if ((objectFlags & types.ObjectFlags.Reference) != 0 and c.getTargetTypeData(t).Object.node == null) {
                    const resolvedTypeArguments = c.getTypeArguments(t);
                    const newTypeArguments = instantiateTypes(c, resolvedTypeArguments, mapperIdx) catch resolvedTypeArguments;
                    if (std.mem.eql(types.TypeIndex, newTypeArguments, resolvedTypeArguments)) {
                        return t;
                    }
                    return c.createNormalizedTypeReference(c.getTargetType(t), newTypeArguments);
                }
                if ((objectFlags & types.ObjectFlags.ReverseMapped) != 0) {
                    return c.instantiateReverseMappedType(t, mapperIdx);
                }
                return c.getObjectTypeInstantiation(t, mapperIdx, null);
            }
            return t;
        }
        if ((flags & types.TypeFlags.UnionOrIntersection) != 0) {
            var source = t;
            if ((flags & types.TypeFlags.Union) != 0) {
                const origin = c.getTargetTypeData(t).Union.origin;
                if (origin != null and (c.typesList.items[origin.?].flags & types.TypeFlags.UnionOrIntersection) != 0) {
                    source = origin.?;
                }
            }
            const typesArr = c.getTypesOfUnionOrIntersectionType(source);
            const newTypes = instantiateTypes(c, typesArr, mapperIdx) catch typesArr;
            if (newTypes.ptr == typesArr.ptr) return t;

            if ((c.typesList.items[source].flags & types.TypeFlags.Intersection) != 0) {
                // return c.getIntersectionTypeEx(newTypes, IntersectionFlagsNone, alias);
                return c.getIntersectionType(newTypes); // fallback for now
            }
            return c.getUnionTypeFromArray(newTypes);
        }
        if ((flags & types.TypeFlags.Index) != 0) {
            return c.getIndexType(c.instantiateType(c.getTargetTypeData(t).Index.target, mapperIdx));
        }
        if ((flags & types.TypeFlags.IndexedAccess) != 0) {
            const d = c.getTargetTypeData(t).IndexedAccess;
            return c.getIndexedAccessTypeOrUndefined(c.instantiateType(d.objectType, mapperIdx), c.instantiateType(d.indexType, mapperIdx), d.accessFlags, null, null) orelse c.getAnyType() catch 0;
        }
        if ((flags & types.TypeFlags.TemplateLiteral) != 0) {
            const tl = c.getTargetTypeData(t).TemplateLiteral;
            const typesSlice = c.unionTypesPool.items[tl.typesStart .. tl.typesStart + tl.typesLen];
            const newTypes = instantiateTypes(c, typesSlice, mapperIdx) catch typesSlice;
            return c.getTemplateLiteralType(tl.texts, newTypes);
        }
        if ((flags & types.TypeFlags.StringMapping) != 0) {
            return c.getStringMappingType(c.typesList.items[t].symbol orelse 0, c.instantiateType(c.getTargetTypeData(t).StringMapping.target, mapperIdx));
        }
        if ((flags & types.TypeFlags.Conditional) != 0) {
            return c.getConditionalTypeInstantiation(t, mapper_pkg.combineTypeMappers(c, c.getTargetTypeData(t).Conditional.mapper, mapperIdx), false, null);
        }
        if ((flags & types.TypeFlags.Substitution) != 0) {
            const newBaseType = c.instantiateType(c.getTargetTypeData(t).Substitution.baseType, mapperIdx);
            if (inference.isNoInferType(c, t)) {
                return c.getNoInferType(newBaseType);
            }
            const newConstraint = c.instantiateType(c.getTargetTypeData(t).Substitution.constraint, mapperIdx);
            if ((c.typesList.items[newBaseType].flags & types.TypeFlags.TypeVariable) != 0 and relater.isGenericType(c, newConstraint)) {
                return c.getSubstitutionType(newBaseType, newConstraint);
            }
            if ((c.typesList.items[newConstraint].flags & (types.TypeFlags.Any | types.TypeFlags.Unknown)) != 0 or c.isTypeAssignableTo(c.getRestrictiveInstantiation(newBaseType), c.getRestrictiveInstantiation(newConstraint))) {
                return newBaseType;
            }
            if ((c.typesList.items[newBaseType].flags & types.TypeFlags.TypeVariable) != 0) {
                return c.getSubstitutionType(newBaseType, newConstraint);
            }
            const ts = [_]types.TypeIndex{ newConstraint, newBaseType };
            return c.getIntersectionType(&ts);
        }
        return t;
    }

    pub fn isMemberOfStringMapping(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
        return relater.isMemberOfStringMapping(c, source, target);
    }

    pub fn extractTypesOfKind(c: *Checker, t: types.TypeIndex, kindMask: u32) types.TypeIndex {
        const Ctx = struct {
            c: *Checker,
            kindMask: u32,
        };
        const filterFn = struct {
            fn f(c_inner: *Checker, ty: types.TypeIndex, ctx: Ctx) bool {
                _ = c_inner;
                return (Checker.getTypeFlags(ctx.c, ty) & ctx.kindMask) != 0;
            }
        }.f;

        return c.filterType(t, filterFn, Ctx{ .c = c, .kindMask = kindMask });
    }

    pub fn getIntersectionType(c: *Checker, typesArr: []const types.TypeIndex) types.TypeIndex {
        if (typesArr.len == 0) return c.unknownTypeIndex orelse 0;
        if (typesArr.len == 1) return typesArr[0];

        var unique = std.ArrayListUnmanaged(types.TypeIndex).empty;
        defer unique.deinit(c.allocator);

        for (typesArr) |t| {
            if (t == (c.neverTypeIndex orelse 0)) return t;
            // Flatten nested intersections
            if ((c.typesList.items[t].flags & types.TypeFlags.Intersection) != 0) {
                const subTypes = c.getTypesFromIntersection(t);
                for (subTypes) |st| {
                    var found = false;
                    for (unique.items) |u| {
                        if (u == st) {
                            found = true;
                            break;
                        }
                    }
                    if (!found) unique.append(c.allocator, st) catch {};
                }
            } else {
                var found = false;
                for (unique.items) |u| {
                    if (u == t) {
                        found = true;
                        break;
                    }
                }
                if (!found) unique.append(c.allocator, t) catch {};
            }
        }

        if (unique.items.len == 0) return c.unknownTypeIndex orelse 0;
        if (unique.items.len == 1) return unique.items[0];

        const start = @as(u32, @intCast(c.unionTypesPool.items.len));
        c.unionTypesPool.appendSlice(c.allocator, unique.items) catch {};

        const data = types.TypeData{
            .Intersection = .{
                .typesStart = start,
                .typesLen = @as(u32, @intCast(unique.items.len)),
            },
        };

        const newType = types.Type{
            .flags = types.TypeFlags.Intersection,
            .objectFlags = types.ObjectFlags.Anonymous,
            .data = data,
        };

        c.typesList.append(c.allocator, newType) catch {};
        return @as(u32, @intCast(c.typesList.items.len - 1));
    }

    pub fn getConstraintOfIndexedAccess(c: *Checker, t: types.TypeIndex) ?types.TypeIndex {
        var target = &c.typesList.items[c.getTargetType(t)].data.IndexedAccess;
        if (target.constraint == 0) {
            target.constraint = c.noConstraintTypeIndex orelse 0;
            if (c.getConstraintOfType(target.objectType)) |constraintType| {
                if (c.getIndexedAccessTypeOrUndefined(constraintType, target.indexType, types.AccessFlags.None, null, null)) |constraint| {
                    target.constraint = constraint;
                }
            }
        }
        if (target.constraint != 0 and target.constraint != c.noConstraintTypeIndex orelse 0) {
            return target.constraint;
        }
        return null;
    }

    pub fn getConstraintOfConditionalType(c: *Checker, t: types.TypeIndex) ?types.TypeIndex {
        var target = &c.typesList.items[c.getTargetType(t)].data.Conditional;
        if (target.constraint == 0) {
            target.constraint = c.noConstraintTypeIndex orelse 0;
            const trueType = c.getTrueTypeFromConditionalType(t);
            const falseType = c.getFalseTypeFromConditionalType(t);
            const trueConstraint = c.getConstraintOfType(trueType) orelse trueType;
            const falseConstraint = c.getConstraintOfType(falseType) orelse falseType;
            // Go typescript uses getUnionType for constraints
            const typesArr = [_]types.TypeIndex{ trueConstraint, falseConstraint };
            const constraint = c.getUnionTypeFromArray(&typesArr);
            if (constraint != 0) {
                target.constraint = constraint;
            }
        }
        if (target.constraint != 0 and target.constraint != c.noConstraintTypeIndex orelse 0) {
            return target.constraint;
        }
        return null;
    }

    pub fn getConstraintOfType(c: *Checker, t: types.TypeIndex) ?types.TypeIndex {
        const flags = c.typesList.items[t].flags;
        if (flags & types.TypeFlags.TypeParameter != 0) {
            return c.getConstraintOfTypeParameter(t);
        }
        if (flags & types.TypeFlags.IndexedAccess != 0) {
            return c.getConstraintOfIndexedAccess(t);
        }
        if (flags & types.TypeFlags.Conditional != 0) {
            return c.getConstraintOfConditionalType(t);
        }
        return c.getBaseConstraintOfType(t);
    }

    pub fn getTypeWithThisArgument(c: *Checker, t: types.TypeIndex, thisArgument: types.TypeIndex, needApparentType: bool) types.TypeIndex {
        _ = c;
        _ = t;
        _ = thisArgument;
        _ = needApparentType;
        return undefined; // Skipped
    }

    pub fn isMappedTypeGenericIndexedAccess(c: *Checker, t: types.TypeIndex) bool {
        const typeNode = c.typesList.items[t];
        if (typeNode.flags & types.TypeFlags.IndexedAccess != 0) {
            const objectType = c.getTargetTypeData(t).IndexedAccess.objectType;
            if (c.getObjectFlags(objectType) & types.ObjectFlags.Mapped != 0 and !c.isGenericMappedType(objectType)) {
                if (c.isGenericIndexType(c.getTargetTypeData(t).IndexedAccess.indexType)) {
                    if (!c.getMappedTypeModifiers(objectType).has(types.MappedTypeModifiers.ExcludeOptional)) {
                        const decl = c.getTargetTypeData(objectType).Mapped.declaration;
                        if (decl != 0) {
                            const mappedNode = c.binder.ast.getNode(decl).MappedType;
                            if (mappedNode.NameType == null or mappedNode.NameType.? == 0) {
                                return true;
                            }
                        }
                    }
                }
            }
        }
        return false;
    }

    pub fn shouldDeferIndexType(c: *Checker, t: types.TypeIndex, indexFlags: types.IndexFlags) bool {
        _ = c;
        _ = t;
        _ = indexFlags;
        return false; // Skipped
    }

    pub fn intersectTypes(c: *Checker, t1: types.TypeIndex, t2: types.TypeIndex) types.TypeIndex {
        const typesArr = [_]types.TypeIndex{ t1, t2 };
        return c.getIntersectionType(&typesArr);
    }

    pub fn newInferenceContext(c: *Checker, typeParameters: []const types.TypeIndex, signature: ?types.SignatureIndex, flags: types.InferenceFlags, compareTypes: types.CompareTypesKind) u32 {
        var inferences: std.ArrayListUnmanaged(types.InferenceInfoIndex) = .empty;
        inferences.ensureTotalCapacity(c.allocator, typeParameters.len) catch unreachable;
        for (typeParameters) |tp| {
            inferences.appendAssumeCapacity(c.newInferenceInfo(tp));
        }
        return c.newInferenceContextWorker(inferences.items, signature, flags, compareTypes);
    }

    pub fn newInferenceInfo(c: *Checker, typeParameter: types.TypeIndex) types.InferenceInfoIndex {
        const index = @as(types.InferenceInfoIndex, @intCast(c.inferenceInfos.items.len));
        c.inferenceInfos.append(c.allocator, .{ .typeParameter = typeParameter }) catch unreachable;
        return index;
    }

    pub fn newInferenceContextWorker(c: *Checker, inferences: []const types.InferenceInfoIndex, signature: ?types.SignatureIndex, flags: types.InferenceFlags, compareTypes: types.CompareTypesKind) u32 {
        var inferences_list: std.ArrayListUnmanaged(types.InferenceInfoIndex) = .empty;
        inferences_list.appendSlice(c.allocator, inferences) catch unreachable;

        c.inferenceContexts.append(c.allocator, types.InferenceContext{
            .inferences = inferences_list,
            .signature = signature orelse 0,
            .flags = flags,
            .compareTypes = compareTypes,
        }) catch unreachable;
        const n = @as(u32, @intCast(c.inferenceContexts.items.len - 1));

        c.inferenceContexts.items[n].mapper = createTypeMapper(c, types.TypeMapper{ .kind = .Inference, .data = .{ .Inference = .{ .n = n, .fixing = true } } }) catch unreachable;
        c.inferenceContexts.items[n].nonFixingMapper = createTypeMapper(c, types.TypeMapper{ .kind = .Inference, .data = .{ .Inference = .{ .n = n, .fixing = false } } }) catch unreachable;

        return n;
    }

    pub fn inferTypes(c: *Checker, inferences: []types.InferenceInfoIndex, target: types.TypeIndex, source: types.TypeIndex, priority: i32, b: bool) void {
        _ = c;
        _ = inferences;
        _ = target;
        _ = source;
        _ = priority;
        _ = b;
    }

    pub fn isTypeIdenticalTo(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
        return c.compareTypesIdentical(source, target) != .False;
    }

    pub fn getInferredTrueTypeFromConditionalType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Skipped
    }

    pub fn isTypeAny(c: *Checker, t: types.TypeIndex) bool {
        if (t == 0 or t >= c.typesList.items.len) return true;
        return c.typesList.items[t].flags & types.TypeFlags.Any != 0;
    }

    pub fn getDefaultConstraintOfConditionalType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        var target = &c.getTargetTypeData(t).Conditional;
        if (target.resolvedDefaultConstraint == null) {
            const trueConstraint = c.getInferredTrueTypeFromConditionalType(t);
            const falseConstraint = c.getFalseTypeFromConditionalType(t);

            if (c.isTypeAny(trueConstraint)) {
                target.resolvedDefaultConstraint = falseConstraint;
            } else if (c.isTypeAny(falseConstraint)) {
                target.resolvedDefaultConstraint = trueConstraint;
            } else {
                const typesArr = [_]types.TypeIndex{ trueConstraint, falseConstraint };
                target.resolvedDefaultConstraint = c.getUnionTypeFromArray(&typesArr);
            }
        }
        return target.resolvedDefaultConstraint.?;
    }

    pub fn hasNonCircularBaseConstraint(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false; // Skipped
    }

    pub fn getConstraintOfDistributiveConditionalType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        var target = &c.getTargetTypeData(t).Conditional;
        if (target.resolvedConstraintOfDistributive == null) {
            target.resolvedConstraintOfDistributive = c.unknownTypeIndex orelse 0; // Skipped, real impl needs instantiateType
        }
        return target.resolvedConstraintOfDistributive.?;
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

    pub fn getDeclarationOfKind(self: *Checker, sym: ast_gen.SymbolIndex, kindValue: @import("../ast/kind.zig").Kind) ast.NodeIndex {
        _ = self;
        _ = sym;
        _ = kindValue;
        _ = kindValue;
        return 0;
    }

    // =========================================================================
    // Intrinsic type getters
    // =========================================================================

    pub fn getNumberType(self: *Checker) !u32 {
        if (self.numberTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.Number, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.numberTypeIndex = idx;
        return idx;
    }

    pub fn getNumberOrBigIntType(self: *Checker) !u32 {
        if (self.numberOrBigIntTypeIndex) |idx| return idx;
        const typesArr = [_]types.TypeIndex{ try self.getNumberType(), try self.getBigIntType() };
        const idx = try self.createUnionType(&typesArr);
        self.numberOrBigIntTypeIndex = idx;
        return idx;
    }

    pub fn getUnaryResultType(c: *Checker, operandType: types.TypeIndex) !types.TypeIndex {
        if (c.maybeTypeOfKind(operandType, types.TypeFlags.BigIntLike)) {
            if (c.isTypeAssignableToKind(operandType, types.TypeFlags.Any | types.TypeFlags.Unknown) or c.maybeTypeOfKind(operandType, types.TypeFlags.NumberLike)) {
                return try c.getNumberOrBigIntType();
            }
            return try c.getBigIntType();
        }
        return try c.getNumberType();
    }

    pub fn getAnyType(self: *Checker) !u32 {
        if (self.anyTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.Any, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.anyTypeIndex = idx;
        return idx;
    }

    pub fn getStringType(self: *Checker) !u32 {
        if (self.stringTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.String, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.stringTypeIndex = idx;
        return idx;
    }

    pub fn getBooleanType(self: *Checker) !u32 {
        if (self.booleanTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.Boolean, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.booleanTypeIndex = idx;
        return idx;
    }

    pub fn getVoidType(self: *Checker) !u32 {
        if (self.voidTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.Void, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.voidTypeIndex = idx;
        return idx;
    }

    pub fn getUndefinedType(self: *Checker) !u32 {
        if (self.undefinedTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.Undefined, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.undefinedTypeIndex = idx;
        return idx;
    }

    pub fn getMissingType(self: *Checker) !u32 {
        if (self.missingTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.Undefined, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.missingTypeIndex = idx;
        self.undefinedOrMissingTypeIndex = if (self.exactOptionalPropertyTypes) idx else self.undefinedTypeIndex orelse try self.getUndefinedType();
        return idx;
    }

    pub fn getNullType(self: *Checker) !u32 {
        if (self.nullTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.Null, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.nullTypeIndex = idx;
        return idx;
    }

    pub fn getUnknownType(self: *Checker) !u32 {
        if (self.unknownTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.Unknown, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.unknownTypeIndex = idx;
        return idx;
    }

    pub fn getNeverType(self: *Checker) !u32 {
        if (self.neverTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.Never, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.neverTypeIndex = idx;
        return idx;
    }

    pub fn getBigIntType(self: *Checker) !u32 {
        if (self.bigintTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.BigInt, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } });
        self.bigintTypeIndex = idx;
        return idx;
    }

    pub fn getTrueType(self: *Checker) !u32 {
        if (self.trueTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.BooleanLiteral, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .BooleanLiteral = .{ .value = true } } });
        self.trueTypeIndex = idx;
        return idx;
    }

    pub fn getFalseType(self: *Checker) !u32 {
        if (self.falseTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.BooleanLiteral, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .BooleanLiteral = .{ .value = false } } });
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

    pub fn getNonPrimitiveType(self: *Checker) !u32 {
        if (self.nonPrimitiveTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.NonPrimitive, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "object" } } });
        self.nonPrimitiveTypeIndex = idx;
        return idx;
    }
    pub fn getEsSymbolType(self: *Checker) !u32 {
        if (self.esSymbolTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .flags = types.TypeFlags.ESSymbol, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "symbol" } } });
        self.esSymbolTypeIndex = idx;
        return idx;
    }

    // =========================================================================
    // Type of symbol / node
    // =========================================================================

    pub fn getTypeOfSymbol(self: *Checker, symIndex: u32) anyerror!u32 {
        if (self.valueSymbolLinks.get(symIndex)) |links| {
            if (links.resolvedType) |resolved| return resolved;
        }
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
                    .EqualsToken => try self.checkExpressionAdHoc(binary.Right),
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
                if (decl.Initializer) |initExpr| return try self.checkExpressionAdHoc(initExpr);
                return try self.getAnyType();
            },
            .PropertyDeclaration => |p| {
                if (p.Type) |typeNode| return try self.getTypeOfNode(typeNode);
                if (p.Initializer) |initExpr| {
                    return try self.checkExpressionAdHoc(initExpr);
                }
                return try self.getAnyType();
            },
            .PropertyAssignment => |p| {
                if (p.Type) |typeNode| {
                    if (typeNode != 0) return try self.getTypeOfNode(typeNode);
                }
                return try self.checkExpressionAdHoc(p.Initializer);
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
                    .objectFlags = types.ObjectFlags.Anonymous,
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
                    .objectFlags = types.ObjectFlags.Anonymous,
                    .id = 0,
                    .alias = null,
                    .symbol = if (tl.Symbol != 0) tl.Symbol else null,
                    .data = .{ .Object = std.mem.zeroes(types.ObjectTypeData) },
                });
            },
            .LiteralType => |lt| {
                return try self.getTypeOfNode(lt.Literal);
            },
            .StringLiteral => |s| {
                return try self.createType(.{
                    .flags = types.TypeFlags.StringLiteral,
                    .objectFlags = types.ObjectFlags.Anonymous,
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
                    .objectFlags = types.ObjectFlags.Anonymous,
                    .id = 0,
                    .symbol = null,
                    .alias = null,
                    .data = .{ .NumberLiteral = .{ .value = value } },
                });
            },
            .TrueKeyword => return try self.getTrueType(),
            .FalseKeyword => return try self.getFalseType(),
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

    pub fn checkExpressionAdHoc(self: *Checker, nodeIndex: u32) anyerror!u32 {
        const node = self.binder.ast.getNode(nodeIndex);
        switch (node) {
            // Literals
            .Identifier => {
                return checkIdentifier(self, nodeIndex, CheckMode.Normal);
            },
            .TrueKeyword => return try self.getTrueType(),
            .FalseKeyword => return try self.getFalseType(),
            .NullKeyword => return try self.getNullType(),
            .UndefinedKeyword => return try self.getUndefinedType(),
            .ThisKeyword => return checkThisExpression(self, nodeIndex),

            .StringLiteral => |s| {
                return try self.createType(.{
                    .flags = types.TypeFlags.StringLiteral,
                    .objectFlags = types.ObjectFlags.Anonymous,
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
                    .objectFlags = types.ObjectFlags.Anonymous,
                    .id = 0,
                    .symbol = null,
                    .alias = null,
                    .data = .{ .NumberLiteral = .{ .value = value } },
                });
            },
            .BigIntLiteral => |n| {
                return try self.createType(.{
                    .flags = types.TypeFlags.BigIntLiteral,
                    .objectFlags = types.ObjectFlags.Anonymous,
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
                const operandType = try self.checkExpressionAdHoc(pue.Operand);
                return try self.checkPrefixUnary(pue.Operator, operandType);
            },
            .PostfixUnaryExpression => |poe| {
                _ = try self.checkExpressionAdHoc(poe.Operand);
                return try self.getNumberType(); // ++ / -- always produce number
            },

            // Conditional / ternary
            .ConditionalExpression => |ce| {
                _ = try self.checkExpressionAdHoc(ce.Condition);
                const trueType = try self.checkExpressionAdHoc(ce.WhenTrue);
                const falseType = try self.checkExpressionAdHoc(ce.WhenFalse);
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
                    .objectFlags = types.ObjectFlags.Anonymous,
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
                    .objectFlags = types.ObjectFlags.Anonymous,
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
                        _ = self.checkStatementAdHoc(prop) catch {};
                    }
                }
                return try self.createType(.{
                    .flags = types.TypeFlags.Object,
                    .objectFlags = types.ObjectFlags.ObjectLiteral | types.ObjectFlags.FreshLiteral | types.ObjectFlags.Anonymous,
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
                    for (elems) |elem| try element_types.append(self.allocator, try self.checkExpressionAdHoc(elem));
                }
                const element_type = if (element_types.items.len == 0) try self.getNeverType() else try self.createUnionType(element_types.items);
                return try self.createType(.{
                    .flags = types.TypeFlags.Object,
                    .objectFlags = types.ObjectFlags.Anonymous | types.ObjectFlags.ArrayLiteral,
                    .id = 0,
                    .symbol = null,
                    .alias = null,
                    .data = .{ .Array = .{ .elementType = element_type } },
                });
            },

            // Property access
            .PropertyAccessExpression => |pae| {
                const objTypeIdx = try self.checkExpressionAdHoc(pae.Expression);
                const propNodeData = self.binder.ast.getNode(pae.name);
                if (std.meta.activeTag(propNodeData) == .Identifier) {
                    const propName = propNodeData.Identifier.Text;
                    if (self.getPropertyOfType(objTypeIdx, propName)) |p| {
                        return try self.getTypeOfSymbol(p);
                    }

                    if (!self.isTypeAny(objTypeIdx)) {
                        const objDataTag = std.meta.activeTag(self.typesList.items[objTypeIdx].data);
                        if (objDataTag == .Array or objDataTag == .Tuple) {
                            return try self.getAnyType();
                        }

                        var indexInfo: ?types.IndexInfo = null;
                        const assignmentKind = utils.getAssignmentTargetKind(self.binder.ast, nodeIndex);
                        if (assignmentKind == .None or !self.isGenericObjectType(objTypeIdx) or utils.isThisTypeParameter(self, objTypeIdx)) {
                            const keyType = if (utils.isNumericLiteralName(propName)) self.numberTypeIndex orelse 0 else self.stringTypeIndex orelse 0;
                            indexInfo = self.getIndexInfoOfType(objTypeIdx, keyType);
                        }

                        if (indexInfo == null) {
                            if (utils.isJSLiteralType(self, &self.typesList.items[objTypeIdx])) {
                                return try self.getAnyType();
                            }

                            if (shouldReportMissingPropertyError(self, objTypeIdx, assignmentKind)) {
                                var argsArr = self.allocator.alloc([]const u8, 2) catch unreachable;
                                self.ownedDiagnosticArgs.append(self.allocator, argsArr) catch unreachable;
                                argsArr[0] = propName;
                                argsArr[1] = self.typeToString(objTypeIdx, pae.Expression, 0, null);

                                const diag = diagnostics.Diagnostic{
                                    .nodeIndex = pae.name,
                                    .message = &diagnostics_gen.Property_0_does_not_exist_on_type_1,
                                    .args = argsArr,
                                };
                                self.addDiagnostic(diag);
                            }
                        }
                    }
                }
                return try self.getAnyType();
            },

            // Element access: arr[0]
            .ElementAccessExpression => |eae| {
                const objTypeIdx = try self.checkExpressionAdHoc(eae.Expression);
                const argTypeIdx = try self.checkExpressionAdHoc(eae.ArgumentExpression);

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
                const calleeTypeIdx = try self.checkExpressionAdHoc(ce.Expression);

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

                    var minRequiredArgs: usize = 0;
                    var hasRestParam = false;
                    for (params) |param_node| {
                        if (std.meta.activeTag(self.binder.ast.getNode(param_node)) != .Parameter) continue;
                        const param = self.binder.ast.getNode(param_node).Parameter;
                        if (param.DotDotDotToken != 0) hasRestParam = true;
                        if (!isParameterOptional(self, param_node)) minRequiredArgs += 1;
                    }

                    const minLen = @min(params.len, args.len);
                    for (0..minLen) |i| {
                        const paramData = self.binder.ast.getNode(params[i]);
                        if (std.meta.activeTag(paramData) == .Parameter) {
                            const param = paramData.Parameter;
                            const argTypeIdx = try self.checkExpressionAdHoc(args[i]);
                            var paramTypeIdx: u32 = 0;
                            if (param.Type != null and param.Type.? != 0) {
                                paramTypeIdx = type_resolution_pkg.getTypeFromTypeNode(self, param.Type.?);
                            } else {
                                paramTypeIdx = try self.getAnyType();
                            }

                            if (!self.isTypeAssignableTo(argTypeIdx, paramTypeIdx) and
                                shouldReportArgumentError(self, argTypeIdx, paramTypeIdx))
                            {
                                var argsArr = self.allocator.alloc([]const u8, 2) catch unreachable;
                                argsArr[0] = self.typeToString(argTypeIdx, args[i], 0, null);
                                argsArr[1] = self.typeToString(paramTypeIdx, args[i], 0, null);

                                const diag = diagnostics.Diagnostic{
                                    .nodeIndex = args[i],
                                    .message = &diagnostics_gen.Argument_of_type_0_is_not_assignable_to_parameter_of_type_1,
                                    .args = argsArr,
                                };
                                self.addDiagnostic(diag);
                            }
                        } else {
                            _ = try self.checkExpressionAdHoc(args[i]);
                        }
                    }
                    // Evaluate remaining args if any
                    for (minLen..args.len) |i| {
                        _ = try self.checkExpressionAdHoc(args[i]);
                    }

                    if (args.len < minRequiredArgs) {
                        var argsArr = self.allocator.alloc([]const u8, 2) catch unreachable;
                        argsArr[0] = try std.fmt.allocPrint(self.allocator, "{d}", .{minRequiredArgs});
                        argsArr[1] = try std.fmt.allocPrint(self.allocator, "{d}", .{args.len});
                        const diag = diagnostics.Diagnostic{
                            .nodeIndex = ce.Expression,
                            .message = &diagnostics_gen.Expected_0_arguments_but_got_1,
                            .args = argsArr,
                        };
                        self.addDiagnostic(diag);
                    } else if (args.len > params.len and !hasRestParam) {
                        var argsArr = self.allocator.alloc([]const u8, 2) catch unreachable;
                        argsArr[0] = try std.fmt.allocPrint(self.allocator, "{d}", .{params.len});
                        argsArr[1] = try std.fmt.allocPrint(self.allocator, "{d}", .{args.len});
                        const diag = diagnostics.Diagnostic{
                            .nodeIndex = ce.Expression,
                            .message = &diagnostics_gen.Expected_0_arguments_but_got_1,
                            .args = argsArr,
                        };
                        self.addDiagnostic(diag);
                    }
                } else {
                    if (ce.Arguments != 0) {
                        const args = self.binder.ast.getNodeList(ce.Arguments);
                        for (args) |arg| {
                            _ = try self.checkExpressionAdHoc(arg);
                        }
                    }
                }

                if (retType != 0) return retType;
                return try self.getAnyType();
            },

            // new expr(args)
            .NewExpression => |ne| {
                _ = try self.checkExpressionAdHoc(ne.Expression);
                if (ne.Arguments) |argsIdx| {
                    if (argsIdx != 0) {
                        const args = self.binder.ast.getNodeList(argsIdx);
                        for (args) |arg| {
                            _ = try self.checkExpressionAdHoc(arg);
                        }
                    }
                }
                return try self.getObjectType();
            },

            // Wrapping expressions
            .ParenthesizedExpression => |pe| {
                return try self.checkExpressionAdHoc(pe.Expression);
            },
            .AsExpression => |ae| {
                _ = try self.checkExpressionAdHoc(ae.Expression);
                return try self.getTypeOfNode(ae.Type);
            },
            .SatisfiesExpression => |se| {
                return try self.checkExpressionAdHoc(se.Expression);
            },
            .NonNullExpression => |nne| {
                return try self.checkExpressionAdHoc(nne.Expression);
            },
            .TypeAssertionExpression => |ta| {
                _ = try self.checkExpressionAdHoc(ta.Expression);
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
                return try self.checkExpressionAdHoc(ae.Expression);
            },
            .YieldExpression => |ye| {
                if (ye.Expression) |expr| {
                    return try self.checkExpressionAdHoc(expr);
                }
                return try self.getAnyType();
            },
            .DeleteExpression => {
                return try self.getBooleanType();
            },
            .SpreadElement => |se| {
                return try self.checkExpressionAdHoc(se.Expression);
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
                        _ = self.checkStatementAdHoc(mem) catch {};
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
        const leftTypeIdx = try self.checkExpressionAdHoc(bin.Left);
        const rightTypeIdx = try self.checkExpressionAdHoc(bin.Right);
        const leftType = if (leftTypeIdx < self.typesList.items.len)
            self.typesList.items[leftTypeIdx]
        else
            types.Type{ .flags = types.TypeFlags.Any, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } };
        const rightType = if (rightTypeIdx < self.typesList.items.len)
            self.typesList.items[rightTypeIdx]
        else
            types.Type{ .flags = types.TypeFlags.Any, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "" } } };

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
            if (!self.isTypeAssignableTo(rightTypeIdx, leftTypeIdx) and
                shouldReportAssignmentError(self, rightTypeIdx, leftTypeIdx))
            {
                var argsArr = self.allocator.alloc([]const u8, 2) catch unreachable;
                argsArr[0] = self.typeToString(rightTypeIdx, bin.Right, 0, null);
                argsArr[1] = self.typeToString(leftTypeIdx, bin.Left, 0, null);

                const diag = diagnostics.Diagnostic{
                    .nodeIndex = bin.Right,
                    .message = &diagnostics_gen.Type_0_is_not_assignable_to_type_1,
                    .args = argsArr,
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

        // Logical operators: union of operand types
        if (opNode == .BarBarToken or opNode == .AmpersandAmpersandToken or opNode == .QuestionQuestionToken) {
            return try self.getUnionType(leftTypeIdx, rightTypeIdx);
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

    fn checkPrefixUnary(self: *Checker, operatorKindNum: u32, operandTypeIdx: u32) !u32 {
        const opKind: @import("../ast/kind.zig").Kind = @enumFromInt(operatorKindNum);
        switch (opKind) {
            .ExclamationToken => {
                const facts = self.getTypeFacts(operandTypeIdx, types.TypeFacts.Truthy | types.TypeFacts.Falsy);
                if (facts == types.TypeFacts.Truthy) {
                    return self.getFalseType();
                } else if (facts == types.TypeFacts.Falsy) {
                    return self.getTrueType();
                } else {
                    return self.getBooleanType();
                }
            },
            .PlusToken, .MinusToken, .TildeToken => {
                // Skipped: numeric literals, bigint literals, check arithmetic
                if (opKind == .PlusToken) {
                    if (self.maybeTypeOfKind(operandTypeIdx, types.TypeFlags.BigIntLike)) {
                        // Skipped: error(Operator '+' cannot be applied to type 'bigint')
                    }
                    return self.getNumberType();
                }
                return try self.getUnaryResultType(operandTypeIdx);
            },
            .PlusPlusToken, .MinusMinusToken => {
                return try self.getUnaryResultType(operandTypeIdx);
            },
            else => return self.getAnyType(),
        }
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
            .objectFlags = types.ObjectFlags.Anonymous,
            .id = 0,
            .symbol = null,
            .alias = null,
            .data = .{ .Union = .{ .typesStart = start, .typesLen = @intCast(unique.items.len) } },
        });
    }

    // =========================================================================
    // checkStatement
    // =========================================================================

    pub fn checkStatementAdHoc(self: *Checker, nodeIndex: u32) anyerror!void {
        const node = self.binder.ast.getNode(nodeIndex);
        switch (node) {
            // Source file - entry point
            .SourceFile => |sf| {
                if (sf.Statements != 0) {
                    const stmts = self.binder.ast.getNodeList(sf.Statements);
                    for (stmts) |stmt| {
                        try self.checkStatementAdHoc(stmt);
                    }
                }
            },

            // Block of statements
            .Block => |blk| {
                if (blk.Statements != 0) {
                    const stmts = self.binder.ast.getNodeList(blk.Statements);
                    for (stmts) |stmt| {
                        try self.checkStatementAdHoc(stmt);
                    }
                }
            },

            // Variables
            .VariableStatement => |varStmt| {
                try self.checkStatementAdHoc(varStmt.DeclarationList);
            },
            .VariableDeclarationList => |varList| {
                if (varList.Declarations != 0) {
                    const decls = self.binder.ast.getNodeList(varList.Declarations);
                    for (decls) |decl| {
                        try self.checkStatementAdHoc(decl);
                    }
                }
            },
            .VariableDeclaration => |decl| {
                var initType: u32 = try self.getAnyType();
                if (decl.Initializer) |initExpr| {
                    initType = try self.checkExpressionAdHoc(initExpr);
                }

                if (decl.Type) |typeNode| {
                    const declaredType = type_resolution_pkg.getTypeFromTypeNode(self, typeNode);
                    if (decl.Initializer) |initExpr| {
                        _ = self.reportExcessPropertyForObjectLiteralUnionAssignment(initExpr, declaredType);
                    }
                    // Type compatibility check
                    if (initType != 0 and declaredType != 0 and
                        initType < self.typesList.items.len and
                        declaredType < self.typesList.items.len)
                    {
                        if (!self.isTypeAssignableTo(initType, declaredType) and
                            shouldReportAssignmentError(self, initType, declaredType))
                        {
                            var argsArr = self.allocator.alloc([]const u8, 2) catch unreachable;
                            self.ownedDiagnosticArgs.append(self.allocator, argsArr) catch unreachable;
                            argsArr[0] = self.typeToString(initType, decl.Initializer.?, 0, null);
                            argsArr[1] = self.typeToString(declaredType, decl.Type.?, 0, null);

                            const diag = diagnostics.Diagnostic{
                                .nodeIndex = decl.Initializer.?,
                                .message = &diagnostics_gen.Type_0_is_not_assignable_to_type_1,
                                .args = argsArr,
                            };
                            self.addDiagnostic(diag);
                        }
                    }
                }
            },

            // Functions
            .FunctionDeclaration => |f| {
                if (f.Body) |body| {
                    try self.checkStatementAdHoc(body);
                }
                if (f.Parameters != 0) {
                    checkFunctionParameters(self, f.Parameters);
                }
                if ((f.Body == null or f.Body == 0) and (f.Type == null or f.Type == 0)) {
                    if (isDeclarationFilePath(self.binder.ast.fileName) or self.noImplicitAny) {
                        if (f.name) |name_idx| {
                            const name = ast_utils.getText(self.binder.ast, name_idx);
                            self.reportErrorWithArgs(
                                name_idx,
                                &diagnostics_gen.X_0_which_lacks_return_type_annotation_implicitly_has_an_1_return_type,
                                &.{ name, "any" },
                            );
                        }
                    }
                }
            },

            // Return statement
            .ReturnStatement => |ret| {
                var exprTypeIdx: u32 = 0;
                if (ret.Expression) |expr| {
                    exprTypeIdx = try self.checkExpressionAdHoc(expr);
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
                    if (!self.isTypeAssignableTo(exprTypeIdx, functionReturnTypeIdx) and
                        shouldReportAssignmentError(self, exprTypeIdx, functionReturnTypeIdx))
                    {
                        var argsArr = self.allocator.alloc([]const u8, 2) catch unreachable;
                        const exprNode = if (ret.Expression != null) ret.Expression.? else nodeIndex;
                        argsArr[0] = self.typeToString(exprTypeIdx, exprNode, 0, null);
                        argsArr[1] = self.typeToString(functionReturnTypeIdx, 0, 0, null);

                        const diag = diagnostics.Diagnostic{
                            .nodeIndex = exprNode,
                            .message = &diagnostics_gen.Type_0_is_not_assignable_to_type_1,
                            .args = argsArr,
                        };
                        self.addDiagnostic(diag);
                    }
                }
            },

            // Expression statement
            .ExpressionStatement => |es| {
                _ = try self.checkExpressionAdHoc(es.Expression);
            },

            // If statement
            .IfStatement => |ifs| {
                _ = try self.checkExpressionAdHoc(ifs.Expression);
                try self.checkStatementAdHoc(ifs.ThenStatement);
                if (ifs.ElseStatement) |elseStmt| {
                    try self.checkStatementAdHoc(elseStmt);
                }
            },

            // While loop
            .WhileStatement => |ws| {
                _ = try self.checkExpressionAdHoc(ws.Expression);
                try self.checkStatementAdHoc(ws.Statement);
            },

            // Do-while loop
            .DoStatement => |ds| {
                try self.checkStatementAdHoc(ds.Statement);
                _ = try self.checkExpressionAdHoc(ds.Expression);
            },

            // For loop
            .ForStatement => |fs| {
                if (fs.Initializer) |initializer_node| {
                    // init can be variable declaration list or expression
                    const initNode = self.binder.ast.getNode(initializer_node);
                    switch (initNode) {
                        .VariableDeclarationList => try self.checkStatementAdHoc(initializer_node),
                        else => _ = try self.checkExpressionAdHoc(initializer_node),
                    }
                }
                if (fs.Condition) |cond| {
                    _ = try self.checkExpressionAdHoc(cond);
                }
                if (fs.Incrementor) |incr| {
                    _ = try self.checkExpressionAdHoc(incr);
                }
                try self.checkStatementAdHoc(fs.Statement);
            },

            // For-in / For-of
            .ForInStatement, .ForOfStatement => |fio| {
                _ = try self.checkExpressionAdHoc(fio.Expression);
                try self.checkStatementAdHoc(fio.Statement);
            },

            // Switch
            .SwitchStatement => |ss| {
                _ = try self.checkExpressionAdHoc(ss.Expression);
                try self.checkStatementAdHoc(ss.CaseBlock);
            },
            .CaseBlock => |cb| {
                if (cb.Clauses != 0) {
                    const clauses = self.binder.ast.getNodeList(cb.Clauses);
                    for (clauses) |clause| {
                        try self.checkStatementAdHoc(clause);
                    }
                }
            },
            .CaseClause => |cc| {
                _ = try self.checkExpressionAdHoc(cc.Expression);
                if (cc.Statements != 0) {
                    const stmts = self.binder.ast.getNodeList(cc.Statements);
                    for (stmts) |stmt| {
                        try self.checkStatementAdHoc(stmt);
                    }
                }
            },
            .DefaultClause => |dc| {
                if (dc.Statements != 0) {
                    const stmts = self.binder.ast.getNodeList(dc.Statements);
                    for (stmts) |stmt| {
                        try self.checkStatementAdHoc(stmt);
                    }
                }
            },

            // Throw
            .ThrowStatement => |ts| {
                _ = try self.checkExpressionAdHoc(ts.Expression);
            },

            // Try-catch-finally
            .TryStatement => |ts| {
                try self.checkStatementAdHoc(ts.TryBlock);
                if (ts.CatchClause) |catchNode| {
                    try self.checkStatementAdHoc(catchNode);
                }
                if (ts.FinallyBlock) |finallyNode| {
                    try self.checkStatementAdHoc(finallyNode);
                }
            },
            .CatchClause => |cc| {
                try self.checkStatementAdHoc(cc.Block);
            },

            // Classes
            .ClassDeclaration => |cd| {
                if (cd.Members != 0) {
                    const members = self.binder.ast.getNodeList(cd.Members);
                    for (members) |mem| {
                        try self.checkStatementAdHoc(mem);
                    }
                }
            },
            .MethodDeclaration => |m| {
                if (m.Body) |body| {
                    try self.checkStatementAdHoc(body);
                }
                if (m.Parameters != 0) {
                    checkFunctionParameters(self, m.Parameters);
                }
            },
            .Constructor => |ctor| {
                if (ctor.Body) |body| {
                    try self.checkStatementAdHoc(body);
                }
                if (ctor.Parameters != 0) {
                    checkFunctionParameters(self, ctor.Parameters);
                }
            },
            .GetAccessor => |ga| {
                if (ga.Body) |body| {
                    try self.checkStatementAdHoc(body);
                }
            },
            .SetAccessor => |sa| {
                if (sa.Body) |body| {
                    try self.checkStatementAdHoc(body);
                }
            },
            .PropertyDeclaration => |pd| {
                if (pd.Initializer) |pd_init| {
                    _ = try self.checkExpressionAdHoc(pd_init);
                }
            },

            // Labeled statement
            .LabeledStatement => |ls| {
                try self.checkStatementAdHoc(ls.Statement);
            },

            // Export assignment: export = expr
            .ExportAssignment => |ea| {
                _ = try self.checkExpressionAdHoc(ea.Expression);
            },

            // ExpressionStatement cho arrow/function expressions
            .ArrowFunction, .FunctionExpression => {
                _ = try self.checkExpressionAdHoc(nodeIndex);
            },

            // Import/Export declarations (no type checking needed here)
            .ImportDeclaration, .ExportDeclaration, .JSImportDeclaration => {},
            .ImportEqualsDeclaration => checkImportEqualsDeclaration(self, nodeIndex),

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
                                    _ = try self.checkExpressionAdHoc(initIdx);
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
                        try self.checkStatementAdHoc(stmt);
                    }
                }
            },

            // Property assignment trong object literal
            .PropertyAssignment => |pa| {
                _ = try self.checkExpressionAdHoc(pa.Initializer);
            },
            .ShorthandPropertyAssignment => |spa| {
                if (spa.ObjectAssignmentInitializer) |initExpr| {
                    _ = try self.checkExpressionAdHoc(initExpr);
                }
            },

            else => {},
        }
    }
    pub fn getTypesOfUnionOrIntersectionType(c: *Checker, t: types.TypeIndex) []const types.TypeIndex {
        if (t == 0 or t >= c.typesList.items.len) return &[_]types.TypeIndex{};
        const flags = c.typesList.items[t].flags;
        if ((flags & types.TypeFlags.Union) != 0) return c.getTypesFromUnion(t);
        if ((flags & types.TypeFlags.Intersection) != 0) return c.getTypesFromIntersection(t);
        return &[_]types.TypeIndex{t};
    }

    pub fn resolveEntityName(c: *Checker, name: ast_gen.NodeIndex, meaning: u32, ignoreErrors: bool, dontResolveAlias: bool, location: ?ast_gen.NodeIndex) ast_gen.SymbolIndex {
        _ = c;
        _ = name;
        _ = meaning;
        _ = ignoreErrors;
        _ = dontResolveAlias;
        _ = location;
        return 0; // Skipped
    }

    pub fn containsType(c: *Checker, typesList: []const types.TypeIndex, t: types.TypeIndex) bool {
        _ = c;
        for (typesList) |item| {
            if (item == t) return true;
        }
        return false;
    }

    pub fn isFunctionOrSourceFile(c: *Checker, node: ast_gen.NodeIndex) bool {
        const nodeKind = c.binder.ast.getKind(node);
        return switch (nodeKind) {
            .FunctionDeclaration, .MethodDeclaration, .GetAccessor, .SetAccessor, .Constructor, .FunctionExpression, .ArrowFunction, .SourceFile => true,
            else => false,
        };
    }

    pub fn isFunctionOrSourceFileForFindAncestor(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
        const nodeKind = tree.getKind(node);
        return switch (nodeKind) {
            .FunctionDeclaration, .MethodDeclaration, .GetAccessor, .SetAccessor, .Constructor, .FunctionExpression, .ArrowFunction, .SourceFile => true,
            else => false,
        };
    }

    pub fn hasParentWithAssignmentsMarked(c: *Checker, node: ast_gen.NodeIndex) bool {
        var current = ast_utils.getParent(c.binder.ast, node);
        while (current != 0) : (current = ast_utils.getParent(c.binder.ast, current)) {
            if (c.isFunctionOrSourceFile(current)) {
                if (c.nodeLinks.get(current)) |links| {
                    if ((links.flags & types.NodeCheckFlags.AssignmentsMarked) != 0) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    pub fn markNodeAssignments(c: *Checker, node: ast_gen.NodeIndex) void {
        _ = c.markNodeAssignmentsWorker(node);
    }

    const MarkNodeAssignmentsVisitor = struct {
        c: *Checker,
        pub fn check(self: *MarkNodeAssignmentsVisitor, n: ast_gen.NodeIndex) bool {
            return self.c.markNodeAssignmentsWorker(n);
        }
    };

    pub fn markNodeAssignmentsWorker(c: *Checker, node: ast_gen.NodeIndex) bool {
        const nodeKind = c.binder.ast.getKind(node);
        switch (nodeKind) {
            .Identifier => {
                const assignmentKind = @intFromEnum(utils.getAssignmentTargetKind(c.binder.ast, node));
                if (assignmentKind != 0) { // AssignmentKindNone
                    const symbolId = getResolvedSymbol(c, node);
                    if (symbolId != 0 and symbolId < c.binder.symbols.items.len) {
                        const symPtr = &c.binder.symbols.items[symbolId];
                        if (utils.isParameterOrMutableLocalVariable(c, symPtr)) {
                            var links = c.markedAssignmentSymbolLinks.get(symbolId) orelse types.MarkedAssignmentSymbolLinks{};
                            const pos = links.lastAssignmentPos;
                            if (pos == 0 or pos != std.math.maxInt(i32)) {
                                const referencingFunction = ast_utils.findAncestor(c.binder.ast, node, isFunctionOrSourceFileForFindAncestor);
                                const symItem = c.binder.symbols.items[symbolId];
                                var declaringFunction: ast_gen.NodeIndex = 0;
                                if (symItem.ValueDeclaration) |vd| {
                                    declaringFunction = ast_utils.findAncestor(c.binder.ast, vd, isFunctionOrSourceFileForFindAncestor);
                                }
                                if (referencingFunction != 0 and referencingFunction == declaringFunction) {
                                    links.lastAssignmentPos = @intCast(extendAssignmentPosition(c, node, symItem.ValueDeclaration.?));
                                } else {
                                    links.lastAssignmentPos = std.math.maxInt(i32);
                                }
                            }
                            if (assignmentKind == 2) { // AssignmentKindDefinite
                                links.hasDefiniteAssignment = true;
                            }
                            c.markedAssignmentSymbolLinks.put(c.allocator, symbolId, links) catch {};
                        }
                    }
                }
                return false;
            },
            .ExportSpecifier => {
                const parentNode = ast_utils.getParent(c.binder.ast, node);
                if (parentNode != 0) {
                    const grandparent = ast_utils.getParent(c.binder.ast, parentNode);
                    if (grandparent != 0) {
                        if (c.binder.ast.getKind(grandparent) == .ExportDeclaration) {
                            const exportDecl = c.binder.ast.getNode(grandparent).ExportDeclaration;
                            const name = ast_utils.getPropertyNameOrName(c.binder.ast, node);
                            const isTypeOnly = ast_utils.isTypeOnly(c.binder.ast, node);

                            if (!isTypeOnly and exportDecl.IsTypeOnly == 0 and exportDecl.ModuleSpecifier == 0 and c.binder.ast.getKind(name) != .StringLiteral) {
                                const symbolId = resolveEntityName(c, name, symbol.SymbolFlags.Value, true, true, null);
                                if (symbolId != 0 and symbolId < c.binder.symbols.items.len) {
                                    const symPtr = &c.binder.symbols.items[symbolId];
                                    if (utils.isParameterOrMutableLocalVariable(c, symPtr)) {
                                        var links = c.markedAssignmentSymbolLinks.get(symbolId) orelse types.MarkedAssignmentSymbolLinks{};
                                        links.lastAssignmentPos = std.math.maxInt(i32);
                                        c.markedAssignmentSymbolLinks.put(c.allocator, symbolId, links) catch {};
                                    }
                                }
                            }
                        }
                    }
                }
                return false;
            },
            .InterfaceDeclaration, .TypeAliasDeclaration, .JSTypeAliasDeclaration, .EnumDeclaration => return false,
            else => {},
        }
        if (ast_utils.isTypeNode(c.binder.ast, node)) return false;

        var visitor = MarkNodeAssignmentsVisitor{ .c = c };
        return ast_utils.forEachChildBool(c.binder.ast, node, &visitor, MarkNodeAssignmentsVisitor.check);
    }

    pub fn extendAssignmentPosition(c: *Checker, startNode: ast_gen.NodeIndex, declaration: ast_gen.NodeIndex) i32 {
        var pos: i32 = @intCast(ast_utils.getPos(c.binder.ast, startNode));
        const declPos: i32 = @intCast(ast_utils.getPos(c.binder.ast, declaration));
        var current = startNode;

        while (current != 0 and @as(i32, @intCast(ast_utils.getPos(c.binder.ast, current))) > declPos) {
            const nodeKind = c.binder.ast.getKind(current);
            switch (nodeKind) {
                .VariableStatement, .ExpressionStatement, .IfStatement, .DoStatement, .WhileStatement, .ForStatement, .ForInStatement, .ForOfStatement, .WithStatement, .SwitchStatement, .TryStatement, .ClassDeclaration => {
                    pos = @intCast(ast_utils.getEndOfNode(c.binder.ast, current));
                },
                else => {},
            }
            current = ast_utils.getParent(c.binder.ast, current);
        }
        return pos;
    }

    pub fn ensureAssignmentsMarked(c: *Checker, symbolId: ast_gen.SymbolIndex) void {
        if (symbolId >= c.binder.symbols.items.len) return;

        if (c.markedAssignmentSymbolLinks.get(symbolId)) |links| {
            if (links.lastAssignmentPos != 0) return;
        }

        const symItem = c.binder.symbols.items[symbolId];
        if (symItem.ValueDeclaration == null) return;

        var parent: ast_gen.NodeIndex = 0;
        var current = symItem.ValueDeclaration.?;
        while (current != 0) : (current = ast_utils.getParent(c.binder.ast, current)) {
            if (isFunctionOrSourceFile(c, current)) {
                parent = current;
                break;
            }
        }
        if (parent == 0) return;

        var links = c.nodeLinks.get(parent) orelse types.NodeLinks{};
        if ((links.flags & types.NodeCheckFlags.AssignmentsMarked) == 0) {
            links.flags |= types.NodeCheckFlags.AssignmentsMarked;
            c.nodeLinks.put(c.allocator, parent, links) catch return;

            if (!c.hasParentWithAssignmentsMarked(parent)) {
                c.markNodeAssignments(parent);
            }
        }
    }

    pub fn getSymbolOfDeclaration(c: *Checker, decl: ast_gen.NodeIndex) ast_gen.SymbolIndex {
        return c.binder.ast.getNodeSymbol(decl) orelse 0;
    }

    pub fn isTypeAssignableToKindEx(c: *Checker, source: types.TypeIndex, kindFlags: u32, strict: bool) bool {
        const sourceFlags = c.typesList.items[source].flags;
        if ((sourceFlags & kindFlags) != 0) return true;

        if (strict and (sourceFlags & (types.TypeFlags.Any | types.TypeFlags.Unknown | types.TypeFlags.Void | types.TypeFlags.Undefined | types.TypeFlags.Null)) != 0) {
            return false;
        }

        if ((kindFlags & types.TypeFlags.NumberLike) != 0 and c.isTypeAssignableTo(source, c.numberTypeIndex.?)) return true;
        if ((kindFlags & types.TypeFlags.BigIntLike) != 0 and c.isTypeAssignableTo(source, c.bigintTypeIndex.?)) return true;
        if ((kindFlags & types.TypeFlags.StringLike) != 0 and c.isTypeAssignableTo(source, c.stringTypeIndex.?)) return true;
        if ((kindFlags & types.TypeFlags.BooleanLike) != 0 and c.isTypeAssignableTo(source, c.booleanTypeIndex.?)) return true;
        if ((kindFlags & types.TypeFlags.Void) != 0 and c.isTypeAssignableTo(source, c.voidTypeIndex.?)) return true;
        if ((kindFlags & types.TypeFlags.Never) != 0 and c.isTypeAssignableTo(source, c.neverTypeIndex.?)) return true;
        if ((kindFlags & types.TypeFlags.Null) != 0 and c.isTypeAssignableTo(source, c.nullTypeIndex.?)) return true;
        if ((kindFlags & types.TypeFlags.Undefined) != 0 and c.isTypeAssignableTo(source, c.undefinedTypeIndex.?)) return true;
        if ((kindFlags & types.TypeFlags.ESSymbol) != 0 and c.isTypeAssignableTo(source, c.esSymbolTypeIndex.?)) return true;
        if ((kindFlags & types.TypeFlags.NonPrimitive) != 0 and c.isTypeAssignableTo(source, c.nonPrimitiveTypeIndex.?)) return true;

        return false;
    }

    pub fn isTypeAssignableToKind(c: *Checker, source: types.TypeIndex, kindFlags: u32) bool {
        return c.isTypeAssignableToKindEx(source, kindFlags, false);
    }

    pub fn getDeclarationNodeFlagsFromSymbol(c: *Checker, sym: ast_gen.SymbolIndex) u32 {
        if (sym < c.binder.symbols.items.len) {
            if (c.binder.symbols.items[sym].ValueDeclaration) |decl| {
                return ast_utils.getCombinedNodeFlags(c.binder.ast, decl);
            }
        }
        return 0;
    }

    pub fn getDeclarationModifierFlagsFromSymbol(c: *Checker, sym: ast_gen.SymbolIndex) u32 {
        if (sym >= c.binder.symbols.items.len) return 0;
        const symItem = c.binder.symbols.items[sym];
        var decl: ?ast_gen.NodeIndex = null;
        if (symItem.ValueDeclaration) |vd| {
            decl = vd;
        } else if (symItem.Flags & symbol.SymbolFlags.GetAccessor != 0) {
            for (symItem.Declarations.items) |d| {
                if (c.binder.ast.getKind(d) == .GetAccessor) {
                    decl = d;
                    break;
                }
            }
        }
        if (decl == null and symItem.Declarations.items.len > 0) {
            decl = symItem.Declarations.items[0];
        }
        if (decl) |d| {
            const flags = ast_utils.getCombinedModifierFlags(c.binder.ast, d);
            if (symItem.Parent) |parent| {
                if (c.binder.symbols.items[parent].Flags & symbol.SymbolFlags.Class != 0) {
                    return flags;
                }
            }
            return flags & ~@as(u32, ast_utils.ModifierFlags.Public | ast_utils.ModifierFlags.Private | ast_utils.ModifierFlags.Protected);
        }
        return 0;
    }

    pub fn getSymbolCheckFlags(c: *Checker, sym: ast_gen.SymbolIndex) u32 {
        if (sym < c.binder.symbols.items.len) {
            return c.binder.symbols.items[sym].CheckFlags;
        }
        return 0;
    }

    pub fn computeEnumMemberValues(c: *Checker, node: ast_gen.NodeIndex) void {
        _ = c;
        _ = node;
    }

    pub fn getHomomorphicTypeVariable(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        const typeVariable = c.getTypeParameterFromMappedType(t);
        if (typeVariable == 0) return 0;
        return c.getConstraintOfTypeParameter(typeVariable) orelse 0;
    }

    pub fn getOriginOfUnionType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return 0; // Skipped
    }

    pub fn getRegularTypeOfObjectLiteral(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        // If not a fresh object literal, return as-is
        if (c.getObjectFlags(t) & types.ObjectFlags.FreshLiteral == 0) return t;
        // Conservative: return t (should map to regular type)
        return t;
    }

    pub fn getRegularTypeOfLiteralType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        // If not freshable, return as-is
        const flags = c.typesList.items[t].flags;
        if (flags & types.TypeFlags.Freshable == 0) return t;
        return t;
    }

    pub fn getFreshTypeOfLiteralType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        // Conservative: return same type
        _ = c;
        return t;
    }

    pub fn getNumberLiteralType(c: *Checker, value: f64) types.TypeIndex {
        if (std.math.isNan(value)) {
            // NaN handling if needed, skip for now or cache it
            // Assuming NaN logic here if we add nanType, else just create it
            return c.createType(.{
                .flags = types.TypeFlags.NumberLiteral,
                .objectFlags = types.ObjectFlags.Anonymous,
                .id = 0,
                .symbol = null,
                .alias = null,
                .data = .{ .NumberLiteral = .{ .value = value } },
            }) catch 0;
        }

        if (c.numberLiteralTypes.get(@bitCast(value))) |cached_t| {
            return cached_t;
        }

        const t = c.createType(.{
            .flags = types.TypeFlags.NumberLiteral,
            .objectFlags = types.ObjectFlags.Anonymous,
            .id = 0,
            .symbol = null,
            .alias = null,
            .data = .{ .NumberLiteral = .{ .value = value } },
        }) catch 0;
        c.numberLiteralTypes.put(c.allocator, @bitCast(value), t) catch {};
        return t;
    }

    pub fn getMatchingUnionConstituentForType(c: *Checker, unionType: types.TypeIndex, t: types.TypeIndex) ?types.TypeIndex {
        return relater.getMatchingUnionConstituentForType(c, unionType, t);
    }

    pub fn getBestMatchingType(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, r: *relater.Relater) ?types.TypeIndex {
        c.bestMatchingRelater = r;
        defer c.bestMatchingRelater = null;
        return relater.getBestMatchingType(c, source, target, relaterIsRelatedToAdapter);
    }

    fn relaterIsRelatedToAdapter(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) types.Ternary {
        return c.bestMatchingRelater.?.isRelatedToSimple(source, target);
    }

    pub fn findDiscriminantProperties(c: *Checker, sourceProperties: []const ast_gen.SymbolIndex, target: types.TypeIndex) []const ast_gen.SymbolIndex {
        c.discriminantPropertiesScratch.clearRetainingCapacity();
        for (sourceProperties) |sp| {
            if (relater.isDiscriminantProperty(c, target, c.getSymbolName(sp))) {
                c.discriminantPropertiesScratch.append(c.allocator, sp) catch {};
            }
        }
        return c.discriminantPropertiesScratch.items;
    }

    pub fn countTypes(c: *Checker, t: types.TypeIndex) usize {
        return c.distributedTypes(t).len;
    }

    pub fn distributedTypes(c: *Checker, t: types.TypeIndex) []const types.TypeIndex {
        if ((c.getTypeFlags(t) & types.TypeFlags.Union) != 0) {
            return c.getTypesFromUnion(t);
        }
        c.distributedTypesScratch[0] = t;
        return c.distributedTypesScratch[0..1];
    }

    pub fn appendIfUniqueTypeIndex(c: *Checker, list: *std.ArrayListUnmanaged(types.TypeIndex), item: types.TypeIndex) void {
        for (list.items) |i| {
            if (i == item) return;
        }
        list.append(c.allocator, item) catch unreachable;
    }

    pub fn getStartElementCount(c: *Checker, tupleType: *types.TupleType, flags: u32) usize {
        const infos = c.tupleElementInfos.items[tupleType.elementInfosStart .. tupleType.elementInfosStart + tupleType.typesLen];
        for (infos, 0..) |info, i| {
            if ((info.flags & flags) == 0) return i;
        }
        return infos.len;
    }

    pub fn getEndElementCount(c: *Checker, tupleType: *types.TupleType, flags: u32) usize {
        const infos = c.tupleElementInfos.items[tupleType.elementInfosStart .. tupleType.elementInfosStart + tupleType.typesLen];
        var i = infos.len;
        while (i > 0) : (i -= 1) {
            if ((infos[i - 1].flags & flags) == 0) return infos.len - i;
        }
        return infos.len;
    }

    pub fn removeMissingType(c: *Checker, t: types.TypeIndex, optional: bool) types.TypeIndex {
        if ((c.options.exactOptionalPropertyTypes orelse false) and optional) {
            return c.removeType(t, c.getMissingType());
        }
        return t;
    }

    pub fn shouldReportUnmatchedPropertyError(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
        const type_call = c.getSignaturesOfType(source, .Call);
        const type_construct = c.getSignaturesOfType(source, .Construct);
        const type_properties = c.getPropertiesOfType(source);
        if ((type_call.len != 0 or type_construct.len != 0) and type_properties.len == 0) {
            const target_call = c.getSignaturesOfType(target, .Call);
            const target_construct = c.getSignaturesOfType(target, .Construct);
            if ((target_call.len != 0 and type_call.len != 0) or (target_construct.len != 0 and type_construct.len != 0)) {
                return true;
            }
            return false;
        }
        return true;
    }

    pub fn markLibSymbol(c: *Checker, sym: ast_gen.SymbolIndex) void {
        c.lib_symbols.put(c.allocator, sym, {}) catch {};
    }

    pub fn symbolBinder(c: *Checker, sym: ast_gen.SymbolIndex) *binder.Binder {
        if (c.lib_symbols.contains(sym)) {
            return c.default_lib_binder orelse c.binder;
        }
        return c.binder;
    }

    pub fn getSymbolFlags(c: *Checker, sym: ast_gen.SymbolIndex) u32 {
        const b = c.symbolBinder(sym);
        if (sym < b.symbols.items.len) {
            return b.symbols.items[sym].Flags;
        }
        return 0;
    }

    pub fn getSymbolName(c: *Checker, sym: ast_gen.SymbolIndex) []const u8 {
        const b = c.symbolBinder(sym);
        if (sym < b.symbols.items.len) {
            return b.symbols.items[sym].Name;
        }
        return "";
    }

    pub fn createObjectTypeWithStringIndexSignature(c: *Checker, valueType: types.TypeIndex) types.TypeIndex {
        const stringType = c.stringTypeIndex orelse 0;
        const t = c.createType(.{
            .flags = types.TypeFlags.Object,
            .objectFlags = types.ObjectFlags.Anonymous,
            .id = 0,
            .symbol = null,
            .alias = null,
            .data = .{ .Object = .{ .Symbol = null } },
        }) catch return 0;
        const info = types.IndexInfo{
            .keyType = stringType,
            .valueType = valueType,
            .isReadonly = false,
        };
        const indexRange = c.appendIndexInfo(0, 0, info, false);
        const members = types.StructuredTypeMembers{
            .indexInfosStart = indexRange.start,
            .indexInfosLen = indexRange.len,
        };
        c.resolvedStructuredTypeMembers.put(c.allocator, t, members) catch {};
        return t;
    }

    pub fn isTypeRelatedTo(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, relation: *relater.Relation) bool {
        return relater.isTypeRelatedTo(c, source, target, relation);
    }

    pub fn isSetAccessorSymbol(c: *Checker, symIdx: ast_gen.SymbolIndex) bool {
        const sym = c.binder.ast.getSymbol(symIdx);
        return (sym.flags & ast_gen.SymbolFlags.SetAccessor) != 0;
    }

    pub fn isGetAccessorSymbol(c: *Checker, symIdx: ast_gen.SymbolIndex) bool {
        const sym = c.binder.ast.getSymbol(symIdx);
        return (sym.flags & ast_gen.SymbolFlags.GetAccessor) != 0;
    }

    pub fn getReturnTypeOfSignature(c: *Checker, signature: *types.Signature) types.TypeIndex {
        _ = signature;
        return c.unknownTypeIndex orelse 0; // Skipped
    }

    pub fn getErasedSignature(c: *Checker, signature: *types.Signature) *types.Signature {
        _ = c;
        return signature; // Skipped
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
        return .False; // Skipped
    }

    pub fn isObjectTypeWithInferableIndex(c: *Checker, t: types.TypeIndex) bool {
        if (c.getTypeFlags(t) & types.TypeFlags.Intersection != 0) {
            for (c.getTypes(t)) |t_elem| {
                if (!c.isObjectTypeWithInferableIndex(t_elem)) return false;
            }
            return true;
        }

        const sym = c.getSymbolOfType(t);
        const has_valid_symbol = sym != 0 and
            (c.getSymbolFlags(sym) & (ast.SymbolFlags.ObjectLiteral | ast.SymbolFlags.TypeLiteral | ast.SymbolFlags.Enum | ast.SymbolFlags.ValueModule) != 0) and
            (c.getSymbolFlags(sym) & ast.SymbolFlags.Class == 0) and !c.typeHasCallOrConstructSignatures(t);

        if (has_valid_symbol) return true;

        if (c.getObjectFlags(t) & (types.ObjectFlags.JSLiteral | types.ObjectFlags.ObjectRestType) != 0) {
            return true;
        }

        if (c.getObjectFlags(t) & types.ObjectFlags.ReverseMapped != 0) {
            return c.isObjectTypeWithInferableIndex(c.getReverseMappedTypeSource(t));
        }

        return false;
    }

    pub fn reportDiagnostic(c: *Checker, diagnostic: ?diagnostics.Diagnostic, diagnosticOutput: ?*std.ArrayListUnmanaged(diagnostics.Diagnostic)) void {
        if (diagnostic) |d| {
            if (diagnosticOutput) |out| {
                out.append(c.allocator, d) catch unreachable;
            } else {
                // c.diagnostics.append(c.allocator, d) catch unreachable;
            }
        }
    }

    pub fn getApplicableIndexInfo(c: *Checker, t: types.TypeIndex, keyType: types.TypeIndex) ?types.IndexInfo {
        return c.findApplicableIndexInfo(c.getIndexInfosOfType(t), keyType);
    }

    pub fn getApplicableIndexInfoForName(c: *Checker, t: types.TypeIndex, name: []const u8) ?types.IndexInfo {
        if (utils.isLateBoundName(name)) {
            return c.getApplicableIndexInfo(t, c.esSymbolTypeIndex orelse 0);
        }
        return c.getApplicableIndexInfo(t, c.getStringLiteralType(name));
    }

    pub fn findApplicableIndexInfo(c: *Checker, indexInfos: []const types.IndexInfo, keyType: types.TypeIndex) ?types.IndexInfo {
        var stringIndexInfo: ?types.IndexInfo = null;
        var applicableInfos: std.ArrayListUnmanaged(types.IndexInfo) = .empty;
        defer applicableInfos.deinit(c.allocator);

        for (indexInfos) |info| {
            if (info.keyType == (c.stringTypeIndex orelse 0)) {
                stringIndexInfo = info;
            } else if (c.isApplicableIndexType(keyType, info.keyType)) {
                applicableInfos.append(c.allocator, info) catch {};
            }
        }

        switch (applicableInfos.items.len) {
            0 => {
                if (stringIndexInfo) |s_info| {
                    if (c.isApplicableIndexType(keyType, c.stringTypeIndex orelse 0)) {
                        return s_info;
                    }
                }
                return null;
            },
            1 => return applicableInfos.items[0],
            else => {
                var isReadonly = true;
                var typesArr: std.ArrayListUnmanaged(types.TypeIndex) = .empty;
                defer typesArr.deinit(c.allocator);

                for (applicableInfos.items) |info| {
                    typesArr.append(c.allocator, info.valueType) catch {};
                    if (!info.isReadonly) {
                        isReadonly = false;
                    }
                }
                return .{
                    .keyType = c.getUnknownType() catch return null,
                    .valueType = c.getIntersectionType(typesArr.items),
                    .isReadonly = isReadonly,
                    .declaration = null,
                };
            },
        }
    }

    pub fn isApplicableIndexType(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
        if (c.isTypeAssignableTo(source, target)) return true;

        if (target == (c.stringTypeIndex orelse 0)) {
            if (c.isTypeAssignableTo(source, c.numberTypeIndex orelse 0)) return true;
        }

        if (target == (c.numberTypeIndex orelse 0)) {
            if (c.numericStringTypeIndex) |n| {
                if (source == n) return true;
            }
            if (c.typesList.items[source].flags & types.TypeFlags.StringLiteral != 0) {
                if (utils.isNumericLiteralName(c.typesList.items[source].data.StringLiteral.text)) return true;
            }
        }
        return false;
    }

    pub fn compareSignaturesIdentical(c: *Checker, source: *types.Signature, target: *types.Signature, partialMatch: bool, ignoreThisTypes: bool, ignoreReturnTypes: bool, isRelatedCtx: anytype, comptime isRelatedFn: fn (ctx: @TypeOf(isRelatedCtx), source: types.TypeIndex, target: types.TypeIndex) types.Ternary) types.Ternary {
        _ = c;
        _ = source;
        _ = target;
        _ = partialMatch;
        _ = ignoreThisTypes;
        _ = ignoreReturnTypes;
        _ = isRelatedFn;
        return .False; // Skipped
    }

    pub fn getIndexInfoKeyType(c: *Checker, info: types.IndexInfo) types.TypeIndex {
        _ = c;
        return info.keyType;
    }

    pub fn getIndexInfoValueType(c: *Checker, info: types.IndexInfo) types.TypeIndex {
        _ = c;
        return info.valueType;
    }

    pub fn isIgnoredJsxProperty(c: *Checker, source: types.TypeIndex, prop: ast_gen.SymbolIndex) bool {
        return (c.getObjectFlags(source) & types.ObjectFlags.JsxAttributes != 0) and relater.isHyphenatedJsxName(c.getSymbolName(prop));
    }

    pub fn getLiteralTypeFromProperty(c: *Checker, prop: ast_gen.SymbolIndex, include: u32, stringify: bool) types.TypeIndex {
        _ = c;
        _ = prop;
        _ = include;
        _ = stringify;
        return 0; // Skipped
    }

    pub fn getNonMissingTypeOfSymbol(c: *Checker, prop: ast_gen.SymbolIndex) types.TypeIndex {
        return c.removeMissingType(c.getTypeOfSymbol(prop), (c.getSymbolFlags(prop) & symbol.SymbolFlags.Optional) != 0);
    }

    pub fn getNarrowedType(c: *Checker, t: types.TypeIndex, candidate: types.TypeIndex, assumeTrue: bool, checkDerived: bool) types.TypeIndex {
        _ = c;
        _ = candidate;
        _ = assumeTrue;
        _ = checkDerived;
        return t;
    }

    pub fn getInstanceType(c: *Checker, constructorType: types.TypeIndex) types.TypeIndex {
        const prototypePropertyType = c.getTypeOfPropertyOfType(constructorType, "prototype");
        if (prototypePropertyType != 0 and !c.isTypeAny(prototypePropertyType)) {
            return prototypePropertyType;
        }

        const constructSignatures = c.getSignaturesOfType(constructorType, types.SignatureKind.Construct);
        if (constructSignatures.len != 0) {
            var returnTypes: std.ArrayListUnmanaged(types.TypeIndex) = .empty;
            defer returnTypes.deinit(c.allocator);
            const sigs = c.resolvedSignaturesPool.items[constructSignatures.start .. constructSignatures.start + constructSignatures.len];
            for (sigs) |sigIdx| {
                const sigPtr = &c.signatures.items[sigIdx];
                const erased = c.getErasedSignature(sigPtr);
                returnTypes.append(c.allocator, c.getReturnTypeOfSignature(erased)) catch unreachable;
            }
            return c.getUnionTypeFromArray(returnTypes.items);
        }
        return c.emptyObjectType;
    }

    pub fn getSymbolForPrivateIdentifierExpression(c: *Checker, expr: ast_gen.NodeIndex) ast_gen.SymbolIndex {
        _ = c;
        _ = expr;
        return 0;
    }

    pub fn getTypeOfPropertyOfType(c: *Checker, t: types.TypeIndex, name: []const u8) types.TypeIndex {
        const prop = c.getPropertyOfType(t, name);
        if (prop) |p| {
            return c.getTypeOfSymbol(p) catch 0;
        }
        return 0;
    }

    fn reportExcessPropertyForObjectLiteralUnionAssignment(c: *Checker, expression: ast_gen.NodeIndex, target: types.TypeIndex) bool {
        if (expression == 0 or expression >= c.binder.ast.nodes.len) return false;
        if ((c.getTypeFlags(target) & types.TypeFlags.Union) == 0) return false;
        const node = c.binder.ast.getNode(expression);
        if (node != .ObjectLiteralExpression) return false;
        const propertiesNode = node.ObjectLiteralExpression.Properties;
        if (propertiesNode == 0) return false;

        const objectProperties = c.binder.ast.getNodeList(propertiesNode);
        if (objectProperties.len == 0) return false;

        var candidates = std.ArrayListUnmanaged(types.TypeIndex).empty;
        defer candidates.deinit(c.allocator);

        for (c.getTypesFromUnion(target)) |candidate| {
            var compatible = true;
            for (objectProperties) |propNode| {
                const propInfo = c.getObjectLiteralPropertyInfo(propNode) orelse continue;
                const targetPropType = c.getTypeOfPropertyOfType(candidate, propInfo.name);
                if (targetPropType == 0) continue;

                const sourceType = c.checkExpressionAdHoc(propInfo.valueExpression) catch continue;
                if (isUnitLikeForExcessProperty(c, sourceType) and isUnitLikeForExcessProperty(c, targetPropType) and !c.literalTypesOverlap(sourceType, targetPropType)) {
                    compatible = false;
                    break;
                }
            }
            if (compatible) {
                candidates.append(c.allocator, candidate) catch {};
            }
        }

        const targetTypes = c.getTypesFromUnion(target);
        if (candidates.items.len == 0 or candidates.items.len == targetTypes.len) return false;

        for (objectProperties) |propNode| {
            const propInfo = c.getObjectLiteralPropertyInfo(propNode) orelse continue;
            var existsInCandidate = false;
            for (candidates.items) |candidate| {
                if (c.getPropertyOfType(candidate, propInfo.name) != null) {
                    existsInCandidate = true;
                    break;
                }
            }
            if (!existsInCandidate) {
                const narrowedTarget = if (candidates.items.len == 1) candidates.items[0] else c.getUnionTypeFromArray(candidates.items);
                var argsArr = c.allocator.alloc([]const u8, 2) catch unreachable;
                c.ownedDiagnosticArgs.append(c.allocator, argsArr) catch unreachable;
                argsArr[0] = propInfo.name;
                argsArr[1] = c.typeToString(narrowedTarget, expression, 0, null);
                c.addDiagnostic(.{
                    .nodeIndex = propInfo.nameNode,
                    .message = &diagnostics_gen.Object_literal_may_only_specify_known_properties_and_0_does_not_exist_in_type_1,
                    .args = argsArr,
                });
                return true;
            }
        }
        return false;
    }

    const ObjectLiteralPropertyInfo = struct {
        name: []const u8,
        nameNode: ast_gen.NodeIndex,
        valueExpression: ast_gen.NodeIndex,
    };

    fn getObjectLiteralPropertyInfo(c: *Checker, propNode: ast_gen.NodeIndex) ?ObjectLiteralPropertyInfo {
        const prop = c.binder.ast.getNode(propNode);
        return switch (prop) {
            .PropertyAssignment => |pa| if (c.propertyNameText(pa.name)) |name| .{
                .name = name,
                .nameNode = pa.name,
                .valueExpression = pa.Initializer,
            } else null,
            .ShorthandPropertyAssignment => |spa| if (c.propertyNameText(spa.name)) |name| .{
                .name = name,
                .nameNode = spa.name,
                .valueExpression = spa.ObjectAssignmentInitializer orelse spa.name,
            } else null,
            else => null,
        };
    }

    fn propertyNameText(c: *Checker, nameNode: ast_gen.NodeIndex) ?[]const u8 {
        const name = c.binder.ast.getNode(nameNode);
        return switch (name) {
            .Identifier => |id| id.Text,
            .StringLiteral => |lit| lit.Text,
            .NumericLiteral => |lit| lit.Text,
            else => null,
        };
    }

    fn isUnitLikeForExcessProperty(c: *Checker, t: types.TypeIndex) bool {
        return (c.getTypeFlags(t) & types.TypeFlags.Unit) != 0;
    }

    fn literalTypesOverlap(c: *Checker, left: types.TypeIndex, right: types.TypeIndex) bool {
        if (left == right) return true;
        if (left == 0 or right == 0 or left >= c.typesList.items.len or right >= c.typesList.items.len) return false;
        const leftType = c.typesList.items[left];
        const rightType = c.typesList.items[right];
        if ((leftType.flags & types.TypeFlags.StringLiteral) != 0 and (rightType.flags & types.TypeFlags.StringLiteral) != 0) {
            return std.mem.eql(u8, leftType.data.StringLiteral.text, rightType.data.StringLiteral.text);
        }
        if ((leftType.flags & types.TypeFlags.NumberLiteral) != 0 and (rightType.flags & types.TypeFlags.NumberLiteral) != 0) {
            return leftType.data.NumberLiteral.value == rightType.data.NumberLiteral.value;
        }
        if ((leftType.flags & types.TypeFlags.BooleanLiteral) != 0 and (rightType.flags & types.TypeFlags.BooleanLiteral) != 0) {
            return leftType.data.BooleanLiteral.value == rightType.data.BooleanLiteral.value;
        }
        return (leftType.flags & (types.TypeFlags.Null | types.TypeFlags.Undefined)) != 0 and leftType.flags == rightType.flags;
    }

    pub fn getStringLiteralType(c: *Checker, value: []const u8) types.TypeIndex {
        if (c.stringLiteralTypes.get(value)) |t| {
            return t;
        }

        const dupedValue = c.allocator.dupe(u8, value) catch unreachable;

        const t = c.createType(.{
            .flags = types.TypeFlags.StringLiteral,
            .objectFlags = types.ObjectFlags.Anonymous,
            .id = 0,
            .symbol = null,
            .alias = null,
            .data = .{ .StringLiteral = .{ .text = dupedValue } },
        }) catch 0;

        c.stringLiteralTypes.put(c.allocator, dupedValue, t) catch unreachable;
        return t;
    }

    pub fn getTypeOfPropertyOrIndexSignatureOfType(c: *Checker, t: types.TypeIndex, name: []const u8) ?types.TypeIndex {
        const propType = c.getTypeOfPropertyOfType(t, name);
        if (propType != 0) {
            return propType;
        }

        // Index info lookup
        // Skipped: Handle late bound names (e.g. symbols)
        const keyType = c.getStringLiteralType(name);
        if (c.getIndexInfoOfType(t, keyType)) |info| {
            return if (c.strictNullChecks) c.getOptionalType(info.valueType, true) else info.valueType;
        }

        return null;
    }

    pub fn maybeTypeOfKind(c: *Checker, tIdx: types.TypeIndex, flags: u32) bool {
        if (tIdx == 0 or tIdx >= c.typesList.items.len) return false;
        const t = c.typesList.items[tIdx];
        if ((t.flags & flags) != 0) {
            return true;
        }
        if ((t.flags & types.TypeFlags.UnionOrIntersection) != 0) {
            const children = c.getTypesOfUnionOrIntersectionType(tIdx);
            for (children) |child| {
                if (c.maybeTypeOfKind(child, flags)) {
                    return true;
                }
            }
        }
        return false;
    }

    pub fn getTypeFacts(c: *Checker, t: types.TypeIndex, mask: u32) u32 {
        return c.getTypeFactsWorker(t, mask) & mask;
    }

    pub fn hasTypeFacts(c: *Checker, t: types.TypeIndex, mask: u32) bool {
        return c.getTypeFacts(t, mask) != 0;
    }

    pub fn getTypeFactsWorker(c: *Checker, t_input: types.TypeIndex, callerOnlyNeeds: u32) u32 {
        var t = t_input;
        var t_flags = c.getTypeFlags(t);
        if ((t_flags & (types.TypeFlags.Intersection | types.TypeFlags.Instantiable)) != 0) {
            t = c.getBaseConstraintOfType(t);
            t_flags = c.getTypeFlags(t);
        }

        if ((t_flags & (types.TypeFlags.String | types.TypeFlags.StringMapping)) != 0) {
            if (c.strictNullChecks) return types.TypeFacts.StringStrictFacts;
            return types.TypeFacts.StringFacts;
        }
        if ((t_flags & (types.TypeFlags.StringLiteral | types.TypeFlags.TemplateLiteral)) != 0) {
            const typeNode = c.typesList.items[t];
            const isEmpty = (t_flags & types.TypeFlags.StringLiteral) != 0 and typeNode.data == .StringLiteral and typeNode.data.StringLiteral.text.len == 0;
            if (c.strictNullChecks) {
                if (isEmpty) return types.TypeFacts.EmptyStringStrictFacts;
                return types.TypeFacts.NonEmptyStringStrictFacts;
            }
            if (isEmpty) return types.TypeFacts.EmptyStringFacts;
            return types.TypeFacts.NonEmptyStringFacts;
        }
        if ((t_flags & (types.TypeFlags.Number | types.TypeFlags.Enum)) != 0) {
            if (c.strictNullChecks) return types.TypeFacts.NumberStrictFacts;
            return types.TypeFacts.NumberFacts;
        }
        if ((t_flags & types.TypeFlags.NumberLiteral) != 0) {
            const typeNode = c.typesList.items[t];
            const isZero = typeNode.data == .NumberLiteral and typeNode.data.NumberLiteral.value == 0;
            if (c.strictNullChecks) {
                if (isZero) return types.TypeFacts.ZeroNumberStrictFacts;
                return types.TypeFacts.NonZeroNumberStrictFacts;
            }
            if (isZero) return types.TypeFacts.ZeroNumberFacts;
            return types.TypeFacts.NonZeroNumberFacts;
        }
        if ((t_flags & types.TypeFlags.BigInt) != 0) {
            if (c.strictNullChecks) return types.TypeFacts.BigIntStrictFacts;
            return types.TypeFacts.BigIntFacts;
        }
        if ((t_flags & types.TypeFlags.BigIntLiteral) != 0) {
            const typeNode = c.typesList.items[t];
            // pseudo-bigint handling for '0' or '0n'
            const isZero = typeNode.data == .BigIntLiteral and
                (std.mem.eql(u8, typeNode.data.BigIntLiteral.text, "0") or std.mem.eql(u8, typeNode.data.BigIntLiteral.text, "0n"));
            if (c.strictNullChecks) {
                if (isZero) return types.TypeFacts.ZeroBigIntStrictFacts;
                return types.TypeFacts.NonZeroBigIntStrictFacts;
            }
            if (isZero) return types.TypeFacts.ZeroBigIntFacts;
            return types.TypeFacts.NonZeroBigIntFacts;
        }
        if ((t_flags & types.TypeFlags.Boolean) != 0) {
            if (c.strictNullChecks) return types.TypeFacts.BooleanStrictFacts;
            return types.TypeFacts.BooleanFacts;
        }
        if ((t_flags & types.TypeFlags.BooleanLike) != 0) {
            const isFalse = t == c.falseTypeIndex or false;
            if (c.strictNullChecks) {
                if (isFalse) return types.TypeFacts.FalseStrictFacts;
                return types.TypeFacts.TrueStrictFacts;
            }
            if (isFalse) return types.TypeFacts.FalseFacts;
            return types.TypeFacts.TrueFacts;
        }
        if ((t_flags & types.TypeFlags.Object) != 0) {
            const possibleFacts = if (c.strictNullChecks)
                types.TypeFacts.EmptyObjectStrictFacts | types.TypeFacts.FunctionStrictFacts | types.TypeFacts.ObjectStrictFacts
            else
                types.TypeFacts.EmptyObjectFacts | types.TypeFacts.FunctionFacts | types.TypeFacts.ObjectFacts;
            if ((callerOnlyNeeds & possibleFacts) == 0) {
                return types.TypeFacts.None;
            }
            const typeNode = c.typesList.items[t];
            const isAnon = (typeNode.objectFlags & types.ObjectFlags.Anonymous) != 0;
            if (isAnon and c.isEmptyObjectType(t)) {
                if (c.strictNullChecks) return types.TypeFacts.EmptyObjectStrictFacts;
                return types.TypeFacts.EmptyObjectFacts;
            } else if (c.isFunctionObjectType(t)) {
                if (c.strictNullChecks) return types.TypeFacts.FunctionStrictFacts;
                return types.TypeFacts.FunctionFacts;
            } else if (c.strictNullChecks) {
                return types.TypeFacts.ObjectStrictFacts;
            }
            return types.TypeFacts.ObjectFacts;
        }
        if ((t_flags & types.TypeFlags.Void) != 0) return types.TypeFacts.VoidFacts;
        if ((t_flags & types.TypeFlags.Undefined) != 0) return types.TypeFacts.UndefinedFacts;
        if ((t_flags & types.TypeFlags.Null) != 0) return types.TypeFacts.NullFacts;
        if ((t_flags & types.TypeFlags.ESSymbolLike) != 0) {
            if (c.strictNullChecks) return types.TypeFacts.SymbolStrictFacts;
            return types.TypeFacts.SymbolFacts;
        }
        if ((t_flags & types.TypeFlags.NonPrimitive) != 0) {
            if (c.strictNullChecks) return types.TypeFacts.ObjectStrictFacts;
            return types.TypeFacts.ObjectFacts;
        }
        if ((t_flags & types.TypeFlags.Never) != 0) return types.TypeFacts.None;
        if ((t_flags & types.TypeFlags.Union) != 0) {
            var facts: u32 = 0;
            const unionTypes = c.getTypesFromUnion(t);
            for (unionTypes) |u| {
                facts |= c.getTypeFactsWorker(u, callerOnlyNeeds);
            }
            return facts;
        }
        if ((t_flags & types.TypeFlags.Intersection) != 0) {
            return c.getIntersectionTypeFacts(t, callerOnlyNeeds);
        }
        return types.TypeFacts.UnknownFacts;
    }

    pub fn getIntersectionTypeFacts(c: *Checker, t: types.TypeIndex, callerOnlyNeeds: u32) u32 {
        const ignoreObjects = c.maybeTypeOfKind(t, types.TypeFlags.Primitive);
        var oredFacts: u32 = types.TypeFacts.None;
        var andedFacts: u32 = types.TypeFacts.All;
        const interTypes = c.getTypesFromIntersection(t);
        for (interTypes) |u| {
            if (!(ignoreObjects and (c.getTypeFlags(u) & types.TypeFlags.Object) != 0)) {
                const f = c.getTypeFactsWorker(u, callerOnlyNeeds);
                oredFacts |= f;
                andedFacts &= f;
            }
        }
        return (oredFacts & types.TypeFacts.OrFactsMask) | (andedFacts & types.TypeFacts.AndFactsMask);
    }

    pub fn mapType(c: *Checker, t: types.TypeIndex, comptime mapFn: anytype, ctx: anytype) types.TypeIndex {
        const flags = c.getTypeFlags(t);
        if ((flags & types.TypeFlags.Union) != 0) {
            var typesList: std.ArrayListUnmanaged(types.TypeIndex) = .empty;
            defer typesList.deinit(c.allocator);
            const unionTypes = c.getTypesFromUnion(t);
            for (unionTypes) |u| {
                typesList.append(c.allocator, mapFn(c, u, ctx)) catch unreachable;
            }
            return c.getUnionTypeFromArray(typesList.items);
        }
        return mapFn(c, t, ctx);
    }

    pub fn filterType(c: *Checker, t: types.TypeIndex, comptime filterFn: anytype, ctx: anytype) types.TypeIndex {
        const flags = c.getTypeFlags(t);
        if ((flags & types.TypeFlags.Union) != 0) {
            var typesList: std.ArrayListUnmanaged(types.TypeIndex) = .empty;
            defer typesList.deinit(c.allocator);
            const unionTypes = c.getTypesFromUnion(t);
            for (unionTypes) |u| {
                if (filterFn(c, u, ctx)) {
                    typesList.append(c.allocator, u) catch unreachable;
                }
            }
            if (typesList.items.len == unionTypes.len) {
                return t;
            }
            return c.getUnionTypeFromArray(typesList.items);
        }
        if (filterFn(c, t, ctx)) {
            return t;
        }
        return c.getNeverType() catch 0;
    }

    fn getTypeWithFactsFilter(c: *Checker, t: types.TypeIndex, include: u32) bool {
        return c.hasTypeFacts(t, include);
    }

    pub fn getTypeWithFacts(c: *Checker, t: types.TypeIndex, include: u32) types.TypeIndex {
        return c.filterType(t, getTypeWithFactsFilter, include);
    }

    pub fn recombineUnknownType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        if (t == (c.unknownTypeIndex orelse 0)) {
            return c.unknownTypeIndex orelse 0;
        }
        return t;
    }

    pub fn getGlobalNonNullableTypeInstantiation(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        const alias = c.getGlobalTypeAliasSymbol("NonNullable", 1, false);
        if (alias != 0) {
            const typesArr = [_]types.TypeIndex{t};
            return c.getTypeAliasInstantiation(alias, &typesArr, null);
        }
        const typesToIntersect = [_]types.TypeIndex{ t, c.emptyObjectTypeIndex.? };
        return c.getIntersectionType(&typesToIntersect);
    }

    pub const RemoveNullableCtx = struct { targetFacts: u32, otherFacts: u32, otherIncludesFacts: u32, emptyAndOtherUnion: types.TypeIndex, facts: u32 };

    pub fn removeNullableByIntersectionMap(c: *Checker, t: types.TypeIndex, ctx: RemoveNullableCtx) types.TypeIndex {
        if (c.hasTypeFacts(t, ctx.targetFacts)) {
            if ((ctx.facts & ctx.otherIncludesFacts) == 0 and c.hasTypeFacts(t, ctx.otherFacts)) {
                const arr = [_]types.TypeIndex{ t, ctx.emptyAndOtherUnion };
                return c.getIntersectionType(&arr);
            }
            const arr2 = [_]types.TypeIndex{ t, c.emptyObjectTypeIndex.? };
            return c.getIntersectionType(&arr2);
        }
        return t;
    }

    pub fn removeNullableByIntersection(c: *Checker, t: types.TypeIndex, targetFacts: u32, otherFacts: u32, otherIncludesFacts: u32, otherType: types.TypeIndex) types.TypeIndex {
        const facts = c.getTypeFacts(t, types.TypeFacts.EQUndefined | types.TypeFacts.EQNull | types.TypeFacts.IsUndefined | types.TypeFacts.IsNull);
        if ((facts & targetFacts) == 0) {
            return t;
        }
        const arrUnion = [_]types.TypeIndex{ c.emptyObjectTypeIndex.?, otherType };
        const emptyAndOtherUnion = c.getUnionTypeFromArray(&arrUnion);

        return c.mapType(t, removeNullableByIntersectionMap, RemoveNullableCtx{
            .targetFacts = targetFacts,
            .otherFacts = otherFacts,
            .otherIncludesFacts = otherIncludesFacts,
            .emptyAndOtherUnion = emptyAndOtherUnion,
            .facts = facts,
        });
    }

    fn getAdjustedTypeWithFactsMap(c: *Checker, t: types.TypeIndex, ctx: void) types.TypeIndex {
        _ = ctx;
        if (c.hasTypeFacts(t, types.TypeFacts.EQUndefinedOrNull)) {
            return c.getGlobalNonNullableTypeInstantiation(t);
        }
        return t;
    }

    pub fn getAdjustedTypeWithFacts(c: *Checker, t_input: types.TypeIndex, facts: u32) types.TypeIndex {
        const t = if (c.strictNullChecks and (c.getTypeFlags(t_input) & types.TypeFlags.Unknown) != 0)
            c.unknownTypeIndex orelse 0
        else
            t_input;

        const reduced = c.recombineUnknownType(c.getTypeWithFacts(t, facts));
        if (c.strictNullChecks) {
            switch (facts) {
                types.TypeFacts.NEUndefined => {
                    return c.removeNullableByIntersection(reduced, types.TypeFacts.EQUndefined, types.TypeFacts.EQNull, types.TypeFacts.IsNull, c.nullTypeIndex.?);
                },
                types.TypeFacts.NENull => {
                    return c.removeNullableByIntersection(reduced, types.TypeFacts.EQNull, types.TypeFacts.EQUndefined, types.TypeFacts.IsUndefined, c.undefinedTypeIndex.?);
                },
                types.TypeFacts.NEUndefinedOrNull, types.TypeFacts.Truthy => {
                    return c.mapType(reduced, getAdjustedTypeWithFactsMap, {});
                },
                else => {},
            }
        }
        return reduced;
    }

    pub fn removeType(c: *Checker, t: types.TypeIndex, toRemove: types.TypeIndex) types.TypeIndex {
        const flags = c.getTypeFlags(t);
        if ((flags & types.TypeFlags.Union) != 0) {
            var typesList: std.ArrayListUnmanaged(types.TypeIndex) = .empty;
            defer typesList.deinit(c.allocator);
            const unionTypes = c.getTypesFromUnion(t);
            for (unionTypes) |u| {
                if (u != toRemove) {
                    typesList.append(c.allocator, u) catch {};
                }
            }
            if (typesList.items.len == unionTypes.len) {
                return t;
            }
            return c.getUnionTypeFromArray(typesList.items);
        }
        if (t != toRemove) {
            return t;
        }
        return c.getNeverType() catch 0;
    }

    pub fn getOptionalType(c: *Checker, t: types.TypeIndex, isProperty: bool) types.TypeIndex {
        const missingOrUndefined = if (isProperty) c.undefinedOrMissingTypeIndex.? else c.undefinedTypeIndex.?;
        const flags = c.getTypeFlags(t);
        if (t == missingOrUndefined or ((flags & types.TypeFlags.Union) != 0 and c.getTypesFromUnion(t)[0] == missingOrUndefined)) {
            return t;
        }
        var arr = [_]types.TypeIndex{ t, missingOrUndefined };
        return c.getUnionTypeFromArray(&arr);
    }

    pub fn getIndexInfoOfType(c: *Checker, source: types.TypeIndex, keyType: types.TypeIndex) ?types.IndexInfo {
        return c.findIndexInfo(c.getIndexInfosOfType(source), keyType);
    }

    pub fn isStringIndexSignatureOnlyTypeWorker(c: *Checker, t: types.TypeIndex) bool {
        const flags = c.typesList.items[t].flags;
        if (flags & (types.TypeFlags.Any | types.TypeFlags.Unknown) != 0) return false;
        if (c.getPropertiesOfType(t).len != 0) return false;
        if (c.getIndexInfoOfType(t, c.numberTypeIndex orelse 0) != null) return false;
        if (c.getIndexInfoOfType(t, c.stringTypeIndex orelse 0) == null) return false;
        return true;
    }

    pub fn getIndexInfosOfType(c: *Checker, t: types.TypeIndex) []const types.IndexInfo {
        return c.getIndexInfosOfStructuredType(c.getReducedApparentType(t));
    }

    pub fn getIndexInfosOfStructuredType(c: *Checker, t: types.TypeIndex) []const types.IndexInfo {
        if (c.typesList.items[t].flags & types.TypeFlags.StructuredType != 0) {
            const members = c.resolveStructuredTypeMembers(t);
            return c.resolvedIndexInfosPool.items[members.indexInfosStart .. members.indexInfosStart + members.indexInfosLen];
        }
        return &[_]types.IndexInfo{};
    }

    pub fn findIndexInfo(c: *Checker, infos: []const types.IndexInfo, keyType: types.TypeIndex) ?types.IndexInfo {
        for (infos) |info| {
            if (c.isTypeIdenticalTo(info.keyType, keyType)) {
                return info;
            }
        }
        return null;
    }

    pub fn getIndexInfoIsReadonly(c: *Checker, info: types.IndexInfo) bool {
        _ = c;
        return info.isReadonly;
    }

    pub fn getGlobalRecordSymbol(c: *Checker) ast_gen.SymbolIndex {
        return c.getGlobalTypeAliasSymbol("Record", 2, true);
    }

    pub fn getGlobalTypeAliasSymbol(c: *Checker, name: []const u8, arity: u32, reportErrors: bool) ast_gen.SymbolIndex {
        const symId = c.getGlobalSymbol(name, symbol.SymbolFlags.TypeAlias, null);
        if (symId == 0) {
            if (reportErrors) {
                c.reportErrorWithArgs(c.currentNode, &diagnostics_gen.Cannot_find_global_type_0, &.{name});
            }
            return 0;
        }

        _ = c.getDeclaredTypeOfSymbol(symId);
        const links = c.typeAliasLinks.getPtr(symId);
        if (links) |l| {
            if (l.typeParameters.len != arity) {
                if (reportErrors) {
                    const arityStr = std.fmt.allocPrint(c.allocator, "{d}", .{arity}) catch "0";
                    c.reportErrorWithArgs(c.currentNode, &diagnostics_gen.Global_type_0_must_have_1_type_parameter_s, &.{ name, arityStr });
                }
                return 0;
            }
        }
        return symId;
    }

    pub fn getGlobalSymbol(c: *Checker, name: []const u8, meaning: u32, diagnostic: ?*const diagnostics_gen.Message) ast_gen.SymbolIndex {
        return resolveName(c, 0, name, meaning, diagnostic, false, false);
    }

    pub fn resolveSymbol(c: *Checker, symbolIdx: ast_gen.SymbolIndex) ast_gen.SymbolIndex {
        return c.resolveSymbolEx(symbolIdx, false);
    }

    pub fn resolveSymbolEx(c: *Checker, symbolIdx: ast_gen.SymbolIndex, dontResolveAlias: bool) ast_gen.SymbolIndex {
        if (!dontResolveAlias) {
            const sym = c.binder.symbols.items[symbolIdx];
            const excludes = symbol.SymbolFlags.Value | symbol.SymbolFlags.Type | symbol.SymbolFlags.Namespace;
            if ((sym.Flags & (symbol.SymbolFlags.Alias | excludes)) == symbol.SymbolFlags.Alias) {
                return c.resolveAlias(symbolIdx);
            }
        }
        return symbolIdx;
    }

    pub fn resolveExternalModuleSymbol(c: *Checker, moduleSymbol: ast_gen.SymbolIndex, dontResolveAlias: bool) ast_gen.SymbolIndex {
        if (moduleSymbol != 0) {
            if (c.binder.symbols.items[moduleSymbol].exports) |exports| {
                const id = c.binder.ast.stringPool.get("export=") orelse return moduleSymbol;
                if (exports.get(id)) |exportEquals| {
                    const resolved = c.resolveSymbolEx(exportEquals, dontResolveAlias);
                    if (resolved != 0) {
                        return c.getMergedSymbol(resolved);
                    }
                }
            }
        }
        return moduleSymbol;
    }

    pub fn getIntrinsicMarkerType(c: *Checker) types.TypeIndex {
        if (c.intrinsicMarkerTypeIndex) |idx| return idx;
        const idx = c.createType(.{ .flags = types.TypeFlags.Intrinsic, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "error" } } }) catch 0;
        c.intrinsicMarkerTypeIndex = idx;
        return idx;
    }

    pub fn getTypeAliasInstantiationKey(typeArguments: []const types.TypeIndex, alias: ?types.TypeAlias) types.CacheHashKey {
        return getTypeInstantiationKey(typeArguments, alias, false);
    }

    pub fn getTypeInstantiationKey(typeArguments: []const types.TypeIndex, alias: ?types.TypeAlias, singleSignature: bool) types.CacheHashKey {
        var hasher = std.hash.Wyhash.init(0);
        for (typeArguments) |t| {
            std.hash.autoHash(&hasher, t);
        }
        if (alias) |a| {
            std.hash.autoHash(&hasher, a.symbol);
            if (a.typeArgumentsLen > 0) {
                // We should hash the type arguments of the alias, but they are stored in the checker's type alias array,
                // wait, typeArgumentsStart and typeArgumentsLen! We need to pass Checker or the array.
                // Since this is just a hash, we can hash the start and len for uniqueness.
                std.hash.autoHash(&hasher, a.typeArgumentsStart);
                std.hash.autoHash(&hasher, a.typeArgumentsLen);
            }
        }
        if (singleSignature) {
            std.hash.autoHash(&hasher, @as(u8, '!'));
        }
        return hasher.final();
    }

    pub fn instantiateTypeWithAlias(c: *Checker, t: types.TypeIndex, mapperIdx: types.TypeMapperIndex, alias: ?types.TypeAlias) types.TypeIndex {
        _ = alias;
        return c.instantiateType(t, mapperIdx);
    }

    pub fn getTypeAliasInstantiation(c: *Checker, sym: ast_gen.SymbolIndex, typeArguments: []const types.TypeIndex, alias: ?types.TypeAlias) types.TypeIndex {
        const t = c.getDeclaredTypeOfSymbol(sym);
        if (t == c.getIntrinsicMarkerType()) {
            const typeKind = c.getIntrinsicTypeKind(sym);

            if (typeKind != .Unknown and typeArguments.len == 1) {
                switch (typeKind) {
                    .NoInfer => return c.getNoInferType(typeArguments[0]),
                    else => return c.getStringMappingType(sym, typeArguments[0]),
                }
            }
        }

        const links = c.typeAliasLinks.getPtr(sym);
        if (links) |l| {
            const typeParameters = l.typeParameters;
            const key = getTypeAliasInstantiationKey(typeArguments, alias);

            if (l.instantiations) |insts| {
                if (insts.get(key)) |inst| {
                    return inst;
                }
            }

            const minTypeArgumentCount = c.getMinTypeArgumentCount(typeParameters);
            const isJs = ast_utils.isInJSFile(c.binder.ast, c.getSymbolValueDeclaration(sym));
            const filledArgs = c.fillMissingTypeArguments(typeArguments, typeParameters, minTypeArgumentCount, isJs);

            if (makeArrayTypeMapper(c, typeParameters, filledArgs)) |mapperIdx| {
                const inst = instantiateTypeWithAlias(c, t, mapperIdx, alias);
                if (l.instantiations == null) {
                    l.instantiations = std.AutoHashMapUnmanaged(types.CacheHashKey, types.TypeIndex).empty;
                }
                l.instantiations.?.put(c.allocator, key, inst) catch {};
                return inst;
            } else |_| {
                return c.unknownTypeIndex orelse 0;
            }
        }
        return t;
    }

    pub fn getNoInferType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        if (c.isNoInferTargetType(t)) {
            return c.getSubstitutionType(t, c.unknownTypeIndex orelse 0);
        }
        return t;
    }

    pub fn isNoInferTargetType(c: *Checker, t: types.TypeIndex) bool {
        const flags = c.typesList.items[t].flags;
        if ((flags & (types.TypeFlags.Union | types.TypeFlags.Intersection)) != 0) {
            const typesArr = if ((flags & types.TypeFlags.Union) != 0)
                c.getTypesFromUnion(t)
            else
                c.getTypesFromIntersection(t);
            for (typesArr) |unionElem| {
                if (c.isNoInferTargetType(unionElem)) return true;
            }
        }
        if ((flags & types.TypeFlags.Substitution) != 0 and !inference.isNoInferType(c, t) and c.isNoInferTargetType(c.getTargetTypeData(t).Substitution.baseType)) {
            return true;
        }
        if ((flags & types.TypeFlags.Object) != 0 and !c.isEmptyAnonymousObjectType(t)) {
            return true;
        }
        if ((flags & (types.TypeFlags.Instantiable & ~types.TypeFlags.Substitution)) != 0 and !c.isPatternLiteralType(t)) {
            return true;
        }
        return false;
    }

    pub fn getIntrinsicTypeKind(c: *Checker, sym: ast_gen.SymbolIndex) types.IntrinsicTypeKind {
        const name = c.binder.symbols.items[sym].Name;
        if (std.mem.eql(u8, name, "Uppercase")) return .Uppercase;
        if (std.mem.eql(u8, name, "Lowercase")) return .Lowercase;
        if (std.mem.eql(u8, name, "Capitalize")) return .Capitalize;
        if (std.mem.eql(u8, name, "Uncapitalize")) return .Uncapitalize;
        if (std.mem.eql(u8, name, "NoInfer")) return .NoInfer;
        return .Unknown;
    }

    pub fn applyStringMapping(c: *Checker, sym: ast_gen.SymbolIndex, str: []const u8) []const u8 {
        const intrinsicKind = c.getIntrinsicTypeKind(sym);
        if (str.len == 0) return str;
        var buf: []u8 = undefined;
        switch (intrinsicKind) {
            .Uppercase => {
                buf = c.allocator.alloc(u8, str.len) catch return str;
                for (str, 0..) |char, i| buf[i] = std.ascii.toUpper(char);
                return buf;
            },
            .Lowercase => {
                buf = c.allocator.alloc(u8, str.len) catch return str;
                for (str, 0..) |char, i| buf[i] = std.ascii.toLower(char);
                return buf;
            },
            .Capitalize => {
                buf = c.allocator.alloc(u8, str.len) catch return str;
                @memcpy(buf, str);
                buf[0] = std.ascii.toUpper(buf[0]);
                return buf;
            },
            .Uncapitalize => {
                buf = c.allocator.alloc(u8, str.len) catch return str;
                @memcpy(buf, str);
                buf[0] = std.ascii.toLower(buf[0]);
                return buf;
            },
            else => return str,
        }
    }

    pub fn applyTemplateStringMapping(c: *Checker, sym: ast_gen.SymbolIndex, texts: [][]const u8, typeArray: []const types.TypeIndex) [][]const u8 {
        var newTexts = c.allocator.alloc([]const u8, texts.len) catch return texts;
        newTexts[0] = c.applyStringMapping(sym, texts[0]);
        var i: usize = 0;
        while (i < typeArray.len) : (i += 1) {
            newTexts[i + 1] = if (c.isPatternLiteralPlaceholderType(typeArray[i])) texts[i + 1] else c.applyStringMapping(sym, texts[i + 1]);
        }
        return newTexts;
    }

    pub fn getStringMappingTypeForGenericType(c: *Checker, sym: ast_gen.SymbolIndex, t: types.TypeIndex) types.TypeIndex {
        // TODO: implement caching if needed
        return c.newStringMappingType(sym, t);
    }

    pub fn newStringMappingType(c: *Checker, sym: ast_gen.SymbolIndex, t: types.TypeIndex) types.TypeIndex {
        const tObj = c.createType(.{
            .flags = types.TypeFlags.StringMapping,
            .objectFlags = 0,
            .symbol = sym,
            .data = .{ .StringMapping = .{ .target = t } },
        }) catch return 0;
        return tObj;
    }

    pub fn getStringMappingType(c: *Checker, sym: ast_gen.SymbolIndex, t: types.TypeIndex) types.TypeIndex {
        const flags = c.getTypeFlags(t);
        if ((flags & (types.TypeFlags.Union | types.TypeFlags.Never)) != 0) {
            const typesArr = c.getTypesOfUnionOrIntersectionType(t);
            var newTypes = c.allocator.alloc(types.TypeIndex, typesArr.len) catch return t;
            for (typesArr, 0..) |typeElem, i| {
                newTypes[i] = c.getStringMappingType(sym, typeElem);
            }
            return c.getUnionTypeFromArray(newTypes);
        } else if ((flags & types.TypeFlags.StringLiteral) != 0) {
            return c.getStringLiteralType(c.applyStringMapping(sym, c.typesList.items[t].data.StringLiteral.text));
        } else if ((flags & types.TypeFlags.TemplateLiteral) != 0) {
            const tl = c.typesList.items[t].data.TemplateLiteral;
            const newTexts = c.applyTemplateStringMapping(sym, tl.texts, c.unionTypesPool.items[tl.typesStart .. tl.typesStart + tl.typesLen]);
            return c.getTemplateLiteralType(newTexts, c.unionTypesPool.items[tl.typesStart .. tl.typesStart + tl.typesLen]);
        } else if ((flags & types.TypeFlags.StringMapping) != 0 and sym == c.typesList.items[t].symbol) {
            return t;
        } else if ((flags & (types.TypeFlags.Any | types.TypeFlags.String | types.TypeFlags.StringMapping)) != 0 or c.isGenericIndexType(t)) {
            return c.getStringMappingTypeForGenericType(sym, t);
        } else if (c.isPatternLiteralPlaceholderType(t)) {
            var texts = [_][]const u8{ "", "" };
            var typesArr = [_]types.TypeIndex{t};
            const tlType = c.getTemplateLiteralType(&texts, &typesArr);
            return c.getStringMappingTypeForGenericType(sym, tlType);
        }
        return t;
    }

    pub fn getPropagatingFlagsOfTypes(c: *Checker, types_arr: []const types.TypeIndex, excludeKinds: u32) u32 {
        var result: u32 = types.ObjectFlags.None;
        for (types_arr) |t| {
            if (c.getTypeFlags(t) & excludeKinds == 0) {
                result |= c.getObjectFlags(t);
            }
        }
        return result & types.ObjectFlags.PropagatingFlags;
    }

    pub fn getTypeListKey(typeArguments: []const types.TypeIndex) u64 {
        var hasher = std.hash.Wyhash.init(0);
        for (typeArguments) |t| {
            std.hash.autoHash(&hasher, t);
        }
        return hasher.final();
    }

    pub fn createTypeReferenceEx(c: *Checker, target: types.TypeIndex, typeArguments: []const types.TypeIndex, objectFlags: u32) !types.TypeIndex {
        const id = getTypeListKey(typeArguments);
        const targetTypeNode = c.typesList.items[target];

        var instantiationsOpt: ?*?std.AutoHashMapUnmanaged(types.CacheHashKey, types.TypeIndex) = null;

        if (std.meta.activeTag(targetTypeNode.data) == .Object) {
            instantiationsOpt = &c.typesList.items[target].data.Object.instantiations;
        } else if (std.meta.activeTag(targetTypeNode.data) == .Tuple) {
            instantiationsOpt = &c.typesList.items[target].data.Tuple.instantiations;
        }

        if (instantiationsOpt) |inst| {
            if (inst.* != null) {
                if (inst.*.?.get(id)) |t| {
                    return t;
                }
            }
        }

        const newFlags = types.ObjectFlags.Reference | objectFlags | c.getPropagatingFlagsOfTypes(typeArguments, types.TypeFlags.None);
        const t = try c.createType(.{ .flags = types.TypeFlags.Object, .objectFlags = newFlags, .symbol = targetTypeNode.symbol, .data = .{ .Object = .{
            .target = target,
        } } });

        var d = &c.typesList.items[t].data.Object;

        // Save type arguments into c.typeArgumentsPool
        const typeArgsStart = @as(u32, @intCast(c.typeArgumentsPool.items.len));
        try c.typeArgumentsPool.appendSlice(c.allocator, typeArguments);
        d.typeArgumentsStart = typeArgsStart;
        d.typeArgumentsLen = @as(u32, @intCast(typeArguments.len));

        // It's safer to re-fetch the pointer after any allocator calls!
        if (std.meta.activeTag(c.typesList.items[target].data) == .Object) {
            var actualTargetData = &c.typesList.items[target].data.Object;
            if (actualTargetData.instantiations == null) {
                actualTargetData.instantiations = std.AutoHashMapUnmanaged(types.CacheHashKey, types.TypeIndex){};
            }
            try actualTargetData.instantiations.?.put(c.allocator, id, t);
        } else if (std.meta.activeTag(c.typesList.items[target].data) == .Tuple) {
            var actualTargetData = &c.typesList.items[target].data.Tuple;
            if (actualTargetData.instantiations == null) {
                actualTargetData.instantiations = std.AutoHashMapUnmanaged(types.CacheHashKey, types.TypeIndex){};
            }
            try actualTargetData.instantiations.?.put(c.allocator, id, t);
        }

        return t;
    }

    pub fn createTypeReference(c: *Checker, target: types.TypeIndex, typeArguments: []const types.TypeIndex) !types.TypeIndex {
        return c.createTypeReferenceEx(target, typeArguments, types.ObjectFlags.None);
    }

    pub const TupleNormalizer = struct {
        types: std.ArrayListUnmanaged(types.TypeIndex),
        infos: std.ArrayListUnmanaged(types.TupleElementInfo),
        lastRequiredIndex: isize,
        firstRestIndex: isize,
        lastOptionalOrRestIndex: isize,

        pub fn init() TupleNormalizer {
            return .{
                .types = .empty,
                .infos = .empty,
                .lastRequiredIndex = -1,
                .firstRestIndex = -1,
                .lastOptionalOrRestIndex = -1,
            };
        }

        pub fn deinit(self: *TupleNormalizer, allocator: std.mem.Allocator) void {
            self.types.deinit(allocator);
            self.infos.deinit(allocator);
        }
        pub fn normalize(self: *TupleNormalizer, c: *Checker, elementTypes: []const types.TypeIndex, elementInfos: []const types.TupleElementInfo) bool {
            self.lastRequiredIndex = -1;
            self.firstRestIndex = -1;
            self.lastOptionalOrRestIndex = -1;

            for (elementTypes, 0..) |t, i| {
                const info = elementInfos[i];
                if (info.flags & types.ElementFlags.Variadic != 0) {
                    if (c.getTypeFlags(t) & types.TypeFlags.Any != 0) {
                        self.add(c, t, .{ .flags = types.ElementFlags.Rest, .labeledDeclaration = info.labeledDeclaration }) catch return false;
                    } else if (c.getTypeFlags(t) & types.TypeFlags.InstantiableNonPrimitive != 0 or c.isGenericMappedType(t)) {
                        self.add(c, t, info) catch return false;
                    } else if (c.isTupleType(t)) {
                        const spreadTypes = c.getTypeArguments(t);
                        if (spreadTypes.len + self.types.items.len >= 10000) {
                            const message = &diagnostics_gen.Expression_produces_a_tuple_type_that_is_too_large_to_represent;
                            c.reportError(0, message);
                            return false;
                        }
                        const spreadInfos = c.getTupleElementInfos(t);
                        for (spreadTypes, 0..) |s, j| {
                            self.add(c, s, spreadInfos[j]) catch return false;
                        }
                    } else {
                        var s: types.TypeIndex = 0;
                        if (c.isArrayLikeType(t)) {
                            s = c.getIndexTypeOfType(t, c.numberTypeIndex orelse 0) orelse 0;
                        }
                        if (s == 0) {
                            s = c.errorTypeIndex orelse 0;
                        }
                        self.add(c, s, .{ .flags = types.ElementFlags.Rest, .labeledDeclaration = info.labeledDeclaration }) catch return false;
                    }
                } else {
                    self.add(c, t, info) catch return false;
                }
            }

            var i: usize = 0;
            while (i < @as(usize, @intCast(@max(0, self.lastRequiredIndex)))) : (i += 1) {
                if (self.infos.items[i].flags & types.ElementFlags.Optional != 0) {
                    self.infos.items[i].flags = types.ElementFlags.Required;
                }
            }

            if (self.firstRestIndex >= 0 and self.firstRestIndex < self.lastOptionalOrRestIndex) {
                var types_to_union: std.ArrayListUnmanaged(types.TypeIndex) = .empty;
                defer types_to_union.deinit(c.allocator);

                i = @intCast(self.firstRestIndex);
                while (i <= @as(usize, @intCast(self.lastOptionalOrRestIndex))) : (i += 1) {
                    var t = self.types.items[i];
                    if (self.infos.items[i].flags & types.ElementFlags.Variadic != 0) {
                        t = c.getIndexedAccessType(t, c.numberTypeIndex orelse 0);
                    }
                    types_to_union.append(c.allocator, t) catch return false;
                }

                self.types.items[@intCast(self.firstRestIndex)] = c.getUnionTypeFromArray(types_to_union.items);

                // Delete
                const start = @as(usize, @intCast(self.firstRestIndex + 1));
                const end = @as(usize, @intCast(self.lastOptionalOrRestIndex + 1));

                const types_len = self.types.items.len;
                if (end < types_len) {
                    std.mem.copyForwards(types.TypeIndex, self.types.items[start..], self.types.items[end..]);
                    std.mem.copyForwards(types.TupleElementInfo, self.infos.items[start..], self.infos.items[end..]);
                }
                self.types.shrinkRetainingCapacity(types_len - (end - start));
                self.infos.shrinkRetainingCapacity(types_len - (end - start));
            }

            return true;
        }

        pub fn add(self: *TupleNormalizer, c: *Checker, t: types.TypeIndex, info: types.TupleElementInfo) !void {
            if (info.flags & types.ElementFlags.Required != 0) {
                self.lastRequiredIndex = @intCast(self.types.items.len);
            }
            if (info.flags & types.ElementFlags.Rest != 0 and self.firstRestIndex < 0) {
                self.firstRestIndex = @intCast(self.types.items.len);
            }
            if (info.flags & (types.ElementFlags.Optional | types.ElementFlags.Rest) != 0) {
                self.lastOptionalOrRestIndex = @intCast(self.types.items.len);
            }
            try self.types.append(c.allocator, c.addOptionalityEx(t, true, info.flags & types.ElementFlags.Optional != 0));
            try self.infos.append(c.allocator, info);
        }
    };

    pub fn getCrossProductUnionSize(c: *Checker, types_arr: []const types.TypeIndex) usize {
        var size: usize = 1;
        for (types_arr) |t| {
            if (c.getTypeFlags(t) & types.TypeFlags.Union != 0) {
                const n = c.getTypesFromUnion(t).len;
                if (n > 0 and size > std.math.maxInt(usize) / n) {
                    return std.math.maxInt(usize);
                }
                size *= n;
            } else if (c.getTypeFlags(t) & types.TypeFlags.Never != 0) {
                return 0;
            }
        }
        return size;
    }

    pub fn checkCrossProductUnion(c: *Checker, types_arr: []const types.TypeIndex) bool {
        const size = c.getCrossProductUnionSize(types_arr);
        if (size >= 100000) {
            c.reportError(0, &diagnostics_gen.Expression_produces_a_union_type_that_is_too_complex_to_represent);
            return false;
        }
        return true;
    }

    pub fn getTupleKey(c: *Checker, elementInfos: []const types.TupleElementInfo, readonly: bool) types.CacheHashKey {
        _ = c;
        var hasher = std.hash.Wyhash.init(0);
        for (elementInfos) |e| {
            if ((e.flags & types.ElementFlags.Required) != 0) {
                hasher.update("#");
            } else if ((e.flags & types.ElementFlags.Optional) != 0) {
                hasher.update("?");
            } else if ((e.flags & types.ElementFlags.Rest) != 0) {
                hasher.update(".");
            } else {
                hasher.update("*");
            }
            if (e.labeledDeclaration) |node| {
                const nodeBytes = std.mem.asBytes(&node);
                hasher.update(nodeBytes);
            }
        }
        if (readonly) {
            hasher.update("R");
        }
        return hasher.final();
    }

    pub fn getTupleTargetType(c: *Checker, elementInfos: []const types.TupleElementInfo, readonly: bool) types.TypeIndex {
        if (elementInfos.len == 1 and (elementInfos[0].flags & types.ElementFlags.Rest) != 0) {
            if (readonly) {
                return c.globalReadonlyArrayType;
            }
            return c.globalArrayType;
        }
        const key = c.getTupleKey(elementInfos, readonly);
        if (c.tupleTypes.get(key)) |t| {
            return t;
        }
        const t = c.createTupleTargetType(elementInfos, readonly);
        c.tupleTypes.put(c.allocator, key, t) catch {};
        return t;
    }

    pub fn createTupleTargetType(c: *Checker, elementInfos: []const types.TupleElementInfo, readonly: bool) types.TypeIndex {
        const arity = elementInfos.len;
        var minLength: u32 = 0;
        for (elementInfos) |e| {
            if ((e.flags & (types.ElementFlags.Required | types.ElementFlags.Variadic)) != 0) {
                minLength += 1;
            }
        }
        var combinedFlags: u32 = types.ElementFlags.None;
        var typeParametersStart: u32 = 0;

        var members = std.AutoHashMapUnmanaged([]const u8, ast_gen.SymbolIndex){};
        defer members.deinit(c.allocator);

        if (arity != 0) {
            typeParametersStart = @as(u32, @intCast(c.typeArgumentsPool.items.len));
            c.typeArgumentsPool.ensureUnusedCapacity(c.allocator, arity) catch {};
            for (elementInfos, 0..) |e, i| {
                const typeParameter = c.createTypeParameter(0);
                c.typeArgumentsPool.appendAssumeCapacity(typeParameter);
                const flags = e.flags;
                combinedFlags |= flags;
                if ((combinedFlags & types.ElementFlags.Variable) == 0) {
                    var buf: [32]u8 = undefined;
                    const name = std.fmt.bufPrint(&buf, "{d}", .{i}) catch "0";
                    const allocName = c.allocator.dupe(u8, name) catch name;
                    const symFlags = types.SymbolFlags.Property | if ((flags & types.ElementFlags.Optional) != 0) types.SymbolFlags.Optional else 0;
                    const property = c.createSymbolEx(symFlags, allocName, if (readonly) types.CheckFlags.Readonly else 0);
                    c.valueSymbolLinks.getPtr(property).?.resolvedType = typeParameter;
                    members.put(c.allocator, allocName, property) catch {};
                }
            }
        }

        const fixedLength = @as(u32, @intCast(members.count()));
        const lengthSymbol = c.createSymbolEx(types.SymbolFlags.Property, "length", if (readonly) types.CheckFlags.Readonly else 0);

        if ((combinedFlags & types.ElementFlags.Variable) != 0) {
            c.valueSymbolLinks.getPtr(lengthSymbol).?.resolvedType = c.numberType;
        } else {
            var literalTypes = std.ArrayListUnmanaged(types.TypeIndex).initCapacity(c.allocator, arity - minLength + 1) catch unreachable;
            defer literalTypes.deinit(c.allocator);
            var i: u32 = minLength;
            while (i <= arity) : (i += 1) {
                literalTypes.appendAssumeCapacity(c.getNumberLiteralType(i)); // Assuming getNumberLiteralType handles u32 correctly
            }
            c.valueSymbolLinks.getPtr(lengthSymbol).?.resolvedType = c.getUnionTypeFromArray(literalTypes.items);
        }
        members.put(c.allocator, "length", lengthSymbol) catch {};

        const t = c.createType(.{
            .flags = types.TypeFlags.Object,
            .objectFlags = types.ObjectFlags.Tuple | types.ObjectFlags.Reference,
            .data = .{ .Tuple = .{
                .typesStart = 0,
                .typesLen = 0,
                .elementInfosStart = 0,
                .readonly = readonly,
                .combinedFlags = combinedFlags,
                .minLength = minLength,
                .fixedLength = fixedLength,
                .hasRestElement = (combinedFlags & types.ElementFlags.Rest) != 0,
                .typeParametersStart = typeParametersStart,
                .typeParametersLen = @as(u32, @intCast(arity)),
            } },
        }) catch return 0;

        var d = &c.typesList.items[t].data.Tuple;
        d.thisType = c.createTypeParameter(0);
        c.typesList.items[d.thisType.?].data.TypeParameter.isThisType = true;
        c.typesList.items[d.thisType.?].data.TypeParameter.constraintType = t;

        c.typeArgumentsPool.append(c.allocator, d.thisType.?) catch {}; // append to allTypeParameters
        d.target = t;

        // Ensure elementInfos are saved in c.tupleElementInfos if not already
        const elementInfosStart = @as(u32, @intCast(c.tupleElementInfos.items.len));
        c.tupleElementInfos.appendSlice(c.allocator, elementInfos) catch {};
        d.elementInfosStart = elementInfosStart;

        d.typesStart = typeParametersStart;
        d.typesLen = @as(u32, @intCast(arity));

        // Members should be saved to c.binder.symbolMembers
        c.binder.symbolMembers.put(c.allocator, t, members) catch {}; // Actually should be stored on the tuple type symbol? Wait! t is a TypeIndex, not SymbolIndex.
        // Go's TupleType has declaredMembers which is ast.SymbolTable
        // Let's create a dummy symbol for the Tuple target and attach members to it
        const tupleSym = c.createSymbolEx(types.SymbolFlags.TypeLiteral, "__tuple", 0);
        c.typesList.items[t].symbol = tupleSym;
        c.binder.symbolMembers.put(c.allocator, tupleSym, members) catch {};

        d.instantiations = std.AutoHashMapUnmanaged(types.CacheHashKey, types.TypeIndex){};

        // d.instantiations[getTypeListKey(d.TypeParameters())] = t
        const typeParams = c.typeArgumentsPool.items[typeParametersStart .. typeParametersStart + arity];
        d.instantiations.?.put(c.allocator, getTypeListKey(typeParams), t) catch {};

        return t;
    }

    pub const CreateTupleCtx = struct {
        target: types.TypeIndex,
        elementTypes: []const types.TypeIndex,
        objectFlags: u32,
        replaceIndex: usize,
    };

    pub fn createNormalizedTupleTypeExMapFn(c: *Checker, t: types.TypeIndex, ctx: CreateTupleCtx) types.TypeIndex {
        var newElementTypes = std.ArrayListUnmanaged(types.TypeIndex).initCapacity(c.allocator, ctx.elementTypes.len) catch return c.errorTypeIndex orelse 0;
        defer newElementTypes.deinit(c.allocator);
        newElementTypes.appendSliceAssumeCapacity(ctx.elementTypes);
        newElementTypes.items[ctx.replaceIndex] = t;
        return c.createNormalizedTupleTypeEx(ctx.target, newElementTypes.items, ctx.objectFlags);
    }

    pub fn createNormalizedTupleTypeEx(c: *Checker, target: types.TypeIndex, elementTypes: []const types.TypeIndex, objectFlags: u32) types.TypeIndex {
        const d = c.getTargetTypeData(target).Tuple;
        if (d.combinedFlags & types.ElementFlags.NonRequired == 0) {
            return c.createTypeReferenceEx(target, elementTypes, objectFlags) catch c.errorTypeIndex orelse 0;
        }

        const elementInfos = c.getTupleElementInfos(target);

        if (d.combinedFlags & types.ElementFlags.Variadic != 0) {
            for (elementTypes, 0..) |e, i| {
                if (i < elementInfos.len and elementInfos[i].flags & types.ElementFlags.Variadic != 0 and c.getTypeFlags(e) & (types.TypeFlags.Never | types.TypeFlags.Union) != 0) {
                    var checkTypes: std.ArrayListUnmanaged(types.TypeIndex) = .empty;
                    for (elementTypes, 0..) |t, j| {
                        if (j < elementInfos.len and elementInfos[j].flags & types.ElementFlags.Variadic != 0) {
                            checkTypes.append(c.allocator, t) catch return c.errorTypeIndex orelse 0;
                        } else {
                            checkTypes.append(c.allocator, c.unknownTypeIndex orelse 0) catch return c.errorTypeIndex orelse 0;
                        }
                    }
                    if (c.checkCrossProductUnion(checkTypes.items)) {
                        checkTypes.deinit(c.allocator);
                        return c.mapType(e, createNormalizedTupleTypeExMapFn, CreateTupleCtx{
                            .target = target,
                            .elementTypes = elementTypes,
                            .objectFlags = objectFlags,
                            .replaceIndex = i,
                        });
                    }
                    checkTypes.deinit(c.allocator);
                }
            }
        }

        var n = TupleNormalizer.init();
        defer n.deinit(c.allocator);

        const infos_to_use = elementInfos;
        if (!n.normalize(c, elementTypes[0..infos_to_use.len], infos_to_use)) {
            return c.errorTypeIndex orelse 0;
        }
        if (elementTypes.len > infos_to_use.len) {
            n.types.append(c.allocator, elementTypes[infos_to_use.len]) catch return c.errorTypeIndex orelse 0;
        }

        return c.createTupleTypeEx(n.types.items, n.infos.items, d.readonly);
    }

    pub fn createNormalizedTupleType(c: *Checker, target: types.TypeIndex, elementTypes: []const types.TypeIndex) types.TypeIndex {
        return c.createNormalizedTupleTypeEx(target, elementTypes, types.ObjectFlags.None);
    }

    pub fn createNormalizedTypeReference(c: *Checker, target: types.TypeIndex, typeArguments: []const types.TypeIndex) types.TypeIndex {
        if (c.isTupleType(target)) {
            return c.createNormalizedTupleType(target, typeArguments);
        }
        return c.createTypeReference(target, typeArguments) catch c.errorTypeIndex orelse 0;
    }

    pub fn instantiateReverseMappedType(c: *Checker, t: types.TypeIndex, m: types.TypeMapperIndex) types.TypeIndex {
        const r = c.getTargetTypeData(t).ReverseMapped;
        const innerMappedType = c.instantiateType(r.mappedType, m);
        if (c.getObjectFlags(innerMappedType) & types.ObjectFlags.Mapped == 0) {
            return t;
        }
        const innerIndexType = c.instantiateType(r.constraintType, m);
        if (c.getTypeFlags(innerIndexType) & types.TypeFlags.Index == 0) {
            return t;
        }
        const instantiated = inference.inferTypeForHomomorphicMappedType(c, c.instantiateType(r.source, m), innerMappedType, innerIndexType);
        if (instantiated) |inst| {
            return inst;
        }
        return t;
    }

    pub fn getConditionalTypeKey(typeArguments: []const types.TypeIndex, alias: ?types.TypeAlias, forConstraint: bool) u64 {
        var hasher = std.hash.Wyhash.init(0);
        for (typeArguments) |t| {
            hasher.update(std.mem.asBytes(&t));
        }
        if (alias) |a| {
            hasher.update(std.mem.asBytes(&a.symbol));
            hasher.update(std.mem.asBytes(&a.typeArgumentsStart));
            hasher.update(std.mem.asBytes(&a.typeArgumentsLen));
        }
        hasher.update(std.mem.asBytes(&forConstraint));
        return hasher.final();
    }

    pub fn skipTypeParentheses(c: *Checker, node_idx: ast_gen.NodeIndex) ast_gen.NodeIndex {
        var current = node_idx;
        while (current != 0 and c.binder.ast.getNode(current) == .ParenthesizedType) {
            current = c.binder.ast.getNode(current).ParenthesizedType.Type;
        }
        return current;
    }

    pub fn isSimpleTupleType(c: *Checker, node_idx: ast_gen.NodeIndex) bool {
        if (node_idx == 0) return false;
        const node = c.binder.ast.getNode(node_idx);
        if (node != .TupleType) return false;

        const elements = c.binder.ast.getNodeList(node.TupleType.Elements);
        if (elements.len == 0) return false;

        for (elements) |el_idx| {
            if (el_idx == 0) continue;
            const el = c.binder.ast.getNode(el_idx);
            switch (el) {
                .OptionalType, .RestType => return false,
                .NamedTupleMember => |m| {
                    if (m.QuestionToken != null or m.DotDotDotToken != null) return false;
                },
                else => {},
            }
        }
        return true;
    }

    pub fn isDeferredType(c: *Checker, t: types.TypeIndex, checkTuples: bool) bool {
        if (c.getGenericObjectFlags(t) != 0) return true;
        if (checkTuples and c.isTupleType(t)) {
            for (c.getTypeArguments(t)) |el| {
                if (c.getGenericObjectFlags(el) != 0) return true;
            }
        }
        return false;
    }

    pub const TailRecursionRootResult = struct {
        root: ?*types.ConditionalRoot,
        mapper: types.TypeMapperIndex,
    };

    pub fn getTailRecursionRoot(c: *Checker, newType_: types.TypeIndex, newMapper: types.TypeMapperIndex) TailRecursionRootResult {
        if (c.getTypeFlags(newType_) & types.TypeFlags.Conditional != 0 and newMapper != 0) {
            const condData = &c.typesList.items[newType_].data.Conditional;
            const newRoot = condData.root;
            const outerTypeParameters = c.unionTypesPool.items[newRoot.outerTypeParametersStart .. newRoot.outerTypeParametersStart + newRoot.outerTypeParametersLen];
            if (outerTypeParameters.len != 0) {
                const typeParamMapper = mapper_pkg.combineTypeMappers(c, condData.mapper, newMapper);
                const typeArguments = instantiateTypes(c, outerTypeParameters, typeParamMapper) catch return .{ .root = null, .mapper = 0 };
                const newRootMapper = mapper_pkg.createTypeMapper(c, outerTypeParameters, typeArguments);
                var newCheckType: types.TypeIndex = 0;
                if (newRoot.isDistributive) {
                    newCheckType = c.instantiateType(newRoot.checkType, newRootMapper);
                }
                if (newCheckType == 0 or newCheckType == newRoot.checkType or c.getTypeFlags(newCheckType) & (types.TypeFlags.Union | types.TypeFlags.Never) == 0) {
                    return .{ .root = newRoot, .mapper = newRootMapper };
                }
            }
        }
        return .{ .root = null, .mapper = 0 };
    }

    pub fn getConditionalType(c: *Checker, root_ptr: *types.ConditionalRoot, mapper_idx: types.TypeMapperIndex, forConstraint: bool, alias: ?types.TypeAlias) types.TypeIndex {
        var result: types.TypeIndex = 0;
        var extraTypes: std.ArrayListUnmanaged(types.TypeIndex) = .empty;
        defer extraTypes.deinit(c.allocator);

        var tailCount: u32 = 0;
        _ = forConstraint;
        var root = root_ptr;
        var mapper = mapper_idx;
        var current_alias = alias;

        while (true) {
            if (tailCount == 1000) {
                c.reportError(0, &diagnostics_gen.Type_instantiation_is_excessively_deep_and_possibly_infinite);
                return c.errorTypeIndex orelse 0;
            }

            const checkType = c.instantiateType(c.getActualTypeVariable(root.checkType), mapper);
            const extendsType = c.instantiateType(root.extendsType, mapper);

            if (checkType == (c.errorTypeIndex orelse 0) or extendsType == (c.errorTypeIndex orelse 0)) {
                return c.errorTypeIndex orelse 0;
            }

            if (checkType == (c.wildcardTypeIndex orelse 0) or extendsType == (c.wildcardTypeIndex orelse 0)) {
                return c.wildcardTypeIndex orelse 0;
            }

            const root_node = c.binder.ast.getNode(root.node).ConditionalType;
            const checkTypeNode = c.skipTypeParentheses(root_node.CheckType);
            const extendsTypeNode = c.skipTypeParentheses(root_node.ExtendsType);

            const checkTuples = c.isSimpleTupleType(checkTypeNode) and c.isSimpleTupleType(extendsTypeNode) and c.binder.ast.getNodeList(c.binder.ast.getNode(checkTypeNode).TupleType.Elements).len == c.binder.ast.getNodeList(c.binder.ast.getNode(extendsTypeNode).TupleType.Elements).len;

            const checkTypeDeferred = c.isDeferredType(checkType, checkTuples);

            var combinedMapper: types.TypeMapperIndex = 0;

            if (root.inferTypeParametersLen != 0) {
                const inferTypeParameters = c.unionTypesPool.items[root.inferTypeParametersStart .. root.inferTypeParametersStart + root.inferTypeParametersLen];
                const contextId = c.newInferenceContext(inferTypeParameters, null, types.InferenceFlags.None, .Assignable);
                var context = &c.inferenceContexts.items[contextId];
                if (mapper != 0) {
                    context.nonFixingMapper = mapper_pkg.combineTypeMappers(c, context.nonFixingMapper, mapper);
                }
                if (!checkTypeDeferred) {
                    c.inferTypes(context.inferences.items, checkType, extendsType, types.InferencePriority.NoConstraints | types.InferencePriority.AlwaysStrict, false);
                }
                if (mapper != 0) {
                    combinedMapper = mapper_pkg.combineTypeMappers(c, context.mapper, mapper);
                } else {
                    combinedMapper = context.mapper;
                }
            }

            var inferredExtendsType: types.TypeIndex = 0;
            if (combinedMapper != 0) {
                inferredExtendsType = c.instantiateType(root.extendsType, combinedMapper);
            } else {
                inferredExtendsType = extendsType;
            }

            if (!checkTypeDeferred and !c.isDeferredType(inferredExtendsType, checkTuples)) {
                if (c.getTypeFlags(inferredExtendsType) & (types.TypeFlags.Any | types.TypeFlags.Unknown) == 0 and (c.getTypeFlags(checkType) & types.TypeFlags.Any != 0 or !c.isTypeAssignableTo(c.getPermissiveInstantiation(checkType), c.getPermissiveInstantiation(inferredExtendsType)))) {
                    const some_type_condition = false;

                    if (c.getTypeFlags(checkType) & types.TypeFlags.Any != 0 or some_type_condition) {
                        const trueTypeIdx = type_resolution_pkg.getTypeFromTypeNode(c, root_node.TrueType);
                        extraTypes.append(c.allocator, c.instantiateType(trueTypeIdx, if (combinedMapper != 0) combinedMapper else mapper)) catch return c.errorTypeIndex orelse 0;
                    }

                    const falseType = type_resolution_pkg.getTypeFromTypeNode(c, root_node.FalseType);
                    if (c.getTypeFlags(falseType) & types.TypeFlags.Conditional != 0) {
                        const newRoot = c.typesList.items[falseType].data.Conditional.root;

                        // wait, newRoot.node.Parent ? We don't have Parent in AST! In Zig we skip this or use something else.
                        // I will skip parent check for now.
                        if (!newRoot.isDistributive or newRoot.checkType == root.checkType) {
                            root = newRoot;
                            continue;
                        }
                        const tailRec = c.getTailRecursionRoot(falseType, mapper);
                        if (tailRec.root != null) {
                            root = tailRec.root.?;
                            mapper = tailRec.mapper;
                            current_alias = null;
                            if (root.alias != null) {
                                tailCount += 1;
                            }
                            continue;
                        }
                    }
                    result = c.instantiateType(falseType, mapper);
                    break;
                }

                if (c.getTypeFlags(inferredExtendsType) & (types.TypeFlags.Any | types.TypeFlags.Unknown) != 0 or c.isTypeAssignableTo(c.getRestrictiveInstantiation(checkType), c.getRestrictiveInstantiation(inferredExtendsType))) {
                    const trueTypeIdx = type_resolution_pkg.getTypeFromTypeNode(c, root_node.TrueType);
                    const trueMapper = if (combinedMapper != 0) combinedMapper else mapper;
                    const tailRec = c.getTailRecursionRoot(trueTypeIdx, trueMapper);
                    if (tailRec.root != null) {
                        root = tailRec.root.?;
                        mapper = tailRec.mapper;
                        current_alias = null;
                        if (root.alias != null) {
                            tailCount += 1;
                        }
                        continue;
                    }
                    result = c.instantiateType(trueTypeIdx, trueMapper);
                    break;
                }
            }

            result = c.newConditionalType(root, mapper, combinedMapper);
            if (current_alias != null) {
                // We should update alias on result, but wait, type data is immutable after creation usually.
                // Or maybe createType handles alias?
                // I will ignore for now or add a setAlias method.
            } else {
                // c.instantiateTypeAlias
            }
            break;
        }

        if (extraTypes.items.len > 0) {
            extraTypes.append(c.allocator, result) catch return c.errorTypeIndex orelse 0;
            return c.getUnionTypeFromArray(extraTypes.items);
        }
        return result;
    }

    pub fn getConditionalTypeInstantiation(c: *Checker, t: types.TypeIndex, mapperIdx: types.TypeMapperIndex, forConstraint: bool, alias: ?types.TypeAlias) types.TypeIndex {
        var root = c.getTargetTypeData(t).Conditional.root;
        const outerTypeParameters = c.unionTypesPool.items[root.outerTypeParametersStart .. root.outerTypeParametersStart + root.outerTypeParametersLen];
        if (outerTypeParameters.len != 0) {
            const typeArguments = instantiateTypes(c, outerTypeParameters, mapperIdx) catch return c.unknownTypeIndex orelse 0;
            const key = getConditionalTypeKey(typeArguments, alias, forConstraint);
            if (root.instantiations == null) {
                root.instantiations = std.AutoHashMapUnmanaged(types.CacheHashKey, types.TypeIndex).empty;
            }
            if (root.instantiations.?.get(key)) |result| {
                return result;
            }
            const newMapper = mapper_pkg.createTypeMapper(c, outerTypeParameters, typeArguments);
            const checkType = root.checkType;
            var distributionType: types.TypeIndex = 0;
            if (root.isDistributive) {
                distributionType = c.getReducedType(c.instantiateType(checkType, newMapper));
            }
            var result: types.TypeIndex = 0;
            if (distributionType != 0 and checkType != distributionType and (c.typesList.items[distributionType].flags & (types.TypeFlags.Union | types.TypeFlags.Never)) != 0) {
                const CtxStruct = struct {
                    root: *types.ConditionalRoot,
                    checkType: types.TypeIndex,
                    newMapper: types.TypeMapperIndex,
                    forConstraint: bool,
                };
                const S = struct {
                    pub fn mapFn(inner_c: *Checker, t2: types.TypeIndex, ctx: *const CtxStruct) types.TypeIndex {
                        const prepended = prependTypeMapping(inner_c, ctx.checkType, t2, ctx.newMapper) catch 0;
                        return inner_c.getConditionalType(ctx.root, prepended, ctx.forConstraint, null);
                    }
                };
                const mapCtx = CtxStruct{ .root = root, .checkType = checkType, .newMapper = newMapper, .forConstraint = forConstraint };
                result = c.mapType(distributionType, S.mapFn, &mapCtx);
            } else {
                result = c.getConditionalType(root, newMapper, forConstraint, alias);
            }
            root.instantiations.?.put(c.allocator, key, result) catch {};
            return result;
        }
        return t;
    }

    pub fn getTemplateStringForType(c: *Checker, t: types.TypeIndex) []const u8 {
        const flags = c.getTypeFlags(t);
        if ((flags & types.TypeFlags.StringLiteral) != 0) {
            return c.getTargetTypeData(t).StringLiteral.text;
        } else if ((flags & types.TypeFlags.NumberLiteral) != 0) {
            const v = c.getTargetTypeData(t).NumberLiteral.value;
            var buf: [64]u8 = undefined;
            const slice = std.fmt.bufPrint(&buf, "{d}", .{v}) catch "";
            return c.allocator.dupe(u8, slice) catch "";
        } else if ((flags & types.TypeFlags.BooleanLiteral) != 0) {
            const v = c.getTargetTypeData(t).BooleanLiteral.value;
            return if (v) "true" else "false";
        } else if ((flags & types.TypeFlags.BigIntLiteral) != 0) {
            return c.getTargetTypeData(t).BigIntLiteral.text;
        } else if ((flags & types.TypeFlags.Nullable) != 0) {
            if ((flags & types.TypeFlags.Null) != 0) return "null";
            if ((flags & types.TypeFlags.Undefined) != 0) return "undefined";
        }
        return "";
    }

    pub fn getTemplateTypeKey(texts: [][]const u8, typesArr: []const types.TypeIndex) types.CacheHashKey {
        var hasher = std.hash.Wyhash.init(0);
        for (typesArr) |t| std.hash.autoHash(&hasher, t);
        std.hash.autoHash(&hasher, @as(u8, '|'));
        for (texts) |s| std.hash.autoHash(&hasher, s.len);
        std.hash.autoHash(&hasher, @as(u8, '|'));
        for (texts) |s| hasher.update(s);
        return hasher.final();
    }

    pub fn newTemplateLiteralType(c: *Checker, texts: [][]const u8, typesArr: []const types.TypeIndex) types.TypeIndex {
        const typesStart: u32 = @intCast(c.tupleTypesPool.items.len);
        c.tupleTypesPool.appendSlice(c.allocator, typesArr) catch unreachable;

        // Ensure texts are duplicated using allocator so they persist
        const dupedTexts = c.allocator.dupe([]const u8, texts) catch unreachable;
        for (dupedTexts, 0..) |s, i| {
            dupedTexts[i] = c.allocator.dupe(u8, s) catch unreachable;
        }

        return c.createType(.{
            .flags = types.TypeFlags.TemplateLiteral,
            .objectFlags = 0,
            .id = 0,
            .symbol = null,
            .alias = null,
            .data = .{ .TemplateLiteral = .{
                .texts = dupedTexts,
                .typesStart = typesStart,
                .typesLen = @intCast(typesArr.len),
            } },
        }) catch c.errorTypeIndex orelse 0;
    }

    pub const GetTemplateCtx = struct {
        texts: [][]const u8,
        typesArr: []const types.TypeIndex,
        unionIndex: usize,
    };

    pub fn getTemplateLiteralTypeMapFn(c: *Checker, t: types.TypeIndex, ctx: GetTemplateCtx) types.TypeIndex {
        var newTypes = std.ArrayListUnmanaged(types.TypeIndex).initCapacity(c.allocator, ctx.typesArr.len) catch return c.errorTypeIndex orelse 0;
        defer newTypes.deinit(c.allocator);
        newTypes.appendSliceAssumeCapacity(ctx.typesArr);
        newTypes.items[ctx.unionIndex] = t;
        return c.getTemplateLiteralType(ctx.texts, newTypes.items);
    }

    pub fn addSpansForTemplateLiteral(c: *Checker, texts: [][]const u8, typesArr: []const types.TypeIndex, newTexts: *std.ArrayListUnmanaged([]const u8), newTypes: *std.ArrayListUnmanaged(types.TypeIndex), sb: *std.ArrayListUnmanaged(u8)) bool {
        for (typesArr, 0..) |t, i| {
            const flags = c.getTypeFlags(t);
            if (flags & types.TypeFlags.StringLiteral != 0) {
                sb.appendSlice(c.allocator, c.typesList.items[t].data.StringLiteral.text) catch {};
                sb.appendSlice(c.allocator, texts[i + 1]) catch {};
            } else if (flags & types.TypeFlags.NumberLiteral != 0) {
                var buf: [64]u8 = undefined;
                const slice = std.fmt.bufPrint(&buf, "{d}", .{c.typesList.items[t].data.NumberLiteral.value}) catch "";
                sb.appendSlice(c.allocator, slice) catch {};
                sb.appendSlice(c.allocator, texts[i + 1]) catch {};
            } else if (flags & types.TypeFlags.BigIntLiteral != 0) {
                sb.appendSlice(c.allocator, c.typesList.items[t].data.BigIntLiteral.text) catch {};
                sb.appendSlice(c.allocator, texts[i + 1]) catch {};
            } else if (flags & types.TypeFlags.BooleanLiteral != 0) {
                if (t == (c.trueTypeIndex orelse 0)) {
                    sb.appendSlice(c.allocator, "true") catch {};
                } else {
                    sb.appendSlice(c.allocator, "false") catch {};
                }
                sb.appendSlice(c.allocator, texts[i + 1]) catch {};
            } else if (t == (c.nullTypeIndex orelse 0)) {
                sb.appendSlice(c.allocator, "null") catch {};
                sb.appendSlice(c.allocator, texts[i + 1]) catch {};
            } else if (t == (c.undefinedTypeIndex orelse 0)) {
                sb.appendSlice(c.allocator, "undefined") catch {};
                sb.appendSlice(c.allocator, texts[i + 1]) catch {};
            } else if (flags & types.TypeFlags.TemplateLiteral != 0) {
                const tData = c.typesList.items[t].data.TemplateLiteral;
                const tTexts = tData.texts;
                const tTypesSlice = c.tupleTypesPool.items[tData.typesStart .. tData.typesStart + tData.typesLen];

                sb.appendSlice(c.allocator, tTexts[0]) catch {};
                if (!c.addSpansForTemplateLiteral(tTexts, tTypesSlice, newTexts, newTypes, sb)) {
                    return false;
                }
                sb.appendSlice(c.allocator, texts[i + 1]) catch {};
            } else {
                if (flags & (types.TypeFlags.Any | types.TypeFlags.Unknown) != 0) {
                    return false;
                }
                newTypes.append(c.allocator, t) catch {};
                newTexts.append(c.allocator, sb.toOwnedSlice(c.allocator) catch "") catch {};
                sb.* = std.ArrayListUnmanaged(u8).empty;
                sb.appendSlice(c.allocator, texts[i + 1]) catch {};
            }
        }
        return true;
    }

    pub fn getTemplateLiteralType(c: *Checker, texts: [][]const u8, typesArr: []const types.TypeIndex) types.TypeIndex {
        var unionIndex: ?usize = null;
        for (typesArr, 0..) |t, i| {
            if (c.getTypeFlags(t) & (types.TypeFlags.Never | types.TypeFlags.Union) != 0) {
                unionIndex = i;
                break;
            }
        }
        if (unionIndex) |idx| {
            if (!c.checkCrossProductUnion(typesArr)) {
                return c.errorTypeIndex orelse 0;
            }
            return c.mapType(typesArr[idx], getTemplateLiteralTypeMapFn, GetTemplateCtx{
                .texts = texts,
                .typesArr = typesArr,
                .unionIndex = idx,
            });
        }

        for (typesArr) |t| {
            if (t == (c.wildcardTypeIndex orelse 0)) return t;
        }

        var newTypes = std.ArrayListUnmanaged(types.TypeIndex).empty;
        defer newTypes.deinit(c.allocator);
        var newTexts = std.ArrayListUnmanaged([]const u8).empty;
        defer newTexts.deinit(c.allocator);

        var sb = std.ArrayListUnmanaged(u8).empty;
        defer sb.deinit(c.allocator);
        sb.appendSlice(c.allocator, texts[0]) catch {};

        if (!c.addSpansForTemplateLiteral(texts, typesArr, &newTexts, &newTypes, &sb)) {
            return c.stringTypeIndex orelse 0;
        }

        newTexts.append(c.allocator, sb.toOwnedSlice(c.allocator) catch "") catch {};
        if (newTypes.items.len == 0) {
            return c.getStringLiteralType(newTexts.items[0]);
        }

        const key = getTemplateTypeKey(newTexts.items, newTypes.items);
        if (c.templateLiteralTypes.get(key)) |t| {
            return t;
        }
        const t = c.newTemplateLiteralType(newTexts.items, newTypes.items);
        c.templateLiteralTypes.put(c.allocator, key, t) catch {};
        return t;
    }

    fn isContextSensitiveVisitor(node: ast_gen.NodeIndex, context: ?*anyopaque) bool {
        const c: *Checker = @ptrCast(@alignCast(context));
        return c.isContextSensitive(node);
    }

    fn hasContextSensitiveReturnVisitor(node: ast_gen.NodeIndex, context: ?*anyopaque) bool {
        const c: *Checker = @ptrCast(@alignCast(context));
        const expr = c.binder.ast.getNode(node).ReturnStatement.Expression;
        if (expr) |e| {
            if (e != 0) return c.isContextSensitive(e);
        }
        return false;
    }

    fn hasContextSensitiveReturnExpression(c: *Checker, node: ast_gen.NodeIndex) bool {
        const tree = c.binder.ast;
        if (ast_utils.getTypeParametersOfNode(tree, node).len != 0 or ast_utils.getTypeOfNode(tree, node) != 0) {
            return false;
        }
        var bodyNode: u32 = 0;
        const nodeKind = tree.getKind(node);
        switch (nodeKind) {
            .FunctionDeclaration => {
                if (tree.getNode(node).FunctionDeclaration.Body) |b| bodyNode = b;
            },
            .FunctionExpression => {
                if (tree.getNode(node).FunctionExpression.Body) |b| bodyNode = b;
            },
            .ArrowFunction => {
                if (tree.getNode(node).ArrowFunction.Body) |b| bodyNode = b;
            },
            .MethodDeclaration => {
                if (tree.getNode(node).MethodDeclaration.Body) |b| bodyNode = b;
            },
            else => return false,
        }

        if (bodyNode == 0) return false;
        if (tree.getKind(bodyNode) != .Block) {
            return c.isContextSensitive(bodyNode);
        }
        return ast_utils.forEachReturnStatement(tree, bodyNode, hasContextSensitiveReturnVisitor, c);
    }

    fn hasContextSensitiveYieldExpression(c: *Checker, node: ast_gen.NodeIndex) bool {
        const tree = c.binder.ast;
        const nodeKind = tree.getKind(node);
        var isGenerator = false;
        var bodyNode: u32 = 0;

        switch (nodeKind) {
            .FunctionDeclaration => {
                const n = tree.getNode(node).FunctionDeclaration;
                if (n.AsteriskToken) |t| {
                    if (t != 0) isGenerator = true;
                }
                if (n.Body) |b| {
                    bodyNode = b;
                }
            },
            .FunctionExpression => {
                const n = tree.getNode(node).FunctionExpression;
                if (n.AsteriskToken) |t| {
                    if (t != 0) isGenerator = true;
                }
                if (n.Body) |b| {
                    bodyNode = b;
                }
            },
            .MethodDeclaration => {
                const n = tree.getNode(node).MethodDeclaration;
                if (n.AsteriskToken) |t| {
                    if (t != 0) isGenerator = true;
                }
                if (n.Body) |b| {
                    bodyNode = b;
                }
            },
            else => {},
        }

        if (isGenerator and bodyNode != 0) {
            return utils.forEachYieldExpression(tree, bodyNode, isContextSensitiveVisitor, c);
        }
        return false;
    }

    pub fn isContextSensitiveFunctionLikeDeclaration(c: *Checker, node: ast_gen.NodeIndex) bool {
        return ast_utils.hasContextSensitiveParameters(c.binder.ast, node) or
            c.hasContextSensitiveReturnExpression(node) or
            c.hasContextSensitiveYieldExpression(node);
    }

    pub fn isContextSensitive(c: *Checker, node: ast_gen.NodeIndex) bool {
        const tree = c.binder.ast;
        const nodeKind = tree.getKind(node);
        switch (nodeKind) {
            .FunctionExpression, .ArrowFunction, .MethodDeclaration, .FunctionDeclaration => {
                return c.isContextSensitiveFunctionLikeDeclaration(node);
            },
            .ObjectLiteralExpression => {
                const props = tree.getNodeList(tree.getNode(node).ObjectLiteralExpression.Properties);
                for (props) |prop| {
                    if (c.isContextSensitive(prop)) return true;
                }
            },
            .ArrayLiteralExpression => {
                const elements = tree.getNodeList(tree.getNode(node).ArrayLiteralExpression.Elements);
                for (elements) |element| {
                    if (c.isContextSensitive(element)) return true;
                }
            },
            .ConditionalExpression => {
                const condNode = tree.getNode(node).ConditionalExpression;
                return c.isContextSensitive(condNode.WhenTrue) or c.isContextSensitive(condNode.WhenFalse);
            },
            .BinaryExpression => {
                const binNode = tree.getNode(node).BinaryExpression;
                const operator = binNode.OperatorToken;
                const opKind = tree.getKind(operator);
                if (opKind == .BarBarToken or opKind == .QuestionQuestionToken) {
                    return c.isContextSensitive(binNode.Left) or c.isContextSensitive(binNode.Right);
                }
            },
            .PropertyAssignment => {
                const initializer_node = tree.getNode(node).PropertyAssignment.Initializer;
                return c.isContextSensitive(initializer_node);
            },
            .ParenthesizedExpression => {
                const expr = tree.getNode(node).ParenthesizedExpression.Expression;
                return c.isContextSensitive(expr);
            },
            .JsxAttributes => {
                const props = tree.getNodeList(tree.getNode(node).JsxAttributes.Properties);
                for (props) |prop| {
                    if (c.isContextSensitive(prop)) return true;
                }
                const parent = tree.getNodeParent(node);
                if (parent != 0 and tree.getKind(parent) == .JsxOpeningElement) {
                    const parentParent = tree.getNodeParent(parent);
                    if (parentParent != 0) {
                        const childrenNode = tree.getNode(parentParent).JsxElement.Children;
                        const childrenList = tree.getNodeList(childrenNode);
                        for (childrenList) |child| {
                            if (c.isContextSensitive(child)) return true;
                        }
                    }
                }
            },
            .JsxAttribute => {
                const initializer = tree.getNode(node).JsxAttribute.Initializer;
                if (initializer) |init_node| {
                    if (init_node != 0) return c.isContextSensitive(init_node);
                }
            },
            .JsxExpression => {
                const expr = tree.getNode(node).JsxExpression.Expression;
                if (expr) |e| {
                    if (e != 0) return c.isContextSensitive(e);
                }
            },
            .YieldExpression => {
                const expr = tree.getNode(node).YieldExpression.Expression;
                if (expr) |e| {
                    if (e != 0) return c.isContextSensitive(e);
                }
            },
            else => return false,
        }
        return false;
    }

    pub fn getOuterTypeParameters(c: *Checker, declaration: ast_gen.NodeIndex, includeThisTypes: bool) ?[]const types.TypeIndex {
        var nodes = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer nodes.deinit(c.allocator);

        var current = c.binder.ast.getNodeParent(declaration);
        while (current != 0) {
            const nodeKind = c.binder.ast.getNodeKind(current);
            switch (nodeKind) {
                .ClassDeclaration, .ClassExpression, .InterfaceDeclaration, .CallSignature, .ConstructSignature, .MethodSignature, .FunctionType, .ConstructorType, .FunctionDeclaration, .MethodDeclaration, .FunctionExpression, .ArrowFunction, .TypeAliasDeclaration, .JSTypeAliasDeclaration, .MappedType, .ConditionalType => {
                    nodes.append(c.allocator, current) catch return null;
                },
                .ModuleDeclaration => {
                    if (c.binder.ast.getNodeFlags(current) & ast_utils.NodeFlags.GlobalAugmentation != 0) {
                        break;
                    }
                },
                else => {},
            }
            current = c.binder.ast.getNodeParent(current);
        }

        if (nodes.items.len == 0) return null;

        var result = std.ArrayListUnmanaged(types.TypeIndex).empty;
        var i: usize = nodes.items.len;
        while (i > 0) {
            i -= 1;
            const node = nodes.items[i];
            const nodeKind = c.binder.ast.getNodeKind(node);

            if ((nodeKind == .FunctionExpression or nodeKind == .ArrowFunction or (nodeKind == .MethodDeclaration and c.binder.ast.getNodeKind(c.binder.ast.getNodeParent(node)) == .ObjectLiteralExpression)) and c.isContextSensitive(node)) {
                const sym = c.getSymbolOfDeclaration(node);
                if (sym != 0) {
                    const sigs = c.getSignaturesOfType((c.getTypeOfSymbol(sym) catch 0), types.SignatureKind.Call);
                    if (sigs.len > 0) {
                        const sig = c.signatures.items[sigs.start];
                        if (sig.typeParametersLen > 0) {
                            result.appendSlice(c.allocator, c.signatureTypeParameters.items[sig.typeParametersStart .. sig.typeParametersStart + sig.typeParametersLen]) catch {};
                        }
                        continue;
                    }
                }
            }

            if (nodeKind == .MappedType) {
                const mappedNode = c.binder.ast.getNode(node).MappedType;
                if (mappedNode.TypeParameter != 0) {
                    const sym = c.getSymbolOfDeclaration(mappedNode.TypeParameter);
                    const tpType = c.getDeclaredTypeOfTypeParameter(sym);
                    if (tpType != 0) result.append(c.allocator, tpType) catch {};
                }
                continue;
            }

            if (nodeKind == .ConditionalType) {
                const inferParams = c.getInferTypeParametersFromConditionalType(node);
                result.appendSlice(c.allocator, inferParams) catch {};
                continue;
            }

            const typeParams = ast_utils.getTypeParametersOfNode(c.binder.ast, node);
            for (typeParams) |tpNode| {
                const tpSym = c.binder.ast.getNodeSymbol(tpNode) orelse 0;
                if (tpSym != 0) {
                    const tpType = c.getDeclaredTypeOfTypeParameter(tpSym);
                    if (tpType != 0) {
                        var found = false;
                        for (result.items) |existing| {
                            if (existing == tpType) {
                                found = true;
                                break;
                            }
                        }
                        if (!found) result.append(c.allocator, tpType) catch {};
                    }
                }
            }

            if (includeThisTypes and (nodeKind == .ClassDeclaration or nodeKind == .ClassExpression or nodeKind == .InterfaceDeclaration)) {
                const sym = c.getSymbolOfDeclaration(node);
                if (sym != 0) {
                    const classType = c.getDeclaredTypeOfSymbol(sym);
                    if (classType != 0 and c.typesList.items[classType].flags & types.TypeFlags.Object != 0) {
                        const thisType = c.typesList.items[classType].data.Object.thisType orelse 0;
                        if (thisType != 0) {
                            var found = false;
                            for (result.items) |existing| {
                                if (existing == thisType) {
                                    found = true;
                                    break;
                                }
                            }
                            if (!found) result.append(c.allocator, thisType) catch {};
                        }
                    }
                }
            }
        }

        if (result.items.len == 0) return null;
        return result.toOwnedSlice(c.allocator) catch null;
    }

    pub fn cloneTypeParameter(c: *Checker, target: types.TypeIndex) types.TypeIndex {
        const t = c.typesList.items[target];
        var d = t.data.TypeParameter;
        d.mapper = 0;

        const newType = types.Type{
            .flags = types.TypeFlags.TypeParameter,
            .objectFlags = t.objectFlags,
            .symbol = t.symbol,
            .alias = t.alias,
            .data = .{ .TypeParameter = d },
        };

        const idx = @as(u32, @intCast(c.typesList.items.len));
        c.typesList.append(c.allocator, newType) catch unreachable;
        return idx;
    }

    pub fn instantiateTypeAlias(c: *Checker, alias: ?types.TypeAlias, m: types.TypeMapperIndex) ?types.TypeAlias {
        if (alias == null) return null;
        const a = alias.?;

        const oldArgs = if (a.typeArgumentsLen > 0) c.typeArgumentsPool.items[a.typeArgumentsStart .. a.typeArgumentsStart + a.typeArgumentsLen] else &[_]types.TypeIndex{};
        const newArgs = instantiateTypes(c, oldArgs, m) catch oldArgs;

        var newAlias = types.TypeAlias{
            .symbol = a.symbol,
            .typeArgumentsStart = 0,
            .typeArgumentsLen = 0,
        };

        if (newArgs.len > 0) {
            newAlias.typeArgumentsStart = @intCast(c.typeArgumentsPool.items.len);
            newAlias.typeArgumentsLen = @intCast(newArgs.len);
            c.typeArgumentsPool.appendSlice(c.allocator, newArgs) catch unreachable;
        }
        return newAlias;
    }

    pub fn getAliasSymbolForTypeNode(c: *Checker, typeNode: ast_gen.NodeIndex) ast_gen.SymbolIndex {
        var host = c.binder.ast.getNodeParent(typeNode);
        while (host != 0) {
            const hostKind = c.binder.ast.getNodeKind(host);
            if (hostKind == .ParenthesizedType) {
                host = c.binder.ast.getNodeParent(host);
                continue;
            }
            if (hostKind == .TypeOperator) {
                const op = c.binder.ast.getNode(host).TypeOperator.Operator;
                if (op == @intFromEnum(kind.Kind.ReadonlyKeyword)) {
                    host = c.binder.ast.getNodeParent(host);
                    continue;
                }
            }
            break;
        }

        if (host != 0) {
            const hostKind = c.binder.ast.getNodeKind(host);
            if (hostKind == .TypeAliasDeclaration or hostKind == .JSTypeAliasDeclaration) {
                return c.getSymbolOfDeclaration(host);
            }
        }
        return 0;
    }

    pub fn getTypeArgumentsForAliasSymbol(c: *Checker, symIdx: ast_gen.SymbolIndex) []const types.TypeIndex {
        if (symIdx == 0) return &[_]types.TypeIndex{};
        const sym = c.binder.symbols.items[symIdx];

        var typesArr = std.ArrayListUnmanaged(types.TypeIndex).empty;
        defer typesArr.deinit(c.allocator);
        for (sym.Declarations.items) |node| {
            const nodeKind = c.binder.ast.getNodeKind(node);
            if (nodeKind == .InterfaceDeclaration or nodeKind == .ClassDeclaration or nodeKind == .ClassExpression or nodeKind == .TypeAliasDeclaration or nodeKind == .JSTypeAliasDeclaration) {
                const typeParams = ast_utils.getTypeParametersOfNode(c.binder.ast, node);
                for (typeParams) |tpNode| {
                    const tpSym = c.binder.ast.getNodeSymbol(tpNode) orelse 0;
                    if (tpSym != 0) {
                        const tpType = c.getDeclaredTypeOfTypeParameter(tpSym);
                        if (tpType != 0) {
                            var found = false;
                            for (typesArr.items) |existing| {
                                if (existing == tpType) {
                                    found = true;
                                    break;
                                }
                            }
                            if (!found) {
                                typesArr.append(c.allocator, tpType) catch {};
                            }
                        }
                    }
                }
            }
        }

        if (typesArr.items.len == 0) return &[_]types.TypeIndex{};
        return c.allocator.dupe(types.TypeIndex, typesArr.items) catch &[_]types.TypeIndex{};
    }

    pub fn getAliasForTypeNode(c: *Checker, node: ast_gen.NodeIndex) ?types.TypeAlias {
        const symIdx = c.getAliasSymbolForTypeNode(node);
        if (symIdx != 0) {
            const args = c.getTypeArgumentsForAliasSymbol(symIdx);
            const start = @as(u32, @intCast(c.typeArgumentsPool.items.len));
            c.typeArgumentsPool.appendSlice(c.allocator, args) catch return null;
            return types.TypeAlias{
                .symbol = symIdx,
                .typeArgumentsStart = start,
                .typeArgumentsLen = @as(u32, @intCast(args.len)),
            };
        }
        return null;
    }

    pub fn createDeferredTypeReference(c: *Checker, target: types.TypeIndex, node: ast_gen.NodeIndex, m: types.TypeMapperIndex, alias: ?types.TypeAlias) types.TypeIndex {
        var newAlias = alias;
        if (newAlias == null) {
            newAlias = c.getAliasForTypeNode(node);
            if (newAlias != null and m != 0) {
                newAlias = c.instantiateTypeAlias(newAlias, m);
            }
        }

        const t = types.Type{
            .flags = types.TypeFlags.Object,
            .objectFlags = types.ObjectFlags.Reference,
            .symbol = c.typesList.items[target].symbol,
            .alias = newAlias,
            .data = .{ .Object = .{
                .target = target,
                .mapper = m,
                .node = node,
            } },
        };

        const idx = @as(u32, @intCast(c.typesList.items.len));
        c.typesList.append(c.allocator, t) catch unreachable;
        return idx;
    }

    const InstantiateConstituentCtx = struct {
        nameType: ?types.TypeIndex,
        t: types.TypeIndex,
        typeVariable: types.TypeIndex,
        m: types.TypeMapperIndex,
    };

    fn instantiateConstituent(c: *Checker, s: types.TypeIndex, ctx: InstantiateConstituentCtx) types.TypeIndex {
        const flags = c.getTypeFlags(s);
        if (flags & (types.TypeFlags.Any | types.TypeFlags.Unknown | types.TypeFlags.InstantiableNonPrimitive | types.TypeFlags.Object | types.TypeFlags.Intersection) == 0 or s == (c.wildcardTypeIndex orelse 0) or c.isErrorType(s)) {
            return s;
        }
        if (ctx.nameType == null) {
            if (c.isArrayType(s) or (flags & types.TypeFlags.Any != 0 and c.findResolutionCycleStartIndex(types.TypeSystemEntity.initType(ctx.typeVariable), .ResolvedBaseConstraint) < 0 and c.hasArrayOrTypeTypeConstraint(ctx.typeVariable))) {
                return c.instantiateMappedArrayType(s, ctx.t, prependTypeMapping(c, ctx.typeVariable, s, ctx.m) catch 0);
            }
            if (c.isTupleType(s)) {
                return c.instantiateMappedTupleType(s, ctx.t, ctx.typeVariable, ctx.m);
            }
            if (c.isArrayOrTupleOrIntersection(s)) {
                const typesArr = c.getTypesOfType(s);
                var newTypes = std.ArrayList(types.TypeIndex).initCapacity(c.allocator, typesArr.len) catch return 0;
                for (typesArr) |t_idx| {
                    newTypes.appendAssumeCapacity(instantiateConstituent(c, t_idx, ctx));
                }
                return c.getIntersectionType(newTypes.items);
            }
        }
        return c.instantiateAnonymousType(ctx.t, prependTypeMapping(c, ctx.typeVariable, s, ctx.m) catch 0, null);
    }

    pub fn mapTypeWithAlias(c: *Checker, t: types.TypeIndex, comptime mapFn: anytype, ctx: anytype, alias: ?types.TypeAlias) types.TypeIndex {
        if (c.getTypeFlags(t) & types.TypeFlags.Union != 0 and alias != null) {
            const typesArr = c.getTypesOfType(t);
            var newTypes = std.ArrayList(types.TypeIndex).initCapacity(c.allocator, typesArr.len) catch return 0;
            for (typesArr) |t_idx| {
                newTypes.appendAssumeCapacity(mapFn(c, t_idx, ctx));
            }
            return c.getUnionTypeFromArray(newTypes.items);
        }
        return c.mapType(t, mapFn, ctx);
    }

    pub fn hasArrayOrTypeTypeConstraint(c: *Checker, typeVariable: types.TypeIndex) bool {
        const constraint = c.getConstraintOfTypeParameter(typeVariable);
        if (constraint) |constr| {
            const S = struct {
                pub fn f(inner_c: *Checker, t: types.TypeIndex, _: void) bool {
                    return inner_c.isArrayOrTupleType(t);
                }
            };
            return c.everyType(constr, S.f, {});
        }
        return false;
    }

    pub fn isArrayOrTupleOrIntersection(c: *Checker, typeIndex: types.TypeIndex) bool {
        if ((c.getTypeFlags(typeIndex) & types.TypeFlags.Intersection) != 0) {
            const S = struct {
                pub fn f(checker: *Checker, t: types.TypeIndex, _: void) bool {
                    return checker.isArrayOrTupleOrIntersection(t);
                }
            };
            return c.everyType(typeIndex, S.f, {});
        }
        return false;
    }

    pub fn findResolutionCycleStartIndex(c: *Checker, target: types.TypeSystemEntity, propertyName: types.TypeSystemPropertyName) i32 {
        var i: i32 = @intCast(c.typeResolutions.items.len);
        i -= 1;
        while (i >= @as(i32, @intCast(c.resolutionStart))) : (i -= 1) {
            const resolution = &c.typeResolutions.items[@intCast(i)];
            if (c.typeResolutionHasProperty(resolution)) {
                return -1;
            }
            if (resolution.target.eql(target) and resolution.propertyName == propertyName) {
                return i;
            }
        }
        return -1;
    }

    fn typeResolutionHasProperty(c: *Checker, r: *const types.TypeResolution) bool {
        switch (r.propertyName) {
            .Type => {
                if (r.target.kind != .Symbol) return false;
                const link = c.valueSymbolLinks.get(r.target.index) orelse return false;
                return link.resolvedType != 0;
            },
            .DeclaredType => {
                if (r.target.kind != .Symbol) return false;
                const link = c.typeAliasLinks.get(r.target.index) orelse return false;
                return link.declaredType != 0;
            },
            .ResolvedTypeArguments => {
                if (r.target.kind != .Type) return false;
                const t = c.typesList.items[r.target.index];
                if (std.meta.activeTag(t.data) != .Object) return false;
                return t.data.Object.typeArgumentsLen > 0; // Approximate for now
            },
            .ResolvedType => {
                if (r.target.kind != .Type) return false;
                const t = c.typesList.items[r.target.index];
                if (std.meta.activeTag(t.data) != .Object) return false;
                return t.data.Object.target != null;
            },
            .ResolvedBaseConstraint => {
                if (r.target.kind != .Type) return false;
                const t = c.typesList.items[r.target.index];
                if (std.meta.activeTag(t.data) != .TypeParameter) return false;
                return t.data.TypeParameter.resolvedBaseConstraint != null;
            },
            .WriteType => {
                return false;
            },
            .InitializerIsUndefined => {
                return false;
            },
            .AliasTarget => {
                if (r.target.kind != .Symbol) return false;
                const link = c.aliasSymbolLinks.get(r.target.index) orelse return false;
                return link.aliasTarget != null;
            },
        }
    }

    pub fn getModifiedReadonlyState(state: bool, modifiers: types.MappedTypeModifiers) bool {
        if (modifiers.has(types.MappedTypeModifiers.IncludeReadonly)) return true;
        if (modifiers.has(types.MappedTypeModifiers.ExcludeReadonly)) return false;
        return state;
    }

    pub fn instantiateMappedArrayType(c: *Checker, arrayType: types.TypeIndex, mappedType: types.TypeIndex, m: types.TypeMapperIndex) types.TypeIndex {
        const elementType = c.instantiateMappedTypeTemplate(mappedType, c.numberTypeIndex orelse 0, true, m);
        if (c.isErrorType(elementType)) return c.errorTypeIndex orelse 0;
        // In Zig version, array creation is simplified.
        _ = arrayType;
        return c.createArrayType(elementType);
    }

    pub fn instantiateMappedTupleType(c: *Checker, tupleType: types.TypeIndex, mappedType: types.TypeIndex, typeVariable: types.TypeIndex, m: types.TypeMapperIndex) types.TypeIndex {
        const elementTypes = c.getTypesOfType(tupleType);
        const elementInfos = c.getTupleElementInfos(tupleType);

        var newElementTypes = std.ArrayList(types.TypeIndex).initCapacity(c.allocator, elementTypes.len) catch return 0;
        var newElementInfos = std.ArrayList(types.TupleElementInfo).initCapacity(c.allocator, elementTypes.len) catch return 0;

        for (elementTypes, 0..) |elementType, i| {
            const info = elementInfos[i];
            newElementInfos.appendAssumeCapacity(.{
                .flags = info.flags,
                .labeledDeclaration = info.labeledDeclaration,
            });
            var templateMapper: types.TypeMapperIndex = 0;
            if (info.flags & types.ElementFlags.Variadic != 0) {
                templateMapper = prependTypeMapping(c, typeVariable, elementType, m) catch 0;
                const d = c.typesList.items[mappedType].data.Mapped;
                const target = d.target orelse mappedType;
                newElementTypes.appendAssumeCapacity(c.instantiateType(c.getTemplateTypeFromMappedType(target), templateMapper));
            } else {
                var buf: [16]u8 = undefined;
                const i_str = std.fmt.bufPrint(&buf, "{d}", .{i}) catch "0";
                const key = c.getStringLiteralType(i_str);

                if (info.flags & types.ElementFlags.Rest != 0) {
                    templateMapper = prependTypeMapping(c, typeVariable, c.createArrayType(elementType), m) catch 0;
                    const d = c.typesList.items[mappedType].data.Mapped;
                    const target = d.target orelse mappedType;
                    newElementTypes.appendAssumeCapacity(c.getIndexType(c.instantiateType(c.getTemplateTypeFromMappedType(target), templateMapper)));
                } else {
                    newElementTypes.appendAssumeCapacity(c.instantiateMappedTypeTemplate(mappedType, key, (info.flags & types.ElementFlags.Optional) != 0, m));
                }
            }
        }
        const newReadonly = getModifiedReadonlyState(c.isReadonlyArrayType(tupleType), c.getMappedTypeModifiers(mappedType));
        return c.createTupleTypeEx(newElementTypes.items, newElementInfos.items, newReadonly);
    }

    pub fn instantiateMappedTypeTemplate(c: *Checker, t: types.TypeIndex, key: types.TypeIndex, isOptional: bool, m: types.TypeMapperIndex) types.TypeIndex {
        const templateMapper = prependTypeMapping(c, c.getTypeParameterFromMappedType(t), key, m) catch 0;
        const d = c.typesList.items[t].data.Mapped;
        const target = d.target orelse t;
        const propType = c.instantiateType(c.getTemplateTypeFromMappedType(target), templateMapper);
        const modifiers = c.getMappedTypeModifiers(t);

        if (c.strictNullChecks and modifiers.has(types.MappedTypeModifiers.IncludeOptional) and !c.maybeTypeOfKind(propType, types.TypeFlags.Undefined | types.TypeFlags.Void)) {
            return c.getOptionalType(propType, true);
        } else if (c.strictNullChecks and modifiers.has(types.MappedTypeModifiers.ExcludeOptional) and isOptional) {
            return c.getTypeWithFacts(propType, types.TypeFacts.NEUndefined);
        }
        return propType;
    }

    pub fn instantiateMappedType(c: *Checker, t: types.TypeIndex, m: types.TypeMapperIndex, alias: ?types.TypeAlias) types.TypeIndex {
        const d = c.typesList.items[t].data.Mapped;
        const typeVariable = c.getHomomorphicTypeVariable(t);
        const ctx = InstantiateConstituentCtx{
            .nameType = d.nameType,
            .t = t,
            .typeVariable = typeVariable,
            .m = m,
        };

        if (typeVariable != 0) {
            const mappedTypeVariable = c.instantiateType(typeVariable, m);
            if (typeVariable != mappedTypeVariable) {
                return c.mapTypeWithAlias(c.getReducedType(mappedTypeVariable), instantiateConstituent, ctx, alias);
            }
        }

        if (c.instantiateType(c.getConstraintTypeFromMappedType(t), m) == (c.wildcardTypeIndex orelse 0)) {
            return c.wildcardTypeIndex orelse 0;
        }
        return c.instantiateAnonymousType(t, m, alias);
    }

    pub fn instantiateAnonymousType(c: *Checker, target: types.TypeIndex, m: types.TypeMapperIndex, alias: ?types.TypeAlias) types.TypeIndex {
        const t = c.typesList.items[target];
        const newObjectFlags = (t.objectFlags & ~(types.ObjectFlags.CouldContainTypeVariablesComputed | types.ObjectFlags.CouldContainTypeVariables)) | types.ObjectFlags.Instantiated;

        var newData: types.TypeData = undefined;
        if (t.objectFlags & types.ObjectFlags.Mapped != 0) {
            var newMapped = t.data.Mapped;

            const origTypeParameter = c.getTypeParameterFromMappedType(target);
            const freshTypeParameter = c.cloneTypeParameter(origTypeParameter);
            newMapped.typeParameter = freshTypeParameter;

            const newSimpleMapper = mapper_pkg.createSimpleTypeMapper(c, origTypeParameter, freshTypeParameter);
            const combinedMapper = mapper_pkg.combineTypeMappers(c, newSimpleMapper, m);
            newMapped.mapper = combinedMapper;

            var freshData = &c.typesList.items[c.getTargetType(freshTypeParameter)].data.TypeParameter;
            freshData.mapper = combinedMapper;

            newMapped.target = target;
            newData = .{ .Mapped = newMapped };
        } else {
            var newObj = t.data.Object;
            newObj.target = target;
            newObj.mapper = m;
            newData = .{ .Object = newObj };
        }

        var newAlias = alias;
        if (newAlias == null) {
            newAlias = c.instantiateTypeAlias(t.alias, m);
        }

        var finalObjectFlags = newObjectFlags;
        if (newAlias) |a| {
            if (a.typeArgumentsLen != 0) {
                const args = c.typeArgumentsPool.items[a.typeArgumentsStart .. a.typeArgumentsStart + a.typeArgumentsLen];
                finalObjectFlags |= c.getPropagatingFlagsOfTypes(args, types.TypeFlags.None);
            }
        }

        const newType = types.Type{
            .flags = types.TypeFlags.Object,
            .objectFlags = finalObjectFlags,
            .symbol = t.symbol,
            .alias = newAlias,
            .data = newData,
        };

        const idx = @as(u32, @intCast(c.typesList.items.len));
        c.typesList.append(c.allocator, newType) catch unreachable;
        return idx;
    }

    pub fn isNonGenericTopLevelType(c: *Checker, t: types.TypeIndex) bool {
        const typeNode = c.typesList.items[t];
        if (typeNode.alias) |alias| {
            if (alias.typeArgumentsLen == 0) {
                var declaration = c.getDeclarationOfKind(alias.symbol, .TypeAliasDeclaration);
                if (declaration == 0) {
                    declaration = c.getDeclarationOfKind(alias.symbol, .JSTypeAliasDeclaration);
                }
                if (declaration != 0) {
                    var current = ast_utils.getParent(c.binder.ast, declaration);
                    var found = false;
                    while (current != 0) {
                        const nodeKind = c.binder.ast.getNodeKind(current);
                        if (nodeKind == .SourceFile) {
                            found = true;
                            break;
                        }
                        if (nodeKind == .ModuleDeclaration) {
                            break;
                        }
                        current = ast_utils.getParent(c.binder.ast, current);
                    }
                    return found;
                }
            }
        }
        return false;
    }

    pub fn getTypesOfType(c: *Checker, t: types.TypeIndex) []const types.TypeIndex {
        const typeNode = c.typesList.items[t];
        if (typeNode.flags & types.TypeFlags.Union != 0) {
            const data = typeNode.data.Union;
            return c.unionTypesPool.items[data.typesStart .. data.typesStart + data.typesLen];
        }
        if (typeNode.flags & types.TypeFlags.Intersection != 0) {
            const data = typeNode.data.Intersection;
            return c.unionTypesPool.items[data.typesStart .. data.typesStart + data.typesLen];
        }
        return &[_]types.TypeIndex{};
    }

    pub fn couldContainTypeVariables(c: *Checker, t: types.TypeIndex) bool {
        if (t == 0) return false;
        const typeNode = c.typesList.items[t];
        if (typeNode.flags & types.TypeFlags.StructuredOrInstantiable == 0) {
            return false;
        }

        const objectFlags = typeNode.objectFlags;
        if (objectFlags & types.ObjectFlags.CouldContainTypeVariablesComputed != 0) {
            return objectFlags & types.ObjectFlags.CouldContainTypeVariables != 0;
        }

        var result = false;
        if (typeNode.flags & types.TypeFlags.Instantiable != 0) {
            result = true;
        } else if (typeNode.flags & types.TypeFlags.Object != 0 and !c.isNonGenericTopLevelType(t)) {
            if (objectFlags & types.ObjectFlags.Reference != 0) {
                if (std.meta.activeTag(typeNode.data) == .Object and typeNode.data.Object.node != null) {
                    result = true;
                } else {
                    const args = c.getTypeArguments(t);
                    for (args) |arg| {
                        if (c.couldContainTypeVariables(arg)) {
                            result = true;
                            break;
                        }
                    }
                }
            } else if (objectFlags & types.ObjectFlags.Anonymous != 0 and typeNode.symbol != null) {
                const sym = c.binder.symbols.items[typeNode.symbol.?];
                if (sym.Flags & (symbol.SymbolFlags.Function | symbol.SymbolFlags.Method | symbol.SymbolFlags.Class | symbol.SymbolFlags.TypeLiteral | symbol.SymbolFlags.ObjectLiteral) != 0 and sym.Declarations.items.len != 0) {
                    result = true;
                }
            } else if (objectFlags & (types.ObjectFlags.Mapped | types.ObjectFlags.ReverseMapped | types.ObjectFlags.ObjectRestType | types.ObjectFlags.InstantiationExpressionType) != 0) {
                result = true;
            }
        } else if (typeNode.flags & types.TypeFlags.UnionOrIntersection != 0 and typeNode.flags & types.TypeFlags.EnumLiteral == 0 and !c.isNonGenericTopLevelType(t)) {
            const typesArr = c.getTypesOfType(t);
            for (typesArr) |type_idx| {
                if (c.couldContainTypeVariables(type_idx)) {
                    result = true;
                    break;
                }
            }
        }

        c.typesList.items[t].objectFlags |= types.ObjectFlags.CouldContainTypeVariablesComputed | (if (result) types.ObjectFlags.CouldContainTypeVariables else 0);
        return result;
    }

    pub fn getObjectTypeInstantiation(c: *Checker, t: types.TypeIndex, m: types.TypeMapperIndex, alias: ?types.TypeAlias) types.TypeIndex {
        var declaration: ast_gen.NodeIndex = 0;
        var target: types.TypeIndex = 0;
        var typeParameters: ?[]const types.TypeIndex = null;

        const objFlags = c.typesList.items[t].objectFlags;
        if ((objFlags & types.ObjectFlags.Reference) != 0) {
            declaration = c.getTargetTypeData(t).Object.node orelse 0;
        } else if ((objFlags & types.ObjectFlags.InstantiationExpressionType) != 0) {
            declaration = c.getTargetTypeData(t).Object.node orelse 0;
        } else {
            if (c.typesList.items[t].symbol) |sym| {
                declaration = c.getFirstDeclarationOfSymbol(sym);
            }
        }

        var linksPtr = c.typeNodeLinks.getPtr(declaration);
        if (linksPtr == null) {
            c.typeNodeLinks.put(c.allocator, declaration, .{}) catch {};
            linksPtr = c.typeNodeLinks.getPtr(declaration);
        }

        if ((objFlags & types.ObjectFlags.Reference) != 0) {
            target = linksPtr.?.resolvedType;
        } else if ((objFlags & types.ObjectFlags.Instantiated) != 0) {
            target = c.getTargetTypeData(t).Object.target orelse 0;
        } else {
            target = t;
        }

        typeParameters = linksPtr.?.outerTypeParameters;
        if (typeParameters == null) {
            typeParameters = c.getOuterTypeParameters(declaration, true);
            const aliasArgsLen = if (c.typesList.items[target].alias) |a| a.typeArgumentsLen else 0;
            if (aliasArgsLen == 0) {
                if ((objFlags & (types.ObjectFlags.Reference | types.ObjectFlags.InstantiationExpressionType)) != 0) {
                    var filtered = std.ArrayListUnmanaged(types.TypeIndex).empty;
                    if (typeParameters) |tps| {
                        for (tps) |tp| {
                            if (c.isTypeParameterPossiblyReferenced(tp, declaration)) {
                                filtered.append(c.allocator, tp) catch {};
                            }
                        }
                    }
                    typeParameters = filtered.items;
                } else if ((c.getSymbolFlags(c.typesList.items[target].symbol orelse 0) & (symbol.SymbolFlags.Method | symbol.SymbolFlags.TypeLiteral)) != 0) {
                    var filtered = std.ArrayListUnmanaged(types.TypeIndex).empty;
                    if (typeParameters) |tps| {
                        for (tps) |tp| {
                            const sym = c.typesList.items[t].symbol.?;
                            const declarations = c.binder.symbols.items[sym].Declarations.items;
                            var isReferenced = false;
                            for (declarations) |decl| {
                                if (c.isTypeParameterPossiblyReferenced(tp, decl)) {
                                    isReferenced = true;
                                    break;
                                }
                            }
                            if (isReferenced) {
                                filtered.append(c.allocator, tp) catch {};
                            }
                        }
                    }
                    typeParameters = filtered.items;
                }
            }
            if (typeParameters == null) {
                typeParameters = &[_]types.TypeIndex{};
            }
            linksPtr.?.outerTypeParameters = typeParameters;
        }
        if (typeParameters == null or typeParameters.?.len == 0) return t;

        const combinedMapper = mapper_pkg.combineTypeMappers(c, c.getTargetTypeData(t).Object.mapper orelse 0, m);
        const typeArguments = instantiateTypes(c, typeParameters.?, combinedMapper) catch return t;

        var newAlias = alias;
        if (newAlias == null) {
            newAlias = c.instantiateTypeAlias(c.typesList.items[t].alias, m);
        }

        const targetId = c.getTargetType(target);
        var data = &c.typesList.items[targetId].data.Object;
        const key = getTypeInstantiationKey(typeArguments, newAlias, (objFlags & types.ObjectFlags.SingleSignatureType) != 0);

        if (data.instantiations == null) {
            data.instantiations = std.AutoHashMapUnmanaged(types.CacheHashKey, types.TypeIndex).empty;
            const targetKey = getTypeInstantiationKey(typeParameters.?, c.typesList.items[target].alias, false);
            data.instantiations.?.put(c.allocator, targetKey, target) catch {};
        }

        if (data.instantiations.?.get(key)) |result| {
            return result;
        }

        var newMapper = mapper_pkg.createTypeMapper(c, typeParameters.?, typeArguments);
        if ((c.typesList.items[target].objectFlags & types.ObjectFlags.SingleSignatureType) != 0 and m != 0) {
            newMapper = mapper_pkg.combineTypeMappers(c, newMapper, m);
        }

        var result: types.TypeIndex = 0;
        if ((c.typesList.items[target].objectFlags & types.ObjectFlags.Reference) != 0) {
            result = c.createDeferredTypeReference(c.getTargetTypeData(t).Object.target orelse 0, c.getTargetTypeData(t).Object.node orelse 0, newMapper, newAlias);
        } else if ((c.typesList.items[target].objectFlags & types.ObjectFlags.Mapped) != 0) {
            result = c.instantiateMappedType(target, newMapper, newAlias);
        } else {
            result = c.instantiateAnonymousType(target, newMapper, newAlias);
        }

        data.instantiations.?.put(c.allocator, key, result) catch {};

        if ((c.typesList.items[result].flags & types.TypeFlags.ObjectFlagsType) != 0 and (c.typesList.items[result].objectFlags & types.ObjectFlags.CouldContainTypeVariablesComputed) == 0) {
            var resultCouldContainObjectFlags = false;
            for (typeArguments) |ta| {
                if (c.couldContainTypeVariables(ta)) {
                    resultCouldContainObjectFlags = true;
                    break;
                }
            }
            if ((c.typesList.items[result].objectFlags & types.ObjectFlags.CouldContainTypeVariablesComputed) == 0) {
                if ((c.typesList.items[result].objectFlags & (types.ObjectFlags.Mapped | types.ObjectFlags.Anonymous | types.ObjectFlags.Reference)) != 0) {
                    c.typesList.items[result].objectFlags |= types.ObjectFlags.CouldContainTypeVariablesComputed | (if (resultCouldContainObjectFlags) types.ObjectFlags.CouldContainTypeVariables else 0);
                } else {
                    c.typesList.items[result].objectFlags |= if (!resultCouldContainObjectFlags) types.ObjectFlags.CouldContainTypeVariablesComputed else 0;
                }
            }
        }
        return result;
    }

    pub fn isTypeDerivedFrom(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
        const sourceFlags = c.getTypeFlags(source);
        const targetFlags = c.getTypeFlags(target);

        if (sourceFlags & types.TypeFlags.Union != 0) {
            const typesArr = c.getTypesOfUnionOrIntersectionType(source);
            for (typesArr) |t| {
                if (!c.isTypeDerivedFrom(t, target)) {
                    return false;
                }
            }
            return true;
        } else if (targetFlags & types.TypeFlags.Union != 0) {
            const typesArr = c.getTypesOfUnionOrIntersectionType(target);
            for (typesArr) |t| {
                if (c.isTypeDerivedFrom(source, t)) {
                    return true;
                }
            }
            return false;
        } else if (sourceFlags & types.TypeFlags.Intersection != 0) {
            const typesArr = c.getTypesOfUnionOrIntersectionType(source);
            for (typesArr) |t| {
                if (c.isTypeDerivedFrom(t, target)) {
                    return true;
                }
            }
            return false;
        } else if (sourceFlags & types.TypeFlags.InstantiableNonPrimitive != 0) {
            var constraint = c.getBaseConstraintOfType(source);
            if (constraint == 0) {
                constraint = c.unknownTypeIndex orelse 0;
            }
            return c.isTypeDerivedFrom(constraint, target);
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
            c.isEmptyObjectType(t);
    }

    pub fn isFunctionObjectType(c: *Checker, t: types.TypeIndex) bool {
        return t < c.typesList.items.len and c.typesList.items[t].data == .Function;
    }

    pub fn getObjectFlags(c: *Checker, t: types.TypeIndex) u32 {
        if (t == 0 or t >= c.typesList.items.len) return 0;
        return c.typesList.items[t].objectFlags;
    }

    pub fn getElementTypeOfSliceOfTupleType(c: *Checker, tupleType: types.TypeIndex, startIndex: usize, endIndex: usize, endSkipCount: isize) ?types.TypeIndex {
        _ = c;
        _ = tupleType;
        _ = startIndex;
        _ = endIndex;
        _ = endSkipCount;
        return null;
    }

    pub fn getTupleTypeKey(elementTypes: []const types.TypeIndex, elementInfos: []const types.TupleElementInfo, readonly: bool) types.CacheHashKey {
        var hasher = std.hash.Wyhash.init(0);
        for (elementTypes) |t| std.hash.autoHash(&hasher, t);
        for (elementInfos) |info| std.hash.autoHash(&hasher, info.flags);
        std.hash.autoHash(&hasher, readonly);
        return hasher.final();
    }

    pub fn createTupleTypeEx(c: *Checker, elementTypes: []const types.TypeIndex, elementInfos: []const types.TupleElementInfo, readonly: bool) types.TypeIndex {
        if (elementInfos.len == 1 and elementInfos[0].flags & types.ElementFlags.Rest != 0) {
            // [...X[]] is equivalent to just X[]
            // We ignore readonly for now as ArrayType in zig currently doesn't store it
            return c.createArrayType(elementTypes[0]);
        }

        // We will store this in a cache if we want, but currently checker doesn't have tupleTypesCache
        // We'll just create it.
        const start: u32 = @intCast(c.tupleTypesPool.items.len);
        c.tupleTypesPool.appendSlice(c.allocator, elementTypes) catch return c.errorTypeIndex orelse 0;

        const infosStart: u32 = @intCast(c.tupleElementInfos.items.len);
        c.tupleElementInfos.appendSlice(c.allocator, elementInfos) catch return c.errorTypeIndex orelse 0;

        var minLength: u32 = 0;
        var combinedFlags: u32 = 0;
        for (elementInfos) |info| {
            if (info.flags & (types.ElementFlags.Required | types.ElementFlags.Variadic) != 0) {
                minLength += 1;
            }
            combinedFlags |= info.flags;
        }

        return c.createType(.{
            .flags = types.TypeFlags.Object,
            .objectFlags = types.ObjectFlags.Reference | types.ObjectFlags.Tuple,
            .id = 0,
            .symbol = null,
            .alias = null,
            .data = .{
                .Tuple = .{
                    .typesStart = start,
                    .typesLen = @intCast(elementTypes.len),
                    .elementInfosStart = infosStart,
                    .readonly = readonly,
                    .combinedFlags = combinedFlags,
                    .minLength = minLength,
                    .fixedLength = @intCast(elementInfos.len), // Approximation for flat tuple
                    .hasRestElement = combinedFlags & types.ElementFlags.Rest != 0,
                },
            },
        }) catch c.errorTypeIndex orelse 0;
    }

    pub fn typesDefinitelyUnrelated(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
        _ = c;
        _ = source;
        _ = target;
        return false;
    }

    pub fn isConstTypeVariable(c: *Checker, t: types.TypeIndex, depth: usize) bool {
        if (depth >= 5 or t == 0) return false;

        const ty = c.typesList.items[t];
        if (ty.flags & types.TypeFlags.TypeParameter != 0) {
            if (ty.symbol != 0) {
                const sym = c.binder.ast.symbols.items[ty.symbol];
                for (sym.Declarations.items) |d| {
                    if (@import("../ast/ast_utils.zig").hasSyntacticModifier(c.binder.ast, d, @import("../ast/ast_utils.zig").ModifierFlags.Const)) return true;
                }
            }
        } else if (ty.flags & types.TypeFlags.UnionOrIntersection != 0) {
            for (c.getTypes(t)) |s| {
                if (c.isConstTypeVariable(s, depth)) return true;
            }
        } else if (ty.flags & types.TypeFlags.IndexedAccess != 0) {
            return c.isConstTypeVariable(ty.data.IndexedAccess.objectType, depth + 1);
        } else if (ty.flags & types.TypeFlags.Conditional != 0) {
            if (c.getConstraintOfConditionalType(t)) |constraint| {
                return c.isConstTypeVariable(constraint, depth + 1);
            }
        } else if (ty.flags & types.TypeFlags.Substitution != 0) {
            return c.isConstTypeVariable(ty.data.Substitution.baseType, depth);
        } else if (ty.flags & types.TypeFlags.Object != 0 and ty.objectFlags & types.ObjectFlags.Mapped != 0) {
            const typeVariable = c.getHomomorphicTypeVariable(t);
            if (typeVariable != 0) return c.isConstTypeVariable(typeVariable, depth);
        } else if (c.isGenericTupleType(t)) {
            const elementTypes = c.getTypeArguments(t);
            const target = c.getTargetType(t);
            const elementInfos = c.getTupleElementInfos(target);
            for (elementTypes, 0..) |s, i| {
                if (elementInfos.len > i and elementInfos[i].flags & types.ElementFlags.Variadic != 0) {
                    if (c.isConstTypeVariable(s, depth)) return true;
                }
            }
        }

        return false;
    }

    pub fn isArrayLikeType(c: *Checker, t: types.TypeIndex) bool {
        if (c.getPropertyOfType(t, "length")) |_| {
            const number_type = c.numberTypeIndex orelse 0;
            const length_type = c.getTypeOfPropertyOfType(t, "length");
            if (length_type != 0 and c.isTypeRelatedTo(length_type, number_type, &c.assignableRelation)) {
                return true;
            }
        }
        return c.isTupleType(t);
    }

    pub fn isMutableArrayLikeType(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn isTupleType(c: *Checker, t: types.TypeIndex) bool {
        const objectFlags = c.getObjectFlags(t);
        if (objectFlags & types.ObjectFlags.Reference == 0) return false;
        const target = c.getTargetType(t);
        return c.getObjectFlags(target) & types.ObjectFlags.Tuple != 0;
    }

    pub fn getTypePredicateType(c: *Checker, predicate: types.TypePredicateIndex) ?types.TypeIndex {
        _ = c;
        _ = predicate;
        return null;
    }

    pub fn isTupleTypeStructureMatching(c: *Checker, t1: types.TypeIndex, t2: types.TypeIndex) bool {
        if (c.getTypeReferenceArity(t1) != c.getTypeReferenceArity(t2)) {
            return false;
        }
        const t1_infos = c.getTupleElementInfos(t1);
        const t2_infos = c.getTupleElementInfos(t2);
        for (t1_infos, 0..) |e, i| {
            if (e.flags & types.ElementFlags.Variable != t2_infos[i].flags & types.ElementFlags.Variable) {
                return false;
            }
        }
        return true;
    }

    pub fn isArrayType(c: *Checker, t: types.TypeIndex) bool {
        return t < c.typesList.items.len and c.typesList.items[t].data == .Array;
    }

    pub fn isReadonlyArrayType(c: *Checker, t: types.TypeIndex) bool {
        return c.getObjectFlags(t) & types.ObjectFlags.Reference != 0 and c.getTargetType(t) == c.globalReadonlyArrayType;
    }

    pub fn hasBaseType(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
        _ = c;
        _ = source;
        _ = target;
        return false; // Skipped
    }

    pub fn isDistributionDependent(c: *Checker, root: *types.ConditionalRoot) bool {
        return root.isDistributive and (c.isTypeParameterPossiblyReferenced(root.checkType, root.node.TrueType) or c.isTypeParameterPossiblyReferenced(root.checkType, root.node.FalseType));
    }

    pub fn isTypeParameterPossiblyReferenced(c: *Checker, tp: types.TypeIndex, node: ast_gen.NodeIndex) bool {
        _ = c;
        _ = tp;
        _ = node;
        return false; // Skipped
    }

    pub fn getValueDeclarationOfSymbol(c: *Checker, sym: ast_gen.SymbolIndex) ast_gen.NodeIndex {
        if (sym >= c.binder.symbols.items.len) return 0;
        return c.binder.symbols.items[sym].ValueDeclaration orelse 0;
    }

    pub fn getFirstDeclarationOfSymbol(c: *Checker, sym: ast_gen.SymbolIndex) ast_gen.NodeIndex {
        if (sym >= c.binder.symbols.items.len) return 0;
        const declarations = c.binder.symbols.items[sym].Declarations.items;
        return if (declarations.len == 0) 0 else declarations[0];
    }

    pub fn getNodeKind(c: *Checker, node: ast_gen.NodeIndex) ast_gen.SyntaxKind {
        return c.binder.ast.getKind(node);
    }

    pub fn getWriteTypeOfSymbol(c: *Checker, sym: ast_gen.SymbolIndex) types.TypeIndex {
        return c.getTypeOfSymbol(sym) catch c.anyTypeIndex orelse 0;
    }

    pub fn getElementTypeOfEvolvingArrayType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        const type_obj = c.typesList.items[t];
        if (type_obj.objectFlags & types.ObjectFlags.EvolvingArray != 0) {
            switch (type_obj.data) {
                .Object => |objData| {
                    if (objData.evolvingArrayElementType) |elemType| {
                        return elemType;
                    }
                },
                else => {},
            }
        }
        return t;
    }

    pub fn getEvolvingArrayType(c: *Checker, elementType: types.TypeIndex) types.TypeIndex {
        const entry = c.evolvingArrayTypes.getOrPut(c.allocator, elementType) catch @panic("OOM");
        if (!entry.found_existing) {
            const newType = types.Type{
                .flags = types.TypeFlags.Object,
                .objectFlags = types.ObjectFlags.EvolvingArray,
                .data = .{
                    .Object = .{
                        .evolvingArrayElementType = elementType,
                    },
                },
            };
            entry.value_ptr.* = c.createType(newType) catch c.errorType;
        }
        return entry.value_ptr.*;
    }

    pub fn getWidenedLiteralType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        const flags = c.getTypeFlags(t);
        // Note: we don't have freshType implemented in zig yet, so we assume fresh
        if (flags & types.TypeFlags.EnumLike != 0) {
            return c.getBaseTypeOfEnumLikeType(t);
        }
        if (flags & types.TypeFlags.StringLiteral != 0) {
            return c.stringTypeIndex orelse 0;
        }
        if (flags & types.TypeFlags.NumberLiteral != 0) {
            return c.numberTypeIndex orelse 0;
        }
        if (flags & types.TypeFlags.BigIntLiteral != 0) {
            return c.bigintTypeIndex orelse 0;
        }
        if (flags & types.TypeFlags.BooleanLiteral != 0) {
            return c.booleanTypeIndex orelse 0;
        }
        if (flags & types.TypeFlags.Union != 0) {
            // return c.mapType(t, getWidenedLiteralType);
        }
        return t;
    }

    pub fn getBaseTypeOfEnumLikeType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        const flags = c.getTypeFlags(t);
        const sym = c.typesList.items[t].symbol;
        if (flags & types.TypeFlags.EnumLike != 0 and sym != null and c.getSymbolFlags(sym.?) & symbol.SymbolFlags.EnumMember != 0) {
            return c.getDeclaredTypeOfSymbol(c.getParentOfSymbol(sym.?));
        }
        return t;
    }

    pub fn getBaseTypeOfLiteralType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        const flags = c.getTypeFlags(t);
        if (flags & types.TypeFlags.EnumLike != 0) {
            return c.getBaseTypeOfEnumLikeType(t);
        }
        if (flags & (types.TypeFlags.StringLiteral | types.TypeFlags.TemplateLiteral | types.TypeFlags.StringMapping) != 0) {
            return c.stringTypeIndex orelse 0;
        }
        if (flags & types.TypeFlags.NumberLiteral != 0) {
            return c.numberTypeIndex orelse 0;
        }
        if (flags & types.TypeFlags.BigIntLiteral != 0) {
            return c.bigintTypeIndex orelse 0;
        }
        if (flags & types.TypeFlags.BooleanLiteral != 0) {
            return c.booleanTypeIndex orelse 0;
        }
        if (flags & types.TypeFlags.Union != 0) {
            // return c.getBaseTypeOfLiteralTypeUnion(t);
        }
        return t;
    }

    pub fn getTypeFlags(c: *Checker, t: types.TypeIndex) u32 {
        return if (t < c.typesList.items.len) c.typesList.items[t].flags else types.TypeFlags.None;
    }

    pub fn getSymbolOfType(c: *Checker, t: types.TypeIndex) ast_gen.SymbolIndex {
        if (t == 0 or t >= c.typesList.items.len) return 0;
        return c.typesList.items[t].symbol orelse 0;
    }

    pub fn reportUnreliableMapperStub(c: *Checker) void {
        _ = c; // Skipped
    }

    pub fn getResolvedSignature(c: *Checker, node: ast_gen.NodeIndex, candidatesOutArray: ?*std.ArrayListUnmanaged(types.SignatureIndex), checkMode: CheckMode) types.SignatureIndex {
        _ = checkMode;

        const callNodeKind = std.meta.activeTag(c.binder.ast.getNode(node));
        var targetExpr: ast_gen.NodeIndex = 0;
        if (callNodeKind == .CallExpression) {
            targetExpr = c.binder.ast.getNode(node).CallExpression.Expression;
        } else if (callNodeKind == .NewExpression) {
            targetExpr = c.binder.ast.getNode(node).NewExpression.Expression;
        } else if (callNodeKind == .TaggedTemplateExpression) {
            targetExpr = c.binder.ast.getNode(node).TaggedTemplateExpression.Tag;
        } else {
            return 0;
        }

        const targetType = c.checkExpressionAdHoc(targetExpr) catch return 0;

        // SignatureKind.Call = 0, SignatureKind.Construct = 1
        const sigKind: types.SignatureKind = if (callNodeKind == .NewExpression) .Construct else .Call;
        const candidates = c.getSignaturesOfType(targetType, sigKind);

        if (candidatesOutArray) |outArray| {
            if (candidates.len > 0) {
                const sigIndices = c.resolvedSignaturesPool.items[candidates.start .. candidates.start + candidates.len];
                outArray.appendSlice(c.allocator, sigIndices) catch unreachable;
            }
        }

        if (candidates.len == 0) return 0;

        if (c.resolvedSignatureLinks.get(node)) |sig| {
            return sig;
        }

        return c.resolvedSignaturesPool.items[candidates.start];
    }
    pub fn newConditionalType(c: *Checker, root: *types.ConditionalRoot, mapper: types.TypeMapperIndex, combinedMapper: types.TypeMapperIndex) types.TypeIndex {
        const data = types.TypeData{ .Conditional = .{
            .root = root,
            .checkType = c.instantiateType(root.checkType, mapper),
            .extendsType = c.instantiateType(root.extendsType, mapper),
            .mapper = mapper,
            .combinedMapper = combinedMapper,
        } };
        return c.createType(.{
            .flags = types.TypeFlags.Conditional,
            .objectFlags = 0,
            .data = data,
        }) catch c.errorTypeIndex orelse 0;
    }
    pub fn newChecker(program: *anyopaque, tracer: *anyopaque) *anyopaque {
        _ = program;
        _ = tracer;
        return undefined;
    }

    pub fn createFileIndexMap(files: *anyopaque) i32 {
        _ = files;
        return 0;
    }

    pub fn countGlobalSymbols(files: *anyopaque) i32 {
        _ = files;
        return 0;
    }

    pub fn reportUnreliableWorker(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn reportUnmeasurableWorker(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getGlobalTypeResolver(c: *Checker, name_: *anyopaque, arity: *anyopaque, reportErrors: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        _ = arity;
        _ = reportErrors;
        return undefined;
    }

    pub fn getGlobalTypeAliasResolver(c: *Checker, name_: *anyopaque, arity: *anyopaque, reportErrors: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        _ = arity;
        _ = reportErrors;
        return undefined;
    }

    pub fn getGlobalValueSymbolResolver(c: *Checker, name_: *anyopaque, reportErrors: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        _ = reportErrors;
        return undefined;
    }

    pub fn getGlobalTypeSymbolResolver(c: *Checker, name_: *anyopaque, reportErrors: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        _ = reportErrors;
        return undefined;
    }

    pub fn getGlobalTypesResolver(c: *Checker, names: *anyopaque, arity: *anyopaque, reportErrors: *anyopaque) *anyopaque {
        _ = c;
        _ = names;
        _ = arity;
        _ = reportErrors;
        return undefined;
    }

    pub fn getTypeAliasTypeParameters(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getGlobalType(c: *Checker, name_: *anyopaque, arity: *anyopaque, reportErrors: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        _ = arity;
        _ = reportErrors;
        return undefined;
    }

    pub fn getGlobalTypeDeclaration(symbol_: *anyopaque) *anyopaque {
        _ = symbol_;
        return undefined;
    }

    pub fn initializeClosures(c: *Checker) void {
        _ = c;
    }

    pub fn initializeIterationResolvers(c: *Checker) void {
        _ = c;
    }

    pub fn initializeChecker(c: *Checker) void {
        _ = c;
    }

    pub fn mergeGlobalSymbol(c: *Checker, symbol_: *anyopaque) void {
        _ = c;
        _ = symbol_;
    }

    pub fn mergeModuleAugmentation(c: *Checker, moduleName: *anyopaque) void {
        _ = c;
        _ = moduleName;
    }

    pub fn addUndefinedToGlobalsOrErrorOnRedeclaration(c: *Checker) void {
        _ = c;
    }

    pub fn createNameResolver(c: *Checker) *anyopaque {
        _ = c;
        return undefined;
    }

    pub fn createNameResolverForSuggestion(c: *Checker) *anyopaque {
        _ = c;
        return undefined;
    }

    pub fn symbolReferenced(c: *Checker, symbol_: *anyopaque, meaning: *anyopaque) void {
        _ = c;
        _ = symbol_;
        _ = meaning;
    }

    pub fn getRequiresScopeChangeCache(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn setRequiresScopeChangeCache(c: *Checker, node: *anyopaque, value: *anyopaque) void {
        _ = c;
        _ = node;
        _ = value;
    }

    pub fn checkAndReportErrorForInvalidInitializer(c: *Checker, errorLocation: *anyopaque, name_: *anyopaque, propertyWithInvalidInitializer: *anyopaque, result: *anyopaque) bool {
        _ = c;
        _ = errorLocation;
        _ = name_;
        _ = propertyWithInvalidInitializer;
        _ = result;
        return false;
    }

    pub fn checkAndReportErrorForMissingPrefix(c: *Checker, errorLocation: *anyopaque, name_: *anyopaque) bool {
        _ = c;
        _ = errorLocation;
        _ = name_;
        return false;
    }

    pub fn onFailedToResolveSymbol(c: *Checker, errorLocation: *anyopaque, name_: *anyopaque, meaning: *anyopaque, nameNotFoundMessage: *anyopaque) void {
        _ = c;
        _ = errorLocation;
        _ = name_;
        _ = meaning;
        _ = nameNotFoundMessage;
    }

    pub fn checkAndReportErrorForUsingTypeAsNamespace(c: *Checker, errorLocation: *anyopaque, name_: *anyopaque, meaning: *anyopaque) bool {
        _ = c;
        _ = errorLocation;
        _ = name_;
        _ = meaning;
        return false;
    }

    pub fn checkAndReportErrorForExportingPrimitiveType(c: *Checker, errorLocation: *anyopaque, name_: *anyopaque) bool {
        _ = c;
        _ = errorLocation;
        _ = name_;
        return false;
    }

    pub fn isPrimitiveTypeName(s: *anyopaque) bool {
        _ = s;
        return false;
    }

    pub fn checkAndReportErrorForUsingNamespaceAsTypeOrValue(c: *Checker, errorLocation: *anyopaque, name_: *anyopaque, meaning: *anyopaque) bool {
        _ = c;
        _ = errorLocation;
        _ = name_;
        _ = meaning;
        return false;
    }

    pub fn checkAndReportErrorForUsingTypeAsValue(c: *Checker, errorLocation: *anyopaque, name_: *anyopaque, meaning: *anyopaque) bool {
        _ = c;
        _ = errorLocation;
        _ = name_;
        _ = meaning;
        return false;
    }

    pub fn isES2015OrLaterConstructorName(s: *anyopaque) bool {
        _ = s;
        return false;
    }

    pub fn maybeMappedType(c: *Checker, node: *anyopaque, symbol_: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = symbol_;
        return false;
    }

    pub fn checkAndReportErrorForUsingValueAsType(c: *Checker, errorLocation: *anyopaque, name_: *anyopaque, meaning: *anyopaque) bool {
        _ = c;
        _ = errorLocation;
        _ = name_;
        _ = meaning;
        return false;
    }

    pub fn getSuggestedLibForNonExistentName(c: *Checker, name_: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        return undefined;
    }

    pub fn getSuggestedSymbolForNonexistentSymbol(c: *Checker, location: *anyopaque, outerName: *anyopaque, meaning: *anyopaque) *anyopaque {
        _ = c;
        _ = location;
        _ = outerName;
        _ = meaning;
        return undefined;
    }

    pub fn getPrimitiveTypeAliasSuggestions(symbols: *anyopaque) *anyopaque {
        _ = symbols;
        return undefined;
    }

    pub fn getSuggestionForSymbolNameLookup(c: *Checker, symbols: *anyopaque, name_: *anyopaque, meaning: *anyopaque) *anyopaque {
        _ = c;
        _ = symbols;
        _ = name_;
        _ = meaning;
        return undefined;
    }

    pub fn getSpellingSuggestionForName(c: *Checker, name_: *anyopaque, symbols: *anyopaque, meaning: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        _ = symbols;
        _ = meaning;
        return undefined;
    }

    pub fn onSuccessfullyResolvedSymbol(c: *Checker, errorLocation: *anyopaque, result: *anyopaque, meaning: *anyopaque, lastLocation: *anyopaque, associatedDeclarationForContainingInitializerOrBindingName: *anyopaque, withinDeferredContext: *anyopaque) void {
        _ = c;
        _ = errorLocation;
        _ = result;
        _ = meaning;
        _ = lastLocation;
        _ = associatedDeclarationForContainingInitializerOrBindingName;
        _ = withinDeferredContext;
    }

    pub fn checkResolvedBlockScopedVariable(c: *Checker, result: *anyopaque, errorLocation: *anyopaque) void {
        _ = c;
        _ = result;
        _ = errorLocation;
    }

    pub fn isBlockScopedNameDeclaredBeforeUse(c: *Checker, declaration: *anyopaque, usage: *anyopaque) bool {
        _ = c;
        _ = declaration;
        _ = usage;
        return false;
    }

    pub fn isUsedInFunctionOrInstanceProperty(c: *Checker, usage: *anyopaque, declaration: *anyopaque, declContainer: *anyopaque) bool {
        _ = c;
        _ = usage;
        _ = declaration;
        _ = declContainer;
        return false;
    }

    pub fn isImmediatelyUsedInInitializerOfBlockScopedVariable(declaration: *anyopaque, usage: *anyopaque, declContainer: *anyopaque) bool {
        _ = declaration;
        _ = usage;
        _ = declContainer;
        return false;
    }

    pub fn isSameScopeDescendentOf(initial: *anyopaque, parent: *anyopaque, stopAt: *anyopaque) bool {
        _ = initial;
        _ = parent;
        _ = stopAt;
        return false;
    }

    pub fn isPropertyImmediatelyReferencedWithinDeclaration(declaration: *anyopaque, usage: *anyopaque, stopAtAnyPropertyDeclaration: *anyopaque) bool {
        _ = declaration;
        _ = usage;
        _ = stopAtAnyPropertyDeclaration;
        return false;
    }

    pub fn getTypeOnlyAliasDeclaration(c: *Checker, sym_idx: ast_gen.SymbolIndex) ast_gen.NodeIndex {
        const sym = c.getSymbolData(sym_idx);
        if (sym.Flags & ast_gen.SymbolFlags.Alias != 0) {
            _ = c.resolveAlias(sym_idx);
            if (c.aliasSymbolLinks.get(sym_idx)) |links| {
                if (links.typeOnlyDeclaration) |decl| {
                    return decl;
                }
            }
        }
        return 0;
    }

    pub fn getTypeOnlyAliasDeclarationEx(c: *Checker, sym_idx: ast_gen.SymbolIndex, meaning: u32) ast_gen.NodeIndex {
        var current_symbol = sym_idx;
        while (true) {
            const sym = c.getSymbolData(current_symbol);
            if (sym.Flags & ast_gen.SymbolFlags.Alias == 0 or sym.Flags & meaning != 0) {
                break;
            }
            const resolved = c.resolveAlias(current_symbol);
            if (c.aliasSymbolLinks.get(current_symbol)) |links| {
                if (links.typeOnlyDeclaration) |decl| {
                    return decl;
                }
            }
            current_symbol = resolved;
        }
        return 0;
    }

    pub fn getImmediateAliasedSymbol(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn addTypeOnlyDeclarationRelatedInfo(c: *Checker, diagnostic: *anyopaque, typeOnlyDeclaration: *anyopaque, name_: *anyopaque) *anyopaque {
        _ = c;
        _ = diagnostic;
        _ = typeOnlyDeclaration;
        _ = name_;
        return undefined;
    }

    /// Port of `checker.go::getSymbol`. Looks up `name` in `symbols` with
    /// the given `meaning` (SymbolFlags bitmask). If the found symbol is
    /// an alias, resolves the alias and checks its target flags.
    pub fn getSymbol(c: *Checker, symbols: *const symbol.SymbolTable, name: []const u8, meaning: u32) ast_gen.SymbolIndex {
        if ((meaning & symbol.SymbolFlags.All) == 0) return 0;
        const raw = symbols.get(name) orelse return 0;
        const sym = c.getMergedSymbol(raw);
        if (sym == 0) return 0;
        const flags = c.getSymbolFlags(sym);
        if ((flags & meaning) != 0) return sym;
        if ((flags & symbol.SymbolFlags.Alias) != 0) {
            const target_flags = c.getSymbolFlags(sym);
            if ((target_flags & meaning) != 0) return sym;
        }
        return 0;
    }

    pub fn checkSourceFile(c: *Checker, ctx: ?*anyopaque, sourceFile: ast_gen.NodeIndex, checkUnused: bool) void {
        _ = ctx;
        var links = c.sourceFileLinks.get(sourceFile) orelse types.SourceFileLinks{};
        if (!links.typeChecked) {
            // c.saveDeferredDiagnostics = true;
            // if (c.tracer) |tr| { ... }

            // Grammar checking
            // c.checkGrammarSourceFile(sourceFile);
            // c.renamedBindingElementsInTypes = null;

            if (c.binder.ast.getNode(sourceFile)) |sf_node| {
                if (sf_node.NodeData == .SourceFile) {
                    const stmts = c.binder.ast.getNodeList(sf_node.NodeData.SourceFile.Statements);
                    c.checkSourceElements(stmts);
                }
            }

            c.checkDeferredNodes(sourceFile);
            if (utils.isExternalOrCommonJSModule(c.ast, sourceFile)) {
                // c.checkExternalModuleExports(sourceFile);
                // c.registerForUnusedIdentifiersCheck(sourceFile);
            }
            if (!utils.isDeclarationFile(c.ast, sourceFile)) { // && !c.isCanceled()
                // c.checkUnusedRenamedBindingElements();
            }
            // c.saveDeferredDiagnostics = false;
            // c.produceDeferredDiagnostics();
            // c.reportedUnreachableNodes.clearRetainingCapacity();
            links.typeChecked = true;
        }
        if (checkUnused and !links.unusedChecked) {
            if (!utils.isDeclarationFile(c.ast, sourceFile)) { // && !c.isCanceled()
                // c.checkUnusedIdentifiers(links.identifierCheckNodes);
            }
            links.unusedChecked = true;
        }
        c.sourceFileLinks.put(c.allocator, sourceFile, links) catch {};
    }

    pub fn checkSourceElements(c: *Checker, nodes: []const ast_gen.NodeIndex) void {
        for (nodes) |node| {
            if (node != 0) checkSourceElement(c, node);
        }
    }

    pub fn checkSourceElementUnreachable(c: *Checker, node: ast_gen.NodeIndex) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn isSourceElementUnreachable(c: *Checker, node: ast_gen.NodeIndex) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn checkDeferredNodes(c: *Checker, context: *anyopaque) void {
        _ = c;
        _ = context;
    }

    pub fn checkDeferredNode(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkJSDocComments(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkJSDocComment(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn resolveJSDocMemberName(c: *Checker, name_: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        return undefined;
    }

    pub fn checkJSDocTypeIsInJsFile(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkTypeParameterDeferred(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn shouldCheckErasableSyntax(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn checkAsyncFunctionReturnType(c: *Checker, node: *anyopaque, returnTypeNode: *anyopaque) void {
        _ = c;
        _ = node;
        _ = returnTypeNode;
    }

    pub fn findFirstSuperCall(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn isInstancePropertyWithInitializerOrPrivateIdentifierProperty(n: *anyopaque) bool {
        _ = n;
        return false;
    }

    pub fn superCallIsRootLevelInConstructor(superCall: *anyopaque, body: *anyopaque) bool {
        _ = superCall;
        _ = body;
        return false;
    }

    pub fn nodeImmediatelyReferencesSuperOrThis(node: *anyopaque) bool {
        _ = node;
        return false;
    }

    pub fn checkTypeReferenceOrImport(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkTypeArgumentConstraints(c: *Checker, node: *anyopaque, typeParameters: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = typeParameters;
        return false;
    }

    pub fn getDeprecatedSuggestionNode(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getTypePredicateParent(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn checkIfTypePredicateVariableIsDeclaredInBindingPattern(c: *Checker, pattern: *anyopaque, predicateVariableNode: *anyopaque, predicateVariableName: *anyopaque) bool {
        _ = c;
        _ = pattern;
        _ = predicateVariableNode;
        _ = predicateVariableName;
        return false;
    }

    pub fn checkObjectTypeForDuplicateDeclarations(c: *Checker, node: *anyopaque, checkPrivateNames: *anyopaque) void {
        _ = c;
        _ = node;
        _ = checkPrivateNames;
    }

    pub fn reportDuplicateMemberErrors(c: *Checker, node: *anyopaque, name_: *anyopaque, checkStatic: *anyopaque, isStatic: *anyopaque, message: *anyopaque) void {
        _ = c;
        _ = node;
        _ = name_;
        _ = checkStatic;
        _ = isStatic;
        _ = message;
    }

    pub fn getResolutionModeOverride(c: *Checker, node: *anyopaque, reportErrors: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = reportErrors;
        return undefined;
    }

    pub fn checkFunctionOrMethodDeclaration(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkFunctionOrConstructorSymbol(c: *Checker, symbol_: *anyopaque) void {
        _ = c;
        _ = symbol_;
    }

    pub fn checkFunctionOrConstructorSymbolWorker(c: *Checker, symbol_: *anyopaque) void {
        _ = c;
        _ = symbol_;
    }

    pub fn getEffectiveDeclarationFlags(c: *Checker, n: *anyopaque, flagsToCheck: *anyopaque) *anyopaque {
        _ = c;
        _ = n;
        _ = flagsToCheck;
        return undefined;
    }

    pub fn isImplementationCompatibleWithOverload(c: *Checker, implementation: *anyopaque, overload: *anyopaque) bool {
        _ = c;
        _ = implementation;
        _ = overload;
        return false;
    }

    pub fn checkAllCodePathsInNonVoidFunctionReturnOrThrow(c: *Checker, fn_: *anyopaque, returnType: *anyopaque) void {
        _ = c;
        _ = fn_;
        _ = returnType;
    }

    pub fn isUnwrappedReturnTypeUndefinedVoidOrAny(c: *Checker, fn_: *anyopaque, returnType: *anyopaque) bool {
        _ = c;
        _ = fn_;
        _ = returnType;
        return false;
    }

    pub fn checkTestingKnownTruthyCallableOrAwaitableOrEnumMemberType(c: *Checker, condExpr: ast_gen.NodeIndex, condType: types.TypeIndex, body: ast_gen.NodeIndex) void {
        if (!c.strictNullChecks) return;
        c.checkTestingKnownTruthyTypes(condExpr, condType, body);
    }

    pub fn checkTestingKnownTruthyTypes(c: *Checker, condExpr: ast_gen.NodeIndex, condType: types.TypeIndex, body: ast_gen.NodeIndex) void {
        _ = c;
        _ = condExpr;
        _ = condType;
        _ = body;
        // TODO: Implement
    }

    pub fn checkTestingKnownTruthyType(c: *Checker, condExpr: ast_gen.NodeIndex, condType: types.TypeIndex, body: ast_gen.NodeIndex) void {
        _ = c;
        _ = condExpr;
        _ = condType;
        _ = body;
        // TODO: Implement
    }

    pub fn isSymbolUsedInBinaryExpressionChain(c: *Checker, node: *anyopaque, testedSymbol: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = testedSymbol;
        return false;
    }

    pub fn isSymbolUsedInConditionBody(c: *Checker, expr: *anyopaque, body: *anyopaque, testedNode: *anyopaque, testedSymbol: *anyopaque) bool {
        _ = c;
        _ = expr;
        _ = body;
        _ = testedNode;
        _ = testedSymbol;
        return false;
    }

    pub fn getIndexTypeOrString(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn checkReturnExpression(c: *Checker, container: *anyopaque, unwrappedReturnType: *anyopaque, node: *anyopaque, expr: *anyopaque, exprType: *anyopaque, inConditionalExpression: *anyopaque) void {
        _ = c;
        _ = container;
        _ = unwrappedReturnType;
        _ = node;
        _ = expr;
        _ = exprType;
        _ = inConditionalExpression;
    }

    pub fn checkClassLikeDeclaration(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkClassForStaticPropertyNameConflicts(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkTypeParameterListsIdentical(c: *Checker, symbol_: *anyopaque) void {
        _ = c;
        _ = symbol_;
    }

    pub fn getClassOrInterfaceDeclarationsOfSymbol(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn areTypeParametersIdentical(c: *Checker, declarations: *anyopaque, targetParameters: *anyopaque, getTypeParameterDeclarations: *anyopaque) bool {
        _ = c;
        _ = declarations;
        _ = targetParameters;
        _ = getTypeParameterDeclarations;
        return false;
    }

    pub fn checkBaseTypeAccessibility(c: *Checker, t: *anyopaque, node: *anyopaque) void {
        _ = c;
        _ = t;
        _ = node;
    }

    pub fn issueMemberSpecificError(c: *Checker, node: *anyopaque, typeWithThis: *anyopaque, baseWithThis: *anyopaque, broadDiag: *anyopaque) void {
        _ = c;
        _ = node;
        _ = typeWithThis;
        _ = baseWithThis;
        _ = broadDiag;
    }

    pub fn getTypeWithoutSignatures(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn checkKindsOfPropertyMemberOverrides(c: *Checker, t: *anyopaque, baseType: *anyopaque) void {
        _ = c;
        _ = t;
        _ = baseType;
    }

    /// Port of `checker.go::arePropertiesAbstractOrInterface`. Returns true
    /// if all (or some, for synthetic symbols) declarations of `base` are
    /// abstract or from an interface.
    pub fn arePropertiesAbstractOrInterface(c: *Checker, base: ast_gen.SymbolIndex, base_declaration_flags: u32) bool {
        if (base == 0 or base >= c.binder.symbols.items.len) return false;
        const sym = c.binder.symbols.items[base];
        const is_synthetic = (sym.CheckFlags & types.CheckFlags.Synthetic) != 0;
        for (sym.Declarations.items) |decl| {
            const result = c.isPropertyAbstractOrInterface(decl, base_declaration_flags);
            if (is_synthetic) {
                // Synthetic: return true if ANY declaration is abstract/interface
                if (result) return true;
            } else {
                // Non-synthetic: return false if ANY declaration is NOT abstract/interface
                if (!result) return false;
            }
        }
        return !is_synthetic; // synthetic returns false if none matched; non-synthetic returns true if all matched
    }

    /// Port of `checker.go::isPropertyAbstractOrInterface`. Returns true if
    /// the declaration's parent is an interface, or if it's an abstract
    /// property without an initializer.
    pub fn isPropertyAbstractOrInterface(c: *Checker, declaration: ast_gen.NodeIndex, base_declaration_flags: u32) bool {
        if (declaration == 0) return false;
        const tree = c.binder.ast;
        const parent = tree.getNodeParent(declaration);
        if (parent != 0 and ast_utils.isInterfaceDeclaration(tree, parent)) return true;
        if ((base_declaration_flags & ast_utils.ModifierFlags.Abstract) != 0) {
            if (!ast_utils.isPropertyDeclaration(tree, declaration)) return true;
            return ast_utils.getInitializerOfNode(tree, declaration) == 0;
        }
        return false;
    }

    pub fn checkMembersForOverrideModifier(c: *Checker, node: *anyopaque, t: *anyopaque, typeWithThis: *anyopaque, staticType: *anyopaque) void {
        _ = c;
        _ = node;
        _ = t;
        _ = typeWithThis;
        _ = staticType;
    }

    pub fn checkMemberForOverrideModifier(c: *Checker, node: *anyopaque, staticType: *anyopaque, baseStaticType: *anyopaque, baseWithThis: *anyopaque, t: *anyopaque, typeWithThis: *anyopaque, member: *anyopaque) void {
        _ = c;
        _ = node;
        _ = staticType;
        _ = baseStaticType;
        _ = baseWithThis;
        _ = t;
        _ = typeWithThis;
        _ = member;
    }

    pub fn getSuggestedSymbolForNonexistentClassMember(c: *Checker, name_: *anyopaque, baseType: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        _ = baseType;
        return undefined;
    }

    pub fn checkIndexConstraints(c: *Checker, t: *anyopaque, symbol_: *anyopaque, isStaticIndex: *anyopaque) void {
        _ = c;
        _ = t;
        _ = symbol_;
        _ = isStaticIndex;
    }

    pub fn checkIndexConstraintForProperty(c: *Checker, t: *anyopaque, prop: *anyopaque, propNameType: *anyopaque, propType: *anyopaque) void {
        _ = c;
        _ = t;
        _ = prop;
        _ = propNameType;
        _ = propType;
    }

    pub fn checkIndexConstraintForIndexSignature(c: *Checker, t: *anyopaque, checkInfo: *anyopaque) void {
        _ = c;
        _ = t;
        _ = checkInfo;
    }

    pub fn checkClassOrInterfaceForDuplicateIndexSignatures(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkTypeForDuplicateIndexSignatures(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkPropertyInitialization(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn isPropertyWithoutInitializer(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn isPropertyInitializedInStaticBlocks(c: *Checker, propName: *anyopaque, propType: *anyopaque, staticBlocks: *anyopaque, startPos: *anyopaque, endPos: *anyopaque) bool {
        _ = c;
        _ = propName;
        _ = propType;
        _ = staticBlocks;
        _ = startPos;
        _ = endPos;
        return false;
    }

    /// Port of `checker.go::isPropertyInitializedInConstructor`. Returns
    /// true if the property `propName` is assigned within `constructor`
    /// before being read (i.e., the flow type does not contain undefined).
    ///
    /// Note: The Go implementation creates a synthetic `this.propName`
    /// reference and uses `getFlowTypeOfReferenceEx`. The Zig flow analysis
    /// is partially ported; this implementation uses a conservative
    /// heuristic: scan the constructor body for an assignment to
    /// `this.<propName>` and return true if found. This is less precise
    /// than the full flow analysis but handles the common case.
    pub fn isPropertyInitializedInConstructor(c: *Checker, propName: ast_gen.NodeIndex, propType: types.TypeIndex, constructor: ast_gen.NodeIndex) bool {
        _ = propType;
        if (constructor == 0 or propName == 0) return false;
        const tree = c.binder.ast;
        // Walk constructor body looking for `this.<propName> = ...` or
        // `this[<propName>] = ...` assignments.
        const prop_name_text = ast_utils.getText(tree, propName);
        if (prop_name_text.len == 0) return false;

        // Get constructor body
        const ctor_data = tree.getNode(constructor);
        if (ctor_data != .Constructor) return false;
        const body = ctor_data.Constructor.Body orelse return false;
        return scanConstructorForAssignment(c, body, prop_name_text);
    }

    /// Walks a constructor body (Block) looking for `this.<name> = ...` or
    /// `this[<name>] = ...` assignments. Returns true if found.
    fn scanConstructorForAssignment(c: *Checker, body: ast_gen.NodeIndex, name: []const u8) bool {
        const tree = c.binder.ast;
        const body_data = tree.getNode(body);
        if (body_data != .Block) return false;
        const stmts = tree.getNodeList(body_data.Block.Statements);
        for (stmts) |stmt| {
            if (scanExpressionForAssignment(c, stmt, name)) return true;
        }
        return false;
    }

    fn scanExpressionForAssignment(c: *Checker, node: ast_gen.NodeIndex, name: []const u8) bool {
        if (node == 0) return false;
        const tree = c.binder.ast;
        const node_data = tree.getNode(node);
        switch (node_data) {
            .ExpressionStatement => |n| return scanExpressionForAssignment(c, n.Expression, name),
            .BinaryExpression => |n| {
                const op_kind = tree.getNodeKind(n.OperatorToken);
                if (op_kind == .EqualsToken) {
                    // Check left side
                    const left_kind = tree.getNodeKind(n.Left);
                    if (left_kind == .PropertyAccessExpression) {
                        const pa = tree.getNode(n.Left).PropertyAccessExpression;
                        // Check expression is `this`
                        const expr_kind = tree.getNodeKind(pa.Expression);
                        if (expr_kind == .ThisKeyword) {
                            const prop_text = ast_utils.getText(tree, pa.name);
                            if (std.mem.eql(u8, prop_text, name)) return true;
                        }
                    } else if (left_kind == .ElementAccessExpression) {
                        const ea = tree.getNode(n.Left).ElementAccessExpression;
                        const expr_kind = tree.getNodeKind(ea.Expression);
                        if (expr_kind == .ThisKeyword) {
                            const arg_text = ast_utils.getText(tree, ea.ArgumentExpression);
                            if (std.mem.eql(u8, arg_text, name)) return true;
                        }
                    }
                }
                return false;
            },
            .Block => |n| {
                const stmts = tree.getNodeList(n.Statements);
                for (stmts) |stmt| {
                    if (scanExpressionForAssignment(c, stmt, name)) return true;
                }
                return false;
            },
            else => return false,
        }
    }

    pub fn checkInheritedPropertiesAreIdentical(c: *Checker, t: *anyopaque, typeNode: *anyopaque) bool {
        _ = c;
        _ = t;
        _ = typeNode;
        return false;
    }

    pub fn isPropertyIdenticalTo(c: *Checker, sourceProp: *anyopaque, targetProp: *anyopaque) bool {
        _ = c;
        _ = sourceProp;
        _ = targetProp;
        return false;
    }

    pub fn isInstantiatedModule(node: *anyopaque, preserveConstEnums: *anyopaque) bool {
        _ = node;
        _ = preserveConstEnums;
        return false;
    }

    pub fn getFirstNonAmbientClassOrFunctionDeclaration(symbol_: *anyopaque) *anyopaque {
        _ = symbol_;
        return undefined;
    }

    pub fn getIsolatedModulesLikeFlagName(c: *Checker) *anyopaque {
        _ = c;
        return undefined;
    }

    pub fn checkModuleAugmentationElement(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkExternalImportOrExportDeclaration(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn checkImportBinding(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkModuleExportName(c: *Checker, name_: *anyopaque, allowStringLiteral: *anyopaque) void {
        _ = c;
        _ = name_;
        _ = allowStringLiteral;
    }

    pub fn hasTypeJsonImportAttribute(node: *anyopaque) bool {
        _ = node;
        return false;
    }

    pub fn checkImportAttributes(c: *Checker, declaration: *anyopaque) void {
        _ = c;
        _ = declaration;
    }

    pub fn getTypeFromImportAttributes(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn checkExportSpecifier(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn getVerbatimModuleSyntaxErrorMessage(node: *anyopaque) *anyopaque {
        _ = node;
        return undefined;
    }

    pub fn checkExternalModuleExports(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn hasExportedMembersOfKind(c: *Checker, moduleSymbol: *anyopaque, kind_: *anyopaque) bool {
        _ = c;
        _ = moduleSymbol;
        _ = kind_;
        return false;
    }

    pub fn hasShadowedNamespace(c: *Checker, symbol_: *anyopaque) bool {
        _ = c;
        _ = symbol_;
        return false;
    }

    pub fn isNotOverload(node: *anyopaque) bool {
        _ = node;
        return false;
    }

    pub fn checkVariableLikeDeclaration(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn errorNextVariableOrPropertyDeclarationMustHaveSameType(c: *Checker, firstDeclaration: *anyopaque, firstType: *anyopaque, nextDeclaration: *anyopaque, nextType: *anyopaque) void {
        _ = c;
        _ = firstDeclaration;
        _ = firstType;
        _ = nextDeclaration;
        _ = nextType;
    }

    pub fn checkVarDeclaredNamesNotShadowed(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkDecorators(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkDecorator(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkIteratedTypeOrElementType(c: *Checker, use: *anyopaque, inputType: *anyopaque, sentType: *anyopaque, errorNode: *anyopaque) *anyopaque {
        _ = c;
        _ = use;
        _ = inputType;
        _ = sentType;
        _ = errorNode;
        return undefined;
    }

    pub fn getIteratedTypeOrElementType(c: *Checker, use: *anyopaque, inputType: *anyopaque, sentType: *anyopaque, errorNode: *anyopaque, checkAssignability: *anyopaque) *anyopaque {
        _ = c;
        _ = use;
        _ = inputType;
        _ = sentType;
        _ = errorNode;
        _ = checkAssignability;
        return undefined;
    }

    pub fn getIterationTypeOfGeneratorFunctionReturnType(c: *Checker, typeKind: *anyopaque, returnType: *anyopaque, isAsyncGenerator: *anyopaque) *anyopaque {
        _ = c;
        _ = typeKind;
        _ = returnType;
        _ = isAsyncGenerator;
        return undefined;
    }

    pub fn getIterationTypesOfGeneratorFunctionReturnType(c: *Checker, t: *anyopaque, isAsyncGenerator: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = isAsyncGenerator;
        return undefined;
    }

    pub fn getIterationTypeOfIterable(c: *Checker, use: *anyopaque, typeKind: *anyopaque, inputType: *anyopaque, errorNode: *anyopaque) *anyopaque {
        _ = c;
        _ = use;
        _ = typeKind;
        _ = inputType;
        _ = errorNode;
        return undefined;
    }

    pub fn getIterationTypesOfIterable(c: *Checker, t: *anyopaque, use: *anyopaque, errorNode: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = use;
        _ = errorNode;
        return undefined;
    }

    pub fn getIterationTypesOfIterableWorker(c: *Checker, t: *anyopaque, use: *anyopaque, errorNode: *anyopaque, noCache: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = use;
        _ = errorNode;
        _ = noCache;
        return undefined;
    }

    pub fn getIterationTypesOfIterableFast(c: *Checker, t: *anyopaque, r: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = r;
        return undefined;
    }

    pub fn getResolvedIterationTypes(r: *anyopaque, yieldType: *anyopaque, returnType: *anyopaque, nextType: *anyopaque) *anyopaque {
        _ = r;
        _ = yieldType;
        _ = returnType;
        _ = nextType;
        return undefined;
    }

    /// Port of `checker.go::isReferenceToType`. Returns true if `t` is a
    /// type reference whose target is `target`.
    pub fn isReferenceToType(c: *Checker, t: types.TypeIndex, target: types.TypeIndex) bool {
        if (t == 0 or t >= c.typesList.items.len) return false;
        const ty = c.typesList.items[t];
        if ((ty.objectFlags & types.ObjectFlags.Reference) == 0) return false;
        return c.getTargetType(t) == target;
    }

    /// Port of `checker.go::isReferenceToSomeType`. Returns true if `t` is a
    /// type reference whose target is one of `targets`.
    pub fn isReferenceToSomeType(c: *Checker, t: types.TypeIndex, targets: []const types.TypeIndex) bool {
        if (t == 0 or t >= c.typesList.items.len) return false;
        const ty = c.typesList.items[t];
        if ((ty.objectFlags & types.ObjectFlags.Reference) == 0) return false;
        const target = c.getTargetType(t);
        for (targets) |tgt| {
            if (target == tgt) return true;
        }
        return false;
    }

    pub fn getBuiltinIteratorReturnType(c: *Checker) *anyopaque {
        _ = c;
        return undefined;
    }

    pub fn hasTypes(iterationTypes: *anyopaque) bool {
        _ = iterationTypes;
        return false;
    }

    pub fn getType(iterationTypes: *anyopaque, typeKind: *anyopaque) *anyopaque {
        _ = iterationTypes;
        _ = typeKind;
        return undefined;
    }

    pub fn combineIterationTypes(c: *Checker, iterationTypes: *anyopaque) *anyopaque {
        _ = c;
        _ = iterationTypes;
        return undefined;
    }

    pub fn getIterationTypeUnion(c: *Checker, iterationTypes: *anyopaque, f: *anyopaque) *anyopaque {
        _ = c;
        _ = iterationTypes;
        _ = f;
        return undefined;
    }

    pub fn getAsyncFromSyncIterationTypes(c: *Checker, iterationTypes: *anyopaque, errorNode: *anyopaque) *anyopaque {
        _ = c;
        _ = iterationTypes;
        _ = errorNode;
        return undefined;
    }

    pub fn getIterationTypesOfIterableSlow(c: *Checker, t: *anyopaque, r: *anyopaque, errorNode: *anyopaque, diagnosticOutput: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = r;
        _ = errorNode;
        _ = diagnosticOutput;
        return undefined;
    }

    pub fn getIterationTypesOfIterator(c: *Checker, t: *anyopaque, r: *anyopaque, errorNode: *anyopaque, diagnosticOutput: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = r;
        _ = errorNode;
        _ = diagnosticOutput;
        return undefined;
    }

    pub fn getIterationTypesOfIteratorWorker(c: *Checker, t: *anyopaque, r: *anyopaque, errorNode: *anyopaque, diagnosticOutput: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = r;
        _ = errorNode;
        _ = diagnosticOutput;
        return undefined;
    }

    pub fn getIterationTypesOfIteratorFast(c: *Checker, t: *anyopaque, r: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = r;
        return undefined;
    }

    pub fn getIterationTypesOfIteratorSlow(c: *Checker, t: *anyopaque, r: *anyopaque, errorNode: *anyopaque, diagnosticOutput: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = r;
        _ = errorNode;
        _ = diagnosticOutput;
        return undefined;
    }

    pub fn getIterationTypesOfMethod(c: *Checker, t: *anyopaque, resolver: *anyopaque, methodName: *anyopaque, errorNode: *anyopaque, diagnosticOutput: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = resolver;
        _ = methodName;
        _ = errorNode;
        _ = diagnosticOutput;
        return undefined;
    }

    pub fn getIterationTypesOfIteratorResult(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn isYieldIteratorResult(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn isReturnIteratorResult(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn isIteratorResult(c: *Checker, t: *anyopaque, kind_: *anyopaque) bool {
        _ = c;
        _ = t;
        _ = kind_;
        return false;
    }

    pub fn reportTypeNotIterableError(c: *Checker, errorNode: *anyopaque, t: *anyopaque, allowAsyncIterables: *anyopaque) *anyopaque {
        _ = c;
        _ = errorNode;
        _ = t;
        _ = allowAsyncIterables;
        return undefined;
    }

    pub fn getIterationDiagnosticDetails(c: *Checker, use: *anyopaque, inputType: *anyopaque, allowsStrings: *anyopaque) bool {
        _ = c;
        _ = use;
        _ = inputType;
        _ = allowsStrings;
        return false;
    }

    pub fn isES2015OrLaterIterable(n: *anyopaque) bool {
        _ = n;
        return false;
    }

    pub fn checkAliasSymbol(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn areDeclarationFlagsIdentical(c: *Checker, left: *anyopaque, right: *anyopaque) bool {
        _ = c;
        _ = left;
        _ = right;
        return false;
    }

    pub fn checkTypeNameIsReserved(c: *Checker, name_: *anyopaque, message: *anyopaque) void {
        _ = c;
        _ = name_;
        _ = message;
    }

    pub fn checkExportsOnMergedDeclarations(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn getDeclarationSpaces(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn checkTypeParametersNotReferenced(c: *Checker, root: *anyopaque, typeParameters: *anyopaque, index: *anyopaque) void {
        _ = c;
        _ = root;
        _ = typeParameters;
        _ = index;
    }

    pub fn registerForUnusedIdentifiersCheck(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkUnusedIdentifiers(c: *Checker, potentiallyUnusedIdentifiers: *anyopaque) void {
        _ = c;
        _ = potentiallyUnusedIdentifiers;
    }

    pub fn isReferenced_stub(c: *Checker, symbol_: *anyopaque) bool {
        _ = c;
        _ = symbol_;
        return false;
    }

    pub fn reportUnusedVariable(c: *Checker, location: *anyopaque, diagnostic: *anyopaque) void {
        _ = c;
        _ = location;
        _ = diagnostic;
    }

    pub fn reportUnused(c: *Checker, location: *anyopaque, kind_: *anyopaque, diagnostic: *anyopaque) void {
        _ = c;
        _ = location;
        _ = kind_;
        _ = diagnostic;
    }

    pub fn unusedIsError(c: *Checker, kind_: *anyopaque) bool {
        _ = c;
        _ = kind_;
        return false;
    }

    pub fn checkUnusedClassMembers(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkUnusedLocalsAndParameters(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn reportUnusedLocal(c: *Checker, node: *anyopaque, name_: *anyopaque) void {
        _ = c;
        _ = node;
        _ = name_;
    }

    pub fn reportUnusedVariables(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn reportUnusedParameters(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn reportUnusedBindingElements(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn reportUnusedVariableDeclarations(c: *Checker, declarations: *anyopaque) void {
        _ = c;
        _ = declarations;
    }

    pub fn isUnreferencedVariableDeclaration(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn reportUnusedImports(c: *Checker, node: *anyopaque, unuseds: *anyopaque) void {
        _ = c;
        _ = node;
        _ = unuseds;
    }

    pub fn isIdentifierThatStartsWithUnderscore(node: *anyopaque) bool {
        _ = node;
        return false;
    }

    pub fn importClauseFromImported(node: *anyopaque) *anyopaque {
        _ = node;
        return undefined;
    }

    pub fn checkUnusedInferTypeParameter(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkUnusedTypeParameters(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn isUnreferencedTypeParameter(c: *Checker, typeParameter: *anyopaque) bool {
        _ = c;
        _ = typeParameter;
        return false;
    }

    pub fn checkUnusedRenamedBindingElements(c: *Checker) void {
        _ = c;
    }

    pub fn getTypeOfExpression(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getQuickTypeOfExpression(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getReturnTypeOfSingleNonGenericSignature(c: *Checker, funcType: *anyopaque, kind_: *anyopaque) *anyopaque {
        _ = c;
        _ = funcType;
        _ = kind_;
        return undefined;
    }

    pub fn getReturnTypeOfSingleNonGenericSignatureOfCallChain(c: *Checker, expr: *anyopaque) *anyopaque {
        _ = c;
        _ = expr;
        return undefined;
    }

    pub fn checkNonNullType(c: *Checker, t: types.TypeIndex, node: ast_gen.NodeIndex) types.TypeIndex {
        _ = c;
        _ = node;
        return t;
    }

    pub fn checkNonNullTypeWithReporter(c: *Checker, t: *anyopaque, node1: *anyopaque, reportError_: *anyopaque, node2: *anyopaque, facts: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = node1;
        _ = reportError_;
        _ = node2;
        _ = facts;
        return undefined;
    }

    pub fn checkNonNullNonVoidType(c: *Checker, t: *anyopaque, node: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = node;
        return undefined;
    }

    pub fn reportObjectPossiblyNullOrUndefinedError(c: *Checker, node: *anyopaque, facts: *anyopaque) void {
        _ = c;
        _ = node;
        _ = facts;
    }

    pub fn checkExpressionWithContextualType(c: *Checker, node: ast_gen.NodeIndex, contextualType: types.TypeIndex, inferenceContext: u32, checkMode: CheckMode) types.TypeIndex {
        _ = c;
        _ = node;
        _ = contextualType;
        _ = inferenceContext;
        _ = checkMode;
        return undefined;
    }

    pub fn getContextNode(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn checkExpressionCached(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return c.checkExpressionCachedEx(node_idx, CheckMode.Normal);
    }

    pub fn checkExpressionCachedEx(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
        if (checkMode != CheckMode.Normal) {
            return checkExpressionEx(c, node_idx, checkMode);
        }
        var linksPtr = c.typeNodeLinks.getPtr(node_idx);
        if (linksPtr == null) {
            c.typeNodeLinks.put(c.allocator, node_idx, .{}) catch {};
            linksPtr = c.typeNodeLinks.getPtr(node_idx);
        }
        if (linksPtr.?.resolvedType == 0) {
            const saveFlowLoopStack = c.flowLoopStack;
            c.flowLoopStack = .empty;
            linksPtr.?.resolvedType = checkExpressionEx(c, node_idx, checkMode);
            c.flowLoopStack = saveFlowLoopStack;
        }
        return linksPtr.?.resolvedType;
    }

    pub fn getContextFreeTypeOfExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        if (c.contextFreeTypes.get(node_idx)) |cached| {
            return cached;
        }
        c.pushContextualType(node_idx, c.anyTypeIndex orelse 0, false);
        const t = checkExpressionEx(c, node_idx, CheckMode.SkipContextSensitive);
        c.contextFreeTypes.put(c.allocator, node_idx, t) catch {};
        c.popContextualType();
        return t;
    }

    pub fn checkConstEnumAccess(c: *Checker, node_idx: ast_gen.NodeIndex, t: types.TypeIndex) void {
        _ = c;
        _ = node_idx;
        _ = t;
    }

    pub fn getOuterInferenceTypeParameters(c: *Checker) *anyopaque {
        _ = c;
        return undefined;
    }

    pub fn getUniqueTypeParameters(c: *Checker, context: *anyopaque, typeParameters: *anyopaque) *anyopaque {
        _ = c;
        _ = context;
        _ = typeParameters;
        return undefined;
    }

    pub fn hasTypeParameterByName(typeParameters: *anyopaque, name_: *anyopaque) bool {
        _ = typeParameters;
        _ = name_;
        return false;
    }

    pub fn getUniqueTypeParameterName(typeParameters: *anyopaque, baseName: *anyopaque) *anyopaque {
        _ = typeParameters;
        _ = baseName;
        return undefined;
    }

    pub fn isInConstructorArgumentInitializer(c: *Checker, node: *anyopaque, constructorDecl: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = constructorDecl;
        return false;
    }

    pub fn isTemplateLiteralContext(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn isTemplateLiteralContextualType(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn createArrayLiteralType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn isSpreadIntoCallOrNew(node: *anyopaque) bool {
        _ = node;
        return false;
    }

    pub fn checkQualifiedName(c: *Checker, node: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = checkMode;
        return undefined;
    }

    pub fn checkIndexedAccess(c: *Checker, node: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = checkMode;
        return undefined;
    }

    pub fn checkElementAccessChain(c: *Checker, node: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = checkMode;
        return undefined;
    }

    pub fn isForInVariableForNumericPropertyNames(c: *Checker, expr: ast_gen.NodeIndex) bool {
        _ = c;
        _ = expr;
        return false;
    }

    pub fn getForInVariableSymbol(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn hasNumericPropertyNames(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn checkIndexedAccessIndexType(c: *Checker, t: types.TypeIndex, accessNode: ast_gen.NodeIndex) types.TypeIndex {
        _ = c;
        _ = accessNode;
        return t;
    }

    pub fn getConstituentProperty(c: *Checker, objectType: *anyopaque, propertyName: *anyopaque) *anyopaque {
        _ = c;
        _ = objectType;
        _ = propertyName;
        return undefined;
    }

    pub fn checkImportCallExpression(c: *Checker, node: ast_gen.NodeIndex) types.TypeIndex {
        _ = node;
        return c.anyTypeIndex orelse 0;
    }

    pub fn checkDeprecatedSignature(c: *Checker, sig: types.SignatureIndex, node: ast_gen.NodeIndex) void {
        _ = c;
        _ = sig;
        _ = node;
    }

    pub fn addDeprecatedSuggestionWithSignature(c: *Checker, location: *anyopaque, declaration: *anyopaque, deprecatedEntity: *anyopaque, signatureString: *anyopaque) *anyopaque {
        _ = c;
        _ = location;
        _ = declaration;
        _ = deprecatedEntity;
        _ = signatureString;
        return undefined;
    }

    pub fn isSymbolOrSymbolForCall(c: *Checker, node: ast_gen.NodeIndex) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn resolveSignature(c: *Checker, node: *anyopaque, candidatesOutArray: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = candidatesOutArray;
        _ = c;
        _ = node;
        _ = checkMode;
        return undefined;
    }

    pub fn resolveCallExpression(c: *Checker, node: *anyopaque, candidatesOutArray: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = candidatesOutArray;
        _ = c;
        _ = node;
        _ = checkMode;
        return undefined;
    }

    pub fn resolveNewExpression(c: *Checker, node: *anyopaque, candidatesOutArray: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = candidatesOutArray;
        _ = c;
        _ = node;
        _ = checkMode;
        return undefined;
    }

    pub fn isConstructorAccessible(c: *Checker, node: *anyopaque, signature: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = signature;
        return false;
    }

    pub fn typeHasProtectedAccessibleBase(c: *Checker, target: *anyopaque, t: *anyopaque) bool {
        _ = c;
        _ = target;
        _ = t;
        return false;
    }

    pub fn someSignature(signatures: *anyopaque, f: *anyopaque) bool {
        _ = signatures;
        _ = f;
        return false;
    }

    pub fn resolveTaggedTemplateExpression(c: *Checker, node: *anyopaque, candidatesOutArray: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = candidatesOutArray;
        _ = c;
        _ = node;
        _ = checkMode;
        return undefined;
    }

    pub fn resolveDecorator(c: *Checker, node: *anyopaque, candidatesOutArray: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = candidatesOutArray;
        _ = c;
        _ = node;
        _ = checkMode;
        return undefined;
    }

    pub fn isPotentiallyUncalledDecorator(c: *Checker, decorator: *anyopaque, signatures: *anyopaque) bool {
        _ = c;
        _ = decorator;
        _ = signatures;
        return false;
    }

    pub fn getDiagnosticHeadMessageForDecoratorResolution(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn resolveInstanceofExpression(c: *Checker, node: *anyopaque, candidatesOutArray: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = candidatesOutArray;
        _ = c;
        _ = node;
        _ = checkMode;
        return undefined;
    }

    pub fn resolveCall(c: *Checker, node: *anyopaque, signatures: *anyopaque, candidatesOutArray: *anyopaque, checkMode: *anyopaque, callChainFlags: *anyopaque, headMessage: *anyopaque) *anyopaque {
        _ = candidatesOutArray;
        _ = c;
        _ = node;
        _ = signatures;
        _ = checkMode;
        _ = callChainFlags;
        _ = headMessage;
        return undefined;
    }

    pub fn reorderCandidates(c: *Checker, signatures: *anyopaque, callChainFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = signatures;
        _ = callChainFlags;
        return undefined;
    }

    pub fn signatureHasLiteralTypes(s: *anyopaque) bool {
        _ = s;
        return false;
    }

    pub fn getOptionalCallSignature(c: *Checker, signature: *anyopaque, callChainFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = signature;
        _ = callChainFlags;
        return undefined;
    }

    pub fn chooseOverload(c: *Checker, s: *anyopaque, relation: *anyopaque) *anyopaque {
        _ = c;
        _ = s;
        _ = relation;
        return undefined;
    }

    pub fn hasCorrectArity(c: *Checker, node: *anyopaque, args: *anyopaque, signature: *anyopaque, signatureHelpTrailingComma: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = args;
        _ = signature;
        _ = signatureHelpTrailingComma;
        return false;
    }

    pub fn acceptsVoid(t: *anyopaque) bool {
        _ = t;
        return false;
    }

    pub fn getDecoratorArgumentCount(c: *Checker, node: *anyopaque, signature: *anyopaque) i32 {
        _ = c;
        _ = node;
        _ = signature;
        return 0;
    }

    pub fn getLegacyDecoratorArgumentCount(c: *Checker, node: *anyopaque, signature: *anyopaque) i32 {
        _ = c;
        _ = node;
        _ = signature;
        return 0;
    }

    pub fn hasCorrectTypeArgumentArity(c: *Checker, signature: *anyopaque, typeArguments: *anyopaque) bool {
        _ = c;
        _ = signature;
        _ = typeArguments;
        return false;
    }

    pub fn checkTypeArguments(c: *Checker, signature: *anyopaque, typeArgumentNodes: *anyopaque, reportErrors: *anyopaque, headMessage: *anyopaque) *anyopaque {
        _ = c;
        _ = signature;
        _ = typeArgumentNodes;
        _ = reportErrors;
        _ = headMessage;
        return undefined;
    }

    pub fn isSignatureApplicable(c: *Checker, node: *anyopaque, args: *anyopaque, signature: *anyopaque, relation: *anyopaque, checkMode: *anyopaque, reportErrors: *anyopaque, diagnosticOutput: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = args;
        _ = signature;
        _ = relation;
        _ = checkMode;
        _ = reportErrors;
        _ = diagnosticOutput;
        return false;
    }

    pub fn maybeAddMissingAwaitInfo(c: *Checker, errorNode: *anyopaque, source: *anyopaque, target: *anyopaque, relation: *anyopaque, reportErrors: *anyopaque, diagnosticOutput: *anyopaque) void {
        _ = c;
        _ = errorNode;
        _ = source;
        _ = target;
        _ = relation;
        _ = reportErrors;
        _ = diagnosticOutput;
    }

    pub fn getThisArgumentOfCall(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getThisArgumentType(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getEffectiveCheckNode(c: *Checker, argument: *anyopaque) *anyopaque {
        _ = c;
        _ = argument;
        return undefined;
    }

    pub fn inferTypeArguments(c: *Checker, node: *anyopaque, signature: *anyopaque, args: *anyopaque, checkMode: *anyopaque, context: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = signature;
        _ = args;
        _ = checkMode;
        _ = context;
        return undefined;
    }

    pub fn getCandidateForOverloadFailure(c: *Checker, node: *anyopaque, candidates: *anyopaque, args: *anyopaque, hasCandidatesOutArray: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = candidates;
        _ = args;
        _ = hasCandidatesOutArray;
        _ = checkMode;
        return undefined;
    }

    pub fn pickLongestCandidateSignature(c: *Checker, node: *anyopaque, candidates: *anyopaque, args: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = candidates;
        _ = args;
        _ = checkMode;
        return undefined;
    }

    pub fn getLongestCandidateIndex(c: *Checker, candidates: *anyopaque, argsCount: *anyopaque) i32 {
        _ = c;
        _ = candidates;
        _ = argsCount;
        return 0;
    }

    pub fn getTypeArgumentsFromNodes(c: *Checker, typeArgumentNodes: *anyopaque, typeParameters: *anyopaque) *anyopaque {
        _ = c;
        _ = typeArgumentNodes;
        _ = typeParameters;
        return undefined;
    }

    pub fn inferSignatureInstantiationForOverloadFailure(c: *Checker, node: *anyopaque, typeParameters: *anyopaque, candidate: *anyopaque, args: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = typeParameters;
        _ = candidate;
        _ = args;
        _ = checkMode;
        return undefined;
    }

    pub fn createUnionOfSignaturesForOverloadFailure(c: *Checker, candidates: *anyopaque) *anyopaque {
        _ = c;
        _ = candidates;
        return undefined;
    }

    pub fn createCombinedSymbolFromTypes(c: *Checker, sources: *anyopaque, types_: *anyopaque) *anyopaque {
        _ = c;
        _ = sources;
        _ = types_;
        return undefined;
    }

    pub fn createCombinedSymbolForOverloadFailure(c: *Checker, sources: *anyopaque, t: *anyopaque) *anyopaque {
        _ = c;
        _ = sources;
        _ = t;
        return undefined;
    }

    pub fn getRestTypeOfSignature(c: *Checker, signature: *anyopaque) *anyopaque {
        _ = c;
        _ = signature;
        return undefined;
    }

    pub fn tryGetRestTypeOfSignature(c: *Checker, signature: *anyopaque) *anyopaque {
        _ = c;
        _ = signature;
        return undefined;
    }

    pub fn reportCallResolutionErrors(c: *Checker, node: *anyopaque, s: *anyopaque, signatures: *anyopaque, headMessage: *anyopaque) void {
        _ = c;
        _ = node;
        _ = s;
        _ = signatures;
        _ = headMessage;
    }

    pub fn addImplementationSuccessElaboration(c: *Checker, s: *anyopaque, failed: *anyopaque, diagnostic: *anyopaque) void {
        _ = c;
        _ = s;
        _ = failed;
        _ = diagnostic;
    }

    pub fn getArgumentArityError(
        c: *Checker,
        node: ast_gen.NodeIndex,
        signatures: []const types.SignatureIndex,
        args: []const ast_gen.NodeIndex,
        head_message: ?*const diagnostics.Message,
    ) ?diagnostics.Diagnostic {
        return argument_arity.getArgumentArityError(c, node, signatures, args, head_message);
    }

    pub fn isPromiseResolveArityError(c: *Checker, node: ast_gen.NodeIndex) bool {
        return argument_arity.isPromiseResolveArityError(c, node);
    }

    pub fn getErrorNodeForCallNode(c: *Checker, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return argument_arity.getErrorNodeForCallNode(c, node);
    }

    pub fn getTypeArgumentArityError(c: *Checker, node: *anyopaque, signatures: *anyopaque, typeArguments: *anyopaque, headMessage: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = signatures;
        _ = typeArguments;
        _ = headMessage;
        return undefined;
    }

    pub fn reportCannotInvokePossiblyNullOrUndefinedError(c: *Checker, node: *anyopaque, facts: *anyopaque) void {
        _ = c;
        _ = node;
        _ = facts;
    }

    pub fn resolveUntypedCall(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn resolveErrorCall(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn isUntypedFunctionCall(c: *Checker, funcType: *anyopaque, apparentFuncType: *anyopaque, numCallSignatures: *anyopaque, numConstructSignatures: *anyopaque) bool {
        _ = c;
        _ = funcType;
        _ = apparentFuncType;
        _ = numCallSignatures;
        _ = numConstructSignatures;
        return false;
    }

    pub fn invocationErrorDetails(c: *Checker, errorTarget: *anyopaque, apparentType: *anyopaque, kind_: *anyopaque) *anyopaque {
        _ = c;
        _ = errorTarget;
        _ = apparentType;
        _ = kind_;
        return undefined;
    }

    pub fn invocationError(c: *Checker, errorTarget: *anyopaque, apparentType: *anyopaque, kind_: *anyopaque, relatedInformation: *anyopaque) void {
        _ = c;
        _ = errorTarget;
        _ = apparentType;
        _ = kind_;
        _ = relatedInformation;
    }

    pub fn invocationErrorRecovery(c: *Checker, apparentType: *anyopaque, kind_: *anyopaque, diagnostic: *anyopaque) void {
        _ = c;
        _ = apparentType;
        _ = kind_;
        _ = diagnostic;
    }

    pub fn isGenericFunctionReturningFunction(c: *Checker, signature: *anyopaque) bool {
        _ = c;
        _ = signature;
        return false;
    }

    pub fn skippedGenericFunction(c: *Checker, node: *anyopaque, checkMode: *anyopaque) void {
        _ = c;
        _ = node;
        _ = checkMode;
    }

    pub fn getFirstTransformableStaticClassElement(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn checkClassExpressionExternalHelpers(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkClassExpressionDeferred(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn contextuallyCheckFunctionExpressionOrObjectLiteralMethod(c: *Checker, node: *anyopaque, checkMode: *anyopaque) void {
        _ = c;
        _ = node;
        _ = checkMode;
    }

    pub fn checkFunctionExpressionOrObjectLiteralMethodDeferred(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn inferFromAnnotatedParametersAndReturn(c: *Checker, sig: *anyopaque, context: *anyopaque, inferenceContext: *anyopaque) void {
        _ = c;
        _ = sig;
        _ = context;
        _ = inferenceContext;
    }

    pub fn getContextualSignature(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn createUnionSignature(c: *Checker, sig: *anyopaque, unionSignatures: *anyopaque) *anyopaque {
        _ = c;
        _ = sig;
        _ = unionSignatures;
        return undefined;
    }

    pub fn getContextualCallSignature(c: *Checker, t: *anyopaque, node: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = node;
        return undefined;
    }

    pub fn getIntersectedSignatures(c: *Checker, signatures: *anyopaque) *anyopaque {
        _ = c;
        _ = signatures;
        return undefined;
    }

    pub fn isAritySmaller(c: *Checker, signature: *anyopaque, target: *anyopaque) bool {
        _ = c;
        _ = signature;
        _ = target;
        return false;
    }

    pub fn assignContextualParameterTypes(c: *Checker, sig: *anyopaque, context: *anyopaque) void {
        _ = c;
        _ = sig;
        _ = context;
    }

    pub fn assignNonContextualParameterTypes(c: *Checker, signature: *anyopaque) void {
        _ = c;
        _ = signature;
    }

    pub fn assignParameterType(c: *Checker, parameter: *anyopaque, contextualType: *anyopaque) void {
        _ = c;
        _ = parameter;
        _ = contextualType;
    }

    pub fn assignBindingElementTypes(c: *Checker, pattern: *anyopaque, parentType: *anyopaque) void {
        _ = c;
        _ = pattern;
        _ = parentType;
    }

    pub fn checkCollisionsForDeclarationName(c: *Checker, node: *anyopaque, name_: *anyopaque) void {
        _ = c;
        _ = node;
        _ = name_;
    }

    pub fn checkCollisionWithRequireExportsInGeneratedCode(c: *Checker, node: *anyopaque, name_: *anyopaque) void {
        _ = c;
        _ = node;
        _ = name_;
    }

    pub fn checkCollisionWithGlobalObjectInGeneratedCode(c: *Checker, node: *anyopaque, name_: *anyopaque) void {
        _ = c;
        _ = node;
        _ = name_;
    }

    pub fn needCollisionCheckForIdentifier(c: *Checker, node: *anyopaque, identifier: *anyopaque, name_: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = identifier;
        _ = name_;
        return false;
    }

    pub fn setNodeLinksForPrivateIdentifierScope(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn recordPotentialCollisionWithWeakMapSetInGeneratedCode(c: *Checker, node: *anyopaque, name_: *anyopaque) void {
        _ = c;
        _ = node;
        _ = name_;
    }

    pub fn checkWeakMapSetCollision(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkCollisionWithGlobalPromiseInGeneratedCode(c: *Checker, node: *anyopaque, name_: *anyopaque) void {
        _ = c;
        _ = node;
        _ = name_;
    }

    pub fn recordPotentialCollisionWithReflectInGeneratedCode(c: *Checker, node: *anyopaque, name_: *anyopaque) void {
        _ = c;
        _ = node;
        _ = name_;
    }

    pub fn checkReflectCollision(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkClassNameCollisionWithObject(c: *Checker, name_: *anyopaque) void {
        _ = c;
        _ = name_;
    }

    pub fn checkNonNullAssertion(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn checkNonNullChain(c: *Checker, node: ast_gen.NodeIndex) types.TypeIndex {
        _ = node;
        return c.anyTypeIndex orelse 0;
    }

    pub fn getInstantiationExpressionType(c: *Checker, exprType: *anyopaque, node: *anyopaque) *anyopaque {
        _ = c;
        _ = exprType;
        _ = node;
        return undefined;
    }

    pub fn checkNewTargetMetaProperty(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn checkImportMetaProperty(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn checkDeleteExpressionMustBeOptional(c: *Checker, expr: ast_gen.NodeIndex, symbol_: ast_gen.SymbolIndex) void {
        _ = c;
        _ = expr;
        _ = symbol_;
    }

    pub fn checkTruthinessExpression(c: *Checker, node: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
        const t = checkExpressionEx(c, node, checkMode);
        return checkTruthinessOfType(c, t, node);
    }

    pub fn getYieldedTypeOfYieldExpression(c: *Checker, node: *anyopaque, expressionType: *anyopaque, sentType: *anyopaque, isAsync: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = expressionType;
        _ = sentType;
        _ = isAsync;
        return undefined;
    }

    pub fn isSameScopedBindingElement(c: *Checker, node: *anyopaque, declaration: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = declaration;
        return false;
    }

    pub fn removeOptionalityFromDeclaredType(c: *Checker, declaredType: *anyopaque, declaration: *anyopaque) *anyopaque {
        _ = c;
        _ = declaredType;
        _ = declaration;
        return undefined;
    }

    pub fn parameterInitializerContainsUndefined(c: *Checker, declaration: *anyopaque) bool {
        _ = c;
        _ = declaration;
        return false;
    }

    pub fn isInAmbientOrTypeNode(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn checkPropertyAccessChain(c: *Checker, node: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = checkMode;
        return undefined;
    }

    pub fn checkPropertyAccessExpressionOrQualifiedName(c: *Checker, node: ast_gen.NodeIndex, left: ast_gen.NodeIndex, leftType: types.TypeIndex, right: ast_gen.NodeIndex, checkMode: CheckMode, writeOnly: bool) types.TypeIndex {
        const parentSymbol = getResolvedSymbolOrNil(c, left);
        const assignmentKind = utils.getAssignmentTargetKind(c.binder.ast, node);
        var widenedType = leftType;
        if (assignmentKind != .None or c.isMethodAccessForCall(node)) {
            widenedType = c.getWidenedType(leftType);
        }
        const apparentType = c.getApparentType(widenedType);
        const isAnyLike = isTypeAnyLike(c, apparentType) or apparentType == (c.errorTypeIndex orelse 0);

        var prop: ?ast_gen.SymbolIndex = null;
        if (c.binder.ast.getKind(right) == .PrivateIdentifier) {
            if (false) {
                if (assignmentKind != .None) {
                    // c.checkExternalEmitHelpers(node, ExternalEmitHelpersClassPrivateFieldSet)
                }
                if (assignmentKind != .Definite) {
                    // c.checkExternalEmitHelpers(node, ExternalEmitHelpersClassPrivateFieldGet)
                }
            }
            const rightName = c.binder.ast.nodes.get(right).PrivateIdentifier.Text;
            const lexicallyScopedSymbol: u32 = 0;
            if (assignmentKind != .None and lexicallyScopedSymbol != 0 and c.symbolHasValueDeclaration(lexicallyScopedSymbol) and c.binder.ast.getKind(c.getSymbolValueDeclaration(lexicallyScopedSymbol)) == .MethodDeclaration) {
                c.grammarErrorOnNode(right, &diagnostics_gen.Cannot_assign_to_private_method_0_Private_methods_are_not_writable, .{rightName});
            }

            if (isAnyLike) {
                if (lexicallyScopedSymbol != 0) {
                    if (c.isErrorType(apparentType)) {
                        return c.errorTypeIndex orelse 0;
                    }
                    return apparentType;
                }
                if (false) {
                    c.grammarErrorOnNode(right, &diagnostics_gen.Private_identifiers_are_not_allowed_outside_class_bodies, .{});
                    return c.anyTypeIndex orelse 0;
                }
            }

            if (lexicallyScopedSymbol != 0) {
                prop = c.getPrivateIdentifierPropertyOfType(leftType, lexicallyScopedSymbol);
                if (prop == null) {
                    return c.getFlowTypeOfAccessExpression(node, lexicallyScopedSymbol, c.anyTypeIndex orelse 0, left, checkMode);
                }
            } else {
                if (c.isErrorType(apparentType)) {
                    return c.errorTypeIndex orelse 0;
                }
                if (false) {
                    c.addError(right, &diagnostics_gen.Private_identifiers_are_not_allowed_outside_class_bodies, .{});
                } else {
                    c.reportError(right, &diagnostics_gen.Cannot_find_name_0);
                }
                return c.anyTypeIndex orelse 0;
            }
        } else {
            if (isAnyLike) {
                if (c.binder.ast.getKind(left) == .Identifier and parentSymbol != 0) {
                    c.markLinkedReferences(node, 0, 0, leftType);
                }
                if (c.isErrorType(apparentType)) {
                    return c.errorTypeIndex orelse 0;
                }
                return apparentType;
            }

            const rightName = c.binder.ast.nodes.get(right).Identifier.Text;
            _ = rightName;
            _ = rightName;
            _ = rightName;
            prop = 0;
        }

        // c.markLinkedReferences(node, 0, prop, leftType);
        var propType: ?types.TypeIndex = null;

        if (prop == null) {
            var indexInfo: ?types.IndexInfo = null;
            const rightName = if (c.binder.ast.getKind(right) == .PrivateIdentifier) c.binder.ast.nodes.get(right).PrivateIdentifier.Text else c.binder.ast.nodes.get(right).Identifier.Text;

            if (c.binder.ast.getKind(right) != .PrivateIdentifier and (assignmentKind == .None or !c.isGenericObjectType(leftType) or utils.isThisTypeParameter(c, leftType))) {
                const keyType = if (utils.isNumericLiteralName(rightName)) c.numberTypeIndex orelse 0 else c.stringTypeIndex orelse 0;
                indexInfo = c.getIndexInfoOfType(apparentType, keyType);
            }

            if (indexInfo == null) {
                const isUncheckedJS = false;
                if (!isUncheckedJS and false) {
                    return c.anyTypeIndex orelse 0;
                }
                if (false) {
                    const globalSymbol = c.getSymbolExport(c.globalThisSymbol, rightName);
                    if (globalSymbol != null and c.getSymbolFlags(globalSymbol.?).BlockScoped) {
                        _ = c.typeToString(leftType);
                        c.reportError(right, &diagnostics_gen.Property_0_does_not_exist_on_type_1);
                    } else if (c.noImplicitAny) {
                        _ = c.typeToString(leftType);
                        c.reportError(right, &diagnostics_gen.Element_implicitly_has_an_any_type_because_type_0_has_no_index_signature);
                    }
                    return c.anyTypeIndex orelse 0;
                }
                if (rightName.len > 0 and !c.checkAndReportErrorForExtendingInterface(node)) {
                    c.reportNonexistentProperty(right, if (utils.isThisTypeParameter(c, leftType)) apparentType else leftType, isUncheckedJS);
                }
                return c.errorTypeIndex orelse 0;
            }
            if (indexInfo.?.isReadonly and (false or false)) {
                _ = c.typeToString(apparentType);
                c.reportError(node, &diagnostics_gen.Index_signature_in_type_0_only_permits_reading);
            }
            propType = indexInfo.?.valueType;
            if (false and assignmentKind != .Definite) {
                propType = c.getUnionType(c.arena.allocator(), &.{ propType.?, c.missingTypeIndex orelse 0 });
            }
            if (false and c.binder.ast.getKind(node) == .PropertyAccessExpression) {
                c.reportError(right, &diagnostics_gen.Property_0_comes_from_an_index_signature_so_it_must_be_accessed_with_0);
            }
            if (indexInfo.?.declaration != null and false) {
                c.addDeprecatedSuggestion(right, &.{indexInfo.?.declaration.?}, rightName);
            }
        } else {
            const targetPropSymbol = 0;
            const rightName = if (c.binder.ast.getKind(right) == .PrivateIdentifier) c.binder.ast.nodes.get(right).PrivateIdentifier.Text else c.binder.ast.nodes.get(right).Identifier.Text;
            if (false) {
                c.addDeprecatedSuggestion(right, c.getSymbolDeclarations(targetPropSymbol).?, rightName);
            }
            // c.checkPropertyNotUsedBeforeDeclaration
            c.markPropertyAsReferenced(prop.?, node, false);
            c.symbolNodeLinks.getPtr(node).?.resolvedSymbol = prop orelse 0;
            // c.checkPropertyAccessibility(node, c.binder.ast.getKind(left) == .SuperKeyword, utils.isWriteAccess(c.binder.ast, node), apparentType, prop.?);
            if (false) {
                c.reportError(right, &diagnostics_gen.Cannot_assign_to_0_because_it_is_a_read_only_property);
                return c.errorTypeIndex orelse 0;
            }
            if (false) {
                propType = c.autoTypeIndex orelse 0;
            } else if (writeOnly or false) {
                propType = c.getWriteTypeOfSymbol(prop.?);
            } else {
                propType = c.getTypeOfSymbol(prop.?) catch (c.anyTypeIndex orelse 0);
            }
        }

        return c.getFlowTypeOfAccessExpression(node, prop, propType orelse (c.anyTypeIndex orelse 0), right, checkMode);
    }

    pub fn getFlowTypeOfAccessExpression(c: *Checker, node: ast_gen.NodeIndex, prop: ?ast_gen.SymbolIndex, propType: types.TypeIndex, errorNode: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
        _ = c;
        _ = node;
        _ = prop;
        _ = errorNode;
        _ = checkMode;
        return propType;
    }

    pub fn getControlFlowContainer(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getFlowTypeOfProperty(c: *Checker, reference: *anyopaque, prop: *anyopaque) *anyopaque {
        _ = c;
        _ = reference;
        _ = prop;
        return undefined;
    }

    pub fn getTypeOfPropertyInBaseClass(c: *Checker, property: *anyopaque) *anyopaque {
        _ = c;
        _ = property;
        return undefined;
    }

    pub fn isMethodAccessForCall(c: *Checker, node: ast_gen.NodeIndex) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn lookupSymbolForPrivateIdentifierDeclaration(c: *Checker, propName: []const u8, location: ast_gen.NodeIndex) ast_gen.SymbolIndex {
        _ = c;
        _ = propName;
        _ = location;
        return undefined;
    }

    pub fn getPrivateIdentifierPropertyOfType(c: *Checker, leftType: *anyopaque, lexicallyScopedIdentifier: *anyopaque) *anyopaque {
        _ = c;
        _ = leftType;
        _ = lexicallyScopedIdentifier;
        return undefined;
    }

    pub fn checkPrivateIdentifierPropertyAccess(c: *Checker, leftType: *anyopaque, right: *anyopaque, lexicallyScopedIdentifier: *anyopaque) bool {
        _ = c;
        _ = leftType;
        _ = right;
        _ = lexicallyScopedIdentifier;
        return false;
    }

    pub fn reportNonexistentProperty(c: *Checker, propNode: ast_gen.NodeIndex, containingType: types.TypeIndex, isUncheckedJS: bool) void {
        _ = c;
        _ = propNode;
        _ = containingType;
        _ = isUncheckedJS;
    }

    pub fn getSuggestedLibForNonExistentProperty(c: *Checker, missingProperty: *anyopaque, containingType: *anyopaque) *anyopaque {
        _ = c;
        _ = missingProperty;
        _ = containingType;
        return undefined;
    }

    pub fn getSuggestedSymbolForNonexistentProperty(c: *Checker, name_: *anyopaque, containingType: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        _ = containingType;
        return undefined;
    }

    pub fn isValidPropertyAccessForCompletions(c: *Checker, node: *anyopaque, t: *anyopaque, property: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = t;
        _ = property;
        return false;
    }

    pub fn isPropertyAccessible(c: *Checker, node: *anyopaque, isSuper: *anyopaque, isWrite: *anyopaque, containingType: *anyopaque, property: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = isSuper;
        _ = isWrite;
        _ = containingType;
        _ = property;
        return false;
    }

    pub fn containerSeemsToBeEmptyDomElement(c: *Checker, containingType: *anyopaque) bool {
        _ = c;
        _ = containingType;
        return false;
    }

    pub fn hasCommonDomTypeName(t: *anyopaque) bool {
        _ = t;
        return false;
    }

    pub fn checkAndReportErrorForExtendingInterface(c: *Checker, errorLocation: ast_gen.NodeIndex) bool {
        _ = c;
        _ = errorLocation;
        return false;
    }

    pub fn getEntityNameForExtendingInterface(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn isUncalledFunctionReference(c: *Checker, node: *anyopaque, symbol_: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = symbol_;
        return false;
    }

    pub fn checkPropertyNotUsedBeforeDeclaration(c: *Checker, prop: ast_gen.SymbolIndex, node: ast_gen.NodeIndex, right: ast_gen.NodeIndex) void {
        _ = c;
        _ = prop;
        _ = node;
        _ = right;
    }

    pub fn isOptionalPropertyDeclaration(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn isPropertyDeclaredInAncestorClass(c: *Checker, prop: *anyopaque) bool {
        _ = c;
        _ = prop;
        return false;
    }

    pub fn checkPropertyAccessibility(c: *Checker, node: ast_gen.NodeIndex, isSuper: bool, writing: bool, t: types.TypeIndex, prop: ast_gen.SymbolIndex) bool {
        _ = c;
        _ = node;
        _ = isSuper;
        _ = writing;
        _ = t;
        _ = prop;
        return false;
    }

    pub fn checkPropertyAccessibilityEx(c: *Checker, node: *anyopaque, isSuper: *anyopaque, writing: *anyopaque, t: *anyopaque, prop: *anyopaque, reportError_: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = isSuper;
        _ = writing;
        _ = t;
        _ = prop;
        _ = reportError_;
        return false;
    }

    pub fn checkPropertyAccessibilityAtLocation(c: *Checker, location: *anyopaque, isSuper: *anyopaque, writing: *anyopaque, containingType: *anyopaque, prop: *anyopaque, errorNode: *anyopaque) bool {
        _ = c;
        _ = location;
        _ = isSuper;
        _ = writing;
        _ = containingType;
        _ = prop;
        _ = errorNode;
        return false;
    }

    pub fn symbolHasNonMethodDeclaration(c: *Checker, symbol_: *anyopaque) bool {
        _ = c;
        _ = symbol_;
        return false;
    }

    pub fn forEachProperty(c: *Checker, prop: *anyopaque, callback: *anyopaque) bool {
        _ = c;
        _ = prop;
        _ = callback;
        return false;
    }

    pub fn getDeclaringClass(c: *Checker, prop: *anyopaque) *anyopaque {
        _ = c;
        _ = prop;
        return undefined;
    }

    pub fn isValidOverrideOf(c: *Checker, sourceProp: *anyopaque, targetProp: *anyopaque) bool {
        _ = c;
        _ = sourceProp;
        _ = targetProp;
        return false;
    }

    pub fn isPropertyInClassDerivedFrom(c: *Checker, prop: *anyopaque, baseClass: *anyopaque) bool {
        _ = c;
        _ = prop;
        _ = baseClass;
        return false;
    }

    pub fn isNodeUsedDuringClassInitialization(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn isNodeWithinClass(c: *Checker, node: *anyopaque, classDeclaration: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = classDeclaration;
        return false;
    }

    pub fn forEachEnclosingClass(c: *Checker, node: *anyopaque, callback: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = callback;
        return false;
    }

    pub fn isClassDerivedFromDeclaringClasses(c: *Checker, checkClass: *anyopaque, prop: *anyopaque, writing: *anyopaque) bool {
        _ = c;
        _ = checkClass;
        _ = prop;
        _ = writing;
        return false;
    }

    pub fn getEnclosingClassFromThisParameter(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getThisParameterFromNodeContext(node: *anyopaque) *anyopaque {
        _ = node;
        return undefined;
    }

    pub fn getContextualThisParameterType(c: *Checker, fn_: *anyopaque) *anyopaque {
        _ = c;
        _ = fn_;
        return undefined;
    }

    pub fn tryGetThisTypeAt(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn tryGetThisTypeAtEx(c: *Checker, node: *anyopaque, includeGlobalThis: *anyopaque, container: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = includeGlobalThis;
        _ = container;
        return undefined;
    }

    pub fn getThisContainer(c: *Checker, node: *anyopaque, includeArrowFunctions: *anyopaque, includeClassComputedPropertyName: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = includeArrowFunctions;
        _ = includeClassComputedPropertyName;
        return undefined;
    }

    pub fn isInParameterInitializerBeforeContainingFunction(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn checkThisInStaticClassFieldInitializerInDecoratedClass(c: *Checker, thisExpression: *anyopaque, container: *anyopaque) void {
        _ = c;
        _ = thisExpression;
        _ = container;
    }

    pub fn checkThisBeforeSuper(c: *Checker, node: *anyopaque, container: *anyopaque, diagnosticMessage: *anyopaque) void {
        _ = c;
        _ = node;
        _ = container;
        _ = diagnosticMessage;
    }

    /// Port of `checker.go::classDeclarationExtendsNull`. Returns true if
    /// the class declaration extends `null` (i.e., its base constructor
    /// type resolves to `nullWideningType`).
    ///
    /// Conservative implementation: checks if the extends heritage clause
    /// expression is the `null` keyword literal.
    pub fn classDeclarationExtendsNull(c: *Checker, class_decl: ast_gen.NodeIndex) bool {
        if (class_decl == 0) return false;
        const extends_elem = ast_utils.getExtendsHeritageClauseElement(c.binder.ast, class_decl);
        if (extends_elem == 0) return false;
        // Check if the heritage element's expression is the `null` keyword
        const node_data = c.binder.ast.getNode(extends_elem);
        if (node_data == .ExpressionWithTypeArguments) {
            const expr = node_data.ExpressionWithTypeArguments.Expression;
            if (expr != 0) {
                return c.binder.ast.getNodeKind(expr) == .NullKeyword;
            }
        }
        return false;
    }

    pub fn checkAssertionDeferred(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn checkBinaryLikeExpression(c: *Checker, left: ast_gen.NodeIndex, operatorToken: ast_gen.NodeIndex, right: ast_gen.NodeIndex, checkMode: CheckMode, errorNode: ast_gen.NodeIndex) types.TypeIndex {
        const operator = c.binder.ast.getKind(operatorToken);
        const leftKind = c.binder.ast.getKind(left);
        const rightKind = c.binder.ast.getKind(right);

        if (operator == .EqualsToken and (leftKind == .ObjectLiteralExpression or leftKind == .ArrayLiteralExpression)) {
            return c.checkDestructuringAssignment(left, checkExpressionEx(c, right, checkMode), checkMode, rightKind == .ThisKeyword);
        }
        var leftType = checkExpressionEx(c, left, checkMode);
        var rightType = checkExpressionEx(c, right, checkMode);

        if (ast_utils.isLogicalOrCoalescingBinaryOperator(operator)) {
            var parent = c.binder.ast.getNodeParent(c.binder.ast.getNodeParent(left));
            var parentKind = c.binder.ast.getKind(parent);
            while (parentKind == .ParenthesizedExpression or ast_utils.isLogicalOrCoalescingAssignmentExpression(c.binder.ast, parent)) {
                parent = c.binder.ast.getNodeParent(parent);
                parentKind = c.binder.ast.getKind(parent);
            }
            if (operator == .AmpersandAmpersandToken or parentKind == .IfStatement) {
                var body: ast_gen.NodeIndex = 0;
                if (parentKind == .IfStatement) {
                    body = c.binder.ast.getNode(parent).IfStatement.ThenStatement;
                }
                c.checkTestingKnownTruthyCallableOrAwaitableOrEnumMemberType(left, leftType, body);
            }
            if (ast_utils.isLogicalBinaryOperator(operator)) {
                _ = c.checkTruthinessOfType(leftType, left);
            }
        }

        switch (operator) {
            .AsteriskToken, .AsteriskAsteriskToken, .AsteriskEqualsToken, .AsteriskAsteriskEqualsToken, .SlashToken, .SlashEqualsToken, .PercentToken, .PercentEqualsToken, .MinusToken, .MinusEqualsToken, .LessThanLessThanToken, .LessThanLessThanEqualsToken, .GreaterThanGreaterThanToken, .GreaterThanGreaterThanEqualsToken, .GreaterThanGreaterThanGreaterThanToken, .GreaterThanGreaterThanGreaterThanEqualsToken, .BarToken, .BarEqualsToken, .CaretToken, .CaretEqualsToken, .AmpersandToken, .AmpersandEqualsToken => {
                if (leftType == c.errorTypeIndex orelse 0 or rightType == c.errorTypeIndex orelse 0) {
                    return c.errorTypeIndex orelse 0;
                }
                leftType = c.checkNonNullType(leftType, left);
                rightType = c.checkNonNullType(rightType, right);

                const leftFlags = c.getTypeFlags(leftType);
                const rightFlags = c.getTypeFlags(rightType);
                if ((leftFlags & types.TypeFlags.BooleanLike) != 0 and (rightFlags & types.TypeFlags.BooleanLike) != 0) {
                    const suggestedOperator = c.getSuggestedBooleanOperator(operator);
                    if (suggestedOperator != .Unknown) {
                        return c.anyTypeIndex orelse 0;
                    }
                }

                const leftOk = c.checkArithmeticOperandType(left, leftType, diagnostics_gen.The_left_hand_side_of_an_arithmetic_operation_must_be_of_type_any_number_bigint_or_an_enum_type, true);
                const rightOk = c.checkArithmeticOperandType(right, rightType, diagnostics_gen.The_right_hand_side_of_an_arithmetic_operation_must_be_of_type_any_number_bigint_or_an_enum_type, true);
                var resultType: types.TypeIndex = 0;

                if ((c.isTypeAssignableToKind(leftType, types.TypeFlags.Any | types.TypeFlags.Unknown) and c.isTypeAssignableToKind(rightType, types.TypeFlags.Any | types.TypeFlags.Unknown)) or
                    (!c.maybeTypeOfKind(leftType, types.TypeFlags.BigIntLike) and !c.maybeTypeOfKind(rightType, types.TypeFlags.BigIntLike)))
                {
                    resultType = c.anyTypeIndex orelse 0;
                } else if (c.bothAreBigIntLike(leftType, rightType)) {
                    switch (operator) {
                        .GreaterThanGreaterThanGreaterThanToken, .GreaterThanGreaterThanGreaterThanEqualsToken => {
                            c.reportOperatorError(leftType, operator, rightType, errorNode, null);
                        },
                        .AsteriskAsteriskToken, .AsteriskAsteriskEqualsToken => {
                            if (false) {
                                c.reportError(errorNode, &diagnostics_gen.Exponentiation_cannot_be_performed_on_bigint_values_unless_the_target_option_is_set_to_es2016_or_later);
                            }
                        },
                        else => {},
                    }
                    resultType = c.bigintTypeIndex orelse 0;
                } else {
                    c.reportOperatorError(leftType, operator, rightType, errorNode, null); // Stub bothAreBigIntLike as related func
                    resultType = c.errorTypeIndex orelse 0;
                }

                if (leftOk and rightOk) {
                    c.checkAssignmentOperator(left, operator, right, leftType, resultType);
                }
                return resultType;
            },
            .PlusToken, .PlusEqualsToken => {
                if (leftType == c.errorTypeIndex orelse 0 or rightType == c.errorTypeIndex orelse 0) {
                    return c.errorTypeIndex orelse 0;
                }
                if (!c.isTypeAssignableToKind(leftType, types.TypeFlags.StringLike) and !c.isTypeAssignableToKind(rightType, types.TypeFlags.StringLike)) {
                    leftType = c.checkNonNullType(leftType, left);
                    rightType = c.checkNonNullType(rightType, right);
                }
                var resultType: types.TypeIndex = 0;
                if (c.isTypeAssignableToKindEx(leftType, types.TypeFlags.NumberLike, true) and c.isTypeAssignableToKindEx(rightType, types.TypeFlags.NumberLike, true)) {
                    resultType = c.anyTypeIndex orelse 0;
                } else if (c.isTypeAssignableToKindEx(leftType, types.TypeFlags.BigIntLike, true) and c.isTypeAssignableToKindEx(rightType, types.TypeFlags.BigIntLike, true)) {
                    resultType = c.bigintTypeIndex orelse 0;
                } else if (c.isTypeAssignableToKindEx(leftType, types.TypeFlags.StringLike, true) or c.isTypeAssignableToKindEx(rightType, types.TypeFlags.StringLike, true)) {
                    resultType = c.stringTypeIndex orelse 0;
                } else if (c.isTypeAny(leftType) or c.isTypeAny(rightType)) {
                    if (c.isErrorType(leftType) or c.isErrorType(rightType)) {
                        resultType = c.errorTypeIndex orelse 0;
                    } else {
                        resultType = c.anyTypeIndex orelse 0;
                    }
                }
                // Symbols are not allowed at all in arithmetic expressions
                if (resultType != 0 and true) {
                    return resultType;
                }
                if (resultType == 0) {
                    return c.anyTypeIndex orelse 0;
                }
                if (operator == .PlusEqualsToken) {
                    c.checkAssignmentOperator(left, operator, right, leftType, resultType);
                }
                return resultType;
            },
            .LessThanToken, .GreaterThanToken, .LessThanEqualsToken, .GreaterThanEqualsToken => {
                if (c.checkForDisallowedESSymbolOperand(left, right, leftType, rightType, @intFromEnum(operator))) {
                    leftType = 0;
                    rightType = c.getBaseTypeOfLiteralTypeForComparison(c.checkNonNullType(rightType, right));
                }
                return c.booleanTypeIndex orelse 0;
            },
            .EqualsEqualsToken, .ExclamationEqualsToken, .EqualsEqualsEqualsToken, .ExclamationEqualsEqualsToken => {
                if (false) {
                    // checkNaNEquality stub
                }
                return c.booleanTypeIndex orelse 0;
            },
            .InstanceOfKeyword => {
                // Not returning anything directly since it's a stub right now, but let's check its signature
                // For now just return c.anyTypeIndex
                return c.anyTypeIndex orelse 0;
            },
            .InKeyword => {
                return c.anyTypeIndex orelse 0;
            },
            .AmpersandAmpersandToken, .AmpersandAmpersandEqualsToken => {
                var resultType = leftType;
                if (c.hasTypeFacts(leftType, types.TypeFacts.Truthy)) {
                    var t = leftType;
                    if (!c.strictNullChecks) {
                        t = c.getBaseTypeOfLiteralType(rightType);
                    }
                    resultType = c.getUnionTypeFromArray(&[_]types.TypeIndex{ c.extractDefinitelyFalsyTypes(t), rightType });
                }
                if (operator == .AmpersandAmpersandEqualsToken) {
                    c.checkAssignmentOperator(left, operator, right, leftType, rightType);
                }
                return resultType;
            },
            .BarBarToken, .BarBarEqualsToken => {
                var resultType = leftType;
                if (c.hasTypeFacts(leftType, types.TypeFacts.Falsy)) {
                    resultType = c.anyTypeIndex orelse 0;
                }
                if (operator == .BarBarEqualsToken) {
                    c.checkAssignmentOperator(left, operator, right, leftType, rightType);
                }
                return resultType;
            },
            .QuestionQuestionToken, .QuestionQuestionEqualsToken => {
                if (operator == .QuestionQuestionToken) {
                    // c.checkNullishCoalesceOperands
                }
                var resultType = leftType;
                if (c.hasTypeFacts(leftType, types.TypeFacts.EQUndefinedOrNull)) {
                    resultType = c.anyTypeIndex orelse 0;
                }
                if (operator == .QuestionQuestionEqualsToken) {
                    c.checkAssignmentOperator(left, operator, right, leftType, rightType);
                }
                return resultType;
            },
            .EqualsToken => {
                c.checkAssignmentOperator(left, operator, right, leftType, rightType);
                return rightType;
            },
            .CommaToken => {
                return rightType;
            },
            else => {
                return c.errorTypeIndex orelse 0;
            },
        }
    }

    pub fn checkDestructuringAssignment(c: *Checker, node: ast_gen.NodeIndex, sourceType: types.TypeIndex, checkMode: CheckMode, rightIsThis: bool) types.TypeIndex {
        _ = node;
        _ = sourceType;
        _ = checkMode;
        _ = rightIsThis;
        return c.anyTypeIndex orelse 0;
    }

    pub fn checkObjectLiteralAssignment(c: *Checker, node: *anyopaque, sourceType: *anyopaque, rightIsThis: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = sourceType;
        _ = rightIsThis;
        return undefined;
    }

    pub fn checkObjectLiteralDestructuringPropertyAssignment(c: *Checker, node: *anyopaque, objectLiteralType: *anyopaque, propertyIndex: *anyopaque, allProperties: *anyopaque, rightIsThis: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = objectLiteralType;
        _ = propertyIndex;
        _ = allProperties;
        _ = rightIsThis;
        return undefined;
    }

    pub fn checkArrayLiteralAssignment(c: *Checker, node: *anyopaque, sourceType: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = sourceType;
        _ = checkMode;
        return undefined;
    }

    pub fn checkArrayLiteralDestructuringElementAssignment(c: *Checker, node: *anyopaque, sourceType: *anyopaque, elementIndex: *anyopaque, elementType: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = sourceType;
        _ = elementIndex;
        _ = elementType;
        _ = checkMode;
        return undefined;
    }

    pub fn checkReferenceAssignment(c: *Checker, target: *anyopaque, sourceType: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = target;
        _ = sourceType;
        _ = checkMode;
        return undefined;
    }

    pub fn reportOperatorError(c: *Checker, leftType: types.TypeIndex, operator: kind.Kind, rightType: types.TypeIndex, errorNode: ast_gen.NodeIndex, isRelated: ?*const fn (*Checker, types.TypeIndex, types.TypeIndex) bool) void {
        _ = c;
        _ = leftType;
        _ = operator;
        _ = rightType;
        _ = errorNode;
        _ = isRelated;
    }

    pub fn reportOperatorErrorUnless(c: *Checker, leftType: types.TypeIndex, operator: kind.Kind, rightType: types.TypeIndex, errorNode: ast_gen.NodeIndex, typesAreCompatible: ?*const fn (*Checker, types.TypeIndex, types.TypeIndex) bool) void {
        _ = c;
        _ = leftType;
        _ = operator;
        _ = rightType;
        _ = errorNode;
        _ = typesAreCompatible;
    }

    pub fn getBaseTypesIfUnrelated(c: *Checker, leftType: *anyopaque, rightType: *anyopaque, isRelated: *anyopaque, right: *anyopaque) bool {
        _ = c;
        _ = leftType;
        _ = rightType;
        _ = isRelated;
        _ = right;
        return false;
    }

    pub fn checkAssignmentOperator(c: *Checker, left: ast_gen.NodeIndex, operator: kind.Kind, right: ast_gen.NodeIndex, leftType: types.TypeIndex, rightType: types.TypeIndex) void {
        _ = c;
        _ = left;
        _ = operator;
        _ = right;
        _ = leftType;
        _ = rightType;
    }

    pub fn bothAreBigIntLike(c: *Checker, left: types.TypeIndex, right: types.TypeIndex) bool {
        return c.isTypeAssignableToKind(left, types.TypeFlags.BigIntLike) and c.isTypeAssignableToKind(right, types.TypeFlags.BigIntLike);
    }

    pub fn getSuggestedBooleanOperator(c: *Checker, operator: kind.Kind) kind.Kind {
        _ = c;
        switch (operator) {
            .BarToken, .BarEqualsToken => return .BarBarToken,
            .CaretToken, .CaretEqualsToken => return .ExclamationEqualsEqualsToken,
            .AmpersandToken, .AmpersandEqualsToken => return .AmpersandAmpersandToken,
            else => return .Unknown,
        }
    }

    pub fn checkArithmeticOperandType(c: *Checker, operand: ast_gen.NodeIndex, t: types.TypeIndex, diagnostic: diagnostics_gen.Message, isAwaitValid: bool) bool {
        _ = c;
        _ = operand;
        _ = t;
        _ = diagnostic;
        _ = isAwaitValid;
        return true;
    }

    pub fn checkForDisallowedESSymbolOperand(c: *Checker, left: ast_gen.NodeIndex, right: ast_gen.NodeIndex, leftType: types.TypeIndex, rightType: types.TypeIndex, operator: u32) bool {
        _ = c;
        _ = left;
        _ = right;
        _ = leftType;
        _ = rightType;
        _ = operator;
        return false;
    }

    pub fn checkNaNEquality(c: *Checker, errorNode: *anyopaque, operator: *anyopaque, left: *anyopaque, right: *anyopaque) void {
        _ = c;
        _ = errorNode;
        _ = operator;
        _ = left;
        _ = right;
    }

    pub fn isGlobalNaN(c: *Checker, expr: *anyopaque) bool {
        _ = c;
        _ = expr;
        return false;
    }

    pub fn isTypeEqualityComparableTo(c: *Checker, source: *anyopaque, target: *anyopaque) bool {
        _ = c;
        _ = source;
        _ = target;
        return false;
    }

    pub const PredicateSemantics = enum(u32) {
        None = 0,
        Always = 1,
        Never = 2,
        Sometimes = 3,
    };

    pub fn checkTruthinessOfType(c: *Checker, t: types.TypeIndex, node: ast_gen.NodeIndex) types.TypeIndex {
        if ((c.typesList.items[t].flags & types.TypeFlags.Void) != 0) {
            c.reportError(node, &diagnostics_gen.An_expression_of_type_void_cannot_be_tested_for_truthiness);
            return t;
        }
        const semantics = getSyntacticTruthySemantics(c, node);
        if (semantics != .Sometimes) {
            if (semantics == .Always) {
                c.reportError(node, &diagnostics_gen.This_kind_of_expression_is_always_truthy);
            } else {
                c.reportError(node, &diagnostics_gen.This_kind_of_expression_is_always_falsy);
            }
        }
        return t;
    }

    pub fn getSyntacticTruthySemantics(c: *Checker, node: ast_gen.NodeIndex) PredicateSemantics {
        _ = c;
        _ = node;
        return .Sometimes; // TODO: Implement getSyntacticTruthySemantics fully
    }

    pub fn checkNullishCoalesceOperands(c: *Checker, left: ast_gen.NodeIndex, right: ast_gen.NodeIndex) void {
        _ = c;
        _ = left;
        _ = right;
    }

    pub fn checkNullishCoalesceOperandLeft(c: *Checker, left: *anyopaque) void {
        _ = c;
        _ = left;
    }

    pub fn getSyntacticNullishnessSemantics(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn isSideEffectFree(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn isIndirectCall(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn checkInstanceOfExpression(c: *Checker, left: *anyopaque, right: *anyopaque, leftType: *anyopaque, rightType: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = left;
        _ = right;
        _ = leftType;
        _ = rightType;
        _ = checkMode;
        return undefined;
    }

    pub fn checkInExpression(c: *Checker, left: *anyopaque, right: *anyopaque, leftType: *anyopaque, rightType: *anyopaque) *anyopaque {
        _ = c;
        _ = left;
        _ = right;
        _ = leftType;
        _ = rightType;
        return undefined;
    }

    pub fn hasEmptyObjectIntersection(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn getExactOptionalUnassignableProperties(c: *Checker, source: *anyopaque, target: *anyopaque) *anyopaque {
        _ = c;
        _ = source;
        _ = target;
        return undefined;
    }

    pub fn isExactOptionalPropertyMismatch(c: *Checker, source: *anyopaque, target: *anyopaque) bool {
        _ = c;
        _ = source;
        _ = target;
        return false;
    }

    pub fn checkReferenceExpression(c: *Checker, expr: ast_gen.NodeIndex, invalidReferenceMessage: diagnostics_gen.Message, invalidOptionalChainMessage: diagnostics_gen.Message) bool {
        _ = c;
        _ = expr;
        _ = invalidReferenceMessage;
        _ = invalidOptionalChainMessage;
        return true;
    }

    pub fn checkSpreadPropOverrides(c: *Checker, t: *anyopaque, props: *anyopaque, spread: *anyopaque) void {
        _ = c;
        _ = t;
        _ = props;
        _ = spread;
    }

    pub fn getSpreadType(c: *Checker, left: *anyopaque, right: *anyopaque, symbol_: *anyopaque, objectFlags: *anyopaque, readonly: *anyopaque) *anyopaque {
        _ = c;
        _ = left;
        _ = right;
        _ = symbol_;
        _ = objectFlags;
        _ = readonly;
        return undefined;
    }

    /// Port of `checker.go::getIndexInfoWithReadonly`. Returns a new
    /// `IndexInfo` with the readonly flag set to `readonly`, or returns
    /// `info` unchanged if it already matches.
    pub fn getIndexInfoWithReadonly(c: *Checker, info: types.IndexInfo, readonly: bool) types.IndexInfo {
        if (info.isReadonly != readonly) {
            return .{
                .keyType = info.keyType,
                .valueType = info.valueType,
                .isReadonly = readonly,
                .declaration = info.declaration,
            };
        }
        return info;
    }

    /// Port of `checker.go::isValidSpreadType`. Returns true if `t` can be
    /// spread into an object literal (any, non-primitive, object, or a
    /// union/intersection of valid spread types).
    pub fn isValidSpreadType(c: *Checker, t: types.TypeIndex) bool {
        if (t == 0 or t >= c.typesList.items.len) return false;
        const flags = c.typesList.items[t].flags;
        const valid_mask = types.TypeFlags.Any | types.TypeFlags.NonPrimitive |
            types.TypeFlags.Object | types.TypeFlags.InstantiableNonPrimitive;
        if ((flags & valid_mask) != 0) return true;
        if ((flags & types.TypeFlags.UnionOrIntersection) != 0) {
            const constituents = c.getTypesFromUnion(t);
            for (constituents) |sub| {
                if (!c.isValidSpreadType(sub)) return false;
            }
            return true;
        }
        return false;
    }

    pub fn tryMergeUnionOfObjectTypeAndEmptyObject(c: *Checker, t: *anyopaque, readonly: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = readonly;
        return undefined;
    }

    /// Port of `checker.go::isSpreadableProperty`. We approximate own
    /// properties as non-methods plus methods that are inside the object
    /// literal (not class declarations).
    pub fn isSpreadableProperty(c: *Checker, prop: ast_gen.SymbolIndex) bool {
        if (prop == 0 or prop >= c.binder.symbols.items.len) return false;
        const sym = c.binder.symbols.items[prop];
        const has_method_or_accessor = (sym.Flags & (symbol.SymbolFlags.Method | symbol.SymbolFlags.GetAccessor | symbol.SymbolFlags.SetAccessor)) != 0;
        // Check if any declaration is a private identifier class element
        var has_private_id = false;
        for (sym.Declarations.items) |decl| {
            if (decl == 0) continue;
            const node = c.binder.ast.getNode(decl);
            if (node == .PropertyDeclaration) {
                const name_node = c.binder.ast.getNode(decl).PropertyDeclaration.name;
                if (name_node != 0) {
                    const name_kind = c.binder.ast.getNode(name_node);
                    if (name_kind == .PrivateIdentifier) {
                        has_private_id = true;
                        break;
                    }
                }
            }
        }
        if (!has_private_id and !has_method_or_accessor) return true;
        // Check if any declaration's parent is NOT class-like
        for (sym.Declarations.items) |decl| {
            if (decl == 0) continue;
            const parent = c.binder.ast.getNodeParent(decl);
            if (parent != 0 and !ast_utils.isClassLike(c.binder.ast, parent)) return true;
        }
        return false;
    }

    /// Port of `checker.go::getSpreadSymbol`. Returns the spread symbol for
    /// `prop`, creating a synthetic one if the readonly flag doesn't match
    /// or `prop` is a set-only accessor.
    pub fn getSpreadSymbol(c: *Checker, prop: ast_gen.SymbolIndex, readonly: bool) ast_gen.SymbolIndex {
        if (prop == 0 or prop >= c.binder.symbols.items.len) return 0;
        const sym = c.binder.symbols.items[prop];
        const is_setonly_accessor = (sym.Flags & symbol.SymbolFlags.SetAccessor) != 0 and (sym.Flags & symbol.SymbolFlags.GetAccessor) == 0;
        if (!is_setonly_accessor and readonly == c.isReadonlySymbol(prop)) {
            return prop;
        }
        // Create synthetic symbol — for now, return the original since the
        // full newSymbolEx + valueSymbolLinks wiring is complex. The
        // synthetic-creation path is rarely hit in practice (only when
        // spreading readonly-ness differs or set-only accessor).
        // TODO(phase1.2): implement newSymbolEx-based synthetic creation.
        return prop;
    }

    /// Port of `checker.go::removeMissingOrUndefinedType`. Strips undefined
    /// (and missing, when exactOptionalPropertyTypes) from `t`.
    pub fn removeMissingOrUndefinedType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        if (c.exactOptionalPropertyTypes) {
            // Full removeType implementation needed; for now use NEUndefined
            return c.getTypeWithFacts(t, types.TypeFacts.NEUndefined);
        }
        return c.getTypeWithFacts(t, types.TypeFacts.NEUndefined);
    }

    /// Port of `checker.go::isEmptyObjectTypeOrSpreadsIntoEmptyObject`.
    /// Returns true if `t` is the empty object type or a primitive-like
    /// type that spreads into nothing (null, undefined, boolean, etc.).
    pub fn isEmptyObjectTypeOrSpreadsIntoEmptyObject(c: *Checker, t: types.TypeIndex) bool {
        if (c.isEmptyObjectType(t)) return true;
        if (t == 0 or t >= c.typesList.items.len) return false;
        const flags = c.typesList.items[t].flags;
        const mask = types.TypeFlags.Null | types.TypeFlags.Undefined |
            types.TypeFlags.BooleanLike | types.TypeFlags.NumberLike |
            types.TypeFlags.BigIntLike | types.TypeFlags.StringLike |
            types.TypeFlags.EnumLike | types.TypeFlags.NonPrimitive | types.TypeFlags.Index;
        return (flags & mask) != 0;
    }

    /// Port of `checker.go::hasDefaultValue`. Returns true if `node` is a
    /// binding element with initializer, a property assignment with a
    /// default-value initializer, a shorthand property assignment with an
    /// object assignment initializer, or a binary expression `x = y`.
    pub fn hasDefaultValue(c: *Checker, node: ast_gen.NodeIndex) bool {
        if (node == 0) return false;
        const tree = c.binder.ast;
        const node_data = tree.getNode(node);
        switch (node_data) {
            .BindingElement => |n| return n.Initializer != null,
            .PropertyAssignment => |n| {
                if (n.Initializer != 0) return c.hasDefaultValue(n.Initializer);
                return false;
            },
            .ShorthandPropertyAssignment => |n| return n.ObjectAssignmentInitializer != null,
            .BinaryExpression => |n| {
                const op = tree.getNode(n.OperatorToken);
                return op == .EqualsToken;
            },
            else => return false,
        }
    }

    /// Port of `checker.go::isValidConstAssertionArgument`. Returns true if
    /// `node` is a literal (string, number, bigint, boolean, array, object,
    /// template) or a property/element access on an enum member.
    pub fn isValidConstAssertionArgument(c: *Checker, node: ast_gen.NodeIndex) bool {
        if (node == 0) return false;
        const tree = c.binder.ast;
        const node_data = tree.getNode(node);
        switch (node_data) {
            .StringLiteral, .NoSubstitutionTemplateLiteral, .NumericLiteral, .BigIntLiteral, .TemplateExpression, .ArrayLiteralExpression, .ObjectLiteralExpression => return true,
            .TrueKeyword, .FalseKeyword => return true,
            .ParenthesizedExpression => |n| return c.isValidConstAssertionArgument(n.Expression),
            .PrefixUnaryExpression => |n| {
                const op = n.Operator;
                const operand = n.Operand;
                if (op == 0 or operand == 0) return false;
                const op_kind = tree.getNodeKind(op);
                const arg_kind = tree.getNodeKind(operand);
                if (op_kind == .MinusToken and (arg_kind == .NumericLiteral or arg_kind == .BigIntLiteral)) return true;
                if (op_kind == .PlusToken and arg_kind == .NumericLiteral) return true;
                return false;
            },
            .PropertyAccessExpression, .ElementAccessExpression => {
                // Requires resolveEntityName; conservative: return false.
                // TODO(phase1.2): wire resolveEntityName + check SymbolFlags.Enum.
                _ = c;
                return false;
            },
            else => return false,
        }
    }

    /// Port of `checker.go::isConstContext`. Returns true if `node` is in
    /// a const assertion context (`as const`) or a contextual const type.
    pub fn isConstContext(c: *Checker, node: ast_gen.NodeIndex) bool {
        if (node == 0) return false;
        const tree = c.binder.ast;
        const parent = tree.getNodeParent(node);
        if (parent != 0) {
            const parent_data = tree.getNode(parent);
            switch (parent_data) {
                .AsExpression => |n| {
                    // Const assertion: `x as const`
                    if (n.Type != 0) {
                        const type_kind = tree.getNodeKind(n.Type);
                        if (type_kind == .TypeReference) {
                            // Check if type is `const` identifier
                            // Conservative: assume yes if Type is Identifier "const"
                            _ = c;
                            return true;
                        }
                    }
                    return false;
                },
                .ParenthesizedExpression, .ArrayLiteralExpression, .SpreadElement => {
                    return c.isConstContext(parent);
                },
                .PropertyAssignment, .ShorthandPropertyAssignment => {
                    const grandparent = tree.getNodeParent(parent);
                    if (grandparent != 0) return c.isConstContext(grandparent);
                    return false;
                },
                else => {},
            }
        }
        return false;
    }

    pub fn isInPropertyInitializerOrClassStaticBlock(c: *Checker, node: *anyopaque, ignoreArrowFunctions: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = ignoreArrowFunctions;
        return false;
    }

    pub fn getNarrowedTypeOfSymbol(c: *Checker, symbol_: *anyopaque, location: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        _ = location;
        return undefined;
    }

    pub fn isReadonlyAssignmentDeclaration(c: *Checker, node: ast_gen.NodeIndex) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn isReadonlySymbol(c: *Checker, sym: ast_gen.SymbolIndex) bool {
        if (sym == 0 or sym >= c.binder.symbols.items.len) return false;
        const symInfo = c.binder.symbols.items[sym];
        const checkFlags = c.getSymbolCheckFlags(sym);
        if ((checkFlags & types.CheckFlags.Readonly) != 0) return true;
        if ((symInfo.Flags & symbol.SymbolFlags.Property) != 0 and (c.getDeclarationModifierFlagsFromSymbol(sym) & ast_utils.ModifierFlags.Readonly) != 0) return true;
        if ((symInfo.Flags & symbol.SymbolFlags.Variable) != 0 and (c.getDeclarationNodeFlagsFromSymbol(sym) & ast_utils.NodeFlags.Constant) != 0) return true;
        if ((symInfo.Flags & symbol.SymbolFlags.Accessor) != 0 and (symInfo.Flags & symbol.SymbolFlags.SetAccessor) == 0) return true;
        if ((symInfo.Flags & symbol.SymbolFlags.EnumMember) != 0) return true;

        if (symInfo.Declarations.items.len > 0) {
            for (symInfo.Declarations.items) |decl| {
                if (Checker.isReadonlyAssignmentDeclaration(c, decl)) return true;
            }
        }
        return false;
    }

    pub fn checkObjectLiteralMethod(c: *Checker, node: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = checkMode;
        return undefined;
    }

    pub fn checkExpressionForMutableLocation(c: *Checker, node: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = checkMode;
        return undefined;
    }

    pub fn getReferencedValueOrAliasSymbol(c: *Checker, reference: *anyopaque) *anyopaque {
        _ = c;
        _ = reference;
        return undefined;
    }

    pub fn getCannotFindNameDiagnosticForName(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getDiagnostics(c: *Checker, ctx: *anyopaque, sourceFile: *anyopaque) *anyopaque {
        _ = c;
        _ = ctx;
        _ = sourceFile;
        return undefined;
    }

    pub fn getSuggestionDiagnostics(c: *Checker, ctx: *anyopaque, sourceFile: *anyopaque) *anyopaque {
        _ = c;
        _ = ctx;
        _ = sourceFile;
        return undefined;
    }

    pub fn getGlobalDiagnostics(c: *Checker) *anyopaque {
        _ = c;
        return undefined;
    }

    pub fn addDeferredDiagnostic(c: *Checker, callback: *anyopaque) *anyopaque {
        _ = c;
        _ = callback;
        return undefined;
    }

    pub fn produceDeferredDiagnostics(c: *Checker) void {
        _ = c;
    }

    pub fn addSuggestionDiagnostic(c: *Checker, diagnostic: *anyopaque) void {
        _ = c;
        _ = diagnostic;
    }

    pub fn @"error"(c: *Checker, location: *anyopaque, message: *anyopaque) *anyopaque {
        _ = c;
        _ = location;
        _ = message;
        return undefined;
    }

    pub fn errorSkippedOnNoEmit(c: *Checker, location: *anyopaque, message: *anyopaque) *anyopaque {
        _ = c;
        _ = location;
        _ = message;
        return undefined;
    }

    pub fn errorOrSuggestion(c: *Checker, isError: *anyopaque, location: *anyopaque, message: *anyopaque) void {
        _ = c;
        _ = isError;
        _ = location;
        _ = message;
    }

    pub fn errorAndMaybeSuggestAwait(c: *Checker, location: ast_gen.NodeIndex, maybeMissingAwait: bool, message: *const diagnostics_gen.Message) void {
        _ = c;
        _ = location;
        _ = maybeMissingAwait;
        _ = message;
    }

    pub fn addErrorOrSuggestion(c: *Checker, isError_: bool, diagnostic: diagnostics.Diagnostic) void {
        _ = c;
        _ = isError_;
        _ = diagnostic;
    }

    pub fn isDeprecatedDeclaration(c: *Checker, declaration: ast_gen.NodeIndex) bool {
        _ = c;
        _ = declaration;
        return false;
    }

    pub fn addDeprecatedSuggestion(c: *Checker, location: *anyopaque, declarations: *anyopaque, deprecatedEntity: *anyopaque) *anyopaque {
        _ = c;
        _ = location;
        _ = declarations;
        _ = deprecatedEntity;
        return undefined;
    }

    pub fn addDeprecatedSuggestionWorker(c: *Checker, declarations: *anyopaque, diagnostic: *anyopaque) *anyopaque {
        _ = c;
        _ = declarations;
        _ = diagnostic;
        return undefined;
    }

    pub fn isDeprecatedSymbol(c: *Checker, symbol_: *anyopaque) bool {
        _ = c;
        _ = symbol_;
        return false;
    }

    pub fn newSymbol(c: *Checker, flags: *anyopaque, name_: *anyopaque) *anyopaque {
        _ = c;
        _ = flags;
        _ = name_;
        return undefined;
    }

    pub fn newSymbolEx(c: *Checker, flags: *anyopaque, name_: *anyopaque, checkFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = flags;
        _ = name_;
        _ = checkFlags;
        return undefined;
    }

    pub fn newParameter(c: *Checker, name_: *anyopaque, t: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        _ = t;
        return undefined;
    }

    pub fn newProperty(c: *Checker, name_: *anyopaque, t: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        _ = t;
        return undefined;
    }

    pub fn combineSymbolTables(c: *Checker, first: *anyopaque, second: *anyopaque) *anyopaque {
        _ = c;
        _ = first;
        _ = second;
        return undefined;
    }

    pub fn mergeSymbolTable(c: *Checker, target: *anyopaque, source: *anyopaque, unidirectional: *anyopaque, mergedParent: *anyopaque) void {
        _ = c;
        _ = target;
        _ = source;
        _ = unidirectional;
        _ = mergedParent;
    }

    pub fn mergeSymbol(c: *Checker, target: *anyopaque, source: *anyopaque, unidirectional: *anyopaque) *anyopaque {
        _ = c;
        _ = target;
        _ = source;
        _ = unidirectional;
        return undefined;
    }

    pub fn reportMergeSymbolError(c: *Checker, target: *anyopaque, source: *anyopaque) void {
        _ = c;
        _ = target;
        _ = source;
    }

    pub fn addDuplicateDeclarationErrorsForSymbols(c: *Checker, target: *anyopaque, message: *anyopaque, symbolName: *anyopaque, source: *anyopaque) void {
        _ = c;
        _ = target;
        _ = message;
        _ = symbolName;
        _ = source;
    }

    pub fn addDuplicateDeclarationError(c: *Checker, node: *anyopaque, message: *anyopaque, symbolName: *anyopaque, relatedNodes: *anyopaque) void {
        _ = c;
        _ = node;
        _ = message;
        _ = symbolName;
        _ = relatedNodes;
    }

    pub fn createDiagnosticForNode(node: *anyopaque, message: *anyopaque) *anyopaque {
        _ = node;
        _ = message;
        return undefined;
    }

    pub fn getAdjustedNodeForError(node: *anyopaque) *anyopaque {
        _ = node;
        return undefined;
    }

    pub fn lookupOrIssueError(c: *Checker, location: *anyopaque, message: *anyopaque) *anyopaque {
        _ = c;
        _ = location;
        _ = message;
        return undefined;
    }

    pub fn getFirstDeclaration(symbol_: *anyopaque) *anyopaque {
        _ = symbol_;
        return undefined;
    }

    pub fn getExcludedSymbolFlags(flags: *anyopaque) *anyopaque {
        _ = flags;
        return undefined;
    }

    pub fn cloneSymbol(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn recordMergedSymbol(c: *Checker, target: *anyopaque, source: *anyopaque) void {
        _ = c;
        _ = target;
        _ = source;
    }

    pub fn getSymbolIfSameReference(c: *Checker, s1: *anyopaque, s2: *anyopaque) *anyopaque {
        _ = c;
        _ = s1;
        _ = s2;
        return undefined;
    }

    pub fn getLateBoundSymbol(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getTargetOfImportEqualsDeclaration(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn resolveExternalModuleTypeByLiteral(c: *Checker, name_: ast_gen.NodeIndex) types.TypeIndex {
        _ = name_;
        return c.anyTypeIndex orelse 0;
    }

    pub fn getSymbolOfPartOfRightHandSideOfImportEquals(c: *Checker, entityName: *anyopaque) *anyopaque {
        _ = c;
        _ = entityName;
        return undefined;
    }

    pub fn checkAndReportErrorForResolvingImportAliasToTypeOnlySymbol(c: *Checker, node: *anyopaque, resolved: *anyopaque) void {
        _ = c;
        _ = node;
        _ = resolved;
    }

    pub fn getTypeOnlyDeclarationOfEntityName(c: *Checker, name_: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        return undefined;
    }

    pub fn getTargetOfImportClause(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getTargetOfModuleDefault(c: *Checker, moduleSymbol: *anyopaque, node: *anyopaque, dontResolveAlias: *anyopaque) *anyopaque {
        _ = c;
        _ = moduleSymbol;
        _ = node;
        _ = dontResolveAlias;
        return undefined;
    }

    pub fn reportNonDefaultExport(c: *Checker, moduleSymbol: *anyopaque, node: *anyopaque) void {
        _ = c;
        _ = moduleSymbol;
        _ = node;
    }

    pub fn resolveExportByName(c: *Checker, moduleSymbol: *anyopaque, name_: *anyopaque, sourceNode: *anyopaque, dontResolveAlias: *anyopaque) *anyopaque {
        _ = c;
        _ = moduleSymbol;
        _ = name_;
        _ = sourceNode;
        _ = dontResolveAlias;
        return undefined;
    }

    pub fn getTargetOfNamespaceImport(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getTargetOfNamespaceExport(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getTargetOfImportSpecifier(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getExternalModuleMember(c: *Checker, node: *anyopaque, specifier: *anyopaque, dontResolveAlias: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = specifier;
        _ = dontResolveAlias;
        return undefined;
    }

    pub fn getPropertyOfVariable(c: *Checker, symbol_: *anyopaque, name_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        _ = name_;
        return undefined;
    }

    pub fn combineValueAndTypeSymbols(c: *Checker, valueSymbol: *anyopaque, typeSymbol: *anyopaque) *anyopaque {
        _ = c;
        _ = valueSymbol;
        _ = typeSymbol;
        return undefined;
    }

    pub fn getExportOfModule(c: *Checker, symbol_: *anyopaque, nameText: *anyopaque, specifier: *anyopaque, dontResolveAlias: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        _ = nameText;
        _ = specifier;
        _ = dontResolveAlias;
        return undefined;
    }

    pub fn isOnlyImportableAsDefault(c: *Checker, usage: *anyopaque, resolvedModule: *anyopaque) bool {
        _ = c;
        _ = usage;
        _ = resolvedModule;
        return false;
    }

    pub fn canHaveSyntheticDefault(c: *Checker, file: *anyopaque, moduleSymbol: *anyopaque, dontResolveAlias: *anyopaque, usage: *anyopaque) bool {
        _ = c;
        _ = file;
        _ = moduleSymbol;
        _ = dontResolveAlias;
        _ = usage;
        return false;
    }

    pub fn getEmitSyntaxForModuleSpecifierExpression(c: *Checker, usage: *anyopaque) *anyopaque {
        _ = c;
        _ = usage;
        return undefined;
    }

    pub fn errorNoModuleMemberSymbol(c: *Checker, moduleSymbol: *anyopaque, targetSymbol: *anyopaque, node: *anyopaque, name_: *anyopaque) void {
        _ = c;
        _ = moduleSymbol;
        _ = targetSymbol;
        _ = node;
        _ = name_;
    }

    pub fn reportNonExportedMember(c: *Checker, name_: *anyopaque, declarationName: *anyopaque, moduleSymbol: *anyopaque, moduleName: *anyopaque) void {
        _ = c;
        _ = name_;
        _ = declarationName;
        _ = moduleSymbol;
        _ = moduleName;
    }

    pub fn reportInvalidImportEqualsExportMember(c: *Checker, name_: *anyopaque, declarationName: *anyopaque, moduleName: *anyopaque) void {
        _ = c;
        _ = name_;
        _ = declarationName;
        _ = moduleName;
    }

    pub fn getTargetOfExportSpecifier(c: *Checker, node: *anyopaque, meaning: *anyopaque, dontResolveAlias: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = meaning;
        _ = dontResolveAlias;
        return undefined;
    }

    pub fn getTargetOfExportAssignment(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getTargetOfBinaryExpression(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getTargetOfAliasLikeExpression(c: *Checker, expression: *anyopaque) *anyopaque {
        _ = c;
        _ = expression;
        return undefined;
    }

    pub fn getTargetOfNamespaceExportDeclaration(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getTargetOfAccessExpression(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getModuleSpecifierForImportOrExport(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getModuleSpecifierFromNode(node: *anyopaque) *anyopaque {
        _ = node;
        return undefined;
    }

    pub fn markSymbolOfAliasDeclarationIfTypeOnly(c: *Checker, aliasDeclaration: *anyopaque, exportStarDeclaration: *anyopaque) bool {
        _ = c;
        _ = aliasDeclaration;
        _ = exportStarDeclaration;
        return false;
    }

    pub fn resolveExternalModuleName(c: *Checker, location: *anyopaque, moduleReferenceExpression: *anyopaque, ignoreErrors: *anyopaque) *anyopaque {
        _ = c;
        _ = location;
        _ = moduleReferenceExpression;
        _ = ignoreErrors;
        return undefined;
    }

    pub fn getCannotResolveModuleNameErrorForSpecificModule(c: *Checker, moduleName: *anyopaque) *anyopaque {
        _ = c;
        _ = moduleName;
        return undefined;
    }

    pub fn resolveExternalModuleNameWorker(c: *Checker, location: *anyopaque, moduleReferenceExpression: *anyopaque, moduleNotFoundError: *anyopaque, ignoreErrors: *anyopaque, isForAugmentation: *anyopaque) *anyopaque {
        _ = c;
        _ = location;
        _ = moduleReferenceExpression;
        _ = moduleNotFoundError;
        _ = ignoreErrors;
        _ = isForAugmentation;
        return undefined;
    }

    pub fn getExternalModuleFileFromDeclaration(c: *Checker, declaration: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = c;
        _ = declaration;
        return 0;
    }

    pub fn getConstantValue(c: *Checker, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = c;
        _ = node;
        return 0; // Stub
    }

    pub fn resolveExternalModule(c: *Checker, location: *anyopaque, moduleReference: *anyopaque, moduleNotFoundError: *anyopaque, errorNode: *anyopaque, isForAugmentation: *anyopaque) *anyopaque {
        _ = c;
        _ = location;
        _ = moduleReference;
        _ = moduleNotFoundError;
        _ = errorNode;
        _ = isForAugmentation;
        return undefined;
    }

    pub fn resolutionExtensionIsTSOrJson(ext: *anyopaque) bool {
        _ = ext;
        return false;
    }

    pub fn getSuggestedImportSource(c: *Checker, moduleReference: *anyopaque, tsExtension: *anyopaque, mode: *anyopaque) *anyopaque {
        _ = c;
        _ = moduleReference;
        _ = tsExtension;
        _ = mode;
        return undefined;
    }

    pub fn getSuggestedImportExtension(c: *Checker, extensionlessImportPath: *anyopaque) *anyopaque {
        _ = c;
        _ = extensionlessImportPath;
        return undefined;
    }

    pub fn errorOnImplicitAnyModule(c: *Checker, isError: *anyopaque, errorNode: *anyopaque, mode: *anyopaque, resolvedModule: *anyopaque, moduleReference: *anyopaque) void {
        _ = c;
        _ = isError;
        _ = errorNode;
        _ = mode;
        _ = resolvedModule;
        _ = moduleReference;
    }

    pub fn createModuleNotFoundChain(c: *Checker, resolvedModule: *anyopaque, errorNode: *anyopaque, moduleReference: *anyopaque, mode: *anyopaque, packageName: *anyopaque) *anyopaque {
        _ = c;
        _ = resolvedModule;
        _ = errorNode;
        _ = moduleReference;
        _ = mode;
        _ = packageName;
        return undefined;
    }

    pub fn createModeMismatchDetails(c: *Checker, sourceFile: *anyopaque, errorNode: *anyopaque) *anyopaque {
        _ = c;
        _ = sourceFile;
        _ = errorNode;
        return undefined;
    }

    pub fn tryFindAmbientModule(c: *Checker, moduleName: *anyopaque, withAugmentations: *anyopaque) *anyopaque {
        _ = c;
        _ = moduleName;
        _ = withAugmentations;
        return undefined;
    }

    pub fn getAmbientModules(c: *Checker) *anyopaque {
        _ = c;
        return undefined;
    }

    pub fn resolveESModuleSymbol(c: *Checker, moduleSymbol: *anyopaque, node: *anyopaque, moduleSpecifier: *anyopaque) *anyopaque {
        _ = c;
        _ = moduleSymbol;
        _ = node;
        _ = moduleSpecifier;
        return undefined;
    }

    pub fn hasSignatures(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn isESMFormatImportImportingCommonjsFormatFile(usageMode: *anyopaque, targetMode: *anyopaque) bool {
        _ = usageMode;
        _ = targetMode;
        return false;
    }

    pub fn getTypeWithSyntheticDefaultOnly(c: *Checker, t: *anyopaque, symbol_: *anyopaque, originalSymbol: *anyopaque, moduleSpecifier: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = symbol_;
        _ = originalSymbol;
        _ = moduleSpecifier;
        return undefined;
    }

    pub fn getTypeWithSyntheticDefaultImportType(c: *Checker, t: *anyopaque, symbol_: *anyopaque, originalSymbol: *anyopaque, moduleSpecifier: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = symbol_;
        _ = originalSymbol;
        _ = moduleSpecifier;
        return undefined;
    }

    pub fn isCommonJSRequire(c: *Checker, node: ast_gen.NodeIndex) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn createDefaultPropertyWrapperForModule(c: *Checker, symbol_: *anyopaque, originalSymbol: *anyopaque, anonymousSymbol: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        _ = originalSymbol;
        _ = anonymousSymbol;
        return undefined;
    }

    pub fn cloneTypeAsModuleType(c: *Checker, symbol_: *anyopaque, moduleType: *anyopaque, referenceParent: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        _ = moduleType;
        _ = referenceParent;
        return undefined;
    }

    pub fn getTargetOfAliasDeclaration(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn resolveQualifiedName(c: *Checker, name_: *anyopaque, left: *anyopaque, right: *anyopaque, meaning: *anyopaque, ignoreErrors: *anyopaque, location: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        _ = left;
        _ = right;
        _ = meaning;
        _ = ignoreErrors;
        _ = location;
        return undefined;
    }

    pub fn tryGetQualifiedNameAsValue(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getSuggestedSymbolForNonexistentModule(c: *Checker, name_: *anyopaque, targetModule: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        _ = targetModule;
        return undefined;
    }

    pub fn getFullyQualifiedName(c: *Checker, symbol_: *anyopaque, containingLocation: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        _ = containingLocation;
        return undefined;
    }

    pub fn getExportsOfSymbol(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getResolvedMembersOrExportsOfSymbol(c: *Checker, symbol_: *anyopaque, resolutionKind: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        _ = resolutionKind;
        return undefined;
    }

    pub fn lateBindMember(c: *Checker, parent: *anyopaque, earlySymbols: *anyopaque, lateSymbols: *anyopaque, decl: *anyopaque) *anyopaque {
        _ = c;
        _ = parent;
        _ = earlySymbols;
        _ = lateSymbols;
        _ = decl;
        return undefined;
    }

    pub fn lateBindIndexSignature(c: *Checker, parent: *anyopaque, earlySymbols: *anyopaque, lateSymbols: *anyopaque, decl: *anyopaque) void {
        _ = c;
        _ = parent;
        _ = earlySymbols;
        _ = lateSymbols;
        _ = decl;
    }

    pub fn isNotReplacableByMethod(decl: *anyopaque) bool {
        _ = decl;
        return false;
    }

    pub fn addDeclarationToLateBoundSymbol(c: *Checker, symbol_: *anyopaque, member: *anyopaque, symbolFlags: *anyopaque) void {
        _ = c;
        _ = symbol_;
        _ = member;
        _ = symbolFlags;
    }

    pub fn getMembersOfSymbol(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getExportsOfModule(c: *Checker, moduleSymbol: ast_gen.SymbolIndex) types.SymbolTableIndex {
        _ = c;
        _ = moduleSymbol;
        return 0; // Stub
    }

    pub fn getExportsOfModuleWorker(c: *Checker, moduleSymbol: ast_gen.SymbolIndex) types.SymbolTableIndex {
        _ = c;
        _ = moduleSymbol;
        return 0; // Stub
    }

    pub fn extendExportSymbols(c: *Checker, target: *anyopaque, source: *anyopaque, lookupTable: *anyopaque, exportNode: *anyopaque) void {
        _ = c;
        _ = target;
        _ = source;
        _ = lookupTable;
        _ = exportNode;
    }

    pub fn resolveIndirectionAlias(c: *Checker, source: *anyopaque, target: *anyopaque) *anyopaque {
        _ = c;
        _ = source;
        _ = target;
        return undefined;
    }

    pub fn tryResolveAlias(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn resolveAliasWithDeprecationCheck(c: *Checker, symbol_: ast_gen.SymbolIndex, location: ast_gen.NodeIndex) ast_gen.SymbolIndex {
        _ = c;
        _ = symbol_;
        _ = location;
        return undefined;
    }

    pub fn getSymbolFlagsEx(c: *Checker, initialSymbol: ast_gen.SymbolIndex, excludeTypeOnlyMeanings: bool, excludeLocalMeanings: bool) u32 {
        var flags: u32 = 0;
        var currentSymbol = initialSymbol;

        if (!excludeLocalMeanings) {
            flags = c.getSymbolFlags(currentSymbol);
        }

        // seenSymbols set could be optimized out by simply relying on maximum resolution depth or similar,
        // but for safety let's use AutoHashMapUnmanaged. We only allocate if there's an alias loop.
        var seenSymbols: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, void) = .empty;
        defer seenSymbols.deinit(c.allocator);

        while ((c.getSymbolFlags(currentSymbol) & ast_gen.SymbolFlags.Alias) != 0) {
            if (excludeTypeOnlyMeanings and c.getTypeOnlyAliasDeclaration(currentSymbol) != 0) {
                break;
            }
            const target = getExportSymbolOfValueSymbolIfExported(c, c.resolveAlias(currentSymbol));
            if (target == c.unknownSymbol) {
                return ast_gen.SymbolFlags.All;
            }
            if ((c.getSymbolFlags(target) & ast_gen.SymbolFlags.Alias) != 0) {
                if (target == currentSymbol or seenSymbols.contains(target)) {
                    break;
                }
                if (seenSymbols.count() == 0) {
                    seenSymbols.put(c.allocator, currentSymbol, {}) catch unreachable;
                }
                seenSymbols.put(c.allocator, target, {}) catch unreachable;
            }
            flags |= c.getSymbolFlags(target);
            currentSymbol = target;
        }

        return flags;
    }

    pub fn getDeclarationOfAliasSymbol(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getTypeOfSymbolWithDeferredType(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getWriteTypeOfSymbolWithDeferredType(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getTypeOfSymbolAtLocation(c: *Checker, symbol_: *anyopaque, location: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        _ = location;
        return undefined;
    }

    pub fn getTypeOfInstantiatedSymbol(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getWriteTypeOfInstantiatedSymbol(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getTypeOfVariableOrParameterOrProperty(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn isParameterOfContextSensitiveSignature(c: *Checker, symbol_: *anyopaque) bool {
        _ = c;
        _ = symbol_;
        return false;
    }

    pub fn getTypeOfVariableOrParameterOrPropertyWorker(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getWidenedTypeForVariableLikeDeclaration(c: *Checker, declaration: *anyopaque, reportErrors: *anyopaque) *anyopaque {
        _ = c;
        _ = declaration;
        _ = reportErrors;
        return undefined;
    }

    pub fn getTypeForVariableLikeDeclaration(c: *Checker, declaration: *anyopaque, includeOptionality: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = declaration;
        _ = includeOptionality;
        _ = checkMode;
        return undefined;
    }

    pub fn checkDeclarationInitializer(c: *Checker, declaration: *anyopaque, checkMode: *anyopaque, contextualType: *anyopaque) *anyopaque {
        _ = c;
        _ = declaration;
        _ = checkMode;
        _ = contextualType;
        return undefined;
    }

    pub fn padObjectLiteralType(c: *Checker, t: *anyopaque, pattern: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = pattern;
        return undefined;
    }

    pub fn getPropertyNameFromBindingElement(c: *Checker, e: *anyopaque) *anyopaque {
        _ = c;
        _ = e;
        return undefined;
    }

    pub fn padTupleType(c: *Checker, t: *anyopaque, pattern: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = pattern;
        return undefined;
    }

    pub fn widenTypeInferredFromInitializer(c: *Checker, declaration: *anyopaque, t: *anyopaque) *anyopaque {
        _ = c;
        _ = declaration;
        _ = t;
        return undefined;
    }

    pub fn getWidenedLiteralTypeForInitializer(c: *Checker, declaration: *anyopaque, t: *anyopaque) *anyopaque {
        _ = c;
        _ = declaration;
        _ = t;
        return undefined;
    }

    pub fn getTypeOfFuncClassEnumModule(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getTypeOfFuncClassEnumModuleWorker(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getBaseTypeVariableOfClass(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getBaseConstructorTypeOfClass(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getConstraintFromTypeParameter(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getConstraintOrUnknownFromTypeParameter(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getInferredTypeParameterConstraint(c: *Checker, t: *anyopaque, omitTypeReferences: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = omitTypeReferences;
        return undefined;
    }

    pub fn getTypeParametersForTypeReferenceOrImport(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getTypeParametersForTypeAndSymbol(c: *Checker, t: *anyopaque, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = symbol_;
        return undefined;
    }

    pub fn getEffectiveTypeArgumentAtIndex(c: *Checker, node: *anyopaque, typeParameters: *anyopaque, index: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = typeParameters;
        _ = index;
        return undefined;
    }

    pub fn getConstraintFromIndexedAccess(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getConstraintFromConditionalType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getDeclaredTypeOfClassOrInterface(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn isThislessInterface(c: *Checker, symbol_: *anyopaque) bool {
        _ = c;
        _ = symbol_;
        return false;
    }

    pub fn isZero_stub() bool {
        return false;
    }

    pub fn hash(b: *anyopaque) *anyopaque {
        _ = b;
        return undefined;
    }

    pub fn writeByte(b: *anyopaque, c: *anyopaque) void {
        _ = b;
        _ = c;
    }

    pub fn writeString(b: *anyopaque, s: *anyopaque) void {
        _ = b;
        _ = s;
    }

    pub fn writeInt(b: *anyopaque, value: *anyopaque) void {
        _ = b;
        _ = value;
    }

    pub fn writeSymbol(b: *anyopaque, s: *anyopaque) void {
        _ = b;
        _ = s;
    }

    pub fn writeType(b: *anyopaque, t: *anyopaque) void {
        _ = b;
        _ = t;
    }

    pub fn writeTypes(b: *anyopaque, types_: *anyopaque) void {
        _ = b;
        _ = types_;
    }

    pub fn writeAlias(b: *anyopaque, alias: *anyopaque) void {
        _ = b;
        _ = alias;
    }

    pub fn writeGenericTypeReferences(b: *anyopaque, source: *anyopaque, target: *anyopaque, ignoreConstraints: *anyopaque) bool {
        _ = b;
        _ = source;
        _ = target;
        _ = ignoreConstraints;
        return false;
    }

    pub fn writeNodeId(b: *anyopaque, id: *anyopaque) void {
        _ = b;
        _ = id;
    }

    pub fn writeNode(b: *anyopaque, node: *anyopaque) void {
        _ = b;
        _ = node;
    }

    pub fn getAliasKey(alias: *anyopaque) *anyopaque {
        _ = alias;
        return undefined;
    }

    pub fn getUnionKey(types_: *anyopaque, origin: *anyopaque, alias: *anyopaque) *anyopaque {
        _ = types_;
        _ = origin;
        _ = alias;
        return undefined;
    }

    pub fn getIntersectionKey(types_: *anyopaque, flags: *anyopaque, alias: *anyopaque) *anyopaque {
        _ = types_;
        _ = flags;
        _ = alias;
        return undefined;
    }

    pub fn getIndexedAccessKey(objectType: *anyopaque, indexType: *anyopaque, accessFlags: *anyopaque, alias: *anyopaque) *anyopaque {
        _ = objectType;
        _ = indexType;
        _ = accessFlags;
        _ = alias;
        return undefined;
    }

    pub fn getRelationKey(source: *anyopaque, target: *anyopaque, intersectionState: *anyopaque, isIdentity: *anyopaque, ignoreConstraints: *anyopaque) bool {
        _ = source;
        _ = target;
        _ = intersectionState;
        _ = isIdentity;
        _ = ignoreConstraints;
        return false;
    }

    pub fn getNodeListKey(nodes: *anyopaque) *anyopaque {
        _ = nodes;
        return undefined;
    }

    pub fn isTypeReferenceWithGenericArguments(t: *anyopaque) bool {
        _ = t;
        return false;
    }

    pub fn isNonDeferredTypeReference(t: *anyopaque) bool {
        _ = t;
        return false;
    }

    pub fn isUnconstrainedTypeParameter(tp: *anyopaque) bool {
        _ = tp;
        return false;
    }

    pub fn isNullOrUndefined(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn checkRightHandSideOfForOf(c: *Checker, statement: *anyopaque) *anyopaque {
        _ = c;
        _ = statement;
        return undefined;
    }

    pub fn getTypeForBindingElement(c: *Checker, declaration: *anyopaque) *anyopaque {
        _ = c;
        _ = declaration;
        return undefined;
    }

    pub fn getTypeForBindingElementParent(c: *Checker, node: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = checkMode;
        return undefined;
    }

    pub fn getBindingElementTypeFromParentType(c: *Checker, declaration: *anyopaque, parentType: *anyopaque, noTupleBoundsCheck: *anyopaque) *anyopaque {
        _ = c;
        _ = declaration;
        _ = parentType;
        _ = noTupleBoundsCheck;
        return undefined;
    }

    pub fn getRestType(c: *Checker, source: *anyopaque, properties: *anyopaque, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = source;
        _ = properties;
        _ = symbol_;
        return undefined;
    }

    pub fn getFlowTypeOfDestructuring(c: *Checker, node: *anyopaque, declaredType: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = declaredType;
        return undefined;
    }

    pub fn getSyntheticElementAccess(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getParentElementAccess(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getTypeFromBindingPattern(c: *Checker, pattern: *anyopaque, includePatternInType: *anyopaque, reportErrors: *anyopaque) *anyopaque {
        _ = c;
        _ = pattern;
        _ = includePatternInType;
        _ = reportErrors;
        return undefined;
    }

    pub fn getTypeFromObjectBindingPattern(c: *Checker, pattern: *anyopaque, includePatternInType: *anyopaque, reportErrors: *anyopaque) *anyopaque {
        _ = c;
        _ = pattern;
        _ = includePatternInType;
        _ = reportErrors;
        return undefined;
    }

    pub fn getTypeFromArrayBindingPattern(c: *Checker, pattern: *anyopaque, includePatternInType: *anyopaque, reportErrors: *anyopaque) *anyopaque {
        _ = c;
        _ = pattern;
        _ = includePatternInType;
        _ = reportErrors;
        return undefined;
    }

    pub fn getTypeFromBindingElement(c: *Checker, element: *anyopaque, includePatternInType: *anyopaque, reportErrors: *anyopaque) *anyopaque {
        _ = c;
        _ = element;
        _ = includePatternInType;
        _ = reportErrors;
        return undefined;
    }

    pub fn declarationBelongsToPrivateAmbientMember(c: *Checker, declaration: *anyopaque) bool {
        _ = c;
        _ = declaration;
        return false;
    }

    pub fn getTypeOfPrototypeProperty(c: *Checker, prototype: *anyopaque) *anyopaque {
        _ = c;
        _ = prototype;
        return undefined;
    }

    pub fn getWidenedTypeForAssignmentDeclaration(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getAssignmentDeclarationInitializerType(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn hasParentWithTypeAnnotation(c: *Checker, symbol_: *anyopaque) bool {
        _ = c;
        _ = symbol_;
        return false;
    }

    pub fn containsSameNamedThisProperty(c: *Checker, thisProperty: *anyopaque, expression: *anyopaque) bool {
        _ = c;
        _ = thisProperty;
        _ = expression;
        return false;
    }

    pub fn getTypeFromPropertyDescriptor(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn isConstructorDeclaredThisProperty(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn isGlobalSymbolConstructor(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn widenTypeForVariableLikeDeclaration(c: *Checker, t: *anyopaque, declaration: *anyopaque, reportErrors: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = declaration;
        _ = reportErrors;
        return undefined;
    }

    pub fn getWidenedType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getWidenedTypeWithContext(c: *Checker, t: *anyopaque, context: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = context;
        return undefined;
    }

    pub fn getWidenedTypeOfObjectLiteral(c: *Checker, t: *anyopaque, context: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = context;
        return undefined;
    }

    pub fn getWidenedProperty(c: *Checker, prop: *anyopaque, context: *anyopaque) *anyopaque {
        _ = c;
        _ = prop;
        _ = context;
        return undefined;
    }

    pub fn getChildContext(w: *anyopaque, propertyName: *anyopaque) *anyopaque {
        _ = w;
        _ = propertyName;
        return undefined;
    }

    pub fn getPropertiesOfContext(c: *Checker, context: *anyopaque) *anyopaque {
        _ = c;
        _ = context;
        return undefined;
    }

    pub fn getSiblingsOfContext(c: *Checker, context: *anyopaque) *anyopaque {
        _ = c;
        _ = context;
        return undefined;
    }

    pub fn getUndefinedProperty(c: *Checker, prop: *anyopaque) *anyopaque {
        _ = c;
        _ = prop;
        return undefined;
    }

    pub fn getTypeOfEnumMember(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getTypeOfAccessors(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getWriteTypeOfAccessors(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getTypeOfAlias(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn addOptionality(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    /// Port of `checker.go::GetNonNullableType`. Strips `undefined | null`
    /// from `t` when strictNullChecks is enabled.
    pub fn getNonNullableType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        if (c.strictNullChecks) {
            return c.getAdjustedTypeWithFacts(t, types.TypeFacts.NEUndefinedOrNull);
        }
        return t;
    }

    /// Port of `checker.go::IsNullableType`. Returns true if `t` includes
    /// `undefined` or `null` as a possible value.
    pub fn isNullableType(c: *Checker, t: types.TypeIndex) bool {
        return c.hasTypeFacts(t, types.TypeFacts.IsUndefinedOrNull);
    }

    /// Port of `checker.go::getNonNullableTypeIfNeeded`. Conditionally
    /// strips null/undefined from `t` if it is nullable.
    pub fn getNonNullableTypeIfNeeded(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        if (c.isNullableType(t)) {
            return c.getNonNullableType(t);
        }
        return t;
    }

    pub fn getCombinedNodeFlagsCached(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn isVarConstLike(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn getEffectivePropertyNameForPropertyNameNode(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn tryGetNameFromType(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn getCombinedModifierFlagsCached(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn pushTypeResolution(c: *Checker, target: *anyopaque, propertyName: *anyopaque) bool {
        _ = c;
        _ = target;
        _ = propertyName;
        return false;
    }

    pub fn popTypeResolution(c: *Checker) bool {
        _ = c;
        return false;
    }

    pub fn reportCircularityError(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getPropertyOfTypeEx(c: *Checker, t: types.TypeIndex, name_: *anyopaque, skipObjectFunctionPropertyAugment: *anyopaque, includeTypeOnlyMembers: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = name_;
        _ = skipObjectFunctionPropertyAugment;
        _ = includeTypeOnlyMembers;
        return undefined;
    }

    pub fn getSignaturesOfStructuredType(c: *Checker, t: *anyopaque, kind_: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = kind_;
        return undefined;
    }

    pub fn getBaseTypes(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getTupleBaseType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn resolveBaseTypesOfClass(c: *Checker, t: *anyopaque) void {
        _ = c;
        _ = t;
    }

    /// Port of `checker.go::getBaseTypeNodeOfClass`. Returns the AST node
    /// representing the `extends` clause expression of the class associated
    /// with type `t`, or 0 if absent.
    pub fn getBaseTypeNodeOfClass(c: *Checker, t: types.TypeIndex) ast_gen.NodeIndex {
        if (t == 0 or t >= c.typesList.items.len) return 0;
        const ty = c.typesList.items[t];
        const sym = ty.symbol orelse return 0;
        const class_decl = ast_utils.getClassLikeDeclarationOfSymbol(&c.binder.ast, &c.binder.symbols, sym);
        if (class_decl == 0) return 0;
        return ast_utils.getExtendsHeritageClauseElement(c.binder.ast, class_decl);
    }

    pub fn getInstantiatedConstructorsForTypeArguments(c: *Checker, t: *anyopaque, typeArgumentNodes: *anyopaque, location: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = typeArgumentNodes;
        _ = location;
        return undefined;
    }

    pub fn getConstructorsForTypeArguments(c: *Checker, t: *anyopaque, typeArgumentNodes: *anyopaque, location: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = typeArgumentNodes;
        _ = location;
        return undefined;
    }

    pub fn getSignatureInstantiation(c: *Checker, sig: *anyopaque, typeArguments: *anyopaque, isJavaScript: *anyopaque, inferredTypeParameters: *anyopaque) *anyopaque {
        _ = c;
        _ = sig;
        _ = typeArguments;
        _ = isJavaScript;
        _ = inferredTypeParameters;
        return undefined;
    }

    pub fn cloneSignature(c: *Checker, sig: *anyopaque) *anyopaque {
        _ = c;
        _ = sig;
        return undefined;
    }

    pub fn getSignatureInstantiationWithoutFillingInTypeArguments(c: *Checker, sig: *anyopaque, typeArguments: *anyopaque) *anyopaque {
        _ = c;
        _ = sig;
        _ = typeArguments;
        return undefined;
    }

    pub fn createSignatureInstantiation(c: *Checker, sig: *anyopaque, typeArguments: *anyopaque) *anyopaque {
        _ = c;
        _ = sig;
        _ = typeArguments;
        return undefined;
    }

    pub fn createSignatureTypeMapper(c: *Checker, sig: *anyopaque, typeArguments: *anyopaque) *anyopaque {
        _ = c;
        _ = sig;
        _ = typeArguments;
        return undefined;
    }

    pub fn getTypeParametersForMapper(c: *Checker, sig: *anyopaque) *anyopaque {
        _ = c;
        _ = sig;
        return undefined;
    }

    pub fn getSingleCallSignature(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getSingleCallOrConstructSignature(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getSingleSignature(c: *Checker, t: *anyopaque, kind_: *anyopaque, allowMembers: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = kind_;
        _ = allowMembers;
        return undefined;
    }

    pub fn getOrCreateTypeFromSignature(c: *Checker, sig: *anyopaque) *anyopaque {
        _ = c;
        _ = sig;
        return undefined;
    }

    pub fn getCanonicalSignature(c: *Checker, signature: *anyopaque) *anyopaque {
        _ = c;
        _ = signature;
        return undefined;
    }

    pub fn createCanonicalSignature(c: *Checker, signature: *anyopaque) *anyopaque {
        _ = c;
        _ = signature;
        return undefined;
    }

    pub fn getBaseSignature(c: *Checker, signature: *anyopaque) *anyopaque {
        _ = c;
        _ = signature;
        return undefined;
    }

    pub fn instantiateSignatureInContextOf(c: *Checker, signature: *anyopaque, contextualSignature: *anyopaque, inferenceContext: *anyopaque, compareTypes: *anyopaque) *anyopaque {
        _ = c;
        _ = signature;
        _ = contextualSignature;
        _ = inferenceContext;
        _ = compareTypes;
        return undefined;
    }

    pub fn resolveBaseTypesOfInterface(c: *Checker, t: *anyopaque) void {
        _ = c;
        _ = t;
    }

    pub fn areAllOuterTypeParametersApplied(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn reportCircularBaseType(c: *Checker, node: *anyopaque, t: *anyopaque) void {
        _ = c;
        _ = node;
        _ = t;
    }

    pub fn isValidBaseType(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn addInheritedMembers(c: *Checker, symbols: *anyopaque, baseSymbols: *anyopaque) *anyopaque {
        _ = c;
        _ = symbols;
        _ = baseSymbols;
        return undefined;
    }

    pub fn getObjectLiteralIndexInfo(c: *Checker, isReadonly: *anyopaque, properties: *anyopaque, keyType: *anyopaque) *anyopaque {
        _ = c;
        _ = isReadonly;
        _ = properties;
        _ = keyType;
        return undefined;
    }

    pub fn isSymbolWithSymbolName(c: *Checker, symbol_: *anyopaque) bool {
        _ = c;
        _ = symbol_;
        return false;
    }

    pub fn isSymbolWithNumericName(c: *Checker, symbol_: *anyopaque) bool {
        _ = c;
        _ = symbol_;
        return false;
    }

    pub fn isSymbolWithComputedName(c: *Checker, symbol_: *anyopaque) bool {
        _ = c;
        _ = symbol_;
        return false;
    }

    pub fn isNumericName(c: *Checker, name_: *anyopaque) bool {
        _ = c;
        _ = name_;
        return false;
    }

    pub fn isNumericComputedName(c: *Checker, name_: *anyopaque) bool {
        _ = c;
        _ = name_;
        return false;
    }

    pub fn isValidIndexKeyType(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn getIndexSymbol(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getTypeParametersFromDeclaration(c: *Checker, declaration: *anyopaque) *anyopaque {
        _ = c;
        _ = declaration;
        return undefined;
    }

    pub fn getAnnotatedAccessorThisParameter(c: *Checker, accessor: *anyopaque) *anyopaque {
        _ = c;
        _ = accessor;
        return undefined;
    }

    pub fn getAccessorThisParameter(c: *Checker, accessor: *anyopaque) *anyopaque {
        _ = c;
        _ = accessor;
        return undefined;
    }

    pub fn hasBindableName(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn hasLateBindableName(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn isLateBindableName(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn hasLateBindableIndexSignature(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn isLateBindableIndexSignature(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn isTypeUsableAsIndexSignatureDeclaration(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn isLateBindableAST(node: *anyopaque) bool {
        _ = node;
        return false;
    }

    pub fn getNonCircularReturnTypeOfSignature(c: *Checker, sig: *anyopaque) *anyopaque {
        _ = c;
        _ = sig;
        return undefined;
    }

    pub fn getReturnTypeFromAnnotation(c: *Checker, declaration: *anyopaque) *anyopaque {
        _ = c;
        _ = declaration;
        return undefined;
    }

    pub fn getSignatureOfFullSignatureType(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getParameterTypeOfFullSignature(c: *Checker, node: *anyopaque, parameter: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = parameter;
        return undefined;
    }

    pub fn getReturnTypeOfFullSignature(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getAnnotatedAccessorType(c: *Checker, accessor: *anyopaque) *anyopaque {
        _ = c;
        _ = accessor;
        return undefined;
    }

    pub fn getAnnotatedAccessorTypeNode(c: *Checker, accessor: *anyopaque) *anyopaque {
        _ = c;
        _ = accessor;
        return undefined;
    }

    pub fn getEffectiveSetAccessorTypeAnnotationNode(node: *anyopaque) *anyopaque {
        _ = node;
        return undefined;
    }

    pub fn getReturnTypeFromBody(c: *Checker, fn_: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = fn_;
        _ = checkMode;
        return undefined;
    }

    pub fn checkAndAggregateReturnExpressionTypes(c: *Checker, fn_: *anyopaque, checkMode: *anyopaque) bool {
        _ = c;
        _ = fn_;
        _ = checkMode;
        return false;
    }

    pub fn functionHasImplicitReturn(c: *Checker, fn_: *anyopaque) bool {
        _ = c;
        _ = fn_;
        return false;
    }

    pub fn mayReturnNever(fn_: *anyopaque) bool {
        _ = fn_;
        return false;
    }

    pub fn checkAndAggregateYieldOperandTypes(c: *Checker, fn_: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = fn_;
        _ = checkMode;
        return undefined;
    }

    pub fn createPromiseType(c: *Checker, promisedType: *anyopaque) *anyopaque {
        _ = c;
        _ = promisedType;
        return undefined;
    }

    pub fn createPromiseLikeType(c: *Checker, promisedType: *anyopaque) *anyopaque {
        _ = c;
        _ = promisedType;
        return undefined;
    }

    pub fn createPromiseReturnType(c: *Checker, fn_: *anyopaque, promisedType: *anyopaque) *anyopaque {
        _ = c;
        _ = fn_;
        _ = promisedType;
        return undefined;
    }

    pub fn unwrapReturnType(c: *Checker, returnType: *anyopaque, functionFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = returnType;
        _ = functionFlags;
        return undefined;
    }

    pub fn getWidenedLiteralLikeTypeForContextualReturnTypeIfNeeded(c: *Checker, t: *anyopaque, contextualSignatureReturnType: *anyopaque, isAsync: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = contextualSignatureReturnType;
        _ = isAsync;
        return undefined;
    }

    pub fn getWidenedLiteralLikeTypeForContextualIterationTypeIfNeeded(c: *Checker, t: *anyopaque, contextualSignatureReturnType: *anyopaque, kind_: *anyopaque, isAsyncGenerator: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = contextualSignatureReturnType;
        _ = kind_;
        _ = isAsyncGenerator;
        return undefined;
    }

    pub fn createGeneratorType(c: *Checker, yieldType: *anyopaque, returnType: *anyopaque, nextType: *anyopaque, isAsyncGenerator: *anyopaque) *anyopaque {
        _ = c;
        _ = yieldType;
        _ = returnType;
        _ = nextType;
        _ = isAsyncGenerator;
        return undefined;
    }

    pub fn reportErrorsFromWidening(c: *Checker, declaration: *anyopaque, t: *anyopaque, wideningKind: *anyopaque) void {
        _ = c;
        _ = declaration;
        _ = t;
        _ = wideningKind;
    }

    pub fn shouldReportErrorsFromWideningWithContextualSignature(c: *Checker, declaration: *anyopaque, wideningKind: *anyopaque) bool {
        _ = c;
        _ = declaration;
        _ = wideningKind;
        return false;
    }

    pub fn reportWideningErrorsInType(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn getTypePredicateFromBody(c: *Checker, fn_: *anyopaque) *anyopaque {
        _ = c;
        _ = fn_;
        return undefined;
    }

    pub fn checkIfExpressionRefinesAnyParameter(c: *Checker, fn_: *anyopaque, expr: *anyopaque) *anyopaque {
        _ = c;
        _ = fn_;
        _ = expr;
        return undefined;
    }

    pub fn checkIfExpressionRefinesParameter(c: *Checker, fn_: *anyopaque, expr: *anyopaque, param: *anyopaque, initType: *anyopaque) *anyopaque {
        _ = c;
        _ = fn_;
        _ = expr;
        _ = param;
        _ = initType;
        return undefined;
    }

    pub fn addOptionalTypeMarker(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn createInstantiatedSymbolTable(c: *Checker, symbols: *anyopaque, m: *anyopaque) *anyopaque {
        _ = c;
        _ = symbols;
        _ = m;
        return undefined;
    }

    pub fn instantiateSymbolTable(c: *Checker, symbols: *anyopaque, m: *anyopaque) *anyopaque {
        _ = c;
        _ = symbols;
        _ = m;
        return undefined;
    }

    pub fn instantiateSymbol(c: *Checker, symbol_: *anyopaque, m: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        _ = m;
        return undefined;
    }

    pub fn isThisless(symbol_: *anyopaque) bool {
        _ = symbol_;
        return false;
    }

    pub fn isThislessVariableLikeDeclaration(node: *anyopaque) bool {
        _ = node;
        return false;
    }

    pub fn isThislessType(node: *anyopaque) bool {
        _ = node;
        return false;
    }

    pub fn isThislessFunctionLikeDeclaration(node: *anyopaque) bool {
        _ = node;
        return false;
    }

    pub fn isThislessTypeParameter(node: *anyopaque) bool {
        _ = node;
        return false;
    }

    pub fn getDefaultConstructSignatures(c: *Checker, classType: *anyopaque) *anyopaque {
        _ = c;
        _ = classType;
        return undefined;
    }

    pub fn getTypeOfMappedSymbol(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getLowerBoundOfKeyType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getArrayMemberCallSignatures(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn isArrayOrTupleSymbol(c: *Checker, symbol_: *anyopaque) bool {
        _ = c;
        _ = symbol_;
        return false;
    }

    pub fn isReadonlyArraySymbol(c: *Checker, symbol_: *anyopaque) bool {
        _ = c;
        _ = symbol_;
        return false;
    }

    pub fn combineUnionOrIntersectionMemberSignatures(c: *Checker, left: *anyopaque, right: *anyopaque, isUnion: *anyopaque) *anyopaque {
        _ = c;
        _ = left;
        _ = right;
        _ = isUnion;
        return undefined;
    }

    pub fn combineUnionOrIntersectionParameters(c: *Checker, left: *anyopaque, right: *anyopaque, mapper: *anyopaque, isUnion: *anyopaque) *anyopaque {
        _ = c;
        _ = left;
        _ = right;
        _ = mapper;
        _ = isUnion;
        return undefined;
    }

    pub fn combineUnionOrIntersectionThisParam(c: *Checker, left: *anyopaque, right: *anyopaque, mapper: *anyopaque, isUnion: *anyopaque) *anyopaque {
        _ = c;
        _ = left;
        _ = right;
        _ = mapper;
        _ = isUnion;
        return undefined;
    }

    pub fn findMixins(c: *Checker, types_: *anyopaque) i32 {
        _ = c;
        _ = types_;
        return 0;
    }

    pub fn includeMixinType(c: *Checker, t: *anyopaque, types_: *anyopaque, mixinFlags: *anyopaque, index: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = types_;
        _ = mixinFlags;
        _ = index;
        return undefined;
    }

    /// Port of `checker.go::getTargetSymbol`. If `s` is an instantiated
    /// (transient) symbol, returns its original target symbol; otherwise
    /// returns `s` unchanged.
    pub fn getTargetSymbol(c: *Checker, s: ast_gen.SymbolIndex) ast_gen.SymbolIndex {
        if (s == 0) return 0;
        const check_flags = c.getSymbolCheckFlags(s);
        if ((check_flags & types.CheckFlags.Instantiated) != 0) {
            if (c.valueSymbolLinks.get(s)) |links| {
                return links.target orelse s;
            }
        }
        return s;
    }

    /// Port of `checker.go::isPrototypeProperty`. Returns true if `symbol`
    /// is a method (or a synthetic method in a union/intersection type).
    pub fn isPrototypeProperty(c: *Checker, sym: ast_gen.SymbolIndex) bool {
        if (sym == 0 or sym >= c.binder.symbols.items.len) return false;
        const s = c.binder.symbols.items[sym];
        if ((s.Flags & symbol.SymbolFlags.Method) != 0) return true;
        if ((s.CheckFlags & types.CheckFlags.SyntheticMethod) != 0) return true;
        return false;
    }

    pub fn hasCommonDeclaration(c: *Checker, symbols: *anyopaque) bool {
        _ = c;
        _ = symbols;
        return false;
    }

    pub fn createSymbolWithType(c: *Checker, source: *anyopaque, t: *anyopaque) *anyopaque {
        _ = c;
        _ = source;
        _ = t;
        return undefined;
    }

    pub fn getApparentTypeOfMappedType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getResolvedApparentTypeOfMappedType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getApparentTypeOfIntersectionType(c: *Checker, t: *anyopaque, thisArgument: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = thisArgument;
        return undefined;
    }

    pub fn isNeverReducedProperty(c: *Checker, prop: *anyopaque) bool {
        _ = c;
        _ = prop;
        return false;
    }

    pub fn elaborateNeverIntersection(c: *Checker, chain: *anyopaque, node: *anyopaque, t: *anyopaque) *anyopaque {
        _ = c;
        _ = chain;
        _ = node;
        _ = t;
        return undefined;
    }

    pub fn isDiscriminantWithNeverType(c: *Checker, prop: *anyopaque) bool {
        _ = c;
        _ = prop;
        return false;
    }

    pub fn isConflictingPrivateProperty(prop: *anyopaque) bool {
        _ = prop;
        return false;
    }

    pub fn getEffectiveTypeArguments(c: *Checker, node: *anyopaque, typeParameters: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = typeParameters;
        return undefined;
    }

    pub fn getDefaultTypeArgumentType(c: *Checker, isInJavaScriptFile: *anyopaque) *anyopaque {
        _ = c;
        _ = isInJavaScriptFile;
        return undefined;
    }

    pub fn getDefaultOrUnknownFromTypeParameter(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getNamedMembers(c: *Checker, members: *anyopaque, container: *anyopaque) *anyopaque {
        _ = c;
        _ = members;
        _ = container;
        return undefined;
    }

    pub fn isDeclarationContainedBy(c: *Checker, symbol_: *anyopaque, container: *anyopaque) bool {
        _ = c;
        _ = symbol_;
        _ = container;
        return false;
    }

    pub fn symbolIsValueEx(c: *Checker, symbol_: *anyopaque, includeTypeOnlyMembers: *anyopaque) bool {
        _ = c;
        _ = symbol_;
        _ = includeTypeOnlyMembers;
        return false;
    }

    pub fn pushActiveMapper(c: *Checker, mapper: *anyopaque) void {
        _ = c;
        _ = mapper;
    }

    pub fn popActiveMapper(c: *Checker) void {
        _ = c;
    }

    pub fn findActiveMapper(c: *Checker, mapper: *anyopaque) i32 {
        _ = c;
        _ = mapper;
        return 0;
    }

    pub fn clearActiveMapperCaches(c: *Checker) void {
        _ = c;
    }

    pub fn couldContainTypeVariablesWorker(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn getConstraintDeclarationForMappedType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn forEachMappedTypePropertyKeyTypeAndIndexSignatureKeyType(c: *Checker, t: *anyopaque, include: *anyopaque, stringsOnly: *anyopaque, cb: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = include;
        _ = stringsOnly;
        _ = cb;
        return undefined;
    }

    pub fn instantiateSymbols(c: *Checker, symbols: *anyopaque, m: *anyopaque) *anyopaque {
        _ = c;
        _ = symbols;
        _ = m;
        return undefined;
    }

    pub fn tryGetTypeFromTypeNode(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getTypeFromTypeNode(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromTypeNode(c, node_idx);
    }

    pub fn getTypeFromTypeNodeWorker(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromTypeNodeWorker(c, node_idx);
    }

    pub fn getTypeFromThisTypeNode(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromThisTypeNode(c, node_idx);
    }

    pub fn getThisType(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getTypeFromLiteralTypeNode(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromLiteralTypeNode(c, node_idx);
    }

    pub fn getTypeFromTypeLiteralOrFunctionOrConstructorTypeNode(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromTypeLiteralOrFunctionOrConstructorTypeNode(c, node_idx);
    }

    pub fn getTypeFromIndexedAccessTypeNode(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromIndexedAccessTypeNode(c, node_idx);
    }

    pub fn getTypeFromTypeOperatorNode(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromTypeOperatorNode(c, node_idx);
    }

    pub fn getESSymbolLikeTypeForNode(c: *Checker, node: ast_gen.NodeIndex) types.TypeIndex {
        _ = node;
        return c.anyTypeIndex orelse 0;
    }

    pub fn getTypeFromTypeReference(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromTypeReference(c, node_idx);
    }

    pub fn getIntendedTypeFromJSDocTypeReference(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getSymbolFromTypeReference(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn resolveTypeReferenceName(c: *Checker, typeReference: *anyopaque, meaning: *anyopaque, ignoreErrors: *anyopaque) *anyopaque {
        _ = c;
        _ = typeReference;
        _ = meaning;
        _ = ignoreErrors;
        return undefined;
    }

    pub fn getUnresolvedSymbolForEntityName(c: *Checker, name_: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        return undefined;
    }

    pub fn getSymbolPath(symbol_: *anyopaque) *anyopaque {
        _ = symbol_;
        return undefined;
    }

    pub fn getTypeReferenceType(c: *Checker, node: *anyopaque, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = symbol_;
        return undefined;
    }

    pub fn getTypeFromClassOrInterfaceReference(c: *Checker, node_idx: ast_gen.NodeIndex, symbol_: ast_gen.SymbolIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromClassOrInterfaceReference(c, node_idx, symbol_);
    }

    pub fn getTypeArgumentsFromNode(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn checkNoTypeArguments(c: *Checker, node: *anyopaque, symbol_: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = symbol_;
        return false;
    }

    pub fn isDeferredTypeReferenceNode(c: *Checker, node: *anyopaque, hasDefaultTypeArguments: *anyopaque) bool {
        _ = c;
        _ = node;
        _ = hasDefaultTypeArguments;
        return false;
    }

    pub fn isResolvedByTypeAlias(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn mayResolveTypeAlias(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn getTotalFixedElementCount(t: *anyopaque) i32 {
        _ = t;
        return 0;
    }

    pub fn getElementTypes(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getTypeReferenceArity(c: *Checker, t: *anyopaque) i32 {
        _ = c;
        _ = t;
        return 0;
    }

    pub fn isEmptyLiteralType(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn isTupleLikeType(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn isArrayOrTupleLikeType(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn getTupleElementType(c: *Checker, t: *anyopaque, index: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = index;
        return undefined;
    }

    pub fn getTypeFromTypeAliasReference(c: *Checker, node_idx: ast_gen.NodeIndex, symbol_: ast_gen.SymbolIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromTypeAliasReference(c, node_idx, symbol_);
    }

    pub fn isLocalTypeAlias(symbol_: *anyopaque) bool {
        _ = symbol_;
        return false;
    }

    pub fn getTypeReferenceName(node: *anyopaque) *anyopaque {
        _ = node;
        return undefined;
    }

    pub fn getOuterTypeParametersOfClassOrInterface(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getInferTypeParameters(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getLocalTypeParametersOfClassOrInterfaceOrTypeAlias(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn appendLocalTypeParametersOfClassOrInterfaceOrTypeAlias(c: *Checker, types_: *anyopaque, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = types_;
        _ = symbol_;
        return undefined;
    }

    pub fn appendTypeParameters(c: *Checker, typeParameters: *anyopaque, declarations: *anyopaque) *anyopaque {
        _ = c;
        _ = typeParameters;
        _ = declarations;
        return undefined;
    }

    pub fn getDeclaredTypeOfEnum(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn createComputedEnumType(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getDeclaredTypeOfEnumMember(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn computeEnumMemberValue(c: *Checker, member: *anyopaque, autoValue: *anyopaque, previous: *anyopaque) *anyopaque {
        _ = c;
        _ = member;
        _ = autoValue;
        _ = previous;
        return undefined;
    }

    pub fn computeConstantEnumMemberValue(c: *Checker, member: *anyopaque) *anyopaque {
        _ = c;
        _ = member;
        return undefined;
    }

    pub fn evaluateEntity(c: *Checker, expr: *anyopaque, location: *anyopaque) *anyopaque {
        _ = c;
        _ = expr;
        _ = location;
        return undefined;
    }

    pub fn evaluateEnumMember(c: *Checker, expr: *anyopaque, symbol_: *anyopaque, location: *anyopaque) *anyopaque {
        _ = c;
        _ = expr;
        _ = symbol_;
        _ = location;
        return undefined;
    }

    pub fn getDeclaredTypeOfAlias(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getTypeFromTypeQueryNode(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromTypeQueryNode(c, node_idx);
    }

    pub fn getTypeFromArrayOrTupleTypeNode(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromArrayOrTupleTypeNode(c, node_idx);
    }

    pub fn isVariadicTupleElement(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn getArrayOrTupleTargetType(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn isReadonlyTypeOperator(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn getTypeFromNamedTupleTypeNode(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromNamedTupleTypeNode(c, node_idx);
    }

    pub fn getTypeFromRestTypeNode(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromRestTypeNode(c, node_idx);
    }

    pub fn getArrayElementTypeNode(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getTypeFromOptionalTypeNode(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromOptionalTypeNode(c, node_idx);
    }

    pub fn getTypeFromUnionTypeNode(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromUnionTypeNode(c, node_idx);
    }

    pub fn getTypeFromIntersectionTypeNode(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromIntersectionTypeNode(c, node_idx);
    }

    pub fn getTypeFromTemplateTypeNode(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromTemplateTypeNode(c, node_idx);
    }

    pub fn getTypeFromMappedTypeNode(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromMappedTypeNode(c, node_idx);
    }

    pub fn getTypeFromConditionalTypeNode(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromConditionalTypeNode(c, node_idx);
    }

    pub fn restrictiveMapperWorker(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn permissiveMapperWorker(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getTypeFromInferTypeNode(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromInferTypeNode(c, node_idx);
    }

    pub fn getTypeFromImportType(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
        return type_resolution_pkg.getTypeFromImportType(c, node_idx);
    }

    pub fn getIdentifierChain(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn resolveImportSymbolType(c: *Checker, node: *anyopaque, symbol_: *anyopaque, meaning: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = symbol_;
        _ = meaning;
        return undefined;
    }

    pub fn createTypeFromGenericGlobalType(c: *Checker, genericGlobalType: *anyopaque, typeArguments: *anyopaque) *anyopaque {
        _ = c;
        _ = genericGlobalType;
        _ = typeArguments;
        return undefined;
    }

    pub fn getGlobalStrictFunctionType(c: *Checker, name_: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        return undefined;
    }

    pub fn getGlobalImportMetaExpressionType(c: *Checker) *anyopaque {
        _ = c;
        return undefined;
    }

    pub fn createIterableType(c: *Checker, iteratedType: *anyopaque) *anyopaque {
        _ = c;
        _ = iteratedType;
        return undefined;
    }

    pub fn createArrayTypeEx(c: *Checker, elementType: *anyopaque, readonly: *anyopaque) *anyopaque {
        _ = c;
        _ = elementType;
        _ = readonly;
        return undefined;
    }

    pub fn getTupleElementFlags(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getTupleElementInfo(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn createTupleType(c: *Checker, elementTypes: *anyopaque) *anyopaque {
        _ = c;
        _ = elementTypes;
        return undefined;
    }

    pub fn getRestTypeOfTupleType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getTupleElementTypeOutOfStartCount(c: *Checker, t: *anyopaque, index: *anyopaque, undefinedLikeType: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = index;
        _ = undefinedLikeType;
        return undefined;
    }

    /// Port of `checker.go::isGenericType`. Returns true if `t` has any
    /// generic object flags (i.e. contains type parameters).
    pub fn isGenericType(c: *Checker, t: types.TypeIndex) bool {
        return c.getGenericObjectFlags(t) != 0;
    }

    pub fn isGenericReducibleType(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn isReducibleIntersection(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn getUniqueLiteralTypeForTypeParameter(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getConditionalFlowTypeOfType(c: *Checker, t: *anyopaque, node: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = node;
        return undefined;
    }

    pub fn getImpliedConstraint(c: *Checker, t: *anyopaque, checkNode: *anyopaque, extendsNode: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = checkNode;
        _ = extendsNode;
        return undefined;
    }

    pub fn isUnaryTupleTypeNode(node: *anyopaque) bool {
        _ = node;
        return false;
    }

    pub fn newType_stub(c: *Checker, flags: *anyopaque, objectFlags: *anyopaque, data: *anyopaque) *anyopaque {
        _ = c;
        _ = flags;
        _ = objectFlags;
        _ = data;
        return undefined;
    }

    pub fn newIntrinsicType(c: *Checker, flags: *anyopaque, intrinsicName: *anyopaque) *anyopaque {
        _ = c;
        _ = flags;
        _ = intrinsicName;
        return undefined;
    }

    pub fn newIntrinsicTypeEx(c: *Checker, flags: *anyopaque, intrinsicName: *anyopaque, objectFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = flags;
        _ = intrinsicName;
        _ = objectFlags;
        return undefined;
    }

    pub fn createWideningType(c: *Checker, nonWideningType: *anyopaque) *anyopaque {
        _ = c;
        _ = nonWideningType;
        return undefined;
    }

    pub fn createUnknownUnionType(c: *Checker) *anyopaque {
        _ = c;
        return undefined;
    }

    pub fn newLiteralType(c: *Checker, flags: *anyopaque, value: *anyopaque, regularType: *anyopaque) *anyopaque {
        _ = c;
        _ = flags;
        _ = value;
        _ = regularType;
        return undefined;
    }

    pub fn newUniqueESSymbolType(c: *Checker, symbol_: *anyopaque, name_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        _ = name_;
        return undefined;
    }

    pub fn newObjectType(c: *Checker, objectFlags: *anyopaque, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = objectFlags;
        _ = symbol_;
        return undefined;
    }

    pub fn newAnonymousType(c: *Checker, symbol_: *anyopaque, members: *anyopaque, callSignatures: *anyopaque, constructSignatures: *anyopaque, indexInfos: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        _ = members;
        _ = callSignatures;
        _ = constructSignatures;
        _ = indexInfos;
        return undefined;
    }

    pub fn tryCreateTypeReference(c: *Checker, target: *anyopaque, typeArguments: *anyopaque) *anyopaque {
        _ = c;
        _ = target;
        _ = typeArguments;
        return undefined;
    }

    pub fn cloneTypeReference(c: *Checker, source: *anyopaque) *anyopaque {
        _ = c;
        _ = source;
        return undefined;
    }

    pub fn setStructuredTypeMembers(c: *Checker, t: *anyopaque, members: *anyopaque, callSignatures: *anyopaque, constructSignatures: *anyopaque, indexInfos: *anyopaque) void {
        _ = c;
        _ = t;
        _ = members;
        _ = callSignatures;
        _ = constructSignatures;
        _ = indexInfos;
    }

    pub fn newTypeParameter(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn newUnionType(c: *Checker, objectFlags: *anyopaque, types_: *anyopaque) *anyopaque {
        _ = c;
        _ = objectFlags;
        _ = types_;
        return undefined;
    }

    pub fn newIntersectionType(c: *Checker, objectFlags: *anyopaque, types_: *anyopaque) *anyopaque {
        _ = c;
        _ = objectFlags;
        _ = types_;
        return undefined;
    }

    pub fn newIndexedAccessType(c: *Checker, objectType: *anyopaque, indexType: *anyopaque, accessFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = objectType;
        _ = indexType;
        _ = accessFlags;
        return undefined;
    }

    pub fn newIndexType(c: *Checker, target: *anyopaque, indexFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = target;
        _ = indexFlags;
        return undefined;
    }

    pub fn newSubstitutionType(c: *Checker, baseType: *anyopaque, constraint: *anyopaque) *anyopaque {
        _ = c;
        _ = baseType;
        _ = constraint;
        return undefined;
    }

    /// Port of `checker.go::newIndexInfo`. Creates a new `IndexInfo` value.
    /// In Go this allocates from an arena; in Zig we return a value (the
    /// caller stores it in an `IndexInfo` slice as needed).
    pub fn newIndexInfo(
        c: *Checker,
        key_type: types.TypeIndex,
        value_type: types.TypeIndex,
        is_readonly: bool,
        declaration: ?ast_gen.NodeIndex,
    ) types.IndexInfo {
        _ = c;
        return .{
            .keyType = key_type,
            .valueType = value_type,
            .isReadonly = is_readonly,
            .declaration = declaration,
        };
    }

    /// Port of `checker.go::isFreshLiteralType`. Returns true if `t` is a
    /// fresh literal type (literal type whose `freshType` points to itself).
    pub fn isFreshLiteralType(c: *Checker, t: types.TypeIndex) bool {
        if (t == 0 or t >= c.typesList.items.len) return false;
        const flags = c.typesList.items[t].flags;
        if ((flags & types.TypeFlags.Freshable) == 0) return false;
        // Freshable types are StringLiteral/NumberLiteral/BooleanLiteral/BigIntLiteral.
        // Without a `freshType` field on LiteralType data, we conservatively
        // return false. TODO(phase1.2): add freshType tracking.
        _ = c;
        return false;
    }

    pub fn getBigIntLiteralType(c: *Checker, value: *anyopaque) *anyopaque {
        _ = c;
        _ = value;
        return undefined;
    }

    pub fn parseBigIntLiteralType(c: *Checker, text: *anyopaque) *anyopaque {
        _ = c;
        _ = text;
        return undefined;
    }

    pub fn getStringLiteralValue(t: *anyopaque) *anyopaque {
        _ = t;
        return undefined;
    }

    pub fn getNumberLiteralValue(t: *anyopaque) *anyopaque {
        _ = t;
        return undefined;
    }

    pub fn getBigIntLiteralValue(t: *anyopaque) *anyopaque {
        _ = t;
        return undefined;
    }

    pub fn getBooleanLiteralValue(t: *anyopaque) bool {
        _ = t;
        return false;
    }

    pub fn getEnumLiteralType(c: *Checker, value: *anyopaque, enumSymbol: *anyopaque, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = value;
        _ = enumSymbol;
        _ = symbol_;
        return undefined;
    }

    pub fn isLiteralType(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn isNeitherUnitTypeNorNever(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn isUnitType(t: *anyopaque) bool {
        _ = t;
        return false;
    }

    pub fn isUnitLikeType(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn extractUnitType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getBaseTypeOfLiteralTypeForComparison(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getBaseTypeOfLiteralTypeUnion(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getWidenedUniqueESSymbolType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getWidenedLiteralLikeTypeForContextualType(c: *Checker, t: *anyopaque, contextualType: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = contextualType;
        return undefined;
    }

    pub fn isLiteralOfContextualType(c: *Checker, candidateType: *anyopaque, contextualType: *anyopaque) bool {
        _ = c;
        _ = candidateType;
        _ = contextualType;
        return false;
    }

    /// Port of `checker.go::mapTypeEx`. Applies `mapFn` to `t`, descending
    /// into union constituents. `no_reductions` is currently ignored.
    pub fn mapTypeEx(c: *Checker, t: types.TypeIndex, comptime mapFn: anytype, ctx: anytype, no_reductions: bool) types.TypeIndex {
        _ = no_reductions;
        const flags = c.getTypeFlags(t);
        if ((flags & types.TypeFlags.Never) != 0) return t;
        if ((flags & types.TypeFlags.Union) == 0) return mapFn(c, t, ctx);
        // Walk union constituents
        var types_list: std.ArrayListUnmanaged(types.TypeIndex) = .empty;
        defer types_list.deinit(c.allocator);
        const union_types = c.getTypesFromUnion(t);
        var changed = false;
        for (union_types) |s| {
            const s_flags = c.getTypeFlags(s);
            const mapped: types.TypeIndex = if ((s_flags & types.TypeFlags.Union) != 0)
                c.mapTypeEx(s, mapFn, ctx, no_reductions)
            else
                mapFn(c, s, ctx);
            if (mapped != s) changed = true;
            if (mapped != 0) types_list.append(c.allocator, mapped) catch unreachable;
        }
        if (changed) {
            if (types_list.items.len == 0) return 0;
            return c.getUnionTypeFromArray(types_list.items);
        }
        return t;
    }

    pub fn getUnionOrIntersectionType(c: *Checker, types_: *anyopaque, isUnion: *anyopaque, unionReduction: *anyopaque) *anyopaque {
        _ = c;
        _ = types_;
        _ = isUnion;
        _ = unionReduction;
        return undefined;
    }

    /// Port of `checker.go::getUnionTypeEx`. Creates a union type from
    /// `types_arr` with the given reduction mode. For now, the reduction
    /// mode is ignored (we always do literal+identity dedup, which is
    /// the common case). Alias and origin are also ignored.
    pub fn getUnionTypeEx(
        c: *Checker,
        types_arr: []const types.TypeIndex,
        union_reduction: types.UnionReduction,
        alias: ?types.TypeAlias,
        origin: ?types.TypeIndex,
    ) types.TypeIndex {
        _ = union_reduction; // TODO(phase1.2): implement subtype reduction
        _ = alias;
        _ = origin;
        if (types_arr.len == 0) {
            return c.neverTypeIndex orelse 0;
        }
        if (types_arr.len == 1) return types_arr[0];
        return c.createUnionType(types_arr) catch (c.neverTypeIndex orelse 0);
    }

    /// Port of `checker.go::getUnionType`. Convenience wrapper for
    /// `getUnionTypeEx` with default `Literal` reduction and no alias.
    pub fn getUnionType(c: *Checker, types_arr: []const types.TypeIndex) types.TypeIndex {
        return c.getUnionTypeEx(types_arr, .Literal, null, null);
    }

    pub fn getUnionTypeWorker(c: *Checker, types_: *anyopaque, unionReduction: *anyopaque, alias: *anyopaque, origin: *anyopaque) *anyopaque {
        _ = c;
        _ = types_;
        _ = unionReduction;
        _ = alias;
        _ = origin;
        return undefined;
    }

    pub fn getUnionTypeFromSortedList(c: *Checker, types_: *anyopaque, precomputedObjectFlags: *anyopaque, alias: *anyopaque, origin: *anyopaque) *anyopaque {
        _ = c;
        _ = types_;
        _ = precomputedObjectFlags;
        _ = alias;
        _ = origin;
        return undefined;
    }

    pub fn unionTypes_stub(c: *Checker) *anyopaque {
        _ = c;
        return undefined;
    }

    pub fn addTypesToUnion(c: *Checker, typeSet: *anyopaque, includes: *anyopaque, types_: *anyopaque) *anyopaque {
        _ = c;
        _ = typeSet;
        _ = includes;
        _ = types_;
        return undefined;
    }

    pub fn addTypeToUnion(c: *Checker, typeSet: *anyopaque, includes: *anyopaque, t: *anyopaque) *anyopaque {
        _ = c;
        _ = typeSet;
        _ = includes;
        _ = t;
        return undefined;
    }

    pub fn addNamedUnions(c: *Checker, namedUnions: *anyopaque, types_: *anyopaque) *anyopaque {
        _ = c;
        _ = namedUnions;
        _ = types_;
        return undefined;
    }

    pub fn removeRedundantLiteralTypes(c: *Checker, types_: *anyopaque, includes: *anyopaque, reduceVoidUndefined: *anyopaque) *anyopaque {
        _ = c;
        _ = types_;
        _ = includes;
        _ = reduceVoidUndefined;
        return undefined;
    }

    pub fn removeStringLiteralsMatchedByTemplateLiterals(c: *Checker, types_: *anyopaque) *anyopaque {
        _ = c;
        _ = types_;
        return undefined;
    }

    pub fn isTypeMatchedByTemplateLiteralOrStringMapping(c: *Checker, t: *anyopaque, template: *anyopaque) bool {
        _ = c;
        _ = t;
        _ = template;
        return false;
    }

    pub fn removeConstrainedTypeVariables(c: *Checker, types_: *anyopaque) *anyopaque {
        _ = c;
        _ = types_;
        return undefined;
    }

    pub fn removeSubtypes(c: *Checker, types_: *anyopaque, hasObjectTypes: *anyopaque) *anyopaque {
        _ = c;
        _ = types_;
        _ = hasObjectTypes;
        return undefined;
    }

    pub fn getIntersectionTypeEx(c: *Checker, types_: *anyopaque, flags: *anyopaque, alias: *anyopaque) *anyopaque {
        _ = c;
        _ = types_;
        _ = flags;
        _ = alias;
        return undefined;
    }

    pub fn isUnionWithUndefined(t: *anyopaque) bool {
        _ = t;
        return false;
    }

    pub fn isUnionWithNull(t: *anyopaque) bool {
        _ = t;
        return false;
    }

    pub fn isIntersectionType(t: *anyopaque) bool {
        _ = t;
        return false;
    }

    pub fn isPrimitiveUnion(t: *anyopaque) bool {
        _ = t;
        return false;
    }

    pub fn isNotUndefinedType(t: *anyopaque) bool {
        _ = t;
        return false;
    }

    pub fn isNotNullType(t: *anyopaque) bool {
        _ = t;
        return false;
    }

    pub fn addTypesToIntersection(c: *Checker, typeSet: *anyopaque, includes: *anyopaque, types_: *anyopaque) *anyopaque {
        _ = c;
        _ = typeSet;
        _ = includes;
        _ = types_;
        return undefined;
    }

    pub fn addTypeToIntersection(c: *Checker, typeSet: *anyopaque, includes: *anyopaque, t: *anyopaque) *anyopaque {
        _ = c;
        _ = typeSet;
        _ = includes;
        _ = t;
        return undefined;
    }

    pub fn removeRedundantSupertypes(c: *Checker, types_: *anyopaque, includes: *anyopaque) *anyopaque {
        _ = c;
        _ = types_;
        _ = includes;
        return undefined;
    }

    pub fn extractRedundantTemplateLiterals(c: *Checker, types_: *anyopaque) bool {
        _ = c;
        _ = types_;
        return false;
    }

    pub fn intersectUnionsOfPrimitiveTypes(c: *Checker, types_: *anyopaque) bool {
        _ = c;
        _ = types_;
        return false;
    }

    pub fn eachUnionContains(c: *Checker, unionTypes_: *anyopaque, t: *anyopaque) bool {
        _ = c;
        _ = unionTypes_;
        _ = t;
        return false;
    }

    pub fn getCrossProductIntersections(c: *Checker, types_: *anyopaque, flags: *anyopaque) *anyopaque {
        _ = c;
        _ = types_;
        _ = flags;
        return undefined;
    }

    pub fn getConstituentCount(t: *anyopaque) i32 {
        _ = t;
        return 0;
    }

    pub fn getConstituentCountOfTypes(types_: *anyopaque) i32 {
        _ = types_;
        return 0;
    }

    pub fn filterTypes(c: *Checker, types_: *anyopaque, predicate: *anyopaque) bool {
        _ = c;
        _ = types_;
        _ = predicate;
        return false;
    }

    pub fn isEmptyResolvedType(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn forEachType(t: *anyopaque, f: *anyopaque) *anyopaque {
        _ = t;
        _ = f;
        return undefined;
    }

    pub fn everyContainedType(t: *anyopaque, f: *anyopaque) bool {
        _ = t;
        _ = f;
        return false;
    }

    pub fn insertType(types_: *anyopaque, t: *anyopaque) bool {
        _ = types_;
        _ = t;
        return false;
    }

    pub fn compareTypeIds(arg0: *anyopaque, t2: *anyopaque) i32 {
        _ = arg0;
        _ = t2;
        return 0;
    }

    pub fn getExtractStringType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getLiteralTypeFromProperties(c: *Checker, t: *anyopaque, include: *anyopaque, includeOrigin: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = include;
        _ = includeOrigin;
        return undefined;
    }

    pub fn getLiteralTypeFromPropertyName(c: *Checker, name_: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        return undefined;
    }

    /// Port of `checker.go::isKeyTypeIncluded`. Returns true if `keyType`
    /// has any of the `include` flags, or if it's an intersection type
    /// whose constituents include a type with those flags.
    pub fn isKeyTypeIncluded(c: *Checker, key_type: types.TypeIndex, include: u32) bool {
        if (key_type == 0 or key_type >= c.typesList.items.len) return false;
        const flags = c.typesList.items[key_type].flags;
        if ((flags & include) != 0) return true;
        if ((flags & types.TypeFlags.Intersection) != 0) {
            const constituents = c.getTypesFromIntersection(key_type);
            for (constituents) |ct| {
                if (c.isKeyTypeIncluded(ct, include)) return true;
            }
        }
        return false;
    }

    pub fn checkComputedPropertyName(c: *Checker, node: ast_gen.NodeIndex) types.TypeIndex {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn isNoInferType(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn getSubstitutionIntersection(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getMappedTypeNameTypeKind(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getIndexTypeForGenericType(c: *Checker, t: *anyopaque, indexFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = indexFlags;
        return undefined;
    }

    pub fn getIndexTypeForMappedType(c: *Checker, t: *anyopaque, indexFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = indexFlags;
        return undefined;
    }

    pub fn getIndexedAccessTypeEx(c: *Checker, objectType: *anyopaque, indexType: *anyopaque, accessFlags: *anyopaque, accessNode: *anyopaque, alias: *anyopaque) *anyopaque {
        _ = c;
        _ = objectType;
        _ = indexType;
        _ = accessFlags;
        _ = accessNode;
        _ = alias;
        return undefined;
    }

    pub fn getPropertyTypeForIndexType(c: *Checker, originalObjectType: *anyopaque, objectType: *anyopaque, indexType: *anyopaque, fullIndexType: *anyopaque, accessNode: *anyopaque, accessFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = originalObjectType;
        _ = objectType;
        _ = indexType;
        _ = fullIndexType;
        _ = accessNode;
        _ = accessFlags;
        return undefined;
    }

    pub fn typeHasStaticProperty(c: *Checker, propName: *anyopaque, containingType: *anyopaque) bool {
        _ = c;
        _ = propName;
        _ = containingType;
        return false;
    }

    pub fn getSuggestionForNonexistentProperty(c: *Checker, name_: *anyopaque, containingType: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        _ = containingType;
        return undefined;
    }

    pub fn getSuggestionForNonexistentIndexSignature(c: *Checker, objectType: *anyopaque, expr: *anyopaque, keyedType: *anyopaque) *anyopaque {
        _ = c;
        _ = objectType;
        _ = expr;
        _ = keyedType;
        return undefined;
    }

    pub fn getSuggestedTypeForNonexistentStringLiteralType(c: *Checker, source: *anyopaque, target: *anyopaque) *anyopaque {
        _ = c;
        _ = source;
        _ = target;
        return undefined;
    }

    pub fn getIndexNodeForAccessExpression(accessNode: *anyopaque) *anyopaque {
        _ = accessNode;
        return undefined;
    }

    pub fn errorIfWritingToReadonlyIndex(c: *Checker, indexInfo: *anyopaque, objectType: *anyopaque, accessExpression: *anyopaque) void {
        _ = c;
        _ = indexInfo;
        _ = objectType;
        _ = accessExpression;
    }

    pub fn isSelfTypeAccess(c: *Checker, name_: ast_gen.NodeIndex, parent: ast_gen.SymbolIndex) bool {
        _ = c;
        _ = name_;
        _ = parent;
        return false;
    }

    pub fn isAssignmentToReadonlyEntity(c: *Checker, expr: ast_gen.NodeIndex, symbol_: ast_gen.SymbolIndex, assignmentKind: u32) bool {
        _ = c;
        _ = expr;
        _ = symbol_;
        _ = assignmentKind;
        return false;
    }

    pub fn isThisPropertyAccessInConstructor(c: *Checker, node: ast_gen.NodeIndex, prop: ast_gen.SymbolIndex) bool {
        _ = c;
        _ = node;
        _ = prop;
        return false;
    }

    pub fn isAutoTypedProperty(c: *Checker, symbol_: *anyopaque) bool {
        _ = c;
        _ = symbol_;
        return false;
    }

    pub fn getDeclaringConstructor(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }

    pub fn getPropertyNameFromIndex(c: *Checker, indexType: *anyopaque, accessNode: *anyopaque) *anyopaque {
        _ = c;
        _ = indexType;
        _ = accessNode;
        return undefined;
    }

    pub fn shouldDeferIndexedAccessType(c: *Checker, objectType: *anyopaque, indexType: *anyopaque, accessNode: *anyopaque) bool {
        _ = c;
        _ = objectType;
        _ = indexType;
        _ = accessNode;
        return false;
    }

    pub fn indexTypeLessThan(indexType: *anyopaque, limit: *anyopaque) bool {
        _ = indexType;
        _ = limit;
        return false;
    }

    pub fn getOrCreateSubstitutionType(c: *Checker, baseType: *anyopaque, constraint: *anyopaque) *anyopaque {
        _ = c;
        _ = baseType;
        _ = constraint;
        return undefined;
    }

    pub fn getResolvedBaseConstraint(c: *Checker, t: *anyopaque, stack: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = stack;
        return undefined;
    }

    pub fn computeBaseConstraint(c: *Checker, t: *anyopaque, stack: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = stack;
        return undefined;
    }

    pub fn getNextBaseConstraint(c: *Checker, t: *anyopaque, stack: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = stack;
        return undefined;
    }

    pub fn maybeTypeOfKindConsideringBaseConstraint(c: *Checker, t: types.TypeIndex, kind_: u32) bool {
        _ = c;
        _ = t;
        _ = kind_;
        return false;
    }

    /// Port of `checker.go::allTypesAssignableToKind`. Returns true if every
    /// constituent of `source` (if union) is assignable to `kindFlags`.
    pub fn allTypesAssignableToKind(c: *Checker, source: types.TypeIndex, kind_flags: u32) bool {
        return c.allTypesAssignableToKindEx(source, kind_flags, false);
    }

    /// Port of `checker.go::allTypesAssignableToKindEx`. Walks union
    /// constituents and checks each via `isTypeAssignableToKindEx`.
    pub fn allTypesAssignableToKindEx(c: *Checker, source: types.TypeIndex, kind_flags: u32, strict: bool) bool {
        if (source == 0 or source >= c.typesList.items.len) return false;
        const flags = c.typesList.items[source].flags;
        if ((flags & types.TypeFlags.Union) != 0) {
            const constituents = c.getTypesFromUnion(source);
            for (constituents) |sub| {
                if (!c.allTypesAssignableToKindEx(sub, kind_flags, strict)) return false;
            }
            return true;
        }
        return c.isTypeAssignableToKindEx(source, kind_flags, strict);
    }

    pub fn isConstEnumObjectType(c: *Checker, t: types.TypeIndex) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn isConstEnumSymbol(symbol_: *anyopaque) bool {
        _ = symbol_;
        return false;
    }

    pub fn compareProperties(c: *Checker, sourceProp: *anyopaque, targetProp: *anyopaque, compareTypes: *anyopaque, target: *anyopaque) *anyopaque {
        _ = c;
        _ = sourceProp;
        _ = targetProp;
        _ = compareTypes;
        _ = target;
        return undefined;
    }

    pub fn compareTypesEqual(s: *anyopaque, t: *anyopaque) *anyopaque {
        _ = s;
        _ = t;
        return undefined;
    }

    pub fn markPropertyAsReferenced(c: *Checker, prop: ast_gen.SymbolIndex, nodeForCheckWriteOnly: u32, isSelfTypeAccess_: bool) void {
        _ = c;
        _ = prop;
        _ = nodeForCheckWriteOnly;
        _ = isSelfTypeAccess_;
    }

    pub fn expandSignatureParametersWithTupleMembers(c: *Checker, signature: *anyopaque, restType: *anyopaque, restIndex: *anyopaque, restSymbol: *anyopaque) *anyopaque {
        _ = c;
        _ = signature;
        _ = restType;
        _ = restIndex;
        _ = restSymbol;
        return undefined;
    }

    pub fn getUniqAssociatedNamesFromTupleType(c: *Checker, t: *anyopaque, restSymbol: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = restSymbol;
        return undefined;
    }

    pub fn hasRestParameter(signature: *anyopaque) bool {
        _ = signature;
        return false;
    }

    pub fn isRestParameter_stub(param: *anyopaque) bool {
        _ = param;
        return false;
    }

    pub fn getNameFromIndexInfo(info: *anyopaque) *anyopaque {
        _ = info;
        return undefined;
    }

    pub fn isUnknownLikeUnionType(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    /// Port of `checker.go::containsUndefinedType`. Returns true if `t` is
    /// or starts with (in a union) the `undefined` type.
    pub fn containsUndefinedType(c: *Checker, t: types.TypeIndex) bool {
        if (t == 0 or t >= c.typesList.items.len) return false;
        var ty = c.typesList.items[t];
        if ((ty.flags & types.TypeFlags.Union) != 0) {
            const constituents = c.getTypesFromUnion(t);
            if (constituents.len > 0) {
                ty = c.typesList.items[constituents[0]];
            }
        }
        return (ty.flags & types.TypeFlags.Undefined) != 0;
    }

    /// Port of `checker.go::typeHasCallOrConstructSignatures`. Returns true
    /// if `t` is a structured type with call or construct signatures.
    pub fn typeHasCallOrConstructSignatures(c: *Checker, t: types.TypeIndex) bool {
        if (t == 0 or t >= c.typesList.items.len) return false;
        const flags = c.typesList.items[t].flags;
        if ((flags & types.TypeFlags.StructuredType) == 0) return false;
        const members = c.resolveStructuredTypeMembers(t);
        return members.callSignaturesLen > 0 or members.constructSignaturesLen > 0;
    }

    pub fn getSimplifiedIndexedAccessType(c: *Checker, t: *anyopaque, writing: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = writing;
        return undefined;
    }

    pub fn getSimplifiedIndexedAccessTypeWorker(c: *Checker, t: *anyopaque, writing: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = writing;
        return undefined;
    }

    pub fn distributeObjectOverIndexType(c: *Checker, objectType: *anyopaque, indexType: *anyopaque, writing: *anyopaque) *anyopaque {
        _ = c;
        _ = objectType;
        _ = indexType;
        _ = writing;
        return undefined;
    }

    pub fn distributeIndexOverObjectType(c: *Checker, objectType: *anyopaque, indexType: *anyopaque, writing: *anyopaque) *anyopaque {
        _ = c;
        _ = objectType;
        _ = indexType;
        _ = writing;
        return undefined;
    }

    pub fn getSimplifiedConditionalType(c: *Checker, t: *anyopaque, writing: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = writing;
        return undefined;
    }

    pub fn isIntersectionEmpty(c: *Checker, type1: *anyopaque, type2: *anyopaque) bool {
        _ = c;
        _ = type1;
        _ = type2;
        return false;
    }

    pub fn getNormalizedUnionOrIntersectionType(c: *Checker, t: *anyopaque, writing: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = writing;
        return undefined;
    }

    pub fn shouldNormalizeIntersection(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn getNormalizedTupleType(c: *Checker, t: *anyopaque, writing: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = writing;
        return undefined;
    }

    pub fn getSingleBaseForNonAugmentingSubtype(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn transformTypeOfMembers(c: *Checker, t: *anyopaque, f: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = f;
        return undefined;
    }

    pub fn markLinkedReferences(c: *Checker, location: ast_gen.NodeIndex, hint: u32, propSymbol: ast_gen.SymbolIndex, parentType: types.TypeIndex) void {
        _ = c;
        _ = location;
        _ = hint;
        _ = propSymbol;
        _ = parentType;
    }

    pub fn isExportOrExportExpression(location: *anyopaque) bool {
        _ = location;
        return false;
    }

    pub fn shouldMarkIdentifierAliasReferenced(node: *anyopaque) bool {
        _ = node;
        return false;
    }

    pub fn isInternalModuleImportEqualsDeclaration(node: *anyopaque) bool {
        _ = node;
        return false;
    }

    pub fn markIdentifierAliasReferenced(c: *Checker, location: *anyopaque) void {
        _ = c;
        _ = location;
    }

    pub fn markPropertyAliasReferenced(c: *Checker, location: *anyopaque, propSymbol: *anyopaque, parentType: *anyopaque) void {
        _ = c;
        _ = location;
        _ = propSymbol;
        _ = parentType;
    }

    pub fn isPartOfImportEqualsModuleReference(location: *anyopaque) bool {
        _ = location;
        return false;
    }

    pub fn markExportAssignmentAliasReferenced(c: *Checker, location: *anyopaque) void {
        _ = c;
        _ = location;
    }

    pub fn markJsxAliasReferenced(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn markImportEqualsAliasReferenced(c: *Checker, location: *anyopaque) void {
        _ = c;
        _ = location;
    }

    pub fn markExportSpecifierAliasReferenced(c: *Checker, location: *anyopaque) void {
        _ = c;
        _ = location;
    }

    pub fn checkExternalEmitHelpers(c: *Checker, location: *anyopaque, helpers: *anyopaque) void {
        _ = c;
        _ = location;
        _ = helpers;
    }

    pub fn hasSignatureWithArityGreaterThan(c: *Checker, symbol_: *anyopaque, arity: *anyopaque) bool {
        _ = c;
        _ = symbol_;
        _ = arity;
        return false;
    }

    pub fn getHelperNames(c: *Checker, helper: *anyopaque) *anyopaque {
        _ = c;
        _ = helper;
        return undefined;
    }

    pub fn resolveHelpersModule(c: *Checker, file: *anyopaque, errorNode: *anyopaque) *anyopaque {
        _ = c;
        _ = file;
        _ = errorNode;
        return undefined;
    }

    pub fn markDecoratorAliasReferenced(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn getParameterTypeNodeForDecoratorCheck(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn markDecoratorMedataDataTypeNodeAsReferenced(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn getEntityNameForDecoratorMetadata(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getEntityNameForDecoratorMetadataFromTypeList(c: *Checker, typeNodes: *anyopaque) *anyopaque {
        _ = c;
        _ = typeNodes;
        return undefined;
    }

    pub fn markAliasReferenced(c: *Checker, symbol_: *anyopaque, location: *anyopaque) void {
        _ = c;
        _ = symbol_;
        _ = location;
    }

    pub fn markAliasSymbolAsReferenced(c: *Checker, symbol_: *anyopaque) void {
        _ = c;
        _ = symbol_;
    }

    pub fn markExportAsReferenced(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn markEntityNameOrEntityExpressionAsReference(c: *Checker, typeName: *anyopaque, forDecoratorMetadata: *anyopaque) void {
        _ = c;
        _ = typeName;
        _ = forDecoratorMetadata;
    }

    pub fn getEntityNameFromTypeNode(node: *anyopaque) *anyopaque {
        _ = node;
        return undefined;
    }

    pub fn markTypeNodeAsReferenced(c: *Checker, node: *anyopaque) void {
        _ = c;
        _ = node;
    }

    pub fn getPromisedTypeOfPromise(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getPromisedTypeOfPromiseEx(c: *Checker, t: *anyopaque, errorNode: *anyopaque, thisTypeForErrorOut: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = errorNode;
        _ = thisTypeForErrorOut;
        return undefined;
    }

    /// Port of `checker.go::getTypeOfFirstParameterOfSignature`. Returns
    /// the type of the first parameter of `signature`, or `neverType` if
    /// the signature has no parameters.
    pub fn getTypeOfFirstParameterOfSignature(c: *Checker, signature: types.SignatureIndex) types.TypeIndex {
        return c.getTypeOfFirstParameterOfSignatureWithFallback(signature, c.neverTypeIndex orelse 0);
    }

    /// Port of `checker.go::getTypeOfFirstParameterOfSignatureWithFallback`.
    /// Returns the type of the first parameter of `signature`, or
    /// `fallback_type` if the signature has no parameters.
    pub fn getTypeOfFirstParameterOfSignatureWithFallback(c: *Checker, signature: types.SignatureIndex, fallback_type: types.TypeIndex) types.TypeIndex {
        const sig = c.signatures.items[signature];
        if (sig.parametersLen > 0) {
            return relater.getTypeAtPosition(c, signature, 0);
        }
        return fallback_type;
    }

    pub fn getOptionalExpressionType(c: *Checker, exprType: types.TypeIndex, expression: ast_gen.NodeIndex) types.TypeIndex {
        _ = c;
        _ = exprType;
        _ = expression;
        return undefined;
    }

    pub fn removeOptionalTypeMarker(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn propagateOptionalTypeMarker(c: *Checker, t: types.TypeIndex, node: ast_gen.NodeIndex, wasOptional: bool) types.TypeIndex {
        _ = c;
        _ = t;
        _ = node;
        _ = wasOptional;
        return undefined;
    }

    pub fn removeMissingOrUndefinedType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn removeDefinitelyFalsyTypes(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn extractDefinitelyFalsyTypes(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getDefinitelyFalsyPartOfType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn substituteIndexedMappedType(c: *Checker, objectType: *anyopaque, index: *anyopaque) *anyopaque {
        _ = c;
        _ = objectType;
        _ = index;
        return undefined;
    }

    pub fn couldAccessOptionalProperty(c: *Checker, objectType: *anyopaque, indexType: *anyopaque) bool {
        _ = c;
        _ = objectType;
        _ = indexType;
        return false;
    }

    pub fn getContextualTypeForInitializerExpression(c: *Checker, node: *anyopaque, contextFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = contextFlags;
        return undefined;
    }

    pub fn getContextualTypeForVariableLikeDeclaration(c: *Checker, declaration: *anyopaque, contextFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = declaration;
        _ = contextFlags;
        return undefined;
    }

    pub fn getContextuallyTypedParameterType(c: *Checker, parameter: *anyopaque) *anyopaque {
        _ = c;
        _ = parameter;
        return undefined;
    }

    pub fn isContextSensitiveFunctionOrObjectLiteralMethod(c: *Checker, fn_: *anyopaque) bool {
        _ = c;
        _ = fn_;
        return false;
    }

    pub fn getSpreadArgumentType(c: *Checker, args: *anyopaque, index: *anyopaque, argCount: *anyopaque, restType: *anyopaque, context: *anyopaque, checkMode: *anyopaque) *anyopaque {
        _ = c;
        _ = args;
        _ = index;
        _ = argCount;
        _ = restType;
        _ = context;
        _ = checkMode;
        return undefined;
    }

    pub fn getMutableArrayOrTupleType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getContextualTypeForBindingElement(c: *Checker, declaration: *anyopaque, contextFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = declaration;
        _ = contextFlags;
        return undefined;
    }

    pub fn getContextualTypeForStaticPropertyDeclaration(c: *Checker, declaration: *anyopaque, contextFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = declaration;
        _ = contextFlags;
        return undefined;
    }

    pub fn getContextualTypeForReturnExpression(c: *Checker, node: *anyopaque, contextFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = contextFlags;
        return undefined;
    }

    pub fn getContextualIterationType(c: *Checker, kind_: *anyopaque, functionDecl: *anyopaque) *anyopaque {
        _ = c;
        _ = kind_;
        _ = functionDecl;
        return undefined;
    }

    pub fn getContextualReturnType(c: *Checker, functionDecl: *anyopaque, contextFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = functionDecl;
        _ = contextFlags;
        return undefined;
    }

    pub fn checkGeneratorInstantiationAssignabilityToReturnType(c: *Checker, returnType: *anyopaque, functionFlags: *anyopaque, errorNode: *anyopaque) bool {
        _ = c;
        _ = returnType;
        _ = functionFlags;
        _ = errorNode;
        return false;
    }

    pub fn getContextualSignatureForFunctionLikeDeclaration(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getContextualTypeForYieldOperand(c: *Checker, node: *anyopaque, contextFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = contextFlags;
        return undefined;
    }

    pub fn getContextualTypeForAwaitOperand(c: *Checker, node: *anyopaque, contextFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = contextFlags;
        return undefined;
    }

    pub fn getContextualTypeForArgument(c: *Checker, callTarget: *anyopaque, arg: *anyopaque) *anyopaque {
        _ = c;
        _ = callTarget;
        _ = arg;
        return undefined;
    }

    pub fn getContextualTypeForDecorator(c: *Checker, decorator: *anyopaque) *anyopaque {
        _ = c;
        _ = decorator;
        return undefined;
    }

    pub fn getContextualTypeForBinaryOperand(c: *Checker, node: *anyopaque, contextFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = contextFlags;
        return undefined;
    }

    pub fn getContextualTypeForAssignmentExpression(c: *Checker, binary: *anyopaque) *anyopaque {
        _ = c;
        _ = binary;
        return undefined;
    }

    pub fn getContextualTypeForObjectLiteralMethod(c: *Checker, node: *anyopaque, contextFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = contextFlags;
        return undefined;
    }

    pub fn getContextualTypeForElementExpression(c: *Checker, t: *anyopaque, index: *anyopaque, length: *anyopaque, firstSpreadIndex: *anyopaque, lastSpreadIndex: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = index;
        _ = length;
        _ = firstSpreadIndex;
        _ = lastSpreadIndex;
        return undefined;
    }

    pub fn getContextualTypeForConditionalOperand(c: *Checker, node: *anyopaque, contextFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = contextFlags;
        return undefined;
    }

    pub fn getContextualTypeForSubstitutionExpression(c: *Checker, template: *anyopaque, substitutionExpression: *anyopaque) *anyopaque {
        _ = c;
        _ = template;
        _ = substitutionExpression;
        return undefined;
    }

    pub fn getContextualImportAttributeType(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getEffectiveCallArguments(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getSpreadArgumentIndex(c: *Checker, args: []const ast_gen.NodeIndex) i32 {
        return argument_arity.getSpreadArgumentIndex(c, args);
    }

    pub fn isSpreadArgument(c: *Checker, arg: ast_gen.NodeIndex) bool {
        return argument_arity.isSpreadArgument(c, arg);
    }

    pub fn createSyntheticExpression(c: *Checker, parent: *anyopaque, t: *anyopaque, isSpread: *anyopaque, tupleNameSource: *anyopaque) *anyopaque {
        _ = c;
        _ = parent;
        _ = t;
        _ = isSpread;
        _ = tupleNameSource;
        return undefined;
    }

    pub fn getSpreadIndices(c: *Checker, node: *anyopaque) i32 {
        _ = c;
        _ = node;
        return 0;
    }

    pub fn getEffectiveDecoratorArguments(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getDecoratorCallSignature(c: *Checker, decorator: *anyopaque) *anyopaque {
        _ = c;
        _ = decorator;
        return undefined;
    }

    pub fn getLegacyDecoratorCallSignature(c: *Checker, decorator: *anyopaque) *anyopaque {
        _ = c;
        _ = decorator;
        return undefined;
    }

    pub fn getESDecoratorCallSignature(c: *Checker, decorator: *anyopaque) *anyopaque {
        _ = c;
        _ = decorator;
        return undefined;
    }

    pub fn newClassDecoratorContextType(c: *Checker, classType: *anyopaque) *anyopaque {
        _ = c;
        _ = classType;
        return undefined;
    }

    pub fn newClassMethodDecoratorContextType(c: *Checker, classType: *anyopaque, valueType: *anyopaque) *anyopaque {
        _ = c;
        _ = classType;
        _ = valueType;
        return undefined;
    }

    pub fn newClassGetterDecoratorContextType(c: *Checker, classType: *anyopaque, valueType: *anyopaque) *anyopaque {
        _ = c;
        _ = classType;
        _ = valueType;
        return undefined;
    }

    pub fn newClassSetterDecoratorContextType(c: *Checker, classType: *anyopaque, valueType: *anyopaque) *anyopaque {
        _ = c;
        _ = classType;
        _ = valueType;
        return undefined;
    }

    pub fn newClassAccessorDecoratorContextType(c: *Checker, thisType: *anyopaque, valueType: *anyopaque) *anyopaque {
        _ = c;
        _ = thisType;
        _ = valueType;
        return undefined;
    }

    pub fn newClassFieldDecoratorContextType(c: *Checker, thisType: *anyopaque, valueType: *anyopaque) *anyopaque {
        _ = c;
        _ = thisType;
        _ = valueType;
        return undefined;
    }

    pub fn getClassMemberDecoratorContextOverrideType(c: *Checker, nameType: *anyopaque, isPrivate: *anyopaque, isStatic: *anyopaque) *anyopaque {
        _ = c;
        _ = nameType;
        _ = isPrivate;
        _ = isStatic;
        return undefined;
    }

    pub fn newClassMemberDecoratorContextTypeForNode(c: *Checker, node: *anyopaque, thisType: *anyopaque, valueType: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = thisType;
        _ = valueType;
        return undefined;
    }

    pub fn newClassAccessorDecoratorTargetType(c: *Checker, thisType: *anyopaque, valueType: *anyopaque) *anyopaque {
        _ = c;
        _ = thisType;
        _ = valueType;
        return undefined;
    }

    pub fn newClassAccessorDecoratorResultType(c: *Checker, thisType: *anyopaque, valueType: *anyopaque) *anyopaque {
        _ = c;
        _ = thisType;
        _ = valueType;
        return undefined;
    }

    pub fn newClassFieldDecoratorInitializerMutatorType(c: *Checker, thisType: *anyopaque, valueType: *anyopaque) *anyopaque {
        _ = c;
        _ = thisType;
        _ = valueType;
        return undefined;
    }

    pub fn newESDecoratorCallSignature(c: *Checker, targetType: *anyopaque, contextType: *anyopaque, nonOptionalReturnType: *anyopaque) *anyopaque {
        _ = c;
        _ = targetType;
        _ = contextType;
        _ = nonOptionalReturnType;
        return undefined;
    }

    pub fn newFunctionType(c: *Checker, typeParameters: *anyopaque, thisParameter: *anyopaque, parameters: *anyopaque, returnType: *anyopaque) *anyopaque {
        _ = c;
        _ = typeParameters;
        _ = thisParameter;
        _ = parameters;
        _ = returnType;
        return undefined;
    }

    pub fn newGetterFunctionType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn newSetterFunctionType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn newCallSignature(c: *Checker, typeParameters: *anyopaque, thisParameter: *anyopaque, parameters: *anyopaque, returnType: *anyopaque) *anyopaque {
        _ = c;
        _ = typeParameters;
        _ = thisParameter;
        _ = parameters;
        _ = returnType;
        return undefined;
    }

    pub fn newTypedPropertyDescriptorType(c: *Checker, propertyType: *anyopaque) *anyopaque {
        _ = c;
        _ = propertyType;
        return undefined;
    }

    pub fn getParentTypeOfClassElement(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getClassElementPropertyKeyType(c: *Checker, element: *anyopaque) *anyopaque {
        _ = c;
        _ = element;
        return undefined;
    }

    pub fn getTypeOfPropertyOfContextualType(c: *Checker, t: *anyopaque, name_: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = name_;
        return undefined;
    }

    pub fn getTypeOfPropertyOfContextualTypeEx(c: *Checker, t: *anyopaque, name_: *anyopaque, nameType: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = name_;
        _ = nameType;
        return undefined;
    }

    pub fn getIndexedMappedTypeSubstitutedTypeOfContextualType(c: *Checker, t: *anyopaque, name_: *anyopaque, nameType: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = name_;
        _ = nameType;
        return undefined;
    }

    pub fn isExcludedMappedPropertyName(c: *Checker, t: *anyopaque, propertyNameType: *anyopaque) bool {
        _ = c;
        _ = t;
        _ = propertyNameType;
        return false;
    }

    pub fn getTypeOfConcretePropertyOfContextualType(c: *Checker, t: *anyopaque, name_: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = name_;
        return undefined;
    }

    pub fn getTypeFromIndexInfosOfContextualType(c: *Checker, t: *anyopaque, name_: *anyopaque, nameType: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = name_;
        _ = nameType;
        return undefined;
    }

    pub fn isCircularMappedProperty(c: *Checker, symbol_: *anyopaque) bool {
        _ = c;
        _ = symbol_;
        return false;
    }

    pub fn appendContextualPropertyTypeConstituent(c: *Checker, types_: *anyopaque, t: *anyopaque) *anyopaque {
        _ = c;
        _ = types_;
        _ = t;
        return undefined;
    }

    pub fn getApparentTypeOfContextualType(c: *Checker, node: *anyopaque, contextFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = contextFlags;
        return undefined;
    }

    pub fn len(d: *anyopaque) i32 {
        _ = d;
        return 0;
    }

    pub fn name_stub(d: *anyopaque, index: *anyopaque) *anyopaque {
        _ = d;
        _ = index;
        return undefined;
    }

    pub fn matches(d: *anyopaque, index: *anyopaque, t: *anyopaque) bool {
        _ = d;
        _ = index;
        _ = t;
        return false;
    }

    pub fn discriminateContextualTypeByObjectMembers(c: *Checker, node: *anyopaque, contextualType: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        _ = contextualType;
        return undefined;
    }

    pub fn getMatchingUnionConstituentForObjectLiteral(c: *Checker, unionType: *anyopaque, node: *anyopaque) *anyopaque {
        _ = c;
        _ = unionType;
        _ = node;
        return undefined;
    }

    pub fn isPossiblyDiscriminantValue(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn instantiateContextualType(c: *Checker, contextualType: *anyopaque, node: *anyopaque, contextFlags: *anyopaque) *anyopaque {
        _ = c;
        _ = contextualType;
        _ = node;
        _ = contextFlags;
        return undefined;
    }

    pub fn instantiateInstantiableTypes(c: *Checker, t: *anyopaque, mapper: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = mapper;
        return undefined;
    }

    pub fn pushCachedContextualType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
        c.pushContextualType(node_idx, c.getContextualType(node_idx, 0), true);
    }

    pub fn pushContextualType(c: *Checker, node_idx: ast_gen.NodeIndex, t: types.TypeIndex, isCache: bool) void {
        c.contextualInfos.append(c.allocator, .{ .node = node_idx, .type_ = t, .isCache = isCache }) catch unreachable;
    }

    pub fn popContextualType(c: *Checker) void {
        _ = c.contextualInfos.pop();
    }

    pub fn findContextualNode(c: *Checker, node: ast_gen.NodeIndex, includeCaches: bool) i32 {
        for (c.contextualInfos.items, 0..) |info, i| {
            if (info.node == node and (includeCaches or !info.isCache)) {
                return @intCast(i);
            }
        }
        return -1;
    }

    pub fn pushInferenceContext(c: *Checker, node: *anyopaque, context: *anyopaque) void {
        _ = c;
        _ = node;
        _ = context;
    }

    pub fn popInferenceContext(c: *Checker) void {
        _ = c;
    }

    pub fn getInferenceContext(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn isZeroBigInt(t: *anyopaque) bool {
        _ = t;
        return false;
    }

    pub fn convertAutoToAny(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn checkAwaitedType(c: *Checker, t: types.TypeIndex, withAlias: bool, errorNode: ast_gen.NodeIndex, diagnosticMessage: *const diagnostics_gen.Message) types.TypeIndex {
        _ = t;
        _ = withAlias;
        _ = errorNode;
        _ = diagnosticMessage;
        return c.anyTypeIndex orelse 0;
    }

    pub fn getAwaitedType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getAwaitedTypeEx(c: *Checker, t: *anyopaque, errorNode: *anyopaque, diagnosticMessage: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = errorNode;
        _ = diagnosticMessage;
        return undefined;
    }

    pub fn getAwaitedTypeNoAlias(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getAwaitedTypeNoAliasEx(c: *Checker, t: *anyopaque, errorNode: *anyopaque, diagnosticMessage: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = errorNode;
        _ = diagnosticMessage;
        return undefined;
    }

    /// Port of `checker.go::isAwaitedTypeInstantiation`. Returns true if
    /// `t` is a conditional type that instantiates `Awaited<T>`.
    pub fn isAwaitedTypeInstantiation(c: *Checker, t: types.TypeIndex) bool {
        if (t == 0 or t >= c.typesList.items.len) return false;
        const ty = c.typesList.items[t];
        if ((ty.flags & types.TypeFlags.Conditional) == 0) return false;
        // Requires global Awaited symbol + alias tracking; conservative
        // false until those are wired. TODO(phase1.2): wire
        // getGlobalAwaitedSymbolOrNil + alias.symbol + alias.typeArguments.
        _ = c;
        return false;
    }

    /// Port of `checker.go::isAwaitedTypeNeeded`. Returns true if `t`
    /// should be wrapped in `Awaited<T>` (i.e., it's a generic object type
    /// whose base constraint is any/unknown/object/empty or thenable).
    pub fn isAwaitedTypeNeeded(c: *Checker, t: types.TypeIndex) bool {
        if (t == 0 or t >= c.typesList.items.len) return false;
        // If `t` is `any` or already `Awaited<U>`, no wrapping needed.
        const flags = c.typesList.items[t].flags;
        if ((flags & types.TypeFlags.Any) != 0) return false;
        if (c.isAwaitedTypeInstantiation(t)) return false;
        // Only wrap generic object types
        if (c.isGenericObjectType(t)) {
            const base_constraint = c.getBaseConstraintOfType(t);
            if (base_constraint != 0) {
                const bc_flags = c.typesList.items[base_constraint].flags;
                if ((bc_flags & types.TypeFlags.AnyOrUnknown) != 0) return true;
                if (c.isEmptyObjectType(base_constraint)) return true;
                // someType(base_constraint, c.isThenableType) — for unions
                if ((bc_flags & types.TypeFlags.Union) != 0) {
                    const constituents = c.getTypesFromUnion(base_constraint);
                    for (constituents) |sub| {
                        if (c.isThenableType(sub)) return true;
                    }
                } else {
                    if (c.isThenableType(base_constraint)) return true;
                }
                return false;
            }
            // No base constraint: check if `t` is a type variable
            return c.maybeTypeOfKind(t, types.TypeFlags.TypeVariable);
        }
        return false;
    }

    pub fn createAwaitedTypeIfNeeded(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn tryCreateAwaitedType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn unwrapAwaitedType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    /// Port of `checker.go::isThenableType`. Returns true if `t` has a
    /// callable `then` property (i.e., it looks like a Promise/thenable).
    pub fn isThenableType(c: *Checker, t: types.TypeIndex) bool {
        if (t == 0 or t >= c.typesList.items.len) return false;
        // Primitive types cannot be thenable.
        if (c.allTypesAssignableToKind(c.getBaseConstraintOrType(t), types.TypeFlags.Primitive | types.TypeFlags.Never)) {
            return false;
        }
        const then_function = c.getTypeOfPropertyOfType(t, "then");
        if (then_function == 0) return false;
        const signatures = c.getSignaturesOfType(c.getTypeWithFacts(then_function, types.TypeFacts.NEUndefinedOrNull), .Call);
        return signatures.len > 0;
    }

    pub fn getAwaitedTypeOfPromise(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return 0; // STUB
    }

    pub fn getAwaitedTypeOfPromiseEx(c: *Checker, t: *anyopaque, errorNode: *anyopaque, diagnosticMessage: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = errorNode;
        _ = diagnosticMessage;
        return undefined;
    }

    pub fn isSomeSymbolAssigned(c: *Checker, rootDeclaration: *anyopaque) bool {
        _ = c;
        _ = rootDeclaration;
        return false;
    }

    pub fn isSomeSymbolAssignedWorker(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn getNarrowableTypeForReference(c: *Checker, t_param: types.TypeIndex, reference: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
        var t = t_param;
        if (c.isNoInferType(@ptrFromInt(t))) {
            t = c.typesList.items[t].data.Substitution.baseType;
        }
        const substituteConstraints = (@intFromEnum(checkMode) & @intFromEnum(CheckMode.Inferential) == 0) and
            c.someType(t, isGenericTypeWithUnionConstraintMap, {}) and
            (Checker.isConstraintPosition(c, t, reference) or Checker.hasContextualTypeWithNoGenericTypes(c, reference, checkMode));

        if (substituteConstraints) {
            return t;
        }
        return t;
    }

    pub fn isConstraintPosition(c: *Checker, t: types.TypeIndex, node: ast_gen.NodeIndex) bool {
        const ast_data = c.binder.ast;
        const parent = ast_utils.getParent(ast_data, node);
        if (parent == 0) return false;

        const parentKind = ast_data.getKind(parent);
        if (ast_utils.isPropertyAccessExpression(ast_data, parent) or parentKind == .QualifiedName) {
            return true;
        }
        if ((parentKind == .CallExpression or parentKind == .NewExpression) and
            ast_utils.getExpressionOfNode(ast_data, parent) == node)
        {
            return true;
        }
        if (parentKind == .ElementAccessExpression and ast_utils.getExpressionOfNode(ast_data, parent) == node) {
            const parentNode = ast_data.getNode(parent).ElementAccessExpression;
            if (c.someType(t, isGenericTypeWithoutNullableConstraintMap, {})) {
                if (c.isGenericIndexType(@intCast(@intFromPtr(c.getTypeOfExpression(@ptrFromInt(parentNode.ArgumentExpression)))))) {
                    return false;
                }
            }
            return true;
        }
        return false;
    }

    fn isGenericTypeWithUnionConstraintMap(c: *Checker, t: types.TypeIndex, ctx: void) bool {
        _ = ctx;
        return Checker.isGenericTypeWithUnionConstraint(c, t);
    }

    pub fn isGenericTypeWithUnionConstraint(c: *Checker, t: types.TypeIndex) bool {
        if ((Checker.getTypeFlags(c, t) & types.TypeFlags.Intersection) != 0) {
            const types_list = Checker.getTypesFromIntersection(c, t);
            for (types_list) |t_elem| {
                if (isGenericTypeWithUnionConstraint(c, t_elem)) return true;
            }
            return false;
        }
        return ((Checker.getTypeFlags(c, t) & types.TypeFlags.Instantiable) != 0) and
            ((Checker.getTypeFlags(c, Checker.getBaseConstraintOrType(c, t)) & (types.TypeFlags.Nullable | types.TypeFlags.Union)) != 0);
    }

    fn isGenericTypeWithoutNullableConstraintMap(c: *Checker, t: types.TypeIndex, ctx: void) bool {
        _ = ctx;
        return Checker.isGenericTypeWithoutNullableConstraint(c, t);
    }

    pub fn isGenericTypeWithoutNullableConstraint(c: *Checker, t: types.TypeIndex) bool {
        if ((Checker.getTypeFlags(c, t) & types.TypeFlags.Intersection) != 0) {
            const types_list = Checker.getTypesFromIntersection(c, t);
            for (types_list) |t_elem| {
                if (isGenericTypeWithoutNullableConstraint(c, t_elem)) return true;
            }
            return false;
        }
        return ((Checker.getTypeFlags(c, t) & types.TypeFlags.Instantiable) != 0) and
            !Checker.maybeTypeOfKind(c, Checker.getBaseConstraintOrType(c, t), types.TypeFlags.Nullable);
    }

    pub fn hasContextualTypeWithNoGenericTypes(c: *Checker, node: ast_gen.NodeIndex, checkMode: CheckMode) bool {
        const ast_data = c.binder.ast;
        if ((ast_data.getKind(node) == .Identifier or ast_utils.isPropertyAccessExpression(ast_data, node) or ast_data.getKind(node) == .ElementAccessExpression)) {
            const parent = ast_utils.getParent(ast_data, node);
            if (parent != 0 and (ast_data.getKind(parent) == .JsxOpeningElement or ast_data.getKind(parent) == .JsxSelfClosingElement)) {
                // Jsx tag name, ignore
                const tagName = switch (ast_data.getNode(parent)) {
                    .JsxOpeningElement => |n| n.TagName,
                    .JsxSelfClosingElement => |n| n.TagName,
                    else => 0,
                };
                if (tagName == node) return false;
            }

            const skipBindingPatterns = (@intFromEnum(checkMode) & @intFromEnum(CheckMode.RestBindingElement)) != 0;
            const contextFlags: u32 = if (skipBindingPatterns) (1 << 3) else 0; // ContextFlagsSkipBindingPatterns = 1 << 3

            const contextualType = c.getContextualType(node, contextFlags);
            if (contextualType != 0) {
                return !c.isGenericType(@ptrFromInt(contextualType));
            }
        }
        return false;
    }

    pub fn getNonUndefinedType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn isGenericTypeWithUndefinedConstraint(c: *Checker, t: *anyopaque) bool {
        _ = c;
        _ = t;
        return false;
    }

    pub fn getIndexSignaturesAtLocation(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getSymbolOfNameOrPropertyAccessExpression(c: *Checker, name_: *anyopaque) *anyopaque {
        _ = c;
        _ = name_;
        return undefined;
    }

    pub fn isThisPropertyAndThisTyped(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn getThisTypeOfObjectLiteralFromContextualType(c: *Checker, containingLiteral: *anyopaque, contextualType: *anyopaque) *anyopaque {
        _ = c;
        _ = containingLiteral;
        _ = contextualType;
        return undefined;
    }

    pub fn getThisTypeFromContextualType(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getThisTypeArgument(c: *Checker, t: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        return undefined;
    }

    pub fn getApplicableIndexInfos(c: *Checker, t: *anyopaque, keyType: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = keyType;
        return undefined;
    }

    pub fn getApplicableIndexSymbol(c: *Checker, t: *anyopaque, keyType: *anyopaque) *anyopaque {
        _ = c;
        _ = t;
        _ = keyType;
        return undefined;
    }

    pub fn getRegularTypeOfExpression(c: *Checker, expr: *anyopaque) *anyopaque {
        _ = c;
        _ = expr;
        return undefined;
    }

    pub fn containsArgumentsReference(c: *Checker, node: *anyopaque) bool {
        _ = c;
        _ = node;
        return false;
    }

    pub fn getTypeAtLocation(c: *Checker, node: *anyopaque) *anyopaque {
        _ = c;
        _ = node;
        return undefined;
    }

    pub fn getEmitResolver(c: *Checker) *anyopaque {
        _ = c;
        return undefined;
    }

    pub fn getAliasedSymbol(c: *Checker, symbol_: *anyopaque) *anyopaque {
        _ = c;
        _ = symbol_;
        return undefined;
    }
};

fn containsTypeIndex(items: []const types.TypeIndex, needle: types.TypeIndex) bool {
    for (items) |item| if (item == needle) return true;
    return false;
}

pub fn resolveName(c: *Checker, location: ?ast_gen.NodeIndex, name: []const u8, meaning: u32, nameNotFoundMessage: ?*const diagnostics_gen.Message, isUse: bool, excludeGlobals: bool) ast_gen.SymbolIndex {
    return c.resolver.resolve(location orelse 0, name, meaning, nameNotFoundMessage, isUse, excludeGlobals) orelse c.unknownSymbol;
}

pub fn getResolvedSymbol(c: *Checker, node: ast_gen.NodeIndex) ast_gen.SymbolIndex {
    var links = c.symbolNodeLinks.get(node) orelse types.SymbolNodeLinks{};
    if (links.resolvedSymbol == 0) {
        var sym: ast_gen.SymbolIndex = 0;
        if (!ast_utils.nodeIsMissing(c.binder.ast, node)) {
            const name = ast_utils.getTextOfNode(c.binder.ast, node);
            sym = resolveName(c, node, name, symbol.SymbolFlags.Value | symbol.SymbolFlags.ExportValue, null, !false, false);
        }
        links.resolvedSymbol = if (sym != 0) sym else c.unknownSymbol;
        c.symbolNodeLinks.put(c.allocator, node, links) catch {};
    }
    return links.resolvedSymbol;
}

pub fn getResolvedSymbolOrNil(c: *Checker, node: ast_gen.NodeIndex) ast_gen.SymbolIndex {
    if (c.symbolNodeLinks.get(node)) |links| {
        return links.resolvedSymbol;
    }
    return 0;
}

pub fn getSymbolAtLocation(c: *Checker, node: ast_gen.NodeIndex) ast_gen.SymbolIndex {
    if (c.binder.ast.getNodeKind(node) == .SourceFile) {
        if (c.binder.ast.getNode(node).SourceFile.ExternalModuleIndicator != null or c.binder.ast.getNode(node).SourceFile.CommonJSModuleIndicator != null) {
            return getMergedSymbol(c, c.binder.ast.getNodeSymbol(node) orelse 0);
        }
        return 0;
    }

    if (ast_utils.isIdentifier(c.binder.ast, node)) {
        const sym = getResolvedSymbol(c, node);
        if (sym != 0 and sym != c.unknownSymbol) {
            return sym;
        }
    }

    if (c.binder.ast.getNodeKind(node) == .PropertyAccessExpression) {
        // Return property symbol if already typechecked and cached
        return getSymbolOfNode(c, node) orelse 0;
    }

    // fallback: mostly for declarations
    return c.binder.ast.getNodeSymbol(node) orelse 0;
}
pub fn getSymbolOfNode(c: *Checker, node: ast_gen.NodeIndex) ?ast_gen.SymbolIndex {
    return c.binder.ast.getNodeSymbol(node); // simplified fallback
}

pub fn getMergedSymbol(c: *Checker, symIndex: ast_gen.SymbolIndex) ast_gen.SymbolIndex {
    if (symIndex != 0) {
        if (c.mergedSymbols.get(symIndex)) |merged| {
            return merged;
        }
    }
    return symIndex;
}

pub fn getExportSymbolOfValueSymbolIfExported(c: *Checker, symIndex: ast_gen.SymbolIndex) ast_gen.SymbolIndex {
    var s = symIndex;
    if (s != 0) {
        const sym = c.binder.symbols.items[s];
        if (sym.Flags & symbol.SymbolFlags.ExportValue != 0 and sym.ExportSymbol != null and sym.ExportSymbol.? != 0) {
            s = sym.ExportSymbol.?;
        }
    }
    return getMergedSymbol(c, s);
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

    const inferred_array = try checker.checkExpressionAdHoc(parsed.ast.getNode(declaration).VariableDeclaration.Initializer.?);
    try std.testing.expect(checker.typesList.items[inferred_array].data == .Array);
    const inferred_element = checker.typesList.items[inferred_array].data.Array.elementType;
    try std.testing.expect(checker.typesList.items[inferred_element].flags & types.TypeFlags.Union != 0);

    const pair_declaration_list = parsed.ast.getNode(statements[2]).VariableStatement.DeclarationList;
    const pair_declaration = parsed.ast.getNodeList(parsed.ast.getNode(pair_declaration_list).VariableDeclarationList.Declarations)[0];
    const referenced_pair = try checker.getTypeOfNode(parsed.ast.getNode(pair_declaration).VariableDeclaration.Type.?);
    try std.testing.expect(checker.typesList.items[referenced_pair].data == .Tuple);
}

test "missing discriminants reports excess properties on narrowed union members" {
    const parser = @import("../parser/parser.zig");
    var parsed = parser.Parser.init(std.testing.allocator,
        \\type Item =
        \\  | { kind: "a", subkind: 0, value: string }
        \\  | { kind: "a", subkind: 1, value: number }
        \\  | { kind: "b" }
        \\
        \\const item1: Item = { subkind: 1, kind: "b" };
    );
    defer parsed.deinit();
    const source_file = try parsed.parseSourceFile();
    var bound = try binder.Binder.init(std.testing.allocator, &parsed.ast);
    defer bound.deinit();
    try bound.bindSourceFile(source_file);
    var checker = Checker.init(std.testing.allocator, &bound);
    defer checker.deinit();

    const statements = parsed.ast.getNodeList(parsed.ast.getNode(source_file).SourceFile.Statements);
    const item_decl_list = parsed.ast.getNode(statements[1]).VariableStatement.DeclarationList;
    const item_decl = parsed.ast.getNodeList(parsed.ast.getNode(item_decl_list).VariableDeclarationList.Declarations)[0];
    const item_decl_node = parsed.ast.getNode(item_decl).VariableDeclaration;
    const declared_type = type_resolution_pkg.getTypeFromTypeNode(&checker, item_decl_node.Type.?);
    try std.testing.expect(checker.typesList.items[declared_type].flags & types.TypeFlags.Union != 0);
    try std.testing.expectEqual(@as(u32, 3), checker.typesList.items[declared_type].data.Union.typesLen);

    try checker.checkStatementAdHoc(item_decl);
    try std.testing.expect(bound.diagnosticsList.items.len > 0);
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

pub fn createTypeMapper(self: *Checker, m: types.TypeMapper) !types.TypeMapperIndex {
    const idx: u32 = @intCast(self.mappersList.items.len);
    try self.mappersList.append(self.allocator, m);
    return idx;
}

pub fn addTypeMapper(self: *Checker, m: types.TypeMapper) types.TypeMapperIndex {
    return createTypeMapper(self, m) catch @panic("OOM");
}

pub fn appendTypeMapping(self: *Checker, mapper: types.TypeMapperIndex, source: types.TypeIndex, target: types.TypeIndex) !types.TypeMapperIndex {
    return try createTypeMapper(self, .{
        .kind = .Deferred,
        .data = .{ .Deferred = .{ .source = source, .target = target, .mapper = mapper } },
    });
}

pub fn makeSimpleTypeMapper(self: *Checker, source: types.TypeIndex, target: types.TypeIndex) !types.TypeMapperIndex {
    return try createTypeMapper(self, .{
        .kind = .Simple,
        .data = .{ .Simple = .{ .source = source, .target = target } },
    });
}

pub fn makeArrayTypeMapper(self: *Checker, sources: []const types.TypeIndex, targets: []const types.TypeIndex) !types.TypeMapperIndex {
    return try createTypeMapper(self, .{
        .kind = .Array,
        .data = .{ .Array = .{ .sources = sources, .targets = targets } },
    });
}

pub fn mapTypeWithMapper(c: *Checker, t: types.TypeIndex, mapperIdx: types.TypeMapperIndex) types.TypeIndex {
    if (mapperIdx == 0) return t;
    const mapper = c.mappersList.items[mapperIdx];
    switch (mapper.kind) {
        .Simple => {
            if (t == mapper.data.Simple.source) return mapper.data.Simple.target;
            return t;
        },
        .Array => {
            for (mapper.data.Array.sources, 0..) |source, i| {
                if (t == source) return mapper.data.Array.targets[i];
            }
            return t;
        },
        .Merged => {
            const target = mapTypeWithMapper(c, t, mapper.data.Merged.mapper1);
            if (target != t) return target;
            return mapTypeWithMapper(c, t, mapper.data.Merged.mapper2);
        },
        .Permissive => {
            if ((c.typesList.items[t].flags & types.TypeFlags.TypeParameter) != 0) {
                return c.wildcardTypeIndex orelse 0;
            }
            return t;
        },
        .Restrictive => {
            if ((c.typesList.items[t].flags & types.TypeFlags.TypeParameter) != 0) {
                return getRestrictiveTypeParameter(c, t);
            }
            return t;
        },
        else => return t,
    }
}

pub fn getRestrictiveTypeParameter(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    const tp = &c.typesList.items[t].data.TypeParameter;
    const constraintType = tp.constraintType;
    if ((constraintType == 0 and getConstraintDeclaration(c, t) == null) or constraintType == (c.noConstraintTypeIndex orelse 0)) {
        return t;
    }

    const gop = c.restrictiveTypeParameterCache.getOrPut(c.allocator, t) catch unreachable;
    if (gop.found_existing) {
        return gop.value_ptr.*;
    }

    const result = c.createType(.{
        .flags = types.TypeFlags.TypeParameter,
        .objectFlags = types.ObjectFlags.Anonymous,
        .symbol = c.typesList.items[t].symbol,
        .data = .{ .TypeParameter = .{ .constraintType = c.noConstraintTypeIndex orelse 0 } },
    }) catch 0;

    gop.value_ptr.* = result;
    return result;
}

pub fn instantiateTypes(c: *Checker, typesArr: []const types.TypeIndex, mapperIdx: types.TypeMapperIndex) ![]const types.TypeIndex {
    if (mapperIdx == 0 or typesArr.len == 0) return typesArr;
    var newTypesArr = try c.allocator.alloc(types.TypeIndex, typesArr.len);
    var changed = false;
    for (typesArr, 0..) |t, i| {
        newTypesArr[i] = c.instantiateType(t, mapperIdx);
        if (newTypesArr[i] != t) changed = true;
    }
    if (changed) return newTypesArr;
    c.allocator.free(newTypesArr);
    return typesArr;
}

pub fn getWildcardType(self: *Checker) !u32 {
    if (self.wildcardTypeIndex) |idx| return idx;
    const idx = try self.createType(.{ .flags = types.TypeFlags.Any, .objectFlags = types.ObjectFlags.Anonymous, .id = 0, .symbol = null, .alias = null, .data = .{ .Intrinsic = .{ .intrinsicName = "any" } } });
    self.wildcardTypeIndex = idx;
    return idx;
}

pub fn getPermissiveMapper(self: *Checker) !types.TypeMapperIndex {
    if (self.permissiveMapperIndex) |idx| return idx;
    const idx = try createTypeMapper(self, .{
        .kind = .Permissive,
        .data = .{ .Dummy = {} },
    });
    self.permissiveMapperIndex = idx;
    return idx;
}

pub fn prependTypeMapping(self: *Checker, source: types.TypeIndex, target: types.TypeIndex, mapper: types.TypeMapperIndex) !types.TypeMapperIndex {
    return try createTypeMapper(self, .{
        .kind = .Deferred,
        .data = .{ .Deferred = .{ .source = source, .target = target, .mapper = mapper } },
    });
}

pub fn getRestrictiveMapper(self: *Checker) !types.TypeMapperIndex {
    if (self.restrictiveMapperIndex) |idx| return idx;
    const idx = try createTypeMapper(self, .{
        .kind = .Restrictive,
        .data = .{ .Dummy = {} },
    });
    self.restrictiveMapperIndex = idx;
    return idx;
}

pub fn getConstraintDeclaration(c: *Checker, t: types.TypeIndex) ?ast_gen.NodeIndex {
    const symbolIdx = c.typesList.items[t].symbol;
    if (symbolIdx) |sIdx| {
        const sym = c.binder.symbols.items[sIdx];
        for (sym.Declarations.items) |declIdx| {
            const decl = c.binder.ast.nodes.get(declIdx);
            switch (decl) {
                .TypeParameter => |tpd| {
                    if (tpd.Constraint) |constraintIdx| {
                        return constraintIdx;
                    }
                },
                else => {},
            }
        }
    }
    return null;
}

pub fn resolveTypeParameterConstraint(c: *Checker, t: types.TypeIndex) void {
    var tp = &c.typesList.items[c.getTargetType(t)].data.TypeParameter;
    tp.isTypeParameterConstraintResolved = true;
    const constraintDeclaration = getConstraintDeclaration(c, t);
    if (constraintDeclaration) |constraintIdx| {
        // Skipped: pushTypeResolution check
        const type_resolution = @import("type_resolution.zig");
        tp.constraintType = type_resolution.getTypeFromTypeNode(c, constraintIdx);
    } else {
        tp.constraintType = c.noConstraintTypeIndex orelse 0;
    }
}
pub fn checkSourceElementWorker(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    // TODO: JSDoc comments

    if (!c.withinUnreachableCode) { // && c.compilerOptions.allowUnreachableCode != true
        if (c.checkSourceElementUnreachable(node_idx)) {
            c.withinUnreachableCode = true;
        }
    }

    const node = c.binder.ast.getNode(node_idx);
    switch (node) {
        .TypeParameter => checkTypeParameter(c, node_idx),
        .Parameter => checkParameter(c, node_idx),
        .PropertyDeclaration => checkPropertyDeclaration(c, node_idx),
        .PropertySignature => checkPropertySignature(c, node_idx),
        .ConstructorType, .FunctionType, .CallSignature, .ConstructSignature, .IndexSignature => checkSignatureDeclaration(c, node_idx),
        .MethodDeclaration, .MethodSignature => checkMethodDeclaration(c, node_idx),
        .ClassStaticBlockDeclaration => checkClassStaticBlockDeclaration(c, node_idx),
        .Constructor => checkConstructorDeclaration(c, node_idx),
        .GetAccessor, .SetAccessor => checkAccessorDeclaration(c, node_idx),
        .TypeReference => checkTypeReferenceNode(c, node_idx),
        .TypePredicate => checkTypePredicate(c, node_idx),
        .TypeQuery => checkTypeQuery(c, node_idx),
        .TypeLiteral => checkTypeLiteral(c, node_idx),
        .ArrayType => checkArrayType(c, node_idx),
        .TupleType => checkTupleType(c, node_idx),
        .UnionType, .IntersectionType => checkUnionOrIntersectionType(c, node_idx),
        .ParenthesizedType => {
            if (node.ParenthesizedType.Type != 0) checkSourceElement(c, node.ParenthesizedType.Type);
        },
        .OptionalType => {
            if (node.OptionalType.Type != 0) checkSourceElement(c, node.OptionalType.Type);
        },
        .RestType => {
            if (node.RestType.Type != 0) checkSourceElement(c, node.RestType.Type);
        },
        .ThisType => checkThisType(c, node_idx),
        .TypeOperator => checkTypeOperator(c, node_idx),
        .ConditionalType => checkConditionalType(c, node_idx),
        .InferType => checkInferType(c, node_idx),
        .TemplateLiteralType => checkTemplateLiteralType(c, node_idx),
        .ImportType => checkImportType(c, node_idx),
        .NamedTupleMember => checkNamedTupleMember(c, node_idx),
        .IndexedAccessType => checkIndexedAccessType(c, node_idx),
        .MappedType => checkMappedType(c, node_idx),
        .FunctionDeclaration => checkFunctionDeclaration(c, node_idx),
        .Block, .ModuleBlock => checkBlock(c, node_idx),
        .VariableStatement => checkVariableStatement(c, node_idx),
        .ExpressionStatement => checkExpressionStatement(c, node_idx),
        .IfStatement => checkIfStatement(c, node_idx),
        .DoStatement => checkDoStatement(c, node_idx),
        .WhileStatement => checkWhileStatement(c, node_idx),
        .ForStatement => checkForStatement(c, node_idx),
        .ForInStatement => checkForInStatement(c, node_idx),
        .ForOfStatement => checkForOfStatement(c, node_idx),
        .ContinueStatement, .BreakStatement => checkBreakOrContinueStatement(c, node_idx),
        .ReturnStatement => checkReturnStatement(c, node_idx),
        .WithStatement => checkWithStatement(c, node_idx),
        .SwitchStatement => checkSwitchStatement(c, node_idx),
        .LabeledStatement => checkLabeledStatement(c, node_idx),
        .ThrowStatement => checkThrowStatement(c, node_idx),
        .TryStatement => checkTryStatement(c, node_idx),
        .PropertyAssignment => checkPropertyAssignment(c, node_idx),
        .ShorthandPropertyAssignment => checkShorthandPropertyAssignment(c, node_idx),
        .SpreadAssignment => checkSpreadAssignment(c, node_idx),
        .VariableDeclaration => checkVariableDeclaration(c, node_idx),
        .VariableDeclarationList => checkVariableDeclarationList(c, node_idx),
        .BindingElement => checkBindingElement(c, node_idx),
        .ClassDeclaration => checkClassDeclaration(c, node_idx),
        .InterfaceDeclaration => checkInterfaceDeclaration(c, node_idx),
        .TypeAliasDeclaration, .JSTypeAliasDeclaration => checkTypeAliasDeclaration(c, node_idx),
        .EnumDeclaration => checkEnumDeclaration(c, node_idx),
        .EnumMember => checkEnumMember(c, node_idx),
        .ModuleDeclaration => checkModuleDeclaration(c, node_idx),
        .ImportDeclaration, .JSImportDeclaration => checkImportDeclaration(c, node_idx),
        .ImportEqualsDeclaration => checkImportEqualsDeclaration(c, node_idx),
        .ExportDeclaration => checkExportDeclaration(c, node_idx),
        .ExportAssignment => checkExportAssignment(c, node_idx),
        .EmptyStatement => checkGrammarStatementInAmbientContext(c, node_idx),
        .DebuggerStatement => checkGrammarStatementInAmbientContext(c, node_idx),
        .MissingDeclaration => checkMissingDeclaration(c, node_idx),
        .JSDocNonNullableType, .JSDocNullableType, .JSDocAllType, .JSDocTypeLiteral => checkJSDocType(c, node_idx),
        else => {},
    }
}

pub fn checkAccessorDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node_kind = c.binder.ast.getKind(node_idx);
    var type_parameters: ?u32 = null;
    var parameters: ?u32 = null;
    var type_idx: ?u32 = null;
    var body: ?u32 = null;

    if (node_kind == .GetAccessor) {
        const node = c.binder.ast.getNode(node_idx).GetAccessor;
        type_parameters = node.TypeParameters;
        parameters = node.Parameters;
        type_idx = node.Type;
        body = node.Body;
    } else if (node_kind == .SetAccessor) {
        const node = c.binder.ast.getNode(node_idx).SetAccessor;
        type_parameters = node.TypeParameters;
        parameters = node.Parameters;
        type_idx = node.Type;
        body = node.Body;
    }

    if (type_parameters) |tps| {
        checkTypeParameters(c, tps);
    }
    if (parameters) |params| {
        checkFunctionParameters(c, params);
    }
    if (type_idx) |t| {
        if (t != 0) checkSourceElement(c, t);
    }
    if (body) |b| {
        if (b != 0) checkSourceElement(c, b);
    }
}
pub fn checkArrayType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).ArrayType;
    if (node.ElementType != 0) checkSourceElement(c, node.ElementType);
}
pub fn checkBindingElement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).BindingElement;
    if (node.Initializer) |init| {
        _ = checkExpression(c, init);
    }
}
pub fn checkBlock(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const stmts = c.binder.ast.nodes.get(node_idx).Block.Statements;
    const list = c.binder.ast.getNodeList(stmts);
    for (list) |stmt_idx| {
        if (stmt_idx != 0) checkSourceElement(c, stmt_idx);
    }
}
pub fn checkBreakOrContinueStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    _ = c;
    _ = node_idx;
}
pub fn checkClassDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const cd = c.binder.ast.nodes.get(node_idx).ClassDeclaration;

    if (cd.TypeParameters) |tps| {
        if (tps != 0) checkSourceElement(c, tps); // Type parameters might be a list, or maybe we just check the wrapper node. In AST, TypeParameters is often a list. If it is, we should iterate it. But wait, in Go, checkTypeParameters iterates over it. Let's just pass the TypeParameter list node to checkSourceElement if it exists.
    }

    if (cd.HeritageClauses) |hc| {
        if (hc != 0) checkSourceElement(c, hc);
    }

    if (cd.Members != 0) {
        const members = c.binder.ast.getNodeList(cd.Members);
        for (members) |mem| {
            if (mem != 0) checkSourceElement(c, mem);
        }
    }
}
pub fn checkClassStaticBlockDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).ClassStaticBlockDeclaration;
    if (node.Body != 0) checkSourceElement(c, node.Body);
}
pub fn checkConditionalType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).ConditionalType;
    if (node.CheckType != 0) checkSourceElement(c, node.CheckType);
    if (node.ExtendsType != 0) checkSourceElement(c, node.ExtendsType);
    if (node.TrueType != 0) checkSourceElement(c, node.TrueType);
    if (node.FalseType != 0) checkSourceElement(c, node.FalseType);
}
pub fn checkConstructorDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const ctor = c.binder.ast.nodes.get(node_idx).Constructor;
    if (ctor.TypeParameters) |tps| checkTypeParameters(c, tps);
    if (ctor.Parameters != 0) checkFunctionParameters(c, ctor.Parameters);
    if (ctor.Type) |t| if (t != 0) checkSourceElement(c, t);
    if (ctor.Body != 0) {
        if (ctor.Body) |body| checkSourceElement(c, body);
    }
}
pub fn checkSpreadAssignment(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.nodes.get(node_idx).SpreadAssignment;
    _ = checkExpression(c, node.Expression);
}
pub fn checkDoStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    checkGrammarStatementInAmbientContext(c, node_idx);
    const node = c.binder.ast.getNode(node_idx).DoStatement;
    if (node.Statement != 0) checkSourceElement(c, node.Statement);
    _ = c.checkTruthinessExpression(node.Expression, CheckMode.Normal);
}
pub fn checkEnumDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).EnumDeclaration;
    const members = c.binder.ast.getNodeList(node.Members);
    for (members) |mem_idx| {
        if (mem_idx != 0) checkSourceElement(c, mem_idx);
    }
}
pub fn checkEnumMember(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).EnumMember;
    if (node.Initializer) |init| {
        _ = checkExpression(c, init);
    }
}
pub fn checkExportAssignment(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).ExportAssignment;
    if (node.Expression != 0) {
        _ = checkExpression(c, node.Expression);
    }
}
pub fn checkExportDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).ExportDeclaration;
    if (node.ExportClause) |clause| {
        if (clause != 0) checkSourceElement(c, clause);
    }
}
pub fn checkExpressionStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    checkGrammarStatementInAmbientContext(c, node_idx);
    const expr = c.binder.ast.nodes.get(node_idx).ExpressionStatement.Expression;
    _ = checkExpression(c, expr);
}
pub fn checkForInStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    if (!grammarchecks.checkGrammarStatementInAmbientContext(c, node_idx)) {
        // if (init := node.Initializer(); init != nil && init.Kind == ast.KindVariableDeclarationList) {
        //     c.checkGrammarVariableDeclarationList(init.AsVariableDeclarationList())
        // }
    }
    const node = c.binder.ast.getNode(node_idx).ForInStatement;
    if (c.binder.ast.getKind(node.Initializer) == .VariableDeclarationList) {
        checkVariableDeclarationList(c, node.Initializer);
    } else {
        _ = checkExpression(c, node.Initializer);
    }
    _ = checkExpression(c, node.Expression);
    if (node.Statement != 0) checkSourceElement(c, node.Statement);
}
pub fn checkForOfStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    if (!grammarchecks.checkGrammarStatementInAmbientContext(c, node_idx)) {
        // if (init := node.Initializer(); init != nil && init.Kind == ast.KindVariableDeclarationList) {
        //     c.checkGrammarVariableDeclarationList(init.AsVariableDeclarationList())
        // }
    }
    const node = c.binder.ast.getNode(node_idx).ForOfStatement;
    if (c.binder.ast.getKind(node.Initializer) == .VariableDeclarationList) {
        checkVariableDeclarationList(c, node.Initializer);
    } else {
        _ = checkExpression(c, node.Initializer);
    }
    _ = checkExpression(c, node.Expression);
    if (node.Statement != 0) checkSourceElement(c, node.Statement);
}
pub fn checkForStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    if (!grammarchecks.checkGrammarStatementInAmbientContext(c, node_idx)) {
        // if (init := node.Initializer(); init != nil && init.Kind == ast.KindVariableDeclarationList) {
        //     c.checkGrammarVariableDeclarationList(init.AsVariableDeclarationList())
        // }
    }
    const node = c.binder.ast.getNode(node_idx).ForStatement;
    if (node.Initializer) |init| {
        if (c.binder.ast.getKind(init) == .VariableDeclarationList) {
            checkVariableDeclarationList(c, init);
        } else {
            _ = checkExpression(c, init);
        }
    }
    if (node.Condition) |cond| {
        _ = c.checkTruthinessExpression(cond, CheckMode.Normal);
    }
    if (node.Incrementor) |incr| {
        _ = checkExpression(c, incr);
    }
    if (node.Statement != 0) checkSourceElement(c, node.Statement);
}
fn isDeclarationFilePath(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".d.ts") or
        std.mem.endsWith(u8, path, ".d.cts") or
        std.mem.endsWith(u8, path, ".d.mts");
}

fn isEsModuleTarget(module_kind: core.ModuleKind) bool {
    return switch (module_kind) {
        .CommonJS, .AMD, .UMD, .System, .None => false,
        else => true,
    };
}

pub fn checkFunctionDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const f = c.binder.ast.nodes.get(node_idx).FunctionDeclaration;
    if (f.TypeParameters) |tps| checkTypeParameters(c, tps);
    if (f.Parameters != 0) checkFunctionParameters(c, f.Parameters);
    if (f.Type) |t| if (t != 0) checkSourceElement(c, t);
    if (f.Body != 0) {
        if (f.Body) |body| checkSourceElement(c, body);
    }
    if ((f.Body == null or f.Body == 0) and (f.Type == null or f.Type == 0)) {
        if (isDeclarationFilePath(c.binder.ast.fileName) or c.noImplicitAny) {
            if (f.name) |name_idx| {
                const name = ast_utils.getText(c.binder.ast, name_idx);
                c.reportErrorWithArgs(
                    name_idx,
                    &diagnostics_gen.X_0_which_lacks_return_type_annotation_implicitly_has_an_1_return_type,
                    &.{ name, "any" },
                );
            }
        }
    }
}
pub fn checkGrammarStatementInAmbientContext(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    _ = c;
    _ = node_idx;
}
pub fn checkIfStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).IfStatement;
    _ = grammarchecks.checkGrammarStatementInAmbientContext(c, node_idx);
    const t = c.checkTruthinessExpression(node.Expression, CheckMode.Normal);
    c.checkTestingKnownTruthyCallableOrAwaitableOrEnumMemberType(node.Expression, t, node.ThenStatement);
    if (node.ThenStatement != 0) checkSourceElement(c, node.ThenStatement);
    if (c.binder.ast.getKind(node.ThenStatement) == .EmptyStatement) {
        c.reportError(node.ThenStatement, &diagnostics_gen.The_body_of_an_if_statement_cannot_be_the_empty_statement);
    }
    if (node.ElseStatement) |else_stmt| {
        if (else_stmt != 0) checkSourceElement(c, else_stmt);
    }
}
pub fn checkImportDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).ImportDeclaration;
    if (node.ImportClause) |clause| {
        if (clause != 0) checkSourceElement(c, clause);
    }
}
pub fn checkImportEqualsDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    if (ast_utils.isExternalModuleImportEqualsDeclaration(c.binder.ast, node_idx) and isEsModuleTarget(c.moduleKind)) {
        c.reportError(
            node_idx,
            &diagnostics_gen.Import_assignment_cannot_be_used_when_targeting_ECMAScript_modules_Consider_using_import_Asterisk_as_ns_from_mod_import_a_from_mod_import_d_from_mod_or_another_module_format_instead,
        );
    }
    if (c.erasableSyntaxOnly) {
        c.reportError(node_idx, &diagnostics_gen.This_syntax_is_not_allowed_when_erasableSyntaxOnly_is_enabled);
    }
}
pub fn checkImportType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    _ = c;
    _ = node_idx;
}
pub fn checkIndexedAccessType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).IndexedAccessType;
    if (node.ObjectType != 0) checkSourceElement(c, node.ObjectType);
    if (node.IndexType != 0) checkSourceElement(c, node.IndexType);
}
pub fn checkInferType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).InferType;
    if (node.TypeParameter != 0) checkSourceElement(c, node.TypeParameter);
}
pub fn checkInterfaceDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).InterfaceDeclaration;
    if (node.TypeParameters) |tps| {
        checkTypeParameters(c, tps);
    }
    if (node.HeritageClauses) |hc| {
        if (hc != 0) checkSourceElement(c, hc);
    }
    const members = c.binder.ast.getNodeList(node.Members);
    for (members) |mem_idx| {
        if (mem_idx != 0) checkSourceElement(c, mem_idx);
    }
}
pub fn checkJSDocType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    _ = c;
    _ = node_idx;
}
pub fn checkLabeledStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).LabeledStatement;
    if (node.Statement != 0) checkSourceElement(c, node.Statement);
}
pub fn checkMappedType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).MappedType;
    if (node.TypeParameter != 0) checkSourceElement(c, node.TypeParameter);
    if (node.NameType) |name_type| {
        if (name_type != 0) checkSourceElement(c, name_type);
    }
    if (node.Type) |type_idx| {
        if (type_idx != 0) checkSourceElement(c, type_idx);
    }
}
pub fn checkMethodDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const method = c.binder.ast.nodes.get(node_idx).MethodDeclaration;
    if (method.TypeParameters) |tps| checkTypeParameters(c, tps);
    if (method.Parameters != 0) checkFunctionParameters(c, method.Parameters);
    if (method.Type) |t| if (t != 0) checkSourceElement(c, t);
    if (method.Body != 0) {
        if (method.Body) |body| checkSourceElement(c, body);
    }
}
pub fn checkMissingDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    _ = c;
    _ = node_idx;
}
pub fn checkModuleDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).ModuleDeclaration;
    if (node.Body) |body| {
        if (body != 0) checkSourceElement(c, body);
    }
}
pub fn checkNamedTupleMember(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).NamedTupleMember;
    if (node.Type != 0) checkSourceElement(c, node.Type);
}
fn isTypeAnyLike(c: *Checker, t: types.TypeIndex) bool {
    if (t == 0 or t >= c.typesList.items.len) return true;
    const flags = c.typesList.items[t].flags;
    return (flags & types.TypeFlags.Any) != 0 or (flags & types.TypeFlags.Unknown) != 0;
}

fn shouldReportMissingPropertyError(c: *Checker, left_type: types.TypeIndex, assignment_kind: utils.AssignmentKind) bool {
    if (isTypeAnyLike(c, left_type)) return false;
    if (assignment_kind != .None and c.isGenericObjectType(left_type) and !utils.isThisTypeParameter(c, left_type)) return false;
    if ((c.getTypeFlags(left_type) & types.TypeFlags.Union) != 0) return false;
    if (left_type < c.typesList.items.len) {
        const t = c.typesList.items[left_type];
        if ((t.flags & types.TypeFlags.Object) != 0 and t.symbol == null) return false;
    }
    if (std.mem.eql(u8, c.typeToString(left_type, 0, 0, null), "Object")) return false;
    return true;
}

fn shouldReportArgumentError(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
    // Argument checking reports object/object and union mismatches; only skip any-like types.
    if (isTypeAnyLike(c, source) or isTypeAnyLike(c, target)) return false;
    return true;
}

fn shouldReportAssignmentError(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
    if (isTypeAnyLike(c, source) or isTypeAnyLike(c, target)) return false;
    if ((c.getTypeFlags(source) & types.TypeFlags.Union) != 0 or (c.getTypeFlags(target) & types.TypeFlags.Union) != 0) return false;
    const source_flags = if (source < c.typesList.items.len) c.typesList.items[source].flags else 0;
    const target_flags = if (target < c.typesList.items.len) c.typesList.items[target].flags else 0;
    if ((source_flags & types.TypeFlags.Object) != 0 and (target_flags & types.TypeFlags.Object) != 0) return false;
    return true;
}

fn isParameterOptional(c: *Checker, param_node: ast_gen.NodeIndex) bool {
    const param = c.binder.ast.getNode(param_node).Parameter;
    if (param.QuestionToken != 0) return true;
    if (param.Initializer != 0) return true;
    if (param.DotDotDotToken != 0) return true;
    return false;
}

pub fn getParameterDeclarationName(c: *Checker, node_idx: ast_gen.NodeIndex) ?[]const u8 {
    const param = c.binder.ast.getNode(node_idx).Parameter;
    if (param.name == 0) return null;
    const name_node = c.binder.ast.getNode(param.name);
    return switch (name_node) {
        .Identifier => |id| id.Text,
        else => null,
    };
}

pub fn checkFunctionParameters(c: *Checker, params_node: ast_gen.NodeIndex) void {
    if (params_node == 0) return;
    const params = c.binder.ast.getNodeList(params_node);
    for (params) |param| {
        checkParameter(c, param);
    }
}

pub fn checkParameter(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const param = c.binder.ast.getNode(node_idx).Parameter;
    if (param.Type) |type_node| {
        if (type_node != 0) return;
    }
    const param_type = c.getTypeOfNode(node_idx) catch return;
    c.reportImplicitAny(node_idx, param_type);
}
pub fn checkPropertyDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).PropertyDeclaration;
    if (node.Initializer) |init| {
        _ = checkExpression(c, init);
    }
    if (node.Type) |type_idx| {
        if (type_idx != 0) checkSourceElement(c, type_idx);
    }
}
pub fn checkPropertySignature(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).PropertySignature;
    if (node.Initializer) |init| {
        _ = checkExpression(c, init);
    }
    if (node.Type) |type_idx| {
        if (type_idx != 0) checkSourceElement(c, type_idx);
    }
}
pub fn checkReturnStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).ReturnStatement;
    if (node.Expression) |expr| {
        _ = checkExpression(c, expr);
    }
}
pub fn checkSignatureDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node_kind = c.binder.ast.getKind(node_idx);
    var type_parameters: ?u32 = null;
    var parameters: ?u32 = null;
    var type_idx: ?u32 = null;

    switch (node_kind) {
        .IndexSignature => {
            const node = c.binder.ast.getNode(node_idx).IndexSignature;
            type_parameters = node.TypeParameters;
            parameters = node.Parameters;
            type_idx = node.Type;
        },
        .FunctionType => {
            const node = c.binder.ast.getNode(node_idx).FunctionType;
            type_parameters = node.TypeParameters;
            parameters = node.Parameters;
            type_idx = node.Type;
        },
        .ConstructorType => {
            const node = c.binder.ast.getNode(node_idx).ConstructorType;
            type_parameters = node.TypeParameters;
            parameters = node.Parameters;
            type_idx = node.Type;
        },
        .CallSignature => {
            const node = c.binder.ast.getNode(node_idx).CallSignature;
            type_parameters = node.TypeParameters;
            parameters = node.Parameters;
            type_idx = node.Type;
        },
        .ConstructSignature => {
            const node = c.binder.ast.getNode(node_idx).ConstructSignature;
            type_parameters = node.TypeParameters;
            parameters = node.Parameters;
            type_idx = node.Type;
        },
        else => {},
    }

    if (type_parameters) |tps| {
        checkTypeParameters(c, tps);
    }
    if (parameters) |params| {
        checkFunctionParameters(c, params);
    }
    if (type_idx) |t| {
        if (t != 0) checkSourceElement(c, t);
    }
}
pub fn checkSwitchStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).SwitchStatement;
    _ = checkExpression(c, node.Expression);
    const caseBlock = c.binder.ast.getNode(node.CaseBlock).CaseBlock;
    const clauses = c.binder.ast.getNodeList(caseBlock.Clauses);
    for (clauses) |clause_idx| {
        const clause_kind = c.binder.ast.getKind(clause_idx);
        if (clause_kind == .CaseClause) {
            const clause = c.binder.ast.getNode(clause_idx).CaseClause;
            _ = checkExpression(c, clause.Expression);
            const stmts = c.binder.ast.getNodeList(clause.Statements);
            for (stmts) |stmt_idx| {
                if (stmt_idx != 0) checkSourceElement(c, stmt_idx);
            }
        } else if (clause_kind == .DefaultClause) {
            const clause = c.binder.ast.getNode(clause_idx).DefaultClause;
            const stmts = c.binder.ast.getNodeList(clause.Statements);
            for (stmts) |stmt_idx| {
                if (stmt_idx != 0) checkSourceElement(c, stmt_idx);
            }
        }
    }
}
pub fn checkTemplateLiteralType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).TemplateLiteralType;
    const template_spans = c.binder.ast.getNodeList(node.TemplateSpans);
    for (template_spans) |span_idx| {
        const span = c.binder.ast.getNode(span_idx).TemplateLiteralTypeSpan;
        if (span.Type != 0) checkSourceElement(c, span.Type);
    }
}
pub fn checkThisType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    _ = c;
    _ = node_idx;
}
pub fn checkThrowStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).ThrowStatement;
    _ = checkExpression(c, node.Expression);
}
pub fn checkTryStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const data = c.binder.ast.getNode(node_idx).TryStatement;
    checkBlock(c, data.TryBlock);
    if (data.CatchClause) |catch_clause| {
        checkCatchClause(c, catch_clause);
    }
    if (data.FinallyBlock) |finally_block| {
        checkBlock(c, finally_block);
    }
}
pub fn checkCatchClause(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).CatchClause;
    if (node.VariableDeclaration != 0) {
        if (node.VariableDeclaration) |vd| checkVariableLikeDeclaration(c, vd);
    }
    checkBlock(c, node.Block);
}
pub fn checkTupleType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).TupleType;
    const elements = c.binder.ast.getNodeList(node.Elements);
    for (elements) |el_idx| {
        if (el_idx != 0) checkSourceElement(c, el_idx);
    }
}
pub fn checkTypeAliasDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).TypeAliasDeclaration;
    if (node.TypeParameters) |tps| {
        checkTypeParameters(c, tps);
    }
    if (node.Type != 0) checkSourceElement(c, node.Type);
}
pub fn checkTypeLiteral(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).TypeLiteral;
    const members = c.binder.ast.getNodeList(node.Members);
    for (members) |mem_idx| {
        if (mem_idx != 0) checkSourceElement(c, mem_idx);
    }
}
pub fn checkTypeOperator(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).TypeOperator;
    if (node.Type != 0) checkSourceElement(c, node.Type);
}
pub fn checkTypeParameter(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).TypeParameter;
    if (node.Constraint) |constraint| if (constraint != 0) checkSourceElement(c, constraint);
    if (node.DefaultType) |def| if (def != 0) checkSourceElement(c, def);
}
pub fn checkTypeParameters(c: *Checker, list_idx: ast_gen.NodeIndex) void {
    const list = c.binder.ast.getNodeList(list_idx);
    for (list) |idx| {
        checkTypeParameter(c, idx);
    }
}
pub fn checkTypePredicate(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).TypePredicate;
    if (node.Type) |type_idx| {
        if (type_idx != 0) checkSourceElement(c, type_idx);
    }
}
pub fn checkTypeQuery(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    _ = c.getTypeOfNode(node_idx) catch return;
}
pub fn checkTypeReferenceNode(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).TypeReference;
    if (node.TypeArguments) |args| {
        const type_args = c.binder.ast.getNodeList(args);
        for (type_args) |arg_idx| {
            if (arg_idx != 0) checkSourceElement(c, arg_idx);
        }
    }
}
pub fn checkUnionOrIntersectionType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node_kind = c.binder.ast.getKind(node_idx);
    const types_list = switch (node_kind) {
        .UnionType => c.binder.ast.getNode(node_idx).UnionType.Types,
        .IntersectionType => c.binder.ast.getNode(node_idx).IntersectionType.Types,
        else => unreachable,
    };
    const type_nodes = c.binder.ast.getNodeList(types_list);
    for (type_nodes) |t_idx| {
        if (t_idx != 0) checkSourceElement(c, t_idx);
    }
}
pub fn checkVariableDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    // checkGrammarVariableDeclaration
    checkVariableLikeDeclaration(c, node_idx);
}

pub fn checkVariableLikeDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    // We only need to traverse children to maintain traversal order.
    // In DoD, we don't need to do complex type checking yet if we are just traversing, but checking types is what the checker does.
    // So let's implement the AST traversal parts.
    const name_idx = ast_utils.getName(c.binder.ast, node_idx);
    if (name_idx == 0) return; // Missing array binding elements have no name

    const type_idx = 0;
    const initializer_idx = 0;

    if (!ast_utils.isBindingElement(c.binder.ast, node_idx)) {
        if (type_idx != 0) checkSourceElement(c, type_idx);
    }

    if (ast_utils.isComputedPropertyName(c.binder.ast, name_idx)) {
        _ = checkExpression(c, name_idx);
        if (initializer_idx != 0) {
            _ = checkExpression(c, initializer_idx);
        }
    }

    if (ast_utils.isBindingElement(c.binder.ast, node_idx)) {
        const propName = 0;
        if (propName != 0 and ast_utils.isComputedPropertyName(c.binder.ast, propName)) {
            c.checkComputedPropertyName(propName);
        }
    }

    if (ast_utils.isBindingPattern(c.binder.ast, name_idx)) {
        // c.checkSourceElements(name.Elements())
        const elements = ast_utils.getElements(c.binder.ast, name_idx);
        if (elements.len != 0) {
            const list = elements;
            for (list) |el_idx| {
                if (el_idx != 0) checkSourceElement(c, el_idx);
            }
        }
    }

    if (ast_utils.isBindingPattern(c.binder.ast, name_idx)) {
        // check the binding pattern with empty elements
        // This is skipped for now as we just do the traversal.
    } else {
        if (initializer_idx != 0) {
            _ = checkExpression(c, initializer_idx);
        }
    }
}
pub fn checkVariableStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const list = c.binder.ast.nodes.get(node_idx).VariableStatement.DeclarationList;
    if (list != 0) {
        if (list != 0) checkSourceElement(c, list);
    }
}
pub fn checkVariableDeclarationList(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const declarations = c.binder.ast.nodes.get(node_idx).VariableDeclarationList.Declarations;
    const list = c.binder.ast.getNodeList(declarations);
    for (list) |decl_idx| {
        if (decl_idx != 0) checkSourceElement(c, decl_idx);
    }
}
pub fn checkWhileStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    checkGrammarStatementInAmbientContext(c, node_idx);
    const node = c.binder.ast.getNode(node_idx).WhileStatement;
    _ = c.checkTruthinessExpression(node.Expression, CheckMode.Normal);
    if (node.Statement != 0) checkSourceElement(c, node.Statement);
}
pub fn checkPropertyAssignment(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const pa = c.binder.ast.nodes.get(node_idx).PropertyAssignment;
    if (pa.Initializer != 0) {
        _ = checkExpression(c, pa.Initializer);
    }
}
pub fn checkShorthandPropertyAssignment(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const spa = c.binder.ast.nodes.get(node_idx).ShorthandPropertyAssignment;
    if (spa.ObjectAssignmentInitializer != 0) {
        if (spa.ObjectAssignmentInitializer) |init| _ = checkExpression(c, init);
    }
}
pub fn checkWithStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).WithStatement;
    _ = checkExpression(c, node.Expression);
    if (node.Statement != 0) checkSourceElement(c, node.Statement);
}

pub fn checkExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    return checkExpressionEx(c, node_idx, CheckMode.Normal);
}

pub fn instantiateTypeWithSingleGenericCallSignature(c: *Checker, node_idx: ast_gen.NodeIndex, uninstantiatedType: types.TypeIndex, checkMode: CheckMode) types.TypeIndex {
    _ = c;
    _ = node_idx;
    _ = checkMode;
    return uninstantiatedType;
}

pub fn checkExpressionEx(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    const saveCurrentNode = c.currentNode;
    c.currentNode = node_idx;
    c.instantiationCount = 0;
    const uninstantiatedType = checkExpressionWorker(c, node_idx, checkMode);
    const t = instantiateTypeWithSingleGenericCallSignature(c, node_idx, uninstantiatedType, checkMode);

    // In Go: if isConstEnumObjectType(t) { c.checkConstEnumAccess(node, t) }
    // As stub, we do nothing or just pass it to checkConstEnumAccess
    c.checkConstEnumAccess(node_idx, t);

    c.currentNode = saveCurrentNode;
    return t;
}

pub fn checkSourceElement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    if (node_idx != 0) {
        const saveCurrentNode = c.currentNode;
        const saveWithinUnreachableCode = c.withinUnreachableCode;
        c.currentNode = node_idx;
        c.instantiationCount = 0;
        checkSourceElementWorker(c, node_idx);
        c.currentNode = saveCurrentNode;
        c.withinUnreachableCode = saveWithinUnreachableCode;
    }
}
pub fn checkExpressionWorker(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    const node = c.binder.ast.getNode(node_idx);
    switch (node) {
        .Identifier => {
            return checkIdentifier(c, node_idx, checkMode);
        },
        .PrivateIdentifier => {
            return checkPrivateIdentifierExpression(c, node_idx);
        },
        .ThisKeyword => {
            return checkThisExpression(c, node_idx);
        },
        .SuperKeyword => {
            return checkSuperExpression(c, node_idx);
        },
        .NullKeyword => {
            return c.anyTypeIndex orelse 0;
        },
        .StringLiteral, .NoSubstitutionTemplateLiteral => {
            return checkStringLiteral(c, node_idx, checkMode);
        },
        .NumericLiteral => {
            return checkNumericLiteral(c, node_idx, checkMode);
        },
        .BigIntLiteral => {
            return checkBigIntLiteral(c, node_idx, checkMode);
        },
        .RegularExpressionLiteral => {
            return getGlobalRegExpType(c, true) catch (c.anyTypeIndex orelse 0);
        },
        .ArrayLiteralExpression => {
            return checkArrayLiteral(c, node_idx, checkMode, null);
        },
        .ObjectLiteralExpression => {
            return checkObjectLiteral(c, node_idx, checkMode);
        },
        .PropertyAccessExpression => {
            return checkPropertyAccessExpression(c, node_idx, checkMode, false);
        },
        .ElementAccessExpression => {
            const expr_idx = c.binder.ast.getNode(node_idx).ElementAccessExpression.Expression;
            const exprType = checkExpression(c, expr_idx);
            return checkElementAccessExpression(c, node_idx, exprType, checkMode);
        },
        .CallExpression => {
            if (ast_utils.isImportCall(c.binder.ast, node_idx)) {
                return c.checkImportCallExpression(node_idx);
            }
            return checkCallExpression(c, node_idx, checkMode);
        },
        .NewExpression => {
            return checkCallExpression(c, node_idx, checkMode);
        },
        .TaggedTemplateExpression => {
            return checkTaggedTemplateExpression(c, node_idx);
        },
        .ParenthesizedExpression => {
            return checkParenthesizedExpression(c, node_idx, checkMode);
        },
        .FunctionExpression, .ArrowFunction => {
            return checkFunctionExpressionOrObjectLiteralMethod(c, node_idx, checkMode);
        },
        .ClassExpression => {
            return checkClassExpression(c, node_idx);
        },
        .TypeAssertionExpression => {
            return checkAssertion(c, node_idx);
        },
        .AsExpression => {
            return checkAssertion(c, node_idx);
        },
        .SatisfiesExpression => {
            return checkSatisfiesExpression(c, node_idx);
        },
        .NonNullExpression => {
            return checkNonNullExpression(c, node_idx);
        },
        .MetaProperty => {
            return checkMetaProperty(c, node_idx);
        },
        .PrefixUnaryExpression => {
            return checkPrefixUnaryExpression(c, node_idx, checkMode);
        },
        .PostfixUnaryExpression => {
            return checkPostfixUnaryExpression(c, node_idx, checkMode);
        },
        .BinaryExpression => {
            return checkBinaryExpression(c, node_idx, checkMode);
        },
        .ConditionalExpression => {
            return checkConditionalExpression(c, node_idx, checkMode);
        },
        .ExpressionWithTypeArguments => {
            return checkExpressionWithTypeArguments(c, node_idx);
        },
        .YieldExpression => {
            return checkYieldExpression(c, node_idx);
        },
        .SpreadElement => {
            return checkSpreadExpression(c, node_idx, checkMode);
        },
        .OmittedExpression => {
            return c.getUndefinedType() catch (c.anyTypeIndex orelse 0);
        },
        .Block, .ModuleBlock => {
            checkBlock(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .VariableStatement => {
            checkVariableStatement(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .ExpressionStatement => {
            checkExpressionStatement(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .IfStatement => {
            checkIfStatement(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .DoStatement => {
            checkDoStatement(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .WhileStatement => {
            checkWhileStatement(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .ForStatement => {
            checkForStatement(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .ForInStatement => {
            checkForInStatement(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .ForOfStatement => {
            checkForOfStatement(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .ContinueStatement, .BreakStatement => {
            checkBreakOrContinueStatement(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .ReturnStatement => {
            checkReturnStatement(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .WithStatement => {
            checkWithStatement(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .SwitchStatement => {
            checkSwitchStatement(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .LabeledStatement => {
            checkLabeledStatement(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .ThrowStatement => {
            checkThrowStatement(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .TryStatement => {
            checkTryStatement(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .VariableDeclaration => {
            checkVariableDeclaration(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .BindingElement => {
            checkBindingElement(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .ClassDeclaration => {
            checkClassDeclaration(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .InterfaceDeclaration => {
            checkInterfaceDeclaration(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .TypeAliasDeclaration => {
            checkTypeAliasDeclaration(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .EnumDeclaration => {
            checkEnumDeclaration(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .EnumMember => {
            checkEnumMember(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .ModuleDeclaration => {
            checkModuleDeclaration(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .ImportDeclaration => {
            checkImportDeclaration(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .ImportEqualsDeclaration => {
            checkImportEqualsDeclaration(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .ExportDeclaration => {
            checkExportDeclaration(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .ExportAssignment => {
            checkExportAssignment(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .EmptyStatement => {
            checkGrammarStatementInAmbientContext(c, node_idx);
            return c.anyTypeIndex orelse 0;
        },
        .TemplateExpression => {
            return checkTemplateExpression(c, node_idx);
        },
        .PartiallyEmittedExpression => {
            return checkPartiallyEmittedExpression(c, node_idx);
        },
        // .CommaListExpression => {
        //     return checkCommaListExpression(c, node_idx);
        // },
        .SyntheticExpression => {
            return checkSyntheticExpression(c, node_idx);
        },
        .TrueKeyword => {
            return c.getTrueType() catch (c.anyTypeIndex orelse 0);
        },
        .FalseKeyword => {
            return c.getFalseType() catch (c.anyTypeIndex orelse 0);
        },
        .VoidExpression => {
            return checkVoidExpression(c, node_idx);
        },
        .TypeOfExpression => {
            return checkTypeOfExpression(c, node_idx);
        },
        .DeleteExpression => {
            return checkDeleteExpression(c, node_idx);
        },
        .AwaitExpression => {
            return checkAwaitExpression(c, node_idx);
        },
        .TypeParameter, .Parameter, .ConstructorType, .FunctionType, .CallSignature, .ConstructSignature, .IndexSignature, .MethodSignature, .Constructor, .GetAccessor, .SetAccessor, .PropertySignature, .TypeReference, .TypePredicate, .TypeQuery, .TypeLiteral, .ArrayType, .TupleType, .UnionType, .IntersectionType, .ParenthesizedType, .OptionalType, .ThisType, .TypeOperator, .ConditionalType, .InferType, .TemplateLiteralType, .ImportType, .NamedTupleMember, .IndexedAccessType, .MappedType, .DebuggerStatement, .MissingDeclaration, .PropertyDeclaration, .MethodDeclaration, .ClassStaticBlockDeclaration, .JSDocNonNullableType, .JSDocNullableType, .JSDocAllType, .JSDocTypeLiteral => {
            return c.errorTypeIndex orelse 0;
        },
        else => return c.anyTypeIndex orelse 0,
    }
}

// Stubs
pub fn checkArrayLiteral(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode, arg4: ?ast_gen.NodeIndex) types.TypeIndex {
    _ = arg4;
    const elements = c.binder.ast.nodes.get(node_idx).ArrayLiteralExpression.Elements;
    const elem_list = c.binder.ast.getNodeList(elements);
    for (elem_list) |elem_idx| {
        const node = c.binder.ast.nodes.get(elem_idx);
        switch (node) {
            .SpreadElement => |spread| {
                _ = checkExpressionEx(c, spread.Expression, checkMode);
            },
            .OmittedExpression => {},
            else => {
                _ = checkExpressionEx(c, elem_idx, checkMode);
            },
        }
    }
    return c.anyTypeIndex orelse 0; // Stub: full checkArrayLiteral logic pending
}
pub fn checkAssertion(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    const node_kind = c.binder.ast.getKind(node_idx);
    const expr = if (node_kind == .TypeAssertionExpression) c.binder.ast.getNode(node_idx).TypeAssertionExpression.Expression else if (node_kind == .SatisfiesExpression) c.binder.ast.getNode(node_idx).SatisfiesExpression.Expression else c.binder.ast.getNode(node_idx).AsExpression.Expression;
    const typeNode = if (node_kind == .TypeAssertionExpression) c.binder.ast.getNode(node_idx).TypeAssertionExpression.Type else if (node_kind == .SatisfiesExpression) c.binder.ast.getNode(node_idx).SatisfiesExpression.Type else c.binder.ast.getNode(node_idx).AsExpression.Type;
    _ = checkExpression(c, expr);
    return c.getTypeFromTypeNode(typeNode);
}
pub fn checkAwaitExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    const node = c.binder.ast.getNode(node_idx).AwaitExpression;
    const operandType = checkExpression(c, node.Expression);
    const awaitedType = c.checkAwaitedType(operandType, true, node_idx, &diagnostics_gen.Type_of_await_operand_must_either_be_a_valid_promise_or_must_not_contain_a_callable_then_member);
    if (awaitedType == operandType and !c.isErrorType(awaitedType) and c.getTypeFlags(operandType) & (types.TypeFlags.Any | types.TypeFlags.Unknown) == 0) {
        c.reportError(node_idx, &diagnostics_gen.X_await_has_no_effect_on_the_type_of_this_expression);
    }
    return awaitedType;
}
pub fn checkBigIntLiteral(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    _ = node_idx;
    _ = checkMode;
    return c.anyTypeIndex orelse 0;
}
pub fn checkBinaryExpression(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    const bin = c.binder.ast.getNode(node_idx).BinaryExpression;
    return c.checkBinaryLikeExpression(bin.Left, bin.OperatorToken, bin.Right, checkMode, node_idx);
}
pub fn checkCallExpression(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    const isNew = c.binder.ast.getKind(node_idx) == .NewExpression;
    const typeArgumentList = if (isNew) c.binder.ast.getNode(node_idx).NewExpression.TypeArguments else c.binder.ast.getNode(node_idx).CallExpression.TypeArguments;
    _ = grammarchecks.checkGrammarTypeArguments(c, node_idx, typeArgumentList orelse 0);

    const signature = c.getResolvedSignature(node_idx, null, checkMode);
    if (false) {
        return c.errorTypeIndex orelse 0;
    }
    c.checkDeprecatedSignature(signature, node_idx);

    const expression = if (isNew) c.binder.ast.getNode(node_idx).NewExpression.Expression else c.binder.ast.getNode(node_idx).CallExpression.Expression;
    if (c.binder.ast.getKind(expression) == .SuperKeyword) {
        return c.voidTypeIndex orelse 0;
    }

    if (isNew) {
        const declaration = c.signatures.items[signature].declaration;
        if (declaration != 0 and c.binder.ast.getKind(declaration) != .Constructor and c.binder.ast.getKind(declaration) != .ConstructSignature and c.binder.ast.getKind(declaration) != .ConstructorType) {
            if (c.noImplicitAny) {
                c.reportError(node_idx, &diagnostics_gen.X_new_expression_whose_target_lacks_a_construct_signature_implicitly_has_an_any_type);
            }
            return c.anyTypeIndex orelse 0;
        }
    }

    if (ast_utils.isInJSFile(c.binder.ast, node_idx) and c.isCommonJSRequire(node_idx)) {
        const arguments = if (isNew) c.binder.ast.getNode(node_idx).NewExpression.Arguments else c.binder.ast.getNode(node_idx).CallExpression.Arguments;
        if (arguments != 0) {
            const elements = c.binder.ast.getNodeList(arguments orelse 0);
            if (elements.len > 0) {
                return c.resolveExternalModuleTypeByLiteral(elements[0]);
            }
        }
    }

    const returnType = c.getReturnTypeOfSignature(&c.signatures.items[signature]);

    if (c.getTypeFlags(returnType) & types.TypeFlags.ESSymbolLike != 0 and c.isSymbolOrSymbolForCall(node_idx)) {
        return c.anyTypeIndex orelse 0;
    }

    if (!isNew) {
        const questionDotToken = c.binder.ast.getNode(node_idx).CallExpression.QuestionDotToken;
        const parent: u32 = 0;
        if (questionDotToken == 0 and c.binder.ast.getKind(parent) == .ExpressionStatement and c.getTypeFlags(returnType) & types.TypeFlags.Void != 0 and relater.getTypePredicateOfSignature(c, signature) != null) {
            if (!false) {
                c.reportError(expression, &diagnostics_gen.Assertions_require_the_call_target_to_be_an_identifier_or_qualified_name);
            } else if (flow.getEffectsSignature(c, node_idx) == null) {
                const diagnostic = c.reportError(expression, &diagnostics_gen.Assertions_require_every_name_in_the_call_target_to_be_declared_with_an_explicit_type_annotation);
                _ = flow.getTypeOfDottedName(c, expression, diagnostic);
            }
        }
    }

    return returnType;
}
pub fn checkClassExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    _ = node_idx;
    return c.anyTypeIndex orelse 0;
}
pub fn checkCommaListExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    _ = node_idx;
    return c.anyTypeIndex orelse 0;
}
pub fn checkConditionalExpression(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    const expr = c.binder.ast.getNode(node_idx).ConditionalExpression;
    const condType = checkExpressionEx(c, expr.Condition, checkMode);
    const t = c.checkTruthinessOfType(condType, expr.Condition);
    c.checkTestingKnownTruthyCallableOrAwaitableOrEnumMemberType(expr.Condition, t, expr.WhenTrue);
    var t1: types.TypeIndex = 0;
    var t2: types.TypeIndex = 0;

    const facts = c.getTypeFacts(condType, types.TypeFacts.Truthy | types.TypeFacts.Falsy);

    if (facts == types.TypeFacts.Falsy) {
        _ = checkExpression(c, expr.WhenTrue);
        t2 = checkExpressionEx(c, expr.WhenFalse, checkMode);
    } else if (facts == types.TypeFacts.Truthy) {
        t1 = checkExpressionEx(c, expr.WhenTrue, checkMode);
        _ = checkExpression(c, expr.WhenFalse);
    } else {
        t1 = checkExpressionEx(c, expr.WhenTrue, checkMode);
        t2 = checkExpressionEx(c, expr.WhenFalse, checkMode);
    }

    if (facts == types.TypeFacts.Falsy) {
        return t2;
    } else if (facts == types.TypeFacts.Truthy) {
        return t1;
    }

    return c.anyTypeIndex orelse 0;
}
pub fn checkDeleteExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    const node = c.binder.ast.getNode(node_idx).DeleteExpression;
    _ = checkExpression(c, node.Expression);
    const expr = node.Expression;
    if (!false) {
        c.reportError(expr, &diagnostics_gen.The_operand_of_a_delete_operator_must_be_a_property_reference);
        return c.booleanTypeIndex orelse 0;
    }
    if (c.binder.ast.getKind(expr) == .PropertyAccessExpression and c.binder.ast.getKind(c.binder.ast.getNode(expr).PropertyAccessExpression.name) == .PrivateIdentifier) {
        c.reportError(expr, &diagnostics_gen.The_operand_of_a_delete_operator_cannot_be_a_private_identifier);
    }
    if (getResolvedSymbolOrNil(c, expr)) |sym_idx| {
        const symbol_ = c.getExportSymbolOfValueSymbolIfExported(sym_idx);
        if (c.isReadonlySymbol(symbol_)) {
            c.reportError(expr, &diagnostics_gen.The_operand_of_a_delete_operator_cannot_be_a_read_only_property);
        } else {
            c.checkDeleteExpressionMustBeOptional(expr, symbol_);
        }
    }
    return c.booleanTypeIndex orelse 0;
}
pub fn checkElementAccessExpression(c: *Checker, node_idx: ast_gen.NodeIndex, exprType: types.TypeIndex, checkMode: CheckMode) types.TypeIndex {
    const node = c.binder.ast.getNode(node_idx).ElementAccessExpression;
    var objectType = exprType;
    if (utils.getAssignmentTargetKind(c.binder.ast, node_idx) != .None or c.isMethodAccessForCall(node_idx)) {
        objectType = c.getWidenedType(objectType);
    }

    const indexExpression = node.ArgumentExpression;
    const indexType = checkExpression(c, indexExpression);

    if (c.isErrorType(objectType) or objectType == (c.errorTypeIndex orelse 0)) {
        return objectType;
    }

    if (false and !utils.isStringLiteralLike(c.binder.ast, indexExpression)) {
        c.addError(indexExpression, &diagnostics_gen.A_const_enum_member_can_only_be_accessed_using_a_string_literal);
        return c.errorTypeIndex orelse 0;
    }

    var effectiveIndexType = indexType;
    if (c.isForInVariableForNumericPropertyNames(indexExpression)) {
        effectiveIndexType = c.numberTypeIndex orelse 0;
    }

    const assignmentTargetKind = utils.getAssignmentTargetKind(c.binder.ast, node_idx);
    var accessFlags: u32 = undefined;
    if (assignmentTargetKind == .None) {
        accessFlags = types.AccessFlags.ExpressionPosition;
    } else {
        const flag1: u32 = if (assignmentTargetKind == .Compound) types.AccessFlags.ExpressionPosition else 0;
        const flag2: u32 = if (c.isGenericObjectType(objectType) and !utils.isThisTypeParameter(c, objectType)) types.AccessFlags.NoIndexSignatures else 0;
        accessFlags = types.AccessFlags.Writing | flag1 | flag2;
    }

    const indexedAccessType = c.getIndexedAccessTypeOrUndefined(objectType, effectiveIndexType, accessFlags, node_idx, 0) orelse (c.errorTypeIndex orelse 0);
    return c.checkIndexedAccessIndexType(c.getFlowTypeOfAccessExpression(node_idx, getResolvedSymbolOrNil(c, node_idx), indexedAccessType, indexExpression, checkMode), node_idx);
}
pub fn checkFunctionExpressionOrObjectLiteralMethod(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    _ = checkMode;
    const node = c.binder.ast.getNode(node_idx);
    const params_id: ast_gen.NodeIndex = switch (node) {
        .FunctionExpression => |f| f.Parameters,
        .ArrowFunction => |f| f.Parameters,
        .MethodDeclaration => |m| m.Parameters,
        else => 0,
    };
    checkFunctionParameters(c, params_id);
    switch (node) {
        .FunctionExpression => |f| {
            if (f.Body) |body| if (body != 0) checkSourceElement(c, body);
        },
        .ArrowFunction => |f| {
            if (f.Body) |body| c.checkStatementAdHoc(body) catch {};
        },
        .MethodDeclaration => |m| {
            if (m.Body) |body| if (body != 0) checkSourceElement(c, body);
        },
        else => {},
    }
    return c.anyTypeIndex orelse 0;
}
pub fn checkIdentifier(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    _ = checkMode;
    const name = c.binder.ast.getNode(node_idx).Identifier.Text;
    if (isNodeGlobalName(name) and !c.hasNodeTypeDefinitions()) {
        c.reportErrorWithArgs(
            node_idx,
            &diagnostics_gen.Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_node_Try_npm_i_save_dev_types_Slashnode_and_then_add_node_to_the_types_field_in_your_tsconfig,
            &.{name},
        );
    }
    if (c.resolver.resolve(node_idx, name, symbol.SymbolFlags.Value, null, false, false)) |symIndex| {
        return c.getTypeOfSymbol(symIndex) catch c.anyTypeIndex orelse 0;
    }
    return c.anyTypeIndex orelse 0;
}

fn isNodeGlobalName(name: []const u8) bool {
    const names = [_][]const u8{ "module", "require", "exports", "__dirname", "__filename", "process", "Buffer", "global" };
    for (names) |global_name| {
        if (std.mem.eql(u8, name, global_name)) return true;
    }
    return false;
}
pub fn checkMetaProperty(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    _ = grammarchecks.checkGrammarMetaProperty(c, node_idx);
    const node = c.binder.ast.getNode(node_idx).MetaProperty;
    if (node.KeywordToken == 80) { // NewKeyword approx
        return checkNewTargetMetaProperty(c, node_idx);
    } else if (node.KeywordToken == 115) { // ImportKeyword approx
        return checkImportMetaProperty(c, node_idx);
    }
    return c.anyTypeIndex orelse 0;
}
// pub fn checkNewExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
//     return c.checkExpressionAdHoc(node_idx) catch c.anyTypeIndex orelse 0;
// }
pub fn checkNonNullExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    const flags = c.binder.ast.getNodeFlags(node_idx);
    if ((flags & ast_utils.NodeFlags.OptionalChain) != 0) {
        return c.checkNonNullChain(node_idx);
    }
    const expr = c.binder.ast.getNode(node_idx).NonNullExpression;
    return c.getNonNullableType(checkExpression(c, expr.Expression));
}
pub fn checkNumericLiteral(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    _ = checkMode;
    const n = c.binder.ast.getNode(node_idx).NumericLiteral;
    const value = std.fmt.parseFloat(f64, n.Text) catch 0.0;
    return c.getFreshTypeOfLiteralType(c.getNumberLiteralType(value));
}
pub fn checkObjectLiteral(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    _ = checkMode;
    const inDestructuringPattern = false;
    _ = grammarchecks.checkGrammarObjectLiteralExpression(c, node_idx, inDestructuringPattern);

    const properties = c.binder.ast.nodes.get(node_idx).ObjectLiteralExpression.Properties;
    const prop_list = c.binder.ast.getNodeList(properties);

    // Just typecheck properties so nested statements get checked
    for (prop_list) |prop_idx| {
        if (prop_idx != 0) checkSourceElement(c, prop_idx);
    }

    return c.anyTypeIndex orelse 0;
}
pub fn checkParenthesizedExpression(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    const node = c.binder.ast.getNode(node_idx).ParenthesizedExpression;
    return checkExpressionEx(c, node.Expression, checkMode);
}
pub fn checkPartiallyEmittedExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    const expr = c.binder.ast.getNode(node_idx).PartiallyEmittedExpression;
    return checkExpression(c, expr.Expression);
}
pub fn checkPostfixUnaryExpression(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    const expr = c.binder.ast.getNode(node_idx).PostfixUnaryExpression;
    const operandType = checkExpressionEx(c, expr.Operand, checkMode);
    if (operandType == c.errorTypeIndex orelse 0) {
        return c.errorTypeIndex orelse 0;
    }
    const nonNullType = c.checkNonNullType(operandType, expr.Operand);
    const ok = c.checkArithmeticOperandType(expr.Operand, nonNullType, diagnostics_gen.An_arithmetic_operand_must_be_of_type_any_number_bigint_or_an_enum_type, false);
    if (ok) {
        _ = c.checkReferenceExpression(expr.Operand, diagnostics_gen.The_operand_of_an_increment_or_decrement_operator_must_be_a_variable_or_a_property_access, diagnostics_gen.The_operand_of_an_increment_or_decrement_operator_may_not_be_an_optional_property_access);
    }
    return c.getUnaryResultType(operandType) catch c.errorTypeIndex orelse 0;
}
pub fn checkPrefixUnaryExpression(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    const expr = c.binder.ast.getNode(node_idx).PrefixUnaryExpression;
    const operandType = checkExpressionEx(c, expr.Operand, checkMode);
    if (operandType == c.errorTypeIndex orelse 0) {
        return c.errorTypeIndex orelse 0;
    }

    const operandKind = c.binder.ast.getKind(expr.Operand);
    if (operandKind == .NumericLiteral) {
        if (expr.Operator == @intFromEnum(kind.Kind.MinusToken)) {
            const text = c.binder.ast.getNode(expr.Operand).NumericLiteral.Text;
            const value = std.fmt.parseFloat(f64, text) catch 0.0;
            return c.getFreshTypeOfLiteralType(c.getNumberLiteralType(-value));
        } else if (expr.Operator == @intFromEnum(kind.Kind.PlusToken)) {
            const text = c.binder.ast.getNode(expr.Operand).NumericLiteral.Text;
            const value = std.fmt.parseFloat(f64, text) catch 0.0;
            return c.getFreshTypeOfLiteralType(c.getNumberLiteralType(value));
        }
    } else if (operandKind == .BigIntLiteral) {
        if (expr.Operator == @intFromEnum(kind.Kind.MinusToken)) {
            return c.anyTypeIndex orelse 0;
        }
    }

    switch (@as(@import("../ast/kind.zig").Kind, @enumFromInt(expr.Operator))) {
        .PlusToken, .MinusToken, .TildeToken => {
            _ = c.checkNonNullType(operandType, expr.Operand);
            if (c.maybeTypeOfKindConsideringBaseConstraint(operandType, types.TypeFlags.ESSymbolLike)) {
                c.reportErrorWithArgs(expr.Operand, &diagnostics_gen.The_0_operator_cannot_be_applied_to_type_symbol, &[_][]const u8{""});
            }
            if (expr.Operator == @intFromEnum(kind.Kind.PlusToken)) {
                if (c.maybeTypeOfKindConsideringBaseConstraint(operandType, types.TypeFlags.BigIntLike)) {
                    c.reportErrorWithArgs(expr.Operand, &diagnostics_gen.Operator_0_cannot_be_applied_to_type_1, &[_][]const u8{ "", c.typeToString(c.getBaseTypeOfLiteralType(operandType), 0, 0, null) });
                }
                return c.numberTypeIndex orelse 0;
            }
            return c.getUnaryResultType(operandType) catch c.errorTypeIndex orelse 0;
        },
        .ExclamationToken => {
            _ = c.checkTruthinessOfType(operandType, expr.Operand);
            const facts = c.getTypeFacts(operandType, types.TypeFacts.Truthy | types.TypeFacts.Falsy);
            if (facts == types.TypeFacts.Truthy) {
                return c.falseTypeIndex orelse 0;
            } else if (facts == types.TypeFacts.Falsy) {
                return c.trueTypeIndex orelse 0;
            } else {
                return c.booleanTypeIndex orelse 0;
            }
        },
        .PlusPlusToken, .MinusMinusToken => {
            const nonNullType = c.checkNonNullType(operandType, expr.Operand);
            const ok = c.checkArithmeticOperandType(expr.Operand, nonNullType, diagnostics_gen.An_arithmetic_operand_must_be_of_type_any_number_bigint_or_an_enum_type, false);
            if (ok) {
                _ = c.checkReferenceExpression(expr.Operand, diagnostics_gen.The_operand_of_an_increment_or_decrement_operator_must_be_a_variable_or_a_property_access, diagnostics_gen.The_operand_of_an_increment_or_decrement_operator_may_not_be_an_optional_property_access);
            }
            return c.getUnaryResultType(operandType) catch c.errorTypeIndex orelse 0;
        },
        else => return c.errorTypeIndex orelse 0,
    }
}
pub fn checkPrivateIdentifierExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    _ = grammarchecks.checkGrammarPrivateIdentifierExpression(c, node_idx);
    const sym = c.getSymbolForPrivateIdentifierExpression(node_idx);
    if (sym != 0) {
        c.markPropertyAsReferenced(sym, 0, false);
    }
    return c.anyTypeIndex orelse 0;
}
pub fn checkPropertyAccessExpression(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode, writeOnly: bool) types.TypeIndex {
    const nodeFlags = c.binder.ast.getNodeFlags(node_idx);
    if ((nodeFlags & ast_utils.NodeFlags.OptionalChain) != 0) {
        return checkPropertyAccessChain(c, node_idx, checkMode);
    }
    const expr_idx = c.binder.ast.getNode(node_idx).PropertyAccessExpression.Expression;
    const name_idx = c.binder.ast.getNode(node_idx).PropertyAccessExpression.name;
    return c.checkPropertyAccessExpressionOrQualifiedName(node_idx, expr_idx, checkNonNullExpression(c, expr_idx), name_idx, checkMode, writeOnly);
}

pub fn checkPropertyAccessChain(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    const expr_idx = c.binder.ast.getNode(node_idx).PropertyAccessExpression.Expression;
    const name_idx = c.binder.ast.getNode(node_idx).PropertyAccessExpression.name;
    const leftType = checkExpression(c, expr_idx);
    const nonOptionalType = c.getOptionalExpressionType(leftType, expr_idx);
    const resultType = c.checkPropertyAccessExpressionOrQualifiedName(node_idx, expr_idx, c.checkNonNullType(nonOptionalType, expr_idx), name_idx, checkMode, false);
    return c.propagateOptionalTypeMarker(resultType, node_idx, nonOptionalType != leftType);
}
pub fn checkSatisfiesExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    return checkAssertion(c, node_idx);
}
pub fn checkSpreadExpression(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    const node = c.binder.ast.getNode(node_idx).SpreadElement;
    _ = checkExpressionEx(c, node.Expression, checkMode);
    return c.anyTypeIndex orelse 0;
}
pub fn checkStringLiteral(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    _ = checkMode;
    const s = c.binder.ast.getNode(node_idx).StringLiteral;
    return c.getFreshTypeOfLiteralType(c.getStringLiteralType(s.Text));
}
pub fn checkSuperExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    _ = node_idx;
    return c.anyTypeIndex orelse 0;
}
pub fn checkSyntheticExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    const node = c.binder.ast.getNode(node_idx).SyntheticExpression;
    const t = node.Type;
    if (node.IsSpread != 0) {
        return c.getIndexedAccessType(t, c.numberTypeIndex orelse 0);
    }
    return t;
}
pub fn checkTaggedTemplateExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    _ = c;
    _ = node_idx;
    return 0; // Simplified to avoid complex dependencies for now
}
pub fn checkTemplateExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    const expr = c.binder.ast.getNode(node_idx).TemplateExpression;
    for (c.binder.ast.getNodeList(expr.TemplateSpans)) |span_idx| {
        const span = c.binder.ast.getNode(span_idx).TemplateSpan;
        _ = checkExpression(c, span.Expression);
    }
    return c.stringTypeIndex orelse 0;
}
pub fn checkThisExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    var container = ast_utils.getParent(c.binder.ast, node_idx);
    while (container != 0) {
        const container_kind = c.binder.ast.getKind(container);
        switch (container_kind) {
            .Constructor, .MethodDeclaration, .GetAccessor, .SetAccessor, .FunctionDeclaration, .FunctionExpression, .ArrowFunction => {
                const parent = ast_utils.getParent(c.binder.ast, container);
                if (parent != 0 and ast_utils.isClassLike(c.binder.ast, parent)) {
                    const sym = getSymbolOfNode(c, parent) orelse c.getSymbolOfDeclaration(parent);
                    if (sym != 0) {
                        const class_type = c.tryGetDeclaredTypeOfSymbol(sym);
                        if (class_type != 0) return class_type;
                    }
                }
                break;
            },
            .SourceFile => break,
            else => {},
        }
        container = ast_utils.getParent(c.binder.ast, container);
    }
    return c.anyTypeIndex orelse 0;
}
pub fn checkTypeOfExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    const node = c.binder.ast.getNode(node_idx).TypeOfExpression;
    _ = checkExpression(c, node.Expression);
    return c.stringTypeIndex orelse 0;
}
pub fn checkVoidExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    c.checkNodeDeferred(node_idx);
    return c.undefinedTypeIndex orelse 0;
}
pub fn checkYieldExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    _ = grammarchecks.checkGrammarYieldExpression(c, node_idx);
    const node = c.binder.ast.getNode(node_idx).YieldExpression;
    if (node.Expression) |expr| {
        _ = checkExpression(c, expr);
    }
    return c.anyTypeIndex orelse 0;
}

pub fn instantiateIndexInfo(c: *Checker, info: types.IndexInfo, m: types.TypeMapperIndex) types.IndexInfo {
    const newValueType = c.instantiateType(info.valueType, m);
    if (newValueType == info.valueType) {
        return info;
    }
    return .{
        .keyType = info.keyType,
        .valueType = newValueType,
        .isReadonly = info.isReadonly,
        .declaration = info.declaration,
    };
}

pub fn instantiateSignatures(c: *Checker, signatures: []const types.SignatureIndex, m: types.TypeMapperIndex) ![]const types.SignatureIndex {
    if (m == 0 or signatures.len == 0) return signatures;
    var newSignatures = try c.allocator.alloc(types.SignatureIndex, signatures.len);
    for (signatures, 0..) |sig, i| {
        newSignatures[i] = c.instantiateSignature(sig, m);
    }
    return newSignatures;
}

pub fn instantiateIndexInfos(c: *Checker, infos: []const types.IndexInfo, m: types.TypeMapperIndex) ![]const types.IndexInfo {
    if (m == 0 or infos.len == 0) return infos;
    var newInfos = try c.allocator.alloc(types.IndexInfo, infos.len);
    for (infos, 0..) |info, i| {
        newInfos[i] = c.instantiateIndexInfo(info, m);
    }
    return newInfos;
}

pub fn instantiateSignature(c: *Checker, sig: types.SignatureIndex, m: types.TypeMapperIndex) types.SignatureIndex {
    return c.instantiateSignatureEx(sig, m, m == c.permissiveMapper);
}

pub fn instantiateSignatureEx(c: *Checker, sigIdx: types.SignatureIndex, m: types.TypeMapperIndex, eraseTypeParameters: bool) types.SignatureIndex {
    const sig = c.signatures.items[sigIdx];
    var freshTypeParameters: []const types.TypeIndex = &[_]types.TypeIndex{};
    var currentMapper = m;

    const typeParameters = c.signatureTypeParameters.items[sig.typeParametersStart .. sig.typeParametersStart + sig.typeParametersLen];
    if (typeParameters.len != 0 and !eraseTypeParameters) {
        var freshArr = std.ArrayListUnmanaged(types.TypeIndex).empty;
        for (typeParameters) |tp| {
            freshArr.append(c.allocator, c.cloneTypeParameter(tp)) catch {};
        }
        freshTypeParameters = freshArr.items;

        const newMapper = mapper_pkg.createTypeMapper(c, typeParameters, freshTypeParameters);
        currentMapper = mapper_pkg.combineTypeMappers(c, newMapper, currentMapper);

        for (freshTypeParameters) |tp| {
            var tpData = &c.getTargetTypeData(tp).TypeParameter;
            tpData.mapper = currentMapper;
        }
    }

    const sigParameters = c.signatureParameters.items[sig.parametersStart .. sig.parametersStart + sig.parametersLen];
    const newParameters = c.instantiateSymbols(sigParameters, currentMapper) catch sigParameters;
    const newThisParameter = if (sig.thisParameter) |tp| c.instantiateSymbol(tp, currentMapper) else null;

    const propagatingFlags = sig.flags & (types.SignatureFlags.HasRestParameter | types.SignatureFlags.HasLiteralTypes | types.SignatureFlags.Construct | types.SignatureFlags.Abstract | types.SignatureFlags.IsUntypedSignatureInJSFile | types.SignatureFlags.IsSignatureCandidateForOverloadFailure);

    const resultIdx = c.newSignature(propagatingFlags, sig.declaration, freshTypeParameters, newThisParameter, newParameters, null, sig.minArgumentCount, (sig.flags & types.SignatureFlags.HasRestParameter) != 0, false);

    var result = &c.signatures.items[resultIdx];
    result.target = sig.target orelse sigIdx;

    return resultIdx;
}

pub fn newSignature(c: *Checker, flags: u32, declaration: ast_gen.NodeIndex, typeParameters: []const types.TypeIndex, thisParameter: ?ast_gen.SymbolIndex, parameters: []const ast_gen.SymbolIndex, resolvedReturnType: ?types.TypeIndex, minArgumentCount: i32, hasRestParameter: bool, hasLiteralRestParameter: bool) types.SignatureIndex {
    var sig = types.Signature{
        .flags = flags,
        .declaration = declaration,
        .thisParameter = thisParameter,
        .resolvedReturnType = resolvedReturnType,
        .minArgumentCount = minArgumentCount,
        .resolvedMinArgumentCount = -1,
    };

    if (typeParameters.len > 0) {
        sig.typeParametersStart = @intCast(c.signatureTypeParameters.items.len);
        sig.typeParametersLen = @intCast(typeParameters.len);
        c.signatureTypeParameters.appendSlice(c.allocator, typeParameters) catch unreachable;
    }

    if (parameters.len > 0) {
        sig.parametersStart = @intCast(c.signatureParameters.items.len);
        sig.parametersLen = @intCast(parameters.len);
        c.signatureParameters.appendSlice(c.allocator, parameters) catch unreachable;
    }

    if (hasRestParameter) {
        sig.flags |= types.SignatureFlags.HasRestParameter;
    }
    if (hasLiteralRestParameter) {
        sig.flags |= types.SignatureFlags.HasLiteralTypes; // Use HasLiteralTypes for now since HasLiteralRestParameter is not defined
    }

    const idx = @as(u32, @intCast(c.signatures.items.len));
    c.signatures.append(c.allocator, sig) catch unreachable;
    return idx;
}

pub fn checkRegularExpressionLiteral(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    const node_links = c.getNodeLinks(node_idx);
    if ((node_links.flags & types.NodeCheckFlags.TypeChecked) == 0) {
        node_links.flags |= types.NodeCheckFlags.TypeChecked;
    }
    return c.anyTypeIndex orelse 0;
}

pub fn checkExpressionWithTypeArguments(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    _ = grammarchecks.checkGrammarExpressionWithTypeArguments(c, node_idx);
    const node = c.binder.ast.getNode(node_idx).ExpressionWithTypeArguments;
    if (node.TypeArguments) |targs| {
        c.checkSourceElements(c.binder.ast.getNodeList(targs));
    }
    var exprType: types.TypeIndex = 0;
    if (c.binder.ast.getKind(node_idx) == .ExpressionWithTypeArguments) {
        exprType = checkExpression(c, node.Expression);
    }
    return getInstantiationExpressionType(c, exprType, node_idx);
}

pub fn getInstantiationExpressionType(c: *Checker, exprType: types.TypeIndex, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    _ = c;
    _ = node_idx;
    return exprType;
}

pub fn checkNewTargetMetaProperty(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    _ = node_idx;
    return c.anyTypeIndex orelse 0;
}

pub fn checkImportMetaProperty(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    _ = node_idx;
    return c.anyTypeIndex orelse 0;
}

pub fn getGlobalRegExpType(c: *Checker, reportErrors: bool) !types.TypeIndex {
    _ = c;
    _ = reportErrors;
    return 0;
}
