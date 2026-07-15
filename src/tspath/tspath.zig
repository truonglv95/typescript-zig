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

pub fn getNormalizedAbsolutePath(allocator: std.mem.Allocator, fileName: []const u8, currentDirectory: []const u8) ![]const u8 {
    const rootLength = getRootLength(fileName);
    var combined: []const u8 = undefined;
    var to_free: ?[]const u8 = null;
    defer if (to_free) |f| allocator.free(f);

    if (rootLength == 0 and currentDirectory.len > 0) {
        combined = try combinePaths(allocator, currentDirectory, &[_][]const u8{fileName});
        to_free = combined;
    } else {
        combined = try normalizeSlashes(allocator, fileName);
        to_free = combined;
    }

    if (hasRelativePathSegment(combined)) {
        var components = std.ArrayList([]const u8).empty;
        defer components.deinit(allocator);

        const root_len = getRootLength(combined);
        try components.append(allocator, combined[0..root_len]);

        var i: usize = root_len;
        while (i < combined.len) {
            while (i < combined.len and combined[i] == '/') : (i += 1) {}
            if (i >= combined.len) break;
            
            const start = i;
            while (i < combined.len and combined[i] != '/') : (i += 1) {}
            const comp = combined[start..i];
            
            if (std.mem.eql(u8, comp, "") or std.mem.eql(u8, comp, ".")) {
                continue;
            }
            if (std.mem.eql(u8, comp, "..")) {
                if (components.items.len > 1) {
                    if (!std.mem.eql(u8, components.items[components.items.len - 1], "..")) {
                        _ = components.pop();
                        continue;
                    }
                } else if (components.items[0].len != 0) {
                    continue; // Absolute path, can't go above root
                }
            }
            try components.append(allocator, comp);
        }

        var res = std.ArrayList(u8).empty;
        try res.appendSlice(allocator, components.items[0]);
        if (components.items[0].len > 0 and !hasTrailingDirectorySeparator(components.items[0])) {
            // Ensure trailing slash for root if needed, actually GetPathFromPathComponents does this
        }
        
        var first = true;
        for (components.items[1..]) |comp| {
            if (!first or (components.items[0].len > 0 and !hasTrailingDirectorySeparator(components.items[0]))) {
                try res.append(allocator, '/');
            }
            try res.appendSlice(allocator, comp);
            first = false;
        }
        
        if (res.items.len > rootLength) {
            // Remove trailing slash
            if (res.items.len > 0 and res.items[res.items.len - 1] == '/') {
                _ = res.pop();
            }
            return res.toOwnedSlice(allocator);
        }
        if (res.items.len == rootLength and rootLength != 0) {
            if (res.items.len > 0 and res.items[res.items.len - 1] != '/') {
                try res.append(allocator, '/');
            }
            return res.toOwnedSlice(allocator);
        }
        return res.toOwnedSlice(allocator);
    }

    return allocator.dupe(u8, combined);
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

pub fn getCanonicalFileName(allocator: std.mem.Allocator, fileName: []const u8, useCaseSensitiveFileNames: bool) ![]const u8 {
    if (useCaseSensitiveFileNames) {
        return try allocator.dupe(u8, fileName);
    }
    return try std.ascii.allocLowerString(allocator, fileName);
}

pub fn getDeclarationEmitExtensionForPath(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    _ = allocator;
    if (std.mem.endsWith(u8, path, ExtensionMts) or std.mem.endsWith(u8, path, ExtensionMjs)) {
        return ExtensionDmts;
    } else if (std.mem.endsWith(u8, path, ExtensionCts) or std.mem.endsWith(u8, path, ExtensionCjs)) {
        return ExtensionDcts;
    }
    return ExtensionDts;
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
    const norm_slashes = try normalizeSlashes(allocator, path);
    defer allocator.free(norm_slashes);
    if (!hasRelativePathSegment(norm_slashes)) {
        return allocator.dupe(u8, norm_slashes);
    }
    const normalized = try getNormalizedAbsolutePath(allocator, norm_slashes, "");
    if (normalized.len > 0 and hasTrailingDirectorySeparator(path)) {
        defer allocator.free(normalized);
        return ensureTrailingDirectorySeparator(allocator, normalized);
    }
    return normalized;
}

pub fn GetNormalizedAbsolutePath(allocator: std.mem.Allocator, path: []const u8, currentDirectory: ?[]const u8) ![]const u8 {
    const cur_dir = currentDirectory orelse "";
    return getNormalizedAbsolutePath(allocator, path, cur_dir);
}

pub fn FileExtensionIs(path: []const u8, extension: []const u8) bool {
    return std.mem.endsWith(u8, path, extension);
}

pub fn GetPathComponentsRelativeTo(allocator: std.mem.Allocator, from: []const u8, to: []const u8, options: anytype) ![][]const u8 {
    const current_dir = if (@hasField(@TypeOf(options), "currentDirectory")) options.currentDirectory else "";
    const from_components = try getNormalizedPathComponents(allocator, from, current_dir);
    defer {
        for (from_components) |c| allocator.free(c);
        allocator.free(from_components);
    }
    
    const to_components = try getNormalizedPathComponents(allocator, to, current_dir);
    defer {
        for (to_components) |c| allocator.free(c);
        allocator.free(to_components);
    }

    var start: usize = 0;
    const max_common = @min(from_components.len, to_components.len);
    
    while (start < max_common) : (start += 1) {
        const from_comp = from_components[start];
        const to_comp = to_components[start];
        if (start == 0) {
            if (compareStringsCaseInsensitive(from_comp, to_comp) != 0) break;
        } else {
            const cmp_opts = ComparePathsOptions{
                .currentDirectory = current_dir,
                .useCaseSensitiveFileNames = if (@hasField(@TypeOf(options), "ignoreCase")) !options.ignoreCase else true,
            };
            if (comparePaths(from_comp, to_comp, cmp_opts) != 0) break;
        }
    }

    if (start == 0) {
        var res = try allocator.alloc([]const u8, to_components.len);
        for (to_components, 0..) |c, i| res[i] = try allocator.dupe(u8, c);
        return res;
    }

    const num_dot_dots = from_components.len - start;
    var res = try allocator.alloc([]const u8, 1 + num_dot_dots + to_components.len - start);
    res[0] = "";
    var i: usize = 1;
    for (0..num_dot_dots) |_| {
        res[i] = try allocator.dupe(u8, "..");
        i += 1;
    }
    for (to_components[start..]) |comp| {
        res[i] = try allocator.dupe(u8, comp);
        i += 1;
    }
    return res;
}

pub fn GetPathFromPathComponents(allocator: std.mem.Allocator, components: [][]const u8) ![]const u8 {
    if (components.len == 0) return allocator.dupe(u8, "");
    const root = components[0];
    var b = std.ArrayList(u8).empty;
    defer b.deinit(allocator);
    
    try b.appendSlice(allocator, root);
    if (root.len > 0 and !hasTrailingDirectorySeparator(root)) {
        try b.append(allocator, '/');
    }
    
    var first = true;
    for (components[1..]) |comp| {
        if (!first) try b.append(allocator, '/');
        try b.appendSlice(allocator, comp);
        first = false;
    }
    return b.toOwnedSlice(allocator);
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
    var b = std.ArrayList(u8).empty;
    defer b.deinit(allocator);

    const fp_normalized = try normalizeSlashes(allocator, first_path);
    defer allocator.free(fp_normalized);
    try b.appendSlice(allocator, fp_normalized);

    var start: usize = 0;

    for (paths) |trailing_path| {
        if (trailing_path.len == 0) continue;
        const tp_norm = try normalizeSlashes(allocator, trailing_path);
        defer allocator.free(tp_norm);

        if (b.items[start..].len == 0 or getRootLength(tp_norm) != 0) {
            start = b.items.len;
            try b.appendSlice(allocator, tp_norm);
        } else {
            if (!hasTrailingDirectorySeparator(b.items[start..])) {
                try b.append(allocator, directory_separator);
            }
            try b.appendSlice(allocator, tp_norm);
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
    var res = std.ArrayList([]const u8).empty;
    try res.append(allocator, try allocator.dupe(u8, path[0..root_length]));

    var iter = std.mem.splitScalar(u8, path[root_length..], '/');
    while (iter.next()) |part| {
        if (iter.peek() == null and part.len == 0) continue;
        try res.append(allocator, try allocator.dupe(u8, part));
    }
    return res.toOwnedSlice(allocator);
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

pub fn getRelativePathToDirectoryOrUrl(allocator: std.mem.Allocator, directoryPathOrUrl: []const u8, relativeOrAbsolutePath: []const u8, isAbsolutePathAnUrl: bool, options: ComparePathsOptions) ![]const u8 {
    var components = try GetPathComponentsRelativeTo(allocator, directoryPathOrUrl, relativeOrAbsolutePath, options);
    defer allocator.free(components);

    if (components.len > 0 and isAbsolutePathAnUrl and isRootedDiskPath(components[0])) {
        var prefix: []const u8 = undefined;
        if (components[0][0] == directory_separator) {
            prefix = "file://";
        } else {
            prefix = "file:///";
        }
        const newFirst = try std.fmt.allocPrint(allocator, "{s}{s}", .{ prefix, components[0] });
        defer allocator.free(components[0]);
        components[0] = newFirst;
    }

    return GetPathFromPathComponents(allocator, components);
}

// === Additional path utilities (ported from Go tspath/path.go) ===

/// Port of RemoveTrailingDirectorySeparator.
pub fn removeTrailingDirectorySeparator(path: []const u8) []const u8 {
    if (path.len > 0 and isAnyDirectorySeparator(path[path.len - 1])) {
        return path[0 .. path.len - 1];
    }
    return path;
}

/// Port of RemoveTrailingDirectorySeparators (removes ALL trailing separators).
pub fn removeTrailingDirectorySeparators(path: []const u8) []const u8 {
    var result = path;
    while (result.len > 0 and isAnyDirectorySeparator(result[result.len - 1])) {
        result = result[0 .. result.len - 1];
    }
    return result;
}

/// Port of ResolvePath. Combines paths and normalizes.
pub fn resolvePath(allocator: std.mem.Allocator, path: []const u8, paths: []const []const u8) ![]const u8 {
    if (paths.len > 0) {
        const combined = try combinePaths(allocator, path, paths);
        defer allocator.free(combined);
        return normalizePath(allocator, combined);
    }
    const norm = try normalizeSlashes(allocator, path);
    defer allocator.free(norm);
    return normalizePath(allocator, norm);
}

/// Port of ResolveTripleslashReference.
pub fn resolveTripleslashReference(allocator: std.mem.Allocator, module_name: []const u8, containing_file: []const u8) ![]const u8 {
    if (isRootedDiskPath(module_name)) {
        return normalizePath(allocator, module_name);
    }
    const base_path = try getDirectoryPath(allocator, containing_file);
    defer allocator.free(base_path);
    const combined = try combinePaths(allocator, base_path, &[_][]const u8{module_name});
    defer allocator.free(combined);
    return normalizePath(allocator, combined);
}

/// Port of GetNormalizedPathComponents.
pub fn getNormalizedPathComponents(allocator: std.mem.Allocator, path: []const u8, current_directory: []const u8) ![][]const u8 {
    const combined = try getNormalizedAbsolutePath(allocator, path, current_directory);
    defer allocator.free(combined);
    return getPathComponents(allocator, combined, "");
}

/// Port of GetNormalizedAbsolutePathWithoutRoot.
pub fn getNormalizedAbsolutePathWithoutRoot(allocator: std.mem.Allocator, file_name: []const u8, current_directory: []const u8) ![]const u8 {
    const full = try getNormalizedAbsolutePath(allocator, file_name, current_directory);
    const root_len = getRootLength(full);
    if (root_len < full.len) {
        const result = try allocator.dupe(u8, full[root_len..]);
        allocator.free(full);
        return result;
    }
    return full;
}

/// Port of ToFileNameLowerCase.
pub fn toFileNameLowerCase(allocator: std.mem.Allocator, file_name: []const u8) ![]const u8 {
    const result = try allocator.alloc(u8, file_name.len);
    for (file_name, 0..) |c, i| {
        result[i] = std.ascii.toLower(c);
    }
    return result;
}

/// Port of ConvertToRelativePath.
pub fn convertToRelativePath(allocator: std.mem.Allocator, absolute_or_relative_path: []const u8, options: ComparePathsOptions) ![]const u8 {
    return getRelativePathFromDirectory(allocator, options.currentDirectory, absolute_or_relative_path, options);
}

/// Port of GetRelativePathFromDirectory.
pub fn getRelativePathFromDirectory(allocator: std.mem.Allocator, from_directory: []const u8, to: []const u8, options: ComparePathsOptions) ![]const u8 {
    const components = try GetPathComponentsRelativeTo(allocator, from_directory, to, options);
    defer allocator.free(components);
    return GetPathFromPathComponents(allocator, components);
}

/// Port of GetRelativePathFromFile.
pub fn getRelativePathFromFile(allocator: std.mem.Allocator, from: []const u8, to: []const u8, options: ComparePathsOptions) ![]const u8 {
    const dir = try getDirectoryPath(allocator, from);
    defer allocator.free(dir);
    return getRelativePathFromDirectory(allocator, dir, to, options);
}

/// Port of hasRelativePathSegment (internal helper).
pub fn hasRelativePathSegment(p: []const u8) bool {
    // Check for "./" or "../" segments
    if (std.mem.startsWith(u8, p, "../")) return true;
    if (std.mem.startsWith(u8, p, "./")) return true;
    if (std.mem.indexOf(u8, p, "/../")) |_| return true;
    if (std.mem.indexOf(u8, p, "/./")) |_| return true;
    if (std.mem.eql(u8, p, "..") or std.mem.eql(u8, p, ".")) return true;
    return false;
}


const ignoredPaths = [_][]const u8{
    "/node_modules/.",
    "/.git",
    ".#",
};

pub fn containsIgnoredPath(path: []const u8) bool {
    for (ignoredPaths) |pattern| {
        if (std.mem.indexOf(u8, path, pattern) != null) {
            return true;
        }
    }
    return false;
}

pub fn changeAnyExtension(allocator: std.mem.Allocator, path: []const u8, ext: []const u8, extensions: []const []const u8, ignoreCase: bool) ![]const u8 {
    _ = ignoreCase; 
    var matched_ext: []const u8 = "";
    if (extensions.len > 0) {
        for (extensions) |e| {
            if (FileExtensionIs(path, e)) {
                matched_ext = e;
                break;
            }
        }
    } else {
        matched_ext = std.fs.path.extension(path);
    }
    
    if (matched_ext.len > 0) {
        const result = path[0 .. path.len - matched_ext.len];
        if (ext.len == 0) return allocator.dupe(u8, result);
        if (std.mem.startsWith(u8, ext, ".")) {
            return std.fmt.allocPrint(allocator, "{s}{s}", .{result, ext});
        }
        return std.fmt.allocPrint(allocator, "{s}.{s}", .{result, ext});
    }
    return allocator.dupe(u8, path);
}

pub fn changeExtension(allocator: std.mem.Allocator, path: []const u8, newExtension: []const u8) ![]const u8 {
    return changeAnyExtension(allocator, path, newExtension, &extensionsToRemove, false);
}

pub fn changeFullExtension(allocator: std.mem.Allocator, path: []const u8, newExtension: []const u8) ![]const u8 {
    const declExt = getDeclarationFileExtension(path);
    if (declExt.len > 0) {
        const ext = newExtension;
        const prefix = if (std.mem.startsWith(u8, ext, ".")) @as([]const u8, "") else @as([]const u8, ".");
        return std.fmt.allocPrint(allocator, "{s}{s}{s}", .{path[0 .. path.len - declExt.len], prefix, ext});
    }
    return changeExtension(allocator, path, newExtension);
}

pub fn getPossibleOriginalInputExtensionForExtension(path: []const u8) []const []const u8 {
    if (FileExtensionIs(path, ExtensionDmts) or FileExtensionIs(path, ExtensionMjs) or FileExtensionIs(path, ExtensionMts)) {
        return &[_][]const u8{ ExtensionMts, ExtensionMjs };
    }
    if (FileExtensionIs(path, ExtensionDcts) or FileExtensionIs(path, ExtensionCjs) or FileExtensionIs(path, ExtensionCts)) {
        return &[_][]const u8{ ExtensionCts, ExtensionCjs };
    }
    // We omit the .d.x.ts custom logic to avoid allocator need for now, 
    // fallback to ts/js.
    return &[_][]const u8{ ExtensionTsx, ExtensionTs, ExtensionJsx, ExtensionJs };
}


pub fn pathIsRelative(path: []const u8) bool {
    if (std.mem.eql(u8, path, ".") or std.mem.eql(u8, path, "..")) return true;
    if (path.len >= 2 and path[0] == '.' and (path[1] == '/' or path[1] == '\\')) return true;
    if (path.len >= 3 and path[0] == '.' and path[1] == '.' and (path[2] == '/' or path[2] == '\\')) return true;
    return false;
}

pub fn ensurePathIsNonModuleName(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    if (!pathIsAbsolute(path) and !pathIsRelative(path)) {
        return try std.fmt.allocPrint(allocator, "./{s}", .{path});
    }
    return try allocator.dupe(u8, path);
}

pub fn isExternalModuleNameRelative(moduleName: []const u8) bool {
    return pathIsRelative(moduleName) or isRootedDiskPath(moduleName);
}

pub fn containsPath(allocator: std.mem.Allocator, parent: []const u8, child: []const u8, options: ComparePathsOptions) !bool {
    const parent_combined = try combinePaths(allocator, options.currentDirectory, &[_][]const u8{parent});
    defer allocator.free(parent_combined);
    
    const child_combined = try combinePaths(allocator, options.currentDirectory, &[_][]const u8{child});
    defer allocator.free(child_combined);
    
    if (parent_combined.len == 0 or child_combined.len == 0) return false;
    if (std.mem.eql(u8, parent_combined, child_combined)) return true;
    
    const parent_comps = try getNormalizedPathComponents(allocator, parent_combined, "");
    defer {
        for (parent_comps) |c| allocator.free(c);
        allocator.free(parent_comps);
    }
    const child_comps = try getNormalizedPathComponents(allocator, child_combined, "");
    defer {
        for (child_comps) |c| allocator.free(c);
        allocator.free(child_comps);
    }
    
    if (child_comps.len < parent_comps.len) return false;
    
    for (parent_comps, 0..) |pcomp, i| {
        const ccomp = child_comps[i];
        if (i == 0) {
            if (compareStringsCaseInsensitive(pcomp, ccomp) != 0) return false;
        } else {
            if (options.useCaseSensitiveFileNames) {
                if (!std.mem.eql(u8, pcomp, ccomp)) return false;
            } else {
                if (compareStringsCaseInsensitive(pcomp, ccomp) != 0) return false;
            }
        }
    }
    return true;
}

pub fn forEachAncestorDirectory(allocator: std.mem.Allocator, directory: []const u8, comptime Context: type, context: Context, callback: *const fn (ctx: Context, dir: []const u8) bool) !void {
    var current = try allocator.dupe(u8, directory);
    defer allocator.free(current);
    while (true) {
        if (callback(context, current)) {
            return;
        }
        const parent = try getDirectoryPath(allocator, current);
        if (std.mem.eql(u8, parent, current)) {
            allocator.free(parent);
            return;
        }
        allocator.free(current);
        current = parent;
    }
}

pub fn hasExtension(path: []const u8) bool {
    const base = getBaseFileName(path);
    return std.mem.indexOfScalar(u8, base, '.') != null;
}

pub const VolumePath = struct {
    volume: []const u8,
    rest: []const u8,
    ok: bool,
};

pub fn splitVolumePath(allocator: std.mem.Allocator, path: []const u8) !VolumePath {
    if (path.len >= 2 and isVolumeCharacter(path[0]) and path[1] == ':') {
        const vol = try allocator.alloc(u8, 2);
        vol[0] = std.ascii.toLower(path[0]);
        vol[1] = ':';
        return VolumePath{ .volume = vol, .rest = try allocator.dupe(u8, path[2..]), .ok = true };
    }
    return VolumePath{ .volume = try allocator.dupe(u8, ""), .rest = try allocator.dupe(u8, path), .ok = false };
}

pub fn startsWithDirectory(allocator: std.mem.Allocator, fileName: []const u8, directoryName: []const u8, useCaseSensitiveFileNames: bool) !bool {
    if (directoryName.len == 0) return false;
    const can_file = try getCanonicalFileName(allocator, fileName, useCaseSensitiveFileNames);
    defer allocator.free(can_file);
    const can_dir = try getCanonicalFileName(allocator, directoryName, useCaseSensitiveFileNames);
    defer allocator.free(can_dir);
    
    var trimmed = can_dir;
    if (trimmed.len > 0 and (trimmed[trimmed.len - 1] == '/' or trimmed[trimmed.len - 1] == '\\')) {
        trimmed = trimmed[0..trimmed.len - 1];
    }
    
    const prefix1 = try std.fmt.allocPrint(allocator, "{s}/", .{trimmed});
    defer allocator.free(prefix1);
    const prefix2 = try std.fmt.allocPrint(allocator, "{s}\\\\", .{trimmed});
    defer allocator.free(prefix2);
    
    return std.mem.startsWith(u8, can_file, prefix1) or std.mem.startsWith(u8, can_file, prefix2);
}

pub fn compareNumberOfDirectorySeparators(path1: []const u8, path2: []const u8) i32 {
    const c1 = std.mem.count(u8, path1, "/");
    const c2 = std.mem.count(u8, path2, "/");
    if (c1 < c2) return -1;
    if (c1 > c2) return 1;
    return 0;
}
