const std = @import("std");
const types = @import("types.zig");
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const tracing = @import("../tracing/tracing.zig");

pub const Tracer = struct {
    tracing: ?*tracing.Tracing,
    checkerIndex: u32,

    pub fn init(tr: ?*tracing.Tracing, checkerIndex: u32) Tracer {
        return .{
            .tracing = tr,
            .checkerIndex = checkerIndex,
        };
    }

    pub fn recordType(self: *Tracer, c: *Checker, t: types.TypeIndex) void {
        if (self.tracing) |tr| {
            const tr_t = TracedTypeAdapter.create(c.arena.allocator(), c, t);
            tr.tracers.items[self.checkerIndex].recordType(tr_t);
        }
    }

    pub fn push(self: *Tracer, phase: tracing.Phase, name: []const u8, args: ?tracing.TraceArgs, separateBeginAndEnd: bool) void {
        if (self.tracing) |tr| {
            var argsWithId = args orelse tracing.TraceArgs{};
            argsWithId.checkerId = @intCast(self.checkerIndex);
            _ = tr.push(phase, name, argsWithId, separateBeginAndEnd);
        }
    }

    pub fn instant(self: *Tracer, phase: tracing.Phase, name: []const u8, args: ?tracing.TraceArgs) void {
        if (self.tracing) |tr| {
            var argsWithId = args orelse tracing.TraceArgs{};
            argsWithId.checkerId = @intCast(self.checkerIndex);
            tr.instant(phase, name, argsWithId);
        }
    }
};

pub const TracedTypeAdapter = struct {
    checker: *Checker,
    t: types.TypeIndex,

    const VTable = tracing.TracedType.VTable{
        .id = id_impl,
        .formatFlags = formatFlags_impl,
        .isConditional = isConditional_impl,
        .symbolName = symbolName_impl,
        .aliasSymbolName = aliasSymbolName_impl,
        .firstDeclaration = firstDeclaration_impl,
        .aliasTypeArguments = aliasTypeArguments_impl,
        .intrinsicName = intrinsicName_impl,
        .unionTypes = unionTypes_impl,
        .intersectionTypes = intersectionTypes_impl,
        .indexType = indexType_impl,
        .indexedAccessObjectType = indexedAccessObjectType_impl,
        .indexedAccessIndexType = indexedAccessIndexType_impl,
        .conditionalCheckType = conditionalCheckType_impl,
        .conditionalExtendsType = conditionalExtendsType_impl,
        .conditionalTrueType = conditionalTrueType_impl,
        .conditionalFalseType = conditionalFalseType_impl,
        .substitutionBaseType = substitutionBaseType_impl,
        .substitutionConstraintType = substitutionConstraintType_impl,
        .referenceTarget = referenceTarget_impl,
        .referenceTypeArguments = referenceTypeArguments_impl,
        .referenceLocation = referenceLocation_impl,
        .reverseMappedSourceType = reverseMappedSourceType_impl,
        .reverseMappedMappedType = reverseMappedMappedType_impl,
        .reverseMappedConstraintType = reverseMappedConstraintType_impl,
        .evolvingArrayElementType = evolvingArrayElementType_impl,
        .evolvingArrayFinalType = evolvingArrayFinalType_impl,
        .isTuple = isTuple_impl,
        .destructuringPattern = destructuringPattern_impl,
        .recursionIdentity = recursionIdentity_impl,
        .display = display_impl,
    };

    pub fn create(allocator: std.mem.Allocator, checker: *Checker, t: types.TypeIndex) tracing.TracedType {
        const ptr = allocator.create(TracedTypeAdapter) catch unreachable;
        ptr.* = .{ .checker = checker, .t = t };
        return .{
            .ptr = ptr,
            .vtable = &VTable,
        };
    }

    fn getSelf(ptr: *anyopaque) *TracedTypeAdapter {
        return @ptrCast(@alignCast(ptr));
    }

    fn id_impl(ptr: *anyopaque) u32 {
        return getSelf(ptr).t;
    }

    fn formatFlags_impl(ptr: *anyopaque, allocator: std.mem.Allocator) [][]const u8 {
        _ = ptr;
        _ = allocator;
        return &[_][]const u8{};
    }

    fn isConditional_impl(ptr: *anyopaque) bool {
        const self = getSelf(ptr);
        return (self.checker.getTypeFlags(self.t) & types.TypeFlags.Conditional) != 0;
    }

    fn symbolName_impl(ptr: *anyopaque, allocator: std.mem.Allocator) []const u8 {
        _ = ptr;
        _ = allocator;
        return "";
    }

    fn aliasSymbolName_impl(ptr: *anyopaque, allocator: std.mem.Allocator) []const u8 {
        _ = ptr;
        _ = allocator;
        return "";
    }

    fn firstDeclaration_impl(ptr: *anyopaque) ?tracing.Location {
        _ = ptr;
        return null;
    }

    fn aliasTypeArguments_impl(ptr: *anyopaque, allocator: std.mem.Allocator) []tracing.TracedType {
        _ = ptr;
        _ = allocator;
        return &[_]tracing.TracedType{};
    }

    fn intrinsicName_impl(ptr: *anyopaque, allocator: std.mem.Allocator) []const u8 {
        _ = allocator;
        const self = getSelf(ptr);
        if ((self.checker.getTypeFlags(self.t) & types.TypeFlags.Intrinsic) == 0) return "";
        return self.checker.getIntrinsicName(self.t);
    }

    fn unionTypes_impl(ptr: *anyopaque, allocator: std.mem.Allocator) []tracing.TracedType {
        _ = ptr;
        _ = allocator;
        return &[_]tracing.TracedType{};
    }

    fn intersectionTypes_impl(ptr: *anyopaque, allocator: std.mem.Allocator) []tracing.TracedType {
        _ = ptr;
        _ = allocator;
        return &[_]tracing.TracedType{};
    }

    fn indexType_impl(ptr: *anyopaque) ?tracing.TracedType {
        _ = ptr;
        return null;
    }

    fn indexedAccessObjectType_impl(ptr: *anyopaque) ?tracing.TracedType {
        _ = ptr;
        return null;
    }

    fn indexedAccessIndexType_impl(ptr: *anyopaque) ?tracing.TracedType {
        _ = ptr;
        return null;
    }

    fn conditionalCheckType_impl(ptr: *anyopaque) ?tracing.TracedType {
        _ = ptr;
        return null;
    }

    fn conditionalExtendsType_impl(ptr: *anyopaque) ?tracing.TracedType {
        _ = ptr;
        return null;
    }

    fn conditionalTrueType_impl(ptr: *anyopaque) ?tracing.TracedType {
        _ = ptr;
        return null;
    }

    fn conditionalFalseType_impl(ptr: *anyopaque) ?tracing.TracedType {
        _ = ptr;
        return null;
    }

    fn substitutionBaseType_impl(ptr: *anyopaque) ?tracing.TracedType {
        _ = ptr;
        return null;
    }

    fn substitutionConstraintType_impl(ptr: *anyopaque) ?tracing.TracedType {
        _ = ptr;
        return null;
    }

    fn referenceTarget_impl(ptr: *anyopaque) ?tracing.TracedType {
        _ = ptr;
        return null;
    }

    fn referenceTypeArguments_impl(ptr: *anyopaque, allocator: std.mem.Allocator) []tracing.TracedType {
        _ = ptr;
        _ = allocator;
        return &[_]tracing.TracedType{};
    }

    fn referenceLocation_impl(ptr: *anyopaque) ?tracing.Location {
        _ = ptr;
        return null;
    }

    fn reverseMappedSourceType_impl(ptr: *anyopaque) ?tracing.TracedType {
        _ = ptr;
        return null;
    }

    fn reverseMappedMappedType_impl(ptr: *anyopaque) ?tracing.TracedType {
        _ = ptr;
        return null;
    }

    fn reverseMappedConstraintType_impl(ptr: *anyopaque) ?tracing.TracedType {
        _ = ptr;
        return null;
    }

    fn evolvingArrayElementType_impl(ptr: *anyopaque) ?tracing.TracedType {
        _ = ptr;
        return null;
    }

    fn evolvingArrayFinalType_impl(ptr: *anyopaque) ?tracing.TracedType {
        _ = ptr;
        return null;
    }

    fn isTuple_impl(ptr: *anyopaque) bool {
        _ = ptr;
        return false;
    }

    fn destructuringPattern_impl(ptr: *anyopaque) ?tracing.Location {
        _ = ptr;
        return null;
    }

    fn recursionIdentity_impl(ptr: *anyopaque) ?usize {
        _ = ptr;
        return null;
    }

    fn display_impl(ptr: *anyopaque, allocator: std.mem.Allocator) []const u8 {
        _ = ptr;
        _ = allocator;
        return "";
    }
};

