const std = @import("std");
const ast = @import("../../ast/ast.zig");
const core = @import("../../core/core.zig");
const stringutil = @import("../../stringutil/stringutil.zig");
const tspath = @import("../../tspath/tspath.zig");
const userpreferences = @import("userpreferences.zig");
const UserPreferences = userpreferences.UserPreferences;
const OrganizeImportsSort = userpreferences.OrganizeImportsSort;
const OrganizeImportsCaseFirst = userpreferences.OrganizeImportsCaseFirst;
const OrganizeImportsCollation = userpreferences.OrganizeImportsCollation;
const OrganizeImportsTypeOrder = userpreferences.OrganizeImportsTypeOrder;

pub fn filterImportDeclarations(allocator: std.mem.Allocator, statements: []*ast.Statement) ![]*ast.Statement {
    var result = std.ArrayList(*ast.Statement).init(allocator);
    for (statements) |stmt| {
        if (stmt.kind == .ImportDeclaration) {
            try result.append(stmt);
        }
    }
    return result.toOwnedSlice();
}

pub const ComparerFunction = *const fn (a: []const u8, b: []const u8) std.math.Order;

// In zig we might pass UserPreferences into the compare function or have different static comparers.
// Since zig fn pointers cannot carry state, we can use a Context struct.
pub const ComparerContext = struct {
    prefs: UserPreferences = .{},
    ignoreCase: bool = false,
    sortMode: OrganizeImportsSort = .auto,

    pub fn compare(self: *const ComparerContext, a: []const u8, b: []const u8) std.math.Order {
        if (self.sortMode != .auto) {
            return getOrganizeImportsPresetStringComparer(self.sortMode)(a, b);
        }
        if (self.prefs.organizeImportsCollation == .unicode) {
            // Simplified: we would call the unicode comparer
            return getOrganizeImportsOrdinalStringComparer(self.ignoreCase)(a, b);
        }
        return getOrganizeImportsOrdinalStringComparer(self.ignoreCase)(a, b);
    }
};

pub fn resolveOrganizeImportsSort(preferences: UserPreferences) OrganizeImportsSort {
    if (preferences.organizeImportsSort != .auto) {
        return preferences.organizeImportsSort;
    }

    if (preferences.organizeImportsCollation == .unicode) {
        if (preferences.organizeImportsIgnoreCase.isTrue()) {
            return .naturalIgnoreCase;
        } else if (preferences.organizeImportsIgnoreCase.isFalse()) {
            return .natural;
        } else {
            return .auto;
        }
    }

    if (preferences.organizeImportsIgnoreCase.isTrue()) {
        return .ordinalIgnoreCase;
    } else if (preferences.organizeImportsIgnoreCase.isFalse()) {
        return .ordinal;
    } else {
        return .auto;
    }
}

fn compareStringsCaseSensitive(a: []const u8, b: []const u8) std.math.Order {
    return std.mem.order(u8, a, b);
}

fn compareStringsCaseInsensitiveEslintCompatible(a: []const u8, b: []const u8) std.math.Order {
    const min_len = @min(a.len, b.len);
    for (0..min_len) |i| {
        const ca = std.ascii.toLower(a[i]);
        const cb = std.ascii.toLower(b[i]);
        if (ca != cb) {
            return std.math.order(ca, cb);
        }
    }
    return std.math.order(a.len, b.len);
}

pub fn getOrganizeImportsOrdinalStringComparer(ignoreCase: bool) ComparerFunction {
    if (ignoreCase) {
        return compareStringsCaseInsensitiveEslintCompatible;
    }
    return compareStringsCaseSensitive;
}

pub fn getOrganizeImportsPresetStringComparer(sort: OrganizeImportsSort) ComparerFunction {
    switch (sort) {
        .ordinalIgnoreCase => return getOrganizeImportsOrdinalStringComparer(true),
        .natural => return getOrganizeImportsOrdinalStringComparer(false), // fallback
        .naturalIgnoreCase => return getOrganizeImportsOrdinalStringComparer(true), // fallback
        else => return getOrganizeImportsOrdinalStringComparer(false),
    }
}

pub fn getOrganizeImportsStringComparer(preferences: UserPreferences, ignoreCase: bool) ComparerContext {
    return ComparerContext{
        .prefs = preferences,
        .ignoreCase = ignoreCase,
        .sortMode = preferences.organizeImportsSort,
    };
}

