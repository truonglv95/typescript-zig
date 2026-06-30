const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const parser = @import("../parser/parser.zig");
const binder = @import("../binder/binder.zig");
const checker = @import("../checker/checker.zig");
const core = @import("../core/core.zig");

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
};

pub const ProgramDiagnostic = struct {
    file: FileId,
    code: u32,
    message: []const u8,
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
    diagnostics: std.ArrayList(ProgramDiagnostic) = .empty,
    public_types: std.StringHashMap(SemanticType),

    pub fn init(allocator: std.mem.Allocator, opts: ProgramOptions) Program {
        return .{
            .allocator = allocator,
            .opts = opts,
            .files_by_path = std.StringHashMap(FileId).init(allocator),
            .loading = std.StringHashMap(void).init(allocator),
            .exports_by_key = std.StringHashMap(ExportedSymbol).init(allocator),
            .aliases_by_key = std.StringHashMap(AliasSymbol).init(allocator),
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
        for (self.diagnostics.items) |diagnostic| self.allocator.free(diagnostic.message);
        self.diagnostics.deinit(self.allocator);
        freeMapKeys(self.allocator, &self.public_types);
        self.public_types.deinit();
    }

    pub fn load(self: *Program, io: std.Io) !void {
        for (self.opts.rootNames) |root| _ = try self.loadFile(io, root, true);
        try self.loadDefaultLibraries(io);
        try self.loadConfiguredTypes(io);
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
            if (try self.resolveTypeReference(io, type_name)) |path| {
                _ = try self.loadFile(io, path, false);
                self.allocator.free(path);
            }
        }
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
        const parser_instance = try self.allocator.create(parser.Parser);
        parser_instance.* = parser.Parser.init(self.allocator, content);
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
        };
        const id: FileId = @intCast(self.units.items.len);
        try self.units.append(self.allocator, unit);
        try self.files_by_path.put(unit.path, id);

        try self.collectDependencies(io, id);
        return id;
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
            if (specifier.len > 0 and (specifier[0] == '.' or specifier[0] == '/')) {
                if (try self.resolveRelative(io, unit.path, specifier)) |path| {
                    resolved = try self.loadFile(io, path, false);
                    self.allocator.free(path);
                }
            } else if (try self.resolveMapped(io, specifier)) |path| {
                resolved = try self.loadFile(io, path, false);
                self.allocator.free(path);
            } else if (try self.resolvePackageImport(io, unit.path, specifier)) |path| {
                resolved = try self.loadFile(io, path, false);
                self.allocator.free(path);
            } else if (try self.resolveBare(io, unit.path, specifier)) |path| {
                resolved = try self.loadFile(io, path, false);
                self.allocator.free(path);
            }
            try unit.dependencies.append(self.allocator, .{ .specifier = owned_specifier, .resolved = resolved });
        }
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
                        if (try self.resolvePackageMap(io, package_root, exports, export_key)) |resolved| return resolved;
                        if (self.opts.options.resolvePackageJsonExports orelse true) return null;
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
            const parent = std.fs.path.dirname(directory) orelse break;
            if (std.mem.eql(u8, parent, directory)) break;
            directory = parent;
        }
        return null;
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
                        if (try self.resolvePackageMap(io, directory, imports, specifier)) |resolved| return resolved;
                    };
                } else |_| {}
            }
            const parent = std.fs.path.dirname(directory) orelse break;
            if (std.mem.eql(u8, parent, directory)) break;
            directory = parent;
        }
        return null;
    }

    fn resolvePackageMap(self: *Program, io: std.Io, package_root: []const u8, map: std.json.Value, requested_key: []const u8) !?[]const u8 {
        if (map == .string or map == .array) return self.resolvePackageTarget(io, package_root, map, "");
        if (map != .object) return null;
        if (map.object.get(requested_key)) |target| return self.resolvePackageTarget(io, package_root, target, "");
        var iterator = map.object.iterator();
        while (iterator.next()) |entry| {
            const star = std.mem.indexOfScalar(u8, entry.key_ptr.*, '*') orelse continue;
            const prefix = entry.key_ptr.*[0..star];
            const suffix = entry.key_ptr.*[star + 1 ..];
            if (!std.mem.startsWith(u8, requested_key, prefix) or !std.mem.endsWith(u8, requested_key, suffix) or requested_key.len < prefix.len + suffix.len) continue;
            const capture = requested_key[prefix.len .. requested_key.len - suffix.len];
            if (try self.resolvePackageTarget(io, package_root, entry.value_ptr.*, capture)) |resolved| return resolved;
        }
        // A condition object at the root (for the "." export).
        if (std.mem.eql(u8, requested_key, ".")) return self.resolvePackageTarget(io, package_root, map, "");
        return null;
    }

    fn resolvePackageTarget(self: *Program, io: std.Io, package_root: []const u8, target: std.json.Value, capture: []const u8) !?[]const u8 {
        switch (target) {
            .string => |text| {
                const replaced = if (std.mem.indexOfScalar(u8, text, '*')) |star| try std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{ text[0..star], capture, text[star + 1 ..] }) else try self.allocator.dupe(u8, text);
                defer self.allocator.free(replaced);
                const requested = try std.fs.path.join(self.allocator, &.{ package_root, replaced });
                defer self.allocator.free(requested);
                return self.resolvePathCandidate(io, requested);
            },
            .array => |items| {
                for (items.items) |item| if (try self.resolvePackageTarget(io, package_root, item, capture)) |resolved| return resolved;
            },
            .object => |conditions| {
                const preferred = [_][]const u8{ "types", "import", "require", "node", "default" };
                for (preferred) |condition| if (conditions.get(condition)) |value| if (try self.resolvePackageTarget(io, package_root, value, capture)) |resolved| return resolved;
                for (self.opts.options.customConditions orelse &.{}) |condition| if (conditions.get(condition)) |value| if (try self.resolvePackageTarget(io, package_root, value, capture)) |resolved| return resolved;
            },
            else => {},
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
            const target = dependencyTarget(unit, ast_utils.getText(tree, declaration.ModuleSpecifier)) orelse continue;
            const clause_index = declaration.ImportClause orelse continue;
            const clause = tree.getNode(clause_index).ImportClause;
            if ((clause.name orelse 0) != 0) try self.putAlias(file, ast_utils.getText(tree, clause.name.?), target, "default");
            if ((clause.NamedBindings orelse 0) == 0) continue;
            switch (tree.getNode(clause.NamedBindings.?)) {
                .NamespaceImport => |namespace| try self.putAlias(file, ast_utils.getText(tree, namespace.name), target, "*"),
                .NamedImports => |named| for (tree.getNodeList(named.Elements)) |element| {
                    const specifier = tree.getNode(element).ImportSpecifier;
                    try self.putAlias(file, ast_utils.getText(tree, specifier.name), target, ast_utils.getText(tree, specifier.PropertyName orelse specifier.name));
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

    fn putAlias(self: *Program, file: FileId, local_name: []const u8, target_file: FileId, imported_name: []const u8) !void {
        const key = try symbolKey(self.allocator, file, local_name);
        if (self.aliases_by_key.contains(key)) {
            self.allocator.free(key);
            return;
        }
        try self.aliases_by_key.put(key, .{ .target_file = target_file, .imported_name = try self.allocator.dupe(u8, imported_name) });
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
        for (self.units.items, 0..) |unit, file_index| {
            if (unit.is_default_library) continue;
            const bound = unit.binder_instance orelse continue;
            var instance = checker.Checker.init(self.allocator, bound);
            defer instance.deinit();
            try instance.checkStatement(unit.source_file);
            for (bound.diagnosticsList.items) |diagnostic| {
                // The minimal cross-file pass below emits a concrete TS2322
                // message; avoid also exposing the checker's unformatted
                // placeholder form for the same assignment.
                if (diagnostic.message.code == 2322) continue;
                try self.diagnostics.append(self.allocator, .{
                    .file = @intCast(file_index),
                    .code = diagnostic.message.code,
                    .message = try self.allocator.dupe(u8, diagnostic.message.text),
                });
            }
        }
        var aliases = self.aliases_by_key.iterator();
        while (aliases.next()) |entry| {
            const alias = entry.value_ptr.*;
            if (std.mem.eql(u8, alias.imported_name, "*")) continue;
            const target_key = try symbolKey(self.allocator, alias.target_file, alias.imported_name);
            defer self.allocator.free(target_key);
            if (!self.exports_by_key.contains(target_key)) {
                const separator = std.mem.indexOfScalar(u8, entry.key_ptr.*, ':') orelse 0;
                const file = std.fmt.parseInt(FileId, entry.key_ptr.*[0..separator], 10) catch 0;
                try self.diagnostics.append(self.allocator, .{
                    .file = file,
                    .code = 2305,
                    .message = try std.fmt.allocPrint(self.allocator, "Module has no exported member '{s}'.", .{alias.imported_name}),
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
        for (self.units.items, 0..) |unit, file_index| if (!unit.is_default_library) try self.checkTopLevelAssignments(@intCast(file_index), unit);
    }

    fn checkTopLevelAssignments(self: *Program, file: FileId, unit: *SourceUnit) !void {
        const tree = unit.tree();
        const source = tree.getNode(unit.source_file).SourceFile;
        for (tree.getNodeList(source.Statements)) |statement| {
            if (tree.getNode(statement) != .VariableStatement) continue;
            const list = tree.getNode(tree.getNode(statement).VariableStatement.DeclarationList).VariableDeclarationList;
            for (tree.getNodeList(list.Declarations)) |declaration_index| {
                const declaration = tree.getNode(declaration_index).VariableDeclaration;
                if ((declaration.Type orelse 0) == 0 or (declaration.Initializer orelse 0) == 0) continue;
                const expected = semanticTypeOfTypeNode(tree, declaration.Type.?);
                const actual = inferExpressionType(tree, declaration.Initializer.?);
                if (!isAssignable(actual, expected)) try self.diagnostics.append(self.allocator, .{
                    .file = file,
                    .code = 2322,
                    .message = try std.fmt.allocPrint(self.allocator, "Type '{s}' is not assignable to type '{s}'.", .{ @tagName(actual), @tagName(expected) }),
                });
            }
        }
    }

    pub fn getPublicType(self: *Program, file: FileId, name: []const u8) ?SemanticType {
        const key = symbolKey(self.allocator, file, name) catch return null;
        defer self.allocator.free(key);
        return self.public_types.get(key);
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
        .ExportDeclaration => |declaration| declaration.ModuleSpecifier orelse 0,
        .ImportEqualsDeclaration => |declaration| switch (tree.getNode(declaration.ModuleReference)) {
            .ExternalModuleReference => |reference| reference.Expression,
            else => 0,
        },
        .ModuleDeclaration => |declaration| if (tree.getNode(declaration.name) == .StringLiteral) declaration.name else 0,
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
    file.close(io);
    return true;
}

fn isPathInside(path: []const u8, directory: []const u8) bool {
    if (!std.mem.startsWith(u8, path, directory)) return false;
    return path.len == directory.len or directory.len > 0 and (directory[directory.len - 1] == std.fs.path.sep or path[directory.len] == std.fs.path.sep);
}

fn isJsxPath(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".tsx") or std.mem.endsWith(u8, path, ".jsx");
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
