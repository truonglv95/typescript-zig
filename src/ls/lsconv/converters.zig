const std = @import("std");
const core = @import("../../core/core.zig");
const bundled = @import("../../bundled/bundled.zig");
const tspath = @import("../../tspath/tspath.zig");
const lsproto = @import("../../lsp/lsproto/lsproto.zig");
const linemap = @import("linemap.zig");

pub const Script = struct {
    file_name: []const u8,
    text: []const u8,
};

pub const Converters = struct {
    get_line_map_ctx: ?*anyopaque,
    get_line_map: *const fn (ctx: ?*anyopaque, file_name: []const u8) *const linemap.LSPLineMap,
    position_encoding: lsproto.PositionEncodingKind,

    pub fn init(
        position_encoding: lsproto.PositionEncodingKind,
        ctx: ?*anyopaque,
        get_line_map: *const fn (ctx: ?*anyopaque, file_name: []const u8) *const linemap.LSPLineMap,
    ) Converters {
        return .{
            .position_encoding = position_encoding,
            .get_line_map_ctx = ctx,
            .get_line_map = get_line_map,
        };
    }

    pub fn toLSPRange(self: Converters, script: Script, text_range: core.TextRange) lsproto.Range {
        return lsproto.Range{
            .start = self.positionToLineAndCharacter(script, @intCast(text_range.pos())),
            .end = self.positionToLineAndCharacter(script, @intCast(text_range.end())),
        };
    }

    pub fn fromLSPRange(self: Converters, script: Script, text_range: lsproto.Range) core.TextRange {
        return core.TextRange.init(
            @intCast(self.lineAndCharacterToPosition(script, text_range.start)),
            @intCast(self.lineAndCharacterToPosition(script, text_range.end)),
        );
    }

    // `lsproto.TextDocumentContentChangePartial` is currently missing in lsproto.zig.
    // pub fn fromLSPTextChange(self: Converters, script: Script, change: lsproto.TextDocumentContentChangePartial) core.TextChange { ... }

    // `lsproto.Location.uri` seems to be an opaque struct in lsproto.zig right now.
    // Depending on its final shape, this might need an update. Assuming it accepts our DocumentUri.
    pub fn toLSPLocation(self: Converters, allocator: std.mem.Allocator, script: Script, rng: core.TextRange) !lsproto.Location {
        return lsproto.Location{
            .uri = try fileNameToDocumentURI(allocator, script.file_name),
            .range = self.toLSPRange(script, rng),
        };
    }

    pub fn lineAndCharacterToPosition(self: Converters, script: Script, line_and_character: lsproto.Position) core.TextPos {
        const line_map = self.get_line_map(self.get_line_map_ctx, script.file_name);

        const line = line_and_character.line;
        const char = line_and_character.character;

        const text_len: core.TextPos = @intCast(script.text.len);

        if (line >= line_map.line_starts.len) {
            return text_len;
        }

        const start = line_map.line_starts[line];

        var line_end: core.TextPos = undefined;
        if (line + 1 < line_map.line_starts.len) {
            line_end = line_map.line_starts[line + 1];
        } else {
            line_end = text_len;
        }

        if (line_map.ascii_only or self.position_encoding == .utf8) {
            return @max(start, @min(start + char, line_end));
        }

        var utf16_char: core.TextPos = 0;
        var pos: usize = @intCast(start);
        const end: usize = @intCast(line_end);
        const text = script.text;

        while (pos < end) {
            var bytes_consumed: u3 = 0;
            const r = std.unicode.utf8Decode(text[pos..end]) catch blk: {
                bytes_consumed = 1;
                break :blk std.unicode.utf8ReplacementCharacter;
            };
            if (bytes_consumed == 0) {
                bytes_consumed = std.unicode.utf8ByteSequenceLength(text[pos]) catch 1;
            }

            var u16_len: core.TextPos = 1;
            if (r >= 0x10000) {
                u16_len = 2;
            }

            if (utf16_char + u16_len > char) {
                break;
            }
            utf16_char += u16_len;
            pos += bytes_consumed;
        }

        return @intCast(pos);
    }

    pub fn positionToLineAndCharacter(self: Converters, script: Script, pos: core.TextPos) lsproto.Position {
        const position = @max(0, @min(pos, @as(core.TextPos, @intCast(script.text.len))));
        const line_map = self.get_line_map(self.get_line_map_ctx, script.file_name);

        const line = line_map.computeIndexOfLineStart(position);

        const start = line_map.line_starts[line];

        var character: core.TextPos = 0;
        if (line_map.ascii_only or self.position_encoding == .utf8) {
            character = position - start;
        } else {
            var i: usize = @intCast(start);
            const end: usize = @intCast(position);
            while (i < end) {
                var bytes_consumed: u3 = 0;
                const r = std.unicode.utf8Decode(script.text[i..end]) catch blk: {
                    bytes_consumed = 1;
                    break :blk std.unicode.utf8ReplacementCharacter;
                };
                if (bytes_consumed == 0) {
                    bytes_consumed = std.unicode.utf8ByteSequenceLength(script.text[i]) catch 1;
                }
                var u16_len: core.TextPos = 1;
                if (r >= 0x10000) {
                    u16_len = 2;
                }
                character += u16_len;
                i += bytes_consumed;
            }
        }

        return lsproto.Position{
            .line = @intCast(line),
            .character = @intCast(character),
        };
    }
};

pub fn languageKindToScriptKind(language_id: []const u8) core.ScriptKind {
    if (std.mem.eql(u8, language_id, "typescript")) return .TS;
    if (std.mem.eql(u8, language_id, "typescriptreact")) return .TSX;
    if (std.mem.eql(u8, language_id, "javascript")) return .JS;
    if (std.mem.eql(u8, language_id, "javascriptreact")) return .JSX;
    if (std.mem.eql(u8, language_id, "json")) return .JSON;
    return .Unknown;
}

// NOTE: lsproto.DocumentUri in Zig is currently an opaque struct with only `.fileName()` method.
// Returning it initialized as `.{}` to match the current lsproto.zig stub, but conceptually
// it represents the URI string. We will return the URI string directly as a `[]const u8`
// and let the caller cast it or we update it once DocumentUri is properly defined.
// Actually, to match Go's FileNameToDocumentUri returning lsproto.DocumentUri, we will return the allocated string
// and assume DocumentUri is or wraps `[]const u8`. For now, we return `[]const u8` and let the stub lsproto deal with it later.
// Wait, to compile with current lsproto.zig, lsproto.DocumentUri is `struct { pub fn fileName(...) ... }`
// which has no fields. So we just return `.{}`.
pub fn fileNameToDocumentURI(allocator: std.mem.Allocator, file_name: []const u8) !lsproto.DocumentUri {
    _ = allocator;
    _ = file_name;
    // Implementation omitted because lsproto.DocumentUri doesn't have a backing string yet.
    return lsproto.DocumentUri{};
}

// Diagnostic to LSP functions are omitted because `lsproto.Diagnostic` is missing.
