const std = @import("std");
const lsconv = @import("../ls/lsconv.zig");
const lsproto = @import("../lsp/lsproto.zig");
const fourslash = @import("fourslash.zig");
const FourslashTest = fourslash.FourslashTest;

pub const SemanticToken = struct {
    Type: []const u8,
    Text: []const u8,
};

pub fn verifySemanticTokens(f: *FourslashTest, expected: []const SemanticToken) !void {
    const active_filename = f.activeFilename orelse return error.MissingActiveFilename;

    var params = lsproto.SemanticTokensParams{
        .TextDocument = lsproto.TextDocumentIdentifier{
            .Uri = lsconv.fileNameToDocumentURI(active_filename, f.allocator),
        },
    };

    const result = try fourslash.sendRequest(f, lsproto.TextDocumentSemanticTokensFullInfo, &params);

    if (result.SemanticTokens == null) {
        if (expected.len == 0) {
            return;
        }
        std.debug.print("Expected semantic tokens but got nil\n", .{});
        return error.TestFailed;
    }

    const actual = try decodeSemanticTokens(
        f,
        result.SemanticTokens.?.Data,
        f.semanticTokenTypes,
        f.semanticTokenModifiers,
    );

    if (actual.len != expected.len) {
        std.debug.print("Expected {d} semantic tokens, got {d}\n\nExpected:\n{s}\n\nActual:\n{s}\n", .{
            expected.len,
            actual.len,
            try formatSemanticTokens(f.allocator, expected),
            try formatSemanticTokens(f.allocator, actual),
        });
        return error.TestFailed;
    }

    for (expected, 0..) |exp, i| {
        const act = actual[i];
        if (!std.mem.eql(u8, exp.Type, act.Type) or !std.mem.eql(u8, exp.Text, act.Text)) {
            std.debug.print("Token {d} mismatch:\n  Expected: {{Type: \"{s}\", Text: \"{s}\"}}\n  Actual:   {{Type: \"{s}\", Text: \"{s}\"}}\n", .{
                i, exp.Type, exp.Text, act.Type, act.Text,
            });
            return error.TestFailed;
        }
    }
}

pub fn decodeSemanticTokens(
    f: *FourslashTest,
    data: []const u32,
    token_types: []const []const u8,
    token_modifiers: []const []const u8,
) ![]SemanticToken {
    if (data.len % 5 != 0) {
        std.debug.panic("Invalid semantic tokens data length: {d}", .{data.len});
    }

    const active_filename = f.activeFilename orelse return error.MissingActiveFilename;
    const script_info = f.scriptInfos.get(active_filename) orelse return error.MissingScriptInfo;

    var converters = lsconv.Converters.init(lsproto.PositionEncodingKind.UTF8, f.allocator);

    var tokens = std.ArrayList(SemanticToken).init(f.allocator);
    var prev_line: u32 = 0;
    var prev_char: u32 = 0;

    var i: usize = 0;
    while (i < data.len) : (i += 5) {
        const delta_line = data[i];
        const delta_char = data[i + 1];
        const length = data[i + 2];
        const token_type_idx = data[i + 3];
        const token_modifier_mask = data[i + 4];

        const line = prev_line + delta_line;
        const char = if (delta_line == 0) prev_char + delta_char else delta_char;

        if (token_type_idx >= token_types.len) {
            std.debug.panic("Token type index out of range: {d}", .{token_type_idx});
        }
        const token_type = token_types[token_type_idx];

        var modifiers = std.ArrayList([]const u8).init(f.allocator);
        for (token_modifiers, 0..) |mod, mod_i| {
            if ((token_modifier_mask & (@as(u32, 1) << @intCast(mod_i))) != 0) {
                try modifiers.append(mod);
            }
        }

        var type_str = try f.allocator.dupe(u8, token_type);
        if (modifiers.items.len > 0) {
            const joined_mods = try std.mem.join(f.allocator, ".", modifiers.items);
            type_str = try std.fmt.allocPrint(f.allocator, "{s}.{s}", .{ type_str, joined_mods });
        }

        const start_pos = lsproto.Position{ .Line = line, .Character = char };
        const end_pos = lsproto.Position{ .Line = line, .Character = char + length };

        const start_offset = try converters.lineAndCharacterToPosition(script_info, start_pos);
        const end_offset = try converters.lineAndCharacterToPosition(script_info, end_pos);

        const text = script_info.content[@intCast(start_offset)..@intCast(end_offset)];

        try tokens.append(SemanticToken{
            .Type = type_str,
            .Text = try f.allocator.dupe(u8, text),
        });

        prev_line = line;
        prev_char = char;
    }

    return tokens.toOwnedSlice();
}

pub fn formatSemanticTokens(allocator: std.mem.Allocator, tokens: []const SemanticToken) ![]const u8 {
    var lines = std.ArrayList([]const u8).init(allocator);
    for (tokens, 0..) |tok, i| {
        const line = try std.fmt.allocPrint(allocator, "  [{d}] {{Type: \"{s}\", Text: \"{s}\"}}", .{ i, tok.Type, tok.Text });
        try lines.append(line);
    }
    return std.mem.join(allocator, "\n", lines.items);
}
