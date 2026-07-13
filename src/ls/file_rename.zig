const std = @import("std");

//! File rename support — finds all references that need updating on rename.
//!
//! Port of `internal/ls/file_rename.go` (382 LOC).
//!
//! When a file is renamed, this module finds all import/export specifiers
//! that reference the old file name and generates text edits to update them.

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");

/// A file edit (path + text changes).
pub const FileEdit = struct {
    file_name: []const u8,
    edits: []const TextEdit,

    pub const TextEdit = struct { start: u32, end: u32, new_text: []const u8 };
};

/// Result of a file rename — all edits needed across the project.
pub const FileRenameResult = struct {
    file_edits: []const FileEdit,
};

/// Provides edits for renaming a file.
/// Port of Go's `ProvideFileRenameEdits`.
pub fn provideFileRenameEdits(
    allocator: std.mem.Allocator,
    old_file_name: []const u8,
    new_file_name: []const u8,
) !FileRenameResult {
    _ = allocator;
    _ = old_file_name;
    _ = new_file_name;
    // Full implementation:
    // 1. Find all files that import the old file
    // 2. Update import specifiers with the new file name
    // 3. Return file edits
    // TODO(phase3.3): wire full implementation.
    return .{ .file_edits = &.{} };
}
