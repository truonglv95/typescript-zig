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

    numberLiteralTypes: std.AutoHashMapUnmanaged(f64, types.TypeIndex) = .empty,
    stringLiteralTypes: std.StringHashMapUnmanaged(types.TypeIndex) = .empty,
    unresolvedSymbols: std.StringHashMapUnmanaged(ast_gen.SymbolIndex) = .empty,

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
    currentNode: ast_gen.NodeIndex = 0,
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
            const mapped_node = c.ast.getNode(decl).MappedType;
            if (mapped_node.TypeParameter) |tp_idx| {
                const tp_node = c.ast.getNode(tp_idx).TypeParameter;
                if (tp_node.Constraint) |constraint_idx| {
                    const type_node = c.ast.getNode(constraint_idx).TypeOperator.Type; // KeyOfKeyword's Type
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

        if (c.numberLiteralTypes.get(value)) |cached_t| {
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
        c.numberLiteralTypes.put(c.allocator, value, t) catch {};
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
        _ = c;
        _ = t;
        return false; // Skipped
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

    pub fn getGlobalSymbol(c: *Checker, name: []const u8, meaning: u32, diagnostic: ?*const diagnostics.Message) ast_gen.SymbolIndex {
        return resolveName(c, 0, name, meaning, diagnostic, false, false);
    }

    pub fn resolveSymbol(c: *Checker, symbolIdx: ast_gen.SymbolIndex) ast_gen.SymbolIndex {
        return c.resolveSymbolEx(symbolIdx, false);
    }

    pub fn resolveSymbolEx(c: *Checker, symbolIdx: ast_gen.SymbolIndex, dontResolveAlias: bool) ast_gen.SymbolIndex {
        if (!dontResolveAlias and ast_utils.isNonLocalAlias(c.binder.ast, symbolIdx, symbol.SymbolFlags.Value | symbol.SymbolFlags.Type | symbol.SymbolFlags.Namespace)) {
            return c.resolveAlias(symbolIdx);
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
        var targetData = &c.typesList.items[target].data.Object;

        if (targetData.instantiations != null) {
            if (targetData.instantiations.?.get(id)) |t| {
                return t;
            }
        }

        const newFlags = types.ObjectFlags.Reference | objectFlags | c.getPropagatingFlagsOfTypes(typeArguments, types.TypeFlags.None);
        const t = try c.createType(.{ .flags = types.TypeFlags.Object, .objectFlags = newFlags, .symbol = c.typesList.items[target].symbol, .data = .{ .Object = .{
            .target = target,
        } } });

        var d = &c.typesList.items[t].data.Object;

        // Save type arguments into c.typeArgumentsPool
        const typeArgsStart = @as(u32, @intCast(c.typeArgumentsPool.items.len));
        try c.typeArgumentsPool.appendSlice(c.allocator, typeArguments);
        d.typeArgumentsStart = typeArgsStart;
        d.typeArgumentsLen = @as(u32, @intCast(typeArguments.len));

        // Note: instantiations map should be updated on the original target, not targetData directly because targetData is a copy of the pointer, wait: targetData is a pointer to the element in array list.
        // It's safer to re-fetch the pointer after any allocator calls!
        var actualTargetData = &c.typesList.items[target].data.Object;
        if (actualTargetData.instantiations == null) {
            actualTargetData.instantiations = std.AutoHashMapUnmanaged(types.CacheHashKey, types.TypeIndex){};
        }
        try actualTargetData.instantiations.?.put(c.allocator, id, t);

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

    pub fn getTupleTargetType(c: *Checker, elementInfos: []const types.TupleElementInfo, readonly: bool) types.TypeIndex {
        _ = c;
        _ = elementInfos;
        _ = readonly;
        // TODO: implement
        return 0; // c.emptyGenericTypeIndex once we expose it properly
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

    pub fn getTailRecursionRoot(c: *Checker, newType: types.TypeIndex, newMapper: types.TypeMapperIndex) TailRecursionRootResult {
        if (c.getTypeFlags(newType) & types.TypeFlags.Conditional != 0 and newMapper != 0) {
            const condData = &c.typesList.items[newType].data.Conditional;
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
                pub fn f(inner_c: *Checker, t: types.TypeIndex, _: void) bool {
                    return inner_c.isArrayOrTupleType(t);
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
            const new_type = types.Type{
                .flags = types.TypeFlags.Object,
                .objectFlags = types.ObjectFlags.EvolvingArray,
                .data = .{
                    .Object = .{
                        .evolvingArrayElementType = elementType,
                    },
                },
            };
            entry.value_ptr.* = c.createType(new_type) catch c.errorType;
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

    pub fn getResolvedSignature(c: *Checker, node: ast_gen.NodeIndex, candidatesOutArray: ?*std.ArrayListUnmanaged(types.SignatureIndex), checkMode: u32) types.SignatureIndex {
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
};

fn containsTypeIndex(items: []const types.TypeIndex, needle: types.TypeIndex) bool {
    for (items) |item| if (item == needle) return true;
    return false;
}

pub fn resolveName(c: *Checker, location: ?ast_gen.NodeIndex, name: []const u8, meaning: u32, nameNotFoundMessage: ?*const diagnostics.Message, isUse: bool, excludeGlobals: bool) ast_gen.SymbolIndex {
    return c.resolver.resolve(location orelse 0, name, meaning, nameNotFoundMessage, isUse, excludeGlobals) orelse c.unknownSymbol;
}

pub fn getResolvedSymbol(c: *Checker, node: ast_gen.NodeIndex) ast_gen.SymbolIndex {
    var links = c.symbolNodeLinks.get(node) orelse types.SymbolNodeLinks{};
    if (links.resolvedSymbol == 0) {
        var sym: ast_gen.SymbolIndex = 0;
        if (!ast_utils.nodeIsMissing(c.binder.ast, node)) {
            const name = ast_utils.getTextOfNode(c.binder.ast, node);
            sym = resolveName(c, node, name, symbol.SymbolFlags.Value | symbol.SymbolFlags.ExportValue, null, !ast_utils.isWriteOnlyAccess(c.binder.ast, node), false);
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
            c.checkSourceElement(node.ParenthesizedType.Type);
        },
        .OptionalType => {
            c.checkSourceElement(node.OptionalType.Type);
        },
        .RestType => {
            c.checkSourceElement(node.RestType.Type);
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
        c.checkSourceElement(t);
    }
    if (body) |b| {
        c.checkSourceElement(b);
    }
}
pub fn checkArrayType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).ArrayType;
    c.checkSourceElement(node.ElementType);
}
pub fn checkBindingElement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).BindingElement;
    if (node.Initializer) |init| {
        _ = checkExpression(c, init);
    }
}
pub fn checkBlock(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const stmts = c.binder.ast.nodes.get(node_idx).Block.Statements;
    const list = c.binder.ast.nodes.get(stmts).NodeList;
    var iter = c.binder.ast.nodeListIter(list);
    while (iter.next()) |stmt_idx| {
        c.checkSourceElement(stmt_idx);
    }
}
pub fn checkBreakOrContinueStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    _ = c;
    _ = node_idx;
}
pub fn checkClassDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const cd = c.binder.ast.nodes.get(node_idx).ClassDeclaration;
    if (cd.Members != 0) {
        const members = c.binder.ast.getNodeList(cd.Members);
        for (members) |mem| {
            c.checkSourceElement(mem);
        }
    }
}
pub fn checkClassStaticBlockDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).ClassStaticBlockDeclaration;
    c.checkSourceElement(node.Body);
}
pub fn checkConditionalType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).ConditionalType;
    c.checkSourceElement(node.CheckType);
    c.checkSourceElement(node.ExtendsType);
    c.checkSourceElement(node.TrueType);
    c.checkSourceElement(node.FalseType);
}
pub fn checkConstructorDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const ctor = c.binder.ast.nodes.get(node_idx).Constructor;
    if (ctor.Parameters != 0) checkFunctionParameters(c, ctor.Parameters);
    if (ctor.Body != 0) {
        c.checkSourceElement(ctor.Body);
    }
}
pub fn checkDoStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).DoStatement;
    c.checkStatement(node.Statement);
    _ = checkExpression(c, node.Condition);
}
pub fn checkEnumDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).EnumDeclaration;
    const members = c.binder.ast.getNode(node.Members).NodeList;
    var iter = c.binder.ast.nodeListIter(members);
    while (iter.next()) |mem_idx| {
        c.checkSourceElement(mem_idx);
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
        c.checkSourceElement(clause);
    }
}
pub fn checkExpressionStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const expr = c.binder.ast.nodes.get(node_idx).ExpressionStatement.Expression;
    _ = c.checkExpression(expr);
}
pub fn checkForInStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).ForInStatement;
    if (c.binder.ast.getKind(node.Initializer) == .VariableDeclarationList) {
        checkVariableDeclarationList(c, node.Initializer);
    } else {
        _ = checkExpression(c, node.Initializer);
    }
    _ = checkExpression(c, node.Expression);
    c.checkStatement(node.Statement);
}
pub fn checkForOfStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).ForOfStatement;
    if (c.binder.ast.getKind(node.Initializer) == .VariableDeclarationList) {
        checkVariableDeclarationList(c, node.Initializer);
    } else {
        _ = checkExpression(c, node.Initializer);
    }
    _ = checkExpression(c, node.Expression);
    c.checkStatement(node.Statement);
}
pub fn checkForStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).ForStatement;
    if (node.Initializer) |init| {
        if (c.binder.ast.getKind(init) == .VariableDeclarationList) {
            checkVariableDeclarationList(c, init);
        } else {
            _ = checkExpression(c, init);
        }
    }
    if (node.Condition) |cond| {
        _ = checkExpression(c, cond);
    }
    if (node.Incrementor) |incr| {
        _ = checkExpression(c, incr);
    }
    c.checkStatement(node.Statement);
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
    if (f.Body != 0) {
        c.checkSourceElement(f.Body);
    }
    if (f.Parameters != 0) checkFunctionParameters(c, f.Parameters);
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
    _ = checkExpression(c, node.Expression);
    c.checkStatement(node.ThenStatement);
    if (node.ElseStatement) |else_stmt| {
        c.checkStatement(else_stmt);
    }
}
pub fn checkImportDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).ImportDeclaration;
    if (node.ImportClause) |clause| {
        c.checkSourceElement(clause);
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
    const node = c.binder.ast.getNode(node_idx).ImportTypeNode;
    c.checkSourceElement(node.Argument);
}
pub fn checkIndexedAccessType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).IndexedAccessType;
    c.checkSourceElement(node.ObjectType);
    c.checkSourceElement(node.IndexType);
}
pub fn checkInferType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).InferType;
    c.checkSourceElement(node.TypeParameter);
}
pub fn checkInterfaceDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).InterfaceDeclaration;
    if (node.TypeParameters) |tps| {
        checkTypeParameters(c, tps);
    }
    const members = c.binder.ast.getNode(node.Members).NodeList;
    var iter = c.binder.ast.nodeListIter(members);
    while (iter.next()) |mem_idx| {
        c.checkSourceElement(mem_idx);
    }
}
pub fn checkJSDocType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    _ = c;
    _ = node_idx;
}
pub fn checkLabeledStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).LabeledStatement;
    c.checkSourceElement(node.Statement);
}
pub fn checkMappedType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).MappedType;
    c.checkSourceElement(node.TypeParameter);
    if (node.NameType) |name_type| {
        c.checkSourceElement(name_type);
    }
    if (node.Type) |type_idx| {
        c.checkSourceElement(type_idx);
    }
}
pub fn checkMethodDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const method = c.binder.ast.nodes.get(node_idx).MethodDeclaration;
    if (method.Parameters != 0) checkFunctionParameters(c, method.Parameters);
    if (method.Body != 0) {
        c.checkSourceElement(method.Body);
    }
}
pub fn checkMissingDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    _ = c;
    _ = node_idx;
}
pub fn checkModuleDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).ModuleDeclaration;
    if (node.Body) |body| {
        c.checkSourceElement(body);
    }
}
pub fn checkNamedTupleMember(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).NamedTupleMember;
    c.checkSourceElement(node.Type);
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
        c.checkSourceElement(type_idx);
    }
}
pub fn checkPropertySignature(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).PropertySignature;
    if (node.Initializer) |init| {
        _ = checkExpression(c, init);
    }
    if (node.Type) |type_idx| {
        c.checkSourceElement(type_idx);
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
        c.checkSourceElement(t);
    }
}
pub fn checkSwitchStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).SwitchStatement;
    _ = checkExpression(c, node.Expression);
    const caseBlock = c.binder.ast.getNode(node.CaseBlock).CaseBlock;
    const clauses = c.binder.ast.getNode(caseBlock.Clauses).NodeList;
    var iter = c.binder.ast.nodeListIter(clauses);
    while (iter.next()) |clause_idx| {
        const clause_kind = c.binder.ast.getKind(clause_idx);
        if (clause_kind == .CaseClause) {
            const clause = c.binder.ast.getNode(clause_idx).CaseClause;
            _ = checkExpression(c, clause.Expression);
            const stmts = c.binder.ast.getNode(clause.Statements).NodeList;
            var stmt_iter = c.binder.ast.nodeListIter(stmts);
            while (stmt_iter.next()) |stmt_idx| {
                c.checkSourceElement(stmt_idx);
            }
        } else if (clause_kind == .DefaultClause) {
            const clause = c.binder.ast.getNode(clause_idx).DefaultClause;
            const stmts = c.binder.ast.getNode(clause.Statements).NodeList;
            var stmt_iter = c.binder.ast.nodeListIter(stmts);
            while (stmt_iter.next()) |stmt_idx| {
                c.checkSourceElement(stmt_idx);
            }
        }
    }
}
pub fn checkTemplateLiteralType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).TemplateLiteralType;
    const template_spans = c.binder.ast.getNode(node.TemplateSpans).NodeList;
    var iter = c.binder.ast.nodeListIter(template_spans);
    while (iter.next()) |span_idx| {
        const span = c.binder.ast.getNode(span_idx).TemplateLiteralTypeSpan;
        c.checkSourceElement(span.Type);
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
    checkBlock(c, node.Block);
}
pub fn checkTupleType(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).TupleType;
    const elements = c.binder.ast.getNode(node.Elements).NodeList;
    var iter = c.binder.ast.nodeListIter(elements);
    while (iter.next()) |el_idx| {
        c.checkSourceElement(el_idx);
    }
}
pub fn checkTypeAliasDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).TypeAliasDeclaration;
    if (node.TypeParameters) |tps| {
        checkTypeParameters(c, tps);
    }
    c.checkSourceElement(node.Type);
}
pub fn checkTypeLiteral(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).TypeLiteral;
    const members = c.binder.ast.getNode(node.Members).NodeList;
    var iter = c.binder.ast.nodeListIter(members);
    while (iter.next()) |mem_idx| {
        c.checkSourceElement(mem_idx);
    }
}
pub fn checkTypeOperator(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).TypeOperator;
    c.checkSourceElement(node.Type);
}
pub fn checkTypeParameter(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).TypeParameter;
    if (node.Constraint) |constraint| c.checkSourceElement(constraint);
    if (node.DefaultType) |def| c.checkSourceElement(def);
}
pub fn checkTypeParameters(c: *Checker, list_idx: ast_gen.NodeIndex) void {
    const list = c.binder.ast.getNode(list_idx).NodeList;
    var iter = c.binder.ast.nodeListIter(list);
    while (iter.next()) |idx| {
        checkTypeParameter(c, idx);
    }
}
pub fn checkTypePredicate(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).TypePredicate;
    if (node.Type) |type_idx| {
        c.checkSourceElement(type_idx);
    }
}
pub fn checkTypeQuery(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    _ = c.getTypeOfNode(node_idx) catch return;
}
pub fn checkTypeReferenceNode(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).TypeReference;
    if (node.TypeArguments) |args| {
        const type_args = c.binder.ast.getNode(args).NodeList;
        var iter = c.binder.ast.nodeListIter(type_args);
        while (iter.next()) |arg_idx| {
            c.checkSourceElement(arg_idx);
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
    const type_nodes = c.binder.ast.getNode(types_list).NodeList;
    var iter = c.binder.ast.nodeListIter(type_nodes);
    while (iter.next()) |t_idx| {
        c.checkSourceElement(t_idx);
    }
}
pub fn checkVariableDeclaration(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const decl = c.binder.ast.nodes.get(node_idx).VariableDeclaration;
    if (decl.Initializer != 0) {
        _ = c.checkExpression(decl.Initializer);
        if (decl.Type) |typeNode| {
            const declaredType = type_resolution_pkg.getTypeFromTypeNode(c, typeNode);
            if (declaredType != 0) {
                _ = c.reportExcessPropertyForObjectLiteralUnionAssignment(decl.Initializer, declaredType);
            }
        }
    }
}
pub fn checkVariableStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const list = c.binder.ast.nodes.get(node_idx).VariableStatement.DeclarationList;
    if (list != 0) {
        c.checkSourceElement(list);
    }
}
pub fn checkVariableDeclarationList(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const declarations = c.binder.ast.nodes.get(node_idx).VariableDeclarationList.Declarations;
    const list = c.binder.ast.nodes.get(declarations).NodeList;
    var iter = c.binder.ast.nodeListIter(list);
    while (iter.next()) |decl_idx| {
        c.checkSourceElement(decl_idx);
    }
}
pub fn checkWhileStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).WhileStatement;
    _ = checkExpression(c, node.Condition);
    c.checkStatement(node.Statement);
}
pub fn checkPropertyAssignment(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const pa = c.binder.ast.nodes.get(node_idx).PropertyAssignment;
    if (pa.Initializer != 0) {
        _ = c.checkExpression(pa.Initializer);
    }
}
pub fn checkShorthandPropertyAssignment(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const spa = c.binder.ast.nodes.get(node_idx).ShorthandPropertyAssignment;
    if (spa.ObjectAssignmentInitializer != 0) {
        _ = c.checkExpression(spa.ObjectAssignmentInitializer);
    }
}
pub fn checkWithStatement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    const node = c.binder.ast.getNode(node_idx).WithStatement;
    _ = checkExpression(c, node.Expression);
    c.checkStatement(node.Statement);
}

