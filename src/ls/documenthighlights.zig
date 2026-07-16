const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");

const findallreferences = @import("findallreferences.zig");
const lsconv = @import("lsconv/converters.zig");
const lsutil = @import("lsutil/lsutil.zig");
const astnav = @import("../astnav/tokens.zig");
const scanner = @import("../scanner/scanner.zig");

pub fn provideDocumentHighlights(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    documentURI: lsproto.DocumentUri,
    documentPosition: lsproto.Position,
) !?[]lsproto.DocumentHighlight {
    const multi_opt = try provideDocumentHighlightsWorker(ls, allocator, documentURI, documentPosition, null);
    if (multi_opt) |multi_highlights| {
        defer {
            for (multi_highlights) |mh| {
                allocator.free(mh.uri);
                allocator.free(mh.highlights);
            }
            allocator.free(multi_highlights);
        }

        var documentHighlights = std.ArrayList(lsproto.DocumentHighlight).init(allocator);
        errdefer documentHighlights.deinit();

        for (multi_highlights) |mh| {
            if (std.mem.eql(u8, mh.uri, documentURI)) {
                try documentHighlights.appendSlice(mh.highlights);
            }
        }
        if (documentHighlights.items.len == 0) return null;
        return try documentHighlights.toOwnedSlice();
    }
    return null;
}

pub fn provideMultiDocumentHighlights(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    documentURI: lsproto.DocumentUri,
    documentPosition: lsproto.Position,
    filesToSearch: []lsproto.DocumentUri,
) !?[]lsproto.MultiDocumentHighlight {
    return provideDocumentHighlightsWorker(ls, allocator, documentURI, documentPosition, filesToSearch);
}

fn provideDocumentHighlightsWorker(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    documentURI: lsproto.DocumentUri,
    documentPosition: lsproto.Position,
    filesToSearch: ?[]lsproto.DocumentUri,
) !?[]lsproto.MultiDocumentHighlight {
    const fileId = ls.program.getFileId(documentURI) orelse return null;
    const sourceFileNode = ls.getSourceFileNode(fileId);

    const pos = ls.converters.lineAndCharacterToPosition(fileId, documentPosition);
    const node = astnav.getTouchingPropertyName(sourceFileNode, &ls.program.ast, pos);

    const parent = ls.program.ast.getParent(node);
    if (parent != ast.null_node) {
        const parentKind = ls.program.ast.getNodeKind(parent);
        if (parentKind == .JsxClosingElement or (parentKind == .JsxOpeningElement and ls.program.ast.getNode(parent).JsxOpeningElement.tagName == node)) {
            var openingElement = ast.null_node;
            var closingElement = ast.null_node;
            const parentParent = ls.program.ast.getParent(parent);
            if (ast_utils.isJsxElement(&ls.program.ast, parentParent)) {
                openingElement = ls.program.ast.getNode(parentParent).JsxElement.openingElement;
                closingElement = ls.program.ast.getNode(parentParent).JsxElement.closingElement;
            }

            var highlights = std.ArrayList(lsproto.DocumentHighlight).init(allocator);
            errdefer highlights.deinit();

            if (openingElement != ast.null_node) {
                try highlights.append(lsproto.DocumentHighlight{
                    .range = findallreferences.getLspRangeOfNode(ls, fileId, openingElement, null, 0),
                    .kind = .Read,
                });
            }
            if (closingElement != ast.null_node) {
                try highlights.append(lsproto.DocumentHighlight{
                    .range = findallreferences.getLspRangeOfNode(ls, fileId, closingElement, null, 0),
                    .kind = .Read,
                });
            }

            var multiHighlights = std.ArrayList(lsproto.MultiDocumentHighlight).init(allocator);
            errdefer multiHighlights.deinit();

            const uri_dup = try allocator.dupe(u8, documentURI);
            errdefer allocator.free(uri_dup);

            try multiHighlights.append(lsproto.MultiDocumentHighlight{
                .uri = uri_dup,
                .highlights = try highlights.toOwnedSlice(),
            });

            return try multiHighlights.toOwnedSlice();
        }
    }

    const multiHighlights = try getSemanticDocumentHighlights(ls, allocator, pos, node, documentURI, filesToSearch);
    if (multiHighlights == null or multiHighlights.?.len == 0) {
        if (multiHighlights != null) {
            allocator.free(multiHighlights.?);
        }
        const syntacticHighlights = try getSyntacticDocumentHighlights(ls, allocator, node, fileId);
        if (syntacticHighlights != null and syntacticHighlights.?.len > 0) {
            var m_highlights = std.ArrayList(lsproto.MultiDocumentHighlight).init(allocator);
            errdefer m_highlights.deinit();

            const uri_dup = try allocator.dupe(u8, documentURI);
            errdefer allocator.free(uri_dup);

            try m_highlights.append(lsproto.MultiDocumentHighlight{
                .uri = uri_dup,
                .highlights = syntacticHighlights.?,
            });
            return try m_highlights.toOwnedSlice();
        } else if (syntacticHighlights != null) {
            allocator.free(syntacticHighlights.?);
        }
        return null;
    }

    return multiHighlights;
}

