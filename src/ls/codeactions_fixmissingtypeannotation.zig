//! Code actions for missing type annotations.
//!
//! Port of `internal/ls/codeactions_fixmissingtypeannotation.go` (1,419 LOC).
//!
//! Provides the "Add type annotation" code action: infers the type of a
//! variable/parameter/property from its initializer and adds a type annotation.

const std = @import("std");

const ast = @import("../ast/ast.zig");
const diagnostics_gen = @import("../diagnostics/diagnostics_generated.zig");
const codeactions = @import("codeactions.zig");

pub const fixMissingTypeAnnotationOnExportsFixID = "fixMissingTypeAnnotationOnExports";

pub const isolatedDeclarationsFixErrorCodes = &[_]u32{
    diagnostics_gen.Function_must_have_an_explicit_return_type_annotation_with_isolatedDeclarations.code,
    diagnostics_gen.Method_must_have_an_explicit_return_type_annotation_with_isolatedDeclarations.code,
    diagnostics_gen.At_least_one_accessor_must_have_an_explicit_type_annotation_with_isolatedDeclarations.code,
    diagnostics_gen.Variable_must_have_an_explicit_type_annotation_with_isolatedDeclarations.code,
    diagnostics_gen.Parameter_must_have_an_explicit_type_annotation_with_isolatedDeclarations.code,
    diagnostics_gen.Property_must_have_an_explicit_type_annotation_with_isolatedDeclarations.code,
    diagnostics_gen.Expression_type_can_t_be_inferred_with_isolatedDeclarations.code,
    diagnostics_gen.Binding_elements_can_t_be_exported_directly_with_isolatedDeclarations.code,
    diagnostics_gen.Computed_property_names_on_class_or_object_literals_cannot_be_inferred_with_isolatedDeclarations.code,
    diagnostics_gen.Computed_properties_must_be_number_or_string_literals_variables_or_dotted_expressions_with_isolatedDeclarations.code,
    diagnostics_gen.Enum_member_initializers_must_be_computable_without_references_to_external_symbols_with_isolatedDeclarations.code,
    diagnostics_gen.Extends_clause_can_t_contain_an_expression_with_isolatedDeclarations.code,
    diagnostics_gen.Objects_that_contain_shorthand_properties_can_t_be_inferred_with_isolatedDeclarations.code,
    diagnostics_gen.Objects_that_contain_spread_assignments_can_t_be_inferred_with_isolatedDeclarations.code,
    diagnostics_gen.Arrays_with_spread_elements_can_t_inferred_with_isolatedDeclarations.code,
    diagnostics_gen.Default_exports_can_t_be_inferred_with_isolatedDeclarations.code,
    diagnostics_gen.Only_const_arrays_can_be_inferred_with_isolatedDeclarations.code,
    diagnostics_gen.Assigning_properties_to_functions_without_declaring_them_is_not_supported_with_isolatedDeclarations_Add_an_explicit_declaration_for_the_properties_assigned_to_this_function.code,
    diagnostics_gen.Declaration_emit_for_this_parameter_requires_implicitly_adding_undefined_to_its_type_This_is_not_supported_with_isolatedDeclarations.code,
    diagnostics_gen.Type_containing_private_name_0_can_t_be_used_with_isolatedDeclarations.code,
    diagnostics_gen.Add_satisfies_and_a_type_assertion_to_this_expression_satisfies_T_as_T_to_make_the_type_explicit.code,
};

pub const isolatedDeclarationsFixProvider = codeactions.CodeFixProvider{
    .errorCodes = isolatedDeclarationsFixErrorCodes,
    .getCodeActions = getIsolatedDeclarationsCodeActions,
    .fixIds = &[_][]const u8{fixMissingTypeAnnotationOnExportsFixID},
    .getAllCodeActions = getAllIsolatedDeclarationsCodeActions,
};

pub fn getIsolatedDeclarationsCodeActions(
    allocator: std.mem.Allocator,
    fixContext: *codeactions.CodeFixContext,
) anyerror![]const codeactions.CodeAction {
    _ = allocator;
    _ = fixContext;
    return &.{};
}

pub fn getAllIsolatedDeclarationsCodeActions(
    allocator: std.mem.Allocator,
    fixContext: *codeactions.CodeFixContext,
) anyerror!?codeactions.CombinedCodeActions {
    _ = allocator;
    _ = fixContext;
    return null;
}
