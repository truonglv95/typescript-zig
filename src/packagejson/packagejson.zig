const std = @import("std");
const expected = @import("expected.zig");
const Expected = expected.Expected;
const jsonvalue = @import("jsonvalue.zig");
const JSONValue = jsonvalue.JSONValue;
const exportsorimports = @import("exportsorimports.zig");
const ExportsOrImports = exportsorimports.ExportsOrImports;
const cache = @import("cache.zig");
pub const InfoCache = cache.InfoCache;
pub const InfoCacheEntry = cache.InfoCacheEntry;

pub const StringMap = std.StringArrayHashMap([]const u8);

pub const HeaderFields = struct {
    name: Expected([]const u8) = .{},
    version: Expected([]const u8) = .{},
    type: Expected([]const u8) = .{},
};

pub const PathFields = struct {
    tsconfig: Expected([]const u8) = .{},
    main: Expected([]const u8) = .{},
    types: Expected([]const u8) = .{},
    typings: Expected([]const u8) = .{},
    typesVersions: JSONValue = .{ .NotPresent = {} },
    imports: ExportsOrImports = .{ .json_value = .{ .NotPresent = {} } },
    exports: ExportsOrImports = .{ .json_value = .{ .NotPresent = {} } },
};

pub const DependencyFields = struct {
    dependencies: Expected(StringMap) = .{},
    devDependencies: Expected(StringMap) = .{},
    peerDependencies: Expected(StringMap) = .{},
    optionalDependencies: Expected(StringMap) = .{},

    pub fn hasDependency(self: *const DependencyFields, name: []const u8) bool {
        if (self.dependencies.getValue()) |deps| {
            if (deps.contains(name)) return true;
        }
        if (self.devDependencies.getValue()) |deps| {
            if (deps.contains(name)) return true;
        }
        if (self.peerDependencies.getValue()) |deps| {
            if (deps.contains(name)) return true;
        }
        if (self.optionalDependencies.getValue()) |deps| {
            if (deps.contains(name)) return true;
        }
        return false;
    }

    pub fn rangeDependencies(self: *const DependencyFields, context: anytype, comptime f: fn (context: @TypeOf(context), name: []const u8, version: []const u8, dependencyField: []const u8) bool) void {
        if (self.dependencies.getValue()) |deps| {
            for (deps.keys(), deps.values()) |name, version| {
                if (!f(context, name, version, "dependencies")) return;
            }
        }
        if (self.devDependencies.getValue()) |deps| {
            for (deps.keys(), deps.values()) |name, version| {
                if (!f(context, name, version, "devDependencies")) return;
            }
        }
        if (self.peerDependencies.getValue()) |deps| {
            for (deps.keys(), deps.values()) |name, version| {
                if (!f(context, name, version, "peerDependencies")) return;
            }
        }
        if (self.optionalDependencies.getValue()) |deps| {
            for (deps.keys(), deps.values()) |name, version| {
                if (!f(context, name, version, "optionalDependencies")) return;
            }
        }
    }

    pub fn getRuntimeDependencyNames(self: *const DependencyFields, allocator: std.mem.Allocator) !std.StringArrayHashMap(void) {
        var names = std.StringArrayHashMap(void).init(allocator);

        if (self.dependencies.getValue()) |deps| {
            for (deps.keys()) |name| {
                try names.put(name, {});
            }
        }
        if (self.peerDependencies.getValue()) |deps| {
            for (deps.keys()) |name| {
                try names.put(name, {});
            }
        }
        if (self.optionalDependencies.getValue()) |deps| {
            for (deps.keys()) |name| {
                try names.put(name, {});
            }
        }
        return names;
    }
};

pub const Fields = struct {
    headerFields: HeaderFields = .{},
    pathFields: PathFields = .{},
    dependencyFields: DependencyFields = .{},

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Fields {
        const value = try std.json.Value.jsonParse(allocator, source, options);
        if (value != .object) return error.UnexpectedToken;

        var fields: Fields = .{};
        const obj = value.object;

        inline for (@typeInfo(HeaderFields).Struct.fields) |f| {
            if (obj.get(f.name)) |val| {
                @field(fields.headerFields, f.name) = try std.json.parseFromValue(f.type, allocator, val, options);
            }
        }

        inline for (@typeInfo(PathFields).Struct.fields) |f| {
            if (obj.get(f.name)) |val| {
                @field(fields.pathFields, f.name) = try std.json.parseFromValue(f.type, allocator, val, options);
            }
        }

        inline for (@typeInfo(DependencyFields).Struct.fields) |f| {
            if (obj.get(f.name)) |val| {
                @field(fields.dependencyFields, f.name) = try std.json.parseFromValue(f.type, allocator, val, options);
            }
        }

        return fields;
    }
};

pub fn parse(allocator: std.mem.Allocator, data: []const u8) !Fields {
    return try std.json.parseFromSlice(Fields, allocator, data, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
}
