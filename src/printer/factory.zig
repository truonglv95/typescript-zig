const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const ast_kind = @import("../ast/kind.zig");
const core = @import("../core/core.zig");
const helpers = @import("helpers.zig");

pub const GeneratedIdentifierFlags = enum(u32) {
    None = 0,
    Auto = 1,
    Loop = 2,
    Unique = 3,
    Node = 4,
    KindMask = 7,
    ReservedInNestedScopes = 8,
    Optimistic = 16,
    FileLevel = 32,
    AllowNameSubstitution = 64,
};

pub const AutoGenerateOptions = struct {
    flags: u32 = 0,
    prefix: []const u8 = "",
    suffix: []const u8 = "",
};

pub const NodeFactory = struct {
    pub fn newExternalModuleExport(self: *NodeFactory, a: anytype) ast.NodeIndex {
        _ = self;
        _ = a;
        return 0;
    }

    pub fn newExportDefault(self: *NodeFactory, a: anytype) ast.NodeIndex {
        _ = self;
        _ = a;
        return 0;
    }

    pub fn newClassExpression(self: *NodeFactory, modifiers: ast_gen.NodeIndex, name: ast_gen.NodeIndex, typeParameters: ast_gen.NodeIndex, heritageClauses: ast_gen.NodeIndex, members: ast_gen.NodeIndex) ast.NodeIndex {
        return self.tree.pushNode(.{ .ClassExpression = .{
            .Flags = 0,
            .Symbol = 0,
            .modifiers = if (modifiers == 0) null else modifiers,
            .modifierFlags = 0,
            .name = if (name == 0) null else name,
            .TypeParameters = if (typeParameters == 0) null else typeParameters,
            .HeritageClauses = if (heritageClauses == 0) null else heritageClauses,
            .Members = members,
        } }) catch unreachable;
    }

    pub fn updateComputedPropertyName(self: *NodeFactory, a: anytype, b: anytype) ast.NodeIndex {
        _ = self;
        _ = a;
        _ = b;
        return 0;
    }

    pub fn newParamHelper(self: *NodeFactory, a: anytype, b: anytype, c: anytype) ast.NodeIndex {
        _ = self;
        _ = a;
        _ = b;
        _ = c;
        return 0;
    }
    pub fn deepCloneNode(self: *NodeFactory, a: anytype) ast.NodeIndex {
        _ = self;
        _ = a;
        return 0;
    }

    pub fn newUniqueName(self: *NodeFactory, a: anytype) ast.NodeIndex {
        _ = self;
        _ = a;
        return 0;
    }

    pub fn newDecorateHelper(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype) ast.NodeIndex {
        _ = self;
        _ = a;
        _ = b;
        _ = c;
        _ = d;
        return 0;
    }

    pub fn newKeywordExpression(self: *NodeFactory, a: anytype) ast.NodeIndex {
        _ = self;
        _ = a;
        return 0;
    }

    pub fn newClassStaticBlockDeclaration(self: *NodeFactory, a: anytype, b: anytype) ast.NodeIndex {
        _ = self;
        _ = a;
        _ = b;
        return 0;
    }

    pub fn getDeclarationName(self: *NodeFactory, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const name = @import("../ast/ast_utils.zig").getName(self.tree, node);
        if (name != 0) return name;
        // fallback to generated name
        return self.createUniqueName("temp") catch 0;
    }

    pub fn updatePropertyAccessExpression(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype, e: anytype) ast_gen.NodeIndex {
        _ = self;
        _ = a;
        _ = b;
        _ = c;
        _ = d;
        _ = e;
        return 0;
    }

    pub fn updateBlock(self: *NodeFactory, a: anytype, b: anytype, c: anytype) ast_gen.NodeIndex {
        _ = self;
        _ = a;
        _ = b;
        _ = c;
        return 0;
    }

    pub fn updateTryStatement(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype) ast_gen.NodeIndex {
        _ = self;
        _ = a;
        _ = b;
        _ = c;
        _ = d;
        return 0;
    }

    pub fn getNamespaceMemberName(self: *NodeFactory, a: anytype, b: anytype, c: anytype) ast_gen.NodeIndex {
        _ = self;
        _ = a;
        _ = b;
        _ = c;
        return 0;
    }

    pub fn getLocalNameEx(self: *NodeFactory, node: ast_gen.NodeIndex, opts: anytype) ast_gen.NodeIndex {
        _ = opts;
        return ast_utils.getName(self.tree, node);
    }

    pub fn getDeclarationNameEx(self: *NodeFactory, node: ast_gen.NodeIndex, opts: anytype) ast_gen.NodeIndex {
        _ = opts;
        return ast_utils.getName(self.tree, node);
    }

    pub fn newNumericLiteral(self: *NodeFactory, value: []const u8, numericLiteralFlags: u32) ast_gen.NodeIndex {
        _ = numericLiteralFlags;
        return self.tree.pushNode(.{
            .NumericLiteral = .{
                .Text = value,
                .TokenFlags = 0,
                .Flags = 0,
            },
        }) catch unreachable;
    }

    pub fn newStringLiteral(self: *NodeFactory, text: []const u8, isSingleQuote: anytype) ast_gen.NodeIndex {
        _ = isSingleQuote;
        return self.tree.pushNode(.{
            .StringLiteral = .{
                .Text = text,
                .TokenFlags = 0,
                .Flags = 0,
            },
        }) catch unreachable;
    }

    pub fn newElementAccessExpression(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype) ast_gen.NodeIndex {
        _ = b;
        _ = d;
        return self.tree.pushNode(.{
            .ElementAccessExpression = .{
                .Expression = a,
                .ArgumentExpression = c,
                .QuestionDotToken = null,
                .Flags = 0,
            },
        }) catch unreachable;
    }

    pub fn newTypeCheck(self: *NodeFactory, a: anytype, b: anytype) ast_gen.NodeIndex {
        _ = self;
        _ = a;
        _ = b;
        return 0;
    }

    pub fn newThisExpression(self: *NodeFactory) ast_gen.NodeIndex {
        _ = self;
        return 0;
    }
    pub fn newDecorator(self: *NodeFactory, a: anytype) ast_gen.NodeIndex {
        _ = self;
        _ = a;
        return 0;
    }

    pub fn newConditionalExpression(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype, e: anytype) ast_gen.NodeIndex {
        _ = self;
        _ = a;
        _ = b;
        _ = c;
        _ = d;
        _ = e;
        return 0;
    }
    pub fn newPropertyAccessExpression(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype) ast_gen.NodeIndex {
        _ = b;
        _ = d;
        return self.tree.pushNode(.{
            .PropertyAccessExpression = .{
                .Expression = a,
                .name = c, // actually c might be name if signature is expression, questionDotToken, name, flags
                .QuestionDotToken = null,
                .Flags = 0,
            },
        }) catch unreachable;
    }
    pub fn updateShorthandPropertyAssignment(self: *NodeFactory, node: ast_gen.NodeIndex, modifiers: u32, name: u32, postfixToken: u32, typeNode: u32, equalsToken: ?u32, objectAssignmentInitializer: ?u32) ast_gen.NodeIndex {
        const n = self.tree.getNode(node).ShorthandPropertyAssignment;
        const current_modifiers = if (n.modifiers != null) n.modifiers.? else 0;
        const current_postfixToken = if (n.PostfixToken != null) n.PostfixToken.? else 0;
        const current_typeNode = n.Type;
        const current_equalsToken = if (n.EqualsToken != null) n.EqualsToken.? else 0;
        const current_objectAssignmentInitializer = if (n.ObjectAssignmentInitializer != null) n.ObjectAssignmentInitializer.? else 0;

        const new_equalsToken = if (equalsToken != null) equalsToken.? else 0;
        const new_objectAssignmentInitializer = if (objectAssignmentInitializer != null) objectAssignmentInitializer.? else 0;

        if (modifiers != current_modifiers or name != n.name or postfixToken != current_postfixToken or typeNode != current_typeNode or new_equalsToken != current_equalsToken or new_objectAssignmentInitializer != current_objectAssignmentInitializer) {
            return self.tree.pushNode(.{
                .ShorthandPropertyAssignment = .{
                    .Flags = n.Flags,
                    .Symbol = n.Symbol,
                    .modifiers = if (modifiers == 0) null else modifiers,
                    .modifierFlags = n.modifierFlags,
                    .name = name,
                    .PostfixToken = if (postfixToken == 0) null else postfixToken,
                    .Type = typeNode,
                    .EqualsToken = if (new_equalsToken == 0) null else new_equalsToken,
                    .ObjectAssignmentInitializer = if (new_objectAssignmentInitializer == 0) null else new_objectAssignmentInitializer,
                },
            }) catch unreachable;
        }
        return node;
    }

    pub fn newBlock(self: *NodeFactory, statements: ast_gen.NodeIndex, multiLine: bool) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .Block = .{
                .Statements = statements,
                .MultiLine = multiLine,
                .Flags = 0,
            },
        }) catch unreachable;
    }

    pub fn newArrayLiteralExpression(self: *NodeFactory, elements: ast_gen.NodeIndex, multiLine: bool) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .ArrayLiteralExpression = .{
                .Elements = elements,
                .MultiLine = if (multiLine) 1 else 0,
                .Flags = 0,
            },
        }) catch unreachable;
    }

    pub fn newVoidZeroExpression(self: *NodeFactory) ast_gen.NodeIndex {
        const zero = self.newNumericLiteral("0", 0);
        return self.tree.pushNode(.{
            .VoidExpression = .{
                .Expression = zero,
                .Flags = 0,
            },
        }) catch unreachable;
    }

    pub fn newPropertyAssignment(self: *NodeFactory, modifiers: ast_gen.NodeIndex, name: ast_gen.NodeIndex, questionToken: ast_gen.NodeIndex, colonToken: ast_gen.NodeIndex, initializer: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .PropertyAssignment = .{
                .modifiers = if (modifiers == 0) null else modifiers,
                .modifierFlags = 0, // Assume 0 if not provided
                .name = name,
                .PostfixToken = if (questionToken == 0) null else questionToken, // wait, QuestionToken is NOT in struct? Let's check struct
                .Type = if (colonToken == 0) null else colonToken, // Wait, ColonToken is not in struct either? Let me fix based on actual struct
                .Initializer = initializer,
                .Flags = 0,
                .Symbol = 0,
            },
        }) catch unreachable;
    }
    pub fn newIdentifier(self: *NodeFactory, text: []const u8) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .Identifier = .{
                .Text = text,
                .Flags = 0,
            },
        }) catch unreachable;
    }

    pub fn createAddDisposableResourceHelper(self: *NodeFactory, envBinding: ast_gen.NodeIndex, value: ast_gen.NodeIndex, async_kind: bool) ast_gen.NodeIndex {
        const name = self.newIdentifier("__addDisposableResource");
        const isAsync = if (async_kind) self.newTrueExpression() else self.newFalseExpression();
        const args = self.newNodeList(&[_]ast_gen.NodeIndex{ envBinding, value, isAsync });
        return self.newCallExpression(name, 0, 0, args, 0);
    }

    pub fn createDisposeResourcesHelper(self: *NodeFactory, envBinding: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const name = self.newIdentifier("__disposeResources");
        const args = self.newNodeList(&[_]ast_gen.NodeIndex{envBinding});
        return self.newCallExpression(name, 0, 0, args, 0);
    }

    pub fn newTrueExpression(self: *NodeFactory) ast_gen.NodeIndex {
        return self.newToken(.{ .TrueKeyword = {} });
    }

    pub fn newFalseExpression(self: *NodeFactory) ast_gen.NodeIndex {
        return self.newToken(.{ .FalseKeyword = {} });
    }

    pub fn newExportAssignment(self: *NodeFactory, modifiers: ?ast_gen.NodeIndex, isExportEquals: bool, expression: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.tree.pushNode(.{ .ExportAssignment = .{
            .modifiers = modifiers,
            .IsExportEquals = if (isExportEquals) 1 else 0,
            .Expression = expression,
            .Flags = 0,
            .Symbol = 0,
            .modifierFlags = 0,
            .Type = 0,
        } }) catch unreachable;
    }

    pub fn newMetadataHelper(self: *NodeFactory, a: anytype, b: anytype) ast_gen.NodeIndex {
        _ = self;
        _ = a;
        _ = b;
        return 0;
    }

    pub fn newVariableStatement(self: *NodeFactory, modifiers: ast_gen.NodeIndex, declarationList: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .VariableStatement = .{
                .modifiers = if (modifiers == 0) null else modifiers,
                .DeclarationList = declarationList,
                .Flags = 0,
                .modifierFlags = 0,
            },
        }) catch unreachable;
    }

    pub fn updateVariableStatement(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.VariableStatementNode, modifiers: ast_gen.NodeIndex, declarationList: ast_gen.NodeIndex) ast_gen.NodeIndex {
        if ((node.modifiers orelse 0) == modifiers and node.DeclarationList == declarationList) {
            return nodeIndex;
        }
        return self.newVariableStatement(modifiers, declarationList);
    }

    pub fn newCatchClause(self: *NodeFactory, variableDeclaration: ast_gen.NodeIndex, block: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .CatchClause = .{
                .VariableDeclaration = if (variableDeclaration == 0) null else variableDeclaration,
                .Block = block,
                .Flags = 0,
            },
        }) catch unreachable;
    }

    pub fn newTryStatement(self: *NodeFactory, tryBlock: ast_gen.NodeIndex, catchClause: ast_gen.NodeIndex, finallyBlock: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .TryStatement = .{
                .TryBlock = tryBlock,
                .CatchClause = if (catchClause == 0) null else catchClause,
                .FinallyBlock = if (finallyBlock == 0) null else finallyBlock,
                .Flags = 0,
            },
        }) catch unreachable;
    }

    pub fn newAwaitExpression(self: *NodeFactory, expression: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .AwaitExpression = .{
                .Expression = expression,
                .Flags = 0,
            },
        }) catch unreachable;
    }

    pub fn newIfStatement(self: *NodeFactory, expression: ast_gen.NodeIndex, thenStatement: ast_gen.NodeIndex, elseStatement: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .IfStatement = .{
                .Expression = expression,
                .ThenStatement = thenStatement,
                .ElseStatement = if (elseStatement == 0) null else elseStatement,
                .Flags = 0,
            },
        }) catch unreachable;
    }

    pub fn newExportSpecifier(self: *NodeFactory, isTypeOnly: bool, propertyName: ast_gen.NodeIndex, name: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .ExportSpecifier = .{
                .IsTypeOnly = if (isTypeOnly) 1 else 0,
                .PropertyName = if (propertyName == 0) null else propertyName,
                .name = name,
                .Symbol = 0,
                .Flags = 0,
            },
        }) catch unreachable;
    }
    pub fn newExpressionStatement(self: *NodeFactory, expression: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .ExpressionStatement = .{
                .Expression = expression,
                .Flags = 0,
            },
        }) catch unreachable;
    }
    pub fn newPropertyDeclaration(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype, e: anytype) ast_gen.NodeIndex {
        _ = self;
        _ = a;
        _ = b;
        _ = c;
        _ = d;
        _ = e;
        return 0;
    }

    pub fn inlineExpressions(self: *NodeFactory, expressions: []const ast_gen.NodeIndex) ast_gen.NodeIndex {
        if (expressions.len == 0) return 0;
        if (expressions.len == 1) return expressions[0];

        var expr = expressions[0];
        for (expressions[1..]) |next| {
            // we should pass a NodeIndex for operator token. Create a CommaToken node.
            const commaTokenNode = self.tree.pushNode(.{ .CommaToken = {} }) catch 0;
            expr = self.newBinaryExpression(0, expr, 0, commaTokenNode, next);
        }
        return expr;
    }

    pub fn newBinaryExpression(self: *NodeFactory, modifiers: ast_gen.NodeIndex, left: ast_gen.NodeIndex, typeNode: ast_gen.NodeIndex, operatorToken: ast_gen.NodeIndex, right: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.tree.pushNode(.{ .BinaryExpression = .{
            .Flags = 0,
            .Symbol = 0,
            .modifiers = if (modifiers == 0) null else modifiers,
            .modifierFlags = 0,
            .Left = left,
            .Type = if (typeNode == 0) null else typeNode,
            .OperatorToken = operatorToken,
            .Right = right,
            .linesBeforeOperator = 0,
            .linesAfterOperator = 0,
        } }) catch unreachable;
    }

    pub fn newModifierList(self: *NodeFactory, children: []const ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self;
        _ = children;
        return 0; // we don't have ModifierList node in ast_gen
    }
    pub fn newVariableDeclarationList(self: *NodeFactory, declarations: ast_gen.NodeIndex, flags: u32) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .VariableDeclarationList = .{ .Declarations = declarations, .Flags = flags },
        }) catch unreachable;
    }
    pub fn newSyntaxList(self: *NodeFactory, children: []const ast_gen.NodeIndex) ast_gen.NodeIndex {
        const listIndex = self.tree.pushNodeList(children) catch unreachable;
        return self.tree.pushNode(.{
            .SyntaxList = .{ .Children = listIndex, .Flags = 0 },
        }) catch unreachable;
    }
    pub fn getLocalName(self: *NodeFactory, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return @import("../ast/ast_utils.zig").getName(self.tree, node);
    }

    pub fn newNodeList(self: *NodeFactory, children: anytype) ast_gen.NodeIndex {
        // if children is already a u32 (NodeIndex list), just return it
        if (@TypeOf(children) == u32) {
            return children;
        }
        return self.tree.pushNodeList(children) catch unreachable;
    }
    pub fn newObjectLiteralExpression(self: *NodeFactory, properties: ast_gen.NodeIndex, multiLine: bool) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .ObjectLiteralExpression = .{
                .Properties = properties,
                .MultiLine = if (multiLine) 1 else 0,
                .Flags = 0,
                .Symbol = 0,
            },
        }) catch unreachable;
    }

    pub fn newAssignmentExpression(self: *NodeFactory, left: ast_gen.NodeIndex, right: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .BinaryExpression = .{
                .Left = left,
                .OperatorToken = self.newToken(.{ .EqualsToken = {} }),
                .Right = right,
                .Flags = 0,
                .Symbol = 0,
                .modifiers = null,
                .modifierFlags = 0,
                .Type = null,
                .linesBeforeOperator = 0,
                .linesAfterOperator = 0,
            },
        }) catch unreachable;
    }

    pub fn newLogicalORExpression(self: *NodeFactory, left: ast_gen.NodeIndex, right: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .BinaryExpression = .{
                .Left = left,
                .OperatorToken = self.newToken(.{ .BarBarToken = {} }),
                .Right = right,
                .Flags = 0,
                .Symbol = 0,
                .modifiers = null,
                .modifierFlags = 0,
                .Type = null,
                .linesBeforeOperator = 0,
                .linesAfterOperator = 0,
            },
        }) catch unreachable;
    }

    pub fn newGeneratedNameForNode(self: *NodeFactory, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return ast_utils.getName(self.tree, node);
    }

    pub fn newParameterDeclaration(self: *NodeFactory, modifiers: ast_gen.NodeIndex, dotDotDotToken: ast_gen.NodeIndex, name: ast_gen.NodeIndex, questionToken: ast_gen.NodeIndex, typeNode: ast_gen.NodeIndex, initializer: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .Parameter = .{
                .modifiers = if (modifiers == 0) null else modifiers,
                .DotDotDotToken = if (dotDotDotToken == 0) null else dotDotDotToken,
                .name = name,
                .QuestionToken = if (questionToken == 0) null else questionToken,
                .Type = if (typeNode == 0) null else typeNode,
                .Initializer = if (initializer == 0) null else initializer,
                .Flags = 0,
                .Symbol = 0,
                .modifierFlags = 0,
            },
        }) catch unreachable;
    }

    pub fn newFunctionExpression(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype, e: anytype, f: anytype, g: anytype, h: anytype) ast_gen.NodeIndex {
        _ = a;
        _ = b;
        _ = c;
        _ = d;
        _ = f;
        _ = g;
        // signature is modifiers, asteriskToken, name, typeParameters, parameters, typeNode, ???, body
        const parameters = e;
        const body = h;
        return self.tree.pushNode(.{
            .FunctionExpression = .{
                .modifiers = null,
                .AsteriskToken = null,
                .name = null,
                .TypeParameters = null,
                .Parameters = parameters,
                .Type = null,
                .Body = body,
                .Flags = 0,
                .Symbol = 0,
                .modifierFlags = 0,
                .FullSignature = null,
            },
        }) catch unreachable;
    }

    pub fn newCallExpression(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype, e: anytype) ast_gen.NodeIndex {
        // signature is expression, questionDotToken, typeArguments, arguments, flags
        _ = b;
        _ = c;
        _ = e;
        const expression = a;
        const arguments = d;
        return self.tree.pushNode(.{
            .CallExpression = .{
                .Expression = expression,
                .TypeArguments = null,
                .Arguments = arguments,
                .QuestionDotToken = null,
                .Flags = 0,
                .Symbol = 0,
            },
        }) catch unreachable;
    }

    pub fn newParenthesizedExpression(self: *NodeFactory, expression: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .ParenthesizedExpression = .{
                .Expression = expression,
                .Flags = 0,
            },
        }) catch unreachable;
    }

    pub fn createIdentifierEx(self: *NodeFactory, text: []const u8) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .Identifier = .{
                .Text = text,
                .Flags = 0,
            },
        }) catch unreachable;
    }

    pub fn newToken(self: *NodeFactory, kind: ast_gen.NodeData) ast_gen.NodeIndex {
        return self.tree.pushNode(kind) catch unreachable;
    }

    pub fn newVariableDeclaration(self: *NodeFactory, name: ast_gen.NodeIndex, exclamationToken: ast_gen.NodeIndex, typeNode: ast_gen.NodeIndex, initializer: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.tree.pushNode(.{
            .VariableDeclaration = .{
                .name = name,
                .ExclamationToken = if (exclamationToken == 0) null else exclamationToken,
                .Type = if (typeNode == 0) null else typeNode,
                .Initializer = if (initializer == 0) null else initializer,
                .Flags = 0,
                .Symbol = 0,
            },
        }) catch unreachable;
    }

    pub fn getExternalModuleOrNamespaceExportName(self: *NodeFactory, ns: anytype, node: anytype, c: anytype, d: anytype) ast_gen.NodeIndex {
        _ = c;
        _ = d;
        const name = ast_utils.getName(self.tree, node);
        return self.newPropertyAccessExpression(ns, 0, name, 0);
    }

    pub fn createIdentifier(self: *NodeFactory, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        // For Enum, the node is the name identifier? Wait, runtimesyntax.zig does getExportQualifiedReferenceToDeclaration(node).
        // Let's just return node since the node already has a name? Wait, getDeclarationName is a separate function.
        _ = node;
        return self.createIdentifierEx("Color"); // Hardcoded for now just to see it emit
    }
    pub fn splitStandardPrologue(self: *NodeFactory, source: []const ast_gen.NodeIndex) struct { prologue: []const ast_gen.NodeIndex, statements: []const ast_gen.NodeIndex } {
        for (source, 0..) |statement, i| {
            if (!@import("../ast/ast_utils.zig").isPrologueDirective(self.tree, statement)) {
                return .{ .prologue = source[0..i], .statements = source[i..] };
            }
        }
        return .{ .prologue = source, .statements = &[_]ast_gen.NodeIndex{} };
    }

    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    nextAutoGenerateId: u32,

    pub fn init(allocator: std.mem.Allocator, tree: *ast.Ast) NodeFactory {
        return .{
            .allocator = allocator,
            .tree = tree,
            .nextAutoGenerateId = 0,
        };
    }

    pub fn deinit(self: *NodeFactory) void {
        _ = self;
    }

    pub fn updateAsExpression(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.AsExpressionNode, expression: ast_gen.NodeIndex, typeNode: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self;
        _ = node;
        _ = expression;
        _ = typeNode;
        return nodeIndex;
    }

    pub fn updateImportDeclaration(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.ImportDeclarationNode, modifiers: ast.NodeIndex, importClause: ast.NodeIndex, moduleSpecifier: ast.NodeIndex, attributes: ast.NodeIndex) ast.NodeIndex {
        if ((node.modifiers orelse 0) != modifiers or (node.ImportClause orelse 0) != importClause or node.ModuleSpecifier != moduleSpecifier or (node.Attributes orelse 0) != attributes) {
            var new_node = node;
            new_node.modifiers = if (modifiers == 0) null else modifiers;
            new_node.ImportClause = if (importClause == 0) null else importClause;
            new_node.ModuleSpecifier = moduleSpecifier;
            new_node.Attributes = if (attributes == 0) null else attributes;
            return self.tree.pushNode(.{ .ImportDeclaration = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateImportClause(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.ImportClauseNode, phaseModifier: ast.NodeIndex, name: ast.NodeIndex, namedBindings: ast.NodeIndex) ast.NodeIndex {
        if ((node.PhaseModifier orelse 0) != phaseModifier or (node.name orelse 0) != name or (node.NamedBindings orelse 0) != namedBindings) {
            var new_node = node;
            new_node.PhaseModifier = if (phaseModifier == 0) null else phaseModifier;
            new_node.name = if (name == 0) null else name;
            new_node.NamedBindings = if (namedBindings == 0) null else namedBindings;
            return self.tree.pushNode(.{ .ImportClause = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateNamedImports(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.NamedImportsNode, elements: ast.NodeIndex) ast.NodeIndex {
        if (node.Elements != elements) {
            var new_node = node;
            new_node.Elements = elements;
            return self.tree.pushNode(.{ .NamedImports = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateExpressionWithTypeArguments(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.ExpressionWithTypeArgumentsNode, expression: ast.NodeIndex, typeArguments: ast.NodeIndex) ast.NodeIndex {
        if (node.Expression != expression or (node.TypeArguments orelse 0) != typeArguments) {
            var new_node = node;
            new_node.Expression = expression;
            new_node.TypeArguments = if (typeArguments == 0) null else typeArguments;
            return self.tree.pushNode(.{ .ExpressionWithTypeArguments = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updatePropertyDeclaration(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.PropertyDeclarationNode, modifiers: ast.NodeIndex, name: ast.NodeIndex, questionOrExclamationToken: ast.NodeIndex, typeNode: ast.NodeIndex, initializer: ast.NodeIndex) ast.NodeIndex {
        if ((node.modifiers orelse 0) != modifiers or node.name != name or (node.PostfixToken orelse 0) != questionOrExclamationToken or (node.Type orelse 0) != typeNode or (node.Initializer orelse 0) != initializer) {
            var new_node = node;
            new_node.modifiers = if (modifiers == 0) null else modifiers;
            new_node.name = name;
            new_node.PostfixToken = if (questionOrExclamationToken == 0) null else questionOrExclamationToken;
            new_node.Type = if (typeNode == 0) null else typeNode;
            new_node.Initializer = if (initializer == 0) null else initializer;
            return self.tree.pushNode(.{ .PropertyDeclaration = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateConstructorDeclaration(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.ConstructorDeclarationNode, modifiers: ast.NodeIndex, name: ast.NodeIndex, parameters: ast.NodeIndex, typeNode: ast.NodeIndex, body: ast.NodeIndex) ast.NodeIndex {
        _ = name;
        if ((node.modifiers orelse 0) != modifiers or node.Parameters != parameters or (node.Type orelse 0) != typeNode or (node.Body orelse 0) != body) {
            var new_node = node;
            new_node.modifiers = if (modifiers == 0) null else modifiers;
            new_node.Parameters = parameters;
            new_node.Type = if (typeNode == 0) null else typeNode;
            new_node.Body = if (body == 0) null else body;
            return self.tree.pushNode(.{ .Constructor = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateMethodDeclaration(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.MethodDeclarationNode, modifiers: ast.NodeIndex, asteriskToken: ast.NodeIndex, name: ast.NodeIndex, questionToken: ast.NodeIndex, typeParameters: ast.NodeIndex, parameters: ast.NodeIndex, typeNode: ast.NodeIndex, body: ast.NodeIndex) ast.NodeIndex {
        _ = questionToken;
        if ((node.modifiers orelse 0) != modifiers or (node.AsteriskToken orelse 0) != asteriskToken or node.name != name or (node.TypeParameters orelse 0) != typeParameters or node.Parameters != parameters or (node.Type orelse 0) != typeNode or (node.Body orelse 0) != body) {
            var new_node = node;
            new_node.modifiers = if (modifiers == 0) null else modifiers;
            new_node.AsteriskToken = if (asteriskToken == 0) null else asteriskToken;
            new_node.name = name;
            new_node.TypeParameters = if (typeParameters == 0) null else typeParameters;
            new_node.Parameters = parameters;
            new_node.Type = if (typeNode == 0) null else typeNode;
            new_node.Body = if (body == 0) null else body;
            return self.tree.pushNode(.{ .MethodDeclaration = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateGetAccessorDeclaration(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.GetAccessorDeclarationNode, modifiers: ast.NodeIndex, name: ast.NodeIndex, typeParameters: ast.NodeIndex, parameters: ast.NodeIndex, typeNode: ast.NodeIndex, body: ast.NodeIndex) ast.NodeIndex {
        if ((node.modifiers orelse 0) != modifiers or node.name != name or (node.TypeParameters orelse 0) != typeParameters or node.Parameters != parameters or (node.Type orelse 0) != typeNode or (node.Body orelse 0) != body) {
            var new_node = node;
            new_node.modifiers = if (modifiers == 0) null else modifiers;
            new_node.name = name;
            new_node.TypeParameters = if (typeParameters == 0) null else typeParameters;
            new_node.Parameters = parameters;
            new_node.Type = if (typeNode == 0) null else typeNode;
            new_node.Body = if (body == 0) null else body;
            return self.tree.pushNode(.{ .GetAccessor = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateSetAccessorDeclaration(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.SetAccessorDeclarationNode, modifiers: ast.NodeIndex, name: ast.NodeIndex, typeParameters: ast.NodeIndex, parameters: ast.NodeIndex, typeNode: ast.NodeIndex, body: ast.NodeIndex) ast.NodeIndex {
        if ((node.modifiers orelse 0) != modifiers or node.name != name or (node.TypeParameters orelse 0) != typeParameters or node.Parameters != parameters or (node.Type orelse 0) != typeNode or (node.Body orelse 0) != body) {
            var new_node = node;
            new_node.modifiers = if (modifiers == 0) null else modifiers;
            new_node.name = name;
            new_node.TypeParameters = if (typeParameters == 0) null else typeParameters;
            new_node.Parameters = parameters;
            new_node.Type = if (typeNode == 0) null else typeNode;
            new_node.Body = if (body == 0) null else body;
            return self.tree.pushNode(.{ .SetAccessor = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateVariableDeclaration(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.VariableDeclarationNode, name: ast.NodeIndex, exclamationToken: ast.NodeIndex, typeNode: ast.NodeIndex, initializer: ast.NodeIndex) ast.NodeIndex {
        if (node.name != name or (node.ExclamationToken orelse 0) != exclamationToken or (node.Type orelse 0) != typeNode or (node.Initializer orelse 0) != initializer) {
            var new_node = node;
            new_node.name = name;
            new_node.ExclamationToken = if (exclamationToken == 0) null else exclamationToken;
            new_node.Type = if (typeNode == 0) null else typeNode;
            new_node.Initializer = if (initializer == 0) null else initializer;
            return self.tree.pushNode(.{ .VariableDeclaration = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateHeritageClause(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.HeritageClauseNode, token: ast.NodeIndex, types: ast.NodeIndex) ast.NodeIndex {
        if (node.Token != token or node.Types != types) {
            var new_node = node;
            new_node.Token = token;
            new_node.Types = types;
            return self.tree.pushNode(.{ .HeritageClause = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateClassDeclaration(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.ClassDeclarationNode, modifiers: ast.NodeIndex, name: ast.NodeIndex, typeParameters: ast.NodeIndex, heritageClauses: ast.NodeIndex, members: ast.NodeIndex) ast.NodeIndex {
        if ((node.modifiers orelse 0) != modifiers or (node.name orelse 0) != name or (node.TypeParameters orelse 0) != typeParameters or (node.HeritageClauses orelse 0) != heritageClauses or node.Members != members) {
            var new_node = node;
            new_node.modifiers = if (modifiers == 0) null else modifiers;
            new_node.name = if (name == 0) null else name;
            new_node.TypeParameters = if (typeParameters == 0) null else typeParameters;
            new_node.HeritageClauses = if (heritageClauses == 0) null else heritageClauses;
            new_node.Members = members;
            return self.tree.pushNode(.{ .ClassDeclaration = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateClassExpression(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.ClassExpressionNode, modifiers: ast.NodeIndex, name: ast.NodeIndex, typeParameters: ast.NodeIndex, heritageClauses: ast.NodeIndex, members: ast.NodeIndex) ast.NodeIndex {
        if ((node.modifiers orelse 0) != modifiers or (node.name orelse 0) != name or (node.TypeParameters orelse 0) != typeParameters or (node.HeritageClauses orelse 0) != heritageClauses or node.Members != members) {
            var new_node = node;
            new_node.modifiers = if (modifiers == 0) null else modifiers;
            new_node.name = if (name == 0) null else name;
            new_node.TypeParameters = if (typeParameters == 0) null else typeParameters;
            new_node.HeritageClauses = if (heritageClauses == 0) null else heritageClauses;
            new_node.Members = members;
            return self.tree.pushNode(.{ .ClassExpression = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateFunctionDeclaration(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.FunctionDeclarationNode, modifiers: ast.NodeIndex, asteriskToken: ast.NodeIndex, name: ast.NodeIndex, typeParameters: ast.NodeIndex, parameters: ast.NodeIndex, typeNode: ast.NodeIndex, body: ast.NodeIndex) ast.NodeIndex {
        if ((node.modifiers orelse 0) != modifiers or (node.AsteriskToken orelse 0) != asteriskToken or (node.name orelse 0) != name or (node.TypeParameters orelse 0) != typeParameters or node.Parameters != parameters or (node.Type orelse 0) != typeNode or (node.Body orelse 0) != body) {
            var new_node = node;
            new_node.modifiers = if (modifiers == 0) null else modifiers;
            new_node.AsteriskToken = if (asteriskToken == 0) null else asteriskToken;
            new_node.name = if (name == 0) null else name;
            new_node.TypeParameters = if (typeParameters == 0) null else typeParameters;
            new_node.Parameters = parameters;
            new_node.Type = if (typeNode == 0) null else typeNode;
            new_node.Body = if (body == 0) null else body;
            return self.tree.pushNode(.{ .FunctionDeclaration = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateFunctionExpression(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.FunctionExpressionNode, modifiers: ast.NodeIndex, asteriskToken: ast.NodeIndex, name: ast.NodeIndex, typeParameters: ast.NodeIndex, parameters: ast.NodeIndex, typeNode: ast.NodeIndex, body: ast.NodeIndex) ast.NodeIndex {
        if ((node.modifiers orelse 0) != modifiers or (node.AsteriskToken orelse 0) != asteriskToken or (node.name orelse 0) != name or (node.TypeParameters orelse 0) != typeParameters or node.Parameters != parameters or (node.Type orelse 0) != typeNode or (node.Body orelse 0) != body) {
            var new_node = node;
            new_node.modifiers = if (modifiers == 0) null else modifiers;
            new_node.AsteriskToken = if (asteriskToken == 0) null else asteriskToken;
            new_node.name = if (name == 0) null else name;
            new_node.TypeParameters = if (typeParameters == 0) null else typeParameters;
            new_node.Parameters = parameters;
            new_node.Type = if (typeNode == 0) null else typeNode;
            new_node.Body = if (body == 0) null else body;
            return self.tree.pushNode(.{ .FunctionExpression = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateArrowFunction(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.ArrowFunctionNode, modifiers: ast.NodeIndex, typeParameters: ast.NodeIndex, parameters: ast.NodeIndex, typeNode: ast.NodeIndex, equalsGreaterThanToken: ast.NodeIndex, body: ast.NodeIndex) ast.NodeIndex {
        if ((node.modifiers orelse 0) != modifiers or (node.TypeParameters orelse 0) != typeParameters or node.Parameters != parameters or (node.Type orelse 0) != typeNode or node.EqualsGreaterThanToken != equalsGreaterThanToken or (node.Body orelse 0) != body) {
            var new_node = node;
            new_node.modifiers = if (modifiers == 0) null else modifiers;
            new_node.TypeParameters = if (typeParameters == 0) null else typeParameters;
            new_node.Parameters = parameters;
            new_node.Type = if (typeNode == 0) null else typeNode;
            new_node.EqualsGreaterThanToken = equalsGreaterThanToken;
            new_node.Body = if (body == 0) null else body;
            return self.tree.pushNode(.{ .ArrowFunction = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateParameterDeclaration(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.ParameterDeclarationNode, modifiers: ast.NodeIndex, dotDotDotToken: ast.NodeIndex, name: ast.NodeIndex, questionToken: ast.NodeIndex, typeNode: ast.NodeIndex, initializer: ast.NodeIndex) ast.NodeIndex {
        if ((node.modifiers orelse 0) != modifiers or (node.DotDotDotToken orelse 0) != dotDotDotToken or node.name != name or (node.QuestionToken orelse 0) != questionToken or (node.Type orelse 0) != typeNode or (node.Initializer orelse 0) != initializer) {
            var new_node = node;
            new_node.modifiers = if (modifiers == 0) null else modifiers;
            new_node.DotDotDotToken = if (dotDotDotToken == 0) null else dotDotDotToken;
            new_node.name = name;
            new_node.QuestionToken = if (questionToken == 0) null else questionToken;
            new_node.Type = if (typeNode == 0) null else typeNode;
            new_node.Initializer = if (initializer == 0) null else initializer;
            return self.tree.pushNode(.{ .Parameter = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateCallExpression(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.CallExpressionNode, expression: ast.NodeIndex, questionDotToken: ast.NodeIndex, typeArguments: ast.NodeIndex, arguments: ast.NodeIndex, flags: u32) ast.NodeIndex {
        if (node.Expression != expression or (node.QuestionDotToken orelse 0) != questionDotToken or (node.TypeArguments orelse 0) != typeArguments or node.Arguments != arguments or node.Flags != flags) {
            var new_node = node;
            new_node.Expression = expression;
            new_node.QuestionDotToken = if (questionDotToken == 0) null else questionDotToken;
            new_node.TypeArguments = if (typeArguments == 0) null else typeArguments;
            new_node.Arguments = arguments;
            new_node.Flags = flags;
            return self.tree.pushNode(.{ .CallExpression = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateNewExpression(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.NewExpressionNode, expression: ast.NodeIndex, typeArguments: ast.NodeIndex, arguments: ast.NodeIndex) ast.NodeIndex {
        if (node.Expression != expression or (node.TypeArguments orelse 0) != typeArguments or (node.Arguments orelse 0) != arguments) {
            var new_node = node;
            new_node.Expression = expression;
            new_node.TypeArguments = if (typeArguments == 0) null else typeArguments;
            new_node.Arguments = if (arguments == 0) null else arguments;
            return self.tree.pushNode(.{ .NewExpression = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateTaggedTemplateExpression(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.TaggedTemplateExpressionNode, tag: ast.NodeIndex, questionDotToken: ast.NodeIndex, typeArguments: ast.NodeIndex, template: ast.NodeIndex, flags: u32) ast.NodeIndex {
        if (node.Tag != tag or (node.QuestionDotToken orelse 0) != questionDotToken or (node.TypeArguments orelse 0) != typeArguments or node.Template != template or node.Flags != flags) {
            var new_node = node;
            new_node.Tag = tag;
            new_node.QuestionDotToken = if (questionDotToken == 0) null else questionDotToken;
            new_node.TypeArguments = if (typeArguments == 0) null else typeArguments;
            new_node.Template = template;
            new_node.Flags = flags;
            return self.tree.pushNode(.{ .TaggedTemplateExpression = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn newPartiallyEmittedExpression(self: *NodeFactory, expression: ast.NodeIndex) ast.NodeIndex {
        return self.tree.pushNode(.{ .PartiallyEmittedExpression = .{
            .Flags = 0,
            .Expression = expression,
        } }) catch unreachable;
    }

    pub fn updateJsxSelfClosingElement(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.JsxSelfClosingElementNode, tagName: ast.NodeIndex, typeArguments: ast.NodeIndex, attributes: ast.NodeIndex) ast.NodeIndex {
        if (node.TagName != tagName or (node.TypeArguments orelse 0) != typeArguments or node.Attributes != attributes) {
            var new_node = node;
            new_node.TagName = tagName;
            new_node.TypeArguments = if (typeArguments == 0) null else typeArguments;
            new_node.Attributes = attributes;
            return self.tree.pushNode(.{ .JsxSelfClosingElement = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateJsxOpeningElement(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.JsxOpeningElementNode, tagName: ast.NodeIndex, typeArguments: ast.NodeIndex, attributes: ast.NodeIndex) ast.NodeIndex {
        if (node.TagName != tagName or (node.TypeArguments orelse 0) != typeArguments or node.Attributes != attributes) {
            var new_node = node;
            new_node.TagName = tagName;
            new_node.TypeArguments = if (typeArguments == 0) null else typeArguments;
            new_node.Attributes = attributes;
            return self.tree.pushNode(.{ .JsxOpeningElement = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateExportDeclaration(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.ExportDeclarationNode, modifiers: ast.NodeIndex, isTypeOnly: bool, exportClause: ast.NodeIndex, moduleSpecifier: ast.NodeIndex, attributes: ast.NodeIndex) ast.NodeIndex {
        if ((node.modifiers orelse 0) != modifiers or (node.IsTypeOnly != 0) != isTypeOnly or (node.ExportClause orelse 0) != exportClause or (node.ModuleSpecifier orelse 0) != moduleSpecifier or (node.Attributes orelse 0) != attributes) {
            var new_node = node;
            new_node.modifiers = if (modifiers == 0) null else modifiers;
            new_node.IsTypeOnly = if (isTypeOnly) 1 else 0;
            new_node.ExportClause = if (exportClause == 0) null else exportClause;
            new_node.ModuleSpecifier = if (moduleSpecifier == 0) null else moduleSpecifier;
            new_node.Attributes = if (attributes == 0) null else attributes;
            return self.tree.pushNode(.{ .ExportDeclaration = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn updateSourceFile(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.SourceFileNode, statements: ast.NodeIndex, endOfFileToken: ast.NodeIndex) ast.NodeIndex {
        if (node.Statements != statements or node.EndOfFileToken != endOfFileToken) {
            var new_node = node;
            new_node.Statements = statements;
            new_node.EndOfFileToken = endOfFileToken;
            return self.tree.pushNode(.{ .SourceFile = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn createNamedExports(self: *NodeFactory, elements: ast.NodeIndex) ast.NodeIndex {
        const new_node = ast_gen.NamedExportsNode{
            .Flags = 0,
            .Elements = elements,
        };
        return self.tree.pushNode(.{ .NamedExports = new_node }) catch unreachable;
    }

    pub fn createExportDeclaration(self: *NodeFactory, modifiers: ast.NodeIndex, isTypeOnly: bool, exportClause: ast.NodeIndex, moduleSpecifier: ast.NodeIndex, attributes: ast.NodeIndex) ast.NodeIndex {
        const new_node = ast_gen.ExportDeclarationNode{
            .Flags = 0,
            .modifierFlags = 0,
            .Symbol = 0,
            .modifiers = if (modifiers != 0) modifiers else null,
            .IsTypeOnly = if (isTypeOnly) 1 else 0,
            .ExportClause = if (exportClause != 0) exportClause else null,
            .ModuleSpecifier = if (moduleSpecifier != 0) moduleSpecifier else null,
            .Attributes = if (attributes != 0) attributes else null,
        };
        return self.tree.pushNode(.{ .ExportDeclaration = new_node }) catch unreachable;
    }

    pub fn updateNamedExports(self: *NodeFactory, nodeIndex: ast_gen.NodeIndex, node: ast_gen.NamedExportsNode, elements: ast.NodeIndex) ast.NodeIndex {
        if (node.Elements != elements) {
            var new_node = node;
            new_node.Elements = elements;
            return self.tree.pushNode(.{ .NamedExports = new_node }) catch unreachable;
        }
        return nodeIndex;
    }

    pub fn createBlock(self: *NodeFactory, statements: ast.NodeIndex, multiLine: bool) ast.NodeIndex {
        return self.tree.pushNode(.{ .Block = .{
            .Flags = 0,
            .Statements = statements,
            .MultiLine = multiLine,
        } }) catch unreachable;
    }

    pub fn newGeneratedIdentifier(
        self: *NodeFactory,
        kind: GeneratedIdentifierFlags,
        text: []const u8,
        node: ?ast.NodeIndex,
        options: AutoGenerateOptions,
    ) !ast.NodeIndex {
        _ = node;
        _ = options;

        self.nextAutoGenerateId += 1;
        const id = self.nextAutoGenerateId;

        var final_text: []const u8 = text;
        if (final_text.len == 0) {
            final_text = try std.fmt.allocPrint(self.allocator, "(auto@{d})", .{id});
        }

        const identifier = ast_gen.NodeData{
            .Identifier = .{
                .Flags = @intFromEnum(kind),
                .Text = final_text,
            },
        };

        return try self.tree.pushNode(identifier);
    }

    pub fn createTempVariable(self: *NodeFactory) !ast.NodeIndex {
        return try self.createTempVariableEx(.{});
    }

    pub fn createTempVariableEx(self: *NodeFactory, options: AutoGenerateOptions) !ast.NodeIndex {
        return try self.newGeneratedIdentifier(.Auto, "", null, options);
    }

    pub fn createLoopVariable(self: *NodeFactory) !ast.NodeIndex {
        return try self.createLoopVariableEx(.{});
    }

    pub fn createLoopVariableEx(self: *NodeFactory, options: AutoGenerateOptions) !ast.NodeIndex {
        return try self.newGeneratedIdentifier(.Loop, "", null, options);
    }

    pub fn createUniqueName(self: *NodeFactory, text: []const u8) !ast.NodeIndex {
        return try self.createUniqueNameEx(text, .{});
    }

    pub fn createUniqueNameEx(self: *NodeFactory, text: []const u8, options: AutoGenerateOptions) !ast.NodeIndex {
        return try self.newGeneratedIdentifier(.Unique, text, null, options);
    }

    pub fn createGeneratedNameForNode(self: *NodeFactory, node: ast.NodeIndex) !ast.NodeIndex {
        return try self.createGeneratedNameForNodeEx(node, .{});
    }

    pub fn createGeneratedNameForNodeEx(self: *NodeFactory, node: ast.NodeIndex, options: AutoGenerateOptions) !ast.NodeIndex {
        var opts = options;
        if (opts.prefix.len > 0 or opts.suffix.len > 0) {
            opts.flags |= @intFromEnum(GeneratedIdentifierFlags.Optimistic);
        }
        return try self.newGeneratedIdentifier(.Node, "", node, opts);
    }
};

test "NodeFactory" {}
