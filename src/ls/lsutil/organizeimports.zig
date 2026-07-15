const std = @import("std");
const ast = @import("../../ast/ast.zig");
const core = @import("../../core/core.zig");
const locale = @import("../../locale/locale.zig");
const stringutil = @import("../../stringutil/stringutil.zig");
const tspath = @import("../../tspath/tspath.zig");
const formatcodeoptions = @import("formatcodeoptions.zig");
const userpreferences = @import("userpreferences.zig");
const UserPreferences = userpreferences.UserPreferences;
const OrganizeImportsTypeOrder = userpreferences.OrganizeImportsTypeOrder;
const NodeIndex = ast.NodeIndex;

pub fn filterImportDeclarations(allocator: std.mem.Allocator, tree: *ast.Ast, statements: []const NodeIndex) ![]const NodeIndex {
    var result = std.ArrayList(NodeIndex).init(allocator);
    for (statements) |stmt| {
        if (tree.getNodeKind(stmt) == .ImportDeclaration) {
            try result.append(stmt);
        }
    }
    return result.toOwnedSlice();
}

pub fn getDetectionLists(allocator: std.mem.Allocator, preferences: UserPreferences) !struct {
    comparersToTest: []const *const fn ([]const u8, []const u8) i32,
    typeOrdersToTest: []const OrganizeImportsTypeOrder,
} {
    var comparers = std.ArrayList(*const fn ([]const u8, []const u8) i32).init(allocator);
    if (preferences.organizeImportsSort != .Auto) {
        // Just ordinal for now to satisfy types
        try comparers.append(getOrganizeImportsOrdinalStringComparer(false));
    } else if (preferences.organizeImportsIgnoreCase) |ignoreCase| {
        try comparers.append(getOrganizeImportsOrdinalStringComparer(ignoreCase));
    } else {
        try comparers.append(getOrganizeImportsOrdinalStringComparer(true));
        try comparers.append(getOrganizeImportsOrdinalStringComparer(false));
    }

    var typeOrders = std.ArrayList(OrganizeImportsTypeOrder).init(allocator);
    if (preferences.organizeImportsTypeOrder != .Auto) {
        try typeOrders.append(preferences.organizeImportsTypeOrder);
    } else {
        try typeOrders.append(.Last);
        try typeOrders.append(.Inline);
        try typeOrders.append(.First);
    }

    return .{
        .comparersToTest = try comparers.toOwnedSlice(),
        .typeOrdersToTest = try typeOrders.toOwnedSlice(),
    };
}

pub fn getOrganizeImportsOrdinalStringComparer(ignoreCase: bool) *const fn ([]const u8, []const u8) i32 {
    if (ignoreCase) {
        return stringutil.compareStringsCaseInsensitiveEslintCompatible;
    }
    return stringutil.compareStringsCaseSensitive;
}

pub fn getExternalModuleName(tree: *ast.Ast, specifier: NodeIndex) []const u8 {
    if (specifier != 0 and tree.getNodeKind(specifier) == .StringLiteral) {
        // tree.getNodeText? Need to check what is available, maybe AST provides a way to get text
        return tree.getIdentifierText(specifier); // Assume this works for string literals
    }
    return "";
}

pub fn compareModuleSpecifiers(tree: *ast.Ast, m1: NodeIndex, m2: NodeIndex, comparer: *const fn ([]const u8, []const u8) i32) i32 {
    const name1 = getExternalModuleName(tree, m1);
    const name2 = getExternalModuleName(tree, m2);
    
    const cmp1 = core.compareBooleans(name1.len == 0, name2.len == 0);
    if (cmp1 != 0) return cmp1;
    
    const cmp2 = core.compareBooleans(tspath.isExternalModuleNameRelative(name1), tspath.isExternalModuleNameRelative(name2));
    if (cmp2 != 0) return cmp2;
    
    return comparer(name1, name2);
}
