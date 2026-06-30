const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const kind = @import("../ast/kind.zig");
const scanner_pkg = @import("../scanner/scanner.zig");
const core = @import("../core/core.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const Parser = @import("parser.zig").Parser;
const ParsingContext = @import("parser.zig").ParsingContext;

const NodeIndex = ast_gen.NodeIndex;

pub const jsdocState = enum(i32) {
    BeginningOfLine = 0,
    SawAsterisk,
    SavingComments,
    SavingBackticks,
};

pub const propertyLikeParse = enum(i32) {
    Property = 1 << 0,
    Parameter = 1 << 1,
    CallbackParameter = 1 << 2,
};

pub fn isJSDocLikeText(text: []const u8) bool {
    return text.len >= 4 and text[0] == '/' and text[1] == '*' and text[2] == '*' and text[3] != '/';
}

fn removeLeadingNewlines(comments: []const []const u8) []const []const u8 {
    var i: usize = 0;
    while (i < comments.len) : (i += 1) {
        var all_nl = true;
        for (comments[i]) |c| {
            if (c != '\r' and c != '\n') {
                all_nl = false;
                break;
            }
        }
        if (!all_nl) break;
    }
    return comments[i..];
}

fn trimEnd(s: []const u8) []const u8 {
    var end: usize = s.len;
    while (end > 0) : (end -= 1) {
        const c = s[end - 1];
        if (c != ' ' and c != '\t' and c != '\r' and c != '\n' and c != '\x0B' and c != '\x0C') {
            break;
        }
    }
    return s[0..end];
}

fn removeTrailingWhitespace(allocator: std.mem.Allocator, comments: []const []const u8) []const []const u8 {
    var end = comments.len;
    if (end == 0) return comments;
    const mutable_comments = allocator.alloc([]const u8, comments.len) catch unreachable;
    @memcpy(mutable_comments, comments);
    var i = comments.len;
    while (i > 0) {
        i -= 1;
        const trimmed = trimEnd(mutable_comments[i]);
        if (trimmed.len == 0) {
            end = i;
        } else {
            mutable_comments[i] = trimmed;
            break;
        }
    }
    return mutable_comments[0..end];
}

pub fn finishNode(p: *Parser, node: NodeIndex, start: usize) NodeIndex {
    if (node < p.ast.positions.items.len) {
        p.ast.positions.items[node] = .{ .pos = @intCast(start), .end = @intCast(p.scanner.getTokenEnd()) };
    }
    return node;
}

pub fn finishNodeWithEnd(p: *Parser, node: NodeIndex, start: usize, end: usize) NodeIndex {
    if (node < p.ast.positions.items.len) {
        p.ast.positions.items[node] = .{ .pos = @intCast(start), .end = @intCast(end) };
    }
    return node;
}

pub fn isNextNonwhitespaceTokenEndOfFile(p: *Parser) bool {
    _ = p.nextTokenJSDoc();
    while (p.token == kind.Kind.WhitespaceTrivia or p.token == kind.Kind.NewLineTrivia) {
        _ = p.nextTokenJSDoc();
    }
    return p.token == kind.Kind.EndOfFile;
}

pub fn skipWhitespace(p: *Parser) void {
    if (p.token == kind.Kind.WhitespaceTrivia or p.token == kind.Kind.NewLineTrivia) {
        if (p.lookAhead(struct {
            fn run(parser: *Parser) bool {
                return isNextNonwhitespaceTokenEndOfFile(parser);
            }
        }.run)) {
            return;
        }
    }
    while (p.token == kind.Kind.WhitespaceTrivia or p.token == kind.Kind.NewLineTrivia) {
        _ = p.nextTokenJSDoc();
    }
}

pub fn skipWhitespaceOrAsterisk(p: *Parser) []const u8 {
    if (p.token == kind.Kind.WhitespaceTrivia or p.token == kind.Kind.NewLineTrivia) {
        if (p.lookAhead(struct {
            fn run(parser: *Parser) bool {
                return isNextNonwhitespaceTokenEndOfFile(parser);
            }
        }.run)) {
            return "";
        }
    }

    var precedingLineBreak = p.scanner.hasPrecedingLineBreak();
    var seenLineBreak = false;
    var indents = std.ArrayList([]const u8).empty;
    defer indents.deinit(p.allocator);

    while ((precedingLineBreak and p.token == kind.Kind.AsteriskToken) or p.token == kind.Kind.WhitespaceTrivia or p.token == kind.Kind.NewLineTrivia) {
        indents.append(p.allocator, p.scanner.getTokenValue()) catch unreachable;
        if (p.token == kind.Kind.NewLineTrivia) {
            precedingLineBreak = true;
            seenLineBreak = true;
            indents.clearRetainingCapacity();
        } else if (p.token == kind.Kind.AsteriskToken) {
            precedingLineBreak = false;
        }
        _ = p.nextTokenJSDoc();
    }

    if (seenLineBreak) {
        return std.mem.concat(p.allocator, u8, indents.items) catch unreachable;
    } else {
        return "";
    }
}

pub fn parseJSDocTypeExpression(p: *Parser, mayOmitBraces: bool) anyerror!NodeIndex {
    const pos = p.scanner.getTokenFullStart();
    var hasBrace = false;
    if (mayOmitBraces) {
        hasBrace = p.parseOptional(kind.Kind.OpenBraceToken);
    } else {
        hasBrace = p.parseExpected(kind.Kind.OpenBraceToken);
    }
    const saveContextFlags = p.contextFlags;
    p.setContextFlags(@import("../ast/ast_utils.zig").NodeFlags.JSDoc, true);
    const t = try parseJSDocType(p);
    p.contextFlags = saveContextFlags;
    if (hasBrace) {
        _ = p.parseExpected(kind.Kind.CloseBraceToken);
    }

    const exprNode = try p.ast.pushNode(.{ .JSDocTypeExpression = .{
        .Flags = 0,
        .Type = t,
    } });
    return finishNode(p, exprNode, pos);
}

pub fn parseJSDocNameReference(p: *Parser) anyerror!NodeIndex {
    const pos = p.scanner.getTokenFullStart();
    const hasBrace = p.parseOptional(kind.Kind.OpenBraceToken);
    const entityName = try parseJSDocLinkName(p);
    if (hasBrace) {
        _ = p.parseExpected(kind.Kind.CloseBraceToken);
    }
    p.scanner.resetPos(p.scanner.getTokenFullStart());
    _ = p.nextTokenJSDoc();
    const nameRef = try p.ast.pushNode(.{ .JSDocNameReference = .{
        .Flags = 0,
        .name = entityName orelse 0,
    } });
    return finishNode(p, nameRef, pos);
}

pub fn parseJSDocComment(p: *Parser, parent: NodeIndex, start: usize, end_val: isize, fullStart: usize) anyerror!?NodeIndex {
    _ = parent;
    const end = if (end_val == -1) p.sourceText.len else @as(usize, @intCast(end_val));
    if (!isJSDocLikeText(p.sourceText[start..])) {
        return null;
    }

    const saveSourceText = p.sourceText;
    const saveToken = p.token;
    const saveContextFlags = p.contextFlags;
    const saveParsingContexts = p.parsingContexts;
    const saveScannerState = p.scanner.mark();
    const saveDiagnosticsCount = p.parseDiagnosticsCount;

    const last_lf = std.mem.lastIndexOfScalar(u8, p.sourceText[0..start], '\n');
    const lf_pos = if (last_lf) |idx| idx + 1 else 0;
    const initialIndent = start + 4 - lf_pos;

    p.sourceText = p.sourceText[0 .. end - 2];
    p.scanner.text = p.sourceText;
    p.scanner.end = p.sourceText.len;
    p.scanner.resetPos(start + 3);
    p.setContextFlags(@import("../ast/ast_utils.zig").NodeFlags.JSDoc, true);
    p.parsingContexts |= (@as(u32, 1) << @intFromEnum(ParsingContext.JSDocComment));

    const comment = try parseJSDocCommentWorker(p, start, end, fullStart, initialIndent);

    p.parseDiagnosticsCount = saveDiagnosticsCount;
    p.sourceText = saveSourceText;
    p.scanner.text = p.sourceText;
    p.scanner.end = p.sourceText.len;
    p.parsingContexts = saveParsingContexts;
    p.contextFlags = saveContextFlags;
    p.scanner.rewind(saveScannerState);
    p.token = saveToken;

    return comment;
}

pub fn parseJSDocCommentWorker(p: *Parser, start: usize, end: usize, fullStart: usize, indent: usize) anyerror!NodeIndex {
    var tags = std.ArrayList(NodeIndex).empty;
    defer tags.deinit(p.allocator);
    var tagsPos: isize = -1;
    var tagsEnd: isize = -1;
    var state = jsdocState.SawAsterisk;
    var backtickCount: usize = 0;
    var inFencedCodeBlock = false;
    var commentParts = std.ArrayList(NodeIndex).empty;
    defer commentParts.deinit(p.allocator);

    var comments = std.ArrayList([]const u8).empty;
    defer comments.deinit(p.allocator);
    var commentsPos: isize = -1;
    var linkEnd: usize = start;
    var margin: isize = -1;
    var curr_indent = indent;

    const pushComment = struct {
        fn run(allocator: std.mem.Allocator, coms: *std.ArrayList([]const u8), m: *isize, ind: *usize, text: []const u8) void {
            if (m.* == -1) {
                m.* = @as(isize, @intCast(ind.*));
            }
            coms.append(allocator, text) catch unreachable;
            ind.* += text.len;
        }
    }.run;

    _ = p.nextTokenJSDoc();
    while (parseOptionalJsdoc(p, kind.Kind.WhitespaceTrivia)) {}
    if (parseOptionalJsdoc(p, kind.Kind.NewLineTrivia)) {
        state = .BeginningOfLine;
        curr_indent = 0;
    }

    while (true) {
        if (p.token != kind.Kind.BacktickToken and backtickCount > 0) {
            if (backtickCount >= 3) {
                inFencedCodeBlock = !inFencedCodeBlock;
            }
            backtickCount = 0;
        }
        switch (p.token) {
            kind.Kind.AtToken => {
                if (inFencedCodeBlock or !p.scanner.canFollowJSDocAt()) {
                    if (inFencedCodeBlock) {
                        state = .SavingBackticks;
                    } else {
                        state = .SavingComments;
                    }
                    pushComment(p.allocator, &comments, &margin, &curr_indent, p.scanner.getTokenValue());
                } else {
                    const trimmed_comments = removeTrailingWhitespace(p.allocator, comments.items);
                    comments.clearRetainingCapacity();
                    comments.appendSlice(p.allocator, trimmed_comments) catch unreachable;
                    if (commentsPos == -1) {
                        commentsPos = @as(isize, @intCast(p.scanner.getTokenFullStart()));
                    }
                    const tag = try parseTag(p, tags.items, @as(isize, @intCast(curr_indent)));
                    if (tagsPos == -1) {
                        tagsPos = @as(isize, @intCast(p.scanner.getTokenStart()));
                    }
                    try tags.append(p.allocator, tag);
                    tagsEnd = @as(isize, @intCast(p.scanner.getTokenEnd()));
                    state = .BeginningOfLine;
                    margin = -1;
                }
            },
            kind.Kind.NewLineTrivia => {
                try comments.append(p.allocator, p.scanner.getTokenValue());
                state = .BeginningOfLine;
                curr_indent = 0;
            },
            kind.Kind.AsteriskToken => {
                const asterisk = p.scanner.getTokenValue();
                if (state == .SawAsterisk) {
                    state = .SavingComments;
                    pushComment(p.allocator, &comments, &margin, &curr_indent, asterisk);
                } else {
                    state = .SawAsterisk;
                    curr_indent += asterisk.len;
                }
            },
            kind.Kind.WhitespaceTrivia => {
                const whitespace = p.scanner.getTokenValue();
                if (margin > -1 and @as(isize, @intCast(curr_indent + whitespace.len)) > margin) {
                    var existingIndent = margin - @as(isize, @intCast(curr_indent));
                    if (existingIndent < 0) {
                        existingIndent += @as(isize, @intCast(whitespace.len));
                    }
                    if (existingIndent < 0) {
                        existingIndent = 0;
                    }
                    try comments.append(p.allocator, whitespace[@as(usize, @intCast(existingIndent))..]);
                }
                curr_indent += whitespace.len;
            },
            kind.Kind.EndOfFile => {
                break;
            },
            kind.Kind.JSDocCommentTextToken => {
                if (state != .SavingBackticks) {
                    if (inFencedCodeBlock) {
                        state = .SavingBackticks;
                    } else {
                        state = .SavingComments;
                    }
                }
                pushComment(p.allocator, &comments, &margin, &curr_indent, p.scanner.getTokenValue());
            },
            kind.Kind.BacktickToken => {
                backtickCount += 1;
                if (state == .SavingBackticks) {
                    state = .SavingComments;
                } else {
                    state = .SavingBackticks;
                }
                pushComment(p.allocator, &comments, &margin, &curr_indent, p.scanner.getTokenValue());
            },
            kind.Kind.OpenBraceToken => {
                if (inFencedCodeBlock) {
                    state = .SavingBackticks;
                    pushComment(p.allocator, &comments, &margin, &curr_indent, p.scanner.getTokenValue());
                } else {
                    state = .SavingComments;
                    const commentEnd = p.scanner.getTokenFullStart();
                    const linkStart = p.scanner.getTokenEnd() - 1;
                    const link = try parseJSDocLink(p, linkStart);
                    if (link != 0) {
                        if (linkEnd == start) {
                            const trimmed = removeLeadingNewlines(comments.items);
                            comments.clearRetainingCapacity();
                            try comments.appendSlice(p.allocator, trimmed);
                        }
                        const text = try std.mem.concat(p.allocator, u8, comments.items);
                        const jsdocText = try p.ast.pushNode(.{ .JSDocText = .{
                            .Flags = 0,
                            .text = text,
                        } });
                        _ = finishNodeWithEnd(p, jsdocText, linkEnd, commentEnd);
                        try commentParts.append(p.allocator, jsdocText);
                        try commentParts.append(p.allocator, link);
                        comments.clearRetainingCapacity();
                        linkEnd = p.scanner.getTokenEnd();
                    } else {
                        pushComment(p.allocator, &comments, &margin, &curr_indent, p.scanner.getTokenValue());
                    }
                }
            },
            else => {
                if (state != .SavingBackticks) {
                    if (inFencedCodeBlock) {
                        state = .SavingBackticks;
                    } else {
                        state = .SavingComments;
                    }
                }
                pushComment(p.allocator, &comments, &margin, &curr_indent, p.scanner.getTokenValue());
            },
        }
        if (state == .SavingComments or state == .SavingBackticks) {
            _ = p.nextJSDocCommentTextToken(state == .SavingBackticks);
        } else {
            _ = p.nextTokenJSDoc();
        }
    }

    if (commentsPos == -1) {
        commentsPos = @as(isize, @intCast(p.scanner.getTokenFullStart()));
    }
    if (comments.items.len > 0) {
        const text = try std.mem.concat(p.allocator, u8, comments.items);
        const jsdocText = try p.ast.pushNode(.{ .JSDocText = .{
            .Flags = 0,
            .text = text,
        } });
        _ = finishNodeWithEnd(p, jsdocText, linkEnd, @as(usize, @intCast(commentsPos)));
        try commentParts.append(p.allocator, jsdocText);
    }

    const commentList = try p.ast.pushNodeList(commentParts.items);
    const tagsList = if (tags.items.len > 0) try p.ast.pushNodeList(tags.items) else null;

    const jsdocComment = try p.ast.pushNode(.{ .JSDoc = .{
        .Flags = 0,
        .Comment = commentList,
        .Tags = tagsList,
    } });
    return finishNodeWithEnd(p, jsdocComment, fullStart, end);
}

pub fn parseTag(p: *Parser, previousTags: []const NodeIndex, margin: isize) anyerror!NodeIndex {
    if (p.token != kind.Kind.AtToken) {
        @panic("should be called only at the start of a tag");
    }
    const start = p.scanner.getTokenStart();
    _ = p.nextTokenJSDoc();

    const tagName = try parseJSDocIdentifierName(p, null);
    const indentText = skipWhitespaceOrAsterisk(p);

    var tag: NodeIndex = 0;
    const tagNameText = p.ast.getNode(tagName).Identifier.Text;

    if (std.mem.eql(u8, tagNameText, "implements")) {
        tag = try parseImplementsTag(p, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "augments") or std.mem.eql(u8, tagNameText, "extends")) {
        tag = try parseAugmentsTag(p, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "public")) {
        tag = try parseSimplePublicTag(p, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "private")) {
        tag = try parseSimplePrivateTag(p, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "protected")) {
        tag = try parseSimpleProtectedTag(p, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "readonly")) {
        tag = try parseSimpleReadonlyTag(p, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "override")) {
        tag = try parseSimpleOverrideTag(p, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "deprecated")) {
        p.hasDeprecatedTag = true;
        tag = try parseSimpleDeprecatedTag(p, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "this")) {
        tag = try parseThisTag(p, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "arg") or std.mem.eql(u8, tagNameText, "argument") or std.mem.eql(u8, tagNameText, "param")) {
        tag = try parseParameterOrPropertyTag(p, start, tagName, .Parameter, margin);
    } else if (std.mem.eql(u8, tagNameText, "return") or std.mem.eql(u8, tagNameText, "returns")) {
        tag = try parseReturnTag(p, previousTags, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "template")) {
        tag = try parseTemplateTag(p, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "type")) {
        tag = try parseTypeTag(p, previousTags, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "typedef")) {
        tag = try parseTypedefTag(p, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "callback")) {
        tag = try parseCallbackTag(p, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "overload")) {
        tag = try parseOverloadTag(p, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "satisfies")) {
        tag = try parseSatisfiesTag(p, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "see")) {
        tag = try parseSeeTag(p, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "exception") or std.mem.eql(u8, tagNameText, "throws")) {
        tag = try parseThrowsTag(p, start, tagName, margin, indentText);
    } else if (std.mem.eql(u8, tagNameText, "import")) {
        tag = try parseImportTag(p, start, tagName, margin, indentText);
    } else {
        tag = try parseUnknownTag(p, start, tagName, margin, indentText);
    }

    return tag;
}

pub fn parseTrailingTagComments(p: *Parser, pos: usize, end: usize, margin: isize, indentText: []const u8) anyerror!?u32 {
    _ = pos;
    var m = margin;
    if (indentText.len == 0) {
        m += @as(isize, @intCast(p.scanner.getTokenEnd() - end));
    }
    var initialMargin: []const u8 = "";
    if (m < indentText.len) {
        initialMargin = indentText[@as(usize, @intCast(m))..];
    }
    return try parseTagComments(p, m, initialMargin);
}

pub fn parseTagComments(p: *Parser, indent: isize, initialMargin: []const u8) anyerror!?u32 {
    const commentsPos = p.scanner.getTokenFullStart();
    var comments = std.ArrayList([]const u8).empty;
    defer comments.deinit(p.allocator);
    var parts = std.ArrayList(NodeIndex).empty;
    defer parts.deinit(p.allocator);

    var linkEnd: isize = -1;
    var state = jsdocState.BeginningOfLine;
    var backtickCount: usize = 0;
    var inFencedCodeBlock = false;
    var curr_indent = @as(usize, @intCast(@max(indent, 0)));
    var margin: isize = -1;

    const pushComment = struct {
        fn run(allocator: std.mem.Allocator, coms: *std.ArrayList([]const u8), m: *isize, ind: *usize, text: []const u8) void {
            if (m.* == -1) {
                m.* = @as(isize, @intCast(ind.*));
            }
            coms.append(allocator, text) catch unreachable;
            ind.* += text.len;
        }
    }.run;

    if (initialMargin.len > 0) {
        pushComment(p.allocator, &comments, &margin, &curr_indent, initialMargin);
        state = .SawAsterisk;
    }

    var tok = p.token;
    while (true) {
        if (tok != kind.Kind.BacktickToken and backtickCount > 0) {
            if (backtickCount >= 3) {
                inFencedCodeBlock = !inFencedCodeBlock;
            }
            backtickCount = 0;
        }
        switch (tok) {
            kind.Kind.NewLineTrivia => {
                state = .BeginningOfLine;
                try comments.append(p.allocator, p.scanner.getTokenValue());
                curr_indent = 0;
            },
            kind.Kind.AtToken => {
                if (!inFencedCodeBlock and p.scanner.canFollowJSDocAt()) {
                    p.scanner.resetPos(p.scanner.getTokenEnd() - 1);
                    break;
                }
                if (inFencedCodeBlock) {
                    state = .SavingBackticks;
                } else {
                    state = .SavingComments;
                }
                pushComment(p.allocator, &comments, &margin, &curr_indent, p.scanner.getTokenValue());
            },
            kind.Kind.EndOfFile => {
                break;
            },
            kind.Kind.WhitespaceTrivia => {
                const whitespace = p.scanner.getTokenValue();
                if (margin > -1 and @as(isize, @intCast(curr_indent + whitespace.len)) > margin) {
                    const idx = @max(margin - @as(isize, @intCast(curr_indent)), 0);
                    try comments.append(p.allocator, whitespace[@as(usize, @intCast(idx))..]);
                    if (inFencedCodeBlock) {
                        state = .SavingBackticks;
                    } else {
                        state = .SavingComments;
                    }
                }
                curr_indent += whitespace.len;
            },
            kind.Kind.OpenBraceToken => {
                if (inFencedCodeBlock) {
                    state = .SavingBackticks;
                    pushComment(p.allocator, &comments, &margin, &curr_indent, p.scanner.getTokenValue());
                } else {
                    state = .SavingComments;
                    const commentEnd = p.scanner.getTokenFullStart();
                    const linkStart = p.scanner.getTokenEnd() - 1;
                    const link = try parseJSDocLink(p, linkStart);
                    if (link != 0) {
                        var commentStart: usize = 0;
                        if (linkEnd > -1) {
                            commentStart = @as(usize, @intCast(linkEnd));
                        } else {
                            commentStart = commentsPos;
                        }
                        const text = try std.mem.concat(p.allocator, u8, comments.items);
                        const jsdocText = try p.ast.pushNode(.{ .JSDocText = .{
                            .Flags = 0,
                            .text = text,
                        } });
                        _ = finishNodeWithEnd(p, jsdocText, commentStart, commentEnd);
                        try parts.append(p.allocator, jsdocText);
                        try parts.append(p.allocator, link);
                        comments.clearRetainingCapacity();
                        linkEnd = @as(isize, @intCast(p.scanner.getTokenEnd()));
                    } else {
                        pushComment(p.allocator, &comments, &margin, &curr_indent, p.scanner.getTokenValue());
                    }
                }
            },
            kind.Kind.BacktickToken => {
                backtickCount += 1;
                if (state == .SavingBackticks) {
                    state = .SavingComments;
                } else {
                    state = .SavingBackticks;
                }
                pushComment(p.allocator, &comments, &margin, &curr_indent, p.scanner.getTokenValue());
            },
            kind.Kind.JSDocCommentTextToken => {
                if (state != .SavingBackticks) {
                    if (inFencedCodeBlock) {
                        state = .SavingBackticks;
                    } else {
                        state = .SavingComments;
                    }
                }
                pushComment(p.allocator, &comments, &margin, &curr_indent, p.scanner.getTokenValue());
            },
            kind.Kind.AsteriskToken => {
                if (state == .BeginningOfLine) {
                    state = .SawAsterisk;
                    curr_indent += 1;
                    tok = p.nextTokenJSDoc();
                    continue;
                }
                pushComment(p.allocator, &comments, &margin, &curr_indent, p.scanner.getTokenValue());
            },
            else => {
                if (state != .SavingBackticks) {
                    if (inFencedCodeBlock) {
                        state = .SavingBackticks;
                    } else {
                        state = .SavingComments;
                    }
                }
                pushComment(p.allocator, &comments, &margin, &curr_indent, p.scanner.getTokenValue());
            },
        }

        if (state == .SavingComments or state == .SavingBackticks) {
            tok = p.nextJSDocCommentTextToken(state == .SavingBackticks);
        } else {
            tok = p.nextTokenJSDoc();
        }
    }

    const final_comments = removeLeadingNewlines(comments.items);
    if (final_comments.len > 0) {
        var commentStart: usize = 0;
        if (linkEnd > -1) {
            commentStart = @as(usize, @intCast(linkEnd));
        } else {
            commentStart = commentsPos;
        }
        const text = try std.mem.concat(p.allocator, u8, final_comments);
        const jsdocText = try p.ast.pushNode(.{ .JSDocText = .{
            .Flags = 0,
            .text = text,
        } });
        _ = finishNode(p, jsdocText, commentStart);
        try parts.append(p.allocator, jsdocText);
    }

    if (parts.items.len > 0) {
        return try p.ast.pushNodeList(parts.items);
    }
    return null;
}

pub fn parseJSDocLink(p: *Parser, start: usize) anyerror!NodeIndex {
    const state = p.mark();
    const linkType = parseJSDocLinkPrefix(p);
    if (linkType.len == 0) {
        p.rewind(state);
        return 0;
    }
    _ = p.nextTokenJSDoc();
    skipWhitespace(p);
    const name = try parseJSDocLinkName(p);
    var text_list = std.ArrayList([]const u8).empty;
    defer text_list.deinit(p.allocator);

    while (p.token != kind.Kind.CloseBraceToken and p.token != kind.Kind.NewLineTrivia and p.token != kind.Kind.EndOfFile) {
        try text_list.append(p.allocator, p.scanner.getTokenValue());
        _ = p.nextTokenJSDoc();
    }
    const final_text = try std.mem.concat(p.allocator, u8, text_list.items);

    var create: NodeIndex = 0;
    if (std.mem.eql(u8, linkType, "link")) {
        create = try p.ast.pushNode(.{ .JSDocLink = .{
            .Flags = 0,
            .text = final_text,
            .name = name,
        } });
    } else if (std.mem.eql(u8, linkType, "linkcode")) {
        create = try p.ast.pushNode(.{ .JSDocLinkCode = .{
            .Flags = 0,
            .text = final_text,
            .name = name,
        } });
    } else {
        create = try p.ast.pushNode(.{ .JSDocLinkPlain = .{
            .Flags = 0,
            .text = final_text,
            .name = name,
        } });
    }

    return finishNodeWithEnd(p, create, start, p.scanner.getTokenEnd());
}

pub fn parseJSDocLinkName(p: *Parser) anyerror!?NodeIndex {
    if (p.isIdentifier() or kind.isKeyword(p.token)) {
        const pos = p.scanner.getTokenFullStart();
        var name = try p.parseIdentifierName();
        while (p.parseOptional(kind.Kind.DotToken)) {
            var right: NodeIndex = 0;
            if (p.token == kind.Kind.PrivateIdentifier) {
                right = try p.createMissingIdentifier();
            } else {
                right = try p.parseIdentifierName();
            }
            const qname = try p.ast.pushNode(.{ .QualifiedName = .{
                .Flags = 0,
                .Left = name,
                .Right = right,
            } });
            name = finishNode(p, qname, pos);
        }
        while (p.token == kind.Kind.PrivateIdentifier) {
            _ = p.scanner.reScanHashToken();
            _ = p.nextTokenJSDoc();
            const qname = try p.ast.pushNode(.{ .QualifiedName = .{
                .Flags = 0,
                .Left = name,
                .Right = try p.parseIdentifier(),
            } });
            name = finishNode(p, qname, pos);
        }
        return name;
    }
    return null;
}

pub fn parseJSDocLinkPrefix(p: *Parser) []const u8 {
    _ = skipWhitespaceOrAsterisk(p);
    if (p.token == kind.Kind.OpenBraceToken) {
        if (p.nextTokenJSDoc() == kind.Kind.AtToken) {
            if (p.isIdentifier() or kind.isKeyword(p.nextTokenJSDoc())) {
                const kind_val = p.scanner.getTokenValue();
                if (std.mem.eql(u8, kind_val, "link") or std.mem.eql(u8, kind_val, "linkcode") or std.mem.eql(u8, kind_val, "linkplain")) {
                    return kind_val;
                }
            }
        }
    }
    return "";
}

pub fn parseUnknownTag(p: *Parser, start: usize, tagName: NodeIndex, indent: isize, indentText: []const u8) anyerror!NodeIndex {
    const comments = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), indent, indentText);
    const tag = try p.ast.pushNode(.{ .JSDocUnknownTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comments,
    } });
    return finishNode(p, tag, start);
}

