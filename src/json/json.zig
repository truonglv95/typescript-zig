const std = @import("std");

pub const Options = struct {
    allowInvalidUTF8: bool = true,
};

pub fn marshal(allocator: std.mem.Allocator, in: anytype, opts: Options) ![]u8 {
    _ = opts;
    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();
    try std.json.stringify(in, .{}, list.writer());
    return list.toOwnedSlice();
}

pub fn marshalEncode(out: anytype, in: anytype, opts: Options) !void {
    _ = opts;
    try std.json.stringify(in, .{}, out);
}

pub fn marshalWrite(writer: anytype, in: anytype, opts: Options) !void {
    _ = opts;
    try std.json.stringify(in, .{}, writer);
}

pub fn marshalIndent(allocator: std.mem.Allocator, in: anytype, prefix: []const u8, indent: []const u8) ![]u8 {
    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();
    // In Zig std.json.stringify, there are no simple prefix/indent options out of the box in the same way,
    // so we approximate it if needed. For now, just stringify unindented.
    _ = prefix;
    _ = indent;
    try std.json.stringify(in, .{}, list.writer());
    return list.toOwnedSlice();
}

pub fn unmarshal(allocator: std.mem.Allocator, in: []const u8, out: anytype, opts: Options) !void {
    _ = opts;
    const parsed = try std.json.parseFromSlice(@TypeOf(out.*), allocator, in, .{});
    defer parsed.deinit();
    out.* = parsed.value;
}

pub const Value = std.json.Value;
// In Zig std.json, we don't have exactly the same Decoder/Encoder streaming types like in go-json-experiment,
// but we will alias whatever is closest.
pub const Decoder = std.json.Scanner;
pub const Encoder = std.json.WriteStream(std.ArrayList(u8).Writer, .{});
pub const Kind = enum { null, bool, number, string, array, object };

pub fn newDecoder(r: anytype) Decoder {
    _ = r;
    unreachable;
}

pub fn allowDuplicateNames(allow: bool) Options {
    _ = allow;
    return Options{};
}

pub fn deterministic(v: bool) Options {
    _ = v;
    return Options{};
}

pub fn withIndent(indent: []const u8) Options {
    _ = indent;
    return Options{};
}

pub const beginObject = 0;
pub const endObject = 1;
pub const nullValue = 2;
pub const beginArray = 3;
pub const endArray = 4;

