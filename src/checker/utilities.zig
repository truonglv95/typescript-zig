const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const ast = @import("../ast/ast.zig");
const symbol = @import("../ast/symbol.zig");
const checker_mod = @import("checker.zig");
const types = @import("types.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");

const Checker = checker_mod.Checker;
const NodeIndex = ast_gen.NodeIndex;
const SymbolIndex = ast_gen.SymbolIndex;
const TypeIndex = types.TypeIndex;

// TODO: Ported a subset of checker utilities. The original utilities.go is 1845 lines.
// As instructed, we use indices instead of pointers.

pub fn tokenIsIdentifierOrKeyword(token: ast_gen.SyntaxKind) bool {
    return @intFromEnum(token) >= @intFromEnum(ast_gen.SyntaxKind.Identifier);
}

pub fn tokenIsIdentifierOrKeywordOrGreaterThan(token: ast_gen.SyntaxKind) bool {
    return token == .GreaterThanToken or tokenIsIdentifierOrKeyword(token);
}

pub fn hasOverrideModifier(ast_data: *const ast.Ast, node: NodeIndex) bool {
    return ast.hasSyntacticModifier(ast_data, node, ast_gen.ModifierFlags.Override);
}

pub fn hasAsyncModifier(ast_data: *const ast.Ast, node: NodeIndex) bool {
    return ast.hasSyntacticModifier(ast_data, node, ast_gen.ModifierFlags.Async);
}

pub fn getSelectedModifierFlags(ast_data: *const ast.Ast, node: NodeIndex, flags: u32) u32 {
    return ast.getModifierFlags(ast_data, node) & flags;
}

pub fn hasReadonlyModifier(ast_data: *const ast.Ast, node: NodeIndex) bool {
    return ast.hasModifier(ast_data, node, ast_gen.ModifierFlags.Readonly);
}

pub fn isStaticPrivateIdentifierProperty(ast_data: *const ast.Ast, sym: *const symbol.Symbol) bool {
    if (sym.ValueDeclaration) |decl| {
        return ast.isPrivateIdentifierClassElementDeclaration(ast_data, decl) and ast.isStatic(ast_data, decl);
    }
    return false;
}

pub fn isEmptyObjectLiteral(ast_data: *const ast.Ast, node: NodeIndex) bool {
    const node_data = ast_data.getNode(node);
    if (node_data == .ObjectLiteralExpression) {
        const props = node_data.ObjectLiteralExpression.Properties;
        return props == 0 or ast_data.getNodeList(props).len == 0;
    }
    return false;
}

pub const AssignmentKind = enum(u32) {
    None,
    Definite,
    Compound,
};

pub fn getAssignmentTargetKind(ast_data: *const ast.Ast, node: NodeIndex) AssignmentKind {
    const target = ast.getAssignmentTarget(ast_data, node);
    if (target == 0) return .None;

    const target_node = ast_data.getNode(target);
    switch (target_node) {
        .BinaryExpression => |bin| {
            const op = ast_data.getNode(bin.OperatorToken);
            // This is a simplification. We'd check the token kind in a real scenario.
            if (op == .EqualsToken or ast.isLogicalOrCoalescingAssignmentOperator(op)) {
                return .Definite;
            }
            return .Compound;
        },
        .PrefixUnaryExpression, .PostfixUnaryExpression => {
            return .Compound;
        },
        .ForInStatement, .ForOfStatement => {
            return .Definite;
        },
        else => unreachable,
    }
}

pub fn isDeleteTarget(ast_data: *const ast.Ast, node: NodeIndex) bool {
    if (!ast.isAccessExpression(ast_data, node)) return false;
    const parent = ast.walkUpParenthesizedExpressions(ast_data, ast_data.getParent(node));
    if (parent != 0 and ast_data.getNode(parent) == .DeleteExpression) {
        return true;
    }
    return false;
}

pub fn isConstTypeReference(ast_data: *const ast.Ast, node: NodeIndex) bool {
    const node_data = ast_data.getNode(node);
    if (node_data == .TypeReference) {
        const tr = node_data.TypeReference;
        if (tr.TypeArguments == 0 or ast_data.getNodeList(tr.TypeArguments).len == 0) {
            const typeName = ast_data.getNode(tr.TypeName);
            if (typeName == .Identifier) {
                return std.mem.eql(u8, typeName.Identifier.Text, "const");
            }
        }
    }
    return false;
}

