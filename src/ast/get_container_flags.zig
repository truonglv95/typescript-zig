const ast_utils = @import("ast_utils.zig");
const kind = @import("kind.zig");
const ast_pkg = @import("ast.zig");
const ast_gen = @import("ast_generated.zig");

pub fn isObjectLiteralOrClassExpressionMethodOrAccessor(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .MethodDeclaration, .GetAccessor, .SetAccessor => {
            const parentIndex = tree.getNodeParent(nodeIndex);
            if (parentIndex != 0) {
                const parentNode = tree.getNode(parentIndex);
                if (parentNode == .ObjectLiteralExpression or parentNode == .ClassExpression) {
                    return true;
                }
            }
        },
        else => {},
    }
    return false;
}

pub fn getContainerFlags(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) u32 {
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .ClassExpression, .ClassDeclaration, .EnumDeclaration, .ObjectLiteralExpression, .TypeLiteral, .JsxAttributes => {
            return ast_utils.ContainerFlags.IsContainer;
        },
        .InterfaceDeclaration => {
            return ast_utils.ContainerFlags.IsContainer | ast_utils.ContainerFlags.IsInterface;
        },
        .ModuleDeclaration, .TypeAliasDeclaration, .JSTypeAliasDeclaration, .MappedType, .IndexSignature => {
            return ast_utils.ContainerFlags.IsContainer | ast_utils.ContainerFlags.HasLocals;
        },
        .SourceFile => {
            return ast_utils.ContainerFlags.IsContainer | ast_utils.ContainerFlags.IsControlFlowContainer | ast_utils.ContainerFlags.HasLocals;
        },
        .GetAccessor, .SetAccessor, .MethodDeclaration => {
            if (isObjectLiteralOrClassExpressionMethodOrAccessor(tree, nodeIndex)) {
                return ast_utils.ContainerFlags.IsContainer | ast_utils.ContainerFlags.IsControlFlowContainer | ast_utils.ContainerFlags.HasLocals | ast_utils.ContainerFlags.IsFunctionLike | ast_utils.ContainerFlags.IsObjectLiteralOrClassExpressionMethodOrAccessor | ast_utils.ContainerFlags.IsThisContainer;
            }
            return ast_utils.ContainerFlags.IsContainer | ast_utils.ContainerFlags.IsControlFlowContainer | ast_utils.ContainerFlags.HasLocals | ast_utils.ContainerFlags.IsFunctionLike | ast_utils.ContainerFlags.IsThisContainer;
        },
        .Constructor, .FunctionDeclaration, .ClassStaticBlockDeclaration => {
            return ast_utils.ContainerFlags.IsContainer | ast_utils.ContainerFlags.IsControlFlowContainer | ast_utils.ContainerFlags.HasLocals | ast_utils.ContainerFlags.IsFunctionLike | ast_utils.ContainerFlags.IsThisContainer;
        },
        .MethodSignature, .CallSignature, .FunctionType, .ConstructSignature, .ConstructorType => {
            return ast_utils.ContainerFlags.IsContainer | ast_utils.ContainerFlags.IsControlFlowContainer | ast_utils.ContainerFlags.HasLocals | ast_utils.ContainerFlags.IsFunctionLike | ast_utils.ContainerFlags.PropagatesThisKeyword;
        },
        .FunctionExpression => {
            return ast_utils.ContainerFlags.IsContainer | ast_utils.ContainerFlags.IsControlFlowContainer | ast_utils.ContainerFlags.HasLocals | ast_utils.ContainerFlags.IsFunctionLike | ast_utils.ContainerFlags.IsFunctionExpression | ast_utils.ContainerFlags.IsThisContainer;
        },
        .ArrowFunction => {
            return ast_utils.ContainerFlags.IsContainer | ast_utils.ContainerFlags.IsControlFlowContainer | ast_utils.ContainerFlags.HasLocals | ast_utils.ContainerFlags.IsFunctionLike | ast_utils.ContainerFlags.IsFunctionExpression | ast_utils.ContainerFlags.PropagatesThisKeyword;
        },
        .ModuleBlock => {
            return ast_utils.ContainerFlags.IsControlFlowContainer;
        },
        .PropertyDeclaration => |n| {
            if (n.Initializer != 0) {
                return ast_utils.ContainerFlags.IsControlFlowContainer | ast_utils.ContainerFlags.IsThisContainer;
            } else {
                return ast_utils.ContainerFlags.None;
            }
        },
        .CatchClause, .ForStatement, .ForInStatement, .ForOfStatement, .CaseBlock => {
            return ast_utils.ContainerFlags.IsBlockScopedContainer | ast_utils.ContainerFlags.HasLocals;
        },
        .Block => {
            const parentIndex = tree.getNodeParent(nodeIndex);
            if (parentIndex != 0) {
                const parentNode = tree.getNode(parentIndex);
                if (ast_utils.isFunctionLike(parentNode) or parentNode == .ClassStaticBlockDeclaration) {
                    return ast_utils.ContainerFlags.None;
                }
            }
            return ast_utils.ContainerFlags.IsBlockScopedContainer | ast_utils.ContainerFlags.HasLocals;
        },
        else => return ast_utils.ContainerFlags.None,
    }
}
