const std = @import("std");
const testing = std.testing;

const bundled = @import("../bundled/bundled.zig");
const lsconv = @import("../ls/lsconv.zig");
const lsutil = @import("../ls/lsutil.zig");
const lsp = @import("lsp.zig");
const lsproto = @import("lsproto.zig");
const lsptestutil = @import("../testutil/lsptestutil.zig");
const iovfs = @import("../vfs/iovfs.zig");
const vfstest = @import("../vfs/vfstest.zig");

const InitResult = struct {
    client: *lsptestutil.LSPClient,
    baseFS: *vfstest.MapFS,
};

fn initMutableLSPClient(files: anytype, prefs: *lsutil.UserPreferences) !InitResult {
    const base = vfstest.fromMap(files, false);
    var fs = bundled.wrapFS(base);

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
        .cwd = "/root",
        .fs = &fs,
        .default_library_path = bundled.libPath(),
    }, Context.onServerRequest);
    client.on_server_request_ctx = &context_data;

    const initMsg, _, const ok = try lsptestutil.sendRequest(client, lsproto.InitializeInfo, &lsproto.InitializeParams{
        .capabilities = &lsproto.ClientCapabilities{},
    });
    try testing.expect(ok and initMsg.asResponse().err == null);
    try lsptestutil.sendNotification(client, lsproto.InitializedInfo, &lsproto.InitializedParams{});

    return InitResult{ .client = client, .baseFS = undefined }; // mock baseFS
}

test "ReferencesAfterAncestorProjectConfigDeletion1" {
    if (!bundled.embedded) return;

    var prefs = lsutil.UserPreferences{};
    const res = try initMutableLSPClient(.{
        .{ "/root/tsconfig.json", "{\n\"files\": [],\n\"references\": [{ \"path\": \"./project\" }]\n}" },
        .{ "/root/project/tsconfig.json", "{\n\"compilerOptions\": { \"composite\": true },\n\"include\": [\"src/**/*.ts\"]\n}" },
        .{ "/root/project/src/main.ts", "export function helloWorld() {}\nhelloWorld()\n" },
    }, &prefs);
    var client = res.client;
    defer client.close();

    const mainURI = lsproto.DocumentUri("file:///root/project/src/main.ts");
    try lsptestutil.sendNotification(client, lsproto.TextDocumentDidOpenInfo, &lsproto.DidOpenTextDocumentParams{
        .textDocument = &lsproto.TextDocumentItem{ .uri = mainURI, .languageId = "typescript", .text = "export function helloWorld() {}\nhelloWorld()\n" },
    });

    const msg, _, const ok = try lsptestutil.sendRequest(client, lsproto.TextDocumentDocumentSymbolInfo, &lsproto.DocumentSymbolParams{
        .textDocument = lsproto.TextDocumentIdentifier{ .uri = mainURI },
    });
    try testing.expect(ok and msg.asResponse().err == null);

    try lsptestutil.sendNotification(client, lsproto.WorkspaceDidChangeWatchedFilesInfo, &lsproto.DidChangeWatchedFilesParams{
        .changes = &[_]lsproto.FileEvent{.{
            .uri = lsproto.DocumentUri("file:///root/tsconfig.json"),
            .type = .Deleted,
        }},
    });

    const msg2, const resp, const ok2 = try lsptestutil.sendRequest(client, lsproto.TextDocumentReferencesInfo, &lsproto.ReferenceParams{
        .textDocument = lsproto.TextDocumentIdentifier{ .uri = mainURI },
        .position = lsproto.Position{ .line = 1, .character = 3 },
        .context = &lsproto.ReferenceContext{ .includeDeclaration = true },
    });
    try testing.expect(ok2 and msg2.asResponse().err == null);
    try testing.expect(resp.locations != null);
}
