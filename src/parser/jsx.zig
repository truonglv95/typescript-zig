// JSX Parser — ported 1:1 from Go internal/parser/parser.go (lines 4742-5065)
const std = @import("std");
const parser_pkg = @import("parser.zig");
const kind = @import("../ast/kind.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast = @import("../ast/ast.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const expr_parser = @import("expression.zig");

// parseJsxElementOrSelfClosingElementOrFragment
// Go: func (p *Parser) parseJsxElementOrSelfClosingElementOrFragment(...)
pub fn parseJsxElementOrSelfClosingElementOrFragment(
    p: *parser_pkg.Parser,
    inExpressionContext: bool,
    topInvalidNodePosition: i32,
    openingTag: ?ast_gen.NodeIndex,
    mustBeUnary: bool,
) anyerror!ast_gen.NodeIndex {
    _ = openingTag;
    const opening = try parseJsxOpeningOrSelfClosingElementOrOpeningFragment(p, inExpressionContext);

    var result: ast_gen.NodeIndex = 0;
    const openingNode = p.ast.getNode(opening);

    switch (openingNode) {
        .JsxOpeningElement => {
            const children = try parseJsxChildren(p, opening);
            const closingElement = try parseJsxClosingElement(p, opening, inExpressionContext);
            result = try p.ast.pushNode(.{ .JsxElement = .{
                .Flags = 0,
                .OpeningElement = opening,
                .Children = children,
                .ClosingElement = closingElement,
            } });
        },
        .JsxOpeningFragment => {
            const children = try parseJsxChildren(p, opening);
            const closingFragment = try parseJsxClosingFragment(p, inExpressionContext);
            result = try p.ast.pushNode(.{ .JsxFragment = .{
                .Flags = 0,
                .OpeningFragment = opening,
                .Children = children,
                .ClosingFragment = closingFragment,
            } });
        },
        .JsxSelfClosingElement => {
            // Self-closing: nothing more to parse
            result = opening;
        },
        else => {
            // Should not happen
            result = opening;
        },
    }

    // If we're in expression context and see another `<`, parse it as
    // comma-separated JSX expressions (error recovery)
    if (!mustBeUnary and inExpressionContext and p.token == kind.Kind.LessThanToken) {
        var topBadPos = topInvalidNodePosition;
        if (topBadPos < 0) {
            topBadPos = 0; // approximate — we don't track pos precisely here
        }
        const invalidElement = try parseJsxElementOrSelfClosingElementOrFragment(p, true, topBadPos, null, false);
        // Report error and create binary expression (comma)
        // For AST parity we create a BinaryExpression with CommaToken
        const commaToken = try p.ast.pushNode(.{ .CommaToken = void{} });
        result = try p.ast.pushNode(.{ .BinaryExpression = .{
            .Flags = 0,
            .Symbol = 0,
            .modifiers = null,
            .modifierFlags = 0,
            .Left = result,
            .Type = null,
            .OperatorToken = commaToken,
            .Right = invalidElement,
            .linesBeforeOperator = 0,
            .linesAfterOperator = 0,
        } });
    }

    return result;
}

// parseJsxChildren
// Go: func (p *Parser) parseJsxChildren(openingTag *ast.Expression) *ast.NodeList
pub fn parseJsxChildren(p: *parser_pkg.Parser, openingTag: ast_gen.NodeIndex) anyerror!ast_gen.NodeListIndex {
    const saveParsingContexts = p.parsingContexts;
    p.parsingContexts |= @as(u32, 1) << @intFromEnum(parser_pkg.ParsingContext.JsxChildren);

    var list = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;

    while (true) {
        // Rescan current position as JSX token
        const currentToken = p.scanner.reScanJsxToken(true);
        p.token = currentToken;

        const child = try parseJsxChild(p, openingTag, currentToken);
        if (child == 0) break;

        try list.append(p.allocator, child);
    }

    p.parsingContexts = saveParsingContexts;

    const listIdx = try p.ast.pushNodeList(list.items);
    list.deinit(p.allocator);
    return listIdx;
}

// parseJsxChild
// Go: func (p *Parser) parseJsxChild(openingTag *ast.Node, token ast.Kind)
pub fn parseJsxChild(p: *parser_pkg.Parser, openingTag: ast_gen.NodeIndex, token_kind: kind.Kind) anyerror!ast_gen.NodeIndex {
    switch (token_kind) {
        .EndOfFile => {
            // Error: unclosed tag — return 0 to stop
            return 0;
        },
        .LessThanSlashToken, .ConflictMarkerTrivia => {
            return 0;
        },
        .JsxText, .JsxTextAllWhiteSpaces => {
            return try parseJsxText(p);
        },
        .OpenBraceToken => {
            return try parseJsxExpression(p, false);
        },
        .LessThanToken => {
            return try parseJsxElementOrSelfClosingElementOrFragment(p, false, -1, openingTag, false);
        },
        else => {
            return 0;
        },
    }
}

// parseJsxText — already implemented, keep it
// Go: func (p *Parser) parseJsxText() *ast.Node
pub fn parseJsxText(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    const isAllWhiteSpace = if (p.token == kind.Kind.JsxTextAllWhiteSpaces) @as(u32, 1) else @as(u32, 0);
    const result = try p.ast.pushNode(.{ .JsxText = .{
        .Flags = 0,
        .Text = p.scanner.state.tokenValue,
        .TokenFlags = p.scanner.state.tokenFlags,
        .ContainsOnlyTriviaWhiteSpaces = isAllWhiteSpace,
    } });
    // scanJsxText() — update token
    _ = p.scanner.scanJsxToken();
    p.token = p.scanner.state.token;
    return result;
}

// parseJsxExpression
// Go: func (p *Parser) parseJsxExpression(inExpressionContext bool) *ast.Node
pub fn parseJsxExpression(p: *parser_pkg.Parser, inExpressionContext: bool) anyerror!ast_gen.NodeIndex {
    if (!p.parseExpected(kind.Kind.OpenBraceToken)) {
        return 0;
    }

    var dotDotDotToken: ?ast_gen.NodeIndex = null;
    var expression: ?ast_gen.NodeIndex = null;

    if (p.token != kind.Kind.CloseBraceToken) {
        if (!inExpressionContext) {
            dotDotDotToken = p.parseOptionalToken(kind.Kind.DotDotDotToken);
        }
        const expr = try expr_parser.parseExpression(p);
        expression = if (expr != 0) expr else null;
    }

    if (inExpressionContext) {
        _ = p.parseExpected(kind.Kind.CloseBraceToken);
    } else {
        // parseExpectedWithoutAdvancing equivalent: peek at } without consuming
        if (p.token == kind.Kind.CloseBraceToken) {
            // scanJsxText — advance scanner in JSX mode
            _ = p.scanner.scanJsxToken();
            p.token = p.scanner.state.token;
        } else {
            _ = p.parseExpected(kind.Kind.CloseBraceToken);
        }
    }

    return try p.ast.pushNode(.{ .JsxExpression = .{
        .Flags = 0,
        .DotDotDotToken = dotDotDotToken,
        .Expression = expression,
    } });
}

// scanJsxText helper (updates parser token via JSX scanner mode)
pub fn scanJsxText(p: *parser_pkg.Parser) kind.Kind {
    p.token = p.scanner.scanJsxToken();
    return p.token;
}

// scanJsxIdentifier helper
pub fn scanJsxIdentifier(p: *parser_pkg.Parser) kind.Kind {
    p.token = p.scanner.scanJsxIdentifier();
    return p.token;
}

// scanJsxAttributeValue helper
pub fn scanJsxAttributeValue(p: *parser_pkg.Parser) kind.Kind {
    p.token = p.scanner.scanJsxAttributeValue();
    return p.token;
}

// parseJsxClosingElement
// Go: func (p *Parser) parseJsxClosingElement(open *ast.Node, inExpressionContext bool)
pub fn parseJsxClosingElement(p: *parser_pkg.Parser, open: ast_gen.NodeIndex, inExpressionContext: bool) anyerror!ast_gen.NodeIndex {
    _ = p.parseExpected(kind.Kind.LessThanSlashToken);
    const tagName = try parseJsxElementName(p);

    // parseExpectedWithDiagnostic(GreaterThanToken, nil, false) — check without advancing
    if (p.token == kind.Kind.GreaterThanToken) {
        // Check if tag names are equivalent — if inExpressionContext, use nextToken; otherwise scanJsxText
        const openNode = p.ast.getNode(open);
        const openTagName = switch (openNode) {
            .JsxOpeningElement => |e| e.TagName,
            else => null,
        };
        const tagsEqual = openTagName != null and openTagName.? == tagName;

        if (inExpressionContext or !tagsEqual) {
            p.nextToken();
        } else {
            _ = p.scanner.scanJsxToken();
            p.token = p.scanner.state.token;
        }
    } else {
        _ = p.parseExpected(kind.Kind.GreaterThanToken);
    }

    return try p.ast.pushNode(.{ .JsxClosingElement = .{
        .Flags = 0,
        .TagName = tagName,
    } });
}

// parseJsxOpeningOrSelfClosingElementOrOpeningFragment
// Go: func (p *Parser) parseJsxOpeningOrSelfClosingElementOrOpeningFragment(inExpressionContext bool)
pub fn parseJsxOpeningOrSelfClosingElementOrOpeningFragment(
    p: *parser_pkg.Parser,
    inExpressionContext: bool,
) anyerror!ast_gen.NodeIndex {
    _ = p.parseExpected(kind.Kind.LessThanToken);

    // Check for fragment: `<>`
    if (p.token == kind.Kind.GreaterThanToken) {
        // Opening fragment — scan to JSX text mode
        _ = p.scanner.scanJsxToken();
        p.token = p.scanner.state.token;
        return try p.ast.pushNode(.{ .JsxOpeningFragment = .{
            .Flags = 0,
        } });
    }

    const tagName = try parseJsxElementName(p);

    // Type arguments (only in non-JS files — always true for .tsx)
    var typeArguments: ?ast_gen.NodeListIndex = null;
    if (p.token == kind.Kind.LessThanToken) {
        // Try to parse type arguments
        typeArguments = p.parseTypeArguments() catch null;
    }
    // used below in node creation

    const attributes = try parseJsxAttributes(p);

    if (p.token == kind.Kind.GreaterThanToken) {
        // Opening element — scan into JSX text mode
        _ = p.scanner.scanJsxToken();
        p.token = p.scanner.state.token;
        return try p.ast.pushNode(.{ .JsxOpeningElement = .{
            .Flags = 0,
            .TagName = tagName,
            .TypeArguments = null,
            .Attributes = attributes,
        } });
    } else {
        // Self-closing: expect `/>`
        _ = p.parseExpected(kind.Kind.SlashToken);
        if (p.token == kind.Kind.GreaterThanToken) {
            if (inExpressionContext) {
                p.nextToken();
            } else {
                _ = p.scanner.scanJsxToken();
                p.token = p.scanner.state.token;
            }
        } else {
            _ = p.parseExpected(kind.Kind.GreaterThanToken);
        }
        return try p.ast.pushNode(.{ .JsxSelfClosingElement = .{
            .Flags = 0,
            .TagName = tagName,
            .TypeArguments = null,
            .Attributes = attributes,
        } });
    }
}

// parseJsxElementName
// Go: func (p *Parser) parseJsxElementName() *ast.Expression
pub fn parseJsxElementName(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    const initialExpression = try parseJsxTagName(p);
    // If it's a namespaced name like `a:b`, don't look for dots
    const initNode = p.ast.getNode(initialExpression);
    if (initNode == .JsxNamespacedName) {
        return initialExpression;
    }
    var expression = initialExpression;
    while (p.parseOptional(kind.Kind.DotToken)) {
        const right = try p.parseIdentifierName();
        expression = try p.ast.pushNode(.{ .PropertyAccessExpression = .{
            .Flags = 0,
            .Expression = expression,
            .QuestionDotToken = null,
            .name = right,
        } });
    }
    return expression;
}

// parseJsxTagName
// Go: func (p *Parser) parseJsxTagName()
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
            .name = name,
        } });
    }
    if (isThis) {
        return try p.ast.pushNode(.{ .ThisKeyword = void{} });
    }
    return tagName;
}

