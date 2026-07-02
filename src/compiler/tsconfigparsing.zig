const std = @import("std");
const core = @import("../core/core.zig");
const program = @import("program.zig");

pub const ParsedTsConfig = struct {
    options: core.CompilerOptions,
    fileNames: std.ArrayList([]const u8),
    hasExplicitFiles: bool = false,
    projectReferences: std.ArrayList([]const u8),
    pathMappings: std.ArrayList(program.PathMapping),
    extendsPath: ?[]const u8 = null,
    includeSpecs: std.ArrayList([]const u8),
    excludeSpecs: std.ArrayList([]const u8),
    errors: std.ArrayList([]const u8),

    pub fn deinit(self: *ParsedTsConfig, allocator: std.mem.Allocator) void {
        for (self.fileNames.items) |name| {
            allocator.free(name);
        }
        self.fileNames.deinit(allocator);
        for (self.projectReferences.items) |name| allocator.free(name);
        self.projectReferences.deinit(allocator);
        for (self.pathMappings.items) |mapping| {
            allocator.free(mapping.pattern);
            for (mapping.targets) |target| allocator.free(target);
            allocator.free(mapping.targets);
        }
        self.pathMappings.deinit(allocator);
        if (self.extendsPath) |path| allocator.free(path);
        for (self.includeSpecs.items) |spec| allocator.free(spec);
        self.includeSpecs.deinit(allocator);
        for (self.excludeSpecs.items) |spec| allocator.free(spec);
        self.excludeSpecs.deinit(allocator);

        for (self.errors.items) |err| {
            allocator.free(err);
        }
        self.errors.deinit(allocator);

        inline for (std.meta.fields(core.CompilerOptions)) |field| {
            if (field.type == ?[]const u8) {
                if (@field(self.options, field.name)) |s| {
                    allocator.free(s);
                }
            } else if (field.type == ?[]const []const u8) {
                if (@field(self.options, field.name)) |arr| {
                    for (arr) |s| allocator.free(s);
                    allocator.free(arr);
                }
            }
        }
    }
};

pub fn parseTsConfigFile(allocator: std.mem.Allocator, io: std.Io, filePath: []const u8) !ParsedTsConfig {
    var result = ParsedTsConfig{
        .options = core.CompilerOptions{},
        .fileNames = std.ArrayList([]const u8).empty,
        .hasExplicitFiles = false,
        .projectReferences = std.ArrayList([]const u8).empty,
        .pathMappings = std.ArrayList(program.PathMapping).empty,
        .includeSpecs = std.ArrayList([]const u8).empty,
        .excludeSpecs = std.ArrayList([]const u8).empty,
        .errors = std.ArrayList([]const u8).empty,
    };

    const fileContent = std.Io.Dir.cwd().readFileAlloc(io, filePath, allocator, @enumFromInt(1024 * 1024 * 10)) catch |err| {
        try result.errors.append(allocator, try std.fmt.allocPrint(allocator, "Cannot read file '{s}': {any}", .{ filePath, err }));
        return result;
    };
    defer allocator.free(fileContent);

    var parsed = try parseTsConfigSlice(allocator, fileContent);
    const config_dir = std.fs.path.dirname(filePath) orelse ".";
    if (parsed.extendsPath) |extends_path| {
        const resolved = try resolveExtendsPath(allocator, io, config_dir, extends_path);
        defer allocator.free(resolved);
        var base = try parseTsConfigFile(allocator, io, resolved);
        defer base.deinit(allocator);
        try inheritConfig(allocator, &parsed, &base);
    }
    for (parsed.fileNames.items, 0..) |name, index| if (!std.fs.path.isAbsolute(name)) {
        parsed.fileNames.items[index] = try std.fs.path.join(allocator, &.{ config_dir, name });
        allocator.free(name);
    };
    resolveConfigPath(allocator, &parsed.options.baseUrl, config_dir) catch {};
    resolveConfigPath(allocator, &parsed.options.rootDir, config_dir) catch {};
    resolveConfigPath(allocator, &parsed.options.outDir, config_dir) catch {};
    resolveConfigPath(allocator, &parsed.options.declarationDir, config_dir) catch {};
    try resolveConfigPathList(allocator, &parsed.options.rootDirs, config_dir);
    try resolveConfigPathList(allocator, &parsed.options.typeRoots, config_dir);
    return parsed;
}

