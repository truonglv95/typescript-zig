const std = @import("std");
const ast = @import("../../ast/ast.zig");
const binder = @import("../../binder/binder.zig");
const checker = @import("../../checker/checker.zig");
const collections = @import("../../collections/collections.zig");
const compiler = @import("../../compiler/program.zig");
const core = @import("../../core/core.zig");
const lsconv = @import("../lsconv.zig");
const lsutil = @import("../lsutil/lsutil.zig");
const lsproto = @import("../../lsp/lsproto/lsproto.zig");
const module_pkg = @import("../../module/module.zig");
const packagejson = @import("../../packagejson/packagejson.zig");
const dirty = @import("../../project/dirty/map.zig");
const logging = @import("../../project/logging/logtree.zig");
const symlinks = @import("../../symlinks/knownsymlinks.zig");
const tspath = @import("../../tspath/tspath.zig");
const vfs = @import("../../vfs/vfs.zig");
const vfsmatch = @import("../../vfs/vfsmatch.zig");

// Note: Ensure DoD compliance.
// Use flat structures and indices over pointers.

pub const knownRecursiveSearchPackages = std.StaticStringMap(void).initComptime(.{
    .{ "@material-ui/core", {} },
    .{ "@material-ui/icons", {} },
    .{ "@sap/cds", {} },
    .{ "@testing-library/react-native", {} },
    .{ "ajv", {} },
    .{ "asap", {} },
    .{ "async", {} },
    .{ "aws-sdk", {} },
    .{ "braintree-web", {} },
    .{ "core-js", {} },
    .{ "core-js-pure", {} },
    .{ "crypto-js", {} },
    .{ "cypress-mochawesome-reporter", {} },
    .{ "dd-trace", {} },
    .{ "dumi", {} },
    .{ "dva", {} },
    .{ "egg-mock", {} },
    .{ "electron-log", {} },
    .{ "es-abstract", {} },
    .{ "es6-promise", {} },
    .{ "eslint-config-taro", {} },
    .{ "expo", {} },
    .{ "expo-router", {} },
    .{ "flow-remove-types", {} },
    .{ "gatsby", {} },
    .{ "glamor", {} },
    .{ "gluegun", {} },
    .{ "graphology-indices", {} },
    .{ "graphology-traversal", {} },
    .{ "graphology-utils", {} },
    .{ "jest-expo", {} },
    .{ "lodash", {} },
    .{ "lodash-es", {} },
    .{ "moment", {} },
    .{ "mz", {} },
    .{ "next", {} },
    .{ "pdfjs-dist", {} },
    .{ "protobufjs", {} },
    .{ "react-app-polyfill", {} },
    .{ "react-dev-utils", {} },
    .{ "react-devtools-inline", {} },
    .{ "recast", {} },
    .{ "semver", {} },
    .{ "stylelint-config-html", {} },
    .{ "umi", {} },
    .{ "web3-provider-engine", {} },
    .{ "webpack", {} },
});

pub const NewProgramStructure = enum(u8) {
    false_ = 0,
    same_file_names = 1,
    different_file_names = 2,
};

pub const BucketBuildPreferences = struct {
    fileExcludePatterns: [][]const u8,
    autoImportEntrypointDirectorySearch: core.Tristate,

    pub fn fromUserPreferences(prefs: lsutil.UserPreferences) BucketBuildPreferences {
        return .{
            .fileExcludePatterns = prefs.autoImportFileExcludePatterns,
            .autoImportEntrypointDirectorySearch = prefs.autoImportEntrypointDirectorySearch,
        };
    }

    pub fn eql(self: BucketBuildPreferences, other: BucketBuildPreferences) bool {
        return core.unorderedEqual([]const u8, self.fileExcludePatterns, other.fileExcludePatterns) and
            self.autoImportEntrypointDirectorySearch == other.autoImportEntrypointDirectorySearch;
    }

    pub fn clone(self: BucketBuildPreferences, allocator: std.mem.Allocator) !BucketBuildPreferences {
        const cloned_patterns = try allocator.alloc([]const u8, self.fileExcludePatterns.len);
        @memcpy(cloned_patterns, self.fileExcludePatterns);
        return .{
            .fileExcludePatterns = cloned_patterns,
            .autoImportEntrypointDirectorySearch = self.autoImportEntrypointDirectorySearch,
        };
    }
};

