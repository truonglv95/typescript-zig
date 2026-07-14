const std = @import("std");
const ast = @import("../ast/ast.zig");
const core = @import("../core/core.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const packagejson = @import("../packagejson/packagejson.zig");
const tspath = @import("../tspath/tspath.zig");
const types = @import("types.zig");
const cache = @import("cache.zig");
const util = @import("util.zig");

const ExtensionMjs = ".mjs";
const ExtensionMts = ".mts";
const ExtensionDmts = ".d.mts";
const ExtensionCjs = ".cjs";
const ExtensionCts = ".cts";
const ExtensionDcts = ".d.cts";

pub const Resolved = struct {
    path: []const u8 = "",
    extension: []const u8 = "",
    packageId: ?types.PackageId = null,
    originalPath: []const u8 = "",
    resolvedUsingTsExtension: bool = false,

    pub fn shouldContinueSearching(self: ?*Resolved) bool {
        return self == null;
    }

    pub fn isResolved(self: ?*Resolved) bool {
        if (self) |r| {
            return r.path.len > 0;
        }
        return false;
    }
};

pub fn continueSearching() ?*Resolved {
    return null;
}

pub fn unresolved(allocator: std.mem.Allocator) !*Resolved {
    const r = try allocator.create(Resolved);
    r.* = .{};
    return r;
}

pub const DiagAndArgs = struct {
    message: *const diagnostics.Message,
    args: [][]const u8 = &[_][]const u8{},
};

pub const Tracer = struct {
    allocator: std.mem.Allocator,
    traces: std.ArrayList(DiagAndArgs),

    pub fn init(allocator: std.mem.Allocator) Tracer {
        return .{
            .allocator = allocator,
            .traces = std.ArrayList(DiagAndArgs).init(allocator),
        };
    }

    pub fn write(self: *Tracer, diag: *const diagnostics.Message, args: [][]const u8) void {
        self.traces.append(.{ .message = diag, .args = args }) catch @panic("OOM");
    }

    pub fn getTraces(self: *Tracer) []DiagAndArgs {
        return self.traces.items;
    }

    pub fn traceResolutionUsingProjectReference(self: *Tracer, redirectedReference: ?*const anyopaque) void {
        _ = self;
        _ = redirectedReference;
        // mock
    }

    pub fn traceTypeReferenceDirectiveResult(self: *Tracer, typeReferenceDirectiveName: []const u8, result: *types.ResolvedTypeReferenceDirective) void {
        _ = self;
        _ = typeReferenceDirectiveName;
        _ = result;
        // mock
    }
};

pub const ResolutionState = struct {
    allocator: std.mem.Allocator,
    resolver: *Resolver,
    tracer: ?*Tracer,

    name: []const u8,
    containingDirectory: []const u8,
    isConfigLookup: bool = false,
    features: types.NodeResolutionFeatures,
    esmMode: bool = false,
    conditions: [][]const u8,
    extensions: types.Extensions,
    compilerOptions: *core.CompilerOptions,
    resolvePackageDirectoryOnly: bool = false,

    candidateEndingIsFromConfig: bool = false,
    resolvedPackageDirectory: bool = false,
    diagnosticsList: std.ArrayList(*ast.Diagnostic),

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        containingDirectory: []const u8,
        isTypeReferenceDirective: bool,
        resolutionMode: core.ResolutionMode,
        compilerOptions: *core.CompilerOptions,
        resolver: *Resolver,
        tracer: ?*Tracer,
    ) !*ResolutionState {
        var state = try allocator.create(ResolutionState);
        state.* = .{
            .allocator = allocator,
            .name = name,
            .containingDirectory = containingDirectory,
            .compilerOptions = compilerOptions,
            .resolver = resolver,
            .tracer = tracer,
            .features = types.NodeResolutionFeatures.NodeNextDefault,
            .conditions = &[_][]const u8{},
            .extensions = types.Extensions.TypeScript,
            .diagnosticsList = std.ArrayList(*ast.Diagnostic).init(allocator),
        };

        if (isTypeReferenceDirective) {
            state.extensions = types.Extensions.Declaration;
        } else if (compilerOptions.noDtsResolution == .True) {
            state.extensions = types.Extensions.ImplementationFiles;
        } else {
            state.extensions = types.Extensions{ .typeScript = true, .javaScript = true, .declaration = true };
        }

        if (!isTypeReferenceDirective and (compilerOptions.resolveJsonModule orelse false)) {
            state.extensions.json = true;
        }

        switch (compilerOptions.moduleResolution orelse .Node10) {
            .Node16 => {
                state.features = types.NodeResolutionFeatures.Node16Default;
                state.esmMode = resolutionMode == .ESNext;
            },
            .NodeNext => {
                state.features = types.NodeResolutionFeatures.NodeNextDefault;
                state.esmMode = resolutionMode == .ESNext;
            },
            .Bundler => {
                state.features = types.NodeResolutionFeatures.BundlerDefault;
            },
            else => {},
        }

        return state;
    }

    pub fn tryFileLookup(self: *ResolutionState, fileName: []const u8) bool {
        if (self.resolver.host.fileExists(fileName)) {
            if (self.tracer) |t| {
                _ = t;
            }
            return true;
        } else if (self.tracer) |t| {
            _ = t;
        }
        return false;
    }

    pub fn tryFile(self: *ResolutionState, fileName: []const u8) struct { []const u8, bool } {
        const moduleSuffixes = self.compilerOptions.moduleSuffixes;
        if (moduleSuffixes == null or moduleSuffixes.?.len == 0) {
            return .{ fileName, self.tryFileLookup(fileName) };
        }

        const ext = tspath.tryGetExtensionFromPath(fileName);
        const fileNameNoExtension = tspath.removeExtension(fileName, ext);
        for (moduleSuffixes.?) |suffix| {
            const path = std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{ fileNameNoExtension, suffix, ext }) catch @panic("OOM");
            if (self.tryFileLookup(path)) {
                return .{ path, true };
            }
        }
        return .{ fileName, false };
    }

    pub fn tryExtension(self: *ResolutionState, extension: []const u8, extensionless: []const u8, resolvedUsingTsExtension: bool) ?*Resolved {
        const fileName = std.fmt.allocPrint(self.allocator, "{s}{s}", .{ extensionless, extension }) catch @panic("OOM");
        const fileResult = self.tryFile(fileName);
        if (fileResult[1]) {
            const r = self.allocator.create(Resolved) catch @panic("OOM");
            r.* = .{
                .path = fileResult[0],
                .extension = extension,
                .resolvedUsingTsExtension = !self.candidateEndingIsFromConfig and resolvedUsingTsExtension,
            };
            return r;
        }
        return continueSearching();
    }

    pub fn tryAddingExtensions(self: *ResolutionState, extensionless: []const u8, exts: types.Extensions, originalExtension: []const u8) ?*Resolved {
        const directory = tspath.getDirectoryPath(self.allocator, extensionless) catch @panic("OOM");
        if (directory.len > 0 and !self.resolver.host.directoryExists(directory)) {
            return continueSearching();
        }

        if (std.mem.eql(u8, originalExtension, tspath.ExtensionMjs) or
            std.mem.eql(u8, originalExtension, tspath.ExtensionMts) or
            std.mem.eql(u8, originalExtension, tspath.ExtensionDmts))
        {
            if (exts.typeScript) {
                if (self.tryExtension(tspath.ExtensionMts, extensionless, std.mem.eql(u8, originalExtension, tspath.ExtensionMts) or std.mem.eql(u8, originalExtension, tspath.ExtensionDmts))) |resolved| {
                    return resolved;
                }
            }
            if (exts.declaration) {
                if (self.tryExtension(tspath.ExtensionDmts, extensionless, std.mem.eql(u8, originalExtension, tspath.ExtensionMts) or std.mem.eql(u8, originalExtension, tspath.ExtensionDmts))) |resolved| {
                    return resolved;
                }
            }
            if (exts.javaScript) {
                if (self.tryExtension(tspath.ExtensionMjs, extensionless, false)) |resolved| {
                    return resolved;
                }
            }
            return continueSearching();
        } else if (std.mem.eql(u8, originalExtension, tspath.ExtensionCjs) or
            std.mem.eql(u8, originalExtension, tspath.ExtensionCts) or
            std.mem.eql(u8, originalExtension, tspath.ExtensionDcts))
        {
            if (exts.typeScript) {
                if (self.tryExtension(tspath.ExtensionCts, extensionless, std.mem.eql(u8, originalExtension, tspath.ExtensionCts) or std.mem.eql(u8, originalExtension, tspath.ExtensionDcts))) |resolved| {
                    return resolved;
                }
            }
            if (exts.declaration) {
                if (self.tryExtension(tspath.ExtensionDcts, extensionless, std.mem.eql(u8, originalExtension, tspath.ExtensionCts) or std.mem.eql(u8, originalExtension, tspath.ExtensionDcts))) |resolved| {
                    return resolved;
                }
            }
            if (exts.javaScript) {
                if (self.tryExtension(tspath.ExtensionCjs, extensionless, false)) |resolved| {
                    return resolved;
                }
            }
            return continueSearching();
        } else if (std.mem.eql(u8, originalExtension, tspath.ExtensionJson)) {
            if (exts.declaration) {
                if (self.tryExtension(".d.json.ts", extensionless, false)) |resolved| {
                    return resolved;
                }
            }
            if (exts.json) {
                if (self.tryExtension(tspath.ExtensionJson, extensionless, false)) |resolved| {
                    return resolved;
                }
            }
            return continueSearching();
        } else if (std.mem.eql(u8, originalExtension, tspath.ExtensionTsx) or
            std.mem.eql(u8, originalExtension, tspath.ExtensionJsx))
        {
            if (exts.typeScript) {
                if (self.tryExtension(tspath.ExtensionTsx, extensionless, std.mem.eql(u8, originalExtension, tspath.ExtensionTsx))) |resolved| {
                    return resolved;
                }
                if (self.tryExtension(tspath.ExtensionTs, extensionless, std.mem.eql(u8, originalExtension, tspath.ExtensionTsx))) |resolved| {
                    return resolved;
                }
            }
            if (exts.declaration) {
                if (self.tryExtension(tspath.ExtensionDts, extensionless, std.mem.eql(u8, originalExtension, tspath.ExtensionTsx))) |resolved| {
                    return resolved;
                }
            }
            if (exts.javaScript) {
                if (self.tryExtension(tspath.ExtensionJsx, extensionless, false)) |resolved| {
                    return resolved;
                }
                if (self.tryExtension(tspath.ExtensionJs, extensionless, false)) |resolved| {
                    return resolved;
                }
            }
            return continueSearching();
        } else if (std.mem.eql(u8, originalExtension, tspath.ExtensionTs) or
            std.mem.eql(u8, originalExtension, tspath.ExtensionDts) or
            std.mem.eql(u8, originalExtension, tspath.ExtensionJs) or
            originalExtension.len == 0)
        {
            if (exts.typeScript) {
                if (self.tryExtension(tspath.ExtensionTs, extensionless, std.mem.eql(u8, originalExtension, tspath.ExtensionTs) or std.mem.eql(u8, originalExtension, tspath.ExtensionDts))) |resolved| {
                    return resolved;
                }
                if (self.tryExtension(tspath.ExtensionTsx, extensionless, std.mem.eql(u8, originalExtension, tspath.ExtensionTs) or std.mem.eql(u8, originalExtension, tspath.ExtensionDts))) |resolved| {
                    return resolved;
                }
            }
            if (exts.declaration) {
                if (self.tryExtension(tspath.ExtensionDts, extensionless, std.mem.eql(u8, originalExtension, tspath.ExtensionTs) or std.mem.eql(u8, originalExtension, tspath.ExtensionDts))) |resolved| {
                    return resolved;
                }
            }
            if (exts.javaScript) {
                if (self.tryExtension(tspath.ExtensionJs, extensionless, false)) |resolved| {
                    return resolved;
                }
                if (self.tryExtension(tspath.ExtensionJsx, extensionless, false)) |resolved| {
                    return resolved;
                }
            }
            if (self.isConfigLookup) {
                if (self.tryExtension(tspath.ExtensionJson, extensionless, false)) |resolved| {
                    return resolved;
                }
            }
            return continueSearching();
        } else {
            if (exts.declaration and !std.mem.endsWith(u8, extensionless, ".d") and !std.mem.endsWith(u8, originalExtension, ".ts")) {
                const ext = std.fmt.allocPrint(self.allocator, ".d{s}.ts", .{originalExtension}) catch @panic("OOM");
                if (self.tryExtension(ext, extensionless, false)) |resolved| {
                    return resolved;
                }
            }
            return continueSearching();
        }
    }

    pub fn loadModuleFromFileNoImplicitExtensions(self: *ResolutionState, exts: types.Extensions, candidate: []const u8) ?*Resolved {
        const base = tspath.getBaseFileName(candidate);
        if (std.mem.indexOfScalar(u8, base, '.') == null) {
            return continueSearching();
        }
        const ext = tspath.tryGetExtensionFromPath(candidate);
        const extless = if (ext.len > 0) tspath.removeExtension(candidate, ext) else blk: {
            const last_dot = std.mem.lastIndexOfScalar(u8, candidate, '.');
            if (last_dot) |i| {
                break :blk candidate[0..i];
            } else {
                break :blk candidate;
            }
        };
        const candidateExtension = candidate[extless.len..];
        if (self.tracer) |t| {
            _ = t;
        }
        return self.tryAddingExtensions(extless, exts, candidateExtension);
    }

    pub fn loadModuleFromFile(self: *ResolutionState, exts: types.Extensions, candidate: []const u8) ?*Resolved {
        if (self.loadModuleFromFileNoImplicitExtensions(exts, candidate)) |resolved| {
            return resolved;
        }
        if (!self.esmMode) {
            return self.tryAddingExtensions(candidate, exts, "");
        }
        return continueSearching();
    }

    pub fn nodeLoadModuleByRelativeName(self: *ResolutionState, exts: types.Extensions, candidate: []const u8, considerPackageJson: bool) ?*Resolved {
        if (self.tracer) |t| {
            _ = t;
        }
        if (!tspath.hasTrailingDirectorySeparator(candidate)) {
            const parentOfCandidate = tspath.getDirectoryPath(self.allocator, candidate) catch @panic("OOM");
            if (!self.resolver.host.directoryExists(parentOfCandidate)) {
                if (self.tracer) |t| {
                    _ = t;
                }
                return continueSearching();
            }
            if (self.loadModuleFromFile(exts, candidate)) |resolvedFromFile| {
                if (considerPackageJson) {
                    const packageDirectory = util.parseNodeModuleFromPath(resolvedFromFile.path, false);
                    _ = packageDirectory;
                }
                return resolvedFromFile;
            }
        }

        if (!self.resolver.host.directoryExists(candidate)) {
            if (self.tracer) |t| {
                _ = t;
            }
            return continueSearching();
        }

        if (!self.esmMode) {
            return self.loadNodeModuleFromDirectory(exts, candidate, considerPackageJson);
        }
        return continueSearching();
    }

    pub fn getPackageJsonInfo(self: *ResolutionState, packageDirectory: []const u8) ?*packagejson.InfoCacheEntry {
        const packageJsonPath = tspath.combinePaths(self.allocator, packageDirectory, &[_][]const u8{"package.json"}) catch @panic("OOM");

        if (self.resolver.caches.packageJsonInfoCache.get(packageJsonPath)) |existing| {
            if (existing.contents != null) {
                if (self.tracer) |t| {
                    _ = t;
                }
                return existing.withPackageDirectory(self.allocator, packageDirectory) catch @panic("OOM");
            } else {
                return null;
            }
        }

        const directoryExists = self.resolver.host.directoryExists(packageDirectory);
        if (directoryExists and self.resolver.host.fileExists(packageJsonPath)) {
            const contents = self.resolver.host.readFile(self.allocator, packageJsonPath) orelse "";
            const parsed = packagejson.parse(self.allocator, contents) catch |err| {
                _ = err;
                if (self.tracer) |t| {
                    _ = t;
                }
                const result = self.allocator.create(packagejson.InfoCacheEntry) catch @panic("OOM");
                result.* = .{
                    .packageDirectory = packageDirectory,
                    .directoryExists = true,
                    .contents = null,
                };
                _ = self.resolver.caches.packageJsonInfoCache.set(packageJsonPath, result) catch @panic("OOM");
                return result;
            };

            if (self.tracer) |t| {
                _ = t;
            }

            const packageJsonPtr = self.allocator.create(packagejson.PackageJson) catch @panic("OOM");
            packageJsonPtr.* = packagejson.PackageJson.init(self.allocator, parsed, true);

            const result = self.allocator.create(packagejson.InfoCacheEntry) catch @panic("OOM");
            result.* = .{
                .packageDirectory = packageDirectory,
                .directoryExists = true,
                .contents = packageJsonPtr,
            };
            const cachedResult = self.resolver.caches.packageJsonInfoCache.set(packageJsonPath, result) catch @panic("OOM");
            return cachedResult.withPackageDirectory(self.allocator, packageDirectory) catch @panic("OOM");
        } else {
            const result = self.allocator.create(packagejson.InfoCacheEntry) catch @panic("OOM");
            result.* = .{
                .packageDirectory = packageDirectory,
                .directoryExists = directoryExists,
                .contents = null,
            };
            _ = self.resolver.caches.packageJsonInfoCache.set(packageJsonPath, result) catch @panic("OOM");
            return null;
        }
    }

    pub fn getPackageJSONPathField(self: *ResolutionState, fieldName: []const u8, field: *const packagejson.Expected([]const u8), packageDirectory: []const u8) ?[]const u8 {
        _ = fieldName;
        if (!field.isPresent()) {
            return null;
        }
        const val = field.getValue();
        if (val == null or val.?.len == 0) {
            if (self.tracer) |t| {
                _ = t;
            }
            return null;
        }
        return tspath.combinePaths(self.allocator, packageDirectory, &[_][]const u8{val.?}) catch @panic("OOM");
    }

    pub fn getPackageFile(self: *ResolutionState, exts: types.Extensions, packageInfo: *packagejson.InfoCacheEntry) ?[]const u8 {
        if (!packageInfo.exists() or packageInfo.contents == null) {
            return null;
        }
        const contents = packageInfo.contents.?;
        if (self.isConfigLookup) {
            return self.getPackageJSONPathField("tsconfig", &contents.fields.pathFields.tsconfig, packageInfo.packageDirectory);
        }
        if (exts.declaration) {
            if (self.getPackageJSONPathField("typings", &contents.fields.pathFields.typings, packageInfo.packageDirectory)) |file| {
                return file;
            }
            if (self.getPackageJSONPathField("types", &contents.fields.pathFields.types, packageInfo.packageDirectory)) |file| {
                return file;
            }
        }
        if (exts.typeScript or exts.javaScript or exts.declaration) {
            return self.getPackageJSONPathField("main", &contents.fields.pathFields.main, packageInfo.packageDirectory);
        }
        return null;
    }

    pub fn loadFileNameFromPackageJSONField(self: *ResolutionState, exts: types.Extensions, candidate: []const u8, packageFile: []const u8) ?*Resolved {
        _ = self;
        _ = exts;
        _ = candidate;
        _ = packageFile;
        return continueSearching();
    }

    pub fn loadNodeModuleFromDirectory(self: *ResolutionState, exts: types.Extensions, candidate: []const u8, considerPackageJson: bool) ?*Resolved {
        var packageInfo: ?*packagejson.InfoCacheEntry = null;
        if (considerPackageJson) {
            packageInfo = self.getPackageJsonInfo(candidate);
        }
        return self.loadNodeModuleFromDirectoryWorker(exts, candidate, packageInfo);
    }

    pub fn loadNodeModuleFromDirectoryWorker(self: *ResolutionState, exts: types.Extensions, candidate: []const u8, packageInfo: ?*packagejson.InfoCacheEntry) ?*Resolved {
        var packageFile: []const u8 = "";
        if (packageInfo) |info| {
            if (info.exists()) {
                const useCaseSensitive = self.resolver.host.useCaseSensitiveFileNames();
                var pathsEql = std.mem.eql(u8, candidate, info.packageDirectory);
                if (!useCaseSensitive) {
                    pathsEql = std.ascii.eqlIgnoreCase(candidate, info.packageDirectory);
                }
                if (pathsEql) {
                    if (self.getPackageFile(exts, info)) |file| {
                        packageFile = file;
                    }
                }
            }
        }

        const ResultLoader = struct {
            state: *ResolutionState,
            packageInfo: ?*packagejson.InfoCacheEntry,
            packageFile: []const u8,

            pub fn load(r_ctx: *@This(), loader_exts: types.Extensions, loader_candidate: []const u8) ?*Resolved {
                if (r_ctx.state.loadFileNameFromPackageJSONField(loader_exts, loader_candidate, r_ctx.packageFile)) |fromFile| {
                    return fromFile;
                }
                var expandedExtensions = loader_exts;
                if (loader_exts.declaration) {
                    expandedExtensions.typeScript = true;
                    expandedExtensions.declaration = true;
                }

                const saveESMMode = r_ctx.state.esmMode;
                const saveCandidateEndingIsFromConfig = r_ctx.state.candidateEndingIsFromConfig;
                r_ctx.state.candidateEndingIsFromConfig = true;
                if (r_ctx.packageInfo) |info| {
                    if (info.exists() and info.contents != null) {
                        const contents = info.contents.?;
                        if (contents.fields.headerFields.type.isPresent() and std.mem.eql(u8, contents.fields.headerFields.type.getValue() orelse "", "module")) {
                            // keeps esmMode
                        } else {
                            r_ctx.state.esmMode = false;
                        }
                    }
                }
                const result = r_ctx.state.nodeLoadModuleByRelativeName(expandedExtensions, loader_candidate, false);
                r_ctx.state.esmMode = saveESMMode;
                r_ctx.state.candidateEndingIsFromConfig = saveCandidateEndingIsFromConfig;
                return result;
            }
        };

        var loader_ctx = ResultLoader{
            .state = self,
            .packageInfo = packageInfo,
            .packageFile = packageFile,
        };

        const indexPath = if (self.isConfigLookup)
            tspath.combinePaths(self.allocator, candidate, &[_][]const u8{"tsconfig"}) catch @panic("OOM")
        else
            tspath.combinePaths(self.allocator, candidate, &[_][]const u8{"index"}) catch @panic("OOM");

        if (packageFile.len > 0) {
            if (loader_ctx.load(exts, packageFile)) |res| {
                return res;
            }
        }

        if (!self.esmMode) {
            if (!self.resolver.host.directoryExists(candidate)) {
                return continueSearching();
            }
            return self.loadModuleFromFile(exts, indexPath);
        }

        return continueSearching();
    }

    pub fn loadModuleFromExports(self: *ResolutionState, packageInfo: *packagejson.InfoCacheEntry, exts: types.Extensions, subpath: []const u8) anyerror!?*Resolved {
        if (!packageInfo.exists() or packageInfo.contents == null or packageInfo.contents.?.fields.pathFields.exports.json_value.isFalsy()) {
            return continueSearching();
        }
        const exports = packageInfo.contents.?.fields.pathFields.exports;
        if (std.mem.eql(u8, subpath, ".")) {
            var mainExport: ?packagejson.JSONValue = null;
            switch (exports.json_value) {
                .String, .Array => {
                    mainExport = exports.json_value;
                },
                .Object => {
                    if (exports.json_value.asObject().get(".")) |dot| {
                        mainExport = dot;
                    } else {
                        var seenDotOrHash = false;
                        var it = exports.json_value.asObject().iterator();
                        while (it.next()) |entry| {
                            const k = entry.key_ptr.*;
                            if (k.len > 0 and (k[0] == '.' or k[0] == '#')) {
                                seenDotOrHash = true;
                                break;
                            }
                        }
                        if (!seenDotOrHash) {
                            mainExport = exports.json_value;
                        }
                    }
                },
                else => {},
            }
            if (mainExport) |m| {
                return try self.loadModuleFromTargetExportOrImport(exts, subpath, packageInfo, false, m, "", false, ".");
            }
        } else if (exports.json_value == .Object) {
            var isSubpaths = false;
            var it = exports.json_value.asObject().iterator();
            while (it.next()) |entry| {
                const k = entry.key_ptr.*;
                if (k.len > 0 and k[0] == '.') {
                    isSubpaths = true;
                    break;
                }
            }
            if (isSubpaths) {
                return try self.loadModuleFromExportsOrImports(exts, subpath, exports.json_value.asObject(), packageInfo, false);
            }
        }
        return continueSearching();
    }

    pub fn loadModuleFromExportsOrImports(
        self: *ResolutionState,
        exts: types.Extensions,
        moduleName: []const u8,
        lookupTable: *const std.StringArrayHashMap(packagejson.JSONValue),
        scope: *packagejson.InfoCacheEntry,
        isImports: bool,
    ) anyerror!?*Resolved {
        if (!std.mem.endsWith(u8, moduleName, "/") and std.mem.indexOfScalar(u8, moduleName, '*') == null) {
            if (lookupTable.get(moduleName)) |target| {
                return try self.loadModuleFromTargetExportOrImport(exts, moduleName, scope, isImports, target, "", false, moduleName);
            }
        }

        var expandingKeys = std.ArrayList([]const u8).init(self.allocator);
        var it = lookupTable.iterator();
        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            if (std.mem.count(u8, key, "*") == 1 or std.mem.endsWith(u8, key, "/")) {
                try expandingKeys.append(key);
            }
        }

        const SortContext = struct {
            pub fn lessThan(ctx: @This(), a: []const u8, b: []const u8) bool {
                _ = ctx;
                return util.comparePatternKeys(a, b) < 0;
            }
        };
        std.mem.sort([]const u8, expandingKeys.items, SortContext{}, SortContext.lessThan);

        for (expandingKeys.items) |potentialTarget| {
            const target = lookupTable.get(potentialTarget).?;
            if (self.features.exportsPatternTrailers and matchesPatternWithTrailer(potentialTarget, moduleName)) {
                const starPos = std.mem.indexOfScalar(u8, potentialTarget, '*').?;
                const prefix = potentialTarget[0..starPos];
                const suffix = potentialTarget[starPos + 1 ..];
                const subpath = moduleName[prefix.len .. moduleName.len - suffix.len];
                return try self.loadModuleFromTargetExportOrImport(exts, moduleName, scope, isImports, target, subpath, true, potentialTarget);
            } else if (std.mem.endsWith(u8, potentialTarget, "*") and std.mem.startsWith(u8, moduleName, potentialTarget[0 .. potentialTarget.len - 1])) {
                const subpath = moduleName[potentialTarget.len - 1 ..];
                return try self.loadModuleFromTargetExportOrImport(exts, moduleName, scope, isImports, target, subpath, true, potentialTarget);
            } else if (std.mem.startsWith(u8, moduleName, potentialTarget)) {
                const subpath = moduleName[potentialTarget.len..];
                return try self.loadModuleFromTargetExportOrImport(exts, moduleName, scope, isImports, target, subpath, false, potentialTarget);
            }
        }

        return continueSearching();
    }

    pub fn loadModuleFromTargetExportOrImport(
        self: *ResolutionState,
        exts: types.Extensions,
        moduleName: []const u8,
        scope: *packagejson.InfoCacheEntry,
        isImports: bool,
        target: packagejson.JSONValue,
        subpath: []const u8,
        isPattern: bool,
        key: []const u8,
    ) anyerror!?*Resolved {
        switch (target) {
            .String => |targetString| {
                if (!isPattern and subpath.len > 0 and !std.mem.endsWith(u8, targetString, "/")) {
                    return continueSearching();
                }
                if (!std.mem.startsWith(u8, targetString, "./")) {
                    if (isImports and !std.mem.startsWith(u8, targetString, "../") and !std.mem.startsWith(u8, targetString, "/") and !tspath.isRootedDiskPath(targetString)) {
                        var combinedLookup = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ targetString, subpath });
                        if (isPattern) {
                            const count = std.mem.count(u8, targetString, "*");
                            if (count > 0) {
                                var replaced = std.ArrayList(u8).init(self.allocator);
                                var start: usize = 0;
                                while (std.mem.indexOfPos(u8, targetString, start, "*")) |idx| {
                                    try replaced.appendSlice(targetString[start..idx]);
                                    try replaced.appendSlice(subpath);
                                    start = idx + 1;
                                }
                                try replaced.appendSlice(targetString[start..]);
                                combinedLookup = try replaced.toOwnedSlice();
                            }
                        }
                        const scopeContainingDirectory = if (std.mem.endsWith(u8, scope.packageDirectory, "/"))
                            scope.packageDirectory
                        else
                            try std.fmt.allocPrint(self.allocator, "{s}/", .{scope.packageDirectory});

                        const prevName = self.name;
                        const prevDir = self.containingDirectory;
                        self.name = combinedLookup;
                        self.containingDirectory = scopeContainingDirectory;

                        const result = try self.resolveNodeLike();
                        self.name = prevName;
                        self.containingDirectory = prevDir;

                        if (result.isResolved()) {
                            const r = try self.allocator.create(Resolved);
                            r.* = .{
                                .path = result.resolvedFileName,
                                .extension = result.extension,
                                .packageId = result.packageId,
                                .originalPath = result.originalPath,
                                .resolvedUsingTsExtension = result.resolvedUsingTsExtension,
                            };
                            return r;
                        }
                        return continueSearching();
                    }
                    return continueSearching();
                }

                if (std.mem.indexOf(u8, targetString, "/../") != null or
                    std.mem.indexOf(u8, targetString, "/./") != null or
                    std.mem.indexOf(u8, targetString, "/node_modules/") != null)
                {
                    return continueSearching();
                }

                const resolvedTarget = try tspath.combinePaths(self.allocator, scope.packageDirectory, &[_][]const u8{targetString});
                if (std.mem.indexOf(u8, subpath, "/../") != null or
                    std.mem.indexOf(u8, subpath, "/./") != null or
                    std.mem.indexOf(u8, subpath, "/node_modules/") != null)
                {
                    return continueSearching();
                }

                var finalPath = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ resolvedTarget, subpath });
                if (isPattern) {
                    const count = std.mem.count(u8, resolvedTarget, "*");
                    if (count > 0) {
                        var replaced = std.ArrayList(u8).init(self.allocator);
                        var start: usize = 0;
                        while (std.mem.indexOfPos(u8, resolvedTarget, start, "*")) |idx| {
                            try replaced.appendSlice(resolvedTarget[start..idx]);
                            try replaced.appendSlice(subpath);
                            start = idx + 1;
                        }
                        try replaced.appendSlice(resolvedTarget[start..]);
                        finalPath = try replaced.toOwnedSlice();
                    }
                }

                if (try self.tryLoadInputFileForPath(finalPath, subpath, try tspath.combinePaths(self.allocator, scope.packageDirectory, &[_][]const u8{"package.json"}), isImports)) |inputLink| {
                    return inputLink;
                }
                if (self.loadFileNameFromPackageJSONField(exts, finalPath, targetString)) |res| {
                    return res;
                }
                return continueSearching();
            },
            .Object => {
                var it = target.asObject().iterator();
                while (it.next()) |entry| {
                    const condition = entry.key_ptr.*;
                    if (self.conditionMatches(condition)) {
                        const subTarget = entry.value_ptr.*;
                        if (try self.loadModuleFromTargetExportOrImport(exts, moduleName, scope, isImports, subTarget, subpath, isPattern, key)) |res| {
                            return res;
                        }
                    }
                }
                return continueSearching();
            },
            .Array => {
                for (target.asArray()) |elem| {
                    if (try self.loadModuleFromTargetExportOrImport(exts, moduleName, scope, isImports, elem, subpath, isPattern, key)) |res| {
                        return res;
                    }
                }
                return continueSearching();
            },
            .Null => {
                return try unresolved(self.allocator);
            },
            else => {
                return continueSearching();
            },
        }
    }

    pub fn conditionMatches(self: *const ResolutionState, condition: []const u8) bool {
        for (self.conditions) |c| {
            if (std.mem.eql(u8, c, condition)) {
                return true;
            }
        }
        return false;
    }

    pub fn tryLoadInputFileForPath(self: *ResolutionState, finalPath: []const u8, entry: []const u8, packagePath: []const u8, isImports: bool) !?*Resolved {
        const hasDeclarationDir = self.compilerOptions.declarationDir != null;
        const hasOutDir = self.compilerOptions.outDir != null;

        std.debug.print("DEBUG tryLoad: finalPath={s}, hasOutDir={}, hasDeclDir={}, outDir={?s}\n", .{ finalPath, hasOutDir, hasDeclarationDir, self.compilerOptions.outDir });

        if (!self.isConfigLookup and (hasDeclarationDir or hasOutDir) and std.mem.indexOf(u8, finalPath, "/node_modules/") == null) {
            var contains = false;
            if (self.compilerOptions.configFilePath) |configFilePath| {
                const configDir = try tspath.getDirectoryPath(self.allocator, configFilePath);
                const pkgDir = try tspath.getDirectoryPath(self.allocator, packagePath);
                contains = std.mem.startsWith(u8, pkgDir, configDir);
                // Also ensure it is actually a subdirectory and not just a string prefix
                if (contains and pkgDir.len > configDir.len and pkgDir[configDir.len] != '/' and configDir[configDir.len - 1] != '/') {
                    contains = false;
                }
            }

            if (self.compilerOptions.configFilePath == null or contains) {
                if (self.compilerOptions.rootDir == null and self.compilerOptions.configFilePath == null) {
                    const diagnostic = try @import("../diagnostics/diagnostics.zig").Diagnostic.init(self.allocator, 0, 0, 0, if (isImports)
                        @import("../diagnostics/diagnostics_generated.zig").The_project_root_is_ambiguous_but_is_required_to_resolve_import_map_entry_0_in_file_1_Supply_the_roo_2210
                    else
                        @import("../diagnostics/diagnostics_generated.zig").The_project_root_is_ambiguous_but_is_required_to_resolve_export_map_entry_0_in_file_1_Supply_the_roo_2209, &.{
                        if (entry.len == 0) "." else entry,
                        packagePath,
                    });
                    try self.diagnostics.append(self.allocator, diagnostic);
                    return try self.unresolved();
                }
                // TODO: the rest of tryLoadInputFileForPath (scanning output directories)
            }
        }
        return self.continueSearching();
    }

    pub fn getPackageScopeForPath(self: *ResolutionState, directory: []const u8) ?*packagejson.InfoCacheEntry {
        var dir = directory;
        while (true) {
            if (self.getPackageJsonInfo(dir)) |info| {
                if (info.exists()) {
                    return info;
                }
            }
            if (std.mem.eql(u8, dir, self.resolver.typingsLocation)) {
                break;
            }
            const parent = tspath.getDirectoryPath(self.allocator, dir) catch break;
            if (std.mem.eql(u8, parent, dir) or parent.len == 0) {
                break;
            }
            dir = parent;
        }
        return null;
    }

    pub fn loadModuleFromSelfNameReference(self: *ResolutionState) !?*Resolved {
        const directoryPath = try tspath.GetNormalizedAbsolutePath(self.allocator, self.containingDirectory, self.resolver.host.getCurrentDirectory());
        const scope = self.getPackageScopeForPath(directoryPath) orelse return continueSearching();
        if (scope.contents == null or scope.contents.?.fields.pathFields.exports.json_value.isFalsy()) {
            return continueSearching();
        }
        const name = scope.contents.?.fields.headerFields.name.getValue() orelse return continueSearching();

        if (!std.mem.startsWith(u8, self.name, name)) {
            return continueSearching();
        }
        var subpath: []const u8 = ".";
        if (self.name.len > name.len) {
            if (self.name[name.len] == '/') {
                subpath = try std.fmt.allocPrint(self.allocator, ".{s}", .{self.name[name.len..]});
            } else {
                return continueSearching();
            }
        }

        const allowJs = self.compilerOptions.allowJs orelse false;
        if (allowJs and std.mem.indexOf(u8, self.containingDirectory, "/node_modules/") == null) {
            return try self.loadModuleFromExports(scope, self.extensions, subpath);
        }

        var priorityExtensions = self.extensions;
        priorityExtensions.javaScript = false;
        priorityExtensions.json = false;

        var secondaryExtensions = self.extensions;
        secondaryExtensions.typeScript = false;
        secondaryExtensions.declaration = false;

        if (try self.loadModuleFromExports(scope, priorityExtensions, subpath)) |resolved| {
            return resolved;
        }
        return try self.loadModuleFromExports(scope, secondaryExtensions, subpath);
    }

    pub fn loadModuleFromImports(self: *ResolutionState) !?*Resolved {
        if (std.mem.eql(u8, self.name, "#") or (std.mem.startsWith(u8, self.name, "#/") and !self.features.importsPatternRoot)) {
            if (self.tracer) |t| {
                _ = t;
            }
            return continueSearching();
        }
        const directoryPath = try tspath.GetNormalizedAbsolutePath(self.allocator, self.containingDirectory, self.resolver.host.getCurrentDirectory());
        const scope = self.getPackageScopeForPath(directoryPath) orelse {
            if (self.tracer) |t| {
                _ = t;
            }
            return continueSearching();
        };
        const contents = scope.contents orelse return continueSearching();
        if (contents.fields.pathFields.imports.json_value == .NotPresent) {
            return continueSearching();
        }

        const importsObj = contents.fields.pathFields.imports.asObject();
        if (try self.loadModuleFromExportsOrImports(self.extensions, self.name, importsObj, scope, true)) |result| {
            return result;
        }
        return continueSearching();
    }

    pub fn loadModuleFromNearestNodeModulesDirectoryWorker(self: *ResolutionState, exts: types.Extensions, typesScopeOnly: bool) ?*Resolved {
        var dir = self.containingDirectory;
        while (true) {
            const baseName = tspath.getBaseFileName(dir);
            if (!std.mem.eql(u8, baseName, "node_modules")) {
                if (self.loadModuleFromImmediateNodeModulesDirectory(exts, dir, typesScopeOnly)) |res| {
                    return res;
                }
            }
            const parent = tspath.getDirectoryPath(self.allocator, dir) catch break;
            if (std.mem.eql(u8, parent, dir) or parent.len == 0) {
                break;
            }
            dir = parent;
        }
        return continueSearching();
    }

    pub fn loadModuleFromNearestNodeModulesDirectory(self: *ResolutionState, typesScopeOnly: bool) ?*Resolved {
        const priorityExtensions = types.Extensions{
            .typeScript = self.extensions.typeScript,
            .declaration = self.extensions.declaration,
        };
        const secondaryExtensions = types.Extensions{
            .javaScript = self.extensions.javaScript,
            .json = self.extensions.json,
        };

        if (priorityExtensions.typeScript or priorityExtensions.declaration) {
            if (self.loadModuleFromNearestNodeModulesDirectoryWorker(priorityExtensions, typesScopeOnly)) |result| {
                return result;
            }
        }

        if ((secondaryExtensions.javaScript or secondaryExtensions.json) and !typesScopeOnly) {
            return self.loadModuleFromNearestNodeModulesDirectoryWorker(secondaryExtensions, typesScopeOnly);
        }

        return continueSearching();
    }

    pub fn loadModuleFromImmediateNodeModulesDirectory(self: *ResolutionState, exts: types.Extensions, directory: []const u8, typesScopeOnly: bool) ?*Resolved {
        const nodeModulesFolder = tspath.combinePaths(self.allocator, directory, &[_][]const u8{"node_modules"}) catch @panic("OOM");
        if (!self.resolver.host.directoryExists(nodeModulesFolder)) {
            if (self.tracer) |t| {
                _ = t;
            }
            return continueSearching();
        }

        if (!typesScopeOnly) {
            if (self.loadModuleFromSpecificNodeModulesDirectory(exts, self.name, nodeModulesFolder) catch null) |packageResult| {
                return packageResult;
            }
        }

        if (exts.declaration) {
            const nodeModulesAtTypes = tspath.combinePaths(self.allocator, nodeModulesFolder, &[_][]const u8{"@types"}) catch @panic("OOM");
            if (!self.resolver.host.directoryExists(nodeModulesAtTypes)) {
                if (self.tracer) |t| {
                    _ = t;
                }
                return continueSearching();
            }
            const mangledName = self.mangleScopedPackageName(self.name);
            return self.loadModuleFromSpecificNodeModulesDirectory(types.Extensions.Declaration, mangledName, nodeModulesAtTypes) catch null;
        }

        return continueSearching();
    }

    pub fn loadModuleFromSpecificNodeModulesDirectory(self: *ResolutionState, exts: types.Extensions, moduleName: []const u8, nodeModulesDirectory: []const u8) anyerror!?*Resolved {
        const combined = try tspath.combinePaths(self.allocator, nodeModulesDirectory, &[_][]const u8{moduleName});
        var candidate = combined;
        if (candidate.len > 1 and candidate[candidate.len - 1] == '/') {
            candidate = candidate[0 .. candidate.len - 1];
        }

        const parsed = util.parsePackageName(moduleName);
        const packageName = parsed[0];
        const rest = parsed[1];

        var packageDirectory = try tspath.combinePaths(self.allocator, nodeModulesDirectory, &[_][]const u8{packageName});
        if (packageName.len == 0) {
            packageDirectory = candidate;
        }

        if (self.resolvePackageDirectoryOnly) {
            if (self.resolver.host.directoryExists(packageDirectory)) {
                const r = try self.allocator.create(Resolved);
                r.* = .{ .path = packageDirectory };
                return r;
            }
            return continueSearching();
        }

        var rootPackageInfo: ?*packagejson.InfoCacheEntry = null;
        const packageInfo = self.getPackageJsonInfo(candidate);
        if (rest.len > 0 and packageInfo != null and packageInfo.?.exists()) {
            if (self.features.exports) {
                rootPackageInfo = self.getPackageJsonInfo(packageDirectory);
            }
            if (rootPackageInfo == null or !rootPackageInfo.?.exists() or rootPackageInfo.?.contents == null or rootPackageInfo.?.contents.?.fields.pathFields.exports.json_value == .NotPresent) {
                if (self.loadModuleFromFile(exts, candidate)) |fromFile| {
                    return fromFile;
                }
                if (self.loadNodeModuleFromDirectoryWorker(exts, candidate, packageInfo)) |fromDirectory| {
                    return fromDirectory;
                }
            }
        }

        const loader = struct {
            state: *ResolutionState,
            packageInfo: ?*packagejson.InfoCacheEntry,
            rest: []const u8,

            pub fn load(loader_ctx: *@This(), loader_exts: types.Extensions, loader_candidate: []const u8) !?*Resolved {
                if (loader_ctx.rest.len > 0 or !loader_ctx.state.esmMode) {
                    if (loader_ctx.state.loadModuleFromFile(loader_exts, loader_candidate)) |fromFile| {
                        return fromFile;
                    }
                }
                if (loader_ctx.state.loadNodeModuleFromDirectoryWorker(loader_exts, loader_candidate, loader_ctx.packageInfo)) |fromDirectory| {
                    return fromDirectory;
                }
                if (loader_ctx.rest.len == 0 and loader_ctx.packageInfo != null and loader_ctx.packageInfo.?.exists() and loader_ctx.state.esmMode) {
                    const contents = loader_ctx.packageInfo.?.contents.?;
                    if (contents.fields.pathFields.exports.json_value == .NotPresent or contents.fields.pathFields.exports.json_value == .Null) {
                        const indexJs = try tspath.combinePaths(loader_ctx.state.allocator, loader_candidate, &[_][]const u8{"index.js"});
                        if (loader_ctx.state.loadModuleFromFile(loader_exts, indexJs)) |indexResult| {
                            return indexResult;
                        }
                    }
                }
                return continueSearching();
            }
        };

        var loader_obj = loader{
            .state = self,
            .packageInfo = packageInfo,
            .rest = rest,
        };

        var finalPackageInfo = packageInfo;
        if (rest.len > 0) {
            finalPackageInfo = rootPackageInfo;
            if (finalPackageInfo == null) {
                finalPackageInfo = self.getPackageJsonInfo(packageDirectory);
            }
        }

        if (finalPackageInfo) |info| {
            self.resolvedPackageDirectory = true;
            if (self.features.exports and info.exists() and info.contents != null and !info.contents.?.fields.pathFields.exports.json_value.isFalsy()) {
                const subpath = try std.fmt.allocPrint(self.allocator, "./{s}", .{rest});
                return try self.loadModuleFromExports(info, exts, subpath);
            }
        }

        return try loader_obj.load(exts, candidate);
    }

    pub fn resolveFromTypeRoot(self: *ResolutionState) ?*Resolved {
        _ = self;
        return continueSearching();
    }

    pub fn getPackageId(self: *ResolutionState, resolvedPath: []const u8, packageInfo: ?*packagejson.InfoCacheEntry) ?types.PackageId {
        _ = self;
        _ = resolvedPath;
        _ = packageInfo;
        return null;
    }

    pub fn mangleScopedPackageName(self: *ResolutionState, packageName: []const u8) []const u8 {
        return util.mangleScopedPackageName(self.allocator, packageName) catch @panic("OOM");
    }

    pub fn createResolvedModule(self: *ResolutionState, r: ?*Resolved, isExternalLibraryImport: bool) !*types.ResolvedModule {
        const result = try self.allocator.create(types.ResolvedModule);
        result.* = .{
            .resolutionDiagnostics = std.ArrayList(*ast.Diagnostic).init(self.allocator),
            .resolvedFileName = if (r) |res| res.path else "",
            .originalPath = if (r) |res| res.originalPath else "",
            .extension = if (r) |res| res.extension else "",
            .resolvedUsingTsExtension = if (r) |res| res.resolvedUsingTsExtension else false,
            .packageId = if (r) |res| res.packageId else null,
            .isExternalLibraryImport = isExternalLibraryImport,
        };
        return result;
    }

    pub fn createResolvedModuleHandlingSymlink(self: *ResolutionState, r: ?*Resolved) !*types.ResolvedModule {
        const isExternal = if (r) |res| std.mem.indexOf(u8, res.path, "/node_modules/") != null else false;
        return try self.createResolvedModule(r, isExternal);
    }

    pub fn tryLoadModuleUsingOptionalResolutionSettings(self: *ResolutionState) ?*Resolved {
        if (self.tryLoadModuleUsingPathsIfEligible()) |resolved| {
            return resolved;
        }
        if (!tspath.isExternalModuleNameRelative(self.name)) {
            return continueSearching();
        } else {
            return self.tryLoadModuleUsingRootDirs();
        }
    }

    pub fn tryLoadModuleUsingPathsIfEligible(self: *ResolutionState) ?*Resolved {
        const paths = self.compilerOptions.paths;
        if (paths == null or paths.?.count() == 0 or tspath.pathIsRelative(self.name)) {
            return continueSearching();
        }
        const baseDirectory = self.compilerOptions.getPathsBasePath(self.resolver.host.getCurrentDirectory());
        const pathPatterns = self.resolver.getParsedPatternsForPaths(self.compilerOptions);
        return self.tryLoadModuleUsingPaths(
            self.extensions,
            self.name,
            baseDirectory,
            paths.?,
            pathPatterns,
        );
    }

    pub fn tryLoadModuleUsingPaths(
        self: *ResolutionState,
        exts: types.Extensions,
        moduleName: []const u8,
        containingDirectory: []const u8,
        paths: core.PathsMappings,
        pathPatterns: *ParsedPatterns,
    ) ?*Resolved {
        const matchedPattern = matchPatternOrExact(pathPatterns, moduleName) orelse return continueSearching();
        const matchedStar = matchedPattern.matchedText(moduleName);
        const substitutions = paths.get(matchedPattern.text) orelse return continueSearching();
        for (substitutions) |subst| {
            const path = if (std.mem.indexOf(u8, subst, "*")) |si| blk: {
                const out = std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{ subst[0..si], matchedStar, subst[si + 1 ..] }) catch @panic("OOM");
                break :blk out;
            } else subst;
            const candidate = tspath.normalizePath(self.allocator, tspath.combinePaths(self.allocator, containingDirectory, &[_][]const u8{path}) catch @panic("OOM")) catch @panic("OOM");
            const extensionFromSubst = tspath.tryGetExtensionFromPath(subst);
            if (extensionFromSubst.len > 0) {
                const fileResult = self.tryFile(candidate);
                if (fileResult[1]) {
                    const r = self.allocator.create(Resolved) catch @panic("OOM");
                    r.* = .{ .path = fileResult[0], .extension = extensionFromSubst };
                    return r;
                }
            }
            const saveCandidateEndingIsFromConfig = self.candidateEndingIsFromConfig;
            if (extensionFromSubst.len > 0) {
                self.candidateEndingIsFromConfig = true;
            }
            const resolved = self.nodeLoadModuleByRelativeName(exts, candidate, true);
            self.candidateEndingIsFromConfig = saveCandidateEndingIsFromConfig;
            if (!Resolved.shouldContinueSearching(resolved)) {
                return resolved;
            }
        }
        return continueSearching();
    }

    pub fn tryLoadModuleUsingRootDirs(self: *ResolutionState) ?*Resolved {
        const rootDirs = self.compilerOptions.rootDirs;
        if (rootDirs == null or rootDirs.?.len == 0) {
            return continueSearching();
        }
        const combined = tspath.combinePaths(self.allocator, self.containingDirectory, &[_][]const u8{self.name}) catch @panic("OOM");
        const candidate = tspath.normalizePath(self.allocator, combined) catch @panic("OOM");

        var matchedRootDir: []const u8 = "";
        var matchedNormalizedPrefix: []const u8 = "";
        for (rootDirs.?) |rootDir| {
            var normalizedRoot = tspath.normalizePath(self.allocator, rootDir) catch @panic("OOM");
            if (!std.mem.endsWith(u8, normalizedRoot, "/")) {
                normalizedRoot = std.fmt.allocPrint(self.allocator, "{s}/", .{normalizedRoot}) catch @panic("OOM");
            }
            const isLongestMatchingPrefix = std.mem.startsWith(u8, candidate, normalizedRoot) and
                (matchedNormalizedPrefix.len == 0 or matchedNormalizedPrefix.len < normalizedRoot.len);
            if (isLongestMatchingPrefix) {
                matchedNormalizedPrefix = normalizedRoot;
                matchedRootDir = rootDir;
            }
        }

        if (matchedNormalizedPrefix.len > 0) {
            const suffix = candidate[matchedNormalizedPrefix.len..];
            if (self.nodeLoadModuleByRelativeName(self.extensions, candidate, true)) |res| {
                return res;
            }
            for (rootDirs.?) |rootDir| {
                if (std.mem.eql(u8, rootDir, matchedRootDir)) {
                    continue;
                }
                const normalizedRoot = tspath.normalizePath(self.allocator, rootDir) catch @panic("OOM");
                const altCandidate = tspath.combinePaths(self.allocator, normalizedRoot, &[_][]const u8{suffix}) catch @panic("OOM");
                if (self.nodeLoadModuleByRelativeName(self.extensions, altCandidate, true)) |res| {
                    return res;
                }
            }
        }
        return continueSearching();
    }

    pub fn resolveNodeLike(self: *ResolutionState) !*types.ResolvedModule {
        if (self.tracer) |t| {
            _ = t;
        }
        const result = try self.resolveNodeLikeWorker();
        return result;
    }

    pub fn resolveNodeLikeWorker(self: *ResolutionState) !*types.ResolvedModule {
        if (self.tryLoadModuleUsingOptionalResolutionSettings()) |resolved| {
            return try self.createResolvedModuleHandlingSymlink(resolved);
        }

        if (!tspath.isExternalModuleNameRelative(self.name)) {
            if (self.features.imports and std.mem.startsWith(u8, self.name, "#")) {
                if (try self.loadModuleFromImports()) |resolved| {
                    return try self.createResolvedModuleHandlingSymlink(resolved);
                }
            }
            if (self.features.selfName) {
                if (try self.loadModuleFromSelfNameReference()) |resolved| {
                    return try self.createResolvedModuleHandlingSymlink(resolved);
                }
            }
            if (std.mem.indexOfScalar(u8, self.name, ':') != null) {
                if (self.tracer) |t| {
                    _ = t;
                }
                return try self.createResolvedModule(null, false);
            }
            if (self.tracer) |t| {
                _ = t;
            }
            if (self.loadModuleFromNearestNodeModulesDirectory(false)) |resolved| {
                return try self.createResolvedModuleHandlingSymlink(resolved);
            }
            if (self.extensions.declaration) {
                if (self.resolveFromTypeRoot()) |resolved| {
                    return try self.createResolvedModuleHandlingSymlink(resolved);
                }
            }
        } else {
            const candidate = try normalizePathForCJSResolution(self.allocator, self.containingDirectory, self.name);
            const resolved = self.nodeLoadModuleByRelativeName(self.extensions, candidate, true);
            const isExternal = if (resolved) |res| std.mem.indexOf(u8, res.path, "/node_modules/") != null else false;
            return try self.createResolvedModule(resolved, isExternal);
        }
        return try self.createResolvedModule(null, false);
    }

    pub fn resolveTypeReferenceDirective(self: *ResolutionState, typeRoots: [][]const u8, fromConfig: bool, fromInferredTypesContainingFile: bool) !*types.ResolvedTypeReferenceDirective {
        _ = typeRoots;
        _ = fromConfig;
        _ = fromInferredTypesContainingFile;
        const result = try self.allocator.create(types.ResolvedTypeReferenceDirective);
        result.* = .{
            .resolutionDiagnostics = std.ArrayList(*ast.Diagnostic).init(self.allocator),
        };
        return result;
    }
};

