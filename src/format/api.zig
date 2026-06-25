const std = @import("std");
const ast = @import("../ast/ast.zig");
const core = @import("../core/core.zig");
const textchange = @import("../core/textchange.zig");
const lsutil = @import("../ls/lsutil/lsutil.zig");
const scanner = @import("../scanner/scanner.zig");
const stringutil = @import("../stringutil/stringutil.zig");

const span = @import("span.zig");
const format_scanner = @import("scanner.zig");
const indent = @import("indent.zig");

pub const FormatRequestKind = enum {
    FormatDocument,
    FormatSelection,
    FormatOnEnter,
    FormatOnSemicolon,
    FormatOnOpeningCurlyBrace,
    FormatOnClosingCurlyBrace,
};

pub const FormatContext = struct {
    options: lsutil.FormatCodeSettings,
    newLine: []const u8,

    pub fn init(options: lsutil.FormatCodeSettings, newLine: []const u8) FormatContext {
        return FormatContext{
            .options = options,
            .newLine = newLine,
        };
    }

    pub fn getFormatCodeSettings(self: *const FormatContext) lsutil.FormatCodeSettings {
        return self.options;
    }

    pub fn getNewLineOrDefault(self: *const FormatContext) []const u8 {
        if (self.options.editorSettings.newLineCharacter.len > 0) {
            return self.options.editorSettings.newLineCharacter;
        }
        if (self.newLine.len > 0) {
            return self.newLine;
        }
        return "\n";
    }
};

// Implementations of FormatSpan, FormatDocument, etc will be written here, 
// but since they depend on span.zig and other files, they are stubs for now to get the structure right.

pub fn formatSpan(allocator: std.mem.Allocator, ctx: *const FormatContext, spanRange: ast.TextRange, tree: *ast.Ast, kind: FormatRequestKind) ![]textchange.TextChange {
    const enclosingNode = span.findEnclosingNode(spanRange, tree);
    const opts = ctx.getFormatCodeSettings();

    var worker = span.FormatSpanWorker{
        .originalRange = spanRange,
        .enclosingNode = enclosingNode,
        .initialIndentation = @intCast(indent.getIndentationForNode(enclosingNode, &spanRange, tree, opts)),
        .delta = @intCast(span.getOwnOrInheritedDelta(enclosingNode, opts, tree)),
        .requestKind = kind,
        .tree = tree,
        .ctx = ctx,
        .edits = .empty,
    };

    const startPos = span.getScanStartPosition(enclosingNode, spanRange, tree);
    return format_scanner.FormattingScanner.init(allocator, tree.sourceText, core.LanguageVariant.Standard, startPos, spanRange.end, &worker);
}

pub fn formatNodeGivenIndentation(allocator: std.mem.Allocator, ctx: *const FormatContext, node: ast.NodeIndex, tree: *ast.Ast, languageVariant: core.LanguageVariant, initialIndentation: i32, delta: i32) ![]textchange.TextChange {
    const textRange = ast.TextRange{ .pos = tree.positions.items[node].pos, .end = tree.positions.items[node].end };
    var worker = span.FormatSpanWorker{
        .originalRange = textRange,
        .enclosingNode = node,
        .initialIndentation = initialIndentation,
        .delta = delta,
        .requestKind = .FormatSelection,
        .sourceFile = tree,
        .ctx = ctx,
        .edits = std.ArrayList(textchange.TextChange).init(allocator),
    };
    var scannerInstance = format_scanner.FormattingScanner.init(allocator, tree.sourceText, languageVariant, textRange.pos, textRange.end);
    defer scannerInstance.deinit();
    return try worker.execute(&scannerInstance);
}

pub fn formatNodeLines(allocator: std.mem.Allocator, ctx: *const FormatContext, tree: *ast.Ast, node: ast.NodeIndex, requestKind: FormatRequestKind) ![]textchange.TextChange {
    if (node == 0) return &[_]textchange.TextChange{};
    const tokenStart = scanner.getTokenPosOfNode(node, tree, false);
    const lineStart = span.getLineStartPositionForPosition(tokenStart, tree);
    const textRange = ast.TextRange{ .pos = lineStart, .end = tree.positions.items[node].end };
    return formatSpan(allocator, ctx, textRange, tree, requestKind);
}

pub fn formatDocument(allocator: std.mem.Allocator, ctx: *const FormatContext, tree: *ast.Ast) ![]textchange.TextChange {
    if (tree.positions.items.len == 0) return &[_]textchange.TextChange{};
    return formatSpan(allocator, ctx, .{ .pos = 0, .end = @intCast(tree.sourceText.len) }, tree, .FormatDocument);
}

