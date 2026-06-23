pub fn getContainerFlags(nodeType: ast_gen.SyntaxKind) u32 {
    switch (nodeType) {
        .ClassExpression, .ClassDeclaration, .EnumDeclaration, .ObjectLiteralExpression, .TypeLiteral, .JsxAttributes => {
            return 1; // IsContainer
        },
        .InterfaceDeclaration => {
            return 1 | 64; // IsContainer | IsInterface
        },
        .ModuleDeclaration, .TypeAliasDeclaration, .JSDocTypeAlias, .MappedType, .IndexSignature => {
            return 1 | 32; // IsContainer | HasLocals
        },
        .SourceFile => {
            return 1 | 4 | 32; // IsContainer | IsControlFlowContainer | HasLocals
        },
        .GetAccessor, .SetAccessor, .MethodDeclaration => {
            // Need to know if IsObjectLiteralOrClassExpressionMethodOrAccessor but let's assume no for now
            return 1 | 4 | 32 | 8 | 256; // IsContainer | IsControlFlowContainer | HasLocals | IsFunctionLike | IsThisContainer
        },
        .Constructor, .FunctionDeclaration => { // ClassStaticBlockDeclaration
            return 1 | 4 | 32 | 8 | 256;
        },
        .MethodSignature, .CallSignature, .FunctionType, .ConstructSignature, .ConstructorType => {
            return 1 | 4 | 32 | 8 | 512; // ... | PropagatesThisKeyword
        },
        .FunctionExpression => {
            return 1 | 4 | 32 | 8 | 16 | 256; // IsFunctionExpression
        },
        .ArrowFunction => {
            return 1 | 4 | 32 | 8 | 16 | 512;
        },
        .ModuleBlock => {
            return 4; // IsControlFlowContainer
        },
        .PropertyDeclaration => {
            // Need nodeInitializer check, let's assume false
            return 0;
        },
        .CatchClause, .ForStatement, .ForInStatement, .ForOfStatement, .CaseBlock => {
            return 2 | 32; // IsBlockScopedContainer | HasLocals
        },
        .Block => {
            // Need parent check, let's assume IsBlockScopedContainer
            return 2 | 32;
        },
        else => return 0,
    }
}
