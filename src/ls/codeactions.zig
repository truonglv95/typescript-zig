const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const diagnostics = @import("diagnostics.zig");
const organizeimports = @import("organizeimports.zig");

pub const CodeFixContext = struct {
    sourceFile: ast.NodeIndex,
    span: ast.TextRange,
    errorCode: u32,
    program: *compiler.Program,
    ls: *languageservice.LanguageService,
    diagnostic: *const lsproto.Diagnostic,
    params: *const lsproto.CodeActionParams,
};

pub const CodeAction = struct {
    description: []const u8,
    changes: []const lsproto.TextEdit,
    fixID: []const u8 = "",
    fixAllDescription: []const u8 = "",

    pub fn compare(a: CodeAction, b: CodeAction) std.math.Order {
        const order = std.mem.order(u8, a.description, b.description);
        if (order != .eq) return order;
        if (a.changes.len < b.changes.len) return .lt;
        if (a.changes.len > b.changes.len) return .gt;
        return .eq;
    }
};

pub const CombinedCodeActions = struct {
    description: []const u8,
    changes: []const lsproto.TextEdit,
};

pub const CodeFixProvider = struct {
    errorCodes: []const u32,
    getCodeActions: *const fn (allocator: std.mem.Allocator, fixContext: *CodeFixContext) anyerror![]const CodeAction,
    fixIds: []const []const u8,
    getAllCodeActions: ?*const fn (allocator: std.mem.Allocator, fixContext: *CodeFixContext) anyerror!?CombinedCodeActions,
};

const codeFixProviders = [_]CodeFixProvider{
    // stub providers until implemented
};

pub fn getCodeActions(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.CodeActionParams,
) !?[]lsproto.CommandOrCodeAction {
    const programAndFile = ls.getProgramAndFile(params.textDocument.uri);
    const file = programAndFile.file;
    const program = ls.getProgram(file) orelse return null;

    var actions = std.ArrayList(lsproto.CommandOrCodeAction).init(allocator);
    errdefer actions.deinit();

    if (params.context) |ctx| {
        if (ctx.only) |only| {
            for (only) |kind| {
                if (std.mem.startsWith(u8, kind, "source.organizeImports") or
                    std.mem.startsWith(u8, kind, "source.removeUnusedImports") or
                    std.mem.startsWith(u8, kind, "source.sortImports"))
                {
                    var orgActionParams = params.*;
                    const orgActions = try organizeimports.organizeImports(ls, allocator, &orgActionParams);
                    if (orgActions) |oa| {
                        for (oa) |act| {
                            try actions.append(.{ .codeAction = act });
                        }
                    }
                }

                if (isFixAllKind(kind)) {
                    if (try createFixAllAction(ls, allocator, program, file, params.textDocument.uri)) |fixAllAction| {
                        try actions.append(fixAllAction);
                    }
                }
            }
        }

        if (ctx.diagnostics.len > 0 and wantsQuickFixes(ctx.only)) {
            var fixIdSeen = std.StringHashMap(*const CodeFixProvider).init(allocator);
            defer fixIdSeen.deinit();

            var seen = std.ArrayList(CodeAction).init(allocator);
            defer seen.deinit();

            for (ctx.diagnostics) |*diag| {
                if (diag.code == null) continue;

                const errorCodeStr = switch (diag.code.?) {
                    .integer => |i| i,
                    .string => continue,
                };
                const errorCode: u32 = @intCast(errorCodeStr);

                for (&codeFixProviders) |*provider| {
                    if (!containsErrorCode(provider.errorCodes, errorCode)) continue;

                    const script = ls.getScript(file);
                    const position = ls.converters.lineAndCharacterToPosition(script, diag.range.start);
                    const endPosition = ls.converters.lineAndCharacterToPosition(script, diag.range.end);

                    var fixContext = CodeFixContext{
                        .sourceFile = file,
                        .span = .{ .pos = position, .end = endPosition },
                        .errorCode = errorCode,
                        .program = program,
                        .ls = ls,
                        .diagnostic = diag,
                        .params = params,
                    };

                    const providerActions = try provider.getCodeActions(allocator, &fixContext);
                    for (providerActions) |action| {
                        var found = false;
                        for (seen.items) |s| {
                            if (CodeAction.compare(s, action) == .eq) {
                                found = true;
                                break;
                            }
                        }
                        if (found) continue;
                        try seen.append(action);

                        const lspAction = try convertToLSPCodeAction(allocator, action, diag, params.textDocument.uri);
                        try actions.append(lspAction);

                        if (action.fixID.len > 0) {
                            try fixIdSeen.put(action.fixID, provider);
                        }
                    }
                }
            }

            const fixAllActions = try getFixAllQuickFixes(ls, allocator, program, file, params.textDocument.uri, &fixIdSeen);
            if (fixAllActions) |faa| {
                for (faa) |act| {
                    try actions.append(act);
                }
            }
        }
    }

    if (actions.items.len == 0) return null;
    return actions.toOwnedSlice();
}

