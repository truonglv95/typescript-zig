const std = @import("std");
const ast = @import("../ast/ast.zig");
const core = @import("../core/core.zig");
const parser = @import("../parser/parser.zig");
const scanner = @import("../scanner/scanner.zig");
const commandlineparser = @import("../tsoptions/commandlineparser.zig");
const tsconfigparsing = @import("../tsoptions/tsconfigparsing.zig");
const tspath = @import("../tspath/tspath.zig");

// Dummy imports for missing packages
const harnessutil = struct {
    pub fn getConfigNameFromFileName(fileName: []const u8) []const u8 {
        _ = fileName;
        return "";
    }
};

const tsoptionstest = struct {
    pub const VFSParseConfigHost = struct {
        vfs: struct {
            pub fn useCaseSensitiveFileNames(self: *@This()) bool {
                _ = self;
                return true;
            }
        },
        pub fn getCurrentDirectory(self: *@This()) []const u8 {
            _ = self;
            return "";
        }
    };
    pub fn NewVFSParseConfigHost(allocator: std.mem.Allocator, files: std.StringHashMap([]const u8), currentDir: []const u8, useCaseSensitive: bool) !*VFSParseConfigHost {
        _ = allocator;
        _ = files;
        _ = currentDir;
        _ = useCaseSensitive;
        return undefined;
    }
};

pub const RawCompilerSettings = std.StringHashMap([]const u8);

pub const TestUnit = struct {
    content: []const u8,
    name: []const u8,
};

pub const TestCaseContent = struct {
    testUnitData: []TestUnit,
    tsConfig: ?*commandlineparser.ParsedCommandLine,
    tsConfigFileUnitData: ?TestUnit,
    symlinks: std.StringHashMap([]const u8),
};

const fourslashDirectives = [_][]const u8{"emitthisfile"};

fn parseOption(allocator: std.mem.Allocator, line: []const u8) ?struct { name: []const u8, value: []const u8 } {
    _ = allocator;
    if (!std.mem.startsWith(u8, line, "//")) return null;
    const after_slashes = line[2..];
    var i: usize = 0;
    while (i < after_slashes.len and std.ascii.isWhitespace(after_slashes[i])) : (i += 1) {}
    if (i >= after_slashes.len) return null;
    if (after_slashes[i] != '@') return null;
    i += 1;
    const name_start = i;
    while (i < after_slashes.len and (std.ascii.isAlphanumeric(after_slashes[i]) or after_slashes[i] == '_')) : (i += 1) {}
    const name_end = i;
    if (name_end == name_start) return null;

    while (i < after_slashes.len and std.ascii.isWhitespace(after_slashes[i])) : (i += 1) {}
    if (i >= after_slashes.len or after_slashes[i] != ':') return null;
    i += 1;

    const value_start = i;
    const value = std.mem.trim(u8, after_slashes[value_start..], " \t\r\n");
    return .{ .name = after_slashes[name_start..name_end], .value = value };
}

fn parseSymlinkFromTest(allocator: std.mem.Allocator, line: []const u8, symlinks: *std.StringHashMap([]const u8)) !bool {
    const opt = parseOption(allocator, line) orelse return false;
    const name_lower = try allocator.alloc(u8, opt.name.len);
    defer allocator.free(name_lower);
    _ = std.ascii.lowerString(name_lower, opt.name);

    if (!std.mem.eql(u8, name_lower, "link")) return false;

    const arrow = std.mem.indexOf(u8, opt.value, "->") orelse return false;
    const link = std.mem.trim(u8, opt.value[0..arrow], " \t");
    const target = std.mem.trim(u8, opt.value[arrow + 2 ..], " \t");
    try symlinks.put(try allocator.dupe(u8, target), try allocator.dupe(u8, link));
    return true;
}

fn getNormalizedAbsolutePath(allocator: std.mem.Allocator, name: []const u8, currentDir: []const u8) ![]const u8 {
    if (std.fs.path.isAbsolute(name)) {
        return try allocator.dupe(u8, name);
    }
    return try std.fs.path.join(allocator, &[_][]const u8{ currentDir, name });
}

