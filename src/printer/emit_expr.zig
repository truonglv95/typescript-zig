const std = @import("std");
const ast_mod = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const Printer = @import("printer.zig").Printer;
const kind = @import("../ast/kind.zig").Kind;
const precedence = @import("../ast/precedence.zig");
const ast_utils = @import("../ast/ast_utils.zig");

pub fn printNumericLiteral(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).NumericLiteral;
    if (std.mem.indexOfScalar(u8, node.Text, '_') != null) {
        var buffer = try printer.tree.allocator.alloc(u8, node.Text.len);
        defer printer.tree.allocator.free(buffer);
        var len: usize = 0;
        for (node.Text) |c| {
            if (c != '_') {
                buffer[len] = c;
                len += 1;
            }
        }
        printer.writer.writeStringLiteral(buffer[0..len]);
    } else {
        printer.writer.writeStringLiteral(node.Text);
    }
}

pub fn printBigIntLiteral(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).BigIntLiteral;
    if (std.mem.indexOfScalar(u8, node.Text, '_') != null) {
        var buffer = try printer.tree.allocator.alloc(u8, node.Text.len);
        defer printer.tree.allocator.free(buffer);
        var len: usize = 0;
        for (node.Text) |c| {
            if (c != '_') {
                buffer[len] = c;
                len += 1;
            }
        }
        printer.writer.writeStringLiteral(buffer[0..len]);
    } else {
        printer.writer.writeStringLiteral(node.Text);
    }
}

pub fn printStringLiteral(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).StringLiteral;
    const isSingleQuote = (node.TokenFlags & (1 << 16)) != 0;
    const quoteStr = if (isSingleQuote) "'" else "\"";
    printer.writer.writePunctuation(quoteStr);

    const range = printer.tree.positions.items[nodeIndex];
    if ((node.TokenFlags & (1 << 30)) != 0) {
        printer.writer.writeStringLiteral(node.Text);
    } else if (range.end == 0) {
        const quoteChar = if (isSingleQuote) @import("utilities.zig").QuoteChar.SingleQuote else @import("utilities.zig").QuoteChar.DoubleQuote;
        const escaped = try @import("utilities.zig").escapeNonAsciiString(printer.tree.allocator, node.Text, quoteChar);
        defer printer.tree.allocator.free(escaped);
        printer.writer.writeStringLiteral(escaped);
    } else {
        printer.writer.writeStringLiteral(node.Text);
    }

    printer.writer.writePunctuation(quoteStr);
}

pub fn printRegularExpressionLiteral(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).RegularExpressionLiteral;
    printer.writer.writeStringLiteral(node.Text);
}

pub fn printNoSubstitutionTemplateLiteral(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).NoSubstitutionTemplateLiteral;
    printer.writer.writePunctuation("`");
    printer.writer.writeStringLiteral(node.Text);
    printer.writer.writePunctuation("`");
}

pub fn printIdentifier(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).Identifier;
    printer.writer.write(node.Text);
}

pub fn printPrivateIdentifier(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).PrivateIdentifier;
    printer.writer.write(node.Text);
}

pub fn printArrayLiteralExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ArrayLiteralExpression;
    var format: u32 = @import("emit_list.zig").ListFormat.CommaDelimited | @import("emit_list.zig").ListFormat.SquareBrackets | @import("emit_list.zig").ListFormat.SpaceBetweenSiblings;
    if (node.MultiLine != 0) {
        format |= @import("emit_list.zig").ListFormat.MultiLine | @import("emit_list.zig").ListFormat.Indented;
    } else {
        format |= @import("emit_list.zig").ListFormat.SingleLine;
    }
    try printer.emitList(null, nodeIndex, node.Elements, format);
}

