const std = @import("std");

//! Code actions for missing type annotations.
//!
//! Port of `internal/ls/codeactions_fixmissingtypeannotation.go` (1,419 LOC).
//!
//! Provides the "Add type annotation" code action: infers the type of a
//! variable/parameter/property from its initializer and adds a type annotation.

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");

/// A code action.
pub const CodeAction = struct {
    title: []const u8,
    kind: CodeActionKind,
    edits: []const FileEdit,

    pub const FileEdit = struct { file_name: []const u8, edits: []const TextEdit };
    pub const TextEdit = struct { start: u32, end: u32, new_text: []const u8 };
};

pub const CodeActionKind = enum {
    QuickFix,
    Refactor,
    RefactorExtract,
    Source,
    SourceOrganizeImports,
};

/// Provides code actions for adding missing type annotations.
/// Port of Go's fixMissingTypeAnnotation code action.
pub fn provideFixMissingTypeAnnotation(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    source_file: ast_gen.NodeIndex,
    start: u32,
    end: u32,
) ![]CodeAction {
    _ = allocator;
    _ = tree;
    _ = source_file;
    _ = start;
    _ = end;
    // Full implementation:
    // 1. Find variable/parameter declarations without type annotations
    // 2. Infer the type from the initializer
    // 3. Generate a text edit to add the type annotation
    // TODO(phase3.3): wire full implementation.
    return &.{};
}