pub fn makeUnitsFromTest(allocator: std.mem.Allocator, code: []const u8, fileName: []const u8) !TestCaseContent {
    const TestFileParser = struct {
        fn parse(alloc: std.mem.Allocator, name: []const u8, content: []const u8, fileOptions: std.StringHashMap([]const u8)) anyerror!TestUnit {
            _ = fileOptions;
            return TestUnit{
                .content = try alloc.dupe(u8, content),
                .name = try alloc.dupe(u8, name),
            };
        }
    };

    var result = try parseTestFilesAndSymlinks(TestUnit, allocator, code, fileName, TestFileParser.parse);

    var currentDirectory = result.currentDir;
    if (currentDirectory.len == 0) {
        currentDirectory = "tests/cases/compiler/";
    }

    var allFiles = std.StringHashMap([]const u8).init(allocator);
    for (result.units.items) |data| {
        const absPath = try getNormalizedAbsolutePath(allocator, data.name, currentDirectory);
        try allFiles.put(absPath, data.content);
    }

    const parseConfigHost = try tsoptionstest.NewVFSParseConfigHost(allocator, allFiles, currentDirectory, true);

    var tsConfig: ?*commandlineparser.ParsedCommandLine = null;
    var tsConfigFileUnitData: ?TestUnit = null;

    var i: usize = 0;
    while (i < result.units.items.len) {
        const data = result.units.items[i];
        if (harnessutil.getConfigNameFromFileName(data.name).len > 0) {
            const configFileName = try getNormalizedAbsolutePath(allocator, data.name, currentDirectory);
            const path = configFileName; // Dummy since tspath.toPath is missing

            const parseOptions = ast.SourceFileParseOptions{
                .FileName = configFileName,
                .Path = path,
            };
            const configJson = try parser.parseSourceFile(allocator, parseOptions, data.content, core.ScriptKind.JSON);
            var tsConfigSourceFile = try allocator.create(tsconfigparsing.TsConfigSourceFile);
            tsConfigSourceFile.sourceFile = configJson;

            const configDir = try tspath.getDirectoryPath(allocator, configFileName);
            tsConfig = tsconfigparsing.parseJsonSourceFileConfigFileContent(
                allocator,
                tsConfigSourceFile,
                parseConfigHost,
                configDir,
                null,
                null,
                configFileName,
                &[_][]const u8{},
                &[_]tsconfigparsing.FileExtensionInfo{},
                null,
            );
            tsConfigFileUnitData = data;

            _ = result.units.orderedRemove(i);
            break;
        }
        i += 1;
    }

    return TestCaseContent{
        .testUnitData = try result.units.toOwnedSlice(allocator),
        .tsConfig = tsConfig,
        .tsConfigFileUnitData = tsConfigFileUnitData,
        .symlinks = result.symlinks,
    };
}

pub const ParseTestFilesOptions = struct {
    allowImplicitFirstFile: bool = false,
};

pub fn ParseTestFilesResultType(comptime T: type) type {
    return struct {
        units: std.ArrayList(T),
        symlinks: std.StringHashMap([]const u8),
        currentDir: []const u8,
        globalOptions: std.StringHashMap([]const u8),
    };
}

pub fn parseTestFilesAndSymlinks(comptime T: type, allocator: std.mem.Allocator, code: []const u8, fileName: []const u8, parseFile: *const fn (std.mem.Allocator, []const u8, []const u8, std.StringHashMap([]const u8)) anyerror!T) !ParseTestFilesResultType(T) {
    return parseTestFilesAndSymlinksWithOptions(T, allocator, code, fileName, parseFile, ParseTestFilesOptions{});
}

