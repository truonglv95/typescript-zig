const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");

pub fn provideFoldingRanges(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    documentURI: lsproto.DocumentUri,
) !?[]lsproto.FoldingRange {
    const programAndFile = ls.getProgramAndFile(documentURI);
    const file = programAndFile.file;

    var ranges = std.ArrayList(lsproto.FoldingRange).init(allocator);
    errdefer ranges.deinit();

    var visitor = FoldingVisitor{
        .ls = ls,
        .file = file,
        .tree = ls.getAst(file),
        .ranges = &ranges,
    };
    try visitor.visit(ls.getSourceFileNode(file));

    if (ranges.items.len == 0) return null;
    return try ranges.toOwnedSlice();
}

const FoldingVisitor = struct {
    ls: *languageservice.LanguageService,
    file: compiler.FileId,
    tree: *ast.Ast,
    ranges: *std.ArrayList(lsproto.FoldingRange),

    pub fn visit(self: *@This(), node: ast.NodeIndex) std.mem.Allocator.Error!void {
        if (node == ast.null_node) return;

        const kind = self.tree.getNodeKind(node);
        if (kind == .Block or kind == .ModuleBlock or kind == .ClassDeclaration or kind == .InterfaceDeclaration) {
            const lspRange = @import("findallreferences.zig").getLspRangeOfNode(self.ls, self.file, node, null, 0);
            if (lspRange.start.line < lspRange.end.line) {
                try self.ranges.append(.{
                    .startLine = lspRange.start.line,
                    .startCharacter = lspRange.start.character,
                    .endLine = lspRange.end.line,
                    .endCharacter = lspRange.end.character,
                    .kind = "region",
                });
            }
        }

        try ast_utils.forEachChild(self.tree, node, self);
    }
};