pub fn printObjectLiteralExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ObjectLiteralExpression;
    if (node.MultiLine == 2) {
        const properties = printer.tree.getNodeList(node.Properties);
        printer.writer.writePunctuation("{");
        if (properties.len != 0) printer.writer.writeSpace(" ");
        printer.writer.increaseIndent();
        for (properties, 0..) |property, index| {
            if (index != 0) {
                printer.writer.writePunctuation(",");
                printer.writer.writeLine();
            }
            try printer.printNode(property);
        }
        printer.writer.decreaseIndent();
        if (properties.len != 0) printer.writer.writeSpace(" ");
        printer.writer.writePunctuation("}");
        return;
    }
    var format: u32 = @import("emit_list.zig").ListFormat.ObjectLiteralExpressionProperties;
    if (node.MultiLine == 1) {
        format |= @import("emit_list.zig").ListFormat.MultiLine | @import("emit_list.zig").ListFormat.SpaceBetweenBraces | @import("emit_list.zig").ListFormat.Indented | @import("emit_list.zig").ListFormat.CommaDelimited;
    } else if (node.MultiLine == 2) {
        format |= @import("emit_list.zig").ListFormat.SpaceBetweenBraces | @import("emit_list.zig").ListFormat.Indented | @import("emit_list.zig").ListFormat.CommaDelimited;
    } else {
        format |= @import("emit_list.zig").ListFormat.SingleLine | @import("emit_list.zig").ListFormat.SpaceBetweenBraces | @import("emit_list.zig").ListFormat.CommaDelimited;
    }
    format |= @import("emit_list.zig").ListFormat.NoSpaceIfEmpty;
    try printer.emitList(null, nodeIndex, node.Properties, format);
}

pub fn printShorthandPropertyAssignment(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ShorthandPropertyAssignment;
    if (node.modifiers != null and node.modifiers.? != 0) {
        try printer.printModifiers(node.modifiers.?);
    }
    try printer.printNode(node.name);
    if (node.EqualsToken != null and node.EqualsToken.? != 0) {
        printer.writer.writeSpace(" ");
        printer.writer.writePunctuation("=");
        printer.writer.writeSpace(" ");
        try printer.printNode(node.ObjectAssignmentInitializer.?);
    }
}

pub fn printPropertyAssignment(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).PropertyAssignment;
    if (node.modifiers != null and node.modifiers.? != 0) {
        try printer.printModifiers(node.modifiers.?);
    }
    try printer.printNode(node.name);
    printer.writer.writePunctuation(":");
    printer.writer.writeSpace(" ");
    try printer.printNode(node.Initializer);
}

pub fn printSpreadAssignment(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).SpreadAssignment;
    printer.writer.writePunctuation("...");
    try printer.printNode(node.Expression);
}

pub fn printPropertyAccessExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).PropertyAccessExpression;
    try printer.printNode(node.Expression);
    const hasNewlineBeforeDot = (node.Flags & (1 << 31)) != 0;
    if (hasNewlineBeforeDot) {
        printer.writer.writeLine();
        printer.writer.increaseIndent();
    }
    if (node.QuestionDotToken != null and node.QuestionDotToken.? != 0) {
        try printer.printNode(node.QuestionDotToken.?);
    } else {
        var shouldEmitDotDot = false;
        const exprNodeData = printer.tree.getNode(node.Expression);
        if (exprNodeData == .NumericLiteral) {
            const numNode = exprNodeData.NumericLiteral;
            const text = numNode.Text;
            const hasSpecifier = text.len >= 2 and text[0] == '0' and (text[1] == 'x' or text[1] == 'X' or text[1] == 'b' or text[1] == 'B' or text[1] == 'o' or text[1] == 'O');
            if (!hasSpecifier and std.mem.indexOfScalar(u8, text, '.') == null and std.mem.indexOfScalar(u8, text, 'E') == null and std.mem.indexOfScalar(u8, text, 'e') == null) {
                shouldEmitDotDot = true;
            }
        }
        if (shouldEmitDotDot) {
            printer.writer.writePunctuation(".");
        }
        printer.writer.writePunctuation(".");
    }
    const hasNewlineAfterDot = (node.Flags & (1 << 30)) != 0;
    if (hasNewlineAfterDot) {
        printer.writer.writeLine();
        printer.writer.increaseIndent();
    }
    try printer.printNode(node.name);
    if (hasNewlineAfterDot) {
        printer.writer.decreaseIndent();
    }
    if (hasNewlineBeforeDot) {
        printer.writer.decreaseIndent();
    }
}

pub fn printElementAccessExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ElementAccessExpression;
    try printer.printNode(node.Expression);
    if (node.QuestionDotToken != null and node.QuestionDotToken.? != 0) {
        try printer.printNode(node.QuestionDotToken.?);
    }
    printer.writer.writePunctuation("[");
    try printer.printNode(node.ArgumentExpression);
    printer.writer.writePunctuation("]");
}

