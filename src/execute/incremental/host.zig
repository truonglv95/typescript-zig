const std = @import("std");

//! Incremental compilation host.
//!
//! Port of `internal/execute/incremental/host.go` (45 LOC).
//!
//! Provides file modification time tracking for incremental builds.

const compiler = @import("../../compiler/compiler.zig");
const vfs = @import("../../vfs/vfs.zig");

/// Host interface for incremental compilation.
/// Port of Go's `incremental.Host`.
pub const Host = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        fs: *const fn (ptr: *anyopaque) *vfs.FS,
        getMTime: *const fn (ptr: *anyopaque, file_name: []const u8) i128,
        setMTime: *const fn (ptr: *anyopaque, file_name: []const u8, mtime: i128) anyerror!void,
    };

    pub fn fs(self: Host) *vfs.FS {
        return self.vtable.fs(self.ptr);
    }

    pub fn getMTime(self: Host, file_name: []const u8) i128 {
        return self.vtable.getMTime(self.ptr, file_name);
    }

    pub fn setMTime(self: Host, file_name: []const u8, mtime: i128) !void {
        return self.vtable.setMTime(self.ptr, file_name, mtime);
    }
};

/// Gets the modification time of a file via a CompilerHost.
/// Port of Go's `GetMTime`.
pub fn getMTime(host: compiler.CompilerHost, file_name: []const u8) i128 {
    const stat = host.fs().stat(file_name) orelse return 0;
    return stat.mod_time_unix_nano;
}
