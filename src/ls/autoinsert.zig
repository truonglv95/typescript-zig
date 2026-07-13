const std = @import("std");

//! Auto-insert provider — inserts closing brackets, semicolons, etc.
//!
//! Port of `internal/ls/autoinsert.go` (99 LOC).
//!
//! Called when the user types a character. Returns a text edit to
//! auto-insert matching closing characters (e.g. `}` after `{`,
//! `]` after `[`, `)` after `(`).

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");

/// The kind of auto-insert.
pub const AutoInsertKind = enum {
    None,
    ClosingBracket,
    Semicolon,
    JsxClosingTag,
};

/// Result of an auto-insert query.
pub const AutoInsertResult = struct {
    kind: AutoInsertKind,
    /// Text to insert.
    text: []const u8,
    /// Offset where to insert.
    offset: u32,
};

/// Returns the auto-insert text edit for the given position and character.
/// Port of Go's `ProvideOnAutoInsert`.
pub fn provideOnAutoInsert(
    tree: *ast.Ast,
    source_text: []const u8,
    position: u32,
    ch: u8,
) ?AutoInsertResult {
    _ = tree;
    _ = source_text;
    // Simplified: auto-insert closing brackets.
    const closing: ?u8 = switch (ch) {
        '(' => ')',
        '[' => ']',
        '{' => '}',
        '"' => '"',
        '\'' => '\'',
        '`' => '`',
        else => null,
    };
    if (closing) |c| {
        var buf: [1]u8 = undefined;
        buf[0] = c;
        return .{
            .kind = .ClosingBracket,
            .text = buf[0..1],
            .offset = position,
        };
    }
    return null;
}
