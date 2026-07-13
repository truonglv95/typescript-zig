const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const symbol = @import("../ast/symbol.zig");
const types = @import("types.zig");
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const diagnostics = @import("../diagnostics/diagnostics.zig");
const diagnostics_gen = @import("../diagnostics/diagnostics_generated.zig");
const core = @import("../core/core.zig");
const utilities = @import("utilities.zig");

// types.CacheHashKey is u64
const CacheHashKey = types.CacheHashKey;

pub const SignatureCheckMode = u32;
pub const SignatureCheckMode_None: SignatureCheckMode = 0;
pub const SignatureCheckMode_BivariantCallback: SignatureCheckMode = 1 << 0;
pub const SignatureCheckMode_StrictCallback: SignatureCheckMode = 1 << 1;
pub const SignatureCheckMode_IgnoreReturnTypes: SignatureCheckMode = 1 << 2;
pub const SignatureCheckMode_StrictArity: SignatureCheckMode = 1 << 3;
pub const SignatureCheckMode_StrictTopSignature: SignatureCheckMode = 1 << 4;
pub const SignatureCheckMode_Callback: SignatureCheckMode = SignatureCheckMode_BivariantCallback | SignatureCheckMode_StrictCallback;

pub const MinArgumentCountFlags = u32;
pub const MinArgumentCountFlags_None: MinArgumentCountFlags = 0;
pub const MinArgumentCountFlags_StrongArityForUntypedJS: MinArgumentCountFlags = 1 << 0;
pub const MinArgumentCountFlags_VoidIsNonOptional: MinArgumentCountFlags = 1 << 1;

pub const IntersectionState = u32;
pub const IntersectionState_None: IntersectionState = 0;
pub const IntersectionState_Source: IntersectionState = 1 << 0;
pub const IntersectionState_Target: IntersectionState = 1 << 1;

pub const RecursionFlags = u32;
pub const RecursionFlags_None: RecursionFlags = 0;
pub const RecursionFlags_Source: RecursionFlags = 1 << 0;
pub const RecursionFlags_Target: RecursionFlags = 1 << 1;
pub const RecursionFlags_Both: RecursionFlags = RecursionFlags_Source | RecursionFlags_Target;

pub const ExpandingFlags = u8;
pub const ExpandingFlags_None: ExpandingFlags = 0;
pub const ExpandingFlags_Source: ExpandingFlags = 1 << 0;
pub const ExpandingFlags_Target: ExpandingFlags = 1 << 1;
pub const ExpandingFlags_Both: ExpandingFlags = ExpandingFlags_Source | ExpandingFlags_Target;

pub const RelationComparisonResult = u32;
pub const RelationComparisonResult_None: RelationComparisonResult = 0;
pub const RelationComparisonResult_Succeeded: RelationComparisonResult = 1 << 0;
pub const RelationComparisonResult_Failed: RelationComparisonResult = 1 << 1;
pub const RelationComparisonResult_ReportsUnmeasurable: RelationComparisonResult = 1 << 3;
pub const RelationComparisonResult_ReportsUnreliable: RelationComparisonResult = 1 << 4;
pub const RelationComparisonResult_ComplexityOverflow: RelationComparisonResult = 1 << 5;
pub const RelationComparisonResult_StackDepthOverflow: RelationComparisonResult = 1 << 6;
pub const RelationComparisonResult_ReportsMask: RelationComparisonResult = RelationComparisonResult_ReportsUnmeasurable | RelationComparisonResult_ReportsUnreliable;
pub const RelationComparisonResult_Overflow: RelationComparisonResult = RelationComparisonResult_ComplexityOverflow | RelationComparisonResult_StackDepthOverflow;

pub const VarianceFlags = u8;
pub const VarianceFlags_Invariant: VarianceFlags = 0;
pub const VarianceFlags_Covariant: VarianceFlags = 1 << 0;
pub const VarianceFlags_Contravariant: VarianceFlags = 1 << 1;
pub const VarianceFlags_Bivariant: VarianceFlags = VarianceFlags_Covariant | VarianceFlags_Contravariant;
pub const VarianceFlags_Independent: VarianceFlags = 1 << 2;
pub const VarianceFlags_VarianceMask: VarianceFlags = VarianceFlags_Covariant | VarianceFlags_Contravariant | VarianceFlags_Independent;
pub const VarianceFlags_Unmeasurable: VarianceFlags = 1 << 3;
pub const VarianceFlags_Unreliable: VarianceFlags = 1 << 4;

pub const DiagnosticAndArguments = struct {
    message: *const diagnostics_gen.Message,
    arguments: [][]const u8,
};

pub const ErrorOutputContainer = struct {
    errors: std.ArrayListUnmanaged(diagnostics.Diagnostic),
    skipLogging: bool = false,
};

pub const ErrorReporter = ?*const fn (message: *const diagnostics_gen.Message, args: []const []const u8) void;

pub const RecursionId = struct {
    value: u64,
};

pub fn asRecursionId(value: anytype) RecursionId {
    return .{ .value = @as(u64, @intCast(value)) };
}

pub const Relation = struct {
    results: ?std.AutoHashMapUnmanaged(CacheHashKey, RelationComparisonResult) = null,

    pub fn get(self: *Relation, key: CacheHashKey) RelationComparisonResult {
        if (self.results) |*r| {
            return r.get(key) orelse RelationComparisonResult_None;
        }
        return RelationComparisonResult_None;
    }

    pub fn set(self: *Relation, allocator: std.mem.Allocator, key: CacheHashKey, result: RelationComparisonResult) !void {
        if (self.results == null) {
            self.results = .empty;
        }
        try self.results.?.put(allocator, key, result);
    }

    pub fn size(self: *const Relation) usize {
        if (self.results) |*r| {
            return r.count();
        }
        return 0;
    }

    pub fn deinit(self: *Relation, allocator: std.mem.Allocator) void {
        if (self.results) |*r| {
            r.deinit(allocator);
        }
    }
};

pub const ErrorChain = struct {
    message: *const diagnostics_gen.Message,
    args: [][]const u8,
    next: ?*ErrorChain = null,
};

pub fn chainDepth(chain: ?*ErrorChain) usize {
    var depth: usize = 0;
    var current = chain;
    while (current != null) {
        depth += 1;
        current = current.?.next;
    }
    return depth;
}

pub const ErrorState = struct {
    errorChain: ?*ErrorChain = null,
    relatedInfo: ?[]diagnostics.Diagnostic = null,
};

