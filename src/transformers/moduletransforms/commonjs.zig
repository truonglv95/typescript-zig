const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const ast_utils = @import("../../ast/ast_utils.zig");
const core = @import("../../core/core.zig");
const helpers = @import("../../printer/helpers.zig");
const transformer_mod = @import("../transformer.zig");
const visitor_mod = @import("../../ast/visitor.zig");

pub const CommonJSModuleTransformer = struct {
    allocator: std.mem.Allocator,
    transformer: *transformer_mod.Transformer,
    import_aliases: std.StringHashMapUnmanaged(ast.NodeIndex) = .empty,
    compiler_options: *core.CompilerOptions,
    needs_tslib: bool = false,

    pub fn new(allocator: std.mem.Allocator, opt: *transformer_mod.TransformOptions) !*transformer_mod.Transformer {
        const tx = try allocator.create(CommonJSModuleTransformer);
        tx.allocator = allocator;
        tx.import_aliases = .empty;
        tx.compiler_options = opt.compilerOptions;
        tx.needs_tslib = false;
        tx.transformer = try transformer_mod.Transformer.init(allocator, visit, tx, opt.context);
        return tx.transformer;
    }

    fn visit(ctx: ?*anyopaque, v: *visitor_mod.NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        const self: *CommonJSModuleTransformer = @ptrCast(@alignCast(ctx.?));
        if (node == 0) return 0;
        if (v.tree.getNode(node) == .SourceFile) return self.visitSourceFile(v, node);
        if (v.tree.getNode(node) == .Identifier) {
            const text_value = v.tree.getNode(node).Identifier.Text;
            return self.import_aliases.get(text_value) orelse node;
        }
        if (v.tree.getNode(node) == .CallExpression) {
            const call = v.tree.getNode(node).CallExpression;
            if (v.tree.getNode(call.Expression) == .Identifier) {
                const original_name = ast_utils.getText(v.tree, call.Expression);
                if (self.import_aliases.get(original_name)) |alias| {
                    const comma = v.tree.pushNode(.{ .CommaToken = {} }) catch unreachable;
                    const unbound = self.transformer.factory.newParenthesizedExpression(self.transformer.factory.newBinaryExpression(0, self.transformer.factory.newNumericLiteral("0", 0), 0, comma, alias));
                    return self.transformer.factory.updateCallExpression(node, call, unbound, call.QuestionDotToken orelse 0, 0, v.visitNodes(call.Arguments), call.Flags);
                }
            }
            return v.visitEachChild(node);
        }
        if (v.tree.getNode(node) == .PropertyAccessExpression) {
            var property = v.tree.getNode(node).PropertyAccessExpression;
            property.Expression = v.visitNode(property.Expression);
            return v.tree.pushNode(.{ .PropertyAccessExpression = property }) catch unreachable;
        }
        return v.visitEachChild(node);
    }

    fn visitSourceFile(self: *CommonJSModuleTransformer, v: *visitor_mod.NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        const source = v.tree.getNode(node).SourceFile;
        self.import_aliases.clearRetainingCapacity();
        self.needs_tslib = false;
        const original = self.allocator.dupe(ast.NodeIndex, v.tree.getNodeList(source.Statements)) catch unreachable;
        defer self.allocator.free(original);
        var body = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer body.deinit(self.allocator);
        var export_prologue = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer export_prologue.deinit(self.allocator);
        var export_void_names = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer export_void_names.deinit(self.allocator);
        var has_module_syntax = ast_utils.isExternalModule(v.tree, node);
        var has_export_equals = false;

        for (original) |statement| switch (v.tree.getNode(statement)) {
            .ImportDeclaration => |declaration| {
                has_module_syntax = true;
                if (self.transformImport(v, declaration)) |lowered| body.append(self.allocator, lowered) catch unreachable;
            },
            .ImportEqualsDeclaration => |declaration| {
                if (declaration.IsTypeOnly != 0) continue;
                has_module_syntax = true;
                const reference = v.tree.getNode(declaration.ModuleReference);
                if (reference == .ExternalModuleReference) {
                    body.append(self.allocator, self.constStatement(declaration.name, self.requireCall(reference.ExternalModuleReference.Expression))) catch unreachable;
                } else {
                    body.append(self.allocator, self.constStatement(declaration.name, v.visitNode(declaration.ModuleReference))) catch unreachable;
                }
            },
            .ExportAssignment => |assignment| {
                has_module_syntax = true;
                has_export_equals = has_export_equals or assignment.IsExportEquals != 0;
                const target = if (assignment.IsExportEquals != 0)
                    self.transformer.factory.newPropertyAccessExpression(self.transformer.factory.newIdentifier("module"), 0, self.transformer.factory.newIdentifier("exports"), 0)
                else
                    self.transformer.factory.newPropertyAccessExpression(self.transformer.factory.newIdentifier("exports"), 0, self.transformer.factory.newIdentifier("default"), 0);
                body.append(self.allocator, self.transformer.factory.newExpressionStatement(self.transformer.factory.newAssignmentExpression(target, v.visitNode(assignment.Expression)))) catch unreachable;
            },
            .ExportDeclaration => |declaration| {
                has_module_syntax = true;
                if ((declaration.ModuleSpecifier orelse 0) == 0 and (declaration.ExportClause orelse 0) != 0 and v.tree.getNode(declaration.ExportClause.?) == .NamedExports) {
                    for (v.tree.getNodeList(v.tree.getNode(declaration.ExportClause.?).NamedExports.Elements)) |element| {
                        const specifier = v.tree.getNode(element).ExportSpecifier;
                        const local_name = specifier.PropertyName orelse specifier.name;
                        if (specifier.IsTypeOnly == 0 and hasRuntimeDeclarationName(v.tree, original, ast_utils.getText(v.tree, local_name))) export_void_names.append(self.allocator, specifier.name) catch unreachable;
                    }
                }
            },
            .ExpressionStatement => |expression_statement| {
                if (isImportDeferCall(v.tree, expression_statement.Expression)) {
                    has_module_syntax = true;
                } else body.append(self.allocator, v.visitNode(statement)) catch unreachable;
            },
            .FunctionDeclaration => |function| {
                const exported = hasExportModifier(v.tree, function.modifiers orelse 0);
                const default_export = hasDefaultModifier(v.tree, function.modifiers orelse 0);
                if (exported) has_module_syntax = true;
                if (exported and !default_export and (function.name orelse 0) != 0) export_prologue.append(self.allocator, self.exportAssignment(function.name.?)) catch unreachable;
                body.append(self.allocator, self.transformer.factory.updateFunctionDeclaration(
                    statement,
                    function,
                    stripExportModifiers(self, v.tree, function.modifiers orelse 0),
                    function.AsteriskToken orelse 0,
                    function.name orelse 0,
                    0,
                    v.visitNodes(function.Parameters),
                    0,
                    v.visitNode(function.Body orelse 0),
                )) catch unreachable;
                if (exported and default_export and (function.name orelse 0) != 0) export_prologue.append(self.allocator, self.exportDefaultAssignment(function.name.?)) catch unreachable;
            },
            .ClassDeclaration => |cls| {
                const exported = hasExportModifier(v.tree, cls.modifiers orelse 0);
                if (exported) has_module_syntax = true;
                const updated = self.transformer.factory.updateClassDeclaration(
                    statement,
                    cls,
                    stripExportModifiers(self, v.tree, cls.modifiers orelse 0),
                    cls.name orelse 0,
                    0,
                    v.visitNodes(cls.HeritageClauses orelse 0),
                    v.visitNodes(cls.Members),
                );
                if (exported and (cls.name orelse 0) != 0) {
                    const left = self.transformer.factory.newPropertyAccessExpression(self.transformer.factory.newIdentifier("exports"), 0, cls.name.?, 0);
                    _ = left;
                    export_void_names.append(self.allocator, cls.name.?) catch unreachable;
                }
                body.append(self.allocator, updated) catch unreachable;
                if (exported and (cls.name orelse 0) != 0) body.append(self.allocator, self.exportAssignment(cls.name.?)) catch unreachable;
            },
            .VariableStatement => |variable_statement| {
                const exported = hasExportModifier(v.tree, variable_statement.modifiers orelse 0);
                if (!exported) {
                    body.append(self.allocator, v.visitNode(statement)) catch unreachable;
                    continue;
                }
                has_module_syntax = true;
                const declaration_list = v.tree.getNode(variable_statement.DeclarationList).VariableDeclarationList;
                for (v.tree.getNodeList(declaration_list.Declarations)) |declaration_index| {
                    const declaration = v.tree.getNode(declaration_index).VariableDeclaration;
                    if (v.tree.getNode(declaration.name) != .Identifier) {
                        var names = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                        defer names.deinit(self.allocator);
                        const target = self.exportBindingTarget(v, declaration.name, false, &names);
                        export_void_names.appendSlice(self.allocator, names.items) catch unreachable;
                        if ((declaration.Initializer orelse 0) != 0) {
                            var assignment = self.transformer.factory.newAssignmentExpression(target, v.visitNode(declaration.Initializer.?));
                            if (v.tree.getNode(target) == .ObjectLiteralExpression) assignment = self.transformer.factory.newParenthesizedExpression(assignment);
                            body.append(self.allocator, self.transformer.factory.newExpressionStatement(assignment)) catch unreachable;
                        }
                        continue;
                    }
                    const export_access = self.transformer.factory.newPropertyAccessExpression(self.transformer.factory.newIdentifier("exports"), 0, declaration.name, 0);
                    export_void_names.append(self.allocator, declaration.name) catch unreachable;
                    if (std.mem.eql(u8, ast_utils.getText(v.tree, declaration.name), "_default")) {
                        body.append(self.allocator, self.constStatement(declaration.name, v.visitNode(declaration.Initializer orelse 0))) catch unreachable;
                        body.append(self.allocator, self.exportAssignment(declaration.name)) catch unreachable;
                        continue;
                    }
                    self.import_aliases.put(self.allocator, ast_utils.getText(v.tree, declaration.name), export_access) catch unreachable;
                    if ((declaration.Initializer orelse 0) != 0) {
                        body.append(self.allocator, self.transformer.factory.newExpressionStatement(self.transformer.factory.newAssignmentExpression(export_access, v.visitNode(declaration.Initializer.?)))) catch unreachable;
                    }
                }
            },
            else => body.append(self.allocator, v.visitNode(statement)) catch unreachable,
        };

        if (export_void_names.items.len > 0) export_prologue.insert(self.allocator, 0, self.exportVoidAssignment(export_void_names.items)) catch unreachable;
        if (self.needs_tslib) body.insert(self.allocator, 0, self.constStatement(self.transformer.factory.newUniqueName("tslib"), self.requireText("tslib"))) catch unreachable;
        if (export_prologue.items.len > 0) body.insertSlice(self.allocator, 0, export_prologue.items) catch unreachable;
        if (has_module_syntax and !has_export_equals) {
            var marker_index: usize = 0;
            while (marker_index < body.items.len and isPrivateStorageDeclaration(v.tree, body.items[marker_index])) : (marker_index += 1) {}
            body.insert(self.allocator, marker_index, self.createModuleMarker()) catch unreachable;
        }
        return self.transformer.factory.updateSourceFile(node, source, self.transformer.factory.newNodeList(body.items), source.EndOfFileToken);
    }

    fn transformImport(self: *CommonJSModuleTransformer, v: *visitor_mod.NodeVisitor, declaration: ast_gen.ImportDeclarationNode) ?ast.NodeIndex {
        const clause_index = declaration.ImportClause orelse return self.transformer.factory.newExpressionStatement(self.requireCall(declaration.ModuleSpecifier));
        const clause = v.tree.getNode(clause_index).ImportClause;
        const required = self.requireCall(declaration.ModuleSpecifier);
        if ((clause.NamedBindings orelse 0) != 0 and v.tree.getNode(clause.NamedBindings.?) == .NamespaceImport) {
            const name = v.tree.getNode(clause.NamedBindings.?).NamespaceImport.name;
            const helper = self.helperCallee("__importStar", &helpers.importStarHelper);
            const wrapped = self.transformer.factory.newCallExpression(helper, 0, 0, self.transformer.factory.newNodeList(&[_]ast.NodeIndex{required}), 0);
            if ((clause.name orelse 0) != 0) {
                const module_name = self.moduleVariableName(v.tree, declaration.ModuleSpecifier);
                const default_access = self.transformer.factory.newPropertyAccessExpression(module_name, 0, self.transformer.factory.newIdentifier("default"), 0);
                self.import_aliases.put(self.allocator, ast_utils.getText(v.tree, clause.name.?), default_access) catch unreachable;
                const first = self.transformer.factory.newVariableDeclaration(module_name, 0, 0, wrapped);
                const second = self.transformer.factory.newVariableDeclaration(name, 0, 0, module_name);
                const list = self.transformer.factory.newVariableDeclarationList(self.transformer.factory.newNodeList(&[_]ast.NodeIndex{ first, second }), ast_utils.NodeFlags.Const);
                return self.transformer.factory.newVariableStatement(0, list);
            }
            return self.constStatement(name, wrapped);
        }
        if ((clause.NamedBindings orelse 0) != 0 and v.tree.getNode(clause.NamedBindings.?) == .NamedImports) {
            const module_name = self.moduleVariableName(v.tree, declaration.ModuleSpecifier);
            const elements = v.tree.getNodeList(v.tree.getNode(clause.NamedBindings.?).NamedImports.Elements);
            var needs_default_wrapper = false;
            for (elements) |element| {
                const specifier = v.tree.getNode(element).ImportSpecifier;
                if (specifier.IsTypeOnly != 0) continue;
                const imported = specifier.PropertyName orelse specifier.name;
                if (std.mem.eql(u8, ast_utils.getText(v.tree, imported), "default")) needs_default_wrapper = true;
                const access = self.transformer.factory.newPropertyAccessExpression(module_name, 0, imported, 0);
                self.import_aliases.put(self.allocator, ast_utils.getText(v.tree, specifier.name), access) catch unreachable;
            }
            if (needs_default_wrapper) {
                const helper = self.helperCallee("__importDefault", &helpers.importDefaultHelper);
                const wrapped = self.transformer.factory.newCallExpression(helper, 0, 0, self.transformer.factory.newNodeList(&[_]ast.NodeIndex{required}), 0);
                return self.constStatement(module_name, wrapped);
            }
            return self.constStatement(module_name, required);
        }
        if ((clause.name orelse 0) != 0) {
            const helper = self.helperCallee("__importDefault", &helpers.importDefaultHelper);
            const wrapped = self.transformer.factory.newCallExpression(helper, 0, 0, self.transformer.factory.newNodeList(&[_]ast.NodeIndex{required}), 0);
            const module_name = self.moduleVariableName(v.tree, declaration.ModuleSpecifier);
            const default_access = self.transformer.factory.newPropertyAccessExpression(module_name, 0, self.transformer.factory.newIdentifier("default"), 0);
            self.import_aliases.put(self.allocator, ast_utils.getText(v.tree, clause.name.?), default_access) catch unreachable;
            return self.constStatement(module_name, wrapped);
        }
        return self.transformer.factory.newExpressionStatement(required);
    }

    fn requireCall(self: *CommonJSModuleTransformer, module_specifier: ast.NodeIndex) ast.NodeIndex {
        const literal = self.transformer.factory.newStringLiteral(ast_utils.getText(self.transformer.factory.tree, module_specifier), false);
        return self.transformer.factory.newCallExpression(self.transformer.factory.newIdentifier("require"), 0, 0, self.transformer.factory.newNodeList(&[_]ast.NodeIndex{literal}), 0);
    }

    fn requireText(self: *CommonJSModuleTransformer, text: []const u8) ast.NodeIndex {
        return self.transformer.factory.newCallExpression(self.transformer.factory.newIdentifier("require"), 0, 0, self.transformer.factory.newNodeList(&[_]ast.NodeIndex{self.transformer.factory.newStringLiteral(text, false)}), 0);
    }

    fn helperCallee(self: *CommonJSModuleTransformer, name: []const u8, helper: *const @TypeOf(helpers.importStarHelper)) ast.NodeIndex {
        if (self.compiler_options.importHelpers orelse false) {
            self.needs_tslib = true;
            return self.transformer.factory.newPropertyAccessExpression(self.transformer.factory.newUniqueName("tslib"), 0, self.transformer.factory.newIdentifier(name), 0);
        }
        self.transformer.emitContext.requestEmitHelper(helper);
        return self.transformer.factory.newIdentifier(name);
    }

    fn moduleVariableName(self: *CommonJSModuleTransformer, tree: *ast.Ast, module_specifier: ast.NodeIndex) ast.NodeIndex {
        const module_text = ast_utils.getText(tree, module_specifier);
        const slash = std.mem.lastIndexOfScalar(u8, module_text, '/');
        const start = if (slash) |index| index + 1 else 0;
        const tail = module_text[start..];
        const raw = if (tail.len == 0) "module" else tail;
        const normalized = self.allocator.alloc(u8, raw.len) catch unreachable;
        for (raw, 0..) |char, index| normalized[index] = if (std.ascii.isAlphanumeric(char) or char == '_') char else '_';
        return self.transformer.factory.newUniqueName(normalized);
    }

    fn constStatement(self: *CommonJSModuleTransformer, name: ast.NodeIndex, initializer: ast.NodeIndex) ast.NodeIndex {
        const declaration = self.transformer.factory.newVariableDeclaration(name, 0, 0, initializer);
        const list = self.transformer.factory.newVariableDeclarationList(self.transformer.factory.newNodeList(&[_]ast.NodeIndex{declaration}), ast_utils.NodeFlags.Const);
        return self.transformer.factory.newVariableStatement(0, list);
    }

    fn exportAssignment(self: *CommonJSModuleTransformer, name: ast.NodeIndex) ast.NodeIndex {
        const left = self.transformer.factory.newPropertyAccessExpression(self.transformer.factory.newIdentifier("exports"), 0, name, 0);
        return self.transformer.factory.newExpressionStatement(self.transformer.factory.newAssignmentExpression(left, name));
    }

    fn exportDefaultAssignment(self: *CommonJSModuleTransformer, value: ast.NodeIndex) ast.NodeIndex {
        const left = self.transformer.factory.newPropertyAccessExpression(self.transformer.factory.newIdentifier("exports"), 0, self.transformer.factory.newIdentifier("default"), 0);
        return self.transformer.factory.newExpressionStatement(self.transformer.factory.newAssignmentExpression(left, value));
    }

    fn exportVoidAssignment(self: *CommonJSModuleTransformer, names: []const ast.NodeIndex) ast.NodeIndex {
        var expression = self.transformer.factory.newVoidZeroExpression();
        for (names) |name| {
            const left = self.transformer.factory.newPropertyAccessExpression(self.transformer.factory.newIdentifier("exports"), 0, name, 0);
            expression = self.transformer.factory.newAssignmentExpression(left, expression);
        }
        return self.transformer.factory.newExpressionStatement(expression);
    }

    fn exportBindingTarget(self: *CommonJSModuleTransformer, v: *visitor_mod.NodeVisitor, node: ast.NodeIndex, object_element: bool, names: *std.ArrayListUnmanaged(ast.NodeIndex)) ast.NodeIndex {
        return switch (v.tree.getNode(node)) {
            .Identifier => blk: {
                names.append(self.allocator, node) catch unreachable;
                break :blk self.transformer.factory.newPropertyAccessExpression(self.transformer.factory.newIdentifier("exports"), 0, node, 0);
            },
            .ArrayBindingPattern => |pattern| blk: {
                var elements = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer elements.deinit(self.allocator);
                for (v.tree.getNodeList(pattern.Elements)) |element| elements.append(self.allocator, self.exportBindingTarget(v, element, false, names)) catch unreachable;
                break :blk self.transformer.factory.newArrayLiteralExpression(self.transformer.factory.newNodeList(elements.items), false);
            },
            .ObjectBindingPattern => |pattern| blk: {
                var elements = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer elements.deinit(self.allocator);
                for (v.tree.getNodeList(pattern.Elements)) |element| elements.append(self.allocator, self.exportBindingTarget(v, element, true, names)) catch unreachable;
                break :blk self.transformer.factory.newObjectLiteralExpression(self.transformer.factory.newNodeList(elements.items), false);
            },
            .BindingElement => |element| blk: {
                const original_name = element.name orelse 0;
                const target = self.exportBindingTarget(v, original_name, false, names);
                var property_name = element.PropertyName orelse 0;
                if (object_element and property_name == 0 and v.tree.getNode(original_name) == .Identifier) property_name = original_name;
                var value = target;
                if ((element.Initializer orelse 0) != 0) value = self.transformer.factory.newAssignmentExpression(value, v.visitNode(element.Initializer.?));
                if ((element.DotDotDotToken orelse 0) != 0) break :blk self.transformer.factory.newSpreadElement(value);
                if (object_element) break :blk self.transformer.factory.newPropertyAssignment(0, property_name, 0, 0, value);
                break :blk value;
            },
            .OmittedExpression => node,
            else => v.visitNode(node),
        };
    }

    fn createModuleMarker(self: *CommonJSModuleTransformer) ast.NodeIndex {
        const target = self.transformer.factory.newIdentifier("exports");
        const key = self.transformer.factory.newStringLiteral("__esModule", false);
        const value = self.transformer.factory.newPropertyAssignment(0, self.transformer.factory.newIdentifier("value"), 0, 0, self.transformer.factory.newTrueExpression());
        const descriptor = self.transformer.factory.newObjectLiteralExpression(self.transformer.factory.newNodeList(&[_]ast.NodeIndex{value}), false);
        const callee = self.transformer.factory.newPropertyAccessExpression(self.transformer.factory.newIdentifier("Object"), 0, self.transformer.factory.newIdentifier("defineProperty"), 0);
        return self.transformer.factory.newExpressionStatement(self.transformer.factory.newCallExpression(callee, 0, 0, self.transformer.factory.newNodeList(&[_]ast.NodeIndex{ target, key, descriptor }), 0));
    }
};

