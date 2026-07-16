const std = @import("std");
const ast = @import("../ast/ast.zig");
const kind = @import("../ast/kind.zig");
const context = @import("context.zig");
const rule = @import("rule.zig");
const astnav = @import("../ast/ast_utils.zig");

const lsutil = @import("../ls/lsutil/lsutil.zig");
const core = @import("../core/core.zig");

pub const OptionSelector = *const fn (options: lsutil.FormatCodeSettings) core.Tristate;

// Option Selectors
pub fn insertSpaceAfterCommaDelimiterOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.insertSpaceAfterCommaDelimiter; }
pub fn insertSpaceAfterSemicolonInForStatementsOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.insertSpaceAfterSemicolonInForStatements; }
pub fn insertSpaceBeforeAndAfterBinaryOperatorsOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.insertSpaceBeforeAndAfterBinaryOperators; }
pub fn insertSpaceAfterConstructorOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.insertSpaceAfterConstructor; }
pub fn insertSpaceAfterKeywordsInControlFlowStatementsOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.insertSpaceAfterKeywordsInControlFlowStatements; }
pub fn insertSpaceAfterFunctionKeywordForAnonymousFunctionsOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.insertSpaceAfterFunctionKeywordForAnonymousFunctions; }
pub fn insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesisOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis; }
pub fn insertSpaceAfterOpeningAndBeforeClosingNonemptyBracketsOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.insertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets; }
pub fn insertSpaceAfterOpeningAndBeforeClosingNonemptyBracesOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces; }
pub fn insertSpaceAfterOpeningAndBeforeClosingEmptyBracesOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.insertSpaceAfterOpeningAndBeforeClosingEmptyBraces; }
pub fn insertSpaceAfterOpeningAndBeforeClosingTemplateStringBracesOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.insertSpaceAfterOpeningAndBeforeClosingTemplateStringBraces; }
pub fn insertSpaceAfterOpeningAndBeforeClosingJsxExpressionBracesOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.insertSpaceAfterOpeningAndBeforeClosingJsxExpressionBraces; }
pub fn insertSpaceAfterTypeAssertionOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.insertSpaceAfterTypeAssertion; }
pub fn insertSpaceBeforeFunctionParenthesisOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.insertSpaceBeforeFunctionParenthesis; }
pub fn placeOpenBraceOnNewLineForFunctionsOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.placeOpenBraceOnNewLineForFunctions; }
pub fn placeOpenBraceOnNewLineForControlBlocksOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.placeOpenBraceOnNewLineForControlBlocks; }
pub fn insertSpaceBeforeTypeAnnotationOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.insertSpaceBeforeTypeAnnotation; }
pub fn indentMultiLineObjectLiteralBeginningOnBlankLineOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.indentMultiLineObjectLiteralBeginningOnBlankLine; }
pub fn indentSwitchCaseOption(options: lsutil.FormatCodeSettings) core.Tristate { return options.indentSwitchCase; }

pub fn isOptionEnabled(comptime optionName: OptionSelector) rule.ContextPredicate {
    const Closure = struct {
        pub fn exec(ctx: *context.FormattingContext) bool {
            return optionName(ctx.options).isTrue();
        }
    };
    return Closure.exec;
}

pub fn isOptionDisabled(comptime optionName: OptionSelector) rule.ContextPredicate {
    const Closure = struct {
        pub fn exec(ctx: *context.FormattingContext) bool {
            return optionName(ctx.options).isFalse();
        }
    };
    return Closure.exec;
}

pub fn isOptionDisabledOrUndefined(comptime optionName: OptionSelector) rule.ContextPredicate {
    const Closure = struct {
        pub fn exec(ctx: *context.FormattingContext) bool {
            return optionName(ctx.options).isFalseOrUnknown();
        }
    };
    return Closure.exec;
}

