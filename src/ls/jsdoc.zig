const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const checker = @import("../checker/checker.zig");
const collections = @import("../collections/collections.zig");
const core = @import("../core/core.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const scanner = @import("../scanner/scanner.zig");
const ls = @import("languageservice.zig");
const hover = @import("hover.zig");

pub const JSDocTagInfo = struct {
    name: []const u8,
    text: []const u8,
};

pub fn getSymbolDocumentationComment(
    self: *ls.LanguageService,
    allocator: std.mem.Allocator,
    c: *checker.Checker,
    symbol: ast_gen.SymbolIndex,
) ![]const u8 {
    if (symbol == 0) return "";
    var parts = std.ArrayListUnmanaged([]const u8).empty;
    defer parts.deinit(allocator);

    var seen = std.AutoHashMapUnmanaged(ast_gen.NodeIndex, void).empty;
    defer seen.deinit(allocator);

    const a = self.getAst(self.getSourceFileNode(0)); // TODO: handle proper AST
    const decls = a.getSymbolDeclarations(symbol);

    for (decls) |decl| {
        if (decl == 0) continue;
        const gop = try seen.getOrPut(allocator, decl);
        if (gop.found_existing) continue;

        const doc = hover.getDocumentationFromDeclaration(self, allocator, c, symbol, decl, decl, .PlainText, true);
        if (doc.len > 0) {
            var found = false;
            for (parts.items) |p| {
                if (std.mem.eql(u8, p, doc)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                try parts.append(allocator, doc);
            }
        }
    }

    return std.mem.join(allocator, "\n", parts.items);
}

pub fn getSymbolJSDocTags(
    self: *ls.LanguageService,
    allocator: std.mem.Allocator,
    symbol: ast_gen.SymbolIndex,
) ![]JSDocTagInfo {
    if (symbol == 0) return &[_]JSDocTagInfo{};
    
    var infos = std.ArrayListUnmanaged(JSDocTagInfo).empty;
    var seen = std.AutoHashMapUnmanaged(ast_gen.NodeIndex, void).empty;
    defer seen.deinit(allocator);

    const a = self.getAst(self.getSourceFileNode(0)); // TODO: proper AST
    const decls = a.getSymbolDeclarations(symbol);

    for (decls) |decl| {
        if (decl == 0) continue;
        const gop = try seen.getOrPut(allocator, decl);
        if (gop.found_existing) continue;

        const tags = try declarationJSDocTags(allocator, a, decl);
        defer allocator.free(tags);

        var hasTypedef = false;
        var hasParamOrReturn = false;
        for (tags) |t| {
            const tk = a.getNodeKind(t);
            if (tk == .JSDocTypedefTag or tk == .JSDocCallbackTag) hasTypedef = true;
            if (tk == .JSDocParameterTag or tk == .JSDocReturnTag) hasParamOrReturn = true;
        }

        if (hasTypedef and !hasParamOrReturn) continue;

        for (tags) |tag| {
            const tagName = ast.getJSDocTagName(a, tag);
            const text = try getJSDocTagText(allocator, a, tag);
            try infos.append(allocator, .{
                .name = try allocator.dupe(u8, scanner.getTextOfNode(a, tagName)),
                .text = text,
            });
        }
    }
    return infos.toOwnedSlice(allocator);
}

pub fn declarationJSDocTags(allocator: std.mem.Allocator, a: *ast.Ast, node: ast_gen.NodeIndex) ![]ast_gen.NodeIndex {
    if ((a.getNodeFlags(node) & ast.NodeFlags.JSDoc) == 0) {
        var current = node;
        while (current != 0) {
            const jsdocs = ast.getJSDocs(a, current);
            if (jsdocs.len > 0) {
                const lastJSDoc = jsdocs[jsdocs.len - 1];
                const tagsNode = a.getNode(lastJSDoc).JSDoc.tags;
                if (tagsNode != 0) {
                    const tags = a.getNodeList(tagsNode);
                    return allocator.dupe(ast_gen.NodeIndex, tags);
                }
            }
            current = ast.getNextJSDocCommentLocation(a, current);
        }
    }
    return &[_]ast_gen.NodeIndex{};
}

pub fn getJSDocTagText(allocator: std.mem.Allocator, a: *ast.Ast, tag: ast_gen.NodeIndex) ![]const u8 {
    const commentList = a.getNode(tag).JSDocTag.commentList;
    const comment = scanner.getTextOfJSDocComment(a, commentList);
    
    const addComment = struct {
        fn apply(alloc: std.mem.Allocator, s: []const u8, c: []const u8) ![]const u8 {
            if (c.len == 0) return alloc.dupe(u8, s);
            return std.fmt.allocPrint(alloc, "{s} {s}", .{s, c});
        }
    }.apply;

    const kind = std.meta.activeTag(a.getNode(tag));
    switch (kind) {
        .JSDocThrowsTag => {
            const te = a.getNode(tag).JSDocThrowsTag.typeExpression;
            if (te != 0) {
                return try addComment(allocator, scanner.getTextOfNode(a, te), comment);
            }
            return allocator.dupe(u8, comment);
        },
        .JSDocImplementsTag => {
            return try addComment(allocator, scanner.getTextOfNode(a, a.getNode(tag).JSDocImplementsTag.className), comment);
        },
        .JSDocAugmentsTag => {
            return try addComment(allocator, scanner.getTextOfNode(a, a.getNode(tag).JSDocAugmentsTag.className), comment);
        },
        .JSDocTemplateTag => {
            const templateTag = a.getNode(tag).JSDocTemplateTag;
            var b = std.ArrayList(u8).init(allocator);
            defer b.deinit();

            if (templateTag.constraint != 0) {
                try b.appendSlice(scanner.getTextOfNode(a, templateTag.constraint));
            }
            if (templateTag.typeParameters != 0) {
                const tps = a.getNodeList(templateTag.typeParameters);
                for (tps, 0..) |tp, i| {
                    if (i == 0 and b.items.len != 0) try b.appendSlice(" ");
                    if (i != 0) try b.appendSlice(", ");
                    try b.appendSlice(scanner.getTextOfNode(a, tp));
                }
            }
            if (comment.len != 0) {
                if (b.items.len != 0) try b.appendSlice(" ");
                try b.appendSlice(comment);
            }
            return allocator.dupe(u8, b.items);
        },
        .JSDocTypeTag => {
            return try addComment(allocator, scanner.getTextOfNode(a, a.getNode(tag).JSDocTypeTag.typeExpression), comment);
        },
        .JSDocSatisfiesTag => {
            return try addComment(allocator, scanner.getTextOfNode(a, a.getNode(tag).JSDocSatisfiesTag.typeExpression), comment);
        },
        .JSDocSeeTag => {
            const ne = a.getNode(tag).JSDocSeeTag.nameExpression;
            if (ne != 0) {
                return try addComment(allocator, scanner.getTextOfNode(a, ne), comment);
            }
            return allocator.dupe(u8, comment);
        },
        .JSDocParameterTag, .JSDocPropertyTag => {
            const name = ast.getJSDocTagName(a, tag);
            if (name != 0) {
                return try addComment(allocator, scanner.getTextOfNode(a, name), comment);
            }
            return allocator.dupe(u8, comment);
        },
        else => return allocator.dupe(u8, comment),
    }
}
