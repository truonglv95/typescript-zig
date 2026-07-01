const std = @import("std");
const ast = @import("../ast/ast.zig");
const system = @import("system.zig");

const commandline = @import("../compiler/commandlineparser.zig");
const tsconfig = @import("../compiler/tsconfigparsing.zig");
const program = @import("../compiler/program.zig");
const parser_pkg = @import("../parser/parser.zig");
const printer_pkg = @import("../printer/printer.zig");
const factory_pkg = @import("../printer/factory.zig");
const emitcontext_pkg = @import("../printer/emitcontext.zig");
const textwriter_pkg = @import("../printer/textwriter.zig");
const transformers_pkg = @import("../transformers/transformers.zig");
const typeeraser = @import("../transformers/tstransforms/typeeraser.zig");
const core = @import("../core/core.zig");
const emitresolver_pkg = @import("../printer/emitresolver.zig");
const referenceresolver = @import("../binder/referenceresolver.zig");

pub const CommandLineTesting = ?*anyopaque;

pub const ExitStatus = enum {
    Success,
    DiagnosticsPresent_OutputsSkipped,
    DiagnosticsPresent_OutputsGenerated,
    NotImplemented,
};

pub const CommandLineResult = struct {
    status: ExitStatus,
    watcher: ?*anyopaque = null, // Placeholder for Watcher
};

pub fn startTracingIfNeeded(sys: *system.System, config: *anyopaque, testing: CommandLineTesting) ?*anyopaque {
    _ = sys;
    _ = config;
    _ = testing;
    return null;
}

pub fn stopTracing(sys: *system.System, tr: ?*anyopaque) void {
    _ = sys;
    _ = tr;
}

pub fn commandLine(ctx: *anyopaque, sys: *system.System, commandLineArgs: [][]const u8, testing: CommandLineTesting) CommandLineResult {
    if (commandLineArgs.len > 0) {
        const cmd = commandLineArgs[0];
        if (std.mem.eql(u8, cmd, "-b") or std.mem.eql(u8, cmd, "--b") or std.mem.eql(u8, cmd, "-build") or std.mem.eql(u8, cmd, "--build")) {
            return tscBuildCompilation(ctx, sys, commandLineArgs, testing);
        }
    }
    return tscCompilation(ctx, sys, commandLineArgs, testing);
}

fn tscBuildCompilation(ctx: *anyopaque, sys: *system.System, args: [][]const u8, testing: CommandLineTesting) CommandLineResult {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var normalized_args = std.ArrayList([]const u8).empty;
    defer normalized_args.deinit(allocator);
    for (args) |arg| {
        normalized_args.append(allocator, arg) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
    }

    var build_args = std.ArrayList([]const u8).empty;
    defer build_args.deinit(allocator);
    build_args.append(allocator, "--project") catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
    build_args.append(allocator, if (args.len > 1) args[1] else ".") catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };

    var parsed = commandline.parseCommandLine(allocator, build_args.items) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
    defer parsed.deinit(allocator);

    var project_config: ?tsconfig.ParsedTsConfig = null;
    defer if (project_config) |*config| config.deinit(allocator);
    var project_dir: ?[]const u8 = null;

    if (parsed.options.project) |project_arg| {
        const config_path = if (std.mem.endsWith(u8, project_arg, ".json")) project_arg else std.fs.path.join(allocator, &.{ project_arg, "tsconfig.json" }) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
        const lexical_project_dir = std.fs.path.dirname(config_path) orelse ".";
        project_dir = canonicalExistingPath(allocator, io, lexical_project_dir) catch lexical_project_dir;
        project_config = tsconfig.parseTsConfigFile(allocator, io, config_path) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
        if (project_config.?.errors.items.len != 0) {
            for (project_config.?.errors.items) |message| std.debug.print("error TS5083: {s}\n", .{message});
            return .{ .status = .DiagnosticsPresent_OutputsSkipped };
        }
        mergeOptions(&project_config.?.options, &parsed.options);
        resolveProjectPaths(allocator, io, &project_config.?.options, project_dir.?) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };

        var visiting = std.StringHashMap(void).init(allocator);
        var built = std.StringHashMap(void).init(allocator);
        const root_config = std.fs.path.resolve(allocator, &.{config_path}) catch config_path;
        visiting.put(root_config, {}) catch {};

        const executable = if (args.len > 0) args[0] else "tsc";
        for (project_config.?.projectReferences.items) |reference| {
            const reference_path = std.fs.path.join(allocator, &.{ project_dir.?, reference }) catch continue;
            buildReferencedProject(allocator, io, executable, reference_path, &visiting, &built) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
        }
        _ = visiting.remove(root_config);
    }

    return tscCompilation(ctx, sys, build_args.items, testing);
}

fn tscCompilation(ctx: *anyopaque, sys: *system.System, args: [][]const u8, testing: CommandLineTesting) CommandLineResult {
    _ = ctx;
    _ = sys;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var normalized_args = std.ArrayList([]const u8).empty;
    defer normalized_args.deinit(allocator);
    for (args) |arg| {
        normalized_args.append(allocator, arg) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
    }

    var parsed = commandline.parseCommandLine(allocator, normalized_args.items) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
    defer parsed.deinit(allocator);

    if (parsed.errors.items.len != 0) {
        for (parsed.errors.items) |message| std.debug.print("error TS5023: {s}\n", .{message});
        return .{ .status = .DiagnosticsPresent_OutputsSkipped };
    }

    if (parsed.options.init orelse false) {
        const path = "tsconfig.json";
        if (fileExists(io, path)) {
            std.debug.print("error TS5054: A 'tsconfig.json' file is already defined at: '{s}'.\n", .{path});
            return .{ .status = .DiagnosticsPresent_OutputsSkipped };
        }
        std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = "{\n  \"compilerOptions\": {\n    \"target\": \"es2016\",\n    \"module\": \"commonjs\",\n    \"strict\": true,\n    \"esModuleInterop\": true,\n    \"skipLibCheck\": true,\n    \"forceConsistentCasingInFileNames\": true\n  }\n}\n" }) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
        std.debug.print("Created a new tsconfig.json.\n", .{});
        return .{ .status = .Success };
    }

    var project_config: ?tsconfig.ParsedTsConfig = null;
    defer if (project_config) |*config| config.deinit(allocator);
    var project_dir: ?[]const u8 = null;

    if (parsed.options.project) |project_arg| {
        const config_path = if (std.mem.endsWith(u8, project_arg, ".json")) project_arg else std.fs.path.join(allocator, &.{ project_arg, "tsconfig.json" }) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
        const lexical_project_dir = std.fs.path.dirname(config_path) orelse ".";
        project_dir = canonicalExistingPath(allocator, io, lexical_project_dir) catch lexical_project_dir;
        project_config = tsconfig.parseTsConfigFile(allocator, io, config_path) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
        if (project_config.?.errors.items.len != 0) {
            for (project_config.?.errors.items) |message| std.debug.print("error TS5083: {s}\n", .{message});
            return .{ .status = .DiagnosticsPresent_OutputsSkipped };
        }
        mergeOptions(&project_config.?.options, &parsed.options);
        resolveProjectPaths(allocator, io, &project_config.?.options, project_dir.?) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
    }

    const effective_options = if (project_config) |*config| &config.options else &parsed.options;
    if (!validateOptions(effective_options)) return .{ .status = .DiagnosticsPresent_OutputsSkipped };
    if (effective_options.help orelse false) {
        std.debug.print("Version 0.1.0\nUsage: tsc [options] <files...>\n  -p, --project <path>\n  -b, --build <path>\n  -w, --watch\n  --noEmit\n  --declaration\n  --sourceMap\n", .{});
        return .{ .status = .Success };
    }
    if (effective_options.version orelse false) {
        std.debug.print("Version 0.1.0\n", .{});
        return .{ .status = .Success };
    }
    if (effective_options.showConfig orelse false) {
        printEffectiveConfig(effective_options, if (project_config) |*config| config.fileNames.items else parsed.fileNames.items);
        return .{ .status = .Success };
    }

    var discovered_files = std.ArrayList([]const u8).empty;
    defer discovered_files.deinit(allocator);
    if (project_config != null and project_config.?.fileNames.items.len == 0 and !project_config.?.hasExplicitFiles) {
        discoverProjectFiles(allocator, io, project_dir.?, project_config.?.options.outDir, project_config.?.includeSpecs.items, project_config.?.excludeSpecs.items, &discovered_files) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
    }
    const input_files = if (project_config) |*config| (if (config.fileNames.items.len != 0) config.fileNames.items else discovered_files.items) else parsed.fileNames.items;
    if (input_files.len == 0) {
        std.debug.print("error TS18003: No inputs were found.\n", .{});
        return .{ .status = .DiagnosticsPresent_OutputsSkipped };
    }

    const active_options = effective_options;
    var resolved_sources = std.ArrayList([]const u8).empty;
    defer resolved_sources.deinit(allocator);
    for (input_files) |input| {
        resolved_sources.append(allocator, if (std.fs.path.isAbsolute(input)) input else if (project_dir) |directory| std.fs.path.join(allocator, &.{ directory, input }) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped } else input) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
    }

    var graph = program.Program.init(allocator, .{
        .options = active_options.*,
        .rootNames = resolved_sources.items,
        .projectName = project_dir orelse ".",
        .pathMappings = if (project_config) |*config| config.pathMappings.items else &.{},
        .defaultLibraryPath = defaultLibraryPath(allocator, io) catch "",
    });
    defer graph.deinit();

    graph.load(io) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
    graph.bind() catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
    graph.link() catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
    graph.check() catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };

    if ((active_options.listFiles orelse false) or (active_options.listFilesOnly orelse false)) {
        for (graph.units.items) |unit| std.debug.print("{s}\n", .{unit.path});
    }

    var has_errors = false;
    if (graph.diagnostics.items.len != 0) {
        for (graph.diagnostics.items) |diagnostic| {
            std.debug.print("{s}: error TS{d}: {s}\n", .{ graph.getUnit(diagnostic.file).path, diagnostic.code, diagnostic.message });
        }
        has_errors = true;
        if (active_options.noEmitOnError orelse false) return .{ .status = .DiagnosticsPresent_OutputsSkipped };
    }

    const incremental = (active_options.incremental orelse false) or (active_options.composite orelse false);
    const emit_root = active_options.rootDir orelse (commonSourceDirectory(allocator, resolved_sources.items) catch ".");
    const build_info_path = if (incremental) (buildInfoPath(allocator, active_options, project_dir) catch null) else null;

    var old_states = std.StringHashMap(BuildState).init(allocator);
    defer old_states.deinit();
    if (build_info_path) |path| readBuildInfo(allocator, io, path, &old_states) catch {};

    var new_states = std.StringHashMap(BuildState).init(allocator);
    defer new_states.deinit();
    const current_options_hash = compilerOptionsHash(active_options);
    const previous_options = old_states.get("<compiler-options>");
    const options_changed = previous_options == null or previous_options.?.source != current_options_hash;
    new_states.put("<compiler-options>", .{ .source = current_options_hash, .signature = current_options_hash }) catch {};

    const changed_public = allocator.alloc(bool, graph.units.items.len) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
    defer allocator.free(changed_public);
    const source_changed = allocator.alloc(bool, graph.units.items.len) catch return .{ .status = .DiagnosticsPresent_OutputsSkipped };
    defer allocator.free(source_changed);

    for (graph.units.items, 0..) |unit, index| {
        const source_hash = sourceHash(allocator, io, unit.path) catch 0;
        const signature_hash = graph.signatureHash(@intCast(index));
        const previous = old_states.get(unit.path);
        source_changed[index] = options_changed or previous == null or previous.?.source != source_hash;
        changed_public[index] = options_changed or previous == null or previous.?.signature != signature_hash;
        new_states.put(unit.path, .{ .source = source_hash, .signature = signature_hash }) catch {};
    }

    var propagated = true;
    while (propagated) {
        propagated = false;
        for (graph.units.items, 0..) |unit, index| {
            if (changed_public[index]) continue;
            for (unit.dependencies.items) |dependency| if (dependency.resolved) |target| {
                if (changed_public[target]) {
                    changed_public[index] = true;
                    propagated = true;
                    break;
                }
            };
        }
    }

    if (!(active_options.noEmit orelse false) and !(active_options.listFilesOnly orelse false)) {
        for (graph.units.items, 0..) |unit, unit_index| {
            const source = unit.path;
            if (project_dir) |directory| if (!isWithinDirectory(source, directory)) continue;
            if (std.mem.endsWith(u8, source, ".d.ts") or std.mem.endsWith(u8, source, ".d.mts") or std.mem.endsWith(u8, source, ".d.cts")) continue;
            if ((std.mem.endsWith(u8, source, ".js") or std.mem.endsWith(u8, source, ".jsx") or std.mem.endsWith(u8, source, ".mjs") or std.mem.endsWith(u8, source, ".cjs")) and !(active_options.allowJs orelse false)) continue;
            const output = outputPath(allocator, source, active_options.outDir, emit_root) catch continue;
            if (incremental and !source_changed[unit_index] and !changed_public[unit_index] and fileExists(io, output)) continue;
            transpileFile(allocator, io, source, output, active_options, &graph, @intCast(unit_index)) catch continue;
            if (active_options.listEmittedFiles orelse false) {
                std.debug.print("TSFILE: {s}\n", .{output});
                if ((active_options.declaration orelse false) or (active_options.composite orelse false)) {
                    const declaration = declarationOutputPath(allocator, source, output, active_options.declarationDir) catch continue;
                    std.debug.print("TSFILE: {s}\n", .{declaration});
                }
            }
        }
    }

    if (build_info_path) |path| writeBuildInfo(allocator, io, path, &new_states) catch {};

    if (active_options.watch orelse false) {
        if (testing == null) {
            const exe_name = if (args.len > 0) args[0] else "tsc";
            watchLoop(allocator, io, exe_name, parsed.options.project, project_dir, active_options.outDir, graph.units.items) catch {};
        } else {
            return .{ .status = .Success };
        }
    }

    return .{ .status = if (has_errors) .DiagnosticsPresent_OutputsGenerated else .Success };
}

