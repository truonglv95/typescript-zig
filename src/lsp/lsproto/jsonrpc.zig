const std = @import("std");
const lsproto = @import("lsp_generated.zig");

pub const ID = union(enum) {
    int: i64,
    string: []const u8,
};

pub const MessageKind = enum {
    request,
    response,
    notification,
};

pub const Message = struct {
    kind: MessageKind,
    msg: std.json.Value, // In Zig, we can just keep the parsed message here.
};

pub const RequestMessage = struct {
    jsonrpc: []const u8 = "2.0",
    id: ?ID = null,
    method: []const u8,
    params: ?std.json.Value = null,
};

pub const ResponseError = struct {
    code: i64,
    message: []const u8,
    data: ?std.json.Value = null,
};

pub const ResponseMessage = struct {
    jsonrpc: []const u8 = "2.0",
    id: ?ID = null,
    result: ?std.json.Value = null,
    error: ?ResponseError = null,
};
