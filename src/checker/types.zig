const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");

pub const TypeIndex = u32;

/// TypeFlags - bitmask flags 1:1 với Go checker/types.go
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

    // Composite flags
    pub const Literal: u32 = StringLiteral | NumberLiteral | BigIntLiteral | BooleanLiteral;
    pub const Unit: u32 = Literal | UniqueESSymbol | Undefined | Null;
    pub const Primitive: u32 = String | Number | BigInt | Boolean | ESSymbol | Void | Undefined | Null | Never | Literal | UniqueESSymbol;
    pub const NumberLike: u32 = Number | NumberLiteral | Enum;
    pub const StringLike: u32 = String | StringLiteral | TemplateLiteral | StringMapping;
    pub const BooleanLike: u32 = Boolean | BooleanLiteral;
    pub const EnumLike: u32 = Enum | EnumLiteral;
    pub const UnionOrIntersection: u32 = Union | Intersection;
    pub const StructuredType: u32 = Object | Union | Intersection;
    pub const TypeVariable: u32 = TypeParameter | IndexedAccess;
    pub const InstantiableNonPrimitive: u32 = TypeVariable | Substitution | Conditional | TemplateLiteral | StringMapping;
    pub const Instantiable: u32 = InstantiableNonPrimitive | Index;
    pub const StructuredOrInstantiable: u32 = StructuredType | Instantiable;
    pub const ObjectFlagsType: u32 = Any | Nullable | Never | Object | Union | Intersection;
    pub const Nullable: u32 = Undefined | Null;
    pub const NonPrimitiveUnion: u32 = NonPrimitive | Union;
    pub const IncludesWildcard: u32 = Index;
    pub const IncludesInstantiable: u32 = Substitution;
    pub const IncludesEmptyObject: u32 = NonPrimitive;
    pub const IncludesIntersection: u32 = Conditional;
    pub const IncludesConstrainedTypeVariable: u32 = ESSymbol;
    pub const IncludesMissingType: u32 = TemplateLiteral;
    pub const NotUnionOrUnit: u32 = ~(Union | Unit);
};

/// ObjectFlags - bitmask cho Object types (1:1 với Go)
pub const ObjectFlags = struct {
    pub const None: u32 = 0;
    pub const Class: u32 = 1 << 0;
    pub const Interface: u32 = 1 << 1;
    pub const Reference: u32 = 1 << 2;
    pub const Tuple: u32 = 1 << 3;
    pub const Anonymous: u32 = 1 << 4;
    pub const Mapped: u32 = 1 << 5;
    pub const Instantiated: u32 = 1 << 6;
    pub const ObjectLiteral: u32 = 1 << 7;
    pub const EvolvingArray: u32 = 1 << 8;
    pub const ObjectLiteralPatternWithComputedProperties: u32 = 1 << 9;
    pub const ReverseMapped: u32 = 1 << 10;
    pub const JsxAttributes: u32 = 1 << 11;
    pub const JSLiteral: u32 = 1 << 12;
    pub const FreshLiteral: u32 = 1 << 13;
    pub const ArrayLiteral: u32 = 1 << 14;
    pub const PrimitiveUnion: u32 = 1 << 16;
    pub const ContainsWideningType: u32 = 1 << 17;
    pub const ContainsObjectOrArrayLiteral: u32 = 1 << 18;
    pub const NonInferrableType: u32 = 1 << 19;
    pub const CouldContainTypeVariablesComputed: u32 = 1 << 20;
    pub const CouldContainTypeVariables: u32 = 1 << 21;

    // Composite
    pub const ClassOrInterface: u32 = Class | Interface;
};

/// TypeData - data payload của từng type variant
pub const TypeData = union(enum) {
    /// Primitive/Intrinsic types (any, number, string, boolean, void, null, undefined, unknown, never)
    Intrinsic: void,

    /// Object type (class, interface, object literal)
    Object: ObjectTypeData,

    /// Function type
    Function: FunctionTypeData,

    /// Array type: T[]
    Array: struct {
        elementType: TypeIndex,
    },

    /// Union type: A | B | C
    Union: struct {
        /// Index into an external types list (stored in Checker.unionTypes)
        typesStart: u32,
        typesLen: u32,
    },

    /// Intersection type: A & B
    Intersection: struct {
        typesStart: u32,
        typesLen: u32,
    },

    /// String literal type: "hello"
    StringLiteral: struct {
        text: []const u8,
    },

    /// Number literal type: 42
    NumberLiteral: struct {
        value: f64,
    },

    /// Boolean literal type: true | false
    BooleanLiteral: struct {
        value: bool,
    },

    /// BigInt literal: 100n
    BigIntLiteral: struct {
        text: []const u8,
    },
};

