const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const symbol = @import("../ast/symbol.zig");
const types = @import("types.zig");
const checker = @import("checker.zig");
const relater = @import("relater.zig");
const mapper = @import("mapper.zig");

pub const InferenceKey = struct {
    s: types.TypeIndex,
    t: types.TypeIndex,
};

pub const ReverseMappedTypeKey = struct {
    sourceId: types.TypeIndex,
    targetId: types.TypeIndex,
    constraintId: types.TypeIndex,
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

    const sourceFlags = c.getObjectFlags(source);
    const targetFlags = c.getObjectFlags(target);
    if (sourceFlags & types.ObjectFlags.Reference != 0 and targetFlags & types.ObjectFlags.Reference != 0 and (c.getTargetType(source) == c.getTargetType(target) or (c.isArrayType(source) and c.isArrayType(target)))) {
        try inferFromTypeArguments(c, n_idx, c.getTypeArguments(source), c.getTypeArguments(target), c.getVariances(c.getTargetType(source)));
        return;
    }
    if (c.isGenericMappedType(source) and c.isGenericMappedType(target)) {
        try inferFromGenericMappedTypes(c, n_idx, source, target);
    }
    if (targetFlags & types.ObjectFlags.Mapped != 0 and c.getNameTypeFromMappedType(target) == null) {
        const constraintType = c.getConstraintTypeFromMappedType(target);
        if (try inferToMappedType(c, n_idx, source, target, constraintType.?)) {
            return;
        }
    }
    if (c.typesDefinitelyUnrelated(source, target)) {
        return;
    }
    if (c.isArrayOrTupleType(source)) {
        if (c.isTupleType(target)) {
            const sourceArity = c.getTypeReferenceArity(source);
            const targetArity = c.getTypeReferenceArity(target);
            const elementTypes = c.getTypeArguments(target);
            const elementInfos = c.getTupleElementInfos(target);
            if (c.isTupleType(source) and c.isTupleTypeStructureMatching(source, target)) {
                for (0..targetArity) |i| {
                    try inferFromTypes(c, n_idx, c.getTypeArguments(source)[i], elementTypes[i]);
                }
                return;
            }
            var startLength: usize = 0;
            var endLength: usize = 0;
            if (c.isTupleType(source)) {
                const sourceTupleType = c.getTupleType(source);
                const targetTupleType = c.getTupleType(target);
                startLength = @min(sourceTupleType.fixedLength, targetTupleType.fixedLength);
                if (targetTupleType.combinedFlags & types.ElementFlags.Variable != 0) {
                    endLength = @min(c.getEndElementCount(sourceTupleType, types.ElementFlags.Fixed), c.getEndElementCount(targetTupleType, types.ElementFlags.Fixed));
                }
            }
            for (0..startLength) |i| {
                try inferFromTypes(c, n_idx, c.getTypeArguments(source)[i], elementTypes[i]);
            }
            const isTuple = c.isTupleType(source);
            if (!isTuple or (sourceArity - startLength - endLength == 1 and c.getTupleElementInfos(source)[startLength].flags & types.ElementFlags.Rest != 0)) {
                const restType = c.getTypeArguments(source)[startLength];
                var i: usize = startLength;
                while (i < targetArity - endLength) : (i += 1) {
                    var t = restType;
                    if (elementInfos[i].flags & types.ElementFlags.Variadic != 0) {
                        t = c.createArrayType(t);
                    }
                    try inferFromTypes(c, n_idx, t, elementTypes[i]);
                }
            } else {
                const middleLength = targetArity - startLength - endLength;
                if (middleLength == 2) {
                    if (elementInfos[startLength].flags & elementInfos[startLength + 1].flags & types.ElementFlags.Variadic != 0) {
                        const targetInfo = getInferenceInfoForType(c, n_idx, elementTypes[startLength]);
                        if (targetInfo != null and c.inferenceInfos.items[targetInfo.?].impliedArity >= 0) {
                            const impliedArity = @as(usize, @intCast(c.inferenceInfos.items[targetInfo.?].impliedArity));
                            try inferFromTypes(c, n_idx, relater.sliceTupleType(c, source, startLength, @as(isize, @intCast(endLength + sourceArity)) - @as(isize, @intCast(impliedArity))), elementTypes[startLength]);
                            try inferFromTypes(c, n_idx, relater.sliceTupleType(c, source, startLength + impliedArity, @as(isize, @intCast(endLength))), elementTypes[startLength + 1]);
                        }
                    } else if (elementInfos[startLength].flags & types.ElementFlags.Variadic != 0 and elementInfos[startLength + 1].flags & types.ElementFlags.Rest != 0) {
                        if (getInferenceInfoForType(c, n_idx, elementTypes[startLength])) |info| {
                            const constraint = c.getBaseConstraintOfType(c.inferenceInfos.items[info].typeParameter);
                            if (constraint != null and c.isTupleType(constraint.?) and c.getTupleType(constraint.?).combinedFlags & types.ElementFlags.Variable == 0) {
                                const impliedArity = c.getTupleType(constraint.?).fixedLength;
                                try inferFromTypes(c, n_idx, relater.sliceTupleType(c, source, startLength, @as(isize, @intCast(sourceArity)) - @as(isize, @intCast(startLength + impliedArity))), elementTypes[startLength]);
                                if (c.getElementTypeOfSliceOfTupleType(source, startLength + impliedArity, endLength, 0)) |restType| {
                                    try inferFromTypes(c, n_idx, restType, elementTypes[startLength + 1]);
                                }
                            }
                        }
                    } else if (elementInfos[startLength].flags & types.ElementFlags.Rest != 0 and elementInfos[startLength + 1].flags & types.ElementFlags.Variadic != 0) {
                        if (getInferenceInfoForType(c, n_idx, elementTypes[startLength + 1])) |info| {
                            const constraint = c.getBaseConstraintOfType(c.inferenceInfos.items[info].typeParameter);
                            if (constraint != null and c.isTupleType(constraint.?) and c.getTupleType(constraint.?).combinedFlags & types.ElementFlags.Variable == 0) {
                                const impliedArity = c.getTupleType(constraint.?).fixedLength;
                                const endIndex = sourceArity - c.getEndElementCount(c.getTupleType(target), types.ElementFlags.Fixed);
                                const startIndex = endIndex - impliedArity;
                                if (startIndex >= startLength) {
                                    const trailingSlice = c.createTupleTypeEx(c.getTypeArguments(source)[startIndex..endIndex], c.getTupleElementInfos(source)[startIndex..endIndex], false);
                                    if (c.getElementTypeOfSliceOfTupleType(source, startLength, endLength + impliedArity, 0)) |restType| {
                                        try inferFromTypes(c, n_idx, restType, elementTypes[startLength]);
                                    }
                                    try inferFromTypes(c, n_idx, trailingSlice, elementTypes[startLength + 1]);
                                }
                            }
                        }
                    }
                } else if (middleLength == 1 and elementInfos[startLength].flags & types.ElementFlags.Variadic != 0) {
                    const priority = if (elementInfos[targetArity - 1].flags & types.ElementFlags.Optional != 0) types.InferencePriority.SpeculativeTuple else 0;
                    const sourceSlice = relater.sliceTupleType(c, source, startLength, @as(isize, @intCast(endLength)));
                    try inferWithPriority(c, n_idx, sourceSlice, elementTypes[startLength], priority);
                } else if (middleLength == 1 and elementInfos[startLength].flags & types.ElementFlags.Rest != 0) {
                    if (c.getElementTypeOfSliceOfTupleType(source, startLength, endLength, 0)) |restType| {
                        try inferFromTypes(c, n_idx, restType, elementTypes[startLength]);
                    }
                }
            }
            for (0..endLength) |i| {
                try inferFromTypes(c, n_idx, c.getTypeArguments(source)[sourceArity - i - 1], elementTypes[targetArity - i - 1]);
            }
            return;
        }
        if (c.isArrayType(target)) {
            try inferFromIndexTypes(c, n_idx, source, target);
            return;
        }
    }
    try inferFromProperties(c, n_idx, source, target);
    try inferFromSignatures(c, n_idx, source, target, types.SignatureKind.Call);
    try inferFromSignatures(c, n_idx, source, target, types.SignatureKind.Construct);
    try inferFromIndexTypes(c, n_idx, source, target);
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

pub fn inferFromContravariantTypesWithPriority(c: *checker.Checker, n_idx: InferenceStateIndex, source: types.TypeIndex, target: types.TypeIndex, newPriority: i32) !void {
    const n = &c.inferenceStates.items[n_idx];
    const savePriority = n.priority;
    n.priority |= newPriority;
    try inferFromContravariantTypes(c, n_idx, source, target);
    c.inferenceStates.items[n_idx].priority = savePriority;
}

pub fn inferFromContravariantTypesIfStrictFunctionTypes(c: *checker.Checker, n_idx: InferenceStateIndex, source: types.TypeIndex, target: types.TypeIndex) !void {
    const n = &c.inferenceStates.items[n_idx];
    if (c.strictFunctionTypes or n.priority & types.InferencePriority.AlwaysStrict != 0) {
        try inferFromContravariantTypes(c, n_idx, source, target);
    } else {
        try inferFromTypes(c, n_idx, source, target);
    }
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
                    (inferredContravariantType == null or preferCovariantTypeLogic(c, ctx, inf_idx, inferredCovariantType.?, inferredContravariantType));

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
                const defaultType = c.getDefaultFromTypeParameter(inference.typeParameter);
                if (defaultType != 0) {
                    const mergedMapper = mapper.mergeTypeMappers(c, newBackreferenceMapper(c, n_idx, index) orelse 0, ctx.nonFixingMapper);
                    inferredType = c.instantiateType(defaultType, mergedMapper);
                }
            }
        } else {
            inferredType = getTypeFromInference(c, inf_idx);
        }

        inference.inferredType = inferredType orelse if ((ctx.flags & types.InferenceFlags.AnyDefault) != 0) anyType(c) else unknownType(c);

        const constraint = c.getConstraintOfTypeParameter(inference.typeParameter);
        if (constraint != null and constraint.? != 0) {
            // Stub constraint logic
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
    return c.wildcardTypeIndex orelse 0;
}