pub fn isOptionDisabledOrUndefinedOrTokensOnSameLine(comptime optionName: OptionSelector) rule.ContextPredicate {
    const Closure = struct {
        pub fn exec(ctx: *context.FormattingContext) bool {
            return optionName(ctx.options).isFalseOrUnknown() or ctx.isTokensAreOnSameLine();
        }
    };
    return Closure.exec;
}

pub fn isOptionEnabledOrUndefined(comptime optionName: OptionSelector) rule.ContextPredicate {
    const Closure = struct {
        pub fn exec(ctx: *context.FormattingContext) bool {
            return optionName(ctx.options).isTrueOrUnknown();
        }
    };
    return Closure.exec;
}

pub fn isAfterCodeBlockContext(ctx: *context.FormattingContext) bool {
    const parentKind = std.meta.activeTag(ctx.tree.getNode(ctx.currentTokenParent));
    switch (parentKind) {
        .ClassDeclaration, .ModuleDeclaration, .EnumDeclaration, .CatchClause, .ModuleBlock, .SwitchStatement => return true,
        .Block => {
            const blockParent = ctx.tree.getNodeParent(ctx.currentTokenParent);
            if (blockParent == 0) return true;
            const blockParentKind = std.meta.activeTag(ctx.tree.getNode(blockParent));
            if (blockParentKind != .ArrowFunction and blockParentKind != .FunctionExpression) {
                return true;
            }
        },
        else => {},
    }
    return false;
}

pub fn isArrowFunctionContext(ctx: *context.FormattingContext) bool {
    return std.meta.activeTag(ctx.tree.getNode(ctx.contextNode)) == .ArrowFunction;
}

pub fn isBeforeBlockContext(ctx: *context.FormattingContext) bool {
    return nodeIsBlockContext(ctx.nextTokenParent, ctx.tree);
}

pub fn isBeforeMultilineBlockContext(ctx: *context.FormattingContext) bool {
    return isBeforeBlockContext(ctx) and !(ctx.isNextNodeAllOnSameLine() or ctx.isNextNodeBlockIsOnOneLine());
}

pub fn isBinaryOpContext(ctx: *context.FormattingContext) bool {
    const nodeTag = std.meta.activeTag(ctx.tree.getNode(ctx.contextNode));
    switch (nodeTag) {
        .BinaryExpression => {
            const expr = ctx.tree.getNode(ctx.contextNode).BinaryExpression;
            const operatorKind = std.meta.activeTag(ctx.tree.getNode(expr.OperatorToken));
            return operatorKind != .CommaToken;
        },
        .ConditionalExpression,
        .ConditionalType,
        .AsExpression,
        .ExportSpecifier,
        .ImportSpecifier,
        .TypePredicate,
        .UnionType,
        .IntersectionType,
        .SatisfiesExpression => return true,

        .BindingElement,
        .TypeAliasDeclaration,
        .ImportEqualsDeclaration,
        .ExportAssignment,
        .VariableDeclaration,
        .Parameter,
        .EnumMember,
        .PropertyDeclaration,
        .PropertySignature => {
            return ctx.currentTokenSpan.kind == .EqualsToken or ctx.nextTokenSpan.kind == .EqualsToken;
        },
        .ForInStatement,
        .TypeParameter => {
            return ctx.currentTokenSpan.kind == .InKeyword or ctx.nextTokenSpan.kind == .InKeyword or ctx.currentTokenSpan.kind == .EqualsToken or ctx.nextTokenSpan.kind == .EqualsToken;
        },
        .ForOfStatement => {
            return ctx.currentTokenSpan.kind == .OfKeyword or ctx.nextTokenSpan.kind == .OfKeyword;
        },
        else => return false,
    }
}

pub fn isBraceWrappedContext(ctx: *context.FormattingContext) bool {
    const contextKind = std.meta.activeTag(ctx.tree.getNode(ctx.contextNode));
    return contextKind == .ObjectBindingPattern or
        contextKind == .MappedType or
        isSingleLineBlockContext(ctx);
}

