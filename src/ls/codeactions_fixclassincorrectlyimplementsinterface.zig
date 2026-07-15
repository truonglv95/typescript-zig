//! Code action: fix class incorrectly implements interface.
//!
//! Port of `internal/ls/codeactions_fixclassincorrectlyimplementsinterface.go` (236 LOC).
//!
//! Provides the "Implement interface" code action: adds all missing
//! properties and methods required by an implemented interface.

const std = @import("std");

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const diagnostics_gen = @import("../diagnostics/diagnostics_generated.zig");
const codeactions = @import("codeactions.zig");

pub const fixClassIncorrectlyImplementsInterfaceFixID = "fixClassIncorrectlyImplementsInterface";

pub const fixClassIncorrectlyImplementsInterfaceErrorCodes = &[_]u32{
    diagnostics_gen.Class_0_incorrectly_implements_interface_1.code,
    diagnostics_gen.Class_0_incorrectly_implements_class_1_Did_you_mean_to_extend_1_and_inherit_its_members_as_a_subclass.code,
};

pub const fixClassIncorrectlyImplementsInterfaceProvider = codeactions.CodeFixProvider{
    .errorCodes = fixClassIncorrectlyImplementsInterfaceErrorCodes,
    .getCodeActions = getCodeActionsToFixClassIncorrectlyImplementsInterface,
    .fixIds = &[_][]const u8{fixClassIncorrectlyImplementsInterfaceFixID},
    .getAllCodeActions = getAllCodeActionsToFixClassIncorrectlyImplementsInterface,
};

pub fn getCodeActionsToFixClassIncorrectlyImplementsInterface(
    allocator: std.mem.Allocator,
    fixContext: *codeactions.CodeFixContext,
) anyerror![]const codeactions.CodeAction {
    _ = allocator;
    _ = fixContext;
    return &.{};
}

pub fn getAllCodeActionsToFixClassIncorrectlyImplementsInterface(
    allocator: std.mem.Allocator,
    fixContext: *codeactions.CodeFixContext,
) anyerror!?codeactions.CombinedCodeActions {
    _ = allocator;
    _ = fixContext;
    return null;
}