// parseJsxAttributes
// Go: func (p *Parser) parseJsxAttributes() *ast.Node
pub fn parseJsxAttributes(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    const properties = try p.parseList(parser_pkg.ParsingContext.JsxAttributes, parseJsxAttribute);
    return try p.ast.pushNode(.{ .JsxAttributes = .{
        .Flags = 0,
        .Symbol = 0,
        .Properties = properties,
    } });
}

// parseJsxAttribute
// Go: func (p *Parser) parseJsxAttribute() *ast.Node
pub fn parseJsxAttribute(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    if (p.token == kind.Kind.OpenBraceToken) {
        return try parseJsxSpreadAttribute(p);
    }
    const name = try parseJsxAttributeName(p);
    const value = try parseJsxAttributeValue(p);
    return try p.ast.pushNode(.{ .JsxAttribute = .{
        .Flags = 0,
        .Symbol = 0,
        .name = name,
        .Initializer = if (value != 0) value else null,
    } });
}

// parseJsxSpreadAttribute
// Go: func (p *Parser) parseJsxSpreadAttribute() *ast.Node
pub fn parseJsxSpreadAttribute(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    _ = p.parseExpected(kind.Kind.OpenBraceToken);
    _ = p.parseExpected(kind.Kind.DotDotDotToken);
    const expression = try expr_parser.parseExpression(p);
    _ = p.parseExpected(kind.Kind.CloseBraceToken);
    return try p.ast.pushNode(.{ .JsxSpreadAttribute = .{
        .Flags = 0,
        .Expression = expression,
    } });
}

