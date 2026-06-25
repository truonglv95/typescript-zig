const std = @import("std");
const core = @import("../core/core.zig");
const ast = @import("../ast/ast.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const tspath = @import("../tspath/tspath.zig");
const options_declarations = @import("commandlineoption.zig");

pub fn parseTristate(value: std.json.Value) ?bool {
    return switch (value) {
        .bool => |b| b,
        else => null,
    };
}

pub fn parseStringArray(allocator: std.mem.Allocator, value: std.json.Value) !?[]const []const u8 {
    if (value != .array) return null;
    var list = std.ArrayList([]const u8).init(allocator);
    for (value.array.items) |v| {
        if (v == .string) {
            try list.append(try allocator.dupe(u8, v.string));
        }
    }
    return try list.toOwnedSlice();
}

pub fn parseStringMap(allocator: std.mem.Allocator, value: std.json.Value) !?*std.AutoHashMap([]const u8, void) {
    if (value != .object) return null;
    const result = try allocator.create(std.AutoHashMap([]const u8, void));
    result.* = std.AutoHashMap([]const u8, void).init(allocator);
    var it = value.object.iterator();
    while (it.next()) |entry| {
        try result.put(try allocator.dupe(u8, entry.key_ptr.*), {});
    }
    return result;
}

pub fn parseString(allocator: std.mem.Allocator, value: std.json.Value) !?[]const u8 {
    if (value == .string) {
        return try allocator.dupe(u8, value.string);
    }
    return null;
}

pub fn parseNumber(allocator: std.mem.Allocator, value: std.json.Value) !?*i32 {
    switch (value) {
        .integer => |i| {
            const num = try allocator.create(i32);
            num.* = @intCast(i);
            return num;
        },
        .float => |f| {
            const num = try allocator.create(i32);
            num.* = @intFromFloat(f);
            return num;
        },
        else => return null,
    }
}

pub fn parseProjectReference(allocator: std.mem.Allocator, json: std.json.Value) !?[]*core.ProjectReference {
    if (json != .object) return null;
    var list = std.ArrayList(*core.ProjectReference).init(allocator);
    const ref = try allocator.create(core.ProjectReference);
    ref.* = core.ProjectReference{
        .path = "",
        .circular = false,
    };
    if (json.object.get("path")) |v| {
        if (v == .string) ref.path = try allocator.dupe(u8, v.string);
    }
    if (json.object.get("circular")) |v| {
        if (v == .bool) ref.circular = v.bool;
    }
    try list.append(ref);
    return try list.toOwnedSlice();
}

pub fn parseJsonToStringKey(allocator: std.mem.Allocator, json: std.json.Value) !?*std.StringHashMap(std.json.Value) {
    if (json != .object) return null;
    const result = try allocator.create(std.StringHashMap(std.json.Value));
    result.* = std.StringHashMap(std.json.Value).init(allocator);

    if (json.object.get("include")) |v| try result.put("include", v);
    if (json.object.get("exclude")) |v| try result.put("exclude", v);
    if (json.object.get("files")) |v| try result.put("files", v);
    if (json.object.get("references")) |v| try result.put("references", v);
    if (json.object.get("extends")) |v| {
        if (v == .string) {
            // Note: Zig's std.json doesn't allow easy array modification like Go does,
            // so we just put the string for now, or wrap it in an array if needed.
            // But we keep it 1:1 as best we can.
        }
        try result.put("extends", v);
    }
    if (json.object.get("compilerOptions")) |v| try result.put("compilerOptions", v);
    if (json.object.get("excludes")) |v| try result.put("excludes", v);
    if (json.object.get("typeAcquisition")) |v| try result.put("typeAcquisition", v);

    return result;
}

pub fn parseCompilerOptions(allocator: std.mem.Allocator, key: []const u8, value: std.json.Value, allOptions: *core.CompilerOptions) !void {
    _ = try parseCompilerOptionsInternal(allocator, key, value, allOptions);
}

pub fn parseCompilerOptionsInternal(allocator: std.mem.Allocator, key_param: []const u8, value: std.json.Value, allOptions: *core.CompilerOptions) !bool {
    var key: []const u8 = key_param;
    for (options_declarations.optionsDeclarations) |opt| {
        if (std.mem.eql(u8, key, opt.name) or (opt.shortName.len > 0 and std.mem.eql(u8, key, opt.shortName))) {
            key = opt.name;
            break;
        }
    }

    if (std.mem.eql(u8, key, "allowJs")) {
        allOptions.allowJs = parseTristate(value);
    } else if (std.mem.eql(u8, key, "allowImportingTsExtensions")) {
        allOptions.allowImportingTsExtensions = parseTristate(value);
    } else if (std.mem.eql(u8, key, "allowSyntheticDefaultImports")) {
        allOptions.allowSyntheticDefaultImports = parseTristate(value);
    } else if (std.mem.eql(u8, key, "allowNonTsExtensions")) {
        allOptions.allowNonTsExtensions = parseTristate(value);
    } else if (std.mem.eql(u8, key, "allowUmdGlobalAccess")) {
        allOptions.allowUmdGlobalAccess = parseTristate(value);
    } else if (std.mem.eql(u8, key, "allowUnreachableCode")) {
        allOptions.allowUnreachableCode = parseTristate(value);
    } else if (std.mem.eql(u8, key, "allowUnusedLabels")) {
        allOptions.allowUnusedLabels = parseTristate(value);
    } else if (std.mem.eql(u8, key, "allowArbitraryExtensions")) {
        allOptions.allowArbitraryExtensions = parseTristate(value);
    } else if (std.mem.eql(u8, key, "alwaysStrict")) {
        allOptions.alwaysStrict = parseTristate(value);
    } else if (std.mem.eql(u8, key, "assumeChangesOnlyAffectDirectDependencies")) {
        allOptions.assumeChangesOnlyAffectDirectDependencies = parseTristate(value);
    } else if (std.mem.eql(u8, key, "baseUrl")) {
        allOptions.baseUrl = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "build")) {
        allOptions.build = parseTristate(value);
    } else if (std.mem.eql(u8, key, "checkJs")) {
        allOptions.checkJs = parseTristate(value);
    } else if (std.mem.eql(u8, key, "customConditions")) {
        allOptions.customConditions = try parseStringArray(allocator, value);
    } else if (std.mem.eql(u8, key, "composite")) {
        allOptions.composite = parseTristate(value);
    } else if (std.mem.eql(u8, key, "declarationDir")) {
        allOptions.declarationDir = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "deduplicatePackages")) {
        allOptions.deduplicatePackages = parseTristate(value);
    } else if (std.mem.eql(u8, key, "diagnostics")) {
        allOptions.diagnostics = parseTristate(value);
    } else if (std.mem.eql(u8, key, "disableSizeLimit")) {
        allOptions.disableSizeLimit = parseTristate(value);
    } else if (std.mem.eql(u8, key, "disableSourceOfProjectReferenceRedirect")) {
        allOptions.disableSourceOfProjectReferenceRedirect = parseTristate(value);
    } else if (std.mem.eql(u8, key, "disableSolutionSearching")) {
        allOptions.disableSolutionSearching = parseTristate(value);
    } else if (std.mem.eql(u8, key, "disableReferencedProjectLoad")) {
        allOptions.disableReferencedProjectLoad = parseTristate(value);
    } else if (std.mem.eql(u8, key, "declarationMap")) {
        allOptions.declarationMap = parseTristate(value);
    } else if (std.mem.eql(u8, key, "declaration")) {
        allOptions.declaration = parseTristate(value);
    } else if (std.mem.eql(u8, key, "downlevelIteration")) {
        allOptions.downlevelIteration = parseTristate(value);
    } else if (std.mem.eql(u8, key, "erasableSyntaxOnly")) {
        allOptions.erasableSyntaxOnly = parseTristate(value);
    } else if (std.mem.eql(u8, key, "emitDeclarationOnly")) {
        allOptions.emitDeclarationOnly = parseTristate(value);
    } else if (std.mem.eql(u8, key, "extendedDiagnostics")) {
        allOptions.extendedDiagnostics = parseTristate(value);
    } else if (std.mem.eql(u8, key, "emitDecoratorMetadata")) {
        allOptions.emitDecoratorMetadata = parseTristate(value);
    } else if (std.mem.eql(u8, key, "emitBOM")) {
        allOptions.emitBOM = parseTristate(value);
    } else if (std.mem.eql(u8, key, "esModuleInterop")) {
        allOptions.eSModuleInterop = parseTristate(value);
    } else if (std.mem.eql(u8, key, "exactOptionalPropertyTypes")) {
        allOptions.exactOptionalPropertyTypes = parseTristate(value);
    } else if (std.mem.eql(u8, key, "explainFiles")) {
        allOptions.explainFiles = parseTristate(value);
    } else if (std.mem.eql(u8, key, "experimentalDecorators")) {
        allOptions.experimentalDecorators = parseTristate(value);
    } else if (std.mem.eql(u8, key, "forceConsistentCasingInFileNames")) {
        allOptions.forceConsistentCasingInFileNames = parseTristate(value);
    } else if (std.mem.eql(u8, key, "generateCpuProfile")) {
        allOptions.generateCpuProfile = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "generateTrace")) {
        allOptions.generateTrace = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "isolatedModules")) {
        allOptions.isolatedModules = parseTristate(value);
    } else if (std.mem.eql(u8, key, "ignoreConfig")) {
        allOptions.ignoreConfig = parseTristate(value);
    } else if (std.mem.eql(u8, key, "ignoreDeprecations")) {
        allOptions.ignoreDeprecations = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "importHelpers")) {
        allOptions.importHelpers = parseTristate(value);
    } else if (std.mem.eql(u8, key, "incremental")) {
        allOptions.incremental = parseTristate(value);
    } else if (std.mem.eql(u8, key, "init")) {
        allOptions.init = parseTristate(value);
    } else if (std.mem.eql(u8, key, "inlineSourceMap")) {
        allOptions.inlineSourceMap = parseTristate(value);
    } else if (std.mem.eql(u8, key, "inlineSources")) {
        allOptions.inlineSources = parseTristate(value);
    } else if (std.mem.eql(u8, key, "isolatedDeclarations")) {
        allOptions.isolatedDeclarations = parseTristate(value);
    } else if (std.mem.eql(u8, key, "jsx")) {
        allOptions.jsx = floatOrInt32ToFlag(core.JsxEmit, value);
    } else if (std.mem.eql(u8, key, "jsxFactory")) {
        allOptions.jsxFactory = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "jsxFragmentFactory")) {
        allOptions.jsxFragmentFactory = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "jsxImportSource")) {
        allOptions.jsxImportSource = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "lib")) {
        allOptions.lib = try parseStringArray(allocator, value);
    } else if (std.mem.eql(u8, key, "libReplacement")) {
        allOptions.libReplacement = parseTristate(value);
    } else if (std.mem.eql(u8, key, "listEmittedFiles")) {
        allOptions.listEmittedFiles = parseTristate(value);
    } else if (std.mem.eql(u8, key, "listFiles")) {
        allOptions.listFiles = parseTristate(value);
    } else if (std.mem.eql(u8, key, "listFilesOnly")) {
        allOptions.listFilesOnly = parseTristate(value);
    } else if (std.mem.eql(u8, key, "locale")) {
        allOptions.locale = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "mapRoot")) {
        allOptions.mapRoot = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "module")) {
        allOptions.module = floatOrInt32ToFlag(core.ModuleKind, value);
    } else if (std.mem.eql(u8, key, "moduleDetectionKind")) {
        allOptions.moduleDetection = floatOrInt32ToFlag(core.ModuleDetectionKind, value);
    } else if (std.mem.eql(u8, key, "moduleResolution")) {
        allOptions.moduleResolution = floatOrInt32ToFlag(core.ModuleResolutionKind, value);
    } else if (std.mem.eql(u8, key, "moduleSuffixes")) {
        allOptions.moduleSuffixes = try parseStringArray(allocator, value);
    } else if (std.mem.eql(u8, key, "moduleDetection")) {
        allOptions.moduleDetection = floatOrInt32ToFlag(core.ModuleDetectionKind, value);
    } else if (std.mem.eql(u8, key, "noCheck")) {
        allOptions.noCheck = parseTristate(value);
    } else if (std.mem.eql(u8, key, "noFallthroughCasesInSwitch")) {
        allOptions.noFallthroughCasesInSwitch = parseTristate(value);
    } else if (std.mem.eql(u8, key, "noEmitForJsFiles")) {
        allOptions.noEmitForJsFiles = parseTristate(value);
    } else if (std.mem.eql(u8, key, "noErrorTruncation")) {
        allOptions.noErrorTruncation = parseTristate(value);
    } else if (std.mem.eql(u8, key, "noImplicitAny")) {
        allOptions.noImplicitAny = parseTristate(value);
    } else if (std.mem.eql(u8, key, "noImplicitThis")) {
        allOptions.noImplicitThis = parseTristate(value);
    } else if (std.mem.eql(u8, key, "noLib")) {
        allOptions.noLib = parseTristate(value);
    } else if (std.mem.eql(u8, key, "noPropertyAccessFromIndexSignature")) {
        allOptions.noPropertyAccessFromIndexSignature = parseTristate(value);
    } else if (std.mem.eql(u8, key, "noUncheckedIndexedAccess")) {
        allOptions.noUncheckedIndexedAccess = parseTristate(value);
    } else if (std.mem.eql(u8, key, "noEmitHelpers")) {
        allOptions.noEmitHelpers = parseTristate(value);
    } else if (std.mem.eql(u8, key, "noEmitOnError")) {
        allOptions.noEmitOnError = parseTristate(value);
    } else if (std.mem.eql(u8, key, "noImplicitReturns")) {
        allOptions.noImplicitReturns = parseTristate(value);
    } else if (std.mem.eql(u8, key, "noUnusedLocals")) {
        allOptions.noUnusedLocals = parseTristate(value);
    } else if (std.mem.eql(u8, key, "noUnusedParameters")) {
        allOptions.noUnusedParameters = parseTristate(value);
    } else if (std.mem.eql(u8, key, "noImplicitOverride")) {
        allOptions.noImplicitOverride = parseTristate(value);
    } else if (std.mem.eql(u8, key, "noUncheckedSideEffectImports")) {
        allOptions.noUncheckedSideEffectImports = parseTristate(value);
    } else if (std.mem.eql(u8, key, "outFile")) {
        allOptions.outFile = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "noResolve")) {
        allOptions.noResolve = parseTristate(value);
    } else if (std.mem.eql(u8, key, "paths")) {
        allOptions.paths = try parseStringMap(allocator, value);
    } else if (std.mem.eql(u8, key, "preserveWatchOutput")) {
        allOptions.preserveWatchOutput = parseTristate(value);
    } else if (std.mem.eql(u8, key, "preserveConstEnums")) {
        allOptions.preserveConstEnums = parseTristate(value);
    } else if (std.mem.eql(u8, key, "preserveSymlinks")) {
        allOptions.preserveSymlinks = parseTristate(value);
    } else if (std.mem.eql(u8, key, "project")) {
        allOptions.project = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "pretty")) {
        allOptions.pretty = parseTristate(value);
    } else if (std.mem.eql(u8, key, "resolveJsonModule")) {
        allOptions.resolveJsonModule = parseTristate(value);
    } else if (std.mem.eql(u8, key, "resolvePackageJsonExports")) {
        allOptions.resolvePackageJsonExports = parseTristate(value);
    } else if (std.mem.eql(u8, key, "resolvePackageJsonImports")) {
        allOptions.resolvePackageJsonImports = parseTristate(value);
    } else if (std.mem.eql(u8, key, "reactNamespace")) {
        allOptions.reactNamespace = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "rewriteRelativeImportExtensions")) {
        allOptions.rewriteRelativeImportExtensions = parseTristate(value);
    } else if (std.mem.eql(u8, key, "rootDir")) {
        allOptions.rootDir = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "rootDirs")) {
        allOptions.rootDirs = try parseStringArray(allocator, value);
    } else if (std.mem.eql(u8, key, "removeComments")) {
        allOptions.removeComments = parseTristate(value);
    } else if (std.mem.eql(u8, key, "stableTypeOrdering")) {
        allOptions.stableTypeOrdering = parseTristate(value);
    } else if (std.mem.eql(u8, key, "strict")) {
        allOptions.strict = parseTristate(value);
    } else if (std.mem.eql(u8, key, "strictBindCallApply")) {
        allOptions.strictBindCallApply = parseTristate(value);
    } else if (std.mem.eql(u8, key, "strictBuiltinIteratorReturn")) {
        allOptions.strictBuiltinIteratorReturn = parseTristate(value);
    } else if (std.mem.eql(u8, key, "strictFunctionTypes")) {
        allOptions.strictFunctionTypes = parseTristate(value);
    } else if (std.mem.eql(u8, key, "strictNullChecks")) {
        allOptions.strictNullChecks = parseTristate(value);
    } else if (std.mem.eql(u8, key, "strictPropertyInitialization")) {
        allOptions.strictPropertyInitialization = parseTristate(value);
    } else if (std.mem.eql(u8, key, "skipDefaultLibCheck")) {
        allOptions.skipDefaultLibCheck = parseTristate(value);
    } else if (std.mem.eql(u8, key, "sourceMap")) {
        allOptions.sourceMap = parseTristate(value);
    } else if (std.mem.eql(u8, key, "sourceRoot")) {
        allOptions.sourceRoot = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "stripInternal")) {
        allOptions.stripInternal = parseTristate(value);
    } else if (std.mem.eql(u8, key, "suppressOutputPathCheck")) {
        allOptions.suppressOutputPathCheck = parseTristate(value);
    } else if (std.mem.eql(u8, key, "target")) {
        allOptions.target = floatOrInt32ToFlag(core.ScriptTarget, value);
    } else if (std.mem.eql(u8, key, "traceResolution")) {
        allOptions.traceResolution = parseTristate(value);
    } else if (std.mem.eql(u8, key, "tsBuildInfoFile")) {
        allOptions.tsBuildInfoFile = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "typeRoots")) {
        allOptions.typeRoots = try parseStringArray(allocator, value);
    } else if (std.mem.eql(u8, key, "types")) {
        allOptions.types = try parseStringArray(allocator, value);
    } else if (std.mem.eql(u8, key, "useDefineForClassFields")) {
        allOptions.useDefineForClassFields = parseTristate(value);
    } else if (std.mem.eql(u8, key, "useUnknownInCatchVariables")) {
        allOptions.useUnknownInCatchVariables = parseTristate(value);
    } else if (std.mem.eql(u8, key, "verbatimModuleSyntax")) {
        allOptions.verbatimModuleSyntax = parseTristate(value);
    } else if (std.mem.eql(u8, key, "version")) {
        allOptions.version = parseTristate(value);
    } else if (std.mem.eql(u8, key, "help")) {
        allOptions.help = parseTristate(value);
    } else if (std.mem.eql(u8, key, "all")) {
        allOptions.all = parseTristate(value);
    } else if (std.mem.eql(u8, key, "maxNodeModuleJsDepth")) {
        allOptions.maxNodeModuleJsDepth = try parseNumber(allocator, value);
    } else if (std.mem.eql(u8, key, "skipLibCheck")) {
        allOptions.skipLibCheck = parseTristate(value);
    } else if (std.mem.eql(u8, key, "noEmit")) {
        allOptions.noEmit = parseTristate(value);
    } else if (std.mem.eql(u8, key, "showConfig")) {
        allOptions.showConfig = parseTristate(value);
    } else if (std.mem.eql(u8, key, "configFilePath")) {
        allOptions.configFilePath = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "noDtsResolution")) {
        allOptions.noDtsResolution = parseTristate(value);
    } else if (std.mem.eql(u8, key, "pathsBasePath")) {
        allOptions.pathsBasePath = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "outDir")) {
        allOptions.outDir = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "newLine")) {
        allOptions.newLine = floatOrInt32ToFlag(core.NewLineKind, value);
    } else if (std.mem.eql(u8, key, "watch")) {
        allOptions.watch = parseTristate(value);
    } else if (std.mem.eql(u8, key, "pprofDir")) {
        allOptions.pprofDir = try parseString(allocator, value);
    } else if (std.mem.eql(u8, key, "singleThreaded")) {
        allOptions.singleThreaded = parseTristate(value);
    } else if (std.mem.eql(u8, key, "quiet")) {
        allOptions.quiet = parseTristate(value);
    } else if (std.mem.eql(u8, key, "checkers")) {
        allOptions.checkers = try parseNumber(allocator, value);
    } else {
        return false;
    }
    return true;
}

