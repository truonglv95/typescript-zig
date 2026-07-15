const std = @import("std");

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const symbol = @import("../ast/symbol.zig");
const checker = @import("../checker/checker.zig");
const Program = @import("../compiler/program.zig").Program;

pub const ImpExpKind = enum(i32) {
    Unknown,
    Import,
    Export,
};

pub const ExportKind = enum(u8) {
    Named = 0,
    Default = 1,
    ExportEquals = 2,
    UMD = 3,
    Module = 4,
};

pub const ExportInfo = struct {
    exporting_module_symbol: ast_gen.SymbolIndex = 0,
    export_kind: ExportKind = .Named,
};

pub const ImportExportSymbol = struct {
    kind: ImpExpKind = .Unknown,
    symbol: ast_gen.SymbolIndex = 0,
    export_info: ?ExportInfo = null,
};

pub const LocationAndSymbol = struct {
    import_location: ast_gen.NodeIndex = 0,
    import_symbol: ast_gen.SymbolIndex = 0,
};

pub const ImportsResult = struct {
    import_searches: std.ArrayListUnmanaged(LocationAndSymbol) = .empty,
    single_references: std.ArrayListUnmanaged(ast_gen.NodeIndex) = .empty,
    indirect_users: std.ArrayListUnmanaged(ast_gen.NodeIndex) = .empty,
};

pub const ModuleReferenceKind = enum(i32) {
    Import,
    Reference,
    Implicit,
};

pub const ModuleReference = struct {
    kind: ModuleReferenceKind = .Import,
    literal: ast_gen.NodeIndex = 0,
    referencing_file: ast_gen.NodeIndex = 0,
    ref: ast_gen.NodeIndex = 0,
};

