const std = @import("std");
const core = @import("../core/core.zig");
const types = @import("types.zig");
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const TypeIndex = types.TypeIndex;

pub const TypeMapperIndex = u32;

pub const TypeMapperKind = enum(u8) {
    Unknown,
    Simple,
    Array,
    Merged,
};

pub const TypeMapper = union(enum) {
    Simple: SimpleTypeMapper,
    Array: ArrayTypeMapper,
    ArrayToSingle: ArrayToSingleTypeMapper,
    Deferred: DeferredTypeMapper,
    Function: FunctionTypeMapper,
    Merged: MergedTypeMapper,
    Composite: CompositeTypeMapper,
    Inference: InferenceTypeMapper,

    pub fn mapType(self: TypeMapper, c: *Checker, t: TypeIndex) TypeIndex {
        switch (self) {
            .Simple => |*m| return m.mapType(t),
            .Array => |*m| return m.mapType(t),
            .ArrayToSingle => |*m| return m.mapType(t),
            .Deferred => |*m| return m.mapType(c, t),
            .Function => |*m| return m.mapType(c, t),
            .Merged => |*m| return m.mapType(c, t),
            .Composite => |*m| return m.mapType(c, t),
            .Inference => |*m| return m.mapType(c, t),
        }
    }

    pub fn getKind(self: TypeMapper) TypeMapperKind {
        switch (self) {
            .Simple => return .Simple,
            .Array => return .Array,
            .Merged => return .Merged,
            else => return .Unknown,
        }
    }

    pub fn mapsThisOnly(self: TypeMapper, c: *Checker) bool {
        switch (self) {
            .Simple => |*m| return m.mapsThisOnly(c),
            .Array => |*m| return m.mapsThisOnly(c),
            .ArrayToSingle => |*m| return m.mapsThisOnly(c),
            .Deferred => |*m| return m.mapsThisOnly(c),
            else => return false,
        }
    }
};

pub const SimpleTypeMapper = struct {
    source: TypeIndex,
    target: TypeIndex,

    pub fn mapType(self: *const SimpleTypeMapper, t: TypeIndex) TypeIndex {
        if (t == self.source) return self.target;
        return t;
    }

    pub fn mapsThisOnly(self: *const SimpleTypeMapper, c: *Checker) bool {
        return c.isThisTypeParameter(self.source);
    }
};

pub const ArrayTypeMapper = struct {
    sources: []const TypeIndex,
    targets: []const TypeIndex,

    pub fn mapType(self: *const ArrayTypeMapper, t: TypeIndex) TypeIndex {
        for (self.sources, 0..) |s, i| {
            if (t == s) return self.targets[i];
        }
        return t;
    }

    pub fn mapsThisOnly(self: *const ArrayTypeMapper, c: *Checker) bool {
        return self.sources.len == 1 and c.isThisTypeParameter(self.sources[0]);
    }
};

pub const ArrayToSingleTypeMapper = struct {
    sources: []const TypeIndex,
    target: TypeIndex,

    pub fn mapType(self: *const ArrayToSingleTypeMapper, t: TypeIndex) TypeIndex {
        for (self.sources) |s| {
            if (t == s) return self.target;
        }
        return t;
    }

    pub fn mapsThisOnly(self: *const ArrayToSingleTypeMapper, c: *Checker) bool {
        return self.sources.len == 1 and c.isThisTypeParameter(self.sources[0]);
    }
};

pub const LazyTypeTarget = enum(u8) {
    Placeholder,
};

pub const DeferredTypeMapper = struct {
    sources: []const TypeIndex,
    targets: []const LazyTypeTarget,

    pub fn mapType(self: *const DeferredTypeMapper, c: *Checker, t: TypeIndex) TypeIndex {
        for (self.sources, 0..) |s, i| {
            if (t == s) {
                return c.evaluateLazyTypeTarget(self.targets[i]);
            }
        }
        return t;
    }

    pub fn mapsThisOnly(self: *const DeferredTypeMapper, c: *Checker) bool {
        return self.sources.len == 1 and c.isThisTypeParameter(self.sources[0]);
    }
};

pub const FunctionMapperContext = enum(u8) {
    Placeholder,
};

pub const FunctionTypeMapper = struct {
    context: FunctionMapperContext,

    pub fn mapType(self: *const FunctionTypeMapper, c: *Checker, t: TypeIndex) TypeIndex {
        return c.evaluateFunctionMapper(self.context, t);
    }
};

