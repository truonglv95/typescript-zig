//! Language service utilities.
//!
//! Port of `internal/ls/utilities.go` (1,404 LOC).
//!
//! Helper functions used across all language service features:
//! - Position-based queries (IsInString, getTouchingPropertyName)
//! - Symbol resolution helpers
//! - Module specifier detection
//! - Display name formatting
//! - Diagnostic conversion
const std = @import("std");


const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const symbol = @import("../ast/symbol.zig");
const checker = @import("../checker/checker.zig");
const types = @import("../checker/types.zig");
const scanner = @import("../scanner/scanner.zig");
const tspath = @import("../tspath/tspath.zig");

/// Returns true if `position` is inside a string literal.
/// Port of Go's `IsInString`.
pub fn isInString(tree: *ast.Ast, position: u32, previous_token: ast_gen.NodeIndex) bool {
    if (previous_token == 0) return false;
    // Check if the token is a string-text-containing node.
    const kind = tree.getNodeKind(previous_token);
    if (kind != .StringLiteral and
        kind != .NoSubstitutionTemplateLiteral and
        kind != .TemplateHead and
        kind != .TemplateMiddle and
        kind != .TemplateTail)
    {
        return false;
    }
    const start = tree.getNodePos(previous_token);
    const end = tree.getNodeEnd(previous_token);
    // Position must be entirely within the token text.
    if (start < position and position < end) return true;
    // Or at the end position of an unterminated literal.
    if (position == end) {
        // Check for unterminated literal (simplified: check if the last
        // character is not a closing quote/backtick).
        if (end > start) {
            const text = tree.sourceText;
            if (end <= text.len) {
                const last_char = text[end - 1];
                return last_char != '"' and last_char != '\'' and last_char != '`';
            }
        }
    }
    return false;
}

/// Returns true if `node` is a module specifier (the string literal in
/// an import/require/external module reference).
/// Port of Go's `isModuleSpecifierLike`.
pub fn isModuleSpecifierLike(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    const kind = tree.getNodeKind(node);
    if (kind != .StringLiteral) return false;
    const parent = tree.getNodeParent(node);
    if (parent == 0) return false;
    const parent_kind = tree.getNodeKind(parent);
    switch (parent_kind) {
        .CallExpression => {
            // require("mod") — check if node is the first argument.
            const call = tree.getNode(parent).CallExpression;
            const args = tree.getNodeList(call.Arguments);
            return args.len > 0 and args[0] == node;
        },
        .ImportCall => {
            // import("mod") — check if node is the first argument.
            // CallExpression with ImportCall kind uses Arguments field.
            const call = tree.getNode(parent).CallExpression;
            const args = tree.getNodeList(call.Arguments);
            return args.len > 0 and args[0] == node;
        },
        .ExternalModuleReference, .ImportDeclaration, .JSImportDeclaration => return true,
        else => return false,
    }
}

/// Returns the non-module symbol for a merged module symbol.
/// Port of Go's `getNonModuleSymbolOfMergedModuleSymbol`.
pub fn getNonModuleSymbolOfMergedModuleSymbol(
    tree: *ast.Ast,
    symbols: *const std.ArrayListUnmanaged(symbol.Symbol),
    sym: ast_gen.SymbolIndex,
) ?ast_gen.SymbolIndex {
    if (sym == 0 or sym >= symbols.items.len) return null;
    const sym_obj = symbols.items[sym];
    if ((sym_obj.Flags & (symbol.SymbolFlags.Module | symbol.SymbolFlags.Transient)) == 0) return null;
    if (sym_obj.Declarations.items.len == 0) return null;
    // Find a declaration that is NOT a SourceFile or ModuleDeclaration.
    for (sym_obj.Declarations.items) |decl| {
        if (decl == 0) continue;
        const kind = tree.getNodeKind(decl);
        if (kind != .SourceFile and kind != .ModuleDeclaration) {
            return tree.getNodeSymbol(decl);
        }
    }
    return null;
}