fn resolveExtendsPath(allocator: std.mem.Allocator, io: std.Io, config_dir: []const u8, value: []const u8) ![]const u8 {
    if (std.fs.path.isAbsolute(value) or std.mem.startsWith(u8, value, ".")) {
        const joined = if (std.fs.path.isAbsolute(value)) try allocator.dupe(u8, value) else try std.fs.path.join(allocator, &.{ config_dir, value });
        defer allocator.free(joined);
        if (fileExists(io, joined)) return allocator.dupe(u8, joined);
        if (std.fs.path.extension(joined).len == 0) {
            const with_json = try std.fmt.allocPrint(allocator, "{s}.json", .{joined});
            if (fileExists(io, with_json)) return with_json;
            allocator.free(with_json);
        }
        return allocator.dupe(u8, joined);
    }

    const package_end = if (value.len > 0 and value[0] == '@') blk: {
        const first = std.mem.indexOfScalar(u8, value, '/') orelse break :blk value.len;
        break :blk std.mem.indexOfScalarPos(u8, value, first + 1, '/') orelse value.len;
    } else std.mem.indexOfScalar(u8, value, '/') orelse value.len;
    const package_name = value[0..package_end];
    const subpath = if (package_end < value.len) value[package_end + 1 ..] else "";
    var directory = config_dir;
    while (true) {
        const package_root = try std.fs.path.join(allocator, &.{ directory, "node_modules", package_name });
        defer allocator.free(package_root);
        if (subpath.len != 0) {
            const requested = try std.fs.path.join(allocator, &.{ package_root, subpath });
            defer allocator.free(requested);
            if (fileExists(io, requested)) return allocator.dupe(u8, requested);
            const with_json = try std.fmt.allocPrint(allocator, "{s}.json", .{requested});
            if (fileExists(io, with_json)) return with_json;
            allocator.free(with_json);
        } else {
            const package_json = try std.fs.path.join(allocator, &.{ package_root, "package.json" });
            defer allocator.free(package_json);
            if (fileExists(io, package_json)) {
                const content = try std.Io.Dir.cwd().readFileAlloc(io, package_json, allocator, @enumFromInt(4 * 1024 * 1024));
                defer allocator.free(content);
                if (std.json.parseFromSlice(std.json.Value, allocator, content, .{})) |package| {
                    var parsed_package = package;
                    defer parsed_package.deinit();
                    if (parsed_package.value == .object) if (parsed_package.value.object.get("tsconfig")) |entry| if (entry == .string) {
                        const requested = try std.fs.path.join(allocator, &.{ package_root, entry.string });
                        if (fileExists(io, requested)) return requested;
                        allocator.free(requested);
                    };
                } else |_| {}
            }
            const default_config = try std.fs.path.join(allocator, &.{ package_root, "tsconfig.json" });
            if (fileExists(io, default_config)) return default_config;
            allocator.free(default_config);
        }
        const parent = std.fs.path.dirname(directory) orelse break;
        if (std.mem.eql(u8, parent, directory)) break;
        directory = parent;
    }
    return error.ExtendsConfigNotFound;
}

fn fileExists(io: std.Io, path: []const u8) bool {
    const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch return false;
    file.close(io);
    return true;
}

