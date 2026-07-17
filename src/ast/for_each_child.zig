const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const Ast = @import("../ast/ast.zig").Ast;

pub fn forEachChild(tree: *Ast, nodeIndex: ast_gen.NodeIndex, visitor: anytype) anyerror!void {
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .QualifiedName => |n| {
            if (@TypeOf(n.Left) == u32) {
                if (n.Left != 0) try visitor.visitNode(n.Left);
            } else {
                if (n.Left) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Right) == u32) {
                if (n.Right != 0) try visitor.visitNode(n.Right);
            } else {
                if (n.Right) |child| try visitor.visitNode(child);
            }
        },
        .ComputedPropertyName => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .Decorator => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .PropertyDeclaration => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.PostfixToken) == u32) {
                if (n.PostfixToken != 0) try visitor.visitNode(n.PostfixToken);
            } else {
                if (n.PostfixToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Initializer) == u32) {
                if (n.Initializer != 0) try visitor.visitNode(n.Initializer);
            } else {
                if (n.Initializer) |child| try visitor.visitNode(child);
            }
        },
        .MethodDeclaration => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.PostfixToken) == u32) {
                if (n.PostfixToken != 0) try visitor.visitNode(n.PostfixToken);
            } else {
                if (n.PostfixToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.TypeParameters) == u32) {
                if (n.TypeParameters != 0) try visitor.visitList(n.TypeParameters);
            } else {
                if (n.TypeParameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Parameters) == u32) {
                if (n.Parameters != 0) try visitor.visitList(n.Parameters);
            } else {
                if (n.Parameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.FullSignature) == u32) {
                if (n.FullSignature != 0) try visitor.visitNode(n.FullSignature);
            } else {
                if (n.FullSignature) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.AsteriskToken) == u32) {
                if (n.AsteriskToken != 0) try visitor.visitNode(n.AsteriskToken);
            } else {
                if (n.AsteriskToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Body) == u32) {
                if (n.Body != 0) try visitor.visitNode(n.Body);
            } else {
                if (n.Body) |child| try visitor.visitNode(child);
            }
        },
        .ClassStaticBlockDeclaration => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Body) == u32) {
                if (n.Body != 0) try visitor.visitNode(n.Body);
            } else {
                if (n.Body) |child| try visitor.visitNode(child);
            }
        },
        .NamedTupleMember => |n| {
            if (@TypeOf(n.DotDotDotToken) == u32) {
                if (n.DotDotDotToken != 0) try visitor.visitNode(n.DotDotDotToken);
            } else {
                if (n.DotDotDotToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.QuestionToken) == u32) {
                if (n.QuestionToken != 0) try visitor.visitNode(n.QuestionToken);
            } else {
                if (n.QuestionToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
        },
        .TemplateLiteralTypeSpan => |n| {
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Literal) == u32) {
                if (n.Literal != 0) try visitor.visitNode(n.Literal);
            } else {
                if (n.Literal) |child| try visitor.visitNode(child);
            }
        },
        .BindingElement => |n| {
            if (@TypeOf(n.DotDotDotToken) == u32) {
                if (n.DotDotDotToken != 0) try visitor.visitNode(n.DotDotDotToken);
            } else {
                if (n.DotDotDotToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.PropertyName) == u32) {
                if (n.PropertyName != 0) try visitor.visitNode(n.PropertyName);
            } else {
                if (n.PropertyName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Initializer) == u32) {
                if (n.Initializer != 0) try visitor.visitNode(n.Initializer);
            } else {
                if (n.Initializer) |child| try visitor.visitNode(child);
            }
        },
        .ArrayLiteralExpression => |n| {
            if (@TypeOf(n.Elements) == u32) {
                if (n.Elements != 0) try visitor.visitList(n.Elements);
            } else {
                if (n.Elements) |child| try visitor.visitList(child);
            }
        },
        .ObjectLiteralExpression => |n| {
            if (@TypeOf(n.Properties) == u32) {
                if (n.Properties != 0) try visitor.visitList(n.Properties);
            } else {
                if (n.Properties) |child| try visitor.visitList(child);
            }
        },
        .PropertyAccessExpression => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.QuestionDotToken) == u32) {
                if (n.QuestionDotToken != 0) try visitor.visitNode(n.QuestionDotToken);
            } else {
                if (n.QuestionDotToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
        },
        .ElementAccessExpression => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.QuestionDotToken) == u32) {
                if (n.QuestionDotToken != 0) try visitor.visitNode(n.QuestionDotToken);
            } else {
                if (n.QuestionDotToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.ArgumentExpression) == u32) {
                if (n.ArgumentExpression != 0) try visitor.visitNode(n.ArgumentExpression);
            } else {
                if (n.ArgumentExpression) |child| try visitor.visitNode(child);
            }
        },
        .CallExpression => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.QuestionDotToken) == u32) {
                if (n.QuestionDotToken != 0) try visitor.visitNode(n.QuestionDotToken);
            } else {
                if (n.QuestionDotToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.TypeArguments) == u32) {
                if (n.TypeArguments != 0) try visitor.visitList(n.TypeArguments);
            } else {
                if (n.TypeArguments) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Arguments) == u32) {
                if (n.Arguments != 0) try visitor.visitList(n.Arguments);
            } else {
                if (n.Arguments) |child| try visitor.visitList(child);
            }
        },
        .NewExpression => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.TypeArguments) == u32) {
                if (n.TypeArguments != 0) try visitor.visitList(n.TypeArguments);
            } else {
                if (n.TypeArguments) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Arguments) == u32) {
                if (n.Arguments != 0) try visitor.visitList(n.Arguments);
            } else {
                if (n.Arguments) |child| try visitor.visitList(child);
            }
        },
        .TaggedTemplateExpression => |n| {
            if (@TypeOf(n.Tag) == u32) {
                if (n.Tag != 0) try visitor.visitNode(n.Tag);
            } else {
                if (n.Tag) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.QuestionDotToken) == u32) {
                if (n.QuestionDotToken != 0) try visitor.visitNode(n.QuestionDotToken);
            } else {
                if (n.QuestionDotToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.TypeArguments) == u32) {
                if (n.TypeArguments != 0) try visitor.visitList(n.TypeArguments);
            } else {
                if (n.TypeArguments) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Template) == u32) {
                if (n.Template != 0) try visitor.visitNode(n.Template);
            } else {
                if (n.Template) |child| try visitor.visitNode(child);
            }
        },
        .ParenthesizedExpression => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .FunctionExpression => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.TypeParameters) == u32) {
                if (n.TypeParameters != 0) try visitor.visitList(n.TypeParameters);
            } else {
                if (n.TypeParameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Parameters) == u32) {
                if (n.Parameters != 0) try visitor.visitList(n.Parameters);
            } else {
                if (n.Parameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.FullSignature) == u32) {
                if (n.FullSignature != 0) try visitor.visitNode(n.FullSignature);
            } else {
                if (n.FullSignature) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.AsteriskToken) == u32) {
                if (n.AsteriskToken != 0) try visitor.visitNode(n.AsteriskToken);
            } else {
                if (n.AsteriskToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Body) == u32) {
                if (n.Body != 0) try visitor.visitNode(n.Body);
            } else {
                if (n.Body) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
        },
        .ArrowFunction => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.TypeParameters) == u32) {
                if (n.TypeParameters != 0) try visitor.visitList(n.TypeParameters);
            } else {
                if (n.TypeParameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Parameters) == u32) {
                if (n.Parameters != 0) try visitor.visitList(n.Parameters);
            } else {
                if (n.Parameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.FullSignature) == u32) {
                if (n.FullSignature != 0) try visitor.visitNode(n.FullSignature);
            } else {
                if (n.FullSignature) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.AsteriskToken) == u32) {
                if (n.AsteriskToken != 0) try visitor.visitNode(n.AsteriskToken);
            } else {
                if (n.AsteriskToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Body) == u32) {
                if (n.Body != 0) try visitor.visitNode(n.Body);
            } else {
                if (n.Body) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.EqualsGreaterThanToken) == u32) {
                if (n.EqualsGreaterThanToken != 0) try visitor.visitNode(n.EqualsGreaterThanToken);
            } else {
                if (n.EqualsGreaterThanToken) |child| try visitor.visitNode(child);
            }
        },
        .DeleteExpression => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .TypeOfExpression => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .VoidExpression => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .AwaitExpression => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .PrefixUnaryExpression => |n| {
            if (@TypeOf(n.Operand) == u32) {
                if (n.Operand != 0) try visitor.visitNode(n.Operand);
            } else {
                if (n.Operand) |child| try visitor.visitNode(child);
            }
        },
        .PostfixUnaryExpression => |n| {
            if (@TypeOf(n.Operand) == u32) {
                if (n.Operand != 0) try visitor.visitNode(n.Operand);
            } else {
                if (n.Operand) |child| try visitor.visitNode(child);
            }
        },
        .BinaryExpression => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Left) == u32) {
                if (n.Left != 0) try visitor.visitNode(n.Left);
            } else {
                if (n.Left) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.OperatorToken) == u32) {
                if (n.OperatorToken != 0) try visitor.visitNode(n.OperatorToken);
            } else {
                if (n.OperatorToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Right) == u32) {
                if (n.Right != 0) try visitor.visitNode(n.Right);
            } else {
                if (n.Right) |child| try visitor.visitNode(child);
            }
        },
        .ConditionalExpression => |n| {
            if (@TypeOf(n.Condition) == u32) {
                if (n.Condition != 0) try visitor.visitNode(n.Condition);
            } else {
                if (n.Condition) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.QuestionToken) == u32) {
                if (n.QuestionToken != 0) try visitor.visitNode(n.QuestionToken);
            } else {
                if (n.QuestionToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.WhenTrue) == u32) {
                if (n.WhenTrue != 0) try visitor.visitNode(n.WhenTrue);
            } else {
                if (n.WhenTrue) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.ColonToken) == u32) {
                if (n.ColonToken != 0) try visitor.visitNode(n.ColonToken);
            } else {
                if (n.ColonToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.WhenFalse) == u32) {
                if (n.WhenFalse != 0) try visitor.visitNode(n.WhenFalse);
            } else {
                if (n.WhenFalse) |child| try visitor.visitNode(child);
            }
        },
        .TemplateExpression => |n| {
            if (@TypeOf(n.Head) == u32) {
                if (n.Head != 0) try visitor.visitNode(n.Head);
            } else {
                if (n.Head) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.TemplateSpans) == u32) {
                if (n.TemplateSpans != 0) try visitor.visitList(n.TemplateSpans);
            } else {
                if (n.TemplateSpans) |child| try visitor.visitList(child);
            }
        },
        .YieldExpression => |n| {
            if (@TypeOf(n.AsteriskToken) == u32) {
                if (n.AsteriskToken != 0) try visitor.visitNode(n.AsteriskToken);
            } else {
                if (n.AsteriskToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .SpreadElement => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .ClassExpression => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.TypeParameters) == u32) {
                if (n.TypeParameters != 0) try visitor.visitList(n.TypeParameters);
            } else {
                if (n.TypeParameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.HeritageClauses) == u32) {
                if (n.HeritageClauses != 0) try visitor.visitList(n.HeritageClauses);
            } else {
                if (n.HeritageClauses) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Members) == u32) {
                if (n.Members != 0) try visitor.visitList(n.Members);
            } else {
                if (n.Members) |child| try visitor.visitList(child);
            }
        },
        .ExpressionWithTypeArguments => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.TypeArguments) == u32) {
                if (n.TypeArguments != 0) try visitor.visitList(n.TypeArguments);
            } else {
                if (n.TypeArguments) |child| try visitor.visitList(child);
            }
        },
        .AsExpression => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
        },
        .NonNullExpression => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .MetaProperty => |n| {
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
        },
        .SyntheticExpression => |n| {
            if (@TypeOf(n.TupleNameSource) == u32) {
                if (n.TupleNameSource != 0) try visitor.visitNode(n.TupleNameSource);
            } else {
                if (n.TupleNameSource) |child| try visitor.visitNode(child);
            }
        },
        .SatisfiesExpression => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
        },
        .TemplateSpan => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Literal) == u32) {
                if (n.Literal != 0) try visitor.visitNode(n.Literal);
            } else {
                if (n.Literal) |child| try visitor.visitNode(child);
            }
        },
        .Block => |n| {
            if (@TypeOf(n.Statements) == u32) {
                if (n.Statements != 0) try visitor.visitList(n.Statements);
            } else {
                if (n.Statements) |child| try visitor.visitList(child);
            }
        },
        .VariableStatement => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.DeclarationList) == u32) {
                if (n.DeclarationList != 0) try visitor.visitNode(n.DeclarationList);
            } else {
                if (n.DeclarationList) |child| try visitor.visitNode(child);
            }
        },
        .ExpressionStatement => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .IfStatement => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.ThenStatement) == u32) {
                if (n.ThenStatement != 0) try visitor.visitNode(n.ThenStatement);
            } else {
                if (n.ThenStatement) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.ElseStatement) == u32) {
                if (n.ElseStatement != 0) try visitor.visitNode(n.ElseStatement);
            } else {
                if (n.ElseStatement) |child| try visitor.visitNode(child);
            }
        },
        .DoStatement => |n| {
            if (@TypeOf(n.Statement) == u32) {
                if (n.Statement != 0) try visitor.visitNode(n.Statement);
            } else {
                if (n.Statement) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .WhileStatement => |n| {
            if (@TypeOf(n.Statement) == u32) {
                if (n.Statement != 0) try visitor.visitNode(n.Statement);
            } else {
                if (n.Statement) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .ForStatement => |n| {
            if (@TypeOf(n.Statement) == u32) {
                if (n.Statement != 0) try visitor.visitNode(n.Statement);
            } else {
                if (n.Statement) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Initializer) == u32) {
                if (n.Initializer != 0) try visitor.visitNode(n.Initializer);
            } else {
                if (n.Initializer) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Condition) == u32) {
                if (n.Condition != 0) try visitor.visitNode(n.Condition);
            } else {
                if (n.Condition) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Incrementor) == u32) {
                if (n.Incrementor != 0) try visitor.visitNode(n.Incrementor);
            } else {
                if (n.Incrementor) |child| try visitor.visitNode(child);
            }
        },
        .ContinueStatement => |n| {
            if (@TypeOf(n.Label) == u32) {
                if (n.Label != 0) try visitor.visitNode(n.Label);
            } else {
                if (n.Label) |child| try visitor.visitNode(child);
            }
        },
        .BreakStatement => |n| {
            if (@TypeOf(n.Label) == u32) {
                if (n.Label != 0) try visitor.visitNode(n.Label);
            } else {
                if (n.Label) |child| try visitor.visitNode(child);
            }
        },
        .ReturnStatement => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .WithStatement => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Statement) == u32) {
                if (n.Statement != 0) try visitor.visitNode(n.Statement);
            } else {
                if (n.Statement) |child| try visitor.visitNode(child);
            }
        },
        .SwitchStatement => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.CaseBlock) == u32) {
                if (n.CaseBlock != 0) try visitor.visitNode(n.CaseBlock);
            } else {
                if (n.CaseBlock) |child| try visitor.visitNode(child);
            }
        },
        .LabeledStatement => |n| {
            if (@TypeOf(n.Label) == u32) {
                if (n.Label != 0) try visitor.visitNode(n.Label);
            } else {
                if (n.Label) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Statement) == u32) {
                if (n.Statement != 0) try visitor.visitNode(n.Statement);
            } else {
                if (n.Statement) |child| try visitor.visitNode(child);
            }
        },
        .ThrowStatement => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .TryStatement => |n| {
            if (@TypeOf(n.TryBlock) == u32) {
                if (n.TryBlock != 0) try visitor.visitNode(n.TryBlock);
            } else {
                if (n.TryBlock) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.CatchClause) == u32) {
                if (n.CatchClause != 0) try visitor.visitNode(n.CatchClause);
            } else {
                if (n.CatchClause) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.FinallyBlock) == u32) {
                if (n.FinallyBlock != 0) try visitor.visitNode(n.FinallyBlock);
            } else {
                if (n.FinallyBlock) |child| try visitor.visitNode(child);
            }
        },
        .VariableDeclaration => |n| {
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.ExclamationToken) == u32) {
                if (n.ExclamationToken != 0) try visitor.visitNode(n.ExclamationToken);
            } else {
                if (n.ExclamationToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Initializer) == u32) {
                if (n.Initializer != 0) try visitor.visitNode(n.Initializer);
            } else {
                if (n.Initializer) |child| try visitor.visitNode(child);
            }
        },
        .VariableDeclarationList => |n| {
            if (@TypeOf(n.Declarations) == u32) {
                if (n.Declarations != 0) try visitor.visitList(n.Declarations);
            } else {
                if (n.Declarations) |child| try visitor.visitList(child);
            }
        },
        .FunctionDeclaration => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.TypeParameters) == u32) {
                if (n.TypeParameters != 0) try visitor.visitList(n.TypeParameters);
            } else {
                if (n.TypeParameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Parameters) == u32) {
                if (n.Parameters != 0) try visitor.visitList(n.Parameters);
            } else {
                if (n.Parameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.FullSignature) == u32) {
                if (n.FullSignature != 0) try visitor.visitNode(n.FullSignature);
            } else {
                if (n.FullSignature) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.AsteriskToken) == u32) {
                if (n.AsteriskToken != 0) try visitor.visitNode(n.AsteriskToken);
            } else {
                if (n.AsteriskToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Body) == u32) {
                if (n.Body != 0) try visitor.visitNode(n.Body);
            } else {
                if (n.Body) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
        },
        .ClassDeclaration => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.TypeParameters) == u32) {
                if (n.TypeParameters != 0) try visitor.visitList(n.TypeParameters);
            } else {
                if (n.TypeParameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.HeritageClauses) == u32) {
                if (n.HeritageClauses != 0) try visitor.visitList(n.HeritageClauses);
            } else {
                if (n.HeritageClauses) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Members) == u32) {
                if (n.Members != 0) try visitor.visitList(n.Members);
            } else {
                if (n.Members) |child| try visitor.visitList(child);
            }
        },
        .InterfaceDeclaration => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.TypeParameters) == u32) {
                if (n.TypeParameters != 0) try visitor.visitList(n.TypeParameters);
            } else {
                if (n.TypeParameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.HeritageClauses) == u32) {
                if (n.HeritageClauses != 0) try visitor.visitList(n.HeritageClauses);
            } else {
                if (n.HeritageClauses) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Members) == u32) {
                if (n.Members != 0) try visitor.visitList(n.Members);
            } else {
                if (n.Members) |child| try visitor.visitList(child);
            }
        },
        .TypeAliasDeclaration => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.TypeParameters) == u32) {
                if (n.TypeParameters != 0) try visitor.visitList(n.TypeParameters);
            } else {
                if (n.TypeParameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
        },
        .EnumDeclaration => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Members) == u32) {
                if (n.Members != 0) try visitor.visitList(n.Members);
            } else {
                if (n.Members) |child| try visitor.visitList(child);
            }
        },
        .ModuleDeclaration => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.AsteriskToken) == u32) {
                if (n.AsteriskToken != 0) try visitor.visitNode(n.AsteriskToken);
            } else {
                if (n.AsteriskToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Body) == u32) {
                if (n.Body != 0) try visitor.visitNode(n.Body);
            } else {
                if (n.Body) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
        },
        .ModuleBlock => |n| {
            if (@TypeOf(n.Statements) == u32) {
                if (n.Statements != 0) try visitor.visitList(n.Statements);
            } else {
                if (n.Statements) |child| try visitor.visitList(child);
            }
        },
        .CaseBlock => |n| {
            if (@TypeOf(n.Clauses) == u32) {
                if (n.Clauses != 0) try visitor.visitList(n.Clauses);
            } else {
                if (n.Clauses) |child| try visitor.visitList(child);
            }
        },
        .NamespaceExportDeclaration => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
        },
        .ImportEqualsDeclaration => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.ModuleReference) == u32) {
                if (n.ModuleReference != 0) try visitor.visitNode(n.ModuleReference);
            } else {
                if (n.ModuleReference) |child| try visitor.visitNode(child);
            }
        },
        .ImportDeclaration => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.ImportClause) == u32) {
                if (n.ImportClause != 0) try visitor.visitNode(n.ImportClause);
            } else {
                if (n.ImportClause) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.ModuleSpecifier) == u32) {
                if (n.ModuleSpecifier != 0) try visitor.visitNode(n.ModuleSpecifier);
            } else {
                if (n.ModuleSpecifier) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Attributes) == u32) {
                if (n.Attributes != 0) try visitor.visitNode(n.Attributes);
            } else {
                if (n.Attributes) |child| try visitor.visitNode(child);
            }
        },
        .ImportClause => |n| {
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.NamedBindings) == u32) {
                if (n.NamedBindings != 0) try visitor.visitNode(n.NamedBindings);
            } else {
                if (n.NamedBindings) |child| try visitor.visitNode(child);
            }
        },
        .NamespaceImport => |n| {
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
        },
        .NamedImports => |n| {
            if (@TypeOf(n.Elements) == u32) {
                if (n.Elements != 0) try visitor.visitList(n.Elements);
            } else {
                if (n.Elements) |child| try visitor.visitList(child);
            }
        },
        .ImportSpecifier => |n| {
            if (@TypeOf(n.PropertyName) == u32) {
                if (n.PropertyName != 0) try visitor.visitNode(n.PropertyName);
            } else {
                if (n.PropertyName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
        },
        .ExportAssignment => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .ExportDeclaration => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.ExportClause) == u32) {
                if (n.ExportClause != 0) try visitor.visitNode(n.ExportClause);
            } else {
                if (n.ExportClause) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.ModuleSpecifier) == u32) {
                if (n.ModuleSpecifier != 0) try visitor.visitNode(n.ModuleSpecifier);
            } else {
                if (n.ModuleSpecifier) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Attributes) == u32) {
                if (n.Attributes != 0) try visitor.visitNode(n.Attributes);
            } else {
                if (n.Attributes) |child| try visitor.visitNode(child);
            }
        },
        .NamedExports => |n| {
            if (@TypeOf(n.Elements) == u32) {
                if (n.Elements != 0) try visitor.visitList(n.Elements);
            } else {
                if (n.Elements) |child| try visitor.visitList(child);
            }
        },
        .NamespaceExport => |n| {
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
        },
        .ExportSpecifier => |n| {
            if (@TypeOf(n.PropertyName) == u32) {
                if (n.PropertyName != 0) try visitor.visitNode(n.PropertyName);
            } else {
                if (n.PropertyName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
        },
        .MissingDeclaration => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
        },
        .ExternalModuleReference => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .JsxElement => |n| {
            if (@TypeOf(n.OpeningElement) == u32) {
                if (n.OpeningElement != 0) try visitor.visitNode(n.OpeningElement);
            } else {
                if (n.OpeningElement) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Children) == u32) {
                if (n.Children != 0) try visitor.visitList(n.Children);
            } else {
                if (n.Children) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.ClosingElement) == u32) {
                if (n.ClosingElement != 0) try visitor.visitNode(n.ClosingElement);
            } else {
                if (n.ClosingElement) |child| try visitor.visitNode(child);
            }
        },
        .JsxSelfClosingElement => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.TypeArguments) == u32) {
                if (n.TypeArguments != 0) try visitor.visitList(n.TypeArguments);
            } else {
                if (n.TypeArguments) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Attributes) == u32) {
                if (n.Attributes != 0) try visitor.visitNode(n.Attributes);
            } else {
                if (n.Attributes) |child| try visitor.visitNode(child);
            }
        },
        .JsxOpeningElement => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.TypeArguments) == u32) {
                if (n.TypeArguments != 0) try visitor.visitList(n.TypeArguments);
            } else {
                if (n.TypeArguments) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Attributes) == u32) {
                if (n.Attributes != 0) try visitor.visitNode(n.Attributes);
            } else {
                if (n.Attributes) |child| try visitor.visitNode(child);
            }
        },
        .JsxClosingElement => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
        },
        .JsxFragment => |n| {
            if (@TypeOf(n.OpeningFragment) == u32) {
                if (n.OpeningFragment != 0) try visitor.visitNode(n.OpeningFragment);
            } else {
                if (n.OpeningFragment) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Children) == u32) {
                if (n.Children != 0) try visitor.visitList(n.Children);
            } else {
                if (n.Children) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.ClosingFragment) == u32) {
                if (n.ClosingFragment != 0) try visitor.visitNode(n.ClosingFragment);
            } else {
                if (n.ClosingFragment) |child| try visitor.visitNode(child);
            }
        },
        .JsxAttribute => |n| {
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Initializer) == u32) {
                if (n.Initializer != 0) try visitor.visitNode(n.Initializer);
            } else {
                if (n.Initializer) |child| try visitor.visitNode(child);
            }
        },
        .JsxAttributes => |n| {
            if (@TypeOf(n.Properties) == u32) {
                if (n.Properties != 0) try visitor.visitList(n.Properties);
            } else {
                if (n.Properties) |child| try visitor.visitList(child);
            }
        },
        .JsxSpreadAttribute => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .JsxExpression => |n| {
            if (@TypeOf(n.DotDotDotToken) == u32) {
                if (n.DotDotDotToken != 0) try visitor.visitNode(n.DotDotDotToken);
            } else {
                if (n.DotDotDotToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .JsxNamespacedName => |n| {
            if (@TypeOf(n.Namespace) == u32) {
                if (n.Namespace != 0) try visitor.visitNode(n.Namespace);
            } else {
                if (n.Namespace) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
        },
        .HeritageClause => |n| {
            if (@TypeOf(n.Types) == u32) {
                if (n.Types != 0) try visitor.visitList(n.Types);
            } else {
                if (n.Types) |child| try visitor.visitList(child);
            }
        },
        .CatchClause => |n| {
            if (@TypeOf(n.VariableDeclaration) == u32) {
                if (n.VariableDeclaration != 0) try visitor.visitNode(n.VariableDeclaration);
            } else {
                if (n.VariableDeclaration) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Block) == u32) {
                if (n.Block != 0) try visitor.visitNode(n.Block);
            } else {
                if (n.Block) |child| try visitor.visitNode(child);
            }
        },
        .ImportAttributes => |n| {
            if (@TypeOf(n.Attributes) == u32) {
                if (n.Attributes != 0) try visitor.visitList(n.Attributes);
            } else {
                if (n.Attributes) |child| try visitor.visitList(child);
            }
        },
        .ImportAttribute => |n| {
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Value) == u32) {
                if (n.Value != 0) try visitor.visitNode(n.Value);
            } else {
                if (n.Value) |child| try visitor.visitNode(child);
            }
        },
        .PropertyAssignment => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.PostfixToken) == u32) {
                if (n.PostfixToken != 0) try visitor.visitNode(n.PostfixToken);
            } else {
                if (n.PostfixToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Initializer) == u32) {
                if (n.Initializer != 0) try visitor.visitNode(n.Initializer);
            } else {
                if (n.Initializer) |child| try visitor.visitNode(child);
            }
        },
        .ShorthandPropertyAssignment => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.PostfixToken) == u32) {
                if (n.PostfixToken != 0) try visitor.visitNode(n.PostfixToken);
            } else {
                if (n.PostfixToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.EqualsToken) == u32) {
                if (n.EqualsToken != 0) try visitor.visitNode(n.EqualsToken);
            } else {
                if (n.EqualsToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.ObjectAssignmentInitializer) == u32) {
                if (n.ObjectAssignmentInitializer != 0) try visitor.visitNode(n.ObjectAssignmentInitializer);
            } else {
                if (n.ObjectAssignmentInitializer) |child| try visitor.visitNode(child);
            }
        },
        .SpreadAssignment => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .EnumMember => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.PostfixToken) == u32) {
                if (n.PostfixToken != 0) try visitor.visitNode(n.PostfixToken);
            } else {
                if (n.PostfixToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Initializer) == u32) {
                if (n.Initializer != 0) try visitor.visitNode(n.Initializer);
            } else {
                if (n.Initializer) |child| try visitor.visitNode(child);
            }
        },
        .SourceFile => |n| {
            if (@TypeOf(n.Statements) == u32) {
                if (n.Statements != 0) try visitor.visitList(n.Statements);
            } else {
                if (n.Statements) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.EndOfFileToken) == u32) {
                if (n.EndOfFileToken != 0) try visitor.visitNode(n.EndOfFileToken);
            } else {
                if (n.EndOfFileToken) |child| try visitor.visitNode(child);
            }
        },
        .JSDocTypeExpression => |n| {
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
        },
        .JSDocNameReference => |n| {
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
        },
        .JSDocNullableType => |n| {
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
        },
        .JSDocNonNullableType => |n| {
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
        },
        .JSDocOptionalType => |n| {
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
        },
        .JSDocVariadicType => |n| {
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
        },
        .JSDoc => |n| {
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Tags) == u32) {
                if (n.Tags != 0) try visitor.visitList(n.Tags);
            } else {
                if (n.Tags) |child| try visitor.visitList(child);
            }
        },
        .JSDocTypeLiteral => |n| {
            if (@TypeOf(n.JSDocPropertyTags) == u32) {
                if (n.JSDocPropertyTags != 0) try visitor.visitList(n.JSDocPropertyTags);
            } else {
                if (n.JSDocPropertyTags) |child| try visitor.visitList(child);
            }
        },
        .JSDocSignature => |n| {
            if (@TypeOf(n.TypeParameters) == u32) {
                if (n.TypeParameters != 0) try visitor.visitList(n.TypeParameters);
            } else {
                if (n.TypeParameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Parameters) == u32) {
                if (n.Parameters != 0) try visitor.visitList(n.Parameters);
            } else {
                if (n.Parameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.FullSignature) == u32) {
                if (n.FullSignature != 0) try visitor.visitNode(n.FullSignature);
            } else {
                if (n.FullSignature) |child| try visitor.visitNode(child);
            }
        },
        .JSDocLink => |n| {
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
        },
        .JSDocLinkCode => |n| {
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
        },
        .JSDocLinkPlain => |n| {
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
        },
        .JSDocUnknownTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
        },
        .JSDocAugmentsTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.ClassName) == u32) {
                if (n.ClassName != 0) try visitor.visitNode(n.ClassName);
            } else {
                if (n.ClassName) |child| try visitor.visitNode(child);
            }
        },
        .JSDocImplementsTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.ClassName) == u32) {
                if (n.ClassName != 0) try visitor.visitNode(n.ClassName);
            } else {
                if (n.ClassName) |child| try visitor.visitNode(child);
            }
        },
        .JSDocDeprecatedTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
        },
        .JSDocPublicTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
        },
        .JSDocPrivateTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
        },
        .JSDocProtectedTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
        },
        .JSDocReadonlyTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
        },
        .JSDocOverrideTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
        },
        .JSDocCallbackTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.TypeExpression) == u32) {
                if (n.TypeExpression != 0) try visitor.visitNode(n.TypeExpression);
            } else {
                if (n.TypeExpression) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
        },
        .JSDocOverloadTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.TypeExpression) == u32) {
                if (n.TypeExpression != 0) try visitor.visitNode(n.TypeExpression);
            } else {
                if (n.TypeExpression) |child| try visitor.visitNode(child);
            }
        },
        .JSDocReturnTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.TypeExpression) == u32) {
                if (n.TypeExpression != 0) try visitor.visitNode(n.TypeExpression);
            } else {
                if (n.TypeExpression) |child| try visitor.visitNode(child);
            }
        },
        .JSDocThisTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.TypeExpression) == u32) {
                if (n.TypeExpression != 0) try visitor.visitNode(n.TypeExpression);
            } else {
                if (n.TypeExpression) |child| try visitor.visitNode(child);
            }
        },
        .JSDocTypeTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.TypeExpression) == u32) {
                if (n.TypeExpression != 0) try visitor.visitNode(n.TypeExpression);
            } else {
                if (n.TypeExpression) |child| try visitor.visitNode(child);
            }
        },
        .JSDocTemplateTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Constraint) == u32) {
                if (n.Constraint != 0) try visitor.visitNode(n.Constraint);
            } else {
                if (n.Constraint) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.TypeParameters) == u32) {
                if (n.TypeParameters != 0) try visitor.visitList(n.TypeParameters);
            } else {
                if (n.TypeParameters) |child| try visitor.visitList(child);
            }
        },
        .JSDocTypedefTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.TypeExpression) == u32) {
                if (n.TypeExpression != 0) try visitor.visitNode(n.TypeExpression);
            } else {
                if (n.TypeExpression) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
        },
        .JSDocSeeTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.NameExpression) == u32) {
                if (n.NameExpression != 0) try visitor.visitNode(n.NameExpression);
            } else {
                if (n.NameExpression) |child| try visitor.visitNode(child);
            }
        },
        .JSDocThrowsTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.TypeExpression) == u32) {
                if (n.TypeExpression != 0) try visitor.visitNode(n.TypeExpression);
            } else {
                if (n.TypeExpression) |child| try visitor.visitNode(child);
            }
        },
        .JSDocSatisfiesTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.TypeExpression) == u32) {
                if (n.TypeExpression != 0) try visitor.visitNode(n.TypeExpression);
            } else {
                if (n.TypeExpression) |child| try visitor.visitNode(child);
            }
        },
        .JSDocImportTag => |n| {
            if (@TypeOf(n.TagName) == u32) {
                if (n.TagName != 0) try visitor.visitNode(n.TagName);
            } else {
                if (n.TagName) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Comment) == u32) {
                if (n.Comment != 0) try visitor.visitList(n.Comment);
            } else {
                if (n.Comment) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.ImportClause) == u32) {
                if (n.ImportClause != 0) try visitor.visitNode(n.ImportClause);
            } else {
                if (n.ImportClause) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.ModuleSpecifier) == u32) {
                if (n.ModuleSpecifier != 0) try visitor.visitNode(n.ModuleSpecifier);
            } else {
                if (n.ModuleSpecifier) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Attributes) == u32) {
                if (n.Attributes != 0) try visitor.visitNode(n.Attributes);
            } else {
                if (n.Attributes) |child| try visitor.visitNode(child);
            }
        },
        .SyntaxList => |n| {
            if (@TypeOf(n.Children) == u32) {
                if (n.Children != 0) try visitor.visitList(n.Children);
            } else {
                if (n.Children) |child| try visitor.visitList(child);
            }
        },
        .PartiallyEmittedExpression => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
        },
        .SyntheticReferenceExpression => |n| {
            if (@TypeOf(n.Expression) == u32) {
                if (n.Expression != 0) try visitor.visitNode(n.Expression);
            } else {
                if (n.Expression) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.ThisArg) == u32) {
                if (n.ThisArg != 0) try visitor.visitNode(n.ThisArg);
            } else {
                if (n.ThisArg) |child| try visitor.visitNode(child);
            }
        },
        .TypeReference => |n| {
            if (@TypeOf(n.TypeArguments) == u32) {
                if (n.TypeArguments != 0) try visitor.visitList(n.TypeArguments);
            } else {
                if (n.TypeArguments) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.TypeName) == u32) {
                if (n.TypeName != 0) try visitor.visitNode(n.TypeName);
            } else {
                if (n.TypeName) |child| try visitor.visitNode(child);
            }
        },
        .FunctionType => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.TypeParameters) == u32) {
                if (n.TypeParameters != 0) try visitor.visitList(n.TypeParameters);
            } else {
                if (n.TypeParameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Parameters) == u32) {
                if (n.Parameters != 0) try visitor.visitList(n.Parameters);
            } else {
                if (n.Parameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.FullSignature) == u32) {
                if (n.FullSignature != 0) try visitor.visitNode(n.FullSignature);
            } else {
                if (n.FullSignature) |child| try visitor.visitNode(child);
            }
        },
        .ConstructorType => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.TypeParameters) == u32) {
                if (n.TypeParameters != 0) try visitor.visitList(n.TypeParameters);
            } else {
                if (n.TypeParameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Parameters) == u32) {
                if (n.Parameters != 0) try visitor.visitList(n.Parameters);
            } else {
                if (n.Parameters) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.FullSignature) == u32) {
                if (n.FullSignature != 0) try visitor.visitNode(n.FullSignature);
            } else {
                if (n.FullSignature) |child| try visitor.visitNode(child);
            }
        },
        .TypeQuery => |n| {
            if (@TypeOf(n.TypeArguments) == u32) {
                if (n.TypeArguments != 0) try visitor.visitList(n.TypeArguments);
            } else {
                if (n.TypeArguments) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.ExprName) == u32) {
                if (n.ExprName != 0) try visitor.visitNode(n.ExprName);
            } else {
                if (n.ExprName) |child| try visitor.visitNode(child);
            }
        },
        .TypeLiteral => |n| {
            if (@TypeOf(n.Members) == u32) {
                if (n.Members != 0) try visitor.visitList(n.Members);
            } else {
                if (n.Members) |child| try visitor.visitList(child);
            }
        },
        .ArrayType => |n| {
            if (@TypeOf(n.ElementType) == u32) {
                if (n.ElementType != 0) try visitor.visitNode(n.ElementType);
            } else {
                if (n.ElementType) |child| try visitor.visitNode(child);
            }
        },
        .TupleType => |n| {
            if (@TypeOf(n.Elements) == u32) {
                if (n.Elements != 0) try visitor.visitList(n.Elements);
            } else {
                if (n.Elements) |child| try visitor.visitList(child);
            }
        },
        .OptionalType => |n| {
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
        },
        .RestType => |n| {
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
        },
        .UnionType => |n| {
            if (@TypeOf(n.Types) == u32) {
                if (n.Types != 0) try visitor.visitList(n.Types);
            } else {
                if (n.Types) |child| try visitor.visitList(child);
            }
        },
        .IntersectionType => |n| {
            if (@TypeOf(n.Types) == u32) {
                if (n.Types != 0) try visitor.visitList(n.Types);
            } else {
                if (n.Types) |child| try visitor.visitList(child);
            }
        },
        .ConditionalType => |n| {
            if (@TypeOf(n.CheckType) == u32) {
                if (n.CheckType != 0) try visitor.visitNode(n.CheckType);
            } else {
                if (n.CheckType) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.ExtendsType) == u32) {
                if (n.ExtendsType != 0) try visitor.visitNode(n.ExtendsType);
            } else {
                if (n.ExtendsType) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.TrueType) == u32) {
                if (n.TrueType != 0) try visitor.visitNode(n.TrueType);
            } else {
                if (n.TrueType) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.FalseType) == u32) {
                if (n.FalseType != 0) try visitor.visitNode(n.FalseType);
            } else {
                if (n.FalseType) |child| try visitor.visitNode(child);
            }
        },
        .InferType => |n| {
            if (@TypeOf(n.TypeParameter) == u32) {
                if (n.TypeParameter != 0) try visitor.visitNode(n.TypeParameter);
            } else {
                if (n.TypeParameter) |child| try visitor.visitNode(child);
            }
        },
        .ParenthesizedType => |n| {
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
        },
        .TypeOperator => |n| {
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
        },
        .IndexedAccessType => |n| {
            if (@TypeOf(n.ObjectType) == u32) {
                if (n.ObjectType != 0) try visitor.visitNode(n.ObjectType);
            } else {
                if (n.ObjectType) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.IndexType) == u32) {
                if (n.IndexType != 0) try visitor.visitNode(n.IndexType);
            } else {
                if (n.IndexType) |child| try visitor.visitNode(child);
            }
        },
        .MappedType => |n| {
            if (@TypeOf(n.ReadonlyToken) == u32) {
                if (n.ReadonlyToken != 0) try visitor.visitNode(n.ReadonlyToken);
            } else {
                if (n.ReadonlyToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.TypeParameter) == u32) {
                if (n.TypeParameter != 0) try visitor.visitNode(n.TypeParameter);
            } else {
                if (n.TypeParameter) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.NameType) == u32) {
                if (n.NameType != 0) try visitor.visitNode(n.NameType);
            } else {
                if (n.NameType) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.QuestionToken) == u32) {
                if (n.QuestionToken != 0) try visitor.visitNode(n.QuestionToken);
            } else {
                if (n.QuestionToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Members) == u32) {
                if (n.Members != 0) try visitor.visitList(n.Members);
            } else {
                if (n.Members) |child| try visitor.visitList(child);
            }
        },
        .LiteralType => |n| {
            if (@TypeOf(n.Literal) == u32) {
                if (n.Literal != 0) try visitor.visitNode(n.Literal);
            } else {
                if (n.Literal) |child| try visitor.visitNode(child);
            }
        },
        .TemplateLiteralType => |n| {
            if (@TypeOf(n.Head) == u32) {
                if (n.Head != 0) try visitor.visitNode(n.Head);
            } else {
                if (n.Head) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.TemplateSpans) == u32) {
                if (n.TemplateSpans != 0) try visitor.visitList(n.TemplateSpans);
            } else {
                if (n.TemplateSpans) |child| try visitor.visitList(child);
            }
        },
        .ImportType => |n| {
            if (@TypeOf(n.TypeArguments) == u32) {
                if (n.TypeArguments != 0) try visitor.visitList(n.TypeArguments);
            } else {
                if (n.TypeArguments) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.Argument) == u32) {
                if (n.Argument != 0) try visitor.visitNode(n.Argument);
            } else {
                if (n.Argument) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Attributes) == u32) {
                if (n.Attributes != 0) try visitor.visitNode(n.Attributes);
            } else {
                if (n.Attributes) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Qualifier) == u32) {
                if (n.Qualifier != 0) try visitor.visitNode(n.Qualifier);
            } else {
                if (n.Qualifier) |child| try visitor.visitNode(child);
            }
        },
        .Parameter => |n| {
            if (@TypeOf(n.modifiers) == u32) {
                if (n.modifiers != 0) try visitor.visitList(n.modifiers);
            } else {
                if (n.modifiers) |child| try visitor.visitList(child);
            }
            if (@TypeOf(n.DotDotDotToken) == u32) {
                if (n.DotDotDotToken != 0) try visitor.visitNode(n.DotDotDotToken);
            } else {
                if (n.DotDotDotToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.name) == u32) {
                if (n.name != 0) try visitor.visitNode(n.name);
            } else {
                if (n.name) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.QuestionToken) == u32) {
                if (n.QuestionToken != 0) try visitor.visitNode(n.QuestionToken);
            } else {
                if (n.QuestionToken) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Type) == u32) {
                if (n.Type != 0) try visitor.visitNode(n.Type);
            } else {
                if (n.Type) |child| try visitor.visitNode(child);
            }
            if (@TypeOf(n.Initializer) == u32) {
                if (n.Initializer != 0) try visitor.visitNode(n.Initializer);
            } else {
                if (n.Initializer) |child| try visitor.visitNode(child);
            }
        },
        .ObjectBindingPattern => |n| {
            if (n.Elements != 0) try visitor.visitList(n.Elements);
        },
        .ArrayBindingPattern => |n| {
            if (n.Elements != 0) try visitor.visitList(n.Elements);
        },
        else => {},
    }
}
