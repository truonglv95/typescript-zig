const std = @import("std");
const ast = @import("../ast/ast.zig");
const core = @import("../core/core.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const packagejson = @import("../packagejson/packagejson.zig");
const tspath = @import("../tspath/tspath.zig");
const types = @import("types.zig");
const cache = @import("cache.zig");

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
    message: *diagnostics.Message,
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

    pub fn write(self: *Tracer, diag: *diagnostics.Message, args: [][]const u8) void {
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

    pub fn resolveTypeReferenceDirective(self: *ResolutionState, typeRoots: [][]const u8, fromConfig: bool, fromInferredTypesContainingFile: bool) !*types.ResolvedTypeReferenceDirective {
        _ = typeRoots;
        _ = fromConfig;
        _ = fromInferredTypesContainingFile;
        // mock implementation
        const result = try self.allocator.create(types.ResolvedTypeReferenceDirective);
        result.* = .{
            .resolutionDiagnostics = std.ArrayList(*ast.Diagnostic).init(self.allocator),
        };
        return result;
    }

    pub fn resolveNodeLike(self: *ResolutionState) !*types.ResolvedModule {
        // mock implementation
        const result = try self.allocator.create(types.ResolvedModule);
        result.* = .{
            .resolutionDiagnostics = std.ArrayList(*ast.Diagnostic).init(self.allocator),
        };
        return result;
    }

    pub fn loadModuleFromImmediateNodeModulesDirectory(self: *ResolutionState, exts: types.Extensions, typingsLocation: []const u8, typesScopeOnly: bool) ?*Resolved {
        _ = self;
        _ = exts;
        _ = typingsLocation;
        _ = typesScopeOnly;
        // mock
        return null;
    }

    pub fn createResolvedModule(self: *ResolutionState, r: *Resolved, isExternalLibraryImport: bool) !*types.ResolvedModule {
        _ = self;
        _ = r;
        _ = isExternalLibraryImport;
        // mock
        return undefined;
    }
};

pub const ResolutionHost = struct {
    ptr: *anyopaque,
    getCurrentDirectoryFn: *const fn (*anyopaque) []const u8,
    useCaseSensitiveFileNamesFn: *const fn (*anyopaque) bool,

    pub fn getCurrentDirectory(self: ResolutionHost) []const u8 {
        return self.getCurrentDirectoryFn(self.ptr);
    }

    pub fn useCaseSensitiveFileNames(self: ResolutionHost) bool {
        return self.useCaseSensitiveFileNamesFn(self.ptr);
    }
};

pub const Resolver = struct {
    allocator: std.mem.Allocator,
    host: ResolutionHost,
    compilerOptions: *core.CompilerOptions,
    typingsLocation: []const u8,
    projectName: []const u8,
    caches: cache.Caches,

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
        if (self.compilerOptions.traceResolution == .True) {
            const t = self.allocator.create(Tracer) catch @panic("OOM");
            t.* = Tracer.init(self.allocator);
            return t;
        }
        return null;
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
