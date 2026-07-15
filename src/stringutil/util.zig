const std = @import("std");

/// Port of stringutil/util.go — full string utility functions.

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

pub fn containsNonASCII(s: []const u8) bool {
    for (s) |b| {
        if (b >= 0x80) return true;
    }
    return false;
}

/// Port of SplitLines. Splits text by \n and \r\n.
pub fn splitLines(allocator: std.mem.Allocator, text: []const u8) ![][]const u8 {
    var lines = std.ArrayList([]const u8).empty;
    var start: usize = 0;
    var pos: usize = 0;
    while (pos < text.len) {
        switch (text[pos]) {
            '\r' => {
                if (pos + 1 < text.len and text[pos + 1] == '\n') {
                    try lines.append(allocator, text[start..pos]);
                    pos += 2;
                    start = pos;
                    continue;
                }
                try lines.append(allocator, text[start..pos]);
                pos += 1;
                start = pos;
                continue;
            },
            '\n' => {
                try lines.append(allocator, text[start..pos]);
                pos += 1;
                start = pos;
                continue;
            },
            else => pos += 1,
        }
    }
    if (start < text.len) {
        try lines.append(allocator, text[start..]);
    }
    return lines.toOwnedSlice(allocator);
}

/// Port of GuessIndentation. Returns the minimum indentation of non-empty lines.
pub fn guessIndentation(lines: []const []const u8) usize {
    const max_smi: usize = 0x3fffffff;
    var indentation: usize = max_smi;
    for (lines) |line| {
        if (line.len == 0) continue;
        var i: usize = 0;
        while (i < line.len and i < indentation) {
            const ch_len = std.unicode.utf8ByteSequenceLength(line[i]) catch 1;
            if (i + ch_len > line.len) break;
            const ch = std.unicode.utf8Decode(line[i .. i + ch_len]) catch break;
            if (!isWhiteSpaceLike(ch)) break;
            i += ch_len;
        }
        if (i < indentation) indentation = i;
        if (indentation == 0) return 0;
    }
    if (indentation == max_smi) return 0;
    return indentation;
}

const upperhex = "0123456789ABCDEF";

fn shouldEscapeForEncodeURI(b: u8) bool {
    if (b >= 'A' and b <= 'Z') return false;
    if (b >= 'a' and b <= 'z') return false;
    if (b >= '0' and b <= '9') return false;
    return switch (b) {
        ';', '/', '?', ':', '@', '&', '=', '+', '$', ',', '#', '-', '_', '.', '!', '~', '*', '\'', '(', ')' => false,
        else => true,
    };
}

/// Port of EncodeURI. Percent-encodes a URI string.
pub fn encodeURI(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    var result = std.ArrayList(u8).empty;
    for (s) |b| {
        if (!shouldEscapeForEncodeURI(b)) {
            try result.append(allocator, b);
        } else {
            try result.append(allocator, '%');
            try result.append(allocator, upperhex[b >> 4]);
            try result.append(allocator, upperhex[b & 0x0f]);
        }
    }
    return result.toOwnedSlice(allocator);
}

/// Port of getByteOrderMarkLength.
pub fn getByteOrderMarkLength(text: []const u8) usize {
    if (text.len >= 1) {
        const ch0 = text[0];
        if (ch0 == 0xfe) {
            if (text.len >= 2 and text[1] == 0xff) return 2; // utf16be
            return 0;
        }
        if (ch0 == 0xff) {
            if (text.len >= 2 and text[1] == 0xfe) return 2; // utf16le
            return 0;
        }
        if (ch0 == 0xef) {
            if (text.len >= 3 and text[1] == 0xbb and text[2] == 0xbf) return 3; // utf8
            return 0;
        }
    }
    return 0;
}

/// Port of RemoveByteOrderMark.
pub fn removeByteOrderMark(text: []const u8) []const u8 {
    const length = getByteOrderMarkLength(text);
    if (length > 0) return text[length..];
    return text;
}

/// Port of AddUTF8ByteOrderMark.
pub fn addUTF8ByteOrderMark(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    if (getByteOrderMarkLength(text) == 0) {
        return try std.mem.concat(allocator, u8, &[_][]const u8{ "\xEF\xBB\xBF", text });
    }
    return text;
}

/// Port of StripQuotes.
pub fn stripQuotes(name: []const u8) []const u8 {
    if (name.len < 2) return name;
    const first = name[0];
    const last = name[name.len - 1];
    if (first == last and (first == '\'' or first == '"' or first == '`')) {
        return name[1 .. name.len - 1];
    }
    return name;
}

/// Port of UnquoteString.
pub fn unquoteString(allocator: std.mem.Allocator, str: []const u8) ![]const u8 {
    const inner = stripQuotes(str);
    // Replace \X with X (remove backslash before any character)
    var result = std.ArrayList(u8).empty;
    var i: usize = 0;
    while (i < inner.len) {
        if (inner[i] == '\\' and i + 1 < inner.len) {
            try result.append(allocator, inner[i + 1]);
            i += 2;
        } else {
            try result.append(allocator, inner[i]);
            i += 1;
        }
    }
    return result.toOwnedSlice(allocator);
}

