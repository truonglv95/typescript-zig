const std = @import("std");
const ast = @import("../ast/ast.zig");
const kind = @import("../ast/kind.zig");
const rule = @import("rule.zig");
const rulecontext = @import("rulecontext.zig");
const lsutil = @import("../ls/lsutil/lsutil.zig");

var allRules: ?[]const rule.RuleSpec = null;
var allRulesArena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

pub fn getAllRules() []const rule.RuleSpec {
    if (allRules) |r| return r;

    const alloc = allRulesArena.allocator();

    var allTokensList: [400]kind.Kind = undefined;
    var allTokensLen: usize = 0;
    for (@intFromEnum(kind.Kind.Unknown)..@intFromEnum(kind.Kind.NotEmittedTypeElement)+1) |k| {
        const token: kind.Kind = @enumFromInt(k);
        if (token != .EndOfFile) {
            allTokensList[allTokensLen] = token;
            allTokensLen += 1;
        }
    }
    const allTokens = allTokensList[0..allTokensLen];

    // anyTokenExcept is slightly complex, we'll inline logic or use helper.
    const anyToken = rule.toTokenRangeAny(allTokens);
    
    var anyTokenIncludingMultilineCommentsList: [400]kind.Kind = undefined;
    var len1: usize = 0;
    for (@intFromEnum(kind.Kind.Unknown)..@intFromEnum(kind.Kind.NotEmittedTypeElement)+1) |k| {
        const token: kind.Kind = @enumFromInt(k);
        if (token != .EndOfFile) {
            anyTokenIncludingMultilineCommentsList[len1] = token;
            len1 += 1;
        }
    }
    anyTokenIncludingMultilineCommentsList[len1] = .MultiLineCommentTrivia;
    len1 += 1;
    const anyTokenIncludingMultilineComments = rule.toTokenRangeAny(anyTokenIncludingMultilineCommentsList[0..len1]);

    var anyTokenIncludingEOFList: [400]kind.Kind = undefined;
    var len2: usize = 0;
    for (@intFromEnum(kind.Kind.Unknown)..@intFromEnum(kind.Kind.NotEmittedTypeElement)+1) |k| {
        const token: kind.Kind = @enumFromInt(k);
        anyTokenIncludingEOFList[len2] = token;
        len2 += 1;
    }
    const anyTokenIncludingEOF = rule.toTokenRangeAny(anyTokenIncludingEOFList[0..len2]);

    var keywordsList: [200]kind.Kind = undefined;
    var keywordsLen: usize = 0;
    for (@intFromEnum(kind.Kind.BreakKeyword)..@intFromEnum(kind.Kind.DeferKeyword)+1) |k| {
        keywordsList[keywordsLen] = @enumFromInt(k);
        keywordsLen += 1;
    }
    const keywords = rule.toTokenRange(keywordsList[0..keywordsLen]);

    var binaryOperatorsList: [200]kind.Kind = undefined;
    var binaryOperatorsLen: usize = 0;
    for (@intFromEnum(kind.Kind.LessThanToken)..@intFromEnum(kind.Kind.CaretEqualsToken)+1) |k| {
        binaryOperatorsList[binaryOperatorsLen] = @enumFromInt(k);
        binaryOperatorsLen += 1;
    }
    const binaryOperators = rule.toTokenRange(binaryOperatorsList[0..binaryOperatorsLen]);

    const binaryKeywordOperators = [_]kind.Kind{
        .InKeyword, .InstanceOfKeyword, .OfKeyword, .AsKeyword, .IsKeyword, .SatisfiesKeyword,
    };
    const unaryPrefixOperators = [_]kind.Kind{ .PlusPlusToken, .MinusToken, .TildeToken, .ExclamationToken };
    const unaryPrefixExpressions = [_]kind.Kind{ .NumericLiteral, .BigIntLiteral, .Identifier, .OpenParenToken, .OpenBracketToken, .OpenBraceToken, .ThisKeyword, .NewKeyword };
    const unaryPreincrementExpressions = [_]kind.Kind{ .Identifier, .OpenParenToken, .ThisKeyword, .NewKeyword };
    const unaryPostincrementExpressions = [_]kind.Kind{ .Identifier, .CloseParenToken, .CloseBracketToken, .NewKeyword };
    const unaryPredecrementExpressions = [_]kind.Kind{ .Identifier, .OpenParenToken, .ThisKeyword, .NewKeyword };
    const unaryPostdecrementExpressions = [_]kind.Kind{ .Identifier, .CloseParenToken, .CloseBracketToken, .NewKeyword };
    const comments = [_]kind.Kind{ .SingleLineCommentTrivia, .MultiLineCommentTrivia };
    
    var typeNamesList: [200]kind.Kind = undefined;
    typeNamesList[0] = .Identifier;
    var typeNamesLen: usize = 1;
    for (@intFromEnum(kind.Kind.TypePredicate)..@intFromEnum(kind.Kind.ImportType)+1) |k| {
        typeNamesList[typeNamesLen] = @enumFromInt(k);
        typeNamesLen += 1;
    }
    const typeNames = rule.toTokenRange(typeNamesList[0..typeNamesLen]);

    const functionOpenBraceLeftTokenRange = anyTokenIncludingMultilineComments;
    const typeScriptOpenBraceLeftTokenRange = rule.toTokenRange(&[_]kind.Kind{ .Identifier, .GreaterThanToken, .MultiLineCommentTrivia, .ClassKeyword, .ExportKeyword, .ImportKeyword });
    const controlOpenBraceLeftTokenRange = rule.toTokenRange(&[_]kind.Kind{ .CloseParenToken, .MultiLineCommentTrivia, .DoKeyword, .TryKeyword, .FinallyKeyword, .ElseKeyword, .CatchKeyword });

    const createRule = rule.createRule;
    const ruleActionStopProcessingSpaceActions = @intFromEnum(rule.RuleAction.StopProcessingSpaceActions);
    const ruleActionDeleteSpace = @intFromEnum(rule.RuleAction.DeleteSpace);
    const ruleActionInsertSpace = @intFromEnum(rule.RuleAction.InsertSpace);
    const ruleActionInsertNewLine = @intFromEnum(rule.RuleAction.InsertNewLine);
    const ruleActionDeleteToken = @intFromEnum(rule.RuleAction.DeleteToken);
    const ruleActionInsertTrailingSemicolon = @intFromEnum(rule.RuleAction.InsertTrailingSemicolon);
    const ruleFlagsCanDeleteNewLines = rule.RuleFlags.CanDeleteNewLines;
    

    const highPriorityCommonRules = [_]rule.RuleSpec{
        createRule("IgnoreBeforeComment", anyToken, rule.toTokenRange(&comments), rule.anyContext, ruleActionStopProcessingSpaceActions, .None),
        createRule("IgnoreAfterLineComment", rule.toTokenRange(&[_]kind.Kind{.SingleLineCommentTrivia}), anyToken, rule.anyContext, ruleActionStopProcessingSpaceActions, .None),

        createRule("NotSpaceBeforeColon", anyToken, rule.toTokenRange(&[_]kind.Kind{.ColonToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isNotBinaryOpContext, rulecontext.isNotTypeAnnotationContext }, ruleActionDeleteSpace, .None),
        createRule("SpaceAfterColon", rule.toTokenRange(&[_]kind.Kind{.ColonToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isNotBinaryOpContext, rulecontext.isNextTokenParentNotJsxNamespacedName }, ruleActionInsertSpace, .None),
        createRule("NoSpaceBeforeQuestionMark", anyToken, rule.toTokenRange(&[_]kind.Kind{.QuestionToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isNotBinaryOpContext, rulecontext.isNotTypeAnnotationContext }, ruleActionDeleteSpace, .None),
        createRule("SpaceAfterQuestionMarkInConditionalOperator", rule.toTokenRange(&[_]kind.Kind{.QuestionToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isConditionalOperatorContext }, ruleActionInsertSpace, .None),

        createRule("NoSpaceAfterQuestionMark", rule.toTokenRange(&[_]kind.Kind{.QuestionToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isNonOptionalPropertyContext }, ruleActionDeleteSpace, .None),

        createRule("NoSpaceBeforeDot", anyToken, rule.toTokenRange(&[_]kind.Kind{ .DotToken, .QuestionDotToken }), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isNotPropertyAccessOnIntegerLiteral }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceAfterDot", rule.toTokenRange(&[_]kind.Kind{ .DotToken, .QuestionDotToken }), anyToken, &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),

        createRule("NoSpaceBetweenImportParenInImportType", rule.toTokenRange(&[_]kind.Kind{.ImportKeyword}), rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isImportTypeContext }, ruleActionDeleteSpace, .None),

        createRule("NoSpaceAfterUnaryPrefixOperator", rule.toTokenRange(&unaryPrefixOperators), rule.toTokenRange(&unaryPrefixExpressions), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isNotBinaryOpContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceAfterUnaryPreincrementOperator", rule.toTokenRange(&[_]kind.Kind{.PlusPlusToken}), rule.toTokenRange(&unaryPreincrementExpressions), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceAfterUnaryPredecrementOperator", rule.toTokenRange(&[_]kind.Kind{.MinusMinusToken}), rule.toTokenRange(&unaryPredecrementExpressions), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceBeforeUnaryPostincrementOperator", rule.toTokenRange(&unaryPostincrementExpressions), rule.toTokenRange(&[_]kind.Kind{.PlusPlusToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isNotStatementConditionContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceBeforeUnaryPostdecrementOperator", rule.toTokenRange(&unaryPostdecrementExpressions), rule.toTokenRange(&[_]kind.Kind{.MinusMinusToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isNotStatementConditionContext }, ruleActionDeleteSpace, .None),


        createRule("SpaceAfterPostincrementWhenFollowedByAdd", rule.toTokenRange(&[_]kind.Kind{.PlusPlusToken}), rule.toTokenRange(&[_]kind.Kind{.PlusToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isBinaryOpContext }, ruleActionInsertSpace, .None),
        createRule("SpaceAfterAddWhenFollowedByUnaryPlus", rule.toTokenRange(&[_]kind.Kind{.PlusToken}), rule.toTokenRange(&[_]kind.Kind{.PlusToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isBinaryOpContext }, ruleActionInsertSpace, .None),
        createRule("SpaceAfterAddWhenFollowedByPreincrement", rule.toTokenRange(&[_]kind.Kind{.PlusToken}), rule.toTokenRange(&[_]kind.Kind{.PlusPlusToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isBinaryOpContext }, ruleActionInsertSpace, .None),
        createRule("SpaceAfterPostdecrementWhenFollowedBySubtract", rule.toTokenRange(&[_]kind.Kind{.MinusMinusToken}), rule.toTokenRange(&[_]kind.Kind{.MinusToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isBinaryOpContext }, ruleActionInsertSpace, .None),
        createRule("SpaceAfterSubtractWhenFollowedByUnaryMinus", rule.toTokenRange(&[_]kind.Kind{.MinusToken}), rule.toTokenRange(&[_]kind.Kind{.MinusToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isBinaryOpContext }, ruleActionInsertSpace, .None),
        createRule("SpaceAfterSubtractWhenFollowedByPredecrement", rule.toTokenRange(&[_]kind.Kind{.MinusToken}), rule.toTokenRange(&[_]kind.Kind{.MinusMinusToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isBinaryOpContext }, ruleActionInsertSpace, .None),

        createRule("NoSpaceAfterCloseBrace", rule.toTokenRange(&[_]kind.Kind{.CloseBraceToken}), rule.toTokenRange(&[_]kind.Kind{ .CommaToken, .SemicolonToken }), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),
        createRule("NewLineBeforeCloseBraceInBlockContext", anyTokenIncludingMultilineComments, rule.toTokenRange(&[_]kind.Kind{.CloseBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isMultilineBlockContext }, ruleActionInsertNewLine, .None),

        createRule("SpaceAfterCloseBrace", rule.toTokenRange(&[_]kind.Kind{.CloseBraceToken}), rule.toTokenRangeAny(&[_]kind.Kind{.CloseParenToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isAfterCodeBlockContext }, ruleActionInsertSpace, .None),
        createRule("SpaceBetweenCloseBraceAndElse", rule.toTokenRange(&[_]kind.Kind{.CloseBraceToken}), rule.toTokenRange(&[_]kind.Kind{.ElseKeyword}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
        createRule("SpaceBetweenCloseBraceAndWhile", rule.toTokenRange(&[_]kind.Kind{.CloseBraceToken}), rule.toTokenRange(&[_]kind.Kind{.WhileKeyword}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
        createRule("NoSpaceBetweenEmptyBraceBrackets", rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), rule.toTokenRange(&[_]kind.Kind{.CloseBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isObjectContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceAfterConditionalClosingParen", rule.toTokenRange(&[_]kind.Kind{.CloseParenToken}), rule.toTokenRange(&[_]kind.Kind{.OpenBracketToken}), &[_]rule.ContextPredicate{ rulecontext.isControlDeclContext }, ruleActionInsertSpace, .None),

        createRule("NoSpaceBetweenFunctionKeywordAndStar", rule.toTokenRange(&[_]kind.Kind{.FunctionKeyword}), rule.toTokenRange(&[_]kind.Kind{.AsteriskToken}), &[_]rule.ContextPredicate{ rulecontext.isFunctionDeclarationOrFunctionExpressionContext }, ruleActionDeleteSpace, .None),
        createRule("SpaceAfterStarInGeneratorDeclaration", rule.toTokenRange(&[_]kind.Kind{.AsteriskToken}), rule.toTokenRange(&[_]kind.Kind{.Identifier}), &[_]rule.ContextPredicate{ rulecontext.isFunctionDeclarationOrFunctionExpressionContext }, ruleActionInsertSpace, .None),

        createRule("SpaceAfterFunctionInFuncDecl", rule.toTokenRange(&[_]kind.Kind{.FunctionKeyword}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isFunctionDeclContext }, ruleActionInsertSpace, .None),
        createRule("NewLineAfterOpenBraceInBlockContext", rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isMultilineBlockContext }, ruleActionInsertNewLine, .None),

        createRule("SpaceAfterGetSetInMember", rule.toTokenRange(&[_]kind.Kind{ .GetKeyword, .SetKeyword }), rule.toTokenRange(&[_]kind.Kind{.Identifier}), &[_]rule.ContextPredicate{ rulecontext.isFunctionDeclContext }, ruleActionInsertSpace, .None),

        createRule("NoSpaceBetweenYieldKeywordAndStar", rule.toTokenRange(&[_]kind.Kind{.YieldKeyword}), rule.toTokenRange(&[_]kind.Kind{.AsteriskToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isYieldOrYieldStarWithOperand }, ruleActionDeleteSpace, .None),
        createRule("SpaceBetweenYieldOrYieldStarAndOperand", rule.toTokenRange(&[_]kind.Kind{ .YieldKeyword, .AsteriskToken }), anyToken, &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isYieldOrYieldStarWithOperand }, ruleActionInsertSpace, .None),

        createRule("NoSpaceBetweenReturnAndSemicolon", rule.toTokenRange(&[_]kind.Kind{.ReturnKeyword}), rule.toTokenRange(&[_]kind.Kind{.SemicolonToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),
        createRule("SpaceAfterCertainKeywords", rule.toTokenRange(&[_]kind.Kind{ .VarKeyword, .ThrowKeyword, .NewKeyword, .DeleteKeyword, .ReturnKeyword, .TypeOfKeyword, .AwaitKeyword }), anyToken, &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
        createRule("SpaceAfterLetConstInVariableDeclaration", rule.toTokenRange(&[_]kind.Kind{ .LetKeyword, .ConstKeyword }), anyToken, &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isStartOfVariableDeclarationList }, ruleActionInsertSpace, .None),
        createRule("NoSpaceBeforeOpenParenInFuncCall", anyToken, rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isFunctionCallOrNewContext, rulecontext.isPreviousTokenNotComma }, ruleActionDeleteSpace, .None),

        createRule("SpaceBeforeBinaryKeywordOperator", anyToken, rule.toTokenRange(&binaryKeywordOperators), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isBinaryOpContext }, ruleActionInsertSpace, .None),
        createRule("SpaceAfterBinaryKeywordOperator", rule.toTokenRange(&binaryKeywordOperators), anyToken, &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isBinaryOpContext }, ruleActionInsertSpace, .None),

        createRule("SpaceAfterVoidOperator", rule.toTokenRange(&[_]kind.Kind{.VoidKeyword}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isVoidOpContext }, ruleActionInsertSpace, .None),

        createRule("SpaceBetweenAsyncAndOpenParen", rule.toTokenRange(&[_]kind.Kind{.AsyncKeyword}), rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), &[_]rule.ContextPredicate{ rulecontext.isArrowFunctionContext, rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
        createRule("SpaceBetweenAsyncAndFunctionKeyword", rule.toTokenRange(&[_]kind.Kind{.AsyncKeyword}), rule.toTokenRange(&[_]kind.Kind{ .FunctionKeyword, .Identifier }), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),

        createRule("NoSpaceBetweenTagAndTemplateString", rule.toTokenRange(&[_]kind.Kind{ .Identifier, .CloseParenToken }), rule.toTokenRange(&[_]kind.Kind{ .NoSubstitutionTemplateLiteral, .TemplateHead }), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceBeforeJsxAttribute", anyToken, rule.toTokenRange(&[_]kind.Kind{.Identifier}), &[_]rule.ContextPredicate{ rulecontext.isNextTokenParentJsxAttribute, rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
        createRule("SpaceBeforeSlashInJsxOpeningElement", anyToken, rule.toTokenRange(&[_]kind.Kind{.SlashToken}), &[_]rule.ContextPredicate{ rulecontext.isJsxSelfClosingElementContext, rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
        createRule("NoSpaceBeforeGreaterThanTokenInJsxOpeningElement", rule.toTokenRange(&[_]kind.Kind{.SlashToken}), rule.toTokenRange(&[_]kind.Kind{.GreaterThanToken}), &[_]rule.ContextPredicate{ rulecontext.isJsxSelfClosingElementContext, rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceBeforeEqualInJsxAttribute", anyToken, rule.toTokenRange(&[_]kind.Kind{.EqualsToken}), &[_]rule.ContextPredicate{ rulecontext.isJsxAttributeContext, rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceAfterEqualInJsxAttribute", rule.toTokenRange(&[_]kind.Kind{.EqualsToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isJsxAttributeContext, rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceBeforeJsxNamespaceColon", rule.toTokenRange(&[_]kind.Kind{.Identifier}), rule.toTokenRange(&[_]kind.Kind{.ColonToken}), &[_]rule.ContextPredicate{ rulecontext.isNextTokenParentJsxNamespacedName }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceAfterJsxNamespaceColon", rule.toTokenRange(&[_]kind.Kind{.ColonToken}), rule.toTokenRange(&[_]kind.Kind{.Identifier}), &[_]rule.ContextPredicate{ rulecontext.isNextTokenParentJsxNamespacedName }, ruleActionDeleteSpace, .None),

        createRule("NoSpaceAfterModuleImport", rule.toTokenRange(&[_]kind.Kind{ .ModuleKeyword, .RequireKeyword }), rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceAfterCertainTypeScriptKeywords", rule.toTokenRange(&[_]kind.Kind{
            .AbstractKeyword, .AccessorKeyword, .ClassKeyword, .DeclareKeyword, .DefaultKeyword, .EnumKeyword, .ExportKeyword, .ExtendsKeyword, .GetKeyword, .ImplementsKeyword, .ImportKeyword, .InterfaceKeyword, .ModuleKeyword, .NamespaceKeyword, .OverrideKeyword, .PrivateKeyword, .PublicKeyword, .ProtectedKeyword, .ReadonlyKeyword, .SetKeyword, .StaticKeyword, .TypeKeyword, .FromKeyword, .KeyOfKeyword, .InferKeyword,
        }), anyToken, &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
        createRule("SpaceBeforeCertainTypeScriptKeywords", anyToken, rule.toTokenRange(&[_]kind.Kind{ .ExtendsKeyword, .ImplementsKeyword, .FromKeyword }), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),

        createRule("SpaceAfterModuleName", rule.toTokenRange(&[_]kind.Kind{.StringLiteral}), rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isModuleDeclContext }, ruleActionInsertSpace, .None),

        createRule("SpaceBeforeArrow", anyToken, rule.toTokenRange(&[_]kind.Kind{.EqualsGreaterThanToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
        createRule("SpaceAfterArrow", rule.toTokenRange(&[_]kind.Kind{.EqualsGreaterThanToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),

        createRule("NoSpaceAfterEllipsis", rule.toTokenRange(&[_]kind.Kind{.DotDotDotToken}), rule.toTokenRange(&[_]kind.Kind{.Identifier}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceAfterOptionalParameters", rule.toTokenRange(&[_]kind.Kind{.QuestionToken}), rule.toTokenRange(&[_]kind.Kind{ .CloseParenToken, .CommaToken }), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isNotBinaryOpContext }, ruleActionDeleteSpace, .None),

        createRule("NoSpaceBetweenEmptyInterfaceBraceBrackets", rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), rule.toTokenRange(&[_]kind.Kind{.CloseBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isObjectTypeContext }, ruleActionDeleteSpace, .None),

        createRule("NoSpaceBeforeOpenAngularBracket", typeNames, rule.toTokenRange(&[_]kind.Kind{.LessThanToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isTypeArgumentOrParameterOrAssertionContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceBetweenCloseParenAndAngularBracket", rule.toTokenRange(&[_]kind.Kind{.CloseParenToken}), rule.toTokenRange(&[_]kind.Kind{.LessThanToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isTypeArgumentOrParameterOrAssertionContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceAfterOpenAngularBracket", rule.toTokenRange(&[_]kind.Kind{.LessThanToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isTypeArgumentOrParameterOrAssertionContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceBeforeCloseAngularBracket", anyToken, rule.toTokenRange(&[_]kind.Kind{.GreaterThanToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isTypeArgumentOrParameterOrAssertionContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceAfterCloseAngularBracket", rule.toTokenRange(&[_]kind.Kind{.GreaterThanToken}), rule.toTokenRange(&[_]kind.Kind{ .OpenParenToken, .OpenBracketToken, .GreaterThanToken, .CommaToken }), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isTypeArgumentOrParameterOrAssertionContext, rulecontext.isNotFunctionDeclContext, rulecontext.isNonTypeAssertionContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceBeforeAt", rule.toTokenRange(&[_]kind.Kind{ .CloseParenToken, .Identifier }), rule.toTokenRange(&[_]kind.Kind{.AtToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
        createRule("NoSpaceAfterAt", rule.toTokenRange(&[_]kind.Kind{.AtToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),
        createRule("SpaceAfterDecorator", anyToken, rule.toTokenRange(&[_]kind.Kind{ .AbstractKeyword, .Identifier, .ExportKeyword, .DefaultKeyword, .ClassKeyword, .StaticKeyword, .PublicKeyword, .PrivateKeyword, .ProtectedKeyword, .GetKeyword, .SetKeyword, .OpenBracketToken, .AsteriskToken }), &[_]rule.ContextPredicate{ rulecontext.isEndOfDecoratorContextOnSameLine }, ruleActionInsertSpace, .None),

        createRule("NoSpaceBeforeNonNullAssertionOperator", anyToken, rule.toTokenRange(&[_]kind.Kind{.ExclamationToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isNonNullAssertionContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceAfterNewKeywordOnConstructorSignature", rule.toTokenRange(&[_]kind.Kind{.NewKeyword}), rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isConstructorSignatureContext }, ruleActionDeleteSpace, .None),
        createRule("SpaceLessThanAndNonJSXTypeAnnotation", rule.toTokenRange(&[_]kind.Kind{.LessThanToken}), rule.toTokenRange(&[_]kind.Kind{.LessThanToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
    };

    const userConfigurableRules = [_]rule.RuleSpec{
        createRule("SpaceAfterConstructor", rule.toTokenRange(&[_]kind.Kind{.ConstructorKeyword}), rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceAfterConstructorOption), rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
        createRule("NoSpaceAfterConstructor", rule.toTokenRange(&[_]kind.Kind{.ConstructorKeyword}), rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceAfterConstructorOption), rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceAfterComma", rule.toTokenRange(&[_]kind.Kind{.CommaToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceAfterCommaDelimiterOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isNonJsxElementOrFragmentContext, rulecontext.isNextTokenNotCloseBracket, rulecontext.isNextTokenNotCloseParen }, ruleActionInsertSpace, .None),
        createRule("NoSpaceAfterComma", rule.toTokenRange(&[_]kind.Kind{.CommaToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceAfterCommaDelimiterOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isNonJsxElementOrFragmentContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceAfterAnonymousFunctionKeyword", rule.toTokenRange(&[_]kind.Kind{ .FunctionKeyword, .AsteriskToken }), rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceAfterFunctionKeywordForAnonymousFunctionsOption), rulecontext.isFunctionDeclContext }, ruleActionInsertSpace, .None),
        createRule("NoSpaceAfterAnonymousFunctionKeyword", rule.toTokenRange(&[_]kind.Kind{ .FunctionKeyword, .AsteriskToken }), rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceAfterFunctionKeywordForAnonymousFunctionsOption), rulecontext.isFunctionDeclContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceAfterKeywordInControl", keywords, rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceAfterKeywordsInControlFlowStatementsOption), rulecontext.isControlDeclContext }, ruleActionInsertSpace, .None),
        createRule("NoSpaceAfterKeywordInControl", keywords, rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceAfterKeywordsInControlFlowStatementsOption), rulecontext.isControlDeclContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceAfterOpenParen", rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesisOption), rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
        createRule("SpaceBeforeCloseParen", anyToken, rule.toTokenRange(&[_]kind.Kind{.CloseParenToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesisOption), rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
        createRule("SpaceBetweenOpenParens", rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesisOption), rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
        createRule("NoSpaceBetweenParens", rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), rule.toTokenRange(&[_]kind.Kind{.CloseParenToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceAfterOpenParen", rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesisOption), rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceBeforeCloseParen", anyToken, rule.toTokenRange(&[_]kind.Kind{.CloseParenToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesisOption), rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceAfterOpenBracket", rule.toTokenRange(&[_]kind.Kind{.OpenBracketToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceAfterOpeningAndBeforeClosingNonemptyBracketsOption), rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
        createRule("SpaceBeforeCloseBracket", anyToken, rule.toTokenRange(&[_]kind.Kind{.CloseBracketToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceAfterOpeningAndBeforeClosingNonemptyBracketsOption), rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
        createRule("NoSpaceBetweenBrackets", rule.toTokenRange(&[_]kind.Kind{.OpenBracketToken}), rule.toTokenRange(&[_]kind.Kind{.CloseBracketToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceAfterOpenBracket", rule.toTokenRange(&[_]kind.Kind{.OpenBracketToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceAfterOpeningAndBeforeClosingNonemptyBracketsOption), rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceBeforeCloseBracket", anyToken, rule.toTokenRange(&[_]kind.Kind{.CloseBracketToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceAfterOpeningAndBeforeClosingNonemptyBracketsOption), rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceAfterOpenBrace", rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionEnabledOrUndefined(rulecontext.insertSpaceAfterOpeningAndBeforeClosingNonemptyBracesOption), rulecontext.isBraceWrappedContext }, ruleActionInsertSpace, .None),
        createRule("SpaceBeforeCloseBrace", anyToken, rule.toTokenRange(&[_]kind.Kind{.CloseBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionEnabledOrUndefined(rulecontext.insertSpaceAfterOpeningAndBeforeClosingNonemptyBracesOption), rulecontext.isBraceWrappedContext }, ruleActionInsertSpace, .None),
        createRule("NoSpaceBetweenEmptyBraceBrackets", rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), rule.toTokenRange(&[_]kind.Kind{.CloseBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isObjectContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceAfterOpenBrace", rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionDisabled(rulecontext.insertSpaceAfterOpeningAndBeforeClosingNonemptyBracesOption), rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceBeforeCloseBrace", anyToken, rule.toTokenRange(&[_]kind.Kind{.CloseBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionDisabled(rulecontext.insertSpaceAfterOpeningAndBeforeClosingNonemptyBracesOption), rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceBetweenEmptyBraceBrackets", rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), rule.toTokenRange(&[_]kind.Kind{.CloseBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceAfterOpeningAndBeforeClosingEmptyBracesOption) }, ruleActionInsertSpace, .None),
        createRule("NoSpaceBetweenEmptyBraceBrackets2", rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), rule.toTokenRange(&[_]kind.Kind{.CloseBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionDisabled(rulecontext.insertSpaceAfterOpeningAndBeforeClosingEmptyBracesOption), rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceAfterTemplateHeadAndMiddle", rule.toTokenRange(&[_]kind.Kind{ .TemplateHead, .TemplateMiddle }), anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceAfterOpeningAndBeforeClosingTemplateStringBracesOption), rulecontext.isNonJsxTextContext }, ruleActionInsertSpace, ruleFlagsCanDeleteNewLines),
        createRule("SpaceBeforeTemplateMiddleAndTail", anyToken, rule.toTokenRange(&[_]kind.Kind{ .TemplateMiddle, .TemplateTail }), &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceAfterOpeningAndBeforeClosingTemplateStringBracesOption), rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
        createRule("NoSpaceAfterTemplateHeadAndMiddle", rule.toTokenRange(&[_]kind.Kind{ .TemplateHead, .TemplateMiddle }), anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceAfterOpeningAndBeforeClosingTemplateStringBracesOption), rulecontext.isNonJsxTextContext }, ruleActionDeleteSpace, ruleFlagsCanDeleteNewLines),
        createRule("NoSpaceBeforeTemplateMiddleAndTail", anyToken, rule.toTokenRange(&[_]kind.Kind{ .TemplateMiddle, .TemplateTail }), &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceAfterOpeningAndBeforeClosingTemplateStringBracesOption), rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceAfterOpenBraceInJsxExpression", rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceAfterOpeningAndBeforeClosingJsxExpressionBracesOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isJsxExpressionContext }, ruleActionInsertSpace, .None),
        createRule("SpaceBeforeCloseBraceInJsxExpression", anyToken, rule.toTokenRange(&[_]kind.Kind{.CloseBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceAfterOpeningAndBeforeClosingJsxExpressionBracesOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isJsxExpressionContext }, ruleActionInsertSpace, .None),
        createRule("NoSpaceAfterOpenBraceInJsxExpression", rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceAfterOpeningAndBeforeClosingJsxExpressionBracesOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isJsxExpressionContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceBeforeCloseBraceInJsxExpression", anyToken, rule.toTokenRange(&[_]kind.Kind{.CloseBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceAfterOpeningAndBeforeClosingJsxExpressionBracesOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isJsxExpressionContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceAfterSemicolonInFor", rule.toTokenRange(&[_]kind.Kind{.SemicolonToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceAfterSemicolonInForStatementsOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isForContext }, ruleActionInsertSpace, .None),
        createRule("NoSpaceAfterSemicolonInFor", rule.toTokenRange(&[_]kind.Kind{.SemicolonToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceAfterSemicolonInForStatementsOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isForContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceBeforeBinaryOperator", anyToken, binaryOperators, &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceBeforeAndAfterBinaryOperatorsOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isBinaryOpContext }, ruleActionInsertSpace, .None),
        createRule("SpaceAfterBinaryOperator", binaryOperators, anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceBeforeAndAfterBinaryOperatorsOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isBinaryOpContext }, ruleActionInsertSpace, .None),
        createRule("NoSpaceBeforeBinaryOperator", anyToken, binaryOperators, &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceBeforeAndAfterBinaryOperatorsOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isBinaryOpContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceAfterBinaryOperator", binaryOperators, anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceBeforeAndAfterBinaryOperatorsOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isBinaryOpContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceBeforeOpenParenInFuncDecl", anyToken, rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceBeforeFunctionParenthesisOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isFunctionDeclContext }, ruleActionInsertSpace, .None),
        createRule("NoSpaceBeforeOpenParenInFuncDecl", anyToken, rule.toTokenRange(&[_]kind.Kind{.OpenParenToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceBeforeFunctionParenthesisOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isFunctionDeclContext }, ruleActionDeleteSpace, .None),

        createRule("NewLineBeforeOpenBraceInControl", controlOpenBraceLeftTokenRange, rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.placeOpenBraceOnNewLineForControlBlocksOption), rulecontext.isControlDeclContext, rulecontext.isBeforeMultilineBlockContext }, ruleActionInsertNewLine, ruleFlagsCanDeleteNewLines),
        createRule("NewLineBeforeOpenBraceInFunction", functionOpenBraceLeftTokenRange, rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.placeOpenBraceOnNewLineForFunctionsOption), rulecontext.isFunctionDeclContext, rulecontext.isBeforeMultilineBlockContext }, ruleActionInsertNewLine, ruleFlagsCanDeleteNewLines),
        createRule("NewLineBeforeOpenBraceInTypeScriptDeclWithBlock", typeScriptOpenBraceLeftTokenRange, rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.placeOpenBraceOnNewLineForFunctionsOption), rulecontext.isTypeScriptDeclWithBlockContext, rulecontext.isBeforeMultilineBlockContext }, ruleActionInsertNewLine, ruleFlagsCanDeleteNewLines),

        createRule("SpaceAfterTypeAssertion", rule.toTokenRange(&[_]kind.Kind{.GreaterThanToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceAfterTypeAssertionOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isTypeAssertionContext }, ruleActionInsertSpace, .None),
        createRule("NoSpaceAfterTypeAssertion", rule.toTokenRange(&[_]kind.Kind{.GreaterThanToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceAfterTypeAssertionOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isTypeAssertionContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceBeforeTypeAnnotation", anyToken, rule.toTokenRange(&[_]kind.Kind{ .QuestionToken, .ColonToken }), &[_]rule.ContextPredicate{ rulecontext.isOptionEnabled(rulecontext.insertSpaceBeforeTypeAnnotationOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isTypeAnnotationContext }, ruleActionInsertSpace, .None),
        createRule("NoSpaceBeforeTypeAnnotation", anyToken, rule.toTokenRange(&[_]kind.Kind{ .QuestionToken, .ColonToken }), &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefined(rulecontext.insertSpaceBeforeTypeAnnotationOption), rulecontext.isNonJsxSameLineTokenContext, rulecontext.isTypeAnnotationContext }, ruleActionDeleteSpace, .None),

        createRule("NoOptionalSemicolon", rule.toTokenRange(&[_]kind.Kind{.SemicolonToken}), anyTokenIncludingEOF, &[_]rule.ContextPredicate{ rulecontext.optionEqualsRemoveSemicolon, rulecontext.isSemicolonDeletionContext }, ruleActionDeleteToken, .None),
        createRule("OptionalSemicolon", anyToken, anyTokenIncludingEOF, &[_]rule.ContextPredicate{ rulecontext.optionEqualsInsertSemicolon, rulecontext.isSemicolonInsertionContext }, ruleActionInsertTrailingSemicolon, .None),
    };

    var anyTokenExceptAsyncCaseList: [400]kind.Kind = undefined;
    var len3: usize = 0;
    for (@intFromEnum(kind.Kind.Unknown)..@intFromEnum(kind.Kind.NotEmittedTypeElement)+1) |k| {
        const token: kind.Kind = @enumFromInt(k);
        if (token != .EndOfFile and token != .AsyncKeyword and token != .CaseKeyword) {
            anyTokenExceptAsyncCaseList[len3] = token;
            len3 += 1;
        }
    }
    const anyTokenExceptAsyncCase = rule.toTokenRangeAny(anyTokenExceptAsyncCaseList[0..len3]);

    const lowPriorityCommonRules = [_]rule.RuleSpec{
        createRule("NoSpaceBeforeSemicolon", anyToken, rule.toTokenRange(&[_]kind.Kind{.SemicolonToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceBeforeOpenBraceInControl", controlOpenBraceLeftTokenRange, rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefinedOrTokensOnSameLine(rulecontext.placeOpenBraceOnNewLineForControlBlocksOption), rulecontext.isControlDeclContext, rulecontext.isNotFormatOnEnter, rulecontext.isSameLineTokenOrBeforeBlockContext }, ruleActionInsertSpace, ruleFlagsCanDeleteNewLines),
        createRule("SpaceBeforeOpenBraceInFunction", functionOpenBraceLeftTokenRange, rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefinedOrTokensOnSameLine(rulecontext.placeOpenBraceOnNewLineForFunctionsOption), rulecontext.isFunctionDeclContext, rulecontext.isBeforeBlockContext, rulecontext.isNotFormatOnEnter, rulecontext.isSameLineTokenOrBeforeBlockContext }, ruleActionInsertSpace, ruleFlagsCanDeleteNewLines),
        createRule("SpaceBeforeOpenBraceInTypeScriptDeclWithBlock", typeScriptOpenBraceLeftTokenRange, rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isOptionDisabledOrUndefinedOrTokensOnSameLine(rulecontext.placeOpenBraceOnNewLineForFunctionsOption), rulecontext.isTypeScriptDeclWithBlockContext, rulecontext.isNotFormatOnEnter, rulecontext.isSameLineTokenOrBeforeBlockContext }, ruleActionInsertSpace, ruleFlagsCanDeleteNewLines),

        createRule("NoSpaceBeforeComma", anyToken, rule.toTokenRange(&[_]kind.Kind{.CommaToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),

        createRule("NoSpaceBeforeOpenBracket", anyTokenExceptAsyncCase, rule.toTokenRange(&[_]kind.Kind{.OpenBracketToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),
        createRule("NoSpaceAfterCloseBracket", rule.toTokenRange(&[_]kind.Kind{.CloseBracketToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isNotBeforeBlockInFunctionDeclarationContext }, ruleActionDeleteSpace, .None),
        createRule("SpaceAfterSemicolon", rule.toTokenRange(&[_]kind.Kind{.SemicolonToken}), anyToken, &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),

        createRule("SpaceBetweenForAndAwaitKeyword", rule.toTokenRange(&[_]kind.Kind{.ForKeyword}), rule.toTokenRange(&[_]kind.Kind{.AwaitKeyword}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
        createRule("SpaceBetweenDotDotDotAndTypeName", rule.toTokenRange(&[_]kind.Kind{.DotDotDotToken}), typeNames, &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionDeleteSpace, .None),

        createRule("SpaceBetweenStatements", rule.toTokenRange(&[_]kind.Kind{ .CloseParenToken, .DoKeyword, .ElseKeyword, .CaseKeyword }), anyToken, &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext, rulecontext.isNonJsxElementOrFragmentContext, rulecontext.isNotForContext }, ruleActionInsertSpace, .None),
        createRule("SpaceAfterTryCatchFinally", rule.toTokenRange(&[_]kind.Kind{ .TryKeyword, .CatchKeyword, .FinallyKeyword }), rule.toTokenRange(&[_]kind.Kind{.OpenBraceToken}), &[_]rule.ContextPredicate{ rulecontext.isNonJsxSameLineTokenContext }, ruleActionInsertSpace, .None),
    };

    const totalRulesLen = highPriorityCommonRules.len + userConfigurableRules.len + lowPriorityCommonRules.len;
    var rulesList = alloc.alloc(rule.RuleSpec, totalRulesLen) catch unreachable;
    
    @memcpy(rulesList[0..highPriorityCommonRules.len], &highPriorityCommonRules);
    @memcpy(rulesList[highPriorityCommonRules.len..highPriorityCommonRules.len + userConfigurableRules.len], &userConfigurableRules);
    @memcpy(rulesList[highPriorityCommonRules.len + userConfigurableRules.len..totalRulesLen], &lowPriorityCommonRules);

    allRules = rulesList;
    return allRules.?;
}

test "getAllRules compiles" {
    _ = getAllRules();
}
