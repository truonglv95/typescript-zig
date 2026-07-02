const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const ast = @import("../ast/ast.zig");

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
    pub const IsGenericTypeComputed: u32 = 1 << 22;
    pub const IsGenericObjectType: u32 = 1 << 23;
    pub const IsGenericIndexType: u32 = 1 << 24;
    pub const IsGenericType: u32 = IsGenericObjectType | IsGenericIndexType;

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
    },

    /// Intersection type: A & B
    Intersection: struct {
        typesStart: u32,
        typesLen: u32,
    },

    /// Conditional type: T extends U ? X : Y
    Conditional: struct {
        root: ast_gen.NodeIndex,
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

pub const TypeAlias = struct {
    symbol: ast_gen.SymbolIndex,
    typeArgumentsStart: u32,
    typeArgumentsLen: u32,
};

pub const TupleType = struct {
    typesStart: u32,
    typesLen: u32,
    readonly: bool = false,
    combinedFlags: u32 = 0,
    minLength: u32 = 0,
    fixedLength: u32 = 0,
    hasRestElement: bool = false,
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
    // instantiations: ...
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
    target: ?TypeIndex = null,
    typeArgumentsStart: u32 = 0,
    typeArgumentsLen: u32 = 0,
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

pub const InferenceContext = struct {
    inferences: std.ArrayListUnmanaged(u32) = .empty,
    intraExpressionInferenceSites: std.ArrayListUnmanaged(u32) = .empty,
};
pub const InferenceContextInfo = struct {};
pub const InferenceInfo = struct {
    candidates: std.ArrayListUnmanaged(TypeIndex) = .empty,
    contraCandidates: std.ArrayListUnmanaged(TypeIndex) = .empty,
};
pub const InferenceInfoIndex = u32;

pub const CacheHashKey = u64;

pub const EnumMemberLink = struct {
    value: @import("../ast/ast_generated.zig").NodeIndex = 0,
};

pub const ContainingSymbolLinks = struct {
    extendedContainersByFile: ?std.AutoHashMapUnmanaged(@import("../ast/ast_generated.zig").NodeIndex, []const @import("../ast/ast_generated.zig").symbolIndex) = null,
    extendedContainers: ?[]const @import("../ast/ast_generated.zig").symbolIndex = null,
    accessibleChainCache: ?std.AutoArrayHashMapUnmanaged(CacheHashKey, []const @import("../ast/ast_generated.zig").symbolIndex) = null,
};

pub const TypeFacts = struct {
    pub const NEUndefinedOrNull = 1;
    pub const EQUndefinedOrNull = 2;
    pub const Truthy = 3;
    pub const Falsy = 4;
};

pub const NodeIndexPair = struct {
    node1: @import("../ast/ast_generated.zig").NodeIndex,
    node2: @import("../ast/ast_generated.zig").NodeIndex,
};

pub const InferencePriority = struct {
    pub const None: i32 = 0;
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