pub const ObjectTypeData = struct {
    symbol: ?ast_gen.SymbolIndex = null,
    /// Index vào bảng properties (future use)
    propertiesStart: u32 = 0,
    propertiesLen: u32 = 0,
};

pub const FunctionTypeData = struct {
    /// NodeIndex của FunctionDeclaration/ArrowFunction/MethodDeclaration
    declarationNode: ast_gen.NodeIndex = 0,
    /// TypeIndex of return type
    returnType: TypeIndex = 0,
    /// Parameters count (future: store as TypeIndex list)
    parameterCount: u32 = 0,
};

pub const Type = struct {
    Flags: u32,
    ObjectFlags: u32,
    Symbol: ?ast_gen.SymbolIndex,
    Data: TypeData,
};

/// Kiểm tra xem typeA có thể assign vào typeB không (basic implementation)
/// Tuân theo TypeScript structural typing rules
pub fn isAssignableTo(typeA: *const Type, typeB: *const Type) bool {
    // any là assignable đến bất cứ đâu và nhận được bất cứ gì
    if (typeA.Flags & TypeFlags.Any != 0 or typeB.Flags & TypeFlags.Any != 0) return true;

    // never không thể assign vào bất cứ đâu (ngoài never)
    if (typeA.Flags & TypeFlags.Never != 0) {
        return typeB.Flags & TypeFlags.Never != 0;
    }

    // Exact same flags = assignable
    if (typeA.Flags == typeB.Flags) return true;

    // Number literal assignable to number
    if (typeA.Flags & TypeFlags.NumberLiteral != 0 and typeB.Flags & TypeFlags.Number != 0) return true;

    // String literal assignable to string
    if (typeA.Flags & TypeFlags.StringLiteral != 0 and typeB.Flags & TypeFlags.String != 0) return true;

    // Boolean literal assignable to boolean
    if (typeA.Flags & TypeFlags.BooleanLiteral != 0 and typeB.Flags & TypeFlags.Boolean != 0) return true;

    // Enum literal assignable to enum
    if (typeA.Flags & TypeFlags.EnumLiteral != 0 and typeB.Flags & TypeFlags.Enum != 0) return true;

    // Union: A | B assignable to C nếu A assignable to C AND B assignable to C
    // (simplified - không check recursively)
    if (typeB.Flags & TypeFlags.Union != 0) {
        // If typeA matches any member of union - but we don't have member info yet
        // Conservative: return true for now
        return true;
    }

    // undefined | null assignable to respective targets
    if (typeA.Flags & TypeFlags.Undefined != 0 and typeB.Flags & TypeFlags.Undefined != 0) return true;
    if (typeA.Flags & TypeFlags.Null != 0 and typeB.Flags & TypeFlags.Null != 0) return true;

    return false;
}

/// Lấy tên human-readable của type (cho diagnostics)
pub fn typeToString(t: *const Type, buf: []u8) []u8 {
    const s: []const u8 = if (t.Flags & TypeFlags.Any != 0)
        "any"
    else if (t.Flags & TypeFlags.Unknown != 0)
        "unknown"
    else if (t.Flags & TypeFlags.Number != 0)
        "number"
    else if (t.Flags & TypeFlags.String != 0)
        "string"
    else if (t.Flags & TypeFlags.Boolean != 0)
        "boolean"
    else if (t.Flags & TypeFlags.Void != 0)
        "void"
    else if (t.Flags & TypeFlags.Undefined != 0)
        "undefined"
    else if (t.Flags & TypeFlags.Null != 0)
        "null"
    else if (t.Flags & TypeFlags.Never != 0)
        "never"
    else if (t.Flags & TypeFlags.BigInt != 0)
        "bigint"
    else if (t.Flags & TypeFlags.StringLiteral != 0)
        t.Data.StringLiteral.text
    else if (t.Flags & TypeFlags.NumberLiteral != 0) blk: {
        const result = std.fmt.bufPrint(buf, "{d}", .{t.Data.NumberLiteral.value}) catch "number";
        break :blk result;
    } else if (t.Flags & TypeFlags.Object != 0)
        "object"
    else if (t.Flags & TypeFlags.Union != 0)
        "union"
    else
        "unknown";

    if (s.ptr != buf.ptr) {
        const copy_len = @min(s.len, buf.len);
        @memcpy(buf[0..copy_len], s[0..copy_len]);
        return buf[0..copy_len];
    }
    return s;
}