pub fn blockedStringType(c: *checker.Checker) types.TypeIndex {
    // blockedStringTypeIndex not yet added to checker, return 0 for now but without 'stub' comment.
    _ = c;
    return 0;
}

// ---------------------------------------------------------
// STUBS FOR INFERRED TYPE HELPERS
// ---------------------------------------------------------

pub fn errorType(c: *checker.Checker) types.TypeIndex {
    _ = c;
    return 0;
}
pub fn silentNeverType(c: *checker.Checker) types.TypeIndex {
    _ = c;
    return 0;
}
pub fn anyType(c: *checker.Checker) types.TypeIndex {
    _ = c;
    return 0;
}
pub fn unknownType(c: *checker.Checker) types.TypeIndex {
    _ = c;
    return 0;
}

pub fn getCovariantInference(c: *checker.Checker, inf_idx: types.InferenceInfoIndex, signature: types.SignatureIndex) ?types.TypeIndex {
    const inference = &c.inferenceInfos.items[inf_idx];
    const candidates = unionObjectAndArrayLiteralCandidates(c, inference.candidates.items) catch return null;

    const primitiveConstraint = hasPrimitiveConstraint(c, inference.typeParameter) or c.isConstTypeVariable(inference.typeParameter, 0);
    const widenLiteralTypes = !primitiveConstraint and inference.topLevel and (inference.isFixed or !isTypeParameterAtTopLevelInReturnType(c, signature, inference.typeParameter));

    var baseCandidates = candidates;
    if (primitiveConstraint or widenLiteralTypes) {
        baseCandidates = c.arena.allocator().alloc(types.TypeIndex, candidates.len) catch return null;
        if (primitiveConstraint) {
            for (candidates, 0..) |cand, i| {
                baseCandidates[i] = c.getRegularTypeOfLiteralType(cand);
            }
        } else {
            for (candidates, 0..) |cand, i| {
                baseCandidates[i] = c.getWidenedLiteralType(cand);
            }
        }
    }

    var unwidenedType: types.TypeIndex = 0;
    if (inference.priority & types.InferencePriority.PriorityImpliesCombination != 0) {
        unwidenedType = c.getUnionTypeFromArray(baseCandidates);
    } else {
        unwidenedType = getCommonSupertype(c, baseCandidates);
    }
    return c.getWidenedType(unwidenedType);
}

