const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");

pub fn provideDocumentSemanticTokens(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.SemanticTokensParams,
) !?lsproto.SemanticTokens {
    const programAndFile = ls.getProgramAndFile(params.textDocument.uri);
    const file = programAndFile.file;

    const tree = ls.getAst(file);
    const sourceFileNode = tree.getNode(ls.getSourceFileNode(file)).SourceFile;

    // TODO: implement semantic tokens visitor
    _ = sourceFileNode;
    _ = allocator;

    // stub implementation
    return null;
}
