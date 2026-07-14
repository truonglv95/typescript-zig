const std = @import("std");
const core = @import("../core/core.zig");
const tspath = @import("../tspath/tspath.zig");
const projectcollection = @import("projectcollection.zig");
const snapshotfs = @import("snapshotfs.zig");
const ast = @import("../ast/ast.zig");
const compiler = @import("../compiler/program.zig");

pub const AutoImportBuilderFS = struct {
    builder: *snapshotfs.SnapshotFSBuilder,
    untrackedFiles: std.StringHashMap(*snapshotfs.FileHandle),

    pub fn init(allocator: std.mem.Allocator, builder: *snapshotfs.SnapshotFSBuilder) AutoImportBuilderFS {
        return .{
            .builder = builder,
            .untrackedFiles = std.StringHashMap(*snapshotfs.FileHandle).init(allocator),
        };
    }

    pub fn getFile(self: *AutoImportBuilderFS, fileName: []const u8) ?*snapshotfs.FileHandle {
        const path = self.builder.toPath(fileName);
        return self.getFileByPath(fileName, path);
    }

    pub fn getFileByPath(self: *AutoImportBuilderFS, fileName: []const u8, path: tspath.Path) ?*snapshotfs.FileHandle {
        if (self.builder.overlays.get(path)) |file| return file;
        if (self.builder.diskFiles.get(path)) |file| return file;
        if (self.untrackedFiles.get(path)) |file| return file;

        // mock read file from disk logic
        _ = fileName;
        return null;
    }
};

pub const AutoImportRegistryCloneHost = struct {
    projectCollection: *projectcollection.ProjectCollection,
    fs: *AutoImportBuilderFS,
    currentDirectory: []const u8,

    pub fn getProgramForProject(self: *AutoImportRegistryCloneHost, projectPath: tspath.Path) ?*compiler.Program {
        if (self.projectCollection.getProjectByPath(projectPath)) |proj| {
            return proj.getProgram();
        }
        return null;
    }
};
