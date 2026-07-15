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
    _ = moduleSpecifierComparer;
    _ = namedImportComparer;
    _ = shouldCombine;
    _ = shouldRemove;

    // TODO: implement the rest of the logic
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

pub fn coalesceImportsWorker(
    allocator: std.mem.Allocator,
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
    
    if (importDecls.len == 0) {
        return allocator.dupe(NodeIndex, importDecls);
    }

    return allocator.dupe(NodeIndex, importDecls);
}

pub fn organizeExportsWorker(
    oldExportDecls: []const NodeIndex,
    comparer: OrganizeImportsComparerSettings,
    sourceFile: NodeIndex,
    changeTracker: *change.ChangeTracker,
) void {
    _ = oldExportDecls;
    _ = comparer;
    _ = sourceFile;
    _ = changeTracker;
}

pub fn removeUnusedImports(
    allocator: std.mem.Allocator,
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
    return allocator.dupe(NodeIndex, oldImports);
}
