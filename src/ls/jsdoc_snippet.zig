const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const astnav = @import("../astnav/tokens.zig");
const scanner = @import("../scanner/scanner.zig");

pub const JSDocSnippet = struct {
    text: []const u8,
    position: u32,
};

pub fn getJSDocSnippet(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    source_file: ast_gen.NodeIndex,
    position: u32,
) ?JSDocSnippet {
    const token = astnav.getTokenAtPosition(source_file, tree, position);
    if (token == 0) return null;
    
    var current: ast_gen.NodeIndex = token;
    var declaration: ast_gen.NodeIndex = 0;
    while (current != 0) : (current = tree.getNodeParent(current)) {
        const kind = tree.getNodeKind(current);
        if (kind == .FunctionDeclaration or kind == .MethodDeclaration or kind == .Constructor or kind == .MethodSignature or kind == .ArrowFunction) {
            declaration = current;
            break;
        }
    }
    
    if (declaration == 0) return null;
    
    const paramsNode = ast.getParametersNode(tree, declaration);
    var param_names = std.ArrayList([]const u8).init(allocator);
    defer param_names.deinit();
    
    if (paramsNode != 0) {
        const params = tree.getNodeList(paramsNode);
        for (params) |param| {
            const nameNode = ast.getNameOfDeclaration(tree, param);
            if (nameNode != 0 and tree.getNodeKind(nameNode) == .Identifier) {
                param_names.append(scanner.getTextOfNode(tree, nameNode)) catch continue;
            } else {
                param_names.append("param") catch continue;
            }
        }
    }
    
    const has_return = tree.getNodeKind(declaration) != .Constructor;
    
    const text = generateJSDocTemplate(allocator, param_names.items, has_return) catch return null;
    return JSDocSnippet{ .text = text, .position = position };
}

pub fn generateJSDocTemplate(
    allocator: std.mem.Allocator,
    param_names: []const []const u8,
    has_return: bool,
) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    try result.appendSlice("/**\n");
    try result.appendSlice(" * $1\n");

    for (param_names) |name| {
        try result.appendSlice(" * @param ");
        try result.appendSlice(name);
        try result.appendSlice(" $2\n");
    }

    if (has_return) {
        try result.appendSlice(" * @returns $3\n");
    }

    try result.appendSlice(" */");

    return result.toOwnedSlice();
}
