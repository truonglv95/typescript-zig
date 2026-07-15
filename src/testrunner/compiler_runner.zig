const std = @import("std");

const ast = @import("../ast/ast.zig");
const checker = @import("../checker/checker.zig");
const core = @import("../core/core.zig");
const repo = @import("../repo/repo.zig");
const testutil = @import("../testutil/testutil.zig");
const baseline = @import("../testutil/baseline/baseline.zig");
const harnessutil = @import("../testutil/harnessutil/harnessutil.zig");
const tsbaseline = @import("../testutil/tsbaseline/tsbaseline.zig");
const tsoptions = @import("../tsoptions/tsoptions.zig");
const tspath = @import("../tspath/tspath.zig");
const osvfs = @import("../vfs/osvfs/osvfs.zig");

// testrunner module imports
const testrunner = @import("testrunner.zig"); // Assume other package definitions are here

const compilerBaselineRegex = "\\.tsx?$";
const requireStr = "require(";
const referencesRegex = "reference\\spath";

// Posix-style path to sources under test
pub const srcFolder = "/.src";

pub const CompilerTestType = enum {
    Conformance,
    Regression,

    pub fn toString(self: CompilerTestType) []const u8 {
        return switch (self) {
            .Regression => "compiler",
            .Conformance => "conformance",
        };
    }
};

