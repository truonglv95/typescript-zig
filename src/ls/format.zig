const std = @import("std");

//! Format provider — code formatting for language service.
//!
//! Port of `internal/ls/format.go` (181 LOC).
//!
//! Delegates to the `format` module to format source code ranges.

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");

/// Format options passed from the editor.
pub const FormatOptions = struct {
    tab_size: u32 = 4,
    insert_spaces: bool = true,
    new_line_character: []const u8 = "\n",
    convert_tabs_to_spaces: bool = true,
    indent_style: IndentStyle = .Smart,
    trim_trailing_whitespace: bool = false,
    insert_final_newline: bool = false,
    trim_final_newlines: bool = false,
};

pub const IndentStyle = enum {
    None,
    Block,
    Smart,
};

/// A text edit for formatting.
pub const TextEdit = struct {
    range: TextRange,
    new_text: []const u8,

    pub const TextRange = struct { start: u32, end: u32 };
};

/// Formats a range of source text.
/// Port of Go's `ProvideFormatting`.
pub fn provideFormatting(
    allocator: std.mem.Allocator,
    source_text: []const u8,
    range: ?TextRange,
    options: FormatOptions,
) ![]TextEdit {
    _ = source_text;
    _ = range;
    _ = options;
    // Full implementation delegates to the format module.
    // TODO(phase3.3): wire format module integration.
    var result = std.ArrayListUnmanaged(TextEdit).empty;
    return result.toOwnedSlice(allocator);
}

/// Formats the document on save (applies format + organize imports).
pub fn provideFormatOnSave(
    allocator: std.mem.Allocator,
    source_text: []const u8,
    options: FormatOptions,
) ![]TextEdit {
    return provideFormatting(allocator, source_text, null, options);
}
