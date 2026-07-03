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

    const script = ls.getScript(file);
    const position = ls.converters.lineAndCharacterToPosition(script, LSPPosition);

    var completionListInternal = try getCompletionsAtPosition(ls, allocator, file, position, triggerCharacter, false);

    const completionList = try ensureItemData(allocator, script.file_name, position, try completionListInternal.toLSP(allocator));
    return lsproto.CompletionResponse{ .CompletionItemsOrListOrNull = .{ .list = completionList } };
}

pub fn getCompletionsAtPosition(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    file: compiler.FileId,
    position: u32,
    triggerCharacter: ?[]const u8,
    includeSymbols: bool,
) !*CompletionList {
    _ = triggerCharacter;
    _ = includeSymbols;

    const tree = ls.getAst(file);
    const node = ast_utils.getTouchingPropertyName(tree.getNode(ls.getSourceFileNode(file)).SourceFile, tree, position);
    const nodeKind = tree.getNodeKind(node);

    var isMemberAccess = false;
    var propertyAccessExpr: ast.NodeIndex = 0;

    const parent = tree.getNodeParent(node);

    if (nodeKind == .Identifier) {
        if (tree.getNodeKind(parent) == .PropertyAccessExpression) {
            const pae = tree.getNode(parent).PropertyAccessExpression;
            if (pae.Name == node) {
                isMemberAccess = true;
                propertyAccessExpr = parent;
            }
        }
    } else if (nodeKind == .PropertyAccessExpression) {
        // sometimes getTouchingPropertyName stops at the expression itself if dot hasn't parsed right
        isMemberAccess = true;
        propertyAccessExpr = node;
    }

    if (isMemberAccess) {
        const pae = tree.getNode(propertyAccessExpr).PropertyAccessExpression;
        var chk = ls.getTypeCheckerForFile(file);

        const exprType = chk.checkExpression(pae.Expression) catch 0;

        if (exprType != 0) {
            var completions = std.ArrayList(*CompletionItem).init(allocator);

            const props = chk.getPropertiesOfType(exprType);
            for (props) |propSymIdx| {
                const propSym = chk.binder.symbols.items[propSymIdx];
                if (propSym.escapedName >= chk.binder.identifiers.items.len) continue;
                const name = chk.binder.identifiers.items[propSym.escapedName];

                const item = try allocator.create(lsproto.CompletionItem);
                item.* = lsproto.CompletionItem{
                    .label = name,
                    .kind = .Field,
                };

                const cItem = try allocator.create(CompletionItem);
                cItem.* = .{ .lspItem = item, .symbol = null };
                try completions.append(cItem);
            }

            const cList = try allocator.create(CompletionList);
            cList.* = .{
                .isIncomplete = false,
                .itemDefaults = null,
                .applyKind = null,
                .items = try completions.toOwnedSlice(),
            };
            return cList;
        }
    } else {
        // Global completion (locals + globals in scope)
        if (nodeKind == .Identifier or nodeKind == .Unknown) {
            const services = @import("../checker/services.zig");
            const meaning = @import("../binder/binder.zig").SymbolFlags.Value | @import("../binder/binder.zig").SymbolFlags.Type | @import("../binder/binder.zig").SymbolFlags.Namespace;

            const chk = ls.getTypeCheckerForFile(file);
            const symbolsInScope = services.getSymbolsInScope(chk, node, meaning);

            var completions = std.ArrayList(*CompletionItem).init(allocator);

            for (symbolsInScope) |symIdx| {
                const sym = chk.binder.symbols.items[symIdx];
                if (sym.escapedName >= chk.binder.identifiers.items.len) continue;
                const name = chk.binder.identifiers.items[sym.escapedName];

                const item = try allocator.create(lsproto.CompletionItem);
                item.* = lsproto.CompletionItem{
                    .label = name,
                    .kind = .Variable,
                };

                const cItem = try allocator.create(CompletionItem);
                cItem.* = .{ .lspItem = item, .symbol = null };
                try completions.append(cItem);
            }

            if (completions.items.len > 0) {
                const cList = try allocator.create(CompletionList);
                cList.* = .{
                    .isIncomplete = false,
                    .itemDefaults = null,
                    .applyKind = null,
                    .items = try completions.toOwnedSlice(),
                };
                return cList;
            }
        }
    }

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