fn getSemanticDocumentHighlights(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    position: u32,
    node: ast.NodeIndex,
    documentURI: lsproto.DocumentUri,
    filesToSearch: ?[]lsproto.DocumentUri,
) !?[]lsproto.MultiDocumentHighlight {
    _ = node;
    const fileId = ls.program.getFileId(documentURI) orelse return null;
    const lsp_pos = ls.converters.positionToLineAndCharacter(fileId, position);

    const data_opt = try findallreferences.provideSymbolsAndEntries(ls, allocator, documentURI, lsp_pos, false, false);
    if (data_opt == null) return null;
    const data = data_opt.?;

    var FileHighlightsMap = std.StringHashMap(std.ArrayList(lsproto.DocumentHighlight)).init(allocator);
    defer {
        var it = FileHighlightsMap.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit();
            allocator.free(entry.key_ptr.*);
        }
        FileHighlightsMap.deinit();
    }

    for (data.symbolsAndEntries) |s| {
        for (s.references) |ref| {
            if (ref.node != ast.null_node) {
                const entry = findallreferences.resolveEntry(ls, ref);
                var kind: lsproto.DocumentHighlightKind = .Read;
                if (entry.kind == .range) {
                    // kind is read
                } else {
                    if (ast_utils.isWriteAccessForReference(&ls.program.ast, entry.node)) {
                        kind = .Write;
                    }
                }
                const highlight = lsproto.DocumentHighlight{
                    .range = findallreferences.getRangeOfEntry(ls, entry),
                    .kind = kind,
                };
                
                const gop = try FileHighlightsMap.getOrPut(entry.fileName);
                if (!gop.found_existing) {
                    gop.key_ptr.* = try allocator.dupe(u8, entry.fileName);
                    gop.value_ptr.* = std.ArrayList(lsproto.DocumentHighlight).init(allocator);
                }
                try gop.value_ptr.append(highlight);
            }
        }
    }

    var result = std.ArrayList(lsproto.MultiDocumentHighlight).init(allocator);
    errdefer {
        for (result.items) |mh| {
            allocator.free(mh.uri);
            allocator.free(mh.highlights);
        }
        result.deinit();
    }

    var it = FileHighlightsMap.iterator();
    while (it.next()) |entry| {
        const uri = try lsconv.fileNameToDocumentURI(allocator, entry.key_ptr.*);
        errdefer allocator.free(uri);
        
        var keep = true;
        if (filesToSearch) |files| {
            keep = false;
            for (files) |f| {
                if (std.mem.eql(u8, f, uri)) {
                    keep = true;
                    break;
                }
            }
        }
        
        if (keep) {
            try result.append(lsproto.MultiDocumentHighlight{
                .uri = uri,
                .highlights = try entry.value_ptr.toOwnedSlice(),
            });
        } else {
            allocator.free(uri);
        }
    }

    if (result.items.len == 0) return null;
    return try result.toOwnedSlice();
}

