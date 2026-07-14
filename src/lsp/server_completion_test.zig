const std = @import("std");
const testing = std.testing;

const bundled = @import("../bundled/bundled.zig");
const core = @import("../core.zig");
const lsconv = @import("../ls/lsconv.zig");
const lsutil = @import("../ls/lsutil.zig");
const lsp = @import("lsp.zig");
const lsproto = @import("lsproto.zig");
const lsptestutil = @import("../testutil/lsptestutil.zig");
const vfstest = @import("../vfs/vfstest.zig");

fn initCompletionClient(files: anytype, prefs: *lsutil.UserPreferences) !*lsptestutil.LSPClient {
    var fs = bundled.wrapFS(vfstest.fromMap(files, false));

    const Context = struct {
        prefs: *lsutil.UserPreferences,

        fn onServerRequest(ctx: *anyopaque, req: *lsproto.RequestMessage) ?*lsproto.ResponseMessage {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            switch (req.method) {
                .WorkspaceConfiguration => {
                    return &lsproto.ResponseMessage{
                        .id = req.id,
                        .jsonrpc = req.jsonrpc,
                        .result = &[_]*lsutil.UserPreferences{self.prefs},
                    };
                },
                .ClientRegisterCapability, .ClientUnregisterCapability => {
                    return &lsproto.ResponseMessage{
                        .id = req.id,
                        .jsonrpc = req.jsonrpc,
                        .result = lsproto.Null{},
                    };
                },
                else => return null,
            }
        }
    };

    var context_data = Context{ .prefs = prefs };

    var client = try lsptestutil.NewLSPClient(.{
        .err = std.io.null_writer,
        .cwd = "/home/projects",
        .fs = &fs,
        .default_library_path = bundled.libPath(),
    }, Context.onServerRequest);
    client.on_server_request_ctx = &context_data;

    const initMsg, _, const ok = try lsptestutil.sendRequest(client, lsproto.InitializeInfo, &lsproto.InitializeParams{
        .capabilities = &lsproto.ClientCapabilities{},
    });
    try testing.expect(ok and initMsg.asResponse().err == null);
    try lsptestutil.sendNotification(client, lsproto.InitializedInfo, &lsproto.InitializedParams{});

    return client;
}

fn completionItems(resp: lsproto.CompletionResponse) ?[]const *lsproto.CompletionItem {
    if (resp.list) |list| return list.items;
    if (resp.items) |items| return items;
    return null;
}

fn findCompletionItem(items: []const *lsproto.CompletionItem, label: []const u8) ?*lsproto.CompletionItem {
    for (items) |item| {
        if (std.mem.eql(u8, item.label, label)) {
            return item;
        }
    }
    return null;
}

test "CompletionAfterFileClose" {
    if (!bundled.embedded) return;

    var prefs = lsutil.UserPreferences{
        .includeCompletionsForModuleExports = core.TSTrue,
        .includeCompletionsForImportStatements = core.TSTrue,
    };
    var client = try initCompletionClient(.{
        .{ "/home/projects/tsconfig.json", "{\"compilerOptions\": {\"module\": \"esnext\", \"target\": \"esnext\"}}" },
        .{ "/home/projects/a.ts", "export const someVar = 10;" },
        .{ "/home/projects/b.ts", "s" },
    }, &prefs);
    defer client.close();

    const aURI = lsproto.DocumentUri("file:///home/projects/a.ts");
    const bURI = lsproto.DocumentUri("file:///home/projects/b.ts");

    try lsptestutil.sendNotification(client, lsproto.TextDocumentDidOpenInfo, &lsproto.DidOpenTextDocumentParams{
        .textDocument = &lsproto.TextDocumentItem{ .uri = aURI, .languageId = "typescript", .text = "export const someVar = 10;" },
    });
    try lsptestutil.sendNotification(client, lsproto.TextDocumentDidOpenInfo, &lsproto.DidOpenTextDocumentParams{
        .textDocument = &lsproto.TextDocumentItem{ .uri = bURI, .languageId = "typescript", .text = "s" },
    });

    try lsptestutil.sendNotification(client, lsproto.TextDocumentDidCloseInfo, &lsproto.DidCloseTextDocumentParams{
        .textDocument = lsproto.TextDocumentIdentifier{ .uri = bURI },
    });

    const msg, const resp, const ok = try lsptestutil.sendRequest(client, lsproto.TextDocumentCompletionInfo, &lsproto.CompletionParams{
        .textDocument = lsproto.TextDocumentIdentifier{ .uri = bURI },
        .position = lsproto.Position{ .line = 0, .character = 1 },
        .context = &lsproto.CompletionContext{},
    });
    try testing.expect(ok and msg.asResponse().err == null);

    const items = completionItems(resp) orelse return error.MissingItems;
    const item = findCompletionItem(items, "someVar") orelse return error.MissingItem;
    try testing.expect(item.data != null and item.data.?.autoImport != null);
    try testing.expectEqualStrings("./a", item.data.?.autoImport.?.moduleSpecifier);
}

