const std = @import("std");

pub const WalkFn = struct {
    ctx: ?*anyopaque = null,
    cb: ?*const fn (ctx: ?*anyopaque, path: []const u8, is_dir: bool) anyerror!void = null,

    pub fn invoke(self: WalkFn, path: []const u8, is_dir: bool) anyerror!void {
        if (self.cb) |f| {
            try f(self.ctx, path, is_dir);
        }
    }
};

pub fn walkDirGeneric(allocator: std.mem.Allocator, dir: []const u8, recursive: bool, fn_cb: WalkFn) anyerror!void {
    const stat = std.Io.Dir.cwd().statFile(dir) catch |err| {
        if (err == error.FileNotFound) return error.ENOENT;
        return err;
    };
    if (stat.kind != .directory) return error.NotDir;

    return walkDirGenericVisit(allocator, dir, recursive, fn_cb);
}

pub fn walkDirGenericVisit(allocator: std.mem.Allocator, dir: []const u8, recursive: bool, fn_cb: WalkFn) anyerror!void {
    var dir_handle = std.Io.Dir.cwd().openDir(dir, .{ .iterate = true }) catch |err| {
        if (err == error.AccessDenied or err == error.FileNotFound) {
            return;
        }
        return err;
    };
    defer dir_handle.close();

    if (fn_cb.cb != null) {
        try fn_cb.invoke(dir, true);
    }

    var it = dir_handle.iterate();
    while (try it.next()) |e| {
        const path = try std.fs.path.join(allocator, &.{ dir, e.name });
        defer allocator.free(path);

        if (e.kind == .directory) {
            if (recursive) {
                try walkDirGenericVisit(allocator, path, recursive, fn_cb);
            } else if (fn_cb.cb != null) {
                try fn_cb.invoke(path, true);
            }
        } else if (fn_cb.cb != null) {
            try fn_cb.invoke(path, false);
        }
    }
}