pub fn floatOrInt32ToFlag(comptime T: type, value: std.json.Value) ?T {
    return switch (value) {
        .integer => |i| @enumFromInt(i),
        .float => |f| @enumFromInt(@as(i64, @intFromFloat(f))),
        else => null,
    };
}

pub fn parseWatchOptions(allocator: std.mem.Allocator, key: []const u8, value: std.json.Value, allOptions: *core.WatchOptions) !void {
    if (std.mem.eql(u8, key, "watchInterval")) {
        allOptions.interval = try parseNumber(allocator, value);
    } else if (std.mem.eql(u8, key, "watchFile")) {
        if (floatOrInt32ToFlag(core.WatchFileKind, value)) |flag| allOptions.fileKind = flag;
    } else if (std.mem.eql(u8, key, "watchDirectory")) {
        if (floatOrInt32ToFlag(core.WatchDirectoryKind, value)) |flag| allOptions.directoryKind = flag;
    } else if (std.mem.eql(u8, key, "fallbackPolling")) {
        if (floatOrInt32ToFlag(core.PollingWatchKind, value)) |flag| allOptions.fallbackPolling = flag;
    } else if (std.mem.eql(u8, key, "synchronousWatchDirectory")) {
        allOptions.syncWatchDir = parseTristate(value);
    } else if (std.mem.eql(u8, key, "excludeDirectories")) {
        allOptions.excludeDir = try parseStringArray(allocator, value);
    } else if (std.mem.eql(u8, key, "excludeFiles")) {
        allOptions.excludeFiles = try parseStringArray(allocator, value);
    }
}

