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

    const programAndFile = ls.tryGetProgramAndFile(documentURI);
    const program = programAndFile.program;
    const file = programAndFile.file;

    const pos = ls.converters.lineAndCharacterToPosition(file, position);

    const astnav = @import("../astnav/tokens.zig");
    const node = astnav.getTouchingPropertyName(file, &program.ast, pos);

    if (program.ast.getNodeKind(node) == .SourceFile) {
        return lsproto.DefinitionResponse{ .LocationOrLocationsOrDefinitionLinksOrNull = .{ .locations = null } };
    }

    _ = clientSupportsLink; // stub handling link output for now

    var chk = program.getTypeCheckerForFile(file);
    const symbolIndex = chk.getSymbolAtLocation(node);

    if (symbolIndex != 0) {
        const symbol = chk.binder.symbols.items[symbolIndex];

        var locations = std.ArrayList(lsproto.Location).init(ls.allocator);
        const findallreferences = @import("findallreferences.zig");
        const lsconv = @import("lsconv/converters.zig");

        for (symbol.Declarations.items) |declNode| {
            const declFile = ast_utils.getSourceFileOfNode(&program.ast, declNode);
            const declFileNode = program.ast.getNode(declFile).SourceFile;

            const range = findallreferences.getLspRangeOfNode(ls, declNode, declFile, 0);

            const uri = try lsconv.fileNameToDocumentURI(ls.allocator, declFileNode.fileName);
            try locations.append(lsproto.Location{
                .uri = uri,
                .range = range,
            });
        }

        if (locations.items.len > 0) {
            return lsproto.DefinitionResponse{ .LocationOrLocationsOrDefinitionLinksOrNull = .{ .locations = try locations.toOwnedSlice() } };
        }
    }

    return lsproto.DefinitionResponse{ .LocationOrLocationsOrDefinitionLinksOrNull = .{ .locations = null } };
}
