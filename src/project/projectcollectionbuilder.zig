const std = @import("std");
const core = @import("../core/core.zig");
const tspath = @import("../tspath/tspath.zig");
const project = @import("project.zig");
const projectcollection = @import("projectcollection.zig");
const configfileregistry = @import("configfileregistry.zig");
const snapshotfs = @import("snapshotfs.zig");
const filechange = @import("filechange.zig");
const session = @import("session.zig");

pub const ProjectCollectionBuilder = struct {
    allocator: std.mem.Allocator,

    snapshotID: u64,
    fs: *snapshotfs.SnapshotFSBuilder,

    // Core state built up
    projectCollection: *projectcollection.ProjectCollection,
    configFileRegistry: *configfileregistry.ConfigFileRegistry,

    // Original states
    oldProjectCollection: *projectcollection.ProjectCollection,
    oldConfigFileRegistry: *configfileregistry.ConfigFileRegistry,

    apiOpenedProjects: std.StringHashMap(void),
    compilerOptionsForInferredProjects: ?*core.CompilerOptions,
    sessionOptions: *session.SessionOptions,
    customConfigFileName: []const u8,

    pub fn init(
        allocator: std.mem.Allocator,
        snapshotID: u64,
        fs: *snapshotfs.SnapshotFSBuilder,
        oldProjectCollection: *projectcollection.ProjectCollection,
        oldConfigFileRegistry: *configfileregistry.ConfigFileRegistry,
        apiOpenedProjects: std.StringHashMap(void),
        compilerOptionsForInferredProjects: ?*core.CompilerOptions,
        sessionOptions: *session.SessionOptions,
        customConfigFileName: []const u8,
    ) !*ProjectCollectionBuilder {
        var builder = try allocator.create(ProjectCollectionBuilder);

        var newConfigFileRegistry = try oldConfigFileRegistry.clone();
        var newProjectCollection = projectcollection.ProjectCollection.init(allocator);

        builder.* = .{
            .allocator = allocator,
            .snapshotID = snapshotID,
            .fs = fs,
            .projectCollection = try allocator.create(projectcollection.ProjectCollection),
            .configFileRegistry = newConfigFileRegistry,
            .oldProjectCollection = oldProjectCollection,
            .oldConfigFileRegistry = oldConfigFileRegistry,
            .apiOpenedProjects = apiOpenedProjects,
            .compilerOptionsForInferredProjects = compilerOptionsForInferredProjects,
            .sessionOptions = sessionOptions,
            .customConfigFileName = customConfigFileName,
        };
        builder.projectCollection.* = newProjectCollection;
        return builder;
    }

    pub fn didUpdateATAState(self: *ProjectCollectionBuilder, ataChanges: std.StringHashMap(void), logger: ?*project.LogTree) void {
        _ = self;
        _ = ataChanges;
        _ = logger;
    }

    pub fn didChangeCustomConfigFileName(self: *ProjectCollectionBuilder, logger: ?*project.LogTree) void {
        _ = self;
        _ = logger;
    }

    pub fn didChangeFiles(self: *ProjectCollectionBuilder, changes: filechange.FileChangeSummary, logger: ?*project.LogTree) void {
        _ = self;
        _ = changes;
        _ = logger;
    }

    pub fn didRequestFile(self: *ProjectCollectionBuilder, uri: []const u8, configuredProjectsOnly: bool, logger: ?*project.LogTree) void {
        _ = self;
        _ = uri;
        _ = configuredProjectsOnly;
        _ = logger;
    }

    pub fn didRequestProject(self: *ProjectCollectionBuilder, projectId: tspath.Path, logger: ?*project.LogTree) void {
        _ = self;
        _ = projectId;
        _ = logger;
    }

    pub fn finalize(self: *ProjectCollectionBuilder, logger: ?*project.LogTree) struct { *projectcollection.ProjectCollection, *configfileregistry.ConfigFileRegistry } {
        _ = logger;
        return .{ self.projectCollection, self.configFileRegistry };
    }
};
