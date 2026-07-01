const std = @import("std");

pub const ExtensionTs = ".ts";
pub const ExtensionTsx = ".tsx";
pub const ExtensionJs = ".js";
pub const ExtensionJsx = ".jsx";
pub const ExtensionJson = ".json";
pub const ExtensionDts = ".d.ts";
pub const ExtensionDmts = ".d.mts";
pub const ExtensionDcts = ".d.cts";
pub const ExtensionMjs = ".mjs";
pub const ExtensionMts = ".mts";
pub const ExtensionCjs = ".cjs";
pub const ExtensionCts = ".cts";

pub const extensionsToRemove = [_][]const u8{ ExtensionDts, ExtensionDmts, ExtensionDcts, ExtensionMjs, ExtensionMts, ExtensionCjs, ExtensionCts, ExtensionTs, ExtensionJs, ExtensionTsx, ExtensionJsx, ExtensionJson };

pub fn tryGetExtensionFromPath(path: []const u8) []const u8 {
    for (extensionsToRemove) |ext| {
        if (std.mem.endsWith(u8, path, ext)) {
            return ext;
        }
    }
    return "";
}

pub fn toPath(allocator: std.mem.Allocator, fileName: []const u8, basePath: ?[]const u8, useCaseSensitiveFileNames: bool) !Path {
    _ = allocator;
    _ = basePath;
    _ = useCaseSensitiveFileNames;
    return fileName;
}

pub fn getBaseFileName(path: []const u8) []const u8 {
    return std.fs.path.basename(path);
}

pub fn removeExtension(path: []const u8, extension: []const u8) []const u8 {
    if (std.mem.endsWith(u8, path, extension)) {
        return path[0 .. path.len - extension.len];
    }
    return path;
}

pub fn removeFileExtension(path: []const u8) []const u8 {
    for (extensionsToRemove) |ext| {
        if (std.mem.endsWith(u8, path, ext)) {
            return path[0 .. path.len - ext.len];
        }
    }
    return path;
}

pub const SupportedDeclarationExtensions = [_][]const u8{ ExtensionDts, ExtensionDcts, ExtensionDmts };

pub fn isDeclarationFileName(fileName: []const u8) bool {
    return getDeclarationFileExtension(fileName).len > 0;
}

pub const SupportedTSImplementationExtensions = [_][]const u8{ ExtensionTs, ExtensionTsx, ExtensionMts, ExtensionCts };

pub fn hasImplementationTSFileExtension(path: []const u8) bool {
    for (SupportedTSImplementationExtensions) |ext| {
        if (std.mem.endsWith(u8, path, ext)) {
            return !isDeclarationFileName(path);
        }
    }
    return false;
}

pub const supportedTSExtensionsForExtractExtension = [_][]const u8{ ExtensionTs, ExtensionTsx, ExtensionDts, ExtensionMts, ExtensionDmts, ExtensionCts, ExtensionDcts };

pub fn tryExtractTSExtension(fileName: []const u8) []const u8 {
    for (supportedTSExtensionsForExtractExtension) |ext| {
        if (std.mem.endsWith(u8, fileName, ext)) {
            return ext;
        }
    }
    return "";
}

pub fn getDeclarationFileExtension(fileName: []const u8) []const u8 {
    const base = getBaseFileName(fileName);
    for (SupportedDeclarationExtensions) |ext| {
        if (std.mem.endsWith(u8, base, ext)) {
            return ext;
        }
    }
    if (std.mem.endsWith(u8, base, ExtensionTs)) {
        if (std.mem.indexOf(u8, base, ".d.")) |idx| {
            return base[idx..];
        }
    }
    return "";
}

pub const GetBaseFileName = getBaseFileName;

pub fn GetAnyExtensionFromPath(path: []const u8, ext: ?*anyopaque, ignoreCase: bool) []const u8 {
    _ = ext;
    _ = ignoreCase;
    return std.fs.path.extension(path);
}

pub fn normalizePath(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    // Simple implementation for testing
    return try normalizeSlashes(allocator, path);
}

pub fn GetNormalizedAbsolutePath(allocator: std.mem.Allocator, path: []const u8, currentDirectory: ?[]const u8) ![]const u8 {
    _ = allocator;
    _ = currentDirectory;
    return path; // stub
}

pub fn FileExtensionIs(path: []const u8, extension: []const u8) bool {
    return std.mem.endsWith(u8, path, extension);
}

