const std = @import("std");
const ast = @import("../ast/ast.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const compiler = @import("../compiler/program.zig");
const completions = @import("completions.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const astnav = @import("../astnav/tokens.zig");
const scanner = @import("../scanner/scanner.zig");

pub const JSDocSnippet = struct {
    text: []const u8,
    position: u32,
};

pub fn getDocCommentTemplateAtPosition(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    source_file: ast_gen.NodeIndex,
    position: u32,
) ?JSDocSnippet {
    const token = astnav.getTokenAtPosition(source_file, tree, position);
    if (token == 0) return null;
    
    var current: ast_gen.NodeIndex = token;
    var declaration: ast_gen.NodeIndex = 0;
    while (current != 0) : (current = tree.getNodeParent(current)) {
        const kind = tree.getNodeKind(current);
        if (kind == .FunctionDeclaration or kind == .MethodDeclaration or kind == .Constructor or kind == .MethodSignature or kind == .ArrowFunction) {
            declaration = current;
            break;
        }
    }
    
    if (declaration == 0) return null;
    
    const paramsNode = @import("../ast/ast_utils.zig").getParametersOfNode(tree, declaration);
    var param_names = std.ArrayListUnmanaged([]const u8).empty;
    defer param_names.deinit(allocator);
    
    if (paramsNode.len > 0) {
        
        for (@import("../ast/ast_utils.zig").getParametersOfNode(tree, declaration)) |param| {
            const nameNode = @import("../ast/ast_utils.zig").getNameOfNode(tree, param);
            if (nameNode != 0 and tree.getNodeKind(nameNode) == .Identifier) {
                param_names.append(allocator, @import("../ast/ast_utils.zig").getTextOfNode(tree, nameNode)) catch continue;
            } else {
                param_names.append(allocator, "param") catch continue;
            }
        }
    }
    
    const has_return = tree.getNodeKind(declaration) != .Constructor;
    
    const text = generateJSDocTemplate(allocator, param_names.items, has_return) catch return null;
    return JSDocSnippet{ .text = text, .position = position };
}

pub fn generateJSDocTemplate(
    allocator: std.mem.Allocator,
    param_names: []const []const u8,
    has_return: bool,
) ![]const u8 {
    var result = std.ArrayListUnmanaged(u8).empty;
    defer result.deinit(allocator);

    try result.appendSlice(allocator, "/**\n");
    try result.appendSlice(allocator, " * $1\n");

    for (param_names) |name| {
        try result.appendSlice(allocator, " * @param ");
        try result.appendSlice(allocator, name);
        try result.appendSlice(allocator, " $2\n");
    }

    if (has_return) {
        try result.appendSlice(allocator, " * @returns $3\n");
    }

    try result.appendSlice(allocator, " */");

    return result.toOwnedSlice(allocator);
}

const format = @import("../format/util.zig");
const stringutil = @import("../stringutil/stringutil.zig");

pub fn isPotentiallyValidJSDocSnippetCompletionPosition(allocator: std.mem.Allocator, tree: *ast.Ast, position: u32) !bool {
    const text = tree.sourceText;
    const lineStart = try format.getLineStartPositionForPosition(allocator, text, position);
    const prefix = text[lineStart..position];
    if (!isJSDocSnippetPrefix(prefix)) {
        return false;
    }

    const lineEnd = getLineEndOfPosition(tree, position);
    const suffix = text[position..lineEnd];
    return isJSDocSnippetSuffix(suffix);
}

fn skipSingleLineWhitespace(text: []const u8, start_pos: usize) usize {
    var pos = start_pos;
    while (pos < text.len) {
        const cp = stringutil.decodeJSStringRune(text[pos..]);
        if (cp.size == 0 or !stringutil.isWhiteSpaceSingleLine(cp.r)) {
            break;
        }
        pos += cp.size;
    }
    return pos;
}

fn trimRightSingleLineWhitespace(text: []const u8) []const u8 {
    var pos = text.len;
    while (pos > 0) {
        const c = text[pos - 1];
        if (c == ' ' or c == '\t' or c == 0x0B or c == 0x0C or c == 0xA0) {
            pos -= 1;
        } else {
            break;
        }
    }
    return text[0..pos];
}

fn isJSDocSnippetPrefix(prefix: []const u8) bool {
    const trimmed = trimRightSingleLineWhitespace(prefix);
    if (std.mem.endsWith(u8, trimmed, "/**")) {
        return true;
    }
    const start = skipSingleLineWhitespace(prefix, 0);
    if (start >= trimmed.len or trimmed[start] != '/') {
        return false;
    }
    if (start + 3 > trimmed.len) {
        return false;
    }
    for (trimmed[start + 1 ..]) |c| {
        if (c != '*') {
            return false;
        }
    }
    return trimmed.len - start >= 3;
}

fn isJSDocSnippetSuffix(suffix: []const u8) bool {
    const start = skipSingleLineWhitespace(suffix, 0);
    const trimmed = trimRightSingleLineWhitespace(suffix[start..]);
    if (trimmed.len == 0) {
        return true;
    }
    if (!std.mem.endsWith(u8, trimmed, "/")) {
        return false;
    }
    var i: usize = 0;
    while (i < trimmed.len - 1) : (i += 1) {
        if (trimmed[i] != '*') {
            return false;
        }
    }
    return true;
}

fn getLineEndOfPosition(a: *ast.Ast, position: u32) u32 {
    const text = a.sourceText;
    var end = position;
    while (end < text.len) : (end += 1) {
        if (text[end] == '\n' or text[end] == '\r') {
            break;
        }
    }
    return end;
}

pub fn getJSDocSnippetCompletion(languageService: anytype, allocator: std.mem.Allocator, file: compiler.FileId, position: u32) !?*completions.CompletionList {
    const prefs = languageService.userPreferences();
    if (prefs.enableJSDocCompletions == .False) return null;
    
    const tree = languageService.getAst(file);
    if (!(try isPotentiallyValidJSDocSnippetCompletionPosition(allocator, tree, position))) {
        return null;
    }
    
    const template = getDocCommentTemplateAtPosition(allocator, tree, 0, position) orelse return null;
    defer allocator.free(template.text);
    
    const lspItem = try allocator.create(lsproto.CompletionItem);
    lspItem.* = .{
        .label = try allocator.dupe(u8, template.text),
        .kind = .Snippet,
    };
    
    const item = try allocator.create(completions.CompletionItem);
    item.* = .{ .lspItem = lspItem, .symbol = 0 };
    
    const items = try allocator.alloc(*completions.CompletionItem, 1);
    items[0] = item;
    
    const list = try allocator.create(completions.CompletionList);
    list.* = .{
        .isIncomplete = false,
        .itemDefaults = null,
        .applyKind = null,
        .items = items,
    };
    return list;
}