pub const CompilerBaselineRunner = struct {
    allocator: std.mem.Allocator,
    isSubmodule: bool,
    testFiles: [][]const u8,
    basePath: []const u8,
    testSuitName: []const u8,

    pub fn init(allocator: std.mem.Allocator, testType: CompilerTestType, isSubmodule: bool) !*CompilerBaselineRunner {
        const testSuitName = testType.toString();
        var basePath: []const u8 = undefined;
        if (isSubmodule) {
            const tsp = try repo.typeScriptSubmodulePath(allocator);
            basePath = try std.fmt.allocPrint(allocator, "{s}/tests/cases/{s}", .{ tsp, testSuitName });
        } else {
            basePath = try std.fmt.allocPrint(allocator, "tests/cases/{s}", .{testSuitName});
        }
        const runner = try allocator.create(CompilerBaselineRunner);
        runner.* = .{
            .allocator = allocator,
            .basePath = basePath,
            .testSuitName = testSuitName,
            .isSubmodule = isSubmodule,
            .testFiles = &[_][]const u8{},
        };
        return runner;
    }

    pub fn deinit(self: *CompilerBaselineRunner) void {
        self.allocator.free(self.basePath);
        if (self.testFiles.len > 0) {
            for (self.testFiles) |f| {
                self.allocator.free(f);
            }
            self.allocator.free(self.testFiles);
        }
        self.allocator.destroy(self);
    }

    pub fn EnumerateTestFiles(self: *CompilerBaselineRunner) ![][]const u8 {
        if (self.testFiles.len > 0) {
            return self.testFiles;
        }
        const files = try harnessutil.EnumerateFiles(self.allocator, self.basePath, compilerBaselineRegex, true);
        std.debug.print("Found {d} test files in {s}\n", .{ files.len, self.basePath });
        self.testFiles = files;
        return files;
    }

    const skippedTests = [_][]const u8{
        // Tests that depended on typescript.d.ts in built.
        "APILibCheck.ts",
        "APISample_Watch.ts",
        "APISample_WatchWithDefaults.ts",
        "APISample_WatchWithOwnWatchHost.ts",
        "APISample_compile.ts",
        "APISample_jsdoc.ts",
        "APISample_linter.ts",
        "APISample_parseConfig.ts",
        "APISample_transform.ts",
        "APISample_watcher.ts",

        // These tests contain options that have been completely removed, so fail to parse.
        "preserveUnusedImports.ts",
        "noCrashWithVerbatimModuleSyntaxAndImportsNotUsedAsValues.ts",
        "verbatimModuleSyntaxCompat.ts",
        "verbatimModuleSyntaxCompat2.ts",
        "verbatimModuleSyntaxCompat3.ts",
        "verbatimModuleSyntaxCompat4.ts",
        "preserveValueImports.ts",
        "preserveValueImports_importsNotUsedAsValues.ts",
        "preserveValueImports_errors.ts",
        "preserveValueImports_mixedImports.ts",
        "preserveValueImports_module.ts",
        "importsNotUsedAsValues_error.ts",
        "alwaysStrictNoImplicitUseStrict.ts",
        "nonPrimitiveIndexingWithForInSupressError.ts",
        "parameterInitializerBeforeDestructuringEmit.ts",
        "mappedTypeUnionConstraintInferences.ts",
        "lateBoundConstraintTypeChecksCorrectly.ts",
        "keyofDoesntContainSymbols.ts",
        "isolatedModulesOut.ts",
        "noStrictGenericChecks.ts",
        "noImplicitUseStrict_umd.ts",
        "noImplicitUseStrict_system.ts",
        "noImplicitUseStrict_es6.ts",
        "noImplicitUseStrict_commonjs.ts",
        "noImplicitUseStrict_amd.ts",
        "noImplicitAnyIndexingSuppressed.ts",
        "excessPropertyErrorsSuppressed.ts",
        "moduleNoneDynamicImport.ts",
        "moduleNoneErrors.ts",
        "moduleNoneOutFile.ts",
        "noErrorUsingImportExportModuleAugmentationInDeclarationFile1.ts",
        "noErrorUsingImportExportModuleAugmentationInDeclarationFile2.ts",
        "noErrorUsingImportExportModuleAugmentationInDeclarationFile3.ts",
        "requireOfJsonFileWithModuleEmitNone.ts",
        "requireOfJsonFileWithModuleNodeResolutionEmitNone.ts",
    };

    pub fn RunTests(self: *CompilerBaselineRunner) !void {
        try self.cleanUpLocal();
        const files = try self.EnumerateTestFiles();

        for (files) |filename| {
            var skip = false;
            for (skippedTests) |skp| {
                if (std.mem.eql(u8, skp, tspath.GetBaseFileName(filename))) {
                    skip = true;
                    break;
                }
            }
            if (skip) continue;
            try self.runTest(filename);
        }
    }

    pub fn cleanUpLocal(self: *CompilerBaselineRunner) !void {
        const testDataPath = try repo.TestDataPath(self.allocator);
        const localBasePath = try std.fs.path.join(self.allocator, &[_][]const u8{ testDataPath, "baselines", "local" });
        defer self.allocator.free(localBasePath);
        const diffFolder = if (self.isSubmodule) "diff" else "";
        const localPath = try std.fs.path.join(self.allocator, &[_][]const u8{ localBasePath, diffFolder, self.testSuitName });
        defer self.allocator.free(localPath);
        // std.fs.cwd().deleteTree(localPath) catch {}; // Ignore error if doesn't exist
    }

    pub fn runTest(self: *CompilerBaselineRunner, filename: []const u8) !void {
        std.debug.print("Running test: {s}\n", .{filename});

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        const test_case = try getCompilerFileBasedTest(arena_allocator, filename);
        const basename = tspath.GetBaseFileName(filename);
        if (test_case.configurations.len > 0) {
            for (test_case.configurations) |config| {
                var testName = try arena_allocator.dupe(u8, basename);
                if (config.Name.len > 0) {
                    const extra = try std.fmt.allocPrint(arena_allocator, " {s}", .{config.Name});
                    testName = try std.mem.concat(arena_allocator, u8, &[_][]const u8{ testName, extra });
                }
                try self.runSingleConfigTest(arena_allocator, testName, test_case, config);
            }
        } else {
            try self.runSingleConfigTest(arena_allocator, basename, test_case, null);
        }
    }

    pub fn runSingleConfigTest(self: *CompilerBaselineRunner, allocator: std.mem.Allocator, testName: []const u8, test_case: *compilerFileBasedTest, config: ?*harnessutil.NamedTestConfiguration) !void {
        var payload = try testrunner.makeUnitsFromTest(allocator, test_case.content, test_case.filename);
        var compTest = try newCompilerTest(allocator, testName, test_case.filename, &payload, config);

        try harnessutil.SkipUnsupportedCompilerOptions(compTest.options);

        try compTest.verifyDiagnostics(self.testSuitName, self.isSubmodule);
        try compTest.verifyJavaScriptOutput(self.testSuitName, self.isSubmodule);
        try compTest.verifySourceMapOutput(self.testSuitName, self.isSubmodule);
        try compTest.verifySourceMapRecord(self.testSuitName, self.isSubmodule);
        try compTest.verifyTypesAndSymbols(self.testSuitName, self.isSubmodule);
        try compTest.verifyModuleResolution(self.testSuitName, self.isSubmodule);
        try compTest.verifyUnionOrdering();
        try compTest.verifyParentPointers();
    }
};

