const std = @import("std");
const ast = @import("../ast/ast.zig");
const astnav = @import("../ast/ast_utils.zig");
const core = @import("../core/core.zig");
const lsutil = @import("../ls/lsutil/lsutil.zig");
const scanner = @import("scanner.zig");
const api = @import("api.zig");
const root_scanner = @import("../scanner/scanner.zig");

pub const FormattingContext = struct {
    currentTokenSpan: scanner.TextRangeWithKind = undefined,
    nextTokenSpan: scanner.TextRangeWithKind = undefined,
    contextNode: ast.NodeIndex = 0,
    currentTokenParent: ast.NodeIndex = 0,
    nextTokenParent: ast.NodeIndex = 0,

    contextNodeAllOnSameLine: core.Tristate = .Unknown,
    nextNodeAllOnSameLine: core.Tristate = .Unknown,
    tokensAreOnSameLine: core.Tristate = .Unknown,
    contextNodeBlockIsOnOneLine: core.Tristate = .Unknown,
    nextNodeBlockIsOnOneLine: core.Tristate = .Unknown,

    tree: *ast.Ast,
    formattingRequestKind: api.FormatRequestKind,
    options: lsutil.FormatCodeSettings,

    pub fn init(tree: *ast.Ast, kind: api.FormatRequestKind, options: lsutil.FormatCodeSettings) FormattingContext {
        return FormattingContext{
            .tree = tree,
            .formattingRequestKind = kind,
            .options = options,
        };
    }

    pub fn updateContext(self: *FormattingContext, cur: scanner.TextRangeWithKind, curParent: ast.NodeIndex, next: scanner.TextRangeWithKind, nextParent: ast.NodeIndex, commonParent: ast.NodeIndex) void {
        std.debug.assert(curParent != 0); // panic("nil current range node parent in update context")
        std.debug.assert(nextParent != 0); // panic("nil next range node parent in update context")
        std.debug.assert(commonParent != 0); // panic("nil common parent node in update context")
        
        self.currentTokenSpan = cur;
        self.currentTokenParent = curParent;
        self.nextTokenSpan = next;
        self.nextTokenParent = nextParent;
        self.contextNode = commonParent;

        // drop cached results
        self.contextNodeAllOnSameLine = .Unknown;
        self.nextNodeAllOnSameLine = .Unknown;
        self.tokensAreOnSameLine = .Unknown;
        self.contextNodeBlockIsOnOneLine = .Unknown;
        self.nextNodeBlockIsOnOneLine = .Unknown;
    }

    fn rangeIsOnOneLine(self: *FormattingContext, r: ast.TextRange) core.Tristate {
        // rangeIsOnOneLine is implemented in util.zig, which we will use here
        // For now, let's call util.rangeIsOnOneLine(r, self.tree)
        const util = @import("util.zig");
        if (util.rangeIsOnOneLine(r, self.tree)) {
            return .True;
        }
        return .False;
    }

    fn nodeIsOnOneLine(self: *FormattingContext, node: ast.NodeIndex) core.Tristate {
        return self.rangeIsOnOneLine(withTokenStart(node, self.tree));
    }

    fn blockIsOnOneLine(self: *FormattingContext, node: ast.NodeIndex) core.Tristate {
        const util = @import("util.zig");
        const openBrace = util.findChildOfKind(node, .OpenBraceToken, self.tree);
        const closeBrace = util.findChildOfKind(node, .CloseBraceToken, self.tree);
        if (openBrace != 0 and closeBrace != 0) {
            const closeBraceStart = self.tree.positions.items[closeBrace].pos;
            return self.rangeIsOnOneLine(.{ .pos = self.tree.positions.items[openBrace].end, .end = closeBraceStart });
        }
        return .False;
    }

    pub fn isContextNodeAllOnSameLine(self: *FormattingContext) bool {
        if (self.contextNodeAllOnSameLine == .Unknown) {
            self.contextNodeAllOnSameLine = self.nodeIsOnOneLine(self.contextNode);
        }
        return self.contextNodeAllOnSameLine == .True;
    }

    pub fn isNextNodeAllOnSameLine(self: *FormattingContext) bool {
        if (self.nextNodeAllOnSameLine == .Unknown) {
            self.nextNodeAllOnSameLine = self.nodeIsOnOneLine(self.nextTokenParent);
        }
        return self.nextNodeAllOnSameLine == .True;
    }

    pub fn isTokensAreOnSameLine(self: *FormattingContext) bool {
        if (self.tokensAreOnSameLine == .Unknown) {
            self.tokensAreOnSameLine = self.rangeIsOnOneLine(.{ .pos = self.currentTokenSpan.loc.pos, .end = self.nextTokenSpan.loc.end });
        }
        return self.tokensAreOnSameLine == .True;
    }

    pub fn isContextNodeBlockIsOnOneLine(self: *FormattingContext) bool {
        if (self.contextNodeBlockIsOnOneLine == .Unknown) {
            self.contextNodeBlockIsOnOneLine = self.blockIsOnOneLine(self.contextNode);
        }
        return self.contextNodeBlockIsOnOneLine == .True;
    }

    pub fn isNextNodeBlockIsOnOneLine(self: *FormattingContext) bool {
        if (self.nextNodeBlockIsOnOneLine == .Unknown) {
            self.nextNodeBlockIsOnOneLine = self.blockIsOnOneLine(self.nextTokenParent);
        }
        return self.nextNodeBlockIsOnOneLine == .True;
    }
};

fn withTokenStart(node: ast.NodeIndex, tree: *ast.Ast) ast.TextRange {
    const startPos = tree.positions.items[node].pos;
    return .{ .pos = startPos, .end = tree.positions.items[node].end };
}
