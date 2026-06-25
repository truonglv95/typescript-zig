const std = @import("std");
const core = @import("../core/core.zig");
const tspath = @import("../tspath/tspath.zig");

pub const FileHandle = opaque {};

pub const SnapshotFS = struct {
    toPath: *const fn(fileName: []const u8) tspath.Path,
    overlays: std.StringArrayHashMap(*FileHandle),
    diskFiles: std.StringArrayHashMap(*FileHandle),
    
    pub fn init(allocator: std.mem.Allocator, toPathFn: *const fn(fileName: []const u8) tspath.Path) SnapshotFS {
        return .{
            .toPath = toPathFn,
            .overlays = std.StringArrayHashMap(*FileHandle).init(allocator),
            .diskFiles = std.StringArrayHashMap(*FileHandle).init(allocator),
        };
    }

    pub fn getFile(self: *SnapshotFS, fileName: []const u8) ?*FileHandle {
        const path = self.toPath(fileName);
        return self.getFileByPath(fileName, path);
    }

    pub fn fileExists(self: *SnapshotFS, fileName: []const u8, path: tspath.Path) bool {
        _ = fileName;
        if (self.overlays.contains(path)) return true;
        if (self.diskFiles.contains(path)) return true;
        return false;
    }

    pub fn getFileByPath(self: *SnapshotFS, fileName: []const u8, path: tspath.Path) ?*FileHandle {
        _ = fileName;
        if (self.overlays.get(path)) |file| return file;
        if (self.diskFiles.get(path)) |file| return file;
        return null;
    }
};

pub const SnapshotFSBuilder = struct {
    overlays: std.StringArrayHashMap(*FileHandle),
    diskFiles: std.StringArrayHashMap(*FileHandle),
    toPath: *const fn(fileName: []const u8) tspath.Path,

    pub fn getFile(self: *SnapshotFSBuilder, fileName: []const u8) ?*FileHandle {
        const path = self.toPath(fileName);
        return self.getFileByPath(fileName, path);
    }

    pub fn getFileByPath(self: *SnapshotFSBuilder, fileName: []const u8, path: tspath.Path) ?*FileHandle {
        _ = fileName;
        if (self.overlays.get(path)) |file| return file;
        if (self.diskFiles.get(path)) |file| return file;
        return null;
    }
};
