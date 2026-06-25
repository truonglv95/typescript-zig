// Auto-generated from typescript-go/_scripts/ast.json. DO NOT EDIT.
const std = @import("std");
const kind = @import("kind.zig");

// Type stubs cho Data-Oriented Design
pub const NodeIndex = u32;
pub const NodeListIndex = u32;
pub const SymbolIndex = u32;

pub const TokenNode = struct {
    Flags: u32,
};

pub const IdentifierNode = struct {
    Flags: u32,
    Text: []const u8,
};

pub const PrivateIdentifierNode = struct {
    Flags: u32,
    Text: []const u8,
};

pub const QualifiedNameNode = struct {
    Flags: u32,
    Left: u32,
    Right: u32,
};

pub const ComputedPropertyNameNode = struct {
    Flags: u32,
    Expression: u32,
};

pub const DecoratorNode = struct {
    Flags: u32,
    Expression: u32,
};

pub const EmptyStatementNode = struct {
    Flags: u32,
};

pub const IfStatementNode = struct {
    Flags: u32,
    Expression: u32,
    ThenStatement: u32,
    ElseStatement: ?u32,
};

pub const DoStatementNode = struct {
    Flags: u32,
    Statement: u32,
    Expression: u32,
};

pub const WhileStatementNode = struct {
    Flags: u32,
    Statement: u32,
    Expression: u32,
};

pub const ForStatementNode = struct {
    Flags: u32,
    Statement: u32,
    Initializer: ?u32,
    Condition: ?u32,
    Incrementor: ?u32,
};

pub const ForInOrOfStatementNode = struct {
    Flags: u32,
    AwaitModifier: ?u32,
    Initializer: u32,
    Expression: u32,
    Statement: u32,
};

pub const BreakStatementNode = struct {
    Flags: u32,
    Label: ?u32,
};

pub const ContinueStatementNode = struct {
    Flags: u32,
    Label: ?u32,
};

pub const ReturnStatementNode = struct {
    Flags: u32,
    Expression: ?u32,
};

pub const WithStatementNode = struct {
    Flags: u32,
    Expression: u32,
    Statement: u32,
};

pub const SwitchStatementNode = struct {
    Flags: u32,
    Expression: u32,
    CaseBlock: u32,
};

pub const CaseBlockNode = struct {
    Flags: u32,
    Clauses: u32,
};

pub const CaseOrDefaultClauseNode = struct {
    Flags: u32,
    Expression: u32,
    Statements: u32,
};

pub const ThrowStatementNode = struct {
    Flags: u32,
    Expression: u32,
};

pub const TryStatementNode = struct {
    Flags: u32,
    TryBlock: u32,
    CatchClause: ?u32,
    FinallyBlock: ?u32,
};

pub const CatchClauseNode = struct {
    Flags: u32,
    VariableDeclaration: ?u32,
    Block: u32,
};

pub const DebuggerStatementNode = struct {
    Flags: u32,
};

pub const LabeledStatementNode = struct {
    Flags: u32,
    Label: u32,
    Statement: u32,
};

pub const ExpressionStatementNode = struct {
    Flags: u32,
    Expression: u32,
};

pub const BlockNode = struct {
    Flags: u32,
    Statements: u32,
    MultiLine: bool,
};

pub const VariableStatementNode = struct {
    Flags: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    DeclarationList: u32,
};

pub const VariableDeclarationNode = struct {
    Flags: u32,
    Symbol: u32,
    name: u32,
    ExclamationToken: ?u32,
    Type: ?u32,
    Initializer: ?u32,
};

pub const VariableDeclarationListNode = struct {
    Flags: u32,
    Declarations: u32,
};

pub const BindingPatternNode = struct {
    Flags: u32,
    Elements: u32,
};

pub const ParameterDeclarationNode = struct {
    Flags: u32,
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    DotDotDotToken: ?u32,
    name: u32,
    QuestionToken: ?u32,
    Type: ?u32,
    Initializer: ?u32,
};

pub const BindingElementNode = struct {
    Flags: u32,
    Symbol: u32,
    DotDotDotToken: ?u32,
    PropertyName: ?u32,
    name: ?u32,
    Initializer: ?u32,
};

pub const MissingDeclarationNode = struct {
    Flags: u32,
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
};

pub const FunctionDeclarationNode = struct {
    Symbol: u32,
    Flags: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    TypeParameters: ?u32,
    Parameters: u32,
    Type: ?u32,
    FullSignature: ?u32,
    AsteriskToken: ?u32,
    Body: ?u32,
    name: ?u32,
};

pub const ClassDeclarationNode = struct {
    Symbol: u32,
    Flags: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    name: ?u32,
    TypeParameters: ?u32,
    HeritageClauses: ?u32,
    Members: u32,
};

pub const ClassExpressionNode = struct {
    Flags: u32,
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    name: ?u32,
    TypeParameters: ?u32,
    HeritageClauses: ?u32,
    Members: u32,
};

pub const HeritageClauseNode = struct {
    Flags: u32,
    Token: u32,
    Types: u32,
};

pub const InterfaceDeclarationNode = struct {
    Symbol: u32,
    Flags: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    name: u32,
    TypeParameters: ?u32,
    HeritageClauses: ?u32,
    Members: u32,
};

pub const TypeAliasDeclarationNode = struct {
    Symbol: u32,
    Flags: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    name: u32,
    TypeParameters: ?u32,
    Type: u32,
};

