const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");

pub fn provideDefinition(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    documentURI: lsproto.DocumentUri,
    position: lsproto.Position,
) !lsproto.DefinitionResponse {
    _ = allocator;
    if (ls.userPreferences().preferGoToSourceDefinition) {
        // return provideSourceDefinition(ls, documentURI, position);
    }
    return try provideDefinitionWorker(ls, documentURI, position);
}

pub fn provideDefinitionWorker(
    ls: *languageservice.LanguageService,
    documentURI: lsproto.DocumentUri,
    position: lsproto.Position,
) !lsproto.DefinitionResponse {
    const caps = lsproto.getClientCapabilities(); // stub
    const clientSupportsLink = caps.textDocument.definition.linkSupport;

    const programAndFile = ls.getProgramAndFile(documentURI);
    const program = programAndFile.program;
    const file = programAndFile.file;

    const pos = ls.converters.lineAndCharacterToPosition(file, position);
    const node = ast_utils.getTouchingPropertyName(&program.ast, file, pos);
    
    // stub
    _ = clientSupportsLink; _ = node;
    
    return lsproto.DefinitionResponse{ .LocationOrLocationsOrDefinitionLinksOrNull = .{ .locations = null } };
}
