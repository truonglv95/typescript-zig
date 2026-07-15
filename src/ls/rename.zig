const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const types = @import("../checker/types.zig");

const findallreferences = @import("findallreferences.zig");

pub const RenameInfo = struct {
    canRename: bool,
    localizedErrorMessage: ?[]const u8,
    displayName: []const u8,
    triggerSpan: lsproto.Range,
    fileToRename: ?[]const u8,
    newFileName: ?[]const u8,
};

pub fn provideRenameEdits(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.RenameParams,
) !?lsproto.WorkspaceEdit {
    const data_opt = try findallreferences.provideSymbolsAndEntries(ls, allocator, params.textDocument.uri, params.position, true, false);
    if (data_opt == null) return null;
    return try symbolAndEntriesToRename(ls, allocator, params, data_opt.?);
}

pub fn symbolAndEntriesToRename(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.RenameParams,
    data: findallreferences.SymbolAndEntriesData,
) !?lsproto.WorkspaceEdit {
    if (!findallreferences.nodeIsEligibleForRename(ls, data.originalNode)) {
        return null;
    }

    const program = ls.getProgram();
    const sourceFile = ast_utils.getSourceFileOfNode(&program.ast, data.originalNode);
    if (try getRenameInfoForNode(ls, allocator, params.newName, data.originalNode, sourceFile, program)) |info| {
        if (!info.canRename) return null;
    } else {
        return null;
    }

    var changes = std.StringHashMap(std.ArrayList(lsproto.TextEdit)).init(allocator);
    errdefer {
        var it = changes.valueIterator();
        while (it.next()) |list| list.deinit();
        changes.deinit();
    }

    const chk = program.getTypeCheckerForFile(sourceFile);
    _ = chk;

    for (data.symbolsAndEntries) |s| {
        for (s.references) |ref| {
            const uri = findallreferences.getFileNameOfEntry(ls, ref);
            var listResult = try changes.getOrPut(uri);
            if (!listResult.found_existing) {
                listResult.value_ptr.* = std.ArrayList(lsproto.TextEdit).init(allocator);
            }
            try listResult.value_ptr.append(lsproto.TextEdit{
                .range = findallreferences.getRangeOfEntry(ls, ref),
                .newText = params.newName,
            });
        }
    }

    // Allocate the final map
    var finalChanges = std.StringHashMap([]lsproto.TextEdit).init(allocator);
    var it = changes.iterator();
    while (it.next()) |entry| {
        try finalChanges.put(entry.key_ptr.*, try entry.value_ptr.toOwnedSlice());
    }

    return lsproto.WorkspaceEdit{ .changes = finalChanges };
}

pub fn getRenameInfoForNode(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    newName: []const u8,
    node: ast.NodeIndex,
    sourceFile: ast.NodeIndex,
    program: *compiler.Program,
) !?RenameInfo {
    _ = newName;
    var chk = program.getTypeCheckerForFile(sourceFile);
    const symbolIndex = chk.getSymbolAtLocation(node);

    if (symbolIndex == 0) {
        if (ast_utils.isStringLiteralLike(&program.ast, node)) {
            const typ = findallreferences.getContextualTypeFromParentOrAncestorTypeNode(ls, node, &chk);
            var isValid = false;
            if (typ != 0) {
                if (types.isStringLiteral(&chk, typ)) {
                    isValid = true;
                } else if (types.isUnion(&chk, typ)) {
                    const unionTypes = types.types(&chk, typ);
                    if (unionTypes.len > 0) {
                        isValid = true;
                        for (unionTypes) |child| {
                            if (!types.isStringLiteral(&chk, child)) {
                                isValid = false;
                                break;
                            }
                        }
                    }
                }
            }
            if (isValid) {
                const text = ast_utils.getTextOfNode(&program.ast, node);
                return getRenameInfoSuccess(ls, &program.ast, node, sourceFile, text);
            }
        } else if (ast_utils.isLabelName(&program.ast, node)) {
            const name = ast_utils.getTextOfNode(&program.ast, node);
            return getRenameInfoSuccess(ls, &program.ast, node, sourceFile, name);
        }
        return null;
    }

    const symbol = chk.binder.symbols.items[symbolIndex];
    if (symbol.Declarations.items.len == 0) {
        return null;
    }

    if (try renameBlockedReason(ls, sourceFile, node, symbolIndex, &chk, program)) |msg| {
        _ = allocator;
        return RenameInfo{
            .canRename = false,
            .localizedErrorMessage = msg,
            .displayName = "",
            .triggerSpan = lsproto.Range{ .start = .{ .line = 0, .character = 0 }, .end = .{ .line = 0, .character = 0 } },
            .fileToRename = null,
            .newFileName = null,
        };
    }

    // TODO: allow rename of import path logic

    const displayName = if (symbol.escapedName < chk.binder.identifiers.items.len)
        chk.binder.identifiers.items[symbol.escapedName]
    else
        "";

    return getRenameInfoSuccess(ls, &program.ast, node, sourceFile, displayName);
}

fn getRenameInfoSuccess(
    ls: *languageservice.LanguageService,
    tree: *ast.Ast,
    node: ast.NodeIndex,
    sourceFile: ast.NodeIndex,
    displayName: []const u8,
) RenameInfo {
    const range = ast_utils.getTextRangeOfNode(tree, node);
    const startPos = ls.converters.positionToLineAndCharacter(sourceFile, range.start);
    const endPos = ls.converters.positionToLineAndCharacter(sourceFile, range.end);

    return RenameInfo{
        .canRename = true,
        .localizedErrorMessage = null,
        .displayName = displayName,
        .triggerSpan = lsproto.Range{
            .start = startPos,
            .end = endPos,
        },
        .fileToRename = null,
        .newFileName = null,
    };
}

fn renameBlockedReason(
    ls: *languageservice.LanguageService,
    sourceFile: ast.NodeIndex,
    node: ast.NodeIndex,
    symbolIndex: u32,
    chk: *checker.Checker,
    program: *compiler.Program,
) !?[]const u8 {
    _ = ls;
    _ = sourceFile;
    const symbol = chk.binder.symbols.items[symbolIndex];
    for (symbol.Declarations.items) |declNode| {
        if (isDefinedInLibraryFile(program, declNode)) {
            return "You cannot rename elements that are defined in the standard TypeScript library.";
        }
    }

    if (program.ast.getNodeKind(node) == .Identifier) {
        const text = ast_utils.getTextOfNode(&program.ast, node);
        if (std.mem.eql(u8, text, "default")) {
            if (symbol.parent != 0) {
                const parentSym = chk.binder.symbols.items[symbol.parent];
                if ((parentSym.Flags & ast.SymbolFlags.Module) != 0) {
                    return "You cannot rename this element.";
                }
            }
        }
    }

    // TODO: wouldRenameInOtherNodeModules check

    return null;
}

fn isDefinedInLibraryFile(program: *compiler.Program, declNode: ast.NodeIndex) bool {
    const declSourceFile = ast_utils.getSourceFileOfNode(&program.ast, declNode);
    if (declSourceFile != 0) {
        const sfNode = program.ast.getNode(declSourceFile).SourceFile;
        // Simple check for now
        const isLib = std.mem.indexOf(u8, sfNode.fileName, "lib.") != null and std.mem.endsWith(u8, sfNode.fileName, ".d.ts");
        return isLib;
    }
    return false;
}
