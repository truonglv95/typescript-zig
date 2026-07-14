const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const kind = @import("../../ast/kind.zig");
const core = @import("../../core/core.zig");
const transformer_mod = @import("../transformer.zig");
const visitor_mod = @import("../../ast/visitor.zig");
const ast_utils = @import("../../ast/ast_utils.zig");
const printer_pkg = @import("../../printer/printer.zig");
const factory_pkg = @import("../../printer/factory.zig");
const emitflags = @import("../../printer/emitflags.zig");
const helpers = @import("../../printer/helpers.zig");

pub const UsingKind = enum(u32) {
    None = 0,
    Sync = 1,
    Async = 2,
};

pub const UsingDeclarationTransformer = struct {
    allocator: std.mem.Allocator,
    transformer: *transformer_mod.Transformer,
    compilerOptions: *core.CompilerOptions,

    exportBindings: std.StringArrayHashMapUnmanaged(ast_gen.NodeIndex),
    exportVars: std.ArrayListUnmanaged(ast_gen.NodeIndex),
    defaultExportBinding: ast_gen.NodeIndex = 0,
    exportEqualsBinding: ast_gen.NodeIndex = 0,

    pub fn newUsingDeclarationTransformer(allocator: std.mem.Allocator, opt: *transformer_mod.TransformOptions) !*transformer_mod.Transformer {
        const tx = try allocator.create(UsingDeclarationTransformer);
        tx.allocator = allocator;
        tx.compilerOptions = opt.compilerOptions;
        tx.exportBindings = std.StringArrayHashMapUnmanaged(ast_gen.NodeIndex).empty;
        tx.exportVars = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        tx.defaultExportBinding = 0;
        tx.exportEqualsBinding = 0;

        tx.transformer = try transformer_mod.Transformer.init(allocator, visit, tx, opt.context);
        return tx.transformer;
    }

    fn visit(ctx: ?*anyopaque, visitor: *visitor_mod.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const self = @as(*UsingDeclarationTransformer, @ptrCast(@alignCast(ctx.?)));
        const tree = visitor.tree;

        if (node == 0) return 0;

        // TODO: if (node.SubtreeFacts() & ast.SubtreeContainsUsing == 0) return node;
        // Subtree facts aren't implemented fully in zig yet, so we just run the transformer always.

        const nodeData = tree.getNode(node);
        switch (nodeData) {
            .SourceFile => {
                return self.visitSourceFile(visitor, node);
            },
            .Block => {
                return self.visitBlock(visitor, node);
            },
            .ForStatement => {
                return self.visitForStatement(visitor, node);
            },
            .ForInStatement, .ForOfStatement => {
                return self.visitForOfStatement(visitor, node);
            },
            else => {
                return visitor.visitEachChild(node);
            },
        }
    }

    fn visitSourceFile(self: *UsingDeclarationTransformer, visitor: *visitor_mod.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = visitor.tree;
        const n = tree.getNode(node).SourceFile;

        if (ast_utils.isDeclarationFile(tree, node)) {
            return node;
        }

        var visited: ast_gen.NodeIndex = 0;
        const statsList = tree.getNodeList(n.Statements);

        const usingKind = getUsingKindOfStatements(tree, statsList);
        if (usingKind != .None) {
            self.transformer.emitContext.startVariableEnvironment() catch unreachable;

            self.exportBindings.clearRetainingCapacity();
            self.exportVars.clearRetainingCapacity();

            const split = self.transformer.factory.splitStandardPrologue(statsList);
            const prologue = split.prologue;
            const rest = split.statements;

            var topLevelStatements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
            defer topLevelStatements.deinit(self.allocator);

            const visitedPrologue = visitor.visitSlice(prologue);
            if (visitedPrologue.len > 0) topLevelStatements.appendSlice(self.allocator, visitedPrologue) catch unreachable;

            var pos: usize = 0;
            while (pos < rest.len) {
                const statement = rest[pos];
                const uk = getUsingKind(tree, statement);
                if (uk != .None) {
                    if (pos > 0) {
                        const visitedRestSlice = visitor.visitSlice(rest[0..pos]);
                        if (visitedRestSlice.len > 0) topLevelStatements.appendSlice(self.allocator, visitedRestSlice) catch unreachable;
                    }
                    break;
                }
                pos += 1;
            }

            self.transformer.emitContext.requestEmitHelper(&helpers.addDisposableResourceHelper);
            self.transformer.emitContext.requestEmitHelper(&helpers.disposeResourcesHelper);

            // transform the rest of the body
            const envBinding = self.createEnvBinding();
            var bodyStatements = self.transformUsingDeclarations(visitor, rest[pos..], envBinding, &topLevelStatements);
            defer bodyStatements.deinit(self.allocator);

            // add export {} declarations for hoisted bindings.
            if (self.exportBindings.count() > 0) {
                var exportSpecifiers = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
                defer exportSpecifiers.deinit(self.allocator);

                var it = self.exportBindings.iterator();
                while (it.next()) |entry| {
                    exportSpecifiers.append(self.allocator, entry.value_ptr.*) catch unreachable;
                }

                const exportDecl = self.transformer.factory.createExportDeclaration(0, false, self.transformer.factory.createNamedExports(self.transformer.factory.newNodeList(exportSpecifiers.items)), 0, 0);
                topLevelStatements.append(self.allocator, exportDecl) catch unreachable;
            }

            var envVars = self.transformer.emitContext.endVariableEnvironment() catch unreachable;
            defer envVars.deinit(self.allocator);
            topLevelStatements.appendSlice(self.allocator, envVars.items) catch unreachable;

            if (self.exportVars.items.len > 0) {
                const modifier = self.transformer.factory.newToken(.{ .ExportKeyword = {} });
                const modifiersList = self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{modifier});
                const varList = self.transformer.factory.newVariableDeclarationList(self.transformer.factory.newNodeList(self.exportVars.items), ast_utils.NodeFlags.None);
                const varStmt = self.transformer.factory.newVariableStatement(modifiersList, varList);
                topLevelStatements.append(self.allocator, varStmt) catch unreachable;
            }

            var downlevelStmts = self.createDownlevelUsingStatements(bodyStatements.items, envBinding, usingKind == .Async);
            defer downlevelStmts.deinit(self.allocator);
            topLevelStatements.appendSlice(self.allocator, downlevelStmts.items) catch unreachable;

            if (self.exportEqualsBinding != 0) {
                const exportAssign = self.transformer.factory.newExportAssignment(0, true, self.exportEqualsBinding);
                topLevelStatements.append(self.allocator, exportAssign) catch unreachable;
            }

            visited = self.transformer.factory.updateSourceFile(node, n, self.transformer.factory.newNodeList(topLevelStatements.items), n.EndOfFileToken);
        } else {
            visited = visitor.visitEachChild(node);
        }

        // self.transformer.emitContext.addEmitHelper(...)

        self.exportVars.clearRetainingCapacity();
        self.exportBindings.clearRetainingCapacity();
        self.defaultExportBinding = 0;
        self.exportEqualsBinding = 0;

        return visited;
    }

    fn visitBlock(self: *UsingDeclarationTransformer, visitor: *visitor_mod.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self;
        const tree = visitor.tree;
        const n = tree.getNode(node).Block;
        const statsList = tree.getNodeList(n.Statements);

        const usingKind = getUsingKindOfStatements(tree, statsList);
        if (usingKind != .None) {
            // TODO
            return node;
        }
        return visitor.visitEachChild(node);
    }

    fn visitForStatement(self: *UsingDeclarationTransformer, visitor: *visitor_mod.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self;
        return visitor.visitEachChild(node);
    }

    fn visitForOfStatement(self: *UsingDeclarationTransformer, visitor: *visitor_mod.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self;
        return visitor.visitEachChild(node);
    }

    fn transformUsingDeclarations(self: *UsingDeclarationTransformer, visitor: *visitor_mod.NodeVisitor, statementsIn: []const ast_gen.NodeIndex, envBinding: ast_gen.NodeIndex, topLevelStatements: ?*std.ArrayListUnmanaged(ast_gen.NodeIndex)) std.ArrayListUnmanaged(ast_gen.NodeIndex) {
        var statements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;

        for (statementsIn) |statement| {
            const usingKind = getUsingKind(visitor.tree, statement);
            if (usingKind != .None) {
                const varStatement = visitor.tree.getNode(statement).VariableStatement;
                const declarationList = varStatement.DeclarationList;
                var declarations = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
                defer declarations.deinit(self.allocator);

                const decls = visitor.tree.getNodeList(visitor.tree.getNode(declarationList).VariableDeclarationList.Declarations);
                for (decls) |declIndex| {
                    const declaration = visitor.tree.getNode(declIndex).VariableDeclaration;
                    if (!ast_utils.isIdentifier(visitor.tree, declaration.name)) {
                        declarations.clearRetainingCapacity();
                        break;
                    }

                    var initializer = if (declaration.Initializer) |init| visitor.visitNode(init) else 0;
                    if (initializer == 0) {
                        initializer = self.transformer.factory.newVoidZeroExpression();
                    }

                    const newInitializer = self.transformer.factory.createAddDisposableResourceHelper(envBinding, initializer, usingKind == .Async);
                    const newDecl = self.transformer.factory.updateVariableDeclaration(declIndex, declaration, declaration.name, 0, 0, newInitializer);
                    declarations.append(self.allocator, newDecl) catch unreachable;
                }

                if (declarations.items.len > 0) {
                    const varList = self.transformer.factory.newVariableDeclarationList(self.transformer.factory.newNodeList(declarations.items), ast_utils.NodeFlags.Const);
                    self.transformer.emitContext.setOriginal(varList, declarationList) catch {};
                    // setLoc not implemented yet

                    const updatedVarStmt = self.transformer.factory.updateVariableStatement(statement, varStatement, 0, varList);
                    self.hoistOrAppendNode(updatedVarStmt, topLevelStatements, &statements);
                    continue;
                }
            }

            const result = visit(self, visitor, statement);
            if (result != 0) {
                const nodeData = visitor.tree.getNode(result);
                if (nodeData == .SyntaxList) {
                    for (visitor.tree.getNodeList(result)) |n| {
                        self.hoistOrAppendNode(n, topLevelStatements, &statements);
                    }
                } else {
                    self.hoistOrAppendNode(result, topLevelStatements, &statements);
                }
            }
        }
        return statements;
    }

    fn hoistOrAppendNode(self: *UsingDeclarationTransformer, node: ast_gen.NodeIndex, topLevelStatements: ?*std.ArrayListUnmanaged(ast_gen.NodeIndex), statements: *std.ArrayListUnmanaged(ast_gen.NodeIndex)) void {
        const hoisted = self.hoist(node, topLevelStatements);
        if (hoisted != 0) {
            statements.append(self.allocator, hoisted) catch unreachable;
        }
    }

    fn hoist(self: *UsingDeclarationTransformer, node: ast_gen.NodeIndex, topLevelStatements: ?*std.ArrayListUnmanaged(ast_gen.NodeIndex)) ast_gen.NodeIndex {
        if (topLevelStatements == null) return node;

        const nodeData = self.transformer.factory.tree.getNode(node);
        switch (nodeData) {
            .ImportDeclaration, .ImportEqualsDeclaration, .ExportDeclaration, .FunctionDeclaration => {
                topLevelStatements.?.append(self.allocator, node) catch unreachable;
                return 0;
            },
            .ExportAssignment => {
                return self.hoistExportAssignment(node);
            },
            .ClassDeclaration => {
                return self.hoistClassDeclaration(node);
            },
            .VariableStatement => {
                return self.hoistVariableStatement(node);
            },
            else => return node,
        }
    }

    fn hoistExportAssignment(self: *UsingDeclarationTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const n = self.transformer.factory.tree.getNode(node).ExportAssignment;
        if (n.IsExportEquals != 0) {
            return self.hoistExportEquals(node, n);
        } else {
            return self.hoistExportDefault(node, n);
        }
    }

    fn hoistExportDefault(self: *UsingDeclarationTransformer, node: ast_gen.NodeIndex, n: ast_gen.ExportAssignmentNode) ast_gen.NodeIndex {
        if (self.defaultExportBinding != 0) return node;

        self.defaultExportBinding = self.transformer.factory.createUniqueNameEx("_default", .{ .flags = @intFromEnum(factory_pkg.GeneratedIdentifierFlags.ReservedInNestedScopes) | @intFromEnum(factory_pkg.GeneratedIdentifierFlags.FileLevel) | @intFromEnum(factory_pkg.GeneratedIdentifierFlags.Optimistic) }) catch unreachable;
        self.hoistBindingIdentifier(self.defaultExportBinding, true, self.transformer.factory.newIdentifier("default"), node);

        const expression = n.Expression;
        // if isNamedEvaluation, transform... skipped for now.

        const assignment = self.transformer.factory.newAssignmentExpression(self.defaultExportBinding, expression);
        return self.transformer.factory.newExpressionStatement(assignment);
    }

    fn hoistExportEquals(self: *UsingDeclarationTransformer, node: ast_gen.NodeIndex, n: ast_gen.ExportAssignmentNode) ast_gen.NodeIndex {
        if (self.exportEqualsBinding != 0) return node;

        self.exportEqualsBinding = self.transformer.factory.createUniqueNameEx("_default", .{ .flags = @intFromEnum(factory_pkg.GeneratedIdentifierFlags.ReservedInNestedScopes) | @intFromEnum(factory_pkg.GeneratedIdentifierFlags.FileLevel) | @intFromEnum(factory_pkg.GeneratedIdentifierFlags.Optimistic) }) catch unreachable;
        self.transformer.emitContext.addVariableDeclaration(self.exportEqualsBinding);

        const assignment = self.transformer.factory.newAssignmentExpression(self.exportEqualsBinding, n.Expression);
        return self.transformer.factory.newExpressionStatement(assignment);
    }

    fn hoistClassDeclaration(self: *UsingDeclarationTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const n = self.transformer.factory.tree.getNode(node).ClassDeclaration;
        if (n.name == 0 and self.defaultExportBinding != 0) return node;

        const isExported = ast_utils.hasSyntacticModifier(self.transformer.factory.tree, node, ast_utils.ModifierFlags.Export);
        const isDefault = ast_utils.hasSyntacticModifier(self.transformer.factory.tree, node, ast_utils.ModifierFlags.Default);

        var expression = self.transformer.factory.newClassExpression(0, n.name orelse 0, n.TypeParameters orelse 0, n.HeritageClauses orelse 0, n.Members);
        self.transformer.emitContext.setOriginal(expression, node) catch unreachable;

        if (n.name != 0) {
            const rawLocalName = self.transformer.factory.getLocalName(node);
            const text = ast_utils.getText(self.transformer.factory.tree, rawLocalName);
            const localName = self.transformer.factory.newIdentifier(text);
            self.transformer.emitContext.addEmitFlags(localName, emitflags.EmitFlags.LocalName) catch unreachable;
            self.hoistBindingIdentifier(localName, isExported and !isDefault, 0, node);

            const declName = self.transformer.factory.getDeclarationName(node);
            expression = self.transformer.factory.newAssignmentExpression(declName, expression);
            self.transformer.emitContext.setOriginal(expression, node) catch unreachable;
        }

        if (isDefault and self.defaultExportBinding == 0) {
            self.defaultExportBinding = self.transformer.factory.createUniqueNameEx("_default", .{ .flags = @intFromEnum(factory_pkg.GeneratedIdentifierFlags.ReservedInNestedScopes) | @intFromEnum(factory_pkg.GeneratedIdentifierFlags.FileLevel) | @intFromEnum(factory_pkg.GeneratedIdentifierFlags.Optimistic) }) catch unreachable;
            self.hoistBindingIdentifier(self.defaultExportBinding, true, self.transformer.factory.newIdentifier("default"), node);
            expression = self.transformer.factory.newAssignmentExpression(self.defaultExportBinding, expression);
            self.transformer.emitContext.setOriginal(expression, node) catch unreachable;
        }

        return self.transformer.factory.newExpressionStatement(expression);
    }

    fn hoistVariableStatement(self: *UsingDeclarationTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const n = self.transformer.factory.tree.getNode(node).VariableStatement;
        const isExported = ast_utils.hasSyntacticModifier(self.transformer.factory.tree, node, ast_utils.ModifierFlags.Export);
        var expressions = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer expressions.deinit(self.allocator);

        const decls = self.transformer.factory.tree.getNodeList(self.transformer.factory.tree.getNode(n.DeclarationList).VariableDeclarationList.Declarations);
        for (decls) |declIndex| {
            const decl = self.transformer.factory.tree.getNode(declIndex).VariableDeclaration;
            self.hoistBindingElement(decl.name, isExported, declIndex);
            if (decl.Initializer != null) {
                expressions.append(self.allocator, self.hoistInitializedVariable(declIndex, decl)) catch unreachable;
            }
        }

        if (expressions.items.len > 0) {
            const inlined = self.transformer.factory.inlineExpressions(expressions.items);
            const statement = self.transformer.factory.newExpressionStatement(inlined);
            self.transformer.emitContext.setOriginal(statement, node) catch unreachable;
            return statement;
        }
        return 0;
    }

    fn hoistInitializedVariable(self: *UsingDeclarationTransformer, node: ast_gen.NodeIndex, n: ast_gen.VariableDeclarationNode) ast_gen.NodeIndex {
        var target: ast_gen.NodeIndex = 0;
        if (ast_utils.isIdentifier(self.transformer.factory.tree, n.name)) {
            // target = clone(n.name)
            target = self.transformer.factory.newIdentifier(ast_utils.getText(self.transformer.factory.tree, n.name));
            // clear emit flags
        } else {
            // convertBindingPattern
            target = n.name;
        }

        const assignment = self.transformer.factory.newAssignmentExpression(target, n.Initializer orelse 0);
        self.transformer.emitContext.setOriginal(assignment, node) catch unreachable;
        return assignment;
    }

    fn hoistBindingElement(self: *UsingDeclarationTransformer, name: ast_gen.NodeIndex, isExported: bool, original: ast_gen.NodeIndex) void {
        if (ast_utils.isBindingPattern(self.transformer.factory.tree, name)) {
            // loop elements
        } else {
            self.hoistBindingIdentifier(name, isExported, 0, original);
        }
    }

    fn hoistBindingIdentifier(self: *UsingDeclarationTransformer, node: ast_gen.NodeIndex, isExport: bool, exportAlias: ast_gen.NodeIndex, original: ast_gen.NodeIndex) void {
        const name = node; // should clone
        if (isExport) {
            if (exportAlias == 0 and (self.transformer.emitContext.getEmitFlags(name) & emitflags.EmitFlags.LocalName) == 0) {
                const varDecl = self.transformer.factory.newVariableDeclaration(name, 0, 0, 0);
                if (original != 0) self.transformer.emitContext.setOriginal(varDecl, original) catch unreachable;
                self.exportVars.append(self.allocator, varDecl) catch unreachable;
                return;
            }

            var localName: ast_gen.NodeIndex = 0;
            var exportName: ast_gen.NodeIndex = 0;
            if (exportAlias != 0) {
                localName = name;
                exportName = exportAlias;
            } else {
                exportName = name;
            }
            const specifier = self.transformer.factory.newExportSpecifier(false, localName, exportName);
            if (original != 0) self.transformer.emitContext.setOriginal(specifier, original) catch unreachable;

            const text = ast_utils.getText(self.transformer.factory.tree, name);
            if (!self.exportBindings.contains(text)) {
                self.exportBindings.put(self.allocator, text, specifier) catch unreachable;
            }
        }
        self.transformer.emitContext.addVariableDeclaration(name);
    }

    fn createEnvBinding(self: *UsingDeclarationTransformer) ast_gen.NodeIndex {
        return self.transformer.factory.createUniqueName("env_1") catch unreachable;
    }

    fn createDownlevelUsingStatements(self: *UsingDeclarationTransformer, bodyStatements: []const ast_gen.NodeIndex, envBinding: ast_gen.NodeIndex, async_kind: bool) std.ArrayListUnmanaged(ast_gen.NodeIndex) {
        var statements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;

        const stackIdent = self.transformer.factory.newIdentifier("stack");
        const stackArr = self.transformer.factory.newArrayLiteralExpression(0, false);
        const stackProp = self.transformer.factory.newPropertyAssignment(0, stackIdent, 0, 0, stackArr);

        const errorIdent = self.transformer.factory.newIdentifier("error");
        const errorVoid = self.transformer.factory.newVoidZeroExpression();
        const errorProp = self.transformer.factory.newPropertyAssignment(0, errorIdent, 0, 0, errorVoid);

        const hasErrorIdent = self.transformer.factory.newIdentifier("hasError");
        const hasErrorFalse = self.transformer.factory.newFalseExpression();
        const hasErrorProp = self.transformer.factory.newPropertyAssignment(0, hasErrorIdent, 0, 0, hasErrorFalse);

        const envObjElements = self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{ stackProp, errorProp, hasErrorProp });
        const envObj = self.transformer.factory.newObjectLiteralExpression(envObjElements, false);

        const envVar = self.transformer.factory.newVariableDeclaration(envBinding, 0, 0, envObj);
        const envVarList = self.transformer.factory.newVariableDeclarationList(self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{envVar}), ast_utils.NodeFlags.Const);
        const envVarStatement = self.transformer.factory.newVariableStatement(0, envVarList);
        statements.append(self.allocator, envVarStatement) catch unreachable;

        const tryBlock = self.transformer.factory.createBlock(self.transformer.factory.newNodeList(bodyStatements), true);

        const catchBinding = self.transformer.factory.newIdentifier("e_1");
        const catchDecl = self.transformer.factory.newVariableDeclaration(catchBinding, 0, 0, 0);

        const errorAssign = self.transformer.factory.newAssignmentExpression(self.transformer.factory.newPropertyAccessExpression(envBinding, 0, errorIdent, 0), catchBinding);
        const errorAssignStmt = self.transformer.factory.newExpressionStatement(errorAssign);

        const hasErrorAssign = self.transformer.factory.newAssignmentExpression(self.transformer.factory.newPropertyAccessExpression(envBinding, 0, hasErrorIdent, 0), self.transformer.factory.newTrueExpression());
        const hasErrorAssignStmt = self.transformer.factory.newExpressionStatement(hasErrorAssign);

        const catchBlock = self.transformer.factory.createBlock(self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{ errorAssignStmt, hasErrorAssignStmt }), true);
        const catchClause = self.transformer.factory.newCatchClause(catchDecl, catchBlock);

        var finallyBlock: ast_gen.NodeIndex = 0;
        if (async_kind) {
            const result = self.transformer.factory.createUniqueName("result") catch unreachable;
            const disposeHelper = self.transformer.factory.createDisposeResourcesHelper(envBinding);
            const resDecl = self.transformer.factory.newVariableDeclaration(result, 0, 0, disposeHelper);
            const resVarList = self.transformer.factory.newVariableDeclarationList(self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{resDecl}), 0);
            const resVarStmt = self.transformer.factory.newVariableStatement(0, resVarList);

            const awaitExpr = self.transformer.factory.newAwaitExpression(result);
            const awaitStmt = self.transformer.factory.newExpressionStatement(awaitExpr);
            const ifStmt = self.transformer.factory.newIfStatement(result, awaitStmt, 0);

            finallyBlock = self.transformer.factory.createBlock(self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{ resVarStmt, ifStmt }), true);
        } else {
            const disposeHelper = self.transformer.factory.createDisposeResourcesHelper(envBinding);
            const disposeStmt = self.transformer.factory.newExpressionStatement(disposeHelper);
            finallyBlock = self.transformer.factory.createBlock(self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{disposeStmt}), true);
        }

        const tryStatement = self.transformer.factory.newTryStatement(tryBlock, catchClause, finallyBlock);
        statements.append(self.allocator, tryStatement) catch unreachable;

        return statements;
    }
    fn getUsingKindOfStatements(tree: *ast.Ast, statements: []const ast_gen.NodeIndex) UsingKind {
        var result: UsingKind = .None;
        for (statements) |statement| {
            const usingKind = getUsingKind(tree, statement);
            if (usingKind == .Async) {
                return .Async;
            }
            if (@intFromEnum(usingKind) > @intFromEnum(result)) {
                result = usingKind;
            }
        }
        return result;
    }

    fn getUsingKind(tree: *ast.Ast, statement: ast_gen.NodeIndex) UsingKind {
        const nodeData = tree.getNode(statement);
        if (nodeData == .VariableStatement) {
            return getUsingKindOfVariableStatement(tree, statement);
        }
        return .None;
    }

    fn getUsingKindOfVariableStatement(tree: *ast.Ast, node: ast_gen.NodeIndex) UsingKind {
        const n = tree.getNode(node).VariableStatement;
        if (n.DeclarationList == 0) return .None;
        return getUsingKindOfVariableDeclarationList(tree, n.DeclarationList);
    }

    fn getUsingKindOfVariableDeclarationList(tree: *ast.Ast, node: ast_gen.NodeIndex) UsingKind {
        const n = tree.getNode(node).VariableDeclarationList;
        const blockScoped = n.Flags & ast_utils.NodeFlags.BlockScoped;
        switch (blockScoped) {
            ast_utils.NodeFlags.AwaitUsing => return .Async,
            ast_utils.NodeFlags.Using => return .Sync,
            else => return .None,
        }
    }
};