pub fn parseTsConfigSlice(allocator: std.mem.Allocator, fileContent: []const u8) !ParsedTsConfig {
    var result = ParsedTsConfig{
        .options = core.CompilerOptions{},
        .fileNames = std.ArrayList([]const u8).empty,
        .hasExplicitFiles = false,
        .projectReferences = std.ArrayList([]const u8).empty,
        .pathMappings = std.ArrayList(program.PathMapping).empty,
        .includeSpecs = std.ArrayList([]const u8).empty,
        .excludeSpecs = std.ArrayList([]const u8).empty,
        .errors = std.ArrayList([]const u8).empty,
    };

    const json_content = try sanitizeJsonc(allocator, fileContent);
    defer allocator.free(json_content);
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, json_content, .{ .ignore_unknown_fields = true }) catch |err| {
        try result.errors.append(allocator, try std.fmt.allocPrint(allocator, "JSON parse error: {any}", .{err}));
        return result;
    };
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .object) {
        try result.errors.append(allocator, try std.fmt.allocPrint(allocator, "Expected an object in tsconfig.json", .{}));
        return result;
    }
    if (root.object.get("extends")) |extends_value| {
        if (extends_value == .string) result.extendsPath = try allocator.dupe(u8, extends_value.string);
    }

    if (root.object.get("compilerOptions")) |co| {
        if (co == .object) {
            // Very basic mapping for now
            // We can iterate the keys and use @hasField
            var it = co.object.iterator();
            while (it.next()) |entry| {
                const key = entry.key_ptr.*;
                const val = entry.value_ptr.*;

                inline for (std.meta.fields(core.CompilerOptions)) |field| {
                    if (std.mem.eql(u8, key, field.name)) {
                        switch (val) {
                            .bool => |b| {
                                if (field.type == ?bool) {
                                    @field(result.options, field.name) = b;
                                }
                            },
                            .string => |s| {
                                if (field.type == ?[]const u8) {
                                    // Allocate a copy of the string to avoid lifetime issues
                                    @field(result.options, field.name) = try allocator.dupe(u8, s);
                                } else if (field.type == ?core.ModuleKind) {
                                    @field(result.options, field.name) = parseModule(s);
                                } else if (field.type == ?core.ScriptTarget) {
                                    @field(result.options, field.name) = parseTarget(s);
                                } else if (field.type == ?core.JsxEmit) {
                                    @field(result.options, field.name) = parseJsx(s);
                                } else if (field.type == ?core.ModuleResolutionKind) {
                                    @field(result.options, field.name) = parseModuleResolution(s);
                                } else if (field.type == ?core.ModuleDetectionKind) {
                                    @field(result.options, field.name) = parseModuleDetection(s);
                                } else if (field.type == ?core.NewLineKind) {
                                    @field(result.options, field.name) = parseNewLine(s);
                                }
                            },
                            .array => |array| {
                                if (field.type == ?[]const []const u8) {
                                    var values = std.ArrayList([]const u8).empty;
                                    for (array.items) |item| if (item == .string) try values.append(allocator, try allocator.dupe(u8, item.string));
                                    @field(result.options, field.name) = try values.toOwnedSlice(allocator);
                                }
                            },
                            else => {},
                        }
                    }
                }
                if (std.mem.eql(u8, key, "paths") and val == .object) {
                    var mappings = val.object.iterator();
                    while (mappings.next()) |mapping| {
                        if (mapping.value_ptr.* != .array) continue;
                        var targets = std.ArrayList([]const u8).empty;
                        for (mapping.value_ptr.array.items) |target| if (target == .string) try targets.append(allocator, try allocator.dupe(u8, target.string));
                        try result.pathMappings.append(allocator, .{ .pattern = try allocator.dupe(u8, mapping.key_ptr.*), .targets = try targets.toOwnedSlice(allocator) });
                    }
                }
            }
        }
    }

    if (root.object.get("files")) |files| {
        result.hasExplicitFiles = true;
        if (files == .array) {
            for (files.array.items) |f| {
                if (f == .string) {
                    try result.fileNames.append(allocator, try allocator.dupe(u8, f.string));
                }
            }
        }
    }
    if (root.object.get("include")) |include| if (include == .array) for (include.array.items) |item| if (item == .string) try result.includeSpecs.append(allocator, try allocator.dupe(u8, item.string));
    if (root.object.get("exclude")) |exclude| if (exclude == .array) for (exclude.array.items) |item| if (item == .string) try result.excludeSpecs.append(allocator, try allocator.dupe(u8, item.string));

    if (root.object.get("references")) |references| {
        if (references == .array) for (references.array.items) |reference| {
            if (reference != .object) continue;
            if (reference.object.get("path")) |path| if (path == .string) {
                try result.projectReferences.append(allocator, try allocator.dupe(u8, path.string));
            };
        };
    }

    // Include / Exclude could be added here (requires glob implementation or basic string matching)

    return result;
}

fn inheritConfig(allocator: std.mem.Allocator, child: *ParsedTsConfig, base: *const ParsedTsConfig) !void {
    inline for (std.meta.fields(core.CompilerOptions)) |field| {
        if (@typeInfo(field.type) != .optional) continue;
        if (@field(child.options, field.name) == null and @field(base.options, field.name) != null) {
            if (field.type == ?[]const u8) {
                @field(child.options, field.name) = try allocator.dupe(u8, @field(base.options, field.name).?);
            } else if (field.type == ?bool or field.type == ?core.ModuleKind or field.type == ?core.ScriptTarget or field.type == ?core.JsxEmit or field.type == ?core.ModuleResolutionKind) {
                @field(child.options, field.name) = @field(base.options, field.name);
            }
        }
    }
    if (!child.hasExplicitFiles) {
        child.hasExplicitFiles = base.hasExplicitFiles;
        for (base.fileNames.items) |file| try child.fileNames.append(allocator, try allocator.dupe(u8, file));
    }
    if (child.pathMappings.items.len == 0) for (base.pathMappings.items) |mapping| {
        var targets = std.ArrayList([]const u8).empty;
        for (mapping.targets) |target| try targets.append(allocator, try allocator.dupe(u8, target));
        try child.pathMappings.append(allocator, .{ .pattern = try allocator.dupe(u8, mapping.pattern), .targets = try targets.toOwnedSlice(allocator) });
    };
    if (child.includeSpecs.items.len == 0) for (base.includeSpecs.items) |spec| try child.includeSpecs.append(allocator, try allocator.dupe(u8, spec));
    if (child.excludeSpecs.items.len == 0) for (base.excludeSpecs.items) |spec| try child.excludeSpecs.append(allocator, try allocator.dupe(u8, spec));
}

