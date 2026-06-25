const std = @import("std");

pub const PseudoBigInt = struct {
    negative: bool,
    base10Value: []const u8,

    pub fn init(value: []const u8, negative: bool) PseudoBigInt {
        const trimmed = std.mem.trimLeft(u8, value, "0");
        return PseudoBigInt{
            .negative = negative and trimmed.len != 0,
            .base10Value = trimmed,
        };
    }

    pub fn format(
        self: PseudoBigInt,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        if (self.base10Value.len == 0) {
            try writer.writeAll("0");
            return;
        }
        if (self.negative) {
            try writer.writeAll("-");
        }
        try writer.writeAll(self.base10Value);
    }

    pub fn sign(self: PseudoBigInt) i32 {
        if (self.base10Value.len == 0) {
            return 0;
        }
        if (self.negative) {
            return -1;
        }
        return 1;
    }
};

pub fn parseValidBigInt(allocator: std.mem.Allocator, text: []const u8) !PseudoBigInt {
    var is_negative = false;
    var trimmed_text = text;
    if (std.mem.startsWith(u8, trimmed_text, "-")) {
        is_negative = true;
        trimmed_text = trimmed_text[1..];
    }
    const val = try parsePseudoBigInt(allocator, trimmed_text);
    return PseudoBigInt.init(val, is_negative);
}

pub fn parsePseudoBigInt(allocator: std.mem.Allocator, stringValue: []const u8) ![]const u8 {
    var val = stringValue;
    if (std.mem.endsWith(u8, val, "n")) {
        val = val[0 .. val.len - 1];
    }
    var b1: u8 = 0;
    if (val.len > 1) {
        b1 = val[1];
    }
    switch (b1) {
        'b', 'B', 'o', 'O', 'x', 'X' => {
            // Not decimal.
        },
        else => {
            val = std.mem.trimLeft(u8, val, "0");
            if (val.len == 0) {
                return "0";
            }
            return val;
        },
    }

    // In Zig, we attempt to parse it to a large integer type and then format it back as decimal.
    // If it exceeds u128, it will fail.
    if (std.fmt.parseInt(u128, val, 0)) |parsed| {
        return try std.fmt.allocPrint(allocator, "{}", .{parsed});
    } else |_| {
        std.debug.panic("Failed to parse big int: {s}", .{stringValue});
    }
}
