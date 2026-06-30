const std = @import("std");
const commandline = @import("tsc").commandlineparser;
const tsconfig = @import("tsc").simple_tsconfig;
const transpile_driver = @import("transpile_driver");

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();

    var iterator = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer iterator.deinit();
    const executable = iterator.next() orelse "tsc";

    var raw_args = std.ArrayList([]const u8).empty;
    while (iterator.next()) |arg| try raw_args.append(allocator, arg);

    if (raw_args.items.len == 0) {
        std.debug.print("Version 0.1.0\nUsage: tsc [options] <files...>\n", .{});
        return;
    }

    var normalized_args = raw_args;
    if (isBuildFlag(raw_args.items[0])) {
        normalized_args = .empty;
        try normalized_args.append(allocator, "--project");
        try normalized_args.append(allocator, if (raw_args.items.len > 1) raw_args.items[1] else ".");
    }

    var parsed = try commandline.parseCommandLine(allocator, normalized_args.items);
    defer parsed.deinit(allocator);
    if (parsed.errors.items.len != 0) {
        for (parsed.errors.items) |message| std.debug.print("error TS5023: {s}\n", .{message});
        std.process.exit(1);
    }
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    if (parsed.options.init orelse false) {
        const path = "tsconfig.json";
        if (fileExists(threaded.io(), path)) {
            std.debug.print("error TS5054: A 'tsconfig.json' file is already defined at: '{s}'.\n", .{path});
            std.process.exit(1);
        }
        try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = path, .data = "{\n  \"compilerOptions\": {\n    \"target\": \"es2016\",\n    \"module\": \"commonjs\",\n    \"strict\": true,\n    \"esModuleInterop\": true,\n    \"skipLibCheck\": true,\n    \"forceConsistentCasingInFileNames\": true\n  }\n}\n" });
        std.debug.print("Created a new tsconfig.json.\n", .{});
        return;
    }

    var project_config: ?tsconfig.ParsedTsConfig = null;
    defer if (project_config) |*config| config.deinit(allocator);
    var project_dir: ?[]const u8 = null;
    if (parsed.options.project) |project_arg| {
        const config_path = if (std.mem.endsWith(u8, project_arg, ".json")) project_arg else try std.fs.path.join(allocator, &.{ project_arg, "tsconfig.json" });
        const lexical_project_dir = std.fs.path.dirname(config_path) orelse ".";
        project_dir = canonicalExistingPath(allocator, threaded.io(), lexical_project_dir) catch lexical_project_dir;
        project_config = try tsconfig.parseTsConfigFile(allocator, threaded.io(), config_path);
        if (project_config.?.errors.items.len != 0) {
            for (project_config.?.errors.items) |message| std.debug.print("error TS5083: {s}\n", .{message});
            std.process.exit(1);
        }
        mergeOptions(&project_config.?.options, &parsed.options);
        try resolveProjectPaths(allocator, threaded.io(), &project_config.?.options, project_dir.?);
        if (isBuildFlag(raw_args.items[0])) {
            var visiting = std.StringHashMap(void).init(allocator);
            var built = std.StringHashMap(void).init(allocator);
            const root_config = try std.fs.path.resolve(allocator, &.{config_path});
            try visiting.put(root_config, {});
            for (project_config.?.projectReferences.items) |reference| {
                const reference_path = try std.fs.path.join(allocator, &.{ project_dir.?, reference });
                try buildReferencedProject(allocator, threaded.io(), executable, reference_path, &visiting, &built);
            }
            _ = visiting.remove(root_config);
        }
    }

    const effective_options = if (project_config) |*config| &config.options else &parsed.options;
    if (!validateOptions(effective_options)) std.process.exit(1);
    if (effective_options.help orelse false) {
        std.debug.print("Version 0.1.0\nUsage: tsc [options] <files...>\n  -p, --project <path>\n  -b, --build <path>\n  -w, --watch\n  --noEmit\n  --declaration\n  --sourceMap\n", .{});
        return;
    }
    if (effective_options.version orelse false) {
        std.debug.print("Version 0.1.0\n", .{});
        return;
    }
    if (effective_options.showConfig orelse false) {
        printEffectiveConfig(effective_options, if (project_config) |*config| config.fileNames.items else parsed.fileNames.items);
        return;
    }

    var discovered_files = std.ArrayList([]const u8).empty;
    if (project_config != null and project_config.?.fileNames.items.len == 0 and !project_config.?.hasExplicitFiles) {
        try discoverProjectFiles(allocator, threaded.io(), project_dir.?, project_config.?.options.outDir, project_config.?.includeSpecs.items, project_config.?.excludeSpecs.items, &discovered_files);
    }
    const input_files = if (project_config) |*config| if (config.fileNames.items.len != 0) config.fileNames.items else discovered_files.items else parsed.fileNames.items;
    if (input_files.len == 0) {
        if (isBuildFlag(raw_args.items[0]) and project_config != null and project_config.?.projectReferences.items.len != 0) return;
        std.debug.print("error TS18003: No inputs were found.\n", .{});
        std.process.exit(1);
    }

    const active_options = effective_options;
    var resolved_sources = std.ArrayList([]const u8).empty;
    for (input_files) |input| {
        try resolved_sources.append(allocator, if (std.fs.path.isAbsolute(input)) input else if (project_dir) |directory| try std.fs.path.join(allocator, &.{ directory, input }) else input);
    }
    var graph = @import("tsc").program.Program.init(allocator, .{
        .options = active_options.*,
        .rootNames = resolved_sources.items,
        .projectName = project_dir orelse ".",
        .pathMappings = if (project_config) |*config| config.pathMappings.items else &.{},
        .defaultLibraryPath = try defaultLibraryPath(allocator, threaded.io()),
    });
    defer graph.deinit();
    try graph.load(threaded.io());
    try graph.bind();
    try graph.link();
    try graph.check();
    if ((active_options.listFiles orelse false) or (active_options.listFilesOnly orelse false)) {
        for (graph.units.items) |unit| std.debug.print("{s}\n", .{unit.path});
    }
    if (graph.diagnostics.items.len != 0) {
        for (graph.diagnostics.items) |diagnostic| std.debug.print("{s}: error TS{d}: {s}\n", .{ graph.getUnit(diagnostic.file).path, diagnostic.code, diagnostic.message });
        if (active_options.noEmitOnError orelse false) std.process.exit(1);
    }

    const incremental = (active_options.incremental orelse false) or (active_options.composite orelse false) or isBuildFlag(raw_args.items[0]);
    const emit_root = active_options.rootDir orelse try commonSourceDirectory(allocator, resolved_sources.items);
    const build_info_path = if (incremental) try buildInfoPath(allocator, active_options, project_dir) else null;
    var old_states = std.StringHashMap(BuildState).init(allocator);
    if (build_info_path) |path| try readBuildInfo(allocator, threaded.io(), path, &old_states);
    var new_states = std.StringHashMap(BuildState).init(allocator);
    const current_options_hash = compilerOptionsHash(active_options);
    const previous_options = old_states.get("<compiler-options>");
    const options_changed = previous_options == null or previous_options.?.source != current_options_hash;
    try new_states.put("<compiler-options>", .{ .source = current_options_hash, .signature = current_options_hash });
    const changed_public = try allocator.alloc(bool, graph.units.items.len);
    const source_changed = try allocator.alloc(bool, graph.units.items.len);
    for (graph.units.items, 0..) |unit, index| {
        const source_hash = try sourceHash(allocator, threaded.io(), unit.path);
        const signature_hash = graph.signatureHash(@intCast(index));
        const previous = old_states.get(unit.path);
        source_changed[index] = options_changed or previous == null or previous.?.source != source_hash;
        changed_public[index] = options_changed or previous == null or previous.?.signature != signature_hash;
        try new_states.put(unit.path, .{ .source = source_hash, .signature = signature_hash });
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
            const output = try outputPath(allocator, source, active_options.outDir, emit_root);
            if (incremental and !source_changed[unit_index] and !changed_public[unit_index] and fileExists(threaded.io(), output)) continue;
            try transpile_driver.transpileFile(init, source, output, active_options, &graph, @intCast(unit_index));
            if (active_options.listEmittedFiles orelse false) {
                std.debug.print("TSFILE: {s}\n", .{output});
                if ((active_options.declaration orelse false) or (active_options.composite orelse false)) {
                    const declaration = try declarationOutputPath(allocator, source, output, active_options.declarationDir);
                    std.debug.print("TSFILE: {s}\n", .{declaration});
                }
            }
        }
    }
    if (build_info_path) |path| try writeBuildInfo(allocator, threaded.io(), path, &new_states);
    if (active_options.watch orelse false) try watchLoop(allocator, threaded.io(), executable, parsed.options.project, project_dir, active_options.outDir, graph.units.items);
}

