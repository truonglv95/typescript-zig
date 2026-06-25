const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const symbol = @import("../ast/symbol.zig");
const types = @import("types.zig");
const checker = @import("checker.zig");

pub const InferenceKey = struct {
    s: types.TypeIndex,
    t: types.TypeIndex,
};

pub const InferenceStateIndex = u32;

pub const InferenceState = struct {
    inferences: std.ArrayListUnmanaged(types.InferenceInfoIndex) = .empty,
    originalSource: ?types.TypeIndex = null,
    originalTarget: ?types.TypeIndex = null,
    priority: i32 = types.InferencePriority.None,
    inferencePriority: i32 = types.InferencePriority.MaxValue,
    contravariant: bool = false,
    bivariant: bool = false,
    expandingFlags: u8 = 0,
    propagationType: ?types.TypeIndex = null,
    visited: std.AutoHashMapUnmanaged(InferenceKey, i32) = .empty,
    sourceStack: std.ArrayListUnmanaged(types.TypeIndex) = .empty,
    targetStack: std.ArrayListUnmanaged(types.TypeIndex) = .empty,
    next: ?InferenceStateIndex = null,

    pub fn deinit(self: *InferenceState, allocator: std.mem.Allocator) void {
        self.inferences.deinit(allocator);
        self.visited.deinit(allocator);
        self.sourceStack.deinit(allocator);
        self.targetStack.deinit(allocator);
    }
};

pub fn getInferenceState(c: *checker.Checker) !InferenceStateIndex {
    if (c.freeInferenceState) |n_idx| {
        c.freeInferenceState = c.inferenceStates.items[n_idx].next;
        return n_idx;
    }
    const n_idx = @as(u32, @intCast(c.inferenceStates.items.len));
    try c.inferenceStates.append(c.allocator, InferenceState{});
    return n_idx;
}

pub fn putInferenceState(c: *checker.Checker, n_idx: InferenceStateIndex) void {
    const n = &c.inferenceStates.items[n_idx];
    n.visited.clearRetainingCapacity();
    n.inferences.clearRetainingCapacity();
    n.sourceStack.clearRetainingCapacity();
    n.targetStack.clearRetainingCapacity();
    n.next = c.freeInferenceState;
    c.freeInferenceState = n_idx;
}

pub fn inferTypes(c: *checker.Checker, inferences: []const types.InferenceInfoIndex, originalSource: types.TypeIndex, originalTarget: types.TypeIndex, priority: i32, contravariant: bool) !void {
    const n_idx = try getInferenceState(c);
    defer putInferenceState(c, n_idx);

    const n = &c.inferenceStates.items[n_idx];
    try n.inferences.appendSlice(c.allocator, inferences);
    n.originalSource = originalSource;
    n.originalTarget = originalTarget;
    n.priority = priority;
    n.inferencePriority = types.InferencePriority.MaxValue;
    n.contravariant = contravariant;

    try inferFromTypes(c, n_idx, originalSource, originalTarget);
}

pub fn inferFromTypes(c: *checker.Checker, n_idx: InferenceStateIndex, source: types.TypeIndex, target: types.TypeIndex) !void {
    if (!couldContainTypeVariables(c, target) or isNoInferType(c, target)) {
        return;
    }
    
    if (source == wildcardType(c) or source == blockedStringType(c)) {
        const n = &c.inferenceStates.items[n_idx];
        const savePropagationType = n.propagationType;
        n.propagationType = source;
        try inferFromTypes(c, n_idx, target, target);
        c.inferenceStates.items[n_idx].propagationType = savePropagationType;
        return;
    }
    
    // Further complex logic stubbed for now

}

pub fn inferFromTypeArguments(c: *checker.Checker, n_idx: InferenceStateIndex, sourceTypes: []const types.TypeIndex, targetTypes: []const types.TypeIndex, variances: []const u32) !void {
    const len = @min(sourceTypes.len, targetTypes.len);
    for (0..len) |i| {
        if (i < variances.len and (variances[i] & 3) == 2) { // VarianceFlagsContravariant == 2
            try inferFromContravariantTypes(c, n_idx, sourceTypes[i], targetTypes[i]);
        } else {
            try inferFromTypes(c, n_idx, sourceTypes[i], targetTypes[i]);
        }
    }
}