pub fn tryParseTypeExpression(p: *Parser) anyerror!?NodeIndex {
    _ = skipWhitespaceOrAsterisk(p);
    if (p.token == kind.Kind.OpenBraceToken) {
        return try parseJSDocTypeExpression(p, false);
    }
    return null;
}

pub fn parseBracketNameInPropertyAndParamTag(p: *Parser, target: propertyLikeParse) anyerror!struct { name: NodeIndex, isBracketed: bool } {
    const isBracketed = parseOptionalJsdoc(p, kind.Kind.OpenBracketToken);
    if (isBracketed) {
        skipWhitespace(p);
    }
    const isBackquoted = parseOptionalJsdoc(p, kind.Kind.BacktickToken);
    const name = try parseJSDocEntityName(p, if (target == .Parameter) null else &diagnostics.generated.Identifier_expected);
    if (isBackquoted) {
        _ = p.parseExpected(kind.Kind.BacktickToken);
    }
    if (isBracketed) {
        skipWhitespace(p);
        if (p.parseOptional(kind.Kind.EqualsToken)) {
            _ = try @import("expression.zig").parseExpression(p);
        }
        _ = p.parseExpected(kind.Kind.CloseBracketToken);
    }
    return .{ .name = name, .isBracketed = isBracketed };
}

