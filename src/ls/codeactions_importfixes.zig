const std = @import("std");

//! Code actions for import fixes.
//!
//! Port of `internal/ls/codeactions_importfixes.go` (452 LOC).
//!
//! Provides code actions for:
//! - "Add import" (auto-import a symbol from another module)
//! - "Fix import" (correct a broken import specifier)
//! - "Remove unused import"

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const codeactions = @import("codeactions_fixmissingtypeannotation.zig");

/// Provides code actions for import fixes.
/// Port of Go's importFixes.
pub fn provideImportFixes(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    source_file: ast_gen.NodeIndex,
    start: u32,
    end: u32,
) ![]codeactions.CodeAction {
    _ = allocator;
    _ = tree;
    _ = source_file;
    _ = start;
    _ = end;
    // TODO(phase3.3): wire full implementation with auto-import registry.
    return &.{};
}
