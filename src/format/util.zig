const std = @import("std");
const ast = @import("../ast/ast.zig");
const kind = @import("../ast/kind.zig");
const core = @import("../core/core.zig");
const scanner = @import("../scanner/scanner.zig");

// To be ported: util.go functions

pub fn rangeIsOnOneLine(r: ast.TextRange, tree: *ast.Ast) bool {
    const text = tree.sourceText;
    var startLine: u32 = 0;
    var endLine: u32 = 0;
    for (text[0..r.end], 0..) |c, i| {
        if (c == '\n') {
            if (i < r.pos) {
                startLine += 1;
            }
            endLine += 1;
        }
    }
    return startLine == endLine;
}

pub fn findChildOfKind(node: ast.NodeIndex, k: kind.Kind, tree: *ast.Ast) ast.NodeIndex {
    if (node == 0) return 0;
    
    // Simplification for the stub: Actually, we would iterate through the children of the node.
    // Given the AST structure (SoA), we might not have a simple child array unless we use astnav or similar.
    // For now, assume it returns 0.
    _ = k;
    _ = tree;
    return 0;
}

// === Missing format/util.go functions ===

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const kind = @import("../ast/kind.zig");

/// Port of getCloseTokenForOpenToken.
pub fn getCloseTokenForOpenToken(k: kind.Kind) kind.Kind {
    return switch (k) {
        .OpenParenToken => .CloseParenToken,
        .LessThanToken => .GreaterThanToken,
        .OpenBraceToken => .CloseBraceToken,
        .OpenBracketToken => .CloseBracketToken,
        else => .Unknown,
    };
}

/// Port of getOpenTokenForList. Returns the opening token for a list node.
pub fn getOpenTokenForList(tree: *ast.Ast, node: ast_gen.NodeIndex, list_node: ast_gen.NodeIndex) kind.Kind {
    _ = list_node;
    const k = tree.getNodeKind(node);
    return switch (k) {
        .Constructor, .FunctionDeclaration, .FunctionExpression, .MethodDeclaration,
        .MethodSignature, .ArrowFunction, .CallSignature, .ConstructSignature,
        .FunctionType, .ConstructorType, .GetAccessor, .SetAccessor,
        => .OpenParenToken,
        .CallExpression, .NewExpression => .OpenParenToken,
        .ClassDeclaration, .ClassExpression, .InterfaceDeclaration, .TypeAliasDeclaration => .LessThanToken,
        .TypeReference, .TaggedTemplateExpression, .TypeQuery, .ExpressionWithTypeArguments, .ImportType => .LessThanToken,
        .TypeLiteral => .OpenBraceToken,
        else => .Unknown,
    };
}

/// Port of GetLineStartPositionForPosition.
pub fn getLineStartPositionForPosition(allocator: std.mem.Allocator, text: []const u8, position: usize) !usize {
    const line_starts = @import("../scanner/scanner.zig").getECMALineStarts(allocator, text);
    defer allocator.free(line_starts);
    const line = @import("../scanner/scanner.zig").getECMALineOfPositionFromStarts(line_starts, position);
    if (line < line_starts.len) return line_starts[line];
    return 0;
}

/// Port of isGrammarError. Checks if child is a grammar error on parent.
pub fn isGrammarError(tree: *ast.Ast, parent: ast_gen.NodeIndex, child: ast_gen.NodeIndex) bool {
    _ = tree;
    _ = parent;
    _ = child;
    // Simplified: requires full AST accessor support
    return false;
}

/// Port of findImmediatelyPrecedingTokenOfKind.
pub fn findImmediatelyPrecedingTokenOfKind(tree: *ast.Ast, end: u32, expected_token_kind: kind.Kind) ast_gen.NodeIndex {
    _ = tree;
    _ = end;
    _ = expected_token_kind;
    // Requires astnav.FindPrecedingToken
    return 0;
}

/// Port of findOutermostNodeWithinListLevel.
pub fn findOutermostNodeWithinListLevel(tree: *ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    var current = node;
    while (current != 0) {
        const parent = @import("../ast/ast_utils.zig").getParent(tree, current);
        if (parent == 0) break;
        // Check if parent ends at node end and node is not a list element
        const parent_end = tree.getNodeEnd(parent);
        const node_end = tree.getNodeEnd(current);
        if (parent_end != node_end or isListElement(tree, parent, current)) break;
        current = parent;
    }
    return current;
}

/// Port of isListElement. Returns true if node is an element in a parent's list.
pub fn isListElement(tree: *ast.Ast, parent: ast_gen.NodeIndex, node: ast_gen.NodeIndex) bool {
    _ = tree;
    _ = node;
    const k = tree.getNodeKind(parent);
    return switch (k) {
        .ClassDeclaration, .InterfaceDeclaration, .ModuleDeclaration,
        .SourceFile, .Block, .ModuleBlock, .CatchClause => true,
        else => false,
    };
}
