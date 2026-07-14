const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const visitor = @import("../../ast/visitor.zig");
const transformers = @import("../transformer.zig");
const kind = @import("../../ast/kind.zig");
const core = @import("../../core/core.zig");
const ast_utils = @import("../../ast/ast_utils.zig");
const helpers = @import("../../printer/helpers.zig");
const emitcontext = @import("../../printer/emitcontext.zig");

pub const LexicalEntryKind = enum {
    Class,
    ClassElement,
    Name,
    Other,
};

pub const LexicalEntry = struct {
    kind: LexicalEntryKind,
    next: ?*LexicalEntry = null,
    classInfoData: ?*ClassInfo = null,
    savedPendingExpressions: ?std.ArrayList(ast_gen.NodeIndex) = null,
    classThisData: ast_gen.NodeIndex = 0,
    classSuperData: ast_gen.NodeIndex = 0,
    depth: usize = 0,
};

pub const MemberInfo = struct {
    memberDecoratorsName: ast_gen.NodeIndex = 0, // used in class definition step 4.a
    memberInitializersName: ast_gen.NodeIndex = 0, // used in class definition step 12 and constructor evaluation step 2.a
    memberExtraInitializersName: ast_gen.NodeIndex = 0, // used in class definition step 12 and constructor evaluation step 2.b
    memberDescriptorName: ast_gen.NodeIndex = 0,
};

pub const ClassInfo = struct {
    classNode: ast_gen.NodeIndex,
    classDecoratorsName: ast_gen.NodeIndex = 0, // used in class definition step 2
    classDescriptorName: ast_gen.NodeIndex = 0, // used in class definition step 10
    classExtraInitializersName: ast_gen.NodeIndex = 0, // used in class definition step 13
    classThis: ast_gen.NodeIndex = 0, // `_classThis`, if needed
    classSuper: ast_gen.NodeIndex = 0, // `_classSuper`, if needed
    metadataReference: ast_gen.NodeIndex = 0,
    memberInfos: std.AutoArrayHashMapUnmanaged(ast_gen.NodeIndex, MemberInfo) = .empty, // key: member node
    instanceMethodExtraInitializersName: ast_gen.NodeIndex = 0, // used in constructor evaluation step 1
    staticMethodExtraInitializersName: ast_gen.NodeIndex = 0, // used in class definition step 11
    staticNonFieldDecorationStatements: std.ArrayList(ast_gen.NodeIndex) = .empty,
    nonStaticNonFieldDecorationStatements: std.ArrayList(ast_gen.NodeIndex) = .empty,
    staticFieldDecorationStatements: std.ArrayList(ast_gen.NodeIndex) = .empty,
    nonStaticFieldDecorationStatements: std.ArrayList(ast_gen.NodeIndex) = .empty,
    hasStaticInitializers: bool = false,
    hasNonAmbientInstanceFields: bool = false,
    hasStaticPrivateClassElements: bool = false,
    pendingStaticInitializers: std.ArrayList(ast_gen.NodeIndex) = .empty,
    pendingInstanceInitializers: std.ArrayList(ast_gen.NodeIndex) = .empty,

    pub fn deinit(self: *ClassInfo, allocator: std.mem.Allocator) void {
        self.memberInfos.deinit(allocator);
        self.staticNonFieldDecorationStatements.deinit(allocator);
        self.nonStaticNonFieldDecorationStatements.deinit(allocator);
        self.staticFieldDecorationStatements.deinit(allocator);
        self.nonStaticFieldDecorationStatements.deinit(allocator);
        self.pendingStaticInitializers.deinit(allocator);
        self.pendingInstanceInitializers.deinit(allocator);
    }
};

