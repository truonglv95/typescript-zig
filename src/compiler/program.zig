const std = @import("std");
const emithost = @import("../printer/emithost.zig");
const emitter_mod = @import("emitter.zig");
const outputpaths = @import("../outputpaths/outputpaths.zig");
const printer = @import("../printer/printer.zig");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const parser = @import("../parser/parser.zig");
const binder = @import("../binder/binder.zig");
const checker = @import("../checker/checker.zig");
const core = @import("../core/core.zig");
const tspath = @import("../tspath/tspath.zig");
const scanner = @import("../scanner/scanner.zig");
const semver = @import("../semver/version.zig");
const semver_range = @import("../semver/version_range.zig");
const text_writer = @import("../printer/textwriter.zig");
const emitcontext = @import("../printer/emitcontext.zig");
const transformers = @import("../transformers/transformer.zig");
const declarations = @import("../transformers/declarations.zig");
const harness = @import("harness.zig");

pub const FileId = u32;

pub const PathMapping = struct {
    pattern: []const u8,
    targets: []const []const u8,
};

pub const ProgramOptions = struct {
    options: core.CompilerOptions,
    rootNames: [][]const u8,
    useSourceOfProjectReference: bool = false,
    singleThreaded: ?bool = null,
    typingsLocation: []const u8 = "",
    projectName: []const u8 = "",
    pathMappings: []const PathMapping = &.{},
    defaultLibraryPath: []const u8 = "",
};

pub const Dependency = struct {
    specifier: []const u8,
    resolved: ?FileId,
};

pub const PackageIdentity = struct {
    name: []u8,
    version: []u8,
    sub_module_name: []u8,

    fn deinit(self: PackageIdentity, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.version);
        allocator.free(self.sub_module_name);
    }
};

pub const SymbolMeaning = packed struct {
    value: bool = false,
    type: bool = false,
};

pub const ExportedSymbol = struct {
    file: FileId,
    declaration_file: FileId,
    declaration: ast.NodeIndex,
    meaning: SymbolMeaning,
};

pub const AliasSymbol = struct {
    target_file: FileId,
    imported_name: []const u8,
    declaration_node: ast.NodeIndex = 0,
};

pub const ProgramDiagnostic = struct {
    file: FileId,
    code: u32,
    message: []const u8,
    category: diagnostics.Category = .Error,
    line: u32 = 1,
    column: u32 = 1,
};

const LineColumn = struct { line: u32, column: u32 };

fn computeLineColumn(source_text: []const u8, pos: u32) LineColumn {
    var line: u32 = 1;
    var column: u32 = 1;
    var index: u32 = 0;
    const limit = @min(pos, @as(u32, @intCast(source_text.len)));
    while (index < limit) : (index += 1) {
        if (source_text[index] == '\n') {
            line += 1;
            column = 1;
        } else {
            column += 1;
        }
    }
    return .{ .line = line, .column = column };
}

fn diagnosticLocation(tree: *ast.Ast, node_index: ast.NodeIndex, explicit_pos: u32) LineColumn {
    const pos = if (node_index != 0)
        scanner.getTokenPosOfNode(tree, node_index, false)
    else
        explicit_pos;
    return computeLineColumn(tree.sourceText, pos);
}

const CachedResolution = struct {
    path: ?[]u8,
};

pub const SemanticType = enum(u8) {
    unknown,
    any,
    void,
    boolean,
    number,
    bigint,
    string,
    function,
    object,
};

pub const SourceUnit = struct {
    path: []const u8,
    content: []u8,
    content_hash: u64,
    parser_instance: *parser.Parser,
    source_file: ast.NodeIndex,
    binder_instance: ?*binder.Binder = null,
    dependencies: std.ArrayList(Dependency) = .empty,
    is_root: bool = false,
    is_default_library: bool = false,
    package_id: ?PackageIdentity = null,
    uses_require_conditions: bool = true,

    pub fn tree(self: *SourceUnit) *ast.Ast {
        return &self.parser_instance.ast;
    }
};