pub fn isTypeAny(t: *const types.Type) bool {
    return t.flags & types.TypeFlags.Any != 0;
}

pub fn isExclamationToken(ast_data: *const ast.Ast, node: NodeIndex) bool {
    return node != 0 and ast_data.getNode(node) == .ExclamationToken;
}

pub fn isOptionalDeclaration(ast_data: *const ast.Ast, declaration: NodeIndex) bool {
    return ast.hasQuestionToken(ast_data, declaration);
}

pub fn isTypeAssertion(ast_data: *const ast.Ast, node: NodeIndex) bool {
    return ast.isAssertionExpression(ast_data, ast.skipParentheses(ast_data, node));
}

pub fn isEmptyArrayLiteral(ast_data: *const ast.Ast, node: NodeIndex) bool {
    const node_data = ast_data.getNode(node);
    if (node_data == .ArrayLiteralExpression) {
        const elements = node_data.ArrayLiteralExpression.Elements;
        return elements == 0 or ast_data.getNodeList(elements).len == 0;
    }
    return false;
}

pub fn isTypeUsableAsPropertyName(t: *const types.Type) bool {
    return t.flags & (types.TypeFlags.StringLiteral | types.TypeFlags.NumberLiteral | types.TypeFlags.UniqueESSymbol) != 0;
}

pub fn getPropertyNameFromType(t: *const types.Type) []const u8 {
    if (t.flags & types.TypeFlags.StringLiteral != 0) {
        return t.data.StringLiteral.text;
    } else if (t.flags & types.TypeFlags.NumberLiteral != 0) {
        // Need to convert f64 to string, caller needs to handle memory. For simplicity we assume it handles it.
        // In real TS it returns string.
        return "number"; // Placeholder
    } else if (t.flags & types.TypeFlags.UniqueESSymbol != 0) {
        return "symbol"; // Placeholder
    }
    unreachable;
}

pub fn isNumericLiteralName(name: []const u8) bool {
    // Basic approximation of whether a string is a numeric literal that matches its own toString()
    if (name.len == 0) return false;
    const float = std.fmt.parseFloat(f64, name) catch return false;
    var buf: [64]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, "{d}", .{float}) catch return false;
    return std.mem.eql(u8, name, str);
}



pub fn hasType(ast_data: *const ast.Ast, node: NodeIndex) bool {
    _ = ast_data;
    _ = node;
    // In a real scenario we'd check if the node has a Type field
    return false;
}

pub fn isReservedMemberName(name: []const u8) bool {
    if (name.len >= 2 and name[0] == '\xFE' and name[1] != '@' and name[1] != '#') {
        return true;
    }
    return false;
}

pub fn isObjectLiteralType(t: *const types.Type) bool {
    return t.objectFlags & types.ObjectFlags.ObjectLiteral != 0;
}

pub fn isDeclarationReadonly(ast_data: *const ast.Ast, declaration: NodeIndex) bool {
    return ast.getCombinedModifierFlags(ast_data, declaration) & ast_gen.ModifierFlags.Readonly != 0 and
        !ast.isParameterPropertyDeclaration(ast_data, declaration, ast_data.getParent(declaration));
}



pub fn getMembersOfDeclaration(ast_data: *const ast.Ast, node: NodeIndex) []const NodeIndex {
    const node_data = ast_data.getNode(node);
    switch (node_data) {
        .InterfaceDeclaration => |id| return if (id.Members != 0) ast_data.getNodeList(id.Members) else &[_]NodeIndex{},
        .ClassDeclaration => |cd| return if (cd.Members != 0) ast_data.getNodeList(cd.Members) else &[_]NodeIndex{},
        .ClassExpression => |ce| return if (ce.Members != 0) ast_data.getNodeList(ce.Members) else &[_]NodeIndex{},
        .TypeLiteral => |tl| return if (tl.Members != 0) ast_data.getNodeList(tl.Members) else &[_]NodeIndex{},
        .ObjectLiteralExpression => |ole| return if (ole.Properties != 0) ast_data.getNodeList(ole.Properties) else &[_]NodeIndex{},
        else => return &[_]NodeIndex{},
    }
}

