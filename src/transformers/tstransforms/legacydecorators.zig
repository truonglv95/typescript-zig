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

    pub fn new(allocator: std.mem.Allocator, opt: *transformers.TransformOptions) !*transformers.Transformer {
        var tx = try allocator.create(LegacyDecoratorsTransformer);
        tx.* = .{
            .base = undefined,
            .languageVersion = opt.compilerOptions.target orelse .Latest,
            .referenceResolver = opt.resolver.?,
            .classAliases = std.AutoHashMap(ast.NodeIndex, ast.NodeIndex).init(allocator),
            .enclosingClasses = std.ArrayListUnmanaged(ast.NodeIndex).empty,
            .allocator = allocator,
        };
        tx.base = (transformers.Transformer.init(allocator, visit, tx, opt.context) catch @panic("OOM")).*;
        return &tx.base;
    }

    fn visit(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        const self: *LegacyDecoratorsTransformer = @ptrCast(@alignCast(ctx.?));
        const tx = &self.base;
        _ = v;

        const k = ast_utils.getKind(tx.emitContext.tree, node);

        switch (k) {
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
                var result = tx.visitor.visitEachChild(node);
                if (self.classAliases.count() > 0) {
                    const source = tx.emitContext.tree.getNode(result).SourceFile;
                    var declarations = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                    var aliases = self.classAliases.valueIterator();
                    while (aliases.next()) |alias| {
                        declarations.append(self.allocator, tx.factory.newVariableDeclaration(alias.*, 0, 0, 0)) catch unreachable;
                    }
                    const declaration_list = tx.factory.newVariableDeclarationList(tx.factory.newNodeList(declarations.items), 0);
                    const statement = tx.factory.newVariableStatement(0, declaration_list);
                    var statements = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                    statements.append(self.allocator, statement) catch unreachable;
                    statements.appendSlice(self.allocator, tx.emitContext.tree.getNodeList(source.Statements)) catch unreachable;
                    result = tx.factory.updateSourceFile(result, source, tx.factory.newNodeList(statements.items), source.EndOfFileToken);
                }
                self.classAliases.clearRetainingCapacity();
                self.enclosingClasses.clearRetainingCapacity();
                return result;
            },
            else => return tx.visitor.visitEachChild(node),
        }
    }

    fn visitIdentifier(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        const name = ast_utils.getTextOfNode(tx.emitContext.tree, node);
        for (self.enclosingClasses.items) |d| {
            if (self.classAliases.get(d)) |alias| {
                const ref = self.referenceResolver.getReferencedValueDeclaration(tx.emitContext.mostOriginal(node));
                const orig_d = tx.emitContext.mostOriginal(d);
                if (ref) |r| {
                    if (r == orig_d) {
                        return alias;
                    }
                } else {
                    const class_name = ast_utils.name(tx.emitContext.tree, d);
                    const parent = tx.emitContext.tree.getNodeParent(node);
                    if (class_name != 0 and std.mem.eql(u8, name, ast_utils.getText(tx.emitContext.tree, class_name)) and ast_utils.isIdentifierReference(tx.emitContext.tree, node, parent)) return alias;
                }
            }
        }
        return node;
    }

    fn visitPropertyAccessExpression(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        _ = self;
        const expression = tx.visitor.visitNode(ast_utils.expression(tx.emitContext.tree, node));
        if (expression != ast_utils.expression(tx.emitContext.tree, node)) {
            return tx.factory.updatePropertyAccessExpression(node, expression, ast_utils.questionDotToken(node), ast_utils.name(tx.emitContext.tree, node), ast_utils.getFlags(tx.visitor.tree, node));
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
            node,
            tx.visitor.tree.getNode(node).Parameter,
            elideModifiers(tx.factory, (ast_utils.getModifiers(tx.visitor.tree, node) orelse 0)),
            ast_utils.dotDotDotToken(node),
            tx.visitor.visitNode(ast_utils.name(tx.emitContext.tree, node)),
            0,
            0,
            tx.visitor.visitNode(ast_utils.getInitializerOfNode(tx.visitor.tree, node)),
        );
        if (updated != node) {
            tx.emitContext.setCommentRange(updated, ast_utils.loc(node));
            const newLoc = ast_utils.moveRangePastModifiers(node);
            ast_utils.setLoc(tx.emitContext.tree, updated, newLoc);
            tx.emitContext.setSourceMapRange(updated, newLoc);
            _ = tx.emitContext.setEmitFlags(ast_utils.name(tx.emitContext.tree, updated), 0) catch {};
        }
        return updated;
    }

    fn visitPropertyNameOfClassElement(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, member: ast.NodeIndex) ast.NodeIndex {
        _ = self;
        const name = ast_utils.name(tx.emitContext.tree, member);
        if (ast_utils.isComputedPropertyName(name) and ast_utils.hasDecorators(tx.visitor.tree, member)) {
            const expression = tx.visitor.visitNode(ast_utils.expression(tx.emitContext.tree, name));
            const innerExpression = ast_utils.skipPartiallyEmittedExpressions(tx.visitor.tree, expression);
            if (!ast_utils.isSimpleInlineableExpression(innerExpression)) {
                const generatedName = tx.factory.newGeneratedNameForNode(name);
                tx.emitContext.addVariableDeclaration(generatedName);
                return tx.factory.updateComputedPropertyName(name, tx.factory.newAssignmentExpression(generatedName, expression));
            }
        }
        return tx.visitor.visitNode(name);
    }

    fn visitPropertyDeclaration(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        if ((ast_utils.getFlags(tx.visitor.tree, node) & ast.NodeFlagsAmbient) != 0) {
            return 0;
        }
        if (ast_utils.hasSyntacticModifier(tx.visitor.tree, node, ast.ModifierFlagsAmbient | ast.ModifierFlagsAbstract)) {
            return 0;
        }

        return self.finishClassElement(
            tx,
            tx.factory.updatePropertyDeclaration(
                node,
                tx.visitor.tree.getNode(node).PropertyDeclaration,
                tx.visitor.visitModifiers((ast_utils.getModifiers(tx.visitor.tree, node) orelse 0)),
                self.visitPropertyNameOfClassElement(tx, node),
                0,
                0,
                tx.visitor.visitNode(ast_utils.getInitializerOfNode(tx.visitor.tree, node)),
            ),
            node,
        );
    }

    fn visitGetAccessorDeclaration(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        return self.finishClassElement(
            tx,
            tx.factory.updateGetAccessorDeclaration(
                node,
                tx.visitor.tree.getNode(node).GetAccessor,
                tx.visitor.visitModifiers((ast_utils.getModifiers(tx.visitor.tree, node) orelse 0)),
                self.visitPropertyNameOfClassElement(tx, node),
                0,
                tx.visitor.visitNodes(ast_utils.parameters(tx.visitor.tree, node)),
                0,
                tx.visitor.visitNode(ast_utils.getBody(tx.visitor.tree, node)),
            ),
            node,
        );
    }

    fn visitSetAccessorDeclaration(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        return self.finishClassElement(
            tx,
            tx.factory.updateSetAccessorDeclaration(
                node,
                tx.visitor.tree.getNode(node).SetAccessor,
                tx.visitor.visitModifiers((ast_utils.getModifiers(tx.visitor.tree, node) orelse 0)),
                self.visitPropertyNameOfClassElement(tx, node),
                0,
                tx.visitor.visitNodes(ast_utils.parameters(tx.visitor.tree, node)),
                0,
                tx.visitor.visitNode(ast_utils.getBody(tx.visitor.tree, node)),
            ),
            node,
        );
    }

    fn visitMethodDeclaration(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        return self.finishClassElement(
            tx,
            tx.factory.updateMethodDeclaration(
                node,
                tx.visitor.tree.getNode(node).MethodDeclaration,
                tx.visitor.visitModifiers((ast_utils.getModifiers(tx.visitor.tree, node) orelse 0)),
                ast_utils.asteriskToken(node),
                self.visitPropertyNameOfClassElement(tx, node),
                0,
                0,
                tx.visitor.visitNodes(ast_utils.parameters(tx.visitor.tree, node)),
                0,
                tx.visitor.visitNode(ast_utils.getBody(tx.visitor.tree, node)),
            ),
            node,
        );
    }

    fn visitConstructorDeclaration(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        _ = self;
        return tx.factory.updateConstructorDeclaration(
            node,
            tx.visitor.tree.getNode(node).Constructor,
            tx.visitor.visitModifiers((ast_utils.getModifiers(tx.visitor.tree, node) orelse 0)),
            0,
            tx.visitor.visitNodes(ast_utils.parameters(tx.visitor.tree, node)),
            0,
            tx.visitor.visitNode(ast_utils.getBody(tx.visitor.tree, node)),
        );
    }

    fn visitClassExpression(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        _ = self;
        return tx.factory.updateClassExpression(
            node,
            tx.visitor.tree.getNode(node).ClassExpression,
            tx.visitor.visitModifiers((ast_utils.getModifiers(tx.visitor.tree, node) orelse 0)),
            ast_utils.name(tx.visitor.tree, node),
            0,
            tx.visitor.visitNodes(ast_utils.heritageClauses(node)),
            tx.visitor.visitNodes(ast_utils.members(tx.visitor.tree, node)),
        );
    }

    fn visitClassDeclaration(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        const decorated = ast_utils.classOrConstructorParameterIsDecorated(tx.emitContext.tree, true, node);
        const child_decorated = ast_utils.childIsDecorated(tx.emitContext.tree, true, node, 0);
        if (!(decorated or child_decorated)) {
            return tx.visitor.visitEachChild(node);
        }

        if (decorated) {
            return self.transformClassDeclarationWithClassDecorators(tx, node, ast_utils.name(tx.emitContext.tree, node));
        }
        return self.transformClassDeclarationWithoutClassDecorators(tx, node, ast_utils.name(tx.emitContext.tree, node));
    }

    fn transformClassDeclarationWithoutClassDecorators(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex, nodeName: ast.NodeIndex) ast.NodeIndex {
        const modifiers = tx.visitor.visitModifiers((ast_utils.getModifiers(tx.visitor.tree, node) orelse 0));
        const heritageClauses = tx.visitor.visitNodes(ast_utils.heritageClauses(node));
        const initialMembers = tx.visitor.visitNodes(ast_utils.members(tx.visitor.tree, node));

        const membersAndDecorations = self.transformDecoratorsOfClassElements(tx, node, initialMembers);
        const members = membersAndDecorations.members;
        const decorationStatements = membersAndDecorations.decorationStatements;

        var name = nodeName;
        if (name == 0 and decorationStatements.items.len > 0) {
            name = tx.factory.newGeneratedNameForNode(node);
        }

        const updated = tx.factory.updateClassDeclaration(
            node,
            tx.visitor.tree.getNode(node).ClassDeclaration,
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
        var isExport = false;
        var isDefault = false;
        const source_modifiers = ast_utils.getModifiers(tx.visitor.tree, node) orelse 0;
        if (source_modifiers != 0) {
            for (ast_utils.getNodes(tx.visitor.tree, source_modifiers)) |modifier| {
                if (ast_utils.getKind(tx.visitor.tree, modifier) == .ExportKeyword) isExport = true;
                if (ast_utils.getKind(tx.visitor.tree, modifier) == .DefaultKeyword) isDefault = true;
            }
        }

        var modifiers: ast.NodeIndex = 0;
        const nodeModifiers = (ast_utils.getModifiers(tx.visitor.tree, node) orelse 0);
        if (nodeModifiers != 0 and ast_utils.nodesLen(tx.visitor.tree, nodeModifiers) > 0) {
            var modifierNodes = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            const nodes = ast_utils.getNodes(tx.visitor.tree, nodeModifiers);
            for (nodes) |m| {
                if (isNotExportOrDefaultOrDecorator(tx.visitor.tree, m)) {
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
        var members = tx.visitor.visitNodes(ast_utils.members(tx.visitor.tree, node));

        const membersAndDecorations = self.transformDecoratorsOfClassElements(tx, node, members);
        members = membersAndDecorations.members;
        const decorationStatements = membersAndDecorations.decorationStatements;

        var assignClassAliasInStaticBlock = false;
        if (@intFromEnum(self.languageVersion) >= @intFromEnum(core.ScriptTarget.ES2022) and classAlias != 0 and members != 0 and ast_utils.nodesLen(tx.visitor.tree, members) > 0) {
            for (ast_utils.getNodes(tx.visitor.tree, members)) |member| {
                const kind_val = ast_utils.getKind(tx.visitor.tree, member);
                if (kind_val == .ClassStaticBlockDeclaration or (kind_val == .PropertyDeclaration and ast_utils.hasStaticModifier(tx.visitor.tree, member))) {
                    assignClassAliasInStaticBlock = true;
                    break;
                }
            }
        }

        if (assignClassAliasInStaticBlock) {
            var memberList = std.ArrayListUnmanaged(ast.NodeIndex).empty;

            const assignment = tx.factory.newAssignmentExpression(classAlias, tx.factory.newKeywordExpression(.ThisKeyword));
            const stmt = tx.factory.newExpressionStatement(assignment);
            const stmtList = tx.factory.newNodeList(&[_]ast.NodeIndex{stmt});
            const block = tx.factory.newBlock(stmtList, false);
            memberList.append(self.allocator, tx.factory.newClassStaticBlockDeclaration(0, block)) catch unreachable;

            memberList.appendSlice(self.allocator, ast_utils.getNodes(tx.visitor.tree, members)) catch unreachable;

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
                const tree = ctx.tx.emitContext.tree;
                if (ast_utils.isIdentifier(tree, n)) {
                    const name = ast_utils.getTextOfNode(tree, n);
                    const class_name = ast_utils.name(tree, ctx.classNode);
                    const parent = tree.getNodeParent(n);
                    const is_property_name = parent != 0 and tree.getNode(parent) == .PropertyAccessExpression and
                        tree.getNode(parent).PropertyAccessExpression.name == n;
                    if (!is_property_name and class_name != 0 and std.mem.eql(u8, name, ast_utils.getText(tree, class_name))) return true;
                }
                if (ast_utils.isPropertyAccessExpression(tree, n)) {
                    return check(ctx, ast_utils.expression(tree, n));
                }
                return ast_utils.forEachChildBool(tree, n, ctx, check);
            }
        };
        var ctx = Context{
            .tx = tx,
            .self_tx = self,
            .classNode = classNode,
        };

        const membersNode = ast_utils.members(tx.emitContext.tree, node);
        if (membersNode != 0) {
            for (ast_utils.getNodes(tx.emitContext.tree, membersNode)) |member| {
                if (!ast_utils.hasStaticModifier(tx.emitContext.tree, member) and ast_utils.getKind(tx.emitContext.tree, member) != .ClassStaticBlockDeclaration) continue;
                if (ast_utils.forEachChildBool(tx.emitContext.tree, member, &ctx, Context.check)) {
                    return true;
                }
            }
        }
        return false;
    }

    fn getClassAliasIfNeeded(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex) ast.NodeIndex {
        const has_ref = self.hasInternalStaticReference(tx, node);
        if (!has_ref) {
            return 0;
        }
        var nameText: []const u8 = "default";
        const nodeName = ast_utils.name(tx.emitContext.tree, node);
        if (nodeName != 0 and !transformers.isGeneratedIdentifier(tx.emitContext, nodeName)) {
            nameText = ast_utils.getText(tx.emitContext.tree, nodeName);
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
        tx.emitContext.requestEmitHelper(&@import("../../printer/helpers.zig").decorateHelper);
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
        const tree = self.base.emitContext.tree;
        const decoratorsNode = ast_utils.decorators(tree, node);
        var parameters: [][]const ast.NodeIndex = &[_][]const ast.NodeIndex{};
        if (useLegacyDecorators) {
            parameters = self.getDecoratorsOfParameters(ast_utils.getFirstConstructorWithBody(tree, node));
        }
        return .{
            .decorators = if (decoratorsNode != 0) ast_utils.getNodes(tree, decoratorsNode) else &[_]ast.NodeIndex{},
            .parameters = parameters,
        };
    }

    fn getAllDecoratorsOfClassElement(self: *LegacyDecoratorsTransformer, member: ast.NodeIndex, parent: ast.NodeIndex, useLegacyDecorators: bool) AllDecorators {
        switch (ast_utils.getKind(self.base.emitContext.tree, member)) {
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
        if (ast_utils.getBody(self.base.emitContext.tree, accessor) == 0) {
            return .{ .decorators = &[_]ast.NodeIndex{}, .parameters = &[_][]const ast.NodeIndex{} };
        }
        const tree = self.base.emitContext.tree;
        const decls = ast_utils.getAllAccessorDeclarations(tree, ast_utils.getNodes(tree, ast_utils.members(tree, parent)), accessor);
        var firstAccessorWithDecorators: ast.NodeIndex = 0;
        if (ast_utils.hasDecorators(tree, decls.firstAccessor)) {
            firstAccessorWithDecorators = decls.firstAccessor;
        } else if (decls.secondAccessor != 0 and ast_utils.hasDecorators(tree, decls.secondAccessor)) {
            firstAccessorWithDecorators = decls.secondAccessor;
        }

        if (firstAccessorWithDecorators == 0 or accessor != firstAccessorWithDecorators) {
            return .{ .decorators = &[_]ast.NodeIndex{}, .parameters = &[_][]const ast.NodeIndex{} };
        }

        const decoratorsNode = ast_utils.decorators(tree, firstAccessorWithDecorators);
        const decorators = if (decoratorsNode != 0) ast_utils.getNodes(tree, decoratorsNode) else &[_]ast.NodeIndex{};
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
        const tree = self.base.emitContext.tree;
        const decoratorsNode = ast_utils.decorators(tree, property);
        const decorators = if (decoratorsNode != 0) ast_utils.getNodes(tree, decoratorsNode) else &[_]ast.NodeIndex{};
        return .{ .decorators = decorators, .parameters = &[_][]const ast.NodeIndex{} };
    }

    fn getAllDecoratorsOfMethod(self: *LegacyDecoratorsTransformer, method: ast.NodeIndex, useLegacyDecorators: bool) AllDecorators {
        const tree = self.base.emitContext.tree;
        if (ast_utils.getBody(tree, method) == 0) {
            return .{ .decorators = &[_]ast.NodeIndex{}, .parameters = &[_][]const ast.NodeIndex{} };
        }
        const decoratorsNode = ast_utils.decorators(tree, method);
        const decorators = if (decoratorsNode != 0) ast_utils.getNodes(tree, decoratorsNode) else &[_]ast.NodeIndex{};
        var parameters: [][]const ast.NodeIndex = &[_][]const ast.NodeIndex{};
        if (useLegacyDecorators) {
            parameters = self.getDecoratorsOfParameters(method);
        }
        return .{ .decorators = decorators, .parameters = parameters };
    }

    fn getDecoratorsOfParameters(self: *LegacyDecoratorsTransformer, node: ast.NodeIndex) [][]const ast.NodeIndex {
        if (node == 0) return &[_][]const ast.NodeIndex{};

        const tree = self.base.emitContext.tree;
        const paramsNode = ast_utils.parameters(tree, node);
        if (paramsNode == 0) return &[_][]const ast.NodeIndex{};
        const parameters = ast_utils.getNodes(tree, paramsNode);

        const firstParameterIsThis = parameters.len > 0 and ast_utils.isThisParameter(tree, parameters[0]);
        const firstParameterOffset: usize = if (firstParameterIsThis) 1 else 0;
        const numParameters = parameters.len - firstParameterOffset;

        var decorators: [][]const ast.NodeIndex = &[_][]const ast.NodeIndex{};
        var anyDecorators = false;
        var i: usize = 0;
        while (i < numParameters) : (i += 1) {
            const p = parameters[i + firstParameterOffset];
            if (anyDecorators or ast_utils.hasDecorators(tree, p)) {
                if (!anyDecorators) {
                    decorators = self.allocator.alloc([]const ast.NodeIndex, numParameters) catch unreachable;
                    @memset(decorators, &[_]ast.NodeIndex{});
                    anyDecorators = true;
                }
                const decsNode = ast_utils.decorators(tree, p);
                decorators[i] = if (decsNode != 0) ast_utils.getNodes(tree, decsNode) else &[_]ast.NodeIndex{};
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
            if (members != 0 and ast_utils.nodesLen(tx.emitContext.tree, members) > 0) {
                memberNodes.appendSlice(self.allocator, ast_utils.getNodes(tx.emitContext.tree, members)) catch unreachable;
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
        const membersNode = ast_utils.members(self.base.emitContext.tree, node);
        const tree = self.base.emitContext.tree;
        if (membersNode == 0 or ast_utils.nodesLen(tree, membersNode) == 0) {
            return &[_]ast.NodeIndex{};
        }
        var members = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        const membersNodes = ast_utils.getNodes(tree, membersNode);
        for (membersNodes) |member| {
            if (isDecoratedClassElement(tree, member, isStatic, node)) {
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
        const memberName = self.getExpressionForPropertyName(tx, member, (ast_utils.getFlags(tx.visitor.tree, member) & ast.NodeFlagsAmbient) == 0);
        var descriptor: ast.NodeIndex = 0;
        if (tx.visitor.tree.getNode(member) == .PropertyDeclaration) {
            descriptor = tx.factory.newVoidZeroExpression();
        } else {
            descriptor = tx.factory.newKeywordExpression(.NullKeyword);
        }

        tx.emitContext.requestEmitHelper(&@import("../../printer/helpers.zig").decorateHelper);
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
            const decorator_expression = ast_utils.expression(tx.emitContext.tree, d);
            const is_metadata_call = tx.emitContext.isCallToHelper(decorator_expression, "__metadata") or blk: {
                const expression_node = tx.emitContext.tree.getNode(decorator_expression);
                if (expression_node != .CallExpression) break :blk false;
                const callee = expression_node.CallExpression.Expression;
                break :blk ast_utils.isIdentifier(tx.emitContext.tree, callee) and
                    std.mem.eql(u8, ast_utils.getText(tx.emitContext.tree, callee), "__metadata");
            };
            if (is_metadata_call) {
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
                    const expr = ast_utils.expression(tx.emitContext.tree, decorator);
                    tx.emitContext.requestEmitHelper(&@import("../../printer/helpers.zig").paramHelper);
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
            const expr = ast_utils.expression(tx.emitContext.tree, d);
            const visited = tx.visitor.visitNode(expr);
            results.append(self.allocator, visited) catch unreachable;
        }
        return results.items;
    }

    fn getClassMemberPrefix(self: *LegacyDecoratorsTransformer, tx: *transformers.Transformer, node: ast.NodeIndex, member: ast.NodeIndex) ast.NodeIndex {
        if (ast_utils.isStatic(tx.visitor.tree, member)) {
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
        const name = ast_utils.name(tx.emitContext.tree, member);
        if (ast_utils.isPrivateIdentifier(name)) {
            return tx.factory.newIdentifier("");
        } else if (ast_utils.isComputedPropertyName(name)) {
            if (generateNameForComputedPropertyName and !ast_utils.isSimpleInlineableExpression(ast_utils.expression(tx.emitContext.tree, name))) {
                return tx.factory.newGeneratedNameForNode(name);
            }
            return ast_utils.expression(tx.emitContext.tree, name);
        } else if (ast_utils.isIdentifier(tx.emitContext.tree, name)) {
            return tx.factory.newStringLiteral(ast_utils.getText(tx.emitContext.tree, name), 0);
        } else {
            return tx.factory.deepCloneNode(name);
        }
    }

    fn hasClassElementWithDecoratorContainingPrivateIdentifierInExpression(self: *LegacyDecoratorsTransformer, node: ast.NodeIndex) bool {
        const membersNode = ast_utils.members(self.base.emitContext.tree, node);
        const tree = self.base.emitContext.tree;
        if (membersNode == 0 or ast_utils.nodesLen(tree, membersNode) == 0) {
            return false;
        }
        const membersNodes = ast_utils.getNodes(tree, membersNode);
        for (membersNodes) |member| {
            if (!ast_utils.canHaveDecorators(tree, member)) {
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
    if (ast_utils.nodesLen(f.tree, nodes) == 0) return nodes;
    const replacement = f.newNodeList(&[_]ast.NodeIndex{});
    ast_utils.setLoc(f.tree, replacement, ast_utils.loc(nodes));
    return replacement;
}

fn elideModifiers(f: *factory.NodeFactory, nodes: ast.NodeIndex) ast.NodeIndex {
    if (nodes == 0) return 0;
    if (ast_utils.nodesLen(f.tree, nodes) == 0) return nodes;
    const replacement = f.newModifierList(&[_]ast.NodeIndex{});
    ast_utils.setLoc(f.tree, replacement, ast_utils.loc(nodes));
    return replacement;
}

fn isNotExportOrDefaultOrDecorator(tree: *ast.Ast, node: ast.NodeIndex) bool {
    return !(ast_utils.isDecorator(tree, node) or ast_utils.getKind(tree, node) == .ExportKeyword or ast_utils.getKind(tree, node) == .DefaultKeyword);
}

fn decoratorContainsPrivateIdentifierInExpression(decorator: ast.NodeIndex) bool {
    return (ast_utils.subtreeFacts(decorator) & ast.SubtreeContainsPrivateIdentifierInExpression) != 0;
}

fn parameterDecoratorsContainPrivateIdentifierInExpression(parameterDecorators: []const ast.NodeIndex) bool {
    return ast_utils.some(parameterDecorators, decoratorContainsPrivateIdentifierInExpression);
}

fn isDecoratedClassElement(tree: *ast.Ast, member: ast.NodeIndex, isStaticElement: bool, parent: ast.NodeIndex) bool {
    return isStaticElement == ast_utils.isStatic(tree, member) and ast_utils.nodeOrChildIsDecorated(tree, true, member, parent);
}
