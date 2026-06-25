const std = @import("std");

pub const TestConfiguration = std.StringHashMap([]const u8);

pub const NamedTestConfiguration = struct {
    Name: []const u8,
    Config: TestConfiguration,
};

pub const TestFile = struct {
    UnitName: []const u8 = "",
    Content: []const u8 = "",
};

pub fn GetFileBasedTestConfigurations(
    allocator: std.mem.Allocator,
    settings: anytype,
    varyByMap: anytype,
) ![]*NamedTestConfiguration {
    _ = settings;
    _ = varyByMap;
    var result = std.ArrayList(*NamedTestConfiguration).empty;
    return result.toOwnedSlice(allocator);
}

pub fn SkipUnsupportedCompilerOptions(options: ?*anyopaque) !void {
    _ = options;
}

pub const CompileFiles = compileFiles;

pub const HarnessOptions = struct {
    UseCaseSensitiveFileNames: bool = false,
    BaselineFile: []const u8 = "",
    IncludeBuiltFile: []const u8 = "",
    FileName: []const u8 = "",
    LibFiles: [][]const u8 = &.{},
    NoImplicitReferences: bool = false,
    CurrentDirectory: []const u8 = "",
    Symlink: []const u8 = "",
    Link: []const u8 = "",
    NoTypesAndSymbols: bool = false,
    FullEmitPaths: bool = false,
    ReportDiagnostics: bool = false,
    CaptureSuggestions: bool = false,
    TypescriptVersion: []const u8 = "",
};

pub fn EnumerateFiles(
    allocator: std.mem.Allocator,
    basePath: []const u8,
    regexPattern: []const u8,
    recursive: bool,
) ![][]const u8 {
    _ = basePath;
    _ = regexPattern;
    _ = recursive;
    var files = std.ArrayList([]const u8).empty;
    return files.toOwnedSlice(allocator);
}

pub fn compileFiles(
    allocator: std.mem.Allocator,
    inputFiles: []const *TestFile,
    otherFiles: []const *TestFile,
    testConfig: ?TestConfiguration,
    tsconfig: ?*anyopaque,
    currentDirectory: []const u8,
    symlinks: std.StringHashMap([]const u8),
) !*CompilationResult {
    _ = allocator;
    _ = inputFiles;
    _ = otherFiles;
    _ = testConfig;
    _ = tsconfig;
    _ = currentDirectory;
    _ = symlinks;
    unreachable;
}

pub fn compileFilesEx(
    allocator: std.mem.Allocator,
    inputFiles: []const *anyopaque,
    otherFiles: []const *anyopaque,
    harnessOptions: *HarnessOptions,
    compilerOptions: *anyopaque,
    currentDirectory: []const u8,
    symlinks: std.StringHashMap([]const u8),
    tsconfig: ?*anyopaque,
) !*CompilationResult {
    _ = allocator;
    _ = inputFiles;
    _ = otherFiles;
    _ = harnessOptions;
    _ = compilerOptions;
    _ = currentDirectory;
    _ = symlinks;
    _ = tsconfig;
    unreachable;
}

pub const CompilationResult = struct {
    Diagnostics: []*anyopaque,
    Result: *anyopaque,
    Program: *anyopaque,
    Options: *anyopaque,
    HarnessOptions: *HarnessOptions,
    // Js: collections.OrderedMap([]const u8, *TestFile),
    // Dts: collections.OrderedMap([]const u8, *TestFile),
    // Maps: collections.OrderedMap([]const u8, *TestFile),
    Symlinks: std.StringHashMap([]const u8),
    Repeat: *const fn(TestConfiguration) *CompilationResult,
    Outputs: []*anyopaque,
    Inputs: []*anyopaque,
    // InputsAndOutputs: collections.OrderedMap([]const u8, *CompilationOutput),
    Trace: []const u8,
    Host: *anyopaque,
};

pub const CompilationOutput = struct {
    Inputs: []*anyopaque,
    Js: ?*anyopaque,
    Dts: ?*anyopaque,
    Map: ?*anyopaque,
};
