const std = @import("std");
const ast = @import("../../ast/ast.zig");
const binder = @import("../../binder/binder.zig");
const checker = @import("../../checker/checker.zig");
const core = @import("../../core/core.zig");
const module = @import("../../module/module.zig");
const packagejson = @import("../../packagejson/packagejson.zig");
const symlinks = @import("../../symlinks/knownsymlinks.zig");
const tsoptions = @import("../../tsoptions/tsoptions.zig");
const tspath = @import("../../tspath/tspath.zig");
const module_types = @import("../../module/types.zig");

pub const PathAndFileName = struct {
    path: tspath.Path,
    fileName: []const u8,
};

pub const AliasResolverHost = struct {
    ptr: *anyopaque,
    getCurrentDirectoryFn: *const fn (ptr: *anyopaque) []const u8,
    useCaseSensitiveFileNamesFn: *const fn (ptr: *anyopaque) bool,
    getSourceFileFn: *const fn (ptr: *anyopaque, fileName: []const u8, path: tspath.Path) ?ast.NodeIndex,

    pub fn getCurrentDirectory(self: AliasResolverHost) []const u8 {
        return self.getCurrentDirectoryFn(self.ptr);
    }

    pub fn useCaseSensitiveFileNames(self: AliasResolverHost) bool {
        return self.useCaseSensitiveFileNamesFn(self.ptr);
    }

    pub fn getSourceFile(self: AliasResolverHost, fileName: []const u8, path: tspath.Path) ?ast.NodeIndex {
        return self.getSourceFileFn(self.ptr, fileName, path);
    }
};

