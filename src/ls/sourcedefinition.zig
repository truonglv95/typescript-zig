const std = @import("std");

//! Source definition — go-to-definition for module specifiers.
//!
//! Port of `internal/ls/sourcedefinition.go` (707 LOC).
//!
//! Resolves "go to source definition" — instead of jumping to the
//! declaration in a .d.ts file, jumps to the implementation in a .ts/.js
//! source file.

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");

/// A source definition location.
pub const SourceDefinition = struct {
    /// The source file URI.
    file_name: []const u8,
    /// The text span in the source file.
    text_span: TextSpan,
    /// Optional name of the definition.
    name: []const u8 = "",

    pub const TextSpan = struct { start: u32, length: u32 };
};

/// Provides source definitions for a symbol at the given position.
/// Port of Go's `ProvideSourceDefinitions`.
pub fn provideSourceDefinitions(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    source_file: ast_gen.NodeIndex,
    position: u32,
) ![]SourceDefinition {
    _ = allocator;
    _ = tree;
    _ = source_file;
    _ = position;
    // Full implementation:
    // 1. Find the symbol at the position
    // 2. Find all declarations of the symbol
    // 3. Filter to source (non-declaration) files only
    // 4. Return source definition locations
    // TODO(phase3.3): wire full implementation.
    return &.{};
}
