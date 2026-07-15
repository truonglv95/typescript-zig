const std = @import("std");

const ast = @import("../../ast/ast.zig");
const checker_module = @import("../../checker/checker.zig");
const Checker = checker_module.Checker;
const compiler = @import("../../compiler/compiler.zig");
const core = @import("../../core/core.zig");
const debug = @import("../../debug/debug.zig");
const locale = @import("../../locale/locale.zig");
const nodebuilder = @import("../../nodebuilder/nodebuilder.zig");

const change = @import("../change/change.zig");
const Tracker = change.Tracker;
const lsconv = @import("../lsconv/lsconv.zig");
const lsutil = @import("../lsutil/lsutil.zig");
const lsproto = @import("../../lsp/lsproto/lsproto.zig");

const autoimport = @import("autoimport.zig");
const Fix = autoimport.fix.Fix;
const getAddToExistingImportFix = autoimport.fix.getAddToExistingImportFix;
const addNamespaceQualifier = autoimport.fix.addNamespaceQualifier;
const addImportType = autoimport.fix.addImportType;
const addToExistingImport = autoimport.fix.addToExistingImport;
const getNewRequires = autoimport.fix.getNewRequires;
const getNewImports = autoimport.fix.getNewImports;
const insertImports = autoimport.fix.insertImports;
const NewImportBinding = autoimport.fix.NewImportBinding;
const Export = autoimport.export_module.Export;
const SymbolToExport = autoimport.export_module.SymbolToExport;
const View = autoimport.view.View;