fn getSyntacticDocumentHighlights(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    node: ast.NodeIndex,
    fileId: compiler.FileId,
) !?[]lsproto.DocumentHighlight {
    const kind = ls.program.ast.getNodeKind(node);
    const parent = ls.program.ast.getParent(node);
    
    switch (kind) {
        .IfKeyword, .ElseKeyword => {
            if (ls.program.ast.getNodeKind(parent) == .IfStatement) {
                return try getIfElseOccurrences(ls, allocator, parent, fileId);
            }
            return null;
        },
        .ReturnKeyword => {
            return try useParent(ls, allocator, parent, fileId, isReturnStatement, getReturnOccurrences);
        },
        .ThrowKeyword => {
            return try useParent(ls, allocator, parent, fileId, isThrowStatement, getThrowOccurrences);
        },
        .TryKeyword, .CatchKeyword, .FinallyKeyword => {
            var tryStatement = parent;
            if (kind == .CatchKeyword) {
                tryStatement = ls.program.ast.getParent(parent);
            }
            return try useParent(ls, allocator, tryStatement, fileId, isTryStatement, getTryCatchFinallyOccurrences);
        },
        .SwitchKeyword => {
            return try useParent(ls, allocator, parent, fileId, isSwitchStatement, getSwitchCaseDefaultOccurrences);
        },
        .CaseKeyword, .DefaultKeyword => {
            const parentKind = ls.program.ast.getNodeKind(parent);
            if (parentKind == .DefaultClause or parentKind == .CaseClause) {
                const p3 = ls.program.ast.getParent(ls.program.ast.getParent(parent));
                return try useParent(ls, allocator, p3, fileId, isSwitchStatement, getSwitchCaseDefaultOccurrences);
            }
            return null;
        },
        .BreakKeyword, .ContinueKeyword => {
            return try useParent(ls, allocator, parent, fileId, isBreakOrContinueStatement, getBreakOrContinueStatementOccurrences);
        },
        .ForKeyword, .WhileKeyword, .DoKeyword => {
            return try useParent(ls, allocator, parent, fileId, isIterationStatementTrue, getLoopBreakContinueOccurrences);
        },
        .ConstructorKeyword => {
            return try getFromAllDeclarations(ls, allocator, isConstructorDeclaration, &[_]std.meta.Tag(ast.NodeData){.ConstructorKeyword}, node, fileId);
        },
        .GetKeyword, .SetKeyword => {
            return try getFromAllDeclarations(ls, allocator, isAccessor, &[_]std.meta.Tag(ast.NodeData){.GetKeyword, .SetKeyword}, node, fileId);
        },
        .AwaitKeyword => {
            return try useParent(ls, allocator, parent, fileId, isAwaitExpression, getAsyncAndAwaitOccurrences);
        },
        .AsyncKeyword => {
            const nodes = try getAsyncAndAwaitOccurrences(ls, allocator, node, fileId);
            if (nodes) |ns| {
                defer allocator.free(ns);
                return try highlightSpans(ls, allocator, ns, fileId);
            }
            return null;
        },
        .YieldKeyword => {
            const nodes = try getYieldOccurrences(ls, allocator, node, fileId);
            if (nodes) |ns| {
                defer allocator.free(ns);
                return try highlightSpans(ls, allocator, ns, fileId);
            }
            return null;
        },
        .InKeyword, .OutKeyword => {
            return null;
        },
        else => {
            if (ast_utils.isModifierKind(kind)) {
                const parentKind = ls.program.ast.getNodeKind(parent);
                if (ast_utils.isDeclaration(&ls.program.ast, parent) or parentKind == .VariableStatement) {
                    const nodes = try getModifierOccurrences(ls, allocator, kind, parent, fileId);
                    if (nodes) |ns| {
                        defer allocator.free(ns);
                        return try highlightSpans(ls, allocator, ns, fileId);
                    }
                }
            }
            return null;
        }
    }
}

// Helpers type signatures
fn isReturnStatement(tree: *ast.Ast, node: ast.NodeIndex) bool { return tree.getNodeKind(node) == .ReturnStatement; }
fn isThrowStatement(tree: *ast.Ast, node: ast.NodeIndex) bool { return tree.getNodeKind(node) == .ThrowStatement; }
fn isTryStatement(tree: *ast.Ast, node: ast.NodeIndex) bool { return tree.getNodeKind(node) == .TryStatement; }
fn isSwitchStatement(tree: *ast.Ast, node: ast.NodeIndex) bool { return tree.getNodeKind(node) == .SwitchStatement; }
fn isBreakOrContinueStatement(tree: *ast.Ast, node: ast.NodeIndex) bool { const kind = tree.getNodeKind(node); return kind == .BreakStatement or kind == .ContinueStatement; }
fn isIterationStatementTrue(tree: *ast.Ast, node: ast.NodeIndex) bool { return ast_utils.isIterationStatement(tree, node, true); }
fn isConstructorDeclaration(tree: *ast.Ast, node: ast.NodeIndex) bool { return tree.getNodeKind(node) == .Constructor; }
fn isAccessor(tree: *ast.Ast, node: ast.NodeIndex) bool { const kind = tree.getNodeKind(node); return kind == .GetAccessor or kind == .SetAccessor; }
fn isAwaitExpression(tree: *ast.Ast, node: ast.NodeIndex) bool { return tree.getNodeKind(node) == .AwaitExpression; }

fn useParent(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    node: ast.NodeIndex,
    fileId: compiler.FileId,
    nodeTest: *const fn (*ast.Ast, ast.NodeIndex) bool,
    getNodes: *const fn (*languageservice.LanguageService, std.mem.Allocator, ast.NodeIndex, compiler.FileId) std.mem.Allocator.Error!?[]ast.NodeIndex,
) !?[]lsproto.DocumentHighlight {
    if (nodeTest(&ls.program.ast, node)) {
        if (try getNodes(ls, allocator, node, fileId)) |nodes| {
            defer allocator.free(nodes);
            return try highlightSpans(ls, allocator, nodes, fileId);
        }
    }
    return null;
}

fn highlightSpans(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    nodes: []ast.NodeIndex,
    fileId: compiler.FileId,
) !?[]lsproto.DocumentHighlight {
    if (nodes.len == 0) return null;
    var highlights = std.ArrayList(lsproto.DocumentHighlight).init(allocator);
    errdefer highlights.deinit();

    for (nodes) |node| {
        if (node != ast.null_node) {
            try highlights.append(lsproto.DocumentHighlight{
                .range = findallreferences.getLspRangeOfNode(ls, fileId, node, null, 0),
                .kind = .Read,
            });
        }
    }
    return try highlights.toOwnedSlice();
}