fn isObjectOrObjectArrayTypeReference(tree: *ast.Ast, typeNode: NodeIndex) bool {
    const nodeData = tree.getNode(typeNode);
    switch (nodeData) {
        .ObjectKeyword => return true,
        .ArrayType => |arr| return isObjectOrObjectArrayTypeReference(tree, arr.ElementType),
        .TypeReference => |ref| {
            const typeNameData = tree.getNode(ref.TypeName);
            if (typeNameData == .Identifier) {
                return std.mem.eql(u8, typeNameData.Identifier.Text, "Object") and ref.TypeArguments == null;
            }
            return false;
        },
        else => return false,
    }
}

pub fn parseParameterOrPropertyTag(p: *Parser, start: usize, tagName: NodeIndex, target: propertyLikeParse, indent: isize) anyerror!NodeIndex {
    var typeExpression = try tryParseTypeExpression(p);
    var isNameFirst = (typeExpression == null);
    _ = skipWhitespaceOrAsterisk(p);

    const bracketRes = try parseBracketNameInPropertyAndParamTag(p, target);
    const name = bracketRes.name;
    const isBracketed = bracketRes.isBracketed;
    const indentText = skipWhitespaceOrAsterisk(p);

    if (isNameFirst and p.lookAhead(struct {
        fn run(parser: *Parser) bool {
            return parseJSDocLinkPrefix(parser).len == 0;
        }
    }.run)) {
        typeExpression = try tryParseTypeExpression(p);
    }

    const comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), indent, indentText);
    const nestedTypeLiteral = try parseNestedTypeLiteral(p, typeExpression, name, target, indent);
    if (nestedTypeLiteral != null) {
        typeExpression = nestedTypeLiteral;
        isNameFirst = true;
    }

    const result = try p.ast.pushNode(.{ .JSDocParameterTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
        .name = name,
        .IsBracketed = if (isBracketed) 1 else 0,
        .TypeExpression = typeExpression,
        .IsNameFirst = if (isNameFirst) 1 else 0,
    } });
    return finishNode(p, result, start);
}

