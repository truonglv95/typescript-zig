const std = @import("std");
const ast = @import("../ast/ast.zig");
const kind = @import("../ast/kind.zig");

pub const TextRangeWithKind = struct {
    loc: ast.TextRange,
    kind: kind.Kind,
};

pub fn newTextRangeWithKind(pos: u32, end: u32, k: kind.Kind) TextRangeWithKind {
    return TextRangeWithKind{
        .loc = .{ .pos = pos, .end = end },
        .kind = k,
    };
}

const core = @import("../core/core.zig");
const root_scanner = @import("../scanner/scanner.zig");
const textchange = @import("../core/textchange.zig");
const span = @import("span.zig");

pub const TokenInfo = struct {
    leadingTrivia: []TextRangeWithKind,
    token: TextRangeWithKind,
    trailingTrivia: []TextRangeWithKind,
};

pub const ScanAction = enum {
    Scan,
    RescanGreaterThanToken,
    RescanSlashToken,
    RescanTemplateToken,
    RescanJsxIdentifier,
    RescanJsxText,
    RescanJsxAttributeValue,
};

pub const FormattingScanner = struct {
    allocator: std.mem.Allocator,
    s: *root_scanner.Scanner,
    startPos: u32,
    endPos: u32,
    savedPos: u32 = 0,
    hasLastTokenInfo: bool = false,
    lastTokenInfo: TokenInfo = undefined,
    lastScanAction: ScanAction = .Scan,
    leadingTrivia: std.ArrayList(TextRangeWithKind),
    trailingTrivia: std.ArrayList(TextRangeWithKind),
    wasNewLine: bool = true,

    pub fn init(allocator: std.mem.Allocator, text: []const u8, languageVariant: core.LanguageVariant, startPos: u32, endPos: u32, worker: *span.FormatSpanWorker) ![]textchange.TextChange {
        var scan = root_scanner.Scanner.init(allocator, text);
        // Note: SetSkipTrivia/SetLanguageVariant are not on the Scanner API yet, might need to add them or handle them
        // scan.setSkipTrivia(false);
        // scan.setLanguageVariant(languageVariant);
        _ = languageVariant;
        scan.resetPos(startPos);

        var fmtScn = FormattingScanner{
            .allocator = allocator,
            .s = &scan,
            .startPos = startPos,
            .endPos = endPos,
            .leadingTrivia = .empty,
            .trailingTrivia = .empty,
            .wasNewLine = true,
        };

        const res = try worker.execute(&fmtScn);

        fmtScn.hasLastTokenInfo = false;
        scan.reset();
        return res;
    }

    pub fn advance(self: *FormattingScanner) !void {
        self.hasLastTokenInfo = false;
        const isStarted = self.s.getTokenFullStart() != self.startPos;

        if (isStarted) {
            self.wasNewLine = self.trailingTrivia.items.len > 0 and self.trailingTrivia.items[self.trailingTrivia.items.len - 1].kind == kind.Kind.NewLineTrivia;
        } else {
            _ = self.s.scan();
        }

        self.leadingTrivia.clearRetainingCapacity();
        self.trailingTrivia.clearRetainingCapacity();

        var pos: u32 = @intCast(self.s.getTokenFullStart());

        while (pos < self.endPos) {
            const t = self.s.getToken();
            if (!kind.isTrivia(t)) {
                break;
            }

            _ = self.s.scan();
            const fullStart: u32 = @intCast(self.s.getTokenFullStart());
            const item = newTextRangeWithKind(pos, fullStart, t);
            pos = fullStart;

            try self.leadingTrivia.append(self.allocator, item);
        }

        self.savedPos = @intCast(self.s.getTokenFullStart());
    }

    pub fn shouldRescanGreaterThanToken(node: ast.NodeIndex, tree: *ast.Ast) bool {
        const k = tree.nodes.items(.kind)[node];
        return switch (k) {
            .GreaterThanEqualsToken,
            .GreaterThanGreaterThanEqualsToken,
            .GreaterThanGreaterThanGreaterThanEqualsToken,
            .GreaterThanGreaterThanGreaterThanToken,
            .GreaterThanGreaterThanToken => true,
            else => false,
        };
    }

    pub fn shouldRescanJsxIdentifier(node: ast.NodeIndex, tree: *ast.Ast) bool {
        const parent = tree.nodes.items(.parent)[node];
        if (parent != 0) {
            const pk = tree.nodes.items(.kind)[parent];
            switch (pk) {
                .JsxAttribute,
                .JsxOpeningElement,
                .JsxClosingElement,
                .JsxSelfClosingElement,
                .JsxNamespacedName => {
                    const k = tree.nodes.items(.kind)[node];
                    return kind.isKeyword(k) or k == .Identifier;
                },
                else => {},
            }
        }
        return false;
    }

    pub fn shouldRescanJsxText(self: *FormattingScanner, node: ast.NodeIndex, tree: *ast.Ast) bool {
        const k = tree.nodes.items(.kind)[node];
        if (k == .JsxText) return true;
        
        // IsJsxElement
        if (k != .JsxElement or !self.hasLastTokenInfo) {
            return false;
        }
        return self.lastTokenInfo.token.kind == .JsxText;
    }

    pub fn shouldRescanSlashToken(container: ast.NodeIndex, tree: *ast.Ast) bool {
        return tree.nodes.items(.kind)[container] == .RegularExpressionLiteral;
    }

    pub fn shouldRescanTemplateToken(container: ast.NodeIndex, tree: *ast.Ast) bool {
        const k = tree.nodes.items(.kind)[container];
        return k == .TemplateMiddle or k == .TemplateTail;
    }

    pub fn shouldRescanJsxAttributeValue(node: ast.NodeIndex, tree: *ast.Ast) bool {
        const parent = tree.nodes.items(.parent)[node];
        if (parent != 0 and tree.nodes.items(.kind)[parent] == .JsxAttribute) {
            // Need to check if it's the initializer
            // Simplification: In Zig ast, if it's JsxAttribute, its second child is initializer.
            // TODO: implement initializer check accurately if needed
            // For now assume true if it's a child of JsxAttribute and not the first child (the name).
            // (Assuming `initializer` property check)
            return true;
        }
        return false;
    }

    fn startsWithSlashToken(t: kind.Kind) bool {
        return t == .SlashToken or t == .SlashEqualsToken;
    }

    fn fixTokenKind(tokenInfoParam: TokenInfo, container: ast.NodeIndex, tree: *ast.Ast) TokenInfo {
        var tokenInfo = tokenInfoParam;
        const containerKind = tree.nodes.items(.kind)[container];
        if (kind.isToken(containerKind) and tokenInfo.token.kind != containerKind) {
            tokenInfo.token.kind = containerKind;
        }
        return tokenInfo;
    }

    pub fn readTokenInfo(self: *FormattingScanner, n: ast.NodeIndex, tree: *ast.Ast) !TokenInfo {
        std.debug.assert(self.isOnToken());

        var expectedScanAction: ScanAction = .Scan;
        if (shouldRescanGreaterThanToken(n, tree)) {
            expectedScanAction = .RescanGreaterThanToken;
        } else if (shouldRescanSlashToken(n, tree)) {
            expectedScanAction = .RescanSlashToken;
        } else if (shouldRescanTemplateToken(n, tree)) {
            expectedScanAction = .RescanTemplateToken;
        } else if (shouldRescanJsxIdentifier(n, tree)) {
            expectedScanAction = .RescanJsxIdentifier;
        } else if (self.shouldRescanJsxText(n, tree)) {
            expectedScanAction = .RescanJsxText;
        } else if (shouldRescanJsxAttributeValue(n, tree)) {
            expectedScanAction = .RescanJsxAttributeValue;
        }

        if (self.hasLastTokenInfo and expectedScanAction == self.lastScanAction) {
            self.lastTokenInfo = fixTokenKind(self.lastTokenInfo, n, tree);
            return self.lastTokenInfo;
        }

        if (self.s.getTokenFullStart() != self.savedPos) {
            self.s.resetPos(self.savedPos);
            _ = self.s.scan();
        }

        var currentToken = self.getNextToken(n, expectedScanAction, tree);

        const token = newTextRangeWithKind(
            @intCast(self.s.getTokenFullStart()),
            @intCast(self.s.getTokenEnd()),
            currentToken,
        );

        self.trailingTrivia.clearRetainingCapacity();
        while (self.s.getTokenFullStart() < self.endPos) {
            currentToken = self.s.scan();
            if (!kind.isTrivia(currentToken)) {
                break;
            }
            const trivia = newTextRangeWithKind(
                @intCast(self.s.getTokenFullStart()),
                @intCast(self.s.getTokenEnd()),
                currentToken,
            );

            try self.trailingTrivia.append(self.allocator, trivia);

            if (currentToken == .NewLineTrivia) {
                _ = self.s.scan();
                break;
            }
        }

        self.hasLastTokenInfo = true;
        
        // We must duplicate the slices for lastTokenInfo.
        // Actually, we can just allocate them or return them.
        // But since this struct owns the lists, it can't just slice them if it changes them later.
        // In Go, it cloned them. We must allocate slices.
        // Wait, creating allocations on every token is bad. Let's just return slices pointing to the ArrayLists.
        // Wait, `advance()` clears the ArrayLists. 
        // We should instead manage `lastTokenInfoLeadingTrivia` ArrayLists explicitly to avoid allocations.
        // For now, let's clone.
        const leadingClone = try self.allocator.dupe(TextRangeWithKind, self.leadingTrivia.items);
        const trailingClone = try self.allocator.dupe(TextRangeWithKind, self.trailingTrivia.items);
        
        self.lastTokenInfo = TokenInfo{
            .leadingTrivia = leadingClone,
            .token = token,
            .trailingTrivia = trailingClone,
        };
        self.lastTokenInfo = fixTokenKind(self.lastTokenInfo, n, tree);

        return self.lastTokenInfo;
    }

    pub fn getNextToken(self: *FormattingScanner, n: ast.NodeIndex, expectedScanAction: ScanAction, tree: *ast.Ast) kind.Kind {
        const token = self.s.getToken();
        self.lastScanAction = .Scan;
        switch (expectedScanAction) {
            .RescanGreaterThanToken => {
                if (token == .GreaterThanToken) {
                    self.lastScanAction = .RescanGreaterThanToken;
                    const newToken = self.s.reScanGreaterThanToken();
                    std.debug.assert(tree.nodes.items(.kind)[n] == newToken);
                    return newToken;
                }
            },
            .RescanSlashToken => {
                if (startsWithSlashToken(token)) {
                    self.lastScanAction = .RescanSlashToken;
                    const newToken = self.s.reScanSlashToken();
                    std.debug.assert(tree.nodes.items(.kind)[n] == newToken);
                    return newToken;
                }
            },
            .RescanTemplateToken => {
                if (token == .CloseBraceToken) {
                    self.lastScanAction = .RescanTemplateToken;
                    return self.s.reScanTemplateToken(false);
                }
            },
            .RescanJsxIdentifier => {
                self.lastScanAction = .RescanJsxIdentifier;
                // return self.s.scanJsxIdentifier();
                // TODO: scanJsxIdentifier is not in root_scanner yet? Let's just return token for now
                return token;
            },
            .RescanJsxText => {
                self.lastScanAction = .RescanJsxText;
                // return self.s.reScanJsxToken(false);
                return token;
            },
            .RescanJsxAttributeValue => {
                self.lastScanAction = .RescanJsxAttributeValue;
                // return self.s.reScanJsxAttributeValue();
                return token;
            },
            .Scan => {},
        }
        return token;
    }

    pub fn readEOFTokenRange(self: *FormattingScanner) TextRangeWithKind {
        std.debug.assert(self.isOnEOF());
        return newTextRangeWithKind(
            @intCast(self.s.getTokenFullStart()),
            @intCast(self.s.getTokenEnd()),
            .EndOfFile,
        );
    }

    pub fn isOnToken(self: *FormattingScanner) bool {
        var current = self.s.getToken();
        if (self.hasLastTokenInfo) {
            current = self.lastTokenInfo.token.kind;
        }
        return current != .EndOfFile and !kind.isTrivia(current);
    }

    pub fn isOnEOF(self: *FormattingScanner) bool {
        var current = self.s.getToken();
        if (self.hasLastTokenInfo) {
            current = self.lastTokenInfo.token.kind;
        }
        return current == .EndOfFile;
    }

    pub fn skipToEndOf(self: *FormattingScanner, r: *const ast.TextRange) void {
        self.s.resetPos(r.end);
        self.savedPos = @intCast(self.s.getTokenFullStart());
        self.lastScanAction = .Scan;
        self.hasLastTokenInfo = false;
        self.wasNewLine = false;
        self.leadingTrivia.clearRetainingCapacity();
        self.trailingTrivia.clearRetainingCapacity();
    }

    pub fn skipToStartOf(self: *FormattingScanner, r: *const ast.TextRange) void {
        self.s.resetPos(r.pos);
        self.savedPos = @intCast(self.s.getTokenFullStart());
        self.lastScanAction = .Scan;
        self.hasLastTokenInfo = false;
        self.wasNewLine = false;
        self.leadingTrivia.clearRetainingCapacity();
        self.trailingTrivia.clearRetainingCapacity();
    }

    pub fn getCurrentLeadingTrivia(self: *FormattingScanner) []const TextRangeWithKind {
        return self.leadingTrivia.items;
    }

    pub fn lastTrailingTriviaWasNewLine(self: *const FormattingScanner) bool {
        return self.wasNewLine;
    }

    pub fn getTokenFullStart(self: *FormattingScanner) u32 {
        if (self.hasLastTokenInfo) {
            return self.lastTokenInfo.token.loc.pos;
        }
        return @intCast(self.s.getTokenFullStart());
    }

    pub fn getStartPos(self: *FormattingScanner) u32 {
        return self.getTokenFullStart();
    }
};
