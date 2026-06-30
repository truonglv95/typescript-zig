const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const visitor = @import("../ast/visitor.zig");
const transformer_mod = @import("transformer.zig");
const program_mod = @import("../compiler/program.zig");

/// Syntactic declaration transform used by the standalone/project driver.
/// It deliberately runs on the original typed AST, before runtime transforms.
pub const DeclarationTransformer = struct {
    allocator: std.mem.Allocator,
    transformer: *transformer_mod.Transformer,
    semantic_program: ?*program_mod.Program,
    semantic_file: ?program_mod.FileId,

    pub fn new(allocator: std.mem.Allocator, context: anytype, semantic_program: ?*program_mod.Program, semantic_file: ?program_mod.FileId) !*transformer_mod.Transformer {
        const self = try allocator.create(DeclarationTransformer);
        self.allocator = allocator;
        self.semantic_program = semantic_program;
        self.semantic_file = semantic_file;
        self.transformer = try transformer_mod.Transformer.init(allocator, visit, self, context);
        return self.transformer;
    }

    fn visit(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        const self: *DeclarationTransformer = @ptrCast(@alignCast(ctx.?));
        if (node == 0) return 0;
        const f = self.transformer.factory;
        const result = switch (v.tree.getNode(node)) {
            .SourceFile => |source| blk: {
                var statements = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer statements.deinit(self.allocator);
                const original_statements = self.allocator.dupe(ast.NodeIndex, v.tree.getNodeList(source.Statements)) catch unreachable;
                defer self.allocator.free(original_statements);
                var has_exported_declaration = false;
                var has_private_class = false;
                for (original_statements) |statement| {
                    if (!isDeclarationStatement(v.tree, statement)) continue;
                    const is_exported = @import("../ast/ast_utils.zig").hasSyntacticModifier(v.tree, statement, @import("../ast/ast_utils.zig").ModifierFlags.Export);
                    has_exported_declaration = has_exported_declaration or is_exported;
                    has_private_class = has_private_class or (v.tree.getNode(statement) == .ClassDeclaration and !is_exported);
                    if (v.tree.getNode(statement) == .VariableStatement and
                        !is_exported) continue;
                    const transformed = v.visitFn(v.ctx, v, statement);
                    if (transformed != 0) {
                        if (v.tree.getNode(transformed) == .SyntaxList) {
                            statements.appendSlice(self.allocator, v.tree.getNodeList(v.tree.getNode(transformed).SyntaxList.Children)) catch unreachable;
                        } else {
                            statements.append(self.allocator, transformed) catch unreachable;
                        }
                    }
                }
                appendJSDocTypeAliases(v.tree, f, source.EndOfFileToken, &statements, self.allocator);
                if (has_exported_declaration and has_private_class) {
                    const empty = f.newNodeList(&.{});
                    const clause = v.tree.pushNode(.{ .NamedExports = .{ .Flags = 0, .Elements = empty } }) catch unreachable;
                    const marker = v.tree.pushNode(.{ .ExportDeclaration = .{
                        .Symbol = 0,
                        .Flags = 0,
                        .modifiers = null,
                        .modifierFlags = 0,
                        .IsTypeOnly = 0,
                        .ExportClause = clause,
                        .ModuleSpecifier = null,
                        .Attributes = null,
                    } }) catch unreachable;
                    statements.append(self.allocator, marker) catch unreachable;
                }
                break :blk f.updateSourceFile(node, source, f.newNodeList(statements.items), source.EndOfFileToken);
            },
            .VariableStatement => |n| f.updateVariableStatement(node, n, self.declarationModifiers(v, node, n.modifiers orelse 0), v.visitNode(n.DeclarationList)),
            .ExportAssignment => |n| self.transformExportAssignment(v, node, n),
            .FunctionDeclaration => |n| self.transformFunction(v, node, n),
            .ClassDeclaration => |n| self.transformClass(v, node, n),
            .MethodDeclaration => |n| self.transformMethod(v, node, n),
            .Constructor => |n| self.transformConstructor(v, node, n),
            .GetAccessor => |n| f.updateGetAccessorDeclaration(node, n, v.visitModifiers(n.modifiers orelse 0), n.name, v.visitNodes(n.TypeParameters orelse 0), v.visitNodes(n.Parameters), inferredType(v.tree, f, n.Type orelse 0, 0), 0),
            .SetAccessor => |n| f.updateSetAccessorDeclaration(node, n, v.visitModifiers(n.modifiers orelse 0), n.name, v.visitNodes(n.TypeParameters orelse 0), v.visitNodes(n.Parameters), 0, 0),
            .PropertyDeclaration => |n| f.updatePropertyDeclaration(node, n, v.visitModifiers(n.modifiers orelse 0), n.name, n.PostfixToken orelse 0, inferredType(v.tree, f, n.Type orelse 0, n.Initializer orelse 0), 0),
            .VariableDeclaration => |n| blk: {
                const initializer = n.Initializer orelse 0;
                const preserve_literal = isConstVariable(v.tree, node) and isDeclarationLiteral(v.tree, initializer);
                break :blk f.updateVariableDeclaration(node, n, v.visitNode(n.name), 0, if (preserve_literal) 0 else self.inferredDeclarationType(v.tree, f, n.name, n.Type orelse 0, initializer), if (preserve_literal) normalizedDeclarationLiteral(v.tree, initializer) else 0);
            },
            .Parameter => |n| f.updateParameterDeclaration(node, n, v.visitModifiers(n.modifiers orelse 0), n.DotDotDotToken orelse 0, v.visitNode(n.name), n.QuestionToken orelse 0, inferredType(v.tree, f, n.Type orelse 0, n.Initializer orelse 0), 0),
            else => v.visitEachChild(node),
        };
        if (result != 0 and result != node) self.transformer.emitContext.setOriginal(result, node) catch {};
        return result;
    }

    fn declarationModifiers(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, modifiers: ast.NodeIndex) ast.NodeIndex {
        const visited = v.visitModifiers(modifiers);
        const utils = @import("../ast/ast_utils.zig");
        if (utils.hasSyntacticModifier(v.tree, node, utils.ModifierFlags.Ambient)) return visited;
        var items = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer items.deinit(self.allocator);
        if (visited != 0) items.appendSlice(self.allocator, v.tree.getNodeList(visited)) catch unreachable;
        items.append(self.allocator, self.transformer.factory.newToken(.{ .DeclareKeyword = {} })) catch unreachable;
        return self.transformer.factory.newModifierList(items.items);
    }

    fn transformConstructor(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, constructor: ast_gen.ConstructorDeclarationNode) ast.NodeIndex {
        const f = self.transformer.factory;
        const utils = @import("../ast/ast_utils.zig");
        var properties = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer properties.deinit(self.allocator);
        var parameters = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer parameters.deinit(self.allocator);
        for (v.tree.getNodeList(constructor.Parameters)) |parameter_index| {
            const parameter = v.tree.getNode(parameter_index).Parameter;
            const is_property = utils.isParameterPropertyDeclaration(v.tree, parameter_index, node);
            const type_node = inferredType(v.tree, f, parameter.Type orelse 0, parameter.Initializer orelse 0);
            if (is_property) {
                const property = f.newPropertyDeclaration(v.visitModifiers(parameter.modifiers orelse 0), parameter.name, parameter.QuestionToken orelse 0, type_node, 0);
                self.transformer.emitContext.setOriginal(property, parameter_index) catch {};
                properties.append(self.allocator, property) catch unreachable;
            }
            const question = parameter.QuestionToken orelse if (parameter.Initializer != null) f.newToken(.{ .QuestionToken = {} }) else 0;
            const updated = f.updateParameterDeclaration(parameter_index, parameter, if (is_property) 0 else v.visitModifiers(parameter.modifiers orelse 0), parameter.DotDotDotToken orelse 0, parameter.name, question, type_node, 0);
            if (updated != parameter_index) self.transformer.emitContext.setOriginal(updated, parameter_index) catch {};
            parameters.append(self.allocator, updated) catch unreachable;
        }
        const parameter_list = f.newNodeList(parameters.items);
        const updated_constructor = f.updateConstructorDeclaration(node, constructor, v.visitModifiers(constructor.modifiers orelse 0), 0, parameter_list, 0, 0);
        if (properties.items.len == 0) return updated_constructor;
        properties.append(self.allocator, updated_constructor) catch unreachable;
        return f.newSyntaxList(properties.items);
    }

    fn transformClass(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, class: ast_gen.ClassDeclarationNode) ast.NodeIndex {
        const f = self.transformer.factory;
        var jsdoc_parameters = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer jsdoc_parameters.deinit(self.allocator);
        collectJSDocTypeParameters(v.tree, node, &jsdoc_parameters, self.allocator);
        const type_parameters = if ((class.TypeParameters orelse 0) != 0)
            v.visitNodes(class.TypeParameters.?)
        else if (jsdoc_parameters.items.len != 0)
            f.newNodeList(jsdoc_parameters.items)
        else
            0;
        return f.updateClassDeclaration(node, class, self.declarationModifiers(v, node, class.modifiers orelse 0), class.name orelse 0, type_parameters, v.visitNodes(class.HeritageClauses orelse 0), v.visitNodes(class.Members));
    }

    fn transformMethod(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, method: ast_gen.MethodDeclarationNode) ast.NodeIndex {
        const f = self.transformer.factory;
        var overloads = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer overloads.deinit(self.allocator);
        for (@import("../ast/ast_utils.zig").getJSDoc(v.tree, node)) |doc_index| {
            const tags = v.tree.getNode(doc_index).JSDoc.Tags orelse continue;
            const tag_items = self.allocator.dupe(ast.NodeIndex, v.tree.getNodeList(tags)) catch unreachable;
            defer self.allocator.free(tag_items);
            var shared_type_parameters = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            defer shared_type_parameters.deinit(self.allocator);
            collectJSDocTypeParameters(v.tree, node, &shared_type_parameters, self.allocator);
            var tag_offset: usize = 0;
            while (tag_offset < tag_items.len) : (tag_offset += 1) {
                if (v.tree.getNode(tag_items[tag_offset]) != .JSDocOverloadTag) continue;
                var parameters = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer parameters.deinit(self.allocator);
                var return_type: ast.NodeIndex = 0;
                var following = tag_offset + 1;
                while (following < tag_items.len and v.tree.getNode(tag_items[following]) != .JSDocOverloadTag and return_type == 0) : (following += 1) {
                    switch (v.tree.getNode(tag_items[following])) {
                        .JSDocParameterTag => |tag| parameters.append(self.allocator, parameterFromJSDocTag(v.tree, f, tag)) catch unreachable,
                        .JSDocReturnTag => |tag| if (tag.TypeExpression) |expression| {
                            return_type = unwrapJSDocTypeExpression(v.tree, expression);
                        },
                        else => {},
                    }
                }
                const overload = f.updateMethodDeclaration(node, method, v.visitModifiers(method.modifiers orelse 0), method.AsteriskToken orelse 0, method.name, method.PostfixToken orelse 0, if (shared_type_parameters.items.len != 0) f.newNodeList(shared_type_parameters.items) else 0, f.newNodeList(parameters.items), if (return_type != 0) return_type else f.newToken(.{ .AnyKeyword = {} }), 0);
                self.transformer.emitContext.setOriginal(overload, node) catch {};
                overloads.append(self.allocator, overload) catch unreachable;
            }
        }
        if (overloads.items.len != 0) return f.newSyntaxList(overloads.items);

        var jsdoc_parameters = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer jsdoc_parameters.deinit(self.allocator);
        collectJSDocTypeParameters(v.tree, node, &jsdoc_parameters, self.allocator);
        const type_parameters = if ((method.TypeParameters orelse 0) != 0) v.visitNodes(method.TypeParameters.?) else if (jsdoc_parameters.items.len != 0) f.newNodeList(jsdoc_parameters.items) else 0;
        return f.updateMethodDeclaration(node, method, v.visitModifiers(method.modifiers orelse 0), method.AsteriskToken orelse 0, method.name, method.PostfixToken orelse 0, type_parameters, v.visitNodes(method.Parameters), method.Type orelse jsdocReturnType(v.tree, node) orelse inferredType(v.tree, f, 0, 0), 0);
    }

    fn transformFunction(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, function: ast_gen.FunctionDeclarationNode) ast.NodeIndex {
        const f = self.transformer.factory;
        if (applicableJSDocFunctionType(v.tree, node)) |function_type_index| {
            const function_type = v.tree.getNode(function_type_index).FunctionType;
            return f.updateFunctionDeclaration(node, function, self.declarationModifiers(v, node, function.modifiers orelse 0), function.AsteriskToken orelse 0, function.name orelse 0, function_type.TypeParameters orelse 0, function_type.Parameters, function_type.Type orelse f.newToken(.{ .VoidKeyword = {} }), 0);
        }

        var parameters = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer parameters.deinit(self.allocator);
        const original_parameters = v.tree.getNodeList(function.Parameters);
        for (original_parameters, 0..) |parameter_index, index| {
            const parameter = v.tree.getNode(parameter_index).Parameter;
            const jsdoc_type = inlineJSDocType(v.tree, parameter_index) orelse jsdocParameterType(v.tree, node, parameter.name, index);
            const type_node = parameter.Type orelse jsdoc_type orelse inferredType(v.tree, f, 0, parameter.Initializer orelse 0);
            const updated = f.updateParameterDeclaration(parameter_index, parameter, v.visitModifiers(parameter.modifiers orelse 0), parameter.DotDotDotToken orelse 0, v.visitNode(parameter.name), parameter.QuestionToken orelse 0, type_node, 0);
            if (updated != parameter_index) self.transformer.emitContext.setOriginal(updated, parameter_index) catch {};
            parameters.append(self.allocator, updated) catch unreachable;
        }

        var type_parameters = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer type_parameters.deinit(self.allocator);
        collectJSDocTypeParameters(v.tree, node, &type_parameters, self.allocator);
        const type_parameter_list = if ((function.TypeParameters orelse 0) != 0) v.visitNodes(function.TypeParameters.?) else if (type_parameters.items.len != 0) f.newNodeList(type_parameters.items) else 0;
        const return_type = function.Type orelse jsdocReturnType(v.tree, node) orelse inferFunctionReturnType(v.tree, f, function.Body orelse 0);
        return f.updateFunctionDeclaration(node, function, self.declarationModifiers(v, node, function.modifiers orelse 0), function.AsteriskToken orelse 0, function.name orelse 0, type_parameter_list, f.newNodeList(parameters.items), return_type, 0);
    }

    fn inferredDeclarationType(self: *DeclarationTransformer, tree: *ast.Ast, factory: anytype, name: ast.NodeIndex, explicit_type: ast.NodeIndex, initializer: ast.NodeIndex) ast.NodeIndex {
        if (explicit_type != 0) return explicit_type;
        if (tree.getNode(initializer) == .ClassExpression) return anonymousClassConstructorType(tree, factory);
        if (self.semantic_program) |program| if (self.semantic_file) |file| {
            if (tree.getNode(name) == .Identifier) if (program.getPublicType(file, @import("../ast/ast_utils.zig").getText(tree, name))) |semantic_type| {
                return factory.newToken(switch (semantic_type) {
                    .boolean => .{ .BooleanKeyword = {} },
                    .number => .{ .NumberKeyword = {} },
                    .bigint => .{ .BigIntKeyword = {} },
                    .string => .{ .StringKeyword = {} },
                    .void => .{ .VoidKeyword = {} },
                    else => .{ .AnyKeyword = {} },
                });
            };
        };
        return inferredType(tree, factory, explicit_type, initializer);
    }

    fn transformExportAssignment(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, assignment: ast_gen.ExportAssignmentNode) ast.NodeIndex {
        if (assignment.IsExportEquals != 0 or v.tree.getNode(assignment.Expression) == .Identifier) return node;
        const f = self.transformer.factory;
        const name = f.newIdentifier("_default_1");
        const declaration = f.newVariableDeclaration(name, 0, 0, assignment.Expression);
        const declarations = f.newNodeList(&.{declaration});
        const declaration_list = f.newVariableDeclarationList(declarations, @import("../ast/ast_utils.zig").NodeFlags.Const);
        const declare_modifier = f.newModifierList(&.{f.newToken(.{ .DeclareKeyword = {} })});
        const statement = f.newVariableStatement(declare_modifier, declaration_list);
        const export_assignment = f.newExportAssignment(0, false, name);
        self.transformer.emitContext.setOriginal(statement, node) catch {};
        self.transformer.emitContext.setOriginal(export_assignment, node) catch {};
        return f.newSyntaxList(&.{ statement, export_assignment });
    }
};

