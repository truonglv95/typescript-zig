const std = @import("std");
const ast = @import("../../ast/ast.zig");
const astnav = @import("../../ast/ast_utils.zig");
const scanner = @import("../../scanner/scanner.zig");
const children = @import("children.zig");

pub fn positionIsASICandidate(tree: *ast.Ast, pos: u32, contextNode: ast.NodeIndex) bool {
    var contextAncestor = contextNode;
    while (contextAncestor != 0) {
        if (tree.positions.items[contextAncestor].end != pos) {
            contextAncestor = 0;
            break;
        }
        if (syntaxMayBeASICandidate(tree.getNodeKind(contextAncestor))) {
            break;
        }
        contextAncestor = tree.getNodeParent(contextAncestor);
    }
    return contextAncestor != 0 and nodeIsASICandidate(tree, contextAncestor);
}

pub fn syntaxMayBeASICandidate(kind: @import("../../ast/kind.zig").Kind) bool {
    return syntaxRequiresTrailingCommaOrSemicolonOrASI(kind) or
        syntaxRequiresTrailingFunctionBlockOrSemicolonOrASI(kind) or
        syntaxRequiresTrailingModuleBlockOrSemicolonOrASI(kind) or
        syntaxRequiresTrailingSemicolonOrASI(kind);
}

pub fn syntaxRequiresTrailingCommaOrSemicolonOrASI(kind: @import("../../ast/kind.zig").Kind) bool {
    return kind == .CallSignature or
        kind == .ConstructSignature or
        kind == .IndexSignature or
        kind == .PropertySignature or
        kind == .MethodSignature;
}

pub fn syntaxRequiresTrailingFunctionBlockOrSemicolonOrASI(kind: @import("../../ast/kind.zig").Kind) bool {
    return kind == .FunctionDeclaration or
        kind == .Constructor or
        kind == .MethodDeclaration or
        kind == .GetAccessor or
        kind == .SetAccessor;
}

pub fn syntaxRequiresTrailingModuleBlockOrSemicolonOrASI(kind: @import("../../ast/kind.zig").Kind) bool {
    return kind == .ModuleDeclaration;
}

pub fn syntaxRequiresTrailingSemicolonOrASI(kind: @import("../../ast/kind.zig").Kind) bool {
    return kind == .VariableStatement or
        kind == .ExpressionStatement or
        kind == .DoStatement or
        kind == .ContinueStatement or
        kind == .BreakStatement or
        kind == .ReturnStatement or
        kind == .ThrowStatement or
        kind == .DebuggerStatement or
        kind == .PropertyDeclaration or
        kind == .TypeAliasDeclaration or
        kind == .ImportDeclaration or
        kind == .ImportEqualsDeclaration or
        kind == .ExportDeclaration or
        kind == .NamespaceExportDeclaration or
        kind == .ExportAssignment;
}

pub fn nodeIsASICandidate(tree: *ast.Ast, node: ast.NodeIndex) bool {
    const lastToken = children.getLastToken(tree, node);
    if (lastToken != null and tree.getNodeKind(lastToken.?) == .SemicolonToken) {
        return false;
    }

    const kind = tree.getNodeKind(node);
    if (syntaxRequiresTrailingCommaOrSemicolonOrASI(kind)) {
        if (lastToken != null and tree.getNodeKind(lastToken.?) == .CommaToken) {
            return false;
        }
    } else if (syntaxRequiresTrailingModuleBlockOrSemicolonOrASI(kind)) {
        const lastChild = children.getLastChild(tree, node);
        if (lastChild != null and tree.getNodeKind(lastChild.?) == .ModuleBlock) {
            return false;
        }
    } else if (syntaxRequiresTrailingFunctionBlockOrSemicolonOrASI(kind)) {
        const lastChild = children.getLastChild(tree, node);
        if (lastChild != null and tree.getNodeKind(lastChild.?) == .Block) {
            return false;
        }
    } else if (!syntaxRequiresTrailingSemicolonOrASI(kind)) {
        return false;
    }

    if (kind == .DoStatement) {
        return true;
    }

    var topNode = node;
    while (tree.getNodeParent(topNode) != 0) {
        topNode = tree.getNodeParent(topNode);
    }
    const nextToken = astnav.findNextToken(tree, node, topNode);
    if (nextToken == null or tree.getNodeKind(nextToken.?) == .CloseBraceToken) {
        return true;
    }

    const startLine = scanner.getECMALineOfPosition(tree, tree.positions.items[node].end);
    const endLine = scanner.getECMALineOfPosition(tree, astnav.getStartOfNode(tree, nextToken.?, false));
    return startLine != endLine;
}
