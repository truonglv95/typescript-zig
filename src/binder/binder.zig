const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const symbol = @import("../ast/symbol.zig");
const kind = @import("../ast/kind.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const nameresolver = @import("nameresolver.zig");
const referenceresolver = @import("referenceresolver.zig");

const BinderVisitor = struct {
    binder: *Binder,
    pub fn visitNode(self: *BinderVisitor, nodeIndex: ast_gen.NodeIndex) anyerror!void {
        try self.binder.bind(nodeIndex);
    }
    pub fn visitList(self: *BinderVisitor, listIndex: u32) anyerror!void {
        if (listIndex != 0) {
            const list = self.binder.ast.getNodeList(listIndex);
            for (list) |child| {
                try self.binder.bind(child);
            }
        }
    }
};

test "binder marks CommonJS modules and declares assignment exports" {
    const parser = @import("../parser/parser.zig");
    var parsed = parser.Parser.init(std.testing.allocator,
        \\module.exports = function main() {};
        \\exports.foo = 1;
        \\module.exports.bar = 2;
        \\Object.defineProperty(exports, "hidden", { value: 3 });
        \\require("dependency");
    );
    defer parsed.deinit();
    parsed.setScriptKind(.JS);
    const source_file = try parsed.parseSourceFile();
    var binder = try Binder.init(std.testing.allocator, &parsed.ast);
    defer binder.deinit();
    try binder.bindSourceFile(source_file);

    try std.testing.expect(ast_utils.getCommonJSModuleIndicator(&parsed.ast, source_file) != 0);
    const source_symbol = parsed.ast.getNodeSymbol(source_file) orelse return error.ExpectedCommonJSModuleSymbol;
    const exports = binder.symbolExports.getPtr(source_symbol) orelse return error.ExpectedCommonJSExports;
    try std.testing.expect(exports.contains(symbol.InternalSymbolNameExportEquals));
    try std.testing.expect(exports.contains("foo"));
    try std.testing.expect(exports.contains("bar"));
    try std.testing.expect(exports.contains("hidden"));
    const locals = binder.nodeLocals.getPtr(source_file) orelse return error.ExpectedCommonJSLocals;
    try std.testing.expect(locals.contains("module"));
    try std.testing.expect(locals.contains("exports"));
    const module_symbol = locals.get("module").?;
    const module_members = binder.symbolMembers.getPtr(module_symbol) orelse return error.ExpectedModuleMembers;
    try std.testing.expect(module_members.contains("exports"));
}

test "binder declares JavaScript this-property assignments on class symbols" {
    const parser = @import("../parser/parser.zig");
    var parsed = parser.Parser.init(std.testing.allocator,
        \\class C {
        \\  constructor() { this.instanceValue = 1; }
        \\  static { this.blockValue = 2; }
        \\  static initialize() { this.staticValue = 2; }
        \\}
    );
    defer parsed.deinit();
    parsed.setScriptKind(.JS);
    const source_file = try parsed.parseSourceFile();
    var binder = try Binder.init(std.testing.allocator, &parsed.ast);
    defer binder.deinit();
    try binder.bindSourceFile(source_file);

    const statements = parsed.ast.getNodeList(parsed.ast.getNode(source_file).SourceFile.Statements);
    const class_node = statements[0];
    const class_symbol = parsed.ast.getNodeSymbol(class_node) orelse return error.ExpectedClassSymbol;
    const members = binder.symbolMembers.getPtr(class_symbol) orelse return error.ExpectedClassMembers;
    const exports = binder.symbolExports.getPtr(class_symbol) orelse return error.ExpectedClassExports;
    try std.testing.expect(members.contains("instanceValue"));
    try std.testing.expect(exports.contains("blockValue"));
    try std.testing.expect(exports.contains("staticValue"));
}

pub const ContainerFlags = struct {
    pub const None: u32 = 0;
    pub const IsContainer: u32 = 1 << 0;
    pub const IsBlockScopedContainer: u32 = 1 << 1;
    pub const IsControlFlowContainer: u32 = 1 << 2;
    pub const IsFunctionLike: u32 = 1 << 3;
    pub const IsFunctionExpression: u32 = 1 << 4;
    pub const HasLocals: u32 = 1 << 5;
    pub const IsInterface: u32 = 1 << 6;
    pub const IsObjectLiteralOrClassExpressionMethodOrAccessor: u32 = 1 << 7;
    pub const IsThisContainer: u32 = 1 << 8;
    pub const PropagatesThisKeyword: u32 = 1 << 9;
};

pub const Binder = struct {
    pub const ExpandoAssignmentInfo = struct {
        node: ast_gen.NodeIndex,
        container: ast_gen.NodeIndex,
        blockScopeContainer: ast_gen.NodeIndex,
    };

    file: ast_gen.NodeIndex = 0,
    container: ?ast_gen.NodeIndex = null,
    thisContainer: ?ast_gen.NodeIndex = null,
    blockScopeContainer: ?ast_gen.NodeIndex = null,
    lastContainer: ?ast_gen.NodeIndex = null,
    seenThisKeyword: bool = false,
    hasExplicitReturn: bool = false,
    hasFlowEffects: bool = false,
    inAssignmentPattern: bool = false,
    seenParseError: bool = false,
    symbolCount: usize = 0,
    depth: usize = 0,

    allocator: std.mem.Allocator,
    ast: *ast.Ast,

    // Global symbols
    symbols: std.ArrayListUnmanaged(symbol.Symbol),

    // Map từ NodeIndex -> SymbolTable (Mô phỏng thuộc tính .locals của AST Node)
    // Binder state
    parentNodeIndex: ast_gen.NodeIndex,
    parent: ?ast_gen.SymbolIndex,

    nodeLocals: std.AutoHashMap(ast_gen.NodeIndex, std.StringHashMap(ast_gen.SymbolIndex)),
    symbolExports: std.AutoHashMap(ast_gen.SymbolIndex, std.StringHashMap(ast_gen.SymbolIndex)),
    symbolMembers: std.AutoHashMap(ast_gen.SymbolIndex, std.StringHashMap(ast_gen.SymbolIndex)),
    notConstEnumOnlyModules: std.AutoHashMap(ast_gen.SymbolIndex, void),

    diagnosticsList: std.ArrayListUnmanaged(diagnostics.Diagnostic) = .empty,
    expandoAssignments: std.ArrayListUnmanaged(ExpandoAssignmentInfo) = .empty,

    unreachableFlow: ast.flow.FlowNodeIndex = 0,
    currentFlow: ast.flow.FlowNodeIndex = 0,
    currentBreakTarget: ast.flow.FlowNodeIndex = 0,
    currentContinueTarget: ast.flow.FlowNodeIndex = 0,
    currentReturnTarget: ast.flow.FlowNodeIndex = 0,
    currentTrueTarget: ast.flow.FlowNodeIndex = 0,
    currentFalseTarget: ast.flow.FlowNodeIndex = 0,
    currentExceptionTarget: ast.flow.FlowNodeIndex = 0,
    preSwitchCaseFlow: ast.flow.FlowNodeIndex = 0,

    flowNodes: std.ArrayListUnmanaged(ast.flow.FlowNode) = .empty,
    flowLists: std.ArrayListUnmanaged(ast.flow.FlowList) = .empty,

    pub fn init(allocator: std.mem.Allocator, a: *ast.Ast) !Binder {
        var symbols = std.ArrayListUnmanaged(symbol.Symbol).empty;
        try symbols.append(allocator, .{
            .Flags = symbol.SymbolFlags.None,
            .Name = try allocator.dupe(u8, ""),
            .Declarations = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty,
            .ValueDeclaration = null,
            .Members = symbol.SymbolTable.empty,
            .Exports = symbol.SymbolTable.empty,
            .Parent = null,
            .ExportSymbol = null,
        });

        var binder = Binder{
            .allocator = allocator,
            .ast = a,
            .symbols = symbols,
            .nodeLocals = std.AutoHashMap(ast_gen.NodeIndex, std.StringHashMap(ast_gen.SymbolIndex)).init(allocator),
            .symbolExports = std.AutoHashMap(ast_gen.SymbolIndex, std.StringHashMap(ast_gen.SymbolIndex)).init(allocator),
            .symbolMembers = std.AutoHashMap(ast_gen.SymbolIndex, std.StringHashMap(ast_gen.SymbolIndex)).init(allocator),
            .notConstEnumOnlyModules = std.AutoHashMap(ast_gen.SymbolIndex, void).init(allocator),
            .parentNodeIndex = 0,
            .parent = null,
            .container = null,
            .blockScopeContainer = null,
            .file = 0,
            .diagnosticsList = std.ArrayListUnmanaged(diagnostics.Diagnostic).empty,
        };
        binder.flowNodes.append(allocator, .{ .flags = 0 }) catch unreachable;
        binder.flowLists.append(allocator, .{}) catch unreachable;
        binder.unreachableFlow = binder.newFlowNode(ast.flow.FlowFlags.Unreachable);
        return binder;
    }

    pub fn deinit(self: *Binder) void {
        for (self.symbols.items) |*sym| {
            self.allocator.free(sym.Name);
            sym.Declarations.deinit(self.allocator);
            sym.Members.deinit(self.allocator);
            sym.Exports.deinit(self.allocator);
        }
        self.symbols.deinit(self.allocator);

        var it = self.nodeLocals.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.nodeLocals.deinit();

        var itEx = self.symbolExports.iterator();
        while (itEx.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.symbolExports.deinit();

        var itMem = self.symbolMembers.iterator();
        while (itMem.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.symbolMembers.deinit();

        self.notConstEnumOnlyModules.deinit();
        self.diagnosticsList.deinit(self.allocator);
        self.expandoAssignments.deinit(self.allocator);
        self.flowNodes.deinit(self.allocator);
        self.flowLists.deinit(self.allocator);
    }

    pub fn newFlowNode(self: *Binder, flags: u32) ast.flow.FlowNodeIndex {
        const index = @as(u32, @intCast(self.flowNodes.items.len));
        self.flowNodes.append(self.allocator, .{ .flags = flags }) catch unreachable;
        return index;
    }

    pub fn newFlowNodeEx(self: *Binder, flags: u32, node: ast_gen.NodeIndex, antecedent: ast.flow.FlowNodeIndex) ast.flow.FlowNodeIndex {
        const index = self.newFlowNode(flags);
        self.flowNodes.items[index].node = node;
        self.flowNodes.items[index].antecedent = antecedent;
        return index;
    }

    pub fn newFlowNodeDataEx(self: *Binder, flags: u32, data: ast.flow.FlowNodeData, antecedent: ast.flow.FlowNodeIndex) ast.flow.FlowNodeIndex {
        const index = self.newFlowNode(flags);
        self.flowNodes.items[index].nodeData = data;
        self.flowNodes.items[index].antecedent = antecedent;
        return index;
    }

    pub fn createLoopLabel(self: *Binder) ast.flow.FlowNodeIndex {
        return self.newFlowNode(ast.flow.FlowFlags.LoopLabel);
    }

    pub fn createBranchLabel(self: *Binder) ast.flow.FlowNodeIndex {
        return self.newFlowNode(ast.flow.FlowFlags.BranchLabel);
    }

    pub fn setFlowNodeReferenced(self: *Binder, nodeIndex: ast.flow.FlowNodeIndex) void {
        if (nodeIndex != 0) {
            self.flowNodes.items[nodeIndex].flags |= ast.flow.FlowFlags.Referenced;
        }
    }

    pub fn createReduceLabel(self: *Binder, target: ast.flow.FlowNodeIndex, antecedents: ast.flow.FlowListIndex, antecedent: ast.flow.FlowNodeIndex) ast.flow.FlowNodeIndex {
        return self.newFlowNodeDataEx(ast.flow.FlowFlags.ReduceLabel, .{ .ReduceLabelData = .{ .target = target, .antecedents = antecedents } }, antecedent);
    }

    pub fn emitConditionFlow(self: *Binder, flags: u32, expression: ast_gen.NodeIndex) bool {
        _ = self;
        _ = flags;
        _ = expression;
        // Simplified
        return true;
    }

    pub fn createFlowCondition(self: *Binder, flags: u32, antecedent: ast.flow.FlowNodeIndex, expression: ast_gen.NodeIndex) ast.flow.FlowNodeIndex {
        if (antecedent != 0 and (self.flowNodes.items[antecedent].flags & ast.flow.FlowFlags.Unreachable) != 0) {
            return antecedent;
        }
        if (expression == 0) {
            if ((flags & ast.flow.FlowFlags.TrueCondition) != 0) {
                return antecedent;
            }
            return self.unreachableFlow;
        }

        // Skip KindTrueKeyword/FalseKeyword logic for brevity or add it
        // ...

        if (!self.emitConditionFlow(flags, expression)) {
            return antecedent;
        }
        self.setFlowNodeReferenced(antecedent);
        return self.newFlowNodeEx(flags, expression, antecedent);
    }

    pub fn createFlowMutation(self: *Binder, flags: u32, antecedent: ast.flow.FlowNodeIndex, node: ast_gen.NodeIndex) ast.flow.FlowNodeIndex {
        self.setFlowNodeReferenced(antecedent);
        self.hasFlowEffects = true;
        return self.newFlowNodeEx(flags, node, antecedent);
    }

    pub fn createFlowSwitchClause(self: *Binder, antecedent: ast.flow.FlowNodeIndex, switchStatement: ast_gen.NodeIndex, clauseStart: i32, clauseEnd: i32) ast.flow.FlowNodeIndex {
        self.setFlowNodeReferenced(antecedent);
        return self.newFlowNodeDataEx(ast.flow.FlowFlags.SwitchClause, .{ .SwitchClauseData = .{ .switchStatement = switchStatement, .clauseStart = clauseStart, .clauseEnd = clauseEnd } }, antecedent);
    }

    pub fn createFlowCall(self: *Binder, antecedent: ast.flow.FlowNodeIndex, node: ast_gen.NodeIndex) ast.flow.FlowNodeIndex {
        self.setFlowNodeReferenced(antecedent);
        self.hasFlowEffects = true;
        return self.newFlowNodeEx(ast.flow.FlowFlags.Call, node, antecedent);
    }

    pub fn newFlowList(self: *Binder, flow: ast.flow.FlowNodeIndex, tail: ast.flow.FlowListIndex) ast.flow.FlowListIndex {
        const index = @as(u32, @intCast(self.flowLists.items.len));
        self.flowLists.append(self.allocator, .{ .flow = flow, .next = tail }) catch unreachable;
        return index;
    }

    pub fn combineFlowLists(self: *Binder, head: ast.flow.FlowListIndex, tail: ast.flow.FlowListIndex) ast.flow.FlowListIndex {
        if (head == 0) return tail;
        if (tail == 0) return head;
        return self.newFlowList(self.flowLists.items[head].flow, self.combineFlowLists(self.flowLists.items[head].next, tail));
    }

    pub fn addAntecedent(self: *Binder, label: ast.flow.FlowNodeIndex, antecedent: ast.flow.FlowNodeIndex) void {
        if (antecedent == 0 or (self.flowNodes.items[antecedent].flags & ast.flow.FlowFlags.Unreachable) != 0) return;
        self.flowNodes.items[label].antecedents = self.newFlowList(antecedent, self.flowNodes.items[label].antecedents);
        self.setFlowNodeReferenced(antecedent);
    }

    pub fn createBranchFlow(self: *Binder, label: ast.flow.FlowNodeIndex, antecedent: ast.flow.FlowNodeIndex) ast.flow.FlowNodeIndex {
        self.addAntecedent(label, antecedent);
        return self.unreachableFlow;
    }

    pub fn createReturnFlow(self: *Binder, label: ast.flow.FlowNodeIndex, antecedent: ast.flow.FlowNodeIndex) ast.flow.FlowNodeIndex {
        self.addAntecedent(label, antecedent);
        return self.unreachableFlow;
    }

    pub fn finishFlowLabel(self: *Binder, flow: ast.flow.FlowNodeIndex) ast.flow.FlowNodeIndex {
        const antecedents = self.flowNodes.items[flow].antecedents;
        if (antecedents == 0) {
            return self.unreachableFlow;
        }
        const firstFlow = self.flowLists.items[antecedents].flow;
        if (self.flowLists.items[antecedents].next == 0) {
            return firstFlow;
        }
        return flow;
    }

    pub fn bindIfStatementFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const thenStatement = self.ast.getNode(nodeIndex).data.IfStatement.thenStatement;
        const elseStatement = self.ast.getNode(nodeIndex).data.IfStatement.elseStatement;
        const expression = self.ast.getNode(nodeIndex).data.IfStatement.expression;

        const thenFlow = self.createFlowCondition(ast.flow.FlowFlags.TrueCondition, self.currentFlow, expression);
        const elseFlow = self.createFlowCondition(ast.flow.FlowFlags.FalseCondition, self.currentFlow, expression);

        self.currentFlow = thenFlow;
        try self.bind(thenStatement);
        const thenEndFlow = self.currentFlow;

        self.currentFlow = elseFlow;
        if (elseStatement != 0) {
            try self.bind(elseStatement);
        }

        const elseEndFlow = self.currentFlow;

        const endLabel = self.createBranchLabel();
        self.addAntecedent(endLabel, thenEndFlow);
        self.addAntecedent(endLabel, elseEndFlow);
        self.currentFlow = self.finishFlowLabel(endLabel);
    }

    pub fn bindDoStatementFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const statement = self.ast.getNode(nodeIndex).data.DoStatement.statement;
        const expression = self.ast.getNode(nodeIndex).data.DoStatement.expression;

        const loopLabel = self.createLoopLabel();
        self.addAntecedent(loopLabel, self.currentFlow);
        self.currentFlow = loopLabel;

        const preBreakTarget = self.currentBreakTarget;
        const preContinueTarget = self.currentContinueTarget;

        self.currentBreakTarget = self.createBranchLabel();
        self.currentContinueTarget = self.createBranchLabel();

        try self.bind(statement);

        self.addAntecedent(self.currentContinueTarget, self.currentFlow);
        self.currentFlow = self.finishFlowLabel(self.currentContinueTarget);

        try self.bind(expression);

        const thenFlow = self.createFlowCondition(ast.flow.FlowFlags.TrueCondition, self.currentFlow, expression);
        const elseFlow = self.createFlowCondition(ast.flow.FlowFlags.FalseCondition, self.currentFlow, expression);

        self.addAntecedent(loopLabel, thenFlow);
        self.addAntecedent(self.currentBreakTarget, elseFlow);

        self.currentFlow = self.finishFlowLabel(self.currentBreakTarget);

        self.currentBreakTarget = preBreakTarget;
        self.currentContinueTarget = preContinueTarget;
    }

    pub fn bindWhileStatementFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const expression = self.ast.getNode(nodeIndex).data.WhileStatement.expression;
        const statement = self.ast.getNode(nodeIndex).data.WhileStatement.statement;

        const loopLabel = self.createLoopLabel();
        self.addAntecedent(loopLabel, self.currentFlow);
        self.currentFlow = loopLabel;

        try self.bind(expression);

        const thenFlow = self.createFlowCondition(ast.flow.FlowFlags.TrueCondition, self.currentFlow, expression);
        const elseFlow = self.createFlowCondition(ast.flow.FlowFlags.FalseCondition, self.currentFlow, expression);

        const preBreakTarget = self.currentBreakTarget;
        const preContinueTarget = self.currentContinueTarget;

        self.currentBreakTarget = self.createBranchLabel();
        self.currentContinueTarget = self.createBranchLabel();

        self.currentFlow = thenFlow;
        try self.bind(statement);

        self.addAntecedent(self.currentContinueTarget, self.currentFlow);
        self.currentFlow = self.finishFlowLabel(self.currentContinueTarget);
        self.addAntecedent(loopLabel, self.currentFlow);

        self.addAntecedent(self.currentBreakTarget, elseFlow);
        self.currentFlow = self.finishFlowLabel(self.currentBreakTarget);

        self.currentBreakTarget = preBreakTarget;
        self.currentContinueTarget = preContinueTarget;
    }

    pub fn bindReturnStatementFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const expression = self.ast.getNode(nodeIndex).data.ReturnStatement.expression;
        if (expression != 0) {
            try self.bind(expression);
        }
        if (self.currentReturnTarget != 0) {
            self.addAntecedent(self.currentReturnTarget, self.currentFlow);
        }
        self.currentFlow = self.unreachableFlow;
    }

    pub fn bindBreakOrContinueFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const kindCode = self.ast.getNode(nodeIndex).kind;
        if (kindCode == kind.BreakStatement) {
            if (self.currentBreakTarget != 0) {
                self.addAntecedent(self.currentBreakTarget, self.currentFlow);
            }
        } else {
            if (self.currentContinueTarget != 0) {
                self.addAntecedent(self.currentContinueTarget, self.currentFlow);
            }
        }
        self.currentFlow = self.unreachableFlow;
    }

    pub fn bindSwitchStatementFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const expression = self.ast.getNode(nodeIndex).data.SwitchStatement.expression;
        const caseBlock = self.ast.getNode(nodeIndex).data.SwitchStatement.caseBlock;

        try self.bind(expression);

        const preBreakTarget = self.currentBreakTarget;
        self.currentBreakTarget = self.createBranchLabel();
        self.preSwitchCaseFlow = self.currentFlow;

        self.currentFlow = self.unreachableFlow;
        try self.bind(caseBlock);

        self.addAntecedent(self.currentBreakTarget, self.currentFlow);

        self.currentFlow = self.finishFlowLabel(self.currentBreakTarget);
        self.currentBreakTarget = preBreakTarget;
    }

    pub fn bindTryStatementFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const tryBlock = self.ast.getNode(nodeIndex).data.TryStatement.tryBlock;
        const catchClause = self.ast.getNode(nodeIndex).data.TryStatement.catchClause;
        const finallyBlock = self.ast.getNode(nodeIndex).data.TryStatement.finallyBlock;

        const preExceptionTarget = self.currentExceptionTarget;

        self.currentExceptionTarget = self.createBranchLabel();
        try self.bind(tryBlock);
        self.addAntecedent(self.currentExceptionTarget, self.currentFlow);

        const finallyReturnFlow: ast.flow.FlowNodeIndex = 0;

        if (catchClause != 0) {
            self.currentFlow = self.currentExceptionTarget;
            self.currentExceptionTarget = preExceptionTarget;
            try self.bind(catchClause);
        } else {
            self.currentExceptionTarget = preExceptionTarget;
        }

        if (finallyBlock != 0) {
            try self.bind(finallyBlock);
        }
        _ = finallyReturnFlow;
    }

    pub fn bindCatchClauseFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const block = self.ast.getNode(nodeIndex).data.CatchClause.block;
        try self.bind(block);
    }

    pub fn bindSourceFile(self: *Binder, sourceFileIndex: ast_gen.NodeIndex) !void {
        self.file = sourceFileIndex;
        try self.bind(sourceFileIndex);
        try self.bindDeferredExpandoAssignments();
    }

    fn bindSourceFileIfExternalModule(self: *Binder) !void {
        if (ast_utils.isExternalOrCommonJSModule(self.ast, self.file)) {
            try self.bindSourceFileAsExternalModule();
        }
    }

    fn bindSourceFileAsExternalModule(self: *Binder) !void {
        const file_name = if (self.ast.fileName.len != 0) self.ast.fileName else "/test.ts";
        const extension = std.fs.path.extension(file_name);
        const without_extension = file_name[0 .. file_name.len - extension.len];
        const module_name = try std.fmt.allocPrint(self.allocator, "\"{s}\"", .{without_extension});
        defer self.allocator.free(module_name);
        _ = try self.bindAnonymousDeclaration(self.file, symbol.SymbolFlags.ValueModule, module_name);
    }

    fn declareCommonJSVariable(self: *Binder, name: []const u8, add_exports_member: bool) !void {
        if (self.nodeLocals.getPtr(self.file)) |locals| if (locals.contains(name)) return;
        const variable = try self.declareSymbolEx(.Locals, self.file, 0, symbol.SymbolFlags.FunctionScopedVariable | symbol.SymbolFlags.ModuleExports, symbol.SymbolFlags.None, name, false, false);
        if (add_exports_member) _ = try self.declareSymbolEx(.Members, variable, 0, symbol.SymbolFlags.ModuleExports | symbol.SymbolFlags.Property, symbol.SymbolFlags.None, "exports", false, false);
    }

    fn isAmbientContext(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        if (ast_utils.hasSyntacticModifier(self.ast, nodeIndex, ast_utils.ModifierFlags.Ambient)) {
            return true;
        }
        var current = nodeIndex;
        while (current != 0) {
            const parent = self.ast.getNodeParent(current);
            if (parent == 0) break;
            const parentNode = self.ast.getNode(parent);
            switch (parentNode) {
                .ModuleDeclaration => {
                    if (ast_utils.hasSyntacticModifier(self.ast, parent, ast_utils.ModifierFlags.Ambient)) {
                        return true;
                    }
                },
                else => {},
            }
            current = parent;
        }
        return false;
    }

    fn hasExportDeclarations(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        const node = self.ast.getNode(nodeIndex);
        var statements_list: []const ast_gen.NodeIndex = &[_]ast_gen.NodeIndex{};
        switch (node) {
            .SourceFile => |n| {
                if (n.Statements != 0) {
                    statements_list = self.ast.getNodeList(n.Statements);
                }
            },
            .ModuleDeclaration => |n| {
                if (n.Body != null and n.Body.? != 0) {
                    const body = self.ast.getNode(n.Body.?);
                    if (body == .ModuleBlock) {
                        if (body.ModuleBlock.Statements != 0) {
                            statements_list = self.ast.getNodeList(body.ModuleBlock.Statements);
                        }
                    }
                }
            },
            else => return false,
        }
        for (statements_list) |stmt| {
            const stmtNode = self.ast.getNode(stmt);
            if (stmtNode == .ExportDeclaration or stmtNode == .ExportAssignment) {
                return true;
            }
        }
        return false;
    }

    fn setExportContextFlag(self: *Binder, nodeIndex: ast_gen.NodeIndex) void {
        var node = self.ast.getNode(nodeIndex);
        if (node == .ModuleDeclaration) {
            const isAmbient = self.isAmbientContext(nodeIndex);
            if (isAmbient) {
                node.ModuleDeclaration.Flags |= ast_utils.NodeFlags.Ambient;
                if (!self.hasExportDeclarations(nodeIndex)) {
                    node.ModuleDeclaration.Flags |= ast_utils.NodeFlags.ExportContext;
                } else {
                    node.ModuleDeclaration.Flags &= ~ast_utils.NodeFlags.ExportContext;
                }
            } else {
                node.ModuleDeclaration.Flags &= ~ast_utils.NodeFlags.ExportContext;
            }
            self.ast.nodes.set(nodeIndex, node);
        } else if (node == .SourceFile) {
            const isAmbient = self.isAmbientContext(nodeIndex);
            if (isAmbient) {
                node.SourceFile.Flags |= ast_utils.NodeFlags.Ambient;
                if (!self.hasExportDeclarations(nodeIndex)) {
                    node.SourceFile.Flags |= ast_utils.NodeFlags.ExportContext;
                } else {
                    node.SourceFile.Flags &= ~ast_utils.NodeFlags.ExportContext;
                }
            } else {
                node.SourceFile.Flags &= ~ast_utils.NodeFlags.ExportContext;
            }
            self.ast.nodes.set(nodeIndex, node);
        }
    }

    pub fn bind(self: *Binder, optNodeIndex: ?ast_gen.NodeIndex) anyerror!void {
        if (optNodeIndex == null or optNodeIndex.? == 0) return;
        const nodeIndex = optNodeIndex.?;
        self.depth += 1;
        if (self.depth > 200) {
            return;
        }
        defer self.depth -= 1;

        if (self.parentNodeIndex != 0) {
            self.ast.setNodeParent(nodeIndex, self.parentNodeIndex);
        }

        const saveParent = self.parentNodeIndex;
        self.parentNodeIndex = nodeIndex;
        defer self.parentNodeIndex = saveParent;

        const node = self.ast.getNode(nodeIndex);

        switch (node) {
            .SourceFile => |n| {
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;

                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                self.file = nodeIndex;

                try self.bindSourceFileIfExternalModule();

                if (n.Statements != 0) {
                    try self.bindEachStatementFunctionsFirst(n.Statements);
                }

                if (ast_utils.isInJSFile(self.ast, nodeIndex)) {
                    if (n.Statements != 0) {
                        for (self.ast.getNodeList(n.Statements)) |statement| {
                            if (self.ast.getNode(statement) == .JSTypeAliasDeclaration) {
                                const st_node = self.ast.getNode(statement).JSTypeAliasDeclaration;
                                _ = try self.bindBlockScopedDeclaration(statement, symbol.SymbolFlags.TypeAlias, symbol.SymbolFlags.TypeAliasExcludes, self.getIdentifierName(st_node.name));
                            }
                        }
                    }
                }

                const current_source = self.ast.getNode(nodeIndex).SourceFile;
                if (current_source.CommonJSModuleIndicator != null) {
                    try self.declareCommonJSVariable("module", true);
                    try self.declareCommonJSVariable("exports", false);
                }

                if (ast_utils.isExternalOrCommonJSModule(self.ast, self.file)) {
                    if (self.ast.getNodeSymbol(nodeIndex)) |sym| {
                        try self.bindCommonJSTypeExports(sym);
                    }
                    if (current_source.CommonJSModuleIndicator) |indicator| {
                        self.setExportContextFlag(indicator);
                    }
                }

                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .VariableStatement => |n| {
                try self.bind(n.DeclarationList);
            },
            .VariableDeclarationList => |n| {
                if (n.Declarations != 0) {
                    try self.bindNodeList(n.Declarations);
                }
            },
            .VariableDeclaration => |n| {
                if (n.name != 0) {
                    try self.bindVariableDeclarationOrBindingElement(nodeIndex, n.name);
                    try self.bind(n.name);
                }
                if (n.Type) |t| try self.bind(t);
                if (n.Initializer != 0) try self.bind(n.Initializer);
                try self.bindVariableDeclarationFlow(nodeIndex);
            },
            .FunctionDeclaration => |n| {
                self.checkStrictModeFunctionName(nodeIndex);
                const nameStr = if (n.name != null and n.name.? != 0) self.getIdentifierName(n.name.?) else symbol.InternalSymbolNameMissing;
                _ = try self.bindBlockScopedDeclaration(nodeIndex, symbol.SymbolFlags.Function, symbol.SymbolFlags.FunctionExcludes, nameStr);

                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;

                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;

                if (n.TypeParameters) |tp| {
                    try self.bindNodeList(tp);
                }
                if (n.Parameters != 0) {
                    try self.bindNodeList(n.Parameters);
                }
                if (n.Type) |t| {
                    try self.bind(t);
                }
                if (n.Body) |body| {
                    try self.bind(body);
                }

                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .FunctionExpression => |n| {
                self.checkStrictModeFunctionName(nodeIndex);
                var bindingName: []const u8 = "__function";
                if (n.name) |nameIndex| {
                    bindingName = self.getIdentifierName(nameIndex);
                }
                _ = try self.bindAnonymousDeclaration(nodeIndex, symbol.SymbolFlags.Function, bindingName);

                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;

                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;

                if (n.TypeParameters) |tp| {
                    try self.bindNodeList(tp);
                }
                if (n.Parameters != 0) {
                    try self.bindNodeList(n.Parameters);
                }
                if (n.Type) |t| {
                    try self.bind(t);
                }
                if (n.Body) |body| {
                    try self.bind(body);
                }

                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .ArrowFunction => |n| {
                _ = try self.bindAnonymousDeclaration(nodeIndex, symbol.SymbolFlags.Function, "__function");

                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;

                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;

                if (n.TypeParameters) |tp| {
                    try self.bindNodeList(tp);
                }
                if (n.Parameters != 0) {
                    try self.bindNodeList(n.Parameters);
                }
                if (n.Type) |t| {
                    try self.bind(t);
                }
                if (n.Body) |body| {
                    try self.bind(body);
                }

                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .ClassDeclaration => |n| {
                const nameStr = if (n.name != null and n.name.? != 0) self.getIdentifierName(n.name.?) else symbol.InternalSymbolNameMissing;
                _ = try self.bindBlockScopedDeclaration(nodeIndex, symbol.SymbolFlags.Class, symbol.SymbolFlags.ClassExcludes, nameStr);
                const classSymbolId = self.ast.getNodeSymbol(nodeIndex).?;

                _ = try self.declareSymbolEx(.Exports, classSymbolId, 0, symbol.SymbolFlags.Property | symbol.SymbolFlags.Prototype, symbol.SymbolFlags.PropertyExcludes, "prototype", false, false);

                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;

                if (n.TypeParameters) |tp| try self.bindNodeList(tp);
                if (n.HeritageClauses) |hc| try self.bindNodeList(hc);
                if (n.Members != 0) {
                    try self.bindNodeList(n.Members);
                }

                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .ClassExpression => |n| {
                const nameStr = if (n.name != null and n.name.? != 0) self.getIdentifierName(n.name.?) else "__class";
                _ = try self.bindAnonymousDeclaration(nodeIndex, symbol.SymbolFlags.Class, nameStr);
                const classSymbolId = self.ast.getNodeSymbol(nodeIndex).?;

                _ = try self.declareSymbolEx(.Exports, classSymbolId, 0, symbol.SymbolFlags.Property | symbol.SymbolFlags.Prototype, symbol.SymbolFlags.PropertyExcludes, "prototype", false, false);

                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;

                if (n.TypeParameters) |tp| try self.bindNodeList(tp);
                if (n.HeritageClauses) |hc| try self.bindNodeList(hc);
                if (n.Members != 0) {
                    try self.bindNodeList(n.Members);
                }

                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .InterfaceDeclaration => |n| {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Interface, symbol.SymbolFlags.InterfaceExcludes, self.getIdentifierName(n.name));
                const saveContainer = self.container;
                self.container = nodeIndex;
                if (n.TypeParameters) |tp| {
                    try self.bindNodeList(tp);
                }
                if (n.Members != 0) {
                    try self.bindNodeList(n.Members);
                }
                self.container = saveContainer;
            },
            .TypeAliasDeclaration => |n| {
                _ = try self.bindBlockScopedDeclaration(nodeIndex, symbol.SymbolFlags.TypeAlias, symbol.SymbolFlags.TypeAliasExcludes, self.getIdentifierName(n.name));
                const saveContainer = self.container;
                self.container = nodeIndex;
                if (n.TypeParameters) |tp| {
                    try self.bindNodeList(tp);
                }
                try self.bind(n.Type);
                self.container = saveContainer;
            },
            .EnumDeclaration => |n| {
                var isConst = false;
                if (n.modifiers != null) {
                    const modifiers = self.ast.getNodeList(n.modifiers.?);
                    for (modifiers) |mod| {
                        if (self.ast.getNode(mod) == .ConstKeyword) {
                            isConst = true;
                            break;
                        }
                    }
                }
                const flags = if (isConst) symbol.SymbolFlags.ConstEnum else symbol.SymbolFlags.RegularEnum;
                const excludes = if (isConst) symbol.SymbolFlags.ConstEnumExcludes else symbol.SymbolFlags.RegularEnumExcludes;
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, flags, excludes, self.getIdentifierName(n.name));
                const saveContainer = self.container;
                self.container = nodeIndex;
                if (n.Members != 0) {
                    try self.bindNodeList(n.Members);
                } else {}
                self.container = saveContainer;
            },
            .EnumMember => |n| {
                _ = try self.bindPropertyOrMethodOrAccessor(nodeIndex, symbol.SymbolFlags.EnumMember, symbol.SymbolFlags.EnumMemberExcludes, self.getIdentifierName(n.name));
                if (n.Initializer) |initExpr| {
                    try self.bind(initExpr);
                }
            },
            .ModuleDeclaration => |n| {
                self.setExportContextFlag(nodeIndex);
                var nameStr = self.getIdentifierName(n.name);
                var allocated_name: ?[]u8 = null;
                if (self.ast.getNode(n.name) == .StringLiteral) {
                    allocated_name = try std.fmt.allocPrint(self.allocator, "\"{s}\"", .{nameStr});
                    nameStr = allocated_name.?;
                } else if (self.ast.getNode(n.name) == .Identifier) {
                    if (ast_utils.isGlobalScopeAugmentation(self.ast, nodeIndex)) {
                        nameStr = symbol.InternalSymbolNameGlobal;
                    }
                }
                const state = ast_utils.getModuleInstanceState(self.ast, nodeIndex);
                const instantiated = state != .NonInstantiated;
                const flags = if (instantiated) symbol.SymbolFlags.ValueModule else symbol.SymbolFlags.NamespaceModule;
                const excludes = if (instantiated) symbol.SymbolFlags.ValueModuleExcludes else symbol.SymbolFlags.NamespaceModuleExcludes;
                const symIndex = try self.declareSymbolAndAddToSymbolTable(nodeIndex, flags, excludes, nameStr);

                if (instantiated) {
                    var sym = &self.symbols.items[symIndex];
                    const constEnumOnlyModule = (sym.Flags & (symbol.SymbolFlags.Function | symbol.SymbolFlags.Class | symbol.SymbolFlags.RegularEnum) == 0) and
                        state == .ConstEnumOnly and
                        !self.notConstEnumOnlyModules.contains(symIndex);

                    if (constEnumOnlyModule) {
                        sym.Flags |= symbol.SymbolFlags.ConstEnumOnlyModule;
                    } else {
                        sym.Flags &= ~symbol.SymbolFlags.ConstEnumOnlyModule;
                        try self.notConstEnumOnlyModules.put(symIndex, {});
                    }
                }
                // if (allocated_name) |an| {
                //     self.allocator.free(an);
                // }
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                if (n.Body) |body| {
                    try self.bind(body);
                }

                if (ast_utils.isAmbientModule(self.ast, nodeIndex)) {
                    if (self.ast.getNodeSymbol(nodeIndex)) |sym| {
                        try self.bindCommonJSTypeExports(sym);
                    }
                }

                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .Constructor => |n| {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Constructor, symbol.SymbolFlags.None, symbol.InternalSymbolNameConstructor);
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                if (n.Parameters != 0) try self.bindNodeList(n.Parameters);
                if (n.Body) |body| try self.bind(body);
                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .MethodDeclaration => |n| {
                self.checkStrictModeFunctionName(nodeIndex);
                var flags = symbol.SymbolFlags.Method;
                if (n.PostfixToken != null and n.PostfixToken.? != 0 and self.ast.getNode(n.PostfixToken.?) == .QuestionToken) flags |= symbol.SymbolFlags.Optional;
                _ = try self.bindPropertyOrMethodOrAccessor(nodeIndex, flags, symbol.SymbolFlags.MethodExcludes, self.getIdentifierName(n.name));
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                if (n.TypeParameters) |tp| {
                    try self.bindNodeList(tp);
                }
                if (n.Parameters != 0) {
                    try self.bindNodeList(n.Parameters);
                }
                if (n.Type) |t| try self.bind(t);
                if (n.Body) |body| try self.bind(body);
                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .MethodSignature => |n| {
                self.checkStrictModeFunctionName(nodeIndex);
                const nameStr = if (n.name != 0) self.getIdentifierName(n.name) else symbol.InternalSymbolNameMissing;
                var flags = symbol.SymbolFlags.Method;
                if (n.PostfixToken != null and n.PostfixToken.? != 0 and self.ast.getNode(n.PostfixToken.?) == .QuestionToken) flags |= symbol.SymbolFlags.Optional;
                _ = try self.bindPropertyOrMethodOrAccessor(nodeIndex, flags, symbol.SymbolFlags.MethodExcludes, nameStr);
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                if (n.TypeParameters) |tp| try self.bindNodeList(tp);
                if (n.Parameters != 0) try self.bindNodeList(n.Parameters);
                if (n.Type) |t| try self.bind(t);
                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .CallSignature => |n| {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Signature, symbol.SymbolFlags.None, symbol.InternalSymbolNameCall);
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                if (n.TypeParameters) |tp| try self.bindNodeList(tp);
                if (n.Parameters != 0) try self.bindNodeList(n.Parameters);
                if (n.Type) |t| try self.bind(t);
                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .ConstructSignature => |n| {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Signature, symbol.SymbolFlags.None, symbol.InternalSymbolNameNew);
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                if (n.TypeParameters) |tp| try self.bindNodeList(tp);
                if (n.Parameters != 0) try self.bindNodeList(n.Parameters);
                if (n.Type) |t| try self.bind(t);
                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .IndexSignature => |n| {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Signature, symbol.SymbolFlags.None, symbol.InternalSymbolNameIndex);
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                if (n.Parameters != 0) try self.bindNodeList(n.Parameters);
                if (n.Type) |t| try self.bind(t);
                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .FunctionType => |n| {
                try self.bindFunctionOrConstructorType(nodeIndex);
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                if (n.TypeParameters) |tp| try self.bindNodeList(tp);
                if (n.Parameters != 0) try self.bindNodeList(n.Parameters);
                if (n.Type) |t| try self.bind(t);
                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .ConstructorType => |n| {
                try self.bindFunctionOrConstructorType(nodeIndex);
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                if (n.modifiers) |mods| try self.bindNodeList(mods);
                if (n.TypeParameters) |tp| try self.bindNodeList(tp);
                if (n.Parameters != 0) try self.bindNodeList(n.Parameters);
                if (n.Type) |t| try self.bind(t);
                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .TypeParameter => |n| {
                const nameStr = self.getIdentifierName(n.name);
                const parent = self.ast.getNodeParent(nodeIndex);
                if (parent != 0 and self.ast.getNode(parent) == .InferType) {
                    const container = self.getInferTypeContainer(parent);
                    if (container != 0) {
                        _ = try self.declareSymbolEx(.Locals, container, nodeIndex, symbol.SymbolFlags.TypeParameter, symbol.SymbolFlags.TypeParameterExcludes, nameStr, false, false);
                    } else {
                        _ = try self.bindAnonymousDeclaration(nodeIndex, symbol.SymbolFlags.TypeParameter, nameStr);
                    }
                } else {
                    _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.TypeParameter, symbol.SymbolFlags.TypeParameterExcludes, nameStr);
                }
                if (n.Constraint) |constraint| try self.bind(constraint);
                if (n.Expression) |expr| try self.bind(expr);
                if (n.DefaultType) |defaultType| try self.bind(defaultType);
            },
            .Parameter => |n| {
                if (n.name != 0) {
                    if (self.isBindingPattern(n.name)) {
                        const parentNode = self.ast.getNode(self.ast.getNodeParent(nodeIndex));
                        var index: usize = 0;
                        switch (parentNode) {
                            .FunctionDeclaration => |pn| index = self.getParamIndex(pn.Parameters, nodeIndex),
                            .FunctionExpression => |pn| index = self.getParamIndex(pn.Parameters, nodeIndex),
                            .ArrowFunction => |pn| index = self.getParamIndex(pn.Parameters, nodeIndex),
                            .MethodDeclaration => |pn| index = self.getParamIndex(pn.Parameters, nodeIndex),
                            .MethodSignature => |pn| index = self.getParamIndex(pn.Parameters, nodeIndex),
                            .CallSignature => |pn| index = self.getParamIndex(pn.Parameters, nodeIndex),
                            .ConstructSignature => |pn| index = self.getParamIndex(pn.Parameters, nodeIndex),
                            else => {},
                        }
                        var nameBuf: [16]u8 = undefined;
                        const nameStr = std.fmt.bufPrint(&nameBuf, "__{d}", .{index}) catch unreachable;
                        _ = try self.bindAnonymousDeclaration(nodeIndex, symbol.SymbolFlags.FunctionScopedVariable, nameStr);
                        try self.bind(n.name);
                    } else {
                        _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.FunctionScopedVariable, symbol.SymbolFlags.FunctionScopedVariableExcludes, self.getIdentifierName(n.name));
                        try self.bind(n.name);
                    }
                }

                // If this is a parameter property, declare the property symbol in the containing class.
                const parentNodeIndex = self.ast.getNodeParent(nodeIndex);
                if (parentNodeIndex != 0) {
                    const pNode = self.ast.getNode(parentNodeIndex);
                    var isConstructor = false;
                    switch (pNode) {
                        .Constructor => isConstructor = true,
                        .MethodDeclaration => |mn| {
                            if (std.mem.eql(u8, self.getIdentifierName(mn.name), "constructor")) {
                                isConstructor = true;
                            }
                        },
                        else => {},
                    }
                    if (isConstructor and ast_utils.hasSyntacticModifier(self.ast, nodeIndex, ast_utils.ModifierFlags.ParameterPropertyModifier)) {
                        const classNodeIndex = self.ast.getNodeParent(parentNodeIndex);
                        if (classNodeIndex != 0) {
                            const cNode = self.ast.getNode(classNodeIndex);
                            if (cNode == .ClassDeclaration or cNode == .ClassExpression) {
                                var flags = symbol.SymbolFlags.Property;
                                if (n.QuestionToken != null and n.QuestionToken.? != 0) flags |= symbol.SymbolFlags.Optional;

                                // We need to declare the symbol in the class's members.
                                // But `declareSymbolAndAddToSymbolTable` uses `self.container`.
                                // For constructor parameters, `self.container` is the constructor.
                                // We need to temporarily set `self.container` to the class!
                                const saveContainer = self.container;
                                self.container = classNodeIndex;
                                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, flags, symbol.SymbolFlags.PropertyExcludes, self.getIdentifierName(n.name));
                                self.container = saveContainer;
                            }
                        }
                    }
                }

                try self.bindParameterFlow(nodeIndex);
            },
            .PropertyDeclaration => |n| {
                var flags = symbol.SymbolFlags.Property;
                var excludes = symbol.SymbolFlags.PropertyExcludes;
                if ((n.modifierFlags & @import("../ast/ast_utils.zig").ModifierFlags.Accessor) != 0) {
                    flags = symbol.SymbolFlags.Accessor;
                    excludes = symbol.SymbolFlags.AccessorExcludes;
                }
                if (n.PostfixToken != null and n.PostfixToken.? != 0 and self.ast.getNode(n.PostfixToken.?) == .QuestionToken) flags |= symbol.SymbolFlags.Optional;
                _ = try self.bindPropertyOrMethodOrAccessor(nodeIndex, flags, excludes, self.getIdentifierName(n.name));
                if (n.Type) |t| try self.bind(t);
                if (n.Initializer) |initializer| try self.bind(initializer);
            },
            .GetAccessor => |n| {
                var flags = symbol.SymbolFlags.GetAccessor;
                if (n.PostfixToken != null and n.PostfixToken.? != 0 and self.ast.getNode(n.PostfixToken.?) == .QuestionToken) flags |= symbol.SymbolFlags.Optional;
                // Actually Go binder checks getOptionalSymbolFlagForNode but I'll do this for now
                _ = try self.bindPropertyOrMethodOrAccessor(nodeIndex, flags, symbol.SymbolFlags.GetAccessorExcludes, self.getIdentifierName(n.name));

                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;

                if (n.TypeParameters) |tp| try self.bindNodeList(tp);
                if (n.Parameters != 0) try self.bindNodeList(n.Parameters);
                if (n.Type) |t| try self.bind(t);
                if (n.Body) |b| try self.bind(b);

                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .SetAccessor => |n| {
                var flags = symbol.SymbolFlags.SetAccessor;
                if (n.PostfixToken != null and n.PostfixToken.? != 0 and self.ast.getNode(n.PostfixToken.?) == .QuestionToken) flags |= symbol.SymbolFlags.Optional;
                _ = try self.bindPropertyOrMethodOrAccessor(nodeIndex, flags, symbol.SymbolFlags.SetAccessorExcludes, self.getIdentifierName(n.name));

                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;

                if (n.TypeParameters) |tp| try self.bindNodeList(tp);
                if (n.Parameters != 0) try self.bindNodeList(n.Parameters);
                if (n.Type) |t| try self.bind(t);
                if (n.Body) |b| try self.bind(b);

                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .Block => |n| {
                const parent = self.ast.getNodeParent(nodeIndex);
                var isContainer = true;
                if (parent != 0) {
                    const parentNode = self.ast.getNode(parent);
                    if (ast_utils.isFunctionLike(parentNode) or parentNode == .ClassStaticBlockDeclaration) {
                        isContainer = false;
                    }
                }

                const saveBlockScopeContainer = self.blockScopeContainer;
                if (isContainer) {
                    self.blockScopeContainer = nodeIndex;
                }

                if (n.Statements != 0) {
                    try self.bindEachStatementFunctionsFirst(n.Statements);
                }

                if (isContainer) {
                    self.blockScopeContainer = saveBlockScopeContainer;
                }
            },
            .ModuleBlock => |n| {
                if (n.Statements != 0) {
                    try self.bindEachStatementFunctionsFirst(n.Statements);
                }
            },
            .IfStatement => |n| {
                try self.bind(n.Expression);
                try self.bind(n.ThenStatement);
                if (n.ElseStatement) |els| try self.bind(els);
            },
            .ReturnStatement => |n| {
                if (n.Expression) |expr| try self.bind(expr);
            },
            .ForInStatement, .ForOfStatement => |n| {
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.blockScopeContainer = nodeIndex;
                if (n.Initializer != 0) try self.bind(n.Initializer);
                if (n.Expression != 0) try self.bind(n.Expression);
                if (n.Statement != 0) try self.bind(n.Statement);
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .ForStatement => |n| {
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.blockScopeContainer = nodeIndex;
                if (n.Initializer) |ini| try self.bind(ini);
                if (n.Condition) |cond| try self.bind(cond);
                if (n.Incrementor) |inc| try self.bind(inc);
                if (n.Statement != 0) try self.bind(n.Statement);
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .CatchClause => |n| {
                self.checkStrictModeCatchClause(nodeIndex);
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.blockScopeContainer = nodeIndex;
                if (n.VariableDeclaration) |decl| try self.bind(decl);
                if (n.Block != 0) try self.bind(n.Block);
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .ExpressionStatement => |n| {
                try self.bind(n.Expression);
            },
            .ImportDeclaration => |n| {
                if (n.ImportClause) |clause| try self.bind(clause);
                try self.bind(n.ModuleSpecifier);
            },
            .JSImportDeclaration => |n| {
                if (n.ImportClause) |clause| try self.bind(clause);
                try self.bind(n.ModuleSpecifier);
            },
            .ImportEqualsDeclaration => |n| {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Alias, symbol.SymbolFlags.AliasExcludes, self.getIdentifierName(n.name));
                try self.bind(n.name);
                try self.bind(n.ModuleReference);
            },
            .NamespaceExportDeclaration => |n| {
                if ((n.Flags & ast_utils.NodeFlags.Ambient) != 0) {
                    _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Alias, symbol.SymbolFlags.AliasExcludes, self.getIdentifierName(n.name));
                }
                try self.bind(n.name);
            },
            .ImportClause => |n| {
                if (n.name) |nameIndex| {
                    _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Alias, symbol.SymbolFlags.AliasExcludes, self.getIdentifierName(nameIndex));
                }
                if (n.NamedBindings) |nb| {
                    try self.bind(nb);
                }
            },
            .NamedImports => |n| {
                if (n.Elements != 0) {
                    try self.bindNodeList(n.Elements);
                }
            },
            .NamespaceImport => |n| {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Alias, symbol.SymbolFlags.AliasExcludes, self.getIdentifierName(n.name));
            },
            .ImportSpecifier => |n| {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Alias, symbol.SymbolFlags.AliasExcludes, self.getIdentifierName(n.name));
            },
            .ExportSpecifier => |n| {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Alias, symbol.SymbolFlags.AliasExcludes, self.getIdentifierName(n.name));
            },
            .ExportDeclaration => |n| {
                const containerSym = self.ast.getNodeSymbol(self.container.?) orelse 0;
                if (containerSym == 0) {
                    _ = try self.bindAnonymousDeclaration(nodeIndex, symbol.SymbolFlags.ExportStar, symbol.InternalSymbolNameExportStar);
                } else if (n.ExportClause == null or n.ExportClause.? == 0) {
                    _ = try self.declareSymbolEx(.Exports, containerSym, nodeIndex, symbol.SymbolFlags.ExportStar, symbol.SymbolFlags.None, symbol.InternalSymbolNameExportStar, false, false);
                } else {
                    const exportClauseNode = self.ast.getNode(n.ExportClause.?);
                    if (exportClauseNode == .NamespaceExport) {
                        const nameStr = if (exportClauseNode.NamespaceExport.name != 0) self.getIdentifierName(exportClauseNode.NamespaceExport.name) else symbol.InternalSymbolNameMissing;
                        _ = try self.declareSymbolEx(.Exports, containerSym, n.ExportClause.?, symbol.SymbolFlags.Alias, symbol.SymbolFlags.AliasExcludes, nameStr, false, false);
                    }
                }
                if (n.ExportClause != null and n.ExportClause.? != 0) try self.bind(n.ExportClause.?);
                if (n.ModuleSpecifier != null and n.ModuleSpecifier.? != 0) try self.bind(n.ModuleSpecifier.?);
            },
            .ExportAssignment => |n| {
                const containerSym = self.ast.getNodeSymbol(self.container.?) orelse 0;
                var flags = symbol.SymbolFlags.Property;
                if (n.Expression != 0) {
                    if (self.isEntityNameExpression(n.Expression) or self.ast.getNode(n.Expression) == .ClassExpression) {
                        flags = symbol.SymbolFlags.Alias;
                    }
                }
                const excludes = symbol.SymbolFlags.All;
                if (n.IsExportEquals != 0) {
                    _ = try self.declareSymbolEx(.Exports, containerSym, nodeIndex, flags, excludes, symbol.InternalSymbolNameExportEquals, false, false);
                } else {
                    _ = try self.declareSymbolEx(.Exports, containerSym, nodeIndex, flags, excludes, "default", false, false);
                }
                if (n.Expression != 0) try self.bind(n.Expression);
            },
            .BinaryExpression => {
                if (self.isThisPropertyAssignment(nodeIndex)) {
                    try self.bindThisPropertyAssignment(nodeIndex);
                } else if (self.isModuleExportsAssignment(nodeIndex)) {
                    try self.bindModuleExportsAssignment(nodeIndex);
                } else if (self.isExportsPropertyAssignment(nodeIndex)) {
                    try self.bindExportsOrObjectDefineProperty(nodeIndex);
                } else if (self.getAssignmentDeclarationKindIsProperty(nodeIndex)) {
                    try self.bindExpandoPropertyAssignment(nodeIndex);
                }
                self.checkStrictModeBinaryExpression(nodeIndex);
                if (ast_utils.isDestructuringAssignment(self.ast, nodeIndex)) {
                    const saveInAssignmentPattern = self.inAssignmentPattern;
                    self.inAssignmentPattern = saveInAssignmentPattern;
                    try self.bindDestructuringAssignmentFlow(nodeIndex);
                } else {
                    try self.bindBinaryExpressionFlow(nodeIndex);
                }
            },
            .DeleteExpression => {
                self.checkStrictModeDeleteExpression(nodeIndex);
                try self.bindDeleteExpressionFlow(nodeIndex);
            },
            .PrefixUnaryExpression => {
                self.checkStrictModePrefixUnaryExpression(nodeIndex);
                try self.bindPrefixUnaryExpressionFlow(nodeIndex);
            },
            .PostfixUnaryExpression => {
                self.checkStrictModePostfixUnaryExpression(nodeIndex);
                try self.bindPostfixUnaryExpressionFlow(nodeIndex);
            },
            .WithStatement => |n| {
                self.checkStrictModeWithStatement(nodeIndex);
                try self.bind(n.Expression);
                try self.bind(n.Statement);
            },
            .LabeledStatement => |n| {
                self.checkStrictModeLabeledStatement(nodeIndex);
                try self.bind(n.Label);
                try self.bind(n.Statement);
            },
            .ObjectLiteralExpression => |n| {
                _ = try self.bindAnonymousDeclaration(nodeIndex, symbol.SymbolFlags.ObjectLiteral, symbol.InternalSymbolNameObject);
                const saveContainer = self.container;
                self.container = nodeIndex;
                if (n.Properties != 0) {
                    try self.bindNodeList(n.Properties);
                }
                self.container = saveContainer;
            },
            .TypeLiteral => |n| {
                _ = try self.bindAnonymousDeclaration(nodeIndex, symbol.SymbolFlags.TypeLiteral, symbol.InternalSymbolNameType);
                const saveContainer = self.container;
                self.container = nodeIndex;
                if (n.Members != 0) {
                    try self.bindNodeList(n.Members);
                }
                self.container = saveContainer;
            },
            .MappedType => |n| {
                _ = try self.bindAnonymousDeclaration(nodeIndex, symbol.SymbolFlags.TypeLiteral, symbol.InternalSymbolNameType);
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                if (n.ReadonlyToken) |rt| try self.bind(rt);
                try self.bind(n.TypeParameter);
                if (n.NameType) |nt| try self.bind(nt);
                if (n.QuestionToken) |qt| try self.bind(qt);
                if (n.Type) |t| try self.bind(t);
                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .PropertySignature => |n| {
                var flags = symbol.SymbolFlags.Property;
                if (n.PostfixToken != null and n.PostfixToken.? != 0 and self.ast.getNode(n.PostfixToken.?) == .QuestionToken) flags |= symbol.SymbolFlags.Optional;
                _ = try self.bindPropertyOrMethodOrAccessor(nodeIndex, flags, symbol.SymbolFlags.PropertyExcludes, self.getIdentifierName(n.name));
                if (n.Type != 0) try self.bind(n.Type);
                if (n.Initializer != 0) try self.bind(n.Initializer);
            },
            .PropertyAssignment => |n| {
                var flags = symbol.SymbolFlags.Property;
                if (n.PostfixToken != null and n.PostfixToken.? != 0 and self.ast.getNode(n.PostfixToken.?) == .QuestionToken) flags |= symbol.SymbolFlags.Optional;
                _ = try self.bindPropertyOrMethodOrAccessor(nodeIndex, flags, symbol.SymbolFlags.PropertyExcludes, self.getIdentifierName(n.name));
                if (n.Initializer != 0) try self.bind(n.Initializer);
            },
            .ShorthandPropertyAssignment => |n| {
                var flags = symbol.SymbolFlags.Property;
                if (n.PostfixToken != null and n.PostfixToken.? != 0 and self.ast.getNode(n.PostfixToken.?) == .QuestionToken) flags |= symbol.SymbolFlags.Optional;
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, flags, symbol.SymbolFlags.PropertyExcludes, self.getIdentifierName(n.name));
                if (n.ObjectAssignmentInitializer) |initializer| try self.bind(initializer);
            },
            .ObjectBindingPattern, .ArrayBindingPattern => |n| {
                if (n.Elements != 0) try self.bindNodeList(n.Elements);
            },
            .BindingElement => |n| {
                if (n.name) |nameIndex| {
                    try self.bindVariableDeclarationOrBindingElement(nodeIndex, nameIndex);
                    try self.bind(nameIndex);
                }
                try self.bindBindingElementFlow(nodeIndex);
            },
            .AwaitExpression => |n| {
                try self.bind(n.Expression);
            },
            .Identifier => {
                // self.checkContextualIdentifier(nodeIndex);
            },
            .NumericLiteral, .StringLiteral, .EndOfFile => {
                // Do nothing
            },
            .ThisKeyword, .SuperKeyword => {
                if (self.ast.getNode(nodeIndex) == .ThisKeyword) {
                    self.seenThisKeyword = true;
                }
            },
            .ThisType => {
                self.seenThisKeyword = true;
            },
            .QualifiedName => {
                if (self.currentFlow != 0 and ast_utils.isPartOfTypeQuery(self.ast, nodeIndex)) {
                    // self.setFlowNode(nodeIndex, self.currentFlow);
                }
            },
            .MetaProperty => {
                // self.setFlowNode(nodeIndex, self.currentFlow);
            },
            .PrivateIdentifier => {
                // self.checkPrivateIdentifier(nodeIndex);
            },
            .JsxAttributes => |n| {
                _ = try self.bindAnonymousDeclaration(nodeIndex, symbol.SymbolFlags.ObjectLiteral, "__jsxAttributes");
                const saveContainer = self.container;
                self.container = nodeIndex;
                if (n.Properties != 0) {
                    try self.bindNodeList(n.Properties);
                }
                self.container = saveContainer;
            },
            .JsxAttribute => |n| {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Property, symbol.SymbolFlags.PropertyExcludes, self.getIdentifierName(n.name));
                if (n.Initializer) |initializer| {
                    try self.bind(initializer);
                }
            },
            .ConditionalExpression => {
                try self.bindConditionalExpressionFlow(nodeIndex);
            },
            .PropertyAccessExpression, .ElementAccessExpression => {
                try self.bindAccessExpressionFlow(nodeIndex);
            },
            .CallExpression => {
                if (self.isRequireCall(nodeIndex)) _ = try self.setCommonJSModuleIndicator(nodeIndex);
                if (self.isObjectDefinePropertyExports(nodeIndex)) try self.bindExportsOrObjectDefineProperty(nodeIndex);
                try self.bindCallExpressionFlow(nodeIndex);
            },
            .NonNullExpression => {
                try self.bindNonNullExpressionFlow(nodeIndex);
            },
            .JSTypeAliasDeclaration => |n| {
                if (self.blockScopeContainer != null and self.ast.getNode(self.blockScopeContainer.?) != .SourceFile) {
                    _ = try self.bindBlockScopedDeclaration(nodeIndex, symbol.SymbolFlags.TypeAlias, symbol.SymbolFlags.TypeAliasExcludes, self.getIdentifierName(n.name));
                }
                const saveContainer = self.container;
                self.container = nodeIndex;
                if (n.TypeParameters) |tp| {
                    try self.bindNodeList(tp);
                }
                try self.bind(n.Type);
                self.container = saveContainer;
            },
            .ClassStaticBlockDeclaration => {
                // Static blocks are containers for flow, but their statements
                // still participate in class symbol binding (notably
                // `this.x = value` static property declarations).
                try self.bindChildren(nodeIndex);
            },
            else => {
                try self.bindChildren(nodeIndex);
            },
        }
    }

    fn isEntityNameExpression(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        const node = self.ast.getNode(nodeIndex);
        if (node == .Identifier) return true;
        if (node == .PropertyAccessExpression) {
            return self.isEntityNameExpression(node.PropertyAccessExpression.Expression) and self.ast.getNode(node.PropertyAccessExpression.name) == .Identifier;
        }
        return false;
    }

    fn getAssignmentDeclarationKindIsProperty(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        const node = self.ast.getNode(nodeIndex);
        if (node != .BinaryExpression) return false;
        const bin = node.BinaryExpression;

        const opToken = self.ast.getNode(bin.OperatorToken);
        if (opToken != .EqualsToken) return false;

        const leftNode = self.ast.getNode(bin.Left);
        if (leftNode == .PropertyAccessExpression) {
            const pae = leftNode.PropertyAccessExpression;
            const isExp = self.isEntityNameExpression(pae.Expression);
            const isId = self.ast.getNode(pae.name) == .Identifier;
            return isExp and isId;
        } else if (leftNode == .ElementAccessExpression) {
            const eae = leftNode.ElementAccessExpression;
            return self.isEntityNameExpression(eae.Expression);
        }
        return false;
    }

    fn isModuleExportsAssignment(self: *Binder, node_index: ast_gen.NodeIndex) bool {
        if (self.ast.getNode(node_index) != .BinaryExpression) return false;
        const binary = self.ast.getNode(node_index).BinaryExpression;
        if (self.ast.getNode(binary.OperatorToken) != .EqualsToken) return false;
        return self.isModuleExportsAccess(binary.Left);
    }

    fn isThisPropertyAssignment(self: *Binder, node_index: ast_gen.NodeIndex) bool {
        if (self.ast.getNode(node_index) != .BinaryExpression) return false;
        const binary = self.ast.getNode(node_index).BinaryExpression;
        if (self.ast.getNode(binary.OperatorToken) != .EqualsToken) return false;
        return switch (self.ast.getNode(binary.Left)) {
            .PropertyAccessExpression => |access| self.ast.getNode(access.Expression) == .ThisKeyword,
            .ElementAccessExpression => |access| self.ast.getNode(access.Expression) == .ThisKeyword,
            else => false,
        };
    }

    fn isRequireCall(self: *Binder, node_index: ast_gen.NodeIndex) bool {
        if (self.ast.getNode(node_index) != .CallExpression) return false;
        const call = self.ast.getNode(node_index).CallExpression;
        return self.isIdentifierText(call.Expression, "require") and self.ast.getNodeList(call.Arguments).len != 0;
    }

    fn isObjectDefinePropertyExports(self: *Binder, node_index: ast_gen.NodeIndex) bool {
        if (self.ast.getNode(node_index) != .CallExpression) return false;
        const call = self.ast.getNode(node_index).CallExpression;
        const callee = self.ast.getNode(call.Expression);
        if (callee != .PropertyAccessExpression or !self.isIdentifierText(callee.PropertyAccessExpression.Expression, "Object") or !self.isIdentifierText(callee.PropertyAccessExpression.name, "defineProperty")) return false;
        const arguments = self.ast.getNodeList(call.Arguments);
        if (arguments.len < 2) return false;
        return self.isIdentifierText(arguments[0], "exports") or self.isModuleExportsAccess(arguments[0]);
    }

    fn isExportsPropertyAssignment(self: *Binder, node_index: ast_gen.NodeIndex) bool {
        if (self.ast.getNode(node_index) != .BinaryExpression) return false;
        const binary = self.ast.getNode(node_index).BinaryExpression;
        if (self.ast.getNode(binary.OperatorToken) != .EqualsToken) return false;
        return switch (self.ast.getNode(binary.Left)) {
            .PropertyAccessExpression => |access| self.isIdentifierText(access.Expression, "exports") or self.isModuleExportsAccess(access.Expression),
            .ElementAccessExpression => |access| self.isIdentifierText(access.Expression, "exports") or self.isModuleExportsAccess(access.Expression),
            else => false,
        };
    }

    fn isModuleExportsAccess(self: *Binder, node_index: ast_gen.NodeIndex) bool {
        return switch (self.ast.getNode(node_index)) {
            .PropertyAccessExpression => |access| self.isIdentifierText(access.Expression, "module") and self.isIdentifierText(access.name, "exports"),
            .ElementAccessExpression => |access| self.isIdentifierText(access.Expression, "module") and self.isStringLiteralText(access.ArgumentExpression, "exports"),
            else => false,
        };
    }

    fn isIdentifierText(self: *Binder, node_index: ast_gen.NodeIndex, text: []const u8) bool {
        return self.ast.getNode(node_index) == .Identifier and std.mem.eql(u8, ast_utils.getText(self.ast, node_index), text);
    }

    fn isStringLiteralText(self: *Binder, node_index: ast_gen.NodeIndex, text: []const u8) bool {
        return self.ast.getNode(node_index) == .StringLiteral and std.mem.eql(u8, ast_utils.getText(self.ast, node_index), text);
    }

    fn bindExpandoPropertyAssignment(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        try self.expandoAssignments.append(self.allocator, .{
            .node = nodeIndex,
            .container = if (self.container != null) self.container.? else 0,
            .blockScopeContainer = if (self.blockScopeContainer != null) self.blockScopeContainer.? else 0,
        });
    }

    fn lookupName(self: *Binder, name: []const u8, containerIndex: ast_gen.NodeIndex) ?ast_gen.SymbolIndex {
        var current = containerIndex;
        while (current != 0) {
            if (self.nodeLocals.getPtr(current)) |locals| {
                if (locals.get(name)) |symIndex| {
                    const localSym = self.symbols.items[symIndex];
                    if (localSym.ExportSymbol) |exportSymIndex| {
                        return exportSymIndex;
                    }
                    return symIndex;
                }
            }
            const node = self.ast.getNode(current);
            if (node == .SourceFile) {
                return null;
            }
            current = self.ast.getNodeParent(current);
        }
        return null;
    }

    fn lookupEntity(self: *Binder, nodeIndex: ast_gen.NodeIndex, containerIndex: ast_gen.NodeIndex) ?ast_gen.SymbolIndex {
        const node = self.ast.getNode(nodeIndex);
        if (node == .Identifier) {
            const name = self.getIdentifierName(nodeIndex);
            return self.lookupName(name, containerIndex);
        }
        return null;
    }

    fn isExpandoInitializer(self: *Binder, decl: ast_gen.NodeIndex, initializerNode: ast_gen.NodeIndex) bool {
        if (initializerNode == 0) return false;
        const initNode = self.ast.getNode(initializerNode);
        if (initNode == .FunctionExpression or initNode == .ArrowFunction) {
            return true;
        }
        if (ast_utils.isInJSFile(self.ast, initializerNode)) {
            if (initNode == .ClassExpression) return true;
            if (initNode == .ObjectLiteralExpression) {
                const props = initNode.ObjectLiteralExpression.Properties;
                const propCount = if (props != 0) self.ast.getNodeList(props).len else 0;
                if (propCount == 0) {
                    const declNode = self.ast.getNode(decl);
                    if (declNode == .VariableDeclaration) {
                        return declNode.VariableDeclaration.Type == null;
                    } else if (declNode == .BinaryExpression) {
                        return true; // No type on BinaryExpression assignment
                    }
                }
            }
        }
        return false;
    }

    fn getInitializerSymbol(self: *Binder, symIndex: ?ast_gen.SymbolIndex) ?ast_gen.SymbolIndex {
        if (symIndex == null) return null;
        const sym = self.symbols.items[symIndex.?];
        const declaration = sym.ValueDeclaration;
        if (declaration == null or declaration.? == 0) return null;

        const declNode = self.ast.getNode(declaration.?);
        if (declNode == .FunctionDeclaration or (ast_utils.isInJSFile(self.ast, declaration.?) and declNode == .ClassDeclaration)) {
            return symIndex.?;
        } else if (declNode == .VariableDeclaration) {
            const varDecl = declNode.VariableDeclaration;
            const parentNode = self.ast.getNode(self.ast.getNodeParent(declaration.?));
            var isConst = false;
            if (parentNode == .VariableDeclarationList) {
                if (parentNode.VariableDeclarationList.Flags & 2 != 0) { // NodeFlags.Const = 2
                    isConst = true;
                }
            }
            if (isConst or ast_utils.isInJSFile(self.ast, declaration.?)) {
                if (varDecl.Initializer) |initializerNode| {
                    if (self.isExpandoInitializer(declaration.?, initializerNode)) {
                        const initSym = self.ast.getNodeSymbol(initializerNode);
                        if (initSym != 0) return initSym;
                    }
                }
            }
        } else if (ast_utils.isInJSFile(self.ast, declaration.?) and declNode == .BinaryExpression) {
            const binExp = declNode.BinaryExpression;
            if (self.isExpandoInitializer(declaration.?, binExp.Right)) {
                const initSym = self.ast.getNodeSymbol(binExp.Right);
                if (initSym != 0) return initSym;
            }
        }
        return null;
    }

    fn getParentOfPropertyAssignment(self: *Binder, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const node = self.ast.getNode(nodeIndex);
        if (node == .BinaryExpression) {
            const left = self.ast.getNode(node.BinaryExpression.Left);
            if (left == .PropertyAccessExpression) {
                return left.PropertyAccessExpression.Expression;
            } else if (left == .ElementAccessExpression) {
                return left.ElementAccessExpression.Expression;
            }
        }
        return 0;
    }

    fn getDeclarationNameForExpando(self: *Binder, nodeIndex: ast_gen.NodeIndex) []const u8 {
        const node = self.ast.getNode(nodeIndex);
        if (node == .BinaryExpression) {
            const left = self.ast.getNode(node.BinaryExpression.Left);
            if (left == .PropertyAccessExpression) {
                return self.getIdentifierName(left.PropertyAccessExpression.name);
            } else if (left == .ElementAccessExpression) {
                const argument = left.ElementAccessExpression.ArgumentExpression;
                if (self.ast.getNode(argument) == .StringLiteral or self.ast.getNode(argument) == .NumericLiteral) return ast_utils.getText(self.ast, argument);
            }
        }
        return symbol.InternalSymbolNameMissing;
    }

    fn bindDeferredExpandoAssignment(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const parent = self.getParentOfPropertyAssignment(nodeIndex);
        if (parent == 0) return;

        var symbolIndex = self.lookupEntity(parent, if (self.blockScopeContainer != null) self.blockScopeContainer.? else 0);
        if (symbolIndex == null) {
            symbolIndex = self.lookupEntity(parent, if (self.container != null) self.container.? else 0);
        }
        symbolIndex = self.getInitializerSymbol(symbolIndex);
        if (symbolIndex) |symIndex| {
            const declName = self.getDeclarationNameForExpando(nodeIndex);

            var shouldDeclare = true;
            if (self.symbolExports.getPtr(symIndex)) |exports| {
                if (exports.get(declName)) |existingSymIndex| {
                    const existingSym = &self.symbols.items[existingSymIndex];
                    if ((existingSym.Flags & symbol.SymbolFlags.Assignment) == 0) {
                        shouldDeclare = false;
                    }
                }
            }

            if (shouldDeclare) {
                _ = try self.declareSymbolEx(.Exports, symIndex, nodeIndex, symbol.SymbolFlags.Property | symbol.SymbolFlags.Assignment, symbol.SymbolFlags.PropertyExcludes, declName, false, false);
            } else {}
        } else {}
    }

    fn bindDeferredExpandoAssignments(self: *Binder) !void {
        for (self.expandoAssignments.items) |info| {
            self.container = if (info.container == 0) null else info.container;
            self.blockScopeContainer = if (info.blockScopeContainer == 0) null else info.blockScopeContainer;
            try self.bindDeferredExpandoAssignment(info.node);
        }
    }

    pub fn bindChildren(self: *Binder, nodeIndex: ast_gen.NodeIndex) anyerror!void {
        if (nodeIndex == 0) return;
        const node = self.ast.getNode(nodeIndex);
        if (node == .SourceFile) {
            try self.bindEachStatementFunctionsFirst(self.ast.getNode(nodeIndex).SourceFile.Statements);
            return;
        }
        if (node == .Block) {
            try self.bindEachStatementFunctionsFirst(self.ast.getNode(nodeIndex).Block.Statements);
            return;
        }
        if (node == .ModuleBlock) {
            try self.bindEachStatementFunctionsFirst(self.ast.getNode(nodeIndex).ModuleBlock.Statements);
            return;
        }
        var visitor = BinderVisitor{ .binder = self };
        try ast.forEachChild(self.ast, nodeIndex, &visitor);
    }

    pub fn bindEachStatementFunctionsFirst(self: *Binder, listIndex: u32) anyerror!void {
        if (listIndex == 0) return;
        const list = self.ast.getNodeList(listIndex);
        for (list) |child| {
            if (self.ast.getNode(child) == .FunctionDeclaration) {
                try self.bind(child);
            }
        }
        for (list) |child| {
            if (self.ast.getNode(child) != .FunctionDeclaration) {
                try self.bind(child);
            }
        }
    }

    pub fn bindNodeList(self: *Binder, listIndex: u32) anyerror!void {
        if (listIndex == 0) return;
        const list = self.ast.getNodeList(listIndex);
        for (list) |child| {
            try self.bind(child);
        }
    }

    fn declareSymbol(self: *Binder, nodeIndex: ast_gen.NodeIndex, flags: u32, name: []const u8) !void {
        _ = try self.declareSymbolEx(.Locals, self.container.?, nodeIndex, flags, symbol.SymbolFlags.None, name, false, false);
    }

    pub const SymbolTableType = enum { Locals, Exports, Members, None };

    fn hasCombinedExportModifier(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        var current: ast_gen.NodeIndex = nodeIndex;
        while (current != 0) {
            if (ast_utils.hasSyntacticModifier(self.ast, current, ast_utils.ModifierFlags.Export)) {
                return true;
            }
            const node = self.ast.getNode(current);
            switch (node) {
                .BindingElement => current = self.ast.getNodeParent(current),
                .ArrayBindingPattern => current = self.ast.getNodeParent(current),
                .ObjectBindingPattern => current = self.ast.getNodeParent(current),
                .VariableDeclaration => current = self.ast.getNodeParent(current),
                .VariableDeclarationList => current = self.ast.getNodeParent(current),
                else => break,
            }
        }
        return false;
    }

    pub fn bindAnonymousDeclaration(self: *Binder, nodeIndex: ast_gen.NodeIndex, flags: u32, name: []const u8) !ast_gen.SymbolIndex {
        const symIndex: ast_gen.SymbolIndex = @intCast(self.symbols.items.len);

        try self.symbols.append(self.allocator, .{
            .Flags = flags,
            .Name = try self.allocator.dupe(u8, name),
            .Declarations = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty,
            .ValueDeclaration = if ((flags & symbol.SymbolFlags.Value) != 0 and nodeIndex != 0) nodeIndex else null,
            .Members = symbol.SymbolTable.empty,
            .Exports = symbol.SymbolTable.empty,
            .Parent = null,
            .ExportSymbol = null,
        });
        if (nodeIndex != 0) {
            var sym = &self.symbols.items[symIndex];
            try sym.Declarations.append(self.allocator, nodeIndex);
        }
        self.symbolCount += 1;

        if (nodeIndex != 0) {
            if (self.ast.getNodeSymbol(nodeIndex) == null) {
                self.ast.setNodeSymbol(nodeIndex, symIndex);
            }
        }
        return symIndex;
    }

    fn getParamIndex(self: *Binder, parametersList: ast_gen.NodeListIndex, nodeIndex: ast_gen.NodeIndex) usize {
        if (parametersList != 0) {
            const params = self.ast.getNodeList(parametersList);
            for (params, 0..) |p, i| {
                if (p == nodeIndex) {
                    return i;
                }
            }
        }
        return 0;
    }

    fn bindVariableDeclarationOrBindingElement(self: *Binder, nodeIndex: ast_gen.NodeIndex, nameIndex: ast_gen.NodeIndex) !void {
        if (!self.isBindingPattern(nameIndex)) {
            const name = self.getIdentifierName(nameIndex);
            const isBlockOrCatchScoped = ast_utils.isBlockScopedVariable(self.ast, nodeIndex) or self.isCatchClauseVariable(nodeIndex);
            if (isBlockOrCatchScoped) {
                _ = try self.bindBlockScopedDeclaration(nodeIndex, symbol.SymbolFlags.BlockScopedVariable, symbol.SymbolFlags.BlockScopedVariableExcludes, name);
            } else if (self.isPartOfParameterDeclaration(nodeIndex)) {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.FunctionScopedVariable, symbol.SymbolFlags.ParameterExcludes, name);
            } else {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.FunctionScopedVariable, symbol.SymbolFlags.FunctionScopedVariableExcludes, name);
            }
        }
    }

    fn bindBlockScopedDeclaration(self: *Binder, nodeIndex: ast_gen.NodeIndex, flags: u32, excludes: u32, name: []const u8) !ast_gen.SymbolIndex {
        const blockScopeNode = self.ast.getNode(self.blockScopeContainer.?);
        var symIndex: ast_gen.SymbolIndex = 0;
        switch (blockScopeNode) {
            .ModuleDeclaration => {
                symIndex = try self.declareModuleMember(nodeIndex, flags, excludes, name);
            },
            .SourceFile => {
                symIndex = try self.declareSourceFileMember(nodeIndex, flags, excludes, name);
            },
            else => {
                symIndex = try self.declareSymbolEx(.Locals, self.blockScopeContainer.?, nodeIndex, flags, excludes, name, false, false);
            },
        }

        if (nodeIndex != 0) {
            if (self.ast.getNodeSymbol(nodeIndex) == null) {}
        }
        return symIndex;
    }

    fn isCatchClauseVariable(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        var current = nodeIndex;
        while (current != 0) {
            const node = self.ast.getNode(current);
            if (node == .CatchClause) return true;
            if (node == .Block or node == .SourceFile) return false;
            current = self.ast.getNodeParent(current);
        }
        return false;
    }

    fn isPartOfParameterDeclaration(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        var current = nodeIndex;
        while (current != 0) {
            const node = self.ast.getNode(current);
            switch (node) {
                .Parameter => return true,
                .Block, .SourceFile => return false,
                else => {},
            }
            current = self.ast.getNodeParent(current);
        }
        return false;
    }

    fn bindFunctionOrConstructorType(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const symbolFlags = symbol.SymbolFlags.Signature;
        const symIndex = @as(ast_gen.SymbolIndex, @intCast(self.symbols.items.len));

        const node = self.ast.getNode(nodeIndex);
        const name = if (node == .FunctionType or node == .CallSignature) symbol.InternalSymbolNameCall else symbol.InternalSymbolNameNew;

        try self.symbols.append(self.allocator, .{
            .Name = try self.allocator.dupe(u8, name),
            .Flags = symbolFlags,
            .Declarations = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty,
            .ValueDeclaration = null,
            .Members = symbol.SymbolTable.empty,
            .Exports = symbol.SymbolTable.empty,
            .Parent = null,
            .ExportSymbol = null,
        });
        self.symbolCount += 1;
        try self.symbols.items[symIndex].Declarations.append(self.allocator, nodeIndex);

        const typeLiteralSymIndex = @as(ast_gen.SymbolIndex, @intCast(self.symbols.items.len));
        try self.symbols.append(self.allocator, .{
            .Name = try self.allocator.dupe(u8, "__type"),
            .Flags = symbol.SymbolFlags.TypeLiteral,
            .Declarations = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty,
            .ValueDeclaration = null,
            .Members = symbol.SymbolTable.empty,
            .Exports = symbol.SymbolTable.empty,
            .Parent = null,
            .ExportSymbol = null,
        });
        self.symbolCount += 1;
        try self.symbols.items[typeLiteralSymIndex].Declarations.append(self.allocator, nodeIndex);

        try symbol.symbolTablePut(&self.symbols.items[typeLiteralSymIndex].Members, self.allocator, "", symIndex);
        self.ast.setNodeSymbol(nodeIndex, typeLiteralSymIndex);
    }

    fn bindPropertyOrMethodOrAccessor(self: *Binder, nodeIndex: ast_gen.NodeIndex, flags: u32, excludes: u32, name: []const u8) !ast_gen.SymbolIndex {
        if (@import("../ast/ast_utils.zig").hasDynamicName(self.ast, nodeIndex)) {
            return try self.bindAnonymousDeclaration(nodeIndex, flags, symbol.InternalSymbolNameComputed);
        } else {
            return try self.declareSymbolAndAddToSymbolTable(nodeIndex, flags, excludes, name);
        }
    }

    fn declareSymbolAndAddToSymbolTable(self: *Binder, nodeIndex: ast_gen.NodeIndex, flags: u32, excludes: u32, name: []const u8) !ast_gen.SymbolIndex {
        if (name.len == 0) {
            return self.bindAnonymousDeclaration(nodeIndex, flags, "");
        }
        const containerNode = self.ast.getNode(self.container.?);
        var symIndex: ast_gen.SymbolIndex = 0;

        switch (containerNode) {
            .ModuleDeclaration => {
                symIndex = try self.declareModuleMember(nodeIndex, flags, excludes, name);
            },
            .SourceFile => {
                if (nodeIndex == self.file) {
                    symIndex = try self.declareSymbolEx(.None, 0, nodeIndex, flags, excludes, name, false, false);
                } else {
                    symIndex = try self.declareSourceFileMember(nodeIndex, flags, excludes, name);
                }
            },
            .ClassDeclaration, .ClassExpression => {
                symIndex = try self.declareClassMember(nodeIndex, flags, excludes, name);
            },
            .EnumDeclaration => {
                const containerSym = self.ast.getNodeSymbol(self.container.?) orelse 0;
                symIndex = try self.declareSymbolEx(.Exports, containerSym, nodeIndex, flags, excludes, name, false, false);
            },
            .TypeLiteral, .ObjectLiteralExpression, .InterfaceDeclaration, .JsxAttributes => {
                const containerSym = self.ast.getNodeSymbol(self.container.?) orelse 0;
                symIndex = try self.declareSymbolEx(.Members, containerSym, nodeIndex, flags, excludes, name, false, false);
            },
            .CallSignature, .ConstructSignature, .IndexSignature, .MethodDeclaration, .MethodSignature, .Constructor, .GetAccessor, .SetAccessor, .FunctionDeclaration, .FunctionExpression, .ArrowFunction, .TypeAliasDeclaration, .MappedType, .FunctionType, .ConstructorType, .ClassStaticBlockDeclaration => {
                symIndex = try self.declareSymbolEx(.Locals, self.container.?, nodeIndex, flags, excludes, name, false, false);
            },
            else => {
                const isDefaultExport = ast_utils.hasSyntacticModifier(self.ast, nodeIndex, ast_utils.ModifierFlags.Default);
                const hasExportModifier = self.hasCombinedExportModifier(nodeIndex);
                const isExport = hasExportModifier or isDefaultExport;
                if (isExport) {
                    symIndex = try self.declareModuleMember(nodeIndex, flags, excludes, name);
                } else {
                    symIndex = try self.declareSymbolEx(.Locals, self.container.?, nodeIndex, flags, excludes, name, false, false);
                }
            },
        }

        if (nodeIndex != 0) {
            if (self.ast.getNodeSymbol(nodeIndex) == null) {}
        }
        return symIndex;
    }

    fn isModuleMember(self: *Binder, nodeIndex: ast_gen.NodeIndex, flags: u32) bool {
        _ = flags;
        _ = nodeIndex;
        if (ast_utils.isExternalOrCommonJSModule(self.ast, self.file)) {
            return true;
        }
        return false;
    }

    fn declareSourceFileMember(self: *Binder, nodeIndex: ast_gen.NodeIndex, flags: u32, excludes: u32, name: []const u8) !ast_gen.SymbolIndex {
        if (ast_utils.isExternalOrCommonJSModule(self.ast, self.file)) {
            return try self.declareModuleMember(nodeIndex, flags, excludes, name);
        }
        return try self.declareSymbolEx(.Locals, self.file, nodeIndex, flags, excludes, name, false, false);
    }

    fn declareClassMember(self: *Binder, nodeIndex: ast_gen.NodeIndex, flags: u32, excludes: u32, name: []const u8) !ast_gen.SymbolIndex {
        const containerSym = self.ast.getNodeSymbol(self.container.?) orelse 0;
        if (ast_utils.hasSyntacticModifier(self.ast, nodeIndex, ast_utils.ModifierFlags.Static)) {
            return try self.declareSymbolEx(.Exports, containerSym, nodeIndex, flags, excludes, name, false, false);
        }
        return try self.declareSymbolEx(.Members, containerSym, nodeIndex, flags, excludes, name, false, false);
    }

    fn declareModuleMember(self: *Binder, nodeIndex: ast_gen.NodeIndex, flags: u32, excludes: u32, name: []const u8) !ast_gen.SymbolIndex {
        const hasExportModifier = self.hasCombinedExportModifier(nodeIndex);
        var isExportContext = false;
        if (self.container != null and self.container.? != 0) {
            const containerNode = self.ast.getNode(self.container.?);
            if (containerNode == .ModuleDeclaration) {
                isExportContext = (containerNode.ModuleDeclaration.Flags & ast_utils.NodeFlags.ExportContext) != 0;
            } else if (containerNode == .SourceFile) {
                isExportContext = (containerNode.SourceFile.Flags & ast_utils.NodeFlags.ExportContext) != 0;
            }
        }

        if ((flags & symbol.SymbolFlags.Alias) != 0) {
            const node = self.ast.getNode(nodeIndex);
            const isExportSpecifier = node == .ExportSpecifier;
            const isImportEquals = node == .ImportEqualsDeclaration;
            const isExportDeclaration = node == .ExportDeclaration;
            const isExportAssignment = node == .ExportAssignment;
            if (isExportSpecifier or (isImportEquals and hasExportModifier) or isExportDeclaration or isExportAssignment) {
                const containerSym = self.ast.getNodeSymbol(self.container.?) orelse 0;
                return try self.declareSymbolEx(.Exports, containerSym, nodeIndex, flags, excludes, name, false, false);
            }
            return try self.declareSymbolEx(.Locals, self.container.?, nodeIndex, flags, excludes, name, false, false);
        }

        if (!ast_utils.isAmbientModule(self.ast, nodeIndex) and (hasExportModifier or isExportContext)) {
            const isDefaultExport = ast_utils.hasSyntacticModifier(self.ast, nodeIndex, ast_utils.ModifierFlags.Default);
            const exportKind = if ((flags & symbol.SymbolFlags.Value) != 0) symbol.SymbolFlags.ExportValue else symbol.SymbolFlags.None;
            const exportName = if (isDefaultExport) symbol.InternalSymbolNameDefault else name;

            if (!ast_utils.isLocalsContainer(self.ast, self.container.?) or (isDefaultExport and std.mem.eql(u8, name, symbol.InternalSymbolNameMissing))) {
                const containerSym = self.ast.getNodeSymbol(self.container.?) orelse 0;
                return try self.declareSymbolEx(.Exports, containerSym, nodeIndex, flags, excludes, exportName, false, false);
            }

            const local = try self.declareSymbolEx(.Locals, self.container.?, nodeIndex, exportKind, excludes, name, false, false);
            const containerSym = self.ast.getNodeSymbol(self.container.?) orelse 0;
            const exportSym = try self.declareSymbolEx(.Exports, containerSym, nodeIndex, flags, excludes, exportName, false, false);
            const localSymbol = &self.symbols.items[local];
            localSymbol.ExportSymbol = exportSym;
            try self.ast.localSymbols.put(self.allocator, nodeIndex, local);
            return local;
        }
        return try self.declareSymbolEx(.Locals, self.container.?, nodeIndex, flags, excludes, name, false, false);
    }

    fn declareSymbolEx(self: *Binder, tableType: SymbolTableType, tableId: u32, nodeIndex: ast_gen.NodeIndex, flags: u32, excludes: u32, name: []const u8, isReplaceableByMethod: bool, isComputedName: bool) !ast_gen.SymbolIndex {
        _ = isReplaceableByMethod;
        _ = isComputedName;

        var existingSymIndex: ?ast_gen.SymbolIndex = null;

        if (std.mem.eql(u8, name, symbol.InternalSymbolNameMissing)) {
            const symIndex: ast_gen.SymbolIndex = @intCast(self.symbols.items.len);
            try self.symbols.append(self.allocator, .{
                .Flags = flags,
                .Name = try self.allocator.dupe(u8, name),
                .Declarations = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty,
                .ValueDeclaration = if ((flags & symbol.SymbolFlags.Value) != 0 and nodeIndex != 0) nodeIndex else null,
                .Members = symbol.SymbolTable.empty,
                .Exports = symbol.SymbolTable.empty,
                .Parent = null,
                .ExportSymbol = null,
            });
            if (nodeIndex != 0) {
                var sym = &self.symbols.items[symIndex];
                try sym.Declarations.append(self.allocator, nodeIndex);
            }
            self.symbolCount += 1;
            if (nodeIndex != 0) {
                self.ast.setNodeSymbol(nodeIndex, symIndex);
            }
            return symIndex;
        }

        switch (tableType) {
            .Locals => {
                if (self.nodeLocals.getPtr(tableId)) |containerLocals| {
                    existingSymIndex = containerLocals.get(name);
                }
            },
            .Exports => {
                if (self.symbolExports.getPtr(tableId)) |containerExports| {
                    existingSymIndex = containerExports.get(name);
                }
            },
            .Members => {
                if (self.symbolMembers.getPtr(tableId)) |containerMembers| {
                    existingSymIndex = containerMembers.get(name);
                }
            },
            .None => {
                existingSymIndex = null;
            },
        }

        var isConflict = false;

        if (existingSymIndex) |symIndex| {
            var sym = &self.symbols.items[symIndex];
            // Check for conflict
            // Note: excludes are flags that this new symbol CANNOT coexist with in the same container under the same name.
            if ((sym.Flags & excludes) != 0) {
                // If it's a conflict, we create a new symbol but DO NOT add it to the symbol table.
                // We do this by clearing existingSymIndex and setting a flag so we don't put it in the table.
                existingSymIndex = null;
                isConflict = true;

                if ((sym.Flags & symbol.SymbolFlags.Accessor) != 0 and (sym.Flags & symbol.SymbolFlags.Accessor) != (flags & symbol.SymbolFlags.Accessor)) {
                    sym.Flags |= symbol.SymbolFlags.Accessor;
                }
            } else {
                sym.Flags |= flags;
                if (nodeIndex != 0) {
                    if ((flags & symbol.SymbolFlags.Value) != 0 and sym.ValueDeclaration == null) {
                        sym.ValueDeclaration = nodeIndex;
                    }
                    try sym.Declarations.append(self.allocator, nodeIndex);
                    self.ast.setNodeSymbol(nodeIndex, symIndex);
                }
                return symIndex;
            }
        }

        const symIndex: ast_gen.SymbolIndex = @intCast(self.symbols.items.len);
        try self.symbols.append(self.allocator, .{
            .Flags = flags,
            .Name = try self.allocator.dupe(u8, name),
            .Declarations = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty,
            .ValueDeclaration = if ((flags & symbol.SymbolFlags.Value) != 0 and nodeIndex != 0) nodeIndex else null,
            .Members = symbol.SymbolTable.empty,
            .Exports = symbol.SymbolTable.empty,
            .Parent = if (tableType == .Exports or tableType == .Members) tableId else null,
            .ExportSymbol = null,
        });

        if (nodeIndex != 0) {
            var sym = &self.symbols.items[symIndex];
            try sym.Declarations.append(self.allocator, nodeIndex);
        }
        self.symbolCount += 1;
        if (nodeIndex != 0) {
            self.ast.setNodeSymbol(nodeIndex, symIndex);
        }

        if (flags == 0) {}
        if (!isConflict) {
            switch (tableType) {
                .Locals => {
                    var res = try self.nodeLocals.getOrPut(tableId);
                    if (!res.found_existing) {
                        res.value_ptr.* = std.StringHashMap(ast_gen.SymbolIndex).init(self.allocator);
                    }
                    try res.value_ptr.put(self.symbols.items[symIndex].Name, symIndex);
                },
                .Exports => {
                    var res = try self.symbolExports.getOrPut(tableId);
                    if (!res.found_existing) {
                        res.value_ptr.* = std.StringHashMap(ast_gen.SymbolIndex).init(self.allocator);
                    }
                    try res.value_ptr.put(self.symbols.items[symIndex].Name, symIndex);
                },
                .Members => {
                    var res = try self.symbolMembers.getOrPut(tableId);
                    if (!res.found_existing) {
                        res.value_ptr.* = std.StringHashMap(ast_gen.SymbolIndex).init(self.allocator);
                    }
                    try res.value_ptr.put(self.symbols.items[symIndex].Name, symIndex);
                },
                .None => {},
            }
        }

        return symIndex;
    }

    fn isBindingPattern(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        const node = self.ast.getNode(nodeIndex);
        switch (node) {
            .ObjectBindingPattern, .ArrayBindingPattern => return true,
            else => return false,
        }
    }

    fn getInferTypeContainer(self: *Binder, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
        var current = nodeIndex;
        while (current != 0) {
            const parent = self.ast.getNodeParent(current);
            if (parent != 0) {
                const parentNode = self.ast.getNode(parent);
                if (parentNode == .ConditionalType) {
                    if (parentNode.ConditionalType.ExtendsType == current) {
                        return parent; // return the ConditionalType node itself
                    }
                }
            }
            current = parent;
        }
        return 0;
    }

    fn getContainingClass(self: *Binder) ast_gen.NodeIndex {
        var current: ast_gen.NodeIndex = self.container orelse 0;
        while (current != 0) {
            const node = self.ast.getNode(current);
            switch (node) {
                .ClassDeclaration, .ClassExpression => return current,
                else => current = self.ast.getNodeParent(current),
            }
        }
        return 0;
    }

    fn getIdentifierName(self: *Binder, nodeIndex: ast_gen.NodeIndex) []const u8 {
        const node = self.ast.getNode(nodeIndex);
        switch (node) {
            .Identifier => |i| return i.Text,
            .StringLiteral => |i| return i.Text,
            .NumericLiteral => |i| return i.Text,
            .JsxNamespacedName => |j| {
                const namespaceNode = self.ast.getNode(j.Namespace);
                const nameNode = self.ast.getNode(j.name);
                if (namespaceNode == .Identifier and nameNode == .Identifier) {
                    return std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ namespaceNode.Identifier.Text, nameNode.Identifier.Text }) catch symbol.InternalSymbolNameMissing;
                }
                return symbol.InternalSymbolNameMissing;
            },
            .PrivateIdentifier => |i| {
                const classNode = self.getContainingClass();
                if (classNode == 0) return symbol.InternalSymbolNameMissing;
                const classSym = self.ast.getNodeSymbol(classNode) orelse return symbol.InternalSymbolNameMissing;
                return std.fmt.allocPrint(self.allocator, "__#{d}@{s}", .{ classSym, i.Text }) catch symbol.InternalSymbolNameMissing;
            },
            .ComputedPropertyName => |c| {
                const expr = self.ast.getNode(c.Expression);
                if (expr == .StringLiteral) {
                    return expr.StringLiteral.Text;
                } else if (expr == .NumericLiteral) {
                    return expr.NumericLiteral.Text;
                }
                return symbol.InternalSymbolNameMissing;
            },
            else => return symbol.InternalSymbolNameMissing,
        }
    }

    fn bindCommonJSTypeExports(self: *Binder, moduleSymIndex: ast_gen.SymbolIndex) !void {
        if (self.symbolExports.getPtr(moduleSymIndex)) |exportsTable| {
            if (exportsTable.get(symbol.InternalSymbolNameExportEquals)) |exportEqualsSymIndex| {
                var iterator = exportsTable.iterator();
                while (iterator.next()) |entry| {
                    const symName = entry.key_ptr.*;
                    const sym = entry.value_ptr.*;
                    if (!std.mem.eql(u8, symName, symbol.InternalSymbolNameExportEquals)) {
                        const symObj = self.symbols.items[sym];
                        if ((symObj.Flags & (symbol.SymbolFlags.Type | symbol.SymbolFlags.Namespace)) != 0) {
                            var exportEqualsSym = &self.symbols.items[exportEqualsSymIndex];

                            var exportEqualsExports = try self.symbolExports.getOrPut(exportEqualsSymIndex);
                            if (!exportEqualsExports.found_existing) {
                                exportEqualsExports.value_ptr.* = std.StringHashMap(ast_gen.SymbolIndex).init(self.allocator);
                            }
                            try exportEqualsExports.value_ptr.put(symName, sym);

                            exportEqualsSym.Flags |= symbol.SymbolFlags.NamespaceModule;
                        }
                    }
                }
            }
        }
    }

    pub fn checkStrictModeFunctionName(self: *Binder, nodeIndex: ast_gen.NodeIndex) void {
        const flags = self.ast.getNodeFlags(nodeIndex);
        if ((flags & ast_utils.NodeFlags.Ambient) == 0) {
            const nameNode = ast_utils.getNameOfNode(self.ast, nodeIndex);
            self.checkStrictModeEvalOrArguments(nodeIndex, nameNode);
        }
    }

    pub fn checkStrictModeBinaryExpression(self: *Binder, nodeIndex: ast_gen.NodeIndex) void {
        const bin = self.ast.getNode(nodeIndex).BinaryExpression;
        const left = bin.Left;
        const opKind = self.ast.getNode(bin.OperatorToken);
        if (ast_utils.isLeftHandSideExpression(self.ast, left) and ast_utils.isAssignmentOperator(opKind)) {
            self.checkStrictModeEvalOrArguments(nodeIndex, left);
        }
    }

    pub fn checkStrictModeCatchClause(self: *Binder, nodeIndex: ast_gen.NodeIndex) void {
        const clause = self.ast.getNode(nodeIndex).CatchClause;
        if (clause.VariableDeclaration != null and clause.VariableDeclaration.? != 0) {
            const nameNode = ast_utils.getNameOfNode(self.ast, clause.VariableDeclaration.?);
            self.checkStrictModeEvalOrArguments(nodeIndex, nameNode);
        }
    }

    pub fn checkStrictModeDeleteExpression(self: *Binder, nodeIndex: ast_gen.NodeIndex) void {
        const expr = self.ast.getNode(nodeIndex).DeleteExpression;
        if (self.ast.getNode(expr.Expression) == .Identifier) {
            self.reportError(expr.Expression, &diagnostics.generated.X_delete_cannot_be_called_on_an_identifier_in_strict_mode, &[_][]const u8{});
        }
    }

    pub fn checkStrictModePostfixUnaryExpression(self: *Binder, nodeIndex: ast_gen.NodeIndex) void {
        const expr = self.ast.getNode(nodeIndex).PostfixUnaryExpression;
        self.checkStrictModeEvalOrArguments(nodeIndex, expr.Operand);
    }

    pub fn checkStrictModePrefixUnaryExpression(self: *Binder, nodeIndex: ast_gen.NodeIndex) void {
        const expr = self.ast.getNode(nodeIndex).PrefixUnaryExpression;
        const op: @import("../ast/kind.zig").Kind = @enumFromInt(expr.Operator);
        if (op == .PlusPlusToken or op == .MinusMinusToken) {
            self.checkStrictModeEvalOrArguments(nodeIndex, expr.Operand);
        }
    }

    pub fn checkStrictModeWithStatement(self: *Binder, nodeIndex: ast_gen.NodeIndex) void {
        self.reportError(nodeIndex, &diagnostics.generated.X_with_statements_are_not_allowed_in_strict_mode, &[_][]const u8{});
    }

    pub fn checkStrictModeLabeledStatement(self: *Binder, nodeIndex: ast_gen.NodeIndex) void {
        const data = self.ast.getNode(nodeIndex).LabeledStatement;
        if (ast_utils.isDeclarationStatement(self.ast, data.Statement) or ast_utils.isVariableStatement(self.ast, data.Statement)) {
            self.reportError(data.Label, &diagnostics.generated.A_label_is_not_allowed_here, &[_][]const u8{});
        }
    }

    pub fn isEvalOrArgumentsIdentifier(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        if (nodeIndex == 0) return false;
        if (self.ast.getNode(nodeIndex) == .Identifier) {
            const text = self.getIdentifierName(nodeIndex);
            return std.mem.eql(u8, text, "eval") or std.mem.eql(u8, text, "arguments");
        }
        return false;
    }

    pub fn checkStrictModeEvalOrArguments(self: *Binder, contextNode: ast_gen.NodeIndex, name: ast_gen.NodeIndex) void {
        if (name != 0 and self.isEvalOrArgumentsIdentifier(name)) {
            self.reportError(name, self.getStrictModeEvalOrArgumentsMessage(contextNode), &[_][]const u8{self.getIdentifierName(name)});
        }
    }

    pub fn getStrictModeEvalOrArgumentsMessage(self: *Binder, nodeIndex: ast_gen.NodeIndex) *const diagnostics.Message {
        _ = self;
        _ = nodeIndex;
        return &diagnostics.generated.Invalid_use_of_0_in_strict_mode;
    }

    pub fn bindModuleExportsAssignment(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        if (try self.setCommonJSModuleIndicator(nodeIndex)) {
            try self.trackNestedCJSExport(nodeIndex);
            const container = self.file;
            const right = self.ast.getNode(nodeIndex).BinaryExpression.Right;
            const isAlias = self.isEntityNameExpression(right) or self.ast.getNode(right) == .ClassExpression;
            const flags = (if (isAlias) symbol.SymbolFlags.Alias else symbol.SymbolFlags.Property) | symbol.SymbolFlags.Assignment;

            const containerSym = self.ast.getNodeSymbol(container).?;
            _ = try self.declareSymbolEx(.Exports, containerSym, nodeIndex, flags, 0, symbol.InternalSymbolNameExportEquals, false, false);
        }
    }

    pub fn bindExportsOrObjectDefineProperty(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        if (try self.setCommonJSModuleIndicator(nodeIndex)) {
            try self.trackNestedCJSExport(nodeIndex);
            const container = self.file;
            const isBin = self.ast.getNode(nodeIndex) == .BinaryExpression;
            const isAlias = isBin and (self.isEntityNameExpression(self.ast.getNode(nodeIndex).BinaryExpression.Right) or self.ast.getNode(self.ast.getNode(nodeIndex).BinaryExpression.Right) == .ClassExpression);
            const flags = (if (isAlias) symbol.SymbolFlags.Alias else symbol.SymbolFlags.FunctionScopedVariable) | symbol.SymbolFlags.Assignment;

            const containerSym = self.ast.getNodeSymbol(container).?;
            const export_name = self.commonJSExportName(nodeIndex) orelse symbol.InternalSymbolNameMissing;
            _ = try self.declareSymbolEx(.Exports, containerSym, nodeIndex, flags, symbol.SymbolFlags.FunctionScopedVariableExcludes, export_name, false, false);
        }
    }

    fn commonJSExportName(self: *Binder, node_index: ast_gen.NodeIndex) ?[]const u8 {
        return switch (self.ast.getNode(node_index)) {
            .BinaryExpression => |binary| switch (self.ast.getNode(binary.Left)) {
                .PropertyAccessExpression => |access| ast_utils.getText(self.ast, access.name),
                .ElementAccessExpression => |access| if (self.ast.getNode(access.ArgumentExpression) == .StringLiteral or self.ast.getNode(access.ArgumentExpression) == .NumericLiteral) ast_utils.getText(self.ast, access.ArgumentExpression) else null,
                else => null,
            },
            .CallExpression => |call| blk: {
                const arguments = self.ast.getNodeList(call.Arguments);
                if (arguments.len >= 2 and (self.ast.getNode(arguments[1]) == .StringLiteral or self.ast.getNode(arguments[1]) == .NumericLiteral)) break :blk ast_utils.getText(self.ast, arguments[1]);
                break :blk null;
            },
            else => null,
        };
    }

    pub fn bindThisPropertyAssignment(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        if (!ast_utils.isInJSFile(self.ast, nodeIndex)) return;
        const binary = self.ast.getNode(nodeIndex).BinaryExpression;
        const property_name: ?[]const u8 = switch (self.ast.getNode(binary.Left)) {
            .PropertyAccessExpression => |access| if (self.ast.getNode(access.name) == .PrivateIdentifier) null else ast_utils.getText(self.ast, access.name),
            .ElementAccessExpression => |access| if (self.ast.getNode(access.ArgumentExpression) == .StringLiteral or self.ast.getNode(access.ArgumentExpression) == .NumericLiteral) ast_utils.getText(self.ast, access.ArgumentExpression) else null,
            else => null,
        };
        const name = property_name orelse return;
        var member = self.ast.getNodeParent(nodeIndex);
        var containing_member: ast_gen.NodeIndex = 0;
        var class_node: ast_gen.NodeIndex = 0;
        while (member != 0) {
            const current = self.ast.getNode(member);
            if (containing_member == 0 and (current == .Constructor or current == .MethodDeclaration or current == .GetAccessor or current == .SetAccessor or current == .PropertyDeclaration or current == .ClassStaticBlockDeclaration)) containing_member = member;
            if (current == .ClassDeclaration or current == .ClassExpression) {
                class_node = member;
                break;
            }
            member = self.ast.getNodeParent(member);
        }
        if (class_node == 0) return;
        const class_symbol = self.ast.getNodeSymbol(class_node) orelse return;
        const is_static = containing_member != 0 and (self.ast.getNode(containing_member) == .ClassStaticBlockDeclaration or ast_utils.hasSyntacticModifier(self.ast, containing_member, ast_utils.ModifierFlags.Static));
        _ = try self.declareSymbolEx(if (is_static) .Exports else .Members, class_symbol, nodeIndex, symbol.SymbolFlags.Property | symbol.SymbolFlags.Assignment, symbol.SymbolFlags.None, name, true, false);
    }

    pub fn setCommonJSModuleIndicator(self: *Binder, nodeIndex: ast_gen.NodeIndex) !bool {
        var source = self.ast.getNode(self.file).SourceFile;
        if (source.ExternalModuleIndicator != null and source.ExternalModuleIndicator.? != self.file) return false;
        if (source.CommonJSModuleIndicator == null) {
            source.CommonJSModuleIndicator = nodeIndex;
            self.ast.nodes.set(self.file, .{ .SourceFile = source });
            if (source.ExternalModuleIndicator == null) try self.bindSourceFileAsExternalModule();
        }
        return true;
    }

    pub fn trackNestedCJSExport(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        _ = self;
        _ = nodeIndex;
    }

    pub fn reportError(self: *Binder, location: ast_gen.NodeIndex, message: *const diagnostics.Message, args: []const []const u8) void {
        self.errorOnNode(location, message, args);
    }

    pub fn errorOnNode(self: *Binder, nodeIndex: ast_gen.NodeIndex, message: *const diagnostics.Message, args: []const []const u8) void {
        self.addDiagnostic(self.createDiagnosticForNode(nodeIndex, message, args));
    }

    pub fn errorOnFirstToken(self: *Binder, nodeIndex: ast_gen.NodeIndex, message: *const diagnostics.Message, args: []const []const u8) void {
        self.addDiagnostic(self.createDiagnosticForNode(nodeIndex, message, args));
    }

    pub fn errorOrSuggestionOnNode(self: *Binder, isError: bool, nodeIndex: ast_gen.NodeIndex, message: *const diagnostics.Message) void {
        self.errorOrSuggestionOnRange(isError, nodeIndex, nodeIndex, message);
    }

    pub fn errorOrSuggestionOnRange(self: *Binder, isError: bool, startNode: ast_gen.NodeIndex, endNode: ast_gen.NodeIndex, message: *const diagnostics.Message) void {
        _ = endNode;
        const diagnostic = self.createDiagnosticForNode(startNode, message, &[_][]const u8{});
        if (isError) {
            self.addDiagnostic(diagnostic);
        } else {
            // Suggestion diagnostics could be appended to a separate list if needed
        }
    }

    pub fn createDiagnosticForNode(self: *Binder, nodeIndex: ast_gen.NodeIndex, message: *const diagnostics.Message, args: []const []const u8) diagnostics.Diagnostic {
        _ = self;
        return .{
            .message = message,
            .nodeIndex = nodeIndex,
            .args = args,
        };
    }

    pub fn addDiagnostic(self: *Binder, diagnostic: diagnostics.Diagnostic) void {
        self.diagnosticsList.append(self.allocator, diagnostic) catch unreachable;
    }

    // -- CFA Functions --
    pub fn isStatementCondition(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        const parentIndex = self.ast.getNodeParent(nodeIndex);
        if (parentIndex == 0) return false;
        switch (self.ast.getNode(parentIndex)) {
            .IfStatement => |n| return n.Expression == nodeIndex,
            .WhileStatement => |n| return n.Expression == nodeIndex,
            .DoStatement => |n| return n.Expression == nodeIndex,
            .ForStatement => |n| return n.Condition == nodeIndex,
            .ConditionalExpression => |n| return n.Condition == nodeIndex,
            else => return false,
        }
    }

    pub fn isTopLevelLogicalExpression(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        var current = nodeIndex;
        while (true) {
            const parentIndex = self.ast.getNodeParent(current);
            if (parentIndex == 0) break;
            const parentNode = self.ast.getNode(parentIndex);
            if (parentNode == .ParenthesizedExpression) {
                current = parentIndex;
                continue;
            }
            if (parentNode == .PrefixUnaryExpression and self.ast.getNode(parentNode.PrefixUnaryExpression.Operator) == .ExclamationToken) {
                current = parentIndex;
                continue;
            }
            break;
        }
        const finalParent = self.ast.getNodeParent(current);
        if (finalParent == 0) return true;

        if (self.isStatementCondition(current)) return false;

        if (ast_utils.isLogicalExpression(self.ast, finalParent)) return false;
        if (ast_utils.isOptionalChain(self.ast, finalParent)) {
            if (ast_utils.getExpressionOfNode(self.ast, finalParent) == current) return false;
        }
        return true;
    }

    pub fn isNarrowableReference(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        if (nodeIndex == 0) return false;
        switch (self.ast.getNode(nodeIndex)) {
            .Identifier, .ThisKeyword, .SuperKeyword, .MetaProperty => return true,
            .PropertyAccessExpression => |n| return self.isNarrowableReference(n.Expression),
            .ParenthesizedExpression => |n| return self.isNarrowableReference(n.Expression),
            .NonNullExpression => |n| return self.isNarrowableReference(n.Expression),
            .ElementAccessExpression => |n| {
                if (ast_utils.isStringOrNumericLiteralLike(self.ast, n.ArgumentExpression)) return true;
                if (ast_utils.isEntityNameExpression(self.ast, n.ArgumentExpression) and self.isNarrowableReference(n.Expression)) return true;
                return false;
            },
            .BinaryExpression => |n| {
                const op = self.ast.getNode(n.OperatorToken);
                if (op == .CommaToken and self.isNarrowableReference(n.Right)) return true;
                if (ast_utils.isAssignmentOperator(op) and ast_utils.isLeftHandSideExpression(self.ast, n.Left)) return true;
                return false;
            },
            else => return false,
        }
    }

    pub fn containsNarrowableReference(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        if (self.isNarrowableReference(nodeIndex)) return true;
        if ((ast_utils.getNodeFlags(self.ast, nodeIndex) & ast_utils.NodeFlags.OptionalChain) != 0) {
            switch (self.ast.getNode(nodeIndex)) {
                .PropertyAccessExpression, .ElementAccessExpression, .CallExpression, .NonNullExpression => {
                    return self.containsNarrowableReference(ast_utils.getExpressionOfNode(self.ast, nodeIndex));
                },
                else => {},
            }
        }
        return false;
    }

    pub fn isNarrowableOperand(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        switch (self.ast.getNode(nodeIndex)) {
            .ParenthesizedExpression => |n| return self.isNarrowableOperand(n.Expression),
            .BinaryExpression => |n| {
                const op = self.ast.getNode(n.OperatorToken);
                if (op == .EqualsToken) return self.isNarrowableOperand(n.Left);
                if (op == .CommaToken) return self.isNarrowableOperand(n.Right);
            },
            else => {},
        }
        return self.containsNarrowableReference(nodeIndex);
    }

    pub fn hasNarrowableArgument(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        const call = self.ast.getNode(nodeIndex).CallExpression;
        if (call.Arguments != 0) {
            const args = self.ast.getNodeList(call.Arguments);
            for (args) |arg| {
                if (self.containsNarrowableReference(arg)) return true;
            }
        }
        if (self.ast.getNode(call.Expression) == .PropertyAccessExpression) {
            const propAccess = self.ast.getNode(call.Expression).PropertyAccessExpression;
            if (self.containsNarrowableReference(propAccess.Expression)) return true;
        }
        return false;
    }

    pub fn isNarrowingExpression(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        if (nodeIndex == 0) return false;
        switch (self.ast.getNode(nodeIndex)) {
            .Identifier, .ThisKeyword => return true,
            .PropertyAccessExpression, .ElementAccessExpression => return self.containsNarrowableReference(nodeIndex),
            .CallExpression => return self.hasNarrowableArgument(nodeIndex),
            .ParenthesizedExpression => |n| return self.isNarrowingExpression(n.Expression),
            .NonNullExpression => |n| return self.isNarrowingExpression(n.Expression),
            .TypeOfExpression => |n| return self.isNarrowingExpression(n.Expression),
            .BinaryExpression => return self.isNarrowingBinaryExpression(nodeIndex),
            .PrefixUnaryExpression => |n| {
                return self.ast.getNode(n.Operator) == .ExclamationToken and self.isNarrowingExpression(n.Operand);
            },
            else => return false,
        }
    }

    pub fn isNarrowingTypeOfOperands(self: *Binder, expr1: ast_gen.NodeIndex, expr2: ast_gen.NodeIndex) bool {
        if (self.ast.getNode(expr1) == .TypeOfExpression) {
            const typeOf = self.ast.getNode(expr1).TypeOfExpression;
            if (self.isNarrowableOperand(typeOf.Expression) and ast_utils.isStringLiteralLike(self.ast, expr2)) {
                return true;
            }
        }
        return false;
    }

    pub fn isNarrowingBinaryExpression(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        const n = self.ast.getNode(nodeIndex).BinaryExpression;
        const op = self.ast.getNode(n.OperatorToken);
        switch (op) {
            .EqualsToken, .BarBarEqualsToken, .AmpersandAmpersandEqualsToken, .QuestionQuestionEqualsToken => {
                return self.containsNarrowableReference(n.Left);
            },
            .EqualsEqualsToken, .ExclamationEqualsToken, .EqualsEqualsEqualsToken, .ExclamationEqualsEqualsToken => {
                const left = ast_utils.skipParentheses(self.ast, n.Left);
                const right = ast_utils.skipParentheses(self.ast, n.Right);
                return self.isNarrowableOperand(left) or self.isNarrowableOperand(right) or
                    self.isNarrowingTypeOfOperands(right, left) or self.isNarrowingTypeOfOperands(left, right) or
                    (ast_utils.isBooleanLiteral(self.ast, right) and self.isNarrowingExpression(left)) or
                    (ast_utils.isBooleanLiteral(self.ast, left) and self.isNarrowingExpression(right));
            },
            .InstanceOfKeyword => return self.isNarrowableOperand(n.Left),
            .InKeyword => return self.isNarrowingExpression(n.Right),
            .CommaToken => return self.isNarrowingExpression(n.Right),
            else => return false,
        }
    }

    pub fn isLogicalAssignmentExpression(self: *Binder, nodeIndex: ast_gen.NodeIndex) bool {
        return ast_utils.isLogicalOrCoalescingAssignmentExpression(self.ast, ast_utils.skipParentheses(self.ast, nodeIndex));
    }

    pub fn bindCondition(self: *Binder, nodeIndex: ast_gen.NodeIndex, trueTarget: ast.flow.FlowNodeIndex, falseTarget: ast.flow.FlowNodeIndex) !void {
        const savedTrueTarget = self.currentTrueTarget;
        const savedFalseTarget = self.currentFalseTarget;
        self.currentTrueTarget = trueTarget;
        self.currentFalseTarget = falseTarget;
        try self.bind(nodeIndex);
        self.currentTrueTarget = savedTrueTarget;
        self.currentFalseTarget = savedFalseTarget;

        if (nodeIndex != 0 and !self.isLogicalAssignmentExpression(nodeIndex) and !ast_utils.isLogicalExpression(self.ast, nodeIndex) and !(ast_utils.isOptionalChain(self.ast, nodeIndex) and ast_utils.isOutermostOptionalChain(self.ast, nodeIndex))) {
            self.addAntecedent(trueTarget, self.createFlowCondition(ast.flow.FlowFlags.TrueCondition, self.currentFlow, nodeIndex));
            self.addAntecedent(falseTarget, self.createFlowCondition(ast.flow.FlowFlags.FalseCondition, self.currentFlow, nodeIndex));
        }
    }

    pub fn bindPrefixUnaryExpressionFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const expr = self.ast.getNode(nodeIndex).PrefixUnaryExpression;
        const op = @as(kind.Kind, @enumFromInt(expr.Operator));
        if (op == .PlusPlusToken or op == .MinusMinusToken) {
            try self.bindAssignmentTargetFlow(expr.Operand);
        } else {
            try self.bind(expr.Operand);
        }
    }

    pub fn bindPostfixUnaryExpressionFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const expr = self.ast.getNode(nodeIndex).PostfixUnaryExpression;
        // The Operator is a Kind, not a NodeIndex.
        try self.bindAssignmentTargetFlow(expr.Operand);
    }

    pub fn bindDestructuringAssignmentFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const expr = self.ast.getNode(nodeIndex).BinaryExpression;
        if (self.inAssignmentPattern) {
            self.inAssignmentPattern = false;
            try self.bind(expr.OperatorToken);
            try self.bind(expr.Right);
            self.inAssignmentPattern = true;
            try self.bind(expr.Left);
        } else {
            self.inAssignmentPattern = true;
            try self.bind(expr.Left);
            self.inAssignmentPattern = false;
            try self.bind(expr.OperatorToken);
            try self.bind(expr.Right);
        }
        try self.bindAssignmentTargetFlow(expr.Left);
    }

    pub fn bindBinaryExpressionFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const expr = self.ast.getNode(nodeIndex).BinaryExpression;
        const operator = self.ast.getNode(expr.OperatorToken);

        if (ast_utils.isLogicalOrCoalescingBinaryOperator(operator) or ast_utils.isLogicalOrCoalescingAssignmentOperator(operator)) {
            if (self.isTopLevelLogicalExpression(nodeIndex)) {
                const postExpressionLabel = self.createBranchLabel();
                try self.bindLogicalLikeExpression(nodeIndex, self.currentTrueTarget, self.currentFalseTarget, postExpressionLabel);
                self.currentFlow = self.finishFlowLabel(postExpressionLabel);
            } else {
                try self.bindLogicalLikeExpression(nodeIndex, self.currentTrueTarget, self.currentFalseTarget, 0);
            }
            return;
        }

        try self.bind(expr.Left);
        try self.bind(expr.Right);

        if (ast_utils.isAssignmentOperator(operator) and !ast_utils.isDestructuringAssignment(self.ast, nodeIndex)) {
            try self.bindAssignmentTargetFlow(expr.Left);
            if (operator == .EqualsToken and self.ast.getNode(expr.Left) == .ElementAccessExpression) {
                const elementAccess = self.ast.getNode(expr.Left).ElementAccessExpression;
                if (ast_utils.isStringOrNumericLiteralLike(self.ast, elementAccess.ArgumentExpression)) {
                    if (ast_utils.isEntityNameExpression(self.ast, elementAccess.Expression) and self.isNarrowableReference(elementAccess.Expression)) {
                        self.currentFlow = self.createFlowMutation(ast.flow.FlowFlags.ArrayMutation, self.currentFlow, nodeIndex);
                    }
                }
            }
        }
    }

    pub fn bindDeleteExpressionFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const expr = self.ast.getNode(nodeIndex).DeleteExpression;
        try self.bind(expr.Expression);
        try self.bindAssignmentTargetFlow(expr.Expression);
    }

    pub fn bindConditionalExpressionFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const expr = self.ast.getNode(nodeIndex).ConditionalExpression;
        const trueLabel = self.createBranchLabel();
        const falseLabel = self.createBranchLabel();
        const postExpressionLabel = self.createBranchLabel();

        try self.bindCondition(expr.Condition, trueLabel, falseLabel);

        self.currentFlow = self.finishFlowLabel(trueLabel);
        try self.bind(expr.WhenTrue);
        self.addAntecedent(postExpressionLabel, self.currentFlow);

        self.currentFlow = self.finishFlowLabel(falseLabel);
        try self.bind(expr.WhenFalse);
        self.addAntecedent(postExpressionLabel, self.currentFlow);

        self.currentFlow = self.finishFlowLabel(postExpressionLabel);
    }

    pub fn bindVariableDeclarationFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const decl = self.ast.getNode(nodeIndex).VariableDeclaration;
        if (decl.Initializer != 0) {
            try self.bindInitializedVariableFlow(nodeIndex);
        }
    }

    pub fn bindInitializedVariableFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) anyerror!void {
        var name: u32 = 0;
        switch (self.ast.getNode(nodeIndex)) {
            .VariableDeclaration => |n| name = n.name,
            .BindingElement => |n| {
                if (n.name) |nameIndex| name = nameIndex;
            },
            else => {},
        }

        if (name != 0 and ast_utils.isBindingPattern(self.ast, name)) {
            const elements = if (self.ast.getNode(name) == .ObjectBindingPattern) self.ast.getNode(name).ObjectBindingPattern.Elements else self.ast.getNode(name).ArrayBindingPattern.Elements;
            const elementsArr = self.ast.getNodeList(elements);
            for (elementsArr) |child| {
                try self.bindInitializedVariableFlow(child);
            }
        } else {
            self.currentFlow = self.createFlowMutation(ast.flow.FlowFlags.Assignment, self.currentFlow, nodeIndex);
        }
    }

    pub fn bindLogicalLikeExpression(self: *Binder, nodeIndex: ast_gen.NodeIndex, trueTarget: ast.flow.FlowNodeIndex, falseTarget: ast.flow.FlowNodeIndex, postExpressionLabel: ast.flow.FlowNodeIndex) !void {
        const expr = self.ast.getNode(nodeIndex).BinaryExpression;
        const operator = self.ast.getNode(expr.OperatorToken);

        const preRightLabel = self.createBranchLabel();

        if (operator == .AmpersandAmpersandToken or operator == .AmpersandAmpersandEqualsToken) {
            try self.bindCondition(expr.Left, preRightLabel, if (falseTarget != 0) falseTarget else postExpressionLabel);
        } else {
            try self.bindCondition(expr.Left, if (trueTarget != 0) trueTarget else postExpressionLabel, preRightLabel);
        }

        self.currentFlow = self.finishFlowLabel(preRightLabel);
        try self.bind(expr.Right);

        if (operator == .AmpersandAmpersandEqualsToken or operator == .BarBarEqualsToken or operator == .QuestionQuestionEqualsToken) {
            try self.bindAssignmentTargetFlow(expr.Left);
        }
    }

    pub fn bindAssignmentTargetFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) anyerror!void {
        if (nodeIndex == 0) return;
        switch (self.ast.getNode(nodeIndex)) {
            .ObjectLiteralExpression => |n| {
                if (n.Properties != 0) {
                    const props = self.ast.getNodeList(n.Properties);
                    for (props) |p| {
                        if (self.ast.getNode(p) == .PropertyAssignment) {
                            try self.bindDestructuringTargetFlow(self.ast.getNode(p).PropertyAssignment.Initializer);
                        } else if (self.ast.getNode(p) == .ShorthandPropertyAssignment) {
                            try self.bindAssignmentTargetFlow(self.ast.getNode(p).ShorthandPropertyAssignment.name);
                        } else if (self.ast.getNode(p) == .SpreadAssignment) {
                            try self.bindAssignmentTargetFlow(self.ast.getNode(p).SpreadAssignment.Expression);
                        }
                    }
                }
            },
            .ArrayLiteralExpression => |n| {
                if (n.Elements != 0) {
                    const elements = self.ast.getNodeList(n.Elements);
                    for (elements) |e| {
                        if (self.ast.getNode(e) == .SpreadElement) {
                            try self.bindAssignmentTargetFlow(self.ast.getNode(e).SpreadElement.Expression);
                        } else {
                            try self.bindDestructuringTargetFlow(e);
                        }
                    }
                }
            },
            else => {
                if (self.isNarrowableReference(nodeIndex)) {
                    self.currentFlow = self.createFlowMutation(ast.flow.FlowFlags.Assignment, self.currentFlow, nodeIndex);
                }
            },
        }
    }

    pub fn bindDestructuringTargetFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        if (self.ast.getNode(nodeIndex) == .BinaryExpression and self.ast.getNode(self.ast.getNode(nodeIndex).BinaryExpression.OperatorToken) == .EqualsToken) {
            try self.bindAssignmentTargetFlow(self.ast.getNode(nodeIndex).BinaryExpression.Left);
        } else {
            try self.bindAssignmentTargetFlow(nodeIndex);
        }
    }

    pub fn bindAccessExpressionFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        try self.bindOptionalChainFlow(nodeIndex);
    }

    pub fn bindCallExpressionFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        try self.bindOptionalChainFlow(nodeIndex);
        if (self.ast.getNode(nodeIndex).CallExpression.Expression != 0) {
            if (self.ast.getNode(self.ast.getNode(nodeIndex).CallExpression.Expression) != .SuperKeyword) {
                self.currentFlow = self.createFlowCall(self.currentFlow, nodeIndex);
            }
        }
    }

    pub fn bindNonNullExpressionFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        try self.bindOptionalChainFlow(nodeIndex);
    }

    pub fn bindOptionalChainFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        if (ast_utils.isOptionalChain(self.ast, nodeIndex)) {
            if (ast_utils.isOutermostOptionalChain(self.ast, nodeIndex)) {
                const postExpressionLabel = self.createBranchLabel();
                try self.bindOptionalChain(nodeIndex, self.currentTrueTarget, self.currentFalseTarget, postExpressionLabel);
                self.currentFlow = self.finishFlowLabel(postExpressionLabel);
                self.currentFlow = self.createFlowMutation(ast.flow.FlowFlags.Assignment, self.currentFlow, nodeIndex);
            } else {
                try self.bindOptionalChain(nodeIndex, self.currentTrueTarget, self.currentFalseTarget, 0);
            }
        } else {
            const expression = ast_utils.getExpressionOfNode(self.ast, nodeIndex);
            try self.bind(expression);
            switch (self.ast.getNode(nodeIndex)) {
                .CallExpression => |n| {
                    if (n.TypeArguments != null and n.TypeArguments.? != 0) try self.bindNodeList(n.TypeArguments.?);
                    if (n.Arguments != 0) try self.bindNodeList(n.Arguments);
                },
                .ElementAccessExpression => |n| try self.bind(n.ArgumentExpression),
                else => {},
            }
        }
    }

    pub fn bindOptionalChain(self: *Binder, nodeIndex: ast_gen.NodeIndex, trueTarget: ast.flow.FlowNodeIndex, falseTarget: ast.flow.FlowNodeIndex, postExpressionLabel: ast.flow.FlowNodeIndex) !void {
        _ = self;
        _ = nodeIndex;
        _ = trueTarget;
        _ = falseTarget;
        _ = postExpressionLabel;
        // Missing implementation, to be done later if needed
    }

    pub fn bindBindingElementFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) anyerror!void {
        const decl = self.ast.getNode(nodeIndex).BindingElement;
        if (decl.PropertyName == null or decl.PropertyName.? == 0) {
            if (decl.name) |n| try self.bindAssignmentTargetFlow(n);
        }
        if (decl.Initializer != null and decl.Initializer.? != 0) {
            try self.bindInitializedVariableFlow(nodeIndex);
        }
    }

    pub fn bindParameterFlow(self: *Binder, nodeIndex: ast_gen.NodeIndex) !void {
        const decl = self.ast.getNode(nodeIndex).Parameter;
        if (decl.Type != 0) try self.bind(decl.Type);
        if (ast_utils.isBindingPattern(self.ast, decl.name)) {
            try self.bindAssignmentTargetFlow(decl.name);
        }
        if (decl.Initializer != 0) {
            try self.bindInitializedVariableFlow(nodeIndex);
        }
    }
};
