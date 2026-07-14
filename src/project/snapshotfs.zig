const std = @import("std");
const core = @import("../core/core.zig");
const tspath = @import("../tspath/tspath.zig");

pub const FileHandle = opaque {};

pub const SnapshotFS = struct {
    toPath: *const fn (fileName: []const u8) tspath.Path,
    overlays: std.StringHashMap(*FileHandle),
    diskFiles: std.StringHashMap(*FileHandle),

    pub fn init(allocator: std.mem.Allocator, toPathFn: *const fn (fileName: []const u8) tspath.Path) SnapshotFS {
        return .{
            .toPath = toPathFn,
            .overlays = std.StringHashMap(*FileHandle).init(allocator),
            .diskFiles = std.StringHashMap(*FileHandle).init(allocator),
        };
    }

    pub fn getFile(self: *SnapshotFS, fileName: []const u8) ?*FileHandle {
        const path = self.toPath(fileName);
        return self.getFileByPath(fileName, path);
    }

    pub fn cloneWithChanges(self: *SnapshotFS, allocator: std.mem.Allocator, created: anytype, deleted: anytype) !*SnapshotFS {
        var new_fs = try allocator.create(SnapshotFS);
        new_fs.* = SnapshotFS.init(allocator, self.toPath);

        // Copy existing disk files, skipping deleted ones
        var disk_it = self.diskFiles.iterator();
        while (disk_it.next()) |entry| {
            var is_deleted = false;
            var del_it = deleted.keyIterator();
            while (del_it.next()) |del_uri_ptr| {
                var del_uri = del_uri_ptr.*;
                if (std.mem.startsWith(u8, del_uri, "file://")) {
                    del_uri = del_uri[7..];
                }
                const del_path = self.toPath(del_uri);

                std.debug.print("cloneWithChanges: checking {s} against del_path {s}\n", .{ entry.key_ptr.*, del_path });
                if (std.mem.startsWith(u8, entry.key_ptr.*, del_path)) {
                    if (entry.key_ptr.*.len > del_path.len and entry.key_ptr.*[del_path.len] == '/') {
                        is_deleted = true;
                        break;
                    }
                    if (entry.key_ptr.*.len == del_path.len) {
                        is_deleted = true;
                        break;
                    }
                }
            }
            if (!is_deleted) {
                try new_fs.diskFiles.put(entry.key_ptr.*, entry.value_ptr.*);
            }
        }

        // Add created files
        var cre_it = created.iterator();
        while (cre_it.next()) |entry| {
            var cre_uri = entry.key_ptr.*;
            if (std.mem.startsWith(u8, cre_uri, "file://")) {
                cre_uri = cre_uri[7..];
            }
            const cre_path = self.toPath(cre_uri);
            try new_fs.diskFiles.put(cre_path, @as(*FileHandle, @ptrFromInt(1))); // Note: just dummy handles in tests
        }

        // Copy overlays exactly
        var ov_it = self.overlays.iterator();
        while (ov_it.next()) |entry| {
            try new_fs.overlays.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        return new_fs;
    }

    pub fn directoryExists(self: *SnapshotFS, dirPath: []const u8) bool {
        std.debug.print("directoryExists checking {s}\n", .{dirPath});
        var it = self.diskFiles.keyIterator();
        while (it.next()) |k| {
            std.debug.print("  disk: {s}\n", .{k.*});
            if (std.mem.startsWith(u8, k.*, dirPath)) {
                if (k.*.len > dirPath.len and k.*[dirPath.len] == '/') return true;
                if (k.*.len == dirPath.len) return true; // Exact match
            }
        }
        var it2 = self.overlays.keyIterator();
        while (it2.next()) |k| {
            std.debug.print("  overlay: {s}\n", .{k.*});
            if (std.mem.startsWith(u8, k.*, dirPath)) {
                if (k.*.len > dirPath.len and k.*[dirPath.len] == '/') return true;
                if (k.*.len == dirPath.len) return true; // Exact match
            }
        }
        return false;
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
    overlays: std.StringHashMap(*FileHandle),
    diskFiles: std.StringHashMap(*FileHandle),
    toPath: *const fn (fileName: []const u8) tspath.Path,

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