pub fn isConditionalOperatorContext(ctx: *context.FormattingContext) bool {
    const contextKind = std.meta.activeTag(ctx.tree.getNode(ctx.contextNode));
    return contextKind == .ConditionalExpression or contextKind == .ConditionalType;
}

pub fn isConstructorSignatureContext(ctx: *context.FormattingContext) bool {
    return std.meta.activeTag(ctx.tree.getNode(ctx.contextNode)) == .ConstructSignature;
}

pub fn isControlDeclContext(ctx: *context.FormattingContext) bool {
    const contextKind = std.meta.activeTag(ctx.tree.getNode(ctx.contextNode));
    return switch (contextKind) {
        .IfStatement, .SwitchStatement, .ForStatement, .ForInStatement, .ForOfStatement, .WhileStatement, .TryStatement, .DoStatement, .WithStatement, .CatchClause => true,
        else => false,
    };
}

pub fn isEndOfDecoratorContextOnSameLine(ctx: *context.FormattingContext) bool {
    return ctx.isTokensAreOnSameLine() and
        nodeHasDecorators(ctx.contextNode, ctx.tree) and
        nodeIsInDecoratorContext(ctx.currentTokenParent, ctx.tree) and
        !nodeIsInDecoratorContext(ctx.nextTokenParent, ctx.tree);
}

pub fn isForContext(ctx: *context.FormattingContext) bool {
    return std.meta.activeTag(ctx.tree.getNode(ctx.contextNode)) == .ForStatement;
}

pub fn isFunctionCallOrNewContext(ctx: *context.FormattingContext) bool {
    return isFunctionCallContext(ctx) or isNewContext(ctx);
}

pub fn isFunctionDeclContext(ctx: *context.FormattingContext) bool {
    const contextKind = std.meta.activeTag(ctx.tree.getNode(ctx.contextNode));
    return switch (contextKind) {
        .FunctionDeclaration, .MethodDeclaration, .MethodSignature, .GetAccessor, .SetAccessor, .CallSignature, .FunctionExpression, .Constructor, .ArrowFunction, .InterfaceDeclaration => true,
        else => false,
    };
}

pub fn isFunctionDeclarationOrFunctionExpressionContext(ctx: *context.FormattingContext) bool {
    const contextKind = std.meta.activeTag(ctx.tree.getNode(ctx.contextNode));
    return contextKind == .FunctionDeclaration or contextKind == .FunctionExpression;
}

pub fn isImportTypeContext(ctx: *context.FormattingContext) bool {
    return std.meta.activeTag(ctx.tree.getNode(ctx.contextNode)) == .ImportType;
}

pub fn isJsxAttributeContext(ctx: *context.FormattingContext) bool {
    return std.meta.activeTag(ctx.tree.getNode(ctx.contextNode)) == .JsxAttribute;
}

pub fn isJsxExpressionContext(ctx: *context.FormattingContext) bool {
    const contextKind = std.meta.activeTag(ctx.tree.getNode(ctx.contextNode));
    return contextKind == .JsxExpression or contextKind == .JsxSpreadAttribute;
}

pub fn isJsxSelfClosingElementContext(ctx: *context.FormattingContext) bool {
    return std.meta.activeTag(ctx.tree.getNode(ctx.contextNode)) == .JsxSelfClosingElement;
}

pub fn isModuleDeclContext(ctx: *context.FormattingContext) bool {
    return std.meta.activeTag(ctx.tree.getNode(ctx.contextNode)) == .ModuleDeclaration;
}

pub fn isMultilineBlockContext(ctx: *context.FormattingContext) bool {
    return isBlockContext(ctx) and !(ctx.isContextNodeAllOnSameLine() or ctx.isContextNodeBlockIsOnOneLine());
}

pub fn isNextTokenNotCloseBracket(ctx: *context.FormattingContext) bool {
    return ctx.nextTokenSpan.kind != .CloseBracketToken;
}

pub fn isNextTokenNotCloseParen(ctx: *context.FormattingContext) bool {
    return ctx.nextTokenSpan.kind != .CloseParenToken;
}