pub fn parseNestedTypeLiteral(p: *Parser, typeExpression: ?NodeIndex, name: NodeIndex, target: propertyLikeParse, indent: isize) anyerror!?NodeIndex {
    if (typeExpression != null and isObjectOrObjectArrayTypeReference(&p.ast, typeExpression.?)) {
        const pos = p.scanner.getTokenFullStart();
        var children = std.ArrayList(NodeIndex).empty;
        defer children.deinit(p.allocator);

        while (true) {
            const state = p.mark();
            const child = try parseChildParameterOrPropertyTag(p, target, indent, name);
            if (child == null) {
                p.rewind(state);
                break;
            }
            const childData = p.ast.getNode(child.?);
            switch (childData) {
                .JSDocParameterTag, .JSDocPropertyTag => {
                    try children.append(p.allocator, child.?);
                },
                .JSDocTemplateTag => {
                    // Report warning or similar
                },
                else => {},
            }
        }

        if (children.items.len > 0) {
            const childrenList = try p.ast.pushNodeList(children.items);
            const isArrayType = p.ast.getNode(typeExpression.?) == .ArrayType;
            const literal = try p.ast.pushNode(.{ .JSDocTypeLiteral = .{
                .Flags = 0,
                .Symbol = 0,
                .JSDocPropertyTags = childrenList,
                .IsArrayType = if (isArrayType) 1 else 0,
            } });
            _ = finishNode(p, literal, pos);
            const expr = try p.ast.pushNode(.{ .JSDocTypeExpression = .{
                .Flags = 0,
                .Type = literal,
            } });
            return finishNode(p, expr, pos);
        }
    }
    return null;
}

