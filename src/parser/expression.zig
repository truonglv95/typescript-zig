const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const ast = @import("../ast/ast.zig");
const jsx = @import("jsx.zig");
const core = @import("../core/core.zig");

pub fn isLeftHandSideExpression(p: *parser_pkg.Parser, expr: ast_gen.NodeIndex) bool {
    if (expr == 0) return false;
    const node = p.ast.nodes.get(expr);
    return switch (node) {
        .PropertyAccessExpression, .ElementAccessExpression, .NewExpression, .CallExpression, .JsxElement, .JsxSelfClosingElement, .JsxFragment, .TaggedTemplateExpression, .ArrayLiteralExpression, .ParenthesizedExpression, .ObjectLiteralExpression, .ClassExpression, .FunctionExpression, .Identifier, .PrivateIdentifier, .RegularExpressionLiteral, .NumericLiteral, .BigIntLiteral, .StringLiteral, .NoSubstitutionTemplateLiteral, .TemplateExpression, .FalseKeyword, .NullKeyword, .ThisKeyword, .TrueKeyword, .SuperKeyword, .NonNullExpression, .ExpressionWithTypeArguments, .MetaProperty, .ImportKeyword, .MissingDeclaration => true,
        else => false,
    };
}

const kind = @import("../ast/kind.zig");
const parser_pkg = @import("parser.zig");
const scanner_pkg = @import("../scanner/scanner.zig");
pub const OperatorPrecedence = enum(i32) {
    Invalid = -1,
    Comma = 0,
    Spread = 1,
    Assignment = 2,
    Conditional = 3,
    LogicalOR = 4,
    LogicalAND = 5,
    BitwiseOR = 6,
    BitwiseXOR = 7,
    BitwiseAND = 8,
    Equality = 9,
    Relational = 10,
    Shift = 11,
    Additive = 12,
    Multiplicative = 13,
    Exponentiation = 14,
    Unary = 15,
    Update = 16,
    LeftHandSide = 17,
    OptionalChain = 18,
    Member = 19,
    Primary = 20,
    Highest = 21,
};

pub fn getBinaryOperatorPrecedence(operatorKind: kind.Kind) OperatorPrecedence {
    switch (operatorKind) {
        kind.Kind.QuestionQuestionToken => return .Conditional,
        kind.Kind.BarBarToken => return .LogicalOR,
        kind.Kind.AmpersandAmpersandToken => return .LogicalAND,
        kind.Kind.BarToken => return .BitwiseOR,
        kind.Kind.CaretToken => return .BitwiseXOR,
        kind.Kind.AmpersandToken => return .BitwiseAND,
        kind.Kind.EqualsEqualsToken, kind.Kind.ExclamationEqualsToken, kind.Kind.EqualsEqualsEqualsToken, kind.Kind.ExclamationEqualsEqualsToken => return .Equality,
        kind.Kind.LessThanToken, kind.Kind.GreaterThanToken, kind.Kind.LessThanEqualsToken, kind.Kind.GreaterThanEqualsToken, kind.Kind.InstanceOfKeyword, kind.Kind.InKeyword, kind.Kind.AsKeyword, kind.Kind.SatisfiesKeyword => return .Relational,
        kind.Kind.LessThanLessThanToken, kind.Kind.GreaterThanGreaterThanToken, kind.Kind.GreaterThanGreaterThanGreaterThanToken => return .Shift,
        kind.Kind.PlusToken, kind.Kind.MinusToken => return .Additive,
        kind.Kind.AsteriskToken, kind.Kind.SlashToken, kind.Kind.PercentToken => return .Multiplicative,
        kind.Kind.AsteriskAsteriskToken => return .Exponentiation,
        else => return .Invalid,
    }
}

pub fn parseExpression(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    var expr = try parseAssignmentExpressionOrHigher(p);
    while (true) {
        const linesBeforeOperator: u8 = if (p.scanner.hasPrecedingLineBreak()) 1 else 0;
        if (!p.parseOptional(kind.Kind.CommaToken)) {
            break;
        }
        const linesAfterOperator: u8 = if (p.scanner.hasPrecedingLineBreak()) 1 else 0;

        const opNodeIndex = try p.ast.pushNode(.{ .CommaToken = void{} });
        const right = try parseAssignmentExpressionOrHigher(p);

        // Push CommaListExpression or BinaryExpression with Comma
        expr = try p.ast.pushNode(.{ .BinaryExpression = .{
            .Flags = 0,
            .Symbol = 0,
            .modifiers = null,
            .modifierFlags = 0,
            .Left = expr,
            .Type = null,
            .OperatorToken = opNodeIndex,
            .Right = right,
            .linesBeforeOperator = linesBeforeOperator,
            .linesAfterOperator = linesAfterOperator,
        } });
    }
    return expr;
}

pub fn isAssignmentOperator(token: kind.Kind) bool {
    return switch (token) {
        kind.Kind.EqualsToken, kind.Kind.PlusEqualsToken, kind.Kind.MinusEqualsToken, kind.Kind.AsteriskAsteriskEqualsToken, kind.Kind.AsteriskEqualsToken, kind.Kind.SlashEqualsToken, kind.Kind.PercentEqualsToken, kind.Kind.LessThanLessThanEqualsToken, kind.Kind.GreaterThanGreaterThanEqualsToken, kind.Kind.GreaterThanGreaterThanGreaterThanEqualsToken, kind.Kind.AmpersandEqualsToken, kind.Kind.BarEqualsToken, kind.Kind.BarBarEqualsToken, kind.Kind.AmpersandAmpersandEqualsToken, kind.Kind.QuestionQuestionEqualsToken, kind.Kind.CaretEqualsToken => true,
        else => false,
    };
}

