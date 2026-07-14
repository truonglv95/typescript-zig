const std = @import("std");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const languageservice = @import("languageservice.zig");
const compiler = @import("../compiler/program.zig");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const userpreferences = @import("lsutil/userpreferences.zig");

pub fn provideInlayHints(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.InlayHintParams,
) !?[]lsproto.InlayHint {
    _ = allocator;

    const userPreferences = ls.userPreferences;
    const inlayHintPreferences = userPreferences.inlayHints;
    if (!isAnyInlayHintEnabled(inlayHintPreferences)) {
        return null;
    }

    const program, const sourceFile = ls.getProgramAndFile(params.textDocument.uri) catch return null;
    const typeChecker, const done = try program.getTypeCheckerForFile(sourceFile);
    defer done();

    // TODO: implement AST visitor
    _ = typeChecker;
    return null;
}

fn isAnyInlayHintEnabled(prefs: userpreferences.InlayHintsPreferences) bool {
    if (prefs.includeInlayParameterNameHints != .None) return true;
    if (prefs.includeInlayParameterNameHintsWhenArgumentMatchesName == .True) return true;
    if (prefs.includeInlayFunctionParameterTypeHints == .True) return true;
    if (prefs.includeInlayVariableTypeHints == .True) return true;
    if (prefs.includeInlayVariableTypeHintsWhenTypeMatchesName == .True) return true;
    if (prefs.includeInlayPropertyDeclarationTypeHints == .True) return true;
    if (prefs.includeInlayFunctionLikeReturnTypeHints == .True) return true;
    if (prefs.includeInlayEnumMemberValueHints == .True) return true;
    return false;
}
