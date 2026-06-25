const std = @import("std");
const core = @import("../core/core.zig");
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
        sessionOptions: *session.SessionOptions,
        configFileRegistry: ?*projectcollection.ConfigFileRegistry,
        compilerOptionsForInferredProjects: ?*core.CompilerOptions,
        autoImports: ?*AutoImportRegistry,
        autoImportsWatch: ?*WatchedFiles,
    ) !*Snapshot {
        var s = try allocator.create(Snapshot);
        var projCol = projectcollection.ProjectCollection.init(allocator);
        
        s.* = .{
            .id = id,
            .parentId = 0,
            .refCount = std.atomic.Value(i32).init(1),
            .sessionOptions = sessionOptions,
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

    pub fn dispose(self: *Snapshot, s: *session.Session) void {
        _ = s;
        // logic to clear caches and deref underlying structures
    }

    pub fn clone(self: *Snapshot, allocator: std.mem.Allocator, change: session.SnapshotChange, overlays: std.StringArrayHashMap(void), s: *session.Session) !*Snapshot {
        _ = change;
        _ = overlays;
        // mock clone
        const newSnapshotID = s.snapshotID.fetchAdd(1, .monotonic) + 1;
        var newSnapshot = try Snapshot.init(
            allocator,
            newSnapshotID,
            self.fs,
            self.sessionOptions,
            self.configFileRegistry,
            self.compilerOptionsForInferredProjects,
            self.autoImports,
            self.autoImportsWatch,
        );
        newSnapshot.parentId = self.id;
        return newSnapshot;
    }
};
