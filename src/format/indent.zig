const std = @import("std");
const ast = @import("../ast/ast.zig");
const lsutil = @import("../ls/lsutil/lsutil.zig");

pub fn getIndentationForNode(n: ast.NodeIndex, originalRange: *const ast.TextRange, tree: *ast.Ast, options: lsutil.FormatCodeSettings) u32 {
    _ = n;
    _ = originalRange;
    _ = tree;
    _ = options;
    // TODO: implement GetIndentationForNode
    return 0;
}

const scanner = @import("scanner.zig");
const root_scanner = @import("../scanner/scanner.zig");
const ast_gen = @import("../ast/ast_generated.zig");


pub fn isControlFlowEndingStatement(k: std.meta.Tag(ast_gen.NodeData), parentKind: std.meta.Tag(ast_gen.NodeData)) bool {
    switch (k) {
        .ReturnStatement, .ThrowStatement, .ContinueStatement, .BreakStatement => {
            return parentKind != .Block;
        },
        else => return false,
    }
}

pub fn rangeIsOnOneLine(range: ast.TextRange, tree: *ast.Ast) bool {
    const startLine = root_scanner.getECMALineOfPosition(tree.sourceText, range.pos);
    const endLine = root_scanner.getECMALineOfPosition(tree.sourceText, range.end);
    return startLine == endLine;
}

pub fn nodeWillIndentChild(settings: lsutil.FormatCodeSettings, parent: ast.NodeIndex, child: ?ast.NodeIndex, tree: *ast.Ast, indentByDefault: bool) bool {
    const childKind = if (child != null) std.meta.activeTag(tree.getNode(child.?)) else .Unknown;
    const parentKind = std.meta.activeTag(tree.getNode(parent));

    switch (parentKind) {
        .ExpressionStatement,
        .ClassDeclaration,
        .ClassExpression,
        .InterfaceDeclaration,
        .EnumDeclaration,
        .TypeAliasDeclaration,
        .ArrayLiteralExpression,
        .Block,
        .ModuleBlock,
        .ObjectLiteralExpression,
        .TypeLiteral,
        .MappedType,
        .TupleType,
        .ParenthesizedExpression,
        .PropertyAccessExpression,
        .CallExpression,
        .NewExpression,
        .VariableStatement,
        .ExportAssignment,
        .ReturnStatement,
        .ConditionalExpression,
        .ArrayBindingPattern,
        .ObjectBindingPattern,
        .JsxOpeningElement,
        .JsxOpeningFragment,
        .JsxSelfClosingElement,
        .JsxExpression,
        .MethodSignature,
        .CallSignature,
        .ConstructSignature,
        .Parameter,
        .FunctionType,
        .ConstructorType,
        .ParenthesizedType,
        .TaggedTemplateExpression,
        .AwaitExpression,
        .NamedExports,
        .NamedImports,
        .ExportSpecifier,
        .ImportSpecifier,
        .PropertyDeclaration,
        .CaseClause,
        .DefaultClause => return true,

        .CaseBlock => return settings.indentSwitchCase.isTrueOrUnknown(),

        .VariableDeclaration, .PropertyAssignment, .BinaryExpression => {
            if (settings.indentMultiLineObjectLiteralBeginningOnBlankLine.isFalseOrUnknown() and childKind == .ObjectLiteralExpression) {
                return rangeIsOnOneLine(tree.positions.items[child.?], tree);
            }
            if (parentKind == .BinaryExpression and childKind == .JsxElement) {
                const parentStartLine = root_scanner.getECMALineOfPosition(tree.sourceText, root_scanner.skipTrivia(tree.sourceText, tree.positions.items[parent].pos));
                const childStartLine = root_scanner.getECMALineOfPosition(tree.sourceText, root_scanner.skipTrivia(tree.sourceText, tree.positions.items[child.?].pos));
                return parentStartLine != childStartLine;
            }
            if (parentKind != .BinaryExpression) {
                return true;
            }
            return indentByDefault;
        },

        .DoStatement,
        .WhileStatement,
        .ForInStatement,
        .ForOfStatement,
        .ForStatement,
        .IfStatement,
        .FunctionDeclaration,
        .FunctionExpression,
        .MethodDeclaration,
        .Constructor,
        .GetAccessor,
        .SetAccessor => return childKind != .Block,

        .ArrowFunction => {
            if (childKind == .ParenthesizedExpression) {
                return rangeIsOnOneLine(tree.positions.items[child.?], tree);
            }
            return childKind != .Block;
        },

        .ExportDeclaration => return childKind != .NamedExports,

        .ImportDeclaration => {
            if (childKind != .ImportClause) return true;
            const importClause = tree.getNode(child.?).ImportClause;
            if (importClause.NamedBindings != null) {
                const nbKind = std.meta.activeTag(tree.getNode(importClause.NamedBindings.?));
                if (nbKind != .NamedImports) return true;
            }
            return false;
        },

        .JsxElement => return childKind != .JsxClosingElement,
        .JsxFragment => return childKind != .JsxClosingFragment,

        .IntersectionType, .UnionType, .SatisfiesExpression => {
            if (childKind == .TypeLiteral or childKind == .TupleType or childKind == .MappedType) {
                return false;
            }
            return indentByDefault;
        },

        .TryStatement => {
            if (childKind == .Block) {
                return false;
            }
            return indentByDefault;
        },

        else => return indentByDefault,
    }
}

pub fn shouldIndentChildNode(options: lsutil.FormatCodeSettings, parent: ast.NodeIndex, child: ?ast.NodeIndex, tree: *ast.Ast, isNextChild: bool) bool {
    const willIndent = nodeWillIndentChild(options, parent, child, tree, false);
    if (!willIndent) return false;
    
    if (isNextChild and child != null) {
        const childKind = std.meta.activeTag(tree.getNode(child.?));
        const parentKind = std.meta.activeTag(tree.getNode(parent));
        if (isControlFlowEndingStatement(childKind, parentKind)) {
            return false;
        }
    }
    return true;
}
