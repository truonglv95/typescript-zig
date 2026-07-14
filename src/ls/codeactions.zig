const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");

pub fn getCodeActions(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.CodeActionParams,
) !?[]lsproto.CodeAction {
    const programAndFile = ls.getProgramAndFile(params.textDocument.uri);
    const file = programAndFile.file;

    const script = ls.getScript(file);
    const position = ls.converters.lineAndCharacterToPosition(script, params.range.start);
    const endPosition = ls.converters.lineAndCharacterToPosition(script, params.range.end);

    // We get the AST
    const tree = ls.getAst(file);

    // TODO: loop over diagnostics and generate appropriate code actions

    _ = allocator;
    _ = position;
    _ = endPosition;
    _ = tree;

    // stub implementation
    return null;
}