pub const ESDecoratorTransformer = struct {
    base: transformers.Transformer,
    allocator: std.mem.Allocator,
    transformer: *transformers.Transformer,
    compiler_options: *core.CompilerOptions,
    top: ?*LexicalEntry = null,
    class_info_stack: ?*ClassInfo = null,
    class_this: ast_gen.NodeIndex = 0,
    class_super: ast_gen.NodeIndex = 0,
    pending_expressions: std.ArrayList(ast_gen.NodeIndex) = .empty,
    outer_this: ast_gen.NodeIndex = 0,
    should_transform_private_static_elements_in_file: bool = false,

    pub fn new(allocator: std.mem.Allocator, opt: *transformers.TransformOptions) !*transformers.Transformer {
        const tx = try allocator.create(ESDecoratorTransformer);
        tx.allocator = allocator;
        tx.compiler_options = opt.compilerOptions;
        tx.top = null;
        tx.class_info_stack = null;
        tx.class_this = 0;
        tx.class_super = 0;
        tx.pending_expressions = .empty;
        tx.outer_this = 0;
        tx.should_transform_private_static_elements_in_file = false;

        tx.transformer = try transformers.Transformer.init(allocator, visit, tx, opt.context);
        tx.base = tx.transformer.*;
        return tx.transformer;
    }

    fn visit(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const self = @as(*ESDecoratorTransformer, @ptrCast(@alignCast(ctx.?)));
        if (node == 0) return 0;

        const tree = v.tree;
        const nodeKind = tree.getNodeKind(node);

        if (nodeKind == .SourceFile) {
            return self.visitSourceFile(v, node);
        }

        switch (nodeKind) {
            .Decorator => return 0,
            .ClassDeclaration => return self.visitClassDeclaration(v, node),
            .ClassExpression => return self.visitClassExpression(v, node),
            .Constructor, .PropertyDeclaration, .ClassStaticBlockDeclaration => {
                std.debug.panic("Not supported outside of a class. Use classElementVisitor instead.", .{});
            },
            .Parameter => return self.visitParameterDeclaration(v, node),
            .BinaryExpression => return self.visitBinaryExpression(v, node, false),
            .PropertyAssignment => {
                const data = tree.getNode(node).PropertyAssignment;
                return self.visitNamedEvaluationSite(v, node, data.Initializer);
            },
            .VariableDeclaration => {
                const data = tree.getNode(node).VariableDeclaration;
                return self.visitNamedEvaluationSite(v, node, data.Initializer orelse 0);
            },
            .BindingElement => {
                const data = tree.getNode(node).BindingElement;
                return self.visitNamedEvaluationSite(v, node, data.Initializer orelse 0);
            },
            .ExportAssignment => {
                const expr = tree.getNode(node).ExportAssignment.Expression;
                return self.visitNamedEvaluationSite(v, node, expr);
            },
            .ThisKeyword => return self.visitThisExpression(v, node),
            .ForStatement => return self.visitForStatement(v, node),
            .ExpressionStatement => return self.visitExpressionStatement(v, node),
            .ParenthesizedExpression => return self.visitParenthesizedExpression(v, node, false),
            .PartiallyEmittedExpression => return self.visitPartiallyEmittedExpression(v, node, false),
            .CallExpression => return self.visitCallExpression(v, node),
            .TaggedTemplateExpression => return self.visitTaggedTemplateExpression(v, node),
            .PrefixUnaryExpression, .PostfixUnaryExpression => return self.visitPreOrPostfixUnaryExpression(v, node, false),
            .PropertyAccessExpression => return self.visitPropertyAccessExpression(v, node),
            .ElementAccessExpression => return self.visitElementAccessExpression(v, node),
            .ComputedPropertyName => return self.visitComputedPropertyName(v, node),
            .MethodDeclaration, .SetAccessor, .GetAccessor, .FunctionExpression, .FunctionDeclaration => {
                self.enterOther();
                const result = v.visitEachChild(node);
                self.exitOther();
                return result;
            },
            else => return v.visitEachChild(node),
        }
    }

    fn visitSourceFile(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        self.top = null;
        self.should_transform_private_static_elements_in_file = false;
        const visited = v.visitEachChild(node);
        if (self.should_transform_private_static_elements_in_file) {
            self.should_transform_private_static_elements_in_file = false;
        }
        return visited;
    }

    fn visitClassDeclaration(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        const data = tree.getNode(node).ClassDeclaration;

        if (isDecoratedClassLike(tree, node)) {
            var statements = std.ArrayList(ast_gen.NodeIndex).empty;
            defer statements.deinit(self.allocator);

            const isExport = ast_utils.hasSyntacticModifier(tree, node, ast_utils.ModifierFlags.Export);
            const isDefault = ast_utils.hasSyntacticModifier(tree, node, ast_utils.ModifierFlags.Default);

            const classNode = node;
            var className: ast_gen.NodeIndex = 0;
            if (data.name == null or data.name.? == 0) {
                className = f.newStringLiteral("default", 0);
            } else {
                className = f.newStringLiteralFromNode(data.name.?) catch unreachable;
            }

            if (isExport and isDefault) {
                const iife = self.transformClassLike(v, classNode);
                const classData = tree.getNode(classNode).ClassDeclaration;
                if (classData.name != null and classData.name.? != 0) {
                    const localName = f.getLocalName(classNode);
                    const varDecl = f.newVariableDeclaration(localName, 0, 0, iife);
                    const varDecls = f.newVariableDeclarationList(f.newNodeList(&[_]ast_gen.NodeIndex{varDecl}), ast_utils.NodeFlags.Let);
                    const varStatement = f.newVariableStatement(0, varDecls);
                    statements.append(self.allocator, varStatement) catch unreachable;

                    const exportDefault = f.newExportAssignment(null, false, f.getDeclarationName(classNode));
                    statements.append(self.allocator, exportDefault) catch unreachable;
                } else {
                    const exportDefault = f.newExportAssignment(null, false, iife);
                    statements.append(self.allocator, exportDefault) catch unreachable;
                }
            } else {
                const iife = self.transformClassLike(v, classNode);
                var modifier_visitor = visitor.NodeVisitor.init(self.allocator, tree, self, visitExportStrippingModifier, .{});
                const classData = tree.getNode(classNode).ClassDeclaration;
                const modifiers = modifier_visitor.visitModifiers(classData.modifiers orelse 0);

                const declName = if ((classData.name orelse 0) != 0) f.getLocalName(classNode) else f.newIdentifier("default_1");
                const varDecl = f.newVariableDeclaration(declName, 0, 0, iife);
                const varDecls = f.newVariableDeclarationList(f.newNodeList(&[_]ast_gen.NodeIndex{varDecl}), ast_utils.NodeFlags.Let);
                const varStatement = f.newVariableStatement(modifiers, varDecls);
                statements.append(self.allocator, varStatement) catch unreachable;

                if (isExport) {
                    const exportStatement = f.newExternalModuleExport(declName);
                    statements.append(self.allocator, exportStatement) catch unreachable;
                }
            }

            return self.singleOrMany(statements.items);
        }

        var modifier_visitor = visitor.NodeVisitor.init(self.allocator, tree, self, visitModifier, .{});
        const modifiers = modifier_visitor.visitModifiers(data.modifiers orelse 0);
        const heritageClauses = v.visitNodes(data.HeritageClauses orelse 0);

        self.enterClass(null);
        var element_visitor = visitor.NodeVisitor.init(self.allocator, tree, self, visitClassElement, .{});
        const members = element_visitor.visitNodes(data.Members);
        self.exitClass();

        return f.updateClassDeclaration(
            node,
            data,
            modifiers,
            data.name orelse 0,
            data.TypeParameters orelse 0,
            heritageClauses,
            members,
        );
    }

    fn visitClassExpression(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        const data = tree.getNode(node).ClassExpression;

        if (isDecoratedClassLike(tree, node)) {
            const iife = self.transformClassLike(v, node);
            return iife;
        }

        var modifier_visitor = visitor.NodeVisitor.init(self.allocator, tree, self, visitModifier, .{});
        const modifiers = modifier_visitor.visitModifiers(data.modifiers orelse 0);
        const heritageClauses = v.visitNodes(data.HeritageClauses orelse 0);

        self.enterClass(null);
        var element_visitor = visitor.NodeVisitor.init(self.allocator, tree, self, visitClassElement, .{});
        const members = element_visitor.visitNodes(data.Members);
        self.exitClass();

        return f.updateClassExpression(
            node,
            data,
            modifiers,
            data.name orelse 0,
            data.TypeParameters orelse 0,
            heritageClauses,
            members,
        );
    }

    fn transformClassLike(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const tree = v.tree;
        const ec = self.transformer.emitContext;

        ec.startVariableEnvironment() catch unreachable;

        var classNode = node;
        const isDecorated = ast_utils.nodeIsDecorated(tree, false, classNode, 0);
        if (!classHasDeclaredOrExplicitlyAssignedName(ec, classNode) and isDecorated) {
            classNode = self.injectClassNamedEvaluationHelperBlockIfMissing(classNode, f.newStringLiteral("", 0));
        }

        const classData = tree.getNode(classNode);
        const hasName = switch (tree.getNodeKind(classNode)) {
            .ClassDeclaration => classData.ClassDeclaration.name orelse 0,
            .ClassExpression => classData.ClassExpression.name orelse 0,
            else => 0,
        };
        const classNameText = if (hasName != 0) ast_utils.getText(tree, hasName) else "default_1";
        const classReference = f.newIdentifier(classNameText);

        const ci = self.createClassInfo(classNode) catch unreachable;
        defer ci.deinit(self.allocator);

        var classDefinitionStatements = std.ArrayList(ast_gen.NodeIndex).empty;
        defer classDefinitionStatements.deinit(self.allocator);

        var leadingBlockStatements = std.ArrayList(ast_gen.NodeIndex).empty;
        defer leadingBlockStatements.deinit(self.allocator);

        var trailingBlockStatements = std.ArrayList(ast_gen.NodeIndex).empty;
        defer trailingBlockStatements.deinit(self.allocator);

        var syntheticConstructor: ast_gen.NodeIndex = 0;
        var heritageClauses: ast_gen.NodeIndex = 0;
        var shouldTransformPrivateStaticElementsInClass = false;

        const decorators_list = switch (tree.getNodeKind(classNode)) {
            .ClassDeclaration => classData.ClassDeclaration.modifiers,
            .ClassExpression => classData.ClassExpression.modifiers,
            else => null,
        };
        var decorators = std.ArrayList(ast_gen.NodeIndex).empty;
        defer decorators.deinit(self.allocator);
        if (decorators_list) |dl| {
            for (tree.getNodeList(dl)) |m| {
                if (tree.getNodeKind(m) == .Decorator) {
                    decorators.append(self.allocator, m) catch unreachable;
                }
            }
        }

        const classDecorators = self.transformAllDecoratorsOfDeclaration(v, decorators.items);
        if (classDecorators.len > 0) {
            ci.classDecoratorsName = f.newUniqueName("_classDecorators");
            ci.classDescriptorName = f.newUniqueName("_classDescriptor");
            ci.classExtraInitializersName = f.newUniqueName("_classExtraInitializers");

            const decoratorsArray = f.newArrayLiteralExpression(f.newNodeList(classDecorators), false);
            classDefinitionStatements.append(self.allocator, self.createLet(ci.classDecoratorsName, decoratorsArray)) catch unreachable;
            classDefinitionStatements.append(self.allocator, self.createLet(ci.classDescriptorName, 0)) catch unreachable;
            classDefinitionStatements.append(self.allocator, self.createLet(ci.classExtraInitializersName, f.newArrayLiteralExpression(f.newNodeList(&[_]ast_gen.NodeIndex{}), false))) catch unreachable;
            classDefinitionStatements.append(self.allocator, self.createLet(ci.classThis, 0)) catch unreachable;

            if (ci.hasStaticPrivateClassElements) {
                shouldTransformPrivateStaticElementsInClass = true;
                self.should_transform_private_static_elements_in_file = true;
            }
        }

        const extendsClause = getHeritageClause(tree, classNode, .ExtendsKeyword);
        var extendsElement: ast_gen.NodeIndex = 0;
        if (extendsClause) |ec_idx| {
            const hc = tree.getNode(ec_idx).HeritageClause;
            const types = tree.getNodeList(hc.Types);
            if (types.len > 0) {
                extendsElement = types[0];
            }
        }

        var extendsExpression: ast_gen.NodeIndex = 0;
        if (extendsElement != 0) {
            const originalExtendsExpression = tree.getNode(extendsElement).ExpressionWithTypeArguments.Expression;
            const visitedExtendsExpression = v.visitNode(originalExtendsExpression);
            extendsExpression = if (visitedExtendsExpression != 0) visitedExtendsExpression else originalExtendsExpression;
        }

        if (extendsExpression != 0) {
            ci.classSuper = f.newUniqueName("_classSuper");
            const unwrapped = skipOuterExpressions(tree, extendsExpression);
            var safeExtendsExpression = extendsExpression;
            const unwrappedKind = tree.getNodeKind(unwrapped);
            const isAnonExpr = (unwrappedKind == .ClassExpression and (tree.getNode(unwrapped).ClassExpression.name orelse 0) == 0) or
                (unwrappedKind == .FunctionExpression and (tree.getNode(unwrapped).FunctionExpression.name orelse 0) == 0) or
                unwrappedKind == .ArrowFunction;
            if (isAnonExpr) {
                safeExtendsExpression = self.newCommaExpression(f.newNumericLiteral("0", 0), extendsExpression);
            }
            classDefinitionStatements.append(self.allocator, self.createLet(ci.classSuper, safeExtendsExpression)) catch unreachable;

            const updatedExtendsElement = f.updateExpressionWithTypeArguments(
                extendsElement,
                tree.getNode(extendsElement).ExpressionWithTypeArguments,
                ci.classSuper,
                0,
            );
            const hc = tree.getNode(extendsClause.?).HeritageClause;
            const updatedExtendsClause = f.updateHeritageClause(
                extendsClause.?,
                hc,
                hc.Token,
                f.newNodeList(&[_]ast_gen.NodeIndex{updatedExtendsElement}),
            );
            heritageClauses = f.newNodeList(&[_]ast_gen.NodeIndex{updatedExtendsClause});
        } else if (extendsClause != 0) {
            heritageClauses = switch (tree.getNodeKind(classNode)) {
                .ClassDeclaration => classData.ClassDeclaration.HeritageClauses orelse 0,
                .ClassExpression => classData.ClassExpression.HeritageClauses orelse 0,
                else => 0,
            };
        }

        const renamedClassThis = if (ci.classThis != 0) ci.classThis else f.newToken(.{ .ThisKeyword = {} });

        self.enterClass(ci);
        leadingBlockStatements.append(self.allocator, self.createMetadata(ci.metadataReference, ci.classSuper)) catch unreachable;

        var non_constructor_visitor = visitor.NodeVisitor.init(self.allocator, tree, self, visitNonConstructorClassElement, .{});
        const members_list = switch (tree.getNodeKind(classNode)) {
            .ClassDeclaration => classData.ClassDeclaration.Members,
            .ClassExpression => classData.ClassExpression.Members,
            else => unreachable,
        };
        var members = non_constructor_visitor.visitNodes(members_list);

        var constructor_visitor = visitor.NodeVisitor.init(self.allocator, tree, self, visitConstructorClassElement, .{});
        members = constructor_visitor.visitNodes(members);

        const downlevelDecoratorStaticBlocks = classDecorators.len > 0 and @intFromEnum(self.compiler_options.target orelse .ES2025) < @intFromEnum(core.ScriptTarget.ES2022);
        var downlevelStaticFieldStatements = std.ArrayList(ast_gen.NodeIndex).empty;
        defer downlevelStaticFieldStatements.deinit(self.allocator);
        if (downlevelDecoratorStaticBlocks) {
            const currentMembers = self.allocator.dupe(ast_gen.NodeIndex, tree.getNodeList(members)) catch unreachable;
            defer self.allocator.free(currentMembers);
            var retainedMembers = std.ArrayList(ast_gen.NodeIndex).empty;
            defer retainedMembers.deinit(self.allocator);
            for (currentMembers) |member| {
                if (tree.getNode(member) == .PropertyDeclaration and ast_utils.isStatic(tree, member)) {
                    const property = tree.getNode(member).PropertyDeclaration;
                    if ((property.Initializer orelse 0) != 0) {
                        const left = if (tree.getNode(property.name) == .ComputedPropertyName)
                            f.newElementAccessExpression(ci.classThis, 0, tree.getNode(property.name).ComputedPropertyName.Expression, 0)
                        else
                            f.newPropertyAccessExpression(ci.classThis, 0, property.name, 0);
                        downlevelStaticFieldStatements.append(self.allocator, f.newExpressionStatement(f.newAssignmentExpression(left, property.Initializer.?))) catch unreachable;
                    }
                } else retainedMembers.append(self.allocator, member) catch unreachable;
            }
            members = f.newNodeList(retainedMembers.items);
        }

        if (self.pending_expressions.items.len > 0) {
            self.outer_this = 0;
            var outer_this_visitor = visitor.NodeVisitor.init(self.allocator, tree, self, visitOuterThis, .{});
            for (self.pending_expressions.items) |expr| {
                var final_expr = expr;
                final_expr = outer_this_visitor.visitNode(expr);
                leadingBlockStatements.append(self.allocator, f.newExpressionStatement(final_expr)) catch unreachable;
            }
            if (self.outer_this != 0) {
                classDefinitionStatements.insert(self.allocator, 0, self.createLet(self.outer_this, f.newToken(.{ .ThisKeyword = {} }))) catch unreachable;
            }
            self.pending_expressions.clearRetainingCapacity();
        }
        self.exitClass();

        // Synthetic constructor
        if (ci.pendingInstanceInitializers.items.len > 0 and getFirstConstructorWithBody(tree, classNode) == 0) {
            const initializerStatements = self.prepareConstructor(ci);
            if (initializerStatements.len > 0) {
                const extendsNull = extendsElement != 0 and tree.getNodeKind(skipOuterExpressions(tree, tree.getNode(extendsElement).ExpressionWithTypeArguments.Expression)) == .NullKeyword;
                const isDerivedClass = extendsElement != 0 and !extendsNull;
                var constructorStatements = std.ArrayList(ast_gen.NodeIndex).empty;
                defer constructorStatements.deinit(self.allocator);

                if (isDerivedClass) {
                    const spreadArguments = f.newSpreadElement(f.newIdentifier("arguments"));
                    const superCall = f.newCallExpression(
                        f.newToken(.{ .SuperKeyword = {} }),
                        0,
                        0,
                        f.newNodeList(&[_]ast_gen.NodeIndex{spreadArguments}),
                        0,
                    );
                    constructorStatements.append(self.allocator, f.newExpressionStatement(superCall)) catch unreachable;
                }
                constructorStatements.appendSlice(self.allocator, initializerStatements) catch unreachable;
                const constructorBody = f.newBlock(f.newNodeList(constructorStatements.items), true);
                syntheticConstructor = f.newConstructorDeclaration(0, constructorBody);
            }
        }

        if (ci.staticMethodExtraInitializersName != 0) {
            classDefinitionStatements.append(self.allocator, self.createLet(ci.staticMethodExtraInitializersName, f.newArrayLiteralExpression(f.newNodeList(&[_]ast_gen.NodeIndex{}), false))) catch unreachable;
        }
        if (ci.instanceMethodExtraInitializersName != 0) {
            classDefinitionStatements.append(self.allocator, self.createLet(ci.instanceMethodExtraInitializersName, f.newArrayLiteralExpression(f.newNodeList(&[_]ast_gen.NodeIndex{}), false))) catch unreachable;
        }

        if (ci.memberInfos.count() > 0) {
            classDefinitionStatements.appendSlice(self.allocator, self.emitMemberInfoDeclarations(ci, true)) catch unreachable;
            classDefinitionStatements.appendSlice(self.allocator, self.emitMemberInfoDeclarations(ci, false)) catch unreachable;
        }

        leadingBlockStatements.appendSlice(self.allocator, ci.staticNonFieldDecorationStatements.items) catch unreachable;
        leadingBlockStatements.appendSlice(self.allocator, ci.nonStaticNonFieldDecorationStatements.items) catch unreachable;
        leadingBlockStatements.appendSlice(self.allocator, ci.staticFieldDecorationStatements.items) catch unreachable;
        leadingBlockStatements.appendSlice(self.allocator, ci.nonStaticFieldDecorationStatements.items) catch unreachable;

        if (ci.classDescriptorName != 0 and ci.classDecoratorsName != 0 and ci.classExtraInitializersName != 0 and ci.classThis != 0) {
            const valueProperty = f.newPropertyAssignment(0, f.newIdentifier("value"), 0, 0, renamedClassThis);
            const classDescriptor = f.newObjectLiteralExpression(f.newNodeList(&[_]ast_gen.NodeIndex{valueProperty}), false);
            const classDescriptorAssignment = f.newAssignmentExpression(ci.classDescriptorName, classDescriptor);
            const classNameReference = f.newPropertyAccessExpression(renamedClassThis, 0, f.newIdentifier("name"), 0);

            const contextObj = self.newESDecorateClassContextObject(classNameReference, ci.metadataReference);
            const esDecorateHelper = self.newESDecorateHelper(
                f.newToken(.{ .NullKeyword = {} }),
                classDescriptorAssignment,
                ci.classDecoratorsName,
                contextObj,
                f.newToken(.{ .NullKeyword = {} }),
                ci.classExtraInitializersName,
            );
            leadingBlockStatements.append(self.allocator, f.newExpressionStatement(esDecorateHelper)) catch unreachable;

            const classDescriptorValueRef = f.newPropertyAccessExpression(ci.classDescriptorName, 0, f.newIdentifier("value"), 0);
            const classThisAssignment = f.newAssignmentExpression(ci.classThis, classDescriptorValueRef);
            const classReferenceAssignment = f.newAssignmentExpression(classReference, classThisAssignment);
            leadingBlockStatements.append(self.allocator, f.newExpressionStatement(classReferenceAssignment)) catch unreachable;
        }

        leadingBlockStatements.append(self.allocator, self.createSymbolMetadata(renamedClassThis, ci.metadataReference)) catch unreachable;

        if (ci.pendingStaticInitializers.items.len > 0) {
            for (ci.pendingStaticInitializers.items) |initializer| {
                trailingBlockStatements.append(self.allocator, f.newExpressionStatement(initializer)) catch unreachable;
            }
            ci.pendingStaticInitializers.clearRetainingCapacity();
        }

        if (ci.classExtraInitializersName != 0) {
            const runClassInitializersHelper = self.newRunInitializersHelper(renamedClassThis, ci.classExtraInitializersName, 0);
            trailingBlockStatements.append(self.allocator, f.newExpressionStatement(runClassInitializersHelper)) catch unreachable;
        }

        if (leadingBlockStatements.items.len > 0 and trailingBlockStatements.items.len > 0 and !ci.hasStaticInitializers) {
            leadingBlockStatements.appendSlice(self.allocator, trailingBlockStatements.items) catch unreachable;
            trailingBlockStatements.clearRetainingCapacity();
        }

        var leadingStaticBlock: ast_gen.NodeIndex = 0;
        if (leadingBlockStatements.items.len > 0 and !downlevelDecoratorStaticBlocks) {
            leadingStaticBlock = f.newClassStaticBlockDeclaration(
                0,
                f.newBlock(f.newNodeList(leadingBlockStatements.items), true),
            );
        }

        var trailingStaticBlock: ast_gen.NodeIndex = 0;
        if (trailingBlockStatements.items.len > 0 and !downlevelDecoratorStaticBlocks) {
            trailingStaticBlock = f.newClassStaticBlockDeclaration(
                0,
                f.newBlock(f.newNodeList(trailingBlockStatements.items), true),
            );
        }

        var membersSlice = tree.getNodeList(members);
        if (leadingStaticBlock != 0 or syntheticConstructor != 0 or trailingStaticBlock != 0) {
            var newMembers = std.ArrayList(ast_gen.NodeIndex).empty;
            defer newMembers.deinit(self.allocator);

            var existingNamedEvaluationHelperBlockIndex: isize = -1;
            for (membersSlice, 0..) |m, i| {
                if (isClassNamedEvaluationHelperBlock(ec, m)) {
                    existingNamedEvaluationHelperBlockIndex = @intCast(i);
                    break;
                }
            }

            if (leadingStaticBlock != 0) {
                const insertPos: usize = @intCast(existingNamedEvaluationHelperBlockIndex + 1);
                newMembers.appendSlice(self.allocator, membersSlice[0..insertPos]) catch unreachable;
                newMembers.append(self.allocator, leadingStaticBlock) catch unreachable;
                newMembers.appendSlice(self.allocator, membersSlice[insertPos..]) catch unreachable;
            } else {
                newMembers.appendSlice(self.allocator, membersSlice) catch unreachable;
            }

            if (syntheticConstructor != 0) {
                newMembers.append(self.allocator, syntheticConstructor) catch unreachable;
            }
            if (trailingStaticBlock != 0) {
                newMembers.append(self.allocator, trailingStaticBlock) catch unreachable;
            }
            members = f.newNodeList(newMembers.items);
        }

        const lexicalEnvironment = ec.endVariableEnvironment() catch unreachable;

        var classExpression: ast_gen.NodeIndex = 0;
        if (classDecorators.len > 0) {
            classExpression = f.newClassExpression(0, 0, 0, heritageClauses, members);
            if (ci.classThis != 0) {
                if (downlevelDecoratorStaticBlocks) {
                    classExpression = f.newAssignmentExpression(ci.classThis, classExpression);
                } else {
                    classExpression = self.injectClassThisAssignmentIfMissing(classExpression, ci.classThis);
                }
            }

            const classReferenceDeclaration = f.newVariableDeclaration(classReference, 0, 0, classExpression);
            const classReferenceVarDeclList = f.newVariableDeclarationList(f.newNodeList(&[_]ast_gen.NodeIndex{classReferenceDeclaration}), ast_utils.NodeFlags.None);

            const returnExpr = if (ci.classThis != 0)
                f.newAssignmentExpression(classReference, ci.classThis)
            else
                classReference;

            classDefinitionStatements.append(self.allocator, f.newVariableStatement(0, classReferenceVarDeclList)) catch unreachable;
            if (downlevelDecoratorStaticBlocks) {
                self.transformer.emitContext.requestEmitHelper(&helpers.setFunctionNameHelper);
                const assignedName = f.newStringLiteral(classNameText, false);
                classDefinitionStatements.append(self.allocator, f.newExpressionStatement(self.newSetFunctionNameHelper(ci.classThis, assignedName, ""))) catch unreachable;
                if (leadingBlockStatements.items.len > 0) {
                    classDefinitionStatements.append(self.allocator, f.newExpressionStatement(self.newImmediatelyInvokedArrowFunction(leadingBlockStatements.items))) catch unreachable;
                }
                classDefinitionStatements.appendSlice(self.allocator, downlevelStaticFieldStatements.items) catch unreachable;
                if (trailingBlockStatements.items.len > 0) {
                    classDefinitionStatements.append(self.allocator, f.newExpressionStatement(self.newImmediatelyInvokedArrowFunction(trailingBlockStatements.items))) catch unreachable;
                }
            }
            classDefinitionStatements.append(self.allocator, f.newReturnStatement(returnExpr)) catch unreachable;
        } else {
            const hasName2 = switch (tree.getNodeKind(classNode)) {
                .ClassDeclaration => classData.ClassDeclaration.name orelse 0,
                .ClassExpression => classData.ClassExpression.name orelse 0,
                else => 0,
            };
            classExpression = f.newClassExpression(0, if (hasName2 != 0) hasName2 else classReference, 0, heritageClauses, members);
            classDefinitionStatements.append(self.allocator, f.newReturnStatement(classExpression)) catch unreachable;
        }

        var mergedStatements = std.ArrayList(ast_gen.NodeIndex).empty;
        defer mergedStatements.deinit(self.allocator);
        mergedStatements.appendSlice(self.allocator, lexicalEnvironment.items) catch unreachable;
        mergedStatements.appendSlice(self.allocator, classDefinitionStatements.items) catch unreachable;

        return self.newImmediatelyInvokedArrowFunction(mergedStatements.items);
    }

    fn emitMemberInfoDeclarations(self: *ESDecoratorTransformer, ci: *ClassInfo, isStatic: bool) []const ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const tree = self.transformer.emitContext.tree;
        var stmts = std.ArrayList(ast_gen.NodeIndex).empty;

        var it = ci.memberInfos.iterator();
        while (it.next()) |entry| {
            const member = entry.key_ptr.*;
            const mi = entry.value_ptr.*;
            if (ast_utils.isStatic(tree, member) != isStatic) {
                continue;
            }
            stmts.append(self.allocator, self.createLet(mi.memberDecoratorsName, 0)) catch unreachable;
            if (mi.memberInitializersName != 0) {
                stmts.append(self.allocator, self.createLet(mi.memberInitializersName, f.newArrayLiteralExpression(f.newNodeList(&[_]ast_gen.NodeIndex{}), false))) catch unreachable;
            }
            if (mi.memberExtraInitializersName != 0) {
                stmts.append(self.allocator, self.createLet(mi.memberExtraInitializersName, f.newArrayLiteralExpression(f.newNodeList(&[_]ast_gen.NodeIndex{}), false))) catch unreachable;
            }
            if (mi.memberDescriptorName != 0) {
                stmts.append(self.allocator, self.createLet(mi.memberDescriptorName, 0)) catch unreachable;
            }
        }
        return self.allocator.dupe(ast_gen.NodeIndex, stmts.items) catch unreachable;
    }

    fn prepareConstructor(self: *ESDecoratorTransformer, ci: *ClassInfo) []const ast_gen.NodeIndex {
        if (ci.pendingInstanceInitializers.items.len == 0) {
            return &[_]ast_gen.NodeIndex{};
        }
        const f = self.transformer.factory;
        const inlined = f.inlineExpressions(ci.pendingInstanceInitializers.items);
        const stmt = f.newExpressionStatement(inlined);
        ci.pendingInstanceInitializers.clearRetainingCapacity();
        return self.allocator.dupe(ast_gen.NodeIndex, &[_]ast_gen.NodeIndex{stmt}) catch unreachable;
    }

    fn visitConstructorDeclaration(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        self.enterClassElement(node);
        const tree = v.tree;
        const f = self.transformer.factory;
        const ctor = tree.getNode(node).Constructor;

        var modifier_visitor = visitor.NodeVisitor.init(self.allocator, tree, self, visitModifier, .{});
        const modifiers = modifier_visitor.visitModifiers(ctor.modifiers orelse 0);
        const parameters = v.visitNodes(ctor.Parameters);

        var body = ctor.Body orelse 0;
        if (body != 0 and self.class_info_stack != null) {
            const initializerStatements = self.prepareConstructor(self.class_info_stack.?);
            if (initializerStatements.len > 0) {
                const bodyBlock = tree.getNode(body).Block;
                const statements = tree.getNodeList(bodyBlock.Statements);
                const split = f.splitStandardPrologue(statements);

                var stmts = std.ArrayList(ast_gen.NodeIndex).empty;
                defer stmts.deinit(self.allocator);
                stmts.appendSlice(self.allocator, split.prologue) catch unreachable;

                const superStatementIndices = findSuperStatementIndexPath(tree, split.statements, 0);
                if (superStatementIndices.len > 0) {
                    const superIndex = superStatementIndices[0];
                    for (split.statements[0..superIndex]) |s| {
                        stmts.append(self.allocator, v.visitNode(s)) catch unreachable;
                    }
                    stmts.append(self.allocator, v.visitNode(split.statements[superIndex])) catch unreachable;
                    stmts.appendSlice(self.allocator, initializerStatements) catch unreachable;
                    for (split.statements[superIndex + 1 ..]) |s| {
                        stmts.append(self.allocator, v.visitNode(s)) catch unreachable;
                    }
                } else {
                    stmts.appendSlice(self.allocator, initializerStatements) catch unreachable;
                    for (split.statements) |s| {
                        stmts.append(self.allocator, v.visitNode(s)) catch unreachable;
                    }
                }
                body = f.newBlock(f.newNodeList(stmts.items), true);
            }
        }

        if (body != 0 and body == (ctor.Body orelse 0)) {
            body = v.visitNode(body);
        }

        self.exitClassElement();
        return f.updateConstructorDeclaration(
            node,
            ctor,
            modifiers,
            0,
            parameters,
            0,
            body,
        );
    }

    fn visitMethodDeclaration(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        self.enterClassElement(node);
        const tree = v.tree;
        const f = self.transformer.factory;
        const result = self.partialTransformClassElement(v, node, self.class_info_stack, createMethodDescriptorObject);
        if (result.descriptorName != 0) {
            self.exitClassElement();
            return self.createMethodDescriptorForwarder(result.modifiers, result.name, result.descriptorName);
        }

        const method = tree.getNode(node).MethodDeclaration;
        const parameters = v.visitNodes(method.Parameters);
        const body = v.visitNode(method.Body orelse 0);
        self.exitClassElement();

        return f.updateMethodDeclaration(
            node,
            method,
            result.modifiers,
            method.AsteriskToken orelse 0,
            result.name,
            0,
            0,
            parameters,
            0,
            body,
        );
    }

    fn visitGetAccessorDeclaration(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        self.enterClassElement(node);
        const tree = v.tree;
        const f = self.transformer.factory;
        const result = self.partialTransformClassElement(v, node, self.class_info_stack, createGetAccessorDescriptorObject);
        if (result.descriptorName != 0) {
            self.exitClassElement();
            return self.createGetAccessorDescriptorForwarder(result.modifiers, result.name, result.descriptorName);
        }

        const accessor = tree.getNode(node).GetAccessor;
        const parameters = v.visitNodes(accessor.Parameters);
        const body = v.visitNode(accessor.Body orelse 0);
        self.exitClassElement();

        return f.updateGetAccessorDeclaration(
            node,
            accessor,
            result.modifiers,
            result.name,
            0,
            parameters,
            0,
            body,
        );
    }

    fn visitSetAccessorDeclaration(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        self.enterClassElement(node);
        const tree = v.tree;
        const f = self.transformer.factory;
        const result = self.partialTransformClassElement(v, node, self.class_info_stack, createSetAccessorDescriptorObject);
        if (result.descriptorName != 0) {
            self.exitClassElement();
            return self.createSetAccessorDescriptorForwarder(result.modifiers, result.name, result.descriptorName);
        }

        const accessor = tree.getNode(node).SetAccessor;
        const parameters = v.visitNodes(accessor.Parameters);
        const body = v.visitNode(accessor.Body orelse 0);
        self.exitClassElement();

        return f.updateSetAccessorDeclaration(
            node,
            accessor,
            result.modifiers,
            result.name,
            0,
            parameters,
            0,
            body,
        );
    }

    fn visitClassStaticBlockDeclaration(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        self.enterClassElement(node);
        const tree = v.tree;
        const f = self.transformer.factory;
        const ec = self.transformer.emitContext;

        var result: ast_gen.NodeIndex = 0;
        if (isClassNamedEvaluationHelperBlock(ec, node)) {
            result = v.visitEachChild(node);
            if (result != node) {
                const assignedName = ec.getAssignedName(node);
                if (assignedName != 0) {
                    ec.setAssignedName(result, assignedName) catch {};
                }
            }
        } else if (isClassThisAssignmentBlock(ec, node)) {
            const savedClassThis = self.class_this;
            self.class_this = 0;
            result = v.visitEachChild(node);
            self.class_this = savedClassThis;
        } else {
            ec.startVariableEnvironment() catch unreachable;
            result = v.visitEachChild(node);
            var varStatements = ec.endVariableEnvironment() catch unreachable;
            defer varStatements.deinit(self.allocator);

            if (varStatements.items.len > 0) {
                const blockBody = tree.getNode(tree.getNode(result).ClassStaticBlockDeclaration.Body).Block;
                const statements = tree.getNodeList(blockBody.Statements);
                var newStmts = std.ArrayList(ast_gen.NodeIndex).empty;
                defer newStmts.deinit(self.allocator);
                newStmts.appendSlice(self.allocator, varStatements.items) catch unreachable;
                newStmts.appendSlice(self.allocator, statements) catch unreachable;
                result = f.newClassStaticBlockDeclaration(0, f.newBlock(f.newNodeList(newStmts.items), blockBody.MultiLine));
            }

            if (self.class_info_stack) |ci| {
                ci.hasStaticInitializers = true;
                if (ci.pendingStaticInitializers.items.len > 0) {
                    var stmts = std.ArrayList(ast_gen.NodeIndex).empty;
                    defer stmts.deinit(self.allocator);
                    for (ci.pendingStaticInitializers.items) |init| {
                        stmts.append(self.allocator, f.newExpressionStatement(init)) catch unreachable;
                    }
                    const body = f.newBlock(f.newNodeList(stmts.items), true);
                    const staticBlock = f.newClassStaticBlockDeclaration(0, body);
                    ci.pendingStaticInitializers.clearRetainingCapacity();
                    self.exitClassElement();
                    return self.singleOrMany(&[_]ast_gen.NodeIndex{ staticBlock, result });
                }
            }
        }

        self.exitClassElement();
        return result;
    }

    fn visitPropertyDeclaration(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        const ec = self.transformer.emitContext;
        const prop = tree.getNode(node).PropertyDeclaration;

        var finalNode = node;
        if (isNamedEvaluationAnd(ec, finalNode, isAnonymousClassNeedingAssignedName)) {
            finalNode = self.transformNamedEvaluation(ec, finalNode, canIgnoreEmptyStringLiteralInAssignedName(tree, prop.Initializer orelse 0), "");
        }

        self.enterClassElement(finalNode);

        const createDescriptor: ?*const fn (*ESDecoratorTransformer, ast_gen.NodeIndex, ast_gen.NodeIndex) ast_gen.NodeIndex = if (ast_utils.hasAccessorModifier(tree, finalNode))
            createAccessorPropertyDescriptorObject
        else
            null;

        const result = self.partialTransformClassElement(v, finalNode, self.class_info_stack, createDescriptor);

        ec.startVariableEnvironment() catch unreachable;

        const finalProp = tree.getNode(finalNode).PropertyDeclaration;
        var initializer = v.visitNode(finalProp.Initializer orelse 0);
        if (result.initializersName != 0) {
            const thisArg = if (result.thisArg != 0) result.thisArg else f.newToken(.{ .ThisKeyword = {} });
            if (initializer == 0) {
                initializer = f.newVoidZeroExpression();
            }
            initializer = self.newRunInitializersHelper(thisArg, result.initializersName, initializer);
        }

        if (ast_utils.isStatic(tree, finalNode) and self.class_info_stack != null and initializer != 0) {
            self.class_info_stack.?.hasStaticInitializers = true;
        }

        var declarations = ec.endVariableEnvironment() catch unreachable;
        defer declarations.deinit(self.allocator);
        if (declarations.items.len > 0) {
            var stmts = std.ArrayList(ast_gen.NodeIndex).empty;
            defer stmts.deinit(self.allocator);
            stmts.appendSlice(self.allocator, declarations.items) catch unreachable;
            stmts.append(self.allocator, f.newReturnStatement(initializer)) catch unreachable;
            initializer = self.newImmediatelyInvokedArrowFunction(stmts.items);
        }

        if (self.class_info_stack) |ci| {
            if (ast_utils.isStatic(tree, finalNode)) {
                initializer = self.injectPendingInitializers(ci, true, initializer);
                if (result.extraInitializersName != 0) {
                    const thisArg = if (ci.classThis != 0) ci.classThis else f.newToken(.{ .ThisKeyword = {} });
                    ci.pendingStaticInitializers.append(self.allocator, self.newRunInitializersHelper(thisArg, result.extraInitializersName, 0)) catch unreachable;
                }
            } else {
                initializer = self.injectPendingInitializers(ci, false, initializer);
                if (result.extraInitializersName != 0) {
                    ci.pendingInstanceInitializers.append(self.allocator, self.newRunInitializersHelper(f.newToken(.{ .ThisKeyword = {} }), result.extraInitializersName, 0)) catch unreachable;
                }
            }
        }

        self.exitClassElement();

        if (ast_utils.hasAccessorModifier(tree, finalNode) and result.descriptorName != 0) {
            var accessor_stripper = visitor.NodeVisitor.init(self.allocator, tree, self, visitAccessorStrippingModifier, .{});
            const modifiersWithoutAccessor = accessor_stripper.visitModifiers(result.modifiers);

            const backingField = self.createAccessorPropertyBackingField(finalNode, modifiersWithoutAccessor, initializer);
            const getter = self.createGetAccessorDescriptorForwarder(modifiersWithoutAccessor, result.name, result.descriptorName);
            const setter = self.createSetAccessorDescriptorForwarder(modifiersWithoutAccessor, result.name, result.descriptorName);

            return self.singleOrMany(&[_]ast_gen.NodeIndex{ backingField, getter, setter });
        }

        return f.updatePropertyDeclaration(
            finalNode,
            finalProp,
            result.modifiers,
            result.name,
            0,
            0,
            initializer,
        );
    }

    fn visitParameterDeclaration(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        const ec = self.transformer.emitContext;
        const param = tree.getNode(node).Parameter;

        var finalNode = node;
        if (isNamedEvaluationAnd(ec, finalNode, isAnonymousClassNeedingAssignedName)) {
            finalNode = self.transformNamedEvaluation(ec, finalNode, canIgnoreEmptyStringLiteralInAssignedName(tree, param.Initializer orelse 0), "");
        }

        const updatedParam = tree.getNode(finalNode).Parameter;
        return f.updateParameterDeclaration(
            finalNode,
            updatedParam,
            0,
            updatedParam.DotDotDotToken orelse 0,
            v.visitNode(updatedParam.name),
            0,
            0,
            v.visitNode(updatedParam.Initializer orelse 0),
        );
    }

    fn visitNamedEvaluationSite(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex, classExpr: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const ec = self.transformer.emitContext;
        var finalNode = node;
        if (isNamedEvaluationAnd(ec, finalNode, isAnonymousClassNeedingAssignedName)) {
            finalNode = self.transformNamedEvaluation(ec, finalNode, canIgnoreEmptyStringLiteralInAssignedName(v.tree, classExpr), "");
        }
        return v.visitEachChild(finalNode);
    }

    fn visitExportAssignment(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const expr = v.tree.getNode(node).ExportAssignment.Expression;
        return self.visitNamedEvaluationSite(v, node, expr);
    }

    fn visitThisExpression(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = v;
        if (self.class_this != 0) {
            return self.class_this;
        }
        return node;
    }

    fn visitForStatement(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const forStmt = tree.getNode(node).ForStatement;

        var discarded_visitor = visitor.NodeVisitor.init(self.allocator, tree, self, visitDiscardedValue, .{});

        return self.updateForStatement(
            node,
            forStmt,
            discarded_visitor.visitNode(forStmt.Initializer orelse 0),
            v.visitNode(forStmt.Condition orelse 0),
            discarded_visitor.visitNode(forStmt.Incrementor orelse 0),
            v.visitNode(forStmt.Statement),
        );
    }

    fn visitExpressionStatement(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        var discarded_visitor = visitor.NodeVisitor.init(self.allocator, tree, self, visitDiscardedValue, .{});
        return discarded_visitor.visitEachChild(node);
    }

    fn visitParenthesizedExpression(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex, discarded: bool) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const pe = v.tree.getNode(node).ParenthesizedExpression;
        var expression: ast_gen.NodeIndex = 0;
        if (discarded) {
            var discarded_visitor = visitor.NodeVisitor.init(self.allocator, v.tree, self, visitDiscardedValue, .{});
            expression = discarded_visitor.visitNode(pe.Expression);
        } else {
            expression = v.visitNode(pe.Expression);
        }
        return f.newParenthesizedExpression(expression);
    }

    fn visitPartiallyEmittedExpression(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex, discarded: bool) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const pe = v.tree.getNode(node).PartiallyEmittedExpression;
        var expression: ast_gen.NodeIndex = 0;
        if (discarded) {
            var discarded_visitor = visitor.NodeVisitor.init(self.allocator, v.tree, self, visitDiscardedValue, .{});
            expression = discarded_visitor.visitNode(pe.Expression);
        } else {
            expression = v.visitNode(pe.Expression);
        }
        return f.newPartiallyEmittedExpression(expression);
    }

    fn visitCallExpression(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        const call = tree.getNode(node).CallExpression;
        if (isSuperProperty(tree, call.Expression) and self.class_this != 0) {
            const expression = v.visitNode(call.Expression);
            const argumentsList = v.visitNodes(call.Arguments);
            const call_kw = f.newIdentifier("call");
            const propAccess = f.newPropertyAccessExpression(expression, 0, call_kw, 0);

            var args = std.ArrayList(ast_gen.NodeIndex).empty;
            defer args.deinit(self.allocator);
            args.append(self.allocator, self.class_this) catch unreachable;
            args.appendSlice(self.allocator, tree.getNodeList(argumentsList)) catch unreachable;

            const invocation = f.newCallExpression(propAccess, 0, 0, f.newNodeList(args.items), 0);
            return invocation;
        }
        return v.visitEachChild(node);
    }

    fn visitTaggedTemplateExpression(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        const tte = tree.getNode(node).TaggedTemplateExpression;
        if (isSuperProperty(tree, tte.Tag) and self.class_this != 0) {
            const tag = v.visitNode(tte.Tag);
            const bind_kw = f.newIdentifier("bind");
            const bindAccess = f.newPropertyAccessExpression(tag, 0, bind_kw, 0);
            const boundTag = f.newCallExpression(
                bindAccess,
                0,
                0,
                f.newNodeList(&[_]ast_gen.NodeIndex{self.class_this}),
                0,
            );
            const template = v.visitNode(tte.Template);
            return f.updateTaggedTemplateExpression(
                node,
                tte,
                boundTag,
                tte.QuestionDotToken orelse 0,
                tte.TypeArguments orelse 0,
                template,
                tte.Flags,
            );
        }
        return v.visitEachChild(node);
    }

    fn visitPreOrPostfixUnaryExpression(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex, discarded: bool) ast_gen.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        const ec = self.transformer.emitContext;

        var operator: kind.Kind = .Unknown;
        var operandNode: ast_gen.NodeIndex = 0;
        if (tree.getNodeKind(node) == .PrefixUnaryExpression) {
            const prefix = tree.getNode(node).PrefixUnaryExpression;
            operator = @as(kind.Kind, @enumFromInt(prefix.Operator));
            operandNode = prefix.Operand;
        } else {
            const postfix = tree.getNode(node).PostfixUnaryExpression;
            operator = @as(kind.Kind, @enumFromInt(postfix.Operator));
            operandNode = postfix.Operand;
        }

        if (operator == .PlusPlusToken or operator == .MinusMinusToken) {
            const operand = skipOuterExpressions(tree, operandNode);
            if (isSuperProperty(tree, operand) and self.class_this != 0 and self.class_super != 0) {
                var setterName: ast_gen.NodeIndex = 0;
                const operandKind = tree.getNodeKind(operand);
                if (operandKind == .ElementAccessExpression) {
                    setterName = v.visitNode(tree.getNode(operand).ElementAccessExpression.ArgumentExpression);
                } else if (operandKind == .PropertyAccessExpression) {
                    const pa = tree.getNode(operand).PropertyAccessExpression;
                    if (ast_utils.isIdentifier(tree, pa.name)) {
                        setterName = f.newStringLiteralFromNode(pa.name) catch unreachable;
                    }
                }

                if (setterName != 0) {
                    var getterName = setterName;
                    if (!isSimpleInlineableExpression(tree, setterName)) {
                        getterName = f.createTempVariable() catch unreachable;
                        ec.addVariableDeclaration(getterName);
                        setterName = f.newAssignmentExpression(getterName, setterName);
                    }

                    const reflectGet = self.newReflectGetCall(self.class_super, getterName, self.class_this);

                    var temp: ast_gen.NodeIndex = 0;
                    if (!discarded) {
                        temp = f.createTempVariable() catch unreachable;
                        ec.addVariableDeclaration(temp);
                    }

                    var expression = reflectGet;
                    if (temp != 0) {
                        expression = f.newAssignmentExpression(temp, expression);
                    }

                    expression = self.newReflectSetCall(self.class_super, setterName, expression, self.class_this);

                    if (temp != 0) {
                        expression = self.newCommaExpression(expression, temp);
                    }
                    return expression;
                }
            }
        }

        return v.visitEachChild(node);
    }

    fn visitPropertyAccessExpression(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        const pa = tree.getNode(node).PropertyAccessExpression;
        if (isSuperProperty(tree, node) and ast_utils.isIdentifier(tree, pa.name) and self.class_this != 0 and self.class_super != 0) {
            const propertyName = f.newStringLiteralFromNode(pa.name) catch unreachable;
            const superProperty = self.newReflectGetCall(self.class_super, propertyName, self.class_this);
            return superProperty;
        }
        return v.visitEachChild(node);
    }

    fn visitElementAccessExpression(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const ea = tree.getNode(node).ElementAccessExpression;
        if (isSuperProperty(tree, node) and self.class_this != 0 and self.class_super != 0) {
            const propertyName = v.visitNode(ea.ArgumentExpression);
            const superProperty = self.newReflectGetCall(self.class_super, propertyName, self.class_this);
            return superProperty;
        }
        return v.visitEachChild(node);
    }

    fn visitComputedPropertyName(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const cpn = v.tree.getNode(node).ComputedPropertyName;
        var expression = v.visitNode(cpn.Expression);
        if (!isSimpleInlineableExpression(v.tree, expression)) {
            expression = self.injectPendingExpressions(expression);
        }
        return f.updateComputedPropertyName(node, expression);
    }

    fn visitDestructuringAssignmentTarget(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const nodeKind = tree.getNodeKind(node);
        if (nodeKind == .ObjectLiteralExpression or nodeKind == .ArrayLiteralExpression) {
            return self.visitAssignmentPattern(v, node);
        }

        if (isSuperProperty(tree, node) and self.class_this != 0 and self.class_super != 0) {
            const f = self.transformer.factory;
            var propertyName: ast_gen.NodeIndex = 0;
            if (nodeKind == .ElementAccessExpression) {
                propertyName = v.visitNode(tree.getNode(node).ElementAccessExpression.ArgumentExpression);
            } else if (nodeKind == .PropertyAccessExpression) {
                const pa = tree.getNode(node).PropertyAccessExpression;
                if (ast_utils.isIdentifier(tree, pa.name)) {
                    propertyName = f.newStringLiteralFromNode(pa.name) catch unreachable;
                }
            }

            if (propertyName != 0) {
                const paramName = f.createTempVariable() catch unreachable;
                const setCall = self.newReflectSetCall(self.class_super, propertyName, paramName, self.class_this);
                const expression = self.newAssignmentTargetWrapper(paramName, setCall);
                return expression;
            }
        }

        return v.visitEachChild(node);
    }

    fn visitAssignmentElement(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        const ec = self.transformer.emitContext;

        if (ast_utils.isDestructuringAssignment(tree, node)) {
            var bin = tree.getNode(node).BinaryExpression;
            if (isNamedEvaluationAnd(ec, node, isAnonymousClassNeedingAssignedName)) {
                const finalNode = self.transformNamedEvaluation(ec, node, canIgnoreEmptyStringLiteralInAssignedName(tree, bin.Right), "");
                bin = tree.getNode(finalNode).BinaryExpression;
            }
            const assignmentTarget = self.visitDestructuringAssignmentTarget(v, bin.Left);
            const initializer = v.visitNode(bin.Right);
            return f.newBinaryExpression(0, assignmentTarget, 0, bin.OperatorToken, initializer);
        }
        return self.visitDestructuringAssignmentTarget(v, node);
    }

    fn visitAssignmentRestElement(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        const se = tree.getNode(node).SpreadElement;
        const expression = self.visitDestructuringAssignmentTarget(v, se.Expression);
        return f.newSpreadElement(expression);
    }

    fn visitAssignmentPropertyNode(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        const pa = tree.getNode(node).PropertyAssignment;
        const name = v.visitNode(pa.name);
        if (ast_utils.isDestructuringAssignment(tree, pa.Initializer)) {
            const assignmentElement = self.visitAssignmentElement(v, pa.Initializer);
            return f.newPropertyAssignment(0, name, 0, 0, assignmentElement);
        }
        const assignmentElement = self.visitDestructuringAssignmentTarget(v, pa.Initializer);
        return f.newPropertyAssignment(0, name, 0, 0, assignmentElement);
    }

    fn visitShorthandAssignmentProperty(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const ec = self.transformer.emitContext;
        var finalNode = node;
        if (isNamedEvaluationAnd(ec, finalNode, isAnonymousClassNeedingAssignedName)) {
            const cpn = v.tree.getNode(finalNode).ShorthandPropertyAssignment;
            finalNode = self.transformNamedEvaluation(ec, finalNode, canIgnoreEmptyStringLiteralInAssignedName(v.tree, cpn.ObjectAssignmentInitializer orelse 0), "");
        }
        return v.visitEachChild(finalNode);
    }

    fn visitAssignmentRestProperty(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        const sa = tree.getNode(node).SpreadAssignment;
        const expression = self.visitDestructuringAssignmentTarget(v, sa.Expression);
        return f.newSpreadAssignment(expression);
    }

    fn visitAssignmentPattern(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        const nodeKind = tree.getNodeKind(node);
        if (nodeKind == .ArrayLiteralExpression) {
            const ale = tree.getNode(node).ArrayLiteralExpression;
            var array_visitor = visitor.NodeVisitor.init(self.allocator, tree, self, visitArrayAssignmentElement, .{});
            const elements = array_visitor.visitNodes(ale.Elements);
            return f.newArrayLiteralExpression(elements, ale.MultiLine != 0);
        }
        const ole = tree.getNode(node).ObjectLiteralExpression;
        var object_visitor = visitor.NodeVisitor.init(self.allocator, tree, self, visitObjectAssignmentElement, .{});
        const properties = object_visitor.visitNodes(ole.Properties);
        return f.newObjectLiteralExpression(properties, false);
    }

    fn visitBinaryExpression(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex, discarded: bool) ast_gen.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        const ec = self.transformer.emitContext;
        const bin = tree.getNode(node).BinaryExpression;

        if (ast_utils.isDestructuringAssignment(tree, node)) {
            const left = self.visitAssignmentPattern(v, bin.Left);
            const right = v.visitNode(bin.Right);
            return f.newBinaryExpression(0, left, 0, bin.OperatorToken, right);
        }

        const opKind = tree.getNodeKind(bin.OperatorToken);
        if (opKind == .EqualsToken or opKind == .AmpersandAmpersandEqualsToken or opKind == .BarBarEqualsToken or opKind == .QuestionQuestionEqualsToken) {
            if (isNamedEvaluationAnd(ec, node, isAnonymousClassNeedingAssignedName)) {
                const finalNode = self.transformNamedEvaluation(ec, node, canIgnoreEmptyStringLiteralInAssignedName(tree, bin.Right), "");
                return v.visitEachChild(finalNode);
            }

            if (isSuperProperty(tree, bin.Left) and self.class_this != 0 and self.class_super != 0) {
                var setterName: ast_gen.NodeIndex = 0;
                const leftKind = tree.getNodeKind(bin.Left);
                if (leftKind == .ElementAccessExpression) {
                    setterName = v.visitNode(tree.getNode(bin.Left).ElementAccessExpression.ArgumentExpression);
                } else if (leftKind == .PropertyAccessExpression) {
                    const pa = tree.getNode(bin.Left).PropertyAccessExpression;
                    if (ast_utils.isIdentifier(tree, pa.name)) {
                        setterName = f.newStringLiteralFromNode(pa.name) catch unreachable;
                    }
                }

                if (setterName != 0) {
                    var expression = v.visitNode(bin.Right);
                    if (opKind != .EqualsToken) {
                        var getterName = setterName;
                        if (!isSimpleInlineableExpression(tree, setterName)) {
                            getterName = f.createTempVariable() catch unreachable;
                            ec.addVariableDeclaration(getterName);
                            setterName = f.newAssignmentExpression(getterName, setterName);
                        }
                        const superPropertyGet = self.newReflectGetCall(self.class_super, getterName, self.class_this);
                        const op = switch (opKind) {
                            .AmpersandAmpersandEqualsToken => f.newToken(.{ .AmpersandAmpersandToken = {} }),
                            .BarBarEqualsToken => f.newToken(.{ .BarBarToken = {} }),
                            .QuestionQuestionEqualsToken => f.newToken(.{ .QuestionQuestionToken = {} }),
                            else => unreachable,
                        };
                        expression = f.newBinaryExpression(0, superPropertyGet, 0, op, expression);
                    }

                    var temp: ast_gen.NodeIndex = 0;
                    if (!discarded) {
                        temp = f.createTempVariable() catch unreachable;
                        ec.addVariableDeclaration(temp);
                    }

                    if (temp != 0) {
                        expression = f.newAssignmentExpression(temp, expression);
                    }

                    expression = self.newReflectSetCall(self.class_super, setterName, expression, self.class_this);

                    if (temp != 0) {
                        expression = self.newCommaExpression(expression, temp);
                    }
                    return expression;
                }
            }
        }

        if (opKind == .CommaToken) {
            var discarded_visitor = visitor.NodeVisitor.init(self.allocator, tree, self, visitDiscardedValue, .{});
            const left = discarded_visitor.visitNode(bin.Left);
            const right = if (discarded) discarded_visitor.visitNode(bin.Right) else v.visitNode(bin.Right);
            return f.updateBinaryExpression(node, 0, left, 0, bin.OperatorToken, right);
        }

        return v.visitEachChild(node);
    }

    fn partialTransformClassElement(
        self: *ESDecoratorTransformer,
        v: *visitor.NodeVisitor,
        member: ast_gen.NodeIndex,
        ci: ?*ClassInfo,
        createDescriptor: ?*const fn (*ESDecoratorTransformer, ast_gen.NodeIndex, ast_gen.NodeIndex) ast_gen.NodeIndex,
    ) PartialResult {
        const tree = v.tree;
        const f = self.transformer.factory;

        if (ci == null) {
            var modifier_visitor = visitor.NodeVisitor.init(self.allocator, tree, self, visitModifier, .{});
            const modifiersList = ast_utils.getModifiers(tree, member) orelse 0;
            const modifiers = modifier_visitor.visitModifiers(modifiersList);
            self.enterName();
            const name = self.visitPropertyName(v, ast_utils.getNameOfNode(tree, member));
            self.exitName();
            return .{ .modifiers = modifiers, .name = name };
        }

        const decorators = getDecoratorsOfNode(tree, member);
        const memberDecorators = self.transformAllDecoratorsOfDeclaration(v, decorators);
        var modifier_visitor = visitor.NodeVisitor.init(self.allocator, tree, self, visitModifier, .{});
        const modifiersList = ast_utils.getModifiers(tree, member) orelse 0;
        const modifiers = modifier_visitor.visitModifiers(modifiersList);

        var result = PartialResult{ .modifiers = modifiers };

        if (memberDecorators.len > 0) {
            const memberDecoratorsName = self.createHelperVariable(member, "decorators");
            const memberDecoratorsArray = f.newArrayLiteralExpression(f.newNodeList(memberDecorators), false);
            const memberDecoratorsAssignment = f.newAssignmentExpression(memberDecoratorsName, memberDecoratorsArray);

            var mi = MemberInfo{ .memberDecoratorsName = memberDecoratorsName };

            self.pending_expressions.append(self.allocator, memberDecoratorsAssignment) catch unreachable;

            var kind_str: []const u8 = "";
            const nodeKind = tree.getNodeKind(member);
            switch (nodeKind) {
                .GetAccessor => kind_str = "getter",
                .SetAccessor => kind_str = "setter",
                .MethodDeclaration => kind_str = "method",
                .PropertyDeclaration => {
                    if (ast_utils.hasAccessorModifier(tree, member)) {
                        kind_str = "accessor";
                    } else {
                        kind_str = "field";
                    }
                },
                else => unreachable,
            }

            var propertyNameComputed = false;
            var propertyNameExpr: ast_gen.NodeIndex = 0;
            const nameNode = ast_utils.getNameOfNode(tree, member);
            const nameKind = tree.getNodeKind(nameNode);
            if (nameNode != 0 and (nameKind == .Identifier or nameKind == .PrivateIdentifier)) {
                propertyNameComputed = false;
                propertyNameExpr = nameNode;
            } else if (nameNode != 0 and nameKind == .ComputedPropertyName) {
                const cpn = tree.getNode(nameNode).ComputedPropertyName;
                if (ast_utils.isStringLiteral(tree, cpn.Expression) or ast_utils.isNumericLiteral(tree, cpn.Expression)) {
                    propertyNameComputed = true;
                    propertyNameExpr = f.newStringLiteralFromNode(cpn.Expression) catch unreachable;
                } else {
                    self.enterName();
                    const pair = self.visitReferencedPropertyName(v, nameNode);
                    self.exitName();
                    result.referencedName = pair.referenced;
                    result.name = pair.name;
                    propertyNameComputed = true;
                    propertyNameExpr = result.referencedName;
                }
            } else if (nameNode != 0) {
                propertyNameComputed = true;
                propertyNameExpr = f.newStringLiteralFromNode(nameNode) catch unreachable;
            }

            const isStatic = ast_utils.isStatic(tree, member);
            const isPrivate = nameNode != 0 and nameKind == .PrivateIdentifier;
            const hasGet = nodeKind == .PropertyDeclaration or nodeKind == .GetAccessor or nodeKind == .MethodDeclaration;
            const hasSet = nodeKind == .PropertyDeclaration or nodeKind == .SetAccessor;

            const contextObj = self.newESDecorateClassElementContextObject(
                kind_str,
                propertyNameComputed,
                propertyNameExpr,
                isStatic,
                isPrivate,
                hasGet,
                hasSet,
                ci.?.metadataReference,
            );

            const isMethodOrAccessor = nodeKind == .MethodDeclaration or nodeKind == .GetAccessor or nodeKind == .SetAccessor;
            if (isMethodOrAccessor) {
                const methodExtraInitializersName = if (isStatic) ci.?.staticMethodExtraInitializersName else ci.?.instanceMethodExtraInitializersName;
                var descriptorArg: ast_gen.NodeIndex = 0;
                if (isPrivate and createDescriptor != null) {
                    var async_stripper = visitor.NodeVisitor.init(self.allocator, tree, self, visitAsyncOnlyModifier, .{});
                    const asyncMods = async_stripper.visitModifiers(modifiers);
                    const descriptor = createDescriptor.?(self, member, asyncMods);
                    mi.memberDescriptorName = self.createHelperVariable(member, "descriptor");
                    result.descriptorName = mi.memberDescriptorName;
                    descriptorArg = f.newAssignmentExpression(mi.memberDescriptorName, descriptor);
                } else {
                    descriptorArg = f.newToken(.{ .NullKeyword = {} });
                }

                const esDecorateExpr = self.newESDecorateHelper(
                    f.newToken(.{ .ThisKeyword = {} }),
                    descriptorArg,
                    memberDecoratorsName,
                    contextObj,
                    f.newToken(.{ .NullKeyword = {} }),
                    methodExtraInitializersName,
                );
                const esDecorateStatement = f.newExpressionStatement(esDecorateExpr);
                self.appendDecorationStatement(ci.?, member, esDecorateStatement);
            } else if (nodeKind == .PropertyDeclaration) {
                mi.memberInitializersName = self.createHelperVariable(member, "initializers");
                mi.memberExtraInitializersName = self.createHelperVariable(member, "extraInitializers");
                result.initializersName = mi.memberInitializersName;
                result.extraInitializersName = mi.memberExtraInitializersName;
                if (isStatic) {
                    result.thisArg = ci.?.classThis;
                }

                const ctorArg = if (ast_utils.hasAccessorModifier(tree, member))
                    f.newToken(.{ .ThisKeyword = {} })
                else
                    f.newToken(.{ .NullKeyword = {} });

                var descriptorArg: ast_gen.NodeIndex = 0;
                if (isPrivate and ast_utils.hasAccessorModifier(tree, member) and createDescriptor != null) {
                    const descriptor = createDescriptor.?(self, member, 0);
                    mi.memberDescriptorName = self.createHelperVariable(member, "descriptor");
                    result.descriptorName = mi.memberDescriptorName;
                    descriptorArg = f.newAssignmentExpression(mi.memberDescriptorName, descriptor);
                } else {
                    descriptorArg = f.newToken(.{ .NullKeyword = {} });
                }

                const esDecorateExpr = self.newESDecorateHelper(
                    ctorArg,
                    descriptorArg,
                    memberDecoratorsName,
                    contextObj,
                    mi.memberInitializersName,
                    mi.memberExtraInitializersName,
                );
                const esDecorateStatement = f.newExpressionStatement(esDecorateExpr);
                self.appendDecorationStatement(ci.?, member, esDecorateStatement);
            }

            ci.?.memberInfos.put(self.allocator, member, mi) catch unreachable;
        }

        if (result.name == 0) {
            self.enterName();
            result.name = self.visitPropertyName(v, ast_utils.getNameOfNode(tree, member));
            self.exitName();
        }

        return result;
    }

    fn appendDecorationStatement(self: *ESDecoratorTransformer, ci: *ClassInfo, member: ast_gen.NodeIndex, stmt: ast_gen.NodeIndex) void {
        const tree = self.transformer.emitContext.tree;
        const nodeKind = tree.getNodeKind(member);
        const isMethodOrAccessor = nodeKind == .MethodDeclaration or nodeKind == .GetAccessor or nodeKind == .SetAccessor;
        const isAutoAccessor = nodeKind == .PropertyDeclaration and ast_utils.hasAccessorModifier(tree, member);

        if (isMethodOrAccessor or isAutoAccessor) {
            if (ast_utils.isStatic(tree, member)) {
                ci.staticNonFieldDecorationStatements.append(self.allocator, stmt) catch unreachable;
            } else {
                ci.nonStaticNonFieldDecorationStatements.append(self.allocator, stmt) catch unreachable;
            }
        } else if (nodeKind == .PropertyDeclaration) {
            if (ast_utils.isStatic(tree, member)) {
                ci.staticFieldDecorationStatements.append(self.allocator, stmt) catch unreachable;
            } else {
                ci.nonStaticFieldDecorationStatements.append(self.allocator, stmt) catch unreachable;
            }
        }
    }

    fn visitPropertyName(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        if (v.tree.getNodeKind(node) == .ComputedPropertyName) {
            return self.visitComputedPropertyName(v, node);
        }
        return v.visitNode(node);
    }

    fn visitReferencedPropertyName(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) struct { referenced: ast_gen.NodeIndex, name: ast_gen.NodeIndex } {
        const tree = v.tree;
        const f = self.transformer.factory;
        const ec = self.transformer.emitContext;
        const nodeKind = tree.getNodeKind(node);

        if (nodeKind != .ComputedPropertyName) {
            return .{ .referenced = f.newStringLiteralFromNode(node) catch unreachable, .name = v.visitNode(node) };
        }

        const cpn = tree.getNode(node).ComputedPropertyName;
        const cpnExprKind = tree.getNodeKind(cpn.Expression);
        if (cpnExprKind != .Identifier and (ast_utils.isStringLiteral(tree, cpn.Expression) or ast_utils.isNumericLiteral(tree, cpn.Expression))) {
            return .{ .referenced = f.newStringLiteralFromNode(cpn.Expression) catch unreachable, .name = v.visitNode(node) };
        }

        const referencedName = f.newUniqueName("_property_name");
        ec.addVariableDeclaration(referencedName);

        ec.requestEmitHelper(&helpers.propKeyHelper);
        const key = f.newCallExpression(
            f.newIdentifier("__propKey"),
            0,
            0,
            f.newNodeList(&[_]ast_gen.NodeIndex{v.visitNode(cpn.Expression)}),
            0,
        );

        const assignment = f.newAssignmentExpression(referencedName, key);
        const updatedName = f.updateComputedPropertyName(node, self.injectPendingExpressions(assignment));
        return .{ .referenced = referencedName, .name = updatedName };
    }

    fn transformAllDecoratorsOfDeclaration(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, decorators: []const ast_gen.NodeIndex) []const ast_gen.NodeIndex {
        if (decorators.len == 0) return &[_]ast_gen.NodeIndex{};
        var result = std.ArrayList(ast_gen.NodeIndex).empty;
        for (decorators) |d| {
            result.append(self.allocator, self.transformDecorator(v, d)) catch unreachable;
        }
        return self.allocator.dupe(ast_gen.NodeIndex, result.items) catch unreachable;
    }

    fn transformDecorator(self: *ESDecoratorTransformer, v: *visitor.NodeVisitor, decorator: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        const dec = tree.getNode(decorator).Decorator;
        const expression = v.visitNode(dec.Expression);

        const innerExpression = skipOuterExpressions(tree, expression);
        const innerKind = tree.getNodeKind(innerExpression);
        const isAccess = innerKind == .PropertyAccessExpression or innerKind == .ElementAccessExpression;
        if (isAccess) {
            const pair = self.createCallBinding(expression);
            const bind_kw = f.newIdentifier("bind");
            const bindAccess = f.newPropertyAccessExpression(pair.target, 0, bind_kw, 0);
            const bindCall = f.newCallExpression(bindAccess, 0, 0, f.newNodeList(&[_]ast_gen.NodeIndex{pair.thisArg}), 0);
            return bindCall;
        }
        return expression;
    }

    fn createCallBinding(self: *ESDecoratorTransformer, expression: ast_gen.NodeIndex) struct { target: ast_gen.NodeIndex, thisArg: ast_gen.NodeIndex } {
        const f = self.transformer.factory;
        const tree = self.transformer.emitContext.tree;
        const ec = self.transformer.emitContext;
        const callee = skipOuterExpressions(tree, expression);
        const calleeKind = tree.getNodeKind(callee);

        if (calleeKind == .SuperKeyword) {
            return .{ .target = callee, .thisArg = f.newToken(.{ .ThisKeyword = {} }) };
        }
        if (calleeKind == .PropertyAccessExpression) {
            const pa = tree.getNode(callee).PropertyAccessExpression;
            if (self.shouldBeCapturedInTempVariable(pa.Expression)) {
                const thisArg = f.createTempVariable() catch unreachable;
                ec.addVariableDeclaration(thisArg);
                const assign = f.newAssignmentExpression(thisArg, pa.Expression);
                const target = f.newPropertyAccessExpression(assign, 0, pa.name, 0);
                return .{ .target = target, .thisArg = thisArg };
            }
            return .{ .target = callee, .thisArg = pa.Expression };
        }
        if (calleeKind == .ElementAccessExpression) {
            const ea = tree.getNode(callee).ElementAccessExpression;
            if (self.shouldBeCapturedInTempVariable(ea.Expression)) {
                const thisArg = f.createTempVariable() catch unreachable;
                ec.addVariableDeclaration(thisArg);
                const assign = f.newAssignmentExpression(thisArg, ea.Expression);
                const target = f.newElementAccessExpression(assign, 0, ea.ArgumentExpression, 0);
                return .{ .target = target, .thisArg = thisArg };
            }
            return .{ .target = callee, .thisArg = ea.Expression };
        }
        return .{ .target = expression, .thisArg = f.newVoidZeroExpression() };
    }

    fn shouldBeCapturedInTempVariable(self: *ESDecoratorTransformer, node: ast_gen.NodeIndex) bool {
        _ = self;
        _ = node;
        return true;
    }

    fn createDescriptorMethod(
        self: *ESDecoratorTransformer,
        original: ast_gen.NodeIndex,
        name: ast_gen.NodeIndex,
        modifiers: ast_gen.NodeIndex,
        asteriskToken: ast_gen.NodeIndex,
        kind_str: []const u8,
        parameters: ast_gen.NodeIndex,
        body: ast_gen.NodeIndex,
    ) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const ec = self.transformer.emitContext;

        const finalBody = if (body == 0) f.newBlock(f.newNodeList(&[_]ast_gen.NodeIndex{}), false) else body;
        const funcExpr = f.newFunctionExpression(
            modifiers,
            asteriskToken,
            0,
            0,
            parameters,
            0,
            0,
            finalBody,
        );
        ec.setOriginal(funcExpr, original) catch {};

        const functionName = f.newStringLiteralFromNode(name) catch unreachable;
        const namedFunction = self.newSetFunctionNameHelper(funcExpr, functionName, kind_str);

        const method = f.newPropertyAssignment(0, f.newIdentifier(kind_str), 0, 0, namedFunction);
        ec.setOriginal(method, original) catch {};
        return method;
    }

    fn createMethodDescriptorObject(self: *ESDecoratorTransformer, member: ast_gen.NodeIndex, modifiers: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const tree = self.transformer.emitContext.tree;
        const method = tree.getNode(member).MethodDeclaration;
        const parameters = self.transformer.visitor.visitNodes(method.Parameters);
        const body = self.transformer.visitor.visitNode(method.Body orelse 0);

        const descMethod = self.createDescriptorMethod(member, ast_utils.getNameOfNode(tree, member), modifiers, method.AsteriskToken orelse 0, "value", parameters, body);
        return f.newObjectLiteralExpression(f.newNodeList(&[_]ast_gen.NodeIndex{descMethod}), false);
    }

    fn createGetAccessorDescriptorObject(self: *ESDecoratorTransformer, member: ast_gen.NodeIndex, modifiers: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const tree = self.transformer.emitContext.tree;
        const accessor = tree.getNode(member).GetAccessor;
        const body = self.transformer.visitor.visitNode(accessor.Body orelse 0);

        const descMethod = self.createDescriptorMethod(member, ast_utils.getNameOfNode(tree, member), modifiers, 0, "get", f.newNodeList(&[_]ast_gen.NodeIndex{}), body);
        return f.newObjectLiteralExpression(f.newNodeList(&[_]ast_gen.NodeIndex{descMethod}), false);
    }

    fn createSetAccessorDescriptorObject(self: *ESDecoratorTransformer, member: ast_gen.NodeIndex, modifiers: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const tree = self.transformer.emitContext.tree;
        const accessor = tree.getNode(member).SetAccessor;
        const parameters = self.transformer.visitor.visitNodes(accessor.Parameters);
        const body = self.transformer.visitor.visitNode(accessor.Body orelse 0);

        const descMethod = self.createDescriptorMethod(member, ast_utils.getNameOfNode(tree, member), modifiers, 0, "set", parameters, body);
        return f.newObjectLiteralExpression(f.newNodeList(&[_]ast_gen.NodeIndex{descMethod}), false);
    }

    fn createAccessorPropertyDescriptorObject(self: *ESDecoratorTransformer, member: ast_gen.NodeIndex, modifiers: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = modifiers;
        const f = self.transformer.factory;
        const backingFieldName = f.newUniqueName("_accessor_storage");

        const getBody = f.newBlock(f.newNodeList(&[_]ast_gen.NodeIndex{
            f.newReturnStatement(f.newPropertyAccessExpression(f.newToken(.{ .ThisKeyword = {} }), 0, backingFieldName, 0)),
        }), false);
        const getMethod = self.createDescriptorMethod(member, ast_utils.getNameOfNode(f.tree, member), 0, 0, "get", f.newNodeList(&[_]ast_gen.NodeIndex{}), getBody);

        const setBody = f.newBlock(f.newNodeList(&[_]ast_gen.NodeIndex{
            f.newExpressionStatement(f.newAssignmentExpression(
                f.newPropertyAccessExpression(f.newToken(.{ .ThisKeyword = {} }), 0, backingFieldName, 0),
                f.newIdentifier("value"),
            )),
        }), false);
        const setParam = f.newParameterDeclaration(0, 0, f.newIdentifier("value"), 0, 0, 0);
        const setMethod = self.createDescriptorMethod(member, ast_utils.getNameOfNode(f.tree, member), 0, 0, "set", f.newNodeList(&[_]ast_gen.NodeIndex{setParam}), setBody);

        return f.newObjectLiteralExpression(f.newNodeList(&[_]ast_gen.NodeIndex{ getMethod, setMethod }), false);
    }

    fn createMethodDescriptorForwarder(self: *ESDecoratorTransformer, modifiers: ast_gen.NodeIndex, name: ast_gen.NodeIndex, descriptorName: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        var static_visitor = visitor.NodeVisitor.init(self.allocator, f.tree, self, visitStaticOnlyModifier, .{});
        const staticOnly = static_visitor.visitModifiers(modifiers);

        const body = f.newBlock(f.newNodeList(&[_]ast_gen.NodeIndex{
            f.newReturnStatement(f.newPropertyAccessExpression(descriptorName, 0, f.newIdentifier("value"), 0)),
        }), false);
        return f.newGetAccessorDeclaration(
            staticOnly,
            name,
            0,
            f.newNodeList(&[_]ast_gen.NodeIndex{}),
            body,
        );
    }

    fn createGetAccessorDescriptorForwarder(self: *ESDecoratorTransformer, modifiers: ast_gen.NodeIndex, name: ast_gen.NodeIndex, descriptorName: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        var static_visitor = visitor.NodeVisitor.init(self.allocator, f.tree, self, visitStaticOnlyModifier, .{});
        const staticOnly = static_visitor.visitModifiers(modifiers);

        const getCall = f.newCallExpression(
            f.newPropertyAccessExpression(descriptorName, 0, f.newIdentifier("get"), 0),
            0,
            0,
            f.newNodeList(&[_]ast_gen.NodeIndex{f.newToken(.{ .ThisKeyword = {} })}),
            0,
        );
        const body = f.newBlock(f.newNodeList(&[_]ast_gen.NodeIndex{
            f.newReturnStatement(getCall),
        }), false);
        return f.newGetAccessorDeclaration(
            staticOnly,
            name,
            0,
            f.newNodeList(&[_]ast_gen.NodeIndex{}),
            body,
        );
    }

    fn createSetAccessorDescriptorForwarder(self: *ESDecoratorTransformer, modifiers: ast_gen.NodeIndex, name: ast_gen.NodeIndex, descriptorName: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        var static_visitor = visitor.NodeVisitor.init(self.allocator, f.tree, self, visitStaticOnlyModifier, .{});
        const staticOnly = static_visitor.visitModifiers(modifiers);

        const setCall = f.newCallExpression(
            f.newPropertyAccessExpression(descriptorName, 0, f.newIdentifier("set"), 0),
            0,
            0,
            f.newNodeList(&[_]ast_gen.NodeIndex{ f.newToken(.{ .ThisKeyword = {} }), f.newIdentifier("value") }),
            0,
        );
        const body = f.newBlock(f.newNodeList(&[_]ast_gen.NodeIndex{
            f.newExpressionStatement(setCall),
        }), false);
        const param = f.newParameterDeclaration(0, 0, f.newIdentifier("value"), 0, 0, 0);
        return f.newSetAccessorDeclaration(
            staticOnly,
            name,
            f.newNodeList(&[_]ast_gen.NodeIndex{param}),
            body,
        );
    }

    fn createAccessorPropertyBackingField(self: *ESDecoratorTransformer, member: ast_gen.NodeIndex, modifiers: ast_gen.NodeIndex, initializer: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = member;
        const f = self.transformer.factory;
        const backingFieldName = f.newUniqueName("_accessor_storage");
        return f.newPropertyDeclaration(
            modifiers,
            backingFieldName,
            0,
            0,
            initializer,
        );
    }

    fn createHelperVariable(self: *ESDecoratorTransformer, node: ast_gen.NodeIndex, suffix: []const u8) ast_gen.NodeIndex {
        const ec = self.transformer.emitContext;
        const prefix = getHelperVariableName(ec, node);
        const text = std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ prefix, suffix }) catch unreachable;
        defer self.allocator.free(text);
        return self.transformer.factory.newUniqueName(text);
    }

    fn createLet(self: *ESDecoratorTransformer, name: ast_gen.NodeIndex, initializer: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const decl = f.newVariableDeclaration(name, 0, 0, initializer);
        const declList = f.newVariableDeclarationList(f.newNodeList(&[_]ast_gen.NodeIndex{decl}), ast_utils.NodeFlags.Let);
        return f.newVariableStatement(0, declList);
    }

    fn createMetadata(self: *ESDecoratorTransformer, name: ast_gen.NodeIndex, classSuper: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;

        const superMetadata = if (classSuper != 0)
            self.createSymbolMetadataReference(classSuper)
        else
            f.newToken(.{ .NullKeyword = {} });

        const objectCreate = f.newCallExpression(
            f.newPropertyAccessExpression(f.newIdentifier("Object"), 0, f.newIdentifier("create"), 0),
            0,
            0,
            f.newNodeList(&[_]ast_gen.NodeIndex{superMetadata}),
            0,
        );

        const symbolCheck = f.newBinaryExpression(
            0,
            f.newTypeCheck(f.newIdentifier("Symbol"), "function"),
            0,
            f.newToken(.{ .AmpersandAmpersandToken = {} }),
            f.newPropertyAccessExpression(f.newIdentifier("Symbol"), 0, f.newIdentifier("metadata"), 0),
        );

        const conditional = f.newConditionalExpression(
            symbolCheck,
            f.newToken(.{ .QuestionToken = {} }),
            objectCreate,
            f.newToken(.{ .ColonToken = {} }),
            f.newVoidZeroExpression(),
        );

        const varDecl = f.newVariableDeclaration(name, 0, 0, conditional);
        const varDeclList = f.newVariableDeclarationList(f.newNodeList(&[_]ast_gen.NodeIndex{varDecl}), ast_utils.NodeFlags.Const);
        return f.newVariableStatement(0, varDeclList);
    }

    fn createSymbolMetadata(self: *ESDecoratorTransformer, target: ast_gen.NodeIndex, value: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;

        const symbolMetadata = f.newPropertyAccessExpression(f.newIdentifier("Symbol"), 0, f.newIdentifier("metadata"), 0);
        const descriptorProps = &[_]ast_gen.NodeIndex{
            f.newPropertyAssignment(0, f.newIdentifier("enumerable"), 0, 0, f.newTrueExpression()),
            f.newPropertyAssignment(0, f.newIdentifier("configurable"), 0, 0, f.newTrueExpression()),
            f.newPropertyAssignment(0, f.newIdentifier("writable"), 0, 0, f.newTrueExpression()),
            f.newPropertyAssignment(0, f.newIdentifier("value"), 0, 0, value),
        };
        const descriptor = f.newObjectLiteralExpression(f.newNodeList(descriptorProps), false);

        const defineProperty = f.newCallExpression(
            f.newPropertyAccessExpression(f.newIdentifier("Object"), 0, f.newIdentifier("defineProperty"), 0),
            0,
            0,
            f.newNodeList(&[_]ast_gen.NodeIndex{ target, symbolMetadata, descriptor }),
            0,
        );

        const ifStatement = f.newIfStatement(value, f.newExpressionStatement(defineProperty), 0);
        var data = f.tree.getNode(ifStatement).IfStatement;
        data.Flags |= 1 << 31;
        return f.tree.pushNode(.{ .IfStatement = data }) catch unreachable;
    }

    fn createSymbolMetadataReference(self: *ESDecoratorTransformer, classSuper: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const symbolMetadata = f.newPropertyAccessExpression(f.newIdentifier("Symbol"), 0, f.newIdentifier("metadata"), 0);
        const elementAccess = f.newElementAccessExpression(classSuper, 0, symbolMetadata, 0);
        return f.newBinaryExpression(0, elementAccess, 0, f.newToken(.{ .QuestionQuestionToken = {} }), f.newToken(.{ .NullKeyword = {} }));
    }

    fn injectClassThisAssignmentIfMissing(self: *ESDecoratorTransformer, node: ast_gen.NodeIndex, classThis: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const ec = self.transformer.emitContext;
        const f = self.transformer.factory;
        const tree = f.tree;

        if (classHasClassThisAssignment(ec, node)) {
            return node;
        }

        const expression = f.newAssignmentExpression(classThis, f.newToken(.{ .ThisKeyword = {} }));
        const statement = f.newExpressionStatement(expression);
        const body = f.newBlock(f.newNodeList(&[_]ast_gen.NodeIndex{statement}), false);
        const staticBlock = f.newClassStaticBlockDeclaration(0, body);
        ec.setClassThis(staticBlock, classThis) catch {};

        const data = tree.getNode(node);
        const members_list = switch (tree.getNodeKind(node)) {
            .ClassDeclaration => data.ClassDeclaration.Members,
            .ClassExpression => data.ClassExpression.Members,
            else => unreachable,
        };

        var newMembers = std.ArrayList(ast_gen.NodeIndex).empty;
        defer newMembers.deinit(self.allocator);
        newMembers.append(self.allocator, staticBlock) catch unreachable;
        newMembers.appendSlice(self.allocator, tree.getNodeList(members_list)) catch unreachable;

        const membersList = f.newNodeList(newMembers.items);

        var updatedNode: ast_gen.NodeIndex = 0;
        if (tree.getNodeKind(node) == .ClassDeclaration) {
            updatedNode = f.updateClassDeclaration(
                node,
                data.ClassDeclaration,
                data.ClassDeclaration.modifiers orelse 0,
                data.ClassDeclaration.name orelse 0,
                data.ClassDeclaration.TypeParameters orelse 0,
                data.ClassDeclaration.HeritageClauses orelse 0,
                membersList,
            );
        } else {
            updatedNode = f.updateClassExpression(
                node,
                data.ClassExpression,
                data.ClassExpression.modifiers orelse 0,
                data.ClassExpression.name orelse 0,
                data.ClassExpression.TypeParameters orelse 0,
                data.ClassExpression.HeritageClauses orelse 0,
                membersList,
            );
        }
        ec.setClassThis(updatedNode, classThis) catch {};
        return updatedNode;
    }

    fn injectClassNamedEvaluationHelperBlockIfMissing(self: *ESDecoratorTransformer, node: ast_gen.NodeIndex, assignedName: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const ec = self.transformer.emitContext;
        const f = self.transformer.factory;
        const tree = f.tree;

        if (classHasExplicitlyAssignedName(ec, node)) {
            return node;
        }

        const namedEvaluationBlock = self.createClassNamedEvaluationHelperBlock(assignedName);

        const data = tree.getNode(node);
        const members_list = switch (tree.getNodeKind(node)) {
            .ClassDeclaration => data.ClassDeclaration.Members,
            .ClassExpression => data.ClassExpression.Members,
            else => unreachable,
        };

        const membersSlice = tree.getNodeList(members_list);
        var insertionIndex: usize = 0;
        for (membersSlice, 0..) |m, i| {
            if (isClassThisAssignmentBlock(ec, m)) {
                insertionIndex = i + 1;
                break;
            }
        }

        var newMembers = std.ArrayList(ast_gen.NodeIndex).empty;
        defer newMembers.deinit(self.allocator);
        newMembers.appendSlice(self.allocator, membersSlice[0..insertionIndex]) catch unreachable;
        newMembers.append(self.allocator, namedEvaluationBlock) catch unreachable;
        newMembers.appendSlice(self.allocator, membersSlice[insertionIndex..]) catch unreachable;

        const membersList = f.newNodeList(newMembers.items);

        var updatedNode: ast_gen.NodeIndex = 0;
        const oldNode = node;
        if (tree.getNodeKind(node) == .ClassDeclaration) {
            updatedNode = f.updateClassDeclaration(
                node,
                data.ClassDeclaration,
                data.ClassDeclaration.modifiers orelse 0,
                data.ClassDeclaration.name orelse 0,
                data.ClassDeclaration.TypeParameters orelse 0,
                data.ClassDeclaration.HeritageClauses orelse 0,
                membersList,
            );
        } else {
            updatedNode = f.updateClassExpression(
                node,
                data.ClassExpression,
                data.ClassExpression.modifiers orelse 0,
                data.ClassExpression.name orelse 0,
                data.ClassExpression.TypeParameters orelse 0,
                data.ClassExpression.HeritageClauses orelse 0,
                membersList,
            );
        }

        ec.setAssignedName(updatedNode, assignedName) catch {};
        const oldCt = ec.getClassThis(oldNode);
        if (oldCt != 0) {
            ec.setClassThis(updatedNode, oldCt) catch {};
        }

        return updatedNode;
    }

    fn createClassNamedEvaluationHelperBlock(self: *ESDecoratorTransformer, assignedName: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const ec = self.transformer.emitContext;

        const thisExpression = f.newToken(.{ .ThisKeyword = {} });
        const expression = self.newSetFunctionNameHelper(thisExpression, assignedName, "");
        const statement = f.newExpressionStatement(expression);
        const body = f.newBlock(f.newNodeList(&[_]ast_gen.NodeIndex{statement}), false);
        const block = f.newClassStaticBlockDeclaration(0, body);

        ec.setAssignedName(block, assignedName) catch {};
        return block;
    }

    fn transformNamedEvaluation(self: *ESDecoratorTransformer, ec: *emitcontext.EmitContext, node: ast_gen.NodeIndex, ignoreEmptyStringLiteral: bool, assignedNameText: []const u8) ast_gen.NodeIndex {
        const tree = ec.tree;
        const f = self.transformer.factory;
        const nodeKind = tree.getNodeKind(node);

        if (nodeKind == .PropertyAssignment) {
            const pa = tree.getNode(node).PropertyAssignment;
            const pair = self.getAssignedNameOfPropertyName(pa.name, assignedNameText);
            const initializer = self.finishTransformNamedEvaluation(pa.Initializer, pair.assignedName, ignoreEmptyStringLiteral);
            return f.newPropertyAssignment(0, pair.name, 0, 0, initializer);
        } else if (nodeKind == .ShorthandPropertyAssignment) {
            const spa = tree.getNode(node).ShorthandPropertyAssignment;
            var assignedName: ast_gen.NodeIndex = 0;
            if (assignedNameText.len > 0) {
                assignedName = f.newStringLiteral(assignedNameText, 0);
            } else {
                assignedName = f.newStringLiteralFromNode(spa.name) catch unreachable;
            }
            const initializer = self.finishTransformNamedEvaluation(spa.ObjectAssignmentInitializer orelse 0, assignedName, ignoreEmptyStringLiteral);
            return f.newPropertyAssignment(0, spa.name, 0, 0, initializer);
        } else if (nodeKind == .VariableDeclaration) {
            const vd = tree.getNode(node).VariableDeclaration;
            const assignedName = getAssignedNameOfIdentifier(ec, vd.name, vd.Initializer orelse 0);
            const initializer = self.finishTransformNamedEvaluation(vd.Initializer orelse 0, assignedName, ignoreEmptyStringLiteral);
            return f.newVariableDeclaration(vd.name, 0, 0, initializer);
        } else if (nodeKind == .Parameter) {
            const param = tree.getNode(node).Parameter;
            const assignedName = getAssignedNameOfIdentifier(ec, param.name, param.Initializer orelse 0);
            const initializer = self.finishTransformNamedEvaluation(param.Initializer orelse 0, assignedName, ignoreEmptyStringLiteral);
            return f.newParameterDeclaration(0, 0, param.name, 0, 0, initializer);
        } else if (nodeKind == .BindingElement) {
            const be = tree.getNode(node).BindingElement;
            const assignedName = getAssignedNameOfIdentifier(ec, be.name orelse 0, be.Initializer orelse 0);
            const initializer = self.finishTransformNamedEvaluation(be.Initializer orelse 0, assignedName, ignoreEmptyStringLiteral);
            return f.newBindingElement(0, be.PropertyName orelse 0, be.name orelse 0, initializer);
        }

        return node;
    }

    fn finishTransformNamedEvaluation(self: *ESDecoratorTransformer, expression: ast_gen.NodeIndex, assignedName: ast_gen.NodeIndex, ignoreEmptyStringLiteral: bool) ast_gen.NodeIndex {
        const tree = self.transformer.emitContext.tree;

        if (expression == 0) return 0;

        if (ignoreEmptyStringLiteral and ast_utils.isStringLiteral(tree, assignedName)) {
            const text = ast_utils.getTextOfNode(tree, assignedName);
            if (text.len == 0) {
                return expression;
            }
        }

        const innerExpression = skipOuterExpressions(tree, expression);
        var updatedExpression: ast_gen.NodeIndex = 0;
        if (tree.getNodeKind(innerExpression) == .ClassExpression) {
            updatedExpression = self.injectClassNamedEvaluationHelperBlockIfMissing(innerExpression, assignedName);
        } else {
            updatedExpression = self.newSetFunctionNameHelper(innerExpression, assignedName, "");
        }

        return self.restoreOuterExpressions(expression, updatedExpression);
    }

    fn getAssignedNameOfPropertyName(self: *ESDecoratorTransformer, name: ast_gen.NodeIndex, assignedNameText: []const u8) struct { assignedName: ast_gen.NodeIndex, name: ast_gen.NodeIndex } {
        const f = self.transformer.factory;
        const tree = f.tree;
        const ec = self.transformer.emitContext;

        if (assignedNameText.len > 0) {
            const assignedName = f.newStringLiteral(assignedNameText, 0);
            return .{ .assignedName = assignedName, .name = name };
        }

        const nameKind = tree.getNodeKind(name);
        if (isPropertyNameLiteral(tree, name) or nameKind == .PrivateIdentifier) {
            const assignedName = f.newStringLiteralFromNode(name) catch unreachable;
            return .{ .assignedName = assignedName, .name = name };
        }

        if (nameKind == .ComputedPropertyName) {
            const cpn = tree.getNode(name).ComputedPropertyName;
            if (isPropertyNameLiteral(tree, cpn.Expression) and tree.getNodeKind(cpn.Expression) != .Identifier) {
                const assignedName = f.newStringLiteralFromNode(cpn.Expression) catch unreachable;
                return .{ .assignedName = assignedName, .name = name };
            }

            const assignedName = f.newUniqueName("_property_name");
            ec.addVariableDeclaration(assignedName);

            ec.requestEmitHelper(&helpers.propKeyHelper);
            const key = f.newCallExpression(
                f.newIdentifier("__propKey"),
                0,
                0,
                f.newNodeList(&[_]ast_gen.NodeIndex{cpn.Expression}),
                0,
            );
            const assignment = f.newAssignmentExpression(assignedName, key);
            const updatedName = f.updateComputedPropertyName(name, assignment);
            return .{ .assignedName = assignedName, .name = updatedName };
        }

        return .{ .assignedName = 0, .name = name };
    }

    fn injectPendingExpressions(self: *ESDecoratorTransformer, expression: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const result = self.prependExpressions(self.pending_expressions.items, expression);
        if (result != expression) {
            self.pending_expressions.clearRetainingCapacity();
        }
        return result;
    }

    fn injectPendingInitializers(self: *ESDecoratorTransformer, ci: *ClassInfo, isStatic: bool, expression: ast_gen.NodeIndex) ast_gen.NodeIndex {
        var pending = if (isStatic) &ci.pendingStaticInitializers else &ci.pendingInstanceInitializers;
        const result = self.prependExpressions(pending.items, expression);
        if (result != expression) {
            pending.clearRetainingCapacity();
        }
        return result;
    }

    fn prependExpressions(self: *ESDecoratorTransformer, pending: []const ast_gen.NodeIndex, expression: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const tree = f.tree;
        if (pending.len == 0) {
            return expression;
        }
        if (expression == 0) {
            return f.inlineExpressions(pending);
        }

        const unwrapped = skipOuterExpressions(tree, expression);
        if (tree.getNodeKind(unwrapped) == .ParenthesizedExpression) {
            const pe = tree.getNode(unwrapped).ParenthesizedExpression;
            var exprs = std.ArrayList(ast_gen.NodeIndex).empty;
            defer exprs.deinit(self.allocator);
            exprs.appendSlice(self.allocator, pending) catch unreachable;
            exprs.append(self.allocator, pe.Expression) catch unreachable;
            return f.newParenthesizedExpression(f.inlineExpressions(exprs.items));
        }

        var exprs = std.ArrayList(ast_gen.NodeIndex).empty;
        defer exprs.deinit(self.allocator);
        exprs.appendSlice(self.allocator, pending) catch unreachable;
        exprs.append(self.allocator, expression) catch unreachable;
        return f.inlineExpressions(exprs.items);
    }

    fn singleOrMany(self: *ESDecoratorTransformer, stmts: []const ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        if (stmts.len == 0) return 0;
        if (stmts.len == 1) return stmts[0];
        return f.newSyntaxList(stmts);
    }

    fn enterClass(self: *ESDecoratorTransformer, ci: ?*ClassInfo) void {
        const entry = self.allocator.create(LexicalEntry) catch unreachable;
        entry.* = .{
            .kind = .Class,
            .next = self.top,
            .classInfoData = ci,
            .savedPendingExpressions = self.pending_expressions,
        };
        self.pending_expressions = .empty;
        self.top = entry;
        self.updateState();
    }

    fn exitClass(self: *ESDecoratorTransformer) void {
        const entry = self.top orelse unreachable;
        std.debug.assert(entry.kind == .Class);
        self.pending_expressions = entry.savedPendingExpressions orelse .empty;
        self.top = entry.next;
        self.allocator.destroy(entry);
        self.updateState();
    }

    fn enterClassElement(self: *ESDecoratorTransformer, node: ast_gen.NodeIndex) void {
        const entry = self.allocator.create(LexicalEntry) catch unreachable;
        entry.* = .{
            .kind = .ClassElement,
            .next = self.top,
        };
        if (self.top != null and self.top.?.classInfoData != null) {
            const ci = self.top.?.classInfoData.?;
            const tree = self.transformer.emitContext.tree;
            const isStaticBlock = ast_utils.getKind(tree, node) == .ClassStaticBlockDeclaration;
            const isStaticProp = ast_utils.getKind(tree, node) == .PropertyDeclaration and ast_utils.isStatic(tree, node);
            if (isStaticBlock or isStaticProp) {
                entry.classThisData = ci.classThis;
                entry.classSuperData = ci.classSuper;
            }
        }
        self.top = entry;
        self.updateState();
    }

    fn exitClassElement(self: *ESDecoratorTransformer) void {
        const entry = self.top orelse unreachable;
        std.debug.assert(entry.kind == .ClassElement);
        self.top = entry.next;
        self.allocator.destroy(entry);
        self.updateState();
    }

    fn enterName(self: *ESDecoratorTransformer) void {
        const entry = self.allocator.create(LexicalEntry) catch unreachable;
        entry.* = .{
            .kind = .Name,
            .next = self.top,
        };
        self.top = entry;
        self.updateState();
    }

    fn exitName(self: *ESDecoratorTransformer) void {
        const entry = self.top orelse unreachable;
        std.debug.assert(entry.kind == .Name);
        self.top = entry.next;
        self.allocator.destroy(entry);
        self.updateState();
    }

    fn enterOther(self: *ESDecoratorTransformer) void {
        if (self.top != null and self.top.?.kind == .Other) {
            std.debug.assert(self.pending_expressions.items.len == 0);
            self.top.?.depth += 1;
        } else {
            const entry = self.allocator.create(LexicalEntry) catch unreachable;
            entry.* = .{
                .kind = .Other,
                .next = self.top,
                .savedPendingExpressions = self.pending_expressions,
            };
            self.pending_expressions = .empty;
            self.top = entry;
            self.updateState();
        }
    }

    fn exitOther(self: *ESDecoratorTransformer) void {
        const entry = self.top orelse unreachable;
        std.debug.assert(entry.kind == .Other);
        if (entry.depth > 0) {
            std.debug.assert(self.pending_expressions.items.len == 0);
            entry.depth -= 1;
        } else {
            self.pending_expressions = entry.savedPendingExpressions orelse .empty;
            self.top = entry.next;
            self.allocator.destroy(entry);
            self.updateState();
        }
    }

    fn updateState(self: *ESDecoratorTransformer) void {
        self.class_info_stack = null;
        self.class_this = 0;
        self.class_super = 0;
        const entry = self.top orelse return;
        switch (entry.kind) {
            .Class => {
                self.class_info_stack = entry.classInfoData;
            },
            .ClassElement => {
                if (entry.next) |next| {
                    self.class_info_stack = next.classInfoData;
                }
                self.class_this = entry.classThisData;
                self.class_super = entry.classSuperData;
            },
            .Name => {
                const parent = entry.next orelse return;
                const grandparent = parent.next orelse return;
                const ggparent = grandparent.next orelse return;
                if (ggparent.kind == .ClassElement) {
                    if (ggparent.next) |next| {
                        self.class_info_stack = next.classInfoData;
                    }
                    self.class_this = ggparent.classThisData;
                    self.class_super = ggparent.classSuperData;
                }
            },
            else => {},
        }
    }

    fn newReflectGetCall(self: *ESDecoratorTransformer, target: ast_gen.NodeIndex, propertyKey: ast_gen.NodeIndex, receiver: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const reflect = f.newIdentifier("Reflect");
        const get_kw = f.newIdentifier("get");
        const reflectGet = f.newPropertyAccessExpression(reflect, 0, get_kw, 0);
        return f.newCallExpression(
            reflectGet,
            0,
            0,
            f.newNodeList(&[_]ast_gen.NodeIndex{ target, propertyKey, receiver }),
            0,
        );
    }

    fn newReflectSetCall(self: *ESDecoratorTransformer, target: ast_gen.NodeIndex, propertyKey: ast_gen.NodeIndex, value: ast_gen.NodeIndex, receiver: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const reflect = f.newIdentifier("Reflect");
        const set_kw = f.newIdentifier("set");
        const reflectSet = f.newPropertyAccessExpression(reflect, 0, set_kw, 0);
        return f.newCallExpression(
            reflectSet,
            0,
            0,
            f.newNodeList(&[_]ast_gen.NodeIndex{ target, propertyKey, value, receiver }),
            0,
        );
    }

    fn restoreOuterExpressions(self: *ESDecoratorTransformer, outerExpression: ast_gen.NodeIndex, innerExpression: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = self.transformer.emitContext.tree;
        const f = self.transformer.factory;
        if (outerExpression == 0) return innerExpression;

        const nodeData = tree.getNode(outerExpression);
        switch (nodeData) {
            .ParenthesizedExpression => |pe| {
                const innerRestored = self.restoreOuterExpressions(pe.Expression, innerExpression);
                return f.newParenthesizedExpression(innerRestored);
            },
            .PartiallyEmittedExpression => |pe| {
                const innerRestored = self.restoreOuterExpressions(pe.Expression, innerExpression);
                return f.newPartiallyEmittedExpression(innerRestored);
            },
            else => return innerExpression,
        }
    }

    fn createClassInfo(self: *ESDecoratorTransformer, node: ast_gen.NodeIndex) !*ClassInfo {
        const f = self.transformer.factory;
        const tree = self.transformer.emitContext.tree;
        const ci = try self.allocator.create(ClassInfo);
        ci.* = .{
            .classNode = node,
            .metadataReference = f.newUniqueName("_metadata"),
        };

        if (ast_utils.nodeIsDecorated(tree, false, node, 0)) {
            const classNode = tree.getNode(node);
            const members_list = switch (tree.getNodeKind(node)) {
                .ClassDeclaration => classNode.ClassDeclaration.Members,
                .ClassExpression => classNode.ClassExpression.Members,
                else => unreachable,
            };
            var needsUniqueClassThis = false;
            for (tree.getNodeList(members_list)) |member| {
                if ((isPrivateIdentifierClassElementDeclaration(tree, member) or ast_utils.hasAccessorModifier(tree, member)) and ast_utils.isStatic(tree, member)) {
                    needsUniqueClassThis = true;
                    break;
                }
            }
            ci.classThis = f.newUniqueName("_classThis");
        }

        const classNode = tree.getNode(node);
        const members_list = switch (tree.getNodeKind(node)) {
            .ClassDeclaration => classNode.ClassDeclaration.Members,
            .ClassExpression => classNode.ClassExpression.Members,
            else => unreachable,
        };
        for (tree.getNodeList(members_list)) |member| {
            const memberKind = tree.getNodeKind(member);
            const isMethodOrAccessor = switch (memberKind) {
                .MethodDeclaration, .GetAccessor, .SetAccessor => true,
                else => false,
            };
            if (isMethodOrAccessor and (getDecoratorsOfNode(tree, member).len > 0 or ast_utils.classElementOrClassElementParameterIsDecorated(tree, false, member, node))) {
                if (ast_utils.isStatic(tree, member)) {
                    if (ci.staticMethodExtraInitializersName == 0) {
                        ci.staticMethodExtraInitializersName = f.newUniqueName("_staticExtraInitializers");
                        const renamedClassThis = if (ci.classThis != 0) ci.classThis else f.newToken(.{ .ThisKeyword = {} });
                        const initializer = self.newRunInitializersHelper(renamedClassThis, ci.staticMethodExtraInitializersName, 0);
                        ci.pendingStaticInitializers.append(self.allocator, initializer) catch unreachable;
                    }
                } else {
                    if (ci.instanceMethodExtraInitializersName == 0) {
                        ci.instanceMethodExtraInitializersName = f.newUniqueName("_instanceExtraInitializers");
                        const initializer = self.newRunInitializersHelper(f.newToken(.{ .ThisKeyword = {} }), ci.instanceMethodExtraInitializersName, 0);
                        ci.pendingInstanceInitializers.append(self.allocator, initializer) catch unreachable;
                    }
                }
            }

            if (memberKind == .ClassStaticBlockDeclaration) {
                if (!isClassNamedEvaluationHelperBlock(self.transformer.emitContext, member)) {
                    ci.hasStaticInitializers = true;
                }
            } else if (memberKind == .PropertyDeclaration) {
                const prop = tree.getNode(member).PropertyDeclaration;
                if (ast_utils.isStatic(tree, member)) {
                    ci.hasStaticInitializers = ci.hasStaticInitializers or prop.Initializer != 0 or ast_utils.nodeIsDecorated(tree, false, member, node);
                } else {
                    ci.hasNonAmbientInstanceFields = ci.hasNonAmbientInstanceFields or !ast_utils.hasSyntacticModifier(tree, member, ast_utils.ModifierFlags.Ambient);
                }
            }

            if ((isPrivateIdentifierClassElementDeclaration(tree, member) or ast_utils.hasAccessorModifier(tree, member)) and ast_utils.isStatic(tree, member)) {
                ci.hasStaticPrivateClassElements = true;
            }
        }
        return ci;
    }

    fn newRunInitializersHelper(self: *ESDecoratorTransformer, thisArg: ast_gen.NodeIndex, initializersName: ast_gen.NodeIndex, value: ast_gen.NodeIndex) ast_gen.NodeIndex {
        self.transformer.emitContext.requestEmitHelper(&helpers.runInitializersHelper);
        var args = std.ArrayList(ast_gen.NodeIndex).empty;
        defer args.deinit(self.allocator);
        args.append(self.allocator, thisArg) catch unreachable;
        args.append(self.allocator, initializersName) catch unreachable;
        if (value != 0) {
            args.append(self.allocator, value) catch unreachable;
        }
        const argsList = self.transformer.factory.newNodeList(args.items);
        const helperName = self.transformer.factory.newIdentifier("__runInitializers");
        return self.transformer.factory.newCallExpression(helperName, 0, 0, argsList, 0);
    }

    fn newESDecorateHelper(self: *ESDecoratorTransformer, ctor: ast_gen.NodeIndex, descriptor: ast_gen.NodeIndex, decorators: ast_gen.NodeIndex, context: ast_gen.NodeIndex, initializers: ast_gen.NodeIndex, extraInitializers: ast_gen.NodeIndex) ast_gen.NodeIndex {
        self.transformer.emitContext.requestEmitHelper(&helpers.esDecorateHelper);
        const argsList = self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{ ctor, descriptor, decorators, context, initializers, extraInitializers });
        const helperName = self.transformer.factory.newIdentifier("__esDecorate");
        return self.transformer.factory.newCallExpression(helperName, 0, 0, argsList, 0);
    }

    fn newESDecorateClassContextObject(self: *ESDecoratorTransformer, nameExpr: ast_gen.NodeIndex, metadata: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const kind_str = f.newStringLiteral("class", 0);
        const props = &[_]ast_gen.NodeIndex{
            f.newPropertyAssignment(0, f.newIdentifier("kind"), 0, 0, kind_str),
            f.newPropertyAssignment(0, f.newIdentifier("name"), 0, 0, nameExpr),
            f.newPropertyAssignment(0, f.newIdentifier("metadata"), 0, 0, metadata),
        };
        return f.newObjectLiteralExpression(f.newNodeList(props), false);
    }

    fn newESDecorateClassElementContextObject(
        self: *ESDecoratorTransformer,
        kind_name: []const u8,
        nameComputed: bool,
        nameExpr: ast_gen.NodeIndex,
        isStatic: bool,
        isPrivate: bool,
        hasGet: bool,
        hasSet: bool,
        metadata: ast_gen.NodeIndex,
    ) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        var nameValue = nameExpr;
        if (!nameComputed and nameExpr != 0 and (treeNodeKind(f.tree, nameExpr) == .PrivateIdentifier or ast_utils.isIdentifier(f.tree, nameExpr))) {
            nameValue = f.newStringLiteralFromNode(nameExpr) catch unreachable;
        }

        const accessObj = self.newESDecorateClassElementAccessObject(nameComputed, nameExpr, hasGet, hasSet);

        const staticExpr = if (isStatic) f.newToken(.{ .TrueKeyword = {} }) else f.newToken(.{ .FalseKeyword = {} });
        const privateExpr = if (isPrivate) f.newToken(.{ .TrueKeyword = {} }) else f.newToken(.{ .FalseKeyword = {} });
        const kind_str = f.newStringLiteral(kind_name, 0);

        const props = &[_]ast_gen.NodeIndex{
            f.newPropertyAssignment(0, f.newIdentifier("kind"), 0, 0, kind_str),
            f.newPropertyAssignment(0, f.newIdentifier("name"), 0, 0, nameValue),
            f.newPropertyAssignment(0, f.newIdentifier("static"), 0, 0, staticExpr),
            f.newPropertyAssignment(0, f.newIdentifier("private"), 0, 0, privateExpr),
            f.newPropertyAssignment(0, f.newIdentifier("access"), 0, 0, accessObj),
            f.newPropertyAssignment(0, f.newIdentifier("metadata"), 0, 0, metadata),
        };
        return f.newObjectLiteralExpression(f.newNodeList(props), false);
    }

    fn newESDecorateClassElementAccessObject(
        self: *ESDecoratorTransformer,
        nameComputed: bool,
        nameExpr: ast_gen.NodeIndex,
        hasGet: bool,
        hasSet: bool,
    ) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        var accessProps = std.ArrayList(ast_gen.NodeIndex).empty;
        defer accessProps.deinit(self.allocator);

        accessProps.append(self.allocator, self.newESDecorateClassElementAccessHasMethod(nameComputed, nameExpr)) catch unreachable;
        if (hasGet) {
            accessProps.append(self.allocator, self.newESDecorateClassElementAccessGetMethod(nameComputed, nameExpr)) catch unreachable;
        }
        if (hasSet) {
            accessProps.append(self.allocator, self.newESDecorateClassElementAccessSetMethod(nameComputed, nameExpr)) catch unreachable;
        }
        return f.newObjectLiteralExpression(f.newNodeList(accessProps.items), false);
    }

    fn newESDecorateClassElementAccessHasMethod(
        self: *ESDecoratorTransformer,
        nameComputed: bool,
        nameExpr: ast_gen.NodeIndex,
    ) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        var propertyName = nameExpr;
        if (!nameComputed and nameExpr != 0 and ast_utils.isIdentifier(f.tree, nameExpr)) {
            propertyName = f.newStringLiteralFromNode(nameExpr) catch unreachable;
        }

        const objParam = f.newParameterDeclaration(0, 0, f.newIdentifier("obj"), 0, 0, 0);
        const inExpr = f.newBinaryExpression(0, propertyName, 0, f.newToken(.{ .InKeyword = {} }), f.newIdentifier("obj"));

        const arrow = f.newArrowFunction(
            0,
            0,
            f.newNodeList(&[_]ast_gen.NodeIndex{objParam}),
            0,
            f.newToken(.{ .EqualsGreaterThanToken = {} }),
            inExpr,
        );
        return f.newPropertyAssignment(0, f.newIdentifier("has"), 0, 0, arrow);
    }

    fn newESDecorateClassElementAccessGetMethod(
        self: *ESDecoratorTransformer,
        nameComputed: bool,
        nameExpr: ast_gen.NodeIndex,
    ) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const accessor = if (nameComputed)
            f.newElementAccessExpression(f.newIdentifier("obj"), 0, nameExpr, 0)
        else
            f.newPropertyAccessExpression(f.newIdentifier("obj"), 0, nameExpr, 0);

        const objParam = f.newParameterDeclaration(0, 0, f.newIdentifier("obj"), 0, 0, 0);

        const arrow = f.newArrowFunction(
            0,
            0,
            f.newNodeList(&[_]ast_gen.NodeIndex{objParam}),
            0,
            f.newToken(.{ .EqualsGreaterThanToken = {} }),
            accessor,
        );
        return f.newPropertyAssignment(0, f.newIdentifier("get"), 0, 0, arrow);
    }

    fn newESDecorateClassElementAccessSetMethod(
        self: *ESDecoratorTransformer,
        nameComputed: bool,
        nameExpr: ast_gen.NodeIndex,
    ) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const accessor = if (nameComputed)
            f.newElementAccessExpression(f.newIdentifier("obj"), 0, nameExpr, 0)
        else
            f.newPropertyAccessExpression(f.newIdentifier("obj"), 0, nameExpr, 0);

        const assignment = f.newAssignmentExpression(accessor, f.newIdentifier("value"));
        const stmt = f.newExpressionStatement(assignment);
        const body = f.newBlock(f.newNodeList(&[_]ast_gen.NodeIndex{stmt}), false);

        const objParam = f.newParameterDeclaration(0, 0, f.newIdentifier("obj"), 0, 0, 0);
        const valueParam = f.newParameterDeclaration(0, 0, f.newIdentifier("value"), 0, 0, 0);

        const arrow = f.newArrowFunction(
            0,
            0,
            f.newNodeList(&[_]ast_gen.NodeIndex{ objParam, valueParam }),
            0,
            f.newToken(.{ .EqualsGreaterThanToken = {} }),
            body,
        );
        return f.newPropertyAssignment(0, f.newIdentifier("set"), 0, 0, arrow);
    }

    fn newImmediatelyInvokedArrowFunction(self: *ESDecoratorTransformer, statements: []const ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const arrow = f.newArrowFunction(
            0,
            0,
            f.newNodeList(&[_]ast_gen.NodeIndex{}),
            0,
            f.newToken(.{ .EqualsGreaterThanToken = {} }),
            f.newBlock(f.newNodeList(statements), true),
        );
        return f.newCallExpression(
            f.newParenthesizedExpression(arrow),
            0,
            0,
            f.newNodeList(&[_]ast_gen.NodeIndex{}),
            0,
        );
    }

    fn newSetFunctionNameHelper(self: *ESDecoratorTransformer, fnExpr: ast_gen.NodeIndex, nameExpr: ast_gen.NodeIndex, prefix: []const u8) ast_gen.NodeIndex {
        self.transformer.emitContext.requestEmitHelper(&helpers.setFunctionNameHelper);
        const f = self.transformer.factory;
        var args = std.ArrayList(ast_gen.NodeIndex).empty;
        defer args.deinit(self.allocator);
        args.append(self.allocator, fnExpr) catch unreachable;
        args.append(self.allocator, nameExpr) catch unreachable;
        if (prefix.len > 0) {
            args.append(self.allocator, f.newStringLiteral(prefix, 0)) catch unreachable;
        }
        const argsList = f.newNodeList(args.items);
        const helperName = f.newIdentifier("__setFunctionName");
        return f.newCallExpression(helperName, 0, 0, argsList, 0);
    }

    fn newAssignmentTargetWrapper(self: *ESDecoratorTransformer, paramName: ast_gen.NodeIndex, expression: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const setAccessor = f.newSetAccessorDeclaration(
            0,
            f.newIdentifier("value"),
            f.newNodeList(&[_]ast_gen.NodeIndex{
                f.newParameterDeclaration(0, 0, paramName, 0, 0, 0),
            }),
            f.newBlock(f.newNodeList(&[_]ast_gen.NodeIndex{
                f.newExpressionStatement(expression),
            }), false),
        );
        const objLiteral = f.newObjectLiteralExpression(f.newNodeList(&[_]ast_gen.NodeIndex{setAccessor}), false);
        return f.newPropertyAccessExpression(
            f.newParenthesizedExpression(objLiteral),
            0,
            f.newIdentifier("value"),
            0,
        );
    }

    fn newCommaExpression(self: *ESDecoratorTransformer, left: ast_gen.NodeIndex, right: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        const commaToken = f.tree.pushNode(.{ .CommaToken = {} }) catch unreachable;
        return f.newBinaryExpression(0, left, 0, commaToken, right);
    }

    fn updateForStatement(self: *ESDecoratorTransformer, nodeIndex: ast_gen.NodeIndex, node: ast_gen.ForStatementNode, initializer: ast_gen.NodeIndex, condition: ast_gen.NodeIndex, incrementor: ast_gen.NodeIndex, statement: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const f = self.transformer.factory;
        if ((node.Initializer orelse 0) != initializer or (node.Condition orelse 0) != condition or (node.Incrementor orelse 0) != incrementor or node.Statement != statement) {
            var new_node = node;
            new_node.Initializer = if (initializer == 0) null else initializer;
            new_node.Condition = if (condition == 0) null else condition;
            new_node.Incrementor = if (incrementor == 0) null else incrementor;
            new_node.Statement = statement;
            return f.tree.pushNode(.{ .ForStatement = new_node }) catch unreachable;
        }
        return nodeIndex;
    }
};

