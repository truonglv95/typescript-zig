const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const completions = @import("completions.zig");

pub const StringCompletions = struct {
    allocator: std.mem.Allocator,

    pub fn getStringLiteralCompletions(
        ls: *languageservice.LanguageService,
        allocator: std.mem.Allocator,
        file: compiler.FileId,
        position: u32,
        context: ?*lsproto.CompletionContext,
    ) !*completions.CompletionList {
        _ = context;

        const tree = ls.getAst(file);
        const node = ast_utils.getTouchingPropertyName(ls.getSourceFileNode(file), tree, position);
        const parent = tree.getNodeParent(node);

        var comps = std.ArrayList(*completions.CompletionItem).empty;
        var chk = ls.getTypeCheckerForFile(file);

        // 1. ElementAccessExpression (e.g. obj["|"])
        if (tree.getNodeKind(parent) == .ElementAccessExpression) {
            const eae = tree.getNode(parent).ElementAccessExpression;
            if (eae.ArgumentExpression == node) {
                const exprType = chk.checkExpressionAdHoc(eae.Expression) catch 0;
                if (exprType != 0) {
                    const props = chk.getPropertiesOfType(exprType);
                    for (props) |propSymIdx| {
                        const propSym = chk.binder.symbols.items[propSymIdx];
                        const name = propSym.Name;

                        const item = try allocator.create(lsproto.CompletionItem);
                        item.* = lsproto.CompletionItem{
                            .label = name,
                            .kind = .Property,
                        };

                        const cItem = try allocator.create(completions.CompletionItem);
                        cItem.* = .{ .lspItem = item, .symbol = propSymIdx };
                        try comps.append(allocator, cItem);
                    }
                }
            }
        }

        // 2. Contextual type (e.g. type T = "a" | "b"; const x: T = "|")
        const services = @import("../checker/services.zig");
        const ctxType = services.getContextualType(chk, node, 0);
        if (ctxType != 0) {
            const t = chk.typesList.items[ctxType];
            if (t.flags & checker.types.TypeFlags.StringLiteral != 0) {
                const text = t.data.StringLiteral.text;
                const item = try allocator.create(lsproto.CompletionItem);
                item.* = lsproto.CompletionItem{
                    .label = text,
                    .kind = .EnumMember,
                };
                const cItem = try allocator.create(completions.CompletionItem);
                cItem.* = .{ .lspItem = item, .symbol = 0 };
                try comps.append(allocator, cItem);
            } else if (t.flags & checker.types.TypeFlags.Union != 0) {
                const unionTypes = chk.getTypesFromUnion(ctxType);
                for (unionTypes) |ut| {
                    const utT = chk.typesList.items[ut];
                    if (utT.flags & checker.types.TypeFlags.StringLiteral != 0) {
                        const text = utT.data.StringLiteral.text;
                        const item = try allocator.create(lsproto.CompletionItem);
                        item.* = lsproto.CompletionItem{
                            .label = text,
                            .kind = .EnumMember,
                        };
                        const cItem = try allocator.create(completions.CompletionItem);
                        cItem.* = .{ .lspItem = item, .symbol = 0 };
                        try comps.append(allocator, cItem);
                    }
                }
            }
        }

        const list = try allocator.create(completions.CompletionList);
        list.* = completions.CompletionList{
            .isIncomplete = false,
            .itemDefaults = null,
            .applyKind = null,
            .items = try comps.toOwnedSlice(allocator),
        };
        return list;
    }
};