pub const ImportTracker = struct {
    allocator: std.mem.Allocator,
    program: *const Program,
    source_files: []const ast_gen.NodeIndex,
    source_files_set: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, void),
    chk: *checker.Checker,
    all_direct_imports: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, std.ArrayListUnmanaged(ast_gen.NodeIndex)),

    pub fn init(
        allocator: std.mem.Allocator,
        program_in: *const Program,
        source_files: []const ast_gen.NodeIndex,
        source_files_set: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, void),
        chk: *checker.Checker,
    ) !ImportTracker {
        var tracker = ImportTracker{
            .allocator = allocator,
            .program = program_in,
            .source_files = source_files,
            .source_files_set = source_files_set,
            .chk = chk,
            .all_direct_imports = .empty,
        };
        try tracker.getDirectImportsMap();
        return tracker;
    }

    pub fn deinit(self: *ImportTracker) void {
        var it = self.all_direct_imports.valueIterator();
        while (it.next()) |list| {
            list.deinit(self.allocator);
        }
        self.all_direct_imports.deinit(self.allocator);
    }

    pub fn track(
        self: *ImportTracker,
        export_symbol: ast_gen.SymbolIndex,
        export_info: *const ExportInfo,
        is_for_rename: bool,
    ) !ImportsResult {
        var direct_imports = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer direct_imports.deinit(self.allocator);

        var indirect_users = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        
        try self.getImportersForExport(&direct_imports, &indirect_users, export_info);
        
        var import_searches = std.ArrayListUnmanaged(LocationAndSymbol).empty;
        var single_references = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        
        try self.getSearchesFromDirectImports(direct_imports.items, export_symbol, export_info.export_kind, is_for_rename, &import_searches, &single_references);
        
        return ImportsResult{
            .import_searches = import_searches,
            .single_references = single_references,
            .indirect_users = indirect_users,
        };
    }

    fn getDirectImportsMap(self: *ImportTracker) !void {
        const Ctx = struct {
            tracker: *ImportTracker,
            fn action(inner: *@This(), import_decl: ast_gen.NodeIndex, module_specifier: ast_gen.NodeIndex) !void {
                const module_symbol = inner.tracker.chk.getSymbolAtLocation(module_specifier);
                if (module_symbol != 0) {
                    const gop = try inner.tracker.all_direct_imports.getOrPut(inner.tracker.allocator, module_symbol);
                    if (!gop.found_existing) {
                        gop.value_ptr.* = .empty;
                    }
                    try gop.value_ptr.append(inner.tracker.allocator, import_decl);
                }
            }
        };
        var ctx = Ctx{ .tracker = self };

        for (self.source_files) |source_file| {
            try forEachImport(self.allocator, self.program, source_file, self.chk, &ctx, Ctx.action);
        }
    }

    fn getImportersForExport(
        self: *ImportTracker,
        direct_imports_out: *std.ArrayListUnmanaged(ast_gen.NodeIndex),
        indirect_users_out: *std.ArrayListUnmanaged(ast_gen.NodeIndex),
        export_info: *const ExportInfo,
    ) !void {
        const tree = &self.chk.binder.ast;
        var indirect_user_declarations = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer indirect_user_declarations.deinit(self.allocator);

        var seen_direct_imports = std.AutoHashMapUnmanaged(ast_gen.NodeIndex, void).empty;
        defer seen_direct_imports.deinit(self.allocator);

        var seen_indirect_users = std.AutoHashMapUnmanaged(ast_gen.NodeIndex, void).empty;
        defer seen_indirect_users.deinit(self.allocator);

        const exporting_module_symbol = export_info.exporting_module_symbol;
        const value_decl = self.chk.symbolValueDeclaration(exporting_module_symbol);
        const is_available_through_global = if (value_decl != 0) ast_utils.isSourceFileWithGlobalExports(tree, value_decl) else false;

        const Ctx = struct {
            tracker: *ImportTracker,
            tree: @TypeOf(tree),
            direct_imports_out: *std.ArrayListUnmanaged(ast_gen.NodeIndex),
            indirect_user_declarations: *std.ArrayListUnmanaged(ast_gen.NodeIndex),
            seen_direct_imports: *std.AutoHashMapUnmanaged(ast_gen.NodeIndex, void),
            seen_indirect_users: *std.AutoHashMapUnmanaged(ast_gen.NodeIndex, void),
            export_info: *const ExportInfo,
            is_available_through_global: bool,

            fn addIndirectUser(c: *@This(), source_file_like: ast_gen.NodeIndex, add_transitive_dependencies: bool) !void {
                if (c.is_available_through_global) {
                    return;
                }
                const gop = try c.seen_indirect_users.getOrPut(c.tracker.allocator, source_file_like);
                if (gop.found_existing) return;

                try c.indirect_user_declarations.append(c.tracker.allocator, source_file_like);

                if (!add_transitive_dependencies) return;

                const node_symbol = c.tracker.chk.getSymbolOfNode(source_file_like);
                const module_symbol = c.tracker.chk.getMergedSymbol(node_symbol);
                if (module_symbol == 0) return;

                if (!c.tracker.chk.hasSymbolFlag(module_symbol, ast.SymbolFlags.Module)) return;

                if (c.tracker.all_direct_imports.get(module_symbol)) |direct_imports| {
                    for (direct_imports.items) |direct_import| {
                        if (!ast_utils.isImportTypeNode(c.tree, direct_import)) {
                            try c.addIndirectUser(getSourceFileLikeForImportDeclaration(c.tree, direct_import), true);
                        }
                    }
                }
            }

            fn isExported(c: *@This(), node_in: ast_gen.NodeIndex, stop_at_ambient_module: bool) bool {
                var node = node_in;
                while (node != 0) {
                    if (stop_at_ambient_module and isAmbientModuleDeclaration(c.tree, node)) break;
                    if (ast_utils.hasSyntacticModifier(c.tree, node, ast.ModifierFlags.Export)) {
                        return true;
                    }
                    node = ast_utils.parent(c.tree, node);
                }
                return false;
            }

            fn handleImportCall(c: *@This(), import_call: ast_gen.NodeIndex) !void {
                var top = ast_utils.findAncestor(c.tree, import_call, isAmbientModuleDeclarationWrapper);
                if (top == 0) {
                    top = ast_utils.getSourceFileOfNode(c.tree, import_call);
                }
                try c.addIndirectUser(top, c.isExported(import_call, true));
            }

            fn isAmbientModuleDeclarationWrapper(tree_inner: @TypeOf(tree), node: ast_gen.NodeIndex) bool {
                return isAmbientModuleDeclaration(tree_inner, node);
            }

            fn handleNamespaceImport(c: *@This(), import_declaration: ast_gen.NodeIndex, name: ast_gen.NodeIndex, is_re_export: bool, already_added_direct: bool) !void {
                if (c.export_info.export_kind == .ExportEquals) {
                    if (!already_added_direct) {
                        try c.direct_imports_out.append(c.tracker.allocator, import_declaration);
                    }
                } else if (!c.is_available_through_global) {
                    const source_file_like = getSourceFileLikeForImportDeclaration(c.tree, import_declaration);
                    const is_re_export_actual = is_re_export or (try findNamespaceReExports(c.tracker.allocator, c.tree, source_file_like, name, c.tracker.chk));
                    try c.addIndirectUser(source_file_like, is_re_export_actual);
                }
            }

            fn handleDirectImports(c: *@This(), module_symbol: ast_gen.SymbolIndex) !void {
                if (c.tracker.all_direct_imports.get(module_symbol)) |direct_imports| {
                    for (direct_imports.items) |direct| {
                        const gop = try c.seen_direct_imports.getOrPut(c.tracker.allocator, direct);
                        if (gop.found_existing) continue;

                        const node_tag = c.tree.nodeTag(direct);
                        switch (node_tag) {
                            .CallExpression => {
                                if (ast_utils.isImportCall(c.tree, direct)) {
                                    try c.handleImportCall(direct);
                                } else if (!c.is_available_through_global) {
                                    const parent = ast_utils.parent(c.tree, direct);
                                    if (c.export_info.export_kind == .ExportEquals and ast_utils.isVariableDeclaration(c.tree, parent)) {
                                        const name = ast_utils.name(c.tree, parent);
                                        if (ast_utils.isIdentifier(c.tree, name)) {
                                            try c.direct_imports_out.append(c.tracker.allocator, name);
                                        }
                                    }
                                }
                            },
                            .Identifier => {},
                            .ImportEqualsDeclaration => {
                                try c.handleNamespaceImport(direct, ast_utils.name(c.tree, direct), ast_utils.hasSyntacticModifier(c.tree, direct, ast.ModifierFlags.Export), false);
                            },
                            .ImportDeclaration, .JSImportDeclaration, .JSDocImportTag => {
                                try c.direct_imports_out.append(c.tracker.allocator, direct);
                                const import_clause = ast_utils.importClause(c.tree, direct);
                                if (import_clause != 0) {
                                    const named_bindings = ast_utils.namedBindings(c.tree, import_clause);
                                    if (named_bindings != 0 and ast_utils.isNamespaceImport(c.tree, named_bindings)) {
                                        try c.handleNamespaceImport(direct, ast_utils.name(c.tree, named_bindings), false, true);
                                        continue;
                                    }
                                }
                                if (!c.is_available_through_global and ast_utils.isDefaultImport(c.tree, direct)) {
                                    try c.addIndirectUser(getSourceFileLikeForImportDeclaration(c.tree, direct), false);
                                }
                            },
                            .ExportDeclaration => {
                                const export_clause = ast_utils.exportClause(c.tree, direct);
                                if (export_clause == 0) {
                                    try c.handleDirectImports(getContainingModuleSymbol(c.tree, direct, c.tracker.chk));
                                } else if (ast_utils.isNamespaceExport(c.tree, export_clause)) {
                                    try c.addIndirectUser(getSourceFileLikeForImportDeclaration(c.tree, direct), true);
                                } else {
                                    try c.direct_imports_out.append(c.tracker.allocator, direct);
                                }
                            },
                            .ImportType => {
                                if (!c.is_available_through_global and ast_utils.isTypeOf(c.tree, direct) and ast_utils.qualifier(c.tree, direct) == 0 and c.isExported(direct, false)) {
                                    try c.addIndirectUser(ast_utils.getSourceFileOfNode(c.tree, direct), true);
                                }
                                try c.direct_imports_out.append(c.tracker.allocator, direct);
                            },
                            else => {},
                        }
                    }
                }
            }
        };

        var ctx = Ctx{
            .tracker = self,
            .tree = tree,
            .direct_imports_out = direct_imports_out,
            .indirect_user_declarations = &indirect_user_declarations,
            .seen_direct_imports = &seen_direct_imports,
            .seen_indirect_users = &seen_indirect_users,
            .export_info = export_info,
            .is_available_through_global = is_available_through_global,
        };

        try ctx.handleDirectImports(export_info.exporting_module_symbol);

        if (is_available_through_global) {
            for (self.source_files) |sf| {
                try indirect_users_out.append(self.allocator, sf);
            }
        } else {
            const decls = self.chk.symbolDeclarations(export_info.exporting_module_symbol);
            for (decls) |decl| {
                if (ast_utils.isExternalModuleAugmentation(tree, decl)) {
                    const sf = ast_utils.getSourceFileOfNode(tree, decl);
                    if (self.source_files_set.contains(sf)) {
                        try ctx.addIndirectUser(decl, false);
                    }
                }
            }
            for (indirect_user_declarations.items) |decl| {
                try indirect_users_out.append(self.allocator, ast_utils.getSourceFileOfNode(tree, decl));
            }
        }
    }

    fn getSearchesFromDirectImports(
        self: *ImportTracker,
        direct_imports: []const ast_gen.NodeIndex,
        export_symbol: ast_gen.SymbolIndex,
        export_kind: ExportKind,
        is_for_rename: bool,
        import_searches_out: *std.ArrayListUnmanaged(LocationAndSymbol),
        single_references_out: *std.ArrayListUnmanaged(ast_gen.NodeIndex),
    ) !void {
        const tree = &self.chk.binder.ast;
        const export_symbol_name = self.chk.symbolName(export_symbol);

        const Ctx = struct {
            tracker: *ImportTracker,
            tree: @TypeOf(tree),
            export_symbol: ast_gen.SymbolIndex,
            export_symbol_name: []const u8,
            export_kind: ExportKind,
            is_for_rename: bool,
            import_searches: *std.ArrayListUnmanaged(LocationAndSymbol),
            single_references: *std.ArrayListUnmanaged(ast_gen.NodeIndex),

            fn isNameMatch(c: *@This(), name: []const u8) bool {
                return std.mem.eql(u8, name, c.export_symbol_name) or (c.export_kind != .Named and std.mem.eql(u8, name, "default"));
            }

            fn handleNamespaceImportLike(c: *@This(), import_name: ast_gen.NodeIndex) !void {
                const text = ast_utils.text(c.tree, import_name);
                if (c.export_kind == .ExportEquals and (!c.is_for_rename or c.isNameMatch(text))) {
                    try c.import_searches.append(c.tracker.allocator, .{
                        .import_location = import_name,
                        .import_symbol = c.tracker.chk.getSymbolAtLocation(import_name),
                    });
                }
            }

            fn searchForNamedImport(c: *@This(), named_bindings: ast_gen.NodeIndex) !void {
                if (named_bindings == 0) return;
                const elements = ast_utils.elements(c.tree, named_bindings);
                for (elements) |element| {
                    const name = ast_utils.name(c.tree, element);
                    const property_name = ast_utils.propertyName(c.tree, element);
                    const text_node = if (property_name != 0) property_name else name;
                    const text = ast_utils.text(c.tree, text_node);
                    
                    if (!c.isNameMatch(text)) continue;
                    
                    if (property_name != 0) {
                        try c.single_references.append(c.tracker.allocator, property_name);
                        if (!c.is_for_rename or std.mem.eql(u8, ast_utils.text(c.tree, name), c.export_symbol_name)) {
                            try c.import_searches.append(c.tracker.allocator, .{
                                .import_location = name,
                                .import_symbol = c.tracker.chk.getSymbolAtLocation(name),
                            });
                        }
                    } else {
                        var local_symbol: ast_gen.SymbolIndex = 0;
                        if (ast_utils.isExportSpecifier(c.tree, element) and ast_utils.propertyName(c.tree, element) != 0) {
                            local_symbol = c.tracker.chk.getExportSpecifierLocalTargetSymbol(element);
                        } else {
                            local_symbol = c.tracker.chk.getSymbolAtLocation(name);
                        }
                        try c.import_searches.append(c.tracker.allocator, .{
                            .import_location = name,
                            .import_symbol = local_symbol,
                        });
                    }
                }
            }
            
            fn handleImport(c: *@This(), decl: ast_gen.NodeIndex) !void {
                if (ast_utils.isImportEqualsDeclaration(c.tree, decl)) {
                    if (isExternalModuleImportEquals(c.tree, decl)) {
                        try c.handleNamespaceImportLike(ast_utils.name(c.tree, decl));
                    }
                    return;
                }
                if (ast_utils.isIdentifier(c.tree, decl)) {
                    try c.handleNamespaceImportLike(decl);
                    return;
                }
                if (ast_utils.isImportTypeNode(c.tree, decl)) {
                    const qualifier = ast_utils.qualifier(c.tree, decl);
                    if (qualifier != 0) {
                        const first_identifier = ast_utils.getFirstIdentifier(c.tree, qualifier);
                        if (std.mem.eql(u8, ast_utils.text(c.tree, first_identifier), c.export_symbol_name)) {
                            try c.single_references.append(c.tracker.allocator, first_identifier);
                        }
                    } else if (c.export_kind == .ExportEquals) {
                        const arg = ast_utils.argument(c.tree, decl);
                        const literal = ast_utils.literal(c.tree, arg);
                        try c.single_references.append(c.tracker.allocator, literal);
                    }
                    return;
                }
                if (!ast_utils.isStringLiteral(c.tree, ast_utils.moduleSpecifier(c.tree, decl))) {
                    return;
                }
                if (ast_utils.isExportDeclaration(c.tree, decl)) {
                    const export_clause = ast_utils.exportClause(c.tree, decl);
                    if (export_clause != 0 and ast_utils.isNamedExports(c.tree, export_clause)) {
                        try c.searchForNamedImport(export_clause);
                    }
                    return;
                }
                const import_clause = ast_utils.importClause(c.tree, decl);
                if (import_clause != 0) {
                    const named_bindings = ast_utils.namedBindings(c.tree, import_clause);
                    if (named_bindings != 0) {
                        if (ast_utils.isNamespaceImport(c.tree, named_bindings)) {
                            try c.handleNamespaceImportLike(ast_utils.name(c.tree, named_bindings));
                        } else if (ast_utils.isNamedImports(c.tree, named_bindings)) {
                            if (c.export_kind == .Named or c.export_kind == .Default) {
                                try c.searchForNamedImport(named_bindings);
                            }
                        }
                    }
                    
                    const name = ast_utils.name(c.tree, import_clause);
                    if (name != 0 and (c.export_kind == .Default or c.export_kind == .ExportEquals)) {
                        const no_default_name = symbolNameNoDefault(c.tracker.chk, c.export_symbol);
                        if (!c.is_for_rename or std.mem.eql(u8, ast_utils.text(c.tree, name), no_default_name)) {
                            const default_import_alias = c.tracker.chk.getSymbolAtLocation(name);
                            try c.import_searches.append(c.tracker.allocator, .{
                                .import_location = name,
                                .import_symbol = default_import_alias,
                            });
                        }
                    }
                }
            }
        };

        var ctx = Ctx{
            .tracker = self,
            .tree = tree,
            .export_symbol = export_symbol,
            .export_symbol_name = export_symbol_name,
            .export_kind = export_kind,
            .is_for_rename = is_for_rename,
            .import_searches = import_searches_out,
            .single_references = single_references_out,
        };

        for (direct_imports) |decl| {
            try ctx.handleImport(decl);
        }
    }
};

