const std = @import("std");
const ast = @import("../ast/ast.zig");

pub const PseudoTypeKind = enum(u16) {
    Direct,
    Inferred,
    NoResult,
    MaybeConstLocation,
    Union,
    Undefined,
    Null,
    Any,
    String,
    Number,
    BigInt,
    Boolean,
    False,
    True,
    SingleCallSignature,
    Tuple,
    ObjectLiteral,
    StringLiteral,
    NumericLiteral,
    BigIntLiteral,
};

pub const PseudoTypeIndex = u32;

pub const PseudoParameter = struct {
    rest: bool,
    name: ast.NodeIndex,
    optional: bool,
    type: PseudoTypeIndex,
};

pub const PseudoObjectElementKind = enum(u8) {
    Method,
    PropertyAssignment,
    SetAccessor,
    GetAccessor,
};

pub const PseudoObjectElement = union(PseudoObjectElementKind) {
    Method: struct {
        name: ast.NodeIndex,
        optional: bool,
        signature: ast.NodeIndex,
        typeParameters: []ast.NodeIndex,
        parameters: []PseudoParameter,
        returnType: PseudoTypeIndex,
    },
    PropertyAssignment: struct {
        name: ast.NodeIndex,
        optional: bool,
        readonly: bool,
        type: PseudoTypeIndex,
    },
    SetAccessor: struct {
        name: ast.NodeIndex,
        optional: bool,
        signature: ast.NodeIndex,
        parameter: PseudoParameter,
    },
    GetAccessor: struct {
        name: ast.NodeIndex,
        optional: bool,
        signature: ast.NodeIndex,
        type: PseudoTypeIndex,
    },
};

pub const PseudoType = union(PseudoTypeKind) {
    Direct: struct { typeNode: ast.NodeIndex },
    Inferred: struct { expression: ast.NodeIndex, errorNodes: []ast.NodeIndex },
    NoResult: struct { declaration: ast.NodeIndex },
    MaybeConstLocation: struct { node: ast.NodeIndex, constType: PseudoTypeIndex, regularType: PseudoTypeIndex },
    Union: struct { types: []PseudoTypeIndex },
    Undefined: void,
    Null: void,
    Any: void,
    String: void,
    Number: void,
    BigInt: void,
    Boolean: void,
    False: void,
    True: void,
    SingleCallSignature: struct {
        signature: ast.NodeIndex,
        parameters: []PseudoParameter,
        typeParameters: []ast.NodeIndex,
        returnType: PseudoTypeIndex,
    },
    Tuple: struct { elements: []PseudoTypeIndex },
    ObjectLiteral: struct { elements: []PseudoObjectElement },
    StringLiteral: struct { node: ast.NodeIndex },
    NumericLiteral: struct { node: ast.NodeIndex },
    BigIntLiteral: struct { node: ast.NodeIndex },
};
