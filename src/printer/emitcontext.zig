const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const NodeFactory = @import("factory.zig").NodeFactory;
const AutoGenerateOptions = @import("factory.zig").AutoGenerateOptions;
const GeneratedIdentifierFlags = @import("factory.zig").GeneratedIdentifierFlags;
const NodeVisitor = @import("../ast/visitor.zig").NodeVisitor;
const NodeVisitorHooks = @import("../ast/visitor.zig").NodeVisitorHooks;
const EmitFlags = @import("emitflags.zig").EmitFlags;
const helpers_mod = @import("helpers.zig");

pub const EnvironmentFlags = struct {
    pub const None: u32 = 0;
    pub const InParameters: u32 = 1 << 0;
    pub const VariablesHoistedInParameters: u32 = 1 << 1;
};

pub const VarScope = struct {
    variables: std.ArrayListUnmanaged(ast.NodeIndex) = .empty,
    functions: std.ArrayListUnmanaged(ast.NodeIndex) = .empty,
    flags: u32 = 0,
    initializationStatements: std.ArrayListUnmanaged(ast.NodeIndex) = .empty,

    pub fn deinit(self: *VarScope, allocator: std.mem.Allocator) void {
        self.variables.deinit(allocator);
        self.functions.deinit(allocator);
        self.initializationStatements.deinit(allocator);
    }
};

pub const TextRange = struct {
    pos: isize = -1,
    end: isize = -1,
};

pub const EmitNodeFlags = struct {
    pub const None: u32 = 0;
    pub const HasCommentRange: u32 = 1 << 0;
    pub const HasSourceMapRange: u32 = 1 << 1;
};

pub const SynthesizedComment = struct {
    kind: u32,
    loc: TextRange = .{},
    hasLeadingNewLine: bool = false,
    hasTrailingNewLine: bool = false,
    text: []const u8,
};

pub const AutoGenerateId = u32;

pub const AutoGenerateInfo = struct {
    flags: u32 = 0,
    id: AutoGenerateId = 0,
    prefix: []const u8 = "",
    suffix: []const u8 = "",
    node: ast.NodeIndex = 0,
};

pub const EmitNode = struct {
    flags: u32 = 0,
    emitFlags: u32 = 0,
    commentRange: TextRange = .{},
    sourceMapRange: TextRange = .{},
    leadingComments: std.ArrayListUnmanaged(SynthesizedComment) = .empty,
    trailingComments: std.ArrayListUnmanaged(SynthesizedComment) = .empty,
    externalHelpersModuleName: ast.NodeIndex = 0,
    helpers: ?std.ArrayListUnmanaged(*const helpers_mod.EmitHelper) = null,
};