fn forEachImport(
    allocator: std.mem.Allocator,
    program: *const Program,
    source_file: ast_gen.NodeIndex,
    chk: *checker.Checker,
    ctx: anytype,
    comptime action: fn (@TypeOf(ctx), ast_gen.NodeIndex, ast_gen.NodeIndex) anyerror!void,
) !void {
    const tree = &chk.binder.ast;
    
    var implicit_imports = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
    defer implicit_imports.deinit(allocator);

    const jsx_specifier = program.getJSXRuntimeImportSpecifier(source_file);
    if (jsx_specifier != 0) {
        try implicit_imports.append(allocator, jsx_specifier);
    }
    const import_helpers_specifier = program.getImportHelpersImportSpecifier(source_file);
    if (import_helpers_specifier != 0) {
        try implicit_imports.append(allocator, import_helpers_specifier);
    }

    const external_module_indicator = ast_utils.externalModuleIndicator(tree, source_file);
    const imports = ast_utils.imports(tree, source_file);

    if (external_module_indicator != 0 or imports.len > 0 or implicit_imports.items.len > 0) {
        for (imports) |i| {
            try action(ctx, ast_utils.importFromModuleSpecifier(tree, i), i);
        }
        for (implicit_imports.items) |i| {
            try action(ctx, ast_utils.importFromModuleSpecifier(tree, i), i);
        }
    } else {
        const ActionContext = struct {
            ctx_inner: @TypeOf(ctx),
            tree_inner: @TypeOf(tree),
        };
        var action_ctx = ActionContext{ .ctx_inner = ctx, .tree_inner = tree };

        const Wrapper = struct {
            fn callback(inner: *ActionContext, statement: ast_gen.NodeIndex) anyerror!bool {
                const ast_ptr = inner.tree_inner;
                const node_tag = ast_ptr.nodeTag(statement);
                switch (node_tag) {
                    .ExportDeclaration, .ImportDeclaration, .JSImportDeclaration => {
                        const specifier = ast_utils.moduleSpecifier(ast_ptr, statement);
                        if (specifier != 0 and ast_utils.isStringLiteral(ast_ptr, specifier)) {
                            try action(inner.ctx_inner, statement, specifier);
                        }
                    },
                    .ImportEqualsDeclaration => {
                        if (isExternalModuleImportEquals(ast_ptr, statement)) {
                            const module_reference = ast_utils.moduleReference(ast_ptr, statement);
                            const expr = ast_utils.expression(ast_ptr, module_reference);
                            try action(inner.ctx_inner, statement, expr);
                        }
                    },
                    else => {},
                }
                return false;
            }
        };
        _ = try forEachPossibleImportOrExportStatement(allocator, tree, source_file, &action_ctx, Wrapper.callback);
    }
}