test "CompletionWithConcurrentFileClose" {
    if (!bundled.embedded) return;

    var prefs = lsutil.UserPreferences{
        .includeCompletionsForModuleExports = core.TSTrue,
        .includeCompletionsForImportStatements = core.TSTrue,
    };
    var client = try initCompletionClient(.{
        .{ "/home/projects/tsconfig.json", "{\"compilerOptions\": {\"module\": \"esnext\", \"target\": \"esnext\"}}" },
        .{ "/home/projects/a.ts", "export const someVar = 10;" },
        .{ "/home/projects/b.ts", "s" },
    }, &prefs);
    defer client.close();

    const aURI = lsproto.DocumentUri("file:///home/projects/a.ts");
    const bURI = lsproto.DocumentUri("file:///home/projects/b.ts");

    try lsptestutil.sendNotification(client, lsproto.TextDocumentDidOpenInfo, &lsproto.DidOpenTextDocumentParams{
        .textDocument = &lsproto.TextDocumentItem{ .uri = aURI, .languageId = "typescript", .text = "export const someVar = 10;" },
    });
    try lsptestutil.sendNotification(client, lsproto.TextDocumentDidOpenInfo, &lsproto.DidOpenTextDocumentParams{
        .textDocument = &lsproto.TextDocumentItem{ .uri = bURI, .languageId = "typescript", .text = "s" },
    });

    const waitForCompletion = try lsptestutil.sendRequestAsync(client, lsproto.TextDocumentCompletionInfo, &lsproto.CompletionParams{
        .textDocument = lsproto.TextDocumentIdentifier{ .uri = bURI },
        .position = lsproto.Position{ .line = 0, .character = 1 },
        .context = &lsproto.CompletionContext{},
    });

    try lsptestutil.sendNotification(client, lsproto.TextDocumentDidCloseInfo, &lsproto.DidCloseTextDocumentParams{
        .textDocument = lsproto.TextDocumentIdentifier{ .uri = bURI },
    });

    const msg, const resp, const ok = try waitForCompletion();
    try testing.expect(ok and msg.asResponse().err == null);
    const items = completionItems(resp) orelse return error.MissingItems;
    const item = findCompletionItem(items, "someVar") orelse return error.MissingItem;
    try testing.expect(item.data != null and item.data.?.autoImport != null);
    try testing.expectEqualStrings("./a", item.data.?.autoImport.?.moduleSpecifier);
}

test "CompletionForUnopenedFile" {
    if (!bundled.embedded) return;

    var prefs = lsutil.UserPreferences{};
    var client = try initCompletionClient(.{
        .{ "/home/projects/tsconfig.json", "{\"compilerOptions\": {\"module\": \"esnext\", \"target\": \"esnext\"}}" },
        .{ "/home/projects/c.ts", "let xyz = 1;\nxy" },
    }, &prefs);
    defer client.close();

    const cURI = lsproto.DocumentUri("file:///home/projects/c.ts");
    const msg, const resp, const ok = try lsptestutil.sendRequest(client, lsproto.TextDocumentCompletionInfo, &lsproto.CompletionParams{
        .textDocument = lsproto.TextDocumentIdentifier{ .uri = cURI },
        .position = lsproto.Position{ .line = 1, .character = 2 },
        .context = &lsproto.CompletionContext{},
    });
    try testing.expect(ok and msg.asResponse().err == null);
    const items = completionItems(resp) orelse return error.MissingItems;
    try testing.expect(findCompletionItem(items, "xyz") != null);
}