fn isPrivateStorageDeclaration(tree: *ast.Ast, node: ast.NodeIndex) bool {
    if (tree.getNode(node) != .VariableStatement) return false;
    const list = tree.getNode(tree.getNode(node).VariableStatement.DeclarationList).VariableDeclarationList;
    const declarations = tree.getNodeList(list.Declarations);
    if (declarations.len != 1 or tree.getNode(declarations[0]) != .VariableDeclaration) return false;
    const declaration = tree.getNode(declarations[0]).VariableDeclaration;
    if ((declaration.Initializer orelse 0) != 0 or tree.getNode(declaration.name) != .Identifier) return false;
    const name = ast_utils.getText(tree, declaration.name);
    return name.len > 2 and name[0] == '_' and std.mem.indexOf(u8, name, "_state") != null;
}

fn hasRuntimeDeclarationName(tree: *ast.Ast, statements: []const ast.NodeIndex, name: []const u8) bool {
    for (statements) |statement| switch (tree.getNode(statement)) {
        .ClassDeclaration => |declaration| if ((declaration.name orelse 0) != 0 and std.mem.eql(u8, ast_utils.getText(tree, declaration.name.?), name)) return true,
        .FunctionDeclaration => |declaration| if ((declaration.name orelse 0) != 0 and std.mem.eql(u8, ast_utils.getText(tree, declaration.name.?), name)) return true,
        .VariableStatement => |variable| {
            const list = tree.getNode(variable.DeclarationList).VariableDeclarationList;
            for (tree.getNodeList(list.Declarations)) |index| {
                const declaration = tree.getNode(index).VariableDeclaration;
                if (tree.getNode(declaration.name) == .Identifier and std.mem.eql(u8, ast_utils.getText(tree, declaration.name), name)) return true;
            }
        },
        else => {},
    };
    return false;
}

