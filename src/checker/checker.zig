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
const printer_pkg = @import("../printer/printer.zig");
const textwriter_pkg = @import("../printer/textwriter.zig");
const emitcontext_pkg = @import("../printer/emitcontext.zig");

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
    typeArgumentsPool: std.ArrayListUnmanaged(types.TypeIndex) = .empty,

    // Flow analysis state
    freeFlowState: ?*flow.FlowState = null,
    flowAnalysisDisabled: bool = false,
    flowInvocationCount: usize = 0,
    sharedFlows: std.ArrayListUnmanaged(flow.SharedFlow) = .empty,
    antecedentTypes: std.ArrayListUnmanaged(types.TypeIndex) = .empty,
    nodeFlowNodes: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, ast_flow.FlowNodeIndex) = .empty,
    symbolContainerLinks: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, types.ContainingSymbolLinks) = .empty,

    // Pools for resolved members
    resolvedPropertiesPool: std.ArrayListUnmanaged(ast_gen.SymbolIndex) = .empty,
    resolvedSignaturesPool: std.ArrayListUnmanaged(types.SignatureIndex) = .empty,
    resolvedIndexInfosPool: std.ArrayListUnmanaged(types.IndexInfo) = .empty,
    resolvedStructuredTypeMembers: std.AutoHashMapUnmanaged(types.TypeIndex, types.StructuredTypeMembers) = .empty,
    resolvedDeclaredMembers: std.AutoHashMapUnmanaged(types.TypeIndex, types.StructuredTypeMembers) = .empty,
    resolvedUnionOrIntersectionProperties: std.AutoHashMapUnmanaged(types.TypeIndex, types.Range) = .empty,

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
    inlineLevel: u32 = 0,
    serializationLevel: u32 = 0,

    // Cache for intrinsic types to avoid duplicates
    numberTypeIndex: ?u32 = null,
    anyTypeIndex: ?u32 = null,
    noConstraintTypeIndex: ?u32 = null,
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
    circularConstraintTypeIndex: ?u32 = null,

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
    ownedDiagnosticArgs: std.ArrayListUnmanaged([]const []const u8) = .empty,

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
        if (self.typeToStringNodebuilder) |builder_instance| {
            builder_instance.ctxStack.deinit(self.allocator);
            builder_instance.impl.deinit();
            self.allocator.destroy(builder_instance.impl);
            self.allocator.destroy(builder_instance);
            self.typeToStringNodebuilder = null;
        }
        for (self.ownedDiagnosticArgs.items) |args| self.allocator.free(args);
        self.ownedDiagnosticArgs.deinit(self.allocator);
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

    pub fn resolveStructuredTypeMembers(c: *Checker, t: types.TypeIndex) types.StructuredTypeMembers {
        if (c.resolvedStructuredTypeMembers.get(t)) |members| {
            return members;
        }

        var members = types.StructuredTypeMembers{};
        const flags = c.typesList.items[t].flags;
        if (flags & types.TypeFlags.Object != 0) {
            const objectFlags = c.typesList.items[t].objectFlags;
            if (objectFlags & types.ObjectFlags.Reference != 0) {
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
            // TODO: check if t == globalFunctionType and return unknownSignature
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
        // TODO: if len == 0, callSignatures = c.getArrayMemberCallSignatures(t)
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

        // TODO: findMixins
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
            _ = i;
            // TODO: implement isFunctionLike check
            // TODO: implement overload implementation check

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
                    // TODO: literal types flag
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
        _ = c;
        _ = symIdx;
        return 0; // Stub
    }

    pub fn getSignaturesOfType(c: *Checker, t: types.TypeIndex, sigKind: types.SignatureKind) types.Range {
        const typeData = &c.typesList.items[t];
        if (typeData.flags & types.TypeFlags.StructuredType == 0) {
            return .{ .start = 0, .len = 0 };
        }

        // TODO: getReducedApparentType
        const resolved = c.resolveStructuredTypeMembers(t);
        if (sigKind == .Call) {
            return .{ .start = resolved.callSignaturesStart, .len = resolved.callSignaturesLen };
        }
        return .{ .start = resolved.constructSignaturesStart, .len = resolved.constructSignaturesLen };
    }

    pub fn appendSignatures(c: *Checker, signaturesStart: u32, signaturesLen: u32, newSignaturesStart: u32, newSignaturesLen: u32) types.Range {
        if (signaturesLen == 0) return .{ .start = newSignaturesStart, .len = newSignaturesLen };
        if (newSignaturesLen == 0) return .{ .start = signaturesStart, .len = signaturesLen };

        // TODO: deduplication using compareSignaturesIdentical
        const mergedStart = @as(u32, @intCast(c.resolvedSignaturesPool.items.len));

        for (0..signaturesLen) |i| {
            c.resolvedSignaturesPool.append(c.allocator, c.resolvedSignaturesPool.items[signaturesStart + i]) catch {};
        }
        for (0..newSignaturesLen) |i| {
            c.resolvedSignaturesPool.append(c.allocator, c.resolvedSignaturesPool.items[newSignaturesStart + i]) catch {};
        }

        return .{ .start = mergedStart, .len = signaturesLen + newSignaturesLen };
    }

    pub fn appendIndexInfo(c: *Checker, indexInfosStart: u32, indexInfosLen: u32, newInfo: types.IndexInfo, isUnion: bool) types.Range {
        _ = isUnion;
        if (indexInfosLen == 0) {
            const start = @as(u32, @intCast(c.resolvedIndexInfosPool.items.len));
            c.resolvedIndexInfosPool.append(c.allocator, newInfo) catch {};
            return .{ .start = start, .len = 1 };
        }

        // TODO: properly merge index infos (dedupe/intersect)
        const mergedStart = @as(u32, @intCast(c.resolvedIndexInfosPool.items.len));
        for (0..indexInfosLen) |i| {
            c.resolvedIndexInfosPool.append(c.allocator, c.resolvedIndexInfosPool.items[indexInfosStart + i]) catch {};
        }
        c.resolvedIndexInfosPool.append(c.allocator, newInfo) catch {};
        return .{ .start = mergedStart, .len = indexInfosLen + 1 };
    }

    pub fn getIndexInfosOfIndexSymbol(c: *Checker, symIdx: ast_gen.SymbolIndex, propertiesStart: u32, propertiesLen: u32) types.Range {
        _ = c;
        _ = symIdx;
        _ = propertiesStart;
        _ = propertiesLen;
        return .{ .start = 0, .len = 0 }; // Stub
    }

    pub fn getIndexInfosOfSymbol(c: *Checker, symIdx: ast_gen.SymbolIndex) types.Range {
        _ = c;
        _ = symIdx;
        // In Go this is just a wrapper, we handled it explicitly above
        return .{ .start = 0, .len = 0 }; // Stub
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
        // TODO: support Alias resolution
        return false;
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

        const startProperties = c.resolvedPropertiesPool.items.len;

        // TODO: Implement proper Union/Intersection property merging
        // ... (getPropertyOfUnionOrIntersectionType) ...

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
        _ = c;
        return t; // Stub
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
            return !c.isGenericMappedType(t);
        }
        if (flags & types.TypeFlags.NonPrimitive != 0) return true;
        // Union/Intersection: partial - conservative return false
        return false;
    }

    pub fn getApparentType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        // Conservative: return same type (for primitives, this is incorrect but safe)
        return t;
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
        _ = c;
        _ = t;
        return false;
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
                    const resolvedType = c.getTypeFromTypeNode(type_node);
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
        var target = &c.getTargetTypeData(t).Conditional;
        if (target.resolvedTrueType == null) {
            const trueTypeNode = c.ast.getNode(target.root).ConditionalType.TrueType;
            target.resolvedTrueType = c.instantiateType(c.getTypeFromTypeNode(trueTypeNode), target.mapper);
        }
        return target.resolvedTrueType.?;
    }

    pub fn getFalseTypeFromConditionalType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        var target = &c.getTargetTypeData(t).Conditional;
        if (target.resolvedFalseType == null) {
            const falseTypeNode = c.ast.getNode(target.root).ConditionalType.FalseType;
            target.resolvedFalseType = c.instantiateType(c.getTypeFromTypeNode(falseTypeNode), target.mapper);
        }
        return target.resolvedFalseType.?;
    }

    pub fn getBaseTypeFromSubstitutionType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        return c.getTargetTypeData(t).Substitution.baseType;
    }

    pub fn getConstraintFromSubstitutionType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        return c.getTargetTypeData(t).Substitution.constraint;
    }

    pub fn getInferTypeParametersFromConditionalType(c: *Checker, t: types.TypeIndex) []const types.TypeIndex {
        const root = c.getTargetTypeData(t).Conditional.root;
        return c.getTypeArray(root.inferTypeParametersStart, root.inferTypeParametersLen);
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
        return c.getTypeArray(tl.typesStart, tl.typesLen);
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
        const type_sym = c.getType(t).symbol orelse return false;
        const sym_ptr = c.symbols.getPtr(type_sym) orelse return false;

        for (sym_ptr.Declarations.items) |d_idx| {
            const node = c.ast.getNode(d_idx);
            if (node.tag == .TypeParameterDeclaration) {
                if (node.TypeParameterDeclaration.DefaultType != 0) return true;
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
            return type_node.data.Object.target orelse t;
        }
        return t;
    }

    pub fn getTargetTupleType(c: *Checker, t: types.TypeIndex) *types.TupleType {
        const target = c.getTargetType(t);
        return &c.typesList.items[target].data.Tuple;
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
            return c.getBaseTypeOfEnumLiteralType(t);
        }
        return t;
    }

    pub fn getIndexType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        return c.getIndexTypeEx(t, types.IndexFlags.None);
    }

    pub fn getConstraintTypeFromMappedType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        return c.getTargetTypeData(t).Mapped.constraintType orelse c.errorType orelse 0;
    }

    pub fn getNameTypeFromMappedType(c: *Checker, t: types.TypeIndex) ?types.TypeIndex {
        return c.getTargetTypeData(t).Mapped.nameType;
    }

    pub fn getMappedTypeModifiers(c: *Checker, t: types.TypeIndex) types.MappedTypeModifiers {
        const declaration = c.getTargetTypeData(t).Mapped.declaration;
        const mapped_node = c.ast.getNode(declaration).MappedType;
        var modifiers = types.MappedTypeModifiers{};
        if (mapped_node.ReadonlyToken) |readonly_token| {
            if (c.ast.getNode(readonly_token).tag == .MinusToken) {
                modifiers.value |= types.MappedTypeModifiers.ExcludeReadonly;
            } else {
                modifiers.value |= types.MappedTypeModifiers.IncludeReadonly;
            }
        }
        if (mapped_node.QuestionToken) |question_token| {
            if (c.ast.getNode(question_token).tag == .MinusToken) {
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
        return c.errorType orelse 0;
    }

    pub fn getTypeParameterFromMappedType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        return c.getTargetTypeData(t).Mapped.typeParameter;
    }

    pub fn getConstraintOfTypeParameter(c: *Checker, t: types.TypeIndex) ?types.TypeIndex {
        if (c.typesList.items[t].flags & types.TypeFlags.TypeParameter != 0) {
            const tp = &c.getTargetTypeData(t).TypeParameter;
            if (!tp.isTypeParameterConstraintResolved) {
                // c.resolveTypeParameterConstraint(t); // TODO: implement resolution
            }
            if (tp.constraintType != 0 and tp.constraintType != c.noConstraintTypeIndex orelse 0) {
                return tp.constraintType;
            }
        }
        return null;
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
        return relater.getKnownKeysOfTupleType(c, t);
    }

    pub fn getSimplifiedType(c: *Checker, t: types.TypeIndex, writing: bool) types.TypeIndex {
        _ = c;
        _ = writing;
        // TODO: implement getSimplifiedType
        return t;
    }

    pub fn getSimplifiedTypeOrConstraint(c: *Checker, t: types.TypeIndex) ?types.TypeIndex {
        const simplified = c.getSimplifiedType(t, false);
        if (simplified != t) {
            return simplified;
        }
        return c.getConstraintOfType(t);
    }

    pub fn getIndexTypeEx(c: *Checker, t: types.TypeIndex, indexFlags: types.IndexFlags) types.TypeIndex {
        _ = c;
        _ = t;
        _ = indexFlags;
        return undefined; // Stub
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
        const decl = c.getTargetTypeData(t).Mapped.declaration;
        const mapped_node = c.ast.getNode(decl).MappedType;
        if (mapped_node.Type) |type_node_idx| {
            const type_node = c.ast.getNode(type_node_idx);
            switch (type_node) {
                .TypeOperator => |op| return op.Operator == @intFromEnum(ast.SyntaxKind.KeyOfKeyword),
                else => return false,
            }
        }
        return false;
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
        return t; // TODO: implement caching and resolution
    }

    pub fn getRestrictiveInstantiation(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        return t; // TODO: implement caching and resolution
    }

    pub fn isTypeAssignableTo(self: *Checker, sourceIdx: types.TypeIndex, targetIdx: types.TypeIndex) bool {
        return relater.isTypeRelatedTo(self, sourceIdx, targetIdx, &self.assignableRelation);
    }

    pub fn templateLiteralTypesDefinitelyUnrelated(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
        return relater.templateLiteralTypesDefinitelyUnrelated(c, source, target);
    }

    pub fn instantiateType(c: *Checker, t: types.TypeIndex, mapper: types.TypeMapperIndex) types.TypeIndex {
        _ = c;
        _ = mapper;
        return t; // TODO: implement instantiateType
    }

    pub fn isMemberOfStringMapping(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
        return relater.isMemberOfStringMapping(c, source, target);
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

    pub fn getConstraintOfIndexedAccess(c: *Checker, t: types.TypeIndex) ?types.TypeIndex {
        var target = &c.getTargetTypeData(t).IndexedAccess;
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
        var target = &c.getTargetTypeData(t).Conditional;
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
        return undefined; // Stub
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
        return false; // Stub
    }

    pub fn intersectTypes(c: *Checker, t1: types.TypeIndex, t2: types.TypeIndex) types.TypeIndex {
        const typesArr = [_]types.TypeIndex{ t1, t2 };
        return c.getIntersectionType(&typesArr);
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
        return c.compareTypesIdentical(source, target) != .False;
    }

    pub fn getInferredTrueTypeFromConditionalType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return undefined; // Stub
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
        return false; // Stub
    }

    pub fn getConstraintOfDistributiveConditionalType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        var target = &c.getTargetTypeData(t).Conditional;
        if (target.resolvedConstraintOfDistributive == null) {
            target.resolvedConstraintOfDistributive = c.unknownTypeIndex orelse 0; // Stub, real impl needs instantiateType
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

                            if (!self.isTypeAssignableTo(argTypeIdx, paramTypeIdx)) {
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
            if (!self.isTypeAssignableTo(rightTypeIdx, leftTypeIdx)) {
                // If not assignable, emit error 2322
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
                        if (!self.isTypeAssignableTo(initType, declaredType)) {
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
                    if (!self.isTypeAssignableTo(exprTypeIdx, functionReturnTypeIdx)) {
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
        for (typesList) |item| {
            if (item == t) return true;
        }
        return false;
    }

    pub fn getSymbolOfDeclaration(c: *Checker, decl: ast_gen.NodeIndex) ast_gen.SymbolIndex {
        _ = c;
        _ = decl;
        return 0; // Stub
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

    pub fn getOriginOfUnionType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
        _ = c;
        _ = t;
        return 0; // Stub
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

    pub fn findDiscriminantProperties(c: *Checker, sourceProperties: []const ast_gen.SymbolIndex, target: types.TypeIndex) []const ast_gen.SymbolIndex {
        _ = c;
        _ = sourceProperties;
        _ = target;
        return &[_]ast_gen.SymbolIndex{}; // Stub
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

    pub fn getSymbolFlags(c: *Checker, sym: ast_gen.SymbolIndex) u32 {
        if (sym < c.binder.symbols.items.len) {
            return c.binder.symbols.items[sym].Flags;
        }
        return 0;
    }

    pub fn isTypeRelatedTo(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, relation: *relater.Relation) bool {
        return relater.isTypeRelatedTo(c, source, target, relation);
    }

    pub fn isSetAccessorSymbol(c: *Checker, sym: ast_gen.SymbolIndex) bool {
        _ = c;
        _ = sym;
        return false; // Stub
    }

    pub fn isGetAccessorSymbol(c: *Checker, sym: ast_gen.SymbolIndex) bool {
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

    pub fn getApplicableIndexInfo(c: *Checker, t: types.TypeIndex, keyType: types.TypeIndex) ?types.IndexInfo {
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

    pub fn getIndexInfoKeyType(c: *Checker, info: types.IndexInfo) types.TypeIndex {
        _ = c;
        return info.keyType;
    }

    pub fn getIndexInfoValueType(c: *Checker, info: types.IndexInfo) types.TypeIndex {
        _ = c;
        return info.valueType;
    }

    pub fn isIgnoredJsxProperty(c: *Checker, source: types.TypeIndex, prop: ast_gen.SymbolIndex) bool {
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

    pub fn getLiteralTypeFromProperty(c: *Checker, prop: ast_gen.SymbolIndex, include: u32, stringify: bool) types.TypeIndex {
        _ = c;
        _ = prop;
        _ = include;
        _ = stringify;
        return 0; // Stub
    }

    pub fn getNonMissingTypeOfSymbol(c: *Checker, prop: ast_gen.SymbolIndex) types.TypeIndex {
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

    pub fn getObjectFlags(c: *Checker, t: types.TypeIndex) u32 {
        if (t == 0 or t >= c.typesList.items.len) return 0;
        return c.typesList.items[t].objectFlags;
    }

    pub fn isTupleType(c: *Checker, t: types.TypeIndex) bool {
        const objectFlags = c.getObjectFlags(t);
        if (objectFlags & types.ObjectFlags.Reference == 0) return false;
        return (c.getObjectFlags(c.getTargetType(t)) & types.ObjectFlags.Tuple) != 0;
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
        _ = c;
        _ = node;
        return .Unknown; // Stub
    }

    pub fn getWriteTypeOfSymbol(c: *Checker, sym: ast_gen.SymbolIndex) types.TypeIndex {
        return c.getTypeOfSymbol(sym) catch c.anyTypeIndex orelse 0;
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
