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
        _ = ls; _ = file; _ = position;

        const list = try allocator.create(completions.CompletionList);
        list.* = completions.CompletionList{
            .isIncomplete = false,
            .itemDefaults = null,
            .applyKind = null,
            .items = &[_]*completions.CompletionItem{},
        };
        return list;
    }
};
