const std = @import("std");
const ast = @import("ast.zig");
const ast_gen = @import("ast_generated.zig");
const visitor = @import("visitor.zig");

pub fn visitEachChild(self: *visitor.NodeVisitor, nodeIndex: ast.NodeIndex) ast.NodeIndex {
    if (nodeIndex == 0) return 0;
    const node = self.tree.getNode(nodeIndex);

    switch (node) {
        .QualifiedName => |n| {
            var new_n = n;
            new_n.Left = self.visitNodeInternal(n.Left);
            new_n.Right = self.visitNodeInternal(n.Right);
            if (new_n.Left != n.Left or new_n.Right != n.Right) {
                return self.tree.pushNode(.{ .QualifiedName = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ComputedPropertyName => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .ComputedPropertyName = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .TypeParameter => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (n.Constraint) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Constraint = if (res == 0) null else res;
            }
            if (n.Expression) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Expression = if (res == 0) null else res;
            }
            if (n.DefaultType) |v| {
                const res = self.visitNodeInternal(v);
                new_n.DefaultType = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.name != n.name or new_n.Constraint != n.Constraint or new_n.Expression != n.Expression or new_n.DefaultType != n.DefaultType) {
                return self.tree.pushNode(.{ .TypeParameter = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .Parameter => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            if (n.DotDotDotToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.DotDotDotToken = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (n.QuestionToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.QuestionToken = if (res == 0) null else res;
            }
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.Initializer) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Initializer = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.DotDotDotToken != n.DotDotDotToken or new_n.name != n.name or new_n.QuestionToken != n.QuestionToken or new_n.Type != n.Type or new_n.Initializer != n.Initializer) {
                return self.tree.pushNode(.{ .Parameter = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .Decorator => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .Decorator = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .PropertySignature => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (n.PostfixToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.PostfixToken = if (res == 0) null else res;
            }
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.Initializer) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Initializer = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.name != n.name or new_n.PostfixToken != n.PostfixToken or new_n.Type != n.Type or new_n.Initializer != n.Initializer) {
                return self.tree.pushNode(.{ .PropertySignature = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .PropertyDeclaration => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (n.PostfixToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.PostfixToken = if (res == 0) null else res;
            }
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.Initializer) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Initializer = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.name != n.name or new_n.PostfixToken != n.PostfixToken or new_n.Type != n.Type or new_n.Initializer != n.Initializer) {
                return self.tree.pushNode(.{ .PropertyDeclaration = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .MethodSignature => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (n.PostfixToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.PostfixToken = if (res == 0) null else res;
            }
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            new_n.Parameters = self.visitNodesInternal(n.Parameters);
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.FullSignature) |v| {
                const res = self.visitNodeInternal(v);
                new_n.FullSignature = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.name != n.name or new_n.PostfixToken != n.PostfixToken or new_n.TypeParameters != n.TypeParameters or new_n.Parameters != n.Parameters or new_n.Type != n.Type or new_n.FullSignature != n.FullSignature) {
                return self.tree.pushNode(.{ .MethodSignature = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .MethodDeclaration => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (n.PostfixToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.PostfixToken = if (res == 0) null else res;
            }
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            new_n.Parameters = self.visitNodesInternal(n.Parameters);
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.FullSignature) |v| {
                const res = self.visitNodeInternal(v);
                new_n.FullSignature = if (res == 0) null else res;
            }
            if (n.AsteriskToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.AsteriskToken = if (res == 0) null else res;
            }
            if (n.Body) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Body = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.name != n.name or new_n.PostfixToken != n.PostfixToken or new_n.TypeParameters != n.TypeParameters or new_n.Parameters != n.Parameters or new_n.Type != n.Type or new_n.FullSignature != n.FullSignature or new_n.AsteriskToken != n.AsteriskToken or new_n.Body != n.Body) {
                return self.tree.pushNode(.{ .MethodDeclaration = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ClassStaticBlockDeclaration => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.Body = self.visitNodeInternal(n.Body);
            if (new_n.modifiers != n.modifiers or new_n.Body != n.Body) {
                return self.tree.pushNode(.{ .ClassStaticBlockDeclaration = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .Constructor => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            new_n.Parameters = self.visitNodesInternal(n.Parameters);
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.FullSignature) |v| {
                const res = self.visitNodeInternal(v);
                new_n.FullSignature = if (res == 0) null else res;
            }
            if (n.AsteriskToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.AsteriskToken = if (res == 0) null else res;
            }
            if (n.Body) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Body = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.TypeParameters != n.TypeParameters or new_n.Parameters != n.Parameters or new_n.Type != n.Type or new_n.FullSignature != n.FullSignature or new_n.AsteriskToken != n.AsteriskToken or new_n.Body != n.Body) {
                return self.tree.pushNode(.{ .Constructor = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .GetAccessor => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (n.PostfixToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.PostfixToken = if (res == 0) null else res;
            }
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            new_n.Parameters = self.visitNodesInternal(n.Parameters);
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.FullSignature) |v| {
                const res = self.visitNodeInternal(v);
                new_n.FullSignature = if (res == 0) null else res;
            }
            if (n.AsteriskToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.AsteriskToken = if (res == 0) null else res;
            }
            if (n.Body) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Body = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.name != n.name or new_n.PostfixToken != n.PostfixToken or new_n.TypeParameters != n.TypeParameters or new_n.Parameters != n.Parameters or new_n.Type != n.Type or new_n.FullSignature != n.FullSignature or new_n.AsteriskToken != n.AsteriskToken or new_n.Body != n.Body) {
                return self.tree.pushNode(.{ .GetAccessor = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .SetAccessor => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (n.PostfixToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.PostfixToken = if (res == 0) null else res;
            }
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            new_n.Parameters = self.visitNodesInternal(n.Parameters);
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.FullSignature) |v| {
                const res = self.visitNodeInternal(v);
                new_n.FullSignature = if (res == 0) null else res;
            }
            if (n.AsteriskToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.AsteriskToken = if (res == 0) null else res;
            }
            if (n.Body) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Body = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.name != n.name or new_n.PostfixToken != n.PostfixToken or new_n.TypeParameters != n.TypeParameters or new_n.Parameters != n.Parameters or new_n.Type != n.Type or new_n.FullSignature != n.FullSignature or new_n.AsteriskToken != n.AsteriskToken or new_n.Body != n.Body) {
                return self.tree.pushNode(.{ .SetAccessor = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .CallSignature => |n| {
            var new_n = n;
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            new_n.Parameters = self.visitNodesInternal(n.Parameters);
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.FullSignature) |v| {
                const res = self.visitNodeInternal(v);
                new_n.FullSignature = if (res == 0) null else res;
            }
            if (new_n.TypeParameters != n.TypeParameters or new_n.Parameters != n.Parameters or new_n.Type != n.Type or new_n.FullSignature != n.FullSignature) {
                return self.tree.pushNode(.{ .CallSignature = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ConstructSignature => |n| {
            var new_n = n;
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            new_n.Parameters = self.visitNodesInternal(n.Parameters);
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.FullSignature) |v| {
                const res = self.visitNodeInternal(v);
                new_n.FullSignature = if (res == 0) null else res;
            }
            if (new_n.TypeParameters != n.TypeParameters or new_n.Parameters != n.Parameters or new_n.Type != n.Type or new_n.FullSignature != n.FullSignature) {
                return self.tree.pushNode(.{ .ConstructSignature = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .IndexSignature => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            new_n.Parameters = self.visitNodesInternal(n.Parameters);
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.FullSignature) |v| {
                const res = self.visitNodeInternal(v);
                new_n.FullSignature = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.TypeParameters != n.TypeParameters or new_n.Parameters != n.Parameters or new_n.Type != n.Type or new_n.FullSignature != n.FullSignature) {
                return self.tree.pushNode(.{ .IndexSignature = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .TypePredicate => |n| {
            var new_n = n;
            if (n.AssertsModifier) |v| {
                const res = self.visitNodeInternal(v);
                new_n.AssertsModifier = if (res == 0) null else res;
            }
            new_n.ParameterName = self.visitNodeInternal(n.ParameterName);
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (new_n.AssertsModifier != n.AssertsModifier or new_n.ParameterName != n.ParameterName or new_n.Type != n.Type) {
                return self.tree.pushNode(.{ .TypePredicate = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .TypeReference => |n| {
            var new_n = n;
            if (n.TypeArguments) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeArguments = if (res == 0) null else res;
            }
            new_n.TypeName = self.visitNodeInternal(n.TypeName);
            if (new_n.TypeArguments != n.TypeArguments or new_n.TypeName != n.TypeName) {
                return self.tree.pushNode(.{ .TypeReference = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .FunctionType => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            new_n.Parameters = self.visitNodesInternal(n.Parameters);
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.FullSignature) |v| {
                const res = self.visitNodeInternal(v);
                new_n.FullSignature = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.TypeParameters != n.TypeParameters or new_n.Parameters != n.Parameters or new_n.Type != n.Type or new_n.FullSignature != n.FullSignature) {
                return self.tree.pushNode(.{ .FunctionType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ConstructorType => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            new_n.Parameters = self.visitNodesInternal(n.Parameters);
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.FullSignature) |v| {
                const res = self.visitNodeInternal(v);
                new_n.FullSignature = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.TypeParameters != n.TypeParameters or new_n.Parameters != n.Parameters or new_n.Type != n.Type or new_n.FullSignature != n.FullSignature) {
                return self.tree.pushNode(.{ .ConstructorType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .TypeQuery => |n| {
            var new_n = n;
            if (n.TypeArguments) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeArguments = if (res == 0) null else res;
            }
            new_n.ExprName = self.visitNodeInternal(n.ExprName);
            if (new_n.TypeArguments != n.TypeArguments or new_n.ExprName != n.ExprName) {
                return self.tree.pushNode(.{ .TypeQuery = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .TypeLiteral => |n| {
            var new_n = n;
            new_n.Members = self.visitNodesInternal(n.Members);
            if (new_n.Members != n.Members) {
                return self.tree.pushNode(.{ .TypeLiteral = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ArrayType => |n| {
            var new_n = n;
            new_n.ElementType = self.visitNodeInternal(n.ElementType);
            if (new_n.ElementType != n.ElementType) {
                return self.tree.pushNode(.{ .ArrayType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .TupleType => |n| {
            var new_n = n;
            new_n.Elements = self.visitNodesInternal(n.Elements);
            if (new_n.Elements != n.Elements) {
                return self.tree.pushNode(.{ .TupleType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .OptionalType => |n| {
            var new_n = n;
            new_n.Type = self.visitNodeInternal(n.Type);
            if (new_n.Type != n.Type) {
                return self.tree.pushNode(.{ .OptionalType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .RestType => |n| {
            var new_n = n;
            new_n.Type = self.visitNodeInternal(n.Type);
            if (new_n.Type != n.Type) {
                return self.tree.pushNode(.{ .RestType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .UnionType => |n| {
            var new_n = n;
            new_n.Types = self.visitNodesInternal(n.Types);
            if (new_n.Types != n.Types) {
                return self.tree.pushNode(.{ .UnionType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .IntersectionType => |n| {
            var new_n = n;
            new_n.Types = self.visitNodesInternal(n.Types);
            if (new_n.Types != n.Types) {
                return self.tree.pushNode(.{ .IntersectionType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ConditionalType => |n| {
            var new_n = n;
            new_n.CheckType = self.visitNodeInternal(n.CheckType);
            new_n.ExtendsType = self.visitNodeInternal(n.ExtendsType);
            new_n.TrueType = self.visitNodeInternal(n.TrueType);
            new_n.FalseType = self.visitNodeInternal(n.FalseType);
            if (new_n.CheckType != n.CheckType or new_n.ExtendsType != n.ExtendsType or new_n.TrueType != n.TrueType or new_n.FalseType != n.FalseType) {
                return self.tree.pushNode(.{ .ConditionalType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .InferType => |n| {
            var new_n = n;
            new_n.TypeParameter = self.visitNodeInternal(n.TypeParameter);
            if (new_n.TypeParameter != n.TypeParameter) {
                return self.tree.pushNode(.{ .InferType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ParenthesizedType => |n| {
            var new_n = n;
            new_n.Type = self.visitNodeInternal(n.Type);
            if (new_n.Type != n.Type) {
                return self.tree.pushNode(.{ .ParenthesizedType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .TypeOperator => |n| {
            var new_n = n;
            new_n.Type = self.visitNodeInternal(n.Type);
            if (new_n.Type != n.Type) {
                return self.tree.pushNode(.{ .TypeOperator = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .IndexedAccessType => |n| {
            var new_n = n;
            new_n.ObjectType = self.visitNodeInternal(n.ObjectType);
            new_n.IndexType = self.visitNodeInternal(n.IndexType);
            if (new_n.ObjectType != n.ObjectType or new_n.IndexType != n.IndexType) {
                return self.tree.pushNode(.{ .IndexedAccessType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .MappedType => |n| {
            var new_n = n;
            if (n.ReadonlyToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.ReadonlyToken = if (res == 0) null else res;
            }
            new_n.TypeParameter = self.visitNodeInternal(n.TypeParameter);
            if (n.NameType) |v| {
                const res = self.visitNodeInternal(v);
                new_n.NameType = if (res == 0) null else res;
            }
            if (n.QuestionToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.QuestionToken = if (res == 0) null else res;
            }
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.Members) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Members = if (res == 0) null else res;
            }
            if (new_n.ReadonlyToken != n.ReadonlyToken or new_n.TypeParameter != n.TypeParameter or new_n.NameType != n.NameType or new_n.QuestionToken != n.QuestionToken or new_n.Type != n.Type or new_n.Members != n.Members) {
                return self.tree.pushNode(.{ .MappedType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .LiteralType => |n| {
            var new_n = n;
            new_n.Literal = self.visitNodeInternal(n.Literal);
            if (new_n.Literal != n.Literal) {
                return self.tree.pushNode(.{ .LiteralType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .NamedTupleMember => |n| {
            var new_n = n;
            if (n.DotDotDotToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.DotDotDotToken = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (n.QuestionToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.QuestionToken = if (res == 0) null else res;
            }
            new_n.Type = self.visitNodeInternal(n.Type);
            if (new_n.DotDotDotToken != n.DotDotDotToken or new_n.name != n.name or new_n.QuestionToken != n.QuestionToken or new_n.Type != n.Type) {
                return self.tree.pushNode(.{ .NamedTupleMember = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .TemplateLiteralType => |n| {
            var new_n = n;
            new_n.Head = self.visitNodeInternal(n.Head);
            new_n.TemplateSpans = self.visitNodesInternal(n.TemplateSpans);
            if (new_n.Head != n.Head or new_n.TemplateSpans != n.TemplateSpans) {
                return self.tree.pushNode(.{ .TemplateLiteralType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .TemplateLiteralTypeSpan => |n| {
            var new_n = n;
            new_n.Type = self.visitNodeInternal(n.Type);
            new_n.Literal = self.visitNodeInternal(n.Literal);
            if (new_n.Type != n.Type or new_n.Literal != n.Literal) {
                return self.tree.pushNode(.{ .TemplateLiteralTypeSpan = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ImportType => |n| {
            var new_n = n;
            if (n.TypeArguments) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeArguments = if (res == 0) null else res;
            }
            new_n.Argument = self.visitNodeInternal(n.Argument);
            if (n.Attributes) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Attributes = if (res == 0) null else res;
            }
            if (n.Qualifier) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Qualifier = if (res == 0) null else res;
            }
            if (new_n.TypeArguments != n.TypeArguments or new_n.Argument != n.Argument or new_n.Attributes != n.Attributes or new_n.Qualifier != n.Qualifier) {
                return self.tree.pushNode(.{ .ImportType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ObjectBindingPattern => |n| {
            var new_n = n;
            new_n.Elements = self.visitNodesInternal(n.Elements);
            if (new_n.Elements != n.Elements) {
                return self.tree.pushNode(.{ .ObjectBindingPattern = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ArrayBindingPattern => |n| {
            var new_n = n;
            new_n.Elements = self.visitNodesInternal(n.Elements);
            if (new_n.Elements != n.Elements) {
                return self.tree.pushNode(.{ .ArrayBindingPattern = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .BindingElement => |n| {
            var new_n = n;
            if (n.DotDotDotToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.DotDotDotToken = if (res == 0) null else res;
            }
            if (n.PropertyName) |v| {
                const res = self.visitNodeInternal(v);
                new_n.PropertyName = if (res == 0) null else res;
            }
            if (n.name) |v| {
                const res = self.visitNodeInternal(v);
                new_n.name = if (res == 0) null else res;
            }
            if (n.Initializer) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Initializer = if (res == 0) null else res;
            }
            if (new_n.DotDotDotToken != n.DotDotDotToken or new_n.PropertyName != n.PropertyName or new_n.name != n.name or new_n.Initializer != n.Initializer) {
                return self.tree.pushNode(.{ .BindingElement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ArrayLiteralExpression => |n| {
            var new_n = n;
            new_n.Elements = self.visitNodesInternal(n.Elements);
            if (new_n.Elements != n.Elements) {
                return self.tree.pushNode(.{ .ArrayLiteralExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ObjectLiteralExpression => |n| {
            var new_n = n;
            new_n.Properties = self.visitNodesInternal(n.Properties);
            if (new_n.Properties != n.Properties) {
                return self.tree.pushNode(.{ .ObjectLiteralExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .PropertyAccessExpression => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (n.QuestionDotToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.QuestionDotToken = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (new_n.Expression != n.Expression or new_n.QuestionDotToken != n.QuestionDotToken or new_n.name != n.name) {
                return self.tree.pushNode(.{ .PropertyAccessExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ElementAccessExpression => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (n.QuestionDotToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.QuestionDotToken = if (res == 0) null else res;
            }
            new_n.ArgumentExpression = self.visitNodeInternal(n.ArgumentExpression);
            if (new_n.Expression != n.Expression or new_n.QuestionDotToken != n.QuestionDotToken or new_n.ArgumentExpression != n.ArgumentExpression) {
                return self.tree.pushNode(.{ .ElementAccessExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .CallExpression => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (n.QuestionDotToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.QuestionDotToken = if (res == 0) null else res;
            }
            if (n.TypeArguments) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeArguments = if (res == 0) null else res;
            }
            new_n.Arguments = self.visitNodesInternal(n.Arguments);
            if (new_n.Expression != n.Expression or new_n.QuestionDotToken != n.QuestionDotToken or new_n.TypeArguments != n.TypeArguments or new_n.Arguments != n.Arguments) {
                return self.tree.pushNode(.{ .CallExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .NewExpression => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (n.TypeArguments) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeArguments = if (res == 0) null else res;
            }
            if (n.Arguments) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Arguments = if (res == 0) null else res;
            }
            if (new_n.Expression != n.Expression or new_n.TypeArguments != n.TypeArguments or new_n.Arguments != n.Arguments) {
                return self.tree.pushNode(.{ .NewExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .TaggedTemplateExpression => |n| {
            var new_n = n;
            new_n.Tag = self.visitNodeInternal(n.Tag);
            if (n.QuestionDotToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.QuestionDotToken = if (res == 0) null else res;
            }
            if (n.TypeArguments) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeArguments = if (res == 0) null else res;
            }
            new_n.Template = self.visitNodeInternal(n.Template);
            if (new_n.Tag != n.Tag or new_n.QuestionDotToken != n.QuestionDotToken or new_n.TypeArguments != n.TypeArguments or new_n.Template != n.Template) {
                return self.tree.pushNode(.{ .TaggedTemplateExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .TypeAssertionExpression => |n| {
            var new_n = n;
            new_n.Type = self.visitNodeInternal(n.Type);
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Type != n.Type or new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .TypeAssertionExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ParenthesizedExpression => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .ParenthesizedExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .FunctionExpression => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            new_n.Parameters = self.visitNodesInternal(n.Parameters);
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.FullSignature) |v| {
                const res = self.visitNodeInternal(v);
                new_n.FullSignature = if (res == 0) null else res;
            }
            if (n.AsteriskToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.AsteriskToken = if (res == 0) null else res;
            }
            if (n.Body) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Body = if (res == 0) null else res;
            }
            if (n.name) |v| {
                const res = self.visitNodeInternal(v);
                new_n.name = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.TypeParameters != n.TypeParameters or new_n.Parameters != n.Parameters or new_n.Type != n.Type or new_n.FullSignature != n.FullSignature or new_n.AsteriskToken != n.AsteriskToken or new_n.Body != n.Body or new_n.name != n.name) {
                return self.tree.pushNode(.{ .FunctionExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ArrowFunction => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            new_n.Parameters = self.visitNodesInternal(n.Parameters);
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.FullSignature) |v| {
                const res = self.visitNodeInternal(v);
                new_n.FullSignature = if (res == 0) null else res;
            }
            if (n.AsteriskToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.AsteriskToken = if (res == 0) null else res;
            }
            if (n.Body) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Body = if (res == 0) null else res;
            }
            new_n.EqualsGreaterThanToken = self.visitNodeInternal(n.EqualsGreaterThanToken);
            if (new_n.modifiers != n.modifiers or new_n.TypeParameters != n.TypeParameters or new_n.Parameters != n.Parameters or new_n.Type != n.Type or new_n.FullSignature != n.FullSignature or new_n.AsteriskToken != n.AsteriskToken or new_n.Body != n.Body or new_n.EqualsGreaterThanToken != n.EqualsGreaterThanToken) {
                return self.tree.pushNode(.{ .ArrowFunction = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .DeleteExpression => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .DeleteExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .TypeOfExpression => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .TypeOfExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .VoidExpression => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .VoidExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .AwaitExpression => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .AwaitExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .PrefixUnaryExpression => |n| {
            var new_n = n;
            new_n.Operand = self.visitNodeInternal(n.Operand);
            if (new_n.Operand != n.Operand) {
                return self.tree.pushNode(.{ .PrefixUnaryExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .PostfixUnaryExpression => |n| {
            var new_n = n;
            new_n.Operand = self.visitNodeInternal(n.Operand);
            if (new_n.Operand != n.Operand) {
                return self.tree.pushNode(.{ .PostfixUnaryExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .BinaryExpression => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.Left = self.visitNodeInternal(n.Left);
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            new_n.OperatorToken = self.visitNodeInternal(n.OperatorToken);
            new_n.Right = self.visitNodeInternal(n.Right);
            if (new_n.modifiers != n.modifiers or new_n.Left != n.Left or new_n.Type != n.Type or new_n.OperatorToken != n.OperatorToken or new_n.Right != n.Right) {
                return self.tree.pushNode(.{ .BinaryExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ConditionalExpression => |n| {
            var new_n = n;
            new_n.Condition = self.visitNodeInternal(n.Condition);
            new_n.QuestionToken = self.visitNodeInternal(n.QuestionToken);
            new_n.WhenTrue = self.visitNodeInternal(n.WhenTrue);
            new_n.ColonToken = self.visitNodeInternal(n.ColonToken);
            new_n.WhenFalse = self.visitNodeInternal(n.WhenFalse);
            if (new_n.Condition != n.Condition or new_n.QuestionToken != n.QuestionToken or new_n.WhenTrue != n.WhenTrue or new_n.ColonToken != n.ColonToken or new_n.WhenFalse != n.WhenFalse) {
                return self.tree.pushNode(.{ .ConditionalExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .TemplateExpression => |n| {
            var new_n = n;
            new_n.Head = self.visitNodeInternal(n.Head);
            new_n.TemplateSpans = self.visitNodesInternal(n.TemplateSpans);
            if (new_n.Head != n.Head or new_n.TemplateSpans != n.TemplateSpans) {
                return self.tree.pushNode(.{ .TemplateExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .YieldExpression => |n| {
            var new_n = n;
            if (n.AsteriskToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.AsteriskToken = if (res == 0) null else res;
            }
            if (n.Expression) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Expression = if (res == 0) null else res;
            }
            if (new_n.AsteriskToken != n.AsteriskToken or new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .YieldExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .SpreadElement => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .SpreadElement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ClassExpression => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            if (n.name) |v| {
                const res = self.visitNodeInternal(v);
                new_n.name = if (res == 0) null else res;
            }
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            if (n.HeritageClauses) |v| {
                const res = self.visitNodesInternal(v);
                new_n.HeritageClauses = if (res == 0) null else res;
            }
            new_n.Members = self.visitNodesInternal(n.Members);
            if (new_n.modifiers != n.modifiers or new_n.name != n.name or new_n.TypeParameters != n.TypeParameters or new_n.HeritageClauses != n.HeritageClauses or new_n.Members != n.Members) {
                return self.tree.pushNode(.{ .ClassExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ExpressionWithTypeArguments => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (n.TypeArguments) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeArguments = if (res == 0) null else res;
            }
            if (new_n.Expression != n.Expression or new_n.TypeArguments != n.TypeArguments) {
                return self.tree.pushNode(.{ .ExpressionWithTypeArguments = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .AsExpression => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            new_n.Type = self.visitNodeInternal(n.Type);
            if (new_n.Expression != n.Expression or new_n.Type != n.Type) {
                return self.tree.pushNode(.{ .AsExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .NonNullExpression => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .NonNullExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .MetaProperty => |n| {
            var new_n = n;
            new_n.name = self.visitNodeInternal(n.name);
            if (new_n.name != n.name) {
                return self.tree.pushNode(.{ .MetaProperty = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .SyntheticExpression => |n| {
            var new_n = n;
            new_n.Type = self.visitNodeInternal(n.Type);
            if (n.TupleNameSource) |v| {
                const res = self.visitNodeInternal(v);
                new_n.TupleNameSource = if (res == 0) null else res;
            }
            if (new_n.Type != n.Type or new_n.TupleNameSource != n.TupleNameSource) {
                return self.tree.pushNode(.{ .SyntheticExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .SatisfiesExpression => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            new_n.Type = self.visitNodeInternal(n.Type);
            if (new_n.Expression != n.Expression or new_n.Type != n.Type) {
                return self.tree.pushNode(.{ .SatisfiesExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .TemplateSpan => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            new_n.Literal = self.visitNodeInternal(n.Literal);
            if (new_n.Expression != n.Expression or new_n.Literal != n.Literal) {
                return self.tree.pushNode(.{ .TemplateSpan = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .Block => |n| {
            var new_n = n;
            new_n.Statements = self.visitNodesInternal(n.Statements);
            if (new_n.Statements != n.Statements) {
                return self.tree.pushNode(.{ .Block = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .VariableStatement => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.DeclarationList = self.visitNodeInternal(n.DeclarationList);
            if (new_n.modifiers != n.modifiers or new_n.DeclarationList != n.DeclarationList) {
                return self.tree.pushNode(.{ .VariableStatement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ExpressionStatement => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .ExpressionStatement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .IfStatement => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            new_n.ThenStatement = self.visitEmbeddedStatementInternal(n.ThenStatement);
            if (n.ElseStatement) |v| {
                const res = self.visitEmbeddedStatementInternal(v);
                new_n.ElseStatement = if (res == 0) null else res;
            }
            if (new_n.Expression != n.Expression or new_n.ThenStatement != n.ThenStatement or new_n.ElseStatement != n.ElseStatement) {
                return self.tree.pushNode(.{ .IfStatement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .DoStatement => |n| {
            var new_n = n;
            new_n.Statement = self.visitNodeInternal(n.Statement);
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Statement != n.Statement or new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .DoStatement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .WhileStatement => |n| {
            var new_n = n;
            new_n.Statement = self.visitNodeInternal(n.Statement);
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Statement != n.Statement or new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .WhileStatement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ForStatement => |n| {
            var new_n = n;
            new_n.Statement = self.visitNodeInternal(n.Statement);
            if (n.Initializer) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Initializer = if (res == 0) null else res;
            }
            if (n.Condition) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Condition = if (res == 0) null else res;
            }
            if (n.Incrementor) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Incrementor = if (res == 0) null else res;
            }
            if (new_n.Statement != n.Statement or new_n.Initializer != n.Initializer or new_n.Condition != n.Condition or new_n.Incrementor != n.Incrementor) {
                return self.tree.pushNode(.{ .ForStatement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ForInStatement => |n| {
            var new_n = n;
            if (n.AwaitModifier) |v| {
                const res = self.visitNodeInternal(v);
                new_n.AwaitModifier = if (res == 0) null else res;
            }
            new_n.Initializer = self.visitNodeInternal(n.Initializer);
            new_n.Expression = self.visitNodeInternal(n.Expression);
            new_n.Statement = self.visitIterationBodyInternal(n.Statement);
            if (new_n.AwaitModifier != n.AwaitModifier or new_n.Initializer != n.Initializer or new_n.Expression != n.Expression or new_n.Statement != n.Statement) {
                return self.tree.pushNode(.{ .ForInStatement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ForOfStatement => |n| {
            var new_n = n;
            if (n.AwaitModifier) |v| {
                const res = self.visitNodeInternal(v);
                new_n.AwaitModifier = if (res == 0) null else res;
            }
            new_n.Initializer = self.visitNodeInternal(n.Initializer);
            new_n.Expression = self.visitNodeInternal(n.Expression);
            new_n.Statement = self.visitIterationBodyInternal(n.Statement);
            if (new_n.AwaitModifier != n.AwaitModifier or new_n.Initializer != n.Initializer or new_n.Expression != n.Expression or new_n.Statement != n.Statement) {
                return self.tree.pushNode(.{ .ForOfStatement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ContinueStatement => |n| {
            var new_n = n;
            if (n.Label) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Label = if (res == 0) null else res;
            }
            if (new_n.Label != n.Label) {
                return self.tree.pushNode(.{ .ContinueStatement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .BreakStatement => |n| {
            var new_n = n;
            if (n.Label) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Label = if (res == 0) null else res;
            }
            if (new_n.Label != n.Label) {
                return self.tree.pushNode(.{ .BreakStatement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ReturnStatement => |n| {
            var new_n = n;
            if (n.Expression) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Expression = if (res == 0) null else res;
            }
            if (new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .ReturnStatement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .WithStatement => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            new_n.Statement = self.visitEmbeddedStatementInternal(n.Statement);
            if (new_n.Expression != n.Expression or new_n.Statement != n.Statement) {
                return self.tree.pushNode(.{ .WithStatement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .SwitchStatement => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            new_n.CaseBlock = self.visitNodeInternal(n.CaseBlock);
            if (new_n.Expression != n.Expression or new_n.CaseBlock != n.CaseBlock) {
                return self.tree.pushNode(.{ .SwitchStatement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .LabeledStatement => |n| {
            var new_n = n;
            new_n.Label = self.visitNodeInternal(n.Label);
            new_n.Statement = self.visitEmbeddedStatementInternal(n.Statement);
            if (new_n.Label != n.Label or new_n.Statement != n.Statement) {
                return self.tree.pushNode(.{ .LabeledStatement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ThrowStatement => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .ThrowStatement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .TryStatement => |n| {
            var new_n = n;
            new_n.TryBlock = self.visitNodeInternal(n.TryBlock);
            if (n.CatchClause) |v| {
                const res = self.visitNodeInternal(v);
                new_n.CatchClause = if (res == 0) null else res;
            }
            if (n.FinallyBlock) |v| {
                const res = self.visitNodeInternal(v);
                new_n.FinallyBlock = if (res == 0) null else res;
            }
            if (new_n.TryBlock != n.TryBlock or new_n.CatchClause != n.CatchClause or new_n.FinallyBlock != n.FinallyBlock) {
                return self.tree.pushNode(.{ .TryStatement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .VariableDeclaration => |n| {
            var new_n = n;
            new_n.name = self.visitNodeInternal(n.name);
            if (n.ExclamationToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.ExclamationToken = if (res == 0) null else res;
            }
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.Initializer) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Initializer = if (res == 0) null else res;
            }
            if (new_n.name != n.name or new_n.ExclamationToken != n.ExclamationToken or new_n.Type != n.Type or new_n.Initializer != n.Initializer) {
                return self.tree.pushNode(.{ .VariableDeclaration = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .VariableDeclarationList => |n| {
            var new_n = n;
            new_n.Declarations = self.visitNodesInternal(n.Declarations);
            if (new_n.Declarations != n.Declarations) {
                return self.tree.pushNode(.{ .VariableDeclarationList = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .FunctionDeclaration => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            new_n.Parameters = self.visitNodesInternal(n.Parameters);
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.FullSignature) |v| {
                const res = self.visitNodeInternal(v);
                new_n.FullSignature = if (res == 0) null else res;
            }
            if (n.AsteriskToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.AsteriskToken = if (res == 0) null else res;
            }
            if (n.Body) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Body = if (res == 0) null else res;
            }
            if (n.name) |v| {
                const res = self.visitNodeInternal(v);
                new_n.name = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.TypeParameters != n.TypeParameters or new_n.Parameters != n.Parameters or new_n.Type != n.Type or new_n.FullSignature != n.FullSignature or new_n.AsteriskToken != n.AsteriskToken or new_n.Body != n.Body or new_n.name != n.name) {
                return self.tree.pushNode(.{ .FunctionDeclaration = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ClassDeclaration => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            if (n.name) |v| {
                const res = self.visitNodeInternal(v);
                new_n.name = if (res == 0) null else res;
            }
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            if (n.HeritageClauses) |v| {
                const res = self.visitNodesInternal(v);
                new_n.HeritageClauses = if (res == 0) null else res;
            }
            new_n.Members = self.visitNodesInternal(n.Members);
            if (new_n.modifiers != n.modifiers or new_n.name != n.name or new_n.TypeParameters != n.TypeParameters or new_n.HeritageClauses != n.HeritageClauses or new_n.Members != n.Members) {
                return self.tree.pushNode(.{ .ClassDeclaration = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .InterfaceDeclaration => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            if (n.HeritageClauses) |v| {
                const res = self.visitNodesInternal(v);
                new_n.HeritageClauses = if (res == 0) null else res;
            }
            new_n.Members = self.visitNodesInternal(n.Members);
            if (new_n.modifiers != n.modifiers or new_n.name != n.name or new_n.TypeParameters != n.TypeParameters or new_n.HeritageClauses != n.HeritageClauses or new_n.Members != n.Members) {
                return self.tree.pushNode(.{ .InterfaceDeclaration = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .TypeAliasDeclaration => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            new_n.Type = self.visitNodeInternal(n.Type);
            if (new_n.modifiers != n.modifiers or new_n.name != n.name or new_n.TypeParameters != n.TypeParameters or new_n.Type != n.Type) {
                return self.tree.pushNode(.{ .TypeAliasDeclaration = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .EnumDeclaration => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            new_n.Members = self.visitNodesInternal(n.Members);
            if (new_n.modifiers != n.modifiers or new_n.name != n.name or new_n.Members != n.Members) {
                return self.tree.pushNode(.{ .EnumDeclaration = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ModuleDeclaration => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            if (n.AsteriskToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.AsteriskToken = if (res == 0) null else res;
            }
            if (n.Body) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Body = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (new_n.modifiers != n.modifiers or new_n.AsteriskToken != n.AsteriskToken or new_n.Body != n.Body or new_n.name != n.name) {
                return self.tree.pushNode(.{ .ModuleDeclaration = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ModuleBlock => |n| {
            var new_n = n;
            new_n.Statements = self.visitNodesInternal(n.Statements);
            if (new_n.Statements != n.Statements) {
                return self.tree.pushNode(.{ .ModuleBlock = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .CaseBlock => |n| {
            var new_n = n;
            new_n.Clauses = self.visitNodesInternal(n.Clauses);
            if (new_n.Clauses != n.Clauses) {
                return self.tree.pushNode(.{ .CaseBlock = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .NamespaceExportDeclaration => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (new_n.modifiers != n.modifiers or new_n.name != n.name) {
                return self.tree.pushNode(.{ .NamespaceExportDeclaration = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ImportEqualsDeclaration => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            new_n.ModuleReference = self.visitNodeInternal(n.ModuleReference);
            if (new_n.modifiers != n.modifiers or new_n.name != n.name or new_n.ModuleReference != n.ModuleReference) {
                return self.tree.pushNode(.{ .ImportEqualsDeclaration = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ImportDeclaration => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            if (n.ImportClause) |v| {
                const res = self.visitNodeInternal(v);
                new_n.ImportClause = if (res == 0) null else res;
            }
            new_n.ModuleSpecifier = self.visitNodeInternal(n.ModuleSpecifier);
            if (n.Attributes) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Attributes = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.ImportClause != n.ImportClause or new_n.ModuleSpecifier != n.ModuleSpecifier or new_n.Attributes != n.Attributes) {
                return self.tree.pushNode(.{ .ImportDeclaration = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ImportClause => |n| {
            var new_n = n;
            if (n.name) |v| {
                const res = self.visitNodeInternal(v);
                new_n.name = if (res == 0) null else res;
            }
            if (n.NamedBindings) |v| {
                const res = self.visitNodeInternal(v);
                new_n.NamedBindings = if (res == 0) null else res;
            }
            if (new_n.name != n.name or new_n.NamedBindings != n.NamedBindings) {
                return self.tree.pushNode(.{ .ImportClause = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .NamespaceImport => |n| {
            var new_n = n;
            new_n.name = self.visitNodeInternal(n.name);
            if (new_n.name != n.name) {
                return self.tree.pushNode(.{ .NamespaceImport = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .NamedImports => |n| {
            var new_n = n;
            new_n.Elements = self.visitNodesInternal(n.Elements);
            if (new_n.Elements != n.Elements) {
                return self.tree.pushNode(.{ .NamedImports = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ImportSpecifier => |n| {
            var new_n = n;
            if (n.PropertyName) |v| {
                const res = self.visitNodeInternal(v);
                new_n.PropertyName = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (new_n.PropertyName != n.PropertyName or new_n.name != n.name) {
                return self.tree.pushNode(.{ .ImportSpecifier = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ExportAssignment => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.Type = self.visitNodeInternal(n.Type);
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.modifiers != n.modifiers or new_n.Type != n.Type or new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .ExportAssignment = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ExportDeclaration => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            if (n.ExportClause) |v| {
                const res = self.visitNodeInternal(v);
                new_n.ExportClause = if (res == 0) null else res;
            }
            if (n.ModuleSpecifier) |v| {
                const res = self.visitNodeInternal(v);
                new_n.ModuleSpecifier = if (res == 0) null else res;
            }
            if (n.Attributes) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Attributes = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.ExportClause != n.ExportClause or new_n.ModuleSpecifier != n.ModuleSpecifier or new_n.Attributes != n.Attributes) {
                return self.tree.pushNode(.{ .ExportDeclaration = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .NamedExports => |n| {
            var new_n = n;
            new_n.Elements = self.visitNodesInternal(n.Elements);
            if (new_n.Elements != n.Elements) {
                return self.tree.pushNode(.{ .NamedExports = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .NamespaceExport => |n| {
            var new_n = n;
            new_n.name = self.visitNodeInternal(n.name);
            if (new_n.name != n.name) {
                return self.tree.pushNode(.{ .NamespaceExport = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ExportSpecifier => |n| {
            var new_n = n;
            if (n.PropertyName) |v| {
                const res = self.visitNodeInternal(v);
                new_n.PropertyName = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (new_n.PropertyName != n.PropertyName or new_n.name != n.name) {
                return self.tree.pushNode(.{ .ExportSpecifier = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .MissingDeclaration => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers) {
                return self.tree.pushNode(.{ .MissingDeclaration = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ExternalModuleReference => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .ExternalModuleReference = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JsxElement => |n| {
            var new_n = n;
            new_n.OpeningElement = self.visitNodeInternal(n.OpeningElement);
            new_n.Children = self.visitNodesInternal(n.Children);
            new_n.ClosingElement = self.visitNodeInternal(n.ClosingElement);
            if (new_n.OpeningElement != n.OpeningElement or new_n.Children != n.Children or new_n.ClosingElement != n.ClosingElement) {
                return self.tree.pushNode(.{ .JsxElement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JsxSelfClosingElement => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.TypeArguments) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeArguments = if (res == 0) null else res;
            }
            new_n.Attributes = self.visitNodeInternal(n.Attributes);
            if (new_n.TagName != n.TagName or new_n.TypeArguments != n.TypeArguments or new_n.Attributes != n.Attributes) {
                return self.tree.pushNode(.{ .JsxSelfClosingElement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JsxOpeningElement => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.TypeArguments) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeArguments = if (res == 0) null else res;
            }
            new_n.Attributes = self.visitNodeInternal(n.Attributes);
            if (new_n.TagName != n.TagName or new_n.TypeArguments != n.TypeArguments or new_n.Attributes != n.Attributes) {
                return self.tree.pushNode(.{ .JsxOpeningElement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JsxClosingElement => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (new_n.TagName != n.TagName) {
                return self.tree.pushNode(.{ .JsxClosingElement = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JsxFragment => |n| {
            var new_n = n;
            new_n.OpeningFragment = self.visitNodeInternal(n.OpeningFragment);
            new_n.Children = self.visitNodesInternal(n.Children);
            new_n.ClosingFragment = self.visitNodeInternal(n.ClosingFragment);
            if (new_n.OpeningFragment != n.OpeningFragment or new_n.Children != n.Children or new_n.ClosingFragment != n.ClosingFragment) {
                return self.tree.pushNode(.{ .JsxFragment = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JsxAttribute => |n| {
            var new_n = n;
            new_n.name = self.visitNodeInternal(n.name);
            if (n.Initializer) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Initializer = if (res == 0) null else res;
            }
            if (new_n.name != n.name or new_n.Initializer != n.Initializer) {
                return self.tree.pushNode(.{ .JsxAttribute = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JsxAttributes => |n| {
            var new_n = n;
            new_n.Properties = self.visitNodesInternal(n.Properties);
            if (new_n.Properties != n.Properties) {
                return self.tree.pushNode(.{ .JsxAttributes = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JsxSpreadAttribute => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .JsxSpreadAttribute = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JsxExpression => |n| {
            var new_n = n;
            if (n.DotDotDotToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.DotDotDotToken = if (res == 0) null else res;
            }
            if (n.Expression) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Expression = if (res == 0) null else res;
            }
            if (new_n.DotDotDotToken != n.DotDotDotToken or new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .JsxExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JsxNamespacedName => |n| {
            var new_n = n;
            new_n.Namespace = self.visitNodeInternal(n.Namespace);
            new_n.name = self.visitNodeInternal(n.name);
            if (new_n.Namespace != n.Namespace or new_n.name != n.name) {
                return self.tree.pushNode(.{ .JsxNamespacedName = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .CaseClause => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            new_n.Statements = self.visitNodesInternal(n.Statements);
            if (new_n.Expression != n.Expression or new_n.Statements != n.Statements) {
                return self.tree.pushNode(.{ .CaseClause = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .DefaultClause => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            new_n.Statements = self.visitNodesInternal(n.Statements);
            if (new_n.Expression != n.Expression or new_n.Statements != n.Statements) {
                return self.tree.pushNode(.{ .DefaultClause = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .HeritageClause => |n| {
            var new_n = n;
            new_n.Types = self.visitNodesInternal(n.Types);
            if (new_n.Types != n.Types) {
                return self.tree.pushNode(.{ .HeritageClause = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .CatchClause => |n| {
            var new_n = n;
            if (n.VariableDeclaration) |v| {
                const res = self.visitNodeInternal(v);
                new_n.VariableDeclaration = if (res == 0) null else res;
            }
            new_n.Block = self.visitNodeInternal(n.Block);
            if (new_n.VariableDeclaration != n.VariableDeclaration or new_n.Block != n.Block) {
                return self.tree.pushNode(.{ .CatchClause = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ImportAttributes => |n| {
            var new_n = n;
            new_n.Attributes = self.visitNodesInternal(n.Attributes);
            if (new_n.Attributes != n.Attributes) {
                return self.tree.pushNode(.{ .ImportAttributes = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ImportAttribute => |n| {
            var new_n = n;
            new_n.name = self.visitNodeInternal(n.name);
            new_n.Value = self.visitNodeInternal(n.Value);
            if (new_n.name != n.name or new_n.Value != n.Value) {
                return self.tree.pushNode(.{ .ImportAttribute = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .PropertyAssignment => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (n.PostfixToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.PostfixToken = if (res == 0) null else res;
            }
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            new_n.Initializer = self.visitNodeInternal(n.Initializer);
            if (new_n.modifiers != n.modifiers or new_n.name != n.name or new_n.PostfixToken != n.PostfixToken or new_n.Type != n.Type or new_n.Initializer != n.Initializer) {
                return self.tree.pushNode(.{ .PropertyAssignment = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .ShorthandPropertyAssignment => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (n.PostfixToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.PostfixToken = if (res == 0) null else res;
            }
            new_n.Type = self.visitNodeInternal(n.Type);
            if (n.EqualsToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.EqualsToken = if (res == 0) null else res;
            }
            if (n.ObjectAssignmentInitializer) |v| {
                const res = self.visitNodeInternal(v);
                new_n.ObjectAssignmentInitializer = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.name != n.name or new_n.PostfixToken != n.PostfixToken or new_n.Type != n.Type or new_n.EqualsToken != n.EqualsToken or new_n.ObjectAssignmentInitializer != n.ObjectAssignmentInitializer) {
                return self.tree.pushNode(.{ .ShorthandPropertyAssignment = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .SpreadAssignment => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .SpreadAssignment = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .EnumMember => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (n.PostfixToken) |v| {
                const res = self.visitNodeInternal(v);
                new_n.PostfixToken = if (res == 0) null else res;
            }
            if (n.Initializer) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Initializer = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.name != n.name or new_n.PostfixToken != n.PostfixToken or new_n.Initializer != n.Initializer) {
                return self.tree.pushNode(.{ .EnumMember = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .SourceFile => |n| {
            var new_n = n;
            new_n.Statements = self.visitNodesInternal(n.Statements);
            new_n.EndOfFileToken = self.visitNodeInternal(n.EndOfFileToken);
            if (new_n.Statements != n.Statements or new_n.EndOfFileToken != n.EndOfFileToken) {
                return self.tree.pushNode(.{ .SourceFile = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocTypeExpression => |n| {
            var new_n = n;
            new_n.Type = self.visitNodeInternal(n.Type);
            if (new_n.Type != n.Type) {
                return self.tree.pushNode(.{ .JSDocTypeExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocNameReference => |n| {
            var new_n = n;
            new_n.name = self.visitNodeInternal(n.name);
            if (new_n.name != n.name) {
                return self.tree.pushNode(.{ .JSDocNameReference = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocNullableType => |n| {
            var new_n = n;
            new_n.Type = self.visitNodeInternal(n.Type);
            if (new_n.Type != n.Type) {
                return self.tree.pushNode(.{ .JSDocNullableType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocNonNullableType => |n| {
            var new_n = n;
            new_n.Type = self.visitNodeInternal(n.Type);
            if (new_n.Type != n.Type) {
                return self.tree.pushNode(.{ .JSDocNonNullableType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocOptionalType => |n| {
            var new_n = n;
            new_n.Type = self.visitNodeInternal(n.Type);
            if (new_n.Type != n.Type) {
                return self.tree.pushNode(.{ .JSDocOptionalType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocVariadicType => |n| {
            var new_n = n;
            new_n.Type = self.visitNodeInternal(n.Type);
            if (new_n.Type != n.Type) {
                return self.tree.pushNode(.{ .JSDocVariadicType = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDoc => |n| {
            var new_n = n;
            new_n.Comment = self.visitNodesInternal(n.Comment);
            if (n.Tags) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Tags = if (res == 0) null else res;
            }
            if (new_n.Comment != n.Comment or new_n.Tags != n.Tags) {
                return self.tree.pushNode(.{ .JSDoc = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocTypeLiteral => |n| {
            var new_n = n;
            if (n.JSDocPropertyTags) |v| {
                const res = self.visitNodesInternal(v);
                new_n.JSDocPropertyTags = if (res == 0) null else res;
            }
            if (new_n.JSDocPropertyTags != n.JSDocPropertyTags) {
                return self.tree.pushNode(.{ .JSDocTypeLiteral = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocSignature => |n| {
            var new_n = n;
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            new_n.Parameters = self.visitNodesInternal(n.Parameters);
            if (n.Type) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Type = if (res == 0) null else res;
            }
            if (n.FullSignature) |v| {
                const res = self.visitNodeInternal(v);
                new_n.FullSignature = if (res == 0) null else res;
            }
            if (new_n.TypeParameters != n.TypeParameters or new_n.Parameters != n.Parameters or new_n.Type != n.Type or new_n.FullSignature != n.FullSignature) {
                return self.tree.pushNode(.{ .JSDocSignature = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocLink => |n| {
            var new_n = n;
            if (n.name) |v| {
                const res = self.visitNodeInternal(v);
                new_n.name = if (res == 0) null else res;
            }
            if (new_n.name != n.name) {
                return self.tree.pushNode(.{ .JSDocLink = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocLinkCode => |n| {
            var new_n = n;
            if (n.name) |v| {
                const res = self.visitNodeInternal(v);
                new_n.name = if (res == 0) null else res;
            }
            if (new_n.name != n.name) {
                return self.tree.pushNode(.{ .JSDocLinkCode = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocLinkPlain => |n| {
            var new_n = n;
            if (n.name) |v| {
                const res = self.visitNodeInternal(v);
                new_n.name = if (res == 0) null else res;
            }
            if (new_n.name != n.name) {
                return self.tree.pushNode(.{ .JSDocLinkPlain = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocUnknownTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment) {
                return self.tree.pushNode(.{ .JSDocUnknownTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocAugmentsTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            new_n.ClassName = self.visitNodeInternal(n.ClassName);
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment or new_n.ClassName != n.ClassName) {
                return self.tree.pushNode(.{ .JSDocAugmentsTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocImplementsTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            new_n.ClassName = self.visitNodeInternal(n.ClassName);
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment or new_n.ClassName != n.ClassName) {
                return self.tree.pushNode(.{ .JSDocImplementsTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocDeprecatedTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment) {
                return self.tree.pushNode(.{ .JSDocDeprecatedTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocPublicTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment) {
                return self.tree.pushNode(.{ .JSDocPublicTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocPrivateTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment) {
                return self.tree.pushNode(.{ .JSDocPrivateTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocProtectedTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment) {
                return self.tree.pushNode(.{ .JSDocProtectedTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocReadonlyTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment) {
                return self.tree.pushNode(.{ .JSDocReadonlyTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocOverrideTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment) {
                return self.tree.pushNode(.{ .JSDocOverrideTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocCallbackTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            new_n.TypeExpression = self.visitNodeInternal(n.TypeExpression);
            if (n.name) |v| {
                const res = self.visitNodeInternal(v);
                new_n.name = if (res == 0) null else res;
            }
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment or new_n.TypeExpression != n.TypeExpression or new_n.name != n.name) {
                return self.tree.pushNode(.{ .JSDocCallbackTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocOverloadTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            new_n.TypeExpression = self.visitNodeInternal(n.TypeExpression);
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment or new_n.TypeExpression != n.TypeExpression) {
                return self.tree.pushNode(.{ .JSDocOverloadTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocReturnTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            if (n.TypeExpression) |v| {
                const res = self.visitNodeInternal(v);
                new_n.TypeExpression = if (res == 0) null else res;
            }
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment or new_n.TypeExpression != n.TypeExpression) {
                return self.tree.pushNode(.{ .JSDocReturnTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocThisTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            new_n.TypeExpression = self.visitNodeInternal(n.TypeExpression);
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment or new_n.TypeExpression != n.TypeExpression) {
                return self.tree.pushNode(.{ .JSDocThisTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocTypeTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            new_n.TypeExpression = self.visitNodeInternal(n.TypeExpression);
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment or new_n.TypeExpression != n.TypeExpression) {
                return self.tree.pushNode(.{ .JSDocTypeTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocTemplateTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            new_n.Constraint = self.visitNodeInternal(n.Constraint);
            new_n.TypeParameters = self.visitNodesInternal(n.TypeParameters);
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment or new_n.Constraint != n.Constraint or new_n.TypeParameters != n.TypeParameters) {
                return self.tree.pushNode(.{ .JSDocTemplateTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocTypedefTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            if (n.TypeExpression) |v| {
                const res = self.visitNodeInternal(v);
                new_n.TypeExpression = if (res == 0) null else res;
            }
            if (n.name) |v| {
                const res = self.visitNodeInternal(v);
                new_n.name = if (res == 0) null else res;
            }
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment or new_n.TypeExpression != n.TypeExpression or new_n.name != n.name) {
                return self.tree.pushNode(.{ .JSDocTypedefTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocSeeTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            new_n.NameExpression = self.visitNodeInternal(n.NameExpression);
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment or new_n.NameExpression != n.NameExpression) {
                return self.tree.pushNode(.{ .JSDocSeeTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocThrowsTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            if (n.TypeExpression) |v| {
                const res = self.visitNodeInternal(v);
                new_n.TypeExpression = if (res == 0) null else res;
            }
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment or new_n.TypeExpression != n.TypeExpression) {
                return self.tree.pushNode(.{ .JSDocThrowsTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocSatisfiesTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            new_n.TypeExpression = self.visitNodeInternal(n.TypeExpression);
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment or new_n.TypeExpression != n.TypeExpression) {
                return self.tree.pushNode(.{ .JSDocSatisfiesTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSDocImportTag => |n| {
            var new_n = n;
            new_n.TagName = self.visitNodeInternal(n.TagName);
            if (n.Comment) |v| {
                const res = self.visitNodesInternal(v);
                new_n.Comment = if (res == 0) null else res;
            }
            if (n.ImportClause) |v| {
                const res = self.visitNodeInternal(v);
                new_n.ImportClause = if (res == 0) null else res;
            }
            new_n.ModuleSpecifier = self.visitNodeInternal(n.ModuleSpecifier);
            if (n.Attributes) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Attributes = if (res == 0) null else res;
            }
            if (new_n.TagName != n.TagName or new_n.Comment != n.Comment or new_n.ImportClause != n.ImportClause or new_n.ModuleSpecifier != n.ModuleSpecifier or new_n.Attributes != n.Attributes) {
                return self.tree.pushNode(.{ .JSDocImportTag = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .SyntaxList => |n| {
            var new_n = n;
            new_n.Children = self.visitNodesInternal(n.Children);
            if (new_n.Children != n.Children) {
                return self.tree.pushNode(.{ .SyntaxList = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSTypeAliasDeclaration => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            new_n.name = self.visitNodeInternal(n.name);
            if (n.TypeParameters) |v| {
                const res = self.visitNodesInternal(v);
                new_n.TypeParameters = if (res == 0) null else res;
            }
            new_n.Type = self.visitNodeInternal(n.Type);
            if (new_n.modifiers != n.modifiers or new_n.name != n.name or new_n.TypeParameters != n.TypeParameters or new_n.Type != n.Type) {
                return self.tree.pushNode(.{ .JSTypeAliasDeclaration = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .JSImportDeclaration => |n| {
            var new_n = n;
            if (n.modifiers) |v| {
                const res = self.visitModifiersInternal(v);
                new_n.modifiers = if (res == 0) null else res;
            }
            if (n.ImportClause) |v| {
                const res = self.visitNodeInternal(v);
                new_n.ImportClause = if (res == 0) null else res;
            }
            new_n.ModuleSpecifier = self.visitNodeInternal(n.ModuleSpecifier);
            if (n.Attributes) |v| {
                const res = self.visitNodeInternal(v);
                new_n.Attributes = if (res == 0) null else res;
            }
            if (new_n.modifiers != n.modifiers or new_n.ImportClause != n.ImportClause or new_n.ModuleSpecifier != n.ModuleSpecifier or new_n.Attributes != n.Attributes) {
                return self.tree.pushNode(.{ .JSImportDeclaration = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .PartiallyEmittedExpression => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            if (new_n.Expression != n.Expression) {
                return self.tree.pushNode(.{ .PartiallyEmittedExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        .SyntheticReferenceExpression => |n| {
            var new_n = n;
            new_n.Expression = self.visitNodeInternal(n.Expression);
            new_n.ThisArg = self.visitNodeInternal(n.ThisArg);
            if (new_n.Expression != n.Expression or new_n.ThisArg != n.ThisArg) {
                return self.tree.pushNode(.{ .SyntheticReferenceExpression = new_n }) catch unreachable;
            }
            return nodeIndex;
        },
        else => return nodeIndex,
    }
}