pub fn checkExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    return checkExpressionEx(c, node_idx, CheckMode.Normal);
}

pub fn checkExpressionEx(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    return checkExpressionWorker(c, node_idx, checkMode);
}

pub fn checkSourceElement(c: *Checker, node_idx: ast_gen.NodeIndex) void {
    if (node_idx != 0) {
        checkSourceElementWorker(c, node_idx);
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
            return c.nullWideningType orelse 0;
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
            return c.getGlobalRegExpType(true) catch (c.anyTypeIndex orelse 0);
        },
        .ArrayLiteralExpression => {
            return checkArrayLiteral(c, node_idx, checkMode, null);
        },
        .ObjectLiteralExpression => {
            return checkObjectLiteral(c, node_idx, checkMode);
        },
        .PropertyAccessExpression => {
            return checkPropertyAccessExpression(c, node_idx);
        },
        .ElementAccessExpression => {
            return checkElementAccessExpression(c, node_idx);
        },
        .CallExpression => {
            return checkCallExpression(c, node_idx);
        },
        .NewExpression => {
            return checkNewExpression(c, node_idx);
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
            return checkPrefixUnaryExpression(c, node_idx);
        },
        .PostfixUnaryExpression => {
            return checkPostfixUnaryExpression(c, node_idx);
        },
        .BinaryExpression => {
            return checkBinaryExpression(c, node_idx, checkMode);
        },
        .ConditionalExpression => {
            return checkConditionalExpression(c, node_idx, checkMode);
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
        .CommaListExpression => {
            return checkCommaListExpression(c, node_idx);
        },
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
    _ = node_idx;
    _ = checkMode;
    _ = arg4;
    return c.anyTypeIndex orelse 0;
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
    return checkExpression(c, node.Expression);
}
pub fn checkBigIntLiteral(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    _ = node_idx;
    _ = checkMode;
    return c.anyTypeIndex orelse 0;
}
pub fn checkBinaryExpression(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    _ = checkMode;
    return c.checkExpressionAdHoc(node_idx) catch c.anyTypeIndex orelse 0;
}
pub fn checkCallExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    return c.checkExpressionAdHoc(node_idx) catch c.anyTypeIndex orelse 0;
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
    const node = c.binder.ast.getNode(node_idx).ConditionalExpression;
    _ = checkExpression(c, node.Condition);
    const t1 = checkExpressionEx(c, node.WhenTrue, checkMode);
    const t2 = checkExpressionEx(c, node.WhenFalse, checkMode);
    return c.getUnionTypeFromArray(&[_]types.TypeIndex{ t1, t2 });
}
pub fn checkDeleteExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    const node = c.binder.ast.getNode(node_idx).DeleteExpression;
    _ = checkExpression(c, node.Expression);
    return c.booleanTypeIndex orelse 0;
}
pub fn checkElementAccessExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    const node = c.binder.ast.getNode(node_idx).ElementAccessExpression;
    const objectType = checkExpression(c, node.Expression);
    const indexType = checkExpression(c, node.ArgumentExpression);
    return c.getIndexedAccessType(objectType, indexType);
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
            if (f.Body) |body| c.checkSourceElement(body);
        },
        .ArrowFunction => |f| {
            if (f.Body) |body| c.checkStatementAdHoc(body) catch {};
        },
        .MethodDeclaration => |m| {
            if (m.Body) |body| c.checkSourceElement(body);
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
    _ = node_idx;
    return c.anyTypeIndex orelse 0;
}
pub fn checkNewExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    _ = node_idx;
    return c.anyTypeIndex orelse 0;
}
pub fn checkNonNullExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    const expr = c.binder.ast.getNode(node_idx).NonNullExpression;
    return checkExpression(c, expr.Expression);
}
pub fn checkNumericLiteral(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    _ = checkMode;
    const n = c.binder.ast.getNode(node_idx).NumericLiteral;
    const value = std.fmt.parseFloat(f64, n.Text) catch 0.0;
    return c.getFreshTypeOfLiteralType(c.getNumberLiteralType(value));
}
pub fn checkObjectLiteral(c: *Checker, node_idx: ast_gen.NodeIndex, checkMode: CheckMode) types.TypeIndex {
    std.debug.print("checkObjectLiteral\n", .{});
    _ = checkMode;
    const properties = c.binder.ast.nodes.get(node_idx).ObjectLiteralExpression.Properties;
    const prop_list = c.binder.ast.nodes.get(properties).NodeList;

    // Just typecheck properties so nested statements get checked
    var iter = c.binder.ast.nodeListIter(prop_list);
    while (iter.next()) |prop_idx| {
        c.checkSourceElement(prop_idx);
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
pub fn checkPostfixUnaryExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    const expr = c.binder.ast.getNode(node_idx).PostfixUnaryExpression;
    _ = checkExpression(c, expr.Operand);
    return c.numberTypeIndex orelse 0;
}
pub fn checkPrefixUnaryExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    const expr = c.binder.ast.getNode(node_idx).PrefixUnaryExpression;
    _ = checkExpression(c, expr.Operand);

    const operandKind = c.binder.ast.getKind(expr.Operand);
    if (operandKind == .NumericLiteral) {
        if (expr.Operator == .MinusToken) {
            const text = c.binder.ast.getNode(expr.Operand).NumericLiteral.Text;
            const value = std.fmt.parseFloat(f64, text) catch 0.0;
            return c.getFreshTypeOfLiteralType(c.getNumberLiteralType(-value));
        } else if (expr.Operator == .PlusToken) {
            const text = c.binder.ast.getNode(expr.Operand).NumericLiteral.Text;
            const value = std.fmt.parseFloat(f64, text) catch 0.0;
            return c.getFreshTypeOfLiteralType(c.getNumberLiteralType(value));
        }
    }

    switch (expr.Operator) {
        .PlusToken, .MinusToken, .TildeToken => return c.numberTypeIndex orelse 0,
        .ExclamationToken => return c.booleanTypeIndex orelse 0,
        .PlusPlusToken, .MinusMinusToken => return c.numberTypeIndex orelse 0,
        else => return c.anyTypeIndex orelse 0,
    }
}
pub fn checkPrivateIdentifierExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    _ = node_idx;
    return c.anyTypeIndex orelse 0;
}
pub fn checkPropertyAccessExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    const expr_idx = c.binder.ast.nodes.get(node_idx).PropertyAccessExpression.Expression;
    const name_idx = c.binder.ast.nodes.get(node_idx).PropertyAccessExpression.name;

    const leftType = c.checkExpression(expr_idx);
    const apparentType = c.getApparentType(leftType);
    if (isTypeAnyLike(c, apparentType)) return c.anyTypeIndex orelse 0;

    const rightName = c.binder.ast.nodes.get(name_idx).Identifier.Text;
    const prop = c.getPropertyOfType(apparentType, rightName);

    if (prop) |p| {
        return c.getTypeOfSymbol(p) catch c.anyTypeIndex orelse 0;
    }

    var indexInfo: ?types.IndexInfo = null;
    const assignmentKind = utils.getAssignmentTargetKind(c.binder.ast, node_idx);
    if (assignmentKind == .None or !c.isGenericObjectType(leftType) or utils.isThisTypeParameter(c, leftType)) {
        const keyType = if (utils.isNumericLiteralName(rightName)) c.numberTypeIndex orelse 0 else c.stringTypeIndex orelse 0;
        indexInfo = c.getIndexInfoOfType(apparentType, keyType);
    }

    if (indexInfo == null) {
        if (utils.isJSLiteralType(c, c.getType(leftType))) {
            return c.anyTypeIndex orelse 0;
        }

        if (rightName.len > 0 and shouldReportMissingPropertyError(c, leftType, assignmentKind)) {
            const typeStr = c.typeToString(leftType);
            c.addError(name_idx, diagnostics.Property_0_does_not_exist_on_type_1, .{
                c.allocString(rightName), c.allocString(typeStr),
            });
        }
        return c.errorTypeIndex orelse 0;
    }
    return indexInfo.?.type;
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
    _ = node_idx;
    return c.anyTypeIndex orelse 0;
}
pub fn checkTemplateExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
    const node = c.binder.ast.getNode(node_idx).TemplateExpression;
    var iter = c.binder.ast.nodeListIter(node.TemplateSpans);
    while (iter.next()) |span_idx| {
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
    const node = c.binder.ast.getNode(node_idx).VoidExpression;
    _ = checkExpression(c, node.Expression);
    return c.undefinedTypeIndex orelse 0;
}
pub fn checkYieldExpression(c: *Checker, node_idx: ast_gen.NodeIndex) types.TypeIndex {
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
