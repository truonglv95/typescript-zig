const std = @import("std");

//! Code lens provider — shows "N references" / "N implementations" above symbols.
//!
//! Port of `internal/ls/codelens.go` (207 LOC).
//!
//! Walks the AST and creates code lenses for:
//! - Functions, classes, interfaces, etc. (references count)
//! - Abstract methods / interface members (implementations count)

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const symbol = @import("../ast/symbol.zig");

/// The kind of code lens.
pub const CodeLensKind = enum {
    References,
    Implementations,
};

/// A code lens entry.
pub const CodeLens = struct {
    /// Line where the lens appears (0-based).
    line: u32,
    /// Character where the lens appears (0-based).
    character: u32,
    /// The kind of lens (references or implementations).
    kind: CodeLensKind,
    /// The node the lens is attached to.
    node: ast_gen.NodeIndex,
};

/// Returns true if the node is valid for a references code lens.
/// Port of Go's `isValidReferenceLensNode`.
pub fn isValidReferenceLensNode(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    const kind = tree.getNodeKind(node);
    return switch (kind) {
        .FunctionDeclaration,
        .ClassDeclaration,
        .InterfaceDeclaration,
        .EnumDeclaration,
        .VariableDeclaration,
        .MethodDeclaration,
        .PropertyDeclaration,
        .GetAccessor,
        .SetAccessor,
        => true,
        else => false,
    };
}

/// Returns true if the node is valid for an implementations code lens.
/// Port of Go's `isValidImplementationsCodeLensNode`.
pub fn isValidImplementationsCodeLensNode(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    const kind = tree.getNodeKind(node);
    // Only abstract methods and interface members get implementation lenses.
    if (kind == .MethodDeclaration or kind == .PropertyDeclaration) {
        // Check for abstract modifier.
        return ast_utils.hasSyntacticModifier(tree, node, ast_utils.ModifierFlags.Abstract);
    }
    if (kind == .MethodSignature or kind == .PropertySignature) {
        return true; // Interface members.
    }
    return false;
}

/// Collects code lenses for a source file.
/// Port of Go's `ProvideCodeLenses`.
pub fn collectCodeLenses(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    source_file: ast_gen.NodeIndex,
    references_enabled: bool,
    implementations_enabled: bool,
) ![]CodeLens {
    var result = std.ArrayListUnmanaged(CodeLens).empty;
    if (!references_enabled and !implementations_enabled) return result.toOwnedSlice(allocator);

    // Walk the AST and collect lenses.
    // Simplified: just check top-level statements.
    if (source_file == 0) return result.toOwnedSlice(allocator);
    const sf = tree.getNode(source_file);
    if (sf != .SourceFile) return result.toOwnedSlice(allocator);
    const stmts = tree.getNodeList(sf.SourceFile.Statements);

    var last_symbol: ast_gen.SymbolIndex = 0;
    for (stmts) |stmt| {
        const current_symbol = tree.getNodeSymbol(stmt) orelse 0;
        if (current_symbol != last_symbol) {
            last_symbol = current_symbol;
            const pos = tree.getNodePos(stmt);
            if (references_enabled and isValidReferenceLensNode(tree, stmt)) {
                try result.append(allocator, .{
                    .line = 0, // TODO: convert pos to line
                    .character = pos,
                    .kind = .References,
                    .node = stmt,
                });
            }
            if (implementations_enabled and isValidImplementationsCodeLensNode(tree, stmt)) {
                try result.append(allocator, .{
                    .line = 0,
                    .character = pos,
                    .kind = .Implementations,
                    .node = stmt,
                });
            }
        }
    }

    return result.toOwnedSlice(allocator);
}