pub fn getSingleVariableOfVariableStatement(ast_data: *const ast.Ast, node: NodeIndex) NodeIndex {
    const node_data = ast_data.getNode(node);
    if (node_data != .VariableStatement) return 0;
    
    const decl_list = node_data.VariableStatement.DeclarationList;
    if (decl_list == 0) return 0;

    const decl_list_node = ast_data.getNode(decl_list);
    if (decl_list_node != .VariableDeclarationList) return 0;

    const decls = decl_list_node.VariableDeclarationList.Declarations;
    if (decls == 0) return 0;

    const decl_nodes = ast_data.getNodeList(decls);
    if (decl_nodes.len > 0) return decl_nodes[0];
    return 0;
}

pub fn isTypeReferenceIdentifier(ast_data: *const ast.Ast, node: NodeIndex) bool {
    var curr = node;
    var parent = ast_data.getParent(curr);
    while (parent != 0 and ast_data.getNode(parent) == .QualifiedName) {
        curr = parent;
        parent = ast_data.getParent(curr);
    }
    return parent != 0 and ast_data.getNode(parent) == .TypeReference;
}

pub fn canHaveLocals(ast_data: *const ast.Ast, node: NodeIndex) bool {
    const kind = ast_data.getNode(node);
    switch (kind) {
        .ArrowFunction, .Block, .CallSignature, .CaseBlock, .CatchClause,
        .ClassStaticBlockDeclaration, .ConditionalType, .Constructor, .ConstructorType,
        .ConstructSignature, .ForStatement, .ForInStatement, .ForOfStatement, .FunctionDeclaration,
        .FunctionExpression, .FunctionType, .GetAccessor, .IndexSignature,
        .JSDocSignature, .MappedType,
        .MethodDeclaration, .MethodSignature, .ModuleDeclaration, .SetAccessor, .SourceFile,
        .TypeAliasDeclaration, .JSTypeAliasDeclaration => return true,
        else => return false,
    }
}

pub fn isShorthandAmbientModuleSymbol(ast_data: *const ast.Ast, sym: *const symbol.Symbol) bool {
    if (sym.ValueDeclaration) |decl| {
        return isShorthandAmbientModule(ast_data, decl);
    }
    return false;
}

pub fn isShorthandAmbientModule(ast_data: *const ast.Ast, node: NodeIndex) bool {
    if (node == 0) return false;
    const node_data = ast_data.getNode(node);
    if (node_data == .ModuleDeclaration) {
        return node_data.ModuleDeclaration.Body == 0;
    }
    return false;
}

pub fn getAliasDeclarationFromName(ast_data: *const ast.Ast, node: NodeIndex) NodeIndex {
    const parent = ast_data.getParent(node);
    if (parent == 0) return 0;
    const parent_data = ast_data.getNode(parent);
    switch (parent_data) {
        .ImportClause, .ImportSpecifier, .NamespaceImport, .ExportSpecifier, .ExportAssignment,
        .ImportEqualsDeclaration, .NamespaceExport => return parent,
        .QualifiedName => return getAliasDeclarationFromName(ast_data, parent),
        else => return 0,
    }
}

pub fn getContainingQualifiedNameNode(ast_data: *const ast.Ast, node: NodeIndex) NodeIndex {
    var curr = node;
    var parent = ast_data.getParent(curr);
    while (parent != 0 and ast_data.getNode(parent) == .QualifiedName) {
        curr = parent;
        parent = ast_data.getParent(curr);
    }
    return curr;
}

pub fn isSideEffectImport(ast_data: *const ast.Ast, node: NodeIndex) bool {
    const ancestor = ast.findAncestor(ast_data, node, ast.isImportDeclaration);
    if (ancestor != 0) {
        const ancestor_data = ast_data.getNode(ancestor);
        if (ancestor_data == .ImportDeclaration) {
            return ancestor_data.ImportDeclaration.ImportClause == 0;
        }
    }
    return false;
}

pub fn isTopLevelInExternalModuleAugmentation(ast_data: *const ast.Ast, node: NodeIndex) bool {
    if (node == 0) return false;
    const parent = ast_data.getParent(node);
    if (parent != 0 and ast_data.getNode(parent) == .ModuleBlock) {
        const grandparent = ast_data.getParent(parent);
        if (grandparent != 0 and ast.isExternalModuleAugmentation(ast_data, grandparent)) {
            return true;
        }
    }
    return false;
}