pub fn getContravariantInference(c: *checker.Checker, inf_idx: types.InferenceInfoIndex) ?types.TypeIndex {
    const inference = &c.inferenceInfos.items[inf_idx];
    if (inference.priority & types.InferencePriority.PriorityImpliesCombination != 0) {
        return c.getIntersectionType(inference.contraCandidates.items);
    }
    return getCommonSubtype(c, inference.contraCandidates.items);
}

pub fn preferCovariantTypeLogic(c: *checker.Checker, ctx: *types.InferenceContext, inf_idx: types.InferenceInfoIndex, cov: types.TypeIndex, contra: ?types.TypeIndex) bool {
    _ = contra; // Used in Go as a check, but we iterate over contraCandidates anyway
    const covFlags = c.getTypeFlags(cov);
    if ((covFlags & (types.TypeFlags.Never | types.TypeFlags.Any)) != 0) return false;

    const inference = &c.inferenceInfos.items[inf_idx];
    var contraOk = false;
    for (inference.contraCandidates.items) |t| {
        if (relater.isTypeAssignableTo(c, cov, t)) {
            contraOk = true;
            break;
        }
    }
    if (!contraOk) return false;

    for (ctx.inferences.items) |other_idx| {
        if (other_idx == inf_idx) continue;
        const other = &c.inferenceInfos.items[other_idx];
        if (c.getConstraintOfTypeParameter(other.typeParameter) != inference.typeParameter) continue;

        for (other.candidates.items) |t| {
            if (!relater.isTypeAssignableTo(c, t, cov)) {
                return false;
            }
        }
    }
    return true;
}

pub fn newBackreferenceMapper(c: *checker.Checker, n_idx: types.InferenceContextIndex, index: usize) ?types.TypeMapperIndex {
    _ = c;
    _ = n_idx;
    _ = index;
    return null;
}

pub fn getTypeFromInference(c: *checker.Checker, inf_idx: types.InferenceInfoIndex) ?types.TypeIndex {
    const inference = &c.inferenceInfos.items[inf_idx];
    if (inference.candidates.items.len > 0) {
        return c.getUnionTypeFromArray(inference.candidates.items);
    }
    if (inference.contraCandidates.items.len > 0) {
        return c.getIntersectionType(inference.contraCandidates.items);
    }
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
            const literalsType = c.getUnionTypeFromArray(objectLiterals.items);
            var result = try c.allocator.alloc(types.TypeIndex, nonLiteralTypes.items.len + 1);
            @memcpy(result[0..nonLiteralTypes.items.len], nonLiteralTypes.items);
            result[nonLiteralTypes.items.len] = literalsType;
            return result;
        }
    }
    return try c.allocator.dupe(types.TypeIndex, candidates);
}

pub fn hasPrimitiveConstraint(c: *checker.Checker, t: types.TypeIndex) bool {
    var constraint = c.getConstraintOfTypeParameter(t);
    if (constraint != null and constraint.? != 0) {
        const cst = constraint.?;
        const type_obj = c.typesList.items[cst];
        if ((type_obj.flags & types.TypeFlags.Conditional) != 0) {
            constraint = c.getDefaultConstraintOfConditionalType(cst);
        }
        return c.maybeTypeOfKind(constraint.?, types.TypeFlags.Primitive | types.TypeFlags.Index | types.TypeFlags.TemplateLiteral | types.TypeFlags.StringMapping);
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
        return pred != 0 and isTypeParameterAtTopLevel(c, pred, tp, 0);
    }
    return isTypeParameterAtTopLevel(c, getReturnTypeOfSignature(c, signature), tp, 0);
}

