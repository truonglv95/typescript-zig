const std = @import("std");
const ast = @import("../ast/ast.zig");
const ptype = @import("type.zig");
pub const lookup = @import("lookup.zig");

pub const PseudoChecker = struct {
    allocator: std.mem.Allocator,
    strictNullChecks: bool,
    exactOptionalPropertyTypes: bool,

    types: std.ArrayListUnmanaged(ptype.PseudoType),

    pub const PseudoTypeUndefined: ptype.PseudoTypeIndex = 1;
    pub const PseudoTypeNull: ptype.PseudoTypeIndex = 2;
    pub const PseudoTypeAny: ptype.PseudoTypeIndex = 3;
    pub const PseudoTypeString: ptype.PseudoTypeIndex = 4;
    pub const PseudoTypeNumber: ptype.PseudoTypeIndex = 5;
    pub const PseudoTypeBigInt: ptype.PseudoTypeIndex = 6;
    pub const PseudoTypeBoolean: ptype.PseudoTypeIndex = 7;
    pub const PseudoTypeFalse: ptype.PseudoTypeIndex = 8;
    pub const PseudoTypeTrue: ptype.PseudoTypeIndex = 9;

    pub fn init(allocator: std.mem.Allocator, strictNullChecks: bool, exactOptionalPropertyTypes: bool) !PseudoChecker {
        var checker = PseudoChecker{
            .allocator = allocator,
            .strictNullChecks = strictNullChecks,
            .exactOptionalPropertyTypes = exactOptionalPropertyTypes,
            .types = .empty,
        };
        // Index 0: invalid/null
        try checker.types.append(allocator, .{ .Undefined = {} });
        
        // Push singletons matching the indices above
        try checker.types.append(allocator, .{ .Undefined = {} });
        try checker.types.append(allocator, .{ .Null = {} });
        try checker.types.append(allocator, .{ .Any = {} });
        try checker.types.append(allocator, .{ .String = {} });
        try checker.types.append(allocator, .{ .Number = {} });
        try checker.types.append(allocator, .{ .BigInt = {} });
        try checker.types.append(allocator, .{ .Boolean = {} });
        try checker.types.append(allocator, .{ .False = {} });
        try checker.types.append(allocator, .{ .True = {} });

        return checker;
    }

    pub fn deinit(self: *PseudoChecker) void {
        self.types.deinit(self.allocator);
    }

    pub fn createType(self: *PseudoChecker, t: ptype.PseudoType) !ptype.PseudoTypeIndex {
        const index = @as(u32, @intCast(self.types.items.len));
        try self.types.append(self.allocator, t);
        return index;
    }

    pub fn getType(self: *const PseudoChecker, index: ptype.PseudoTypeIndex) ptype.PseudoType {
        return self.types.items[index];
    }
};
