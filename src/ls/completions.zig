const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const autoimport = @import("../project/autoimport.zig");
const string_completions = @import("string_completions.zig");
const keyword_completions = @import("keyword_completions.zig");

pub const ErrNeedsAutoImports = error.NeedsAutoImports;

pub const CompletionItem = struct {
    lspItem: *lsproto.CompletionItem,
    symbol: ?*ast.Symbol,
};

pub const CompletionList = struct {
    isIncomplete: bool,
    itemDefaults: ?*lsproto.CompletionItemDefaults,
    applyKind: ?*lsproto.CompletionItemApplyKinds,
    items: []*CompletionItem,

    pub fn toLSP(self: *CompletionList, allocator: std.mem.Allocator) !lsproto.CompletionList {
        var items = std.ArrayList(lsproto.CompletionItem).init(allocator);
        errdefer items.deinit();
        for (self.items) |item| {
            try items.append(item.lspItem.*);
        }
        return lsproto.CompletionList{
            .isIncomplete = self.isIncomplete,
            .itemDefaults = if (self.itemDefaults) |d| d.* else null,
            .applyKind = if (self.applyKind) |k| k.* else null,
            .items = try items.toOwnedSlice(),
        };
    }
};

pub fn provideCompletion(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    documentURI: lsproto.DocumentUri,
    LSPPosition: lsproto.Position,
    context: ?*lsproto.CompletionContext,
) !lsproto.CompletionResponse {
    const programAndFile = ls.getProgramAndFile(documentURI);
    const file = programAndFile.file;

    var triggerCharacter: ?[]const u8 = null;
    if (context) |ctx| {
        triggerCharacter = ctx.triggerCharacter;
    }

    const position = ls.converters.lineAndCharacterToPosition(file, LSPPosition);
    
    var completionListInternal = try getCompletionsAtPosition(ls, allocator, file, position, triggerCharacter, false);
    
    const completionList = try ensureItemData(allocator, programAndFile.program.getAstNode(file).source_file.fileName, position, try completionListInternal.toLSP(allocator));
    return lsproto.CompletionResponse{ .CompletionItemsOrListOrNull = .{ .list = completionList } };
}

pub fn getCompletionsAtPosition(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    file: ast.NodeIndex,
    position: u32,
    triggerCharacter: ?[]const u8,
    includeSymbols: bool,
) !*CompletionList {
    _ = triggerCharacter; _ = includeSymbols;
    const programAndFile = ls.tryGetProgramAndFile(ls.program.getAstNode(file).source_file.fileName);
    const program = programAndFile.program;
    
    const node = ast_utils.getTouchingPropertyName(&program.ast, file, position);
    const nodeKind = program.ast.getNodeKind(node);

    if (nodeKind == .StringLiteral or nodeKind == .NoSubstitutionTemplateLiteral) {
        return string_completions.StringCompletions.getStringLiteralCompletions(ls, allocator, file, position, null);
    }

    return keyword_completions.KeywordCompletions.getKeywordCompletions(ls, allocator, file, position);
}

fn ensureItemData(allocator: std.mem.Allocator, fileName: []const u8, pos: u32, list: lsproto.CompletionList) !*lsproto.CompletionList {
    const pList = try allocator.create(lsproto.CompletionList);
    pList.* = list;
    for (pList.items) |*item| {
        if (item.data == null) {
            item.data = lsproto.CompletionItemData{
                .fileName = fileName,
                .position = pos,
                .name = item.label,
            };
        }
    }
    return pList;
}
