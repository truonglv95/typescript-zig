const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const types = @import("../checker/types.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const symbol_mod = @import("../ast/symbol.zig");
const displaypartswriter = @import("displaypartswriter.zig");

pub const SymbolFormatFlags = struct {
    pub const WriteTypeParametersOrArguments = types.SymbolFormatFlags.WriteTypeParametersOrArguments;
    pub const UseOnlyExternalAliasing = types.SymbolFormatFlags.UseOnlyExternalAliasing;
    pub const AllowAnyNodeKind = types.SymbolFormatFlags.AllowAnyNodeKind;
    pub const UseAliasDefinedOutsideCurrentScope = types.SymbolFormatFlags.UseAliasDefinedOutsideCurrentScope;
};

pub const TypeFormatFlags = struct {
    pub const UseAliasDefinedOutsideCurrentScope = types.TypeFormatFlags.UseAliasDefinedOutsideCurrentScope;
    pub const UseInstantiationExpressions = types.TypeFormatFlags.UseInstantiationExpressions;
    // Missing flags based on go implementation:
    pub const WriteCallStyleSignature = 1 << 4; // TODO: properly define
    pub const WriteArrowStyleSignature = 1 << 5; // TODO: properly define
    pub const WriteTypeArgumentsOfSignature = 1 << 6; // TODO: properly define
    pub const MultilineObjectLiterals = 1 << 7; // TODO: properly define
    pub const NodeBuilderFlagsMask = 0; // TODO: properly define
};

const symbol_format_flags: u32 =
    SymbolFormatFlags.WriteTypeParametersOrArguments |
    SymbolFormatFlags.UseOnlyExternalAliasing |
    SymbolFormatFlags.AllowAnyNodeKind |
    SymbolFormatFlags.UseAliasDefinedOutsideCurrentScope;

const type_format_flags: u32 =
    TypeFormatFlags.UseAliasDefinedOutsideCurrentScope |
    TypeFormatFlags.UseInstantiationExpressions;

pub const SemanticMeaning = struct {
    pub const None: u32 = 0;
    pub const Value: u32 = 1 << 0;
    pub const Type: u32 = 1 << 1;
    pub const Namespace: u32 = 1 << 2;
    pub const All: u32 = Value | Type | Namespace;
};

pub const SymbolDisplayInfo = struct {
    displayParts: *displaypartswriter.DisplayPartsWriter,
    declaration: ast.NodeIndex,
};

/// Port of LanguageService.ProvideHover.
/// Returns hover information for the symbol at the given position.
pub fn getMeaningFromLocation(tree: *ast.Ast, node: ast.NodeIndex) u32 {
    const parent = tree.getNodeParent(node);
    if (tree.getNodeKind(node) == .SourceFile) return SemanticMeaning.Value;
    
    if (parent != 0) {
        const pk = tree.getNodeKind(parent);
        if (pk == .ExportAssignment or pk == .ExportSpecifier or pk == .ExternalModuleReference or
            pk == .ImportSpecifier or pk == .ImportClause) {
            return SemanticMeaning.All;
        }
        if (pk == .ImportEqualsDeclaration) {
            const importEquals = tree.getNode(parent).ImportEqualsDeclaration;
            if (importEquals.name == node) {
                return SemanticMeaning.All;
            }
        }
    }
    
    const isTypeRef = blk: {
        var curr = node;
        const p = tree.getNodeParent(curr);
        if (p != 0) {
            const pk = tree.getNodeKind(p);
            if (pk == .PropertyAccessExpression) {
                const pae = tree.getNode(p).PropertyAccessExpression;
                if (pae.name == curr) curr = p;
            } else if (pk == .QualifiedName) {
                const qn = tree.getNode(p).QualifiedName;
                if (qn.Right == curr) curr = p;
            }
        }
        const currP = tree.getNodeParent(curr);
        break :blk (currP != 0 and tree.getNodeKind(currP) == .TypeReference);
    };
    if (isTypeRef) return SemanticMeaning.Type;
    
    return SemanticMeaning.Value | SemanticMeaning.Type | SemanticMeaning.Namespace;
}

pub const VerbosityContext = struct {
    level: u32,
    maxTruncationLength: u32,
    canIncreaseVerbosity: bool,
    truncated: bool,
};

pub fn provideHover(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.HoverParams,
) !lsproto.HoverOrNull {
    const caps = lsproto.getClientCapabilities();
    const contentFormat = lsproto.preferredMarkupKind(caps.textDocument.hover.contentFormat);

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
        // ...
    }

    const chk = ls.getTypeCheckerForFile(file);
    const rangeNode = getNodeForQuickInfo(ls, file, node);
    const symbol = getSymbolAtLocationForQuickInfo(chk, rangeNode);

    var vc = VerbosityContext{
        .level = 0, // TODO: map from params
        .maxTruncationLength = 160,
        .canIncreaseVerbosity = false,
        .truncated = false,
    };

    const hoverRange = @import("findallreferences.zig").getLspRangeOfNode(ls, file, rangeNode, null, 0);

    const info = getQuickInfoAndDocumentationForSymbol(ls, chk, file, symbol, rangeNode, contentFormat, &vc);
    if (info.quickInfo.len == 0) {
        return lsproto.HoverOrNull{ .hover = null };
    }

    const content = try std.fmt.allocPrint(allocator, "{s}{s}", .{ info.quickInfo, info.documentation });

    const hover_res = try allocator.create(lsproto.Hover);
    hover_res.* = .{
        .contents = .{ .markupContent = .{ .kind = contentFormat, .value = content } },
        .range = hoverRange,
        .canIncreaseVerbosity = vc.canIncreaseVerbosity and !vc.truncated,
    };

    return lsproto.HoverOrNull{ .hover = hover_res };
}