fn forEachPossibleImportOrExportStatement(
    allocator: std.mem.Allocator,
    tree: anytype,
    source_file_like: ast_gen.NodeIndex,
    ctx: anytype,
    comptime action: fn (@TypeOf(ctx), ast_gen.NodeIndex) anyerror!bool,
) anyerror!bool {
    const statements = ast_utils.getStatementsOfSourceFileLike(tree, source_file_like);
    for (statements) |statement| {
        if (try action(ctx, statement)) {
            return true;
        }
        if (isAmbientModuleDeclaration(tree, statement)) {
            if (try forEachPossibleImportOrExportStatement(allocator, tree, statement, ctx, action)) {
                return true;
            }
        }
    }
    return false;
}

fn getSourceFileLikeForImportDeclaration(tree: anytype, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (ast_utils.isCallExpression(tree, node) or ast_utils.isJSDocImportTag(tree, node)) {
        return ast_utils.getSourceFileOfNode(tree, node);
    }
    const parent = ast_utils.parent(tree, node);
    if (tree.nodeTag(parent) == .SourceFile) {
        return parent;
    }
    std.debug.assert(ast_utils.isModuleBlock(tree, parent) and isAmbientModuleDeclaration(tree, ast_utils.parent(tree, parent)));
    return ast_utils.parent(tree, parent);
}

