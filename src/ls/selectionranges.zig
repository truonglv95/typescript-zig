const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");

pub fn provideSelectionRanges(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.SelectionRangeParams,
) !?[]lsproto.SelectionRange {
    const programAndFile = ls.getProgramAndFile(params.textDocument.uri);
    const file = programAndFile.file;

    var results = std.ArrayList(lsproto.SelectionRange).init(allocator);
    errdefer results.deinit();

    const astnav = @import("../astnav/tokens.zig");
    const findallreferences = @import("findallreferences.zig");

    for (params.positions) |position| {
        const script = ls.getScript(file);
        const pos = ls.converters.lineAndCharacterToPosition(script, position);
        const tree = ls.getAst(file);
        var node = astnav.getTouchingPropertyName(tree.getNode(ls.getSourceFileNode(file)).SourceFile, tree, pos);

        var leaf: ?*lsproto.SelectionRange = null;
        var current_range: ?*lsproto.SelectionRange = null;

        while (node != ast.null_node) {
            const range = findallreferences.getLspRangeOfNode(ls, file, node, null, 0);

            // Only add if range is different from previous
            const isDifferent = if (current_range) |cr|
                (cr.range.start.line != range.start.line or
                    cr.range.start.character != range.start.character or
                    cr.range.end.line != range.end.line or
                    cr.range.end.character != range.end.character)
            else
                true;

            if (isDifferent) {
                const sr = try allocator.create(lsproto.SelectionRange);
                sr.* = .{ .range = range, .parent = null };
                if (current_range) |cr| {
                    cr.parent = sr;
                } else {
                    leaf = sr;
                }
                current_range = sr;
            }
            node = tree.getNodeParent(node);
        }

        if (leaf) |l| {
            try results.append(l.*);
        }
    }

    if (results.items.len == 0) return null;
    return try results.toOwnedSlice();
}
