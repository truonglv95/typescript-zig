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
        file: ast.NodeIndex,
        position: u32,
        context: ?*lsproto.CompletionContext,
    ) !*completions.CompletionList {
        _ = ls; _ = file; _ = position; _ = context;

        // Stub out full logic, return empty for now
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