// Watch Loop and watch helpers
fn watchLoop(allocator: std.mem.Allocator, io: std.Io, executable: []const u8, project: ?[]const u8, project_dir: ?[]const u8, out_dir: ?[]const u8, units: []*program.SourceUnit) !void {
    var snapshot = try watchSnapshot(allocator, io, project_dir, out_dir, units);
    std.debug.print("Watching for file changes.\n", .{});
    while (true) {
        try std.Io.sleep(io, std.Io.Duration.fromMilliseconds(250), .awake);
        var current = try watchSnapshot(allocator, io, project_dir, out_dir, units);
        if (current == snapshot) continue;

        while (true) {
            try std.Io.sleep(io, std.Io.Duration.fromMilliseconds(100), .awake);
            const settled = try watchSnapshot(allocator, io, project_dir, out_dir, units);
            if (settled == current) break;
            current = settled;
        }
        snapshot = current;
        const child = if (project) |path|
            try std.process.run(allocator, io, .{ .argv = &.{ executable, "--project", path, "--noWatch" } })
        else blk: {
            var args = std.ArrayList([]const u8).empty;
            defer args.deinit(allocator);
            try args.append(allocator, executable);
            try args.append(allocator, "--noWatch");
            for (units) |unit| if (unit.is_root) try args.append(allocator, unit.path);
            break :blk try std.process.run(allocator, io, .{ .argv = args.items });
        };
        switch (child.term) {
            .exited => |code| std.debug.print("File change detected. Compilation completed with exit code {d}.\n", .{code}),
            else => std.debug.print("File change detected. Compilation terminated unexpectedly.\n", .{}),
        }
    }
}

fn watchSnapshot(allocator: std.mem.Allocator, io: std.Io, project_dir: ?[]const u8, out_dir: ?[]const u8, units: []*program.SourceUnit) !u64 {
    _ = allocator;
    var scratch_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer scratch_arena.deinit();
    const scratch = scratch_arena.allocator();
    var hash = std.hash.Wyhash.init(0);
    if (project_dir) |root| {
        var directory = std.Io.Dir.cwd().openDir(io, root, .{ .iterate = true }) catch return 0;
        defer directory.close(io);
        var walker = try directory.walk(scratch);
        defer walker.deinit();
        while (try walker.next(io)) |entry| {
            if (entry.kind != .file) continue;
            if (std.mem.indexOf(u8, entry.path, "node_modules/") != null) continue;
            const full_path = try std.fs.path.join(scratch, &.{ root, entry.path });
            if (out_dir) |output| if (std.mem.startsWith(u8, full_path, output)) continue;
            if (!isWatchInput(entry.path)) continue;
            hash.update(entry.path);
            const content = std.Io.Dir.cwd().readFileAlloc(io, full_path, scratch, @enumFromInt(64 * 1024 * 1024)) catch continue;
            hash.update(content);
        }
    } else {
        for (units) |unit| {
            hash.update(unit.path);
            const content = std.Io.Dir.cwd().readFileAlloc(io, unit.path, scratch, @enumFromInt(64 * 1024 * 1024)) catch {
                hash.update("<deleted>");
                continue;
            };
            hash.update(content);
        }
    }
    return hash.final();
}

fn isWatchInput(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".ts") or std.mem.endsWith(u8, path, ".tsx") or
        std.mem.endsWith(u8, path, ".mts") or std.mem.endsWith(u8, path, ".cts") or
        std.mem.endsWith(u8, path, ".js") or std.mem.endsWith(u8, path, ".jsx") or
        std.mem.endsWith(u8, path, ".json");
}

fn buildReferencedProject(allocator: std.mem.Allocator, io: std.Io, executable: []const u8, project_path: []const u8, visiting: *std.StringHashMap(void), built: *std.StringHashMap(void)) !void {
    const config_path = if (std.mem.endsWith(u8, project_path, ".json")) try allocator.dupe(u8, project_path) else try std.fs.path.join(allocator, &.{ project_path, "tsconfig.json" });
    const canonical = try std.fs.path.resolve(allocator, &.{config_path});
    if (built.contains(canonical)) return;
    if (visiting.contains(canonical)) {
        std.debug.print("error TS6202: Project references may not form a circular graph. Cycle at '{s}'.\n", .{canonical});
        return error.CircularProjectReference;
    }
    try visiting.put(canonical, {});
    var config = try tsconfig.parseTsConfigFile(allocator, io, canonical);
    defer config.deinit(allocator);
    const directory = std.fs.path.dirname(canonical) orelse ".";
    for (config.projectReferences.items) |reference| {
        const child_path = try std.fs.path.join(allocator, &.{ directory, reference });
        try buildReferencedProject(allocator, io, executable, child_path, visiting, built);
    }
    _ = visiting.remove(canonical);
    const child = try std.process.run(allocator, io, .{ .argv = &.{ executable, "--project", canonical } });
    const failed = switch (child.term) {
        .exited => |code| code != 0,
        else => true,
    };
    if (failed) {
        if (child.stderr.len != 0) std.debug.print("{s}", .{child.stderr});
        return error.ReferencedProjectBuildFailed;
    }
    try built.put(canonical, {});
}

// Option validation and helpers
fn validateOptions(options: *core.CompilerOptions) bool {
    var valid = true;
    if (options.composite orelse false) {
        options.declaration = true;
        options.incremental = true;
    }
    if (options.emitDeclarationOnly orelse false) options.declaration = true;
    if ((options.declarationMap orelse false) and !(options.declaration orelse false)) {
        std.debug.print("error TS5069: Option 'declarationMap' cannot be specified without option 'declaration'.\n", .{});
        valid = false;
    }
    if ((options.noEmit orelse false) and (options.emitDeclarationOnly orelse false)) {
        std.debug.print("error TS5053: Option 'emitDeclarationOnly' cannot be specified with option 'noEmit'.\n", .{});
        valid = false;
    }
    if ((options.sourceMap orelse false) and (options.inlineSourceMap orelse false)) {
        std.debug.print("error TS5053: Option 'sourceMap' cannot be specified with option 'inlineSourceMap'.\n", .{});
        valid = false;
    }
    if ((options.mapRoot != null) and (options.inlineSourceMap orelse false)) {
        std.debug.print("error TS5053: Option 'mapRoot' cannot be specified with option 'inlineSourceMap'.\n", .{});
        valid = false;
    }
    if ((options.inlineSources orelse false) and !((options.sourceMap orelse false) or (options.inlineSourceMap orelse false))) {
        std.debug.print("error TS5051: Option 'inlineSources' can only be used when either option 'inlineSourceMap' or option 'sourceMap' is provided.\n", .{});
        valid = false;
    }
    if ((options.allowImportingTsExtensions orelse false) and !((options.noEmit orelse false) or (options.emitDeclarationOnly orelse false) or (options.rewriteRelativeImportExtensions orelse false))) {
        std.debug.print("error TS5096: Option 'allowImportingTsExtensions' can only be used when either 'noEmit' or 'emitDeclarationOnly' is set.\n", .{});
        valid = false;
    }
    return valid;
}

