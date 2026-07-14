const std = @import("std");

//! Code action: fix class incorrectly implements interface.
//!
//! Port of `internal/ls/codeactions_fixclassincorrectlyimplementsinterface.go` (236 LOC).
//!
//! Provides the "Implement interface" code action: adds all missing
//! properties and methods required by an implemented interface.

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const codeactions = @import("codeactions_fixmissingtypeannotation.zig");

/// Provides code actions for fixing "class incorrectly implements interface".
/// Port of Go's fixClassIncorrectlyImplementsInterface.
pub fn provideFixClassIncorrectlyImplementsInterface(
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
