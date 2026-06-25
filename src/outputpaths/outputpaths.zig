const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const core = @import("../core/core.zig");
const tspath = @import("../tspath/tspath.zig");

pub const OutputPathsHost = struct {
    astState: *ast.Ast,
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        commonSourceDirectory: *const fn (ptr: *anyopaque) []const u8,
        getCurrentDirectory: *const fn (ptr: *anyopaque) []const u8,
        useCaseSensitiveFileNames: *const fn (ptr: *anyopaque) bool,
    };

    pub fn commonSourceDirectory(self: OutputPathsHost) []const u8 {
        return self.vtable.commonSourceDirectory(self.ptr);
    }
    pub fn getCurrentDirectory(self: OutputPathsHost) []const u8 {
        return self.vtable.getCurrentDirectory(self.ptr);
    }
    pub fn useCaseSensitiveFileNames(self: OutputPathsHost) bool {
        return self.vtable.useCaseSensitiveFileNames(self.ptr);
    }
};

pub const OutputPaths = struct {
    jsFilePath: []const u8 = "",
    sourceMapFilePath: []const u8 = "",
    declarationFilePath: []const u8 = "",
    declarationMapPath: []const u8 = "",

    pub fn getDeclarationFilePath(self: *const OutputPaths) []const u8 {
        return self.declarationFilePath;
    }

    pub fn getJsFilePath(self: *const OutputPaths) []const u8 {
        return self.jsFilePath;
    }

    pub fn getSourceMapFilePath(self: *const OutputPaths) []const u8 {
        return self.sourceMapFilePath;
    }

    pub fn getDeclarationMapPath(self: *const OutputPaths) []const u8 {
        return self.declarationMapPath;
    }
};

pub fn getOutputPathsFor(
    allocator: std.mem.Allocator,
    sourceFile: ast.NodeIndex,
    options: *const core.CompilerOptions,
    host: OutputPathsHost,
    forceDtsEmit: bool,
) !*OutputPaths {
    const fileName = try ast_utils.getFileName(host.astState, sourceFile);
    const ownOutputFilePath = try getOwnEmitOutputFilePath(allocator, fileName, options, host, try getOutputExtension(allocator, fileName, options.jsx orelse .None));
    const isJsonFile = ast_utils.isJsonSourceFile(host.astState, sourceFile);
    
    // If json file emits to the same location skip writing it, if emitDeclarationOnly skip writing it
    const isJsonEmittedToSameLocation = isJsonFile and tspath.comparePaths(fileName, ownOutputFilePath, .{
        .currentDirectory = host.getCurrentDirectory(),
        .useCaseSensitiveFileNames = host.useCaseSensitiveFileNames(),
    }) == 0;
    
    var paths = try allocator.create(OutputPaths);
    paths.* = .{};
    
    if ((options.emitDeclarationOnly orelse false) != true and !isJsonEmittedToSameLocation) {
        paths.jsFilePath = ownOutputFilePath;
        if (!isJsonFile) {
            paths.sourceMapFilePath = try getSourceMapFilePath(allocator, paths.jsFilePath, options);
        }
    }
    
    const getEmitDeclarations = (options.declaration orelse false) or (options.composite orelse false);
    
    if (forceDtsEmit or (getEmitDeclarations and !isJsonFile)) {
        paths.declarationFilePath = try getDeclarationEmitOutputFilePath(allocator, fileName, options, host);
        const getAreDeclarationMapsEnabled = options.declarationMap orelse false;
        if (getAreDeclarationMapsEnabled) {
            paths.declarationMapPath = try std.fmt.allocPrint(allocator, "{s}.map", .{paths.declarationFilePath});
        }
    }
    return paths;
}

pub fn forEachEmittedFile(
    allocator: std.mem.Allocator,
    host: OutputPathsHost,
    options: *const core.CompilerOptions,
    action: anytype,
    sourceFiles: []const ast.NodeIndex,
    forceDtsEmit: bool,
) !bool {
    for (sourceFiles) |sourceFile| {
        const paths = try getOutputPathsFor(allocator, sourceFile, options, host, forceDtsEmit);
        if (action(paths, sourceFile)) {
            return true;
        }
    }
    return false;
}

