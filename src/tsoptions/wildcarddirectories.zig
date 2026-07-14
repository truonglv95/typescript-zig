const std = @import("std");
const tspath = @import("../tspath/tspath.zig");
const vfsmatch = @import("../vfs/vfsmatch.zig");

pub fn getWildcardDirectories(
    allocator: std.mem.Allocator,
    include: []const []const u8,
    exclude: []const []const u8,
    comparePathsOptions: tspath.ComparePathsOptions,
) !?std.StringHashMap(bool) {
    if (include.len == 0) {
        return null;
    }

    var excludeMatcher = try vfsmatch.NewSpecMatcher(
        allocator,
        exclude,
        comparePathsOptions.CurrentDirectory,
        vfsmatch.UsageExclude,
        comparePathsOptions.UseCaseSensitiveFileNames,
    );

    var wildcardDirectories = std.StringHashMap(bool).init(allocator);
    var wildCardKeyToPath = std.StringHashMap([]const u8).init(allocator);

    var recursiveKeys = std.ArrayList([]const u8).init(allocator);

    for (include) |file| {
        const spec = try tspath.NormalizeSlashes(allocator, try tspath.CombinePaths(allocator, comparePathsOptions.CurrentDirectory, file));
        if (excludeMatcher) |*matcher| {
            if (matcher.MatchString(spec)) {
                continue;
            }
        }

        const match = try getWildcardDirectoryFromSpec(allocator, spec, comparePathsOptions.UseCaseSensitiveFileNames);
        if (match) |m| {
            const key = m.Key;
            const path = m.Path;
            const recursive = m.Recursive;

            const existingPath = wildCardKeyToPath.get(key);
            const existsPath = existingPath != null;
            var existingRecursive: bool = false;

            if (existsPath) {
                existingRecursive = wildcardDirectories.get(existingPath.?).?;
            }

            if (!existsPath or (!existingRecursive and recursive)) {
                var pathToUse = path;
                if (existsPath) {
                    pathToUse = existingPath.?;
                }
                try wildcardDirectories.put(pathToUse, recursive);

                if (!existsPath) {
                    try wildCardKeyToPath.put(key, path);
                }

                if (recursive) {
                    try recursiveKeys.append(key);
                }
            }
        }

        // Remove any subpaths under an existing recursively watched directory
        var keysToRemove = std.ArrayList([]const u8).init(allocator);
        var it = wildcardDirectories.iterator();
        while (it.next()) |entry| {
            const path = entry.key_ptr.*;
            for (recursiveKeys.items) |recursiveKey| {
                const key = try toCanonicalKey(allocator, path, comparePathsOptions.UseCaseSensitiveFileNames);
                if (!std.mem.eql(u8, key, recursiveKey) and tspath.ContainsPath(recursiveKey, key, comparePathsOptions)) {
                    try keysToRemove.append(path);
                    break;
                }
            }
        }

        for (keysToRemove.items) |path| {
            _ = wildcardDirectories.remove(path);
        }
    }

    return wildcardDirectories;
}

pub fn toCanonicalKey(allocator: std.mem.Allocator, path: []const u8, useCaseSensitiveFileNames: bool) ![]const u8 {
    if (useCaseSensitiveFileNames) {
        return path;
    }
    return try std.ascii.allocLowerString(allocator, path);
}

pub const WildcardDirectoryMatch = struct {
    Key: []const u8,
    Path: []const u8,
    Recursive: bool,
};

pub fn getWildcardDirectoryFromSpec(
    allocator: std.mem.Allocator,
    spec: []const u8,
    useCaseSensitiveFileNames: bool,
) !?WildcardDirectoryMatch {
    // Find the first occurrence of a wildcard character
    const firstWildcard = std.mem.indexOfAny(u8, spec, "*?");
    if (firstWildcard) |fw| {
        // Find the last directory separator before the wildcard
        const lastSepBeforeWildcard = std.mem.lastIndexOfScalar(u8, spec[0..fw], tspath.DirectorySeparator);
        if (lastSepBeforeWildcard) |lsbw| {
            const path = spec[0..lsbw];
            const lastDirectorySeparatorIndex = std.mem.lastIndexOfScalar(u8, spec, tspath.DirectorySeparator).?;

            // Determine if this should be watched recursively:
            // recursive if the wildcard appears in a directory segment (not just the final file segment)
            const recursive = fw < lastDirectorySeparatorIndex;

            return WildcardDirectoryMatch{
                .Key = try toCanonicalKey(allocator, path, useCaseSensitiveFileNames),
                .Path = path,
                .Recursive = recursive,
            };
        }
    }

    if (std.mem.lastIndexOfScalar(u8, spec, tspath.DirectorySeparator)) |lastSepIndex| {
        const lastSegment = spec[lastSepIndex + 1 ..];
        if (vfsmatch.IsImplicitGlob(lastSegment)) {
            const path = tspath.RemoveTrailingDirectorySeparator(spec);
            return WildcardDirectoryMatch{
                .Key = try toCanonicalKey(allocator, path, useCaseSensitiveFileNames),
                .Path = path,
                .Recursive = true,
            };
        }
    }

    return null;
}
