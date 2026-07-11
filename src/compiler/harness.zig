const std = @import("std");
const core = @import("../core/core.zig");
const test_case_parser = @import("../testrunner/test_case_parser.zig");
const tspath = @import("../tspath/tspath.zig");

const require_str = "require(";
const references_regex = "reference path";

pub fn isHarnessContent(content: []const u8) bool {
    var line_start: usize = 0;
    while (line_start < content.len) {
        var line_end = line_start;
        while (line_end < content.len and content[line_end] != '\n') : (line_end += 1) {}
        var line = content[line_start..line_end];
        if (line.len > 0 and line[line.len - 1] == '\r') line = line[0 .. line.len - 1];
        line_start = line_end + 1;

        const trimmed = std.mem.trim(u8, line, " \t");
        if (std.mem.startsWith(u8, trimmed, "//")) {
            const after = std.mem.trim(u8, trimmed[2..], " \t");
            if (std.ascii.eqlIgnoreCase(after[0..@min(9, after.len)], "@filename")) return true;
        }
    }
    return false;
}

fn parseHarnessBool(value: []const u8) ?bool {
    if (std.ascii.eqlIgnoreCase(value, "true")) return true;
    if (std.ascii.eqlIgnoreCase(value, "false")) return false;
    return null;
}

fn isHarnessOnlyOption(key: []const u8) bool {
    const harness_only = [_][]const u8{
        "filename",
        "notypesandsymbols",
        "currentdirectory",
        "symlink",
        "link",
        "baselinefile",
        "libfiles",
        "includebuiltfile",
    };
    for (harness_only) |name| {
        if (std.mem.eql(u8, key, name)) return true;
    }
    return false;
}

fn parseHarnessModule(value: []const u8) ?core.ModuleKind {
    if (std.ascii.eqlIgnoreCase(value, "commonjs")) return .CommonJS;
    if (std.ascii.eqlIgnoreCase(value, "node16")) return .Node16;
    if (std.ascii.eqlIgnoreCase(value, "nodenext")) return .NodeNext;
    if (std.ascii.eqlIgnoreCase(value, "esnext")) return .ESNext;
    if (std.ascii.eqlIgnoreCase(value, "es2015") or std.ascii.eqlIgnoreCase(value, "es6")) return .ES2015;
    return null;
}

fn parseHarnessModuleResolution(value: []const u8) ?core.ModuleResolutionKind {
    if (std.ascii.eqlIgnoreCase(value, "node") or std.ascii.eqlIgnoreCase(value, "node10")) return .NodeJs;
    if (std.ascii.eqlIgnoreCase(value, "node16")) return .Node16;
    if (std.ascii.eqlIgnoreCase(value, "nodenext")) return .NodeNext;
    if (std.ascii.eqlIgnoreCase(value, "bundler")) return .Bundler;
    return null;
}

fn applyHarnessOption(key: []const u8, value: []const u8, options: *core.CompilerOptions) void {
    if (isHarnessOnlyOption(key)) return;
    if (parseHarnessBool(value)) |parsed| {
        if (std.ascii.eqlIgnoreCase(key, "checkJs")) {
            options.checkJs = parsed;
        } else if (std.ascii.eqlIgnoreCase(key, "allowJs")) {
            options.allowJs = parsed;
        } else if (std.ascii.eqlIgnoreCase(key, "noImplicitAny")) {
            options.noImplicitAny = parsed;
        } else if (std.ascii.eqlIgnoreCase(key, "strict")) {
            options.strict = parsed;
        } else if (std.ascii.eqlIgnoreCase(key, "declaration")) {
            options.declaration = parsed;
        } else if (std.ascii.eqlIgnoreCase(key, "strictNullChecks")) {
            options.strictNullChecks = parsed;
        } else if (std.ascii.eqlIgnoreCase(key, "noEmit")) {
            options.noEmit = parsed;
        } else if (std.ascii.eqlIgnoreCase(key, "allowSyntheticDefaultImports")) {
            options.allowSyntheticDefaultImports = parsed;
        } else if (std.ascii.eqlIgnoreCase(key, "erasableSyntaxOnly")) {
            options.erasableSyntaxOnly = parsed;
        } else if (std.ascii.eqlIgnoreCase(key, "skipLibCheck")) {
            options.skipLibCheck = parsed;
        }
        return;
    }
    if (std.ascii.eqlIgnoreCase(key, "module")) {
        if (parseHarnessModule(value)) |kind| options.module = kind;
    } else if (std.ascii.eqlIgnoreCase(key, "moduleResolution")) {
        if (parseHarnessModuleResolution(value)) |kind| options.moduleResolution = kind;
    }
}

