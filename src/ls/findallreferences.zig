const std = @import("std");
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
        // Assume getMappedLocation is implemented in LanguageService or lsutil
        // We will stub this call to fit what Go did.
        // const location = ls.getMappedLocation(entry.fileName, entry.textRange.?);
        // entry.lspRange = location;
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
    const tree = &ls.program.ast;

    // We assume ast_utils functions will be properly implemented.
    // For now we use some dummy calls or comment them to avoid compile errors
    // before ast_utils is fully complete, but we structure it correctly.

    // if (ast_utils.isDeclaration(tree, node)) {
    //     return getContextNode(ls, node);
    // }

    const parent = tree.parents.items[node];
    if (parent == 0) return ast.null_node;

    // ... stub logic mapping ...
    // The exact translation of the context tree walking requires full ast_utils.
    return parent;
}

pub fn getContextNode(ls: *languageservice.LanguageService, fileId: compiler.FileId, node: ast.NodeIndex) ast.NodeIndex {
    if (node == 0) return ast.null_node;
    const tree = ls.getAst(fileId);
    const parent = tree.getNodeParent(node);
    return parent;
}

pub fn getLspRangeOfNode(ls: *languageservice.LanguageService, fileId: compiler.FileId, node: ast.NodeIndex, endNode: ?ast.NodeIndex, dummy: u32) lsproto.Range {
    _ = dummy;
    const textRange = getRangeOfNode(ls, fileId, node, endNode);
    return ls.converters.toLSPRange(ls.getScript(fileId), textRange);
}

pub fn getRangeOfNode(ls: *languageservice.LanguageService, fileId: compiler.FileId, node: ast.NodeIndex, endNode: ?ast.NodeIndex) core.TextRange {
    _ = endNode;
    const tree = ls.getAst(fileId);
    return core.TextRange.init(@intCast(tree.getNodeStart(node)), @intCast(tree.getNodeEnd(node)));
}

