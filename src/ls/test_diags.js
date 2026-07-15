const fs = require('fs');

const zigFile = fs.readFileSync('/Users/truong/Documents/typescript-zig/src/diagnostics/diagnostics_generated.zig', 'utf8');
const names = zigFile.match(/pub const ([A-Za-z0-9_]+) = Message/g).map(s => s.replace('pub const ', '').replace(' = Message', ''));
const set = new Set(names);

function check(list) {
    return list.map(name => {
        if (!set.has(name)) {
            // fuzzy match
            const best = names.find(n => n.toLowerCase() === name.toLowerCase() || n.replace(/_be_/, '_') === name || name.replace(/_be_/, '_') === n || n.includes(name) || name.includes(n));
            return best || name;
        }
        return name;
    });
}

const importFixes = check([
	"Cannot_find_name_0",
	"Cannot_find_name_0_Did_you_mean_1",
	"Cannot_find_name_0_Did_you_mean_the_instance_member_this_0",
	"Cannot_find_name_0_Did_you_mean_the_static_member_1_0",
	"Cannot_find_namespace_0",
	"X_0_refers_to_a_UMD_global_but_the_current_file_is_a_module_Consider_adding_an_import_instead",
	"X_0_only_refers_to_a_type_but_is_being_used_as_a_value_here",
	"No_value_exists_in_scope_for_the_shorthand_property_0_Either_declare_one_or_provide_an_initializer",
	"X_0_cannot_be_used_as_a_value_because_it_was_imported_using_import_type",
	"Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_jQuery_Try_npm_i_save_dev_types_Slashjquery",
	"Cannot_find_name_0_Do_you_need_to_change_your_target_library_Try_changing_the_lib_compiler_option_to_1_or_later",
	"Cannot_find_name_0_Do_you_need_to_change_your_target_library_Try_changing_the_lib_compiler_option_to_include_dom",
	"Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_a_test_runner_Try_npm_i_save_dev_types_Slashjest_or_npm_i_save_dev_types_Slashmocha_and_then_add_jest_or_mocha_to_the_types_field_in_your_tsconfig",
	"Cannot_find_name_0_Did_you_mean_to_write_this_in_an_async_function",
	"Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_jQuery_Try_npm_i_save_dev_types_Slashjquery_and_then_add_jquery_to_the_types_field_in_your_tsconfig",
	"Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_a_test_runner_Try_npm_i_save_dev_types_Slashjest_or_npm_i_save_dev_types_Slashmocha",
	"Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_node_Try_npm_i_save_dev_types_Slashnode",
	"Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_node_Try_npm_i_save_dev_types_Slashnode_and_then_add_node_to_the_types_field_in_your_tsconfig",
	"Cannot_find_namespace_0_Did_you_mean_1",
	"Cannot_extend_an_interface_0_Did_you_mean_implements",
	"This_JSX_tag_requires_0_to_be_in_scope_but_it_could_not_be_found",
]);

const missingMembers = check([
	"Property_0_is_missing_in_type_1_but_required_in_type_2",
	"Type_0_is_missing_the_following_properties_from_type_1_Colon_2",
	"Type_0_is_missing_the_following_properties_from_type_1_Colon_2_and_3_more",
	"Cannot_find_name_0",
]);

const fixClass = check([
	"Class_0_incorrectly_implements_interface_1",
	"Class_0_incorrectly_implements_class_1_Did_you_mean_to_extend_1_and_inherit_its_members_as_a_subclass",
]);

const fixMissing = check([
	"Function_must_have_an_explicit_return_type_annotation_with_isolatedDeclarations",
	"Method_must_have_an_explicit_return_type_annotation_with_isolatedDeclarations",
	"At_least_one_accessor_must_have_an_explicit_type_annotation_with_isolatedDeclarations",
	"Variable_must_have_an_explicit_type_annotation_with_isolatedDeclarations",
	"Parameter_must_have_an_explicit_type_annotation_with_isolatedDeclarations",
	"Property_must_have_an_explicit_type_annotation_with_isolatedDeclarations",
	"Expression_type_can_t_be_inferred_with_isolatedDeclarations",
	"Binding_elements_can_t_be_exported_directly_with_isolatedDeclarations",
	"Computed_property_names_on_class_or_object_literals_cannot_be_inferred_with_isolatedDeclarations",
	"Computed_properties_must_be_number_or_string_literals_variables_or_dotted_expressions_with_isolatedDeclarations",
	"Enum_member_initializers_must_be_computable_without_references_to_external_symbols_with_isolatedDeclarations",
	"Extends_clause_can_t_contain_an_expression_with_isolatedDeclarations",
	"Objects_that_contain_shorthand_properties_can_t_be_inferred_with_isolatedDeclarations",
	"Objects_that_contain_spread_assignments_can_t_be_inferred_with_isolatedDeclarations",
	"Arrays_with_spread_elements_can_t_inferred_with_isolatedDeclarations",
	"Default_exports_can_t_be_inferred_with_isolatedDeclarations",
	"Only_const_arrays_can_be_inferred_with_isolatedDeclarations",
	"Assigning_properties_to_functions_without_declaring_them_is_not_supported_with_isolatedDeclarations_Add_an_explicit_declaration_for_the_properties_assigned_to_this_function",
	"Declaration_emit_for_this_parameter_requires_implicitly_adding_undefined_to_its_type_This_is_not_supported_with_isolatedDeclarations",
	"Type_containing_private_name_0_can_t_be_used_with_isolatedDeclarations",
	"Add_satisfies_and_a_type_assertion_to_this_expression_satisfies_T_as_T_to_make_the_type_explicit",
]);

console.log("importFixes", importFixes);
console.log("missingMembers", missingMembers);
console.log("fixClass", fixClass);
console.log("fixMissing", fixMissing);