pub fn GetPathComponentsRelativeTo(allocator: std.mem.Allocator, from: []const u8, to: []const u8, options: anytype) ![][]const u8 {
    _ = from;
    _ = to;
    _ = options;
    return allocator.alloc([]const u8, 0);
}

pub fn GetPathFromPathComponents(allocator: std.mem.Allocator, components: [][]const u8) ![]const u8 {
    _ = allocator;
    _ = components;
    return "";
}

pub const Path = []const u8;

pub const directory_separator: u8 = '/';
pub const url_scheme_separator: []const u8 = "://";

pub fn isAnyDirectorySeparator(char: u8) bool {
    return char == '/' or char == '\\';
}

pub fn isUrl(path: []const u8) bool {
    return getEncodedRootLength(path) < 0;
}

pub fn isRootedDiskPath(path: []const u8) bool {
    return getEncodedRootLength(path) > 0;
}
pub const IsRootedDiskPath = isRootedDiskPath;

pub fn isDiskPathRoot(path: []const u8) bool {
    const root_len = getEncodedRootLength(path);
    return root_len > 0 and root_len == path.len;
}

pub fn isDynamicFileName(fileName: []const u8) bool {
    return std.mem.startsWith(u8, fileName, "^/");
}

pub fn pathIsAbsolute(path: []const u8) bool {
    return getEncodedRootLength(path) != 0;
}

pub fn hasTrailingDirectorySeparator(path: []const u8) bool {
    return path.len > 0 and isAnyDirectorySeparator(path[path.len - 1]);
}

pub fn combinePaths(allocator: std.mem.Allocator, first_path: []const u8, paths: []const []const u8) ![]const u8 {
    var b = std.ArrayList(u8).init(allocator);
    defer b.deinit();

    const fp_normalized = try normalizeSlashes(allocator, first_path);
    defer allocator.free(fp_normalized);
    try b.appendSlice(fp_normalized);

    var start: usize = 0;

    for (paths) |trailing_path| {
        if (trailing_path.len == 0) continue;
        const tp_norm = try normalizeSlashes(allocator, trailing_path);
        defer allocator.free(tp_norm);

        if (b.items[start..].len == 0 or getRootLength(tp_norm) != 0) {
            start = b.items.len;
            try b.appendSlice(tp_norm);
        } else {
            if (!hasTrailingDirectorySeparator(b.items[start..])) {
                try b.append(directory_separator);
            }
            try b.appendSlice(tp_norm);
        }
    }

    return try allocator.dupe(u8, b.items[start..]);
}

pub fn getPathComponents(allocator: std.mem.Allocator, path: []const u8, current_directory: []const u8) ![][]const u8 {
    const combined = try combinePaths(allocator, current_directory, &[_][]const u8{path});
    defer allocator.free(combined);
    return pathComponents(allocator, combined, getRootLength(combined));
}

fn pathComponents(allocator: std.mem.Allocator, path: []const u8, root_length: usize) ![][]const u8 {
    var res = std.ArrayList([]const u8).init(allocator);
    try res.append(try allocator.dupe(u8, path[0..root_length]));

    var iter = std.mem.splitScalar(u8, path[root_length..], '/');
    while (iter.next()) |part| {
        if (iter.peek() == null and part.len == 0) continue;
        try res.append(try allocator.dupe(u8, part));
    }
    return res.toOwnedSlice();
}