pub const BucketState = struct {
    dirtyFile: tspath.Path,
    multipleFilesDirty: bool,
    newProgramStructure: NewProgramStructure,
    buildPreferences: BucketBuildPreferences,
    dirtyPackages: ?*collections.Set([]const u8),
    recursiveSearchPackages: ?*collections.Set([]const u8),

    pub fn dirty(self: BucketState) bool {
        return self.dirtyFile.len > 0 or self.multipleFilesDirty;
    }

    pub fn clone(self: BucketState, allocator: std.mem.Allocator) !BucketState {
        const cloned_prefs = try self.buildPreferences.clone(allocator);
        const cloned_dirty = if (self.dirtyPackages) |dp| try dp.clone(allocator) else null;
        const cloned_recursive = if (self.recursiveSearchPackages) |rp| try rp.clone(allocator) else null;
        return .{
            .dirtyFile = self.dirtyFile,
            .multipleFilesDirty = self.multipleFilesDirty,
            .newProgramStructure = self.newProgramStructure,
            .buildPreferences = cloned_prefs,
            .dirtyPackages = cloned_dirty,
            .recursiveSearchPackages = cloned_recursive,
        };
    }

    pub fn isDirty(self: BucketState) bool {
        return self.multipleFilesDirty or self.dirtyFile.len > 0 or @intFromEnum(self.newProgramStructure) > 0 or (self.dirtyPackages != null and self.dirtyPackages.?.len() > 0);
    }

    pub fn getDirtyFile(self: BucketState) tspath.Path {
        if (self.multipleFilesDirty) {
            return "";
        }
        return self.dirtyFile;
    }

    pub fn getDirtyPackages(self: BucketState) ?*collections.Set([]const u8) {
        if (self.multipleFilesDirty) {
            return null;
        }
        return self.dirtyPackages;
    }

    pub fn possiblyNeedsRebuildForFile(self: BucketState, file: tspath.Path, preferences: lsutil.UserPreferences) bool {
        return @intFromEnum(self.newProgramStructure) > 0 or
            self.hasDirtyFileBesides(file) or
            !self.buildPreferences.eql(BucketBuildPreferences.fromUserPreferences(preferences)) or
            (self.dirtyPackages != null and self.dirtyPackages.?.*.count() > 0);
    }

    pub fn hasDirtyFileBesides(self: BucketState, file: tspath.Path) bool {
        return self.multipleFilesDirty or (self.dirtyFile.len > 0 and !std.mem.eql(u8, self.dirtyFile, file));
    }
};

pub fn recursiveSearchSubset(target: ?*collections.Set([]const u8), current: ?*collections.Set([]const u8)) bool {
    if (target == null) {
        return current == null;
    }
    if (current == null) {
        return true;
    }
    return target.?.isSubsetOf(current.?);
}

pub const Index = opaque {};
pub const Export = opaque {};