pub fn inferWithPriority(c: *checker.Checker, n_idx: InferenceStateIndex, source: types.TypeIndex, target: types.TypeIndex, newPriority: i32) !void {
    const n = &c.inferenceStates.items[n_idx];
    const savePriority = n.priority;
    n.priority |= newPriority;
    try inferFromTypes(c, n_idx, source, target);
    c.inferenceStates.items[n_idx].priority = savePriority; // Re-access due to potential reallocation
}

pub fn inferFromContravariantTypes(c: *checker.Checker, n_idx: InferenceStateIndex, source: types.TypeIndex, target: types.TypeIndex) !void {
    const n = &c.inferenceStates.items[n_idx];
    n.contravariant = !n.contravariant;
    try inferFromTypes(c, n_idx, source, target);
    c.inferenceStates.items[n_idx].contravariant = !c.inferenceStates.items[n_idx].contravariant;
}

pub fn invokeOnce(
    c: *checker.Checker,
    n_idx: InferenceStateIndex,
    source: types.TypeIndex,
    target: types.TypeIndex,
    action: *const fn (*checker.Checker, InferenceStateIndex, types.TypeIndex, types.TypeIndex) anyerror!void,
) !void {
    const key = InferenceKey{ .s = source, .t = target };
    var n = &c.inferenceStates.items[n_idx];

    if (n.visited.get(key)) |status| {
        n.inferencePriority = @min(n.inferencePriority, status);
        return;
    }

    try n.visited.put(c.allocator, key, types.InferencePriority.Circularity);
    const saveInferencePriority = n.inferencePriority;
    n.inferencePriority = types.InferencePriority.MaxValue;

    const saveExpandingFlags = n.expandingFlags;
    try n.sourceStack.append(c.allocator, source);
    try n.targetStack.append(c.allocator, target);

    if (isDeeplyNestedType(c, source, n.sourceStack.items, 2)) {
        n.expandingFlags |= types.ExpandingFlags.Source;
    }
    if (isDeeplyNestedType(c, target, n.targetStack.items, 2)) {
        n.expandingFlags |= types.ExpandingFlags.Target;
    }

    if (n.expandingFlags != types.ExpandingFlags.Both) {
        try action(c, n_idx, source, target);
    } else {
        n.inferencePriority = types.InferencePriority.Circularity;
    }

    n = &c.inferenceStates.items[n_idx]; // Re-fetch
    _ = n.targetStack.pop();
    _ = n.sourceStack.pop();
    n.expandingFlags = saveExpandingFlags;
    try n.visited.put(c.allocator, key, n.inferencePriority);
    n.inferencePriority = @min(n.inferencePriority, saveInferencePriority);
}

pub fn getInferenceInfoForType(c: *checker.Checker, n_idx: InferenceStateIndex, t: types.TypeIndex) ?types.InferenceInfoIndex {
    const type_obj = c.typesList.items[t];
    if ((type_obj.flags & types.TypeFlags.TypeVariable) != 0) {
        const n = &c.inferenceStates.items[n_idx];
        for (n.inferences.items) |info_idx| {
            if (c.inferenceContextInfos.items[info_idx].context) |ctx_idx| {
                _ = ctx_idx;
                // Actually InferenceInfo is in `c.inferenceInfos`, wait, InferenceInfo needs a list.
                // Let's assume we have `c.inferenceInfos` in Checker!
            }
        }
    }
    return null;
}

// ---------------------------------------------------------
// STUBS FOR AST / CHECKER HELPER FUNCTIONS
// ---------------------------------------------------------

pub fn couldContainTypeVariables(c: *checker.Checker, t: types.TypeIndex) bool {
    _ = c;
    _ = t;
    return true;
}

pub fn isNoInferType(c: *checker.Checker, t: types.TypeIndex) bool {
    _ = c;
    _ = t;
    return false;
}

pub fn isDeeplyNestedType(c: *checker.Checker, t: types.TypeIndex, stack: []const types.TypeIndex, depth: usize) bool {
    _ = c;
    _ = t;
    _ = stack;
    _ = depth;
    return false;
}