fn hasExportModifier(tree: *ast.Ast, modifiers: ast.NodeIndex) bool {
    if (modifiers == 0) return false;
    for (tree.getNodeList(modifiers)) |modifier| if (tree.getNodeKind(modifier) == .ExportKeyword) return true;
    return false;
}

fn hasDefaultModifier(tree: *ast.Ast, modifiers: ast.NodeIndex) bool {
    if (modifiers == 0) return false;
    for (tree.getNodeList(modifiers)) |modifier| if (tree.getNodeKind(modifier) == .DefaultKeyword) return true;
    return false;
}

fn stripExportModifiers(self: *CommonJSModuleTransformer, tree: *ast.Ast, modifiers: ast.NodeIndex) ast.NodeIndex {
    if (modifiers == 0) return 0;
    var kept = std.ArrayListUnmanaged(ast.NodeIndex).empty;
    defer kept.deinit(self.allocator);
    for (tree.getNodeList(modifiers)) |modifier| {
        const k = tree.getNodeKind(modifier);
        if (k != .ExportKeyword and k != .DefaultKeyword) kept.append(self.allocator, modifier) catch unreachable;
    }
    return if (kept.items.len == 0) 0 else self.transformer.factory.newModifierList(kept.items);
}

fn isImportDeferCall(tree: *ast.Ast, node: ast.NodeIndex) bool {
    if (tree.getNode(node) != .CallExpression) return false;
    const callee = tree.getNode(node).CallExpression.Expression;
    if (tree.getNode(callee) != .PropertyAccessExpression) return false;
    const property = tree.getNode(callee).PropertyAccessExpression;
    return tree.getNodeKind(property.Expression) == .ImportKeyword and (tree.getNodeKind(property.name) == .DeferKeyword or std.mem.eql(u8, ast_utils.getText(tree, property.name), "defer"));
}