pub const EnumMemberNode = struct {
    Flags: u32,
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    name: u32,
    PostfixToken: ?u32,
    Initializer: ?u32,
};

pub const EnumDeclarationNode = struct {
    Symbol: u32,
    Flags: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    name: u32,
    Members: u32,
};

pub const ModuleBlockNode = struct {
    Flags: u32,
    Statements: u32,
};

pub const NotEmittedStatementNode = struct {
    Flags: u32,
};

pub const NotEmittedTypeElementNode = struct {
    Flags: u32,
};

pub const ImportDeclarationNode = struct {
    Flags: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    Symbol: u32,
    ImportClause: ?u32,
    ModuleSpecifier: u32,
    Attributes: ?u32,
};

pub const ExternalModuleReferenceNode = struct {
    Flags: u32,
    Expression: u32,
};

pub const NamespaceImportNode = struct {
    Flags: u32,
    Symbol: u32,
    name: u32,
};

pub const NamedImportsNode = struct {
    Flags: u32,
    Elements: u32,
};

pub const ExportAssignmentNode = struct {
    Symbol: u32,
    Flags: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    IsExportEquals: u32,
    Type: u32,
    Expression: u32,
};

pub const NamespaceExportDeclarationNode = struct {
    Symbol: u32,
    Flags: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    name: u32,
};

pub const NamespaceExportNode = struct {
    Flags: u32,
    Symbol: u32,
    name: u32,
};

pub const NamedExportsNode = struct {
    Flags: u32,
    Elements: u32,
};

pub const ExportSpecifierNode = struct {
    Flags: u32,
    Symbol: u32,
    IsTypeOnly: u32,
    PropertyName: ?u32,
    name: u32,
};

pub const CallSignatureDeclarationNode = struct {
    Flags: u32,
    Symbol: u32,
    TypeParameters: ?u32,
    Parameters: u32,
    Type: ?u32,
    FullSignature: ?u32,
};

pub const ConstructSignatureDeclarationNode = struct {
    Flags: u32,
    Symbol: u32,
    TypeParameters: ?u32,
    Parameters: u32,
    Type: ?u32,
    FullSignature: ?u32,
};

pub const ConstructorDeclarationNode = struct {
    Flags: u32,
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    TypeParameters: ?u32,
    Parameters: u32,
    Type: ?u32,
    FullSignature: ?u32,
    AsteriskToken: ?u32,
    Body: ?u32,
};

pub const GetAccessorDeclarationNode = struct {
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    name: u32,
    PostfixToken: ?u32,
    TypeParameters: ?u32,
    Parameters: u32,
    Type: ?u32,
    FullSignature: ?u32,
    AsteriskToken: ?u32,
    Body: ?u32,
    Flags: u32,
};

pub const SetAccessorDeclarationNode = struct {
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    name: u32,
    PostfixToken: ?u32,
    TypeParameters: ?u32,
    Parameters: u32,
    Type: ?u32,
    FullSignature: ?u32,
    AsteriskToken: ?u32,
    Body: ?u32,
    Flags: u32,
};

pub const IndexSignatureDeclarationNode = struct {
    Flags: u32,
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    TypeParameters: ?u32,
    Parameters: u32,
    Type: ?u32,
    FullSignature: ?u32,
};

pub const MethodSignatureDeclarationNode = struct {
    Flags: u32,
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    name: u32,
    PostfixToken: ?u32,
    TypeParameters: ?u32,
    Parameters: u32,
    Type: ?u32,
    FullSignature: ?u32,
};

pub const MethodDeclarationNode = struct {
    Flags: u32,
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    name: u32,
    PostfixToken: ?u32,
    TypeParameters: ?u32,
    Parameters: u32,
    Type: ?u32,
    FullSignature: ?u32,
    AsteriskToken: ?u32,
    Body: ?u32,
};

pub const PropertySignatureDeclarationNode = struct {
    Flags: u32,
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    name: u32,
    PostfixToken: ?u32,
    Type: ?u32,
    Initializer: ?u32,
};

pub const PropertyDeclarationNode = struct {
    Flags: u32,
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    name: u32,
    PostfixToken: ?u32,
    Type: ?u32,
    Initializer: ?u32,
};

pub const SemicolonClassElementNode = struct {
    Flags: u32,
    Symbol: u32,
};

pub const ClassStaticBlockDeclarationNode = struct {
    Flags: u32,
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    Body: u32,
};

pub const OmittedExpressionNode = struct {
    Flags: u32,
};

pub const KeywordExpressionNode = struct {
    Flags: u32,
};

pub const StringLiteralNode = struct {
    Text: []const u8,
    TokenFlags: u16,
    Flags: u32,
};

pub const NumericLiteralNode = struct {
    Text: []const u8,
    TokenFlags: u16,
    Flags: u32,
};

pub const BigIntLiteralNode = struct {
    Text: []const u8,
    TokenFlags: u16,
    Flags: u32,
};

pub const RegularExpressionLiteralNode = struct {
    Text: []const u8,
    TokenFlags: u16,
    Flags: u32,
};

pub const NoSubstitutionTemplateLiteralNode = struct {
    Flags: u32,
    Text: []const u8,
    TokenFlags: u16,
    RawText: []const u8,
    TemplateFlags: u16,
    Symbol: u32,
};

