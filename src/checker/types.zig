const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");

pub const TypeIndex = u32;

pub const TypeFlags = struct {
    pub const None: u32 = 0;
    pub const Any: u32 = 1 << 0;
    pub const Unknown: u32 = 1 << 1;
    pub const Undefined: u32 = 1 << 2;
    pub const Null: u32 = 1 << 3;
    pub const Void: u32 = 1 << 4;
    pub const String: u32 = 1 << 5;
    pub const Number: u32 = 1 << 6;
    pub const BigInt: u32 = 1 << 7;
    pub const Boolean: u32 = 1 << 8;
    pub const ESSymbol: u32 = 1 << 9;
    pub const StringLiteral: u32 = 1 << 10;
    pub const NumberLiteral: u32 = 1 << 11;
    pub const BigIntLiteral: u32 = 1 << 12;
    pub const BooleanLiteral: u32 = 1 << 13;
    pub const UniqueESSymbol: u32 = 1 << 14;
    pub const EnumLiteral: u32 = 1 << 15;
    pub const Enum: u32 = 1 << 16;
    pub const NonPrimitive: u32 = 1 << 17;
    pub const Never: u32 = 1 << 18;
    pub const TypeParameter: u32 = 1 << 19;
    pub const Object: u32 = 1 << 20;
    pub const Index: u32 = 1 << 21;
    pub const TemplateLiteral: u32 = 1 << 22;
    pub const StringMapping: u32 = 1 << 23;
    pub const Substitution: u32 = 1 << 24;
    pub const IndexedAccess: u32 = 1 << 25;
    pub const Conditional: u32 = 1 << 26;
    pub const Union: u32 = 1 << 27;
    pub const Intersection: u32 = 1 << 28;
};

pub const TypeData = union(enum) {
    Intrinsic: void,
    Object: struct {}, // TODO: Expand later
    Union: struct {
        types: u32, // index into some type list array
    },
    StringLiteral: struct {
        text: []const u8,
    },
    NumberLiteral: struct {
        value: f64,
    },
};

pub const Type = struct {
    Flags: u32,
    ObjectFlags: u32,
    Symbol: ?ast_gen.SymbolIndex,
    Data: TypeData,
};