fn getFixAllQuickFixes(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    program: *compiler.Program,
    file: ast.NodeIndex,
    uri: lsproto.DocumentUri,
    fixIdSeen: *std.StringHashMap(*const CodeFixProvider),
) !?[]lsproto.CommandOrCodeAction {
    var actions = std.ArrayList(lsproto.CommandOrCodeAction).init(allocator);
    errdefer actions.deinit();

    var seen = std.AutoHashMap(*const CodeFixProvider, void).init(allocator);
    defer seen.deinit();

    var it = fixIdSeen.iterator();
    while (it.next()) |entry| {
        const provider = entry.value_ptr.*;
        if (seen.contains(provider)) continue;
        try seen.put(provider, {});

        if (provider.getAllCodeActions == null) continue;

        if (!(try hasMultipleFixableDiagnostics(allocator, program, file, provider.errorCodes))) continue;

        var fixContext = CodeFixContext{
            .sourceFile = file,
            .span = .{ .pos = 0, .end = 0 },
            .errorCode = 0,
            .program = program,
            .ls = ls,
            .diagnostic = undefined,
            .params = undefined,
        };

        if (try provider.getAllCodeActions.?(allocator, &fixContext)) |combined| {
            if (combined.changes.len > 0) {
                var changes = std.StringHashMap([]lsproto.TextEdit).init(allocator);
                try changes.put(uri.fileName(), @constCast(combined.changes));
                try actions.append(.{ .codeAction = .{
                    .title = combined.description,
                    .kind = "quickfix",
                    .edit = .{ .changes = changes },
                } });
            }
        }
    }

    if (actions.items.len == 0) return null;
    return actions.toOwnedSlice();
}

fn hasMultipleFixableDiagnostics(allocator: std.mem.Allocator, program: *compiler.Program, file: ast.NodeIndex, errorCodes: []const u32) !bool {
    const allDiags = try diagnostics.getAllDiagnostics(allocator, program, file);
    defer allocator.free(allDiags);
    var count: usize = 0;
    for (allDiags) |d| {
        if (containsErrorCode(errorCodes, d.message.code)) {
            count += 1;
            if (count >= 2) return true;
        }
    }
    return false;
}

fn codeActionKindContains(requestedKind: []const u8, actionKind: []const u8) bool {
    if (std.mem.eql(u8, requestedKind, actionKind)) return true;
    if (requestedKind.len == 0) return true;
    if (std.mem.startsWith(u8, actionKind, requestedKind)) {
        if (actionKind.len > requestedKind.len and actionKind[requestedKind.len] == '.') {
            return true;
        }
    }
    return false;
}

fn isFixAllKind(kind: []const u8) bool {
    return codeActionKindContains(kind, "source.fixAll");
}

fn wantsQuickFixes(only: ?[][]const u8) bool {
    if (only == null or only.?.len == 0) return true;
    for (only.?) |kind| {
        if (codeActionKindContains(kind, "quickfix")) return true;
    }
    return false;
}

fn createFixAllAction(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    program: *compiler.Program,
    file: ast.NodeIndex,
    uri: lsproto.DocumentUri,
) !?lsproto.CommandOrCodeAction {
    var lspChanges = std.ArrayList(lsproto.TextEdit).init(allocator);
    defer lspChanges.deinit();

    for (&codeFixProviders) |*provider| {
        if (provider.getAllCodeActions == null) continue;

        var fixContext = CodeFixContext{
            .sourceFile = file,
            .span = .{ .pos = 0, .end = 0 },
            .errorCode = 0,
            .program = program,
            .ls = ls,
            .diagnostic = undefined,
            .params = undefined,
        };

        if (try provider.getAllCodeActions.?(allocator, &fixContext)) |combined| {
            if (combined.changes.len > 0) {
                try lspChanges.appendSlice(combined.changes);
            }
        }
    }

    if (lspChanges.items.len == 0) return null;

    var changesMap = std.StringHashMap([]lsproto.TextEdit).init(allocator);
    try changesMap.put(uri.fileName(), try lspChanges.toOwnedSlice());

    return .{ .codeAction = .{
        .title = "Fix all auto-fixable problems",
        .kind = "source.fixAll",
        .edit = .{ .changes = changesMap },
    } };
}

fn containsErrorCode(codes: []const u32, code: u32) bool {
    for (codes) |c| {
        if (c == code) return true;
    }
    return false;
}

fn convertToLSPCodeAction(allocator: std.mem.Allocator, action: CodeAction, diag: *const lsproto.Diagnostic, uri: lsproto.DocumentUri) !lsproto.CommandOrCodeAction {
    _ = diag;
    var changes = std.StringHashMap([]lsproto.TextEdit).init(allocator);
    try changes.put(uri.fileName(), @constCast(action.changes));
    return .{ .codeAction = .{
        .title = action.description,
        .kind = "quickfix",
        .edit = .{ .changes = changes },
    } };
}