pub const ImportAdder = struct {
    arena: std.mem.Allocator,

    checker: *Checker,
    view: *View,
    format_options: lsutil.FormatCodeSettings,
    converters: *lsconv.Converters,
    preferences: lsutil.UserPreferences,

    add_to_namespace: std.ArrayListUnmanaged(*Fix) = .empty,
    import_type: std.ArrayListUnmanaged(*Fix) = .empty,
    add_to_existing: std.AutoHashMapUnmanaged(ast.NodeIndex, *AddToExistingState) = .empty,
    new_imports: std.StringHashMapUnmanaged(*ImportsCollection) = .empty,

    pub fn init(
        arena: std.mem.Allocator,
        // ctx
        _program: *compiler.Program,
        checker: *Checker,
        _file: ast.NodeIndex, // source_file
        view: *View,
        format_options: lsutil.FormatCodeSettings,
        converters: *lsconv.Converters,
        preferences: lsutil.UserPreferences,
    ) ImportAdder {
        _ = _program;
        _ = _file;
        return ImportAdder{
            .arena = arena,
            .checker = checker,
            .view = view,
            .format_options = format_options,
            .converters = converters,
            .preferences = preferences,
        };
    }

    pub fn hasFixes(self: *ImportAdder) bool {
        return self.add_to_namespace.items.len > 0 or
            self.import_type.items.len > 0 or
            self.add_to_existing.count() > 0 or
            self.new_imports.count() > 0;
    }

    pub fn addImportFromExportedSymbol(self: *ImportAdder, exported_symbol: ast.SymbolIndex, is_valid_type_only_use_site: bool) void {
        const symbol = self.checker.getMergedSymbol(self.checker.skipAlias(exported_symbol));
        const export_infos = self.getAllExportsForSymbol(symbol);
        if (export_infos.len == 0) {
            return;
        }
        const fix = self.getImportFixForSymbol(self.view, self.view.importing_file, export_infos, is_valid_type_only_use_site);
        if (fix) |f| {
            self.addImportFix(f);
        }
    }

    pub fn edits(self: *ImportAdder) []*lsproto.TextEdit {
        var tracker = Tracker.init(self.arena, self.view.program.options, self.format_options, self.converters);
        const quote_preference = lsutil.getQuotePreference(self.view.importing_file, self.preferences);

        for (self.add_to_namespace.items) |fix| {
            _ = addNamespaceQualifier(fix, &tracker, self.view.importing_file, locale.default);
        }
        for (self.import_type.items) |fix| {
            _ = addImportType(fix, self.view.importing_file, self.preferences, &tracker, locale.default);
        }

        var it = self.add_to_existing.iterator();
        while (it.next()) |entry| {
            const clause_or_pattern = entry.key_ptr.*;
            const state = entry.value_ptr.*;
            addToExistingImport(
                &tracker,
                self.view.importing_file,
                clause_or_pattern,
                state.default_import,
                sortedNamedImports(self.arena, state.named_imports),
                self.preferences,
            );
        }

        var new_declarations = std.ArrayList(ast.NodeIndex).init(self.arena);
        var new_imports_it = self.new_imports.iterator();
        while (new_imports_it.next()) |entry| {
            const key = entry.key_ptr.*;
            const new_import = entry.value_ptr.*;
            const module_specifier = key[2..]; // from "0|module" format
            
            var declarations: []ast.NodeIndex = undefined;
            if (new_import.use_require) {
                declarations = getNewRequires(
                    &tracker,
                    module_specifier,
                    quote_preference,
                    new_import.default_import,
                    sortedNamedImports(self.arena, new_import.named_imports),
                    new_import.namespace_like_import,
                    self.view.program.options,
                );
            } else {
                declarations = getNewImports(
                    &tracker,
                    module_specifier,
                    quote_preference,
                    new_import.default_import,
                    sortedNamedImports(self.arena, new_import.named_imports),
                    new_import.namespace_like_import,
                    self.view.program.options,
                    self.preferences,
                );
            }
            new_declarations.appendSlice(declarations) catch @panic("OOM");
        }

        if (new_declarations.items.len > 0) {
            insertImports(&tracker, self.view.importing_file, new_declarations.items, true, self.preferences);
        }

        const changes = tracker.getChanges();
        const filename = self.view.importing_file.fileName();
        if (changes.get(filename)) |edits_list| {
            return edits_list;
        }
        return &[_]*lsproto.TextEdit{};
    }

    pub fn addImportFix(self: *ImportAdder, fix: *Fix) void {
        const symbol_name = fix.name;
        const compiler_options = self.view.program.options;

        switch (fix.kind) {
            .use_namespace => {
                self.add_to_namespace.append(self.arena, fix) catch @panic("OOM");
            },
            .jsdoc_type_import => {
                self.import_type.append(self.arena, fix) catch @panic("OOM");
            },
            .add_to_existing => {
                const existing_fix = getAddToExistingImportFix(self.view.importing_file, fix);
                const entry_ptr = self.add_to_existing.getOrPut(self.arena, existing_fix.import_clause_or_binding_pattern) catch @panic("OOM");
                var entry: *AddToExistingState = undefined;
                if (!entry_ptr.found_existing) {
                    entry = self.arena.create(AddToExistingState) catch @panic("OOM");
                    entry.* = .{
                        .import_clause_or_binding_pattern = existing_fix.import_clause_or_binding_pattern,
                    };
                    entry_ptr.value_ptr.* = entry;
                } else {
                    entry = entry_ptr.value_ptr.*;
                }

                if (fix.import_kind == .named) {
                    var prev_type_only: lsproto.AddAsTypeOnly = .allowed;
                    if (entry.named_imports.get(symbol_name)) |prev_import| {
                        prev_type_only = prev_import.add_as_type_only;
                    }
                    const new_binding = self.arena.create(NewImportBinding) catch @panic("OOM");
                    new_binding.* = .{
                        .kind = .named,
                        .name = symbol_name,
                        .add_as_type_only = reduceAddAsTypeOnlyValues(prev_type_only, fix.add_as_type_only),
                        .property_name = existing_fix.named_import.property_name,
                    };
                    entry.named_imports.put(self.arena, symbol_name, new_binding) catch @panic("OOM");
                } else {
                    debug.assert(entry.default_import == null or std.mem.eql(u8, entry.default_import.?.name, symbol_name));
                    var prev_type_only: lsproto.AddAsTypeOnly = .allowed;
                    if (entry.default_import) |di| {
                        prev_type_only = di.add_as_type_only;
                    }
                    const new_binding = self.arena.create(NewImportBinding) catch @panic("OOM");
                    new_binding.* = .{
                        .kind = .default,
                        .name = symbol_name,
                        .add_as_type_only = reduceAddAsTypeOnlyValues(prev_type_only, fix.add_as_type_only),
                        .property_name = "",
                    };
                    entry.default_import = new_binding;
                }
            },
            .add_new => {
                const entry = self.getNewImportEntry(fix.module_specifier, fix.import_kind, fix.use_require, fix.add_as_type_only);
                debug.assert(entry.use_require == fix.use_require);

                switch (fix.import_kind) {
                    .default => {
                        debug.assert(entry.default_import == null or std.mem.eql(u8, entry.default_import.?.name, symbol_name));
                        var prev_type_only: lsproto.AddAsTypeOnly = .allowed;
                        if (entry.default_import) |di| {
                            prev_type_only = di.add_as_type_only;
                        }
                        const new_binding = self.arena.create(NewImportBinding) catch @panic("OOM");
                        new_binding.* = .{
                            .kind = .default,
                            .name = symbol_name,
                            .add_as_type_only = reduceAddAsTypeOnlyValues(prev_type_only, fix.add_as_type_only),
                            .property_name = "",
                        };
                        entry.default_import = new_binding;
                    },
                    .named => {
                        var prev_type_only: lsproto.AddAsTypeOnly = .allowed;
                        if (entry.named_imports.get(symbol_name)) |prev_import| {
                            prev_type_only = prev_import.add_as_type_only;
                        }
                        const new_binding = self.arena.create(NewImportBinding) catch @panic("OOM");
                        new_binding.* = .{
                            .kind = .named,
                            .name = symbol_name,
                            .add_as_type_only = reduceAddAsTypeOnlyValues(prev_type_only, fix.add_as_type_only),
                            .property_name = "",
                        };
                        entry.named_imports.put(self.arena, symbol_name, new_binding) catch @panic("OOM");
                    },
                    .common_js => {
                        if (compiler_options.verbatim_module_syntax == core.TSTrue) {
                            var prev_type_only: lsproto.AddAsTypeOnly = .allowed;
                            if (entry.named_imports.get(symbol_name)) |prev_import| {
                                prev_type_only = prev_import.add_as_type_only;
                            }
                            const new_binding = self.arena.create(NewImportBinding) catch @panic("OOM");
                            new_binding.* = .{
                                .kind = .common_js,
                                .name = symbol_name,
                                .add_as_type_only = reduceAddAsTypeOnlyValues(prev_type_only, fix.add_as_type_only),
                                .property_name = "",
                            };
                            entry.named_imports.put(self.arena, symbol_name, new_binding) catch @panic("OOM");
                        } else {
                            debug.assert(entry.namespace_like_import == null or std.mem.eql(u8, entry.namespace_like_import.?.name, symbol_name));
                            const new_binding = self.arena.create(NewImportBinding) catch @panic("OOM");
                            new_binding.* = .{
                                .kind = .common_js,
                                .name = symbol_name,
                                .add_as_type_only = fix.add_as_type_only,
                                .property_name = "",
                            };
                            entry.namespace_like_import = new_binding;
                        }
                    },
                    .namespace => {
                        debug.assert(entry.namespace_like_import == null or std.mem.eql(u8, entry.namespace_like_import.?.name, symbol_name));
                        const new_binding = self.arena.create(NewImportBinding) catch @panic("OOM");
                        new_binding.* = .{
                            .kind = .namespace,
                            .name = symbol_name,
                            .add_as_type_only = fix.add_as_type_only,
                            .property_name = "",
                        };
                        entry.namespace_like_import = new_binding;
                    },
                    else => {},
                }
            },
            .promote_type_only => {},
            else => {
                debug.fail("Unexpected fix kind", .{});
            },
        }
    }

    fn getNewImportEntry(self: *ImportAdder, module_specifier: []const u8, import_kind: lsproto.ImportKind, use_require: bool, add_as_type_only: lsproto.AddAsTypeOnly) *ImportsCollection {
        const type_only_key = newImportsKey(self.arena, module_specifier, true);
        const non_type_only_key = newImportsKey(self.arena, module_specifier, false);
        
        const type_only_entry = self.new_imports.get(type_only_key);
        const non_type_only_entry = self.new_imports.get(non_type_only_key);
        
        const new_entry = self.arena.create(ImportsCollection) catch @panic("OOM");
        new_entry.* = .{
            .use_require = use_require,
        };

        if (import_kind == .default and add_as_type_only == .required) {
            if (type_only_entry) |entry| {
                return entry;
            }
            self.new_imports.put(self.arena, type_only_key, new_entry) catch @panic("OOM");
            return new_entry;
        }

        if (add_as_type_only == .allowed and (type_only_entry != null or non_type_only_entry != null)) {
            if (type_only_entry) |entry| {
                return entry;
            }
            return non_type_only_entry.?;
        }

        if (non_type_only_entry) |entry| {
            return entry;
        }

        self.new_imports.put(self.arena, non_type_only_key, new_entry) catch @panic("OOM");
        return new_entry;
    }

    fn getAllExportsForSymbol(self: *ImportAdder, symbol: ast.SymbolIndex) []*Export {
        if (SymbolToExport(symbol, self.checker)) |export_info| {
            return self.view.searchByExportId(export_info.export_id);
        }
        return &[_]*Export{};
    }

    fn getImportFixForSymbol(self: *ImportAdder, view: *View, file: ast.NodeIndex, exports: []*Export, is_valid_type_only_use_site: bool) ?*Fix {
        _ = file;
        var fixes = std.ArrayList(*Fix).init(self.arena);
        for (exports) |export_info| {
            const export_fixes = view.getFixes(export_info, false, is_valid_type_only_use_site, null);
            fixes.appendSlice(export_fixes) catch @panic("OOM");
        }
        
        std.mem.sort(*Fix, fixes.items, view, View.compareFixesForRanking);
        if (fixes.items.len > 0) {
            return fixes.items[0];
        }
        return null;
    }
};

