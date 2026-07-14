const std = @import("std");
const ast_mod = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const Printer = @import("printer.zig").Printer;

fn printStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    try printer.printNode(nodeIndex);
}
fn printArgument(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    try printer.printNode(nodeIndex);
}

// Port of isEmptyBlock
pub fn isEmptyBlock(printer: *Printer, blockIndex: ast_mod.NodeIndex, statementsIndex: ast_mod.NodeIndex) bool {
    const statements = printer.tree.getNodeList(statementsIndex);
    return statements.len == 0 and
        (printer.currentSourceFile == 0 or printer.rangeEndIsOnSameLineAsRangeStart(blockIndex, blockIndex, printer.currentSourceFile));
}

pub fn printFunctionBody(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex);
    if (node != .Block) {
        try printer.printNode(nodeIndex);
        return;
    }
    const state = try printer.enterNode(nodeIndex);
    try printer.generateNames(nodeIndex);
    _ = try printer.emitToken(.OpenBraceToken, 0, .Punctuation, nodeIndex);

    const statements = node.Block.Statements;
    const statementsList = if (statements == 0) &[_]ast_mod.NodeIndex{} else printer.tree.getNodeList(statements);

    const singleLine = printer.shouldEmitBlockFunctionBodyOnSingleLine(nodeIndex);
    if (singleLine and statementsList.len == 0) {
        printer.writer.writeSpace(" ");
    } else {
        const format = if (singleLine) @import("emit_list.zig").ListFormat.SingleLineFunctionBodyStatements else @import("emit_list.zig").ListFormat.MultiLineBlockStatements;
        try printer.emitList(printStatement, nodeIndex, statements, format);
    }

    const endPos = 0;
    const closeBraceFormat: u32 = 0;
    _ = try printer.emitTokenEx(.CloseBraceToken, endPos, .Punctuation, nodeIndex, closeBraceFormat);
    try printer.exitNode(nodeIndex, state);
}

// emitBlock
pub fn printBlock(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).Block;
    const state = try printer.enterNode(nodeIndex);
    try printer.generateNames(nodeIndex);
    _ = try printer.emitToken(.OpenBraceToken, 0, .Punctuation, nodeIndex);

    const statements = node.Statements;
    const statementsList = if (statements == 0) &[_]ast_mod.NodeIndex{} else printer.tree.getNodeList(statements);

    const singleLine = (!node.MultiLine and isEmptyBlock(printer, nodeIndex, statements)) or printer.shouldEmitOnSingleLine(nodeIndex);
    if (singleLine and statementsList.len == 0) {
        printer.writer.writeSpace(" ");
    } else {
        const format = if (singleLine) @import("emit_list.zig").ListFormat.SingleLineFunctionBodyStatements else @import("emit_list.zig").ListFormat.MultiLineBlockStatements;
        try printer.emitList(printStatement, nodeIndex, statements, format);
    }

    const endPos = 0;
    const closeBraceFormat: u32 = 0;
    _ = try printer.emitTokenEx(.CloseBraceToken, endPos, .Punctuation, nodeIndex, closeBraceFormat);
    try printer.exitNode(nodeIndex, state);
}

// emitVariableStatement
pub fn printVariableStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).VariableStatement;
    const state = try printer.enterNode(nodeIndex);
    try printer.emitModifierList(nodeIndex, node.modifiers, false);
    try printer.emitVariableDeclarationList(node.DeclarationList);
    printer.writer.writeTrailingSemicolon(";");
    try printer.exitNode(nodeIndex, state);
}

// emitEmptyStatement
pub fn printEmptyStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex, isEmbeddedStatement: bool) anyerror!void {
    const state = try printer.enterNode(nodeIndex);
    if (isEmbeddedStatement) {
        printer.writer.writePunctuation(";");
    } else {
        printer.writer.writeTrailingSemicolon(";");
    }
    try printer.exitNode(nodeIndex, state);
}