const PartialResult = struct {
    modifiers: ast_gen.NodeIndex = 0,
    referencedName: ast_gen.NodeIndex = 0,
    name: ast_gen.NodeIndex = 0,
    initializersName: ast_gen.NodeIndex = 0,
    extraInitializersName: ast_gen.NodeIndex = 0,
    descriptorName: ast_gen.NodeIndex = 0,
    thisArg: ast_gen.NodeIndex = 0,
};

fn isDecoratedClassLike(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    return ast_utils.classOrConstructorParameterIsDecorated(tree, false, node) or
        ast_utils.childIsDecorated(tree, false, node, 0);
}

fn getHelperVariableName(ec: *emitcontext.EmitContext, node: ast_gen.NodeIndex) []const u8 {
    const tree = ec.tree;
    const nameNode = ast_utils.getNameOfNode(tree, node);
    const nodeKind = tree.getNodeKind(node);

    var declarationName: []const u8 = "";
    if (nameNode != 0 and ast_utils.isIdentifier(tree, nameNode)) {
        declarationName = ast_utils.getText(tree, nameNode);
    } else if (nameNode != 0 and treeNodeKind(tree, nameNode) == .PrivateIdentifier) {
        const txt = ast_utils.getText(tree, nameNode);
        if (txt.len > 1) {
            declarationName = txt[1..];
        }
    } else if (nameNode != 0 and ast_utils.isStringLiteral(tree, nameNode)) {
        declarationName = ast_utils.getText(tree, nameNode);
    } else if (nodeKind == .ClassDeclaration or nodeKind == .ClassExpression) {
        declarationName = "class";
    } else {
        declarationName = "member";
    }

    var prefix: []const u8 = "";
    if (nodeKind == .GetAccessor) {
        prefix = "get_";
    } else if (nodeKind == .SetAccessor) {
        prefix = "set_";
    } else if (nameNode != 0 and treeNodeKind(tree, nameNode) == .PrivateIdentifier) {
        prefix = "private_";
    }

    const static_prefix = if (ast_utils.isStatic(tree, node)) "static_" else "";

    const allocator = ec.allocator;
    const formatted = std.fmt.allocPrint(allocator, "_{s}{s}{s}", .{ static_prefix, prefix, declarationName }) catch unreachable;
    return formatted;
}

