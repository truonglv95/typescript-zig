const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const visitor = @import("../../ast/visitor.zig");
const kind = @import("../../ast/kind.zig");
const binder = @import("../../binder/binder.zig");
const core = @import("../../core/core.zig");
const printer = @import("../../printer/printer.zig");
const transformers = @import("../transformer.zig");
const factory = @import("../../printer/factory.zig");
const ast_utils = @import("../../ast/ast_utils.zig");
const referenceresolver = @import("../../binder/referenceresolver.zig");
const emitresolver = @import("../../printer/emitresolver.zig");

pub const LegacyDecoratorsTransformer = struct {
    base: transformers.Transformer,
    languageVersion: core.ScriptTarget,
    referenceResolver: *referenceresolver.ReferenceResolver,

    classAliases: std.AutoHashMap(ast.NodeIndex, ast.NodeIndex),
    enclosingClasses: std.ArrayList(ast.NodeIndex),
    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, opt: *transformers.TransformOptions) *transformers.Transformer {
        var tx = allocator.create(LegacyDecoratorsTransformer) catch unreachable;
        tx.* = .{
            .base = undefined,
            .languageVersion = opt.compilerOptions.target,
            .referenceResolver = opt.resolver.?,
            .classAliases = std.AutoHashMap(ast.NodeIndex, ast.NodeIndex).init(allocator),
            .enclosingClasses = std.ArrayListUnmanaged(ast.NodeIndex).empty,
            .allocator = allocator,
        };
        tx.base = (transformers.Transformer.init(allocator, @as(*const fn (?*anyopaque, *visitor.NodeVisitor, u32) u32, @ptrCast(&visit)), tx, opt.context) catch @panic("OOM")).*;
        return &tx.base;
    }

    fn getSelf(tx: *transformers.Transformer) *LegacyDecoratorsTransformer {
        return @fieldParentPtr("base", tx);
    }

    fn visit(tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        var self = getSelf(tx);
        if ((ast_utils.subtreeFacts(node) & ast.SubtreeContainsDecorators) == 0 and self.enclosingClasses.items.len == 0) {
            return node;
        }

        switch (ast_utils.getKind(node)) {
            .Identifier => return self.visitIdentifier(tx, node),
            .PropertyAccessExpression => return self.visitPropertyAccessExpression(tx, node),
            .Decorator => return 0,
            .ClassDeclaration => return self.visitClassDeclaration(tx, node),
            .ClassExpression => return self.visitClassExpression(tx, node),
            .Constructor => return self.visitConstructorDeclaration(tx, node),
            .MethodDeclaration => return self.visitMethodDeclaration(tx, node),
            .SetAccessor => return self.visitSetAccessorDeclaration(tx, node),
            .GetAccessor => return self.visitGetAccessorDeclaration(tx, node),
            .PropertyDeclaration => return self.visitPropertyDeclaration(tx, node),
            .Parameter => return self.visitParamerDeclaration(tx, node),
            .SourceFile => {
                self.classAliases.clearRetainingCapacity();
                self.enclosingClasses.clearRetainingCapacity();
                const result = tx.visitor.visitEachChild(node);
                tx.emitContext.addEmitHelpers(result, tx.emitContext.readEmitHelpers());
                self.classAliases.clearRetainingCapacity();
                self.enclosingClasses.clearRetainingCapacity();
                return result;
            },
            else => return tx.visitor.visitEachChild(node),
        }
    }

    fn visitIdentifier(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        for (self.enclosingClasses.items) |d| {
            if (self.classAliases.get(d)) |alias| {
                if (self.referenceResolver.getReferencedValueDeclaration(tx.emitContext.mostOriginal(node)) == tx.emitContext.mostOriginal(d)) {
                    return alias;
                }
            }
        }
        return node;
    }

    fn visitPropertyAccessExpression(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        _ = self;
        const expression = tx.visitor.visitNode(ast_utils.expression(node));
        if (expression != ast_utils.expression(node)) {
            return tx.factory.updatePropertyAccessExpression(node, expression, ast_utils.questionDotToken(node), ast_utils.name(node), ast_utils.getFlags(node));
        }
        return node;
    }

    fn finishClassElement(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, updated: ast.NodeIndex, original: ast.NodeIndex) ast.NodeIndex {
        _ = self;
        if (updated != original) {
            tx.emitContext.setCommentRange(updated, ast_utils.loc(original));
            tx.emitContext.setSourceMapRange(updated, ast_utils.moveRangePastModifiers(original));
        }
        return updated;
    }

    fn visitParamerDeclaration(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        _ = self;
        const updated = tx.factory.updateParameterDeclaration(
            node, tx.visitor.tree.getNode(node).Parameter,
                elideModifiers(tx.factory, (ast_utils.getModifiers(tx.visitor.tree, node) orelse 0)),
            ast_utils.dotDotDotToken(node),
            tx.visitor.visitNode(ast_utils.name(node)),
            0,
            0,
            tx.visitor.visitNode(ast_utils.initializer(node)),
        );
        if (updated != node) {
            tx.emitContext.setCommentRange(updated, ast_utils.loc(node));
            const newLoc = ast_utils.moveRangePastModifiers(node);
            ast_utils.setLoc(tx.emitContext.tree, updated, newLoc);
            tx.emitContext.setSourceMapRange(updated, newLoc);
            _ = tx.emitContext.setEmitFlags(ast_utils.name(updated), 0) catch {};
        }
        return updated;
    }

    fn visitPropertyNameOfClassElement(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, member: ast.NodeIndex) ast.NodeIndex {
        _ = self;
        const name = ast_utils.name(member);
        if (ast_utils.isComputedPropertyName(name) and ast_utils.hasDecorators(tx.visitor.tree, member)) {
            const expression = tx.visitor.visitNode(ast_utils.expression(name));
            const innerExpression = ast_utils.skipPartiallyEmittedExpressions(expression);
            if (!ast_utils.isSimpleInlineableExpression(innerExpression)) {
                const generatedName = tx.factory.newGeneratedNameForNode(name);
                tx.emitContext.addVariableDeclaration(generatedName);
                return tx.factory.updateComputedPropertyName(name, tx.factory.newAssignmentExpression(generatedName, expression));
            }
        }
        return tx.visitor.visitNode(name);
    }

    fn visitPropertyDeclaration(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        if ((ast_utils.getFlags(node) & ast.NodeFlagsAmbient) != 0) {
            return 0;
        }
        if (ast_utils.hasSyntacticModifier(tx.visitor.tree, node, ast.ModifierFlagsAmbient | ast.ModifierFlagsAbstract)) {
            return 0;
        }

        return self.finishClassElement(
            tx,
            tx.factory.updatePropertyDeclaration(
                node, tx.visitor.tree.getNode(node).PropertyDeclaration,
                tx.visitor.visitModifiers((ast_utils.getModifiers(tx.visitor.tree, node) orelse 0)),
                self.visitPropertyNameOfClassElement(tx, node),
                0,
                0,
                tx.visitor.visitNode(ast_utils.initializer(node)),
            ),
            node,
        );
    }

    fn visitGetAccessorDeclaration(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        return self.finishClassElement(
            tx,
            tx.factory.updateGetAccessorDeclaration(
                node, tx.visitor.tree.getNode(node).GetAccessor,
                tx.visitor.visitModifiers((ast_utils.getModifiers(tx.visitor.tree, node) orelse 0)),
                self.visitPropertyNameOfClassElement(tx, node),
                0,
                tx.visitor.visitNodes(ast_utils.parameters(node)),
                0,
                tx.visitor.visitNode(ast_utils.getBody(node)),
            ),
            node,
        );
    }

    fn visitSetAccessorDeclaration(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        return self.finishClassElement(
            tx,
            tx.factory.updateSetAccessorDeclaration(
                node, tx.visitor.tree.getNode(node).SetAccessor,
                tx.visitor.visitModifiers((ast_utils.getModifiers(tx.visitor.tree, node) orelse 0)),
                self.visitPropertyNameOfClassElement(tx, node),
                0,
                tx.visitor.visitNodes(ast_utils.parameters(node)),
                0,
                tx.visitor.visitNode(ast_utils.getBody(node)),
            ),
            node,
        );
    }

    fn visitMethodDeclaration(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        return self.finishClassElement(
            tx,
            tx.factory.updateMethodDeclaration(
                node, tx.visitor.tree.getNode(node).MethodDeclaration,
                tx.visitor.visitModifiers((ast_utils.getModifiers(tx.visitor.tree, node) orelse 0)),
                ast_utils.asteriskToken(node),
                self.visitPropertyNameOfClassElement(tx, node),
                0,
                0,
                tx.visitor.visitNodes(ast_utils.parameters(node)),
                0,
                tx.visitor.visitNode(ast_utils.getBody(node)),
            ),
            node,
        );
    }

    fn visitConstructorDeclaration(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        _ = self;
        return tx.factory.updateConstructorDeclaration(
            node, tx.visitor.tree.getNode(node).Constructor,
                tx.visitor.visitModifiers((ast_utils.getModifiers(tx.visitor.tree, node) orelse 0)),
            0,
            tx.visitor.visitNodes(ast_utils.parameters(node)),
            0,
            tx.visitor.visitNode(ast_utils.getBody(node)),
        );
    }

    fn visitClassExpression(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        _ = self;
        return tx.factory.updateClassExpression(
            node, tx.visitor.tree.getNode(node).ClassExpression,
                tx.visitor.visitModifiers((ast_utils.getModifiers(tx.visitor.tree, node) orelse 0)),
            ast_utils.name(node),
            0,
            tx.visitor.visitNodes(ast_utils.heritageClauses(node)),
            tx.visitor.visitNodes(ast_utils.members(node)),
        );
    }

    fn visitClassDeclaration(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        const decorated = ast_utils.classOrConstructorParameterIsDecorated(tx.emitContext.tree, 0, node);
        if (!(decorated or ast_utils.childIsDecorated(true, node, 0))) {
            return tx.visitor.visitEachChild(node);
        }

        if (decorated) {
            return self.transformClassDeclarationWithClassDecorators(tx, node, ast_utils.name(node));
        }
        return self.transformClassDeclarationWithoutClassDecorators(tx, node, ast_utils.name(node));
    }

    fn transformClassDeclarationWithoutClassDecorators(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex, nodeName: ast.NodeIndex) ast.NodeIndex {
        const modifiers = tx.visitor.visitModifiers((ast_utils.getModifiers(tx.visitor.tree, node) orelse 0));
        const heritageClauses = tx.visitor.visitNodes(ast_utils.heritageClauses(node));
        const initialMembers = tx.visitor.visitNodes(ast_utils.members(node));

        const membersAndDecorations = self.transformDecoratorsOfClassElements(tx, node, initialMembers);
        const members = membersAndDecorations.members;
        const decorationStatements = membersAndDecorations.decorationStatements;

        var name = nodeName;
        if (name == 0 and decorationStatements.items.len > 0) {
            name = tx.factory.newGeneratedNameForNode(node);
        }

        const updated = tx.factory.updateClassDeclaration(
            node, tx.visitor.tree.getNode(node).ClassDeclaration,
            modifiers,
            name,
            0,
            heritageClauses,
            members,
        );

        if (decorationStatements.items.len == 0) {
            return updated;
        }

        var list = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        list.append(self.allocator, updated) catch unreachable;
        list.appendSlice(self.allocator, decorationStatements.items) catch unreachable;
        const result = tx.factory.newSyntaxList(list.items);
        return result;
    }

    fn popEnclosingClass(self: *LegacyDecoratorsTransformer) void {
        _ = self.enclosingClasses.pop();
    }

    fn pushEnclosingClass(self: *LegacyDecoratorsTransformer, cls: ast.NodeIndex) void {
        self.enclosingClasses.append(self.allocator, cls) catch unreachable;
    }

    fn transformClassDeclarationWithClassDecorators(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex, name: ast.NodeIndex) ast.NodeIndex {
        const isExport = ast_utils.hasSyntacticModifier(tx.visitor.tree, node, ast.ModifierFlagsExport);
        const isDefault = ast_utils.hasSyntacticModifier(tx.visitor.tree, node, ast.ModifierFlagsDefault);

        var modifiers: ast.NodeIndex = 0;
        const nodeModifiers = (ast_utils.getModifiers(tx.visitor.tree, node) orelse 0);
        if (nodeModifiers != 0 and ast_utils.nodesLen(nodeModifiers) > 0) {
            var modifierNodes = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            const nodes = ast_utils.getNodes(nodeModifiers);
            for (nodes) |m| {
                if (isNotExportOrDefaultOrDecorator(m)) {
                    modifierNodes.append(self.allocator, m) catch unreachable;
                }
            }
            if (modifierNodes.items.len != nodes.len) {
                modifiers = tx.factory.newModifierList(modifierNodes.items);
                ast_utils.setLoc(tx.emitContext.tree, modifiers, ast_utils.loc(nodeModifiers));
            } else {
                modifiers = nodeModifiers;
            }
        }

        const location = ast_utils.moveRangePastModifiers(node);
        const classAlias = self.getClassAliasIfNeeded(tx, node);
        if (classAlias != 0) {
            self.pushEnclosingClass(node);
        }

        const declName = tx.factory.getLocalNameEx(node, .{ .allowComments = false, .allowSourceMaps = true });

        const heritageClauses = tx.visitor.visitNodes(ast_utils.heritageClauses(node));
        var members = tx.visitor.visitNodes(ast_utils.members(node));

        const membersAndDecorations = self.transformDecoratorsOfClassElements(tx, node, members);
        members = membersAndDecorations.members;
        const decorationStatements = membersAndDecorations.decorationStatements;

        const assignClassAliasInStaticBlock = @intFromEnum(self.languageVersion) >= @intFromEnum(core.ScriptTarget.ES2022) and classAlias != 0 and members != 0 and ast_utils.nodesLen(members) > 0 and ast_utils.some(ast_utils.getNodes(members), isClassStaticBlockDeclarationOrStaticProperty);

        if (assignClassAliasInStaticBlock) {
            var memberList = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            
            const assignment = tx.factory.newAssignmentExpression(classAlias, tx.factory.newKeywordExpression(.ThisKeyword));
            const stmt = tx.factory.newExpressionStatement(assignment);
            const stmtList = tx.factory.newNodeList(&[_]ast.NodeIndex{stmt});
            const block = tx.factory.newBlock(stmtList, false);
            memberList.append(self.allocator, tx.factory.newClassStaticBlockDeclaration(0, block)) catch unreachable;
            
            memberList.appendSlice(self.allocator, ast_utils.getNodes(members)) catch unreachable;
            
            const newList = tx.factory.newNodeList(memberList.items);
            ast_utils.setLoc(undefined, newList, ast_utils.loc(members));
            members = newList;
        }

        var exprName = name;
        if (name != 0 and transformers.isGeneratedIdentifier(tx.emitContext, name)) {
            exprName = 0;
        }

        const classExpression = tx.factory.newClassExpression(
            modifiers,
            exprName,
            0,
            heritageClauses,
            members,
        );

        _ = tx.emitContext.setOriginal(classExpression, node) catch {};
        ast_utils.setLoc(tx.emitContext.tree, classExpression, location);

        var varInitializer = classExpression;
        if (classAlias != 0 and !assignClassAliasInStaticBlock) {
            varInitializer = tx.factory.newAssignmentExpression(classAlias, classExpression);
        }

        const varDecl = tx.factory.newVariableDeclaration(declName, 0, 0, varInitializer);
        _ = tx.emitContext.setOriginal(varDecl, node) catch {};

        const varDeclList = tx.factory.newVariableDeclarationList(tx.factory.newNodeList(&[_]ast.NodeIndex{varDecl}), ast.NodeFlagsLet);
        const varStatement = tx.factory.newVariableStatement(0, varDeclList);
        _ = tx.emitContext.setOriginal(varStatement, node) catch {};
        ast_utils.setLoc(tx.emitContext.tree, varStatement, location);
        tx.emitContext.setCommentRange(varStatement, ast_utils.loc(node));

        var statements = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        statements.append(self.allocator, varStatement) catch unreachable;
        statements.appendSlice(self.allocator, decorationStatements.items) catch unreachable;
        const constructorDecStmt = self.getConstructorDecorationStatement(tx, node);
        if (constructorDecStmt != 0) {
            statements.append(self.allocator, constructorDecStmt) catch unreachable;
        }

        if (isExport) {
            var exportStatement: ast.NodeIndex = 0;
            if (isDefault) {
                exportStatement = tx.factory.newExportDefault(declName);
            } else {
                exportStatement = tx.factory.newExternalModuleExport(tx.factory.getDeclarationName(node));
            }
            statements.append(self.allocator, exportStatement) catch unreachable;
        }

        if (classAlias != 0) {
            self.popEnclosingClass();
        }

        if (statements.items.len == 1) {
            return statements.items[0];
        }
        return tx.factory.newSyntaxList(statements.items);
    }

    fn hasInternalStaticReference(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) bool {
        const classNode = tx.emitContext.mostOriginal(node);
        
        const Context = struct {
            tx: *transformers.Transformer,
            self_tx: *LegacyDecoratorsTransformer,
            classNode: ast.NodeIndex,
            
            fn check(ctx: *@This(), n: ast.NodeIndex) bool {
                if (n == 0) return false;
                if (ast_utils.isIdentifier(n) and ctx.self_tx.referenceResolver.getReferencedValueDeclaration(ctx.tx.emitContext.mostOriginal(n)) == ctx.classNode) {
                    return true;
                }
                if (ast_utils.isPropertyAccessExpression(n)) {
                    return check(ctx, ast_utils.expression(n));
                }
                return ast_utils.forEachChildBool(n, ctx, check);
            }
        };
        var ctx = Context{
            .tx = tx,
            .self_tx = self,
            .classNode = classNode,
        };
        
        const membersNode = ast_utils.members(node);
        if (membersNode != 0) {
            for (ast_utils.getNodes(membersNode)) |member| {
                if (ast_utils.forEachChildBool(member, &ctx, Context.check)) {
                    return true;
                }
            }
        }
        return false;
    }

    fn getClassAliasIfNeeded(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        if (!self.hasInternalStaticReference(tx, node)) {
            return 0;
        }
        var nameText: []const u8 = "default";
        const nodeName = ast_utils.name(node);
        if (nodeName != 0 and !transformers.isGeneratedIdentifier(tx.emitContext, nodeName)) {
            nameText = ast_utils.getText(undefined, nodeName);
        }

        const classAlias = tx.factory.newUniqueName(nameText);
        tx.emitContext.addVariableDeclaration(classAlias);
        self.classAliases.put(node, classAlias) catch unreachable;

        return classAlias;
    }

    fn getConstructorDecorationStatement(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        const expression = self.generateConstructorDecorationExpression(tx, node);
        if (expression != 0) {
            const result = tx.factory.newExpressionStatement(expression);
            _ = tx.emitContext.setOriginal(result, node) catch {};
            return result;
        }
        return 0;
    }

    fn generateConstructorDecorationExpression(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        const allDecorators = self.getAllDecoratorsOfClass(node, true);
        const hasAlias = self.enclosingClasses.items.len > 0 and self.enclosingClasses.items[self.enclosingClasses.items.len - 1] == node;
        if (hasAlias) {
            self.popEnclosingClass();
        }
        const decoratorExpressions = self.transformAllDecoratorsOfDeclaration(tx, allDecorators);
        if (hasAlias) {
            self.pushEnclosingClass(node);
        }
        if (decoratorExpressions.len == 0) {
            return 0;
        }

        var classAlias: ast.NodeIndex = 0;
        if (self.classAliases.get(node)) |alias| {
            classAlias = alias;
        }

        const localName = tx.factory.getDeclarationNameEx(node, .{ .allowComments = false, .allowSourceMaps = true });
        const decorate = tx.factory.newDecorateHelper(decoratorExpressions, localName, 0, 0);
        var assignmentTarget = decorate;
        if (classAlias != 0) {
            assignmentTarget = tx.factory.newAssignmentExpression(classAlias, decorate);
        }
        const expression = tx.factory.newAssignmentExpression(localName, assignmentTarget);
        _ = tx.emitContext.setEmitFlags(expression, 0) catch {};
        tx.emitContext.setSourceMapRange(expression, ast_utils.moveRangePastModifiers(node));
        return expression;
    }

    const AllDecorators = struct {
        decorators: []const ast.NodeIndex,
        parameters: [][]const ast.NodeIndex,
    };

    fn getAllDecoratorsOfClass(self: *LegacyDecoratorsTransformer, node: ast.NodeIndex, useLegacyDecorators: bool) AllDecorators {
        const decoratorsNode = ast_utils.decorators(node);
        var parameters: [][]const ast.NodeIndex = &[_][]const ast.NodeIndex{};
        if (useLegacyDecorators) {
            parameters = self.getDecoratorsOfParameters(ast_utils.getFirstConstructorWithBody(undefined, node));
        }
        return .{
            .decorators = if (decoratorsNode != 0) ast_utils.getNodes(decoratorsNode) else &[_]ast.NodeIndex{},
            .parameters = parameters,
        };
    }

    fn getAllDecoratorsOfClassElement(self: *LegacyDecoratorsTransformer, member: ast.NodeIndex, parent: ast.NodeIndex, useLegacyDecorators: bool) AllDecorators {
        switch (ast_utils.getKind(member)) {
            .GetAccessor, .SetAccessor => {
                if (!useLegacyDecorators) {
                    return self.getAllDecoratorsOfMethod(member, false);
                }
                return self.getAllDecoratorsOfAccessors(member, parent, true);
            },
            .MethodDeclaration => {
                return self.getAllDecoratorsOfMethod(member, useLegacyDecorators);
            },
            .PropertyDeclaration => {
                return self.getAllDecoratorsOfProperty(member);
            },
            else => return .{ .decorators = &[_]ast.NodeIndex{}, .parameters = &[_][]const ast.NodeIndex{} },
        }
    }

    fn getAllDecoratorsOfAccessors(self: *LegacyDecoratorsTransformer, accessor: ast.NodeIndex, parent: ast.NodeIndex, useLegacyDecorators: bool) AllDecorators {
        if (ast_utils.getBody(accessor) == 0) {
            return .{ .decorators = &[_]ast.NodeIndex{}, .parameters = &[_][]const ast.NodeIndex{} };
        }
        const decls = ast_utils.getAllAccessorDeclarations(undefined, ast_utils.getNodes(ast_utils.members(parent)), accessor);
        var firstAccessorWithDecorators: ast.NodeIndex = 0;
        if (ast_utils.hasDecorators(undefined, decls.firstAccessor)) {
            firstAccessorWithDecorators = decls.firstAccessor;
        } else if (decls.secondAccessor != 0 and ast_utils.hasDecorators(undefined, decls.secondAccessor)) {
            firstAccessorWithDecorators = decls.secondAccessor;
        }

        if (firstAccessorWithDecorators == 0 or accessor != firstAccessorWithDecorators) {
            return .{ .decorators = &[_]ast.NodeIndex{}, .parameters = &[_][]const ast.NodeIndex{} };
        }

        const decoratorsNode = ast_utils.decorators(firstAccessorWithDecorators);
        const decorators = if (decoratorsNode != 0) ast_utils.getNodes(decoratorsNode) else &[_]ast.NodeIndex{};
        var parameters: [][]const ast.NodeIndex = &[_][]const ast.NodeIndex{};
        if (useLegacyDecorators and decls.setAccessor != 0) {
            parameters = self.getDecoratorsOfParameters(decls.setAccessor);
        }

        return .{
            .decorators = decorators,
            .parameters = parameters,
        };
    }

    fn getAllDecoratorsOfProperty(self: *LegacyDecoratorsTransformer, property: ast.NodeIndex) AllDecorators {
        _ = self;
        const decoratorsNode = ast_utils.decorators(property);
        const decorators = if (decoratorsNode != 0) ast_utils.getNodes(decoratorsNode) else &[_]ast.NodeIndex{};
        return .{ .decorators = decorators, .parameters = &[_][]const ast.NodeIndex{} };
    }

    fn getAllDecoratorsOfMethod(self: *LegacyDecoratorsTransformer, method: ast.NodeIndex, useLegacyDecorators: bool) AllDecorators {
        if (ast_utils.getBody(method) == 0) {
            return .{ .decorators = &[_]ast.NodeIndex{}, .parameters = &[_][]const ast.NodeIndex{} };
        }
        const decoratorsNode = ast_utils.decorators(method);
        const decorators = if (decoratorsNode != 0) ast_utils.getNodes(decoratorsNode) else &[_]ast.NodeIndex{};
        var parameters: [][]const ast.NodeIndex = &[_][]const ast.NodeIndex{};
        if (useLegacyDecorators) {
            parameters = self.getDecoratorsOfParameters(method);
        }
        return .{ .decorators = decorators, .parameters = parameters };
    }

    fn getDecoratorsOfParameters(self: *LegacyDecoratorsTransformer, node: ast.NodeIndex) [][]const ast.NodeIndex {
        if (node == 0) return &[_][]const ast.NodeIndex{};
        
        const paramsNode = ast_utils.parameters(node);
        if (paramsNode == 0) return &[_][]const ast.NodeIndex{};
        const parameters = ast_utils.getNodes(paramsNode);
        
        const firstParameterIsThis = parameters.len > 0 and ast_utils.isThisParameter(undefined, parameters[0]);
        const firstParameterOffset: usize = if (firstParameterIsThis) 1 else 0;
        const numParameters = parameters.len - firstParameterOffset;
        
        var decorators: [][]const ast.NodeIndex = &[_][]const ast.NodeIndex{};
        var anyDecorators = false;
        var i: usize = 0;
        while (i < numParameters) : (i += 1) {
            const p = parameters[i + firstParameterOffset];
            if (anyDecorators or ast_utils.hasDecorators(undefined, p)) {
                if (!anyDecorators) {
                    decorators = self.allocator.alloc([]const ast.NodeIndex, numParameters) catch unreachable;
                    @memset(decorators, &[_]ast.NodeIndex{});
                    anyDecorators = true;
                }
                const decsNode = ast_utils.decorators(p);
                decorators[i] = if (decsNode != 0) ast_utils.getNodes(decsNode) else &[_]ast.NodeIndex{};
            }
        }
        return decorators;
    }

    const MembersAndDecorations = struct {
        members: ast.NodeIndex,
        decorationStatements: std.ArrayList(ast.NodeIndex),
    };

    fn transformDecoratorsOfClassElements(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex, membersList: ast.NodeIndex) MembersAndDecorations {
        var decorationStatements = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        
        decorationStatements.appendSlice(self.allocator, self.getClassElementDecorationStatements(tx, node, false)) catch unreachable;
        decorationStatements.appendSlice(self.allocator, self.getClassElementDecorationStatements(tx, node, true)) catch unreachable;
        
        var members = membersList;
        
        if (self.hasClassElementWithDecoratorContainingPrivateIdentifierInExpression(node)) {
            var memberNodes = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            if (members != 0 and ast_utils.nodesLen(members) > 0) {
                memberNodes.appendSlice(self.allocator, ast_utils.getNodes(members)) catch unreachable;
            }
            const block = tx.factory.newBlock(tx.factory.newNodeList(decorationStatements.items), true);
            const staticBlock = tx.factory.newClassStaticBlockDeclaration(0, block);
            memberNodes.append(self.allocator, staticBlock) catch unreachable;
            
            members = tx.factory.newNodeList(memberNodes.items);
            decorationStatements.clearRetainingCapacity();
        }
        
        return .{
            .members = members,
            .decorationStatements = decorationStatements,
        };
    }

    fn getClassElementDecorationStatements(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex, isStatic: bool) []const ast.NodeIndex {
        const exprs = self.generateClassElementDecorationExpressions(tx, node, isStatic);
        var statements = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        for (exprs) |e| {
            statements.append(self.allocator, tx.factory.newExpressionStatement(e)) catch unreachable;
        }
        return statements.items;
    }

    fn getDecoratedClassElements(self: *LegacyDecoratorsTransformer, node: ast.NodeIndex, isStatic: bool) []const ast.NodeIndex {
        const membersNode = ast_utils.members(node);
        if (membersNode == 0 or ast_utils.nodesLen(membersNode) == 0) {
            return &[_]ast.NodeIndex{};
        }
        var members = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        const membersNodes = ast_utils.getNodes(membersNode);
        for (membersNodes) |member| {
            if (isDecoratedClassElement(member, isStatic, node)) {
                members.append(self.allocator, member) catch unreachable;
            }
        }
        return members.items;
    }

    fn generateClassElementDecorationExpressions(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex, isStatic: bool) []const ast.NodeIndex {
        const members = self.getDecoratedClassElements(node, isStatic);
        var expressions = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        for (members) |member| {
            const expr = self.generateClassElementDecorationExpression(tx, node, member);
            if (expr != 0) {
                expressions.append(self.allocator, expr) catch unreachable;
            }
        }
        return expressions.items;
    }

    fn generateClassElementDecorationExpression(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex, member: ast.NodeIndex) ast.NodeIndex {
        const allDecorators = self.getAllDecoratorsOfClassElement(member, node, true);
        const decoratorExpressions = self.transformAllDecoratorsOfDeclaration(tx, allDecorators);
        if (decoratorExpressions.len == 0) {
            return 0;
        }

        const prefix = self.getClassMemberPrefix(tx, node, member);
        const memberName = self.getExpressionForPropertyName(tx, member, (ast_utils.getFlags(member) & ast.NodeFlagsAmbient) == 0);
        var descriptor: ast.NodeIndex = 0;
        if (ast_utils.isPropertyDeclaration(member) and !ast_utils.hasAccessorModifier(member)) {
            descriptor = tx.factory.newVoidZeroExpression();
        } else {
            descriptor = tx.factory.newKeywordExpression(.NullKeyword);
        }

        const helper = tx.factory.newDecorateHelper(
            decoratorExpressions,
            prefix,
            memberName,
            descriptor,
        );

        tx.emitContext.setEmitFlags(helper, 0) catch {};
        tx.emitContext.setSourceMapRange(helper, ast_utils.moveRangePastModifiers(member));
        return helper;
    }

    fn transformAllDecoratorsOfDeclaration(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, allDecorators: AllDecorators) []const ast.NodeIndex {
        if (allDecorators.decorators.len == 0 and allDecorators.parameters.len == 0) {
            return &[_]ast.NodeIndex{};
        }

        var metadata = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        var decorators = std.ArrayListUnmanaged(ast.NodeIndex).empty;

        for (allDecorators.decorators) |d| {
            if (tx.emitContext.isCallToHelper(ast_utils.expression(d), "__metadata")) {
                metadata.append(self.allocator, d) catch unreachable;
            } else {
                decorators.append(self.allocator, d) catch unreachable;
            }
        }

        var decoratorExpressions = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        decoratorExpressions.appendSlice(self.allocator, self.transformDecorators(tx, decorators.items)) catch unreachable;
        decoratorExpressions.appendSlice(self.allocator, self.transformDecoratorsOfParameters(tx, allDecorators.parameters)) catch unreachable;
        decoratorExpressions.appendSlice(self.allocator, self.transformDecorators(tx, metadata.items)) catch unreachable;
        return decoratorExpressions.items;
    }

    fn transformDecoratorsOfParameters(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, parameters: [][]const ast.NodeIndex) []const ast.NodeIndex {
        var results = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        for (parameters, 0..) |decorators, i| {
            if (decorators.len > 0) {
                for (decorators) |decorator| {
                    const expr = ast_utils.expression(decorator);
                    const helper = tx.factory.newParamHelper(
                        tx.visitor.visitNode(expr),
                        @as(u32, @intCast(i)),
                        ast_utils.loc(expr),
                    );
                    tx.emitContext.setEmitFlags(helper, 0) catch {};
                    results.append(self.allocator, helper) catch unreachable;
                }
            }
        }
        return results.items;
    }

    fn transformDecorators(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, decorators: []const ast.NodeIndex) []const ast.NodeIndex {
        var results = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        for (decorators) |d| {
            results.append(self.allocator, tx.visitor.visitNode(ast_utils.expression(d))) catch unreachable;
        }
        return results.items;
    }

    fn getClassMemberPrefix(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex, member: ast.NodeIndex) ast.NodeIndex {
        if (ast_utils.isStatic(member)) {
            return tx.factory.getDeclarationName(node);
        }
        return self.getClassPrototype(tx, node);
    }

    fn getClassPrototype(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        _ = self;
        return tx.factory.newPropertyAccessExpression(
            tx.factory.getDeclarationName(node),
            0,
            tx.factory.newIdentifier("prototype"),
            0,
        );
    }

    fn getExpressionForPropertyName(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, member: ast.NodeIndex, generateNameForComputedPropertyName: bool) ast.NodeIndex {
        _ = self;
        const name = ast_utils.name(member);
        if (ast_utils.isPrivateIdentifier(name)) {
            return tx.factory.newIdentifier("");
        } else if (ast_utils.isComputedPropertyName(name)) {
            if (generateNameForComputedPropertyName and !ast_utils.isSimpleInlineableExpression(ast_utils.expression(name))) {
                return tx.factory.newGeneratedNameForNode(name);
            }
            return ast_utils.expression(name);
        } else if (ast_utils.isIdentifier(tx.emitContext.tree, name)) {
            return tx.factory.newStringLiteral(ast_utils.getText(undefined, name), 0);
        } else {
            return tx.factory.deepCloneNode(name);
        }
    }

    fn hasClassElementWithDecoratorContainingPrivateIdentifierInExpression(self: *LegacyDecoratorsTransformer, node: ast.NodeIndex) bool {
        const membersNode = ast_utils.members(node);
        if (membersNode == 0 or ast_utils.nodesLen(membersNode) == 0) {
            return false;
        }
        const membersNodes = ast_utils.getNodes(membersNode);
        for (membersNodes) |member| {
            if (!ast_utils.canHaveDecorators(member)) {
                continue;
            }
            const allDec = self.getAllDecoratorsOfClassElement(member, node, true);
            if (allDec.decorators.len == 0 and allDec.parameters.len == 0) {
                continue;
            }
            if (ast_utils.some(allDec.decorators, decoratorContainsPrivateIdentifierInExpression)) {
                return true;
            }
            for (allDec.parameters) |params| {
                if (parameterDecoratorsContainPrivateIdentifierInExpression(params)) {
                    return true;
                }
            }
        }
        return false;
    }
};