pub const BinaryExpressionNode = struct {
    Flags: u32,
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    Left: u32,
    Type: ?u32,
    OperatorToken: u32,
    Right: u32,
    linesBeforeOperator: u32,
    linesAfterOperator: u32,
};

pub const PrefixUnaryExpressionNode = struct {
    Flags: u32,
    Operator: u32,
    Operand: u32,
};

pub const PostfixUnaryExpressionNode = struct {
    Flags: u32,
    Operand: u32,
    Operator: u32,
};

pub const YieldExpressionNode = struct {
    Flags: u32,
    AsteriskToken: ?u32,
    Expression: ?u32,
};

pub const ArrowFunctionNode = struct {
    Flags: u32,
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    TypeParameters: ?u32,
    Parameters: u32,
    Type: ?u32,
    FullSignature: ?u32,
    AsteriskToken: ?u32,
    Body: ?u32,
    EqualsGreaterThanToken: u32,
};

pub const FunctionExpressionNode = struct {
    Flags: u32,
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    TypeParameters: ?u32,
    Parameters: u32,
    Type: ?u32,
    FullSignature: ?u32,
    AsteriskToken: ?u32,
    Body: ?u32,
    name: ?u32,
};

pub const AsExpressionNode = struct {
    Flags: u32,
    Expression: u32,
    Type: u32,
};

pub const SatisfiesExpressionNode = struct {
    Flags: u32,
    Expression: u32,
    Type: u32,
};

pub const ConditionalExpressionNode = struct {
    Flags: u32,
    Condition: u32,
    QuestionToken: u32,
    WhenTrue: u32,
    ColonToken: NodeIndex,
    WhenFalse: NodeIndex,
    linesBeforeQuestion: u32,
    linesAfterQuestion: u32,
    linesBeforeColon: u32,
    linesAfterColon: u32,
};

pub const PropertyAccessExpressionNode = struct {
    Flags: u32,
    Expression: u32,
    QuestionDotToken: ?u32,
    name: u32,
};

pub const ElementAccessExpressionNode = struct {
    Flags: u32,
    Expression: u32,
    QuestionDotToken: ?u32,
    ArgumentExpression: u32,
};

pub const CallExpressionNode = struct {
    Flags: u32,
    Symbol: u32,
    Expression: u32,
    QuestionDotToken: ?u32,
    TypeArguments: ?u32,
    Arguments: u32,
};

pub const NewExpressionNode = struct {
    Flags: u32,
    Expression: u32,
    TypeArguments: ?u32,
    Arguments: ?u32,
};

pub const MetaPropertyNode = struct {
    Flags: u32,
    KeywordToken: u32,
    name: u32,
};

pub const NonNullExpressionNode = struct {
    Flags: u32,
    Expression: u32,
};

pub const SpreadElementNode = struct {
    Flags: u32,
    Expression: u32,
};

pub const TemplateExpressionNode = struct {
    Flags: u32,
    Head: u32,
    TemplateSpans: u32,
};

pub const TemplateSpanNode = struct {
    Flags: u32,
    Expression: u32,
    Literal: u32,
};

pub const TaggedTemplateExpressionNode = struct {
    Flags: u32,
    Tag: u32,
    QuestionDotToken: ?u32,
    TypeArguments: ?u32,
    Template: u32,
};

pub const ParenthesizedExpressionNode = struct {
    Flags: u32,
    Expression: u32,
};

pub const ArrayLiteralExpressionNode = struct {
    Flags: u32,
    Elements: u32,
    MultiLine: u32,
};

pub const ObjectLiteralExpressionNode = struct {
    Flags: u32,
    Symbol: u32,
    Properties: u32,
    MultiLine: u32,
};

pub const SpreadAssignmentNode = struct {
    Flags: u32,
    Symbol: u32,
    Expression: u32,
};

pub const PropertyAssignmentNode = struct {
    Flags: u32,
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    name: u32,
    PostfixToken: ?u32,
    Type: ?u32,
    Initializer: u32,
};

pub const ShorthandPropertyAssignmentNode = struct {
    Flags: u32,
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    name: u32,
    PostfixToken: ?u32,
    Type: u32,
    EqualsToken: ?u32,
    ObjectAssignmentInitializer: ?u32,
};

pub const DeleteExpressionNode = struct {
    Flags: u32,
    Expression: u32,
};

pub const TypeOfExpressionNode = struct {
    Flags: u32,
    Expression: u32,
};

pub const VoidExpressionNode = struct {
    Flags: u32,
    Expression: u32,
};

pub const AwaitExpressionNode = struct {
    Flags: u32,
    Expression: u32,
};

pub const TypeAssertionNode = struct {
    Flags: u32,
    Type: u32,
    Expression: u32,
};

pub const KeywordTypeNodeNode = struct {
    Flags: u32,
};

pub const UnionTypeNodeNode = struct {
    Flags: u32,
    Types: u32,
};

pub const IntersectionTypeNodeNode = struct {
    Flags: u32,
    Types: u32,
};

pub const ConditionalTypeNodeNode = struct {
    Flags: u32,
    CheckType: u32,
    ExtendsType: u32,
    TrueType: u32,
    FalseType: u32,
};

pub const TypeOperatorNodeNode = struct {
    Flags: u32,
    Operator: u32,
    Type: u32,
};

pub const InferTypeNodeNode = struct {
    Flags: u32,
    TypeParameter: u32,
};