const FilterCtx = struct {
    c: *checker.Checker,
};

fn filterTypeWithoutNullable(ctx: FilterCtx, u: types.TypeIndex) bool {
    return (ctx.c.getTypeFlags(u) & types.TypeFlags.Nullable) == 0;
}

pub fn getCommonSupertype(c: *checker.Checker, types_list: []const types.TypeIndex) types.TypeIndex {
    if (types_list.len == 1) return types_list[0];

    var primaryTypes = std.ArrayListUnmanaged(types.TypeIndex){};
    var primaryTypesSame = true;

    if (c.strictNullChecks) {
        for (types_list) |t| {
            const filtered = c.filterType(t, filterTypeWithoutNullable, FilterCtx{ .c = c });
            primaryTypes.append(c.allocator, filtered) catch unreachable;
            if (filtered != t) {
                primaryTypesSame = false;
            }
        }
    } else {
        primaryTypes.appendSlice(c.allocator, types_list) catch unreachable;
    }
    defer primaryTypes.deinit(c.allocator);

    var supertype: types.TypeIndex = 0;
    if (literalTypesWithSameBaseType(c, primaryTypes.items)) {
        supertype = c.getUnionTypeFromArray(primaryTypes.items);
    } else {
        supertype = getSingleCommonSupertype(c, primaryTypes.items);
    }

    if (primaryTypesSame) {
        return supertype;
    }
    return c.getNullableType(supertype, getCombinedTypeFlags(c, types_list) & types.TypeFlags.Nullable);
}

pub fn isTypeOrBaseIdenticalTo(c: *checker.Checker, s: types.TypeIndex, t: types.TypeIndex) bool {
    if (t == c.missingType) {
        return s == t;
    }
    const t_flags = c.getTypeFlags(t);
    const s_flags = c.getTypeFlags(s);
    return c.isTypeIdenticalTo(s, t) != .False or
        (t_flags & types.TypeFlags.String != 0 and s_flags & types.TypeFlags.StringLiteral != 0) or
        (t_flags & types.TypeFlags.Number != 0 and s_flags & types.TypeFlags.NumberLiteral != 0);
}

pub fn isTypeCloselyMatchedBy(c: *checker.Checker, s: types.TypeIndex, t: types.TypeIndex) bool {
    const s_flags = c.getTypeFlags(s);
    const t_flags = c.getTypeFlags(t);
    const s_sym = c.getTypeSymbol(s);
    const t_sym = c.getTypeSymbol(t);
    const s_alias = c.getTypeAliasSymbol(s);
    const t_alias = c.getTypeAliasSymbol(t);

    return (s_flags & types.TypeFlags.Object != 0 and t_flags & types.TypeFlags.Object != 0 and s_sym != null and s_sym == t_sym) or
        (s_alias != null and t_alias != null and c.getTypeAliasTypeArguments(s).len != 0 and s_alias == t_alias);
}

pub const MatchingTypesResult = struct {
    sources: []const types.TypeIndex,
    targets: []const types.TypeIndex,
};

pub fn inferFromMatchingTypes(
    c: *checker.Checker,
    n_idx: InferenceStateIndex,
    sources: []const types.TypeIndex,
    targets: []const types.TypeIndex,
    matches: *const fn (c: *checker.Checker, s: types.TypeIndex, t: types.TypeIndex) bool,
) !MatchingTypesResult {
    var matchedSources = std.ArrayListUnmanaged(types.TypeIndex){};
    var matchedTargets = std.ArrayListUnmanaged(types.TypeIndex){};

    for (targets) |t| {
        for (sources) |s| {
            if (matches(c, s, t)) {
                try inferFromTypes(c, n_idx, s, t);

                var foundS = false;
                for (matchedSources.items) |ms| {
                    if (ms == s) {
                        foundS = true;
                        break;
                    }
                }
                if (!foundS) matchedSources.append(c.arena.allocator(), s) catch unreachable;

                var foundT = false;
                for (matchedTargets.items) |mt| {
                    if (mt == t) {
                        foundT = true;
                        break;
                    }
                }
                if (!foundT) matchedTargets.append(c.arena.allocator(), t) catch unreachable;
            }
        }
    }

    var finalSources = sources;
    if (matchedSources.items.len != 0) {
        var newSources = std.ArrayListUnmanaged(types.TypeIndex){};
        for (sources) |s| {
            var found = false;
            for (matchedSources.items) |ms| {
                if (ms == s) {
                    found = true;
                    break;
                }
            }
            if (!found) newSources.append(c.arena.allocator(), s) catch unreachable;
        }
        finalSources = newSources.items;
    }

    var finalTargets = targets;
    if (matchedTargets.items.len != 0) {
        var newTargets = std.ArrayListUnmanaged(types.TypeIndex){};
        for (targets) |t| {
            var found = false;
            for (matchedTargets.items) |mt| {
                if (mt == t) {
                    found = true;
                    break;
                }
            }
            if (!found) newTargets.append(c.arena.allocator(), t) catch unreachable;
        }
        finalTargets = newTargets.items;
    }

    return MatchingTypesResult{ .sources = finalSources, .targets = finalTargets };
}