pub const RegistryBucket = struct {
    state: BucketState,
    Paths: std.StringHashMap([]const u8),
    PackageFiles: std.StringHashMap(std.StringHashMap([]const u8)),
    ResolvedPackageNames: ?*collections.Set([]const u8),
    DependencyNames: ?*collections.Set([]const u8),
    AmbientModuleNames: std.StringHashMap([][]const u8),
    Index: ?*Index,

    pub fn init(allocator: std.mem.Allocator) !*RegistryBucket {
        const bucket = try allocator.create(RegistryBucket);
        bucket.* = .{
            .state = .{
                .dirtyFile = "",
                .multipleFilesDirty = true,
                .newProgramStructure = .different_file_names,
                .buildPreferences = .{
                    .fileExcludePatterns = &[_][]const u8{},
                    .autoImportEntrypointDirectorySearch = .unknown,
                },
                .dirtyPackages = null,
                .recursiveSearchPackages = null,
            },
            .Paths = std.StringHashMap([]const u8).init(allocator),
            .PackageFiles = std.StringHashMap(std.StringHashMap([]const u8)).init(allocator),
            .ResolvedPackageNames = null,
            .DependencyNames = null,
            .AmbientModuleNames = std.StringHashMap([][]const u8).init(allocator),
            .Index = null,
        };
        return bucket;
    }

    pub fn clone(self: *RegistryBucket, allocator: std.mem.Allocator) !*RegistryBucket {
        const bucket = try allocator.create(RegistryBucket);
        bucket.* = .{
            .state = try self.state.clone(allocator),
            .Paths = try self.Paths.clone(),
            .PackageFiles = try self.PackageFiles.clone(), // note: shallow clone of inner map
            .ResolvedPackageNames = self.ResolvedPackageNames,
            .DependencyNames = self.DependencyNames,
            .AmbientModuleNames = try self.AmbientModuleNames.clone(),
            .Index = self.Index,
        };
        return bucket;
    }

    pub fn markProjectFileDirty(self: *RegistryBucket, file: tspath.Path) void {
        if (self.state.hasDirtyFileBesides(file)) {
            self.state.multipleFilesDirty = true;
        } else {
            self.state.dirtyFile = file;
        }
    }

    pub fn markNodeModulesDirty(self: *RegistryBucket, allocator: std.mem.Allocator, packageName: []const u8) !void {
        if (self.state.multipleFilesDirty) {
            return;
        }
        if (packageName.len == 0) {
            self.state.multipleFilesDirty = true;
            return;
        }
        if (self.state.dirtyPackages == null) {
            self.state.dirtyPackages = try collections.Set([]const u8).init(allocator);
        }
        try self.state.dirtyPackages.?.add(packageName);
    }
};

pub const Directory = struct {
    name: []const u8,
    packageJson: ?*packagejson.InfoCacheEntry,
    hasNodeModules: bool,

    pub fn clone(self: Directory, allocator: std.mem.Allocator) !*Directory {
        const d = try allocator.create(Directory);
        d.* = .{
            .name = self.name,
            .packageJson = self.packageJson,
            .hasNodeModules = self.hasNodeModules,
        };
        return d;
    }
};

pub const Registry = struct {
    allocator: std.mem.Allocator,
    toPathFn: *const fn (fileName: []const u8) tspath.Path,
    userPreferences: lsutil.UserPreferences,

    directories: std.StringHashMap(*Directory),
    nodeModules: std.StringHashMap(*RegistryBucket),
    projects: std.StringHashMap(*RegistryBucket),
    uniquePackageCount: usize,

    entrypoints: std.StringHashMap([]*module_pkg.ResolvedEntrypoint),
    specifierCache: std.StringHashMap(*collections.SyncMap([]const u8, []const u8)),

    pub fn init(
        allocator: std.mem.Allocator,
        toPathFn: *const fn (fileName: []const u8) tspath.Path,
        preferences: lsutil.UserPreferences,
    ) !*Registry {
        const registry = try allocator.create(Registry);
        registry.* = .{
            .allocator = allocator,
            .toPathFn = toPathFn,
            .userPreferences = preferences,
            .directories = std.StringHashMap(*Directory).init(allocator),
            .nodeModules = std.StringHashMap(*RegistryBucket).init(allocator),
            .projects = std.StringHashMap(*RegistryBucket).init(allocator),
            .uniquePackageCount = 0,
            .entrypoints = std.StringHashMap([]*module_pkg.ResolvedEntrypoint).init(allocator),
            .specifierCache = std.StringHashMap(*collections.SyncMap([]const u8, []const u8)).init(allocator),
        };
        return registry;
    }

    pub fn getCacheStats(self: *Registry) *CacheStats {
        const stats = self.allocator.create(CacheStats) catch unreachable;
        stats.* = .{
            .projectBuckets = &[_]BucketStats{},
            .nodeModulesBuckets = &[_]BucketStats{},
            .uniquePackageCount = 0,
        };
        return stats;
    }

    pub fn isPreparedForImportingFile(self: *Registry, fileName: []const u8, projectPath: tspath.Path, preferences: lsutil.UserPreferences) bool {
        const projectBucket = self.projects.get(projectPath) orelse return false;
        const path = self.toPathFn(fileName);
        if (projectBucket.state.possiblyNeedsRebuildForFile(path, preferences)) {
            return false;
        }

        var dirPath = tspath.getDirectoryPath(self.allocator, path) catch unreachable;
        while (true) {
            if (self.nodeModules.get(dirPath)) |dirBucket| {
                if (dirBucket.state.possiblyNeedsRebuildForFile(path, preferences)) {
                    return false;
                }
            }
            const parent = tspath.getDirectoryPath(self.allocator, dirPath) catch unreachable;
            if (std.mem.eql(u8, parent, dirPath)) {
                break;
            }
            dirPath = parent;
        }
        return true;
    }

    pub fn nodeModulesDirectories(self: *Registry, allocator: std.mem.Allocator) !std.StringHashMap([]const u8) {
        _ = self;
        return std.StringHashMap([]const u8).init(allocator);
    }
};

