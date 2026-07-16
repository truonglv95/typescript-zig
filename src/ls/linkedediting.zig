const std = @import("std");


const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const astnav = @import("../astnav/tokens.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const ls = @import("languageservice.zig");

// allow the client to match more than valid tag names. This allows linked editing when typing is in progress or tag name is incomplete
// in Zig we might just return the string instead of creating a regex object, or use a string for the pattern
const jsxTagWordPattern = "[a-zA-Z0-9:\\-\\._$]*";

pub fn provideLinkedEditingRange(
    l_srv: *ls.LanguageService,
    allocator: std.mem.Allocator,
    params: *const lsproto.LinkedEditingRangeParams,
) !?lsproto.LinkedEditingRanges {
    const res = l_srv.getProgramAndFile(params.textDocument.uri);
    const position = l_srv.converters.*.lineAndCharacterToPosition(res.file, params.position);
    const tree = l_srv.getAst(res.file);
    const source_file = l_srv.getSourceFileNode(res.file);

    const token = astnav.findPrecedingToken(source_file, tree, position);
    if (token == 0 or tree.getNodeParent(token) == 0 or tree.getNodeKind(tree.getNodeParent(token)) == .SourceFile) {
        return null;
    }

    const parent = tree.getNodeParent(token);
    const parent_parent = tree.getNodeParent(parent);

    if (parent_parent != 0 and tree.getNodeKind(parent_parent) == .JsxFragment) {
        const fragment = tree.getNode(parent_parent).JsxFragment;
        const openFragment = fragment.openingFragment;
        const closeFragment = fragment.closingFragment;

        if ((tree.getNodeFlags(openFragment) & ast_utils.NodeFlags.ThisNodeOrAnySubNodesHasError) != 0 or
            (tree.getNodeFlags(closeFragment) & ast_utils.NodeFlags.ThisNodeOrAnySubNodesHasError) != 0)
        {
            return null;
        }

        const openPos = astnav.getStartOfNode(openFragment, tree, source_file, false) + 1; // len("<")
        const closePos = astnav.getStartOfNode(closeFragment, tree, source_file, false) + 2; // len("</")

        if (position != openPos and position != closePos) {
            return null;
        }

        const openLineChar = l_srv.converters.*.positionToLineAndCharacter(res.file, openPos);
        const closeLineChar = l_srv.converters.*.positionToLineAndCharacter(res.file, closePos);

        const ranges = try allocator.alloc(lsproto.Range, 2);
        ranges[0] = .{ .start = openLineChar, .end = openLineChar };
        ranges[1] = .{ .start = closeLineChar, .end = closeLineChar };

        return lsproto.LinkedEditingRanges{
            .ranges = ranges,
            .wordPattern = try allocator.dupe(u8, jsxTagWordPattern),
        };
    } else {
        var tag = parent;
        while (tag != 0) {
            const kind = tree.getNodeKind(tag);
            if (kind == .JsxOpeningElement or kind == .JsxClosingElement) {
                break;
            }
            tag = tree.getNodeParent(tag);
        }
        if (tag == 0) return null;

        const tagParent = tree.getNodeParent(tag);
        if (tagParent == 0 or tree.getNodeKind(tagParent) != .JsxElement) return null;

        const jsxElement = tree.getNode(tagParent).JsxElement;
        const openTag = jsxElement.openingElement;
        const closeTag = jsxElement.closingElement;

        const openTagName = tree.getNode(openTag).JsxOpeningElement.tagName;
        const closeTagName = tree.getNode(closeTag).JsxClosingElement.tagName;

        const openTagNameStart = astnav.getStartOfNode(openTagName, tree, source_file, false);
        const openTagNameEnd = tree.getNodeEnd(openTagName);
        const closeTagNameStart = astnav.getStartOfNode(closeTagName, tree, source_file, false);
        const closeTagNameEnd = tree.getNodeEnd(closeTagName);

        const openTagStart = astnav.getStartOfNode(openTag, tree, source_file, false);
        const closeTagStart = astnav.getStartOfNode(closeTag, tree, source_file, false);

        if (openTagNameStart == openTagStart or closeTagNameStart == closeTagStart or
            openTagNameEnd == tree.getNodeEnd(openTag) or closeTagNameEnd == tree.getNodeEnd(closeTag))
        {
            return null;
        }

        if (!(openTagNameStart <= position and position <= openTagNameEnd or
            closeTagNameStart <= position and position <= closeTagNameEnd))
        {
            return null;
        }

        const openingTagText = ast_utils.getTextOfNode(tree, openTagName);
        const closingTagText = ast_utils.getTextOfNode(tree, closeTagName);

        if (!std.mem.eql(u8, openingTagText, closingTagText)) {
            return null;
        }

        const ranges = try allocator.alloc(lsproto.Range, 2);
        ranges[0] = l_srv.converters.*.createLspRangeFromBounds(res.file, openTagNameStart, openTagNameEnd);
        ranges[1] = l_srv.converters.*.createLspRangeFromBounds(res.file, closeTagNameStart, closeTagNameEnd);

        return lsproto.LinkedEditingRanges{
            .ranges = ranges,
            .wordPattern = try allocator.dupe(u8, jsxTagWordPattern),
        };
    }
}