fn isClassStaticBlockDeclaration(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    return ast_utils.getKind(tree, node) == .ClassStaticBlockDeclaration;
}

fn isClassNamedEvaluationHelperBlock(ec: *emitcontext.EmitContext, node: ast_gen.NodeIndex) bool {
    return isClassStaticBlockDeclaration(ec.tree, node) and ec.getAssignedName(node) != 0;
}

fn isClassThisAssignmentBlock(ec: *emitcontext.EmitContext, node: ast_gen.NodeIndex) bool {
    return isClassStaticBlockDeclaration(ec.tree, node) and ec.getClassThis(node) != 0;
}

fn classHasClassThisAssignment(ec: *emitcontext.EmitContext, node: ast_gen.NodeIndex) bool {
    const tree = ec.tree;
    const nodeKind = ast_utils.getKind(tree, node);
    const members_list = switch (nodeKind) {
        .ClassDeclaration => tree.getNode(node).ClassDeclaration.Members,
        .ClassExpression => tree.getNode(node).ClassExpression.Members,
        else => return false,
    };
    for (tree.getNodeList(members_list)) |m| {
        if (isClassThisAssignmentBlock(ec, m)) return true;
    }
    return false;
}

fn classHasExplicitlyAssignedName(ec: *emitcontext.EmitContext, classNode: ast_gen.NodeIndex) bool {
    const assignedName = ec.getAssignedName(classNode);
    if (assignedName != 0) {
        const tree = ec.tree;
        const nodeKind = ast_utils.getKind(tree, classNode);
        const members_list = switch (nodeKind) {
            .ClassDeclaration => tree.getNode(classNode).ClassDeclaration.Members,
            .ClassExpression => tree.getNode(classNode).ClassExpression.Members,
            else => return false,
        };
        for (tree.getNodeList(members_list)) |member| {
            if (isClassNamedEvaluationHelperBlock(ec, member)) {
                return true;
            }
        }
    }
    return false;
}