pub const BucketStats = struct {
    path: tspath.Path,
    exportCount: usize,
    fileCount: usize,
    state: BucketState,
    dependencyNames: ?*collections.Set([]const u8),
    packageNames: ?*collections.Set([]const u8),
};

pub const CacheStats = struct {
    projectBuckets: []BucketStats,
    nodeModulesBuckets: []BucketStats,
    uniquePackageCount: usize,
};
pub const RegistryChange = struct {
    RequestedFile: tspath.Path,
    OpenFiles: std.StringHashMap([]const u8),
    Changed: collections.Set(lsproto.DocumentUri),
    Created: collections.Set(lsproto.DocumentUri),
    Deleted: collections.Set(lsproto.DocumentUri),
    RebuiltPrograms: std.StringHashMap(bool),
    UserPreferences: ?*lsutil.UserPreferences,
};

pub const RegistryCloneHost = struct {
    // resolutionHost: module.ResolutionHost,
    // Using a vtable-like structure or just assuming an interface struct with pointers to functions
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        fs: *const fn(ptr: *anyopaque) *vfs.FS,
        getDefaultProject: *const fn(ptr: *anyopaque, path: tspath.Path) struct {tspath.Path, ?*compiler.Program},
        getProgramForProject: *const fn(ptr: *anyopaque, projectPath: tspath.Path) ?*compiler.Program,
        getPackageJson: *const fn(ptr: *anyopaque, fileName: []const u8) ?*packagejson.InfoCacheEntry,
        getSourceFile: *const fn(ptr: *anyopaque, fileName: []const u8, path: tspath.Path) ?*ast.SourceFile,
        dispose: *const fn(ptr: *anyopaque) void,
    };

    pub inline fn fs(self: RegistryCloneHost) *vfs.FS {
        return self.vtable.fs(self.ptr);
    }
    
    pub inline fn getDefaultProject(self: RegistryCloneHost, path: tspath.Path) struct {tspath.Path, ?*compiler.Program} {
        return self.vtable.getDefaultProject(self.ptr, path);
    }
    
    pub inline fn getProgramForProject(self: RegistryCloneHost, projectPath: tspath.Path) ?*compiler.Program {
        return self.vtable.getProgramForProject(self.ptr, projectPath);
    }
    
    pub inline fn getPackageJson(self: RegistryCloneHost, fileName: []const u8) ?*packagejson.InfoCacheEntry {
        return self.vtable.getPackageJson(self.ptr, fileName);
    }
    
    pub inline fn getSourceFile(self: RegistryCloneHost, fileName: []const u8, path: tspath.Path) ?*ast.SourceFile {
        return self.vtable.getSourceFile(self.ptr, fileName, path);
    }
    
    pub inline fn dispose(self: RegistryCloneHost) void {
        self.vtable.dispose(self.ptr);
    }
};

pub const RegistryBuilder = struct {
    host: RegistryCloneHost,
    base: *Registry,

    userPreferences: lsutil.UserPreferences,
    directories: *dirty.Map(tspath.Path, *Directory),
    nodeModules: *dirty.Map(tspath.Path, *RegistryBucket),
    projects: *dirty.Map(tspath.Path, *RegistryBucket),
    specifierCache: *dirty.MapBuilder(tspath.Path, *collections.SyncMap([]const u8, []const u8), *collections.SyncMap([]const u8, []const u8)),
    resolverOptions: module_pkg.ResolverOptions,

    uniquePackageCount: usize,
    entrypoints: *dirty.MapBuilder(tspath.Path, []*module_pkg.ResolvedEntrypoint, []*module_pkg.ResolvedEntrypoint),
};
