const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const change = @import("change/tracker.zig");
const lsutil = @import("lsutil/lsutil.zig");
const scanner = @import("../scanner/scanner.zig");
const factory_pkg = @import("../printer/factory.zig");
const core = @import("../core/core.zig");

const NodeIndex = ast.NodeIndex;

pub fn organizeImports(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.CodeActionParams,
) !?[]lsproto.CodeAction {
    const programAndFile = ls.getProgramAndFile(params.textDocument.uri);
    const file = programAndFile.file;

    const tree = ls.getAst(file);
    const sourceFileNodeIdx = ls.getSourceFileNode(file);
    const sourceFileNode = tree.getNode(sourceFileNodeIdx).SourceFile;
    const kind = if (params.context.only) |only| if (only.len > 0) only[0] else "" else "";

    var changeTracker = change.ChangeTracker.init(allocator);
    defer changeTracker.deinit();

    const shouldSort = std.mem.eql(u8, kind, "source.sortImports") or std.mem.eql(u8, kind, "source.organizeImports");
    const shouldCombine = shouldSort;
    const shouldRemove = std.mem.eql(u8, kind, "source.removeUnusedImports") or std.mem.eql(u8, kind, "source.organizeImports");

    const statements = tree.getNodeList(sourceFileNode.Statements);
    const topLevelImportDecls = try lsutil.filterImportDeclarations(allocator, tree, statements);
    defer allocator.free(topLevelImportDecls);

    const topLevelImportGroupDecls = try groupByNewlineContiguous(allocator, tree, sourceFileNodeIdx, topLevelImportDecls);
    defer {
        for (topLevelImportGroupDecls) |group| allocator.free(group);
        allocator.free(topLevelImportGroupDecls);
    }

    const preferences = ls.userPreferences();
    const lists = try lsutil.getDetectionLists(allocator, preferences);
    defer {
        allocator.free(lists.comparersToTest);
        allocator.free(lists.typeOrdersToTest);
    }

    const moduleSpecifierComparer: ?*const fn ([]const u8, []const u8) i32 = null;
    const namedImportComparer: ?*const fn ([]const u8, []const u8) i32 = null;

    const comparer = OrganizeImportsComparerSettings{
        .moduleSpecifierComparer = moduleSpecifierComparer,
        .namedImportComparer = namedImportComparer,
        .typeOrder = preferences.organizeImportsTypeOrder,
    };

    for (topLevelImportGroupDecls) |importGroupDecl| {
        try organizeImportsWorker(allocator, tree, importGroupDecl, comparer, shouldSort, shouldCombine, shouldRemove, sourceFileNodeIdx, ls.getProgram(), &changeTracker);
    }

    if (!std.mem.eql(u8, kind, "source.removeUnusedImports")) {
        const topLevelExportGroupDecls = try getTopLevelExportGroups(allocator, tree, sourceFileNodeIdx);
        defer {
            for (topLevelExportGroupDecls) |g| allocator.free(g);
            allocator.free(topLevelExportGroupDecls);
        }
        for (topLevelExportGroupDecls) |exportGroupDecl| {
            try organizeExportsWorker(allocator, tree, exportGroupDecl, comparer, sourceFileNodeIdx, &changeTracker);
        }
    }

    if (changeTracker.hasChanges()) {
        return null;
    }

    return null;
}

pub const OrganizeImportsComparerSettings = struct {
    moduleSpecifierComparer: ?*const fn ([]const u8, []const u8) i32,
    namedImportComparer: ?*const fn ([]const u8, []const u8) i32,
    typeOrder: lsutil.OrganizeImportsTypeOrder,
};

pub fn groupByNewlineContiguous(allocator: std.mem.Allocator, tree: *ast.Ast, sourceFileNode: NodeIndex, decls: []const NodeIndex) ![][]const NodeIndex {
    var groups = std.ArrayList([]const NodeIndex).init(allocator);
    errdefer {
        for (groups.items) |group| allocator.free(group);
        groups.deinit();
    }
    var currentGroup = std.ArrayList(NodeIndex).init(allocator);
    errdefer currentGroup.deinit();

    var s = scanner.Scanner.init("", allocator);
    defer s.deinit();
    s.setSkipTrivia(false);

    for (decls) |decl| {
        if (currentGroup.items.len > 0 and isNewGroup(tree, sourceFileNode, decl, &s)) {
            try groups.append(try currentGroup.toOwnedSlice());
            currentGroup = std.ArrayList(NodeIndex).init(allocator);
        }
        try currentGroup.append(decl);
    }

    if (currentGroup.items.len > 0) {
        try groups.append(try currentGroup.toOwnedSlice());
    } else {
        currentGroup.deinit();
    }

    return try groups.toOwnedSlice();
}

