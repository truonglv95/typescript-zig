const std = @import("std");
const testing = std.testing;

const bundled = @import("../bundled/bundled.zig");
const lsp = @import("lsp.zig");
const lsproto = @import("lsproto.zig");
const lsptestutil = @import("../testutil/lsptestutil.zig");
const vfstest = @import("../vfs/vfstest.zig");

test "SemanticTokensCRLF" {
    if (!bundled.embedded) {
        return;
    }

    const fileOnDisk = "var x\nvar x\nvar x\nvar x\nvar x\nvar x\nconst a = 1\n";
    const fileFromEditor = "var x\r\nvar x\r\nvar x\r\nvar x\r\nvar x\r\nvar x\r\nconst a = 1\r\n";

    var fs = bundled.wrapFS(vfstest.fromMap(.{
        .{ "/home/projects/tsconfig.json", "{}" },
        .{ "/home/projects/test.ts", fileOnDisk },
        .{ "/home/projects/other.ts", "export {}" },
    }, false));

    const Handler = struct {
        fn onServerRequest(ctx: *anyopaque, req: *lsproto.RequestMessage) ?*lsproto.ResponseMessage {
            _ = ctx;
            if (req.method == .ClientRegisterCapability or req.method == .ClientUnregisterCapability) {
                return &lsproto.ResponseMessage{ .id = req.id, .jsonrpc = req.jsonrpc, .result = lsproto.Null{} };
            }
            return null;
        }
    };

    var client = try lsptestutil.NewLSPClient(.{
        .err = std.io.null_writer,
        .cwd = "/home/projects",
        .fs = &fs,
        .default_library_path = bundled.libPath(),
    }, Handler.onServerRequest);
    defer client.close();

    var tokenTypes = [_][]const u8{"namespace", "type", "class", "enum", "interface", "struct", "typeParameter", "parameter", "variable", "property", "enumMember", "event", "function", "method", "macro", "keyword", "modifier", "comment", "string", "number", "regexp", "operator", "decorator"};
    var tokenModifiers = [_][]const u8{"declaration", "definition", "readonly", "static", "deprecated", "abstract", "async", "modification", "documentation", "defaultLibrary", "local"};

    const initMsg, _, const ok = try lsptestutil.sendRequest(client, lsproto.InitializeInfo, &lsproto.InitializeParams{
        .capabilities = &lsproto.ClientCapabilities{
            .textDocument = &lsproto.TextDocumentClientCapabilities{
                .semanticTokens = &lsproto.SemanticTokensClientCapabilities{
                    .tokenTypes = &tokenTypes,
                    .tokenModifiers = &tokenModifiers,
                },
            },
        },
    });
    try testing.expect(ok and initMsg.asResponse().err == null);
    try lsptestutil.sendNotification(client, lsproto.InitializedInfo, &lsproto.InitializedParams{});

    const otherUri = lsproto.DocumentUri("file:///home/projects/other.ts");
    try lsptestutil.sendNotification(client, lsproto.TextDocumentDidOpenInfo, &lsproto.DidOpenTextDocumentParams{
        .textDocument = &lsproto.TextDocumentItem{ .uri = otherUri, .languageId = "typescript", .text = "export {}" },
    });
    const msg1, _, _ = try lsptestutil.sendRequest(client, lsproto.TextDocumentSemanticTokensFullInfo, &lsproto.SemanticTokensParams{
        .textDocument = lsproto.TextDocumentIdentifier{ .uri = otherUri },
    });
    try testing.expect(msg1.asResponse().err == null);

    const uri = lsproto.DocumentUri("file:///home/projects/test.ts");
    try lsptestutil.sendNotification(client, lsproto.TextDocumentDidOpenInfo, &lsproto.DidOpenTextDocumentParams{
        .textDocument = &lsproto.TextDocumentItem{ .uri = uri, .languageId = "typescript", .text = fileFromEditor },
    });

    const msg, _, _ = try lsptestutil.sendRequest(client, lsproto.TextDocumentSemanticTokensFullInfo, &lsproto.SemanticTokensParams{
        .textDocument = lsproto.TextDocumentIdentifier{ .uri = uri },
    });
    if (msg.asResponse().err != null) {
        return error.SemanticTokensFailed;
    }
}
