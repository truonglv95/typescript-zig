const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const visitor = @import("../../ast/visitor.zig");
const kind = @import("../../ast/kind.zig");
const core = @import("../../core/core.zig");
const transformers = @import("../transformer.zig");
const ast_utils = @import("../../ast/ast_utils.zig");
const helpers = @import("../../printer/helpers.zig");

pub const ClassFieldsTransformer = struct {
    base: transformers.Transformer,
    allocator: std.mem.Allocator,
    transformer: *transformers.Transformer,
    compiler_options: *core.CompilerOptions,
    static_this_alias: ast_gen.NodeIndex = 0,
    hoisted_aliases: std.ArrayListUnmanaged(ast_gen.NodeIndex) = .empty,
    inferred_class_name: []const u8 = "",
    nested_destructuring_array: bool = false,

    pub fn new(allocator: std.mem.Allocator, opt: *transformers.TransformOptions) !*transformers.Transformer {
        const tx = try allocator.create(ClassFieldsTransformer);
        tx.allocator = allocator;
        tx.compiler_options = opt.compilerOptions;
        tx.static_this_alias = 0;
        tx.hoisted_aliases = .empty;
        tx.inferred_class_name = "";
        tx.nested_destructuring_array = false;
        tx.transformer = try transformers.Transformer.init(allocator, visit, tx, opt.context);
        tx.base = tx.transformer.*;
        return tx.transformer;
    }

    fn visit(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const self: *ClassFieldsTransformer = @ptrCast(@alignCast(ctx.?));
        if (node == 0) return 0;

        const nodeKind = ast_utils.getKind(v.tree, node);
        if (nodeKind == .SourceFile) return self.visitSourceFile(v, node);
        if (nodeKind == .Block) return self.visitBlock(v, node);
        if (nodeKind == .BinaryExpression) return self.visitBinaryExpression(v, node);
        if (nodeKind == .ShorthandPropertyAssignment) return self.visitShorthandProperty(v, node);
        if (nodeKind == .ArrayLiteralExpression) {
            const previous = self.nested_destructuring_array;
            self.nested_destructuring_array = true;
            const result = v.visitEachChild(node);
            self.nested_destructuring_array = previous;
            return result;
        }
        if (nodeKind == .ClassDeclaration or nodeKind == .ClassExpression) {
            return self.visitClassLike(v, node);
        }

        return v.visitEachChild(node);
    }

    fn visitBlock(self: *ClassFieldsTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const alias_start = self.hoisted_aliases.items.len;
        const visited = v.visitEachChild(node);
        if (self.hoisted_aliases.items.len == alias_start) return visited;
        const aliases = self.allocator.dupe(ast_gen.NodeIndex, self.hoisted_aliases.items[alias_start..]) catch unreachable;
        defer self.allocator.free(aliases);
        self.hoisted_aliases.shrinkRetainingCapacity(alias_start);
        var declarations = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer declarations.deinit(self.allocator);
        for (aliases) |alias| declarations.append(self.allocator, self.transformer.factory.newVariableDeclaration(alias, 0, 0, 0)) catch unreachable;
        const list = self.transformer.factory.newVariableDeclarationList(self.transformer.factory.newNodeList(declarations.items), ast_utils.NodeFlags.Let);
        const block = v.tree.getNode(visited).Block;
        var statements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer statements.deinit(self.allocator);
        statements.append(self.allocator, self.transformer.factory.newVariableStatement(0, list)) catch unreachable;
        statements.appendSlice(self.allocator, v.tree.getNodeList(block.Statements)) catch unreachable;
        return self.transformer.factory.updateBlock(visited, block, self.transformer.factory.newNodeList(statements.items), true);
    }

    fn visitShorthandProperty(self: *ClassFieldsTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        var data = v.tree.getNode(node).ShorthandPropertyAssignment;
        const initializer = data.ObjectAssignmentInitializer orelse return v.visitEachChild(node);
        const previous = self.inferred_class_name;
        self.inferred_class_name = ast_utils.getText(v.tree, data.name);
        data.ObjectAssignmentInitializer = v.visitNode(initializer);
        self.inferred_class_name = previous;
        return v.tree.pushNode(.{ .ShorthandPropertyAssignment = data }) catch unreachable;
    }

    fn visitBinaryExpression(self: *ClassFieldsTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const data = v.tree.getNode(node).BinaryExpression;
        if (v.tree.getNodeKind(data.OperatorToken) == .EqualsToken and v.tree.getNode(data.Right) == .ClassExpression and
            (v.tree.getNode(data.Right).ClassExpression.name orelse 0) == 0 and v.tree.getNode(data.Left) == .Identifier)
        {
            const previous = self.inferred_class_name;
            self.inferred_class_name = v.tree.getNode(data.Left).Identifier.Text;
            const right = v.visitNode(data.Right);
            self.inferred_class_name = previous;
            var updated = data;
            updated.Left = v.visitNode(data.Left);
            updated.Right = right;
            return v.tree.pushNode(.{ .BinaryExpression = updated }) catch unreachable;
        }
        return v.visitEachChild(node);
    }

    fn visitSourceFile(self: *ClassFieldsTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        self.hoisted_aliases.clearRetainingCapacity();
        const visited = v.visitEachChild(node);
        if (self.hoisted_aliases.items.len == 0) return visited;
        const source = v.tree.getNode(visited).SourceFile;
        var declarations = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer declarations.deinit(self.allocator);
        for (self.hoisted_aliases.items) |alias| declarations.append(self.allocator, self.transformer.factory.newVariableDeclaration(alias, 0, 0, 0)) catch unreachable;
        const declaration_list = self.transformer.factory.newVariableDeclarationList(self.transformer.factory.newNodeList(declarations.items), 0);
        var statements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer statements.deinit(self.allocator);
        statements.append(self.allocator, self.transformer.factory.newVariableStatement(0, declaration_list)) catch unreachable;
        statements.appendSlice(self.allocator, v.tree.getNodeList(source.Statements)) catch unreachable;
        return self.transformer.factory.updateSourceFile(visited, source, self.transformer.factory.newNodeList(statements.items), source.EndOfFileToken);
    }

    fn visitClassLike(self: *ClassFieldsTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const nodeData = tree.getNode(node);
        const membersListIndex = switch (nodeData) {
            .ClassDeclaration => |n| n.Members,
            .ClassExpression => |n| n.Members,
            else => return node,
        };

        const members_slice = self.allocator.dupe(ast_gen.NodeIndex, tree.getNodeList(membersListIndex)) catch unreachable;
        defer self.allocator.free(members_slice);
        const PrivateField = struct { name: []const u8, storage: ast_gen.NodeIndex };
        var private_fields = std.ArrayListUnmanaged(PrivateField).empty;
        defer private_fields.deinit(self.allocator);
        const ComputedField = struct { member: ast_gen.NodeIndex, temp: ast_gen.NodeIndex };
        var computed_fields = std.ArrayListUnmanaged(ComputedField).empty;
        defer computed_fields.deinit(self.allocator);
        const target = self.compiler_options.target orelse .ES2025;
        if (@intFromEnum(target) < @intFromEnum(core.ScriptTarget.ES2022)) {
            const owner = ast_utils.getText(tree, ast_utils.name(tree, node));
            for (members_slice) |member| {
                if (ast_utils.getKind(tree, member) != .PropertyDeclaration or ast_utils.isStatic(tree, member)) continue;
                const field_name = ast_utils.name(tree, member);
                if (ast_utils.getKind(tree, field_name) != .PrivateIdentifier) continue;
                const raw = ast_utils.getText(tree, field_name);
                const clean = if (raw.len > 0 and raw[0] == '#') raw[1..] else raw;
                const storage_text = std.fmt.allocPrint(self.allocator, "_{s}_{s}", .{ owner, clean }) catch unreachable;
                const storage = self.transformer.factory.newIdentifier(storage_text);
                private_fields.append(self.allocator, .{ .name = raw, .storage = storage }) catch unreachable;
                self.hoisted_aliases.append(self.allocator, storage) catch unreachable;
            }
            if (nodeData == .ClassExpression) for (members_slice) |member| {
                if (ast_utils.getKind(tree, member) == .PropertyDeclaration and ast_utils.getKind(tree, ast_utils.name(tree, member)) == .ComputedPropertyName) {
                    const temp = self.transformer.factory.newGeneratedIdentifier(.Auto, "", null, .{}) catch unreachable;
                    computed_fields.append(self.allocator, .{ .member = member, .temp = temp }) catch unreachable;
                    self.hoisted_aliases.append(self.allocator, temp) catch unreachable;
                }
            };
        }
        var class_this_alias: ast_gen.NodeIndex = 0;
        if (nodeData == .ClassDeclaration and @intFromEnum(self.compiler_options.target orelse .ES2025) < @intFromEnum(core.ScriptTarget.ES2022)) {
            for (members_slice) |member| {
                if (ast_utils.getKind(tree, member) == .PropertyDeclaration and ast_utils.isStatic(tree, member) and containsThis(tree, ast_utils.getInitializerOfNode(tree, member))) {
                    class_this_alias = self.transformer.factory.newGeneratedIdentifier(.Auto, "", null, .{}) catch unreachable;
                    break;
                }
            }
        }
        if (nodeData == .ClassExpression and @intFromEnum(self.compiler_options.target orelse .ES2025) < @intFromEnum(core.ScriptTarget.ES2022)) {
            for (members_slice) |member| {
                if (ast_utils.getKind(tree, member) == .PropertyDeclaration and ast_utils.getInitializerOfNode(tree, member) != 0 and
                    (ast_utils.isStatic(tree, member) or ast_utils.getKind(tree, ast_utils.name(tree, member)) == .PrivateIdentifier or ast_utils.getKind(tree, ast_utils.name(tree, member)) == .ComputedPropertyName))
                {
                    class_this_alias = self.transformer.factory.newGeneratedIdentifier(.Auto, "", null, .{}) catch unreachable;
                    self.hoisted_aliases.append(self.allocator, class_this_alias) catch unreachable;
                    break;
                }
            }
        }
        var new_members = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer new_members.deinit(self.allocator);
        var instance_initializers = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer instance_initializers.deinit(self.allocator);
        var static_initializers = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer static_initializers.deinit(self.allocator);

        var changed = false;
        const language_version = self.compiler_options.target orelse .ES2025;

        for (members_slice) |member| {
            const member_kind = ast_utils.getKind(tree, member);
            if (member_kind == .PropertyDeclaration and !ast_utils.isStatic(tree, member) and
                ast_utils.getKind(tree, ast_utils.name(tree, member)) == .PrivateIdentifier and
                @intFromEnum(language_version) < @intFromEnum(core.ScriptTarget.ES2022))
            {
                changed = true;
                const raw = ast_utils.getText(tree, ast_utils.name(tree, member));
                for (private_fields.items) |field| if (std.mem.eql(u8, field.name, raw)) {
                    const set_access = self.transformer.factory.newPropertyAccessExpression(field.storage, 0, self.transformer.factory.newIdentifier("set"), 0);
                    const args = self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{ self.transformer.factory.newThisExpression(), v.visitNode(ast_utils.getInitializerOfNode(tree, member)) });
                    instance_initializers.append(self.allocator, self.transformer.factory.newCallExpression(set_access, 0, 0, args, 0)) catch unreachable;
                    break;
                };
                continue;
            }
            if (member_kind == .PropertyDeclaration and ast_utils.isStatic(tree, member) and
                ast_utils.getKind(tree, ast_utils.name(tree, member)) == .PrivateIdentifier and
                @intFromEnum(language_version) < @intFromEnum(core.ScriptTarget.ES2022))
            {
                changed = true;
                const private_text = ast_utils.getText(tree, ast_utils.name(tree, member));
                const clean_private = if (private_text.len > 0 and private_text[0] == '#') private_text[1..] else private_text;
                const owner = if (self.inferred_class_name.len != 0) self.inferred_class_name else ast_utils.getText(tree, ast_utils.name(tree, node));
                const descriptor_text = std.fmt.allocPrint(self.allocator, "_{s}_{s}", .{ owner, clean_private }) catch unreachable;
                const descriptor = self.transformer.factory.newIdentifier(descriptor_text);
                self.hoisted_aliases.append(self.allocator, descriptor) catch unreachable;
                const value_property = self.transformer.factory.newPropertyAssignment(0, self.transformer.factory.newIdentifier("value"), 0, 0, v.visitNode(ast_utils.getInitializerOfNode(tree, member)));
                const descriptor_object = self.transformer.factory.newObjectLiteralExpression(self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{value_property}), false);
                static_initializers.append(self.allocator, self.transformer.factory.newAssignmentExpression(descriptor, descriptor_object)) catch unreachable;
                continue;
            }
            if (member_kind == .PropertyDeclaration and
                !ast_utils.hasAccessorModifier(tree, member) and
                ast_utils.getInitializerOfNode(tree, member) != 0 and
                ast_utils.getKind(tree, ast_utils.name(tree, member)) != .PrivateIdentifier and
                @intFromEnum(language_version) < @intFromEnum(core.ScriptTarget.ES2022))
            {
                changed = true;
                var computed_temp: ast_gen.NodeIndex = 0;
                if (tree.getNode(ast_utils.name(tree, member)) == .ComputedPropertyName) {
                    for (computed_fields.items) |entry| if (entry.member == member) {
                        computed_temp = entry.temp;
                        break;
                    };
                    if (computed_temp == 0) {
                        computed_temp = self.transformer.factory.newGeneratedIdentifier(.Auto, "", null, .{}) catch unreachable;
                        self.hoisted_aliases.append(self.allocator, computed_temp) catch unreachable;
                    }
                    const computed = tree.getNode(ast_utils.name(tree, member)).ComputedPropertyName;
                    static_initializers.append(self.allocator, self.transformer.factory.newAssignmentExpression(computed_temp, v.visitNode(computed.Expression))) catch unreachable;
                }
                const previous_alias = self.static_this_alias;
                self.static_this_alias = class_this_alias;
                const assignment = self.createFieldInitializer(v, node, member, computed_temp);
                self.static_this_alias = previous_alias;
                if (ast_utils.isStatic(tree, member)) {
                    static_initializers.append(self.allocator, assignment) catch unreachable;
                } else {
                    instance_initializers.append(self.allocator, assignment) catch unreachable;
                }
                continue;
            } else if (member_kind == .PropertyDeclaration and
                !ast_utils.hasAccessorModifier(tree, member) and
                ast_utils.getInitializerOfNode(tree, member) == 0 and
                @intFromEnum(language_version) < @intFromEnum(core.ScriptTarget.ES2022))
            {
                // With assignment semantics (the default below ES2022), an
                // uninitialized field has no runtime emit. This also removes
                // the synthetic field created for a parameter property; its
                // `this.x = x` assignment is emitted by RuntimeSyntax.
                changed = true;
                continue;
            } else if (ast_utils.getKind(tree, member) == .PropertyDeclaration and
                ast_utils.hasAccessorModifier(tree, member) and
                language_version != .ESNext)
            {
                changed = true;

                // 1. Get original name and initializer
                const orig_name_node = ast_utils.name(tree, member);
                const orig_name_text = ast_utils.getText(tree, orig_name_node);
                const is_static = ast_utils.isStatic(tree, member);

                // We want to generate a backing property name: e.g. `#x_accessor_storage` or `#y_accessor_storage`.
                const backing_name_str = std.fmt.allocPrint(self.allocator, "#{s}_accessor_storage", .{orig_name_text}) catch unreachable;
                const backingNameNode = self.transformer.factory.newPrivateIdentifier(backing_name_str);

                const orig_init = ast_utils.getInitializerOfNode(tree, member);

                // 2. Determine modifiers for getter, setter, backing field.
                const orig_modifiers = ast_utils.getModifiers(tree, member) orelse 0;
                const field_modifiers_mask = if (is_static) ast_utils.ModifierFlags.Static else 0;
                const field_modifiers = self.transformer.extractModifiers(orig_modifiers, field_modifiers_mask);

                const accessor_modifiers_mask = (if (is_static) ast_utils.ModifierFlags.Static else 0) |
                    (ast_utils.getModifierFlags(tree, member) &
                        (ast_utils.ModifierFlags.Public | ast_utils.ModifierFlags.Private | ast_utils.ModifierFlags.Protected));
                const accessor_modifiers = self.transformer.extractModifiers(orig_modifiers, accessor_modifiers_mask);

                // 3. Create backing field: `#x_accessor_storage = initializer;`
                const visited_init = if (orig_init != 0) v.visitNode(orig_init) else 0;
                const backingField = self.transformer.factory.newPropertyDeclaration(
                    field_modifiers,
                    backingNameNode,
                    0,
                    0,
                    visited_init,
                );

                // 4. Create getter: `get x() { return this.#x_accessor_storage; }`
                const thisExpr = self.transformer.factory.newThisExpression();
                const backingAccessExpr = self.transformer.factory.newPropertyAccessExpression(thisExpr, 0, backingNameNode, 0);
                const getterReturnStmt = self.transformer.factory.newReturnStatement(backingAccessExpr);
                const getterStatements = &[_]ast_gen.NodeIndex{getterReturnStmt};
                const getterStatementsList = self.transformer.factory.newNodeList(getterStatements);
                const getterBlock = self.transformer.factory.newBlock(getterStatementsList, false);

                const getterParamsList = self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{});
                const getterName = v.visitNode(orig_name_node);

                const getterDecl = self.transformer.factory.newGetAccessorDeclaration(
                    accessor_modifiers,
                    getterName,
                    getterParamsList,
                    0,
                    getterBlock,
                );

                // 5. Create setter: `set x(value) { this.#x_accessor_storage = value; }`
                const valueIdentStr = self.allocator.dupe(u8, "value") catch unreachable;
                const valueParamIdent = self.transformer.factory.newIdentifier(valueIdentStr);
                const valueParamDecl = self.transformer.factory.newParameterDeclaration(
                    0,
                    0,
                    valueParamIdent,
                    0,
                    0,
                    0,
                );
                const setterParamsList = self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{valueParamDecl});

                const valueRefIdent = self.transformer.factory.newIdentifier(valueIdentStr);
                const setterAssignmentExpr = self.transformer.factory.newAssignmentExpression(backingAccessExpr, valueRefIdent);
                const setterExprStmt = self.transformer.factory.newExpressionStatement(setterAssignmentExpr);
                const setterStatements = &[_]ast_gen.NodeIndex{setterExprStmt};
                const setterStatementsList = self.transformer.factory.newNodeList(setterStatements);
                const setterBlock = self.transformer.factory.newBlock(setterStatementsList, false);

                const setterDecl = self.transformer.factory.newSetAccessorDeclaration(
                    accessor_modifiers,
                    getterName,
                    setterParamsList,
                    setterBlock,
                );

                new_members.append(self.allocator, backingField) catch unreachable;
                new_members.append(self.allocator, getterDecl) catch unreachable;
                new_members.append(self.allocator, setterDecl) catch unreachable;
            } else {
                const visited_member = v.visitNode(member);
                const rewritten_member = self.rewritePrivateAccesses(tree, visited_member, private_fields.items);
                new_members.append(self.allocator, rewritten_member) catch unreachable;
            }
        }

        if (private_fields.items.len != 0) {
            var storage_initializers = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
            defer storage_initializers.deinit(self.allocator);
            for (private_fields.items) |field| {
                const weak_map = tree.pushNode(.{ .NewExpression = .{
                    .Flags = 0,
                    .Expression = self.transformer.factory.newIdentifier("WeakMap"),
                    .TypeArguments = null,
                    .Arguments = self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{}),
                } }) catch unreachable;
                storage_initializers.append(self.allocator, self.transformer.factory.newAssignmentExpression(field.storage, weak_map)) catch unreachable;
            }
            static_initializers.insert(self.allocator, 0, self.transformer.factory.inlineExpressions(storage_initializers.items)) catch unreachable;
        }

        if (instance_initializers.items.len > 0) {
            self.addInstanceInitializers(v, &new_members, instance_initializers.items) catch unreachable;
            changed = true;
        }

        if (changed) {
            const newMembersList = self.transformer.factory.newNodeList(new_members.items);
            if (nodeData == .ClassDeclaration) {
                const updated = self.transformer.factory.updateClassDeclaration(
                    node,
                    nodeData.ClassDeclaration,
                    v.visitModifiers(nodeData.ClassDeclaration.modifiers orelse 0),
                    v.visitNode(nodeData.ClassDeclaration.name orelse 0),
                    0,
                    v.visitNodes(nodeData.ClassDeclaration.HeritageClauses orelse 0),
                    newMembersList,
                );
                if (static_initializers.items.len == 0) return updated;
                var statements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
                defer statements.deinit(self.allocator);
                if (class_this_alias != 0) {
                    const declaration = self.transformer.factory.newVariableDeclaration(class_this_alias, 0, 0, 0);
                    const declarations = self.transformer.factory.newVariableDeclarationList(self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{declaration}), 0);
                    statements.append(self.allocator, self.transformer.factory.newVariableStatement(0, declarations)) catch unreachable;
                }
                statements.append(self.allocator, updated) catch unreachable;
                if (class_this_alias != 0) {
                    const class_name = ast_utils.cloneNode(tree, self.transformer.factory, ast_utils.name(tree, node));
                    statements.append(self.allocator, self.transformer.factory.newExpressionStatement(self.transformer.factory.newAssignmentExpression(class_this_alias, class_name))) catch unreachable;
                }
                for (static_initializers.items) |initializer| {
                    statements.append(self.allocator, self.transformer.factory.newExpressionStatement(initializer)) catch unreachable;
                }
                return self.transformer.factory.newSyntaxList(statements.items);
            } else {
                const updated = self.transformer.factory.updateClassExpression(
                    node,
                    nodeData.ClassExpression,
                    v.visitModifiers(nodeData.ClassExpression.modifiers orelse 0),
                    v.visitNode(nodeData.ClassExpression.name orelse 0),
                    0,
                    v.visitNodes(nodeData.ClassExpression.HeritageClauses orelse 0),
                    newMembersList,
                );
                if (static_initializers.items.len == 0) return updated;
                var expressions = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
                defer expressions.deinit(self.allocator);
                expressions.append(self.allocator, self.transformer.factory.newAssignmentExpression(class_this_alias, updated)) catch unreachable;
                if (self.inferred_class_name.len != 0) {
                    self.transformer.emitContext.requestEmitHelper(&helpers.setFunctionNameHelper);
                    const name_args = self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{ class_this_alias, self.transformer.factory.newStringLiteral(self.inferred_class_name, false) });
                    expressions.append(self.allocator, self.transformer.factory.newCallExpression(self.transformer.factory.newIdentifier("__setFunctionName"), 0, 0, name_args, 0)) catch unreachable;
                }
                expressions.appendSlice(self.allocator, static_initializers.items) catch unreachable;
                expressions.append(self.allocator, class_this_alias) catch unreachable;
                const expression = self.inlineMultilineExpressions(v.tree, expressions.items);
                if (self.nested_destructuring_array) return v.tree.pushNode(.{ .ParenthesizedExpression = .{ .Expression = expression, .Flags = 1 << 31 } }) catch unreachable;
                return self.transformer.factory.newParenthesizedExpression(expression);
            }
        }

        return v.visitEachChild(node);
    }

    fn rewritePrivateAccesses(self: *ClassFieldsTransformer, tree: *ast.Ast, node: ast_gen.NodeIndex, fields: anytype) ast_gen.NodeIndex {
        if (fields.len == 0) return node;
        const Rewriter = struct {
            owner: *ClassFieldsTransformer,
            fields: @TypeOf(fields),
            fn visit(ctx: ?*anyopaque, v: *visitor.NodeVisitor, child: ast_gen.NodeIndex) ast_gen.NodeIndex {
                const rw: *@This() = @ptrCast(@alignCast(ctx.?));
                if (v.tree.getNode(child) == .MethodDeclaration) {
                    var method = v.tree.getNode(child).MethodDeclaration;
                    if (method.Body) |body| method.Body = v.visitNode(body);
                    return v.tree.pushNode(.{ .MethodDeclaration = method }) catch unreachable;
                }
                if (v.tree.getNode(child) == .TaggedTemplateExpression) {
                    var tagged = v.tree.getNode(child).TaggedTemplateExpression;
                    const original_tag = tagged.Tag;
                    if (v.tree.getNode(original_tag) == .PropertyAccessExpression) {
                        const property = v.tree.getNode(original_tag).PropertyAccessExpression;
                        if (v.tree.getNode(property.name) == .PrivateIdentifier) {
                            const receiver = property.Expression;
                            const get_call = v.visitNode(original_tag);
                            const bind_access = rw.owner.transformer.factory.newPropertyAccessExpression(get_call, 0, rw.owner.transformer.factory.newIdentifier("bind"), 0);
                            tagged.Tag = rw.owner.transformer.factory.newCallExpression(bind_access, 0, 0, rw.owner.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{receiver}), 0);
                            tagged.Template = v.visitNode(tagged.Template);
                            return v.tree.pushNode(.{ .TaggedTemplateExpression = tagged }) catch unreachable;
                        }
                    }
                }
                if (v.tree.getNode(child) == .PropertyAccessExpression) {
                    const property = v.tree.getNode(child).PropertyAccessExpression;
                    if (v.tree.getNode(property.name) == .PrivateIdentifier) {
                        const raw = v.tree.getNode(property.name).PrivateIdentifier.Text;
                        for (rw.fields) |field| if (std.mem.eql(u8, field.name, raw)) {
                            rw.owner.transformer.emitContext.requestEmitHelper(&helpers.classPrivateFieldGetHelper);
                            const args = rw.owner.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{
                                v.visitNode(property.Expression),
                                field.storage,
                                rw.owner.transformer.factory.newStringLiteral("f", false),
                            });
                            return rw.owner.transformer.factory.newCallExpression(rw.owner.transformer.factory.newIdentifier("__classPrivateFieldGet"), 0, 0, args, 0);
                        };
                    }
                }
                return v.visitEachChild(child);
            }
        };
        var rw = Rewriter{ .owner = self, .fields = fields };
        var node_visitor = visitor.NodeVisitor.init(tree.allocator, tree, &rw, Rewriter.visit, .{});
        return node_visitor.visitNode(node);
    }

    fn inlineMultilineExpressions(self: *ClassFieldsTransformer, tree: *ast.Ast, expressions: []const ast_gen.NodeIndex) ast_gen.NodeIndex {
        var result = expressions[0];
        for (expressions[1..]) |expression| {
            const comma = self.transformer.factory.newToken(.{ .CommaToken = {} });
            const binary = self.transformer.factory.newBinaryExpression(0, result, 0, comma, expression);
            var data = tree.getNode(binary).BinaryExpression;
            data.linesAfterOperator = 1;
            result = tree.pushNode(.{ .BinaryExpression = data }) catch unreachable;
        }
        return result;
    }

    fn createFieldInitializer(self: *ClassFieldsTransformer, v: *visitor.NodeVisitor, class_node: ast_gen.NodeIndex, field_node: ast_gen.NodeIndex, computed_temp: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const name = ast_utils.name(tree, field_node);
        const receiver = if (ast_utils.isStatic(tree, field_node)) blk: {
            if (self.static_this_alias != 0 and tree.getNode(class_node) == .ClassExpression) break :blk self.static_this_alias;
            const class_name = ast_utils.name(tree, class_node);
            break :blk ast_utils.cloneNode(tree, self.transformer.factory, class_name);
        } else self.transformer.factory.newThisExpression();
        const left = switch (tree.getNode(name)) {
            .ComputedPropertyName => |n| self.transformer.factory.newElementAccessExpression(receiver, 0, if (computed_temp != 0) computed_temp else v.visitNode(n.Expression), 0),
            else => self.transformer.factory.newPropertyAccessExpression(receiver, 0, ast_utils.cloneNode(tree, self.transformer.factory, name), 0),
        };
        const initializer = v.visitNode(ast_utils.getInitializerOfNode(tree, field_node));
        const class_name_text = ast_utils.getText(tree, ast_utils.name(tree, class_node));
        return self.transformer.factory.newAssignmentExpression(left, replaceStaticReferences(tree, initializer, self.static_this_alias, class_name_text));
    }

    fn addInstanceInitializers(self: *ClassFieldsTransformer, v: *visitor.NodeVisitor, members: *std.ArrayListUnmanaged(ast_gen.NodeIndex), initializers: []const ast_gen.NodeIndex) !void {
        const tree = v.tree;
        for (members.items, 0..) |member, index| {
            if (tree.getNode(member) != .Constructor) continue;
            const constructor = tree.getNode(member).Constructor;
            const body_index = constructor.Body orelse 0;
            if (body_index == 0) continue;
            const body = tree.getNode(body_index).Block;
            var statements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
            defer statements.deinit(self.allocator);
            for (initializers) |initializer| try statements.append(self.allocator, self.transformer.factory.newExpressionStatement(initializer));
            try statements.appendSlice(self.allocator, tree.getNodeList(body.Statements));
            const new_body = self.transformer.factory.updateBlock(body_index, body, self.transformer.factory.newNodeList(statements.items), true);
            members.items[index] = self.transformer.factory.updateConstructorDeclaration(member, constructor, constructor.modifiers orelse 0, 0, constructor.Parameters, constructor.Type orelse 0, new_body);
            return;
        }

        var statements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer statements.deinit(self.allocator);
        for (initializers) |initializer| try statements.append(self.allocator, self.transformer.factory.newExpressionStatement(initializer));
        const body = self.transformer.factory.newBlock(self.transformer.factory.newNodeList(statements.items), true);
        const constructor = self.transformer.factory.newConstructorDeclaration(self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{}), body);
        try members.insert(self.allocator, 0, constructor);
    }
};