// emitExpressionStatement
pub fn printExpressionStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ExpressionStatement;
    const state = try printer.enterNode(nodeIndex);

    if (printer.currentSourceFile != 0) {
        try printer.emitExpression(node.Expression, 0);
    } else if (printer.isImmediatelyInvokedFunctionExpressionOrArrowFunction(node.Expression)) {
        try printIIFEWithParenthesizedCallee(printer, node.Expression);
    } else {
        _ = printer.getLeftmostExpression(node.Expression, false);

        try printer.emitExpression(node.Expression, 0);
    }

    if (printer.currentSourceFile == 0 or
        true or
        printer.nodeIsSynthesized(node.Expression))
    {
        printer.writer.writeTrailingSemicolon(";");
    }

    try printer.exitNode(nodeIndex, state);
}

pub fn printIIFEWithParenthesizedCallee(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const callIndex = printer.skipPartiallyEmittedExpressions(nodeIndex);
    const call = printer.tree.getNode(callIndex).CallExpression;
    const state = try printer.enterNode(callIndex);
    printer.writer.writePunctuation("(");
    try printer.emitExpression(call.Expression, 0);
    printer.writer.writePunctuation(")");
    try printer.emitTokenNode(call.QuestionDotToken);
    try printer.emitTypeArguments(callIndex, call.TypeArguments);
    try printer.emitList(printArgument, callIndex, call.Arguments, 0);
    try printer.exitNode(callIndex, state);
}

// emitIfStatement
pub fn printIfStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).IfStatement;
    const state = try printer.enterNode(nodeIndex);
    const pos = try printer.emitToken(.IfKeyword, 0, .Keyword, nodeIndex);
    printer.writer.writeSpace(" ");
    _ = try printer.emitToken(.OpenParenToken, pos, .Punctuation, nodeIndex);
    try printer.emitExpression(node.Expression, 0);
    _ = try printer.emitToken(.CloseParenToken, 0, .Punctuation, nodeIndex);
    try printer.emitEmbeddedStatement(nodeIndex, node.ThenStatement);
    if (node.ElseStatement) |elseStmt| {
        if (elseStmt != 0) {
            try printer.writeLineOrSpace(nodeIndex, node.ThenStatement, elseStmt);
            _ = try printer.emitToken(.ElseKeyword, 0, .Keyword, nodeIndex);
            if (std.meta.activeTag(printer.tree.getNode(elseStmt)) == .IfStatement) {
                printer.writer.writeSpace(" ");
                try printIfStatement(printer, elseStmt);
            } else {
                try printer.emitEmbeddedStatement(nodeIndex, elseStmt);
            }
        }
    }
    try printer.exitNode(nodeIndex, state);
}

// emitWhileClause
pub fn printWhileClause(printer: *Printer, nodeIndex: ast_mod.NodeIndex, expressionIndex: ast_mod.NodeIndex, startPos: usize) anyerror!void {
    const pos = try printer.emitToken(.WhileKeyword, startPos, .Keyword, nodeIndex);
    printer.writer.writeSpace(" ");
    _ = try printer.emitToken(.OpenParenToken, pos, .Punctuation, nodeIndex);
    try printer.emitExpression(expressionIndex, 0);
    _ = try printer.emitToken(.CloseParenToken, 0, .Punctuation, nodeIndex);
}

// emitDoStatement
pub fn printDoStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).DoStatement;
    const state = try printer.enterNode(nodeIndex);
    _ = try printer.emitToken(.DoKeyword, 0, .Keyword, nodeIndex);
    try printer.emitEmbeddedStatement(nodeIndex, node.Statement);
    if (std.meta.activeTag(printer.tree.getNode(node.Statement)) == .Block) {
        printer.writer.writeSpace(" ");
    } else {
        try printer.writeLineOrSpace(nodeIndex, node.Statement, node.Expression);
    }
    try printWhileClause(printer, nodeIndex, node.Expression, 0);
    printer.writer.writeTrailingSemicolon(";");
    try printer.exitNode(nodeIndex, state);
}

