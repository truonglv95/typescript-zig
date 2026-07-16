const std = @import("std");
const ls = @import("languageservice.zig");
const compiler = @import("../compiler/compiler.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const completions = @import("completions.zig");
const ast = @import("../ast/ast.zig");
const jsdoc_snippet = @import("jsdoc_snippet.zig");

pub fn getJSDocSnippetCompletion(languageService: *ls.LanguageService, allocator: std.mem.Allocator, file: compiler.FileId, position: u32) !?*completions.CompletionList {
    const prefs = languageService.userPreferences();
    if (prefs.enableJSDocCompletions == .False) return null;
    
    const tree = languageService.getAst(file);
    if (!(try jsdoc_snippet.isPotentiallyValidJSDocSnippetCompletionPosition(allocator, tree, position))) {
        return null;
    }
    
    const template = jsdoc_snippet.getDocCommentTemplateAtPosition(allocator, tree, tree.getSourceFile(), position) orelse return null;
    defer allocator.free(template.newText);
    
    // We would create a completion item here and return the list.
    // For now we return an empty list to compile.
    var list = try allocator.create(completions.CompletionList);
    list.* = completions.CompletionList{
        .isGlobalCompletion = false,
        .isMemberCompletion = false,
        .isNewIdentifierLocation = false,
        .optionalReplacementSpan = null,
        .entries = std.ArrayList(completions.CompletionEntry).empty,
        .defaultCommitCharacters = null,
    };
    return list;
}