pub fn parseAssignmentExpressionOrHigher(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    // YieldExpression
    if (p.token == kind.Kind.YieldKeyword) {
        const start_pos = p.scanner.state.tokenStart;
        p.nextToken();
        var asteriskToken: ?u32 = null;
        if (p.parseOptional(kind.Kind.AsteriskToken)) {
            asteriskToken = try p.ast.pushTokenNode(kind.Kind.AsteriskToken);
        }

        var yieldExpr: ?u32 = null;
        if (!p.scanner.hasPrecedingLineBreak() and p.token != kind.Kind.ColonToken and p.token != kind.Kind.CommaToken and p.token != kind.Kind.CloseBraceToken and p.token != kind.Kind.CloseBracketToken and p.token != kind.Kind.CloseParenToken) {
            if (p.token != kind.Kind.EndOfFile) {
                yieldExpr = try parseAssignmentExpressionOrHigher(p);
            }
        }

        const node = try p.ast.pushNode(.{ .YieldExpression = .{
            .Flags = 0,
            .AsteriskToken = asteriskToken,
            .Expression = yieldExpr,
        } });
        p.setNodeStartPos(node, start_pos);
        return node;
    }

    if (p.token == kind.Kind.LessThanToken or p.token == kind.Kind.OpenParenToken or p.token == kind.Kind.AsyncKeyword) {
        if (tryParseParenthesizedArrowFunctionExpression(p, true)) |arrowExpression| {
            return arrowExpression;
        }

        if (tryParseAsyncSimpleArrowFunctionExpression(p, true)) |asyncArrow| {
            return asyncArrow;
        }
    }

    const expr = try parseBinaryExpressionOrHigher(p, .Invalid);

    if (p.token == kind.Kind.EqualsGreaterThanToken) {
        // Simple Arrow function (e.g. `x => x`)
        return try parseSimpleArrowFunctionExpression(p, expr, true, null);
    }

    if (isLeftHandSideExpression(p, expr) and isAssignmentOperator(p.reScanGreaterThanToken())) {
        const opKind = p.token;
        var opTokenNode: ast_gen.NodeIndex = 0;
        switch (opKind) {
            .EqualsToken => opTokenNode = try p.ast.pushNode(.{ .EqualsToken = void{} }),
            .PlusEqualsToken => opTokenNode = try p.ast.pushNode(.{ .PlusEqualsToken = void{} }),
            .MinusEqualsToken => opTokenNode = try p.ast.pushNode(.{ .MinusEqualsToken = void{} }),
            .AsteriskAsteriskEqualsToken => opTokenNode = try p.ast.pushNode(.{ .AsteriskAsteriskEqualsToken = void{} }),
            .AsteriskEqualsToken => opTokenNode = try p.ast.pushNode(.{ .AsteriskEqualsToken = void{} }),
            .SlashEqualsToken => opTokenNode = try p.ast.pushNode(.{ .SlashEqualsToken = void{} }),
            .PercentEqualsToken => opTokenNode = try p.ast.pushNode(.{ .PercentEqualsToken = void{} }),
            .AmpersandEqualsToken => opTokenNode = try p.ast.pushNode(.{ .AmpersandEqualsToken = void{} }),
            .BarEqualsToken => opTokenNode = try p.ast.pushNode(.{ .BarEqualsToken = void{} }),
            .CaretEqualsToken => opTokenNode = try p.ast.pushNode(.{ .CaretEqualsToken = void{} }),
            .LessThanLessThanEqualsToken => opTokenNode = try p.ast.pushNode(.{ .LessThanLessThanEqualsToken = void{} }),
            .GreaterThanGreaterThanGreaterThanEqualsToken => opTokenNode = try p.ast.pushNode(.{ .GreaterThanGreaterThanGreaterThanEqualsToken = void{} }),
            .GreaterThanGreaterThanEqualsToken => opTokenNode = try p.ast.pushNode(.{ .GreaterThanGreaterThanEqualsToken = void{} }),
            .BarBarEqualsToken => opTokenNode = try p.ast.pushNode(.{ .BarBarEqualsToken = void{} }),
            .AmpersandAmpersandEqualsToken => opTokenNode = try p.ast.pushNode(.{ .AmpersandAmpersandEqualsToken = void{} }),
            .QuestionQuestionEqualsToken => opTokenNode = try p.ast.pushNode(.{ .QuestionQuestionEqualsToken = void{} }),
            else => opTokenNode = try p.ast.pushTokenNode(opKind),
        }

        p.nextToken();
        const right = try parseAssignmentExpressionOrHigher(p);

        return p.ast.pushNode(.{ .BinaryExpression = .{
            .Flags = 0,
            .Symbol = 0,
            .modifiers = null,
            .modifierFlags = 0,
            .Left = expr,
            .Type = null,
            .OperatorToken = opTokenNode,
            .Right = right,
            .linesBeforeOperator = 0,
            .linesAfterOperator = 0,
        } });
    }

    const linesBeforeQuestion: u8 = if (p.scanner.hasPrecedingLineBreak()) 1 else 0;
    if (p.parseOptional(kind.Kind.QuestionToken)) {
        const cond_pos = if (expr != 0 and expr < p.ast.positions.items.len and p.ast.positions.items[expr].pos != 0)
            p.ast.positions.items[expr].pos
        else
            @as(u32, @intCast(p.scanner.state.tokenStart));
        const questionTokenNode = try p.ast.pushNode(.{ .QuestionToken = void{} });
        const linesAfterQuestion: u8 = if (p.scanner.hasPrecedingLineBreak()) 1 else 0;
        const trueBranch = try parseAssignmentExpressionOrHigher(p);
        const linesBeforeColon: u8 = if (p.scanner.hasPrecedingLineBreak()) 1 else 0;
        _ = p.parseExpected(kind.Kind.ColonToken);
        const colonTokenNode = try p.ast.pushNode(.{ .ColonToken = void{} });
        const linesAfterColon: u8 = if (p.scanner.hasPrecedingLineBreak()) 1 else 0;
        const falseBranch = try parseAssignmentExpressionOrHigher(p);

        const node = try p.ast.pushNode(.{ .ConditionalExpression = .{
            .Flags = 0,
            .Condition = expr,
            .QuestionToken = questionTokenNode,
            .WhenTrue = trueBranch,
            .ColonToken = colonTokenNode,
            .WhenFalse = falseBranch,
            .linesBeforeQuestion = linesBeforeQuestion,
            .linesAfterQuestion = linesAfterQuestion,
            .linesBeforeColon = linesBeforeColon,
            .linesAfterColon = linesAfterColon,
        } });
        p.setNodeStartPos(node, cond_pos);
        return node;
    }

    return expr;
}

pub fn parseBinaryExpressionOrHigher(p: *parser_pkg.Parser, precedence: OperatorPrecedence) anyerror!ast_gen.NodeIndex {
    var leftOperand = try parseUnaryExpressionOrHigher(p);
    var lastOperand = leftOperand;

    while (true) {
        const operator = p.reScanGreaterThanToken();
        const newPrecedence = getBinaryOperatorPrecedence(operator);

        var consumeCurrentOperator = false;
        if (operator == kind.Kind.AsteriskAsteriskToken) {
            consumeCurrentOperator = @intFromEnum(newPrecedence) >= @intFromEnum(precedence);
        } else {
            consumeCurrentOperator = @intFromEnum(newPrecedence) > @intFromEnum(precedence);
        }

        if (!consumeCurrentOperator) {
            break;
        }

        if (operator == kind.Kind.InKeyword and p.disallowInContext) {
            break;
        }

        var opNodeIndex: ast_gen.NodeIndex = 0;
        if (operator != kind.Kind.AsKeyword and operator != kind.Kind.SatisfiesKeyword) {
            switch (operator) {
                .PlusToken => opNodeIndex = try p.ast.pushNode(.{ .PlusToken = void{} }),
                .MinusToken => opNodeIndex = try p.ast.pushNode(.{ .MinusToken = void{} }),
                .AsteriskToken => opNodeIndex = try p.ast.pushNode(.{ .AsteriskToken = void{} }),
                .SlashToken => opNodeIndex = try p.ast.pushNode(.{ .SlashToken = void{} }),
                .PercentToken => opNodeIndex = try p.ast.pushNode(.{ .PercentToken = void{} }),
                .AsteriskAsteriskToken => opNodeIndex = try p.ast.pushNode(.{ .AsteriskAsteriskToken = void{} }),
                .LessThanLessThanToken => opNodeIndex = try p.ast.pushNode(.{ .LessThanLessThanToken = void{} }),
                .GreaterThanGreaterThanToken => opNodeIndex = try p.ast.pushNode(.{ .GreaterThanGreaterThanToken = void{} }),
                .GreaterThanGreaterThanGreaterThanToken => opNodeIndex = try p.ast.pushNode(.{ .GreaterThanGreaterThanGreaterThanToken = void{} }),
                .AmpersandToken => opNodeIndex = try p.ast.pushNode(.{ .AmpersandToken = void{} }),
                .BarToken => opNodeIndex = try p.ast.pushNode(.{ .BarToken = void{} }),
                .CaretToken => opNodeIndex = try p.ast.pushNode(.{ .CaretToken = void{} }),
                .LessThanToken => opNodeIndex = try p.ast.pushNode(.{ .LessThanToken = void{} }),
                .GreaterThanToken => opNodeIndex = try p.ast.pushNode(.{ .GreaterThanToken = void{} }),
                .LessThanEqualsToken => opNodeIndex = try p.ast.pushNode(.{ .LessThanEqualsToken = void{} }),
                .GreaterThanEqualsToken => opNodeIndex = try p.ast.pushNode(.{ .GreaterThanEqualsToken = void{} }),
                .EqualsEqualsToken => opNodeIndex = try p.ast.pushNode(.{ .EqualsEqualsToken = void{} }),
                .ExclamationEqualsToken => opNodeIndex = try p.ast.pushNode(.{ .ExclamationEqualsToken = void{} }),
                .EqualsEqualsEqualsToken => opNodeIndex = try p.ast.pushNode(.{ .EqualsEqualsEqualsToken = void{} }),
                .ExclamationEqualsEqualsToken => opNodeIndex = try p.ast.pushNode(.{ .ExclamationEqualsEqualsToken = void{} }),
                .AmpersandAmpersandToken => opNodeIndex = try p.ast.pushNode(.{ .AmpersandAmpersandToken = void{} }),
                .BarBarToken => opNodeIndex = try p.ast.pushNode(.{ .BarBarToken = void{} }),
                .QuestionQuestionToken => opNodeIndex = try p.ast.pushNode(.{ .QuestionQuestionToken = void{} }),
                .InKeyword => opNodeIndex = try p.ast.pushNode(.{ .InKeyword = void{} }),
                .InstanceOfKeyword => opNodeIndex = try p.ast.pushNode(.{ .InstanceOfKeyword = void{} }),
                else => opNodeIndex = try p.ast.pushTokenNode(operator),
            }
        }

        if (operator == kind.Kind.AsKeyword or operator == kind.Kind.SatisfiesKeyword) {
            var lastPrecedence = OperatorPrecedence.Highest;
            const leftNode = p.ast.getNode(lastOperand);
            if (leftNode == .BinaryExpression) {
                const opToken = p.ast.getNode(leftNode.BinaryExpression.OperatorToken);
                lastPrecedence = getBinaryOperatorPrecedence(std.meta.activeTag(opToken));
            }

            const cast_start = p.scanner.state.tokenStart;
            p.nextToken();
            const typeNode = try p.parseType();

            if (operator == kind.Kind.SatisfiesKeyword) {
                leftOperand = try p.ast.pushNode(.{ .SatisfiesExpression = .{
                    .Flags = 0,
                    .Expression = leftOperand,
                    .Type = typeNode,
                } });
                p.setNodeStartPos(leftOperand, cast_start);
            } else {
                leftOperand = try p.ast.pushNode(.{ .AsExpression = .{
                    .Flags = 0,
                    .Expression = leftOperand,
                    .Type = typeNode,
                } });
                p.setNodeStartPos(leftOperand, cast_start);
            }

            if (@intFromEnum(getBinaryOperatorPrecedence(p.reScanGreaterThanToken())) > @intFromEnum(lastPrecedence)) {
                break;
            }

            continue;
        }

        const linesBeforeOperator: u8 = if (p.scanner.hasPrecedingLineBreak()) 1 else 0;
        p.nextToken();
        const linesAfterOperator: u8 = if (p.scanner.hasPrecedingLineBreak()) 1 else 0;
        const rightOperand = try parseBinaryExpressionOrHigher(p, newPrecedence);
        leftOperand = try p.ast.pushNode(.{ .BinaryExpression = .{
            .Flags = 0,
            .Symbol = 0,
            .modifiers = null,
            .modifierFlags = 0,
            .Left = leftOperand,
            .Type = null,
            .OperatorToken = opNodeIndex,
            .Right = rightOperand,
            .linesBeforeOperator = linesBeforeOperator,
            .linesAfterOperator = linesAfterOperator,
        } });
        lastOperand = leftOperand;
    }

    return leftOperand;
}

