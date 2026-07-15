const std = @import("std");
const ls_utils = @import("utilities.zig");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const binder = @import("../binder/binder.zig");
const checker = @import("../checker/checker.zig");
const collections = @import("../collections/collections.zig");
const compiler = @import("../compiler/program.zig");
const core = @import("../core/core.zig");
const debug = @import("../debug/debug.zig");
const lsconv = @import("lsconv.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const printer = @import("../printer/printer.zig");
const scanner = @import("../scanner/scanner.zig");
const stringutil = @import("../stringutil/stringutil.zig");
const tspath = @import("../tspath/tspath.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const types = @import("../checker/types.zig");
const languageservice = @import("languageservice.zig");

// === types for settings ===
pub const ReferenceUse = enum {
    none,
    other,
    references,
    rename,
};

pub const RefOptions = struct {
    findInStrings: bool = false,
    findInComments: bool = false,
    use: ReferenceUse = .other,
    implementations: bool = false,
    useAliasesForRename: bool = true, // renamed from providePrefixAndSuffixTextForRename. default: true
};

// === types for results ===

pub const RefInfo = struct {
    file: ast.NodeIndex,
    fileName: []const u8,
    reference: ast.FileReferenceIndex,
    unverified: bool,
};

pub const SymbolAndEntries = struct {
    definition: ?*Definition,
    references: []*ReferenceEntry,

    pub fn init(allocator: std.mem.Allocator, kind: DefinitionKind, node: ast.NodeIndex, symbol: ast_gen.SymbolIndex, references: []*ReferenceEntry) !*SymbolAndEntries {
        const self = try allocator.create(SymbolAndEntries);
        const def = try allocator.create(Definition);
        def.* = .{
            .kind = kind,
            .node = node,
            .symbol = symbol,
            .tripleSlashFileRef = null,
        };
        self.* = .{
            .definition = def,
            .references = references,
        };
        return self;
    }

    pub fn references_slice(self: *SymbolAndEntries) []*ReferenceEntry {
        return self.references;
    }

    pub fn definitionNode(self: *SymbolAndEntries) ast.NodeIndex {
        if (self.definition) |def| {
            if (def.node != ast.null_node) {
                return def.node;
            }
            // we'd need to resolve symbol declarations here, handled by caller
        }
        return ast.null_node;
    }

    pub fn definitionSymbol(self: *SymbolAndEntries) ast_gen.SymbolIndex {
        if (self.definition) |def| {
            return def.symbol;
        }
        return 0;
    }

    pub fn canUseDefinitionSymbol(self: *SymbolAndEntries) bool {
        if (self.definition == null) return false;
        const def = self.definition.?;

        switch (def.kind) {
            .symbol, .this => return def.symbol != 0,
            .tripleSlashReference => return false,
            else => return false,
        }
    }
};

pub const DefinitionKind = enum {
    symbol,
    label,
    keyword,
    this,
    string,
    tripleSlashReference,
};

pub const Definition = struct {
    kind: DefinitionKind,
    symbol: ?*ast.Symbol,
    node: ast.NodeIndex,
    tripleSlashFileRef: ?TripleSlashDefinition,
};

pub const TripleSlashDefinition = struct {
    reference: ast.FileReferenceIndex,
    file: ast.NodeIndex,
};

pub const EntryKind = enum {
    none,
    range,
    node,
    stringLiteral,
    searchedLocalFoundProperty,
    searchedPropertyFoundLocal,
};

pub const ReferenceEntry = struct {
    kind: EntryKind,
    node: ast.NodeIndex,
    context: ast.NodeIndex, // optional context
    fileName: []const u8,
    textRange: ?core.TextRange,
    lspRange: ?lsproto.Location,

    pub fn isNodeEntry(self: *ReferenceEntry) bool {
        return self.node != ast.null_node;
    }
};

pub fn getRangeOfEntry(ls: *languageservice.LanguageService, entry: *ReferenceEntry) lsproto.Range {
    return resolveEntry(ls, entry).lspRange.?.range;
}

pub fn getFileNameOfEntry(ls: *languageservice.LanguageService, entry: *ReferenceEntry) lsproto.DocumentUri {
    return resolveEntry(ls, entry).lspRange.?.uri;
}

pub fn getLocationOfEntry(ls: *languageservice.LanguageService, entry: *ReferenceEntry) lsproto.Location {
    return resolveEntry(ls, entry).lspRange.?;
}

pub fn resolveEntry(ls: *languageservice.LanguageService, entry: *ReferenceEntry) *ReferenceEntry {
    if (entry.textRange == null) {
        const sourceFile = ast.getSourceFileOfNode(ls.program, entry.node);
        const textRange = getRangeOfNode(ls, entry.node, sourceFile, ast.null_node);
        entry.textRange = textRange;
        entry.fileName = ls.program.getAstNode(sourceFile).source_file.fileName;
    }
    if (entry.lspRange == null) {
        const location = ls.getMappedLocation(entry.fileName, entry.textRange.?);
        entry.lspRange = location;
    }
    return entry;
}

pub fn newNodeEntryWithKind(allocator: std.mem.Allocator, ls: *languageservice.LanguageService, node: ast.NodeIndex, kind: EntryKind) !*ReferenceEntry {
    const e = try newNodeEntry(allocator, ls, node);
    e.kind = kind;
    return e;
}

pub fn newNodeEntry(allocator: std.mem.Allocator, ls: *languageservice.LanguageService, node: ast.NodeIndex) !*ReferenceEntry {
    const e = try allocator.create(ReferenceEntry);

    // We assume ast.name(node) exists or we fallback to node. This requires looking up the program's AST.
    // For now we just use node.
    const actual_node = node;

    e.* = .{
        .kind = .node,
        .node = actual_node,
        .context = getContextNodeForNodeEntry(ls, actual_node),
        .fileName = "",
        .textRange = null,
        .lspRange = null,
    };
    return e;
}

pub fn getContextNodeForNodeEntry(ls: *languageservice.LanguageService, node: ast.NodeIndex) ast.NodeIndex {
    const fileId = ls.program.getFileId(ls.program.getAstNode(ls.program.ast.getSourceFileOfNode(node)).source_file.fileName).?;
    const tree = ls.getAst(fileId);

    if (ast_utils.isDeclaration(tree, node)) {
        return getContextNode(ls, fileId, node);
    }

    const parent = tree.parents.items[node];
    if (parent == 0) return ast.null_node;

    if (!ast_utils.isDeclaration(tree, parent) and tree.getKind(parent) != .ExportAssignment) {
        if (ast_utils.isInJSFile(tree, node)) {
            var binaryExpression: ast.NodeIndex = 0;
            if (tree.getKind(parent) == .BinaryExpression) {
                binaryExpression = parent;
            } else if (ast_utils.isAccessExpression(tree, parent) and tree.getKind(tree.parents.items[parent]) == .BinaryExpression and tree.getAstNode(tree.parents.items[parent]).binary_expression.left == parent) {
                binaryExpression = tree.parents.items[parent];
            }
            if (binaryExpression != 0 and ast_utils.getAssignmentDeclarationKind(tree, binaryExpression) != .None) {
                return getContextNode(ls, fileId, binaryExpression);
            }
        }

        switch (tree.getKind(parent)) {
            .JsxOpeningElement, .JsxClosingElement => return tree.parents.items[parent],
            .JsxSelfClosingElement, .LabeledStatement, .BreakStatement, .ContinueStatement => return parent,
            .StringLiteral, .NoSubstitutionTemplateLiteral => {
                if (ast_utils.tryGetImportFromModuleSpecifier(tree, node)) |validImport| {
                    const declOrStatement = ast_utils.findAncestor(tree, validImport, struct {
                        fn isDeclOrStmtOrJSDocTag(t: *ast.Ast, n: ast.NodeIndex) bool {
                            return ast_utils.isDeclaration(t, n) or ast_utils.isStatement(t, n) or ast_utils.isJSDocTag(t, n);
                        }
                    }.isDeclOrStmtOrJSDocTag);
                    if (declOrStatement != 0 and ast_utils.isDeclaration(tree, declOrStatement)) {
                        return getContextNode(ls, fileId, declOrStatement);
                    }
                    return declOrStatement;
                }
            },
            else => {},
        }

        const propertyName = ast_utils.findAncestor(tree, node, ast_utils.isComputedPropertyName);
        if (propertyName != 0) {
            return getContextNode(ls, fileId, tree.parents.items[propertyName]);
        }
        return ast.null_node;
    }

    if (ast_utils.getNameOfNode(tree, parent) == node or
        tree.getKind(parent) == .Constructor or
        tree.getKind(parent) == .ExportAssignment or
        ((ast_utils.isImportOrExportSpecifier(tree, parent) or tree.getKind(parent) == .BindingElement) and ast_utils.getPropertyName(tree, parent) == node) or
        (tree.getKind(node) == .DefaultKeyword and ast_utils.hasSyntacticModifier(tree, parent, ast.ModifierFlags.ExportDefault)))
    {
        return getContextNode(ls, fileId, parent);
    }

    return ast.null_node;
}

pub fn getContextNode(ls: *languageservice.LanguageService, fileId: compiler.FileId, node: ast.NodeIndex) ast.NodeIndex {
    if (node == 0) return ast.null_node;
    const tree = ls.getAst(fileId);
    const parent = tree.parents.items[node];
    if (parent == 0) return node;

    switch (tree.getKind(node)) {
        .VariableDeclaration => {
            if (tree.getKind(parent) != .VariableDeclarationList or tree.getAstNode(parent).variable_declaration_list.declarations.len != 1) {
                return node;
            } else if (tree.getKind(tree.parents.items[parent]) == .VariableStatement) {
                return tree.parents.items[parent];
            } else if (ast_utils.isForInOrOfStatement(tree, tree.parents.items[parent])) {
                return getContextNode(ls, fileId, tree.parents.items[parent]);
            }
            return parent;
        },
        .BindingElement => return getContextNode(ls, fileId, tree.parents.items[parent]),
        .ImportSpecifier => return tree.parents.items[tree.parents.items[parent]],
        .ExportSpecifier, .NamespaceImport => return tree.parents.items[parent],
        .ImportClause, .NamespaceExport => return parent,
        .BinaryExpression => {
            if (tree.getKind(parent) == .ExpressionStatement) return parent;
            return node;
        },
        .ForOfStatement, .ForInStatement => {
            return ast.null_node;
        },
        .PropertyAssignment, .ShorthandPropertyAssignment => {
            if (ast_utils.isArrayLiteralOrObjectLiteralDestructuringPattern(tree, parent)) {
                const ancestor = ast_utils.findAncestor(tree, parent, struct {
                    fn check(t: *ast.Ast, n: ast.NodeIndex) bool {
                        return t.getKind(n) == .BinaryExpression or ast_utils.isForInOrOfStatement(t, n);
                    }
                }.check);
                return getContextNode(ls, fileId, ancestor);
            }
            return node;
        },
        .SwitchStatement => {
            return ast.null_node;
        },
        else => return node,
    }
}

pub fn getLspRangeOfNode(ls: *languageservice.LanguageService, fileId: compiler.FileId, node: ast.NodeIndex, endNode: ?ast.NodeIndex, dummy: u32) lsproto.Range {
    _ = dummy;
    const textRange = getRangeOfNode(ls, fileId, node, endNode);
    return ls.converters.toLSPRange(ls.getScript(fileId), textRange);
}

pub fn getRangeOfNode(ls: *languageservice.LanguageService, fileId: compiler.FileId, node: ast.NodeIndex, endNode: ?ast.NodeIndex) ast.TextRange {
    const tree = ls.getAst(fileId);
    _ = endNode;
    return ast.TextRange{ .pos = @intCast(tree.getNodePos(node)), .end = @intCast(tree.getNodeEnd(node)) };
}


pub fn isForRenameWithPrefixAndSuffixText(options: RefOptions) bool {
    return options.use == .rename and options.useAliasesForRename;
}

pub fn skipPastExportOrImportSpecifierOrUnion(tree: *ast.Ast, symbol: *ast.Symbol, node: ast.NodeIndex, chk: *checker.Checker, useLocalSymbolForExportSpecifier: bool) ?*ast.Symbol {
    _ = tree;
    _ = symbol;
    _ = node;
    _ = chk;
    _ = useLocalSymbolForExportSpecifier;
    return null;
}

pub const SymbolAndEntriesData = struct {
    originalNode: ast.NodeIndex,
    symbolsAndEntries: []*SymbolAndEntries,
    position: u32,
};

pub fn symbolAndEntriesToReferences(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.ReferenceParams,
    data: SymbolAndEntriesData,
) !lsproto.ReferencesResponse {
    var locations = std.ArrayList(lsproto.Location).init(allocator);
    errdefer locations.deinit();

    for (data.symbolsAndEntries) |s| {
        const locs = try convertSymbolAndEntriesToLocations(ls, allocator, s, params.context.includeDeclaration);
        try locations.appendSlice(locs);
    }

    return lsproto.ReferencesResponse{
        .LocationsOrNull = .{ .locations = try locations.toOwnedSlice() },
    };
}

pub fn convertSymbolAndEntriesToLocations(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    s: *SymbolAndEntries,
    includeDeclarations: bool,
) ![]lsproto.Location {
    var references = s.references_slice();

    if (!includeDeclarations and s.definition != null) {
        var filtered = std.ArrayList(*ReferenceEntry).init(allocator);
        errdefer filtered.deinit();

        for (references) |entry| {
            if (!isDeclarationOfSymbol(ls.program, entry.node, s.definition.?.symbol)) {
                try filtered.append(entry);
            }
        }
        references = try filtered.toOwnedSlice();
    }

    return convertEntriesToLocations(ls, allocator, references);
}

pub fn isDeclarationOfSymbol(program: *compiler.Program, node: ast.NodeIndex, target: ?*ast.Symbol) bool {
    if (node == ast.null_node or target == null) {
        return false;
    }

    const tree = &program.ast;
    var source: ast.NodeIndex = ast.null_node;

    const decl = ast_utils.getDeclarationFromName(tree, node);

    if (decl != ast.null_node) {
        source = decl;
    } else if (tree.getKind(node) == .DefaultKeyword) {
        source = tree.parents.items[node];
    } else if (ast_utils.isLiteralComputedPropertyDeclarationName(tree, node)) {
        source = tree.parents.items[tree.parents.items[node]];
    } else if (tree.getKind(node) == .ConstructorKeyword and ast_utils.isConstructorDeclaration(tree, tree.parents.items[node])) {
        source = tree.parents.items[tree.parents.items[node]];
    }

    if (source != ast.null_node) {
        for (target.?.declarations) |d| {
            if (d == source) return true;
        }
    }
    return false;
}

pub fn convertEntriesToLocations(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    entries: []const *ReferenceEntry,
) ![]lsproto.Location {
    var locations = try allocator.alloc(lsproto.Location, entries.len);
    for (entries, 0..) |entry_const, i| {
        const entry = @constCast(entry_const);
        locations[i] = getLocationOfEntry(ls, entry);
    }
    return locations;
}

pub fn provideReferences(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.ReferenceParams,
) !lsproto.ReferencesResponse {
    if (try provideSymbolsAndEntries(ls, allocator, params.textDocument.uri, params.position, false, false)) |data| {
        return try symbolAndEntriesToReferences(ls, allocator, params, data);
    }
    return lsproto.ReferencesResponse{ .LocationsOrNull = .{ .locations = null } };
}

pub fn provideSymbolsAndEntries(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    uri: []const u8,
    documentPosition: lsproto.Position,
    isRename: bool,
    implementations: bool,
) !?SymbolAndEntriesData {
    const programAndFile = ls.getProgramAndFile(uri);
    const fileId = programAndFile.file;
    const script = ls.getScript(fileId);
    const position = ls.converters.lineAndCharacterToPosition(script, documentPosition);

    const tree = ls.getAst(fileId);

    var node = ast_utils.getTouchingPropertyName(tree.getNode(ls.getSourceFileNode(fileId)).SourceFile, tree, position);
    if (isRename) {
        node = getAdjustedLocation(ls, node, true, ls.getSourceFileNode(fileId));
    }

    if ((isRename and !nodeIsEligibleForRename(ls, node)) or (implementations and tree.getNodeKind(node) == .SourceFile)) {
        return SymbolAndEntriesData{ .originalNode = node, .symbolsAndEntries = &[_]*SymbolAndEntries{}, .position = position };
    }

    const entries = getSymbolAndEntries(ls, allocator, position, node, ls.program, isRename, implementations);
    if (!implementations) {
        return SymbolAndEntriesData{ .originalNode = node, .symbolsAndEntries = entries, .position = position };
    }

    var implementationEntries = std.ArrayList(*SymbolAndEntries).init(allocator);
    var queue = std.ArrayList(*ReferenceEntry).init(allocator);
    var seenNodes = std.AutoHashMap(ast.NodeIndex, void).init(allocator);

    const addToQueue = struct {
        fn run(q: *std.ArrayList(*ReferenceEntry), e: *std.ArrayList(*SymbolAndEntries), symbolAndEntries: []*SymbolAndEntries) void {
            for (symbolAndEntries) |s| {
                e.append(s) catch unreachable;
                for (s.references) |ref| {
                    q.append(ref) catch unreachable;
                }
            }
        }
    }.run;

    addToQueue(&queue, &implementationEntries, entries);
    while (queue.items.len > 0) {
        const entry = queue.orderedRemove(0);
        if (entry.node != ast.null_node and !seenNodes.contains(entry.node)) {
            seenNodes.put(entry.node, {}) catch unreachable;
        } else if (entry.isNodeEntry()) {
            const nodeStart = ls.getAst(fileId).getNodeStart(entry.node);
            addToQueue(&queue, &implementationEntries, getSymbolAndEntries(ls, allocator, nodeStart, entry.node, ls.program, isRename, implementations));
        }
    }

    return SymbolAndEntriesData{ .originalNode = node, .symbolsAndEntries = try implementationEntries.toOwnedSlice(), .position = position };
}

pub fn getSymbolAndEntries(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    position: u32,
    node: ast.NodeIndex,
    program: *compiler.Program,
    isRename: bool,
    implementations: bool,
) []*SymbolAndEntries {
    var options = RefOptions{ .use = .references, .useAliasesForRename = false, .implementations = false, .findInStrings = false, .findInComments = false };
    if (!isRename) {
        options.use = .references;
        if (implementations) {
            options.implementations = true;
        }
    } else {
        options.use = .rename;
        options.useAliasesForRename = true;
    }
    return getReferencedSymbolsForNode(ls, allocator, position, node, program, program.getSourceFiles(), options);
}

pub fn nodeIsEligibleForRename(ls: *languageservice.LanguageService, node: ast.NodeIndex) bool {
    const fileId = ls.program.getFileId(ls.program.getAstNode(ls.program.ast.getSourceFileOfNode(node)).source_file.fileName).?;
    const tree = ls.getAst(fileId);
    switch (tree.getKind(node)) {
        .Identifier, .StringLiteral, .NoSubstitutionTemplateLiteral, .ThisKeyword, .NumericLiteral, .PrivateIdentifier => return true,
        else => return false,
    }
}

pub fn getReferencedSymbolsForNodePublic(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    position: u32,
    node: ast.NodeIndex,
    sourceFiles: []const ast.NodeIndex,
) ![]*SymbolAndEntries {
    return getReferencedSymbolsForNode(ls, allocator, position, node, ls.program, sourceFiles, RefOptions{
        .use = .references,
        .useAliasesForRename = true,
    });
}

pub fn getReferencedSymbolsForNode(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    position: u32,
    node_arg: ast.NodeIndex,
    program: *compiler.Program,
    sourceFiles: []const ast.NodeIndex,
    options: RefOptions,
) ![]*SymbolAndEntries {
    var node = node_arg;

    // We assume ast_utils functions will be properly implemented.
    if (options.use == .references or options.use == .rename) {
        node = getAdjustedLocation(ls, node, options.use == .rename, ast.getSourceFileOfNode(ls.program, node));
    }

    const chk = program.getTypeChecker();

    if (program.ast.getNodeKind(node) == .SourceFile) {
        const resolvedRef = getReferenceAtPosition(ls, node, position, program);
        if (resolvedRef.file == ast.null_node) {
            return &[_]*SymbolAndEntries{};
        }
        return &[_]*SymbolAndEntries{};
    }

    if (!options.implementations) {
        if (getReferencedSymbolsSpecial(ls, allocator, node, sourceFiles)) |special| {
            return special;
        }
    }

    const parent = program.ast.parents.items[node];
    const parent_name = getName(ls, parent);
    const symbol_node = if (program.ast.getNodeKind(node) == .Constructor and parent_name != 0) parent_name else node;
    const symbol = chk.getSymbolAtLocation(symbol_node);

    if (symbol == 0) {
        if (!options.implementations and ast_utils.isStringLiteralLike(&ls.program.ast, node)) {
            if (isModuleSpecifierLike(ls, node)) {
                // not implemented
            }
            return getReferencesForStringLiteral(ls, allocator, node, sourceFiles, chk);
        }
        return &[_]*SymbolAndEntries{};
    }

    // if (std.mem.eql(u8, symbol.?.name, ast_utils.InternalSymbolNameExportEquals)) { ... }

    const moduleReferences = getReferencedSymbolsForModuleIfDeclaredBySourceFile(ls, allocator, symbol.?, program, sourceFiles, chk, options);
    if (moduleReferences.len > 0) { // and (symbol.?.flags & ast_utils.SymbolFlags.Transient) == 0
        return moduleReferences;
    }

    const aliasedSymbol = getMergedAliasedSymbolOfNamespaceExportDeclaration(ls, node, symbol.?, chk);
    const moduleReferencesOfExportTarget = getReferencedSymbolsForModuleIfDeclaredBySourceFile(ls, allocator, aliasedSymbol.?, program, sourceFiles, chk, options);

    const references = getReferencedSymbolsForSymbol(ls, allocator, program, symbol.?, node, sourceFiles, chk, options);
    return mergeReferences(ls, allocator, program, moduleReferences, references, moduleReferencesOfExportTarget);
}

// ---- Stubs for dependencies of getReferencedSymbolsForNode ----

pub fn getAdjustedLocation(ls: *languageservice.LanguageService, node: ast.NodeIndex, isForRename: bool, sourceFile: ast.NodeIndex) ast.NodeIndex {
    return ls_utils.getAdjustedLocation(&ls.program.ast, node, isForRename, sourceFile);
}

pub const ResolvedRef = struct {
    file: ast.NodeIndex,
};

pub fn getReferenceAtPosition(ls: *languageservice.LanguageService, node: ast.NodeIndex, position: u32, program: *compiler.Program) ResolvedRef {
    _ = program;
    const tree = ls.getAst(node);
    const sfNodeIndex = ast_utils.getSourceFileOfNode(tree, node);
    if (sfNodeIndex == 0) return .{ .file = 0 };
    for (tree.referencedFiles.items) |ref| {
        if (position >= ref.pos and position < ref.end) {
            return .{ .file = sfNodeIndex }; // Simplified for now
        }
    }
    for (tree.typeReferenceDirectives.items) |ref| {
        if (position >= ref.pos and position < ref.end) {
            return .{ .file = sfNodeIndex }; // Simplified for now
        }
    }
    for (tree.libReferenceDirectives.items) |ref| {
        if (position >= ref.pos and position < ref.end) {
            return .{ .file = sfNodeIndex }; // Simplified for now
        }
    }
    return .{ .file = 0 };
}


pub fn isTypeKeyword(kind: ast.Kind) bool {
    switch (kind) {
        .AnyKeyword, .UnknownKeyword, .NumberKeyword, .BigIntKeyword, .ObjectKeyword, .BooleanKeyword, .StringKeyword, .SymbolKeyword, .ThisKeyword, .VoidKeyword, .UndefinedKeyword, .NullKeyword, .NeverKeyword => return true,
        else => return false,
    }
}

pub fn isReadonlyTypeOperator(tree: *ast.Ast, node: ast.NodeIndex) bool {
    const parent = tree.getNodeParent(node);
    return parent != 0 and tree.getNodeKind(parent) == .TypeOperator and tree.getNode(parent).TypeOperator.operator == .ReadonlyKeyword;
}

pub fn getAllReferencesForKeyword(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, sourceFiles: []const ast.NodeIndex, keywordKind: ast.Kind, filterReadOnlyTypeOperator: bool) !?[]*SymbolAndEntries {
    _ = ls;
    _ = sourceFiles;
    _ = keywordKind;
    _ = filterReadOnlyTypeOperator;
    var references = std.ArrayList(*ReferenceEntry).init(allocator);
    defer references.deinit();

    // Just an empty fallback, not fully implemented for text search
    if (references.items.len == 0) return null;
    return null;
}

pub fn getAllReferencesForImportMeta(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, sourceFiles: []const ast.NodeIndex) !?[]*SymbolAndEntries {
    _ = ls;
    _ = allocator;
    _ = sourceFiles;
    return null;
}

pub fn isJumpStatementTarget(tree: *ast.Ast, node: ast.NodeIndex) bool {
    const parent = tree.getNodeParent(node);
    if (parent == 0) return false;
    const p_kind = tree.getNodeKind(parent);
    if (p_kind == .BreakStatement or p_kind == .ContinueStatement) {
        const label = if (p_kind == .BreakStatement) tree.getNode(parent).BreakStatement.Label else tree.getNode(parent).ContinueStatement.Label;
        return label == node;
    }
    return false;
}

pub fn getTargetLabel(tree: *ast.Ast, referenceNode: ast.NodeIndex, labelName: []const u8) ast.NodeIndex {
    _ = tree;
    _ = referenceNode;
    _ = labelName;
    return 0; // simple fallback
}

pub fn getLabelReferencesInNode(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, container: ast.NodeIndex, targetLabel: ast.NodeIndex) !?[]*SymbolAndEntries {
    _ = ls;
    _ = allocator;
    _ = container;
    _ = targetLabel;
    return null;
}

pub fn isLabelOfLabeledStatement(tree: *ast.Ast, node: ast.NodeIndex) bool {
    const parent = tree.getNodeParent(node);
    return parent != 0 and tree.getNodeKind(parent) == .LabeledStatement and tree.getNode(parent).LabeledStatement.label == node;
}

pub fn isThis(tree: *ast.Ast, node: ast.NodeIndex) bool {
    return tree.getNodeKind(node) == .ThisKeyword;
}

pub fn getReferencesForThisKeyword(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, node: ast.NodeIndex, sourceFiles: []const ast.NodeIndex) !?[]*SymbolAndEntries {
    _ = ls;
    _ = allocator;
    _ = node;
    _ = sourceFiles;
    return null;
}

pub fn getReferencesForSuperKeyword(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, node: ast.NodeIndex) !?[]*SymbolAndEntries {
    _ = ls;
    _ = allocator;
    _ = node;
    return null;
}

pub fn getReferencedSymbolsSpecial(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, node: ast.NodeIndex, sourceFiles: []const ast.NodeIndex) ?[]*SymbolAndEntries {
    const tree = &ls.program.ast;
    const kind = tree.getNodeKind(node);
    const parent = tree.getNodeParent(node);

    if (isTypeKeyword(kind)) {
        if (kind == .VoidKeyword and parent != 0 and tree.getNodeKind(parent) == .VoidExpression) {
            return null;
        }
        if (kind == .ReadonlyKeyword and !isReadonlyTypeOperator(tree, node)) {
            return null;
        }
        return (getAllReferencesForKeyword(ls, allocator, sourceFiles, kind, kind == .ReadonlyKeyword) catch null);
    }

    if (parent != 0 and tree.getNodeKind(parent) == .MetaProperty) {
        const meta = tree.getNode(parent).MetaProperty;
        if (meta.keyword == .ImportKeyword and meta.name == node) {
            return (getAllReferencesForImportMeta(ls, allocator, sourceFiles) catch null);
        }
    }

    if (kind == .StaticKeyword and parent != 0 and tree.getNodeKind(parent) == .ClassStaticBlockDeclaration) {
        // Return a mock
        return null;
    }

    if (isJumpStatementTarget(tree, node)) {
        const text = ast_utils.getText(tree, node);
        const labelDef = getTargetLabel(tree, parent, text);
        if (labelDef != 0) {
            return (getLabelReferencesInNode(ls, allocator, tree.getNodeParent(labelDef), labelDef) catch null);
        }
        return null;
    }

    if (isLabelOfLabeledStatement(tree, node)) {
        return (getLabelReferencesInNode(ls, allocator, parent, node) catch null);
    }

    if (isThis(tree, node)) {
        return (getReferencesForThisKeyword(ls, allocator, node, sourceFiles) catch null);
    }

    if (kind == .SuperKeyword) {
        return (getReferencesForSuperKeyword(ls, allocator, node) catch null);
    }

    return null;
}


pub fn getName(ls: *languageservice.LanguageService, node: ast.NodeIndex) ast.NodeIndex {
    return ast_utils.getName(&ls.program.ast, node);
}

pub fn isModuleSpecifierLike(ls: *languageservice.LanguageService, node: ast.NodeIndex) bool {
    return ls_utils.isModuleSpecifierLike(&ls.program.ast, node);
}

pub fn getReferencesForStringLiteral(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, node: ast.NodeIndex, sourceFiles: []const ast.NodeIndex, chk: *checker.Checker) ![]*SymbolAndEntries {
    const t = getContextualTypeFromParentOrAncestorTypeNode(ls, node, chk);
    const nodeText = ast_utils.getText(&ls.program.ast, node);

    var references = std.ArrayList(*ReferenceEntry).init(allocator);
    errdefer references.deinit();

    for (sourceFiles) |sf| {
        const possibleReferences = getPossibleSymbolReferenceNodes(ls, allocator, sf, nodeText);
        for (possibleReferences) |ref| {
            if (ast_utils.isStringLiteralLike(&ls.program.ast, ref) and std.mem.eql(u8, ast_utils.getText(&ls.program.ast, ref), nodeText)) {
                if (t != null) {
                    const refType = getContextualTypeFromParentOrAncestorTypeNode(ls, ref, chk);
                    if (t.? != chk.getStringType() and (t.? == refType.? or isStringLiteralPropertyReference(ls, ref, chk))) {
                        try references.append(try newNodeEntryWithKindNoLs(allocator, ref, EntryKind.stringLiteral));
                    }
                } else {
                    if (ls.program.ast.getNodeKind(ref) == .NoSubstitutionTemplateLiteral and !rangeIsOnSingleLine(ls, ref, sf)) {
                        continue;
                    }
                    try references.append(try newNodeEntryWithKindNoLs(allocator, ref, EntryKind.stringLiteral));
                }
            }
        }
    }

    const definition = try allocator.create(Definition);
    definition.* = Definition{
        .kind = DefinitionKind.string,
        .node = node,
        .symbol = null,
        .tripleSlashFileRef = null,
    };

    const sae = try allocator.create(SymbolAndEntries);
    sae.* = SymbolAndEntries{
        .definition = definition,
        .references = try references.toOwnedSlice(),
    };

    var result = try allocator.alloc(*SymbolAndEntries, 1);
    result[0] = sae;
    return result;
}

fn walkUpParenthesizedExpressions(tree: *ast.Ast, node_in: ast.NodeIndex) ast.NodeIndex {
    var node = node_in;
    while (node != 0 and tree.getNodeKind(node) == .ParenthesizedExpression) {
        node = tree.getNodeParent(node);
    }
    return node;
}

fn isEqualityOperatorKind(kind: std.meta.Tag(ast_gen.NodeData)) bool {
    switch (kind) {
        .EqualsEqualsEqualsToken, .EqualsEqualsToken,
        .ExclamationEqualsEqualsToken, .ExclamationEqualsToken => return true,
        else => return false,
    }
}

fn getSwitchedType(tree: *ast.Ast, caseClause: ast.NodeIndex, chk: *checker.Checker) types.TypeIndex {
    const parent = tree.getNodeParent(caseClause);
    if (parent == 0) return 0;
    const grandparent = tree.getNodeParent(parent);
    if (grandparent == 0) return 0;

    if (tree.getNodeKind(grandparent) == .SwitchStatement) {
        const switchStmt = tree.getNode(grandparent).SwitchStatement;
        return chk.getTypeAtLocation(switchStmt.Expression);
    }
    return 0;
}

fn getContextualTypeFromParent(tree: *ast.Ast, node: ast.NodeIndex, chk: *checker.Checker, contextFlags: u32) types.TypeIndex {
    const parent = walkUpParenthesizedExpressions(tree, tree.getNodeParent(node));
    if (parent == 0) return 0;

    switch (tree.getNodeKind(parent)) {
        .NewExpression => {
            return chk.getContextualType(parent, contextFlags);
        },
        .BinaryExpression => {
            const binExpr = tree.getNode(parent).BinaryExpression;
            if (isEqualityOperatorKind(tree.getNodeKind(binExpr.OperatorToken))) {
                const expr = if (node == binExpr.Right) binExpr.Left else binExpr.Right;
                return chk.getTypeAtLocation(expr);
            }
            return chk.getContextualType(node, contextFlags);
        },
        .CaseClause => {
            return getSwitchedType(tree, parent, chk);
        },
        else => {
            return chk.getContextualType(node, contextFlags);
        }
    }
}

fn isTypeElement(kind: std.meta.Tag(ast_gen.NodeData)) bool {
    switch (kind) {
        .ConstructSignature,
        .CallSignature,
        .PropertySignature,
        .MethodSignature,
        .IndexSignature,
        .GetAccessor,
        .SetAccessor => return true,
        else => return false,
    }
}

fn isTypeNode(kind: std.meta.Tag(ast_gen.NodeData)) bool {
    switch (kind) {
        .AnyKeyword, .UnknownKeyword, .NumberKeyword, .BigIntKeyword, .ObjectKeyword,
        .BooleanKeyword, .StringKeyword, .SymbolKeyword, .VoidKeyword, .UndefinedKeyword,
        .NeverKeyword, .IntrinsicKeyword, .ExpressionWithTypeArguments, .JSDocAllType,
        .JSDocNullableType, .JSDocNonNullableType, .JSDocOptionalType, .JSDocVariadicType,
        .TypePredicate, .TypeReference, .FunctionType, .ConstructorType, .TypeQuery,
        .TypeLiteral, .ArrayType, .TupleType, .OptionalType, .RestType, .UnionType,
        .IntersectionType, .ConditionalType, .InferType, .ParenthesizedType, .ThisType,
        .TypeOperator, .IndexedAccessType, .MappedType, .LiteralType, .NamedTupleMember,
        .TemplateLiteralType, .TemplateLiteralTypeSpan, .ImportType => return true,
        else => return false,
    }
}

fn getAncestorTypeNode(tree: *ast.Ast, node: ast.NodeIndex) ast.NodeIndex {
    var lastTypeNode: ast.NodeIndex = 0;
    var current = node;
    while (current != 0) {
        if (isTypeNode(tree.getNodeKind(current))) {
            lastTypeNode = current;
        }
        const parent = tree.getNodeParent(current);
        if (parent == 0) break;
        const parentKind = tree.getNodeKind(parent);
        
        if (parentKind != .QualifiedName and !isTypeNode(parentKind) and !isTypeElement(parentKind)) {
            break;
        }
        current = parent;
    }
    return lastTypeNode;
}

pub fn getContextualTypeFromParentOrAncestorTypeNode(ls: *languageservice.LanguageService, node: ast.NodeIndex, chk: *checker.Checker) types.TypeIndex {
    _ = ls;
    const tree = &chk.program.ast;
    const flags = tree.getNodeFlags(node);
    if ((flags & ast_utils.NodeFlags.JSDoc) != 0 and (flags & ast_utils.NodeFlags.JavaScriptFile) == 0) {
        return 0;
    }

    const contextualType = getContextualTypeFromParent(tree, node, chk, 0);
    if (contextualType != 0) {
        return contextualType;
    }

    const ancestorTypeNode = getAncestorTypeNode(tree, node);
    if (ancestorTypeNode != 0) {
        return chk.getTypeAtLocation(ancestorTypeNode);
    }

    return 0;
}

pub fn getPossibleSymbolReferenceNodes(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, sourceFile: ast.NodeIndex, textArg: []const u8) []const ast.NodeIndex {
    if (textArg.len == 0) return &[_]ast.NodeIndex{};
    
    const tree = &ls.program.ast;
    const fileId = ls.program.getFileId(tree.getAstNode(sourceFile).source_file.fileName).?;
    const script = ls.getScript(fileId);
    const text = script.content;

    var positions = std.ArrayList(u32).init(allocator);

    const startPos = tree.getStart(sourceFile);
    const endPos = tree.getEnd(sourceFile);

    var position: ?usize = std.mem.indexOf(u8, text[startPos..], textArg);
    if (position != null) {
        position.? += startPos;
    }

    while (position != null and position.? < endPos) {
        const endPosition = position.? + textArg.len;

        if ((position.? == 0 or !ast_utils.isIdentifierPart(text[position.? - 1])) and
            (endPosition == text.len or !ast_utils.isIdentifierPart(text[endPosition]))) {
            positions.append(@intCast(position.?)) catch {};
        }

        const startIndex = position.? + textArg.len + 1;
        if (startIndex > text.len) break;

        const foundIndex = std.mem.indexOf(u8, text[startIndex..], textArg);
        if (foundIndex != null) {
            position = startIndex + foundIndex.?;
        } else {
            break;
        }
    }

    var nodes = std.ArrayList(ast.NodeIndex).init(allocator);
    for (positions.items) |pos| {
        const referenceLocation = ast_utils.getTouchingPropertyName(tree, sourceFile, pos);
        if (referenceLocation != sourceFile) {
            nodes.append(referenceLocation) catch {};
        }
    }
    positions.deinit();

    return nodes.toOwnedSlice() catch &[_]ast.NodeIndex{};
}

pub fn isStringLiteralPropertyReference(ls: *languageservice.LanguageService, node: ast.NodeIndex, chk: *checker.Checker) bool {
    const tree = &ls.program.ast;
    const parent = tree.parents.items[node];
    if (ast_utils.isPropertySignatureDeclaration(tree, parent)) {
        return chk.getPropertyOfType(@intCast(chk.getTypeAtLocation(tree.parents.items[parent])), ast_utils.getText(tree, node)) != 0;
    }
    return false;
}

pub fn rangeIsOnSingleLine(ls: *languageservice.LanguageService, node: ast.NodeIndex, sourceFile: ast.NodeIndex) bool {
    const tree = &ls.program.ast;
    const start = tree.getStart(node);
    const end = tree.getEnd(node);
    const fileId = ls.program.getFileId(tree.getAstNode(sourceFile).source_file.fileName).?;
    const script = ls.getScript(fileId);
    const startPos = ls.converters.positionToLineAndCharacter(script, start);
    const endPos = ls.converters.positionToLineAndCharacter(script, end);
    return startPos.line == endPos.line;
}

pub fn newNodeEntryWithKindNoLs(allocator: std.mem.Allocator, node: ast.NodeIndex, kind: EntryKind) !*ReferenceEntry {
    const entry = try allocator.create(ReferenceEntry);
    entry.* = ReferenceEntry{
        .kind = kind,
        .node = node,
        .fileName = "", // dummy
        .textRange = null,
        .lspRange = null,
        .context = ast.null_node,
    };
    return entry;
}

pub fn getReferencedSymbolsForModule(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, program: *compiler.Program, symbol: *ast.Symbol, excludeImportTypeOfExportEquals: bool, sourceFiles: []const ast.NodeIndex) ![]*SymbolAndEntries {
    _ = ls;
    _ = allocator;
    _ = program;
    _ = symbol;
    _ = excludeImportTypeOfExportEquals;
    _ = sourceFiles;
    return &[_]*SymbolAndEntries{};
}

pub fn getReferencedSymbolsForModuleIfDeclaredBySourceFile(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    symbol_opt: ?*ast.Symbol,
    program: *compiler.Program,
    sourceFiles: []const ast.NodeIndex,
    chk: *checker.Checker,
    options: RefOptions,
) []*SymbolAndEntries {
    if (symbol_opt == null) return &[_]*SymbolAndEntries{};
    var symbol = symbol_opt.?;

    if (symbol.flags & ast.SymbolFlags.Module == 0 or symbol.declarations.len == 0) {
        return &[_]*SymbolAndEntries{};
    }

    var moduleSourceFileName: ?[]const u8 = null;
    for (symbol.declarations) |decl| {
        if (program.ast.getKind(decl) == .SourceFile) {
            moduleSourceFileName = program.ast.getAstNode(decl).source_file.fileName;
            break;
        }
    }

    if (moduleSourceFileName == null) {
        return &[_]*SymbolAndEntries{};
    }

    var exportEquals: ?*ast.Symbol = null;
    if (symbol.exports != null) {
        if (symbol.exports.?.get("export=")) |exp_id| {
            exportEquals = program.ast.symbols.items[exp_id];
        }
    }

    const moduleReferences = getReferencedSymbolsForModule(ls, allocator, program, symbol, exportEquals != null, sourceFiles) catch &[_]*SymbolAndEntries{};

    _ = chk;
    _ = options;
    if (exportEquals == null or exportEquals.?.flags & ast.SymbolFlags.Alias == 0) {
        var foundSourceFile = false;
        for (sourceFiles) |sf| {
            if (std.mem.eql(u8, program.ast.getAstNode(sf).source_file.fileName, moduleSourceFileName.?)) {
                foundSourceFile = true;
                break;
            }
        }

        if (foundSourceFile) {
            if (exportEquals != null) {
                if (exportEquals.?.flags & ast.SymbolFlags.ExportValue != 0 and exportEquals.?.exportSymbol != 0) {
                    exportEquals = program.ast.symbols.items[exportEquals.?.exportSymbol];
                }
            }
            var newRefs = std.ArrayList(*SymbolAndEntries).init(allocator);
            newRefs.appendSlice(moduleReferences) catch {};
            
            const moduleSymbolAndEntries = allocator.create(SymbolAndEntries) catch @panic("OOM");
            moduleSymbolAndEntries.* = .{
                .definition_kind = .Keyword,
                .node = symbol.declarations[0],
                .symbol = symbol,
                .entries = &[_]*ReferenceEntry{},
            };
            
            if (exportEquals != null) {
                const exportSymbolAndEntries = allocator.create(SymbolAndEntries) catch @panic("OOM");
                exportSymbolAndEntries.* = .{
                    .definition_kind = .Keyword,
                    .node = exportEquals.?.declarations[0],
                    .symbol = exportEquals.?,
                    .entries = &[_]*ReferenceEntry{},
                };
                newRefs.append(exportSymbolAndEntries) catch {};
            }
            newRefs.append(moduleSymbolAndEntries) catch {};
            return newRefs.toOwnedSlice() catch moduleReferences;
        }
    }

    return moduleReferences;
}

pub fn getMergedAliasedSymbolOfNamespaceExportDeclaration(ls: *languageservice.LanguageService, node: ast.NodeIndex, symbol: *ast.Symbol, chk: *checker.Checker) ?*ast.Symbol {
    const tree = &ls.program.ast;
    const parent = tree.parents.items[node];
    if (parent != 0 and tree.getNodeKind(parent) == .NamespaceExportDeclaration) {
        if (chk.resolveAlias(symbol)) |aliasedSymbol| {
            const targetSymbol = chk.getMergedSymbol(aliasedSymbol);
            if (aliasedSymbol != targetSymbol) {
                return targetSymbol;
            }
        }
    }
    return null;
}

pub const ImpExpKind = enum {
    unknown,
    import,
    @"export",
};

pub const RefSearch = struct {
    comingFrom: ImpExpKind,
    symbol: *ast.Symbol,
    text: []const u8,
    escapedText: []const u8,
    parents: []*ast.Symbol,
    allSearchSymbols: []const *ast.Symbol,

    pub fn includes(self: *const RefSearch, sym: *ast.Symbol) bool {
        for (self.allSearchSymbols) |s| {
            if (s.id == sym.id) return true;
        }
        return false;
    }
};

pub const ExportKind = enum {
    default,
    named,
};

pub const ExportInfo = struct {
    exportingModuleSymbol: *ast.Symbol,
    exportKind: ExportKind,
};

pub const InheritKey = struct {
    symbol: *ast.Symbol,
    parent: *ast.Symbol,
};

pub const State = struct {
    allocator: std.mem.Allocator,
    program: *compiler.Program,
    sourceFiles: []const ast.NodeIndex,
    chk: *checker.Checker,
    searchMeaning: u32,
    options: RefOptions,

    result: []*SymbolAndEntries,

    // internal state
    sourceFileToSeenSymbols: std.AutoHashMap(ast.NodeIndex, std.AutoHashMap(*ast.Symbol, void)),
    inheritsFromCache: std.AutoHashMap(InheritKey, bool),

    pub fn deinit(self: *State) void {
        var it = self.sourceFileToSeenSymbols.valueIterator();
        while (it.next()) |*set| {
            set.deinit();
        }
        self.sourceFileToSeenSymbols.deinit();
        self.inheritsFromCache.deinit();
    }

    pub fn getReferencesAtExportSpecifier(self: *State, name: ast.NodeIndex, symbol: *ast.Symbol, exportSpecifier: ast.NodeIndex, search: *RefSearch, addReferencesHere: bool, alwaysGetReferences: bool) void {
        _ = self;
        _ = name;
        _ = symbol;
        _ = exportSpecifier;
        _ = search;
        _ = addReferencesHere;
        _ = alwaysGetReferences;
    }
    pub fn addReference(self: *State, node: ast.NodeIndex, symbol: *ast.Symbol, kind: EntryKind) void {
        _ = self;
        _ = node;
        _ = symbol;
        _ = kind;
    }
    pub fn searchForImportsOfExport(self: *State, node: ast.NodeIndex, symbol: *ast.Symbol, info: *ExportInfo) void {
        _ = self;
        _ = node;
        _ = symbol;
        _ = info;
    }
    pub fn createSearch(self: *State, location: ast.NodeIndex, symbol: *ast.Symbol, comingFrom: ImpExpKind, text_arg: []const u8, searchSymbols: []const *ast.Symbol) *RefSearch {
        var text = text_arg;
        if (text.len == 0) {
            var localSym = getLocalSymbolForExportDefault(self.program, symbol);
            if (localSym == null) {
                localSym = getNonModuleSymbolOfMergedModuleSymbol(self.program, symbol);
                if (localSym == null) localSym = symbol;
            }
            text = stringutil.stripQuotes(localSym.?.name);
        }

        var allSearchSymbols = searchSymbols;
        if (allSearchSymbols.len == 0) {
            var res = self.allocator.alloc(*ast.Symbol, 1) catch unreachable;
            res[0] = symbol;
            allSearchSymbols = res;
        }

        const search = self.allocator.create(RefSearch) catch unreachable;
        search.* = RefSearch{
            .comingFrom = comingFrom,
            .symbol = symbol,
            .text = text,
            .escapedText = text,
            .parents = &[_]*ast.Symbol{},
            .allSearchSymbols = allSearchSymbols,
        };

        if (self.options.implementations and location != ast.null_node) {
            // search.parents = getParentSymbolsOfPropertyAccess(location, symbol, state.checker)
        }

        return search;
    }



    pub fn populateSearchSymbolSet(self: *State, symbol: *ast.Symbol, location: ast.NodeIndex, isForRename: bool, useAliasesForRename: bool, implementations: bool) []const *ast.Symbol {
        _ = useAliasesForRename;

        if (location == ast.null_node) {
            var res = self.allocator.alloc(*ast.Symbol, 1) catch return &[_]*ast.Symbol{};
            res[0] = symbol;
            return res;
        }
        var result = std.ArrayList(*ast.Symbol).init(self.allocator);
        
        const Ctx = struct {
            result: *std.ArrayList(*ast.Symbol),
            symbol: *ast.Symbol,
            implementations: bool,
            program_ast: *const ast.Tree,

            fn cb(ctx: *@This(), sym: *ast.Symbol, root: ?*ast.Symbol, base: ?*ast.Symbol) !?*ast.Symbol {
                var finalBase = base;
                if (finalBase) |b| {
                    if (ls_utils.isStaticSymbol(ctx.program_ast, ctx.symbol) != ls_utils.isStaticSymbol(ctx.program_ast, b)) {
                        finalBase = null;
                    }
                }
                try ctx.result.append(finalBase orelse root orelse sym);
                return null;
            }

            fn allowBaseTypes(ctx: *@This(), _: *ast.Symbol) bool {
                return !ctx.implementations;
            }
        };

        var ctx = Ctx{
            .result = &result,
            .symbol = symbol,
            .implementations = implementations,
            .program_ast = &self.program.ast,
        };

        const providePrefixAndSuffixText = false; // Add parameter later if needed
        _ = self.forEachRelatedSymbol(
            &ctx,
            symbol,
            location,
            isForRename,
            !(isForRename and providePrefixAndSuffixText),
            Ctx.cb,
            Ctx.allowBaseTypes,
        ) catch null;
        
        return result.toOwnedSlice() catch return &[_]*ast.Symbol{};
    }

    pub fn forEachRelatedSymbol(
        self: *State,
        context: anytype,
        symbol: *ast.Symbol,
        location: ast.NodeIndex,
        isForRenamePopulateSearchSymbolSet: bool,
        onlyIncludeBindingElementAtReferenceLocation: bool,
        comptime cbSymbol: anytype,
        comptime allowBaseTypes: anytype,
    ) !struct { ?*ast.Symbol, EntryKind } {
        const FromRootContext = struct {
            state: *State,
            context: @TypeOf(context),
            sym_capture: *ast.Symbol,
            
            fn call(ctx: *const @This(), sym: *ast.Symbol) !?*ast.Symbol {
                const rootSymbols = ctx.state.checker.getRootSymbols(ctx.state.allocator, sym);
                for (rootSymbols) |rootSymbol| {
                    if (try cbSymbol(ctx.context, sym, rootSymbol, null)) |result| {
                        return result;
                    }
                    
                    if (rootSymbol.Parent != null and (rootSymbol.Flags & (checker.SymbolFlags.Class | checker.SymbolFlags.Interface)) != 0 and allowBaseTypes(ctx.context, rootSymbol)) {
                        const BaseTypeContext = struct {
                            inner_ctx: *const @This(),
                            inner_sym: *ast.Symbol,
                            inner_root: *ast.Symbol,
                            
                            fn cb(baseCtx: *const @This(), base: *ast.Symbol) !?*ast.Symbol {
                                return cbSymbol(baseCtx.inner_ctx.context, baseCtx.inner_sym, baseCtx.inner_root, base);
                            }
                        };
                        const baseTypeCtx = BaseTypeContext{
                            .inner_ctx = ctx,
                            .inner_sym = sym,
                            .inner_root = rootSymbol,
                        };
                        
                        if (try ls_utils.getPropertySymbolsFromBaseTypes(
                            ctx.state.allocator,
                            &ctx.state.program.ast,
                            ctx.state.program.ast.getNode(rootSymbol.Parent.?).symbol orelse return null,
                            rootSymbol.Name,
                            ctx.state.checker,
                            &baseTypeCtx,
                            BaseTypeContext.cb,
                        )) |result| {
                            return result;
                        }
                    }
                }
                return null;
            }
        };

        const fromRootCtx = FromRootContext{
            .state = self,
            .context = context,
            .sym_capture = symbol,
        };

        if (ls_utils.getContainingObjectLiteralElement(&self.program.ast, location)) |containingObjectLiteralElement| {
            if (self.checker.getShorthandAssignmentValueSymbol(self.program.ast.nodeParent(location).?)) |shorthandValueSymbol| {
                if (isForRenamePopulateSearchSymbolSet) {
                    if (try cbSymbol(context, shorthandValueSymbol, null, null)) |res| {
                        return .{ res, .searchedLocalFoundProperty };
                    }
                }
            }
            if (self.checker.getContextualType(self.program.ast.nodeParent(containingObjectLiteralElement).?, 0)) |contextualType| {
                const symbols = self.checker.getPropertySymbolsFromContextualType(self.allocator, containingObjectLiteralElement, contextualType, true);
                for (symbols) |sym| {
                    if (try fromRootCtx.call(sym)) |res| {
                        return .{ res, .searchedPropertyFoundLocal };
                    }
                }
            }
            if (self.checker.getPropertySymbolOfDestructuringAssignment(location)) |propertySymbol| {
                if (try cbSymbol(context, propertySymbol, null, null)) |res| {
                    return .{ res, .searchedPropertyFoundLocal };
                }
            }
            if (self.checker.getShorthandAssignmentValueSymbol(self.program.ast.nodeParent(location).?)) |shorthandValueSymbol| {
                if (try cbSymbol(context, shorthandValueSymbol, null, null)) |res| {
                    return .{ res, .searchedLocalFoundProperty };
                }
            }
        }

        if (self.checker.getMergedAliasedSymbolOfNamespaceExportDeclaration(location, symbol)) |aliasedSymbol| {
            if (try cbSymbol(context, aliasedSymbol, null, null)) |res| {
                return .{ res, .node };
            }
        }

        if (try fromRootCtx.call(symbol)) |res| {
            return .{ res, .node };
        }

        if (symbol.ValueDeclaration != null and ast_utils.isParameterPropertyDeclaration(&self.program.ast, symbol.ValueDeclaration.?, self.program.ast.nodeParent(symbol.ValueDeclaration.?).?)) {
            const paramProps = self.checker.getSymbolsOfParameterPropertyDeclaration(symbol.ValueDeclaration.?, symbol.Name);
            const paramProp1 = paramProps[0];
            const paramProp2 = paramProps[1];
            const isFuncScoped = (symbol.Flags & checker.SymbolFlags.FunctionScopedVariable) != 0;
            if (try fromRootCtx.call(if (isFuncScoped) paramProp2 else paramProp1)) |res| {
                return .{ res, .node };
            }
        }

        if (ast_utils.getDeclarationOfKind(&self.program.ast, symbol, .ExportSpecifier)) |exportSpecifier| {
            if (!isForRenamePopulateSearchSymbolSet or ast_utils.propertyName(&self.program.ast, exportSpecifier) == null) {
                if (self.checker.getExportSpecifierLocalTargetSymbol(exportSpecifier)) |localSymbol| {
                    if (try cbSymbol(context, localSymbol, null, null)) |res| {
                        return .{ res, .node };
                    }
                }
            }
        }

        if (!isForRenamePopulateSearchSymbolSet) {
            var bindingElementPropertySymbol: ?*ast.Symbol = null;
            if (onlyIncludeBindingElementAtReferenceLocation) {
                if (self.program.ast.nodeParent(location)) |parent| {
                    if (!ls_utils.isObjectBindingElementWithoutPropertyName(&self.program.ast, parent)) {
                        return .{ null, .none };
                    }
                    bindingElementPropertySymbol = ls_utils.getPropertySymbolFromBindingElement(&self.program.ast, self.checker, parent);
                }
            } else {
                bindingElementPropertySymbol = ls_utils.getPropertySymbolOfObjectBindingPatternWithoutPropertyName(&self.program.ast, symbol, self.checker);
            }
            if (bindingElementPropertySymbol) |propSym| {
                if (try fromRootCtx.call(propSym)) |res| {
                    return .{ res, .searchedPropertyFoundLocal };
                }
            }
            return .{ null, .none };
        }

        const includeOriginalSymbolOfBindingElement = onlyIncludeBindingElementAtReferenceLocation;

        if (includeOriginalSymbolOfBindingElement) {
            if (ls_utils.getPropertySymbolOfObjectBindingPatternWithoutPropertyName(&self.program.ast, symbol, self.checker)) |bindingElementPropertySymbol| {
                if (try fromRootCtx.call(bindingElementPropertySymbol)) |res| {
                    return .{ res, .searchedPropertyFoundLocal };
                }
            }
        }
        return .{ null, .none };
    }

    pub fn getReferencesInContainerOrFiles(self: *State, symbol: *ast.Symbol, search: *RefSearch) void {
        const scope = getSymbolScope(self.program, symbol);
        if (scope != ast.null_node) {
            const isSourceFile = self.program.ast.getNodeKind(scope) == .SourceFile;
            var contains = false;
            if (isSourceFile) {
                for (self.sourceFiles) |sf| {
                    if (sf == scope) {
                        contains = true;
                        break;
                    }
                }
            }
            const addReferencesHere = !isSourceFile or contains;
            self.getReferencesInContainer(scope, ast_utils.getSourceFileOfNode(&self.program.ast, scope), search, addReferencesHere);
        } else {
            // Global search
            for (self.sourceFiles) |sourceFile| {
                self.searchForName(sourceFile, search);
            }
        }
    }

    pub fn getReferencesInContainer(self: *State, container: ast.NodeIndex, sourceFile: ast.NodeIndex, search: *RefSearch, addReferencesHere: bool) void {
        if (!self.markSearchedSymbols(sourceFile, search.allSearchSymbols)) {
            return;
        }

        const positions = getPossibleSymbolReferencePositions(self.program, sourceFile, search.text, container);
        for (positions) |pos| {
            self.getReferencesAtLocation(sourceFile, pos, search, addReferencesHere);
        }
    }

    pub fn markSearchedSymbols(self: *State, sourceFile: ast.NodeIndex, symbols: []const *ast.Symbol) bool {
        var seenSymbolsResult = self.sourceFileToSeenSymbols.getOrPut(sourceFile) catch return false;
        if (!seenSymbolsResult.found_existing) {
            seenSymbolsResult.value_ptr.* = std.AutoHashMap(*ast.Symbol, void).init(self.allocator);
        }
        var anyNewSymbols = false;
        for (symbols) |sym| {
            const entry = seenSymbolsResult.value_ptr.getOrPut(sym) catch return false;
            if (!entry.found_existing) {
                anyNewSymbols = true;
            }
        }
        return anyNewSymbols;
    }

    pub fn getReferencesAtLocation(self: *State, sourceFile: ast.NodeIndex, position: u32, search: *RefSearch, addReferencesHere: bool) void {
        const referenceLocation = ast_utils.getTouchingPropertyName(&self.program.ast, sourceFile, position);

        if (referenceLocation == ast.null_node) return;
        if (!isValidReferencePosition(&self.program.ast, referenceLocation, search.text)) return;

        const referenceSymbol = self.chk.getSymbolAtLocation(referenceLocation);
        if (referenceSymbol == null) return;

        const parent = self.program.ast.parents.items[referenceLocation];
        if (self.program.ast.getNodeKind(parent) == .ImportSpecifier and ast_utils.getPropertyName(&self.program.ast, parent) == referenceLocation) {
            return;
        }

        if (self.program.ast.getNodeKind(parent) == .ExportSpecifier) {
            self.getReferencesAtExportSpecifier(referenceLocation, referenceSymbol.?, parent, search, addReferencesHere, false);
            return;
        }

        const relatedRes = self.getRelatedSymbol(search, referenceSymbol.?, referenceLocation) catch .{ null, .node };
        const relatedSymbol = relatedRes[0];
        const relatedSymbolKind = relatedRes[1];

        if (relatedSymbol == null) {
            self.getReferenceForShorthandProperty(referenceSymbol.?, search);
            return;
        }

        if (addReferencesHere) {
            self.addReference(referenceLocation, relatedSymbol.?, relatedSymbolKind);
        }
    }



    pub fn searchForName(self: *State, sourceFile: ast.NodeIndex, search: *RefSearch) void {
        // In a full DoD implementation, we would check the sourceFile's name table here.
        // For now, we assume it's in the file.
        self.getReferencesInContainer(sourceFile, sourceFile, search, true);
    }

    pub fn explicitlyInheritsFrom(self: *State, symbol: *ast.Symbol, parent: *ast.Symbol) bool {
        if (symbol.id == parent.id) return true;
        
        const key = InheritKey{ .symbol = symbol, .parent = parent };
        if (self.inheritsFromCache.get(key)) |cached| {
            return cached;
        }

        self.inheritsFromCache.put(self.allocator, key, false) catch {}; // Prevent infinite recursion
        
        if (symbol.Declarations.items.len == 0) return false;
        
        var inherits = false;
        for (symbol.Declarations.items) |decl| {
            const superTypeNodes = ls_utils.getAllSuperTypeNodes(self.allocator, &self.program.ast, decl) catch &[_]ast.NodeIndex{};
            for (superTypeNodes) |typeReference| {
                if (self.chk.getTypeAtLocation(&self.program.ast, typeReference)) |typ| {
                    if (typ.symbol) |sym| {
                        if (self.explicitlyInheritsFrom(sym, parent)) {
                            inherits = true;
                            break;
                        }
                    }
                }
            }
            if (inherits) break;
        }

        self.inheritsFromCache.put(self.allocator, key, inherits) catch {};
        return inherits;
    }

    pub fn getRelatedSymbol(self: *State, search: *RefSearch, referenceSymbol: *ast.Symbol, referenceLocation: ast.NodeIndex) !struct { ?*ast.Symbol, EntryKind } {
        const Ctx = struct {
            search: *RefSearch,
            referenceSymbol: *ast.Symbol,
            program_ast: *const ast.Tree,
            state: *State,

            fn cb(ctx: *@This(), sym: *ast.Symbol, rootSymbol: ?*ast.Symbol, baseSymbol: ?*ast.Symbol) !?*ast.Symbol {
                var finalBase = baseSymbol;
                if (finalBase) |b| {
                    if (ls_utils.isStaticSymbol(ctx.program_ast, ctx.referenceSymbol) != ls_utils.isStaticSymbol(ctx.program_ast, b)) {
                        finalBase = null;
                    }
                }
                const searchSym = finalBase orelse rootSymbol orelse sym;
                if (ctx.search.includes(searchSym)) {
                    if (rootSymbol != null and (sym.CheckFlags & checker.CheckFlags.Synthetic) == 0) {
                        return rootSymbol;
                    }
                    return sym;
                }
                return null;
            }

            fn allowBaseTypes(ctx: *@This(), rootSymbol: *ast.Symbol) bool {
                if (ctx.search.parents.len != 0) {
                    var found = false;
                    for (ctx.search.parents) |parent| {
                        if (rootSymbol.Parent) |rp| {
                            if (ctx.state.program.ast.getNode(rp).symbol) |parent_sym| {
                                if (ctx.state.explicitlyInheritsFrom(parent_sym, parent)) {
                                    found = true;
                                    break;
                                }
                            }
                        }
                    }
                    return !found;
                }
                return true;
            }
        };

        var ctx = Ctx{
            .search = search,
            .referenceSymbol = referenceSymbol,
            .program_ast = &self.program.ast,
            .state = self,
        };

        return try self.forEachRelatedSymbol(
            &ctx,
            referenceSymbol,
            referenceLocation,
            false,
            self.options.use != .Rename or self.options.useAliasesForRename,
            Ctx.cb,
            Ctx.allowBaseTypes,
        );
    }

    pub fn getReferenceForShorthandProperty(self: *State, referenceSymbol: *ast.Symbol, search: *RefSearch) void {
        if ((referenceSymbol.flags & ast_utils.SymbolFlags.Transient) != 0 or referenceSymbol.valueDeclaration == ast.null_node) {
            return;
        }
        const shorthandValueSymbol = self.chk.getShorthandAssignmentValueSymbol(referenceSymbol.valueDeclaration);
        const name = ast_utils.getNameOfDeclaration(&self.program.ast, referenceSymbol.valueDeclaration);

        if (name != ast.null_node and search.includes(shorthandValueSymbol orelse return)) {
            self.addReference(name, shorthandValueSymbol.?, EntryKind.node);
        }
    }
};

pub fn getSymbolScope(program: *compiler.Program, symbol: *ast.Symbol) ast.NodeIndex {
    const valueDeclaration = symbol.valueDeclaration;
    if (valueDeclaration != ast.null_node) {
        const kind = program.ast.getNodeKind(valueDeclaration);
        if (kind == .FunctionExpression or kind == .ClassExpression) {
            return valueDeclaration;
        }
    }

    if (symbol.declarations.len == 0) {
        return ast.null_node;
    }

    if ((symbol.flags & (ast_utils.SymbolFlags.Property | ast_utils.SymbolFlags.Method)) != 0) {
        var privateDeclaration: ast.NodeIndex = ast.null_node;
        for (symbol.declarations) |d| {
            if (ast_utils.hasModifier(&program.ast, d, ast_utils.ModifierFlags.Private) or ast_utils.isPrivateIdentifierClassElementDeclaration(&program.ast, d)) {
                privateDeclaration = d;
                break;
            }
        }
        if (privateDeclaration != ast.null_node) {
            return ast_utils.findAncestorKind(&program.ast, privateDeclaration, .ClassDeclaration);
        }
        return ast.null_node;
    }

    const exposedByParent = symbol.parent != null and (symbol.flags & ast_utils.SymbolFlags.TypeParameter) == 0;
    if (exposedByParent and !(program.getTypeChecker().isExternalModuleSymbol(symbol.parent.?) and !isSourceFileWithGlobalExports(program, symbol.parent.?.valueDeclaration))) {
        return ast.null_node;
    }

    var scope: ast.NodeIndex = ast.null_node;
    for (symbol.declarations) |declaration| {
        const container = getContainerNode(program, declaration);
        if (scope != ast.null_node and scope != container) {
            return ast.null_node;
        }

        if (container == ast.null_node or (program.ast.getNodeKind(container) == .SourceFile and !ast_utils.isExternalOrCommonJSModule(&program.ast, container))) {
            return ast.null_node;
        }
        scope = container;
    }

    if (exposedByParent) {
        return ast_utils.getSourceFileOfNode(&program.ast, scope);
    }
    return scope;
}

pub fn getContainerNode(program: *compiler.Program, node: ast.NodeIndex) ast.NodeIndex {
    const tree = &program.ast;
    if (ast_utils.isJSDocNode(tree, node)) {
        return tree.parents.items[node];
    } else if (ast_utils.isStringLiteralLike(tree, node)) {
        return ast_utils.getEnclosingBlockScopeContainer(tree, node);
    }
    return ast_utils.getEnclosingBlockScopeContainer(tree, tree.parents.items[node]);
}

pub fn isSourceFileWithGlobalExports(program: *compiler.Program, node: ast.NodeIndex) bool {
    const tree = &program.ast;
    return ast_utils.getCommonJSModuleIndicator(tree, node) != 0 and !ast_utils.hasUMDExport(tree, node);
}

pub fn getLocalSymbolForExportDefault(program: *compiler.Program, symbol: *ast.Symbol) ?*ast.Symbol {
    if (symbol.flags & ast.SymbolFlags.ExportValue != 0 and symbol.exportSymbol != 0) {
        return program.ast.symbols.items[symbol.exportSymbol];
    }
    return null;
}

pub fn getNonModuleSymbolOfMergedModuleSymbol(program: *compiler.Program, symbol: *ast.Symbol) ?*ast.Symbol {
    if (symbol.declarations.len == 0 or (symbol.flags & (ast.SymbolFlags.Module | ast.SymbolFlags.Transient)) == 0) {
        return null;
    }
    const tree = &program.ast;
    for (symbol.declarations) |decl| {
        const k = tree.getKind(decl);
        if (k != .SourceFile and k != .ModuleDeclaration) {
            const sym_id = tree.getSymbolOfNode(decl);
            if (sym_id != 0) {
                return tree.symbols.items[sym_id];
            }
        }
    }
    return null;
}

pub fn getPossibleSymbolReferencePositions(program: *compiler.Program, sourceFile: ast.NodeIndex, text: []const u8, container_arg: ast.NodeIndex) []const u32 {
    if (text.len == 0) return &[_]u32{};

    const sourceText = program.getAstNode(sourceFile).source_file.text;
    const sourceLength = sourceText.len;
    const symbolNameLength = text.len;

    const container = if (container_arg == ast.null_node) sourceFile else container_arg;
    var positions = std.ArrayList(u32).init(program.allocator);

    const start_pos = program.ast.positions.items[container].pos;
    var position = std.mem.indexOfPos(u8, sourceText, start_pos, text) orelse return &[_]u32{};
    const endPos = program.ast.positions.items[container].end;

    while (position < endPos) {
        const endPosition = position + symbolNameLength;
        if ((position == 0 or !scanner.isIdentifierPart(sourceText[position - 1])) and
            (endPosition == sourceLength or !scanner.isIdentifierPart(sourceText[endPosition])))
        {
            positions.append(@intCast(position)) catch {};
        }

        const startIndex = position + symbolNameLength + 1;
        if (startIndex > sourceLength) break;
        if (std.mem.indexOfPos(u8, sourceText, startIndex, text)) |foundIndex| {
            position = foundIndex;
        } else {
            break;
        }
    }

    return positions.toOwnedSlice() catch &[_]u32{};
}

pub fn newState(allocator: std.mem.Allocator, program: *compiler.Program, sourceFiles: []const ast.NodeIndex, node: ast.NodeIndex, chk: *checker.Checker, searchMeaning: u32, options: RefOptions) State {
    _ = node;
    return State{
        .allocator = allocator,
        .program = program,
        .sourceFiles = sourceFiles,
        .chk = chk,
        .searchMeaning = searchMeaning,
        .options = options,
        .result = &[_]*SymbolAndEntries{},
        .sourceFileToSeenSymbols = std.AutoHashMap(ast.NodeIndex, std.AutoHashMap(*ast.Symbol, void)).init(allocator),
        .inheritsFromCache = std.AutoHashMap(InheritKey, bool).init(allocator),
    };
}

pub fn getReferencedSymbolsForSymbol(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, program: *compiler.Program, originalSymbol: *ast.Symbol, node: ast.NodeIndex, sourceFiles: []const ast.NodeIndex, chk: *checker.Checker, options: RefOptions) []*SymbolAndEntries {
    _ = ls;

    // symbol = core.Coalesce(skipPastExportOrImportSpecifierOrUnion(originalSymbol, node, checker, !isForRenameWithPrefixAndSuffixText(options)), originalSymbol);
    const skippedSymbol = skipPastExportOrImportSpecifierOrUnion(&program.ast, originalSymbol, node, chk, !isForRenameWithPrefixAndSuffixText(options));
    const symbol = if (skippedSymbol != null) skippedSymbol.? else originalSymbol;

    const searchMeaning: u32 = ast_utils.SemanticMeaningAll;
    if (options.use != .rename) {
        // searchMeaning = getIntersectingMeaningFromDeclarations(node, symbol, ast_utils.SemanticMeaningAll);
    }

    var state = newState(allocator, program, sourceFiles, node, chk, searchMeaning, options);

    const exportSpecifier: ast.NodeIndex = ast.null_node;
    if (isForRenameWithPrefixAndSuffixText(options) and symbol.declarations.len != 0) {
        // exportSpecifier = core.Find(symbol.Declarations, ast.IsExportSpecifier);
    }

    if (exportSpecifier != ast.null_node) {
        const search = state.createSearch(node, originalSymbol, ImpExpKind.unknown, "", &[_]*ast.Symbol{});
        state.getReferencesAtExportSpecifier(ast_utils.getName(&program.ast, exportSpecifier), symbol, exportSpecifier, search, true, true);
    } else if (node != ast.null_node and program.ast.getNodeKind(node) == .DefaultKeyword and std.mem.eql(u8, symbol.name, ast_utils.InternalSymbolNameDefault) and symbol.parent != null) {
        state.addReference(node, symbol, EntryKind.node);
        var exportInfo = ExportInfo{ .exportingModuleSymbol = symbol.parent.?, .exportKind = ExportKind.default };
        state.searchForImportsOfExport(node, symbol, &exportInfo);
    } else {
        const searchSymbols = state.populateSearchSymbolSet(symbol, node, options.use == .rename, options.useAliasesForRename, options.implementations);
        const search = state.createSearch(node, symbol, ImpExpKind.unknown, "", searchSymbols);
        state.getReferencesInContainerOrFiles(symbol, search);
    }

    return state.result;
}

pub fn mergeReferences(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, program: *compiler.Program, r1: []*SymbolAndEntries, r2: []*SymbolAndEntries, r3: []*SymbolAndEntries) []*SymbolAndEntries {
    _ = ls;
    _ = allocator;
    _ = program;
    _ = r2;
    _ = r3;
    return r1;
}

pub fn isLiteralNameOfPropertyDeclarationOrIndexAccess(tree: *ast.Ast, node: ast.NodeIndex) bool {
    const parent = tree.parents.items[node];
    switch (tree.getKind(parent)) {
        .PropertyDeclaration, .PropertySignature, .PropertyAssignment, .EnumMember, .MethodDeclaration, .MethodSignature, .GetAccessor, .SetAccessor, .ModuleDeclaration => {
            return ast_utils.getName(tree, parent) == node;
        },
        .ElementAccessExpression => {
            return tree.getAstNode(parent).element_access_expression.argumentExpression == node;
        },
        else => return false,
    }
}

pub fn isNameOfModuleDeclaration(tree: *ast.Ast, node: ast.NodeIndex) bool {
    const parent = tree.parents.items[node];
    return tree.getKind(parent) == .ModuleDeclaration and ast_utils.getName(tree, parent) == node;
}

pub fn isExpressionOfExternalModuleImportEqualsDeclaration(tree: *ast.Ast, node: ast.NodeIndex) bool {
    const parent = tree.parents.items[node];
    if (tree.parents.items.len <= parent) return false;
    const grandParent = tree.parents.items[parent];
    if (tree.getKind(grandParent) == .ImportEqualsDeclaration) {
        const moduleReference = tree.getAstNode(grandParent).import_equals_declaration.moduleReference;
        if (tree.getKind(moduleReference) == .ExternalModuleReference) {
            return tree.getAstNode(moduleReference).external_module_reference.expression == node;
        }
    }
    return false;
}

pub fn isObjectDefinePropertyCall(tree: *ast.Ast, node: ast.NodeIndex) bool {
    if (tree.getKind(node) != .CallExpression) return false;
    const callExpr = tree.getAstNode(node).call_expression;
    if (tree.getKind(callExpr.expression) != .PropertyAccessExpression) return false;
    const propAccess = tree.getAstNode(callExpr.expression).property_access_expression;
    if (tree.getKind(propAccess.expression) != .Identifier or !std.mem.eql(u8, ast_utils.getText(tree, propAccess.expression), "Object")) return false;
    if (tree.getKind(propAccess.name) != .Identifier or !std.mem.eql(u8, ast_utils.getText(tree, propAccess.name), "defineProperty")) return false;
    return true;
}

pub fn isBindableObjectDefinePropertyCall(tree: *ast.Ast, node: ast.NodeIndex) bool {
    if (tree.getKind(node) != .CallExpression) return false;
    if (!isObjectDefinePropertyCall(tree, node)) return false;
    const callExpr = tree.getAstNode(node).call_expression;
    if (callExpr.arguments.len < 3) return false;
    if (tree.getKind(callExpr.arguments[1]) != .StringLiteral) return false;
    if (tree.getKind(callExpr.arguments[2]) != .ObjectLiteralExpression) return false;
    return true;
}

pub fn isValidReferencePosition(tree: *ast.Ast, node: ast.NodeIndex, searchSymbolName: []const u8) bool {
    const kind = tree.getKind(node);
    switch (kind) {
        .PrivateIdentifier => return ast_utils.getText(tree, node).len == searchSymbolName.len,
        .Identifier => return ast_utils.getText(tree, node).len == searchSymbolName.len,
        .NoSubstitutionTemplateLiteral, .StringLiteral => {
            if (ast_utils.getText(tree, node).len != searchSymbolName.len) return false;
            return isLiteralNameOfPropertyDeclarationOrIndexAccess(tree, node) or
                   isNameOfModuleDeclaration(tree, node) or
                   isExpressionOfExternalModuleImportEqualsDeclaration(tree, node) or
                   (tree.getKind(tree.parents.items[node]) == .CallExpression and isBindableObjectDefinePropertyCall(tree, tree.parents.items[node]) and tree.getAstNode(tree.parents.items[node]).call_expression.arguments[1] == node) or
                   ast_utils.isImportOrExportSpecifier(tree, tree.parents.items[node]);
        },
        .NumericLiteral => return isLiteralNameOfPropertyDeclarationOrIndexAccess(tree, node) and ast_utils.getText(tree, node).len == searchSymbolName.len,
        .DefaultKeyword => return "default".len == searchSymbolName.len,
        else => return false,
    }
}