// emitWhileStatement
pub fn printWhileStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).WhileStatement;
    const state = try printer.enterNode(nodeIndex);
    try printWhileClause(printer, nodeIndex, node.Expression, 0);
    try printer.emitEmbeddedStatement(nodeIndex, node.Statement);
    try printer.exitNode(nodeIndex, state);
}

// emitForInitializer
pub fn printForInitializer(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    if (std.meta.activeTag(printer.tree.getNode(nodeIndex)) == .VariableDeclarationList) {
        try printer.printNode(nodeIndex);
    } else {
        try printer.emitExpression(nodeIndex, 0);
    }
}

// emitForStatement
pub fn printForStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ForStatement;
    const state = try printer.enterNode(nodeIndex);
    var pos = try printer.emitToken(.ForKeyword, 0, .Keyword, nodeIndex);
    printer.writer.writeSpace(" ");
    pos = try printer.emitToken(.OpenParenToken, pos, .Punctuation, nodeIndex);
    if (node.Initializer) |init| {
        if (init != 0) {
            try printForInitializer(printer, init);
            pos = 0;
        }
    }
    pos = try printer.emitToken(.SemicolonToken, pos, .Punctuation, nodeIndex);
    if (node.Condition) |cond| {
        if (cond != 0) {
            printer.writer.writeSpace(" ");
            try printer.emitExpression(cond, 0);
            pos = 0;
        }
    }
    pos = try printer.emitToken(.SemicolonToken, pos, .Punctuation, nodeIndex);
    if (node.Incrementor) |inc| {
        if (inc != 0) {
            printer.writer.writeSpace(" ");
            try printer.emitExpression(inc, 0);
            pos = 0;
        }
    }
    _ = try printer.emitToken(.CloseParenToken, pos, .Punctuation, nodeIndex);
    try printer.emitEmbeddedStatement(nodeIndex, node.Statement);
    try printer.exitNode(nodeIndex, state);
}

// emitForInStatement
pub fn printForInStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ForInStatement;
    const state = try printer.enterNode(nodeIndex);
    const pos = try printer.emitToken(.ForKeyword, 0, .Keyword, nodeIndex);
    printer.writer.writeSpace(" ");
    _ = try printer.emitToken(.OpenParenToken, pos, .Punctuation, nodeIndex);
    try printForInitializer(printer, node.Initializer);
    printer.writer.writeSpace(" ");
    _ = try printer.emitToken(.InKeyword, 0, .Keyword, nodeIndex);
    printer.writer.writeSpace(" ");
    try printer.emitExpression(node.Expression, 0);
    _ = try printer.emitToken(.CloseParenToken, 0, .Punctuation, nodeIndex);
    try printer.emitEmbeddedStatement(nodeIndex, node.Statement);
    try printer.exitNode(nodeIndex, state);
}

// emitForOfStatement
pub fn printForOfStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ForOfStatement;
    const state = try printer.enterNode(nodeIndex);
    const openParenPos = try printer.emitToken(.ForKeyword, 0, .Keyword, nodeIndex);
    printer.writer.writeSpace(" ");
    if (node.AwaitModifier) |awaitMod| {
        if (awaitMod != 0) {
            try printer.emitKeywordNode(awaitMod);
            printer.writer.writeSpace(" ");
        }
    }
    _ = try printer.emitToken(.OpenParenToken, openParenPos, .Punctuation, nodeIndex);
    try printForInitializer(printer, node.Initializer);
    printer.writer.writeSpace(" ");
    _ = try printer.emitToken(.OfKeyword, 0, .Keyword, nodeIndex);
    printer.writer.writeSpace(" ");
    try printer.emitExpression(node.Expression, 0);
    _ = try printer.emitToken(.CloseParenToken, 0, .Punctuation, nodeIndex);
    try printer.emitEmbeddedStatement(nodeIndex, node.Statement);
    try printer.exitNode(nodeIndex, state);
}