pub fn isUpdateExpression(p: *parser_pkg.Parser) bool {
    switch (p.token) {
        kind.Kind.PlusToken, kind.Kind.MinusToken, kind.Kind.TildeToken, kind.Kind.ExclamationToken, kind.Kind.DeleteKeyword, kind.Kind.TypeOfKeyword, kind.Kind.VoidKeyword, kind.Kind.AwaitKeyword, kind.Kind.LessThanToken => return false,
        else => return true,
    }
}

pub fn parseUpdateExpression(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    if (p.token == kind.Kind.PlusPlusToken or p.token == kind.Kind.MinusMinusToken) {
        const start_pos = p.scanner.state.tokenStart;
        const operator = p.token;
        p.nextToken();
        const expr = try parseLeftHandSideExpressionOrHigher(p);
        const node = try p.ast.pushNode(.{ .PrefixUnaryExpression = .{ .Flags = 0, .Operator = @intFromEnum(operator), .Operand = expr } });
        p.setNodeStartPos(node, start_pos);
        return node;
    } else if (p.languageVariant == .JSX and p.token == kind.Kind.LessThanToken and p.lookAhead(parser_pkg.Parser.nextTokenIsIdentifierOrKeywordOrGreaterThan)) {
        return jsx.parseJsxElementOrSelfClosingElementOrFragment(p, true, -1, null, false);
    }

    var expression = try parseLeftHandSideExpressionOrHigher(p);

    while (true) {
        if (p.token == kind.Kind.ExclamationToken and !p.scanner.hasPrecedingLineBreak()) {
            const start_pos = p.scanner.state.tokenStart;
            p.nextToken();
            expression = try p.ast.pushNode(.{ .NonNullExpression = .{ .Flags = 0, .Expression = expression } });
            p.setNodeStartPos(expression, start_pos);
        } else if ((p.token == kind.Kind.PlusPlusToken or p.token == kind.Kind.MinusMinusToken) and !p.scanner.hasPrecedingLineBreak()) {
            const start_pos = p.scanner.state.tokenStart;
            const operator = p.token;
            p.nextToken();
            expression = try p.ast.pushNode(.{ .PostfixUnaryExpression = .{ .Flags = 0, .Operand = expression, .Operator = @intFromEnum(operator) } });
            p.setNodeStartPos(expression, start_pos);
        } else {
            break;
        }
    }

    return expression;
}

pub fn parsePrefixUnaryExpression(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    const start_pos = p.scanner.state.tokenStart;
    const operator = p.token;
    p.nextToken();
    const expr = try parseSimpleUnaryExpression(p);
    const node = try p.ast.pushNode(.{ .PrefixUnaryExpression = .{ .Flags = 0, .Operator = @intFromEnum(operator), .Operand = expr } });
    p.setNodeStartPos(node, start_pos);
    return node;
}

pub fn parseSimpleUnaryExpression(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    switch (p.token) {
        kind.Kind.PlusToken, kind.Kind.MinusToken, kind.Kind.TildeToken, kind.Kind.ExclamationToken => return parsePrefixUnaryExpression(p),
        kind.Kind.DeleteKeyword => {
            const start_pos = p.scanner.state.tokenStart;
            p.nextToken();
            const expr = try parseSimpleUnaryExpression(p);
            const node = try p.ast.pushNode(.{ .DeleteExpression = .{ .Flags = 0, .Expression = expr } });
            p.setNodeStartPos(node, start_pos);
            return node;
        },
        kind.Kind.TypeOfKeyword => {
            const start_pos = p.scanner.state.tokenStart;
            p.nextToken();
            const expr = try parseSimpleUnaryExpression(p);
            const node = try p.ast.pushNode(.{ .TypeOfExpression = .{ .Flags = 0, .Expression = expr } });
            p.setNodeStartPos(node, start_pos);
            return node;
        },
        kind.Kind.VoidKeyword => {
            const start_pos = p.scanner.state.tokenStart;
            p.nextToken();
            const expr = try parseSimpleUnaryExpression(p);
            const node = try p.ast.pushNode(.{ .VoidExpression = .{ .Flags = 0, .Expression = expr } });
            p.setNodeStartPos(node, start_pos);
            return node;
        },
        kind.Kind.AwaitKeyword => {
            const start_pos = p.scanner.state.tokenStart;
            p.nextToken();
            const expr = try parseSimpleUnaryExpression(p);
            const node = try p.ast.pushNode(.{ .AwaitExpression = .{ .Flags = 0, .Expression = expr } });
            p.setNodeStartPos(node, start_pos);
            return node;
        },
        kind.Kind.LessThanToken => {
            if (p.languageVariant == .JSX) {
                return jsx.parseJsxElementOrSelfClosingElementOrFragment(p, true, -1, null, true);
            }
            const start_pos = p.scanner.state.tokenStart;
            _ = p.parseExpected(kind.Kind.LessThanToken);
            const typeNode = p.parseType() catch 0;
            _ = p.parseExpected(kind.Kind.GreaterThanToken);
            const expr = try parseSimpleUnaryExpression(p);
            const node = try p.ast.pushNode(.{ .TypeAssertionExpression = .{ .Flags = 0, .Type = typeNode, .Expression = expr } });
            p.setNodeStartPos(node, start_pos);
            return node;
        },
        else => return parseUpdateExpression(p),
    }
}