fn getFromAllDeclarations(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    nodeTest: *const fn (*ast.Ast, ast.NodeIndex) bool,
    keywords: []const std.meta.Tag(ast.NodeData),
    node: ast.NodeIndex,
    fileId: compiler.FileId,
) !?[]lsproto.DocumentHighlight {
    _ = keywords;
    var symbolDecls = std.ArrayList(ast.NodeIndex).init(allocator);
    defer symbolDecls.deinit();

    const parent = ls.program.ast.getParent(node);
    if (nodeTest(&ls.program.ast, parent)) {
        if (ast_utils.canHaveSymbol(&ls.program.ast, parent)) {
            const sym = checker.getSymbolOfNode(&ls.program.ast, parent);
            if (sym != ast.null_symbol) {
                const declarations = ls.program.ast.getSymbol(sym).declarations;
                for (declarations) |d| {
                    if (nodeTest(&ls.program.ast, d)) {
                        try symbolDecls.append(d);
                    }
                }
            }
        }
    }

    if (symbolDecls.items.len > 0) {
        return try highlightSpans(ls, allocator, symbolDecls.items, fileId);
    }
    return null; 
}


fn findTokensInNodeExcludingChildren(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, node: ast.NodeIndex, targetKinds: []const std.meta.Tag(ast.NodeData), outRanges: *std.ArrayList(ast.TextRange)) !void {
    var childRanges = std.ArrayList(ast.TextRange).init(allocator);
    defer childRanges.deinit();

    const Visitor = struct {
        arr: *std.ArrayList(ast.TextRange),
        t: *ast.Ast,
        pub fn check(self: *@This(), n: ast.NodeIndex) bool {
            if (n != 0) {
                self.arr.append(.{
                    .pos = self.t.getNodePos(n),
                    .end = self.t.getNodeEnd(n),
                }) catch {};
            }
            return false;
        }
    };
    var v = Visitor{ .arr = &childRanges, .t = &ls.program.ast };
    _ = ast_utils.forEachChildBool(&ls.program.ast, node, &v, Visitor.check);

    var pos = ls.program.ast.getNodePos(node);
    const end = ls.program.ast.getNodeEnd(node);
    var scan = scanner.getScannerForSourceFile(&ls.program.ast, pos);

    var childIdx: usize = 0;

    while (pos < end) {
        while (childIdx < childRanges.items.len and pos >= childRanges.items[childIdx].end) {
            childIdx += 1;
        }

        if (childIdx < childRanges.items.len and pos >= childRanges.items[childIdx].pos) {
            pos = childRanges.items[childIdx].end;
            scan = scanner.getScannerForSourceFile(&ls.program.ast, pos);
            continue;
        }

        const tokenKind = scan.token();
        const tokenFullStart = scan.tokenFullStart();
        const tokenEnd = scan.tokenEnd();

        if (tokenFullStart >= end) break;

        for (targetKinds) |k| {
            if (k == tokenKind) {
                try outRanges.append(.{ .pos = scan.tokenPos(), .end = tokenEnd });
                break;
            }
        }

        pos = tokenEnd;
        scan.scan();
    }
}

fn highlightRanges(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, ranges: []ast.TextRange, fileId: compiler.FileId) !?[]lsproto.DocumentHighlight {
    if (ranges.len == 0) return null;
    var highlights = std.ArrayList(lsproto.DocumentHighlight).init(allocator);
    errdefer highlights.deinit();

    for (ranges) |r| {
        try highlights.append(lsproto.DocumentHighlight{
            .range = ls.converters.toLSPRange(ls.getScript(fileId), r),
            .kind = .Read,
        });
    }
    return try highlights.toOwnedSlice();
}

fn getIfElseOccurrences(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, ifStatement: ast.NodeIndex, fileId: compiler.FileId) !?[]lsproto.DocumentHighlight {
    var currentIf = ifStatement;
    while (true) {
        const parent = ls.program.ast.getParent(currentIf);
        if (ls.program.ast.getNodeKind(parent) == .IfStatement) {
            const pNode = ls.program.ast.getNode(parent).IfStatement;
            if (pNode.ElseStatement != null and pNode.ElseStatement.? == currentIf) {
                currentIf = parent;
                continue;
            }
        }
        break;
    }

    var ranges = std.ArrayList(ast.TextRange).init(allocator);
    defer ranges.deinit();

    while (true) {
        try findTokensInNodeExcludingChildren(ls, allocator, currentIf, &[_]std.meta.Tag(ast.NodeData){.IfKeyword}, &ranges);

        const nodeData = ls.program.ast.getNode(currentIf).IfStatement;
        if (nodeData.ElseStatement) |els| {
            try findTokensInNodeExcludingChildren(ls, allocator, currentIf, &[_]std.meta.Tag(ast.NodeData){.ElseKeyword}, &ranges);
            if (ls.program.ast.getNodeKind(els) == .IfStatement) {
                currentIf = els;
                continue;
            } else {
                break;
            }
        } else {
            break;
        }
    }

    return try highlightRanges(ls, allocator, ranges.items, fileId);
}