/// Owns a complete source graph. Every file keeps its own parser/AST arena;
/// NodeIndex values never cross file boundaries without an accompanying FileId.
pub const Program = struct {
    allocator: std.mem.Allocator,
    opts: ProgramOptions,
    units: std.ArrayList(*SourceUnit) = .empty,
    files_by_path: std.StringHashMap(FileId),
    loading: std.StringHashMap(void),
    exports_by_key: std.StringHashMap(ExportedSymbol),
    aliases_by_key: std.StringHashMap(AliasSymbol),
    resolution_cache: std.StringHashMap(CachedResolution),
    diagnostics: std.ArrayList(ProgramDiagnostic) = .empty,
    public_types: std.StringHashMap(SemanticType),
    emit_resolver: emithost.EmitResolver = .{},
    source_files_cache: std.ArrayList(ast.NodeIndex) = .empty,
    common_source_directory: []u8 = &.{},
    current_emit_file: ?FileId = null,
    declaration_diagnostic_start: usize = 0,

    pub fn init(allocator: std.mem.Allocator, opts: ProgramOptions) Program {
        return .{
            .allocator = allocator,
            .opts = opts,
            .files_by_path = std.StringHashMap(FileId).init(allocator),
            .loading = std.StringHashMap(void).init(allocator),
            .exports_by_key = std.StringHashMap(ExportedSymbol).init(allocator),
            .aliases_by_key = std.StringHashMap(AliasSymbol).init(allocator),
            .resolution_cache = std.StringHashMap(CachedResolution).init(allocator),
            .public_types = std.StringHashMap(SemanticType).init(allocator),
        };
    }

    pub fn deinit(self: *Program) void {
        for (self.units.items) |unit| {
            if (unit.binder_instance) |instance| {
                instance.deinit();
                self.allocator.destroy(instance);
            }
            for (unit.dependencies.items) |dependency| self.allocator.free(dependency.specifier);
            if (unit.package_id) |package_id| package_id.deinit(self.allocator);
            unit.dependencies.deinit(self.allocator);
            unit.parser_instance.deinit();
            self.allocator.destroy(unit.parser_instance);
            self.allocator.free(unit.content);
            self.allocator.free(unit.path);
            self.allocator.destroy(unit);
        }
        self.units.deinit(self.allocator);
        self.files_by_path.deinit();
        self.loading.deinit();
        freeMapKeys(self.allocator, &self.exports_by_key);
        var aliases = self.aliases_by_key.valueIterator();
        while (aliases.next()) |alias| self.allocator.free(alias.imported_name);
        freeMapKeys(self.allocator, &self.aliases_by_key);
        self.exports_by_key.deinit();
        self.aliases_by_key.deinit();
        var cached_resolutions = self.resolution_cache.valueIterator();
        while (cached_resolutions.next()) |resolution| if (resolution.path) |path| self.allocator.free(path);
        freeMapKeys(self.allocator, &self.resolution_cache);
        self.resolution_cache.deinit();
        for (self.diagnostics.items) |diagnostic| self.allocator.free(diagnostic.message);
        self.diagnostics.deinit(self.allocator);
        freeMapKeys(self.allocator, &self.public_types);
        self.public_types.deinit();
        self.source_files_cache.deinit(self.allocator);
        if (self.common_source_directory.len != 0) self.allocator.free(self.common_source_directory);
    }

    // --- EmitHost Implementation ---

    fn eh_options(ptr: *anyopaque) *emithost.CompilerOptions {
        const self: *Program = @ptrCast(@alignCast(ptr));
        return @ptrCast(&self.opts.options);
    }

    fn eh_sourceFiles(ptr: *anyopaque) []const ast_gen.NodeIndex {
        const self: *Program = @ptrCast(@alignCast(ptr));
        if (self.source_files_cache.items.len != self.units.items.len) {
            self.source_files_cache.clearRetainingCapacity();
            for (self.units.items) |unit| {
                self.source_files_cache.append(self.allocator, unit.source_file) catch unreachable;
            }
        }
        return self.source_files_cache.items;
    }

    fn eh_useCaseSensitiveFileNames(ptr: *anyopaque) bool {
        _ = ptr;
        // Mac/Linux default to true, Windows to false.
        // But TS uses current OS semantics.
        return true;
    }

    fn eh_getCurrentDirectory(ptr: *anyopaque) []const u8 {
        const self: *Program = @ptrCast(@alignCast(ptr));
        return self.opts.projectName;
    }

    fn eh_commonSourceDirectory(ptr: *anyopaque) []const u8 {
        const self: *Program = @ptrCast(@alignCast(ptr));
        return self.common_source_directory;
    }

    fn eh_isEmitBlocked(ptr: *anyopaque, file: []const u8) bool {
        _ = ptr;
        _ = file;
        return false;
    }

    fn eh_writeFile(ptr: *anyopaque, fileName: []const u8, text: []const u8) anyerror!void {
        const self: *Program = @ptrCast(@alignCast(ptr));
        const dir_path = std.fs.path.dirname(fileName) orelse ".";

        var threaded = std.Io.Threaded.init(self.allocator, .{});
        defer threaded.deinit();
        const io = threaded.io();

        try std.Io.Dir.cwd().createDirPath(io, dir_path);
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = fileName, .data = text });
    }

    fn eh_getEmitModuleFormatOfFile(ptr: *anyopaque, file: ast_gen.NodeIndex) emithost.ModuleKind {
        const self: *Program = @ptrCast(@alignCast(ptr));
        _ = file;
        const configured = self.opts.options.module orelse .CommonJS;
        if (configured != .Node16 and configured != .NodeNext) return @intFromEnum(configured);
        const id = self.current_emit_file orelse return @intFromEnum(core.ModuleKind.CommonJS);
        return @intFromEnum(if (self.units.items[id].uses_require_conditions) core.ModuleKind.CommonJS else core.ModuleKind.ESNext);
    }

    fn eh_getEmitResolver(ptr: *anyopaque) *emithost.EmitResolver {
        const self: *Program = @ptrCast(@alignCast(ptr));
        return &self.emit_resolver;
    }

    fn eh_getProjectReferenceFromSource(ptr: *anyopaque, path: emithost.Path) ?*emithost.SourceOutputAndProjectReference {
        _ = ptr;
        _ = path;
        return null;
    }

    fn eh_isSourceFileFromExternalLibrary(ptr: *anyopaque, file: ast_gen.NodeIndex) bool {
        _ = ptr;
        _ = file;
        return false;
    }

    const emit_host_vtable = emithost.EmitHost.VTable{
        .options = eh_options,
        .sourceFiles = eh_sourceFiles,
        .useCaseSensitiveFileNames = eh_useCaseSensitiveFileNames,
        .getCurrentDirectory = eh_getCurrentDirectory,
        .commonSourceDirectory = eh_commonSourceDirectory,
        .isEmitBlocked = eh_isEmitBlocked,
        .writeFile = eh_writeFile,
        .getEmitModuleFormatOfFile = eh_getEmitModuleFormatOfFile,
        .getEmitResolver = eh_getEmitResolver,
        .getProjectReferenceFromSource = eh_getProjectReferenceFromSource,
        .isSourceFileFromExternalLibrary = eh_isSourceFileFromExternalLibrary,
    };

    pub fn getEmitHost(self: *Program) emithost.EmitHost {
        return .{
            .ptr = self,
            .vtable = &emit_host_vtable,
        };
    }

    fn createDeclarationTransformer(allocator: std.mem.Allocator, context: *emitcontext.EmitContext, context_ptr: *anyopaque) !*transformers.Transformer {
        const self: *Program = @ptrCast(@alignCast(context_ptr));
        self.declaration_diagnostic_start = self.diagnostics.items.len;
        const file = self.current_emit_file orelse return declarations.DeclarationTransformer.new(allocator, context, null, null, null);
        const bound = self.units.items[file].binder_instance orelse return declarations.DeclarationTransformer.new(allocator, context, self, file, null);
        return declarations.DeclarationTransformer.new(allocator, context, self, file, bound);
    }

    fn declarationEmitBlocked(context_ptr: *anyopaque) bool {
        const self: *Program = @ptrCast(@alignCast(context_ptr));
        return self.diagnostics.items.len > self.declaration_diagnostic_start;
    }

    pub fn hasErrorDiagnostics(self: *const Program) bool {
        for (self.diagnostics.items) |diagnostic| {
            if (diagnostic.category == .Error) return true;
        }
        return false;
    }

    // Program emit coordination logic
    // Analogous to EmitFilesAndReportErrors in Go
    pub fn emit(self: *Program, emit_only: emitter_mod.EmitOnly) !*emitter_mod.EmitResult {
        // Create an arena for this emit run
        var emit_arena = std.heap.ArenaAllocator.init(self.allocator);
        const emit_alloc = emit_arena.allocator();

        var result = try emit_alloc.create(emitter_mod.EmitResult);
        result.* = .{
            .EmitSkipped = false,
            .Diagnostics = &[_]diagnostics.Diagnostic{},
            .EmittedFiles = &[_][]const u8{},
            .SourceMaps = &[_]*emitter_mod.SourceMapEmitResult{},
        };

        var all_diagnostics = std.ArrayList(diagnostics.Diagnostic).empty;
        var all_emitted_files = std.ArrayList([]const u8).empty;
        var all_source_maps = std.ArrayList(*emitter_mod.SourceMapEmitResult).empty;
        var emit_skipped = false;

        const host = self.getEmitHost();
        const options = self.opts.options;

        const OutputPathsHostVTable = outputpaths.OutputPathsHost.VTable{
            .commonSourceDirectory = eh_commonSourceDirectory,
            .getCurrentDirectory = eh_getCurrentDirectory,
            .useCaseSensitiveFileNames = eh_useCaseSensitiveFileNames,
        };

        // Create an outputpaths host based on emit host.
        var op_host = outputpaths.OutputPathsHost{
            .astState = undefined, // Needs to be filled or unused?
            .ptr = self,
            .vtable = &OutputPathsHostVTable,
        };

        for (self.units.items, 0..) |unit, unit_index| {
            if (unit.is_default_library) continue;
            if (std.mem.endsWith(u8, unit.path, ".d.ts")) continue;
            // Depending on emit_only, we might skip some files
            // if (unit.ast == null) continue;

            op_host.astState = unit.tree();
            self.current_emit_file = @intCast(unit_index);
            const paths = try outputpaths.getOutputPathsFor(emit_alloc, unit.source_file, &options, op_host, emit_only == .EmitOnlyForcedDts);

            var writer = text_writer.TextWriter.init(emit_alloc, "\n", 0);
            var emit_writer = writer.getEmitTextWriter();

            var e = emitter_mod.Emitter{
                .allocator = emit_alloc,
                .host = host,
                .emitOnly = emit_only,
                .emitterDiagnostics = std.ArrayList(diagnostics.Diagnostic).empty,
                .writer = &emit_writer,
                .paths = paths,
                .sourceFile = unit.source_file,
                .tree = unit.tree(),
                .emitResult = emitter_mod.EmitResult{
                    .EmitSkipped = true,
                    .Diagnostics = &[_]diagnostics.Diagnostic{},
                    .EmittedFiles = &[_][]const u8{},
                    .SourceMaps = &[_]*emitter_mod.SourceMapEmitResult{},
                },
                .writeFile = null, // TODO
                .tr = null,
                .declarationTransformerContext = self,
                .declarationTransformerFactory = createDeclarationTransformer,
                .declarationEmitBlocked = declarationEmitBlocked,
            };

            try e.emit();

            if (e.emitResult.EmitSkipped) emit_skipped = true;
            try all_diagnostics.appendSlice(emit_alloc, e.emitResult.Diagnostics);
            try all_emitted_files.appendSlice(emit_alloc, e.emitResult.EmittedFiles);
            try all_source_maps.appendSlice(emit_alloc, e.emitResult.SourceMaps);
        }

        result.EmitSkipped = emit_skipped;
        result.Diagnostics = try all_diagnostics.toOwnedSlice(emit_alloc);
        result.EmittedFiles = try all_emitted_files.toOwnedSlice(emit_alloc);
        result.SourceMaps = try all_source_maps.toOwnedSlice(emit_alloc);
        self.current_emit_file = null;

        return result;
    }

    pub fn load(self: *Program, io: std.Io) !void {
        for (self.opts.rootNames) |root| _ = try self.loadFile(io, root, true);
        try self.loadDefaultLibraries(io);
        try self.loadConfiguredTypes(io);
        try self.computeCommonSourceDirectory();
    }

    fn computeCommonSourceDirectory(self: *Program) !void {
        if (self.common_source_directory.len != 0) {
            self.allocator.free(self.common_source_directory);
            self.common_source_directory = &.{};
        }
        if (self.opts.options.rootDir) |root_dir| {
            if (root_dir.len != 0) {
                self.common_source_directory = try self.allocator.dupe(u8, root_dir);
                return;
            }
        }

        var common: ?[]const u8 = null;
        for (self.units.items) |unit| {
            if (!unit.is_root or unit.is_default_library) continue;
            const directory = std.fs.path.dirname(unit.path) orelse unit.path;
            if (common == null) {
                common = directory;
                continue;
            }
            while (!isPathInside(directory, common.?)) {
                common = std.fs.path.dirname(common.?) orelse common.?;
                if (common.?.len == 1 and common.?[0] == std.fs.path.sep) break;
            }
        }
        self.common_source_directory = try self.allocator.dupe(u8, common orelse self.opts.projectName);
    }

    fn loadDefaultLibraries(self: *Program, io: std.Io) !void {
        if ((self.opts.options.noLib orelse false) or self.opts.defaultLibraryPath.len == 0) return;
        if (self.opts.options.lib) |libraries| {
            for (libraries) |library| try self.loadLibraryByName(io, library);
            return;
        }
        try self.loadLibraryByName(io, defaultLibraryName(self.opts.options.target orelse .ES5));
    }

    fn loadLibraryByName(self: *Program, io: std.Io, requested_name: []const u8) anyerror!void {
        const file_name = if (std.mem.startsWith(u8, requested_name, "lib.") and std.mem.endsWith(u8, requested_name, ".d.ts"))
            try self.allocator.dupe(u8, requested_name)
        else if (std.mem.startsWith(u8, requested_name, "lib."))
            try std.fmt.allocPrint(self.allocator, "{s}.d.ts", .{requested_name})
        else
            try std.fmt.allocPrint(self.allocator, "lib.{s}.d.ts", .{requested_name});
        defer self.allocator.free(file_name);
        const path = try std.fs.path.join(self.allocator, &.{ self.opts.defaultLibraryPath, file_name });
        defer self.allocator.free(path);
        if (!fileExists(io, path)) return;
        const previous_count = self.units.items.len;
        const id = try self.loadFile(io, path, false);
        self.units.items[id].is_default_library = true;
        if (self.units.items.len == previous_count) return;
        try self.loadReferencedLibraries(io, self.units.items[id].content);
    }

    fn loadReferencedLibraries(self: *Program, io: std.Io, content: []const u8) anyerror!void {
        const prefix = "/// <reference lib=\"";
        var offset: usize = 0;
        while (std.mem.indexOfPos(u8, content, offset, prefix)) |start| {
            const name_start = start + prefix.len;
            const name_end = std.mem.indexOfScalarPos(u8, content, name_start, '\"') orelse break;
            try self.loadLibraryByName(io, content[name_start..name_end]);
            offset = name_end + 1;
        }
    }

    fn loadConfiguredTypes(self: *Program, io: std.Io) !void {
        const requested_types = self.opts.options.types orelse return;
        for (requested_types) |type_name| {
            if (std.mem.eql(u8, type_name, "*")) {
                try self.loadWildcardTypePackages(io);
                continue;
            }
            if (try self.resolveTypeReference(io, type_name)) |path| {
                _ = try self.loadFile(io, path, false);
                self.allocator.free(path);
            }
        }
    }

    fn loadWildcardTypePackages(self: *Program, io: std.Io) !void {
        var roots = std.ArrayList([]const u8).empty;
        defer {
            for (roots.items) |root| self.allocator.free(root);
            roots.deinit(self.allocator);
        }
        if (self.opts.options.typeRoots) |configured_roots| {
            for (configured_roots) |root| try roots.append(self.allocator, try self.allocator.dupe(u8, root));
        } else {
            var directory = if (self.opts.projectName.len != 0) self.opts.projectName else ".";
            while (true) {
                try roots.append(self.allocator, try std.fs.path.join(self.allocator, &.{ directory, "node_modules", "@types" }));
                const parent = std.fs.path.dirname(directory) orelse break;
                if (std.mem.eql(u8, parent, directory)) break;
                directory = parent;
            }
        }

        var package_roots = std.ArrayList([]const u8).empty;
        defer {
            for (package_roots.items) |root| self.allocator.free(root);
            package_roots.deinit(self.allocator);
        }
        for (roots.items) |root| {
            var directory = std.Io.Dir.cwd().openDir(io, root, .{ .iterate = true }) catch continue;
            defer directory.close(io);
            var iterator = directory.iterate();
            while (try iterator.next(io)) |entry| {
                if (entry.kind != .directory or entry.name.len == 0 or entry.name[0] == '.') continue;
                const package_root = try std.fs.path.join(self.allocator, &.{ root, entry.name });
                if (try isNotNeededTypePackage(self.allocator, io, package_root)) {
                    self.allocator.free(package_root);
                    continue;
                }
                try package_roots.append(self.allocator, package_root);
            }
        }
        std.mem.sort([]const u8, package_roots.items, {}, struct {
            fn lessThan(_: void, left: []const u8, right: []const u8) bool {
                return std.mem.lessThan(u8, left, right);
            }
        }.lessThan);
        for (package_roots.items) |package_root| if (try self.resolveTypePackage(io, package_root)) |path| {
            _ = try self.loadFile(io, path, false);
            self.allocator.free(path);
        };
    }

    fn resolveTypeReference(self: *Program, io: std.Io, type_name: []const u8) !?[]const u8 {
        if (self.opts.options.typeRoots) |roots| {
            for (roots) |root| {
                const package_root = try std.fs.path.join(self.allocator, &.{ root, type_name });
                defer self.allocator.free(package_root);
                if (try self.resolveTypePackage(io, package_root)) |resolved| return resolved;
            }
        } else {
            const encoded_name = if (type_name.len > 0 and type_name[0] == '@') blk: {
                const slash = std.mem.indexOfScalar(u8, type_name, '/') orelse break :blk try self.allocator.dupe(u8, type_name[1..]);
                break :blk try std.fmt.allocPrint(self.allocator, "{s}__{s}", .{ type_name[1..slash], type_name[slash + 1 ..] });
            } else try self.allocator.dupe(u8, type_name);
            defer self.allocator.free(encoded_name);
            var directory = self.opts.projectName;
            if (directory.len == 0) directory = ".";
            while (true) {
                const package_root = try std.fs.path.join(self.allocator, &.{ directory, "node_modules", "@types", encoded_name });
                defer self.allocator.free(package_root);
                if (try self.resolveTypePackage(io, package_root)) |resolved| return resolved;
                const parent = std.fs.path.dirname(directory) orelse break;
                if (std.mem.eql(u8, parent, directory)) break;
                directory = parent;
            }
        }
        return null;
    }

    fn resolveTypePackage(self: *Program, io: std.Io, package_root: []const u8) !?[]const u8 {
        const package_json = try std.fs.path.join(self.allocator, &.{ package_root, "package.json" });
        defer self.allocator.free(package_json);
        if (fileExists(io, package_json)) {
            const content = try std.Io.Dir.cwd().readFileAlloc(io, package_json, self.allocator, @enumFromInt(4 * 1024 * 1024));
            defer self.allocator.free(content);
            if (std.json.parseFromSlice(std.json.Value, self.allocator, content, .{})) |parsed_value| {
                var parsed = parsed_value;
                defer parsed.deinit();
                if (parsed.value == .object) for ([_][]const u8{ "types", "typings" }) |field| if (parsed.value.object.get(field)) |entry| {
                    if (entry != .string) continue;
                    const requested = try std.fs.path.join(self.allocator, &.{ package_root, entry.string });
                    defer self.allocator.free(requested);
                    if (try self.resolvePathCandidate(io, requested)) |resolved| return resolved;
                };
            } else |_| {}
        }
        const index = try std.fs.path.join(self.allocator, &.{ package_root, "index.d.ts" });
        if (fileExists(io, index)) return index;
        self.allocator.free(index);
        return null;
    }

    pub fn loadFile(self: *Program, io: std.Io, file_name: []const u8, is_root: bool) anyerror!FileId {
        const lexical = try normalizePath(self.allocator, file_name);
        defer self.allocator.free(lexical);
        const normalized: []u8 = if (self.opts.options.preserveSymlinks orelse false) try self.allocator.dupe(u8, lexical) else try canonicalPath(self.allocator, io, lexical);
        if (self.files_by_path.get(normalized)) |id| {
            self.allocator.free(normalized);
            if (is_root) self.units.items[id].is_root = true;
            return id;
        }
        if (self.loading.contains(normalized)) {
            self.allocator.free(normalized);
            return error.CyclicLoadWithoutFile;
        }
        try self.loading.put(normalized, {});
        defer _ = self.loading.remove(normalized);

        const content = try std.Io.Dir.cwd().readFileAlloc(io, normalized, self.allocator, @enumFromInt(std.math.maxInt(usize)));
        // NOTE: Harness directive comments (e.g. `// @noEmit`) are only honored when a
        // multi-file harness is materialized via `tryPrepareHarnessCompilation`. Applying
        // them for every root file here would diverge from the real `tsc`/`tsgo` CLI, which
        // treats such comments as ordinary trivia.
        const parser_instance = try self.allocator.create(parser.Parser);
        parser_instance.* = parser.Parser.init(self.allocator, content);
        parser_instance.ast.fileName = normalized;
        parser_instance.setScriptKind(scriptKindForPath(normalized));
        const source_file = try parser_instance.parseSourceFile();

        const unit = try self.allocator.create(SourceUnit);
        unit.* = .{
            .path = normalized,
            .content = content,
            .content_hash = std.hash.Wyhash.hash(0, content),
            .parser_instance = parser_instance,
            .source_file = source_file,
            .is_root = is_root,
            .package_id = try self.packageIdentityForFile(io, normalized),
            .uses_require_conditions = try self.usesRequireConditionsForFile(io, normalized),
        };
        const id: FileId = @intCast(self.units.items.len);
        try self.units.append(self.allocator, unit);
        try self.files_by_path.put(unit.path, id);

        try self.collectDependencies(io, id);
        return id;
    }

    fn packageIdentityForFile(self: *Program, io: std.Io, file_name: []const u8) !?PackageIdentity {
        if (std.mem.indexOf(u8, file_name, "node_modules") == null) return null;
        var directory = std.fs.path.dirname(file_name) orelse return null;
        while (true) {
            const package_json = try std.fs.path.join(self.allocator, &.{ directory, "package.json" });
            defer self.allocator.free(package_json);
            if (fileExists(io, package_json)) {
                const content = try std.Io.Dir.cwd().readFileAlloc(io, package_json, self.allocator, @enumFromInt(4 * 1024 * 1024));
                defer self.allocator.free(content);
                if (std.json.parseFromSlice(std.json.Value, self.allocator, content, .{})) |parsed_value| {
                    var parsed = parsed_value;
                    defer parsed.deinit();
                    if (parsed.value == .object) {
                        const name = parsed.value.object.get("name") orelse return null;
                        const version = parsed.value.object.get("version") orelse return null;
                        if (name != .string or version != .string) return null;
                        const relative = try std.fs.path.relative(self.allocator, ".", null, directory, file_name);
                        defer self.allocator.free(relative);
                        const extension = std.fs.path.extension(relative);
                        var submodule = relative[0 .. relative.len - extension.len];
                        if (std.mem.endsWith(u8, submodule, ".d")) submodule = submodule[0 .. submodule.len - 2];
                        if (std.mem.eql(u8, submodule, "index")) submodule = "";
                        return .{
                            .name = try self.allocator.dupe(u8, name.string),
                            .version = try self.allocator.dupe(u8, version.string),
                            .sub_module_name = try self.allocator.dupe(u8, submodule),
                        };
                    }
                } else |_| {}
                return null;
            }
            const parent = std.fs.path.dirname(directory) orelse break;
            if (std.mem.eql(u8, parent, directory) or std.mem.endsWith(u8, directory, "node_modules")) break;
            directory = parent;
        }
        return null;
    }

    fn collectDependencies(self: *Program, io: std.Io, file_id: FileId) anyerror!void {
        const unit = self.units.items[file_id];
        const tree = unit.tree();
        const source = tree.getNode(unit.source_file).SourceFile;
        for (tree.getNodeList(source.Statements)) |statement| {
            const specifier_node = moduleSpecifier(tree, statement);
            if (specifier_node == 0) continue;
            const specifier = ast_utils.getText(tree, specifier_node);
            const owned_specifier = try self.allocator.dupe(u8, specifier);
            var resolved: ?FileId = null;
            if (try self.resolveModuleCached(io, unit.path, specifier)) |path| {
                resolved = try self.loadFile(io, path, false);
                self.allocator.free(path);
            }
            try unit.dependencies.append(self.allocator, .{ .specifier = owned_specifier, .resolved = resolved });
            if (resolved == null) try self.appendDiagnostic(file_id, 2307, try std.fmt.allocPrint(self.allocator, "Cannot find module '{s}' or its corresponding type declarations.", .{specifier}), statement, 0);
        }
        var require_offset: usize = 0;
        while (std.mem.indexOfPos(u8, unit.content, require_offset, "require(")) |call_start| {
            var quote_pos = call_start + "require(".len;
            while (quote_pos < unit.content.len and std.ascii.isWhitespace(unit.content[quote_pos])) : (quote_pos += 1) {}
            if (quote_pos >= unit.content.len or (unit.content[quote_pos] != '"' and unit.content[quote_pos] != '\'')) {
                require_offset = quote_pos;
                continue;
            }
            const quote = unit.content[quote_pos];
            const end = std.mem.indexOfScalarPos(u8, unit.content, quote_pos + 1, quote) orelse break;
            const specifier = unit.content[quote_pos + 1 .. end];
            require_offset = end + 1;
            var already_present = false;
            for (unit.dependencies.items) |dependency| if (std.mem.eql(u8, dependency.specifier, specifier)) {
                already_present = true;
                break;
            };
            if (already_present) continue;
            var resolved: ?FileId = null;
            if (try self.resolveModuleCached(io, unit.path, specifier)) |path| {
                resolved = try self.loadFile(io, path, false);
                self.allocator.free(path);
            }
            try unit.dependencies.append(self.allocator, .{ .specifier = try self.allocator.dupe(u8, specifier), .resolved = resolved });
            if (resolved == null) try self.appendDiagnostic(file_id, 2307, try std.fmt.allocPrint(self.allocator, "Cannot find module '{s}' or its corresponding type declarations.", .{specifier}), 0, @intCast(call_start));
        }
        for (tree.referencedFiles.items) |reference| {
            const owned_specifier = try self.allocator.dupe(u8, reference.fileName);
            var resolved: ?FileId = null;
            if (try self.resolveRelative(io, unit.path, reference.fileName)) |path| {
                resolved = try self.loadFile(io, path, false);
                self.allocator.free(path);
            }
            try unit.dependencies.append(self.allocator, .{ .specifier = owned_specifier, .resolved = resolved });
            if (resolved == null) try self.appendDiagnostic(file_id, 6053, try std.fmt.allocPrint(self.allocator, "File '{s}' not found.", .{reference.fileName}), 0, reference.pos);
        }
        for (tree.typeReferenceDirectives.items) |reference| {
            const owned_specifier = try self.allocator.dupe(u8, reference.fileName);
            var resolved: ?FileId = null;
            if (try self.resolveTypeReference(io, reference.fileName)) |path| {
                resolved = try self.loadFile(io, path, false);
                self.allocator.free(path);
            }
            try unit.dependencies.append(self.allocator, .{ .specifier = owned_specifier, .resolved = resolved });
            if (resolved == null) try self.appendDiagnostic(file_id, 2688, try std.fmt.allocPrint(self.allocator, "Cannot find type definition file for '{s}'.", .{reference.fileName}), 0, reference.pos);
        }
        for (tree.libReferenceDirectives.items) |reference| try self.loadLibraryByName(io, reference.fileName);
    }

    fn resolveModuleCached(self: *Program, io: std.Io, containing_file: []const u8, specifier: []const u8) !?[]const u8 {
        const require_mode = try self.usesRequireConditionsForFile(io, containing_file);
        const key = try std.fmt.allocPrint(self.allocator, "{s}\x00{s}\x00{c}", .{ containing_file, specifier, if (require_mode) @as(u8, 'r') else @as(u8, 'i') });
        if (self.resolution_cache.get(key)) |cached| {
            self.allocator.free(key);
            return if (cached.path) |path| try self.allocator.dupe(u8, path) else null;
        }

        const resolved = if (specifier.len > 0 and (specifier[0] == '.' or specifier[0] == '/'))
            try self.resolveRelative(io, containing_file, specifier)
        else if (try self.resolveMapped(io, specifier)) |path|
            path
        else if (try self.resolvePackageImport(io, containing_file, specifier)) |path|
            path
        else
            try self.resolveBare(io, containing_file, specifier);
        try self.resolution_cache.put(key, .{ .path = if (resolved) |path| try self.allocator.dupe(u8, path) else null });
        return resolved;
    }

    fn appendDiagnostic(self: *Program, file: FileId, code: u32, owned_message: []u8, node_index: ast.NodeIndex, explicit_pos: u32) !void {
        const unit = self.units.items[file];
        const loc = diagnosticLocation(unit.tree(), node_index, explicit_pos);
        try self.diagnostics.append(self.allocator, .{
            .file = file,
            .code = code,
            .message = owned_message,
            .line = loc.line,
            .column = loc.column,
        });
    }

    fn resolveRelative(self: *Program, io: std.Io, containing_file: []const u8, specifier: []const u8) !?[]const u8 {
        const base = if (std.fs.path.isAbsolute(specifier)) try self.allocator.dupe(u8, specifier) else try std.fs.path.join(self.allocator, &.{ std.fs.path.dirname(containing_file) orelse ".", specifier });
        defer self.allocator.free(base);
        if (std.mem.endsWith(u8, base, ".js") or std.mem.endsWith(u8, base, ".jsx") or std.mem.endsWith(u8, base, ".mjs") or std.mem.endsWith(u8, base, ".cjs")) {
            const stem = base[0 .. base.len - (std.fs.path.extension(base).len)];
            const substitutions = [_][]const u8{ ".ts", ".tsx", ".mts", ".cts", ".d.ts" };
            for (substitutions) |extension| {
                const candidate = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ stem, extension });
                if (fileExists(io, candidate)) return candidate;
                self.allocator.free(candidate);
            }
        }
        if (try self.resolvePathCandidate(io, base)) |resolved| return resolved;
        if (!std.fs.path.isAbsolute(specifier)) for (self.opts.options.rootDirs orelse &.{}) |configured_source_root| {
            const source_root = try canonicalPath(self.allocator, io, configured_source_root);
            defer self.allocator.free(source_root);
            if (!isPathInside(containing_file, source_root)) continue;
            const relative_directory = try std.fs.path.relativePosix(self.allocator, ".", source_root, std.fs.path.dirname(containing_file) orelse source_root);
            defer self.allocator.free(relative_directory);
            for (self.opts.options.rootDirs orelse &.{}) |configured_target_root| {
                const target_root = try canonicalPath(self.allocator, io, configured_target_root);
                defer self.allocator.free(target_root);
                if (std.mem.eql(u8, source_root, target_root)) continue;
                const candidate_base = try std.fs.path.join(self.allocator, &.{ target_root, relative_directory, specifier });
                defer self.allocator.free(candidate_base);
                if (try self.resolvePathCandidate(io, candidate_base)) |resolved| return resolved;
            }
        };
        return null;
    }

    fn resolveBare(self: *Program, io: std.Io, containing_file: []const u8, specifier: []const u8) !?[]const u8 {
        if (specifier.len == 0) return null;
        const package_end = packageNameEnd(specifier);
        const package_name = specifier[0..package_end];
        const subpath = if (package_end < specifier.len) specifier[package_end + 1 ..] else "";
        if (try self.resolvePackageSelfName(io, containing_file, package_name, subpath)) |resolved| return resolved;
        var directory = std.fs.path.dirname(containing_file) orelse ".";
        while (true) {
            const package_root = try std.fs.path.join(self.allocator, &.{ directory, "node_modules", package_name });
            defer self.allocator.free(package_root);
            const package_json = try std.fs.path.join(self.allocator, &.{ package_root, "package.json" });
            defer self.allocator.free(package_json);
            if (fileExists(io, package_json)) {
                const content = try std.Io.Dir.cwd().readFileAlloc(io, package_json, self.allocator, @enumFromInt(4 * 1024 * 1024));
                defer self.allocator.free(content);
                if (std.json.parseFromSlice(std.json.Value, self.allocator, content, .{})) |parsed_value| {
                    var parsed = parsed_value;
                    defer parsed.deinit();
                    if (parsed.value == .object) if (parsed.value.object.get("exports")) |exports| {
                        const export_key = if (subpath.len == 0) "." else try std.fmt.allocPrint(self.allocator, "./{s}", .{subpath});
                        defer if (subpath.len != 0) self.allocator.free(export_key);
                        if (try self.resolvePackageMap(io, package_root, exports, export_key, try self.usesRequireConditionsForFile(io, containing_file))) |resolved| return resolved;
                        if (self.opts.options.resolvePackageJsonExports orelse true) return null;
                    };
                    if (subpath.len != 0 and parsed.value == .object) if (parsed.value.object.get("typesVersions")) |types_versions| {
                        if (try self.resolveTypesVersions(io, package_root, types_versions, subpath)) |resolved| return resolved;
                    };
                } else |_| {}
            }
            if (subpath.len != 0) {
                const requested = try std.fs.path.join(self.allocator, &.{ package_root, subpath });
                defer self.allocator.free(requested);
                if (try self.resolvePathCandidate(io, requested)) |resolved| return resolved;
            } else {
                if (fileExists(io, package_json)) {
                    const content = try std.Io.Dir.cwd().readFileAlloc(io, package_json, self.allocator, @enumFromInt(4 * 1024 * 1024));
                    defer self.allocator.free(content);
                    if (std.json.parseFromSlice(std.json.Value, self.allocator, content, .{})) |parsed_value| {
                        var parsed = parsed_value;
                        defer parsed.deinit();
                        if (parsed.value == .object) {
                            const fields = [_][]const u8{ "types", "typings", "module", "main" };
                            for (fields) |field| if (parsed.value.object.get(field)) |entry| {
                                if (entry != .string) continue;
                                const requested = try std.fs.path.join(self.allocator, &.{ package_root, entry.string });
                                defer self.allocator.free(requested);
                                if (try self.resolvePathCandidate(io, requested)) |resolved| return resolved;
                            };
                        }
                    } else |_| {}
                }
                if (try self.resolvePathCandidate(io, package_root)) |resolved| return resolved;
            }
            if (subpath.len == 0) {
                const encoded_name = if (package_name.len > 0 and package_name[0] == '@') blk: {
                    const slash = std.mem.indexOfScalar(u8, package_name, '/') orelse break :blk package_name[1..];
                    break :blk try std.fmt.allocPrint(self.allocator, "{s}__{s}", .{ package_name[1..slash], package_name[slash + 1 ..] });
                } else try self.allocator.dupe(u8, package_name);
                defer self.allocator.free(encoded_name);
                const types_root = try std.fs.path.join(self.allocator, &.{ directory, "node_modules", "@types", encoded_name });
                defer self.allocator.free(types_root);
                if (try self.resolveTypePackage(io, types_root)) |resolved| return resolved;
            }
            const parent = std.fs.path.dirname(directory) orelse break;
            if (std.mem.eql(u8, parent, directory)) break;
            directory = parent;
        }
        return null;
    }

    fn resolveTypesVersions(self: *Program, io: std.Io, package_root: []const u8, types_versions: std.json.Value, subpath: []const u8) !?[]const u8 {
        if (types_versions != .object) return null;
        var arena_state = std.heap.ArenaAllocator.init(self.allocator);
        defer arena_state.deinit();
        const arena = arena_state.allocator();
        const compiler_version = semver.tryParseVersion(arena, "7.0.0-dev") catch return null;
        var versions = types_versions.object.iterator();
        while (versions.next()) |version_entry| {
            const range = semver_range.tryParseVersionRange(arena, version_entry.key_ptr.*) catch continue;
            if (!range.testVersion(&compiler_version)) continue;
            if (version_entry.value_ptr.* != .object) return null;
            return self.resolveTypesVersionsPaths(io, package_root, version_entry.value_ptr.*.object, subpath);
        }
        return null;
    }

    fn resolveTypesVersionsPaths(self: *Program, io: std.Io, package_root: []const u8, paths: std.json.ObjectMap, subpath: []const u8) !?[]const u8 {
        if (paths.get(subpath)) |targets| return self.resolveTypesVersionsTargets(io, package_root, targets, "");
        var best_key: ?[]const u8 = null;
        var best_capture: []const u8 = "";
        var iterator = paths.iterator();
        while (iterator.next()) |entry| {
            const star = std.mem.indexOfScalar(u8, entry.key_ptr.*, '*') orelse continue;
            const prefix = entry.key_ptr.*[0..star];
            const suffix = entry.key_ptr.*[star + 1 ..];
            if (!std.mem.startsWith(u8, subpath, prefix) or !std.mem.endsWith(u8, subpath, suffix) or subpath.len < prefix.len + suffix.len) continue;
            const best_prefix_len = if (best_key) |key| std.mem.indexOfScalar(u8, key, '*') orelse 0 else 0;
            if (best_key == null or prefix.len > best_prefix_len or (prefix.len == best_prefix_len and entry.key_ptr.*.len > best_key.?.len)) {
                best_key = entry.key_ptr.*;
                best_capture = subpath[prefix.len .. subpath.len - suffix.len];
            }
        }
        if (best_key) |key| return self.resolveTypesVersionsTargets(io, package_root, paths.get(key).?, best_capture);
        return null;
    }

    fn resolveTypesVersionsTargets(self: *Program, io: std.Io, package_root: []const u8, targets: std.json.Value, capture: []const u8) !?[]const u8 {
        if (targets != .array) return null;
        for (targets.array.items) |target| {
            if (target != .string) continue;
            const replaced = if (std.mem.indexOfScalar(u8, target.string, '*')) |star|
                try std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{ target.string[0..star], capture, target.string[star + 1 ..] })
            else
                try self.allocator.dupe(u8, target.string);
            defer self.allocator.free(replaced);
            const candidate = try std.fs.path.join(self.allocator, &.{ package_root, replaced });
            defer self.allocator.free(candidate);
            if (try self.resolvePathCandidate(io, candidate)) |resolved| return resolved;
        }
        return null;
    }

    fn resolvePackageSelfName(self: *Program, io: std.Io, containing_file: []const u8, package_name: []const u8, subpath: []const u8) !?[]const u8 {
        var directory = std.fs.path.dirname(containing_file) orelse ".";
        while (true) {
            const package_json = try std.fs.path.join(self.allocator, &.{ directory, "package.json" });
            defer self.allocator.free(package_json);
            if (fileExists(io, package_json)) {
                const content = try std.Io.Dir.cwd().readFileAlloc(io, package_json, self.allocator, @enumFromInt(4 * 1024 * 1024));
                defer self.allocator.free(content);
                if (std.json.parseFromSlice(std.json.Value, self.allocator, content, .{})) |parsed_value| {
                    var parsed = parsed_value;
                    defer parsed.deinit();
                    if (parsed.value == .object) {
                        const name = parsed.value.object.get("name");
                        const exports = parsed.value.object.get("exports");
                        if (name != null and name.? == .string and std.mem.eql(u8, name.?.string, package_name) and exports != null) {
                            const export_key = if (subpath.len == 0) "." else try std.fmt.allocPrint(self.allocator, "./{s}", .{subpath});
                            defer if (subpath.len != 0) self.allocator.free(export_key);
                            return self.resolvePackageMap(io, directory, exports.?, export_key, try self.usesRequireConditionsForFile(io, containing_file));
                        }
                    }
                } else |_| {}
                // The nearest package scope owns self-name resolution.
                return null;
            }
            const parent = std.fs.path.dirname(directory) orelse break;
            if (std.mem.eql(u8, parent, directory)) break;
            directory = parent;
        }
        return null;
    }

    fn usesRequireConditionsForFile(self: *Program, io: std.Io, containing_file: []const u8) !bool {
        if (usesRequireConditions(containing_file)) return true;
        if (std.mem.endsWith(u8, containing_file, ".mts") or std.mem.endsWith(u8, containing_file, ".mjs") or std.mem.endsWith(u8, containing_file, ".d.mts")) return false;
        var directory = std.fs.path.dirname(containing_file) orelse ".";
        while (true) {
            const package_json = try std.fs.path.join(self.allocator, &.{ directory, "package.json" });
            defer self.allocator.free(package_json);
            if (fileExists(io, package_json)) {
                const content = try std.Io.Dir.cwd().readFileAlloc(io, package_json, self.allocator, @enumFromInt(4 * 1024 * 1024));
                defer self.allocator.free(content);
                if (std.json.parseFromSlice(std.json.Value, self.allocator, content, .{})) |parsed_value| {
                    var parsed = parsed_value;
                    defer parsed.deinit();
                    if (parsed.value == .object) if (parsed.value.object.get("type")) |package_type| {
                        return package_type != .string or !std.mem.eql(u8, package_type.string, "module");
                    };
                } else |_| {}
                return true;
            }
            const parent = std.fs.path.dirname(directory) orelse break;
            if (std.mem.eql(u8, parent, directory)) break;
            directory = parent;
        }
        return true;
    }

    fn resolveMapped(self: *Program, io: std.Io, specifier: []const u8) !?[]const u8 {
        for (self.opts.pathMappings) |mapping| {
            const star = std.mem.indexOfScalar(u8, mapping.pattern, '*');
            var capture: []const u8 = "";
            if (star) |position| {
                const prefix = mapping.pattern[0..position];
                const suffix = mapping.pattern[position + 1 ..];
                if (!std.mem.startsWith(u8, specifier, prefix) or !std.mem.endsWith(u8, specifier, suffix) or specifier.len < prefix.len + suffix.len) continue;
                capture = specifier[prefix.len .. specifier.len - suffix.len];
            } else if (!std.mem.eql(u8, specifier, mapping.pattern)) continue;
            for (mapping.targets) |target| {
                const replaced = if (std.mem.indexOfScalar(u8, target, '*')) |position| try std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{ target[0..position], capture, target[position + 1 ..] }) else try self.allocator.dupe(u8, target);
                defer self.allocator.free(replaced);
                const base = if (std.fs.path.isAbsolute(replaced)) try self.allocator.dupe(u8, replaced) else try std.fs.path.join(self.allocator, &.{ self.opts.options.baseUrl orelse self.opts.projectName, replaced });
                defer self.allocator.free(base);
                if (try self.resolvePathCandidate(io, base)) |resolved| return resolved;
            }
        }
        return null;
    }

    fn resolvePackageImport(self: *Program, io: std.Io, containing_file: []const u8, specifier: []const u8) !?[]const u8 {
        if (specifier.len == 0 or specifier[0] != '#') return null;
        var directory = std.fs.path.dirname(containing_file) orelse ".";
        while (true) {
            const package_json = try std.fs.path.join(self.allocator, &.{ directory, "package.json" });
            defer self.allocator.free(package_json);
            if (fileExists(io, package_json)) {
                const content = try std.Io.Dir.cwd().readFileAlloc(io, package_json, self.allocator, @enumFromInt(4 * 1024 * 1024));
                defer self.allocator.free(content);
                if (std.json.parseFromSlice(std.json.Value, self.allocator, content, .{})) |parsed_value| {
                    var parsed = parsed_value;
                    defer parsed.deinit();
                    if (parsed.value == .object) if (parsed.value.object.get("imports")) |imports| {
                        if (try self.resolvePackageMap(io, directory, imports, specifier, try self.usesRequireConditionsForFile(io, containing_file))) |resolved| return resolved;
                    };
                } else |_| {}
            }
            const parent = std.fs.path.dirname(directory) orelse break;
            if (std.mem.eql(u8, parent, directory)) break;
            directory = parent;
        }
        return null;
    }

    fn resolvePackageMap(self: *Program, io: std.Io, package_root: []const u8, map: std.json.Value, requested_key: []const u8, prefer_require: bool) !?[]const u8 {
        if (map == .string or map == .array) return self.resolvePackageTarget(io, package_root, map, "", prefer_require);
        if (map != .object) return null;
        if (map.object.get(requested_key)) |target| return self.resolvePackageTarget(io, package_root, target, "", prefer_require);
        var best_key: ?[]const u8 = null;
        var best_capture: []const u8 = "";
        var iterator = map.object.iterator();
        while (iterator.next()) |entry| {
            const star = std.mem.indexOfScalar(u8, entry.key_ptr.*, '*') orelse continue;
            const prefix = entry.key_ptr.*[0..star];
            const suffix = entry.key_ptr.*[star + 1 ..];
            if (!std.mem.startsWith(u8, requested_key, prefix) or !std.mem.endsWith(u8, requested_key, suffix) or requested_key.len < prefix.len + suffix.len) continue;
            const capture = requested_key[prefix.len .. requested_key.len - suffix.len];
            const best_prefix_len = if (best_key) |key| std.mem.indexOfScalar(u8, key, '*') orelse 0 else 0;
            if (best_key == null or prefix.len > best_prefix_len or (prefix.len == best_prefix_len and entry.key_ptr.*.len > best_key.?.len)) {
                best_key = entry.key_ptr.*;
                best_capture = capture;
            }
        }
        if (best_key) |key| if (try self.resolvePackageTarget(io, package_root, map.object.get(key).?, best_capture, prefer_require)) |resolved| return resolved;
        // A condition object at the root (for the "." export).
        if (std.mem.eql(u8, requested_key, ".")) return self.resolvePackageTarget(io, package_root, map, "", prefer_require);
        return null;
    }

    fn resolvePackageTarget(self: *Program, io: std.Io, package_root: []const u8, target: std.json.Value, capture: []const u8, prefer_require: bool) !?[]const u8 {
        switch (target) {
            .string => |text| {
                const replaced = if (std.mem.indexOfScalar(u8, text, '*')) |star| try std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{ text[0..star], capture, text[star + 1 ..] }) else try self.allocator.dupe(u8, text);
                defer self.allocator.free(replaced);
                var requested = try std.fs.path.join(self.allocator, &.{ package_root, replaced });
                defer self.allocator.free(requested);

                if (try self.tryLoadInputFileForPath(io, requested)) |mapped_requested| {
                    self.allocator.free(requested);
                    requested = mapped_requested;
                }

                if (std.mem.endsWith(u8, requested, ".js") or std.mem.endsWith(u8, requested, ".jsx") or std.mem.endsWith(u8, requested, ".mjs") or std.mem.endsWith(u8, requested, ".cjs")) {
                    const extension = std.fs.path.extension(requested);
                    const stem = requested[0 .. requested.len - extension.len];
                    const substitutions = if (std.mem.eql(u8, extension, ".mjs"))
                        [_][]const u8{ ".mts", ".d.mts", ".mjs", "" }
                    else if (std.mem.eql(u8, extension, ".cjs"))
                        [_][]const u8{ ".cts", ".d.cts", ".cjs", "" }
                    else
                        [_][]const u8{ ".ts", ".tsx", ".d.ts", ".js" };
                    for (substitutions) |replacement_extension| {
                        if (replacement_extension.len == 0) continue;
                        const candidate = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ stem, replacement_extension });
                        if (fileExists(io, candidate)) return candidate;
                        self.allocator.free(candidate);
                    }
                }
                return self.resolvePathCandidate(io, requested);
            },
            .array => |items| {
                for (items.items) |item| if (try self.resolvePackageTarget(io, package_root, item, capture, prefer_require)) |resolved| return resolved;
            },
            .object => |conditions| {
                // Node conditional exports are order-sensitive: select the first
                // property whose condition is active, rather than imposing our
                // own priority over the package author's object order.
                var iterator = conditions.iterator();
                while (iterator.next()) |entry| {
                    const condition = entry.key_ptr.*;
                    const active = std.mem.eql(u8, condition, "types") or
                        std.mem.eql(u8, condition, "node") or
                        std.mem.eql(u8, condition, "default") or
                        (prefer_require and std.mem.eql(u8, condition, "require")) or
                        (!prefer_require and std.mem.eql(u8, condition, "import")) or
                        containsString(self.opts.options.customConditions orelse &.{}, condition);
                    if (active) if (try self.resolvePackageTarget(io, package_root, entry.value_ptr.*, capture, prefer_require)) |resolved| return resolved;
                }
            },
            else => {},
        }
        return null;
    }

    fn tryLoadInputFileForPath(self: *Program, io: std.Io, requested: []const u8) !?[]u8 {
        const hasOutDir = self.opts.options.outDir != null or self.opts.options.declarationDir != null;
        if (!hasOutDir or std.mem.indexOf(u8, requested, "/node_modules/") != null) return null;

        var rootDir: ?[]const u8 = self.opts.options.rootDir;
        if (rootDir == null and self.opts.options.configFilePath != null) {
            rootDir = std.fs.path.dirname(self.opts.options.configFilePath.?);
        }
        if (rootDir == null) return null;

        var outDirs = std.ArrayList([]const u8).empty;
        defer outDirs.deinit(self.allocator);
        if (self.opts.options.outDir) |outDir| {
            try outDirs.append(self.allocator, try canonicalPath(self.allocator, io, outDir));
        }
        if (self.opts.options.declarationDir) |declDir| {
            try outDirs.append(self.allocator, try canonicalPath(self.allocator, io, declDir));
        }
        defer {
            for (outDirs.items) |dir| self.allocator.free(dir);
        }

        const canonical_requested = try canonicalPath(self.allocator, io, requested);
        defer self.allocator.free(canonical_requested);

        for (outDirs.items) |outDir| {
            if (isPathInside(canonical_requested, outDir)) {
                var pathFragment = canonical_requested[outDir.len..];
                if (pathFragment.len > 0 and (pathFragment[0] == '/' or pathFragment[0] == '\\')) {
                    pathFragment = pathFragment[1..];
                }
                const root_dir_canonical = try canonicalPath(self.allocator, io, rootDir.?);
                defer self.allocator.free(root_dir_canonical);

                return try std.fs.path.join(self.allocator, &.{ root_dir_canonical, pathFragment });
            }
        }
        return null;
    }

    fn resolvePathCandidate(self: *Program, io: std.Io, base: []const u8) !?[]const u8 {
        const extensions = [_][]const u8{ "", ".ts", ".tsx", ".mts", ".cts", ".d.ts", ".js", ".jsx", ".mjs", ".cjs", ".json" };
        for (extensions) |extension| {
            if (std.mem.eql(u8, extension, ".json") and !(self.opts.options.resolveJsonModule orelse false)) continue;
            const default_suffixes = [_][]const u8{""};
            const suffixes: []const []const u8 = self.opts.options.moduleSuffixes orelse &default_suffixes;
            for (suffixes) |suffix| {
                const candidate = try std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{ base, suffix, extension });
                if (fileExists(io, candidate)) return candidate;
                self.allocator.free(candidate);
            }
        }
        const indexes = [_][]const u8{ "index.ts", "index.tsx", "index.mts", "index.cts", "index.d.ts", "index.js" };
        for (indexes) |index| {
            const candidate = try std.fs.path.join(self.allocator, &.{ base, index });
            if (fileExists(io, candidate)) return candidate;
            self.allocator.free(candidate);
        }
        return null;
    }

    pub fn bind(self: *Program) !void {
        for (self.units.items) |unit| {
            if (unit.binder_instance != null) continue;
            const instance = try self.allocator.create(binder.Binder);
            instance.* = try binder.Binder.init(self.allocator, unit.tree());
            try instance.bindSourceFile(unit.source_file);
            unit.binder_instance = instance;
        }
    }

    pub fn link(self: *Program) !void {
        for (self.units.items, 0..) |unit, file_index| try self.indexExports(@intCast(file_index), unit);
        for (self.units.items, 0..) |unit, file_index| try self.indexModuleAugmentations(@intCast(file_index), unit);
        for (self.units.items, 0..) |unit, file_index| try self.indexReExports(@intCast(file_index), unit);
        for (self.units.items, 0..) |unit, file_index| try self.indexImports(@intCast(file_index), unit);
    }

    fn indexModuleAugmentations(self: *Program, augmentation_file: FileId, unit: *SourceUnit) !void {
        const tree = unit.tree();
        const source = tree.getNode(unit.source_file).SourceFile;
        for (tree.getNodeList(source.Statements)) |statement| {
            if (tree.getNode(statement) != .ModuleDeclaration) continue;
            const module = tree.getNode(statement).ModuleDeclaration;
            if (tree.getNode(module.name) != .StringLiteral or (module.Body orelse 0) == 0) continue;
            const specifier = ast_utils.getText(tree, module.name);
            const target = dependencyTarget(unit, specifier) orelse continue;
            if (tree.getNode(module.Body.?) != .ModuleBlock) continue;
            const block = tree.getNode(module.Body.?).ModuleBlock;
            for (tree.getNodeList(block.Statements)) |member| try self.indexAmbientExport(target, augmentation_file, tree, member);
        }
    }

    fn indexAmbientExport(self: *Program, target: FileId, declaration_file: FileId, tree: *ast.Ast, statement: ast.NodeIndex) !void {
        switch (tree.getNode(statement)) {
            .FunctionDeclaration => |node| if ((node.name orelse 0) != 0) try self.putExportFrom(target, ast_utils.getText(tree, node.name.?), declaration_file, statement, .{ .value = true }),
            .ClassDeclaration => |node| if ((node.name orelse 0) != 0) try self.putExportFrom(target, ast_utils.getText(tree, node.name.?), declaration_file, statement, .{ .value = true, .type = true }),
            .InterfaceDeclaration => |node| try self.putExportFrom(target, ast_utils.getText(tree, node.name), declaration_file, statement, .{ .type = true }),
            .TypeAliasDeclaration => |node| try self.putExportFrom(target, ast_utils.getText(tree, node.name), declaration_file, statement, .{ .type = true }),
            .EnumDeclaration => |node| try self.putExportFrom(target, ast_utils.getText(tree, node.name), declaration_file, statement, .{ .value = true, .type = true }),
            .ModuleDeclaration => |node| if (tree.getNode(node.name) == .Identifier) try self.putExportFrom(target, ast_utils.getText(tree, node.name), declaration_file, statement, .{ .value = true, .type = true }),
            .VariableStatement => |node| {
                const list = tree.getNode(node.DeclarationList).VariableDeclarationList;
                for (tree.getNodeList(list.Declarations)) |declaration| {
                    const name = tree.getNode(declaration).VariableDeclaration.name;
                    if (tree.getNode(name) == .Identifier) try self.putExportFrom(target, ast_utils.getText(tree, name), declaration_file, declaration, .{ .value = true });
                }
            },
            else => {},
        }
    }

    fn indexExports(self: *Program, file: FileId, unit: *SourceUnit) !void {
        const tree = unit.tree();
        const source = tree.getNode(unit.source_file).SourceFile;
        for (tree.getNodeList(source.Statements)) |statement| switch (tree.getNode(statement)) {
            .FunctionDeclaration => |node| if (hasExport(tree, node.modifiers orelse 0) and (node.name orelse 0) != 0) {
                try self.putExport(file, ast_utils.getText(tree, node.name.?), statement, .{ .value = true });
                if (hasDefault(tree, node.modifiers orelse 0)) try self.putExport(file, "default", statement, .{ .value = true });
            },
            .ClassDeclaration => |node| if (hasExport(tree, node.modifiers orelse 0) and (node.name orelse 0) != 0) {
                try self.putExport(file, ast_utils.getText(tree, node.name.?), statement, .{ .value = true, .type = true });
                if (hasDefault(tree, node.modifiers orelse 0)) try self.putExport(file, "default", statement, .{ .value = true, .type = true });
            },
            .InterfaceDeclaration => |node| if (hasExport(tree, node.modifiers orelse 0)) try self.putExport(file, ast_utils.getText(tree, node.name), statement, .{ .type = true }),
            .TypeAliasDeclaration => |node| if (hasExport(tree, node.modifiers orelse 0)) try self.putExport(file, ast_utils.getText(tree, node.name), statement, .{ .type = true }),
            .EnumDeclaration => |node| if (hasExport(tree, node.modifiers orelse 0)) try self.putExport(file, ast_utils.getText(tree, node.name), statement, .{ .value = true, .type = true }),
            .ModuleDeclaration => |node| if (hasExport(tree, node.modifiers orelse 0) and tree.getNode(node.name) == .Identifier) try self.putExport(file, ast_utils.getText(tree, node.name), statement, .{ .value = true, .type = true }),
            .VariableStatement => |node| if (hasExport(tree, node.modifiers orelse 0)) {
                const list = tree.getNode(node.DeclarationList).VariableDeclarationList;
                for (tree.getNodeList(list.Declarations)) |declaration| {
                    const name = tree.getNode(declaration).VariableDeclaration.name;
                    if (tree.getNode(name) == .Identifier) try self.putExport(file, ast_utils.getText(tree, name), declaration, .{ .value = true });
                }
            },
            else => {},
        };
    }

    fn indexReExports(self: *Program, file: FileId, unit: *SourceUnit) !void {
        const tree = unit.tree();
        const source = tree.getNode(unit.source_file).SourceFile;
        for (tree.getNodeList(source.Statements)) |statement| {
            if (tree.getNode(statement) != .ExportDeclaration) continue;
            const declaration = tree.getNode(statement).ExportDeclaration;
            const target = if ((declaration.ModuleSpecifier orelse 0) != 0) dependencyTarget(unit, ast_utils.getText(tree, declaration.ModuleSpecifier.?)) else null;
            if ((declaration.ExportClause orelse 0) == 0) {
                const target_file = target orelse continue;
                var exports = self.exports_by_key.iterator();
                var copies = std.ArrayList(struct { name: []const u8, symbol: ExportedSymbol }).empty;
                while (exports.next()) |entry| {
                    if (entry.value_ptr.file != target_file) continue;
                    const separator = std.mem.indexOfScalar(u8, entry.key_ptr.*, ':') orelse continue;
                    const name = entry.key_ptr.*[separator + 1 ..];
                    if (std.mem.eql(u8, name, "default")) continue;
                    try copies.append(self.allocator, .{ .name = name, .symbol = entry.value_ptr.* });
                }
                for (copies.items) |copy| try self.putExport(file, copy.name, statement, copy.symbol.meaning);
                copies.deinit(self.allocator);
                continue;
            }
            if (tree.getNode(declaration.ExportClause.?) != .NamedExports) continue;
            for (tree.getNodeList(tree.getNode(declaration.ExportClause.?).NamedExports.Elements)) |element| {
                const specifier = tree.getNode(element).ExportSpecifier;
                const imported_name = ast_utils.getText(tree, specifier.PropertyName orelse specifier.name);
                const exported_name = ast_utils.getText(tree, specifier.name);
                var meaning = SymbolMeaning{ .value = specifier.IsTypeOnly == 0, .type = true };
                if (target) |target_file| {
                    const target_key = try symbolKey(self.allocator, target_file, imported_name);
                    defer self.allocator.free(target_key);
                    if (self.exports_by_key.get(target_key)) |symbol| meaning = symbol.meaning;
                }
                try self.putExport(file, exported_name, statement, meaning);
            }
        }
    }

    fn indexImports(self: *Program, file: FileId, unit: *SourceUnit) !void {
        const tree = unit.tree();
        const source = tree.getNode(unit.source_file).SourceFile;
        for (tree.getNodeList(source.Statements)) |statement| {
            if (tree.getNode(statement) != .ImportDeclaration) continue;
            const declaration = tree.getNode(statement).ImportDeclaration;
            const module_specifier = ast_utils.getText(tree, declaration.ModuleSpecifier);
            const target = dependencyTarget(unit, module_specifier);
            const target_file = target orelse continue;
            const clause_index = declaration.ImportClause orelse continue;
            const clause_node = tree.getNode(clause_index);
            if (clause_node != .ImportClause) continue;
            const clause = clause_node.ImportClause;
            if ((clause.name orelse 0) != 0) try self.putAlias(file, ast_utils.getText(tree, clause.name.?), target_file, "default", clause.name.?);
            if ((clause.NamedBindings orelse 0) == 0) continue;
            switch (tree.getNode(clause.NamedBindings.?)) {
                .NamespaceImport => |namespace| try self.putAlias(file, ast_utils.getText(tree, namespace.name), target_file, "*", namespace.name),
                .NamedImports => |named| for (tree.getNodeList(named.Elements)) |element| {
                    const specifier = tree.getNode(element).ImportSpecifier;
                    try self.putAlias(file, ast_utils.getText(tree, specifier.name), target_file, ast_utils.getText(tree, specifier.PropertyName orelse specifier.name), element);
                },
                else => {},
            }
        }
    }

    fn putExport(self: *Program, file: FileId, name: []const u8, declaration: ast.NodeIndex, meaning: SymbolMeaning) !void {
        return self.putExportFrom(file, name, file, declaration, meaning);
    }

    fn putExportFrom(self: *Program, file: FileId, name: []const u8, declaration_file: FileId, declaration: ast.NodeIndex, meaning: SymbolMeaning) !void {
        const key = try symbolKey(self.allocator, file, name);
        if (self.exports_by_key.getPtr(key)) |existing| {
            existing.meaning.value = existing.meaning.value or meaning.value;
            existing.meaning.type = existing.meaning.type or meaning.type;
            self.allocator.free(key);
            return;
        }
        try self.exports_by_key.put(key, .{ .file = file, .declaration_file = declaration_file, .declaration = declaration, .meaning = meaning });
    }

    fn putAlias(self: *Program, file: FileId, local_name: []const u8, target_file: FileId, imported_name: []const u8, declaration_node: ast.NodeIndex) !void {
        const key = try symbolKey(self.allocator, file, local_name);
        if (self.aliases_by_key.contains(key)) {
            self.allocator.free(key);
            return;
        }
        try self.aliases_by_key.put(key, .{
            .target_file = target_file,
            .imported_name = try self.allocator.dupe(u8, imported_name),
            .declaration_node = declaration_node,
        });
    }

    pub fn resolveAlias(self: *Program, file: FileId, local_name: []const u8) ?ExportedSymbol {
        const key = symbolKey(self.allocator, file, local_name) catch return null;
        defer self.allocator.free(key);
        const alias = self.aliases_by_key.get(key) orelse return null;
        if (std.mem.eql(u8, alias.imported_name, "*")) return null;
        const target_key = symbolKey(self.allocator, alias.target_file, alias.imported_name) catch return null;
        defer self.allocator.free(target_key);
        return self.exports_by_key.get(target_key);
    }

    pub fn check(self: *Program) !void {
        var default_lib_binder: ?*binder.Binder = null;
        for (self.units.items) |unit| {
            if (unit.is_default_library) {
                if (unit.binder_instance) |b| {
                    default_lib_binder = b;
                    break;
                }
            }
        }

        const module_kind = emitter_mod.getEmitModuleKind(&self.opts.options);

        for (self.units.items, 0..) |unit, file_index| {
            if (unit.is_default_library) continue;
            if (!unit.is_root and isJsSourcePath(unit.path)) continue;
            const bound = unit.binder_instance orelse continue;
            var instance = checker.Checker.init(self.allocator, bound);
            instance.default_lib_binder = default_lib_binder;
            const strict = self.opts.options.strict orelse false;
            instance.strictNullChecks = self.opts.options.strictNullChecks orelse strict;
            instance.noImplicitAny = self.opts.options.noImplicitAny orelse strict;
            instance.checkJs = self.opts.options.checkJs orelse false;
            instance.allowJs = self.opts.options.allowJs orelse false;
            instance.erasableSyntaxOnly = self.opts.options.erasableSyntaxOnly orelse false;
            instance.moduleKind = module_kind;
            defer instance.deinit();
            try instance.checkStatementAdHoc(unit.source_file);
            const parser_ast = &unit.parser_instance.ast;
            for (parser_ast.diagnostics.items) |diagnostic| {
                const formatted_message = try formatDiagnosticMessage(self.allocator, diagnostic.message.text, diagnostic.args);
                const loc = diagnosticLocation(parser_ast, diagnostic.nodeIndex, diagnostic.pos);
                try self.diagnostics.append(self.allocator, .{
                    .file = @intCast(file_index),
                    .code = diagnostic.message.code,
                    .message = formatted_message,
                    .category = diagnostic.message.category,
                    .line = loc.line,
                    .column = loc.column,
                });
            }
            for (bound.diagnosticsList.items) |diagnostic| {
                const formatted_message = try formatDiagnosticMessage(self.allocator, diagnostic.message.text, diagnostic.args);
                const loc = diagnosticLocation(bound.ast, diagnostic.nodeIndex, 0);
                try self.diagnostics.append(self.allocator, .{
                    .file = @intCast(file_index),
                    .code = diagnostic.message.code,
                    .message = formatted_message,
                    .category = diagnostic.message.category,
                    .line = loc.line,
                    .column = loc.column,
                });
            }
        }
        var aliases = self.aliases_by_key.iterator();
        while (aliases.next()) |entry| {
            const alias = entry.value_ptr.*;
            if (std.mem.eql(u8, alias.imported_name, "*")) continue;
            if (std.mem.eql(u8, alias.imported_name, "default") and (self.opts.options.allowSyntheticDefaultImports orelse false)) continue;
            const target_key = try symbolKey(self.allocator, alias.target_file, alias.imported_name);
            defer self.allocator.free(target_key);
            if (!self.exports_by_key.contains(target_key)) {
                const separator = std.mem.indexOfScalar(u8, entry.key_ptr.*, ':') orelse 0;
                const file = std.fmt.parseInt(FileId, entry.key_ptr.*[0..separator], 10) catch 0;
                const unit = self.units.items[file];
                const loc = diagnosticLocation(unit.tree(), alias.declaration_node, 0);
                try self.diagnostics.append(self.allocator, .{
                    .file = file,
                    .code = 2305,
                    .message = try std.fmt.allocPrint(self.allocator, "Module has no exported member '{s}'.", .{alias.imported_name}),
                    .line = loc.line,
                    .column = loc.column,
                });
            }
        }
        var exports = self.exports_by_key.iterator();
        while (exports.next()) |entry| {
            const symbol = entry.value_ptr.*;
            const unit = self.units.items[symbol.declaration_file];
            const inferred = inferDeclarationType(unit.tree(), symbol.declaration);
            try self.public_types.put(try self.allocator.dupe(u8, entry.key_ptr.*), inferred);
        }
        var pass: usize = 0;
        while (pass < self.units.items.len) : (pass += 1) {
            var changed = false;
            var public_iterator = self.exports_by_key.iterator();
            while (public_iterator.next()) |entry| {
                if (self.public_types.get(entry.key_ptr.*) != .unknown) continue;
                const symbol = entry.value_ptr.*;
                const unit = self.units.items[symbol.declaration_file];
                if (unit.tree().getNode(symbol.declaration) != .VariableDeclaration) continue;
                const declaration = unit.tree().getNode(symbol.declaration).VariableDeclaration;
                const initializer = declaration.Initializer orelse continue;
                if (unit.tree().getNode(initializer) != .Identifier) continue;
                const local_name = ast_utils.getText(unit.tree(), initializer);
                const alias_key = try symbolKey(self.allocator, symbol.file, local_name);
                defer self.allocator.free(alias_key);
                const alias = self.aliases_by_key.get(alias_key) orelse continue;
                const target_key = try symbolKey(self.allocator, alias.target_file, alias.imported_name);
                defer self.allocator.free(target_key);
                const target_type = self.public_types.get(target_key) orelse continue;
                if (target_type == .unknown) continue;
                self.public_types.getPtr(entry.key_ptr.*).?.* = target_type;
                changed = true;
            }
            if (!changed) break;
        }
    }

    pub fn getPublicType(self: *Program, file: FileId, name: []const u8) ?SemanticType {
        const key = symbolKey(self.allocator, file, name) catch return null;
        defer self.allocator.free(key);
        return self.public_types.get(key);
    }

    pub fn getBinder(self: *Program, file: FileId) ?*binder.Binder {
        if (file >= self.units.items.len) return null;
        return self.units.items[file].binder_instance;
    }

    pub fn signatureHash(self: *Program, file: FileId) u64 {
        var hash = std.hash.Wyhash.init(0);
        var exports = self.exports_by_key.iterator();
        while (exports.next()) |entry| {
            if (entry.value_ptr.file != file) continue;
            hash.update(entry.key_ptr.*);
            hash.update(std.mem.asBytes(&entry.value_ptr.meaning));
            if (self.public_types.get(entry.key_ptr.*)) |semantic_type| hash.update(std.mem.asBytes(&semantic_type));
            const unit = self.units.items[entry.value_ptr.declaration_file];
            updatePublicSignature(unit.tree(), entry.value_ptr.declaration, &hash);
        }
        return hash.final();
    }

    pub fn fileCount(self: *const Program) usize {
        return self.units.items.len;
    }

    pub fn getUnit(self: *Program, id: FileId) *SourceUnit {
        return self.units.items[id];
    }

    pub fn getFileId(self: *const Program, path: []const u8) ?FileId {
        return self.files_by_path.get(path);
    }
};

