const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const astnav = @import("../astnav/tokens.zig");

pub fn prepareCallHierarchy(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.CallHierarchyPrepareParams,
) !?[]lsproto.CallHierarchyItem {
    const programAndFile = ls.getProgramAndFile(params.textDocument.uri);
    const file = programAndFile.file;

    const script = ls.getScript(file);
    const position = ls.converters.lineAndCharacterToPosition(script, params.position);

    const tree = ls.getAst(file);
    const sourceFileNode = tree.getNode(ls.getSourceFileNode(file)).SourceFile;
    const node = astnav.getTouchingPropertyName(sourceFileNode, tree, position);

    if (node == sourceFileNode) {
        return null;
    }

    const decl = resolveCallHierarchyDeclaration(tree, node);
    if (decl == 0) return null;

    var result = std.ArrayListUnmanaged(lsproto.CallHierarchyItem).empty;
    errdefer result.deinit(allocator);

    const item = createCallHierarchyItem(tree, decl);
    try result.append(allocator, item);

    return result.toOwnedSlice(allocator);
}

pub fn provideCallHierarchyIncomingCalls(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.CallHierarchyIncomingCallsParams,
) !?[]lsproto.CallHierarchyIncomingCall {
    const program = ls.getProgram();
    const fileName = lsproto.uriToPath(params.item.uri);
    const file = program.getSourceFile(fileName) orelse return null;

    _ = file;
    var result = std.ArrayListUnmanaged(lsproto.CallHierarchyIncomingCall).empty;
    return result.toOwnedSlice(allocator);
}

pub fn provideCallHierarchyOutgoingCalls(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.CallHierarchyOutgoingCallsParams,
) !?[]lsproto.CallHierarchyOutgoingCall {
    const program = ls.getProgram();
    const fileName = lsproto.uriToPath(params.item.uri);
    const file = program.getSourceFile(fileName) orelse return null;

    _ = file;
    var result = std.ArrayListUnmanaged(lsproto.CallHierarchyOutgoingCall).empty;
    return result.toOwnedSlice(allocator);
}

fn resolveCallHierarchyDeclaration(tree: *ast.Ast, node: ast.NodeIndex) ast.NodeIndex {
    var current = node;
    while (current != 0) : (current = tree.getNodeParent(current)) {
        const kind = tree.getNodeKind(current);
        switch (kind) {
            .FunctionDeclaration,
            .MethodDeclaration,
            .ClassDeclaration,
            .PropertyDeclaration,
            .Constructor,
            => return current,
            else => {},
        }
    }
    return 0;
}

fn createCallHierarchyItem(tree: *ast.Ast, node: ast.NodeIndex) lsproto.CallHierarchyItem {
    _ = tree;
    _ = node;
    return .{
        .name = "TODO",
        .kind = .Function,
        .tags = null,
        .detail = null,
        .uri = "",
        .range = .{ .start = .{ .line = 0, .character = 0 }, .end = .{ .line = 0, .character = 0 } },
        .selectionRange = .{ .start = .{ .line = 0, .character = 0 }, .end = .{ .line = 0, .character = 0 } },
        .data = null,
    };
}
