const std = @import("std");
const core = @import("../../core/core.zig");

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
    _ = regexPattern;
    var files = std.ArrayList([]const u8).empty;

    try collectFiles(allocator, basePath, recursive, &files);

    return files.toOwnedSlice(allocator);
}

fn collectFiles(
    allocator: std.mem.Allocator,
    basePath: []const u8,
    recursive: bool,
    files: *std.ArrayList([]const u8),
) !void {
    const osvfs = @import("../../vfs/osvfs/osvfs.zig");
    const entries = osvfs.fs().getAccessibleEntries(allocator, basePath);

    for (entries.files) |f| {
        if (std.mem.endsWith(u8, f, ".ts") or std.mem.endsWith(u8, f, ".tsx")) {
            const joined = try std.fs.path.join(allocator, &[_][]const u8{ basePath, f });
            try files.append(allocator, joined);
        }
        allocator.free(f);
    }
    allocator.free(entries.files);

    if (recursive) {
        for (entries.directories) |d| {
            const joined = try std.fs.path.join(allocator, &[_][]const u8{ basePath, d });
            try collectFiles(allocator, joined, recursive, files);
            allocator.free(joined);
        }
    }

    for (entries.directories) |d| {
        allocator.free(d);
    }
    allocator.free(entries.directories);
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
    _ = inputFiles;
    _ = otherFiles;
    _ = testConfig;
    _ = tsconfig;
    _ = currentDirectory;

    // We don't have a full VFS/CompilerHost implementation for the test suite yet.
    // For now, we will just return a dummy CompilationResult to allow the test harness to run.
    const hOptions = try allocator.create(HarnessOptions);
    hOptions.* = .{};

    const compilerOpts = try allocator.create(core.CompilerOptions);
    compilerOpts.* = .{};

    const dummyProgram = try allocator.create(u8);
    dummyProgram.* = 0;

    const result = try allocator.create(CompilationResult);
    result.* = .{
        .Diagnostics = &[_]*anyopaque{},
        .Result = undefined,
        .Program = dummyProgram,
        .Options = compilerOpts,
        .HarnessOptions = hOptions,
        .Symlinks = symlinks,
        .Repeat = undefined,
        .Outputs = &[_]*anyopaque{},
        .Inputs = &[_]*anyopaque{},
        .Trace = "",
        .Host = undefined,
    };
    return result;
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
    Repeat: *const fn (TestConfiguration) *CompilationResult,
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
