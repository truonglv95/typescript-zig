const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");

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
    pub fn newExternalModuleExport(self: *NodeFactory, a: anytype) ast.NodeIndex { _ = self; _ = a; return 0; }
    
    pub fn newExportDefault(self: *NodeFactory, a: anytype) ast.NodeIndex { _ = self; _ = a; return 0; }

    pub fn newClassExpression(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype, e: anytype) ast.NodeIndex { _ = self; _ = a; _ = b; _ = c; _ = d; _ = e; return 0; }

    pub fn updateComputedPropertyName(self: *NodeFactory, a: anytype, b: anytype) ast.NodeIndex { _ = self; _ = a; _ = b; return 0; }

    pub fn newParamHelper(self: *NodeFactory, a: anytype, b: anytype, c: anytype) ast.NodeIndex { _ = self; _ = a; _ = b; _ = c; return 0; }
    pub fn deepCloneNode(self: *NodeFactory, a: anytype) ast.NodeIndex { _ = self; _ = a; return 0; }

    pub fn newUniqueName(self: *NodeFactory, a: anytype) ast.NodeIndex { _ = self; _ = a; return 0; }

    pub fn newDecorateHelper(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype) ast.NodeIndex { _ = self; _ = a; _ = b; _ = c; _ = d; return 0; }

    pub fn newKeywordExpression(self: *NodeFactory, a: anytype) ast.NodeIndex { _ = self; _ = a; return 0; }

    pub fn newClassStaticBlockDeclaration(self: *NodeFactory, a: anytype, b: anytype) ast.NodeIndex { _ = self; _ = a; _ = b; return 0; }

    pub fn getDeclarationName(self: *NodeFactory, a: anytype) ast.NodeIndex { _ = self; _ = a; return 0; }

    pub fn updatePropertyAccessExpression(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype, e: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; _ = c; _ = d; _ = e; return 0; }

    pub fn updateBlock(self: *NodeFactory, a: anytype, b: anytype, c: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; _ = c; return 0; }

    pub fn updateTryStatement(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; _ = c; _ = d; return 0; }

    pub fn newArrayLiteralExpression(self: *NodeFactory, a: anytype, b: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; return 0; }

    pub fn newNumericLiteral(self: *NodeFactory, a: anytype, b: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; return 0; }

    pub fn newStringLiteral(self: *NodeFactory, a: anytype, b: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; return 0; }

    pub fn newElementAccessExpression(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; _ = c; _ = d; return 0; }

    pub fn newTypeCheck(self: *NodeFactory, a: anytype, b: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; return 0; }

    pub fn newThisExpression(self: *NodeFactory) ast_gen.NodeIndex { _ = self; return 0; }
    pub fn newDecorator(self: *NodeFactory, a: anytype) ast_gen.NodeIndex { _ = self; _ = a; return 0; }

    pub fn newConditionalExpression(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype, e: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; _ = c; _ = d; _ = e; return 0; }
    pub fn newPropertyAccessExpression(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; _ = c; _ = d; return 0; }
    pub fn updateShorthandPropertyAssignment(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype, e: anytype, f: anytype, g: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; _ = c; _ = d; _ = e; _ = f; _ = g; return 0; }


    pub fn newParenthesizedExpression(self: *NodeFactory, a: anytype) ast_gen.NodeIndex { _ = self; _ = a; return 0; }
    pub fn newBlock(self: *NodeFactory, a: anytype, b: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; return 0; }

    pub fn newCallExpression(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype, e: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; _ = c; _ = d; _ = e; return 0; }
    pub fn newVoidZeroExpression(self: *NodeFactory) ast_gen.NodeIndex { _ = self; return 0; }

    pub fn newFunctionExpression(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype, e: anytype, f: anytype, g: anytype, h: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; _ = c; _ = d; _ = e; _ = f; _ = g; _ = h; return 0; }
    pub fn newPropertyAssignment(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype, e: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; _ = c; _ = d; _ = e; return 0; }
    pub fn newIdentifier(self: *NodeFactory, a: anytype) ast_gen.NodeIndex { _ = self; _ = a; return 0; }


    pub fn newMetadataHelper(self: *NodeFactory, a: anytype, b: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; return 0; }
    pub fn newParameterDeclaration(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype, e: anytype, f: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; _ = c; _ = d; _ = e; _ = f; return 0; }

    pub fn newVariableStatement(self: *NodeFactory, a: anytype, b: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; return 0; }
    pub fn newExpressionStatement(self: *NodeFactory, a: anytype) ast_gen.NodeIndex { _ = self; _ = a; return 0; }
    pub fn newPropertyDeclaration(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype, e: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; _ = c; _ = d; _ = e; return 0; }

    pub fn newObjectLiteralExpression(self: *NodeFactory, a: anytype, b: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; return 0; }
    pub fn inlineExpressions(self: *NodeFactory, a: anytype) ast_gen.NodeIndex { _ = self; _ = a; return 0; }

    pub fn newAssignmentExpression(self: *NodeFactory, a: anytype, b: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; return 0; }
    pub fn newBinaryExpression(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype, e: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; _ = c; _ = d; _ = e; return 0; }

    pub fn newModifierList(self: *NodeFactory, a: anytype) ast_gen.NodeIndex { _ = self; _ = a; return 0; }
    pub fn newVariableDeclarationList(self: *NodeFactory, a: anytype, b: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; return 0; }
    pub fn newSyntaxList(self: *NodeFactory, a: anytype) ast_gen.NodeIndex { _ = self; _ = a; return 0; }
    pub fn getLocalName(self: *NodeFactory, a: anytype) ast_gen.NodeIndex { _ = self; _ = a; return 0; }
    pub fn newNodeList(self: *NodeFactory, a: anytype) ast_gen.NodeIndex { _ = self; _ = a; return 0; }

    pub fn getLocalNameEx(self: *NodeFactory, node: ast_gen.NodeIndex, opts: anytype) ast_gen.NodeIndex { _ = self; _ = node; _ = opts; return 0; }
    pub fn getDeclarationNameEx(self: *NodeFactory, node: ast_gen.NodeIndex, opts: anytype) ast_gen.NodeIndex { _ = self; _ = node; _ = opts; return 0; }
    pub fn getNamespaceMemberName(self: *NodeFactory, a: anytype, b: anytype, c: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; _ = c; return 0; }
    pub fn newGeneratedNameForNode(self: *NodeFactory, node: ast_gen.NodeIndex) ast_gen.NodeIndex { _ = self; _ = node; return 0; }
    pub fn newVariableDeclaration(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; _ = c; _ = d; return 0; }

    pub fn getExternalModuleOrNamespaceExportName(self: *NodeFactory, a: anytype, b: anytype, c: anytype, d: anytype) ast_gen.NodeIndex { _ = self; _ = a; _ = b; _ = c; _ = d; return 0; }
    pub fn splitStandardPrologue(self: *NodeFactory, a: anytype) struct { prologue: []const ast_gen.NodeIndex, statements: []const ast_gen.NodeIndex } { _ = self; _ = a; return .{ .prologue = &[_]ast_gen.NodeIndex{}, .statements = &[_]ast_gen.NodeIndex{} }; }
    

    pub fn newLogicalORExpression(self: *NodeFactory, left: ast_gen.NodeIndex, right: ast_gen.NodeIndex) ast_gen.NodeIndex { _ = self; _ = left; _ = right; return 0; }
    pub fn createIdentifier(self: *NodeFactory, node: ast_gen.NodeIndex) ast_gen.NodeIndex { _ = self; _ = node; return 0; }
    pub fn newToken(self: *NodeFactory, kind: anytype) ast_gen.NodeIndex { _ = self; _ = kind; return 0; }
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