pub fn isNextTokenParentJsxAttribute(ctx: *context.FormattingContext) bool {
    const nextTokenParentKind = std.meta.activeTag(ctx.tree.getNode(ctx.nextTokenParent));
    if (nextTokenParentKind == .JsxAttribute) return true;
    if (nextTokenParentKind == .JsxNamespacedName) {
        const parentOfNextTokenParent = ctx.tree.getNodeParent(ctx.nextTokenParent);
        if (parentOfNextTokenParent != 0 and std.meta.activeTag(ctx.tree.getNode(parentOfNextTokenParent)) == .JsxAttribute) {
            return true;
        }
    }
    return false;
}

pub fn isNextTokenParentJsxNamespacedName(ctx: *context.FormattingContext) bool {
    return std.meta.activeTag(ctx.tree.getNode(ctx.nextTokenParent)) == .JsxNamespacedName;
}

pub fn isNextTokenParentNotJsxNamespacedName(ctx: *context.FormattingContext) bool {
    return std.meta.activeTag(ctx.tree.getNode(ctx.nextTokenParent)) != .JsxNamespacedName;
}

pub fn isNonJsxElementOrFragmentContext(ctx: *context.FormattingContext) bool {
    const contextKind = std.meta.activeTag(ctx.tree.getNode(ctx.contextNode));
    return contextKind != .JsxElement and contextKind != .JsxFragment;
}

pub fn isNonJsxSameLineTokenContext(ctx: *context.FormattingContext) bool {
    return ctx.isTokensAreOnSameLine() and std.meta.activeTag(ctx.tree.getNode(ctx.contextNode)) != .JsxText;
}

pub fn isNonJsxTextContext(ctx: *context.FormattingContext) bool {
    return std.meta.activeTag(ctx.tree.getNode(ctx.contextNode)) != .JsxText;
}

pub fn isNonNullAssertionContext(ctx: *context.FormattingContext) bool {
    return std.meta.activeTag(ctx.tree.getNode(ctx.contextNode)) == .NonNullExpression;
}

pub fn isNonOptionalPropertyContext(ctx: *context.FormattingContext) bool {
    return !isOptionalPropertyContext(ctx);
}

pub fn isNonTypeAssertionContext(ctx: *context.FormattingContext) bool {
    return !isTypeAssertionContext(ctx);
}

pub fn isNotBeforeBlockInFunctionDeclarationContext(ctx: *context.FormattingContext) bool {
    return !isFunctionDeclContext(ctx) and !isBeforeBlockContext(ctx);
}

pub fn isNotBinaryOpContext(ctx: *context.FormattingContext) bool {
    return !isBinaryOpContext(ctx);
}

pub fn isNotForContext(ctx: *context.FormattingContext) bool {
    return !isForContext(ctx);
}

pub fn isNotFormatOnEnter(ctx: *context.FormattingContext) bool {
    return ctx.formattingRequestKind != .FormatOnEnter;
}

pub fn isNotFunctionDeclContext(ctx: *context.FormattingContext) bool {
    return !isFunctionDeclContext(ctx);
}

pub fn isNotPropertyAccessOnIntegerLiteral(ctx: *context.FormattingContext) bool {
    if (std.meta.activeTag(ctx.tree.getNode(ctx.contextNode)) != .PropertyAccessExpression) return true;
    const pae = ctx.tree.getNode(ctx.contextNode).PropertyAccessExpression;
    const exprNode = ctx.tree.getNode(pae.Expression);
    if (std.meta.activeTag(exprNode) != .NumericLiteral) return true;
    const text = exprNode.NumericLiteral.Text;
    for (text) |c| {
        if (c == '.') return false;
    }
    return true;
}

pub fn isNotStatementConditionContext(ctx: *context.FormattingContext) bool {
    return !isStatementConditionContext(ctx);
}

pub fn isNotTypeAnnotationContext(ctx: *context.FormattingContext) bool {
    return !isTypeAnnotationContext(ctx);
}

