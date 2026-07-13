const std = @import("std");

//! Linked editing ranges — highlights matching tags in JSX/HTML.
//!
//! Port of `internal/ls/linkedediting.go` (107 LOC).
//!
//! When the cursor is on a JSX opening tag, returns the ranges of the
//! opening and closing tags so the editor can highlight them together.

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");

/// A linked editing range pair (opening + closing tag).
pub const LinkedEditingRanges = struct {
    /// The word range at the cursor position.
    word_range: Range,
    /// Ranges of matching tags (opening + closing).
    ranges: []const Range,

    pub const Range = struct { start: u32, end: u32 };
};

/// Returns linked editing ranges for JSX tags at the given position.
/// Port of Go's `ProvideLinkedEditingRanges`.
pub fn provideLinkedEditingRanges(
    tree: *ast.Ast,
    source_file: ast_gen.NodeIndex,
    position: u32,
) ?LinkedEditingRanges {
    _ = tree;
    _ = source_file;
    _ = position;
    // Full implementation:
    // 1. Find the JSX element at the position
    // 2. Get the tag name of the opening element
    // 3. Find the matching closing element
    // 4. Return both tag name ranges
    // TODO(phase3.3): wire full implementation.
    return null;
}
