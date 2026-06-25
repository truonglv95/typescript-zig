const std = @import("std");
const jsnum = @import("jsnum.zig");
const Number = jsnum.Number;
const json = @import("../json/json.zig");
const stringutil = @import("../stringutil/stringutil.zig");

pub fn toString(allocator: std.mem.Allocator, n: Number) ![]const u8 {
    if (jsnum.isNaN(n)) {
        return "NaN";
    }
    if (jsnum.isInf(n)) {
        if (n < 0) {
            return "-Infinity";
        }
        return "Infinity";
    }

    if (n >= jsnum.min_safe_integer and n <= jsnum.max_safe_integer) {
        const i: i64 = @intFromFloat(n);
        if (@as(f64, @floatFromInt(i)) == n) {
            return try std.fmt.allocPrint(allocator, "{}", .{i});
        }
    }

    return try json.marshal(allocator, n, .{});
}

pub fn fromString(s: []const u8) Number {
    var trimmed = s;
    while (trimmed.len > 0) {
        const decoded = std.unicode.utf8Decode(trimmed) catch break;
        if (!isStrWhiteSpace(decoded)) break;
        const size = std.unicode.utf8ByteSequenceLength(trimmed[0]) catch 1;
        trimmed = trimmed[size..];
    }
    
    // Reverse trim
    // We can use std.mem.trim, but with a custom function.
    trimmed = trimWhiteSpaceFn(trimmed);

    if (trimmed.len == 0) {
        return 0;
    }
    if (std.mem.eql(u8, trimmed, "Infinity") or std.mem.eql(u8, trimmed, "+Infinity")) {
        return jsnum.inf(1);
    }
    if (std.mem.eql(u8, trimmed, "-Infinity")) {
        return jsnum.inf(-1);
    }

    // Check if it only contains valid number runes
    var it = std.unicode.Utf8Iterator{ .bytes = trimmed, .i = 0 };
    while (it.nextCodepoint()) |r| {
        if (!isNumberRune(r)) {
            return jsnum.nan();
        }
    }

    if (tryParseInt(trimmed)) |parsed| {
        return parsed;
    }

    var is_negative = false;
    var parse_s = trimmed;
    if (std.mem.startsWith(u8, parse_s, "-")) {
        is_negative = true;
        parse_s = parse_s[1..];
    } else if (std.mem.startsWith(u8, parse_s, "+")) {
        parse_s = parse_s[1..];
    }

    if (parse_s.len > 0) {
        const first = std.unicode.utf8Decode(parse_s) catch 0;
        if (!stringutil.isDigit(first) and first != '.') {
            return jsnum.nan();
        }
    } else {
        return jsnum.nan();
    }

    const f = parseFloatString(parse_s);
    if (std.math.isNan(f)) {
        return jsnum.nan();
    }

    const sign: f64 = if (is_negative) -1.0 else 1.0;
    return std.math.copysign(f64, f, sign);
}

fn trimWhiteSpaceFn(s: []const u8) []const u8 {
    var start: usize = 0;
    var it = std.unicode.Utf8Iterator{ .bytes = s, .i = 0 };
    while (it.nextCodepoint()) |c| {
        if (!isStrWhiteSpace(c)) break;
        start = it.i;
    }
    
    var end: usize = s.len;
    // We should technically parse backwards, but let's do a simple scan for now.
    var it_end = std.unicode.Utf8Iterator{ .bytes = s, .i = start };
    var last_non_ws: usize = start;
    while (it_end.nextCodepoint()) |c| {
        if (!isStrWhiteSpace(c)) {
            last_non_ws = it_end.i;
        }
    }
    end = last_non_ws;
    return s[start..end];
}

fn isStrWhiteSpace(r: u21) bool {
    switch (r) {
        '\n', '\r', 0x2028, 0x2029 => return true,
        '\t', 0x0B, 0x0C, 0xFEFF => return true,
        ' ' => return true,
        else => return false, // Unicode Zs class not fully covered here, assume space
    }
}

fn tryParseInt(s: []const u8) ?Number {
    if (s.len > 2) {
        const prefix = s[0..2];
        const rest = s[2..];
        if (std.mem.eql(u8, prefix, "0b") or std.mem.eql(u8, prefix, "0B")) {
            if (!isAllBinaryDigits(rest)) return jsnum.nan();
            const i = std.fmt.parseInt(i64, rest, 2) catch return null;
            return @as(Number, @floatFromInt(i));
        }
        if (std.mem.eql(u8, prefix, "0o") or std.mem.eql(u8, prefix, "0O")) {
            if (!isAllOctalDigits(rest)) return jsnum.nan();
            const i = std.fmt.parseInt(i64, rest, 8) catch return null;
            return @as(Number, @floatFromInt(i));
        }
        if (std.mem.eql(u8, prefix, "0x") or std.mem.eql(u8, prefix, "0X")) {
            if (!isAllHexDigits(rest)) return jsnum.nan();
            const i = std.fmt.parseInt(i64, rest, 16) catch return null;
            return @as(Number, @floatFromInt(i));
        }
    }

    const trimmed = trimLeadingZeros(s);
    if (!isAllDigits(trimmed)) {
        return null; // Go code returns 0, false
    }

    if (std.fmt.parseInt(i64, trimmed, 10)) |i| {
        return @as(Number, @floatFromInt(i));
    } else |_| {
        // Fallback to f64 parsing if integer is too big
        if (std.fmt.parseFloat(f64, s)) |f| {
            return f;
        } else |_| {
            return jsnum.nan();
        }
    }
}

fn parseFloatString(s: []const u8) f64 {
    // simplified parsing: just use Zig's parseFloat
    if (std.fmt.parseFloat(f64, s)) |f| {
        return f;
    } else |_| {
        return std.math.nan(f64);
    }
}

fn trimLeadingZeros(s: []const u8) []const u8 {
    if (std.mem.startsWith(u8, s, "0")) {
        const trimmed = std.mem.trimLeft(u8, s, "0");
        if (trimmed.len == 0) {
            return "0";
        }
        return trimmed;
    }
    return s;
}

fn isAllDigits(s: []const u8) bool {
    for (s) |b| {
        if (!stringutil.isDigit(b)) return false;
    }
    return true;
}

fn isAllBinaryDigits(s: []const u8) bool {
    for (s) |b| {
        if (b != '0' and b != '1') return false;
    }
    return true;
}

fn isAllOctalDigits(s: []const u8) bool {
    for (s) |b| {
        if (!stringutil.isOctalDigit(b)) return false;
    }
    return true;
}

fn isAllHexDigits(s: []const u8) bool {
    for (s) |b| {
        if (!stringutil.isHexDigit(b)) return false;
    }
    return true;
}

fn isNumberRune(r: u21) bool {
    if (stringutil.isDigit(r)) return true;
    if (r >= 'a' and r <= 'f') return true;
    if (r >= 'A' and r <= 'F') return true;
    switch (r) {
        '.', '-', '+', 'x', 'X', 'o', 'O' => return true,
        else => return false,
    }
}