fn isAmbientModuleDeclaration(tree: anytype, node: ast_gen.NodeIndex) bool {
    return ast_utils.isModuleDeclaration(tree, node) and ast_utils.isStringLiteral(tree, ast_utils.name(tree, node));
}

fn getContainingModuleSymbol(tree: anytype, importer: ast_gen.NodeIndex, chk: *checker.Checker) ast_gen.SymbolIndex {
    const file_like = getSourceFileLikeForImportDeclaration(tree, importer);
    return chk.getMergedSymbol(chk.getSymbolOfNode(file_like));
}

fn findNamespaceReExports(allocator: std.mem.Allocator, tree: anytype, source_file_like: ast_gen.NodeIndex, name: ast_gen.NodeIndex, chk: *checker.Checker) !bool {
    const namespace_import_symbol = chk.getSymbolAtLocation(name);
    
    const Ctx = struct {
        tree: @TypeOf(tree),
        chk: *checker.Checker,
        namespace_import_symbol: ast_gen.SymbolIndex,
    };
    var ctx = Ctx{ .tree = tree, .chk = chk, .namespace_import_symbol = namespace_import_symbol };
    
    const Wrapper = struct {
        fn action(inner: *Ctx, statement: ast_gen.NodeIndex) anyerror!bool {
            if (!ast_utils.isExportDeclaration(inner.tree, statement)) return false;
            const export_clause = ast_utils.exportClause(inner.tree, statement);
            const module_specifier = ast_utils.moduleSpecifier(inner.tree, statement);
            
            if (module_specifier == 0 and export_clause != 0 and ast_utils.isNamedExports(inner.tree, export_clause)) {
                const elements = ast_utils.elements(inner.tree, export_clause);
                for (elements) |element| {
                    if (inner.chk.getExportSpecifierLocalTargetSymbol(element) == inner.namespace_import_symbol) {
                        return true;
                    }
                }
            }
            return false;
        }
    };
    
    return try forEachPossibleImportOrExportStatement(allocator, tree, source_file_like, &ctx, Wrapper.action);
}

