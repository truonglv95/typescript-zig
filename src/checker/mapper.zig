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
};

pub const ArrayTypeMapper = struct {
    sources: []const TypeIndex,
    targets: []const TypeIndex,
};

pub const ArrayToSingleTypeMapper = struct {
    sources: []const TypeIndex,
    target: TypeIndex,
};

pub const LazyTypeTarget = enum(u8) {
    Placeholder,
};

pub const DeferredTypeMapper = struct {
    sources: []const TypeIndex,
    targets: []const LazyTypeTarget,
};

pub const FunctionMapperContext = enum(u8) {
    Placeholder,
};

pub const FunctionTypeMapper = struct {
    context: FunctionMapperContext,
};

pub const MergedTypeMapper = struct {
    m1: TypeMapperIndex,
    m2: TypeMapperIndex,
};

pub const CompositeTypeMapper = struct {
    m1: TypeMapperIndex,
    m2: TypeMapperIndex,
};

pub const InferenceTypeMapper = struct {
    n: u32, // InferenceContextIndex
    fixing: bool,
};

// Factory functions
pub fn createSimpleTypeMapper(c: *Checker, source: TypeIndex, target: TypeIndex) TypeMapperIndex {
    return checker_mod.addTypeMapper(c, .{ .kind = .Simple, .data = .{ .Simple = .{ .source = source, .target = target } } });
}

pub fn createArrayTypeMapper(c: *Checker, sources: []const TypeIndex, targets: []const TypeIndex) TypeMapperIndex {
    return checker_mod.addTypeMapper(c, .{ .kind = .Array, .data = .{ .Array = .{ .sources = sources, .targets = targets } } });
}

pub fn createArrayToSingleTypeMapper(c: *Checker, sources: []const TypeIndex, target: TypeIndex) TypeMapperIndex {
    return checker_mod.addTypeMapper(c, .{ .kind = .ArrayToSingle, .data = .{ .ArrayToSingle = .{ .sources = sources, .target = target } } });
}

pub fn createDeferredTypeMapper(c: *Checker, sources: []const TypeIndex, targets: []const LazyTypeTarget) TypeMapperIndex {
    return checker_mod.addTypeMapper(c, .{ .kind = .Deferred, .data = .{ .Deferred = .{ .sources = sources, .targets = targets } } });
}

pub fn createFunctionTypeMapper(c: *Checker, context: FunctionMapperContext) TypeMapperIndex {
    return checker_mod.addTypeMapper(c, .{ .kind = .Function, .data = .{ .Function = .{ .context = context } } });
}

pub fn createInferenceTypeMapper(c: *Checker, n: u32, fixing: bool) TypeMapperIndex {
    return checker_mod.addTypeMapper(c, .{ .kind = .Inference, .data = .{ .Inference = .{ .n = n, .fixing = fixing } } });
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

pub fn map(m: *anyopaque, t: *anyopaque) *anyopaque {
    _ = m;
    _ = t;
    return undefined;
}

pub fn kind(m: *anyopaque) *anyopaque {
    _ = m;
    return undefined;
}

pub fn newTypeMapper(sources: *anyopaque, targets: *anyopaque) *anyopaque {
    _ = sources;
    _ = targets;
    return undefined;
}

pub fn newBackreferenceMapper(c: *Checker, context: *anyopaque, index: *anyopaque) *anyopaque {
    _ = c;
    _ = context;
    _ = index;
    return undefined;
}

pub fn newSimpleTypeMapper(source: *anyopaque, target: *anyopaque) *anyopaque {
    _ = source;
    _ = target;
    return undefined;
}

pub fn newArrayTypeMapper(sources: *anyopaque, targets: *anyopaque) *anyopaque {
    _ = sources;
    _ = targets;
    return undefined;
}

pub fn newArrayToSingleTypeMapper(sources: *anyopaque, target: *anyopaque) *anyopaque {
    _ = sources;
    _ = target;
    return undefined;
}

pub fn newDeferredTypeMapper(sources: *anyopaque, targets: *anyopaque) *anyopaque {
    _ = sources;
    _ = targets;
    return undefined;
}

pub fn newFunctionTypeMapper(fn_: *anyopaque) *anyopaque {
    _ = fn_;
    return undefined;
}

pub fn newMergedTypeMapper(m1: *anyopaque, m2: *anyopaque) *anyopaque {
    _ = m1;
    _ = m2;
    return undefined;
}

pub fn newCompositeTypeMapper(c: *anyopaque, m1: *anyopaque, m2: *anyopaque) *anyopaque {
    _ = c;
    _ = m1;
    _ = m2;
    return undefined;
}

pub fn newInferenceTypeMapper(c: *Checker, n: *anyopaque, fixing: *anyopaque) *anyopaque {
    _ = c;
    _ = n;
    _ = fixing;
    return undefined;
}