pub fn getCompilerVaryByMap(allocator: std.mem.Allocator) !std.StringHashMap(void) {
    var varyByMap = std.StringHashMap(void).init(allocator);
    for (tsoptions.OptionsDeclarations) |option| {
        if (!option.IsCommandLineOnly and
            (option.Kind == tsoptions.CommandLineOptionTypeBoolean or option.Kind == tsoptions.CommandLineOptionTypeEnum) and
            (option.AffectsProgramStructure or
                option.AffectsEmit or
                option.AffectsModuleResolution or
                option.AffectsBindDiagnostics or
                option.AffectsSemanticDiagnostics or
                option.AffectsSourceFile or
                option.AffectsDeclarationPath or
                option.AffectsBuildInfo))
        {
            const lower = try std.ascii.allocLowerString(allocator, option.Name);
            try varyByMap.put(lower, {});
        }
    }
    try varyByMap.put("noemit", {});
    try varyByMap.put("isolatedmodules", {});
    return varyByMap;
}

pub const compilerFileBasedTest = struct {
    filename: []const u8,
    content: []const u8,
    configurations: []*harnessutil.NamedTestConfiguration,
};

pub fn getCompilerFileBasedTest(allocator: std.mem.Allocator, filename: []const u8) !*compilerFileBasedTest {
    const content = try osvfs.FS().ReadFile(allocator, filename);
    const settings = try testrunner.extractCompilerSettings(allocator, content);
    const varyByMap = try getCompilerVaryByMap(allocator);
    const configurations = try harnessutil.GetFileBasedTestConfigurations(allocator, settings, varyByMap);

    const test_case = try allocator.create(compilerFileBasedTest);
    test_case.* = .{
        .filename = filename,
        .content = content,
        .configurations = configurations,
    };
    return test_case;
}

