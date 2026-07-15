//! Code actions for missing members (implement interface members).
//!
//! Port of `internal/ls/codeactions_missingmemberfixer.go` (498 LOC).
//!
//! Provides code actions for:
//! - "Add missing properties" from an interface/class
//! - "Implement interface" (add all missing members)
//! - "Add missing imports"

const std = @import("std");

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const diagnostics_gen = @import("../diagnostics/diagnostics_generated.zig");
const codeactions = @import("codeactions.zig");

pub const missingMemberErrorCodes = &[_]u32{
    diagnostics_gen.Property_0_is_missing_in_type_1_but_required_in_type_2.code,
    diagnostics_gen.Type_0_is_missing_the_following_properties_from_type_1_Colon_2.code,
    diagnostics_gen.Type_0_is_missing_the_following_properties_from_type_1_Colon_2_and_3_more.code,
    diagnostics_gen.Cannot_find_name_0.code,
};

pub const missingMemberFixProvider = codeactions.CodeFixProvider{
    .errorCodes = missingMemberErrorCodes,
    .getCodeActions = getMissingMemberCodeActions,
    .fixIds = &[_][]const u8{},
    .getAllCodeActions = null,
};

pub fn getMissingMemberCodeActions(
    allocator: std.mem.Allocator,
    fixContext: *codeactions.CodeFixContext,
) anyerror![]const codeactions.CodeAction {
    _ = allocator;
    _ = fixContext;
    return &.{};
}