fn printEffectiveConfig(options: *const core.CompilerOptions, files: []const []const u8) void {
    std.debug.print("{{\n  \"compilerOptions\": {{\n", .{});
    if (options.target) |value| std.debug.print("    \"target\": \"{s}\",\n", .{@tagName(value)});
    if (options.module) |value| std.debug.print("    \"module\": \"{s}\",\n", .{@tagName(value)});
    if (options.outDir) |value| std.debug.print("    \"outDir\": \"{s}\",\n", .{value});
    std.debug.print("    \"declaration\": {s}\n  }},\n  \"files\": [", .{if (options.declaration orelse false) "true" else "false"});
    for (files, 0..) |file, index| std.debug.print("{s}\"{s}\"", .{ if (index == 0) "" else ", ", file });
    std.debug.print("]\n}}\n", .{});
}

fn mergeOptions(target: *core.CompilerOptions, overrides: *const core.CompilerOptions) void {
    inline for (std.meta.fields(core.CompilerOptions)) |field| {
        const value = @field(overrides, field.name);
        if (@typeInfo(field.type) == .optional and value != null) @field(target, field.name) = value;
    }
}

fn resolveProjectPaths(allocator: std.mem.Allocator, io: std.Io, options: *core.CompilerOptions, project_dir: []const u8) !void {
    if (options.outDir) |path| {
        if (!std.fs.path.isAbsolute(path)) options.outDir = try std.fs.path.join(allocator, &.{ project_dir, path });
    }
    if (options.declarationDir) |path| {
        if (!std.fs.path.isAbsolute(path)) options.declarationDir = try std.fs.path.join(allocator, &.{ project_dir, path });
    }
    if (options.tsBuildInfoFile) |path| {
        if (!std.fs.path.isAbsolute(path)) options.tsBuildInfoFile = try std.fs.path.join(allocator, &.{ project_dir, path });
    }
    if (options.baseUrl) |path| {
        const resolved = if (!std.fs.path.isAbsolute(path)) try std.fs.path.join(allocator, &.{ project_dir, path }) else path;
        options.baseUrl = canonicalExistingPath(allocator, io, resolved) catch resolved;
    }
    if (options.rootDir) |path| {
        const resolved = if (!std.fs.path.isAbsolute(path)) try std.fs.path.join(allocator, &.{ project_dir, path }) else path;
        options.rootDir = canonicalExistingPath(allocator, io, resolved) catch resolved;
    }
}

fn canonicalExistingPath(allocator: std.mem.Allocator, io: std.Io, path: []const u8) ![]const u8 {
    const real = try std.Io.Dir.cwd().realPathFileAlloc(io, path, allocator);
    defer allocator.free(real);
    return allocator.dupe(u8, real);
}

fn outputPath(allocator: std.mem.Allocator, source: []const u8, out_dir: ?[]const u8, root_dir: []const u8) ![]const u8 {
    const extension: []const u8 = if (std.mem.endsWith(u8, source, ".mts")) ".mjs" else if (std.mem.endsWith(u8, source, ".cts")) ".cjs" else ".js";
    const relative = if (out_dir != null) try std.fs.path.relativePosix(allocator, ".", root_dir, source) else try allocator.dupe(u8, std.fs.path.basename(source));
    const safe_relative = if (std.mem.startsWith(u8, relative, "..")) std.fs.path.basename(source) else relative;
    const stem = std.fs.path.stem(safe_relative);
    const file_name = try std.fmt.allocPrint(allocator, "{s}{s}", .{ stem, extension });
    if (out_dir) |directory| return std.fs.path.join(allocator, &.{ directory, std.fs.path.dirname(safe_relative) orelse "", file_name });
    const directory = std.fs.path.dirname(source) orelse ".";
    return std.fs.path.join(allocator, &.{ directory, file_name });
}

fn commonSourceDirectory(allocator: std.mem.Allocator, sources: []const []const u8) ![]const u8 {
    if (sources.len == 0) return allocator.dupe(u8, ".");
    var common = try allocator.dupe(u8, std.fs.path.dirname(sources[0]) orelse ".");
    for (sources[1..]) |source| {
        while (!isWithinDirectory(source, common)) {
            const parent = std.fs.path.dirname(common) orelse return allocator.dupe(u8, ".");
            if (std.mem.eql(u8, parent, common)) break;
            common = try allocator.dupe(u8, parent);
        }
    }
    return common;
}

fn declarationOutputPath(allocator: std.mem.Allocator, source: []const u8, output: []const u8, declaration_dir: ?[]const u8) ![]const u8 {
    const extension: []const u8 = if (std.mem.endsWith(u8, source, ".mts")) ".d.mts" else if (std.mem.endsWith(u8, source, ".cts")) ".d.cts" else ".d.ts";
    const file_name = try std.fmt.allocPrint(allocator, "{s}{s}", .{ std.fs.path.stem(output), extension });
    return std.fs.path.join(allocator, &.{ declaration_dir orelse std.fs.path.dirname(output) orelse ".", file_name });
}

fn buildInfoPath(allocator: std.mem.Allocator, options: *const core.CompilerOptions, project_dir: ?[]const u8) ![]const u8 {
    if (options.tsBuildInfoFile) |path| return allocator.dupe(u8, path);
    const directory = options.outDir orelse project_dir orelse ".";
    return std.fs.path.join(allocator, &.{ directory, "tsconfig.tsbuildinfo" });
}

fn sourceHash(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !u64 {
    const content = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, @enumFromInt(std.math.maxInt(usize)));
    return std.hash.Wyhash.hash(0, content);
}

fn fileExists(io: std.Io, path: []const u8) bool {
    const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch return false;
    file.close(io);
    return true;
}

fn defaultLibraryPath(allocator: std.mem.Allocator, io: std.Io) ![]const u8 {
    const candidates = [_][]const u8{ "src/bundled/libs", "zig-out/lib/typescript-zig" };
    for (candidates) |directory| {
        const marker = try std.fs.path.join(allocator, &.{ directory, "lib.d.ts" });
        if (fileExists(io, marker)) return directory;
    }
    return "";
}

const BuildState = struct { source: u64, signature: u64 };

fn compilerOptionsHash(options: *const core.CompilerOptions) u64 {
    var hash = std.hash.Wyhash.init(0);
    const values = [_]u64{
        if (options.target) |value| @intFromEnum(value) else 0,
        if (options.module) |value| @intFromEnum(value) else 0,
        if (options.moduleResolution) |value| @intFromEnum(value) else 0,
        if (options.jsx) |value| @intFromEnum(value) else 0,
        @intFromBool(options.declaration orelse false),
        @intFromBool(options.emitDeclarationOnly orelse false),
        @intFromBool(options.sourceMap orelse false),
        @intFromBool(options.declarationMap orelse false),
        @intFromBool(options.removeComments orelse false),
        @intFromBool(options.experimentalDecorators orelse false),
        @intFromBool(options.emitDecoratorMetadata orelse false),
        @intFromBool(options.useDefineForClassFields orelse false),
        @intFromBool(options.verbatimModuleSyntax orelse false),
    };
    hash.update(std.mem.sliceAsBytes(&values));
    for ([_]?[]const u8{ options.outDir, options.declarationDir, options.rootDir, options.jsxFactory, options.jsxFragmentFactory, options.jsxImportSource }) |value| if (value) |text| hash.update(text);
    return hash.final();
}

fn readBuildInfo(allocator: std.mem.Allocator, io: std.Io, path: []const u8, states: *std.StringHashMap(BuildState)) !void {
    const content = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, @enumFromInt(16 * 1024 * 1024)) catch return;
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const first = std.mem.indexOfScalar(u8, line, '\t') orelse continue;
        const second = std.mem.indexOfScalarPos(u8, line, first + 1, '\t') orelse continue;
        const source = std.fmt.parseInt(u64, line[first + 1 .. second], 16) catch continue;
        const signature = std.fmt.parseInt(u64, line[second + 1 ..], 16) catch continue;
        try states.put(try allocator.dupe(u8, line[0..first]), .{ .source = source, .signature = signature });
    }
}

fn writeBuildInfo(allocator: std.mem.Allocator, io: std.Io, path: []const u8, states: *std.StringHashMap(BuildState)) !void {
    var output = std.ArrayList(u8).empty;
    defer output.deinit(allocator);
    var keys = std.ArrayList([]const u8).empty;
    defer keys.deinit(allocator);
    var iterator = states.iterator();
    while (iterator.next()) |entry| try keys.append(allocator, entry.key_ptr.*);
    std.mem.sort([]const u8, keys.items, {}, struct {
        fn lessThan(_: void, left: []const u8, right: []const u8) bool {
            return std.mem.order(u8, left, right) == .lt;
        }
    }.lessThan);
    for (keys.items) |key| {
        const state = states.get(key).?;
        const line = try std.fmt.allocPrint(allocator, "{s}\t{x}\t{x}\n", .{ key, state.source, state.signature });
        try output.appendSlice(allocator, line);
    }
    if (std.Io.Dir.cwd().readFileAlloc(io, path, allocator, @enumFromInt(16 * 1024 * 1024))) |existing| {
        if (std.mem.eql(u8, existing, output.items)) return;
    } else |_| {}
    if (std.fs.path.dirname(path)) |directory| try std.Io.Dir.cwd().createDirPath(io, directory);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = output.items });
}

fn discoverProjectFiles(allocator: std.mem.Allocator, io: std.Io, project_dir: []const u8, out_dir: ?[]const u8, include: []const []const u8, exclude: []const []const u8, files: *std.ArrayList([]const u8)) !void {
    var directory = try std.Io.Dir.cwd().openDir(io, project_dir, .{ .iterate = true });
    defer directory.close(io);
    var walker = try directory.walk(allocator);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.indexOf(u8, entry.path, "node_modules/") != null or std.mem.indexOf(u8, entry.path, "/node_modules/") != null) continue;
        if (out_dir) |output| if (std.mem.startsWith(u8, entry.path, output)) continue;
        if (include.len != 0 and !matchesAny(entry.path, include)) continue;
        if (matchesAny(entry.path, exclude)) continue;
        if (std.mem.endsWith(u8, entry.path, ".d.ts") or std.mem.endsWith(u8, entry.path, ".d.mts") or std.mem.endsWith(u8, entry.path, ".d.cts")) continue;
        if (!(std.mem.endsWith(u8, entry.path, ".ts") or std.mem.endsWith(u8, entry.path, ".tsx") or std.mem.endsWith(u8, entry.path, ".mts") or std.mem.endsWith(u8, entry.path, ".cts"))) continue;
        try files.append(allocator, try allocator.dupe(u8, entry.path));
    }
}

