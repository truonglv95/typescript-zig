const std = @import("std");
const ast = @import("../ast/ast.zig");
const astnav = @import("../astnav/tokens.zig");
const scanner = @import("../scanner/scanner.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const ls = @import("languageservice.zig");

pub fn provideOnAutoInsert(
    self: *ls.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.VSOnAutoInsertParams,
) !?lsproto.VSOnAutoInsertResponse {
    if (self.userPreferences().enableAutoClosingTags.isFalse()) {
        return null;
    }
    if (!std.mem.eql(u8, params.vSCh, ">")) {
        return null;
    }

    const res = self.getProgramAndFile(params.textDocument.uri);
    const position = self.converters.*.lineAndCharacterToPosition(res.file, params.position);

    const a = self.getAst(res.file);
    const source_file = self.getSourceFileNode(res.file);

    const token = astnav.findPrecedingToken(source_file, a, position);
    if (token == 0) {
        return null;
    }

    var closingText: ?[]const u8 = null;
    var element: ast.NodeIndex = 0;

    const tokenNode = a.getNode(token);
    const tokenKind = std.meta.activeTag(tokenNode);
    const tokenParent = a.getNodeParent(token);

    if (tokenKind == .GreaterThanToken and ast.isJsxOpeningElement(a, tokenParent)) {
        element = a.getNodeParent(tokenParent);
    } else if (ast.isJsxText(a, token) and ast.isJsxElement(a, tokenParent)) {
        element = tokenParent;
    }

    if (element != 0 and isUnclosedTag(a, element)) {
        const jsxElement = a.getNode(element).JsxElement;
        const tagNameNode = a.getNode(jsxElement.openingElement).JsxOpeningElement.tagName;
        // Slight divergence from Strada
        const tagNameStr = ast.entityNameToString(a, tagNameNode, scanner.getTextOfNode);
        closingText = try std.fmt.allocPrint(allocator, "</{s}>", .{tagNameStr});
    } else {
        var fragment: ast.NodeIndex = 0;
        if (tokenKind == .GreaterThanToken and ast.isJsxOpeningFragment(a, tokenParent)) {
            fragment = a.getNodeParent(tokenParent);
        } else if (ast.isJsxText(a, token) and ast.isJsxFragment(a, tokenParent)) {
            fragment = tokenParent;
        }

        if (fragment != 0 and isUnclosedFragment(a, fragment)) {
            closingText = try allocator.dupe(u8, "</>");
        }
    }

    if (closingText) |txt| {
        const escaped = try escapeSnippetText(allocator, txt);
        const newText = try std.fmt.allocPrint(allocator, "$0{s}", .{escaped});

        const response = lsproto.VSOnAutoInsertResponse{
            .VSOnAutoInsertResponseItem = lsproto.VSOnAutoInsertResponseItem{
                .textEditFormat = .Snippet,
                .textEdit = lsproto.TextEdit{
                    .range = lsproto.Range{ .start = params.position, .end = params.position },
                    .newText = newText,
                },
            },
        };
        return response;
    }

    return null;
}

fn isUnclosedTag(a: *ast.Ast, node: ast.NodeIndex) bool {
    const jsxElement = a.getNode(node).JsxElement;
    const openingElement = jsxElement.openingElement;
    const closingElement = jsxElement.closingElement;
    const openingTagName = a.getNode(openingElement).JsxOpeningElement.tagName;
    const closingTagName = a.getNode(closingElement).JsxClosingElement.tagName;
    
    if (!ast.tagNamesAreEquivalent(a, openingTagName, closingTagName)) {
        return true;
    }

    const parent = a.getNodeParent(node);
    if (ast.isJsxElement(a, parent)) {
        const parentElement = a.getNode(parent).JsxElement;
        const parentOpeningTagName = a.getNode(parentElement.openingElement).JsxOpeningElement.tagName;
        return ast.tagNamesAreEquivalent(a, openingTagName, parentOpeningTagName) and isUnclosedTag(a, parent);
    }

    return false;
}

fn isUnclosedFragment(a: *ast.Ast, node: ast.NodeIndex) bool {
    const jsxFragment = a.getNode(node).JsxFragment;
    const closingFragment = jsxFragment.closingFragment;
    if ((a.getNodeFlags(closingFragment) & ast.NodeFlags.ThisNodeHasError) != 0) {
        return true;
    }

    const parent = a.getNodeParent(node);
    if (ast.isJsxFragment(a, parent) and isUnclosedFragment(a, parent)) {
        return true;
    }

    return false;
}

fn escapeSnippetText(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    return std.mem.replaceOwned(u8, allocator, text, "$", "\\$");
}