pub fn createProgram(allocator: std.mem.Allocator, opts: ProgramOptions) !*Program {
    const program = try allocator.create(Program);
    program.* = Program.init(allocator, opts);
    return program;
}

fn scriptKindForPath(path: []const u8) core.ScriptKind {
    if (std.mem.endsWith(u8, path, ".jsx")) return .JSX;
    if (std.mem.endsWith(u8, path, ".js") or std.mem.endsWith(u8, path, ".mjs") or std.mem.endsWith(u8, path, ".cjs")) return .JS;
    if (std.mem.endsWith(u8, path, ".tsx")) return .TSX;
    if (std.mem.endsWith(u8, path, ".json")) return .JSON;
    return .TS;
}

fn moduleSpecifier(tree: *ast.Ast, node: ast.NodeIndex) ast.NodeIndex {
    return switch (tree.getNode(node)) {
        .ImportDeclaration => |declaration| declaration.ModuleSpecifier,
        .JSImportDeclaration => |declaration| declaration.ModuleSpecifier,
        .ExportDeclaration => |declaration| declaration.ModuleSpecifier orelse 0,
        .ImportEqualsDeclaration => |declaration| switch (tree.getNode(declaration.ModuleReference)) {
            .ExternalModuleReference => |reference| reference.Expression,
            else => 0,
        },
        .ModuleDeclaration => 0,
        else => 0,
    };
}