pub fn getOutputJSFileName(allocator: std.mem.Allocator, inputFileName: []const u8, options: *const core.CompilerOptions, host: OutputPathsHost) ![]const u8 {
    if (options.emitDeclarationOnly orelse false) {
        return "";
    }
    const outputFileName = try getOutputJSFileNameWorker(allocator, inputFileName, options, host);
    if (!tspath.fileExtensionIs(outputFileName, tspath.ExtensionJson) or
        tspath.comparePaths(inputFileName, outputFileName, .{
            .currentDirectory = host.getCurrentDirectory(),
            .useCaseSensitiveFileNames = host.useCaseSensitiveFileNames(),
        }) != 0)
    {
        return outputFileName;
    }
    return "";
}

pub fn getOutputJSFileNameWorker(allocator: std.mem.Allocator, inputFileName: []const u8, options: *const core.CompilerOptions, host: OutputPathsHost) ![]const u8 {
    const outputPath = try getOutputPathWithoutChangingExtension(allocator, inputFileName, options.outDir orelse "", host);
    const ext = try getOutputExtension(allocator, inputFileName, options.jsx orelse .None);
    return try tspath.changeExtension(allocator, outputPath, ext);
}

pub fn getOutputDeclarationFileNameWorker(allocator: std.mem.Allocator, inputFileName: []const u8, options: *const core.CompilerOptions, host: OutputPathsHost) ![]const u8 {
    var dir = options.declarationDir orelse "";
    if (dir.len == 0) {
        dir = options.outDir orelse "";
    }
    const outputPath = try getOutputPathWithoutChangingExtension(allocator, inputFileName, dir, host);
    const ext = try tspath.getDeclarationEmitExtensionForPath(allocator, inputFileName);
    return try tspath.changeExtension(allocator, outputPath, ext);
}

pub fn getOutputExtension(allocator: std.mem.Allocator, fileName: []const u8, jsx: core.JsxEmit) ![]const u8 {
    _ = allocator;
    if (tspath.fileExtensionIs(fileName, tspath.ExtensionJson)) {
        return tspath.ExtensionJson;
    } else if (jsx == core.JsxEmit.Preserve and tspath.fileExtensionIsOneOf(fileName, &[_][]const u8{ tspath.ExtensionJsx, tspath.ExtensionTsx })) {
        return tspath.ExtensionJsx;
    } else if (tspath.fileExtensionIsOneOf(fileName, &[_][]const u8{ tspath.ExtensionMts, tspath.ExtensionMjs })) {
        return tspath.ExtensionMjs;
    } else if (tspath.fileExtensionIsOneOf(fileName, &[_][]const u8{ tspath.ExtensionCts, tspath.ExtensionCjs })) {
        return tspath.ExtensionCjs;
    } else {
        return tspath.ExtensionJs;
    }
}

pub fn getDeclarationEmitOutputFilePath(allocator: std.mem.Allocator, file: []const u8, options: *const core.CompilerOptions, host: OutputPathsHost) ![]const u8 {
    var outputDir: ?[]const u8 = null;
    if ((options.declarationDir orelse "").len > 0) {
        outputDir = options.declarationDir;
    } else if ((options.outDir orelse "").len > 0) {
        outputDir = options.outDir;
    }

    var path: []const u8 = undefined;
    if (outputDir) |dir| {
        path = try getSourceFilePathInNewDirWorker(allocator, file, dir, host.getCurrentDirectory(), host.commonSourceDirectory(), host.useCaseSensitiveFileNames());
    } else {
        path = file;
    }
    const declarationExtension = try tspath.getDeclarationEmitExtensionForPath(allocator, path);
    return try std.fmt.allocPrint(allocator, "{s}{s}", .{ tspath.removeFileExtension(path), declarationExtension });
}

pub fn getSourceFilePathInNewDir(allocator: std.mem.Allocator, fileName: []const u8, newDirPath: []const u8, currentDirectory: []const u8, commonSourceDirectory: []const u8, useCaseSensitiveFileNames: bool) ![]const u8 {
    var sourceFilePath = try tspath.getNormalizedAbsolutePath(allocator, fileName, currentDirectory);
    const commonSrcDir = try tspath.ensureTrailingDirectorySeparator(allocator, commonSourceDirectory);
    const isSourceFileInCommonSourceDirectory = tspath.containsPath(commonSrcDir, sourceFilePath, .{
        .useCaseSensitiveFileNames = useCaseSensitiveFileNames,
        .currentDirectory = currentDirectory,
    });
    if (isSourceFileInCommonSourceDirectory) {
        sourceFilePath = sourceFilePath[commonSrcDir.len..];
    }
    return try tspath.combinePaths(allocator, newDirPath, sourceFilePath);
}