test "AutoImportCompletionForUnopenedFile" {
    if (!bundled.embedded) return;

    var prefs = lsutil.UserPreferences{
        .includeCompletionsForModuleExports = core.TSTrue,
        .includeCompletionsForImportStatements = core.TSTrue,
    };
    var client = try initCompletionClient(.{
        .{ "/home/projects/tsconfig.json", "{\"compilerOptions\": {\"module\": \"esnext\", \"target\": \"esnext\"}}" },
        .{ "/home/projects/a.ts", "export const someVar = 10;" },
        .{ "/home/projects/c.ts", "s" },
    }, &prefs);
    defer client.close();

    const cURI = lsproto.DocumentUri("file:///home/projects/c.ts");
    const msg, const resp, const ok = try lsptestutil.sendRequest(client, lsproto.TextDocumentCompletionInfo, &lsproto.CompletionParams{
        .textDocument = lsproto.TextDocumentIdentifier{ .uri = cURI },
        .position = lsproto.Position{ .line = 0, .character = 1 },
        .context = &lsproto.CompletionContext{},
    });
    try testing.expect(ok and msg.asResponse().err == null);
    const items = completionItems(resp) orelse return error.MissingItems;
    const item = findCompletionItem(items, "someVar") orelse return error.MissingItem;
    try testing.expect(item.data != null and item.data.?.autoImport != null);
    try testing.expectEqualStrings("./a", item.data.?.autoImport.?.moduleSpecifier);
}

test "CompletionSnapshotFreezing" {
    if (!bundled.embedded) return;

    var prefs = lsutil.UserPreferences{
        .includeCompletionsForModuleExports = core.TSTrue,
        .includeCompletionsForImportStatements = core.TSTrue,
    };
    var client = try initCompletionClient(.{
        .{ "/home/projects/tsconfig.json", "{\"compilerOptions\": {\"module\": \"esnext\", \"target\": \"esnext\"}}" },
        .{ "/home/projects/a.ts", "export const someVar = 10;" },
        .{ "/home/projects/b.ts", "someV" },
    }, &prefs);
    defer client.close();

    const aURI = lsproto.DocumentUri("file:///home/projects/a.ts");
    const bURI = lsproto.DocumentUri("file:///home/projects/b.ts");

    try lsptestutil.sendNotification(client, lsproto.TextDocumentDidOpenInfo, &lsproto.DidOpenTextDocumentParams{
        .textDocument = &lsproto.TextDocumentItem{ .uri = aURI, .languageId = "typescript", .text = "export const someVar = 10;" },
    });
    try lsptestutil.sendNotification(client, lsproto.TextDocumentDidOpenInfo, &lsproto.DidOpenTextDocumentParams{
        .textDocument = &lsproto.TextDocumentItem{ .uri = bURI, .languageId = "typescript", .text = "someV" },
    });

    const waitForCompletion = try lsptestutil.sendRequestAsync(client, lsproto.TextDocumentCompletionInfo, &lsproto.CompletionParams{
        .textDocument = lsproto.TextDocumentIdentifier{ .uri = bURI },
        .position = lsproto.Position{ .line = 0, .character = 5 },
        .context = &lsproto.CompletionContext{},
    });

    try lsptestutil.sendNotification(client, lsproto.TextDocumentDidChangeInfo, &lsproto.DidChangeTextDocumentParams{
        .textDocument = lsproto.VersionedTextDocumentIdentifier{ .uri = bURI, .version = 2 },
        .contentChanges = &[_]lsproto.TextDocumentContentChangePartialOrWholeDocument{
            .{ .WholeDocument = &lsproto.TextDocumentContentChangeWholeDocument{ .text = "notMatching" } },
        },
    });

    const msg, const resp, const ok = try waitForCompletion();
    try testing.expect(ok and msg.asResponse().err == null);
    const items = completionItems(resp) orelse return error.MissingItems;
    const item = findCompletionItem(items, "someVar") orelse return error.MissingItem;
    try testing.expect(item.data != null and item.data.?.autoImport != null);
    try testing.expectEqualStrings("./a", item.data.?.autoImport.?.moduleSpecifier);
}
