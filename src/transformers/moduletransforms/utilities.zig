const std = @import("std");

//! Module transform utilities.
//!
//! Port of `internal/transformers/moduletransforms/utilities.go` (118 LOC).
//!
//! Helper functions used by the CommonJS and ES module transformers:
//! - isDeclarationNameOfEnumOrNamespace
//! - rewriteModuleSpecifier
//! - createEmptyImports
//! - getExternalModuleNameLiteral
//! - tryGetModuleNameFromFile / tryGetModuleNameFromDeclaration
//! - isFileLevelReservedGeneratedIdentifier
//! - isSimpleInlineableExpression

const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const ast_utils = @import("../../ast/ast_utils.zig");

/// Returns true if `node` is the name of an enum or namespace declaration.
/// Port of Go's `isDeclarationNameOfEnumOrNamespace`.
pub fn isDeclarationNameOfEnumOrNamespace(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    const parent = tree.getNodeParent(node);
    if (parent == 0) return false;
    const parent_kind = tree.getNodeKind(parent);
    if (parent_kind == .EnumDeclaration or parent_kind == .ModuleDeclaration) {
        // Check that node is the name of the parent.
        const name_node = ast_utils.name(tree, parent);
        return name_node == node;
    }
    return false;
}

/// Returns true if `expression` is a simple inlineable expression (not an
/// identifier, but a simple copiable expression like a literal).
/// Port of Go's `isSimpleInlineableExpression`.
pub fn isSimpleInlineableExpression(tree: *ast.Ast, expression: ast_gen.NodeIndex) bool {
    if (expression == 0) return false;
    if (ast_utils.isIdentifier(tree, expression)) return false;
    // IsSimpleCopiableExpression: literal, array literal, object literal
    // (without computed property names), etc. Conservative check:
    const kind = tree.getNodeKind(expression);
    return switch (kind) {
        .StringLiteral, .NumericLiteral, .BigIntLiteral, .TrueKeyword, .FalseKeyword, .NullKeyword => true,
        .ArrayLiteralExpression => true,
        .ObjectLiteralExpression => true,
        else => false,
    };
}

/// Creates an empty `export {}` declaration to mark a file as a module.
/// Port of Go's `createEmptyImports`.
/// NOTE: Requires NodeFactory; returns 0 until factory is wired.
pub fn createEmptyImports() ast_gen.NodeIndex {
    // TODO(phase1.3): wire NodeFactory.NewExportDeclaration + NewNamedExports
    return 0;
}

/// Rewrites a module specifier (e.g. "./foo.ts" -> "./foo.js") based on
/// compiler options. Port of Go's `rewriteModuleSpecifier`.
/// NOTE: Requires EmitContext + NodeFactory; returns the original node
/// until those are wired.
pub fn rewriteModuleSpecifier(node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    // TODO(phase1.3): wire ShouldRewriteModuleSpecifier + ChangeExtension +
    // GetOutputExtension + EmitContext.Factory.NewStringLiteral
    return node;
}