fn normalizePath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    return std.fs.path.resolve(allocator, &.{path});
}

fn canonicalPath(allocator: std.mem.Allocator, io: std.Io, path: []const u8) ![]u8 {
    const real = if (std.fs.path.isAbsolute(path))
        std.Io.Dir.realPathFileAbsoluteAlloc(io, path, allocator)
    else
        std.Io.Dir.cwd().realPathFileAlloc(io, path, allocator);
    if (real) |sentinel_path| {
        defer allocator.free(sentinel_path);
        return allocator.dupe(u8, sentinel_path);
    } else |_| {
        return normalizePath(allocator, path);
    }
}

fn fileExists(io: std.Io, path: []const u8) bool {
    const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch return false;
    defer file.close(io);
    const stat = file.stat(io) catch return false;
    return stat.kind == .file;
}

fn isNotNeededTypePackage(allocator: std.mem.Allocator, io: std.Io, package_root: []const u8) !bool {
    const package_json = try std.fs.path.join(allocator, &.{ package_root, "package.json" });
    defer allocator.free(package_json);
    if (!fileExists(io, package_json)) return false;
    const content = try std.Io.Dir.cwd().readFileAlloc(io, package_json, allocator, @enumFromInt(4 * 1024 * 1024));
    defer allocator.free(content);
    if (std.json.parseFromSlice(std.json.Value, allocator, content, .{})) |parsed_value| {
        var parsed = parsed_value;
        defer parsed.deinit();
        if (parsed.value == .object) if (parsed.value.object.get("typings")) |typings| return typings == .null;
    } else |_| {}
    return false;
}