pub fn parseUnaryExpressionOrHigher(p: *parser_pkg.Parser) !ast_gen.NodeIndex {
    if (isUpdateExpression(p)) {
        return try parseUpdateExpression(p);
    }
    const simpleUnaryExpression = try parseSimpleUnaryExpression(p);
    return simpleUnaryExpression;
}

pub fn parseMemberExpressionOrHigher(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    const expr = try parsePrimaryExpression(p);
    return parseMemberExpressionRest(p, expr, true);
}

fn isStartOfOptionalPropertyOrElementAccessChain(p: *parser_pkg.Parser) bool {
    if (p.token != kind.Kind.QuestionDotToken) return false;
    const snapshot = p.mark();
    defer p.rewind(snapshot);
    p.nextToken();
    return p.token == kind.Kind.OpenBracketToken or p.isIdentifier() or kind.isKeyword(p.token) or p.token == kind.Kind.NoSubstitutionTemplateLiteral or p.token == kind.Kind.TemplateHead;
}

pub fn parseMemberExpressionRest(p: *parser_pkg.Parser, expression: ast_gen.NodeIndex, allowOptionalChain: bool) anyerror!ast_gen.NodeIndex {
    var currentExpr = expression;
    while (true) {
        var questionDotToken: ?ast_gen.NodeIndex = null;
        var isPropertyAccess = false;
        const hasNewlineBeforeDot = p.scanner.hasPrecedingLineBreak();

        if (allowOptionalChain and isStartOfOptionalPropertyOrElementAccessChain(p)) {
            questionDotToken = try p.ast.pushNode(.{ .QuestionDotToken = void{} });
            p.nextToken();
            isPropertyAccess = p.isIdentifier() or kind.isKeyword(p.token);
        } else {
            isPropertyAccess = p.parseOptional(kind.Kind.DotToken);
        }

        if (isPropertyAccess) {
            const access_start = p.scanner.state.tokenStart;
            var right: ast_gen.NodeIndex = 0;
            var hasNewlineAfterDot = false;
            if (p.token == kind.Kind.PrivateIdentifier) {
                hasNewlineAfterDot = p.scanner.hasPrecedingLineBreak();
                const text = p.scanner.state.tokenValue;
                const start_pos = p.scanner.state.tokenStart;
                const end_pos = p.scanner.getTokenEnd();
                p.nextToken();
                right = try p.ast.pushNode(.{ .PrivateIdentifier = .{ .Flags = 0, .Text = text } });
                p.ast.positions.items[right] = .{ .pos = @intCast(start_pos), .end = @intCast(end_pos) };
            } else {
                hasNewlineAfterDot = p.scanner.hasPrecedingLineBreak();
                right = try p.parseIdentifierName();
            }
            const flags = (if (hasNewlineBeforeDot) @as(u32, 1) << 31 else 0) | (if (hasNewlineAfterDot) @as(u32, 1) << 30 else 0);
            currentExpr = try p.ast.pushNode(.{ .PropertyAccessExpression = .{
                .Flags = flags,
                .Expression = currentExpr,
                .QuestionDotToken = questionDotToken,
                .name = right,
            } });
            p.setNodeStartPos(currentExpr, access_start);
            continue;
        }

        if (questionDotToken != null or p.token == kind.Kind.OpenBracketToken) {
            const access_start = p.scanner.state.tokenStart;
            if (questionDotToken == null) {
                p.nextToken();
            } else {
                if (p.token == kind.Kind.OpenBracketToken) p.nextToken();
            }

            const arg = try parseExpression(p);
            _ = p.parseExpected(kind.Kind.CloseBracketToken);
            currentExpr = try p.ast.pushNode(.{ .ElementAccessExpression = .{
                .Flags = 0,
                .Expression = currentExpr,
                .QuestionDotToken = questionDotToken,
                .ArgumentExpression = arg,
            } });
            p.setNodeStartPos(currentExpr, access_start);
            continue;
        }

        break;
    }
    return currentExpr;
}

pub fn parseCallExpressionRest(p: *parser_pkg.Parser, expression: ast_gen.NodeIndex) anyerror!ast_gen.NodeIndex {
    var currentExpr = expression;
    while (true) {
        currentExpr = try parseMemberExpressionRest(p, currentExpr, true);

        var typeArguments: ?ast_gen.NodeListIndex = null;
        var questionDotToken: ?ast_gen.NodeIndex = null;

        if (p.token == kind.Kind.QuestionDotToken) {
            questionDotToken = try p.ast.pushNode(.{ .QuestionDotToken = void{} });
            p.nextToken();
        }

        if (p.token == kind.Kind.LessThanToken) {
            const mark = p.mark();
            typeArguments = p.parseTypeArguments() catch null;

            if (typeArguments == null or (p.token != kind.Kind.OpenParenToken and p.token != kind.Kind.NoSubstitutionTemplateLiteral and p.token != kind.Kind.TemplateHead)) {
                // Not a call expression, rollback!
                p.rewind(mark);
                typeArguments = null;
            }
        }

        if (p.token == kind.Kind.NoSubstitutionTemplateLiteral or p.token == kind.Kind.TemplateHead) {
            currentExpr = try parseTaggedTemplateRest(p, currentExpr, questionDotToken, typeArguments);
            continue;
        }

        if (p.token == kind.Kind.OpenParenToken) {
            const call_start = p.scanner.state.tokenStart;
            p.nextToken();

            const argsList = p.parseDelimitedList(.ArgumentExpressions, parseArgumentExpressionWrapper);

            _ = p.parseExpected(kind.Kind.CloseParenToken);

            currentExpr = try p.ast.pushNode(.{ .CallExpression = .{
                .Flags = 0,
                .Symbol = 0,
                .Expression = currentExpr,
                .QuestionDotToken = questionDotToken,
                .TypeArguments = typeArguments,
                .Arguments = argsList,
            } });
            p.setNodeStartPos(currentExpr, call_start);
            continue;
        }

        break;
    }
    return currentExpr;
}

pub fn parseTaggedTemplateRest(p: *parser_pkg.Parser, tag: ast_gen.NodeIndex, questionDotToken: ?ast_gen.NodeIndex, typeArguments: ?ast_gen.NodeListIndex) anyerror!ast_gen.NodeIndex {
    const start_pos = p.scanner.state.tokenStart;
    var template: ast_gen.NodeIndex = 0;
    if (p.token == kind.Kind.NoSubstitutionTemplateLiteral) {
        p.token = p.scanner.reScanTemplateToken(true);
        template = try parseLiteralExpression(p);
    } else {
        template = try parseTemplateExpression(p, true);
    }

    const node = try p.ast.pushNode(.{ .TaggedTemplateExpression = .{
        .Flags = 0,
        .Tag = tag,
        .QuestionDotToken = questionDotToken orelse 0,
        .TypeArguments = typeArguments,
        .Template = template,
    } });
    p.setNodeStartPos(node, start_pos);
    return node;
}

pub fn parseLeftHandSideExpressionOrHigher(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    var expression: ast_gen.NodeIndex = 0;

    // Simplification of Import, Super, Member logic
    if (p.token == kind.Kind.SuperKeyword) {
        p.nextToken();
        expression = try p.ast.pushNode(.{ .SuperKeyword = void{} });
    } else {
        expression = try parseMemberExpressionOrHigher(p);
    }

    return parseCallExpressionRest(p, expression);
}