pub const Pattern = struct {
    text: []const u8,
    starIndex: i32, // -1 for exact match

    pub fn isValid(self: Pattern) bool {
        return self.starIndex == -1 or @as(usize, @intCast(self.starIndex)) < self.text.len;
    }

    pub fn matches(self: Pattern, candidate: []const u8) bool {
        if (self.starIndex == -1) {
            return std.mem.eql(u8, self.text, candidate);
        }
        const si = @as(usize, @intCast(self.starIndex));
        const prefix = self.text[0..si];
        const suffix = self.text[si + 1 ..];
        return candidate.len >= self.text.len - 1 and
            std.mem.startsWith(u8, candidate, prefix) and
            std.mem.endsWith(u8, candidate, suffix);
    }

    pub fn matchedText(self: Pattern, candidate: []const u8) []const u8 {
        if (self.starIndex == -1) return "";
        const si = @as(usize, @intCast(self.starIndex));
        const suffix = self.text[si + 1 ..];
        return candidate[si .. candidate.len - suffix.len];
    }
};

pub const ParsedPatterns = struct {
    matchableStringSet: std.StringHashMap(void),
    patterns: std.ArrayList(Pattern),

    pub fn init(allocator: std.mem.Allocator) ParsedPatterns {
        return .{
            .matchableStringSet = std.StringHashMap(void).init(allocator),
            .patterns = std.ArrayList(Pattern).init(allocator),
        };
    }
};