pub fn getOutputPathWithoutChangingExtension(allocator: std.mem.Allocator, inputFileName: []const u8, outputDirectory: []const u8, host: OutputPathsHost) ![]const u8 {
    if (outputDirectory.len > 0) {
        const relativePath = try tspath.getRelativePathFromDirectory(allocator, host.commonSourceDirectory(), inputFileName, .{
            .useCaseSensitiveFileNames = host.useCaseSensitiveFileNames(),
            .currentDirectory = host.getCurrentDirectory(),
        });
        return try tspath.resolvePath(allocator, outputDirectory, relativePath);
    }
    return inputFileName;
}

pub fn getSourceFilePathInNewDirWorker(allocator: std.mem.Allocator, fileName: []const u8, newDirPath: []const u8, currentDirectory: []const u8, commonSourceDirectory: []const u8, useCaseSensitiveFileNames: bool) ![]const u8 {
    var sourceFilePath = try tspath.getNormalizedAbsolutePath(allocator, fileName, currentDirectory);
    const commonDir = try tspath.getCanonicalFileName(allocator, commonSourceDirectory, useCaseSensitiveFileNames);
    const canonFile = try tspath.getCanonicalFileName(allocator, sourceFilePath, useCaseSensitiveFileNames);
    const isSourceFileInCommonSourceDirectory = std.mem.startsWith(u8, canonFile, commonDir);
    if (isSourceFileInCommonSourceDirectory) {
        sourceFilePath = sourceFilePath[commonSourceDirectory.len..];
    }
    return try tspath.combinePaths(allocator, newDirPath, sourceFilePath);
}

pub fn getOwnEmitOutputFilePath(allocator: std.mem.Allocator, fileName: []const u8, options: *const core.CompilerOptions, host: OutputPathsHost, extension: []const u8) ![]const u8 {
    var emitOutputFilePathWithoutExtension: []const u8 = undefined;
    if ((options.outDir orelse "").len > 0) {
        const currentDirectory = host.getCurrentDirectory();
        const srcPathInNewDir = try getSourceFilePathInNewDir(
            allocator,
            fileName,
            options.outDir orelse "",
            currentDirectory,
            host.commonSourceDirectory(),
            host.useCaseSensitiveFileNames(),
        );
        emitOutputFilePathWithoutExtension = tspath.removeFileExtension(srcPathInNewDir);
    } else {
        emitOutputFilePathWithoutExtension = tspath.removeFileExtension(fileName);
    }
    return try std.fmt.allocPrint(allocator, "{s}{s}", .{ emitOutputFilePathWithoutExtension, extension });
}

pub fn getSourceMapFilePath(allocator: std.mem.Allocator, jsFilePath: []const u8, options: *const core.CompilerOptions) ![]const u8 {
    if ((options.sourceMap orelse false) and !(options.inlineSourceMap orelse false)) {
        return try std.fmt.allocPrint(allocator, "{s}.map", .{jsFilePath});
    }
    return "";
}

pub fn getBuildInfoFileName(allocator: std.mem.Allocator, options: *const core.CompilerOptions, opts: tspath.ComparePathsOptions) ![]const u8 {
    const isIncremental = options.incremental orelse false;
    const isBuild = options.build orelse false;
    
    if (!isIncremental and !isBuild) {
        return "";
    }
    if ((options.tsBuildInfoFile orelse "").len > 0) {
        return options.tsBuildInfoFile.?;
    }
    if ((options.configFilePath orelse "").len == 0) {
        return "";
    }
    const configFileExtensionLess = tspath.removeFileExtension(options.configFilePath.?);
    var buildInfoExtensionLess: []const u8 = undefined;
    if ((options.outDir orelse "").len > 0) {
        if ((options.rootDir orelse "").len > 0) {
            const relativePath = try tspath.getRelativePathFromDirectory(allocator, options.rootDir.?, configFileExtensionLess, opts);
            buildInfoExtensionLess = try tspath.resolvePath(allocator, options.outDir.?, relativePath);
        } else {
            buildInfoExtensionLess = try tspath.combinePaths(allocator, options.outDir.?, tspath.getBaseFileName(configFileExtensionLess));
        }
    } else {
        buildInfoExtensionLess = configFileExtensionLess;
    }
    return try std.fmt.allocPrint(allocator, "{s}{s}", .{ buildInfoExtensionLess, tspath.ExtensionTsBuildInfo });
}
