const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const Binder = @import("binder.zig").Binder;

pub fn bindFallback(self: *Binder, nodeIndex: ast_gen.NodeIndex) anyerror!void {
    const node = self.ast.getNode(nodeIndex);
    switch (node) {
        .QualifiedName => |n| {
            if (n.Left != 0) try self.bind(n.Left);
            if (n.Right != 0) try self.bind(n.Right);
        },
        .ComputedPropertyName => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .Decorator => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .PropertyDeclaration => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.name != 0) try self.bind(n.name);
            if (n.PostfixToken) |child| try self.bind(child);
            if (n.Type) |child| try self.bind(child);
            if (n.Initializer) |child| try self.bind(child);
        },
        .MethodDeclaration => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.name != 0) try self.bind(n.name);
            if (n.PostfixToken) |child| try self.bind(child);
            if (n.TypeParameters) |child| try self.bindChildren(child);
            if (n.Parameters != 0) try self.bindChildren(n.Parameters);
            if (n.Type) |child| try self.bind(child);
            if (n.FullSignature) |child| try self.bind(child);
            if (n.AsteriskToken) |child| try self.bind(child);
            if (n.Body) |child| try self.bind(child);
        },
        .ClassStaticBlockDeclaration => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.Body != 0) try self.bind(n.Body);
        },
        .NamedTupleMember => |n| {
            if (n.DotDotDotToken) |child| try self.bind(child);
            if (n.name != 0) try self.bind(n.name);
            if (n.QuestionToken) |child| try self.bind(child);
            if (n.Type != 0) try self.bind(n.Type);
        },
        .TemplateLiteralTypeSpan => |n| {
            if (n.Type != 0) try self.bind(n.Type);
            if (n.Literal != 0) try self.bind(n.Literal);
        },
        .BindingElement => |n| {
            if (n.DotDotDotToken) |child| try self.bind(child);
            if (n.PropertyName) |child| try self.bind(child);
            if (n.name) |child| try self.bind(child);
            if (n.Initializer) |child| try self.bind(child);
        },
        .ArrayLiteralExpression => |n| {
            if (n.Elements != 0) try self.bindChildren(n.Elements);
        },
        .ObjectLiteralExpression => |n| {
            if (n.Properties != 0) try self.bindChildren(n.Properties);
        },
        .PropertyAccessExpression => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
            if (n.QuestionDotToken) |child| try self.bind(child);
            if (n.name != 0) try self.bind(n.name);
        },
        .ElementAccessExpression => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
            if (n.QuestionDotToken) |child| try self.bind(child);
            if (n.ArgumentExpression != 0) try self.bind(n.ArgumentExpression);
        },
        .CallExpression => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
            if (n.QuestionDotToken) |child| try self.bind(child);
            if (n.TypeArguments) |child| try self.bindChildren(child);
            if (n.Arguments != 0) try self.bindChildren(n.Arguments);
        },
        .NewExpression => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
            if (n.TypeArguments) |child| try self.bindChildren(child);
            if (n.Arguments) |child| try self.bindChildren(child);
        },
        .TaggedTemplateExpression => |n| {
            if (n.Tag != 0) try self.bind(n.Tag);
            if (n.QuestionDotToken != 0) try self.bind(n.QuestionDotToken);
            if (n.TypeArguments) |child| try self.bindChildren(child);
            if (n.Template != 0) try self.bind(n.Template);
        },
        .ParenthesizedExpression => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .FunctionExpression => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.TypeParameters) |child| try self.bindChildren(child);
            if (n.Parameters != 0) try self.bindChildren(n.Parameters);
            if (n.Type) |child| try self.bind(child);
            if (n.FullSignature) |child| try self.bind(child);
            if (n.AsteriskToken) |child| try self.bind(child);
            if (n.Body) |child| try self.bind(child);
            if (n.name) |child| try self.bind(child);
        },
        .ArrowFunction => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.TypeParameters) |child| try self.bindChildren(child);
            if (n.Parameters != 0) try self.bindChildren(n.Parameters);
            if (n.Type) |child| try self.bind(child);
            if (n.FullSignature) |child| try self.bind(child);
            if (n.AsteriskToken) |child| try self.bind(child);
            if (n.Body) |child| try self.bind(child);
            if (n.EqualsGreaterThanToken != 0) try self.bind(n.EqualsGreaterThanToken);
        },
        .DeleteExpression => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .TypeOfExpression => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .VoidExpression => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .AwaitExpression => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .PrefixUnaryExpression => |n| {
            if (n.Operand != 0) try self.bind(n.Operand);
        },
        .PostfixUnaryExpression => |n| {
            if (n.Operand != 0) try self.bind(n.Operand);
        },
        .BinaryExpression => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.Left != 0) try self.bind(n.Left);
            if (n.Type) |child| try self.bind(child);
            if (n.OperatorToken != 0) try self.bind(n.OperatorToken);
            if (n.Right != 0) try self.bind(n.Right);
        },
        .ConditionalExpression => |n| {
            if (n.Condition != 0) try self.bind(n.Condition);
            if (n.QuestionToken != 0) try self.bind(n.QuestionToken);
            if (n.WhenTrue != 0) try self.bind(n.WhenTrue);
            if (n.ColonToken != 0) try self.bind(n.ColonToken);
            if (n.WhenFalse != 0) try self.bind(n.WhenFalse);
        },
        .TemplateExpression => |n| {
            if (n.Head != 0) try self.bind(n.Head);
            if (n.TemplateSpans != 0) try self.bindChildren(n.TemplateSpans);
        },
        .YieldExpression => |n| {
            if (n.AsteriskToken) |child| try self.bind(child);
            if (n.Expression) |child| try self.bind(child);
        },
        .SpreadElement => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .ClassExpression => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.name) |child| try self.bind(child);
            if (n.TypeParameters) |child| try self.bindChildren(child);
            if (n.HeritageClauses) |child| try self.bindChildren(child);
            if (n.Members != 0) try self.bindChildren(n.Members);
        },
        .ExpressionWithTypeArguments => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
            if (n.TypeArguments) |child| try self.bindChildren(child);
        },
        .AsExpression => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
            if (n.Type != 0) try self.bind(n.Type);
        },
        .NonNullExpression => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .MetaProperty => |n| {
            if (n.name != 0) try self.bind(n.name);
        },
        .SyntheticExpression => |n| {
            if (n.TupleNameSource) |child| try self.bind(child);
        },
        .SatisfiesExpression => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
            if (n.Type != 0) try self.bind(n.Type);
        },
        .TemplateSpan => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
            if (n.Literal != 0) try self.bind(n.Literal);
        },
        .Block => |n| {
            if (n.Statements != 0) try self.bindChildren(n.Statements);
        },
        .VariableStatement => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.DeclarationList != 0) try self.bind(n.DeclarationList);
        },
        .ExpressionStatement => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .IfStatement => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
            if (n.ThenStatement != 0) try self.bind(n.ThenStatement);
            if (n.ElseStatement) |child| try self.bind(child);
        },
        .DoStatement => |n| {
            if (n.Statement != 0) try self.bind(n.Statement);
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .WhileStatement => |n| {
            if (n.Statement != 0) try self.bind(n.Statement);
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .ForStatement => |n| {
            if (n.Statement != 0) try self.bind(n.Statement);
            if (n.Initializer) |child| try self.bind(child);
            if (n.Condition) |child| try self.bind(child);
            if (n.Incrementor) |child| try self.bind(child);
        },
        .ContinueStatement => |n| {
            if (n.Label) |child| try self.bind(child);
        },
        .BreakStatement => |n| {
            if (n.Label) |child| try self.bind(child);
        },
        .ReturnStatement => |n| {
            if (n.Expression) |child| try self.bind(child);
        },
        .WithStatement => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
            if (n.Statement != 0) try self.bind(n.Statement);
        },
        .SwitchStatement => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
            if (n.CaseBlock != 0) try self.bind(n.CaseBlock);
        },
        .LabeledStatement => |n| {
            if (n.Label != 0) try self.bind(n.Label);
            if (n.Statement != 0) try self.bind(n.Statement);
        },
        .ThrowStatement => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .TryStatement => |n| {
            if (n.TryBlock != 0) try self.bind(n.TryBlock);
            if (n.CatchClause) |child| try self.bind(child);
            if (n.FinallyBlock) |child| try self.bind(child);
        },
        .VariableDeclaration => |n| {
            if (n.name != 0) try self.bind(n.name);
            if (n.ExclamationToken) |child| try self.bind(child);
            if (n.Type) |child| try self.bind(child);
            if (n.Initializer) |child| try self.bind(child);
        },
        .VariableDeclarationList => |n| {
            if (n.Declarations != 0) try self.bindChildren(n.Declarations);
        },
        .FunctionDeclaration => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.TypeParameters) |child| try self.bindChildren(child);
            if (n.Parameters != 0) try self.bindChildren(n.Parameters);
            if (n.Type) |child| try self.bind(child);
            if (n.FullSignature) |child| try self.bind(child);
            if (n.AsteriskToken) |child| try self.bind(child);
            if (n.Body) |child| try self.bind(child);
            if (n.name) |child| try self.bind(child);
        },
        .ClassDeclaration => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.name) |child| try self.bind(child);
            if (n.TypeParameters) |child| try self.bindChildren(child);
            if (n.HeritageClauses) |child| try self.bindChildren(child);
            if (n.Members != 0) try self.bindChildren(n.Members);
        },
        .InterfaceDeclaration => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.name != 0) try self.bind(n.name);
            if (n.TypeParameters) |child| try self.bindChildren(child);
            if (n.HeritageClauses) |child| try self.bindChildren(child);
            if (n.Members != 0) try self.bindChildren(n.Members);
        },
        .TypeAliasDeclaration => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.name != 0) try self.bind(n.name);
            if (n.TypeParameters) |child| try self.bindChildren(child);
            if (n.Type != 0) try self.bind(n.Type);
        },
        .EnumDeclaration => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.name != 0) try self.bind(n.name);
            if (n.Members != 0) try self.bindChildren(n.Members);
        },
        .ModuleDeclaration => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.AsteriskToken) |child| try self.bind(child);
            if (n.Body) |child| try self.bind(child);
            if (n.name != 0) try self.bind(n.name);
        },
        .ModuleBlock => |n| {
            if (n.Statements != 0) try self.bindChildren(n.Statements);
        },
        .CaseBlock => |n| {
            if (n.Clauses != 0) try self.bindChildren(n.Clauses);
        },
        .NamespaceExportDeclaration => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.name != 0) try self.bind(n.name);
        },
        .ImportEqualsDeclaration => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.name != 0) try self.bind(n.name);
            if (n.ModuleReference != 0) try self.bind(n.ModuleReference);
        },
        .ImportDeclaration => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.ImportClause) |child| try self.bind(child);
            if (n.ModuleSpecifier != 0) try self.bind(n.ModuleSpecifier);
            if (n.Attributes) |child| try self.bind(child);
        },
        .ImportClause => |n| {
            if (n.name) |child| try self.bind(child);
            if (n.NamedBindings) |child| try self.bind(child);
        },
        .NamespaceImport => |n| {
            if (n.name != 0) try self.bind(n.name);
        },
        .NamedImports => |n| {
            if (n.Elements != 0) try self.bindChildren(n.Elements);
        },
        .ImportSpecifier => |n| {
            if (n.PropertyName) |child| try self.bind(child);
            if (n.name != 0) try self.bind(n.name);
        },
        .ExportAssignment => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.Type != 0) try self.bind(n.Type);
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .ExportDeclaration => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.ExportClause) |child| try self.bind(child);
            if (n.ModuleSpecifier) |child| try self.bind(child);
            if (n.Attributes) |child| try self.bind(child);
        },
        .NamedExports => |n| { std.debug.print("Visiting NamedExports {d}\n", .{nodeIndex});
            if (n.Elements != 0) try self.bindChildren(n.Elements);
        },
        .NamespaceExport => |n| {
            if (n.name != 0) try self.bind(n.name);
        },
        .ExportSpecifier => |n| {
            if (n.PropertyName) |child| try self.bind(child);
            if (n.name != 0) try self.bind(n.name);
        },
        .MissingDeclaration => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
        },
        .ExternalModuleReference => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .JsxElement => |n| {
            if (n.OpeningElement != 0) try self.bind(n.OpeningElement);
            if (n.Children != 0) try self.bindChildren(n.Children);
            if (n.ClosingElement != 0) try self.bind(n.ClosingElement);
        },
        .JsxSelfClosingElement => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.TypeArguments) |child| try self.bindChildren(child);
            if (n.Attributes != 0) try self.bind(n.Attributes);
        },
        .JsxOpeningElement => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.TypeArguments) |child| try self.bindChildren(child);
            if (n.Attributes != 0) try self.bind(n.Attributes);
        },
        .JsxClosingElement => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
        },
        .JsxFragment => |n| {
            if (n.OpeningFragment != 0) try self.bind(n.OpeningFragment);
            if (n.Children != 0) try self.bindChildren(n.Children);
            if (n.ClosingFragment != 0) try self.bind(n.ClosingFragment);
        },
        .JsxAttribute => |n| {
            if (n.name != 0) try self.bind(n.name);
            if (n.Initializer) |child| try self.bind(child);
        },
        .JsxAttributes => |n| {
            if (n.Properties != 0) try self.bindChildren(n.Properties);
        },
        .JsxSpreadAttribute => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .JsxExpression => |n| {
            if (n.DotDotDotToken) |child| try self.bind(child);
            if (n.Expression) |child| try self.bind(child);
        },
        .JsxNamespacedName => |n| {
            if (n.Namespace != 0) try self.bind(n.Namespace);
            if (n.name != 0) try self.bind(n.name);
        },
        .HeritageClause => |n| {
            if (n.Types != 0) try self.bindChildren(n.Types);
        },
        .CatchClause => |n| {
            if (n.VariableDeclaration) |child| try self.bind(child);
            if (n.Block != 0) try self.bind(n.Block);
        },
        .ImportAttributes => |n| {
            if (n.Attributes != 0) try self.bindChildren(n.Attributes);
        },
        .ImportAttribute => |n| {
            if (n.name != 0) try self.bind(n.name);
            if (n.Value != 0) try self.bind(n.Value);
        },
        .PropertyAssignment => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.name != 0) try self.bind(n.name);
            if (n.PostfixToken) |child| try self.bind(child);
            if (n.Type != 0) try self.bind(n.Type);
            if (n.Initializer != 0) try self.bind(n.Initializer);
        },
        .ShorthandPropertyAssignment => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.name != 0) try self.bind(n.name);
            if (n.PostfixToken) |child| try self.bind(child);
            if (n.Type != 0) try self.bind(n.Type);
            if (n.EqualsToken) |child| try self.bind(child);
            if (n.ObjectAssignmentInitializer) |child| try self.bind(child);
        },
        .SpreadAssignment => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .EnumMember => |n| {
            if (n.modifiers) |child| try self.bindChildren(child);
            if (n.name != 0) try self.bind(n.name);
            if (n.PostfixToken) |child| try self.bind(child);
            if (n.Initializer) |child| try self.bind(child);
        },
        .SourceFile => |n| {
            if (n.Statements != 0) try self.bindChildren(n.Statements);
            if (n.EndOfFileToken != 0) try self.bind(n.EndOfFileToken);
        },
        .JSDocTypeExpression => |n| {
            if (n.Type != 0) try self.bind(n.Type);
        },
        .JSDocNameReference => |n| {
            if (n.name != 0) try self.bind(n.name);
        },
        .JSDocNullableType => |n| {
            if (n.Type != 0) try self.bind(n.Type);
        },
        .JSDocNonNullableType => |n| {
            if (n.Type != 0) try self.bind(n.Type);
        },
        .JSDocOptionalType => |n| {
            if (n.Type != 0) try self.bind(n.Type);
        },
        .JSDocVariadicType => |n| {
            if (n.Type != 0) try self.bind(n.Type);
        },
        .JSDoc => |n| {
            if (n.Comment != 0) try self.bindChildren(n.Comment);
            if (n.Tags) |child| try self.bindChildren(child);
        },
        .JSDocTypeLiteral => |n| {
            if (n.JSDocPropertyTags) |child| try self.bindChildren(child);
        },
        .JSDocSignature => |n| {
            if (n.TypeParameters) |child| try self.bindChildren(child);
            if (n.Parameters != 0) try self.bindChildren(n.Parameters);
            if (n.Type) |child| try self.bind(child);
            if (n.FullSignature) |child| try self.bind(child);
        },
        .JSDocLink => |n| {
            if (n.name) |child| try self.bind(child);
        },
        .JSDocLinkCode => |n| {
            if (n.name) |child| try self.bind(child);
        },
        .JSDocLinkPlain => |n| {
            if (n.name) |child| try self.bind(child);
        },
        .JSDocUnknownTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
        },
        .JSDocAugmentsTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
            if (n.ClassName != 0) try self.bind(n.ClassName);
        },
        .JSDocImplementsTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
            if (n.ClassName != 0) try self.bind(n.ClassName);
        },
        .JSDocDeprecatedTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
        },
        .JSDocPublicTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
        },
        .JSDocPrivateTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
        },
        .JSDocProtectedTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
        },
        .JSDocReadonlyTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
        },
        .JSDocOverrideTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
        },
        .JSDocCallbackTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
            if (n.TypeExpression != 0) try self.bind(n.TypeExpression);
            if (n.name) |child| try self.bind(child);
        },
        .JSDocOverloadTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
            if (n.TypeExpression != 0) try self.bind(n.TypeExpression);
        },
        .JSDocReturnTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
            if (n.TypeExpression) |child| try self.bind(child);
        },
        .JSDocThisTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
            if (n.TypeExpression != 0) try self.bind(n.TypeExpression);
        },
        .JSDocTypeTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
            if (n.TypeExpression != 0) try self.bind(n.TypeExpression);
        },
        .JSDocTemplateTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
            if (n.Constraint != 0) try self.bind(n.Constraint);
            if (n.TypeParameters != 0) try self.bindChildren(n.TypeParameters);
        },
        .JSDocTypedefTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
            if (n.TypeExpression) |child| try self.bind(child);
            if (n.name) |child| try self.bind(child);
        },
        .JSDocSeeTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
            if (n.NameExpression != 0) try self.bind(n.NameExpression);
        },
        .JSDocThrowsTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
            if (n.TypeExpression) |child| try self.bind(child);
        },
        .JSDocSatisfiesTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
            if (n.TypeExpression != 0) try self.bind(n.TypeExpression);
        },
        .JSDocImportTag => |n| {
            if (n.TagName != 0) try self.bind(n.TagName);
            if (n.Comment) |child| try self.bindChildren(child);
            if (n.ImportClause) |child| try self.bind(child);
            if (n.ModuleSpecifier != 0) try self.bind(n.ModuleSpecifier);
            if (n.Attributes) |child| try self.bind(child);
        },
        .SyntaxList => |n| {
            if (n.Children != 0) try self.bindChildren(n.Children);
        },
        .PartiallyEmittedExpression => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
        },
        .SyntheticReferenceExpression => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
            if (n.ThisArg != 0) try self.bind(n.ThisArg);
        },
        .UnionType => |n| {
            if (n.Types != 0) try self.bindChildren(n.Types);
        },
        .IntersectionType => |n| {
            if (n.Types != 0) try self.bindChildren(n.Types);
        },
        .ConditionalType => |n| {
            if (n.CheckType != 0) try self.bind(n.CheckType);
            if (n.ExtendsType != 0) try self.bind(n.ExtendsType);
            if (n.TrueType != 0) try self.bind(n.TrueType);
            if (n.FalseType != 0) try self.bind(n.FalseType);
        },
        .InferType => |n| {
            if (n.TypeParameter != 0) try self.bind(n.TypeParameter);
        },
        .ArrayType => |n| {
            if (n.ElementType != 0) try self.bind(n.ElementType);
        },
        .IndexedAccessType => |n| {
            if (n.ObjectType != 0) try self.bind(n.ObjectType);
            if (n.IndexType != 0) try self.bind(n.IndexType);
        },
        .LiteralType => |n| {
            if (n.Literal != 0) try self.bind(n.Literal);
        },
        .TupleType => |n| {
            if (n.Elements != 0) try self.bindChildren(n.Elements);
        },
        .OptionalType => |n| {
            if (n.Type != 0) try self.bind(n.Type);
        },
        .RestType => |n| {
            if (n.Type != 0) try self.bind(n.Type);
        },
        .ParenthesizedType => |n| {
            if (n.Type != 0) try self.bind(n.Type);
        },
        .TemplateLiteralType => |n| {
            if (n.Head != 0) try self.bind(n.Head);
            if (n.TemplateSpans != 0) try self.bindChildren(n.TemplateSpans);
        },
        
        .TypeAssertionExpression => |n| {
            if (n.Expression != 0) try self.bind(n.Expression);
            if (n.Type != 0) try self.bind(n.Type);
        },
        .TypeReference => |n| {
            if (n.TypeName != 0) try self.bind(n.TypeName);
            if (n.TypeArguments) |args| try self.bindChildren(args);
        },
        else => {}
    }
}