pub fn getImportOrExportSymbol(
    allocator: std.mem.Allocator,
    node: ast_gen.NodeIndex,
    symbol_idx: ast_gen.SymbolIndex,
    chk: *checker.Checker,
    coming_from_export: bool,
) !?ImportExportSymbol {
    _ = allocator;
    const tree = &chk.binder.ast;
    
    const Ctx = struct {
        tree: @TypeOf(tree),
        chk: *checker.Checker,
        node: ast_gen.NodeIndex,
        symbol_idx: ast_gen.SymbolIndex,

        fn exportInfo(c: *@This(), sym: ast_gen.SymbolIndex, kind: ExportKind) ?ImportExportSymbol {
            if (getExportInfo(sym, kind, c.chk)) |info| {
                return ImportExportSymbol{
                    .kind = .Export,
                    .symbol = sym,
                    .export_info = info,
                };
            }
            return null;
        }

        fn getExportAssignmentExport(c: *@This(), ex: ast_gen.NodeIndex) ?ImportExportSymbol {
            const ex_symbol = c.chk.getSymbolOfNode(ex);
            const parent = c.chk.symbolParent(ex_symbol);
            if (parent == 0) return null;
            const export_kind: ExportKind = if (ast_utils.isExportEquals(c.tree, ex)) .ExportEquals else .Default;
            return ImportExportSymbol{
                .kind = .Export,
                .symbol = c.symbol_idx,
                .export_info = .{
                    .exporting_module_symbol = parent,
                    .export_kind = export_kind,
                },
            };
        }

        fn getExportKindForDeclaration(c: *@This(), n: ast_gen.NodeIndex) ExportKind {
            if (ast_utils.hasSyntacticModifier(c.tree, n, ast.ModifierFlags.Default)) {
                return .Default;
            }
            return .Named;
        }

        fn getSpecialPropertyExport(c: *@This(), n: ast_gen.NodeIndex, use_lhs_symbol: bool) ?ImportExportSymbol {
            var kind: ExportKind = undefined;
            switch (ast_utils.getAssignmentDeclarationKind(c.tree, n)) {
                ast.JSDeclarationKind.ExportsProperty => kind = .Named,
                ast.JSDeclarationKind.ModuleExports => kind = .ExportEquals,
                else => return null,
            }
            var sym = c.symbol_idx;
            if (use_lhs_symbol) {
                sym = c.chk.getSymbolOfNode(n);
            }
            if (sym == 0) return null;
            return c.exportInfo(sym, kind);
        }

        fn getExport(c: *@This(), coming_from_export_inner: bool) ?ImportExportSymbol {
            const parent = ast_utils.parent(c.tree, c.node);
            const grandparent = ast_utils.parent(c.tree, parent);
            const export_symbol = c.chk.symbolExportSymbol(c.symbol_idx);
            
            if (export_symbol != 0) {
                if (ast_utils.isPropertyAccessExpression(c.tree, parent)) {
                    if (ast_utils.isBinaryExpression(c.tree, grandparent) and ast_utils.containsNode(c.chk.symbolDeclarations(c.symbol_idx), parent)) {
                        return c.getSpecialPropertyExport(grandparent, false);
                    }
                    return null;
                }
                return c.exportInfo(export_symbol, c.getExportKindForDeclaration(parent));
            } else {
                const export_node = getExportNode(c.tree, parent, c.node);
                if (export_node != 0 and (ast_utils.hasSyntacticModifier(c.tree, export_node, ast.ModifierFlags.Export) or ast_utils.isImplicitlyExportedJSDocDeclaration(c.tree, export_node))) {
                    if (ast_utils.isImportEqualsDeclaration(c.tree, export_node) and ast_utils.moduleReference(c.tree, export_node) == c.node) {
                        if (coming_from_export_inner) return null;
                        const lhs_symbol = c.chk.getSymbolAtLocation(ast_utils.name(c.tree, export_node));
                        return ImportExportSymbol{
                            .kind = .Import,
                            .symbol = lhs_symbol,
                        };
                    }
                    return c.exportInfo(c.symbol_idx, c.getExportKindForDeclaration(export_node));
                } else if (ast_utils.isNamespaceExport(c.tree, parent)) {
                    return c.exportInfo(c.symbol_idx, .Named);
                } else if (ast_utils.isExportAssignment(c.tree, parent)) {
                    return c.getExportAssignmentExport(parent);
                } else if (ast_utils.isExportAssignment(c.tree, grandparent)) {
                    return c.getExportAssignmentExport(grandparent);
                } else if (ast_utils.isBinaryExpression(c.tree, parent)) {
                    return c.getSpecialPropertyExport(parent, true);
                } else if (ast_utils.isBinaryExpression(c.tree, grandparent)) {
                    return c.getSpecialPropertyExport(grandparent, true);
                } else if (ast_utils.isJSDocTypedefTag(c.tree, parent) or ast_utils.isJSDocCallbackTag(c.tree, parent)) {
                    return c.exportInfo(c.symbol_idx, .Named);
                }
            }
            return null;
        }

        fn getImport(c: *@This()) ?ImportExportSymbol {
            if (!isNodeImport(c.tree, c.node)) return null;
            
            var imported_symbol: ast_gen.SymbolIndex = 0;
            if (c.chk.hasSymbolFlag(c.symbol_idx, ast.SymbolFlags.Alias)) {
                imported_symbol = c.chk.getImmediateAliasedSymbol(c.symbol_idx);
            } else {
                imported_symbol = c.chk.getPropertySymbolOfObjectBindingPatternWithoutPropertyName(c.symbol_idx);
            }
            if (imported_symbol == 0) return null;
            
            imported_symbol = skipExportSpecifierSymbol(c.tree, imported_symbol, c.chk);
            if (imported_symbol == 0) return null;
            
            const imported_name = c.chk.symbolName(imported_symbol);
            if (std.mem.eql(u8, imported_name, "export=")) {
                imported_symbol = getExportEqualsLocalSymbol(c.tree, imported_symbol, c.chk);
                if (imported_symbol == 0) return null;
            }
            
            const imported_name_no_default = symbolNameNoDefault(c.chk, imported_symbol);
            if (imported_name_no_default.len == 0 or std.mem.eql(u8, imported_name_no_default, "default") or std.mem.eql(u8, imported_name_no_default, c.chk.symbolName(c.symbol_idx))) {
                return ImportExportSymbol{
                    .kind = .Import,
                    .symbol = imported_symbol,
                };
            }
            return null;
        }
    };
    
    var ctx = Ctx{ .tree = tree, .chk = chk, .node = node, .symbol_idx = symbol_idx };
    if (ctx.getExport(coming_from_export)) |res| return res;
    if (!coming_from_export) {
        if (ctx.getImport()) |res| return res;
    }
    return null;
}

