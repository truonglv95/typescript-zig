const std = @import("std");
const testing = std.testing;

const bundled = @import("../bundled/bundled.zig");
const lsp = @import("lsp.zig");
const lsproto = @import("lsproto.zig");
const lsptestutil = @import("../testutil/lsptestutil.zig");
const vfstest = @import("../vfs/vfstest.zig");

fn initProjectInfoClient(files: anytype) !*lsptestutil.LSPClient {
    var fs = bundled.wrapFS(vfstest.fromMap(files, false));

    const Handler = struct {
        fn onServerRequest(ctx: anytype, req: *lsproto.RequestMessage) ?*lsproto.ResponseMessage {
            _ = ctx;
            switch (req.method) {
                .ClientRegisterCapability, .ClientUnregisterCapability, .WindowWorkDoneProgressCreate => {
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

    const client = try lsptestutil.NewLSPClient(.{
        .err = std.io.null_writer,
        .cwd = "/home/projects",
        .fs = &fs,
        .default_library_path = bundled.libPath(),
    }, Handler.onServerRequest);

    const initMsg, _, const ok = try lsptestutil.sendRequest(client, lsproto.InitializeInfo, &lsproto.InitializeParams{
        .capabilities = &lsproto.ClientCapabilities{},
    });
    try testing.expect(ok and initMsg.asResponse().err == null);
    try lsptestutil.sendNotification(client, lsproto.InitializedInfo, &lsproto.InitializedParams{});
    // <-client.server.initComplete()

    return client;
}

test "ProjectInfoConfiguredProject" {
    if (!bundled.embedded) {
        return;
    }

    var client = try initProjectInfoClient(.{
        .{ "/home/projects/tsconfig.json", "{}" },
        .{ "/home/projects/index.ts", "export const x = 1;" },
    });
    defer client.close();

    const uri = lsproto.DocumentUri("file:///home/projects/index.ts");
    try lsptestutil.sendNotification(client, lsproto.TextDocumentDidOpenInfo, &lsproto.DidOpenTextDocumentParams{
        .textDocument = &lsproto.TextDocumentItem{ .uri = uri, .languageId = "typescript", .text = "export const x = 1;" },
    });

    const msg, const resp, const ok = try lsptestutil.sendRequest(client, lsproto.CustomProjectInfoInfo, &lsproto.ProjectInfoParams{
        .textDocument = lsproto.TextDocumentIdentifier{ .uri = uri },
    });
    try testing.expect(ok);
    try testing.expect(msg.asResponse().err == null);
    try testing.expectEqualStrings("/home/projects/tsconfig.json", resp.configFilePath);
}

test "ProjectInfoInferredProject" {
    if (!bundled.embedded) {
        return;
    }

    var client = try initProjectInfoClient(.{
        .{ "/home/projects/index.ts", "export const x = 1;" },
    });
    defer client.close();

    const uri = lsproto.DocumentUri("file:///home/projects/index.ts");
    try lsptestutil.sendNotification(client, lsproto.TextDocumentDidOpenInfo, &lsproto.DidOpenTextDocumentParams{
        .textDocument = &lsproto.TextDocumentItem{ .uri = uri, .languageId = "typescript", .text = "export const x = 1;" },
    });

    const msg, const resp, const ok = try lsptestutil.sendRequest(client, lsproto.CustomProjectInfoInfo, &lsproto.ProjectInfoParams{
        .textDocument = lsproto.TextDocumentIdentifier{ .uri = uri },
    });
    try testing.expect(ok);
    try testing.expect(msg.asResponse().err == null);
    try testing.expectEqualStrings("", resp.configFilePath);
}