pub fn newTracer(tr: *anyopaque, checkerIndex: *anyopaque) *anyopaque {
    _ = tr;
    _ = checkerIndex;
    return undefined;
}

pub fn copyWithCheckerIndex(t: *anyopaque, args: *anyopaque) *anyopaque {
    _ = t;
    _ = args;
    return undefined;
}

pub fn temporarilyAddCheckerIndex(t: *anyopaque, args: *anyopaque) *anyopaque {
    _ = t;
    _ = args;
    return undefined;
}

pub fn id(a: *anyopaque) i32 {
    _ = a;
    return 0;
}

pub fn formatFlags(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn isConditional(a: *anyopaque) bool {
    _ = a;
    return false;
}

pub fn symbol(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn aliasSymbol(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn aliasTypeArguments(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn intrinsicName(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn unionTypes(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn intersectionTypes(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn indexType(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn indexedAccessObjectType(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn indexedAccessIndexType(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn conditionalCheckType(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn conditionalExtendsType(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn conditionalTrueType(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn conditionalFalseType(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn substitutionBaseType(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn substitutionConstraintType(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn referenceTarget(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn referenceTypeArguments(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn referenceNode(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn reverseMappedSourceType(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn reverseMappedMappedType(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn reverseMappedConstraintType(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn evolvingArrayElementType(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn evolvingArrayFinalType(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn isTuple(a: *anyopaque) bool {
    _ = a;
    return false;
}

pub fn pattern(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn recursionIdentity(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn display(a: *anyopaque) *anyopaque {
    _ = a;
    return undefined;
}

pub fn wrapType(t: *anyopaque) *anyopaque {
    _ = t;
    return undefined;
}

pub fn wrapTypes(types_: *anyopaque) *anyopaque {
    _ = types_;
    return undefined;
}