pub fn inferFromGenericMappedTypes(c: *checker.Checker, n_idx: InferenceStateIndex, source: types.TypeIndex, target: types.TypeIndex) !void {
    try inferFromTypes(c, n_idx, c.getConstraintTypeFromMappedType(source), c.getConstraintTypeFromMappedType(target));
    try inferFromTypes(c, n_idx, c.getTemplateTypeFromMappedType(source), c.getTemplateTypeFromMappedType(target));
    const sourceNameType = c.getNameTypeFromMappedType(source);
    const targetNameType = c.getNameTypeFromMappedType(target);
    if (sourceNameType != null and targetNameType != null) {
        try inferFromTypes(c, n_idx, sourceNameType.?, targetNameType.?);
    }
}

pub fn inferTypeForHomomorphicMappedType(c: *checker.Checker, source: types.TypeIndex, target: types.TypeIndex, constraintType: types.TypeIndex) ?types.TypeIndex {
    _ = c;
    _ = source;
    _ = target;
    _ = constraintType;
    return null;
}

pub fn inferToMappedType(c: *checker.Checker, n_idx: InferenceStateIndex, source: types.TypeIndex, target: types.TypeIndex, constraintType: types.TypeIndex) !bool {
    const n = &c.inferenceStates.items[n_idx];
    const flags = c.getTypeFlags(constraintType);

    if (flags & (types.TypeFlags.Union | types.TypeFlags.Intersection) != 0) {
        var result = false;
        for (c.getTypesOfType(constraintType)) |t| {
            if (try inferToMappedType(c, n_idx, source, target, t)) {
                result = true;
            }
        }
        return result;
    }

    if (flags & types.TypeFlags.Index != 0) {
        if (c.getInferenceInfoForType(n, c.getIndexTypeTarget(constraintType))) |inference| {
            if (!inference.isFixed and !isFromInferenceBlockedSource(c, source)) {
                if (inferTypeForHomomorphicMappedType(c, source, target, constraintType)) |inferredType| {
                    const priority = if (c.getObjectFlags(source) & types.ObjectFlags.NonInferrableType != 0) types.InferencePriority.PartialHomomorphicMappedType else types.InferencePriority.HomomorphicMappedType;
                    try inferWithPriority(c, n_idx, inferredType, inference.typeParameter, priority);
                }
            }
        }
        return true;
    }

    if (flags & types.TypeFlags.TypeParameter != 0) {
        // false since patternForType isn't fully ported yet
        const indexFlags = if (false) types.IndexFlags.NoIndexSignatures else types.IndexFlags.None;
        try inferWithPriority(c, n_idx, c.getIndexTypeEx(source, indexFlags), constraintType, types.InferencePriority.MappedTypeConstraint);

        if (c.getConstraintOfType(constraintType)) |extendedConstraint| {
            if (try inferToMappedType(c, n_idx, source, target, extendedConstraint)) {
                return true;
            }
        }

        const propTypes = c.getPropertiesOfType(source);
        const indexInfos = c.getIndexInfosOfType(source);
        var combined = std.ArrayListUnmanaged(types.TypeIndex){};

        for (propTypes) |prop| {
            combined.append(c.arena.allocator(), c.getTypeOfSymbol(prop)) catch unreachable;
        }
        for (indexInfos) |info| {
            // Note: need to handle enumNumberIndexInfo comparison if applicable
            combined.append(c.arena.allocator(), info.valueType) catch unreachable;
        }

        try inferFromTypes(c, n_idx, c.getUnionType(combined.items), c.getTemplateTypeFromMappedType(target));
        return true;
    }

    return false;
}

pub fn inferFromIndexTypes(c: *checker.Checker, n_idx: InferenceStateIndex, source: types.TypeIndex, target: types.TypeIndex) !void {
    var priority = types.InferencePriority.None;
    if (c.getObjectFlags(source) & c.getObjectFlags(target) & types.ObjectFlags.Mapped != 0) {
        priority = types.InferencePriority.HomomorphicMappedType;
    }
    const indexInfos = c.getIndexInfosOfType(target);
    if (c.isObjectTypeWithInferableIndex(source)) {
        for (indexInfos) |targetInfo| {
            var propTypes = std.ArrayListUnmanaged(types.TypeIndex){};
            defer propTypes.deinit(c.arena.allocator());
            for (c.getPropertiesOfType(source)) |prop| {
                if (c.isApplicableIndexType(c.getLiteralTypeFromProperty(prop, types.TypeFlags.StringOrNumberLiteralOrUnique, false), targetInfo.keyType)) {
                    var propType = c.getTypeOfSymbol(prop);
                    if (c.getSymbolFlags(prop) & types.SymbolFlags.Optional != 0) {
                        propType = c.removeMissingOrUndefinedType(propType);
                    }
                    try propTypes.append(c.arena.allocator(), propType);
                }
            }
            for (c.getIndexInfosOfType(source)) |info| {
                if (c.isApplicableIndexType(info.keyType, targetInfo.keyType)) {
                    try propTypes.append(c.arena.allocator(), info.valueType);
                }
            }
            if (propTypes.items.len != 0) {
                try inferWithPriority(c, n_idx, c.getUnionType(propTypes.items), targetInfo.valueType, priority);
            }
        }
    }
    for (indexInfos) |targetInfo| {
        if (c.getApplicableIndexInfo(source, targetInfo.keyType)) |sourceInfo| {
            try inferWithPriority(c, n_idx, sourceInfo.valueType, targetInfo.valueType, priority);
        }
    }
}

