const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const kind = @import("../../ast/kind.zig");
const core = @import("../../core/core.zig");
const transformer_mod = @import("../transformer.zig");
const visitor_mod = @import("../../ast/visitor.zig");
const binder = @import("../../binder/binder.zig");
const printer = @import("../../printer/printer.zig");
const ast_utils = @import("../../ast/ast_utils.zig");
const factory = @import("../../printer/factory.zig");
const referenceresolver = @import("../../binder/referenceresolver.zig");
const emitresolver = @import("../../printer/emitresolver.zig");

pub const EnumMemberValue = union(enum) {
    Int: u32,
    Double: f64,
    String: []const u8,
    NaN,
};

pub const RuntimeSyntaxTransformer = struct {
    transformer: *transformer_mod.Transformer,
    compilerOptions: *core.CompilerOptions,
    parentNode: ast_gen.NodeIndex = 0,
    currentNode: ast_gen.NodeIndex = 0,
    currentSourceFile: ast_gen.NodeIndex = 0,
    namespaceExportNames: std.StringHashMapUnmanaged(void) = .empty,
    currentScope: ast_gen.NodeIndex = 0, // SourceFile | Block | ModuleBlock | CaseBlock
    currentScopeFirstDeclarationsOfName: ?*std.StringHashMap(ast_gen.NodeIndex) = null,
    currentEnum: ast_gen.NodeIndex = 0,
    currentNamespace: ast_gen.NodeIndex = 0,
    resolver: ?*referenceresolver.ReferenceResolver = null,
    emitResolver: *emitresolver.EmitResolver,
    enumMemberValues: std.StringHashMap(EnumMemberValue),

    pub fn newRuntimeSyntaxTransformer(allocator: std.mem.Allocator, opt: *transformer_mod.TransformOptions) !*transformer_mod.Transformer {
        const tx = try allocator.create(RuntimeSyntaxTransformer);
        tx.compilerOptions = opt.compilerOptions;
        tx.parentNode = 0;
        tx.currentNode = 0;
        tx.currentSourceFile = 0;
        tx.currentScope = 0;
        tx.currentScopeFirstDeclarationsOfName = null;
        tx.currentEnum = 0;
        tx.currentNamespace = 0;
        tx.resolver = opt.resolver;
        tx.emitResolver = opt.emitResolver;
        tx.enumMemberValues = std.StringHashMap(EnumMemberValue).init(allocator);
        tx.transformer = try transformer_mod.Transformer.init(allocator, visit, tx, opt.context);
        return tx.transformer;
    }

    fn pushNode(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const grandparentNode = self.parentNode;
        self.parentNode = self.currentNode;
        self.currentNode = node;
        return grandparentNode;
    }

    fn popNode(self: *RuntimeSyntaxTransformer, grandparentNode: ast_gen.NodeIndex) void {
        self.currentNode = self.parentNode;
        self.parentNode = grandparentNode;
    }

    const ScopeState = struct {
        savedCurrentScope: ast_gen.NodeIndex,
        savedCurrentScopeFirstDeclarationsOfName: ?*std.StringHashMap(ast_gen.NodeIndex),
    };

    fn pushScope(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) ScopeState {
        const savedCurrentScope = self.currentScope;
        const savedCurrentScopeFirstDeclarationsOfName = self.currentScopeFirstDeclarationsOfName;

        switch (self.transformer.visitor.tree.getNode(node)) {
            .SourceFile => {
                self.currentScope = node;
                self.currentSourceFile = node;
                self.currentScopeFirstDeclarationsOfName = null;
            },
            .CaseBlock, .ModuleBlock, .Block => {
                self.currentScope = node;
                self.currentScopeFirstDeclarationsOfName = null;
            },
            .FunctionDeclaration, .ClassDeclaration, .VariableStatement => {
                self.recordDeclarationInScope(node);
            },
            else => {},
        }
        return .{
            .savedCurrentScope = savedCurrentScope,
            .savedCurrentScopeFirstDeclarationsOfName = savedCurrentScopeFirstDeclarationsOfName,
        };
    }

    fn popScope(self: *RuntimeSyntaxTransformer, state: ScopeState) void {
        if (self.currentScope != state.savedCurrentScope) {
            self.currentScopeFirstDeclarationsOfName = state.savedCurrentScopeFirstDeclarationsOfName;
        }
        self.currentScope = state.savedCurrentScope;
    }

    fn visit(ctx: ?*anyopaque, v: *visitor_mod.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const self = @as(*RuntimeSyntaxTransformer, @ptrCast(@alignCast(ctx.?)));

        if (node == 0) return 0;

        const grandparentNode = self.pushNode(node);
        defer self.popNode(grandparentNode);

        const scopeState = self.pushScope(node);
        defer self.popScope(scopeState);

        const facts = ast_utils.getSubtreeFacts(self.transformer.visitor.tree, node);
        if ((facts & ast_utils.SubtreeFacts.ContainsTypeScript) == 0 and
            (self.currentNamespace == 0 and self.currentEnum == 0 or (facts & ast_utils.SubtreeFacts.ContainsIdentifier) == 0))
        {
            return node;
        }

        switch (self.transformer.visitor.tree.getNode(node)) {
            .PublicKeyword, .PrivateKeyword, .ProtectedKeyword, .ReadonlyKeyword, .OverrideKeyword => return 0,
            .EnumDeclaration => return self.visitEnumDeclaration(node),
            .ModuleDeclaration => return self.visitModuleDeclaration(node),
            .ClassDeclaration => return self.visitClassDeclaration(node),
            .ClassExpression => return self.visitClassExpression(node),
            .Constructor => return self.visitConstructorDeclaration(node),
            .FunctionDeclaration => return self.visitFunctionDeclaration(node),
            .VariableStatement => return self.visitVariableStatement(node),
            .ExportDeclaration, .ImportDeclaration, .ImportClause => {
                if (self.currentNamespace != 0 and self.currentScope != 0 and self.transformer.visitor.tree.getNode(self.currentScope) != .Block) {
                    return 0;
                } else {
                    return v.visitEachChild(node);
                }
            },
            .ImportEqualsDeclaration => |n| {
                if (self.currentNamespace != 0 and self.currentScope != 0 and self.transformer.visitor.tree.getNode(self.currentScope) != .Block and self.transformer.visitor.tree.getNode(n.ModuleReference) == .ExternalModuleReference) {
                    return 0;
                } else if (self.currentNamespace != 0 and self.currentScope != 0 and self.transformer.visitor.tree.getNode(self.currentScope) == .Block and self.transformer.visitor.tree.getNode(n.ModuleReference) != .ExternalModuleReference) {
                    return 0;
                } else {
                    return self.visitImportEqualsDeclaration(node);
                }
            },
            .Identifier => return self.visitIdentifier(node),
            .ShorthandPropertyAssignment => return self.visitShorthandPropertyAssignment(node),
            else => return v.visitEachChild(node),
        }
    }

    fn recordDeclarationInScope(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) void {
        switch (self.transformer.visitor.tree.getNode(node)) {
            .VariableStatement => |n| {
                self.recordDeclarationInScope(n.DeclarationList);
                return;
            },
            .VariableDeclarationList => |n| {
                for (self.transformer.visitor.tree.getNodeList(n.Declarations)) |decl| {
                    self.recordDeclarationInScope(decl);
                }
                return;
            },
            .ArrayBindingPattern, .ObjectBindingPattern => {
                for (ast_utils.getElements(self.transformer.visitor.tree, node)) |element| {
                    self.recordDeclarationInScope(element);
                }
                return;
            },
            else => {},
        }
        const name = ast_utils.getName(self.transformer.visitor.tree, node);
        if (name != 0) {
            if (ast_utils.isIdentifier(self.transformer.visitor.tree, name)) {
                if (self.currentScopeFirstDeclarationsOfName == null) {
                    const map = self.transformer.emitContext.allocator.create(std.StringHashMap(ast_gen.NodeIndex)) catch unreachable;
                    map.* = std.StringHashMap(ast_gen.NodeIndex).init(self.transformer.emitContext.allocator);
                    self.currentScopeFirstDeclarationsOfName = map;
                }
                const text = ast_utils.getText(self.transformer.visitor.tree, name);
                if (!self.currentScopeFirstDeclarationsOfName.?.contains(text)) {
                    self.currentScopeFirstDeclarationsOfName.?.put(text, node) catch unreachable;
                }
            } else if (ast_utils.isBindingPattern(self.transformer.visitor.tree, name)) {
                self.recordDeclarationInScope(name);
            }
        }
    }

    fn isFirstDeclarationInScope(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) bool {
        const name = ast_utils.getName(self.transformer.visitor.tree, node);
        if (name != 0 and ast_utils.isIdentifier(self.transformer.visitor.tree, name)) {
            const text = ast_utils.getText(self.transformer.visitor.tree, name);
            if (self.currentScopeFirstDeclarationsOfName) |map| {
                if (map.get(text)) |firstDeclaration| {
                    return firstDeclaration == node;
                }
            }
        }
        return false;
    }

    fn isExportOfNamespace(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) bool {
        return self.currentNamespace != 0 and (self.currentScope == 0 or self.transformer.visitor.tree.getNode(self.currentScope) != .Block) and (ast_utils.getModifierFlags(self.transformer.visitor.tree, node) & ast_utils.ModifierFlags.Export) != 0;
    }

    fn getExpressionForPropertyName(self: *RuntimeSyntaxTransformer, memberNode: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const name = ast_utils.getName(self.transformer.visitor.tree, memberNode);
        switch (self.transformer.visitor.tree.getNode(name)) {
            .PrivateIdentifier => {
                return self.transformer.factory.newIdentifier("");
            },
            .ComputedPropertyName => |n| {
                return self.transformer.visitor.visitNode(n.Expression);
            },
            .Identifier => {
                return self.transformer.factory.newStringLiteral(ast_utils.getText(self.transformer.visitor.tree, name), ast_utils.TokenFlags.None);
            },
            .StringLiteral => {
                return self.transformer.factory.newStringLiteral(ast_utils.getText(self.transformer.visitor.tree, name), ast_utils.TokenFlags.None);
            },
            .NumericLiteral => {
                return self.transformer.factory.newNumericLiteral(ast_utils.getText(self.transformer.visitor.tree, name), ast_utils.TokenFlags.None);
            },
            else => return name,
        }
    }

    fn getEnumQualifiedElement(self: *RuntimeSyntaxTransformer, enumNode: ast_gen.NodeIndex, memberNode: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const prop = self.getNamespaceQualifiedElement(self.getNamespaceContainerName(enumNode), self.getExpressionForPropertyName(memberNode));
        self.transformer.emitContext.addEmitFlags(prop, 0 | printer.EmitFlags.NoSourceMap | printer.EmitFlags.NoNestedSourceMaps) catch unreachable;
        return prop;
    }

    fn getNamespaceContainerName(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.transformer.factory.newGeneratedNameForNode(node);
    }

    fn getNamespaceQualifiedProperty(self: *RuntimeSyntaxTransformer, ns: ast_gen.NodeIndex, name: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.transformer.factory.getNamespaceMemberName(ns, name, .{ .allowSourceMaps = true });
    }

    fn getNamespaceQualifiedElement(self: *RuntimeSyntaxTransformer, ns: ast_gen.NodeIndex, expression: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const qualifiedName = self.transformer.emitContext.factory.newElementAccessExpression(ns, 0, expression, ast_utils.NodeFlags.None);
        self.transformer.emitContext.assignCommentAndSourceMapRanges(qualifiedName, expression);
        return qualifiedName;
    }

    fn getExportQualifiedReferenceToDeclaration(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        if (self.isExportOfNamespace(node)) {
            return self.transformer.factory.getExternalModuleOrNamespaceExportName(self.getNamespaceContainerName(self.currentNamespace), node, false, true);
        }
        return self.transformer.factory.getDeclarationNameEx(node, .{ .allowSourceMaps = true });
    }

    fn addVarForDeclaration(self: *RuntimeSyntaxTransformer, statements: *std.ArrayList(ast_gen.NodeIndex), node: ast_gen.NodeIndex) bool {
        self.recordDeclarationInScope(node);
        if (!self.isFirstDeclarationInScope(node)) {
            return false;
        }

        const name = self.transformer.factory.getLocalNameEx(node, .{ .allowSourceMaps = true });
        const varDecl = self.transformer.factory.newVariableDeclaration(name, 0, 0, 0);
        const varFlags = if (self.currentScope == self.currentSourceFile) ast_utils.NodeFlags.None else ast_utils.NodeFlags.Let;

        const nodesArr = self.transformer.emitContext.allocator.alloc(ast_gen.NodeIndex, 1) catch unreachable;
        nodesArr[0] = varDecl;
        const varDecls = self.transformer.factory.newVariableDeclarationList(self.transformer.factory.newNodeList(nodesArr), varFlags);

        var modifierMask = ~(ast_utils.ModifierFlags.TypeScriptModifier | ast_utils.ModifierFlags.Decorator);
        if (self.currentNamespace != 0) {
            modifierMask &= ~ast_utils.ModifierFlags.Export;
        }
        const modifiers = ast_utils.extractModifiers(self.transformer.visitor.tree, (ast_utils.getModifiers(self.transformer.visitor.tree, node) orelse 0), modifierMask);
        const varStatement = self.transformer.factory.newVariableStatement(modifiers, varDecls);

        self.transformer.emitContext.setOriginal(varDecl, node) catch unreachable;
        self.transformer.emitContext.setOriginal(varStatement, node) catch unreachable;

        if (ast_utils.isEnumDeclaration(self.transformer.visitor.tree, node)) {
            self.transformer.emitContext.setSourceMapRange(varDecls, ast_utils.getLoc(self.transformer.visitor.tree, node));
        } else {
            self.transformer.emitContext.setSourceMapRange(varStatement, ast_utils.getLoc(self.transformer.visitor.tree, node));
        }

        self.transformer.emitContext.setCommentRange(varStatement, ast_utils.getLoc(self.transformer.visitor.tree, node));
        self.transformer.emitContext.addEmitFlags(varStatement, printer.EmitFlags.NoTrailingComments) catch unreachable;
        statements.append(std.heap.page_allocator, varStatement) catch unreachable;

        return true;
    }

    fn visitEnumDeclaration(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        if (!self.shouldEmitEnumDeclaration(node)) {
            return self.transformer.emitContext.newNotEmittedStatement(node) catch 0;
        }

        var statements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        const varAdded = self.addVarForDeclaration(&statements, node);

        var emitFlags: u32 = 0;
        if (varAdded and (false or self.currentScope != self.currentSourceFile)) {
            emitFlags |= 0;
        }

        var enumArg = self.transformer.factory.newLogicalORExpression(self.getExportQualifiedReferenceToDeclaration(node), self.transformer.factory.newParenthesizedExpression(self.transformer.factory.newAssignmentExpression(self.getExportQualifiedReferenceToDeclaration(node), self.transformer.factory.newObjectLiteralExpression(self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{}), false))));

        if (self.isExportOfNamespace(node)) {
            const localName = self.transformer.factory.getLocalNameEx(node, .{ .allowSourceMaps = true });
            enumArg = self.transformer.factory.newAssignmentExpression(localName, enumArg);
        }

        const enumParamName = self.transformer.factory.newGeneratedNameForNode(node);
        self.transformer.emitContext.setSourceMapRange(enumParamName, ast_utils.getLoc(self.transformer.visitor.tree, ast_utils.getName(self.transformer.visitor.tree, node)));

        const enumParam = self.transformer.factory.newParameterDeclaration(0, 0, enumParamName, 0, 0, 0);
        const enumBody = self.transformEnumBody(node);

        const paramsArr = self.transformer.emitContext.allocator.alloc(ast_gen.NodeIndex, 1) catch unreachable;
        paramsArr[0] = enumParam;

        const enumFunc = self.transformer.factory.newFunctionExpression(0, 0, 0, 0, self.transformer.factory.newNodeList(paramsArr), 0, 0, enumBody);

        const argsArr = self.transformer.emitContext.allocator.alloc(ast_gen.NodeIndex, 1) catch unreachable;
        argsArr[0] = enumArg;

        const enumCall = self.transformer.factory.newCallExpression(self.transformer.factory.newParenthesizedExpression(enumFunc), 0, 0, self.transformer.factory.newNodeList(argsArr), ast_utils.NodeFlags.None);
        const enumStatement = self.transformer.factory.newExpressionStatement(enumCall);
        self.transformer.emitContext.setOriginal(enumStatement, node) catch unreachable;
        self.transformer.emitContext.assignCommentAndSourceMapRanges(enumStatement, node);
        self.transformer.emitContext.addEmitFlags(enumStatement, emitFlags) catch unreachable;

        statements.append(std.heap.page_allocator, enumStatement) catch unreachable;

        const result = self.transformer.factory.newSyntaxList(statements.items);
        return result;
    }

    fn transformEnumBody(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const savedCurrentEnum = self.currentEnum;
        self.currentEnum = node;

        const visitedNode = self.transformer.visitor.visitEachChild(node);
        const enumData = self.transformer.visitor.tree.getNode(visitedNode).EnumDeclaration;

        var statements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        const membersList = self.transformer.visitor.tree.getNodeList(enumData.Members);
        var enumVal = EnumMemberValue{ .Int = 0 };
        for (membersList, 0..) |_, i| {
            enumVal = self.transformEnumMember(&statements, visitedNode, i, enumVal);
            switch (enumVal) {
                .Int => |val| enumVal = .{ .Int = val +% 1 },
                .Double => |val| enumVal = .{ .Double = val + 1.0 },
                .NaN => enumVal = .NaN,
                else => {},
            }
        }

        const statementList = self.transformer.factory.newNodeList(statements.items);
        ast_utils.setLoc(self.transformer.visitor.tree, statementList, ast_utils.getLoc(self.transformer.visitor.tree, enumData.Members));

        self.currentEnum = savedCurrentEnum;
        return self.transformer.factory.newBlock(statementList, true);
    }

    fn evaluateEnumInitializer(self: *RuntimeSyntaxTransformer, expr: ast_gen.NodeIndex) ?EnumMemberValue {
        if (expr == 0) return null;
        const node = self.transformer.visitor.tree.getNode(expr);
        switch (node) {
            .NumericLiteral => |n| {
                if (std.fmt.parseInt(u32, n.Text, 10)) |val| {
                    return EnumMemberValue{ .Int = val };
                } else |_| {
                    if (std.fmt.parseFloat(f64, n.Text)) |val| {
                        return EnumMemberValue{ .Double = val };
                    } else |_| return null;
                }
            },
            .StringLiteral => |n| {
                return EnumMemberValue{ .String = n.Text };
            },
            .Identifier => |n| {
                if (std.mem.eql(u8, n.Text, "NaN")) return .NaN;
                return self.enumMemberValues.get(n.Text);
            },
            .PropertyAccessExpression => |n| {
                const nameNode = self.transformer.visitor.tree.getNode(n.name);
                if (nameNode == .Identifier) {
                    return self.enumMemberValues.get(nameNode.Identifier.Text);
                }
                return null;
            },
            .BinaryExpression => |n| {
                const leftVal = self.evaluateEnumInitializer(n.Left) orelse return null;
                const rightVal = self.evaluateEnumInitializer(n.Right) orelse return null;
                const opKind = std.meta.activeTag(self.transformer.visitor.tree.getNode(n.OperatorToken));

                if (leftVal == .NaN or rightVal == .NaN) return .NaN;

                switch (opKind) {
                    .PlusToken => {
                        if (leftVal == .Int and rightVal == .Int) return .{ .Int = leftVal.Int +% rightVal.Int };
                        const l = if (leftVal == .Int) @as(f64, @floatFromInt(leftVal.Int)) else leftVal.Double;
                        const r = if (rightVal == .Int) @as(f64, @floatFromInt(rightVal.Int)) else rightVal.Double;
                        return .{ .Double = l + r };
                    },
                    .MinusToken => {
                        if (leftVal == .Int and rightVal == .Int) return .{ .Int = leftVal.Int -% rightVal.Int };
                        const l = if (leftVal == .Int) @as(f64, @floatFromInt(leftVal.Int)) else leftVal.Double;
                        const r = if (rightVal == .Int) @as(f64, @floatFromInt(rightVal.Int)) else rightVal.Double;
                        return .{ .Double = l - r };
                    },
                    .AsteriskToken => {
                        if (leftVal == .Int and rightVal == .Int) return .{ .Int = leftVal.Int *% rightVal.Int };
                        const l = if (leftVal == .Int) @as(f64, @floatFromInt(leftVal.Int)) else leftVal.Double;
                        const r = if (rightVal == .Int) @as(f64, @floatFromInt(rightVal.Int)) else rightVal.Double;
                        return .{ .Double = l * r };
                    },
                    .SlashToken => {
                        const l = if (leftVal == .Int) @as(f64, @floatFromInt(leftVal.Int)) else leftVal.Double;
                        const r = if (rightVal == .Int) @as(f64, @floatFromInt(rightVal.Int)) else rightVal.Double;
                        if (r == 0) return .NaN;
                        const res = l / r;
                        if (std.math.isNan(res)) return .NaN;
                        if (res == @round(res)) {
                            return .{ .Int = @as(u32, @intFromFloat(res)) };
                        }
                        return .{ .Double = res };
                    },
                    else => return null,
                }
            },
            .PrefixUnaryExpression => |n| {
                const op_kind = std.meta.activeTag(self.transformer.visitor.tree.getNode(n.Operator));
                if (op_kind != .MinusToken and op_kind != .PlusToken and op_kind != .TildeToken) return null;
                const operand_val = self.evaluateEnumInitializer(n.Operand) orelse return null;
                switch (op_kind) {
                    .MinusToken => switch (operand_val) {
                        .NaN => return .NaN, // -NaN === NaN
                        .Int => |v| return .{ .Int = 0 -% v },
                        .Double => |v| return .{ .Double = -v },
                        else => return null,
                    },
                    .PlusToken => return operand_val,
                    .TildeToken => switch (operand_val) {
                        .Int => |v| return .{ .Int = ~v },
                        else => return null,
                    },
                    else => return null,
                }
            },
            else => return null,
        }
    }

    fn transformEnumMember(self: *RuntimeSyntaxTransformer, statements: *std.ArrayListUnmanaged(ast_gen.NodeIndex), enumNode: ast_gen.NodeIndex, index: usize, currentVal: EnumMemberValue) EnumMemberValue {
        const enumData = self.transformer.visitor.tree.getNode(enumNode).EnumDeclaration;
        const memberNode = self.transformer.visitor.tree.getNodeList(enumData.Members)[index];
        const memberData = self.transformer.visitor.tree.getNode(memberNode).EnumMember;

        const savedParent = self.parentNode;
        self.parentNode = self.currentNode;
        self.currentNode = memberNode;
        defer {
            self.parentNode = savedParent;
        }

        var expression = (memberData.Initializer orelse 0);
        var nextVal = currentVal;

        if (expression == 0) {
            switch (currentVal) {
                .Int => |val| {
                    var buf: [32]u8 = undefined;
                    const text = std.fmt.bufPrint(&buf, "{d}", .{val}) catch unreachable;
                    const strValue = self.transformer.emitContext.allocator.dupe(u8, text) catch unreachable;
                    expression = self.transformer.factory.newNumericLiteral(strValue, 0);
                },
                .Double => |val| {
                    var buf: [32]u8 = undefined;
                    const text = std.fmt.bufPrint(&buf, "{d}", .{val}) catch unreachable;
                    const strValue = self.transformer.emitContext.allocator.dupe(u8, text) catch unreachable;
                    expression = self.transformer.factory.newNumericLiteral(strValue, 0);
                },
                .NaN => {
                    expression = self.transformer.factory.newIdentifier("NaN");
                },
                else => {},
            }
        } else {
            if (self.evaluateEnumInitializer(expression)) |val| {
                switch (val) {
                    .Int => |v| {
                        var buf: [32]u8 = undefined;
                        const text = std.fmt.bufPrint(&buf, "{d}", .{v}) catch unreachable;
                        const strValue = self.transformer.emitContext.allocator.dupe(u8, text) catch unreachable;
                        expression = self.transformer.factory.newNumericLiteral(strValue, 0);
                    },
                    .Double => |v| {
                        var buf: [32]u8 = undefined;
                        const text = std.fmt.bufPrint(&buf, "{d}", .{v}) catch unreachable;
                        const strValue = self.transformer.emitContext.allocator.dupe(u8, text) catch unreachable;
                        expression = self.transformer.factory.newNumericLiteral(strValue, 0);
                    },
                    .NaN => {
                        expression = self.transformer.factory.newIdentifier("NaN");
                    },
                    .String => |v| {
                        const strValue = self.transformer.emitContext.allocator.dupe(u8, v) catch unreachable;
                        expression = self.transformer.factory.newStringLiteral(strValue, 0);
                    },
                }
                nextVal = val;
            } else {
                if (self.transformer.visitor.tree.getNode(expression) == .NumericLiteral) {
                    const numText = ast_utils.getText(self.transformer.visitor.tree, expression);
                    if (std.fmt.parseInt(u32, numText, 10)) |parsed| {
                        nextVal = .{ .Int = parsed };
                    } else |_| {
                        if (std.fmt.parseFloat(f64, numText)) |parsed| {
                            nextVal = .{ .Double = parsed };
                        } else |_| {}
                    }
                } else if (self.transformer.visitor.tree.getNode(expression) == .StringLiteral) {
                    const strText = ast_utils.getText(self.transformer.visitor.tree, expression);
                    nextVal = .{ .String = strText };
                }
            }
        }

        const memberName = ast_utils.getName(self.transformer.visitor.tree, memberNode);
        const nameText = ast_utils.getText(self.transformer.visitor.tree, memberName);
        self.enumMemberValues.put(nameText, nextVal) catch {};

        const useExplicitReverseMapping = switch (nextVal) {
            .String => false,
            else => true,
        };

        expression = self.transformer.factory.newAssignmentExpression(
            self.getEnumQualifiedElement(enumNode, memberNode),
            expression,
        );

        if (useExplicitReverseMapping) {
            const strName = self.transformer.emitContext.allocator.dupe(u8, nameText) catch unreachable;
            const propertyName = self.transformer.factory.newStringLiteral(strName, ast_utils.TokenFlags.None);

            expression = self.transformer.factory.newAssignmentExpression(
                self.transformer.factory.newElementAccessExpression(
                    self.getNamespaceContainerName(enumNode),
                    0,
                    expression,
                    0,
                ),
                propertyName,
            );
        }

        const statement = self.transformer.factory.newExpressionStatement(expression);
        ast_utils.setLoc(self.transformer.visitor.tree, statement, ast_utils.getLoc(self.transformer.visitor.tree, memberNode));
        statements.append(self.transformer.emitContext.allocator, statement) catch unreachable;

        return nextVal;
    }

    fn constantExpression(self: *RuntimeSyntaxTransformer, val: f64) ast_gen.NodeIndex {
        return ast_utils.constantExpression(self.transformer.factory, val);
    }

    fn constantExpressionStr(self: *RuntimeSyntaxTransformer, val: []const u8) ast_gen.NodeIndex {
        return ast_utils.constantExpressionStr(self.transformer.factory, val);
    }

    fn visitModuleDeclaration(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        if (!self.shouldEmitModuleDeclaration(node)) {
            return self.transformer.emitContext.newNotEmittedStatement(node) catch 0;
        }

        var statements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        const varAdded = self.addVarForDeclaration(&statements, node);

        var emitFlags: u32 = 0;
        if (varAdded and (false or self.currentScope != self.currentSourceFile)) {
            emitFlags |= 0;
        }

        var moduleArg = self.transformer.factory.newLogicalORExpression(self.getExportQualifiedReferenceToDeclaration(node), self.transformer.factory.newParenthesizedExpression(self.transformer.factory.newAssignmentExpression(self.getExportQualifiedReferenceToDeclaration(node), self.transformer.factory.newObjectLiteralExpression(self.transformer.factory.newNodeList(&[_]ast_gen.NodeIndex{}), false))));

        if (self.isExportOfNamespace(node)) {
            const localName = self.transformer.factory.getLocalNameEx(node, .{ .allowSourceMaps = true });
            moduleArg = self.transformer.factory.newAssignmentExpression(localName, moduleArg);
        }

        const moduleParamName = self.transformer.factory.newGeneratedNameForNode(node);
        self.transformer.emitContext.setSourceMapRange(moduleParamName, ast_utils.getLoc(self.transformer.visitor.tree, ast_utils.getName(self.transformer.visitor.tree, node)));

        const moduleParam = self.transformer.factory.newParameterDeclaration(0, 0, moduleParamName, 0, 0, 0);
        const moduleBody = self.transformModuleBody(node, self.getNamespaceContainerName(node));

        const paramsArr = self.transformer.emitContext.allocator.alloc(ast_gen.NodeIndex, 1) catch unreachable;
        paramsArr[0] = moduleParam;

        const moduleFunc = self.transformer.factory.newFunctionExpression(0, 0, 0, 0, self.transformer.factory.newNodeList(paramsArr), 0, 0, moduleBody);

        const argsArr = self.transformer.emitContext.allocator.alloc(ast_gen.NodeIndex, 1) catch unreachable;
        argsArr[0] = moduleArg;

        const moduleCall = self.transformer.factory.newCallExpression(self.transformer.factory.newParenthesizedExpression(moduleFunc), 0, 0, self.transformer.factory.newNodeList(argsArr), ast_utils.NodeFlags.None);
        const moduleStatement = self.transformer.factory.newExpressionStatement(moduleCall);
        self.transformer.emitContext.setOriginal(moduleStatement, node) catch unreachable;
        self.transformer.emitContext.assignCommentAndSourceMapRanges(moduleStatement, node);
        self.transformer.emitContext.addEmitFlags(moduleStatement, emitFlags) catch unreachable;
        statements.append(std.heap.page_allocator, moduleStatement) catch unreachable;
        return self.transformer.factory.newSyntaxList(statements.items);
    }

    fn transformModuleBody(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex, namespaceLocalName: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = namespaceLocalName;
        const savedCurrentNamespace = self.currentNamespace;
        const savedCurrentScope = self.currentScope;
        const savedCurrentScopeFirstDeclarationsOfName = self.currentScopeFirstDeclarationsOfName;

        self.currentNamespace = node;
        self.currentScopeFirstDeclarationsOfName = null;
        const savedNamespaceExportNames = self.namespaceExportNames;
        self.namespaceExportNames = .empty;
        defer {
            self.namespaceExportNames.deinit(self.transformer.emitContext.allocator);
            self.namespaceExportNames = savedNamespaceExportNames;
        }

        var statements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        self.transformer.emitContext.startVariableEnvironment() catch unreachable;

        var statementsLocation: ast.TextRange = undefined;
        var blockLocation: ast.TextRange = undefined;

        const nodeData = self.transformer.visitor.tree.getNode(node).ModuleDeclaration;
        const namespace_name = ast_utils.getText(self.transformer.visitor.tree, nodeData.name);
        if (self.currentSourceFile != 0) {
            const source = self.transformer.visitor.tree.getNode(self.currentSourceFile).SourceFile;
            for (self.transformer.visitor.tree.getNodeList(source.Statements)) |candidate| {
                if (self.transformer.visitor.tree.getNode(candidate) != .ModuleDeclaration) continue;
                const candidate_data = self.transformer.visitor.tree.getNode(candidate).ModuleDeclaration;
                if (std.mem.eql(u8, ast_utils.getText(self.transformer.visitor.tree, candidate_data.name), namespace_name)) self.recordNamespaceExports(candidate);
            }
        } else self.recordNamespaceExports(node);

        if ((nodeData.Body orelse 0) != 0 and self.transformer.visitor.tree.getNode(nodeData.Body.?) == .ModuleBlock) {
            const body = self.transformer.visitor.tree.getNode(nodeData.Body.?).ModuleBlock;
            for (self.transformer.visitor.tree.getNodeList(body.Statements)) |statement| {
                if ((ast_utils.getModifierFlags(self.transformer.visitor.tree, statement) & ast_utils.ModifierFlags.Export) == 0) continue;
                if (self.transformer.visitor.tree.getNode(statement) == .VariableStatement) {
                    const list = self.transformer.visitor.tree.getNode(self.transformer.visitor.tree.getNode(statement).VariableStatement.DeclarationList).VariableDeclarationList;
                    for (self.transformer.visitor.tree.getNodeList(list.Declarations)) |declaration| {
                        const name = ast_utils.getName(self.transformer.visitor.tree, declaration);
                        if (name != 0 and self.transformer.visitor.tree.getNode(name) == .Identifier) self.namespaceExportNames.put(self.transformer.emitContext.allocator, ast_utils.getText(self.transformer.visitor.tree, name), {}) catch unreachable;
                    }
                } else {
                    const name = ast_utils.getName(self.transformer.visitor.tree, statement);
                    if (name != 0 and self.transformer.visitor.tree.getNode(name) == .Identifier) self.namespaceExportNames.put(self.transformer.emitContext.allocator, ast_utils.getText(self.transformer.visitor.tree, name), {}) catch unreachable;
                }
            }
        }
        var visitedNode = node;
        if ((nodeData.Body orelse 0) != 0) {
            if (self.transformer.visitor.tree.getNode((nodeData.Body orelse 0)) == .ModuleBlock) {
                visitedNode = self.transformer.visitor.visitEachChild(node);
                const visitedData = self.transformer.visitor.tree.getNode(visitedNode).ModuleDeclaration;
                const bodyData = self.transformer.visitor.tree.getNode(visitedData.Body orelse 0).ModuleBlock;
                for (self.transformer.visitor.tree.getNodeList(bodyData.Statements)) |stmt| {
                    statements.append(std.heap.page_allocator, stmt) catch unreachable;
                }
                statementsLocation = ast_utils.getLoc(self.transformer.visitor.tree, bodyData.Statements);
                blockLocation = ast_utils.getLoc(self.transformer.visitor.tree, visitedData.Body orelse 0);
            } else {
                const visitedBody = self.transformer.visitor.visitNode(nodeData.Body orelse 0);
                statements.append(std.heap.page_allocator, visitedBody) catch unreachable;
                const innerMod = getInnermostModuleDeclarationFromDottedModule(self.transformer.visitor.tree, node);
                const innerBodyData = self.transformer.visitor.tree.getNode(self.transformer.visitor.tree.getNode(innerMod).ModuleDeclaration.Body orelse 0).ModuleBlock;
                statementsLocation = ast_utils.withPos(ast_utils.getLoc(self.transformer.visitor.tree, innerBodyData.Statements), -1);
            }
        }

        self.currentNamespace = savedCurrentNamespace;
        self.currentScope = savedCurrentScope;
        self.currentScopeFirstDeclarationsOfName = savedCurrentScopeFirstDeclarationsOfName;

        const mergedStatements = self.transformer.emitContext.endAndMergeVariableEnvironment(statements.items);
        const statementList = self.transformer.factory.newNodeList(mergedStatements);
        ast_utils.setLoc(self.transformer.visitor.tree, statementList, statementsLocation);
        const block = self.transformer.factory.newBlock(statementList, true);
        ast_utils.setLoc(self.transformer.visitor.tree, block, blockLocation);

        if ((nodeData.Body orelse 0) == 0 or self.transformer.visitor.tree.getNode((nodeData.Body orelse 0)) != .ModuleBlock) {
            self.transformer.emitContext.addEmitFlags(block, printer.EmitFlags.NoComments) catch unreachable;
        }
        return block;
    }

    fn recordNamespaceExports(self: *RuntimeSyntaxTransformer, module: ast_gen.NodeIndex) void {
        const module_data = self.transformer.visitor.tree.getNode(module).ModuleDeclaration;
        const body_index = module_data.Body orelse return;
        if (self.transformer.visitor.tree.getNode(body_index) != .ModuleBlock) return;
        const body = self.transformer.visitor.tree.getNode(body_index).ModuleBlock;
        for (self.transformer.visitor.tree.getNodeList(body.Statements)) |statement| {
            if ((ast_utils.getModifierFlags(self.transformer.visitor.tree, statement) & ast_utils.ModifierFlags.Export) == 0) continue;
            if (self.transformer.visitor.tree.getNode(statement) == .VariableStatement) {
                const list = self.transformer.visitor.tree.getNode(self.transformer.visitor.tree.getNode(statement).VariableStatement.DeclarationList).VariableDeclarationList;
                for (self.transformer.visitor.tree.getNodeList(list.Declarations)) |declaration| {
                    const name = ast_utils.getName(self.transformer.visitor.tree, declaration);
                    if (name != 0 and self.transformer.visitor.tree.getNode(name) == .Identifier) self.namespaceExportNames.put(self.transformer.emitContext.allocator, ast_utils.getText(self.transformer.visitor.tree, name), {}) catch unreachable;
                }
            } else {
                const name = ast_utils.getName(self.transformer.visitor.tree, statement);
                if (name != 0 and self.transformer.visitor.tree.getNode(name) == .Identifier) self.namespaceExportNames.put(self.transformer.emitContext.allocator, ast_utils.getText(self.transformer.visitor.tree, name), {}) catch unreachable;
            }
        }
    }

    fn visitImportEqualsDeclaration(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const nodeData = self.transformer.visitor.tree.getNode(node).ImportEqualsDeclaration;
        if (self.transformer.visitor.tree.getNode(nodeData.ModuleReference) == .ExternalModuleReference) {
            return self.transformer.visitor.visitEachChild(node);
        }

        const moduleReference = self.transformer.factory.createIdentifier(nodeData.ModuleReference);
        self.transformer.emitContext.setEmitFlags(moduleReference, 0) catch unreachable;
        if (!self.isExportOfNamespace(node)) {
            const varDecl = self.transformer.factory.newVariableDeclaration(nodeData.name, 0, 0, moduleReference);
            self.transformer.emitContext.setOriginal(varDecl, node) catch unreachable;

            const arr = self.transformer.emitContext.allocator.alloc(ast_gen.NodeIndex, 1) catch unreachable;
            arr[0] = varDecl;
            const varList = self.transformer.factory.newVariableDeclarationList(self.transformer.factory.newNodeList(arr), ast_utils.NodeFlags.None);

            const varModifiers = ast_utils.extractModifiers(self.transformer.visitor.tree, (ast_utils.getModifiers(self.transformer.visitor.tree, node) orelse 0), ast_utils.ModifierFlags.Export);
            const varStatement = self.transformer.factory.newVariableStatement(varModifiers, varList);
            self.transformer.emitContext.setOriginal(varStatement, node) catch unreachable;
            self.transformer.emitContext.assignCommentAndSourceMapRanges(varStatement, node);
            return varStatement;
        } else {
            const statement = self.createExportStatement(nodeData.name, moduleReference, ast_utils.getLoc(self.transformer.visitor.tree, node), ast_utils.getLoc(self.transformer.visitor.tree, node), node);
            ast_utils.setLoc(self.transformer.visitor.tree, statement, ast_utils.getLoc(self.transformer.visitor.tree, node));
            return statement;
        }
    }

    fn visitVariableStatement(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        if (self.isExportOfNamespace(node)) {
            var expressions = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
            const nodeData = self.transformer.visitor.tree.getNode(node).VariableStatement;
            const declList = self.transformer.visitor.tree.getNode(nodeData.DeclarationList).VariableDeclarationList;

            for (self.transformer.visitor.tree.getNodeList(declList.Declarations)) |declaration| {
                const v = self.transformer.visitor.tree.getNode(declaration).VariableDeclaration;
                if (v.Initializer == 0) continue;
                if (ast_utils.isBindingPattern(self.transformer.visitor.tree, v.name)) {
                    const expression = ast_utils.flattenDestructuringAssignment(self.transformer, self.transformer.visitor.visitNode(declaration), false, ast_utils.FlattenLevel.All, self, createNamespaceExportExpressionWrapper);
                    if (expression != 0) {
                        expressions.append(std.heap.page_allocator, expression) catch unreachable;
                    }
                } else {
                    const expression = self.createNamespaceExportExpression(v.name, self.transformer.visitor.visitNode(v.Initializer.?), null);
                    if (expression != 0) {
                        expressions.append(std.heap.page_allocator, expression) catch unreachable;
                    }
                }
            }
            if (expressions.items.len == 0) return 0;
            const expression = self.transformer.factory.inlineExpressions(expressions.items);
            var statement = self.transformer.factory.newExpressionStatement(expression);
            self.transformer.emitContext.setOriginal(statement, node) catch unreachable;
            self.transformer.emitContext.assignCommentAndSourceMapRanges(statement, node);

            const savedCurrent = self.currentNode;
            self.currentNode = statement;
            statement = self.transformer.visitor.visitEachChild(statement);
            self.currentNode = savedCurrent;
            return statement;
        }
        return self.transformer.visitor.visitEachChild(node);
    }

    fn createNamespaceExportExpressionWrapper(ctx: *anyopaque, exportName: ast_gen.NodeIndex, exportValue: ast_gen.NodeIndex, location: ?*ast.TextRange) ast_gen.NodeIndex {
        const self = @as(*RuntimeSyntaxTransformer, @ptrCast(@alignCast(ctx)));
        return self.createNamespaceExportExpression(exportName, exportValue, location);
    }

    fn createNamespaceExportExpression(self: *RuntimeSyntaxTransformer, exportName: ast_gen.NodeIndex, exportValue: ast_gen.NodeIndex, location: ?*ast.TextRange) ast_gen.NodeIndex {
        const memberName = self.getNamespaceQualifiedProperty(self.getNamespaceContainerName(self.currentNamespace), exportName);
        const expression = self.transformer.factory.newAssignmentExpression(memberName, exportValue);
        if (location) |loc| {
            ast_utils.setLoc(self.transformer.visitor.tree, expression, loc.*);
        }
        return expression;
    }

    fn visitFunctionDeclaration(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        if (self.isExportOfNamespace(node)) {
            const nodeData = self.transformer.visitor.tree.getNode(node).FunctionDeclaration;
            const updated = self.transformer.factory.updateFunctionDeclaration(node, nodeData, self.transformer.visitor.visitModifiers(ast_utils.extractModifiers(self.transformer.visitor.tree, (nodeData.modifiers orelse 0), ~ast_utils.ModifierFlags.Export)), (nodeData.AsteriskToken orelse 0), self.transformer.visitor.visitNode((nodeData.name orelse 0)), 0, self.transformer.visitor.visitNodes(nodeData.Parameters), 0, self.transformer.visitor.visitNode((nodeData.Body orelse 0)));
            const exportStmt = self.createExportStatementForDeclaration(node);
            if (exportStmt != 0) {
                const arr = self.transformer.emitContext.allocator.alloc(ast_gen.NodeIndex, 2) catch unreachable;
                arr[0] = updated;
                arr[1] = exportStmt;
                return self.transformer.factory.newSyntaxList(arr);
            }
            return updated;
        }
        return self.transformer.visitor.visitEachChild(node);
    }

    fn getParameterProperties(self: *RuntimeSyntaxTransformer, constructor: ast_gen.NodeIndex) []ast_gen.NodeIndex {
        var parameterProperties = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        if (constructor != 0) {
            const constructorData = self.transformer.visitor.tree.getNode(constructor).Constructor;
            for (self.transformer.visitor.tree.getNodeList(constructorData.Parameters)) |parameter| {
                if (ast_utils.isParameterPropertyDeclaration(self.transformer.visitor.tree, parameter, constructor)) {
                    parameterProperties.append(std.heap.page_allocator, parameter) catch unreachable;
                }
            }
        }
        return parameterProperties.items;
    }

    fn visitClassDeclaration(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const exported = self.isExportOfNamespace(node);
        const nodeData = self.transformer.visitor.tree.getNode(node).ClassDeclaration;

        var modifiers: ast_gen.NodeIndex = 0;
        if (exported) {
            modifiers = self.transformer.visitor.visitModifiers(ast_utils.extractModifiers(self.transformer.visitor.tree, (nodeData.modifiers orelse 0), ~ast_utils.ModifierFlags.ExportDefault));
        } else {
            modifiers = self.transformer.visitor.visitModifiers((nodeData.modifiers orelse 0));
        }

        var name = self.transformer.visitor.visitNode((nodeData.name orelse 0));
        if (name == 0 and (exported or ast_utils.childIsDecorated(self.transformer.visitor.tree, self.compilerOptions.experimentalDecorators orelse false, node, 0))) {
            name = self.transformer.factory.newGeneratedNameForNode(node);
        }
        const heritageClauses = self.transformer.visitor.visitNodes((nodeData.HeritageClauses orelse 0));
        var members = self.transformer.visitor.visitNodes(nodeData.Members);

        var constructorNode: ast_gen.NodeIndex = 0;
        for (self.transformer.visitor.tree.getNodeList(nodeData.Members)) |m| {
            if (ast_utils.isConstructorDeclaration(self.transformer.visitor.tree, m)) {
                constructorNode = m;
                break;
            }
        }
        const parameterProperties = self.getParameterProperties(constructorNode);

        if (parameterProperties.len > 0) {
            var newMembers = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
            for (parameterProperties) |parameter| {
                const paramName = ast_utils.getName(self.transformer.visitor.tree, parameter);
                if (ast_utils.isIdentifier(self.transformer.visitor.tree, paramName)) {
                    const parameterProperty = self.transformer.factory.newPropertyDeclaration(0, ast_utils.cloneNode(self.transformer.visitor.tree, self.transformer.factory, paramName), 0, 0, 0);
                    self.transformer.emitContext.setOriginal(parameterProperty, parameter) catch unreachable;
                    newMembers.append(std.heap.page_allocator, parameterProperty) catch unreachable;
                }
            }
            if (newMembers.items.len > 0) {
                for (self.transformer.visitor.tree.getNodeList(members)) |m| {
                    newMembers.append(std.heap.page_allocator, m) catch unreachable;
                }
                members = self.transformer.factory.newNodeList(newMembers.items);
                ast_utils.setLoc(self.transformer.visitor.tree, members, ast_utils.getLoc(self.transformer.visitor.tree, nodeData.Members));
            }
        }

        const updated = self.transformer.factory.updateClassDeclaration(node, nodeData, modifiers, name, 0, heritageClauses, members);
        if (exported) {
            const exportStmt = self.createExportStatementForDeclaration(node);
            if (exportStmt != 0) {
                const arr = self.transformer.emitContext.allocator.alloc(ast_gen.NodeIndex, 2) catch unreachable;
                arr[0] = updated;
                arr[1] = exportStmt;
                return self.transformer.factory.newSyntaxList(arr);
            }
        }
        return updated;
    }

    fn visitClassExpression(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const nodeData = self.transformer.visitor.tree.getNode(node).ClassExpression;

        const modifiers = self.transformer.visitor.visitModifiers(ast_utils.extractModifiers(self.transformer.visitor.tree, (nodeData.modifiers orelse 0), ~ast_utils.ModifierFlags.ExportDefault));
        const name = self.transformer.visitor.visitNode((nodeData.name orelse 0));
        const heritageClauses = self.transformer.visitor.visitNodes((nodeData.HeritageClauses orelse 0));
        var members = self.transformer.visitor.visitNodes(nodeData.Members);

        var constructorNode: ast_gen.NodeIndex = 0;
        for (self.transformer.visitor.tree.getNodeList(nodeData.Members)) |m| {
            if (ast_utils.isConstructorDeclaration(self.transformer.visitor.tree, m)) {
                constructorNode = m;
                break;
            }
        }
        const parameterProperties = self.getParameterProperties(constructorNode);

        if (parameterProperties.len > 0) {
            var newMembers = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
            for (parameterProperties) |parameter| {
                const paramName = ast_utils.getName(self.transformer.visitor.tree, parameter);
                if (ast_utils.isIdentifier(self.transformer.visitor.tree, paramName)) {
                    const parameterProperty = self.transformer.factory.newPropertyDeclaration(0, ast_utils.cloneNode(self.transformer.visitor.tree, self.transformer.factory, paramName), 0, 0, 0);
                    self.transformer.emitContext.setOriginal(parameterProperty, parameter) catch unreachable;
                    newMembers.append(std.heap.page_allocator, parameterProperty) catch unreachable;
                }
            }
            if (newMembers.items.len > 0) {
                for (self.transformer.visitor.tree.getNodeList(members)) |m| {
                    newMembers.append(std.heap.page_allocator, m) catch unreachable;
                }
                members = self.transformer.factory.newNodeList(newMembers.items);
                ast_utils.setLoc(self.transformer.visitor.tree, members, ast_utils.getLoc(self.transformer.visitor.tree, nodeData.Members));
            }
        }

        return self.transformer.factory.updateClassExpression(node, nodeData, modifiers, name, 0, heritageClauses, members);
    }

    fn visitConstructorDeclaration(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const nodeData = self.transformer.visitor.tree.getNode(node).Constructor;
        const modifiers = self.transformer.visitor.visitModifiers((nodeData.modifiers orelse 0));
        const parameters = self.transformer.visitor.visitNodes(nodeData.Parameters);
        const body = self.visitConstructorBody((nodeData.Body orelse 0), node);
        return self.transformer.factory.updateConstructorDeclaration(node, nodeData, modifiers, 0, parameters, 0, body);
    }

    fn visitConstructorBody(self: *RuntimeSyntaxTransformer, body: ast_gen.NodeIndex, constructor: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const parameterProperties = self.getParameterProperties(constructor);
        if (parameterProperties.len == 0) {
            return self.transformer.visitor.visitNode(body);
        }

        const grandparentOfBody = self.pushNode(body);
        const scopeState = self.pushScope(body);

        self.transformer.emitContext.startVariableEnvironment() catch unreachable;
        const bodyData = self.transformer.visitor.tree.getNode(body).Block;
        const bodyNodes = self.transformer.visitor.tree.getNodeList(bodyData.Statements);

        const prologueResult = self.transformer.factory.splitStandardPrologue(bodyNodes);
        var statements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        for (prologueResult.prologue) |p| {
            statements.append(std.heap.page_allocator, p) catch unreachable;
        }

        var parameterPropertyAssignments = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        for (parameterProperties) |parameter| {
            const paramName = ast_utils.getName(self.transformer.visitor.tree, parameter);
            if (ast_utils.isIdentifier(self.transformer.visitor.tree, paramName)) {
                const propertyName = ast_utils.cloneNode(self.transformer.visitor.tree, self.transformer.factory, paramName);
                ast_utils.setParent(self.transformer.visitor.tree, propertyName, ast_utils.getParent(self.transformer.visitor.tree, paramName));
                self.transformer.emitContext.addEmitFlags(propertyName, 0) catch unreachable;

                const localName = ast_utils.cloneNode(self.transformer.visitor.tree, self.transformer.factory, paramName);
                ast_utils.setParent(self.transformer.visitor.tree, localName, ast_utils.getParent(self.transformer.visitor.tree, paramName));
                self.transformer.emitContext.addEmitFlags(localName, printer.EmitFlags.NoComments) catch unreachable;

                const parameterProperty = self.transformer.factory.newExpressionStatement(self.transformer.factory.newAssignmentExpression(self.transformer.factory.newPropertyAccessExpression(self.transformer.factory.newThisExpression(), 0, propertyName, ast_utils.NodeFlags.None), localName));
                self.transformer.emitContext.setOriginal(parameterProperty, parameter) catch unreachable;
                self.transformer.emitContext.addEmitFlags(parameterProperty, printer.EmitFlags.StartOnNewLine) catch unreachable;
                parameterPropertyAssignments.append(std.heap.page_allocator, parameterProperty) catch unreachable;
            }
        }

        const superPath = ast_utils.findSuperStatementIndexPath(prologueResult.statements, 0);

        if (superPath.len > 0) {
            const res = self.transformConstructorBodyWorker(prologueResult.statements, superPath, parameterPropertyAssignments.items);
            for (res) |r| {
                statements.append(std.heap.page_allocator, r) catch unreachable;
            }
        } else {
            for (parameterPropertyAssignments.items) |r| {
                statements.append(std.heap.page_allocator, r) catch unreachable;
            }
            const res = self.transformer.visitor.visitSlice(prologueResult.statements);
            for (res) |r| {
                statements.append(std.heap.page_allocator, r) catch unreachable;
            }
        }

        const mergedStatements = self.transformer.emitContext.endAndMergeVariableEnvironment(statements.items);
        const statementList = self.transformer.factory.newNodeList(mergedStatements);
        ast_utils.setLoc(self.transformer.visitor.tree, statementList, ast_utils.getLoc(self.transformer.visitor.tree, bodyData.Statements));

        self.popScope(scopeState);
        self.popNode(grandparentOfBody);
        const updated = self.transformer.factory.newBlock(statementList, true);
        self.transformer.emitContext.setOriginal(updated, body) catch unreachable;
        ast_utils.setLoc(self.transformer.visitor.tree, updated, ast_utils.getLoc(self.transformer.visitor.tree, body));
        return updated;
    }

    fn transformConstructorBodyWorker(self: *RuntimeSyntaxTransformer, statementsIn: []const ast_gen.NodeIndex, superPath: []const ast_gen.NodeIndex, initializerStatements: []ast_gen.NodeIndex) []ast_gen.NodeIndex {
        var statementsOut = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        const superStatementIndex = @as(usize, @intCast(superPath[0]));
        const superStatement = statementsIn[superStatementIndex];

        const visitedBefore = self.transformer.visitor.visitSlice(statementsIn[0..superStatementIndex]);
        for (visitedBefore) |v| {
            statementsOut.append(std.heap.page_allocator, v) catch unreachable;
        }

        if (ast_utils.isTryStatement(self.transformer.visitor.tree, superStatement)) {
            const tryStatementData = self.transformer.visitor.tree.getNode(superStatement).TryStatement;
            const tryBlock = tryStatementData.TryBlock;

            const grandparentOfTryStatement = self.pushNode(superStatement);
            const grandparentOfTryBlock = self.pushNode(tryBlock);
            const scopeState = self.pushScope(tryBlock);

            const tryBlockData = self.transformer.visitor.tree.getNode(tryBlock).Block;
            const tryBlockStatementsIn = self.transformer.visitor.tree.getNodeList(tryBlockData.Statements);
            const tryBlockStatementsOut = self.transformConstructorBodyWorker(tryBlockStatementsIn, superPath[1..], initializerStatements);

            self.popScope(scopeState);
            self.popNode(grandparentOfTryBlock);

            const tryBlockStatementList = self.transformer.factory.newNodeList(tryBlockStatementsOut);
            ast_utils.setLoc(self.transformer.visitor.tree, tryBlockStatementList, ast_utils.getLoc(self.transformer.visitor.tree, tryBlockData.Statements));

            statementsOut.append(std.heap.page_allocator, self.transformer.factory.updateTryStatement(
                superStatement,
                tryStatementData,
                self.transformer.factory.updateBlock(tryBlock, tryBlockData, tryBlockStatementList, tryBlockData.MultiLine),
                self.transformer.visitor.visitNode(tryStatementData.CatchClause orelse 0),
                self.transformer.visitor.visitNode(tryStatementData.FinallyBlock orelse 0),
            )) catch unreachable;

            self.popNode(grandparentOfTryStatement);
        } else {
            const visitedSuper = self.transformer.visitor.visitSlice(statementsIn[superStatementIndex .. superStatementIndex + 1]);
            for (visitedSuper) |v| {
                statementsOut.append(std.heap.page_allocator, v) catch unreachable;
            }

            for (initializerStatements) |i| {
                statementsOut.append(std.heap.page_allocator, i) catch unreachable;
            }
        }

        const visitedAfter = self.transformer.visitor.visitSlice(statementsIn[superStatementIndex + 1 ..]);
        for (visitedAfter) |v| {
            statementsOut.append(std.heap.page_allocator, v) catch unreachable;
        }

        return statementsOut.items;
    }

    fn visitShorthandPropertyAssignment(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const nodeData = self.transformer.visitor.tree.getNode(node).ShorthandPropertyAssignment;
        const name = nodeData.name;
        const exportedOrImportedName = self.visitExpressionIdentifier(name);
        if (exportedOrImportedName != name) {
            var expression = exportedOrImportedName;
            if (nodeData.ObjectAssignmentInitializer != 0) {
                var equalsToken = nodeData.EqualsToken;
                if (equalsToken == 0) {
                    equalsToken = self.transformer.factory.newToken(.EqualsToken);
                }
                expression = self.transformer.factory.newBinaryExpression(0, expression, 0, equalsToken orelse 0, self.transformer.visitor.visitNode(nodeData.ObjectAssignmentInitializer orelse 0));
            }

            const updated = self.transformer.factory.newPropertyAssignment(0, name, 0, 0, expression);
            ast_utils.setLoc(self.transformer.visitor.tree, updated, ast_utils.getLoc(self.transformer.visitor.tree, node));
            self.transformer.emitContext.setOriginal(updated, node) catch unreachable;
            self.transformer.emitContext.assignCommentAndSourceMapRanges(updated, node);
            return updated;
        }
        return self.transformer.factory.updateShorthandPropertyAssignment(node, 0, exportedOrImportedName, 0, 0, nodeData.EqualsToken, self.transformer.visitor.visitNode(nodeData.ObjectAssignmentInitializer orelse 0));
    }

    fn visitIdentifier(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        if (ast_utils.isIdentifierReference(self.transformer.visitor.tree, node, self.parentNode)) {
            return self.visitExpressionIdentifier(node);
        }
        return node;
    }

    fn visitExpressionIdentifier(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        if ((self.currentEnum != 0 or self.currentNamespace != 0) and !ast_utils.isGeneratedIdentifier(self.transformer.emitContext, node) and !ast_utils.isLocalName(self.transformer.emitContext, node)) {
            if (self.currentNamespace != 0 and self.namespaceExportNames.contains(ast_utils.getText(self.transformer.visitor.tree, node))) {
                const memberName = ast_utils.cloneNode(self.transformer.visitor.tree, self.transformer.factory, node);
                return self.transformer.factory.getNamespaceMemberName(self.getNamespaceContainerName(self.currentNamespace), memberName, .{ .allowSourceMaps = true });
            }
            const location = ast_utils.mostOriginal(self.transformer.visitor.tree, node);

            if (self.resolver) |resolver| {
                const container = resolver.getReferencedExportContainer(location, false);
                if (container != 0 and (ast_utils.isEnumDeclaration(self.transformer.visitor.tree, container orelse 0) or ast_utils.isModuleDeclaration(self.transformer.visitor.tree, container orelse 0))) {
                    const containerName = self.getNamespaceContainerName(container orelse 0);

                    const memberName = ast_utils.cloneNode(self.transformer.visitor.tree, self.transformer.factory, node);
                    self.transformer.emitContext.setEmitFlags(memberName, 0) catch unreachable;

                    const expression = self.transformer.factory.getNamespaceMemberName(containerName, memberName, .{ .allowSourceMaps = true });
                    self.transformer.emitContext.assignCommentAndSourceMapRanges(expression, node);
                    return expression;
                }
            }
        }
        return node;
    }

    fn createExportStatementForDeclaration(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const exportName = self.transformer.factory.getExternalModuleOrNamespaceExportName(self.getNamespaceContainerName(self.currentNamespace), node, false, true);
        const localName = self.transformer.factory.getLocalName(node);
        const expression = self.transformer.factory.newAssignmentExpression(exportName, localName);

        var exportAssignmentSourceMapRange = ast_utils.getLoc(self.transformer.visitor.tree, node);
        const nameNode = ast_utils.getName(self.transformer.visitor.tree, node);
        if (nameNode != 0) {
            exportAssignmentSourceMapRange = ast_utils.withPos(exportAssignmentSourceMapRange, ast_utils.getPos(self.transformer.visitor.tree, nameNode));
        }
        self.transformer.emitContext.setSourceMapRange(expression, exportAssignmentSourceMapRange);

        const statement = self.transformer.factory.newExpressionStatement(expression);
        const exportStatementSourceMapRange = ast_utils.withPos(ast_utils.getLoc(self.transformer.visitor.tree, node), -1);
        self.transformer.emitContext.setSourceMapRange(statement, exportStatementSourceMapRange);
        return statement;
    }

    fn createExportAssignment(self: *RuntimeSyntaxTransformer, name: ast_gen.NodeIndex, expression: ast_gen.NodeIndex, exportAssignmentSourceMapRange: ast.TextRange, original: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const exportName = self.getNamespaceQualifiedProperty(self.getNamespaceContainerName(self.currentNamespace), name);
        const exportAssignment = self.transformer.factory.newAssignmentExpression(exportName, expression);
        self.transformer.emitContext.setOriginal(exportAssignment, original) catch unreachable;
        self.transformer.emitContext.setSourceMapRange(exportAssignment, exportAssignmentSourceMapRange);
        return exportAssignment;
    }

    fn createExportStatement(self: *RuntimeSyntaxTransformer, name: ast_gen.NodeIndex, expression: ast_gen.NodeIndex, exportAssignmentSourceMapRange: ast.TextRange, exportStatementSourceMapRange: ast.TextRange, original: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const exportStatement = self.transformer.factory.newExpressionStatement(self.createExportAssignment(name, expression, exportAssignmentSourceMapRange, original));
        self.transformer.emitContext.setOriginal(exportStatement, original) catch unreachable;
        self.transformer.emitContext.setSourceMapRange(exportStatement, exportStatementSourceMapRange);
        return exportStatement;
    }

    fn shouldEmitEnumDeclaration(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) bool {
        return !ast_utils.isEnumConst(self.transformer.visitor.tree, node) or (self.compilerOptions.preserveConstEnums orelse false);
    }

    fn shouldEmitModuleDeclaration(self: *RuntimeSyntaxTransformer, node: ast_gen.NodeIndex) bool {
        return ast_utils.isInstantiatedModule(self.transformer.visitor.tree, node, self.compilerOptions.preserveConstEnums orelse false);
    }
};

fn getInnermostModuleDeclarationFromDottedModule(tree: *ast.Ast, moduleDeclaration: ast_gen.NodeIndex) ast_gen.NodeIndex {
    var current = moduleDeclaration;
    while (true) {
        const nodeData = tree.getNode(current).ModuleDeclaration;
        if ((nodeData.Body orelse 0) != 0 and tree.getNode((nodeData.Body orelse 0)) == .ModuleDeclaration) {
            current = (nodeData.Body orelse 0);
        } else {
            break;
        }
    }
    return current;
}