pub const Relater = struct {
    c: *Checker,
    relation: *Relation,
    errorNode: ?ast.NodeIndex = null,
    errorChain: ?*ErrorChain = null,
    relatedInfo: std.ArrayListUnmanaged(diagnostics.Diagnostic) = .empty,
    maybeKeys: std.ArrayListUnmanaged(CacheHashKey) = .empty,
    maybeKeysSet: std.AutoHashMapUnmanaged(CacheHashKey, void) = .empty,
    sourceStack: std.ArrayListUnmanaged(types.TypeIndex) = .empty,
    targetStack: std.ArrayListUnmanaged(types.TypeIndex) = .empty,
    maybeCount: usize = 0,
    sourceDepth: usize = 0,
    targetDepth: usize = 0,
    expandingFlags: ExpandingFlags = ExpandingFlags_None,
    overflow: bool = false,
    relationCount: isize = 0,
    next: ?*Relater = null,

    pub fn unionOrIntersectionRelatedTo(r: *Relater, source: types.TypeIndex, target: types.TypeIndex, reportErrors: bool, intersectionState: IntersectionState) types.Ternary {
        const c = r.c;
        const source_flags = c.getTypeFlags(source);
        const target_flags = c.getTypeFlags(target);

        if (source_flags & types.TypeFlags.Union != 0) {
            if (target_flags & types.TypeFlags.Union != 0) {
                const sourceOrigin = c.getOriginOfUnionType(source);
                if (sourceOrigin != 0 and c.getTypeFlags(sourceOrigin) & types.TypeFlags.Intersection != 0 and c.getAliasSymbol(target) != 0 and c.containsType(c.getTypesOfUnionOrIntersectionType(sourceOrigin), target)) {
                    return .True;
                }

                const targetOrigin = c.getOriginOfUnionType(target);
                if (targetOrigin != 0 and c.getTypeFlags(targetOrigin) & types.TypeFlags.Union != 0 and c.getAliasSymbol(source) != 0 and c.containsType(c.getTypesOfUnionOrIntersectionType(targetOrigin), source)) {
                    return .True;
                }
            }
            if (r.relation == &c.comparableRelation) {
                return r.someTypeRelatedToType(source, target, reportErrors and source_flags & types.TypeFlags.Primitive == 0, intersectionState);
            }
            return r.eachTypeRelatedToType(source, target, reportErrors and source_flags & types.TypeFlags.Primitive == 0, intersectionState);
        }
        if (target_flags & types.TypeFlags.Union != 0) {
            return r.typeRelatedToSomeType(c.getRegularTypeOfObjectLiteral(source), target, reportErrors and source_flags & types.TypeFlags.Primitive == 0 and target_flags & types.TypeFlags.Primitive == 0, intersectionState);
        }
        if (target_flags & types.TypeFlags.Intersection != 0) {
            return r.typeRelatedToEachType(source, target, reportErrors, .Target);
        }

        if (r.relation == &c.comparableRelation and target_flags & types.TypeFlags.Primitive != 0) {
            var constraints_alloc = std.ArrayList(types.TypeIndex).init(c.allocator);
            defer constraints_alloc.deinit();
            var same = true;

            for (c.getTypesOfUnionOrIntersectionType(source)) |t| {
                if (c.getTypeFlags(t) & types.TypeFlags.Instantiable != 0) {
                    const constraint = c.getBaseConstraintOfType(t);
                    if (constraint) |cnst| {
                        constraints_alloc.append(cnst) catch unreachable;
                    } else {
                        constraints_alloc.append(c.unknownTypeIndex orelse 0) catch unreachable;
                    }
                    same = false;
                } else {
                    constraints_alloc.append(t) catch unreachable;
                }
            }

            if (!same) {
                const newSource = c.getIntersectionType(constraints_alloc.items);
                if (c.getTypeFlags(newSource) & types.TypeFlags.Never != 0) {
                    return .False;
                }
                if (c.getTypeFlags(newSource) & types.TypeFlags.Intersection == 0) {
                    const result = r.isRelatedTo(newSource, target, RecursionFlags_Source, false);
                    if (result != .False) {
                        return result;
                    }
                    return r.isRelatedTo(target, newSource, RecursionFlags_Source, false);
                }
            }
        }

        return r.someTypeRelatedToType(source, target, false, .Source);
    }

    pub fn typeRelatedToEachType(r: *Relater, source: types.TypeIndex, target: types.TypeIndex, reportErrors: bool, intersectionState: IntersectionState) types.Ternary {
        const c = r.c;
        var result = types.Ternary.True;
        const targetTypes = c.getTypesOfUnionOrIntersectionType(target);
        for (targetTypes) |targetType| {
            const related = r.isRelatedToEx(source, targetType, RecursionFlags_Target, reportErrors, null, intersectionState);
            if (related == .False) {
                return .False;
            }
            result = types.Ternary.andValues(result, related);
        }
        return result;
    }

    pub fn someTypeRelatedToType(r: *Relater, source: types.TypeIndex, target: types.TypeIndex, reportErrors: bool, intersectionState: IntersectionState) types.Ternary {
        const c = r.c;
        const sourceTypes = c.getTypesOfUnionOrIntersectionType(source);
        if (c.getTypeFlags(source) & types.TypeFlags.Union != 0 and c.containsType(sourceTypes, target)) {
            return .True;
        }
        for (sourceTypes, 0..) |t, i| {
            const related = r.isRelatedToEx(t, target, RecursionFlags_Source, reportErrors and i == sourceTypes.len - 1, null, intersectionState);
            if (related != .False) {
                return related;
            }
        }
        return .False;
    }

    pub fn eachTypeRelatedToType(r: *Relater, source: types.TypeIndex, target: types.TypeIndex, reportErrors: bool, intersectionState: IntersectionState) types.Ternary {
        const c = r.c;
        var result = types.Ternary.True;
        const sourceTypes = c.getTypesOfUnionOrIntersectionType(source);

        var strippedTarget = target;
        if (c.getTypeFlags(source) & types.TypeFlags.Union != 0 and c.getTypeFlags(target) & types.TypeFlags.Union != 0 and c.getTypeFlags(sourceTypes[0]) & types.TypeFlags.Undefined == 0 and c.getTypeFlags(c.getTypesOfUnionOrIntersectionType(target)[0]) & types.TypeFlags.Undefined != 0) {
            strippedTarget = c.extractTypesOfKind(target, ~@as(u32, @intFromEnum(types.TypeFlags.Undefined)));
        }

        var strippedTypes: []const types.TypeIndex = &[_]types.TypeIndex{};
        if (c.getTypeFlags(strippedTarget) & types.TypeFlags.Union != 0) {
            strippedTypes = c.getTypesOfUnionOrIntersectionType(strippedTarget);
        }

        for (sourceTypes, 0..) |sourceType, i| {
            if (c.getTypeFlags(strippedTarget) & types.TypeFlags.Union != 0 and sourceTypes.len >= strippedTypes.len and sourceTypes.len % strippedTypes.len == 0) {
                const related = r.isRelatedToEx(sourceType, strippedTypes[i % strippedTypes.len], RecursionFlags_Both, false, null, intersectionState);
                if (related != .False) {
                    result = types.Ternary.andValues(result, related);
                    continue;
                }
            }
            const related = r.isRelatedToEx(sourceType, target, RecursionFlags_Source, reportErrors, null, intersectionState);
            if (related == .False) {
                return .False;
            }
            result = types.Ternary.andValues(result, related);
        }
        return result;
    }

    const CombinationContext = struct {
        combination: []const types.TypeIndex,

        pub fn getTypeOfSourceProperty(ctx: *const CombinationContext, sym: types.SymbolIndex) types.TypeIndex {
            _ = ctx;
            _ = sym;
            // In Go: func(*ast.Symbol) *Type { return combination[i] }
            // Wait, we need the index `i`!
            unreachable;
        }
    };

    pub fn getChainMessage(r: *Relater, index: usize) ?*const diagnostics.Message {
        var e = r.errorChain;
        var i = index;
        while (true) {
            if (e == null) {
                return null;
            }
            if (i == 0) {
                return e.?.message;
            }
            e = e.?.next;
            i -= 1;
        }
    }
    pub fn typeRelatedToDiscriminatedType(r: *Relater, source: types.TypeIndex, target: types.TypeIndex) types.Ternary {
        const c = r.c;
        const sourceProperties = c.getPropertiesOfType(source);
        const sourcePropertiesFiltered = c.findDiscriminantProperties(sourceProperties, target);
        if (sourcePropertiesFiltered.len == 0) {
            return .False;
        }

        var numCombinations: usize = 1;
        for (sourcePropertiesFiltered) |sourceProperty| {
            numCombinations *= c.countTypes(c.getNonMissingTypeOfSymbol(sourceProperty));
            if (numCombinations > 25) {
                // tracing
                return .False;
            }
            if (numCombinations == 0) {
                return .False;
            }
        }

        var sourceDiscriminantTypes = std.ArrayList([]const types.TypeIndex).init(c.allocator);
        var excludedProperties = std.StringHashMap(void).init(c.allocator);
        for (sourcePropertiesFiltered) |sourceProperty| {
            const sourcePropertyType = c.getNonMissingTypeOfSymbol(sourceProperty);
            sourceDiscriminantTypes.append(c.distributedTypes(sourcePropertyType)) catch unreachable;
            excludedProperties.put(c.getSymbolName(sourceProperty), {}) catch unreachable;
        }

        var discriminantCombinations = std.ArrayList([]const types.TypeIndex).init(c.allocator);
        for (0..numCombinations) |i| {
            var combination = std.ArrayList(types.TypeIndex).init(c.allocator);
            combination.resize(sourceDiscriminantTypes.items.len) catch unreachable;
            var n = i;
            var j: isize = @as(isize, @intCast(sourceDiscriminantTypes.items.len)) - 1;
            while (j >= 0) : (j -= 1) {
                const sourceTypes = sourceDiscriminantTypes.items[@as(usize, @intCast(j))];
                const length = sourceTypes.len;
                combination.items[@as(usize, @intCast(j))] = sourceTypes[n % length];
                n = n / length;
            }
            discriminantCombinations.append(combination.items) catch unreachable;
        }

        var matchingTypes = std.ArrayList(types.TypeIndex).init(c.allocator);
        for (discriminantCombinations.items) |combination| {
            var hasMatch = false;
            outer: for (c.getTypesOfUnionOrIntersectionType(target)) |t| {
                for (sourcePropertiesFiltered, 0..) |sourceProperty, i| {
                    const targetProperty = c.getPropertyOfType(t, c.getSymbolName(sourceProperty));
                    if (targetProperty == 0) {
                        continue :outer;
                    }
                    if (sourceProperty == targetProperty) {
                        continue;
                    }

                    // Context for closures
                    const Ctx = struct {
                        comb: []const types.TypeIndex,
                        idx: usize,
                        pub fn get(ctx: @This(), sym: types.SymbolIndex) types.TypeIndex {
                            _ = sym;
                            return ctx.comb[ctx.idx];
                        }
                    };
                    const ctx = Ctx{ .comb = combination, .idx = i };

                    const related = r.propertyRelatedTo(source, target, sourceProperty, targetProperty, ctx, Ctx.get, false, .None, c.strictNullChecks or r.relation == &c.comparableRelation);
                    if (related == .False) {
                        continue :outer;
                    }
                }
                c.appendIfUniqueTypeIndex(&matchingTypes, t);
                hasMatch = true;
            }
            if (!hasMatch) {
                return .False;
            }
        }

        var result = types.Ternary.True;
        for (matchingTypes.items) |t| {
            result = types.Ternary.andValues(result, r.propertiesRelatedTo(source, t, false, &excludedProperties, false, .None));
            if (result != .False) {
                result = types.Ternary.andValues(result, r.signaturesRelatedTo(source, t, types.SignatureKind.Call, false, .None));
                if (result != .False) {
                    result = types.Ternary.andValues(result, r.signaturesRelatedTo(source, t, types.SignatureKind.Construct, false, .None));
                    if (result != .False and !(c.isTupleType(source) and c.isTupleType(t))) {
                        result = types.Ternary.andValues(result, r.indexSignaturesRelatedTo(source, t, false, false, false, .None));
                    }
                }
            }
            if (result == .False) {
                return result;
            }
        }
        return result;
    }

    pub fn propertiesRelatedTo(r: *Relater, source: types.TypeIndex, target: types.TypeIndex, reportErrors: bool, excludedProperties: ?*std.StringHashMap(void), optionalsOnly: bool, intersectionState: IntersectionState) types.Ternary {
        const c = r.c;
        if (r.relation == &c.identityRelation) {
            return r.propertiesIdenticalTo(source, target, excludedProperties);
        }
        var result = types.Ternary.True;

        if (c.isTupleType(target)) {
            if (c.isArrayOrTupleType(source)) {
                if (!c.getTargetTupleType(target).readonly and (c.isReadonlyArrayType(source) or (c.isTupleType(source) and c.getTargetTupleType(source).readonly))) {
                    return .False;
                }
                const sourceArity = c.getTypeReferenceArity(source);
                const targetArity = c.getTypeReferenceArity(target);
                var sourceRest = false;
                if (c.isTupleType(source)) {
                    sourceRest = c.getTargetTupleType(source).combinedFlags & types.ElementFlags.Rest != 0;
                } else {
                    sourceRest = true;
                }
                const targetHasRestElement = c.getTargetTupleType(target).combinedFlags & types.ElementFlags.Variable != 0;
                var sourceMinLength: usize = 0;
                if (c.isTupleType(source)) {
                    sourceMinLength = c.getTargetTupleType(source).minLength;
                } else {
                    sourceMinLength = 0;
                }
                const targetMinLength = c.getTargetTupleType(target).minLength;
                if (!sourceRest and sourceArity < targetMinLength) {
                    if (reportErrors) {
                        // TODO: r.reportError(diagnostics.Source_has_0_element_s_but_target_requires_1, sourceArity, targetMinLength)
                    }
                    return .False;
                }
                if (!targetHasRestElement and targetArity < sourceMinLength) {
                    if (reportErrors) {
                        // TODO: r.reportError(diagnostics.Source_has_0_element_s_but_target_allows_only_1, sourceMinLength, targetArity)
                    }
                    return .False;
                }
                if (!targetHasRestElement and (sourceRest or targetArity < sourceArity)) {
                    if (reportErrors) {
                        // TODO
                    }
                    return .False;
                }
                const sourceTypeArguments = c.getTypeArguments(source);
                const targetTypeArguments = c.getTypeArguments(target);
                const targetStartCount = c.getStartElementCount(c.getTargetTupleType(target), types.ElementFlags.NonRest);
                const targetEndCount = c.getEndElementCount(c.getTargetTupleType(target), types.ElementFlags.NonRest);
                var canExcludeDiscriminants = if (excludedProperties) |ep| ep.count() != 0 else false;

                var sourcePosition: usize = 0;
                while (sourcePosition < sourceArity) : (sourcePosition += 1) {
                    var sourceFlags: u32 = 0;
                    if (c.isTupleType(source)) {
                        sourceFlags = c.getTupleElementInfos(source)[sourcePosition].flags;
                    } else {
                        sourceFlags = types.ElementFlags.Rest;
                    }
                    const sourcePositionFromEnd = sourceArity - 1 - sourcePosition;
                    var targetPosition: usize = 0;
                    if (targetHasRestElement and sourcePosition >= targetStartCount) {
                        targetPosition = targetArity - 1 - @min(sourcePositionFromEnd, targetEndCount);
                    } else {
                        targetPosition = sourcePosition;
                    }
                    var targetFlags: u32 = types.ElementFlags.None;
                    if (targetPosition >= 0) {
                        targetFlags = c.getTupleElementInfos(target)[targetPosition].flags;
                    }
                    if (targetFlags & types.ElementFlags.Variadic != 0 and sourceFlags & types.ElementFlags.Variadic == 0) {
                        if (reportErrors) {
                            // TODO
                        }
                        return .False;
                    }
                    if (sourceFlags & types.ElementFlags.Variadic != 0 and targetFlags & types.ElementFlags.Variable == 0) {
                        if (reportErrors) {
                            // TODO
                        }
                        return .False;
                    }
                    if (targetFlags & types.ElementFlags.Required != 0 and sourceFlags & types.ElementFlags.Required == 0) {
                        if (reportErrors) {
                            // TODO
                        }
                        return .False;
                    }
                    if (canExcludeDiscriminants) {
                        if (sourceFlags & types.ElementFlags.Variable != 0 or targetFlags & types.ElementFlags.Variable != 0) {
                            canExcludeDiscriminants = false;
                        }
                        var buf: [32]u8 = undefined;
                        const posStr = std.fmt.bufPrint(&buf, "{d}", .{sourcePosition}) catch unreachable;
                        if (canExcludeDiscriminants and excludedProperties.?.contains(posStr)) {
                            continue;
                        }
                    }

                    const sourceType = c.removeMissingType(sourceTypeArguments[sourcePosition], sourceFlags & targetFlags & types.ElementFlags.Optional != 0);
                    const targetType = targetTypeArguments[targetPosition];
                    var targetCheckType: types.TypeIndex = 0;
                    if (sourceFlags & types.ElementFlags.Variadic != 0 and targetFlags & types.ElementFlags.Rest != 0) {
                        targetCheckType = c.createArrayType(targetType);
                    } else {
                        targetCheckType = c.removeMissingType(targetType, targetFlags & types.ElementFlags.Optional != 0);
                    }
                    const related = r.isRelatedToEx(sourceType, targetCheckType, RecursionFlags_Both, reportErrors, null, intersectionState);
                    if (related == .False) {
                        if (reportErrors and (targetArity > 1 or sourceArity > 1)) {
                            // TODO: report
                        }
                        return .False;
                    }
                    result = types.Ternary.andValues(result, related);
                }
                return result;
            }
            if (c.getTargetTupleType(target).combinedFlags & types.ElementFlags.Variable != 0) {
                return .False;
            }
        }

        const requireOptionalProperties = (r.relation == &c.subtypeRelation or r.relation == &c.strictSubtypeRelation) and !c.isObjectLiteralType(source) and !c.isEmptyArrayLiteralType(source) and !c.isTupleType(source);
        const unmatchedProperty = c.getUnmatchedProperty(source, target, requireOptionalProperties, false);
        if (unmatchedProperty != 0) {
            if (reportErrors and c.shouldReportUnmatchedPropertyError(source, target)) {
                r.reportUnmatchedProperty(source, target, unmatchedProperty, requireOptionalProperties);
            }
            return .False;
        }

        if (c.isObjectLiteralType(target)) {
            const props = c.getPropertiesOfType(source);
            for (props) |sourceProp| {
                if (excludedProperties != null and excludedProperties.?.contains(c.getSymbolName(sourceProp))) continue;
                if (c.getPropertyOfObjectType(target, c.getSymbolName(sourceProp)) == 0) {
                    if (reportErrors) {
                        // TODO
                    }
                    return .False;
                }
            }
        }

        const properties = c.getPropertiesOfType(target);
        const numericNamesOnly = c.isTupleType(source) and c.isTupleType(target);
        for (properties) |targetProp| {
            if (excludedProperties != null and excludedProperties.?.contains(c.getSymbolName(targetProp))) continue;
            const name = c.getSymbolName(targetProp);
            const flags = c.getSymbolFlags(targetProp);
            if (flags & types.SymbolFlags.Prototype == 0 and (!numericNamesOnly or c.isNumericLiteralName(name) or std.mem.eql(u8, name, "length")) and (!optionalsOnly or flags & types.SymbolFlags.Optional != 0)) {
                const sourceProp = c.getPropertyOfType(source, name);
                if (sourceProp != 0 and sourceProp != targetProp) {
                    const ctx = c;
                    const related = r.propertyRelatedTo(source, target, sourceProp, targetProp, ctx, Checker.getNonMissingTypeOfSymbol, reportErrors, intersectionState, r.relation == &c.comparableRelation);
                    if (related == .False) {
                        return .False;
                    }
                    result = types.Ternary.andValues(result, related);
                }
            }
        }

        return result;
    }

    pub fn propertyRelatedTo(r: *Relater, source: types.TypeIndex, target: types.TypeIndex, sourceProp: types.SymbolIndex, targetProp: types.SymbolIndex, context: anytype, comptime getTypeOfSourceProperty: fn (ctx: @TypeOf(context), sym: types.SymbolIndex) types.TypeIndex, reportErrors: bool, intersectionState: IntersectionState, skipOptional: bool) types.Ternary {
        _ = source;
        _ = target;
        const c = r.c;
        if (r.relation == &c.identityRelation) {
            return r.isPropertySymbolTypeRelated(sourceProp, targetProp, context, getTypeOfSourceProperty, reportErrors, intersectionState);
        }

        const sourceFlags = c.getSymbolFlags(sourceProp);
        const targetFlags = c.getSymbolFlags(targetProp);

        if (sourceFlags & types.SymbolFlags.Optional != 0 and targetFlags & types.SymbolFlags.Optional == 0 and !skipOptional) {
            if (reportErrors) {
                // TODO: r.reportError(diagnostics.Property_0_is_optional_in_type_1_but_required_in_type_2, c.symbolToString(sourceProp), c.TypeToString(source), c.TypeToString(target))
            }
            return .False;
        }

        if (sourceFlags & types.SymbolFlags.Optional == 0 and targetFlags & types.SymbolFlags.Optional != 0 and c.exactOptionalPropertyTypes) {
            if (reportErrors) {
                // TODO: r.reportError(diagnostics.Property_0_is_required_in_type_1_but_optional_in_type_2, c.symbolToString(sourceProp), c.TypeToString(source), c.TypeToString(target))
            }
            return .False;
        }

        if (targetFlags & types.SymbolFlags.Method != 0 and sourceFlags & types.SymbolFlags.Method == 0 and c.strictFunctionTypes) {
            const sourceType = c.getNonMissingTypeOfSymbol(sourceProp);
            if (c.isTypeRelatedTo(sourceType, c.globalFunctionType, &c.subtypeRelation)) {
                if (reportErrors) {
                    // TODO: r.reportError(diagnostics.Type_of_property_0_circularly_references_itself_in_mapped_type_1, c.symbolToString(sourceProp), c.TypeToString(target))
                }
                return .False;
            }
        }

        if (c.isSetAccessorSymbol(targetProp) and !c.isGetAccessorSymbol(targetProp)) {
            return .True;
        }

        return r.isPropertySymbolTypeRelated(sourceProp, targetProp, context, getTypeOfSourceProperty, reportErrors, intersectionState);
    }

    pub fn isPropertySymbolTypeRelated(r: *Relater, sourceProp: types.SymbolIndex, targetProp: types.SymbolIndex, context: anytype, comptime getTypeOfSourceProperty: fn (ctx: @TypeOf(context), sym: types.SymbolIndex) types.TypeIndex, reportErrors: bool, intersectionState: IntersectionState) types.Ternary {
        _ = r;
        _ = sourceProp;
        _ = targetProp;
        _ = getTypeOfSourceProperty;
        _ = reportErrors;
        _ = intersectionState;
        return .False; // Stub
    }

    pub fn reportUnmatchedProperty(r: *Relater, source: types.TypeIndex, target: types.TypeIndex, unmatchedProperty: types.SymbolIndex, requireOptionalProperties: bool) void {
        _ = r;
        _ = source;
        _ = target;
        _ = unmatchedProperty;
        _ = requireOptionalProperties;
        // Stub
    }

    pub fn signaturesRelatedTo(r: *Relater, source: types.TypeIndex, target: types.TypeIndex, kind: types.SignatureKind, reportErrors: bool, intersectionState: IntersectionState) types.Ternary {
        const c = r.c;
        if (r.relation == &c.identityRelation) {
            return r.signaturesIdenticalTo(source, target, kind);
        }

        if (source == c.anyFunctionType) {
            return .True;
        }
        if (target == c.anyFunctionType) {
            return .False;
        }

        const sourceSignatures = c.getSignaturesOfType(source, kind);
        const targetSignatures = c.getSignaturesOfType(target, kind);

        if (kind == types.SignatureKind.Construct and sourceSignatures.len != 0 and targetSignatures.len != 0) {
            const sourceIsAbstract = sourceSignatures[0].flags & types.SignatureFlags.Abstract != 0;
            const targetIsAbstract = targetSignatures[0].flags & types.SignatureFlags.Abstract != 0;
            if (sourceIsAbstract and !targetIsAbstract) {
                if (reportErrors) {
                    // TODO: r.reportError(diagnostics.Cannot_assign_an_abstract_constructor_type_to_a_non_abstract_constructor_type)
                }
                return .False;
            }
            if (!r.constructorVisibilitiesAreCompatible(sourceSignatures[0], targetSignatures[0], reportErrors)) {
                return .False;
            }
        }

        var result = types.Ternary.True;
        const sourceObjectFlags = c.getObjectFlags(source);
        const targetObjectFlags = c.getObjectFlags(target);
        if ((sourceObjectFlags & types.ObjectFlags.Instantiated != 0 and targetObjectFlags & types.ObjectFlags.Instantiated != 0 and c.getSymbol(source) == c.getSymbol(target)) or
            (sourceObjectFlags & types.ObjectFlags.Reference != 0 and targetObjectFlags & types.ObjectFlags.Reference != 0 and c.getTargetType(source) == c.getTargetType(target)))
        {
            for (targetSignatures, 0..) |t, i| {
                const s = sourceSignatures[i];
                const related = r.signatureRelatedTo(s, t, true, reportErrors, intersectionState);
                if (related == .False) {
                    return .False;
                }
                result = types.Ternary.andValues(result, related);
            }
        } else if (sourceSignatures.len == 1 and targetSignatures.len == 1) {
            const eraseGenerics = r.relation == &c.comparableRelation;
            result = r.signatureRelatedTo(sourceSignatures[0], targetSignatures[0], eraseGenerics, reportErrors, intersectionState);
        } else {
            outer: for (targetSignatures) |t| {
                const saveErrorState = r.getErrorState();
                var shouldElaborateErrors = reportErrors;
                for (sourceSignatures) |s| {
                    const related = r.signatureRelatedTo(s, t, true, shouldElaborateErrors, intersectionState);
                    if (related != .False) {
                        result = types.Ternary.andValues(result, related);
                        r.restoreErrorState(saveErrorState);
                        continue :outer;
                    }
                    shouldElaborateErrors = false;
                }
                if (shouldElaborateErrors) {
                    // TODO: r.reportError(diagnostics.Type_0_provides_no_match_for_the_signature_1, c.TypeToString(source), c.signatureToString(t))
                }
                return .False;
            }
        }

        return result;
    }

    pub fn constructorVisibilitiesAreCompatible(r: *Relater, sourceSignature: *types.Signature, targetSignature: *types.Signature, reportErrors: bool) bool {
        const c = r.c;
        if (sourceSignature.declaration == 0 or targetSignature.declaration == 0) {
            return true;
        }
        const sourceAccessibility = c.getModifierFlags(sourceSignature.declaration) & types.ModifierFlags.NonPublicAccessibilityModifier;
        const targetAccessibility = c.getModifierFlags(targetSignature.declaration) & types.ModifierFlags.NonPublicAccessibilityModifier;

        if (targetAccessibility == types.ModifierFlags.Private) {
            return true;
        }
        if (targetAccessibility == types.ModifierFlags.Protected and sourceAccessibility != types.ModifierFlags.Private) {
            return true;
        }
        if (targetAccessibility != types.ModifierFlags.Protected and sourceAccessibility == 0) {
            return true;
        }
        if (reportErrors) {
            // TODO: r.reportError(diagnostics.Cannot_assign_a_0_constructor_type_to_a_1_constructor_type, visibilityToString(sourceAccessibility), visibilityToString(targetAccessibility))
        }
        return false;
    }

    pub fn reportErrorStub(r: *Relater, msg: types.DiagnosticMessage) void {
        _ = r;
        _ = msg;
        // Stub
    }

    pub fn signatureRelatedTo(r: *Relater, source: *types.Signature, target: *types.Signature, erase: bool, reportErrors: bool, intersectionState: IntersectionState) types.Ternary {
        const c = r.c;
        var checkMode = types.SignatureCheckMode.None;
        if (r.relation == &c.subtypeRelation) {
            checkMode = types.SignatureCheckMode.StrictTopSignature;
        } else if (r.relation == &c.strictSubtypeRelation) {
            checkMode = types.SignatureCheckMode.StrictTopSignature | types.SignatureCheckMode.StrictArity;
        }

        var effectiveSource = source;
        var effectiveTarget = target;
        if (erase) {
            effectiveSource = c.getErasedSignature(source);
            effectiveTarget = c.getErasedSignature(target);
        }

        // isRelatedToWorker := func(source *Type, target *Type, reportErrors bool) Ternary {
        //  return r.isRelatedToEx(source, target, RecursionFlagsBoth, reportErrors, nil /*headMessage*/, intersectionState)
        // }

        // Ctx struct
        const Ctx = struct {
            r: *Relater,
            intersectionState: IntersectionState,
            pub fn isRelatedToWorker(ctx: @This(), s: types.TypeIndex, t: types.TypeIndex, reportErr: bool) types.Ternary {
                return ctx.r.isRelatedToEx(s, t, RecursionFlags_Both, reportErr, null, ctx.intersectionState);
            }
        };
        const ctx = Ctx{ .r = r, .intersectionState = intersectionState };

        return c.compareSignaturesRelated(effectiveSource, effectiveTarget, checkMode, reportErrors, r, Relater.reportErrorStub, ctx, Ctx.isRelatedToWorker, c, Checker.reportUnreliableMapperStub);
    }

    pub fn getUndefinedStrippedTargetIfNeeded(r: *Relater, source: types.TypeIndex, target: types.TypeIndex) types.TypeIndex {
        const c = r.c;
        const sourceFlags = c.getTypeFlags(source);
        const targetFlags = c.getTypeFlags(target);
        if ((sourceFlags & types.TypeFlags.Union) != 0 and (targetFlags & types.TypeFlags.Union) != 0) {
            const sourceTypes = c.getTypesOfUnionOrIntersectionType(source);
            const targetTypes = c.getTypesOfUnionOrIntersectionType(target);
            if (sourceTypes.len > 0 and targetTypes.len > 0) {
                if ((c.getTypeFlags(sourceTypes[0]) & types.TypeFlags.Undefined) == 0 and (c.getTypeFlags(targetTypes[0]) & types.TypeFlags.Undefined) != 0) {
                    return c.extractTypesOfKind(target, ~@as(u32, types.TypeFlags.Undefined));
                }
            }
        }
        return target;
    }

    pub fn typeRelatedToSomeType(r: *Relater, source: types.TypeIndex, target: types.TypeIndex, reportErrors: bool, intersectionState: IntersectionState) types.Ternary {
        const c = r.c;
        const targetTypes = c.getTypesOfUnionOrIntersectionType(target);
        if (c.getTypeFlags(target) & types.TypeFlags.Union != 0) {
            if (c.containsType(targetTypes, source)) {
                return .True;
            }
            const source_flags = c.getTypeFlags(source);
            if (r.relation != &c.comparableRelation and c.getObjectFlags(target) & types.ObjectFlags.PrimitiveUnion != 0 and source_flags & types.TypeFlags.EnumLiteral == 0 and
                (source_flags & (types.TypeFlags.StringLiteral | types.TypeFlags.BooleanLiteral | types.TypeFlags.BigIntLiteral) != 0 or
                    (r.relation == &c.subtypeRelation or r.relation == &c.strictSubtypeRelation) and source_flags & types.TypeFlags.NumberLiteral != 0))
            {
                var alternateForm: ?types.TypeIndex = null;
                if (source == c.getRegularTypeOfLiteralType(source)) {
                    alternateForm = c.getFreshTypeOfLiteralType(source);
                } else {
                    alternateForm = c.getRegularTypeOfLiteralType(source);
                }
                var primitive: ?types.TypeIndex = null;
                if (source_flags & types.TypeFlags.StringLiteral != 0) {
                    primitive = c.stringType;
                } else if (source_flags & types.TypeFlags.NumberLiteral != 0) {
                    primitive = c.numberType;
                } else if (source_flags & types.TypeFlags.BigIntLiteral != 0) {
                    primitive = c.bigintType;
                }

                if ((primitive != null and c.containsType(targetTypes, primitive.?)) or (alternateForm != null and c.containsType(targetTypes, alternateForm.?))) {
                    return .True;
                }
                return .False;
            }
            const match = c.getMatchingUnionConstituentForType(target, source);
            if (match) |m| {
                const related = r.isRelatedToEx(source, m, RecursionFlags_Target, false, null, intersectionState);
                if (related != .False) {
                    return related;
                }
            }
        }
        for (targetTypes) |t| {
            const related = r.isRelatedToEx(source, t, RecursionFlags_Target, false, null, intersectionState);
            if (related != .False) {
                return related;
            }
        }
        if (reportErrors) {
            const bestMatchingType = c.getBestMatchingType(source, target, r);
            if (bestMatchingType) |bmt| {
                _ = r.isRelatedToEx(source, bmt, RecursionFlags_Target, true, null, intersectionState);
            }
        }
        return .False;
    }

    pub fn eachTypeRelatedToSomeType(r: *Relater, source: types.TypeIndex, target: types.TypeIndex) types.Ternary {
        _ = r;
        _ = source;
        _ = target;
        return .False; // Stub
    }

    pub fn recursiveTypeRelatedTo(r: *Relater, source: types.TypeIndex, target: types.TypeIndex, reportErrors: bool, intersectionState: IntersectionState, recursionFlags: RecursionFlags) types.Ternary {
        _ = r;
        _ = source;
        _ = target;
        _ = reportErrors;
        _ = intersectionState;
        _ = recursionFlags;
        return .False; // Stub
    }

    pub fn resetMaybeStack(r: *Relater, maybeStart: usize, propagatingVarianceFlags: RelationComparisonResult, markAllAsSucceeded: bool) void {
        _ = r;
        _ = maybeStart;
        _ = propagatingVarianceFlags;
        _ = markAllAsSucceeded;
    }

    pub fn getErrorState(r: *Relater) ErrorState {
        _ = r;
        return .{}; // Stub
    }

    pub fn restoreErrorState(r: *Relater, e: ErrorState) void {
        _ = r;
        _ = e;
    }

    pub fn structuredTypeRelatedTo(r: *Relater, source: types.TypeIndex, target: types.TypeIndex, reportErrors: bool, intersectionState: IntersectionState) types.Ternary {
        const c = r.c;
        const saveErrorState = r.getErrorState();
        var result = r.structuredTypeRelatedToWorker(source, target, reportErrors, intersectionState);

        if (r.relation != &c.identityRelation) {
            const source_flags = c.getTypeFlags(source);
            const target_flags = c.getTypeFlags(target);
            if (result == .False and (source_flags & types.TypeFlags.Intersection != 0 or (source_flags & types.TypeFlags.TypeParameter != 0 and target_flags & types.TypeFlags.Union != 0))) {
                // var sourceTypes []*Type
                const sourceTypes = if (source_flags & types.TypeFlags.Intersection != 0) c.getTypes(source) else @as([]const types.TypeIndex, &[_]types.TypeIndex{source});
                const constraint = c.getEffectiveConstraintOfIntersection(sourceTypes, target_flags & types.TypeFlags.Union != 0);
                if (constraint) |cnst| {
                    if (c.everyType(cnst, struct {
                        fn predicate(ctx: types.TypeIndex, t: types.TypeIndex) bool {
                            return t != ctx;
                        }
                    }.predicate, source)) {
                        result = r.isRelatedToEx(cnst, target, RecursionFlags_Source, false, null, intersectionState);
                    }
                }
            }

            if (result != .False and intersectionState & IntersectionState_Target == 0 and target_flags & types.TypeFlags.Intersection != 0 and !c.isGenericObjectType(target) and source_flags & (types.TypeFlags.Object | types.TypeFlags.Intersection) != 0) {
                result = types.Ternary.andValues(result, r.propertiesRelatedTo(source, target, reportErrors, false, IntersectionState_None));
                if (result != .False and c.isObjectLiteralType(source) and c.getObjectFlags(source) & types.ObjectFlags.FreshLiteral != 0) {
                    result = types.Ternary.andValues(result, r.indexSignaturesRelatedTo(source, target, false, reportErrors, IntersectionState_None));
                }
            } else if (result != .False and c.isNonGenericObjectType(target) and !c.isArrayOrTupleType(target) and r.isSourceIntersectionNeedingExtraCheck(source, target)) {
                result = types.Ternary.andValues(result, r.propertiesRelatedTo(source, target, reportErrors, true, intersectionState));
            }
        }

        if (result != .False) {
            r.restoreErrorState(saveErrorState);
        }
        return result;
    }

    pub fn isSourceIntersectionNeedingExtraCheck(r: *Relater, source: types.TypeIndex, target: types.TypeIndex) bool {
        const c = r.c;
        if (c.getTypeFlags(source) & types.TypeFlags.Intersection != 0 and c.getTypeFlags(c.getApparentType(source)) & types.TypeFlags.StructuredType != 0) {
            return !c.someType(source, struct {
                fn predicate(ctx: struct { c: *Checker, target: types.TypeIndex }, t: types.TypeIndex) bool {
                    return t == ctx.target or ctx.c.getObjectFlags(t) & types.ObjectFlags.NonInferrableType != 0;
                }
            }.predicate, .{ .c = c, .target = target });
        }
        return false;
    }

    fn relateVariances(r: *Relater, sourceTypeArguments: []const types.TypeIndex, targetTypeArguments: []const types.TypeIndex, variances: []const types.VarianceFlags, intersectionState: IntersectionState, reportErrors: bool, varianceCheckFailed: *bool, originalErrorChain: *?*ErrorChain, saveErrorState: ErrorState) ?types.Ternary {
        const result = r.typeArgumentsRelatedTo(sourceTypeArguments, targetTypeArguments, variances, reportErrors, intersectionState);
        if (result != .False) {
            return result;
        }
        for (variances) |v| {
            if (@intFromEnum(v) & @intFromEnum(types.VarianceFlags.AllowsStructuralFallback) != 0) {
                originalErrorChain.* = null;
                r.restoreErrorState(saveErrorState);
                return .False;
            }
        }
        const allowStructuralFallback = r.c.hasCovariantVoidArgument(targetTypeArguments, variances);
        varianceCheckFailed.* = !allowStructuralFallback;
        if (variances.len != 0 and !allowStructuralFallback) {
            var hasInvariant = false;
            for (variances) |v| {
                if (@intFromEnum(v) & @intFromEnum(types.VarianceFlags.VarianceMask) == @intFromEnum(types.VarianceFlags.Invariant)) {
                    hasInvariant = true;
                    break;
                }
            }
            if (varianceCheckFailed.* and !(reportErrors and hasInvariant)) {
                return .False;
            }
            originalErrorChain.* = r.errorChain;
            r.restoreErrorState(saveErrorState);
        }
        return null;
    }

    pub fn structuredTypeRelatedToWorker(r: *Relater, source: types.TypeIndex, target: types.TypeIndex, reportErrors: bool, intersectionState: IntersectionState) types.Ternary {
        const c = r.c;
        var result: types.Ternary = .False;
        var varianceCheckFailed: bool = false;
        var originalErrorChain: ?*ErrorChain = null;
        const saveErrorState = r.getErrorState();

        _ = &varianceCheckFailed;
        _ = &originalErrorChain;

        const source_flags = c.getTypeFlags(source);
        const target_flags = c.getTypeFlags(target);

        if (r.relation == &c.identityRelation) {
            if (source_flags & types.TypeFlags.UnionOrIntersection != 0) {
                result = r.eachTypeRelatedToSomeType(source, target);
                if (result != .False) {
                    result = types.Ternary.andValues(result, r.eachTypeRelatedToSomeType(target, source));
                }
                return result;
            } else if (source_flags & types.TypeFlags.Index != 0) {
                return r.isRelatedTo(c.getTargetType(source), c.getTargetType(target), RecursionFlags_Both, false);
            } else if (source_flags & types.TypeFlags.IndexedAccess != 0) {
                result = r.isRelatedTo(c.getObjectTypeFromIndexedAccessType(source), c.getObjectTypeFromIndexedAccessType(target), RecursionFlags_Both, false);
                if (result != .False) {
                    result = types.Ternary.andValues(result, r.isRelatedTo(c.getIndexTypeFromIndexedAccessType(source), c.getIndexTypeFromIndexedAccessType(target), RecursionFlags_Both, false));
                    if (result != .False) {
                        return result;
                    }
                }
            } else if (source_flags & types.TypeFlags.Conditional != 0) {
                const sourceRoot = c.getRootOfConditionalType(source);
                const targetRoot = c.getRootOfConditionalType(target);
                if (c.isDistributionDependent(sourceRoot) == c.isDistributionDependent(targetRoot)) {
                    result = r.isRelatedTo(c.getCheckTypeFromConditionalType(source), c.getCheckTypeFromConditionalType(target), RecursionFlags_Both, false);
                    if (result != .False) {
                        result = types.Ternary.andValues(result, r.isRelatedTo(c.getExtendsTypeFromConditionalType(source), c.getExtendsTypeFromConditionalType(target), RecursionFlags_Both, false));
                        if (result != .False) {
                            result = types.Ternary.andValues(result, r.isRelatedTo(c.getTrueTypeFromConditionalType(source), c.getTrueTypeFromConditionalType(target), RecursionFlags_Both, false));
                            if (result != .False) {
                                result = types.Ternary.andValues(result, r.isRelatedTo(c.getFalseTypeFromConditionalType(source), c.getFalseTypeFromConditionalType(target), RecursionFlags_Both, false));
                                if (result != .False) {
                                    return result;
                                }
                            }
                        }
                    }
                }
            } else if (source_flags & types.TypeFlags.Substitution != 0) {
                result = r.isRelatedTo(c.getBaseTypeFromSubstitutionType(source), c.getBaseTypeFromSubstitutionType(target), RecursionFlags_Both, false);
                if (result != .False) {
                    result = types.Ternary.andValues(result, r.isRelatedTo(c.getConstraintFromSubstitutionType(source), c.getConstraintFromSubstitutionType(target), RecursionFlags_Both, false));
                    if (result != .False) {
                        return result;
                    }
                }
            } else if (source_flags & types.TypeFlags.TemplateLiteral != 0) {
                if (c.templateLiteralTextsEqual(source, target)) {
                    result = .True;
                    const sourceTypes = c.getTypesFromTemplateLiteralType(source);
                    const targetTypes = c.getTypesFromTemplateLiteralType(target);
                    for (sourceTypes, 0..) |sourceType, i| {
                        const targetType = targetTypes[i];
                        result = types.Ternary.andValues(result, r.isRelatedTo(sourceType, targetType, RecursionFlags_Both, false));
                        if (result == .False) {
                            return result;
                        }
                    }
                    return result;
                }
            } else if (source_flags & types.TypeFlags.StringMapping != 0) {
                if (c.getSymbolFromStringMappingType(source) == c.getSymbolFromStringMappingType(target)) {
                    return r.isRelatedTo(c.getTargetTypeFromStringMappingType(source), c.getTargetTypeFromStringMappingType(target), RecursionFlags_Both, false);
                }
            }
            if (source_flags & types.TypeFlags.Object == 0) {
                return .False;
            }
        } else if (source_flags & types.TypeFlags.UnionOrIntersection != 0 or target_flags & types.TypeFlags.UnionOrIntersection != 0) {
            result = r.unionOrIntersectionRelatedTo(source, target, reportErrors, intersectionState);
            if (result != .False) {
                return result;
            }
            if (!(source_flags & types.TypeFlags.Instantiable != 0 or
                source_flags & types.TypeFlags.Object != 0 and target_flags & types.TypeFlags.Union != 0 or
                source_flags & types.TypeFlags.Intersection != 0 and target_flags & (types.TypeFlags.Object | types.TypeFlags.Union | types.TypeFlags.Instantiable) != 0))
            {
                if (source_flags & types.TypeFlags.Mapped != 0) {
                    const mappedType = c.getTargetType(source);
                    const nameType = c.getNameTypeFromMappedType(mappedType);
                    var sourceMappedKeys: types.TypeIndex = undefined;
                    if (nameType != null and c.isMappedTypeWithKeyofConstraintDeclaration(mappedType)) {
                        sourceMappedKeys = c.getApparentMappedTypeKeys(nameType.?, mappedType);
                    } else if (nameType != null) {
                        sourceMappedKeys = nameType.?;
                    } else {
                        sourceMappedKeys = c.getConstraintTypeFromMappedType(mappedType);
                    }
                    result = r.isRelatedTo(sourceMappedKeys, target, RecursionFlags_Source, reportErrors);
                    if (result != .False) {
                        return result;
                    }
                }
                return .False;
            }
        } else if (source_flags & types.TypeFlags.Conditional != 0) {
            if (c.isDeeplyNestedType(source, r.sourceStack.items, 10)) {
                return .Maybe;
            }
            if (target_flags & types.TypeFlags.Conditional != 0) {
                const sourceParams = c.getInferTypeParametersFromConditionalType(source);
                var sourceExtends = c.getExtendsTypeFromConditionalType(source);
                const mapper: ?types.TypeMapperIndex = null;
                if (sourceParams.len != 0) {
                    _ = c.newInferenceContext(sourceParams, null, types.InferenceFlags.None, .RelatedToWorker);
                    // c.inferTypes(ctx.inferences, c.getExtendsTypeFromConditionalType(target), sourceExtends, types.InferencePriority.NoConstraints | types.InferencePriority.AlwaysStrict, false);
                    sourceExtends = c.instantiateType(sourceExtends, 0); // Need context.mapper
                    // mapper = ctx.mapper;
                }
                if (c.isTypeIdenticalTo(sourceExtends, c.getExtendsTypeFromConditionalType(target)) and
                    (r.isRelatedTo(c.getCheckTypeFromConditionalType(source), c.getCheckTypeFromConditionalType(target), RecursionFlags_Both, false) != 0 or
                        r.isRelatedTo(c.getCheckTypeFromConditionalType(target), c.getCheckTypeFromConditionalType(source), RecursionFlags_Both, false) != 0))
                {
                    result = r.isRelatedTo(c.instantiateType(c.getTrueTypeFromConditionalType(source), mapper orelse 0), c.getTrueTypeFromConditionalType(target), RecursionFlags_Both, reportErrors);
                    if (result != .False) {
                        result = types.Ternary.andValues(result, r.isRelatedTo(c.getFalseTypeFromConditionalType(source), c.getFalseTypeFromConditionalType(target), RecursionFlags_Both, reportErrors));
                    }
                    if (result != .False) {
                        return result;
                    }
                }
            }
            const defaultConstraint = c.getDefaultConstraintOfConditionalType(source);
            if (defaultConstraint) |dc| {
                result = r.isRelatedTo(dc, target, RecursionFlags_Source, reportErrors);
                if (result != .False) {
                    return result;
                }
            }
            if (target_flags & types.TypeFlags.Conditional == 0 and c.hasNonCircularBaseConstraint(source)) {
                const distributiveConstraint = c.getConstraintOfDistributiveConditionalType(source);
                if (distributiveConstraint) |dc| {
                    r.restoreErrorState(saveErrorState);
                    result = r.isRelatedTo(dc, target, RecursionFlags_Source, reportErrors);
                    if (result != .False) {
                        return result;
                    }
                }
            }
        } else if (source_flags & types.TypeFlags.TemplateLiteral != 0 and target_flags & types.TypeFlags.Object == 0) {
            if (target_flags & types.TypeFlags.TemplateLiteral == 0) {
                const constraint = c.getBaseConstraintOfType(source);
                if (constraint != null and constraint.? != source) {
                    result = r.isRelatedTo(constraint.?, target, RecursionFlags_Source, reportErrors);
                    if (result != .False) {
                        return result;
                    }
                }
            }
        } else if (source_flags & types.TypeFlags.StringMapping != 0) {
            if (target_flags & types.TypeFlags.StringMapping != 0) {
                if (c.getSymbolFromStringMappingType(source) != c.getSymbolFromStringMappingType(target)) {
                    return .False;
                }
                result = r.isRelatedTo(c.getTargetTypeFromStringMappingType(source), c.getTargetTypeFromStringMappingType(target), RecursionFlags_Both, reportErrors);
                if (result != .False) {
                    return result;
                }
            } else {
                const constraint = c.getBaseConstraintOfType(source);
                if (constraint) |cnst| {
                    result = r.isRelatedTo(cnst, target, RecursionFlags_Source, reportErrors);
                    if (result != .False) {
                        return result;
                    }
                }
            }
        } else {
            if (r.relation != &c.subtypeRelation and r.relation != &c.strictSubtypeRelation and c.isPartialMappedType(target) and c.isEmptyObjectType(source)) {
                return .True;
            }
            if (c.isGenericMappedType(target)) {
                if (c.isGenericMappedType(source)) {
                    result = r.mappedTypeRelatedTo(source, target, reportErrors);
                    if (result != .False) {
                        return result;
                    }
                }
                return .False;
            }
            const sourceIsPrimitive = source_flags & types.TypeFlags.Primitive != 0;
            var mappedSource = source;
            if (r.relation != &c.identityRelation) {
                mappedSource = c.getApparentType(source);
            } else if (c.isGenericMappedType(source)) {
                return .False;
            }

            if (c.getObjectFlags(mappedSource) & types.ObjectFlags.Reference != 0 and c.getObjectFlags(target) & types.ObjectFlags.Reference != 0 and c.getTargetType(mappedSource) == c.getTargetType(target) and !c.isTupleType(mappedSource) and !c.isMarkerType(mappedSource) and !c.isMarkerType(target)) {
                if (c.isEmptyArrayLiteralType(mappedSource)) {
                    return .True;
                }
                const variances = c.getVariances(c.getTargetType(mappedSource));
                if (variances.len == 0) {
                    return .Unknown;
                }
                if (relateVariances(r, c.getTypeArguments(mappedSource), c.getTypeArguments(target), variances, intersectionState, reportErrors, &varianceCheckFailed, &originalErrorChain, saveErrorState)) |varianceResult| {
                    return varianceResult;
                }
            } else if (c.isArrayType(target) and (c.isReadonlyArrayType(target) and c.everyType(mappedSource, struct {
                fn predicate(ctx: *Checker, t: types.TypeIndex) bool {
                    return ctx.isArrayOrTupleType(t);
                }
            }.predicate) or c.everyType(mappedSource, struct {
                fn predicate(ctx: *Checker, t: types.TypeIndex) bool {
                    return ctx.isMutableTupleType(t);
                }
            }.predicate))) {
                if (r.relation != &c.identityRelation) {
                    return r.isRelatedTo(c.getIndexTypeOfTypeEx(mappedSource, c.numberType, c.anyType), c.getIndexTypeOfTypeEx(target, c.numberType, c.anyType), RecursionFlags_Both, reportErrors);
                }
                return .False;
            } else if (c.isGenericTupleType(mappedSource) and c.isTupleType(target) and !c.isGenericTupleType(target)) {
                const constraint = c.getBaseConstraintOrType(mappedSource);
                if (constraint != mappedSource) {
                    return r.isRelatedTo(constraint, target, RecursionFlags_Source, reportErrors);
                }
            } else if ((r.relation == &c.subtypeRelation or r.relation == &c.strictSubtypeRelation) and c.isEmptyObjectType(target) and c.getObjectFlags(target) & types.ObjectFlags.FreshLiteral != 0 and !c.isEmptyObjectType(mappedSource)) {
                return .False;
            }

            if ((c.getTypeFlags(mappedSource) & (types.TypeFlags.Object | types.TypeFlags.Intersection) != 0 or sourceIsPrimitive and r.relation != &c.identityRelation) and target_flags & types.TypeFlags.Object != 0) {
                const reportStructuralErrors = reportErrors and r.errorChain == saveErrorState.errorChain and !sourceIsPrimitive;
                result = r.propertiesRelatedTo(mappedSource, target, reportStructuralErrors, false, intersectionState);
                if (result != .False) {
                    result = types.Ternary.andValues(result, r.signaturesRelatedTo(mappedSource, target, types.SignatureKind.Call, reportStructuralErrors, intersectionState));
                    if (result != .False) {
                        result = types.Ternary.andValues(result, r.signaturesRelatedTo(mappedSource, target, types.SignatureKind.Construct, reportStructuralErrors, intersectionState));
                        if (result != .False) {
                            result = types.Ternary.andValues(result, r.indexSignaturesRelatedTo(mappedSource, target, sourceIsPrimitive, reportStructuralErrors, intersectionState));
                        }
                    }
                }
                if (result != .False) {
                    if (!varianceCheckFailed) {
                        return result;
                    }
                }
                if (reportErrors) {
                    if (originalErrorChain) |oec| {
                        r.errorChain = oec;
                    } else if (r.errorChain == null) {
                        r.errorChain = saveErrorState.errorChain;
                    }
                }
            }
        }

        if (c.getTypeFlags(source) & (types.TypeFlags.Object | types.TypeFlags.Intersection) != 0 and c.getTypeFlags(target) & types.TypeFlags.Union != 0) {
            const objectOnlyTarget = c.extractTypesOfKind(target, types.TypeFlags.Object | types.TypeFlags.Intersection | types.TypeFlags.Substitution);
            if (c.getTypeFlags(objectOnlyTarget) & types.TypeFlags.Union != 0) {
                result = r.typeRelatedToDiscriminatedType(source, objectOnlyTarget);
                if (result != .False) {
                    return result;
                }
            }
        }

        return .False;
    }

    pub fn typeArgumentsRelatedTo(r: *Relater, sources: []const types.TypeIndex, targets: []const types.TypeIndex, variances: []const types.VarianceFlags, reportErrors: bool, intersectionState: IntersectionState) types.Ternary {
        const c = r.c;
        if (sources.len != targets.len and r.relation == &c.identityRelation) {
            return .False;
        }
        const length = @min(sources.len, targets.len);
        var result = types.Ternary.True;

        for (0..length) |i| {
            var varianceFlags = types.VarianceFlags.Covariant;
            if (i < variances.len) {
                varianceFlags = variances[i];
            }
            const variance = @intFromEnum(varianceFlags) & @intFromEnum(types.VarianceFlags.VarianceMask);

            if (variance != @intFromEnum(types.VarianceFlags.Independent)) {
                const s = sources[i];
                const t = targets[i];
                var related: types.Ternary = undefined;

                if (@intFromEnum(varianceFlags) & @intFromEnum(types.VarianceFlags.Unmeasurable) != 0) {
                    if (r.relation == &c.identityRelation) {
                        related = r.isRelatedTo(s, t, RecursionFlags_Both, false);
                    } else {
                        related = c.compareTypesIdentical(s, t);
                    }
                } else {
                    if (c.inVarianceComputation and @intFromEnum(varianceFlags) & @intFromEnum(types.VarianceFlags.Unreliable) != 0) {
                        _ = c.instantiateType(s, c.reportUnreliableMapper(0)); // Pass a dummy mapper for now
                    }

                    if (variance == @intFromEnum(types.VarianceFlags.Covariant)) {
                        related = r.isRelatedToEx(s, t, RecursionFlags_Both, reportErrors, null, intersectionState);
                    } else if (variance == @intFromEnum(types.VarianceFlags.Contravariant)) {
                        related = r.isRelatedToEx(t, s, RecursionFlags_Both, reportErrors, null, intersectionState);
                    } else if (variance == @intFromEnum(types.VarianceFlags.Bivariant)) {
                        related = r.isRelatedTo(t, s, RecursionFlags_Both, false);
                        if (related == .False) {
                            related = r.isRelatedToEx(s, t, RecursionFlags_Both, reportErrors, null, intersectionState);
                        }
                    } else {
                        related = r.isRelatedToEx(s, t, RecursionFlags_Both, reportErrors, null, intersectionState);
                        if (related != .False) {
                            related = types.Ternary.andValues(related, r.isRelatedToEx(t, s, RecursionFlags_Both, reportErrors, null, intersectionState));
                        }
                    }
                }
                if (related == .False) {
                    return .False;
                }
                result = types.Ternary.andValues(result, related);
            }
        }
        return result;
    }

    pub fn mappedTypeRelatedTo(r: *Relater, source: types.TypeIndex, target: types.TypeIndex, reportErrors: bool) types.Ternary {
        const c = r.c;
        const modifiersRelated = r.relation == &c.comparableRelation or
            (r.relation == &c.identityRelation and @intFromEnum(c.getMappedTypeModifiers(source)) == @intFromEnum(c.getMappedTypeModifiers(target))) or
            (r.relation != &c.identityRelation and c.getCombinedMappedTypeOptionality(source) <= c.getCombinedMappedTypeOptionality(target));

        if (modifiersRelated) {
            const targetConstraint = c.getConstraintTypeFromMappedType(target);
            var mapper_type: types.TypeMapperIndex = 0;
            if (c.getCombinedMappedTypeOptionality(source) < 0) {
                mapper_type = c.reportUnmeasurableMapper(0);
            } else {
                mapper_type = c.reportUnreliableMapper(0);
            }
            const sourceConstraint = c.instantiateType(c.getConstraintTypeFromMappedType(source), mapper_type);

            if (r.isRelatedTo(targetConstraint, sourceConstraint, RecursionFlags_Both, reportErrors) != .False) {
                const mapper = checker_mod.addTypeMapper(c, .{ .kind = .Simple, .data = .{ .Simple = .{ .source = c.getTypeParameterFromMappedType(source), .target = c.getTypeParameterFromMappedType(target) } } });
                if (c.instantiateType(c.getNameTypeFromMappedType(source), mapper) == c.instantiateType(c.getNameTypeFromMappedType(target), mapper)) {
                    return types.Ternary.andValues(r.isRelatedTo(targetConstraint, sourceConstraint, RecursionFlags_Both, reportErrors), r.isRelatedTo(c.instantiateType(c.getTemplateTypeFromMappedType(source), mapper), c.getTemplateTypeFromMappedType(target), RecursionFlags_Both, reportErrors));
                }
            }
        }
        return .False;
    }

    pub fn tryElaborateArrayLikeErrors(r: *Relater, source: types.TypeIndex, target: types.TypeIndex, reportErrors: bool) bool {
        _ = r;
        _ = source;
        _ = target;
        _ = reportErrors;
        return false; // Stub
    }

    pub fn tryElaborateErrorsForPrimitivesAndObjects(r: *Relater, source: types.TypeIndex, target: types.TypeIndex) void {
        _ = r;
        _ = source;
        _ = target;
    }

    pub fn propertiesIdenticalTo(r: *Relater, source: types.TypeIndex, target: types.TypeIndex) types.Ternary {
        _ = r;
        _ = source;
        _ = target;
        return .False; // Stub
    }

    pub fn signaturesIdenticalTo(r: *Relater, source: types.TypeIndex, target: types.TypeIndex, kind: types.SignatureKind) types.Ternary {
        const c = r.c;
        const sourceSignatures = c.getSignaturesOfType(source, kind);
        const targetSignatures = c.getSignaturesOfType(target, kind);
        if (sourceSignatures.len != targetSignatures.len) {
            return .False;
        }

        var result = types.Ternary.True;
        for (sourceSignatures, 0..) |s, i| {
            const t = targetSignatures[i];
            const Ctx = struct {
                r: *Relater,
                pub fn isRelatedToSimple(ctx: @This(), src: types.TypeIndex, tgt: types.TypeIndex) types.Ternary {
                    return ctx.r.isRelatedToSimple(src, tgt);
                }
            };
            const ctx = Ctx{ .r = r };
            const related = c.compareSignaturesIdentical(s, t, false, false, false, ctx, Ctx.isRelatedToSimple);
            if (related == .False) {
                return .False;
            }
            result = types.Ternary.andValues(result, related);
        }
        return result;
    }

    pub fn indexSignaturesRelatedTo(r: *Relater, source: types.TypeIndex, target: types.TypeIndex, sourceIsPrimitive: bool, reportErrors: bool, intersectionState: IntersectionState) types.Ternary {
        const c = r.c;
        if (r.relation == &c.identityRelation) {
            return r.indexSignaturesIdenticalTo(source, target);
        }

        const indexInfos = c.getIndexInfosOfType(target);
        var targetHasStringIndex = false;
        for (indexInfos) |info| {
            if (c.getIndexInfoKeyType(info) == c.stringType) {
                targetHasStringIndex = true;
                break;
            }
        }

        var result = types.Ternary.True;
        for (indexInfos) |info| {
            const valType = c.getIndexInfoValueType(info);
            var related = types.Ternary.False;
            if (r.relation != &c.strictSubtypeRelation and !sourceIsPrimitive and targetHasStringIndex and c.getTypeFlags(valType) & types.TypeFlags.Any != 0) {
                related = .True;
            } else if (c.isGenericMappedType(source) and targetHasStringIndex) {
                related = r.isRelatedTo(c.getTemplateTypeFromMappedType(source), valType, RecursionFlags_Both, reportErrors);
            } else {
                related = r.typeRelatedToIndexInfo(source, info, reportErrors, intersectionState);
            }

            if (related == .False) {
                return .False;
            }
            result = types.Ternary.andValues(result, related);
        }

        return result;
    }

    pub fn typeRelatedToIndexInfo(r: *Relater, source: types.TypeIndex, targetInfo: types.IndexInfoIndex, reportErrors: bool, intersectionState: IntersectionState) types.Ternary {
        const c = r.c;
        const sourceInfo = c.getApplicableIndexInfo(source, c.getIndexInfoKeyType(targetInfo));
        if (sourceInfo) |sInfo| {
            return r.indexInfoRelatedTo(sInfo, targetInfo, reportErrors, intersectionState);
        }

        if (intersectionState & IntersectionState_Source == 0 and (r.relation != &c.strictSubtypeRelation or c.getObjectFlags(source) & types.ObjectFlags.FreshLiteral != 0) and c.isObjectTypeWithInferableIndex(source)) {
            return r.membersRelatedToIndexInfo(source, targetInfo, reportErrors, intersectionState);
        }

        if (reportErrors) {
            // TODO: r.reportError(diagnostics.Index_signature_for_type_0_is_missing_in_type_1, c.TypeToString(c.getIndexInfoKeyType(targetInfo)), c.TypeToString(source))
        }
        return .False;
    }

    pub fn membersRelatedToIndexInfo(r: *Relater, source: types.TypeIndex, targetInfo: types.IndexInfoIndex, reportErrors: bool, intersectionState: IntersectionState) types.Ternary {
        const c = r.c;
        var result = types.Ternary.True;
        const keyType = c.getIndexInfoKeyType(targetInfo);

        const props = if (c.getTypeFlags(source) & types.TypeFlags.Intersection != 0)
            c.getPropertiesOfUnionOrIntersectionType(source)
        else
            c.getPropertiesOfObjectType(source);

        for (props) |prop| {
            if (c.isIgnoredJsxProperty(source, prop)) {
                continue;
            }
            if (c.isApplicableIndexType(c.getLiteralTypeFromProperty(prop, types.TypeFlags.StringOrNumberLiteralOrUnique, false), keyType)) {
                const propType = c.getNonMissingTypeOfSymbol(prop);
                var t: types.TypeIndex = undefined;
                if (c.exactOptionalPropertyTypes or c.getTypeFlags(propType) & types.TypeFlags.Undefined != 0 or keyType == c.numberType or c.getSymbolFlags(prop) & types.SymbolFlags.Optional == 0) {
                    t = propType;
                } else {
                    t = c.getTypeWithFacts(propType, types.TypeFacts.NEUndefined);
                }
                const related = r.isRelatedToEx(t, c.getIndexInfoValueType(targetInfo), RecursionFlags_Both, reportErrors, null, intersectionState);
                if (related == .False) {
                    if (reportErrors) {
                        // TODO: r.reportError(diagnostics.Property_0_is_incompatible_with_index_signature, c.symbolToString(prop))
                    }
                    return .False;
                }
                result = types.Ternary.andValues(result, related);
            }
        }

        for (c.getIndexInfosOfType(source)) |info| {
            if (c.isApplicableIndexType(c.getIndexInfoKeyType(info), keyType)) {
                const related = r.indexInfoRelatedTo(info, targetInfo, reportErrors, intersectionState);
                if (related == .False) {
                    return .False;
                }
                result = types.Ternary.andValues(result, related);
            }
        }
        return result;
    }

    pub fn indexInfoRelatedTo(r: *Relater, sourceInfo: types.IndexInfoIndex, targetInfo: types.IndexInfoIndex, reportErrors: bool, intersectionState: IntersectionState) types.Ternary {
        const c = r.c;
        const related = r.isRelatedToEx(c.getIndexInfoValueType(sourceInfo), c.getIndexInfoValueType(targetInfo), RecursionFlags_Both, reportErrors, null, intersectionState);
        if (related == .False and reportErrors) {
            if (c.getIndexInfoKeyType(sourceInfo) == c.getIndexInfoKeyType(targetInfo)) {
                // TODO: r.reportError(diagnostics.X_0_index_signatures_are_incompatible, c.TypeToString(c.getIndexInfoKeyType(sourceInfo)))
            } else {
                // TODO: r.reportError(diagnostics.X_0_and_1_index_signatures_are_incompatible, c.TypeToString(c.getIndexInfoKeyType(sourceInfo)), c.TypeToString(c.getIndexInfoKeyType(targetInfo)))
            }
        }
        return related;
    }

    pub fn indexSignaturesIdenticalTo(r: *Relater, source: types.TypeIndex, target: types.TypeIndex) types.Ternary {
        const c = r.c;
        const sourceInfos = c.getIndexInfosOfType(source);
        const targetInfos = c.getIndexInfosOfType(target);
        if (sourceInfos.len != targetInfos.len) {
            return .False;
        }

        for (targetInfos) |targetInfo| {
            const sourceInfo = c.getIndexInfoOfType(source, c.getIndexInfoKeyType(targetInfo));
            if (sourceInfo) |sInfo| {
                if (r.isRelatedTo(c.getIndexInfoValueType(sInfo), c.getIndexInfoValueType(targetInfo), RecursionFlags_Both, false) != .False and c.getIndexInfoIsReadonly(sInfo) == c.getIndexInfoIsReadonly(targetInfo)) {
                    continue;
                }
            }
            return .False;
        }
        return .True;
    }

    pub fn reportErrorResults(r: *Relater, originalSource: types.TypeIndex, originalTarget: types.TypeIndex, source: types.TypeIndex, target: types.TypeIndex, headMessage: ?*const diagnostics_gen.Message) void {
        _ = r;
        _ = originalSource;
        _ = originalTarget;
        _ = source;
        _ = target;
        _ = headMessage;
    }

    pub fn reportRelationError(r: *Relater, message: ?*const diagnostics_gen.Message, source: types.TypeIndex, target: types.TypeIndex) void {
        _ = r;
        _ = message;
        _ = source;
        _ = target;
    }

    pub fn reportError(r: *Relater, message: ?*const diagnostics_gen.Message, args: []const []const u8) void {
        _ = r;
        _ = message;
        _ = args;
    }

    pub fn traceUnionsOrIntersectionsTooLarge(r: *Relater, source: types.TypeIndex, target: types.TypeIndex) void {
        const c = r.c;
        if (c.tracer == null) {
            return;
        }

        if (c.getTypeFlags(source) & types.TypeFlags.UnionOrIntersection != 0 and c.getTypeFlags(target) & types.TypeFlags.UnionOrIntersection != 0) {
            if (c.getObjectFlags(source) & c.getObjectFlags(target) & types.ObjectFlags.PrimitiveUnion != 0) {
                return;
            }
            const sourceSize = c.getTypesCount(source);
            const targetSize = c.getTypesCount(target);
            if (sourceSize * targetSize > 1000000) {
                // c.tracer.Instant(tracing.PhaseCheckTypes, "traceUnionsOrIntersectionsTooLarge_DepthLimit", ...)
            }
        }
    }
    pub fn chainArgsMatch(r: *Relater, args: []const []const u8) bool {
        _ = r;
        _ = args;
        return false; // Stub
    }

    pub fn isRelatedToSimple(
        r: *Relater,
        source: types.TypeIndex,
        target: types.TypeIndex,
    ) types.Ternary {
        return r.isRelatedToEx(source, target, RecursionFlags_Both, false, null, IntersectionState_None);
    }

    pub fn isRelatedTo(
        r: *Relater,
        source: types.TypeIndex,
        target: types.TypeIndex,
        recursionFlags: RecursionFlags,
        reportErrors: bool,
    ) types.Ternary {
        return r.isRelatedToEx(source, target, recursionFlags, reportErrors, null, IntersectionState_None);
    }

    pub fn isRelatedToEx(
        self: *Relater,
        originalSource: types.TypeIndex,
        originalTarget: types.TypeIndex,
        recursionFlags: RecursionFlags,
        reportErrors: bool,
        headMessage: ?*const diagnostics_gen.Message,
        intersectionState: IntersectionState,
    ) types.Ternary {
        _ = recursionFlags;
        _ = headMessage;
        _ = intersectionState;

        if (originalSource == originalTarget) return .True;

        const c = self.c;
        const sourceFlags = c.typesList.items[originalSource].flags;
        const targetFlags = c.typesList.items[originalTarget].flags;

        if (sourceFlags & types.TypeFlags.Object != 0 and targetFlags & types.TypeFlags.Primitive != 0) {
            if ((self.relation == &c.comparableRelation and targetFlags & types.TypeFlags.Never == 0 and isSimpleTypeRelatedTo(c, originalTarget, originalSource, self.relation, null)) or
                isSimpleTypeRelatedTo(c, originalSource, originalTarget, self.relation, null)) // TODO: reportErrors
            {
                return .True;
            }
            if (reportErrors) {
                // TODO: reportErrorResults
            }
            return .False;
        }

        const source = c.getNormalizedType(originalSource, false);
        var target = c.getNormalizedType(originalTarget, true);

        if (source == target) return .True;

        if (self.relation == &c.identityRelation) {
            const sFlags = c.typesList.items[source].flags;
            const tFlags = c.typesList.items[target].flags;
            if (sFlags != tFlags) return .False;
            if (sFlags & types.TypeFlags.Singleton != 0) return .True;
            // TODO: traceUnionsOrIntersectionsTooLarge
            // return recursiveTypeRelatedTo(...)
        }

        // We fastpath comparing a type parameter to exactly its constraint, as this is _super_ common...
        if (c.typesList.items[source].flags & types.TypeFlags.TypeParameter != 0 and c.getConstraintOfType(source) == target) {
            return .True;
        }

        // See if we're relating a definitely non-nullable type to a union that includes null and/or undefined
        if (c.typesList.items[source].flags & types.TypeFlags.DefinitelyNonNullable != 0 and c.typesList.items[target].flags & types.TypeFlags.Union != 0) {
            const unionTypes = c.getTypesFromUnion(target);
            var candidate: ?types.TypeIndex = null;
            if (unionTypes.len == 2 and c.typesList.items[unionTypes[0]].flags & types.TypeFlags.Nullable != 0) {
                candidate = unionTypes[1];
            } else if (unionTypes.len == 3 and c.typesList.items[unionTypes[0]].flags & types.TypeFlags.Nullable != 0 and c.typesList.items[unionTypes[1]].flags & types.TypeFlags.Nullable != 0) {
                candidate = unionTypes[2];
            }
            if (candidate) |cand| {
                if (c.typesList.items[cand].flags & types.TypeFlags.Nullable == 0) {
                    target = c.getNormalizedType(cand, true);
                    if (source == target) return .True;
                }
            }
        }

        if ((self.relation == &c.comparableRelation and targetFlags & types.TypeFlags.Never == 0 and isSimpleTypeRelatedTo(c, target, source, self.relation, null)) or
            isSimpleTypeRelatedTo(c, source, target, self.relation, null)) // TODO: reportErrors
        {
            return .True;
        }

        return .False; // Stub
    }
};

