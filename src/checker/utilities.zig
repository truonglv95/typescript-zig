const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const ast = @import("../ast/ast.zig");
const symbol = @import("../ast/symbol.zig");
const checker_mod = @import("checker.zig");
const types = @import("types.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const ast_utils = @import("../ast/ast_utils.zig");

const Checker = checker_mod.Checker;
const NodeIndex = ast_gen.NodeIndex;
const SymbolIndex = ast_gen.SymbolIndex;
const TypeIndex = types.TypeIndex;

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

pub fn getAssignmentTargetKind(ast_data: *ast.Ast, node: NodeIndex) AssignmentKind {
    const target = ast_utils.getAssignmentTarget(ast_data, node);
    if (target == 0) return .None;

    const target_node = ast_data.getNode(target);
    switch (target_node) {
        .BinaryExpression => |bin| {
            const op = ast_data.getNode(bin.OperatorToken);
            // This is a simplification. We'd check the token kind in a real scenario.
            if (op == .EqualsToken or ast_utils.isLogicalOrCoalescingAssignmentOperator(op)) {
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

pub fn isOptionalDeclaration(ast_data: *ast.Ast, declaration: NodeIndex) bool {
    const node = ast_data.getNode(declaration);
    switch (node) {
        .Parameter => |n| return n.QuestionToken != null,
        .ConditionalExpression => |n| return n.QuestionToken != 0,
        .MappedType => |n| return n.QuestionToken != null,
        .NamedTupleMember => |n| return n.QuestionToken != null,
        .PropertyDeclaration => |n| return n.PostfixToken != null and ast_data.getNode(n.PostfixToken.?) == .QuestionToken,
        .PropertySignature => |n| return n.PostfixToken != null and ast_data.getNode(n.PostfixToken.?) == .QuestionToken,
        .MethodDeclaration => |n| return n.PostfixToken != null and ast_data.getNode(n.PostfixToken.?) == .QuestionToken,
        .MethodSignature => |n| return n.PostfixToken != null and ast_data.getNode(n.PostfixToken.?) == .QuestionToken,
        else => return false,
    }
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
        .ArrowFunction, .Block, .CallSignature, .CaseBlock, .CatchClause, .ClassStaticBlockDeclaration, .ConditionalType, .Constructor, .ConstructorType, .ConstructSignature, .ForStatement, .ForInStatement, .ForOfStatement, .FunctionDeclaration, .FunctionExpression, .FunctionType, .GetAccessor, .IndexSignature, .JSDocSignature, .MappedType, .MethodDeclaration, .MethodSignature, .ModuleDeclaration, .SetAccessor, .SourceFile, .TypeAliasDeclaration, .JSTypeAliasDeclaration => return true,
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
        .ImportClause, .ImportSpecifier, .NamespaceImport, .ExportSpecifier, .ExportAssignment, .ImportEqualsDeclaration, .NamespaceExport => return parent,
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

pub fn getDeclarationModifierFlagsFromSymbol(c: *const @import("checker.zig").Checker, sym: ast_gen.SymbolIndex) u32 {
    return getDeclarationModifierFlagsFromSymbolEx(c, sym, false);
}

pub fn getDeclarationModifierFlagsFromSymbolEx(c: *const @import("checker.zig").Checker, sym: ast_gen.SymbolIndex, isWrite: bool) u32 {
    const symObj = &c.binder.symbols.items[sym];
    if (symObj.ValueDeclaration) |val_decl| {
        var declaration: ast_gen.NodeIndex = 0;
        if (isWrite) {
            for (symObj.Declarations.items) |decl| {
                if (c.binder.ast.getKind(decl) == .SetAccessor) {
                    declaration = decl;
                    break;
                }
            }
        }
        if (declaration == 0 and (symObj.flags & symbol.SymbolFlags.GetAccessor) != 0) {
            for (symObj.Declarations.items) |decl| {
                if (c.binder.ast.getKind(decl) == .GetAccessor) {
                    declaration = decl;
                    break;
                }
            }
        }
        if (declaration == 0) {
            declaration = val_decl;
        }
        const flags = ast_utils.getCombinedModifierFlags(c.binder.ast, declaration);
        if (symObj.parent != 0 and (c.binder.symbols.items[symObj.parent].flags & symbol.SymbolFlags.Class) != 0) {
            return flags;
        }
        return flags & ~@as(u32, ast_gen.ModifierFlags.AccessibilityModifier);
    }
    if ((symObj.checkFlags & symbol.CheckFlags.Synthetic) != 0) {
        var accessModifier: u32 = 0;
        if ((symObj.checkFlags & symbol.CheckFlags.ContainsPrivate) != 0) {
            accessModifier = ast_gen.ModifierFlags.Private;
        } else if ((symObj.checkFlags & symbol.CheckFlags.ContainsPublic) != 0) {
            accessModifier = ast_gen.ModifierFlags.Public;
        } else {
            accessModifier = ast_gen.ModifierFlags.Protected;
        }
        var staticModifier: u32 = 0;
        if ((symObj.checkFlags & symbol.CheckFlags.ContainsStatic) != 0) {
            staticModifier = ast_gen.ModifierFlags.Static;
        }
        return accessModifier | staticModifier;
    }
    if ((symObj.flags & symbol.SymbolFlags.Prototype) != 0) {
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
    const nodeFlags = if (sym.ValueDeclaration) |decl| ast_utils.getCombinedNodeFlags(c.binder.ast, decl) else 0;
    return (sym.Flags & symbol.SymbolFlags.Variable) != 0 and (nodeFlags & ast_utils.NodeFlags.Const) != 0;
}

pub fn isParameterOrMutableLocalVariable(c: *Checker, sym: *const symbol.Symbol) bool {
    if (sym.ValueDeclaration) |decl| {
        const declaration = ast_utils.getRootDeclaration(c.binder.ast, decl);
        if (declaration != 0) {
            const decl_node = c.binder.ast.getNode(declaration);
            if (decl_node == .Parameter) return true;
            if (decl_node == .VariableDeclaration) {
                const parent = ast_utils.getParent(c.binder.ast, declaration);
                if (parent != 0 and c.binder.ast.getNode(parent) == .CatchClause) return true;
                if (isMutableLocalVariableDeclaration(c, declaration)) return true;
            }
        }
    }
    return false;
}

pub fn isMutableLocalVariableDeclaration(c: *Checker, declaration: NodeIndex) bool {
    const parent = ast_utils.getParent(c.binder.ast, declaration);
    if (parent == 0) return false;
    if ((c.binder.ast.getNodeFlags(parent) & ast_utils.NodeFlags.Let) != 0) {
        const combined = ast_utils.getCombinedModifierFlags(c.binder.ast, declaration);
        if ((combined & ast_utils.ModifierFlags.Export) != 0) return false;
        const parent2 = ast_utils.getParent(c.binder.ast, parent);
        if (parent2 != 0 and c.binder.ast.getNode(parent2) == .VariableStatement) {
            const parent3 = ast_utils.getParent(c.binder.ast, parent2);
            if (parent3 != 0 and ast_utils.isGlobalSourceFile(c.binder.ast, parent3)) return false;
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
    const n_data = @constCast(ast_data).getNode(node);
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

pub fn getNonRestParameterCount(c: *Checker, sigIndex: types.SignatureIndex) usize {
    const sig = &c.signaturesList.items[sigIndex];
    if (sig.parametersLen == 0) return 0;
    if ((sig.flags & types.SignatureFlags.HasRestParameter) != 0) {
        return sig.parametersLen - 1;
    }
    return sig.parametersLen;
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

pub fn isExternalModuleSymbol(sym: *const symbol.Symbol) bool {
    return (sym.flags & symbol.SymbolFlags.Module) != 0 and sym.name.len > 0 and sym.name[0] == '"';
}

pub fn valueToString(value: types.LiteralValue) []const u8 {
    _ = value;
    return "";
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
    if (accessor != 0 and ast_data.getNodeKind(accessor) == .SetAccessor) {
        const parametersList = ast_data.nodes.items[accessor].data.SetAccessor.Parameters;
        if (parametersList != 0) {
            const parameters = ast_data.getNodeArray(parametersList);
            if (parameters.len > 0) {
                return parameters[0];
            }
        }
    }
    return 0;
}

pub fn isInCompoundLikeAssignment(c: *const @import("checker.zig").Checker, node: ast_gen.NodeIndex) bool {
    const target = ast_utils.getAssignmentTarget(c.binder.ast, node);
    return target != 0 and ast_utils.isAssignmentExpression(c.binder.ast, target, true) and isCompoundLikeAssignment(c, target);
}

pub fn isCompoundLikeAssignment(c: *const @import("checker.zig").Checker, assignment: ast_gen.NodeIndex) bool {
    const right = ast_utils.skipParentheses(c.binder.ast, c.binder.ast.getNode(assignment).BinaryExpression.Right);
    return c.binder.ast.getKind(right) == .BinaryExpression and isShiftOperatorOrHigher(c.binder.ast.getNode(right).BinaryExpression.OperatorTokenKind);
}

pub fn isInTypeQuery(c: *const @import("checker.zig").Checker, node: ast_gen.NodeIndex) bool {
    var current = node;
    while (current != 0) {
        const kind = c.binder.ast.getKind(current);
        if (kind == .TypeQuery) return true;
        if (kind == .Identifier or kind == .QualifiedName) {
            current = c.binder.ast.getNodeParent(current);
            continue;
        }
        return false;
    }
    return false;
}

pub fn isRightSideOfAccessExpression(c: *const @import("checker.zig").Checker, node: ast_gen.NodeIndex) bool {
    const parent = c.binder.ast.getNodeParent(node);
    if (parent == 0) return false;
    const parentKind = c.binder.ast.getKind(parent);
    if (parentKind == .PropertyAccessExpression) {
        return c.binder.ast.getNode(parent).PropertyAccessExpression.Name == node;
    }
    if (parentKind == .ElementAccessExpression) {
        return c.binder.ast.getNode(parent).ElementAccessExpression.ArgumentExpression == node;
    }
    return false;
}

pub fn isLateBoundName(name: []const u8) bool {
    return name.len >= 2 and name[0] == '\xfe' and name[1] == '@';
}

pub fn isObjectOrArrayLiteralType(t: *const types.Type) bool {
    return (t.objectFlags & (types.ObjectFlags.ObjectLiteral | types.ObjectFlags.ArrayLiteral)) != 0;
}

pub fn skipAlias(c: *const @import("checker.zig").Checker, sym: ast_gen.SymbolIndex) ast_gen.SymbolIndex {
    if (sym == 0) return 0;
    const symObj = c.binder.symbols.items[sym];
    if ((symObj.flags & ast.SymbolFlags.Alias) != 0) {
        return c.getAliasedSymbol(sym);
    }
    return sym;
}

pub fn isCallChain(ast_data: *const ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    return ast_utils.isCallExpression(ast_data, node) and (ast_data.getNode(node).CallExpression.flags & ast_gen.NodeFlags.OptionalChain) != 0;
}

pub fn isSuperCall(ast_data: *const ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    if (ast_utils.isCallExpression(ast_data, node)) {
        const expr = ast_data.getNode(node).CallExpression.Expression;
        if (expr != 0 and ast_data.getKind(expr) == .SuperKeyword) {
            return true;
        }
    }
    return false;
}

pub fn getContainingObjectLiteral(ast_data: *const ast.Ast, f: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (f == 0) return 0;
    const kind = ast_data.getKind(f);
    const parent = ast_data.getNodeParent(f);
    if (parent == 0) return 0;

    if ((kind == .MethodDeclaration or kind == .GetAccessor or kind == .SetAccessor) and ast_data.getKind(parent) == .ObjectLiteralExpression) {
        return parent;
    } else if (kind == .FunctionExpression and ast_data.getKind(parent) == .PropertyAssignment) {
        return ast_data.getNodeParent(parent);
    }
    return 0;
}

pub fn isImportTypeQualifierPart(ast_data: *const ast.Ast, node_in: ast_gen.NodeIndex) ast_gen.NodeIndex {
    var node = node_in;
    var parent = ast_data.getNodeParent(node);
    while (ast_utils.isQualifiedName(ast_data, parent)) {
        node = parent;
        parent = ast_data.getNodeParent(parent);
    }
    if (parent != 0 and ast_data.getKind(parent) == .ImportType) {
        const import_type = ast_data.getNode(parent).ImportType;
        if (import_type.Qualifier == node) {
            return parent;
        }
    }
    return 0;
}

pub fn isInNameOfExpressionWithTypeArguments(ast_data: *const ast.Ast, node_in: ast_gen.NodeIndex) bool {
    var node = node_in;
    var parent = ast_data.getNodeParent(node);
    while (parent != 0 and ast_data.getKind(parent) == .PropertyAccessExpression) {
        node = parent;
        parent = ast_data.getNodeParent(node);
    }
    return parent != 0 and ast_data.getKind(parent) == .ExpressionWithTypeArguments;
}

pub fn isThisTypeParameter(c: *const @import("checker.zig").Checker, typeIndex: types.TypeIndex) bool {
    if (typeIndex == 0) return false;
    const typeObj = c.typesList.items[typeIndex];
    if ((typeObj.flags & types.TypeFlags.TypeParameter) != 0) {
        return typeObj.data.TypeParameter.isThisType;
    }
    return false;
}

pub fn isKnownSymbol(c: *const @import("checker.zig").Checker, sym: ast_gen.SymbolIndex) bool {
    if (sym == 0) return false;
    const name = ast_utils.getNameOfSymbol(c.binder.ast, c.binder.symbols.items, sym);
    return isLateBoundName(name);
}

pub fn isPrivateIdentifierSymbol(c: *const @import("checker.zig").Checker, sym: ast_gen.SymbolIndex) bool {
    if (sym == 0) return false;
    const name = ast_utils.getNameOfSymbol(c.binder.ast, c.binder.symbols.items, sym);
    return std.mem.startsWith(u8, name, "__#");
}

pub fn hasExportAssignmentSymbol(c: *const @import("checker.zig").Checker, sym: ast_gen.SymbolIndex) bool {
    if (sym == 0) return false;
    const symObj = c.binder.symbols.items[sym];
    for (symObj.Declarations.items) |decl| {
        if (c.binder.ast.getKind(decl) == .ExportAssignment) {
            return true;
        }
    }
    return false;
}

pub fn getContainingClass(ast_data: *const ast.Ast, node_in: ast_gen.NodeIndex) ast_gen.NodeIndex {
    var node = ast_data.getNodeParent(node_in);
    while (node != 0) {
        if (ast_utils.isClassLike(ast_data, node)) {
            return node;
        }
        node = ast_data.getNodeParent(node);
    }
    return 0;
}

pub fn getContainingClassExcludingClassDecorators(ast_data: *const ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    var decorator: ast_gen.NodeIndex = 0;
    var current = ast_data.getNodeParent(node);
    while (current != 0) {
        if (ast_utils.isClassLike(ast_data, current)) {
            break;
        }
        if (ast_utils.isDecorator(ast_data, current)) {
            decorator = current;
            break;
        }
        current = ast_data.getNodeParent(current);
    }

    if (decorator != 0) {
        const parent = ast_data.getNodeParent(decorator);
        if (ast_utils.isClassLike(ast_data, parent)) {
            return getContainingClass(ast_data, parent);
        }
        return getContainingClass(ast_data, decorator);
    }
    return getContainingClass(ast_data, node);
}

pub fn getSuperContainer(ast_data: *const ast.Ast, node_in: ast_gen.NodeIndex, stopOnFunctions: bool) ast_gen.NodeIndex {
    var node = node_in;
    while (true) {
        node = ast_data.getNodeParent(node);
        if (node == 0) return 0;
        const kind = ast_data.getKind(node);
        switch (kind) {
            .ComputedPropertyName => {
                node = ast_data.getNodeParent(node);
            },
            .FunctionDeclaration, .FunctionExpression, .ArrowFunction => {
                if (!stopOnFunctions) {
                    continue;
                }
                return node;
            },
            .PropertyDeclaration, .PropertySignature, .MethodDeclaration, .MethodSignature, .Constructor, .GetAccessor, .SetAccessor, .ClassStaticBlockDeclaration => {
                return node;
            },
            .Decorator => {
                const parent = ast_data.getNodeParent(node);
                if (ast_utils.isParameterDeclaration(ast_data, parent)) {
                    const grandparent = ast_data.getNodeParent(parent);
                    if (ast_utils.isClassElement(ast_data, grandparent)) {
                        node = grandparent;
                    }
                } else if (ast_utils.isClassElement(ast_data, parent)) {
                    node = parent;
                }
            },
            else => {},
        }
    }
}

pub fn isInRightSideOfImportOrExportAssignment(ast_data: *const ast.Ast, node_in: ast_gen.NodeIndex) bool {
    var node = node_in;
    var parent = ast_data.getNodeParent(node);
    while (parent != 0 and ast_data.getKind(parent) == .QualifiedName) {
        node = parent;
        parent = ast_data.getNodeParent(node);
    }
    if (parent == 0) return false;
    const kind = ast_data.getKind(parent);
    if (kind == .ImportEqualsDeclaration and ast_data.getNode(parent).ImportEqualsDeclaration.ModuleReference == node) return true;
    if (kind == .ExportAssignment and ast_data.getNode(parent).ExportAssignment.Expression == node) return true;
    return false;
}

pub fn getBindingElementPropertyName(ast_data: *const ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (node == 0) return 0;
    const kind = ast_data.getKind(node);
    if (kind == .BindingElement) {
        const be = ast_data.getNode(node).BindingElement;
        if (be.PropertyName != 0) {
            return be.PropertyName;
        }
        return be.Name;
    }
    return 0;
}

pub fn getExternalModuleRequireArgument(ast_data: *const ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (ast_utils.isVariableDeclarationInitializedToRequire(ast_data, node)) {
        const init = ast_data.getNode(node).VariableDeclaration.Initializer.?;
        if (init != 0 and ast_data.getKind(init) == .CallExpression) {
            const call = ast_data.getNode(init).CallExpression;
            if (call.Arguments != 0) {
                const args = ast_data.getNodeList(call.Arguments);
                if (args.len > 0) return args[0];
            }
        }
    }
    return 0;
}

pub fn getTypeNameSymbol(t: *const types.Type) ?ast_gen.SymbolIndex {
    if (t.alias != null) {
        return t.alias.?.symbol;
    }
    if ((t.flags & (types.TypeFlags.TypeParameter | types.TypeFlags.StringMapping)) != 0 or (t.objectFlags & (types.ObjectFlags.ClassOrInterface | types.ObjectFlags.Reference)) != 0) {
        return t.symbol;
    }
    return null;
}

const YieldExpressionVisitor = struct {
    visitor: *const fn (node: ast_gen.NodeIndex, context: ?*anyopaque) bool,
    context: ?*anyopaque,
    tree: *ast.Ast,

    pub fn visit(self: *YieldExpressionVisitor, node: ast_gen.NodeIndex) bool {
        const kind = self.tree.getKind(node);
        if (kind == .YieldExpression) {
            if (self.visitor(node, self.context)) {
                return true;
            }
            const operand_opt = self.tree.getNode(node).YieldExpression.Expression;
            if (operand_opt) |operand| {
                if (operand == 0) return false;
                return self.visit(operand);
            }
            return false;
        }
        switch (kind) {
            .EnumDeclaration, .InterfaceDeclaration, .ModuleDeclaration, .TypeAliasDeclaration => {
                return false;
            },
            else => {
                if (ast_utils.isFunctionLike(kind)) {
                    const name = ast_utils.getNameOfNode(self.tree, node);
                    if (name != 0 and ast_utils.isComputedPropertyName(self.tree, name)) {
                        return self.visit(name);
                    }
                    return false;
                } else if (kind == .ClassDeclaration or kind == .ClassExpression) {
                    return false;
                }
            },
        }
        return ast_utils.forEachChildBool(self.tree, node, self, visit);
    }
};

pub fn forEachYieldExpression(tree: *ast.Ast, body: ast_gen.NodeIndex, visitor: *const fn (node: ast_gen.NodeIndex, context: ?*anyopaque) bool, context: ?*anyopaque) bool {
    var v = YieldExpressionVisitor{ .visitor = visitor, .context = context, .tree = tree };
    return v.visit(body);
}

pub fn newDiagnosticForNode(node: ast_gen.NodeIndex, message: *const diagnostics.Message) diagnostics.Diagnostic {
    return diagnostics.Diagnostic{
        .message = message,
        .nodeIndex = node,
    };
}

pub fn newDiagnosticChainForNode(chain: diagnostics.Diagnostic, node: ast_gen.NodeIndex, message: *const diagnostics.Message) diagnostics.Diagnostic {
    _ = chain;
    // In DoD, creating an array slice dynamically requires an allocator.
    // For now, we will just return the diagnostic.
    return diagnostics.Diagnostic{
        .message = message,
        .nodeIndex = node,
    };
}

pub fn entityNameToString(c: *Checker, name: ast_gen.NodeIndex) []const u8 {
    return ast_utils.getTextOfNode(&c.binder.ast, name);
}

pub fn createSymbolTable(c: *Checker, symbols: []const ast_gen.SymbolIndex) !*symbol.SymbolTable {
    const table = try c.allocator.create(symbol.SymbolTable);
    table.* = symbol.SymbolTable.empty;
    for (symbols) |sym| {
        const name = ast_utils.getNameOfSymbol(c.binder.ast, c.binder.symbols.items, sym);
        try table.put(c.allocator, name, sym);
    }
    return table;
}

pub fn sortSymbols(c: *Checker, symbols: []ast_gen.SymbolIndex) void {
    const SortContext = struct {
        checker: *Checker,
        pub fn lessThan(self: @This(), lhs: ast_gen.SymbolIndex, rhs: ast_gen.SymbolIndex) bool {
            return compareSymbolsWorker(self.checker, lhs, rhs) < 0;
        }
    };
    std.mem.sort(ast_gen.SymbolIndex, symbols, SortContext{ .checker = c }, SortContext.lessThan);
}

pub fn compareSymbolsWorker(c: *Checker, s1: ast_gen.SymbolIndex, s2: ast_gen.SymbolIndex) i32 {
    if (s1 == s2) return 0;
    if (s1 == 0) return 1;
    if (s2 == 0) return -1;

    const sym1 = c.binder.symbols.items[s1];
    const sym2 = c.binder.symbols.items[s2];

    if (sym1.Declarations.items.len != 0 and sym2.Declarations.items.len != 0) {
        const comp = compareNodes(c, sym1.Declarations.items[0], sym2.Declarations.items[0]);
        if (comp != 0) return comp;
    } else if (sym1.Declarations.items.len != 0) {
        return -1;
    } else if (sym2.Declarations.items.len != 0) {
        return 1;
    }

    const name1 = ast_utils.getNameOfSymbol(c.binder.ast, c.binder.symbols.items, s1);
    const name2 = ast_utils.getNameOfSymbol(c.binder.ast, c.binder.symbols.items, s2);

    const compName = std.mem.order(u8, name1, name2);
    if (compName != .eq) {
        return switch (compName) {
            .lt => -1,
            .gt => 1,
            else => unreachable,
        };
    }

    return if (s1 > s2) 1 else -1;
}

pub fn checkNotCanceled(c: *Checker) void {
    _ = c;
}

pub fn isCanceled(c: *Checker) bool {
    _ = c;
    return false;
}

pub fn symbolsToArray(symbols: *anyopaque) []const ast_gen.SymbolIndex {
    _ = symbols;
    return &[_]ast_gen.SymbolIndex{};
}

pub fn getIndexSymbolFromSymbolTable(table: ?*symbol.SymbolTable) ast_gen.SymbolIndex {
    if (table) |t| {
        return t.get(symbol.InternalSymbolNameIndex) orelse 0;
    }
    return 0;
}

pub fn isJsxIntrinsicTagName(name: []const u8) bool {
    if (name.len == 0) return false;
    const ch = name[0];
    if (ch >= 'a' and ch <= 'z') return true;
    for (name) |c| {
        if (c == '-') return true;
    }
    return false;
}

pub fn isUncheckedJSSuggestion(node: ast_gen.NodeIndex) bool {
    _ = node;
    return false;
}

pub fn compareNodes(c: *Checker, n1: ast_gen.NodeIndex, n2: ast_gen.NodeIndex) i32 {
    if (n1 == n2) return 0;
    if (n1 == 0) return 1;
    if (n2 == 0) return -1;

    const s1 = ast_utils.getSourceFileOfNode(&c.binder.ast, n1);
    const s2 = ast_utils.getSourceFileOfNode(&c.binder.ast, n2);

    if (s1 != s2) {
        return if (s1 > s2) 1 else -1;
    }

    const pos1 = c.binder.ast.nodes.items[n1].pos;
    const pos2 = c.binder.ast.nodes.items[n2].pos;
    if (pos1 != pos2) {
        return if (pos1 > pos2) 1 else -1;
    }
    return 0;
}

pub fn compareTypeNames(c: *Checker, t1: types.TypeIndex, t2: types.TypeIndex) i32 {
    const type1 = &c.typesList.items[t1];
    const type2 = &c.typesList.items[t2];
    const s1 = getTypeNameSymbol(type1);
    const s2 = getTypeNameSymbol(type2);
    if (s1 == s2) {
        if (type1.alias != null and type2.alias != null) {
            // Wait, alias.typeArguments is a slice of TypeIndex?
            // In types.zig, alias.typeArguments is a slice
            return compareTypeLists(c, type1.alias.?.typeArguments, type2.alias.?.typeArguments);
        }
        return 0;
    }
    if (s1 == null) return 1;
    if (s2 == null) return -1;

    const name1 = ast_utils.getNameOfSymbol(c.binder.ast, c.binder.symbols.items, s1.?);
    const name2 = ast_utils.getNameOfSymbol(c.binder.ast, c.binder.symbols.items, s2.?);

    return switch (std.mem.order(u8, name1, name2)) {
        .lt => -1,
        .eq => 0,
        .gt => 1,
    };
}

pub fn compareTypeLists(c: *Checker, l1: []const types.TypeIndex, l2: []const types.TypeIndex) i32 {
    if (l1.len != l2.len) return if (l1.len > l2.len) 1 else -1;
    for (l1, 0..) |t1, i| {
        const comp = compareTypes(c, t1, l2[i]);
        if (comp != 0) return comp;
    }
    return 0;
}

pub fn compareTupleTypes(c: *Checker, t1: types.TypeIndex, t2: types.TypeIndex) i32 {
    const tuple1 = c.typesList.items[t1].data.Tuple;
    const tuple2 = c.typesList.items[t2].data.Tuple;

    if (t1 == t2) return 0;
    if (tuple1.readonly != tuple2.readonly) return if (tuple1.readonly) 1 else -1;

    const infos1 = tuple1.elementInfos;
    const infos2 = tuple2.elementInfos;

    if (infos1.len != infos2.len) return if (infos1.len > infos2.len) 1 else -1;

    for (infos1, 0..) |info1, i| {
        const info2 = infos2[i];
        if (@intFromEnum(info1.flags) != @intFromEnum(info2.flags)) {
            return if (@intFromEnum(info1.flags) > @intFromEnum(info2.flags)) 1 else -1;
        }
    }

    for (infos1, 0..) |info1, i| {
        const info2 = infos2[i];
        const comp = compareElementLabels(c, info1.labeledDeclaration, info2.labeledDeclaration);
        if (comp != 0) return comp;
    }
    return 0;
}

pub fn compareTypeMappers(c: *Checker, m1: types.TypeMapperIndex, m2: types.TypeMapperIndex) i32 {
    if (m1 == m2) return 0;
    if (m1 == 0) return 1;
    if (m2 == 0) return -1;

    const mapper1 = &c.mappersList.items[m1];
    const mapper2 = &c.mappersList.items[m2];

    if (@intFromEnum(mapper1.kind) != @intFromEnum(mapper2.kind)) {
        return if (@intFromEnum(mapper1.kind) > @intFromEnum(mapper2.kind)) 1 else -1;
    }

    switch (mapper1.kind) {
        .Simple => {
            const comp = compareTypes(c, mapper1.data.Simple.source, mapper2.data.Simple.source);
            if (comp != 0) return comp;
            return compareTypes(c, mapper1.data.Simple.target, mapper2.data.Simple.target);
        },
        .Array => {
            const compSources = compareTypeLists(c, mapper1.data.Array.sources, mapper2.data.Array.sources);
            if (compSources != 0) return compSources;
            return compareTypeLists(c, mapper1.data.Array.targets, mapper2.data.Array.targets);
        },
        .Merged => {
            const compM1 = compareTypeMappers(c, mapper1.data.Merged.m1, mapper2.data.Merged.m1);
            if (compM1 != 0) return compM1;
            return compareTypeMappers(c, mapper1.data.Merged.m2, mapper2.data.Merged.m2);
        },
        else => return 0,
    }
}

pub fn getObjectTypeName(t: types.TypeIndex) []const u8 {
    _ = t;
    return "";
}

pub fn getSortOrderFlags(c: *Checker, t: types.TypeIndex) u32 {
    const flags = c.typesList.items[t].flags;
    if ((flags & (types.TypeFlags.EnumLiteral | types.TypeFlags.Enum)) != 0 and (flags & types.TypeFlags.Union) == 0) {
        return types.TypeFlags.Enum;
    }
    return flags;
}

pub fn pseudoBigIntToString(v: *anyopaque) []const u8 {
    _ = v;
    return "";
}

pub fn rangeOfTypeParameters(source: []const types.TypeIndex, start: usize, end: usize) []const types.TypeIndex {
    _ = source;
    _ = start;
    _ = end;
    return &[_]types.TypeIndex{};
}

pub fn compareTypes(c: *Checker, t1: types.TypeIndex, t2: types.TypeIndex) i32 {
    if (t1 == t2) return 0;
    if (t1 == 0) return -1;
    if (t2 == 0) return 1;

    // Sort by type flags
    const f1 = getSortOrderFlags(c, t1);
    const f2 = getSortOrderFlags(c, t2);
    if (f1 != f2) return if (f1 > f2) 1 else -1;

    const cNames = compareTypeNames(c, t1, t2);
    if (cNames != 0) return cNames;

    const typeObj1 = &c.typesList.items[t1];
    const typeObj2 = &c.typesList.items[t2];
    const type1Flags = typeObj1.flags;

    if ((type1Flags & (types.TypeFlags.Any | types.TypeFlags.Unknown | types.TypeFlags.String | types.TypeFlags.Number | types.TypeFlags.Boolean | types.TypeFlags.BigInt | types.TypeFlags.ESSymbol | types.TypeFlags.Void | types.TypeFlags.Undefined | types.TypeFlags.Null | types.TypeFlags.Never | types.TypeFlags.NonPrimitive)) != 0) {
        // Fall back to type IDs below
    } else if ((type1Flags & types.TypeFlags.Object) != 0) {
        const symComp = compareSymbolsWorker(c, typeObj1.data.Object.Symbol orelse 0, typeObj2.data.Object.Symbol orelse 0);
        if (symComp != 0) return symComp;

        if ((typeObj1.objectFlags & types.ObjectFlags.Reference) != 0 and (typeObj2.objectFlags & types.ObjectFlags.Reference) != 0) {
            const target1 = typeObj1.data.Object.target orelse 0;
            const target2 = typeObj2.data.Object.target orelse 0;
            if (target1 != 0 and target2 != 0 and (c.typesList.items[target1].objectFlags & types.ObjectFlags.Tuple) != 0 and (c.typesList.items[target2].objectFlags & types.ObjectFlags.Tuple) != 0) {
                const tupleComp = compareTupleTypes(c, target1, target2);
                if (tupleComp != 0) return tupleComp;
            }

            if ((typeObj1.data.Object.node orelse 0) == 0 and (typeObj2.data.Object.node orelse 0) == 0) {
                const args1 = c.typeArgumentsPool.items[typeObj1.data.Object.typeArgumentsStart .. typeObj1.data.Object.typeArgumentsStart + typeObj1.data.Object.typeArgumentsLen];
                const args2 = c.typeArgumentsPool.items[typeObj2.data.Object.typeArgumentsStart .. typeObj2.data.Object.typeArgumentsStart + typeObj2.data.Object.typeArgumentsLen];
                const listComp = compareTypeLists(c, args1, args2);
                if (listComp != 0) return listComp;
            } else {
                const nodeComp = compareNodes(c, typeObj1.data.Object.node orelse 0, typeObj2.data.Object.node orelse 0);
                if (nodeComp != 0) return nodeComp;

                const mapComp = compareTypeMappers(c, typeObj1.data.Object.mapper orelse 0, typeObj2.data.Object.mapper orelse 0);
                if (mapComp != 0) return mapComp;
            }
        } else if ((typeObj1.objectFlags & types.ObjectFlags.Reference) != 0) {
            return -1;
        } else if ((typeObj2.objectFlags & types.ObjectFlags.Reference) != 0) {
            return 1;
        } else {
            const kind1 = typeObj1.objectFlags & types.ObjectFlags.ObjectTypeKindMask;
            const kind2 = typeObj2.objectFlags & types.ObjectFlags.ObjectTypeKindMask;
            if (kind1 != kind2) return if (kind1 > kind2) 1 else -1;

            const mapComp = compareTypeMappers(c, typeObj1.data.Object.mapper orelse 0, typeObj2.data.Object.mapper orelse 0);
            if (mapComp != 0) return mapComp;
        }
    } else if ((type1Flags & types.TypeFlags.Union) != 0) {
        const o1 = typeObj1.data.Union.origin orelse 0;
        const o2 = typeObj2.data.Union.origin orelse 0;
        if (o1 == 0 and o2 == 0) {
            const types1 = c.unionTypesPool.items[typeObj1.data.Union.typesStart .. typeObj1.data.Union.typesStart + typeObj1.data.Union.typesLen];
            const types2 = c.unionTypesPool.items[typeObj2.data.Union.typesStart .. typeObj2.data.Union.typesStart + typeObj2.data.Union.typesLen];
            const listComp = compareTypeLists(c, types1, types2);
            if (listComp != 0) return listComp;
        } else if (o1 == 0) {
            return 1;
        } else if (o2 == 0) {
            return -1;
        } else {
            const originComp = compareTypes(c, o1, o2);
            if (originComp != 0) return originComp;
        }
    } else if ((type1Flags & types.TypeFlags.Intersection) != 0) {
        const types1 = c.unionTypesPool.items[typeObj1.data.Intersection.typesStart .. typeObj1.data.Intersection.typesStart + typeObj1.data.Intersection.typesLen];
        const types2 = c.unionTypesPool.items[typeObj2.data.Intersection.typesStart .. typeObj2.data.Intersection.typesStart + typeObj2.data.Intersection.typesLen];
        const listComp = compareTypeLists(c, types1, types2);
        if (listComp != 0) return listComp;
    } else if ((type1Flags & (types.TypeFlags.Enum | types.TypeFlags.EnumLiteral | types.TypeFlags.UniqueESSymbol)) != 0) {
        const symComp = compareSymbolsWorker(c, typeObj1.symbol, typeObj2.symbol);
        if (symComp != 0) return symComp;
    } else if ((type1Flags & types.TypeFlags.StringLiteral) != 0) {
        return std.mem.order(u8, typeObj1.data.StringLiteral.text, typeObj2.data.StringLiteral.text).compare();
    } else if ((type1Flags & types.TypeFlags.NumberLiteral) != 0) {
        const num1 = typeObj1.data.NumberLiteral.value;
        const num2 = typeObj2.data.NumberLiteral.value;
        if (num1 != num2) return if (num1 > num2) 1 else -1;
    } else if ((type1Flags & types.TypeFlags.BooleanLiteral) != 0) {
        const b1 = typeObj1.data.BooleanLiteral.value;
        const b2 = typeObj2.data.BooleanLiteral.value;
        if (b1 != b2) return if (b1) 1 else -1;
    } else if ((type1Flags & types.TypeFlags.TypeParameter) != 0) {
        const symComp = compareSymbolsWorker(c, typeObj1.symbol, typeObj2.symbol);
        if (symComp != 0) return symComp;
    } else if ((type1Flags & types.TypeFlags.Index) != 0) {
        const targetComp = compareTypes(c, typeObj1.data.Index.target, typeObj2.data.Index.target);
        if (targetComp != 0) return targetComp;
        // In Go it also compares indexFlags, but we don't have indexFlags in Index in Zig yet. Let's ignore it.
    } else if ((type1Flags & types.TypeFlags.IndexedAccess) != 0) {
        const objComp = compareTypes(c, typeObj1.data.IndexedAccess.objectType, typeObj2.data.IndexedAccess.objectType);
        if (objComp != 0) return objComp;
        const indexComp = compareTypes(c, typeObj1.data.IndexedAccess.indexType, typeObj2.data.IndexedAccess.indexType);
        if (indexComp != 0) return indexComp;
    } else if ((type1Flags & types.TypeFlags.Conditional) != 0) {
        const nodeComp = compareNodes(c, typeObj1.data.Conditional.root.node, typeObj2.data.Conditional.root.node);
        if (nodeComp != 0) return nodeComp;
        const mapComp = compareTypeMappers(c, typeObj1.data.Conditional.mapper, typeObj2.data.Conditional.mapper);
        if (mapComp != 0) return mapComp;
    } else if ((type1Flags & types.TypeFlags.Substitution) != 0) {
        const baseComp = compareTypes(c, typeObj1.data.Substitution.baseType, typeObj2.data.Substitution.baseType);
        if (baseComp != 0) return baseComp;
        const consComp = compareTypes(c, typeObj1.data.Substitution.constraint, typeObj2.data.Substitution.constraint);
        if (consComp != 0) return consComp;
    } else if ((type1Flags & types.TypeFlags.TemplateLiteral) != 0) {
        // Compare texts
        const texts1 = typeObj1.data.TemplateLiteral.texts;
        const texts2 = typeObj2.data.TemplateLiteral.texts;
        if (texts1.len != texts2.len) return if (texts1.len > texts2.len) 1 else -1;
        for (texts1, 0..) |text1, i| {
            const comp = std.mem.order(u8, text1, texts2[i]).compare();
            if (comp != 0) return comp;
        }
        const types1 = c.unionTypesPool.items[typeObj1.data.TemplateLiteral.typesStart .. typeObj1.data.TemplateLiteral.typesStart + typeObj1.data.TemplateLiteral.typesLen];
        const types2 = c.unionTypesPool.items[typeObj2.data.TemplateLiteral.typesStart .. typeObj2.data.TemplateLiteral.typesStart + typeObj2.data.TemplateLiteral.typesLen];
        const typesComp = compareTypeLists(c, types1, types2);
        if (typesComp != 0) return typesComp;
    } else if ((type1Flags & types.TypeFlags.StringMapping) != 0) {
        const targetComp = compareTypes(c, typeObj1.data.StringMapping.target, typeObj2.data.StringMapping.target);
        if (targetComp != 0) return targetComp;
    }

    // Fall back to type IDs
    const id1 = typeObj1.id;
    const id2 = typeObj2.id;
    if (id1 != id2) return if (id1 > id2) 1 else -1;

    return 0;
}

pub fn createModuleNotFoundChain(c: *Checker, node: ast_gen.NodeIndex, specifier: []const u8) *anyopaque {
    _ = c;
    _ = node;
    _ = specifier;
    return undefined;
}

pub fn createModeMismatchDetails(c: *Checker, node: ast_gen.NodeIndex, specifier: []const u8) *anyopaque {
    _ = c;
    _ = node;
    _ = specifier;
    return undefined;
}

pub fn getPackagesMap(c: *Checker) *std.StringHashMapUnmanaged(bool) {
    if (c.packagesMap == null) {
        c.packagesMap = std.StringHashMapUnmanaged(bool).empty;
    }
    return &c.packagesMap.?;
}

pub fn packageBundlesTypes(c: *Checker, name: []const u8) bool {
    const packagesMap = getPackagesMap(c);
    if (packagesMap.get(name)) |hasTypes| {
        return hasTypes;
    }
    return false;
}

pub fn typesPackageExists(c: *Checker, name: []const u8) bool {
    _ = c;
    _ = name;
    return false;
}

pub fn add(set: *anyopaque, value: *anyopaque) void {
    _ = set;
    _ = value;
}

pub fn contains(set: *anyopaque, value: *anyopaque) bool {
    _ = set;
    _ = value;
    return false;
}

pub fn compareElementLabels(c: *Checker, n1: ast_gen.NodeIndex, n2: ast_gen.NodeIndex) i32 {
    if (n1 == n2) return 0;
    if (n1 == 0) return -1;
    if (n2 == 0) return 1;

    const name1Node = ast_utils.getNameOfNode(c.binder.ast, n1);
    const name2Node = ast_utils.getNameOfNode(c.binder.ast, n2);

    if (name1Node == 0 and name2Node == 0) return 0;
    if (name1Node == 0) return -1;
    if (name2Node == 0) return 1;

    const text1 = tryGetPropertyAccessOrIdentifierToString(&c.binder.ast, name1Node, c.allocator) catch null;
    const text2 = tryGetPropertyAccessOrIdentifierToString(&c.binder.ast, name2Node, c.allocator) catch null;

    if (text1 == null and text2 == null) return 0;
    if (text1 == null) return -1;
    if (text2 == null) return 1;

    return switch (std.mem.order(u8, text1.?, text2.?)) {
        .lt => -1,
        .eq => 0,
        .gt => 1,
    };
}
