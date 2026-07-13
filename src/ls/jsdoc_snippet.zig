const std = @import("std");

//! JSDoc snippet generation.
//!
//! Port of `internal/ls/jsdoc_snippet.go` (594 LOC).
//!
//! Generates JSDoc comment templates for completions. When the user types
//! `/**` and triggers completion, this module generates a JSDoc template
//! with `@param` tags for each parameter and `@returns` tag.

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");

/// A JSDoc snippet entry.
pub const JSDocSnippet = struct {
    /// The generated JSDoc text (may contain snippet placeholders like `${1:description}`).
    text: []const u8,
    /// The position where the snippet should be inserted.
    position: u32,
};

/// Generates a JSDoc snippet for the declaration at the given position.
/// Port of Go's `getJSDocSnippet`.
pub fn getJSDocSnippet(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    source_file: ast_gen.NodeIndex,
    position: u32,
) ?JSDocSnippet {
    _ = allocator;
    _ = tree;
    _ = source_file;
    _ = position;
    // Full implementation:
    // 1. Find the declaration node after the cursor
    // 2. Extract parameters (for functions/methods)
    // 3. Generate JSDoc template with @param tags
    // 4. Add @returns tag if the function has a return type
    // TODO(phase3.3): wire full implementation.
    return null;
}

/// Generates JSDoc template text for a function with the given parameter names.
pub fn generateJSDocTemplate(
    allocator: std.mem.Allocator,
    param_names: []const []const u8,
    has_return: bool,
) ![]const u8 {
    var result = std.ArrayList(u8).empty;
    defer result.deinit(allocator);

    try result.appendSlice(allocator, "/**\n");
    try result.appendSlice(allocator, " * $1\n"); // Description placeholder

    for (param_names) |name| {
        try result.appendSlice(allocator, " * @param ");
        try result.appendSlice(allocator, name);
        try result.appendSlice(allocator, " $2\n"); // Param description placeholder
    }

    if (has_return) {
        try result.appendSlice(allocator, " * @returns $3\n");
    }

    try result.appendSlice(allocator, " */");

    return result.toOwnedSlice(allocator);
}