fn anonymousClassConstructorType(tree: *ast.Ast, factory: anytype) ast.NodeIndex {
    const empty_members = factory.newNodeList(&.{});
    const instance_type = tree.pushNode(.{ .TypeLiteral = .{ .Flags = 0, .Symbol = 0, .Members = empty_members } }) catch unreachable;
    const parameters = factory.newNodeList(&.{});
    const signature = tree.pushNode(.{ .ConstructSignature = .{ .Flags = 0, .Symbol = 0, .TypeParameters = null, .Parameters = parameters, .Type = instance_type, .FullSignature = null } }) catch unreachable;
    const members = factory.newNodeList(&.{signature});
    return tree.pushNode(.{ .TypeLiteral = .{ .Flags = 0, .Symbol = 0, .Members = members } }) catch unreachable;
}

fn appendJSDocTypeAliases(tree: *ast.Ast, factory: anytype, eof: ast.NodeIndex, statements: *std.ArrayListUnmanaged(ast.NodeIndex), allocator: std.mem.Allocator) void {
    for (tree.jsdocCache.get(eof) orelse &.{}) |doc_index| {
        const tags = tree.getNode(doc_index).JSDoc.Tags orelse continue;
        for (tree.getNodeList(tags)) |tag_index| {
            if (tree.getNode(tag_index) != .JSDocTypedefTag) continue;
            const tag = tree.getNode(tag_index).JSDocTypedefTag;
            const name = tag.name orelse continue;
            const expression = tag.TypeExpression orelse continue;
            const modifiers = factory.newModifierList(&.{factory.newToken(.{ .ExportKeyword = {} })});
            const alias = tree.pushNode(.{ .TypeAliasDeclaration = .{
                .Symbol = 0,
                .Flags = 0,
                .modifiers = modifiers,
                .modifierFlags = @import("../ast/ast_utils.zig").ModifierFlags.Export,
                .name = name,
                .TypeParameters = null,
                .Type = unwrapJSDocTypeExpression(tree, expression),
            } }) catch unreachable;
            statements.append(allocator, alias) catch unreachable;
        }
    }
}

