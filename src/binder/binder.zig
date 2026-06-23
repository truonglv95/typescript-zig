const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const symbol = @import("../ast/symbol.zig");
const kind = @import("../ast/kind.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const fallback = @import("fallback.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");

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

    diagnosticsList: std.ArrayListUnmanaged(diagnostics.Diagnostic) = .empty,
    expandoAssignments: std.ArrayListUnmanaged(ExpandoAssignmentInfo) = .empty,

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

        return Binder{
            .allocator = allocator,
            .ast = a,
            .symbols = symbols,
            .nodeLocals = std.AutoHashMap(ast_gen.NodeIndex, std.StringHashMap(ast_gen.SymbolIndex)).init(allocator),
            .symbolExports = std.AutoHashMap(ast_gen.SymbolIndex, std.StringHashMap(ast_gen.SymbolIndex)).init(allocator),
            .symbolMembers = std.AutoHashMap(ast_gen.SymbolIndex, std.StringHashMap(ast_gen.SymbolIndex)).init(allocator),
            .parentNodeIndex = 0,
            .parent = null,
            .container = null,
            .blockScopeContainer = null,
            .file = 0,
            .diagnosticsList = std.ArrayListUnmanaged(diagnostics.Diagnostic).empty,
        };
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

        self.diagnosticsList.deinit(self.allocator);
        self.expandoAssignments.deinit(self.allocator);
    }

    pub fn bindSourceFile(self: *Binder, sourceFileIndex: ast_gen.NodeIndex) !void {
        self.file = sourceFileIndex;
        try self.bind(sourceFileIndex);
        try self.bindDeferredExpandoAssignments();
    }

    fn bindSourceFileIfExternalModule(self: *Binder) !void {
        if (ast_utils.isExternalModule(self.ast, self.file)) {
            try self.bindSourceFileAsExternalModule();
        }
    }

    fn bindSourceFileAsExternalModule(self: *Binder) !void {
        // b.bindAnonymousDeclaration(b.file.AsNode(), ast.SymbolFlagsValueModule, "\""+tspath.RemoveFileExtension(b.file.FileName())+"\"")
        // Hardcode "test.ts" for now
        _ = try self.declareSymbolEx(.Locals, self.file, self.file, symbol.SymbolFlags.ValueModule, symbol.SymbolFlags.None, "\"test.ts\"", false, false);
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

    pub fn bind(self: *Binder, optNodeIndex: ?ast_gen.NodeIndex) !void {
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
                
                try self.bindSourceFileIfExternalModule();

                if (n.Statements != 0) {
                    try self.bindChildren(n.Statements);
                }

                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .VariableStatement => |n| {
                try self.bind(n.DeclarationList);
            },
            .VariableDeclarationList => |n| {
                if (n.Declarations != 0) {
                    try self.bindChildren(n.Declarations);
                }
            },
            .VariableDeclaration => |n| {
                if (n.name != 0) {
                    try self.bindVariableDeclarationOrBindingElement(nodeIndex, n.name);
                    try self.bind(n.name);
                }
                if (n.Type) |t| try self.bind(t);
                if (n.Initializer) |i| try self.bind(i);
            },
            .FunctionDeclaration => |n| {
                const nameStr = if (n.name != null and n.name.? != 0) self.getIdentifierName(n.name.?)
                                else if (ast_utils.hasSyntacticModifier(self.ast, nodeIndex, ast_utils.ModifierFlags.Default)) "default"
                                else "";
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Function, symbol.SymbolFlags.FunctionExcludes, nameStr);

                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;

                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;

                if (n.TypeParameters) |tp| {
                    try self.bindChildren(tp);
                }
                if (n.Parameters != 0) {
                    try self.bindChildren(n.Parameters);
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
                    try self.bindChildren(tp);
                }
                if (n.Parameters != 0) {
                    try self.bindChildren(n.Parameters);
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
                    try self.bindChildren(tp);
                }
                if (n.Parameters != 0) {
                    try self.bindChildren(n.Parameters);
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
                const nameStr = if (n.name != null) self.getIdentifierName(n.name.?) 
                                else if (ast_utils.hasSyntacticModifier(self.ast, nodeIndex, ast_utils.ModifierFlags.Default)) "default" 
                                else "";
                _ = try self.bindBlockScopedDeclaration(nodeIndex, symbol.SymbolFlags.Class, symbol.SymbolFlags.ClassExcludes, nameStr);
                const classSymbolId = self.ast.getNodeSymbol(nodeIndex).?;

                _ = try self.declareSymbolEx(.Exports, classSymbolId, 0, symbol.SymbolFlags.Property | symbol.SymbolFlags.Prototype, symbol.SymbolFlags.PropertyExcludes, "prototype", false, false);

                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;

                if (n.TypeParameters) |tp| try self.bindChildren(tp);
                if (n.HeritageClauses) |hc| try self.bindChildren(hc);
                if (n.Members != 0) {
                    try self.bindChildren(n.Members);
                }

                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .ClassExpression => |n| {
                const nameStr = if (n.name != null) self.getIdentifierName(n.name.?) else "__class";
                _ = try self.bindAnonymousDeclaration(nodeIndex, symbol.SymbolFlags.Class, nameStr);
                const classSymbolId = self.ast.getNodeSymbol(nodeIndex).?;

                _ = try self.declareSymbolEx(.Exports, classSymbolId, 0, symbol.SymbolFlags.Property | symbol.SymbolFlags.Prototype, symbol.SymbolFlags.PropertyExcludes, "prototype", false, false);

                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;

                if (n.TypeParameters) |tp| try self.bindChildren(tp);
                if (n.HeritageClauses) |hc| try self.bindChildren(hc);
                if (n.Members != 0) {
                    try self.bindChildren(n.Members);
                }

                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .InterfaceDeclaration => |n| {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Interface, symbol.SymbolFlags.InterfaceExcludes, self.getIdentifierName(n.name));
                const saveContainer = self.container;
                self.container = nodeIndex;
                if (n.TypeParameters) |tp| {
                    try self.bindChildren(tp);
                }
                if (n.Members != 0) {
                    try self.bindChildren(n.Members);
                }
                self.container = saveContainer;
            },
            .TypeAliasDeclaration => |n| {
                _ = try self.bindBlockScopedDeclaration(nodeIndex, symbol.SymbolFlags.TypeAlias, symbol.SymbolFlags.TypeAliasExcludes, self.getIdentifierName(n.name));
                const saveContainer = self.container;
                self.container = nodeIndex;
                if (n.TypeParameters) |tp| {
                    try self.bindChildren(tp);
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
                    try self.bindChildren(n.Members);
                } else {
                }
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
                    if (std.mem.eql(u8, nameStr, "global")) {
                        nameStr = "__global";
                    }
                }
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.ValueModule, symbol.SymbolFlags.ValueModuleExcludes, nameStr);
                if (allocated_name) |an| {
                    self.allocator.free(an);
                }
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                if (n.Body) |body| {
                    try self.bind(body);
                }
                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .MethodDeclaration => |n| {
                var flags = symbol.SymbolFlags.Method;
                if (n.PostfixToken != 0) flags |= symbol.SymbolFlags.Optional;
                _ = try self.bindPropertyOrMethodOrAccessor(nodeIndex, flags, symbol.SymbolFlags.MethodExcludes, self.getIdentifierName(n.name));
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                if (n.TypeParameters) |tp| {
                    try self.bindChildren(tp);
                }
                if (n.Parameters != 0) {
                    try self.bindChildren(n.Parameters);
                }
                if (n.Type) |t| try self.bind(t);
                if (n.Body) |body| try self.bind(body);
                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .MethodSignature => |n| {
                var flags = symbol.SymbolFlags.Method;
                if (n.PostfixToken != 0) flags |= symbol.SymbolFlags.Optional;
                _ = try self.bindPropertyOrMethodOrAccessor(nodeIndex, flags, symbol.SymbolFlags.MethodExcludes, self.getIdentifierName(n.name));
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                if (n.TypeParameters) |tp| {
                    try self.bindChildren(tp);
                }
                if (n.Parameters != 0) {
                    try self.bindChildren(n.Parameters);
                }
                if (n.Type) |t| try self.bind(t);
                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .CallSignature => |n| {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Signature, symbol.SymbolFlags.None, "");
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                if (n.TypeParameters) |tp| try self.bindChildren(tp);
                if (n.Parameters != 0) try self.bindChildren(n.Parameters);
                if (n.Type) |t| try self.bind(t);
                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .ConstructSignature => |n| {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Signature, symbol.SymbolFlags.None, "");
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                if (n.TypeParameters) |tp| try self.bindChildren(tp);
                if (n.Parameters != 0) try self.bindChildren(n.Parameters);
                if (n.Type) |t| try self.bind(t);
                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .IndexSignature => |n| {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Signature, symbol.SymbolFlags.None, "");
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                if (n.Parameters != 0) try self.bindChildren(n.Parameters);
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
                if (n.TypeParameters) |tp| try self.bindChildren(tp);
                if (n.Parameters != 0) try self.bindChildren(n.Parameters);
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
                if (n.modifiers) |mods| try self.bindChildren(mods);
                if (n.TypeParameters) |tp| try self.bindChildren(tp);
                if (n.Parameters != 0) try self.bindChildren(n.Parameters);
                if (n.Type) |t| try self.bind(t);
                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .TypeParameter => |n| {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.TypeParameter, symbol.SymbolFlags.TypeParameterExcludes, self.getIdentifierName(n.name));
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

                if (n.Type) |t| try self.bind(t);
                if (n.Initializer) |i| try self.bind(i);
            },
            .PropertyDeclaration => |n| {
                var flags = symbol.SymbolFlags.Property;
                var excludes = symbol.SymbolFlags.PropertyExcludes;
                if ((n.modifierFlags & @import("../ast/ast_utils.zig").ModifierFlags.Accessor) != 0) {
                    flags = symbol.SymbolFlags.Accessor;
                    excludes = symbol.SymbolFlags.AccessorExcludes;
                }
                if (n.PostfixToken != 0) flags |= symbol.SymbolFlags.Optional;
                _ = try self.bindPropertyOrMethodOrAccessor(nodeIndex, flags, excludes, self.getIdentifierName(n.name));
                if (n.Type) |t| try self.bind(t);
                if (n.Initializer) |initializer| try self.bind(initializer);
            },
            .GetAccessor => |n| {
                var flags = symbol.SymbolFlags.GetAccessor;
                if (n.PostfixToken != 0) flags |= symbol.SymbolFlags.Optional;
                // Actually Go binder checks getOptionalSymbolFlagForNode but I'll do this for now
                _ = try self.bindPropertyOrMethodOrAccessor(nodeIndex, flags, symbol.SymbolFlags.GetAccessorExcludes, self.getIdentifierName(n.name));
                
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                
                if (n.TypeParameters) |tp| try self.bindChildren(tp);
                if (n.Parameters != 0) try self.bindChildren(n.Parameters);
                if (n.Type) |t| try self.bind(t);
                if (n.Body) |b| try self.bind(b);
                
                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .SetAccessor => |n| {
                var flags = symbol.SymbolFlags.SetAccessor;
                if (n.PostfixToken != 0) flags |= symbol.SymbolFlags.Optional;
                _ = try self.bindPropertyOrMethodOrAccessor(nodeIndex, flags, symbol.SymbolFlags.SetAccessorExcludes, self.getIdentifierName(n.name));
                
                const saveContainer = self.container;
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.container = nodeIndex;
                self.blockScopeContainer = nodeIndex;
                
                if (n.TypeParameters) |tp| try self.bindChildren(tp);
                if (n.Parameters != 0) try self.bindChildren(n.Parameters);
                if (n.Type) |t| try self.bind(t);
                if (n.Body) |b| try self.bind(b);
                
                self.container = saveContainer;
                self.blockScopeContainer = saveBlockScopeContainer;
            },
            .Block => |n| {
                const saveBlockScopeContainer = self.blockScopeContainer;
                self.blockScopeContainer = nodeIndex;

                if (n.Statements != 0) {
                    try self.bindChildren(n.Statements);
                }

                self.blockScopeContainer = saveBlockScopeContainer;
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
                    try self.bindChildren(n.Elements);
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
                const excludes = symbol.SymbolFlags.None;
                if (n.IsExportEquals != 0) {
                    _ = try self.declareSymbolEx(.Exports, containerSym, nodeIndex, flags, excludes, symbol.InternalSymbolNameExportEquals, false, false);
                } else {
                    _ = try self.declareSymbolEx(.Exports, containerSym, nodeIndex, flags, excludes, "default", false, false);
                }
                if (n.Expression != 0) try self.bind(n.Expression);
            },
            .BinaryExpression => |n| {
                const isProp = self.getAssignmentDeclarationKindIsProperty(nodeIndex);
                if (isProp) {
                    try self.bindExpandoPropertyAssignment(nodeIndex);
                }
                try self.bind(n.Left);
                try self.bind(n.Right);
            },
            .ObjectLiteralExpression => |n| {
                _ = try self.bindAnonymousDeclaration(nodeIndex, symbol.SymbolFlags.ObjectLiteral, symbol.InternalSymbolNameObject);
                const saveContainer = self.container;
                self.container = nodeIndex;
                if (n.Properties != 0) {
                    try self.bindChildren(n.Properties);
                }
                self.container = saveContainer;
            },
            .TypeLiteral => |n| {
                _ = try self.bindAnonymousDeclaration(nodeIndex, symbol.SymbolFlags.TypeLiteral, "__type");
                const saveContainer = self.container;
                self.container = nodeIndex;
                if (n.Members != 0) {
                    try self.bindChildren(n.Members);
                }
                self.container = saveContainer;
            },
            .MappedType => |n| {
                _ = try self.bindAnonymousDeclaration(nodeIndex, symbol.SymbolFlags.TypeLiteral, "__type");
                if (n.ReadonlyToken) |rt| try self.bind(rt);
                try self.bind(n.TypeParameter);
                if (n.NameType) |nt| try self.bind(nt);
                if (n.QuestionToken) |qt| try self.bind(qt);
                if (n.Type) |t| try self.bind(t);
            },
            .PropertySignature => |n| {
                var flags = symbol.SymbolFlags.Property;
                if (n.PostfixToken != 0) flags |= symbol.SymbolFlags.Optional;
                _ = try self.bindPropertyOrMethodOrAccessor(nodeIndex, flags, symbol.SymbolFlags.PropertyExcludes, self.getIdentifierName(n.name));
                if (n.Type != 0) try self.bind(n.Type);
                if (n.Initializer != 0) try self.bind(n.Initializer);
            },
            .PropertyAssignment => |n| {
                var flags = symbol.SymbolFlags.Property;
                if (n.PostfixToken != 0) flags |= symbol.SymbolFlags.Optional;
                _ = try self.bindPropertyOrMethodOrAccessor(nodeIndex, flags, symbol.SymbolFlags.PropertyExcludes, self.getIdentifierName(n.name));
                if (n.Initializer != 0) try self.bind(n.Initializer);
            },
            .ShorthandPropertyAssignment => |n| {
                var flags = symbol.SymbolFlags.Property;
                if (n.PostfixToken != 0) flags |= symbol.SymbolFlags.Optional;
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, flags, symbol.SymbolFlags.PropertyExcludes, self.getIdentifierName(n.name));
                if (n.ObjectAssignmentInitializer) |initializer| try self.bind(initializer);
            },
            .ObjectBindingPattern, .ArrayBindingPattern => |n| {
                if (n.Elements != 0) try self.bindChildren(n.Elements);
            },
            .BindingElement => |n| {
                if (n.name) |nameIndex| {
                    try self.bindVariableDeclarationOrBindingElement(nodeIndex, nameIndex);
                    try self.bind(nameIndex);
                }
                if (n.Initializer) |initExpr| try self.bind(initExpr);
            },
            .AwaitExpression => |n| {
                try self.bind(n.Expression);
            },
            .Identifier, .NumericLiteral, .StringLiteral, .EndOfFile => {
                // Do nothing
            },
            .JsxAttributes => |n| {
                _ = try self.bindAnonymousDeclaration(nodeIndex, symbol.SymbolFlags.ObjectLiteral, "__jsxAttributes");
                const saveContainer = self.container;
                self.container = nodeIndex;
                if (n.Properties != 0) {
                    try self.bindChildren(n.Properties);
                }
                self.container = saveContainer;
            },
            .JsxAttribute => |n| {
                _ = try self.declareSymbolAndAddToSymbolTable(nodeIndex, symbol.SymbolFlags.Property, symbol.SymbolFlags.PropertyExcludes, self.getIdentifierName(n.name));
                if (n.Initializer) |initializer| {
                    try self.bind(initializer);
                }
            },
            else => {
                try fallback.bindFallback(self, nodeIndex);
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
            } else {
            }
        } else {
        }
    }

    fn bindDeferredExpandoAssignments(self: *Binder) !void {
        for (self.expandoAssignments.items) |info| {
            self.container = if (info.container == 0) null else info.container;
            self.blockScopeContainer = if (info.blockScopeContainer == 0) null else info.blockScopeContainer;
            try self.bindDeferredExpandoAssignment(info.node);
        }
    }

    pub fn bindChildren(self: *Binder, listIndex: u32) anyerror!void {
        const list = self.ast.getNodeList(listIndex);
        for (list) |childIndex| {
            try self.bind(childIndex);
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
        
        std.debug.print("ZIG SYMBOL DECLARED: {s} (flags: {d}, excludes: 0, existing flags: 0)\n", .{ name, flags });

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
                if (nodeIndex == self.file) {
                    symIndex = try self.declareSymbolEx(.None, 0, nodeIndex, flags, excludes, name, false, false);
                } else {
                    symIndex = try self.declareSourceFileMember(nodeIndex, flags, excludes, name);
                }
            },
            else => {
                symIndex = try self.declareSymbolEx(.Locals, self.blockScopeContainer.?, nodeIndex, flags, excludes, name, false, false);
            },
        }
        
        if (nodeIndex != 0) {
            if (self.ast.getNodeSymbol(nodeIndex) == null) {
            }
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
        try self.symbols.append(self.allocator, .{
            .Name = try self.allocator.dupe(u8, ""),
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
            .CallSignature, .ConstructSignature, .IndexSignature, .MethodDeclaration, .MethodSignature, .Constructor, .GetAccessor, .SetAccessor, .FunctionDeclaration, .FunctionExpression, .ArrowFunction, .TypeAliasDeclaration => {
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
            if (self.ast.getNodeSymbol(nodeIndex) == null) {
            }
        }
        return symIndex;
    }

    fn declareSourceFileMember(self: *Binder, nodeIndex: ast_gen.NodeIndex, flags: u32, excludes: u32, name: []const u8) !ast_gen.SymbolIndex {
        if (ast_utils.isExternalModule(self.ast, self.file)) {
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
            const isExportSpecifier = self.ast.getNode(nodeIndex) == .ExportSpecifier;
            const isImportEquals = self.ast.getNode(nodeIndex) == .ImportEqualsDeclaration;
            if (isExportSpecifier or (isImportEquals and hasExportModifier)) {
                const containerSym = self.ast.getNodeSymbol(self.container.?) orelse 0;
                return try self.declareSymbolEx(.Exports, containerSym, nodeIndex, flags, excludes, name, false, false);
            }
            return try self.declareSymbolEx(.Locals, self.container.?, nodeIndex, flags, excludes, name, false, false);
        }

        if (hasExportModifier or isExportContext) {
            const exportKind = if ((flags & symbol.SymbolFlags.Value) != 0) symbol.SymbolFlags.ExportValue else symbol.SymbolFlags.None;
            const local = try self.declareSymbolEx(.Locals, self.container.?, nodeIndex, exportKind, excludes, name, false, false);
            const containerSym = self.ast.getNodeSymbol(self.container.?) orelse 0;
            const exportSymbol = try self.declareSymbolEx(.Exports, containerSym, nodeIndex, flags, excludes, name, false, false);
            self.symbols.items[local].ExportSymbol = exportSymbol;
            return local;
        }

        return try self.declareSymbolEx(.Locals, self.container.?, nodeIndex, flags, excludes, name, false, false);
    }

    fn declareSymbolEx(self: *Binder, tableType: SymbolTableType, tableId: u32, nodeIndex: ast_gen.NodeIndex, flags: u32, excludes: u32, name: []const u8, isReplaceableByMethod: bool, isComputedName: bool) !ast_gen.SymbolIndex {
        _ = isReplaceableByMethod;
        _ = isComputedName;

        var existingSymIndex: ?ast_gen.SymbolIndex = null;
        
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
            .Parent = if (tableType == .Exports) tableId else null,
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

        std.debug.print("ZIG SYMBOL DECLARED: {s} (flags: {d}, excludes: {d}, existing flags: {d})\n", .{name, flags, excludes, if (existingSymIndex != null) self.symbols.items[existingSymIndex.?].Flags else 0});
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





    fn getIdentifierName(self: *Binder, nodeIndex: ast_gen.NodeIndex) []const u8 {
        const node = self.ast.getNode(nodeIndex);
        switch (node) {
            .Identifier => |i| return i.Text,
            .StringLiteral => |i| return i.Text,
            .NumericLiteral => |i| return i.Text,
            .PrivateIdentifier => |i| return i.Text,
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
};
