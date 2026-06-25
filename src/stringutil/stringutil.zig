const std = @import("std");

pub fn isWhiteSpaceLike(ch: u21) bool {
    return isWhiteSpaceSingleLine(ch) or isLineBreak(ch);
}

pub fn isWhiteSpaceSingleLine(ch: u21) bool {
    // Note: nextLine is in the Zs space, and should be considered to be a whitespace.
    // It is explicitly not a line-break as it isn't in the exact set specified by EcmaScript.
    switch (ch) {
        ' ', // space
        '\t', // tab
        0x000B, // verticalTab (\v)
        0x000C, // formFeed (\f)
        0x0085, // nextLine
        0x00A0, // nonBreakingSpace
        0x1680, // ogham
        0x2000, // enQuad
        0x2001, // emQuad
        0x2002, // enSpace
        0x2003, // emSpace
        0x2004, // threePerEmSpace
        0x2005, // fourPerEmSpace
        0x2006, // sixPerEmSpace
        0x2007, // figureSpace
        0x2008, // punctuationEmSpace
        0x2009, // thinSpace
        0x200A, // hairSpace
        0x200B, // zeroWidthSpace
        0x202F, // narrowNoBreakSpace
        0x205F, // mathematicalSpace
        0x3000, // ideographicSpace
        0xFEFF, // byteOrderMark
        => return true,
        else => return false,
    }
}