fn isDeclarationStatement(tree: *ast.Ast, node: ast.NodeIndex) bool {
    return switch (tree.getNode(node)) {
        .ImportDeclaration, .ImportEqualsDeclaration, .ExportDeclaration, .ExportAssignment, .FunctionDeclaration, .ClassDeclaration, .InterfaceDeclaration, .TypeAliasDeclaration, .EnumDeclaration, .ModuleDeclaration, .VariableStatement => true,
        else => false,
    };
}

fn parameterFromJSDocTag(tree: *ast.Ast, factory: anytype, tag: ast_gen.JSDocParameterOrPropertyTagNode) ast.NodeIndex {
    var type_node = if (tag.TypeExpression) |expression| unwrapJSDocTypeExpression(tree, expression) else factory.newToken(.{ .AnyKeyword = {} });
    var rest_token: ast.NodeIndex = 0;
    var question_token: ast.NodeIndex = if (tag.IsBracketed != 0) factory.newToken(.{ .QuestionToken = {} }) else 0;
    if (tree.getNode(type_node) == .JSDocVariadicType) {
        rest_token = factory.newToken(.{ .DotDotDotToken = {} });
        type_node = tree.getNode(type_node).JSDocVariadicType.Type;
    }
    if (tree.getNode(type_node) == .JSDocOptionalType) {
        question_token = factory.newToken(.{ .QuestionToken = {} });
        type_node = tree.getNode(type_node).JSDocOptionalType.Type;
    }
    markJSDocTuplesSynthetic(tree, type_node);
    return tree.pushNode(.{ .Parameter = .{
        .Flags = 0,
        .Symbol = 0,
        .modifiers = null,
        .modifierFlags = 0,
        .DotDotDotToken = if (rest_token != 0) rest_token else null,
        .name = tag.name,
        .QuestionToken = if (question_token != 0) question_token else null,
        .Type = type_node,
        .Initializer = null,
    } }) catch unreachable;
}