pub fn printCallExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).CallExpression;
    try printer.printNode(node.Expression);
    if (node.QuestionDotToken != null and node.QuestionDotToken.? != 0) {
        try printer.printNode(node.QuestionDotToken.?);
    }
    if (node.TypeArguments != null and node.TypeArguments.? != 0) {
        try printer.printTypeArguments(node.TypeArguments.?);
    }
    printer.writer.writePunctuation("(");
    const args = printer.tree.getNodeList(node.Arguments);
    for (args, 0..) |argIndex, i| {
        const inferred_jsx_child_line = i >= 2 and printer.tree.getNode(argIndex) == .CallExpression and
            isCreateElementCallee(printer, node.Expression) and
            isCreateElementCallee(printer, printer.tree.getNode(argIndex).CallExpression.Expression);
        const starts_on_new_line = (printer.context.getEmitFlags(argIndex) & @import("emitflags.zig").EmitFlags.StartOnNewLine) != 0 or inferred_jsx_child_line;
        if (i > 0) {
            printer.writer.writePunctuation(",");
            if (starts_on_new_line) {
                printer.writer.increaseIndent();
                printer.writer.writeLine();
            } else {
                printer.writer.writeSpace(" ");
            }
        }
        try printer.printNode(argIndex);
        if (i > 0 and starts_on_new_line) printer.writer.decreaseIndent();
    }
    printer.writer.writePunctuation(")");
}

fn isCreateElementCallee(printer: *Printer, nodeIndex: ast_mod.NodeIndex) bool {
    return switch (printer.tree.getNode(nodeIndex)) {
        .PropertyAccessExpression => |node| std.mem.eql(u8, ast_utils.getTextOfNode(printer.tree, node.name), "createElement"),
        else => false,
    };
}

pub fn printNewExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).NewExpression;
    printer.writer.writeKeyword("new ");
    try printer.printNode(node.Expression);
    if (node.TypeArguments != null) {
        printer.writer.writePunctuation("<");
        const typeArgs = printer.tree.getNodeList(node.TypeArguments.?);
        for (typeArgs, 0..) |argIndex, i| {
            if (i > 0) {
                printer.writer.writePunctuation(",");
                printer.writer.writeSpace(" ");
            }
            try printer.printNode(argIndex);
        }
        printer.writer.writePunctuation(">");
    }
    if (node.Arguments != null) {
        printer.writer.writePunctuation("(");
        const args = printer.tree.getNodeList(node.Arguments.?);
        for (args, 0..) |argIndex, i| {
            if (i > 0) {
                printer.writer.writePunctuation(",");
                printer.writer.writeSpace(" ");
            }
            try printer.printNode(argIndex);
        }
        printer.writer.writePunctuation(")");
    }
}

pub fn printTaggedTemplateExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).TaggedTemplateExpression;
    try printer.printNode(node.Tag);

    if (node.TypeArguments != null and node.TypeArguments.? != 0) {
        try printer.printTypeArguments(node.TypeArguments.?);
    }

    printer.writer.writeSpace(" ");
    try printer.printNode(node.Template);
}

pub fn printTypeAssertionExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).TypeAssertionExpression;
    printer.writer.writePunctuation("<");
    try printer.printNode(node.Type);
    printer.writer.writePunctuation(">");
    try printer.printNode(node.Expression);
}

pub fn printParenthesizedExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ParenthesizedExpression;
    printer.writer.writePunctuation("(");
    const multiline_comma = printer.tree.getNode(node.Expression) == .BinaryExpression and
        printer.tree.getNode(node.Expression).BinaryExpression.linesAfterOperator != 0;
    if (multiline_comma) {
        printer.writer.increaseIndent();
        if ((node.Flags & (1 << 31)) != 0) printer.writer.increaseIndent();
    }
    try printer.printNode(node.Expression);
    if (multiline_comma) {
        if ((node.Flags & (1 << 31)) != 0) printer.writer.decreaseIndent();
        printer.writer.decreaseIndent();
    }
    printer.writer.writePunctuation(")");
}