pub const EmitContext = struct {
    pub fn addVariableDeclaration(self: *EmitContext, name: ast.NodeIndex) void {
        const varDecl = self.factory.newVariableDeclaration(name, 0, 0, 0);
        self.setEmitFlags(varDecl, EmitFlags.NoNestedSourceMaps) catch unreachable;
        if (self.varScopeStack.items.len > 0) {
            const scope = self.varScopeStack.items[self.varScopeStack.items.len - 1];
            scope.variables.append(self.allocator, varDecl) catch unreachable;
        }
    }

    pub fn mostOriginal(self: *EmitContext, node: ast.NodeIndex) ast.NodeIndex {
        if (node == 0) return 0;
        var current = node;
        while (true) {
            const orig = self.getOriginal(current);
            if (orig == 0) break;
            current = orig;
        }
        return current;
    }

    pub fn isCallToHelper(self: *EmitContext, a: anytype, b: anytype) bool {
        _ = self;
        _ = a;
        _ = b;
        return false;
    }

    pub fn requestEmitHelper(self: *EmitContext, helper: *const helpers_mod.EmitHelper) void {
        for (self.emitHelpers.items) |h| {
            if (std.mem.eql(u8, h.name, helper.name)) return;
        }
        self.emitHelpers.append(self.allocator, helper) catch unreachable;
        for (helper.dependencies) |dep| {
            self.requestEmitHelper(dep);
        }
    }

    pub fn readEmitHelpers(self: *EmitContext) ?[]const *const helpers_mod.EmitHelper {
        if (self.emitHelpers.items.len == 0) return null;
        const helpers_slice = self.allocator.dupe(*const helpers_mod.EmitHelper, self.emitHelpers.items) catch unreachable;
        self.emitHelpers.clearRetainingCapacity();
        return helpers_slice;
    }

    pub fn addEmitHelpers(self: *EmitContext, nodeIndex: ast.NodeIndex, helpers_list: ?[]const *const helpers_mod.EmitHelper) void {
        const h_list = helpers_list orelse return;
        var gop = self.emitNodes.getOrPut(self.allocator, nodeIndex) catch unreachable;
        if (!gop.found_existing) {
            gop.value_ptr.* = .{};
        }
        if (gop.value_ptr.helpers == null) {
            gop.value_ptr.helpers = std.ArrayListUnmanaged(*const helpers_mod.EmitHelper).empty;
        }
        for (h_list) |helper| {
            var found = false;
            for (gop.value_ptr.helpers.?.items) |existing| {
                if (std.mem.eql(u8, existing.name, helper.name)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                gop.value_ptr.helpers.?.append(self.allocator, helper) catch unreachable;
            }
        }
    }

    pub fn getEmitHelpers(self: *EmitContext, nodeIndex: ast.NodeIndex) ?[]const *const helpers_mod.EmitHelper {
        const emitNode = self.emitNodes.get(nodeIndex) orelse return null;
        if (emitNode.helpers) |h| {
            return h.items;
        }
        return null;
    }

    pub fn endAndMergeVariableEnvironment(self: *EmitContext, statements: []const ast_gen.NodeIndex) []const ast_gen.NodeIndex {
        const declarations = self.endVariableEnvironment() catch unreachable;
        return self.mergeEnvironment(statements, declarations.items);
    }

    pub fn mergeEnvironment(self: *EmitContext, statements: []const ast_gen.NodeIndex, declarations: []const ast_gen.NodeIndex) []const ast_gen.NodeIndex {
        if (declarations.len == 0) {
            return statements;
        }

        const ast_utils = @import("../ast/ast_utils.zig");

        const leftStandardPrologueEnd = findSpanEnd(self.tree, statements, ast_utils.isPrologueDirective, 0);
        const leftHoistedFunctionsEnd = self.findSpanEndWithEmitContext(statements, isHoistedFunction, leftStandardPrologueEnd);
        const leftHoistedVariablesEnd = self.findSpanEndWithEmitContext(statements, isHoistedVariableStatement, leftHoistedFunctionsEnd);

        const rightStandardPrologueEnd = findSpanEnd(self.tree, declarations, ast_utils.isPrologueDirective, 0);
        const rightHoistedFunctionsEnd = self.findSpanEndWithEmitContext(declarations, isHoistedFunction, rightStandardPrologueEnd);
        const rightHoistedVariablesEnd = self.findSpanEndWithEmitContext(declarations, isHoistedVariableStatement, rightHoistedFunctionsEnd);
        const rightCustomPrologueEnd = self.findSpanEndWithEmitContext(declarations, isCustomPrologue, rightHoistedVariablesEnd);

        if (rightCustomPrologueEnd != declarations.len) {
            std.debug.panic("Expected declarations to be valid standard or custom prologues", .{});
        }

        var left = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        left.appendSlice(self.allocator, statements) catch unreachable;

        if (rightCustomPrologueEnd > rightHoistedVariablesEnd) {
            left.insertSlice(self.allocator, leftHoistedVariablesEnd, declarations[rightHoistedVariablesEnd..rightCustomPrologueEnd]) catch unreachable;
        }

        if (rightHoistedVariablesEnd > rightHoistedFunctionsEnd) {
            left.insertSlice(self.allocator, leftHoistedFunctionsEnd, declarations[rightHoistedFunctionsEnd..rightHoistedVariablesEnd]) catch unreachable;
        }

        if (rightHoistedFunctionsEnd > rightStandardPrologueEnd) {
            left.insertSlice(self.allocator, leftStandardPrologueEnd, declarations[rightStandardPrologueEnd..rightHoistedFunctionsEnd]) catch unreachable;
        }

        if (rightStandardPrologueEnd > 0) {
            if (leftStandardPrologueEnd == 0) {
                left.insertSlice(self.allocator, 0, declarations[0..rightStandardPrologueEnd]) catch unreachable;
            } else {
                var leftPrologues = std.StringHashMap(void).init(self.allocator);
                defer leftPrologues.deinit();

                for (statements[0..leftStandardPrologueEnd]) |leftPrologue| {
                    const text = self.tree.getNode(leftPrologue).ExpressionStatement.Expression;
                    leftPrologues.put(self.tree.getNode(text).StringLiteral.Text, {}) catch unreachable;
                }

                var i: usize = rightStandardPrologueEnd;
                while (i > 0) {
                    i -= 1;
                    const rightPrologue = declarations[i];
                    const text = self.tree.getNode(rightPrologue).ExpressionStatement.Expression;
                    if (!leftPrologues.contains(self.tree.getNode(text).StringLiteral.Text)) {
                        left.insert(self.allocator, 0, rightPrologue) catch unreachable;
                    }
                }
            }
        }

        return left.items;
    }

    fn isCustomPrologue(self: *EmitContext, node: ast_gen.NodeIndex) bool {
        return (self.getEmitFlags(node) & EmitFlags.CustomPrologue) != 0;
    }

    fn isHoistedFunction(self: *EmitContext, node: ast_gen.NodeIndex) bool {
        return self.isCustomPrologue(node) and self.tree.getNode(node) == .FunctionDeclaration;
    }

    fn isHoistedVariableStatement(self: *EmitContext, node: ast_gen.NodeIndex) bool {
        return self.isCustomPrologue(node) and self.tree.getNode(node) == .VariableStatement;
    }

    fn findSpanEndWithEmitContext(self: *EmitContext, statements: []const ast_gen.NodeIndex, match: *const fn (*EmitContext, ast_gen.NodeIndex) bool, startIndex: usize) usize {
        for (statements[startIndex..], 0..) |statement, i| {
            if (!match(self, statement)) {
                return startIndex + i;
            }
        }
        return statements.len;
    }

    fn findSpanEnd(tree: *ast.Ast, statements: []const ast_gen.NodeIndex, match: *const fn (*ast.Ast, ast_gen.NodeIndex) bool, startIndex: usize) usize {
        for (statements[startIndex..], 0..) |statement, i| {
            if (!match(tree, statement)) {
                return startIndex + i;
            }
        }
        return statements.len;
    }

    pub fn parseNode(self: *EmitContext, a: anytype) ast_gen.NodeIndex {
        _ = self;
        _ = a;
        return 0;
    }

    pub fn setCommentRange(self: *EmitContext, a: anytype, b: anytype) void {
        _ = self;
        _ = a;
        _ = b;
    }

    pub fn setSourceMapRange(self: *EmitContext, a: anytype, b: anytype) void {
        _ = self;
        _ = a;
        _ = b;
    }

    pub fn assignCommentAndSourceMapRanges(self: *EmitContext, a: anytype, b: anytype) void {
        _ = self;
        _ = a;
        _ = b;
    }

    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    factory: *NodeFactory,

    original: std.AutoHashMapUnmanaged(ast.NodeIndex, ast.NodeIndex) = .empty,
    emitNodes: std.AutoHashMapUnmanaged(ast.NodeIndex, EmitNode) = .empty,
    assignedName: std.AutoHashMapUnmanaged(ast.NodeIndex, ast.NodeIndex) = .empty,
    classThis: std.AutoHashMapUnmanaged(ast.NodeIndex, ast.NodeIndex) = .empty,
    autoGenerate: std.AutoHashMapUnmanaged(ast.NodeIndex, AutoGenerateInfo) = .empty,
    textSource: std.AutoHashMapUnmanaged(ast.NodeIndex, ast.NodeIndex) = .empty,

    varScopeStack: std.ArrayListUnmanaged(*VarScope) = .empty,
    letScopeStack: std.ArrayListUnmanaged(*VarScope) = .empty,
    emitHelpers: std.ArrayListUnmanaged(*const helpers_mod.EmitHelper) = .empty,

    pub fn init(allocator: std.mem.Allocator, tree: *ast.Ast, nodeFactory: *NodeFactory) EmitContext {
        return .{
            .allocator = allocator,
            .tree = tree,
            .factory = nodeFactory,
        };
    }

    pub fn deinit(self: *EmitContext) void {
        self.original.deinit(self.allocator);
        var it = self.emitNodes.valueIterator();
        while (it.next()) |node| {
            if (node.helpers) |*h| {
                h.deinit(self.allocator);
            }
            node.leadingComments.deinit(self.allocator);
            node.trailingComments.deinit(self.allocator);
        }
        self.emitNodes.deinit(self.allocator);
        self.assignedName.deinit(self.allocator);
        self.classThis.deinit(self.allocator);
        self.autoGenerate.deinit(self.allocator);
        self.textSource.deinit(self.allocator);
        self.emitHelpers.deinit(self.allocator);

        for (self.varScopeStack.items) |scope| {
            scope.deinit(self.allocator);
            self.allocator.destroy(scope);
        }
        self.varScopeStack.deinit(self.allocator);

        for (self.letScopeStack.items) |scope| {
            scope.deinit(self.allocator);
            self.allocator.destroy(scope);
        }
        self.letScopeStack.deinit(self.allocator);
    }

    pub fn reset(self: *EmitContext) void {
        self.original.clearRetainingCapacity();
        var it = self.emitNodes.valueIterator();
        while (it.next()) |node| {
            if (node.helpers) |*h| {
                h.deinit(self.allocator);
                node.helpers = null;
            }
        }
        self.emitNodes.clearRetainingCapacity();
        self.assignedName.clearRetainingCapacity();
        self.classThis.clearRetainingCapacity();
        self.autoGenerate.clearRetainingCapacity();
        self.textSource.clearRetainingCapacity();
        self.emitHelpers.clearRetainingCapacity();
    }

    pub fn setOriginal(self: *EmitContext, node: ast.NodeIndex, original: ast.NodeIndex) !void {
        try self.original.put(self.allocator, node, original);
        if (self.emitNodes.get(original)) |en| {
            try self.emitNodes.put(self.allocator, node, en); // clone emit node state
        }
    }

    pub fn newPartiallyEmittedExpression(self: *EmitContext, expression: ast.NodeIndex) ast.NodeIndex {
        _ = self;
        return expression; // placeholder
    }

    pub fn setTypeNode(self: *EmitContext, node: ast.NodeIndex, typeNode: ast_gen.NodeIndex) void {
        _ = self;
        _ = node;
        _ = typeNode;
        // Stub for setting type node
    }

    pub fn getAssignedName(self: *EmitContext, node: ast.NodeIndex) ast.NodeIndex {
        return self.assignedName.get(node) orelse 0;
    }

    pub fn setAssignedName(self: *EmitContext, node: ast.NodeIndex, name: ast.NodeIndex) !void {
        try self.assignedName.put(self.allocator, node, name);
    }

    pub fn getClassThis(self: *EmitContext, node: ast.NodeIndex) ast.NodeIndex {
        return self.classThis.get(node) orelse 0;
    }

    pub fn setClassThis(self: *EmitContext, node: ast.NodeIndex, class_this: ast.NodeIndex) !void {
        try self.classThis.put(self.allocator, node, class_this);
    }

    pub fn getOriginal(self: *EmitContext, node: ast.NodeIndex) ast.NodeIndex {
        return self.original.get(node) orelse 0;
    }

    pub fn newNodeVisitor(
        self: *EmitContext,
        visitFn: *const fn (ctx: ?*anyopaque, visitor: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex,
        ctx: ?*anyopaque,
        hooks: NodeVisitorHooks,
    ) *NodeVisitor {
        const v = self.allocator.create(NodeVisitor) catch unreachable;
        var final_hooks = hooks;
        if (final_hooks.visitEmbeddedStatement == null) {
            final_hooks.visitEmbeddedStatement = visitEmbeddedStatementHook;
        }
        v.* = NodeVisitor.init(self.allocator, self.tree, ctx, visitFn, final_hooks);
        v.emitContext = self;
        return v;
    }

    fn visitEmbeddedStatementHook(visitor: *NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        if (node == 0) return 0;
        const embeddedStatement = visitor.visitEmbeddedStatement(node);
        if (embeddedStatement == 0 or isNotEmittedStatement(visitor.tree, embeddedStatement)) {
            // const self = @as(*EmitContext, @ptrCast(@alignCast(visitor.emitContext.?)));
            const emptyStatement = visitor.tree.pushNode(.{ .EmptyStatement = .{ .Flags = 0 } }) catch unreachable;
            // self.setOriginal(emptyStatement, node) catch {}; // We can set original if needed
            return emptyStatement;
        }
        return embeddedStatement;
    }

    fn isNotEmittedStatement(tree: *ast.Ast, node: ast.NodeIndex) bool {
        if (node == 0) return false;
        return std.meta.activeTag(tree.getNode(node)) == .NotEmittedStatement;
    }

    pub fn getEmitFlags(self: *EmitContext, node: ast.NodeIndex) u32 {
        if (self.emitNodes.get(node)) |en| {
            return en.emitFlags;
        }
        return EmitFlags.None;
    }

    pub fn setEmitFlags(self: *EmitContext, node: ast.NodeIndex, flags: u32) !void {
        var gop = try self.emitNodes.getOrPut(self.allocator, node);
        if (!gop.found_existing) {
            gop.value_ptr.* = .{};
        }
        gop.value_ptr.emitFlags = flags;
    }

    pub fn addEmitFlags(self: *EmitContext, node: ast.NodeIndex, flags: u32) !void {
        var gop = try self.emitNodes.getOrPut(self.allocator, node);
        if (!gop.found_existing) {
            gop.value_ptr.* = .{};
        }
        gop.value_ptr.emitFlags |= flags;
    }

    pub fn startVariableEnvironment(self: *EmitContext) !void {
        const scope = try self.allocator.create(VarScope);
        scope.* = .{};
        try self.varScopeStack.append(self.allocator, scope);
        try self.startLexicalEnvironment();
    }

    pub fn endVariableEnvironment(self: *EmitContext) !std.ArrayListUnmanaged(ast.NodeIndex) {
        if (self.varScopeStack.items.len > 0) {
            const scope = self.varScopeStack.pop() orelse unreachable;
            defer {
                scope.deinit(self.allocator);
                self.allocator.destroy(scope);
            }
            var statements = std.ArrayListUnmanaged(ast.NodeIndex).empty;

            if (scope.functions.items.len > 0) {
                try statements.appendSlice(self.allocator, scope.functions.items);
            }
            if (scope.variables.items.len > 0) {
                const varList = self.factory.newVariableDeclarationList(self.factory.newNodeList(scope.variables.items), 0);
                const varStmt = self.factory.newVariableStatement(0, varList);
                try self.setEmitFlags(varStmt, EmitFlags.CustomPrologue);
                try statements.append(self.allocator, varStmt);
            }
            if (scope.initializationStatements.items.len > 0) {
                try statements.appendSlice(self.allocator, scope.initializationStatements.items);
            }

            var lexStmts = try self.endLexicalEnvironment();
            defer lexStmts.deinit(self.allocator);
            try statements.appendSlice(self.allocator, lexStmts.items);

            return statements;
        }
        return std.ArrayListUnmanaged(ast.NodeIndex).empty;
    }

    pub fn newNotEmittedStatement(self: *EmitContext, originalNode: ast.NodeIndex) !ast.NodeIndex {
        const newNodeData = ast_gen.NodeData{ .NotEmittedStatement = .{ .Flags = 0 } };
        const idx = try self.tree.pushNode(newNodeData);
        try self.setOriginal(idx, originalNode);
        return idx;
    }

    pub fn startLexicalEnvironment(self: *EmitContext) !void {
        const scope = try self.allocator.create(VarScope);
        scope.* = .{};
        try self.letScopeStack.append(self.allocator, scope);
    }

    pub fn endLexicalEnvironment(self: *EmitContext) !std.ArrayListUnmanaged(ast.NodeIndex) {
        if (self.letScopeStack.items.len > 0) {
            const scope = self.letScopeStack.pop() orelse unreachable;
            defer {
                scope.deinit(self.allocator);
                self.allocator.destroy(scope);
            }
            const statements = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            if (scope.variables.items.len > 0) {
                // Here we would create let variable declaration statement
            }
            return statements;
        }
        return std.ArrayListUnmanaged(ast.NodeIndex).empty;
    }
};

test "EmitContext" {
    const allocator = std.testing.allocator;
    var tree = ast.Ast.init(allocator);
    defer tree.deinit();

    var factory = NodeFactory.init(allocator, &tree);
    defer factory.deinit();

    var ctx = EmitContext.init(allocator, &tree, &factory);
    defer ctx.deinit();

    try ctx.setOriginal(1, 2);
    try std.testing.expectEqual(@as(ast.NodeIndex, 2), ctx.getOriginal(1));
}