pub fn getRelater(c: *Checker) *Relater {
    if (c.freeRelater) |r| {
        c.freeRelater = r.next;
        return r;
    }
    const r = c.allocator.create(Relater) catch unreachable;
    r.* = .{
        .c = c,
        .relation = &c.identityRelation, // initialized later
    };
    return r;
}

pub fn putRelater(c: *Checker, r: *Relater) void {
    r.maybeKeysSet.clearRetainingCapacity();
    r.maybeKeys.clearRetainingCapacity();
    r.sourceStack.clearRetainingCapacity();
    r.targetStack.clearRetainingCapacity();
    r.next = c.freeRelater;
    c.freeRelater = r;
}

pub fn checkTypeAssignableTo(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, errorNode: ?ast.NodeIndex, headMessage: ?*const diagnostics_gen.Message) bool {
    return checkTypeRelatedToEx(c, source, target, &c.assignableRelation, errorNode, headMessage, null);
}

pub fn checkTypeAssignableToEx(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, errorNode: ?ast.NodeIndex, headMessage: ?*const diagnostics_gen.Message, diagnosticOutput: ?*std.ArrayListUnmanaged(diagnostics.Diagnostic)) bool {
    return checkTypeRelatedToEx(c, source, target, &c.assignableRelation, errorNode, headMessage, diagnosticOutput);
}