pub fn parseTypeAcquisition(allocator: std.mem.Allocator, key: []const u8, value: std.json.Value, allOptions: *core.TypeAcquisition) !void {
    if (std.mem.eql(u8, key, "enable")) {
        allOptions.enable = parseTristate(value);
    } else if (std.mem.eql(u8, key, "include")) {
        allOptions.include = try parseStringArray(allocator, value);
    } else if (std.mem.eql(u8, key, "exclude")) {
        allOptions.exclude = try parseStringArray(allocator, value);
    } else if (std.mem.eql(u8, key, "disableFilenameBasedTypeAcquisition")) {
        allOptions.disableFilenameBasedTypeAcquisition = parseTristate(value);
    }
}

pub fn parseBuildOptions(allocator: std.mem.Allocator, key_param: []const u8, value: std.json.Value, allOptions: *core.BuildOptions) !void {
    const key = key_param; // We skip BuildNameMap.Get(key) for now

    if (std.mem.eql(u8, key, "clean")) {
        allOptions.clean = parseTristate(value);
    } else if (std.mem.eql(u8, key, "dry")) {
        allOptions.dry = parseTristate(value);
    } else if (std.mem.eql(u8, key, "force")) {
        allOptions.force = parseTristate(value);
    } else if (std.mem.eql(u8, key, "builders")) {
        allOptions.builders = try parseNumber(allocator, value);
    } else if (std.mem.eql(u8, key, "stopBuildOnErrors")) {
        allOptions.stopBuildOnErrors = parseTristate(value);
    } else if (std.mem.eql(u8, key, "verbose")) {
        allOptions.verbose = parseTristate(value);
    }
}

