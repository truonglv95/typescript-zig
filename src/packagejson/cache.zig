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
        if (!self.once.isSet()) {
            self.once.set();
            if (self.fields.typesVersions == .NotPresent) {
                const msg = try allocator.create(DiagnosticAndArgs);
                msg.* = .{
                    .message = &diagnostics.X_package_json_does_not_have_a_0_field,
                    .args = try duplicateArgs(allocator, &[_][]const u8{"typesVersions"}),
                };
                try self.versionTraces.append(msg.*);
                return self.versionPaths;
            }
            if (self.fields.typesVersions != .Object) {
                const msg = try allocator.create(DiagnosticAndArgs);
                msg.* = .{
                    .message = &diagnostics.Expected_type_of_0_field_in_package_json_to_be_1_got_2,
                    .args = try duplicateArgs(allocator, &[_][]const u8{ "typesVersions", "object", @tagName(self.fields.typesVersions) }),
                };
                try self.versionTraces.append(msg.*);
                return self.versionPaths;
            }

            const msg = try allocator.create(DiagnosticAndArgs);
            msg.* = .{
                .message = &diagnostics.X_package_json_has_a_typesVersions_field_with_version_specific_path_mappings,
                .args = try duplicateArgs(allocator, &[_][]const u8{"typesVersions"}),
            };
            try self.versionTraces.append(msg.*);

            const ts_version = semver.tryParseVersion(allocator, "7.0.0-dev") catch unreachable orelse unreachable;

            var types_versions_obj = self.fields.typesVersions.asObject();
            var it = types_versions_obj.iterator();
            while (it.next()) |entry| {
                const key_range = semver.tryParseVersionRange(allocator, entry.key_ptr.*) catch null orelse {
                    const msg2 = try allocator.create(DiagnosticAndArgs);
                    msg2.* = .{
                        .message = &diagnostics.X_package_json_has_a_typesVersions_entry_0_that_is_not_a_valid_semver_range,
                        .args = try duplicateArgs(allocator, &[_][]const u8{entry.key_ptr.*}),
                    };
                    try self.versionTraces.append(msg2.*);
                    continue;
                };
                const is_match = key_range.testVersion(&ts_version);
                if (is_match) {
                    if (entry.value_ptr.* != .Object) {
                        const msg3 = try allocator.create(DiagnosticAndArgs);
                        msg3.* = .{
                            .message = &diagnostics.Expected_type_of_0_field_in_package_json_to_be_1_got_2,
                            .args = try duplicateArgs(allocator, &[_][]const u8{ try std.fmt.allocPrint(allocator, "typesVersions['{s}']", .{entry.key_ptr.*}), "object", @tagName(entry.value_ptr.*) }),
                        };
                        try self.versionTraces.append(msg3.*);
                        return self.versionPaths;
                    }
                    self.versionPaths = .{
                        .version = entry.key_ptr.*,
                        .pathsJSON = entry.value_ptr.asObject(),
                    };
                    return self.versionPaths;
                }
            }

            const msg_err = try allocator.create(DiagnosticAndArgs);
            msg_err.* = .{
                .message = &diagnostics.X_package_json_does_not_have_a_typesVersions_entry_that_matches_version_0,
                .args = try duplicateArgs(allocator, &[_][]const u8{"7.0"}),
            };
            try self.versionTraces.append(msg_err.*);
        }
        return self.versionPaths;
    }

    fn duplicateArgs(allocator: std.mem.Allocator, args: []const []const u8) ![][]const u8 {
        var copy = try allocator.alloc([]const u8, args.len);
        for (args, 0..) |arg, i| {
            copy[i] = try allocator.dupe(u8, arg);
        }
        return copy;
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
