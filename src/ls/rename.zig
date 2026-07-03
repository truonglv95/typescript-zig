const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");

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
        for (s.references) |_| {
            // stub URI mapping
            const uri = "";
            var listResult = try changes.getOrPut(uri);
            if (!listResult.found_existing) {
                listResult.value_ptr.* = std.ArrayList(lsproto.TextEdit).init(allocator);
            }
            try listResult.value_ptr.append(lsproto.TextEdit{
                .range = lsproto.Range{ .start = .{ .line = 0, .character = 0 }, .end = .{ .line = 0, .character = 0 } },
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
    _ = ls;
    _ = allocator;
    _ = newName;

    const chk = program.getTypeCheckerForFile(sourceFile);
    const symbolIndex = chk.getSymbolAtLocation(node);
    if (symbolIndex == 0) {
        if (ast_utils.isStringLiteralLike(&program.ast, node)) {
            // Contextual string literal types check stub
            return RenameInfo{
                .canRename = true,
                .localizedErrorMessage = null,
                .displayName = "",
                .triggerSpan = lsproto.Range{ .start = .{ .line = 0, .character = 0 }, .end = .{ .line = 0, .character = 0 } },
                .fileToRename = null,
                .newFileName = null,
            };
        } else if (program.ast.getNodeKind(node) == .Identifier) {
            return RenameInfo{
                .canRename = true,
                .localizedErrorMessage = null,
                .displayName = "",
                .triggerSpan = lsproto.Range{ .start = .{ .line = 0, .character = 0 }, .end = .{ .line = 0, .character = 0 } },
                .fileToRename = null,
                .newFileName = null,
            };
        }
        return null;
    }

    const symbol = chk.binder.symbols.items[symbolIndex];
    if (symbol.Declarations.items.len == 0) return null;

    const displayName = if (symbol.escapedName < chk.binder.identifiers.items.len)
        chk.binder.identifiers.items[symbol.escapedName]
    else
        "";

    return RenameInfo{
        .canRename = true,
        .localizedErrorMessage = null,
        .displayName = displayName,
        .triggerSpan = lsproto.Range{ .start = .{ .line = 0, .character = 0 }, .end = .{ .line = 0, .character = 0 } },
        .fileToRename = null,
        .newFileName = null,
    };
}
