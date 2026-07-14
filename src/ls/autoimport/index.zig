const std = @import("std");

/// Index stores entries with an index mapping uppercase letters to entries whose name
/// starts with that letter, and lowercase letters to entries whose name contains a
/// word starting with that letter.
pub fn Index(comptime T: type) type {
    return struct {
        entries: std.ArrayListUnmanaged(T),
        index: std.AutoHashMapUnmanaged(u21, std.ArrayListUnmanaged(u32)),

        const Self = @This();

        pub fn init() Self {
            return .{
                .entries = .empty,
                .index = .empty,
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.entries.deinit(allocator);
            var it = self.index.valueIterator();
            while (it.next()) |list| {
                list.deinit(allocator);
            }
            self.index.deinit(allocator);
        }

        inline fn getName(entry: T) []const u8 {
            if (@TypeOf(entry) == []const u8) return entry;
            return entry.name();
        }

        pub fn find(self: *const Self, allocator: std.mem.Allocator, search_name: []const u8, case_sensitive: bool) ![]T {
            if (self.entries.items.len == 0 or search_name.len == 0) {
                return &[_]T{};
            }

            var iter = std.unicode.Utf8View.init(search_name) catch return &[_]T{};
            var it = iter.iterator();
            const first_rune = it.nextCodepoint() orelse return &[_]T{};
            const first_rune_upper = toUpper(first_rune);

            const candidates = self.index.get(first_rune_upper) orelse return &[_]T{};

            var results = std.ArrayListUnmanaged(T).empty;
            errdefer results.deinit(allocator);

            for (candidates.items) |entry_index| {
                const entry = self.entries.items[entry_index];
                const entry_name = getName(entry);

                if (case_sensitive) {
                    if (std.mem.eql(u8, entry_name, search_name)) {
                        try results.append(allocator, entry);
                    }
                } else {
                    if (std.ascii.eqlIgnoreCase(entry_name, search_name)) {
                        try results.append(allocator, entry);
                    }
                }
            }

            return results.toOwnedSlice(allocator);
        }

        pub fn searchWordPrefix(self: *const Self, allocator: std.mem.Allocator, prefix: []const u8) ![]T {
            if (self.entries.items.len == 0) {
                return &[_]T{};
            }
            if (prefix.len == 0) {
                var results = std.ArrayListUnmanaged(T).empty;
                try results.appendSlice(allocator, self.entries.items);
                return results.toOwnedSlice(allocator);
            }

            // Go's prefix = strings.ToLower(prefix)
            // We just use a custom containsCharsInOrder that does case-insensitive comparison.
            
            var iter = std.unicode.Utf8View.init(prefix) catch return &[_]T{};
            var it = iter.iterator();
            const first_rune = it.nextCodepoint() orelse return &[_]T{};
            
            const first_rune_upper = toUpper(first_rune);
            const first_rune_lower = toLower(first_rune);

            const name_starts = self.index.get(first_rune_upper) orelse std.ArrayListUnmanaged(u32).empty;
            const word_starts = if (first_rune_upper != first_rune_lower)
                (self.index.get(first_rune_lower) orelse std.ArrayListUnmanaged(u32).empty)
            else
                std.ArrayListUnmanaged(u32).empty;

            const count = name_starts.items.len + word_starts.items.len;
            if (count == 0) {
                return &[_]T{};
            }

            var results = std.ArrayListUnmanaged(T).empty;
            errdefer results.deinit(allocator);

            const lists = [_][]const u32{ name_starts.items, word_starts.items };
            for (lists) |starts| {
                for (starts) |i| {
                    const entry = self.entries.items[i];
                    if (containsCharsInOrder(getName(entry), prefix)) {
                        try results.append(allocator, entry);
                    }
                }
            }
            return results.toOwnedSlice(allocator);
        }

        pub fn insertAsWords(self: *Self, allocator: std.mem.Allocator, value: T) !void {
            const entry_name = getName(value);
            if (entry_name.len == 0) {
                @panic("Cannot index entry with empty name");
            }
            const entry_index: u32 = @intCast(self.entries.items.len);
            try self.entries.append(allocator, value);

            var seen_runes = std.AutoHashMap(u21, void).init(allocator);
            defer seen_runes.deinit();

            const indices = try wordIndices(allocator, entry_name);
            defer allocator.free(indices);

            for (indices, 0..) |start, i| {
                const substr = entry_name[start..];
                var iter = std.unicode.Utf8View.init(substr) catch continue;
                var it = iter.iterator();
                var first_rune = it.nextCodepoint() orelse continue;

                if (i == 0) {
                    first_rune = toUpper(first_rune);
                    var list = self.index.getPtr(first_rune);
                    if (list == null) {
                        try self.index.put(allocator, first_rune, .empty);
                        list = self.index.getPtr(first_rune);
                    }
                    try list.?.append(allocator, entry_index);
                    try seen_runes.put(first_rune, {});
                } else {
                    first_rune = toLower(first_rune);
                    if (!seen_runes.contains(first_rune)) {
                        var list = self.index.getPtr(first_rune);
                        if (list == null) {
                            try self.index.put(allocator, first_rune, .empty);
                            list = self.index.getPtr(first_rune);
                        }
                        try list.?.append(allocator, entry_index);
                        try seen_runes.put(first_rune, {});
                    }
                }
            }
        }

        pub fn clone(self: *const Self, allocator: std.mem.Allocator, filter: *const fn (T) bool) !Self {
            var new_idx = Self.init();
            errdefer new_idx.deinit(allocator);

            var old_to_new = std.AutoHashMap(u32, u32).init(allocator);
            defer old_to_new.deinit();

            for (self.entries.items, 0..) |entry, old_index| {
                if (filter(entry)) {
                    const new_index: u32 = @intCast(new_idx.entries.items.len);
                    try new_idx.entries.append(allocator, entry);
                    try old_to_new.put(@intCast(old_index), new_index);
                }
            }

            var it = self.index.iterator();
            while (it.next()) |kv| {
                const r = kv.key_ptr.*;
                const old_indices = kv.value_ptr.items;

                var new_indices = std.ArrayListUnmanaged(u32).empty;
                for (old_indices) |old_index| {
                    if (old_to_new.get(old_index)) |new_index| {
                        try new_indices.append(allocator, new_index);
                    }
                }

                if (new_indices.items.len > 0) {
                    try new_idx.index.put(allocator, r, new_indices);
                } else {
                    new_indices.deinit(allocator);
                }
            }

            return new_idx;
        }
    };
}

fn containsCharsInOrder(str: []const u8, pattern: []const u8) bool {
    var pattern_idx: usize = 0;
    
    var str_iter = std.unicode.Utf8View.init(str) catch return false;
    var str_it = str_iter.iterator();

    var pat_iter = std.unicode.Utf8View.init(pattern) catch return false;
    var pat_it = pat_iter.iterator();

    var next_pat_rune = pat_it.nextCodepoint();

    while (str_it.nextCodepoint()) |ch| {
        if (next_pat_rune) |pat_rune| {
            if (toLower(ch) == toLower(pat_rune)) {
                pattern_idx += std.unicode.utf8CodepointSequenceLength(pat_rune) catch 1;
                next_pat_rune = pat_it.nextCodepoint();
            }
        } else {
            break;
        }
    }
    return pattern_idx == pattern.len;
}

fn toUpper(c: u21) u21 {
    if (c >= 'a' and c <= 'z') {
        return c - 32;
    }
    return c;
}

fn toLower(c: u21) u21 {
    if (c >= 'A' and c <= 'Z') {
        return c + 32;
    }
    return c;
}

fn isUpper(c: u21) bool {
    return c >= 'A' and c <= 'Z';
}

fn isLower(c: u21) bool {
    return c >= 'a' and c <= 'z';
}

fn decodeLastRune(s: []const u8) u21 {
    if (s.len == 0) return 0;
    var i: usize = s.len - 1;
    while (true) {
        if (std.unicode.utf8ByteSequenceLength(s[i])) |len| {
            if (i + len == s.len) {
                return std.unicode.utf8Decode(s[i..s.len]) catch 0;
            }
        } else |_| {}
        if (i == 0) break;
        i -= 1;
    }
    return std.unicode.utf8Decode(s[0..s.len]) catch 0;
}

fn decodeFirstRune(s: []const u8) u21 {
    if (s.len == 0) return 0;
    const len = std.unicode.utf8ByteSequenceLength(s[0]) catch 1;
    if (len > s.len) return 0;
    return std.unicode.utf8Decode(s[0..len]) catch 0;
}

pub fn wordIndices(allocator: std.mem.Allocator, s: []const u8) ![]usize {
    var indices = std.ArrayListUnmanaged(usize).empty;
    errdefer indices.deinit(allocator);

    var byte_index: usize = 0;
    while (byte_index < s.len) {
        if (byte_index == 0) {
            try indices.append(allocator, byte_index);
            const len = std.unicode.utf8ByteSequenceLength(s[byte_index]) catch 1;
            byte_index += len;
            continue;
        }

        const rune_len = std.unicode.utf8ByteSequenceLength(s[byte_index]) catch 1;
        if (byte_index + rune_len > s.len) break;
        const rune_value = std.unicode.utf8Decode(s[byte_index .. byte_index + rune_len]) catch {
            byte_index += 1;
            continue;
        };

        if (rune_value == '_') {
            if (byte_index + 1 < s.len and s[byte_index + 1] != '_') {
                try indices.append(allocator, byte_index + 1);
            }
            byte_index += rune_len;
            continue;
        }

        if (isUpper(rune_value)) {
            const prev_rune = decodeLastRune(s[0..byte_index]);
            const next_rune = decodeFirstRune(s[byte_index + rune_len ..]);
            
            if (isLower(prev_rune) or isLower(next_rune)) {
                try indices.append(allocator, byte_index);
            }
        }

        byte_index += rune_len;
    }

    return indices.toOwnedSlice(allocator);
}
