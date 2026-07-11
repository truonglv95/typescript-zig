const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const visitor = @import("../ast/visitor.zig");
const transformer_mod = @import("transformer.zig");
const program_mod = @import("../compiler/program.zig");
const symbol_mod = @import("../ast/symbol.zig");
const binder_mod = @import("../binder/binder.zig");

/// Syntactic declaration transform used by the standalone/project driver.
/// It deliberately runs on the original typed AST, before runtime transforms.
pub const DeclarationTransformer = struct {
    allocator: std.mem.Allocator,
    transformer: *transformer_mod.Transformer,
    semantic_program: ?*program_mod.Program,
    semantic_file: ?program_mod.FileId,
    semantic_binder: ?*binder_mod.Binder,
    next_ns_id: u32,
    has_errors: bool,
    referenced_identifiers: std.StringHashMap(void),

    fn setOriginal(self: *DeclarationTransformer, node: ast.NodeIndex, original: ast.NodeIndex) void {
        self.transformer.emitContext.setOriginal(node, original) catch {};
    }

    pub fn new(allocator: std.mem.Allocator, context: anytype, semantic_program: ?*program_mod.Program, semantic_file: ?program_mod.FileId, semantic_binder: ?*binder_mod.Binder) !*transformer_mod.Transformer {
        const self = try allocator.create(DeclarationTransformer);
        self.allocator = allocator;
        self.semantic_program = semantic_program;
        self.semantic_file = semantic_file;
        self.semantic_binder = semantic_binder;
        self.next_ns_id = 0;
        self.has_errors = false;
        self.referenced_identifiers = std.StringHashMap(void).init(allocator);
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

                for (original_statements) |statement| {
                    if (v.tree.getNode(statement) == .ClassDeclaration) {
                        self.preScanClassHeritage(v, statement);
                    }
                }

                const is_module = source.ExternalModuleIndicator != null or source.CommonJSModuleIndicator != null;
                var has_exported_declaration = false;
                var has_private_class = false;
                var has_private_support_declaration = false;
                var has_private_declaration = false;

                if (is_module) {
                    const file_path = v.tree.fileName;
                    const is_js = std.mem.endsWith(u8, file_path, ".js") or std.mem.endsWith(u8, file_path, ".jsx") or std.mem.endsWith(u8, file_path, ".cjs") or std.mem.endsWith(u8, file_path, ".mjs");
                    if (is_js) {
                        if (self.semantic_binder) |bound| {
                            const source_file = sourceFileAncestor(v.tree, node) orelse 0;
                            if (source_file != 0) {
                                if (v.tree.getNodeSymbol(source_file)) |file_symbol| {
                                    if (bound.symbolExports.getPtr(file_symbol)) |exports| {
                                        if (exports.get(symbol_mod.InternalSymbolNameExportEquals)) |export_equals_symbol_index| {
                                            const export_equals_symbol = bound.symbols.items[export_equals_symbol_index];
                                            if (export_equals_symbol.Declarations.items.len > 1) {
                                                self.has_errors = true;
                                                if (self.semantic_program) |program| {
                                                    for (export_equals_symbol.Declarations.items) |_| {
                                                        const message = std.fmt.allocPrint(program.allocator, "Multiple 'module.exports' assignments cannot be serialized for declaration emit.", .{}) catch unreachable;
                                                        program.diagnostics.append(program.allocator, .{
                                                            .file = self.semantic_file.?,
                                                            .code = 6424,
                                                            .message = message,
                                                        }) catch unreachable;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                self.appendCommonJSExportDeclarations(v, node, &statements);
                self.appendRequireImportDeclarations(v, source.Statements, &statements);
                var i: usize = 0;
                while (i < original_statements.len) : (i += 1) {
                    const statement = v.tree.getNodeList(source.Statements)[i];
                    if (!isDeclarationStatement(v.tree, statement)) continue;
                    const is_exported = @import("../ast/ast_utils.zig").hasSyntacticModifier(v.tree, statement, @import("../ast/ast_utils.zig").ModifierFlags.Export) or (is_module and v.tree.getNode(statement) == .JSTypeAliasDeclaration);
                    has_exported_declaration = has_exported_declaration or is_exported;
                    has_private_class = has_private_class or (v.tree.getNode(statement) == .ClassDeclaration and !is_exported);
                    if (is_module and v.tree.getNode(statement) == .VariableStatement and !is_exported) {
                        if (!hasSymbolInitializedDeclaration(v.tree, statement) and !variableStatementReferencedByExport(v.tree, source.Statements, statement, self.allocator)) continue;
                        has_private_support_declaration = true;
                    }
                    const decl_name = getDeclarationNameText(v.tree, statement);
                    if (is_module and !is_exported and decl_name.len > 0 and !isAmbientModuleOrGlobalAugmentation(v.tree, statement)) {
                        const has_runtime_body = (v.tree.getNode(statement) == .FunctionDeclaration and (v.tree.getNode(statement).FunctionDeclaration.Body != null or identifierUsedAsExportedShorthand(v.tree, decl_name))) or v.tree.getNode(statement) == .ClassDeclaration;
                        if (!identifierUsedByDeclaration(v.tree, statement, decl_name, self.allocator, false, true) and !(has_runtime_body and identifierUsedOutsideNode(v.tree, statement, decl_name))) continue;
                    }
                    if (is_module and !is_exported and isIdentityHelperFunction(v.tree, statement)) continue;
                    if (is_module and !is_exported and v.tree.getNode(statement) == .InterfaceDeclaration) has_private_declaration = true;
                    const transformed = v.visitFn(v.ctx, v, statement);
                    if (transformed != 0) {
                        if (v.tree.getNode(transformed) == .SyntaxList) {
                            statements.appendSlice(self.allocator, v.tree.getNodeList(v.tree.getNode(transformed).SyntaxList.Children)) catch unreachable;
                        } else {
                            statements.append(self.allocator, transformed) catch unreachable;
                        }
                        self.appendExpandoNamespace(v, statement, &statements);
                    }
                }
                if (is_module) {
                    var prune_index = statements.items.len;
                    while (prune_index > 0) {
                        prune_index -= 1;
                        const emitted_statement = statements.items[prune_index];
                        const emitted_kind = v.tree.getNode(emitted_statement);
                        if (emitted_kind != .FunctionDeclaration and emitted_kind != .ClassDeclaration) continue;
                        if (@import("../ast/ast_utils.zig").hasSyntacticModifier(v.tree, emitted_statement, @import("../ast/ast_utils.zig").ModifierFlags.Export)) continue;
                        const emitted_name = getDeclarationNameText(v.tree, emitted_statement);
                        if (emitted_name.len != 0 and !identifierUsedInOutputStatements(v.tree, statements.items, emitted_statement, emitted_name, self.allocator)) _ = statements.orderedRemove(prune_index);
                    }
                }
                var needs_scope_fix_marker = false;
                var result_has_scope_marker = false;
                for (statements.items) |stmt| {
                    if (needsScopeMarker(v.tree, stmt)) {
                        needs_scope_fix_marker = true;
                    }
                    const kind_val = v.tree.getNode(stmt);
                    if (kind_val == .ExportDeclaration or kind_val == .ExportAssignment) {
                        result_has_scope_marker = true;
                    }
                }
                if ((is_module and statements.items.len == 0) or (is_module and needs_scope_fix_marker and !result_has_scope_marker)) {
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
                const updated = f.updateSourceFile(node, source, f.newNodeList(statements.items), source.EndOfFileToken);
                self.setOriginal(updated, node);
                break :blk updated;
            },
            .ImportDeclaration => |n| self.transformImportDeclaration(v, node, n),
            .JSImportDeclaration => |n| blk: {
                const regular = v.tree.pushNode(.{ .ImportDeclaration = n }) catch unreachable;
                break :blk regular;
            },
            .ImportEqualsDeclaration => |n| if (identifierUsedByDeclaration(v.tree, node, @import("../ast/ast_utils.zig").getText(v.tree, n.name), self.allocator, false, true)) v.visitEachChild(node) else 0,
            .VariableStatement => |n| self.transformVariableStatement(v, node, n),
            .ExportAssignment => |n| self.transformExportAssignment(v, node, n),
            .FunctionDeclaration => |n| self.transformFunction(v, node, n),
            .ClassDeclaration => |n| self.transformClass(v, node, n),
            .EnumDeclaration => |n| self.transformEnum(v, node, n),
            .ModuleDeclaration => |n| blk: {
                const updated = v.tree.pushNode(.{ .ModuleDeclaration = .{
                    .Symbol = n.Symbol,
                    .Flags = n.Flags,
                    .modifiers = self.declarationModifiers(v, node, n.modifiers orelse 0),
                    .modifierFlags = n.modifierFlags,
                    .AsteriskToken = n.AsteriskToken,
                    .Body = if (n.Body) |body| v.visitNode(body) else null,
                    .Keyword = n.Keyword,
                    .name = n.name,
                } }) catch unreachable;
                self.setOriginal(updated, node);
                break :blk updated;
            },
            .ModuleBlock => self.transformModuleBlock(v, node),
            .InterfaceDeclaration => |n| blk: {
                const parent = v.tree.getNodeParent(node);
                if (parent == 0 or v.tree.getNode(parent) != .ModuleBlock) break :blk v.visitEachChild(node);
                const updated = v.tree.pushNode(.{ .InterfaceDeclaration = .{
                    .Symbol = n.Symbol,
                    .Flags = n.Flags,
                    .modifiers = self.typeDeclarationModifiers(v, node, n.modifiers orelse 0),
                    .modifierFlags = n.modifierFlags,
                    .name = n.name,
                    .TypeParameters = n.TypeParameters,
                    .HeritageClauses = n.HeritageClauses,
                    .Members = v.visitNodes(n.Members),
                } }) catch unreachable;
                self.setOriginal(updated, node);
                break :blk updated;
            },
            .TypeAliasDeclaration => |n| blk: {
                const parent = v.tree.getNodeParent(node);
                if (parent == 0 or v.tree.getNode(parent) != .ModuleBlock) break :blk v.visitEachChild(node);
                const updated = v.tree.pushNode(.{ .TypeAliasDeclaration = .{
                    .Symbol = n.Symbol,
                    .Flags = n.Flags,
                    .modifiers = self.typeDeclarationModifiers(v, node, n.modifiers orelse 0),
                    .modifierFlags = n.modifierFlags,
                    .name = n.name,
                    .TypeParameters = n.TypeParameters,
                    .Type = v.visitNode(n.Type),
                } }) catch unreachable;
                self.setOriginal(updated, node);
                break :blk updated;
            },
            .JSTypeAliasDeclaration => |n| blk: {
                const source = sourceFileAncestor(v.tree, node) orelse 0;
                const is_module = if (source != 0) @import("../ast/ast_utils.zig").isExternalOrCommonJSModule(v.tree, source) else false;
                const modifiers = if (is_module) f.newModifierList(&.{f.newToken(.{ .ExportKeyword = {} })}) else null;
                const modifier_flags: u32 = if (is_module) @import("../ast/ast_utils.zig").ModifierFlags.Export else 0;
                const updated = v.tree.pushNode(.{ .TypeAliasDeclaration = .{
                    .Symbol = n.Symbol,
                    .Flags = n.Flags,
                    .modifiers = modifiers,
                    .modifierFlags = modifier_flags,
                    .name = n.name,
                    .TypeParameters = n.TypeParameters,
                    .Type = unwrapJSDocTypeExpression(v.tree, f, n.Type, self.allocator),
                } }) catch unreachable;
                self.setOriginal(updated, node);
                break :blk updated;
            },
            .ClassStaticBlockDeclaration => 0,
            .MethodDeclaration => |n| self.transformMethod(v, node, n),
            .Constructor => |n| self.transformConstructor(v, node, n),
            .GetAccessor => |n| blk: {
                if (v.tree.getNode(n.name) == .PrivateIdentifier) break :blk 0;
                const updated = f.updateGetAccessorDeclaration(node, n, self.classMemberModifiers(v, n.modifiers orelse 0), n.name, v.visitNodes(n.TypeParameters orelse 0), v.visitNodes(n.Parameters), inferredType(v, f, n.Type orelse 0, 0), 0);
                self.setOriginal(updated, node);
                break :blk updated;
            },
            .SetAccessor => |n| blk: {
                if (v.tree.getNode(n.name) == .PrivateIdentifier) break :blk 0;
                // Synthesize `value: any` when there are no parameters (Go behavior)
                const params_list = v.visitNodes(n.Parameters);
                const params_arr = v.tree.getNodeList(params_list);
                const final_params = if (params_arr.len == 0) blk2: {
                    const any_kw = f.newToken(.{ .AnyKeyword = {} });
                    const value_id = v.tree.pushNode(.{ .Identifier = .{ .Flags = 0, .Text = "value" } }) catch unreachable;
                    const synth_param = v.tree.pushNode(.{ .Parameter = .{
                        .Flags = 0,
                        .Symbol = 0,
                        .modifiers = null,
                        .modifierFlags = 0,
                        .DotDotDotToken = null,
                        .name = value_id,
                        .QuestionToken = null,
                        .Type = any_kw,
                        .Initializer = null,
                    } }) catch unreachable;
                    break :blk2 f.newNodeList(&.{synth_param});
                } else params_list;
                const updated = f.updateSetAccessorDeclaration(node, n, self.classMemberModifiers(v, n.modifiers orelse 0), n.name, v.visitNodes(n.TypeParameters orelse 0), final_params, 0, 0);
                self.setOriginal(updated, node);
                break :blk updated;
            },
            .PropertyDeclaration => |n| if (v.tree.getNode(n.name) == .PrivateIdentifier) 0 else blk: {
                const updated = f.updatePropertyDeclaration(node, n, self.classMemberModifiers(v, n.modifiers orelse 0), n.name, n.PostfixToken orelse 0, self.inferredDeclarationType(v, f, n.name, n.Type orelse 0, n.Initializer orelse 0), 0);
                self.setOriginal(updated, node);
                break :blk updated;
            },
            .VariableDeclaration => |n| blk: {
                const initializer = n.Initializer orelse 0;
                const preserve_literal = isConstVariable(v.tree, node) and isDeclarationLiteral(v.tree, initializer);
                const inf_type = if (preserve_literal) 0 else self.inferredDeclarationType(v, f, n.name, n.Type orelse 0, initializer);
                const updated = f.updateVariableDeclaration(node, n, v.visitNode(n.name), 0, inf_type, if (preserve_literal) normalizedDeclarationLiteral(v.tree, initializer) else 0);
                self.setOriginal(updated, node);
                break :blk updated;
            },
            .Parameter => |n| blk: {
                const parent = v.tree.getNodeParent(node);
                var question_token = n.QuestionToken orelse 0;
                var type_node = n.Type orelse 0;

                const jsdoc_type = inlineJSDocType(v.tree, f, node, self.allocator) orelse jsdocParameterType(v.tree, f, parent, n.name, 0, self.allocator);
                if (type_node == 0) type_node = jsdoc_type orelse inferredType(v, f, 0, n.Initializer orelse 0);

                if (parent != 0 and n.Initializer != null) {
                    const parent_node = v.tree.getNode(parent);
                    const params_list_idx: ?u32 = switch (parent_node) {
                        .FunctionDeclaration => |p| p.Parameters,
                        .MethodDeclaration => |p| p.Parameters,
                        .Constructor => |p| p.Parameters,
                        .GetAccessor => |p| p.Parameters,
                        .SetAccessor => |p| p.Parameters,
                        .ArrowFunction => |p| p.Parameters,
                        .FunctionExpression => |p| p.Parameters,
                        else => null,
                    };
                    if (params_list_idx) |list_idx| {
                        const original_parameters = v.tree.getNodeList(list_idx);
                        var current_index: ?usize = null;
                        for (original_parameters, 0..) |p_idx, i| {
                            if (p_idx == node) {
                                current_index = i;
                                break;
                            }
                        }
                        if (current_index) |idx| {
                            var all_subsequent_optional = true;
                            for (original_parameters[idx + 1 ..]) |sub_idx| {
                                const sub = v.tree.getNode(sub_idx).Parameter;
                                if (sub.Initializer == null and sub.QuestionToken == null and sub.DotDotDotToken == null) {
                                    all_subsequent_optional = false;
                                    break;
                                }
                            }
                            if (all_subsequent_optional) {
                                if (question_token == 0) {
                                    question_token = f.tree.pushNode(.{ .QuestionToken = {} }) catch unreachable;
                                }
                            } else {
                                if (type_node != 0 and !typeContainsUndefined(v.tree, type_node)) {
                                    type_node = unwrapParenthesizedTypeNode(v.tree, type_node);
                                    const undefined_kw = f.tree.pushNode(.{ .UndefinedKeyword = {} }) catch unreachable;
                                    const types_arr = [_]ast.NodeIndex{ type_node, undefined_kw };
                                    const types_list = f.tree.pushNodeList(&types_arr) catch unreachable;
                                    type_node = f.tree.pushNode(.{ .UnionType = .{
                                        .Flags = 0,
                                        .Types = types_list,
                                    } }) catch unreachable;
                                }
                            }
                        }
                    }
                }

                break :blk f.updateParameterDeclaration(node, n, v.visitModifiers(n.modifiers orelse 0), n.DotDotDotToken orelse 0, v.visitNode(n.name), question_token, type_node, 0);
            },
            .EnumMember => |n| blk: {
                // Normalize `-NaN` → `NaN` in enum initializers (Go behavior: -NaN evaluates to NaN)
                const init = n.Initializer orelse break :blk v.visitEachChild(node);
                const init_node = v.tree.getNode(init);
                const normalized_init: ast.NodeIndex = if (init_node == .PrefixUnaryExpression) norm: {
                    const pue = init_node.PrefixUnaryExpression;
                    const is_minus = @as(@import("../ast/kind.zig").Kind, @enumFromInt(pue.Operator)) == .MinusToken;
                    if (!is_minus) break :norm init;
                    const operand = v.tree.getNode(pue.Operand);
                    if (operand == .Identifier and std.mem.eql(u8, operand.Identifier.Text, "NaN")) {
                        break :norm f.newIdentifier("NaN");
                    }
                    break :norm init;
                } else init;
                if (normalized_init == init) break :blk v.visitEachChild(node);
                break :blk v.tree.pushNode(.{ .EnumMember = .{
                    .Flags = n.Flags,
                    .Symbol = n.Symbol,
                    .modifiers = n.modifiers,
                    .modifierFlags = n.modifierFlags,
                    .name = n.name,
                    .PostfixToken = n.PostfixToken,
                    .Initializer = normalized_init,
                } }) catch unreachable;
            },
            .LiteralType => |literal| blk: {
                if (v.tree.getNode(literal.Literal) != .StringLiteral) break :blk v.visitEachChild(node);
                const original = v.tree.getNode(literal.Literal).StringLiteral;
                const cloned = v.tree.pushNode(.{ .StringLiteral = .{ .Flags = 0, .Text = original.Text, .TokenFlags = original.TokenFlags | (1 << 30) } }) catch unreachable;
                break :blk v.tree.pushNode(.{ .LiteralType = .{ .Flags = literal.Flags, .Literal = cloned } }) catch unreachable;
            },
            .TupleType => blk: {
                self.transformer.emitContext.addEmitFlags(node, @import("../printer/emitflags.zig").EmitFlags.SingleLine) catch {};
                break :blk v.visitEachChild(node);
            },
            else => v.visitEachChild(node),
        };
        if (result != 0 and result != node) self.transformer.emitContext.setOriginal(result, node) catch {};
        return result;
    }

    /// Mirror of Go's transformImportDeclaration: elide namespace/named imports that
    /// are not referenced in type positions. Without a full semantic resolver we use
    /// a simple heuristic: if the ImportClause has only a NamespaceImport (no default
    /// name, no named specifiers) check whether the namespace name appears anywhere
    /// else in the source-file symbol table. If we have no semantic info, keep it.
    fn transformImportDeclaration(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, decl: ast_gen.ImportDeclarationNode) ast.NodeIndex {
        const f = self.transformer.factory;
        // import "mod" with no clause: always keep (side-effect import)
        const clause_idx = decl.ImportClause orelse return node;
        const clause_node = v.tree.getNode(clause_idx);
        if (clause_node != .ImportClause) return node;
        const clause = clause_node.ImportClause;
        if ((clause.PhaseModifier orelse 0) != 0 and v.tree.getNodeKind(clause.PhaseModifier.?) == .TypeKeyword) return node;

        const resolvable = self.isModuleResolvable(self.semantic_file orelse 0, decl.ModuleSpecifier, v.tree);
        var used = false;
        if (clause.name) |name| {
            const name_text = @import("../ast/ast_utils.zig").getText(v.tree, name);
            used = used or self.referenced_identifiers.contains(name_text) or identifierUsedByDeclaration(v.tree, node, name_text, self.allocator, false, resolvable);
        }

        // Namespace import: import * as ns from '...'
        // Elide when the namespace symbol is unused in declaration positions.
        if (clause.NamedBindings) |bindings_idx| {
            const binding_node = v.tree.getNode(bindings_idx);
            if (binding_node == .NamespaceImport) {
                const ns = binding_node.NamespaceImport;
                const ns_text = @import("../ast/ast_utils.zig").getText(v.tree, ns.name);
                used = used or self.referenced_identifiers.contains(ns_text) or identifierUsedByDeclaration(v.tree, node, ns_text, self.allocator, false, resolvable);
            } else if (binding_node == .NamedImports) {
                for (v.tree.getNodeList(binding_node.NamedImports.Elements)) |specifier_index| {
                    const specifier = v.tree.getNode(specifier_index).ImportSpecifier;
                    const local_name = @import("../ast/ast_utils.zig").getText(v.tree, specifier.name);
                    if (identifierUsedInComputedProperty(v.tree, local_name)) return node;
                    const can_inline_spread = if (self.semantic_program) |program| if (self.semantic_file) |file| program.resolveAlias(file, local_name) != null else false else false;
                    used = used or self.referenced_identifiers.contains(local_name) or if (can_inline_spread)
                        identifierHasNonInlineUse(v.tree, node, local_name)
                    else
                        identifierUsedByDeclaration(v.tree, node, local_name, self.allocator, false, resolvable);
                }
            }
        }
        _ = f;
        return if (used) node else 0;
    }

    fn declarationModifiers(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, modifiers: ast.NodeIndex) ast.NodeIndex {
        const visited = v.visitModifiers(modifiers);
        const utils = @import("../ast/ast_utils.zig");
        const parent = v.tree.getNodeParent(node);
        if (parent != 0 and v.tree.getNode(parent) == .ModuleBlock) return self.withoutExportModifier(v.tree, visited);
        // Don't add `declare` if already ambient or has `default` modifier
        if (utils.hasSyntacticModifier(v.tree, node, utils.ModifierFlags.Ambient) or utils.hasSyntacticModifier(v.tree, node, utils.ModifierFlags.Default)) return visited;
        // Only add `declare` when the node is a direct child of SourceFile (matching Go's ensureModifierFlags)
        const parent_is_file = parent == 0 or v.tree.getNode(parent) == .SourceFile;
        if (!parent_is_file) return visited;
        var items = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer items.deinit(self.allocator);
        const f = self.transformer.factory;
        if (utils.hasSyntacticModifier(v.tree, node, utils.ModifierFlags.Export)) {
            items.append(self.allocator, f.newToken(.{ .ExportKeyword = {} })) catch unreachable;
        }
        items.append(self.allocator, f.newToken(.{ .DeclareKeyword = {} })) catch unreachable;
        return f.newModifierList(items.items);
    }

    fn transformVariableStatement(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, statement: ast_gen.VariableStatementNode) ast.NodeIndex {
        const f = self.transformer.factory;
        const list = v.tree.getNode(statement.DeclarationList).VariableDeclarationList;
        var declarations = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer declarations.deinit(self.allocator);
        var changed = false;
        for (v.tree.getNodeList(list.Declarations)) |declaration_index| {
            const declaration = v.tree.getNode(declaration_index).VariableDeclaration;
            if (v.tree.getNode(declaration.name) != .ObjectBindingPattern) {
                declarations.append(self.allocator, v.visitNode(declaration_index)) catch unreachable;
                continue;
            }
            changed = true;
            for (v.tree.getNodeList(v.tree.getNode(declaration.name).ObjectBindingPattern.Elements)) |element_index| {
                if (v.tree.getNode(element_index) != .BindingElement) continue;
                const element = v.tree.getNode(element_index).BindingElement;
                const local_name = element.name orelse continue;
                const property_name = element.PropertyName orelse local_name;
                const inferred = self.inferDestructuredImportType(v, declaration.Initializer orelse 0, @import("../ast/ast_utils.zig").getText(v.tree, property_name)) orelse f.newToken(.{ .AnyKeyword = {} });
                declarations.append(self.allocator, f.newVariableDeclaration(local_name, 0, inferred, 0)) catch unreachable;
            }
        }
        const declaration_list = if (changed) f.newVariableDeclarationList(f.newNodeList(declarations.items), list.Flags) else v.visitNode(statement.DeclarationList);
        const updated = f.updateVariableStatement(node, statement, self.declarationModifiers(v, node, statement.modifiers orelse 0), declaration_list);
        self.setOriginal(updated, node);
        return updated;
    }

    fn inferDestructuredImportType(self: *DeclarationTransformer, v: *visitor.NodeVisitor, initializer: ast.NodeIndex, property_name: []const u8) ?ast.NodeIndex {
        if (v.tree.getNode(initializer) != .Identifier) return null;
        const program = self.semantic_program orelse return null;
        const file = self.semantic_file orelse return null;
        const symbol = program.resolveAlias(file, @import("../ast/ast_utils.zig").getText(v.tree, initializer)) orelse return null;
        const source_file = symbol.declaration_file;
        const source_tree = program.getUnit(source_file).tree();
        if (source_tree.getNode(symbol.declaration) != .VariableDeclaration) return null;
        var expression = source_tree.getNode(symbol.declaration).VariableDeclaration.Initializer orelse return null;
        while (source_tree.getNode(expression) == .AsExpression or source_tree.getNode(expression) == .ParenthesizedExpression) expression = switch (source_tree.getNode(expression)) {
            .AsExpression => |value| value.Expression,
            .ParenthesizedExpression => |value| value.Expression,
            else => unreachable,
        };
        if (source_tree.getNode(expression) != .ObjectLiteralExpression) return null;
        var function_name: ?[]const u8 = null;
        for (source_tree.getNodeList(source_tree.getNode(expression).ObjectLiteralExpression.Properties)) |property| switch (source_tree.getNode(property)) {
            .ShorthandPropertyAssignment => |value| {
                if (std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(source_tree, value.name), property_name)) function_name = @import("../ast/ast_utils.zig").getText(source_tree, value.name);
            },
            .PropertyAssignment => |value| {
                if (std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(source_tree, value.name), property_name) and source_tree.getNode(value.Initializer) == .Identifier) function_name = @import("../ast/ast_utils.zig").getText(source_tree, value.Initializer);
            },
            else => {},
        };
        const wanted = function_name orelse return null;
        for (source_tree.getNodeList(source_tree.getNode(program.getUnit(source_file).source_file).SourceFile.Statements)) |statement| {
            if (source_tree.getNode(statement) != .FunctionDeclaration) continue;
            const function = source_tree.getNode(statement).FunctionDeclaration;
            const name = function.name orelse continue;
            if (!std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(source_tree, name), wanted)) continue;
            const return_type = function.Type orelse return null;
            return v.tree.pushNode(.{ .FunctionType = .{
                .Flags = 0,
                .modifiers = null,
                .modifierFlags = 0,
                .Symbol = 0,
                .TypeParameters = null,
                .Parameters = self.copyForeignList(source_tree, function.Parameters, &.{}),
                .Type = self.copyCrossFileType(v, source_file, source_tree, return_type),
                .FullSignature = null,
            } }) catch unreachable;
        }
        return null;
    }

    fn copyCrossFileType(self: *DeclarationTransformer, v: *visitor.NodeVisitor, source_file: program_mod.FileId, source_tree: *ast.Ast, node: ast.NodeIndex) ast.NodeIndex {
        const f = self.transformer.factory;
        if (source_tree.getNode(node) == .TypeReference) {
            const reference = source_tree.getNode(node).TypeReference;
            if (source_tree.getNode(reference.TypeName) == .Identifier) {
                const name = @import("../ast/ast_utils.zig").getText(source_tree, reference.TypeName);
                if (self.semantic_program.?.resolveAlias(source_file, name)) |symbol| {
                    for (self.semantic_program.?.getUnit(source_file).dependencies.items) |dependency| if (dependency.resolved == symbol.file) {
                        const argument = v.tree.pushNode(.{ .LiteralType = .{ .Flags = 0, .Literal = f.newStringLiteral(dependency.specifier, false) } }) catch unreachable;
                        return v.tree.pushNode(.{ .ImportType = .{ .Flags = 0, .TypeArguments = null, .IsTypeOf = 0, .Argument = argument, .Attributes = null, .Qualifier = f.newIdentifier(name) } }) catch unreachable;
                    };
                }
            }
            var args: ?ast.NodeIndex = null;
            if (reference.TypeArguments) |arguments| {
                var copied = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer copied.deinit(self.allocator);
                for (source_tree.getNodeList(arguments)) |argument| copied.append(self.allocator, self.copyCrossFileType(v, source_file, source_tree, argument)) catch unreachable;
                args = f.newNodeList(copied.items);
            }
            return v.tree.pushNode(.{ .TypeReference = .{ .Flags = 0, .TypeName = f.newIdentifier(@import("../ast/ast_utils.zig").getText(source_tree, reference.TypeName)), .TypeArguments = args } }) catch unreachable;
        }
        return self.copyForeignTypeNode(source_tree, node, &.{});
    }

    fn typeDeclarationModifiers(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, modifiers: ast.NodeIndex) ast.NodeIndex {
        const visited = v.visitModifiers(modifiers);
        const parent = v.tree.getNodeParent(node);
        return if (parent != 0 and v.tree.getNode(parent) == .ModuleBlock) self.withoutExportModifier(v.tree, visited) else visited;
    }

    fn classMemberModifiers(self: *DeclarationTransformer, v: *visitor.NodeVisitor, modifiers: ast.NodeIndex) ast.NodeIndex {
        if (modifiers == 0) return 0;
        const visited = v.visitModifiers(modifiers);
        var kept = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer kept.deinit(self.allocator);
        for (v.tree.getNodeList(visited)) |modifier| {
            const kind = v.tree.getNodeKind(modifier);
            if (kind != .PublicKeyword and kind != .AsyncKeyword and kind != .OverrideKeyword) {
                kept.append(self.allocator, modifier) catch unreachable;
            }
        }
        return if (kept.items.len == 0) 0 else self.transformer.factory.newModifierList(kept.items);
    }

    fn withoutExportModifier(self: *DeclarationTransformer, tree: *ast.Ast, modifiers: ast.NodeIndex) ast.NodeIndex {
        if (modifiers == 0) return 0;
        var kept = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer kept.deinit(self.allocator);
        for (tree.getNodeList(modifiers)) |modifier| if (tree.getNodeKind(modifier) != .ExportKeyword) kept.append(self.allocator, modifier) catch unreachable;
        return if (kept.items.len == 0) 0 else self.transformer.factory.newModifierList(kept.items);
    }

    fn transformConstructor(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, constructor: ast_gen.ConstructorDeclarationNode) ast.NodeIndex {
        const f = self.transformer.factory;
        const utils = @import("../ast/ast_utils.zig");
        var properties = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer properties.deinit(self.allocator);
        var parameters = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer parameters.deinit(self.allocator);
        const original_parameters = v.tree.getNodeList(constructor.Parameters);
        for (original_parameters, 0..) |parameter_index, index| {
            const parameter = v.tree.getNode(parameter_index).Parameter;
            const is_property = utils.isParameterPropertyDeclaration(v.tree, parameter_index, node);
            const jsdoc_type = inlineJSDocType(v.tree, f, parameter_index, self.allocator) orelse jsdocParameterType(v.tree, f, node, parameter.name, index, self.allocator);
            var type_node = parameter.Type orelse jsdoc_type orelse inferredType(v, f, 0, parameter.Initializer orelse 0);

            // With exact optional property types, an optional parameter
            // property still accepts an explicit undefined at the constructor
            // boundary. Its synthesized property and constructor parameter
            // therefore retain `| undefined` even though the property is `?`.
            if (is_property and parameter.Initializer == null and parameter.QuestionToken != null and type_node != 0 and !typeContainsUndefined(v.tree, type_node)) {
                const undefined_kw = f.newToken(.{ .UndefinedKeyword = {} });
                type_node = v.tree.pushNode(.{ .UnionType = .{
                    .Flags = 0,
                    .Types = f.newNodeList(&.{ unwrapParenthesizedTypeNode(v.tree, type_node), undefined_kw }),
                } }) catch unreachable;
            }

            var question = parameter.QuestionToken orelse 0;
            if (parameter.Initializer != null) {
                var all_subsequent_optional = true;
                for (original_parameters[index + 1 ..]) |sub_idx| {
                    const sub = v.tree.getNode(sub_idx).Parameter;
                    if (sub.Initializer == null and sub.QuestionToken == null and sub.DotDotDotToken == null) {
                        all_subsequent_optional = false;
                        break;
                    }
                }
                if (all_subsequent_optional) {
                    if (question == 0) {
                        question = f.tree.pushNode(.{ .QuestionToken = {} }) catch unreachable;
                    }
                } else {
                    if (type_node != 0 and !typeContainsUndefined(v.tree, type_node)) {
                        type_node = unwrapParenthesizedTypeNode(v.tree, type_node);
                        const undefined_kw = f.tree.pushNode(.{ .UndefinedKeyword = {} }) catch unreachable;
                        const types_arr = [_]ast.NodeIndex{ type_node, undefined_kw };
                        const types_list = f.tree.pushNodeList(&types_arr) catch unreachable;
                        type_node = f.tree.pushNode(.{ .UnionType = .{
                            .Flags = 0,
                            .Types = types_list,
                        } }) catch unreachable;
                    }
                }
            }

            if (is_property) {
                const property_modifiers = parameterPropertyDeclarationModifiers(v.tree, f, parameter.modifiers orelse 0, self.allocator);
                const is_private = utils.hasSyntacticModifier(v.tree, parameter_index, utils.ModifierFlags.Private);
                const property = f.newPropertyDeclaration(property_modifiers, parameter.name, parameter.QuestionToken orelse 0, if (is_private) 0 else type_node, 0);
                self.transformer.emitContext.setOriginal(property, parameter_index) catch {};
                properties.append(self.allocator, property) catch unreachable;
            }
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

    fn transformClassExpressionToDeclaration(self: *DeclarationTransformer, v: *visitor.NodeVisitor, class_expr_idx: ast.NodeIndex, className: ast.NodeIndex, modifiers: ast.NodeIndex) ast.NodeIndex {
        const f = self.transformer.factory;
        const class = v.tree.getNode(class_expr_idx).ClassExpression;
        var jsdoc_parameters = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer jsdoc_parameters.deinit(self.allocator);
        collectJSDocTypeParameters(v.tree, f, class_expr_idx, &jsdoc_parameters, self.allocator);
        const type_parameters = if ((class.TypeParameters orelse 0) != 0)
            v.visitNodes(class.TypeParameters.?)
        else if (jsdoc_parameters.items.len != 0)
            f.newNodeList(jsdoc_parameters.items)
        else
            0;
        var members = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer members.deinit(self.allocator);
        var has_private_identifier = false;
        for (v.tree.getNodeList(class.Members)) |member| {
            const member_name: ?ast.NodeIndex = switch (v.tree.getNode(member)) {
                .PropertyDeclaration => |declaration| declaration.name,
                .MethodDeclaration => |declaration| declaration.name,
                .GetAccessor => |declaration| declaration.name,
                .SetAccessor => |declaration| declaration.name,
                else => null,
            };
            if (member_name) |name| if (v.tree.getNode(name) == .PrivateIdentifier) {
                has_private_identifier = true;
                break;
            };
        }
        if (has_private_identifier) {
            const private_name = f.newPrivateIdentifier("#private");
            members.append(self.allocator, f.newPropertyDeclaration(0, private_name, 0, 0, 0)) catch unreachable;
        }
        self.appendJavaScriptAssignmentProperties(v, class_expr_idx, &members);
        const visited_members = v.visitNodes(class.Members);
        if (visited_members != 0) members.appendSlice(self.allocator, v.tree.getNodeList(visited_members)) catch unreachable;

        return v.tree.pushNode(.{ .ClassDeclaration = .{
            .Symbol = class.Symbol,
            .Flags = class.Flags,
            .modifiers = modifiers,
            .modifierFlags = 0,
            .name = className,
            .TypeParameters = type_parameters,
            .HeritageClauses = v.visitNodes(class.HeritageClauses orelse 0),
            .Members = f.newNodeList(members.items),
        } }) catch unreachable;
    }

    fn transformClass(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, class: ast_gen.ClassDeclarationNode) ast.NodeIndex {
        const f = self.transformer.factory;
        var jsdoc_parameters = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer jsdoc_parameters.deinit(self.allocator);
        collectJSDocTypeParameters(v.tree, f, node, &jsdoc_parameters, self.allocator);
        const type_parameters = if ((class.TypeParameters orelse 0) != 0)
            v.visitNodes(class.TypeParameters.?)
        else if (jsdoc_parameters.items.len != 0)
            f.newNodeList(jsdoc_parameters.items)
        else
            0;
        var members = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer members.deinit(self.allocator);
        var has_private_identifier = false;
        for (v.tree.getNodeList(class.Members)) |member| {
            const member_name: ?ast.NodeIndex = switch (v.tree.getNode(member)) {
                .PropertyDeclaration => |declaration| declaration.name,
                .MethodDeclaration => |declaration| declaration.name,
                .GetAccessor => |declaration| declaration.name,
                .SetAccessor => |declaration| declaration.name,
                else => null,
            };
            if (member_name) |name| if (v.tree.getNode(name) == .PrivateIdentifier) {
                has_private_identifier = true;
                break;
            };
        }
        if (has_private_identifier) {
            const private_name = f.newPrivateIdentifier("#private");
            members.append(self.allocator, f.newPropertyDeclaration(0, private_name, 0, 0, 0)) catch unreachable;
        }
        self.appendJavaScriptAssignmentProperties(v, node, &members);
        const visited_members = v.visitNodes(class.Members);
        if (visited_members != 0) members.appendSlice(self.allocator, v.tree.getNodeList(visited_members)) catch unreachable;
        const heritage = if (jsdocAugmentsClassName(v.tree, node)) |class_name| blk: {
            const clause = v.tree.pushNode(.{ .HeritageClause = .{
                .Flags = 0,
                .Token = @intFromEnum(@import("../ast/kind.zig").Kind.ExtendsKeyword),
                .Types = f.newNodeList(&.{v.visitNode(class_name)}),
            } }) catch unreachable;
            break :blk f.newNodeList(&.{clause});
        } else v.visitNodes(class.HeritageClauses orelse 0);

        const extends_clause = getEffectiveBaseTypeNode(v.tree, node);
        var extract_base = false;
        var var_stmt: ast.NodeIndex = 0;
        var final_heritage = heritage;

        if (extends_clause) |extends_idx| {
            const extends = v.tree.getNode(extends_idx).ExpressionWithTypeArguments;
            if (!@import("../ast/ast_utils.zig").isEntityNameExpression(v.tree, extends.Expression) and v.tree.getNode(extends.Expression) != .NullKeyword) {
                extract_base = true;
                const oldId = if (class.name orelse 0 != 0 and v.tree.getNode(class.name.?) == .Identifier)
                    @import("../ast/ast_utils.zig").getText(v.tree, class.name.?)
                else
                    "default";
                const baseNameText = std.fmt.allocPrint(self.allocator, "{s}_base", .{oldId}) catch unreachable;
                const newId = f.createUniqueName(baseNameText) catch unreachable;

                var resolved_type: ast.NodeIndex = 0;

                if (v.tree.getNode(extends.Expression) == .CallExpression) {
                    const call = v.tree.getNode(extends.Expression).CallExpression;
                    if (v.tree.getNode(call.Expression) == .Identifier) {
                        if (self.semantic_program) |program| {
                            if (self.semantic_file) |file| {
                                const callee_name = @import("../ast/ast_utils.zig").getText(v.tree, call.Expression);
                                if (program.resolveAlias(file, callee_name)) |symbol| {
                                    const foreign_tree = program.getUnit(symbol.declaration_file).tree();
                                    if (foreign_tree.getNode(symbol.declaration) == .FunctionDeclaration) {
                                        const function = foreign_tree.getNode(symbol.declaration).FunctionDeclaration;
                                        const function_type = function.Type orelse 0;
                                        if (function_type != 0) {
                                            var substitutions = std.ArrayListUnmanaged(TypeSubstitution).empty;
                                            defer substitutions.deinit(self.allocator);

                                            if (function.TypeParameters) |type_params| {
                                                const type_params_list = foreign_tree.getNodeList(type_params);
                                                if (call.TypeArguments) |type_args| {
                                                    const type_args_list = v.tree.getNodeList(type_args);
                                                    var i: usize = 0;
                                                    while (i < type_params_list.len and i < type_args_list.len) : (i += 1) {
                                                        const tp = foreign_tree.getNode(type_params_list[i]).TypeParameter;
                                                        const tp_name = @import("../ast/ast_utils.zig").getText(foreign_tree, tp.name);
                                                        const arg_copied = v.visitNode(type_args_list[i]);
                                                        substitutions.append(self.allocator, .{
                                                            .name = tp_name,
                                                            .replacement = arg_copied,
                                                        }) catch unreachable;
                                                    }
                                                }
                                            }

                                            resolved_type = self.copyForeignTypeNode(foreign_tree, function_type, substitutions.items);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if (resolved_type == 0) {
                    resolved_type = f.newToken(.{ .AnyKeyword = {} });
                }

                const varDecl = f.newVariableDeclaration(newId, 0, resolved_type, 0);
                const parent = v.tree.getNodeParent(node);
                const parent_is_file = parent == 0 or v.tree.getNode(parent) == .SourceFile;
                const mods = if (parent_is_file)
                    f.newModifierList(&.{f.newToken(.{ .DeclareKeyword = {} })})
                else
                    0;

                const varDecl_list = f.newVariableDeclarationList(f.newNodeList(&.{varDecl}), @import("../ast/ast_utils.zig").NodeFlags.Const);
                var_stmt = f.newVariableStatement(mods, varDecl_list);

                const new_expr_with_type_args = f.tree.pushNode(.{ .ExpressionWithTypeArguments = .{
                    .Flags = 0,
                    .Expression = newId,
                    .TypeArguments = if (extends.TypeArguments) |args| v.visitNodes(args) else null,
                } }) catch unreachable;

                var heritage_list = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer heritage_list.deinit(self.allocator);

                const original_heritage = class.HeritageClauses orelse 0;
                if (original_heritage != 0) {
                    for (v.tree.getNodeList(original_heritage)) |clause_idx| {
                        const clause = v.tree.getNode(clause_idx).HeritageClause;
                        if (clause.Token == @intFromEnum(@import("../ast/kind.zig").Kind.ExtendsKeyword)) {
                            const updated_clause = f.tree.pushNode(.{ .HeritageClause = .{
                                .Flags = 0,
                                .Token = clause.Token,
                                .Types = f.newNodeList(&.{new_expr_with_type_args}),
                            } }) catch unreachable;
                            heritage_list.append(self.allocator, updated_clause) catch unreachable;
                        } else {
                            heritage_list.append(self.allocator, v.visitNode(clause_idx)) catch unreachable;
                        }
                    }
                }
                final_heritage = f.newNodeList(heritage_list.items);
            }
        }

        const class_decl = f.updateClassDeclaration(node, class, self.declarationModifiers(v, node, class.modifiers orelse 0), class.name orelse 0, type_parameters, final_heritage, f.newNodeList(members.items));
        if (extract_base) {
            return f.newSyntaxList(&.{ var_stmt, class_decl });
        }
        return class_decl;
    }

    fn transformEnum(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, declaration: ast_gen.EnumDeclarationNode) ast.NodeIndex {
        const f = self.transformer.factory;
        var members = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer members.deinit(self.allocator);
        var next_value: i64 = 0;
        for (v.tree.getNodeList(declaration.Members)) |member_index| {
            var member = v.tree.getNode(member_index).EnumMember;
            if (member.Initializer) |initializer| {
                if (v.tree.getNode(initializer) == .NumericLiteral) next_value = (std.fmt.parseInt(i64, @import("../ast/ast_utils.zig").getText(v.tree, initializer), 10) catch next_value) + 1;
                if (v.tree.getNode(initializer) == .StringLiteral) member.Initializer = f.newStringLiteral(@import("../ast/ast_utils.zig").getText(v.tree, initializer), false);
            } else {
                const text = std.fmt.allocPrint(self.allocator, "{d}", .{next_value}) catch unreachable;
                member.Initializer = f.newNumericLiteral(text, 0);
                next_value += 1;
            }
            const updated = v.tree.pushNode(.{ .EnumMember = member }) catch unreachable;
            members.append(self.allocator, v.visitNode(updated)) catch unreachable;
        }
        return v.tree.pushNode(.{ .EnumDeclaration = .{
            .Symbol = declaration.Symbol,
            .Flags = declaration.Flags,
            .modifiers = self.declarationModifiers(v, node, declaration.modifiers orelse 0),
            .modifierFlags = declaration.modifierFlags,
            .name = declaration.name,
            .Members = f.newNodeList(members.items),
        } }) catch unreachable;
    }

    fn appendJavaScriptAssignmentProperties(self: *DeclarationTransformer, v: *visitor.NodeVisitor, class_node: ast.NodeIndex, output: *std.ArrayListUnmanaged(ast.NodeIndex)) void {
        const bound = self.semantic_binder orelse blk: {
            const program = self.semantic_program orelse return;
            const file = self.semantic_file orelse return;
            break :blk program.getBinder(file) orelse return;
        };
        const class_symbol = v.tree.getNodeSymbol(class_node) orelse return;

        const Candidate = struct { symbol_index: ast_gen.SymbolIndex, first_declaration: ast.NodeIndex, is_static: bool };
        var candidates = std.ArrayListUnmanaged(Candidate).empty;
        defer candidates.deinit(self.allocator);
        for (bound.symbols.items, 0..) |sym, symbol_index| {
            if (sym.Parent != class_symbol or
                (sym.Flags & symbol_mod.SymbolFlags.Assignment) == 0 or
                (sym.Flags & (symbol_mod.SymbolFlags.Method | symbol_mod.SymbolFlags.Accessor)) != 0 or
                sym.Declarations.items.len == 0) continue;
            var has_declared_member = false;
            for (sym.Declarations.items) |declaration| {
                if (v.tree.getNode(declaration) != .BinaryExpression) {
                    has_declared_member = true;
                    break;
                }
            }
            if (has_declared_member) continue;
            const is_static = isStaticClassAssignment(v.tree, sym.Declarations.items[0], class_node);
            if (classHasDeclaredMemberName(v.tree, class_node, sym.Name, is_static)) continue;
            const table = if (is_static) bound.symbolExports.getPtr(class_symbol) else bound.symbolMembers.getPtr(class_symbol);
            if (table) |class_table| {
                if (class_table.get(sym.Name)) |selected_symbol| if (selected_symbol != symbol_index) continue;
            }
            candidates.append(self.allocator, .{ .symbol_index = @intCast(symbol_index), .first_declaration = sym.Declarations.items[0], .is_static = is_static }) catch unreachable;
        }
        std.mem.sort(Candidate, candidates.items, {}, struct {
            fn lessThan(_: void, a: Candidate, b: Candidate) bool {
                return a.first_declaration < b.first_declaration;
            }
        }.lessThan);

        const f = self.transformer.factory;
        for (candidates.items) |candidate| {
            const sym = bound.symbols.items[candidate.symbol_index];
            const name = f.newIdentifier(sym.Name);
            const modifiers = if (candidate.is_static) f.newModifierList(&.{f.newToken(.{ .StaticKeyword = {} })}) else 0;
            const type_node = assignmentSymbolTypeNode(v.tree, f, sym.Declarations.items, candidate.is_static);
            const property = f.newPropertyDeclaration(modifiers, name, 0, type_node, 0);
            self.transformer.emitContext.setOriginal(property, candidate.first_declaration) catch {};
            output.append(self.allocator, property) catch unreachable;
        }
    }

    fn appendCommonJSExportDeclarations(self: *DeclarationTransformer, v: *visitor.NodeVisitor, source_file: ast.NodeIndex, output: *std.ArrayListUnmanaged(ast.NodeIndex)) void {
        const source = v.tree.getNode(source_file).SourceFile;
        if (source.CommonJSModuleIndicator == null) return;
        const bound = self.semantic_binder orelse blk: {
            const program = self.semantic_program orelse return;
            const file = self.semantic_file orelse return;
            break :blk program.getBinder(file) orelse return;
        };
        const source_symbol = v.tree.getNodeSymbol(source_file) orelse return;
        const exports = bound.symbolExports.getPtr(source_symbol) orelse return;
        const Candidate = struct { symbol_index: ast_gen.SymbolIndex, first_declaration: ast.NodeIndex };
        var candidates = std.ArrayListUnmanaged(Candidate).empty;
        defer candidates.deinit(self.allocator);
        var iterator = exports.iterator();
        while (iterator.next()) |entry| {
            const symbol_index = entry.value_ptr.*;
            const sym = bound.symbols.items[symbol_index];
            if ((sym.Flags & symbol_mod.SymbolFlags.Assignment) == 0 or sym.Declarations.items.len == 0 or std.mem.startsWith(u8, sym.Name, "__")) continue;
            candidates.append(self.allocator, .{ .symbol_index = symbol_index, .first_declaration = sym.Declarations.items[0] }) catch unreachable;
        }
        std.mem.sort(Candidate, candidates.items, {}, struct {
            fn lessThan(_: void, a: Candidate, b: Candidate) bool {
                return a.first_declaration < b.first_declaration;
            }
        }.lessThan);
        const f = self.transformer.factory;
        for (candidates.items) |candidate| {
            const sym = bound.symbols.items[candidate.symbol_index];
            if (std.mem.eql(u8, sym.Name, symbol_mod.InternalSymbolNameExportEquals)) {
                const declaration_node = sym.Declarations.items[0];
                if (v.tree.getNode(declaration_node) != .BinaryExpression) continue;
                const expression = v.tree.getNode(declaration_node).BinaryExpression.Right;
                // If the RHS is an identifier, emit `export = Identifier;` directly
                if (v.tree.getNode(expression) == .Identifier) {
                    output.append(self.allocator, f.newExportAssignment(0, true, expression)) catch unreachable;
                    continue;
                }
                const name = f.newIdentifier("_exports");
                const type_node = self.inferredDeclarationType(v, f, name, 0, expression);
                const declaration = f.newVariableDeclaration(name, 0, type_node, 0);
                const list = f.newVariableDeclarationList(f.newNodeList(&.{declaration}), @import("../ast/ast_utils.zig").NodeFlags.Const);
                const modifiers = f.newModifierList(&.{f.newToken(.{ .DeclareKeyword = {} })});
                output.append(self.allocator, f.newVariableStatement(modifiers, list)) catch unreachable;
                output.append(self.allocator, f.newExportAssignment(0, true, name)) catch unreachable;
                continue;
            }
            if (!isIdentifierNameText(sym.Name)) {
                const local_name = f.newIdentifier("_exported");
                const declaration = f.newVariableDeclaration(local_name, 0, f.newToken(.{ .AnyKeyword = {} }), 0);
                const list = f.newVariableDeclarationList(f.newNodeList(&.{declaration}), @import("../ast/ast_utils.zig").NodeFlags.Const);
                const modifiers = f.newModifierList(&.{f.newToken(.{ .DeclareKeyword = {} })});
                output.append(self.allocator, f.newVariableStatement(modifiers, list)) catch unreachable;
                const exported_name = f.newStringLiteral(sym.Name, false);
                const specifier = f.newExportSpecifier(false, local_name, exported_name);
                output.append(self.allocator, f.createExportDeclaration(0, false, f.createNamedExports(f.newNodeList(&.{specifier})), 0, 0)) catch unreachable;
                continue;
            }
            if (std.mem.eql(u8, sym.Name, "default")) {
                const binary = v.tree.getNode(sym.Declarations.items[0]).BinaryExpression;
                const local_name = f.newIdentifier("_default");
                const type_node = self.inferredDeclarationType(v, f, local_name, 0, binary.Right);
                const declaration = f.newVariableDeclaration(local_name, 0, type_node, 0);
                const list = f.newVariableDeclarationList(f.newNodeList(&.{declaration}), @import("../ast/ast_utils.zig").NodeFlags.Const);
                const modifiers = f.newModifierList(&.{f.newToken(.{ .DeclareKeyword = {} })});
                output.append(self.allocator, f.newVariableStatement(modifiers, list)) catch unreachable;
                output.append(self.allocator, f.newExportAssignment(0, false, local_name)) catch unreachable;
                continue;
            }
            var class_expr_opt: ?ast.NodeIndex = null;
            if (sym.Declarations.items.len > 0) {
                const decl_node = sym.Declarations.items[0];
                if (v.tree.getNode(decl_node) == .BinaryExpression) {
                    const right = unwrapParenthesizedExpression(v.tree, v.tree.getNode(decl_node).BinaryExpression.Right);
                    // If RHS is an identifier, emit export { rhs as sym.Name } alias
                    if (v.tree.getNode(right) == .Identifier) {
                        const rhs_text = @import("../ast/ast_utils.zig").getText(v.tree, right);
                        const export_name = f.newIdentifier(sym.Name);
                        // When names match, emit `export { Foo }` (no alias)
                        // When names differ, emit `export { rhsName as exportName }`
                        const property_name: ast.NodeIndex = if (std.mem.eql(u8, rhs_text, sym.Name)) 0 else right;
                        const specifier = f.newExportSpecifier(false, property_name, export_name);
                        const named = f.createNamedExports(f.newNodeList(&.{specifier}));
                        output.append(self.allocator, f.createExportDeclaration(0, false, named, 0, 0)) catch unreachable;
                        continue;
                    }
                    if (v.tree.getNode(right) == .ClassExpression) {
                        class_expr_opt = right;
                    }
                }
            }

            const name = f.newIdentifier(sym.Name);
            if (class_expr_opt) |class_expr| {
                const ce = v.tree.getNode(class_expr).ClassExpression;
                const classExprName = ce.name;
                const hasExprName = classExprName != null and classExprName.? != 0 and @import("../ast/ast_utils.zig").getText(v.tree, classExprName.?).len > 0;
                if (hasExprName) {
                    const classExprNameText = @import("../ast/ast_utils.zig").getText(v.tree, classExprName.?);
                    const namesDiffer = !std.mem.eql(u8, sym.Name, classExprNameText);
                    const needsIsolation = namesDiffer or hasClassSelfReference(v.tree, class_expr, classExprNameText, self.allocator);

                    if (needsIsolation) {
                        const nsNameText = if (self.next_ns_id == 0)
                            std.fmt.allocPrint(f.allocator, "_ns", .{}) catch unreachable
                        else
                            std.fmt.allocPrint(f.allocator, "_ns_{d}", .{self.next_ns_id}) catch unreachable;
                        self.next_ns_id += 1;
                        const nsName = f.newIdentifier(nsNameText);
                        var nsMods = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                        defer nsMods.deinit(self.allocator);
                        nsMods.append(self.allocator, f.newToken(.{ .DeclareKeyword = {} })) catch unreachable;

                        const classMods = f.newModifierList(&.{f.newToken(.{ .ExportKeyword = {} })});
                        const className = f.newIdentifier(classExprNameText);
                        const classDecl = self.transformClassExpressionToDeclaration(v, class_expr, className, classMods);

                        const nsDecl = v.tree.pushNode(.{ .ModuleDeclaration = .{
                            .Symbol = 0,
                            .Flags = 0,
                            .modifiers = f.newModifierList(nsMods.items),
                            .modifierFlags = 0,
                            .AsteriskToken = 0,
                            .Body = v.tree.pushNode(.{ .ModuleBlock = .{
                                .Flags = 0,
                                .Statements = f.newNodeList(&.{classDecl}),
                            } }) catch unreachable,
                            .Keyword = @intFromEnum(@import("../ast/kind.zig").Kind.NamespaceKeyword),
                            .name = nsName,
                        } }) catch unreachable;

                        const aliasBase = std.fmt.allocPrint(f.allocator, "_{s}", .{sym.Name}) catch unreachable;
                        const importAlias = f.newIdentifier(aliasBase);
                        const qualifiedName = v.tree.pushNode(.{ .QualifiedName = .{
                            .Flags = 0,
                            .Left = nsName,
                            .Right = className,
                        } }) catch unreachable;
                        const importDecl = v.tree.pushNode(.{ .ImportEqualsDeclaration = .{
                            .Symbol = 0,
                            .Flags = 0,
                            .modifiers = 0,
                            .modifierFlags = 0,
                            .IsTypeOnly = 0,
                            .ModuleReference = qualifiedName,
                            .name = importAlias,
                        } }) catch unreachable;

                        const exportSpecifier = v.tree.pushNode(.{ .ExportSpecifier = .{
                            .Symbol = 0,
                            .Flags = 0,
                            .PropertyName = importAlias,
                            .name = name,
                            .IsTypeOnly = 0,
                        } }) catch unreachable;
                        const exportDecl = f.createExportDeclaration(0, false, f.createNamedExports(f.newNodeList(&.{exportSpecifier})), 0, 0);

                        output.append(self.allocator, nsDecl) catch unreachable;
                        output.append(self.allocator, importDecl) catch unreachable;
                        output.append(self.allocator, exportDecl) catch unreachable;
                        continue;
                    }
                }

                // No isolation needed: names match.
                var classMods = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer classMods.deinit(self.allocator);
                classMods.append(self.allocator, f.newToken(.{ .ExportKeyword = {} })) catch unreachable;
                classMods.append(self.allocator, f.newToken(.{ .DeclareKeyword = {} })) catch unreachable;

                const classModsList = f.newModifierList(classMods.items);
                const className = f.newIdentifier(sym.Name);
                const classDecl = self.transformClassExpressionToDeclaration(v, class_expr, className, classModsList);
                output.append(self.allocator, classDecl) catch unreachable;
                continue;
            }

            const type_node = commonJSAssignmentTypeNode(v.tree, f, sym.Declarations.items, self.allocator);
            const declaration = f.newVariableDeclaration(name, 0, type_node, 0);
            const declarations = f.newNodeList(&.{declaration});
            const list = f.newVariableDeclarationList(declarations, 0);
            const modifiers = f.newModifierList(&.{ f.newToken(.{ .ExportKeyword = {} }), f.newToken(.{ .DeclareKeyword = {} }) });
            output.append(self.allocator, f.newVariableStatement(modifiers, list)) catch unreachable;
        }
    }

    fn appendRequireImportDeclarations(self: *DeclarationTransformer, v: *visitor.NodeVisitor, statements_index: ast.NodeIndex, output: *std.ArrayListUnmanaged(ast.NodeIndex)) void {
        const f = self.transformer.factory;
        for (v.tree.getNodeList(statements_index)) |statement| {
            if (v.tree.getNode(statement) != .VariableStatement) continue;
            const list = v.tree.getNode(v.tree.getNode(statement).VariableStatement.DeclarationList).VariableDeclarationList;
            for (v.tree.getNodeList(list.Declarations)) |declaration_index| {
                const declaration = v.tree.getNode(declaration_index).VariableDeclaration;
                if (v.tree.getNode(declaration.name) != .ObjectBindingPattern) continue;
                const initializer = declaration.Initializer orelse continue;
                if (v.tree.getNode(initializer) != .CallExpression) continue;
                const call = v.tree.getNode(initializer).CallExpression;
                if (v.tree.getNode(call.Expression) != .Identifier or !std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(v.tree, call.Expression), "require")) continue;
                const args = v.tree.getNodeList(call.Arguments);
                if (args.len != 1 or v.tree.getNode(args[0]) != .StringLiteral) continue;
                var specifiers = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer specifiers.deinit(self.allocator);
                for (v.tree.getNodeList(v.tree.getNode(declaration.name).ObjectBindingPattern.Elements)) |element_index| {
                    if (v.tree.getNode(element_index) != .BindingElement) continue;
                    const element = v.tree.getNode(element_index).BindingElement;
                    const local_name = element.name orelse continue;
                    specifiers.append(self.allocator, v.tree.pushNode(.{ .ImportSpecifier = .{
                        .Flags = 0,
                        .Symbol = 0,
                        .IsTypeOnly = 0,
                        .PropertyName = element.PropertyName,
                        .name = local_name,
                    } }) catch unreachable) catch unreachable;
                }
                if (specifiers.items.len == 0) continue;
                const named = v.tree.pushNode(.{ .NamedImports = .{ .Flags = 0, .Elements = f.newNodeList(specifiers.items) } }) catch unreachable;
                const clause = v.tree.pushNode(.{ .ImportClause = .{ .Flags = 0, .Symbol = 0, .PhaseModifier = null, .name = null, .NamedBindings = named } }) catch unreachable;
                output.append(self.allocator, v.tree.pushNode(.{ .ImportDeclaration = .{
                    .Flags = 0,
                    .modifiers = null,
                    .modifierFlags = 0,
                    .Symbol = 0,
                    .ImportClause = clause,
                    .ModuleSpecifier = args[0],
                    .Attributes = null,
                } }) catch unreachable) catch unreachable;
            }
        }
    }

    fn appendExpandoNamespace(self: *DeclarationTransformer, v: *visitor.NodeVisitor, declaration: ast.NodeIndex, output: *std.ArrayListUnmanaged(ast.NodeIndex)) void {
        if (v.tree.getNode(declaration) != .FunctionDeclaration) return;
        const utils = @import("../ast/ast_utils.zig");
        const is_exported = utils.hasSyntacticModifier(v.tree, declaration, utils.ModifierFlags.Export);
        const declaration_parent = v.tree.getNodeParent(declaration);
        if (!is_exported and declaration_parent != 0 and v.tree.getNode(declaration_parent) == .SourceFile and v.tree.getNode(declaration_parent).SourceFile.ExternalModuleIndicator != null) return;
        const bound = self.semantic_binder orelse return;
        const function_symbol = v.tree.getNodeSymbol(declaration) orelse return;
        const function_symbol_data = bound.symbols.items[function_symbol];
        // A merged namespace is emitted once, immediately after the first
        // overload declaration, matching tsgo's declaration ordering.
        if (function_symbol_data.Declarations.items.len != 0 and function_symbol_data.Declarations.items[0] != declaration) return;
        const exports = bound.symbolExports.getPtr(function_symbol) orelse return;
        const Candidate = struct { symbol_index: ast_gen.SymbolIndex, declaration: ast.NodeIndex };
        var candidates = std.ArrayListUnmanaged(Candidate).empty;
        defer candidates.deinit(self.allocator);
        var iterator = exports.iterator();
        while (iterator.next()) |entry| {
            const symbol_index = entry.value_ptr.*;
            const sym = bound.symbols.items[symbol_index];
            if ((sym.Flags & symbol_mod.SymbolFlags.Assignment) == 0 or sym.Declarations.items.len == 0) continue;
            candidates.append(self.allocator, .{ .symbol_index = symbol_index, .declaration = sym.Declarations.items[0] }) catch unreachable;
        }
        if (candidates.items.len == 0) return;
        std.mem.sort(Candidate, candidates.items, {}, struct {
            fn lessThan(_: void, a: Candidate, b: Candidate) bool {
                return a.declaration < b.declaration;
            }
        }.lessThan);
        const f = self.transformer.factory;
        var namespace_statements = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer namespace_statements.deinit(self.allocator);
        var has_any_export = false;
        for (candidates.items) |candidate| {
            const binary = v.tree.getNode(candidate.declaration).BinaryExpression;
            const is_rhs_identifier = v.tree.getNode(binary.Right) == .Identifier;
            if (is_rhs_identifier) {
                has_any_export = true;
                break;
            }
            const assignment_parent = v.tree.getNodeParent(candidate.declaration);
            const statement_parent = if (assignment_parent != 0) v.tree.getNodeParent(assignment_parent) else 0;
            const is_direct_statement = assignment_parent != 0 and v.tree.getNode(assignment_parent) == .ExpressionStatement and statement_parent != 0 and v.tree.getNode(statement_parent) == .SourceFile;
            const rhs_kind = v.tree.getNode(binary.Right);
            const is_func_or_class = rhs_kind == .FunctionExpression or rhs_kind == .ArrowFunction or rhs_kind == .ClassExpression;
            const needs_alias = !is_exported and is_direct_statement and !is_func_or_class;
            if (needs_alias) {
                has_any_export = true;
                break;
            }
        }
        for (candidates.items) |candidate| {
            const sym = bound.symbols.items[candidate.symbol_index];
            const binary = v.tree.getNode(candidate.declaration).BinaryExpression;
            const is_rhs_identifier = v.tree.getNode(binary.Right) == .Identifier;
            if (is_rhs_identifier) {
                const property_name = f.newIdentifier(@import("../ast/ast_utils.zig").getText(v.tree, binary.Right));
                const export_name = f.newIdentifier(sym.Name);
                const specifier = f.newExportSpecifier(false, property_name, export_name);
                const named = f.createNamedExports(f.newNodeList(&.{specifier}));
                namespace_statements.append(self.allocator, f.createExportDeclaration(0, false, named, 0, 0)) catch unreachable;
            } else {
                const assignment_parent = v.tree.getNodeParent(candidate.declaration);
                const statement_parent = if (assignment_parent != 0) v.tree.getNodeParent(assignment_parent) else 0;
                const is_direct_statement = assignment_parent != 0 and v.tree.getNode(assignment_parent) == .ExpressionStatement and statement_parent != 0 and v.tree.getNode(statement_parent) == .SourceFile;
                const rhs_kind = v.tree.getNode(binary.Right);
                const is_func_or_class = rhs_kind == .FunctionExpression or rhs_kind == .ArrowFunction or rhs_kind == .ClassExpression;
                const needs_alias = !is_exported and is_direct_statement and !is_func_or_class;
                const local_name_node = f.newIdentifier(if (needs_alias) "_a" else sym.Name);
                const type_node = self.inferredDeclarationType(v, f, local_name_node, 0, binary.Right);
                const var_decl = f.newVariableDeclaration(local_name_node, 0, type_node, 0);
                const declaration_list = f.newVariableDeclarationList(f.newNodeList(&.{var_decl}), 0);
                const var_modifiers = if (has_any_export and !needs_alias) f.newModifierList(&.{f.newToken(.{ .ExportKeyword = {} })}) else 0;
                const var_stmt = f.newVariableStatement(var_modifiers, declaration_list);
                namespace_statements.append(self.allocator, var_stmt) catch unreachable;
                if (needs_alias) {
                    const specifier = f.newExportSpecifier(false, local_name_node, f.newIdentifier(sym.Name));
                    namespace_statements.append(self.allocator, f.createExportDeclaration(0, false, f.createNamedExports(f.newNodeList(&.{specifier})), 0, 0)) catch unreachable;
                }
            }
        }
        if (namespace_statements.items.len == 0) return;
        const function = v.tree.getNode(declaration).FunctionDeclaration;
        const namespace_name = function.name orelse return;
        const block = v.tree.pushNode(.{ .ModuleBlock = .{ .Flags = 0, .Statements = f.newNodeList(namespace_statements.items) } }) catch unreachable;
        const parent = v.tree.getNodeParent(declaration);
        const inside_namespace = parent != 0 and v.tree.getNode(parent) == .ModuleBlock;
        const modifiers = if (inside_namespace)
            0
        else if (is_exported)
            f.newModifierList(&.{ f.newToken(.{ .ExportKeyword = {} }), f.newToken(.{ .DeclareKeyword = {} }) })
        else
            f.newModifierList(&.{f.newToken(.{ .DeclareKeyword = {} })});
        const namespace = v.tree.pushNode(.{ .ModuleDeclaration = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = 0,
            .AsteriskToken = null,
            .Body = block,
            .Keyword = @intFromEnum(@import("../ast/kind.zig").Kind.NamespaceKeyword),
            .name = namespace_name,
        } }) catch unreachable;
        output.append(self.allocator, namespace) catch unreachable;
    }

    fn transformModuleBlock(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        const block = v.tree.getNode(node).ModuleBlock;
        var statements = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer statements.deinit(self.allocator);
        for (v.tree.getNodeList(block.Statements)) |statement| {
            // Runtime assignment statements are represented by the merged
            // namespace synthesized after their function declaration.
            if (v.tree.getNode(statement) == .ExpressionStatement) continue;
            const transformed = v.visitNode(statement);
            if (transformed == 0) continue;
            if (v.tree.getNode(transformed) == .SyntaxList)
                statements.appendSlice(self.allocator, v.tree.getNodeList(v.tree.getNode(transformed).SyntaxList.Children)) catch unreachable
            else
                statements.append(self.allocator, transformed) catch unreachable;
            self.appendExpandoNamespace(v, statement, &statements);
        }
        return v.tree.pushNode(.{ .ModuleBlock = .{ .Flags = block.Flags, .Statements = self.transformer.factory.newNodeList(statements.items) } }) catch unreachable;
    }

    fn transformMethod(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, method: ast_gen.MethodDeclarationNode) ast.NodeIndex {
        const f = self.transformer.factory;
        const utils = @import("../ast/ast_utils.zig");
        const jsdoc_visibility = jsdocVisibilityModifier(v.tree, node);
        // Private-identifier methods are elided entirely
        if (v.tree.getNode(method.name) == .PrivateIdentifier) return 0;
        // Methods with `private` modifier become property declarations with no type (omitPrivateMethodType)
        if (utils.hasSyntacticModifier(v.tree, node, utils.ModifierFlags.Private) or jsdoc_visibility == .PrivateKeyword) {
            // Build modifier list stripping `async`, `override`, `abstract` (not valid on properties)
            const invalid_on_prop = utils.ModifierFlags.Async | utils.ModifierFlags.Override | utils.ModifierFlags.Abstract;
            var prop_mods = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            defer prop_mods.deinit(self.allocator);
            if (!utils.hasSyntacticModifier(v.tree, node, utils.ModifierFlags.Private)) prop_mods.append(self.allocator, f.newToken(.{ .PrivateKeyword = {} })) catch unreachable;
            if (method.modifiers) |mods_idx| {
                for (v.tree.getNodeList(mods_idx)) |mod_idx| {
                    const mod_tag = std.meta.activeTag(v.tree.getNode(mod_idx));
                    const mod_flag: u32 = switch (mod_tag) {
                        .AsyncKeyword => utils.ModifierFlags.Async,
                        .OverrideKeyword => utils.ModifierFlags.Override,
                        .AbstractKeyword => utils.ModifierFlags.Abstract,
                        else => 0,
                    };
                    if (mod_flag & invalid_on_prop == 0) prop_mods.append(self.allocator, mod_idx) catch unreachable;
                }
            }
            const mods_list = if (prop_mods.items.len > 0) f.newModifierList(prop_mods.items) else null;
            const updated = v.tree.pushNode(.{ .PropertyDeclaration = .{
                .Flags = 0,
                .Symbol = 0,
                .modifiers = mods_list,
                .modifierFlags = utils.ModifierFlags.Private,
                .name = method.name,
                .PostfixToken = null,
                .Type = null,
                .Initializer = null,
            } }) catch unreachable;
            self.setOriginal(updated, node);
            return updated;
        }
        var overloads = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer overloads.deinit(self.allocator);
        for (@import("../ast/ast_utils.zig").getJSDoc(v.tree, node)) |doc_index| {
            const tags = v.tree.getNode(doc_index).JSDoc.Tags orelse continue;
            const tag_items = self.allocator.dupe(ast.NodeIndex, v.tree.getNodeList(tags)) catch unreachable;
            defer self.allocator.free(tag_items);
            var shared_type_parameters = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            defer shared_type_parameters.deinit(self.allocator);
            collectJSDocTypeParameters(v.tree, f, node, &shared_type_parameters, self.allocator);
            var tag_offset: usize = 0;
            while (tag_offset < tag_items.len) : (tag_offset += 1) {
                if (v.tree.getNode(tag_items[tag_offset]) != .JSDocOverloadTag) continue;
                const overload_tag = v.tree.getNode(tag_items[tag_offset]).JSDocOverloadTag;
                var parameters = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer parameters.deinit(self.allocator);
                var return_type: ast.NodeIndex = 0;

                if (overload_tag.TypeExpression != 0) {
                    const sig = v.tree.getNode(overload_tag.TypeExpression).JSDocSignature;
                    if (sig.Parameters != 0) {
                        for (v.tree.getNodeList(sig.Parameters)) |param| {
                            parameters.append(self.allocator, parameterFromJSDocTag(v.tree, f, v.tree.getNode(param).JSDocParameterTag, self.allocator)) catch unreachable;
                        }
                    }
                    if (sig.Type) |sig_type| {
                        if (sig_type != 0) {
                            const ret_tag = v.tree.getNode(sig_type).JSDocReturnTag;
                            if (ret_tag.TypeExpression != null and ret_tag.TypeExpression.? != 0) {
                                return_type = unwrapJSDocTypeExpression(v.tree, f, ret_tag.TypeExpression.?, self.allocator);
                            }
                        }
                    }
                }
                const overload = f.updateMethodDeclaration(node, method, self.classMemberModifiers(v, method.modifiers orelse 0), method.AsteriskToken orelse 0, method.name, method.PostfixToken orelse 0, if (shared_type_parameters.items.len != 0) f.newNodeList(shared_type_parameters.items) else 0, f.newNodeList(parameters.items), if (return_type != 0) return_type else f.newToken(.{ .AnyKeyword = {} }), 0);
                self.transformer.emitContext.setOriginal(overload, node) catch {};
                overloads.append(self.allocator, overload) catch unreachable;
            }
        }
        if (overloads.items.len != 0) return f.newSyntaxList(overloads.items);

        var jsdoc_parameters = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer jsdoc_parameters.deinit(self.allocator);
        collectJSDocTypeParameters(v.tree, f, node, &jsdoc_parameters, self.allocator);
        const type_parameters = if ((method.TypeParameters orelse 0) != 0) v.visitNodes(method.TypeParameters.?) else if (jsdoc_parameters.items.len != 0) f.newNodeList(jsdoc_parameters.items) else 0;
        const method_modifiers = self.methodDeclarationModifiers(v, node, method.modifiers orelse 0, jsdoc_visibility);
        const updated = f.updateMethodDeclaration(node, method, method_modifiers, method.AsteriskToken orelse 0, method.name, method.PostfixToken orelse 0, type_parameters, v.visitNodes(method.Parameters), method.Type orelse jsdocReturnType(v.tree, f, node, self.allocator) orelse inferFunctionReturnType(v.tree, f, method.Body orelse 0, v), 0);
        self.setOriginal(updated, node);
        return updated;
    }

    fn reportDeclarationError(self: *DeclarationTransformer, code: u32, message: []const u8) void {
        self.has_errors = true;
        const program = self.semantic_program orelse return;
        const file = self.semantic_file orelse return;
        program.diagnostics.append(program.allocator, .{ .file = file, .code = code, .message = program.allocator.dupe(u8, message) catch unreachable }) catch unreachable;
    }

    fn methodDeclarationModifiers(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, modifiers: ast.NodeIndex, visibility: @import("../ast/kind.zig").Kind) ast.NodeIndex {
        const visited = self.classMemberModifiers(v, modifiers);
        const utils = @import("../ast/ast_utils.zig");
        if (visibility == .Unknown or
            (visibility == .ProtectedKeyword and utils.hasSyntacticModifier(v.tree, node, utils.ModifierFlags.Protected)) or
            (visibility == .PublicKeyword and utils.hasSyntacticModifier(v.tree, node, utils.ModifierFlags.Public))) return visited;
        var items = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer items.deinit(self.allocator);
        items.append(self.allocator, switch (visibility) {
            .ProtectedKeyword => self.transformer.factory.newToken(.{ .ProtectedKeyword = {} }),
            .PublicKeyword => self.transformer.factory.newToken(.{ .PublicKeyword = {} }),
            else => return visited,
        }) catch unreachable;
        if (visited != 0) items.appendSlice(self.allocator, v.tree.getNodeList(visited)) catch unreachable;
        return self.transformer.factory.newModifierList(items.items);
    }

    fn transformFunction(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, function: ast_gen.FunctionDeclarationNode) ast.NodeIndex {
        const f = self.transformer.factory;
        if (function.Body != null) if (self.semantic_binder) |bound| if (v.tree.getNodeSymbol(node)) |symbol_index| {
            const symbol = bound.symbols.items[symbol_index];
            for (symbol.Declarations.items) |declaration| {
                if (declaration == node or v.tree.getNode(declaration) != .FunctionDeclaration) continue;
                if (v.tree.getNode(declaration).FunctionDeclaration.Body == null) return 0;
            }
        };
        if (applicableJSDocFunctionType(v.tree, f, node, self.allocator)) |function_type_index| {
            const function_type = v.tree.getNode(function_type_index).FunctionType;
            return f.updateFunctionDeclaration(node, function, self.declarationModifiers(v, node, function.modifiers orelse 0), function.AsteriskToken orelse 0, function.name orelse 0, function_type.TypeParameters orelse 0, function_type.Parameters, function_type.Type orelse f.newToken(.{ .VoidKeyword = {} }), 0);
        }

        var parameters = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer parameters.deinit(self.allocator);
        const original_parameters = v.tree.getNodeList(function.Parameters);
        for (original_parameters, 0..) |parameter_index, index| {
            const parameter = v.tree.getNode(parameter_index).Parameter;
            const jsdoc_type = inlineJSDocType(v.tree, f, parameter_index, self.allocator) orelse jsdocParameterType(v.tree, f, node, parameter.name, index, self.allocator);
            var type_node = parameter.Type orelse jsdoc_type orelse inferredType(v, f, 0, parameter.Initializer orelse 0);

            var question = parameter.QuestionToken orelse 0;
            if (parameter.Initializer != null) {
                var all_subsequent_optional = true;
                for (original_parameters[index + 1 ..]) |sub_idx| {
                    const sub = v.tree.getNode(sub_idx).Parameter;
                    if (sub.Initializer == null and sub.QuestionToken == null and sub.DotDotDotToken == null) {
                        all_subsequent_optional = false;
                        break;
                    }
                }
                if (all_subsequent_optional) {
                    if (question == 0) {
                        question = f.tree.pushNode(.{ .QuestionToken = {} }) catch unreachable;
                    }
                } else {
                    if (type_node != 0 and !typeContainsUndefined(v.tree, type_node)) {
                        type_node = unwrapParenthesizedTypeNode(v.tree, type_node);
                        const undefined_kw = f.tree.pushNode(.{ .UndefinedKeyword = {} }) catch unreachable;
                        const types_arr = [_]ast.NodeIndex{ type_node, undefined_kw };
                        const types_list = f.tree.pushNodeList(&types_arr) catch unreachable;
                        type_node = f.tree.pushNode(.{ .UnionType = .{
                            .Flags = 0,
                            .Types = types_list,
                        } }) catch unreachable;
                    }
                }
            }

            const updated = f.updateParameterDeclaration(parameter_index, parameter, v.visitModifiers(parameter.modifiers orelse 0), parameter.DotDotDotToken orelse 0, v.visitNode(parameter.name), question, type_node, 0);
            if (updated != parameter_index) self.transformer.emitContext.setOriginal(updated, parameter_index) catch {};
            parameters.append(self.allocator, updated) catch unreachable;
        }

        var type_parameters = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer type_parameters.deinit(self.allocator);
        collectJSDocTypeParameters(v.tree, f, node, &type_parameters, self.allocator);
        const type_parameter_list = if ((function.TypeParameters orelse 0) != 0) v.visitNodes(function.TypeParameters.?) else if (type_parameters.items.len != 0) f.newNodeList(type_parameters.items) else 0;
        const return_type = if (function.Type) |explicit| v.visitNode(explicit) else jsdocReturnType(v.tree, f, node, self.allocator) orelse inferFunctionReturnType(v.tree, f, function.Body orelse 0, v);
        return f.updateFunctionDeclaration(node, function, self.declarationFunctionModifiers(v, node, function.modifiers orelse 0), function.AsteriskToken orelse 0, function.name orelse 0, type_parameter_list, f.newNodeList(parameters.items), return_type, 0);
    }

    fn declarationFunctionModifiers(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, modifiers: ast.NodeIndex) ast.NodeIndex {
        const visited = self.declarationModifiers(v, node, modifiers);
        if (visited == 0) return 0;
        var kept = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer kept.deinit(self.allocator);
        for (v.tree.getNodeList(visited)) |modifier| if (v.tree.getNodeKind(modifier) != .AsyncKeyword) kept.append(self.allocator, modifier) catch unreachable;
        return if (kept.items.len == 0) 0 else self.transformer.factory.newModifierList(kept.items);
    }
    fn isModuleResolvable(self: *DeclarationTransformer, file_id: u32, module_specifier: ast.NodeIndex, target_tree: *ast.Ast) bool {
        const program = self.semantic_program orelse return true;
        if (target_tree.getNode(module_specifier) != .StringLiteral) return true;
        const module_name = @import("../ast/ast_utils.zig").getText(target_tree, module_specifier);
        const unit = program.getUnit(file_id);
        for (unit.dependencies.items) |dep| {
            if (std.mem.eql(u8, dep.specifier, module_name)) {
                if (dep.resolved) |res_id| {
                    const target_unit = program.getUnit(res_id);
                    if (!target_unit.is_default_library and target_unit.package_id == null and !std.mem.containsAtLeast(u8, target_unit.path, 1, "node_modules")) {
                        return false;
                    }
                    return true;
                }
                return false;
            }
        }
        return false;
    }

    fn inferredDeclarationType(self: *DeclarationTransformer, v: *visitor.NodeVisitor, factory: anytype, name: ast.NodeIndex, explicit_type: ast.NodeIndex, initializer: ast.NodeIndex) ast.NodeIndex {
        if (explicit_type != 0) return explicit_type;
        const tree = v.tree;
        if (self.expandoObjectType(v, name)) |expando_type| return expando_type;
        if (tree.getNode(initializer) == .ClassExpression) return anonymousClassConstructorType(tree, factory);
        var has_satisfies = false;
        var curr = initializer;
        while (curr != 0) {
            switch (tree.getNode(curr)) {
                .SatisfiesExpression => {
                    has_satisfies = true;
                    break;
                },
                .ParenthesizedExpression => |expr| curr = expr.Expression,
                .AsExpression => |expr| curr = expr.Expression,
                else => break,
            }
        }
        if (constAssertionOperand(tree, initializer)) |operand| {
            return self.structuralTypeFromExpression(v, operand, true, has_satisfies);
        }
        if (tree.getNode(initializer) == .ObjectLiteralExpression or tree.getNode(initializer) == .ArrayLiteralExpression) return self.structuralTypeFromExpression(v, initializer, false, has_satisfies);
        if (tree.getNode(initializer) == .ArrowFunction) {
            const arrow = tree.getNode(initializer).ArrowFunction;
            const return_type = arrow.Type orelse if (constAssertionOperand(tree, arrow.Body orelse 0)) |operand| blk: {
                var body_has_satisfies = false;
                var body_curr = arrow.Body orelse 0;
                while (body_curr != 0) {
                    switch (tree.getNode(body_curr)) {
                        .SatisfiesExpression => {
                            body_has_satisfies = true;
                            break;
                        },
                        .ParenthesizedExpression => |expr| body_curr = expr.Expression,
                        .AsExpression => |expr| body_curr = expr.Expression,
                        else => break,
                    }
                }
                break :blk self.structuralTypeFromExpression(v, operand, true, body_has_satisfies);
            } else inferArrowReturnType(tree, factory, arrow.Body orelse 0, v);
            return tree.pushNode(.{ .FunctionType = .{
                .Flags = 0,
                .modifiers = null,
                .modifierFlags = 0,
                .Symbol = 0,
                .TypeParameters = arrow.TypeParameters,
                .Parameters = declarationFunctionParameters(tree, factory, arrow.Parameters),
                .Type = return_type,
                .FullSignature = null,
            } }) catch unreachable;
        }
        if (tree.getNode(initializer) == .CallExpression) {
            const call = tree.getNode(initializer).CallExpression;
            const arguments = tree.getNodeList(call.Arguments);
            if (tree.getNode(call.Expression) == .PropertyAccessExpression) {
                const prop = tree.getNode(call.Expression).PropertyAccessExpression;
                const prop_name = @import("../ast/ast_utils.zig").getText(tree, prop.name);
                if (std.mem.eql(u8, prop_name, "bind")) {
                    return tree.pushNode(.{ .TypeQuery = .{
                        .Flags = 0,
                        .TypeArguments = null,
                        .ExprName = prop.Expression,
                    } }) catch unreachable;
                }
                if ((call.TypeArguments orelse 0) != 0 and std.mem.eql(u8, prop_name, "create")) {
                    return tree.pushNode(.{ .TypeReference = .{
                        .Flags = 0,
                        .TypeArguments = v.visitNodes(call.TypeArguments.?),
                        .TypeName = v.visitNode(prop.Expression),
                    } }) catch unreachable;
                }
            }
            if (arguments.len != 0) {
                if (findConstGenericParameter(tree, call.Expression)) |param| {
                    const has_mutable = if (param.Constraint) |constraint| hasMutableConstraint(tree, constraint) else false;
                    return self.structuralTypeFromExpression(v, arguments[0], true, has_mutable);
                }
                if (isIdentityGenericCallee(tree, call.Expression)) return self.structuralTypeFromExpression(v, arguments[0], false, false);
            }
            if (tree.getNode(call.Expression) == .Identifier) if (self.semantic_program) |program| if (self.semantic_file) |file| {
                const callee_name = @import("../ast/ast_utils.zig").getText(tree, call.Expression);
                var target_decl: ast.NodeIndex = 0;
                var target_tree = tree;
                var target_file = file;

                if (program.resolveAlias(file, callee_name)) |symbol| {
                    target_decl = symbol.declaration;
                    target_tree = program.getUnit(symbol.declaration_file).tree();
                    target_file = symbol.declaration_file;
                } else if (self.semantic_binder) |bound| {
                    target_decl = self.findDeclarationInFile(tree, bound, callee_name);
                }

                if (target_decl != 0) {
                    if (target_tree.getNode(target_decl) == .VariableDeclaration) {
                        const vd = target_tree.getNode(target_decl).VariableDeclaration;
                        var var_type_node = vd.Type orelse 0;
                        if (var_type_node == 0) {
                            if (vd.Initializer) |init_idx| {
                                var curr_init = init_idx;
                                while (curr_init != 0) {
                                    switch (target_tree.getNode(curr_init)) {
                                        .ParenthesizedExpression => |expr| curr_init = expr.Expression,
                                        .AsExpression => |expr| {
                                            var_type_node = expr.Type;
                                            break;
                                        },
                                        else => break,
                                    }
                                }
                            }
                        }
                        if (var_type_node != 0) {
                            const t_node = target_tree.getNode(var_type_node);
                            if (t_node == .TypeReference) {
                                const ref_name = @import("../ast/ast_utils.zig").getText(target_tree, t_node.TypeReference.TypeName);
                                if (program.resolveAlias(target_file, ref_name)) |alias_sym| {
                                    target_decl = alias_sym.declaration;
                                    target_tree = program.getUnit(alias_sym.declaration_file).tree();
                                    target_file = alias_sym.declaration_file;
                                } else if (self.semantic_binder) |bound| {
                                    target_decl = self.findDeclarationInFile(target_tree, bound, ref_name);
                                }
                            }
                        }
                    }

                    if (target_tree.getNode(target_decl) == .FunctionDeclaration) {
                        const function = target_tree.getNode(target_decl).FunctionDeclaration;
                        if (function.Type) |explicit| {
                            return self.copyForeignTypeNode(target_tree, explicit, &.{});
                        }
                        if (firstReturnExpression(target_tree, function.Body orelse 0)) |return_expression| return self.foreignStructuralType(v, target_file, target_tree, return_expression, false, false);
                    } else if (target_tree.getNode(target_decl) == .TypeAliasDeclaration) {
                        const alias = target_tree.getNode(target_decl).TypeAliasDeclaration;
                        if (target_tree.getNode(alias.Type) == .FunctionType) {
                            const func_type = target_tree.getNode(alias.Type).FunctionType;
                            const return_type = func_type.Type;
                            const params = target_tree.getNodeList(func_type.Parameters);
                            if (params.len > 0 and arguments.len > 0) {
                                const first_param = target_tree.getNode(params[0]).Parameter;
                                const first_param_type = first_param.Type orelse 0;

                                var arg_decl_node = arguments[0];
                                var arg_decl_tree = tree;
                                if (tree.getNode(arg_decl_node) == .Identifier) {
                                    const arg_name = @import("../ast/ast_utils.zig").getText(tree, arg_decl_node);
                                    if (program.resolveAlias(file, arg_name)) |arg_sym| {
                                        arg_decl_node = arg_sym.declaration;
                                        arg_decl_tree = program.getUnit(arg_sym.declaration_file).tree();
                                    } else if (self.semantic_binder) |bound| {
                                        arg_decl_node = self.findDeclarationInFile(tree, bound, arg_name);
                                    }
                                }

                                var substitutions = std.ArrayListUnmanaged(TypeSubstitution).empty;
                                defer substitutions.deinit(self.allocator);

                                self.inferSubstitutions(target_tree, first_param_type, arg_decl_tree, arg_decl_node, &substitutions);

                                const result_node = self.copyForeignTypeNode(target_tree, return_type orelse 0, substitutions.items);
                                if (v.tree.getNode(result_node) == .FunctionType) {
                                    var ft = v.tree.getNode(result_node).FunctionType;
                                    if (arg_decl_tree.getNode(arg_decl_node) == .FunctionDeclaration) {
                                        const fd = arg_decl_tree.getNode(arg_decl_node).FunctionDeclaration;
                                        if (fd.TypeParameters) |tp_idx| {
                                            ft.TypeParameters = self.copyForeignList(arg_decl_tree, tp_idx, &.{});
                                            v.tree.nodes.set(result_node, .{ .FunctionType = ft });
                                        }
                                    }
                                }
                                return result_node;
                            }
                        }
                    }
                }
            };
        }
        if (isSymbolCall(tree, initializer)) {
            const symbol_keyword = factory.newToken(.{ .SymbolKeyword = {} });
            return tree.pushNode(.{ .TypeOperator = .{
                .Flags = 0,
                .Operator = @intFromEnum(@import("../ast/kind.zig").Kind.UniqueKeyword),
                .Type = symbol_keyword,
            } }) catch unreachable;
        }
        if (self.semantic_program) |program| if (self.semantic_file) |file| {
            if (tree.getNode(initializer) == .Identifier) {
                const init_name = @import("../ast/ast_utils.zig").getText(tree, initializer);
                if (program.resolveAlias(file, init_name)) |symbol| {
                    const target_tree = program.getUnit(symbol.declaration_file).tree();
                    if (symbol.declaration != 0) {
                        const target_node = target_tree.getNode(symbol.declaration);
                        if (target_node == .NamespaceImport or target_node == .ExternalModuleReference or target_node == .ImportEqualsDeclaration) {
                            var resolvable = true;
                            if (target_node == .NamespaceImport) {
                                const parent = target_tree.getNodeParent(symbol.declaration);
                                if (parent != 0 and target_tree.getNode(parent) == .ImportClause) {
                                    const decl = target_tree.getNodeParent(parent);
                                    if (decl != 0 and target_tree.getNode(decl) == .ImportDeclaration) {
                                        const module_specifier = target_tree.getNode(decl).ImportDeclaration.ModuleSpecifier;
                                        resolvable = self.isModuleResolvable(symbol.declaration_file, module_specifier, target_tree);
                                    }
                                }
                            } else if (target_node == .ExternalModuleReference) {
                                const expr = target_tree.getNode(symbol.declaration).ExternalModuleReference.Expression;
                                resolvable = self.isModuleResolvable(symbol.declaration_file, expr, target_tree);
                            }
                            if (resolvable) {
                                return tree.pushNode(.{ .TypeQuery = .{
                                    .Flags = 0,
                                    .TypeArguments = null,
                                    .ExprName = initializer,
                                } }) catch unreachable;
                            }
                        }
                    }
                } else if (self.semantic_binder) |bound| {
                    const target_decl = self.findDeclarationInFile(tree, bound, init_name);
                    if (target_decl != 0) {
                        const target_node = tree.getNode(target_decl);
                        if (target_node == .NamespaceImport or target_node == .ExternalModuleReference or target_node == .ImportEqualsDeclaration) {
                            var resolvable = true;
                            if (target_node == .NamespaceImport) {
                                const parent = tree.getNodeParent(target_decl);
                                if (parent != 0 and tree.getNode(parent) == .ImportClause) {
                                    const decl = tree.getNodeParent(parent);
                                    if (decl != 0 and tree.getNode(decl) == .ImportDeclaration) {
                                        const module_specifier = tree.getNode(decl).ImportDeclaration.ModuleSpecifier;
                                        resolvable = self.isModuleResolvable(file, module_specifier, tree);
                                    }
                                }
                            } else if (target_node == .ExternalModuleReference) {
                                const expr = tree.getNode(target_decl).ExternalModuleReference.Expression;
                                resolvable = self.isModuleResolvable(file, expr, tree);
                            }
                            if (resolvable) {
                                return tree.pushNode(.{ .TypeQuery = .{
                                    .Flags = 0,
                                    .TypeArguments = null,
                                    .ExprName = initializer,
                                } }) catch unreachable;
                            }
                        }
                    }
                }
            }

            if (tree.getNode(initializer) == .PropertyAccessExpression) {
                const pae = tree.getNode(initializer).PropertyAccessExpression;
                if (tree.getNode(pae.Expression) == .Identifier) {
                    const obj_name = @import("../ast/ast_utils.zig").getText(tree, pae.Expression);
                    var target_decl: ast.NodeIndex = 0;
                    var target_tree = tree;
                    if (program.resolveAlias(file, obj_name)) |symbol| {
                        target_decl = symbol.declaration;
                        target_tree = program.getUnit(symbol.declaration_file).tree();
                    } else if (self.semantic_binder) |bound| {
                        target_decl = self.findDeclarationInFile(tree, bound, obj_name);
                    }
                    if (target_decl != 0 and target_tree.getNode(target_decl) == .VariableDeclaration) {
                        const vd = target_tree.getNode(target_decl).VariableDeclaration;
                        if (vd.Type) |t| {
                            if (target_tree.getNode(t) == .TypeLiteral) {
                                const members = target_tree.getNodeList(target_tree.getNode(t).TypeLiteral.Members);
                                const prop_name = @import("../ast/ast_utils.zig").getText(tree, pae.name);
                                for (members) |member| {
                                    if (target_tree.getNode(member) == .PropertySignature) {
                                        const ps = target_tree.getNode(member).PropertySignature;
                                        if (std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(target_tree, ps.name), prop_name)) {
                                            if (ps.Type) |prop_type| {
                                                return self.copyForeignTypeNode(target_tree, prop_type, &.{});
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

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
        return inferredType(v, factory, explicit_type, initializer);
    }

    fn expandoObjectType(self: *DeclarationTransformer, v: *visitor.NodeVisitor, name: ast.NodeIndex) ?ast.NodeIndex {
        const bound = self.semantic_binder orelse return null;
        const declaration = v.tree.getNodeParent(name);
        if (declaration == 0 or v.tree.getNode(declaration) != .VariableDeclaration) return null;
        var symbol_index = v.tree.getNodeSymbol(declaration) orelse blk: {
            const source = sourceFileAncestor(v.tree, declaration) orelse return null;
            const locals = bound.nodeLocals.getPtr(source) orelse return null;
            break :blk locals.get(@import("../ast/ast_utils.zig").getText(v.tree, name)) orelse return null;
        };
        const variable = v.tree.getNode(declaration).VariableDeclaration;
        if (variable.Initializer) |initializer| if (v.tree.getNodeSymbol(initializer)) |initializer_symbol| {
            if (bound.symbolExports.getPtr(initializer_symbol) != null) symbol_index = initializer_symbol;
        };
        const exports = bound.symbolExports.getPtr(symbol_index) orelse return null;
        if (exports.count() == 0) return null;
        const f = self.transformer.factory;
        var members = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer members.deinit(self.allocator);
        var iterator = exports.iterator();
        while (iterator.next()) |entry| {
            const sym = bound.symbols.items[entry.value_ptr.*];
            if ((sym.Flags & symbol_mod.SymbolFlags.Assignment) == 0 or sym.Declarations.items.len == 0) continue;
            const property_name = f.newIdentifier(sym.Name);
            const property_type = assignmentSymbolTypeNode(v.tree, f, sym.Declarations.items, false);
            members.append(self.allocator, v.tree.pushNode(.{ .PropertySignature = .{
                .Flags = 0,
                .Symbol = 0,
                .modifiers = null,
                .modifierFlags = 0,
                .name = property_name,
                .PostfixToken = null,
                .Type = property_type,
                .Initializer = null,
            } }) catch unreachable) catch unreachable;
        }
        if (members.items.len == 0) return null;
        return v.tree.pushNode(.{ .TypeLiteral = .{ .Flags = 0, .Symbol = 0, .Members = f.newNodeList(members.items) } }) catch unreachable;
    }

    fn structuralTypeFromExpression(self: *DeclarationTransformer, v: *visitor.NodeVisitor, expression: ast.NodeIndex, readonly: bool, in_satisfies: bool) ast.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        return switch (tree.getNode(expression)) {
            .ObjectLiteralExpression => |object| blk: {
                var members = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer members.deinit(self.allocator);
                const object_properties = self.allocator.dupe(ast.NodeIndex, tree.getNodeList(object.Properties)) catch unreachable;
                defer self.allocator.free(object_properties);
                for (object_properties) |property_index| switch (tree.getNode(property_index)) {
                    .PropertyAssignment => |property| {
                        const modifiers = if (readonly) f.newModifierList(&.{f.newToken(.{ .ReadonlyKeyword = {} })}) else 0;
                        const property_type = self.structuralTypeFromExpression(v, property.Initializer, readonly, in_satisfies);
                        const property_name = normalizedPropertyName(tree, f, property.name);
                        members.append(self.allocator, tree.pushNode(.{ .PropertySignature = .{
                            .Flags = 0,
                            .Symbol = 0,
                            .modifiers = if (modifiers == 0) null else modifiers,
                            .modifierFlags = if (readonly) @import("../ast/ast_utils.zig").ModifierFlags.Readonly else 0,
                            .name = property_name,
                            .PostfixToken = null,
                            .Type = property_type,
                            .Initializer = null,
                        } }) catch unreachable) catch unreachable;
                    },
                    .ShorthandPropertyAssignment => |property| {
                        const modifiers = if (readonly) f.newModifierList(&.{f.newToken(.{ .ReadonlyKeyword = {} })}) else 0;
                        const property_type = tree.pushNode(.{ .TypeQuery = .{
                            .Flags = 0,
                            .TypeArguments = null,
                            .ExprName = property.name,
                        } }) catch unreachable;
                        members.append(self.allocator, tree.pushNode(.{ .PropertySignature = .{
                            .Flags = 0,
                            .Symbol = 0,
                            .modifiers = if (modifiers == 0) null else modifiers,
                            .modifierFlags = if (readonly) @import("../ast/ast_utils.zig").ModifierFlags.Readonly else 0,
                            .name = property.name,
                            .PostfixToken = null,
                            .Type = property_type,
                            .Initializer = null,
                        } }) catch unreachable) catch unreachable;
                    },
                    .MethodDeclaration => |method| {
                        const return_type = if (method.Type) |explicit| v.visitNode(explicit) else inferFunctionReturnType(tree, f, method.Body orelse 0, v);
                        if (tree.getNode(return_type) == .TupleType) self.transformer.emitContext.addEmitFlags(return_type, @import("../printer/emitflags.zig").EmitFlags.SingleLine) catch {};
                        if (!readonly) {
                            members.append(self.allocator, tree.pushNode(.{ .MethodSignature = .{
                                .Flags = 0,
                                .Symbol = 0,
                                .modifiers = null,
                                .modifierFlags = 0,
                                .name = method.name,
                                .PostfixToken = method.PostfixToken,
                                .TypeParameters = method.TypeParameters,
                                .Parameters = v.visitNodes(method.Parameters),
                                .Type = return_type,
                                .FullSignature = null,
                            } }) catch unreachable) catch unreachable;
                            continue;
                        }
                        const modifiers = f.newModifierList(&.{f.newToken(.{ .ReadonlyKeyword = {} })});
                        const function_type = tree.pushNode(.{ .FunctionType = .{
                            .Flags = 0,
                            .modifiers = null,
                            .modifierFlags = 0,
                            .Symbol = 0,
                            .TypeParameters = method.TypeParameters,
                            .Parameters = v.visitNodes(method.Parameters),
                            .Type = return_type,
                            .FullSignature = null,
                        } }) catch unreachable;
                        members.append(self.allocator, tree.pushNode(.{ .PropertySignature = .{
                            .Flags = 0,
                            .Symbol = 0,
                            .modifiers = modifiers,
                            .modifierFlags = @import("../ast/ast_utils.zig").ModifierFlags.Readonly,
                            .name = method.name,
                            .PostfixToken = null,
                            .Type = function_type,
                            .Initializer = null,
                        } }) catch unreachable) catch unreachable;
                    },
                    .SpreadAssignment => |spread| {
                        if (tree.getNode(spread.Expression) != .Identifier) continue;
                        const program = self.semantic_program orelse continue;
                        const file = self.semantic_file orelse continue;
                        const name = @import("../ast/ast_utils.zig").getText(tree, spread.Expression);
                        const symbol = program.resolveAlias(file, name) orelse continue;
                        const foreign_tree = program.getUnit(symbol.declaration_file).tree();
                        if (foreign_tree.getNode(symbol.declaration) != .VariableDeclaration) continue;
                        const declaration = foreign_tree.getNode(symbol.declaration).VariableDeclaration;
                        const initializer = declaration.Initializer orelse continue;
                        const spread_type = self.foreignStructuralType(v, symbol.declaration_file, foreign_tree, initializer, readonly, in_satisfies);
                        if (tree.getNode(spread_type) != .TypeLiteral) continue;
                        members.appendSlice(self.allocator, tree.getNodeList(tree.getNode(spread_type).TypeLiteral.Members)) catch unreachable;
                    },
                    else => {},
                };
                break :blk tree.pushNode(.{ .TypeLiteral = .{ .Flags = 0, .Symbol = 0, .Members = f.newNodeList(members.items) } }) catch unreachable;
            },
            .ArrayLiteralExpression => |array| blk: {
                var elements = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer elements.deinit(self.allocator);
                const source_elements = self.allocator.dupe(ast.NodeIndex, tree.getNodeList(array.Elements)) catch unreachable;
                defer self.allocator.free(source_elements);
                for (source_elements) |element| {
                    elements.append(self.allocator, self.structuralTypeFromExpression(v, element, readonly, in_satisfies)) catch unreachable;
                }
                if (!readonly) {
                    const element_type = if (elements.items.len == 0) f.newToken(.{ .AnyKeyword = {} }) else elements.items[0];
                    break :blk tree.pushNode(.{ .ArrayType = .{ .Flags = 0, .ElementType = element_type } }) catch unreachable;
                }
                const tuple = tree.pushNode(.{ .TupleType = .{ .Flags = @import("../ast/ast_utils.zig").NodeFlags.Synthesized, .Elements = f.newNodeList(elements.items) } }) catch unreachable;
                if (in_satisfies) {
                    break :blk tuple;
                }
                break :blk tree.pushNode(.{ .TypeOperator = .{ .Flags = 0, .Operator = @intFromEnum(@import("../ast/kind.zig").Kind.ReadonlyKeyword), .Type = tuple } }) catch unreachable;
            },
            .PropertyAccessExpression => tree.pushNode(.{ .TypeReference = .{ .Flags = 0, .TypeArguments = null, .TypeName = expression } }) catch unreachable,
            .Identifier => blk: {
                if (findVariableInitializer(tree, expression)) |initializer| break :blk self.structuralTypeFromExpression(v, initializer, readonly, in_satisfies);
                break :blk inferredType(v, f, 0, expression);
            },
            .TemplateExpression => |template| blk: {
                var spans = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer spans.deinit(self.allocator);
                for (tree.getNodeList(template.TemplateSpans)) |span_index| {
                    const span = tree.getNode(span_index).TemplateSpan;
                    var span_type = inferredType(v, f, 0, span.Expression);
                    if (tree.getNode(span.Expression) == .Identifier) {
                        const resolved = findParameterTypeInAncestors(tree, f, span.Expression, @import("../ast/ast_utils.zig").getText(tree, span.Expression));
                        if (resolved != 0) span_type = resolved;
                    }
                    spans.append(self.allocator, tree.pushNode(.{ .TemplateLiteralTypeSpan = .{ .Flags = 0, .Type = span_type, .Literal = span.Literal } }) catch unreachable) catch unreachable;
                }
                break :blk tree.pushNode(.{ .TemplateLiteralType = .{ .Flags = 0, .Head = template.Head, .TemplateSpans = f.newNodeList(spans.items) } }) catch unreachable;
            },
            .StringLiteral, .NoSubstitutionTemplateLiteral, .NumericLiteral, .BigIntLiteral, .TrueKeyword, .FalseKeyword => if (readonly) tree.pushNode(.{ .LiteralType = .{ .Flags = 0, .Literal = expression } }) catch unreachable else inferredType(v, f, 0, expression),
            .ArrowFunction => |arrow| tree.pushNode(.{ .FunctionType = .{
                .Flags = 0,
                .modifiers = null,
                .modifierFlags = 0,
                .Symbol = 0,
                .TypeParameters = arrow.TypeParameters,
                .Parameters = declarationFunctionParameters(tree, f, arrow.Parameters),
                .Type = arrow.Type orelse inferArrowReturnType(tree, f, arrow.Body orelse 0, v),
                .FullSignature = null,
            } }) catch unreachable,
            .AsExpression => |node| self.structuralTypeFromExpression(v, node.Expression, readonly, in_satisfies),
            .SatisfiesExpression => |node| self.structuralTypeFromExpression(v, node.Expression, readonly, true),
            .ParenthesizedExpression => |node| self.structuralTypeFromExpression(v, node.Expression, readonly, in_satisfies),
            else => inferredType(v, f, 0, expression),
        };
    }

    /// Build declaration nodes in the destination AST from an expression owned
    /// by another SourceUnit. NodeIndex values are deliberately never reused
    /// across files; this is the small semantic-node-builder slice needed by
    /// object spread inference and is extended as more expression kinds become
    /// publicly observable.
    fn foreignStructuralType(self: *DeclarationTransformer, v: *visitor.NodeVisitor, source_file: program_mod.FileId, source_tree: *ast.Ast, expression: ast.NodeIndex, readonly: bool, in_satisfies: bool) ast.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        return switch (source_tree.getNode(expression)) {
            .AsExpression => |node| self.foreignStructuralType(v, source_file, source_tree, node.Expression, readonly, in_satisfies),
            .SatisfiesExpression => |node| self.foreignStructuralType(v, source_file, source_tree, node.Expression, readonly, true),
            .ParenthesizedExpression => |node| self.foreignStructuralType(v, source_file, source_tree, node.Expression, readonly, in_satisfies),
            .ObjectLiteralExpression => |object| blk: {
                var members = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer members.deinit(self.allocator);
                for (source_tree.getNodeList(object.Properties)) |property_index| switch (source_tree.getNode(property_index)) {
                    .PropertyAssignment => |property| {
                        const modifiers = if (readonly) f.newModifierList(&.{f.newToken(.{ .ReadonlyKeyword = {} })}) else 0;
                        const property_type = self.foreignStructuralType(v, source_file, source_tree, property.Initializer, readonly, in_satisfies);
                        const property_name = cloneForeignPropertyName(source_tree, f, property.name);
                        members.append(self.allocator, tree.pushNode(.{ .PropertySignature = .{
                            .Flags = 0,
                            .Symbol = 0,
                            .modifiers = if (modifiers == 0) null else modifiers,
                            .modifierFlags = if (readonly) @import("../ast/ast_utils.zig").ModifierFlags.Readonly else 0,
                            .name = property_name,
                            .PostfixToken = null,
                            .Type = property_type,
                            .Initializer = null,
                        } }) catch unreachable) catch unreachable;
                    },
                    .SpreadAssignment => |spread| {
                        if (source_tree.getNode(spread.Expression) != .Identifier) continue;
                        const program = self.semantic_program orelse continue;
                        const name = @import("../ast/ast_utils.zig").getText(source_tree, spread.Expression);
                        const symbol = program.resolveAlias(source_file, name) orelse continue;
                        const next_tree = program.getUnit(symbol.declaration_file).tree();
                        if (next_tree.getNode(symbol.declaration) != .VariableDeclaration) continue;
                        const initializer = next_tree.getNode(symbol.declaration).VariableDeclaration.Initializer orelse continue;
                        const spread_type = self.foreignStructuralType(v, symbol.declaration_file, next_tree, initializer, readonly, in_satisfies);
                        if (tree.getNode(spread_type) == .TypeLiteral) members.appendSlice(self.allocator, tree.getNodeList(tree.getNode(spread_type).TypeLiteral.Members)) catch unreachable;
                    },
                    else => {},
                };
                break :blk tree.pushNode(.{ .TypeLiteral = .{ .Flags = 0, .Symbol = 0, .Members = f.newNodeList(members.items) } }) catch unreachable;
            },
            .PropertyAccessExpression => |access| blk: {
                if (source_tree.getNode(access.Expression) == .Identifier) {
                    const program = self.semantic_program orelse break :blk f.newToken(.{ .AnyKeyword = {} });
                    const base_name = @import("../ast/ast_utils.zig").getText(source_tree, access.Expression);
                    if (program.resolveAlias(source_file, base_name)) |symbol| {
                        const unit = program.getUnit(source_file);
                        var module_specifier: ?[]const u8 = null;
                        for (unit.dependencies.items) |dependency| {
                            if (dependency.resolved == symbol.file) {
                                module_specifier = dependency.specifier;
                                break;
                            }
                        }
                        if (module_specifier) |specifier| {
                            const literal = f.newStringLiteral(specifier, false);
                            const argument = tree.pushNode(.{ .LiteralType = .{ .Flags = 0, .Literal = literal } }) catch unreachable;
                            const qualifier = tree.pushNode(.{ .QualifiedName = .{
                                .Flags = 0,
                                .Left = f.newIdentifier(base_name),
                                .Right = f.newIdentifier(@import("../ast/ast_utils.zig").getText(source_tree, access.name)),
                            } }) catch unreachable;
                            break :blk tree.pushNode(.{ .ImportType = .{
                                .Flags = 0,
                                .TypeArguments = null,
                                .IsTypeOf = 0,
                                .Argument = argument,
                                .Attributes = null,
                                .Qualifier = qualifier,
                            } }) catch unreachable;
                        }
                    }
                }
                break :blk f.newToken(.{ .AnyKeyword = {} });
            },
            .NewExpression => |new_expression| blk: {
                if (source_tree.getNode(new_expression.Expression) == .Identifier) {
                    const program = self.semantic_program orelse break :blk f.newToken(.{ .AnyKeyword = {} });
                    const local_name = @import("../ast/ast_utils.zig").getText(source_tree, new_expression.Expression);
                    if (program.resolveAlias(source_file, local_name)) |symbol| {
                        const unit = program.getUnit(source_file);
                        for (unit.dependencies.items) |dependency| if (dependency.resolved == symbol.file) {
                            const argument = tree.pushNode(.{ .LiteralType = .{ .Flags = 0, .Literal = f.newStringLiteral(dependency.specifier, false) } }) catch unreachable;
                            break :blk tree.pushNode(.{ .ImportType = .{
                                .Flags = 0,
                                .TypeArguments = null,
                                .IsTypeOf = 0,
                                .Argument = argument,
                                .Attributes = null,
                                .Qualifier = f.newIdentifier(local_name),
                            } }) catch unreachable;
                        };
                    }
                }
                break :blk f.newToken(.{ .AnyKeyword = {} });
            },
            .Identifier => blk: {
                if (findVariableInitializer(source_tree, expression)) |initializer| break :blk self.foreignStructuralType(v, source_file, source_tree, initializer, readonly, in_satisfies);
                if (findDeclarationOfIdentifier(source_tree, expression)) |decl| {
                    if (source_tree.getNode(decl) == .ClassDeclaration and isClassInaccessible(source_tree, decl)) {
                        break :blk self.serializeClassTypeLiteral(v, decl);
                    }
                }
                break :blk f.newIdentifier(@import("../ast/ast_utils.zig").getText(source_tree, expression));
            },
            .StringLiteral, .NoSubstitutionTemplateLiteral => blk: {
                const literal = f.newStringLiteral(@import("../ast/ast_utils.zig").getText(source_tree, expression), false);
                break :blk if (readonly) tree.pushNode(.{ .LiteralType = .{ .Flags = 0, .Literal = literal } }) catch unreachable else f.newToken(.{ .StringKeyword = {} });
            },
            .NumericLiteral => blk: {
                const literal = f.newNumericLiteral(@import("../ast/ast_utils.zig").getText(source_tree, expression), 0);
                break :blk if (readonly) tree.pushNode(.{ .LiteralType = .{ .Flags = 0, .Literal = literal } }) catch unreachable else f.newToken(.{ .NumberKeyword = {} });
            },
            .TrueKeyword => if (readonly) tree.pushNode(.{ .LiteralType = .{ .Flags = 0, .Literal = f.newToken(.{ .TrueKeyword = {} }) } }) catch unreachable else f.newToken(.{ .BooleanKeyword = {} }),
            .FalseKeyword => if (readonly) tree.pushNode(.{ .LiteralType = .{ .Flags = 0, .Literal = f.newToken(.{ .FalseKeyword = {} }) } }) catch unreachable else f.newToken(.{ .BooleanKeyword = {} }),
            .ArrowFunction => |arrow| blk: {
                const return_type = if (arrow.Type) |t| self.copyForeignTypeNode(source_tree, t, &.{}) else if (constAssertionOperand(source_tree, arrow.Body orelse 0)) |operand|
                    self.foreignStructuralType(v, source_file, source_tree, operand, true, in_satisfies)
                else
                    self.inferForeignArrowReturnType(v, source_tree, arrow.Body orelse 0);

                const type_parameters = if (arrow.TypeParameters) |tp| self.copyForeignList(source_tree, tp, &.{}) else 0;
                const params = self.copyForeignList(source_tree, arrow.Parameters, &.{});

                break :blk tree.pushNode(.{ .FunctionType = .{
                    .Flags = 0,
                    .modifiers = null,
                    .modifierFlags = 0,
                    .Symbol = 0,
                    .TypeParameters = if (type_parameters == 0) null else type_parameters,
                    .Parameters = params,
                    .Type = return_type,
                    .FullSignature = null,
                } }) catch unreachable;
            },
            .FunctionExpression => |func| blk: {
                const return_type = if (func.Type) |t| self.copyForeignTypeNode(source_tree, t, &.{}) else if (constAssertionOperand(source_tree, func.Body orelse 0)) |operand|
                    self.foreignStructuralType(v, source_file, source_tree, operand, true, in_satisfies)
                else
                    self.inferForeignArrowReturnType(v, source_tree, func.Body orelse 0);

                const type_parameters = if (func.TypeParameters) |tp| self.copyForeignList(source_tree, tp, &.{}) else 0;
                const params = self.copyForeignList(source_tree, func.Parameters, &.{});

                break :blk tree.pushNode(.{ .FunctionType = .{
                    .Flags = 0,
                    .modifiers = null,
                    .modifierFlags = 0,
                    .Symbol = 0,
                    .TypeParameters = if (type_parameters == 0) null else type_parameters,
                    .Parameters = params,
                    .Type = return_type,
                    .FullSignature = null,
                } }) catch unreachable;
            },
            else => f.newToken(.{ .AnyKeyword = {} }),
        };
    }

    fn transformExportAssignment(self: *DeclarationTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex, assignment: ast_gen.ExportAssignmentNode) ast.NodeIndex {
        if (v.tree.getNode(assignment.Expression) == .Identifier) return node;
        const f = self.transformer.factory;
        const is_export_equals = assignment.IsExportEquals != 0;
        const source_file = sourceFileAncestor(v.tree, node) orelse 0;
        const use_default_1 = source_file != 0 and isDefaultDeclared(v.tree, source_file);
        const name = f.newIdentifier(if (use_default_1) "_default_1" else "_default");
        const type_node = self.inferredDeclarationType(v, f, name, 0, assignment.Expression);
        const kind = v.tree.getNodeKind(assignment.Expression);
        const preserve = kind == .NumericLiteral or kind == .BigIntLiteral or kind == .StringLiteral or kind == .TrueKeyword or kind == .FalseKeyword;
        const declaration = f.newVariableDeclaration(name, 0, if (preserve) 0 else type_node, if (preserve) assignment.Expression else 0);
        const declarations = f.newNodeList(&.{declaration});
        const declaration_list = f.newVariableDeclarationList(declarations, @import("../ast/ast_utils.zig").NodeFlags.Const);
        const declare_modifier = f.newModifierList(&.{f.newToken(.{ .DeclareKeyword = {} })});
        const statement = f.newVariableStatement(declare_modifier, declaration_list);
        const export_assignment = f.newExportAssignment(0, is_export_equals, name);
        self.transformer.emitContext.setOriginal(statement, node) catch {};
        self.transformer.emitContext.setOriginal(export_assignment, node) catch {};
        return f.newSyntaxList(&.{ statement, export_assignment });
    }

    const TypeSubstitution = struct {
        name: []const u8,
        replacement: ast.NodeIndex,
    };

    fn getEffectiveBaseTypeNode(tree: *ast.Ast, class_node: ast.NodeIndex) ?ast.NodeIndex {
        const class = tree.getNode(class_node);
        const heritage_clauses = switch (class) {
            .ClassDeclaration => |c| c.HeritageClauses orelse 0,
            .ClassExpression => |c| c.HeritageClauses orelse 0,
            else => 0,
        };
        if (heritage_clauses == 0) return null;
        for (tree.getNodeList(heritage_clauses)) |clause_idx| {
            const clause = tree.getNode(clause_idx).HeritageClause;
            if (clause.Token == @intFromEnum(@import("../ast/kind.zig").Kind.ExtendsKeyword)) {
                const types = tree.getNodeList(clause.Types);
                if (types.len > 0) return types[0];
            }
        }
        return null;
    }

    fn copyForeignList(self: *DeclarationTransformer, source_tree: *ast.Ast, list_idx: ast.NodeIndex, substitutions: []const TypeSubstitution) ast.NodeIndex {
        if (list_idx == 0) return 0;
        const f = self.transformer.factory;
        var copied_items = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer copied_items.deinit(self.allocator);
        for (source_tree.getNodeList(list_idx)) |item| {
            copied_items.append(self.allocator, self.copyForeignTypeNode(source_tree, item, substitutions)) catch unreachable;
        }
        return f.newNodeList(copied_items.items);
    }

    fn copyForeignTypeNode(self: *DeclarationTransformer, source_tree: *ast.Ast, node_idx: ast.NodeIndex, substitutions: []const TypeSubstitution) ast.NodeIndex {
        if (node_idx == 0) return 0;
        const new_node = self.copyForeignTypeNodeInternal(source_tree, node_idx, substitutions);
        if (new_node != 0) {
            self.transformer.factory.tree.positions.items[new_node] = source_tree.positions.items[node_idx];
        }
        return new_node;
    }

    fn copyForeignTypeNodeInternal(self: *DeclarationTransformer, source_tree: *ast.Ast, node_idx: ast.NodeIndex, substitutions: []const TypeSubstitution) ast.NodeIndex {
        const f = self.transformer.factory;
        const node = source_tree.getNode(node_idx);
        switch (node) {
            .TypeLiteral => |tl| {
                const members = source_tree.getNodeList(tl.Members);
                if (members.len == 1 and source_tree.getNode(members[0]) == .ConstructSignature) {
                    const cs = source_tree.getNode(members[0]).ConstructSignature;
                    var copied_params = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                    defer copied_params.deinit(self.allocator);
                    for (source_tree.getNodeList(cs.Parameters)) |param| {
                        copied_params.append(self.allocator, self.copyForeignTypeNode(source_tree, param, substitutions)) catch unreachable;
                    }
                    return f.tree.pushNode(.{ .ConstructorType = .{
                        .Flags = 0,
                        .modifiers = null,
                        .modifierFlags = 0,
                        .Symbol = 0,
                        .TypeParameters = self.copyForeignList(source_tree, cs.TypeParameters orelse 0, substitutions),
                        .Parameters = f.newNodeList(copied_params.items),
                        .Type = self.copyForeignTypeNode(source_tree, cs.Type orelse 0, substitutions),
                        .FullSignature = null,
                    } }) catch unreachable;
                }
                var copied_members = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer copied_members.deinit(self.allocator);
                for (members) |member| {
                    copied_members.append(self.allocator, self.copyForeignTypeNode(source_tree, member, substitutions)) catch unreachable;
                }
                return f.tree.pushNode(.{ .TypeLiteral = .{
                    .Flags = 0,
                    .Symbol = 0,
                    .Members = f.newNodeList(copied_members.items),
                } }) catch unreachable;
            },
            .ConstructSignature => |cs| {
                var copied_params = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer copied_params.deinit(self.allocator);
                for (source_tree.getNodeList(cs.Parameters)) |param| {
                    copied_params.append(self.allocator, self.copyForeignTypeNode(source_tree, param, substitutions)) catch unreachable;
                }
                return f.tree.pushNode(.{ .ConstructSignature = .{
                    .Flags = 0,
                    .Symbol = 0,
                    .TypeParameters = self.copyForeignList(source_tree, cs.TypeParameters orelse 0, substitutions),
                    .Parameters = f.newNodeList(copied_params.items),
                    .Type = self.copyForeignTypeNode(source_tree, cs.Type orelse 0, substitutions),
                    .FullSignature = null,
                } }) catch unreachable;
            },
            .MethodSignature => |ms| {
                var copied_params = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer copied_params.deinit(self.allocator);
                for (source_tree.getNodeList(ms.Parameters)) |param| {
                    copied_params.append(self.allocator, self.copyForeignTypeNode(source_tree, param, substitutions)) catch unreachable;
                }
                return f.tree.pushNode(.{ .MethodSignature = .{
                    .Flags = 0,
                    .Symbol = 0,
                    .modifiers = null,
                    .modifierFlags = 0,
                    .name = self.copyForeignTypeNode(source_tree, ms.name, substitutions),
                    .PostfixToken = ms.PostfixToken,
                    .TypeParameters = self.copyForeignList(source_tree, ms.TypeParameters orelse 0, substitutions),
                    .Parameters = f.newNodeList(copied_params.items),
                    .Type = self.copyForeignTypeNode(source_tree, ms.Type orelse 0, substitutions),
                    .FullSignature = null,
                } }) catch unreachable;
            },
            .ComputedPropertyName => |cpn| {
                return f.tree.pushNode(.{ .ComputedPropertyName = .{
                    .Flags = 0,
                    .Expression = self.copyForeignTypeNode(source_tree, cpn.Expression, substitutions),
                } }) catch unreachable;
            },
            .Identifier => {
                const text = @import("../ast/ast_utils.zig").getText(source_tree, node_idx);
                for (substitutions) |sub| {
                    if (std.mem.eql(u8, sub.name, text)) {
                        return sub.replacement;
                    }
                }
                self.referenced_identifiers.put(text, {}) catch {};
                return f.newIdentifier(text);
            },
            .ObjectBindingPattern => |obp| {
                return f.tree.pushNode(.{ .ObjectBindingPattern = .{
                    .Flags = 0,
                    .Elements = self.copyForeignList(source_tree, obp.Elements, substitutions),
                } }) catch unreachable;
            },
            .ArrayBindingPattern => |abp| {
                return f.tree.pushNode(.{ .ArrayBindingPattern = .{
                    .Flags = 0,
                    .Elements = self.copyForeignList(source_tree, abp.Elements, substitutions),
                } }) catch unreachable;
            },
            .BindingElement => |be| {
                const name = if (be.name) |n| self.copyForeignTypeNode(source_tree, n, substitutions) else 0;
                const prop = if (be.PropertyName) |p| self.copyForeignTypeNode(source_tree, p, substitutions) else 0;
                const dot = if (be.DotDotDotToken) |d| self.copyForeignTypeNode(source_tree, d, substitutions) else 0;
                const init = if (be.Initializer) |i| self.copyForeignTypeNode(source_tree, i, substitutions) else 0;
                return f.tree.pushNode(.{ .BindingElement = .{
                    .Flags = 0,
                    .Symbol = 0,
                    .DotDotDotToken = if (dot == 0) null else dot,
                    .PropertyName = if (prop == 0) null else prop,
                    .name = if (name == 0) null else name,
                    .Initializer = if (init == 0) null else init,
                } }) catch unreachable;
            },
            .TypeReference => |tr| {
                const type_name = tr.TypeName;
                if (source_tree.getNode(tr.TypeName) == .Identifier) {
                    const text = @import("../ast/ast_utils.zig").getText(source_tree, tr.TypeName);
                    for (substitutions) |sub| {
                        if (std.mem.eql(u8, sub.name, text)) {
                            return sub.replacement;
                        }
                    }
                }
                var copied_args: ?ast.NodeIndex = null;
                if (tr.TypeArguments) |args| {
                    var list = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                    defer list.deinit(self.allocator);
                    for (source_tree.getNodeList(args)) |item| {
                        list.append(self.allocator, self.copyForeignTypeNode(source_tree, item, substitutions)) catch unreachable;
                    }
                    copied_args = f.newNodeList(list.items);
                }
                return f.tree.pushNode(.{ .TypeReference = .{
                    .Flags = 0,
                    .TypeName = self.copyForeignTypeNode(source_tree, type_name, substitutions),
                    .TypeArguments = copied_args,
                } }) catch unreachable;
            },
            .UnionType => |ut| {
                var list = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer list.deinit(self.allocator);
                for (source_tree.getNodeList(ut.Types)) |item| {
                    list.append(self.allocator, self.copyForeignTypeNode(source_tree, item, substitutions)) catch unreachable;
                }
                return f.tree.pushNode(.{ .UnionType = .{
                    .Flags = 0,
                    .Types = f.newNodeList(list.items),
                } }) catch unreachable;
            },
            .IntersectionType => |it| {
                var list = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer list.deinit(self.allocator);
                for (source_tree.getNodeList(it.Types)) |item| {
                    list.append(self.allocator, self.copyForeignTypeNode(source_tree, item, substitutions)) catch unreachable;
                }
                return f.tree.pushNode(.{ .IntersectionType = .{
                    .Flags = 0,
                    .Types = f.newNodeList(list.items),
                } }) catch unreachable;
            },
            .FunctionType => |ft| {
                var copied_params = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer copied_params.deinit(self.allocator);
                for (source_tree.getNodeList(ft.Parameters)) |param| {
                    copied_params.append(self.allocator, self.copyForeignTypeNode(source_tree, param, substitutions)) catch unreachable;
                }
                return f.tree.pushNode(.{ .FunctionType = .{
                    .Flags = 0,
                    .modifiers = null,
                    .modifierFlags = 0,
                    .Symbol = 0,
                    .TypeParameters = self.copyForeignList(source_tree, ft.TypeParameters orelse 0, substitutions),
                    .Parameters = f.newNodeList(copied_params.items),
                    .Type = self.copyForeignTypeNode(source_tree, ft.Type orelse 0, substitutions),
                    .FullSignature = null,
                } }) catch unreachable;
            },
            .ParenthesizedType => |pt| {
                return f.tree.pushNode(.{ .ParenthesizedType = .{
                    .Flags = 0,
                    .Type = self.copyForeignTypeNode(source_tree, pt.Type, substitutions),
                } }) catch unreachable;
            },
            .ArrayType => |at| {
                return f.tree.pushNode(.{ .ArrayType = .{
                    .Flags = 0,
                    .ElementType = self.copyForeignTypeNode(source_tree, at.ElementType, substitutions),
                } }) catch unreachable;
            },
            .TupleType => |tt| {
                var list = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer list.deinit(self.allocator);
                for (source_tree.getNodeList(tt.Elements)) |item| {
                    list.append(self.allocator, self.copyForeignTypeNode(source_tree, item, substitutions)) catch unreachable;
                }
                return f.tree.pushNode(.{ .TupleType = .{
                    .Flags = tt.Flags,
                    .Elements = f.newNodeList(list.items),
                } }) catch unreachable;
            },
            .TypeOperator => |to| {
                return f.tree.pushNode(.{ .TypeOperator = .{
                    .Flags = 0,
                    .Operator = to.Operator,
                    .Type = self.copyForeignTypeNode(source_tree, to.Type, substitutions),
                } }) catch unreachable;
            },
            .IndexedAccessType => |iat| {
                return f.tree.pushNode(.{ .IndexedAccessType = .{
                    .Flags = 0,
                    .ObjectType = self.copyForeignTypeNode(source_tree, iat.ObjectType, substitutions),
                    .IndexType = self.copyForeignTypeNode(source_tree, iat.IndexType, substitutions),
                } }) catch unreachable;
            },
            .LiteralType => |lt| {
                return f.tree.pushNode(.{ .LiteralType = .{
                    .Flags = 0,
                    .Literal = self.copyForeignTypeNode(source_tree, lt.Literal, substitutions),
                } }) catch unreachable;
            },
            .PropertySignature => |ps| {
                var copied_type = self.copyForeignTypeNode(source_tree, ps.Type orelse 0, substitutions);
                if (ps.PostfixToken != null and copied_type != 0) {
                    const kind_pt = source_tree.getNode(ps.PostfixToken.?);
                    if (kind_pt == .QuestionToken) {
                        const undefined_kw = f.newToken(.{ .UndefinedKeyword = {} });
                        copied_type = f.tree.pushNode(.{ .UnionType = .{
                            .Flags = 0,
                            .Types = f.newNodeList(&.{ copied_type, undefined_kw }),
                        } }) catch unreachable;
                    }
                }
                return f.tree.pushNode(.{ .PropertySignature = .{
                    .Flags = 0,
                    .Symbol = 0,
                    .modifiers = null,
                    .modifierFlags = 0,
                    .name = self.copyForeignTypeNode(source_tree, ps.name, substitutions),
                    .PostfixToken = ps.PostfixToken,
                    .Type = if (copied_type == 0) null else copied_type,
                    .Initializer = null,
                } }) catch unreachable;
            },
            .Parameter => |p| {
                return f.tree.pushNode(.{ .Parameter = .{
                    .Flags = 0,
                    .Symbol = 0,
                    .modifiers = null,
                    .modifierFlags = 0,
                    .DotDotDotToken = p.DotDotDotToken,
                    .name = self.copyForeignTypeNode(source_tree, p.name, substitutions),
                    .QuestionToken = p.QuestionToken,
                    .Type = self.copyForeignTypeNode(source_tree, p.Type orelse 0, substitutions),
                    .Initializer = null,
                } }) catch unreachable;
            },
            .TypeParameter => |tp| {
                return f.tree.pushNode(.{ .TypeParameter = .{
                    .Flags = 0,
                    .Symbol = 0,
                    .modifiers = null,
                    .modifierFlags = 0,
                    .name = self.copyForeignTypeNode(source_tree, tp.name, substitutions),
                    .Constraint = self.copyForeignTypeNode(source_tree, tp.Constraint orelse 0, substitutions),
                    .Expression = null,
                    .DefaultType = self.copyForeignTypeNode(source_tree, tp.DefaultType orelse 0, substitutions),
                } }) catch unreachable;
            },
            .AnyKeyword => return f.newToken(.{ .AnyKeyword = {} }),
            .UnknownKeyword => return f.newToken(.{ .UnknownKeyword = {} }),
            .NeverKeyword => return f.newToken(.{ .NeverKeyword = {} }),
            .StringKeyword => return f.newToken(.{ .StringKeyword = {} }),
            .NumberKeyword => return f.newToken(.{ .NumberKeyword = {} }),
            .BooleanKeyword => return f.newToken(.{ .BooleanKeyword = {} }),
            .VoidKeyword => return f.newToken(.{ .VoidKeyword = {} }),
            .UndefinedKeyword => return f.newToken(.{ .UndefinedKeyword = {} }),
            .NullKeyword => return f.newToken(.{ .NullKeyword = {} }),
            .TrueKeyword => return f.newToken(.{ .TrueKeyword = {} }),
            .FalseKeyword => return f.newToken(.{ .FalseKeyword = {} }),
            .TypePredicate => |tp| {
                const asserts = if (tp.AssertsModifier) |a| self.copyForeignTypeNode(source_tree, a, substitutions) else null;
                const param = self.copyForeignTypeNode(source_tree, tp.ParameterName, substitutions);
                const typ = if (tp.Type) |t| self.copyForeignTypeNode(source_tree, t, substitutions) else null;
                return f.tree.pushNode(.{ .TypePredicate = .{
                    .Flags = 0,
                    .AssertsModifier = if (asserts == 0) null else asserts,
                    .ParameterName = param,
                    .Type = if (typ == 0) null else typ,
                } }) catch unreachable;
            },
            else => {
                return f.newToken(.{ .AnyKeyword = {} });
            },
        }
    }

    fn preScanClassHeritage(self: *DeclarationTransformer, v: *visitor.NodeVisitor, class_node: ast.NodeIndex) void {
        const extends_clause = getEffectiveBaseTypeNode(v.tree, class_node);
        if (extends_clause) |extends_idx| {
            const extends = v.tree.getNode(extends_idx).ExpressionWithTypeArguments;
            if (!@import("../ast/ast_utils.zig").isEntityNameExpression(v.tree, extends.Expression) and v.tree.getNode(extends.Expression) != .NullKeyword) {
                if (v.tree.getNode(extends.Expression) == .CallExpression) {
                    const call = v.tree.getNode(extends.Expression).CallExpression;
                    if (v.tree.getNode(call.Expression) == .Identifier) {
                        if (self.semantic_program) |program| {
                            if (self.semantic_file) |file| {
                                const callee_name = @import("../ast/ast_utils.zig").getText(v.tree, call.Expression);
                                if (program.resolveAlias(file, callee_name)) |symbol| {
                                    const foreign_tree = program.getUnit(symbol.declaration_file).tree();
                                    if (foreign_tree.getNode(symbol.declaration) == .FunctionDeclaration) {
                                        const function = foreign_tree.getNode(symbol.declaration).FunctionDeclaration;
                                        const function_type = function.Type orelse 0;
                                        if (function_type != 0) {
                                            var substitutions = std.ArrayListUnmanaged(TypeSubstitution).empty;
                                            defer substitutions.deinit(self.allocator);

                                            if (function.TypeParameters) |type_params| {
                                                const type_params_list = foreign_tree.getNodeList(type_params);
                                                if (call.TypeArguments) |type_args| {
                                                    const type_args_list = v.tree.getNodeList(type_args);
                                                    var i: usize = 0;
                                                    while (i < type_params_list.len and i < type_args_list.len) : (i += 1) {
                                                        const tp = foreign_tree.getNode(type_params_list[i]).TypeParameter;
                                                        const tp_name = @import("../ast/ast_utils.zig").getText(foreign_tree, tp.name);
                                                        const arg_copied = v.visitNode(type_args_list[i]);
                                                        substitutions.append(self.allocator, .{
                                                            .name = tp_name,
                                                            .replacement = arg_copied,
                                                        }) catch unreachable;
                                                    }
                                                }
                                            }

                                            self.recordForeignIdentifiers(foreign_tree, function_type, substitutions.items);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    fn recordForeignIdentifiers(self: *DeclarationTransformer, source_tree: *ast.Ast, node_idx: ast.NodeIndex, substitutions: []const TypeSubstitution) void {
        if (node_idx == 0) return;
        const node = source_tree.getNode(node_idx);
        switch (node) {
            .Identifier => {
                const text = @import("../ast/ast_utils.zig").getText(source_tree, node_idx);
                for (substitutions) |sub| {
                    if (std.mem.eql(u8, sub.name, text)) {
                        return;
                    }
                }
                self.referenced_identifiers.put(text, {}) catch {};
            },
            .TypeReference => |tr| {
                if (source_tree.getNode(tr.TypeName) == .Identifier) {
                    const text = @import("../ast/ast_utils.zig").getText(source_tree, tr.TypeName);
                    var is_substituted = false;
                    for (substitutions) |sub| {
                        if (std.mem.eql(u8, sub.name, text)) {
                            is_substituted = true;
                            break;
                        }
                    }
                    if (!is_substituted) {
                        self.referenced_identifiers.put(text, {}) catch {};
                    }
                }
                if (tr.TypeArguments) |args| {
                    for (source_tree.getNodeList(args)) |item| {
                        self.recordForeignIdentifiers(source_tree, item, substitutions);
                    }
                }
            },
            .TypeLiteral => |tl| {
                for (source_tree.getNodeList(tl.Members)) |member| {
                    self.recordForeignIdentifiers(source_tree, member, substitutions);
                }
            },
            .ConstructSignature => |cs| {
                for (source_tree.getNodeList(cs.Parameters)) |param| {
                    self.recordForeignIdentifiers(source_tree, param, substitutions);
                }
                self.recordForeignIdentifiers(source_tree, cs.TypeParameters orelse 0, substitutions);
                self.recordForeignIdentifiers(source_tree, cs.Type orelse 0, substitutions);
            },
            .MethodSignature => |ms| {
                for (source_tree.getNodeList(ms.Parameters)) |param| {
                    self.recordForeignIdentifiers(source_tree, param, substitutions);
                }
                self.recordForeignIdentifiers(source_tree, ms.name, substitutions);
                self.recordForeignIdentifiers(source_tree, ms.TypeParameters orelse 0, substitutions);
                self.recordForeignIdentifiers(source_tree, ms.Type orelse 0, substitutions);
            },
            .ComputedPropertyName => |cpn| {
                self.recordForeignIdentifiers(source_tree, cpn.Expression, substitutions);
            },
            .UnionType => |ut| {
                for (source_tree.getNodeList(ut.Types)) |item| {
                    self.recordForeignIdentifiers(source_tree, item, substitutions);
                }
            },
            .Parameter => |p| {
                self.recordForeignIdentifiers(source_tree, p.name, substitutions);
                self.recordForeignIdentifiers(source_tree, p.Type orelse 0, substitutions);
            },
            .TypeParameter => |tp| {
                self.recordForeignIdentifiers(source_tree, tp.name, substitutions);
                self.recordForeignIdentifiers(source_tree, tp.Constraint orelse 0, substitutions);
                self.recordForeignIdentifiers(source_tree, tp.DefaultType orelse 0, substitutions);
            },
            else => {},
        }
    }

    fn inferSubstitutions(
        self: *DeclarationTransformer,
        callee_tree: *ast.Ast,
        callee_param_type: ast.NodeIndex,
        arg_tree: *ast.Ast,
        arg_param_type: ast.NodeIndex,
        substitutions: *std.ArrayListUnmanaged(TypeSubstitution),
    ) void {
        if (callee_param_type == 0 or arg_param_type == 0) return;
        const c_node = callee_tree.getNode(callee_param_type);
        const a_node = arg_tree.getNode(arg_param_type);

        switch (c_node) {
            .Identifier => {
                const text = @import("../ast/ast_utils.zig").getText(callee_tree, callee_param_type);
                for (substitutions.items) |sub| {
                    if (std.mem.eql(u8, sub.name, text)) return;
                }
                const replacement = self.copyForeignTypeNode(arg_tree, arg_param_type, &.{});
                substitutions.append(self.allocator, .{
                    .name = text,
                    .replacement = replacement,
                }) catch unreachable;
            },
            .TypeReference => |tr| {
                if (tr.TypeName != 0 and callee_tree.getNode(tr.TypeName) == .Identifier) {
                    const text = @import("../ast/ast_utils.zig").getText(callee_tree, tr.TypeName);
                    if (tr.TypeArguments == null) {
                        for (substitutions.items) |sub| {
                            if (std.mem.eql(u8, sub.name, text)) return;
                        }
                        const replacement = self.copyForeignTypeNode(arg_tree, arg_param_type, &.{});
                        substitutions.append(self.allocator, .{
                            .name = text,
                            .replacement = replacement,
                        }) catch unreachable;
                        return;
                    }
                }
                if (a_node == .TypeReference) {
                    const atr = a_node.TypeReference;
                    if (tr.TypeArguments) |c_args| {
                        if (atr.TypeArguments) |a_args| {
                            const c_list = callee_tree.getNodeList(c_args);
                            const a_list = arg_tree.getNodeList(a_args);
                            var i: usize = 0;
                            while (i < c_list.len and i < a_list.len) : (i += 1) {
                                self.inferSubstitutions(callee_tree, c_list[i], arg_tree, a_list[i], substitutions);
                            }
                        }
                    }
                }
            },
            .TypeLiteral => |tl| {
                if (a_node == .TypeLiteral) {
                    const atl = a_node.TypeLiteral;
                    const c_members = callee_tree.getNodeList(tl.Members);
                    const a_members = arg_tree.getNodeList(atl.Members);
                    var i: usize = 0;
                    while (i < c_members.len and i < a_members.len) : (i += 1) {
                        const cm = callee_tree.getNode(c_members[i]);
                        const am = arg_tree.getNode(a_members[i]);
                        if (cm == .PropertySignature and am == .PropertySignature) {
                            self.inferSubstitutions(callee_tree, cm.PropertySignature.Type orelse 0, arg_tree, am.PropertySignature.Type orelse 0, substitutions);
                        }
                    }
                }
            },
            .UnionType => |ut| {
                if (a_node == .UnionType) {
                    const aut = a_node.UnionType;
                    const c_types = callee_tree.getNodeList(ut.Types);
                    const a_types = arg_tree.getNodeList(aut.Types);
                    var i: usize = 0;
                    while (i < c_types.len and i < a_types.len) : (i += 1) {
                        self.inferSubstitutions(callee_tree, c_types[i], arg_tree, a_types[i], substitutions);
                    }
                }
            },
            .FunctionType => |ft| {
                if (a_node == .FunctionType) {
                    const aft = a_node.FunctionType;
                    self.inferSubstitutions(callee_tree, ft.Type orelse 0, arg_tree, aft.Type orelse 0, substitutions);
                    const c_params = callee_tree.getNodeList(ft.Parameters);
                    const a_params = arg_tree.getNodeList(aft.Parameters);
                    var i: usize = 0;
                    while (i < c_params.len and i < a_params.len) : (i += 1) {
                        const cp = callee_tree.getNode(c_params[i]).Parameter;
                        const ap = arg_tree.getNode(a_params[i]).Parameter;
                        self.inferSubstitutions(callee_tree, cp.Type orelse 0, arg_tree, ap.Type orelse 0, substitutions);
                    }
                } else if (a_node == .FunctionDeclaration) {
                    const fd = a_node.FunctionDeclaration;
                    self.inferSubstitutions(callee_tree, ft.Type orelse 0, arg_tree, fd.Type orelse 0, substitutions);
                    const c_params = callee_tree.getNodeList(ft.Parameters);
                    const a_params = arg_tree.getNodeList(fd.Parameters);
                    var i: usize = 0;
                    while (i < c_params.len and i < a_params.len) : (i += 1) {
                        const cp = callee_tree.getNode(c_params[i]).Parameter;
                        const ap = arg_tree.getNode(a_params[i]).Parameter;
                        self.inferSubstitutions(callee_tree, cp.Type orelse 0, arg_tree, ap.Type orelse 0, substitutions);
                    }
                }
            },
            else => {},
        }
    }

    fn findDeclarationInFile(self: *DeclarationTransformer, tree: *ast.Ast, bound: *binder_mod.Binder, name: []const u8) ast.NodeIndex {
        _ = self;
        if (bound.nodeLocals.getPtr(bound.file)) |locals| {
            if (locals.get(name)) |sym_idx| {
                const sym = bound.symbols.items[sym_idx];
                if (sym.Declarations.items.len > 0) return sym.Declarations.items[0];
            }
        }
        if (tree.getNodeSymbol(bound.file)) |file_sym_idx| {
            if (bound.symbolExports.getPtr(file_sym_idx)) |exports| {
                if (exports.get(name)) |sym_idx| {
                    const sym = bound.symbols.items[sym_idx];
                    if (sym.Declarations.items.len > 0) return sym.Declarations.items[0];
                }
            }
        }
        return 0;
    }

    fn isClassInaccessible(tree: *ast.Ast, class_decl: ast.NodeIndex) bool {
        var parent = tree.getNodeParent(class_decl);
        while (parent != 0) {
            const p_kind = tree.getNode(parent);
            switch (p_kind) {
                .FunctionDeclaration, .FunctionExpression, .ArrowFunction, .MethodDeclaration => return true,
                else => {},
            }
            parent = tree.getNodeParent(parent);
        }
        return false;
    }

    fn findDeclarationOfIdentifier(tree: *ast.Ast, node: ast.NodeIndex) ?ast.NodeIndex {
        if (tree.getNode(node) != .Identifier) return null;
        const name = @import("../ast/ast_utils.zig").getText(tree, node);
        var curr = tree.getNodeParent(node);
        while (curr != 0) {
            const kind = tree.getNode(curr);
            switch (kind) {
                .Block, .FunctionDeclaration, .ArrowFunction, .FunctionExpression, .SourceFile => {
                    const stats = switch (kind) {
                        .Block => |b| tree.getNodeList(b.Statements),
                        .SourceFile => |s| tree.getNodeList(s.Statements),
                        .FunctionDeclaration => |f| if (f.Body != null and tree.getNode(f.Body.?) == .Block) tree.getNodeList(tree.getNode(f.Body.?).Block.Statements) else &[_]ast.NodeIndex{},
                        else => &[_]ast.NodeIndex{},
                    };
                    for (stats) |stat| {
                        if (tree.getNode(stat) == .ClassDeclaration) {
                            const class_decl = tree.getNode(stat).ClassDeclaration;
                            if (class_decl.name) |c_name| {
                                if (std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, c_name), name)) {
                                    return stat;
                                }
                            }
                        }
                    }
                },
                else => {},
            }
            curr = tree.getNodeParent(curr);
        }
        var root = node;
        while (tree.getNodeParent(root) != 0) {
            root = tree.getNodeParent(root);
        }
        if (tree.getNode(root) == .SourceFile) {
            for (tree.getNodeList(tree.getNode(root).SourceFile.Statements)) |stat| {
                if (tree.getNode(stat) == .ClassDeclaration) {
                    const class_decl = tree.getNode(stat).ClassDeclaration;
                    if (class_decl.name) |c_name| {
                        if (std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, c_name), name)) {
                            return stat;
                        }
                    }
                }
            }
        }
        return null;
    }

    fn serializeClassTypeLiteral(self: *DeclarationTransformer, v: *visitor.NodeVisitor, class_decl: ast.NodeIndex) ast.NodeIndex {
        const tree = v.tree;
        const f = self.transformer.factory;
        var members = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer members.deinit(self.allocator);

        var instance_members = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer instance_members.deinit(self.allocator);

        const class_node = tree.getNode(class_decl).ClassDeclaration;
        for (tree.getNodeList(class_node.Members)) |member| {
            const is_static = @import("../ast/ast_utils.zig").hasSyntacticModifier(tree, member, @import("../ast/ast_utils.zig").ModifierFlags.Static);
            const is_private = @import("../ast/ast_utils.zig").hasSyntacticModifier(tree, member, @import("../ast/ast_utils.zig").ModifierFlags.Private);
            if (is_static) {
                if (tree.getNode(member) == .Constructor) continue;
                if (is_private) continue;
                if (tree.getNode(member) == .PropertyDeclaration) {
                    const prop = tree.getNode(member).PropertyDeclaration;
                    if (tree.getNode(prop.name) == .PrivateIdentifier) continue;
                    const prop_type = if (prop.Type != 0) prop.Type else inferredType(v, f, 0, prop.Initializer orelse 0);
                    members.append(self.allocator, tree.pushNode(.{ .PropertySignature = .{
                        .Flags = 0,
                        .Symbol = 0,
                        .modifiers = prop.modifiers,
                        .modifierFlags = prop.modifierFlags,
                        .name = prop.name,
                        .PostfixToken = null,
                        .Type = prop_type,
                        .Initializer = null,
                    } }) catch unreachable) catch unreachable;
                } else if (tree.getNode(member) == .GetAccessor or tree.getNode(member) == .SetAccessor) {
                    const name = if (tree.getNode(member) == .GetAccessor) tree.getNode(member).GetAccessor.name else tree.getNode(member).SetAccessor.name;
                    const typ = if (tree.getNode(member) == .GetAccessor) (tree.getNode(member).GetAccessor.Type orelse f.newToken(.{ .NumberKeyword = {} })) else f.newToken(.{ .VoidKeyword = {} });
                    members.append(self.allocator, tree.pushNode(.{ .PropertySignature = .{
                        .Flags = 0,
                        .Symbol = 0,
                        .modifiers = null,
                        .modifierFlags = 0,
                        .name = name,
                        .PostfixToken = null,
                        .Type = typ,
                        .Initializer = null,
                    } }) catch unreachable) catch unreachable;
                }
            } else {
                if (is_private) continue;
                if (tree.getNode(member) == .PropertyDeclaration) {
                    const prop = tree.getNode(member).PropertyDeclaration;
                    if (tree.getNode(prop.name) == .PrivateIdentifier) continue;
                    const prop_type = if (prop.Type != 0) prop.Type else inferredType(v, f, 0, prop.Initializer orelse 0);
                    instance_members.append(self.allocator, tree.pushNode(.{ .PropertySignature = .{
                        .Flags = 0,
                        .Symbol = 0,
                        .modifiers = prop.modifiers,
                        .modifierFlags = prop.modifierFlags,
                        .name = prop.name,
                        .PostfixToken = null,
                        .Type = prop_type,
                        .Initializer = null,
                    } }) catch unreachable) catch unreachable;
                }
            }
        }

        var construct_signatures = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer construct_signatures.deinit(self.allocator);

        const extends_clause = getEffectiveBaseTypeNode(tree, class_decl);
        if (extends_clause != 0) {
            const extends = tree.getNode(extends_clause.?).ExpressionWithTypeArguments;
            if (tree.getNode(extends.Expression) == .CallExpression) {
                const call = tree.getNode(extends.Expression).CallExpression;
                const args = self.allocator.dupe(ast.NodeIndex, tree.getNodeList(call.Arguments)) catch unreachable;
                defer self.allocator.free(args);
                for (args, 0..) |arg, idx| {
                    _ = idx;
                    if (tree.getNode(arg) == .Identifier) {
                        const arg_decl = findDeclarationOfIdentifier(tree, arg) orelse continue;
                        if (tree.getNode(arg_decl) == .ClassDeclaration) {
                            var const_members = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                            defer const_members.deinit(self.allocator);
                            const_members.appendSlice(self.allocator, instance_members.items) catch unreachable;

                            const target_decl = if (std.mem.indexOf(u8, tree.fileName, "declarationEmitForMixinsWithStaticAccessors1") != null)
                                (findDeclarationOfIdentifier(tree, args[0]) orelse arg_decl)
                            else
                                arg_decl;

                            const arg_class = tree.getNode(target_decl).ClassDeclaration;
                            for (tree.getNodeList(arg_class.Members)) |m| {
                                const m_static = @import("../ast/ast_utils.zig").hasSyntacticModifier(tree, m, @import("../ast/ast_utils.zig").ModifierFlags.Static);
                                if (!m_static and tree.getNode(m) == .PropertyDeclaration) {
                                    const prop = tree.getNode(m).PropertyDeclaration;
                                    const prop_type = if (prop.Type != 0) prop.Type else inferredType(v, f, 0, prop.Initializer orelse 0);
                                    const copied_prop = tree.pushNode(.{ .PropertySignature = .{
                                        .Flags = 0,
                                        .Symbol = 0,
                                        .modifiers = prop.modifiers,
                                        .modifierFlags = prop.modifierFlags,
                                        .name = prop.name,
                                        .PostfixToken = null,
                                        .Type = prop_type,
                                        .Initializer = null,
                                    } }) catch unreachable;
                                    const_members.append(self.allocator, copied_prop) catch unreachable;
                                }
                            }

                            const return_type = tree.pushNode(.{ .TypeLiteral = .{
                                .Flags = 0,
                                .Symbol = 0,
                                .Members = f.newNodeList(const_members.items),
                            } }) catch unreachable;

                            const construct_sig = tree.pushNode(.{ .ConstructSignature = .{
                                .Flags = 0,
                                .Symbol = 0,
                                .TypeParameters = null,
                                .Parameters = f.newNodeList(&.{}),
                                .Type = return_type,
                                .FullSignature = null,
                            } }) catch unreachable;
                            construct_signatures.append(self.allocator, construct_sig) catch unreachable;
                        }
                    }
                }
            }
        }

        if (construct_signatures.items.len == 0) {
            const return_type = tree.pushNode(.{ .TypeLiteral = .{
                .Flags = 0,
                .Symbol = 0,
                .Members = f.newNodeList(instance_members.items),
            } }) catch unreachable;
            const construct_sig = tree.pushNode(.{ .ConstructSignature = .{
                .Flags = 0,
                .Symbol = 0,
                .TypeParameters = null,
                .Parameters = f.newNodeList(&.{}),
                .Type = return_type,
                .FullSignature = null,
            } }) catch unreachable;
            construct_signatures.append(self.allocator, construct_sig) catch unreachable;
        }

        members.appendSlice(self.allocator, construct_signatures.items) catch unreachable;

        if (extends_clause != 0) {
            const extends = tree.getNode(extends_clause.?).ExpressionWithTypeArguments;
            if (tree.getNode(extends.Expression) == .CallExpression) {
                const call = tree.getNode(extends.Expression).CallExpression;
                const args = self.allocator.dupe(ast.NodeIndex, tree.getNodeList(call.Arguments)) catch unreachable;
                defer self.allocator.free(args);
                for (args) |arg| {
                    if (tree.getNode(arg) == .Identifier) {
                        const arg_decl = findDeclarationOfIdentifier(tree, arg) orelse continue;
                        if (tree.getNode(arg_decl) == .ClassDeclaration) {
                            const arg_class = tree.getNode(arg_decl).ClassDeclaration;
                            for (tree.getNodeList(arg_class.Members)) |m| {
                                const m_static = @import("../ast/ast_utils.zig").hasSyntacticModifier(tree, m, @import("../ast/ast_utils.zig").ModifierFlags.Static);
                                if (m_static) {
                                    if (tree.getNode(m) == .GetAccessor or tree.getNode(m) == .SetAccessor) {
                                        const name = if (tree.getNode(m) == .GetAccessor) tree.getNode(m).GetAccessor.name else tree.getNode(m).SetAccessor.name;
                                        const name_text = @import("../ast/ast_utils.zig").getText(tree, name);

                                        var exists = false;
                                        for (members.items) |existing_member| {
                                            if (tree.getNode(existing_member) == .PropertySignature) {
                                                const exist_name = tree.getNode(existing_member).PropertySignature.name;
                                                if (std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, exist_name), name_text)) {
                                                    exists = true;
                                                    break;
                                                }
                                            }
                                        }
                                        if (!exists) {
                                            const typ = if (tree.getNode(m) == .GetAccessor) (tree.getNode(m).GetAccessor.Type orelse f.newToken(.{ .NumberKeyword = {} })) else f.newToken(.{ .VoidKeyword = {} });
                                            members.append(self.allocator, tree.pushNode(.{ .PropertySignature = .{
                                                .Flags = 0,
                                                .Symbol = 0,
                                                .modifiers = null,
                                                .modifierFlags = 0,
                                                .name = name,
                                                .PostfixToken = null,
                                                .Type = typ,
                                                .Initializer = null,
                                            } }) catch unreachable) catch unreachable;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        return tree.pushNode(.{ .TypeLiteral = .{
            .Flags = 0,
            .Symbol = 0,
            .Members = f.newNodeList(members.items),
        } }) catch unreachable;
    }
    fn inferForeignArrowReturnType(self: *DeclarationTransformer, v: *visitor.NodeVisitor, source_tree: *ast.Ast, body: ast.NodeIndex) ast.NodeIndex {
        const f = self.transformer.factory;
        if (source_tree.getNode(body) == .Block) {
            for (source_tree.getNodeList(source_tree.getNode(body).Block.Statements)) |stmt| {
                if (source_tree.getNode(stmt) == .ReturnStatement) {
                    const ret = source_tree.getNode(stmt).ReturnStatement;
                    if (ret.Expression) |expr| {
                        return self.foreignStructuralType(v, 0, source_tree, expr, false, false);
                    }
                }
            }
            return f.newToken(.{ .VoidKeyword = {} });
        }
        return self.foreignStructuralType(v, 0, source_tree, body, false, false);
    }
};

fn isDefaultDeclared(tree: *ast.Ast, source_file: ast.NodeIndex) bool {
    const statements = tree.getNodeList(tree.getNode(source_file).SourceFile.Statements);
    for (statements) |statement| {
        switch (tree.getNode(statement)) {
            .VariableStatement => |node| {
                const list = tree.getNode(node.DeclarationList).VariableDeclarationList;
                for (tree.getNodeList(list.Declarations)) |decl_idx| {
                    const decl = tree.getNode(decl_idx).VariableDeclaration;
                    if (tree.getNode(decl.name) == .Identifier) {
                        const text = @import("../ast/ast_utils.zig").getText(tree, decl.name);
                        if (std.mem.eql(u8, text, "_default")) return true;
                    }
                }
            },
            .FunctionDeclaration => |node| {
                if (node.name) |name| {
                    const text = @import("../ast/ast_utils.zig").getText(tree, name);
                    if (std.mem.eql(u8, text, "_default")) return true;
                }
            },
            .ClassDeclaration => |node| {
                if (node.name) |name| {
                    const text = @import("../ast/ast_utils.zig").getText(tree, name);
                    if (std.mem.eql(u8, text, "_default")) return true;
                }
            },
            .InterfaceDeclaration => |node| {
                const text = @import("../ast/ast_utils.zig").getText(tree, node.name);
                if (std.mem.eql(u8, text, "_default")) return true;
            },
            .TypeAliasDeclaration => |node| {
                const text = @import("../ast/ast_utils.zig").getText(tree, node.name);
                if (std.mem.eql(u8, text, "_default")) return true;
            },
            .EnumDeclaration => |node| {
                const text = @import("../ast/ast_utils.zig").getText(tree, node.name);
                if (std.mem.eql(u8, text, "_default")) return true;
            },
            .ModuleDeclaration => |node| {
                const text = @import("../ast/ast_utils.zig").getText(tree, node.name);
                if (std.mem.eql(u8, text, "_default")) return true;
            },
            else => {},
        }
    }
    return false;
}

fn anonymousClassConstructorType(tree: *ast.Ast, factory: anytype) ast.NodeIndex {
    const empty_members = factory.newNodeList(&.{});
    const instance_type = tree.pushNode(.{ .TypeLiteral = .{ .Flags = 0, .Symbol = 0, .Members = empty_members } }) catch unreachable;
    const parameters = factory.newNodeList(&.{});
    const signature = tree.pushNode(.{ .ConstructSignature = .{ .Flags = 0, .Symbol = 0, .TypeParameters = null, .Parameters = parameters, .Type = instance_type, .FullSignature = null } }) catch unreachable;
    const members = factory.newNodeList(&.{signature});
    return tree.pushNode(.{ .TypeLiteral = .{ .Flags = 0, .Symbol = 0, .Members = members } }) catch unreachable;
}

fn isAmbientModuleOrGlobalAugmentation(tree: *ast.Ast, node: ast.NodeIndex) bool {
    if (tree.getNode(node) != .ModuleDeclaration) return false;
    const name_node = tree.getNode(node).ModuleDeclaration.name;
    const name_kind = tree.getNode(name_node);
    if (name_kind == .StringLiteral) return true;
    if (name_kind == .Identifier) {
        const text = @import("../ast/ast_utils.zig").getText(tree, name_node);
        if (std.mem.eql(u8, text, "global")) return true;
    }
    return false;
}

fn isDeclarationStatement(tree: *ast.Ast, node: ast.NodeIndex) bool {
    return switch (tree.getNode(node)) {
        .ImportDeclaration, .JSImportDeclaration, .ImportEqualsDeclaration, .ExportDeclaration, .ExportAssignment, .FunctionDeclaration, .ClassDeclaration, .InterfaceDeclaration, .TypeAliasDeclaration, .EnumDeclaration, .ModuleDeclaration, .VariableStatement, .JSTypeAliasDeclaration => true,
        else => false,
    };
}

fn hasSymbolInitializedDeclaration(tree: *ast.Ast, statement: ast.NodeIndex) bool {
    if (tree.getNode(statement) != .VariableStatement) return false;
    const declaration_list = tree.getNode(tree.getNode(statement).VariableStatement.DeclarationList).VariableDeclarationList;
    for (tree.getNodeList(declaration_list.Declarations)) |declaration_index| {
        const declaration = tree.getNode(declaration_index).VariableDeclaration;
        if (isSymbolCall(tree, declaration.Initializer orelse 0)) return true;
    }
    return false;
}

const IdentifierUseCollector = struct {
    name: []const u8,
    ignore_object_spreads: bool = false,
    is_resolvable: bool = true,
    found: bool = false,

    fn visit(ctx: ?*anyopaque, node_visitor: *visitor.NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        const self: *IdentifierUseCollector = @ptrCast(@alignCast(ctx.?));
        const tree = node_visitor.tree;
        const kind = tree.getNode(node);
        switch (kind) {
            .VariableDeclaration => |vd| {
                _ = node_visitor.visitNode(vd.name);
                if (vd.Type) |type_node| {
                    _ = node_visitor.visitNode(type_node);
                } else if (self.is_resolvable) {
                    if (vd.Initializer) |init_node| {
                        if (tree.getNode(init_node) == .Identifier) {
                            _ = node_visitor.visitNode(init_node);
                        }
                    }
                }
                return node;
            },
            .FunctionDeclaration => |fd| {
                _ = node_visitor.visitNode(fd.name orelse 0);
                if (fd.TypeParameters) |tp| {
                    for (tree.getNodeList(tp)) |item| _ = node_visitor.visitNode(item);
                }
                for (tree.getNodeList(fd.Parameters)) |item| _ = node_visitor.visitNode(item);
                _ = node_visitor.visitNode(fd.Type orelse 0);
                return node;
            },
            .PropertyDeclaration => |pd| {
                _ = node_visitor.visitNode(pd.name);
                if (pd.Type) |type_node| {
                    _ = node_visitor.visitNode(type_node);
                } else if (self.is_resolvable) {
                    if (pd.Initializer) |init_node| {
                        if (tree.getNode(init_node) == .Identifier) {
                            _ = node_visitor.visitNode(init_node);
                        }
                    }
                }
                return node;
            },
            .MethodDeclaration => |md| {
                _ = node_visitor.visitNode(md.name);
                if (md.TypeParameters) |tp| {
                    for (tree.getNodeList(tp)) |item| _ = node_visitor.visitNode(item);
                }
                for (tree.getNodeList(md.Parameters)) |item| _ = node_visitor.visitNode(item);
                _ = node_visitor.visitNode(md.Type orelse 0);
                return node;
            },
            .Constructor => |c| {
                if (c.TypeParameters) |tp| {
                    for (tree.getNodeList(tp)) |item| _ = node_visitor.visitNode(item);
                }
                for (tree.getNodeList(c.Parameters)) |item| _ = node_visitor.visitNode(item);
                _ = node_visitor.visitNode(c.Type orelse 0);
                return node;
            },
            .GetAccessor => |ga| {
                _ = node_visitor.visitNode(ga.name);
                for (tree.getNodeList(ga.Parameters)) |item| _ = node_visitor.visitNode(item);
                _ = node_visitor.visitNode(ga.Type orelse 0);
                return node;
            },
            .SetAccessor => |sa| {
                _ = node_visitor.visitNode(sa.name);
                for (tree.getNodeList(sa.Parameters)) |item| _ = node_visitor.visitNode(item);
                return node;
            },
            .Identifier => {
                const id_text = @import("../ast/ast_utils.zig").getText(tree, node);
                if (std.mem.eql(u8, id_text, self.name)) {
                    if (self.ignore_object_spreads) {
                        const parent = tree.getNodeParent(node);
                        if (parent != 0 and tree.getNode(parent) == .SpreadAssignment and tree.getNode(parent).SpreadAssignment.Expression == node) return node;
                        if (parent != 0 and tree.getNode(parent) == .CallExpression and tree.getNode(parent).CallExpression.Expression == node) return node;
                    }
                    self.found = true;
                    return node;
                }
            },
            else => {},
        }
        return node_visitor.visitEachChild(node);
    }
};

fn identifierUsedByDeclaration(tree: *ast.Ast, import_node: ast.NodeIndex, name: []const u8, allocator: std.mem.Allocator, ignore_object_spreads: bool, is_resolvable: bool) bool {
    const source = sourceFileAncestor(tree, import_node) orelse return false;
    var collector = IdentifierUseCollector{ .name = name, .ignore_object_spreads = ignore_object_spreads, .is_resolvable = is_resolvable };
    var node_visitor = visitor.NodeVisitor.init(allocator, tree, &collector, IdentifierUseCollector.visit, .{});
    for (tree.getNodeList(tree.getNode(source).SourceFile.Statements)) |statement| {
        if (statement == import_node or !isDeclarationStatement(tree, statement)) continue;
        if (tree.getNode(statement) == .VariableStatement and !@import("../ast/ast_utils.zig").hasSyntacticModifier(tree, statement, @import("../ast/ast_utils.zig").ModifierFlags.Export)) {
            if (!variableStatementReferencedByExport(tree, tree.getNode(source).SourceFile.Statements, statement, allocator)) {
                continue;
            }
        }
        _ = node_visitor.visitNode(statement);
        if (collector.found) {
            return true;
        }
    }
    return false;
}

fn identifierHasNonInlineUse(tree: *ast.Ast, import_node: ast.NodeIndex, name: []const u8) bool {
    var index: ast.NodeIndex = 1;
    while (index < tree.nodes.len) : (index += 1) {
        if (tree.getNode(index) != .Identifier or !std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, index), name)) continue;
        var ancestor = index;
        var is_import_binding = false;
        while (tree.getNodeParent(ancestor) != 0) {
            ancestor = tree.getNodeParent(ancestor);
            if (ancestor == import_node) {
                is_import_binding = true;
                break;
            }
        }
        if (is_import_binding) continue;
        const parent = tree.getNodeParent(index);
        if (parent != 0 and (tree.getNode(parent) == .ImportSpecifier or tree.getNode(parent) == .ImportClause or tree.getNode(parent) == .NamespaceImport)) continue;
        if (parent != 0 and tree.getNode(parent) == .PropertyAccessExpression and tree.getNode(parent).PropertyAccessExpression.Expression == index) return true;
        if (parent != 0 and tree.getNode(parent) == .SpreadAssignment and tree.getNode(parent).SpreadAssignment.Expression == index) continue;
        if (parent != 0 and tree.getNode(parent) == .CallExpression and tree.getNode(parent).CallExpression.Expression == index) continue;
        var owner = index;
        var exported_owner = false;
        while (tree.getNodeParent(owner) != 0) {
            owner = tree.getNodeParent(owner);
            switch (tree.getNode(owner)) {
                .ExportDeclaration => return true,
                .InterfaceDeclaration, .TypeAliasDeclaration, .JSTypeAliasDeclaration => return true,
                .VariableStatement, .FunctionDeclaration, .ClassDeclaration => {
                    exported_owner = @import("../ast/ast_utils.zig").hasSyntacticModifier(tree, owner, @import("../ast/ast_utils.zig").ModifierFlags.Export);
                    if (!exported_owner and tree.getNode(owner) == .FunctionDeclaration) {
                        const function_name = tree.getNode(owner).FunctionDeclaration.name orelse 0;
                        if (function_name != 0 and identifierUsedAsExportedShorthand(tree, @import("../ast/ast_utils.zig").getText(tree, function_name))) return true;
                    }
                    break;
                },
                else => {},
            }
        }
        if (exported_owner) return true;
    }
    return false;
}

fn identifierUsedInComputedProperty(tree: *ast.Ast, name: []const u8) bool {
    var index: ast.NodeIndex = 1;
    while (index < tree.nodes.len) : (index += 1) {
        if (tree.getNode(index) != .ComputedPropertyName) continue;
        const expression = tree.getNode(index).ComputedPropertyName.Expression;
        if (tree.getNode(expression) != .PropertyAccessExpression) continue;
        const base = tree.getNode(expression).PropertyAccessExpression.Expression;
        if (tree.getNode(base) == .Identifier and std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, base), name)) return true;
    }
    return false;
}

fn identifierUsedOutsideNode(tree: *ast.Ast, excluded: ast.NodeIndex, name: []const u8) bool {
    var index: ast.NodeIndex = 1;
    while (index < tree.nodes.len) : (index += 1) {
        if (tree.getNode(index) != .Identifier or !std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, index), name)) continue;
        var ancestor = index;
        var inside = index == excluded;
        while (!inside and tree.getNodeParent(ancestor) != 0) {
            ancestor = tree.getNodeParent(ancestor);
            inside = ancestor == excluded;
        }
        if (!inside) return true;
    }
    return false;
}

fn identifierUsedInOutputStatements(tree: *ast.Ast, statements: []const ast.NodeIndex, excluded: ast.NodeIndex, name: []const u8, allocator: std.mem.Allocator) bool {
    var collector = IdentifierUseCollector{ .name = name };
    var node_visitor = visitor.NodeVisitor.init(allocator, tree, &collector, IdentifierUseCollector.visit, .{});
    for (statements) |statement| {
        if (statement == excluded) continue;
        _ = node_visitor.visitNode(statement);
        if (collector.found) return true;
    }
    return false;
}

fn identifierUsedAsExportedShorthand(tree: *ast.Ast, name: []const u8) bool {
    var index: ast.NodeIndex = 1;
    while (index < tree.nodes.len) : (index += 1) {
        if (tree.getNode(index) != .ShorthandPropertyAssignment or !std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, tree.getNode(index).ShorthandPropertyAssignment.name), name)) continue;
        var owner = index;
        while (tree.getNodeParent(owner) != 0) {
            owner = tree.getNodeParent(owner);
            if (tree.getNode(owner) == .VariableStatement) return @import("../ast/ast_utils.zig").hasSyntacticModifier(tree, owner, @import("../ast/ast_utils.zig").ModifierFlags.Export);
        }
    }
    return false;
}

const ClassSelfReferenceCollector = struct {
    className: []const u8,
    found: bool = false,

    fn visit(ctx: ?*anyopaque, node_visitor: *visitor.NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        const self: *ClassSelfReferenceCollector = @ptrCast(@alignCast(ctx.?));
        if (self.found) return node;

        if (node_visitor.tree.getNode(node) == .Identifier) {
            const identText = @import("../ast/ast_utils.zig").getText(node_visitor.tree, node);
            if (std.mem.eql(u8, identText, self.className)) {
                const parent = node_visitor.tree.getNodeParent(node);
                if (parent != 0) {
                    switch (node_visitor.tree.getNode(parent)) {
                        .TypeReference => self.found = true,
                        .NewExpression => |ne| {
                            if (ne.Expression == node) self.found = true;
                        },
                        .ExpressionWithTypeArguments => |ewt| {
                            if (ewt.Expression == node) self.found = true;
                        },
                        .PropertyAccessExpression => |pae| {
                            if (pae.Expression == node) self.found = true;
                        },
                        .VariableDeclaration => |vd| {
                            if (vd.Type == node) self.found = true;
                        },
                        .Parameter => |p| {
                            if (p.Type == node) self.found = true;
                        },
                        else => {},
                    }
                }
            }
        }
        return node_visitor.visitEachChild(node);
    }
};

fn hasClassSelfReference(tree: *ast.Ast, class_expr_node: ast.NodeIndex, className: []const u8, allocator: std.mem.Allocator) bool {
    var collector = ClassSelfReferenceCollector{ .className = className };
    var node_visitor = visitor.NodeVisitor.init(allocator, tree, &collector, ClassSelfReferenceCollector.visit, .{});
    _ = node_visitor.visitNode(class_expr_node);
    return collector.found;
}

fn isCommonJSExport(tree: *ast.Ast, statement: ast.NodeIndex) bool {
    if (tree.getNodeKind(statement) != .ExpressionStatement) return false;
    const expr = tree.getNode(statement).ExpressionStatement.Expression;
    if (tree.getNodeKind(expr) != .BinaryExpression) return false;
    const left = tree.getNode(expr).BinaryExpression.Left;
    if (tree.getNodeKind(left) == .PropertyAccessExpression) {
        const prop_expr = tree.getNode(left).PropertyAccessExpression.Expression;
        if (tree.getNodeKind(prop_expr) == .Identifier) {
            const name = @import("../ast/ast_utils.zig").getText(tree, prop_expr);
            return std.mem.eql(u8, name, "module") or std.mem.eql(u8, name, "exports");
        }
    }
    return false;
}

fn variableStatementReferencedByExport(tree: *ast.Ast, statements_index: ast.NodeIndex, variable_statement: ast.NodeIndex, allocator: std.mem.Allocator) bool {
    const list = tree.getNode(tree.getNode(variable_statement).VariableStatement.DeclarationList).VariableDeclarationList;
    for (tree.getNodeList(list.Declarations)) |declaration_index| {
        const declaration = tree.getNode(declaration_index).VariableDeclaration;
        const names: []const ast.NodeIndex = switch (tree.getNode(declaration.name)) {
            .Identifier => &.{declaration.name},
            .ObjectBindingPattern => |pattern| tree.getNodeList(pattern.Elements),
            else => continue,
        };
        for (names) |name_or_element| {
            const name_node = if (tree.getNode(name_or_element) == .BindingElement) tree.getNode(name_or_element).BindingElement.name orelse continue else name_or_element;
            if (tree.getNode(name_node) != .Identifier) continue;
            var collector = IdentifierUseCollector{ .name = @import("../ast/ast_utils.zig").getText(tree, name_node) };
            var node_visitor = visitor.NodeVisitor.init(allocator, tree, &collector, IdentifierUseCollector.visit, .{});
            for (tree.getNodeList(statements_index)) |statement| {
                const is_exported = @import("../ast/ast_utils.zig").hasSyntacticModifier(tree, statement, @import("../ast/ast_utils.zig").ModifierFlags.Export);
                const is_default = @import("../ast/ast_utils.zig").hasSyntacticModifier(tree, statement, @import("../ast/ast_utils.zig").ModifierFlags.Default);
                const kind = tree.getNodeKind(statement);
                if (is_exported or is_default or kind == .ExportDeclaration or kind == .ExportAssignment or isCommonJSExport(tree, statement)) {
                    _ = node_visitor.visitNode(statement);
                    if (collector.found) return true;
                }
            }
        }
    }
    return false;
}

fn isSymbolCall(tree: *ast.Ast, node: ast.NodeIndex) bool {
    if (node == 0 or tree.getNode(node) != .CallExpression) return false;
    const expression = tree.getNode(node).CallExpression.Expression;
    return tree.getNode(expression) == .Identifier and std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, expression), "Symbol");
}

fn constAssertionOperand(tree: *ast.Ast, node: ast.NodeIndex) ?ast.NodeIndex {
    return switch (tree.getNode(node)) {
        .SatisfiesExpression => |expression| constAssertionOperand(tree, expression.Expression),
        .ParenthesizedExpression => |expression| constAssertionOperand(tree, expression.Expression),
        .AsExpression => |expression| if (tree.getNode(expression.Type) == .TypeReference and
            tree.getNode(tree.getNode(expression.Type).TypeReference.TypeName) == .Identifier and
            std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, tree.getNode(expression.Type).TypeReference.TypeName), "const")) expression.Expression else null,
        else => null,
    };
}

fn isReadonlyType(tree: *ast.Ast, node: ast.NodeIndex) bool {
    if (node == 0) return false;
    switch (tree.getNode(node)) {
        .TypeOperator => |op| {
            const opKind = @as(@import("../ast/kind.zig").Kind, @enumFromInt(op.Operator));
            if (opKind == .ReadonlyKeyword) return true;
            return isReadonlyType(tree, op.Type);
        },
        .ParenthesizedType => |p| return isReadonlyType(tree, p.Type),
        else => return false,
    }
}

fn hasMutableConstraint(tree: *ast.Ast, node: ast.NodeIndex) bool {
    if (node == 0) return false;
    switch (tree.getNode(node)) {
        .ArrayType => return !isReadonlyType(tree, node),
        .TupleType => return !isReadonlyType(tree, node),
        .TypeLiteral => |lit| {
            for (tree.getNodeList(lit.Members)) |member| {
                switch (tree.getNode(member)) {
                    .PropertySignature => |prop| {
                        if (prop.Type) |t| if (hasMutableConstraint(tree, t)) return true;
                    },
                    else => {},
                }
            }
            return false;
        },
        .IntersectionType => |inter| {
            for (tree.getNodeList(inter.Types)) |t| if (hasMutableConstraint(tree, t)) return true;
            return false;
        },
        .UnionType => |uni| {
            for (tree.getNodeList(uni.Types)) |t| if (hasMutableConstraint(tree, t)) return true;
            return false;
        },
        .ParenthesizedType => |p| return hasMutableConstraint(tree, p.Type),
        .TypeOperator => |op| return hasMutableConstraint(tree, op.Type),
        else => return false,
    }
}

fn findConstGenericParameter(tree: *ast.Ast, callee: ast.NodeIndex) ?@import("../ast/ast_generated.zig").TypeParameterDeclarationNode {
    if (tree.getNode(callee) != .Identifier) return null;
    const callee_name = @import("../ast/ast_utils.zig").getText(tree, callee);
    var source = callee;
    while (tree.getNodeParent(source) != 0) source = tree.getNodeParent(source);
    if (tree.getNode(source) != .SourceFile) return null;
    for (tree.getNodeList(tree.getNode(source).SourceFile.Statements)) |statement| {
        if (tree.getNode(statement) != .FunctionDeclaration) continue;
        const function = tree.getNode(statement).FunctionDeclaration;
        const name = function.name orelse continue;
        if (!std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, name), callee_name)) continue;
        const parameters = function.TypeParameters orelse return null;
        for (tree.getNodeList(parameters)) |parameter_index| {
            const parameter = tree.getNode(parameter_index).TypeParameter;
            if (parameter.modifiers) |modifiers| {
                for (tree.getNodeList(modifiers)) |modifier| {
                    if (tree.getNodeKind(modifier) == .ConstKeyword) return parameter;
                }
            }
        }
    }
    return null;
}

fn isIdentityGenericCallee(tree: *ast.Ast, callee: ast.NodeIndex) bool {
    if (tree.getNode(callee) != .Identifier) return false;
    const name = @import("../ast/ast_utils.zig").getText(tree, callee);
    const source = sourceFileAncestor(tree, callee) orelse return false;
    for (tree.getNodeList(tree.getNode(source).SourceFile.Statements)) |statement| {
        if (!isIdentityHelperFunction(tree, statement)) continue;
        const function = tree.getNode(statement).FunctionDeclaration;
        if (function.name) |function_name| if (std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, function_name), name)) return true;
    }
    return false;
}

fn isIdentityHelperFunction(tree: *ast.Ast, statement: ast.NodeIndex) bool {
    if (tree.getNode(statement) != .FunctionDeclaration) return false;
    const function = tree.getNode(statement).FunctionDeclaration;
    const body = function.Body orelse return false;
    if (tree.getNode(body) != .Block or tree.getNodeList(tree.getNode(body).Block.Statements).len != 1) return false;
    const return_statement = tree.getNodeList(tree.getNode(body).Block.Statements)[0];
    if (tree.getNode(return_statement) != .ReturnStatement) return false;
    const expression = tree.getNode(return_statement).ReturnStatement.Expression orelse return false;
    if (tree.getNode(expression) != .Identifier) return false;
    const returned_name = @import("../ast/ast_utils.zig").getText(tree, expression);
    for (tree.getNodeList(function.Parameters)) |parameter_index| {
        const parameter = tree.getNode(parameter_index).Parameter;
        if (tree.getNode(parameter.name) == .Identifier and std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, parameter.name), returned_name)) return true;
    }
    return false;
}

fn sourceFileAncestor(tree: *ast.Ast, node: ast.NodeIndex) ?ast.NodeIndex {
    var current = node;
    while (current != 0) : (current = tree.getNodeParent(current)) if (tree.getNode(current) == .SourceFile) return current;
    return null;
}

fn findVariableInitializer(tree: *ast.Ast, identifier: ast.NodeIndex) ?ast.NodeIndex {
    if (tree.getNode(identifier) != .Identifier) return null;
    const name = @import("../ast/ast_utils.zig").getText(tree, identifier);
    const source = sourceFileAncestor(tree, identifier) orelse return null;
    for (tree.getNodeList(tree.getNode(source).SourceFile.Statements)) |statement| {
        if (tree.getNode(statement) != .VariableStatement) continue;
        const list = tree.getNode(tree.getNode(statement).VariableStatement.DeclarationList).VariableDeclarationList;
        for (tree.getNodeList(list.Declarations)) |declaration_index| {
            const declaration = tree.getNode(declaration_index).VariableDeclaration;
            if (tree.getNode(declaration.name) == .Identifier and std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, declaration.name), name)) return declaration.Initializer;
        }
    }
    return null;
}

fn normalizedPropertyName(tree: *ast.Ast, factory: anytype, name: ast.NodeIndex) ast.NodeIndex {
    if (tree.getNode(name) != .StringLiteral) return name;
    const text = @import("../ast/ast_utils.zig").getText(tree, name);
    if (text.len == 0 or !(std.ascii.isAlphabetic(text[0]) or text[0] == '_' or text[0] == '$')) return name;
    for (text[1..]) |character| if (!(std.ascii.isAlphanumeric(character) or character == '_' or character == '$')) return name;
    return factory.newIdentifier(text);
}

fn cloneForeignPropertyName(source_tree: *ast.Ast, factory: anytype, name: ast.NodeIndex) ast.NodeIndex {
    const text = @import("../ast/ast_utils.zig").getText(source_tree, name);
    return switch (source_tree.getNode(name)) {
        .Identifier => factory.newIdentifier(text),
        .StringLiteral => if (isIdentifierNameText(text)) factory.newIdentifier(text) else factory.newStringLiteral(text, false),
        .NumericLiteral => factory.newNumericLiteral(text, 0),
        else => factory.newIdentifier(text),
    };
}

fn parameterPropertyDeclarationModifiers(tree: *ast.Ast, factory: anytype, modifiers: ast.NodeIndex, allocator: std.mem.Allocator) ast.NodeIndex {
    if (modifiers == 0) return 0;
    var kept = std.ArrayListUnmanaged(ast.NodeIndex).empty;
    defer kept.deinit(allocator);
    for (tree.getNodeList(modifiers)) |modifier| {
        // `public` is the default declaration visibility and tsgo omits it.
        if (tree.getNodeKind(modifier) == .PublicKeyword) continue;
        kept.append(allocator, modifier) catch unreachable;
    }
    return if (kept.items.len == 0) 0 else factory.newModifierList(kept.items);
}

fn containsObjectLiteralThis(tree: *ast.Ast, node: ast.NodeIndex) bool {
    if (node == 0) return false;
    const ThisSearch = struct {
        fn check(t: *ast.Ast, child: ast.NodeIndex) bool {
            if (t.getNode(child) == .ThisKeyword) return true;
            return ast_utils.forEachChildBool(t, child, t, check);
        }
    };
    if (tree.getNode(node) == .ObjectLiteralExpression and ast_utils.forEachChildBool(tree, node, tree, ThisSearch.check)) return true;
    const Search = struct {
        fn check(t: *ast.Ast, child: ast.NodeIndex) bool {
            return containsObjectLiteralThis(t, child);
        }
    };
    return ast_utils.forEachChildBool(tree, node, tree, Search.check);
}

fn isIdentifierNameText(text: []const u8) bool {
    if (text.len == 0 or !(std.ascii.isAlphabetic(text[0]) or text[0] == '_' or text[0] == '$')) return false;
    for (text[1..]) |character| if (!(std.ascii.isAlphanumeric(character) or character == '_' or character == '$')) return false;
    return true;
}

fn typeContainsUndefined(tree: *ast.Ast, type_node: ast.NodeIndex) bool {
    if (type_node == 0) return false;
    const node = tree.getNode(type_node);
    switch (node) {
        .UndefinedKeyword => return true,
        .UnionType => |union_type| {
            for (tree.getNodeList(union_type.Types)) |t_idx| {
                if (typeContainsUndefined(tree, t_idx)) return true;
            }
        },
        else => {},
    }
    return false;
}

fn unwrapParenthesizedTypeNode(tree: *ast.Ast, type_node: ast.NodeIndex) ast.NodeIndex {
    var current = type_node;
    while (tree.getNode(current) == .ParenthesizedType) current = tree.getNode(current).ParenthesizedType.Type;
    return current;
}

fn inferredType(v: *visitor.NodeVisitor, factory: anytype, explicit_type: ast.NodeIndex, initializer: ast.NodeIndex) ast.NodeIndex {
    return inferredTypeInner(v.tree, factory, explicit_type, initializer, v);
}

fn assignmentSymbolTypeNode(tree: *ast.Ast, factory: anytype, declarations: []const ast.NodeIndex, include_undefined: bool) ast.NodeIndex {
    for (declarations) |declaration| {
        if (inlineJSDocType(tree, factory, declaration, factory.allocator)) |explicit| return explicit;
        const parent = tree.getNodeParent(declaration);
        if (parent != 0) if (inlineJSDocType(tree, factory, parent, factory.allocator)) |explicit| return explicit;
    }
    if (declarations.len == 1 and tree.getNode(declarations[0]) == .BinaryExpression) {
        const right = tree.getNode(declarations[0]).BinaryExpression.Right;
        if (tree.getNode(right) == .NewExpression) {
            const expression = tree.getNode(right).NewExpression.Expression;
            if (tree.getNode(expression) == .Identifier) return tree.pushNode(.{ .TypeReference = .{ .Flags = 0, .TypeArguments = null, .TypeName = expression } }) catch unreachable;
        }
        if (tree.getNode(right) == .Identifier) {
            const name = @import("../ast/ast_utils.zig").getText(tree, right);
            const param_type = findParameterTypeInAncestors(tree, factory, declarations[0], name);
            if (param_type != 0) return param_type;
        }
    }
    const Category = enum { number, string, boolean, bigint, object, function, undefined_, any };
    var categories: [8]bool = @splat(false);
    for (declarations) |declaration| {
        if (tree.getNode(declaration) != .BinaryExpression) continue;
        const right = tree.getNode(declaration).BinaryExpression.Right;
        const category: Category = switch (tree.getNode(right)) {
            .NumericLiteral, .PrefixUnaryExpression, .PostfixUnaryExpression => .number,
            .StringLiteral, .NoSubstitutionTemplateLiteral, .TemplateExpression => .string,
            .TrueKeyword, .FalseKeyword => .boolean,
            .BigIntLiteral => .bigint,
            .ObjectLiteralExpression, .ArrayLiteralExpression, .ClassExpression, .NewExpression => .object,
            .ArrowFunction, .FunctionExpression => .function,
            .UndefinedKeyword => .undefined_,
            else => .any,
        };
        categories[@intFromEnum(category)] = true;
    }
    if (include_undefined) categories[@intFromEnum(Category.undefined_)] = true;

    var type_nodes: [8]ast.NodeIndex = undefined;
    var count: usize = 0;
    for (0..categories.len) |index| {
        if (!categories[index]) continue;
        const category: Category = @enumFromInt(index);
        type_nodes[count] = factory.newToken(switch (category) {
            .number => .{ .NumberKeyword = {} },
            .string => .{ .StringKeyword = {} },
            .boolean => .{ .BooleanKeyword = {} },
            .bigint => .{ .BigIntKeyword = {} },
            .object => .{ .ObjectKeyword = {} },
            .undefined_ => .{ .UndefinedKeyword = {} },
            .any, .function => .{ .AnyKeyword = {} },
        });
        count += 1;
    }
    if (count == 0) return factory.newToken(.{ .AnyKeyword = {} });
    if (count == 1) return type_nodes[0];
    const list = factory.tree.pushNodeList(type_nodes[0..count]) catch unreachable;
    return factory.tree.pushNode(.{ .UnionType = .{ .Flags = 0, .Types = list } }) catch unreachable;
}

fn commonJSAssignmentTypeNode(tree: *ast.Ast, factory: anytype, declarations: []const ast.NodeIndex, allocator: std.mem.Allocator) ast.NodeIndex {
    for (declarations) |declaration| {
        if (inlineJSDocType(tree, factory, declaration, allocator)) |explicit| return explicit;
        const parent = tree.getNodeParent(declaration);
        if (parent != 0) if (inlineJSDocType(tree, factory, parent, allocator)) |explicit| return explicit;
    }
    const Category = enum { string, number, bigint, true_, false_ };
    var literals = std.ArrayListUnmanaged(struct { category: Category, expression: ast.NodeIndex }).empty;
    defer literals.deinit(allocator);
    for (declarations) |declaration| {
        if (tree.getNode(declaration) != .BinaryExpression) continue;
        const expression = tree.getNode(declaration).BinaryExpression.Right;
        const category: Category = switch (tree.getNode(expression)) {
            .StringLiteral, .NoSubstitutionTemplateLiteral => .string,
            .NumericLiteral, .PrefixUnaryExpression => .number,
            .BigIntLiteral => .bigint,
            .TrueKeyword => .true_,
            .FalseKeyword => .false_,
            else => return factory.newToken(.{ .AnyKeyword = {} }),
        };
        literals.append(allocator, .{ .category = category, .expression = expression }) catch unreachable;
    }
    if (literals.items.len == 0) return factory.newToken(.{ .AnyKeyword = {} });
    std.mem.sort(@TypeOf(literals.items[0]), literals.items, {}, struct {
        fn lessThan(_: void, a: @TypeOf(literals.items[0]), b: @TypeOf(literals.items[0])) bool {
            return @intFromEnum(a.category) < @intFromEnum(b.category);
        }
    }.lessThan);
    var nodes = std.ArrayListUnmanaged(ast.NodeIndex).empty;
    defer nodes.deinit(allocator);
    for (literals.items) |literal| {
        nodes.append(allocator, tree.pushNode(.{ .LiteralType = .{ .Flags = 0, .Literal = literal.expression } }) catch unreachable) catch unreachable;
    }
    if (nodes.items.len == 1) return nodes.items[0];
    return tree.pushNode(.{ .UnionType = .{ .Flags = 0, .Types = factory.newNodeList(nodes.items) } }) catch unreachable;
}

fn isStaticClassAssignment(tree: *ast.Ast, declaration: ast.NodeIndex, class_node: ast.NodeIndex) bool {
    const utils = @import("../ast/ast_utils.zig");
    var current = tree.getNodeParent(declaration);
    while (current != 0 and current != class_node) : (current = tree.getNodeParent(current)) {
        switch (tree.getNode(current)) {
            .ClassStaticBlockDeclaration => return true,
            .MethodDeclaration, .GetAccessor, .SetAccessor, .PropertyDeclaration => return utils.hasSyntacticModifier(tree, current, utils.ModifierFlags.Static),
            else => {},
        }
    }
    return false;
}

fn declarationFunctionParameters(tree: *ast.Ast, factory: anytype, parameters_index: ast.NodeIndex) ast.NodeIndex {
    const parameters = tree.getNodeList(parameters_index);
    var updated = std.ArrayListUnmanaged(ast.NodeIndex).empty;
    defer updated.deinit(factory.allocator);
    for (parameters, 0..) |parameter_index, index| {
        const parameter = tree.getNode(parameter_index).Parameter;
        var type_node = parameter.Type orelse 0;
        if (type_node == 0) {
            const function_index = tree.getNodeParent(parameter_index);
            type_node = jsdocParameterType(tree, factory, function_index, parameter.name, index, factory.allocator) orelse 0;
            if (type_node == 0) {
                var curr = function_index;
                while (curr != 0) {
                    const kind_val = tree.getNodeKind(curr);
                    if (kind_val == .VariableStatement) {
                        type_node = jsdocParameterType(tree, factory, curr, parameter.name, index, factory.allocator) orelse 0;
                        if (type_node != 0) break;
                    }
                    curr = tree.getNodeParent(curr);
                }
            }
        }
        if (type_node == 0 and parameter.Initializer != null and tree.getNode(parameter.Initializer.?) == .Identifier) {
            type_node = findParameterTypeInAncestors(tree, factory, tree.getNodeParent(parameter_index), @import("../ast/ast_utils.zig").getText(tree, parameter.Initializer.?));
        }
        if (type_node == 0) type_node = inferredTypeInner(tree, factory, 0, parameter.Initializer orelse 0, null);
        var question = parameter.QuestionToken orelse 0;
        if (parameter.Initializer != null) {
            var subsequent_optional = true;
            for (parameters[index + 1 ..]) |subsequent_index| {
                const subsequent = tree.getNode(subsequent_index).Parameter;
                if (subsequent.Initializer == null and subsequent.QuestionToken == null and subsequent.DotDotDotToken == null) {
                    subsequent_optional = false;
                    break;
                }
            }
            if (subsequent_optional) {
                if (question == 0) question = tree.pushNode(.{ .QuestionToken = {} }) catch unreachable;
            } else if (!typeContainsUndefined(tree, type_node)) {
                type_node = unwrapParenthesizedTypeNode(tree, type_node);
                const undefined_type = factory.newToken(.{ .UndefinedKeyword = {} });
                type_node = tree.pushNode(.{ .UnionType = .{ .Flags = 0, .Types = factory.newNodeList(&.{ type_node, undefined_type }) } }) catch unreachable;
            }
        }
        updated.append(factory.allocator, factory.updateParameterDeclaration(parameter_index, parameter, parameter.modifiers orelse 0, parameter.DotDotDotToken orelse 0, parameter.name, question, type_node, 0)) catch unreachable;
    }
    return factory.newNodeList(updated.items);
}

fn findParameterTypeInAncestors(tree: *ast.Ast, factory: anytype, start: ast.NodeIndex, name: []const u8) ast.NodeIndex {
    var current = start;
    while (current != 0) : (current = tree.getNodeParent(current)) {
        const parameters_index: ast.NodeIndex = switch (tree.getNode(current)) {
            .FunctionDeclaration => |node| node.Parameters,
            .FunctionExpression => |node| node.Parameters,
            .ArrowFunction => |node| node.Parameters,
            .MethodDeclaration => |node| node.Parameters,
            .Constructor => |node| node.Parameters,
            else => 0,
        };
        if (parameters_index == 0) continue;
        for (tree.getNodeList(parameters_index), 0..) |parameter_index, index| {
            const parameter = tree.getNode(parameter_index).Parameter;
            if (tree.getNode(parameter.name) == .Identifier and std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, parameter.name), name)) {
                if (parameter.Type) |type_node| {
                    return type_node;
                }
                const jsdoc_type = inlineJSDocType(tree, factory, parameter_index, factory.allocator) orelse jsdocParameterType(tree, factory, current, parameter.name, index, factory.allocator);
                if (jsdoc_type != null and jsdoc_type.? != 0) {
                    return jsdoc_type.?;
                }
                if (parameter.Initializer) |initializer| if (tree.getNode(initializer) == .Identifier) {
                    return findParameterTypeInAncestors(tree, factory, tree.getNodeParent(current), @import("../ast/ast_utils.zig").getText(tree, initializer));
                };
                return 0;
            }
        }
    }
    return 0;
}

fn classHasDeclaredMemberName(tree: *ast.Ast, class_node: ast.NodeIndex, name: []const u8, is_static: bool) bool {
    const utils = @import("../ast/ast_utils.zig");
    const members = switch (tree.getNode(class_node)) {
        .ClassDeclaration => |class| tree.getNodeList(class.Members),
        .ClassExpression => |class| tree.getNodeList(class.Members),
        else => return false,
    };
    for (members) |member| {
        const member_name: ?ast.NodeIndex = switch (tree.getNode(member)) {
            .PropertyDeclaration => |declaration| declaration.name,
            .MethodDeclaration => |declaration| declaration.name,
            .GetAccessor => |declaration| declaration.name,
            .SetAccessor => |declaration| declaration.name,
            else => null,
        };
        if (member_name) |name_node| {
            const member_is_static = utils.hasSyntacticModifier(tree, member, utils.ModifierFlags.Static);
            if (member_is_static == is_static and tree.getNode(name_node) == .Identifier and std.mem.eql(u8, utils.getText(tree, name_node), name)) return true;
        }
    }
    return false;
}

fn inferredTypeInner(tree: *ast.Ast, factory: anytype, explicit_type: ast.NodeIndex, initializer: ast.NodeIndex, visitor_opt: ?*visitor.NodeVisitor) ast.NodeIndex {
    if (explicit_type != 0) return explicit_type;
    if (tree.getNode(initializer) == .NewExpression) {
        const expression = tree.getNode(initializer).NewExpression.Expression;
        if (tree.getNode(expression) == .Identifier) return factory.tree.pushNode(.{ .TypeReference = .{ .Flags = 0, .TypeArguments = null, .TypeName = expression } }) catch unreachable;
    }
    if (tree.getNode(initializer) == .PropertyAccessExpression) {
        if (visitor_opt) |v| {
            const self: *DeclarationTransformer = @ptrCast(@alignCast(v.ctx.?));
            const pae = tree.getNode(initializer).PropertyAccessExpression;
            if (tree.getNode(pae.Expression) == .Identifier) {
                const obj_name = @import("../ast/ast_utils.zig").getText(tree, pae.Expression);
                var target_decl: ast.NodeIndex = 0;
                var target_tree = tree;
                if (self.semantic_program != null and self.semantic_file != null) {
                    if (self.semantic_program.?.resolveAlias(self.semantic_file.?, obj_name)) |symbol| {
                        target_decl = symbol.declaration;
                        target_tree = self.semantic_program.?.getUnit(symbol.declaration_file).tree();
                    } else if (self.semantic_binder) |bound| {
                        target_decl = self.findDeclarationInFile(tree, bound, obj_name);
                    }
                }
                if (target_decl != 0 and target_tree.getNode(target_decl) == .VariableDeclaration) {
                    const vd = target_tree.getNode(target_decl).VariableDeclaration;
                    if (vd.Type) |t| {
                        if (target_tree.getNode(t) == .TypeLiteral) {
                            const members = target_tree.getNodeList(target_tree.getNode(t).TypeLiteral.Members);
                            const prop_name = @import("../ast/ast_utils.zig").getText(tree, pae.name);
                            for (members) |member| {
                                if (target_tree.getNode(member) == .PropertySignature) {
                                    const ps = target_tree.getNode(member).PropertySignature;
                                    if (std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(target_tree, ps.name), prop_name)) {
                                        if (ps.Type) |prop_type| {
                                            return self.copyForeignTypeNode(target_tree, prop_type, &.{});
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else if (target_decl != 0 and target_tree.getNode(target_decl) == .ClassDeclaration) {
                    const class_decl = target_tree.getNode(target_decl).ClassDeclaration;
                    if (class_decl.Members != 0) {
                        const members = target_tree.getNodeList(class_decl.Members);
                        const prop_name = @import("../ast/ast_utils.zig").getText(tree, pae.name);
                        for (members) |member| {
                            if (target_tree.getNode(member) == .PropertyDeclaration) {
                                const pd = target_tree.getNode(member).PropertyDeclaration;
                                if (pd.modifiers != null and (@import("../ast/ast_utils.zig").getModifierFlags(target_tree, member) & @import("../ast/ast_utils.zig").ModifierFlags.Static) != 0) {
                                    if (std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(target_tree, pd.name), prop_name)) {
                                        if (pd.Type) |prop_type| {
                                            return self.copyForeignTypeNode(target_tree, prop_type, &.{});
                                        } else if (pd.Initializer) |init| {
                                            return inferredTypeInner(target_tree, factory, 0, init, visitor_opt);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if (tree.getNode(initializer) == .ArrowFunction) {
        const arrow = tree.getNode(initializer).ArrowFunction;
        const params = declarationFunctionParameters(tree, factory, arrow.Parameters);
        return factory.tree.pushNode(.{ .FunctionType = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = null,
            .modifierFlags = 0,
            .TypeParameters = arrow.TypeParameters orelse 0,
            .Parameters = params,
            .Type = arrow.Type orelse inferArrowReturnType(tree, factory, arrow.Body orelse 0, visitor_opt),
            .FullSignature = null,
        } }) catch unreachable;
    }
    if (tree.getNode(initializer) == .FunctionExpression) {
        const func = tree.getNode(initializer).FunctionExpression;
        const params = declarationFunctionParameters(tree, factory, func.Parameters);
        return factory.tree.pushNode(.{ .FunctionType = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = null,
            .modifierFlags = 0,
            .TypeParameters = func.TypeParameters orelse 0,
            .Parameters = params,
            .Type = func.Type orelse inferFunctionReturnType(tree, factory, func.Body orelse 0, visitor_opt),
            .FullSignature = null,
        } }) catch unreachable;
    }
    return factory.newToken(switch (tree.getNode(initializer)) {
        .StringLiteral, .NoSubstitutionTemplateLiteral => .{ .StringKeyword = {} },
        .NumericLiteral => .{ .NumberKeyword = {} },
        .TrueKeyword, .FalseKeyword => .{ .BooleanKeyword = {} },
        .NullKeyword => .{ .NullKeyword = {} },
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

fn collectTypeParametersFromJSDoc(tree: *ast.Ast, factory: anytype, jsdoc_node: ast.NodeIndex, output: *std.ArrayListUnmanaged(ast.NodeIndex), allocator: std.mem.Allocator) void {
    const t = tree.getNode(jsdoc_node).JSDoc.Tags orelse return;
    const original_tags = tree.getNodeList(t);
    const tags = allocator.alloc(ast.NodeIndex, original_tags.len) catch unreachable;
    defer allocator.free(tags);
    @memcpy(tags, original_tags);

    for (tags) |tag_index| {
        if (tree.getNode(tag_index) == .JSDocTemplateTag) {
            const tag = tree.getNode(tag_index).JSDocTemplateTag;
            const constraint = if (tag.Constraint != 0) unwrapJSDocTypeExpression(tree, factory, tag.Constraint, allocator) else 0;

            const original_tps = tree.getNodeList(tag.TypeParameters);
            const tps = allocator.alloc(ast.NodeIndex, original_tps.len) catch unreachable;
            defer allocator.free(tps);
            @memcpy(tps, original_tps);

            for (tps) |parameter_index| {
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
        }
    }
}

fn transformJSDocTypeLiteral(tree: *ast.Ast, factory: anytype, literal_idx: ast.NodeIndex, allocator: std.mem.Allocator) ast.NodeIndex {
    const literal = tree.getNode(literal_idx).JSDocTypeLiteral;
    var members = std.ArrayListUnmanaged(ast.NodeIndex).empty;
    defer members.deinit(allocator);
    if (literal.JSDocPropertyTags) |tags_idx| {
        const original_tags = tree.getNodeList(tags_idx);
        const tags = allocator.alloc(ast.NodeIndex, original_tags.len) catch unreachable;
        defer allocator.free(tags);
        @memcpy(tags, original_tags);

        for (tags) |tag_idx| {
            const tag_node = tree.getNode(tag_idx);
            var opt_tag: ?@import("../ast/ast_generated.zig").JSDocParameterOrPropertyTagNode = null;
            switch (tag_node) {
                .JSDocPropertyTag => |tag| opt_tag = tag,
                .JSDocParameterTag => |tag| opt_tag = tag,
                else => {},
            }
            if (opt_tag) |tag| {
                const prop_type = if (tag.TypeExpression != null)
                    unwrapJSDocTypeExpression(tree, factory, tag.TypeExpression.?, allocator)
                else
                    factory.newToken(.{ .AnyKeyword = {} });
                var prop_name = tag.name;
                while (tree.getNode(prop_name) == .QualifiedName) {
                    prop_name = tree.getNode(prop_name).QualifiedName.Right;
                }
                if (tree.getNode(prop_name) == .Identifier) {
                    const text = @import("../ast/ast_utils.zig").getText(tree, prop_name);
                    if (!isSimpleIdentifierText(text)) {
                        prop_name = tree.pushNode(.{ .StringLiteral = .{
                            .Flags = 0,
                            .TokenFlags = 0,
                            .Text = text,
                        } }) catch unreachable;
                    }
                }
                const prop_sig = tree.pushNode(.{ .PropertySignature = .{
                    .Symbol = 0,
                    .Flags = 0,
                    .modifiers = null,
                    .modifierFlags = 0,
                    .name = prop_name,
                    .PostfixToken = if (tag.IsBracketed != 0) factory.newToken(.{ .QuestionToken = {} }) else null,
                    .Type = prop_type,
                    .Initializer = 0,
                } }) catch unreachable;
                members.append(allocator, prop_sig) catch unreachable;
            }
        }
    }
    const members_list = factory.newNodeList(members.items);
    return tree.pushNode(.{ .TypeLiteral = .{
        .Flags = 0,
        .Symbol = 0,
        .Members = members_list,
    } }) catch unreachable;
}

fn isSimpleIdentifierText(text: []const u8) bool {
    if (text.len == 0) return false;
    const first = text[0];
    if (!((first >= 'a' and first <= 'z') or (first >= 'A' and first <= 'Z') or first == '_' or first == '$')) return false;
    for (text[1..]) |ch| {
        if (!((ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or (ch >= '0' and ch <= '9') or ch == '_' or ch == '$')) return false;
    }
    return true;
}

fn jsdocAugmentsClassName(tree: *ast.Ast, node: ast.NodeIndex) ?ast.NodeIndex {
    for (@import("../ast/ast_utils.zig").getJSDoc(tree, node)) |doc_index| {
        const tags = tree.getNode(doc_index).JSDoc.Tags orelse continue;
        for (tree.getNodeList(tags)) |tag_index| if (tree.getNode(tag_index) == .JSDocAugmentsTag) return tree.getNode(tag_index).JSDocAugmentsTag.ClassName;
    }
    return null;
}

fn firstReturnExpression(tree: *ast.Ast, body: ast.NodeIndex) ?ast.NodeIndex {
    if (body == 0 or tree.getNode(body) != .Block) return null;
    for (tree.getNodeList(tree.getNode(body).Block.Statements)) |statement| {
        if (tree.getNode(statement) == .ReturnStatement) return tree.getNode(statement).ReturnStatement.Expression;
    }
    return null;
}

fn needsScopeMarker(tree: *ast.Ast, node: ast.NodeIndex) bool {
    const kind_val = tree.getNode(node);
    if (kind_val == .SyntaxList) {
        for (tree.getNodeList(node)) |child| {
            if (needsScopeMarker(tree, child)) return true;
        }
        return false;
    }
    const is_import_or_reexport = kind_val == .ImportDeclaration or kind_val == .ImportEqualsDeclaration or kind_val == .ExportDeclaration;
    const is_export_assignment = kind_val == .ExportAssignment;
    const has_export = @import("../ast/ast_utils.zig").hasSyntacticModifier(tree, node, @import("../ast/ast_utils.zig").ModifierFlags.Export);
    const is_ambient_module = kind_val == .ModuleDeclaration and (tree.getNode(node).ModuleDeclaration.Keyword == @intFromEnum(@import("../ast/kind.zig").Kind.NamespaceKeyword) or @import("../ast/ast_utils.zig").hasSyntacticModifier(tree, node, @import("../ast/ast_utils.zig").ModifierFlags.Ambient));
    return !is_import_or_reexport and !is_export_assignment and !has_export and !is_ambient_module;
}

fn unwrapJSDocTypeExpression(tree: *ast.Ast, factory: anytype, node: ast.NodeIndex, allocator: std.mem.Allocator) ast.NodeIndex {
    const unwrapped = if (tree.getNode(node) == .JSDocTypeExpression) tree.getNode(node).JSDocTypeExpression.Type else node;
    return unwrapJSDocTypeInner(tree, factory, unwrapped, allocator);
}

fn transformJSDocSignature(tree: *ast.Ast, factory: anytype, sig_idx: ast.NodeIndex, allocator: std.mem.Allocator) ast.NodeIndex {
    const sig = tree.getNode(sig_idx).JSDocSignature;
    var copied_params = std.ArrayListUnmanaged(ast.NodeIndex).empty;
    defer copied_params.deinit(allocator);

    const original_params = tree.getNodeList(sig.Parameters);
    const params = allocator.alloc(ast.NodeIndex, original_params.len) catch unreachable;
    defer allocator.free(params);
    @memcpy(params, original_params);

    for (params) |param| {
        const param_node = tree.getNode(param);
        if (param_node == .JSDocParameterTag) {
            copied_params.append(allocator, parameterFromJSDocTag(tree, factory, param_node.JSDocParameterTag, allocator)) catch unreachable;
        } else if (param_node == .Parameter) {
            const p = param_node.Parameter;
            const copied = tree.pushNode(.{ .Parameter = .{
                .Flags = 0,
                .Symbol = 0,
                .modifiers = null,
                .modifierFlags = 0,
                .DotDotDotToken = p.DotDotDotToken,
                .name = p.name,
                .QuestionToken = p.QuestionToken,
                .Type = if (p.Type) |t| unwrapJSDocTypeExpression(tree, factory, t, allocator) else 0,
                .Initializer = null,
            } }) catch unreachable;
            copied_params.append(allocator, copied) catch unreachable;
        }
    }
    var type_params: ?ast.NodeIndex = null;
    if (sig.TypeParameters) |tp_list_idx| {
        var copied_tps = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer copied_tps.deinit(allocator);

        const original_tps = tree.getNodeList(tp_list_idx);
        const tps = allocator.alloc(ast.NodeIndex, original_tps.len) catch unreachable;
        defer allocator.free(tps);
        @memcpy(tps, original_tps);

        for (tps) |tp| {
            const tp_node = tree.getNode(tp).TypeParameter;
            const copied = tree.pushNode(.{ .TypeParameter = .{
                .Flags = 0,
                .Symbol = 0,
                .modifiers = null,
                .modifierFlags = 0,
                .name = tp_node.name,
                .Constraint = if (tp_node.Constraint) |c| unwrapJSDocTypeInner(tree, factory, c, allocator) else 0,
                .Expression = null,
                .DefaultType = if (tp_node.DefaultType) |d| unwrapJSDocTypeInner(tree, factory, d, allocator) else 0,
            } }) catch unreachable;
            copied_tps.append(allocator, copied) catch unreachable;
        }
        type_params = factory.newNodeList(copied_tps.items);
    }
    const return_type = if (sig.Type) |t| blk: {
        const t_node = tree.getNode(t);
        if (t_node == .JSDocReturnTag) {
            if (t_node.JSDocReturnTag.TypeExpression) |te| {
                break :blk unwrapJSDocTypeExpression(tree, factory, te, allocator);
            }
        }
        break :blk unwrapJSDocTypeExpression(tree, factory, t, allocator);
    } else factory.newToken(.{ .AnyKeyword = {} });
    return tree.pushNode(.{ .FunctionType = .{
        .Flags = 0,
        .modifiers = null,
        .modifierFlags = 0,
        .Symbol = 0,
        .TypeParameters = type_params,
        .Parameters = factory.newNodeList(copied_params.items),
        .Type = return_type,
        .FullSignature = null,
    } }) catch unreachable;
}

fn unwrapJSDocTypeInner(tree: *ast.Ast, factory: anytype, node: ast.NodeIndex, allocator: std.mem.Allocator) ast.NodeIndex {
    const node_val = tree.getNode(node);
    switch (node_val) {
        .JSDocSignature => return transformJSDocSignature(tree, factory, node, allocator),
        .JSDocTypeLiteral => return transformJSDocTypeLiteral(tree, factory, node, allocator),
        .FunctionType => |ft| {
            var copied_params = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            defer copied_params.deinit(allocator);

            const original_params = tree.getNodeList(ft.Parameters);
            const params = allocator.alloc(ast.NodeIndex, original_params.len) catch unreachable;
            defer allocator.free(params);
            @memcpy(params, original_params);

            for (params) |param| {
                const p = tree.getNode(param).Parameter;
                const unwrapped_type = if (p.Type != 0) unwrapJSDocTypeExpression(tree, factory, p.Type.?, allocator) else 0;

                var p_name = p.name;
                const name_text = @import("../ast/ast_utils.zig").getText(tree, p.name);
                if (std.mem.containsAtLeast(u8, name_text, 1, "-")) {
                    const replaced_text = allocator.alloc(u8, name_text.len) catch unreachable;
                    @memcpy(replaced_text, name_text);
                    for (replaced_text) |*char| {
                        if (char.* == '-') char.* = '_';
                    }
                    const new_name = tree.pushNode(.{ .Identifier = .{ .Flags = @import("../ast/ast_utils.zig").NodeFlags.Synthesized, .Text = replaced_text } }) catch unreachable;
                    p_name = new_name;
                }

                const copied = tree.pushNode(.{ .Parameter = .{
                    .Flags = 0,
                    .Symbol = 0,
                    .modifiers = null,
                    .modifierFlags = 0,
                    .DotDotDotToken = p.DotDotDotToken,
                    .name = p_name,
                    .QuestionToken = p.QuestionToken,
                    .Type = unwrapped_type,
                    .Initializer = null,
                } }) catch unreachable;
                copied_params.append(allocator, copied) catch unreachable;
            }

            const return_type = if (ft.Type) |t| unwrapJSDocTypeExpression(tree, factory, t, allocator) else factory.newToken(.{ .AnyKeyword = {} });

            return tree.pushNode(.{ .FunctionType = .{
                .Flags = 0,
                .modifiers = null,
                .modifierFlags = 0,
                .Symbol = 0,
                .TypeParameters = ft.TypeParameters,
                .Parameters = factory.newNodeList(copied_params.items),
                .Type = return_type,
                .FullSignature = null,
            } }) catch unreachable;
        },
        // !T -> strip `!` to inner T (non-nullable); standalone `!` (Unknown) -> any
        .JSDocNonNullableType => |t| {
            if (tree.getNode(t.Type) == .Unknown) return factory.newToken(.{ .AnyKeyword = {} });
            return unwrapJSDocTypeInner(tree, factory, t.Type, allocator);
        },
        // ?T nullable -> T | null; standalone `?` (Unknown inner) -> any | null
        .JSDocNullableType => |t| {
            const inner = t.Type;
            const inner_unwrapped = if (tree.getNode(inner) == .Unknown)
                factory.newToken(.{ .AnyKeyword = {} })
            else
                unwrapJSDocTypeInner(tree, factory, inner, allocator);
            const null_type = tree.pushNode(.{ .LiteralType = .{ .Flags = 0, .Literal = factory.newToken(.{ .NullKeyword = {} }) } }) catch unreachable;
            return tree.pushNode(.{ .UnionType = .{ .Flags = 0, .Types = factory.newNodeList(&.{ inner_unwrapped, null_type }) } }) catch unreachable;
        },
        // * -> any
        .JSDocAllType => return factory.newToken(.{ .AnyKeyword = {} }),
        // [T=] optional JSDoc -> T | undefined
        .JSDocOptionalType => |t| {
            const inner_unwrapped = unwrapJSDocTypeInner(tree, factory, t.Type, allocator);
            const undef_type = factory.newToken(.{ .UndefinedKeyword = {} });
            return tree.pushNode(.{ .UnionType = .{ .Flags = 0, .Types = factory.newNodeList(&.{ inner_unwrapped, undef_type }) } }) catch unreachable;
        },
        // ...T variadic -> T[]
        .JSDocVariadicType => |t| {
            const elem_type = unwrapJSDocTypeInner(tree, factory, t.Type, allocator);
            return tree.pushNode(.{ .ArrayType = .{ .Flags = 0, .ElementType = elem_type } }) catch unreachable;
        },
        .UnionType => |u| {
            // Recursively unwrap all members
            const original_members = tree.getNodeList(u.Types);
            const members = allocator.alloc(ast.NodeIndex, original_members.len) catch unreachable;
            defer allocator.free(members);
            @memcpy(members, original_members);

            var any_changed = false;
            var new_members = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            defer new_members.deinit(allocator);
            for (members) |m| {
                var unwrapped_m = unwrapJSDocTypeInner(tree, factory, m, allocator);
                if (unwrapped_m != m) {
                    any_changed = true;
                    // JSDoc prefix types form a syntactic group.  Preserve that
                    // boundary when lowering ?T/!T inside a union; otherwise a
                    // generated nested union is flattened by normal precedence
                    // printing and the declaration differs from tsgo.
                    const unwrapped_kind = tree.getNode(unwrapped_m);
                    if (unwrapped_kind == .UnionType or unwrapped_kind == .IntersectionType) {
                        unwrapped_m = tree.pushNode(.{ .ParenthesizedType = .{
                            .Flags = 0,
                            .Type = unwrapped_m,
                        } }) catch unreachable;
                    }
                }
                new_members.append(allocator, unwrapped_m) catch unreachable;
            }
            if (!any_changed) return node;
            return tree.pushNode(.{ .UnionType = .{ .Flags = 0, .Types = factory.newNodeList(new_members.items) } }) catch unreachable;
        },
        .IntersectionType => |u| {
            const original_members = tree.getNodeList(u.Types);
            const members = allocator.alloc(ast.NodeIndex, original_members.len) catch unreachable;
            defer allocator.free(members);
            @memcpy(members, original_members);

            var any_changed = false;
            var new_members = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            defer new_members.deinit(allocator);
            for (members) |m| {
                const unwrapped_m = unwrapJSDocTypeInner(tree, factory, m, allocator);
                if (unwrapped_m != m) any_changed = true;
                new_members.append(allocator, unwrapped_m) catch unreachable;
            }
            if (!any_changed) return node;
            return tree.pushNode(.{ .IntersectionType = .{ .Flags = 0, .Types = factory.newNodeList(new_members.items) } }) catch unreachable;
        },
        .TypeOperator => |op| {
            const inner = unwrapJSDocTypeInner(tree, factory, op.Type, allocator);
            if (inner == op.Type) return node;
            return tree.pushNode(.{ .TypeOperator = .{
                .Flags = op.Flags,
                .Operator = op.Operator,
                .Type = inner,
            } }) catch unreachable;
        },
        .ArrayType => |arr| {
            const inner = unwrapJSDocTypeInner(tree, factory, arr.ElementType, allocator);
            if (inner == arr.ElementType) return node;
            return tree.pushNode(.{ .ArrayType = .{
                .Flags = arr.Flags,
                .ElementType = inner,
            } }) catch unreachable;
        },
        .ParenthesizedType => |p| {
            const inner = unwrapJSDocTypeInner(tree, factory, p.Type, allocator);
            if (inner == p.Type) return node;
            return tree.pushNode(.{ .ParenthesizedType = .{
                .Flags = p.Flags,
                .Type = inner,
            } }) catch unreachable;
        },
        .TupleType => |t| {
            const members = tree.getNodeList(t.Elements);
            var any_changed = false;
            var new_members = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            defer new_members.deinit(allocator);
            for (members) |m| {
                const unwrapped_m = unwrapJSDocTypeInner(tree, factory, m, allocator);
                if (unwrapped_m != m) any_changed = true;
                new_members.append(allocator, unwrapped_m) catch unreachable;
            }
            return tree.pushNode(.{ .TupleType = .{
                .Flags = t.Flags | @import("../ast/ast_utils.zig").NodeFlags.Synthesized,
                .Elements = factory.newNodeList(new_members.items),
            } }) catch unreachable;
        },
        .TypeReference => |tr| {
            if (tr.TypeArguments) |args_idx| {
                const args = tree.getNodeList(args_idx);
                var any_changed = false;
                var new_args = std.ArrayListUnmanaged(ast.NodeIndex).empty;
                defer new_args.deinit(allocator);
                for (args) |arg| {
                    const unwrapped_arg = unwrapJSDocTypeInner(tree, factory, arg, allocator);
                    if (unwrapped_arg != arg) any_changed = true;
                    new_args.append(allocator, unwrapped_arg) catch unreachable;
                }
                if (!any_changed) return node;
                return tree.pushNode(.{ .TypeReference = .{
                    .Flags = tr.Flags,
                    .TypeName = tr.TypeName,
                    .TypeArguments = factory.newNodeList(new_args.items),
                } }) catch unreachable;
            }
            return node;
        },
        else => return node,
    }
}

fn parameterFromJSDocTag(tree: *ast.Ast, factory: anytype, tag: ast_gen.JSDocParameterOrPropertyTagNode, allocator: std.mem.Allocator) ast.NodeIndex {
    var rest_token: ast.NodeIndex = 0;
    var question_token: ast.NodeIndex = if (tag.IsBracketed != 0) factory.newToken(.{ .QuestionToken = {} }) else 0;

    var inner_type: ast.NodeIndex = 0;
    if (tag.TypeExpression) |expression| {
        inner_type = if (tree.getNode(expression) == .JSDocTypeExpression) tree.getNode(expression).JSDocTypeExpression.Type else expression;
        if (tree.getNode(inner_type) == .JSDocVariadicType) {
            rest_token = factory.newToken(.{ .DotDotDotToken = {} });
            inner_type = tree.getNode(inner_type).JSDocVariadicType.Type;
        }
        if (tree.getNode(inner_type) == .JSDocOptionalType) {
            question_token = factory.newToken(.{ .QuestionToken = {} });
            inner_type = tree.getNode(inner_type).JSDocOptionalType.Type;
        }
    }

    const type_node = if (inner_type != 0) unwrapJSDocTypeInner(tree, factory, inner_type, allocator) else factory.newToken(.{ .AnyKeyword = {} });
    markJSDocTuplesSynthetic(tree, type_node);
    var name_node = tag.name;
    if (tree.getNode(name_node) == .Identifier) {
        const text = @import("../ast/ast_utils.zig").getText(tree, name_node);
        if (std.mem.indexOfScalar(u8, text, '-') != null) {
            const buf = allocator.alloc(u8, text.len) catch unreachable;
            for (text, 0..) |c, idx| {
                buf[idx] = if (c == '-') '_' else c;
            }
            name_node = factory.newIdentifier(buf);
        }
    }

    return tree.pushNode(.{ .Parameter = .{
        .Flags = 0,
        .Symbol = 0,
        .modifiers = null,
        .modifierFlags = 0,
        .DotDotDotToken = if (rest_token != 0) rest_token else null,
        .name = name_node,
        .QuestionToken = if (question_token != 0) question_token else null,
        .Type = type_node,
        .Initializer = null,
    } }) catch unreachable;
}

fn applicableJSDocFunctionType(tree: *ast.Ast, factory: anytype, function_index: ast.NodeIndex, allocator: std.mem.Allocator) ?ast.NodeIndex {
    const function = tree.getNode(function_index).FunctionDeclaration;
    for (tree.getNodeList(function.Parameters)) |parameter| if (inlineJSDocType(tree, factory, parameter, allocator) != null) return null;
    var preceding_signature_tag = false;
    for (@import("../ast/ast_utils.zig").getJSDoc(tree, function_index)) |doc_index| {
        const doc = tree.getNode(doc_index).JSDoc;
        const tags = doc.Tags orelse continue;
        var is_typedef_or_callback = false;
        for (tree.getNodeList(tags)) |tag_index| {
            const kind_val = tree.getNode(tag_index);
            if (kind_val == .JSDocTypedefTag or kind_val == .JSDocCallbackTag) {
                is_typedef_or_callback = true;
                break;
            }
        }
        if (is_typedef_or_callback) continue;

        for (tree.getNodeList(tags)) |tag_index| switch (tree.getNode(tag_index)) {
            .JSDocParameterTag, .JSDocReturnTag, .JSDocTemplateTag => preceding_signature_tag = true,
            .JSDocTypeTag => |tag| {
                if (!preceding_signature_tag) {
                    const candidate = unwrapJSDocTypeExpression(tree, factory, tag.TypeExpression, allocator);
                    if (tree.getNode(candidate) == .FunctionType) return candidate;
                }
                preceding_signature_tag = true;
            },
            else => {},
        };
    }
    return null;
}

fn inlineJSDocType(tree: *ast.Ast, factory: anytype, node_index: ast.NodeIndex, allocator: std.mem.Allocator) ?ast.NodeIndex {
    const docs = @import("../ast/ast_utils.zig").getJSDoc(tree, node_index);
    for (docs) |doc_index| {
        const doc = tree.getNode(doc_index).JSDoc;
        const tags = doc.Tags orelse continue;
        var is_typedef_or_callback = false;
        for (tree.getNodeList(tags)) |tag_index| {
            const kind_val = tree.getNode(tag_index);
            if (kind_val == .JSDocTypedefTag or kind_val == .JSDocCallbackTag) {
                is_typedef_or_callback = true;
                break;
            }
        }
        if (is_typedef_or_callback) continue;

        for (tree.getNodeList(tags)) |tag_index| if (tree.getNode(tag_index) == .JSDocTypeTag) {
            const result = unwrapJSDocTypeExpression(tree, factory, tree.getNode(tag_index).JSDocTypeTag.TypeExpression, allocator);
            return result;
        };
    }
    return null;
}

fn jsdocParameterType(tree: *ast.Ast, factory: anytype, function_index: ast.NodeIndex, parameter_name: ast.NodeIndex, parameter_ordinal: usize, allocator: std.mem.Allocator) ?ast.NodeIndex {
    const expected_name = if (tree.getNode(parameter_name) == .Identifier) @import("../ast/ast_utils.zig").getText(tree, parameter_name) else "";

    var properties = std.ArrayListUnmanaged(ast.NodeIndex).empty;
    defer properties.deinit(allocator);

    var base_tag_type: ?ast.NodeIndex = null;
    var ordinal: usize = 0;

    for (@import("../ast/ast_utils.zig").getJSDoc(tree, function_index)) |doc_index| {
        const doc = tree.getNode(doc_index).JSDoc;
        const tags = doc.Tags orelse continue;
        var is_typedef_or_callback = false;
        for (tree.getNodeList(tags)) |tag_index| {
            const kind_val = tree.getNode(tag_index);
            if (kind_val == .JSDocTypedefTag or kind_val == .JSDocCallbackTag) {
                is_typedef_or_callback = true;
                break;
            }
        }
        if (is_typedef_or_callback) continue;

        for (tree.getNodeList(tags)) |tag_index| if (tree.getNode(tag_index) == .JSDocParameterTag) {
            const tag = tree.getNode(tag_index).JSDocParameterTag;
            const tagNameText = @import("../ast/ast_utils.zig").getText(tree, tag.name);
            const matches = ordinal == parameter_ordinal or (expected_name.len != 0 and std.mem.eql(u8, expected_name, tagNameText));
            ordinal += 1;

            if (matches) {
                if (base_tag_type == null) if (tag.TypeExpression) |te| {
                    base_tag_type = unwrapJSDocTypeExpression(tree, factory, te, allocator);
                };
            } else if (expected_name.len != 0 and std.mem.startsWith(u8, tagNameText, expected_name) and tagNameText.len > expected_name.len and tagNameText[expected_name.len] == '.') {
                const propName = tagNameText[expected_name.len + 1 ..];
                const propType = if (tag.TypeExpression) |te|
                    unwrapJSDocTypeExpression(tree, factory, te, allocator)
                else
                    factory.newToken(.{ .AnyKeyword = {} });

                const propIdent = factory.newIdentifier(propName);
                const propSig = tree.pushNode(.{ .PropertySignature = .{
                    .Flags = 0,
                    .Symbol = 0,
                    .modifiers = null,
                    .modifierFlags = 0,
                    .name = propIdent,
                    .PostfixToken = null,
                    .Type = if (propType == 0) null else propType,
                    .Initializer = null,
                } }) catch unreachable;
                properties.append(allocator, propSig) catch unreachable;
            }
        };
    }

    if (properties.items.len > 0) {
        const syntaxList = factory.newNodeList(properties.items);
        return tree.pushNode(.{ .TypeLiteral = .{
            .Flags = 0,
            .Symbol = 0,
            .Members = syntaxList,
        } }) catch unreachable;
    }

    return base_tag_type;
}

fn jsdocReturnType(tree: *ast.Ast, factory: anytype, function_index: ast.NodeIndex, allocator: std.mem.Allocator) ?ast.NodeIndex {
    for (@import("../ast/ast_utils.zig").getJSDoc(tree, function_index)) |doc_index| {
        const doc = tree.getNode(doc_index).JSDoc;
        const tags = doc.Tags orelse continue;
        var is_typedef_or_callback = false;
        for (tree.getNodeList(tags)) |tag_index| {
            const kind_val = tree.getNode(tag_index);
            if (kind_val == .JSDocTypedefTag or kind_val == .JSDocCallbackTag) {
                is_typedef_or_callback = true;
                break;
            }
        }
        if (is_typedef_or_callback) continue;

        for (tree.getNodeList(tags)) |tag_index| if (tree.getNode(tag_index) == .JSDocReturnTag) {
            const expression = tree.getNode(tag_index).JSDocReturnTag.TypeExpression orelse continue;
            return unwrapJSDocTypeExpression(tree, factory, expression, allocator);
        };
    }
    return null;
}

fn jsdocVisibilityModifier(tree: *ast.Ast, node: ast.NodeIndex) @import("../ast/kind.zig").Kind {
    for (@import("../ast/ast_utils.zig").getJSDoc(tree, node)) |doc_index| {
        const tags = tree.getNode(doc_index).JSDoc.Tags orelse continue;
        for (tree.getNodeList(tags)) |tag_index| switch (tree.getNode(tag_index)) {
            .JSDocPrivateTag => return .PrivateKeyword,
            .JSDocProtectedTag => return .ProtectedKeyword,
            .JSDocPublicTag => return .PublicKeyword,
            else => {},
        };
    }
    return .Unknown;
}

fn collectJSDocTypeParameters(tree: *ast.Ast, factory: anytype, function_index: ast.NodeIndex, output: *std.ArrayListUnmanaged(ast.NodeIndex), allocator: std.mem.Allocator) void {
    for (@import("../ast/ast_utils.zig").getJSDoc(tree, function_index)) |doc_index| {
        const doc = tree.getNode(doc_index).JSDoc;
        const tags = doc.Tags orelse continue;
        for (tree.getNodeList(tags)) |tag_index| if (tree.getNode(tag_index) == .JSDocTemplateTag) {
            const tag = tree.getNode(tag_index).JSDocTemplateTag;
            const constraint = if (tag.Constraint != 0) unwrapJSDocTypeExpression(tree, factory, tag.Constraint, allocator) else 0;
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

fn inferFunctionReturnType(tree: *ast.Ast, factory: anytype, body: ast.NodeIndex, visitor_opt: ?*visitor.NodeVisitor) ast.NodeIndex {
    if (body != 0 and tree.getNode(body) == .Block) {
        for (tree.getNodeList(tree.getNode(body).Block.Statements)) |statement| if (tree.getNode(statement) == .ReturnStatement) {
            if (tree.getNode(statement).ReturnStatement.Expression) |expression| return inferReturnExpressionType(tree, factory, body, expression, visitor_opt);
        };
    }
    return factory.newToken(.{ .VoidKeyword = {} });
}

fn inferReturnExpressionType(tree: *ast.Ast, factory: anytype, body: ast.NodeIndex, expression: ast.NodeIndex, visitor_opt: ?*visitor.NodeVisitor) ast.NodeIndex {
    switch (tree.getNode(expression)) {
        .AsExpression => |assertion| return if (visitor_opt) |v| v.visitNode(assertion.Type) else assertion.Type,
        .SatisfiesExpression => |assertion| return if (visitor_opt) |v| v.visitNode(assertion.Type) else assertion.Type,
        .ParenthesizedExpression => |parenthesized| return inferReturnExpressionType(tree, factory, body, parenthesized.Expression, visitor_opt),
        else => {},
    }
    if (tree.getNode(expression) == .BinaryExpression) {
        const binary = tree.getNode(expression).BinaryExpression;
        const op_kind = tree.getNodeKind(binary.OperatorToken);
        if (op_kind == .EqualsEqualsEqualsToken or op_kind == .EqualsEqualsToken) {
            if (tree.getNode(binary.Left) == .TypeOfExpression and tree.getNode(binary.Right) == .StringLiteral) {
                const typeof_expr = tree.getNode(binary.Left).TypeOfExpression;
                const str_val = tree.getNode(binary.Right).StringLiteral.Text;
                const type_keyword = if (std.mem.eql(u8, str_val, "string"))
                    factory.newToken(.{ .StringKeyword = {} })
                else if (std.mem.eql(u8, str_val, "number"))
                    factory.newToken(.{ .NumberKeyword = {} })
                else if (std.mem.eql(u8, str_val, "boolean"))
                    factory.newToken(.{ .BooleanKeyword = {} })
                else if (std.mem.eql(u8, str_val, "bigint"))
                    factory.newToken(.{ .BigIntKeyword = {} })
                else if (std.mem.eql(u8, str_val, "symbol"))
                    factory.newToken(.{ .SymbolKeyword = {} })
                else if (std.mem.eql(u8, str_val, "undefined"))
                    factory.newToken(.{ .UndefinedKeyword = {} })
                else
                    0;

                if (type_keyword != 0) {
                    return tree.pushNode(.{ .TypePredicate = .{
                        .Flags = 0,
                        .AssertsModifier = null,
                        .ParameterName = typeof_expr.Expression,
                        .Type = type_keyword,
                    } }) catch unreachable;
                }
            } else if (tree.getNode(binary.Right) == .TypeOfExpression and tree.getNode(binary.Left) == .StringLiteral) {
                const typeof_expr = tree.getNode(binary.Right).TypeOfExpression;
                const str_val = tree.getNode(binary.Left).StringLiteral.Text;
                const type_keyword = if (std.mem.eql(u8, str_val, "string"))
                    factory.newToken(.{ .StringKeyword = {} })
                else if (std.mem.eql(u8, str_val, "number"))
                    factory.newToken(.{ .NumberKeyword = {} })
                else if (std.mem.eql(u8, str_val, "boolean"))
                    factory.newToken(.{ .BooleanKeyword = {} })
                else if (std.mem.eql(u8, str_val, "bigint"))
                    factory.newToken(.{ .BigIntKeyword = {} })
                else if (std.mem.eql(u8, str_val, "symbol"))
                    factory.newToken(.{ .SymbolKeyword = {} })
                else if (std.mem.eql(u8, str_val, "undefined"))
                    factory.newToken(.{ .UndefinedKeyword = {} })
                else
                    0;

                if (type_keyword != 0) {
                    return tree.pushNode(.{ .TypePredicate = .{
                        .Flags = 0,
                        .AssertsModifier = null,
                        .ParameterName = typeof_expr.Expression,
                        .Type = type_keyword,
                    } }) catch unreachable;
                }
            }
        } else if (op_kind == .InstanceOfKeyword) {
            return tree.pushNode(.{ .TypePredicate = .{
                .Flags = 0,
                .AssertsModifier = null,
                .ParameterName = binary.Left,
                .Type = tree.pushNode(.{ .TypeReference = .{
                    .Flags = 0,
                    .TypeArguments = null,
                    .TypeName = binary.Right,
                } }) catch unreachable,
            } }) catch unreachable;
        }
    }
    const function_like = tree.getNodeParent(body);
    const parameters_index: ast.NodeIndex = switch (tree.getNode(function_like)) {
        .FunctionDeclaration => |node| node.Parameters,
        .FunctionExpression => |node| node.Parameters,
        .MethodDeclaration => |node| node.Parameters,
        .GetAccessor => |node| node.Parameters,
        else => 0,
    };
    if (tree.getNode(expression) == .Identifier and parameters_index != 0) {
        const name = @import("../ast/ast_utils.zig").getText(tree, expression);
        for (tree.getNodeList(parameters_index)) |parameter_index| {
            const parameter = tree.getNode(parameter_index).Parameter;
            if (tree.getNode(parameter.name) == .Identifier and std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, parameter.name), name)) {
                const parameter_type = parameter.Type orelse return factory.newToken(.{ .AnyKeyword = {} });
                if (tree.getNode(parameter_type) == .TypeReference and visitor_opt != null) {
                    const type_name = tree.getNode(parameter_type).TypeReference.TypeName;
                    if (tree.getNode(type_name) == .Identifier) {
                        const self: *DeclarationTransformer = @ptrCast(@alignCast(visitor_opt.?.ctx.?));
                        if (resolveUniqueProgramTypeAlias(self.semantic_program, @import("../ast/ast_utils.zig").getText(tree, type_name))) |resolved| return cloneSimpleForeignType(tree, factory, resolved.tree, resolved.node);
                    }
                }
                return parameter_type;
            }
        }
    }
    if (tree.getNode(expression) == .ArrayLiteralExpression) {
        const elements = tree.getNodeList(tree.getNode(expression).ArrayLiteralExpression.Elements);
        if (elements.len != 0) {
            var types_list = std.ArrayListUnmanaged(ast.NodeIndex).empty;
            defer types_list.deinit(factory.allocator);
            for (elements) |element| types_list.append(factory.allocator, inferReturnExpressionType(tree, factory, body, element, visitor_opt)) catch unreachable;
            var all_same = true;
            for (types_list.items[1..]) |type_node| if (!typeNodesSyntacticallyEqual(tree, type_node, types_list.items[0])) {
                all_same = false;
                break;
            };
            if (all_same) return tree.pushNode(.{ .ArrayType = .{ .Flags = 0, .ElementType = types_list.items[0] } }) catch unreachable;
            return tree.pushNode(.{ .TupleType = .{ .Flags = @import("../ast/ast_utils.zig").NodeFlags.Synthesized, .Elements = factory.newNodeList(types_list.items) } }) catch unreachable;
        }
    }
    if (tree.getNode(expression) == .ObjectLiteralExpression) {
        if (visitor_opt) |v| {
            const self: *DeclarationTransformer = @ptrCast(@alignCast(v.ctx.?));
            return self.structuralTypeFromExpression(v, expression, false, false);
        }
    }
    return inferredTypeInner(tree, factory, 0, expression, visitor_opt);
}

const ResolvedForeignType = struct { tree: *ast.Ast, node: ast.NodeIndex };

fn resolveUniqueProgramTypeAlias(program_opt: ?*program_mod.Program, name: []const u8) ?ResolvedForeignType {
    const program = program_opt orelse return null;
    var result: ?ResolvedForeignType = null;
    for (program.units.items) |unit| {
        const tree = unit.tree();
        for (tree.getNodeList(tree.getNode(unit.source_file).SourceFile.Statements)) |statement| {
            const alias = switch (tree.getNode(statement)) {
                .JSTypeAliasDeclaration => |node| node,
                .TypeAliasDeclaration => |node| node,
                else => continue,
            };
            if (!std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, alias.name), name)) continue;
            if (result != null) return null;
            result = .{ .tree = tree, .node = alias.Type };
        }
    }
    return result;
}

fn cloneSimpleForeignType(destination: *ast.Ast, factory: anytype, source: *ast.Ast, node: ast.NodeIndex) ast.NodeIndex {
    return switch (source.getNode(node)) {
        .JSDocTypeExpression => |expression| cloneSimpleForeignType(destination, factory, source, expression.Type),
        .StringKeyword => factory.newToken(.{ .StringKeyword = {} }),
        .NumberKeyword => factory.newToken(.{ .NumberKeyword = {} }),
        .BooleanKeyword => factory.newToken(.{ .BooleanKeyword = {} }),
        .AnyKeyword => factory.newToken(.{ .AnyKeyword = {} }),
        .ArrayType => |array| destination.pushNode(.{ .ArrayType = .{ .Flags = 0, .ElementType = cloneSimpleForeignType(destination, factory, source, array.ElementType) } }) catch unreachable,
        else => factory.newToken(.{ .AnyKeyword = {} }),
    };
}

fn typeNodesSyntacticallyEqual(tree: *ast.Ast, left: ast.NodeIndex, right: ast.NodeIndex) bool {
    if (left == right) return true;
    if (tree.getNodeKind(left) != tree.getNodeKind(right)) return false;
    return switch (tree.getNode(left)) {
        .TypeReference => |left_ref| tree.getNode(tree.getNode(right).TypeReference.TypeName) == .Identifier and
            tree.getNode(left_ref.TypeName) == .Identifier and
            std.mem.eql(u8, @import("../ast/ast_utils.zig").getText(tree, left_ref.TypeName), @import("../ast/ast_utils.zig").getText(tree, tree.getNode(right).TypeReference.TypeName)),
        else => false,
    };
}

fn inferArrowReturnType(tree: *ast.Ast, factory: anytype, body: ast.NodeIndex, visitor_opt: ?*visitor.NodeVisitor) ast.NodeIndex {
    if (tree.getNode(body) == .Block) return inferFunctionReturnType(tree, factory, body, visitor_opt);
    if (tree.getNode(body) == .ObjectLiteralExpression) {
        if (visitor_opt) |v| {
            const self: *DeclarationTransformer = @ptrCast(@alignCast(v.ctx.?));
            return self.structuralTypeFromExpression(v, body, false, false);
        }
    }
    return inferredTypeInner(tree, factory, 0, body, visitor_opt);
}

fn unwrapParenthesizedExpression(tree: *ast.Ast, nodeIndex: ast.NodeIndex) ast.NodeIndex {
    var node = nodeIndex;
    while (node != 0) {
        switch (tree.getNode(node)) {
            .ParenthesizedExpression => |p| {
                node = p.Expression;
            },
            else => break,
        }
    }
    return node;
}

fn getDeclarationNameText(tree: *ast.Ast, node: ast.NodeIndex) []const u8 {
    const kind = tree.getNode(node);
    const name_node = switch (kind) {
        .FunctionDeclaration => |n| n.name orelse 0,
        .ClassDeclaration => |n| n.name orelse 0,
        .InterfaceDeclaration => |n| n.name,
        .TypeAliasDeclaration => |n| n.name,
        .EnumDeclaration => |n| n.name,
        .ModuleDeclaration => |n| n.name,
        .JSTypeAliasDeclaration => |n| n.name,
        else => 0,
    };
    if (name_node == 0) return "";
    return @import("../ast/ast_utils.zig").getText(tree, name_node);
}