pub fn isValidReferencePosition(ls: *languageservice.LanguageService, node: ast.NodeIndex, searchSymbolName: []const u8) bool {
    _ = ls;
    _ = node;
    _ = searchSymbolName;
    return false;
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

    // We assume these ast_utils functions exist or will be added
    // const decl = ast_utils.getDeclarationFromName(tree, node);
    const decl = ast.null_node; // stub

    if (decl != ast.null_node) {
        source = decl;
    } else if (tree.getNodeKind(node) == .DefaultKeyword) {
        source = tree.parents.items[node];
    } else {
        // stub out literal computed property check to compile safely
        // if (ast_utils.isLiteralComputedPropertyDeclarationName(tree, node)) {
        //     source = tree.parents.items[tree.parents.items[node]];
        // } else if (tree.getNodeKind(node) == .ConstructorKeyword and ast_utils.isConstructorDeclaration(tree, tree.parents.items[node])) {
        //     source = tree.parents.items[tree.parents.items[node]];
        // }
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
    _ = ls;
    _ = node;
    return true; // stub
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
        node = getAdjustedLocation(ls, node, options.use == .rename, getSourceFileOfNode(ls, node));
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
        if (!options.implementations and isStringLiteralLike(ls, node)) {
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
    _ = ls;
    _ = isForRename;
    _ = sourceFile;
    return node;
}

pub fn getSourceFileOfNode(ls: *languageservice.LanguageService, node: ast.NodeIndex) ast.NodeIndex {
    _ = ls;
    _ = node;
    return ast.null_node;
}

pub const ResolvedRef = struct {
    file: ast.NodeIndex,
};

pub fn getReferenceAtPosition(ls: *languageservice.LanguageService, node: ast.NodeIndex, position: u32, program: *compiler.Program) ResolvedRef {
    _ = ls;
    _ = node;
    _ = position;
    _ = program;
    return ResolvedRef{ .file = ast.null_node };
}

pub fn getReferencedSymbolsSpecial(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, node: ast.NodeIndex, sourceFiles: []const ast.NodeIndex) ?[]*SymbolAndEntries {
    _ = ls;
    _ = allocator;
    _ = node;
    _ = sourceFiles;
    return null;
}

pub fn getName(ls: *languageservice.LanguageService, node: ast.NodeIndex) ast.NodeIndex {
    _ = ls;
    _ = node;
    return ast.null_node;
}

pub fn isStringLiteralLike(ls: *languageservice.LanguageService, node: ast.NodeIndex) bool {
    _ = ls;
    _ = node;
    return false;
}

pub fn isModuleSpecifierLike(ls: *languageservice.LanguageService, node: ast.NodeIndex) bool {
    _ = ls;
    _ = node;
    return false;
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

pub fn getContextualTypeFromParentOrAncestorTypeNode(ls: *languageservice.LanguageService, node: ast.NodeIndex, chk: *checker.Checker) ?*types.Type {
    _ = ls;
    _ = node;
    _ = chk;
    return null; // stub
}

pub fn getPossibleSymbolReferenceNodes(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, sourceFile: ast.NodeIndex, text: []const u8) []const ast.NodeIndex {
    _ = ls;
    _ = allocator;
    _ = sourceFile;
    _ = text;
    return &[_]ast.NodeIndex{}; // stub
}

pub fn isStringLiteralPropertyReference(ls: *languageservice.LanguageService, node: ast.NodeIndex, chk: *checker.Checker) bool {
    const tree = &ls.program.ast;
    const parent = tree.parents.items[node];
    if (ast_utils.isPropertySignatureDeclaration(tree, parent)) {
        return chk.getPropertyOfType(chk.getTypeAtLocation(tree.parents.items[parent]), ast_utils.getText(tree, node)) != null;
    }
    return false;
}

pub fn rangeIsOnSingleLine(ls: *languageservice.LanguageService, node: ast.NodeIndex, sourceFile: ast.NodeIndex) bool {
    _ = ls;
    _ = node;
    _ = sourceFile;
    return true; // stub
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

    // stub check for SymbolFlags.Module
    // if ((symbol.flags & ast_utils.SymbolFlags.Module == 0) or symbol.declarations.len == 0) { ... }
    if (symbol.declarations.len == 0) {
        return &[_]*SymbolAndEntries{};
    }

    const moduleSourceFileName: []const u8 = "";
    _ = moduleSourceFileName;
    var moduleSourceFile: ast.NodeIndex = ast.null_node;

    for (symbol.declarations) |decl| {
        if (program.ast.getNodeKind(decl) == .SourceFile) {
            moduleSourceFile = decl;
            break;
        }
    }

    if (moduleSourceFile != ast.null_node) {
        // Assume program.getAstNode(moduleSourceFile).source_file.fileName exists
        // We will just leave it empty string for now to make it compile as a stub.
        // moduleSourceFileName = program.getAstNode(moduleSourceFile).source_file.fileName;
    } else {
        return &[_]*SymbolAndEntries{};
    }

    // const exportEquals = symbol.exports.get("export=");
    const exportEquals: ?*ast.Symbol = null; // stub

    const moduleReferences = getReferencedSymbolsForModule(ls, allocator, program, symbol, exportEquals != null, sourceFiles) catch &[_]*SymbolAndEntries{};

    var has_moduleSourceFileName = false;
    for (sourceFiles) |sf| {
        // if (std.mem.eql(u8, program.getAstNode(sf).source_file.fileName, moduleSourceFileName))
        _ = sf;
        has_moduleSourceFileName = true; // stub
        break;
    }

    if (exportEquals == null or !has_moduleSourceFileName) { // stub (exportEquals.?.flags & ast_utils.SymbolFlags.Alias == 0)
        return moduleReferences;
    }

    if (chk.resolveAlias(exportEquals.?)) |resolved_alias| {
        symbol = resolved_alias;
    }
    const otherReferences = getReferencedSymbolsForSymbol(ls, allocator, program, symbol, ast.null_node, sourceFiles, chk, options);
    return mergeReferences(ls, allocator, program, moduleReferences, otherReferences, &[_]*SymbolAndEntries{});
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
    allSearchSymbols: []*ast.Symbol,
};

pub const ExportKind = enum {
    default,
    named,
};

pub const ExportInfo = struct {
    exportingModuleSymbol: *ast.Symbol,
    exportKind: ExportKind,
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

    pub fn deinit(self: *State) void {
        var it = self.sourceFileToSeenSymbols.valueIterator();
        while (it.next()) |*set| {
            set.deinit();
        }
        self.sourceFileToSeenSymbols.deinit();
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
            // stub logic for getting local symbol text
            text = symbol.name;
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
        _ = isForRename;
        _ = useAliasesForRename;
        _ = implementations;

        if (location == ast.null_node) {
            var res = self.allocator.alloc(*ast.Symbol, 1) catch return &[_]*ast.Symbol{};
            res[0] = symbol;
            return res;
        }
        var result = std.ArrayList(*ast.Symbol).init(self.allocator);

        // Stubbed forEachRelatedSymbol.
        // It returns a single symbol, but also populates result as a side effect.
        // Here we just return `symbol` wrapped in a slice to avoid compilation errors and preserve DoD structure.
        result.append(symbol) catch return &[_]*ast.Symbol{};
        return result.toOwnedSlice() catch return &[_]*ast.Symbol{};
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

        // stub isValidReferencePosition checking
        if (referenceLocation == ast.null_node) return;

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

        // stub getRelatedSymbol
        const relatedSymbol = referenceSymbol.?;
        // if (relatedSymbol == null) {
        //     self.getReferenceForShorthandProperty(referenceSymbol, search);
        //     return;
        // }

        if (addReferencesHere) {
            self.addReference(referenceLocation, relatedSymbol, EntryKind.node);
        }
    }

    pub fn searchForName(self: *State, sourceFile: ast.NodeIndex, search: *RefSearch) void {
        // In a full DoD implementation, we would check the sourceFile's name table here.
        // For now, we assume it's in the file.
        self.getReferencesInContainer(sourceFile, sourceFile, search, true);
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
    _ = program;
    _ = node;
    return ast.null_node; // stub
}

pub fn isSourceFileWithGlobalExports(program: *compiler.Program, node: ast.NodeIndex) bool {
    _ = program;
    _ = node;
    return false; // stub
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
        _ = endPosition;
        // stub out scanner identifier part check
        // if ((position == 0 or !scanner.isIdentifierPart(sourceText[position - 1])) and
        //     (endPosition == sourceLength or !scanner.isIdentifierPart(sourceText[endPosition])))
        {
            positions.append(@intCast(position)) catch break;
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