pub fn tryParsePatterns(allocator: std.mem.Allocator, pathMappings: *const core.PathsMappings) !*ParsedPatterns {
    var result = try allocator.create(ParsedPatterns);
    result.* = ParsedPatterns.init(allocator);
    var it = pathMappings.iterator();
    while (it.next()) |entry| {
        const path = entry.key_ptr.*;
        const starIdx = std.mem.indexOfScalar(u8, path, '*');
        const hasMultipleStar = if (starIdx) |si| std.mem.indexOfScalar(u8, path[si + 1 ..], '*') != null else false;
        if (hasMultipleStar) continue; // invalid pattern - more than one star
        const pat = Pattern{ .text = path, .starIndex = if (starIdx) |si| @as(i32, @intCast(si)) else -1 };
        if (!pat.isValid()) continue;
        if (starIdx == null) {
            // exact match - goes into string set
            try result.matchableStringSet.put(path, {});
        } else {
            try result.patterns.append(pat);
        }
    }
    return result;
}

pub fn matchPatternOrExact(patterns: *const ParsedPatterns, candidate: []const u8) ?Pattern {
    if (patterns.matchableStringSet.get(candidate) != null) {
        return Pattern{ .text = candidate, .starIndex = -1 };
    }
    var best: ?Pattern = null;
    var bestLen: i32 = -1;
    for (patterns.patterns.items) |pat| {
        if (pat.isValid() and (pat.starIndex == -1 or pat.starIndex > bestLen) and pat.matches(candidate)) {
            best = pat;
            bestLen = pat.starIndex;
        }
    }
    return best;
}