fn aggregateOwnedThrowStatements(tree: *ast.Ast, node: ast.NodeIndex, throwStatements: *std.ArrayList(ast.NodeIndex)) !void {
    if (tree.getNodeKind(node) == .ThrowStatement) {
        try throwStatements.append(node);
        return;
    }
    if (tree.getNodeKind(node) == .TryStatement) {
        const statement = tree.getNode(node).TryStatement;
        const tryBlock = statement.TryBlock;
        const catchClause = statement.CatchClause;
        const finallyBlock = statement.FinallyBlock;

        if (catchClause != null and catchClause.? != 0) {
            try aggregateOwnedThrowStatements(tree, catchClause.?, throwStatements);
        } else if (tryBlock != 0) {
            try aggregateOwnedThrowStatements(tree, tryBlock, throwStatements);
        }
        if (finallyBlock != null and finallyBlock.? != 0) {
            try aggregateOwnedThrowStatements(tree, finallyBlock.?, throwStatements);
        }
        return;
    }
    if (ast_utils.isFunctionLikeNode(tree, node)) {
        return;
    }

    const Visitor = struct {
        t: *ast.Ast,
        ts: *std.ArrayList(ast.NodeIndex),
        pub fn visitNode(self: *@This(), n: ast.NodeIndex) anyerror!void {
            try aggregateOwnedThrowStatements(self.t, n, self.ts);
        }
        pub fn visitList(self: *@This(), list: u32) anyerror!void {
            for (self.t.getNodeList(list)) |n| {
                try aggregateOwnedThrowStatements(self.t, n, self.ts);
            }
        }
    };
    var visitor = Visitor{ .t = tree, .ts = throwStatements };
    try ast.forEachChild(tree, node, &visitor);
}

fn getReturnOccurrences(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, node: ast.NodeIndex, fileId: compiler.FileId) !?[]ast.NodeIndex {
    _ = fileId;
    const parent = ls.program.ast.getParent(node);
    const funcNode = astnav.findAncestor(&ls.program.ast, parent, ast_utils.isFunctionLike);
    if (funcNode == 0) return null;

    var returns = std.ArrayList(ast.NodeIndex).init(allocator);
    errdefer returns.deinit();

    const body = ast_utils.getBody(&ls.program.ast, funcNode);
    if (body != 0) {
        const Ctx = struct {
            arr: *std.ArrayList(ast.NodeIndex),
        };
        var ctx = Ctx{ .arr = &returns };
        const visitor = struct {
            fn visit(retNode: ast.NodeIndex, c: ?*anyopaque) bool {
                const cx = @as(*Ctx, @ptrCast(@alignCast(c)));
                cx.arr.append(retNode) catch {};
                return false;
            }
        }.visit;
        _ = ast_utils.forEachReturnStatement(&ls.program.ast, body, visitor, &ctx);

        try aggregateOwnedThrowStatements(&ls.program.ast, body, &returns);
    }
    
    if (returns.items.len == 0) return null;
    return try returns.toOwnedSlice();
}

fn getThrowStatementOwner(tree: *ast.Ast, throwStatement: ast.NodeIndex) ast.NodeIndex {
    var child = throwStatement;
    while (tree.getParent(child) != 0) {
        const parent = tree.getParent(child);
        const parentKind = tree.getNodeKind(parent);
        
        if ((parentKind == .Block and ast_utils.isFunctionLike(tree.getNodeKind(tree.getParent(parent)))) or parentKind == .SourceFile) {
            return parent;
        }

        if (parentKind == .TryStatement) {
            const tryStatementNode = tree.getNode(parent).TryStatement;
            if (tryStatementNode.TryBlock == child and tryStatementNode.CatchClause != null and tryStatementNode.CatchClause.? != 0) {
                return child;
            }
        }
        child = parent;
    }
    return 0;
}

fn getThrowOccurrences(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, node: ast.NodeIndex, fileId: compiler.FileId) !?[]ast.NodeIndex {
    _ = fileId;
    const owner = getThrowStatementOwner(&ls.program.ast, node);
    if (owner == 0) return null;

    var keywords = std.ArrayList(ast.NodeIndex).init(allocator);
    errdefer keywords.deinit();

    try aggregateOwnedThrowStatements(&ls.program.ast, owner, &keywords);

    const ownerKind = ls.program.ast.getNodeKind(owner);
    if ((ownerKind == .Block and ast_utils.isFunctionLike(ls.program.ast.getNodeKind(ls.program.ast.getParent(owner))))) {
        const Ctx = struct {
            arr: *std.ArrayList(ast.NodeIndex),
        };
        var ctx = Ctx{ .arr = &keywords };
        const visitor = struct {
            fn visit(retNode: ast.NodeIndex, c: ?*anyopaque) bool {
                const cx = @as(*Ctx, @ptrCast(@alignCast(c)));
                cx.arr.append(retNode) catch {};
                return false;
            }
        }.visit;
        _ = ast_utils.forEachReturnStatement(&ls.program.ast, owner, visitor, &ctx);
    }

    if (keywords.items.len == 0) return null;
    return try keywords.toOwnedSlice();
}

