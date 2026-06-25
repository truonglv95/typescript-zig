const std = @import("std");
const core = @import("../core/core.zig");
const tspath = @import("../tspath/tspath.zig");

pub fn computeCommonSourceDirectoryOfFilenames(
    allocator: std.mem.Allocator,
    fileNames: [][]const u8,
    currentDirectory: []const u8,
    useCaseSensitiveFileNames: bool,
) ![]const u8 {
    var commonPathComponents: ?[][]const u8 = null;
    
    for (fileNames) |sourceFile| {
        var sourcePathComponents = try tspath.getNormalizedPathComponents(allocator, sourceFile, currentDirectory);
        
        if (sourcePathComponents.len > 0) {
            sourcePathComponents = sourcePathComponents[0 .. sourcePathComponents.len - 1];
        }
        
        if (commonPathComponents == null) {
            commonPathComponents = sourcePathComponents;
            continue;
        }
        
        const n = @min(commonPathComponents.?.len, sourcePathComponents.len);
        for (0..n) |i| {
            const canonCommon = try tspath.getCanonicalFileName(allocator, commonPathComponents.?[i], useCaseSensitiveFileNames);
            const canonSource = try tspath.getCanonicalFileName(allocator, sourcePathComponents[i], useCaseSensitiveFileNames);
            if (!std.mem.eql(u8, canonCommon, canonSource)) {
                if (i == 0) {
                    return "";
                }
                commonPathComponents = commonPathComponents.?[0..i];
                break;
            }
        }
        
        if (sourcePathComponents.len < commonPathComponents.?.len) {
            commonPathComponents = commonPathComponents.?[0..sourcePathComponents.len];
        }
    }
    
    if (commonPathComponents == null or commonPathComponents.?.len == 0) {
        return currentDirectory;
    }
    
    return try tspath.getPathFromPathComponents(allocator, commonPathComponents.?);
}

pub fn getComputedCommonSourceDirectory(
    allocator: std.mem.Allocator,
    emittedFiles: [][]const u8,
    currentDirectory: []const u8,
    useCaseSensitiveFileNames: bool,
) ![]const u8 {
    var commonSourceDirectory = try computeCommonSourceDirectoryOfFilenames(allocator, emittedFiles, currentDirectory, useCaseSensitiveFileNames);
    if (commonSourceDirectory.len > 0) {
        commonSourceDirectory = try tspath.ensureTrailingDirectorySeparator(allocator, commonSourceDirectory);
    }
    return commonSourceDirectory;
}

pub fn getCommonSourceDirectory(
    allocator: std.mem.Allocator,
    options: *core.CompilerOptions,
    filesFn: *const fn() [][]const u8,
    currentDirectory: []const u8,
    useCaseSensitiveFileNames: bool,
    checkSourceFilesBelongToPath: ?*const fn([][]const u8, []const u8) void,
) ![]const u8 {
    var commonSourceDirectory: []const u8 = "";
    
    if (options.rootDir != null and options.rootDir.?.len > 0) {
        commonSourceDirectory = options.rootDir.?;
        if (checkSourceFilesBelongToPath) |checkFn| {
            checkFn(filesFn(), options.rootDir.?);
        }
    } else if (options.configFilePath != null and options.configFilePath.?.len > 0) {
        commonSourceDirectory = try tspath.getDirectoryPath(allocator, options.configFilePath.?);
        if (checkSourceFilesBelongToPath) |checkFn| {
            checkFn(filesFn(), commonSourceDirectory);
        }
    } else {
        commonSourceDirectory = try computeCommonSourceDirectoryOfFilenames(allocator, filesFn(), currentDirectory, useCaseSensitiveFileNames);
    }
    
    if (commonSourceDirectory.len > 0) {
        commonSourceDirectory = try tspath.ensureTrailingDirectorySeparator(allocator, commonSourceDirectory);
    }
    return commonSourceDirectory;
}