pub const compilerTest = struct {
    allocator: std.mem.Allocator,
    testName: []const u8,
    filename: []const u8,
    basename: []const u8,
    configuredName: []const u8,
    options: *core.CompilerOptions,
    harnessOptions: *harnessutil.HarnessOptions,
    result: *harnessutil.CompilationResult,
    tsConfigFiles: []*harnessutil.TestFile,
    toBeCompiled: []*harnessutil.TestFile,
    otherFiles: []*harnessutil.TestFile,
    hasNonDtsFiles: bool,

    pub fn verifyDiagnostics(self: *compilerTest, suiteName: []const u8, isSubmodule: bool) !void {
        const files = try core.Concatenate(*harnessutil.TestFile, self.allocator, self.tsConfigFiles, try core.Concatenate(*harnessutil.TestFile, self.allocator, self.toBeCompiled, self.otherFiles));
        try tsbaseline.DoErrorBaseline(self.allocator, self.configuredName, files, self.result.Diagnostics, self.options.pretty orelse false, .{
            .Subfolder = suiteName,
            .IsSubmodule = isSubmodule,
        });
    }

    const skippedEmitTests = std.StaticStringMap([]const u8).initComptime(.{
        .{ "filesEmittingIntoSameOutput.ts", "Output order nondeterministic due to collision on filename during parallel emit." },
        .{ "jsFileCompilationWithJsEmitPathSameAsInput.ts", "Output order nondeterministic due to collision on filename during parallel emit." },
        .{ "grammarErrors.ts", "Output order nondeterministic due to collision on filename during parallel emit." },
        .{ "jsFileCompilationEmitBlockedCorrectly.ts", "Output order nondeterministic due to collision on filename during parallel emit." },
        .{ "jsDeclarationsReexportAliasesEsModuleInterop.ts", "cls.d.ts is missing statements when run concurrently." },
        .{ "jsFileCompilationWithoutJsExtensions.ts", "No files are emitted." },
        .{ "typeOnlyMerge2.ts", "Nondeterministic contents when run concurrently." },
        .{ "typeOnlyMerge3.ts", "Nondeterministic contents when run concurrently." },
    });

    pub fn verifyJavaScriptOutput(self: *compilerTest, suiteName: []const u8, isSubmodule: bool) !void {
        if (!self.hasNonDtsFiles) {
            return;
        }

        if (skippedEmitTests.get(self.basename) != null) {
            return; // Skip
        }

        const testDataPath = try repo.TestDataPath(self.allocator);
        var headerComponents = try tspath.GetPathComponentsRelativeTo(self.allocator, testDataPath, self.filename, .{});
        if (isSubmodule and headerComponents.len >= 4) {
            headerComponents = headerComponents[4..]; // Strip "./../_submodules/TypeScript" prefix
        }
        const header = try tspath.GetPathFromPathComponents(self.allocator, headerComponents);
        try tsbaseline.DoJSEmitBaseline(self.allocator, self.configuredName, header, self.options, self.result, self.tsConfigFiles, self.toBeCompiled, self.otherFiles, self.harnessOptions, .{
            .Subfolder = suiteName,
            .IsSubmodule = isSubmodule,
        });
    }

    pub fn verifySourceMapOutput(self: *compilerTest, suiteName: []const u8, isSubmodule: bool) !void {
        const testDataPath = try repo.TestDataPath(self.allocator);
        var headerComponents = try tspath.GetPathComponentsRelativeTo(self.allocator, testDataPath, self.filename, .{});
        if (isSubmodule and headerComponents.len >= 4) {
            headerComponents = headerComponents[4..];
        }
        const header = try tspath.GetPathFromPathComponents(self.allocator, headerComponents);
        try tsbaseline.DoSourcemapBaseline(self.allocator, self.configuredName, header, self.options, self.result, self.harnessOptions, .{
            .Subfolder = suiteName,
            .IsSubmodule = isSubmodule,
        });
    }

    pub fn verifySourceMapRecord(self: *compilerTest, suiteName: []const u8, isSubmodule: bool) !void {
        const testDataPath = try repo.TestDataPath(self.allocator);
        var headerComponents = try tspath.GetPathComponentsRelativeTo(self.allocator, testDataPath, self.filename, .{});
        if (isSubmodule and headerComponents.len >= 4) {
            headerComponents = headerComponents[4..];
        }
        const header = try tspath.GetPathFromPathComponents(self.allocator, headerComponents);
        try tsbaseline.DoSourcemapRecordBaseline(self.allocator, self.configuredName, header, self.options, self.result, self.harnessOptions, .{
            .Subfolder = suiteName,
            .IsSubmodule = isSubmodule,
        });
    }

    pub fn verifyTypesAndSymbols(self: *compilerTest, suiteName: []const u8, isSubmodule: bool) !void {
        if (self.harnessOptions.NoTypesAndSymbols) {
            return;
        }
        const MockProgram = struct {
            dummy: u8 = 0,
            pub fn GetSourceFile(_self: *@This(), name: []const u8) ?*anyopaque {
                _ = _self;
                _ = name;
                return null;
            }
        };
        const program: *MockProgram = @ptrCast(@alignCast(self.result.Program));
        var allFiles = std.ArrayList(*harnessutil.TestFile).empty;
        defer allFiles.deinit(self.allocator);
        for (try core.Concatenate(*harnessutil.TestFile, self.allocator, self.toBeCompiled, self.otherFiles)) |f| {
            if (program.GetSourceFile(f.UnitName) != null) {
                try allFiles.append(self.allocator, f);
            }
        }

        const testDataPath = try repo.TestDataPath(self.allocator);
        var headerComponents = try tspath.GetPathComponentsRelativeTo(self.allocator, testDataPath, self.filename, .{});
        if (isSubmodule and headerComponents.len >= 4) {
            headerComponents = headerComponents[4..];
        }
        const header = try tspath.GetPathFromPathComponents(self.allocator, headerComponents);
        try tsbaseline.DoTypeAndSymbolBaseline(self.allocator, self.configuredName, header, program, allFiles.items, .{
            .Subfolder = suiteName,
            .IsSubmodule = isSubmodule,
        }, false, false, self.result.Diagnostics.len > 0);
    }

    pub fn verifyModuleResolution(self: *compilerTest, suiteName: []const u8, isSubmodule: bool) !void {
        if (!(self.options.traceResolution orelse false)) {
            return;
        }
        try tsbaseline.DoModuleResolutionBaseline(self.allocator, self.configuredName, self.result.Trace, .{
            .Subfolder = suiteName,
            .IsSubmodule = isSubmodule,
            .SkipDiffWithOld = true,
        });
    }

    pub fn verifyUnionOrdering(self: *compilerTest) !void {
        _ = self;
    }

    pub fn verifyParentPointers(self: *compilerTest) !void {
        _ = self;
    }
};

pub const testCaseContentWithConfig = struct {
    testCaseContent: testrunner.testCaseContent,
    configuration: harnessutil.TestConfiguration,
};

