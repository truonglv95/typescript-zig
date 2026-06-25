const std = @import("std");
const libs_generated = @import("libs_generated.zig");
const embed_generated = @import("embed_generated.zig");

pub const embedded = true;
const scheme = "bundled:///";

pub fn splitPath(path: []const u8) ?[]const u8 {
    if (std.mem.startsWith(u8, path, scheme)) {
        return path[scheme.len..];
    }
    return null;
}

pub fn libPath() []const u8 {
    return scheme ++ "libs";
}

pub fn IsBundled(path: []const u8) bool {
    return splitPath(path) != null;
}

// In typescript-go, WrapFS wraps a vfs.FS.
// We provide a stub for WrapFS, since vfs.FS in Zig is not fully defined yet.
// When it is defined, we can implement wrappedFS.
pub fn wrapFS(fs: anytype) @TypeOf(fs) {
    // TODO: implement vfs wrapper when vfs is fully implemented.
    return fs;
}
