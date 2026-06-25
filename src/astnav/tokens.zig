const std = @import("std");
const ast = @import("../ast/ast.zig");
const core = @import("../core/core.zig");
const scanner = @import("../scanner/scanner.zig");
const kind = @import("../ast/kind.zig").Kind;

pub fn getTouchingPropertyName(sourceFile: ast.NodeIndex, a: *ast.Ast, position: u32) ast.NodeIndex {
    _ = sourceFile; _ = a; _ = position;
    @panic("TODO: getTouchingPropertyName");
}

pub fn getTouchingToken(sourceFile: ast.NodeIndex, a: *ast.Ast, position: u32) ast.NodeIndex {
    _ = sourceFile; _ = a; _ = position;
    @panic("TODO: getTouchingToken");
}

pub fn getTokenAtPosition(sourceFile: ast.NodeIndex, a: *ast.Ast, position: u32) ast.NodeIndex {
    _ = sourceFile; _ = a; _ = position;
    @panic("TODO: getTokenAtPosition");
}

pub fn visitEachChildAndJSDoc(
    node: ast.NodeIndex,
    a: *ast.Ast,
    sourceFile: ast.NodeIndex,
    // Note: Zig uses contexts or fn pointers for visitors, depending on the architecture
) void {
    _ = node; _ = a; _ = sourceFile;
    @panic("TODO: visitEachChildAndJSDoc");
}

pub fn findPrecedingToken(sourceFile: ast.NodeIndex, a: *ast.Ast, position: u32) ast.NodeIndex {
    _ = sourceFile; _ = a; _ = position;
    @panic("TODO: findPrecedingToken");
}

pub fn findPrecedingTokenEx(sourceFile: ast.NodeIndex, a: *ast.Ast, position: u32, startNode: ast.NodeIndex, excludeJSDoc: bool) ast.NodeIndex {
    _ = sourceFile; _ = a; _ = position; _ = startNode; _ = excludeJSDoc;
    @panic("TODO: findPrecedingTokenEx");
}

pub fn getStartOfNode(node: ast.NodeIndex, a: *ast.Ast, file: ast.NodeIndex, includeJSDoc: bool) u32 {
    _ = node; _ = a; _ = file; _ = includeJSDoc;
    @panic("TODO: getStartOfNode");
}

pub fn findNextToken(previousToken: ast.NodeIndex, a: *ast.Ast, parent: ast.NodeIndex, file: ast.NodeIndex) ast.NodeIndex {
    _ = previousToken; _ = a; _ = parent; _ = file;
    @panic("TODO: findNextToken");
}

pub fn findChildOfKind(containingNode: ast.NodeIndex, a: *ast.Ast, searchKind: kind, sourceFile: ast.NodeIndex) ast.NodeIndex {
    _ = containingNode; _ = a; _ = searchKind; _ = sourceFile;
    @panic("TODO: findChildOfKind");
}
