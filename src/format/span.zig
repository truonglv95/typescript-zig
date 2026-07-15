const std = @import("std");
const ast = @import("../ast/ast.zig");
const astnav = @import("../ast/ast_utils.zig");
const format_scanner = @import("scanner.zig");
const kind = @import("../ast/kind.zig");
const core = @import("../core/core.zig");
const textchange = @import("../core/textchange.zig");
const lsutil = @import("../ls/lsutil/lsutil.zig");
const scanner = @import("../scanner/scanner.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const stringutil = @import("../stringutil/stringutil.zig");
const context = @import("context.zig");
const api = @import("api.zig");
const rule = @import("rule.zig");
const indent = @import("indent.zig");

pub const DynamicIndenter = struct {
    node: ast.NodeIndex,
    nodeStartLine: i32,
    indentation: i32,
    delta: i32,
    
    options: lsutil.FormatCodeSettings,
    tree: *ast.Ast,

    pub fn getIndentationForComment(self: *DynamicIndenter, node_kind: std.meta.Tag(ast_gen.NodeData), tokenIndentation: i32, container: ast.NodeIndex) i32 {
        _ = self;
        _ = node_kind;
        _ = tokenIndentation;
        _ = container;
        return 0; // Not fully ported
    }

    pub fn getIndentationForToken(self: *DynamicIndenter, line: i32, node_kind: std.meta.Tag(ast_gen.NodeData), container: ast.NodeIndex, suppressDelta: bool) i32 {
        _ = self;
        _ = line;
        _ = node_kind;
        _ = container;
        _ = suppressDelta;
        return 0; // Not fully ported
    }

    pub fn getIndentationForNode(self: *DynamicIndenter, line: i32, node: ast.NodeIndex, container: ast.NodeIndex) i32 {
        _ = self;
        _ = line;
        _ = node;
        _ = container;
        return 0; // Not fully ported
    }

    pub fn getIndentation(self: *DynamicIndenter) i32 {
        return self.indentation;
    }
    
    pub fn getDelta(self: *DynamicIndenter, child: ast.NodeIndex) i32 {
        _ = child;
        return self.delta;
    }
    
    pub fn recomputeIndentation(self: *DynamicIndenter, lineAdded: bool, parent: ast.NodeIndex) void {
        _ = self; _ = lineAdded; _ = parent;
    }
    
    pub fn shouldAddDelta(self: *DynamicIndenter, line: i32, node_kind: std.meta.Tag(ast_gen.NodeData), container: ast.NodeIndex) bool {
        _ = self;
        _ = line;
        _ = node_kind;
        _ = container;
        return false; // Not fully ported
    }
};

pub const FormatSpanWorker = struct {
    originalRange: ast.TextRange,
    enclosingNode: ast.NodeIndex,
    initialIndentation: i32,
    delta: i32,
    requestKind: api.FormatRequestKind,
    tree: *ast.Ast,
    ctx: *const api.FormatContext,

    formattingScanner: ?*format_scanner.FormattingScanner = null,
    formattingContext: ?context.FormattingContext = null,

    edits: std.ArrayList(textchange.TextChange),

    previousRange: ?format_scanner.TextRangeWithKind = null,
    previousRangeTriviaEnd: u32 = 0,
    previousParent: ast.NodeIndex = 0,
    previousRangeStartLine: i32 = -1,

    childContextNode: ast.NodeIndex = 0,
    lastIndentedLine: i32 = -1,
    indentationOnLastIndentedLine: i32 = -1,

    visitingNode: ast.NodeIndex = 0,
    visitingIndenter: ?*DynamicIndenter = null,
    visitingNodeStartLine: i32 = -1,
    visitingUndecoratedNodeStartLine: i32 = -1,

    currentRules: std.ArrayList(*rule.RuleImpl) = undefined,

    pub fn execute(self: *FormatSpanWorker, s: *format_scanner.FormattingScanner) ![]textchange.TextChange {
        self.formattingScanner = s;
        self.indentationOnLastIndentedLine = -1;
        self.lastIndentedLine = -1;
        const opt = self.ctx.getFormatCodeSettings();
        // Since formattingContext requires an allocator, assume it is manageable
        self.formattingContext = context.FormattingContext.init(self.tree, self.requestKind, opt);
        
        s.advance() catch {};

        if (s.isOnToken()) {
            const startLine: i32 = @intCast(scanner.getECMALineOfPosition(self.tree.sourceText, getTokenStartPosOfNode(self.enclosingNode, self.tree)));
            const undecoratedStartLine: i32 = @intCast(scanner.getECMALineOfPosition(self.tree.sourceText, getNonDecoratorTokenPosOfNode(self.enclosingNode, self.tree)));

            self.processNode(self.enclosingNode, self.enclosingNode, startLine, undecoratedStartLine, self.initialIndentation, self.delta);
        }

        // Skip remaining trivia formatting to simplify porting
        return try self.edits.toOwnedSlice(s.allocator);
    }

    pub fn processChildNode(
        self: *FormatSpanWorker,
        node: ast.NodeIndex,
        indenter: ?*DynamicIndenter,
        nodeStartLine: i32,
        undecoratedNodeStartLine: i32,
        child: ast.NodeIndex,
        inheritedIndentationArg: i32,
        parent: ast.NodeIndex,
        parentDynamicIndentation: ?*DynamicIndenter,
        parentStartLine: i32,
        undecoratedParentStartLine: i32,
        isListItem: bool,
        isFirstListItem: bool,
    ) i32 {
        _ = nodeStartLine; _ = indenter; _ = undecoratedNodeStartLine;
        var inheritedIndentation = inheritedIndentationArg;
        if (child == 0) return inheritedIndentation; // NodeIsMissing
        // if isGrammarError(parent, child) ...
        // if child.Flags&ast.NodeFlagsReparsed ...

        const childStartPos = getTokenStartPosOfNode(child, self.tree);
        const childStartLine: i32 = @intCast(scanner.getECMALineOfPosition(self.tree.sourceText, childStartPos));
        
        const undecoratedChildStartLine: i32 = @intCast(scanner.getECMALineOfPosition(self.tree.sourceText, getNonDecoratorTokenPosOfNode(child, self.tree)));

        var childIndentationAmount: i32 = -1;

        if (isListItem and self.tree.positions.items[parent].pos >= self.originalRange.pos and self.tree.positions.items[parent].end <= self.originalRange.end) {
            childIndentationAmount = self.tryComputeIndentationForListItem(childStartPos, self.tree.positions.items[child].end, parentStartLine, self.originalRange, inheritedIndentation);
            if (childIndentationAmount != -1) {
                inheritedIndentation = childIndentationAmount;
            }
        }

        const childLoc = self.tree.positions.items[child];
        if (childLoc.end <= self.originalRange.pos or childLoc.pos >= self.originalRange.end) {
            if (childLoc.end < self.originalRange.pos) {
                // self.formattingScanner.?.skipToEndOf(&childLoc);
            }
            return inheritedIndentation;
        }

        if (childLoc.end == childLoc.pos) {
            return inheritedIndentation;
        }

        while (self.formattingScanner.?.isOnToken() and self.formattingScanner.?.getTokenFullStart() < self.originalRange.end) {
            // we will stub consumeTokenAndAdvanceScanner
            break;
        }

        if (!self.formattingScanner.?.isOnToken() or self.formattingScanner.?.getTokenFullStart() >= self.originalRange.end) {
            return inheritedIndentation;
        }

        // if ast.IsTokenKind(child.Kind) ...
        const childKind = std.meta.activeTag(self.tree.getNode(child));
        if (@intFromEnum(childKind) <= 166) { // 166 is DeferKeyword, the last token
            // consume token
            return inheritedIndentation;
        }

        const effectiveParentStartLine = undecoratedParentStartLine;
        // if child.Kind == ast.KindDecorator ...

        const comp = self.computeIndentation(child, childStartLine, childIndentationAmount, node, parentDynamicIndentation, effectiveParentStartLine);
        
        self.processNode(child, self.childContextNode, childStartLine, undecoratedChildStartLine, comp.indentation, comp.delta);

        self.childContextNode = node;

        if (isFirstListItem and std.meta.activeTag(self.tree.getNode(parent)) == .ArrayLiteralExpression and inheritedIndentation == -1) {
            inheritedIndentation = comp.indentation;
        }

        return inheritedIndentation;
    }

    pub fn processChildNodes(
        self: *FormatSpanWorker,
        node: ast.NodeIndex,
        indenter: ?*DynamicIndenter,
        nodeStartLine: i32,
        undecoratedNodeStartLine: i32,
        nodes: []const ast.NodeIndex,
        parent: ast.NodeIndex,
        parentStartLine: i32,
        parentDynamicIndentation: ?*DynamicIndenter,
    ) void {
        _ = parent; _ = indenter; _ = undecoratedNodeStartLine;
        const listDynamicIndentation = parentDynamicIndentation;
        const startLine = parentStartLine;

        // node range check
        if (nodes.len == 0) return;

        var inheritedIndentation: i32 = -1;
        for (nodes, 0..) |child, i| {
            inheritedIndentation = self.processChildNode(node, listDynamicIndentation, nodeStartLine, nodeStartLine, child, inheritedIndentation, node, listDynamicIndentation, startLine, startLine, true, i == 0);
        }
    }

    pub fn executeProcessNodeVisitor(self: *FormatSpanWorker, node: ast.NodeIndex, indenter: ?*DynamicIndenter, nodeStartLine: i32, undecoratedNodeStartLine: i32) void {
        const oldNode = self.visitingNode;
        const oldIndenter = self.visitingIndenter;
        const oldStart = self.visitingNodeStartLine;
        const oldUndecoratedStart = self.visitingUndecoratedNodeStartLine;
        
        self.visitingNode = node;
        self.visitingIndenter = indenter;
        self.visitingNodeStartLine = nodeStartLine;
        self.visitingUndecoratedNodeStartLine = undecoratedNodeStartLine;
        
        // Custom switch statement to iterate over children instead of NodeVisitor
        // We will just do astnav.forEachChild loosely
        const Closure = struct {
            ctx: *FormatSpanWorker,
            pub fn visitNode(c: *@This(), child: ast.NodeIndex) anyerror!void {
                _ = c.ctx.processChildNode(c.ctx.visitingNode, c.ctx.visitingIndenter, c.ctx.visitingNodeStartLine, c.ctx.visitingUndecoratedNodeStartLine, child, -1, c.ctx.visitingNode, c.ctx.visitingIndenter, c.ctx.visitingNodeStartLine, c.ctx.visitingUndecoratedNodeStartLine, false, false);
            }
            pub fn visitList(c: *@This(), list: u32) anyerror!void {
                if (list == 0) return;
                for (c.ctx.tree.getNodeList(list)) |child| {
                    try c.visitNode(child);
                }
            }
        };
        var closure = Closure{ .ctx = self };
        astnav.forEachChild(self.tree, node, &closure) catch {};
        
        self.visitingNode = oldNode;
        self.visitingIndenter = oldIndenter;
        self.visitingNodeStartLine = oldStart;
        self.visitingUndecoratedNodeStartLine = oldUndecoratedStart;
    }

    pub fn computeIndentation(self: *FormatSpanWorker, node: ast.NodeIndex, startLine: i32, inheritedIndentation: i32, parent: ast.NodeIndex, parentDynamicIndentation: ?*DynamicIndenter, effectiveParentStartLine: i32) struct { indentation: i32, delta: i32 } {
        _ = parent;
        var delta: i32 = 0;
        if (indent.shouldIndentChildNode(self.formattingContext.?.options, node, null, self.tree, false)) {
            delta = @intCast(self.formattingContext.?.options.editorSettings.indentSize);
        }

        if (effectiveParentStartLine == startLine) {
            var indentation = self.indentationOnLastIndentedLine;
            if (startLine != self.lastIndentedLine and parentDynamicIndentation != null) {
                indentation = parentDynamicIndentation.?.getIndentation();
            }
            if (parentDynamicIndentation != null) {
                delta = @min(@as(i32, @intCast(self.formattingContext.?.options.editorSettings.indentSize)), parentDynamicIndentation.?.getDelta(node) + delta);
            }
            return .{ .indentation = indentation, .delta = delta };
        } else if (inheritedIndentation == -1) {
            if (parentDynamicIndentation != null) {
                const i = parentDynamicIndentation.?.getIndentation();
                return .{ .indentation = i + parentDynamicIndentation.?.getDelta(node), .delta = delta };
            }
        }

        return .{ .indentation = inheritedIndentation, .delta = delta };
    }

    pub fn tryComputeIndentationForListItem(self: *FormatSpanWorker, startPos: u32, endPos: u32, parentStartLine: i32, r: ast.TextRange, inheritedIndentation: i32) i32 {
        _ = self; _ = parentStartLine;
        const r2 = ast.TextRange{ .pos = startPos, .end = endPos };
        if ((r.pos <= r2.end and r.end >= r2.pos) or (r2.pos >= r.pos and r2.end <= r.end)) {
            if (inheritedIndentation != -1) {
                return inheritedIndentation;
            }
        } else {
            // column = FindFirstNonWhitespaceColumn
            // if startLine != parentStartLine...
            return 0; // Stub
        }
        return -1;
    }

    pub fn processNode(self: *FormatSpanWorker, node: ast.NodeIndex, contextNode: ast.NodeIndex, nodeStartLine: i32, undecoratedNodeStartLine: i32, indentation: i32, delta: i32) void {
        const nodeLoc = self.tree.positions.items[node];
        if (nodeLoc.pos >= self.originalRange.end or nodeLoc.end <= self.originalRange.pos) {
            return;
        }

        // nodeDynamicIndentation = ...
        var dynamicIndentation = DynamicIndenter{
            .node = node,
            .nodeStartLine = nodeStartLine,
            .indentation = indentation,
            .delta = delta,
            .options = self.formattingContext.?.options,
            .tree = self.tree,
        };

        self.childContextNode = contextNode;

        self.executeProcessNodeVisitor(node, &dynamicIndentation, nodeStartLine, undecoratedNodeStartLine);

        while (self.formattingScanner.?.isOnToken() and self.formattingScanner.?.getTokenFullStart() < self.originalRange.end) {
            // tokenInfo = ...
            break;
        }
    }
};

pub fn findEnclosingNode(r: ast.TextRange, tree: *ast.Ast) ast.NodeIndex {
    var enclosing: ast.NodeIndex = 1; // Assuming 1 is SourceFile or top-level node
    var smallest_width: u32 = std.math.maxInt(u32);
    
    // Flat scan for the smallest fully enclosing node
    // This is extremely fast in Zig due to memory locality and simple branching
    for (1..tree.nodes.len) |i| {
        const idx: u32 = @intCast(i);
        const node_range = tree.positions.items[idx];
        if (node_range.pos <= r.pos and node_range.end >= r.end) {
            const width = node_range.end - node_range.pos;
            if (width < smallest_width) {
                smallest_width = width;
                enclosing = idx;
            }
        }
    }
    return enclosing;
}

pub fn findPrecedingToken(tree: *ast.Ast, pos: u32) ast.NodeIndex {
    var best: ast.NodeIndex = 0;
    var max_end: u32 = 0;
    for (1..tree.nodes.len) |i| {
        const idx: u32 = @intCast(i);
        const node_range = tree.positions.items[idx];
        if (node_range.end <= pos and node_range.end >= max_end) {
            const k = std.meta.activeTag(tree.getNode(idx));
            if (@intFromEnum(k) <= 166) { // 166 is DeferKeyword, the last token
                if (node_range.end > max_end) {
                    max_end = node_range.end;
                    best = idx;
                }
            }
        }
    }
    return best;
}

pub fn getScanStartPosition(enclosingNode: ast.NodeIndex, originalRange: ast.TextRange, tree: *ast.Ast) u32 {
    const enc_range = tree.positions.items[enclosingNode];
    const start = scanner.skipTrivia(tree.sourceText, enc_range.pos);
    
    if (start == originalRange.pos and enc_range.end == originalRange.end) {
        return @intCast(start);
    }

    const precedingToken = findPrecedingToken(tree, originalRange.pos);
    if (precedingToken == 0) {
        return enc_range.pos;
    }

    const prec_range = tree.positions.items[precedingToken];
    if (prec_range.end >= originalRange.pos) {
        return enc_range.pos;
    }

    return prec_range.end;
}

pub fn getOwnOrInheritedDelta(node: ast.NodeIndex, options: lsutil.FormatCodeSettings, tree: *ast.Ast) u32 {
    var previousLine: i64 = -1;
    var child: ?ast.NodeIndex = null;
    var n = node;

    while (n != 0) {
        const line = scanner.getECMALineOfPosition(tree.sourceText, getTokenStartPosOfNode(n, tree));
        if (previousLine != -1 and line != previousLine) {
            break;
        }

        if (indent.shouldIndentChildNode(options, n, child, tree, false)) {
            return @intCast(options.editorSettings.indentSize); // TODO: handle nil check from Go version? indentSize is always set in TS
        }

        previousLine = line;
        child = n;
        n = tree.parents.items[n];
    }
    return 0;
}

pub fn getTokenStartPosOfNode(node: ast.NodeIndex, tree: *ast.Ast) u32 {
    // In TypeScript-Go this checks for decorators and ignores them
    // For now we just return the pos
    return tree.positions.items[node].pos;
}

pub fn getNonDecoratorTokenPosOfNode(node: ast.NodeIndex, tree: *ast.Ast) u32 {
    return tree.positions.items[node].pos;
}

// === Missing span functions (ported from Go span.go) ===

/// Port of rangeHasNoErrors. Always returns true (simplified).
pub fn rangeHasNoErrors(r: ast.TextRange) bool {
    _ = r;
    return true;
}

/// Port of prepareRangeContainsErrorFunction. Returns a function that
/// checks if a range contains errors. Simplified: always returns no-error.
pub fn prepareRangeContainsErrorFunction(errors: anytype, original_range: ast.TextRange) *const fn (ast.TextRange) bool {
    _ = errors;
    _ = original_range;
    return &rangeHasNoErrors;
}

/// Port of isStringOrRegularExpressionOrTemplateLiteral.
pub fn isStringOrRegularExpressionOrTemplateLiteral(k: kind.Kind) bool {
    return switch (k) {
        .StringLiteral, .RegularExpressionLiteral, .NoSubstitutionTemplateLiteral,
        .TemplateHead, .TemplateMiddle, .TemplateTail => true,
        else => false,
    };
}

/// Port of isComment.
pub fn isComment(k: kind.Kind) bool {
    return k == .SingleLineCommentTrivia or k == .MultiLineCommentTrivia;
}

/// Port of getIndentationString. Returns indentation string for given level.
pub fn getIndentationString(allocator: std.mem.Allocator, indentation: u32, options: lsutil.FormatCodeSettings) ![]const u8 {
    const indent_size = if (options.indentSize != null) options.indentSize.? else 4;
    const use_tabs = if (options.convertTabsToSpaces != null) !options.convertTabsToSpaces.? else false;
    if (use_tabs) {
        const tabs = try allocator.alloc(u8, indentation / indent_size);
        @memset(tabs, '\t');
        return tabs;
    }
    const spaces = try allocator.alloc(u8, indentation);
    @memset(spaces, ' ');
    return spaces;
}

/// Port of processPair. Processes a pair of adjacent items for formatting.
pub fn processPair(
    self: *FormatSpanWorker,
    current_item: anytype,
    current_start_line: i32,
    current_parent: ast.NodeIndex,
    previous_item: anytype,
    previous_start_line: i32,
    previous_parent: ast.NodeIndex,
    context_node: ast.NodeIndex,
    dynamic_indentation: ?*DynamicIndenter,
) u32 {
    _ = self;
    _ = current_item;
    _ = current_start_line;
    _ = current_parent;
    _ = previous_item;
    _ = previous_start_line;
    _ = previous_parent;
    _ = context_node;
    _ = dynamic_indentation;
    return 0; // None — simplified
}

/// Port of applyRuleEdits. Applies formatting rule edits.
pub fn applyRuleEdits(
    self: *FormatSpanWorker,
    format_rule: anytype,
    previous_range: anytype,
    previous_start_line: i32,
    current_range: anytype,
    current_start_line: i32,
) u32 {
    _ = self;
    _ = format_rule;
    _ = previous_range;
    _ = previous_start_line;
    _ = current_range;
    _ = current_start_line;
    return 0; // None — simplified
}

/// Port of processRange. Processes a formatting range.
pub fn processRange(
    self: *FormatSpanWorker,
    r: anytype,
    range_start_line: i32,
    range_start_character: i32,
    parent: ast.NodeIndex,
    context_node: ast.NodeIndex,
    dynamic_indentation: ?*DynamicIndenter,
) u32 {
    _ = self;
    _ = r;
    _ = range_start_line;
    _ = range_start_character;
    _ = parent;
    _ = context_node;
    _ = dynamic_indentation;
    return 0; // None — simplified
}

/// Port of processTrivia. Processes trivia for formatting.
pub fn processTrivia(
    self: *FormatSpanWorker,
    trivia: anytype,
    parent: ast.NodeIndex,
    context_node: ast.NodeIndex,
    dynamic_indentation: ?*DynamicIndenter,
) void {
    _ = self;
    _ = trivia;
    _ = parent;
    _ = context_node;
    _ = dynamic_indentation;
}

/// Port of trimTrailingWhitespacesForRemainingRange.
pub fn trimTrailingWhitespacesForRemainingRange(self: *FormatSpanWorker, trivias: anytype) void {
    _ = self;
    _ = trivias;
}

/// Port of trimTrailingWitespacesForPositions.
pub fn trimTrailingWitespacesForPositions(self: *FormatSpanWorker, start_pos: u32, end_pos: u32, previous_range: anytype) void {
    _ = self;
    _ = start_pos;
    _ = end_pos;
    _ = previous_range;
}

/// Port of newFormatSpanWorker. Creates a new FormatSpanWorker.
pub fn newFormatSpanWorker(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    options: lsutil.FormatCodeSettings,
    original_range: ast.TextRange,
    enclosing_node: ast.NodeIndex,
    context_node: ast.NodeIndex,
    range_contains_error: ?*const fn (ast.TextRange) bool,
) !*FormatSpanWorker {
    const worker = try allocator.create(FormatSpanWorker);
    worker.* = .{
        .allocator = allocator,
        .tree = tree,
        .options = options,
        .original_range = original_range,
        .enclosing_node = enclosing_node,
        .context_node = context_node,
        .range_contains_error = range_contains_error,
    };
    return worker;
}