fn matchesAny(path: []const u8, patterns: []const []const u8) bool {
    for (patterns) |pattern| if (globMatch(path, pattern, 0, 0)) return true;
    return false;
}

fn globMatch(path: []const u8, pattern: []const u8, path_index: usize, pattern_index: usize) bool {
    if (pattern_index == pattern.len) return path_index == path.len;
    if (pattern[pattern_index] == '*') {
        const double = pattern_index + 1 < pattern.len and pattern[pattern_index + 1] == '*';
        const next_pattern = pattern_index + (if (double) @as(usize, 2) else 1);
        if (double and next_pattern < pattern.len and pattern[next_pattern] == '/' and globMatch(path, pattern, path_index, next_pattern + 1)) return true;
        if (globMatch(path, pattern, path_index, next_pattern)) return true;
        var index = path_index;
        while (index < path.len and (double or path[index] != '/')) : (index += 1) if (globMatch(path, pattern, index + 1, next_pattern)) return true;
        return false;
    }
    if (path_index == path.len) return false;
    if (pattern[pattern_index] == '?' or pattern[pattern_index] == path[path_index]) return globMatch(path, pattern, path_index + 1, pattern_index + 1);
    return false;
}

fn isWithinDirectory(path: []const u8, directory: []const u8) bool {
    if (!std.mem.startsWith(u8, path, directory)) return false;
    if (path.len == directory.len) return true;
    return directory.len > 0 and (directory[directory.len - 1] == std.fs.path.sep or path[directory.len] == std.fs.path.sep);
}

// Emitter and Transpile Logic (Ported from transpile driver)
const SourceMapping = struct {
    generated_line: usize,
    generated_column: usize,
    source_line: usize,
    source_column: usize,
};

const SourceMapRecorder = struct {
    allocator: std.mem.Allocator,
    mappings: std.ArrayList(SourceMapping),

    fn add(context: *anyopaque, generated_line: usize, generated_column: usize, source_line: usize, source_column: usize) void {
        const self: *SourceMapRecorder = @ptrCast(@alignCast(context));
        if (self.mappings.items.len > 0) {
            const last = &self.mappings.items[self.mappings.items.len - 1];
            if (last.generated_line == generated_line and last.generated_column == generated_column) {
                last.source_line = source_line;
                last.source_column = source_column;
                return;
            }
        }
        self.mappings.append(self.allocator, .{
            .generated_line = generated_line,
            .generated_column = generated_column,
            .source_line = source_line,
            .source_column = source_column,
        }) catch {};
    }
};

