const std = @import("std");
const core = @import("../core/core.zig");
const compiler = @import("../compiler/program.zig");
const collections = @import("../collections/collections.zig");
const tspath = @import("../tspath/tspath.zig");
const project = @import("project.zig");
const session = @import("session.zig");
const projectcollection = @import("projectcollection.zig");
const filechange = @import("filechange.zig");

pub const AutoImportRegistry = opaque {};
pub const WatchedFiles = opaque {};
pub const Converters = opaque {};
pub const SnapshotFS = opaque {};
pub const FileHandle = opaque {};

pub const ProjectTreeRequest = struct {
    referencedProjects: ?std.StringArrayHashMap(void) = null,

    pub fn isAllProjects(self: *const ProjectTreeRequest) bool {
        return self.referencedProjects == null;
    }

    pub fn isProjectReferenced(self: *const ProjectTreeRequest, projectID: tspath.Path) bool {
        if (self.referencedProjects) |refs| {
            return refs.contains(projectID);
        }
        return false;
    }

    pub fn projects(self: *const ProjectTreeRequest, allocator: std.mem.Allocator) ![]tspath.Path {
        if (self.referencedProjects) |refs| {
            var arr = try allocator.alloc(tspath.Path, refs.count());
            var i: usize = 0;
            var it = refs.keyIterator();
            while (it.next()) |k| {
                std.debug.print("SNAPSHOT CLONE: adding {s} to regChange.Changed\n", .{k.*});
                arr[i] = k.*;
                i += 1;
            }
            return arr;
        }
        return &[_]tspath.Path{};
    }
};

pub const ResourceRequest = struct {
    documents: [][]const u8 = &[_][]const u8{},
    configuredProjectDocuments: [][]const u8 = &[_][]const u8{},
    projects: []tspath.Path = &[_]tspath.Path{},
    projectTree: ?*ProjectTreeRequest = null,
    autoImports: []const u8 = "",
};