pub fn checkTypeComparableTo(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, errorNode: ?ast.NodeIndex, headMessage: ?*const diagnostics_gen.Message) bool {
    return checkTypeRelatedToEx(c, source, target, &c.comparableRelation, errorNode, headMessage, null);
}

pub fn checkTypeRelatedTo(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, relation: *Relation, errorNode: ?ast.NodeIndex) bool {
    return checkTypeRelatedToEx(c, source, target, relation, errorNode, null, null);
}

pub fn checkTypeRelatedToEx(
    c: *Checker,
    source: types.TypeIndex,
    target: types.TypeIndex,
    relation: *Relation,
    errorNode: ?ast.NodeIndex,
    headMessage: ?*const diagnostics_gen.Message,
    diagnosticOutput: ?*std.ArrayListUnmanaged(diagnostics.Diagnostic),
) bool {
    const r = getRelater(c);
    r.relation = relation;
    r.errorNode = errorNode;
    r.relationCount = @intCast((16000000 - relation.size()) / 8);

    const result = r.isRelatedToEx(source, target, RecursionFlags_Both, errorNode != null, headMessage, IntersectionState_None);

    if (r.overflow) {
        // Record this relation as having failed such that we don't attempt the overflowing operation again.
        // id, _ := getRelationKey(...)
        // relation.set(id, RelationComparisonResultFailed | RelationComparisonResultComplexityOverflow)
        // message := ...
        c.reportDiagnostic(createDiagnosticChainFromErrorChain(r.errorChain, r.errorNode.?, r.relatedInfo.items), diagnosticOutput);
    } else if (r.errorChain != null) {
        // ...
    }

    putRelater(c, r);

    return result != .False;
}

