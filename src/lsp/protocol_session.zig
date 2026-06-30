const std = @import("std");
const documents = @import("document_store.zig");
const parser_mod = @import("../parser/parser.zig");

pub const Session = struct {
    allocator: std.mem.Allocator,
    store: documents.DocumentStore,
    initialized: bool = false,
    shutdown_requested: bool = false,
    exit_requested: bool = false,

    pub fn init(allocator: std.mem.Allocator) Session {
        return .{ .allocator = allocator, .store = documents.DocumentStore.init(allocator) };
    }

    pub fn deinit(self: *Session) void {
        self.store.deinit();
    }

    /// Handles one JSON-RPC payload and returns an owned response payload for
    /// requests. Notifications return null.
    pub fn handle(self: *Session, payload: []const u8) !?[]u8 {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, payload, .{});
        defer parsed.deinit();
        if (parsed.value != .object) return error.InvalidRequest;
        const object = parsed.value.object;
        const method_value = object.get("method") orelse return error.InvalidRequest;
        if (method_value != .string) return error.InvalidRequest;
        const method = method_value.string;

        if (std.mem.eql(u8, method, "initialize")) {
            self.initialized = true;
            return try response(self.allocator, object.get("id"), "{\"capabilities\":{\"positionEncoding\":\"utf-16\",\"textDocumentSync\":2,\"diagnosticProvider\":{\"interFileDependencies\":true,\"workspaceDiagnostics\":false}}}");
        }
        if (std.mem.eql(u8, method, "shutdown")) {
            self.shutdown_requested = true;
            return try response(self.allocator, object.get("id"), "null");
        }
        if (std.mem.eql(u8, method, "exit")) {
            self.exit_requested = true;
            return null;
        }
        if (!self.initialized or self.shutdown_requested) return try errorResponse(self.allocator, object.get("id"), -32002, "Server not initialized");
        const params_value = object.get("params") orelse return error.InvalidParams;
        if (params_value != .object) return error.InvalidParams;

        if (std.mem.eql(u8, method, "textDocument/didOpen")) {
            const document = try objectField(params_value.object, "textDocument");
            try self.store.open(try stringField(document, "uri"), try integerField(document, "version"), try stringField(document, "text"));
        } else if (std.mem.eql(u8, method, "textDocument/didClose")) {
            const document = try objectField(params_value.object, "textDocument");
            _ = self.store.close(try stringField(document, "uri"));
        } else if (std.mem.eql(u8, method, "textDocument/didChange")) {
            const document = try objectField(params_value.object, "textDocument");
            const uri = try stringField(document, "uri");
            const version = try integerField(document, "version");
            const changes_value = params_value.object.get("contentChanges") orelse return error.InvalidParams;
            if (changes_value != .array) return error.InvalidParams;
            var changes: std.ArrayList(documents.Change) = .empty;
            defer changes.deinit(self.allocator);
            for (changes_value.array.items) |change_value| {
                if (change_value != .object) return error.InvalidParams;
                const text = try stringField(change_value.object, "text");
                var range: ?documents.Range = null;
                if (change_value.object.get("range")) |range_value| {
                    if (range_value != .object) return error.InvalidParams;
                    range = .{
                        .start = try position(try objectField(range_value.object, "start")),
                        .end = try position(try objectField(range_value.object, "end")),
                    };
                }
                try changes.append(self.allocator, .{ .range = range, .text = text });
            }
            try self.store.applyChanges(uri, version, changes.items);
        } else if (std.mem.eql(u8, method, "textDocument/diagnostic")) {
            const document = try objectField(params_value.object, "textDocument");
            const uri = try stringField(document, "uri");
            const open_document = self.store.get(uri) orelse return try errorResponse(self.allocator, object.get("id"), -32602, "Document is not open");
            var parser = parser_mod.Parser.init(self.allocator, open_document.text);
            defer parser.deinit();
            _ = try parser.parseSourceFile();
            const result = if (parser.diagnosticCount() == 0)
                try self.allocator.dupe(u8, "{\"kind\":\"full\",\"items\":[]}")
            else
                try std.fmt.allocPrint(self.allocator, "{{\"kind\":\"full\",\"items\":[{{\"range\":{{\"start\":{{\"line\":0,\"character\":0}},\"end\":{{\"line\":0,\"character\":1}}}},\"severity\":1,\"source\":\"typescript-zig\",\"code\":1005,\"message\":\"Syntax errors: {d}\"}}]}}", .{parser.diagnosticCount()});
            defer self.allocator.free(result);
            return try response(self.allocator, object.get("id"), result);
        } else if (object.get("id") != null) {
            return try errorResponse(self.allocator, object.get("id"), -32601, "Method not found");
        }
        return null;
    }
};