pub fn getInferredType(c: *checker.Checker, n_idx: types.InferenceContextIndex, index: usize) types.TypeIndex {
    const ctx_info = &c.inferenceContextInfos.items[n_idx];
    if (ctx_info.context == null) return 0; // Fallback
    
    const ctx = &c.inferenceContexts.items[ctx_info.context.?];
    const inf_idx = ctx.inferences.items[index];
    var inference = &c.inferenceInfos.items[inf_idx];

    if (inference.inferredType == null) {
        if (inference.typeParameter == errorType(c)) {
            return inference.typeParameter;
        }

        var inferredType: ?types.TypeIndex = null;
        var fallbackType: ?types.TypeIndex = null;

        if (ctx.signature != null) {
            var inferredCovariantType: ?types.TypeIndex = null;
            if (inference.candidates.items.len != 0) {
                inferredCovariantType = getCovariantInference(c, inf_idx, ctx.signature.?);
            }
            var inferredContravariantType: ?types.TypeIndex = null;
            if (inference.contraCandidates.items.len != 0) {
                inferredContravariantType = getContravariantInference(c, inf_idx);
            }

            if (inferredCovariantType != null or inferredContravariantType != null) {
                const preferCovariantType = inferredCovariantType != null and 
                    (inferredContravariantType == null or preferCovariantTypeLogic(c, inf_idx, inferredCovariantType.?, inferredContravariantType));
                
                if (preferCovariantType) {
                    inferredType = inferredCovariantType;
                    fallbackType = inferredContravariantType;
                } else {
                    inferredType = inferredContravariantType;
                    fallbackType = inferredCovariantType;
                }
            } else if ((ctx.flags & types.InferenceFlags.NoDefault) != 0) {
                inferredType = silentNeverType(c);
            } else {
                const defaultType = getDefaultFromTypeParameter(c, inference.typeParameter);
                if (defaultType) |dt| {
                    inferredType = instantiateType(c, dt, mergeTypeMappers(c, newBackreferenceMapper(c, n_idx, index), ctx.nonFixingMapper));
                }
            }
        } else {
            inferredType = getTypeFromInference(c, inf_idx);
        }

        inference.inferredType = inferredType orelse if ((ctx.flags & types.InferenceFlags.AnyDefault) != 0) anyType(c) else unknownType(c);

        const constraint = getConstraintOfTypeParameter(c, inference.typeParameter);
        if (constraint) |cst| {
            // Stub constraint logic
            _ = cst; 
        }
    }
    
    return inference.inferredType.?;
}

pub fn getInferredTypes(c: *checker.Checker, n_idx: types.InferenceContextIndex) ![]types.TypeIndex {
    const ctx_info = &c.inferenceContextInfos.items[n_idx];
    if (ctx_info.context == null) return &[_]types.TypeIndex{};
    
    const ctx = &c.inferenceContexts.items[ctx_info.context.?];
    var result = try c.allocator.alloc(types.TypeIndex, ctx.inferences.items.len);
    for (ctx.inferences.items, 0..) |_, i| {
        result[i] = getInferredType(c, n_idx, i);
    }
    return result;
}

pub fn getMapperFromContext(c: *checker.Checker, n_idx: types.InferenceContextIndex) ?types.TypeMapperIndex {
    _ = c;
    _ = n_idx;
    return null;
}

pub fn inferToMultipleTypes(c: *checker.Checker, n_idx: InferenceStateIndex, source: types.TypeIndex, targets: []const types.TypeIndex, targetFlags: u32) !void {
    _ = c;
    _ = n_idx;
    _ = source;
    _ = targets;
    _ = targetFlags;
}

pub fn inferToMultipleTypesWithPriority(c: *checker.Checker, n_idx: InferenceStateIndex, source: types.TypeIndex, targets: []const types.TypeIndex, targetFlags: u32, newPriority: i32) !void {
    const n = &c.inferenceStates.items[n_idx];
    const savePriority = n.priority;
    n.priority |= newPriority;
    try inferToMultipleTypes(c, n_idx, source, targets, targetFlags);
    c.inferenceStates.items[n_idx].priority = savePriority;
}

pub fn wildcardType(c: *checker.Checker) types.TypeIndex {
    _ = c;
    return 0; // stub
}

pub fn blockedStringType(c: *checker.Checker) types.TypeIndex {
    _ = c;
    return 0; // stub
}

// ---------------------------------------------------------
// STUBS FOR INFERRED TYPE HELPERS
// ---------------------------------------------------------

