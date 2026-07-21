// Auto-generated from typescript-go/_scripts/ast.json. DO NOT EDIT.
const std = @import("std");

pub const Kind = enum(u16) {
    Unknown = 0,
    EndOfFile = 1,
    SingleLineCommentTrivia = 2,
    MultiLineCommentTrivia = 3,
    NewLineTrivia = 4,
    WhitespaceTrivia = 5,
    ConflictMarkerTrivia = 6,
    NonTextFileMarkerTrivia = 7,
    NumericLiteral = 8,
    BigIntLiteral = 9,
    StringLiteral = 10,
    JsxText = 11,
    JsxTextAllWhiteSpaces = 12,
    RegularExpressionLiteral = 13,
    NoSubstitutionTemplateLiteral = 14,
    // Pseudo-literals
    TemplateHead = 15,
    TemplateMiddle = 16,
    TemplateTail = 17,
    // Punctuation
    OpenBraceToken = 18,
    CloseBraceToken = 19,
    OpenParenToken = 20,
    CloseParenToken = 21,
    OpenBracketToken = 22,
    CloseBracketToken = 23,
    DotToken = 24,
    DotDotDotToken = 25,
    SemicolonToken = 26,
    CommaToken = 27,
    QuestionDotToken = 28,
    LessThanToken = 29,
    LessThanSlashToken = 30,
    GreaterThanToken = 31,
    LessThanEqualsToken = 32,
    GreaterThanEqualsToken = 33,
    EqualsEqualsToken = 34,
    ExclamationEqualsToken = 35,
    EqualsEqualsEqualsToken = 36,
    ExclamationEqualsEqualsToken = 37,
    EqualsGreaterThanToken = 38,
    PlusToken = 39,
    MinusToken = 40,
    AsteriskToken = 41,
    AsteriskAsteriskToken = 42,
    SlashToken = 43,
    PercentToken = 44,
    PlusPlusToken = 45,
    MinusMinusToken = 46,
    LessThanLessThanToken = 47,
    GreaterThanGreaterThanToken = 48,
    GreaterThanGreaterThanGreaterThanToken = 49,
    AmpersandToken = 50,
    BarToken = 51,
    CaretToken = 52,
    ExclamationToken = 53,
    TildeToken = 54,
    AmpersandAmpersandToken = 55,
    BarBarToken = 56,
    QuestionToken = 57,
    ColonToken = 58,
    AtToken = 59,
    QuestionQuestionToken = 60,
    // Only the JSDoc scanner produces BacktickToken. The normal scanner produces NoSubstitutionTemplateLiteral and related kinds.
    BacktickToken = 61,
    // Only the JSDoc scanner produces HashToken. The normal scanner produces PrivateIdentifier.
    HashToken = 62,
    // Assignments
    EqualsToken = 63,
    PlusEqualsToken = 64,
    MinusEqualsToken = 65,
    AsteriskEqualsToken = 66,
    AsteriskAsteriskEqualsToken = 67,
    SlashEqualsToken = 68,
    PercentEqualsToken = 69,
    LessThanLessThanEqualsToken = 70,
    GreaterThanGreaterThanEqualsToken = 71,
    GreaterThanGreaterThanGreaterThanEqualsToken = 72,
    AmpersandEqualsToken = 73,
    BarEqualsToken = 74,
    BarBarEqualsToken = 75,
    AmpersandAmpersandEqualsToken = 76,
    QuestionQuestionEqualsToken = 77,
    CaretEqualsToken = 78,
    // Identifiers and PrivateIdentifier
    Identifier = 79,
    PrivateIdentifier = 80,
    JSDocCommentTextToken = 81,
    // Reserved words
    BreakKeyword = 82,
    CaseKeyword = 83,
    CatchKeyword = 84,
    ClassKeyword = 85,
    ConstKeyword = 86,
    ContinueKeyword = 87,
    DebuggerKeyword = 88,
    DefaultKeyword = 89,
    DeleteKeyword = 90,
    DoKeyword = 91,
    ElseKeyword = 92,
    EnumKeyword = 93,
    ExportKeyword = 94,
    ExtendsKeyword = 95,
    FalseKeyword = 96,
    FinallyKeyword = 97,
    ForKeyword = 98,
    FunctionKeyword = 99,
    IfKeyword = 100,
    ImportKeyword = 101,
    InKeyword = 102,
    InstanceOfKeyword = 103,
    NewKeyword = 104,
    NullKeyword = 105,
    ReturnKeyword = 106,
    SuperKeyword = 107,
    SwitchKeyword = 108,
    ThisKeyword = 109,
    ThrowKeyword = 110,
    TrueKeyword = 111,
    TryKeyword = 112,
    TypeOfKeyword = 113,
    VarKeyword = 114,
    VoidKeyword = 115,
    WhileKeyword = 116,
    WithKeyword = 117,
    // Strict mode reserved words
    ImplementsKeyword = 118,
    InterfaceKeyword = 119,
    LetKeyword = 120,
    PackageKeyword = 121,
    PrivateKeyword = 122,
    ProtectedKeyword = 123,
    PublicKeyword = 124,
    StaticKeyword = 125,
    YieldKeyword = 126,
    // Contextual keywords
    AbstractKeyword = 127,
    AccessorKeyword = 128,
    AsKeyword = 129,
    AssertsKeyword = 130,
    AssertKeyword = 131,
    AnyKeyword = 132,
    AsyncKeyword = 133,
    AwaitKeyword = 134,
    BooleanKeyword = 135,
    ConstructorKeyword = 136,
    DeclareKeyword = 137,
    GetKeyword = 138,
    ImmediateKeyword = 139,
    InferKeyword = 140,
    IntrinsicKeyword = 141,
    IsKeyword = 142,
    KeyOfKeyword = 143,
    ModuleKeyword = 144,
    NamespaceKeyword = 145,
    NeverKeyword = 146,
    OutKeyword = 147,
    ReadonlyKeyword = 148,
    RequireKeyword = 149,
    NumberKeyword = 150,
    ObjectKeyword = 151,
    SatisfiesKeyword = 152,
    SetKeyword = 153,
    StringKeyword = 154,
    SymbolKeyword = 155,
    TypeKeyword = 156,
    UndefinedKeyword = 157,
    UniqueKeyword = 158,
    UnknownKeyword = 159,
    UsingKeyword = 160,
    FromKeyword = 161,
    GlobalKeyword = 162,
    BigIntKeyword = 163,
    OverrideKeyword = 164,
    OfKeyword = 165,
    // LastKeyword and LastToken and LastContextualKeyword
    DeferKeyword = 166,
    // Parse tree nodes
    // Names
    QualifiedName = 167,
    ComputedPropertyName = 168,
    // Signature elements
    TypeParameter = 169,
    Parameter = 170,
    Decorator = 171,
    // TypeMember
    PropertySignature = 172,
    PropertyDeclaration = 173,
    MethodSignature = 174,
    MethodDeclaration = 175,
    ClassStaticBlockDeclaration = 176,
    Constructor = 177,
    GetAccessor = 178,
    SetAccessor = 179,
    CallSignature = 180,
    ConstructSignature = 181,
    IndexSignature = 182,
    // Type
    TypePredicate = 183,
    TypeReference = 184,
    FunctionType = 185,
    ConstructorType = 186,
    TypeQuery = 187,
    TypeLiteral = 188,
    ArrayType = 189,
    TupleType = 190,
    OptionalType = 191,
    RestType = 192,
    UnionType = 193,
    IntersectionType = 194,
    ConditionalType = 195,
    InferType = 196,
    ParenthesizedType = 197,
    ThisType = 198,
    TypeOperator = 199,
    IndexedAccessType = 200,
    MappedType = 201,
    LiteralType = 202,
    NamedTupleMember = 203,
    TemplateLiteralType = 204,
    TemplateLiteralTypeSpan = 205,
    ImportType = 206,
    // Binding patterns
    ObjectBindingPattern = 207,
    ArrayBindingPattern = 208,
    BindingElement = 209,
    // Expression
    ArrayLiteralExpression = 210,
    ObjectLiteralExpression = 211,
    PropertyAccessExpression = 212,
    ElementAccessExpression = 213,
    CallExpression = 214,
    NewExpression = 215,
    TaggedTemplateExpression = 216,
    TypeAssertionExpression = 217,
    ParenthesizedExpression = 218,
    FunctionExpression = 219,
    ArrowFunction = 220,
    DeleteExpression = 221,
    TypeOfExpression = 222,
    VoidExpression = 223,
    AwaitExpression = 224,
    PrefixUnaryExpression = 225,
    PostfixUnaryExpression = 226,
    BinaryExpression = 227,
    ConditionalExpression = 228,
    TemplateExpression = 229,
    YieldExpression = 230,
    SpreadElement = 231,
    ClassExpression = 232,
    OmittedExpression = 233,
    ExpressionWithTypeArguments = 234,
    AsExpression = 235,
    NonNullExpression = 236,
    MetaProperty = 237,
    SyntheticExpression = 238,
    SatisfiesExpression = 239,
    // Misc
    TemplateSpan = 240,
    SemicolonClassElement = 241,
    // Element
    Block = 242,
    EmptyStatement = 243,
    VariableStatement = 244,
    ExpressionStatement = 245,
    IfStatement = 246,
    DoStatement = 247,
    WhileStatement = 248,
    ForStatement = 249,
    ForInStatement = 250,
    ForOfStatement = 251,
    ContinueStatement = 252,
    BreakStatement = 253,
    ReturnStatement = 254,
    WithStatement = 255,
    SwitchStatement = 256,
    LabeledStatement = 257,
    ThrowStatement = 258,
    TryStatement = 259,
    DebuggerStatement = 260,
    VariableDeclaration = 261,
    VariableDeclarationList = 262,
    FunctionDeclaration = 263,
    ClassDeclaration = 264,
    InterfaceDeclaration = 265,
    TypeAliasDeclaration = 266,
    EnumDeclaration = 267,
    ModuleDeclaration = 268,
    ModuleBlock = 269,
    CaseBlock = 270,
    NamespaceExportDeclaration = 271,
    ImportEqualsDeclaration = 272,
    ImportDeclaration = 273,
    ImportClause = 274,
    NamespaceImport = 275,
    NamedImports = 276,
    ImportSpecifier = 277,
    ExportAssignment = 278,
    ExportDeclaration = 279,
    NamedExports = 280,
    NamespaceExport = 281,
    ExportSpecifier = 282,
    MissingDeclaration = 283,
    // Module references
    ExternalModuleReference = 284,
    // JSX
    JsxElement = 285,
    JsxSelfClosingElement = 286,
    JsxOpeningElement = 287,
    JsxClosingElement = 288,
    JsxFragment = 289,
    JsxOpeningFragment = 290,
    JsxClosingFragment = 291,
    JsxAttribute = 292,
    JsxAttributes = 293,
    JsxSpreadAttribute = 294,
    JsxExpression = 295,
    JsxNamespacedName = 296,
    // Clauses
    CaseClause = 297,
    DefaultClause = 298,
    HeritageClause = 299,
    CatchClause = 300,
    // Import attributes
    ImportAttributes = 301,
    ImportAttribute = 302,
    // Property assignments
    PropertyAssignment = 303,
    ShorthandPropertyAssignment = 304,
    SpreadAssignment = 305,
    // Enum
    EnumMember = 306,
    // Top-level nodes
    SourceFile = 307,
    // JSDoc nodes
    JSDocTypeExpression = 308,
    JSDocNameReference = 309,
    // The * type
    JSDocAllType = 310,
    JSDocNullableType = 311,
    JSDocNonNullableType = 312,
    JSDocOptionalType = 313,
    JSDocVariadicType = 314,
    JSDoc = 315,
    JSDocText = 316,
    JSDocTypeLiteral = 317,
    JSDocSignature = 318,
    JSDocLink = 319,
    JSDocLinkCode = 320,
    JSDocLinkPlain = 321,
    JSDocUnknownTag = 322,
    JSDocAugmentsTag = 323,
    JSDocImplementsTag = 324,
    JSDocDeprecatedTag = 325,
    JSDocPublicTag = 326,
    JSDocPrivateTag = 327,
    JSDocProtectedTag = 328,
    JSDocReadonlyTag = 329,
    JSDocOverrideTag = 330,
    JSDocCallbackTag = 331,
    JSDocOverloadTag = 332,
    JSDocParameterTag = 333,
    JSDocReturnTag = 334,
    JSDocThisTag = 335,
    JSDocTypeTag = 336,
    JSDocTemplateTag = 337,
    JSDocTypedefTag = 338,
    JSDocSeeTag = 339,
    JSDocPropertyTag = 340,
    JSDocThrowsTag = 341,
    JSDocSatisfiesTag = 342,
    JSDocImportTag = 343,
    // Synthesized list
    SyntaxList = 344,
    // Reparsed JS nodes
    JSTypeAliasDeclaration = 345,
    JSImportDeclaration = 346,
    // Transformation nodes
    NotEmittedStatement = 347,
    PartiallyEmittedExpression = 348,
    SyntheticReferenceExpression = 349,
    NotEmittedTypeElement = 350,
};