pub const MergedTypeMapper = struct {
    m1: TypeMapperIndex,
    m2: TypeMapperIndex,

    pub fn mapType(self: *const MergedTypeMapper, c: *Checker, t: TypeIndex) TypeIndex {
        const mappedT1 = c.mapTypeWithMapper(self.m1, t);
        return c.mapTypeWithMapper(self.m2, mappedT1);
    }
};

pub const CompositeTypeMapper = struct {
    m1: TypeMapperIndex,
    m2: TypeMapperIndex,

    pub fn mapType(self: *const CompositeTypeMapper, c: *Checker, t: TypeIndex) TypeIndex {
        const t1 = c.mapTypeWithMapper(self.m1, t);
        if (t1 != t) {
            return c.instantiateType(t1, self.m2);
        }
        return c.mapTypeWithMapper(self.m2, t);
    }
};

pub const InferenceTypeMapper = struct {
    n: u32, // InferenceContextIndex
    fixing: bool,

    pub fn mapType(self: *const InferenceTypeMapper, c: *Checker, t: TypeIndex) TypeIndex {
        const context = c.getInferenceContext(self.n);
        for (context.inferences, 0..) |inferenceIndex, i| {
            const inference = c.getInferenceInfo(inferenceIndex);
            if (t == inference.typeParameter) {
                if (self.fixing and !inference.isFixed) {
                    c.inferFromIntraExpressionSites(self.n);
                    c.clearCachedInferences(context.inferences);
                    c.setInferenceFixed(inferenceIndex, true);
                }
                return c.getInferredType(self.n, @intCast(i));
            }
        }
        return t;
    }
};

// Factory functions
pub fn createSimpleTypeMapper(c: *Checker, source: TypeIndex, target: TypeIndex) TypeMapperIndex {
    return checker_mod.addTypeMapper(c, .{ .kind = .Simple, .data = .{ .Simple = .{ .source = source, .target = target } } });
}

pub fn createArrayTypeMapper(c: *Checker, sources: []const TypeIndex, targets: []const TypeIndex) TypeMapperIndex {
    return checker_mod.addTypeMapper(c, .{ .kind = .Array, .data = .{ .Array = .{ .sources = sources, .targets = targets } } });
}

pub fn createTypeMapper(c: *Checker, sources: []const TypeIndex, targets: []const TypeIndex) TypeMapperIndex {
    if (sources.len == 1) {
        return createSimpleTypeMapper(c, sources[0], targets[0]);
    }
    return createArrayTypeMapper(c, sources, targets);
}

pub fn combineTypeMappers(c: *Checker, m1: TypeMapperIndex, m2: TypeMapperIndex) TypeMapperIndex {
    if (m1 != 0) {
        return checker_mod.addTypeMapper(c, .{ .kind = .Composite, .data = .{ .Composite = .{ .m1 = m1, .m2 = m2 } } });
    }
    return m2;
}

pub fn mergeTypeMappers(c: *Checker, m1: TypeMapperIndex, m2: TypeMapperIndex) TypeMapperIndex {
    if (m1 != 0) {
        return checker_mod.addTypeMapper(c, .{ .kind = .Merged, .data = .{ .Merged = .{ .mapper1 = m1, .mapper2 = m2 } } });
    }
    return m2;
}

pub fn prependTypeMapping(c: *Checker, source: TypeIndex, target: TypeIndex, mapper: TypeMapperIndex) TypeMapperIndex {
    if (mapper == 0) {
        return createSimpleTypeMapper(c, source, target);
    }
    return mergeTypeMappers(c, createSimpleTypeMapper(c, source, target), mapper);
}

pub fn appendTypeMapping(c: *Checker, mapper: TypeMapperIndex, source: TypeIndex, target: TypeIndex) TypeMapperIndex {
    if (mapper == 0) {
        return createSimpleTypeMapper(c, source, target);
    }
    return mergeTypeMappers(c, mapper, createSimpleTypeMapper(c, source, target));
}

pub fn createBackreferenceMapper(c: *Checker, contextIndex: u32, index: usize) TypeMapperIndex {
    const context = c.getInferenceContext(contextIndex);
    const forwardInferences = context.inferences[index..];
    const typeParameters = c.arena.allocator().alloc(TypeIndex, forwardInferences.len) catch unreachable;
    for (forwardInferences, 0..) |infIndex, i| {
        typeParameters[i] = c.getInferenceInfo(infIndex).typeParameter;
    }
    return checker_mod.addTypeMapper(c, .{ .kind = .ArrayToSingle, .data = .{ .ArrayToSingle = .{ .sources = typeParameters, .target = c.globalUnknownType() } } });
}