pub const AddToExistingState = struct {
    import_clause_or_binding_pattern: ast.NodeIndex,
    default_import: ?*NewImportBinding = null,
    named_imports: std.StringHashMapUnmanaged(*NewImportBinding) = .empty,
};

pub const ImportsCollection = struct {
    default_import: ?*NewImportBinding = null,
    named_imports: std.StringHashMapUnmanaged(*NewImportBinding) = .empty,
    namespace_like_import: ?*NewImportBinding = null,
    use_require: bool = false,
};

fn newImportsKey(allocator: std.mem.Allocator, module_specifier: []const u8, top_level_type_only: bool) []const u8 {
    if (top_level_type_only) {
        return std.fmt.allocPrint(allocator, "1|{s}", .{module_specifier}) catch @panic("OOM");
    }
    return std.fmt.allocPrint(allocator, "0|{s}", .{module_specifier}) catch @panic("OOM");
}

fn sortedNamedImports(arena: std.mem.Allocator, m: std.StringHashMapUnmanaged(*NewImportBinding)) []*NewImportBinding {
    var keys = std.ArrayList([]const u8).init(arena);
    var it = m.keyIterator();
    while (it.next()) |k| {
        keys.append(k.*) catch @panic("OOM");
    }
    std.mem.sort([]const u8, keys.items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);
    
    var result = std.ArrayList(*NewImportBinding).init(arena);
    for (keys.items) |k| {
        result.append(m.get(k).?) catch @panic("OOM");
    }
    return result.items;
}

