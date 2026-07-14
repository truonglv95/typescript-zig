const std = @import("std");

pub const Element = union(enum) {
    slash: void,
    literal: []const u8,
    star: void,
    any_char: void,
    star_star: void,
    group: []const Glob,
    char_range: struct {
        negate: bool,
        low: u21,
        high: u21,
    },
};

pub const Glob = struct {
    elems: []const Element,

    pub fn parse(allocator: std.mem.Allocator, pattern: []const u8) !Glob {
        var p_state = ParseState{ .allocator = allocator };
        const result = try p_state.parseGlob(pattern, false);
        return result.glob;
    }

    pub fn match(self: *const Glob, input: []const u8) bool {
        return matchElems(self.elems, input);
    }
};

const ParseState = struct {
    allocator: std.mem.Allocator,

    pub fn parseGlob(self: *ParseState, pattern: []const u8, nested: bool) !struct { glob: Glob, rest: []const u8 } {
        var elems = std.ArrayList(Element).init(self.allocator);
        var rest = pattern;

        while (rest.len > 0) {
            switch (rest[0]) {
                '/' => {
                    rest = rest[1..];
                    try elems.append(.{ .slash = {} });
                },
                '*' => {
                    if (rest.len > 1 and rest[1] == '*') {
                        if ((elems.items.len > 0 and elems.items[elems.items.len - 1] != .slash) or (rest.len > 2 and rest[2] != '/')) {
                            return error.StarStarAdjacency; // ** may only be adjacent to '/'
                        }
                        rest = rest[2..];
                        try elems.append(.{ .star_star = {} });
                        continue;
                    }
                    rest = rest[1..];
                    try elems.append(.{ .star = {} });
                },
                '?' => {
                    rest = rest[1..];
                    try elems.append(.{ .any_char = {} });
                },
                '{' => {
                    var gs = std.ArrayList(Glob).init(self.allocator);
                    while (rest[0] != '}') {
                        rest = rest[1..];
                        const group_res = try self.parseGlob(rest, true);
                        if (group_res.rest.len == 0) {
                            return error.UnmatchedBrace;
                        }
                        rest = group_res.rest;
                        try gs.append(group_res.glob);
                    }
                    rest = rest[1..];
                    try elems.append(.{ .group = try gs.toOwnedSlice() });
                },
                '}', ',' => {
                    if (nested) {
                        return .{ .glob = Glob{ .elems = try elems.toOwnedSlice() }, .rest = rest };
                    }
                    rest = try self.parseLiteral(&elems, rest, false);
                },
                '[' => {
                    rest = rest[1..];
                    if (rest.len == 0) return error.BadRange;
                    var negate = false;
                    if (rest[0] == '!') {
                        rest = rest[1..];
                        negate = true;
                    }
                    const low_res = try readRangeRune(rest);
                    rest = rest[low_res.sz..];
                    if (rest.len == 0 or rest[0] != '-') return error.BadRange;
                    rest = rest[1..];

                    const high_res = try readRangeRune(rest);
                    rest = rest[high_res.sz..];
                    if (rest.len == 0 or rest[0] != ']') return error.BadRange;
                    rest = rest[1..];

                    try elems.append(.{ .char_range = .{
                        .negate = negate,
                        .low = low_res.r,
                        .high = high_res.r,
                    } });
                },
                else => {
                    rest = try self.parseLiteral(&elems, rest, nested);
                },
            }
        }

        return .{ .glob = Glob{ .elems = try elems.toOwnedSlice() }, .rest = "" };
    }

    fn parseLiteral(self: *ParseState, elems: *std.ArrayList(Element), pattern: []const u8, nested: bool) ![]const u8 {
        _ = self;
        const special_chars = if (nested) "*?{[/}," else "*?{[/";
        const end = std.mem.indexOfAny(u8, pattern, special_chars) orelse pattern.len;
        try elems.append(.{ .literal = pattern[0..end] });
        return pattern[end..];
    }
};

fn readRangeRune(input: []const u8) !struct { r: u21, sz: usize } {
    if (input.len == 0) return error.BadRange;
    const sz = std.unicode.utf8ByteSequenceLength(input[0]) catch return error.InvalidUtf8;
    if (input.len < sz) return error.InvalidUtf8;
    const r = std.unicode.utf8Decode(input[0..sz]) catch return error.InvalidUtf8;
    return .{ .r = r, .sz = sz };
}

