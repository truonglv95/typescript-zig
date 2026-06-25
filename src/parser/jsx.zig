const std = @import("std");
const parser_pkg = @import("parser.zig");
const kind = @import("../ast/kind.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast = @import("../ast/ast.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");

pub fn parseJsxElementOrSelfClosingElementOrFragment(p: *parser_pkg.Parser, inExpressionContext: bool, topInvalidNodePosition: i32, openingTag: ?ast_gen.NodeIndex, mustBeUnary: bool) anyerror!ast_gen.NodeIndex {
    _ = p;
    _ = inExpressionContext;
    _ = topInvalidNodePosition;
    _ = openingTag;
    _ = mustBeUnary;
    return 0;
}

pub fn parseJsxChildren(p: *parser_pkg.Parser, openingTag: ?ast_gen.NodeIndex) anyerror!ast_gen.NodeListIndex {
    _ = p;
    _ = openingTag;
    return 0;
}

pub fn parseJsxChild(p: *parser_pkg.Parser, openingTag: ?ast_gen.NodeIndex, token: kind.Kind) anyerror!ast_gen.NodeIndex {
    _ = p;
    _ = openingTag;
    _ = token;
    return 0;
}

pub fn parseJsxText(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    const isAllWhiteSpace = if (p.token == kind.Kind.JsxTextAllWhiteSpaces) @as(u32, 1) else @as(u32, 0);
    const result = try p.ast.pushNode(.{ .JsxText = .{
        .Flags = 0,
        .Text = p.scanner.state.tokenValue,
        .TokenFlags = p.scanner.state.tokenFlags,
        .ContainsOnlyTriviaWhiteSpaces = isAllWhiteSpace,
    } });
    _ = p.scanner.scanJsxToken();
    p.token = p.scanner.state.token;
    return result;
}

pub fn parseJsxExpression(p: *parser_pkg.Parser, inExpressionContext: bool) anyerror!ast_gen.NodeIndex {
    _ = p;
    _ = inExpressionContext;
    return 0;
}

pub fn scanJsxText(p: *parser_pkg.Parser) kind.Kind {
    _ = p;
    return kind.Kind.Unknown;
}

pub fn scanJsxIdentifier(p: *parser_pkg.Parser) kind.Kind {
    _ = p;
    return kind.Kind.Unknown;
}

pub fn scanJsxAttributeValue(p: *parser_pkg.Parser) kind.Kind {
    _ = p;
    return kind.Kind.Unknown;
}

pub fn parseJsxClosingElement(p: *parser_pkg.Parser, open: ast_gen.NodeIndex, inExpressionContext: bool) anyerror!ast_gen.NodeIndex {
    _ = p;
    _ = open;
    _ = inExpressionContext;
    return 0;
}

pub fn parseJsxOpeningOrSelfClosingElementOrOpeningFragment(p: *parser_pkg.Parser, inExpressionContext: bool) anyerror!ast_gen.NodeIndex {
    _ = p;
    _ = inExpressionContext;
    return 0;
}

pub fn parseJsxTagName(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    _ = p.scanner.scanJsxIdentifier();
    p.token = p.scanner.state.token;
    const isThis = p.token == kind.Kind.ThisKeyword;
    const tagName = try p.parseIdentifierName();
    if (p.parseOptional(kind.Kind.ColonToken)) {
        _ = p.scanner.scanJsxIdentifier();
        p.token = p.scanner.state.token;
        const name = try p.parseIdentifierName();
        return try p.ast.pushNode(.{ .JsxNamespacedName = .{
            .Flags = 0,
            .Namespace = tagName,
            .Name = name,
        } });
    }
    if (isThis) {
        return try p.ast.pushNode(.{ .ThisKeyword = {} });
    }
    return tagName;
}

pub fn parseJsxElementName(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    const initialExpression = try parseJsxTagName(p);
    if (initialExpression != 0 and p.ast.getNode(initialExpression) == .JsxNamespacedName) {
        return initialExpression;
    }
    var expression = initialExpression;
    while (p.parseOptional(kind.Kind.DotToken)) {
        const right = try p.parseRightSideOfDot(true, false, false);
        expression = try p.ast.pushNode(.{ .PropertyAccessExpression = .{
            .Flags = 0,
            .Expression = expression,
            .QuestionDotToken = null,
            .Name = right,
        } });
    }
    return expression;
}

pub fn parseJsxAttributes(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    const properties = try p.parseList(parser_pkg.ParsingContext.JsxAttributes, parseJsxAttribute);
    return try p.ast.pushNode(.{ .JsxAttributes = .{
        .Flags = 0,
        .Symbol = 0,
        .Properties = properties,
    } });
}

pub fn parseJsxAttribute(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    if (p.token == kind.Kind.OpenBraceToken) {
        return try parseJsxSpreadAttribute(p);
    }
    const name = try parseJsxAttributeName(p);
    const value = try parseJsxAttributeValue(p);
    return try p.ast.pushNode(.{ .JsxAttribute = .{
        .Flags = 0,
        .Name = name,
        .Initializer = value,
    } });
}

pub fn parseJsxSpreadAttribute(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    _ = p.parseExpected(kind.Kind.OpenBraceToken);
    _ = p.parseExpected(kind.Kind.DotDotDotToken);
    const expr_parser = @import("expression.zig");
    const expression = try expr_parser.parseExpression(p);
    _ = p.parseExpected(kind.Kind.CloseBraceToken);
    return try p.ast.pushNode(.{ .JsxSpreadAttribute = .{
        .Flags = 0,
        .Expression = expression,
    } });
}

pub fn parseJsxAttributeName(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    _ = p.scanner.scanJsxIdentifier();
    p.token = p.scanner.state.token;
    const attrName = try p.parseIdentifierName();
    if (p.parseOptional(kind.Kind.ColonToken)) {
        _ = p.scanner.scanJsxIdentifier();
        p.token = p.scanner.state.token;
        const name = try p.parseIdentifierName();
        return try p.ast.pushNode(.{ .JsxNamespacedName = .{
            .Flags = 0,
            .Namespace = attrName,
            .Name = name,
        } });
    }
    return attrName;
}

pub fn parseJsxAttributeValue(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    if (p.token == kind.Kind.EqualsToken) {
        _ = p.scanner.scanJsxAttributeValue();
        p.token = p.scanner.state.token;
        if (p.token == kind.Kind.StringLiteral) {
            const expr_parser = @import("expression.zig");
            return try expr_parser.parseLiteralExpression(p);
        }
        if (p.token == kind.Kind.OpenBraceToken) {
            return try parseJsxExpression(p, true);
        }
        if (p.token == kind.Kind.LessThanToken) {
            return try parseJsxElementOrSelfClosingElementOrFragment(p, true, -1, null, false);
        }
        p.parseErrorAtCurrentToken(diagnostics.DiagnosticMessage.X_or_JSX_element_expected);
    }
    return 0; // null basically
}

pub fn parseJsxClosingFragment(p: *parser_pkg.Parser, inExpressionContext: bool) anyerror!ast_gen.NodeIndex {
    _ = p;
    _ = inExpressionContext;
    return 0;
}

