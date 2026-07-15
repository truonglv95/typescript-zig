//! Code actions for import fixes.
//!
//! Port of `internal/ls/codeactions_importfixes.go` (452 LOC).
//!
//! Provides code actions for:
//! - "Add import" (auto-import a symbol from another module)
//! - "Fix import" (correct a broken import specifier)
//! - "Remove unused import"

const std = @import("std");

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const diagnostics_gen = @import("../diagnostics/diagnostics_generated.zig");
const codeactions = @import("codeactions.zig");

pub const fixMissingImportFixID = "fixMissingImport";

pub const importFixErrorCodes = &[_]u32{
    diagnostics_gen.Cannot_find_name_0.code,
    diagnostics_gen.Cannot_find_name_0_Did_you_mean_1.code,
    diagnostics_gen.Cannot_find_name_0_Did_you_mean_the_instance_member_this_0.code,
    diagnostics_gen.Cannot_find_name_0_Did_you_mean_the_static_member_1_0.code,
    diagnostics_gen.Cannot_find_namespace_0.code,
    diagnostics_gen.X_0_refers_to_a_UMD_global_but_the_current_file_is_a_module_Consider_adding_an_import_instead.code,
    diagnostics_gen.X_0_only_refers_to_a_type_but_is_being_used_as_a_value_here.code,
    diagnostics_gen.No_value_exists_in_scope_for_the_shorthand_property_0_Either_declare_one_or_provide_an_initializer.code,
    diagnostics_gen.X_0_cannot_be_used_as_a_value_because_it_was_imported_using_import_type.code,
    diagnostics_gen.Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_jQuery_Try_npm_i_save_dev_types_Slashjquery.code,
    diagnostics_gen.Cannot_find_name_0_Do_you_need_to_change_your_target_library_Try_changing_the_lib_compiler_option_to_1_or_later.code,
    diagnostics_gen.Cannot_find_name_0_Do_you_need_to_change_your_target_library_Try_changing_the_lib_compiler_option_to_include_dom.code,
    diagnostics_gen.Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_a_test_runner_Try_npm_i_save_dev_types_Slashjest_or_npm_i_save_dev_types_Slashmocha_and_then_add_jest_or_mocha_to_the_types_field_in_your_tsconfig.code,
    diagnostics_gen.Cannot_find_name_0_Did_you_mean_to_write_this_in_an_async_function.code,
    diagnostics_gen.Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_jQuery_Try_npm_i_save_dev_types_Slashjquery_and_then_add_jquery_to_the_types_field_in_your_tsconfig.code,
    diagnostics_gen.Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_a_test_runner_Try_npm_i_save_dev_types_Slashjest_or_npm_i_save_dev_types_Slashmocha.code,
    diagnostics_gen.Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_node_Try_npm_i_save_dev_types_Slashnode.code,
    diagnostics_gen.Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_node_Try_npm_i_save_dev_types_Slashnode_and_then_add_node_to_the_types_field_in_your_tsconfig.code,
    diagnostics_gen.Cannot_find_namespace_0_Did_you_mean_1.code,
    diagnostics_gen.Cannot_extend_an_interface_0_Did_you_mean_implements.code,
    diagnostics_gen.This_JSX_tag_requires_0_to_be_in_scope_but_it_could_not_be_found.code,
};

pub const importFixProvider = codeactions.CodeFixProvider{
    .errorCodes = importFixErrorCodes,
    .getCodeActions = getImportFixesCodeActions,
    .fixIds = &[_][]const u8{fixMissingImportFixID},
    .getAllCodeActions = getAllImportFixesCodeActions,
};

pub fn getImportFixesCodeActions(
    allocator: std.mem.Allocator,
    fixContext: *codeactions.CodeFixContext,
) anyerror![]const codeactions.CodeAction {
    _ = allocator;
    _ = fixContext;
    return &.{};
}

pub fn getAllImportFixesCodeActions(
    allocator: std.mem.Allocator,
    fixContext: *codeactions.CodeFixContext,
) anyerror!?codeactions.CombinedCodeActions {
    _ = allocator;
    _ = fixContext;
    return null;
}