fn reduceAddAsTypeOnlyValues(prev_value: lsproto.AddAsTypeOnly, new_value: lsproto.AddAsTypeOnly) lsproto.AddAsTypeOnly {
    if (@intFromEnum(new_value) > @intFromEnum(prev_value)) {
        return new_value;
    }
    return prev_value;
}

pub fn typeToAutoImportableTypeNode(
    c: *Checker,
    import_adder: ?*ImportAdder,
    t: checker_module.TypeIndex,
    context_node: ast.NodeIndex,
) ast.NodeIndex {
    var id_to_symbol = std.AutoHashMapUnmanaged(ast.NodeIndex, ast.SymbolIndex){};
    const type_node = c.typeToTypeNode(t, context_node, nodebuilder.FlagsNone, &id_to_symbol);
    if (type_node == .null) {
        return .null;
    }
    return typeNodeToAutoImportableTypeNode(c.arena, type_node, import_adder, &id_to_symbol);
}

pub fn typeNodeToAutoImportableTypeNode(
    arena: std.mem.Allocator,
    type_node: ast.NodeIndex,
    import_adder: ?*ImportAdder,
    id_to_symbol: *std.AutoHashMapUnmanaged(ast.NodeIndex, ast.SymbolIndex),
) ast.NodeIndex {
    const res = tryGetAutoImportableReferenceFromTypeNode(arena, type_node, id_to_symbol);
    const reference_type_node = res.type_node;
    const importable_symbols = res.symbols;

    if (reference_type_node != .null) {
        if (import_adder) |adder| {
            importSymbols(adder, importable_symbols);
        }
        return reference_type_node;
    }
    return type_node;
}

fn importSymbols(adder: *ImportAdder, symbols: []const ast.SymbolIndex) void {
    for (symbols) |symbol| {
        adder.addImportFromExportedSymbol(symbol, true);
    }
}

const TryGetAutoImportableReferenceResult = struct {
    type_node: ast.NodeIndex,
    symbols: []const ast.SymbolIndex,
};