fn containsThis(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    if (tree.getNodeKind(node) == .ThisKeyword) return true;
    const Context = struct {
        tree: *ast.Ast,
        fn check(ctx: *@This(), child: ast_gen.NodeIndex) bool {
            return containsThis(ctx.tree, child);
        }
    };
    var context = Context{ .tree = tree };
    return ast_utils.forEachChildBool(tree, node, &context, Context.check);
}

fn replaceStaticReferences(tree: *ast.Ast, node: ast_gen.NodeIndex, alias: ast_gen.NodeIndex, class_name: []const u8) ast_gen.NodeIndex {
    if (alias == 0 or node == 0) return node;
    if (tree.getNodeKind(node) == .ThisKeyword) return alias;
    // The async transform runs after class fields and will recursively visit
    // the initializer. Its identifier substitution handles the generated
    // alias, while nested `this` nodes are rewritten here through a tiny
    // dedicated visitor.
    const Rewriter = struct {
        alias: ast_gen.NodeIndex,
        class_name: []const u8,
        fn visit(ctx: ?*anyopaque, v: *visitor.NodeVisitor, child: ast_gen.NodeIndex) ast_gen.NodeIndex {
            const self: *@This() = @ptrCast(@alignCast(ctx.?));
            if (v.tree.getNodeKind(child) == .ThisKeyword) return self.alias;
            if (v.tree.getNode(child) == .Identifier and std.mem.eql(u8, v.tree.getNode(child).Identifier.Text, self.class_name)) return self.alias;
            if (v.tree.getNode(child) == .PropertyAccessExpression) {
                var property = v.tree.getNode(child).PropertyAccessExpression;
                property.Expression = v.visitNode(property.Expression);
                return v.tree.pushNode(.{ .PropertyAccessExpression = property }) catch unreachable;
            }
            return v.visitEachChild(child);
        }
    };
    var rw = Rewriter{ .alias = alias, .class_name = class_name };
    var node_visitor = visitor.NodeVisitor.init(tree.allocator, tree, &rw, Rewriter.visit, .{});
    return node_visitor.visitNode(node);
}