fn isWithinDirectory(path: []const u8, directory: []const u8) bool {
    if (!std.mem.startsWith(u8, path, directory)) return false;
    if (path.len == directory.len) return true;
    return directory.len > 0 and (directory[directory.len - 1] == std.fs.path.sep or path[directory.len] == std.fs.path.sep);
}

fn watchLoop(allocator: std.mem.Allocator, io: std.Io, executable: []const u8, project: ?[]const u8, project_dir: ?[]const u8, out_dir: ?[]const u8, units: []*@import("tsc").program.SourceUnit) !void {
    var snapshot = try watchSnapshot(allocator, io, project_dir, out_dir, units);
    std.debug.print("Watching for file changes.\n", .{});
    while (true) {
        try std.Io.sleep(io, std.Io.Duration.fromMilliseconds(250), .awake);
        var current = try watchSnapshot(allocator, io, project_dir, out_dir, units);
        if (current == snapshot) continue;

        // Wait until editors have completed atomic rename/write sequences.
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

fn watchSnapshot(allocator: std.mem.Allocator, io: std.Io, project_dir: ?[]const u8, out_dir: ?[]const u8, units: []*@import("tsc").program.SourceUnit) !u64 {
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

fn validateOptions(options: *@import("tsc").core.CompilerOptions) bool {
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

fn printEffectiveConfig(options: *const @import("tsc").core.CompilerOptions, files: []const []const u8) void {
    std.debug.print("{{\n  \"compilerOptions\": {{\n", .{});
    if (options.target) |value| std.debug.print("    \"target\": \"{s}\",\n", .{@tagName(value)});
    if (options.module) |value| std.debug.print("    \"module\": \"{s}\",\n", .{@tagName(value)});
    if (options.outDir) |value| std.debug.print("    \"outDir\": \"{s}\",\n", .{value});
    std.debug.print("    \"declaration\": {s}\n  }},\n  \"files\": [", .{if (options.declaration orelse false) "true" else "false"});
    for (files, 0..) |file, index| std.debug.print("{s}\"{s}\"", .{ if (index == 0) "" else ", ", file });
    std.debug.print("]\n}}\n", .{});
}

fn mergeOptions(target: *@import("tsc").core.CompilerOptions, overrides: *const @import("tsc").core.CompilerOptions) void {
    inline for (std.meta.fields(@import("tsc").core.CompilerOptions)) |field| {
        const value = @field(overrides, field.name);
        if (@typeInfo(field.type) == .optional and value != null) @field(target, field.name) = value;
    }
}

fn resolveProjectPaths(allocator: std.mem.Allocator, io: std.Io, options: *@import("tsc").core.CompilerOptions, project_dir: []const u8) !void {
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

fn isBuildFlag(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "-b") or std.mem.eql(u8, arg, "--build") or std.mem.eql(u8, arg, "--b") or std.mem.eql(u8, arg, "-build");
}

fn buildInfoPath(allocator: std.mem.Allocator, options: *const @import("tsc").core.CompilerOptions, project_dir: ?[]const u8) ![]const u8 {
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

fn compilerOptionsHash(options: *const @import("tsc").core.CompilerOptions) u64 {
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
    var keys = std.ArrayList([]const u8).empty;
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