fn inferredType(tree: *ast.Ast, factory: anytype, explicit_type: ast.NodeIndex, initializer: ast.NodeIndex) ast.NodeIndex {
    if (explicit_type != 0) return explicit_type;
    if (tree.getNode(initializer) == .NewExpression) {
        const expression = tree.getNode(initializer).NewExpression.Expression;
        if (tree.getNode(expression) == .Identifier) return factory.tree.pushNode(.{ .TypeReference = .{ .Flags = 0, .TypeArguments = null, .TypeName = expression } }) catch unreachable;
    }
    return factory.newToken(switch (tree.getNode(initializer)) {
        .StringLiteral, .NoSubstitutionTemplateLiteral => .{ .StringKeyword = {} },
        .NumericLiteral => .{ .NumberKeyword = {} },
        .TrueKeyword, .FalseKeyword => .{ .BooleanKeyword = {} },
        else => .{ .AnyKeyword = {} },
    });
}

fn isConstVariable(tree: *ast.Ast, declaration: ast.NodeIndex) bool {
    var current = tree.getNodeParent(declaration);
    var depth: usize = 0;
    while (current != 0 and depth < 4) : (depth += 1) {
        if (tree.getNode(current) == .VariableDeclarationList) return (tree.getNode(current).VariableDeclarationList.Flags & @import("../ast/ast_utils.zig").NodeFlags.Const) != 0;
        current = tree.getNodeParent(current);
    }
    return false;
}

