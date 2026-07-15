const std = @import("std");
const ast = @import("../../ast/ast.zig");
const collections = @import("../../collections/collections.zig");
const compiler = @import("../../compiler/compiler.zig");
const core = @import("../../core/core.zig");
const lsutil = @import("../lsutil.zig");
const lsproto = @import("../../lsp/lsproto.zig");
const module = @import("../../module/module.zig");
const modulespecifiers = @import("../../modulespecifiers/modulespecifiers.zig");
const scanner = @import("../../scanner/scanner.zig");
const tspath = @import("../../tspath/tspath.zig");

const autoimport = @import("autoimport.zig");
const Registry = autoimport.registry.Registry;
const RegistryBucket = autoimport.registry.RegistryBucket;
const Export = autoimport.export_module.Export;
const ExportIndex = autoimport.export_module.ExportIndex;
const ExportID = autoimport.export_module.ExportID;
const ModuleID = autoimport.export_module.ModuleID;
const existingImport = autoimport.export_module.existingImport;
const FixIndex = autoimport.fix.FixIndex;

pub const View = struct {
    allocator: std.mem.Allocator,
    registry: *Registry,
    importingFile: ast.NodeIndex,
    program: *compiler.Program,
    preferences: modulespecifiers.UserPreferences,
    projectKey: tspath.Path,

    allowedEndings: ?[]modulespecifiers.ModuleSpecifierEnding = null,
    conditions: *collections.Set([]const u8) = undefined,
    shouldUseUriStyleNodeCoreModules: core.Tristate = .Unknown,
    existingImports: ?*collections.MultiMap(ModuleID, existingImport) = null,
    shouldUseRequireForFixes: ?bool = null,

    pub fn init(
        allocator: std.mem.Allocator,
        registry: *Registry,
        importingFile: ast.NodeIndex,
        projectKey: tspath.Path,
        program: *compiler.Program,
        preferences: modulespecifiers.UserPreferences,
    ) *View {
        const v = allocator.create(View) catch @panic("OOM");

        const conditions_items = module.getConditions(
            allocator,
            program.options(),
            program.getDefaultResolutionModeForFile(importingFile),
        );
        const conditions = collections.Set([]const u8).initFromItems(allocator, conditions_items);

        v.* = View{
            .allocator = allocator,
            .registry = registry,
            .importingFile = importingFile,
            .program = program,
            .projectKey = projectKey,
            .preferences = preferences,
            .conditions = conditions,
            .shouldUseUriStyleNodeCoreModules = lsutil.shouldUseUriStyleNodeCoreModules(importingFile, program),
        };
        return v;
    }

    pub fn getAllowedEndings(self: *View) []modulespecifiers.ModuleSpecifierEnding {
        if (self.allowedEndings) |endings| {
            return endings;
        }
        const resolutionMode = self.program.getDefaultResolutionModeForFile(self.importingFile);
        self.allowedEndings = modulespecifiers.getAllowedEndingsInPreferredOrder(
            self.allocator,
            self.preferences,
            self.program,
            self.program.options(),
            self.importingFile,
            "",
            resolutionMode,
        );
        return self.allowedEndings.?;
    }

    pub const QueryKind = enum {
        WordPrefix,
        ExactMatch,
        CaseInsensitiveMatch,
    };

    pub fn search(self: *View, query: []const u8, kind: QueryKind) []ExportIndex {
        const SearchFn = struct {
            kind: QueryKind,
            query: []const u8,
            pub fn call(ctx: @This(), bucket: *RegistryBucket) []ExportIndex {
                switch (ctx.kind) {
                    .WordPrefix => return bucket.index.searchWordPrefix(ctx.query),
                    .ExactMatch => return bucket.index.find(ctx.query, true),
                    .CaseInsensitiveMatch => return bucket.index.find(ctx.query, false),
                }
            }
        };
        const searchFn = SearchFn{ .kind = kind, .query = query };
        return self.searchInternal(SearchFn, searchFn);
    }

    pub fn searchByExportID(self: *View, id: ExportID) []ExportIndex {
        const SearchFn = struct {
            id: ExportID,
            allocator: std.mem.Allocator,
            registry: *Registry,
            pub fn call(ctx: @This(), bucket: *RegistryBucket) []ExportIndex {
                var results = std.ArrayList(ExportIndex).init(ctx.allocator);
                for (bucket.index.entries) |e_idx| {
                    const e = ctx.registry.getExport(e_idx);
                    if (e.exportID == ctx.id) {
                        results.append(e_idx) catch @panic("OOM");
                    }
                }
                return results.toOwnedSlice() catch @panic("OOM");
            }
        };
        const searchFn = SearchFn{ .id = id, .allocator = self.allocator };
        return self.searchInternal(SearchFn, searchFn);
    }

    fn searchInternal(self: *View, comptime Context: type, searchFn: Context) []ExportIndex {
        var results = std.ArrayList(ExportIndex).init(self.allocator);

        if (self.registry.projects.get(self.projectKey)) |bucket| {
            const exports = searchFn.call(bucket);
            results.ensureUnusedCapacity(exports.len) catch @panic("OOM");
            for (exports) |e_idx| {
                const e = self.registry.getExport(e_idx);
                if (std.mem.eql(u8, e.moduleID, self.importingFile.path())) {
                    // Don't auto-import from the importing file itself
                    continue;
                }
                results.appendAssumeCapacity(e_idx);
            }
        }

        var allowedPackages: ?*collections.Set([]const u8) = null;

        const AncestorContext1 = struct {
            registry: *Registry,
            allowedPackages: *?*collections.Set([]const u8),
            allocator: std.mem.Allocator,
            pub fn call(ctx: @This(), dirPath: tspath.Path) bool {
                if (ctx.registry.directories.get(dirPath)) |dir| {
                    const pj = dir.packageJson;
                    if (pj.exists() and pj.contents.parseable) {
                        if (ctx.allowedPackages.* == null) {
                            const new_set = ctx.allocator.create(collections.Set([]const u8)) catch @panic("OOM");
                            new_set.* = collections.Set([]const u8).init(ctx.allocator);
                            ctx.allowedPackages.* = new_set;
                        }
                        autoimport.util.addPackageJsonDependencies(pj.contents, ctx.allowedPackages.*.?);
                    }
                }
                return false;
            }
        };

        tspath.forEachAncestorDirectoryPath(
            self.importingFile.path().getDirectoryPath(),
            AncestorContext1{
                .registry = self.registry,
                .allowedPackages = &allowedPackages,
                .allocator = self.allocator,
            },
        );

        if (allowedPackages) |pkgs| {
            if (self.registry.projects.get(self.projectKey)) |bucket| {
                pkgs.* = pkgs.unionedWith(bucket.resolvedPackageNames);
            }
        }

        var excludePackages = collections.Set([]const u8).init(self.allocator);

        const AncestorContext2 = struct {
            registry: *Registry,
            results: *std.ArrayList(ExportIndex),
            excludePackages: *collections.Set([]const u8),
            allowedPackages: ?*collections.Set([]const u8),
            searchFnCtx: Context,
            allocator: std.mem.Allocator,

            pub fn call(ctx: @This(), dirPath: tspath.Path) bool {
                if (ctx.registry.nodeModules.get(dirPath)) |nodeModulesBucket| {
                    const exports = ctx.searchFnCtx.call(nodeModulesBucket);
                    ctx.results.ensureUnusedCapacity(exports.len) catch @panic("OOM");
                    for (exports) |e_idx| {
                        const e = ctx.registry.getExport(e_idx);
                        if (ctx.excludePackages.has(e.packageName)) {
                            continue;
                        }
                        if (ctx.allowedPackages) |allowed| {
                            if (!allowed.has(e.packageName)) {
                                continue;
                            }
                        }
                        ctx.results.appendAssumeCapacity(e_idx);
                    }

                    var it = nodeModulesBucket.packageFiles.keyIterator();
                    while (it.next()) |pkgName| {
                        ctx.excludePackages.add(pkgName.*);
                    }
                }
                return false;
            }
        };

        tspath.forEachAncestorDirectoryPath(
            self.importingFile.path().getDirectoryPath(),
            AncestorContext2{
                .registry = self.registry,
                .results = &results,
                .excludePackages = &excludePackages,
                .allowedPackages = allowedPackages,
                .searchFnCtx = searchFn,
                .allocator = self.allocator,
            },
        );

        return results.toOwnedSlice() catch @panic("OOM");
    }

    pub const FixAndExport = struct {
        fix: FixIndex,
        export_idx: ExportIndex,
    };

    pub fn getCompletions(
        self: *View,
        prefix: []const u8,
        position: lsproto.Position,
        forJSX: bool,
        isTypeOnlyLocation: bool,
    ) []FixAndExport {
        const results = self.search(prefix, .WordPrefix);

        const ExportGroupKey = struct {
            target: ExportID,
            name: []const u8,
            ambientModuleOrPackageName: []const u8,
        };

        var grouped = std.AutoHashMap(ExportGroupKey, std.ArrayList(ExportIndex)).init(self.allocator);

        outer: for (results) |e_idx| {
            const e = self.registry.getExport(e_idx);
            const name = e.name();
            if (!scanner.isIdentifierText(name, core.LanguageVariant.standard)) {
                continue;
            }
            if (forJSX and !(std.ascii.isUpper(name[0]) or e.isRenameable())) {
                continue;
            }
            var target = e.exportID;
            if (e.target != 0) {
                target = e.target;
            }

            const ambient = core.firstNonZero(e.ambientModuleName(), e.packageName);
            var key = ExportGroupKey{
                .target = target,
                .name = name,
                .ambientModuleOrPackageName = ambient,
            };

            if (std.mem.eql(u8, e.packageName, "@types/node") or std.mem.indexOf(u8, e.path, "/node_modules/@types/node/") != null) {
                if (core.unprefixedNodeCoreModules.has(key.ambientModuleOrPackageName)) {
                    key.ambientModuleOrPackageName = std.fmt.allocPrint(self.allocator, "node:{s}", .{key.ambientModuleOrPackageName}) catch @panic("OOM");
                }
            }

            if (grouped.getPtr(key)) |existing| {
                for (existing.items, 0..) |ex_idx, i| {
                    const ex = self.registry.getExport(ex_idx);
                    if (e.exportID == ex.exportID) {
                        const new_export_idx = self.registry.createMergedExport(e_idx, ex_idx);
                        existing.items[i] = new_export_idx;
                        continue :outer;
                    }
                }
                existing.append(e_idx) catch @panic("OOM");
            } else {
                var list = std.ArrayList(ExportIndex).init(self.allocator);
                list.append(e_idx) catch @panic("OOM");
                grouped.put(key, list) catch @panic("OOM");
            }
        }

        var fixes = std.ArrayList(FixAndExport).init(self.allocator);

        var it = grouped.iterator();
        while (it.next()) |entry| {
            const exps = entry.value_ptr.items;
            var fixesForGroup = std.ArrayList(FixAndExport).init(self.allocator);

            for (exps) |e_idx| {
                const e_fixes = self.getFixes(e_idx, forJSX, isTypeOnlyLocation, position);
                for (e_fixes) |fix_idx| {
                    fixesForGroup.append(FixAndExport{
                        .fix = fix_idx,
                        .export_idx = e_idx,
                    }) catch @panic("OOM");
                }
            }
            if (fixesForGroup.items.len > 0) {
                const Context = struct {
                    view: *View,
                    pub fn call(ctx: @This(), a: FixAndExport, b: FixAndExport) std.math.Order {
                        return ctx.view.compareFixesForRanking(a.fix, b.fix);
                    }
                };
                const best = core.minAllFunc(FixAndExport, fixesForGroup.items, Context{ .view = self }, self.allocator);
                fixes.appendSlice(best) catch @panic("OOM");
            }
        }

        std.mem.sort(FixAndExport, fixes.items, self, struct {
            pub fn lessThan(ctx: *View, a: FixAndExport, b: FixAndExport) bool {
                return ctx.compareFixesForSorting(a.fix, b.fix) == .lt;
            }
        }.lessThan);

        return fixes.toOwnedSlice() catch @panic("OOM");
    }

    pub fn getFixes(self: *View, e_idx: ExportIndex, forJSX: bool, isTypeOnlyLocation: bool, position: lsproto.Position) []FixIndex {
        _ = self;
        _ = e_idx;
        _ = forJSX;
        _ = isTypeOnlyLocation;
        _ = position;
        return &[_]FixIndex{};
    }

    pub fn compareFixesForRanking(self: *View, a: FixIndex, b: FixIndex) std.math.Order {
        _ = self;
        _ = a;
        _ = b;
        return .eq;
    }

    pub fn compareFixesForSorting(self: *View, a: FixIndex, b: FixIndex) std.math.Order {
        _ = self;
        _ = a;
        _ = b;
        return .eq;
    }
};
