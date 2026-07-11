const std = @import("std");
const vfs = @import("../vfs.zig");

const OsFS = struct {
    case_sensitive: bool,

    fn useCaseSensitiveFileNames(ptr: *anyopaque) bool {
        const self: *OsFS = @ptrCast(@alignCast(ptr));
        return self.case_sensitive;
    }

    fn fileExists(ptr: *anyopaque, path: []const u8) bool {
        const self: *OsFS = @ptrCast(@alignCast(ptr));
        _ = self;
        return std.fs.cwd().access(path, .{}) == null;
    }

    fn directoryExists(ptr: *anyopaque, path: []const u8) bool {
        const self: *OsFS = @ptrCast(@alignCast(ptr));
        _ = self;
        if (std.fs.cwd().openDir(path, .{})) |dir| {
            dir.close();
            return true;
        } else |_| {
            return false;
        }
    }

    fn readFile(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
        const self: *OsFS = @ptrCast(@alignCast(ptr));
        _ = self;
        return std.fs.cwd().readFileAlloc(allocator, path, std.math.maxInt(usize)) catch null;
    }

    fn writeFile(ptr: *anyopaque, path: []const u8, data: []const u8) !void {
        const self: *OsFS = @ptrCast(@alignCast(ptr));
        _ = self;
        if (std.fs.path.dirname(path)) |dir| {
            try std.fs.cwd().makePath(dir);
        }
        try std.fs.cwd().writeFile(.{ .sub_path = path, .data = data });
    }

    fn getAccessibleEntries(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) vfs.Entries {
        const self: *OsFS = @ptrCast(@alignCast(ptr));
        _ = self;
        var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch return .{};
        defer dir.close();

        var files = std.ArrayListUnmanaged([]const u8).empty;
        var directories = std.ArrayListUnmanaged([]const u8).empty;
        defer files.deinit(allocator);
        defer directories.deinit(allocator);

        var it = dir.iterate();
        while (it.next() catch null) |entry| {
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
        return std.fs.cwd().realpathAlloc(allocator, path) catch null;
    }

    const vtable = vfs.FS.VTable{
        .useCaseSensitiveFileNames = useCaseSensitiveFileNames,
        .fileExists = fileExists,
        .directoryExists = directoryExists,
        .readFile = readFile,
        .writeFile = writeFile,
        .getAccessibleEntries = getAccessibleEntries,
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