pub fn isSyntacticDefault(ast_data: *const ast.Ast, node: NodeIndex) bool {
    const node_data = ast_data.getNode(node);
    if (node_data == .ExportAssignment) {
        if (!node_data.ExportAssignment.IsExportEquals) return true;
    }
    if (ast.hasSyntacticModifier(ast_data, node, ast_gen.ModifierFlags.Default)) return true;
    if (node_data == .ExportSpecifier or node_data == .NamespaceExport) return true;
    return false;
}

pub fn isTypeAlias(ast_data: *const ast.Ast, node: NodeIndex) bool {
    return ast.isTypeOrJSTypeAliasDeclaration(ast_data, node);
}

pub fn hasOnlyExpressionInitializer(ast_data: *const ast.Ast, node: NodeIndex) bool {
    const kind = ast_data.getNode(node);
    switch (kind) {
        .VariableDeclaration, .Parameter, .BindingElement, .PropertyDeclaration, .PropertyAssignment, .EnumMember => return true,
        else => return false,
    }
}

pub fn hasDotDotDotToken(ast_data: *const ast.Ast, node: NodeIndex) bool {
    const node_data = ast_data.getNode(node);
    switch (node_data) {
        .Parameter => |p| return p.DotDotDotToken != 0,
        .BindingElement => |be| return be.DotDotDotToken != 0,
        .NamedTupleMember => |ntm| return ntm.DotDotDotToken != 0,
        .JsxExpression => |je| return je.DotDotDotToken != 0,
        else => return false,
    }
}

pub fn isJSDocOptionalParameter(ast_data: *const ast.Ast, node: NodeIndex) bool {
    _ = ast_data;
    _ = node;
    return false; // !!!
}

pub fn isOptionalParameter(c: *Checker, node: NodeIndex) bool {
    const ast_data = &c.binder.ast;
    const node_data = ast_data.getNode(node);
    if (node_data == .Parameter and node_data.Parameter.QuestionToken != 0) {
        return true;
    }
    if (node_data != .Parameter) return false;

    if (node_data.Parameter.Initializer != 0) {
        return true; // Simplified for now
    }
    return false;
}

pub fn declarationBelongsToPrivateAmbientMember(ast_data: *const ast.Ast, declaration: NodeIndex) bool {
    const root = ast.getRootDeclaration(ast_data, declaration);
    var memberDeclaration = root;
    if (ast_data.getNode(root) == .Parameter) {
        memberDeclaration = ast_data.getParent(root);
    }
    return isPrivateWithinAmbient(ast_data, memberDeclaration);
}

pub fn isPrivateWithinAmbient(ast_data: *const ast.Ast, node: NodeIndex) bool {
    if ((ast.hasModifier(ast_data, node, ast_gen.ModifierFlags.Private) or ast.isPrivateIdentifierClassElementDeclaration(ast_data, node)) and (ast_data.getNodeFlags(node) & ast_gen.NodeFlags.Ambient) != 0) {
        return true;
    }
    return false;
}

pub fn getDeclarationModifierFlagsFromSymbol(ast_data: *const ast.Ast, sym: *const symbol.Symbol) u32 {
    return getDeclarationModifierFlagsFromSymbolEx(ast_data, sym, false);
}

pub fn getDeclarationModifierFlagsFromSymbolEx(ast_data: *const ast.Ast, sym: *const symbol.Symbol, isWrite: bool) u32 {
    _ = isWrite;
    if (sym.ValueDeclaration) |decl| {
        const flags = ast.getCombinedModifierFlags(ast_data, decl);
        return flags & ~@as(u32, ast_gen.ModifierFlags.AccessibilityModifier);
    }
    if ((sym.Flags & symbol.SymbolFlags.Prototype) != 0) {
        return ast_gen.ModifierFlags.Public | ast_gen.ModifierFlags.Static;
    }
    return 0;
}

pub fn isExponentiationOperator(kind_val: ast_gen.SyntaxKind) bool {
    return kind_val == .AsteriskAsteriskToken;
}

pub fn isMultiplicativeOperator(kind_val: ast_gen.SyntaxKind) bool {
    return kind_val == .AsteriskToken or kind_val == .SlashToken or kind_val == .PercentToken;
}

