const std = @import("std");
const core = @import("../core/core.zig");
const ast = @import("../ast/ast.zig");
const tspath = @import("../tspath/tspath.zig");
const parser = @import("../parser/parser.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const commandlineparser = @import("commandlineparser.zig");

// Note: many other imports like collections, vfs, etc. can be added as needed

pub const ExtendsResult = struct {
    options: *core.CompilerOptions,
    watchOptionsCopied: bool,
    include: ?[]const []const u8,
    exclude: ?[]const []const u8,
    files: ?[]const []const u8,
    compileOnSave: bool,
    extendedSourceFiles: std.StringHashMap(void), // Using hash map as Set
};

pub const ConfigFileSpecs = struct {
    filesSpecs: ?*std.json.Value,
    includeSpecs: ?*std.json.Value,
    excludeSpecs: ?*std.json.Value,
    validatedFilesSpec: ?[]const []const u8,
    validatedIncludeSpecs: ?[]const []const u8,
    validatedExcludeSpecs: ?[]const []const u8,
    validatedFilesSpecBeforeSubstitution: ?[]const []const u8,
    validatedIncludeSpecsBeforeSubstitution: ?[]const []const u8,
    isDefaultIncludeSpec: bool,
};

pub const FileExtensionInfo = struct {
    Extension: []const u8,
    IsMixedContent: bool,
    ScriptKind: core.ScriptKind,
};

pub const TsConfigSourceFile = struct {
    ExtendedSourceFiles: []const []const u8,
    configFileSpecs: ?*ConfigFileSpecs,
    sourceFile: ast.NodeIndex,
};

pub const ParsedTsconfig = struct {
    raw: ?*std.json.Value,
    options: *core.CompilerOptions,
    typeAcquisition: *core.TypeAcquisition,
    extendedConfigPath: ?[]const []const u8, // simplified for now
};

pub const ParseConfigHost = struct {
    fs: *anyopaque,
    getCurrentDirectory: *const fn(host: *anyopaque) []const u8,
};

pub const ExtendedConfigCacheEntry = struct {
    extendedResult: ?*TsConfigSourceFile,
    extendedConfig: ?*ParsedTsconfig,
    errors: []*diagnostics.Diagnostic,
};

pub const ExtendedConfigCache = struct {
    getExtendedConfig: *const fn(self: *ExtendedConfigCache, fileName: []const u8, path: []const u8, resolutionStack: [][]const u8, host: *ParseConfigHost) *ExtendedConfigCacheEntry,
};

pub fn parseJsonConfigFileContent(
    allocator: std.mem.Allocator,
    json: ?*std.json.Value,
    host: anytype,
    basePath: []const u8,
    existingOptions: ?*core.CompilerOptions,
    configFileName: []const u8,
    resolutionStack: [][]const u8,
    extraFileExtensions: []FileExtensionInfo,
    extendedConfigCache: ?*ExtendedConfigCache,
) *commandlineparser.ParsedCommandLine {
    return parseJsonConfigFileContentWorker(
        allocator,
        json,
        null, // sourceFile
        host,
        basePath,
        existingOptions,
        null, // existingOptionsRaw
        configFileName,
        resolutionStack,
        extraFileExtensions,
        extendedConfigCache,
    );
}

pub fn parseJsonSourceFileConfigFileContent(
    allocator: std.mem.Allocator,
    sourceFile: *TsConfigSourceFile,
    host: anytype,
    basePath: []const u8,
    existingOptions: ?*core.CompilerOptions,
    existingOptionsRaw: ?*std.json.Value,
    configFileName: []const u8,
    resolutionStack: [][]const u8,
    extraFileExtensions: []FileExtensionInfo,
    extendedConfigCache: ?*ExtendedConfigCache,
) *commandlineparser.ParsedCommandLine {
    return parseJsonConfigFileContentWorker(
        allocator,
        null, // json
        sourceFile,
        host,
        basePath,
        existingOptions,
        existingOptionsRaw,
        configFileName,
        resolutionStack,
        extraFileExtensions,
        extendedConfigCache,
    );
}

pub fn parseJsonConfigFileContentWorker(
    allocator: std.mem.Allocator,
    json: ?*std.json.Value,
    sourceFile: ?*TsConfigSourceFile,
    host: anytype,
    basePath: []const u8,
    existingOptions: ?*core.CompilerOptions,
    existingOptionsRaw: ?*std.json.Value,
    configFileName: []const u8,
    resolutionStack: [][]const u8,
    extraFileExtensions: []FileExtensionInfo,
    extendedConfigCache: ?*ExtendedConfigCache,
) *commandlineparser.ParsedCommandLine {
    std.debug.assert((json == null and sourceFile != null) or (json != null and sourceFile == null));

    var basePathForFileNames: []const u8 = "";
    if (configFileName.len > 0) {
        basePathForFileNames = directoryOfCombinedPath(configFileName, basePath);
    } else {
        basePathForFileNames = basePath;
    }

    var errors = std.ArrayList(*diagnostics.Diagnostic).empty;

    const parsedConfigResult = parseConfig(allocator, json, sourceFile, host, basePath, configFileName, resolutionStack, extendedConfigCache);
    for (parsedConfigResult.errors) |err| {
        errors.append(allocator, err) catch unreachable;
    }
    
    const parsedConfig = parsedConfigResult.config;
    _ = parsedConfig;
    // mergeCompilerOptions(parsedConfig.options, existingOptions, existingOptionsRaw);
    // handleOptionConfigDirTemplateSubstitution(parsedConfig.options, basePathForFileNames);
    _ = existingOptions;
    _ = existingOptionsRaw;
    
    if (configFileName.len > 0) { // simplified check
        // parsedConfig.options.ConfigFilePath = tspath.NormalizeSlashes(configFileName);
    }
    
    _ = extraFileExtensions; // TODO: properly map these
    // _ = host;
    const result = allocator.create(commandlineparser.ParsedCommandLine) catch unreachable;
    result.* = .{
        .ParsedConfig = .{ .WatchOptions = undefined },
        .Errors = errors,
        .Raw = undefined,
    };
    return result;
}

pub fn directoryOfCombinedPath(fileName: []const u8, basePath: []const u8) []const u8 {
    _ = fileName;
    // _ = basePath;
    return basePath; // stub
}

pub fn parseConfig(
    allocator: std.mem.Allocator,
    json: ?*std.json.Value,
    sourceFile: ?*TsConfigSourceFile,
    host: anytype,
    basePath: []const u8,
    configFileName: []const u8,
    resolutionStack: [][]const u8,
    extendedConfigCache: ?*ExtendedConfigCache,
) struct { config: *ParsedTsconfig, errors: []*diagnostics.Diagnostic } {
    // _ = host;
    _ = resolutionStack;
    _ = extendedConfigCache;
    
    var errors = std.ArrayList(*diagnostics.Diagnostic).empty;
    
    // Check circularity in resolution stack (simplified)
    
    var ownConfig: *ParsedTsconfig = undefined;
    if (json != null) {
        const result = parseOwnConfigOfJson(allocator, json, host, basePath, configFileName);
        ownConfig = result.config;
        for (result.errors) |err| { errors.append(allocator, err) catch unreachable; }
    } else if (sourceFile != null) {
        const result = parseOwnConfigOfJsonSourceFile(allocator, sourceFile.?.sourceFile, host, basePath, configFileName);
        ownConfig = result.config;
        for (result.errors) |err| { errors.append(allocator, err) catch unreachable; }
    }
    
    // Process extends...
    
    return .{
        .config = ownConfig,
        .errors = errors.toOwnedSlice(allocator) catch unreachable,
    };
}

pub fn getExtendsConfigPath(
    allocator: std.mem.Allocator,
    extendedConfigParam: []const u8,
    host: anytype,
    basePath: []const u8,
    valueExpression: ?*ast.Expression,
    sourceFile: ?*ast.SourceFile,
) struct { path: []const u8, errors: []*diagnostics.Diagnostic } {
    _ = allocator;
    _ = basePath;
    _ = valueExpression;
    _ = host;
    
    // extendedConfig = tspath.NormalizeSlashes(extendedConfig)
    const extendedConfig = extendedConfigParam; // stub
    
    var errors = std.ArrayList(*diagnostics.Diagnostic).empty;
    var errorFile: ?*ast.SourceFile = null;
    if (sourceFile != null) {
        errorFile = sourceFile;
    }
        // _ = errorFile;
    
    // if tspath.IsRootedDiskPath(extendedConfig) || strings.HasPrefix(extendedConfig, "./") || strings.HasPrefix(extendedConfig, "../")
    if (std.mem.startsWith(u8, extendedConfig, "/") or std.mem.startsWith(u8, extendedConfig, "./") or std.mem.startsWith(u8, extendedConfig, "../")) {
        // const extendedConfigPath = tspath.GetNormalizedAbsolutePath(extendedConfig, basePath);
        const extendedConfigPath = extendedConfig; // stub
        
        // if !host.FS().FileExists(extendedConfigPath) && !strings.HasSuffix(extendedConfigPath, tspath.ExtensionJson) {
        //     extendedConfigPath = extendedConfigPath + tspath.ExtensionJson
        //     if !host.FS().FileExists(extendedConfigPath) {
        //         errors.append(CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(errorFile, valueExpression, diagnostics.File_0_not_found, extendedConfig)) catch unreachable;
        //         return .{ .path = "", .errors = errors.toOwnedSlice() catch unreachable };
        //     }
        // }
        return .{ .path = extendedConfigPath, .errors = errors.toOwnedSlice() catch unreachable };
    }
    
    // resolverHost := &resolverHost{host}
    // if resolved := module.ResolveConfig(extendedConfig, tspath.CombinePaths(basePath, "tsconfig.json"), resolverHost); resolved.IsResolved() {
    //     return resolved.ResolvedFileName, errors
    // }
    
    if (extendedConfig.len == 0) {
        // errors.append(CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(errorFile, valueExpression, diagnostics.Compiler_option_0_cannot_be_given_an_empty_string, "extends")) catch unreachable;
    } else {
        // errors.append(CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(errorFile, valueExpression, diagnostics.File_0_not_found, extendedConfig)) catch unreachable;
    }
    
    return .{
        .path = "",
        .errors = errors.toOwnedSlice() catch unreachable,
    };
}

pub fn parseOwnConfigOfJson(
    allocator: std.mem.Allocator,
    json: ?*std.json.Value,
    host: anytype,
    basePath: []const u8,
    configFileName: []const u8,
) struct { config: *ParsedTsconfig, errors: []*diagnostics.Diagnostic } {
    _ = host;
    _ = basePath;
    _ = configFileName;
    
    var errors = std.ArrayList(*diagnostics.Diagnostic).empty;
    if (json != null and json.?.* == .object) {
        if (json.?.object.contains("excludes")) {
            // errors.append(ast.NewCompilerDiagnostic(diagnostics.Unknown_option_excludes_Did_you_mean_exclude)) catch unreachable;
        }
    }
    
    // options, err := convertCompilerOptionsFromJsonWorker(json.GetOrZero("compilerOptions"), basePath, configFileName)
    // typeAcquisition, err2 := convertTypeAcquisitionFromJsonWorker(json.GetOrZero("typeAcquisition"), basePath, configFileName)
    // var extendedConfigPath []string
    // if extends := json.GetOrZero("extends"); extends != nil && extends != "" {
    //     extendedConfigPath, err = getExtendsConfigPathOrArray(extends, host, basePath, configFileName, nil, nil, nil)
    // }
    
    const config = allocator.create(ParsedTsconfig) catch unreachable;
    config.* = .{
        .raw = json,
        .options = undefined,
        .typeAcquisition = undefined,
        .extendedConfigPath = null,
    };
    return .{
        .config = config,
        .errors = errors.toOwnedSlice(allocator) catch unreachable,
    };
}

pub fn parseOwnConfigOfJsonSourceFile(
    allocator: std.mem.Allocator,
    sourceFile: ast.NodeIndex,
    host: anytype,
    basePath: []const u8,
    configFileName: []const u8,
) struct { config: *ParsedTsconfig, errors: []*diagnostics.Diagnostic } {
    _ = sourceFile;
    _ = host;
    _ = basePath;
    _ = configFileName;
    const config = allocator.create(ParsedTsconfig) catch unreachable;
    config.* = .{
        .raw = null,
        .options = undefined,
        .typeAcquisition = undefined,
        .extendedConfigPath = null,
    };
    return .{
        .config = config,
        .errors = &[_]*diagnostics.Diagnostic{},
    };
}

pub fn parseExtendedConfig(
    allocator: std.mem.Allocator,
    fileName: []const u8,
    path: []const u8,
    resolutionStack: [][]const u8,
    host: anytype,
    extendedConfigCache: ?*ExtendedConfigCache,
) *ExtendedConfigCacheEntry {
    _ = fileName;
    _ = path;
    _ = resolutionStack;
    _ = host;
    _ = extendedConfigCache;
    const entry = allocator.create(ExtendedConfigCacheEntry) catch unreachable;
    entry.* = .{
        .extendedResult = null,
        .extendedConfig = null,
        .errors = &[_]*diagnostics.Diagnostic{},
    };
    return entry;
}
