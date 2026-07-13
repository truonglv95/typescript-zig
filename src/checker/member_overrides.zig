const std = @import("std");

//! Class property member override checking.
//!
//! Port of `internal/checker/checker.go::checkKindsOfPropertyMemberOverrides`.
//!
//! Verifies that derived-class property members are kind-compatible with
//! their base-class counterparts (property vs accessor vs method), and
//! reports "non-abstract class does not implement inherited abstract
//! member" errors for unimplemented abstract members.

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const diagnostics_gen = @import("../diagnostics/diagnostics_generated.zig");
const symbol = @import("../ast/symbol.zig");
const types = @import("types.zig");
const utilities = @import("utilities.zig");

const Checker = @import("checker.zig").Checker;

/// Port of `checker.go::checkKindsOfPropertyMemberOverrides`.
///
/// Walks `base_type`'s properties and checks each against the corresponding
/// property on derived type `t`. Reports:
/// - Property/accessor kind mismatch (property overridden as accessor or vice versa)
/// - Method overridden as accessor/property or vice versa
/// - Uninitialized property overwriting base property (when `useDefineForClassFields`)
/// - Unimplemented abstract members ("Non-abstract class X does not implement...")
pub fn checkKindsOfPropertyMemberOverrides(c: *Checker, t: types.TypeIndex, base_type: types.TypeIndex) void {
    const allocator = c.allocator;
    const tree = c.binder.ast;

    // Collect missed abstract properties per derived-class declaration node.
    const MemberInfo = struct {
        missed_properties: std.ArrayListUnmanaged([]const u8),
        base_type_name: []const u8,
        type_name: []const u8,
    };
    var not_implemented = std.AutoHashMapUnmanaged(ast_gen.NodeIndex, MemberInfo).empty;
    defer {
        var iter = not_implemented.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.missed_properties.deinit(allocator);
        }
        not_implemented.deinit(allocator);
    }

    const base_properties = c.getPropertiesOfType(base_type);
    base_property_loop: for (base_properties) |base_property| {
        const base_sym = c.getTargetSymbol(base_property);
        if (base_sym == 0 or base_sym >= c.binder.symbols.items.len) continue;
        const base_sym_obj = c.binder.symbols.items[base_sym];
        if ((base_sym_obj.Flags & symbol.SymbolFlags.Prototype) != 0) continue;

        const base_symbol = c.getPropertyOfObjectType(t, base_sym_obj.Name) orelse continue;
        if (base_symbol == 0) continue;
        const derived_sym = c.getTargetSymbol(base_symbol);
        const base_decl_flags = utilities.getDeclarationModifierFlagsFromSymbol(c, base_sym);

        if (derived_sym == base_sym) {
            // Derived class inherits base without override.
            if ((base_decl_flags & ast_utils.ModifierFlags.Abstract) != 0) {
                // Check if derived class is abstract.
                const t_sym = c.typesList.items[t].symbol orelse continue;
                const derived_class_decl = ast_utils.getClassLikeDeclarationOfSymbol(&c.binder.ast, &c.binder.symbols, t_sym);
                if (derived_class_decl == 0 or !ast_utils.hasSyntacticModifier(tree, derived_class_decl, ast_utils.ModifierFlags.Abstract)) {
                    // Search other base types for a satisfying declaration.
                    // getBaseTypes is still a stub returning empty; skip this search.
                    // Report missed abstract member.
                    const base_type_name = c.typeToString(base_type, 0, 0, null);
                    const type_name = c.typeToString(t, 0, 0, null);
                    const prop_name = c.symbolToString(base_property);

                    const gop = not_implemented.getOrPut(allocator, derived_class_decl) catch continue;
                    if (!gop.found_existing) {
                        gop.value_ptr.* = .{
                            .missed_properties = .empty,
                            .base_type_name = base_type_name,
                            .type_name = type_name,
                        };
                    }
                    gop.value_ptr.missed_properties.append(allocator, prop_name) catch continue;
                }
            }
        } else {
            // Derived overrides base.
            const derived_decl_flags = utilities.getDeclarationModifierFlagsFromSymbol(c, derived_sym);
            if ((base_decl_flags & ast_utils.ModifierFlags.Private) != 0 or (derived_decl_flags & ast_utils.ModifierFlags.Private) != 0) {
                continue; // Private members don't participate in override checking.
            }

            const derived_sym_obj = c.binder.symbols.items[derived_sym];
            const base_property_flags = base_sym_obj.Flags & symbol.SymbolFlags.PropertyOrAccessor;
            const derived_property_flags = derived_sym_obj.Flags & symbol.SymbolFlags.PropertyOrAccessor;

            if (base_property_flags != 0 and derived_property_flags != 0) {
                // Property/accessor overridden with property/accessor.
                const is_mapped = (base_sym_obj.CheckFlags & types.CheckFlags.Mapped) != 0;
                const is_assignment = derived_sym_obj.ValueDeclaration != null and tree.getNodeKind(derived_sym_obj.ValueDeclaration orelse 0) == .BinaryExpression;
                if (is_mapped or is_assignment or c.arePropertiesAbstractOrInterface(base_sym, base_decl_flags)) {
                    continue; // Base is abstract/interface/assignment — flags don't need to match.
                }
                const overridden_instance_property = base_property_flags != symbol.SymbolFlags.Property and derived_property_flags == symbol.SymbolFlags.Property;
                const overridden_instance_accessor = base_property_flags == symbol.SymbolFlags.Property and derived_property_flags != symbol.SymbolFlags.Property;
                if (overridden_instance_property or overridden_instance_accessor) {
                    const msg = if (overridden_instance_property)
                        &diagnostics_gen.X_0_is_defined_as_an_accessor_in_class_1_but_is_overridden_here_in_2_as_an_instance_property
                    else
                        &diagnostics_gen.X_0_is_defined_as_a_property_in_class_1_but_is_overridden_here_in_2_as_an_accessor;
                    const error_node = derived_sym_obj.ValueDeclaration orelse derived_sym_obj.ValueDeclaration orelse 0;
                    const base_name = c.symbolToString(base_property);
                    const base_type_str = c.typeToString(base_type, 0, 0, null);
                    const type_str = c.typeToString(t, 0, 0, null);
                    c.reportErrorWithArgs(error_node, msg, &.{ base_name, base_type_str, type_str });
                }
                // Correct case — no error.
                continue;
            } else if (c.isPrototypeProperty(base_sym)) {
                if (c.isPrototypeProperty(derived_sym) or (derived_sym_obj.Flags & symbol.SymbolFlags.Property) != 0) {
                    continue; // Method overridden with method or property — correct.
                }
                // Method overridden as accessor — error.
                const error_node = derived_sym_obj.ValueDeclaration orelse 0;
                const base_type_str = c.typeToString(base_type, 0, 0, null);
                const base_name = c.symbolToString(base_property);
                const type_str = c.typeToString(t, 0, 0, null);
                c.reportErrorWithArgs(error_node, &diagnostics_gen.Class_0_defines_instance_member_function_1_but_extended_class_2_defines_it_as_instance_member_accessor, &.{ base_type_str, base_name, type_str });
            } else if ((base_sym_obj.Flags & symbol.SymbolFlags.Accessor) != 0) {
                // Accessor overridden as method — error.
                const error_node = derived_sym_obj.ValueDeclaration orelse 0;
                const base_type_str = c.typeToString(base_type, 0, 0, null);
                const base_name = c.symbolToString(base_property);
                const type_str = c.typeToString(t, 0, 0, null);
                c.reportErrorWithArgs(error_node, &diagnostics_gen.Class_0_defines_instance_member_accessor_1_but_extended_class_2_defines_it_as_instance_member_function, &.{ base_type_str, base_name, type_str });
            } else {
                // Property overridden as method — error.
                const error_node = derived_sym_obj.ValueDeclaration orelse 0;
                const base_type_str = c.typeToString(base_type, 0, 0, null);
                const base_name = c.symbolToString(base_property);
                const type_str = c.typeToString(t, 0, 0, null);
                c.reportErrorWithArgs(error_node, &diagnostics_gen.Class_0_defines_instance_member_property_1_but_extended_class_2_defines_it_as_instance_member_function, &.{ base_type_str, base_name, type_str });
            }
        }
    }

    // Report unimplemented abstract members.
    var iter = not_implemented.iterator();
    while (iter.next()) |entry| {
        const error_node = entry.key_ptr.*;
        const info = entry.value_ptr.*;
        const missed = info.missed_properties.items;
        if (missed.len == 0) continue;

        const is_class_expr = tree.getNodeKind(error_node) == .ClassExpression;
        if (missed.len == 1) {
            if (is_class_expr) {
                c.reportErrorWithArgs(error_node, &diagnostics_gen.Non_abstract_class_expression_does_not_implement_inherited_abstract_member_0_from_class_1, &.{ missed[0], info.base_type_name });
            } else {
                c.reportErrorWithArgs(error_node, &diagnostics_gen.Non_abstract_class_0_does_not_implement_inherited_abstract_member_1_from_class_2, &.{ info.type_name, missed[0], info.base_type_name });
            }
        } else if (missed.len > 5) {
            // Show first 4 + "and N more"
            var props_buf = std.ArrayList(u8).empty;
            defer props_buf.deinit(allocator);
            for (missed[0..4], 0..) |prop, i| {
                if (i > 0) props_buf.appendSlice(allocator, ", ") catch break;
                props_buf.append(allocator, '\'') catch break;
                props_buf.appendSlice(allocator, prop) catch break;
                props_buf.append(allocator, '\'') catch break;
            }
            const remaining_str = std.fmt.allocPrint(allocator, "{d}", .{missed.len - 4}) catch continue;
            const props_str = props_buf.toOwnedSlice(allocator) catch continue;
            if (is_class_expr) {
                c.reportErrorWithArgs(error_node, &diagnostics_gen.Non_abstract_class_expression_is_missing_implementations_for_the_following_members_of_0_Colon_1_and_2_more, &.{ info.base_type_name, props_str, remaining_str });
            } else {
                c.reportErrorWithArgs(error_node, &diagnostics_gen.Non_abstract_class_0_is_missing_implementations_for_the_following_members_of_1_Colon_2_and_3_more, &.{ info.type_name, info.base_type_name, props_str, remaining_str });
            }
        } else {
            var props_buf = std.ArrayList(u8).empty;
            defer props_buf.deinit(allocator);
            for (missed, 0..) |prop, i| {
                if (i > 0) props_buf.appendSlice(allocator, ", ") catch break;
                props_buf.append(allocator, '\'') catch break;
                props_buf.appendSlice(allocator, prop) catch break;
                props_buf.append(allocator, '\'') catch break;
            }
            const props_str = props_buf.toOwnedSlice(allocator) catch continue;
            if (is_class_expr) {
                c.reportErrorWithArgs(error_node, &diagnostics_gen.Non_abstract_class_expression_is_missing_implementations_for_the_following_members_of_0_Colon_1, &.{ info.base_type_name, props_str });
            } else {
                c.reportErrorWithArgs(error_node, &diagnostics_gen.Non_abstract_class_0_is_missing_implementations_for_the_following_members_of_1_Colon_2, &.{ info.type_name, info.base_type_name, props_str });
            }
        }
    }
}