fn classHasDeclaredOrExplicitlyAssignedName(ec: *emitcontext.EmitContext, classNode: ast_gen.NodeIndex) bool {
    const tree = ec.tree;
    const name = switch (ast_utils.getKind(tree, classNode)) {
        .ClassDeclaration => tree.getNode(classNode).ClassDeclaration.name orelse 0,
        .ClassExpression => tree.getNode(classNode).ClassExpression.name orelse 0,
        else => 0,
    };
    return name != 0 or classHasExplicitlyAssignedName(ec, classNode);
}

fn getFirstConstructorWithBody(tree: *ast.Ast, classNode: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const nodeKind = ast_utils.getKind(tree, classNode);
    const members_list = switch (nodeKind) {
        .ClassDeclaration => tree.getNode(classNode).ClassDeclaration.Members,
        .ClassExpression => tree.getNode(classNode).ClassExpression.Members,
        else => return 0,
    };
    for (tree.getNodeList(members_list)) |member| {
        if (ast_utils.getKind(tree, member) == .Constructor) {
            const body = tree.getNode(member).Constructor.Body orelse 0;
            if (body != 0) return member;
        }
    }
    return 0;
}

fn getHeritageClause(tree: *ast.Ast, classNode: ast_gen.NodeIndex, k: kind.Kind) ?ast_gen.NodeIndex {
    const nodeData = tree.getNode(classNode);
    const clauses_idx = switch (tree.getNodeKind(classNode)) {
        .ClassDeclaration => nodeData.ClassDeclaration.HeritageClauses,
        .ClassExpression => nodeData.ClassExpression.HeritageClauses,
        else => return null,
    };
    const clauses = clauses_idx orelse return null;
    if (clauses == 0) return null;
    for (tree.getNodeList(clauses)) |clause| {
        const hc = tree.getNode(clause).HeritageClause;
        if (hc.Token == @intFromEnum(k)) {
            return clause;
        }
    }
    return null;
}