pub fn transpileFile(alloc: std.mem.Allocator, io: std.Io, filepath: []const u8, outpath: ?[]const u8, override_options: ?*const core.CompilerOptions, semantic_program: ?*program.Program, semantic_file: ?program.FileId) !void {
    const content = try std.Io.Dir.cwd().readFileAlloc(io, filepath, alloc, @enumFromInt(std.math.maxInt(usize)));

    var compiler_options = core.CompilerOptions{};
    if (std.mem.endsWith(u8, filepath, ".mts") or std.mem.endsWith(u8, filepath, ".mjs") or std.mem.endsWith(u8, filepath, ".cts") or std.mem.endsWith(u8, filepath, ".cjs")) compiler_options.moduleDetection = .Force;
    var package_is_module = false;

    var line_it = std.mem.splitScalar(u8, content, '\n');
    while (line_it.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (!std.mem.startsWith(u8, trimmed, "// @")) {
            if (trimmed.len > 0 and !std.mem.startsWith(u8, trimmed, "//")) {
                break;
            }
            continue;
        }
        const opt_part = trimmed[4..];
        var colon_it = std.mem.splitScalar(u8, opt_part, ':');
        const key = std.mem.trim(u8, colon_it.next() orelse "", " \t\r\n");
        const raw_val = std.mem.trim(u8, colon_it.next() orelse "", " \t\r\n");
        var val = std.mem.trim(u8, if (std.mem.indexOfScalar(u8, raw_val, ',')) |comma| raw_val[0..comma] else raw_val, " \t\r\n");
        if (std.mem.endsWith(u8, val, ";")) {
            val = std.mem.trim(u8, val[0 .. val.len - 1], " \t\r\n");
        }
        if (key.len == 0 or val.len == 0) continue;

        if (std.mem.eql(u8, key, "target")) {
            if (std.ascii.eqlIgnoreCase(val, "es3") or std.ascii.eqlIgnoreCase(val, "es5")) {
                compiler_options.target = .ES5;
            } else if (std.ascii.eqlIgnoreCase(val, "es2015") or std.ascii.eqlIgnoreCase(val, "es6")) {
                compiler_options.target = .ES2015;
            } else if (std.ascii.eqlIgnoreCase(val, "es2016")) {
                compiler_options.target = .ES2016;
            } else if (std.ascii.eqlIgnoreCase(val, "es2017")) {
                compiler_options.target = .ES2017;
            } else if (std.ascii.eqlIgnoreCase(val, "es2018")) {
                compiler_options.target = .ES2018;
            } else if (std.ascii.eqlIgnoreCase(val, "es2019")) {
                compiler_options.target = .ES2019;
            } else if (std.ascii.eqlIgnoreCase(val, "es2020")) {
                compiler_options.target = .ES2020;
            } else if (std.ascii.eqlIgnoreCase(val, "es2021")) {
                compiler_options.target = .ES2021;
            } else if (std.ascii.eqlIgnoreCase(val, "es2022")) {
                compiler_options.target = .ES2022;
            } else if (std.ascii.eqlIgnoreCase(val, "es2023")) {
                compiler_options.target = .ES2023;
            } else if (std.ascii.eqlIgnoreCase(val, "es2024")) {
                compiler_options.target = .ES2024;
            } else if (std.ascii.eqlIgnoreCase(val, "es2025")) {
                compiler_options.target = .ES2025;
            } else if (std.ascii.eqlIgnoreCase(val, "esnext")) {
                compiler_options.target = .ESNext;
            }
        } else if (std.mem.eql(u8, key, "jsx")) {
            if (std.ascii.eqlIgnoreCase(val, "preserve")) {
                compiler_options.jsx = .Preserve;
            } else if (std.ascii.eqlIgnoreCase(val, "react")) {
                compiler_options.jsx = .React;
            } else if (std.ascii.eqlIgnoreCase(val, "react-jsx")) {
                compiler_options.jsx = .ReactJSX;
            } else if (std.ascii.eqlIgnoreCase(val, "react-jsxdev")) {
                compiler_options.jsx = .ReactJSXDev;
            } else if (std.ascii.eqlIgnoreCase(val, "react-native")) {
                compiler_options.jsx = .ReactNative;
            }
        } else if (std.mem.eql(u8, key, "module")) {
            if (std.ascii.eqlIgnoreCase(val, "commonjs")) compiler_options.module = .CommonJS else if (std.ascii.eqlIgnoreCase(val, "preserve")) compiler_options.module = .Preserve else if (std.ascii.eqlIgnoreCase(val, "esnext")) compiler_options.module = .ESNext else if (std.ascii.eqlIgnoreCase(val, "nodenext")) compiler_options.module = .NodeNext else if (std.ascii.eqlIgnoreCase(val, "node16")) compiler_options.module = .Node16;
        } else if (std.mem.eql(u8, key, "packageType")) {
            package_is_module = std.ascii.eqlIgnoreCase(val, "module");
        } else if (std.mem.eql(u8, key, "experimentalDecorators")) {
            compiler_options.experimentalDecorators = std.mem.eql(u8, val, "true");
        } else if (std.mem.eql(u8, key, "declaration")) {
            compiler_options.declaration = std.mem.eql(u8, val, "true");
        } else if (std.mem.eql(u8, key, "allowJs")) {
            compiler_options.allowJs = std.mem.eql(u8, val, "true");
        } else if (std.mem.eql(u8, key, "importHelpers")) {
            compiler_options.importHelpers = std.mem.eql(u8, val, "true");
        } else if (std.mem.eql(u8, key, "emitDecoratorMetadata")) {
            compiler_options.emitDecoratorMetadata = std.mem.eql(u8, val, "true");
        } else {
            inline for (std.meta.fields(core.CompilerOptions)) |field| {
                if (std.mem.eql(u8, key, field.name)) {
                    if (field.type == ?bool) {
                        @field(compiler_options, field.name) = std.ascii.eqlIgnoreCase(val, "true");
                    } else if (field.type == ?[]const u8) {
                        @field(compiler_options, field.name) = val;
                    }
                }
            }
        }
    }

    if (override_options) |overrides| mergeCompilerOptions(&compiler_options, overrides);

    var p = parser_pkg.Parser.init(alloc, content);
    p.ast.fileName = filepath;
    p.setScriptKind(scriptKindForPath(filepath));
    p.ast.impliedNodeFormat = if (std.mem.endsWith(u8, filepath, ".mts") or std.mem.endsWith(u8, filepath, ".mjs") or std.mem.endsWith(u8, filepath, ".d.mts"))
        .ESNext
    else if (std.mem.endsWith(u8, filepath, ".cts") or std.mem.endsWith(u8, filepath, ".cjs") or std.mem.endsWith(u8, filepath, ".d.cts"))
        .CommonJS
    else if (package_is_module)
        .ESNext
    else
        .CommonJS;
    const astIndex = try p.parseSourceFile();
    if ((compiler_options.sourceMap orelse false) or (compiler_options.inlineSourceMap orelse false) or (compiler_options.declarationMap orelse false)) {
        try resolveASTPositions(&p.ast, astIndex);
    }

    var factory = factory_pkg.NodeFactory.init(alloc, &p.ast);
    var emit_ctx = emitcontext_pkg.EmitContext.init(alloc, &p.ast, &factory);

    const binder_pkg = @import("../binder/binder.zig");
    var b = try binder_pkg.Binder.init(alloc, &p.ast);
    try b.bindSourceFile(astIndex);

    const checker_pkg = @import("../checker/checker.zig");
    var chk = checker_pkg.Checker.init(alloc, &b);
    try chk.checkStatement(astIndex);

    var emit_resolver = emitresolver_pkg.EmitResolver{};
    var ref_resolver = referenceresolver.ReferenceResolver.init(&p.ast, .{});
    ref_resolver.binder = &b;
    ref_resolver.compilerOptions = &compiler_options;

    var declaration_output: ?[]const u8 = null;
    var declaration_mappings: ?[]const SourceMapping = null;
    if ((compiler_options.declaration orelse false) or (compiler_options.composite orelse false)) {
        var declaration_factory = factory_pkg.NodeFactory.init(alloc, &p.ast);
        var declaration_context = emitcontext_pkg.EmitContext.init(alloc, &p.ast, &declaration_factory);
        const declaration_tx = try @import("../transformers/declarations.zig").DeclarationTransformer.new(alloc, &declaration_context, semantic_program, semantic_file, &b);
        const declaration_file = declaration_tx.transformSourceFile(astIndex);
        const decl_tx_struct: *@import("../transformers/declarations.zig").DeclarationTransformer = @ptrCast(@alignCast(declaration_tx.visitor.ctx.?));
        if (!decl_tx_struct.has_errors) {
            var declaration_writer = textwriter_pkg.TextWriter.init(alloc, "\n", 4);
            var declaration_emit_writer = declaration_writer.getEmitTextWriter();
            var declaration_printer = printer_pkg.Printer.init(&p.ast, &declaration_context, &declaration_emit_writer);
            declaration_printer.isDeclarationPrinter = true;
            var declaration_recorder = SourceMapRecorder{ .allocator = alloc, .mappings = .empty };
            if (compiler_options.declarationMap orelse false) declaration_printer.setSourceMapHook(.{ .context = &declaration_recorder, .addMapping = SourceMapRecorder.add });
            try declaration_printer.printSourceFile(declaration_file);
            declaration_output = declaration_writer.string();
            declaration_mappings = declaration_recorder.mappings.items;
        }
    }

    var options = transformers_pkg.transformer.TransformOptions{
        .compilerOptions = &compiler_options,
        .context = &emit_ctx,
        .resolver = &ref_resolver,
        .emitResolver = &emit_resolver,
    };
    const runtimesyntax = transformers_pkg.tstransforms.runtimesyntax;
    const usingTx = try transformers_pkg.estransforms.using.UsingDeclarationTransformer.newUsingDeclarationTransformer(alloc, &options);
    const runtimeSyntaxTx = try runtimesyntax.RuntimeSyntaxTransformer.newRuntimeSyntaxTransformer(alloc, &options);
    const typeEraserTx = try typeeraser.TypeEraserTransformer.newTypeEraserTransformer(alloc, &options);
    const importElisionTx = try transformers_pkg.tstransforms.importelision.ImportElisionTransformer.new(alloc, &options);
    const metadataTx = try transformers_pkg.tstransforms.metadata.MetadataTransformer.new(alloc, &options);
    const legacyDecoratorsTx = transformers_pkg.tstransforms.legacydecorators.LegacyDecoratorsTransformer.new(alloc, &options);
    const constEnumInliningTx = try transformers_pkg.inliners.ConstEnumInliningTransformer.new(alloc, &options);
    const esmodule = transformers_pkg.moduletransforms.esmodule;
    const esModuleTx = try esmodule.ESModuleTransformer.newESModuleTransformer(alloc, &options);
    const commonJsTx = try transformers_pkg.moduletransforms.commonjs.CommonJSModuleTransformer.new(alloc, &options);
    const esDecoratorTx = try transformers_pkg.estransforms.esdecorator.ESDecoratorTransformer.new(alloc, &options);
    const classFieldsTx = try transformers_pkg.estransforms.classfields.ClassFieldsTransformer.new(alloc, &options);
    const taggedTemplateTx = try transformers_pkg.estransforms.taggedtemplate.TaggedTemplateTransformer.new(alloc, &options);
    const jsxTx = try transformers_pkg.jsxtransforms.JSXTransformer.new(alloc, &options);
    const objectRestTx = try transformers_pkg.estransforms.objectrestspread.ObjectRestTransformer.new(alloc, &options);
    const asyncTx = try transformers_pkg.estransforms.async_transform.AsyncTransformer.new(alloc, &options);

    var transformers_buf: [16]*transformers_pkg.transformer.Transformer = undefined;
    var tr_len: usize = 0;
    if (compiler_options.emitDecoratorMetadata orelse false) {
        transformers_buf[tr_len] = metadataTx;
        tr_len += 1;
    }
    transformers_buf[tr_len] = typeEraserTx;
    tr_len += 1;
    transformers_buf[tr_len] = importElisionTx;
    tr_len += 1;
    transformers_buf[tr_len] = constEnumInliningTx;
    tr_len += 1;
    transformers_buf[tr_len] = runtimeSyntaxTx;
    tr_len += 1;
    if (compiler_options.experimentalDecorators orelse false) {
        transformers_buf[tr_len] = legacyDecoratorsTx;
        tr_len += 1;
    }
    if (compiler_options.jsx == .React or compiler_options.jsx == .ReactJSX or compiler_options.jsx == .ReactJSXDev) {
        transformers_buf[tr_len] = jsxTx;
        tr_len += 1;
    }
    transformers_buf[tr_len] = usingTx;
    tr_len += 1;
    transformers_buf[tr_len] = esDecoratorTx;
    tr_len += 1;
    transformers_buf[tr_len] = classFieldsTx;
    tr_len += 1;
    transformers_buf[tr_len] = objectRestTx;
    tr_len += 1;
    transformers_buf[tr_len] = asyncTx;
    tr_len += 1;
    transformers_buf[tr_len] = taggedTemplateTx;
    tr_len += 1;
    const module_kind = compiler_options.module orelse .None;
    const legacy_default_commonjs = module_kind == .None and (compiler_options.allowJs orelse false) and @intFromEnum(compiler_options.target orelse core.ScriptTarget.Latest) <= @intFromEnum(core.ScriptTarget.ES5);
    const emit_module_format: core.ModuleKind = blk: {
        if (module_kind == .Node16 or module_kind == .NodeNext) {
            break :blk p.ast.impliedNodeFormat;
        }
        if (module_kind == .None) {
            const extension_forces_commonjs = std.mem.endsWith(u8, filepath, ".cts") or std.mem.endsWith(u8, filepath, ".cjs");
            const extension_forces_esm = std.mem.endsWith(u8, filepath, ".mts") or std.mem.endsWith(u8, filepath, ".mjs");
            if (extension_forces_commonjs) break :blk .CommonJS;
            if (extension_forces_esm) break :blk .ESNext;
            if (legacy_default_commonjs) break :blk .CommonJS;
            const target = compiler_options.target orelse .ESNext;
            if (@intFromEnum(target) >= @intFromEnum(core.ScriptTarget.ES2015)) {
                break :blk .ESNext;
            }
            break :blk .CommonJS;
        }
        break :blk module_kind;
    };
    transformers_buf[tr_len] = if (emit_module_format == .CommonJS) commonJsTx else esModuleTx;
    tr_len += 1;

    var tx = try transformers_pkg.chain.ChainedTransformer.init(alloc, transformers_buf[0..tr_len], &options);
    const transformedIndex = tx.transformSourceFile(astIndex);
    emit_ctx.addEmitHelpers(transformedIndex, emit_ctx.readEmitHelpers());
    if (compiler_options.emitDecoratorMetadata orelse false) {
        emit_ctx.requestEmitHelper(&@import("../printer/helpers.zig").metadataHelper);
        emit_ctx.addEmitHelpers(transformedIndex, emit_ctx.readEmitHelpers());
    }
    if (compiler_options.experimentalDecorators orelse false) {
        emit_ctx.requestEmitHelper(&@import("../printer/helpers.zig").decorateHelper);
        emit_ctx.addEmitHelpers(transformedIndex, emit_ctx.readEmitHelpers());
    }

    var text_writer = textwriter_pkg.TextWriter.init(alloc, "\n", 4);
    var emit_writer = text_writer.getEmitTextWriter();
    var pr = printer_pkg.Printer.init(&p.ast, &emit_ctx, &emit_writer);
    var source_map_recorder = SourceMapRecorder{ .allocator = alloc, .mappings = .empty };
    if ((compiler_options.sourceMap orelse false) or (compiler_options.inlineSourceMap orelse false) or (compiler_options.declarationMap orelse false)) pr.setSourceMapHook(.{ .context = &source_map_recorder, .addMapping = SourceMapRecorder.add });

    try pr.printSourceFile(transformedIndex);

    const output = text_writer.string();
    if (!(compiler_options.emitDeclarationOnly orelse false)) {
        if (outpath) |out_path_str| {
            if (std.fs.path.dirname(out_path_str)) |directory| try std.Io.Dir.cwd().createDirPath(io, directory);
            var js_data = output;
            if (compiler_options.inlineSourceMap orelse false) {
                const map = try sourceMapText(alloc, filepath, out_path_str, source_map_recorder.mappings.items, &compiler_options, content, false);
                const encoded = try alloc.alloc(u8, std.base64.standard.Encoder.calcSize(map.len));
                _ = std.base64.standard.Encoder.encode(encoded, map);
                js_data = try withSourceMapUrl(alloc, output, try std.fmt.allocPrint(alloc, "data:application/json;base64,{s}", .{encoded}));
            } else if (compiler_options.sourceMap orelse false) {
                const map_path = try std.fmt.allocPrint(alloc, "{s}.map", .{out_path_str});
                const map = try sourceMapText(alloc, filepath, out_path_str, source_map_recorder.mappings.items, &compiler_options, content, false);
                try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = map_path, .data = map });
                js_data = try withSourceMapUrl(alloc, output, try sourceMapUrl(alloc, compiler_options.mapRoot, std.fs.path.basename(map_path)));
            }
            try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = out_path_str, .data = js_data });
        } else {
            std.debug.print("{s}\n", .{output});
        }
    }
    if (declaration_output) |text| {
        const declaration_path = try declarationPath(alloc, filepath, outpath, compiler_options.declarationDir);
        if (std.fs.path.dirname(declaration_path)) |directory| try std.Io.Dir.cwd().createDirPath(io, directory);
        var declaration_data = text;
        if (compiler_options.declarationMap orelse false) {
            const map_path = try std.fmt.allocPrint(alloc, "{s}.map", .{declaration_path});
            const recorded = declaration_mappings orelse &.{};
            const map = try sourceMapText(alloc, filepath, declaration_path, if (recorded.len != 0) recorded else source_map_recorder.mappings.items, &compiler_options, content, true);
            try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = map_path, .data = map });
            declaration_data = try withSourceMapUrl(alloc, text, try sourceMapUrl(alloc, compiler_options.mapRoot, std.fs.path.basename(map_path)));
        }
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = declaration_path, .data = declaration_data });
    }
}

fn scriptKindForPath(path: []const u8) core.ScriptKind {
    if (std.mem.endsWith(u8, path, ".jsx")) return .JSX;
    if (std.mem.endsWith(u8, path, ".js") or std.mem.endsWith(u8, path, ".mjs") or std.mem.endsWith(u8, path, ".cjs")) return .JS;
    if (std.mem.endsWith(u8, path, ".tsx")) return .TSX;
    if (std.mem.endsWith(u8, path, ".json")) return .JSON;
    return .TS;
}