fn isPathInside(path: []const u8, directory: []const u8) bool {
    if (!std.mem.startsWith(u8, path, directory)) return false;
    return path.len == directory.len or directory.len > 0 and (directory[directory.len - 1] == std.fs.path.sep or path[directory.len] == std.fs.path.sep);
}

fn isJsxPath(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".tsx") or std.mem.endsWith(u8, path, ".jsx");
}

fn usesRequireConditions(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".cts") or std.mem.endsWith(u8, path, ".cjs") or std.mem.endsWith(u8, path, ".d.cts");
}

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| if (std.mem.eql(u8, value, needle)) return true;
    return false;
}

fn isJsSourcePath(path: []const u8) bool {
    const ext = tspath.tryGetExtensionFromPath(path);
    return std.mem.eql(u8, ext, ".js") or
        std.mem.eql(u8, ext, ".jsx") or
        std.mem.eql(u8, ext, ".mjs") or
        std.mem.eql(u8, ext, ".cjs");
}

fn defaultLibraryName(target: core.ScriptTarget) []const u8 {
    return switch (target) {
        .None, .ES5 => "lib.d.ts",
        .ES2015 => "es2015.full",
        .ES2016 => "es2016.full",
        .ES2017 => "es2017.full",
        .ES2018 => "es2018.full",
        .ES2019 => "es2019.full",
        .ES2020 => "es2020.full",
        .ES2021 => "es2021.full",
        .ES2022 => "es2022.full",
        .ES2023 => "es2023.full",
        .ES2024 => "es2024.full",
        .ES2025 => "es2025.full",
        .ESNext, .JSON => "esnext.full",
    };
}