fn response(allocator: std.mem.Allocator, id: ?std.json.Value, result_json: []const u8) ![]u8 {
    const id_json = if (id) |value| try std.json.Stringify.valueAlloc(allocator, value, .{}) else try allocator.dupe(u8, "null");
    defer allocator.free(id_json);
    return std.fmt.allocPrint(allocator, "{{\"jsonrpc\":\"2.0\",\"id\":{s},\"result\":{s}}}", .{ id_json, result_json });
}

fn errorResponse(allocator: std.mem.Allocator, id: ?std.json.Value, code: i32, message: []const u8) ![]u8 {
    const id_json = if (id) |value| try std.json.Stringify.valueAlloc(allocator, value, .{}) else try allocator.dupe(u8, "null");
    defer allocator.free(id_json);
    const message_json = try std.json.Stringify.valueAlloc(allocator, message, .{});
    defer allocator.free(message_json);
    return std.fmt.allocPrint(allocator, "{{\"jsonrpc\":\"2.0\",\"id\":{s},\"error\":{{\"code\":{d},\"message\":{s}}}}}", .{ id_json, code, message_json });
}

fn objectField(object: std.json.ObjectMap, name: []const u8) !std.json.ObjectMap {
    const value = object.get(name) orelse return error.InvalidParams;
    if (value != .object) return error.InvalidParams;
    return value.object;
}

fn stringField(object: std.json.ObjectMap, name: []const u8) ![]const u8 {
    const value = object.get(name) orelse return error.InvalidParams;
    if (value != .string) return error.InvalidParams;
    return value.string;
}

fn integerField(object: std.json.ObjectMap, name: []const u8) !i64 {
    const value = object.get(name) orelse return error.InvalidParams;
    return switch (value) {
        .integer => value.integer,
        else => error.InvalidParams,
    };
}

fn position(object: std.json.ObjectMap) !documents.Position {
    const line = try integerField(object, "line");
    const character = try integerField(object, "character");
    if (line < 0 or character < 0) return error.InvalidParams;
    return .{ .line = @intCast(line), .character = @intCast(character) };
}

test "protocol session lifecycle and incremental synchronization" {
    const allocator = std.testing.allocator;
    var session = Session.init(allocator);
    defer session.deinit();

    const initialize = (try session.handle("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}")).?;
    defer allocator.free(initialize);
    try std.testing.expect(std.mem.indexOf(u8, initialize, "textDocumentSync") != null);
    try std.testing.expect((try session.handle("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///a.ts\",\"version\":1,\"text\":\"const x = 1;\"}}}")) == null);
    try std.testing.expect((try session.handle("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didChange\",\"params\":{\"textDocument\":{\"uri\":\"file:///a.ts\",\"version\":2},\"contentChanges\":[{\"range\":{\"start\":{\"line\":0,\"character\":10},\"end\":{\"line\":0,\"character\":11}},\"text\":\"2\"}]}}")) == null);
    try std.testing.expectEqualStrings("const x = 2;", session.store.get("file:///a.ts").?.text);
    const shutdown = (try session.handle("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"shutdown\",\"params\":null}")).?;
    defer allocator.free(shutdown);
    try std.testing.expect(session.shutdown_requested);
    _ = try session.handle("{\"jsonrpc\":\"2.0\",\"method\":\"exit\"}");
    try std.testing.expect(session.exit_requested);
}

test "protocol session returns JSON-RPC errors for invalid request state and unknown methods" {
    const allocator = std.testing.allocator;
    var session = Session.init(allocator);
    defer session.deinit();
    const premature = (try session.handle("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"workspace/symbol\",\"params\":{}}")).?;
    defer allocator.free(premature);
    try std.testing.expect(std.mem.indexOf(u8, premature, "-32002") != null);
    const initialize = (try session.handle("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"initialize\",\"params\":{}}")).?;
    defer allocator.free(initialize);
    const unknown = (try session.handle("{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"workspace/unknown\",\"params\":{}}")).?;
    defer allocator.free(unknown);
    try std.testing.expect(std.mem.indexOf(u8, unknown, "-32601") != null);
}

test "protocol session serves pull diagnostics from the document overlay" {
    const allocator = std.testing.allocator;
    var session = Session.init(allocator);
    defer session.deinit();
    const initialize = (try session.handle("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}")).?;
    defer allocator.free(initialize);
    _ = try session.handle("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///bad.ts\",\"version\":1,\"text\":\"const = ;\"}}}");
    const diagnostics = (try session.handle("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"textDocument/diagnostic\",\"params\":{\"textDocument\":{\"uri\":\"file:///bad.ts\"}}}")).?;
    defer allocator.free(diagnostics);
    try std.testing.expect(std.mem.indexOf(u8, diagnostics, "typescript-zig") != null);
}