/// Replaces single quotes with `\'` and double quotes with `\"`.
/// Port of Go's `quoteReplacer`.
pub fn escapeQuotes(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    var result = std.ArrayList(u8).empty;
    defer result.deinit(allocator);
    for (text) |c| {
        switch (c) {
            '\'' => try result.appendSlice(allocator, "\\'"),
            '"' => try result.appendSlice(allocator, "\\\""),
            else => try result.append(allocator, c),
        }
    }
    return result.toOwnedSlice(allocator);
}

/// Returns true if the given node is at the given position.
/// Port of Go's position-in-range check.
pub fn isPositionInNode(tree: *ast.Ast, node: ast_gen.NodeIndex, position: u32) bool {
    if (node == 0) return false;
    const start = tree.getNodePos(node);
    const end = tree.getNodeEnd(node);
    return start <= position and position < end;
}

/// Returns the node at the given position (touching property name).
/// Port of Go's `getTouchingPropertyName`.
pub fn getTouchingPropertyName(tree: *ast.Ast, source_file: ast_gen.NodeIndex, position: u32) ast_gen.NodeIndex {
    _ = source_file;
    // Simplified: walk all nodes and find the one at the position.
    // Full implementation uses astnav.getTouchingPropertyName.
    // For now, return 0 (not found).
    _ = position;
    _ = tree;
    return 0;
}

/// Converts a checker type to a display string.
/// Port of Go's type-to-string conversion (simplified).
pub fn typeToString(c: *checker.Checker, t: types.TypeIndex) []const u8 {
    return c.typeToString(t, 0, 0, null);
}

/// Returns the line and column (0-based) for a byte offset in text.
pub fn offsetToLineColumn(text: []const u8, offset: u32) struct { line: u32, column: u32 } {
    var line: u32 = 0;
    var column: u32 = 0;
    var i: u32 = 0;
    while (i < offset and i < text.len) : (i += 1) {
        if (text[i] == '\n') {
            line += 1;
            column = 0;
        } else {
            column += 1;
        }
    }
    return .{ .line = line, .column = column };
}

/// Converts a line and column (0-based) to a byte offset in text.
pub fn lineColumnToOffset(text: []const u8, line: u32, column: u32) u32 {
    var current_line: u32 = 0;
    var offset: u32 = 0;
    while (offset < text.len and current_line < line) {
        if (text[offset] == '\n') {
            current_line += 1;
        }
        offset += 1;
    }
    // Now at the start of the target line. Add column.
    var col: u32 = 0;
    while (offset < text.len and col < column and text[offset] != '\n') {
        offset += 1;
        col += 1;
    }
    return offset;
}
pub fn getAllSuperTypeNodes(arena: std.mem.Allocator, tree: *const ast.Tree, node: ast.NodeIndex) ![]ast.NodeIndex {
    if (tree.nodeTag(node) == .InterfaceDeclaration) {
        return ast.getHeritageElements(arena, tree, node, .ExtendsKeyword);
    }
    if (ast.isClassLike(tree.nodeTag(node))) {
        var result = std.ArrayList(ast.NodeIndex).init(arena);
        if (ast.getClassExtendsHeritageElement(tree, node)) |extendsNode| {
            try result.append(extendsNode);
        }
        const implementsNodes = try ast.getImplementsTypeNodes(arena, tree, node);
        try result.appendSlice(implementsNodes);
        return result.items;
    }
    return &[_]ast.NodeIndex{};
}

pub fn getPropertySymbolsFromBaseTypes(
    arena: std.mem.Allocator,
    tree: *const ast.Tree,
    sym: *ast.Symbol,
    propertyName: []const u8,
    type_checker: *checker.Checker,
    ctx: anytype,
    comptime cb: anytype, // fn (ctx: @TypeOf(ctx), base: *ast.Symbol) ?*ast.Symbol
) !?*ast.Symbol {
    var seen = std.AutoHashMap(*ast.Symbol, void).init(arena);
    return try getPropertySymbolsFromBaseTypesRecur(arena, tree, sym, propertyName, type_checker, ctx, cb, &seen);
}

