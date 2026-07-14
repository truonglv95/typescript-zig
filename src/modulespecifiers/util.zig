const std = @import("std");
const core = @import("../core/core.zig");
const ast = @import("../ast/ast.zig");
const tspath = @import("../tspath/tspath.zig");
const types = @import("types.zig");

pub fn comparePathsByRedirect(a: types.ModulePath, b: types.ModulePath, useCaseSensitiveFileNames: bool) i32 {
    if (a.IsRedirect != b.IsRedirect) {
        return if (b.IsRedirect) 1 else -1;
    }
    const c = tspath.compareNumberOfDirectorySeparators(a.FileName, b.FileName);
    if (c != 0) {
        return c;
    }
    return tspath.comparePaths(a.FileName, b.FileName, .{ .useCaseSensitiveFileNames = useCaseSensitiveFileNames });
}

pub fn pathIsBareSpecifier(path: []const u8) bool {
    return !tspath.pathIsAbsolute(path) and !tspath.pathIsRelative(path);
}

// Regex matching is mocked
pub fn isExcludedByRegex(moduleSpecifier: []const u8, excludes: [][]const u8) bool {
    _ = moduleSpecifier;
    _ = excludes;
    return false;
}

pub fn ensurePathIsNonModuleName(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    if (pathIsBareSpecifier(path)) {
        return std.fmt.allocPrint(allocator, "./{s}", .{path});
    }
    return allocator.dupe(u8, path);
}

pub fn getJSExtensionForDeclarationFileExtension(ext: []const u8) []const u8 {
    if (std.mem.eql(u8, ext, tspath.ExtensionDts)) {
        return tspath.ExtensionJs;
    }
    if (std.mem.eql(u8, ext, tspath.ExtensionDmts)) {
        return tspath.ExtensionMjs;
    }
    if (std.mem.eql(u8, ext, tspath.ExtensionDcts)) {
        return tspath.ExtensionCjs;
    }
    if (std.mem.startsWith(u8, ext, ".d")) {
        return ext[2 .. ext.len - tspath.ExtensionTs.len];
    }
    return ext;
}

pub fn tryGetRealFileNameForNonJSDeclarationFileName(allocator: std.mem.Allocator, fileName: []const u8) !?[]const u8 {
    const baseName = tspath.getBaseFileName(fileName);
    if (!std.mem.endsWith(u8, fileName, tspath.ExtensionTs) or
        std.mem.indexOf(u8, baseName, ".d.") == null or
        std.mem.endsWith(u8, baseName, tspath.ExtensionDts))
    {
        return null;
    }
    const noExtension = tspath.removeExtension(fileName, tspath.ExtensionTs);
    const lastDotIndex = std.mem.lastIndexOf(u8, noExtension, ".") orelse return null;
    const ext = noExtension[lastDotIndex..];
    
    if (std.mem.indexOf(u8, noExtension, ".d.")) |idx| {
        const before = noExtension[0..idx];
        return try std.fmt.allocPrint(allocator, "{s}{s}", .{ before, ext });
    }
    return null;
}

pub fn getJSExtensionForFile(fileName: []const u8, options: *const core.CompilerOptions) []const u8 {
    _ = fileName;
    _ = options;
    return tspath.ExtensionJs; // Mock implementation
}

pub fn extensionFromPath(path: []const u8) []const u8 {
    const ext = tspath.tryGetExtensionFromPath(path);
    if (ext.len == 0) {
        std.debug.panic("File {s} has unknown extension.", .{path});
    }
    return ext;
}

pub fn tryGetAnyFileFromPath(host: anytype, path: []const u8) bool {
    // Mock for now
    _ = host;
    _ = path;
    return false;
}

pub fn isPathRelativeToParent(path: []const u8) bool {
    return std.mem.startsWith(u8, path, "..");
}

pub fn prefersTsExtension(allowedEndings: []const types.ModuleSpecifierEnding) bool {
    const jsPriority = std.mem.indexOfScalar(types.ModuleSpecifierEnding, allowedEndings, .JsExtension) orelse return false;
    const tsPriority = std.mem.indexOfScalar(types.ModuleSpecifierEnding, allowedEndings, .TsExtension) orelse return false;
    return tsPriority < jsPriority;
}

pub fn replaceFirstStar(allocator: std.mem.Allocator, s: []const u8, replacement: []const u8) ![]const u8 {
    if (std.mem.indexOf(u8, s, "*")) |idx| {
        return std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ s[0..idx], replacement, s[idx + 1 ..] });
    }
    return allocator.dupe(u8, s);
}

pub const NodeModulePathParts = struct {
    topLevelNodeModulesIndex: usize,
    topLevelPackageNameIndex: usize,
    packageRootIndex: usize,
    fileNameIndex: usize,
};

pub fn getNodeModulePathParts(fullPath: []const u8) ?NodeModulePathParts {
    // Simplified stub
    if (std.mem.indexOf(u8, fullPath, "/node_modules/")) |idx| {
        return NodeModulePathParts{
            .topLevelNodeModulesIndex = idx,
            .topLevelPackageNameIndex = idx + 14,
            .packageRootIndex = fullPath.len,
            .fileNameIndex = fullPath.len,
        };
    }
    return null;
}

pub fn allKeysStartWithDot(keys: [][]const u8) bool {
    for (keys) |k| {
        if (!std.mem.startsWith(u8, k, ".")) {
            return false;
        }
    }
    return true;
}

pub fn getPackageNameFromDirectory(fileOrDirectoryPath: []const u8) []const u8 {
    if (std.mem.lastIndexOf(u8, fileOrDirectoryPath, "/node_modules/")) |idx| {
        const basename = fileOrDirectoryPath[idx + 14 ..];
        if (basename.len == 0 or basename[0] == '.') return "";
        const nextSlash = std.mem.indexOf(u8, basename, "/") orelse return basename;
        if (basename[0] != '@' or nextSlash == basename.len - 1) return basename[0..nextSlash];
        if (std.mem.indexOf(u8, basename[nextSlash + 1 ..], "/")) |secondSlash| {
            return basename[0 .. nextSlash + 1 + secondSlash];
        }
        return basename;
    }
    return "";
}

// In typescript-go, ResolvedEntrypoint is part of internal/module.
// Mock for now or import from module
pub fn processEntrypointEnding(
    allocator: std.mem.Allocator,
    entrypoint: anytype,
    prefs: types.UserPreferences,
    host: anytype,
    options: *const core.CompilerOptions,
    tree: *const ast.Tree,
    importingSourceFile: ast.NodeIndex,
    allowedEndings: []const types.ModuleSpecifierEnding,
) ![]const u8 {
    _ = prefs;
    _ = host;
    _ = options;
    _ = tree;
    _ = importingSourceFile;
    _ = allowedEndings;
    // Just a mocked return for now, since full implementation requires module.zig support
    return allocator.dupe(u8, entrypoint.ModuleSpecifier);
}

