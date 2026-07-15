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
    const caps = lsproto.getClientCapabilities();
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

    const program = ls.getProgram();
    const reference = findallreferences.getReferenceAtPosition(ls, initialNode, pos, program);
    if (reference.file != 0) {
        const empty_decls = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        return try createDefinitionLocations(ls, tree, file, originSelectionRange, clientSupportsLink, empty_decls.items);
    }

    const chk = ls.getTypeCheckerForFile(file);

    if (tree.getNodeKind(initialNode) == .OverrideKeyword) {
        if (getSymbolForOverriddenMember(chk, initialNode)) |symIndex| {
            const sym = chk.binder.symbols.items[symIndex];
            return try createDefinitionLocations(ls, tree, file, originSelectionRange, clientSupportsLink, sym.Declarations.items);
        }
    }

    if (findallreferences.isJumpStatementTarget(tree, initialNode)) {
        const parent = tree.getNodeParent(initialNode);
        const text = ast_utils.getTextOfNode(tree, initialNode);
        const label = findallreferences.getTargetLabel(tree, parent, text);
        if (label != 0) {
            var label_arr = [_]ast.NodeIndex{label};
            return try createDefinitionLocations(ls, tree, file, originSelectionRange, clientSupportsLink, &label_arr);
        }
    }

    if (tree.getNodeKind(initialNode) == .CaseKeyword or (tree.getNodeKind(initialNode) == .DefaultKeyword and tree.getNodeKind(tree.getNodeParent(initialNode)) == .DefaultClause)) {
        const stmt = ast_utils.findAncestorKind(tree, tree.getNodeParent(initialNode), .SwitchStatement);
        if (stmt != 0) {
            const stmtFile = ast_utils.getSourceFileOfNode(tree, stmt);
            const scanner = @import("../scanner/scanner.zig");
            const range = scanner.getRangeOfTokenAtPosition(tree.sourceText, tree.positions.items[stmt].pos);
            var locations = std.ArrayListUnmanaged(lsproto.Location).empty;
            const uri = try lsconv.fileNameToDocumentURI(ls.allocator, tree.fileName);
            const startPos = ls.converters.*.positionToLineAndCharacter(ls.getScript(stmtFile), range.pos);
            const endPos = ls.converters.*.positionToLineAndCharacter(ls.getScript(stmtFile), range.end);
            try locations.append(ls.allocator, lsproto.Location{ .uri = uri, .range = .{ .start = startPos, .end = endPos } });
            return lsproto.DefinitionResponse{ .LocationOrLocationsOrDefinitionLinksOrNull = .{ .locations = try locations.toOwnedSlice(ls.allocator) } };
        }
    }

    if (tree.getNodeKind(initialNode) == .ReturnKeyword or tree.getNodeKind(initialNode) == .YieldKeyword or tree.getNodeKind(initialNode) == .AwaitKeyword) {
        const fnNode = ast_utils.findAncestor(tree, initialNode, ast_utils.isFunctionLikeDeclaration);
        if (fnNode != 0) {
            var fn_arr = [_]ast.NodeIndex{fnNode};
            return try createDefinitionLocations(ls, tree, file, originSelectionRange, clientSupportsLink, &fn_arr);
        }
    }

    const node = getDeclarationNameForKeyword(tree, initialNode);

    var declarations = std.ArrayListUnmanaged(ast.NodeIndex).empty;
    defer declarations.deinit(ls.allocator);

    const symbolIndex = checker.getSymbolAtLocation(chk, node);
    if (symbolIndex != 0) {
        const symbol = chk.binder.symbols.items[symbolIndex];



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
    const caps = lsproto.getClientCapabilities();
    const clientSupportsLink = caps.textDocument.typeDefinition.linkSupport;

    const programAndFile = ls.tryGetProgramAndFile(documentURI.fileName()) orelse return lsproto.TypeDefinitionResponse{ .LocationOrLocationsOrDefinitionLinksOrNull = .{ .locations = null } };
    _ = programAndFile.program;
    const file = programAndFile.file;
    const tree = ls.getAst(file);

    const pos = ls.converters.*.lineAndCharacterToPosition(ls.getScript(file), position);
    const initialNode = astnav.getTouchingPropertyName(file, tree, pos);
    const chk = programAndFile.program.getTypeCheckerForFile(file);

    if (tree.getNodeKind(initialNode) == .SourceFile) {
        return lsproto.TypeDefinitionResponse{ .LocationOrLocationsOrDefinitionLinksOrNull = .{ .locations = null } };
    }

    const originSelectionRange = @import("findallreferences.zig").getLspRangeOfNode(ls, file, initialNode, null, 0);

    const node = getDeclarationNameForKeyword(tree, initialNode);
    const symbolIndex = checker.getSymbolAtLocation(chk, node);

    var declarations = std.ArrayListUnmanaged(ast.NodeIndex).empty;
    defer declarations.deinit(ls.allocator);

    if (symbolIndex != 0) {
        const symbol = chk.binder.symbols.items[symbolIndex];
        const symbolType = chk.getTypeOfSymbolAtLocation(symbolIndex, node);

        try getDeclarationsFromType(chk, symbolType, &declarations);

        const checker_services = @import("../checker/services.zig");
        const typeArg = checker_services.getFirstTypeArgumentFromKnownType(chk, @ptrFromInt(symbolType));
        if (@intFromPtr(typeArg) != 0) {
            try getDeclarationsFromType(chk, @intCast(@intFromPtr(typeArg)), &declarations);
        }

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

fn getDeclarationsFromType(chk: *checker.Checker, t: checker.types.TypeIndex, declarations: *std.ArrayListUnmanaged(ast.NodeIndex)) !void {
    const distTypes = chk.distributedTypes(t);
    for (distTypes) |distTypeIndex| {
        const distType = chk.typesList.items[distTypeIndex];
        if (distType.symbol) |symbolIndex| {
            if (symbolIndex != 0) {
                const sym = chk.binder.symbols.items[symbolIndex];
                for (sym.Declarations.items) |decl| {
                    var found = false;
                    for (declarations.items) |existing| {
                        if (existing == decl) {
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        try declarations.append(chk.allocator, decl);
                    }
                }
            }
        }
    }
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

fn getSymbolForOverriddenMember(chk: *checker.Checker, node: ast.NodeIndex) ?u32 {
    const classElement = ast_utils.findAncestor(chk.binder.ast, node, ast_utils.isClassElement);
    if (classElement == 0) return null;
    const nameNode = ast_utils.getNameOfNode(chk.binder.ast, classElement);
    if (nameNode == 0) return null;

    const baseDeclaration = ast_utils.findAncestor(chk.binder.ast, classElement, ast_utils.isClassLike);
    if (baseDeclaration == 0) return null;

    const baseTypeNode = ast_utils.getClassExtendsHeritageElement(chk.binder.ast, baseDeclaration);
    if (baseTypeNode == 0) return null;

    const expr = ast_utils.skipParentheses(chk.binder.ast, chk.binder.ast.getNode(baseTypeNode).ExpressionWithTypeArguments.Expression);
    
    var baseSymbol: u32 = 0;
    if (chk.binder.ast.getNodeKind(expr) == .ClassExpression) {
        if (chk.binder.ast.symbols.items.len > expr) {
            baseSymbol = @intCast(expr); // Approximation for class expression symbol
        }
    } else {
        baseSymbol = checker.getSymbolAtLocation(chk, expr);
    }
    if (baseSymbol == 0) return null;

    const nameText = ast_utils.getTextOfNode(chk.binder.ast, nameNode);
    if (ast_utils.hasStaticModifier(chk.binder.ast, classElement)) {
        return chk.getPropertyOfType(chk.getTypeOfSymbol(baseSymbol) catch 0, nameText);
    }
    return chk.getPropertyOfType(chk.getDeclaredTypeOfSymbol(baseSymbol), nameText);
}