// emitContinueStatement
pub fn printContinueStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ContinueStatement;
    const state = try printer.enterNode(nodeIndex);
    _ = try printer.emitToken(.ContinueKeyword, 0, .Keyword, nodeIndex);
    if (node.Label) |label| {
        if (label != 0) {
            printer.writer.writeSpace(" ");
            try printer.emitLabelIdentifier(label);
        }
    }
    printer.writer.writeTrailingSemicolon(";");
    try printer.exitNode(nodeIndex, state);
}

// emitBreakStatement
pub fn printBreakStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).BreakStatement;
    const state = try printer.enterNode(nodeIndex);
    _ = try printer.emitToken(.BreakKeyword, 0, .Keyword, nodeIndex);
    if (node.Label) |label| {
        if (label != 0) {
            printer.writer.writeSpace(" ");
            try printer.emitLabelIdentifier(label);
        }
    }
    printer.writer.writeTrailingSemicolon(";");
    try printer.exitNode(nodeIndex, state);
}

// emitReturnStatement
pub fn printReturnStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ReturnStatement;
    const state = try printer.enterNode(nodeIndex);
    _ = try printer.emitToken(.ReturnKeyword, 0, .Keyword, nodeIndex);
    if (node.Expression) |expr| {
        if (expr != 0) {
            printer.writer.writeSpace(" ");
            try printer.emitExpressionNoASI(expr, 0);
        }
    }
    printer.writer.writeTrailingSemicolon(";");
    try printer.exitNode(nodeIndex, state);
}

// emitWithStatement
pub fn printWithStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).WithStatement;
    const state = try printer.enterNode(nodeIndex);
    const pos = try printer.emitToken(.WithKeyword, 0, .Keyword, nodeIndex);
    printer.writer.writeSpace(" ");
    _ = try printer.emitToken(.OpenParenToken, pos, .Punctuation, nodeIndex);
    try printer.emitExpression(node.Expression, 0);
    _ = try printer.emitToken(.CloseParenToken, 0, .Punctuation, nodeIndex);
    try printer.emitEmbeddedStatement(nodeIndex, node.Statement);
    try printer.exitNode(nodeIndex, state);
}

// emitSwitchStatement
pub fn printSwitchStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).SwitchStatement;
    const state = try printer.enterNode(nodeIndex);
    const pos = try printer.emitToken(.SwitchKeyword, 0, .Keyword, nodeIndex);
    printer.writer.writeSpace(" ");
    _ = try printer.emitToken(.OpenParenToken, pos, .Punctuation, nodeIndex);
    try printer.emitExpression(node.Expression, 0);
    _ = try printer.emitToken(.CloseParenToken, 0, .Punctuation, nodeIndex);
    printer.writer.writeSpace(" ");
    try printer.emitCaseBlock(node.CaseBlock);
    try printer.exitNode(nodeIndex, state);
}

// emitCaseBlock
pub fn printCaseBlock(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).CaseBlock;
    const state = try printer.enterNode(nodeIndex);
    _ = try printer.emitToken(.OpenBraceToken, 0, .Punctuation, nodeIndex);
    const CaseBlockClauses = @import("emit_list.zig").ListFormat.CaseBlockClauses;
    try printer.emitList(Printer.printNode, nodeIndex, node.Clauses, CaseBlockClauses);
    _ = try printer.emitToken(.CloseBraceToken, 0, .Punctuation, nodeIndex);
    try printer.exitNode(nodeIndex, state);
}

// emitLabeledStatement
pub fn printLabeledStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).LabeledStatement;
    const state = try printer.enterNode(nodeIndex);
    try printer.emitLabelIdentifier(node.Label);
    _ = try printer.emitToken(.ColonToken, 0, .Punctuation, nodeIndex);
    printer.writer.writeSpace(" ");
    try printer.emitStatement(node.Statement);
    try printer.exitNode(nodeIndex, state);
}

