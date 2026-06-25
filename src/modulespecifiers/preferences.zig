const std = @import("std");
const core = @import("../core/core.zig");
const ast = @import("../ast/ast.zig");
const tspath = @import("../tspath/tspath.zig");
const types = @import("types.zig");

pub fn shouldAllowImportingTsExtension(compilerOptions: *const core.CompilerOptions, fromFileName: []const u8) bool {
    // In DoD, compilerOptions fields might be named slightly differently, assuming allowImportingTsExtensions.
    return compilerOptions.allowImportingTsExtensions or (fromFileName.len > 0 and tspath.isDeclarationFileName(fromFileName));
}

// Stub for now
pub fn usesExtensionsOnImports(tree: *const ast.Tree, sourceFileIndex: ast.NodeIndex) bool {
    _ = tree;
    _ = sourceFileIndex;
    return false;
}

pub fn inferPreference(
    resolutionMode: core.ModuleKind,
    tree: *const ast.Tree,
    sourceFileIndex: ast.NodeIndex,
    moduleResolutionIsNodeNext: bool,
) types.ModuleSpecifierEnding {
    _ = tree;
    _ = sourceFileIndex;
    _ = resolutionMode;
    _ = moduleResolutionIsNodeNext;
    return .Minimal;
}

pub fn getModuleSpecifierEndingPreference(
    pref: types.ImportModuleSpecifierEndingPreference,
    resolutionMode: core.ModuleKind,
    compilerOptions: *const core.CompilerOptions,
    tree: *const ast.Tree,
    sourceFileIndex: ast.NodeIndex,
) types.ModuleSpecifierEnding {
    const moduleResolution = compilerOptions.moduleResolution;
    const moduleResolutionIsNodeNext = @intFromEnum(core.ModuleResolutionKind.Node16) <= @intFromEnum(moduleResolution) and @intFromEnum(moduleResolution) <= @intFromEnum(core.ModuleResolutionKind.NodeNext);

    if (pref == .Js or (resolutionMode == .ESNext and moduleResolutionIsNodeNext)) {
        if (!shouldAllowImportingTsExtension(compilerOptions, "")) {
            return .JsExtension;
        }
        if (inferPreference(resolutionMode, tree, sourceFileIndex, moduleResolutionIsNodeNext) != .JsExtension) {
            return .TsExtension;
        }
        return .JsExtension;
    }

    if (pref == .Minimal) {
        return .Minimal;
    }

    if (pref == .Index) {
        return .Index;
    }

    if (!shouldAllowImportingTsExtension(compilerOptions, "")) {
        if (sourceFileIndex != ast.NodeIndex.Null and usesExtensionsOnImports(tree, sourceFileIndex)) {
            return .JsExtension;
        }
        return .Minimal;
    }

    return inferPreference(resolutionMode, tree, sourceFileIndex, moduleResolutionIsNodeNext);
}

// We mock ModuleSpecifierGenerationHost as anytype in Zig or just a host context pointer.
pub fn getPreferredEnding(
    prefs: types.UserPreferences,
    host: anytype,
    compilerOptions: *const core.CompilerOptions,
    tree: *const ast.Tree,
    importingSourceFile: ast.NodeIndex,
    oldImportSpecifier: []const u8,
    resolutionMode: core.ModuleKind,
) types.ModuleSpecifierEnding {
    if (oldImportSpecifier.len > 0) {
        if (tspath.hasJSFileExtension(oldImportSpecifier)) {
            return .JsExtension;
        }
        if (std.mem.endsWith(u8, oldImportSpecifier, "/index")) {
            return .Index;
        }
    }
    
    var actualResolutionMode = resolutionMode;
    if (actualResolutionMode == .None) {
        actualResolutionMode = host.getDefaultResolutionModeForFile(importingSourceFile);
    }
    
    return getModuleSpecifierEndingPreference(
        prefs.ImportModuleSpecifierEnding,
        actualResolutionMode,
        compilerOptions,
        tree,
        importingSourceFile,
    );
}

pub const ModuleSpecifierPreferences = struct {
    relativePreference: types.RelativePreferenceKind,
    getAllowedEndingsInPreferredOrder: *const fn(syntaxImpliedNodeFormat: core.ModuleKind) []const types.ModuleSpecifierEnding,
    excludeRegexes: [][]const u8,
};