fn getTryCatchFinallyOccurrences(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, node: ast.NodeIndex, fileId: compiler.FileId) !?[]ast.NodeIndex {
    _ = fileId;
    var keywords = std.ArrayList(ast.NodeIndex).init(allocator);
    errdefer keywords.deinit();

    try keywords.append(node);
    const tryStatement = ls.program.ast.getNode(node).TryStatement;
    if (tryStatement.CatchClause) |cc| {
        if (cc != 0) try keywords.append(cc);
    }
    if (tryStatement.FinallyBlock) |fb| {
        if (fb != 0) try keywords.append(fb);
    }

    if (keywords.items.len == 0) return null;
    return try keywords.toOwnedSlice();
}

fn getSwitchCaseDefaultOccurrences(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, node: ast.NodeIndex, fileId: compiler.FileId) !?[]ast.NodeIndex {
    _ = fileId;
    var keywords = std.ArrayList(ast.NodeIndex).init(allocator);
    errdefer keywords.deinit();

    try keywords.append(node);
    
    const switchStatement = ls.program.ast.getNode(node).SwitchStatement;
    const caseBlock = switchStatement.CaseBlock;
    if (caseBlock != 0) {
        const clauses = ls.program.ast.getNode(caseBlock).CaseBlock.Clauses;
        for (ls.program.ast.getNodeList(clauses)) |clause| {
            try keywords.append(clause);
        }
        
        var statements = std.ArrayList(ast.NodeIndex).init(allocator);
        defer statements.deinit();
        try aggregateAllBreakAndContinueStatements(&ls.program.ast, caseBlock, &statements);
        for (statements.items) |stmt| {
            if (ls.program.ast.getNodeKind(stmt) == .BreakStatement and ownsBreakOrContinueStatement(&ls.program.ast, node, stmt)) {
                try keywords.append(stmt);
            }
        }
    }

    if (keywords.items.len == 0) return null;
    return try keywords.toOwnedSlice();
}

fn isLabeledBy(tree: *ast.Ast, node: ast.NodeIndex, labelName: []const u8) bool {
    var current = tree.getParent(node);
    while (current != 0) {
        if (tree.getNodeKind(current) != .LabeledStatement) {
            return false;
        }
        const labelNode = tree.getNode(current).LabeledStatement.Label;
        const text = tree.getTextOfNode(labelNode);
        if (std.mem.eql(u8, text, labelName)) {
            return true;
        }
        current = tree.getParent(current);
    }
    return false;
}

fn getBreakOrContinueOwner(tree: *ast.Ast, statement: ast.NodeIndex) ast.NodeIndex {
    const isBreak = tree.getNodeKind(statement) == .BreakStatement;
    const labelNode = if (isBreak) tree.getNode(statement).BreakStatement.Label else tree.getNode(statement).ContinueStatement.Label;
    const labelName = if (labelNode != null and labelNode.? != 0) tree.getTextOfNode(labelNode.?) else null;

    var current = tree.getParent(statement);
    while (current != 0) {
        const kind = tree.getNodeKind(current);
        switch (kind) {
            .SwitchStatement => {
                if (!isBreak) {
                    // continue cannot target switch
                } else {
                    if (labelName == null or isLabeledBy(tree, current, labelName.?)) {
                        return current;
                    }
                }
            },
            .ForStatement, .ForInStatement, .ForOfStatement, .WhileStatement, .DoStatement => {
                if (labelName == null or isLabeledBy(tree, current, labelName.?)) {
                    return current;
                }
            },
            else => {
                if (ast_utils.isFunctionLike(kind)) {
                    return 0;
                }
            }
        }
        current = tree.getParent(current);
    }
    return 0;
}

fn ownsBreakOrContinueStatement(tree: *ast.Ast, owner: ast.NodeIndex, statement: ast.NodeIndex) bool {
    return getBreakOrContinueOwner(tree, statement) == owner;
}

fn aggregateAllBreakAndContinueStatements(tree: *ast.Ast, node: ast.NodeIndex, statements: *std.ArrayList(ast.NodeIndex)) !void {
    const kind = tree.getNodeKind(node);
    if (kind == .BreakStatement or kind == .ContinueStatement) {
        try statements.append(node);
        return;
    }
    if (ast_utils.isFunctionLike(kind)) {
        return;
    }

    const Visitor = struct {
        t: *ast.Ast,
        s: *std.ArrayList(ast.NodeIndex),
        pub fn visitNode(self: *@This(), n: ast.NodeIndex) anyerror!void {
            try aggregateAllBreakAndContinueStatements(self.t, n, self.s);
        }
        pub fn visitList(self: *@This(), list: u32) anyerror!void {
            for (self.t.getNodeList(list)) |n| {
                try aggregateAllBreakAndContinueStatements(self.t, n, self.s);
            }
        }
    };
    var visitor = Visitor{ .t = tree, .s = statements };
    try ast.forEachChild(tree, node, &visitor);
}

