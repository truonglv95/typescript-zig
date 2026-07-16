const std = @import("std");

/// This module provides reflection-driven object codec utilities for LSP structs.
/// In Zig, `std.json` naturally enforces that non-optional fields are present,
/// fulfilling the core strictness requirement of LSP object decoding.

/// unmarshalStruct decodes a JSON object into the struct type T,
/// enforcing object-kind and required-field strictness.
pub fn unmarshalStruct(comptime T: type, allocator: std.mem.Allocator, source: []const u8) !T {
    const parsed = try std.json.parseFromSlice(T, allocator, source, .{
        .ignore_unknown_fields = true,
    });
    return parsed.value;
}

/// marshalUnion encodes a union struct whose fields are all optional, exactly
/// one of which is set. It writes the single non-null field; if nullable, an
/// empty union marshals as null, otherwise an empty union is a programming error.
pub fn marshalUnion(v: anytype, jws: anytype, comptime name: []const u8, comptime nullable: bool) !void {
    const T = @TypeOf(v);
    const info = @typeInfo(T);

    if (info != .Struct) {
        @compileError("marshalUnion expects a struct");
    }

    var count: usize = 0;
    
    inline for (info.Struct.fields) |field| {
        const val = @field(v, field.name);
        if (@typeInfo(field.type) == .Optional) {
            if (val != null) {
                count += 1;
                if (count == 1) {
                    try jws.write(val.?);
                }
            }
        } else {
            count += 1;
            if (count == 1) {
                try jws.write(val);
            }
        }
    }

    if (nullable) {
        if (count > 1) {
            std.debug.panic("more than one element of {s} is set", .{name});
        }
        if (count == 0) {
            try jws.write(null);
        }
    } else {
        if (count != 1) {
            std.debug.panic("exactly one element of {s} should be set", .{name});
        }
    }
}

/// countNonNil returns the number of non-null optional/pointer fields in the struct v.
/// Used to assert externally-tagged unions have exactly one arm set.
pub fn countNonNil(v: anytype) usize {
    const T = @TypeOf(v);
    const info = @typeInfo(T);
    if (info != .Struct) {
        @compileError("countNonNil expects a struct");
    }

    var count: usize = 0;
    inline for (info.Struct.fields) |field| {
        const val = @field(v, field.name);
        if (@typeInfo(field.type) == .Optional) {
            if (val != null) {
                count += 1;
            }
        } else {
            count += 1;
        }
    }
    return count;
}