pub fn checkTypeAssignableToAndOptionallyElaborate(
    c: *Checker,
    source: types.TypeIndex,
    target: types.TypeIndex,
    errorNode: ?ast.NodeIndex,
    expr: ?ast.NodeIndex,
    headMessage: ?*const diagnostics_gen.Message,
    diagnosticOutput: ?*std.ArrayListUnmanaged(diagnostics.Diagnostic),
) bool {
    return checkTypeRelatedToAndOptionallyElaborate(c, source, target, &c.assignableRelation, errorNode, expr, headMessage, diagnosticOutput);
}

pub fn checkTypeRelatedToAndOptionallyElaborate(
    c: *Checker,
    source: types.TypeIndex,
    target: types.TypeIndex,
    relation: *Relation,
    errorNode: ?ast.NodeIndex,
    expr: ?ast.NodeIndex,
    headMessage: ?*const diagnostics_gen.Message,
    diagnosticOutput: ?*std.ArrayListUnmanaged(diagnostics.Diagnostic),
) bool {
    if (isTypeRelatedTo(c, source, target, relation)) {
        return true;
    }
    if (errorNode != null and !elaborateError(c, expr, source, target, relation, headMessage, diagnosticOutput)) {
        return checkTypeRelatedToEx(c, source, target, relation, errorNode, headMessage, diagnosticOutput);
    }
    return false;
}

pub fn elaborateError(
    c: *Checker,
    node: ?ast.NodeIndex,
    source: types.TypeIndex,
    target: types.TypeIndex,
    relation: *Relation,
    headMessage: ?*const diagnostics_gen.Message,
    diagnosticOutput: ?*std.ArrayListUnmanaged(diagnostics.Diagnostic),
) bool {
    _ = c;
    _ = node;
    _ = source;
    _ = target;
    _ = relation;
    _ = headMessage;
    _ = diagnosticOutput;
    return false; // Stub
}

pub fn isOrHasGenericConditional(c: *Checker, t: types.TypeIndex) bool {
    _ = c;
    _ = t;
    return false; // Stub
}

pub fn elaborateDidYouMeanToCallOrConstruct(c: *Checker, node: ast.NodeIndex, source: types.TypeIndex, target: types.TypeIndex, relation: *Relation, kind: types.SignatureKind, headMessage: ?*const diagnostics_gen.Message, diagnosticOutput: ?*std.ArrayListUnmanaged(diagnostics.Diagnostic)) bool {
    _ = c;
    _ = node;
    _ = source;
    _ = target;
    _ = relation;
    _ = kind;
    _ = headMessage;
    _ = diagnosticOutput;
    return false; // Stub
}

pub fn elaborateObjectLiteral(c: *Checker, node: ast.NodeIndex, source: types.TypeIndex, target: types.TypeIndex, relation: *Relation, diagnosticOutput: ?*std.ArrayListUnmanaged(diagnostics.Diagnostic)) bool {
    _ = c;
    _ = node;
    _ = source;
    _ = target;
    _ = relation;
    _ = diagnosticOutput;
    return false; // Stub
}

pub fn elaborateArrayLiteral(c: *Checker, node: ast.NodeIndex, source: types.TypeIndex, target: types.TypeIndex, relation: *Relation, diagnosticOutput: ?*std.ArrayListUnmanaged(diagnostics.Diagnostic)) bool {
    _ = c;
    _ = node;
    _ = source;
    _ = target;
    _ = relation;
    _ = diagnosticOutput;
    return false; // Stub
}

pub fn elaborateElement(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, relation: *Relation, prop: ast.NodeIndex, next: ?ast.NodeIndex, nameType: types.TypeIndex, errorMessage: ?*const diagnostics_gen.Message, diagnosticFactory: ?*const fn (prop: ast.NodeIndex) diagnostics.Diagnostic, diagnosticOutput: ?*std.ArrayListUnmanaged(diagnostics.Diagnostic)) bool {
    _ = c;
    _ = source;
    _ = target;
    _ = relation;
    _ = prop;
    _ = next;
    _ = nameType;
    _ = errorMessage;
    _ = diagnosticFactory;
    _ = diagnosticOutput;
    return false; // Stub
}

pub fn isWeakType(c: *Checker, t: types.TypeIndex) bool {
    const typeObj = &c.typesList.items[t];
    if (typeObj.flags & types.TypeFlags.Object != 0) {
        // const resolved = c.resolveStructuredTypeMembers(t);
        // ...
        return false;
    }
    if (typeObj.flags & types.TypeFlags.Substitution != 0) {
        return isWeakType(c, typeObj.data.Substitution.baseType);
    }
    if (typeObj.flags & types.TypeFlags.Intersection != 0) {
        // return core.Every(t.Types(), isWeakType)
        return false;
    }
    return false;
}

pub fn hasCommonProperties(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, isComparingJsxAttributes: bool) bool {
    for (c.getPropertiesOfType(source)) |prop| {
        const propName = c.binder.symbols.items[prop].Name;
        if (isKnownProperty(c, target, propName, isComparingJsxAttributes)) {
            return true;
        }
    }
    return false;
}

pub fn isKnownProperty(c: *Checker, targetType: types.TypeIndex, name: []const u8, isComparingJsxAttributes: bool) bool {
    const typeObj = &c.typesList.items[targetType];
    if (typeObj.flags & types.TypeFlags.Object != 0) {
        // if c.getPropertyOfObjectType(targetType, name) != null or ...
        // ...
        return false;
    }
    if (typeObj.flags & types.TypeFlags.Substitution != 0) {
        return isKnownProperty(c, typeObj.data.Substitution.baseType, name, isComparingJsxAttributes);
    }
    if (typeObj.flags & types.TypeFlags.UnionOrIntersection != 0 and isExcessPropertyCheckTarget(c, targetType)) {
        // for t in types: isKnownProperty(t)
        return false;
    }
    return false;
}

pub fn isHyphenatedJsxName(name: []const u8) bool {
    return std.mem.indexOf(u8, name, "-") != null;
}

pub fn isExcessPropertyCheckTarget(c: *Checker, t: types.TypeIndex) bool {
    const typeObj = &c.typesList.items[t];
    if ((typeObj.flags & types.TypeFlags.Object != 0 and typeObj.objectFlags & types.ObjectFlags.ObjectLiteralPatternWithComputedProperties == 0) or
        (typeObj.flags & types.TypeFlags.NonPrimitive != 0))
    {
        return true;
    }
    if (typeObj.flags & types.TypeFlags.Substitution != 0 and isExcessPropertyCheckTarget(c, typeObj.data.Substitution.baseType)) {
        return true;
    }
    if (typeObj.flags & types.TypeFlags.Union != 0) {
        // Some(t.Types(), isExcessPropertyCheckTarget)
        return false;
    }
    if (typeObj.flags & types.TypeFlags.Intersection != 0) {
        // Every(t.Types(), isExcessPropertyCheckTarget)
        return false;
    }
    return false;
}

pub fn isTypeIdenticalTo(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
    return isTypeRelatedTo(c, source, target, &c.identityRelation);
}

pub fn isDeeplyNestedType(c: *Checker, t: types.TypeIndex, stack: *std.ArrayListUnmanaged(types.TypeIndex), maxDepth: usize) bool {
    _ = c;
    _ = t;
    _ = stack;
    _ = maxDepth;
    return false; // Stub
}

pub fn getMappedTargetWithSymbol(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    _ = c;
    return t; // Stub
}

pub fn hasMatchingRecursionIdentity(c: *Checker, t: types.TypeIndex, identity: RecursionId) bool {
    _ = c;
    _ = t;
    _ = identity;
    return false; // Stub
}

pub fn getRecursionIdentity(c: *Checker, t: types.TypeIndex) RecursionId {
    _ = c;
    _ = t;
    return asRecursionId(0); // Stub
}

pub fn getBestMatchingType(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, isRelatedToFn: *const fn (c: *Checker, source: types.TypeIndex, target: types.TypeIndex) types.Ternary) ?types.TypeIndex {
    if (findMatchingDiscriminantType(c, source, target, isRelatedToFn)) |t| return t;
    if (findMatchingTypeReferenceOrTypeAliasReference(c, source, target)) |t| return t;
    if (findBestTypeForObjectLiteral(c, source, target)) |t| return t;
    if (findBestTypeForInvokable(c, source, target, .Call)) |t| return t;
    if (findBestTypeForInvokable(c, source, target, .Construct)) |t| return t;
    return findMostOverlappyType(c, source, target);
}

pub fn findMatchingTypeReferenceOrTypeAliasReference(c: *Checker, source: types.TypeIndex, unionTarget: types.TypeIndex) ?types.TypeIndex {
    const source_object_flags = c.getObjectFlags(source);
    if ((source_object_flags & (types.ObjectFlags.Reference | types.ObjectFlags.Anonymous)) == 0) return null;
    if ((c.getTypeFlags(unionTarget) & types.TypeFlags.Union) == 0) return null;
    for (c.getTypesOfUnionOrIntersectionType(unionTarget)) |target| {
        if ((c.getTypeFlags(target) & types.TypeFlags.Object) == 0) continue;
        const overlap = source_object_flags & c.getObjectFlags(target);
        if ((overlap & types.ObjectFlags.Reference) != 0 and c.getTargetType(source) == c.getTargetType(target)) {
            return target;
        }
        if ((overlap & types.ObjectFlags.Anonymous) != 0) {
            const source_alias = c.getAliasSymbol(source);
            const target_alias = c.getAliasSymbol(target);
            if (source_alias != 0 and target_alias != 0 and source_alias == target_alias) {
                return target;
            }
        }
    }
    return null;
}

pub fn findBestTypeForInvokable(c: *Checker, source: types.TypeIndex, unionTarget: types.TypeIndex, kind: types.SignatureKind) ?types.TypeIndex {
    if (c.getSignaturesOfType(source, kind).len == 0) return null;
    for (c.getTypesOfUnionOrIntersectionType(unionTarget)) |t| {
        if (c.getSignaturesOfType(t, kind).len != 0) return t;
    }
    return null;
}

pub fn findMostOverlappyType(c: *Checker, source: types.TypeIndex, unionTarget: types.TypeIndex) ?types.TypeIndex {
    var best_match: ?types.TypeIndex = null;
    if ((c.getTypeFlags(source) & types.TypeFlags.Primitive) != 0 and (c.getTypeFlags(source) & types.TypeFlags.Instantiable) == 0) return null;
    var matching_count: usize = 0;
    for (c.getTypesOfUnionOrIntersectionType(unionTarget)) |target| {
        if ((c.getTypeFlags(target) & types.TypeFlags.Primitive) != 0 and (c.getTypeFlags(target) & types.TypeFlags.Instantiable) == 0) continue;
        const overlap = c.getIntersectionType(&.{ c.getIndexType(source), c.getIndexType(target) });
        if ((c.getTypeFlags(overlap) & types.TypeFlags.Index) != 0) return target;
        // Simplified overlap scoring for union/index types
        if ((c.getTypeFlags(overlap) & types.TypeFlags.Union) != 0 or isUnitType(c, overlap)) {
            const length: usize = 1;
            if (length >= matching_count) {
                best_match = target;
                matching_count = length;
            }
        }
    }
    return best_match;
}

pub fn findBestTypeForObjectLiteral(c: *Checker, source: types.TypeIndex, unionTarget: types.TypeIndex) ?types.TypeIndex {
    if ((c.getObjectFlags(source) & types.ObjectFlags.ObjectLiteral) == 0) return null;
    for (c.getTypesOfUnionOrIntersectionType(unionTarget)) |t| {
        if (!c.isArrayLikeType(t)) return t;
    }
    return null;
}

fn isUnitType(c: *Checker, t: types.TypeIndex) bool {
    const flags = c.getTypeFlags(t);
    return (flags & (types.TypeFlags.StringLiteral | types.TypeFlags.NumberLiteral | types.TypeFlags.BooleanLiteral | types.TypeFlags.EnumLiteral)) != 0;
}

pub fn shouldReportUnmatchedPropertyError(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
    return c.shouldReportUnmatchedPropertyError(source, target);
}

pub fn getUnmatchedProperty(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, requireOptionalProperties: bool, matchDiscriminantProperties: bool) ?ast.SymbolIndex {
    return getUnmatchedPropertiesWorker(c, source, target, requireOptionalProperties, matchDiscriminantProperties, null);
}

