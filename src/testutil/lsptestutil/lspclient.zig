const std = @import("std");
const core = @import("../../core/core.zig");
const json = @import("../../json/json.zig");
const jsonrpc = @import("../../jsonrpc/jsonrpc.zig");
const lsp = @import("../../lsp/lsp.zig");
const lsproto = @import("../../lsp/lsproto.zig");

pub const LSPReader = struct {
    // We would use a thread-safe queue or channel here.
    // For skeleton, we'll just have it implement lsp.Reader interface if any
    allocator: std.mem.Allocator,
    queue: std.ArrayList(*lsproto.Message),
    mutex: std.Thread.Mutex,
    cond: std.Thread.Condition,
    closed: bool,

    pub fn init(allocator: std.mem.Allocator) LSPReader {
        return .{
            .allocator = allocator,
            .queue = std.ArrayList(*lsproto.Message).init(allocator),
            .mutex = .{},
            .cond = .{},
            .closed = false,
        };
    }

    pub fn deinit(self: *LSPReader) void {
        self.queue.deinit();
    }

    pub fn read(self: *LSPReader) !*lsproto.Message {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.queue.items.len == 0 and !self.closed) {
            self.cond.wait(&self.mutex);
        }

        if (self.queue.items.len > 0) {
            return self.queue.orderedRemove(0);
        }
        return error.EOF;
    }
};

pub const LSPWriter = struct {
    reader: *LSPReader, // Writing to this writer enqueues to the reader

    pub fn write(self: *LSPWriter, msg: *lsproto.Message) !void {
        self.reader.mutex.lock();
        defer self.reader.mutex.unlock();

        if (self.reader.closed) return error.Closed;

        try self.reader.queue.append(msg);
        self.reader.cond.signal();
    }

    pub fn close(self: *LSPWriter) void {
        self.reader.mutex.lock();
        defer self.reader.mutex.unlock();

        self.reader.closed = true;
        self.reader.cond.broadcast();
    }
};

pub fn newLSPPipe(allocator: std.mem.Allocator) !struct { *LSPReader, *LSPWriter } {
    const reader = try allocator.create(LSPReader);
    reader.* = LSPReader.init(allocator);

    const writer = try allocator.create(LSPWriter);
    writer.* = .{ .reader = reader };

    return .{ reader, writer };
}

pub const ServerRequestHandler = *const fn (ctx: ?*anyopaque, req: *lsproto.RequestMessage) ?*lsproto.ResponseMessage;
pub const ServerNotificationHandler = *const fn (ctx: ?*anyopaque, req: *lsproto.RequestMessage) void;

pub const LSPClient = struct {
    allocator: std.mem.Allocator,
    server: *lsp.Server,
    inputWriter: *LSPWriter,
    outputReader: *LSPReader,
    id: i32,
    
    onServerRequest: ?ServerRequestHandler,
    onServerNotification: ?ServerNotificationHandler,
    ctx: ?*anyopaque,

    pendingRequests: std.AutoHashMap(jsonrpc.ID, *std.Thread.Condition), // Dummy for now
    pendingRequestsMu: std.Thread.Mutex,

    serverThread: std.Thread,
    routerThread: std.Thread,
    closed: std.atomic.Value(bool),

    pub fn init(
        allocator: std.mem.Allocator,
        serverOpts: lsp.ServerOptions,
        onServerRequest: ?ServerRequestHandler,
    ) !*LSPClient {
        const inputPipe = try newLSPPipe(allocator);
        const outputPipe = try newLSPPipe(allocator);

        var opts = serverOpts;
        opts.in_reader = inputPipe[0];
        opts.out_writer = outputPipe[1];

        const server = try lsp.Server.init(allocator, &opts);

        var client = try allocator.create(LSPClient);
        client.* = .{
            .allocator = allocator,
            .server = server,
            .inputWriter = inputPipe[1],
            .outputReader = outputPipe[0],
            .id = 0,
            .onServerRequest = onServerRequest,
            .onServerNotification = null,
            .ctx = null,
            .pendingRequests = std.AutoHashMap(jsonrpc.ID, *std.Thread.Condition).init(allocator),
            .pendingRequestsMu = .{},
            .serverThread = undefined,
            .routerThread = undefined,
            .closed = std.atomic.Value(bool).init(false),
        };

        client.serverThread = try std.Thread.spawn(.{}, serverRunThread, .{client});
        client.routerThread = try std.Thread.spawn(.{}, messageRouterThread, .{client});

        return client;
    }

    fn serverRunThread(self: *LSPClient) void {
        _ = self.server.run() catch {};
        self.outputReader.writer.close(); // Need ref to outputWriter
    }

    fn messageRouterThread(self: *LSPClient) void {
        while (!self.closed.load(.seq_cst)) {
            const msg = self.outputReader.read() catch break;
            
            switch (msg.kind) {
                .response => {
                    self.handleResponse(msg.asResponse());
                },
                .request => {
                    self.handleServerRequest(msg.asRequest()) catch {};
                },
                .notification => {
                    if (self.onServerNotification) |handler| {
                        handler(self.ctx, msg.asRequest());
                    }
                },
            }
        }
    }

    pub fn deinit(self: *LSPClient) void {
        self.closed.store(true, .seq_cst);
        self.inputWriter.close();
        self.serverThread.join();
        self.routerThread.join();
        self.pendingRequests.deinit();
    }

    pub fn nextID(self: *LSPClient) i32 {
        const id = self.id;
        self.id += 1;
        return id;
    }

    fn handleResponse(self: *LSPClient, resp: *lsproto.ResponseMessage) void {
        if (resp.id == null) return;

        self.pendingRequestsMu.lock();
        defer self.pendingRequestsMu.unlock();

        if (self.pendingRequests.get(resp.id.?)) |cond| {
            _ = self.pendingRequests.remove(resp.id.?);
            cond.signal();
        }
    }

    fn handleServerRequest(self: *LSPClient, req: *lsproto.RequestMessage) !void {
        var response: ?*lsproto.ResponseMessage = null;

        if (self.onServerRequest) |handler| {
            response = handler(self.ctx, req);
        }

        if (response == null) {
            response = try self.allocator.create(lsproto.ResponseMessage);
            response.* = .{
                .id = req.id,
                .jsonrpc = req.jsonrpc,
                .err = try self.allocator.create(jsonrpc.ResponseError),
            };
            response.?.err.?.* = .{
                .code = @intFromEnum(lsproto.ErrorCode.methodNotFound),
                .message = "Unknown method",
            };
        }

        try self.inputWriter.write(response.?.message());
    }

    pub fn writeMsg(self: *LSPClient, msg: *lsproto.Message) !void {
        try self.inputWriter.write(msg);
    }
};

pub fn sendRequest(
    comptime Params: type,
    comptime Resp: type,
    allocator: std.mem.Allocator,
    c: *LSPClient,
    info: anytype,
    params: Params,
) !struct { *lsproto.Message, Resp, bool } {
    _ = info;
    _ = params;
    _ = allocator;
    const id = c.nextID();
    _ = id;
    // Skeleton: In a real impl, we would create a condition variable, add to pending requests, write, and wait
    return error.NotImplemented;
}

pub fn sendNotification(
    comptime Params: type,
    allocator: std.mem.Allocator,
    c: *LSPClient,
    info: anytype,
    params: Params,
) !void {
    _ = allocator;
    _ = c;
    _ = info;
    _ = params;
    return error.NotImplemented;
}