fn skipOuterExpressions(tree: *ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    var current = node;
    while (current != 0) {
        const nodeData = tree.getNode(current);
        switch (nodeData) {
            .ParenthesizedExpression => |pe| current = pe.Expression,
            .PartiallyEmittedExpression => |pe| current = pe.Expression,
            else => break,
        }
    }
    return current;
}

fn isAnonymousFunctionDefinition(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    const inner = skipOuterExpressions(tree, node);
    const nodeKind = tree.getNodeKind(inner);
    switch (nodeKind) {
        .ArrowFunction => return true,
        .FunctionExpression => {
            const data = tree.getNode(inner).FunctionExpression;
            return data.name == null or data.name.? == 0;
        },
        .ClassExpression => {
            const data = tree.getNode(inner).ClassExpression;
            return data.name == null or data.name.? == 0;
        },
        else => return false,
    }
}

fn isAnonymousClassNeedingAssignedName(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const inner = skipOuterExpressions(tree, node);
    if (tree.getNodeKind(inner) == .ClassExpression) {
        const data = tree.getNode(inner).ClassExpression;
        return (data.name == null or data.name.? == 0) and isDecoratedClassLike(tree, inner);
    }
    return false;
}

fn isNamedEvaluationAnd(ec: *emitcontext.EmitContext, node: ast_gen.NodeIndex, cb: *const fn (*ast.Ast, ast_gen.NodeIndex) bool) bool {
    const tree = ec.tree;
    if (!isNamedEvaluationSource(tree, node)) {
        return false;
    }
    const nodeKind = tree.getNodeKind(node);
    switch (nodeKind) {
        .ShorthandPropertyAssignment => {
            const spa = tree.getNode(node).ShorthandPropertyAssignment;
            return isAnonymousFunctionDefinition(tree, spa.ObjectAssignmentInitializer orelse 0) and cb(tree, spa.ObjectAssignmentInitializer orelse 0);
        },
        .PropertyAssignment => {
            const pa = tree.getNode(node).PropertyAssignment;
            return isAnonymousFunctionDefinition(tree, pa.Initializer) and cb(tree, pa.Initializer);
        },
        .VariableDeclaration => {
            const vd = tree.getNode(node).VariableDeclaration;
            return isAnonymousFunctionDefinition(tree, vd.Initializer orelse 0) and cb(tree, vd.Initializer orelse 0);
        },
        .Parameter => {
            const param = tree.getNode(node).Parameter;
            return isAnonymousFunctionDefinition(tree, param.Initializer orelse 0) and cb(tree, param.Initializer orelse 0);
        },
        .BindingElement => {
            const be = tree.getNode(node).BindingElement;
            return isAnonymousFunctionDefinition(tree, be.Initializer orelse 0) and cb(tree, be.Initializer orelse 0);
        },
        .PropertyDeclaration => {
            const prop = tree.getNode(node).PropertyDeclaration;
            return isAnonymousFunctionDefinition(tree, prop.Initializer orelse 0) and cb(tree, prop.Initializer orelse 0);
        },
        .BinaryExpression => {
            const bin = tree.getNode(node).BinaryExpression;
            return isAnonymousFunctionDefinition(tree, bin.Right) and cb(tree, bin.Right);
        },
        .ExportAssignment => {
            const ea = tree.getNode(node).ExportAssignment;
            return isAnonymousFunctionDefinition(tree, ea.Expression) and cb(tree, ea.Expression);
        },
        else => {
            std.debug.panic("Unhandled case in isNamedEvaluationAnd: {s}", .{@tagName(tree.getNode(node))});
        },
    }
}