pub fn parseReturnTag(p: *Parser, previousTags: []const NodeIndex, start: usize, tagName: NodeIndex, indent: isize, indentText: []const u8) anyerror!NodeIndex {
    _ = previousTags; // standard typescript-go handles warnings inside checker
    const typeExpression = try tryParseTypeExpression(p);
    const comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), indent, indentText);
    const tag = try p.ast.pushNode(.{ .JSDocReturnTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
        .TypeExpression = typeExpression,
    } });
    return finishNode(p, tag, start);
}

pub fn parseTypeTag(p: *Parser, previousTags: []const NodeIndex, start: usize, tagName: NodeIndex, indent: isize, indentText: []const u8) anyerror!NodeIndex {
    _ = previousTags;
    const typeExpression = try parseJSDocTypeExpression(p, true);
    var comment: ?u32 = null;
    if (indent != -1) {
        comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), indent, indentText);
    }
    const tag = try p.ast.pushNode(.{ .JSDocTypeTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
        .TypeExpression = typeExpression,
    } });
    return finishNode(p, tag, start);
}

pub fn parseSeeTag(p: *Parser, start: usize, tagName: NodeIndex, indent: isize, indentText: []const u8) anyerror!NodeIndex {
    const hasNameReference = p.isIdentifier() and !std.mem.startsWith(u8, p.sourceText[p.scanner.getTokenEnd()..], "://") or
        p.token == kind.Kind.OpenBraceToken and p.lookAhead(struct {
            fn run(parser: *Parser) bool {
                _ = parser.nextToken();
                return parser.isIdentifier() or kind.isKeyword(parser.token);
            }
        }.run);

    var nameExpression: ?NodeIndex = null;
    if (hasNameReference) {
        nameExpression = try parseJSDocNameReference(p);
    }
    const comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), indent, indentText);
    const tag = try p.ast.pushNode(.{ .JSDocSeeTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
        .NameExpression = nameExpression orelse 0,
    } });
    return finishNode(p, tag, start);
}

pub fn parseImplementsTag(p: *Parser, start: usize, tagName: NodeIndex, margin: isize, indentText: []const u8) anyerror!NodeIndex {
    const className = try parseExpressionWithTypeArgumentsForAugments(p);
    const comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), margin, indentText);
    const tag = try p.ast.pushNode(.{ .JSDocImplementsTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
        .ClassName = className,
    } });
    return finishNode(p, tag, start);
}

pub fn parseAugmentsTag(p: *Parser, start: usize, tagName: NodeIndex, margin: isize, indentText: []const u8) anyerror!NodeIndex {
    const className = try parseExpressionWithTypeArgumentsForAugments(p);
    const comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), margin, indentText);
    const tag = try p.ast.pushNode(.{ .JSDocAugmentsTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
        .ClassName = className,
    } });
    return finishNode(p, tag, start);
}

pub fn parseSatisfiesTag(p: *Parser, start: usize, tagName: NodeIndex, margin: isize, indentText: []const u8) anyerror!NodeIndex {
    const typeExpression = try parseJSDocTypeExpression(p, false);
    const comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), margin, indentText);
    const tag = try p.ast.pushNode(.{ .JSDocSatisfiesTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
        .TypeExpression = typeExpression,
    } });
    return finishNode(p, tag, start);
}

pub fn parseThrowsTag(p: *Parser, start: usize, tagName: NodeIndex, margin: isize, indentText: []const u8) anyerror!NodeIndex {
    const typeExpression = try tryParseTypeExpression(p);
    const comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), margin, indentText);
    const tag = try p.ast.pushNode(.{ .JSDocThrowsTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
        .TypeExpression = typeExpression,
    } });
    return finishNode(p, tag, start);
}

pub fn parseImportTag(p: *Parser, start: usize, tagName: NodeIndex, margin: isize, indentText: []const u8) anyerror!NodeIndex {
    const afterImportTagPos = p.scanner.getTokenFullStart();
    var identifier: ?NodeIndex = null;
    if (p.isIdentifier()) {
        identifier = try p.parsePrivateIdentifier();
    }
    const importClause = try p.tryParseImportClause(identifier, afterImportTagPos, kind.Kind.TypeKeyword, true);
    const moduleSpecifier = if (p.token == kind.Kind.StringLiteral) try @import("expression.zig").parseExpression(p) else 0;
    const attributes = try p.parseImportAttributes();
    const comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), margin, indentText);
    const tag = try p.ast.pushNode(.{ .JSDocImportTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
        .ImportClause = importClause orelse 0,
        .ModuleSpecifier = moduleSpecifier,
        .Attributes = attributes,
    } });
    return finishNode(p, tag, start);
}

pub fn parseExpressionWithTypeArgumentsForAugments(p: *Parser) anyerror!NodeIndex {
    const usedBrace = p.parseOptional(kind.Kind.OpenBraceToken);
    const pos = p.scanner.getTokenFullStart();
    const expression = try parsePropertyAccessEntityNameExpression(p);
    p.scanner.setSkipJSDocLeadingAsterisks(true);
    const typeArguments = try p.parseTypeArguments();
    p.scanner.setSkipJSDocLeadingAsterisks(false);
    const node = try p.ast.pushNode(.{ .ExpressionWithTypeArguments = .{
        .Flags = 0,
        .Expression = expression,
        .TypeArguments = typeArguments,
    } });
    _ = finishNode(p, node, pos);
    if (usedBrace) {
        skipWhitespace(p);
        _ = p.parseExpected(kind.Kind.CloseBraceToken);
    }
    return node;
}

