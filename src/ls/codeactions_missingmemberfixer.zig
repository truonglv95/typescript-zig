const std = @import("std");

//! Code actions for missing members (implement interface members).
//!
//! Port of `internal/ls/codeactions_missingmemberfixer.go` (498 LOC).
//!
//! Provides code actions for:
//! - "Add missing properties" from an interface/class
//! - "Implement interface" (add all missing members)
//! - "Add missing imports"

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const codeactions = @import("codeactions_fixmissingtypeannotation.zig");

/// Provides code actions for fixing missing members.
/// Port of Go's missingMemberFixer.
pub fn provideMissingMemberFixes(
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
    // TODO(phase3.3): wire full implementation.
    return &.{};
}