pub fn printFunctionExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).FunctionExpression;
    if (node.modifiers != null and node.modifiers.? != 0) {
        try printer.printModifiers(node.modifiers.?);
    }
    printer.writer.writeKeyword("function");
    if (node.AsteriskToken != null and node.AsteriskToken.? != 0) {
        printer.writer.writePunctuation("*");
    }
    printer.writer.writeSpace(" ");
    if (node.name != null) {
        try printer.printNode(node.name.?);
    }
    if (node.TypeParameters != null and node.TypeParameters.? != 0) {
        try printer.printTypeParameters(node.TypeParameters.?);
    }
    printer.writer.writePunctuation("(");
    const params = printer.tree.getNodeList(node.Parameters);
    for (params, 0..) |paramIndex, i| {
        if (i > 0) {
            printer.writer.writePunctuation(",");
            printer.writer.writeSpace(" ");
        }
        try printer.printNode(paramIndex);
    }
    printer.writer.writePunctuation(")");
    if (node.Type != null and node.Type.? != 0) {
        printer.writer.writePunctuation(":");
        printer.writer.writeSpace(" ");
        try printer.printNode(node.Type.?);
    }
    printer.writer.writeSpace(" ");
    try @import("emit_stmt.zig").printFunctionBody(printer, node.Body.?);
}

pub fn printArrowFunction(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ArrowFunction;
    try printer.emitModifierList(nodeIndex, node.modifiers, false);
    var isSimple = (node.Flags & (1 << 29)) != 0;
    if (node.modifiers != null) isSimple = false;
    if (node.TypeParameters != null) isSimple = false;

    if (node.TypeParameters != null) {
        printer.writer.writePunctuation("<");
        const typeParams = printer.tree.getNodeList(node.TypeParameters.?);
        for (typeParams, 0..) |paramIndex, i| {
            if (i > 0) {
                printer.writer.writePunctuation(",");
                printer.writer.writeSpace(" ");
            }
            try printer.printNode(paramIndex);
        }
        printer.writer.writePunctuation(">");
    }

    if (!isSimple) {
        printer.writer.writePunctuation("(");
    }
    const params = printer.tree.getNodeList(node.Parameters);
    for (params, 0..) |paramIndex, i| {
        if (i > 0) {
            printer.writer.writePunctuation(",");
            printer.writer.writeSpace(" ");
        }
        try printer.printNode(paramIndex);
    }
    if (!isSimple) {
        printer.writer.writePunctuation(")");
    }
    if (node.Type != null and node.Type.? != 0) {
        printer.writer.writePunctuation(":");
        printer.writer.writeSpace(" ");
        try printer.printNode(node.Type.?);
    }
    printer.writer.writeSpace(" ");
    if (node.EqualsGreaterThanToken != 0) {
        try printer.printNode(node.EqualsGreaterThanToken);
    } else {
        printer.writer.writePunctuation("=>");
    }
    printer.writer.writeSpace(" ");
    try @import("emit_stmt.zig").printFunctionBody(printer, node.Body.?);
}

pub fn printDeleteExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).DeleteExpression;
    printer.writer.writeKeyword("delete ");
    try printer.printNode(node.Expression);
}

pub fn printTypeOfExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).TypeOfExpression;
    printer.writer.writeKeyword("typeof ");
    try printer.printNode(node.Expression);
}

pub fn printVoidExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).VoidExpression;
    printer.writer.writeKeyword("void ");
    try printer.printNode(node.Expression);
}

pub fn printAwaitExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).AwaitExpression;
    printer.writer.writeKeyword("await ");
    try printer.printNode(node.Expression);
}

pub fn printPrefixUnaryExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).PrefixUnaryExpression;
    const opKind: @import("../ast/kind.zig").Kind = @enumFromInt(node.Operator);
    const opText = @import("utilities.zig").tokenToString(opKind);
    if (opText) |text| {
        printer.writer.writeOperator(text);
    }
    // Insert space between +/+ or -/- to prevent merging (e.g. `+ +a` not `++a`)
    if (std.meta.activeTag(printer.tree.getNode(node.Operand)) == .PrefixUnaryExpression) {
        const inner = printer.tree.getNode(node.Operand).PrefixUnaryExpression;
        const innerKind: @import("../ast/kind.zig").Kind = @enumFromInt(inner.Operator);
        const needsSpace = (opKind == .PlusToken and (innerKind == .PlusToken or innerKind == .PlusPlusToken)) or
            (opKind == .MinusToken and (innerKind == .MinusToken or innerKind == .MinusMinusToken));
        if (needsSpace) {
            printer.writer.writeSpace(" ");
        }
    }
    try printer.printNode(node.Operand);
}

