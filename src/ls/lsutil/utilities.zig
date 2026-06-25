const std = @import("std");
const ast = @import("../../ast/ast.zig");
const astnav = @import("../../ast/ast_utils.zig");
const compiler = @import("../../compiler/program.zig");
const core = @import("../../core/core.zig");
const scanner = @import("../../scanner/scanner.zig");
const stringutil = @import("../../stringutil/stringutil.zig");
const tspath = @import("../../tspath/tspath.zig");
const formatcodeoptions = @import("formatcodeoptions.zig");
const QuotePreference = @import("userpreferences.zig").QuotePreference;
const UserPreferences = @import("userpreferences.zig").UserPreferences;
const children = @import("children.zig");
const NodeIndex = ast.NodeIndex;

pub fn probablyUsesSemicolons(tree: *ast.Ast) bool {
    _ = tree;
    // TODO
    return true;
}

pub fn shouldUseUriStyleNodeCoreModules(tree: *ast.Ast, prog: *compiler.Program) core.Tristate {
    _ = tree;
    _ = prog;
    // TODO
    return .False;
}

pub fn quotePreferenceFromString(tree: *ast.Ast, str: NodeIndex) QuotePreference {
    _ = tree;
    _ = str;
    // TODO
    return .Double;
}

pub fn getQuotePreference(tree: *ast.Ast, preferences: UserPreferences) QuotePreference {
    _ = tree;
    _ = preferences;
    // TODO
    return .Double;
}

pub fn moduleSymbolToValidIdentifier(tree: *ast.Ast, moduleSymbol: ast.SymbolIndex, forceCapitalize: bool) []const u8 {
    _ = tree;
    _ = moduleSymbol;
    _ = forceCapitalize;
    // TODO
    return "";
}

pub fn moduleSpecifierToValidIdentifier(allocator: std.mem.Allocator, moduleSpecifier: []const u8, forceCapitalize: bool) []const u8 {
    _ = allocator;
    _ = moduleSpecifier;
    _ = forceCapitalize;
    // TODO
    return "";
}

pub fn isNonContextualKeyword(token: ast.Kind) bool {
    return astnav.isKeywordKind(token) and !astnav.isContextualKeyword(token);
}