fn packageNameEnd(specifier: []const u8) usize {
    if (specifier[0] == '@') {
        const first = std.mem.indexOfScalar(u8, specifier, '/') orelse return specifier.len;
        return std.mem.indexOfScalarPos(u8, specifier, first + 1, '/') orelse specifier.len;
    }
    return std.mem.indexOfScalar(u8, specifier, '/') orelse specifier.len;
}

fn hasExport(tree: *ast.Ast, modifiers: ast.NodeIndex) bool {
    if (modifiers == 0) return false;
    for (tree.getNodeList(modifiers)) |modifier| if (tree.getNodeKind(modifier) == .ExportKeyword) return true;
    return false;
}

fn hasDefault(tree: *ast.Ast, modifiers: ast.NodeIndex) bool {
    if (modifiers == 0) return false;
    for (tree.getNodeList(modifiers)) |modifier| if (tree.getNodeKind(modifier) == .DefaultKeyword) return true;
    return false;
}

fn dependencyTarget(unit: *SourceUnit, specifier: []const u8) ?FileId {
    for (unit.dependencies.items) |dependency| if (std.mem.eql(u8, dependency.specifier, specifier)) return dependency.resolved;
    return null;
}

fn symbolKey(allocator: std.mem.Allocator, file: FileId, name: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{d}:{s}", .{ file, name });
}