pub fn parseLiteralExpression(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    const start_pos = p.scanner.state.tokenStart;
    const end_pos = p.scanner.getTokenEnd();
    const text = p.scanner.state.tokenValue;
    const tokenFlags = p.scanner.state.tokenFlags; // Assuming this exists or similar
    const token = p.token;
    p.nextToken();

    const nodeIndex = switch (token) {
        kind.Kind.StringLiteral => try p.ast.pushNode(.{ .StringLiteral = .{ .Flags = 0, .TokenFlags = tokenFlags, .Text = text } }),
        kind.Kind.NumericLiteral => try p.ast.pushNode(.{ .NumericLiteral = .{ .Flags = 0, .TokenFlags = tokenFlags, .Text = text } }),
        kind.Kind.BigIntLiteral => try p.ast.pushNode(.{ .BigIntLiteral = .{ .Flags = 0, .TokenFlags = tokenFlags, .Text = text } }),
        kind.Kind.RegularExpressionLiteral => try p.ast.pushNode(.{ .RegularExpressionLiteral = .{ .Flags = 0, .TokenFlags = tokenFlags, .Text = text } }),
        kind.Kind.NoSubstitutionTemplateLiteral => try p.ast.pushNode(.{ .NoSubstitutionTemplateLiteral = .{ .Flags = 0, .TokenFlags = tokenFlags, .Text = text, .RawText = text, .TemplateFlags = @as(u16, @intCast(tokenFlags & 0xFFFF)), .Symbol = 0 } }),
        else => return error.InvalidLiteral,
    };
    if (nodeIndex < p.ast.positions.items.len) {
        p.ast.positions.items[nodeIndex] = .{ .pos = @intCast(start_pos), .end = @intCast(end_pos) };
    }
    return nodeIndex;
}

pub fn parseArgumentExpressionWrapper(p: *parser_pkg.Parser) ast_gen.NodeIndex {
    if (p.token == kind.Kind.DotDotDotToken) {
        p.nextToken();
        const expr = parseAssignmentExpressionOrHigher(p) catch return 0;
        return p.ast.pushNode(.{ .SpreadElement = .{ .Flags = 0, .Expression = expr } }) catch 0;
    }
    return parseAssignmentExpressionOrHigher(p) catch 0;
}

pub fn parseArgumentOrArrayLiteralElement(p: *parser_pkg.Parser) ast_gen.NodeIndex {
    if (p.token == kind.Kind.CommaToken) {
        return p.ast.pushNode(.{ .OmittedExpression = .{ .Flags = 0 } }) catch 0;
    }
    if (p.token == kind.Kind.DotDotDotToken) {
        p.nextToken();
        const expr = parseAssignmentExpressionOrHigher(p) catch return 0;
        return p.ast.pushNode(.{ .SpreadElement = .{ .Flags = 0, .Expression = expr } }) catch 0;
    }
    return parseAssignmentExpressionOrHigher(p) catch 0;
}

pub fn parseArrayLiteralExpression(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    const start_pos = p.scanner.state.tokenStart;
    _ = p.parseExpected(kind.Kind.OpenBracketToken);

    var multiLine: u8 = if (p.scanner.hasPrecedingLineBreak()) 1 else 0;

    const elementsList = p.parseDelimitedList(.ArrayLiteralMembers, parseArgumentOrArrayLiteralElement);

    if (p.scanner.hasPrecedingLineBreak()) {
        multiLine = 1;
    }

    _ = p.parseExpected(kind.Kind.CloseBracketToken);

    const node = try p.ast.pushNode(.{ .ArrayLiteralExpression = .{ .Flags = 0, .Elements = elementsList, .MultiLine = multiLine } });
    p.setNodeStartPos(node, start_pos);
    return node;
}

pub fn parseObjectLiteralElementWrapper(p: *parser_pkg.Parser) ast_gen.NodeIndex {
    return parseObjectLiteralElement(p) catch 0;
}

pub fn parseObjectLiteralExpression(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    const start_pos = p.scanner.state.tokenStart;
    _ = p.parseExpected(kind.Kind.OpenBraceToken);

    var multiLine: u8 = if (p.scanner.hasPrecedingLineBreak()) 1 else 0;

    const propertiesList = p.parseDelimitedList(.ObjectLiteralMembers, parseObjectLiteralElementWrapper);

    if (p.scanner.hasPrecedingLineBreak()) {
        multiLine = 1;
    }

    _ = p.parseExpected(kind.Kind.CloseBraceToken);

    const node = try p.ast.pushNode(.{ .ObjectLiteralExpression = .{ .Flags = 0, .Symbol = 0, .Properties = propertiesList, .MultiLine = multiLine } });
    p.setNodeStartPos(node, start_pos);
    return node;
}

pub fn parseObjectLiteralElement(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    const element_start = p.scanner.state.tokenStart;
    if (p.parseOptional(kind.Kind.DotDotDotToken)) {
        const expr = try parseAssignmentExpressionOrHigher(p);
        const node = try p.ast.pushNode(.{ .SpreadAssignment = .{ .Flags = 0, .Symbol = 0, .Expression = expr } });
        p.setNodeStartPos(node, element_start);
        return node;
    }

    var isGet = false;
    var isSet = false;
    if (p.token == kind.Kind.GetKeyword) {
        var tempScanner = p.scanner;
        const tok = tempScanner.scan();
        if (@intFromEnum(tok) >= 79 or tok == kind.Kind.StringLiteral or tok == kind.Kind.NumericLiteral or tok == kind.Kind.BigIntLiteral or tok == kind.Kind.OpenBracketToken) {
            isGet = true;
            p.nextToken();
        }
    } else if (p.token == kind.Kind.SetKeyword) {
        var tempScanner = p.scanner;
        const tok = tempScanner.scan();
        if (@intFromEnum(tok) >= 79 or tok == kind.Kind.StringLiteral or tok == kind.Kind.NumericLiteral or tok == kind.Kind.BigIntLiteral or tok == kind.Kind.OpenBracketToken) {
            isSet = true;
            p.nextToken();
        }
    }

    const name = try p.parsePropertyName();

    if (p.token == kind.Kind.ColonToken) {
        // PropertyAssignment
        p.nextToken();
        const initializer = try parseAssignmentExpressionOrHigher(p);
        const node = try p.ast.pushNode(.{ .PropertyAssignment = .{
            .Flags = 0,
            .Symbol = 0,
            .modifiers = null,
            .modifierFlags = 0,
            .name = name,
            .PostfixToken = null,
            .Type = 0,
            .Initializer = initializer,
        } });
        p.setNodeStartPos(node, element_start);
        return node;
    } else if (p.token == kind.Kind.OpenParenToken or p.token == kind.Kind.LessThanToken) {
        if (isGet) {
            const typeParameters = try p.parseTypeParameters();
            const parameters = try p.parseParameters();
            const returnType = try p.parseReturnTypeAnnotation();
            const body = try p.parseBlock();
            const node = try p.ast.pushNode(.{ .GetAccessor = .{
                .Flags = 0,
                .Symbol = 0,
                .modifiers = null,
                .modifierFlags = 0,
                .name = name,
                .TypeParameters = typeParameters,
                .Parameters = parameters,
                .Type = returnType orelse 0,
                .Body = body,
                .PostfixToken = 0,
                .FullSignature = null,
                .AsteriskToken = 0,
            } });
            p.setNodeStartPos(node, element_start);
            return node;
        } else if (isSet) {
            const typeParameters = try p.parseTypeParameters();
            const parameters = try p.parseParameters();
            const returnType = try p.parseReturnTypeAnnotation();
            const body = try p.parseBlock();
            const node = try p.ast.pushNode(.{ .SetAccessor = .{
                .Flags = 0,
                .Symbol = 0,
                .modifiers = null,
                .modifierFlags = 0,
                .name = name,
                .TypeParameters = typeParameters,
                .Parameters = parameters,
                .Type = returnType orelse 0,
                .Body = body,
                .PostfixToken = 0,
                .FullSignature = null,
                .AsteriskToken = 0,
            } });
            p.setNodeStartPos(node, element_start);
            return node;
        } else {
            return p.parseMethodDeclaration(null, 0, null, name, null, element_start);
        }
    } else {
        // ShorthandPropertyAssignment
        var equalsToken: ?ast_gen.NodeIndex = null;
        var initializer: ?ast_gen.NodeIndex = null;
        if (p.parseOptional(kind.Kind.EqualsToken)) {
            equalsToken = try p.ast.pushTokenNode(kind.Kind.EqualsToken);
            initializer = try parseAssignmentExpressionOrHigher(p);
        }
        const node = try p.ast.pushNode(.{ .ShorthandPropertyAssignment = .{
            .Flags = 0,
            .Symbol = 0,
            .modifiers = null,
            .modifierFlags = 0,
            .name = name,
            .PostfixToken = null,
            .Type = 0,
            .EqualsToken = equalsToken,
            .ObjectAssignmentInitializer = initializer,
        } });
        p.setNodeStartPos(node, element_start);
        return node;
    }
}