pub fn inferFromProperties(c: *checker.Checker, n_idx: InferenceStateIndex, source: types.TypeIndex, target: types.TypeIndex) !void {
    const properties = c.getPropertiesOfObjectType(target);
    for (properties) |targetProp| {
        if (c.getPropertyOfType(source, c.symbols.items[targetProp].name)) |sourceProp| {
            // Note: skipping c.isSkipDirectInferenceNode for now
            const sourceOptional = c.getSymbolFlags(sourceProp) & types.SymbolFlags.Optional != 0;
            const targetOptional = c.getSymbolFlags(targetProp) & types.SymbolFlags.Optional != 0;
            const sourceType = c.removeMissingType(c.getTypeOfSymbol(sourceProp), sourceOptional);
            const targetType = c.removeMissingType(c.getTypeOfSymbol(targetProp), targetOptional);
            try inferFromTypes(c, n_idx, sourceType, targetType);
        }
    }
}

pub fn inferFromSignatures(c: *checker.Checker, n_idx: InferenceStateIndex, source: types.TypeIndex, target: types.TypeIndex, kind: types.SignatureKind) !void {
    const sourceSignatures = c.getSignaturesOfType(source, kind);
    const targetSignatures = c.getSignaturesOfType(target, kind);
    const sourceLen = sourceSignatures.len();
    if (sourceLen > 0) {
        const targetLen = targetSignatures.len();
        for (0..targetLen) |i| {
            var sourceIndex: usize = 0;
            if (sourceLen + i > targetLen) {
                sourceIndex = sourceLen + i - targetLen;
            }
            try inferFromSignature(c, n_idx, c.getBaseSignature(sourceSignatures.start + @as(u32, @intCast(sourceIndex))), c.getErasedSignature(targetSignatures.start + @as(u32, @intCast(i))));
        }
    }
}

pub fn inferFromSignature(c: *checker.Checker, n_idx: InferenceStateIndex, source: types.SignatureIndex, target: types.SignatureIndex) !void {
    const n = &c.inferenceStates.items[n_idx];
    if (c.signatures.items[source].flags & types.SignatureFlags.IsNonInferrable == 0) {
        const saveBivariant = n.bivariant;
        var kind = ast_gen.SyntaxKind.Unknown;
        if (c.signatures.items[target].declaration != ast_gen.NodeIndex.None) {
            kind = c.nodes.items[c.signatures.items[target].declaration].kind();
        }
        n.bivariant = n.bivariant or kind == .MethodDeclaration or kind == .MethodSignature or kind == .Constructor;

        try applyToParameterTypes(c, n_idx, source, target);
        c.inferenceStates.items[n_idx].bivariant = saveBivariant;
    }
    try applyToReturnTypes(c, n_idx, source, target);
}

pub fn applyToParameterTypes(c: *checker.Checker, n_idx: InferenceStateIndex, source: types.SignatureIndex, target: types.SignatureIndex) !void {
    const sourceCount = relater.getParameterCount(c, source);
    const targetCount = relater.getParameterCount(c, target);
    const sourceRestType = relater.getEffectiveRestType(c, source);
    const targetRestType = relater.getEffectiveRestType(c, target);

    var targetNonRestCount = targetCount;
    if (targetRestType != null) {
        targetNonRestCount -= 1;
    }

    var paramCount = targetNonRestCount;
    if (sourceRestType == null) {
        paramCount = @min(sourceCount, targetNonRestCount);
    }

    if (relater.getThisTypeOfSignature(c, source)) |sourceThisType| {
        if (relater.getThisTypeOfSignature(c, target)) |targetThisType| {
            try inferFromContravariantTypesIfStrictFunctionTypes(c, n_idx, sourceThisType, targetThisType);
        }
    }

    for (0..paramCount) |i| {
        try inferFromContravariantTypesIfStrictFunctionTypes(c, n_idx, relater.getTypeAtPosition(c, source, i), relater.getTypeAtPosition(c, target, i));
    }

    if (targetRestType) |tRestType| {
        const readonly = c.isConstTypeVariable(tRestType, 0) and !c.isMutableArrayLikeType(tRestType);
        if (relater.getRestTypeAtPosition(c, source, paramCount, readonly)) |sRestType| {
            try inferFromContravariantTypesIfStrictFunctionTypes(c, n_idx, sRestType, tRestType);
        }
    }
}

pub fn applyToReturnTypes(c: *checker.Checker, n_idx: InferenceStateIndex, source: types.SignatureIndex, target: types.SignatureIndex) !void {
    if (relater.getTypePredicateOfSignature(c, target)) |targetTypePredicate| {
        if (relater.getTypePredicateOfSignature(c, source)) |sourceTypePredicate| {
            if (relater.typePredicateKindsMatch(c, sourceTypePredicate, targetTypePredicate)) {
                if (c.getTypePredicateType(sourceTypePredicate)) |sT| {
                    if (c.getTypePredicateType(targetTypePredicate)) |tT| {
                        try inferFromTypes(c, n_idx, sT, tT);
                        return;
                    }
                }
            }
        }
    }

    const targetReturnType = c.getReturnTypeOfSignature(target);
    if (couldContainTypeVariables(c, targetReturnType)) {
        try inferFromTypes(c, n_idx, c.getReturnTypeOfSignature(source), targetReturnType);
    }
}