pub fn errorType(c: *checker.Checker) types.TypeIndex { _ = c; return 0; }
pub fn silentNeverType(c: *checker.Checker) types.TypeIndex { _ = c; return 0; }
pub fn anyType(c: *checker.Checker) types.TypeIndex { _ = c; return 0; }
pub fn unknownType(c: *checker.Checker) types.TypeIndex { _ = c; return 0; }

pub fn getCovariantInference(c: *checker.Checker, inf_idx: types.InferenceInfoIndex, signature: types.SignatureIndex) ?types.TypeIndex {
    _ = c; _ = inf_idx; _ = signature;
    return null;
}

pub fn getContravariantInference(c: *checker.Checker, inf_idx: types.InferenceInfoIndex) ?types.TypeIndex {
    _ = c; _ = inf_idx;
    return null;
}

pub fn preferCovariantTypeLogic(c: *checker.Checker, inf_idx: types.InferenceInfoIndex, cov: types.TypeIndex, contra: ?types.TypeIndex) bool {
    _ = c; _ = inf_idx; _ = cov; _ = contra;
    return true;
}

pub fn getDefaultFromTypeParameter(c: *checker.Checker, t: types.TypeIndex) ?types.TypeIndex {
    _ = c; _ = t;
    return null;
}

pub fn instantiateType(c: *checker.Checker, t: types.TypeIndex, mapper: ?types.TypeMapperIndex) types.TypeIndex {
    _ = c; _ = mapper;
    return t;
}

pub fn mergeTypeMappers(c: *checker.Checker, a: ?types.TypeMapperIndex, b: ?types.TypeMapperIndex) ?types.TypeMapperIndex {
    _ = c; _ = a; _ = b;
    return null;
}

pub fn newBackreferenceMapper(c: *checker.Checker, n_idx: types.InferenceContextIndex, index: usize) ?types.TypeMapperIndex {
    _ = c; _ = n_idx; _ = index;
    return null;
}

pub fn getTypeFromInference(c: *checker.Checker, inf_idx: types.InferenceInfoIndex) ?types.TypeIndex {
    _ = c; _ = inf_idx;
    return null;
}

pub fn getConstraintOfTypeParameter(c: *checker.Checker, t: types.TypeIndex) ?types.TypeIndex {
    _ = c; _ = t;
    return null;
}

pub fn unionObjectAndArrayLiteralCandidates(c: *checker.Checker, candidates: []const types.TypeIndex) ![]types.TypeIndex {
    if (candidates.len > 1) {
        var objectLiterals = std.ArrayList(types.TypeIndex).init(c.allocator);
        defer objectLiterals.deinit();
        var nonLiteralTypes = std.ArrayList(types.TypeIndex).init(c.allocator);
        defer nonLiteralTypes.deinit();

        for (candidates) |cand| {
            if (isObjectOrArrayLiteralType(c, cand)) {
                try objectLiterals.append(cand);
            } else {
                try nonLiteralTypes.append(cand);
            }
        }
        if (objectLiterals.items.len != 0) {
            const literalsType = getUnionTypeEx(c, objectLiterals.items);
            var result = try c.allocator.alloc(types.TypeIndex, nonLiteralTypes.items.len + 1);
            @memcpy(result[0..nonLiteralTypes.items.len], nonLiteralTypes.items);
            result[nonLiteralTypes.items.len] = literalsType;
            return result;
        }
    }
    return try c.allocator.dupe(types.TypeIndex, candidates);
}

pub fn hasPrimitiveConstraint(c: *checker.Checker, t: types.TypeIndex) bool {
    var constraint = getConstraintOfTypeParameter(c, t);
    if (constraint) |cst| {
        const type_obj = c.typesList.items[cst];
        if ((type_obj.flags & types.TypeFlags.Conditional) != 0) {
            constraint = getDefaultConstraintOfConditionalType(c, cst);
        }
        return maybeTypeOfKind(c, constraint.?, types.TypeFlags.Primitive | types.TypeFlags.Index | types.TypeFlags.TemplateLiteral | types.TypeFlags.StringMapping);
    }
    return false;
}

