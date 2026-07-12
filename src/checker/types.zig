const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");

pub const TypeSystemPropertyName = enum {
    ResolvedBaseConstraint,
    Type,
    DeclaredType,
    ResolvedTypeArguments,
    ResolvedType,
    WriteType,
    InitializerIsUndefined,
    AliasTarget,
    // Add others as needed
};

pub const TypeSystemEntityKind = enum(u2) {
    Type = 0,
    Symbol = 1,
    Node = 2,
};

pub const TypeSystemEntity = struct {
    kind: TypeSystemEntityKind,
    index: u32,

    pub fn initType(idx: u32) TypeSystemEntity {
        return .{ .kind = .Type, .index = idx };
    }
    pub fn initSymbol(idx: u32) TypeSystemEntity {
        return .{ .kind = .Symbol, .index = idx };
    }
    pub fn initNode(idx: u32) TypeSystemEntity {
        return .{ .kind = .Node, .index = idx };
    }

    pub fn eql(self: TypeSystemEntity, other: TypeSystemEntity) bool {
        return self.kind == other.kind and self.index == other.index;
    }
};

pub const TypeResolution = struct {
    target: TypeSystemEntity,
    propertyName: TypeSystemPropertyName,
    result: bool,
};
const ast = @import("../ast/ast.zig");
const checker_mod = @import("checker.zig");

pub const TypeIndex = u32;

pub const Ternary = enum(i8) {
    False = 0,
    True = 1,
    Maybe = 2,
};

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
    pub const Intrinsic: u32 = Any | Unknown | String | Number | Boolean | BigInt | ESSymbol | Void | Undefined | Null | Never | NonPrimitive;
    pub const NumberLike: u32 = Number | NumberLiteral | Enum;
    pub const StringLike: u32 = String | StringLiteral | TemplateLiteral | StringMapping;
    pub const BooleanLike: u32 = Boolean | BooleanLiteral;
    pub const BigIntLike: u32 = BigInt | BigIntLiteral;
    pub const ESSymbolLike: u32 = ESSymbol | UniqueESSymbol;
    pub const EnumLike: u32 = Enum | EnumLiteral;
    pub const Singleton: u32 = Any | Unknown | String | Number | Boolean | BigInt | ESSymbol | Void | Undefined | Null | Never | NonPrimitive;
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
    pub const DefinitelyNonNullable: u32 = StringLike | NumberLike | BigIntLike | BooleanLike | EnumLike | ESSymbolLike | Object | NonPrimitive;
    pub const Freshable: u32 = Enum | Literal;
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
    pub const ContainsSpread: u32 = 1 << 22;
    pub const ObjectRestType: u32 = 1 << 23;
    pub const InstantiationExpressionType: u32 = 1 << 24;
    pub const SingleSignatureType: u32 = 1 << 25;
    pub const IsClassInstanceClone: u32 = 1 << 26;

    pub const IdenticalBaseTypeCalculated: u32 = 1 << 27;
    pub const IdenticalBaseTypeExists: u32 = 1 << 28;

    pub const PropagatingFlags = ContainsWideningType | ContainsObjectOrArrayLiteral | NonInferrableType;
    pub const UnresolvedMembers: u32 = 1 << 29;
    pub const FromTypeNode: u32 = 1 << 30;

    pub const IsGenericTypeComputed: u32 = 1 << 22;
    pub const IsGenericObjectType: u32 = 1 << 23;
    pub const IsGenericIndexType: u32 = 1 << 24;
    pub const IsGenericType: u32 = IsGenericObjectType | IsGenericIndexType;

    // Union/Intersection flags
    pub const ContainsIntersections: u32 = 1 << 25;
    pub const IsUnknownLikeUnionComputed: u32 = 1 << 26;
    pub const IsUnknownLikeUnion: u32 = 1 << 27;

    pub const IsNeverIntersectionComputed: u32 = 1 << 25;
    pub const IsNeverIntersection: u32 = 1 << 26;

    // Composite
    pub const ClassOrInterface: u32 = Class | Interface;
};