pub fn isMultiplicativeOperatorOrHigher(kind_val: ast_gen.SyntaxKind) bool {
    return isExponentiationOperator(kind_val) or isMultiplicativeOperator(kind_val);
}

pub fn isAdditiveOperator(kind_val: ast_gen.SyntaxKind) bool {
    return kind_val == .PlusToken or kind_val == .MinusToken;
}

pub fn isAdditiveOperatorOrHigher(kind_val: ast_gen.SyntaxKind) bool {
    return isAdditiveOperator(kind_val) or isMultiplicativeOperatorOrHigher(kind_val);
}

pub fn isShiftOperator(kind_val: ast_gen.SyntaxKind) bool {
    return kind_val == .LessThanLessThanToken or kind_val == .GreaterThanGreaterThanToken or
        kind_val == .GreaterThanGreaterThanGreaterThanToken;
}

pub fn isShiftOperatorOrHigher(kind_val: ast_gen.SyntaxKind) bool {
    return isShiftOperator(kind_val) or isAdditiveOperatorOrHigher(kind_val);
}

pub fn isRelationalOperator(kind_val: ast_gen.SyntaxKind) bool {
    return kind_val == .LessThanToken or kind_val == .LessThanEqualsToken or kind_val == .GreaterThanToken or
        kind_val == .GreaterThanEqualsToken or kind_val == .InstanceOfKeyword or kind_val == .InKeyword;
}

pub fn isRelationalOperatorOrHigher(kind_val: ast_gen.SyntaxKind) bool {
    return isRelationalOperator(kind_val) or isShiftOperatorOrHigher(kind_val);
}

pub fn isEqualityOperator(kind_val: ast_gen.SyntaxKind) bool {
    return kind_val == .EqualsEqualsToken or kind_val == .EqualsEqualsEqualsToken or
        kind_val == .ExclamationEqualsToken or kind_val == .ExclamationEqualsEqualsToken;
}

pub fn isEqualityOperatorOrHigher(kind_val: ast_gen.SyntaxKind) bool {
    return isEqualityOperator(kind_val) or isRelationalOperatorOrHigher(kind_val);
}

pub fn isBitwiseOperator(kind_val: ast_gen.SyntaxKind) bool {
    return kind_val == .AmpersandToken or kind_val == .BarToken or kind_val == .CaretToken;
}

pub fn isBitwiseOperatorOrHigher(kind_val: ast_gen.SyntaxKind) bool {
    return isBitwiseOperator(kind_val) or isEqualityOperatorOrHigher(kind_val);
}

pub fn isLogicalOperatorOrHigher(kind_val: ast_gen.SyntaxKind) bool {
    return ast.isLogicalBinaryOperator(kind_val) or isBitwiseOperatorOrHigher(kind_val);
}

pub fn isAssignmentOperatorOrHigher(kind_val: ast_gen.SyntaxKind) bool {
    return kind_val == .QuestionQuestionToken or isLogicalOperatorOrHigher(kind_val) or ast.isAssignmentOperator(kind_val);
}

pub fn isBinaryOperator(kind_val: ast_gen.SyntaxKind) bool {
    return isAssignmentOperatorOrHigher(kind_val) or kind_val == .CommaToken;
}

pub fn getContainingFunctionOrClassStaticBlock(ast_data: *const ast.Ast, node: NodeIndex) NodeIndex {
    return ast.findAncestor(ast_data, ast_data.getParent(node), ast.isFunctionLikeOrClassStaticBlockDeclaration);
}

pub fn isNodeDescendantOf(ast_data: *const ast.Ast, node: NodeIndex, ancestor: NodeIndex) bool {
    var curr = node;
    while (curr != 0) {
        if (curr == ancestor) return true;
        curr = ast_data.getParent(curr);
    }
    return false;
}

pub fn isThisProperty(ast_data: *const ast.Ast, node: NodeIndex) bool {
    if (ast.isPropertyAccessExpression(ast_data, node) or ast.isElementAccessExpression(ast_data, node)) {
        if (ast_data.getExpression(node)) |expr| {
            return ast_data.getNode(expr) == .ThisKeyword;
        }
    }
    return false;
}

pub fn isValidNumberString(s: []const u8, roundTripOnly: bool) bool {
    _ = roundTripOnly;
    if (s.len == 0) return false;
    return true; // !!!
}