pub const ResolutionHost = struct {
    ptr: *anyopaque,
    getCurrentDirectoryFn: *const fn (*anyopaque) []const u8,
    useCaseSensitiveFileNamesFn: *const fn (*anyopaque) bool,
    fileExistsFn: ?*const fn (ptr: *anyopaque, path: []const u8) bool = null,
    directoryExistsFn: ?*const fn (ptr: *anyopaque, path: []const u8) bool = null,
    readFileFn: ?*const fn (ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) ?[]const u8 = null,

    pub fn getCurrentDirectory(self: ResolutionHost) []const u8 {
        return self.getCurrentDirectoryFn(self.ptr);
    }

    pub fn useCaseSensitiveFileNames(self: ResolutionHost) bool {
        return self.useCaseSensitiveFileNamesFn(self.ptr);
    }

    pub fn fileExists(self: ResolutionHost, path: []const u8) bool {
        if (self.fileExistsFn) |f| {
            return f(self.ptr, path);
        }
        const file = std.fs.cwd().openFile(path, .{}) catch return false;
        file.close();
        return true;
    }

    pub fn directoryExists(self: ResolutionHost, path: []const u8) bool {
        if (self.directoryExistsFn) |f| {
            return f(self.ptr, path);
        }
        var dir = std.fs.cwd().openDir(path, .{}) catch return false;
        dir.close();
        return true;
    }

    pub fn readFile(self: ResolutionHost, allocator: std.mem.Allocator, path: []const u8) ?[]const u8 {
        if (self.readFileFn) |f| {
            return f(self.ptr, allocator, path);
        }
        return std.fs.cwd().readFileAlloc(allocator, path, std.math.maxInt(usize)) catch return null;
    }
};

