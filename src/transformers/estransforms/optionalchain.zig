const std = @import("std");

//! Optional chaining (`?.`) transformer.
//!
//! Port of `internal/transformers/estransforms/optionalchain.go` (240 LOC).
//!
//! Down-levels `a?.b`, `a?.()`, `a?.[b]` to conditional expressions
//! for targets that don't support optional chaining (pre-ES2020).
//!
//! The transformation pattern is:
//!   `a?.b`     -> `a === null || a === undefined ? undefined : a.b`
//!   `a?.()`    -> `a === null || a === undefined ? undefined : a()`
//!   `a?.[b]`   -> `a === null || a === undefined ? undefined : a[b]`
//!
//! For method calls like `a?.b()`, a temp variable is introduced to
//! avoid evaluating `a` twice:
//!   `a?.b()` -> `(_a = a) === null || _a === undefined ? undefined : _a.b()`

const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const ast_utils = @import("../../ast/ast_utils.zig");

/// Checks whether `node` is part of an optional chain (has the
/// `NodeFlagsOptionalChain` flag set).
pub fn isOptionalChain(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    return (tree.getNodeFlags(node) & 0x100) != 0; // NodeFlagsOptionalChain = 1 << 8
}

/// Returns true if `node` is an optional chain root — i.e. the
/// outermost expression of an optional chain.
pub fn isOptionalChainRoot(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (!isOptionalChain(tree, node)) return false;
    const parent = tree.getNodeParent(node);
    if (parent == 0) return true;
    const parent_kind = tree.getNodeKind(parent);
    // The root of an optional chain is the first `?.` in a chain.
    // It's the node whose parent is NOT an optional chain member.
    return switch (parent_kind) {
        .PropertyAccessExpression, .ElementAccessExpression, .CallExpression => !isOptionalChain(tree, parent),
        else => true,
    };
}

/// Transforms an optional chain expression into a conditional expression.
///
/// This is the main entry point for the optional chain transformer.
/// It detects the chain root and delegates to the appropriate helper.
///
/// TODO(phase1.3): Full implementation requires NodeFactory for
/// creating conditional expressions, temp variables, and synthetic
/// reference expressions.
pub fn transformOptionalChain(tree: *ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (!isOptionalChainRoot(tree, node)) return node;
    const kind = tree.getNodeKind(node);
    return switch (kind) {
        .PropertyAccessExpression => transformOptionalPropertyAccess(tree, node),
        .ElementAccessExpression => transformOptionalElementAccess(tree, node),
        .CallExpression => transformOptionalCall(tree, node),
        else => node,
    };
}

/// Transforms `a?.b` into a conditional expression.
/// TODO(phase1.3): wire NodeFactory
fn transformOptionalPropertyAccess(tree: *ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    _ = tree;
    _ = node;
    // Full implementation:
    // 1. Extract the expression (left side)
    // 2. If not simple copiable, introduce temp variable: _a = a
    // 3. Create condition: _a === null || _a === undefined
    // 4. Create then-branch: undefined
    // 5. Create else-branch: _a.b
    // 6. Return conditional expression
    return node;
}

/// Transforms `a?.[b]` into a conditional expression.
/// TODO(phase1.3): wire NodeFactory
fn transformOptionalElementAccess(tree: *ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    _ = tree;
    _ = node;
    return node;
}

/// Transforms `a?.()` into a conditional expression.
/// TODO(phase1.3): wire NodeFactory
fn transformOptionalCall(tree: *ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    _ = tree;
    _ = node;
    return node;
}

/// Creates a conditional expression that checks if `expr` is null or
/// undefined, returning `undefined` if so, otherwise `expr`.
///
/// Pattern: `expr === null || expr === undefined ? undefined : expr`
///
/// For non-simple expressions, a temp variable is used:
/// `(_a = expr) === null || _a === undefined ? undefined : _a`
///
/// TODO(phase1.3): wire NodeFactory
pub fn createOptionalCondition(expr: ast_gen.NodeIndex, is_simple: bool) ast_gen.NodeIndex {
    _ = expr;
    _ = is_simple;
    return 0;
}