pub fn isValidBigIntString(s: []const u8, roundTripOnly: bool) bool {
    _ = s;
    _ = roundTripOnly;
    return false; // !!!
}

pub fn isValidESSymbolDeclaration(ast_data: *const ast.Ast, node: NodeIndex) bool {
    if (ast.isVariableDeclaration(ast_data, node)) {
        const name = ast_data.getName(node);
        return ast.isVarConst(ast_data, node) and (if (name) |n| ast.isIdentifier(ast_data, n) else false) and isVariableDeclarationInVariableStatement(ast_data, node);
    }
    if (ast.isPropertyDeclaration(ast_data, node)) {
        return ast.hasModifier(ast_data, node, ast_gen.ModifierFlags.Readonly) and ast.hasModifier(ast_data, node, ast_gen.ModifierFlags.Static);
    }
    return ast.isPropertySignatureDeclaration(ast_data, node) and ast.hasModifier(ast_data, node, ast_gen.ModifierFlags.Readonly);
}

pub fn isVariableDeclarationInVariableStatement(ast_data: *const ast.Ast, node: NodeIndex) bool {
    const parent = ast_data.getParent(node);
    if (parent == 0) return false;
    const parent2 = ast_data.getParent(parent);
    if (parent2 == 0) return false;
    return ast_data.getNode(parent) == .VariableDeclarationList and ast_data.getNode(parent2) == .VariableStatement;
}


pub fn isClassInstanceProperty(ast_data: *const ast.Ast, node: NodeIndex) bool {
    const parent = ast_data.getParent(node);
    if (parent != 0 and ast.isClassLike(ast_data, parent) and ast.isPropertyDeclaration(ast_data, node) and !ast.hasAccessorModifier(ast_data, node)) {
        return true;
    }
    return false;
}

pub fn isThisInitializedObjectBindingExpression(ast_data: *const ast.Ast, node: NodeIndex) bool {
    if (node == 0) return false;
    if (ast.isShorthandPropertyAssignment(ast_data, node) or ast.isPropertyAssignment(ast_data, node)) {
        const parent = ast_data.getParent(node);
        if (parent == 0) return false;
        const parent2 = ast_data.getParent(parent);
        if (parent2 == 0) return false;
        const p2_data = ast_data.getNode(parent2);
        if (p2_data == .BinaryExpression) {
            if (p2_data.BinaryExpression.OperatorToken != 0 and ast_data.getNode(p2_data.BinaryExpression.OperatorToken) == .EqualsToken) {
                if (p2_data.BinaryExpression.Right != 0 and ast_data.getNode(p2_data.BinaryExpression.Right) == .ThisKeyword) {
                    return true;
                }
            }
        }
    }
    return false;
}

pub fn isThisInitializedDeclaration(ast_data: *const ast.Ast, node: NodeIndex) bool {
    if (node == 0) return false;
    const n_data = ast_data.getNode(node);
    if (n_data == .VariableDeclaration) {
        const init = n_data.VariableDeclaration.Initializer;
        if (init != 0 and ast_data.getNode(init) == .ThisKeyword) {
            return true;
        }
    }
    return false;
}

pub fn isInfinityOrNaNString(name: []const u8) bool {
    return std.mem.eql(u8, name, "Infinity") or std.mem.eql(u8, name, "-Infinity") or std.mem.eql(u8, name, "NaN");
}

pub fn isConstantVariable(c: *Checker, sym: *const symbol.Symbol) bool {
    return (sym.flags & symbol.SymbolFlags.Variable) != 0 and (c.getDeclarationNodeFlagsFromSymbol(sym) & ast_gen.NodeFlags.Constant) != 0;
}

pub fn isParameterOrMutableLocalVariable(c: *Checker, sym: *const symbol.Symbol) bool {
    if (sym.ValueDeclaration) |decl| {
        const declaration = ast.getRootDeclaration(&c.binder.ast, decl);
        if (declaration != 0) {
            const decl_node = c.binder.ast.getNode(declaration);
            if (decl_node == .Parameter) return true;
            if (decl_node == .VariableDeclaration) {
                const parent = c.binder.ast.getParent(declaration);
                if (parent != 0 and c.binder.ast.getNode(parent) == .CatchClause) return true;
                if (c.isMutableLocalVariableDeclaration(declaration)) return true;
            }
        }
    }
    return false;
}