fn getExportInfo(export_symbol: ast_gen.SymbolIndex, export_kind: ExportKind, chk: *checker.Checker) ?ExportInfo {
    const parent = chk.symbolParent(export_symbol);
    if (parent != 0) {
        const exporting_module_symbol = chk.getMergedSymbol(parent);
        if (chk.isExternalModuleSymbol(exporting_module_symbol)) {
            return ExportInfo{
                .exporting_module_symbol = exporting_module_symbol,
                .export_kind = export_kind,
            };
        }
    }
    return null;
}

fn getExportNode(tree: anytype, parent: ast_gen.NodeIndex, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    var declaration: ast_gen.NodeIndex = 0;
    if (ast_utils.isVariableDeclaration(tree, parent)) {
        declaration = parent;
    } else if (ast_utils.isBindingElement(tree, parent)) {
        declaration = ast_utils.walkUpBindingElementsAndPatterns(tree, parent);
    }
    if (declaration != 0) {
        const decl_parent = ast_utils.parent(tree, declaration);
        const decl_grandparent = ast_utils.parent(tree, decl_parent);
        if (ast_utils.name(tree, parent) == node and !ast_utils.isCatchClause(tree, decl_parent) and ast_utils.isVariableStatement(tree, decl_grandparent)) {
            return decl_grandparent;
        }
        return 0;
    }
    return parent;
}

fn isNodeImport(tree: anytype, node: ast_gen.NodeIndex) bool {
    const parent = ast_utils.parent(tree, node);
    switch (tree.nodeTag(parent)) {
        .ImportEqualsDeclaration => {
            return ast_utils.name(tree, parent) == node and isExternalModuleImportEquals(tree, parent);
        },
        .ImportSpecifier => {
            return ast_utils.propertyName(tree, parent) == 0;
        },
        .ImportClause, .NamespaceImport => {
            return ast_utils.name(tree, parent) == node;
        },
        .BindingElement => {
            const parent_parent_parent = ast_utils.parent(tree, ast_utils.parent(tree, parent));
            return ast_utils.isInJSFile(tree, node) and ast_utils.isVariableDeclarationInitializedToBareOrAccessedRequire(tree, parent_parent_parent);
        },
        else => return false,
    }
}

fn isExternalModuleImportEquals(tree: anytype, node: ast_gen.NodeIndex) bool {
    const module_reference = ast_utils.moduleReference(tree, node);
    return ast_utils.isExternalModuleReference(tree, module_reference) and tree.nodeTag(ast_utils.expression(tree, module_reference)) == .StringLiteral;
}