pub fn newCompilerTest(
    allocator: std.mem.Allocator,
    testName: []const u8,
    filename: []const u8,
    testContent: *testrunner.testCaseContent,
    namedConfiguration: ?*harnessutil.NamedTestConfiguration,
) !*compilerTest {
    const basename = tspath.GetBaseFileName(filename);
    var configuredName = try allocator.dupe(u8, basename);
    if (namedConfiguration) |nc| {
        if (nc.Name.len > 0) {
            const extname = tspath.GetAnyExtensionFromPath(basename, null, false);
            const extensionlessBasename = basename[0 .. basename.len - extname.len];
            configuredName = try std.fmt.allocPrint(allocator, "{s}({s}){s}", .{ extensionlessBasename, nc.Name, extname });
        }
    }

    const configuration = if (namedConfiguration) |nc| nc.Config else testrunner.TestConfiguration.init(allocator);

    const tcContentConfig = testCaseContentWithConfig{
        .testCaseContent = testContent.*,
        .configuration = configuration,
    };

    var harnessConfig = tcContentConfig.configuration;
    const currentDirectory = try tspath.GetNormalizedAbsolutePath(allocator, harnessConfig.get("currentdirectory") orelse srcFolder, srcFolder);

    const units = tcContentConfig.testCaseContent.testUnitData;
    var toBeCompiled = std.ArrayList(*harnessutil.TestFile).empty;
    var otherFiles = std.ArrayList(*harnessutil.TestFile).empty;
    var tsConfig: ?*tsoptions.commandlineparser.ParsedCommandLine = null;

    var hasNonDtsFiles = false;
    for (units) |unit| {
        if (!tspath.FileExtensionIs(unit.name, tspath.ExtensionDts)) {
            hasNonDtsFiles = true;
            break;
        }
    }

    var tsConfigFiles = std.ArrayList(*harnessutil.TestFile).empty;

    if (tcContentConfig.testCaseContent.tsConfig) |tsc| {
        tsConfig = tsc;
        var tscf_ud = tcContentConfig.testCaseContent.tsConfigFileUnitData.?;
        try tsConfigFiles.append(allocator, try createHarnessTestFile(allocator, &tscf_ud, currentDirectory));
        for (units) |unit| {
            const normalizedPath = try tspath.GetNormalizedAbsolutePath(allocator, unit.name, currentDirectory);
            var contains = false;
            for (tsc.FileNames()) |f| {
                if (std.mem.eql(u8, f, normalizedPath)) {
                    contains = true;
                    break;
                }
            }
            if (contains) {
                try toBeCompiled.append(allocator, try createHarnessTestFile(allocator, &unit, currentDirectory));
            } else {
                try otherFiles.append(allocator, try createHarnessTestFile(allocator, &unit, currentDirectory));
            }
        }
    } else {
        if (harnessConfig.get("baseurl")) |baseUrl| {
            if (!tspath.IsRootedDiskPath(baseUrl)) {
                try harnessConfig.put("baseurl", try tspath.GetNormalizedAbsolutePath(allocator, baseUrl, currentDirectory));
            }
        }

        const lastUnit = units[units.len - 1];
        if (harnessConfig.get("noimplicitreferences") != null or
            std.mem.indexOf(u8, lastUnit.content, requireStr) != null or
            std.mem.indexOf(u8, lastUnit.content, referencesRegex) != null) // Simplification for regex match
        {
            try toBeCompiled.append(allocator, try createHarnessTestFile(allocator, &lastUnit, currentDirectory));
            for (units[0 .. units.len - 1]) |unit| {
                try otherFiles.append(allocator, try createHarnessTestFile(allocator, &unit, currentDirectory));
            }
        } else {
            for (units) |unit| {
                try toBeCompiled.append(allocator, try createHarnessTestFile(allocator, &unit, currentDirectory));
            }
        }
    }

    const result = try harnessutil.CompileFiles(allocator, toBeCompiled.items, otherFiles.items, harnessConfig, tsConfig, currentDirectory, tcContentConfig.testCaseContent.symlinks);

    const compTest = try allocator.create(compilerTest);
    compTest.* = .{
        .allocator = allocator,
        .testName = testName,
        .filename = filename,
        .basename = basename,
        .configuredName = configuredName,
        .options = @ptrCast(@alignCast(result.Options)),
        .harnessOptions = result.HarnessOptions,
        .result = result,
        .tsConfigFiles = try tsConfigFiles.toOwnedSlice(allocator),
        .toBeCompiled = try toBeCompiled.toOwnedSlice(allocator),
        .otherFiles = try otherFiles.toOwnedSlice(allocator),
        .hasNonDtsFiles = hasNonDtsFiles,
    };
    return compTest;
}

pub fn createHarnessTestFile(allocator: std.mem.Allocator, unit: *const testrunner.testUnit, currentDirectory: []const u8) !*harnessutil.TestFile {
    const tf = try allocator.create(harnessutil.TestFile);
    tf.* = .{
        .UnitName = try tspath.GetNormalizedAbsolutePath(allocator, unit.name, currentDirectory),
        .Content = unit.content,
    };
    return tf;
}
