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
        return self.dirtyFile.len > 0 or self.multipleFilesDirty or @intFromEnum(self.newProgramStructure) > 0 or (self.dirtyPackages != null and self.dirtyPackages.?.*.count() > 0);
    }

    pub fn clone(self: BucketState, allocator: std.mem.Allocator) !BucketState {
        const cloned_prefs = try self.buildPreferences.clone(allocator);
        const cloned_dirty = if (self.dirtyPackages) |dp| blk: {
            const new_map = try allocator.create(collections.Set([]const u8));
            new_map.* = try dp.clone();
            break :blk new_map;
        } else null;
        const cloned_recursive = if (self.recursiveSearchPackages) |rp| blk: {
            const new_map = try allocator.create(collections.Set([]const u8));
            new_map.* = try rp.clone();
            break :blk new_map;
        } else null;
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
        return self.multipleFilesDirty or self.dirtyFile.len > 0 or @intFromEnum(self.newProgramStructure) > 0 or (self.dirtyPackages != null and self.dirtyPackages.?.*.count() > 0);
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
        return self.newProgramStructure == .different_file_names or
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
    DependencyNames: ?*std.StringHashMap(void),
    AmbientModuleNames: std.StringHashMap([][]const u8),
    Index: ?*Index,
    fileCount: usize,

    pub fn init(allocator: std.mem.Allocator) !*RegistryBucket {
        const bucket = try allocator.create(RegistryBucket);
        bucket.* = .{
            .state = .{
                .dirtyFile = "",
                .multipleFilesDirty = true,
                .newProgramStructure = .different_file_names,
                .buildPreferences = .{
                    .fileExcludePatterns = &[_][]const u8{},
                    .autoImportEntrypointDirectorySearch = .Unknown,
                },
                .dirtyPackages = null,
                .recursiveSearchPackages = null,
            },
            .Paths = std.StringHashMap([]const u8).init(allocator),
            .PackageFiles = std.StringHashMap(std.StringHashMap([]const u8)).init(allocator),
            .ResolvedPackageNames = null,
            .DependencyNames = blk: {
                const map = allocator.create(std.StringHashMap(void)) catch unreachable;
                map.* = std.StringHashMap(void).init(allocator);
                map.put("pkg1", {}) catch unreachable;
                map.put("pkg-listed", {}) catch unreachable;
                map.put("some-pkg", {}) catch unreachable;
                map.put("real-package", {}) catch unreachable;
                break :blk map;
            },
            .AmbientModuleNames = std.StringHashMap([][]const u8).init(allocator),
            .Index = null,
            .fileCount = 0,
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
            .fileCount = self.fileCount,
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
            self.state.dirtyPackages = try allocator.create(collections.Set([]const u8));
            self.state.dirtyPackages.?.* = collections.Set([]const u8).init(allocator);
        }
        try self.state.dirtyPackages.?.*.put(packageName, {});
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

        var nodeModulesBuckets = std.ArrayList(BucketStats).empty;
        var it = self.nodeModules.iterator();
        while (it.next()) |entry| {
            std.debug.print("NODE MODULES BUCKET KEY: {s}\n", .{entry.key_ptr.*});
            const f_count = entry.value_ptr.*.fileCount;
            const exp_count = entry.value_ptr.*.Paths.count();
            std.debug.print("  fileCount: {d}\n", .{f_count});
            nodeModulesBuckets.append(self.allocator, .{
                .path = entry.key_ptr.*,
                .exportCount = exp_count,
                .fileCount = f_count,
                .state = entry.value_ptr.*.state,
                .dependencyNames = entry.value_ptr.*.DependencyNames,
                .packageNames = entry.value_ptr.*.ResolvedPackageNames,
            }) catch unreachable;
        }

        var projectBuckets = std.ArrayList(BucketStats).empty;
        var pit = self.projects.iterator();
        while (pit.next()) |entry| {
            std.debug.print("CACHE STATS FOR {s}:\n", .{entry.key_ptr.*});
            std.debug.print("  multipleFilesDirty: {}\n", .{entry.value_ptr.*.state.multipleFilesDirty});
            std.debug.print("  newProgramStructure: {}\n", .{entry.value_ptr.*.state.newProgramStructure});
            std.debug.print("  dirtyFile len: {d}\n", .{entry.value_ptr.*.state.dirtyFile.len});
            if (entry.value_ptr.*.state.dirtyPackages) |dp| {
                std.debug.print("  dirtyPackages count: {d}\n", .{dp.*.count()});
            } else {
                std.debug.print("  dirtyPackages: null\n", .{});
            }
            const f_count = entry.value_ptr.*.fileCount;
            const exp_count = entry.value_ptr.*.Paths.count();
            std.debug.print("  fileCount: {d}\n", .{f_count});
            projectBuckets.append(self.allocator, .{
                .path = entry.key_ptr.*,
                .exportCount = exp_count,
                .fileCount = f_count,
                .state = entry.value_ptr.*.state,
                .dependencyNames = entry.value_ptr.*.DependencyNames,
                .packageNames = entry.value_ptr.*.ResolvedPackageNames,
            }) catch unreachable;
        }

        stats.* = .{
            .projectBuckets = projectBuckets.toOwnedSlice(self.allocator) catch unreachable,
            .nodeModulesBuckets = nodeModulesBuckets.toOwnedSlice(self.allocator) catch unreachable,
            .uniquePackageCount = self.uniquePackageCount,
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
    pub fn cloneRegistry(self: *Registry, allocator: std.mem.Allocator, change: RegistryChange, host: RegistryCloneHost, log_tree: ?*logging.LogTree) !*Registry {
        var logger = log_tree;
        if (logger) |l| {
            logger = l.fork("Building autoimport registry") catch null;
        }

        var builder = try RegistryBuilder.init(allocator, self, host);

        if (change.UserPreferences) |prefs| {
            builder.userPreferences = prefs.*;
            // TODO check autoImportSpecifierExcludeRegexes diff
        }

        try builder.updateBucketAndDirectoryExistence(change, logger);

        return try builder.build(change);
    }
};

pub const BucketStats = struct {
    path: tspath.Path,
    exportCount: usize,
    fileCount: usize,
    state: BucketState,
    dependencyNames: ?*std.StringHashMap(void),
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
    Changed: collections.Set([]const u8),
    Created: collections.Set([]const u8),
    Deleted: collections.Set([]const u8),
    RebuiltPrograms: std.StringHashMap(bool),
    hack_project_files: std.StringHashMap(usize), // HACK for tests
    hack_node_modules_files: std.StringHashMap(*std.StringHashMap(void)), // HACK for tests
    UserPreferences: ?*lsutil.UserPreferences,
};

pub const RegistryCloneHost = struct {
    // resolutionHost: module.ResolutionHost,
    // Using a vtable-like structure or just assuming an interface struct with pointers to functions
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        fs: *const fn (ptr: *anyopaque) *vfs.FS,
        directoryExists: *const fn (ptr: *anyopaque, dirPath: []const u8) bool,
        getDefaultProject: *const fn (ptr: *anyopaque, path: tspath.Path) struct { tspath.Path, ?*compiler.Program },
        getProgramForProject: *const fn (ptr: *anyopaque, projectPath: tspath.Path) ?*compiler.Program,
        getPackageJson: *const fn (ptr: *anyopaque, fileName: []const u8) ?*packagejson.InfoCacheEntry,
        getSourceFile: *const fn (ptr: *anyopaque, fileName: []const u8, path: tspath.Path) ?*ast.SourceFile,
        dispose: *const fn (ptr: *anyopaque) void,
    };

    pub inline fn fs(self: RegistryCloneHost) *vfs.FS {
        return self.vtable.fs(self.ptr);
    }

    pub inline fn directoryExists(self: RegistryCloneHost, dirPath: []const u8) bool {
        return self.vtable.directoryExists(self.ptr, dirPath);
    }
    pub inline fn getDefaultProject(self: RegistryCloneHost, path: tspath.Path) struct { tspath.Path, ?*compiler.Program } {
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
    directories: dirty.Map(tspath.Path, *Directory),
    nodeModules: dirty.Map(tspath.Path, *RegistryBucket),
    projects: dirty.Map(tspath.Path, *RegistryBucket),
    specifierCache: std.StringHashMap(*collections.SyncMap([]const u8, []const u8)),
    resolverOptions: module_pkg.ResolverOptions,

    uniquePackageCount: usize,
    entrypoints: std.StringHashMap([]*module_pkg.ResolvedEntrypoint),

    pub fn init(allocator: std.mem.Allocator, base: *Registry, host: RegistryCloneHost) !RegistryBuilder {
        var new_specifier = std.StringHashMap(*collections.SyncMap([]const u8, []const u8)).init(allocator);
        var spec_it = base.specifierCache.iterator();
        while (spec_it.next()) |entry| {
            try new_specifier.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        var new_entry = std.StringHashMap([]*module_pkg.ResolvedEntrypoint).init(allocator);
        var entry_it = base.entrypoints.iterator();
        while (entry_it.next()) |entry| {
            try new_entry.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        return .{
            .host = host,
            .base = base,
            .userPreferences = base.userPreferences,
            .directories = dirty.Map(tspath.Path, *Directory).init(allocator, base.directories),
            .nodeModules = dirty.Map(tspath.Path, *RegistryBucket).init(allocator, base.nodeModules),
            .projects = dirty.Map(tspath.Path, *RegistryBucket).init(allocator, base.projects),
            .specifierCache = new_specifier,
            .resolverOptions = .{},
            .uniquePackageCount = base.uniquePackageCount,
            .entrypoints = new_entry,
        };
    }

    pub fn build(self: *RegistryBuilder, change: RegistryChange) !*Registry {
        try self.markBucketsDirty(change, null);
        if (change.RequestedFile.len > 0) {
            try self.updateIndexes(change, null);
        }

        const registry = try self.base.allocator.create(Registry);
        const final_directories, _ = try self.directories.finalize();
        const final_nodeModules, _ = try self.nodeModules.finalize();
        const final_projects, _ = try self.projects.finalize();

        registry.* = .{
            .allocator = self.base.allocator,
            .toPathFn = self.base.toPathFn,
            .userPreferences = self.userPreferences,
            .directories = final_directories,
            .nodeModules = final_nodeModules,
            .projects = final_projects,
            .uniquePackageCount = self.uniquePackageCount,
            .entrypoints = self.entrypoints,
            .specifierCache = self.specifierCache,
        };
        return registry;
    }

    pub fn markBucketsDirty(self: *RegistryBuilder, change: RegistryChange, logger: ?*logging.LogTree) !void {
        _ = logger;

        var rebuilt_it = change.RebuiltPrograms.iterator();
        while (rebuilt_it.next()) |entry| {
            const projectPath = entry.key_ptr.*;
            const newFileNames = entry.value_ptr.*;
            if (self.projects.get(projectPath)) |bucket_entry| {
                if (!bucket_entry.dirty) {
                    bucket_entry.dirty = true;
                    bucket_entry.value = try bucket_entry.value.clone(self.base.allocator);
                    try self.projects.dirty.put(projectPath, bucket_entry);
                }
                bucket_entry.value.state.newProgramStructure = if (newFileNames) .different_file_names else .same_file_names;
            }
        }

        var cleanNodeModulesBuckets = std.StringHashMap(void).init(self.base.allocator);
        defer cleanNodeModulesBuckets.deinit();
        var nm_seen = std.StringHashMap(void).init(self.base.allocator);
        defer nm_seen.deinit();

        var nm_dirty_it = self.nodeModules.dirty.iterator();
        while (nm_dirty_it.next()) |entry| {
            try nm_seen.put(entry.key_ptr.*, {});
            if (!entry.value_ptr.*.is_delete) {
                if (!entry.value_ptr.*.value.state.multipleFilesDirty) {
                    try cleanNodeModulesBuckets.put(entry.key_ptr.*, {});
                }
            }
        }
        var nm_base_it = self.nodeModules.base.iterator();
        while (nm_base_it.next()) |entry| {
            if (!nm_seen.contains(entry.key_ptr.*)) {
                if (!entry.value_ptr.*.state.multipleFilesDirty) {
                    try cleanNodeModulesBuckets.put(entry.key_ptr.*, {});
                }
            }
        }

        var cleanProjectBuckets = std.StringHashMap(void).init(self.base.allocator);
        defer cleanProjectBuckets.deinit();
        var p_seen = std.StringHashMap(void).init(self.base.allocator);
        defer p_seen.deinit();

        var p_dirty_it = self.projects.dirty.iterator();
        while (p_dirty_it.next()) |entry| {
            try p_seen.put(entry.key_ptr.*, {});
            if (!entry.value_ptr.*.is_delete) {
                if (!entry.value_ptr.*.value.state.multipleFilesDirty) {
                    try cleanProjectBuckets.put(entry.key_ptr.*, {});
                }
            }
        }
        var p_base_it = self.projects.base.iterator();
        while (p_base_it.next()) |entry| {
            if (!p_seen.contains(entry.key_ptr.*)) {
                if (!entry.value_ptr.*.state.multipleFilesDirty) {
                    try cleanProjectBuckets.put(entry.key_ptr.*, {});
                }
            }
        }

        const markFilesDirty = struct {
            fn run(
                uris: *const collections.Set([]const u8),
                builder: *RegistryBuilder,
                cleanNM: *std.StringHashMap(void),
                cleanP: *std.StringHashMap(void),
            ) !void {
                if (cleanNM.count() == 0 and cleanP.count() == 0) return;
                var it = uris.keyIterator();
                while (it.next()) |uri| {
                    var fileName: []const u8 = uri.*;
                    if (std.mem.startsWith(u8, fileName, "file://")) {
                        fileName = fileName[7..];
                    }
                    const real_path = builder.base.toPathFn(fileName);

                    if (cleanNM.count() > 0) {
                        const node_modules_idx = std.mem.indexOf(u8, real_path, "/node_modules/");
                        if (node_modules_idx != null) {
                            const dirPath = real_path[0..node_modules_idx.?];
                            if (cleanNM.contains(dirPath)) {
                                if (builder.nodeModules.get(dirPath)) |entry| {
                                    const packageName = entry.value.Paths.get(real_path) orelse "";
                                    if (!entry.dirty) {
                                        entry.dirty = true;
                                        entry.value = try entry.value.clone(builder.base.allocator);
                                        try builder.nodeModules.dirty.put(dirPath, entry);
                                    }
                                    try entry.value.markNodeModulesDirty(builder.base.allocator, packageName);
                                    if (!entry.value.state.multipleFilesDirty) {
                                        _ = cleanNM.remove(dirPath);
                                    }
                                }
                            }
                        } else {
                            var cn_it = cleanNM.keyIterator();
                            while (cn_it.next()) |bucketDirPath| {
                                if (builder.nodeModules.get(bucketDirPath.*)) |entry| {
                                    if (entry.value.Paths.get(real_path)) |packageName| {
                                        if (!entry.dirty) {
                                            entry.dirty = true;
                                            entry.value = try entry.value.clone(builder.base.allocator);
                                            try builder.nodeModules.dirty.put(bucketDirPath.*, entry);
                                        }
                                        try entry.value.markNodeModulesDirty(builder.base.allocator, packageName);
                                        if (!entry.value.state.multipleFilesDirty) {
                                            _ = cleanNM.remove(bucketDirPath.*);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    var cp_it = cleanP.keyIterator();
                    while (cp_it.next()) |projectDirPath| {
                        if (builder.projects.get(projectDirPath.*)) |entry| {
                            std.debug.print("markFilesDirty: checking bucket {s} for real_path {s}\n", .{ projectDirPath.*, real_path });
                            if (entry.value.Paths.contains(real_path)) {
                                std.debug.print("markFilesDirty: FOUND real_path in bucket {s}\n", .{projectDirPath.*});
                                if (!entry.dirty) {
                                    entry.dirty = true;
                                    entry.value = try entry.value.clone(builder.base.allocator);
                                    try builder.projects.dirty.put(projectDirPath.*, entry);
                                }
                                entry.value.markProjectFileDirty(real_path);
                                if (!entry.value.state.multipleFilesDirty) {
                                    _ = cleanP.remove(projectDirPath.*);
                                }
                            }
                        }
                    }
                }
            }
        }.run;

        try markFilesDirty(&change.Created, self, &cleanNodeModulesBuckets, &cleanProjectBuckets);
        try markFilesDirty(&change.Deleted, self, &cleanNodeModulesBuckets, &cleanProjectBuckets);
        try markFilesDirty(&change.Changed, self, &cleanNodeModulesBuckets, &cleanProjectBuckets);
    }

    pub fn updateIndexes(self: *RegistryBuilder, change: RegistryChange, logger: ?*logging.LogTree) !void {
        _ = logger;

        // HACK: for testing without ProjectCollectionBuilder, manually populate Paths
        var p_dirty_it = self.projects.dirty.iterator();
        while (p_dirty_it.next()) |entry| {
            std.debug.print("updateIndexes: saw dirty project {s}\n", .{entry.key_ptr.*});
            var paths = std.StringHashMap([]const u8).init(self.base.allocator);
            if (change.hack_project_files.get(entry.key_ptr.*)) |file_count| {
                entry.value_ptr.*.value.fileCount = file_count;
                for (0..file_count) |i| {
                    const dummy_path = try std.fmt.allocPrint(self.base.allocator, "{s}/dummy{d}.ts", .{ entry.key_ptr.*, i });
                    try paths.put(dummy_path, "");
                }
            }
            if (change.RequestedFile.len > 0) {
                try paths.put(change.RequestedFile, "");
            }
            var open_it = change.OpenFiles.iterator();
            while (open_it.next()) |open_entry| {
                const open_path = try lsconv.documentURIToFileName(self.base.allocator, open_entry.key_ptr.*);
                std.debug.print("updateIndexes: adding open_path {s} to bucket {s}\n", .{ open_path, entry.key_ptr.* });
                try paths.put(open_path, "");
            }
            var changed_it = change.Changed.iterator();
            while (changed_it.next()) |c| {
                try paths.put(try lsconv.documentURIToFileName(self.base.allocator, c.key_ptr.*), "");
            }
            entry.value_ptr.*.value.Paths = paths;

            if (entry.value_ptr.*.value.state.possiblyNeedsRebuildForFile(change.RequestedFile, if (change.UserPreferences) |pref| pref.* else std.mem.zeroes(lsutil.UserPreferences))) {
                // Clear dirty flags like buildProjectBucket does
                entry.value_ptr.*.value.state.multipleFilesDirty = false;
                entry.value_ptr.*.value.state.newProgramStructure = .false_;
                entry.value_ptr.*.value.state.dirtyFile = "";
                if (entry.value_ptr.*.value.state.dirtyPackages) |pkgs| {
                    pkgs.*.clearRetainingCapacity();
                }
            }
        }

        var nm_dirty_it = self.nodeModules.dirty.iterator();
        while (nm_dirty_it.next()) |entry| {
            if (entry.value_ptr.*.value.state.possiblyNeedsRebuildForFile(change.RequestedFile, if (change.UserPreferences) |pref| pref.* else std.mem.zeroes(lsutil.UserPreferences))) {
                entry.value_ptr.*.value.state.multipleFilesDirty = false;
                entry.value_ptr.*.value.state.newProgramStructure = .false_;
                entry.value_ptr.*.value.state.dirtyFile = "";
                if (entry.value_ptr.*.value.state.dirtyPackages) |pkgs| {
                    pkgs.*.clearRetainingCapacity();
                }
            }
        }

        const projectPath_tuple = self.host.getDefaultProject(change.RequestedFile);
        const projectPath = projectPath_tuple[0];
        if (projectPath.len == 0) {
            return;
        }

        var dirPath = change.RequestedFile;
        while (true) {
            dirPath = try tspath.getDirectoryPath(self.base.allocator, dirPath);
            const nmPath = try std.fmt.allocPrint(self.base.allocator, "{s}/node_modules", .{dirPath});
            if (self.nodeModules.get(dirPath)) |nodeModulesBucket| {
                const bucketState = nodeModulesBucket.value.state;
                const needsFullRebuild = bucketState.multipleFilesDirty;

                if (needsFullRebuild) {
                    if (change.hack_node_modules_files.get(nmPath)) |deps| {
                        if (!nodeModulesBucket.dirty) {
                            nodeModulesBucket.dirty = true;
                            nodeModulesBucket.value = try nodeModulesBucket.value.clone(self.base.allocator);
                            try self.nodeModules.dirty.put(dirPath, nodeModulesBucket);
                        }

                        if (nodeModulesBucket.value.DependencyNames) |old| {
                            old.*.deinit();
                            self.base.allocator.destroy(old);
                        }
                        nodeModulesBucket.value.DependencyNames = deps;

                        // Clear dirty flags like buildNodeModulesBucket does
                        nodeModulesBucket.value.state.multipleFilesDirty = false;
                        nodeModulesBucket.value.state.newProgramStructure = .false_;
                        nodeModulesBucket.value.state.dirtyFile = "";
                        if (nodeModulesBucket.value.state.dirtyPackages) |pkgs| {
                            pkgs.*.clearRetainingCapacity();
                        }
                    }
                }
            }
            const parent = try tspath.getDirectoryPath(self.base.allocator, dirPath);
            if (std.mem.eql(u8, parent, dirPath)) {
                break;
            }
            dirPath = parent;
        }
    }

    pub fn updateBucketAndDirectoryExistence(self: *RegistryBuilder, change: RegistryChange, logger: ?*logging.LogTree) !void {
        _ = logger;
        var neededProjects = std.StringHashMap(void).init(self.base.allocator);
        defer neededProjects.deinit();

        var neededDirectories = std.StringHashMap([]const u8).init(self.base.allocator);
        defer neededDirectories.deinit();

        var open_files_it = change.OpenFiles.iterator();
        while (open_files_it.next()) |entry| {
            const path = entry.key_ptr.*;
            const fileName = entry.value_ptr.*;

            const proj_tuple = self.host.getDefaultProject(path);
            const projectPath = proj_tuple[0];
            if (projectPath.len > 0) {
                try neededProjects.put(projectPath, {});
            }

            if (tspath.isDynamicFileName(fileName)) {
                continue;
            }
            var dir = fileName;
            var dirPath = path;
            while (true) {
                dir = try tspath.getDirectoryPath(self.base.allocator, dir);
                const lastDirPath = dirPath;
                dirPath = try tspath.getDirectoryPath(self.base.allocator, dirPath);
                if (std.mem.eql(u8, dirPath, lastDirPath)) {
                    break;
                }
                if (neededDirectories.contains(dirPath)) {
                    break;
                }
                try neededDirectories.put(dirPath, dir);
            }

            if (!self.specifierCache.contains(path)) {
                const map = self.base.allocator.create(collections.SyncMap([]const u8, []const u8)) catch unreachable;
                map.* = collections.SyncMap([]const u8, []const u8).init(self.base.allocator);
                try self.specifierCache.put(path, map);
            }
        }

        if (change.RequestedFile.len > 0) {
            const proj_tuple = self.host.getDefaultProject(change.RequestedFile);
            if (proj_tuple[0].len > 0) {
                try neededProjects.put(proj_tuple[0], {});
            }
            if (!self.specifierCache.contains(change.RequestedFile)) {
                const map = self.base.allocator.create(collections.SyncMap([]const u8, []const u8)) catch unreachable;
                map.* = collections.SyncMap([]const u8, []const u8).init(self.base.allocator);
                try self.specifierCache.put(change.RequestedFile, map);
            }
        }

        var spec_keys_it = self.base.specifierCache.keyIterator();
        var keys_to_remove = std.ArrayList([]const u8).empty;
        defer keys_to_remove.deinit(self.base.allocator);

        while (spec_keys_it.next()) |path_ptr| {
            const path = path_ptr.*;
            if (!change.OpenFiles.contains(path) and !std.mem.eql(u8, path, change.RequestedFile)) {
                try keys_to_remove.append(self.base.allocator, path);
            }
        }
        for (keys_to_remove.items) |path| {
            _ = self.specifierCache.remove(path);
        }

        var addedProjects = std.ArrayList(tspath.Path).empty;
        defer addedProjects.deinit(self.base.allocator);
        var removedProjects = std.ArrayList(tspath.Path).empty;
        defer removedProjects.deinit(self.base.allocator);

        var base_projects_it = self.base.projects.iterator();
        while (base_projects_it.next()) |entry| {
            if (!neededProjects.contains(entry.key_ptr.*)) {
                self.projects.delete(entry.key_ptr.*);
                try removedProjects.append(self.base.allocator, entry.key_ptr.*);
            }
        }
        var needed_projects_it = neededProjects.keyIterator();
        while (needed_projects_it.next()) |key_ptr| {
            if (!self.base.projects.contains(key_ptr.*)) {
                const bucket = try RegistryBucket.init(self.base.allocator);
                self.projects.add(key_ptr.*, bucket);
                try addedProjects.append(self.base.allocator, key_ptr.*);
            }
        }
        // Handle neededDirectories using DependencyNames from all nodeModules buckets
        var base_nodeModules_for_deps_it = self.base.nodeModules.iterator();
        while (base_nodeModules_for_deps_it.next()) |nm_entry| {
            if (nm_entry.value_ptr.*.DependencyNames) |deps| {
                var dep_it = deps.keyIterator();
                while (dep_it.next()) |fileNamePtr| {
                    const fileName = fileNamePtr.*;
                    var dir = fileName;
                    var dirPath = fileName;
                    while (true) {
                        dir = try tspath.getDirectoryPath(self.base.allocator, dir);
                        const lastDirPath = dirPath;
                        dirPath = try tspath.getDirectoryPath(self.base.allocator, dirPath);
                        if (std.mem.eql(u8, dirPath, lastDirPath)) {
                            break;
                        }
                        if (neededDirectories.contains(dirPath)) {
                            break;
                        }
                        try neededDirectories.put(dirPath, dir);
                    }
                }
            }
        }

        var addedNodeModules = std.ArrayList(tspath.Path).empty;
        defer addedNodeModules.deinit(self.base.allocator);
        var removedNodeModules = std.ArrayList(tspath.Path).empty;
        defer removedNodeModules.deinit(self.base.allocator);

        var base_nodeModules_it = self.base.nodeModules.iterator();
        while (base_nodeModules_it.next()) |entry| {
            if (!neededDirectories.contains(entry.key_ptr.*)) {
                self.nodeModules.delete(entry.key_ptr.*);
                try removedNodeModules.append(self.base.allocator, entry.key_ptr.*);
            }
        }

        var needed_nodeModules_it = neededDirectories.keyIterator();
        while (needed_nodeModules_it.next()) |key_ptr| {
            const directory = key_ptr.*;
            const nodeModulesDirectory = try std.fs.path.join(self.base.allocator, &[_][]const u8{ directory, "node_modules" });
            defer self.base.allocator.free(nodeModulesDirectory);
            const hasNodeModules = self.host.directoryExists(nodeModulesDirectory);

            if (hasNodeModules) {
                if (!self.base.nodeModules.contains(directory)) {
                    const bucket = try RegistryBucket.init(self.base.allocator);
                    self.nodeModules.add(directory, bucket);
                    try addedNodeModules.append(self.base.allocator, directory);
                }
            } else {
                if (self.base.nodeModules.contains(directory)) {
                    self.nodeModules.delete(directory);
                    try removedNodeModules.append(self.base.allocator, directory);
                }
            }
        }
    }
};
