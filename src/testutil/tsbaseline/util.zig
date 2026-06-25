const std = @import("std");
const tspath = @import("../../tspath/tspath.zig");

pub const lineDelimiter = "\n"; // Simplified for Zig
pub const libFolder = "built/local/";
pub const builtFolder = "/.ts";

const ReplacerPair = struct {
    old: []const u8,
    new: []const u8,
};

const testPathPrefixReplacer = [_]ReplacerPair{
    .{ .old = "/.ts/", .new = "" },
    .{ .old = "/.lib/", .new = "" },
    .{ .old = "/.src/", .new = "" },
    .{ .old = "bundled:///libs/", .new = "" },
    .{ .old = "file:///./ts/", .new = "file:///" },
    .{ .old = "file:///./lib/", .new = "file:///" },
    .{ .old = "file:///./src/", .new = "file:///" },
};

const testPathTrailingReplacerTrailingSeparator = [_]ReplacerPair{
    .{ .old = "/.ts/", .new = "/" },
    .{ .old = "/.lib/", .new = "/" },
    .{ .old = "/.src/", .new = "/" },
    .{ .old = "bundled:///libs/", .new = "/" },
    .{ .old = "file:///./ts/", .new = "file:///" },
    .{ .old = "file:///./lib/", .new = "file:///" },
    .{ .old = "file:///./src/", .new = "file:///" },
};

pub fn removeTestPathPrefixes(allocator: std.mem.Allocator, text: []const u8, retainTrailingDirectorySeparator: bool) ![]const u8 {
    var current = try allocator.dupe(u8, text);
    const replacers = if (retainTrailingDirectorySeparator) testPathTrailingReplacerTrailingSeparator else testPathPrefixReplacer;
    for (replacers) |replacer| {
        const next = try std.mem.replaceOwned(u8, allocator, current, replacer.old, replacer.new);
        allocator.free(current);
        current = next;
    }
    return current;
}

pub fn isDefaultLibraryFile(filePath: []const u8) bool {
    const fileName = tspath.getBaseFileName(filePath);
    return std.mem.startsWith(u8, fileName, "lib.") and std.mem.endsWith(u8, fileName, tspath.ExtensionDts);
}

pub fn isBuiltFile(allocator: std.mem.Allocator, filePath: []const u8) !bool {
    if (std.mem.startsWith(u8, filePath, libFolder)) return true;
    const trailingBuiltFolder = try tspath.ensureTrailingDirectorySeparator(allocator, builtFolder);
    defer allocator.free(trailingBuiltFolder);
    return std.mem.startsWith(u8, filePath, trailingBuiltFolder);
}

pub fn isTsConfigFile(path: []const u8) bool {
    return std.mem.indexOf(u8, path, "tsconfig") != null and std.mem.indexOf(u8, path, "json") != null;
}

pub fn sanitizeTestFilePath(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    var path = std.ArrayList(u8).init(allocator);
    errdefer path.deinit();

    for (name) |c| {
        switch (c) {
            '^', '<', '>', ':', '"', '|', '?', '*', '%' => try path.append('_'),
            else => try path.append(c),
        }
    }

    const normalized = try tspath.normalizeSlashes(allocator, path.items);
    path.deinit();
    
    const dotdotReplaced = try std.mem.replaceOwned(u8, allocator, normalized, "../", "__dotdot/");
    allocator.free(normalized);

    const toPathStr = try tspath.toPath(allocator, dotdotReplaced, "", false);
    allocator.free(dotdotReplaced);

    var finalPath = toPathStr;
    if (std.mem.startsWith(u8, finalPath, "/")) {
        finalPath = finalPath[1..];
    }
    const result = try allocator.dupe(u8, finalPath);
    allocator.free(toPathStr);
    return result;
}