pub fn parseKeywordExpression(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    const start_pos = p.scanner.state.tokenStart;
    const token = p.token;
    p.nextToken();
    const node = switch (token) {
        kind.Kind.ThisKeyword => try p.ast.pushNode(.{ .ThisKeyword = void{} }),
        kind.Kind.SuperKeyword => try p.ast.pushNode(.{ .SuperKeyword = void{} }),
        kind.Kind.NullKeyword => try p.ast.pushNode(.{ .NullKeyword = void{} }),
        kind.Kind.TrueKeyword => try p.ast.pushNode(.{ .TrueKeyword = void{} }),
        kind.Kind.FalseKeyword => try p.ast.pushNode(.{ .FalseKeyword = void{} }),
        kind.Kind.ImportKeyword => try p.ast.pushNode(.{ .ImportKeyword = void{} }),
        else => return error.InvalidKeywordExpression,
    };
    p.setNodeStartPos(node, start_pos);
    return node;
}

pub fn parseNewExpressionOrNewDotTarget(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    const start_pos = p.scanner.state.tokenStart;
    _ = p.parseExpected(kind.Kind.NewKeyword);

    if (p.parseOptional(kind.Kind.DotToken)) {
        const name = try p.parseIdentifierName();
        // MetaProperty for new.target
        const node = try p.ast.pushNode(.{ .MetaProperty = .{
            .Flags = 0,
            .KeywordToken = @intFromEnum(kind.Kind.NewKeyword),
            .name = name,
        } });
        p.setNodeStartPos(node, start_pos);
        return node;
    }

    var expression = try parsePrimaryExpression(p);
    expression = try parseMemberExpressionRest(p, expression, false);

    var typeArguments: ?ast_gen.NodeListIndex = null;
    if (!p.scanner.hasPrecedingLineBreak() and p.token == kind.Kind.LessThanToken) {
        typeArguments = try p.parseTypeArguments();
    }

    var arguments: ?ast_gen.NodeListIndex = null;
    if (p.token == kind.Kind.OpenParenToken) {
        p.nextToken();
        arguments = p.parseDelimitedList(.ArgumentExpressions, parseArgumentExpressionWrapper);
        _ = p.parseExpected(kind.Kind.CloseParenToken);
    }

    const node = try p.ast.pushNode(.{ .NewExpression = .{
        .Flags = 0,
        .Expression = expression,
        .TypeArguments = typeArguments,
        .Arguments = arguments,
    } });
    p.setNodeStartPos(node, start_pos);
    return node;
}

pub fn parsePrimaryExpression(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    switch (p.token) {
        kind.Kind.NoSubstitutionTemplateLiteral => {
            if ((p.scanner.state.tokenFlags & scanner_pkg.TokenFlags.Unterminated) != 0) {
                p.token = p.scanner.reScanTemplateToken(false);
            }
            return parseLiteralExpression(p);
        },
        kind.Kind.NumericLiteral, kind.Kind.BigIntLiteral, kind.Kind.StringLiteral, kind.Kind.RegularExpressionLiteral => {
            return parseLiteralExpression(p);
        },
        kind.Kind.SlashToken, kind.Kind.SlashEqualsToken => {
            p.token = p.scanner.reScanSlashToken();
            return parseLiteralExpression(p);
        },
        kind.Kind.ThisKeyword, kind.Kind.SuperKeyword, kind.Kind.NullKeyword, kind.Kind.TrueKeyword, kind.Kind.FalseKeyword => {
            return parseKeywordExpression(p);
        },
        kind.Kind.ImportKeyword => {
            const isMeta = p.lookAhead(struct {
                fn run(p1: *parser_pkg.Parser) bool {
                    p1.nextToken();
                    return p1.token == kind.Kind.DotToken;
                }
            }.run);
            if (isMeta) {
                p.nextToken(); // consume 'import'
                p.nextToken(); // consume '.'
                const nameNode = try p.parseIdentifierName();
                return p.ast.pushNode(.{ .MetaProperty = .{
                    .Flags = 0,
                    .KeywordToken = @intFromEnum(kind.Kind.ImportKeyword),
                    .name = nameNode,
                } });
            }
            return parseKeywordExpression(p);
        },
        kind.Kind.NewKeyword => {
            return parseNewExpressionOrNewDotTarget(p);
        },
        kind.Kind.OpenParenToken => {
            const start_pos = p.scanner.state.tokenStart;
            p.nextToken(); // Consume '('
            if (p.token == kind.Kind.CloseParenToken) {
                p.nextToken();
                const expr = try p.ast.pushNode(.{ .OmittedExpression = .{ .Flags = 0 } });
                const node = try p.ast.pushNode(.{ .ParenthesizedExpression = .{ .Flags = 0, .Expression = expr } });
                p.setNodeStartPos(node, start_pos);
                return node;
            }
            const expr = try parseExpression(p);
            _ = p.parseExpected(kind.Kind.CloseParenToken);
            const node = try p.ast.pushNode(.{ .ParenthesizedExpression = .{ .Flags = 0, .Expression = expr } });
            p.setNodeStartPos(node, start_pos);
            return node;
        },
        kind.Kind.OpenBracketToken => {
            return parseArrayLiteralExpression(p);
        },
        kind.Kind.OpenBraceToken => {
            return parseObjectLiteralExpression(p);
        },
        kind.Kind.AsyncKeyword => {
            const isAsyncFunc = p.lookAhead(struct {
                fn run(p1: *parser_pkg.Parser) bool {
                    p1.nextToken();
                    return p1.token == kind.Kind.FunctionKeyword and !p1.scanner.hasPrecedingLineBreak();
                }
            }.run);
            if (isAsyncFunc) {
                return p.parseFunctionExpression();
            }
            return p.parseIdentifierName();
        },
        kind.Kind.AtToken => {
            const modifiers = try p.parseModifiersEx(true);
            return p.parseClassExpression(modifiers, 0);
        },
        kind.Kind.AbstractKeyword => {
            if (p.lookAhead(struct {
                fn run(p1: *parser_pkg.Parser) bool {
                    p1.nextToken();
                    return p1.token == kind.Kind.ClassKeyword;
                }
            }.run)) {
                const modifiers = try p.parseModifiersEx(true);
                return p.parseClassExpression(modifiers, 0);
            }
            return p.parseIdentifierName();
        },
        kind.Kind.ClassKeyword => {
            return p.parseClassExpression(null, 0);
        },
        kind.Kind.FunctionKeyword => {
            return p.parseFunctionExpression();
        },
        kind.Kind.PrivateIdentifier => {
            const start_pos = p.scanner.state.tokenStart;
            const end_pos = p.scanner.getTokenEnd();
            const text = p.scanner.state.tokenValue;
            p.nextToken();
            const node = try p.ast.pushNode(.{ .PrivateIdentifier = .{ .Flags = 0, .Text = text } });
            p.ast.positions.items[node] = .{ .pos = @intCast(start_pos), .end = @intCast(end_pos) };
            return node;
        },
        kind.Kind.TemplateHead => {
            return parseTemplateExpression(p, false);
        },
        else => {
            return p.parseIdentifier();
        },
    }
}