pub fn getUnmatchedProperties(c: *Checker, allocator: std.mem.Allocator, source: types.TypeIndex, target: types.TypeIndex, requireOptionalProperties: bool, matchDiscriminantProperties: bool) ![]ast.SymbolIndex {
    var props = std.ArrayList(ast.SymbolIndex).init(allocator);
    _ = getUnmatchedPropertiesWorker(c, source, target, requireOptionalProperties, matchDiscriminantProperties, &props);
    return props.toOwnedSlice();
}

pub fn getUnmatchedPropertiesWorker(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, requireOptionalProperties: bool, matchDiscriminantProperties: bool, propsOut: ?*std.ArrayList(ast.SymbolIndex)) ?ast.SymbolIndex {
    const properties = c.getPropertiesOfType(target);
    for (properties) |target_prop| {
        const target_flags = c.getSymbolFlags(target_prop);
        const target_check = c.getSymbolCheckFlags(target_prop);
        if (!requireOptionalProperties and (target_flags & symbol.SymbolFlags.Optional) != 0) continue;
        if (!requireOptionalProperties and (target_check & types.CheckFlags.Partial) != 0) continue;

        const prop_name = c.getSymbolName(target_prop);
        const source_prop = c.getPropertyOfType(source, prop_name);
        if (source_prop == null) {
            if (propsOut) |out| {
                out.append(target_prop) catch {};
            } else {
                return target_prop;
            }
            continue;
        }
        if (!matchDiscriminantProperties) continue;
        const target_type = c.getTypeOfSymbol(target_prop) catch 0;
        if ((c.getTypeFlags(target_type) & types.TypeFlags.Unit) == 0) continue;
        const source_type = c.getTypeOfSymbol(source_prop.?) catch 0;
        if ((c.getTypeFlags(source_type) & types.TypeFlags.Any) != 0) continue;
        if (c.getRegularTypeOfLiteralType(source_type) == c.getRegularTypeOfLiteralType(target_type)) continue;
        if (propsOut) |out| {
            out.append(target_prop) catch {};
        } else {
            return target_prop;
        }
    }
    return null;
}

pub fn excludeProperties(c: *Checker, allocator: std.mem.Allocator, properties: []ast.SymbolIndex, excludedProperties: std.StringHashMapUnmanaged(void)) ![]ast.SymbolIndex {
    if (excludedProperties.count() == 0 or properties.len == 0) return properties;
    var reduced = std.ArrayList(ast.SymbolIndex).init(allocator);
    for (properties) |prop| {
        const name = c.getSymbolName(prop);
        if (!excludedProperties.contains(name)) {
            try reduced.append(prop);
        }
    }
    return reduced.toOwnedSlice();
}

pub const TypeDiscriminator = struct {
    c: *Checker,
    props: []ast.SymbolIndex,
    isRelatedToFn: *const fn (c: *Checker, source: types.TypeIndex, target: types.TypeIndex) types.Ternary,

    pub fn len(self: *const TypeDiscriminator) usize {
        return self.props.len;
    }

    pub fn name(self: *const TypeDiscriminator, index: usize) []const u8 {
        return self.c.binder.symbols.items[self.props[index]].Name;
    }

    pub fn matches(self: *const TypeDiscriminator, index: usize, t: types.TypeIndex) bool {
        const propType = self.c.getNonMissingTypeOfSymbol(self.props[index]);
        for (self.c.distributedTypes(propType)) |s| {
            if (self.isRelatedToFn(self.c, s, t) != .False) return true;
        }
        return false;
    }
};

fn isLiteralType(c: *Checker, t: types.TypeIndex) bool {
    const flags = c.getTypeFlags(t);
    return (flags & (types.TypeFlags.Literal | types.TypeFlags.EnumLiteral)) != 0;
}

pub fn isGenericType(c: *Checker, t: types.TypeIndex) bool {
    return c.getGenericObjectFlags(t) & types.ObjectFlags.IsGenericType != 0;
}

pub fn findMatchingDiscriminantType(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, isRelatedToFn: *const fn (c: *Checker, source: types.TypeIndex, target: types.TypeIndex) types.Ternary) ?types.TypeIndex {
    if ((c.getTypeFlags(target) & types.TypeFlags.Union) == 0) return null;
    if ((c.getTypeFlags(source) & (types.TypeFlags.Intersection | types.TypeFlags.Object)) == 0) return null;

    if (getMatchingUnionConstituentForType(c, target, source)) |match| return match;

    const discriminantProperties = c.findDiscriminantProperties(c.getPropertiesOfType(source), target);
    if (discriminantProperties.len == 0) return null;

    var discriminator = TypeDiscriminator{ .c = c, .props = discriminantProperties, .isRelatedToFn = isRelatedToFn };
    const discriminated = discriminateTypeByDiscriminableItems(c, target, &discriminator);
    if (discriminated != target) return discriminated;
    return null;
}

pub fn findDiscriminantProperties(c: *Checker, allocator: std.mem.Allocator, sourceProperties: []ast.SymbolIndex, target: types.TypeIndex) ![]ast.SymbolIndex {
    var result = std.ArrayList(ast.SymbolIndex).init(allocator);
    errdefer result.deinit();
    for (sourceProperties) |sourceProperty| {
        const name = c.getSymbolName(sourceProperty);
        if (isDiscriminantProperty(c, target, name)) {
            try result.append(sourceProperty);
        }
    }
    return result.toOwnedSlice();
}

pub fn isDiscriminantProperty(c: *Checker, t: types.TypeIndex, name: []const u8) bool {
    if ((c.getTypeFlags(t) & types.TypeFlags.Union) == 0) return false;

    if (c.getUnionOrIntersectionProperty(t, name)) |prop| {
        const checkFlags = c.getSymbolCheckFlags(prop);
        if ((checkFlags & types.CheckFlags.SyntheticProperty) != 0) {
            if ((checkFlags & types.CheckFlags.NonUniformAndLiteral) == types.CheckFlags.NonUniformAndLiteral) {
                const propType = c.getTypeOfSymbol(prop) catch 0;
                return propType != 0 and !isGenericType(c, propType);
            }
            return false;
        }
    }

    var hasLiteral = false;
    var hasNonUniform = false;
    var firstRegularType: ?types.TypeIndex = null;
    var firstLiteralType: ?types.TypeIndex = null;
    var foundAny = false;

    for (c.getTypesFromUnion(t)) |constituent| {
        const apparent = c.getApparentType(constituent);
        if ((c.getTypeFlags(apparent) & types.TypeFlags.Never) != 0) continue;

        const propType = c.getTypeOfPropertyOfType(apparent, name);
        if (propType == 0) return false;
        if (!isLiteralType(c, propType)) return false;
        if (isGenericType(c, propType)) return false;

        hasLiteral = true;
        const regularType = c.getRegularTypeOfLiteralType(propType);
        if (firstRegularType) |firstRegular| {
            if (regularType != firstRegular or propType != firstLiteralType.?) {
                hasNonUniform = true;
            }
        } else {
            firstRegularType = regularType;
            firstLiteralType = propType;
        }
        foundAny = true;
    }

    return foundAny and hasLiteral and hasNonUniform;
}

pub fn getMatchingUnionConstituentForType(c: *Checker, unionType: types.TypeIndex, t: types.TypeIndex) ?types.TypeIndex {
    const keyPropertyName = getKeyPropertyName(c, unionType);
    if (keyPropertyName.len == 0) return null;
    const propType = c.getTypeOfPropertyOfType(t, keyPropertyName);
    if (propType == 0) return null;
    return getConstituentTypeForKeyType(c, unionType, propType);
}

pub fn getKeyPropertyName(c: *Checker, t: types.TypeIndex) []const u8 {
    if ((c.getTypeFlags(t) & types.TypeFlags.Union) == 0) return "";
    if (!c.unionKeyPropertyCache.contains(t)) {
        computeKeyPropertyNameAndMap(c, t);
    }
    const entry = c.unionKeyPropertyCache.get(t) orelse return "";
    if (std.mem.eql(u8, entry.keyPropertyName, symbol.InternalSymbolNameMissing)) return "";
    return entry.keyPropertyName;
}

pub fn getConstituentTypeForKeyType(c: *Checker, t: types.TypeIndex, keyType: types.TypeIndex) ?types.TypeIndex {
    _ = getKeyPropertyName(c, t);
    const entry = c.unionKeyPropertyCache.get(t) orelse return null;
    const map = entry.constituentMap orelse return null;
    const regularKey = c.getRegularTypeOfLiteralType(keyType);
    const result = map.get(regularKey) orelse return null;
    if (result == (c.unknownTypeIndex orelse 0)) return null;
    return result;
}

fn mapTypesByKeyProperty(c: *Checker, typeList: []const types.TypeIndex, keyPropertyName: []const u8) ?std.AutoHashMapUnmanaged(types.TypeIndex, types.TypeIndex) {
    var typesByKey = std.AutoHashMapUnmanaged(types.TypeIndex, types.TypeIndex).empty;
    var count: usize = 0;
    const unknown = c.unknownTypeIndex orelse 0;

    for (typeList) |t| {
        const flags = c.getTypeFlags(t);
        if ((flags & (types.TypeFlags.Object | types.TypeFlags.Intersection | types.TypeFlags.InstantiableNonPrimitive)) == 0) continue;

        const discriminant = c.getTypeOfPropertyOfType(t, keyPropertyName);
        if (discriminant == 0 or !isLiteralType(c, discriminant)) {
            typesByKey.deinit(c.allocator);
            return null;
        }

        var duplicate = false;
        for (c.distributedTypes(discriminant)) |d| {
            const key = c.getRegularTypeOfLiteralType(d);
            if (typesByKey.get(key)) |existing| {
                if (existing != unknown) {
                    typesByKey.put(c.allocator, key, unknown) catch {};
                    duplicate = true;
                }
            } else {
                typesByKey.put(c.allocator, key, t) catch {};
            }
        }
        if (!duplicate) count += 1;
    }

    if (count >= 10 and count * 2 >= typeList.len) {
        return typesByKey;
    }
    typesByKey.deinit(c.allocator);
    return null;
}

pub fn computeKeyPropertyNameAndMap(c: *Checker, t: types.TypeIndex) void {
    const typeList = c.getTypesFromUnion(t);
    const typeNode = &c.typesList.items[t];
    var keyPropertyName: []const u8 = symbol.InternalSymbolNameMissing;
    var constituentMap: ?std.AutoHashMapUnmanaged(types.TypeIndex, types.TypeIndex) = null;

    if (typeList.len >= 10 and (typeNode.objectFlags & types.ObjectFlags.PrimitiveUnion) == 0) {
        var nonPrimitiveCount: usize = 0;
        for (typeList) |ct| {
            if (isObjectOrInstantiableNonPrimitive(c, ct)) nonPrimitiveCount += 1;
        }
        if (nonPrimitiveCount >= 10) {
            const candidateName = getKeyPropertyCandidateName(c, typeList);
            if (candidateName.len > 0) {
                if (mapTypesByKeyProperty(c, typeList, candidateName)) |map| {
                    keyPropertyName = candidateName;
                    constituentMap = map;
                }
            }
        }
    }

    c.unionKeyPropertyCache.put(c.allocator, t, .{
        .keyPropertyName = keyPropertyName,
        .constituentMap = constituentMap,
    }) catch {};
}

pub fn getKeyPropertyCandidateName(c: *Checker, typeList: []const types.TypeIndex) []const u8 {
    for (typeList) |t| {
        if (isObjectOrInstantiableNonPrimitive(c, t)) {
            for (c.getPropertiesOfType(t)) |p| {
                const propType = c.getTypeOfSymbol(p) catch continue;
                if (isUnitType(c, propType)) {
                    return c.getSymbolName(p);
                }
            }
        }
    }
    return "";
}

pub fn discriminateTypeByDiscriminableItems(c: *Checker, target: types.TypeIndex, discriminator: *TypeDiscriminator) types.TypeIndex {
    const typeList = c.getTypesFromUnion(target);
    var include = c.allocator.alloc(types.Ternary, typeList.len) catch return target;
    defer c.allocator.free(include);

    for (typeList, 0..) |t, i| {
        if ((c.getTypeFlags(t) & types.TypeFlags.Primitive) == 0 and (c.getTypeFlags(c.getReducedType(t)) & types.TypeFlags.Never) == 0) {
            include[i] = .True;
        } else {
            include[i] = .False;
        }
    }

    for (0..discriminator.len()) |n| {
        var matched = false;
        const discName = discriminator.name(n);
        for (typeList, 0..) |t, i| {
            if (include[i] == .False) continue;
            if (c.getTypeOfPropertyOrIndexSignatureOfType(t, discName)) |targetType| {
                if (discriminator.matches(n, targetType)) {
                    matched = true;
                } else {
                    include[i] = .Maybe;
                }
            }
        }
        for (include) |*inc| {
            if (inc.* == .Maybe) {
                inc.* = if (matched) .False else .True;
            }
        }
    }

    var hasFalse = false;
    for (include) |inc| {
        if (inc == .False) {
            hasFalse = true;
            break;
        }
    }
    if (!hasFalse) return target;

    var filteredTypes = std.ArrayList(types.TypeIndex).init(c.allocator);
    defer filteredTypes.deinit();
    for (typeList, include) |t, inc| {
        if (inc == .True) {
            filteredTypes.append(t) catch return target;
        }
    }
    const filtered = c.getUnionTypeFromArray(filteredTypes.items);
    if ((c.getTypeFlags(filtered) & types.TypeFlags.Never) == 0) {
        return filtered;
    }
    return target;
}

pub fn filterPrimitivesIfContainsNonPrimitive(c: *Checker, unionType: types.TypeIndex) types.TypeIndex {
    if (c.maybeTypeOfKind(unionType, types.TypeFlags.NonPrimitive)) {
        const result = c.filterType(unionType, nonPrimitiveFilter, struct {});
        if ((c.getTypeFlags(result) & types.TypeFlags.Never) == 0) {
            return result;
        }
    }
    return unionType;
}

fn nonPrimitiveFilter(c: *Checker, t: types.TypeIndex, _: void) bool {
    return isNonPrimitiveType(c, t);
}

pub fn isObjectOrInstantiableNonPrimitive(c: *Checker, t: types.TypeIndex) bool {
    const typeObj = &c.typesList.items[t];
    return typeObj.flags & (types.TypeFlags.Object | types.TypeFlags.InstantiableNonPrimitive) != 0;
}

pub fn isNonPrimitiveType(c: *Checker, t: types.TypeIndex) bool {
    return c.typesList.items[t].flags & types.TypeFlags.Primitive == 0;
}

pub fn getTypeNamesForErrorDisplay(c: *Checker, left: types.TypeIndex, right: types.TypeIndex) struct { []const u8, []const u8 } {
    _ = c;
    _ = left;
    _ = right;
    return .{ "left", "right" }; // Stub
}

pub fn getTypeNameForErrorDisplay(c: *Checker, t: types.TypeIndex) []const u8 {
    _ = c;
    _ = t;
    return "t"; // Stub
}

pub fn compareTypesIdentical(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) types.Ternary {
    if (isTypeRelatedTo(c, source, target, &c.identityRelation)) {
        return .True;
    }
    return .False;
}

pub fn symbolValueDeclarationIsContextSensitive(c: *Checker, symbolIdx: ?ast.SymbolIndex) bool {
    _ = c;
    _ = symbolIdx;
    return false; // Stub
}

pub fn typeCouldHaveTopLevelSingletonTypes(c: *Checker, t: types.TypeIndex) bool {
    _ = c;
    _ = t;
    return false; // Stub
}

pub fn getVariances(c: *Checker, t: types.TypeIndex) []VarianceFlags {
    _ = c;
    _ = t;
    return &[_]VarianceFlags{}; // Stub
}

pub fn getAliasVariances(c: *Checker, symbolIdx: ast.SymbolIndex) []VarianceFlags {
    _ = c;
    _ = symbolIdx;
    return &[_]VarianceFlags{}; // Stub
}

pub fn getVariancesWorker(c: *Checker, symbolIdx: ast.SymbolIndex, typeParameters: []types.TypeIndex) []VarianceFlags {
    _ = c;
    _ = symbolIdx;
    _ = typeParameters;
    return &[_]VarianceFlags{}; // Stub
}

pub fn createMarkerType(c: *Checker, symbolIdx: ast.SymbolIndex, source: types.TypeIndex, target: types.TypeIndex) types.TypeIndex {
    _ = c;
    _ = symbolIdx;
    _ = target;
    return source; // Stub
}

pub fn isMarkerType(c: *Checker, t: types.TypeIndex) bool {
    _ = c;
    _ = t;
    return false; // Stub
}

pub fn getTypeParameterModifiers(c: *Checker, tp: types.TypeIndex) ast.ModifierFlags {
    _ = c;
    _ = tp;
    return 0; // Stub
}

pub fn hasCovariantVoidArgument(c: *Checker, typeArguments: []types.TypeIndex, variances: []VarianceFlags) bool {
    _ = c;
    _ = typeArguments;
    _ = variances;
    return false; // Stub
}

pub fn isSignatureAssignableTo(c: *Checker, source: types.SignatureIndex, target: types.SignatureIndex, ignoreReturnTypes: bool) bool {
    _ = c;
    _ = source;
    _ = target;
    _ = ignoreReturnTypes;
    return false; // Stub
}

pub fn compareSignaturesRelated(c: *Checker, source: types.SignatureIndex, target: types.SignatureIndex, checkMode: SignatureCheckMode, reportErrors: bool, errorReporter: ErrorReporter, compareTypes: ?*const fn (c: *Checker, source: types.TypeIndex, target: types.TypeIndex) types.Ternary, reportUnreliableMarkers: ?types.TypeMapperIndex) types.Ternary {
    _ = c;
    _ = source;
    _ = target;
    _ = checkMode;
    _ = reportErrors;
    _ = errorReporter;
    _ = compareTypes;
    _ = reportUnreliableMarkers;
    return .False; // Stub
}

pub fn isTopSignature(c: *Checker, s: types.SignatureIndex) bool {
    _ = c;
    _ = s;
    return false; // Stub
}

/// Return the number of parameters in a signature. The rest parameter, if
/// present, counts as one parameter. For example, the parameter count of
/// `(x: number, y: number, ...z: string[])` is 3 and the parameter count
/// of `(x: number, ...args: [number, ...string[], boolean])` is also 3. In
/// the latter example, the effective rest type is `[...string[], boolean]`.
///
/// Port of `checker.go::getParameterCount`.
pub fn getParameterCount(c: *Checker, signature: types.SignatureIndex) usize {
    const sig = c.signatures.items[signature];
    const params = types.parameters(c, signature);
    const length = params.len;
    if (checker_mod.Checker.signatureHasRestParameter(&sig)) {
        if (length == 0) return 0;
        const rest_symbol = params[length - 1];
        const rest_type = c.getTypeOfSymbol(rest_symbol) catch return length;
        if (c.isTupleType(rest_type)) {
            const tuple = c.getTargetTupleType(rest_type);
            const variable_offset: usize = if ((tuple.combinedFlags & types.ElementFlags.Variable) != 0) 0 else 1;
            return length + tuple.fixedLength - variable_offset;
        }
    }
    return length;
}

