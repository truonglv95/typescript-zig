const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");

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

    if (tree.getNodeKind(node) == .SourceFile or (ast_utils.isPropertyAccessOrQualifiedName(tree, node) and isInComment(ls, file, position, node) == null)) {
        return lsproto.HoverOrNull{ .hover = null };
    }

    var chk = ls.getTypeCheckerForFile(file);
    const rangeNode = getNodeForQuickInfo(ls, file, node);
    const symbol = getSymbolAtLocationForQuickInfo(chk, node);

    var maxTruncLen = ls.userPreferences().maximumHoverLength;
    if (maxTruncLen <= 0) {
        maxTruncLen = 500;
    }

    const hoverRange = @import("findallreferences.zig").getLspRangeOfNode(ls, file, rangeNode, null, 0);

    if (symbol != 0) {
        const t = chk.getTypeOfSymbol(symbol) catch (chk.errorTypeIndex orelse 0);
        const typeStr = chk.typeToString(t, node, 0, null);
        const name = ast_utils.getTextOfNode(tree, node);
        const quickInfoStr = try std.fmt.allocPrint(allocator, "```typescript\n{s}: {s}\n```", .{ name, typeStr });
        const hover_res = try allocator.create(lsproto.Hover);
        hover_res.* = .{
            .contents = .{ .markupContent = .{ .kind = contentFormat, .value = quickInfoStr } },
            .range = hoverRange,
            .canIncreaseVerbosity = false,
        };
        return lsproto.HoverOrNull{ .hover = hover_res };
    } else {
        const t = chk.checkExpressionAdHoc(node) catch (chk.errorTypeIndex orelse 0);
        const typeStr = chk.typeToString(t, node, 0, null);
        const quickInfoStr = try std.fmt.allocPrint(allocator, "```typescript\n{s}\n```", .{typeStr});
        const hover_res = try allocator.create(lsproto.Hover);
        hover_res.* = .{
            .contents = .{ .markupContent = .{ .kind = contentFormat, .value = quickInfoStr } },
            .range = hoverRange,
            .canIncreaseVerbosity = false,
        };
        return lsproto.HoverOrNull{ .hover = hover_res };
    }
}

pub fn isInComment(ls: *languageservice.LanguageService, file: compiler.FileId, position: u32, node: ast.NodeIndex) ?void {
    _ = ls;
    _ = file;
    _ = position;
    _ = node;
    return null; // stub
}

pub fn getNodeForQuickInfo(ls: *languageservice.LanguageService, file: compiler.FileId, node: ast.NodeIndex) ast.NodeIndex {
    const tree = ls.getAst(file);
    const parent = tree.getNodeParent(node);
    if (parent == 0) return node;

    if (tree.getNodeKind(parent) == .NewExpression) {
        const newExpr = tree.getNode(parent).NewExpression;
        if (newExpr.Expression == node) return parent;
    }
    // TODO: support NamedTupleMember, ImportMeta, JsxNamespacedName expansions
    return node;
}

pub fn getSymbolAtLocationForQuickInfo(chk: *checker.Checker, node: ast.NodeIndex) ast_gen.SymbolIndex {
    // TODO: object literal contextual property symbol resolutions
    return checker.getSymbolAtLocation(chk, node);
}
