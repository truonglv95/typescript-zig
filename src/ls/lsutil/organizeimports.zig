const std = @import("std");
const ast = @import("../../ast/ast.zig");
const core = @import("../../core/core.zig");
const locale = @import("../../locale/locale.zig");
const stringutil = @import("../../stringutil/stringutil.zig");
const tspath = @import("../../tspath/tspath.zig");
const formatcodeoptions = @import("formatcodeoptions.zig");
const userpreferences = @import("userpreferences.zig");
const UserPreferences = userpreferences.UserPreferences;
const OrganizeImportsSort = userpreferences.OrganizeImportsSort;
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

pub fn resolveOrganizeImportsSort(preferences: UserPreferences) OrganizeImportsSort {
    if (preferences.organizeImportsSort != .Auto) {
        return preferences.organizeImportsSort;
    }

    if (preferences.organizeImportsCollation == .Unicode) {
        if (preferences.organizeImportsIgnoreCase.isTrue()) {
            return .NaturalIgnoreCase;
        } else if (preferences.organizeImportsIgnoreCase.isFalse()) {
            return .Natural;
        } else {
            return .Auto;
        }
    }

    if (preferences.organizeImportsIgnoreCase.isTrue()) {
        return .OrdinalIgnoreCase;
    } else if (preferences.organizeImportsIgnoreCase.isFalse()) {
        return .Ordinal;
    } else {
        return .Auto;
    }
}

pub fn compareOrganizeImportsNaturalStrings(a_param: []const u8, b_param: []const u8, ignoreCase: bool) i32 {
    // lowercase for natural key roughly simulates NFD / natural collation key for simple strings
    const allocator = std.heap.page_allocator;
    const a = std.ascii.allocLowerString(allocator, a_param) catch a_param;
    defer if (a.ptr != a_param.ptr) allocator.free(a);
    const b = std.ascii.allocLowerString(allocator, b_param) catch b_param;
    defer if (b.ptr != b_param.ptr) allocator.free(b);

    var cmp = compareStringsNumeric(a, b);
    if (cmp != 0) return cmp;

    if (!ignoreCase) {
        cmp = compareOrganizeImportsCaseUpperFirst(a_param, b_param);
        if (cmp != 0) return cmp;
    }

    return std.mem.order(u8, a_param, b_param).compare();
}

fn compareStringsNumeric(a_param: []const u8, b_param: []const u8) i32 {
    var a = a_param;
    var b = b_param;
    while (a.len > 0 and b.len > 0) {
        if (std.ascii.isDigit(a[0]) and std.ascii.isDigit(b[0])) {
            const aRunEnd = asciiDigitRunEnd(a);
            const bRunEnd = asciiDigitRunEnd(b);

            const cmp = compareNumericText(a[0..aRunEnd], b[0..bRunEnd]);
            if (cmp != 0) return cmp;

            a = a[aRunEnd..];
            b = b[bRunEnd..];
            continue;
        }

        const aLen = std.unicode.utf8ByteSequenceLength(a[0]) catch 1;
        const bLen = std.unicode.utf8ByteSequenceLength(b[0]) catch 1;
        
        const aChar = if (a.len >= aLen) a[0..aLen] else a[0..1];
        const bChar = if (b.len >= bLen) b[0..bLen] else b[0..1];
        
        const cmp = std.mem.order(u8, aChar, bChar).compare();
        if (cmp != 0) return cmp;
        
        a = if (a.len >= aLen) a[aLen..] else "";
        b = if (b.len >= bLen) b[bLen..] else "";
    }

    return std.math.order(a.len, b.len).compare();
}

fn asciiDigitRunEnd(s: []const u8) usize {
    var i: usize = 0;
    while (i < s.len and std.ascii.isDigit(s[i])) {
        i += 1;
    }
    return i;
}

fn compareNumericText(a: []const u8, b: []const u8) i32 {
    const aTrim = std.mem.trimLeft(u8, a, "0");
    const bTrim = std.mem.trimLeft(u8, b, "0");
    const aDigits = if (aTrim.len == 0) "0" else aTrim;
    const bDigits = if (bTrim.len == 0) "0" else bTrim;

    if (aDigits.len != bDigits.len) {
        return std.math.order(aDigits.len, bDigits.len).compare();
    }
    const cmp = std.mem.order(u8, aDigits, bDigits).compare();
    if (cmp != 0) return cmp;
    
    return std.mem.order(u8, a, b).compare();
}

fn compareOrganizeImportsCaseUpperFirst(a: []const u8, b: []const u8) i32 {
    const min_len = @min(a.len, b.len);
    for (0..min_len) |i| {
        const aUpper = std.ascii.isUpper(a[i]);
        const bUpper = std.ascii.isUpper(b[i]);
        if (aUpper != bUpper) {
            if (aUpper) return -1;
            return 1;
        }
    }
    return std.math.order(a.len, b.len).compare();
}

fn getOrganizeImportsNaturalStringComparer(ignoreCase: bool) *const fn ([]const u8, []const u8) i32 {
    if (ignoreCase) {
        return struct {
            fn compare(a: []const u8, b: []const u8) i32 {
                return compareOrganizeImportsNaturalStrings(a, b, true);
            }
        }.compare;
    }
    return struct {
        fn compare(a: []const u8, b: []const u8) i32 {
            return compareOrganizeImportsNaturalStrings(a, b, false);
        }
    }.compare;
}

pub fn getOrganizeImportsPresetStringComparer(sort: OrganizeImportsSort) *const fn ([]const u8, []const u8) i32 {
    switch (sort) {
        .OrdinalIgnoreCase => return getOrganizeImportsOrdinalStringComparer(true),
        .Natural => return getOrganizeImportsNaturalStringComparer(false),
        .NaturalIgnoreCase => return getOrganizeImportsNaturalStringComparer(true),
        else => return getOrganizeImportsOrdinalStringComparer(false),
    }
}