/// Return the minimum number of arguments required by `signature`.
///
/// Port of `checker.go::getMinArgumentCount`. Caches the resolved value
/// in `signature.resolvedMinArgumentCount` (-1 means "not yet computed").
pub fn getMinArgumentCount(c: *Checker, signature: types.SignatureIndex) usize {
    return getMinArgumentCountEx(c, signature, MinArgumentCountFlags_None);
}

/// Port of `checker.go::getMinArgumentCountEx`. Computes (and caches) the
/// minimum argument count, taking rest-tuple-element required-flags and
/// trailing `void` parameters into account.
pub fn getMinArgumentCountEx(c: *Checker, signature: types.SignatureIndex, flags: MinArgumentCountFlags) usize {
    const strong_arity_for_untyped_js = (flags & MinArgumentCountFlags_StrongArityForUntypedJS) != 0;
    const void_is_non_optional = (flags & MinArgumentCountFlags_VoidIsNonOptional) != 0;
    var sig = &c.signatures.items[signature];

    if (void_is_non_optional or sig.resolvedMinArgumentCount == -1) {
        var min_argument_count: i32 = -1;
        const params = types.parameters(c, signature);
        if (checker_mod.Checker.signatureHasRestParameter(sig)) {
            if (params.len > 0) {
                const rest_symbol = params[params.len - 1];
                const rest_type = c.getTypeOfSymbol(rest_symbol) catch 0;
                if (rest_type != 0 and c.isTupleType(rest_type)) {
                    const tuple = c.getTargetTupleType(rest_type);
                    const element_infos = c.getTupleElementInfos(rest_type);
                    var first_optional_index: i32 = -1;
                    for (element_infos, 0..) |info, i| {
                        if ((info.flags & types.ElementFlags.Required) == 0) {
                            first_optional_index = @intCast(i);
                            break;
                        }
                    }
                    const required_count: i32 = if (first_optional_index < 0)
                        @intCast(tuple.fixedLength)
                    else
                        first_optional_index;
                    if (required_count > 0) {
                        min_argument_count = @as(i32, @intCast(params.len)) - 1 + required_count;
                    }
                }
            }
        }
        if (min_argument_count == -1) {
            if (!strong_arity_for_untyped_js and (sig.flags & types.SignatureFlags.IsUntypedSignatureInJSFile) != 0) {
                if (void_is_non_optional) {
                    // already set
                } else {
                    sig.resolvedMinArgumentCount = 0;
                    return 0;
                }
            }
            min_argument_count = sig.minArgumentCount;
        }
        if (void_is_non_optional) {
            sig.resolvedMinArgumentCount = min_argument_count;
            return @intCast(@max(min_argument_count, 0));
        }
        // Walk back over trailing `void` parameters — they are treated as
        // optional for arity purposes (e.g. `function f(): void {}` has
        // min-arg-count 0 even though its declared minArgumentCount might
        // be 1 from a parameter-less signature).
        var i: i32 = min_argument_count - 1;
        while (i >= 0) : (i -= 1) {
            const t = getTypeAtPosition(c, signature, @intCast(i));
            if (!someTypeIsVoid(c, t)) break;
            min_argument_count = i;
        }
        sig.resolvedMinArgumentCount = min_argument_count;
    }
    return @intCast(@max(sig.resolvedMinArgumentCount, 0));
}

/// Port of `checker.go::hasEffectiveRestParameter`. A signature has an
/// effective rest parameter when its rest parameter is *not* a fixed-length
/// tuple (i.e. it ends with `...T[]` or `[...T[], ...U[]]`).
pub fn hasEffectiveRestParameter(c: *Checker, signature: types.SignatureIndex) bool {
    const sig = c.signatures.items[signature];
    if (!checker_mod.Checker.signatureHasRestParameter(&sig)) return false;
    const params = types.parameters(c, signature);
    if (params.len == 0) return false;
    const rest_symbol = params[params.len - 1];
    const rest_type = c.getTypeOfSymbol(rest_symbol) catch return true;
    if (!c.isTupleType(rest_type)) return true;
    const tuple = c.getTargetTupleType(rest_type);
    return (tuple.combinedFlags & types.ElementFlags.Variable) != 0;
}

/// Returns true if any constituent of `t` (if it's a union) has the `Void`
/// flag set. Used by `getMinArgumentCountEx` to skip trailing void params.
/// Port of `someType(t, func(t) bool { return t.flags & TypeFlagsVoid != 0 })`.
fn someTypeIsVoid(c: *Checker, t: types.TypeIndex) bool {
    if (t == 0) return false;
    const type_obj = c.typesList.items[t];
    if ((type_obj.flags & types.TypeFlags.Union) != 0) {
        // Walk union constituents
        const constituents = c.getTypesFromUnion(t);
        for (constituents) |ct| {
            if ((c.typesList.items[ct].flags & types.TypeFlags.Void) != 0) return true;
        }
        return false;
    }
    return (type_obj.flags & types.TypeFlags.Void) != 0;
}

/// Port of `checker.go::getTypeAtPosition`. Returns the type of the
/// parameter at `pos` in `signature`, or `c.anyType` if out of range.
/// Currently a thin wrapper around `tryGetTypeAtPosition`.
pub fn getTypeAtPosition(c: *Checker, signature: types.SignatureIndex, pos: usize) types.TypeIndex {
    if (tryGetTypeAtPosition(c, signature, pos)) |t| return t;
    return c.anyTypeIndex orelse 0;
}

/// Port of `checker.go::tryGetTypeAtPosition`. Returns the type of the
/// parameter at `pos`, or null if `pos` is past the last fixed parameter
/// and the signature has no rest parameter.
pub fn tryGetTypeAtPosition(c: *Checker, signature: types.SignatureIndex, pos: usize) ?types.TypeIndex {
    const sig = c.signatures.items[signature];
    const params = types.parameters(c, signature);
    const has_rest = checker_mod.Checker.signatureHasRestParameter(&sig);
    const param_count: usize = if (has_rest) params.len - 1 else params.len;
    if (pos < param_count) {
        return c.getTypeOfParameter(params[pos]);
    }
    if (has_rest and params.len > 0) {
        // Out-of-bounds position with a rest parameter — return the
        // rest element type. Full implementation requires indexed-access
        // type machinery (`getIndexedAccessType`), which is still a stub.
        // For now, return the rest array's element type if available.
        const rest_symbol = params[param_count];
        const rest_type = c.getTypeOfSymbol(rest_symbol) catch return null;
        return c.getElementTypeOfArrayType(rest_type);
    }
    return null;
}

pub fn getRestOrAnyTypeAtPosition(c: *Checker, source: types.SignatureIndex, pos: usize) ?types.TypeIndex {
    _ = c;
    _ = source;
    _ = pos;
    return null; // Stub
}

pub fn getRestTypeAtPosition(c: *Checker, source: types.SignatureIndex, pos: usize, readonly: bool) ?types.TypeIndex {
    _ = c;
    _ = source;
    _ = pos;
    _ = readonly;
    return null; // Stub
}

pub fn getNameableDeclarationAtPosition(c: *Checker, signature: types.SignatureIndex, pos: usize) ?ast.NodeIndex {
    _ = c;
    _ = signature;
    _ = pos;
    return null; // Stub
}

pub fn isValidDeclarationForTupleLabel(c: *Checker, d: ast.NodeIndex) bool {
    _ = c;
    _ = d;
    return false; // Stub
}

pub fn getNonArrayRestType(c: *Checker, signature: types.SignatureIndex) ?types.TypeIndex {
    _ = c;
    _ = signature;
    return null; // Stub
}

pub fn getEffectiveRestType(c: *Checker, signature: types.SignatureIndex) ?types.TypeIndex {
    _ = c;
    _ = signature;
    return null; // Stub
}

pub fn sliceTupleType(c: *Checker, t: types.TypeIndex, index: usize, endSkipCount: isize) types.TypeIndex {
    _ = c;
    _ = index;
    _ = endSkipCount;
    return t; // Stub
}

pub fn getKnownKeysOfTupleType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    _ = c;
    return t; // Stub
}

pub fn getThisTypeOfSignature(c: *Checker, signature: types.SignatureIndex) ?types.TypeIndex {
    _ = c;
    _ = signature;
    return null; // Stub
}

pub fn isInstantiatedGenericParameter(c: *Checker, signature: types.SignatureIndex, pos: usize) bool {
    _ = c;
    _ = signature;
    _ = pos;
    return false; // Stub
}

pub fn getParameterNameAtPosition(c: *Checker, signature: types.SignatureIndex, pos: usize) []const u8 {
    _ = c;
    _ = signature;
    _ = pos;
    return ""; // Stub
}

pub fn getTupleElementLabel(c: *Checker, elementInfo: types.TupleElementInfo, restSymbol: ?ast.SymbolIndex, index: usize) []const u8 {
    _ = c;
    _ = elementInfo;
    _ = restSymbol;
    _ = index;
    return ""; // Stub
}

pub fn getTupleElementLabelFromBindingElement(c: *Checker, node: ast.NodeIndex, index: usize, elementFlags: types.ElementFlags) []const u8 {
    _ = c;
    _ = node;
    _ = index;
    _ = elementFlags;
    return ""; // Stub
}

pub fn getTypePredicateOfSignature(c: *Checker, sig: types.SignatureIndex) ?*types.TypePredicate {
    _ = c;
    _ = sig;
    return null; // Stub
}

pub fn getUnionOrIntersectionTypePredicate(c: *Checker, signatures: []types.SignatureIndex, isUnion: bool) ?*types.TypePredicate {
    _ = c;
    _ = signatures;
    _ = isUnion;
    return null; // Stub
}

pub fn typePredicateKindsMatch(c: *Checker, a: *types.TypePredicate, b: *types.TypePredicate) bool {
    _ = c;
    _ = a;
    _ = b;
    return false; // Stub
}

pub fn createTypePredicateFromTypePredicateNode(c: *Checker, node: ast.NodeIndex, signature: types.SignatureIndex) *types.TypePredicate {
    _ = c;
    _ = node;
    _ = signature;
    return 0; // Stub
}

pub fn instantiateTypePredicate(c: *Checker, predicate: *types.TypePredicate, mapper: ?types.TypeMapperIndex) *types.TypePredicate {
    _ = c;
    _ = mapper;
    return predicate; // Stub
}

pub fn isResolvingReturnTypeOfSignature(c: *Checker, signature: types.SignatureIndex) bool {
    _ = c;
    _ = signature;
    return false; // Stub
}

pub fn findMatchingSignatures(c: *Checker, signatureLists: [][]types.SignatureIndex, signature: types.SignatureIndex, listIndex: usize) []types.SignatureIndex {
    _ = c;
    _ = signatureLists;
    _ = signature;
    _ = listIndex;
    return &[_]types.SignatureIndex{}; // Stub
}

pub fn findMatchingSignature(c: *Checker, signatureList: []types.SignatureIndex, signature: types.SignatureIndex, partialMatch: bool, ignoreThisTypes: bool, ignoreReturnTypes: bool) ?types.SignatureIndex {
    _ = c;
    _ = signatureList;
    _ = signature;
    _ = partialMatch;
    _ = ignoreThisTypes;
    _ = ignoreReturnTypes;
    return null; // Stub
}

pub fn compareSignaturesIdentical(c: *Checker, source: types.SignatureIndex, target: types.SignatureIndex, partialMatch: bool, ignoreThisTypes: bool, ignoreReturnTypes: bool, compareTypes: ?*const fn (c: *Checker, source: types.TypeIndex, target: types.TypeIndex) types.Ternary) types.Ternary {
    _ = c;
    _ = source;
    _ = target;
    _ = partialMatch;
    _ = ignoreThisTypes;
    _ = ignoreReturnTypes;
    _ = compareTypes;
    return .False; // Stub
}

pub fn isMatchingSignature(c: *Checker, source: types.SignatureIndex, target: types.SignatureIndex, partialMatch: bool) bool {
    _ = c;
    _ = source;
    _ = target;
    _ = partialMatch;
    return false; // Stub
}

pub fn compareTypeParametersIdentical(c: *Checker, sourceParams: []types.TypeIndex, targetParams: []types.TypeIndex) bool {
    _ = c;
    _ = sourceParams;
    _ = targetParams;
    return false; // Stub
}

pub fn compareTypePredicatesIdentical(c: *Checker, source: ?*types.TypePredicate, target: ?*types.TypePredicate, compareTypes: ?*const fn (c: *Checker, source: types.TypeIndex, target: types.TypeIndex) types.Ternary) types.Ternary {
    _ = c;
    _ = source;
    _ = target;
    _ = compareTypes;
    return .False; // Stub
}

pub fn getEffectiveConstraintOfIntersection(c: *Checker, typeList: []types.TypeIndex, targetIsUnion: bool) types.TypeIndex {
    _ = typeList;
    _ = targetIsUnion;
    return c.anyType; // Stub
}

pub fn templateLiteralTypesDefinitelyUnrelated(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
    _ = c;
    _ = source;
    _ = target;
    return false; // Stub
}

pub fn isTypeMatchedByTemplateLiteralType(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, compareTypes: ?*const fn (c: *Checker, source: types.TypeIndex, target: types.TypeIndex) types.Ternary) bool {
    _ = c;
    _ = source;
    _ = target;
    _ = compareTypes;
    return false; // Stub
}

pub fn inferTypesFromTemplateLiteralType(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) ?[]types.TypeIndex {
    _ = c;
    _ = source;
    _ = target;
    return null; // Stub
}

pub fn inferFromLiteralPartsToTemplateLiteral(c: *Checker, sourceTexts: [][]const u8, sourceTypes: []types.TypeIndex, target: types.TypeIndex) ?[]types.TypeIndex {
    _ = c;
    _ = sourceTexts;
    _ = sourceTypes;
    _ = target;
    return null; // Stub
}

pub fn getStringLikeTypeForType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    _ = c;
    return t; // Stub
}

pub fn isValidTypeForTemplateLiteralPlaceholder(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, compareTypes: ?*const fn (c: *Checker, source: types.TypeIndex, target: types.TypeIndex) types.Ternary) bool {
    _ = c;
    _ = source;
    _ = target;
    _ = compareTypes;
    return false; // Stub
}

pub fn isMemberOfStringMapping(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
    _ = c;
    _ = source;
    _ = target;
    return false; // Stub
}

pub fn applyTargetStringMappingToSource(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) struct { types.TypeIndex, types.TypeIndex } {
    _ = c;
    return .{ source, target }; // Stub
}

pub fn getTypeOfPropertyInTypes(c: *Checker, typeList: []types.TypeIndex, name: []const u8) types.TypeIndex {
    _ = typeList;
    _ = name;
    return c.anyType; // Stub
}

pub fn getTypeOfPropertyInType(c: *Checker, t: types.TypeIndex, name: []const u8) types.TypeIndex {
    _ = t;
    _ = name;
    return c.undefinedType; // Stub
}

pub fn shouldCheckAsExcessProperty(c: *Checker, prop: ast.SymbolIndex, container: ast.SymbolIndex) bool {
    _ = c;
    _ = prop;
    _ = container;
    return false; // Stub
}

pub fn isIgnoredJsxProperty(c: *Checker, source: types.TypeIndex, sourceProp: ast.SymbolIndex) bool {
    _ = c;
    _ = source;
    _ = sourceProp;
    return false; // Stub
}

pub fn isTypeSubsetOf(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
    _ = c;
    _ = source;
    _ = target;
    return false; // Stub
}

pub fn isTypeSubsetOfUnion(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
    _ = c;
    _ = source;
    _ = target;
    return false; // Stub
}

pub fn compareTypesAssignableSimple(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) types.Ternary {
    if (isTypeRelatedTo(c, source, target, &c.assignableRelation)) {
        return .True;
    }
    return .False;
}

pub fn compareTypesAssignableWorker(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, reportErrors: bool) types.Ternary {
    _ = reportErrors;
    if (isTypeRelatedTo(c, source, target, &c.assignableRelation)) {
        return .True;
    }
    return .False;
}

pub fn compareTypesSubtypeOf(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) types.Ternary {
    if (isTypeRelatedTo(c, source, target, &c.subtypeRelation)) {
        return .True;
    }
    return .False;
}

pub fn isTypeAssignableTo(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
    return isTypeRelatedTo(c, source, target, &c.assignableRelation);
}

pub fn isTypeSubtypeOf(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
    return isTypeRelatedTo(c, source, target, &c.subtypeRelation);
}

pub fn isTypeStrictSubtypeOf(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
    return isTypeRelatedTo(c, source, target, &c.strictSubtypeRelation);
}

pub fn isTypeComparableTo(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
    return isTypeRelatedTo(c, source, target, &c.comparableRelation);
}

pub fn areTypesComparable(c: *Checker, type1: types.TypeIndex, type2: types.TypeIndex) bool {
    return isTypeComparableTo(c, type1, type2) or isTypeComparableTo(c, type2, type1);
}

pub fn isFreshLiteralType(c: *Checker, t_index: types.TypeIndex) bool {
    _ = c;
    _ = t_index;
    return false; // Type doesn't have fresh/regular directly in Zig TypeData yet
}

pub fn getRegularTypeOfLiteralType(c: *Checker, t_index: types.TypeIndex) types.TypeIndex {
    _ = c;
    return t_index; // Stub for now
}

// Stub for now
pub fn getRelationKey(source: types.TypeIndex, target: types.TypeIndex, intersectionState: IntersectionState, isIdentity: bool, ignoreConstraints: bool) CacheHashKey {
    _ = source;
    _ = target;
    _ = intersectionState;
    _ = isIdentity;
    _ = ignoreConstraints;
    return 0;
}