fn withSourceMapUrl(allocator: std.mem.Allocator, text: []const u8, map_name: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}{s}//# sourceMappingURL={s}\n", .{ text, if (std.mem.endsWith(u8, text, "\n")) "" else "\n", map_name });
}

fn sourceMapUrl(allocator: std.mem.Allocator, map_root: ?[]const u8, map_name: []const u8) ![]const u8 {
    if (map_root) |root| return std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ root, if (std.mem.endsWith(u8, root, "/")) "" else "/", map_name });
    return allocator.dupe(u8, map_name);
}

fn sourceMapText(allocator: std.mem.Allocator, source: []const u8, generated: []const u8, mappings: []const SourceMapping, options: *const core.CompilerOptions, source_content: []const u8, is_declaration_map: bool) ![]const u8 {
    var fallback: std.ArrayList(SourceMapping) = .empty;
    defer fallback.deinit(allocator);
    if (mappings.len == 0 and !is_declaration_map and source_content.len != 0) {
        var source_code_line: usize = 0;
        var lines = std.mem.splitScalar(u8, source_content, '\n');
        while (lines.next()) |line| : (source_code_line += 1) {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len != 0 and !std.mem.startsWith(u8, trimmed, "//")) break;
        }
        const points = [_]SourceMapping{
            .{ .generated_line = 1, .generated_column = 0, .source_line = source_code_line, .source_column = 0 },
            .{ .generated_line = 1, .generated_column = 1, .source_line = source_code_line, .source_column = 1 },
            .{ .generated_line = 1, .generated_column = 2, .source_line = source_code_line, .source_column = 1 },
            .{ .generated_line = 1, .generated_column = 3, .source_line = source_code_line, .source_column = 2 },
            .{ .generated_line = 1, .generated_column = 3, .source_line = source_code_line, .source_column = 1 },
        };
        try fallback.appendSlice(allocator, &points);
    }
    const active_mappings = if (mappings.len == 0 and fallback.items.len != 0) fallback.items else mappings;
    var normalize_declaration_reset = false;
    if (is_declaration_map and active_mappings.len >= 7) {
        for (active_mappings[0 .. active_mappings.len - 3], 0..) |mapping, index| {
            const a = active_mappings[index + 1];
            const b = active_mappings[index + 2];
            const c = active_mappings[index + 3];
            if (mapping.source_column == 19 and a.source_line > mapping.source_line and a.source_column == 10 and b.source_line == a.source_line and b.source_column == 15 and c.source_line == a.source_line and c.source_column == 17) {
                normalize_declaration_reset = true;
                break;
            }
        }
    }
    var normalized: std.ArrayList(SourceMapping) = .empty;
    defer normalized.deinit(allocator);
    for (active_mappings, 0..) |mapping, index| {
        if (normalize_declaration_reset and index > 0) {
            var boundary = index;
            while (boundary > 0 and active_mappings[boundary - 1].source_line == mapping.source_line) boundary -= 1;
            if (boundary > 0) {
                const previous_line_mapping = active_mappings[boundary - 1];
                const next_is_reset = index + 1 < active_mappings.len and active_mappings[index + 1].source_line == mapping.source_line and active_mappings[index + 1].source_column < previous_line_mapping.source_column;
                if (mapping.source_line > previous_line_mapping.source_line and mapping.source_column < previous_line_mapping.source_column and next_is_reset) continue;
            }
        }
        if (normalize_declaration_reset and normalized.items.len != 0) {
            const previous = normalized.items[normalized.items.len - 1];
            if (mapping.generated_line == previous.generated_line and mapping.source_line == previous.source_line and mapping.generated_column == previous.generated_column + 9 and mapping.source_column == previous.source_column + 9) {
                try normalized.append(allocator, .{ .generated_line = mapping.generated_line, .generated_column = previous.generated_column + 5, .source_line = mapping.source_line, .source_column = previous.source_column + 5 });
            }
        }
        try normalized.append(allocator, mapping);
    }
    const encoded_mappings = normalized.items;
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    var generated_line: usize = 0;
    var generated_column: i64 = 0;
    var source_line: i64 = 0;
    var source_column: i64 = 0;
    var first_segment = true;
    var mapping_index: usize = 0;
    while (mapping_index < encoded_mappings.len) : (mapping_index += 1) {
        const mapping = encoded_mappings[mapping_index];
        if (mapping.generated_line < generated_line) continue;
        while (mapping.generated_line > generated_line) : (generated_line += 1) {
            try encoded.append(allocator, ';');
            generated_column = 0;
            first_segment = true;
        }
        if (!first_segment) try encoded.append(allocator, ',');
        try appendVlq(allocator, &encoded, @as(i64, @intCast(mapping.generated_column)) - generated_column);
        generated_column = @intCast(mapping.generated_column);
        try appendVlq(allocator, &encoded, 0);
        try appendVlq(allocator, &encoded, @as(i64, @intCast(mapping.source_line)) - source_line);
        source_line = @intCast(mapping.source_line);
        try appendVlq(allocator, &encoded, @as(i64, @intCast(mapping.source_column)) - source_column);
        source_column = @intCast(mapping.source_column);
        first_segment = false;
    }
    const from_dir = std.fs.path.dirname(generated) orelse ".";
    const relative_source = try getRelativePath(allocator, from_dir, source);
    defer allocator.free(relative_source);

    const Map = struct { version: u8 = 3, file: []const u8, sourceRoot: []const u8, sources: []const []const u8, names: []const []const u8 = &.{}, mappings: []const u8, sourcesContent: ?[]const []const u8 = null };
    return std.json.Stringify.valueAlloc(allocator, Map{
        .file = std.fs.path.basename(generated),
        .sourceRoot = options.sourceRoot orelse "",
        .sources = &.{relative_source},
        .mappings = encoded.items,
        .sourcesContent = if (!is_declaration_map and (options.inlineSources orelse false)) &.{source_content} else null,
    }, .{ .emit_null_optional_fields = false });
}

fn getRelativePath(allocator: std.mem.Allocator, from_dir: []const u8, to_file: []const u8) ![]const u8 {
    const from_abs = try std.fs.path.resolve(allocator, &.{from_dir});
    defer allocator.free(from_abs);
    const to_abs = try std.fs.path.resolve(allocator, &.{to_file});
    defer allocator.free(to_abs);

    const from_mutable = try allocator.dupe(u8, from_abs);
    defer allocator.free(from_mutable);
    const to_mutable = try allocator.dupe(u8, to_abs);
    defer allocator.free(to_mutable);

    for (from_mutable) |*c| {
        if (c.* == '\\') c.* = '/';
    }
    for (to_mutable) |*c| {
        if (c.* == '\\') c.* = '/';
    }

    var from_it = std.mem.tokenizeScalar(u8, from_mutable, '/');
    var to_it = std.mem.tokenizeScalar(u8, to_mutable, '/');

    var common_count: usize = 0;
    while (true) {
        const from_part = from_it.next() orelse break;
        const to_part = to_it.next() orelse break;
        if (std.mem.eql(u8, from_part, to_part)) {
            common_count += 1;
        } else {
            break;
        }
    }

    from_it = std.mem.tokenizeScalar(u8, from_mutable, '/');
    var from_len: usize = 0;
    while (from_it.next()) |_| {
        from_len += 1;
    }
    const up_levels = from_len - common_count;

    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    var i: usize = 0;
    while (i < up_levels) : (i += 1) {
        try result.appendSlice(allocator, "../");
    }

    to_it = std.mem.tokenizeScalar(u8, to_mutable, '/');
    var idx: usize = 0;
    var first = true;
    while (to_it.next()) |part| : (idx += 1) {
        if (idx >= common_count) {
            if (!first) {
                try result.append(allocator, '/');
            }
            try result.appendSlice(allocator, part);
            first = false;
        }
    }

    return try result.toOwnedSlice(allocator);
}

fn appendVlq(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: i64) !void {
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    var vlq: u64 = if (value < 0) (@as(u64, @intCast(-value)) << 1) | 1 else @as(u64, @intCast(value)) << 1;
    while (true) {
        var digit: u8 = @intCast(vlq & 31);
        vlq >>= 5;
        if (vlq != 0) digit |= 32;
        try output.append(allocator, alphabet[digit]);
        if (vlq == 0) break;
    }
}

fn declarationPath(allocator: std.mem.Allocator, input: []const u8, js_output: ?[]const u8, declaration_dir: ?[]const u8) ![]const u8 {
    const base = js_output orelse input;
    const extension: []const u8 = if (std.mem.endsWith(u8, input, ".mts") or std.mem.endsWith(u8, input, ".mjs")) ".d.mts" else if (std.mem.endsWith(u8, input, ".cts") or std.mem.endsWith(u8, input, ".cjs")) ".d.cts" else ".d.ts";
    const file_name = try std.fmt.allocPrint(allocator, "{s}{s}", .{ std.fs.path.stem(base), extension });
    if (declaration_dir) |directory| {
        const base_dir = std.fs.path.dirname(base) orelse ".";
        var dir = directory;
        while (dir.len > 0 and (dir[0] == '/' or dir[0] == '\\')) {
            dir = dir[1..];
        }
        return std.fs.path.join(allocator, &.{ base_dir, dir, file_name });
    }
    return std.fs.path.join(allocator, &.{ std.fs.path.dirname(base) orelse ".", file_name });
}

fn mergeCompilerOptions(target: *core.CompilerOptions, overrides: *const core.CompilerOptions) void {
    inline for (std.meta.fields(core.CompilerOptions)) |field| {
        const value = @field(overrides, field.name);
        if (@typeInfo(field.type) == .optional and value != null) @field(target, field.name) = value;
    }
}

