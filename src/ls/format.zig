const std = @import("std");
const ast = @import("../ast/ast.zig");
const astnav = @import("../astnav/tokens.zig");
const compiler = @import("../compiler/program.zig");
const core = @import("../core/core.zig");
const format = @import("../format/api.zig");
const format_context = @import("../format/context.zig");
const lsutil = @import("lsutil/lsutil.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const scanner = @import("../scanner/scanner.zig");
const textchange = @import("../core/textchange.zig");
const ls = @import("languageservice.zig");

fn toLSProtoTextEdits(allocator: std.mem.Allocator, l_srv: *ls.LanguageService, file: compiler.FileId, changes: []const textchange.TextChange) ![]lsproto.TextEdit {
    var result = try std.ArrayList(lsproto.TextEdit).initCapacity(allocator, changes.len);
    for (changes) |c| {
        result.appendAssumeCapacity(.{
            .newText = try allocator.dupe(u8, c.newText),
            .range = l_srv.converters.*.createLspRangeFromBounds(file, c.span.start, c.span.end()),
        });
    }
    return result.toOwnedSlice();
}

pub fn provideFormatDocument(
    l_srv: *ls.LanguageService,
    allocator: std.mem.Allocator,
    documentURI: lsproto.DocumentUri,
    options: *const lsproto.FormattingOptions,
) !lsproto.TextEditsOrNull {
    if (l_srv.userPreferences().enableFormatting.isFalse()) {
        return .{ .TextEdits = null };
    }
    const res = l_srv.getProgramAndFile(documentURI);
    const formatOpts = lsutil.fromLSFormatOptions(l_srv.formatOptions(), options);

    const changes = try getFormattingEditsForDocument(allocator, l_srv, res.file, formatOpts);
    defer {
        for (changes) |c| allocator.free(c.newText);
        allocator.free(changes);
    }
    const edits = try toLSProtoTextEdits(allocator, l_srv, res.file, changes);
    return .{ .TextEdits = edits };
}

pub fn provideFormatDocumentRange(
    l_srv: *ls.LanguageService,
    allocator: std.mem.Allocator,
    documentURI: lsproto.DocumentUri,
    options: *const lsproto.FormattingOptions,
    r: lsproto.Range,
) !lsproto.TextEditsOrNull {
    if (l_srv.userPreferences().enableFormatting.isFalse()) {
        return .{ .TextEdits = null };
    }
    const res = l_srv.getProgramAndFile(documentURI);
    const formatOpts = lsutil.fromLSFormatOptions(l_srv.formatOptions(), options);
    const tr = l_srv.converters.*.fromLSPRange(res.file, r);
    const changes = try getFormattingEditsForRange(allocator, l_srv, res.file, formatOpts, tr);
    defer {
        for (changes) |c| allocator.free(c.newText);
        allocator.free(changes);
    }
    const edits = try toLSProtoTextEdits(allocator, l_srv, res.file, changes);
    return .{ .TextEdits = edits };
}

pub fn provideFormatDocumentOnType(
    l_srv: *ls.LanguageService,
    allocator: std.mem.Allocator,
    documentURI: lsproto.DocumentUri,
    options: *const lsproto.FormattingOptions,
    position: lsproto.Position,
    character: []const u8,
) !lsproto.TextEditsOrNull {
    if (l_srv.userPreferences().enableFormatting.isFalse()) {
        return .{ .TextEdits = null };
    }
    const res = l_srv.getProgramAndFile(documentURI);
    const formatOpts = lsutil.fromLSFormatOptions(l_srv.formatOptions(), options);
    const pos = l_srv.converters.*.lineAndCharacterToPosition(res.file, position);
    const changes = try getFormattingEditsAfterKeystroke(allocator, l_srv, res.file, formatOpts, pos, character);
    defer {
        for (changes) |c| allocator.free(c.newText);
        allocator.free(changes);
    }
    const edits = try toLSProtoTextEdits(allocator, l_srv, res.file, changes);
    return .{ .TextEdits = edits };
}

fn getFormattingEditsForRange(
    allocator: std.mem.Allocator,
    l_srv: *ls.LanguageService,
    file: compiler.FileId,
    options: lsutil.FormatCodeSettings,
    r: core.TextRange,
) ![]textchange.TextChange {
    const ctx = format_context.FormatContext.init(options, options.newLineCharacter orelse "\n");
    const a = l_srv.getAst(file);
    return format.formatSelection(allocator, &ctx, a, r.start, r.end());
}

fn getFormattingEditsForDocument(
    allocator: std.mem.Allocator,
    l_srv: *ls.LanguageService,
    file: compiler.FileId,
    options: lsutil.FormatCodeSettings,
) ![]textchange.TextChange {
    const ctx = format_context.FormatContext.init(options, options.newLineCharacter orelse "\n");
    const a = l_srv.getAst(file);
    return format.formatDocument(allocator, &ctx, a);
}

fn getFormattingEditsAfterKeystroke(
    allocator: std.mem.Allocator,
    l_srv: *ls.LanguageService,
    file: compiler.FileId,
    options: lsutil.FormatCodeSettings,
    position: u32,
    key: []const u8,
) ![]textchange.TextChange {
    const ctx = format_context.FormatContext.init(options, options.newLineCharacter orelse "\n");
    const a = l_srv.getAst(file);
    const source_file = l_srv.getSourceFileNode(file);
    const tokenAtPosition = astnav.getTokenAtPosition(source_file, a, position);
    
    // In go: if isInComment(file, position, tokenAtPosition) == nil {
    // We don't have isInComment yet, let's implement the rest
    if (getRangeOfEnclosingComment(l_srv, file, position, 0, tokenAtPosition) == null) {
        if (std.mem.eql(u8, key, "{")) {
            return format.formatOnOpeningCurly(allocator, &ctx, a, position);
        } else if (std.mem.eql(u8, key, "}")) {
            return format.formatOnClosingCurly(allocator, &ctx, a, position);
        } else if (std.mem.eql(u8, key, ";")) {
            return format.formatOnSemicolon(allocator, &ctx, a, position);
        } else if (std.mem.eql(u8, key, "\n")) {
            return format.formatOnEnter(allocator, &ctx, a, position);
        }
    }
    return &[_]textchange.TextChange{};
}

pub fn getRangeOfEnclosingComment(
    l_srv: *ls.LanguageService,
    file: compiler.FileId,
    position: u32,
    precedingToken: ast.NodeIndex,
    tokenAtPos: ast.NodeIndex,
) ?ast.CommentRange {
    _ = precedingToken;
    const a = l_srv.getAst(file);
    var tokenAtPosition = tokenAtPos;
    
    // jsdoc = ast.FindAncestor(tokenAtPosition, IsJSDoc)
    var curr = tokenAtPosition;
    var jsdoc: ast.NodeIndex = 0;
    while (curr != 0) {
        const k = std.meta.activeTag(a.getNode(curr));
        if (k == .JSDoc or k == .JSDocComment) {
            jsdoc = curr;
            break;
        }
        curr = a.getNodeParent(curr);
    }
    if (jsdoc != 0) {
        tokenAtPosition = a.getNodeParent(jsdoc);
    }
    
    const tokenStart = astnav.getStartOfNode(tokenAtPosition, a, l_srv.getSourceFileNode(file), false);
    if (tokenStart <= position and position < a.getNodeEnd(tokenAtPosition)) {
        return null;
    }
    
    // TODO: implement comment range logic like in TS
    return null;
}