pub fn formatSelection(allocator: std.mem.Allocator, ctx: *const FormatContext, tree: *ast.Ast, start: u32, end: u32) ![]textchange.TextChange {
    return formatSpan(allocator, ctx, .{ .pos = span.getLineStartPositionForPosition(start, tree), .end = end }, tree, .FormatSelection);
}

pub fn formatOnOpeningCurly(allocator: std.mem.Allocator, ctx: *const FormatContext, tree: *ast.Ast, position: u32) ![]textchange.TextChange {
    const openingCurly = span.findImmediatelyPrecedingTokenOfKind(position, .OpenBraceToken, tree);
    if (openingCurly == 0) return &[_]textchange.TextChange{};
    const outermostNode = span.findOutermostNodeWithinListLevel(tree.parents.items[openingCurly], tree);
    const textRange = ast.TextRange{
        .pos = span.getLineStartPositionForPosition(scanner.getTokenPosOfNode(outermostNode, tree, false), tree),
        .end = position,
    };
    return formatSpan(allocator, ctx, textRange, tree, .FormatOnOpeningCurlyBrace);
}

pub fn formatOnClosingCurly(allocator: std.mem.Allocator, ctx: *const FormatContext, tree: *ast.Ast, position: u32) ![]textchange.TextChange {
    const precedingToken = span.findImmediatelyPrecedingTokenOfKind(position, .CloseBraceToken, tree);
    return formatNodeLines(allocator, ctx, tree, span.findOutermostNodeWithinListLevel(precedingToken, tree), .FormatOnClosingCurlyBrace);
}

pub fn formatOnSemicolon(allocator: std.mem.Allocator, ctx: *const FormatContext, tree: *ast.Ast, position: u32) ![]textchange.TextChange {
    const precedingToken = span.findImmediatelyPrecedingTokenOfKind(position, .SemicolonToken, tree);
    return formatNodeLines(allocator, ctx, tree, span.findOutermostNodeWithinListLevel(precedingToken, tree), .FormatOnSemicolon);
}

pub fn formatOnEnter(allocator: std.mem.Allocator, ctx: *const FormatContext, tree: *ast.Ast, position: u32) ![]textchange.TextChange {
    const line = scanner.getECMALineOfPosition(tree.sourceText, position);
    if (line == 0) return &[_]textchange.TextChange{};
    
    const ecmaStarts = scanner.getECMALineStarts(tree.sourceText, allocator) catch return &[_]textchange.TextChange{};
    defer allocator.free(ecmaStarts);
    const startPos = ecmaStarts[line - 1];
    
    var endOfFormatSpan = scanner.getECMAEndLinePosition(tree.sourceText, line);
    while (endOfFormatSpan > startPos) {
        var ch: u21 = 0;
        var s: usize = 0;
        if (endOfFormatSpan > 0) {
            const temp = endOfFormatSpan - 1;
            // backwards decoding is hard, let's just use stringutil logic simply
            ch = tree.sourceText[temp];
            s = 1;
            // if multi-byte, skip... (simplified for now)
        }
        if (s == 0 or stringutil.isWhiteSpaceSingleLine(ch)) {
            endOfFormatSpan -= 1;
            continue;
        }
        break;
    }
    
    if (endOfFormatSpan > 0) {
        const ch = tree.sourceText[endOfFormatSpan - 1];
        if (stringutil.isLineBreak(ch)) {
            endOfFormatSpan -= 1;
        }
    }
    
    const textRange = ast.TextRange{ .pos = @intCast(startPos), .end = @intCast(endOfFormatSpan + 1) };
    return formatSpan(allocator, ctx, textRange, tree, .FormatOnEnter);
}

test "formatDocument parses and initializes scanner" {
    const testing = std.testing;
    const allocator = testing.allocator;


    var tree = ast.Ast.init(allocator);
    defer tree.deinit();

    // Stub out positions to simulate an AST
    try tree.positions.append(allocator, .{ .pos = 0, .end = 0 }); // index 0
    try tree.positions.append(allocator, .{ .pos = 0, .end = 10 }); // index 1 (SourceFile)
    
    // Simulate source text
    tree.sourceText = "const a = 1;";
    
    // Since we need node.data to not panic in getScanStartPosition, let's append one
    try tree.nodes.append(allocator, .{ .SourceFile = undefined });
    try tree.nodes.append(allocator, .{ .SourceFile = undefined }); // for index 1
    
    // Mock parents
    try tree.parents.append(allocator, 0); // index 0 parent is 0
    try tree.parents.append(allocator, 0); // index 1 parent is 0

    const settings = lsutil.getDefaultFormatCodeSettings();
    const ctx = FormatContext.init(settings, "\n");
    
    const edits = try formatDocument(allocator, &ctx, &tree);
    defer allocator.free(edits);

    try testing.expect(edits.len == 0);
}
