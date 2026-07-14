const std = @import("std");

pub fn isWhiteSpaceLike(ch: u21) bool {
    return isWhiteSpaceSingleLine(ch) or isLineBreak(ch);
}

pub fn isWhiteSpaceSingleLine(ch: u21) bool {
    return switch (ch) {
        ' ', '\t', '\x0B', '\x0C', 0x0085, 0x00A0, 0x1680, 0x2000...0x200A, 0x202F, 0x205F, 0x3000, 0xFEFF => true,
        else => false,
    };
}

pub fn isLineBreak(ch: u21) bool {
    return switch (ch) {
        '\n', '\r', 0x2028, 0x2029 => true,
        else => false,
    };
}

pub fn isDigit(ch: u21) bool {
    return ch >= '0' and ch <= '9';
}

pub fn isOctalDigit(ch: u21) bool {
    return ch >= '0' and ch <= '7';
}

pub fn isHexDigit(ch: u21) bool {
    return (ch >= '0' and ch <= '9') or (ch >= 'A' and ch <= 'F') or (ch >= 'a' and ch <= 'f');
}

pub fn isASCIILetter(ch: u21) bool {
    return (ch >= 'A' and ch <= 'Z') or (ch >= 'a' and ch <= 'z');
}

pub fn encodeURI(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    _ = allocator;
    // mock
    return s;
}

pub fn removeByteOrderMark(text: []const u8) []const u8 {
    if (std.mem.startsWith(u8, text, "\xEF\xBB\xBF")) {
        return text[3..];
    }
    return text;
}

pub fn stripQuotes(name: []const u8) []const u8 {
    if (name.len < 2) return name;
    const first = name[0];
    const last = name[name.len - 1];
    if (first == last and (first == '\'' or first == '"' or first == '`')) {
        return name[1 .. name.len - 1];
    }
    return name;
}

pub fn lowerFirstChar(allocator: std.mem.Allocator, str: []const u8) ![]const u8 {
    if (str.len == 0) return str;
    var result = try allocator.dupe(u8, str);
    result[0] = std.ascii.toLower(result[0]);
    return result;
}

pub fn isSurrogate(ch: u21) bool {
    return ch >= 0xD800 and ch <= 0xDFFF;
}
