const std = @import("std");
const ast = @import("../ast/ast.zig");
const core = @import("../core/core.zig");
const tspath = @import("../tspath/tspath.zig");

// Note: Semver integration is skipped for brevity

pub fn isApplicableVersionedTypesKey(key: []const u8) bool {
    return std.mem.startsWith(u8, key, "types@");
}

fn moveToNextDirectorySeparatorIfAvailable(path: []const u8, prevSeparatorIndex: usize, isFolder: bool) usize {
    const offset = prevSeparatorIndex + 1;
    if (offset >= path.len) {
        return if (isFolder) path.len else prevSeparatorIndex;
    }
    const nextSeparatorIndex = std.mem.indexOfScalar(u8, path[offset..], '/');
    if (nextSeparatorIndex == null) {
        if (isFolder) {
            return path.len;
        }
        return prevSeparatorIndex;
    }
    return nextSeparatorIndex.? + offset;
}

pub fn parseNodeModuleFromPath(resolved: []const u8, isFolder: bool) []const u8 {
    const idx = std.mem.lastIndexOf(u8, resolved, "/node_modules/");
    if (idx == null) {
        return "";
    }
    const indexAfterNodeModules = idx.? + "/node_modules/".len;
    var indexAfterPackageName = moveToNextDirectorySeparatorIfAvailable(resolved, indexAfterNodeModules, isFolder);
    if (indexAfterNodeModules < resolved.len and resolved[indexAfterNodeModules] == '@') {
        indexAfterPackageName = moveToNextDirectorySeparatorIfAvailable(resolved, indexAfterPackageName, isFolder);
    }
    return resolved[0..indexAfterPackageName];
}

pub fn parsePackageName(moduleName: []const u8) struct { []const u8, []const u8 } {
    var idx = std.mem.indexOf(u8, moduleName, "/");
    if (moduleName.len > 0 and moduleName[0] == '@') {
        if (idx) |i| {
            const offset = i + 1;
            const nextIdx = std.mem.indexOf(u8, moduleName[offset..], "/");
            if (nextIdx) |ni| {
                idx = ni + offset;
            } else {
                idx = null;
            }
        }
    }
    if (idx == null) {
        return .{ moduleName, "" };
    }
    return .{ moduleName[0..idx.?], moduleName[idx.? + 1 ..] };
}

pub fn mangleScopedPackageName(allocator: std.mem.Allocator, packageName: []const u8) ![]const u8 {
    if (packageName.len > 0 and packageName[0] == '@') {
        const idx = std.mem.indexOf(u8, packageName, "/");
        if (idx == null) {
            return try allocator.dupe(u8, packageName);
        }
        return try std.fmt.allocPrint(allocator, "{s}__{s}", .{ packageName[1..idx.?], packageName[idx.? + 1 ..] });
    }
    return try allocator.dupe(u8, packageName);
}

pub fn unmangleScopedPackageName(allocator: std.mem.Allocator, packageName: []const u8) ![]const u8 {
    const idx = std.mem.indexOf(u8, packageName, "__");
    if (idx) |i| {
        return try std.fmt.allocPrint(allocator, "@{s}/{s}", .{ packageName[0..i], packageName[i + 2 ..] });
    }
    return try allocator.dupe(u8, packageName);
}

pub fn comparePatternKeys(a: []const u8, b: []const u8) i32 {
    const aPatternIndex = std.mem.indexOf(u8, a, "*");
    const bPatternIndex = std.mem.indexOf(u8, b, "*");
    var baseLenA = a.len;
    if (aPatternIndex) |i| baseLenA = i + 1;
    var baseLenB = b.len;
    if (bPatternIndex) |i| baseLenB = i + 1;

    if (baseLenA > baseLenB) return -1;
    if (baseLenB > baseLenA) return 1;
    if (aPatternIndex == null) return 1;
    if (bPatternIndex == null) return -1;
    if (a.len > b.len) return -1;
    if (b.len > a.len) return 1;
    return 0;
}

pub fn tryGetJSExtensionForFile(fileName: []const u8, options: *const core.CompilerOptions) []const u8 {
    const ext = tspath.tryGetExtensionFromPath(fileName);
    if (std.mem.eql(u8, ext, tspath.ExtensionTs) or std.mem.eql(u8, ext, tspath.ExtensionDts)) {
        return tspath.ExtensionJs;
    } else if (std.mem.eql(u8, ext, tspath.ExtensionTsx)) {
        if ((options.jsx orelse .None) == .Preserve) {
            return tspath.ExtensionJsx;
        }
        return tspath.ExtensionJs;
    } else if (std.mem.eql(u8, ext, tspath.ExtensionJs) or std.mem.eql(u8, ext, tspath.ExtensionJsx) or std.mem.eql(u8, ext, tspath.ExtensionJson)) {
        return ext;
    } else if (std.mem.eql(u8, ext, tspath.ExtensionDmts) or std.mem.eql(u8, ext, tspath.ExtensionMts) or std.mem.eql(u8, ext, tspath.ExtensionMjs)) {
        return tspath.ExtensionMjs;
    } else if (std.mem.eql(u8, ext, tspath.ExtensionDcts) or std.mem.eql(u8, ext, tspath.ExtensionCts) or std.mem.eql(u8, ext, tspath.ExtensionCjs)) {
        return tspath.ExtensionCjs;
    }
    return "";
}
