const std = @import("std");
const core = @import("../core/core.zig");
const ast = @import("../ast/ast.zig");
const tspath = @import("../tspath/tspath.zig");
const types = @import("types.zig");
const preferences = @import("preferences.zig");
const util = @import("util.zig");

pub const ImportModuleSpecifierPreference = enum {
    Shortest,
    ProjectRelative,
    Relative,
    NonRelative,
};

pub const ImportModuleSpecifierEndingPreference = enum {
    Auto,
    Minimal,
    Index,
    JsExtension,
};

pub fn getModuleSpecifiers(
    allocator: std.mem.Allocator,
    moduleSymbol: *ast.Symbol,
    checker: anytype,
    compilerOptions: *const core.CompilerOptions,
    tree: *const ast.Tree,
    importingSourceFile: ast.NodeIndex,
    host: anytype,
    userPreferences: types.UserPreferences,
    options: types.ModuleSpecifierOptions,
    forAutoImports: bool,
) ![][]const u8 {
    const result = try getModuleSpecifiersWithInfo(
        allocator,
        moduleSymbol,
        checker,
        compilerOptions,
        tree,
        importingSourceFile,
        host,
        userPreferences,
        options,
        forAutoImports,
    );
    return result[0];
}

pub fn getModuleSpecifiersWithInfo(
    allocator: std.mem.Allocator,
    moduleSymbol: *ast.Symbol,
    checker: anytype,
    compilerOptions: *const core.CompilerOptions,
    tree: *const ast.Tree,
    importingSourceFile: ast.NodeIndex,
    host: anytype,
    userPreferences: types.UserPreferences,
    options: types.ModuleSpecifierOptions,
    forAutoImports: bool,
) !struct { [][]const u8, types.ResultKind } {
    // This is a partial stub porting the beginning of GetModuleSpecifiersWithInfo.
    const ambient = tryGetModuleNameFromAmbientModule(moduleSymbol, checker);
    if (ambient.len > 0) {
        if (forAutoImports and util.isExcludedByRegex(ambient, userPreferences.AutoImportSpecifierExcludeRegexes)) {
            return .{ &[_][]const u8{}, .Ambient };
        }
        var arr = try allocator.alloc([]const u8, 1);
        arr[0] = ambient;
        return .{ arr, .Ambient };
    }

    // Since we don't have GetSourceFileOfModule yet, mock return
    _ = tree;
    _ = importingSourceFile;
    _ = host;
    _ = compilerOptions;
    _ = options;
    return .{ &[_][]const u8{}, .None };
}

pub fn getModuleSpecifiersForFileWithInfo(
    allocator: std.mem.Allocator,
    tree: *const ast.Tree,
    importingSourceFile: ast.NodeIndex,
    moduleFileName: []const u8,
    compilerOptions: *const core.CompilerOptions,
    host: anytype,
    userPreferences: types.UserPreferences,
    options: types.ModuleSpecifierOptions,
    forAutoImports: bool,
) !struct { [][]const u8, types.ResultKind } {
    _ = allocator;
    _ = tree;
    _ = importingSourceFile;
    _ = moduleFileName;
    _ = compilerOptions;
    _ = host;
    _ = userPreferences;
    _ = options;
    _ = forAutoImports;
    return .{ &[_][]const u8{}, .None };
}

pub fn tryGetModuleNameFromAmbientModule(moduleSymbol: *ast.Symbol, checker: anytype) []const u8 {
    _ = moduleSymbol;
    _ = checker;
    return "";
}

pub fn containsNodeModules(s: []const u8) bool {
    return std.mem.indexOf(u8, s, "/node_modules/") != null;
}

pub fn getEachFileNameOfModule(
    allocator: std.mem.Allocator,
    importingFileName: []const u8,
    importedFileName: []const u8,
    host: anytype,
    preferSymlinks: bool,
) ![]types.ModulePath {
    _ = allocator;
    _ = importingFileName;
    _ = importedFileName;
    _ = host;
    _ = preferSymlinks;
    return &[_]types.ModulePath{};
}

pub fn getModuleSpecifier(
    allocator: std.mem.Allocator,
    compilerOptions: *const core.CompilerOptions,
    tree: *const ast.Tree,
    importingSourceFile: ast.NodeIndex,
    toFileName: []const u8,
    host: anytype,
    userPreferences: types.UserPreferences,
    options: types.ModuleSpecifierOptions,
) ![]const u8 {
    _ = allocator;
    _ = compilerOptions;
    _ = tree;
    _ = importingSourceFile;
    _ = toFileName;
    _ = host;
    _ = userPreferences;
    _ = options;
    return "";
}

pub fn updateModuleSpecifier(
    allocator: std.mem.Allocator,
    compilerOptions: *const core.CompilerOptions,
    tree: *const ast.Tree,
    importingSourceFile: ast.NodeIndex,
    toFileName: []const u8,
    host: anytype,
    oldSpecifier: []const u8,
    userPreferences: types.UserPreferences,
    options: types.ModuleSpecifierOptions,
) !?[]const u8 {
    _ = allocator;
    _ = compilerOptions;
    _ = tree;
    _ = importingSourceFile;
    _ = toFileName;
    _ = host;
    _ = oldSpecifier;
    _ = userPreferences;
    _ = options;
    return null;
}