fn isNamedEvaluationSource(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const nodeKind = tree.getNodeKind(node);
    switch (nodeKind) {
        .PropertyAssignment => {
            const pa = tree.getNode(node).PropertyAssignment;
            return !isProtoSetter(tree, pa.name);
        },
        .ShorthandPropertyAssignment => {
            const spa = tree.getNode(node).ShorthandPropertyAssignment;
            return spa.ObjectAssignmentInitializer != null and spa.ObjectAssignmentInitializer.? != 0;
        },
        .VariableDeclaration => {
            const vd = tree.getNode(node).VariableDeclaration;
            return ast_utils.isIdentifier(tree, vd.name) and vd.Initializer != null and vd.Initializer.? != 0;
        },
        .Parameter => {
            const param = tree.getNode(node).Parameter;
            return ast_utils.isIdentifier(tree, param.name) and param.Initializer != null and param.Initializer.? != 0 and param.DotDotDotToken == null;
        },
        .BindingElement => {
            const be = tree.getNode(node).BindingElement;
            return ast_utils.isIdentifier(tree, be.name orelse 0) and be.Initializer != null and be.Initializer.? != 0 and be.DotDotDotToken == null;
        },
        .PropertyDeclaration => {
            const prop = tree.getNode(node).PropertyDeclaration;
            return prop.Initializer != 0;
        },
        .BinaryExpression => {
            const bin = tree.getNode(node).BinaryExpression;
            const opKind = tree.getNodeKind(bin.OperatorToken);
            switch (opKind) {
                .EqualsToken, .AmpersandAmpersandEqualsToken, .BarBarEqualsToken, .QuestionQuestionEqualsToken => {
                    return ast_utils.isIdentifier(tree, bin.Left);
                },
                else => return false,
            }
        },
        .ExportAssignment => return true,
        else => return false,
    }
}

