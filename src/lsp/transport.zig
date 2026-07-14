const std = @import("std");

pub const Decoder = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayList(u8) = .empty,
    max_message_size: usize = 64 * 1024 * 1024,

    pub fn init(allocator: std.mem.Allocator) Decoder {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Decoder) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn feed(self: *Decoder, bytes: []const u8) !void {
        if (self.buffer.items.len + bytes.len > self.max_message_size + 64 * 1024) return error.MessageTooLarge;
        try self.buffer.appendSlice(self.allocator, bytes);
    }

    /// Returns an owned JSON payload. A null result means the frame is incomplete.
    pub fn next(self: *Decoder) !?[]u8 {
        const header_end = std.mem.indexOf(u8, self.buffer.items, "\r\n\r\n") orelse return null;
        var content_length: ?usize = null;
        var headers = std.mem.splitSequence(u8, self.buffer.items[0..header_end], "\r\n");
        while (headers.next()) |header| {
            const colon = std.mem.indexOfScalar(u8, header, ':') orelse return error.InvalidHeader;
            const name = std.mem.trim(u8, header[0..colon], " \t");
            const value = std.mem.trim(u8, header[colon + 1 ..], " \t");
            if (std.ascii.eqlIgnoreCase(name, "Content-Length")) {
                if (content_length != null) return error.DuplicateContentLength;
                content_length = std.fmt.parseInt(usize, value, 10) catch return error.InvalidContentLength;
            }
        }
        const length = content_length orelse return error.MissingContentLength;
        if (length > self.max_message_size) return error.MessageTooLarge;
        const payload_start = header_end + 4;
        const frame_end = payload_start + length;
        if (frame_end > self.buffer.items.len) return null;
        const payload = try self.allocator.dupe(u8, self.buffer.items[payload_start..frame_end]);
        const remaining = self.buffer.items.len - frame_end;
        std.mem.copyForwards(u8, self.buffer.items[0..remaining], self.buffer.items[frame_end..]);
        self.buffer.items.len = remaining;
        return payload;
    }
};

pub fn encode(allocator: std.mem.Allocator, payload: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "Content-Length: {d}\r\n\r\n{s}", .{ payload.len, payload });
}

test "LSP decoder accepts fragmented and pipelined frames" {
    const allocator = std.testing.allocator;
    const first = try encode(allocator, "{\"id\":1}");
    defer allocator.free(first);
    const second = try encode(allocator, "{\"method\":\"exit\"}");
    defer allocator.free(second);

    var decoder = Decoder.init(allocator);
    defer decoder.deinit();
    try decoder.feed(first[0..7]);
    try std.testing.expect((try decoder.next()) == null);
    try decoder.feed(first[7..]);
    try decoder.feed(second);
    const first_payload = (try decoder.next()).?;
    defer allocator.free(first_payload);
    try std.testing.expectEqualStrings("{\"id\":1}", first_payload);
    const second_payload = (try decoder.next()).?;
    defer allocator.free(second_payload);
    try std.testing.expectEqualStrings("{\"method\":\"exit\"}", second_payload);
    try std.testing.expect((try decoder.next()) == null);
}

test "LSP decoder validates Content-Length" {
    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    try decoder.feed("X-Test: value\r\n\r\n{}");
    try std.testing.expectError(error.MissingContentLength, decoder.next());
}