fn resolveConfigPath(allocator: std.mem.Allocator, value: *?[]const u8, directory: []const u8) !void {
    if (value.*) |path| if (!std.fs.path.isAbsolute(path)) {
        value.* = try std.fs.path.join(allocator, &.{ directory, path });
        allocator.free(path);
    };
}

fn resolveConfigPathList(allocator: std.mem.Allocator, value: *?[]const []const u8, directory: []const u8) !void {
    const paths = value.* orelse return;
    const resolved = try allocator.alloc([]const u8, paths.len);
    for (paths, 0..) |path, index| {
        resolved[index] = if (std.fs.path.isAbsolute(path)) try allocator.dupe(u8, path) else try std.fs.path.join(allocator, &.{ directory, path });
        allocator.free(path);
    }
    allocator.free(paths);
    value.* = resolved;
}

fn sanitizeJsonc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var without_comments = std.ArrayList(u8).empty;
    var index: usize = 0;
    var in_string = false;
    var escaped = false;
    while (index < input.len) {
        const char = input[index];
        if (in_string) {
            try without_comments.append(allocator, char);
            if (escaped) escaped = false else if (char == '\\') escaped = true else if (char == '"') in_string = false;
            index += 1;
            continue;
        }
        if (char == '"') {
            in_string = true;
            try without_comments.append(allocator, char);
            index += 1;
        } else if (char == '/' and index + 1 < input.len and input[index + 1] == '/') {
            index += 2;
            while (index < input.len and input[index] != '\n') : (index += 1) {}
        } else if (char == '/' and index + 1 < input.len and input[index + 1] == '*') {
            index += 2;
            while (index + 1 < input.len and !(input[index] == '*' and input[index + 1] == '/')) : (index += 1) {}
            index = @min(index + 2, input.len);
        } else {
            try without_comments.append(allocator, char);
            index += 1;
        }
    }

    var result = std.ArrayList(u8).empty;
    index = 0;
    in_string = false;
    escaped = false;
    while (index < without_comments.items.len) : (index += 1) {
        const char = without_comments.items[index];
        if (in_string) {
            try result.append(allocator, char);
            if (escaped) escaped = false else if (char == '\\') escaped = true else if (char == '"') in_string = false;
            continue;
        }
        if (char == '"') in_string = true;
        if (char == ',') {
            var next = index + 1;
            while (next < without_comments.items.len and std.ascii.isWhitespace(without_comments.items[next])) : (next += 1) {}
            if (next < without_comments.items.len and (without_comments.items[next] == '}' or without_comments.items[next] == ']')) continue;
        }
        try result.append(allocator, char);
        // The TypeScript config parser recovers from a missing comma between
        // object properties and still builds the project. Preserve that useful
        // recovery for JSONC instead of rejecting the whole compilation.
        if (char == '}' or char == ']') {
            var next = index + 1;
            while (next < without_comments.items.len and std.ascii.isWhitespace(without_comments.items[next])) : (next += 1) {}
            if (next < without_comments.items.len and without_comments.items[next] == '"') try result.append(allocator, ',');
        }
    }
    without_comments.deinit(allocator);
    return result.toOwnedSlice(allocator);
}