fn getBreakOrContinueStatementOccurrences(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, node: ast.NodeIndex, fileId: compiler.FileId) !?[]ast.NodeIndex {
    const owner = getBreakOrContinueOwner(&ls.program.ast, node);
    if (owner != 0) {
        const kind = ls.program.ast.getNodeKind(owner);
        switch (kind) {
            .ForStatement, .ForInStatement, .ForOfStatement, .DoStatement, .WhileStatement => {
                return getLoopBreakContinueOccurrences(ls, allocator, owner, fileId);
            },
            .SwitchStatement => {
                return getSwitchCaseDefaultOccurrences(ls, allocator, owner, fileId);
            },
            else => return null,
        }
    }
    return null;
}

fn getLoopBreakContinueOccurrences(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, node: ast.NodeIndex, fileId: compiler.FileId) !?[]ast.NodeIndex {
    _ = fileId;
    var keywords = std.ArrayList(ast.NodeIndex).init(allocator);
    errdefer keywords.deinit();

    try keywords.append(node);

    var statements = std.ArrayList(ast.NodeIndex).init(allocator);
    defer statements.deinit();

    try aggregateAllBreakAndContinueStatements(&ls.program.ast, node, &statements);
    for (statements.items) |stmt| {
        if (ownsBreakOrContinueStatement(&ls.program.ast, node, stmt)) {
            try keywords.append(stmt);
        }
    }

    if (keywords.items.len == 0) return null;
    return try keywords.toOwnedSlice();
}

fn traverseWithoutCrossingFunction(tree: *ast.Ast, node: ast.NodeIndex, context: anytype, cb: anytype) anyerror!void {
    try cb(context, node);
    const kind = tree.getNodeKind(node);
    if (!ast_utils.isFunctionLike(kind) and kind != .ClassDeclaration and kind != .ClassExpression and kind != .InterfaceDeclaration and kind != .ModuleDeclaration and kind != .TypeAliasDeclaration and !ast_utils.isTypeNode(kind)) {
        const Visitor = struct {
            t: *ast.Ast,
            cx: @TypeOf(context),
            callback: @TypeOf(cb),
            pub fn visitNode(self: *@This(), n: ast.NodeIndex) anyerror!void {
                try traverseWithoutCrossingFunction(self.t, n, self.cx, self.callback);
            }
            pub fn visitList(self: *@This(), list: u32) anyerror!void {
                for (self.t.getNodeList(list)) |n| {
                    try traverseWithoutCrossingFunction(self.t, n, self.cx, self.callback);
                }
            }
        };
        var visitor = Visitor{ .t = tree, .cx = context, .callback = cb };
        try ast.forEachChild(tree, node, &visitor);
    }
}

fn getAsyncAndAwaitOccurrences(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, node: ast.NodeIndex, fileId: compiler.FileId) !?[]ast.NodeIndex {
    _ = fileId;
    const fun = astnav.findAncestor(&ls.program.ast, node, ast_utils.isFunctionLike);
    if (fun == 0) return null;

    var keywords = std.ArrayList(ast.NodeIndex).init(allocator);
    errdefer keywords.deinit();
    
    try keywords.append(fun);

    const Ctx = struct {
        t: *ast.Ast,
        arr: *std.ArrayList(ast.NodeIndex),
        fn cb(self: *@This(), n: ast.NodeIndex) anyerror!void {
            if (self.t.getNodeKind(n) == .AwaitExpression) {
                try self.arr.append(n);
            }
        }
    };
    var ctx = Ctx{ .t = &ls.program.ast, .arr = &keywords };

    const Visitor = struct {
        t: *ast.Ast,
        c: *Ctx,
        pub fn visitNode(self: *@This(), n: ast.NodeIndex) anyerror!void {
            const closure = struct {
                fn run(cx: *Ctx, cn: ast.NodeIndex) !void {
                    try cx.cb(cn);
                }
            };
            try traverseWithoutCrossingFunction(self.t, n, self.c, closure.run);
        }
        pub fn visitList(self: *@This(), list: u32) anyerror!void {
            for (self.t.getNodeList(list)) |n| {
                try self.visitNode(n);
            }
        }
    };
    var visitor = Visitor{ .t = &ls.program.ast, .c = &ctx };
    try ast.forEachChild(&ls.program.ast, fun, &visitor);

    if (keywords.items.len == 0) return null;
    return try keywords.toOwnedSlice();
}