pub fn matchElems(elems: []const Element, input: []const u8) bool {
    var in_str = input;

    // This is a naive recursive implementation similar to the Go one
    if (elems.len == 0) return in_str.len == 0;

    const elem = elems[0];
    const rest_elems = elems[1..];

    switch (elem) {
        .slash => {
            if (in_str.len == 0 or in_str[0] != '/') return false;
            while (in_str.len > 0 and in_str[0] == '/') {
                in_str = in_str[1..];
            }
            return matchElems(rest_elems, in_str);
        },
        .star_star => {
            var curr_elems = rest_elems;
            if (curr_elems.len > 0) {
                // If ** is followed by anything, it must be '/' (enforced by Parse).
                curr_elems = curr_elems[1..];
            }
            if (curr_elems.len == 0) return true;

            var temp_input = in_str;
            while (temp_input.len != 0) {
                if (matchElems(curr_elems, temp_input)) return true;
                const split_res = splitFirstSlash(temp_input);
                temp_input = split_res.rest;
            }
            return false;
        },
        .literal => |l| {
            if (!std.mem.startsWith(u8, in_str, l)) return false;
            return matchElems(rest_elems, in_str[l.len..]);
        },
        .star => {
            const split_res = splitFirstSlash(in_str);
            const seg_input = split_res.first;
            in_str = split_res.rest;

            var elem_end: usize = rest_elems.len;
            for (rest_elems, 0..) |e, i| {
                if (e == .slash) {
                    elem_end = i;
                    break;
                }
            }
            const seg_elems = rest_elems[0..elem_end];
            const next_elems = rest_elems[elem_end..];

            if (seg_elems.len == 0) {
                // trailing * matches the entire segment
                return matchElems(next_elems, in_str);
            }

            var matched = false;
            for (0..seg_input.len + 1) |i| {
                if (matchElems(seg_elems, seg_input[i..])) {
                    matched = true;
                    break;
                }
            }
            if (!matched) return false;
            return matchElems(next_elems, in_str);
        },
        .any_char => {
            if (in_str.len == 0 or in_str[0] == '/') return false;
            return matchElems(rest_elems, in_str[1..]);
        },
        .group => |g| {
            // Append remaining pattern elements to each group member
            for (g) |m| {
                // In Go, it allocates a new branch array. In Zig, we can do recursive checking.
                // Wait, it says: branch = append(m.elems, rest_elems...)
                // We'll have to allocate or just match recursively but it's not straightforward without allocating
                // Let's allocate a temporary array.
                // Since we don't have an allocator in matchElems, we can just do a hacky thing where we match m.elems
                // but what about the rest? It needs to match both.
                // Actually, `glob` matching could be done by creating a local buffer or passing an allocator.
                // Let's just use a fixed buffer for branch.
                var buf: [256]Element = undefined;
                if (m.elems.len + rest_elems.len <= buf.len) {
                    std.mem.copyForwards(Element, buf[0..m.elems.len], m.elems);
                    std.mem.copyForwards(Element, buf[m.elems.len..], rest_elems);
                    const branch = buf[0 .. m.elems.len + rest_elems.len];
                    if (matchElems(branch, in_str)) return true;
                }
            }
            return false;
        },
        .char_range => |cr| {
            if (in_str.len == 0 or in_str[0] == '/') return false;
            const sz = std.unicode.utf8ByteSequenceLength(in_str[0]) catch return false;
            if (in_str.len < sz) return false;
            const c = std.unicode.utf8Decode(in_str[0..sz]) catch return false;
            
            const in_range = (c >= cr.low and c <= cr.high);
            const matches = if (cr.negate) !in_range else in_range;
            if (!matches) return false;
            
            return matchElems(rest_elems, in_str[sz..]);
        },
    }
}

fn splitFirstSlash(input: []const u8) struct { first: []const u8, rest: []const u8 } {
    const i = std.mem.indexOfScalar(u8, input, '/') orelse return .{ .first = input, .rest = "" };
    const first = input[0..i];
    var j: usize = i;
    while (j < input.len) : (j += 1) {
        if (input[j] != '/') {
            return .{ .first = first, .rest = input[j..] };
        }
    }
    return .{ .first = first, .rest = "" };
}
