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
    symbol: u32,
};

pub const CompletionList = struct {
    isIncomplete: bool,
    itemDefaults: ?*lsproto.CompletionItemDefaults,
    applyKind: ?*lsproto.CompletionItemApplyKinds,
    items: []*CompletionItem,

    pub fn toLSP(self: *CompletionList, allocator: std.mem.Allocator) !lsproto.CompletionList {
        var items = std.ArrayListUnmanaged(lsproto.CompletionItem).empty;
        errdefer items.deinit(allocator);
        for (self.items) |item| {
            try items.append(allocator, item.lspItem.*);
        }
        return lsproto.CompletionList{
            .isIncomplete = self.isIncomplete,
            .itemDefaults = if (self.itemDefaults) |d| d.* else null,
            .applyKind = if (self.applyKind) |k| k.* else null,
            .items = try items.toOwnedSlice(allocator),
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

pub fn resolveCompletionItem(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    item: *lsproto.CompletionItem,
    data: *lsproto.CompletionItemData,
) !lsproto.CompletionResolveResponse {
    const programAndFile = ls.getProgramAndFile(data.fileName);
    const file = programAndFile.file;

    const chk = ls.getTypeCheckerForFile(file);

    const cList = try getCompletionsAtPosition(ls, allocator, file, data.position, null, false);

    var foundSym: checker.SymbolIndex = 0;
    for (cList.items) |cItem| {
        if (std.mem.eql(u8, cItem.lspItem.label, item.label)) {
            foundSym = cItem.symbol;
            break;
        }
    }

    if (foundSym != 0) {
        const typeIdx = chk.getTypeOfSymbol(foundSym) catch 0;
        if (typeIdx != 0) {
            const typeStr = checker.printer.typeToString(chk, typeIdx);
            item.detail = typeStr;
        }
    }

    return lsproto.CompletionResolveResponse{ .CompletionItem = item.* };
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
    const node = ast_utils.getTouchingPropertyName(ls.getSourceFileNode(file), tree, position);
    const nodeKind = tree.getNodeKind(node);

    var isMemberAccess = false;
    var propertyAccessExpr: ast.NodeIndex = 0;

    const parent = tree.getNodeParent(node);

    if (nodeKind == .Identifier) {
        if (tree.getNodeKind(parent) == .PropertyAccessExpression) {
            const pae = tree.getNode(parent).PropertyAccessExpression;
            if (pae.name == node) {
                isMemberAccess = true;
                propertyAccessExpr = parent;
            }
        }
    } else if (nodeKind == .PropertyAccessExpression) {
        // sometimes getTouchingPropertyName stops at the expression itself if dot hasn't parsed right
        isMemberAccess = true;
        propertyAccessExpr = node;
    }

    var isObjectLiteralCompletion = false;
    var objLitExpr: ast.NodeIndex = 0;
    if (tryGetObjectLikeCompletionContainer(tree, node)) |lit| {
        isObjectLiteralCompletion = true;
        objLitExpr = lit;
    }

    var isJsxCompletion = false;
    var jsxExpr: ast.NodeIndex = 0;
    if (tryGetContainingJsxElement(tree, node)) |jsx| {
        isJsxCompletion = true;
        jsxExpr = jsx;
    }

    if (isMemberAccess) {
        const pae = tree.getNode(propertyAccessExpr).PropertyAccessExpression;
        var chk = ls.getTypeCheckerForFile(file);

        const exprType = chk.checkExpressionAdHoc(pae.Expression) catch 0;

        if (exprType != 0) {
            var completions = std.ArrayList(*CompletionItem).empty;

            const props = chk.getPropertiesOfType(exprType);
            for (props) |propSymIdx| {
                const propSym = chk.binder.symbols.items[propSymIdx];
                const name = propSym.Name;

                const item = try allocator.create(lsproto.CompletionItem);
                item.* = lsproto.CompletionItem{
                    .label = name,
                    .kind = symbolToCompletionItemKind(propSym.Flags),
                };

                const cItem = try allocator.create(CompletionItem);
                cItem.* = .{ .lspItem = item, .symbol = propSymIdx };
                try completions.append(allocator, cItem);
            }

            const cList = try allocator.create(CompletionList);
            cList.* = .{
                .isIncomplete = false,
                .itemDefaults = null,
                .applyKind = null,
                .items = try completions.toOwnedSlice(allocator),
            };
            return cList;
        }
    } else if (isObjectLiteralCompletion) {
        var chk = ls.getTypeCheckerForFile(file);
        const services = @import("../checker/services.zig");
        const ctxType = services.getContextualType(chk, objLitExpr, 0);

        if (ctxType != 0) {
            var comps = std.ArrayList(*CompletionItem).empty;

            const props = chk.getPropertiesOfType(ctxType);
            for (props) |propSymIdx| {
                const propSym = chk.binder.symbols.items[propSymIdx];
                const name = propSym.Name;

                const item = try allocator.create(lsproto.CompletionItem);
                item.* = lsproto.CompletionItem{
                    .label = name,
                    .kind = symbolToCompletionItemKind(propSym.Flags),
                };

                const cItem = try allocator.create(CompletionItem);
                cItem.* = .{ .lspItem = item, .symbol = propSymIdx };
                try comps.append(allocator, cItem);
            }

            if (comps.items.len > 0) {
                const cList = try allocator.create(CompletionList);
                cList.* = .{
                    .isIncomplete = false,
                    .itemDefaults = null,
                    .applyKind = null,
                    .items = try comps.toOwnedSlice(allocator),
                };
                return cList;
            }
        }
    } else if (isJsxCompletion) {
        var chk = ls.getTypeCheckerForFile(file);
        const jsxPkg = @import("../checker/jsx.zig");

        var attrsNode: ast.NodeIndex = 0;
        const jsxKind = tree.getNodeKind(jsxExpr);
        if (jsxKind == .JsxOpeningElement) {
            attrsNode = tree.getNode(jsxExpr).JsxOpeningElement.Attributes;
        } else if (jsxKind == .JsxSelfClosingElement) {
            attrsNode = tree.getNode(jsxExpr).JsxSelfClosingElement.Attributes;
        }

        if (attrsNode != 0) {
            const ctxType = jsxPkg.getContextualTypeForJsxAttribute(chk, attrsNode, 0);
            if (ctxType != 0) {
                var comps = std.ArrayList(*CompletionItem).empty;

                const props = chk.getPropertiesOfType(ctxType);
                for (props) |propSymIdx| {
                    const propSym = chk.binder.symbols.items[propSymIdx];
                    const name = propSym.Name;

                    const item = try allocator.create(lsproto.CompletionItem);
                    item.* = lsproto.CompletionItem{
                        .label = name,
                        .kind = symbolToCompletionItemKind(propSym.Flags),
                    };

                    const cItem = try allocator.create(CompletionItem);
                    cItem.* = .{ .lspItem = item, .symbol = propSymIdx };
                    try comps.append(allocator, cItem);
                }

                if (comps.items.len > 0) {
                    const cList = try allocator.create(CompletionList);
                    cList.* = .{
                        .isIncomplete = false,
                        .itemDefaults = null,
                        .applyKind = null,
                        .items = try comps.toOwnedSlice(allocator),
                    };
                    return cList;
                }
            }
        }
    } else {
        // Global completion (locals + globals in scope)
        if (nodeKind == .Identifier or nodeKind == .Unknown) {
            const services = @import("../checker/services.zig");
            const meaning = @import("../ast/symbol.zig").SymbolFlags.Value | @import("../ast/symbol.zig").SymbolFlags.Type | @import("../ast/symbol.zig").SymbolFlags.Namespace;

            const chk = ls.getTypeCheckerForFile(file);
            const symbolsInScope = services.getSymbolsInScope(chk, node, meaning);

            var completions = std.ArrayList(*CompletionItem).empty;

            for (symbolsInScope) |symIdx| {
                const sym = chk.binder.symbols.items[symIdx];
                const name = sym.Name;

                const item = try allocator.create(lsproto.CompletionItem);
                item.* = lsproto.CompletionItem{
                    .label = name,
                    .kind = symbolToCompletionItemKind(sym.Flags),
                };

                const cItem = try allocator.create(CompletionItem);
                cItem.* = .{ .lspItem = item, .symbol = symIdx };
                try completions.append(allocator, cItem);
            }

            const kwList = try keyword_completions.KeywordCompletions.getKeywordCompletions(ls, allocator, file, position);
            for (kwList.items) |kwItem| {
                try completions.append(allocator, kwItem);
            }

            if (completions.items.len > 0) {
                const cList = try allocator.create(CompletionList);
                cList.* = .{
                    .isIncomplete = false,
                    .itemDefaults = null,
                    .applyKind = null,
                    .items = try completions.toOwnedSlice(allocator),
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

fn tryGetObjectLikeCompletionContainer(tree: *ast.Ast, node: ast.NodeIndex) ?ast.NodeIndex {
    if (node == 0) return null;
    const nodeKind = tree.getNodeKind(node);
    const parent = tree.getNodeParent(node);
    if (parent == 0) return null;

    if (nodeKind == .OpenBraceToken or nodeKind == .CommaToken) {
        const pKind = tree.getNodeKind(parent);
        if (pKind == .ObjectLiteralExpression or pKind == .ObjectBindingPattern) {
            return parent;
        }
    }

    if (nodeKind == .Identifier) {
        const pKind = tree.getNodeKind(parent);
        if (pKind == .PropertyAssignment or pKind == .ShorthandPropertyAssignment) {
            const pp = tree.getNodeParent(parent);
            if (pp != 0) {
                const ppKind = tree.getNodeKind(pp);
                if (ppKind == .ObjectLiteralExpression) {
                    return pp;
                }
            }
        }
    }

    if (nodeKind == .ObjectLiteralExpression or nodeKind == .ObjectBindingPattern) {
        return node;
    }

    return null;
}

fn tryGetContainingJsxElement(tree: *ast.Ast, node: ast.NodeIndex) ?ast.NodeIndex {
    if (node == 0) return null;
    const nodeKind = tree.getNodeKind(node);
    const parent = tree.getNodeParent(node);
    if (parent == 0) return null;

    if (nodeKind == .Identifier or nodeKind == .GreaterThanToken or nodeKind == .SlashToken or nodeKind == .LessThanSlashToken or nodeKind == .JsxAttributes or nodeKind == .JsxAttribute or nodeKind == .JsxSpreadAttribute) {
        const pKind = tree.getNodeKind(parent);
        if (pKind == .JsxSelfClosingElement or pKind == .JsxOpeningElement) {
            return parent;
        } else if (pKind == .JsxAttribute) {
            const pp = tree.getNodeParent(parent);
            if (pp != 0) {
                const ppp = tree.getNodeParent(pp);
                if (ppp != 0) return ppp;
            }
        }
    }

    if (nodeKind == .StringLiteral) {
        const pKind = tree.getNodeKind(parent);
        if (pKind == .JsxAttribute or pKind == .JsxSpreadAttribute) {
            const pp = tree.getNodeParent(parent);
            if (pp != 0) {
                const ppp = tree.getNodeParent(pp);
                if (ppp != 0) return ppp;
            }
        }
    }

    return null;
}

fn symbolToCompletionItemKind(flags: u32) lsproto.CompletionItemKind {
    const SymbolFlags = @import("../ast/symbol.zig").SymbolFlags;
    if (flags & SymbolFlags.Function != 0) return .Function;
    if (flags & SymbolFlags.Class != 0) return .Class;
    if (flags & SymbolFlags.Interface != 0) return .Interface;
    if (flags & SymbolFlags.TypeAlias != 0) return .Struct;
    if (flags & SymbolFlags.RegularEnum != 0 or flags & SymbolFlags.ConstEnum != 0) return .Enum;
    if (flags & SymbolFlags.EnumMember != 0) return .EnumMember;
    if (flags & SymbolFlags.Module != 0) return .Module;
    if (flags & SymbolFlags.Method != 0) return .Method;
    if (flags & SymbolFlags.Property != 0 or flags & SymbolFlags.GetAccessor != 0 or flags & SymbolFlags.SetAccessor != 0) return .Property;
    if (flags & SymbolFlags.TypeParameter != 0) return .TypeParameter;
    if (flags & SymbolFlags.Constructor != 0) return .Constructor;
    if (flags & SymbolFlags.BlockScopedVariable != 0 or flags & SymbolFlags.FunctionScopedVariable != 0) return .Variable;
    return .Variable;
}
