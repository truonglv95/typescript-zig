const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const ast_utils = @import("../../ast/ast_utils.zig");
const kind = @import("../../ast/kind.zig");
const core = @import("../../core/core.zig");
const helpers = @import("../../printer/helpers.zig");
const emitflags = @import("../../printer/emitflags.zig");
const transformer_mod = @import("../transformer.zig");
const visitor_mod = @import("../../ast/visitor.zig");

pub const AsyncTransformer = struct {
    transformer: *transformer_mod.Transformer,
    allocator: std.mem.Allocator,
    options: *core.CompilerOptions,
    lowering_body: bool = false,
    arguments_alias: ast.NodeIndex = 0,
    suppress_arguments_substitution: bool = false,
    arguments_replacements: usize = 0,

    capturedSuperProperties: ?std.StringHashMap(void) = null,
    hasSuperElementAccess: bool = false,
    hasSuperPropertyAssignment: bool = false,
    superBinding: ast.NodeIndex = 0,
    superIndexBinding: ast.NodeIndex = 0,

    pub fn new(allocator: std.mem.Allocator, opt: *transformer_mod.TransformOptions) !*transformer_mod.Transformer {
        const tx = try allocator.create(AsyncTransformer);
        tx.allocator = allocator;
        tx.options = opt.compilerOptions;
        tx.lowering_body = false;
        tx.arguments_alias = 0;
        tx.suppress_arguments_substitution = false;
        tx.arguments_replacements = 0;
        tx.capturedSuperProperties = null;
        tx.hasSuperElementAccess = false;
        tx.hasSuperPropertyAssignment = false;
        tx.superBinding = 0;
        tx.superIndexBinding = 0;
        tx.transformer = try transformer_mod.Transformer.init(allocator, visit, tx, opt.context);
        return tx.transformer;
    }

    fn visit(ctx: ?*anyopaque, v: *visitor_mod.NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        const self: *AsyncTransformer = @ptrCast(@alignCast(ctx.?));
        if (node == 0) return 0;
        const target = self.options.target orelse .ES2025;
        if (@intFromEnum(target) >= @intFromEnum(core.ScriptTarget.ES2017)) return v.visitEachChild(node);
        return switch (v.tree.getNode(node)) {
            .AwaitExpression => |n| if (self.lowering_body) self.transformer.factory.newYieldExpression(v.visitNode(n.Expression)) else v.visitEachChild(node),
            .Identifier => |n| self.visitIdentifier(node, n),
            .PropertyAssignment => |n| self.visitPropertyAssignment(v, n),
            .BindingElement => |n| self.visitBindingElement(v, n),
            .FunctionDeclaration => |n| self.visitFunction(v, node, n),
            .MethodDeclaration => |n| self.visitMethod(v, node, n),
            .Constructor => |n| self.visitConstructor(v, node, n),
            .GetAccessor => |n| self.visitGetAccessor(v, node, n),
            .SetAccessor => |n| self.visitSetAccessor(v, node, n),
            .ArrowFunction => |n| self.transformArrow(v, node, n),
            else => if (self.lowering_body) self.visitLoweringBody(v, node) else v.visitEachChild(node),
        };
    }

    fn visitIdentifier(self: *AsyncTransformer, node: ast.NodeIndex, data: ast_gen.IdentifierNode) ast.NodeIndex {
        if (self.lowering_body and !self.suppress_arguments_substitution and self.arguments_alias != 0 and std.mem.eql(u8, data.Text, "arguments")) {
            self.arguments_replacements += 1;
            return self.arguments_alias;
        }
        return node;
    }

    fn visitPropertyAssignment(self: *AsyncTransformer, v: *visitor_mod.NodeVisitor, data: ast_gen.PropertyAssignmentNode) ast.NodeIndex {
        const previous = self.suppress_arguments_substitution;
        self.suppress_arguments_substitution = true;
        const name = v.visitNode(data.name);
        self.suppress_arguments_substitution = previous;
        var updated = data;
        updated.name = name;
        updated.Initializer = v.visitNode(data.Initializer);
        return v.tree.pushNode(.{ .PropertyAssignment = updated }) catch unreachable;
    }

    fn visitBindingElement(self: *AsyncTransformer, v: *visitor_mod.NodeVisitor, data: ast_gen.BindingElementNode) ast.NodeIndex {
        var updated = data;
        const previous = self.suppress_arguments_substitution;
        self.suppress_arguments_substitution = true;
        if (data.PropertyName) |name| updated.PropertyName = v.visitNode(name);
        self.suppress_arguments_substitution = previous;
        if (data.name) |name| updated.name = v.visitNode(name);
        if (data.Initializer) |initializer| updated.Initializer = v.visitNode(initializer);
        return v.tree.pushNode(.{ .BindingElement = updated }) catch unreachable;
    }

    fn visitFunction(self: *AsyncTransformer, v: *visitor_mod.NodeVisitor, node: ast.NodeIndex, data: ast_gen.FunctionDeclarationNode) ast.NodeIndex {
        if (hasAsyncModifier(v.tree, data.modifiers orelse 0)) {
            return self.transformFunction(v, node, data);
        }

        const savedCapturedSuperProperties = self.capturedSuperProperties;
        const savedHasSuperElementAccess = self.hasSuperElementAccess;
        const savedHasSuperPropertyAssignment = self.hasSuperPropertyAssignment;
        const savedSuperBinding = self.superBinding;
        const savedSuperIndexBinding = self.superIndexBinding;
        const savedLoweringBody = self.lowering_body;

        self.capturedSuperProperties = null;
        self.lowering_body = false;

        const body = v.visitNode(data.Body orelse 0);

        self.capturedSuperProperties = savedCapturedSuperProperties;
        self.hasSuperElementAccess = savedHasSuperElementAccess;
        self.hasSuperPropertyAssignment = savedHasSuperPropertyAssignment;
        self.superBinding = savedSuperBinding;
        self.superIndexBinding = savedSuperIndexBinding;
        self.lowering_body = savedLoweringBody;

        return self.transformer.factory.updateFunctionDeclaration(
            node,
            data,
            v.visitModifiers(data.modifiers orelse 0),
            data.AsteriskToken orelse 0,
            v.visitNode(data.name orelse 0),
            0,
            v.visitNodes(data.Parameters),
            0,
            body,
        );
    }

    fn transformFunction(self: *AsyncTransformer, v: *visitor_mod.NodeVisitor, node: ast.NodeIndex, data: ast_gen.FunctionDeclarationNode) ast.NodeIndex {
        const savedCapturedSuperProperties = self.capturedSuperProperties;
        const savedHasSuperElementAccess = self.hasSuperElementAccess;
        const savedHasSuperPropertyAssignment = self.hasSuperPropertyAssignment;
        const savedSuperBinding = self.superBinding;
        const savedSuperIndexBinding = self.superIndexBinding;

        self.capturedSuperProperties = null;

        const has_simple_params = isSimpleParameterList(v.tree, data.Parameters);
        var outerParameters = data.Parameters;
        var innerParameters: ast.NodeIndex = 0;
        var argumentsExpression: ast.NodeIndex = 0;

        if (!has_simple_params) {
            innerParameters = data.Parameters;

            var outerParametersList = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            defer outerParametersList.deinit(self.allocator);
            const params = v.tree.getNodeList(data.Parameters);
            for (params) |param_idx| {
                const param = v.tree.getNode(param_idx).Parameter;
                if (param.Initializer != 0 or param.DotDotDotToken != null) {
                    break;
                }
                const genName = self.transformer.factory.newUniqueName("param");
                const newParam = self.transformer.factory.newParameterDeclaration(0, 0, genName, 0, 0, 0);
                outerParametersList.append(self.allocator, newParam) catch unreachable;
            }
            outerParameters = self.transformer.factory.newNodeList(outerParametersList.items);
            argumentsExpression = self.transformer.factory.newIdentifier("arguments");
        } else {
            outerParameters = v.visitNodes(data.Parameters);
        }

        const body = self.createAsyncBody(v, data.Body orelse 0, innerParameters, argumentsExpression);

        self.capturedSuperProperties = savedCapturedSuperProperties;
        self.hasSuperElementAccess = savedHasSuperElementAccess;
        self.hasSuperPropertyAssignment = savedHasSuperPropertyAssignment;
        self.superBinding = savedSuperBinding;
        self.superIndexBinding = savedSuperIndexBinding;

        return self.transformer.factory.updateFunctionDeclaration(
            node,
            data,
            self.withoutAsync(v, data.modifiers orelse 0),
            data.AsteriskToken orelse 0,
            v.visitNode(data.name orelse 0),
            0,
            outerParameters,
            0,
            body,
        );
    }

    fn visitMethod(self: *AsyncTransformer, v: *visitor_mod.NodeVisitor, node: ast.NodeIndex, data: ast_gen.MethodDeclarationNode) ast.NodeIndex {
        if (hasAsyncModifier(v.tree, data.modifiers orelse 0)) {
            return self.transformMethod(v, node, data);
        }

        const savedCapturedSuperProperties = self.capturedSuperProperties;
        const savedHasSuperElementAccess = self.hasSuperElementAccess;
        const savedHasSuperPropertyAssignment = self.hasSuperPropertyAssignment;
        const savedSuperBinding = self.superBinding;
        const savedSuperIndexBinding = self.superIndexBinding;
        const savedLoweringBody = self.lowering_body;

        var capProps = std.StringHashMap(void).init(self.allocator);
        self.capturedSuperProperties = capProps;
        self.hasSuperElementAccess = false;
        self.hasSuperPropertyAssignment = false;
        self.superBinding = self.transformer.factory.newIdentifier("_super");
        self.superIndexBinding = self.transformer.factory.newIdentifier("_superIndex");
        self.lowering_body = false;

        const body = v.visitNode(data.Body orelse 0);

        const emitSuperHelpers = (self.capturedSuperProperties.?.count() > 0 or self.hasSuperElementAccess);

        var final_body = body;
        if (emitSuperHelpers and body != 0) {
            if (self.capturedSuperProperties.?.count() > 0) {
                const super_stmt = self.createSuperAccessVariableStatement();

                const block_data = v.tree.getNode(body).Block;
                const original_stmts = v.tree.getNodeList(block_data.Statements);
                var new_stmts = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer new_stmts.deinit(self.allocator);
                new_stmts.append(self.allocator, super_stmt) catch unreachable;
                new_stmts.appendSlice(self.allocator, original_stmts) catch unreachable;

                const new_list = self.transformer.factory.newNodeList(new_stmts.items);
                final_body = self.transformer.factory.updateBlock(body, block_data, new_list, block_data.MultiLine);
            }
        }

        capProps.deinit();
        self.capturedSuperProperties = savedCapturedSuperProperties;
        self.hasSuperElementAccess = savedHasSuperElementAccess;
        self.hasSuperPropertyAssignment = savedHasSuperPropertyAssignment;
        self.superBinding = savedSuperBinding;
        self.superIndexBinding = savedSuperIndexBinding;
        self.lowering_body = savedLoweringBody;

        return self.transformer.factory.updateMethodDeclaration(
            node,
            data,
            v.visitModifiers(data.modifiers orelse 0),
            data.AsteriskToken orelse 0,
            v.visitNode(data.name),
            0,
            0,
            v.visitNodes(data.Parameters),
            0,
            final_body,
        );
    }

    fn transformMethod(self: *AsyncTransformer, v: *visitor_mod.NodeVisitor, node: ast.NodeIndex, data: ast_gen.MethodDeclarationNode) ast.NodeIndex {
        const savedCapturedSuperProperties = self.capturedSuperProperties;
        const savedHasSuperElementAccess = self.hasSuperElementAccess;
        const savedHasSuperPropertyAssignment = self.hasSuperPropertyAssignment;
        const savedSuperBinding = self.superBinding;
        const savedSuperIndexBinding = self.superIndexBinding;

        var capProps = std.StringHashMap(void).init(self.allocator);
        self.capturedSuperProperties = capProps;
        self.hasSuperElementAccess = false;
        self.hasSuperPropertyAssignment = false;
        self.superBinding = self.transformer.factory.newIdentifier("_super");
        self.superIndexBinding = self.transformer.factory.newIdentifier("_superIndex");

        const has_simple_params = isSimpleParameterList(v.tree, data.Parameters);
        var outerParameters = data.Parameters;
        var innerParameters: ast.NodeIndex = 0;
        var argumentsExpression: ast.NodeIndex = 0;

        if (!has_simple_params) {
            innerParameters = data.Parameters;

            var outerParametersList = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            defer outerParametersList.deinit(self.allocator);
            const params = v.tree.getNodeList(data.Parameters);
            for (params) |param_idx| {
                const param = v.tree.getNode(param_idx).Parameter;
                if (param.Initializer != 0 or param.DotDotDotToken != null) {
                    break;
                }
                const genName = self.transformer.factory.newUniqueName("param");
                const newParam = self.transformer.factory.newParameterDeclaration(0, 0, genName, 0, 0, 0);
                outerParametersList.append(self.allocator, newParam) catch unreachable;
            }
            outerParameters = self.transformer.factory.newNodeList(outerParametersList.items);
            argumentsExpression = self.transformer.factory.newIdentifier("arguments");
        } else {
            outerParameters = v.visitNodes(data.Parameters);
        }

        const body = self.createAsyncBody(v, data.Body orelse 0, innerParameters, argumentsExpression);

        const emitSuperHelpers = (self.capturedSuperProperties.?.count() > 0 or self.hasSuperElementAccess);

        var final_body = body;
        if (emitSuperHelpers and body != 0) {
            if (self.capturedSuperProperties.?.count() > 0) {
                const super_stmt = self.createSuperAccessVariableStatement();

                const block_data = v.tree.getNode(body).Block;
                const original_stmts = v.tree.getNodeList(block_data.Statements);
                var new_stmts = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer new_stmts.deinit(self.allocator);
                new_stmts.append(self.allocator, super_stmt) catch unreachable;
                new_stmts.appendSlice(self.allocator, original_stmts) catch unreachable;

                const new_list = self.transformer.factory.newNodeList(new_stmts.items);
                final_body = self.transformer.factory.updateBlock(body, block_data, new_list, block_data.MultiLine);
            }
        }

        capProps.deinit();
        self.capturedSuperProperties = savedCapturedSuperProperties;
        self.hasSuperElementAccess = savedHasSuperElementAccess;
        self.hasSuperPropertyAssignment = savedHasSuperPropertyAssignment;
        self.superBinding = savedSuperBinding;
        self.superIndexBinding = savedSuperIndexBinding;

        return self.transformer.factory.updateMethodDeclaration(
            node,
            data,
            self.withoutAsync(v, data.modifiers orelse 0),
            data.AsteriskToken orelse 0,
            v.visitNode(data.name),
            0,
            0,
            outerParameters,
            0,
            final_body,
        );
    }

    fn visitConstructor(self: *AsyncTransformer, v: *visitor_mod.NodeVisitor, node: ast.NodeIndex, data: ast_gen.ConstructorDeclarationNode) ast.NodeIndex {
        const savedCapturedSuperProperties = self.capturedSuperProperties;
        const savedHasSuperElementAccess = self.hasSuperElementAccess;
        const savedHasSuperPropertyAssignment = self.hasSuperPropertyAssignment;
        const savedSuperBinding = self.superBinding;
        const savedSuperIndexBinding = self.superIndexBinding;
        const savedLoweringBody = self.lowering_body;

        var capProps = std.StringHashMap(void).init(self.allocator);
        self.capturedSuperProperties = capProps;
        self.hasSuperElementAccess = false;
        self.hasSuperPropertyAssignment = false;
        self.superBinding = self.transformer.factory.newIdentifier("_super");
        self.superIndexBinding = self.transformer.factory.newIdentifier("_superIndex");
        self.lowering_body = false;

        const body = v.visitNode(data.Body orelse 0);

        const emitSuperHelpers = (self.capturedSuperProperties.?.count() > 0 or self.hasSuperElementAccess);

        var final_body = body;
        if (emitSuperHelpers and body != 0) {
            if (self.capturedSuperProperties.?.count() > 0) {
                const super_stmt = self.createSuperAccessVariableStatement();

                const block_data = v.tree.getNode(body).Block;
                const original_stmts = v.tree.getNodeList(block_data.Statements);
                var new_stmts = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer new_stmts.deinit(self.allocator);
                new_stmts.append(self.allocator, super_stmt) catch unreachable;
                new_stmts.appendSlice(self.allocator, original_stmts) catch unreachable;

                const new_list = self.transformer.factory.newNodeList(new_stmts.items);
                final_body = self.transformer.factory.updateBlock(body, block_data, new_list, block_data.MultiLine);
            }
        }

        capProps.deinit();
        self.capturedSuperProperties = savedCapturedSuperProperties;
        self.hasSuperElementAccess = savedHasSuperElementAccess;
        self.hasSuperPropertyAssignment = savedHasSuperPropertyAssignment;
        self.superBinding = savedSuperBinding;
        self.superIndexBinding = savedSuperIndexBinding;
        self.lowering_body = savedLoweringBody;

        return self.transformer.factory.updateConstructorDeclaration(
            node,
            data,
            v.visitModifiers(data.modifiers orelse 0),
            0,
            v.visitNodes(data.Parameters),
            0,
            final_body,
        );
    }

    fn visitGetAccessor(self: *AsyncTransformer, v: *visitor_mod.NodeVisitor, node: ast.NodeIndex, data: ast_gen.GetAccessorDeclarationNode) ast.NodeIndex {
        const savedCapturedSuperProperties = self.capturedSuperProperties;
        const savedHasSuperElementAccess = self.hasSuperElementAccess;
        const savedHasSuperPropertyAssignment = self.hasSuperPropertyAssignment;
        const savedSuperBinding = self.superBinding;
        const savedSuperIndexBinding = self.superIndexBinding;
        const savedLoweringBody = self.lowering_body;

        var capProps = std.StringHashMap(void).init(self.allocator);
        self.capturedSuperProperties = capProps;
        self.hasSuperElementAccess = false;
        self.hasSuperPropertyAssignment = false;
        self.superBinding = self.transformer.factory.newIdentifier("_super");
        self.superIndexBinding = self.transformer.factory.newIdentifier("_superIndex");
        self.lowering_body = false;

        const body = v.visitNode(data.Body orelse 0);

        const emitSuperHelpers = (self.capturedSuperProperties.?.count() > 0 or self.hasSuperElementAccess);

        var final_body = body;
        if (emitSuperHelpers and body != 0) {
            if (self.capturedSuperProperties.?.count() > 0) {
                const super_stmt = self.createSuperAccessVariableStatement();

                const block_data = v.tree.getNode(body).Block;
                const original_stmts = v.tree.getNodeList(block_data.Statements);
                var new_stmts = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer new_stmts.deinit(self.allocator);
                new_stmts.append(self.allocator, super_stmt) catch unreachable;
                new_stmts.appendSlice(self.allocator, original_stmts) catch unreachable;

                const new_list = self.transformer.factory.newNodeList(new_stmts.items);
                final_body = self.transformer.factory.updateBlock(body, block_data, new_list, block_data.MultiLine);
            }
        }

        capProps.deinit();
        self.capturedSuperProperties = savedCapturedSuperProperties;
        self.hasSuperElementAccess = savedHasSuperElementAccess;
        self.hasSuperPropertyAssignment = savedHasSuperPropertyAssignment;
        self.superBinding = savedSuperBinding;
        self.superIndexBinding = savedSuperIndexBinding;
        self.lowering_body = savedLoweringBody;

        return self.transformer.factory.updateGetAccessorDeclaration(
            node,
            data,
            v.visitModifiers(data.modifiers orelse 0),
            v.visitNode(data.name),
            0,
            v.visitNodes(data.Parameters),
            0,
            final_body,
        );
    }

    fn visitSetAccessor(self: *AsyncTransformer, v: *visitor_mod.NodeVisitor, node: ast.NodeIndex, data: ast_gen.SetAccessorDeclarationNode) ast.NodeIndex {
        const savedCapturedSuperProperties = self.capturedSuperProperties;
        const savedHasSuperElementAccess = self.hasSuperElementAccess;
        const savedHasSuperPropertyAssignment = self.hasSuperPropertyAssignment;
        const savedSuperBinding = self.superBinding;
        const savedSuperIndexBinding = self.superIndexBinding;
        const savedLoweringBody = self.lowering_body;

        var capProps = std.StringHashMap(void).init(self.allocator);
        self.capturedSuperProperties = capProps;
        self.hasSuperElementAccess = false;
        self.hasSuperPropertyAssignment = false;
        self.superBinding = self.transformer.factory.newIdentifier("_super");
        self.superIndexBinding = self.transformer.factory.newIdentifier("_superIndex");
        self.lowering_body = false;

        const body = v.visitNode(data.Body orelse 0);

        const emitSuperHelpers = (self.capturedSuperProperties.?.count() > 0 or self.hasSuperElementAccess);

        var final_body = body;
        if (emitSuperHelpers and body != 0) {
            if (self.capturedSuperProperties.?.count() > 0) {
                const super_stmt = self.createSuperAccessVariableStatement();

                const block_data = v.tree.getNode(body).Block;
                const original_stmts = v.tree.getNodeList(block_data.Statements);
                var new_stmts = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer new_stmts.deinit(self.allocator);
                new_stmts.append(self.allocator, super_stmt) catch unreachable;
                new_stmts.appendSlice(self.allocator, original_stmts) catch unreachable;

                const new_list = self.transformer.factory.newNodeList(new_stmts.items);
                final_body = self.transformer.factory.updateBlock(body, block_data, new_list, block_data.MultiLine);
            }
        }

        capProps.deinit();
        self.capturedSuperProperties = savedCapturedSuperProperties;
        self.hasSuperElementAccess = savedHasSuperElementAccess;
        self.hasSuperPropertyAssignment = savedHasSuperPropertyAssignment;
        self.superBinding = savedSuperBinding;
        self.superIndexBinding = savedSuperIndexBinding;
        self.lowering_body = savedLoweringBody;

        return self.transformer.factory.updateSetAccessorDeclaration(
            node,
            data,
            v.visitModifiers(data.modifiers orelse 0),
            v.visitNode(data.name),
            0,
            v.visitNodes(data.Parameters),
            0,
            final_body,
        );
    }

    fn transformArrow(self: *AsyncTransformer, v: *visitor_mod.NodeVisitor, node: ast.NodeIndex, data: ast_gen.ArrowFunctionNode) ast.NodeIndex {
        if (!hasAsyncModifier(v.tree, data.modifiers orelse 0)) {
            return v.visitEachChild(node);
        }

        var generator_body = data.Body orelse 0;
        if (v.tree.getNode(generator_body) != .Block) {
            generator_body = self.transformer.factory.newBlock(
                self.transformer.factory.newNodeList(&[_]ast.NodeIndex{self.transformer.factory.newReturnStatement(generator_body)}),
                true,
            );
        }

        const has_simple_params = isSimpleParameterList(v.tree, data.Parameters);
        var outerParameters = data.Parameters;
        var innerParameters: ast.NodeIndex = 0;
        var argumentsExpression: ast.NodeIndex = 0;

        if (!has_simple_params) {
            innerParameters = data.Parameters;

            var outerParametersList = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            defer outerParametersList.deinit(self.allocator);
            const params = v.tree.getNodeList(data.Parameters);
            for (params) |param_idx| {
                const param = v.tree.getNode(param_idx).Parameter;
                if (param.Initializer != 0 or param.DotDotDotToken != null) {
                    const argsId = self.transformer.factory.newUniqueName("args");
                    const dotDotDot = self.transformer.factory.newToken(.{ .DotDotDotToken = {} });
                    const restParam = self.transformer.factory.newParameterDeclaration(0, dotDotDot, argsId, 0, 0, 0);
                    outerParametersList.append(self.allocator, restParam) catch unreachable;
                    break;
                }
                const genName = self.transformer.factory.newUniqueName("param");
                const newParam = self.transformer.factory.newParameterDeclaration(0, 0, genName, 0, 0, 0);
                outerParametersList.append(self.allocator, newParam) catch unreachable;
            }
            outerParameters = self.transformer.factory.newNodeList(outerParametersList.items);

            var bindings = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            defer bindings.deinit(self.allocator);
            for (params, 0..) |param_idx, i| {
                if (i >= outerParametersList.items.len) break;
                const param = v.tree.getNode(param_idx).Parameter;
                const outerParam = v.tree.getNode(outerParametersList.items[i]).Parameter;
                if (param.Initializer != 0 or param.DotDotDotToken != null) {
                    const spread = self.transformer.factory.newSpreadElement(outerParam.name);
                    bindings.append(self.allocator, spread) catch unreachable;
                    break;
                }
                bindings.append(self.allocator, outerParam.name) catch unreachable;
            }
            argumentsExpression = self.transformer.factory.newArrayLiteralExpression(self.transformer.factory.newNodeList(bindings.items), false);
        } else {
            outerParameters = v.visitNodes(data.Parameters);
        }

        const call = self.createAwaiterCall(v, generator_body, true, innerParameters, argumentsExpression);
        return self.transformer.factory.updateArrowFunction(node, data, self.withoutAsync(v, data.modifiers orelse 0), 0, outerParameters, 0, data.EqualsGreaterThanToken, call);
    }

    fn visitLoweringBody(self: *AsyncTransformer, v: *visitor_mod.NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        self.trackSuperAccess(node);

        const node_data = v.tree.getNode(node);
        switch (node_data) {
            .CallExpression => |n| {
                if (ast_utils.getKind(v.tree, n.Expression) == .PropertyAccessExpression) {
                    const prop = v.tree.getNode(n.Expression).PropertyAccessExpression;
                    if (ast_utils.getKind(v.tree, prop.Expression) == .SuperKeyword) {
                        const target = self.transformer.factory.newPropertyAccessExpression(self.superBinding, 0, prop.name, 0);
                        const call_id = self.transformer.factory.newIdentifier("call");
                        const callTarget = self.transformer.factory.newPropertyAccessExpression(target, 0, call_id, 0);

                        var args = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                        defer args.deinit(self.allocator);
                        const thisExpr = self.transformer.factory.newThisExpression();
                        args.append(self.allocator, thisExpr) catch unreachable;
                        if (n.Arguments != 0) {
                            for (v.tree.getNodeList(n.Arguments)) |arg| {
                                args.append(self.allocator, v.visitNode(arg)) catch unreachable;
                            }
                        }

                        const args_list = self.transformer.factory.newNodeList(args.items);
                        return self.transformer.factory.newCallExpression(callTarget, 0, 0, args_list, 0);
                    }
                } else if (ast_utils.getKind(v.tree, n.Expression) == .ElementAccessExpression) {
                    const elem = v.tree.getNode(n.Expression).ElementAccessExpression;
                    if (ast_utils.getKind(v.tree, elem.Expression) == .SuperKeyword) {
                        const target = self.createSuperElementAccessInAsyncMethod(elem.ArgumentExpression);
                        const call_id = self.transformer.factory.newIdentifier("call");
                        const callTarget = self.transformer.factory.newPropertyAccessExpression(target, 0, call_id, 0);

                        var args = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                        defer args.deinit(self.allocator);
                        const thisExpr = self.transformer.factory.newThisExpression();
                        args.append(self.allocator, thisExpr) catch unreachable;
                        if (n.Arguments != 0) {
                            for (v.tree.getNodeList(n.Arguments)) |arg| {
                                args.append(self.allocator, v.visitNode(arg)) catch unreachable;
                            }
                        }

                        const args_list = self.transformer.factory.newNodeList(args.items);
                        return self.transformer.factory.newCallExpression(callTarget, 0, 0, args_list, 0);
                    }
                }
            },
            .PropertyAccessExpression => |n| {
                if (ast_utils.getKind(v.tree, n.Expression) == .SuperKeyword) {
                    return self.transformer.factory.newPropertyAccessExpression(self.superBinding, 0, n.name, 0);
                }
            },
            .ElementAccessExpression => |n| {
                if (ast_utils.getKind(v.tree, n.Expression) == .SuperKeyword) {
                    return self.createSuperElementAccessInAsyncMethod(n.ArgumentExpression);
                }
            },
            else => {},
        }

        return v.visitEachChild(node);
    }

    fn createAsyncBody(self: *AsyncTransformer, v: *visitor_mod.NodeVisitor, body: ast.NodeIndex, innerParameters: ast.NodeIndex, argumentsExpression: ast.NodeIndex) ast.NodeIndex {
        const previous_alias = self.arguments_alias;
        const previous_replacements = self.arguments_replacements;
        self.arguments_alias = self.transformer.factory.newIdentifier("arguments_1");
        self.arguments_replacements = 0;
        const call = self.createAwaiterCall(v, body, false, innerParameters, argumentsExpression);
        const captures_arguments = self.arguments_replacements != 0;
        const alias = self.arguments_alias;
        self.arguments_alias = previous_alias;
        self.arguments_replacements = previous_replacements;
        var statements = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer statements.deinit(self.allocator);
        if (captures_arguments) {
            const declaration = self.transformer.factory.newVariableDeclaration(alias, 0, 0, self.transformer.factory.newIdentifier("arguments"));
            const list = self.transformer.factory.newVariableDeclarationList(self.transformer.factory.newNodeList(&[_]ast.NodeIndex{declaration}), 0);
            statements.append(self.allocator, self.transformer.factory.newVariableStatement(0, list)) catch unreachable;
        }
        statements.append(self.allocator, self.transformer.factory.newReturnStatement(call)) catch unreachable;
        return self.transformer.factory.newBlock(
            self.transformer.factory.newNodeList(statements.items),
            true,
        );
    }

    fn createAwaiterCall(self: *AsyncTransformer, v: *visitor_mod.NodeVisitor, body: ast.NodeIndex, arrow: bool, innerParameters: ast.NodeIndex, argumentsExpression: ast.NodeIndex) ast.NodeIndex {
        const previous = self.lowering_body;
        self.lowering_body = true;

        const visited_inner_params = if (innerParameters != 0) v.visitNodes(innerParameters) else 0;
        const visited_body = v.visitNode(body);

        self.lowering_body = previous;
        const asterisk = self.transformer.factory.newToken(.{ .AsteriskToken = {} });
        const generator = self.transformer.factory.newFunctionExpression(0, asterisk, 0, 0, visited_inner_params, 0, 0, visited_body);
        if (arrow) self.transformer.emitContext.addEmitFlags(visited_body, emitflags.EmitFlags.SingleLine) catch unreachable;

        const second_arg = if (argumentsExpression != 0) argumentsExpression else self.transformer.factory.newVoidZeroExpression();
        const args = [_]ast.NodeIndex{
            if (arrow and self.capturedSuperProperties == null) self.transformer.factory.newVoidZeroExpression() else self.transformer.factory.newThisExpression(),
            second_arg,
            self.transformer.factory.newVoidZeroExpression(),
            generator,
        };
        self.transformer.emitContext.requestEmitHelper(&helpers.awaiterHelper);
        return self.transformer.factory.newCallExpression(self.transformer.factory.newIdentifier("__awaiter"), 0, 0, self.transformer.factory.newNodeList(&args), 0);
    }

    fn withoutAsync(self: *AsyncTransformer, v: *visitor_mod.NodeVisitor, modifiers: ast.NodeIndex) ast.NodeIndex {
        if (modifiers == 0) return 0;
        var result = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer result.deinit(self.allocator);
        for (v.tree.getNodeList(modifiers)) |modifier| {
            if (v.tree.getNodeKind(modifier) != .AsyncKeyword) result.append(self.allocator, v.visitNode(modifier)) catch unreachable;
        }
        return if (result.items.len == 0) 0 else self.transformer.factory.newModifierList(result.items);
    }

    fn trackSuperAccess(self: *AsyncTransformer, node: ast.NodeIndex) void {
        if (self.capturedSuperProperties == null) {
            return;
        }
        const tree = self.transformer.emitContext.tree;
        const node_data = tree.getNode(node);
        switch (node_data) {
            .CallExpression => |n| {
                if (ast_utils.getKind(tree, n.Expression) == .PropertyAccessExpression) {
                    const prop = tree.getNode(n.Expression).PropertyAccessExpression;
                    if (ast_utils.getKind(tree, prop.Expression) == .SuperKeyword) {
                        const prop_name = ast_utils.getTextOfNode(tree, prop.name);
                        self.capturedSuperProperties.?.put(prop_name, {}) catch unreachable;
                    }
                } else if (ast_utils.getKind(tree, n.Expression) == .ElementAccessExpression) {
                    const elem = tree.getNode(n.Expression).ElementAccessExpression;
                    if (ast_utils.getKind(tree, elem.Expression) == .SuperKeyword) {
                        self.hasSuperElementAccess = true;
                    }
                }
            },
            .PropertyAccessExpression => |n| {
                if (ast_utils.getKind(tree, n.Expression) == .SuperKeyword) {
                    const prop_name = ast_utils.getTextOfNode(tree, n.name);
                    self.capturedSuperProperties.?.put(prop_name, {}) catch unreachable;
                }
            },
            .ElementAccessExpression => |n| {
                if (ast_utils.getKind(tree, n.Expression) == .SuperKeyword) {
                    self.hasSuperElementAccess = true;
                }
            },
            .BinaryExpression => |n| {
                if (ast_utils.isAssignmentOperator(ast_utils.getKind(tree, n.OperatorToken)) and self.assignmentTargetContainsSuperProperty(n.Left)) {
                    self.hasSuperPropertyAssignment = true;
                }
            },
            .PrefixUnaryExpression => |n| {
                if (isUpdateExpression(tree, node) and self.assignmentTargetContainsSuperProperty(n.Operand)) {
                    self.hasSuperPropertyAssignment = true;
                }
            },
            .PostfixUnaryExpression => |n| {
                if (isUpdateExpression(tree, node) and self.assignmentTargetContainsSuperProperty(n.Operand)) {
                    self.hasSuperPropertyAssignment = true;
                }
            },
            else => {},
        }
    }

    fn assignmentTargetContainsSuperProperty(self: *AsyncTransformer, node: ast.NodeIndex) bool {
        if (node == 0) return false;
        const tree = self.transformer.emitContext.tree;
        const kind_val = ast_utils.getKind(tree, node);
        switch (kind_val) {
            .PropertyAccessExpression => {
                const expr = tree.getNode(node).PropertyAccessExpression.Expression;
                return ast_utils.getKind(tree, expr) == .SuperKeyword;
            },
            .ElementAccessExpression => {
                const expr = tree.getNode(node).ElementAccessExpression.Expression;
                return ast_utils.getKind(tree, expr) == .SuperKeyword;
            },
            .ParenthesizedExpression => {
                const expr = tree.getNode(node).ParenthesizedExpression.Expression;
                return self.assignmentTargetContainsSuperProperty(expr);
            },
            .ArrayLiteralExpression => {
                const elements = tree.getNode(node).ArrayLiteralExpression.Elements;
                for (tree.getNodeList(elements)) |elem| {
                    if (self.assignmentTargetContainsSuperProperty(elem)) return true;
                }
            },
            .ObjectLiteralExpression => {
                const properties = tree.getNode(node).ObjectLiteralExpression.Properties;
                for (tree.getNodeList(properties)) |prop| {
                    const prop_kind = ast_utils.getKind(tree, prop);
                    switch (prop_kind) {
                        .PropertyAssignment => {
                            if (self.assignmentTargetContainsSuperProperty(tree.getNode(prop).PropertyAssignment.Initializer)) return true;
                        },
                        .ShorthandPropertyAssignment => {
                            if (self.assignmentTargetContainsSuperProperty(tree.getNode(prop).ShorthandPropertyAssignment.name)) return true;
                        },
                        .SpreadAssignment => {
                            if (self.assignmentTargetContainsSuperProperty(tree.getNode(prop).SpreadAssignment.Expression)) return true;
                        },
                        else => {},
                    }
                }
            },
            .SpreadElement => {
                return self.assignmentTargetContainsSuperProperty(tree.getNode(node).SpreadElement.Expression);
            },
            else => {},
        }
        return false;
    }

    fn createSuperAccessVariableStatement(self: *AsyncTransformer) ast.NodeIndex {
        const f = self.transformer.factory;

        var accessors = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer accessors.deinit(self.allocator);

        var it = self.capturedSuperProperties.?.keyIterator();
        while (it.next()) |name_ptr| {
            const name = name_ptr.*;

            var descriptorProperties = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            defer descriptorProperties.deinit(self.allocator);

            const superKeyword = f.newKeywordExpression(.SuperKeyword);
            const superPropId = f.newIdentifier(name);
            const getterBody = f.newPropertyAccessExpression(superKeyword, 0, superPropId, 0);

            const emptyParams = f.newNodeList(&[_]ast.NodeIndex{});
            const equalsGreaterThan = f.newToken(.{ .EqualsGreaterThanToken = {} });
            const getterArrow = f.newArrowFunction(0, 0, emptyParams, 0, equalsGreaterThan, getterBody);

            const getId = f.newIdentifier("get");
            const getter = f.newPropertyAssignment(0, getId, 0, 0, getterArrow);
            descriptorProperties.append(self.allocator, getter) catch unreachable;

            if (self.hasSuperPropertyAssignment) {
                const vId = f.newIdentifier("v");
                const vParam = f.newParameterDeclaration(0, 0, vId, 0, 0, 0);
                const setterParams = f.newNodeList(&[_]ast.NodeIndex{vParam});

                const superProp = f.newPropertyAccessExpression(f.newKeywordExpression(.SuperKeyword), 0, f.newIdentifier(name), 0);
                const assignExpr = f.newAssignmentExpression(superProp, f.newIdentifier("v"));

                const setterArrow = f.newArrowFunction(0, 0, setterParams, 0, equalsGreaterThan, assignExpr);
                const setId = f.newIdentifier("set");
                const setter = f.newPropertyAssignment(0, setId, 0, 0, setterArrow);
                descriptorProperties.append(self.allocator, setter) catch unreachable;
            }

            const descriptorPropsList = f.newNodeList(descriptorProperties.items);
            const descriptor = f.newObjectLiteralExpression(descriptorPropsList, false);

            const propNameId = f.newIdentifier(name);
            const accessor = f.newPropertyAssignment(0, propNameId, 0, 0, descriptor);
            accessors.append(self.allocator, accessor) catch unreachable;
        }

        const descriptorsObjectList = f.newNodeList(accessors.items);
        const descriptorsObject = f.newObjectLiteralExpression(descriptorsObjectList, true);

        const objectId = f.newIdentifier("Object");
        const createId = f.newIdentifier("create");
        const objectCreate = f.newPropertyAccessExpression(objectId, 0, createId, 0);

        const nullExpr = f.newKeywordExpression(.NullKeyword);
        const createArgsList = f.newNodeList(&[_]ast.NodeIndex{ nullExpr, descriptorsObject });

        const objectCreateCall = f.newCallExpression(objectCreate, 0, 0, createArgsList, 0);

        const decl = f.newVariableDeclaration(self.superBinding, 0, 0, objectCreateCall);
        const declList = f.newVariableDeclarationList(f.newNodeList(&[_]ast.NodeIndex{decl}), ast_utils.NodeFlags.Const);
        return f.newVariableStatement(0, declList);
    }

    fn createSuperElementAccessInAsyncMethod(self: *AsyncTransformer, argumentExpression: ast.NodeIndex) ast.NodeIndex {
        const f = self.transformer.factory;
        const arg_list = f.newNodeList(&[_]ast.NodeIndex{argumentExpression});
        const superIndexCall = f.newCallExpression(self.superIndexBinding, 0, 0, arg_list, 0);
        if (self.hasSuperPropertyAssignment) {
            const value_id = f.newIdentifier("value");
            return f.newPropertyAccessExpression(superIndexCall, 0, value_id, 0);
        }
        return superIndexCall;
    }
};