/// TypeData - data payload của từng type variant
pub const TypeData = union(enum) {
    /// Primitive/Intrinsic types (any, number, string, boolean, void, null, undefined, unknown, never)
    Intrinsic: struct {
        intrinsicName: []const u8 = "",
    },

    /// Object type (class, interface, object literal)
    Object: ObjectTypeData,

    ReverseMapped: struct {
        source: TypeIndex,
        mappedType: TypeIndex,
        constraintType: TypeIndex,
    },

    /// Function type
    Function: FunctionTypeData,

    /// Array type: T[]
    Array: struct {
        elementType: TypeIndex,
    },

    /// Tuple type: [A, B, ...]
    Tuple: TupleType,

    /// Union type: A | B | C
    Union: struct {
        /// Index into an external types list (stored in Checker.unionTypes)
        typesStart: u32,
        typesLen: u32,
        origin: ?TypeIndex = null,
    },

    /// Intersection type: A & B
    Intersection: struct {
        typesStart: u32,
        typesLen: u32,
        origin: ?TypeIndex = null,
    },

    /// Conditional type: T extends U ? X : Y
    Conditional: struct {
        root: *ConditionalRoot,
        checkType: TypeIndex,
        extendsType: TypeIndex,
        resolvedTrueType: ?TypeIndex = null,
        resolvedFalseType: ?TypeIndex = null,
        resolvedDefaultConstraint: ?TypeIndex = null,
        resolvedConstraintOfDistributive: ?TypeIndex = null,
        constraint: TypeIndex = 0,
        mapper: u32 = 0,
        combinedMapper: u32 = 0,
    },

    TypeParameter: struct {
        isTypeParameterConstraintResolved: bool = false,
        resolvedBaseConstraint: ?TypeIndex = null,
        constraintType: TypeIndex = 0, // 0 = undefined, to save optional overhead or we can use ?TypeIndex
        target: ?TypeIndex = null,
        mapper: u32 = 0, // TypeMapperIndex
        isThisType: bool = false,
        resolvedDefaultType: ?TypeIndex = null,
    },

    Substitution: struct {
        baseType: TypeIndex,
        constraint: TypeIndex,
    },

    TemplateLiteral: struct {
        texts: [][]const u8,
        typesStart: u32,
        typesLen: u32,
    },

    StringMapping: struct {
        target: TypeIndex,
    },

    Index: struct {
        target: TypeIndex,
    },

    IndexedAccess: struct {
        objectType: TypeIndex,
        indexType: TypeIndex,
        accessFlags: u32,
        constraint: TypeIndex = 0,
    },

    Mapped: struct {
        declaration: ast_gen.NodeIndex,
        typeParameter: TypeIndex,
        constraintType: ?TypeIndex = null,
        nameType: ?TypeIndex = null,
        templateType: TypeIndex,
        modifiersType: ?TypeIndex = null,
        mapper: u32 = 0,
        target: ?TypeIndex = null,
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

pub const EvolutionTypeKey = struct {
    t: TypeIndex,
    symbol: ast_gen.SymbolIndex,
    flow: ast_gen.NodeIndex, // Wait, flow is FlowNodeIndex or NodeIndex? The Go code uses Node, we'll use FlowNodeIndex
};

pub const MarkedAssignmentSymbolLinks = struct {
    lastAssignmentPos: i32 = 0,
    hasDefiniteAssignment: bool = false,
};

pub const NodeCheckFlags = struct {
    pub const None: u32 = 0;
    pub const TypeChecked: u32 = 1 << 0;
    pub const ContextChecked: u32 = 1 << 6;
    pub const EnumValuesComputed: u32 = 1 << 10;
    pub const AssignmentsMarked: u32 = 1 << 17;
    pub const ContainsClassWithPrivateIdentifiers: u32 = 1 << 20;
    pub const ContainsSuperPropertyInStaticInitializer: u32 = 1 << 21;
    pub const InCheckIdentifier: u32 = 1 << 22;
    pub const InitializerIsUndefined: u32 = 1 << 24;
    pub const InitializerIsUndefinedComputed: u32 = 1 << 25;
};

pub const SourceFileLinks = struct {
    typeChecked: bool = false,
    unusedChecked: bool = false,
};
pub const NodeLinks = struct {
    flags: u32 = 0,
    // declarationRequiresScopeChange
    // hasReportedStatementInAmbientContext
};

pub const TypeAlias = struct {
    symbol: ast_gen.SymbolIndex,
    typeArgumentsStart: u32,
    typeArgumentsLen: u32,
};

pub const TupleElementInfo = struct {
    flags: u32, // ElementFlags
    labeledDeclaration: ?ast_gen.NodeIndex = null,
};

pub const TupleType = struct {
    typesStart: u32,
    typesLen: u32,
    elementInfosStart: u32 = 0,
    readonly: bool = false,
    combinedFlags: u32 = 0,
    minLength: u32 = 0,
    fixedLength: u32 = 0,
    hasRestElement: bool = false,
    instantiations: ?std.AutoHashMapUnmanaged(CacheHashKey, TypeIndex) = null,
    target: ?TypeIndex = null,
    thisType: ?TypeIndex = null,
    typeParametersStart: u32 = 0,
    typeParametersLen: u32 = 0,
};

pub const ConditionalRoot = struct {
    node: ast_gen.NodeIndex, // ConditionalTypeNode
    checkType: TypeIndex,
    extendsType: TypeIndex,
    isDistributive: bool,
    inferTypeParametersStart: u32 = 0,
    inferTypeParametersLen: u32 = 0,
    outerTypeParametersStart: u32 = 0,
    outerTypeParametersLen: u32 = 0,
    alias: ?TypeAlias = null,
    instantiations: ?std.AutoHashMapUnmanaged(CacheHashKey, TypeIndex) = null,
};

/// MappedTypeModifiers - bitmask 1:1 với Go MappedTypeModifiers
pub const MappedTypeModifiers = struct {
    value: u32 = 0,

    pub const IncludeReadonly: u32 = 1 << 0;
    pub const ExcludeReadonly: u32 = 1 << 1;
    pub const IncludeOptional: u32 = 1 << 2;
    pub const ExcludeOptional: u32 = 1 << 3;

    pub fn has(self: MappedTypeModifiers, flag: u32) bool {
        return self.value & flag != 0;
    }
};

pub const ElementFlags = struct {
    pub const None: u32 = 0;
    pub const Required: u32 = 1 << 0;
    pub const Optional: u32 = 1 << 1;
    pub const Rest: u32 = 1 << 2;
    pub const Variadic: u32 = 1 << 3;

    pub const Fixed: u32 = Required | Optional;
    pub const Variable: u32 = Rest | Variadic;
    pub const NonRequired: u32 = Optional | Rest | Variadic;
    pub const NonRest: u32 = Required | Optional | Variadic;
};

pub const IndexInfo = struct {
    keyType: TypeIndex,
    valueType: TypeIndex,
    isReadonly: bool,
    declaration: ?ast_gen.NodeIndex = null,
};

pub const SignatureKind = enum {
    Call,
    Construct,
};

pub const SignatureFlags = struct {
    pub const None: u32 = 0;
    pub const HasRestParameter: u32 = 1 << 0;
    pub const HasLiteralTypes: u32 = 1 << 1;
    pub const Construct: u32 = 1 << 2;
    pub const Abstract: u32 = 1 << 3;
    pub const IsInnerCallChain: u32 = 1 << 4;
    pub const IsOuterCallChain: u32 = 1 << 5;
    pub const IsUntypedSignatureInJSFile: u32 = 1 << 6;
    pub const IsNonInferrable: u32 = 1 << 7;
    pub const IsSignatureCandidateForOverloadFailure: u32 = 1 << 8;

    pub const PropagatingFlags = HasRestParameter | HasLiteralTypes | Construct | Abstract | IsUntypedSignatureInJSFile | IsSignatureCandidateForOverloadFailure;
    pub const CallChainFlags = IsInnerCallChain | IsOuterCallChain;
};

pub const SymbolNodeLinks = struct {
    resolvedSymbol: ast_gen.SymbolIndex = 0,
    exportSymbol: ast_gen.SymbolIndex = 0,
};

pub const AssignmentReducedKey = struct {
    id1: TypeIndex,
    id2: TypeIndex,
};

pub const TypeNodeLinks = struct {
    resolvedType: TypeIndex = 0,
    outerTypeParameters: ?[]const TypeIndex = null,
    restrictiveTypeParameter: ?TypeIndex = null,
};

pub const Signature = struct {
    flags: u32 = 0,
    minArgumentCount: i32 = 0,
    resolvedMinArgumentCount: i32 = -1,
    declaration: ast_gen.NodeIndex = 0,
    typeParametersStart: u32 = 0,
    typeParametersLen: u32 = 0,
    parametersStart: u32 = 0,
    parametersLen: u32 = 0,
    thisParameter: ?ast_gen.SymbolIndex = null,
    resolvedReturnType: ?TypeIndex = null,
    target: ?SignatureIndex = null,
    isolatedSignatureType: ?TypeIndex = null,
};

pub const StructuredTypeMembers = struct {
    propertiesStart: u32 = 0,
    propertiesLen: u32 = 0,
    callSignaturesStart: u32 = 0,
    callSignaturesLen: u32 = 0,
    constructSignaturesStart: u32 = 0,
    constructSignaturesLen: u32 = 0,
    indexInfosStart: u32 = 0,
    indexInfosLen: u32 = 0,
};

pub const Range = struct {
    start: u32 = 0,
    len: u32 = 0,
};

pub const ObjectTypeData = struct {
    Symbol: ?ast_gen.SymbolIndex = null,
    node: ?ast_gen.NodeIndex = null,
    target: ?TypeIndex = null,
    mapper: ?TypeMapperIndex = null,
    typeArgumentsStart: u32 = 0,
    typeArgumentsLen: u32 = 0,
    evolvingArrayElementType: ?TypeIndex = null,
    finalArrayType: ?TypeIndex = null,
    instantiations: ?std.AutoHashMapUnmanaged(CacheHashKey, TypeIndex) = null,
    thisType: ?TypeIndex = null,
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
    flags: u32,
    objectFlags: u32,
    id: u32 = 0,
    symbol: ?ast_gen.SymbolIndex = null,
    alias: ?TypeAlias = null,
    data: TypeData,
};

/// Kiểm tra xem typeA có thể assign vào typeB không (basic implementation)
/// Tuân theo TypeScript structural typing rules
pub fn isAssignableTo(typeA: *const Type, typeB: *const Type) bool {
    // any là assignable đến bất cứ đâu và nhận được bất cứ gì
    if (typeA.flags & TypeFlags.Any != 0 or typeB.flags & TypeFlags.Any != 0) return true;

    // never không thể assign vào bất cứ đâu (ngoài never)
    if (typeA.flags & TypeFlags.Never != 0) {
        return typeB.flags & TypeFlags.Never != 0;
    }

    // Exact same flags = assignable (except for structural types)
    if (typeA.flags == typeB.flags) {
        if (typeA.flags & TypeFlags.Object != 0 or typeA.flags & TypeFlags.Union != 0) {
            // Need structural comparison handled by checker
        } else {
            return true;
        }
    }

    // Number literal assignable to number
    if (typeA.flags & TypeFlags.NumberLiteral != 0 and typeB.flags & TypeFlags.Number != 0) return true;

    // String literal assignable to string
    if (typeA.flags & TypeFlags.StringLiteral != 0 and typeB.flags & TypeFlags.String != 0) return true;

    // Boolean literal assignable to boolean
    if (typeA.flags & TypeFlags.BooleanLiteral != 0 and typeB.flags & TypeFlags.Boolean != 0) return true;

    // Enum literal assignable to enum
    if (typeA.flags & TypeFlags.EnumLiteral != 0 and typeB.flags & TypeFlags.Enum != 0) return true;

    // Union: A | B assignable to C nếu A assignable to C AND B assignable to C
    // (simplified - không check recursively)
    if (typeB.flags & TypeFlags.Union != 0) {
        // If typeA matches any member of union - but we don't have member info yet
        // Conservative: return true for now
        return true;
    }

    // undefined | null assignable to respective targets
    if (typeA.flags & TypeFlags.Undefined != 0 and typeB.flags & TypeFlags.Undefined != 0) return true;
    if (typeA.flags & TypeFlags.Null != 0 and typeB.flags & TypeFlags.Null != 0) return true;

    return false;
}

/// Lấy tên human-readable của type (cho diagnostics)
pub fn typeToString(t: *const Type, buf: []u8) []u8 {
    const s: []const u8 = if (t.flags & TypeFlags.Any != 0)
        "any"
    else if (t.flags & TypeFlags.Unknown != 0)
        "unknown"
    else if (t.flags & TypeFlags.Number != 0)
        "number"
    else if (t.flags & TypeFlags.String != 0)
        "string"
    else if (t.flags & TypeFlags.Boolean != 0)
        "boolean"
    else if (t.flags & TypeFlags.Void != 0)
        "void"
    else if (t.flags & TypeFlags.Undefined != 0)
        "undefined"
    else if (t.flags & TypeFlags.Null != 0)
        "null"
    else if (t.flags & TypeFlags.Never != 0)
        "never"
    else if (t.flags & TypeFlags.BigInt != 0)
        "bigint"
    else if (t.flags & TypeFlags.StringLiteral != 0)
        t.data.StringLiteral.text
    else if (t.flags & TypeFlags.NumberLiteral != 0) blk: {
        const result = std.fmt.bufPrint(buf, "{d}", .{t.data.NumberLiteral.value}) catch "number";
        break :blk result;
    } else if (t.flags & TypeFlags.Object != 0)
        "object"
    else if (t.flags & TypeFlags.Union != 0)
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

pub const CompareTypesKind = enum {
    Assignable,
    AssignableSimple,
    Identical,
    SubtypeOf,
    RelatedToWorker,
};

pub const InferenceFlags = packed struct(u32) {
    NoDefault: bool = false,
    AnyDefault: bool = false,
    SkippedGenericFunction: bool = false,
    _pad: u29 = 0,

    pub const None = InferenceFlags{};
};

pub const InferenceContext = struct {
    inferences: std.ArrayListUnmanaged(u32) = .empty,
    intraExpressionInferenceSites: std.ArrayListUnmanaged(u32) = .empty,
    signature: ?u32 = null,
    flags: InferenceFlags = InferenceFlags.None,
    compareTypes: CompareTypesKind = .Assignable,
    mapper: u32 = 0,
    nonFixingMapper: u32 = 0,
};
pub const InferenceContextInfo = struct {};
pub const InferenceInfo = struct {
    typeParameter: TypeIndex = 0,
    candidates: std.ArrayListUnmanaged(TypeIndex) = .empty,
    contraCandidates: std.ArrayListUnmanaged(TypeIndex) = .empty,
    inferredType: TypeIndex = 0,
    priority: i32 = 0,
    isFixed: bool = false,
};
pub const InferenceInfoIndex = u32;

pub const CacheHashKey = u64;

pub const EnumMemberLink = struct {
    value: @import("../ast/ast_generated.zig").NodeIndex = 0,
};

pub const ContainingSymbolLinks = struct {
    extendedContainersByFile: ?std.AutoHashMapUnmanaged(@import("../ast/ast_generated.zig").NodeIndex, []const @import("../ast/ast_generated.zig").SymbolIndex) = null,
    extendedContainers: ?[]const @import("../ast/ast_generated.zig").SymbolIndex = null,
    accessibleChainCache: ?std.AutoArrayHashMapUnmanaged(CacheHashKey, []const @import("../ast/ast_generated.zig").SymbolIndex) = null,
};

pub const TypeFacts = struct {
    pub const None: u32 = 0;
    pub const TypeofEQString: u32 = 1 << 0;
    pub const TypeofEQNumber: u32 = 1 << 1;
    pub const TypeofEQBigInt: u32 = 1 << 2;
    pub const TypeofEQBoolean: u32 = 1 << 3;
    pub const TypeofEQSymbol: u32 = 1 << 4;
    pub const TypeofEQObject: u32 = 1 << 5;
    pub const TypeofEQFunction: u32 = 1 << 6;
    pub const TypeofEQHostObject: u32 = 1 << 7;
    pub const TypeofNEString: u32 = 1 << 8;
    pub const TypeofNENumber: u32 = 1 << 9;
    pub const TypeofNEBigInt: u32 = 1 << 10;
    pub const TypeofNEBoolean: u32 = 1 << 11;
    pub const TypeofNESymbol: u32 = 1 << 12;
    pub const TypeofNEObject: u32 = 1 << 13;
    pub const TypeofNEFunction: u32 = 1 << 14;
    pub const TypeofNEHostObject: u32 = 1 << 15;
    pub const EQUndefined: u32 = 1 << 16;
    pub const EQNull: u32 = 1 << 17;
    pub const EQUndefinedOrNull: u32 = 1 << 18;
    pub const NEUndefined: u32 = 1 << 19;
    pub const NENull: u32 = 1 << 20;
    pub const NEUndefinedOrNull: u32 = 1 << 21;
    pub const Truthy: u32 = 1 << 22;
    pub const Falsy: u32 = 1 << 23;
    pub const IsUndefined: u32 = 1 << 24;
    pub const IsNull: u32 = 1 << 25;
    pub const IsUndefinedOrNull: u32 = IsUndefined | IsNull;
    pub const All: u32 = (1 << 27) - 1;
    // The following members encode facts about particular kinds of types for use in the getTypeFacts function.
    // The presence of a particular fact means that the given test is true for some (and possibly all) values
    // of that kind of type.
    pub const BaseStringStrictFacts: u32 = TypeofEQString | TypeofNENumber | TypeofNEBigInt | TypeofNEBoolean | TypeofNESymbol | TypeofNEObject | TypeofNEFunction | TypeofNEHostObject | NEUndefined | NENull | NEUndefinedOrNull;
    pub const BaseStringFacts: u32 = BaseStringStrictFacts | EQUndefined | EQNull | EQUndefinedOrNull | Falsy;
    pub const StringStrictFacts: u32 = BaseStringStrictFacts | Truthy | Falsy;
    pub const StringFacts: u32 = BaseStringFacts | Truthy;
    pub const EmptyStringStrictFacts: u32 = BaseStringStrictFacts | Falsy;
    pub const EmptyStringFacts: u32 = BaseStringFacts;
    pub const NonEmptyStringStrictFacts: u32 = BaseStringStrictFacts | Truthy;
    pub const NonEmptyStringFacts: u32 = BaseStringFacts | Truthy;
    pub const BaseNumberStrictFacts: u32 = TypeofEQNumber | TypeofNEString | TypeofNEBigInt | TypeofNEBoolean | TypeofNESymbol | TypeofNEObject | TypeofNEFunction | TypeofNEHostObject | NEUndefined | NENull | NEUndefinedOrNull;
    pub const BaseNumberFacts: u32 = BaseNumberStrictFacts | EQUndefined | EQNull | EQUndefinedOrNull | Falsy;
    pub const NumberStrictFacts: u32 = BaseNumberStrictFacts | Truthy | Falsy;
    pub const NumberFacts: u32 = BaseNumberFacts | Truthy;
    pub const ZeroNumberStrictFacts: u32 = BaseNumberStrictFacts | Falsy;
    pub const ZeroNumberFacts: u32 = BaseNumberFacts;
    pub const NonZeroNumberStrictFacts: u32 = BaseNumberStrictFacts | Truthy;
    pub const NonZeroNumberFacts: u32 = BaseNumberFacts | Truthy;
    pub const BaseBigIntStrictFacts: u32 = TypeofEQBigInt | TypeofNEString | TypeofNENumber | TypeofNEBoolean | TypeofNESymbol | TypeofNEObject | TypeofNEFunction | TypeofNEHostObject | NEUndefined | NENull | NEUndefinedOrNull;
    pub const BaseBigIntFacts: u32 = BaseBigIntStrictFacts | EQUndefined | EQNull | EQUndefinedOrNull | Falsy;
    pub const BigIntStrictFacts: u32 = BaseBigIntStrictFacts | Truthy | Falsy;
    pub const BigIntFacts: u32 = BaseBigIntFacts | Truthy;
    pub const ZeroBigIntStrictFacts: u32 = BaseBigIntStrictFacts | Falsy;
    pub const ZeroBigIntFacts: u32 = BaseBigIntFacts;
    pub const NonZeroBigIntStrictFacts: u32 = BaseBigIntStrictFacts | Truthy;
    pub const NonZeroBigIntFacts: u32 = BaseBigIntFacts | Truthy;
    pub const BaseBooleanStrictFacts: u32 = TypeofEQBoolean | TypeofNEString | TypeofNENumber | TypeofNEBigInt | TypeofNESymbol | TypeofNEObject | TypeofNEFunction | TypeofNEHostObject | NEUndefined | NENull | NEUndefinedOrNull;
    pub const BaseBooleanFacts: u32 = BaseBooleanStrictFacts | EQUndefined | EQNull | EQUndefinedOrNull | Falsy;
    pub const BooleanStrictFacts: u32 = BaseBooleanStrictFacts | Truthy | Falsy;
    pub const BooleanFacts: u32 = BaseBooleanFacts | Truthy;
    pub const FalseStrictFacts: u32 = BaseBooleanStrictFacts | Falsy;
    pub const FalseFacts: u32 = BaseBooleanFacts;
    pub const TrueStrictFacts: u32 = BaseBooleanStrictFacts | Truthy;
    pub const TrueFacts: u32 = BaseBooleanFacts | Truthy;
    pub const SymbolStrictFacts: u32 = TypeofEQSymbol | TypeofNEString | TypeofNENumber | TypeofNEBigInt | TypeofNEBoolean | TypeofNEObject | TypeofNEFunction | TypeofNEHostObject | NEUndefined | NENull | NEUndefinedOrNull | Truthy;
    pub const SymbolFacts: u32 = SymbolStrictFacts | EQUndefined | EQNull | EQUndefinedOrNull | Falsy;
    pub const ObjectStrictFacts: u32 = TypeofEQObject | TypeofEQHostObject | TypeofNEString | TypeofNENumber | TypeofNEBigInt | TypeofNEBoolean | TypeofNESymbol | TypeofNEFunction | NEUndefined | NENull | NEUndefinedOrNull | Truthy;
    pub const ObjectFacts: u32 = ObjectStrictFacts | EQUndefined | EQNull | EQUndefinedOrNull | Falsy;
    pub const FunctionStrictFacts: u32 = TypeofEQFunction | TypeofEQHostObject | TypeofNEString | TypeofNENumber | TypeofNEBigInt | TypeofNEBoolean | TypeofNESymbol | TypeofNEObject | NEUndefined | NENull | NEUndefinedOrNull | Truthy;
    pub const FunctionFacts: u32 = FunctionStrictFacts | EQUndefined | EQNull | EQUndefinedOrNull | Falsy;
    pub const VoidFacts: u32 = TypeofNEString | TypeofNENumber | TypeofNEBigInt | TypeofNEBoolean | TypeofNESymbol | TypeofNEObject | TypeofNEFunction | TypeofNEHostObject | EQUndefined | EQUndefinedOrNull | NENull | Falsy;
    pub const UndefinedFacts: u32 = TypeofNEString | TypeofNENumber | TypeofNEBigInt | TypeofNEBoolean | TypeofNESymbol | TypeofNEObject | TypeofNEFunction | TypeofNEHostObject | EQUndefined | EQUndefinedOrNull | NENull | Falsy | IsUndefined;
    pub const NullFacts: u32 = TypeofEQObject | TypeofNEString | TypeofNENumber | TypeofNEBigInt | TypeofNEBoolean | TypeofNESymbol | TypeofNEFunction | TypeofNEHostObject | EQNull | EQUndefinedOrNull | NEUndefined | Falsy | IsNull;
    pub const EmptyObjectStrictFacts: u32 = All & ~(EQUndefined | EQNull | EQUndefinedOrNull | IsUndefinedOrNull);
    pub const EmptyObjectFacts: u32 = All & ~IsUndefinedOrNull;
    pub const UnknownFacts: u32 = All & ~IsUndefinedOrNull;
    pub const AllTypeofNE: u32 = TypeofNEString | TypeofNENumber | TypeofNEBigInt | TypeofNEBoolean | TypeofNESymbol | TypeofNEObject | TypeofNEFunction | NEUndefined;
    // Masks
    pub const OrFactsMask: u32 = TypeofEQFunction | TypeofNEObject;
    pub const AndFactsMask: u32 = All & ~OrFactsMask;
};

pub const NodeIndexPair = struct {
    node1: @import("../ast/ast_generated.zig").NodeIndex,
    node2: @import("../ast/ast_generated.zig").NodeIndex,
};

pub const InferencePriority = struct {
    pub const None: i32 = 0;
    pub const NakedTypeVariable: i32 = 1 << 0;
    pub const SpeculativeTuple: i32 = 1 << 1;
    pub const SubstituteSource: i32 = 1 << 2;
    pub const HomomorphicMappedType: i32 = 1 << 3;
    pub const PartialHomomorphicMappedType: i32 = 1 << 4;
    pub const MappedTypeConstraint: i32 = 1 << 5;
    pub const ContravariantConditional: i32 = 1 << 6;
    pub const ReturnType: i32 = 1 << 7;
    pub const LiteralKeyof: i32 = 1 << 8;
    pub const NoConstraints: i32 = 1 << 9;
    pub const AlwaysStrict: i32 = 1 << 10;
    pub const MaxValue: i32 = 0x7FFFFFFF;
};

pub const TypePredicateKind = enum(u32) {
    This = 0,
    Identifier = 1,
    AssertsThis = 2,
    AssertsIdentifier = 3,
};

pub const TypePredicate = struct {
    t: ?TypeIndex = null,
    kind: TypePredicateKind = .Identifier,
    parameterIndex: i32 = -1,
};

pub const ExpandingFlags = struct {
    pub const None: u8 = 0;
};

pub const SignatureIndex = u32;
pub const TypeFormatFlags = struct {
    pub const None: u32 = 0;
    pub const NoTruncation: u32 = 1 << 0;
    pub const WriteArrayAsGenericType: u32 = 1 << 1;
    pub const GenerateNamesForShadowedTypeParams: u32 = 1 << 2;
    pub const UseStructuralFallback: u32 = 1 << 3;
    pub const WriteTypeArgumentsOfSignature: u32 = 1 << 5;
    pub const UseFullyQualifiedType: u32 = 1 << 6;
    pub const SuppressAnyReturnType: u32 = 1 << 8;
    pub const MultilineObjectLiterals: u32 = 1 << 10;
    pub const WriteClassExpressionAsTypeLiteral: u32 = 1 << 11;
    pub const UseTypeOfFunction: u32 = 1 << 12;
    pub const OmitParameterModifiers: u32 = 1 << 13;
    pub const UseAliasDefinedOutsideCurrentScope: u32 = 1 << 14;
    pub const UseSingleQuotesForStringLiteralType: u32 = 1 << 28;
    pub const NoTypeReduction: u32 = 1 << 29;
    pub const UseInstantiationExpressions: u32 = 1 << 30;
    pub const OmitThisParameter: u32 = 1 << 25;
    pub const WriteCallStyleSignature: u32 = 1 << 27;
    pub const AllowUniqueESSymbolType: u32 = 1 << 20;
    pub const AddUndefined: u32 = 1 << 17;
    pub const WriteArrowStyleSignature: u32 = 1 << 18;
    pub const InArrayType: u32 = 1 << 19;
    pub const InElementType: u32 = 1 << 21;
    pub const InFirstTypeArgument: u32 = 1 << 22;
    pub const InTypeAlias: u32 = 1 << 23;

    pub const NodeBuilderFlagsMask: u32 = NoTruncation | WriteArrayAsGenericType | GenerateNamesForShadowedTypeParams | UseStructuralFallback | WriteTypeArgumentsOfSignature | UseFullyQualifiedType | SuppressAnyReturnType | MultilineObjectLiterals | WriteClassExpressionAsTypeLiteral | UseTypeOfFunction | OmitParameterModifiers | UseAliasDefinedOutsideCurrentScope | AllowUniqueESSymbolType | InTypeAlias | UseInstantiationExpressions | UseSingleQuotesForStringLiteralType | NoTypeReduction | OmitThisParameter;
};

pub const SymbolFormatFlags = struct {
    pub const None: u32 = 0;
    pub const WriteTypeParametersOrArguments: u32 = 1 << 0;
    pub const UseOnlyExternalAliasing: u32 = 1 << 1;
    pub const AllowAnyNodeKind: u32 = 1 << 2;
    pub const UseAliasDefinedOutsideCurrentScope: u32 = 1 << 3;
    pub const WriteComputedProps: u32 = 1 << 4;
    pub const DoNotIncludeSymbolChain: u32 = 1 << 5;
};

pub const IndexFlags = struct {
    pub const None: u32 = 0;
    pub const StringsOnly: u32 = 1 << 0;
    pub const NoIndexSignatures: u32 = 1 << 1;
    pub const NoReducibleCheck: u32 = 1 << 2;
};

pub const AccessFlags = struct {
    pub const None: u32 = 0;
    pub const IncludeUndefined: u32 = 1 << 0;
    pub const NoIndexSignatures: u32 = 1 << 1;
    pub const Writing: u32 = 1 << 2;
    pub const CacheSymbol: u32 = 1 << 3;
    pub const AllowMissing: u32 = 1 << 4;
    pub const ExpressionPosition: u32 = 1 << 5;
    pub const ReportDeprecated: u32 = 1 << 6;
    pub const SuppressNoImplicitAnyError: u32 = 1 << 7;
    pub const Contextual: u32 = 1 << 8;
    pub const Persistent: u32 = IncludeUndefined;
};

pub const CheckFlags = struct {
    pub const None: u32 = 0;
    pub const SyntheticProperty: u32 = 1 << 1;
    pub const Readonly: u32 = 1 << 3;
    pub const ReadPartial: u32 = 1 << 4;
    pub const WritePartial: u32 = 1 << 5;
    pub const HasNonUniformType: u32 = 1 << 6;
    pub const HasLiteralType: u32 = 1 << 7;
    pub const Late: u32 = 1 << 12;
    pub const IsDiscriminantComputed: u32 = 1 << 21;
    pub const IsDiscriminant: u32 = 1 << 22;
    pub const Unresolved: u32 = 1 << 20;
    pub const NonUniformAndLiteral: u32 = HasNonUniformType | HasLiteralType;
    pub const Partial: u32 = ReadPartial | WritePartial;
};

pub const TypeMapperIndex = u32;

pub const IndexKind = enum(u8) {
    String,
    Number,
};

pub const ContextualInfo = struct {
    node: ast_gen.NodeIndex,
    type_: TypeIndex,
    isCache: bool,
};

pub const IntrinsicTypeKind = enum(u8) {
    Unknown,
    Uppercase,
    Lowercase,
    Capitalize,
    Uncapitalize,
    NoInfer,
};

pub const TypeMapperKind = enum(u8) {
    Simple,
    Array,
    ArrayToSingle,
    Deferred,
    Function,
    Merged,
    Composite,
    Inference,
    Permissive,
    Restrictive,
};

pub const TypeMapper = struct {
    kind: TypeMapperKind,
    mapsThisOnly: bool = false,
    data: union {
        Simple: struct {
            source: TypeIndex,
            target: TypeIndex,
        },
        Array: struct {
            sources: []const TypeIndex,
            targets: []const TypeIndex,
        },
        ArrayToSingle: struct {
            sources: []const TypeIndex,
            target: TypeIndex,
        },
        Merged: struct {
            mapper1: TypeMapperIndex,
            mapper2: TypeMapperIndex,
        },
        Composite: struct {
            m1: TypeMapperIndex,
            m2: TypeMapperIndex,
        },
        Deferred: struct {
            source: TypeIndex,
            target: TypeIndex,
            mapper: TypeMapperIndex,
        },
        Inference: struct {
            n: u32,
            fixing: bool,
        },
        Function: struct {
            func: *const fn (*checker_mod.Checker, TypeIndex) TypeIndex,
        },
        // We will add more as needed
        Dummy: void,
    },
};

pub const AliasSymbolLinks = struct {
    immediateTarget: ?ast_gen.SymbolIndex = null,
    aliasTarget: ?ast_gen.SymbolIndex = null,
    referenced: bool = false,
    typeOnlyDeclaration: ?ast_gen.NodeIndex = null,
};

pub const TypeAliasLinks = struct {
    declaredType: ?TypeIndex = null,
    typeParameters: []const TypeIndex = &[_]TypeIndex{},
    instantiations: ?std.AutoHashMapUnmanaged(CacheHashKey, TypeIndex) = null,
};

pub const SymbolReferenceLinks = struct {
    referenceKinds: u32 = 0,
};

pub const ValueSymbolLinks = struct {
    resolvedType: ?TypeIndex = null,
    writeType: ?TypeIndex = null,
    target: ?ast_gen.SymbolIndex = null,
    mapper: u32 = 0,
    nameType: ?TypeIndex = null,
    containingType: ?TypeIndex = null,
    functionOrConstructorChecked: bool = false,
};

pub const MappedSymbolLinks = struct {
    keyType: ?TypeIndex = null,
    syntheticOrigin: ?ast_gen.SymbolIndex = null,
};

pub const DeferredSymbolLinks = struct {
    parent: ?TypeIndex = null,
    constituentsStart: u32 = 0,
    constituentsLen: u32 = 0,
    writeConstituentsStart: u32 = 0,
    writeConstituentsLen: u32 = 0,
};

pub const ModuleSymbolLinks = struct {
    resolvedExports: u32 = 0, // SymbolTableIndex
    typeOnlyExportStarMap: u32 = 0,
    exportsChecked: bool = false,
};

pub const ReverseMappedSymbolLinks = struct {
    propertyType: ?TypeIndex = null,
    mappedType: ?TypeIndex = null,
    constraintType: ?TypeIndex = null,
};

pub const LateBoundLinks = struct {
    lateSymbol: ?ast_gen.SymbolIndex = null,
};

pub const ExportTypeLinks = struct {
    target: ?ast_gen.SymbolIndex = null,
    originatingImport: ?ast_gen.NodeIndex = null,
};

pub const DeclaredTypeLinks = struct {
    declaredType: ?TypeIndex = null,
    interfaceChecked: bool = false,
    indexSignaturesChecked: bool = false,
    typeParametersChecked: bool = false,
    enumChecked: bool = false,
};

pub const ExhaustiveState = enum(u8) {
    Unknown = 0,
    Computing = 1,
    False = 2,
    True = 3,
};

pub const SwitchStatementLinks = struct {
    exhaustiveState: ExhaustiveState = .Unknown,
    switchTypesComputed: bool = false,
    witnessesComputed: bool = false,
    switchTypesStart: u32 = 0,
    switchTypesLen: u32 = 0,
    witnessesStart: u32 = 0,
    witnessesLen: u32 = 0,
};

pub const ArrayLiteralLinks = struct {
    indicesComputed: bool = false,
    firstSpreadIndex: i32 = -1,
    lastSpreadIndex: i32 = -1,
};

pub const MembersOrExportsResolutionKind = enum(u8) {
    ResolvedExports = 0,
    ResolvedMembers = 1,
};

pub const MembersAndExportsLinks = [2]u32; // SymbolTable indices

pub const SpreadLinks = struct {
    leftSpread: ?ast_gen.SymbolIndex = null,
    rightSpread: ?ast_gen.SymbolIndex = null,
};

pub const VarianceFlags = struct {
    pub const Invariant: u32 = 0;
    pub const Covariant: u32 = 1 << 0;
    pub const Contravariant: u32 = 1 << 1;
    pub const Bivariant: u32 = Covariant | Contravariant;
    pub const Independent: u32 = 1 << 2;
    pub const VarianceMask: u32 = Invariant | Covariant | Contravariant | Independent;
    pub const Unmeasurable: u32 = 1 << 3;
    pub const Unreliable: u32 = 1 << 4;
    pub const AllowsStructuralFallback: u32 = Unmeasurable | Unreliable;
};

pub const VarianceLinks = struct {
    variancesStart: u32 = 0,
    variancesLen: u32 = 0,
};

pub const ParseFlags = struct {
    pub const None: u32 = 0;
    pub const Yield: u32 = 1 << 0;
    pub const Await: u32 = 1 << 1;
    pub const Type: u32 = 1 << 2;
    pub const IgnoreMissingOpenBrace: u32 = 1 << 4;
    pub const JSDoc: u32 = 1 << 5;
};

pub const ContextFlags = struct {
    pub const None: u32 = 0;
    pub const Signature: u32 = 1 << 0;
    pub const NoConstraints: u32 = 1 << 1;
    pub const IgnoreNodeInferences: u32 = 1 << 2;
    pub const SkipBindingPatterns: u32 = 1 << 3;
};

pub const ExternalEmitHelpers = struct {
    pub const Rest: u32 = 1 << 0;
    pub const Decorate: u32 = 1 << 1;
    pub const Metadata: u32 = 1 << 2;
    pub const Param: u32 = 1 << 3;
    pub const Awaiter: u32 = 1 << 4;
    pub const Await: u32 = 1 << 5;
    pub const AsyncGenerator: u32 = 1 << 6;
    pub const AsyncDelegator: u32 = 1 << 7;
    pub const AsyncValues: u32 = 1 << 8;
    pub const ExportStar: u32 = 1 << 9;
    pub const ImportStar: u32 = 1 << 10;
    pub const ImportDefault: u32 = 1 << 11;
    pub const MakeTemplateObject: u32 = 1 << 12;
    pub const ClassPrivateFieldGet: u32 = 1 << 13;
    pub const ClassPrivateFieldSet: u32 = 1 << 14;
    pub const ClassPrivateFieldIn: u32 = 1 << 15;
    pub const SetFunctionName: u32 = 1 << 16;
    pub const PropKey: u32 = 1 << 17;
    pub const AddDisposableResourceAndDisposeResources: u32 = 1 << 18;
    pub const RewriteRelativeImportExtension: u32 = 1 << 19;
    pub const ESDecorateAndRunInitializers: u32 = Decorate;

    pub const FirstEmitHelper = Rest;
    pub const LastEmitHelper = RewriteRelativeImportExtension;

    pub const ForAwaitOfIncludes = AsyncValues;
    pub const AsyncGeneratorIncludes = Await | AsyncGenerator;
    pub const AsyncDelegatorIncludes = Await | AsyncDelegator | AsyncValues;
};

pub fn formatTypeFlags(flags_: *anyopaque) *anyopaque {
    _ = flags_;
    return undefined;
}

pub fn string() *anyopaque {
    return undefined;
}

pub fn symbol() *anyopaque {
    return undefined;
}

pub fn typeArguments() *anyopaque {
    return undefined;
}

pub fn id(c: *const @import("checker.zig").Checker, t: TypeIndex) u32 {
    return c.typesList.items[t].id;
}

pub fn flags(c: *const @import("checker.zig").Checker, t: TypeIndex) u32 {
    return c.typesList.items[t].flags;
}

pub fn objectFlags(c: *const @import("checker.zig").Checker, t: TypeIndex) u32 {
    return c.typesList.items[t].objectFlags;
}

pub fn asIntrinsicType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asLiteralType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asUniqueESSymbolType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asTupleType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asInstantiationExpressionType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asMappedType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asReverseMappedType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asEvolvingArrayType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asTypeParameter(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asUnionType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asIntersectionType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asIndexType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asIndexedAccessType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asTemplateLiteralType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asStringMappingType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asSubstitutionType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asConditionalType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asConstrainedType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asStructuredType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asObjectType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asTypeReference(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asInterfaceType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn asUnionOrIntersectionType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn distributed(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn target(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn mapper(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn types(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn targetInterfaceType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn targetTupleType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn alias(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn isUnion(t: TypeIndex) bool {
    _ = t;
    return false;
}

pub fn isString(t: TypeIndex) bool {
    _ = t;
    return false;
}

pub fn isIntersection(t: TypeIndex) bool {
    _ = t;
    return false;
}

pub fn isStringLiteral(t: TypeIndex) bool {
    _ = t;
    return false;
}

pub fn isNumberLiteral(t: TypeIndex) bool {
    _ = t;
    return false;
}

pub fn isBigIntLiteral(t: TypeIndex) bool {
    _ = t;
    return false;
}

pub fn isEnumLiteral(t: TypeIndex) bool {
    _ = t;
    return false;
}

pub fn isBooleanLike(t: TypeIndex) bool {
    _ = t;
    return false;
}

pub fn isStringLike(t: TypeIndex) bool {
    _ = t;
    return false;
}

pub fn isClass(t: TypeIndex) bool {
    _ = t;
    return false;
}

pub fn isTypeParameter(t: TypeIndex) bool {
    _ = t;
    return false;
}

pub fn isIndex(t: TypeIndex) bool {
    _ = t;
    return false;
}

pub fn isTupleType(t: TypeIndex) bool {
    _ = t;
    return false;
}

pub fn asType(t: TypeIndex) *anyopaque {
    _ = t;
    return undefined;
}

pub fn intrinsicName() *anyopaque {
    return undefined;
}

pub fn value() *anyopaque {
    return undefined;
}

pub fn freshType() *anyopaque {
    return undefined;
}

pub fn regularType() *anyopaque {
    return undefined;
}

pub fn callSignatures() *anyopaque {
    return undefined;
}

pub fn constructSignatures() *anyopaque {
    return undefined;
}

pub fn properties() *anyopaque {
    return undefined;
}

pub fn outerTypeParameters() *anyopaque {
    return undefined;
}

pub fn localTypeParameters() *anyopaque {
    return undefined;
}

pub fn typeParameters() *anyopaque {
    return undefined;
}

pub fn tupleElementFlags() *anyopaque {
    return undefined;
}

pub fn labeledDeclaration() *anyopaque {
    return undefined;
}

pub fn fixedLength() i32 {
    return 0;
}

pub fn isReadonly() bool {
    return false;
}

pub fn elementFlags() *anyopaque {
    return undefined;
}

pub fn elementInfos() *anyopaque {
    return undefined;
}

pub fn isThisType(t: TypeIndex) bool {
    _ = t;
    return false;
}

pub fn objectType() *anyopaque {
    return undefined;
}

pub fn indexType() *anyopaque {
    return undefined;
}

pub fn texts() *anyopaque {
    return undefined;
}

pub fn baseType() *anyopaque {
    return undefined;
}

pub fn substConstraint() *anyopaque {
    return undefined;
}

pub fn checkType() *anyopaque {
    return undefined;
}

pub fn extendsType() *anyopaque {
    return undefined;
}

pub fn declaration(s: *anyopaque) *anyopaque {
    _ = s;
    return undefined;
}

pub fn thisParameter(s: *anyopaque) *anyopaque {
    _ = s;
    return undefined;
}

pub fn parameters(s: *anyopaque) *anyopaque {
    _ = s;
    return undefined;
}

pub fn hasRestParameter(s: *anyopaque) bool {
    _ = s;
    return false;
}

pub fn minArgumentCount(s: *anyopaque) i32 {
    _ = s;
    return 0;
}

pub fn @"type"() *anyopaque {
    return undefined;
}

pub fn kind() *anyopaque {
    return undefined;
}

pub fn parameterIndex() i32 {
    return 0;
}

pub fn parameterName() *anyopaque {
    return undefined;
}

pub fn keyType() *anyopaque {
    return undefined;
}

pub fn valueType() *anyopaque {
    return undefined;
}