pub fn applyHarnessSettings(allocator: std.mem.Allocator, content: []const u8, options: *core.CompilerOptions) !void {
    var settings = try test_case_parser.extractCompilerSettings(allocator, content);
    defer settings.deinit();

    var it = settings.iterator();
    while (it.next()) |entry| {
        applyHarnessOption(entry.key_ptr.*, entry.value_ptr.*, options);
    }
}

pub const HarnessUnit = struct {
    path: []const u8,
    name: []const u8,
    content: []const u8,
};

pub fn parseHarnessUnits(
    allocator: std.mem.Allocator,
    harness_path: []const u8,
    content: []const u8,
) !struct {
    units: []HarnessUnit,
    harness_dir: []const u8,
} {
    const TestFileParser = struct {
        fn parse(alloc: std.mem.Allocator, name: []const u8, file_content: []const u8, file_options: std.StringHashMap([]const u8)) anyerror!test_case_parser.TestUnit {
            _ = file_options;
            return .{
                .content = try alloc.dupe(u8, file_content),
                .name = try alloc.dupe(u8, name),
            };
        }
    };

    var parsed = try test_case_parser.parseTestFilesAndSymlinks(
        test_case_parser.TestUnit,
        allocator,
        content,
        harness_path,
        TestFileParser.parse,
    );
    defer {
        for (parsed.units.items) |unit| {
            allocator.free(unit.content);
            allocator.free(unit.name);
        }
        parsed.units.deinit(allocator);
        parsed.symlinks.deinit();
        parsed.globalOptions.deinit();
        if (parsed.currentDir.len != 0) allocator.free(parsed.currentDir);
    }

    const harness_dir = if (parsed.currentDir.len != 0)
        try allocator.dupe(u8, parsed.currentDir)
    else
        try allocator.dupe(u8, std.fs.path.dirname(harness_path) orelse ".");

    var units = std.ArrayList(HarnessUnit).empty;
    for (parsed.units.items) |unit| {
        const abs_path = try tspath.getNormalizedAbsolutePath(allocator, unit.name, harness_dir);
        try units.append(allocator, .{
            .path = abs_path,
            .name = try allocator.dupe(u8, unit.name),
            .content = try allocator.dupe(u8, unit.content),
        });
    }

    return .{
        .units = try units.toOwnedSlice(allocator),
        .harness_dir = harness_dir,
    };
}

fn isTsConfigFileName(name: []const u8) bool {
    const base = std.fs.path.basename(name);
    return std.mem.eql(u8, base, "tsconfig.json");
}

fn isProgramInputFile(name: []const u8) bool {
    const ext = std.fs.path.extension(name);
    return std.mem.eql(u8, ext, ".ts") or
        std.mem.eql(u8, ext, ".tsx") or
        std.mem.eql(u8, ext, ".mts") or
        std.mem.eql(u8, ext, ".cts") or
        std.mem.eql(u8, ext, ".js") or
        std.mem.eql(u8, ext, ".jsx") or
        std.mem.eql(u8, ext, ".mjs") or
        std.mem.eql(u8, ext, ".cjs");
}

fn contentReferencesOtherFiles(content: []const u8) bool {
    if (std.mem.indexOf(u8, content, require_str) != null) return true;
    if (std.ascii.indexOfIgnoreCase(content, references_regex) != null) return true;
    return false;
}

fn writeHarnessFile(io: std.Io, workspace_dir: []const u8, relative_name: []const u8, content: []const u8) !void {
    const full_path = try std.fs.path.join(std.heap.page_allocator, &.{ workspace_dir, relative_name });
    defer std.heap.page_allocator.free(full_path);
    if (std.fs.path.dirname(relative_name)) |parent| {
        const parent_path = try std.fs.path.join(std.heap.page_allocator, &.{ workspace_dir, parent });
        defer std.heap.page_allocator.free(parent_path);
        try std.Io.Dir.cwd().createDirPath(io, parent_path);
    }
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = full_path, .data = content });
}

pub const HarnessCompilation = struct {
    workspace_dir: []const u8,
    project_dir: []const u8,
    root_names: []const []const u8,
    project_config_path: ?[]const u8 = null,
};

pub fn deinitHarnessCompilation(allocator: std.mem.Allocator, compilation: *HarnessCompilation) void {
    allocator.free(compilation.workspace_dir);
    allocator.free(compilation.project_dir);
    for (compilation.root_names) |name| allocator.free(name);
    allocator.free(compilation.root_names);
    if (compilation.project_config_path) |path| allocator.free(path);
    compilation.* = undefined;
}