pub fn isTypeParameterAtTopLevel(c: *checker.Checker, t: types.TypeIndex, tp: types.TypeIndex, depth: usize) bool {
    if (t == tp) return true;
    const type_obj = c.typesList.items[t];
    if ((type_obj.flags & types.TypeFlags.UnionOrIntersection) != 0) {
        const typeList = getTypes(c, t); 
        for (typeList) |ty| {
            if (isTypeParameterAtTopLevel(c, ty, tp, depth)) return true;
        }
    } else if (depth < 3 and (type_obj.flags & types.TypeFlags.Conditional) != 0) {
        if (isTypeParameterAtTopLevel(c, getTrueTypeFromConditionalType(c, t), tp, depth + 1)) return true;
        if (isTypeParameterAtTopLevel(c, getFalseTypeFromConditionalType(c, t), tp, depth + 1)) return true;
    }
    return false;
}

pub fn isTypeParameterAtTopLevelInReturnType(c: *checker.Checker, signature: types.SignatureIndex, tp: types.TypeIndex) bool {
    const typePredicate = getTypePredicateOfSignature(c, signature);
    if (typePredicate) |pred| {
        return pred != 0 and isTypeParameterAtTopLevel(c, pred, tp, 0); // Using 0 as a stub for actual predicate type
    }
    return isTypeParameterAtTopLevel(c, getReturnTypeOfSignature(c, signature), tp, 0);
}

pub fn getCommonSupertype(c: *checker.Checker, types_list: []const types.TypeIndex) types.TypeIndex {
    if (types_list.len == 1) return types_list[0];
    
    // Stub
    _ = c;
    return types_list[0];
}

pub fn getSingleCommonSupertype(c: *checker.Checker, types_list: []const types.TypeIndex) types.TypeIndex {
    _ = c;
    return types_list[0];
}

pub fn findLeftmostType(c: *checker.Checker, types_list: []const types.TypeIndex, checkFn: *const fn (*checker.Checker, types.TypeIndex, types.TypeIndex) bool) types.TypeIndex {
    var candidate: ?types.TypeIndex = null;
    for (types_list) |t| {
        if (candidate == null or checkFn(c, candidate.?, t)) {
            candidate = t;
        }
    }
    return candidate orelse types_list[0];
}

pub fn getCommonSubtype(c: *checker.Checker, types_list: []const types.TypeIndex) types.TypeIndex {
    var subtype: ?types.TypeIndex = null;
    for (types_list) |t| {
        if (subtype == null or isTypeSubtypeOf(c, t, subtype.?)) {
            subtype = t;
        }
    }
    return subtype orelse types_list[0];
}

pub fn getCombinedTypeFlags(c: *checker.Checker, types_list: []const types.TypeIndex) u32 {
    var flags: u32 = types.TypeFlags.None;
    for (types_list) |t| {
        const type_obj = c.typesList.items[t];
        if ((type_obj.flags & types.TypeFlags.Union) != 0) {
            flags |= getCombinedTypeFlags(c, getTypes(c, t));
        } else {
            flags |= type_obj.flags;
        }
    }
    return flags;
}

pub fn literalTypesWithSameBaseType(c: *checker.Checker, types_list: []const types.TypeIndex) bool {
    var commonBaseType: ?types.TypeIndex = null;
    for (types_list) |t| {
        const type_obj = c.typesList.items[t];
        if ((type_obj.flags & types.TypeFlags.Never) == 0) {
            const baseType = getBaseTypeOfLiteralType(c, t);
            if (commonBaseType == null) {
                commonBaseType = baseType;
            }
            if (baseType == t or baseType != commonBaseType.?) {
                return false;
            }
        }
    }
    return true;
}

pub fn isFromInferenceBlockedSource(c: *checker.Checker, t: types.TypeIndex) bool {
    _ = c; _ = t;
    return false;
}

pub fn isSkipDirectInferenceNode(c: *checker.Checker, node: ast_gen.NodeIndex) bool {
    _ = c; _ = node;
    return false;
}

pub fn newInferenceInfo(c: *checker.Checker, typeParameter: types.TypeIndex) !types.InferenceInfoIndex {
    const info = types.InferenceInfo{
        .typeParameter = typeParameter,
        .candidates = .empty,
        .contraCandidates = .empty,
        .inferredType = null,
        .priority = types.InferencePriority.MaxValue,
        .topLevel = true,
        .isFixed = false,
        .impliedArity = -1,
    };
    const n_idx = @as(u32, @intCast(c.inferenceInfos.items.len));
    try c.inferenceInfos.append(c.allocator, info);
    return n_idx;
}