pub const QuickInfoDoc = struct {
    quickInfo: []const u8,
    documentation: []const u8,
};

pub fn getQuickInfoAndDocumentationForSymbol(
    ls: *languageservice.LanguageService,
    chk: *checker.Checker,
    file: compiler.FileId,
    symbol: ast_gen.SymbolIndex,
    node: ast.NodeIndex,
    contentFormat: u32,
    vc: *VerbosityContext,
) QuickInfoDoc {
    const tree = ls.getAst(file);
    const meaning = getMeaningFromLocation(tree, node);
    const info = getQuickInfoAndDeclarationAtLocation(ls, chk, file, symbol, node, vc, false, meaning);
    const quickInfo = info.displayParts.string();

    if (quickInfo.len == 0) {
        return .{ .quickInfo = "", .documentation = "" };
    }

    const doc1 = documentationFromSignature(ls, chk, file, symbol, getCallOrNewExpression(tree, node), node, contentFormat, false);
    if (doc1.len != 0) {
        return .{ .quickInfo = quickInfo, .documentation = doc1 };
    }

    const doc2 = getDocumentationFromDeclaration(ls, chk, file, symbol, info.declaration, node, contentFormat, false);
    if (doc2.len != 0) {
        return .{ .quickInfo = quickInfo, .documentation = doc2 };
    }

    const doc3 = documentationFromAlias(ls, chk, file, symbol, node, contentFormat);
    return .{ .quickInfo = quickInfo, .documentation = doc3 };
}

pub fn documentationFromSignature(
    ls: *languageservice.LanguageService,
    chk: *checker.Checker,
    file: compiler.FileId,
    symbol: ast_gen.SymbolIndex,
    node: ast.NodeIndex,
    location: ast.NodeIndex,
    contentFormat: u32,
    commentOnly: bool,
) []const u8 {
    if (node == 0) return "";
    const signature = chk.getResolvedSignature(node, null, .Normal);
    if (signature == 0) return "";
    const declaration = chk.signatures.items[signature].declaration;
    if (declaration == 0) return "";
    
    const tree = ls.getAst(file);
    const kind = tree.getNodeKind(declaration);
    if (kind == .CallSignature or kind == .ConstructSignature) {
        return getDocumentationFromDeclaration(ls, chk, file, symbol, declaration, location, contentFormat, commentOnly);
    }
    return "";
}