/// Port of LowerFirstChar.
pub fn lowerFirstChar(allocator: std.mem.Allocator, str: []const u8) ![]const u8 {
    if (str.len == 0) return str;
    var result = try allocator.dupe(u8, str);
    result[0] = std.ascii.toLower(result[0]);
    return result;
}

/// Port of TruncateByRunes. Truncates string by rune count.
pub fn truncateByRunes(str: []const u8, max_length: usize) []const u8 {
    if (str.len < max_length) return str;
    if (max_length == 0) return "";
    var rune_count: usize = 0;
    var i: usize = 0;
    while (i < str.len) {
        const len = std.unicode.utf8ByteSequenceLength(str[i]) catch 1;
        rune_count += 1;
        if (rune_count > max_length) return str[0..i];
        i += len;
    }
    return str;
}

// === Surrogate pair utilities ===

pub const SurrogateLowStart: u21 = 0xDC00;

pub fn isHighSurrogate(ch: u21) bool {
    return isSurrogate(ch) and ch < SurrogateLowStart;
}

pub fn isLowSurrogate(ch: u21) bool {
    return isSurrogate(ch) and ch >= SurrogateLowStart;
}

pub fn isSurrogate(ch: u21) bool {
    return ch >= 0xD800 and ch <= 0xDFFF;
}

pub fn surrogatePairToCodePoint(high: u21, low: u21) u21 {
    return 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00);
}

pub fn codePointToSurrogatePair(ch: u21) struct { high: u21, low: u21 } {
    const v = ch - 0x10000;
    return .{ .high = 0xD800 + (v >> 10), .low = 0xDC00 + (v & 0x3FF) };
}

// === JS string rune encoding (surrogate support) ===

const surrogate_utf8_lead: u8 = 0xED;
const surrogate_utf8_lead_bits: u21 = 0xD000;
const utf8_cont_marker: u8 = 0x80;
const utf8_cont_mask: u8 = 0x3F;
const surrogate_utf8_byte1_min: u8 = 0xA0;
const surrogate_utf8_byte1_max: u8 = 0xBF;
const utf8_cont_max: u8 = 0xBF;

/// Port of EncodeJSStringRune. Encodes a rune to a JS string, handling
/// surrogates via CESU-8/WTF-8 sentinel bytes.
pub fn encodeJSStringRune(allocator: std.mem.Allocator, ch: u21) ![]u8 {
    if (isSurrogate(ch)) {
        var buf = try allocator.alloc(u8, 3);
        buf[0] = surrogate_utf8_lead;
        buf[1] = utf8_cont_marker | @as(u8, @intCast((ch >> 6) & utf8_cont_mask));
        buf[2] = utf8_cont_marker | @as(u8, @intCast(ch & utf8_cont_mask));
        return buf;
    }
    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(ch, &buf) catch return try allocator.dupe(u8, &[_]u8{0});
    return try allocator.dupe(u8, buf[0..len]);
}

/// Port of DecodeJSStringRune. Decodes a rune from a JS string, handling
/// surrogate sentinel bytes. Returns the rune and the number of bytes consumed.
pub fn decodeJSStringRune(s: []const u8) struct { rune: u21, size: usize } {
    if (s.len >= 3 and
        s[0] == surrogate_utf8_lead and
        s[1] >= surrogate_utf8_byte1_min and s[1] <= surrogate_utf8_byte1_max and
        s[2] >= utf8_cont_marker and s[2] <= utf8_cont_max)
    {
        const rune = surrogate_utf8_lead_bits |
            @as(u21, @intCast(s[1] & utf8_cont_mask)) << 6 |
            @as(u21, @intCast(s[2] & utf8_cont_mask));
        return .{ .rune = rune, .size = 3 };
    }
    const r = std.unicode.utf8Decode(s[0..std.unicode.utf8ByteSequenceLength(s[0]) catch 1]) catch {
        return .{ .rune = 0xFFFD, .size = 1 };
    };
    const size = std.unicode.utf8ByteSequenceLength(s[0]) catch 1;
    return .{ .rune = r, .size = size };
}

/// Port of CombineSurrogatePairs. Merges adjacent high+low surrogate
/// sentinel pairs into single supplementary code points.
pub fn combineSurrogatePairs(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    if (std.mem.indexOfScalar(u8, s, surrogate_utf8_lead) == null) return s;
    var result = std.ArrayList(u8).empty;
    var i: usize = 0;
    while (i < s.len) {
        const decoded = decodeJSStringRune(s[i..]);
        if (isHighSurrogate(decoded.rune) and i + decoded.size < s.len) {
            const low_decoded = decodeJSStringRune(s[i + decoded.size ..]);
            if (isLowSurrogate(low_decoded.rune)) {
                const cp = surrogatePairToCodePoint(decoded.rune, low_decoded.rune);
                var buf: [4]u8 = undefined;
                const len = std.unicode.utf8Encode(cp, &buf) catch {
                    try result.appendSlice(allocator, s[i .. i + decoded.size]);
                    i += decoded.size;
                    continue;
                };
                try result.appendSlice(allocator, buf[0..len]);
                i += decoded.size + low_decoded.size;
                continue;
            }
        }
        try result.appendSlice(allocator, s[i .. i + decoded.size]);
        i += decoded.size;
    }
    return result.toOwnedSlice(allocator);
}