pub fn isVolumeCharacter(char: u8) bool {
    return (char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z');
}

pub fn getEncodedRootLength(path: []const u8) isize {
    const ln = path.len;
    if (ln == 0) return 0;
    const ch0 = path[0];

    if (ch0 == '/' or ch0 == '\\') {
        if (ln == 1 or path[1] != ch0) return 1;
        const offset = 2;
        const p1 = std.mem.indexOfScalar(u8, path[offset..], ch0);
        if (p1 == null) return @as(isize, @intCast(ln));
        return @as(isize, @intCast(p1.? + offset + 1));
    }

    if (isVolumeCharacter(ch0) and ln > 1 and path[1] == ':') {
        if (ln == 2) return 2;
        const ch2 = path[2];
        if (ch2 == '/' or ch2 == '\\') return 3;
    }

    if (ch0 == '^' and ln > 1 and path[1] == '/') return 2;

    const scheme_end = std.mem.indexOf(u8, path, url_scheme_separator);
    if (scheme_end != null) {
        const authority_start = scheme_end.? + url_scheme_separator.len;
        const authority_len = std.mem.indexOfScalar(u8, path[authority_start..], '/');
        if (authority_len != null) {
            const authority_end = authority_start + authority_len.?;
            const scheme = path[0..scheme_end.?];
            const authority = path[authority_start..authority_end];

            if (std.mem.eql(u8, scheme, "file") and (authority.len == 0 or std.mem.eql(u8, authority, "localhost")) and (ln > authority_end + 2) and isVolumeCharacter(path[authority_end + 1])) {
                const vol_sep_end = getFileUrlVolumeSeparatorEnd(path, authority_end + 2);
                if (vol_sep_end != -1) {
                    if (vol_sep_end == ln) return ~@as(isize, @intCast(vol_sep_end));
                    if (path[@as(usize, @intCast(vol_sep_end))] == '/') return ~(@as(isize, @intCast(vol_sep_end)) + 1);
                }
            }
            return ~(@as(isize, @intCast(authority_end)) + 1);
        }
        return ~@as(isize, @intCast(ln));
    }

    return 0;
}

fn getFileUrlVolumeSeparatorEnd(url: []const u8, start: usize) isize {
    if (url.len <= start) return -1;
    const ch0 = url[start];
    if (ch0 == ':') return @as(isize, @intCast(start + 1));
    if (ch0 == '%' and url.len > start + 2 and url[start + 1] == '3') {
        const ch2 = url[start + 2];
        if (ch2 == 'a' or ch2 == 'A') return @as(isize, @intCast(start + 3));
    }
    return -1;
}

pub fn getRootLength(path: []const u8) usize {
    const r = getEncodedRootLength(path);
    if (r < 0) return @as(usize, @intCast(~r));
    return @as(usize, @intCast(r));
}

pub fn normalizeSlashes(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    const res = try allocator.dupe(u8, path);
    std.mem.replaceScalar(u8, res, '\\', '/');
    return res;
}

pub fn getDirectoryPath(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    const norm = try normalizeSlashes(allocator, path);
    defer allocator.free(norm);

    const root_len = getRootLength(norm);
    if (root_len == norm.len) return allocator.dupe(u8, norm);

    var no_trail = norm;
    if (hasTrailingDirectorySeparator(no_trail)) {
        no_trail = no_trail[0 .. no_trail.len - 1];
    }
    const last_slash = std.mem.lastIndexOfScalar(u8, no_trail, '/');
    if (last_slash == null) {
        return allocator.dupe(u8, no_trail[0..root_len]);
    }
    const limit = @max(root_len, last_slash.?);
    return allocator.dupe(u8, no_trail[0..limit]);
}

pub const ComparePathsOptions = struct {
    useCaseSensitiveFileNames: bool = true,
    currentDirectory: []const u8 = "",
};

pub fn comparePaths(a: []const u8, b: []const u8, options: ComparePathsOptions) i32 {
    if (std.mem.eql(u8, a, b)) return 0;
    if (a.len == 0) return -1;
    if (b.len == 0) return 1;

    if (options.useCaseSensitiveFileNames) {
        return compareStrings(a, b);
    } else {
        return compareStringsCaseInsensitive(a, b);
    }
}

fn compareStrings(a: []const u8, b: []const u8) i32 {
    const min_len = @min(a.len, b.len);
    for (a[0..min_len], b[0..min_len]) |char_a, char_b| {
        if (char_a < char_b) return -1;
        if (char_a > char_b) return 1;
    }
    if (a.len < b.len) return -1;
    if (a.len > b.len) return 1;
    return 0;
}

fn compareStringsCaseInsensitive(a: []const u8, b: []const u8) i32 {
    const min_len = @min(a.len, b.len);
    for (a[0..min_len], b[0..min_len]) |char_a, char_b| {
        const lower_a = std.ascii.toLower(char_a);
        const lower_b = std.ascii.toLower(char_b);
        if (lower_a < lower_b) return -1;
        if (lower_a > lower_b) return 1;
    }
    if (a.len < b.len) return -1;
    if (a.len > b.len) return 1;
    return 0;
}

pub fn ensureTrailingDirectorySeparator(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    if (!hasTrailingDirectorySeparator(path)) {
        return try std.fmt.allocPrint(allocator, "{s}/", .{path});
    }
    return try allocator.dupe(u8, path);
}