pub fn isTypeRelatedTo(c: *Checker, sourceIn: types.TypeIndex, targetIn: types.TypeIndex, relation: *Relation) bool {
    var source = sourceIn;
    var target = targetIn;

    if (isFreshLiteralType(c, source)) {
        source = getRegularTypeOfLiteralType(c, source);
    }
    if (isFreshLiteralType(c, target)) {
        target = getRegularTypeOfLiteralType(c, target);
    }
    if (source == target) {
        return true;
    }

    const source_flags = c.typesList.items[source].flags;
    const target_flags = c.typesList.items[target].flags;

    if (relation != &c.identityRelation) {
        if (relation == &c.comparableRelation and target_flags & types.TypeFlags.Never == 0 and isSimpleTypeRelatedTo(c, target, source, relation, null)) {
            return true;
        }
        if (isSimpleTypeRelatedTo(c, source, target, relation, null)) {
            return true;
        }
    } else if ((source_flags | target_flags) & (types.TypeFlags.UnionOrIntersection | types.TypeFlags.IndexedAccess | types.TypeFlags.Conditional | types.TypeFlags.Substitution) == 0) {
        if (source_flags != target_flags) {
            return false;
        }
        if (source_flags & types.TypeFlags.Singleton != 0) {
            return true;
        }
    }

    if (source_flags & types.TypeFlags.Object != 0 and target_flags & types.TypeFlags.Object != 0) {
        const id = getRelationKey(source, target, IntersectionState_None, relation == &c.identityRelation, false);
        const related = relation.get(id);
        if (related != RelationComparisonResult_None) {
            return related & RelationComparisonResult_Succeeded != 0;
        }
    }

    if (source_flags & types.TypeFlags.StructuredOrInstantiable != 0 or target_flags & types.TypeFlags.StructuredOrInstantiable != 0) {
        return checkTypeRelatedTo(c, source, target, relation, null);
    }

    return false;
}

pub fn isEnumTypeRelatedTo(c: *Checker, source: ast_gen.SymbolIndex, target: ast_gen.SymbolIndex, errorReporter: ErrorReporter) bool {
    const source_sym = &c.binder.symbols.items[source];
    const target_sym = &c.binder.symbols.items[target];

    const sourceSymbol = if (source_sym.Flags & symbol.SymbolFlags.EnumMember != 0) c.getParentOfSymbol(source) else source;
    const targetSymbol = if (target_sym.Flags & symbol.SymbolFlags.EnumMember != 0) c.getParentOfSymbol(target) else target;

    if (sourceSymbol == targetSymbol) {
        return true;
    }

    const sourceSymbol_sym = &c.binder.symbols.items[sourceSymbol];
    const targetSymbol_sym = &c.binder.symbols.items[targetSymbol];

    if (!std.mem.eql(u8, sourceSymbol_sym.Name, targetSymbol_sym.Name) or sourceSymbol_sym.Flags & symbol.SymbolFlags.RegularEnum == 0 or targetSymbol_sym.Flags & symbol.SymbolFlags.RegularEnum == 0) {
        return false;
    }

    const key = checker_mod.EnumRelationKey{ .sourceId = sourceSymbol, .targetId = targetSymbol };
    if (c.enumRelation.get(key)) |entry| {
        if (entry != RelationComparisonResult_None and !(entry & RelationComparisonResult_Failed != 0 and errorReporter != null)) {
            return entry & RelationComparisonResult_Succeeded != 0;
        }
    }

    const targetEnumType = c.getTypeOfSymbol(targetSymbol) catch unreachable;
    for (c.getPropertiesOfType(c.getTypeOfSymbol(sourceSymbol) catch unreachable)) |sourceProperty| {
        const sourceProperty_sym = &c.binder.symbols.items[sourceProperty];
        if (sourceProperty_sym.Flags & symbol.SymbolFlags.EnumMember != 0) {
            const targetProperty = c.getPropertyOfType(targetEnumType, sourceProperty_sym.Name);
            if (targetProperty == null or c.binder.symbols.items[targetProperty.?].Flags & symbol.SymbolFlags.EnumMember == 0) {
                if (errorReporter) |reporter| {
                    reporter(&diagnostics_gen.Property_0_is_missing_in_type_1, &[_][]const u8{ c.symbolToString(sourceProperty), c.TypeToStringEx(c.getDeclaredTypeOfSymbol(targetSymbol), 0, 0, null) });
                }
                c.enumRelation.put(c.allocator, key, RelationComparisonResult_Failed) catch unreachable;
                return false;
            }

            // Value comparison logic stubbed due to complex enum values in Go. Let's just compare them using the stubbed methods.
            const sourceValue = c.getEnumMemberValue(c.getDeclarationOfKind(sourceProperty, @import("../ast/kind.zig").Kind.EnumMember));
            const targetValue = c.getEnumMemberValue(c.getDeclarationOfKind(targetProperty.?, @import("../ast/kind.zig").Kind.EnumMember));

            if (sourceValue != targetValue) {
                // If they differ, they might be known values that differ.
                if (sourceValue != 0 and targetValue != 0) {
                    if (errorReporter) |reporter| {
                        reporter(&diagnostics_gen.Each_declaration_of_0_1_differs_in_its_value_where_2_was_expected_but_3_was_given, &[_][]const u8{ c.symbolToString(targetSymbol), c.symbolToString(targetProperty.?), c.valueToString(targetValue), c.valueToString(sourceValue) });
                    }
                    c.enumRelation.put(c.allocator, key, RelationComparisonResult_Failed) catch unreachable;
                    return false;
                }
                // Opaque members assumed numeric vs string
                // In zig, we can't do the string vs numeric check on ast.NodeIndex as easily, we'll assume failure for now
                if (errorReporter) |reporter| {
                    const knownStringValue = if (sourceValue != 0) sourceValue else targetValue;
                    reporter(&diagnostics_gen.One_value_of_0_1_is_the_string_2_and_the_other_is_assumed_to_be_an_unknown_numeric_value, &[_][]const u8{ c.symbolToString(targetSymbol), c.symbolToString(targetProperty.?), c.valueToString(knownStringValue) });
                }
                c.enumRelation.put(c.allocator, key, RelationComparisonResult_Failed) catch unreachable;
                return false;
            }
        }
    }

    c.enumRelation.put(c.allocator, key, RelationComparisonResult_Succeeded) catch unreachable;
    return true;
}

pub fn isUnknownLikeUnionType(c: *Checker, target: types.TypeIndex) bool {
    _ = c;
    _ = target;
    return false; // Stub
}

pub fn IsEmptyAnonymousObjectType(c: *Checker, source: types.TypeIndex) bool {
    return c.isEmptyAnonymousObjectType(source);
}

pub fn isSimpleTypeRelatedTo(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, relation: *Relation, errorReporter: ErrorReporter) bool {
    const source_t = &c.typesList.items[source];
    const target_t = &c.typesList.items[target];
    const s = source_t.flags;
    const t = target_t.flags;

    if (t & types.TypeFlags.Any != 0 or s & types.TypeFlags.Never != 0 or source == c.anyTypeIndex) { // wildcardType mapping to anyTypeIndex for now
        return true;
    }
    if (t & types.TypeFlags.Unknown != 0 and !(relation == &c.strictSubtypeRelation and s & types.TypeFlags.Any != 0)) {
        return true;
    }
    if (t & types.TypeFlags.Never != 0) {
        return false;
    }
    if (s & types.TypeFlags.Unknown != 0 and (relation == &c.assignableRelation or relation == &c.comparableRelation)) {
        return t & (types.TypeFlags.Unknown | types.TypeFlags.Any) != 0;
    }
    if (s & types.TypeFlags.StringLike != 0 and t & types.TypeFlags.String != 0) {
        return true;
    }
    if (s & types.TypeFlags.StringLiteral != 0 and s & types.TypeFlags.EnumLiteral != 0 and t & types.TypeFlags.StringLiteral != 0 and t & types.TypeFlags.EnumLiteral == 0 and source_t.data == .StringLiteral and target_t.data == .StringLiteral and std.mem.eql(u8, source_t.data.StringLiteral.text, target_t.data.StringLiteral.text)) {
        return true;
    }
    if (s & types.TypeFlags.NumberLike != 0 and t & types.TypeFlags.Number != 0) {
        return true;
    }
    if (s & types.TypeFlags.NumberLiteral != 0 and s & types.TypeFlags.EnumLiteral != 0 and t & types.TypeFlags.NumberLiteral != 0 and t & types.TypeFlags.EnumLiteral == 0 and source_t.data == .NumberLiteral and target_t.data == .NumberLiteral and source_t.data.NumberLiteral.value == target_t.data.NumberLiteral.value) {
        return true;
    }
    if (s & types.TypeFlags.BigIntLike != 0 and t & types.TypeFlags.BigInt != 0) {
        return true;
    }
    if (s & types.TypeFlags.BooleanLike != 0 and t & types.TypeFlags.Boolean != 0) {
        return true;
    }
    if (s & types.TypeFlags.ESSymbolLike != 0 and t & types.TypeFlags.ESSymbol != 0) {
        return true;
    }
    if (s & types.TypeFlags.Enum != 0 and t & types.TypeFlags.Enum != 0 and source_t.symbol != null and target_t.symbol != null and std.mem.eql(u8, c.binder.symbols.items[source_t.symbol.?].Name, c.binder.symbols.items[target_t.symbol.?].Name) and isEnumTypeRelatedTo(c, source_t.symbol.?, target_t.symbol.?, errorReporter)) {
        return true;
    }
    if (s & types.TypeFlags.EnumLiteral != 0 and t & types.TypeFlags.EnumLiteral != 0) {
        if (s & types.TypeFlags.Union != 0 and t & types.TypeFlags.Union != 0 and source_t.symbol != null and target_t.symbol != null and isEnumTypeRelatedTo(c, source_t.symbol.?, target_t.symbol.?, errorReporter)) {
            return true;
        }
        if (s & types.TypeFlags.StringLiteral != 0 and t & types.TypeFlags.StringLiteral != 0 and source_t.data == .StringLiteral and target_t.data == .StringLiteral and std.mem.eql(u8, source_t.data.StringLiteral.text, target_t.data.StringLiteral.text) and source_t.symbol != null and target_t.symbol != null and isEnumTypeRelatedTo(c, source_t.symbol.?, target_t.symbol.?, errorReporter)) {
            return true;
        }
        if (s & types.TypeFlags.NumberLiteral != 0 and t & types.TypeFlags.NumberLiteral != 0 and source_t.data == .NumberLiteral and target_t.data == .NumberLiteral and source_t.data.NumberLiteral.value == target_t.data.NumberLiteral.value and source_t.symbol != null and target_t.symbol != null and isEnumTypeRelatedTo(c, source_t.symbol.?, target_t.symbol.?, errorReporter)) {
            return true;
        }
    }
    if (s & types.TypeFlags.Undefined != 0 and (!c.strictNullChecks and t & types.TypeFlags.UnionOrIntersection == 0 or t & (types.TypeFlags.Undefined | types.TypeFlags.Void) != 0)) {
        return true;
    }
    if (s & types.TypeFlags.Null != 0 and (!c.strictNullChecks and t & types.TypeFlags.UnionOrIntersection == 0 or t & types.TypeFlags.Null != 0)) {
        return true;
    }
    if (s & types.TypeFlags.Object != 0 and t & types.TypeFlags.NonPrimitive != 0 and !(relation == &c.strictSubtypeRelation and IsEmptyAnonymousObjectType(c, source) and source_t.objectFlags & types.ObjectFlags.FreshLiteral == 0)) {
        return true;
    }
    if (relation == &c.assignableRelation or relation == &c.comparableRelation) {
        if (s & types.TypeFlags.Any != 0) {
            return true;
        }
        if (s & types.TypeFlags.Number != 0 and (t & types.TypeFlags.Enum != 0 or t & types.TypeFlags.NumberLiteral != 0 and t & types.TypeFlags.EnumLiteral != 0)) {
            return true;
        }
        if (s & types.TypeFlags.NumberLiteral != 0 and s & types.TypeFlags.EnumLiteral == 0 and (t & types.TypeFlags.Enum != 0 or t & types.TypeFlags.NumberLiteral != 0 and t & types.TypeFlags.EnumLiteral != 0 and source_t.data == .NumberLiteral and target_t.data == .NumberLiteral and source_t.data.NumberLiteral.value == target_t.data.NumberLiteral.value)) {
            return true;
        }
        if (isUnknownLikeUnionType(c, target)) {
            return true;
        }
    }
    return false;
}

pub fn createDiagnosticChainFromErrorChain(chain: ?*ErrorChain, errorNode: ast_gen.NodeIndex, relatedInfo: []const diagnostics.Diagnostic) ?diagnostics.Diagnostic {
    var current: ?*ErrorChain = chain;
    while (current != null and current.?.message.elidedInCompatabilityPyramid) {
        current = current.?.next;
    }
    if (current == null) {
        return null;
    }
    const next = createDiagnosticChainFromErrorChain(current.?.next, errorNode, relatedInfo);
    if (next == null) {
        return utilities.newDiagnosticForNode(errorNode, current.?.message); // TODO: SetRelatedInfo
    }
    return utilities.newDiagnosticChainForNode(next.?, errorNode, current.?.message);
}

pub fn isConversionOrInterfaceImplementationMessage(message: *const diagnostics.Message) bool {
    return message == &diagnostics_gen.Class_0_incorrectly_implements_interface_1 or
        message == &diagnostics_gen.Class_0_incorrectly_implements_class_1_Did_you_mean_to_extend_1_and_inherit_its_members_as_a_subclass or
        message == &diagnostics_gen.Conversion_of_type_0_to_type_1_may_be_a_mistake_because_neither_type_sufficiently_overlaps_with_the_other_If_this_was_intentional_convert_the_expression_to_unknown_first or
        message == &diagnostics_gen.Its_instance_type_0_is_not_a_valid_JSX_element or
        message == &diagnostics_gen.Its_return_type_0_is_not_a_valid_JSX_element or
        message == &diagnostics_gen.Its_element_type_0_is_not_a_valid_JSX_element;
}

pub fn getBestMatchIndexedAccessTypeOrUndefined(c: *Checker, source: types.TypeIndex, target: types.TypeIndex, nameType: types.TypeIndex) ?types.TypeIndex {
    if (c.getIndexedAccessTypeOrUndefined(target, nameType, 0, null, null)) |idx| {
        return idx;
    }
    if (c.getTypeFlags(target) & types.TypeFlags.Union != 0) {
        if (c.getBestMatchingType(source, target, &compareTypesAssignableSimple)) |best| {
            return c.getIndexedAccessTypeOrUndefined(best, nameType, 0, null, null);
        }
    }
    return null;
}

pub fn checkExpressionForMutableLocationWithContextualType(c: *Checker, next: ast.NodeIndex, sourcePropType: types.TypeIndex) types.TypeIndex {
    c.pushContextualType(next, sourcePropType, false);
    const result = c.checkExpressionForMutableLocation(next, types.CheckMode.Contextual);
    c.popContextualType();
    return result;
}

pub fn elaborateArrowFunction(c: *Checker, node: ast.NodeIndex, source: types.TypeIndex, target: types.TypeIndex, relation: *Relation, diagnosticOutput: ?*std.ArrayListUnmanaged(diagnostics.Diagnostic)) bool {
    const ast_data = c.binder.ast;
    const body = ast_data.getBody(node);
    if (body != 0 and ast_data.nodes.items[body].tag == .Block) {
        return false;
    }
    const params = ast_data.getParameters(node);
    for (params) |param| {
        if (utilities.hasType(ast_data, param)) {
            return false;
        }
    }
    const sourceSig = c.getSingleCallSignature(source);
    if (sourceSig == null) {
        return false;
    }
    const targetSignatures = c.getSignaturesOfType(target, types.SignatureKind.Call);
    if (targetSignatures.len == 0) {
        return false;
    }
    const returnExpression = body;
    const sourceReturn = c.getReturnTypeOfSignature(sourceSig.?);

    // getUnionType mapped from targetSignatures using getReturnTypeOfSignature
    // Wait, let's just do it in a loop
    // In DoD we need allocator for this mapping.
    var targetReturns = std.ArrayList(types.TypeIndex).init(c.allocator);
    defer targetReturns.deinit();
    for (targetSignatures) |sig| {
        targetReturns.append(c.getReturnTypeOfSignature(sig)) catch unreachable;
    }
    const targetReturn = c.getUnionType(targetReturns.items);

    if (checkTypeRelatedTo(c, sourceReturn, targetReturn, relation, null)) {
        return false;
    }
    if (returnExpression != 0 and elaborateError(c, returnExpression, sourceReturn, targetReturn, relation, null, diagnosticOutput)) {
        return true;
    }
    return false;
}

pub fn compareTypePredicateRelatedTo(c: *Checker, source: *types.TypePredicate, target: *types.TypePredicate, reportErrors: bool, errorReporter: ErrorReporter, compareTypes: *const fn (c: *Checker, source: types.TypeIndex, target: types.TypeIndex, reportErrors: bool) types.Ternary) types.Ternary {
    if (source.kind != target.kind) {
        if (reportErrors) {
            errorReporter.?(c, &diagnostics_gen.A_this_based_type_guard_is_not_compatible_with_a_parameter_based_type_guard, &[_][]const u8{});
            errorReporter.?(c, &diagnostics_gen.Type_predicate_0_is_not_assignable_to_1, &[_][]const u8{ c.typePredicateToString(source), c.typePredicateToString(target) });
        }
        return types.Ternary.False;
    }
    if (source.kind == types.TypePredicateKind.Identifier or source.kind == types.TypePredicateKind.AssertsIdentifier) {
        if (source.parameterIndex != target.parameterIndex) {
            if (reportErrors) {
                errorReporter.?(c, &diagnostics_gen.Parameter_0_is_not_in_the_same_position_as_parameter_1, &[_][]const u8{ source.parameterName, target.parameterName });
                errorReporter.?(c, &diagnostics_gen.Type_predicate_0_is_not_assignable_to_1, &[_][]const u8{ c.typePredicateToString(source), c.typePredicateToString(target) });
            }
            return types.Ternary.False;
        }
    }
    var related: types.Ternary = types.Ternary.False;
    if (source.type == target.type) {
        related = types.Ternary.True;
    } else if (source.type != 0 and target.type != 0) {
        related = compareTypes(c, source.type, target.type, reportErrors);
    } else {
        related = types.Ternary.False;
    }
    return related;
}

pub fn getRestArrayTypeOfTupleType(c: *Checker, t: types.TypeIndex) ?types.TypeIndex {
    if (c.getRestTypeOfTupleType(t)) |restType| {
        return c.createArrayType(restType);
    }
    return null;
}

pub fn newTypePredicate(c: *Checker, kind: types.TypePredicateKind, parameterName: []const u8, parameterIndex: u32, t: types.TypeIndex) *types.TypePredicate {
    const pred = c.allocator.create(types.TypePredicate) catch unreachable;
    pred.* = types.TypePredicate{
        .kind = kind,
        .parameterIndex = parameterIndex,
        .parameterName = parameterName,
        .type = t,
    };
    return pred;
}

pub fn visibilityToString(flags: u32) []const u8 {
    if (flags & ast.ModifierFlags.Private != 0) {
        return "private";
    }
    if (flags & ast.ModifierFlags.Protected != 0) {
        return "protected";
    }
    return "public";
}

pub fn getPropertyNameArg(c: *Checker, arg: []const u8) []const u8 {
    if (arg.len != 0 and (arg[0] == '"' or arg[0] == '\'' or arg[0] == '`')) {
        return std.fmt.allocPrint(c.allocator, "[{s}]", .{arg}) catch unreachable;
    }
    return arg;
}