pub const ArrayTypeNodeNode = struct {
    Flags: u32,
    ElementType: u32,
};

pub const IndexedAccessTypeNodeNode = struct {
    Flags: u32,
    ObjectType: u32,
    IndexType: u32,
};

pub const TypeReferenceNodeNode = struct {
    Flags: u32,
    TypeArguments: ?u32,
    TypeName: u32,
};

pub const ExpressionWithTypeArgumentsNode = struct {
    Flags: u32,
    Expression: u32,
    TypeArguments: ?u32,
};

pub const LiteralTypeNodeNode = struct {
    Flags: u32,
    Literal: u32,
};

pub const ThisTypeNodeNode = struct {
    Flags: u32,
};

pub const TypePredicateNodeNode = struct {
    Flags: u32,
    AssertsModifier: ?u32,
    ParameterName: u32,
    Type: ?u32,
};

pub const ImportAttributeNode = struct {
    Flags: u32,
    name: u32,
    Value: u32,
};

pub const ImportAttributesNode = struct {
    Flags: u32,
    Token: u32,
    Attributes: u32,
    MultiLine: u32,
};

pub const TypeQueryNodeNode = struct {
    Flags: u32,
    TypeArguments: ?u32,
    ExprName: u32,
};

pub const MappedTypeNodeNode = struct {
    Flags: u32,
    Symbol: u32,
    ReadonlyToken: ?u32,
    TypeParameter: u32,
    NameType: ?u32,
    QuestionToken: ?u32,
    Type: ?u32,
    Members: ?u32,
};

pub const TypeLiteralNodeNode = struct {
    Flags: u32,
    Symbol: u32,
    Members: u32,
};

pub const TupleTypeNodeNode = struct {
    Flags: u32,
    Elements: u32,
};

pub const NamedTupleMemberNode = struct {
    Flags: u32,
    Symbol: u32,
    DotDotDotToken: ?u32,
    name: u32,
    QuestionToken: ?u32,
    Type: u32,
};

pub const OptionalTypeNodeNode = struct {
    Flags: u32,
    Type: u32,
};

pub const RestTypeNodeNode = struct {
    Flags: u32,
    Type: u32,
};

pub const ParenthesizedTypeNodeNode = struct {
    Flags: u32,
    Type: u32,
};

pub const FunctionTypeNodeNode = struct {
    Flags: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    Symbol: u32,
    TypeParameters: ?u32,
    Parameters: u32,
    Type: ?u32,
    FullSignature: ?u32,
};

pub const ConstructorTypeNodeNode = struct {
    Flags: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    Symbol: u32,
    TypeParameters: ?u32,
    Parameters: u32,
    Type: ?u32,
    FullSignature: ?u32,
};

pub const TemplateHeadNode = struct {
    Flags: u32,
    Text: []const u8,
    TokenFlags: u16,
    RawText: []const u8,
    TemplateFlags: u16,
};

pub const TemplateMiddleNode = struct {
    Flags: u32,
    Text: []const u8,
    TokenFlags: u16,
    RawText: []const u8,
    TemplateFlags: u16,
};

pub const TemplateTailNode = struct {
    Flags: u32,
    Text: []const u8,
    TokenFlags: u16,
    RawText: []const u8,
    TemplateFlags: u16,
};

pub const TemplateLiteralTypeNodeNode = struct {
    Flags: u32,
    Head: u32,
    TemplateSpans: u32,
};

pub const TemplateLiteralTypeSpanNode = struct {
    Flags: u32,
    Type: u32,
    Literal: u32,
};

pub const SyntheticExpressionNode = struct {
    Flags: u32,
    Type: u32,
    IsSpread: u32,
    TupleNameSource: ?u32,
};

pub const PartiallyEmittedExpressionNode = struct {
    Flags: u32,
    Expression: u32,
};

pub const JsxElementNode = struct {
    Flags: u32,
    OpeningElement: u32,
    Children: u32,
    ClosingElement: u32,
};

pub const JsxAttributesNode = struct {
    Flags: u32,
    Symbol: u32,
    Properties: u32,
};

pub const JsxNamespacedNameNode = struct {
    Flags: u32,
    Namespace: u32,
    name: u32,
};

pub const JsxOpeningElementNode = struct {
    Flags: u32,
    TagName: u32,
    TypeArguments: ?u32,
    Attributes: u32,
};

pub const JsxSelfClosingElementNode = struct {
    Flags: u32,
    TagName: u32,
    TypeArguments: ?u32,
    Attributes: u32,
};

pub const JsxFragmentNode = struct {
    Flags: u32,
    OpeningFragment: u32,
    Children: u32,
    ClosingFragment: u32,
};

pub const JsxOpeningFragmentNode = struct {
    Flags: u32,
};

pub const JsxClosingFragmentNode = struct {
    Flags: u32,
};

pub const JsxAttributeNode = struct {
    Flags: u32,
    Symbol: u32,
    name: u32,
    Initializer: ?u32,
};

pub const JsxSpreadAttributeNode = struct {
    Flags: u32,
    Expression: u32,
};

pub const JsxClosingElementNode = struct {
    Flags: u32,
    TagName: u32,
};

pub const JsxExpressionNode = struct {
    Flags: u32,
    DotDotDotToken: ?u32,
    Expression: ?u32,
};

pub const JsxTextNode = struct {
    Flags: u32,
    Text: []const u8,
    TokenFlags: u16,
    ContainsOnlyTriviaWhiteSpaces: u32,
};