fn isDeclarationLiteral(tree: *ast.Ast, initializer: ast.NodeIndex) bool {
    if (initializer == 0) return false;
    return switch (tree.getNode(initializer)) {
        .StringLiteral, .NoSubstitutionTemplateLiteral, .NumericLiteral, .BigIntLiteral, .TrueKeyword, .FalseKeyword => true,
        .PrefixUnaryExpression => |node| switch (tree.getNode(node.Operand)) {
            .NumericLiteral, .BigIntLiteral => true,
            else => false,
        },
        else => false,
    };
}

fn normalizedDeclarationLiteral(tree: *ast.Ast, initializer: ast.NodeIndex) ast.NodeIndex {
    if (tree.getNode(initializer) == .PrefixUnaryExpression) {
        const operand = tree.getNode(initializer).PrefixUnaryExpression.Operand;
        if (tree.getNode(operand) == .BigIntLiteral and std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, operand), "0n")) return operand;
    }
    return initializer;
}

fn applicableJSDocFunctionType(tree: *ast.Ast, function_index: ast.NodeIndex) ?ast.NodeIndex {
    const function = tree.getNode(function_index).FunctionDeclaration;
    for (tree.getNodeList(function.Parameters)) |parameter| if (inlineJSDocType(tree, parameter) != null) return null;
    var preceding_signature_tag = false;
    for (@import("../ast/ast_utils.zig").getJSDoc(tree, function_index)) |doc_index| {
        const doc = tree.getNode(doc_index).JSDoc;
        const tags = doc.Tags orelse continue;
        for (tree.getNodeList(tags)) |tag_index| switch (tree.getNode(tag_index)) {
            .JSDocParameterTag, .JSDocReturnTag, .JSDocTemplateTag => preceding_signature_tag = true,
            .JSDocTypeTag => |tag| {
                if (!preceding_signature_tag) {
                    const candidate = unwrapJSDocTypeExpression(tree, tag.TypeExpression);
                    if (tree.getNode(candidate) == .FunctionType) return candidate;
                }
                preceding_signature_tag = true;
            },
            else => {},
        };
    }
    return null;
}