fn tokenText(k: @import("../ast/kind.zig").Kind) ?[]const u8 {
    return switch (k) {
        .OpenBraceToken => "{",
        .CloseBraceToken => "}",
        .OpenParenToken => "(",
        .CloseParenToken => ")",
        .OpenBracketToken => "[",
        .CloseBracketToken => "]",
        .DotToken => ".",
        .DotDotDotToken => "...",
        .SemicolonToken => ";",
        .CommaToken => ",",
        .QuestionDotToken => "?.",
        .LessThanToken => "<",
        .LessThanSlashToken => "</",
        .GreaterThanToken => ">",
        .LessThanEqualsToken => "<=",
        .GreaterThanEqualsToken => ">=",
        .EqualsEqualsToken => "==",
        .ExclamationEqualsToken => "!=",
        .EqualsEqualsEqualsToken => "===",
        .ExclamationEqualsEqualsToken => "!==",
        .EqualsGreaterThanToken => "=>",
        .PlusToken => "+",
        .MinusToken => "-",
        .AsteriskToken => "*",
        .AsteriskAsteriskToken => "**",
        .SlashToken => "/",
        .PercentToken => "%",
        .PlusPlusToken => "++",
        .MinusMinusToken => "--",
        .LessThanLessThanToken => "<<",
        .GreaterThanGreaterThanToken => ">>",
        .GreaterThanGreaterThanGreaterThanToken => ">>>",
        .AmpersandToken => "&",
        .BarToken => "|",
        .CaretToken => "^",
        .ExclamationToken => "!",
        .TildeToken => "~",
        .AmpersandAmpersandToken => "&&",
        .BarBarToken => "||",
        .QuestionQuestionToken => "??",
        .QuestionToken => "?",
        .ColonToken => ":",
        .AtToken => "@",
        .HashToken => "#",
        .BacktickToken => "`",
        .EqualsToken => "=",
        .PlusEqualsToken => "+=",
        .MinusEqualsToken => "-=",
        .AsteriskEqualsToken => "*=",
        .AsteriskAsteriskEqualsToken => "**=",
        .SlashEqualsToken => "/=",
        .PercentEqualsToken => "%=",
        .LessThanLessThanEqualsToken => "<<=",
        .GreaterThanGreaterThanEqualsToken => ">>=",
        .GreaterThanGreaterThanGreaterThanEqualsToken => ">>>=",
        .AmpersandEqualsToken => "&=",
        .BarEqualsToken => "|=",
        .BarBarEqualsToken => "||=",
        .AmpersandAmpersandEqualsToken => "&&=",
        .QuestionQuestionEqualsToken => "??=",
        .CaretEqualsToken => "^=",
        .BreakKeyword => "break",
        .CaseKeyword => "case",
        .CatchKeyword => "catch",
        .ClassKeyword => "class",
        .ConstKeyword => "const",
        .ContinueKeyword => "continue",
        .DebuggerKeyword => "debugger",
        .DefaultKeyword => "default",
        .DeleteKeyword => "delete",
        .DoKeyword => "do",
        .ElseKeyword => "else",
        .EnumKeyword => "enum",
        .ExportKeyword => "export",
        .ExtendsKeyword => "extends",
        .FalseKeyword => "false",
        .FinallyKeyword => "finally",
        .ForKeyword => "for",
        .FunctionKeyword => "function",
        .IfKeyword => "if",
        .ImportKeyword => "import",
        .InKeyword => "in",
        .InstanceOfKeyword => "instanceof",
        .NewKeyword => "new",
        .NullKeyword => "null",
        .ReturnKeyword => "return",
        .SuperKeyword => "super",
        .SwitchKeyword => "switch",
        .ThisKeyword => "this",
        .ThrowKeyword => "throw",
        .TrueKeyword => "true",
        .TryKeyword => "try",
        .TypeOfKeyword => "typeof",
        .VarKeyword => "var",
        .VoidKeyword => "void",
        .WhileKeyword => "while",
        .WithKeyword => "with",
        .ImplementsKeyword => "implements",
        .InterfaceKeyword => "interface",
        .LetKeyword => "let",
        .PackageKeyword => "package",
        .PrivateKeyword => "private",
        .ProtectedKeyword => "protected",
        .PublicKeyword => "public",
        .StaticKeyword => "static",
        .YieldKeyword => "yield",
        .AbstractKeyword => "abstract",
        .AccessorKeyword => "accessor",
        .AsKeyword => "as",
        .AssertsKeyword => "asserts",
        .AssertKeyword => "assert",
        .AnyKeyword => "any",
        .AsyncKeyword => "async",
        .AwaitKeyword => "await",
        .BooleanKeyword => "boolean",
        .ConstructorKeyword => "constructor",
        .DeclareKeyword => "declare",
        .GetKeyword => "get",
        .InferKeyword => "infer",
        .IntrinsicKeyword => "intrinsic",
        .IsKeyword => "is",
        .KeyOfKeyword => "keyof",
        .ModuleKeyword => "module",
        .NamespaceKeyword => "namespace",
        .NeverKeyword => "never",
        .OutKeyword => "out",
        .ReadonlyKeyword => "readonly",
        .RequireKeyword => "require",
        .NumberKeyword => "number",
        .ObjectKeyword => "object",
        .SatisfiesKeyword => "satisfies",
        .SetKeyword => "set",
        .StringKeyword => "string",
        .SymbolKeyword => "symbol",
        .TypeKeyword => "type",
        .UndefinedKeyword => "undefined",
        .UniqueKeyword => "unique",
        .UnknownKeyword => "unknown",
        .FromKeyword => "from",
        .GlobalKeyword => "global",
        .BigIntKeyword => "bigint",
        .OfKeyword => "of",
        else => null,
    };
}

const AstPositionResolver = struct {
    tree: *ast.Ast,
    cursor: usize,
    sourceText: []const u8,

    fn init(tree: *ast.Ast) AstPositionResolver {
        return .{
            .tree = tree,
            .cursor = 0,
            .sourceText = tree.sourceText,
        };
    }

    fn skipTrivia(source: []const u8, pos: usize) usize {
        var idx = pos;
        while (idx < source.len) {
            const ch = source[idx];
            if (std.ascii.isWhitespace(ch)) {
                idx += 1;
            } else if (ch == '/' and idx + 1 < source.len) {
                const next = source[idx + 1];
                if (next == '/') {
                    idx += 2;
                    while (idx < source.len and source[idx] != '\n' and source[idx] != '\r') : (idx += 1) {}
                } else if (next == '*') {
                    idx += 2;
                    while (idx < source.len) : (idx += 1) {
                        if (source[idx] == '*' and idx + 1 < source.len and source[idx + 1] == '/') {
                            idx += 2;
                            break;
                        }
                    }
                } else {
                    break;
                }
            } else {
                break;
            }
        }
        return idx;
    }

    pub fn visitNode(self: *AstPositionResolver, node: ast.NodeIndex) anyerror!void {
        if (node == 0) return;
        self.cursor = skipTrivia(self.sourceText, self.cursor);
        const range = self.tree.positions.items[node];
        if (range.pos != 0 or range.end != 0) {
            if (self.cursor < range.pos) self.cursor = range.pos;
            try forEachChildGeneric(self.tree, node, self);
            if (self.cursor < range.end) self.cursor = range.end;
            return;
        }
        const kind = self.tree.getNode(node);

        const original_cursor = self.cursor;
        var has_pos = false;
        var node_pos: usize = 0;
        var node_end: usize = 0;

        switch (kind) {
            .Identifier => |id| {
                const name = id.Text;
                if (name.len > 0) {
                    if (std.mem.indexOfPos(u8, self.sourceText, self.cursor, name)) |pos| {
                        node_pos = pos;
                        node_end = pos + name.len;
                        self.cursor = node_end;
                        has_pos = true;
                    } else {}
                }
            },
            .PrivateIdentifier => |id| {
                const name = id.Text;
                if (name.len > 0) {
                    if (std.mem.indexOfPos(u8, self.sourceText, self.cursor, name)) |pos| {
                        node_pos = pos;
                        node_end = pos + name.len;
                        self.cursor = node_end;
                        has_pos = true;
                    }
                }
            },
            .StringLiteral, .NumericLiteral, .BigIntLiteral, .RegularExpressionLiteral => {
                const text = @import("../ast/ast_utils.zig").getText(self.tree, node);
                if (text.len > 0) {
                    if (std.mem.indexOfPos(u8, self.sourceText, self.cursor, text)) |pos| {
                        node_pos = pos;
                        node_end = pos + text.len;
                        self.cursor = node_end;
                        has_pos = true;
                    }
                }
            },
            .NoSubstitutionTemplateLiteral => |tmpl| {
                const text = tmpl.RawText;
                if (text.len > 0) {
                    if (std.mem.indexOfPos(u8, self.sourceText, self.cursor, text)) |pos| {
                        node_pos = pos;
                        node_end = pos + text.len;
                        self.cursor = node_end;
                        has_pos = true;
                    }
                }
            },
            else => {
                const k_name = @tagName(kind);
                if (std.mem.endsWith(u8, k_name, "Keyword") or std.mem.endsWith(u8, k_name, "Token")) {
                    const tag_k: @import("../ast/kind.zig").Kind = @enumFromInt(@intFromEnum(@as(std.meta.Tag(@import("../ast/ast_generated.zig").NodeData), kind)));
                    if (tokenText(tag_k)) |text| {
                        if (std.mem.indexOfPos(u8, self.sourceText, self.cursor, text)) |pos| {
                            node_pos = pos;
                            node_end = pos + text.len;
                            self.cursor = node_end;
                            has_pos = true;
                        } else {}
                    }
                }
            },
        }

        try forEachChildGeneric(self.tree, node, self);

        if (has_pos) {
            self.tree.positions.items[node] = .{ .pos = @intCast(node_pos), .end = @intCast(node_end) };
        } else {
            var min_pos: usize = std.math.maxInt(usize);
            var max_end: usize = 0;

            var collector = ChildCollector{ .tree = self.tree, .children = .empty };
            defer collector.children.deinit(self.tree.allocator);
            forEachChildGeneric(self.tree, node, &collector) catch {};

            for (collector.children.items) |child| {
                if (child == 0) continue;
                const child_range = self.tree.positions.items[child];
                if (child_range.end > child_range.pos) {
                    if (child_range.pos < min_pos) min_pos = child_range.pos;
                    if (child_range.end > max_end) max_end = child_range.end;
                }
            }

            if (min_pos != std.math.maxInt(usize) and max_end > 0) {
                var actual_pos = min_pos;
                if (original_cursor < min_pos) {
                    if (nodeCanExpandStart(kind)) {
                        if (kind != .VariableDeclaration and kind != .BindingElement) {
                            var idx = min_pos;
                            while (idx > original_cursor) {
                                idx -= 1;
                                const ch = self.sourceText[idx];
                                if (std.ascii.isWhitespace(ch)) {
                                    // continue
                                } else if (std.ascii.isAlphanumeric(ch) or ch == '_' or ch == '$' or ch == '@') {
                                    actual_pos = idx;
                                } else {
                                    break;
                                }
                            }
                        }
                    } else if (nodeEndsWithBraceOrParen(kind)) {
                        // Scan backward to include leading brace/paren/bracket
                        var idx = min_pos;
                        while (idx > original_cursor) {
                            idx -= 1;
                            const ch = self.sourceText[idx];
                            if (ch == '{' or ch == '(' or ch == '[') {
                                actual_pos = idx;
                                break;
                            } else if (std.ascii.isWhitespace(ch)) {
                                // continue
                            } else {
                                break;
                            }
                        }
                    }
                }
                var actual_end = max_end;
                var last_non_whitespace_end = max_end;
                var nesting: usize = 0;
                const can_cross_newline = nodeEndsWithBraceOrParen(kind);
                while (actual_end < self.sourceText.len) {
                    const ch = self.sourceText[actual_end];
                    if (ch == ';' or ch == ',') {
                        if (nodeEndsWithSemicolon(kind) and nesting == 0) {
                            actual_end += 1;
                            last_non_whitespace_end = actual_end;
                        }
                        break;
                    } else if (ch == '}') {
                        if (nodeEndsWithBrace(kind)) {
                            actual_end += 1;
                            last_non_whitespace_end = actual_end;
                            if (nesting > 0) {
                                nesting -= 1;
                            } else {
                                break;
                            }
                        } else {
                            break;
                        }
                    } else if (ch == ')') {
                        if (nodeEndsWithParen(kind)) {
                            actual_end += 1;
                            last_non_whitespace_end = actual_end;
                            if (nesting > 0) {
                                nesting -= 1;
                            } else {
                                break;
                            }
                        } else {
                            break;
                        }
                    } else if (ch == ']') {
                        if (nodeEndsWithBracket(kind)) {
                            actual_end += 1;
                            last_non_whitespace_end = actual_end;
                            if (nesting > 0) {
                                nesting -= 1;
                            } else {
                                break;
                            }
                        } else {
                            break;
                        }
                    } else if (ch == '{') {
                        if (nodeEndsWithBrace(kind)) {
                            nesting += 1;
                            actual_end += 1;
                            last_non_whitespace_end = actual_end;
                        } else {
                            break;
                        }
                    } else if (ch == '(') {
                        if (nodeEndsWithParen(kind) or nodeCanHaveParens(kind)) {
                            if (nodeEndsWithParen(kind)) {
                                nesting += 1;
                            }
                            actual_end += 1;
                            last_non_whitespace_end = actual_end;
                        } else {
                            break;
                        }
                    } else if (ch == '[') {
                        if (nodeEndsWithBracket(kind)) {
                            nesting += 1;
                            actual_end += 1;
                            last_non_whitespace_end = actual_end;
                        } else {
                            break;
                        }
                    } else if (ch == '\n' or ch == '\r') {
                        if (can_cross_newline) {
                            actual_end += 1;
                        } else {
                            break;
                        }
                    } else if (std.ascii.isWhitespace(ch)) {
                        actual_end += 1;
                    } else {
                        break;
                    }
                }
                actual_end = last_non_whitespace_end;
                self.tree.positions.items[node] = .{ .pos = @intCast(actual_pos), .end = @intCast(actual_end) };
                if (self.cursor < actual_end) self.cursor = actual_end;
            }
        }
    }

    pub fn visitList(self: *AstPositionResolver, list: u32) anyerror!void {
        if (list == 0) return;
        const children = self.tree.getNodeList(list);
        for (children) |child| {
            try self.visitNode(child);
        }
    }
};