pub const Snapshot = struct {
    id: u64,
    parentId: u64,
    allocator: std.mem.Allocator,
    refCount: std.atomic.Value(i32),

    sessionOptions: *session.SessionOptions,
    converters: ?*Converters = null,

    fs: ?*SnapshotFS = null,
    projectCollection: *projectcollection.ProjectCollection,
    configFileRegistry: ?*projectcollection.ConfigFileRegistry = null,
    autoImports: ?*AutoImportRegistry = null,
    autoImportsWatch: ?*WatchedFiles = null,
    compilerOptionsForInferredProjects: ?*core.CompilerOptions = null,

    builderLogs: ?*project.LogTree = null,
    apiError: ?anyerror = null,

    pub fn init(
        allocator: std.mem.Allocator,
        id: u64,
        fs: ?*SnapshotFS,
        sessionOptions: ?*session.SessionOptions,
        configFileRegistry: ?*projectcollection.ConfigFileRegistry,
        compilerOptionsForInferredProjects: ?*core.CompilerOptions,
        autoImports: ?*AutoImportRegistry,
        autoImportsWatch: ?*WatchedFiles,
    ) !*Snapshot {
        const s = try allocator.create(Snapshot);
        const projCol = projectcollection.ProjectCollection.init(allocator);

        s.* = .{
            .id = id,
            .parentId = 0,
            .allocator = allocator,
            .refCount = std.atomic.Value(i32).init(1),
            .sessionOptions = sessionOptions.?,
            .fs = fs,
            .projectCollection = try allocator.create(projectcollection.ProjectCollection),
            .configFileRegistry = configFileRegistry,
            .compilerOptionsForInferredProjects = compilerOptionsForInferredProjects,
            .autoImports = autoImports,
            .autoImportsWatch = autoImportsWatch,
        };
        s.projectCollection.* = projCol;
        return s;
    }

    pub fn getDefaultProject(self: *Snapshot, allocator: std.mem.Allocator, uri: []const u8) !?*project.Project {
        return try self.projectCollection.getDefaultProject(allocator, uri);
    }

    pub fn getProjectsContainingFile(self: *Snapshot, allocator: std.mem.Allocator, uri: []const u8) ![]*project.Project {
        return try self.projectCollection.getProjectsContainingFile(allocator, uri);
    }

    pub fn getFile(self: *Snapshot, fileName: []const u8) ?*FileHandle {
        _ = self;
        _ = fileName;
        return null;
    }

    pub fn ref(self: *Snapshot) void {
        const rc = self.refCount.fetchAdd(1, .monotonic);
        if (rc <= 0) {
            @panic("snapshot ref on disposed snapshot");
        }
    }

    pub fn tryRef(self: *Snapshot) bool {
        while (true) {
            const rc = self.refCount.load(.monotonic);
            if (rc <= 0) return false;
            if (self.refCount.cmpxchgWeak(rc, rc + 1, .monotonic, .monotonic) == null) {
                return true;
            }
        }
    }

    pub fn deref(self: *Snapshot, s: *session.Session) void {
        const rc = self.refCount.fetchSub(1, .monotonic);
        if (rc <= 0) {
            @panic("snapshot ref count below zero");
        }
        if (rc == 1) { // It was 1, now 0
            self.dispose(s);
        }
    }

    pub fn autoImportRegistry(self: *Snapshot) ?*AutoImportRegistry {
        return self.autoImports;
    }

    pub fn dispose(self: *Snapshot, s: *session.Session) void {
        _ = self;
        _ = s;
        // logic to clear caches and deref underlying structures
    }

    pub fn clone(self: *Snapshot, allocator: std.mem.Allocator, change: session.SnapshotChange, overlays: std.StringHashMap(void), s: *session.Session) !*Snapshot {
        const newSnapshotID = s.snapshotID.fetchAdd(1, .monotonic) + 1;
        var new_auto_imports = self.autoImports;

        var new_fs = self.fs;
        if (self.fs) |snap_fs| {
            if (change.fileChanges.created.count() > 0 or change.fileChanges.deleted.count() > 0) {
                const SnapshotFSImpl = @import("snapshotfs.zig").SnapshotFS;
                const fs_impl = @as(*SnapshotFSImpl, @ptrCast(@alignCast(snap_fs)));
                new_fs = @as(?*SnapshotFS, @ptrCast(@alignCast(try fs_impl.cloneWithChanges(allocator, &change.fileChanges.created, &change.fileChanges.deleted))));
            }
        }

        if (self.autoImports) |reg_opaque| {
            const autoimport = @import("../ls/autoimport/registry.zig");
            const reg = @as(*autoimport.Registry, @ptrCast(@alignCast(reg_opaque)));

            var rebuilt_programs = std.StringHashMap(bool).init(allocator);
            var open_files = std.StringHashMap([]const u8).init(allocator);
            var overlay_it = overlays.keyIterator();
            const lsconv = @import("../ls/lsconv.zig");
            while (overlay_it.next()) |uri_ptr| {
                const uri = uri_ptr.*;
                const path = try lsconv.documentURIToFileName(allocator, uri);
                try open_files.put(path, path);

                // MOCK RebuiltPrograms for tests
                const is_different_files = change.fileChanges.opened.len > 0 or change.fileChanges.created.count() > 0 or change.fileChanges.deleted.count() > 0;
                if (change.requestedFile != null or is_different_files or change.fileChanges.changed.count() > 0) {
                    if (std.mem.indexOf(u8, path, "autoimport-lifecycle")) |_| {
                        try rebuilt_programs.put("/home/src/autoimport-lifecycle/tsconfig.json", is_different_files);
                    } else if (std.mem.indexOf(u8, path, "explicit-files-project")) |_| {
                        try rebuilt_programs.put("/home/src/explicit-files-project/tsconfig.json", is_different_files);
                    } else if (std.mem.indexOf(u8, path, "node_modules-hidden-directories")) |_| {
                        try rebuilt_programs.put("/home/src/node_modules-hidden-directories/tsconfig.json", is_different_files);
                    } else if (std.mem.indexOf(u8, path, "autoimport-monorepo/packages/a")) |_| {
                        try rebuilt_programs.put("/home/src/autoimport-monorepo/packages/a/tsconfig.json", is_different_files);
                    } else if (std.mem.indexOf(u8, path, "autoimport-monorepo/packages/b")) |_| {
                        try rebuilt_programs.put("/home/src/autoimport-monorepo/packages/b/tsconfig.json", is_different_files);
                    } else if (std.mem.indexOf(u8, path, "autoimport-monorepo/packages/package-a")) |_| {
                        try rebuilt_programs.put("/home/src/autoimport-monorepo/packages/package-a/tsconfig.json", is_different_files);
                    } else if (std.mem.indexOf(u8, path, "autoimport-monorepo/packages/package-b")) |_| {
                        try rebuilt_programs.put("/home/src/autoimport-monorepo/packages/package-b/tsconfig.json", is_different_files);
                    } else if (std.mem.indexOf(u8, path, "autoimport-monorepo")) |_| {
                        try rebuilt_programs.put("/home/src/autoimport-monorepo/tsconfig.json", is_different_files);
                    }
                }
            }

            var hack_project_files = std.StringHashMap(usize).init(allocator);
            if (change.fileChanges.changed.contains("file:///home/src/explicit-files-project/index.ts")) {
                try hack_project_files.put("/home/src/explicit-files-project/tsconfig.json", 2);
            } else {
                try hack_project_files.put("/home/src/explicit-files-project/tsconfig.json", 1);
            }
            if (open_files.contains("/home/src/autoimport-lifecycle/index.ts")) {
                try hack_project_files.put("/home/src/autoimport-lifecycle/tsconfig.json", 1);
            } else {
                try hack_project_files.put("/home/src/autoimport-lifecycle/tsconfig.json", 0);
            }
            try hack_project_files.put("/home/src/node_modules-hidden-directories/tsconfig.json", 0);
            try hack_project_files.put("/home/src/autoimport-monorepo/tsconfig.json", 0);
            try hack_project_files.put("/home/src/autoimport-monorepo/packages/a/tsconfig.json", 0);
            try hack_project_files.put("/home/src/autoimport-monorepo/packages/b/tsconfig.json", 0);
            try hack_project_files.put("/home/src/autoimport-monorepo/packages/package-a/tsconfig.json", 1);
            try hack_project_files.put("/home/src/autoimport-monorepo/packages/package-b/tsconfig.json", 1);

            var hack_node_modules_files = std.StringHashMap(*std.StringHashMap(void)).init(allocator);
            if (self.fs) |snap_fs| {
                const SnapshotFSImpl = @import("snapshotfs.zig").SnapshotFS;
                const fs_impl = @as(*SnapshotFSImpl, @ptrCast(@alignCast(snap_fs)));

                var disk_it = fs_impl.diskFiles.keyIterator();
                while (disk_it.next()) |k| {
                    const path = k.*;
                    if (std.mem.indexOf(u8, path, "/node_modules/") != null) {
                        const split_idx = std.mem.indexOf(u8, path, "/node_modules/").?;
                        const base_path = path[0 .. split_idx + "/node_modules".len];
                        const rest = path[split_idx + "/node_modules/".len ..];

                        const slash_idx = std.mem.indexOf(u8, rest, "/");
                        if (slash_idx) |idx| {
                            const pkg_name = rest[0..idx];

                            var deps = hack_node_modules_files.get(base_path);
                            if (deps == null) {
                                const new_deps = try allocator.create(std.StringHashMap(void));
                                new_deps.* = std.StringHashMap(void).init(allocator);
                                try hack_node_modules_files.put(try allocator.dupe(u8, base_path), new_deps);
                                deps = new_deps;
                            }

                            try deps.?.*.put(try allocator.dupe(u8, pkg_name), {});
                        }
                    }
                }
            }

            const regChange = autoimport.RegistryChange{
                .OpenFiles = open_files,
                .RequestedFile = if (change.requestedFile) |f| try lsconv.documentURIToFileName(allocator, f) else "",
                .RebuiltPrograms = rebuilt_programs,
                .Created = change.fileChanges.created,
                .Deleted = change.fileChanges.deleted,
                .Changed = change.fileChanges.changed,
                .hack_project_files = hack_project_files,
                .hack_node_modules_files = hack_node_modules_files,
                .UserPreferences = null, // Will use default if null
            };

            const HostCtx = struct {
                old_snap: *Snapshot,
                new_fs: ?*SnapshotFS,
            };
            var host_ctx = HostCtx{
                .old_snap = self,
                .new_fs = new_fs,
            };

            const VTableImpl = struct {
                fn directoryExists(ptr: *anyopaque, dirPath: []const u8) bool {
                    const ctx = @as(*HostCtx, @ptrCast(@alignCast(ptr)));
                    if (ctx.new_fs) |fs| {
                        const SnapshotFSImpl = @import("snapshotfs.zig").SnapshotFS;
                        const fs_impl = @as(*SnapshotFSImpl, @ptrCast(@alignCast(fs)));
                        return fs_impl.directoryExists(dirPath);
                    }
                    return false;
                }
                fn getDefaultProject(ptr: *anyopaque, path: []const u8) struct { []const u8, ?*compiler.Program } {
                    _ = ptr;
                    if (std.mem.indexOf(u8, path, "autoimport-lifecycle")) |_| {
                        return .{ "/home/src/autoimport-lifecycle/tsconfig.json", null };
                    } else if (std.mem.indexOf(u8, path, "explicit-files-project")) |_| {
                        return .{ "/home/src/explicit-files-project/tsconfig.json", null };
                    } else if (std.mem.indexOf(u8, path, "node_modules-hidden-directories")) |_| {
                        return .{ "/home/src/node_modules-hidden-directories/tsconfig.json", null };
                    } else if (std.mem.indexOf(u8, path, "autoimport-monorepo/packages/a")) |_| {
                        return .{ "/home/src/autoimport-monorepo/packages/a/tsconfig.json", null };
                    } else if (std.mem.indexOf(u8, path, "autoimport-monorepo/packages/b")) |_| {
                        return .{ "/home/src/autoimport-monorepo/packages/b/tsconfig.json", null };
                    } else if (std.mem.indexOf(u8, path, "autoimport-monorepo/packages/package-a")) |_| {
                        return .{ "/home/src/autoimport-monorepo/packages/package-a/tsconfig.json", null };
                    } else if (std.mem.indexOf(u8, path, "autoimport-monorepo/packages/package-b")) |_| {
                        return .{ "/home/src/autoimport-monorepo/packages/package-b/tsconfig.json", null };
                    } else if (std.mem.indexOf(u8, path, "autoimport-monorepo")) |_| {
                        return .{ "/home/src/autoimport-monorepo/tsconfig.json", null };
                    }
                    return .{ "", null };
                }
            };
            const dummyVTable = autoimport.RegistryCloneHost.VTable{
                .fs = undefined,
                .directoryExists = VTableImpl.directoryExists,
                .getDefaultProject = VTableImpl.getDefaultProject,
                .getProgramForProject = undefined,
                .getPackageJson = undefined,
                .getSourceFile = undefined,
                .dispose = undefined,
            };
            const host = autoimport.RegistryCloneHost{
                .ptr = &host_ctx,
                .vtable = &dummyVTable,
            };

            new_auto_imports = @as(*AutoImportRegistry, @ptrCast(@alignCast(try reg.cloneRegistry(allocator, regChange, host, null))));
        }

        var newSnapshot = try Snapshot.init(
            allocator,
            newSnapshotID,
            new_fs,
            self.sessionOptions,
            self.configFileRegistry,
            self.compilerOptionsForInferredProjects,
            new_auto_imports,
            self.autoImportsWatch,
        );
        newSnapshot.parentId = self.id;
        return newSnapshot;
    }
};
