const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");

pub fn provideDocumentHighlights(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    documentURI: lsproto.DocumentUri,
    position: lsproto.Position,
) !?[]lsproto.DocumentHighlight {
    const findallreferences = @import("findallreferences.zig");
    const data_opt = try findallreferences.provideSymbolsAndEntries(ls, allocator, documentURI, position, false, false);
    if (data_opt == null) return null;
    const data = data_opt.?;

    var highlights = std.ArrayList(lsproto.DocumentHighlight).init(allocator);
    errdefer highlights.deinit();

    const lsconv = @import("lsconv/converters.zig");

    for (data.symbolsAndEntries) |s| {
        for (s.references) |ref| {
            if (ref.node != ast.null_node) {
                const refFileId = ls.program.getFileId(ref.fileName) orelse continue;

                const uri = try lsconv.fileNameToDocumentURI(allocator, ref.fileName);
                if (std.mem.eql(u8, uri, documentURI)) {
                    const range = findallreferences.getLspRangeOfNode(ls, refFileId, ref.node, null, 0);
                    try highlights.append(lsproto.DocumentHighlight{
                        .range = range,
                        .kind = .Text, // In absence of writeAccess tracking, default to Text
                    });
                }
                allocator.free(uri);
            }
        }
    }

    if (highlights.items.len == 0) return null;
    return try highlights.toOwnedSlice();
}