fn getPropertySymbolsFromBaseTypesRecur(
    arena: std.mem.Allocator,
    tree: *const ast.Tree,
    sym: *ast.Symbol,
    propertyName: []const u8,
    type_checker: *checker.Checker,
    ctx: anytype,
    comptime cb: anytype,
    seen: *std.AutoHashMap(*ast.Symbol, void),
) anyerror!?*ast.Symbol {
    if ((sym.Flags & (checker.SymbolFlags.Class | checker.SymbolFlags.Interface)) == 0) return null;
    if (try seen.fetchPut(sym, {})) |_| return null;
    
    const declarations = sym.Declarations.items;
    for (declarations) |declaration| {
        const superTypeNodes = try getAllSuperTypeNodes(arena, tree, declaration);
        for (superTypeNodes) |typeReference| {
            if (type_checker.getTypeAtLocation(tree, typeReference)) |propertyType| {
                if (propertyType.symbol) |propertyTypeSymbol| {
                    if (type_checker.getPropertyOfType(propertyType, propertyName)) |propertySymbol| {
                        const rootSymbols = type_checker.getRootSymbols(arena, propertySymbol);
                        for (rootSymbols) |rootSymbol| {
                            if (cb(ctx, rootSymbol)) |result| {
                                return result;
                            }
                        }
                    }
                    if (try getPropertySymbolsFromBaseTypesRecur(arena, tree, propertyTypeSymbol, propertyName, type_checker, ctx, cb, seen)) |result| {
                        return result;
                    }
                }
            }
        }
    }
    return null;
}

pub fn getPropertySymbolFromBindingElement(tree: *const ast.Tree, type_checker: *checker.Checker, bindingElement: ast.NodeIndex) ?*ast.Symbol {
    if (tree.nodeParent(bindingElement)) |parent| {
        if (type_checker.getTypeAtLocation(tree, parent)) |typeOfPattern| {
            if (ast.name(tree, bindingElement)) |nameNode| {
                const nameText = ast_utils.getTextOfNode(tree, nameNode);
                return type_checker.getPropertyOfType(typeOfPattern, nameText);
            }
        }
    }
    return null;
}

pub fn getPropertySymbolOfObjectBindingPatternWithoutPropertyName(tree: *const ast.Tree, sym: *ast.Symbol, type_checker: *checker.Checker) ?*ast.Symbol {
    const declarations = sym.Declarations.items;
    var bindingElement: ?ast.NodeIndex = null;
    for (declarations) |decl| {
        if (tree.nodeTag(decl) == .BindingElement) {
            bindingElement = decl;
            break;
        }
    }
    if (bindingElement) |element| {
        if (isObjectBindingElementWithoutPropertyName(tree, element)) {
            return getPropertySymbolFromBindingElement(tree, type_checker, element);
        }
    }
    return null;
}

pub fn isObjectBindingElementWithoutPropertyName(tree: *const ast.Tree, node: ast.NodeIndex) bool {
    return tree.nodeTag(node) == .BindingElement and ast.propertyName(tree, node) == null and tree.nodeParent(node) != null and tree.nodeTag(tree.nodeParent(node).?) == .ObjectBindingPattern;
}

pub fn isStaticSymbol(tree: *const ast.Tree, sym: *ast.Symbol) bool {
    if (sym.ValueDeclaration) |decl| {
        const modifierFlags = ast.modifierFlags(tree, decl);
        return (modifierFlags & ast.ModifierFlags.Static) != 0;
    }
    return false;
}