fn isProtoSetter(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    const isIdent = ast_utils.isIdentifier(tree, node);
    const isStr = ast_utils.isStringLiteral(tree, node);
    if (isIdent or isStr) {
        const text = ast_utils.getTextOfNode(tree, node);
        return std.mem.eql(u8, text, "__proto__");
    }
    return false;
}

fn canIgnoreEmptyStringLiteralInAssignedName(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    if (nodeIndex == 0) return false;
    const innerExpression = skipOuterExpressions(tree, nodeIndex);
    if (tree.getNodeKind(innerExpression) == .ClassExpression) {
        const ce = tree.getNode(innerExpression).ClassExpression;
        const hasName = ce.name orelse 0;
        return hasName == 0 and !ast_utils.classOrConstructorParameterIsDecorated(tree, false, innerExpression);
    }
    return false;
}

fn getAssignedNameOfIdentifier(ec: *emitcontext.EmitContext, name: ast_gen.NodeIndex, expression: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const f = ec.factory;
    const tree = ec.tree;
    const original = ec.getOriginal(skipOuterExpressions(tree, expression));
    if (original != 0) {
        const origKind = tree.getNodeKind(original);
        if (origKind == .ClassDeclaration or origKind == .FunctionDeclaration) {
            const hasName = switch (origKind) {
                .ClassDeclaration => tree.getNode(original).ClassDeclaration.name orelse 0,
                .FunctionDeclaration => tree.getNode(original).FunctionDeclaration.name orelse 0,
                else => 0,
            };
            if (hasName == 0 and ast_utils.hasSyntacticModifier(tree, original, ast_utils.ModifierFlags.Default)) {
                return f.newStringLiteral("default", 0);
            }
        }
    }
    return f.newStringLiteralFromNode(name) catch unreachable;
}

fn visitModifier(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    _ = ctx;
    const kind_val = ast_utils.getKind(v.tree, node);
    if (kind_val == .Decorator) return 0;
    return node;
}

fn visitExportStrippingModifier(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    _ = ctx;
    const kind_val = ast_utils.getKind(v.tree, node);
    if (kind_val == .ExportKeyword) return 0;
    if (kind_val == .Decorator) return 0;
    return node;
}

fn visitStaticOnlyModifier(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    _ = ctx;
    const kind_val = ast_utils.getKind(v.tree, node);
    if (kind_val == .StaticKeyword) return node;
    return 0;
}

fn visitAsyncOnlyModifier(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    _ = ctx;
    const kind_val = ast_utils.getKind(v.tree, node);
    if (kind_val == .AsyncKeyword) return node;
    return 0;
}

fn visitAccessorStrippingModifier(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    _ = ctx;
    const kind_val = ast_utils.getKind(v.tree, node);
    if (kind_val == .AccessorKeyword) return 0;
    return node;
}

fn visitOuterThis(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const self = @as(*ESDecoratorTransformer, @ptrCast(@alignCast(ctx.?)));
    const tree = v.tree;
    const nodeKind = ast_utils.getKind(tree, node);
    if (nodeKind == .ThisKeyword) {
        if (self.outer_this == 0) {
            self.outer_this = self.transformer.factory.newUniqueName("_outerThis");
        }
        return self.outer_this;
    }
    return v.visitEachChild(node);
}

fn visitDiscardedValue(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const self = @as(*ESDecoratorTransformer, @ptrCast(@alignCast(ctx.?)));
    const tree = v.tree;
    const nodeKind = ast_utils.getKind(tree, node);
    switch (nodeKind) {
        .PrefixUnaryExpression, .PostfixUnaryExpression => {
            return self.visitPreOrPostfixUnaryExpression(v, node, true);
        },
        .BinaryExpression => {
            return self.visitBinaryExpression(v, node, true);
        },
        .ParenthesizedExpression => {
            return self.visitParenthesizedExpression(v, node, true);
        },
        .PartiallyEmittedExpression => {
            return self.visitPartiallyEmittedExpression(v, node, true);
        },
        else => {
            return ESDecoratorTransformer.visit(ctx, v, node);
        },
    }
}

fn visitClassElement(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const self = @as(*ESDecoratorTransformer, @ptrCast(@alignCast(ctx.?)));
    const tree = v.tree;
    const nodeKind = ast_utils.getKind(tree, node);
    switch (nodeKind) {
        .Constructor => return self.visitConstructorDeclaration(v, node),
        .MethodDeclaration => return self.visitMethodDeclaration(v, node),
        .GetAccessor => return self.visitGetAccessorDeclaration(v, node),
        .SetAccessor => return self.visitSetAccessorDeclaration(v, node),
        .PropertyDeclaration => return self.visitPropertyDeclaration(v, node),
        .ClassStaticBlockDeclaration => return self.visitClassStaticBlockDeclaration(v, node),
        else => return ESDecoratorTransformer.visit(ctx, v, node),
    }
}

fn visitNonConstructorClassElement(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const tree = v.tree;
    const nodeKind = ast_utils.getKind(tree, node);
    if (nodeKind == .Constructor) return node;
    return visitClassElement(ctx, v, node);
}

fn visitConstructorClassElement(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const tree = v.tree;
    const nodeKind = ast_utils.getKind(tree, node);
    if (nodeKind == .Constructor) return visitClassElement(ctx, v, node);
    return node;
}

fn visitArrayAssignmentElement(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const self = @as(*ESDecoratorTransformer, @ptrCast(@alignCast(ctx.?)));
    const tree = v.tree;
    const nodeKind = ast_utils.getKind(tree, node);
    if (nodeKind == .SpreadElement) {
        return self.visitAssignmentRestElement(v, node);
    }
    if (nodeKind != .OmittedExpression) {
        return self.visitAssignmentElement(v, node);
    }
    return v.visitEachChild(node);
}

fn visitObjectAssignmentElement(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const self = @as(*ESDecoratorTransformer, @ptrCast(@alignCast(ctx.?)));
    const tree = v.tree;
    const nodeKind = ast_utils.getKind(tree, node);
    switch (nodeKind) {
        .SpreadAssignment => return self.visitAssignmentRestProperty(v, node),
        .ShorthandPropertyAssignment => return self.visitShorthandAssignmentProperty(v, node),
        .PropertyAssignment => return self.visitAssignmentPropertyNode(v, node),
        else => return v.visitEachChild(node),
    }
}

fn findSuperStatementIndexPath(tree: *ast.Ast, statements: []const ast_gen.NodeIndex, startOffset: usize) []const usize {
    var result = std.ArrayList(usize).empty;
    var i = startOffset;
    while (i < statements.len) : (i += 1) {
        const stmt = statements[i];
        if (hasSuperCall(tree, stmt)) {
            result.append(std.heap.page_allocator, i) catch unreachable;
            break;
        }
    }
    return result.toOwnedSlice(std.heap.page_allocator) catch unreachable;
}

fn hasSuperCall(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    const k_val = tree.getNodeKind(node);
    if (k_val == .CallExpression) {
        const expr = tree.getNode(node).CallExpression.Expression;
        if (tree.getNodeKind(expr) == .SuperKeyword) return true;
    }
    const n = tree.getNode(node);
    switch (n) {
        .Block => |b| {
            for (tree.getNodeList(b.Statements)) |s| {
                if (hasSuperCall(tree, s)) return true;
            }
        },
        .ExpressionStatement => |es| {
            return hasSuperCall(tree, es.Expression);
        },
        else => {},
    }
    return false;
}

fn isSimpleInlineableExpression(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const k_val = tree.getNodeKind(node);
    return k_val == .Identifier or k_val == .NumericLiteral or k_val == .StringLiteral or k_val == .ThisKeyword;
}

fn isPrivateIdentifierClassElementDeclaration(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const nodeKind = ast_utils.getKind(tree, node);
    switch (nodeKind) {
        .PropertyDeclaration, .MethodDeclaration, .GetAccessor, .SetAccessor => {
            const nameNode = ast_utils.getNameOfNode(tree, node);
            return nameNode != 0 and treeNodeKind(tree, nameNode) == .PrivateIdentifier;
        },
        else => return false,
    }
}

fn getDecoratorsOfNode(tree: *ast.Ast, node: ast_gen.NodeIndex) []const ast_gen.NodeIndex {
    const decsNode = ast_utils.decorators(tree, node);
    if (decsNode == 0) return &[_]ast_gen.NodeIndex{};
    return ast_utils.getNodes(tree, decsNode);
}

fn isSuperProperty(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const k_val = tree.getNodeKind(nodeIndex);
    if (k_val == .PropertyAccessExpression) {
        const pa = tree.getNode(nodeIndex).PropertyAccessExpression;
        return tree.getNodeKind(pa.Expression) == .SuperKeyword;
    } else if (k_val == .ElementAccessExpression) {
        const ea = tree.getNode(nodeIndex).ElementAccessExpression;
        return tree.getNodeKind(ea.Expression) == .SuperKeyword;
    }
    return false;
}

fn isPropertyNameLiteral(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const kind_val = ast_utils.getKind(tree, node);
    return kind_val == .Identifier or kind_val == .StringLiteral or kind_val == .NumericLiteral;
}

fn treeNodeKind(tree: *ast.Ast, node: ast_gen.NodeIndex) kind.Kind {
    return tree.getNodeKind(node);
}
