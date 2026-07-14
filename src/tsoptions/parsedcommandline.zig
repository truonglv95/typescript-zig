const std = @import("std");
const ast = @import("../ast/ast.zig");
const core = @import("../core/core.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const glob = @import("../glob/glob.zig");
const locale = @import("../locale/locale.zig");
const module_pkg = @import("../module/module.zig");
const outputpaths = @import("../outputpaths/outputpaths.zig");
const tspath = @import("../tspath/tspath.zig");
const vfs = @import("../vfs/vfs.zig");
const vfsmatch = @import("../vfs/vfsmatch.zig");
const tsconfig = @import("tsconfig.zig");

pub const fileGlobPattern = "*.{js,jsx,mjs,cjs,ts,tsx,mts,cts,json}";
pub const recursiveFileGlobPattern = "**/*.{js,jsx,mjs,cjs,ts,tsx,mts,cts,json}";

pub const SourceOutputAndProjectReference = struct {
    Source: []const u8,
    OutputDts: []const u8,
    Resolved: *ParsedCommandLine,
};

pub const ParsedCommandLine = struct {
    allocator: std.mem.Allocator,

    ParsedConfig: *core.ParsedOptions,
    ConfigFile: ?*tsconfig.TsConfigSourceFile = null,
    Errors: std.ArrayList(*ast.Diagnostic),
    Raw: ?*anyopaque = null,
    CompileOnSave: ?bool = null,

    comparePathsOptions: tspath.ComparePathsOptions,
    wildcardDirectoriesOnce: bool = false,
    wildcardDirectories: ?std.StringHashMap(bool) = null,
    includeGlobsOnce: bool = false,
    includeGlobs: ?[]*glob.Glob = null,
    extraFileExtensions: []tsconfig.FileExtensionInfo = &[_]tsconfig.FileExtensionInfo{},

    sourceAndOutputMapsOnce: bool = false,
    sourceToProjectReference: ?std.AutoHashMap(tspath.Path, *SourceOutputAndProjectReference) = null,
    outputDtsToProjectReference: ?std.AutoHashMap(tspath.Path, *SourceOutputAndProjectReference) = null,

    commonSourceDirectory: ?[]const u8 = null,
    commonSourceDirectoryOnce: bool = false,

    resolvedProjectReferencePaths: ?[][]const u8 = null,
    resolvedProjectReferencePathsOnce: bool = false,

    literalFileNamesLen: usize = 0,
    fileNamesByPath: ?std.AutoHashMap(tspath.Path, []const u8) = null,
    fileNamesByPathOnce: bool = false,

    locale: ?locale.Locale = null,
    localeOnce: bool = false,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        compilerOptions: *core.CompilerOptions,
        rootFileNames: [][]const u8,
        comparePathsOptions_: tspath.ComparePathsOptions,
    ) !*Self {
        const p = try allocator.create(Self);
        const parsedConfig = try allocator.create(core.ParsedOptions);
        parsedConfig.* = .{
            .CompilerOptions = compilerOptions,
            .FileNames = rootFileNames,
        };
        p.* = .{
            .allocator = allocator,
            .ParsedConfig = parsedConfig,
            .comparePathsOptions = comparePathsOptions_,
            .Errors = std.ArrayList(*ast.Diagnostic).init(allocator),
        };
        return p;
    }

    pub fn ConfigName(self: *Self) []const u8 {
        if (self.ConfigFile) |cf| {
            return cf.SourceFile.FileName();
        }
        return "";
    }

    pub fn SourceToProjectReference(self: *Self) ?std.AutoHashMap(tspath.Path, *SourceOutputAndProjectReference) {
        return self.sourceToProjectReference;
    }

    pub fn OutputDtsToProjectReference(self: *Self) ?std.AutoHashMap(tspath.Path, *SourceOutputAndProjectReference) {
        return self.outputDtsToProjectReference;
    }

    pub const OutputDeclAndSourceIterator = struct {
        p: *Self,
        index: usize,

        pub const Item = struct {
            dtsName: []const u8,
            inputName: []const u8,
        };

        pub fn next(self: *OutputDeclAndSourceIterator) ?Item {
            if (self.index >= self.p.ParsedConfig.FileNames.len) return null;
            const fileName = self.p.ParsedConfig.FileNames[self.index];
            self.index += 1;

            var outputDts: []const u8 = "";
            if (!tspath.IsDeclarationFileName(fileName) and !tspath.FileExtensionIs(fileName, tspath.ExtensionJson)) {
                outputDts = outputpaths.GetOutputDeclarationFileNameWorker(fileName, self.p.CompilerOptions(), self.p);
            }
            return Item{ .dtsName = outputDts, .inputName = fileName };
        }
    };

    pub fn getOutputDeclarationAndSourceFileNames(self: *Self) OutputDeclAndSourceIterator {
        return .{ .p = self, .index = 0 };
    }

    pub fn ParseInputOutputNames(self: *Self) !void {
        if (self.sourceAndOutputMapsOnce) return;
        self.sourceAndOutputMapsOnce = true;

        var sourceToOutput = std.AutoHashMap(tspath.Path, *SourceOutputAndProjectReference).init(self.allocator);
        var outputDtsToSource = std.AutoHashMap(tspath.Path, *SourceOutputAndProjectReference).init(self.allocator);

        var it = self.getOutputDeclarationAndSourceFileNames();
        while (it.next()) |pair| {
            const outputDts = pair.dtsName;
            const source = pair.inputName;

            const path = tspath.ToPath(source, self.GetCurrentDirectory(), self.UseCaseSensitiveFileNames());
            const projectReference = try self.allocator.create(SourceOutputAndProjectReference);
            projectReference.* = .{
                .Source = source,
                .OutputDts = outputDts,
                .Resolved = self,
            };

            if (outputDts.len > 0) {
                try outputDtsToSource.put(tspath.ToPath(outputDts, self.GetCurrentDirectory(), self.UseCaseSensitiveFileNames()), projectReference);
            }
            try sourceToOutput.put(path, projectReference);
        }

        self.outputDtsToProjectReference = outputDtsToSource;
        self.sourceToProjectReference = sourceToOutput;
    }

    pub fn CommonSourceDirectory(self: *Self) ![]const u8 {
        if (!self.commonSourceDirectoryOnce) {
            self.commonSourceDirectoryOnce = true;

            var files = std.ArrayList([]const u8).init(self.allocator);
            for (self.ParsedConfig.FileNames) |file| {
                // assume NoEmitForJsFiles could be mapped to an optional boolean or similar, default to false
                const noEmit = if (@hasField(@TypeOf(self.ParsedConfig.CompilerOptions.*), "NoEmitForJsFiles")) self.ParsedConfig.CompilerOptions.NoEmitForJsFiles orelse false else false;
                const skip = (noEmit and tspath.HasJSFileExtension(file)) or tspath.IsDeclarationFileName(file);
                if (!skip) {
                    try files.append(file);
                }
            }

            self.commonSourceDirectory = try outputpaths.GetCommonSourceDirectory(
                self.allocator,
                self.ParsedConfig.CompilerOptions,
                files.items,
                self.GetCurrentDirectory(),
                self.UseCaseSensitiveFileNames(),
                self,
            );
        }
        return self.commonSourceDirectory orelse "";
    }

    pub fn checkSourceFilesBelongToPath(self: *Self, sourceFiles: [][]const u8, rootDirectory: []const u8) !bool {
        var allFilesBelongToPath = true;
        for (sourceFiles) |file| {
            const absoluteSourceFilePath = tspath.GetCanonicalFileName(
                tspath.GetNormalizedAbsolutePath(file, self.GetCurrentDirectory()),
                self.UseCaseSensitiveFileNames()
            );
            if (!tspath.ContainsPath(rootDirectory, file, self.comparePathsOptions)) {
                const diag = try ast.NewCompilerDiagnostic(
                    diagnostics.File_0_is_not_under_rootDir_1_rootDir_is_expected_to_contain_all_source_files,
                    absoluteSourceFilePath,
                    rootDirectory
                );
                try self.Errors.append(diag);
                allFilesBelongToPath = false;
            }
        }
        return allFilesBelongToPath;
    }

    pub fn GetCurrentDirectory(self: *Self) []const u8 {
        return self.comparePathsOptions.CurrentDirectory;
    }

    pub fn UseCaseSensitiveFileNames(self: *Self) bool {
        return self.comparePathsOptions.UseCaseSensitiveFileNames;
    }

    pub fn GetOutputFileNames(self: *Self) ![][]const u8 {
        var list = std.ArrayList([]const u8).init(self.allocator);

        for (self.ParsedConfig.FileNames) |fileName| {
            if (tspath.IsDeclarationFileName(fileName)) {
                continue;
            }
            const jsFileName = outputpaths.GetOutputJSFileName(fileName, self.CompilerOptions(), self);
            const isJson = tspath.FileExtensionIs(fileName, tspath.ExtensionJson);

            if (jsFileName.len > 0) {
                try list.append(jsFileName);
                if (!isJson) {
                    const sourceMap = outputpaths.GetSourceMapFilePath(jsFileName, self.CompilerOptions());
                    if (sourceMap.len > 0) {
                        try list.append(sourceMap);
                    }
                }
            }

            if (isJson) {
                continue;
            }

            if (self.CompilerOptions().GetEmitDeclarations()) {
                const dtsFileName = outputpaths.GetOutputDeclarationFileNameWorker(fileName, self.CompilerOptions(), self);
                if (dtsFileName.len > 0) {
                    try list.append(dtsFileName);
                    if (self.CompilerOptions().GetAreDeclarationMapsEnabled()) {
                        const declarationMap = try std.fmt.allocPrint(self.allocator, "{s}.map", .{dtsFileName});
                        try list.append(declarationMap);
                    }
                }
            }
        }

        return try list.toOwnedSlice();
    }

    pub fn GetBuildInfoFileName(self: *Self) []const u8 {
        return outputpaths.GetBuildInfoFileName(self.CompilerOptions(), self.comparePathsOptions);
    }

    pub fn WildcardDirectories(self: *Self) !std.StringHashMap(bool) {
        if (!self.wildcardDirectoriesOnce) {
            self.wildcardDirectoriesOnce = true;
            if (self.ConfigFile) |cf| {
                self.wildcardDirectories = try tsconfig.getWildcardDirectories(
                    self.allocator,
                    cf.configFileSpecs.validatedIncludeSpecs,
                    cf.configFileSpecs.validatedExcludeSpecs,
                    self.comparePathsOptions,
                );
            }
        }
        return self.wildcardDirectories orelse std.StringHashMap(bool).init(self.allocator);
    }

    pub fn WildcardDirectoryGlobs(self: *Self) ![]*glob.Glob {
        var wildcardDirs = try self.WildcardDirectories();
        if (wildcardDirs.count() == 0) return &[_]*glob.Glob{};

        if (!self.includeGlobsOnce) {
            self.includeGlobsOnce = true;
            var globsList = std.ArrayList(*glob.Glob).init(self.allocator);
            var it = wildcardDirs.iterator();
            while (it.next()) |entry| {
                const dir = entry.key_ptr.*;
                const recursive = entry.value_ptr.*;
                const pattern = if (recursive) recursiveFileGlobPattern else fileGlobPattern;
                const pathStr = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ tspath.NormalizePath(dir), pattern });

                if (glob.Parse(self.allocator, pathStr)) |parsed| {
                    try globsList.append(parsed);
                } else |_| {
                    // Ignore error
                }
            }
            self.includeGlobs = try globsList.toOwnedSlice();
        }
        return self.includeGlobs orelse &[_]*glob.Glob{};
    }

    pub fn LiteralFileNames(self: *Self) [][]const u8 {
        if (self.ConfigFile != null) {
            return self.FileNames()[0..self.literalFileNamesLen];
        }
        return &[_][]const u8{};
    }

    pub fn SetParsedOptions(self: *Self, o: *core.ParsedOptions) void {
        self.ParsedConfig = o;
    }

    pub fn SetCompilerOptions(self: *Self, o: *core.CompilerOptions) void {
        self.ParsedConfig.CompilerOptions = o;
    }

    pub fn CompilerOptions(self: *Self) *core.CompilerOptions {
        return self.ParsedConfig.CompilerOptions;
    }

    pub fn SetTypeAcquisition(self: *Self, o: *core.TypeAcquisition) void {
        self.ParsedConfig.TypeAcquisition = o;
    }

    pub fn TypeAcquisition(self: *Self) *core.TypeAcquisition {
        return self.ParsedConfig.TypeAcquisition;
    }

    pub fn FileNames(self: *Self) [][]const u8 {
        return self.ParsedConfig.FileNames;
    }

    pub fn FileNamesByPath(self: *Self) !std.AutoHashMap(tspath.Path, []const u8) {
        if (!self.fileNamesByPathOnce) {
            self.fileNamesByPathOnce = true;
            var map = std.AutoHashMap(tspath.Path, []const u8).init(self.allocator);
            for (self.ParsedConfig.FileNames) |fileName| {
                const path = tspath.ToPath(fileName, self.GetCurrentDirectory(), self.UseCaseSensitiveFileNames());
                try map.put(path, fileName);
            }
            self.fileNamesByPath = map;
        }
        return self.fileNamesByPath orelse std.AutoHashMap(tspath.Path, []const u8).init(self.allocator);
    }

    pub fn ProjectReferences(self: *Self) []*core.ProjectReference {
        return self.ParsedConfig.ProjectReferences;
    }

    pub fn ResolvedProjectReferencePaths(self: *Self) ![][]const u8 {
        if (!self.resolvedProjectReferencePathsOnce) {
            self.resolvedProjectReferencePathsOnce = true;
            var paths = std.ArrayList([]const u8).init(self.allocator);
            for (self.ParsedConfig.ProjectReferences) |ref| {
                const resolved = core.ResolveProjectReferencePath(ref);
                try paths.append(resolved);
            }
            self.resolvedProjectReferencePaths = try paths.toOwnedSlice();
        }
        return self.resolvedProjectReferencePaths orelse &[_][]const u8{};
    }

    pub fn ExtendedSourceFiles(self: *Self) [][]const u8 {
        if (self.ConfigFile) |cf| {
            return cf.ExtendedSourceFiles;
        }
        return &[_][]const u8{};
    }

    pub fn GetConfigFileParsingDiagnostics(self: *Self) ![]*ast.Diagnostic {
        if (self.ConfigFile) |cf| {
            var all = std.ArrayList(*ast.Diagnostic).init(self.allocator);
            try all.appendSlice(cf.SourceFile.Diagnostics());
            try all.appendSlice(self.Errors.items);
            return try all.toOwnedSlice();
        }
        return self.Errors.items;
    }

    pub fn PossiblyMatchesFileName(self: *Self, fileName: []const u8) !bool {
        const path = tspath.ToPath(fileName, self.GetCurrentDirectory(), self.UseCaseSensitiveFileNames());
        var byPath = try self.FileNamesByPath();
        if (byPath.contains(path)) {
            return true;
        }

        if (self.ConfigFile) |cf| {
            for (cf.configFileSpecs.validatedIncludeSpecs) |include| {
                if (std.mem.indexOfAny(u8, include, "*?") == null and !vfsmatch.IsImplicitGlob(include)) {
                    const includePath = tspath.ToPath(include, self.GetCurrentDirectory(), self.UseCaseSensitiveFileNames());
                    if (std.meta.eql(includePath, path)) {
                        return true;
                    }
                }
            }
        }

        const globsList = try self.WildcardDirectoryGlobs();
        if (globsList.len > 0) {
            for (globsList) |g| {
                if (g.Match(fileName)) {
                    return true;
                }
            }
        }
        return false;
    }

    pub fn PossiblyMatchesDirectoryName(self: *Self, directoryPath: tspath.Path) !bool {
        var dirs = try self.WildcardDirectories();
        var it = dirs.iterator();
        while (it.next()) |entry| {
            const wildcardDir = entry.key_ptr.*;
            const recursive = entry.value_ptr.*;
            const wildcardDirPath = tspath.ToPath(wildcardDir, self.GetCurrentDirectory(), self.UseCaseSensitiveFileNames());

            if (recursive) {
                if (wildcardDirPath.ContainsPath(directoryPath)) {
                    return true;
                }
            } else {
                if (std.meta.eql(wildcardDirPath, directoryPath)) {
                    return true;
                }
            }
        }
        return false;
    }

    pub fn GetMatchedFileSpec(self: *Self, fileName: []const u8) []const u8 {
        if (self.ConfigFile) |cf| {
            return cf.configFileSpecs.getMatchedFileSpec(fileName, self.comparePathsOptions);
        }
        return "";
    }

    pub fn GetMatchedIncludeSpec(self: *Self, fileName: []const u8) struct { []const u8, bool } {
        if (self.ConfigFile) |cf| {
            if (cf.configFileSpecs.validatedIncludeSpecs.len == 0) {
                return .{ "", false };
            }
            if (cf.configFileSpecs.isDefaultIncludeSpec) {
                return .{ cf.configFileSpecs.validatedIncludeSpecs[0], true };
            }
            return .{ cf.configFileSpecs.getMatchedIncludeSpec(fileName, self.comparePathsOptions), false };
        }
        return .{ "", false };
    }

    pub fn ReloadFileNamesOfParsedCommandLine(self: *Self, fs: vfs.FS) !*Self {
        var newParsedConfig = try self.allocator.create(core.ParsedOptions);
        newParsedConfig.* = self.ParsedConfig.*;

        var literalFileNamesLen: usize = 0;
        var fileNames: [][]const u8 = &[_][]const u8{};
        if (self.ConfigFile) |cf| {
            const result = tsconfig.getFileNamesFromConfigSpecs(
                self.allocator,
                cf.configFileSpecs,
                self.GetCurrentDirectory(),
                self.CompilerOptions(),
                fs,
                self.extraFileExtensions,
            );
            fileNames = result.fileNames;
            literalFileNamesLen = result.literalFileNamesLen;
        }

        newParsedConfig.FileNames = fileNames;

        const p = try self.allocator.create(Self);
        p.* = .{
            .allocator = self.allocator,
            .ParsedConfig = newParsedConfig,
            .ConfigFile = self.ConfigFile,
            .Errors = self.Errors,
            .Raw = self.Raw,
            .CompileOnSave = self.CompileOnSave,
            .comparePathsOptions = self.comparePathsOptions,
            .wildcardDirectories = self.wildcardDirectories,
            .wildcardDirectoriesOnce = self.wildcardDirectoriesOnce,
            .includeGlobs = self.includeGlobs,
            .includeGlobsOnce = self.includeGlobsOnce,
            .extraFileExtensions = self.extraFileExtensions,
            .literalFileNamesLen = literalFileNamesLen,
        };
        return p;
    }

    pub fn Locale(self: *Self) !locale.Locale {
        if (!self.localeOnce) {
            self.localeOnce = true;
            if (@hasField(@TypeOf(self.CompilerOptions().*), "Locale")) {
                if (self.CompilerOptions().Locale) |locStr| {
                    if (locStr.len > 0) {
                        if (locale.Parse(locStr)) |loc| {
                            self.locale = loc;
                        } else |_| {}
                    }
                }
            }
        }
        return self.locale orelse locale.Locale{};
    }
};