pub const SyntaxListNode = struct {
    Flags: u32,
    Children: u32,
};

pub const JSDocNode = struct {
    Flags: u32,
    Comment: u32,
    Tags: ?u32,
};

pub const JSDocTypeExpressionNode = struct {
    Flags: u32,
    Type: u32,
};

pub const JSDocNonNullableTypeNode = struct {
    Flags: u32,
    Type: u32,
};

pub const JSDocNullableTypeNode = struct {
    Flags: u32,
    Type: u32,
};

pub const JSDocAllTypeNode = struct {
    Flags: u32,
};

pub const JSDocVariadicTypeNode = struct {
    Flags: u32,
    Type: u32,
};

pub const JSDocOptionalTypeNode = struct {
    Flags: u32,
    Type: u32,
};

pub const JSDocTypeTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
    TypeExpression: u32,
};

pub const JSDocUnknownTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
};

pub const JSDocTemplateTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
    Constraint: u32,
    TypeParameters: u32,
};

pub const JSDocReturnTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
    TypeExpression: ?u32,
};

pub const JSDocPublicTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
};

pub const JSDocPrivateTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
};

pub const JSDocProtectedTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
};

pub const JSDocReadonlyTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
};

pub const JSDocOverrideTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
};

pub const JSDocDeprecatedTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
};

pub const JSDocSeeTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
    NameExpression: u32,
};

pub const JSDocImplementsTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
    ClassName: u32,
};

pub const JSDocAugmentsTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
    ClassName: u32,
};

pub const JSDocSatisfiesTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
    TypeExpression: u32,
};

pub const JSDocThrowsTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
    TypeExpression: ?u32,
};

pub const JSDocThisTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
    TypeExpression: u32,
};

pub const JSDocImportTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
    ImportClause: ?u32,
    ModuleSpecifier: u32,
    Attributes: ?u32,
};

pub const JSDocCallbackTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
    TypeExpression: u32,
    name: ?u32,
};

pub const JSDocOverloadTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
    TypeExpression: u32,
};

pub const JSDocTypedefTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
    TypeExpression: ?u32,
    name: ?u32,
};

pub const JSDocSignatureNode = struct {
    Flags: u32,
    Symbol: u32,
    TypeParameters: ?u32,
    Parameters: u32,
    Type: ?u32,
    FullSignature: ?u32,
};

pub const JSDocNameReferenceNode = struct {
    Flags: u32,
    name: u32,
};

pub const SourceFileNode = struct {
    Flags: u32,
    Symbol: u32,
    Statements: u32,
    EndOfFileToken: u32,
    ExternalModuleIndicator: ?u32 = null,
    CommonJSModuleIndicator: ?u32 = null,
};

pub const ModuleDeclarationNode = struct {
    Symbol: u32,
    Flags: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    AsteriskToken: ?u32,
    Body: ?u32,
    Keyword: u32,
    name: u32,
};

pub const ImportEqualsDeclarationNode = struct {
    Symbol: u32,
    Flags: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    IsTypeOnly: u32,
    name: u32,
    ModuleReference: u32,
};

pub const ExportDeclarationNode = struct {
    Symbol: u32,
    Flags: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    IsTypeOnly: u32,
    ExportClause: ?u32,
    ModuleSpecifier: ?u32,
    Attributes: ?u32,
};

pub const ImportTypeNodeNode = struct {
    Flags: u32,
    TypeArguments: ?u32,
    IsTypeOf: u32,
    Argument: u32,
    Attributes: ?u32,
    Qualifier: ?u32,
};

pub const ImportClauseNode = struct {
    Flags: u32,
    Symbol: u32,
    PhaseModifier: ?u32,
    name: ?u32,
    NamedBindings: ?u32,
};

pub const ImportSpecifierNode = struct {
    Flags: u32,
    Symbol: u32,
    IsTypeOnly: u32,
    PropertyName: ?u32,
    name: u32,
};

pub const JSDocTextNode = struct {
    Flags: u32,
    text: []const u8,
};

pub const JSDocLinkNode = struct {
    Flags: u32,
    text: []const u8,
    name: ?u32,
};

pub const JSDocLinkPlainNode = struct {
    Flags: u32,
    text: []const u8,
    name: ?u32,
};

pub const JSDocLinkCodeNode = struct {
    Flags: u32,
    text: []const u8,
    name: ?u32,
};

pub const TypeParameterDeclarationNode = struct {
    Flags: u32,
    Symbol: u32,
    modifiers: ?u32,
    modifierFlags: u32,
    name: u32,
    Constraint: ?u32,
    Expression: ?u32,
    DefaultType: ?u32,
};

pub const SyntheticReferenceExpressionNode = struct {
    Flags: u32,
    Expression: u32,
    ThisArg: u32,
};

pub const JSDocTypeLiteralNode = struct {
    Flags: u32,
    Symbol: u32,
    JSDocPropertyTags: ?u32,
    IsArrayType: u32,
};

pub const JSDocParameterOrPropertyTagNode = struct {
    Flags: u32,
    TagName: u32,
    Comment: ?u32,
    name: u32,
    IsBracketed: u32,
    TypeExpression: ?u32,
    IsNameFirst: u32,
};

