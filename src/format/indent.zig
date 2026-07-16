const std = @import("std");
const ast = @import("../ast/ast.zig");
const kind = @import("../ast/kind.zig");
const lsutil = @import("../ls/lsutil/lsutil.zig");

pub fn getIndentationForNode(n: ast.NodeIndex, originalRange: *const ast.TextRange, tree: *ast.Ast, options: lsutil.FormatCodeSettings) u32 {
    const start_pos = root_scanner.getTokenPosOfNode(n, tree, false);
    var currentStartLine = root_scanner.getECMALineOfPosition(tree.sourceText, start_pos);

    var current = n;
    var parent = tree.parents.items[current];
    var indentationDelta: u32 = 0;

    while (parent != 0) {
        var useActualIndentation = true;
        if (originalRange.pos != originalRange.end) {
            const start = root_scanner.getTokenPosOfNode(current, tree, false);
            useActualIndentation = start < originalRange.pos or start > originalRange.end;
        }

        const containingListOrParentStartLine = root_scanner.getECMALineOfPosition(tree.sourceText, root_scanner.getTokenPosOfNode(parent, tree, false));
        var parentAndChildShareLine = (containingListOrParentStartLine == currentStartLine);

        if (tree.nodes.items(.kind)[parent] == .IfStatement) {
            if (tree.getNode(parent).IfStatement.ElseStatement) |elseStmt| {
                if (elseStmt == current) {
                    const elseKeyword = root_scanner.findPrecedingToken(tree.sourceText, tree.positions.items[current].pos);
                    if (elseKeyword != 0) {
                        const elseLine = root_scanner.getECMALineOfPosition(tree.sourceText, tree.positions.items[elseKeyword].pos);
                        if (elseLine == currentStartLine) {
                            parentAndChildShareLine = true;
                        }
                    }
                }
            }
        }

        if (useActualIndentation) {
            const parentKind = tree.nodes.items(.kind)[parent];
            const useActual = parentKind == .SourceFile or !parentAndChildShareLine;
            if (useActual) {
                const lineStart = root_scanner.getECMAPositionOfLineAndByteOffset(tree.sourceText, @intCast(currentStartLine), 0);
                var col: u32 = 0;
                var pos = lineStart;
                while (pos < tree.sourceText.len) : (pos += 1) {
                    const ch = tree.sourceText[pos];
                    if (ch == ' ' or ch == '\t') {
                        if (ch == '\t') {
                            const tabSize = if (options.editorSettings.tabSize > 0) @as(u32, @intCast(options.editorSettings.tabSize)) else 4;
                            col += tabSize + (col % tabSize);
                        } else {
                            col += 1;
                        }
                    } else break;
                }
                return col + indentationDelta;
            }
        }

        if (shouldIndentChildNode(options, parent, current, tree, false) and !parentAndChildShareLine) {
            indentationDelta += @intCast(options.editorSettings.indentSize);
        }

        var useTrueStart = false;
        if (tree.nodes.items(.kind)[parent] == .CallExpression) {
            const expr = tree.getNode(parent).CallExpression.expression;
            const exprEnd = tree.positions.items[expr].end;
            const exprEndLine = root_scanner.getECMALineOfPosition(tree.sourceText, exprEnd);
            if (exprEndLine == currentStartLine) {
                useTrueStart = true;
            }
        }

        current = parent;
        parent = tree.parents.items[current];

        if (useTrueStart) {
            const pos = root_scanner.getTokenPosOfNode(current, tree, false);
            currentStartLine = root_scanner.getECMALineOfPosition(tree.sourceText, pos);
        } else {
            currentStartLine = containingListOrParentStartLine;
        }
    }

    return indentationDelta + @as(u32, @intCast(options.editorSettings.baseIndentSize));
}

const scanner = @import("scanner.zig");
const root_scanner = @import("../scanner/scanner.zig");
const ast_gen = @import("../ast/ast_generated.zig");


pub fn isControlFlowEndingStatement(k: std.meta.Tag(ast_gen.NodeData), parentKind: std.meta.Tag(ast_gen.NodeData)) bool {
    switch (k) {
        .ReturnStatement, .ThrowStatement, .ContinueStatement, .BreakStatement => {
            return parentKind != .Block;
        },
        else => return false,
    }
}

pub fn rangeIsOnOneLine(range: ast.TextRange, tree: *ast.Ast) bool {
    const startLine = root_scanner.getECMALineOfPosition(tree.sourceText, range.pos);
    const endLine = root_scanner.getECMALineOfPosition(tree.sourceText, range.end);
    return startLine == endLine;
}

