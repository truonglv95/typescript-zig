const std = @import("std");
const packagejson = @import("packagejson.zig");
const jsonvalue = @import("jsonvalue.zig");
const semver = @import("../semver/version.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");

pub const DiagnosticAndArgs = struct {
    message: *const diagnostics.DiagnosticMessage,
    args: [][]const u8,
};

pub const VersionPaths = struct {
    version: []const u8 = "",
    pathsJSON: *const std.StringArrayHashMap(jsonvalue.JSONValue) = undefined,
    paths: ?*std.StringArrayHashMap([][]const u8) = null,

    pub fn exists(self: *const VersionPaths) bool {
        return self.version.len > 0;
    }

    pub fn getPaths(self: *VersionPaths, allocator: std.mem.Allocator) !*std.StringArrayHashMap([][]const u8) {
        if (!self.exists()) return error.NotExists;
        if (self.paths) |p| return p;

        var paths_map = try allocator.create(std.StringArrayHashMap([][]const u8));
        paths_map.* = std.StringArrayHashMap([][]const u8).init(allocator);

        var it = self.pathsJSON.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.* != .Array) continue;
            const arr = entry.value_ptr.asArray();
            var slice = try allocator.alloc([]const u8, arr.len);
            var i: usize = 0;
            for (arr) |val| {
                if (val == .String) {
                    slice[i] = val.asString();
                    i += 1;
                }
            }
            try paths_map.put(entry.key_ptr.*, slice[0..i]);
        }
        self.paths = paths_map;
        return paths_map;
    }
};

pub const PackageJson = struct {
    fields: packagejson.Fields,
    parseable: bool,
    versionPaths: VersionPaths = .{},
    versionTraces: std.ArrayList(DiagnosticAndArgs),
    once: std.once_cell.Once = std.once_cell.Once{},

    pub fn init(allocator: std.mem.Allocator, fields: packagejson.Fields, parseable: bool) PackageJson {
        return .{
            .fields = fields,
            .parseable = parseable,
            .versionTraces = std.ArrayList(DiagnosticAndArgs).init(allocator),
        };
    }

    pub fn getVersionPaths(self: *PackageJson, allocator: std.mem.Allocator) !VersionPaths {
        _ = allocator; // for DoD, you'd allocate diagnostics here
        // TODO: implement version matching and diagnostic generation
        // for now we just return version paths
        return self.versionPaths;
    }
};

pub const InfoCacheEntry = struct {
    packageDirectory: []const u8,
    directoryExists: bool,
    contents: ?*PackageJson,

    pub fn exists(self: *const InfoCacheEntry) bool {
        return self.contents != null;
    }

    pub fn getContents(self: *const InfoCacheEntry) ?*PackageJson {
        return self.contents;
    }

    pub fn getDirectory(self: *const InfoCacheEntry) []const u8 {
        return self.packageDirectory;
    }

    pub fn withPackageDirectory(self: *const InfoCacheEntry, allocator: std.mem.Allocator, packageDirectory: []const u8) !*InfoCacheEntry {
        if (std.mem.eql(u8, self.packageDirectory, packageDirectory)) {
            // Can't return self since it's const and we return mutable pointer
            // Actually in DoD we use Arena so it's fine to just reallocate
        }
        const new_entry = try allocator.create(InfoCacheEntry);
        new_entry.* = .{
            .packageDirectory = packageDirectory,
            .directoryExists = self.directoryExists,
            .contents = self.contents,
        };
        return new_entry;
    }
};

pub const InfoCache = struct {
    cache: std.StringHashMap(*InfoCacheEntry),
    currentDirectory: []const u8,
    useCaseSensitiveFileNames: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, currentDirectory: []const u8, useCaseSensitiveFileNames: bool) InfoCache {
        return .{
            .cache = std.StringHashMap(*InfoCacheEntry).init(allocator),
            .currentDirectory = currentDirectory,
            .useCaseSensitiveFileNames = useCaseSensitiveFileNames,
            .allocator = allocator,
        };
    }

    pub fn get(self: *InfoCache, packageJsonPath: []const u8) ?*InfoCacheEntry {
        return self.cache.get(packageJsonPath);
    }

    pub fn set(self: *InfoCache, packageJsonPath: []const u8, info: *InfoCacheEntry) !*InfoCacheEntry {
        const gop = try self.cache.getOrPut(packageJsonPath);
        if (!gop.found_existing) {
            gop.value_ptr.* = info;
        }
        return gop.value_ptr.*;
    }
};