pub fn printPostfixUnaryExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).PostfixUnaryExpression;
    try printer.printNode(node.Operand);
    const opKind: @import("../ast/kind.zig").Kind = @enumFromInt(node.Operator);
    const opText = @import("utilities.zig").tokenToString(opKind);
    if (opText) |text| {
        printer.writer.writeOperator(text);
    }
}

pub fn printBinaryExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).BinaryExpression;
    const opKind = std.meta.activeTag(printer.tree.getNode(node.OperatorToken));
    const isComma = opKind == .CommaToken;

    const precs = precedence.getBinaryExpressionPrecedence(printer.tree, nodeIndex);
    var leftPrec = precs.left;
    var rightPrec = precs.right;

    const emittedLeft = precedence.skipPartiallyEmittedExpressions(printer.tree, node.Left);
    if (ast_utils.nodeIsSynthesized(printer.tree, emittedLeft) and std.meta.activeTag(printer.tree.getNode(emittedLeft)) == .BinaryExpression) {
        const leftOp = std.meta.activeTag(printer.tree.getNode(printer.tree.getNode(emittedLeft).BinaryExpression.OperatorToken));
        if (precedence.mixingBinaryOperatorsRequiresParentheses(opKind, leftOp)) {
            leftPrec = .Highest;
        }
    }
    const emittedRight = precedence.skipPartiallyEmittedExpressions(printer.tree, node.Right);
    if (ast_utils.nodeIsSynthesized(printer.tree, emittedRight) and std.meta.activeTag(printer.tree.getNode(emittedRight)) == .BinaryExpression) {
        const rightOp = std.meta.activeTag(printer.tree.getNode(printer.tree.getNode(emittedRight).BinaryExpression.OperatorToken));
        if (precedence.mixingBinaryOperatorsRequiresParentheses(opKind, rightOp)) {
            rightPrec = .Highest;
        }
    }

    try printer.emitExpression(node.Left, @intCast(@intFromEnum(leftPrec)));

    if (node.linesBeforeOperator > 0) {
        // newline before operator: emit newline + increase indent + operator + decrease
        printer.writer.writeLine();
        printer.writer.increaseIndent();
        try printer.printNode(node.OperatorToken);
        printer.writer.decreaseIndent();
    } else {
        if (!isComma) {
            printer.writer.writeSpace(" ");
        }
        try printer.printNode(node.OperatorToken);
    }
    if (node.linesAfterOperator > 0) {
        // newline after operator: emit newline + increase indent + right + decrease
        printer.writer.writeLine();
        if (!isComma) printer.writer.increaseIndent();
        try printer.emitExpression(node.Right, @intCast(@intFromEnum(rightPrec)));
        if (!isComma) printer.writer.decreaseIndent();
    } else {
        printer.writer.writeSpace(" ");
        try printer.emitExpression(node.Right, @intCast(@intFromEnum(rightPrec)));
    }
}

pub fn printConditionalExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ConditionalExpression;
    try printer.printNode(node.Condition);
    // Before '?'
    if (node.linesBeforeQuestion > 0) {
        printer.writer.writeLine();
        printer.writer.increaseIndent();
        printer.writer.writePunctuation("?");
        printer.writer.decreaseIndent();
    } else {
        printer.writer.writeSpace(" ");
        printer.writer.writePunctuation("?");
    }
    // After '?' / before WhenTrue
    if (node.linesAfterQuestion > 0) {
        printer.writer.writeLine();
        printer.writer.increaseIndent();
        try printer.printNode(node.WhenTrue);
        printer.writer.decreaseIndent();
    } else {
        printer.writer.writeSpace(" ");
        try printer.printNode(node.WhenTrue);
    }
    // Before ':'
    if (node.linesBeforeColon > 0) {
        printer.writer.writeLine();
        printer.writer.increaseIndent();
        printer.writer.writePunctuation(":");
        printer.writer.decreaseIndent();
    } else {
        printer.writer.writeSpace(" ");
        printer.writer.writePunctuation(":");
    }
    // After ':' / before WhenFalse
    if (node.linesAfterColon > 0) {
        printer.writer.writeLine();
        printer.writer.increaseIndent();
        try printer.printNode(node.WhenFalse);
        printer.writer.decreaseIndent();
    } else {
        printer.writer.writeSpace(" ");
        try printer.printNode(node.WhenFalse);
    }
}

