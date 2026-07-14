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
    _ = allocator;
    _ = preferences;
    // TODO: implement fully
    return .{
        .comparersToTest = &[_]*const fn ([]const u8, []const u8) i32{},
        .typeOrdersToTest = &[_]OrganizeImportsTypeOrder{},
    };
}

pub fn getOrganizeImportsOrdinalStringComparer(ignoreCase: bool) *const fn ([]const u8, []const u8) i32 {
    _ = ignoreCase;
    // TODO
    return undefined;
}

pub fn getExternalModuleName(tree: *ast.Ast, specifier: NodeIndex) []const u8 {
    _ = tree;
    _ = specifier;
    // TODO
    return "";
}

pub fn compareModuleSpecifiers(tree: *ast.Ast, m1: NodeIndex, m2: NodeIndex, comparer: *const fn ([]const u8, []const u8) i32) i32 {
    const name1 = getExternalModuleName(tree, m1);
    const name2 = getExternalModuleName(tree, m2);
    _ = name1;
    _ = name2;
    _ = comparer;
    // TODO
    return 0;
}