pub fn parseTestFilesAndSymlinksWithOptions(comptime T: type, allocator: std.mem.Allocator, code_in: []const u8, fileName: []const u8, parseFile: *const fn (std.mem.Allocator, []const u8, []const u8, std.StringHashMap([]const u8)) anyerror!T, options: ParseTestFilesOptions) !ParseTestFilesResultType(T) {
    var code = code_in;
    if (code.len >= 3 and code[0] == 0xef and code[1] == 0xbb and code[2] == 0xbf) {
        code = code[3..];
    }
    var testUnits = std.ArrayList(T).empty;

    var currentFileContent = std.ArrayList(u8).empty;
    defer currentFileContent.deinit(allocator);

    var currentFileName: []const u8 = "";
    var seenContentLine = false;
    var hasSeenFile = false;
    if (options.allowImplicitFirstFile) {
        currentFileName = fileName;
    }

    var currentDirectory: []const u8 = "";
    var currentFileOptions = std.StringHashMap([]const u8).init(allocator);
    var symlinks = std.StringHashMap([]const u8).init(allocator);
    var globalOptions = std.StringHashMap([]const u8).init(allocator);

    var line_start: usize = 0;
    while (line_start < code.len) {
        var line_end = line_start;
        while (line_end < code.len and code[line_end] != '\n') {
            line_end += 1;
        }
        var line = code[line_start..line_end];
        if (line.len > 0 and line[line.len - 1] == '\r') {
            line = line[0 .. line.len - 1];
        }
        line_start = line_end + 1; // skip \n

        const is_symlink = try parseSymlinkFromTest(allocator, line, &symlinks);
        if (is_symlink) continue;

        if (parseOption(allocator, line)) |opt| {
            const metaDataName = try allocator.alloc(u8, opt.name.len);
            defer allocator.free(metaDataName);
            _ = std.ascii.lowerString(metaDataName, opt.name);
            const metaDataValue = opt.value;

            if (std.mem.eql(u8, metaDataName, "currentdirectory")) {
                currentDirectory = try allocator.dupe(u8, metaDataValue);
            }

            if (!std.mem.eql(u8, metaDataName, "filename")) {
                if (std.mem.eql(u8, metaDataName, "symlink") and currentFileName.len > 0) {
                    var link_iter = std.mem.splitSequence(u8, metaDataValue, ",");
                    while (link_iter.next()) |link| {
                        const trimmed = std.mem.trim(u8, link, " \t");
                        if (trimmed.len > 0) {
                            try symlinks.put(try allocator.dupe(u8, trimmed), try allocator.dupe(u8, currentFileName));
                        }
                    }
                } else {
                    var is_fourslash = false;
                    for (fourslashDirectives) |dir| {
                        if (std.mem.eql(u8, metaDataName, dir)) {
                            is_fourslash = true;
                            break;
                        }
                    }
                    if (is_fourslash) {
                        try currentFileOptions.put(try allocator.dupe(u8, metaDataName), try allocator.dupe(u8, metaDataValue));
                    } else {
                        try globalOptions.put(try allocator.dupe(u8, metaDataName), try allocator.dupe(u8, metaDataValue));
                    }
                }
                continue;
            }

            if (currentFileName.len > 0) {
                const shouldSaveFile = !options.allowImplicitFirstFile or currentFileContent.items.len != 0 or hasSeenFile;
                if (shouldSaveFile) {
                    hasSeenFile = true;
                    const newTestFile = try parseFile(allocator, currentFileName, currentFileContent.items, currentFileOptions);
                    try testUnits.append(allocator, newTestFile);
                }

                currentFileContent.clearRetainingCapacity();
                seenContentLine = false;
                currentFileName = try allocator.dupe(u8, metaDataValue);
                currentFileOptions = std.StringHashMap([]const u8).init(allocator);
            } else {
                const hasContentBeforeFirstFilename = currentFileContent.items.len != 0 and scanner.skipTrivia(currentFileContent.items, 0) != currentFileContent.items.len;
                if (hasContentBeforeFirstFilename and !options.allowImplicitFirstFile) {
                    std.debug.print("ParseError! filename: {s}, content: '{s}'\n", .{ currentFileName, currentFileContent.items });
                    return error.ParseError;
                }

                if (hasContentBeforeFirstFilename and options.allowImplicitFirstFile and currentFileName.len > 0) {
                    hasSeenFile = true;
                    const newTestFile = try parseFile(allocator, currentFileName, currentFileContent.items, currentFileOptions);
                    try testUnits.append(allocator, newTestFile);
                }

                currentFileContent.clearRetainingCapacity();
                seenContentLine = false;
                currentFileName = try allocator.dupe(u8, metaDataValue);
                currentFileOptions = std.StringHashMap([]const u8).init(allocator);
            }
        } else {
            if (currentFileName.len == 0) {
                const trimmed = std.mem.trim(u8, line, " \t");
                if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "//")) continue;
            }
            if (options.allowImplicitFirstFile) {
                if (seenContentLine) {
                    try currentFileContent.append(allocator, '\n');
                }
                seenContentLine = true;
            } else {
                if (currentFileContent.items.len != 0) {
                    try currentFileContent.append(allocator, '\n');
                }
            }
            try currentFileContent.appendSlice(allocator, line);
        }
    }

    if (testUnits.items.len == 0 and currentFileName.len == 0) {
        currentFileName = std.fs.path.basename(fileName);
    }

    const newTestFile2 = try parseFile(allocator, currentFileName, currentFileContent.items, currentFileOptions);
    try testUnits.append(allocator, newTestFile2);

    return ParseTestFilesResultType(T){
        .units = testUnits,
        .symlinks = symlinks,
        .currentDir = currentDirectory,
        .globalOptions = globalOptions,
    };
}

pub fn extractCompilerSettings(allocator: std.mem.Allocator, content_in: []const u8) !RawCompilerSettings {
    var content = content_in;
    if (content.len >= 3 and content[0] == 0xef and content[1] == 0xbb and content[2] == 0xbf) {
        content = content[3..];
    }
    var opts = RawCompilerSettings.init(allocator);
    var line_start: usize = 0;
    while (line_start < content.len) {
        var line_end = line_start;
        while (line_end < content.len and content[line_end] != '\n') {
            line_end += 1;
        }
        var line = content[line_start..line_end];
        if (line.len > 0 and line[line.len - 1] == '\r') {
            line = line[0 .. line.len - 1];
        }
        line_start = line_end + 1; // skip \n

        if (parseOption(allocator, line)) |opt| {
            const name_lower = try allocator.alloc(u8, opt.name.len);
            _ = std.ascii.lowerString(name_lower, opt.name);
            var val = opt.value;
            if (std.mem.endsWith(u8, val, ";")) {
                val = val[0 .. val.len - 1];
            }
            try opts.put(name_lower, try allocator.dupe(u8, val));
        }
    }
    return opts;
}
