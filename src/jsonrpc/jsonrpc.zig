const std = @import("std");

pub const IDTag = enum {
    string,
    integer,
};

pub const ID = union(IDTag) {
    string: []const u8,
    integer: i32,

    pub fn format(self: ID, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .string => |s| try writer.print("{s}", .{s}),
            .integer => |i| try writer.print("{d}", .{i}),
        }
    }
};

pub const ResponseError = struct {
    code: i32,
    message: []const u8,
    data: ?std.json.Value = null,
};

pub const ErrorCode = struct {
    pub const ParseError: i32 = -32700;
    pub const InvalidRequest: i32 = -32600;
    pub const MethodNotFound: i32 = -32601;
    pub const InvalidParams: i32 = -32602;
    pub const InternalError: i32 = -32603;
};

pub const MessageKind = enum {
    Notification,
    Request,
    Response,
};

pub const Message = struct {
    jsonrpc: []const u8 = "2.0",
    id: ?ID = null,
    method: ?[]const u8 = null,
    params: ?std.json.Value = null,
    result: ?std.json.Value = null,
    @"error": ?ResponseError = null,

    pub fn kind(self: Message) MessageKind {
        if (self.id != null and self.method == null) {
            return .Response;
        }
        if (self.id == null) {
            return .Notification;
        }
        return .Request;
    }
};