pub fn tryGetAutoImportableReferenceFromTypeNode(
    arena: std.mem.Allocator,
    import_type_node: ast.NodeIndex,
    id_to_symbol: *std.AutoHashMapUnmanaged(ast.NodeIndex, ast.SymbolIndex),
) TryGetAutoImportableReferenceResult {
    const Context = struct {
        arena: std.mem.Allocator,
        symbols: std.ArrayListUnmanaged(ast.SymbolIndex),
        id_to_symbol: *std.AutoHashMapUnmanaged(ast.NodeIndex, ast.SymbolIndex),
        factory: *ast.NodeFactory,
    };
    
    var ctx = Context{
        .arena = arena,
        .symbols = .empty,
        .id_to_symbol = id_to_symbol,
        .factory = ast.NodeFactory.init(arena, null),
    };

    const visit = struct {
        fn visit(_ctx: ?*anyopaque, visitor: *ast.NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
            var c = @as(*Context, @ptrCast(@alignCast(_ctx.?)));
            if (ast.isLiteralImportTypeNode(node) and node.asImportTypeNode().qualifier != .null) {
                const import_type = node.asImportTypeNode();
                const first_identifier = ast.getFirstIdentifier(import_type.qualifier);
                if (c.id_to_symbol.get(first_identifier)) |symbol| {
                    const name = getNameForExportedSymbol(c.arena, symbol, false);
                    var qualifier: ast.NodeIndex = .null;
                    if (!std.mem.eql(u8, name, first_identifier.text())) {
                        qualifier = replaceFirstIdentifierOfEntityName(c.factory, import_type.qualifier, c.factory.newIdentifier(name));
                    } else {
                        qualifier = import_type.qualifier;
                    }
                    c.symbols.append(c.arena, symbol) catch @panic("OOM");
                    const type_arguments = visitor.visitNodes(import_type.type_arguments);
                    return c.factory.newTypeReferenceNode(qualifier, type_arguments).asNode();
                } else {
                    return visitor.visitEachChild(node);
                }
            }
            return visitor.visitEachChild(node);
        }
    }.visit;

    var visitor = ast.NodeVisitor.init(&ctx, visit, .{});
    const type_node = visitor.visitNode(import_type_node);
    
    debug.assert(type_node == .null or ast.isTypeNode(type_node));
    return .{
        .type_node = type_node,
        .symbols = ctx.symbols.items,
    };
}

fn getNameForExportedSymbol(arena: std.mem.Allocator, symbol: ast.SymbolIndex, prefer_capitalized: bool) []const u8 {
    const sym = ast.getSymbol(symbol);
    if (std.mem.eql(u8, sym.name, ast.InternalSymbolNameExportEquals) or std.mem.eql(u8, sym.name, ast.InternalSymbolNameDefault)) {
        const name = getDefaultLikeExportNameFromDeclaration(arena, symbol);
        if (name.len > 0) {
            return name;
        }
        debug.assert(sym.parent != .null);
        return lsutil.moduleSymbolToValidIdentifier(arena, sym.parent, prefer_capitalized);
    }
    return sym.name;
}

fn replaceFirstIdentifierOfEntityName(factory: *ast.NodeFactory, name: ast.NodeIndex, new_identifier: ast.NodeIndex) ast.NodeIndex {
    const n = ast.getNode(name);
    if (n.kind == .identifier) {
        return new_identifier;
    }
    return factory.newQualifiedName(
        replaceFirstIdentifierOfEntityName(factory, n.asQualifiedName().left, new_identifier),
        n.asQualifiedName().right,
    ).asNode();
}

fn getDefaultLikeExportNameFromDeclaration(arena: std.mem.Allocator, symbol: ast.SymbolIndex) []const u8 {
    _ = arena;
    const sym = ast.getSymbol(symbol);
    var decl: ast.NodeIndex = sym.value_declaration;
    if (decl == .null) {
        if (sym.declarations.len > 0) {
            decl = sym.declarations[0];
        }
    }
    if (decl != .null) {
        const n = ast.getNode(decl);
        if (n.kind == .export_assignment) {
            const expr = n.asExportAssignment().expression;
            if (expr != .null) {
                const expr_n = ast.getNode(expr);
                if (expr_n.kind == .identifier) {
                    return expr_n.asIdentifier().text();
                }
            }
        }
    }
    return "";
}
