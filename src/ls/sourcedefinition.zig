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
    const astnav = @import("../astnav/tokens.zig");
    const token = astnav.getTokenAtPosition(source_file, tree, position);
    if (token == 0) return &.{};

    const symbol = tree.getNodeSymbol(token) orelse return &.{};
    if (symbol == 0) return &.{};

    // Note: without checker we cannot reliably get all declarations across files.
    // So we return an empty array for now.
    // Once checker is passed, we can do c.getSymbolDeclarations(symbol).
    var result = std.ArrayListUnmanaged(SourceDefinition).empty;
    errdefer result.deinit(allocator);

    return result.toOwnedSlice(allocator);
}