pub fn parsePropertyAccessEntityNameExpression(p: *Parser) anyerror!NodeIndex {
    const pos = p.scanner.getTokenFullStart();
    var node = try parseJSDocIdentifierName(p, null);
    while (p.parseOptional(kind.Kind.DotToken)) {
        const name = try parseJSDocIdentifierName(p, null);
        node = try p.ast.pushNode(.{ .PropertyAccessExpression = .{
            .Flags = 0,
            .Expression = node,
            .QuestionDotToken = null,
            .name = name,
        } });
        _ = finishNode(p, node, pos);
    }
    return node;
}

pub fn parseSimplePublicTag(p: *Parser, start: usize, tagName: NodeIndex, margin: isize, indentText: []const u8) anyerror!NodeIndex {
    const comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), margin, indentText);
    const tag = try p.ast.pushNode(.{ .JSDocPublicTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
    } });
    return finishNode(p, tag, start);
}

pub fn parseSimplePrivateTag(p: *Parser, start: usize, tagName: NodeIndex, margin: isize, indentText: []const u8) anyerror!NodeIndex {
    const comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), margin, indentText);
    const tag = try p.ast.pushNode(.{ .JSDocPrivateTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
    } });
    return finishNode(p, tag, start);
}

pub fn parseSimpleProtectedTag(p: *Parser, start: usize, tagName: NodeIndex, margin: isize, indentText: []const u8) anyerror!NodeIndex {
    const comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), margin, indentText);
    const tag = try p.ast.pushNode(.{ .JSDocProtectedTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
    } });
    return finishNode(p, tag, start);
}

pub fn parseSimpleReadonlyTag(p: *Parser, start: usize, tagName: NodeIndex, margin: isize, indentText: []const u8) anyerror!NodeIndex {
    const comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), margin, indentText);
    const tag = try p.ast.pushNode(.{ .JSDocReadonlyTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
    } });
    return finishNode(p, tag, start);
}

pub fn parseSimpleOverrideTag(p: *Parser, start: usize, tagName: NodeIndex, margin: isize, indentText: []const u8) anyerror!NodeIndex {
    const comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), margin, indentText);
    const tag = try p.ast.pushNode(.{ .JSDocOverrideTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
    } });
    return finishNode(p, tag, start);
}

pub fn parseSimpleDeprecatedTag(p: *Parser, start: usize, tagName: NodeIndex, margin: isize, indentText: []const u8) anyerror!NodeIndex {
    const comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), margin, indentText);
    const tag = try p.ast.pushNode(.{ .JSDocDeprecatedTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
    } });
    return finishNode(p, tag, start);
}

pub fn parseThisTag(p: *Parser, start: usize, tagName: NodeIndex, margin: isize, indentText: []const u8) anyerror!NodeIndex {
    const typeExpression = try parseJSDocTypeExpression(p, true);
    skipWhitespace(p);
    const comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), margin, indentText);
    const tag = try p.ast.pushNode(.{ .JSDocThisTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
        .TypeExpression = typeExpression,
    } });
    return finishNode(p, tag, start);
}

pub fn parseJSDocTypeNameWithNamespace(p: *Parser, nested: bool) anyerror!?NodeIndex {
    const start = p.scanner.getTokenStart();
    if (!p.isIdentifier() and !kind.isKeyword(p.token)) {
        return null;
    }
    const typeNameOrNamespaceName = try parseJSDocIdentifierName(p, null);
    if (parseOptionalJsdoc(p, kind.Kind.DotToken)) {
        const body = try parseJSDocTypeNameWithNamespace(p, true);
        const jsDocNamespaceNode = try p.ast.pushNode(.{ .ModuleDeclaration = .{
            .Symbol = 0,
            .Flags = if (nested) @import("../ast/ast_utils.zig").NodeFlags.NestedNamespace else 0,
            .modifiers = null,
            .modifierFlags = 0,
            .AsteriskToken = null,
            .Body = body orelse 0,
            .Keyword = 0,
            .name = typeNameOrNamespaceName,
        } });
        return finishNode(p, jsDocNamespaceNode, start);
    }
    return typeNameOrNamespaceName;
}

pub fn parseTypedefTag(p: *Parser, start: usize, tagName: NodeIndex, indent: isize, indentText: []const u8) anyerror!NodeIndex {
    const typeExpression = try tryParseTypeExpression(p);
    _ = skipWhitespaceOrAsterisk(p);
    var fullName = try parseJSDocTypeNameWithNamespace(p, false);
    if (fullName == null) {
        fullName = try parseJSDocIdentifierName(p, null);
    }
    skipWhitespace(p);
    var comment = try parseTagComments(p, indent, "");

    var end: isize = -1;
    var hasChildren = false;
    if (typeExpression == null or isObjectOrObjectArrayTypeReference(&p.ast, typeExpression.?)) {
        var jsdocPropertyTags = std.ArrayList(NodeIndex).empty;
        defer jsdocPropertyTags.deinit(p.allocator);
        var childTypeTag: ?NodeIndex = null;

        while (true) {
            const state = p.mark();
            const child = try parseChildPropertyTag(p, indent);
            if (child == null) {
                p.rewind(state);
                break;
            }
            hasChildren = true;
            const childData = p.ast.getNode(child.?);
            switch (childData) {
                .JSDocTypeTag => {
                    if (childTypeTag == null) {
                        childTypeTag = child.?;
                    }
                },
                else => {
                    try jsdocPropertyTags.append(p.allocator, child.?);
                },
            }
        }

        if (hasChildren) {
            const isArrayType = typeExpression != null and p.ast.getNode(typeExpression.?) == .ArrayType;
            const tagsList = try p.ast.pushNodeList(jsdocPropertyTags.items);
            const jsdocTypeLiteral = try p.ast.pushNode(.{ .JSDocTypeLiteral = .{
                .Flags = 0,
                .Symbol = 0,
                .JSDocPropertyTags = tagsList,
                .IsArrayType = if (isArrayType) 1 else 0,
            } });
            _ = finishNode(p, jsdocTypeLiteral, start);
            end = @as(isize, @intCast(p.scanner.getTokenEnd()));
        }
    }

    if (end == -1) {
        if (comment != null) {
            end = @as(isize, @intCast(p.scanner.getTokenFullStart()));
        } else if (fullName != null) {
            end = @as(isize, @intCast(p.scanner.getTokenEnd()));
        } else if (typeExpression != null) {
            end = @as(isize, @intCast(p.scanner.getTokenEnd()));
        } else {
            end = @as(isize, @intCast(p.scanner.getTokenEnd()));
        }
    }

    if (comment == null) {
        comment = try parseTrailingTagComments(p, start, @as(usize, @intCast(end)), indent, indentText);
    }

    const typedefTag = try p.ast.pushNode(.{ .JSDocTypedefTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
        .TypeExpression = typeExpression,
        .name = fullName orelse 0,
    } });
    return finishNodeWithEnd(p, typedefTag, start, @as(usize, @intCast(end)));
}

pub fn parseCallbackTagParameters(p: *Parser, indent: isize) anyerror!?u32 {
    var parameters = std.ArrayList(NodeIndex).empty;
    defer parameters.deinit(p.allocator);

    while (true) {
        const state = p.mark();
        const child = try parseChildParameterOrPropertyTag(p, .CallbackParameter, indent, 0);
        if (child == null) {
            p.rewind(state);
            break;
        }
        try parameters.append(p.allocator, child.?);
    }
    if (parameters.items.len > 0) {
        return try p.ast.pushNodeList(parameters.items);
    }
    return null;
}

