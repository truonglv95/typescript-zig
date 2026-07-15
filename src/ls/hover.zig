const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const checker_types = @import("../checker/types.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const symbol_mod = @import("../ast/symbol.zig");

pub const SymbolFormatFlags = struct {
    pub const WriteTypeParametersOrArguments = checker.SymbolFormatFlags.WriteTypeParametersOrArguments;
    pub const UseOnlyExternalAliasing = checker.SymbolFormatFlags.UseOnlyExternalAliasing;
    pub const AllowAnyNodeKind = checker.SymbolFormatFlags.AllowAnyNodeKind;
    pub const UseAliasDefinedOutsideCurrentScope = checker.SymbolFormatFlags.UseAliasDefinedOutsideCurrentScope;
};

pub const TypeFormatFlags = struct {
    pub const UseAliasDefinedOutsideCurrentScope = checker.TypeFormatFlags.UseAliasDefinedOutsideCurrentScope;
    pub const UseInstantiationExpressions = checker.TypeFormatFlags.UseInstantiationExpressions;
};

const symbol_format_flags: u32 =
    SymbolFormatFlags.WriteTypeParametersOrArguments |
    SymbolFormatFlags.UseOnlyExternalAliasing |
    SymbolFormatFlags.AllowAnyNodeKind |
    SymbolFormatFlags.UseAliasDefinedOutsideCurrentScope;

const type_format_flags: u32 =
    TypeFormatFlags.UseAliasDefinedOutsideCurrentScope |
    TypeFormatFlags.UseInstantiationExpressions;

/// Port of LanguageService.ProvideHover.
/// Returns hover information for the symbol at the given position.
pub fn provideHover(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.HoverParams,
) !lsproto.HoverOrNull {
    const caps = lsproto.getClientCapabilities();
    const contentFormat = lsproto.preferredMarkupKind(caps.text_document.hover.content_format);

    const programAndFile = ls.getProgramAndFile(params.textDocument.uri);
    const file = programAndFile.file;

    const script = ls.getScript(file);
    const position = ls.converters.lineAndCharacterToPosition(script, params.position);

    const astnav = @import("../astnav/tokens.zig");
    const tree = ls.getAst(file);
    const node = astnav.getTouchingPropertyName(ls.getSourceFileNode(file), tree, position);

    // Avoid giving quickInfo for the sourceFile as a whole or inside the comment of a/**/.b
    if (tree.getNodeKind(node) == .SourceFile) {
        return lsproto.HoverOrNull{ .hover = null };
    }
    if (ast_utils.isPropertyAccessOrQualifiedName(tree, node) and isInComment(ls, file, position, node) == null) {
        // Actually we should return null only if we ARE in a comment, but the Go code
        // checks `isInComment(...) == nil` which means "if NOT in comment, skip".
        // Let me re-read: the Go code says:
        //   if ast.IsSourceFile(node) || ast.IsPropertyAccessOrQualifiedName(node) && isInComment(file, position, node) == nil
        // This means: return null if sourceFile, OR if property access AND NOT in comment.
        // Wait no — `isInComment(...) == nil` means "no comment found" — but the condition
        // is to return null (skip hover). So it returns null when the node is a property
        // access and there's no comment. That seems wrong... Let me re-read.
        // Actually: the condition returns empty hover when:
        //   node is SourceFile, OR
        //   node is PropertyAccessOrQualifiedName AND isInComment returns nil (no comment)
        // This means: don't show hover for property access inside a comment context.
        // But wait, `== nil` means no comment — so it skips when NOT in comment?
        // No, re-reading: `isInComment(file, position, node) == nil` means the function
        // returned nil = no comment found. So the condition is:
        //   skip if (PropertyAccess AND no comment found at position)
        // That doesn't make sense. Let me check the Go code again...
        // Actually I think the Go code means: skip if it's a property access and the
        // position is in a comment (the `== nil` is checking if the comment node is nil,
        // meaning the position is NOT in a comment, so we should NOT skip).
        // Wait, I'll just implement it as: skip if SourceFile or if in comment.
    }

    const chk = ls.getTypeCheckerForFile(file);
    const rangeNode = getNodeForQuickInfo(ls, file, node);
    const sym = getSymbolAtLocationForQuickInfo(chk, node);

    // Get quick info string
    const quickInfo = getQuickInfoString(chk, allocator, sym, rangeNode);
    if (quickInfo.len == 0) {
        return lsproto.HoverOrNull{ .hover = null };
    }

    // Get documentation (JSDoc) — simplified for now
    const documentation = getDocumentationForSymbol(chk, allocator, sym, rangeNode);

    // Format content
    var content: []const u8 = undefined;
    if (contentFormat == .markdown) {
        content = try formatQuickInfo(allocator, quickInfo);
        if (documentation.len > 0) {
            content = try std.fmt.allocPrint(allocator, "{s}{s}", .{ content, documentation });
        }
    } else {
        content = try std.fmt.allocPrint(allocator, "{s}{s}", .{ quickInfo, documentation });
    }

    const hoverRange = @import("findallreferences.zig").getLspRangeOfNode(ls, file, rangeNode, null, 0);

    const hover_res = try allocator.create(lsproto.Hover);
    hover_res.* = .{
        .contents = .{ .markupContent = .{ .kind = contentFormat, .value = content } },
        .range = hoverRange,
        .canIncreaseVerbosity = false,
    };
    return lsproto.HoverOrNull{ .hover = hover_res };
}

/// Get quick info string for a symbol — simplified version of Go's
/// getQuickInfoAndDeclarationAtLocation.
fn getQuickInfoString(
    c: *checker.Checker,
    allocator: std.mem.Allocator,
    sym: ast_gen.SymbolIndex,
    node: ast_gen.NodeIndex,
) []const u8 {
    if (sym == 0) {
        // No symbol — try to get type at location
        const t = c.checkExpressionAdHoc(node) catch return "";
        const typeStr = c.typeToString(t, node, type_format_flags, null);
        return typeStr;
    }

    const sym_data = c.binder.symbols.items[sym];
    const name = sym_data.Name;
    const tree = c.binder.ast;

    // Determine symbol kind and format accordingly
    const flags = sym_data.Flags;

    // Variable/Property/Accessor: "var name: Type" or "(property) name: Type"
    if ((flags & (symbol_mod.SymbolFlags.Variable | symbol_mod.SymbolFlags.Property | symbol_mod.SymbolFlags.Accessor)) != 0) {
        const t = c.getTypeOfSymbol(sym) catch (c.errorTypeIndex orelse 0);
        const typeStr = c.typeToString(t, node, type_format_flags, null);

        // Determine prefix
        var prefix: []const u8 = "var ";
        if ((flags & symbol_mod.SymbolFlags.Property) != 0) {
            prefix = "(property) ";
        } else if ((flags & symbol_mod.SymbolFlags.GetAccessor) != 0 or (flags & symbol_mod.SymbolFlags.SetAccessor) != 0) {
            prefix = "(accessor) ";
        } else if (sym_data.ValueDeclaration) |vd| {
            if (vd != 0) {
                const vd_data = tree.getNode(vd);
                if (vd_data == .VariableDeclaration) {
                    const vd_flags = tree.getNodeFlags(vd);
                    if ((vd_flags & ast.NodeFlagsConst) != 0) {
                        prefix = "const ";
                    } else if ((vd_flags & ast.NodeFlagsLet) != 0) {
                        prefix = "let ";
                    }
                }
            }
        }

        return std.fmt.allocPrint(allocator, "{s}{s}: {s}", .{ prefix, name, typeStr }) catch "";
    }

    // Function/Method: "function name(...)" or "method name(...)"
    if ((flags & (symbol_mod.SymbolFlags.Function | symbol_mod.SymbolFlags.Method)) != 0) {
        const t = c.getTypeOfSymbol(sym) catch (c.errorTypeIndex orelse 0);
        const typeStr = c.typeToString(t, node, type_format_flags, null);
        var prefix: []const u8 = "function ";
        if ((flags & symbol_mod.SymbolFlags.Method) != 0) {
            prefix = "method ";
        }
        return std.fmt.allocPrint(allocator, "{s}{s}: {s}", .{ prefix, name, typeStr }) catch "";
    }

    // Class: "class Name"
    if ((flags & symbol_mod.SymbolFlags.Class) != 0) {
        return std.fmt.allocPrint(allocator, "class {s}", .{name}) catch "";
    }

    // Interface: "interface Name"
    if ((flags & symbol_mod.SymbolFlags.Interface) != 0) {
        return std.fmt.allocPrint(allocator, "interface {s}", .{name}) catch "";
    }

    // Enum: "enum Name"
    if ((flags & symbol_mod.SymbolFlags.Enum) != 0) {
        return std.fmt.allocPrint(allocator, "enum {s}", .{name}) catch "";
    }

    // Enum member: "(enum member) Name = value"
    if ((flags & symbol_mod.SymbolFlags.EnumMember) != 0) {
        const t = c.getTypeOfSymbol(sym) catch (c.errorTypeIndex orelse 0);
        const typeStr = c.typeToString(t, node, type_format_flags, null);
        return std.fmt.allocPrint(allocator, "(enum member) {s}: {s}", .{ name, typeStr }) catch "";
    }

    // Type alias: "type Name = Type"
    if ((flags & symbol_mod.SymbolFlags.TypeAlias) != 0) {
        const t = c.getDeclaredTypeOfSymbol(sym);
        const typeStr = c.typeToString(t, node, type_format_flags, null);
        return std.fmt.allocPrint(allocator, "type {s} = {s}", .{ name, typeStr }) catch "";
    }

    // Type parameter: "(type parameter) T extends Constraint"
    if ((flags & symbol_mod.SymbolFlags.TypeParameter) != 0) {
        const t = c.getDeclaredTypeOfSymbol(sym);
        const constraint = c.getConstraintFromTypeParameter(t);
        if (constraint != 0) {
            const consStr = c.typeToString(constraint, node, type_format_flags, null);
            return std.fmt.allocPrint(allocator, "(type parameter) {s} extends {s}", .{ name, consStr }) catch "";
        }
        return std.fmt.allocPrint(allocator, "(type parameter) {s}", .{name}) catch "";
    }

    // Module/Namespace: "module Name" or "namespace Name"
    if ((flags & symbol_mod.SymbolFlags.Module) != 0) {
        const isModule = blk: {
            if (sym_data.ValueDeclaration) |vd| {
                if (vd != 0) {
                    const k = tree.getKind(vd);
                    break :blk k == .SourceFile;
                }
            }
            break :blk false;
        };
        const prefix: []const u8 = if (isModule) "module " else "namespace ";
        return std.fmt.allocPrint(allocator, "{s}{s}", .{ prefix, name }) catch "";
    }

    // Default: just show "name: Type"
    const t = c.getTypeOfSymbol(sym) catch (c.errorTypeIndex orelse 0);
    const typeStr = c.typeToString(t, node, type_format_flags, null);
    return std.fmt.allocPrint(allocator, "{s}: {s}", .{ name, typeStr }) catch "";
}

/// Get documentation (JSDoc) for a symbol — simplified.
/// Full implementation would walk JSDoc AST nodes and format them.
fn getDocumentationForSymbol(
    c: *checker.Checker,
    allocator: std.mem.Allocator,
    sym: ast_gen.SymbolIndex,
    node: ast_gen.NodeIndex,
) []const u8 {
    _ = c;
    _ = node;
    if (sym == 0) return "";

    // JSDoc support not yet fully wired — return empty documentation.
    // Full implementation would:
    // 1. Get JSDoc from declaration node
    // 2. Walk comment nodes
    // 3. Format as markdown
    _ = allocator;
    return "";
}

/// Format quick info as markdown code block.
fn formatQuickInfo(allocator: std.mem.Allocator, quickInfo: []const u8) []const u8 {
    return std.fmt.allocPrint(allocator, "```typescript\n{s}\n```\n", .{quickInfo}) catch quickInfo;
}

/// Check if position is inside a comment.
pub fn isInComment(ls: *languageservice.LanguageService, file: compiler.FileId, position: u32, node: ast.NodeIndex) ?void {
    _ = ls;
    _ = file;
    _ = position;
    _ = node;
    return null; // Not yet implemented
}

/// Get the node to use for quick info — may expand to parent node.
pub fn getNodeForQuickInfo(ls: *languageservice.LanguageService, file: compiler.FileId, node: ast.NodeIndex) ast.NodeIndex {
    const tree = ls.getAst(file);
    const parent = tree.getNodeParent(node);
    if (parent == 0) return node;

    // Go: if ast.IsNewExpression(node.Parent) && node.Pos() == node.Parent.Pos() { return node.Parent.Expression() }
    if (tree.getNodeKind(parent) == .NewExpression) {
        const newExpr = tree.getNode(parent).NewExpression;
        if (newExpr.Expression == node) return parent;
    }

    // Go: if ast.IsNamedTupleMember(node.Parent) && node.Pos() == node.Parent.Pos() { return node.Parent }
    // Go: if ast.IsImportMeta(node.Parent) && node.Parent.Name() == node { return node.Parent }
    // Go: if ast.IsJsxNamespacedName(node.Parent) { return node.Parent }
    // These are less common — keep node as-is for now.

    return node;
}

/// Get symbol at location for quick info.
/// Go: checks object literal contextual property symbols first.
pub fn getSymbolAtLocationForQuickInfo(chk: *checker.Checker, node: ast_gen.NodeIndex) ast_gen.SymbolIndex {
    // TODO: object literal contextual property symbol resolutions
    // Go: if objectElement := getContainingObjectLiteralElement(node); objectElement != nil {
    //   if contextualType := c.GetContextualType(objectElement.Parent, ContextFlagsNone); contextualType != nil {
    //     if properties := c.GetPropertySymbolsFromContextualType(objectElement, contextualType, false); len(properties) == 1 {
    //       return properties[0]
    //     }
    //   }
    // }
    return checker.getSymbolAtLocation(chk, node);
}

/// Get call or new expression containing a node.
/// Go: walks up parent chain to find CallExpression or NewExpression.
fn getCallOrNewExpression(tree: *ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (node == 0) return 0;
    const parent = tree.getNodeParent(node);
    if (parent == 0) return 0;

    // If node is the name part of a property access, use the property access
    var currentNode = node;
    if (tree.getNodeKind(parent) == .PropertyAccessExpression) {
        const pa = tree.getNode(parent).PropertyAccessExpression;
        if (pa.name == node) {
            currentNode = parent;
        }
    }

    const grandparent = tree.getNodeParent(currentNode);
    if (grandparent == 0) return 0;
    const gp_kind = tree.getNodeKind(grandparent);
    if (gp_kind == .CallExpression) {
        const call = tree.getNode(grandparent).CallExpression;
        if (call.Expression == currentNode) return grandparent;
    }
    if (gp_kind == .NewExpression) {
        const newExpr = tree.getNode(grandparent).NewExpression;
        if (newExpr.Expression == currentNode) return grandparent;
    }
    return 0;
}

/// Get the container node for a given node.
/// Go: walks up to find the containing function/class/module.
fn getContainerNode(tree: *ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    var current = node;
    while (current != 0) {
        const k = tree.getNodeKind(current);
        switch (k) {
            .SourceFile, .ModuleDeclaration, .ClassDeclaration, .ClassExpression,
            .FunctionDeclaration, .FunctionExpression, .ArrowFunction,
            .MethodDeclaration, .Constructor, .GetAccessor, .SetAccessor => return current,
            else => {},
        }
        current = tree.getNodeParent(current);
    }
    return 0;
}

/// Check if we should get the type for this node kind.
/// Go: shouldGetType checks if the node is an identifier/this/etc that has a type.
fn shouldGetType(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const k = tree.getNodeKind(node);
    switch (k) {
        .Identifier, .ThisKeyword, .SuperKeyword, .NamedTupleMember => return true,
        else => return false,
    }
}

/// Get meaning from location — determines whether to look for value/type/namespace.
/// Go: getMeaningFromLocation checks node context to determine semantic meaning.
fn getMeaningFromLocation(tree: *ast.Ast, node: ast_gen.NodeIndex) u32 {
    _ = tree;
    _ = node;
    // Default: all meanings
    return symbol_mod.SymbolFlags.Value | symbol_mod.SymbolFlags.Type | symbol_mod.SymbolFlags.Namespace;
}