fn freeMapKeys(allocator: std.mem.Allocator, map: anytype) void {
    var iterator = map.keyIterator();
    while (iterator.next()) |key| allocator.free(key.*);
}

fn inferDeclarationType(tree: *ast.Ast, declaration: ast.NodeIndex) SemanticType {
    return switch (tree.getNode(declaration)) {
        .VariableDeclaration => |node| if ((node.Type orelse 0) != 0) semanticTypeOfTypeNode(tree, node.Type.?) else inferExpressionType(tree, node.Initializer orelse 0),
        .FunctionDeclaration => .function,
        .ClassDeclaration => .object,
        .EnumDeclaration => .number,
        .InterfaceDeclaration, .TypeAliasDeclaration => .object,
        else => .unknown,
    };
}

fn semanticTypeOfTypeNode(tree: *ast.Ast, node: ast.NodeIndex) SemanticType {
    return switch (tree.getNodeKind(node)) {
        .AnyKeyword => .any,
        .VoidKeyword, .UndefinedKeyword, .NeverKeyword => .void,
        .BooleanKeyword => .boolean,
        .NumberKeyword => .number,
        .BigIntKeyword => .bigint,
        .StringKeyword, .TemplateLiteralType => .string,
        .FunctionType, .ConstructorType => .function,
        .ObjectKeyword, .TypeLiteral, .ArrayType, .TupleType, .TypeReference => .object,
        else => .unknown,
    };
}

fn inferExpressionType(tree: *ast.Ast, node: ast.NodeIndex) SemanticType {
    if (node == 0) return .unknown;
    return switch (tree.getNode(node)) {
        .StringLiteral, .NoSubstitutionTemplateLiteral, .TemplateExpression => .string,
        .NumericLiteral => .number,
        .BigIntLiteral => .bigint,
        .TrueKeyword, .FalseKeyword => .boolean,
        .ArrowFunction, .FunctionExpression => .function,
        .ObjectLiteralExpression, .ArrayLiteralExpression, .ClassExpression, .NewExpression => .object,
        .ParenthesizedExpression => |expression| inferExpressionType(tree, expression.Expression),
        else => .unknown,
    };
}

fn isAssignable(actual: SemanticType, expected: SemanticType) bool {
    return expected == .any or expected == .unknown or actual == .any or actual == .unknown or actual == expected;
}

fn updatePublicSignature(tree: *ast.Ast, declaration: ast.NodeIndex, hash: *std.hash.Wyhash) void {
    hash.update(@tagName(tree.getNodeKind(declaration)));
    switch (tree.getNode(declaration)) {
        .VariableDeclaration => |node| if ((node.Type orelse 0) != 0) hash.update(ast_utils.getText(tree, node.Type.?)),
        .FunctionDeclaration => |node| {
            if ((node.name orelse 0) != 0) hash.update(ast_utils.getText(tree, node.name.?));
            for (tree.getNodeList(node.Parameters)) |parameter_index| {
                const parameter = tree.getNode(parameter_index).Parameter;
                hash.update(ast_utils.getText(tree, parameter.name));
                if ((parameter.Type orelse 0) != 0) hash.update(ast_utils.getText(tree, parameter.Type.?));
            }
            if ((node.Type orelse 0) != 0) hash.update(ast_utils.getText(tree, node.Type.?));
        },
        .ClassDeclaration => |node| for (tree.getNodeList(node.Members)) |member| {
            const name = ast_utils.name(tree, member);
            if (name != 0) hash.update(ast_utils.getText(tree, name));
            const type_node = ast_utils.getTypeNode(tree, member);
            if (type_node != 0) hash.update(ast_utils.getText(tree, type_node));
        },
        .InterfaceDeclaration, .TypeAliasDeclaration => hash.update(ast_utils.getText(tree, declaration)),
        else => {},
    }
}

fn formatDiagnosticMessage(allocator: std.mem.Allocator, message: []const u8, args: []const []const u8) ![]u8 {
    if (args.len == 0) return allocator.dupe(u8, message);
    var result = std.ArrayListUnmanaged(u8).empty;
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < message.len) {
        if (message[i] == '{') {
            const start = i;
            i += 1;
            var num: usize = 0;
            var is_num = false;
            while (i < message.len and message[i] >= '0' and message[i] <= '9') {
                num = num * 10 + (message[i] - '0');
                is_num = true;
                i += 1;
            }
            if (is_num and i < message.len and message[i] == '}') {
                if (num < args.len) {
                    try result.appendSlice(allocator, args[num]);
                } else {
                    try result.appendSlice(allocator, message[start .. i + 1]);
                }
                i += 1;
                continue;
            }
            i = start;
        }
        try result.append(allocator, message[i]);
        i += 1;
    }
    return result.toOwnedSlice(allocator);
}

test "program loads and binds a multi-file graph" {
    var threaded = std.Io.Threaded.init(std.testing.allocator, .{});
    defer threaded.deinit();
    const root = "zig-cache-program-graph-test";
    defer std.Io.Dir.cwd().deleteTree(threaded.io(), root) catch {};
    try std.Io.Dir.cwd().createDirPath(threaded.io(), root);
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/a.ts", .data = "import { b } from './b'; export const a = b;" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/b.ts", .data = "export const b = 1;" });
    var roots = [_][]const u8{root ++ "/a.ts"};
    var program = Program.init(std.testing.allocator, .{ .options = .{}, .rootNames = &roots });
    defer program.deinit();
    try program.load(threaded.io());
    try std.testing.expectEqual(@as(usize, 2), program.fileCount());
    try program.bind();
    try program.link();
    try std.testing.expect(program.getUnit(0).dependencies.items[0].resolved != null);
    const resolved = program.resolveAlias(0, "b") orelse return error.ExpectedResolvedAlias;
    try std.testing.expect(resolved.meaning.value);
}

