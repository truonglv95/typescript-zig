const std = @import("std");
const core = @import("../core/core.zig");
const ast = @import("../ast/ast.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");

pub const Converters = struct {
    /// Convert line/character position to absolute text position.
    /// Port of Go's converters.LineAndCharacterToPosition.
    pub fn lineAndCharacterToPosition(self: *Converters, file: anytype, position: anytype) u32 {
        _ = self;
        // Get file content
        const content = if (@TypeOf(file) == Script) file.content else file;
        const line = if (@TypeOf(position) == lsproto.Position) position.line else 0;
        const char = if (@TypeOf(position) == lsproto.Position) position.character else 0;

        // Walk through content counting newlines
        var current_line: u32 = 0;
        var pos: usize = 0;
        while (pos < content.len and current_line < line) {
            if (content[pos] == '\n') current_line += 1;
            pos += 1;
        }
        // Add character offset within the line
        pos += char;
        if (pos > content.len) pos = content.len;
        return @intCast(pos);
    }

    /// Convert a text range to an LSP Range.
    /// Port of Go's converters.ToLSPRange.
    pub fn toLSPRange(self: *const Converters, script: anytype, text_range: anytype) lsproto.Range {
        _ = self;
        // Get content from script
        const content = if (@TypeOf(script) == Script) script.content else "";
        const pos_val: u32 = if (@TypeOf(text_range) == ast.TextRange) text_range.pos else 0;
        const end_val: u32 = if (@TypeOf(text_range) == ast.TextRange) text_range.end else 0;

        return .{
            .start = positionToLineAndCharacterImpl(content, pos_val),
            .end = positionToLineAndCharacterImpl(content, end_val),
        };
    }

    /// Convert absolute position to line/character.
    /// Port of Go's converters.PositionToLineAndCharacter.
    pub fn positionToLineAndCharacter(self: *Converters, script: anytype, pos: anytype) lsproto.Position {
        _ = self;
        const content = if (@TypeOf(script) == Script) script.content else "";
        const pos_val: u32 = if (@TypeOf(pos) == u32) pos else 0;
        return positionToLineAndCharacterImpl(content, pos_val);
    }
};

fn positionToLineAndCharacterImpl(content: []const u8, pos: u32) lsproto.Position {
    var line: u32 = 0;
    var character: u32 = 0;
    var i: usize = 0;
    const limit = if (pos < content.len) pos else @as(u32, @intCast(content.len));
    while (i < limit) {
        if (content[i] == '\n') {
            line += 1;
            character = 0;
        } else {
            character += 1;
        }
        i += 1;
    }
    return .{ .line = line, .character = character };
}

pub const Script = struct {
    file_name: []const u8,
    content: []const u8,
};

pub fn fileNameToDocumentURI(allocator: std.mem.Allocator, filename: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "file://{s}", .{filename});
}

pub fn documentURIToFileName(allocator: std.mem.Allocator, uri: []const u8) ![]const u8 {
    if (std.mem.startsWith(u8, uri, "file://")) {
        return try allocator.dupe(u8, uri["file://".len..]);
    }
    return try allocator.dupe(u8, uri);
}