fn inlineJSDocType(tree: *ast.Ast, node_index: ast.NodeIndex) ?ast.NodeIndex {
    const docs = @import("../ast/ast_utils.zig").getJSDoc(tree, node_index);
    for (docs) |doc_index| {
        const doc = tree.getNode(doc_index).JSDoc;
        const tags = doc.Tags orelse continue;
        for (tree.getNodeList(tags)) |tag_index| if (tree.getNode(tag_index) == .JSDocTypeTag) {
            const result = unwrapJSDocTypeExpression(tree, tree.getNode(tag_index).JSDocTypeTag.TypeExpression);
            return result;
        };
    }
    return null;
}

fn jsdocParameterType(tree: *ast.Ast, function_index: ast.NodeIndex, parameter_name: ast.NodeIndex, parameter_ordinal: usize) ?ast.NodeIndex {
    const expected_name = if (tree.getNode(parameter_name) == .Identifier) @import("../ast/ast_utils.zig").getText(tree, parameter_name) else "";
    var ordinal: usize = 0;
    for (@import("../ast/ast_utils.zig").getJSDoc(tree, function_index)) |doc_index| {
        const doc = tree.getNode(doc_index).JSDoc;
        const tags = doc.Tags orelse continue;
        for (tree.getNodeList(tags)) |tag_index| if (tree.getNode(tag_index) == .JSDocParameterTag) {
            const tag = tree.getNode(tag_index).JSDocParameterTag;
            const matches = ordinal == parameter_ordinal or (expected_name.len != 0 and std.mem.eql(u8, expected_name, @import("../ast/ast_utils.zig").getText(tree, tag.name)));
            ordinal += 1;
            if (matches and tag.TypeExpression != null) return unwrapJSDocTypeExpression(tree, tag.TypeExpression.?);
        };
    }
    return null;
}