pub const Resolver = struct {
    allocator: std.mem.Allocator,
    host: ResolutionHost,
    compilerOptions: *core.CompilerOptions,
    typingsLocation: []const u8,
    projectName: []const u8,
    caches: cache.Caches,
    parsedPatternsForPaths: ?*ParsedPatterns = null,

    pub fn init(
        allocator: std.mem.Allocator,
        host: ResolutionHost,
        options: *core.CompilerOptions,
        typingsLocation: []const u8,
        projectName: []const u8,
    ) !*Resolver {
        const resolver = try allocator.create(Resolver);
        resolver.* = .{
            .allocator = allocator,
            .host = host,
            .compilerOptions = options,
            .typingsLocation = typingsLocation,
            .projectName = projectName,
            .caches = try cache.Caches.init(allocator, host.getCurrentDirectory(), host.useCaseSensitiveFileNames(), options),
        };
        return resolver;
    }

    pub fn newTraceBuilder(self: *Resolver) ?*Tracer {
        if (self.compilerOptions.traceResolution == true) {
            const t = self.allocator.create(Tracer) catch @panic("OOM");
            t.* = Tracer.init(self.allocator);
            return t;
        }
        return null;
    }

    pub fn getParsedPatternsForPaths(self: *Resolver, compilerOptions: *const core.CompilerOptions) *ParsedPatterns {
        // Use cached version if it's for the same options
        if (self.parsedPatternsForPaths != null and compilerOptions == self.compilerOptions) {
            return self.parsedPatternsForPaths.?;
        }
        const paths = compilerOptions.paths orelse {
            // Return an empty ParsedPatterns
            const empty = self.allocator.create(ParsedPatterns) catch @panic("OOM");
            empty.* = ParsedPatterns.init(self.allocator);
            if (compilerOptions == self.compilerOptions) {
                self.parsedPatternsForPaths = empty;
            }
            return empty;
        };
        const result = tryParsePatterns(self.allocator, paths) catch @panic("OOM");
        if (compilerOptions == self.compilerOptions) {
            self.parsedPatternsForPaths = result;
        }
        return result;
    }

    pub fn resolveTypeReferenceDirective(
        self: *Resolver,
        typeReferenceDirectiveName: []const u8,
        containingFile: []const u8,
        resolutionMode: core.ResolutionMode,
    ) !struct { *types.ResolvedTypeReferenceDirective, []DiagAndArgs } {
        const containingDirectory = tspath.getDirectoryPath(containingFile);
        const traceBuilder = self.newTraceBuilder();

        const fromInferredTypesContainingFile = std.mem.endsWith(u8, containingFile, "__inferred type names__.ts");

        const cacheKey = cache.TypeRefDirectiveResolutionCacheKey{
            .containingDirectory = containingDirectory,
            .typeReferenceName = typeReferenceDirectiveName,
            .resolutionMode = resolutionMode,
            .redirectConfigName = "",
            .fromInferredTypesContainingFile = fromInferredTypesContainingFile,
        };

        if (traceBuilder == null) {
            if (self.caches.typeRefDirectiveResolutionCache.get(cacheKey)) |cached| {
                return .{ cached, &[_]DiagAndArgs{} };
            }
        }

        const typeRoots = &[_][]const u8{};
        const fromConfig = false;

        var state = try ResolutionState.init(
            self.allocator,
            typeReferenceDirectiveName,
            containingDirectory,
            true,
            resolutionMode,
            self.compilerOptions,
            self,
            traceBuilder,
        );

        const result = try state.resolveTypeReferenceDirective(typeRoots, fromConfig, fromInferredTypesContainingFile);

        if (traceBuilder) |tb| {
            tb.traceTypeReferenceDirectiveResult(typeReferenceDirectiveName, result);
        }

        try self.caches.typeRefDirectiveResolutionCache.set(cacheKey, result);

        return .{ result, if (traceBuilder) |tb| tb.getTraces() else &[_]DiagAndArgs{} };
    }

    pub fn resolveModuleName(
        self: *Resolver,
        moduleName: []const u8,
        containingFile: []const u8,
        resolutionMode: core.ResolutionMode,
    ) !struct { *types.ResolvedModule, []DiagAndArgs } {
        const containingDirectory = tspath.getDirectoryPath(containingFile);
        const traceBuilder = self.newTraceBuilder();

        const cacheKey = cache.ModuleResolutionCacheKey{
            .containingDirectory = containingDirectory,
            .moduleName = moduleName,
            .resolutionMode = resolutionMode,
            .redirectConfigName = "",
        };

        if (traceBuilder == null) {
            if (self.caches.moduleResolutionCache.get(cacheKey)) |cached| {
                return .{ cached, &[_]DiagAndArgs{} };
            }
        }

        const moduleResolution = self.compilerOptions.moduleResolution orelse .Node10;

        var result: *types.ResolvedModule = undefined;
        switch (moduleResolution) {
            .Node16, .NodeNext, .Bundler => {
                var state = try ResolutionState.init(
                    self.allocator,
                    moduleName,
                    containingDirectory,
                    false,
                    resolutionMode,
                    self.compilerOptions,
                    self,
                    traceBuilder,
                );
                result = try state.resolveNodeLike();
            },
            else => {
                @panic("Unexpected moduleResolution");
            },
        }

        const finalResult = try self.tryResolveFromTypingsLocation(moduleName, containingDirectory, result, traceBuilder);
        try self.caches.moduleResolutionCache.set(cacheKey, finalResult);

        return .{ finalResult, if (traceBuilder) |tb| tb.getTraces() else &[_]DiagAndArgs{} };
    }

    pub fn tryResolveFromTypingsLocation(
        self: *Resolver,
        moduleName: []const u8,
        containingDirectory: []const u8,
        originalResult: *types.ResolvedModule,
        traceBuilder: ?*Tracer,
    ) !*types.ResolvedModule {
        if (self.typingsLocation.len == 0 or
            tspath.isExternalModuleNameRelative(moduleName) or
            (originalResult.resolvedFileName.len > 0 and tspath.extensionIsOneOf(originalResult.extension, tspath.SupportedTSExtensionsWithJsonFlat)))
        {
            return originalResult;
        }

        var state = try ResolutionState.init(
            self.allocator,
            moduleName,
            containingDirectory,
            false,
            .None,
            self.compilerOptions,
            self,
            traceBuilder,
        );

        if (state.loadModuleFromImmediateNodeModulesDirectory(types.Extensions.Declaration, self.typingsLocation, false)) |globalResolved| {
            var result = try state.createResolvedModule(globalResolved, true);
            try result.resolutionDiagnostics.appendSlice(originalResult.resolutionDiagnostics.items);
            return result;
        }

        return originalResult;
    }

    pub fn resolveConfig(self: *Resolver, moduleName: []const u8, containingFile: []const u8) !*types.ResolvedModule {
        const containingDirectory = tspath.getDirectoryPath(containingFile);
        var state = try ResolutionState.init(
            self.allocator,
            moduleName,
            containingDirectory,
            false,
            .CommonJS,
            self.compilerOptions,
            self,
            null,
        );
        state.isConfigLookup = true;
        state.extensions = types.Extensions.Json;
        return try state.resolveNodeLike();
    }
};

fn matchesPatternWithTrailer(target: []const u8, name: []const u8) bool {
    if (std.mem.endsWith(u8, target, "*")) {
        return false;
    }
    const starIdx = std.mem.indexOfScalar(u8, target, '*');
    if (starIdx == null) {
        return false;
    }
    const idx = starIdx.?;
    const prefix = target[0..idx];
    const suffix = target[idx + 1 ..];
    return std.mem.startsWith(u8, name, prefix) and std.mem.endsWith(u8, name, suffix);
}

pub fn normalizePathForCJSResolution(allocator: std.mem.Allocator, containingDirectory: []const u8, moduleName: []const u8) ![]const u8 {
    const combined = try tspath.combinePaths(allocator, containingDirectory, &[_][]const u8{moduleName});
    if (std.mem.endsWith(u8, combined, "/.") or
        std.mem.endsWith(u8, combined, "/..") or
        std.mem.eql(u8, combined, ".") or
        std.mem.eql(u8, combined, ".."))
    {
        if (combined.len > 0 and combined[combined.len - 1] == '/') {
            return combined;
        }
        return try std.fmt.allocPrint(allocator, "{s}/", .{combined});
    }
    return combined;
}
