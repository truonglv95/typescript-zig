const std = @import("std");
const vfs = @import("../vfs.zig");

const OsFS = struct {
    case_sensitive: bool,

    fn useCaseSensitiveFileNames(ptr: *anyopaque) bool {
        const self: *OsFS = @ptrCast(@alignCast(ptr));
        return self.case_sensitive;
    }

    var global_threaded: ?std.Io.Threaded = null;

    fn getIo() std.Io {
        if (global_threaded == null) {
            global_threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
        }
        return global_threaded.?.io();
    }

    fn fileExists(ptr: *anyopaque, path: []const u8) bool {
        const self: *OsFS = @ptrCast(@alignCast(ptr));
        _ = self;
        std.Io.Dir.cwd().access(getIo(), path, .{}) catch return false;
        return true;
    }

    fn directoryExists(ptr: *anyopaque, path: []const u8) bool {
        const self: *OsFS = @ptrCast(@alignCast(ptr));
        _ = self;
        if (std.Io.Dir.cwd().openDir(getIo(), path, .{})) |dir| {
            dir.close(getIo());
            return true;
        } else |_| {
            return false;
        }
    }

    fn readFile(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
        const self: *OsFS = @ptrCast(@alignCast(ptr));
        _ = self;
        return std.Io.Dir.cwd().readFileAlloc(getIo(), path, allocator, .limited(std.math.maxInt(usize))) catch null;
    }

    fn writeFile(ptr: *anyopaque, path: []const u8, data: []const u8) !void {
        const self: *OsFS = @ptrCast(@alignCast(ptr));
        _ = self;
        if (std.fs.path.dirname(path)) |dir| {
            try std.Io.Dir.cwd().createDirPath(getIo(), dir);
        }
        try std.Io.Dir.cwd().writeFile(getIo(), .{ .sub_path = path, .data = data });
    }

    fn getAccessibleEntries(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) vfs.Entries {
        const self: *OsFS = @ptrCast(@alignCast(ptr));
        _ = self;
        var dir = std.Io.Dir.cwd().openDir(getIo(), path, .{ .iterate = true }) catch return .{};
        defer dir.close(getIo());

        var files = std.ArrayListUnmanaged([]const u8).empty;
        var directories = std.ArrayListUnmanaged([]const u8).empty;
        defer files.deinit(allocator);
        defer directories.deinit(allocator);

        var it = dir.iterate();
        while (it.next(getIo()) catch null) |entry| {
            const name = allocator.dupe(u8, entry.name) catch continue;
            switch (entry.kind) {
                .file => files.append(allocator, name) catch allocator.free(name),
                .directory => directories.append(allocator, name) catch allocator.free(name),
                else => allocator.free(name),
            }
        }

        return .{
            .files = files.toOwnedSlice(allocator) catch &.{},
            .directories = directories.toOwnedSlice(allocator) catch &.{},
        };
    }

    fn realpath(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) ?[]const u8 {
        const self: *OsFS = @ptrCast(@alignCast(ptr));
        _ = self;
        return std.Io.Dir.cwd().realPathFileAlloc(getIo(), path, allocator) catch null;
    }

    fn appendFile(ptr: *anyopaque, path: []const u8, data: []const u8) anyerror!void {
        _ = ptr;
        if (std.fs.path.dirname(path)) |dir| {
            std.Io.Dir.cwd().createDirPath(getIo(), dir) catch {};
        }
        var file = try std.Io.Dir.cwd().createFile(getIo(), path, .{ .truncate = false });
        defer file.close(getIo());
        const len = try file.length(getIo());
        try file.writePositionalAll(getIo(), data, len);
    }

    fn remove(ptr: *anyopaque, path: []const u8) anyerror!void {
        _ = ptr;
        if (std.fs.path.isAbsolute(path)) {
            std.Io.Dir.cwd().deleteTree(getIo(), path) catch {};
        } else {
            std.Io.Dir.cwd().deleteTree(getIo(), path) catch {};
        }
    }

    fn chtimes(ptr: *anyopaque, path: []const u8, atime: i128, mtime: i128) anyerror!void {
        _ = atime; _ = mtime;
        _ = ptr;
        if (std.fs.path.isAbsolute(path)) {
            var file = std.Io.Dir.cwd().openFile(getIo(), path, .{}) catch return;
            defer file.close(getIo());
            // file.updateTimes(atime, mtime) catch {};
        } else {
            var file = std.Io.Dir.cwd().openFile(getIo(), path, .{}) catch return;
            defer file.close(getIo());
            // file.updateTimes(atime, mtime) catch {};
        }
    }

    fn stat(ptr: *anyopaque, path: []const u8) ?vfs.FileInfo {
        _ = ptr;
        _ = path;
        return null;
    }

    fn walkDir(ptr: *anyopaque, root: []const u8, walk_fn: vfs.WalkDirFunc) anyerror!void {
        _ = ptr;
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        const root_entry = vfs.DirEntry{
            .name = std.fs.path.basename(root),
            .is_dir = true,
            .type = 0,
        };

        walk_fn(root, root_entry, null) catch |err| {
            if (err == vfs.skip_dir or err == vfs.skip_all) return;
            return err;
        };

        try walkDirInner(arena.allocator(), root, walk_fn);
    }

    fn walkDirInner(allocator: std.mem.Allocator, current_path: []const u8, walk_fn: vfs.WalkDirFunc) anyerror!void {
        var dir = if (std.fs.path.isAbsolute(current_path)) 
            std.Io.Dir.cwd().openDir(getIo(), current_path, .{ .iterate = true }) catch |err| {
                try walk_fn(current_path, null, err);
                return;
            }
        else 
            std.Io.Dir.cwd().openDir(getIo(), current_path, .{ .iterate = true }) catch |err| {
                try walk_fn(current_path, null, err);
                return;
            };
        defer dir.close(getIo());

        var it = dir.iterate();
        while (it.next(getIo()) catch null) |entry| {
            const path = std.fs.path.join(allocator, &.{ current_path, entry.name }) catch continue;
            const is_dir = entry.kind == .directory;
            const vfs_entry = vfs.DirEntry{
                .name = entry.name,
                .is_dir = is_dir,
                .type = 0,
            };

            var skip_children = false;
            walk_fn(path, vfs_entry, null) catch |err| {
                if (err == vfs.skip_dir) {
                    skip_children = true;
                } else if (err == vfs.skip_all) {
                    return err;
                } else {
                    return err;
                }
            };

            if (is_dir and !skip_children) {
                walkDirInner(allocator, path, walk_fn) catch |err| {
                    if (err == vfs.skip_all) return err;
                };
            }
        }
    }

    const vtable = vfs.FS.VTable{
        .useCaseSensitiveFileNames = useCaseSensitiveFileNames,
        .fileExists = fileExists,
        .directoryExists = directoryExists,
        .readFile = readFile,
        .writeFile = writeFile,
        .appendFile = appendFile,
        .remove = remove,
        .chtimes = chtimes,
        .getAccessibleEntries = getAccessibleEntries,
        .stat = stat,
        .walkDir = walkDir,
        .realpath = realpath,
    };

    pub fn asVfs(self: *OsFS) vfs.FS {
        return .{ .ptr = self, .vtable = &vtable };
    }
};

var global_instance = OsFS{
    .case_sensitive = builtinCaseSensitive(),
};
var global_vfs = global_instance.asVfs();

fn builtinCaseSensitive() bool {
    if (@import("builtin").os.tag == .windows) return false;
    return true;
}

/// Legacy API used by testrunner: returns OS-backed filesystem.
pub const OSVFS = struct {
    pub fn ReadFile(self: *OSVFS, allocator: std.mem.Allocator, filename: []const u8) ![]u8 {
        _ = self;
        return global_vfs.readFile(allocator, filename) orelse error.FileNotFound;
    }
};

var legacy_instance = OSVFS{};

pub fn FS() *OSVFS {
    return &legacy_instance;
}

pub fn fs() vfs.FS {
    return global_vfs;
}