fn jsdocReturnType(tree: *ast.Ast, function_index: ast.NodeIndex) ?ast.NodeIndex {
    for (@import("../ast/ast_utils.zig").getJSDoc(tree, function_index)) |doc_index| {
        const doc = tree.getNode(doc_index).JSDoc;
        const tags = doc.Tags orelse continue;
        for (tree.getNodeList(tags)) |tag_index| if (tree.getNode(tag_index) == .JSDocReturnTag) {
            const expression = tree.getNode(tag_index).JSDocReturnTag.TypeExpression orelse continue;
            return unwrapJSDocTypeExpression(tree, expression);
        };
    }
    return null;
}

fn collectJSDocTypeParameters(tree: *ast.Ast, function_index: ast.NodeIndex, output: *std.ArrayListUnmanaged(ast.NodeIndex), allocator: std.mem.Allocator) void {
    for (@import("../ast/ast_utils.zig").getJSDoc(tree, function_index)) |doc_index| {
        const doc = tree.getNode(doc_index).JSDoc;
        const tags = doc.Tags orelse continue;
        for (tree.getNodeList(tags)) |tag_index| if (tree.getNode(tag_index) == .JSDocTemplateTag) {
            const tag = tree.getNode(tag_index).JSDocTemplateTag;
            const constraint = if (tag.Constraint != 0) unwrapJSDocTypeExpression(tree, tag.Constraint) else 0;
            for (tree.getNodeList(tag.TypeParameters)) |parameter_index| {
                var parameter = tree.getNode(parameter_index).TypeParameter;
                if ((parameter.Constraint orelse 0) == 0 and constraint != 0) parameter.Constraint = constraint;
                if (parameter.DefaultType) |default_type| {
                    const is_empty_array = switch (tree.getNode(default_type)) {
                        .ArrayLiteralExpression => |array| tree.getNodeList(array.Elements).len == 0,
                        .TupleType => |tuple| tree.getNodeList(tuple.Elements).len == 0,
                        else => false,
                    };
                    if (is_empty_array) {
                        const name = tree.pushNode(.{ .Identifier = .{ .Flags = @import("../ast/ast_utils.zig").NodeFlags.Synthesized, .Text = "[]" } }) catch unreachable;
                        parameter.DefaultType = tree.pushNode(.{ .TypeReference = .{ .Flags = @import("../ast/ast_utils.zig").NodeFlags.Synthesized, .TypeName = name, .TypeArguments = null } }) catch unreachable;
                    }
                }
                const updated = tree.pushNode(.{ .TypeParameter = parameter }) catch unreachable;
                output.append(allocator, updated) catch unreachable;
            }
        };
    }
}

fn markJSDocTuplesSynthetic(tree: *ast.Ast, node_index: ast.NodeIndex) void {
    if (node_index == 0) return;
    switch (tree.getNode(node_index)) {
        .TupleType => |node| {
            var updated = node;
            updated.Flags |= @import("../ast/ast_utils.zig").NodeFlags.Synthesized;
            tree.nodes.set(node_index, .{ .TupleType = updated });
        },
        .ParenthesizedType => |node| markJSDocTuplesSynthetic(tree, node.Type),
        .UnionType => |node| for (tree.getNodeList(node.Types)) |child| markJSDocTuplesSynthetic(tree, child),
        .IntersectionType => |node| for (tree.getNodeList(node.Types)) |child| markJSDocTuplesSynthetic(tree, child),
        else => {},
    }
}

fn unwrapJSDocTypeExpression(tree: *ast.Ast, node: ast.NodeIndex) ast.NodeIndex {
    return if (tree.getNode(node) == .JSDocTypeExpression) tree.getNode(node).JSDocTypeExpression.Type else node;
}

fn inferFunctionReturnType(tree: *ast.Ast, factory: anytype, body: ast.NodeIndex) ast.NodeIndex {
    if (body != 0 and tree.getNode(body) == .Block) {
        for (tree.getNodeList(tree.getNode(body).Block.Statements)) |statement| if (tree.getNode(statement) == .ReturnStatement) {
            if (tree.getNode(statement).ReturnStatement.Expression) |expression| return inferredType(tree, factory, 0, expression);
        };
    }
    return factory.newToken(.{ .VoidKeyword = {} });
}