// Tập hợp các Helper phân loại Token
pub fn isKeyword(kind: Kind) bool {
    return @intFromEnum(kind) >= @intFromEnum(Kind.BreakKeyword) and @intFromEnum(kind) <= @intFromEnum(Kind.DeferKeyword);
}

pub fn isPunctuation(kind: Kind) bool {
    return @intFromEnum(kind) >= @intFromEnum(Kind.OpenBraceToken) and @intFromEnum(kind) <= @intFromEnum(Kind.CaretEqualsToken);
}

pub fn isTrivia(kind: Kind) bool {
    return @intFromEnum(kind) >= @intFromEnum(Kind.SingleLineCommentTrivia) and @intFromEnum(kind) <= @intFromEnum(Kind.NonTextFileMarkerTrivia);
}

pub fn isTokenKind(kind: Kind) bool {
    return @intFromEnum(kind) >= @intFromEnum(Kind.Unknown) and @intFromEnum(kind) <= @intFromEnum(Kind.DeferKeyword);
}

/// Converts a string to a keyword Kind. Returns .Unknown if not a keyword.
pub fn keywordFromString(s: []const u8) Kind {
    if (std.mem.eql(u8, s, "break")) return .BreakKeyword;
    if (std.mem.eql(u8, s, "case")) return .CaseKeyword;
    if (std.mem.eql(u8, s, "catch")) return .CatchKeyword;
    if (std.mem.eql(u8, s, "class")) return .ClassKeyword;
    if (std.mem.eql(u8, s, "const")) return .ConstKeyword;
    if (std.mem.eql(u8, s, "continue")) return .ContinueKeyword;
    if (std.mem.eql(u8, s, "debugger")) return .DebuggerKeyword;
    if (std.mem.eql(u8, s, "default")) return .DefaultKeyword;
    if (std.mem.eql(u8, s, "delete")) return .DeleteKeyword;
    if (std.mem.eql(u8, s, "do")) return .DoKeyword;
    if (std.mem.eql(u8, s, "else")) return .ElseKeyword;
    if (std.mem.eql(u8, s, "enum")) return .EnumKeyword;
    if (std.mem.eql(u8, s, "export")) return .ExportKeyword;
    if (std.mem.eql(u8, s, "extends")) return .ExtendsKeyword;
    if (std.mem.eql(u8, s, "false")) return .FalseKeyword;
    if (std.mem.eql(u8, s, "finally")) return .FinallyKeyword;
    if (std.mem.eql(u8, s, "for")) return .ForKeyword;
    if (std.mem.eql(u8, s, "function")) return .FunctionKeyword;
    if (std.mem.eql(u8, s, "if")) return .IfKeyword;
    if (std.mem.eql(u8, s, "import")) return .ImportKeyword;
    if (std.mem.eql(u8, s, "in")) return .InKeyword;
    if (std.mem.eql(u8, s, "new")) return .NewKeyword;
    if (std.mem.eql(u8, s, "null")) return .NullKeyword;
    if (std.mem.eql(u8, s, "return")) return .ReturnKeyword;
    if (std.mem.eql(u8, s, "super")) return .SuperKeyword;
    if (std.mem.eql(u8, s, "switch")) return .SwitchKeyword;
    if (std.mem.eql(u8, s, "this")) return .ThisKeyword;
    if (std.mem.eql(u8, s, "throw")) return .ThrowKeyword;
    if (std.mem.eql(u8, s, "true")) return .TrueKeyword;
    if (std.mem.eql(u8, s, "try")) return .TryKeyword;
    if (std.mem.eql(u8, s, "typeof")) return .TypeOfKeyword;
    if (std.mem.eql(u8, s, "var")) return .VarKeyword;
    if (std.mem.eql(u8, s, "void")) return .VoidKeyword;
    if (std.mem.eql(u8, s, "while")) return .WhileKeyword;
    if (std.mem.eql(u8, s, "with")) return .WithKeyword;
    if (std.mem.eql(u8, s, "implements")) return .ImplementsKeyword;
    if (std.mem.eql(u8, s, "interface")) return .InterfaceKeyword;
    if (std.mem.eql(u8, s, "let")) return .LetKeyword;
    if (std.mem.eql(u8, s, "package")) return .PackageKeyword;
    if (std.mem.eql(u8, s, "private")) return .PrivateKeyword;
    if (std.mem.eql(u8, s, "protected")) return .ProtectedKeyword;
    if (std.mem.eql(u8, s, "public")) return .PublicKeyword;
    if (std.mem.eql(u8, s, "static")) return .StaticKeyword;
    if (std.mem.eql(u8, s, "yield")) return .YieldKeyword;
    if (std.mem.eql(u8, s, "abstract")) return .AbstractKeyword;
    if (std.mem.eql(u8, s, "as")) return .AsKeyword;
    if (std.mem.eql(u8, s, "asserts")) return .AssertsKeyword;
    if (std.mem.eql(u8, s, "assert")) return .AssertKeyword;
    if (std.mem.eql(u8, s, "any")) return .AnyKeyword;
    if (std.mem.eql(u8, s, "async")) return .AsyncKeyword;
    if (std.mem.eql(u8, s, "await")) return .AwaitKeyword;
    if (std.mem.eql(u8, s, "boolean")) return .BooleanKeyword;
    if (std.mem.eql(u8, s, "constructor")) return .ConstructorKeyword;
    if (std.mem.eql(u8, s, "declare")) return .DeclareKeyword;
    if (std.mem.eql(u8, s, "get")) return .GetKeyword;
    if (std.mem.eql(u8, s, "infer")) return .InferKeyword;
    if (std.mem.eql(u8, s, "intrinsic")) return .IntrinsicKeyword;
    if (std.mem.eql(u8, s, "is")) return .IsKeyword;
    if (std.mem.eql(u8, s, "keyof")) return .KeyOfKeyword;
    if (std.mem.eql(u8, s, "module")) return .ModuleKeyword;
    if (std.mem.eql(u8, s, "namespace")) return .NamespaceKeyword;
    if (std.mem.eql(u8, s, "never")) return .NeverKeyword;
    if (std.mem.eql(u8, s, "number")) return .NumberKeyword;
    if (std.mem.eql(u8, s, "object")) return .ObjectKeyword;
    if (std.mem.eql(u8, s, "out")) return .OutKeyword;
    if (std.mem.eql(u8, s, "override")) return .OverrideKeyword;
    if (std.mem.eql(u8, s, "readonly")) return .ReadonlyKeyword;
    if (std.mem.eql(u8, s, "require")) return .RequireKeyword;
    if (std.mem.eql(u8, s, "set")) return .SetKeyword;
    if (std.mem.eql(u8, s, "string")) return .StringKeyword;
    if (std.mem.eql(u8, s, "symbol")) return .SymbolKeyword;
    if (std.mem.eql(u8, s, "type")) return .TypeKeyword;
    if (std.mem.eql(u8, s, "undefined")) return .UndefinedKeyword;
    if (std.mem.eql(u8, s, "unique")) return .UniqueKeyword;
    if (std.mem.eql(u8, s, "unknown")) return .UnknownKeyword;
    if (std.mem.eql(u8, s, "from")) return .FromKeyword;
    if (std.mem.eql(u8, s, "of")) return .OfKeyword;
    if (std.mem.eql(u8, s, "bigint")) return .BigIntKeyword;
    if (std.mem.eql(u8, s, "satisfies")) return .SatisfiesKeyword;
    if (std.mem.eql(u8, s, "using")) return .UsingKeyword;
    if (std.mem.eql(u8, s, "defer")) return .DeferKeyword;
    return .Unknown;
}