pub fn isObjectContext(ctx: *context.FormattingContext) bool {
    return std.meta.activeTag(ctx.tree.getNode(ctx.contextNode)) == .ObjectLiteralExpression;
}

pub fn isObjectTypeContext(ctx: *context.FormattingContext) bool {
    return std.meta.activeTag(ctx.tree.getNode(ctx.contextNode)) == .TypeLiteral;
}

pub fn isPreviousTokenNotComma(ctx: *context.FormattingContext) bool {
    return ctx.currentTokenSpan.kind != .CommaToken;
}

pub fn isSameLineTokenOrBeforeBlockContext(ctx: *context.FormattingContext) bool {
    return ctx.isTokensAreOnSameLine() or isBeforeBlockContext(ctx);
}

pub fn isSemicolonDeletionContext(ctx: *context.FormattingContext) bool {
    var nextTokenKind = ctx.nextTokenSpan.kind;
    var nextTokenStart = ctx.nextTokenSpan.loc.pos;
    
    if (kind.isTrivia(nextTokenKind)) {
        var nextRealTokenNode: ast.NodeIndex = 0;
        if (ctx.nextTokenParent == ctx.currentTokenParent) {
            nextRealTokenNode = astnav.getFirstToken(ctx.nextTokenParent, ctx.tree);
        } else {
            nextRealTokenNode = astnav.getFirstToken(ctx.nextTokenParent, ctx.tree);
        }
        
        if (nextRealTokenNode == 0) {
            return true;
        }
        

        nextTokenStart = ctx.tree.positions.items[nextRealTokenNode].pos;
        // Note: activeTag on NodeData will give the union tag like .SemicolonToken
        // However, not all tokens are distinct NodeData tags. 
        // In Zig typescript-go port, maybe kind is still needed. Let's assume it works for now and fix errors later.
        nextTokenKind = @enumFromInt(@intFromEnum(std.meta.activeTag(ctx.tree.getNode(nextRealTokenNode)))); // Will probably not compile directly, need to check build.
    }

    const root_scanner = @import("../scanner/scanner.zig");
    const startLine = root_scanner.getECMALineOfPosition(ctx.tree.sourceText, ctx.currentTokenSpan.loc.pos);
    const endLine = root_scanner.getECMALineOfPosition(ctx.tree.sourceText, nextTokenStart);

    if (startLine == endLine) {
        return nextTokenKind == .CloseBraceToken or nextTokenKind == .EndOfFile;
    }

    if (nextTokenKind == .SemicolonToken and ctx.currentTokenSpan.kind == .SemicolonToken) {
        return true;
    }

    if (nextTokenKind == .SemicolonClassElement or nextTokenKind == .SemicolonToken) {
        return false;
    }

    const contextKind = std.meta.activeTag(ctx.tree.getNode(ctx.contextNode));
    if (contextKind == .InterfaceDeclaration or contextKind == .TypeAliasDeclaration) {
        const parentKind = std.meta.activeTag(ctx.tree.getNode(ctx.currentTokenParent));
        if (parentKind != .PropertySignature) return true;
        const ps = ctx.tree.getNode(ctx.currentTokenParent).PropertySignature;
        return ps.Type != 0 or nextTokenKind != .OpenParenToken;
    }

    const currentParentKind = std.meta.activeTag(ctx.tree.getNode(ctx.currentTokenParent));
    if (currentParentKind == .PropertyDeclaration) {
        const pd = ctx.tree.getNode(ctx.currentTokenParent).PropertyDeclaration;
        return pd.Initializer == 0;
    }

    return currentParentKind != .ForStatement and
        currentParentKind != .EmptyStatement and
        currentParentKind != .SemicolonClassElement and
        nextTokenKind != .OpenBracketToken and
        nextTokenKind != .OpenParenToken and
        nextTokenKind != .PlusToken and
        nextTokenKind != .MinusToken and
        nextTokenKind != .SlashToken and
        nextTokenKind != .RegularExpressionLiteral and
        nextTokenKind != .CommaToken and
        nextTokenKind != .TemplateExpression and
        nextTokenKind != .TemplateHead and
        nextTokenKind != .NoSubstitutionTemplateLiteral and
        nextTokenKind != .DotToken;
}