pub fn getAdjustedLocation(tree: *ast.Ast, node: ast_gen.NodeIndex, forRename: bool, sourceFile: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const parent = tree.getNodeParent(node);
    if (parent == 0) return node;

    const kind = tree.getNodeKind(node);
    const parent_kind = tree.getNodeKind(parent);

    var is_modifier = false;
    if (ast_utils.isModifier(tree, node) and (forRename or kind != .DefaultKeyword)) {
        is_modifier = ast_utils.canHaveModifiers(tree, parent) and ast_utils.hasModifier(tree, parent, kind);
    } else {
        switch (kind) {
            .ClassKeyword => is_modifier = parent_kind == .ClassDeclaration or parent_kind == .ClassExpression,
            .FunctionKeyword => is_modifier = parent_kind == .FunctionDeclaration or parent_kind == .FunctionExpression,
            .InterfaceKeyword => is_modifier = parent_kind == .InterfaceDeclaration,
            .EnumKeyword => is_modifier = parent_kind == .EnumDeclaration,
            .TypeKeyword => is_modifier = parent_kind == .TypeAliasDeclaration,
            .NamespaceKeyword, .ModuleKeyword => is_modifier = parent_kind == .ModuleDeclaration,
            .ImportKeyword => is_modifier = parent_kind == .ImportEqualsDeclaration,
            .GetKeyword => is_modifier = parent_kind == .GetAccessor,
            .SetKeyword => is_modifier = parent_kind == .SetAccessor,
            else => {},
        }
    }

    if (is_modifier) {
        var src_file = sourceFile;
        if (src_file == 0) src_file = ast_utils.getSourceFileOfNode(tree, node);
        const location = getAdjustedLocationForDeclaration(tree, parent, forRename, src_file);
        if (location != 0) return location;
    }

    if (kind == .VarKeyword or kind == .ConstKeyword or kind == .LetKeyword) {
        if (parent_kind == .VariableDeclarationList) {
            const list = tree.getNodeList(tree.getNode(parent).VariableDeclarationList.declarations);
            if (list.len == 1) {
                const decl = tree.getNode(list[0]).VariableDeclaration;
                if (tree.getNodeKind(decl.name) == .Identifier) {
                    return decl.name;
                }
            }
        }
    }

    if (kind == .TypeKeyword) {
        if (parent_kind == .ImportClause and tree.getNode(parent).ImportClause.isTypeOnly) {
            const import_decl = tree.getNodeParent(parent);
            if (tree.getNodeKind(import_decl) == .ImportDeclaration) {
                const location = getAdjustedLocationForImportDeclaration(tree, import_decl, forRename);
                if (location != 0) return location;
            }
        }
        if (parent_kind == .ExportDeclaration and tree.getNode(parent).ExportDeclaration.isTypeOnly) {
            const location = getAdjustedLocationForExportDeclaration(tree, parent, forRename);
            if (location != 0) return location;
        }
    }

    if (kind == .AsKeyword) {
        if (parent_kind == .ImportSpecifier) {
            const spec = tree.getNode(parent).ImportSpecifier;
            if (spec.propertyName != 0) return spec.name;
        } else if (parent_kind == .ExportSpecifier) {
            const spec = tree.getNode(parent).ExportSpecifier;
            if (spec.propertyName != 0) return spec.name;
        } else if (parent_kind == .NamespaceImport or parent_kind == .NamespaceExport) {
            return ast_utils.getName(tree, parent); // name
        } else if (parent_kind == .ExportDeclaration) {
            const decl = tree.getNode(parent).ExportDeclaration;
            if (decl.exportClause != 0 and tree.getNodeKind(decl.exportClause) == .NamespaceExport) {
                return ast_utils.getName(tree, decl.exportClause);
            }
        }
    }

    if (kind == .ImportKeyword and parent_kind == .ImportDeclaration) {
        const location = getAdjustedLocationForImportDeclaration(tree, parent, forRename);
        if (location != 0) return location;
    }

    if (kind == .ExportKeyword) {
        if (parent_kind == .ExportDeclaration) {
            const location = getAdjustedLocationForExportDeclaration(tree, parent, forRename);
            if (location != 0) return location;
        }
        if (parent_kind == .ExportAssignment) {
            return ast_utils.skipOuterExpressions(tree, tree.getNode(parent).ExportAssignment.expression, ast_utils.OEKAll);
        }
    }

    if (kind == .RequireKeyword and parent_kind == .ExternalModuleReference) {
        return tree.getNode(parent).ExternalModuleReference.expression;
    }

    if (kind == .FromKeyword) {
        if (parent_kind == .ImportDeclaration) {
            const decl = tree.getNode(parent).ImportDeclaration;
            if (decl.moduleSpecifier != 0) return decl.moduleSpecifier;
        } else if (parent_kind == .ExportDeclaration) {
            const decl = tree.getNode(parent).ExportDeclaration;
            if (decl.moduleSpecifier != 0) return decl.moduleSpecifier;
        }
    }

    if (kind == .ExtendsKeyword or kind == .ImplementsKeyword) {
        if (parent_kind == .HeritageClause) {
            const hc = tree.getNode(parent).HeritageClause;
            if (hc.token == kind) {
                const hc_types = tree.getNodeList(hc.types);
                if (hc_types.len == 1) {
                    const expr = tree.getNode(hc_types[0]).ExpressionWithTypeArguments.expression;
                    return expr;
                }
            }
        }
    }

    if (kind == .DefaultKeyword) {
        if (parent_kind == .ExportAssignment) {
            return ast_utils.skipOuterExpressions(tree, tree.getNode(parent).ExportAssignment.expression, ast_utils.OEKAll);
        }
    }

    if (kind == .InKeyword and parent_kind == .ForInStatement) {
        return ast_utils.skipOuterExpressions(tree, tree.getNode(parent).ForInStatement.expression, ast_utils.OEKAll);
    }
    if (kind == .OfKeyword and parent_kind == .ForOfStatement) {
        return ast_utils.skipOuterExpressions(tree, tree.getNode(parent).ForOfStatement.expression, ast_utils.OEKAll);
    }

    return node;
}