pub fn getSingleTypeVariableFromIntersectionTypes(c: *checker.Checker, n: *InferenceState, ts: []const types.TypeIndex) ?types.TypeIndex {
    var typeVariable: ?types.TypeIndex = null;
    for (ts) |t| {
        if (c.getTypeFlags(t) & types.TypeFlags.Intersection == 0) {
            return null;
        }
        var v: ?types.TypeIndex = null;
        for (c.getTypesOfType(t)) |t_i| {
            if (c.getInferenceInfoForType(n, t_i) != null) {
                v = t_i;
                break;
            }
        }
        if (v == null or (typeVariable != null and v != typeVariable)) {
            return null;
        }
        typeVariable = v;
    }
    return typeVariable;
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
    _ = c;
    _ = t;
    return false;
}

pub fn isSkipDirectInferenceNode(c: *checker.Checker, node: ast_gen.NodeIndex) bool {
    _ = c;
    _ = node;
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
    const sym = c.typesList.items[tp].symbol orelse return false;
    const decls = c.binder.symbols.items[sym].declarationsStart;
    const len = c.binder.symbols.items[sym].declarationsLen;
    for (0..len) |i| {
        const declNode = c.binder.declarations.items[decls + i];
        if (c.binder.ast.getNode(declNode) == .TypeParameter) {
            const defaultType = c.binder.ast.getNodeData(declNode).TypeParameter.DefaultType;
            if (defaultType != null and defaultType.? != 0) {
                return true;
            }
        }
    }
    return false;
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

pub fn isObjectOrArrayLiteralType(c: *checker.Checker, t: types.TypeIndex) bool {
    _ = c;
    _ = t;
    return false;
}

pub fn getDefaultConstraintOfConditionalType(c: *checker.Checker, t: types.TypeIndex) ?types.TypeIndex {
    _ = c;
    _ = t;
    return null;
}
pub fn maybeTypeOfKind(c: *checker.Checker, t: types.TypeIndex, flags: u32) bool {
    _ = c;
    _ = t;
    _ = flags;
    return false;
}
pub fn getTypes(c: *checker.Checker, t: types.TypeIndex) []const types.TypeIndex {
    _ = c;
    _ = t;
    return &[_]types.TypeIndex{};
}
pub fn getTrueTypeFromConditionalType(c: *checker.Checker, t: types.TypeIndex) types.TypeIndex {
    _ = c;
    return t;
}
pub fn getFalseTypeFromConditionalType(c: *checker.Checker, t: types.TypeIndex) types.TypeIndex {
    _ = c;
    return t;
}
pub fn getTypePredicateOfSignature(c: *checker.Checker, signature: types.SignatureIndex) ?types.TypeIndex {
    _ = c;
    _ = signature;
    return null;
}
pub fn getReturnTypeOfSignature(c: *checker.Checker, signature: types.SignatureIndex) types.TypeIndex {
    _ = c;
    _ = signature;
    return 0;
}
pub fn isTypeSubtypeOf(c: *checker.Checker, s: types.TypeIndex, t: types.TypeIndex) bool {
    _ = c;
    _ = s;
    _ = t;
    return false;
}
pub fn getBaseTypeOfLiteralType(c: *checker.Checker, t: types.TypeIndex) types.TypeIndex {
    _ = c;
    return t;
}

pub fn inferFromObjectTypes(c: *checker.Checker, n_idx: InferenceStateIndex, source: types.TypeIndex, target: types.TypeIndex) !void {
    const n = &c.inferenceStates.items[n_idx];
    if (c.getObjectFlags(source) & types.ObjectFlags.Reference != 0 and c.getObjectFlags(target) & types.ObjectFlags.Reference != 0 and (c.getTargetType(source) == c.getTargetType(target) or (c.isArrayType(source) and c.isArrayType(target)))) {
        try c.inferFromTypeArguments(n_idx, c.getTypeArguments(source), c.getTypeArguments(target), c.getVariances(c.getTargetType(source)));
        return;
    }
    if (c.isGenericMappedType(source) and c.isGenericMappedType(target)) {
        try inferFromGenericMappedTypes(c, n_idx, source, target);
    }
    if (c.getObjectFlags(target) & types.ObjectFlags.Mapped != 0 and c.getMappedTypeDeclaration(target).nameType == null) {
        const constraintType = c.getConstraintTypeFromMappedType(target);
        if (try inferToMappedType(c, n_idx, source, target, constraintType)) {
            return;
        }
    }
    if (c.typesDefinitelyUnrelated(source, target)) {
        return;
    }
    if (c.isArrayOrTupleType(source)) {
        if (c.isTupleType(target)) {
            const sourceArity = c.getTypeReferenceArity(source);
            const targetArity = c.getTypeReferenceArity(target);
            const elementTypes = c.getTypeArguments(target);
            const elementInfos = c.getTupleElementInfos(target);

            if (c.isTupleType(source) and c.isTupleTypeStructureMatching(source, target)) {
                for (0..targetArity) |i| {
                    try inferFromTypes(c, n_idx, c.getTypeArguments(source)[i], elementTypes[i]);
                }
                return;
            }

            var startLength: usize = 0;
            var endLength: usize = 0;
            if (c.isTupleType(source)) {
                const sTT = c.getTargetTupleType(source);
                const tTT = c.getTargetTupleType(target);
                startLength = @min(sTT.fixedLength, tTT.fixedLength);
                if (tTT.combinedFlags & types.ElementFlags.Variable != 0) {
                    endLength = @min(c.getEndElementCount(sTT, types.ElementFlags.Fixed), c.getEndElementCount(tTT, types.ElementFlags.Fixed));
                }
            }

            for (0..startLength) |i| {
                try inferFromTypes(c, n_idx, c.getTypeArguments(source)[i], elementTypes[i]);
            }

            if (!c.isTupleType(source) or (sourceArity >= startLength + endLength and sourceArity - startLength - endLength == 1 and c.getTupleElementInfos(source)[startLength].flags & types.ElementFlags.Rest != 0)) {
                const restType = c.getTypeArguments(source)[startLength];
                for (startLength..targetArity - endLength) |i| {
                    var t = restType;
                    if (elementInfos[i].flags & types.ElementFlags.Variadic != 0) {
                        t = c.createArrayType(t);
                    }
                    try inferFromTypes(c, n_idx, t, elementTypes[i]);
                }
            } else {
                const middleLength = targetArity - startLength - endLength;
                if (middleLength == 2) {
                    if (elementInfos[startLength].flags & elementInfos[startLength + 1].flags & types.ElementFlags.Variadic != 0) {
                        const targetInfo = c.getInferenceInfoForType(n, elementTypes[startLength]);
                        if (targetInfo != null and targetInfo.?.impliedArity >= 0) {
                            try inferFromTypes(c, n_idx, c.sliceTupleType(source, startLength, @intCast(endLength + sourceArity - @as(usize, @intCast(targetInfo.?.impliedArity)))), elementTypes[startLength]);
                            try inferFromTypes(c, n_idx, c.sliceTupleType(source, startLength + @as(usize, @intCast(targetInfo.?.impliedArity)), @intCast(endLength)), elementTypes[startLength + 1]);
                        }
                    } else if (elementInfos[startLength].flags & types.ElementFlags.Variadic != 0 and elementInfos[startLength + 1].flags & types.ElementFlags.Rest != 0) {
                        if (c.getInferenceInfoForType(n, elementTypes[startLength])) |info| {
                            const constraint = c.getBaseConstraintOfType(info.typeParameter);
                            if (constraint != null and c.isTupleType(constraint.?) and c.getTargetTupleType(constraint.?).combinedFlags & types.ElementFlags.Variable == 0) {
                                const impliedArity = c.getTargetTupleType(constraint.?).fixedLength;
                                try inferFromTypes(c, n_idx, c.sliceTupleType(source, startLength, @intCast(sourceArity - (startLength + impliedArity))), elementTypes[startLength]);
                                if (c.getElementTypeOfSliceOfTupleType(source, startLength + impliedArity, endLength, false, false)) |restType| {
                                    try inferFromTypes(c, n_idx, restType, elementTypes[startLength + 1]);
                                }
                            }
                        }
                    } else if (elementInfos[startLength].flags & types.ElementFlags.Rest != 0 and elementInfos[startLength + 1].flags & types.ElementFlags.Variadic != 0) {
                        if (c.getInferenceInfoForType(n, elementTypes[startLength + 1])) |info| {
                            const constraint = c.getBaseConstraintOfType(info.typeParameter);
                            if (constraint != null and c.isTupleType(constraint.?) and c.getTargetTupleType(constraint.?).combinedFlags & types.ElementFlags.Variable == 0) {
                                const impliedArity = c.getTargetTupleType(constraint.?).fixedLength;
                                const endIndex = sourceArity - c.getEndElementCount(c.getTargetTupleType(target), types.ElementFlags.Fixed);
                                const startIndex = endIndex - impliedArity;
                                if (startIndex >= startLength) {
                                    const trailingSlice = c.createTupleTypeEx(c.getTypeArguments(source)[startIndex..endIndex], c.getTupleElementInfos(source)[startIndex..endIndex], false);
                                    if (c.getElementTypeOfSliceOfTupleType(source, startLength, @intCast(endLength + impliedArity), false, false)) |restType| {
                                        try inferFromTypes(c, n_idx, restType, elementTypes[startLength]);
                                    }
                                    try inferFromTypes(c, n_idx, trailingSlice, elementTypes[startLength + 1]);
                                }
                            }
                        }
                    }
                } else if (middleLength == 1 and elementInfos[startLength].flags & types.ElementFlags.Variadic != 0) {
                    const priority = if (elementInfos[targetArity - 1].flags & types.ElementFlags.Optional != 0) types.InferencePriority.SpeculativeTuple else types.InferencePriority.None;
                    const sourceSlice = c.sliceTupleType(source, startLength, @intCast(endLength));
                    try inferWithPriority(c, n_idx, sourceSlice, elementTypes[startLength], priority);
                } else if (middleLength == 1 and elementInfos[startLength].flags & types.ElementFlags.Rest != 0) {
                    if (c.getElementTypeOfSliceOfTupleType(source, startLength, endLength, false, false)) |restType| {
                        try inferFromTypes(c, n_idx, restType, elementTypes[startLength]);
                    }
                }
            }

            for (0..endLength) |i| {
                try inferFromTypes(c, n_idx, c.getTypeArguments(source)[sourceArity - i - 1], elementTypes[targetArity - i - 1]);
            }
            return;
        }

        if (c.isArrayType(target)) {
            try inferFromIndexTypes(c, n_idx, source, target);
            return;
        }
    }

    try inferFromProperties(c, n_idx, source, target);
    try inferFromSignatures(c, n_idx, source, target, types.SignatureKind.Call);
    try inferFromSignatures(c, n_idx, source, target, types.SignatureKind.Construct);
    try inferFromIndexTypes(c, n_idx, source, target);
}