fn elideNodes(f: *factory.NodeFactory, nodes: ast.NodeIndex) ast.NodeIndex {
    if (nodes == 0) return 0;
    if (ast_utils.nodesLen(nodes) == 0) return nodes;
    const replacement = f.newNodeList(&[_]ast.NodeIndex{});
    ast_utils.setLoc(undefined, replacement, ast_utils.loc(nodes));
    return replacement;
}

fn elideModifiers(f: *factory.NodeFactory, nodes: ast.NodeIndex) ast.NodeIndex {
    if (nodes == 0) return 0;
    if (ast_utils.nodesLen(nodes) == 0) return nodes;
    const replacement = f.newModifierList(&[_]ast.NodeIndex{});
    ast_utils.setLoc(undefined, replacement, ast_utils.loc(nodes));
    return replacement;
}

fn isClassStaticBlockDeclarationOrStaticProperty(node: ast.NodeIndex) bool {
    return ast_utils.isClassStaticBlockDeclaration(node) or (ast_utils.isPropertyDeclaration(node) and ast_utils.hasStaticModifier(node));
}

fn isNotExportOrDefaultOrDecorator(node: ast.NodeIndex) bool {
    
    return !(ast_utils.isDecorator(undefined, node) or ast_utils.getKind(node) == .ExportKeyword or ast_utils.getKind(node) == .DefaultKeyword);
}

fn decoratorContainsPrivateIdentifierInExpression(decorator: ast.NodeIndex) bool {
    return (ast_utils.subtreeFacts(decorator) & ast.SubtreeContainsPrivateIdentifierInExpression) != 0;
}

fn parameterDecoratorsContainPrivateIdentifierInExpression(parameterDecorators: []const ast.NodeIndex) bool {
    return ast_utils.some(parameterDecorators, decoratorContainsPrivateIdentifierInExpression);
}

fn isDecoratedClassElement(member: ast.NodeIndex, isStaticElement: bool, parent: ast.NodeIndex) bool {
    return isStaticElement == ast_utils.isStatic(member) and ast_utils.nodeOrChildIsDecorated(true, member, parent, 0);
}