pub fn isMutableLocalVariableDeclaration(c: *Checker, declaration: NodeIndex) bool {
    const parent = c.binder.ast.getParent(declaration);
    if (parent == 0) return false;
    if ((c.binder.ast.getNodeFlags(parent) & ast_gen.NodeFlags.Let) != 0) {
        const combined = ast.getCombinedModifierFlags(&c.binder.ast, declaration);
        if ((combined & ast_gen.ModifierFlags.Export) != 0) return false;
        const parent2 = c.binder.ast.getParent(parent);
        if (parent2 != 0 and c.binder.ast.getNode(parent2) == .VariableStatement) {
            const parent3 = c.binder.ast.getParent(parent2);
            if (parent3 != 0 and ast.isGlobalSourceFile(&c.binder.ast, parent3)) return false;
        }
        return true;
    }
    return false;
}

pub fn isInAmbientOrTypeNode(ast_data: *const ast.Ast, node: NodeIndex) bool {
    if ((ast_data.getNodeFlags(node) & ast_gen.NodeFlags.Ambient) != 0) return true;
    var curr = node;
    while (curr != 0) {
        const n_data = ast_data.getNode(curr);
        if (n_data == .InterfaceDeclaration or n_data == .TypeAliasDeclaration or n_data == .JSDocTypeAlias or n_data == .TypeLiteral) return true;
        curr = ast_data.getParent(curr);
    }
    return false;
}

pub fn isLiteralExpressionOfObject(ast_data: *const ast.Ast, node: NodeIndex) bool {
    const n_data = ast_data.getNode(node);
    switch (n_data) {
        .ObjectLiteralExpression, .ArrayLiteralExpression, .RegularExpressionLiteral, .FunctionExpression, .ClassExpression => return true,
        else => return false,
    }
}

pub fn canHaveFlowNode(ast_data: *const ast.Ast, node: NodeIndex) bool {
    _ = ast_data;
    _ = node;
    return true; 
}

pub fn isNonNullAccess(ast_data: *const ast.Ast, node: NodeIndex) bool {
    if (ast.isAccessExpression(ast_data, node)) {
        if (ast_data.getExpression(node)) |expr| {
            if (ast_data.getNode(expr) == .NonNullExpression) return true;
        }
    }
    return false;
}


pub fn callLikeExpressionMayHaveTypeArguments(ast_data: *const ast.Ast, node: NodeIndex) bool {
    const n_data = ast_data.getNode(node);
    switch (n_data) {
        .CallExpression, .NewExpression, .TaggedTemplateExpression, .JsxOpeningElement, .JsxSelfClosingElement => return true,
        else => return false,
    }
}


pub fn expressionResultIsUnused(ast_data: *const ast.Ast, node_in: NodeIndex) bool {
    var node = node_in;
    while (true) {
        const parent = ast_data.getParent(node);
        if (parent == 0) return false;
        const p_data = ast_data.getNode(parent);
        if (p_data == .ParenthesizedExpression) {
            node = parent;
            continue;
        }
        if (p_data == .ExpressionStatement or p_data == .VoidExpression) return true;
        if (p_data == .ForStatement) {
            if (p_data.ForStatement.Initializer == node or p_data.ForStatement.Incrementor == node) return true;
        }
        if (p_data == .BinaryExpression and p_data.BinaryExpression.OperatorToken != 0 and ast_data.getNode(p_data.BinaryExpression.OperatorToken) == .CommaToken) {
            if (node == p_data.BinaryExpression.Left) return true;
            node = parent;
            continue;
        }
        return false;
    }
}

pub fn getEnclosingContainer(ast_data: *const ast.Ast, node: NodeIndex) NodeIndex {
    return ast.findAncestor(ast_data, ast_data.getParent(node), ast.isContainer);
}

pub fn getDeclarationsOfKind(ast_data: *const ast.Ast, decls: []const NodeIndex, kind_val: ast_gen.SyntaxKind, allocator: std.mem.Allocator) ![]NodeIndex {
    var result = std.ArrayList(NodeIndex).init(allocator);
    for (decls) |d| {
        if (ast_data.getNode(d).tag() == kind_val) {
            try result.append(d);
        }
    }
    return result.toOwnedSlice();
}