pub fn parseJSDocSignature(p: *Parser, start: usize, indent: isize) anyerror!NodeIndex {
    const parameters = try parseCallbackTagParameters(p, indent);
    var returnTag: ?NodeIndex = null;
    const state = p.mark();
    if (parseOptionalJsdoc(p, kind.Kind.AtToken)) {
        const tag = try parseTag(p, &[_]NodeIndex{}, indent);
        const tagData = p.ast.getNode(tag);
        if (tagData == .JSDocReturnTag) {
            returnTag = tag;
        }
    }
    if (returnTag == null) {
        p.rewind(state);
    }

    const sig = try p.ast.pushNode(.{ .JSDocSignature = .{
        .Flags = 0,
        .Symbol = 0,
        .TypeParameters = null,
        .Parameters = parameters orelse 0,
        .Type = returnTag,
        .FullSignature = null,
    } });
    return finishNode(p, sig, start);
}

pub fn parseCallbackTag(p: *Parser, start: usize, tagName: NodeIndex, indent: isize, indentText: []const u8) anyerror!NodeIndex {
    var fullName = try parseJSDocTypeNameWithNamespace(p, false);
    if (fullName == null) {
        fullName = try parseJSDocIdentifierName(p, null);
    }
    skipWhitespace(p);
    var comment = try parseTagComments(p, indent, "");
    const typeExpression = try parseJSDocSignature(p, p.scanner.getTokenFullStart(), indent);
    if (comment == null) {
        comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), indent, indentText);
    }
    var end: usize = 0;
    if (comment != null) {
        end = p.scanner.getTokenFullStart();
    } else {
        end = p.scanner.getTokenEnd();
    }

    const callbackTag = try p.ast.pushNode(.{ .JSDocCallbackTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
        .TypeExpression = typeExpression,
        .name = fullName,
    } });
    return finishNodeWithEnd(p, callbackTag, start, end);
}

pub fn parseOverloadTag(p: *Parser, start: usize, tagName: NodeIndex, indent: isize, indentText: []const u8) anyerror!NodeIndex {
    skipWhitespace(p);
    var comment = try parseTagComments(p, indent, "");
    const typeExpression = try parseJSDocSignature(p, start, indent);
    if (comment == null) {
        comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), indent, indentText);
    }
    var end: usize = 0;
    if (comment != null) {
        end = p.scanner.getTokenFullStart();
    } else {
        end = p.scanner.getTokenEnd();
    }

    const overloadTag = try p.ast.pushNode(.{ .JSDocOverloadTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
        .TypeExpression = typeExpression,
    } });
    return finishNodeWithEnd(p, overloadTag, start, end);
}

pub fn parseChildPropertyTag(p: *Parser, indent: isize) anyerror!?NodeIndex {
    return try parseChildParameterOrPropertyTag(p, .Property, indent, 0);
}

pub fn parseChildParameterOrPropertyTag(p: *Parser, target: propertyLikeParse, indent: isize, name: NodeIndex) anyerror!?NodeIndex {
    var canParseTag = true;
    var seenAsterisk = false;
    while (true) {
        const tok = p.nextTokenJSDoc();
        switch (tok) {
            kind.Kind.AtToken => {
                if (canParseTag and p.scanner.canFollowJSDocAt()) {
                    const child = try tryParseChildTag(p, target, indent);
                    if (child != null and name != 0) {
                        // checks here
                    }
                    return child;
                }
                seenAsterisk = false;
            },
            kind.Kind.NewLineTrivia => {
                canParseTag = true;
                seenAsterisk = false;
            },
            kind.Kind.AsteriskToken => {
                if (seenAsterisk) {
                    canParseTag = false;
                }
                seenAsterisk = true;
            },
            kind.Kind.EndOfFile => {
                return null;
            },
            else => {
                canParseTag = false;
            },
        }
    }
}

pub fn tryParseChildTag(p: *Parser, target: propertyLikeParse, indent: isize) anyerror!?NodeIndex {
    if (p.token != kind.Kind.AtToken) {
        @panic("should only be called when at @");
    }
    const start = p.scanner.getTokenFullStart();
    _ = p.nextTokenJSDoc();

    const tagName = try parseJSDocIdentifierName(p, null);
    const indentText = skipWhitespaceOrAsterisk(p);
    var t: i32 = 0;

    const tagNameText = p.ast.getNode(tagName).Identifier.Text;
    if (std.mem.eql(u8, tagNameText, "type")) {
        if (target == .Property) {
            return try parseTypeTag(p, &[_]NodeIndex{}, start, tagName, -1, "");
        }
    } else if (std.mem.eql(u8, tagNameText, "prop") or std.mem.eql(u8, tagNameText, "property")) {
        t = @intFromEnum(propertyLikeParse.Property);
    } else if (std.mem.eql(u8, tagNameText, "arg") or std.mem.eql(u8, tagNameText, "argument") or std.mem.eql(u8, tagNameText, "param")) {
        t = @intFromEnum(propertyLikeParse.Parameter) | @intFromEnum(propertyLikeParse.CallbackParameter);
    } else if (std.mem.eql(u8, tagNameText, "template")) {
        return try parseTemplateTag(p, start, tagName, indent, indentText);
    } else if (std.mem.eql(u8, tagNameText, "this")) {
        return try parseThisTag(p, start, tagName, indent, indentText);
    }

    if (t == 0 or (@intFromEnum(target) & t) == 0) {
        return null;
    }
    return try parseParameterOrPropertyTag(p, start, tagName, target, indent);
}

pub fn parseTemplateTagTypeParameter(p: *Parser) anyerror!?NodeIndex {
    const typeParameterPos = p.scanner.getTokenFullStart();
    const isBracketed = parseOptionalJsdoc(p, kind.Kind.OpenBracketToken);
    if (isBracketed) {
        skipWhitespace(p);
    }

    const modifiers = try p.parseModifiersEx(false);
    const name = try parseJSDocIdentifierName(p, null);
    var defaultType: ?NodeIndex = null;
    if (isBracketed) {
        skipWhitespace(p);
        _ = p.parseExpected(kind.Kind.EqualsToken);
        const saveContextFlags = p.contextFlags;
        p.setContextFlags(@import("../ast/ast_utils.zig").NodeFlags.JSDoc, true);
        defaultType = try parseJSDocType(p);
        p.contextFlags = saveContextFlags;
        _ = p.parseExpected(kind.Kind.CloseBracketToken);
    }

    const nameData = p.ast.getNode(name);
    if (nameData == .Identifier and nameData.Identifier.Text.len == 0) {
        return null;
    }

    const decl = try p.ast.pushNode(.{ .TypeParameter = .{
        .Flags = 0,
        .Symbol = 0,
        .modifiers = modifiers,
        .modifierFlags = 0,
        .name = name,
        .Constraint = null,
        .Expression = null,
        .DefaultType = defaultType,
    } });
    return finishNode(p, decl, typeParameterPos);
}

pub fn parseTemplateTagTypeParameters(p: *Parser) anyerror!?u32 {
    var typeParameters = std.ArrayList(NodeIndex).empty;
    defer typeParameters.deinit(p.allocator);

    while (true) {
        skipWhitespace(p);
        const node = try parseTemplateTagTypeParameter(p);
        if (node != null) {
            try typeParameters.append(p.allocator, node.?);
        }
        _ = skipWhitespaceOrAsterisk(p);
        if (!parseOptionalJsdoc(p, kind.Kind.CommaToken)) {
            break;
        }
    }
    if (typeParameters.items.len > 0) {
        return try p.ast.pushNodeList(typeParameters.items);
    }
    return null;
}