fn skipExportSpecifierSymbol(tree: anytype, symbol_idx: ast_gen.SymbolIndex, chk: *checker.Checker) ast_gen.SymbolIndex {
    const declarations = chk.symbolDeclarations(symbol_idx);
    for (declarations) |declaration| {
        if (ast_utils.isExportSpecifier(tree, declaration) and ast_utils.propertyName(tree, declaration) == 0 and ast_utils.moduleSpecifier(tree, ast_utils.parent(tree, ast_utils.parent(tree, declaration))) == 0) {
            const target = chk.getExportSpecifierLocalTargetSymbol(declaration);
            return if (target != 0) target else symbol_idx;
        } else if (ast_utils.isPropertyAccessExpression(tree, declaration) and ast_utils.isModuleExportsAccessExpression(tree, ast_utils.expression(tree, declaration)) and !ast_utils.isPrivateIdentifier(tree, ast_utils.name(tree, declaration))) {
            return chk.getSymbolAtLocation(declaration);
        } else if (ast_utils.isShorthandPropertyAssignment(tree, declaration) and ast_utils.isBinaryExpression(tree, ast_utils.parent(tree, ast_utils.parent(tree, declaration))) and ast_utils.getAssignmentDeclarationKind(tree, ast_utils.parent(tree, ast_utils.parent(tree, declaration))) == ast.JSDeclarationKind.ModuleExports) {
            return chk.getExportSpecifierLocalTargetSymbol(ast_utils.name(tree, declaration));
        }
    }
    return symbol_idx;
}

fn getExportEqualsLocalSymbol(tree: anytype, imported_symbol: ast_gen.SymbolIndex, chk: *checker.Checker) ast_gen.SymbolIndex {
    if (chk.hasSymbolFlag(imported_symbol, ast.SymbolFlags.Alias)) {
        return chk.getImmediateAliasedSymbol(imported_symbol);
    }
    const decl = chk.symbolValueDeclaration(imported_symbol);
    if (decl == 0) return 0;
    
    if (ast_utils.isExportAssignment(tree, decl)) {
        return chk.getSymbolOfNode(ast_utils.expression(tree, decl));
    } else if (ast_utils.isBinaryExpression(tree, decl)) {
        return chk.getSymbolOfNode(ast_utils.right(tree, decl));
    } else if (tree.nodeTag(decl) == .SourceFile) {
        return chk.getSymbolOfNode(decl);
    }
    return 0;
}

fn symbolNameNoDefault(chk: *checker.Checker, symbol_idx: ast_gen.SymbolIndex) []const u8 {
    const name = chk.symbolName(symbol_idx);
    if (!std.mem.eql(u8, name, "default")) {
        return name;
    }
    const declarations = chk.symbolDeclarations(symbol_idx);
    for (declarations) |decl| {
        const decl_name = ast_utils.getNameOfDeclaration(&chk.binder.ast, decl);
        if (decl_name != 0 and ast_utils.isIdentifier(&chk.binder.ast, decl_name)) {
            return ast_utils.text(&chk.binder.ast, decl_name);
        }
    }
    return "";
}

pub fn findModuleReferences(
    allocator: std.mem.Allocator,
    program: *const Program,
    source_files: []const ast_gen.NodeIndex,
    search_module_symbol: ast_gen.SymbolIndex,
    chk: *checker.Checker,
) ![]ModuleReference {
    var refs = std.ArrayList(ModuleReference).init(allocator);
    errdefer refs.deinit();

    const tree = &chk.binder.ast;

    for (source_files) |referencing_file| {
        const search_source_file = chk.symbolValueDeclaration(search_module_symbol);
        if (search_source_file != 0 and tree.nodeTag(search_source_file) == .SourceFile) {
            const referenced_files = ast_utils.referencedFiles(tree, referencing_file);
            for (referenced_files) |ref| {
                if (program.getSourceFileFromReference(referencing_file, ref) == search_source_file) {
                    try refs.append(.{
                        .kind = .Reference,
                        .referencing_file = referencing_file,
                        .ref = ref,
                    });
                }
            }

            const type_reference_directives = ast_utils.typeReferenceDirectives(tree, referencing_file);
            for (type_reference_directives) |ref| {
                const referenced = program.getResolvedTypeReferenceDirectiveFromTypeReferenceDirective(ref, referencing_file);
                if (referenced != 0 and std.mem.eql(u8, ast_utils.fileName(tree, referenced), ast_utils.fileName(tree, search_source_file))) {
                    try refs.append(.{
                        .kind = .Reference,
                        .referencing_file = referencing_file,
                        .ref = ref,
                    });
                }
            }
        }

        const Context = struct {
            refs: *std.ArrayList(ModuleReference),
            search_module_symbol: ast_gen.SymbolIndex,
            chk: *checker.Checker,
            referencing_file: ast_gen.NodeIndex,
            tree: @TypeOf(tree),
            
            fn action(inner: *@This(), import_decl: ast_gen.NodeIndex, module_specifier: ast_gen.NodeIndex) !void {
                const module_symbol = inner.chk.getSymbolAtLocation(module_specifier);
                if (module_symbol == inner.search_module_symbol) {
                    if (ast_utils.nodeIsSynthesized(inner.tree, import_decl)) {
                        try inner.refs.append(.{
                            .kind = .Implicit,
                            .literal = module_specifier,
                            .referencing_file = inner.referencing_file,
                        });
                    } else {
                        try inner.refs.append(.{
                            .kind = .Import,
                            .literal = module_specifier,
                        });
                    }
                }
            }
        };
        var ctx = Context{
            .refs = &refs,
            .search_module_symbol = search_module_symbol,
            .chk = chk,
            .referencing_file = referencing_file,
            .tree = tree,
        };

        try forEachImport(allocator, program, referencing_file, chk, &ctx, Context.action);
    }

    return refs.toOwnedSlice();
}