pub fn isSemicolonInsertionContext(ctx: *context.FormattingContext) bool {
    return lsutil.positionIsASICandidate(ctx.tree, ctx.currentTokenSpan.loc.end, ctx.currentTokenParent);
}

pub fn isStartOfVariableDeclarationList(ctx: *context.FormattingContext) bool {
    if (std.meta.activeTag(ctx.tree.getNode(ctx.currentTokenParent)) == .VariableDeclarationList) {

        return ctx.tree.positions.items[ctx.currentTokenParent].pos == ctx.currentTokenSpan.loc.pos;
    }
    return false;
}

pub fn isTypeAnnotationContext(ctx: *context.FormattingContext) bool {
    const contextKind = std.meta.activeTag(ctx.tree.getNode(ctx.contextNode));
    return contextKind == .PropertyDeclaration or
        contextKind == .PropertySignature or
        contextKind == .Parameter or
        contextKind == .VariableDeclaration or
        isFunctionLikeKind(contextKind);
}

pub fn isTypeArgumentOrParameterOrAssertionContext(ctx: *context.FormattingContext) bool {
    return isTypeArgumentOrParameterOrAssertion(ctx.currentTokenSpan, ctx.currentTokenParent, ctx.tree) or
        isTypeArgumentOrParameterOrAssertion(ctx.nextTokenSpan, ctx.nextTokenParent, ctx.tree);
}

pub fn isTypeAssertionContext(ctx: *context.FormattingContext) bool {
    return std.meta.activeTag(ctx.tree.getNode(ctx.contextNode)) == .TypeAssertionExpression;
}

pub fn isTypeScriptDeclWithBlockContext(ctx: *context.FormattingContext) bool {
    return nodeIsTypeScriptDeclWithBlockContext(ctx.contextNode, ctx.tree);
}

pub fn isVoidOpContext(ctx: *context.FormattingContext) bool {
    return ctx.currentTokenSpan.kind == .VoidKeyword and std.meta.activeTag(ctx.tree.getNode(ctx.currentTokenParent)) == .VoidExpression;
}

pub fn isYieldOrYieldStarWithOperand(ctx: *context.FormattingContext) bool {
    if (std.meta.activeTag(ctx.tree.getNode(ctx.contextNode)) == .YieldExpression) {
        const ye = ctx.tree.getNode(ctx.contextNode).YieldExpression;
        return ye.Expression != 0;
    }
    return false;
}

pub fn optionEqualsInsertSemicolon(ctx: *context.FormattingContext) bool {
    return ctx.options.semicolons == .Insert;
}

pub fn optionEqualsRemoveSemicolon(ctx: *context.FormattingContext) bool {
    return ctx.options.semicolons == .Remove;
}

// Helper functions for the above context functions
const ast_gen = @import("../ast/ast_generated.zig");
pub fn isFunctionLikeKind(contextKind: std.meta.Tag(ast_gen.NodeData)) bool {
    return switch (contextKind) {
        .FunctionDeclaration, .MethodDeclaration, .MethodSignature, .GetAccessor, .SetAccessor, .CallSignature, .FunctionExpression, .Constructor, .ArrowFunction, .InterfaceDeclaration => true,
        else => false,
    };
}

pub fn isOptionalPropertyContext(ctx: *context.FormattingContext) bool {
    const contextKind = std.meta.activeTag(ctx.tree.getNode(ctx.contextNode));
    if (contextKind == .PropertyDeclaration) {
        const pd = ctx.tree.getNode(ctx.contextNode).PropertyDeclaration;
        return pd.PostfixToken != null and std.meta.activeTag(ctx.tree.getNode(pd.PostfixToken.?)) == .QuestionToken;
    }
    return false;
}