pub fn parseTemplateTag(p: *Parser, start: usize, tagName: NodeIndex, indent: isize, indentText: []const u8) anyerror!NodeIndex {
    var constraint: ?NodeIndex = null;
    if (p.token == kind.Kind.OpenBraceToken) {
        constraint = try parseJSDocTypeExpression(p, false);
    }
    const typeParameters = try parseTemplateTagTypeParameters(p);
    const comment = try parseTrailingTagComments(p, start, p.scanner.getTokenFullStart(), indent, indentText);
    const tag = try p.ast.pushNode(.{ .JSDocTemplateTag = .{
        .Flags = 0,
        .TagName = tagName,
        .Comment = comment,
        .Constraint = constraint orelse 0,
        .TypeParameters = typeParameters orelse 0,
    } });
    return finishNode(p, tag, start);
}

pub fn parseOptionalJsdoc(p: *Parser, t: kind.Kind) bool {
    if (p.token == t) {
        _ = p.nextTokenJSDoc();
        return true;
    }
    return false;
}

pub fn parseJSDocEntityName(p: *Parser, diagnosticMessage: ?*const diagnostics.Message) anyerror!NodeIndex {
    var entity = try parseJSDocIdentifierName(p, diagnosticMessage);
    if (p.parseOptional(kind.Kind.OpenBracketToken)) {
        _ = p.parseExpected(kind.Kind.CloseBracketToken);
    }
    while (p.parseOptional(kind.Kind.DotToken)) {
        const name = try parseJSDocIdentifierName(p, null);
        if (p.parseOptional(kind.Kind.OpenBracketToken)) {
            _ = p.parseExpected(kind.Kind.CloseBracketToken);
        }
        const pos = p.scanner.getTokenFullStart();
        const qname = try p.ast.pushNode(.{ .QualifiedName = .{
            .Flags = 0,
            .Left = entity,
            .Right = name,
        } });
        entity = finishNode(p, qname, pos);
    }
    return entity;
}

pub fn parseJSDocIdentifierName(p: *Parser, diagnosticMessage: ?*const diagnostics.Message) anyerror!NodeIndex {
    if (!p.isIdentifier() and !kind.isKeyword(p.token)) {
        if (diagnosticMessage != null) {
            p.parseError(diagnosticMessage.?.text);
        }
        const missing = try p.ast.pushNode(.{ .Identifier = .{ .Flags = 0, .Text = "" } });
        return finishNode(p, missing, p.scanner.getTokenFullStart());
    }
    const pos = p.scanner.getTokenStart();
    const end = p.scanner.getTokenEnd();
    const text = p.scanner.getTokenValue();
    _ = p.nextTokenJSDoc();
    const ident = try p.ast.pushNode(.{ .Identifier = .{ .Flags = 0, .Text = text } });
    return finishNodeWithEnd(p, ident, pos, end);
}

pub fn parseJSDocType(p: *Parser) anyerror!NodeIndex {
    p.scanner.setSkipJSDocLeadingAsterisks(true);
    const pos = p.scanner.getTokenFullStart();

    const hasDotDotDot = p.parseOptional(kind.Kind.DotDotDotToken);
    var t = try p.parseTypeOrTypePredicate();
    p.scanner.setSkipJSDocLeadingAsterisks(false);
    if (hasDotDotDot) {
        t = try p.ast.pushNode(.{ .JSDocVariadicType = .{
            .Flags = 0,
            .Type = t,
        } });
        t = finishNode(p, t, pos);
    }
    if (p.token == kind.Kind.EqualsToken) {
        p.nextToken();
        t = try p.ast.pushNode(.{ .JSDocOptionalType = .{
            .Flags = 0,
            .Type = t,
        } });
        t = finishNode(p, t, pos);
    }
    return t;
}

pub fn parseJSDocNullableType(p: *Parser) anyerror!NodeIndex {
    const pos = p.scanner.getTokenFullStart();
    p.nextToken();
    const typeNode = try p.parseTypeOperatorOrHigher();
    const t = try p.ast.pushNode(.{ .JSDocNullableType = .{
        .Flags = 0,
        .Type = typeNode,
    } });
    return finishNode(p, t, pos);
}

pub fn parseJSDocNonNullableType(p: *Parser) anyerror!NodeIndex {
    const pos = p.scanner.getTokenFullStart();
    p.nextToken();
    const typeNode = try p.parseTypeOperatorOrHigher();
    const t = try p.ast.pushNode(.{ .JSDocNonNullableType = .{
        .Flags = 0,
        .Type = typeNode,
    } });
    return finishNode(p, t, pos);
}

pub fn parseJSDocAllType(p: *Parser) anyerror!NodeIndex {
    const pos = p.scanner.getTokenFullStart();
    p.nextToken();
    const t = try p.ast.pushNode(.{ .JSDocAllType = void{} });
    return finishNode(p, t, pos);
}

pub fn withJSDoc(p: *Parser, node: NodeIndex, info: @import("parser.zig").JSDocScannerInfo) anyerror!?[]const NodeIndex {
    if ((info & @import("parser.zig").jsdocScannerInfoHasJSDoc) == 0) {
        return null;
    }

    if (!p.isJavaScript()) {
        var flags = p.ast.getNodeFlags(node);
        flags |= @import("../ast/ast_utils.zig").NodeFlags.HasJSDoc;
        if ((info & @import("parser.zig").jsdocScannerInfoHasDeprecated) != 0) {
            flags |= @import("../ast/ast_utils.zig").NodeFlags.PossiblyContainsDeprecatedTag;
        }
        p.ast.setNodeFlags(node, flags);
        if ((info & @import("parser.zig").jsdocScannerInfoHasSeeOrLink) == 0) {
            return null;
        }
    }

    var commentRanges = std.ArrayList(scanner_pkg.CommentRange).empty;
    defer commentRanges.deinit(p.allocator);
    try scanner_pkg.getLeadingCommentRangesFromFullStart(p.allocator, &commentRanges, p.sourceText, @intCast(info >> 8));
    var range_index: usize = 0;
    while (range_index < commentRanges.items.len) {
        const comment = commentRanges.items[range_index];
        const length = comment.end - comment.pos;
        if (length < 4 or p.sourceText[comment.pos + 1] != '*' or p.sourceText[comment.pos + 2] != '*' or p.sourceText[comment.pos + 3] == '/') {
            _ = commentRanges.orderedRemove(range_index);
        } else {
            range_index += 1;
        }
    }

    p.hasDeprecatedTag = false;
    var jsdoc_list = std.ArrayList(NodeIndex).empty;
    defer jsdoc_list.deinit(p.allocator);

    var pos = p.ast.positions.items[node].pos;
    for (commentRanges.items) |comment| {
        if (try parseJSDocComment(p, node, comment.pos, @intCast(comment.end), pos)) |parsed| {
            p.ast.parents.items[parsed] = node;
            try jsdoc_list.append(p.allocator, parsed);
            pos = p.ast.positions.items[parsed].end;
        }
    }

    if (jsdoc_list.items.len != 0) {
        var flags = p.ast.getNodeFlags(node);
        if ((flags & @import("../ast/ast_utils.zig").NodeFlags.HasJSDoc) == 0) {
            flags |= @import("../ast/ast_utils.zig").NodeFlags.HasJSDoc;
        }
        if (p.hasDeprecatedTag) {
            p.hasDeprecatedTag = false;
            flags |= @import("../ast/ast_utils.zig").NodeFlags.PossiblyContainsDeprecatedTag;
        }
        p.ast.setNodeFlags(node, flags);

        const jsdoc_slice = try p.allocator.dupe(NodeIndex, jsdoc_list.items);
        try p.ast.jsdocCache.put(p.allocator, node, jsdoc_slice);

        try p.jsdocInfos.append(p.allocator, .{
            .parent = node,
            .jsDocs = jsdoc_slice,
        });
        return jsdoc_slice;
    }
    return null;
}