pub fn isLineBreak(ch: u21) bool {
    // ES5 7.3:
    // The ECMAScript line terminator characters are listed in Table 3.
    switch (ch) {
        '\n', // lineFeed
        '\r', // carriageReturn
        0x2028, // lineSeparator
        0x2029, // paragraphSeparator
        => return true,
        else => return false,
    }
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

pub fn splitLines(allocator: std.mem.Allocator, text: []const u8) ![][]const u8 {
    var lines = std.ArrayList([]const u8).init(allocator);
    var start: usize = 0;
    var pos: usize = 0;
    while (pos < text.len) {
        switch (text[pos]) {
            '\r' => {
                if (pos + 1 < text.len and text[pos + 1] == '\n') {
                    try lines.append(text[start..pos]);
                    pos += 2;
                    start = pos;
                    continue;
                }
                try lines.append(text[start..pos]);
                pos += 1;
                start = pos;
                continue;
            },
            '\n' => {
                try lines.append(text[start..pos]);
                pos += 1;
                start = pos;
                continue;
            },
            else => {
                pos += 1;
            },
        }
    }
    if (start < text.len) {
        try lines.append(text[start..]);
    }
    return lines.toOwnedSlice();
}

pub fn guessIndentation(lines: []const []const u8) usize {
    const MAX_SMI_X86: usize = 0x3fff_ffff;
    var indentation: usize = MAX_SMI_X86;
    for (lines) |line| {
        if (line.len == 0) continue;
        var i: usize = 0;
        while (i < line.len and i < indentation) {
            const length = std.unicode.utf8ByteSequenceLength(line[i]) catch 1;
            if (i + length > line.len) {
                break;
            }
            const ch = std.unicode.utf8Decode(line[i .. i + length]) catch {
                break;
            };
            if (!isWhiteSpaceLike(ch)) {
                break;
            }
            i += length;
        }
        if (i < indentation) {
            indentation = i;
        }
        if (indentation == 0) {
            return 0;
        }
    }
    if (indentation == MAX_SMI_X86) {
        return 0;
    }
    return indentation;
}

const upperhex = "0123456789ABCDEF";

fn shouldEscapeForEncodeURI(b: u8) bool {
    switch (b) {
        'A'...'Z' => return false,
        'a'...'z' => return false,
        '0'...'9' => return false,
        ';', '/', '?', ':', '@', '&', '=', '+', '$', ',', '#', '-', '_', '.', '!', '~', '*', '\'', '(', ')' => return false,
        else => return true,
    }
}

pub fn encodeURI(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    var builder = std.ArrayList(u8).init(allocator);
    for (s) |b| {
        if (!shouldEscapeForEncodeURI(b)) {
            try builder.append(b);
            continue;
        }
        try builder.append('%');
        try builder.append(upperhex[b >> 4]);
        try builder.append(upperhex[b & 0x0f]);
    }
    return builder.toOwnedSlice();
}

fn getByteOrderMarkLength(text: []const u8) usize {
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

pub fn removeByteOrderMark(text: []const u8) []const u8 {
    const length = getByteOrderMarkLength(text);
    if (length > 0) {
        return text[length..];
    }
    return text;
}

pub fn addUTF8ByteOrderMark(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    if (getByteOrderMarkLength(text) == 0) {
        return std.fmt.allocPrint(allocator, "\xEF\xBB\xBF{s}", .{text});
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

pub fn unquoteString(allocator: std.mem.Allocator, str: []const u8) ![]const u8 {
    const inner = stripQuotes(str);
    var builder = std.ArrayList(u8).init(allocator);
    try builder.ensureTotalCapacity(inner.len);
    var i: usize = 0;
    while (i < inner.len) {
        if (inner[i] == '\\' and i + 1 < inner.len and inner[i + 1] != '\n') {
            try builder.append(inner[i + 1]);
            i += 2;
        } else {
            try builder.append(inner[i]);
            i += 1;
        }
    }
    return builder.toOwnedSlice();
}

pub fn lowerFirstChar(allocator: std.mem.Allocator, str: []const u8) ![]const u8 {
    if (str.len == 0) return str;
    const len = std.unicode.utf8ByteSequenceLength(str[0]) catch 1;
    if (len > str.len) return str;
    const char = std.unicode.utf8Decode(str[0..len]) catch return str;
    
    var lower_char = char;
    if (char >= 'A' and char <= 'Z') {
        lower_char = char + 32;
    }
    
    var buf: [4]u8 = undefined;
    const encoded_len = std.unicode.utf8Encode(lower_char, &buf) catch return str;
    
    var result = try allocator.alloc(u8, encoded_len + str.len - len);
    @memcpy(result[0..encoded_len], buf[0..encoded_len]);
    @memcpy(result[encoded_len..], str[len..]);
    return result;
}

pub fn truncateByRunes(str: []const u8, max_length: usize) []const u8 {
    if (str.len < max_length) {
        return str;
    }
    if (max_length == 0) {
        return "";
    }
    var rune_count: usize = 0;
    var i: usize = 0;
    while (i < str.len) {
        rune_count += 1;
        if (rune_count > max_length) {
            return str[0..i];
        }
        const len = std.unicode.utf8ByteSequenceLength(str[i]) catch 1;
        i += len;
    }
    return str;
}

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
    if (high >= 0xD800 and high < 0xDC00 and low >= 0xDC00 and low < 0xE000) {
        return ((high - 0xD800) << 10) | (low - 0xDC00) + 0x10000;
    }
    return 0xFFFD;
}

pub fn codePointToSurrogatePair(ch: u21) struct { high: u21, low: u21 } {
    if (ch >= 0x10000 and ch <= 0x10FFFF) {
        const r = ch - 0x10000;
        return .{
            .high = 0xD800 + (r >> 10),
            .low = 0xDC00 + (r & 0x3FF),
        };
    }
    return .{ .high = 0xFFFD, .low = 0xFFFD };
}

const surrogateUTF8Lead: u8 = 0xED;
const surrogateUTF8LeadBits: u21 = 0xD000;
const utf8ContMarker: u8 = 0x80;
const utf8ContMax: u8 = 0xBF;
const utf8ContMask: u8 = 0x3F;
const surrogateUTF8Byte1Min: u8 = 0xA0;
const surrogateUTF8Byte1Max: u8 = 0xBF;

pub fn encodeJSStringRune(allocator: std.mem.Allocator, ch: u21) ![]const u8 {
    if (isSurrogate(ch)) {
        var res = try allocator.alloc(u8, 3);
        res[0] = surrogateUTF8Lead;
        res[1] = utf8ContMarker | @as(u8, @intCast((ch >> 6) & utf8ContMask));
        res[2] = utf8ContMarker | @as(u8, @intCast(ch & utf8ContMask));
        return res;
    }
    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(ch, &buf) catch return "";
    const res = try allocator.alloc(u8, len);
    @memcpy(res, buf[0..len]);
    return res;
}

pub fn decodeJSStringRune(s: []const u8) struct { r: u21, size: usize } {
    if (s.len >= 3 and
        s[0] == surrogateUTF8Lead and
        s[1] >= surrogateUTF8Byte1Min and s[1] <= surrogateUTF8Byte1Max and
        s[2] >= utf8ContMarker and s[2] <= utf8ContMax)
    {
        const r = surrogateUTF8LeadBits | (@as(u21, s[1] & utf8ContMask) << 6) | @as(u21, s[2] & utf8ContMask);
        return .{ .r = r, .size = 3 };
    }
    if (s.len == 0) return .{ .r = 0, .size = 0 };
    const len = std.unicode.utf8ByteSequenceLength(s[0]) catch {
        return .{ .r = 0xFFFD, .size = 1 };
    };
    if (len > s.len) return .{ .r = 0xFFFD, .size = 1 };
    const r = std.unicode.utf8Decode(s[0..len]) catch {
        return .{ .r = 0xFFFD, .size = 1 };
    };
    return .{ .r = r, .size = len };
}

pub fn combineSurrogatePairs(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    if (std.mem.indexOfScalar(u8, s, surrogateUTF8Lead) == null) {
        return s;
    }
    var b = std.ArrayList(u8).init(allocator);
    try b.ensureTotalCapacity(s.len);
    var i: usize = 0;
    while (i < s.len) {
        const decoded = decodeJSStringRune(s[i..]);
        if (isHighSurrogate(decoded.r)) {
            const low_decoded = decodeJSStringRune(s[i + decoded.size ..]);
            if (isLowSurrogate(low_decoded.r)) {
                var buf: [4]u8 = undefined;
                const r = surrogatePairToCodePoint(decoded.r, low_decoded.r);
                const encoded_len = std.unicode.utf8Encode(r, &buf) catch 0;
                try b.appendSlice(buf[0..encoded_len]);
                i += decoded.size + low_decoded.size;
                continue;
            }
        }
        try b.appendSlice(s[i .. i + decoded.size]);
        i += decoded.size;
    }
    return b.toOwnedSlice();
}