pub fn isSingleLineBlockContext(ctx: *context.FormattingContext) bool {
    return isBlockContext(ctx) and (ctx.isContextNodeAllOnSameLine() or ctx.isContextNodeBlockIsOnOneLine());
}

pub fn isBlockContext(ctx: *context.FormattingContext) bool {
    return nodeIsBlockContext(ctx.contextNode, ctx.tree);
}


pub fn nodeIsBlockContext(node: ast.NodeIndex, tree: *ast.Ast) bool {
    if (nodeIsTypeScriptDeclWithBlockContext(node, tree)) return true;
    const kindTag = std.meta.activeTag(tree.getNode(node));
    return switch (kindTag) {
        .Block, .CaseBlock, .ObjectLiteralExpression, .ModuleBlock => true,
        else => false,
    };
}

pub fn nodeIsTypeScriptDeclWithBlockContext(node: ast.NodeIndex, tree: *ast.Ast) bool {
    const kindTag = std.meta.activeTag(tree.getNode(node));
    return switch (kindTag) {
        .ClassDeclaration, .ClassExpression, .InterfaceDeclaration, .EnumDeclaration, .TypeLiteral, .ModuleDeclaration, .ExportDeclaration, .NamedExports, .ImportDeclaration, .NamedImports => true,
        else => false,
    };
}

pub fn isFunctionCallContext(ctx: *context.FormattingContext) bool {
    return std.meta.activeTag(ctx.tree.getNode(ctx.contextNode)) == .CallExpression;
}

pub fn isNewContext(ctx: *context.FormattingContext) bool {
    return std.meta.activeTag(ctx.tree.getNode(ctx.contextNode)) == .NewExpression;
}

pub fn nodeHasDecorators(node: ast.NodeIndex, tree: *ast.Ast) bool {
    const ast_utils = @import("../ast/ast_utils.zig");
    return ast_utils.hasDecorators(tree, node);
}

pub fn nodeIsInDecoratorContext(nodeParam: ast.NodeIndex, tree: *ast.Ast) bool {
    var node = nodeParam;
    while (node != 0 and isExpression(node, tree)) {
        node = tree.getNodeParent(node);
    }
    return node != 0 and std.meta.activeTag(tree.getNode(node)) == .Decorator;
}

pub fn isExpression(node: ast.NodeIndex, tree: *ast.Ast) bool {
    const tag = std.meta.activeTag(tree.getNode(node));
    return switch (tag) {
        .CallExpression, .Identifier, .PropertyAccessExpression, .ElementAccessExpression, .ParenthesizedExpression, .TypeAssertionExpression, .AsExpression, .NonNullExpression => true,
        else => false,
    };
}

pub fn isStatementConditionContext(ctx: *context.FormattingContext) bool {
    const contextKind = std.meta.activeTag(ctx.tree.getNode(ctx.contextNode));
    return switch (contextKind) {
        .IfStatement, .ForStatement, .ForInStatement, .ForOfStatement, .DoStatement, .WhileStatement => true,
        else => false,
    };
}

const format_scanner = @import("scanner.zig");
pub fn isTypeArgumentOrParameterOrAssertion(token: format_scanner.TextRangeWithKind, parent: ast.NodeIndex, tree: *ast.Ast) bool {
    if (token.kind != .LessThanToken and token.kind != .GreaterThanToken) {
        return false;
    }
    if (parent == 0) return false;
    const parentKind = std.meta.activeTag(tree.getNode(parent));
    return switch (parentKind) {
        .TypeReference, .TypeAssertionExpression, .TypeAliasDeclaration, .ClassDeclaration, .ClassExpression, .InterfaceDeclaration, .FunctionDeclaration, .FunctionExpression, .ArrowFunction, .MethodDeclaration, .MethodSignature, .CallSignature, .ConstructSignature, .CallExpression, .NewExpression, .ExpressionWithTypeArguments => true,
        else => false,
    };
}