test "program resolves rootDirs and moduleSuffixes" {
    var threaded = std.Io.Threaded.init(std.testing.allocator, .{});
    defer threaded.deinit();
    const root = "zig-cache-program-rootdirs-test";
    defer std.Io.Dir.cwd().deleteTree(threaded.io(), root) catch {};
    try std.Io.Dir.cwd().createDirPath(threaded.io(), root ++ "/src");
    try std.Io.Dir.cwd().createDirPath(threaded.io(), root ++ "/generated");
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/src/a.ts", .data = "import { b } from './b'; import { platform } from './platform'; export { b, platform };" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/generated/b.ts", .data = "export const b = 1;" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/src/platform.native.ts", .data = "export const platform = 'native';" });
    const source_root = try std.fs.path.resolve(std.testing.allocator, &.{root ++ "/src"});
    defer std.testing.allocator.free(source_root);
    const generated_root = try std.fs.path.resolve(std.testing.allocator, &.{root ++ "/generated"});
    defer std.testing.allocator.free(generated_root);
    var root_dirs = [_][]const u8{ source_root, generated_root };
    var suffixes = [_][]const u8{ ".native", "" };
    var roots = [_][]const u8{root ++ "/src/a.ts"};
    var program = Program.init(std.testing.allocator, .{ .options = .{ .rootDirs = &root_dirs, .moduleSuffixes = &suffixes }, .rootNames = &roots });
    defer program.deinit();
    try program.load(threaded.io());
    try std.testing.expectEqual(@as(usize, 3), program.fileCount());
    try std.testing.expect(program.getUnit(0).dependencies.items[0].resolved != null);
    try std.testing.expect(program.getUnit(0).dependencies.items[1].resolved != null);
}

test "program loads configured type packages from typeRoots" {
    var threaded = std.Io.Threaded.init(std.testing.allocator, .{});
    defer threaded.deinit();
    const root = "zig-cache-program-types-test";
    defer std.Io.Dir.cwd().deleteTree(threaded.io(), root) catch {};
    try std.Io.Dir.cwd().createDirPath(threaded.io(), root ++ "/types/example");
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/main.ts", .data = "export const value = 1;" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/types/example/index.d.ts", .data = "declare const exampleGlobal: string;" });
    const type_root = try std.fs.path.resolve(std.testing.allocator, &.{root ++ "/types"});
    defer std.testing.allocator.free(type_root);
    var type_roots = [_][]const u8{type_root};
    var types = [_][]const u8{"example"};
    var roots = [_][]const u8{root ++ "/main.ts"};
    var program = Program.init(std.testing.allocator, .{ .options = .{ .typeRoots = &type_roots, .types = &types }, .rootNames = &roots });
    defer program.deinit();
    try program.load(threaded.io());
    try std.testing.expectEqual(@as(usize, 2), program.fileCount());
}

test "program expands wildcard types and skips not-needed packages" {
    var threaded = std.Io.Threaded.init(std.testing.allocator, .{});
    defer threaded.deinit();
    const root = "zig-cache-program-wildcard-types-test";
    defer std.Io.Dir.cwd().deleteTree(threaded.io(), root) catch {};
    try std.Io.Dir.cwd().createDirPath(threaded.io(), root ++ "/types/alpha");
    try std.Io.Dir.cwd().createDirPath(threaded.io(), root ++ "/types/not-needed");
    try std.Io.Dir.cwd().createDirPath(threaded.io(), root ++ "/types/.ignored");
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/main.ts", .data = "export const value = alpha;" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/types/alpha/index.d.ts", .data = "declare const alpha: string;" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/types/not-needed/package.json", .data = "{\"typings\":null}" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/types/not-needed/index.d.ts", .data = "declare const skipped: string;" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/types/.ignored/index.d.ts", .data = "declare const ignored: string;" });
    const type_root = try std.fs.path.resolve(std.testing.allocator, &.{root ++ "/types"});
    defer std.testing.allocator.free(type_root);
    var type_roots = [_][]const u8{type_root};
    var types = [_][]const u8{"*"};
    var roots = [_][]const u8{root ++ "/main.ts"};
    var program = Program.init(std.testing.allocator, .{ .options = .{ .typeRoots = &type_roots, .types = &types }, .rootNames = &roots });
    defer program.deinit();
    try program.load(threaded.io());
    try std.testing.expectEqual(@as(usize, 2), program.fileCount());
    try std.testing.expect(std.mem.endsWith(u8, program.getUnit(1).path, "alpha/index.d.ts"));
}

test "program includes triple-slash path and type references in the graph" {
    var threaded = std.Io.Threaded.init(std.testing.allocator, .{});
    defer threaded.deinit();
    const root = "zig-cache-program-reference-directives-test";
    defer std.Io.Dir.cwd().deleteTree(threaded.io(), root) catch {};
    try std.Io.Dir.cwd().createDirPath(threaded.io(), root ++ "/types/example");
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/main.ts", .data = "/// <reference path=\"./globals.d.ts\" />\n/// <reference types=\"example\" />\nexport const value = globalValue;" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/globals.d.ts", .data = "declare const globalValue: string;" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/types/example/index.d.ts", .data = "declare const exampleValue: string;" });
    const type_root = try std.fs.path.resolve(std.testing.allocator, &.{root ++ "/types"});
    defer std.testing.allocator.free(type_root);
    var type_roots = [_][]const u8{type_root};
    var roots = [_][]const u8{root ++ "/main.ts"};
    var program = Program.init(std.testing.allocator, .{ .options = .{ .typeRoots = &type_roots }, .rootNames = &roots });
    defer program.deinit();
    try program.load(threaded.io());
    try std.testing.expectEqual(@as(usize, 3), program.fileCount());
    try std.testing.expectEqual(@as(usize, 2), program.getUnit(0).dependencies.items.len);
    try std.testing.expect(program.getUnit(0).dependencies.items[0].resolved != null);
    try std.testing.expect(program.getUnit(0).dependencies.items[1].resolved != null);
}

test "program reports unresolved module and reference directives" {
    var threaded = std.Io.Threaded.init(std.testing.allocator, .{});
    defer threaded.deinit();
    const root = "zig-cache-program-unresolved-test";
    defer std.Io.Dir.cwd().deleteTree(threaded.io(), root) catch {};
    try std.Io.Dir.cwd().createDirPath(threaded.io(), root);
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/main.ts", .data = "/// <reference path=\"./missing.d.ts\" />\n/// <reference types=\"missing-types\" />\nimport 'missing-package';" });
    var roots = [_][]const u8{root ++ "/main.ts"};
    var program = Program.init(std.testing.allocator, .{ .options = .{}, .rootNames = &roots, .projectName = root });
    defer program.deinit();
    try program.load(threaded.io());
    try std.testing.expectEqual(@as(usize, 3), program.diagnostics.items.len);
    try std.testing.expectEqual(@as(u32, 2307), program.diagnostics.items[0].code);
    try std.testing.expectEqual(@as(u32, 6053), program.diagnostics.items[1].code);
    try std.testing.expectEqual(@as(u32, 2688), program.diagnostics.items[2].code);
}

test "program resolves package imports wildcard with JavaScript extension substitution" {
    var threaded = std.Io.Threaded.init(std.testing.allocator, .{});
    defer threaded.deinit();
    const root = "zig-cache-program-package-imports-test";
    defer std.Io.Dir.cwd().deleteTree(threaded.io(), root) catch {};
    try std.Io.Dir.cwd().createDirPath(threaded.io(), root ++ "/src/features");
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/package.json", .data = "{\"name\":\"pkg\",\"type\":\"module\",\"imports\":{\"#/*\":\"./src/*\"}}" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/index.ts", .data = "import { foo } from '#/features/foo.js'; export { foo };" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/src/features/foo.ts", .data = "export const foo = 1;" });
    var roots = [_][]const u8{root ++ "/index.ts"};
    var program = Program.init(std.testing.allocator, .{ .options = .{ .moduleResolution = .NodeNext }, .rootNames = &roots });
    defer program.deinit();
    try program.load(threaded.io());
    try std.testing.expectEqual(@as(usize, 2), program.fileCount());
    try std.testing.expect(program.getUnit(0).dependencies.items[0].resolved != null);
    try std.testing.expectEqual(@as(usize, 1), program.resolution_cache.count());
}

test "program resolves package self-name exports using import and require conditions" {
    var threaded = std.Io.Threaded.init(std.testing.allocator, .{});
    defer threaded.deinit();
    const root = "zig-cache-program-self-name-test";
    defer std.Io.Dir.cwd().deleteTree(threaded.io(), root) catch {};
    try std.Io.Dir.cwd().createDirPath(threaded.io(), root ++ "/src");
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/package.json", .data = "{\"name\":\"pkg\",\"type\":\"module\",\"exports\":{\"./feature\":{\"import\":\"./src/feature.mts\",\"require\":\"./src/feature.cts\"}}}" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/main.mts", .data = "import { mode } from 'pkg/feature'; export { mode };" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/main.cts", .data = "import { mode } from 'pkg/feature'; export { mode };" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/main.ts", .data = "import { mode } from 'pkg/feature'; export { mode };" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/src/feature.mts", .data = "export const mode = 'import';" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/src/feature.cts", .data = "export const mode = 'require';" });
    var roots = [_][]const u8{ root ++ "/main.mts", root ++ "/main.cts", root ++ "/main.ts" };
    var program = Program.init(std.testing.allocator, .{ .options = .{ .moduleResolution = .NodeNext }, .rootNames = &roots });
    defer program.deinit();
    try program.load(threaded.io());
    try std.testing.expectEqual(@as(usize, 5), program.fileCount());
    const import_target = program.getUnit(0).dependencies.items[0].resolved orelse return error.ExpectedImportResolution;
    const require_target = program.getUnit(2).dependencies.items[0].resolved orelse return error.ExpectedRequireResolution;
    const package_module_target = program.getUnit(4).dependencies.items[0].resolved orelse return error.ExpectedPackageModuleResolution;
    try std.testing.expect(std.mem.endsWith(u8, program.getUnit(import_target).path, "feature.mts"));
    try std.testing.expect(std.mem.endsWith(u8, program.getUnit(require_target).path, "feature.cts"));
    try std.testing.expect(std.mem.endsWith(u8, program.getUnit(package_module_target).path, "feature.mts"));
}

test "program resolves matching package typesVersions paths" {
    var threaded = std.Io.Threaded.init(std.testing.allocator, .{});
    defer threaded.deinit();
    const root = "zig-cache-program-typesversions-test";
    defer std.Io.Dir.cwd().deleteTree(threaded.io(), root) catch {};
    try std.Io.Dir.cwd().createDirPath(threaded.io(), root ++ "/node_modules/pkg/ts7");
    try std.Io.Dir.cwd().createDirPath(threaded.io(), root ++ "/node_modules/pkg/legacy");
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/main.ts", .data = "import { feature } from 'pkg/feature'; export { feature };" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/node_modules/pkg/package.json", .data = "{\"name\":\"pkg\",\"version\":\"1.0.0\",\"typesVersions\":{\">=7.0\":{\"*\":[\"ts7/*\"]},\"*\":{\"*\":[\"legacy/*\"]}}}" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/node_modules/pkg/ts7/feature.d.ts", .data = "export declare const feature: 'ts7';" });
    try std.Io.Dir.cwd().writeFile(threaded.io(), .{ .sub_path = root ++ "/node_modules/pkg/legacy/feature.d.ts", .data = "export declare const feature: 'legacy';" });
    var roots = [_][]const u8{root ++ "/main.ts"};
    var program = Program.init(std.testing.allocator, .{ .options = .{ .moduleResolution = .NodeJs }, .rootNames = &roots, .projectName = root });
    defer program.deinit();
    try program.load(threaded.io());
    try std.testing.expectEqual(@as(usize, 2), program.fileCount());
    const target = program.getUnit(0).dependencies.items[0].resolved orelse return error.ExpectedTypesVersionsResolution;
    try std.testing.expect(std.mem.endsWith(u8, program.getUnit(target).path, "ts7/feature.d.ts"));
    const package_id = program.getUnit(target).package_id orelse return error.ExpectedPackageIdentity;
    try std.testing.expectEqualStrings("pkg", package_id.name);
    try std.testing.expectEqualStrings("1.0.0", package_id.version);
    try std.testing.expectEqualStrings("ts7/feature", package_id.sub_module_name);
}
