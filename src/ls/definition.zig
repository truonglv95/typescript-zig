const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const astnav = @import("../astnav/tokens.zig");
const findallreferences = @import("findallreferences.zig");
const lsconv = @import("lsconv/converters.zig");

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

    const programAndFile = ls.tryGetProgramAndFile(documentURI.fileName()) orelse return lsproto.DefinitionResponse{ .LocationOrLocationsOrDefinitionLinksOrNull = .{ .locations = null } };
    _ = programAndFile.program;
    const file = programAndFile.file;
    const tree = ls.getAst(file);

    const pos = ls.converters.*.lineAndCharacterToPosition(ls.getScript(file), position);
    const initialNode = astnav.getTouchingPropertyName(file, tree, pos);

    if (tree.getNodeKind(initialNode) == .SourceFile) {
        return lsproto.DefinitionResponse{ .LocationOrLocationsOrDefinitionLinksOrNull = .{ .locations = null } };
    }

    const originSelectionRange = @import("findallreferences.zig").getLspRangeOfNode(ls, file, initialNode, null, 0);

    // TODO: getReferenceAtPosition, getSymbolForOverriddenMember, isJumpStatementTarget, etc.

    const chk = ls.getTypeCheckerForFile(file);
    const node = getDeclarationNameForKeyword(tree, initialNode);

    var declarations = std.ArrayListUnmanaged(ast.NodeIndex).empty;
    defer declarations.deinit(ls.allocator);

    const symbolIndex = checker.getSymbolAtLocation(chk, node);
    if (symbolIndex != 0) {
        const symbol = chk.binder.symbols.items[symbolIndex];

        // TODO: getDeclarationsFromObjectLiteralElement

        for (symbol.Declarations.items) |declNode| {
            try declarations.append(ls.allocator, declNode);
        }
    }

    return try createDefinitionLocations(ls, chk.binder.ast, file, originSelectionRange, clientSupportsLink, declarations.items);
}

pub fn provideTypeDefinition(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    documentURI: lsproto.DocumentUri,
    position: lsproto.Position,
) !lsproto.TypeDefinitionResponse {
    _ = allocator;
    const caps = lsproto.getClientCapabilities(); // stub
    const clientSupportsLink = caps.textDocument.typeDefinition.linkSupport;

    const programAndFile = ls.tryGetProgramAndFile(documentURI.fileName()) orelse return lsproto.TypeDefinitionResponse{ .LocationOrLocationsOrDefinitionLinksOrNull = .{ .locations = null } };
    _ = programAndFile.program;
    const file = programAndFile.file;
    const tree = ls.getAst(file);

    const pos = ls.converters.*.lineAndCharacterToPosition(ls.getScript(file), position);
    const initialNode = astnav.getTouchingPropertyName(file, tree, pos);

    if (tree.getNodeKind(initialNode) == .SourceFile) {
        return lsproto.TypeDefinitionResponse{ .LocationOrLocationsOrDefinitionLinksOrNull = .{ .locations = null } };
    }

    const originSelectionRange = @import("findallreferences.zig").getLspRangeOfNode(ls, file, initialNode, null, 0);
    const chk = ls.getTypeCheckerForFile(file);

    const node = getDeclarationNameForKeyword(tree, initialNode);
    const symbolIndex = checker.getSymbolAtLocation(chk, node);

    var declarations = std.ArrayListUnmanaged(ast.NodeIndex).empty;
    defer declarations.deinit(ls.allocator);

    if (symbolIndex != 0) {
        const symbol = chk.binder.symbols.items[symbolIndex];
        const symbolType = chk.getTypeOfSymbolAtLocation(symbolIndex, node);

        try getDeclarationsFromType(chk, symbolType, &declarations);

        // TODO: GetFirstTypeArgumentFromKnownType

        if (declarations.items.len == 0) {
            if ((symbol.Flags & ast.SymbolFlags.Value) == 0 and (symbol.Flags & ast.SymbolFlags.Type) != 0) {
                for (symbol.Declarations.items) |declNode| {
                    try declarations.append(ls.allocator, declNode);
                }
            }
        }
    }

    return try createDefinitionLocations(ls, chk.binder.ast, file, originSelectionRange, clientSupportsLink, declarations.items);
}

fn getDeclarationNameForKeyword(tree: *ast.Ast, node: ast.NodeIndex) ast.NodeIndex {
    const kind = tree.getNodeKind(node);
    switch (kind) {
        .VarKeyword, .LetKeyword, .ConstKeyword, .FunctionKeyword, .ClassKeyword, .InterfaceKeyword, .TypeKeyword, .EnumKeyword, .ModuleKeyword, .NamespaceKeyword, .VoidKeyword, .YieldKeyword => {
            const parent = tree.getNodeParent(node);
            if (tree.getNodeKind(parent) == .VariableDeclarationList) {
                const list = tree.getNode(parent).VariableDeclarationList.Declarations;
                if (tree.getNodeList(list).len > 0) {
                    const firstDecl = tree.getNodeList(list)[0];
                    const declNode = tree.getNode(firstDecl).VariableDeclaration;
                    if (declNode.name != 0) {
                        return declNode.name;
                    }
                }
            } else {
                const name = ast_utils.getNameOfNode(tree, parent);
                if (name != 0) {
                    return name;
                }
            }
        },
        else => {},
    }
    return node;
}

fn getDeclarationsFromType(chk: *checker.Checker, t: *checker.Type, declarations: *std.ArrayList(ast.NodeIndex)) !void {
    _ = chk;
    _ = t;
    _ = declarations;
    // Stub
}

fn createDefinitionLocations(
    ls: *languageservice.LanguageService,
    tree: *ast.Ast,
    file: compiler.FileId,
    originSelectionRange: lsproto.Range,
    clientSupportsLink: bool,
    declarations: []const ast.NodeIndex,
) !lsproto.DefinitionResponse {
    _ = originSelectionRange; // currently unused
    _ = clientSupportsLink; // currently unused

    var locations = std.ArrayListUnmanaged(lsproto.Location).empty;
    defer locations.deinit(ls.allocator);

    for (declarations) |declNode| {
        // Since Checker is currently per-file, all declarations belong to the same file
        var nameRange = std.mem.zeroes(ast.TextRange);
        const name = ast_utils.getNameOfNode(tree, declNode);
        if (name != 0) {
            if (tree.getNodeKind(name) == .EmptyStatement) {
                nameRange = .{ .pos = tree.positions.items[name].pos, .end = tree.positions.items[name].pos };
            } else {
                nameRange = tree.positions.items[name];
            }
        } else {
            nameRange = tree.positions.items[declNode];
        }

        const uri = try lsconv.fileNameToDocumentURI(ls.allocator, tree.fileName);

        // This is simplified. True link support requires LocationLink.
        const startPos = ls.converters.*.positionToLineAndCharacter(ls.getScript(file), nameRange.pos);
        const endPos = ls.converters.*.positionToLineAndCharacter(ls.getScript(file), nameRange.end);

        try locations.append(ls.allocator, lsproto.Location{
            .uri = uri,
            .range = .{
                .start = startPos,
                .end = endPos,
            },
        });
    }

    if (locations.items.len > 0) {
        return lsproto.DefinitionResponse{ .LocationOrLocationsOrDefinitionLinksOrNull = .{ .locations = try locations.toOwnedSlice(ls.allocator) } };
    }

    return lsproto.DefinitionResponse{ .LocationOrLocationsOrDefinitionLinksOrNull = .{ .locations = null } };
}