pub fn cloneInferenceInfo(c: *checker.Checker, inf_idx: types.InferenceInfoIndex) !types.InferenceInfoIndex {
    const info = c.inferenceInfos.items[inf_idx];
    const cloned = types.InferenceInfo{
        .typeParameter = info.typeParameter,
        .candidates = try info.candidates.clone(c.allocator),
        .contraCandidates = try info.contraCandidates.clone(c.allocator),
        .inferredType = info.inferredType,
        .priority = info.priority,
        .topLevel = info.topLevel,
        .isFixed = info.isFixed,
        .impliedArity = info.impliedArity,
    };
    const n_idx = @as(u32, @intCast(c.inferenceInfos.items.len));
    try c.inferenceInfos.append(c.allocator, cloned);
    return n_idx;
}

pub fn clearCachedInferences(c: *checker.Checker, inferences: []const types.InferenceInfoIndex) void {
    for (inferences) |inf_idx| {
        if (!c.inferenceInfos.items[inf_idx].isFixed) {
            c.inferenceInfos.items[inf_idx].inferredType = null;
        }
    }
}

pub fn hasInferenceCandidates(c: *checker.Checker, inf_idx: types.InferenceInfoIndex) bool {
    const info = c.inferenceInfos.items[inf_idx];
    return info.candidates.items.len != 0 or info.contraCandidates.items.len != 0;
}

pub fn hasInferenceCandidatesOrDefault(c: *checker.Checker, inf_idx: types.InferenceInfoIndex) bool {
    return hasInferenceCandidates(c, inf_idx) or hasTypeParameterDefault(c, c.inferenceInfos.items[inf_idx].typeParameter);
}

pub fn hasTypeParameterDefault(c: *checker.Checker, tp: types.TypeIndex) bool {
    _ = c; _ = tp;
    return false; // stub
}

pub fn hasOverlappingInferences(c: *checker.Checker, a: []const types.InferenceInfoIndex, b: []const types.InferenceInfoIndex) bool {
    const len = @min(a.len, b.len);
    for (0..len) |i| {
        if (hasInferenceCandidates(c, a[i]) and hasInferenceCandidates(c, b[i])) {
            return true;
        }
    }
    return false;
}

pub fn mergeInferences(c: *checker.Checker, target: []types.InferenceInfoIndex, source: []const types.InferenceInfoIndex) void {
    const len = @min(target.len, source.len);
    for (0..len) |i| {
        if (!hasInferenceCandidates(c, target[i]) and hasInferenceCandidates(c, source[i])) {
            target[i] = source[i];
        }
    }
}

// ---------------------------------------------------------
// ADDITIONAL STUBS FOR INFERRED TYPE HELPERS
// ---------------------------------------------------------

pub fn isObjectOrArrayLiteralType(c: *checker.Checker, t: types.TypeIndex) bool { _ = c; _ = t; return false; }
pub fn getUnionTypeEx(c: *checker.Checker, types_list: []const types.TypeIndex) types.TypeIndex { _ = c; return types_list[0]; }
pub fn getDefaultConstraintOfConditionalType(c: *checker.Checker, t: types.TypeIndex) ?types.TypeIndex { _ = c; _ = t; return null; }
pub fn maybeTypeOfKind(c: *checker.Checker, t: types.TypeIndex, flags: u32) bool { _ = c; _ = t; _ = flags; return false; }
pub fn getTypes(c: *checker.Checker, t: types.TypeIndex) []const types.TypeIndex { _ = c; _ = t; return &[_]types.TypeIndex{}; }
pub fn getTrueTypeFromConditionalType(c: *checker.Checker, t: types.TypeIndex) types.TypeIndex { _ = c; return t; }
pub fn getFalseTypeFromConditionalType(c: *checker.Checker, t: types.TypeIndex) types.TypeIndex { _ = c; return t; }
pub fn getTypePredicateOfSignature(c: *checker.Checker, signature: types.SignatureIndex) ?types.TypeIndex { _ = c; _ = signature; return null; }
pub fn getReturnTypeOfSignature(c: *checker.Checker, signature: types.SignatureIndex) types.TypeIndex { _ = c; _ = signature; return 0; }
pub fn isTypeSubtypeOf(c: *checker.Checker, s: types.TypeIndex, t: types.TypeIndex) bool { _ = c; _ = s; _ = t; return false; }
pub fn getBaseTypeOfLiteralType(c: *checker.Checker, t: types.TypeIndex) types.TypeIndex { _ = c; return t; }