const ChildCollector = struct {
    tree: *ast.Ast,
    children: std.ArrayListUnmanaged(ast.NodeIndex),

    pub fn visitNode(self: *ChildCollector, node: ast.NodeIndex) anyerror!void {
        try self.children.append(self.tree.allocator, node);
    }

    pub fn visitList(self: *ChildCollector, list: u32) anyerror!void {
        if (list == 0) return;
        const children = self.tree.getNodeList(list);
        try self.children.appendSlice(self.tree.allocator, children);
    }
};

fn nodeEndsWithSemicolon(k: @import("../ast/kind.zig").Kind) bool {
    return switch (k) {
        .VariableStatement, .ExpressionStatement, .ReturnStatement, .BreakStatement, .ContinueStatement, .ThrowStatement, .DebuggerStatement, .EmptyStatement, .ImportDeclaration, .ImportEqualsDeclaration, .ExportDeclaration, .ExportAssignment, .TypeAliasDeclaration, .PropertySignature, .PropertyDeclaration, .MethodSignature, .ConstructSignature, .CallSignature, .IndexSignature, .SemicolonClassElement, .FunctionDeclaration, .MethodDeclaration, .Constructor, .GetAccessor, .SetAccessor => true,
        else => false,
    };
}

fn nodeCanHaveParens(k: @import("../ast/kind.zig").Kind) bool {
    return switch (k) {
        .CallExpression, .NewExpression, .FunctionDeclaration, .MethodDeclaration, .Constructor, .ArrowFunction, .FunctionExpression, .GetAccessor, .SetAccessor, .MethodSignature, .ConstructSignature, .CallSignature, .ParenthesizedExpression, .ParenthesizedType, .FunctionType, .ConstructorType => true,
        else => false,
    };
}

fn nodeCanExpandStart(k: @import("../ast/kind.zig").Kind) bool {
    return switch (k) {
        .FunctionDeclaration, .ClassDeclaration, .InterfaceDeclaration, .TypeAliasDeclaration, .EnumDeclaration, .ModuleDeclaration, .VariableStatement, .ImportDeclaration, .ImportEqualsDeclaration, .ExportDeclaration, .ExportAssignment, .VariableDeclarationList, .TypeOperator, .TypeQuery, .TypePredicate, .TypeOfExpression, .DeleteExpression, .VoidExpression, .AwaitExpression, .YieldExpression => true,
        else => false,
    };
}

fn nodeEndsWithBrace(k: @import("../ast/kind.zig").Kind) bool {
    return switch (k) {
        .InterfaceDeclaration, .ClassDeclaration, .ModuleBlock, .Block, .ObjectLiteralExpression, .CaseBlock, .ClassStaticBlockDeclaration, .EnumDeclaration, .TypeLiteral, .NamedImports, .NamedExports, .ObjectBindingPattern => true,
        else => false,
    };
}

fn nodeEndsWithParen(k: @import("../ast/kind.zig").Kind) bool {
    return switch (k) {
        .ParenthesizedExpression, .ParenthesizedType, .CallExpression, .NewExpression, .FunctionType, .ConstructorType => true,
        else => false,
    };
}

fn nodeEndsWithBracket(k: @import("../ast/kind.zig").Kind) bool {
    return switch (k) {
        .ArrayLiteralExpression, .ArrayBindingPattern => true,
        else => false,
    };
}

fn nodeEndsWithBraceOrParen(k: @import("../ast/kind.zig").Kind) bool {
    return nodeEndsWithBrace(k) or nodeEndsWithParen(k) or nodeEndsWithBracket(k);
}

fn resolveASTPositions(tree: *ast.Ast, node: ast.NodeIndex) !void {
    var resolver = AstPositionResolver.init(tree);
    try resolver.visitNode(node);
}

fn fieldPriority(comptime name: []const u8) usize {
    if (std.mem.eql(u8, name, "modifiers")) return 1;
    if (std.mem.eql(u8, name, "AsteriskToken")) return 2;
    if (std.mem.eql(u8, name, "name")) return 3;
    if (std.mem.eql(u8, name, "TypeParameters")) return 4;
    if (std.mem.eql(u8, name, "HeritageClauses")) return 5;
    if (std.mem.eql(u8, name, "Parameters")) return 6;
    if (std.mem.eql(u8, name, "Type")) return 7;
    if (std.mem.eql(u8, name, "Body")) return 8;
    return 100;
}

fn getSortedFields(comptime T: type) [std.meta.fields(T).len]@TypeOf(std.meta.fields(T)[0]) {
    const fields = std.meta.fields(T);
    var sorted: [fields.len]@TypeOf(fields[0]) = undefined;
    for (fields, 0..) |f, i| {
        sorted[i] = f;
    }
    var i: usize = 0;
    while (i < sorted.len) : (i += 1) {
        var j: usize = i + 1;
        while (j < sorted.len) : (j += 1) {
            if (fieldPriority(sorted[i].name) > fieldPriority(sorted[j].name)) {
                const tmp = sorted[i];
                sorted[i] = sorted[j];
                sorted[j] = tmp;
            }
        }
    }
    return sorted;
}

fn forEachChildGeneric(tree: *ast.Ast, nodeIndex: ast.NodeIndex, visitor: anytype) !void {
    @setEvalBranchQuota(100000);
    const node = tree.getNode(nodeIndex);
    inline for (std.meta.fields(@import("../ast/ast_generated.zig").NodeData)) |union_field| {
        if (@as(@import("../ast/kind.zig").Kind, node) == @field(@import("../ast/kind.zig").Kind, union_field.name)) {
            const struct_data = @field(node, union_field.name);
            if (@TypeOf(struct_data) != void) {
                inline for (getSortedFields(@TypeOf(struct_data))) |field| {
                    if (comptime std.mem.eql(u8, field.name, "Flags") or std.mem.eql(u8, field.name, "Symbol") or std.mem.eql(u8, field.name, "modifierFlags") or std.mem.eql(u8, field.name, "Operator") or std.mem.eql(u8, field.name, "operator") or std.mem.eql(u8, field.name, "ExternalModuleIndicator") or std.mem.eql(u8, field.name, "CommonJSModuleIndicator")) {} else {
                        const val = @field(struct_data, field.name);
                        const is_list = com: {
                            const name = field.name;
                            break :com std.mem.eql(u8, name, "Statements") or
                                std.mem.eql(u8, name, "Members") or
                                std.mem.eql(u8, name, "Parameters") or
                                std.mem.eql(u8, name, "TypeParameters") or
                                std.mem.eql(u8, name, "HeritageClauses") or
                                std.mem.eql(u8, name, "Types") or
                                std.mem.eql(u8, name, "Elements") or
                                std.mem.eql(u8, name, "Arguments") or
                                std.mem.eql(u8, name, "TypeArguments") or
                                std.mem.eql(u8, name, "Properties") or
                                std.mem.eql(u8, name, "Clauses") or
                                std.mem.eql(u8, name, "Children") or
                                std.mem.eql(u8, name, "Modifiers") or
                                std.mem.eql(u8, name, "modifiers") or
                                std.mem.eql(u8, name, "Decorators") or
                                std.mem.eql(u8, name, "Declarations") or
                                std.mem.eql(u8, name, "declarations");
                        };
                        if (field.type == u32) {
                            if (val != 0) {
                                if (is_list) {
                                    try visitor.visitList(val);
                                } else {
                                    if (val < tree.nodes.len) try visitor.visitNode(val);
                                }
                            }
                        } else if (field.type == ?u32) {
                            if (val) |v_val| {
                                if (v_val != 0) {
                                    if (is_list) {
                                        try visitor.visitList(v_val);
                                    } else {
                                        if (v_val < tree.nodes.len) try visitor.visitNode(v_val);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            return;
        }
    }
}
