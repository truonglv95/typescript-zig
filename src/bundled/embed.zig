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
pub fn wrapFS(fs: anytype) WrappedFS(@TypeOf(fs)) {
    return .{ .fs = fs };
}

pub fn WrappedFS(comptime FS: type) type {
    return struct {
        fs: FS,

        pub fn useCaseSensitiveFileNames(self: *@This()) bool {
            return self.fs.useCaseSensitiveFileNames();
        }

        pub fn fileExists(self: *@This(), path: []const u8) bool {
            if (splitPath(path)) |rest| {
                return embed_generated.embeddedContents.has(rest);
            }
            return self.fs.fileExists(path);
        }

        pub fn readFile(self: *@This(), allocator: std.mem.Allocator, path: []const u8) ?[]const u8 {
            if (splitPath(path)) |rest| {
                if (embed_generated.embeddedContents.get(rest)) |contents| {
                    return allocator.dupe(u8, contents) catch null;
                }
                return null;
            }
            return self.fs.readFile(allocator, path);
        }

        pub fn directoryExists(self: *@This(), path: []const u8) bool {
            if (splitPath(path)) |rest| {
                return std.mem.eql(u8, rest, "libs") or std.mem.eql(u8, rest, "");
            }
            return self.fs.directoryExists(path);
        }

        pub fn getAccessibleEntries(self: *@This(), allocator: std.mem.Allocator, path: []const u8) !@import("../vfs/vfs.zig").Entries {
            if (splitPath(path)) |rest| {
                var result = @import("../vfs/vfs.zig").Entries{};
                if (rest.len == 0) {
                    var dirs = std.ArrayList([]const u8).init(allocator);
                    try dirs.append("libs");
                    result.directories = try dirs.toOwnedSlice();
                } else if (std.mem.eql(u8, rest, "libs")) {
                    var files = std.ArrayList([]const u8).init(allocator);
                    for (libs_generated.LibNames) |lib| {
                        try files.append(lib);
                    }
                    result.files = try files.toOwnedSlice();
                }
                return result;
            }
            return try self.fs.getAccessibleEntries(allocator, path);
        }

        pub fn realpath(self: *@This(), allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
            if (splitPath(path) != null) {
                return try allocator.dupe(u8, path);
            }
            return try self.fs.realpath(allocator, path);
        }

        pub fn writeFile(self: *@This(), path: []const u8, data: []const u8) !void {
            if (splitPath(path) != null) {
                @panic("cannot write to embedded file system");
            }
            return try self.fs.writeFile(path, data);
        }
    };
}