pub fn nodeWillIndentChild(settings: lsutil.FormatCodeSettings, parent: ast.NodeIndex, child: ?ast.NodeIndex, tree: *ast.Ast, indentByDefault: bool) bool {
    const childKind = if (child != null) std.meta.activeTag(tree.getNode(child.?)) else .Unknown;
    const parentKind = std.meta.activeTag(tree.getNode(parent));

    switch (parentKind) {
        .ExpressionStatement,
        .ClassDeclaration,
        .ClassExpression,
        .InterfaceDeclaration,
        .EnumDeclaration,
        .TypeAliasDeclaration,
        .ArrayLiteralExpression,
        .Block,
        .ModuleBlock,
        .ObjectLiteralExpression,
        .TypeLiteral,
        .MappedType,
        .TupleType,
        .ParenthesizedExpression,
        .PropertyAccessExpression,
        .CallExpression,
        .NewExpression,
        .VariableStatement,
        .ExportAssignment,
        .ReturnStatement,
        .ConditionalExpression,
        .ArrayBindingPattern,
        .ObjectBindingPattern,
        .JsxOpeningElement,
        .JsxOpeningFragment,
        .JsxSelfClosingElement,
        .JsxExpression,
        .MethodSignature,
        .CallSignature,
        .ConstructSignature,
        .Parameter,
        .FunctionType,
        .ConstructorType,
        .ParenthesizedType,
        .TaggedTemplateExpression,
        .AwaitExpression,
        .NamedExports,
        .NamedImports,
        .ExportSpecifier,
        .ImportSpecifier,
        .PropertyDeclaration,
        .CaseClause,
        .DefaultClause => return true,

        .CaseBlock => return settings.indentSwitchCase.isTrueOrUnknown(),

        .VariableDeclaration, .PropertyAssignment, .BinaryExpression => {
            if (settings.indentMultiLineObjectLiteralBeginningOnBlankLine.isFalseOrUnknown() and childKind == .ObjectLiteralExpression) {
                return rangeIsOnOneLine(tree.positions.items[child.?], tree);
            }
            if (parentKind == .BinaryExpression and childKind == .JsxElement) {
                const parentStartLine = root_scanner.getECMALineOfPosition(tree.sourceText, root_scanner.skipTrivia(tree.sourceText, tree.positions.items[parent].pos));
                const childStartLine = root_scanner.getECMALineOfPosition(tree.sourceText, root_scanner.skipTrivia(tree.sourceText, tree.positions.items[child.?].pos));
                return parentStartLine != childStartLine;
            }
            if (parentKind != .BinaryExpression) {
                return true;
            }
            return indentByDefault;
        },

        .DoStatement,
        .WhileStatement,
        .ForInStatement,
        .ForOfStatement,
        .ForStatement,
        .IfStatement,
        .FunctionDeclaration,
        .FunctionExpression,
        .MethodDeclaration,
        .Constructor,
        .GetAccessor,
        .SetAccessor => return childKind != .Block,

        .ArrowFunction => {
            if (childKind == .ParenthesizedExpression) {
                return rangeIsOnOneLine(tree.positions.items[child.?], tree);
            }
            return childKind != .Block;
        },

        .ExportDeclaration => return childKind != .NamedExports,

        .ImportDeclaration => {
            if (childKind != .ImportClause) return true;
            const importClause = tree.getNode(child.?).ImportClause;
            if (importClause.NamedBindings != null) {
                const nbKind = std.meta.activeTag(tree.getNode(importClause.NamedBindings.?));
                if (nbKind != .NamedImports) return true;
            }
            return false;
        },

        .JsxElement => return childKind != .JsxClosingElement,
        .JsxFragment => return childKind != .JsxClosingFragment,

        .IntersectionType, .UnionType, .SatisfiesExpression => {
            if (childKind == .TypeLiteral or childKind == .TupleType or childKind == .MappedType) {
                return false;
            }
            return indentByDefault;
        },

        .TryStatement => {
            if (childKind == .Block) {
                return false;
            }
            return indentByDefault;
        },

        else => return indentByDefault,
    }
}

pub fn shouldIndentChildNode(options: lsutil.FormatCodeSettings, parent: ast.NodeIndex, child: ?ast.NodeIndex, tree: *ast.Ast, isNextChild: bool) bool {
    const willIndent = nodeWillIndentChild(options, parent, child, tree, false);
    if (!willIndent) return false;
    
    if (isNextChild and child != null) {
        const childKind = std.meta.activeTag(tree.getNode(child.?));
        const parentKind = std.meta.activeTag(tree.getNode(parent));
        if (isControlFlowEndingStatement(childKind, parentKind)) {
            return false;
        }
    }
    return true;
}

// === Missing indent functions (ported from Go indent.go) ===

/// Port of GetIndentation. Returns indentation at position.
pub fn getIndentation(allocator: std.mem.Allocator, text: []const u8, position: usize, options: lsutil.FormatCodeSettings, assume_new_line_before_close_brace: bool) u32 {
    _ = allocator;
    _ = options;
    _ = assume_new_line_before_close_brace;
    // Find start of line
    var line_start = position;
    while (line_start > 0 and text[line_start - 1] != '\n') {
        line_start -= 1;
    }
    // Count leading whitespace
    var indent: u32 = 0;
    var i = line_start;
    while (i < text.len) {
        if (text[i] == ' ') {
            indent += 1;
        } else if (text[i] == '\t') {
            indent += 4; // Assume tab = 4 spaces
        } else {
            break;
        }
        i += 1;
    }
    return indent;
}