fn getYieldOccurrences(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, node: ast.NodeIndex, fileId: compiler.FileId) !?[]ast.NodeIndex {
    _ = fileId;
    const parent = ls.program.ast.getParent(node);
    const fun = astnav.findAncestor(&ls.program.ast, parent, ast_utils.isFunctionLike);
    if (fun == 0) return null;

    var keywords = std.ArrayList(ast.NodeIndex).init(allocator);
    errdefer keywords.deinit();

    const Ctx = struct {
        t: *ast.Ast,
        arr: *std.ArrayList(ast.NodeIndex),
        fn cb(self: *@This(), n: ast.NodeIndex) anyerror!void {
            if (self.t.getNodeKind(n) == .YieldExpression) {
                try self.arr.append(n);
            }
        }
    };
    var ctx = Ctx{ .t = &ls.program.ast, .arr = &keywords };

    const Visitor = struct {
        t: *ast.Ast,
        c: *Ctx,
        pub fn visitNode(self: *@This(), n: ast.NodeIndex) anyerror!void {
            const closure = struct {
                fn run(cx: *Ctx, cn: ast.NodeIndex) !void {
                    try cx.cb(cn);
                }
            };
            try traverseWithoutCrossingFunction(self.t, n, self.c, closure.run);
        }
        pub fn visitList(self: *@This(), list: u32) anyerror!void {
            for (self.t.getNodeList(list)) |n| {
                try self.visitNode(n);
            }
        }
    };
    var visitor = Visitor{ .t = &ls.program.ast, .c = &ctx };
    try ast.forEachChild(&ls.program.ast, fun, &visitor);

    if (keywords.items.len == 0) return null;
    return try keywords.toOwnedSlice();
}

fn getModifierOccurrences(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, kind: std.meta.Tag(ast.NodeData), node: ast.NodeIndex, fileId: compiler.FileId) !?[]ast.NodeIndex {
    _ = fileId;
    var keywords = std.ArrayList(ast.NodeIndex).init(allocator);
    errdefer keywords.deinit();

    const container = ls.program.ast.getParent(node);
    if (container == 0) return null;

    var nodesToSearch = std.ArrayList(ast.NodeIndex).init(allocator);
    defer nodesToSearch.deinit();

    const parentKind = ls.program.ast.getNodeKind(container);
    switch (parentKind) {
        .ModuleBlock, .SourceFile, .Block, .CaseClause, .DefaultClause => {
            // we omit the abstract class modifier flag check for simplicity here
            // because DOD approach is mostly scanning modifiers.
            if (ls.program.ast.getNodeKind(node) == .ClassDeclaration) {
                try nodesToSearch.append(node);
                const members = ast_utils.getMembers(&ls.program.ast, node);
                if (members != 0) {
                    for (ls.program.ast.getNodeList(members)) |m| {
                        try nodesToSearch.append(m);
                    }
                }
            } else {
                const statements = ast_utils.getStatements(&ls.program.ast, container);
                if (statements != 0) {
                    for (ls.program.ast.getNodeList(statements)) |s| {
                        try nodesToSearch.append(s);
                    }
                }
            }
        },
        .Constructor, .MethodDeclaration, .FunctionDeclaration => {
            const params = ast_utils.getParameters(&ls.program.ast, container);
            if (params != 0) {
                for (ls.program.ast.getNodeList(params)) |p| {
                    try nodesToSearch.append(p);
                }
            }
            const grandParent = ls.program.ast.getParent(container);
            if (ast_utils.isClassLike(&ls.program.ast, grandParent)) {
                const members = ast_utils.getMembers(&ls.program.ast, grandParent);
                if (members != 0) {
                    for (ls.program.ast.getNodeList(members)) |m| {
                        try nodesToSearch.append(m);
                    }
                }
            }
        },
        .ClassDeclaration, .ClassExpression, .InterfaceDeclaration, .TypeLiteral => {
            const members = ast_utils.getMembers(&ls.program.ast, container);
            if (members != 0) {
                for (ls.program.ast.getNodeList(members)) |m| {
                    try nodesToSearch.append(m);
                    if (ls.program.ast.getNodeKind(m) == .Constructor) {
                        const params = ast_utils.getParameters(&ls.program.ast, m);
                        if (params != 0) {
                            for (ls.program.ast.getNodeList(params)) |p| {
                                try nodesToSearch.append(p);
                            }
                        }
                    }
                }
            }
            try nodesToSearch.append(container);
        },
        else => {},
    }

    for (nodesToSearch.items) |n| {
        const modifiersList = ast_utils.getModifiers(&ls.program.ast, n);
        if (modifiersList) |idx| {
            if (idx != 0) {
                for (ls.program.ast.getNodeList(idx)) |m| {
                    if (ls.program.ast.getNodeKind(m) == kind) {
                        try keywords.append(m);
                        break;
                    }
                }
            }
        }
    }

    if (keywords.items.len == 0) return null;
    return try keywords.toOwnedSlice();
}