pub fn parseTemplateExpression(p: *parser_pkg.Parser, isTaggedTemplate: bool) anyerror!ast_gen.NodeIndex {
    const start_pos = p.scanner.state.tokenStart;
    const head = try parseTemplateHead(p, isTaggedTemplate);
    const spans = try parseTemplateSpans(p, isTaggedTemplate);
    const node = try p.ast.pushNode(.{ .TemplateExpression = .{ .Flags = 0, .Head = head, .TemplateSpans = spans } });
    p.setNodeStartPos(node, start_pos);
    return node;
}

pub fn parseTemplateHead(p: *parser_pkg.Parser, isTaggedTemplate: bool) anyerror!ast_gen.NodeIndex {
    if (!isTaggedTemplate and (p.scanner.state.tokenFlags & scanner_pkg.TokenFlags.Unterminated) != 0) {
        p.token = p.scanner.reScanTemplateToken(false);
    }
    const result = try p.ast.pushNode(.{ .TemplateHead = .{ .Flags = 0, .TokenFlags = p.scanner.state.tokenFlags, .Text = p.scanner.state.tokenValue, .RawText = "", .TemplateFlags = @as(u16, @intCast(p.scanner.state.tokenFlags & 0xFFFF)) } });
    p.nextToken();
    return result;
}

pub fn parseTemplateSpans(p: *parser_pkg.Parser, isTaggedTemplate: bool) anyerror!ast_gen.NodeListIndex {
    var spans = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
    defer spans.deinit(p.allocator);
    while (true) {
        const span = try parseTemplateSpan(p, isTaggedTemplate);
        try spans.append(p.allocator, span);
        const spanNode = p.ast.nodes.get(span);
        if (spanNode == .TemplateSpan) {
            const litNode = p.ast.nodes.get(spanNode.TemplateSpan.Literal);
            if (litNode != .TemplateMiddle) {
                break;
            }
        } else {
            break;
        }
    }
    return p.ast.pushNodeList(spans.items);
}

pub fn parseTemplateSpan(p: *parser_pkg.Parser, isTaggedTemplate: bool) anyerror!ast_gen.NodeIndex {
    const expr = try parseExpression(p);
    const literal = try parseLiteralOfTemplateSpan(p, isTaggedTemplate);
    return p.ast.pushNode(.{ .TemplateSpan = .{ .Flags = 0, .Expression = expr, .Literal = literal } });
}

pub fn parseLiteralOfTemplateSpan(p: *parser_pkg.Parser, isTaggedTemplate: bool) anyerror!ast_gen.NodeIndex {
    if (p.token == kind.Kind.CloseBraceToken) {
        p.token = p.scanner.reScanTemplateToken(isTaggedTemplate);
        return parseTemplateMiddleOrTail(p);
    }
    p.parseError("Expected '}'");
    return p.ast.pushNode(.{ .TemplateTail = .{ .Flags = 0, .TokenFlags = 0, .Text = "", .RawText = "", .TemplateFlags = 0 } });
}

pub fn parseTemplateMiddleOrTail(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    var result: ast_gen.NodeIndex = 0;
    if (p.token == kind.Kind.TemplateMiddle) {
        result = try p.ast.pushNode(.{ .TemplateMiddle = .{ .Flags = 0, .TokenFlags = p.scanner.state.tokenFlags, .Text = p.scanner.state.tokenValue, .RawText = "", .TemplateFlags = @as(u16, @intCast(p.scanner.state.tokenFlags & 0xFFFF)) } });
    } else {
        result = try p.ast.pushNode(.{ .TemplateTail = .{ .Flags = 0, .TokenFlags = p.scanner.state.tokenFlags, .Text = p.scanner.state.tokenValue, .RawText = "", .TemplateFlags = @as(u16, @intCast(p.scanner.state.tokenFlags & 0xFFFF)) } });
    }
    p.nextToken();
    return result;
}

pub fn isStartOfExpressionStatement(p: *parser_pkg.Parser) bool {
    return p.token != kind.Kind.OpenBraceToken and
        p.token != kind.Kind.FunctionKeyword and
        p.token != kind.Kind.ClassKeyword and
        p.token != kind.Kind.AtToken and
        p.isStartOfExpression();
}

pub fn isParenthesizedArrowFunctionExpression(p: *parser_pkg.Parser) core.Tristate {
    if (p.token == kind.Kind.OpenParenToken or p.token == kind.Kind.LessThanToken or p.token == kind.Kind.AsyncKeyword) {
        const state = p.mark();
        const result = nextIsParenthesizedArrowFunctionExpression(p);
        p.rewind(state);
        return result;
    }
    if (p.token == kind.Kind.EqualsGreaterThanToken) {
        return .True;
    }
    return .False;
}

pub fn nextIsParenthesizedArrowFunctionExpression(p: *parser_pkg.Parser) core.Tristate {
    if (p.token == kind.Kind.AsyncKeyword) {
        p.nextToken();
        if (p.scanner.hasPrecedingLineBreak()) {
            return .False;
        }
        if (p.token != kind.Kind.OpenParenToken and p.token != kind.Kind.LessThanToken) {
            return .False;
        }
    }
    const first = p.token;
    p.nextToken();
    const second = p.token;
    if (first == kind.Kind.OpenParenToken) {
        if (second == kind.Kind.CloseParenToken) {
            p.nextToken();
            const third = p.token;
            switch (third) {
                .EqualsGreaterThanToken, .ColonToken, .OpenBraceToken => return .True,
                else => return .False,
            }
        }
        if (second == kind.Kind.OpenBracketToken or second == kind.Kind.OpenBraceToken) {
            return .Unknown;
        }
        if (second == kind.Kind.DotDotDotToken) {
            return .True;
        }
        if (p.isModifierKind(second) and second != kind.Kind.AsyncKeyword and p.lookAhead(parser_pkg.Parser.nextTokenIsIdentifier)) {
            p.nextToken();
            if (p.token == kind.Kind.AsKeyword) {
                return .False;
            }
            return .True;
        }
        if (!p.isIdentifier() and second != kind.Kind.ThisKeyword) {
            return .False;
        }
        p.nextToken();
        switch (p.token) {
            .ColonToken => return .True,
            .QuestionToken => {
                p.nextToken();
                if (p.token == kind.Kind.ColonToken or p.token == kind.Kind.CommaToken or p.token == kind.Kind.EqualsToken or p.token == kind.Kind.CloseParenToken) {
                    return .True;
                }
                return .False;
            },
            .CommaToken, .EqualsToken, .CloseParenToken => return .Unknown,
            else => return .False,
        }
    } else {
        std.debug.assert(first == kind.Kind.LessThanToken);
        if (!p.isIdentifier() and p.token != kind.Kind.ConstKeyword) {
            return .False;
        }
        if (p.languageVariant == .JSX) {
            const isArrowFunctionInJsx = p.lookAhead(struct {
                fn run(p1: *parser_pkg.Parser) bool {
                    _ = p1.parseOptional(kind.Kind.ConstKeyword);
                    p1.nextToken();
                    const third = p1.token;
                    if (third == kind.Kind.ExtendsKeyword) {
                        p1.nextToken();
                        const fourth = p1.token;
                        switch (fourth) {
                            .EqualsToken, .GreaterThanToken, .SlashToken => return false,
                            else => return true,
                        }
                    } else if (third == kind.Kind.CommaToken or third == kind.Kind.EqualsToken) {
                        return true;
                    }
                    return false;
                }
            }.run);
            if (isArrowFunctionInJsx) {
                return .True;
            }
            return .False;
        }
        return .Unknown;
    }
}

pub fn tryParseParenthesizedArrowFunctionExpression(p: *parser_pkg.Parser, allowReturnTypeInArrowFunction: bool) ?ast_gen.NodeIndex {
    const tristate = isParenthesizedArrowFunctionExpression(p);
    if (tristate == .False) {
        return null;
    }
    if (tristate == .True) {
        return parseParenthesizedArrowFunctionExpression(p, true, allowReturnTypeInArrowFunction);
    }
    const state = p.mark();
    const result = parsePossibleParenthesizedArrowFunctionExpression(p, allowReturnTypeInArrowFunction);
    if (result == null) {
        p.rewind(state);
    }
    return result;
}

