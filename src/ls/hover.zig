const std = @import("std");
const ast = @import("../ast/ast.zig");
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
    _ = allocator;
    const caps = lsproto.getClientCapabilities();
    const contentFormat = lsproto.preferredMarkupKind(caps.textDocument.hover.contentFormat);

    const verbosityLevel: u32 = if (params.verbosityLevel) |level| level else 0;

    const programAndFile = ls.getProgramAndFile(params.textDocument.uri);
    const program = programAndFile.program;
    const file = programAndFile.file;

    const position = ls.converters.lineAndCharacterToPosition(file, params.position);
    const node = ast_utils.getTouchingPropertyName(&program.ast, file, position);

    if (program.ast.getNodeKind(node) == .SourceFile or (ast_utils.isPropertyAccessOrQualifiedName(&program.ast, node) and isInComment(ls, file, position, node) == null)) {
        return lsproto.HoverOrNull{ .hover = null };
    }

    const chk = program.getTypeCheckerForFile(file);
    const rangeNode = getNodeForQuickInfo(ls, node);
    const symbol = getSymbolAtLocationForQuickInfo(chk, node);

    var maxTruncLen = ls.userPreferences().maximumHoverLength;
    if (maxTruncLen <= 0) {
        maxTruncLen = 500;
    }

    // stub
    _ = contentFormat; _ = rangeNode; _ = symbol; _ = verbosityLevel;

    return lsproto.HoverOrNull{ .hover = null };
}

pub fn isInComment(ls: *languageservice.LanguageService, file: ast.NodeIndex, position: u32, node: ast.NodeIndex) ?void {
    _ = ls; _ = file; _ = position; _ = node;
    return null; // stub
}

pub fn getNodeForQuickInfo(ls: *languageservice.LanguageService, node: ast.NodeIndex) ast.NodeIndex {
    _ = ls;
    return node; // stub
}

pub fn getSymbolAtLocationForQuickInfo(chk: *checker.Checker, node: ast.NodeIndex) ?*ast.Symbol {
    _ = chk; _ = node;
    return null; // stub
}
