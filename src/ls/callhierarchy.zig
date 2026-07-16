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

    const item = createCallHierarchyItem(ls, tree, decl);
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

fn getCallHierarchyItemName(tree: *ast.Ast, node: ast.NodeIndex) struct { text: []const u8, start: u32, end: u32 } {
    if (tree.getNodeKind(node) == .SourceFile) {
        return .{ .text = tree.fileName, .start = 0, .end = 0 };
    }
    
    const declName = ast_utils.getName(tree, node);
    if (declName == 0) {
        const start = tree.getNodePos(node);
        const k = tree.getNodeKind(node);
        if (k == .FunctionDeclaration or k == .FunctionExpression or k == .ArrowFunction) {
            return .{ .text = "(anonymous)", .start = start, .end = start + 8 };
        } else if (k == .ClassDeclaration or k == .ClassExpression) {
            return .{ .text = "(anonymous)", .start = start, .end = start + 5 };
        }
        return .{ .text = "(anonymous)", .start = start, .end = start };
    }
    
    const text = ast_utils.getTextOfNode(tree, declName);
    return .{ .text = text, .start = tree.getNodePos(declName), .end = tree.getNodeEnd(declName) };
}

fn getCallHierarchyItemContainerName(tree: *ast.Ast, node: ast.NodeIndex) ?[]const u8 {
    const parent = tree.getNodeParent(node);
    if (parent == 0) return null;
    
    const pkind = tree.getNodeKind(parent);
    if (pkind == .ClassDeclaration or pkind == .ClassExpression or pkind == .InterfaceDeclaration) {
        const pname = ast_utils.getName(tree, parent);
        if (pname != 0) return ast_utils.getTextOfNode(tree, pname);
    }
    return null;
}

fn getSymbolKindFromNode(tree: *ast.Ast, node: ast.NodeIndex) lsproto.SymbolKind {
    const kind = tree.getNodeKind(node);
    return switch (kind) {
        .ModuleDeclaration => .Module,
        .ClassDeclaration, .ClassExpression => .Class,
        .InterfaceDeclaration, .TypeAliasDeclaration => .Interface,
        .EnumDeclaration => .Enum,
        .MethodDeclaration, .MethodSignature => .Method,
        .FunctionDeclaration, .FunctionExpression, .ArrowFunction => .Function,
        .GetAccessor, .SetAccessor, .PropertyDeclaration, .PropertySignature, .PropertyAssignment => .Property,
        .VariableDeclaration => .Variable,
        .Constructor => .Constructor,
        .EnumMember => .EnumMember,
        .StringLiteral, .NumericLiteral, .TrueKeyword, .FalseKeyword, .NullKeyword => .Constant,
        else => .Variable,
    };
}

fn createCallHierarchyItem(ls: *languageservice.LanguageService, tree: *ast.Ast, node: ast.NodeIndex) lsproto.CallHierarchyItem {
    const nameInfo = getCallHierarchyItemName(tree, node);
    const containerName = getCallHierarchyItemContainerName(tree, node);
    const kind = getSymbolKindFromNode(tree, node);
    
    const fullStart = tree.getNodePos(node);
    const endPos = tree.getNodeEnd(node);
    
    const program = ls.getProgram();
    const fileId = program.getFileId(tree.fileName).?;
    const script = ls.getScript(fileId);
    
    const span = ls.converters.toLSPRange(script, .{ .pos = fullStart, .end = endPos });
    const selectionSpan = ls.converters.toLSPRange(script, .{ .pos = nameInfo.start, .end = nameInfo.end });
    
    const lsconv = @import("lsconv.zig");
    return .{
        .name = ls.allocator.dupe(u8, nameInfo.text) catch nameInfo.text,
        .kind = kind,
        .tags = null,
        .detail = if (containerName) |c| (ls.allocator.dupe(u8, c) catch c) else null,
        .uri = lsconv.fileNameToDocumentURI(ls.allocator, tree.fileName) catch "",
        .range = span,
        .selectionRange = selectionSpan,
        .data = null,
    };
}