pub fn getNonRestParameterCount(ast_data: *const ast.Ast, sig: *const types.Signature) usize {
    _ = ast_data;
    if (sig.parameters.len == 0) return 0;
    return sig.parameters.len; // stub
}

pub fn minAndMax(slice: []const usize) struct { min: usize, max: usize } {
    if (slice.len == 0) return .{ .min = 0, .max = 0 };
    var min_v = slice[0];
    var max_v = slice[0];
    for (slice) |v| {
        if (v < min_v) min_v = v;
        if (v > max_v) max_v = v;
    }
    return .{ .min = min_v, .max = max_v };
}

pub fn tryGetPropertyAccessOrIdentifierToString(ast_data: *const ast.Ast, node: NodeIndex, allocator: std.mem.Allocator) !?[]const u8 {
    _ = allocator;
    switch (ast_data.getNode(node)) {
        .Identifier => |n| return ast_data.getIdentifierText(n.Text),
        else => return null,
    }
}

pub fn allDeclarationsInSameSourceFile(ast_data: *const ast.Ast, decls: []const NodeIndex) bool {
    if (decls.len > 1) {
        var sourceFile: NodeIndex = 0;
        for (decls, 0..) |d, i| {
            if (i == 0) {
                sourceFile = ast.getSourceFileOfNode(ast_data, d);
            } else if (ast.getSourceFileOfNode(ast_data, d) != sourceFile) {
                return false;
            }
        }
    }
    return true;
}

pub fn containsNonMissingUndefinedType(c: *Checker, t: *const types.Type) bool {
    var candidate = t;
    if ((t.flags & types.TypeFlags.Union) != 0) {
        candidate = &c.typesList.items[t.data.Union.types[0]];
    }
    return (candidate.flags & types.TypeFlags.Undefined) != 0;
}

pub fn getAnyImportSyntax(ast_data: *const ast.Ast, node: NodeIndex) NodeIndex {
    switch (ast_data.getNode(node)) {
        .ImportEqualsDeclaration => return node,
        .ImportClause => return ast_data.getParent(node),
        .NamespaceImport => return ast_data.getParent(ast_data.getParent(node)),
        .ImportSpecifier => return ast_data.getParent(ast_data.getParent(ast_data.getParent(node))),
        else => return 0,
    }
}


pub fn introducesArgumentsExoticObject(ast_data: *const ast.Ast, node: NodeIndex) bool {
    switch (ast_data.getNode(node)) {
        .MethodDeclaration, .MethodSignature, .Constructor, .GetAccessor, .SetAccessor, .FunctionDeclaration, .FunctionExpression => return true,
        else => return false,
    }
}

pub fn skipAlias(c: *Checker, sym: *const symbol.Symbol) *const symbol.Symbol {
    if ((sym.flags & symbol.SymbolFlags.Alias) != 0) {
        return c.getAliasedSymbol(sym); // stub
    }
    return sym;
}

pub fn isExternalModuleSymbol(sym: *const symbol.Symbol) bool {
    return (sym.flags & symbol.SymbolFlags.Module) != 0 and sym.name.len > 0 and sym.name[0] == '"';
}

pub fn valueToString(value: types.LiteralValue) []const u8 {
    _ = value;
    return ""; // stub
}

pub fn nodeStartsNewLexicalEnvironment(ast_data: *const ast.Ast, node: NodeIndex) bool {
    switch (ast_data.getNode(node)) {
        .Constructor, .FunctionExpression, .FunctionDeclaration, .ArrowFunction, .MethodDeclaration, .GetAccessor, .SetAccessor, .ModuleDeclaration, .SourceFile => return true,
        else => return false,
    }
}

pub fn isJSLiteralType(c: *Checker, t: *const types.Type) bool {
    _ = c;
    if ((t.objectFlags & types.ObjectFlags.JSLiteral) != 0) {
        return true;
    }
    return false;
}

pub fn walkUpOuterExpressions(ast_data: *const ast.Ast, node: NodeIndex) NodeIndex {
    var parent = ast_data.getParent(node);
    while (parent != 0 and ast.isOuterExpression(ast_data, parent)) {
        parent = ast_data.getParent(parent);
    }
    return parent;
}

pub fn getSetAccessorValueParameter(ast_data: *const ast.Ast, accessor: NodeIndex) NodeIndex {
    _ = ast_data;
    _ = accessor;
    return 0; // stub
}