pub const NodeData = union(kind.Kind) {
    Unknown: void,
    EndOfFile: void,
    SingleLineCommentTrivia: void,
    MultiLineCommentTrivia: void,
    NewLineTrivia: void,
    WhitespaceTrivia: void,
    ConflictMarkerTrivia: void,
    NonTextFileMarkerTrivia: void,
    NumericLiteral: NumericLiteralNode,
    BigIntLiteral: BigIntLiteralNode,
    StringLiteral: StringLiteralNode,
    JsxText: JsxTextNode,
    JsxTextAllWhiteSpaces: void,
    RegularExpressionLiteral: RegularExpressionLiteralNode,
    NoSubstitutionTemplateLiteral: NoSubstitutionTemplateLiteralNode,
    TemplateHead: TemplateHeadNode,
    TemplateMiddle: TemplateMiddleNode,
    TemplateTail: TemplateTailNode,
    OpenBraceToken: void,
    CloseBraceToken: void,
    OpenParenToken: void,
    CloseParenToken: void,
    OpenBracketToken: void,
    CloseBracketToken: void,
    DotToken: void,
    DotDotDotToken: void,
    SemicolonToken: void,
    CommaToken: void,
    QuestionDotToken: void,
    LessThanToken: void,
    LessThanSlashToken: void,
    GreaterThanToken: void,
    LessThanEqualsToken: void,
    GreaterThanEqualsToken: void,
    EqualsEqualsToken: void,
    ExclamationEqualsToken: void,
    EqualsEqualsEqualsToken: void,
    ExclamationEqualsEqualsToken: void,
    EqualsGreaterThanToken: void,
    PlusToken: void,
    MinusToken: void,
    AsteriskToken: void,
    AsteriskAsteriskToken: void,
    SlashToken: void,
    PercentToken: void,
    PlusPlusToken: void,
    MinusMinusToken: void,
    LessThanLessThanToken: void,
    GreaterThanGreaterThanToken: void,
    GreaterThanGreaterThanGreaterThanToken: void,
    AmpersandToken: void,
    BarToken: void,
    CaretToken: void,
    ExclamationToken: void,
    TildeToken: void,
    AmpersandAmpersandToken: void,
    BarBarToken: void,
    QuestionToken: void,
    ColonToken: void,
    AtToken: void,
    QuestionQuestionToken: void,
    BacktickToken: void,
    HashToken: void,
    EqualsToken: void,
    PlusEqualsToken: void,
    MinusEqualsToken: void,
    AsteriskEqualsToken: void,
    AsteriskAsteriskEqualsToken: void,
    SlashEqualsToken: void,
    PercentEqualsToken: void,
    LessThanLessThanEqualsToken: void,
    GreaterThanGreaterThanEqualsToken: void,
    GreaterThanGreaterThanGreaterThanEqualsToken: void,
    AmpersandEqualsToken: void,
    BarEqualsToken: void,
    BarBarEqualsToken: void,
    AmpersandAmpersandEqualsToken: void,
    QuestionQuestionEqualsToken: void,
    CaretEqualsToken: void,
    Identifier: IdentifierNode,
    PrivateIdentifier: PrivateIdentifierNode,
    JSDocCommentTextToken: void,
    BreakKeyword: void,
    CaseKeyword: void,
    CatchKeyword: void,
    ClassKeyword: void,
    ConstKeyword: void,
    ContinueKeyword: void,
    DebuggerKeyword: void,
    DefaultKeyword: void,
    DeleteKeyword: void,
    DoKeyword: void,
    ElseKeyword: void,
    EnumKeyword: void,
    ExportKeyword: void,
    ExtendsKeyword: void,
    FalseKeyword: void,
    FinallyKeyword: void,
    ForKeyword: void,
    FunctionKeyword: void,
    IfKeyword: void,
    ImportKeyword: void,
    InKeyword: void,
    InstanceOfKeyword: void,
    NewKeyword: void,
    NullKeyword: void,
    ReturnKeyword: void,
    SuperKeyword: void,
    SwitchKeyword: void,
    ThisKeyword: void,
    ThrowKeyword: void,
    TrueKeyword: void,
    TryKeyword: void,
    TypeOfKeyword: void,
    VarKeyword: void,
    VoidKeyword: void,
    WhileKeyword: void,
    WithKeyword: void,
    ImplementsKeyword: void,
    InterfaceKeyword: void,
    LetKeyword: void,
    PackageKeyword: void,
    PrivateKeyword: void,
    ProtectedKeyword: void,
    PublicKeyword: void,
    StaticKeyword: void,
    YieldKeyword: void,
    AbstractKeyword: void,
    AccessorKeyword: void,
    AsKeyword: void,
    AssertsKeyword: void,
    AssertKeyword: void,
    AnyKeyword: void,
    AsyncKeyword: void,
    AwaitKeyword: void,
    BooleanKeyword: void,
    ConstructorKeyword: void,
    DeclareKeyword: void,
    GetKeyword: void,
    ImmediateKeyword: void,
    InferKeyword: void,
    IntrinsicKeyword: void,
    IsKeyword: void,
    KeyOfKeyword: void,
    ModuleKeyword: void,
    NamespaceKeyword: void,
    NeverKeyword: void,
    OutKeyword: void,
    ReadonlyKeyword: void,
    RequireKeyword: void,
    NumberKeyword: void,
    ObjectKeyword: void,
    SatisfiesKeyword: void,
    SetKeyword: void,
    StringKeyword: void,
    SymbolKeyword: void,
    TypeKeyword: void,
    UndefinedKeyword: void,
    UniqueKeyword: void,
    UnknownKeyword: void,
    UsingKeyword: void,
    FromKeyword: void,
    GlobalKeyword: void,
    BigIntKeyword: void,
    OverrideKeyword: void,
    OfKeyword: void,
    DeferKeyword: void,
    QualifiedName: QualifiedNameNode,
    ComputedPropertyName: ComputedPropertyNameNode,
    TypeParameter: TypeParameterDeclarationNode,
    Parameter: ParameterDeclarationNode,
    Decorator: DecoratorNode,
    PropertySignature: PropertySignatureDeclarationNode,
    PropertyDeclaration: PropertyDeclarationNode,
    MethodSignature: MethodSignatureDeclarationNode,
    MethodDeclaration: MethodDeclarationNode,
    ClassStaticBlockDeclaration: ClassStaticBlockDeclarationNode,
    Constructor: ConstructorDeclarationNode,
    GetAccessor: GetAccessorDeclarationNode,
    SetAccessor: SetAccessorDeclarationNode,
    CallSignature: CallSignatureDeclarationNode,
    ConstructSignature: ConstructSignatureDeclarationNode,
    IndexSignature: IndexSignatureDeclarationNode,
    TypePredicate: TypePredicateNodeNode,
    TypeReference: TypeReferenceNodeNode,
    FunctionType: FunctionTypeNodeNode,
    ConstructorType: ConstructorTypeNodeNode,
    TypeQuery: TypeQueryNodeNode,
    TypeLiteral: TypeLiteralNodeNode,
    ArrayType: ArrayTypeNodeNode,
    TupleType: TupleTypeNodeNode,
    OptionalType: OptionalTypeNodeNode,
    RestType: RestTypeNodeNode,
    UnionType: UnionTypeNodeNode,
    IntersectionType: IntersectionTypeNodeNode,
    ConditionalType: ConditionalTypeNodeNode,
    InferType: InferTypeNodeNode,
    ParenthesizedType: ParenthesizedTypeNodeNode,
    ThisType: ThisTypeNodeNode,
    TypeOperator: TypeOperatorNodeNode,
    IndexedAccessType: IndexedAccessTypeNodeNode,
    MappedType: MappedTypeNodeNode,
    LiteralType: LiteralTypeNodeNode,
    NamedTupleMember: NamedTupleMemberNode,
    TemplateLiteralType: TemplateLiteralTypeNodeNode,
    TemplateLiteralTypeSpan: TemplateLiteralTypeSpanNode,
    ImportType: ImportTypeNodeNode,
    ObjectBindingPattern: BindingPatternNode,
    ArrayBindingPattern: BindingPatternNode,
    BindingElement: BindingElementNode,
    ArrayLiteralExpression: ArrayLiteralExpressionNode,
    ObjectLiteralExpression: ObjectLiteralExpressionNode,
    PropertyAccessExpression: PropertyAccessExpressionNode,
    ElementAccessExpression: ElementAccessExpressionNode,
    CallExpression: CallExpressionNode,
    NewExpression: NewExpressionNode,
    TaggedTemplateExpression: TaggedTemplateExpressionNode,
    TypeAssertionExpression: TypeAssertionNode,
    ParenthesizedExpression: ParenthesizedExpressionNode,
    FunctionExpression: FunctionExpressionNode,
    ArrowFunction: ArrowFunctionNode,
    DeleteExpression: DeleteExpressionNode,
    TypeOfExpression: TypeOfExpressionNode,
    VoidExpression: VoidExpressionNode,
    AwaitExpression: AwaitExpressionNode,
    PrefixUnaryExpression: PrefixUnaryExpressionNode,
    PostfixUnaryExpression: PostfixUnaryExpressionNode,
    BinaryExpression: BinaryExpressionNode,
    ConditionalExpression: ConditionalExpressionNode,
    TemplateExpression: TemplateExpressionNode,
    YieldExpression: YieldExpressionNode,
    SpreadElement: SpreadElementNode,
    ClassExpression: ClassExpressionNode,
    OmittedExpression: OmittedExpressionNode,
    ExpressionWithTypeArguments: ExpressionWithTypeArgumentsNode,
    AsExpression: AsExpressionNode,
    NonNullExpression: NonNullExpressionNode,
    MetaProperty: MetaPropertyNode,
    SyntheticExpression: SyntheticExpressionNode,
    SatisfiesExpression: SatisfiesExpressionNode,
    TemplateSpan: TemplateSpanNode,
    SemicolonClassElement: SemicolonClassElementNode,
    Block: BlockNode,
    EmptyStatement: EmptyStatementNode,
    VariableStatement: VariableStatementNode,
    ExpressionStatement: ExpressionStatementNode,
    IfStatement: IfStatementNode,
    DoStatement: DoStatementNode,
    WhileStatement: WhileStatementNode,
    ForStatement: ForStatementNode,
    ForInStatement: ForInOrOfStatementNode,
    ForOfStatement: ForInOrOfStatementNode,
    ContinueStatement: ContinueStatementNode,
    BreakStatement: BreakStatementNode,
    ReturnStatement: ReturnStatementNode,
    WithStatement: WithStatementNode,
    SwitchStatement: SwitchStatementNode,
    LabeledStatement: LabeledStatementNode,
    ThrowStatement: ThrowStatementNode,
    TryStatement: TryStatementNode,
    DebuggerStatement: DebuggerStatementNode,
    VariableDeclaration: VariableDeclarationNode,
    VariableDeclarationList: VariableDeclarationListNode,
    FunctionDeclaration: FunctionDeclarationNode,
    ClassDeclaration: ClassDeclarationNode,
    InterfaceDeclaration: InterfaceDeclarationNode,
    TypeAliasDeclaration: TypeAliasDeclarationNode,
    EnumDeclaration: EnumDeclarationNode,
    ModuleDeclaration: ModuleDeclarationNode,
    ModuleBlock: ModuleBlockNode,
    CaseBlock: CaseBlockNode,
    NamespaceExportDeclaration: NamespaceExportDeclarationNode,
    ImportEqualsDeclaration: ImportEqualsDeclarationNode,
    ImportDeclaration: ImportDeclarationNode,
    ImportClause: ImportClauseNode,
    NamespaceImport: NamespaceImportNode,
    NamedImports: NamedImportsNode,
    ImportSpecifier: ImportSpecifierNode,
    ExportAssignment: ExportAssignmentNode,
    ExportDeclaration: ExportDeclarationNode,
    NamedExports: NamedExportsNode,
    NamespaceExport: NamespaceExportNode,
    ExportSpecifier: ExportSpecifierNode,
    MissingDeclaration: MissingDeclarationNode,
    ExternalModuleReference: ExternalModuleReferenceNode,
    JsxElement: JsxElementNode,
    JsxSelfClosingElement: JsxSelfClosingElementNode,
    JsxOpeningElement: JsxOpeningElementNode,
    JsxClosingElement: JsxClosingElementNode,
    JsxFragment: JsxFragmentNode,
    JsxOpeningFragment: JsxOpeningFragmentNode,
    JsxClosingFragment: JsxClosingFragmentNode,
    JsxAttribute: JsxAttributeNode,
    JsxAttributes: JsxAttributesNode,
    JsxSpreadAttribute: JsxSpreadAttributeNode,
    JsxExpression: JsxExpressionNode,
    JsxNamespacedName: JsxNamespacedNameNode,
    CaseClause: CaseOrDefaultClauseNode,
    DefaultClause: CaseOrDefaultClauseNode,
    HeritageClause: HeritageClauseNode,
    CatchClause: CatchClauseNode,
    ImportAttributes: ImportAttributesNode,
    ImportAttribute: ImportAttributeNode,
    PropertyAssignment: PropertyAssignmentNode,
    ShorthandPropertyAssignment: ShorthandPropertyAssignmentNode,
    SpreadAssignment: SpreadAssignmentNode,
    EnumMember: EnumMemberNode,
    SourceFile: SourceFileNode,
    JSDocTypeExpression: JSDocTypeExpressionNode,
    JSDocNameReference: JSDocNameReferenceNode,
    JSDocAllType: void,
    JSDocNullableType: JSDocNullableTypeNode,
    JSDocNonNullableType: JSDocNonNullableTypeNode,
    JSDocOptionalType: JSDocOptionalTypeNode,
    JSDocVariadicType: JSDocVariadicTypeNode,
    JSDoc: JSDocNode,
    JSDocText: JSDocTextNode,
    JSDocTypeLiteral: JSDocTypeLiteralNode,
    JSDocSignature: JSDocSignatureNode,
    JSDocLink: JSDocLinkNode,
    JSDocLinkCode: JSDocLinkCodeNode,
    JSDocLinkPlain: JSDocLinkPlainNode,
    JSDocUnknownTag: JSDocUnknownTagNode,
    JSDocAugmentsTag: JSDocAugmentsTagNode,
    JSDocImplementsTag: JSDocImplementsTagNode,
    JSDocDeprecatedTag: JSDocDeprecatedTagNode,
    JSDocPublicTag: JSDocPublicTagNode,
    JSDocPrivateTag: JSDocPrivateTagNode,
    JSDocProtectedTag: JSDocProtectedTagNode,
    JSDocReadonlyTag: JSDocReadonlyTagNode,
    JSDocOverrideTag: JSDocOverrideTagNode,
    JSDocCallbackTag: JSDocCallbackTagNode,
    JSDocOverloadTag: JSDocOverloadTagNode,
    JSDocParameterTag: JSDocParameterOrPropertyTagNode,
    JSDocReturnTag: JSDocReturnTagNode,
    JSDocThisTag: JSDocThisTagNode,
    JSDocTypeTag: JSDocTypeTagNode,
    JSDocTemplateTag: JSDocTemplateTagNode,
    JSDocTypedefTag: JSDocTypedefTagNode,
    JSDocSeeTag: JSDocSeeTagNode,
    JSDocPropertyTag: JSDocParameterOrPropertyTagNode,
    JSDocThrowsTag: JSDocThrowsTagNode,
    JSDocSatisfiesTag: JSDocSatisfiesTagNode,
    JSDocImportTag: JSDocImportTagNode,
    SyntaxList: SyntaxListNode,
    JSTypeAliasDeclaration: TypeAliasDeclarationNode,
    JSImportDeclaration: ImportDeclarationNode,
    NotEmittedStatement: NotEmittedStatementNode,
    PartiallyEmittedExpression: PartiallyEmittedExpressionNode,
    SyntheticReferenceExpression: SyntheticReferenceExpressionNode,
    NotEmittedTypeElement: NotEmittedTypeElementNode,
};
