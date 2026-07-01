const std = @import("std");

pub const Position = struct { line: usize, character: usize };
pub const Range = struct { start: Position, end: Position };
pub const Change = struct { range: ?Range = null, text: []const u8 };

pub const Document = struct {
    version: i64,
    text: []u8,
};

/// In-memory overlay used by the LSP transport. Positions follow LSP's UTF-16
/// convention, while stored text remains UTF-8.
pub const DocumentStore = struct {
    allocator: std.mem.Allocator,
    documents: std.StringHashMap(Document),

    pub fn init(allocator: std.mem.Allocator) DocumentStore {
        return .{ .allocator = allocator, .documents = std.StringHashMap(Document).init(allocator) };
    }

    pub fn deinit(self: *DocumentStore) void {
        var iterator = self.documents.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.text);
        }
        self.documents.deinit();
    }

    pub fn open(self: *DocumentStore, uri: []const u8, version: i64, text: []const u8) !void {
        if (self.documents.getPtr(uri)) |document| {
            self.allocator.free(document.text);
            document.* = .{ .version = version, .text = try self.allocator.dupe(u8, text) };
            return;
        }
        try self.documents.put(try self.allocator.dupe(u8, uri), .{ .version = version, .text = try self.allocator.dupe(u8, text) });
    }

    pub fn close(self: *DocumentStore, uri: []const u8) bool {
        const removed = self.documents.fetchRemove(uri) orelse return false;
        self.allocator.free(removed.key);
        self.allocator.free(removed.value.text);
        return true;
    }

    pub fn get(self: *DocumentStore, uri: []const u8) ?*const Document {
        return self.documents.getPtr(uri);
    }

    pub fn applyChanges(self: *DocumentStore, uri: []const u8, version: i64, changes: []const Change) !void {
        const document = self.documents.getPtr(uri) orelse return error.DocumentNotOpen;
        if (version <= document.version) return error.StaleDocumentVersion;
        for (changes) |change| {
            if (change.range == null) {
                const replacement = try self.allocator.dupe(u8, change.text);
                self.allocator.free(document.text);
                document.text = replacement;
                continue;
            }
            const start = try offsetAt(document.text, change.range.?.start);
            const end = try offsetAt(document.text, change.range.?.end);
            if (end < start) return error.InvalidRange;
            const replacement = try self.allocator.alloc(u8, start + change.text.len + document.text.len - end);
            @memcpy(replacement[0..start], document.text[0..start]);
            @memcpy(replacement[start .. start + change.text.len], change.text);
            @memcpy(replacement[start + change.text.len ..], document.text[end..]);
            self.allocator.free(document.text);
            document.text = replacement;
        }
        document.version = version;
    }
};

pub fn offsetAt(text: []const u8, position: Position) !usize {
    var line: usize = 0;
    var offset: usize = 0;
    while (line < position.line) {
        const newline = std.mem.indexOfScalarPos(u8, text, offset, '\n') orelse return error.PositionOutOfRange;
        offset = newline + 1;
        line += 1;
    }

    var utf16_column: usize = 0;
    while (utf16_column < position.character) {
        if (offset >= text.len or text[offset] == '\n' or text[offset] == '\r') return error.PositionOutOfRange;
        const sequence_len = std.unicode.utf8ByteSequenceLength(text[offset]) catch return error.InvalidUtf8;
        if (offset + sequence_len > text.len) return error.InvalidUtf8;
        const codepoint = std.unicode.utf8Decode(text[offset .. offset + sequence_len]) catch return error.InvalidUtf8;
        const width: usize = if (codepoint > 0xffff) 2 else 1;
        if (utf16_column + width > position.character) return error.PositionInsideSurrogatePair;
        utf16_column += width;
        offset += sequence_len;
    }
    return offset;
}

pub fn positionAt(text: []const u8, requested_offset: usize) Position {
    const target = @min(requested_offset, text.len);
    var line: usize = 0;
    var character: usize = 0;
    var offset: usize = 0;
    while (offset < target) {
        if (text[offset] == '\n') {
            line += 1;
            character = 0;
            offset += 1;
            continue;
        }
        if (text[offset] == '\r') {
            offset += 1;
            if (offset < target and text[offset] == '\n') offset += 1;
            line += 1;
            character = 0;
            continue;
        }
        const sequence_len = std.unicode.utf8ByteSequenceLength(text[offset]) catch 1;
        if (offset + sequence_len > target) break;
        const codepoint = std.unicode.utf8Decode(text[offset .. offset + sequence_len]) catch {
            offset += 1;
            character += 1;
            continue;
        };
        character += if (codepoint > 0xffff) 2 else 1;
        offset += sequence_len;
    }
    return .{ .line = line, .character = character };
}

test "document store applies UTF-16 incremental edits and rejects stale versions" {
    var store = DocumentStore.init(std.testing.allocator);
    defer store.deinit();
    try store.open("file:///main.ts", 1, "const face = '😀';\nconst value = 1;");
    const changes = [_]Change{.{ .range = .{ .start = .{ .line = 1, .character = 14 }, .end = .{ .line = 1, .character = 15 } }, .text = "2" }};
    try store.applyChanges("file:///main.ts", 2, &changes);
    try std.testing.expectEqualStrings("const face = '😀';\nconst value = 2;", store.get("file:///main.ts").?.text);
    try std.testing.expectError(error.StaleDocumentVersion, store.applyChanges("file:///main.ts", 2, &changes));
}

test "offsetAt counts astral characters as two UTF-16 code units" {
    try std.testing.expectEqual(@as(usize, 5), try offsetAt("a😀b", .{ .line = 0, .character = 3 }));
    try std.testing.expectError(error.PositionInsideSurrogatePair, offsetAt("a😀b", .{ .line = 0, .character = 2 }));
}

test "positionAt reports UTF-16 positions" {
    try std.testing.expectEqual(Position{ .line = 1, .character = 3 }, positionAt("x\na😀b", 7));
}