test "tsconfig parses list and modern resolution options" {
    const allocator = std.testing.allocator;
    var parsed = try parseTsConfigSlice(allocator,
        \\{
        \\  "compilerOptions": {
        \\    "moduleResolution": "bundler",
        \\    "moduleDetection": "force",
        \\    "newLine": "lf",
        \\    "lib": ["es2022", "dom"],
        \\    "types": ["node"]
        \\  }
        \\}
    );
    defer parsed.deinit(allocator);
    try std.testing.expectEqual(core.ModuleResolutionKind.Bundler, parsed.options.moduleResolution.?);
    try std.testing.expectEqual(core.ModuleDetectionKind.Force, parsed.options.moduleDetection.?);
    try std.testing.expectEqual(core.NewLineKind.LineFeed, parsed.options.newLine.?);
    try std.testing.expectEqualStrings("es2022", parsed.options.lib.?[0]);
    try std.testing.expectEqualStrings("node", parsed.options.types.?[0]);
}

test "tsconfig accepts comments and trailing commas" {
    var parsed = try parseTsConfigSlice(std.testing.allocator,
        \\{
        \\  // comment
        \\  "compilerOptions": { "module": "commonjs", },
        \\  "files": ["a.ts",],
        \\}
    );
    defer parsed.deinit(std.testing.allocator);
    try std.testing.expectEqual(core.ModuleKind.CommonJS, parsed.options.module.?);
    try std.testing.expectEqual(@as(usize, 1), parsed.fileNames.items.len);
}

fn parseModule(value: []const u8) ?core.ModuleKind {
    if (std.ascii.eqlIgnoreCase(value, "commonjs")) return .CommonJS;
    if (std.ascii.eqlIgnoreCase(value, "preserve")) return .Preserve;
    if (std.ascii.eqlIgnoreCase(value, "es2015") or std.ascii.eqlIgnoreCase(value, "es6")) return .ES2015;
    if (std.ascii.eqlIgnoreCase(value, "es2020")) return .ES2020;
    if (std.ascii.eqlIgnoreCase(value, "es2022")) return .ES2022;
    if (std.ascii.eqlIgnoreCase(value, "esnext")) return .ESNext;
    if (std.ascii.eqlIgnoreCase(value, "node16")) return .Node16;
    if (std.ascii.eqlIgnoreCase(value, "nodenext")) return .NodeNext;
    return null;
}

fn parseTarget(value: []const u8) ?core.ScriptTarget {
    if (std.ascii.eqlIgnoreCase(value, "es5")) return .ES5;
    if (std.ascii.eqlIgnoreCase(value, "es2015") or std.ascii.eqlIgnoreCase(value, "es6")) return .ES2015;
    inline for (2016..2026) |year| if (std.ascii.eqlIgnoreCase(value, std.fmt.comptimePrint("es{d}", .{year}))) return @enumFromInt(year - 2013);
    if (std.ascii.eqlIgnoreCase(value, "esnext")) return .ESNext;
    return null;
}

fn parseModuleResolution(value: []const u8) ?core.ModuleResolutionKind {
    if (std.ascii.eqlIgnoreCase(value, "classic")) return .Classic;
    if (std.ascii.eqlIgnoreCase(value, "node") or std.ascii.eqlIgnoreCase(value, "node10") or std.ascii.eqlIgnoreCase(value, "nodejs")) return .NodeJs;
    if (std.ascii.eqlIgnoreCase(value, "node16")) return .Node16;
    if (std.ascii.eqlIgnoreCase(value, "nodenext")) return .NodeNext;
    if (std.ascii.eqlIgnoreCase(value, "bundler")) return .Bundler;
    return null;
}

fn parseModuleDetection(value: []const u8) ?core.ModuleDetectionKind {
    if (std.ascii.eqlIgnoreCase(value, "legacy")) return .Legacy;
    if (std.ascii.eqlIgnoreCase(value, "auto")) return .Auto;
    if (std.ascii.eqlIgnoreCase(value, "force")) return .Force;
    return null;
}

fn parseNewLine(value: []const u8) ?core.NewLineKind {
    if (std.ascii.eqlIgnoreCase(value, "crlf")) return .CarriageReturnLineFeed;
    if (std.ascii.eqlIgnoreCase(value, "lf")) return .LineFeed;
    return null;
}

fn parseJsx(value: []const u8) ?core.JsxEmit {
    if (std.ascii.eqlIgnoreCase(value, "preserve")) return .Preserve;
    if (std.ascii.eqlIgnoreCase(value, "react")) return .React;
    if (std.ascii.eqlIgnoreCase(value, "react-jsx")) return .ReactJSX;
    if (std.ascii.eqlIgnoreCase(value, "react-jsxdev")) return .ReactJSXDev;
    if (std.ascii.eqlIgnoreCase(value, "react-native")) return .ReactNative;
    return null;
}
