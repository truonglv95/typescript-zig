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

    // TODO: implement resolveCallHierarchyDeclaration and createCallHierarchyItem
    _ = allocator;
    return null;
}

pub fn provideCallHierarchyIncomingCalls(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.CallHierarchyIncomingCallsParams,
) !?[]lsproto.CallHierarchyIncomingCall {
    const program = ls.getProgram();
    const fileName = lsproto.uriToPath(params.item.uri);
    const file = program.getSourceFile(fileName) orelse return null;

    // TODO: implement getIncomingCalls
    _ = allocator;
    _ = file;
    return null;
}

pub fn provideCallHierarchyOutgoingCalls(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.CallHierarchyOutgoingCallsParams,
) !?[]lsproto.CallHierarchyOutgoingCall {
    const program = ls.getProgram();
    const fileName = lsproto.uriToPath(params.item.uri);
    const file = program.getSourceFile(fileName) orelse return null;

    // TODO: implement getOutgoingCalls
    _ = allocator;
    _ = file;
    return null;
}
