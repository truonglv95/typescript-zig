const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");

pub fn provideInlayHints(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.InlayHintParams,
) !?[]lsproto.InlayHint {
    _ = ls; _ = allocator; _ = params;
    // stub
    return null;
}