fn isNewGroup(tree: *ast.Ast, sourceFileNode: NodeIndex, decl: NodeIndex, s: *scanner.Scanner) bool {
    const fullStart = tree.getNodePos(decl);
    const text = tree.sourceText;
    const textLen = text.len;

    if (fullStart >= textLen) {
        return false;
    }
    _ = sourceFileNode;

    const startPos = scanner.skipTrivia(text, fullStart, false);
    if (startPos <= fullStart) {
        return false;
    }

    const triviaLen = startPos - fullStart;
    s.setText(text[fullStart..startPos]);

    var numberOfNewLines: u32 = 0;
    while (s.getTokenStart() < triviaLen) {
        const tokenKind = s.scan();
        if (tokenKind == .NewLineTrivia) {
            numberOfNewLines += 1;
            if (numberOfNewLines >= 2) {
                return true;
            }
        }
    }

    return false;
}

pub fn organizeImportsWorker(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    oldImportDecls: []const NodeIndex,
    comparer: OrganizeImportsComparerSettings,
    shouldSort: bool,
    shouldCombine: bool,
    shouldRemove: bool,
    sourceFile: NodeIndex,
    program: *compiler.Program,
    changeTracker: *change.ChangeTracker,
) !void {
    if (oldImportDecls.len == 0) return;

    var processedImports = try allocator.dupe(NodeIndex, oldImportDecls);
    defer allocator.free(processedImports);

    if (shouldRemove) {
        // ... typeChecker etc
        const newImports = try removeUnusedImports(allocator, tree, processedImports, sourceFile, program.getTypeCheckerForFile(sourceFile), program, changeTracker);
        allocator.free(processedImports);
        processedImports = newImports;
    }

    var newImportDecls = std.ArrayList(NodeIndex).init(allocator);
    defer newImportDecls.deinit();

    if (shouldCombine) {
        const grouped = try groupByModuleSpecifier(allocator, tree, processedImports);
        defer {
            for (grouped) |g| allocator.free(g);
            allocator.free(grouped);
        }

        if (shouldSort) {
            // ... sorting
        }

        for (grouped) |importGroup| {
            const coalesced = try coalesceImportsWorker(allocator, tree, importGroup, comparer.moduleSpecifierComparer, null, sourceFile, changeTracker);
            defer allocator.free(coalesced);

            try newImportDecls.appendSlice(coalesced);
        }
    } else {
        try newImportDecls.appendSlice(processedImports);
    }

    if (shouldSort and !shouldCombine) {
        // ...
    }

    if (newImportDecls.items.len == 0) {
        // changeTracker.deleteNodeRange(...)
    } else {
        // changeTracker.replaceNodeWithNodes(...)
    }
}

pub fn groupByModuleSpecifier(allocator: std.mem.Allocator, tree: *ast.Ast, imports: []const NodeIndex) ![][]const NodeIndex {
    var groups = std.StringHashMap(std.ArrayList(NodeIndex)).init(allocator);
    defer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit();
        groups.deinit();
    }
    var order = std.ArrayList([]const u8).init(allocator);
    defer order.deinit();

    for (imports) |imp| {
        const specifier = lsutil.getExternalModuleName(tree, ast_utils.getModuleSpecifier(tree, imp));
        const gop = try groups.getOrPut(specifier);
        if (!gop.found_existing) {
            try order.append(specifier);
            gop.value_ptr.* = std.ArrayList(NodeIndex).init(allocator);
        }
        try gop.value_ptr.append(imp);
    }

    var result = try allocator.alloc([]const NodeIndex, order.items.len);
    for (order.items, 0..) |key, i| {
        const list = groups.get(key).?;
        result[i] = try list.toOwnedSlice();
    }
    return result;
}

pub fn removeUnusedImports(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    oldImports: []const NodeIndex,
    sourceFile: NodeIndex,
    typeChecker: *checker.Checker,
    program: *compiler.Program,
    changeTracker: *change.ChangeTracker,
) ![]const NodeIndex {
    _ = sourceFile;
    _ = typeChecker;
    _ = program;
    _ = changeTracker;
    _ = tree;
    return allocator.dupe(NodeIndex, oldImports);
}

