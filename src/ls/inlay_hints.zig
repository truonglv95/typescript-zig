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


    const userPreferences = ls.userPreferences;
    const inlayHintPreferences = userPreferences.inlayHints;
    if (!isAnyInlayHintEnabled(inlayHintPreferences)) {
        return null;
    }

    const program, const sourceFile = ls.getProgramAndFile(params.textDocument.uri) catch return null;
    const typeChecker, const done = try program.getTypeCheckerForFile(sourceFile);
    defer done();

    var result = std.ArrayListUnmanaged(lsproto.InlayHint){};
    errdefer result.deinit(allocator);

    var visitor = InlayHintVisitor{
        .allocator = allocator,
        .tree = typeChecker.binder.ast,
        .checker = typeChecker,
        .preferences = inlayHintPreferences,
        .result = &result,
    };
    try visitor.visitNode(sourceFile);

    return result.toOwnedSlice(allocator);
}

const InlayHintVisitor = struct {
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    checker: *checker.Checker,
    preferences: userpreferences.InlayHintsPreferences,
    result: *std.ArrayListUnmanaged(lsproto.InlayHint),

    pub fn visitNode(self: *@This(), node: ast_gen.NodeIndex) anyerror!void {
        if (node == 0) return;

        // In a full implementation, we would call:
        // visitForParameterNameHints(self, node);
        // visitForTypeHints(self, node);
        // visitForFunctionReturnTypeHints(self, node);
        // visitForEnumMemberValueHints(self, node);
        // For now, we traverse children.
        
        try ast.forEachChild(self.tree, node, self);
    }

    pub fn visitList(self: *@This(), list: u32) anyerror!void {
        for (self.tree.getNodeList(list)) |child| {
            try self.visitNode(child);
        }
    }
};

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