pub fn documentationFromAlias(
    ls: *languageservice.LanguageService,
    chk: *checker.Checker,
    file: compiler.FileId,
    symbol: ast_gen.SymbolIndex,
    node: ast.NodeIndex,
    contentFormat: u32,
) []const u8 {
    if (symbol == 0 or (chk.binder.symbols.items[symbol].Flags & symbol_mod.SymbolFlags.Alias) == 0) return "";
    
    const aliasedSymbol = chk.getAliasedSymbol(symbol);
    if (aliasedSymbol == 0 or aliasedSymbol == chk.unknownSymbol) return "";
    
    var candidates = std.ArrayListUnmanaged(ast_gen.SymbolIndex).empty;
    defer candidates.deinit(chk.allocator);
    candidates.append(chk.allocator, aliasedSymbol) catch {};
    
    if (chk.binder.symbols.items[aliasedSymbol].ExportSymbol) |es| {
        candidates.append(chk.allocator, es) catch {};
    }
    
    for (candidates.items) |candidate| {
        const sym = chk.binder.symbols.items[candidate];
        const aliasedDeclaration = sym.ValueDeclaration orelse (if (sym.Declarations.items.len > 0) sym.Declarations.items[0] else 0);
        if (aliasedDeclaration == 0) continue;
        const doc = getDocumentationFromDeclaration(ls, chk, file, candidate, aliasedDeclaration, node, contentFormat, false);
        if (doc.len > 0) return doc;
    }
    return "";
}

pub fn getDocumentationFromDeclaration(
    ls: *languageservice.LanguageService,
    chk: *checker.Checker,
    file: compiler.FileId,
    symbol: ast_gen.SymbolIndex,
    declaration: ast.NodeIndex,
    location: ast.NodeIndex,
    contentFormat: u32,
    commentOnly: bool,
) []const u8 {
    _ = symbol;
    _ = location;
    _ = contentFormat;
    _ = commentOnly;
    _ = chk;
    if (declaration == 0) return "";
    
    const tree = ls.getAst(file);
    const jsDocs = @import("../ast/ast_utils.zig").getJSDoc(tree, declaration);
    if (jsDocs.len > 0) {
        const docNode = jsDocs[0];
        const text = @import("../ast/ast_utils.zig").getTextOfNode(tree, docNode);
        return text; // Simplification: return raw JSDoc text.
    }
    return "";
}

pub fn getQuickInfoAndDeclarationAtLocation(
    ls: *languageservice.LanguageService,
    chk: *checker.Checker,
    file: compiler.FileId,
    symbol: ast_gen.SymbolIndex,
    node: ast.NodeIndex,
    vc: *VerbosityContext,
    vsCapability: bool,
    meaning: u32,
) SymbolDisplayInfo {
    _ = vsCapability;
    _ = meaning;
    _ = vc;
    const tree = ls.getAst(file);
    
    const dpw = chk.allocator.create(displaypartswriter.DisplayPartsWriter) catch unreachable;
    dpw.* = displaypartswriter.DisplayPartsWriter.init(chk.allocator, false);

    var declaration: ast.NodeIndex = 0;
    if (symbol != 0) {
        const t = chk.getTypeOfSymbol(symbol) catch (chk.errorTypeIndex orelse 0);
        const typeStr = chk.typeToString(t, node, 0, null);
        const name = ast_utils.getTextOfNode(tree, node);
        dpw.write("```typescript\n");
        dpw.write(name);
        dpw.write(": ");
        dpw.write(typeStr);
        dpw.write("\n```");
        
        const sym = chk.binder.symbols.items[symbol];
        declaration = sym.ValueDeclaration orelse (if (sym.Declarations.items.len > 0) sym.Declarations.items[0] else 0);
    } else {
        const t = chk.checkExpressionAdHoc(node) catch (chk.errorTypeIndex orelse 0);
        const typeStr = chk.typeToString(t, node, 0, null);
        dpw.write("```typescript\n");
        dpw.write(typeStr);
        dpw.write("\n```");
    }

    return .{
        .displayParts = dpw,
        .declaration = declaration,
    };
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

// Use the getCallOrNewExpression from later in the file.

pub fn isInComment(ls_srv: *languageservice.LanguageService, file: compiler.FileId, position: u32, node: ast.NodeIndex) ?void {
    const tree = ls_srv.getAst(file);
    const sourceFile = ls_srv.getSourceFileNode(file);
    const precedingToken = @import("../astnav/tokens.zig").findPrecedingToken(sourceFile, tree, position);
    const commentRange = @import("format.zig").getRangeOfEnclosingComment(ls_srv, file, position, precedingToken, node);
    if (commentRange) |_| return {};
    return null;
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
pub fn getCallOrNewExpression(tree: *ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
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