fn hasAsyncModifier(tree: *ast.Ast, modifiers: ast.NodeIndex) bool {
    if (modifiers == 0) return false;
    for (tree.getNodeList(modifiers)) |modifier| if (tree.getNodeKind(modifier) == .AsyncKeyword) return true;
    return false;
}

fn isSimpleParameterList(tree: *ast.Ast, parameters: ast.NodeIndex) bool {
    if (parameters == 0) return true;
    for (tree.getNodeList(parameters)) |param_idx| {
        const param = tree.getNode(param_idx).Parameter;
        if (param.Initializer != 0) return false;
        if (ast_utils.getKind(tree, param.name) != .Identifier) return false;
    }
    return true;
}

fn isUpdateExpression(tree: *ast.Ast, node: ast.NodeIndex) bool {
    const kind_val = ast_utils.getKind(tree, node);
    if (kind_val == .PrefixUnaryExpression) {
        const op = ast_utils.getKind(tree, tree.getNode(node).PrefixUnaryExpression.Operator);
        return op == .PlusPlusToken or op == .MinusMinusToken;
    }
    if (kind_val == .PostfixUnaryExpression) {
        const op = ast_utils.getKind(tree, tree.getNode(node).PostfixUnaryExpression.Operator);
        return op == .PlusPlusToken or op == .MinusMinusToken;
    }
    return false;
}
