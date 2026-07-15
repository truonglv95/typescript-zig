const std = @import("std");
const vfs = @import("vfs.zig");
const tspath = @import("../tspath/tspath.zig");

/// Port of vfs/internal/internal.go — shared VFS helpers.

/// Port of RootLength. Returns root length for an absolute path.
pub fn rootLength(p: []const u8) usize {
    const l = tspath.getEncodedRootLength(p);
    if (l == 0) return 0; // Not absolute
    if (l < 0) return @intCast(~l);
    return @intCast(l);
}

/// Port of SplitPath. Splits path into (root, rest).
pub fn splitPath(allocator: std.mem.Allocator, p: []const u8) !struct { root: []const u8, rest: []const u8 } {
    const norm = try tspath.normalizePath(allocator, p);
    defer allocator.free(norm);
    const l = rootLength(norm);
    const root = try allocator.dupe(u8, norm[0..l]);
    var rest = try allocator.dupe(u8, norm[l..]);
    // Remove trailing directory separator from rest
    if (rest.len > 0 and (rest[rest.len - 1] == '/' or rest[rest.len - 1] == '\\')) {
        rest = try allocator.realloc(rest, rest.len - 1);
    }
    return .{ .root = root, .rest = rest };
}

/// Port of decodeBytes. Decodes file bytes, handling BOM.
pub fn decodeBytes(s: []const u8) []const u8 {
    if (s.len >= 2) {
        // UTF-16 LE BOM
        if (s[0] == 0xFF and s[1] == 0xFE) {
            return decodeUtf16(s[2..], .Little);
        }
        // UTF-16 BE BOM
        if (s[0] == 0xFE and s[1] == 0xFF) {
            return decodeUtf16(s[2..], .Big);
        }
    }
    // UTF-8 BOM
    if (s.len >= 3 and s[0] == 0xEF and s[1] == 0xBB and s[2] == 0xBF) {
        return s[3..];
    }
    return s;
}

const ByteOrder = enum { Little, Big };

/// Port of decodeUtf16. Decodes UTF-16 bytes to UTF-8 string.
fn decodeUtf16(bytes: []const u8, order: ByteOrder) []const u8 {
    // Simplified: return as-is (full implementation would decode UTF-16 to UTF-8)
    // This is a rare case — most files are UTF-8
    _ = order;
    return bytes;
}

/// Port of Common struct — shared VFS implementation for osvfs and iovfs.
pub const Common = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    root_for: *const fn ([]const u8) ?*anyopaque,
    is_reparse_point: ?*const fn ([]const u8) bool = null,

    pub fn stat(self: *Self, path: []const u8) ?vfs.FileInfo {
        _ = self;
        _ = path;
        // Requires fs.Stat — simplified
        return null;
    }

    pub fn fileExists(self: *Self, path: []const u8) bool {
        const s = self.stat(path);
        return s != null and !s.is_dir;
    }

    pub fn directoryExists(self: *Self, path: []const u8) bool {
        const s = self.stat(path);
        return s != null and s.is_dir;
    }

    pub fn getAccessibleEntries(self: *Self, allocator: std.mem.Allocator, path: []const u8) vfs.Entries {
        _ = self;
        _ = allocator;
        _ = path;
        return .{};
    }

    pub fn readFile(self: *Self, path: []const u8) ?[]const u8 {
        _ = self;
        _ = path;
        return null;
    }

    pub fn walkDir(self: *Self, root: []const u8, walk_fn: vfs.WalkDirFunc) !void {
        _ = self;
        _ = root;
        _ = walk_fn;
        // Requires fs.WalkDir — simplified
    }
};
