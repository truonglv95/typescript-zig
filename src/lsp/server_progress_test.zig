const std = @import("std");
const testing = std.testing;

const bundled = @import("../bundled/bundled.zig");
const lsp = @import("lsp.zig");
const lsproto = @import("lsproto.zig");
const lsptestutil = @import("../testutil/lsptestutil.zig");
const vfstest = @import("../vfs/vfstest.zig");

test "ProgressNotificationsEndToEnd" {
    if (!bundled.embedded) {
        return;
    }

    var fs = bundled.wrapFS(vfstest.fromMap(.{
        .{ "/home/projects/tsconfig.json", "{}" },
        .{ "/home/projects/index.ts", "export const x = 1;" },
    }, false));

    const Context = struct {
        mu: std.Thread.Mutex = .{},
        progress_notifications: std.ArrayList(*lsproto.ProgressParams),
        end_received: std.Thread.Semaphore = .{},

        fn onServerRequest(ctx: *anyopaque, req: *lsproto.RequestMessage) ?*lsproto.ResponseMessage {
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

        fn onServerNotification(ctx: *anyopaque, req: *lsproto.RequestMessage) void {
            var self: *@This() = @ptrCast(@alignCast(ctx));
            if (req.method == .Progress) {
                if (req.params) |p| {
                    if (p.isProgressParams()) {
                        self.mu.lock();
                        defer self.mu.unlock();
                        self.progress_notifications.append(p) catch {};
                        if (p.value.end != null) {
                            self.end_received.post();
                        }
                    }
                }
            }
        }
    };

    var context_data = Context{
        .progress_notifications = std.ArrayList(*lsproto.ProgressParams).init(std.testing.allocator),
    };
    defer context_data.progress_notifications.deinit();

    var client = try lsptestutil.NewLSPClient(.{
        .err = std.io.null_writer,
        .cwd = "/home/projects",
        .fs = &fs,
        .default_library_path = bundled.libPath(),
    }, Context.onServerRequest);
    defer client.close();

    client.on_server_notification_ctx = &context_data;
    client.on_server_notification = Context.onServerNotification;

    const initMsg, _, const ok = try lsptestutil.sendRequest(client, lsproto.InitializeInfo, &lsproto.InitializeParams{
        .capabilities = &lsproto.ClientCapabilities{
            .window = &lsproto.WindowClientCapabilities{
                .workDoneProgress = true,
            },
        },
    });
    try testing.expect(ok and initMsg.asResponse().err == null);
    try lsptestutil.sendNotification(client, lsproto.InitializedInfo, &lsproto.InitializedParams{});
    // <-client.server.initComplete()

    const uri = lsproto.DocumentUri("file:///home/projects/index.ts");
    try lsptestutil.sendNotification(client, lsproto.TextDocumentDidOpenInfo, &lsproto.DidOpenTextDocumentParams{
        .textDocument = &lsproto.TextDocumentItem{ .uri = uri, .languageId = "typescript", .text = "export const x = 1;" },
    });

    const msg, const resp, const ok_proj = try lsptestutil.sendRequest(client, lsproto.CustomProjectInfoInfo, &lsproto.ProjectInfoParams{
        .textDocument = lsproto.TextDocumentIdentifier{ .uri = uri },
    });
    try testing.expect(ok_proj);
    try testing.expect(msg.asResponse().err == null);
    try testing.expectEqualStrings("/home/projects/tsconfig.json", resp.configFilePath);

    context_data.end_received.wait();

    context_data.mu.lock();
    const notifications = try context_data.progress_notifications.clone();
    context_data.mu.unlock();
    defer notifications.deinit();

    try testing.expect(notifications.items.len >= 2);
    try testing.expect(notifications.items[0].value.begin != null);
    try testing.expectEqualStrings("Loading", notifications.items[0].value.begin.title);

    const last = notifications.items[notifications.items.len - 1];
    try testing.expect(last.value.end != null);

    const firstToken = tokenString(notifications.items[0].token);
    try testing.expect(firstToken.len > 0);
    for (notifications.items) |n| {
        try testing.expectEqualStrings(firstToken, tokenString(n.token));
    }
}

fn tokenString(t: lsproto.IntegerOrString) []const u8 {
    if (t.string) |s| {
        return s;
    }
    return "";
}