pub fn printTemplateExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).TemplateExpression;
    try printer.printNode(node.Head);
    const spans = printer.tree.getNodeList(node.TemplateSpans);
    for (spans) |spanIndex| {
        try printer.printNode(spanIndex);
    }
}

pub fn printYieldExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).YieldExpression;
    printer.writer.writeKeyword("yield");
    if (node.AsteriskToken != null and node.AsteriskToken.? != 0) {
        printer.writer.writePunctuation("*");
    }
    if (node.Expression != null and node.Expression.? != 0) {
        printer.writer.writeSpace(" ");
        try printer.printNode(node.Expression.?);
    }
}

pub fn printSpreadElement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).SpreadElement;
    printer.writer.writePunctuation("...");
    try printer.printNode(node.Expression);
}

pub fn printClassExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ClassExpression;
    if (node.modifiers != null and node.modifiers.? != 0) {
        try printer.emitList(null, nodeIndex, node.modifiers.?, @import("emit_list.zig").ListFormat.Modifiers);
    }
    printer.writer.writeKeyword("class");
    if (node.name != null and node.name.? != 0) {
        printer.writer.writeSpace(" ");
        try printer.printNode(node.name.?);
    }
    if (node.TypeParameters != null and node.TypeParameters.? != 0) {
        try printer.emitList(null, nodeIndex, node.TypeParameters.?, @import("emit_list.zig").ListFormat.TypeParameters);
    }
    if (node.HeritageClauses != null and node.HeritageClauses.? != 0) {
        printer.writer.writeSpace(" ");
        try printer.emitList(null, nodeIndex, node.HeritageClauses.?, @import("emit_list.zig").ListFormat.SingleLine | @import("emit_list.zig").ListFormat.SpaceBetweenSiblings);
    }
    printer.writer.writeSpace(" ");
    printer.writer.writePunctuation("{");
    try printer.emitList(null, nodeIndex, node.Members, @import("emit_list.zig").ListFormat.ClassMembers);
    printer.writer.writePunctuation("}");
}

pub fn printOmittedExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    _ = printer;
    _ = nodeIndex;
    // OmittedExpression writes nothing
}

pub fn printAsExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).AsExpression;
    try printer.printNode(node.Expression);
    printer.writer.writeKeyword(" as ");
    try printer.printNode(node.Type);
}

pub fn printNonNullExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).NonNullExpression;
    try printer.printNode(node.Expression);
    printer.writer.writePunctuation("!");
}

pub fn printExpressionWithTypeArguments(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ExpressionWithTypeArguments;
    try printer.printNode(node.Expression);
    if (node.TypeArguments != null) {
        printer.writer.writePunctuation("<");
        const typeArgs = printer.tree.getNodeList(node.TypeArguments.?);
        for (typeArgs, 0..) |argIndex, i| {
            if (i > 0) {
                printer.writer.writePunctuation(",");
                printer.writer.writeSpace(" ");
            }
            try printer.printNode(argIndex);
        }
        printer.writer.writePunctuation(">");
    }
}

pub fn printMetaProperty(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).MetaProperty;
    if (node.KeywordToken == @intFromEnum(@import("../ast/kind.zig").Kind.NewKeyword)) {
        printer.writer.writeKeyword("new");
    } else if (node.KeywordToken == @intFromEnum(@import("../ast/kind.zig").Kind.ImportKeyword)) {
        printer.writer.writeKeyword("import");
    } else {
        // Fallback, just in case
        printer.writer.writeKeyword("unknown");
    }
    printer.writer.writePunctuation(".");
    try printer.printNode(node.name);
}

pub fn printSatisfiesExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).SatisfiesExpression;
    try printer.printNode(node.Expression);
    printer.writer.writeKeyword(" satisfies ");
    try printer.printNode(node.Type);
}

pub fn printPartiallyEmittedExpression(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).PartiallyEmittedExpression;
    try printer.printNode(node.Expression);
}