pub fn getAllowedEndingsInPreferredOrder(
    allocator: std.mem.Allocator,
    prefs: types.UserPreferences,
    host: anytype,
    compilerOptions: *const core.CompilerOptions,
    tree: *const ast.Tree,
    importingSourceFile: ast.NodeIndex,
    oldImportSpecifier: []const u8,
    syntaxImpliedNodeFormat: core.ModuleKind,
) ![]types.ModuleSpecifierEnding {
    var preferredEnding = getPreferredEnding(
        prefs,
        host,
        compilerOptions,
        tree,
        importingSourceFile,
        oldImportSpecifier,
        .None,
    );
    
    const resolutionMode = host.getDefaultResolutionModeForFile(importingSourceFile);
    if (resolutionMode != syntaxImpliedNodeFormat) {
        preferredEnding = getPreferredEnding(
            prefs,
            host,
            compilerOptions,
            tree,
            importingSourceFile,
            oldImportSpecifier,
            syntaxImpliedNodeFormat,
        );
    }
    
    const moduleResolution = compilerOptions.moduleResolution;
    const moduleResolutionIsNodeNext = @intFromEnum(core.ModuleResolutionKind.Node16) <= @intFromEnum(moduleResolution) and @intFromEnum(moduleResolution) <= @intFromEnum(core.ModuleResolutionKind.NodeNext);
    const allowImportingTsExt = shouldAllowImportingTsExtension(compilerOptions, tree.nodes.get(importingSourceFile).SourceFile.FileName); // Mock fileName access
    
    var results = std.ArrayList(types.ModuleSpecifierEnding).init(allocator);
    
    if (syntaxImpliedNodeFormat == .ESNext and moduleResolutionIsNodeNext) {
        if (allowImportingTsExt) {
            try results.appendSlice(&.{ .TsExtension, .JsExtension });
            return results.toOwnedSlice();
        }
        try results.append(.JsExtension);
        return results.toOwnedSlice();
    }
    
    switch (preferredEnding) {
        .JsExtension => {
            if (allowImportingTsExt) {
                try results.appendSlice(&.{ .JsExtension, .TsExtension, .Minimal, .Index });
            } else {
                try results.appendSlice(&.{ .JsExtension, .Minimal, .Index });
            }
        },
        .TsExtension => {
            try results.appendSlice(&.{ .TsExtension, .Minimal, .JsExtension, .Index });
        },
        .Index => {
            if (allowImportingTsExt) {
                try results.appendSlice(&.{ .Index, .Minimal, .TsExtension, .JsExtension });
            } else {
                try results.appendSlice(&.{ .Index, .Minimal, .JsExtension });
            }
        },
        .Minimal => {
            if (allowImportingTsExt) {
                try results.appendSlice(&.{ .Minimal, .Index, .TsExtension, .JsExtension });
            } else {
                try results.appendSlice(&.{ .Minimal, .Index, .JsExtension });
            }
        },
    }
    
    return results.toOwnedSlice();
}

pub fn getModuleSpecifierPreferences(
    prefs: types.UserPreferences,
    host: anytype,
    compilerOptions: *const core.CompilerOptions,
    tree: *const ast.Tree,
    importingSourceFile: ast.NodeIndex,
    oldImportSpecifier: []const u8,
) ModuleSpecifierPreferences {
    _ = host;
    _ = compilerOptions;
    _ = tree;
    _ = importingSourceFile;

    const excludes = prefs.AutoImportSpecifierExcludeRegexes;
    var relativePreference: types.RelativePreferenceKind = .Shortest;
    
    if (oldImportSpecifier.len > 0) {
        if (tspath.isExternalModuleNameRelative(oldImportSpecifier)) {
            relativePreference = .Relative;
        } else {
            relativePreference = .NonRelative;
        }
    } else {
        switch (prefs.ImportModuleSpecifierPreference) {
            .Relative => relativePreference = .Relative,
            .NonRelative => relativePreference = .NonRelative,
            .ProjectRelative => relativePreference = .ExternalNonRelative,
            else => {},
        }
    }
    
    // In Zig, creating a closure requires a struct context. For simplicity, we just return the data struct 
    // and callers will call a helper instead of the function pointer.
    return ModuleSpecifierPreferences{
        .excludeRegexes = excludes,
        .relativePreference = relativePreference,
        .getAllowedEndingsInPreferredOrder = undefined, // To be replaced by a direct call or bound context
    };
}