pub fn tryPrepareHarnessCompilation(
    allocator: std.mem.Allocator,
    io: std.Io,
    harness_path: []const u8,
    options: *core.CompilerOptions,
) !?HarnessCompilation {
    const content = std.Io.Dir.cwd().readFileAlloc(io, harness_path, allocator, @enumFromInt(std.math.maxInt(usize))) catch return null;
    defer allocator.free(content);
    if (!isHarnessContent(content)) return null;

    try applyHarnessSettings(allocator, content, options);

    const parsed = try parseHarnessUnits(allocator, harness_path, content);
    defer {
        for (parsed.units) |unit| {
            allocator.free(unit.path);
            allocator.free(unit.name);
            allocator.free(unit.content);
        }
        allocator.free(parsed.units);
        allocator.free(parsed.harness_dir);
    }
    if (parsed.units.len == 0) return null;

    const harness_base = std.fs.path.stem(std.fs.path.basename(harness_path));
    // Materialize the harness workspace under the current working directory rather
    // than alongside the source test file, so test discovery tools that walk the
    // testdata tree do not pick up the expanded units as standalone test cases.
    const workspace_dir = try std.fs.path.join(allocator, &.{ ".zig-harness", harness_base });
    std.Io.Dir.cwd().deleteTree(io, workspace_dir) catch {};
    try std.Io.Dir.cwd().createDirPath(io, workspace_dir);

    var tsconfig_relative: ?[]const u8 = null;
    for (parsed.units) |unit| {
        try writeHarnessFile(io, workspace_dir, unit.name, unit.content);
        if (isTsConfigFileName(unit.name)) {
            tsconfig_relative = unit.name;
        }
    }

    var root_names = std.ArrayList([]const u8).empty;
    errdefer {
        for (root_names.items) |name| allocator.free(name);
        root_names.deinit(allocator);
    }

    if (tsconfig_relative) |config_rel| {
        const config_path = try std.fs.path.join(allocator, &.{ workspace_dir, config_rel });
        return HarnessCompilation{
            .workspace_dir = try allocator.dupe(u8, workspace_dir),
            .project_dir = try allocator.dupe(u8, workspace_dir),
            .root_names = &.{},
            .project_config_path = config_path,
        };
    }

    const last_unit = parsed.units[parsed.units.len - 1];
    const implicit_refs = contentReferencesOtherFiles(last_unit.content);
    if (implicit_refs) {
        const last_path = try std.fs.path.join(allocator, &.{ workspace_dir, last_unit.name });
        try root_names.append(allocator, last_path);
    } else {
        for (parsed.units) |unit| {
            if (!isProgramInputFile(unit.name) and !std.mem.endsWith(u8, unit.name, ".d.ts")) continue;
            const full_path = try std.fs.path.join(allocator, &.{ workspace_dir, unit.name });
            try root_names.append(allocator, full_path);
        }
    }

    if (root_names.items.len == 0) {
        for (root_names.items) |name| allocator.free(name);
        root_names.deinit(allocator);
        return null;
    }

    return HarnessCompilation{
        .workspace_dir = try allocator.dupe(u8, workspace_dir),
        .project_dir = try allocator.dupe(u8, workspace_dir),
        .root_names = try root_names.toOwnedSlice(allocator),
        .project_config_path = null,
    };
}

test "harness materializes allowSyntheticDefaultImports9 units" {
    var threaded = std.Io.Threaded.init(std.testing.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const harness_path = "submodule/typescript-go/testdata/tests/cases/compiler/allowSyntheticDefaultImports9.ts";
    var options = core.CompilerOptions{};
    const maybe = try tryPrepareHarnessCompilation(std.testing.allocator, io, harness_path, &options);
    if (maybe) |compilation| {
        defer deinitHarnessCompilation(std.testing.allocator, &compilation);
        try std.testing.expect(compilation.root_names.len >= 1);
        try std.testing.expect(options.allowSyntheticDefaultImports == true);
        try std.testing.expect(options.module == .CommonJS);
    } else |_| {
        // Submodule path may be unavailable in some environments.
    }
}

test "harness materializes packageJsonImportsWildcardNoCrash with tsconfig" {
    var threaded = std.Io.Threaded.init(std.testing.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const harness_path = "submodule/typescript-go/testdata/tests/cases/compiler/packageJsonImportsWildcardNoCrash.ts";
    var options = core.CompilerOptions{};
    const maybe = try tryPrepareHarnessCompilation(std.testing.allocator, io, harness_path, &options);
    if (maybe) |compilation| {
        defer deinitHarnessCompilation(std.testing.allocator, &compilation);
        try std.testing.expect(compilation.project_config_path != null);
        try std.testing.expect(options.noEmit == true);
    } else |_| {}
}
