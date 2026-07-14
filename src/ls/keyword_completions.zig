const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const completions = @import("completions.zig");

pub const KeywordCompletions = struct {
    pub fn getKeywordCompletions(
        ls: *languageservice.LanguageService,
        allocator: std.mem.Allocator,
        file: ast.NodeIndex,
        position: u32,
    ) !*completions.CompletionList {
        _ = ls;
        _ = file;
        _ = position;

        var comps = std.ArrayList(*completions.CompletionItem).empty;

        const keywords = [_][]const u8{ "const", "let", "var", "function", "class", "interface", "type", "export", "import", "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue", "return", "throw", "try", "catch", "finally", "yield", "await", "new", "typeof", "instanceof", "in", "void", "delete", "debugger", "this", "super", "true", "false", "null", "undefined", "extends", "implements", "public", "private", "protected", "readonly", "static", "abstract", "override", "as", "any", "number", "string", "boolean", "symbol", "bigint", "object", "unknown", "never" };

        for (keywords) |kw| {
            const item = try allocator.create(lsproto.CompletionItem);
            item.* = lsproto.CompletionItem{
                .label = kw,
                .kind = .Keyword,
            };
            const cItem = try allocator.create(completions.CompletionItem);
            cItem.* = .{ .lspItem = item, .symbol = 0 };
            try comps.append(allocator, cItem);
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