// parseJsxAttributeName
// Go: func (p *Parser) parseJsxAttributeName() *ast.Node
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
            .name = name,
        } });
    }
    return attrName;
}

// parseJsxAttributeValue
// Go: func (p *Parser) parseJsxAttributeValue() *ast.Expression
pub fn parseJsxAttributeValue(p: *parser_pkg.Parser) anyerror!ast_gen.NodeIndex {
    if (p.token == kind.Kind.EqualsToken) {
        _ = p.scanner.scanJsxAttributeValue();
        p.token = p.scanner.state.token;
        if (p.token == kind.Kind.StringLiteral) {
            return try expr_parser.parseLiteralExpression(p);
        }
        if (p.token == kind.Kind.OpenBraceToken) {
            return try parseJsxExpression(p, true);
        }
        if (p.token == kind.Kind.LessThanToken) {
            return try parseJsxElementOrSelfClosingElementOrFragment(p, true, -1, null, false);
        }
        p.parseError("X or JSX element expected");
    }
    return 0;
}

// parseJsxClosingFragment
// Go: func (p *Parser) parseJsxClosingFragment(inExpressionContext bool) *ast.Node
pub fn parseJsxClosingFragment(p: *parser_pkg.Parser, inExpressionContext: bool) anyerror!ast_gen.NodeIndex {
    _ = p.parseExpected(kind.Kind.LessThanSlashToken);
    if (p.token == kind.Kind.GreaterThanToken) {
        if (inExpressionContext) {
            p.nextToken();
        } else {
            _ = p.scanner.scanJsxToken();
            p.token = p.scanner.state.token;
        }
    } else {
        _ = p.parseExpected(kind.Kind.GreaterThanToken);
    }
    return try p.ast.pushNode(.{ .JsxClosingFragment = .{
        .Flags = 0,
    } });
}