pub fn mergeCompilerOptions(targetOptions: *core.CompilerOptions, sourceOptions: ?*core.CompilerOptions, rawSource: ?std.json.Value) *core.CompilerOptions {
    if (sourceOptions == null) return targetOptions;

    const T = core.CompilerOptions;
    inline for (@typeInfo(T).Struct.fields) |field| {
        var explicitly_null = false;
        if (rawSource) |raw| {
            if (raw == .object) {
                if (raw.object.get("compilerOptions")) |co_val| {
                    if (co_val == .object) {
                        if (co_val.object.get(field.name)) |json_val| {
                            if (json_val == .null) explicitly_null = true;
                        }
                    }
                }
            }
        }

        if (explicitly_null) {
            @field(targetOptions, field.name) = null;
        } else {
            const src_val = @field(sourceOptions.?, field.name);
            if (src_val != null) {
                @field(targetOptions, field.name) = src_val;
            }
        }
    }
    return targetOptions;
}

pub fn convertToOptionsWithAbsolutePaths(allocator: std.mem.Allocator, optionsBase: ?*std.StringHashMap(std.json.Value), cwd: []const u8) !?*std.StringHashMap(std.json.Value) {
    if (optionsBase == null) return null;
    var it = optionsBase.?.iterator();
    while (it.next()) |entry| {
        if (try convertOptionToAbsolutePath(allocator, entry.key_ptr.*, entry.value_ptr.*, cwd)) |res| {
            try optionsBase.?.put(entry.key_ptr.*, res);
        }
    }
    return optionsBase;
}

pub fn convertOptionToAbsolutePath(allocator: std.mem.Allocator, o: []const u8, v: std.json.Value, cwd: []const u8) !?std.json.Value {
    var option: ?options_declarations.CommandLineOption = null;
    for (options_declarations.optionsDeclarations) |opt| {
        if (std.mem.eql(u8, o, opt.name)) {
            option = opt;
            break;
        }
    }
    if (option == null) return null;

    if (option.?.kind == .List) {
        if (option.?.isFilePath) {
            if (v == .array) {
                var new_arr = std.ArrayList(std.json.Value).init(allocator);
                for (v.array.items) |item| {
                    if (item == .string) {
                        const abs_path = tspath.getNormalizedAbsolutePath(allocator, item.string, cwd);
                        try new_arr.append(std.json.Value{ .string = try allocator.dupe(u8, abs_path) });
                    } else {
                        try new_arr.append(item);
                    }
                }
                return std.json.Value{ .array = new_arr };
            }
        }
    } else if (option.?.isFilePath) {
        if (v == .string) {
            const abs_path = tspath.getNormalizedAbsolutePath(allocator, v.string, cwd);
            return std.json.Value{ .string = try allocator.dupe(u8, abs_path) };
        }
    }
    return null;
}