pub fn getAdjustedLocationForDeclaration(tree: *ast.Ast, node: ast_gen.NodeIndex, forRename: bool, sourceFile: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const name = ast_utils.getName(tree, node);
    if (name != 0) return name;
    if (forRename) return 0;
    
    const kind = tree.getNodeKind(node);
    if (kind == .ClassDeclaration or kind == .FunctionDeclaration) {
        // find default modifier
        const modifiers = ast_utils.getModifiers(tree, node);
        if (modifiers != 0) {
            const list = tree.getNodeList(modifiers);
            for (list) |mod| {
                if (tree.getNodeKind(mod) == .DefaultKeyword) return mod;
            }
        }
        return 0;
    }
    if (kind == .ClassExpression) {
        return ast_utils.findChildOfKind(tree, node, .ClassKeyword, sourceFile);
    }
    if (kind == .FunctionExpression) {
        return ast_utils.findChildOfKind(tree, node, .FunctionKeyword, sourceFile);
    }
    if (kind == .Constructor) return node;

    return 0;
}

pub fn getAdjustedLocationForImportDeclaration(tree: *ast.Ast, node: ast_gen.NodeIndex, forRename: bool) ast_gen.NodeIndex {
    const decl = tree.getNode(node).ImportDeclaration;
    if (decl.importClause != 0) {
        const ic = tree.getNode(decl.importClause).ImportClause;
        if (ic.name != 0) {
            if (ic.namedBindings != 0) return 0;
            return ic.name;
        }
        if (ic.namedBindings != 0) {
            const nb_kind = tree.getNodeKind(ic.namedBindings);
            if (nb_kind == .NamedImports) {
                const elements = tree.getNodeList(tree.getNode(ic.namedBindings).NamedImports.elements);
                if (elements.len != 1) return 0;
                return ast_utils.getName(tree, elements[0]);
            } else if (nb_kind == .NamespaceImport) {
                return ast_utils.getName(tree, ic.namedBindings);
            }
        }
    }
    if (!forRename) {
        return decl.moduleSpecifier;
    }
    return 0;
}

pub fn getAdjustedLocationForExportDeclaration(tree: *ast.Ast, node: ast_gen.NodeIndex, forRename: bool) ast_gen.NodeIndex {
    const decl = tree.getNode(node).ExportDeclaration;
    if (decl.exportClause != 0) {
        const ec_kind = tree.getNodeKind(decl.exportClause);
        if (ec_kind == .NamedExports) {
            const elements = tree.getNodeList(tree.getNode(decl.exportClause).NamedExports.elements);
            if (elements.len != 1) return 0;
            return ast_utils.getName(tree, elements[0]);
        } else if (ec_kind == .NamespaceExport) {
            return ast_utils.getName(tree, decl.exportClause);
        }
    }
    if (!forRename) {
        return decl.moduleSpecifier;
    }
    return 0;
}