pub fn parseParenthesizedArrowFunctionExpression(p: *parser_pkg.Parser, allowAmbiguity: bool, allowReturnTypeInArrowFunction: bool) ?ast_gen.NodeIndex {
    const arrow_start = p.scanner.state.tokenStart;
    const modifiers = parseModifiersForArrowFunction(p) catch null;
    const isAsync = modifiers != null;

    const typeParameters = if (p.token == kind.Kind.LessThanToken) p.parseTypeParameters() catch null else null;
    var parameters: ?ast_gen.NodeListIndex = null;

    if (!p.parseExpected(kind.Kind.OpenParenToken)) {
        if (!allowAmbiguity) return null;
        parameters = p.ast.pushNodeList(&.{}) catch 0;
    } else {
        if (!allowAmbiguity and (p.token == kind.Kind.OpenBracketToken or p.token == kind.Kind.OpenBraceToken)) {
            return null;
        }
        parameters = p.parseDelimitedList(.Parameters, parser_pkg.Parser.parseParameterWrapper);
        if (!p.parseExpected(kind.Kind.CloseParenToken) and !allowAmbiguity) {
            return null;
        }
    }

    var returnType: ?ast_gen.NodeIndex = null;
    var hasReturnColon = false;
    if (p.parseOptional(kind.Kind.ColonToken)) {
        hasReturnColon = true;
        if (allowAmbiguity or allowReturnTypeInArrowFunction) {
            returnType = p.parseTypeOrTypePredicate() catch null;
        }
    }

    if (!allowAmbiguity and p.token != kind.Kind.EqualsGreaterThanToken and p.token != kind.Kind.OpenBraceToken) {
        return null;
    }

    const lastToken = p.token;
    const equalsGreaterThanToken = p.ast.pushNode(.{ .EqualsGreaterThanToken = void{} }) catch 0;
    _ = p.parseExpected(kind.Kind.EqualsGreaterThanToken); // Should be =>

    var body: ast_gen.NodeIndex = 0;
    if (lastToken == kind.Kind.EqualsGreaterThanToken or lastToken == kind.Kind.OpenBraceToken) {
        body = parseArrowFunctionExpressionBody(p, isAsync, allowReturnTypeInArrowFunction) catch 0;
    } else {
        body = p.parseIdentifier() catch 0;
    }

    if (!allowReturnTypeInArrowFunction and hasReturnColon) {
        if (p.token != kind.Kind.ColonToken) {
            return null;
        }
    }

    var modifierFlags: u32 = 0;
    if (isAsync) {
        modifierFlags |= ast_utils.ModifierFlags.Async;
    }

    const node = p.ast.pushNode(.{ .ArrowFunction = .{
        .Flags = 0,
        .Symbol = 0,
        .modifiers = modifiers,
        .modifierFlags = modifierFlags,
        .TypeParameters = typeParameters,
        .Parameters = parameters orelse 0,
        .Type = returnType,
        .FullSignature = null,
        .AsteriskToken = null,
        .EqualsGreaterThanToken = equalsGreaterThanToken,
        .Body = body,
    } }) catch 0;
    p.setNodeStartPos(node, arrow_start);
    return node;
}

pub fn parsePossibleParenthesizedArrowFunctionExpression(p: *parser_pkg.Parser, allowReturnTypeInArrowFunction: bool) ?ast_gen.NodeIndex {
    return parseParenthesizedArrowFunctionExpression(p, false, allowReturnTypeInArrowFunction);
}

pub fn tryParseAsyncSimpleArrowFunctionExpression(p: *parser_pkg.Parser, allowReturnTypeInArrowFunction: bool) ?ast_gen.NodeIndex {
    if (p.token == kind.Kind.AsyncKeyword and p.lookAhead(nextIsUnParenthesizedAsyncArrowFunction)) {
        const modifiers = parseModifiersForArrowFunction(p) catch null;
        const expr = parseBinaryExpressionOrHigher(p, .Invalid) catch 0;
        return parseSimpleArrowFunctionExpression(p, expr, allowReturnTypeInArrowFunction, modifiers) catch null;
    }
    return null;
}

pub fn nextIsUnParenthesizedAsyncArrowFunction(p: *parser_pkg.Parser) bool {
    if (p.token == kind.Kind.AsyncKeyword) {
        p.nextToken();
        if (p.scanner.hasPrecedingLineBreak() or p.token == kind.Kind.EqualsGreaterThanToken) {
            return false;
        }
        const expr = parseBinaryExpressionOrHigher(p, .Invalid) catch 0;
        if (!p.scanner.hasPrecedingLineBreak() and p.ast.getKind(expr) == .Identifier and p.token == kind.Kind.EqualsGreaterThanToken) {
            return true;
        }
    }
    return false;
}

pub fn parseSimpleArrowFunctionExpression(p: *parser_pkg.Parser, identifier: ast_gen.NodeIndex, allowReturnTypeInArrowFunction: bool, asyncModifier: ?ast_gen.NodeListIndex) !ast_gen.NodeIndex {
    const arrow_start = if (identifier != 0 and identifier < p.ast.positions.items.len and p.ast.positions.items[identifier].pos != 0)
        p.ast.positions.items[identifier].pos
    else
        @as(u32, @intCast(p.scanner.state.tokenStart));
    std.debug.assert(p.token == kind.Kind.EqualsGreaterThanToken);
    const param = try p.ast.pushNode(.{ .Parameter = .{
        .Symbol = 0,
        .Flags = 0,
        .modifiers = null,
        .modifierFlags = 0,
        .DotDotDotToken = null,
        .name = identifier,
        .QuestionToken = null,
        .Type = null,
        .Initializer = null,
    } });
    const parameters = try p.ast.pushNodeList(&.{param});
    const equalsGreaterThanToken = try p.ast.pushNode(.{ .EqualsGreaterThanToken = void{} });
    p.nextToken(); // consume =>
    const body = try parseArrowFunctionExpressionBody(p, asyncModifier != null, allowReturnTypeInArrowFunction);

    var modifierFlags: u32 = 0;
    if (asyncModifier != null) {
        modifierFlags |= ast_utils.ModifierFlags.Async;
    }

    const node = try p.ast.pushNode(.{
        .ArrowFunction = .{
            .Flags = 1 << 29, // Custom flag to indicate simple arrow head
            .Symbol = 0,
            .modifiers = asyncModifier,
            .modifierFlags = modifierFlags,
            .TypeParameters = null,
            .Parameters = parameters,
            .Type = null,
            .FullSignature = null,
            .AsteriskToken = null,
            .EqualsGreaterThanToken = equalsGreaterThanToken,
            .Body = body,
        },
    });
    p.setNodeStartPos(node, arrow_start);
    return node;
}

pub fn parseModifiersForArrowFunction(p: *parser_pkg.Parser) !?ast_gen.NodeListIndex {
    if (p.token == kind.Kind.AsyncKeyword) {
        const modifier = try p.ast.pushNode(.{ .AsyncKeyword = void{} });
        p.nextToken();
        return try p.ast.pushNodeList(&.{modifier});
    }
    return null;
}

pub fn parseArrowFunctionExpressionBody(p: *parser_pkg.Parser, isAsync: bool, allowReturnTypeInArrowFunction: bool) !ast_gen.NodeIndex {
    _ = allowReturnTypeInArrowFunction;
    if (p.token == kind.Kind.OpenBraceToken) {
        return p.parseBlock();
    }
    if (p.token != kind.Kind.SemicolonToken and p.token != kind.Kind.FunctionKeyword and p.token != kind.Kind.ClassKeyword and p.isStartOfStatement() and !isStartOfExpressionStatement(p)) {
        return p.parseBlock();
    }

    const saveContextFlags = p.contextFlags;
    p.setContextFlags(ast_utils.NodeFlags.AwaitContext, isAsync);
    p.setContextFlags(ast_utils.NodeFlags.YieldContext, false);

    const node = try parseAssignmentExpressionOrHigher(p);

    p.contextFlags = saveContextFlags;
    return node;
}