pub const AliasResolver = struct {
    allocator: std.mem.Allocator,
    toPath: *const fn (fileName: []const u8) tspath.Path,
    host: AliasResolverHost,
    moduleResolver: *module.Resolver,

    rootFiles: std.ArrayListUnmanaged(ast.NodeIndex),
    symlinks: std.StringHashMapUnmanaged(PathAndFileName),
    onFailedAmbientModuleLookup: *const fn (source: ast.NodeIndex, moduleName: []const u8) void,

    pub fn init(
        allocator: std.mem.Allocator,
        rootFiles: []const ast.NodeIndex,
        symlinkMap: ?std.StringHashMapUnmanaged(PathAndFileName),
        host: AliasResolverHost,
        moduleResolver: *module.Resolver,
        toPath: *const fn (fileName: []const u8) tspath.Path,
        onFailedAmbientModuleLookup: *const fn (source: ast.NodeIndex, moduleName: []const u8) void,
    ) !*AliasResolver {
        const r = try allocator.create(AliasResolver);
        var rootList = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        try rootList.appendSlice(allocator, rootFiles);
        
        r.* = .{
            .allocator = allocator,
            .toPath = toPath,
            .host = host,
            .moduleResolver = moduleResolver,
            .rootFiles = rootList,
            .symlinks = symlinkMap orelse std.StringHashMapUnmanaged(PathAndFileName).empty,
            .onFailedAmbientModuleLookup = onFailedAmbientModuleLookup,
        };
        return r;
    }

    pub fn bindSourceFiles(self: *AliasResolver) void {
        _ = self;
    }

    pub fn getSourceFiles(self: *AliasResolver) []const ast.NodeIndex {
        return self.rootFiles.items;
    }

    pub fn getOptions(self: *AliasResolver) !*core.CompilerOptions {
        const opts = try self.allocator.create(core.CompilerOptions);
        opts.* = .{
            .noCheck = true,
        };
        return opts;
    }

    pub fn getCurrentDirectory(self: *AliasResolver) []const u8 {
        return self.host.getCurrentDirectory();
    }

    pub fn useCaseSensitiveFileNames(self: *AliasResolver) bool {
        return self.host.useCaseSensitiveFileNames();
    }

    pub fn getSourceFile(self: *AliasResolver, fileName: []const u8) ?ast.NodeIndex {
        const path = self.toPath(fileName);
        const file = self.host.getSourceFile(fileName, path);
        if (file) |f| {
            // binder.bindSourceFile(file) logic depends on implementation details
            return f;
        }
        return null;
    }

    pub fn getDefaultResolutionModeForFile(self: *AliasResolver, file: ast.NodeIndex) core.ModuleKind {
        _ = self;
        _ = file;
        return .ESNext;
    }

    pub fn getEmitModuleFormatOfFile(self: *AliasResolver, sourceFile: ast.NodeIndex) core.ModuleKind {
        _ = self;
        _ = sourceFile;
        return .ESNext;
    }

    pub fn getEmitSyntaxForUsageLocation(self: *AliasResolver, sourceFile: ast.NodeIndex, usageLocation: ast.NodeIndex) core.ModuleKind {
        _ = self;
        _ = sourceFile;
        _ = usageLocation;
        return .ESNext;
    }

    pub fn getImpliedNodeFormatForEmit(self: *AliasResolver, sourceFile: ast.NodeIndex) core.ModuleKind {
        _ = self;
        _ = sourceFile;
        return .ESNext;
    }

    pub fn getModeForUsageLocation(self: *AliasResolver, file: ast.NodeIndex, moduleSpecifier: ast.NodeIndex) core.ModuleKind {
        _ = self;
        _ = file;
        _ = moduleSpecifier;
        return .ESNext;
    }

    pub fn getResolvedModule(self: *AliasResolver, currentSourceFile: ast.NodeIndex, moduleReference: []const u8, mode: core.ModuleKind) ?*module.Resolved {
        _ = self;
        _ = currentSourceFile;
        _ = moduleReference;
        _ = mode;
        @panic("unimplemented");
    }

    pub fn getSourceFileForResolvedModule(self: *AliasResolver, fileName: []const u8) ?ast.NodeIndex {
        return self.getSourceFile(fileName);
    }

    pub fn getResolvedModules(self: *AliasResolver) void {
        _ = self;
    }

    pub fn getSymlinkCache(self: *AliasResolver) *symlinks.KnownSymlinks {
        _ = self;
        @panic("unimplemented");
    }

    pub fn getSourceFileMetaData(self: *AliasResolver, path: tspath.Path) void {
        _ = self;
        _ = path;
        @panic("unimplemented");
    }

    pub fn commonSourceDirectory(self: *AliasResolver) []const u8 {
        _ = self;
        @panic("unimplemented");
    }

    pub fn fileExists(self: *AliasResolver, fileName: []const u8) bool {
        _ = self;
        _ = fileName;
        @panic("unimplemented");
    }

    pub fn getGlobalTypingsCacheLocation(self: *AliasResolver) []const u8 {
        _ = self;
        @panic("unimplemented");
    }

    pub fn getImportHelpersImportSpecifier(self: *AliasResolver, path: tspath.Path) ast.NodeIndex {
        _ = self;
        _ = path;
        @panic("unimplemented");
    }

    pub fn getJSXRuntimeImportSpecifier(self: *AliasResolver, path: tspath.Path) void {
        _ = self;
        _ = path;
        @panic("unimplemented");
    }

    pub fn getNearestAncestorDirectoryWithPackageJson(self: *AliasResolver, dirname: []const u8) []const u8 {
        _ = self;
        _ = dirname;
        @panic("unimplemented");
    }

    pub fn getPackageJsonInfo(self: *AliasResolver, pkgJsonPath: []const u8) *packagejson.InfoCacheEntry {
        _ = self;
        _ = pkgJsonPath;
        @panic("unimplemented");
    }

    pub fn getProjectReferenceFromOutputDts(self: *AliasResolver, path: tspath.Path) *tsoptions.SourceOutputAndProjectReference {
        _ = self;
        _ = path;
        @panic("unimplemented");
    }

    pub fn getProjectReferenceFromSource(self: *AliasResolver, path: tspath.Path) *tsoptions.SourceOutputAndProjectReference {
        _ = self;
        _ = path;
        @panic("unimplemented");
    }

    pub fn getRedirectForResolution(self: *AliasResolver, file: ast.NodeIndex) *tsoptions.ParsedCommandLine {
        _ = self;
        _ = file;
        @panic("unimplemented");
    }

    pub fn getRedirectTargets(self: *AliasResolver, path: tspath.Path) [][]const u8 {
        _ = self;
        _ = path;
        @panic("unimplemented");
    }

    pub fn getResolvedModuleFromModuleSpecifier(self: *AliasResolver, file: ast.NodeIndex, moduleSpecifier: ast.NodeIndex) *module.Resolved {
        _ = self;
        _ = file;
        _ = moduleSpecifier;
        @panic("unimplemented");
    }

    pub fn getSourceOfProjectReferenceIfOutputIncluded(self: *AliasResolver, file: ast.NodeIndex) []const u8 {
        _ = self;
        _ = file;
        @panic("unimplemented");
    }

    pub fn isSourceFileDefaultLibrary(self: *AliasResolver, path: tspath.Path) bool {
        _ = self;
        _ = path;
        return false;
    }

    pub fn isSourceFromProjectReference(self: *AliasResolver, path: tspath.Path) bool {
        _ = self;
        _ = path;
        @panic("unimplemented");
    }

    pub fn sourceFileMayBeEmitted(self: *AliasResolver, sourceFile: ast.NodeIndex, forceDtsEmit: bool) bool {
        _ = self;
        _ = sourceFile;
        _ = forceDtsEmit;
        @panic("unimplemented");
    }

    pub fn getPackagesMap(self: *AliasResolver) void {
        _ = self;
    }
};