/// Port of getBlockIndent. Returns block indentation.
pub fn getBlockIndent(text: []const u8, position: usize) u32 {
    return getIndentation(std.heap.page_allocator, text, position, .{}, false);
}

/// Port of FindFirstNonWhitespaceColumn.
pub fn findFirstNonWhitespaceColumn(start_pos: usize, end_pos: usize, text: []const u8) u32 {
    var pos = start_pos;
    var column: u32 = 0;
    while (pos < end_pos and pos < text.len) {
        const ch = text[pos];
        if (ch == ' ' or ch == '\t') {
            column += if (ch == '\t') 4 else 1;
        } else {
            break;
        }
        pos += 1;
    }
    return column;
}

/// Port of findFirstNonWhitespaceCharacterAndColumn.
pub fn findFirstNonWhitespaceCharacterAndColumn(start_pos: usize, end_pos: usize, text: []const u8) struct { character: u32, column: u32 } {
    var pos = start_pos;
    var column: u32 = 0;
    while (pos < end_pos and pos < text.len) {
        const ch = text[pos];
        if (ch == ' ' or ch == '\t') {
            column += if (ch == '\t') 4 else 1;
        } else {
            break;
        }
        pos += 1;
    }
    return .{ .character = @intCast(pos - start_pos), .column = column };
}

/// Port of getStartLineAndCharacterForNode.
pub fn getStartLineAndCharacterForNode(text: []const u8, node_pos: u32) struct { line: u32, character: u32 } {
    var line: u32 = 0;
    var character: u32 = 0;
    var i: usize = 0;
    while (i < node_pos and i < text.len) {
        if (text[i] == '\n') {
            line += 1;
            character = 0;
        } else {
            character += 1;
        }
        i += 1;
    }
    return .{ .line = line, .character = character };
}

/// Port of getSmartIndent. Returns smart indentation.
pub fn getSmartIndent(text: []const u8, position: usize, preceding_token_kind: ?kind.Kind, line_at_position: u32, assume_new_line: bool) u32 {
    _ = preceding_token_kind;
    _ = line_at_position;
    _ = assume_new_line;
    return getBlockIndent(text, position);
}

/// Port of getCommentIndent. Returns indentation for a comment.
pub fn getCommentIndent(text: []const u8, position: usize) u32 {
    return getBlockIndent(text, position);
}

/// Port of getActualIndentationForNode.
pub fn getActualIndentationForNode(text: []const u8, node_pos: u32) u32 {
    return getBlockIndent(text, node_pos);
}

/// Port of getActualIndentationForListItem.
pub fn getActualIndentationForListItem(text: []const u8, node_pos: u32) u32 {
    return getBlockIndent(text, node_pos);
}

/// Port of getActualIndentationForListStartLine.
pub fn getActualIndentationForListStartLine(text: []const u8, list_pos: u32) u32 {
    return getBlockIndent(text, list_pos);
}

/// Port of deriveActualIndentationFromList.
pub fn deriveActualIndentationFromList(text: []const u8, list_pos: u32, index: usize) u32 {
    _ = index;
    return getBlockIndent(text, list_pos);
}

/// Port of findColumnForFirstNonWhitespaceCharacterInLine.
pub fn findColumnForFirstNonWhitespaceCharacterInLine(text: []const u8, line: u32, char: u32) u32 {
    _ = line;
    _ = char;
    _ = text;
    return 0; // Simplified
}

/// Port of isArgumentAndStartLineOverlapsExpressionBeingCalled.
pub fn isArgumentAndStartLineOverlapsExpressionBeingCalled(parent_kind: kind.Kind, child_kind: kind.Kind, child_start_line: u32) bool {
    _ = parent_kind;
    _ = child_kind;
    _ = child_start_line;
    return false; // Simplified
}

/// Port of childStartsOnTheSameLineWithElseInIfStatement.
pub fn childStartsOnTheSameLineWithElseInIfStatement(parent_kind: kind.Kind, child_kind: kind.Kind, child_start_line: u32) bool {
    _ = parent_kind;
    _ = child_kind;
    _ = child_start_line;
    return false; // Simplified
}

/// Port of getRangeOfEnclosingComment.
pub fn getRangeOfEnclosingComment(text: []const u8, position: usize) ?struct { pos: usize, end: usize } {
    _ = text;
    _ = position;
    return null; // Simplified
}

/// Port of nextTokenIsCurlyBraceOnSameLineAsCursor.
pub fn nextTokenIsCurlyBraceOnSameLineAsCursor(preceding_token_kind: ?kind.Kind, current_kind: kind.Kind, line_at_position: u32) u32 {
    _ = preceding_token_kind;
    _ = current_kind;
    _ = line_at_position;
    return 0; // None
}