pub fn coalesceImportsWorker(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    importDecls: []const NodeIndex,
    comparer: ?*const fn ([]const u8, []const u8) i32,
    specifierComparer: ?*const fn (NodeIndex, NodeIndex) i32,
    sourceFile: NodeIndex,
    changeTracker: *change.ChangeTracker,
) ![]const NodeIndex {
    _ = comparer;
    _ = specifierComparer;
    _ = sourceFile;
    _ = changeTracker;
    _ = tree;

    if (importDecls.len == 0) {
        return allocator.dupe(NodeIndex, importDecls);
    }

    return allocator.dupe(NodeIndex, importDecls);
}

pub fn getTopLevelExportGroups(allocator: std.mem.Allocator, tree: *ast.Ast, sourceFile: NodeIndex) ![][]const NodeIndex {
    _ = sourceFile;
    _ = tree;
    var result = std.ArrayList([]const NodeIndex).init(allocator);
    return result.toOwnedSlice();
}

pub fn organizeExportsWorker(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    oldExportDecls: []const NodeIndex,
    comparer: OrganizeImportsComparerSettings,
    sourceFile: NodeIndex,
    changeTracker: *change.ChangeTracker,
) !void {
    _ = oldExportDecls;
    _ = comparer;
    _ = sourceFile;
    _ = changeTracker;
    _ = allocator;
    _ = tree;
}

pub fn getImportAttributesKey(allocator: std.mem.Allocator, tree: *ast.Ast, attributes: NodeIndex) ![]const u8 {
    _ = tree;
    if (attributes == 0) return "";
    var key = std.ArrayList(u8).init(allocator);
    defer key.deinit();
    // Implementation omitted for brevity
    return try key.toOwnedSlice();
}

pub fn filterUsedImportSpecifiers(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    elements: []const NodeIndex,
    typeChecker: *checker.Checker,
    sourceFile: NodeIndex,
    jsxElementsPresent: bool,
    jsxModeNeedsExplicitImport: bool,
) ![]const NodeIndex {
    _ = typeChecker;
    _ = sourceFile;
    _ = jsxElementsPresent;
    _ = jsxModeNeedsExplicitImport;
    _ = tree;
    return allocator.dupe(NodeIndex, elements);
}

pub fn hasModuleDeclarationMatchingSpecifier(tree: *ast.Ast, sourceFile: NodeIndex, moduleSpecifier: NodeIndex) bool {
    _ = sourceFile;
    _ = moduleSpecifier;
    _ = tree;
    return false;
}

pub fn getCategorizedImports(allocator: std.mem.Allocator, tree: *ast.Ast, importDecls: []const NodeIndex) !struct {
    importWithoutClause: NodeIndex,
    typeOnlyImports: []const NodeIndex,
    regularImports: []const NodeIndex,
} {
    _ = allocator;
    _ = tree;
    _ = importDecls;
    return .{
        .importWithoutClause = 0,
        .typeOnlyImports = &[_]NodeIndex{},
        .regularImports = &[_]NodeIndex{},
    };
}

pub fn getNewImportSpecifiers(allocator: std.mem.Allocator, tree: *ast.Ast, namedImports: []const NodeIndex) ![]const NodeIndex {
    _ = tree;
    return allocator.dupe(NodeIndex, namedImports);
}

pub fn tryGetNamedBindingElements(allocator: std.mem.Allocator, tree: *ast.Ast, namedImport: NodeIndex) ![]const NodeIndex {
    _ = tree;
    _ = namedImport;
    return allocator.dupe(NodeIndex, &[_]NodeIndex{});
}

pub fn coalesceExportsWorker(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    exportGroup: []const NodeIndex,
    specifierComparer: ?*const fn (NodeIndex, NodeIndex) i32,
    moduleSpecifierComparer: ?*const fn ([]const u8, []const u8) i32,
    sourceFile: NodeIndex,
    changeTracker: *change.ChangeTracker,
) ![]const NodeIndex {
    _ = specifierComparer;
    _ = moduleSpecifierComparer;
    _ = sourceFile;
    _ = changeTracker;
    _ = tree;
    return allocator.dupe(NodeIndex, exportGroup);
}

pub fn getCategorizedExports(allocator: std.mem.Allocator, tree: *ast.Ast, exportGroup: []const NodeIndex) !struct {
    exportWithoutClause: NodeIndex,
    namedExports: []const NodeIndex,
    typeOnlyExports: []const NodeIndex,
} {
    _ = allocator;
    _ = tree;
    _ = exportGroup;
    return .{
        .exportWithoutClause = 0,
        .namedExports = &[_]NodeIndex{},
        .typeOnlyExports = &[_]NodeIndex{},
    };
}