// emitThrowStatement
pub fn printThrowStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ThrowStatement;
    const state = try printer.enterNode(nodeIndex);
    _ = try printer.emitToken(.ThrowKeyword, 0, .Keyword, nodeIndex);
    printer.writer.writeSpace(" ");
    try printer.emitExpressionNoASI(node.Expression, 0);
    printer.writer.writeTrailingSemicolon(";");
    try printer.exitNode(nodeIndex, state);
}

// emitTryStatement
pub fn printTryStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).TryStatement;
    const state = try printer.enterNode(nodeIndex);
    _ = try printer.emitToken(.TryKeyword, 0, .Keyword, nodeIndex);
    printer.writer.writeSpace(" ");
    try printer.emitBlock(node.TryBlock);
    if (node.CatchClause) |catchClause| {
        if (catchClause != 0) {
            try printer.writeLineOrSpace(nodeIndex, node.TryBlock, catchClause);
            try printer.emitCatchClause(catchClause);
        }
    }
    if (node.FinallyBlock) |finallyBlock| {
        if (finallyBlock != 0) {
            const catchOrTry = if (node.CatchClause != null and node.CatchClause.? != 0) node.CatchClause.? else node.TryBlock;
            try printer.writeLineOrSpace(nodeIndex, catchOrTry, finallyBlock);
            _ = try printer.emitToken(.FinallyKeyword, 0, .Keyword, nodeIndex);
            printer.writer.writeSpace(" ");
            try printer.emitBlock(finallyBlock);
        }
    }
    try printer.exitNode(nodeIndex, state);
}

// emitDebuggerStatement
pub fn printDebuggerStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const state = try printer.enterNode(nodeIndex);
    _ = try printer.emitToken(.DebuggerKeyword, 0, .Keyword, nodeIndex);
    printer.writer.writeTrailingSemicolon(";");
    try printer.exitNode(nodeIndex, state);
}

// emitNotEmittedStatement
pub fn printNotEmittedStatement(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const state = try printer.enterNode(nodeIndex);
    try printer.exitNode(nodeIndex, state);
}
// emitCaseClause
pub fn printCaseClause(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).CaseClause;
    const state = try printer.enterNode(nodeIndex);
    const pos = try printer.emitToken(.CaseKeyword, 0, .Keyword, nodeIndex);
    printer.writer.writeSpace(" ");
    try printer.emitExpression(node.Expression, 0);
    _ = try printer.emitToken(.ColonToken, pos, .Punctuation, nodeIndex);
    const CaseOrDefaultClauseStatements = @import("emit_list.zig").ListFormat.CaseOrDefaultClauseStatements;
    try printer.emitList(Printer.printNode, nodeIndex, node.Statements, CaseOrDefaultClauseStatements);
    try printer.exitNode(nodeIndex, state);
}

// emitDefaultClause
pub fn printDefaultClause(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).DefaultClause;
    const state = try printer.enterNode(nodeIndex);
    const pos = try printer.emitToken(.DefaultKeyword, 0, .Keyword, nodeIndex);
    _ = try printer.emitToken(.ColonToken, pos, .Punctuation, nodeIndex);
    const CaseOrDefaultClauseStatements = @import("emit_list.zig").ListFormat.CaseOrDefaultClauseStatements;
    try printer.emitList(Printer.printNode, nodeIndex, node.Statements, CaseOrDefaultClauseStatements);
    try printer.exitNode(nodeIndex, state);
}

// emitCatchClause
pub fn printCatchClause(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).CatchClause;
    const state = try printer.enterNode(nodeIndex);
    const pos = try printer.emitToken(.CatchKeyword, 0, .Keyword, nodeIndex);
    if (node.VariableDeclaration) |varDecl| {
        if (varDecl != 0) {
            printer.writer.writeSpace(" ");
            _ = try printer.emitToken(.OpenParenToken, pos, .Punctuation, nodeIndex);
            try printer.printNode(varDecl);
            _ = try printer.emitToken(.CloseParenToken, 0, .Punctuation, nodeIndex);
        }
    }
    printer.writer.writeSpace(" ");
    try printer.emitBlock(node.Block);
    try printer.exitNode(nodeIndex, state);
}
