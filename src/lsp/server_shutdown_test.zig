const std = @import("std");
const testing = std.testing;

const bundled = @import("../bundled/bundled.zig");
const lsproto = @import("lsproto.zig");
const project = @import("../project.zig");
const vfstest = @import("../vfs/vfstest.zig");
const lsp = @import("lsp.zig");

const ShutdownTestReader = struct {
    pub fn read(self: *ShutdownTestReader) !*lsproto.Message {
        _ = self;
        return error.EOF;
    }
};

const ShutdownTestWriter = struct {
    pub fn write(self: *ShutdownTestWriter, msg: *lsproto.Message) !void {
        _ = self;
        _ = msg;
    }
};

// TestServerShutdownNoDeadlock verifies that operations after shutdown don't block.
test "ServerShutdownNoDeadlock" {
    if (!bundled.embedded) {
        // skipped: bundled files are not embedded
        return;
    }

    var fs = bundled.wrapFS(vfstest.fromMap(.{
        .{ "/test/tsconfig.json", "{}" },
        .{ "/test/index.ts", "const x = 1;" },
    }, false));

    var reader = ShutdownTestReader{};
    var writer = ShutdownTestWriter{};

    var server = try lsp.Server.init(.{
        .in = &reader,
        .out = &writer,
        .err = std.io.null_writer,
        .cwd = "/test",
        .fs = &fs,
        .default_library_path = bundled.libPath(),
    });
    defer server.deinit();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const ctx = arena.allocator();

    server.background_ctx = ctx;

    // Start write loop to drain queue
    const write_loop_thread = try std.Thread.spawn(.{}, server.writeLoop, .{ctx});

    // Create session with the server's lifecycle context
    server.init_started.store(true, .SeqCst);
    server.session = try project.Session.init(.{
        .background_ctx = ctx,
        .options = &.{
            .current_directory = "/test",
            .default_library_path = bundled.libPath(),
            .position_encoding = .UTF8,
            .watch_enabled = false,
            .logging_enabled = true,
        },
        .fs = &fs,
        .logger = server.logger,
    });

    // Open a file to establish a project
    try server.session.didOpenFile(ctx, "file:///test/index.ts", 1, "const x = 1;", .TypeScript);
    server.session.waitForBackgroundTasks();

    // Shutdown (cancel context and wait for write loop to exit)
    server.cancel();
    write_loop_thread.join();

    // Trigger operations that would log (these should not block)
    var changes = [_]lsproto.TextDocumentContentChangePartialOrWholeDocument{
        .{ .WholeDocument = &.{ .text = "const x = 2;" } },
    };
    try server.session.didChangeFile(ctx, "file:///test/index.ts", 2, &changes);
    _ = try server.session.getLanguageService(ctx, "file:///test/index.ts");
    server.session.waitForBackgroundTasks();

    server.session.close();
}

test "ServerOutgoingQueueDoesNotBlockWithoutWriter" {
    var reader = ShutdownTestReader{};
    var writer = ShutdownTestWriter{};
    var server = try lsp.Server.init(.{
        .in = &reader,
        .out = &writer,
        .err = std.io.null_writer,
        .cwd = "/test",
    });
    defer server.deinit();

    const ctx = std.testing.allocator;
    server.background_ctx = ctx;

    const msg = try lsproto.WindowLogMessageInfo.newNotificationMessage(.{
        .type = .Info,
        .message = "queued",
    }).message();

    const ThreadJob = struct {
        server: *lsp.Server,
        msg: *lsproto.Message,

        fn run(self: *@This()) !void {
            var i: usize = 0;
            while (i < 1000) : (i += 1) {
                try self.server.send(self.msg);
            }
        }
    };

    var job = ThreadJob{ .server = &server, .msg = msg };
    const thread = try std.Thread.spawn(.{}, ThreadJob.run, .{&job});
    thread.join();
}