pub fn getModuleSpecifierExpression(declaration: *ast.Statement) ?*ast.Expression {
    switch (declaration.kind) {
        .ImportEqualsDeclaration => {
            const importEquals = declaration.asImportEqualsDeclaration();
            if (importEquals.moduleReference.kind == .ExternalModuleReference) {
                return importEquals.moduleReference.expression();
            }
            return null;
        },
        .ImportDeclaration => return declaration.moduleSpecifier(),
        .VariableStatement => {
            const declarations = declaration.asVariableStatement().declarationList.asVariableDeclarationList().declarations.items;
            if (declarations.len > 0) {
                const initializer = declarations[0].initializer();
                if (initializer != null and initializer.?.kind == .CallExpression) {
                    const callExpr = initializer.?.asCallExpression();
                    if (callExpr.arguments.items.len > 0) {
                        return callExpr.arguments.items[0];
                    }
                }
            }
            return null;
        },
        else => return null,
    }
}

pub fn getExternalModuleName(specifier: ?*ast.Expression) []const u8 {
    if (specifier != null and ast.isStringLiteralLike(specifier.?)) {
        return specifier.?.text();
    }
    return "";
}

pub fn compareModuleSpecifiers(m1: ?*ast.Expression, m2: ?*ast.Expression, comparer: *const ComparerContext) std.math.Order {
    const name1 = getExternalModuleName(m1);
    const name2 = getExternalModuleName(m2);
    const cmpEmpty = core.compareBooleans(name1.len == 0, name2.len == 0);
    if (cmpEmpty != .eq) return cmpEmpty;

    const cmpRelative = core.compareBooleans(tspath.isExternalModuleNameRelative(name1), tspath.isExternalModuleNameRelative(name2));
    if (cmpRelative != .eq) return cmpRelative;

    return comparer.compare(name1, name2);
}

pub const ImportKindOrder = enum(u3) {
    sideEffect = 0,
    typeOnly = 1,
    namespace = 2,
    default = 3,
    named = 4,
    importEquals = 5,
    require = 6,
    unknown = 7,
};

pub fn getImportKindOrder(s1: *ast.Statement) ImportKindOrder {
    switch (s1.kind) {
        .ImportDeclaration => {
            const importDecl = s1.asImportDeclaration();
            if (importDecl.importClause == null) {
                return .sideEffect;
            }
            const importClause = importDecl.importClause.?.asImportClause();
            if (importClause.isTypeOnly()) {
                return .typeOnly;
            }
            if (importClause.namedBindings != null and importClause.namedBindings.?.kind == .NamespaceImport) {
                return .namespace;
            }
            if (importClause.name() != null) {
                return .default;
            }
            return .named;
        },
        .ImportEqualsDeclaration => return .importEquals,
        .VariableStatement => return .require,
        else => return .unknown,
    }
}

pub fn compareImportKind(s1: *ast.Statement, s2: *ast.Statement) std.math.Order {
    const order1 = getImportKindOrder(s1);
    const order2 = getImportKindOrder(s2);
    return std.math.order(@intFromEnum(order1), @intFromEnum(order2));
}

pub fn compareImportsOrRequireStatements(s1: *ast.Statement, s2: *ast.Statement, comparer: *const ComparerContext) std.math.Order {
    const cmp = compareModuleSpecifiers(getModuleSpecifierExpression(s1), getModuleSpecifierExpression(s2), comparer);
    if (cmp != .eq) return cmp;
    return compareImportKind(s1, s2);
}

pub fn compareImportOrExportSpecifiers(s1: *ast.Node, s2: *ast.Node, comparer: *const ComparerContext, preferences: UserPreferences) std.math.Order {
    const typeOrder = preferences.organizeImportsTypeOrder;

    const s1Name = s1.name().?.text();
    const s2Name = s2.name().?.text();

    switch (typeOrder) {
        .first => {
            const cmp = core.compareBooleans(s2.isTypeOnly(), s1.isTypeOnly());
            if (cmp != .eq) return cmp;
            return comparer.compare(s1Name, s2Name);
        },
        .inline => {
            return comparer.compare(s1Name, s2Name);
        },
        else => {
            const cmp = core.compareBooleans(s1.isTypeOnly(), s2.isTypeOnly());
            if (cmp != .eq) return cmp;
            return comparer.compare(s1Name, s2Name);
        },
    }
}

pub const SpecifierComparerContext = struct {
    prefs: UserPreferences,
    comparer: ComparerContext,

    pub fn compare(self: *const SpecifierComparerContext, s1: *ast.Node, s2: *ast.Node) std.math.Order {
        return compareImportOrExportSpecifiers(s1, s2, &self.comparer, self.prefs);
    }
};

pub fn getNamedImportSpecifierComparer(preferences: UserPreferences, comparer: ?ComparerContext) SpecifierComparerContext {
    const finalComparer = comparer orelse getOrganizeImportsStringComparer(preferences, preferences.organizeImportsIgnoreCase.isTrue());
    return .{
        .prefs = preferences,
        .comparer = finalComparer,
    };
}
