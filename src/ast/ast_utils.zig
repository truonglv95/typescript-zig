const std = @import("std");
const ast = @import("ast.zig");
const ast_gen = @import("ast_generated.zig");

pub const getTouchingPropertyName = @import("../astnav/tokens.zig").getTouchingPropertyName;

pub fn isPropertyAccessOrQualifiedName(tree: *ast.Ast, node: ast.NodeIndex) bool {
    const k = tree.getNodeKind(node);
    return k == .PropertyAccessExpression or k == .QualifiedName;
}
const kind = @import("kind.zig");
const ast_pkg = @import("ast.zig");

pub fn isTypeOnly(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .ImportEqualsDeclaration => |n| return n.IsTypeOnly != 0,
        .ExportDeclaration => |n| return n.IsTypeOnly != 0,
        .ImportSpecifier => |n| return n.IsTypeOnly != 0,
        .ExportSpecifier => |n| return n.IsTypeOnly != 0,
        else => return false,
    }
}

pub fn isParameterPropertyDeclaration(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex, parentIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    if (node != .Parameter) return false;
    const parent = tree.getNode(parentIndex);
    if (parent != .Constructor) return false;
    return hasSyntacticModifier(tree, nodeIndex, ModifierFlags.ParameterPropertyModifier);
}

pub const OEKParentheses: u32 = 1 << 0;
pub const OEKTypeAssertions: u32 = 1 << 1;
pub const OEKNonNullAssertions: u32 = 1 << 2;
pub const OEKPartiallyEmittedExpressions: u32 = 1 << 3;
pub const OEKAssertions: u32 = OEKTypeAssertions | OEKNonNullAssertions;
pub const OEKAll: u32 = OEKParentheses | OEKAssertions | OEKPartiallyEmittedExpressions;
pub const OEKExcludeJSDocTypeAssertion: u32 = 1 << 4;
pub const OEKAllExceptAssertionsOrExpressionsWithTypeArguments: u32 = OEKParentheses | OEKPartiallyEmittedExpressions;

pub fn isJSDocTypeAssertion(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    _ = a;
    _ = nodeIndex;
    return false; // TODO
}

pub fn skipOuterExpressions(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex, kinds: u32) ast_gen.NodeIndex {
    var curr = nodeIndex;
    while (curr != 0) {
        const node = a.getNode(curr);
        switch (node) {
            .ParenthesizedExpression => |n| {
                if (kinds & OEKParentheses != 0) {
                    curr = n.Expression;
                    continue;
                }
            },
            .TypeAssertionExpression => |n| {
                if (kinds & OEKTypeAssertions != 0) {
                    curr = n.Expression;
                    continue;
                }
            },
            .AsExpression => |n| {
                if (kinds & OEKTypeAssertions != 0) {
                    curr = n.Expression;
                    continue;
                }
            },
            .NonNullExpression => |n| {
                if (kinds & OEKNonNullAssertions != 0) {
                    curr = n.Expression;
                    continue;
                }
            },
            .PartiallyEmittedExpression => |n| {
                if (kinds & OEKPartiallyEmittedExpressions != 0) {
                    curr = n.Expression;
                    continue;
                }
            },
            else => {},
        }
        break;
    }
    return curr;
}

pub fn isEnumConst(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    return hasSyntacticModifier(a, nodeIndex, ModifierFlags.Const);
}

pub fn isBinaryExpression(nodeData: ast_gen.NodeData) bool {
    return std.meta.activeTag(nodeData) == .BinaryExpression;
}

pub fn getSourceFileOfNode(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
    var curr = nodeIndex;
    while (curr != 0) {
        if (tree.getNode(curr) == .SourceFile) return curr;
        curr = tree.getNodeParent(curr);
    }
    return 0;
}

pub fn resolveJSDoc(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) []const ast_gen.NodeIndex {
    // Lazy JSDoc resolution placeholder for now (Phase 2), will be wired to Parser in Phase 3.
    return tree.jsdocCache.get(nodeIndex) orelse &[_]ast_gen.NodeIndex{};
}

pub fn getJSDoc(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) []const ast_gen.NodeIndex {
    const flags = tree.getNodeFlags(nodeIndex);
    if ((flags & NodeFlags.HasJSDoc) == 0) {
        return &[_]ast_gen.NodeIndex{};
    }
    if (tree.hasLazyJSDoc) {
        return resolveJSDoc(tree, nodeIndex);
    }
    return tree.jsdocCache.get(nodeIndex) orelse &[_]ast_gen.NodeIndex{};
}

pub fn getEagerJSDoc(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) []const ast_gen.NodeIndex {
    const flags = tree.getNodeFlags(nodeIndex);
    if ((flags & NodeFlags.HasJSDoc) == 0) {
        return &[_]ast_gen.NodeIndex{};
    }
    return tree.jsdocCache.get(nodeIndex) orelse &[_]ast_gen.NodeIndex{};
}

pub fn isNonLocalAlias(tree: *ast_pkg.Ast, symIndex: ast_gen.SymbolIndex, excludes: u32) bool {
    const sym = tree.symbols.items[symIndex];
    return (sym.Flags & (@import("symbol.zig").SymbolFlags.Alias | excludes)) == @import("symbol.zig").SymbolFlags.Alias;
}

pub fn getName(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (nodeIndex == 0) return 0;
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .ModuleDeclaration => |n| return n.name,
        .EnumDeclaration => |n| return n.name,
        .EnumMember => |n| return n.name,
        .ClassDeclaration => |n| return n.name orelse 0,
        .FunctionDeclaration => |n| return n.name orelse 0,
        .VariableDeclaration => |n| return n.name,
        .InterfaceDeclaration => |n| return n.name,
        .TypeAliasDeclaration => |n| return n.name,
        .MethodDeclaration => |n| return n.name,
        .PropertyDeclaration => |n| return n.name,
        .GetAccessor => |n| return n.name,
        .SetAccessor => |n| return n.name,
        .Parameter => |n| return n.name,
        .TypeParameter => |n| return n.name,
        .NamespaceExportDeclaration => |n| return n.name,
        else => return 0,
    }
}

pub const JSDeclarationKind = enum {
    None,
    ModuleExports,
    ExportsProperty,
    ThisProperty,
    PropertyAssignment,
    PrototypeProperty,
};

pub fn getAssignmentDeclarationKind(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) JSDeclarationKind {
    const node = tree.getNode(nodeIndex);
    if (node != .BinaryExpression) return .None;
    const bin = node.BinaryExpression;
    if (tree.getNodeKind(bin.operatorToken) != .EqualsToken) return .None;

    if (tree.getNodeKind(bin.left) == .PropertyAccessExpression) {
        const pae = tree.getNode(bin.left).PropertyAccessExpression;
        if (pae.expression != 0) {
            const expKind = tree.getNodeKind(pae.expression);
            if (expKind == .Identifier) {
                const idText = tree.getIdentifierText(pae.expression);
                if (std.mem.eql(u8, idText, "exports")) {
                    return .ExportsProperty;
                }
            } else if (expKind == .PropertyAccessExpression) {
                const inner = tree.getNode(pae.expression).PropertyAccessExpression;
                if (inner.expression != 0 and tree.getNodeKind(inner.expression) == .Identifier) {
                    const idText = tree.getIdentifierText(inner.expression);
                    if (std.mem.eql(u8, idText, "module")) {
                        const nameText = tree.getIdentifierText(inner.name);
                        if (std.mem.eql(u8, nameText, "exports")) {
                            return .ExportsProperty;
                        }
                    }
                }
            }
        }
    }

    return .None;
}

pub fn isAliasSymbolDeclaration(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .ImportEqualsDeclaration, .NamespaceExportDeclaration, .NamespaceImport, .NamespaceExport, .ImportSpecifier, .ExportSpecifier => return true,
        .ImportClause => |n| return n.name != 0,
        .ExportAssignment => |n| return expressionIsAlias(tree, n.expression),
        .VariableDeclaration => |n| return if (n.initializer != 0) isRequireCall(tree, n.initializer, true) else false,
        .BindingElement => |n| return if (n.initializer != 0) isRequireCall(tree, n.initializer, true) else false,
        .BinaryExpression => |n| {
            const assignmentKind = getAssignmentDeclarationKind(tree, nodeIndex);
            if (assignmentKind == .ModuleExports or assignmentKind == .ExportsProperty) {
                return expressionIsAlias(tree, n.right);
            }
            return false;
        },
        else => return false,
    }
}

pub fn expressionIsAlias(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    return isEntityNameExpression(tree, nodeIndex) or tree.getNodeKind(nodeIndex) == .ClassExpression;
}

pub const ModifierFlags = struct {
    pub const None: u32 = 0;
    pub const Public: u32 = 1 << 0;
    pub const Private: u32 = 1 << 1;
    pub const Protected: u32 = 1 << 2;
    pub const Readonly: u32 = 1 << 3;
    pub const Override: u32 = 1 << 4;
    pub const Export: u32 = 1 << 5;
    pub const Abstract: u32 = 1 << 6;
    pub const Ambient: u32 = 1 << 7;
    pub const Static: u32 = 1 << 8;
    pub const Accessor: u32 = 1 << 9;
    pub const Async: u32 = 1 << 10;
    pub const Default: u32 = 1 << 11;
    pub const Const: u32 = 1 << 12;
    pub const In: u32 = 1 << 13;
    pub const Out: u32 = 1 << 14;
    pub const Decorator: u32 = 1 << 15;
    pub const Deprecated: u32 = 1 << 16;

    pub const ParameterPropertyModifier: u32 = Public | Private | Protected | Readonly | Override;
    pub const NonPublicAccessibilityModifier: u32 = Private | Protected;
    pub const TypeScriptModifier: u32 = Ambient | Public | Private | Protected | Readonly | Abstract | Const | Override | In | Out;
    pub const ExportDefault: u32 = Export | Default;
};

pub const ContainerFlags = struct {
    pub const None: u32 = 0;
    pub const IsContainer: u32 = 1 << 0;
    pub const IsBlockScopedContainer: u32 = 1 << 1;
    pub const IsControlFlowContainer: u32 = 1 << 2;
    pub const IsFunctionLike: u32 = 1 << 3;
    pub const IsFunctionExpression: u32 = 1 << 4;
    pub const HasLocals: u32 = 1 << 5;
    pub const IsInterface: u32 = 1 << 6;
    pub const IsObjectLiteralOrClassExpressionMethodOrAccessor: u32 = 1 << 7;
    pub const IsThisContainer: u32 = 1 << 8;
    pub const PropagatesThisKeyword: u32 = 1 << 9;
};

pub const NodeFlags = struct {
    pub const None: u32 = 0;
    pub const Let: u32 = 1 << 0;
    pub const Const: u32 = 1 << 1;
    pub const Using: u32 = 1 << 2;
    pub const Reparsed: u32 = 1 << 3;
    pub const Synthesized: u32 = 1 << 4;
    pub const OptionalChain: u32 = 1 << 5;
    pub const ExportContext: u32 = 1 << 6;
    pub const ContainsThis: u32 = 1 << 7;
    pub const HasImplicitReturn: u32 = 1 << 8;
    pub const HasExplicitReturn: u32 = 1 << 9;
    pub const DisallowInContext: u32 = 1 << 10;
    pub const YieldContext: u32 = 1 << 11;
    pub const DecoratorContext: u32 = 1 << 12;
    pub const AwaitContext: u32 = 1 << 13;
    pub const DisallowConditionalTypesContext: u32 = 1 << 14;
    pub const ThisNodeHasError: u32 = 1 << 15;
    pub const JavaScriptFile: u32 = 1 << 16;
    pub const ThisNodeOrAnySubNodesHasError: u32 = 1 << 17;
    pub const HasAsyncFunctions: u32 = 1 << 18;
    pub const PossiblyContainsDynamicImport: u32 = 1 << 19;
    pub const PossiblyContainsImportMeta: u32 = 1 << 20;
    pub const HasJSDoc: u32 = 1 << 21;
    pub const JSDoc: u32 = 1 << 22;
    pub const Ambient: u32 = 1 << 23;
    pub const InWithStatement: u32 = 1 << 24;
    pub const JsonFile: u32 = 1 << 25;
    pub const PossiblyContainsDeprecatedTag: u32 = 1 << 26;
    pub const Unreachable: u32 = 1 << 27;
    pub const ReparserTransformedLiteral: u32 = 1 << 28;

    pub const BlockScoped: u32 = Let | Const | Using;
    pub const Constant: u32 = Const | Using;
    pub const AwaitUsing: u32 = Const | Using;
    pub const ReachabilityCheckFlags: u32 = HasImplicitReturn | HasExplicitReturn;
    pub const ReachabilityAndEmitFlags: u32 = ReachabilityCheckFlags | HasAsyncFunctions;

    pub const Namespace: u32 = 1 << 29;
    pub const GlobalAugmentation: u32 = 1 << 30;
    pub const NestedNamespace: u32 = 1 << 31;
    pub const ContextFlags: u32 = DisallowInContext | DisallowConditionalTypesContext | YieldContext | DecoratorContext | AwaitContext | JavaScriptFile | InWithStatement | Ambient;
    pub const TypeExcludesFlags: u32 = YieldContext | AwaitContext;
};

pub fn isInJSFile(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    if (nodeIndex == 0) return false;
    var current = nodeIndex;
    while (current != 0) {
        if ((a.getNodeFlags(current) & NodeFlags.JavaScriptFile) != 0) return true;
        if (a.getNode(current) == .SourceFile) return false;
        current = a.getNodeParent(current);
    }
    return false;
}

pub fn getModifiers(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ?u32 {
    const node = a.getNode(nodeIndex);
    switch (node) {
        .FunctionDeclaration => |n| return n.modifiers,
        .ClassDeclaration => |n| return n.modifiers,
        .VariableStatement => |n| return n.modifiers,
        .InterfaceDeclaration => |n| return n.modifiers,
        .TypeAliasDeclaration => |n| return n.modifiers,
        .EnumDeclaration => |n| return n.modifiers,
        .ModuleDeclaration => |n| return n.modifiers,
        .ImportEqualsDeclaration => |n| return n.modifiers,
        .MethodDeclaration => |n| return n.modifiers,
        .PropertyDeclaration => |n| return n.modifiers,
        .Constructor => return null,
        .GetAccessor => |n| return n.modifiers,
        .SetAccessor => |n| return n.modifiers,
        .Parameter => |n| return n.modifiers,
        .ExportAssignment => |n| return n.modifiers,
        else => return null,
    }
}

pub fn hasSyntacticModifier(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex, flag: u32) bool {
    const modifiersIndex = getModifiers(a, nodeIndex);
    if (modifiersIndex) |idx| {
        const modifiers = a.getNodeList(idx);
        for (modifiers) |modIndex| {
            const modNode = a.getNode(modIndex);
            switch (modNode) {
                .ExportKeyword => {
                    if ((flag & ModifierFlags.Export) != 0) return true;
                },
                .DeclareKeyword => {
                    if ((flag & ModifierFlags.Ambient) != 0) return true;
                },
                .PublicKeyword => {
                    if ((flag & ModifierFlags.Public) != 0) return true;
                },
                .PrivateKeyword => {
                    if ((flag & ModifierFlags.Private) != 0) return true;
                },
                .ProtectedKeyword => {
                    if ((flag & ModifierFlags.Protected) != 0) return true;
                },
                .ReadonlyKeyword => {
                    if ((flag & ModifierFlags.Readonly) != 0) return true;
                },
                .OverrideKeyword => {
                    if ((flag & ModifierFlags.Override) != 0) return true;
                },
                .DefaultKeyword => {
                    if ((flag & ModifierFlags.Default) != 0) return true;
                },
                .ConstKeyword => {
                    if ((flag & ModifierFlags.Const) != 0) return true;
                },
                .AbstractKeyword => {
                    if ((flag & ModifierFlags.Abstract) != 0) return true;
                },
                .StaticKeyword => {
                    if ((flag & ModifierFlags.Static) != 0) return true;
                },
                .AccessorKeyword => {
                    if ((flag & ModifierFlags.Accessor) != 0) return true;
                },
                .AsyncKeyword => {
                    if ((flag & ModifierFlags.Async) != 0) return true;
                },
                .InKeyword => {
                    if ((flag & ModifierFlags.In) != 0) return true;
                },
                .OutKeyword => {
                    if ((flag & ModifierFlags.Out) != 0) return true;
                },
                else => {},
            }
        }
    }
    return false;
}

pub fn isModuleWithStringLiteralName(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node_kind = a.getNodeKind(nodeIndex);
    if (node_kind == .ModuleDeclaration) {
        const mod_name = a.getNode(nodeIndex).ModuleDeclaration.name;
        if (mod_name != 0 and a.getNodeKind(mod_name) == .StringLiteral) {
            return true;
        }
    }
    return false;
}

pub fn isExternalModuleIndicator(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const tree = a;
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .ImportDeclaration, .ImportEqualsDeclaration, .ExportDeclaration, .JSImportDeclaration, .ExportAssignment => return true,
        else => {},
    }
    if (hasSyntacticModifier(tree, nodeIndex, ModifierFlags.Export)) {
        return true;
    }
    return false;
}

pub fn isDeclarationFile(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    _ = a;
    _ = nodeIndex;
    // We do not parse declaration files yet in transpile step, so return false.
    // Real implementation would check the filename.
    return false;
}

pub fn isExternalModuleReference(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = a.getNode(nodeIndex);
    return node == .ExternalModuleReference;
}

pub fn isExternalModuleImportEqualsDeclaration(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = a.getNode(nodeIndex);
    if (node != .ImportEqualsDeclaration) return false;
    return isExternalModuleReference(a, node.ImportEqualsDeclaration.ModuleReference);
}

pub fn isInstantiatedModule(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex, preserveConstEnums: bool) bool {
    const moduleState = getModuleInstanceState(a, nodeIndex);
    return moduleState == .Instantiated or (preserveConstEnums and moduleState == .ConstEnumOnly);
}

pub fn isThisIdentifier(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    if (node != .Identifier) return false;
    return std.mem.eql(u8, node.Identifier.Text, "this");
}

pub fn isThisParameter(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    if (node != .Parameter) return false;
    const p = node.Parameter;
    if (p.name == 0) return false;
    return isThisIdentifier(tree, p.name);
}

pub fn hasDecorators(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const modifiersIndex = getModifiers(tree, nodeIndex) orelse return false;
    if (modifiersIndex == 0) return false;
    const modifiers = tree.getNodeList(modifiersIndex);
    for (modifiers) |modIndex| {
        if (tree.getNode(modIndex) == .Decorator) {
            return true;
        }
    }
    return false;
}

pub fn isExternalModule(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = a.getNode(nodeIndex);
    if (node == .SourceFile) {
        return node.SourceFile.ExternalModuleIndicator != null and node.SourceFile.ExternalModuleIndicator.? != 0;
    }
    return false;
}

pub fn isAnExternalModuleIndicatorNode(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    if (hasSyntacticModifier(a, nodeIndex, ModifierFlags.Export)) {
        return true;
    }
    const node = a.getNode(nodeIndex);
    switch (node) {
        .ImportEqualsDeclaration => |n| {
            return isExternalModuleReference(a, n.ModuleReference);
        },
        .ImportDeclaration, .ExportAssignment, .ExportDeclaration => {
            return true;
        },
        else => {
            return false;
        },
    }
}

pub fn isFileProbablyExternalModule(a: *ast.Ast, sourceFileIndex: ast_gen.NodeIndex) ?ast_gen.NodeIndex {
    const sourceFileNode = a.getNode(sourceFileIndex).SourceFile;
    if (sourceFileNode.Statements != 0) {
        const stmts = a.getNodeList(sourceFileNode.Statements);
        for (stmts) |stmtIndex| {
            if (isAnExternalModuleIndicatorNode(a, stmtIndex)) {
                return stmtIndex;
            }
        }
    }
    return null;
}

pub fn isExternalOrCommonJSModule(a: *ast.Ast, sourceFileIndex: ast_gen.NodeIndex) bool {
    const sourceFileNode = a.getNode(sourceFileIndex).SourceFile;
    if (sourceFileNode.ExternalModuleIndicator) |_| {
        return true;
    }
    if (sourceFileNode.CommonJSModuleIndicator) |_| {
        return true;
    }
    return false;
}

pub fn isAmbientModule(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = a.getNode(nodeIndex);
    if (node == .ModuleDeclaration) {
        const nameNode = a.getNode(node.ModuleDeclaration.name);
        return nameNode == .StringLiteral or isGlobalScopeAugmentation(a, nodeIndex);
    }
    return false;
}

pub fn isBlockScopedVariable(astTree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const flags = getCombinedNodeFlags(astTree, nodeIndex);
    const result = (flags & NodeFlags.BlockScoped) != 0;
    return result; // TODO: CatchClauseVariableDeclaration
}

pub fn getRootDeclaration(astTree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
    var current = nodeIndex;
    while (current != 0 and std.meta.activeTag(astTree.getNode(current)) == .BindingElement) {
        const parent = astTree.getNodeParent(current);
        if (parent == 0) break;
        const grandParent = astTree.getNodeParent(parent);
        if (grandParent == 0) break;
        current = grandParent;
    }
    return current;
}

pub fn getCombinedNodeFlags(astTree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) u32 {
    var root = getRootDeclaration(astTree, nodeIndex);
    var flags = astTree.getNodeFlags(root);

    if (std.meta.activeTag(astTree.getNode(root)) == .VariableDeclaration) {
        root = astTree.getNodeParent(root);
    }

    if (root != 0 and std.meta.activeTag(astTree.getNode(root)) == .VariableDeclarationList) {
        flags |= astTree.getNodeFlags(root);
        root = astTree.getNodeParent(root);

        if (root != 0 and astTree.getKind(root) == .VariableStatement) {
            flags |= astTree.getNodeFlags(root);
        }
    }
    return flags;
}

pub fn getCombinedModifierFlags(tree: *ast.Ast, node: ast_gen.NodeIndex) u32 {
    _ = tree;
    _ = node;
    return 0; // Stub
}

pub fn isStringOrNumericLiteralLike(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    if (nodeIndex == 0) return false;
    const node = a.getNode(nodeIndex);
    switch (node) {
        .StringLiteral, .NumericLiteral, .NoSubstitutionTemplateLiteral => return true,
        else => return false,
    }
}

pub fn isDynamicName(a: *ast.Ast, nameNodeIndex: ast_gen.NodeIndex) bool {
    if (nameNodeIndex == 0) return false;
    const node = a.getNode(nameNodeIndex);
    switch (node) {
        .ComputedPropertyName => |n| {
            return !isStringOrNumericLiteralLike(a, n.Expression);
        },
        else => return false,
    }
}

pub fn hasDynamicName(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    if (nodeIndex == 0) return false;
    const node = a.getNode(nodeIndex);
    switch (node) {
        .PropertyDeclaration => |n| return isDynamicName(a, n.name),
        .MethodDeclaration => |n| return isDynamicName(a, n.name),
        .GetAccessor => |n| return isDynamicName(a, n.name),
        .SetAccessor => |n| return isDynamicName(a, n.name),
        .PropertySignature => |n| return isDynamicName(a, n.name),
        .MethodSignature => |n| return isDynamicName(a, n.name),
        else => return false,
    }
}

pub fn isConstAssertion(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = a.getNode(nodeIndex);
    if (node == .TypeAssertionExpression) {
        const typeNode = a.getNode(node.TypeAssertionExpression.Type);
        if (typeNode == .TypeReference) {
            const typeName = a.getNode(typeNode.TypeReference.TypeName);
            if (typeName == .Identifier) {
                return std.mem.eql(u8, typeName.Identifier.Text, "const");
            }
        }
    }
    if (node == .AsExpression) {
        const typeNode = a.getNode(node.AsExpression.Type);
        if (typeNode == .TypeReference) {
            const typeName = a.getNode(typeNode.TypeReference.TypeName);
            if (typeName == .Identifier) {
                return std.mem.eql(u8, typeName.Identifier.Text, "const");
            }
        }
    }
    return false;
}

pub fn isModuleOrEnumDeclaration(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = a.getNode(nodeIndex);
    return node == .ModuleDeclaration or node == .EnumDeclaration;
}

pub fn getNameOfNode(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const node = a.getNode(nodeIndex);
    switch (node) {
        .ModuleDeclaration => |n| return n.name,
        .EnumDeclaration => |n| return n.name,
        .ClassDeclaration => |n| return if (n.name) |n_name| n_name else 0,
        .FunctionDeclaration => |n| return if (n.name) |n_name| n_name else 0,
        .MethodDeclaration => |n| return n.name,
        .PropertyDeclaration => |n| return n.name,
        .GetAccessor => |n| return n.name,
        .SetAccessor => |n| return n.name,
        .VariableDeclaration => |n| return n.name,
        .Parameter => |n| return n.name,
        .BindingElement => |n| return if (n.name) |n_name| n_name else 0,
        .PropertySignature => |n| return n.name,
        .MethodSignature => |n| return n.name,
        .InterfaceDeclaration => |n| return n.name,
        .TypeAliasDeclaration => |n| return n.name,
        .ImportEqualsDeclaration => |n| return n.name,
        .ImportSpecifier => |n| return n.name,
        .ExportSpecifier => |n| return n.name,
        .EnumMember => |n| return n.name,
        .PropertyAssignment => |n| return n.name,
        .ShorthandPropertyAssignment => |n| return n.name,
        .JsxAttribute => |n| return n.name,
        .NamespaceImport => |n| return n.name,
        .NamespaceExport => |n| return n.name,
        .ImportClause => |n| return if (n.name) |n_name| n_name else 0,
        else => return 0,
    }
}

pub fn isGlobalSourceFile(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = a.getNode(nodeIndex);
    return node == .SourceFile and !isExternalModule(a, nodeIndex);
}

pub fn isFunctionLike(tag: std.meta.Tag(@import("ast_generated.zig").NodeData)) bool {
    switch (tag) {
        .FunctionDeclaration, .MethodDeclaration, .GetAccessor, .SetAccessor, .Constructor, .FunctionExpression, .ArrowFunction, .MethodSignature, .CallSignature, .JSDocSignature, .ConstructSignature, .IndexSignature, .FunctionType, .ConstructorType => return true,
        else => return false,
    }
}

pub fn isSomeDeclaration(astTree: *@import("ast.zig").Ast, nodeIndex: @import("ast_generated.zig").NodeIndex) bool {
    const node = astTree.getNode(nodeIndex);
    return switch (node) {
        .ArrowFunction, .BindingElement, .ClassDeclaration, .ClassExpression, .ClassStaticBlockDeclaration, .Constructor, .EnumDeclaration, .EnumMember, .ExportAssignment, .ExportDeclaration, .ExportSpecifier, .FunctionDeclaration, .FunctionExpression, .GetAccessor, .ImportClause, .ImportEqualsDeclaration, .ImportSpecifier, .InterfaceDeclaration, .JsxAttribute, .MethodDeclaration, .MethodSignature, .ModuleDeclaration, .NamespaceExport, .NamespaceExportDeclaration, .NamespaceImport, .Parameter, .PropertyAssignment, .PropertyDeclaration, .PropertySignature, .SetAccessor, .ShorthandPropertyAssignment, .TypeAliasDeclaration, .TypeParameter, .VariableDeclaration => true,
        else => false,
    };
}

pub fn isGlobalScopeAugmentation(astTree: *@import("ast.zig").Ast, nodeIndex: @import("ast_generated.zig").NodeIndex) bool {
    const node = astTree.getNode(nodeIndex);
    if (std.meta.activeTag(node) == .ModuleDeclaration) {
        return node.ModuleDeclaration.Keyword == @intFromEnum(@import("kind.zig").Kind.GlobalKeyword);
    }
    return false;
}
pub const ModuleInstanceState = enum {
    NonInstantiated,
    ConstEnumOnly,
    Instantiated,
    Unknown,
};

const AncestorsArray = struct {
    items: [256]ast_gen.NodeIndex,
    len: usize,

    pub fn append(self: *@This(), value: ast_gen.NodeIndex) void {
        if (self.len < self.items.len) {
            self.items[self.len] = value;
            self.len += 1;
        }
    }

    pub fn appendSlice(self: *@This(), s: []const ast_gen.NodeIndex) void {
        for (s) |item| {
            self.append(item);
        }
    }

    pub fn slice(self: *const @This()) []const ast_gen.NodeIndex {
        return self.items[0..self.len];
    }
};

pub fn getModuleInstanceState(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ModuleInstanceState {
    const node = tree.getNode(nodeIndex);
    if (node != .ModuleDeclaration) return .Instantiated;
    const body = tree.getNode(nodeIndex).ModuleDeclaration.Body;
    if (body) |b| {
        var ancestors: AncestorsArray = .{ .items = undefined, .len = 0 };
        ancestors.append(nodeIndex);
        var visited: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, ModuleInstanceState) = .empty;
        defer visited.deinit(tree.allocator);
        return getModuleInstanceStateCached(tree, b, &ancestors, &visited);
    }
    return .Instantiated;
}

fn getModuleInstanceStateCached(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex, ancestors: *AncestorsArray, visited: *std.AutoHashMapUnmanaged(ast_gen.NodeIndex, ModuleInstanceState)) ModuleInstanceState {
    if (visited.get(nodeIndex)) |state| {
        return state;
    }
    visited.put(tree.allocator, nodeIndex, .NonInstantiated) catch {};
    const state = getModuleInstanceStateWorker(tree, nodeIndex, ancestors, visited);
    visited.put(tree.allocator, nodeIndex, state) catch {};
    return state;
}

fn getModuleInstanceStateWorker(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex, ancestors: *AncestorsArray, visited: *std.AutoHashMapUnmanaged(ast_gen.NodeIndex, ModuleInstanceState)) ModuleInstanceState {
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .InterfaceDeclaration, .TypeAliasDeclaration, .JSTypeAliasDeclaration, .NotEmittedStatement => return .NonInstantiated,
        .EnumDeclaration => {
            if (hasSyntacticModifier(tree, nodeIndex, ModifierFlags.Const)) return .ConstEnumOnly;
            return .Instantiated;
        },
        .ImportDeclaration, .JSImportDeclaration, .ImportEqualsDeclaration => {
            if (!hasSyntacticModifier(tree, nodeIndex, ModifierFlags.Export)) return .NonInstantiated;
            return .Instantiated;
        },
        .ExportDeclaration => |n| {
            if (n.ModuleSpecifier == null or n.ModuleSpecifier.? == 0) {
                if (n.ExportClause != null and n.ExportClause.? != 0) {
                    const exportClauseNode = tree.getNode(n.ExportClause.?);
                    if (exportClauseNode == .NamedExports) {
                        var state: ModuleInstanceState = .NonInstantiated;
                        const save_len = ancestors.len;
                        ancestors.append(nodeIndex);
                        ancestors.append(n.ExportClause.?);
                        defer ancestors.len = save_len;

                        const elements = exportClauseNode.NamedExports.Elements;
                        if (elements != 0) {
                            for (tree.getNodeList(elements)) |specifier| {
                                const specifierState = getModuleInstanceStateForAliasTarget(tree, specifier, ancestors, visited);
                                if (@intFromEnum(specifierState) > @intFromEnum(state)) {
                                    state = specifierState;
                                }
                                if (state == .Instantiated) return state;
                            }
                        }
                        return state;
                    }
                }
            }
            return .Instantiated;
        },
        .ModuleBlock => {
            var state: ModuleInstanceState = .NonInstantiated;
            const block = tree.getNode(nodeIndex).ModuleBlock;
            const save_len = ancestors.len;
            ancestors.append(nodeIndex);
            defer ancestors.len = save_len;
            for (tree.getNodeList(block.Statements)) |stmt| {
                const childState = getModuleInstanceStateCached(tree, stmt, ancestors, visited);
                if (childState == .Instantiated) return .Instantiated;
                if (childState == .ConstEnumOnly) state = .ConstEnumOnly;
            }
            return state;
        },
        .ModuleDeclaration => |n| {
            if (n.Body) |b| {
                const save_len = ancestors.len;
                ancestors.append(nodeIndex);
                defer ancestors.len = save_len;
                return getModuleInstanceStateCached(tree, b, ancestors, visited);
            }
            return .Instantiated;
        },
        else => return .Instantiated,
    }
}

pub fn isPrologueDirective(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    if (node == .ExpressionStatement) {
        const exprStmt = node.ExpressionStatement;
        const exprNode = tree.getNode(exprStmt.Expression);
        return exprNode == .StringLiteral;
    }
    return false;
}

fn getModuleInstanceStateForAliasTarget(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex, ancestors: *AncestorsArray, visited: *std.AutoHashMapUnmanaged(ast_gen.NodeIndex, ModuleInstanceState)) ModuleInstanceState {
    const nameIndex = getPropertyNameOrName(tree, nodeIndex);
    if (nameIndex == 0 or tree.getNode(nameIndex) != .Identifier) {
        return .Instantiated;
    }

    var current_node = nodeIndex;
    var i: usize = ancestors.len;
    while (true) {
        var p: ast_gen.NodeIndex = 0;
        if (i > 0) {
            i -= 1;
            p = ancestors.items[i];
        } else {
            p = tree.getNodeParent(current_node);
        }
        if (p == 0) break;
        current_node = p;

        const parentNode = tree.getNode(p);
        if (parentNode == .Block or parentNode == .ModuleBlock or parentNode == .SourceFile) {
            var found: ModuleInstanceState = .Unknown;
            const statements = switch (parentNode) {
                .Block => parentNode.Block.Statements,
                .ModuleBlock => parentNode.ModuleBlock.Statements,
                .SourceFile => parentNode.SourceFile.Statements,
                else => 0,
            };
            if (statements != 0) {
                var new_ancestors: AncestorsArray = .{ .items = undefined, .len = 0 };
                new_ancestors.appendSlice(ancestors.items[0..i]);
                new_ancestors.append(p);

                const stmtList = tree.getNodeList(statements);
                for (stmtList) |stmt| {
                    if (nodeHasName(tree, stmt, nameIndex)) {
                        const state = getModuleInstanceStateCached(tree, stmt, &new_ancestors, visited);
                        if (found == .Unknown or @intFromEnum(state) > @intFromEnum(found)) {
                            found = state;
                        }
                        if (found == .Instantiated) return found;
                        if (tree.getNode(stmt) == .ImportEqualsDeclaration) {
                            found = .Instantiated;
                        }
                    }
                }
            }
            if (found != .Unknown) return found;
        }
    }
    return .Instantiated;
}

pub fn getPropertyNameOrName(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .ObjectLiteralExpression => return 0,
        .ExportSpecifier => |n| return if (n.PropertyName != null and n.PropertyName.? != 0) n.PropertyName.? else n.name,
        .ImportSpecifier => |n| return if (n.PropertyName != null and n.PropertyName.? != 0) n.PropertyName.? else n.name,
        .PropertyAssignment => |n| return n.name,
        .ShorthandPropertyAssignment => |n| return n.name,
        .PropertyDeclaration => |n| return n.name,
        .MethodDeclaration => |n| return n.name,
        .GetAccessor => |n| return n.name,
        .SetAccessor => |n| return n.name,
        .EnumMember => |n| return n.name,
        .PropertySignature => |n| return n.name,
        .MethodSignature => |n| return n.name,
        .ClassDeclaration => |n| return if (n.name) |n_idx| n_idx else 0,
        .FunctionDeclaration => |n| return if (n.name) |n_idx| n_idx else 0,
        .VariableDeclaration => |n| return n.name,
        .Parameter => |n| return n.name,
        .ModuleDeclaration => |n| return n.name,
        .ImportEqualsDeclaration => |n| return n.name,
        .TypeAliasDeclaration => |n| return n.name,
        .InterfaceDeclaration => |n| return n.name,
        .EnumDeclaration => |n| return n.name,
        .TypeParameter => |n| return n.name,
        .BindingElement => |n| return if (n.PropertyName != null and n.PropertyName.? != 0) n.PropertyName.? else if (n.name) |n_idx| n_idx else 0,
        else => return 0,
    }
}

fn nodeHasName(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex, nameIndex: ast_gen.NodeIndex) bool {
    if (tree.getNode(nameIndex) == .Identifier) {
        const nodeName = getPropertyNameOrName(tree, nodeIndex);
        if (nodeName != 0 and tree.getNode(nodeName) == .Identifier) {
            const id1 = getText(tree, nameIndex);
            const id2 = getText(tree, nodeName);
            return std.mem.eql(u8, id1, id2);
        }
    }
    return false;
}

pub fn unescapeIdentifier(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    if (text.len == 0) return text;

    var hasEscape = false;
    for (text, 0..) |c, i| {
        if (c == '\\' and i + 1 < text.len and text[i + 1] == 'u') {
            hasEscape = true;
            break;
        }
    }
    if (!hasEscape) {
        return text;
    }

    var result = std.ArrayListUnmanaged(u8).empty;
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == '\\' and i + 1 < text.len and text[i + 1] == 'u') {
            i += 2;
            var codePoint: u32 = 0;
            if (i < text.len and text[i] == '{') {
                i += 1;
                while (i < text.len and text[i] != '}') {
                    const c = text[i];
                    const val: u32 = if (c >= '0' and c <= '9') c - '0' else if (c >= 'a' and c <= 'f') c - 'a' + 10 else if (c >= 'A' and c <= 'F') c - 'A' + 10 else return error.InvalidEscape;
                    codePoint = (codePoint << 4) | val;
                    i += 1;
                }
                if (i < text.len and text[i] == '}') {
                    i += 1;
                }
            } else {
                for (0..4) |_| {
                    if (i < text.len) {
                        const c = text[i];
                        const val: u32 = if (c >= '0' and c <= '9') c - '0' else if (c >= 'a' and c <= 'f') c - 'a' + 10 else if (c >= 'A' and c <= 'F') c - 'A' + 10 else return error.InvalidEscape;
                        codePoint = (codePoint << 4) | val;
                        i += 1;
                    }
                }
            }
            var buf: [4]u8 = undefined;
            const len = try std.unicode.utf8Encode(@intCast(codePoint), &buf);
            try result.appendSlice(allocator, buf[0..len]);
        } else {
            try result.append(allocator, text[i]);
            i += 1;
        }
    }
    return result.toOwnedSlice(allocator);
}

pub const SubtreeFacts = struct {
    pub const ContainsTypeScript: u32 = 1 << 0;
    pub const ContainsIdentifier: u32 = 1 << 1;
    pub const ContainsDecorators: u32 = 1 << 2;
};

pub fn getSubtreeFacts(tree: *ast.Ast, node: ast.NodeIndex) u32 {
    _ = tree;
    _ = node;
    // Bypassing fast-path optimization since we haven't implemented computing facts yet
    return SubtreeFacts.ContainsTypeScript | SubtreeFacts.ContainsIdentifier;
}

pub fn getModifierFlags(tree: *ast.Ast, node: ast_gen.NodeIndex) u32 {
    var flags: u32 = 0;
    const modifiersIndex = getModifiers(tree, node);
    if (modifiersIndex) |idx| {
        const modifiers = tree.getNodeList(idx);
        for (modifiers) |modIndex| {
            const modNode = tree.getNode(modIndex);
            switch (modNode) {
                .ExportKeyword => flags |= ModifierFlags.Export,
                .DefaultKeyword => flags |= ModifierFlags.Default,
                .DeclareKeyword => flags |= ModifierFlags.Ambient,
                .PublicKeyword => flags |= ModifierFlags.Public,
                .PrivateKeyword => flags |= ModifierFlags.Private,
                .ProtectedKeyword => flags |= ModifierFlags.Protected,
                .ReadonlyKeyword => flags |= ModifierFlags.Readonly,
                .OverrideKeyword => flags |= ModifierFlags.Override,
                .ConstKeyword => flags |= ModifierFlags.Const,
                .AbstractKeyword => flags |= ModifierFlags.Abstract,
                .StaticKeyword => flags |= ModifierFlags.Static,
                .AsyncKeyword => flags |= ModifierFlags.Async,
                .InKeyword => flags |= ModifierFlags.In,
                .OutKeyword => flags |= ModifierFlags.Out,
                .AccessorKeyword => flags |= ModifierFlags.Accessor,
                else => {},
            }
        }
    }
    return flags;
}

pub fn extractModifiers(tree: *ast.Ast, modifiersList: ast_gen.NodeIndex, mask: u32) ast_gen.NodeIndex {
    if (modifiersList == 0) return 0;
    const modifiers = tree.getNodeList(modifiersList);
    var keepCount: usize = 0;
    for (modifiers) |modIndex| {
        const modNode = tree.getNode(modIndex);
        var flag: u32 = 0;
        switch (modNode) {
            .ExportKeyword => flag = ModifierFlags.Export,
            .DefaultKeyword => flag = ModifierFlags.Default,
            .DeclareKeyword => flag = ModifierFlags.Ambient,
            .PublicKeyword => flag = ModifierFlags.Public,
            .PrivateKeyword => flag = ModifierFlags.Private,
            .ProtectedKeyword => flag = ModifierFlags.Protected,
            .ReadonlyKeyword => flag = ModifierFlags.Readonly,
            .OverrideKeyword => flag = ModifierFlags.Override,
            .ConstKeyword => flag = ModifierFlags.Const,
            .AbstractKeyword => flag = ModifierFlags.Abstract,
            .StaticKeyword => flag = ModifierFlags.Static,
            .AsyncKeyword => flag = ModifierFlags.Async,
            .InKeyword => flag = ModifierFlags.In,
            .OutKeyword => flag = ModifierFlags.Out,
            .AccessorKeyword => flag = ModifierFlags.Accessor,
            else => {},
        }
        if ((flag & mask) != 0) {
            keepCount += 1;
        }
    }
    if (keepCount == modifiers.len) return modifiersList;
    if (keepCount == 0) return 0;

    const newMods = tree.allocator.alloc(ast_gen.NodeIndex, keepCount) catch unreachable;
    var i: usize = 0;
    for (modifiers) |modIndex| {
        const modNode = tree.getNode(modIndex);
        var flag: u32 = 0;
        switch (modNode) {
            .ExportKeyword => flag = ModifierFlags.Export,
            .DefaultKeyword => flag = ModifierFlags.Default,
            .DeclareKeyword => flag = ModifierFlags.Ambient,
            .PublicKeyword => flag = ModifierFlags.Public,
            .PrivateKeyword => flag = ModifierFlags.Private,
            .ProtectedKeyword => flag = ModifierFlags.Protected,
            .ReadonlyKeyword => flag = ModifierFlags.Readonly,
            .OverrideKeyword => flag = ModifierFlags.Override,
            .ConstKeyword => flag = ModifierFlags.Const,
            .AbstractKeyword => flag = ModifierFlags.Abstract,
            .StaticKeyword => flag = ModifierFlags.Static,
            .AsyncKeyword => flag = ModifierFlags.Async,
            .InKeyword => flag = ModifierFlags.In,
            .OutKeyword => flag = ModifierFlags.Out,
            .AccessorKeyword => flag = ModifierFlags.Accessor,
            else => {},
        }
        if ((flag & mask) != 0) {
            newMods[i] = modIndex;
            i += 1;
        }
    }
    const childrenList = tree.pushNodeList(newMods) catch unreachable;
    return tree.pushNode(.{
        .SyntaxList = .{
            .Children = childrenList,
            .Flags = 0,
        },
    }) catch unreachable;
}

pub fn getParseTreeNode(tree: *ast.Ast, node: ast.NodeIndex) ast.NodeIndex {
    _ = tree;
    _ = node;
    return 0;
}

pub fn getElements(tree: *ast.Ast, node: ast.NodeIndex) []const ast.NodeIndex {
    _ = tree;
    _ = node;
    return &[_]ast.NodeIndex{};
}
fn getExpressionField(tree: *ast.Ast, node: ast.NodeIndex) ast.NodeIndex {
    const parentNode = tree.getNode(node);
    switch (parentNode) {
        .ComputedPropertyName => |n| return n.Expression,
        .Decorator => |n| return n.Expression,
        .IfStatement => |n| return n.Expression,
        .DoStatement => |n| return n.Expression,
        .WhileStatement => |n| return n.Expression,
        .WithStatement => |n| return n.Expression,
        .ReturnStatement => |n| return n.Expression orelse 0,
        .SwitchStatement => |n| return n.Expression,
        .CaseClause => |n| return n.Expression,
        .ThrowStatement => |n| return n.Expression,
        .ExpressionStatement => |n| return n.Expression,
        .ExportAssignment => |n| return n.Expression,
        .PropertyAccessExpression => |n| return n.Expression,
        .TemplateSpan => |n| return n.Expression,
        else => return 0,
    }
}

pub fn isIdentifierReference(tree: *ast.Ast, node: ast.NodeIndex, parent: ast.NodeIndex) bool {
    if (parent == 0) return false;
    const parentNode = tree.getNode(parent);
    switch (parentNode) {
        .BinaryExpression, .PrefixUnaryExpression, .PostfixUnaryExpression, .YieldExpression, .AsExpression, .SatisfiesExpression, .ElementAccessExpression, .NonNullExpression, .SpreadElement, .SpreadAssignment, .ParenthesizedExpression, .ArrayLiteralExpression, .DeleteExpression, .TypeOfExpression, .VoidExpression, .AwaitExpression, .TypeAssertionExpression, .ExpressionWithTypeArguments, .JsxSelfClosingElement, .JsxSpreadAttribute, .JsxExpression, .PartiallyEmittedExpression => {
            return true;
        },
        .ComputedPropertyName, .Decorator, .IfStatement, .DoStatement, .WhileStatement, .WithStatement, .ReturnStatement, .SwitchStatement, .CaseClause, .ThrowStatement, .ExpressionStatement, .ExportAssignment, .PropertyAccessExpression, .TemplateSpan => {
            return getExpressionField(tree, parent) == node;
        },
        .VariableDeclaration => {
            const v = parentNode.VariableDeclaration;
            return (v.Initializer orelse 0) == node;
        },
        .Parameter => {
            const p = parentNode.Parameter;
            return (p.Initializer orelse 0) == node;
        },
        .BindingElement => {
            const b = parentNode.BindingElement;
            return (b.Initializer orelse 0) == node;
        },
        .PropertyDeclaration => {
            const p = parentNode.PropertyDeclaration;
            return (p.Initializer orelse 0) == node;
        },
        .PropertySignature => {
            const p = parentNode.PropertySignature;
            return (p.Initializer orelse 0) == node;
        },
        .PropertyAssignment => {
            const p = parentNode.PropertyAssignment;
            return p.Initializer == node;
        },
        .EnumMember => {
            const e = parentNode.EnumMember;
            return (e.Initializer orelse 0) == node;
        },
        .JsxAttribute => {
            const j = parentNode.JsxAttribute;
            return (j.Initializer orelse 0) == node;
        },
        .ShorthandPropertyAssignment => {
            const s = parentNode.ShorthandPropertyAssignment;
            return (s.ObjectAssignmentInitializer orelse 0) == node;
        },
        .ForStatement => {
            const f = parentNode.ForStatement;
            return (f.Initializer orelse 0) == node or (f.Condition orelse 0) == node or (f.Incrementor orelse 0) == node;
        },
        .ForInStatement => {
            const f = parentNode.ForInStatement;
            return f.Initializer == node or f.Expression == node;
        },
        .ForOfStatement => {
            const f = parentNode.ForOfStatement;
            return f.Initializer == node or f.Expression == node;
        },
        .ImportEqualsDeclaration => {
            const i = parentNode.ImportEqualsDeclaration;
            return i.ModuleReference == node;
        },
        .ArrowFunction => {
            const a = parentNode.ArrowFunction;
            return a.Body == node;
        },
        .ConditionalExpression => {
            const c = parentNode.ConditionalExpression;
            return c.Condition == node or c.WhenTrue == node or c.WhenFalse == node;
        },
        .CallExpression => {
            const c = parentNode.CallExpression;
            if (c.Expression == node) return true;
            if (c.Arguments != 0) {
                for (tree.getNodeList(c.Arguments)) |arg| {
                    if (arg == node) return true;
                }
            }
            return false;
        },
        .NewExpression => {
            const n = parentNode.NewExpression;
            if (n.Expression == node) return true;
            if (n.Arguments != null and n.Arguments.? != 0) {
                for (tree.getNodeList(n.Arguments.?)) |arg| {
                    if (arg == node) return true;
                }
            }
            return false;
        },
        .TaggedTemplateExpression => {
            const t = parentNode.TaggedTemplateExpression;
            return t.Tag == node;
        },
        .ImportAttribute => {
            const i = parentNode.ImportAttribute;
            return i.Value == node;
        },
        .JsxOpeningElement => {
            const j = parentNode.JsxOpeningElement;
            return j.TagName == node;
        },
        .JsxClosingElement => {
            const j = parentNode.JsxClosingElement;
            return j.TagName == node;
        },
        else => return false,
    }
}
pub fn isGeneratedIdentifier(context: anytype, node: ast.NodeIndex) bool {
    _ = context;
    _ = node;
    return false;
}
pub fn isLocalName(context: anytype, node: ast.NodeIndex) bool {
    _ = context;
    _ = node;
    return false;
}
pub fn isClassLike(tree: *ast.Ast, node: ast.NodeIndex) bool {
    const k = getKind(tree, node);
    return k == .ClassDeclaration or k == .ClassExpression;
}
pub fn isIdentifier(tree: *ast.Ast, node: ast.NodeIndex) bool {
    if (node == 0) return false;
    return tree.getNode(node) == .Identifier;
}
pub fn mostOriginal(tree: *ast.Ast, node: ast.NodeIndex) ast.NodeIndex {
    _ = tree;
    return node;
}
pub fn classElementOrClassElementParameterIsDecorated(tree: *ast.Ast, legacyDecorators: bool, nodeIndex: ast.NodeIndex, containerIndex: ast.NodeIndex) bool {
    _ = legacyDecorators;
    _ = containerIndex;
    if (hasDecorators(tree, nodeIndex)) return true;
    const parameter_nodes = getParametersOfNode(tree, nodeIndex);
    for (parameter_nodes) |parameter| if (hasDecorators(tree, parameter)) return true;
    return false;
}
pub fn getText(tree: *ast.Ast, node: ast.NodeIndex) []const u8 {
    if (node == 0) return "";
    const data = tree.getNode(node);
    switch (data) {
        .Identifier => |n| return n.Text,
        .StringLiteral => |n| return n.Text,
        .NumericLiteral => |n| return n.Text,
        .PrivateIdentifier => |n| return n.Text,
        .RegularExpressionLiteral => |n| return n.Text,
        .NoSubstitutionTemplateLiteral => |n| return n.Text,
        else => {
            if (node < tree.positions.items.len) {
                const pos = tree.positions.items[node];
                if (pos.pos < pos.end and pos.end <= tree.sourceText.len) {
                    return tree.sourceText[pos.pos..pos.end];
                }
            }
            return "";
        },
    }
}

pub fn isEnumDeclaration(tree: *ast.Ast, node: ast.NodeIndex) bool {
    if (node == 0) return false;
    return tree.getNode(node) == .EnumDeclaration;
}
pub fn isBindingPattern(tree: *ast.Ast, node: ast.NodeIndex) bool {
    _ = tree;
    _ = node;
    return false;
}

pub fn isModuleDeclaration(tree: *ast.Ast, node: ast.NodeIndex) bool {
    if (node == 0) return false;
    return tree.getNode(node) == .ModuleDeclaration;
}

pub fn flattenDestructuringAssignment(a: anytype, b: anytype, c: anytype, d: anytype, e: anytype, f: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    _ = c;
    _ = d;
    _ = e;
    _ = f;
    return 0;
}
pub fn cloneNode(a: anytype, b: anytype, c: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return c;
}
pub fn hasAbstractModifier(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    return (getModifierFlags(tree, node) & ModifierFlags.Abstract) != 0;
}
pub fn hasAmbientModifier(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    return (getModifierFlags(tree, node) & ModifierFlags.Ambient) != 0;
}

pub fn nodeCanBeDecorated(tree: *ast.Ast, useLegacyDecorators: bool, node: ast_gen.NodeIndex, parent: ast_gen.NodeIndex) bool {
    const nodeKind = getKind(tree, node);
    if (useLegacyDecorators) {
        const nameNode = name(tree, node);
        if (nameNode != 0 and getKind(tree, nameNode) == .PrivateIdentifier) {
            return false;
        }
    }
    switch (nodeKind) {
        .ClassDeclaration => return true,
        .ClassExpression => return !useLegacyDecorators,
        .PropertyDeclaration => {
            if (parent == 0) return false;
            const parentKind = getKind(tree, parent);
            if (useLegacyDecorators) {
                return parentKind == .ClassDeclaration;
            } else {
                return (parentKind == .ClassDeclaration or parentKind == .ClassExpression) and
                    !hasAbstractModifier(tree, node) and !hasAmbientModifier(tree, node);
            }
        },
        .GetAccessor, .SetAccessor, .MethodDeclaration => {
            if (parent == 0) return false;
            const parentKind = getKind(tree, parent);
            const bodyNode = getBodyOfNode(tree, node);
            if (bodyNode == 0) return false;
            if (useLegacyDecorators) {
                return parentKind == .ClassDeclaration;
            } else {
                return parentKind == .ClassDeclaration or parentKind == .ClassExpression;
            }
        },
        .Parameter => {
            if (!useLegacyDecorators) return false;
            if (parent == 0) return false;
            const parentKind = getKind(tree, parent);
            const bodyNode = getBodyOfNode(tree, parent);
            if (bodyNode == 0) return false;

            const isTargetMethod = parentKind == .Constructor or parentKind == .MethodDeclaration or parentKind == .SetAccessor;
            if (!isTargetMethod) return false;

            if (isThisParameter(tree, node)) return false;

            return true;
        },
        else => return false,
    }
}

pub fn nodeIsDecorated(tree: *ast.Ast, useLegacyDecorators: bool, node: ast_gen.NodeIndex, parent: ast_gen.NodeIndex) bool {
    return hasDecorators(tree, node) and nodeCanBeDecorated(tree, useLegacyDecorators, node, parent);
}

pub fn nodeOrChildIsDecorated(tree: *ast.Ast, useLegacyDecorators: bool, node: ast_gen.NodeIndex, parent: ast_gen.NodeIndex) bool {
    return nodeIsDecorated(tree, useLegacyDecorators, node, parent) or childIsDecorated(tree, useLegacyDecorators, node, parent);
}

pub fn childIsDecorated(tree: *ast.Ast, useLegacyDecorators: bool, node: ast_gen.NodeIndex, parent: ast_gen.NodeIndex) bool {
    _ = parent;
    const nodeKind = getKind(tree, node);
    switch (nodeKind) {
        .ClassDeclaration, .ClassExpression => {
            const membersListIndex = switch (tree.getNode(node)) {
                .ClassDeclaration => |n| n.Members,
                .ClassExpression => |n| n.Members,
                else => return false,
            };
            const members_slice = tree.getNodeList(membersListIndex);
            for (members_slice) |m| {
                if (nodeOrChildIsDecorated(tree, useLegacyDecorators, m, node)) {
                    return true;
                }
            }
            return false;
        },
        .MethodDeclaration, .SetAccessor, .Constructor => {
            const paramsListIndex = switch (tree.getNode(node)) {
                .MethodDeclaration => |n| n.Parameters,
                .SetAccessor => |n| n.Parameters,
                .Constructor => |n| n.Parameters,
                else => return false,
            };
            const params_slice = tree.getNodeList(paramsListIndex);
            for (params_slice) |p| {
                if (nodeIsDecorated(tree, useLegacyDecorators, p, node)) {
                    return true;
                }
            }
            return false;
        },
        else => return false,
    }
}
pub const FlattenLevel = struct {
    pub const All: u32 = 1;
};

pub fn isDecorator(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    return tree.getNode(node) == .Decorator;
}

pub fn canHaveIllegalDecorators(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const tag = tree.getNode(node);
    switch (tag) {
        .PropertyAssignment, .ShorthandPropertyAssignment, .FunctionDeclaration, .Constructor, .IndexSignature, .ClassStaticBlockDeclaration, .MissingDeclaration, .VariableStatement, .InterfaceDeclaration, .TypeAliasDeclaration, .EnumDeclaration, .ModuleDeclaration, .ImportEqualsDeclaration, .ImportDeclaration, .JSImportDeclaration, .NamespaceExportDeclaration, .ExportDeclaration, .ExportAssignment => return true,
        else => return false,
    }
}
pub fn convertVariableDeclarationToAssignmentExpression(ctx: anytype, node: ast.NodeIndex) ast.NodeIndex {
    const tree = ctx.tree;
    const v = tree.getNode(node).VariableDeclaration;
    if (v.Initializer == 0) return 0;
    const target = v.name;
    const assignment = ctx.factory.newAssignmentExpression(target, v.Initializer.?);
    ctx.setOriginal(assignment, node) catch unreachable;
    ctx.assignCommentAndSourceMapRanges(assignment, node);
    return assignment;
}

pub fn isConstructorDeclaration(tree: *ast.Ast, node: ast.NodeIndex) bool {
    if (node == 0) return false;
    return tree.getNode(node) == .Constructor;
}

pub fn setParent(tree: *ast.Ast, node: ast.NodeIndex, parent: ast.NodeIndex) void {
    if (node != 0) {
        tree.setNodeParent(node, parent);
    }
}
pub fn withPos(range: ast.TextRange, pos: anytype) ast.TextRange {
    var new_range = range;
    new_range.pos = @bitCast(@as(i32, @intCast(pos)));
    return new_range;
}

pub fn getParent(tree: *ast.Ast, node: ast.NodeIndex) ast.NodeIndex {
    if (node == 0) return 0;
    return tree.getNodeParent(node);
}
pub fn getPos(tree: *ast.Ast, node: ast.NodeIndex) u32 {
    if (node == 0) return 0;
    return tree.getNodePos(node);
}
pub fn getTypeNode(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (nodeIndex == 0) return 0;
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .VariableDeclaration => |n| return n.Type orelse 0,
        .Parameter => |n| return n.Type orelse 0,
        .PropertySignature => |n| return n.Type orelse 0,
        .PropertyDeclaration => |n| return n.Type orelse 0,
        .PropertyAssignment => |n| return n.Type orelse 0,
        .ShorthandPropertyAssignment => |n| return n.Type,
        .TypePredicate => |n| return n.Type orelse 0,
        .ParenthesizedType => |n| return n.Type,
        .TypeOperator => |n| return n.Type,
        .MappedType => |n| return n.Type orelse 0,
        .TypeAssertionExpression => |n| return n.Type,
        .AsExpression => |n| return n.Type,
        .SatisfiesExpression => |n| return n.Type,
        .TypeAliasDeclaration => |n| return n.Type,
        .NamedTupleMember => |n| return n.Type,
        .OptionalType => |n| return n.Type,
        .RestType => |n| return n.Type,
        .TemplateLiteralTypeSpan => |n| return n.Type,
        .ExportAssignment => |n| return n.Type,
        .BinaryExpression => |n| return n.Type orelse 0,
        // Function-like:
        .FunctionDeclaration => |n| return n.Type orelse 0,
        .MethodDeclaration => |n| return n.Type orelse 0,
        .Constructor => |n| return n.Type orelse 0,
        .GetAccessor => |n| return n.Type orelse 0,
        .SetAccessor => |n| return n.Type orelse 0,
        .FunctionExpression => |n| return n.Type orelse 0,
        .ArrowFunction => |n| return n.Type orelse 0,
        else => return 0,
    }
}

pub fn setLoc(tree: *ast.Ast, node: ast.NodeIndex, range: anytype) void {
    if (node != 0) {
        const T = @TypeOf(range);
        if (T == ast.TextRange) {
            tree.setNodePosition(node, range.pos, range.end);
        } else if (T == ast.NodeIndex or T == u32) {
            if (range != 0) {
                tree.setNodePosition(node, tree.getNodePos(range), tree.getNodeEnd(range));
            }
        } else if (@typeInfo(T) == .optional) {
            if (range) |r| {
                setLoc(tree, node, r);
            }
        }
    }
}
pub fn skipTypeParentheses(tree: *ast.Ast, nodeIndex: ast.NodeIndex) ast.NodeIndex {
    var current = nodeIndex;
    while (current != 0 and tree.getNodeKind(current) == .ParenthesizedType) {
        current = getTypeNode(tree, current);
    }
    return current;
}
pub fn getMembersOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn getLoc(tree: *ast.Ast, node: ast_gen.NodeIndex) ast.TextRange {
    if (node == 0 or node >= tree.positions.items.len) return .{ .pos = 0, .end = 0 };
    return tree.positions.items[node];
}
pub fn getAssertsModifierOfTypePredicate(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}
pub fn getAllAccessorDeclarations(tree: *ast.Ast, members_slice: []const ast_gen.NodeIndex, accessor: ast_gen.NodeIndex) struct { firstAccessor: ast.NodeIndex, secondAccessor: ast.NodeIndex, getAccessor: ast.NodeIndex, setAccessor: ast.NodeIndex } {
    var getAccessor: ast_gen.NodeIndex = 0;
    var setAccessor: ast_gen.NodeIndex = 0;
    var firstAccessor: ast_gen.NodeIndex = 0;
    var secondAccessor: ast_gen.NodeIndex = 0;
    const accessor_name_node = name(tree, accessor);
    const accessor_name_text = getText(tree, accessor_name_node);
    const accessor_is_static = isStatic(tree, accessor);
    for (members_slice) |m| {
        const kind_val = getKind(tree, m);
        if (kind_val == .GetAccessor or kind_val == .SetAccessor) {
            const m_name_node = name(tree, m);
            if (std.mem.eql(u8, getText(tree, m_name_node), accessor_name_text) and isStatic(tree, m) == accessor_is_static) {
                if (kind_val == .GetAccessor) {
                    getAccessor = m;
                } else {
                    setAccessor = m;
                }
                if (firstAccessor == 0) {
                    firstAccessor = m;
                } else if (secondAccessor == 0) {
                    secondAccessor = m;
                }
            }
        }
    }
    return .{
        .firstAccessor = firstAccessor,
        .secondAccessor = secondAccessor,
        .getAccessor = getAccessor,
        .setAccessor = setAccessor,
    };
}

pub fn getLiteralOfLiteralTypeNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}
pub fn getParametersOfNode(tree: *ast.Ast, nodeIndex: ast.NodeIndex) []const ast.NodeIndex {
    if (nodeIndex == 0) return &[_]ast.NodeIndex{};
    const node = tree.nodes.get(nodeIndex);
    switch (node) {
        .FunctionDeclaration => |n| return tree.getNodeList(n.Parameters),
        .MethodDeclaration => |n| return tree.getNodeList(n.Parameters),
        .Constructor => |n| return tree.getNodeList(n.Parameters),
        .GetAccessor => |n| return tree.getNodeList(n.Parameters),
        .SetAccessor => |n| return tree.getNodeList(n.Parameters),
        .FunctionExpression => |n| return tree.getNodeList(n.Parameters),
        .ArrowFunction => |n| return tree.getNodeList(n.Parameters),
        .CallSignature => |n| return tree.getNodeList(n.Parameters),
        .ConstructSignature => |n| return tree.getNodeList(n.Parameters),
        .MethodSignature => |n| return tree.getNodeList(n.Parameters),
        .IndexSignature => |n| return tree.getNodeList(n.Parameters),
        .FunctionType => |n| return tree.getNodeList(n.Parameters),
        .ConstructorType => |n| return tree.getNodeList(n.Parameters),
        else => return &[_]ast.NodeIndex{},
    }
}

pub fn getTypesOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn getOperandOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn getTypeParametersOfNode(tree: *ast.Ast, nodeIndex: ast.NodeIndex) []const ast.NodeIndex {
    if (nodeIndex == 0) return &[_]ast.NodeIndex{};
    const node = tree.nodes.get(nodeIndex);
    switch (node) {
        .FunctionDeclaration => |n| return if (n.TypeParameters) |idx| tree.getNodeList(idx) else &[_]ast.NodeIndex{},
        .MethodDeclaration => |n| return if (n.TypeParameters) |idx| tree.getNodeList(idx) else &[_]ast.NodeIndex{},
        .FunctionExpression => |n| return if (n.TypeParameters) |idx| tree.getNodeList(idx) else &[_]ast.NodeIndex{},
        .ArrowFunction => |n| return if (n.TypeParameters) |idx| tree.getNodeList(idx) else &[_]ast.NodeIndex{},
        .CallSignature => |n| return if (n.TypeParameters) |idx| tree.getNodeList(idx) else &[_]ast.NodeIndex{},
        .ConstructSignature => |n| return if (n.TypeParameters) |idx| tree.getNodeList(idx) else &[_]ast.NodeIndex{},
        .MethodSignature => |n| return if (n.TypeParameters) |idx| tree.getNodeList(idx) else &[_]ast.NodeIndex{},
        .FunctionType => |n| return if (n.TypeParameters) |idx| tree.getNodeList(idx) else &[_]ast.NodeIndex{},
        .ConstructorType => |n| return if (n.TypeParameters) |idx| tree.getNodeList(idx) else &[_]ast.NodeIndex{},
        .ClassDeclaration => |n| return if (n.TypeParameters) |idx| tree.getNodeList(idx) else &[_]ast.NodeIndex{},
        .InterfaceDeclaration => |n| return if (n.TypeParameters) |idx| tree.getNodeList(idx) else &[_]ast.NodeIndex{},
        .TypeAliasDeclaration => |n| return if (n.TypeParameters) |idx| tree.getNodeList(idx) else &[_]ast.NodeIndex{},
        else => return &[_]ast.NodeIndex{},
    }
}
pub fn getTypeNameOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn getTrueTypeOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}
pub fn getFalseTypeOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}
pub fn getLiteralKind(a: anytype, b: anytype) std.meta.Tag(ast_gen.NodeData) {
    _ = a;
    _ = b;
    return .Unknown;
}

pub fn classOrConstructorParameterIsDecorated(tree: *ast.Ast, useLegacyDecorators: bool, node: ast_gen.NodeIndex) bool {
    if (nodeIsDecorated(tree, useLegacyDecorators, node, 0)) {
        return true;
    }
    const constructor = getFirstConstructorWithBody(tree, node);
    return constructor != 0 and childIsDecorated(tree, useLegacyDecorators, constructor, node);
}
pub fn getFirstConstructorWithBody(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ast.NodeIndex {
    const node = tree.getNode(nodeIndex);
    const membersListIndex = switch (node) {
        .ClassDeclaration => |n| n.Members,
        .ClassExpression => |n| n.Members,
        else => return 0,
    };
    const members_slice = tree.getNodeList(membersListIndex);
    for (members_slice) |member| {
        if (getKind(tree, member) == .Constructor) {
            const bodyNode = getBodyOfNode(tree, member);
            if (bodyNode != 0) {
                return member;
            }
        }
    }
    return 0;
}
pub fn getOperatorOfTypeOperator(a: anytype, b: anytype) u32 {
    _ = a;
    _ = b;
    return 0;
}

pub fn isModifier(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}

pub fn getDecoratorsOfParameters(a: anytype, b: anytype, c: anytype) ![][]const ast.NodeIndex {
    _ = a;
    _ = b;
    _ = c;
    return &.{};
}
pub fn isDeclaration(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const kind_ = tree.getKind(node);
    if (kind_ == .TypeParameter) {
        const parent = tree.getNodeParent(node);
        return parent != 0;
    }
    return isDeclarationKind(kind_);
}

pub fn isDeclarationKind(k: kind.Kind) bool {
    switch (k) {
        .ArrowFunction, .BindingElement, .ClassDeclaration, .ClassExpression, .ClassStaticBlockDeclaration, .Constructor, .EnumDeclaration, .EnumMember, .ExportSpecifier, .FunctionDeclaration, .FunctionExpression, .GetAccessor, .ImportClause, .ImportEqualsDeclaration, .ImportSpecifier, .InterfaceDeclaration, .JsxAttribute, .MethodDeclaration, .MethodSignature, .ModuleDeclaration, .NamespaceExport, .NamespaceExportDeclaration, .NamespaceImport, .Parameter, .PropertyAssignment, .PropertyDeclaration, .PropertySignature, .SetAccessor, .ShorthandPropertyAssignment, .TypeAliasDeclaration, .TypeParameter, .VariableDeclaration, .JSDocTypedefTag, .JSDocCallbackTag, .JSDocPropertyTag, .JSDocParameterTag, .JSDocSignature => return true,
        else => return false,
    }
}

pub fn findSuperStatementIndexPath(a: anytype, b: anytype) []const ast_gen.NodeIndex {
    _ = a;
    _ = b;
    return &[_]ast_gen.NodeIndex{};
}

pub const TokenFlags = struct {
    pub const None: u32 = 0;
};

pub fn nodeIsPresent(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}
pub fn isAsyncFunction(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}
pub const SyntaxKind = struct {
    pub const ReadonlyKeyword: u32 = 0;
    pub const QuestionToken: u32 = 0;
    pub const ColonToken: u32 = 0;
};

pub fn getTextOfNode(tree: *ast.Ast, node: ast.NodeIndex) []const u8 {
    return getText(tree, node);
}

pub fn subtreeFacts(a: anytype) u32 {
    _ = a;
    return 0;
}

pub fn getTypeOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn getBodyOfNode(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ast.NodeIndex {
    if (nodeIndex == 0) return 0;
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .MethodDeclaration => |n| return n.Body orelse 0,
        .Constructor => |n| return n.Body orelse 0,
        .GetAccessor => |n| return n.Body orelse 0,
        .SetAccessor => |n| return n.Body orelse 0,
        .FunctionDeclaration => |n| return n.Body orelse 0,
        .FunctionExpression => |n| return n.Body orelse 0,
        .ArrowFunction => |n| return n.Body orelse 0,
        else => return 0,
    }
}
pub fn isFunctionLikeDeclaration(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}

pub fn getTrueTypeOfConditionalType(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}
pub fn getPosOfNode(tree: *ast.Ast, node: anytype) u32 {
    const T = @TypeOf(node);
    const actual_node = if (@typeInfo(T) == .optional) (node orelse return 0) else node;
    if (actual_node == 0) return 0;
    return tree.getNodePos(actual_node);
}
pub fn getSymbolOfNode(a: anytype, b: anytype) u32 {
    _ = a;
    _ = b;
    return 0;
}
pub fn getImmediatelyInvokedFunctionExpression(a: anytype, b: anytype) u32 {
    _ = a;
    _ = b;
    return 0;
}
pub fn isTypeQueryNode(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}
pub fn findConstructorDeclaration(a: anytype, b: anytype) u32 {
    _ = a;
    _ = b;
    return 0;
}
pub fn getEndOfNode(tree: *ast.Ast, node: anytype) u32 {
    const T = @TypeOf(node);
    const actual_node = if (@typeInfo(T) == .optional) (node orelse return 0) else node;
    if (actual_node == 0) return 0;
    return tree.getNodeEnd(actual_node);
}

pub fn findAncestor(a: anytype, b: anytype, c: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    _ = c;
    return 0;
}
pub fn hasPropertyAccessExpressionWithName(a: anytype, b: anytype, c: anytype) bool {
    _ = a;
    _ = b;
    _ = c;
    return false;
}
pub fn isParameterDeclaration(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false; // Stub
}

pub fn isStatement(tree: *ast_pkg.Ast, node: ast_gen.NodeIndex) bool {
    const nodeKind = tree.getKind(node);
    return switch (nodeKind) {
        .Block, .EmptyStatement, .VariableStatement, .ExpressionStatement, .IfStatement, .DoStatement, .WhileStatement, .ForStatement, .ForInStatement, .ForOfStatement, .ContinueStatement, .BreakStatement, .ReturnStatement, .WithStatement, .SwitchStatement, .LabeledStatement, .ThrowStatement, .TryStatement, .DebuggerStatement => true,
        else => false,
    };
}

pub fn isTypeOnlyImportOrExportDeclaration(tree: *ast_gen.Tree, node: ast_gen.NodeIndex) bool {
    switch (tree.getNodeKind(node)) {
        .ImportSpecifier => {
            const specifier = tree.getImportSpecifier(node);
            if (specifier.isTypeOnly) return true;
            const parent = tree.getNodeParent(node);
            if (parent == 0) return false;
            const grandParent = tree.getNodeParent(parent);
            if (grandParent != 0 and tree.getNodeKind(grandParent) == .ImportClause) {
                return tree.getImportClause(grandParent).isTypeOnly;
            }
            return false;
        },
        .ExportSpecifier => {
            const specifier = tree.getExportSpecifier(node);
            if (specifier.isTypeOnly) return true;
            const parent = tree.getNodeParent(node);
            if (parent == 0) return false;
            const grandParent = tree.getNodeParent(parent);
            if (grandParent != 0 and tree.getNodeKind(grandParent) == .ExportDeclaration) {
                return tree.getExportDeclaration(grandParent).isTypeOnly;
            }
            return false;
        },
        .ImportClause => return tree.getImportClause(node).isTypeOnly,
        .ImportEqualsDeclaration => return tree.getImportEqualsDeclaration(node).isTypeOnly,
        .ExportDeclaration => return tree.getExportDeclaration(node).isTypeOnly,
        .NamespaceImport => {
            const parent = tree.getNodeParent(node);
            if (parent != 0 and tree.getNodeKind(parent) == .ImportClause) {
                return tree.getImportClause(parent).isTypeOnly;
            }
            return false;
        },
        else => return false,
    }
}

pub fn isPropertyAccessExpression(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    return tree.getKind(node) == .PropertyAccessExpression;
}

pub fn isAccessExpression(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const node_kind = tree.getKind(node);
    return node_kind == .PropertyAccessExpression or node_kind == .ElementAccessExpression;
}

pub fn nodeIsMissing(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return true;
    const nodeKind = tree.getKind(node);
    if (nodeKind == .MissingDeclaration) return true;
    // OmittedExpression has pos == end, but let's just check kind for now if possible.
    // In TS: node == nil || node.pos == node.end && node.pos >= 0 && node.kind != EndOfFile
    // Since Zig is AST array, usually node==0 means missing.
    // Let's implement basic for now.
    const pos = tree.getNodePos(node);
    const end = tree.getNodeEnd(node);
    return pos == end and nodeKind != .EndOfFile;
}

pub fn isTryStatement(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}
pub fn getDotDotDotTokenOfParameter(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn isVoidExpression(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}
pub fn getRestParameterElementType(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn getKind(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) std.meta.Tag(ast_gen.NodeData) {
    if (nodeIndex == 0) return .Unknown;
    return std.meta.activeTag(tree.getNode(nodeIndex));
}
pub fn isNumericLiteral(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}

pub fn isStringLiteral(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}

pub fn isTypeOfExpression(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}

pub fn getFlags(tree: *ast.Ast, node: ast_gen.NodeIndex) u32 {
    if (node == 0) return 0;
    const nodeData = tree.getNode(node);
    switch (nodeData) {
        inline else => |n| {
            const T = @TypeOf(n);
            if (@typeInfo(T) == .@"struct") {
                if (@hasField(T, "Flags")) {
                    return n.Flags;
                }
            }
            return 0;
        },
    }
}
pub fn nodeIsSynthesized(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    return (getFlags(tree, node) & NodeFlags.Synthesized) != 0;
}
pub fn isParenthesizedExpression(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}

pub fn isConditionalExpression(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}

pub fn name(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (nodeIndex == 0) return 0;
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .PropertyDeclaration => |n| return n.name,
        .MethodDeclaration => |n| return n.name,
        .GetAccessor => |n| return n.name,
        .SetAccessor => |n| return n.name,
        .ClassDeclaration => |n| return n.name orelse 0,
        .ClassExpression => |n| return n.name orelse 0,
        .FunctionDeclaration => |n| return n.name orelse 0,
        .FunctionExpression => |n| return n.name orelse 0,
        .Parameter => |n| return n.name,
        .VariableDeclaration => |n| return n.name,
        .EnumMember => |n| return n.name,
        .ModuleDeclaration => |n| return n.name,
        .PropertyAccessExpression => |n| return n.name,
        else => return 0,
    }
}
pub fn expression(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (nodeIndex == 0) return 0;
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .Decorator => |n| return n.Expression,
        .ComputedPropertyName => |n| return n.Expression,
        .PropertyAccessExpression => |n| return n.Expression,
        .ElementAccessExpression => |n| return n.Expression,
        .ExpressionStatement => |n| return n.Expression,
        .ParenthesizedExpression => |n| return n.Expression,
        .ReturnStatement => |n| return n.Expression orelse 0,
        .YieldExpression => |n| return n.Expression orelse 0,
        .AwaitExpression => |n| return n.Expression,
        .NonNullExpression => |n| return n.Expression,
        .AsExpression => |n| return n.Expression,
        .TypeAssertionExpression => |n| return n.Expression,
        .SpreadElement => |n| return n.Expression,
        .DeleteExpression => |n| return n.Expression,
        .TypeOfExpression => |n| return n.Expression,
        .VoidExpression => |n| return n.Expression,
        .ThrowStatement => |n| return n.Expression,
        else => return 0,
    }
}
pub fn getConditionOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn getWhenTrueOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn getWhenFalseOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn heritageClauses(a: anytype) ast.NodeIndex {
    _ = a;
    return 0;
}
pub fn nodesLen(tree: *ast.Ast, nodeListIndex: ast_gen.NodeIndex) u32 {
    if (nodeListIndex == 0) return 0;
    return @intCast(tree.getNodeList(nodeListIndex).len);
}

pub fn members(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (nodeIndex == 0) return 0;
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .ClassDeclaration => |n| return n.Members,
        .ClassExpression => |n| return n.Members,
        .InterfaceDeclaration => |n| return n.Members,
        .TypeLiteral => |n| return n.Members,
        .EnumDeclaration => |n| return n.Members,
        .ObjectLiteralExpression => |n| return n.Properties,
        else => return 0,
    }
}

pub fn questionDotToken(a: anytype) ast.NodeIndex {
    _ = a;
    return 0;
}
pub fn isComputedPropertyName(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    return tree.getKind(node) == .ComputedPropertyName;
}
pub fn initializer(a: anytype) ast.NodeIndex {
    _ = a;
    return 0;
}
pub fn getNodes(tree: *ast.Ast, nodeListIndex: ast_gen.NodeIndex) []const ast_gen.NodeIndex {
    if (nodeListIndex == 0) return &.{};
    return tree.getNodeList(nodeListIndex);
}
pub fn getOperatorTokenOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn getBody(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
    return getBodyOfNode(tree, nodeIndex);
}
pub fn decorators(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const modifiersIndex = getModifiers(tree, nodeIndex) orelse return 0;
    if (modifiersIndex == 0) return 0;
    const modifiers = tree.getNodeList(modifiersIndex);
    var list = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
    defer list.deinit(tree.allocator);
    for (modifiers) |modIndex| {
        if (tree.getNode(modIndex) == .Decorator) {
            list.append(tree.allocator, modIndex) catch unreachable;
        }
    }
    if (list.items.len == 0) return 0;
    return tree.pushNodeList(list.items) catch unreachable;
}
pub fn isStatic(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    return (getModifierFlags(tree, node) & ModifierFlags.Static) != 0;
}
pub fn getInitializerOfNode(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ast.NodeIndex {
    if (nodeIndex == 0) return 0;
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .PropertyDeclaration => |n| return n.Initializer orelse 0,
        .VariableDeclaration => |n| return n.Initializer orelse 0,
        .Parameter => |n| return n.Initializer orelse 0,
        .EnumMember => |n| return n.Initializer orelse 0,
        else => return 0,
    }
}
pub fn hasStaticModifier(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    return (getModifierFlags(tree, node) & ModifierFlags.Static) != 0;
}
pub fn getAsteriskTokenOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn isNullishCoalesce(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}
pub fn isOptionalChain(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    const flags = getFlags(tree, node);
    if ((flags & NodeFlags.OptionalChain) != 0) {
        switch (tree.getNode(node)) {
            .PropertyAccessExpression, .ElementAccessExpression, .CallExpression, .NonNullExpression => return true,
            else => {},
        }
    }
    return false;
}
pub fn isBindingElement(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}
pub fn getDotDotDotTokenOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}
pub fn getPropertyNameOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}
pub fn isPartOfParameterDeclaration(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}
pub fn isObjectBindingPattern(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}

pub fn isHeritageClause(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}
pub fn getTokenOfHeritageClause(a: anytype, b: anytype) kind.Kind {
    _ = a;
    _ = b;
    return .Unknown;
}
pub fn isTypeNode(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}

pub fn isInterfaceDeclaration(tree: *ast.Ast, node: ast.NodeIndex) bool {
    if (node == 0) return false;
    return tree.getKind(node) == .InterfaceDeclaration;
}

pub fn isNodeDescendantOf(tree: *ast.Ast, node_in: ast.NodeIndex, ancestor: ast.NodeIndex) bool {
    var node = node_in;
    while (node != 0) {
        if (node == ancestor) return true;
        node = tree.getNodeParent(node);
    }
    return false;
}
pub fn isClassElementKind(k: kind.Kind) bool {
    switch (k) {
        .Constructor, .PropertyDeclaration, .MethodDeclaration, .GetAccessor, .SetAccessor, .IndexSignature, .ClassStaticBlockDeclaration, .SemicolonClassElement => return true,
        else => return false,
    }
}

pub fn isClassElement(tree: *ast.Ast, node: ast.NodeIndex) bool {
    if (node == 0) return false;
    return isClassElementKind(tree.getKind(node));
}

pub fn getThisContainer(tree: *ast.Ast, node_in: ast.NodeIndex, includeArrowFunctions: bool, includeClassComputedPropertyName: bool) ast.NodeIndex {
    var node = node_in;
    while (true) {
        node = tree.getNodeParent(node);
        if (node == 0) {
            return 0; // panic("nil parent in getThisContainer")
        }
        const k = tree.getKind(node);
        switch (k) {
            .ComputedPropertyName => {
                const parent1 = tree.getNodeParent(node);
                const parent2 = if (parent1 != 0) tree.getNodeParent(parent1) else 0;
                if (includeClassComputedPropertyName and parent2 != 0 and isClassLike(tree, parent2)) {
                    return node;
                }
                node = parent2;
                // node will be reassigned at the start of loop? No, the Go code continues loop which calls `node = node.Parent`.
                // So here we need to simulate the loop continuing, wait, Go code: `node = node.Parent.Parent` then loop continues.
                // In my code, loop starts with `node = tree.getNodeParent(node)`. If I set `node = parent2`, the next loop will parent it again!
            },
            .Decorator => {
                const parent1 = tree.getNodeParent(node);
                if (parent1 != 0 and tree.getKind(parent1) == .Parameter) {
                    const parent2 = tree.getNodeParent(parent1);
                    if (parent2 != 0 and isClassElement(tree, parent2)) {
                        node = parent2;
                    }
                } else if (parent1 != 0 and isClassElement(tree, parent1)) {
                    node = parent1;
                }
            },
            .ArrowFunction => {
                if (includeArrowFunctions) return node;
            },
            .FunctionDeclaration, .FunctionExpression, .ModuleDeclaration, .ClassStaticBlockDeclaration, .PropertyDeclaration, .PropertySignature, .MethodDeclaration, .MethodSignature, .Constructor, .GetAccessor, .SetAccessor, .CallSignature, .ConstructSignature, .IndexSignature, .EnumDeclaration, .SourceFile => {
                return node;
            },
            else => {},
        }
    }
}

pub fn getCommonJSModuleIndicator(tree: *ast.Ast, node_index: ast.NodeIndex) ast.NodeIndex {
    if (node_index == 0 or tree.getNode(node_index) != .SourceFile) return 0;
    return tree.getNode(node_index).SourceFile.CommonJSModuleIndicator orelse 0;
}
pub fn isLeftHandSideExpressionKind(k: kind.Kind) bool {
    switch (k) {
        .PropertyAccessExpression, .ElementAccessExpression, .NewExpression, .CallExpression, .JsxElement, .JsxSelfClosingElement, .JsxFragment, .TaggedTemplateExpression, .ArrayLiteralExpression, .ParenthesizedExpression, .ObjectLiteralExpression, .ClassExpression, .FunctionExpression, .Identifier, .PrivateIdentifier, .RegularExpressionLiteral, .NumericLiteral, .BigIntLiteral, .StringLiteral, .NoSubstitutionTemplateLiteral, .TemplateExpression, .FalseKeyword, .NullKeyword, .ThisKeyword, .TrueKeyword, .SuperKeyword, .NonNullExpression, .ExpressionWithTypeArguments, .MetaProperty, .ImportKeyword, .MissingDeclaration => return true,
        else => return false,
    }
}

pub fn isLeftHandSideExpression(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    return isLeftHandSideExpressionKind(tree.getKind(skipPartiallyEmittedExpressions(tree, node)));
}

pub fn isAssignmentExpression(tree: *ast.Ast, node: ast_gen.NodeIndex, excludeCompoundAssignment: bool) bool {
    if (tree.getKind(node) == .BinaryExpression) {
        const bin = tree.getNode(node).BinaryExpression;
        const opKind = tree.getKind(bin.OperatorToken);
        if ((opKind == .EqualsToken or (!excludeCompoundAssignment and isAssignmentOperator(opKind))) and
            isLeftHandSideExpression(tree, bin.Left))
        {
            return true;
        }
    }
    return false;
}

pub fn isExponentiationOperator(nodeKind: kind.Kind) bool {
    return nodeKind == .AsteriskAsteriskToken;
}

pub fn isMultiplicativeOperator(nodeKind: kind.Kind) bool {
    return nodeKind == .AsteriskToken or nodeKind == .SlashToken or nodeKind == .PercentToken;
}

pub fn isMultiplicativeOperatorOrHigher(nodeKind: kind.Kind) bool {
    return isExponentiationOperator(nodeKind) or isMultiplicativeOperator(nodeKind);
}

pub fn isAdditiveOperator(nodeKind: kind.Kind) bool {
    return nodeKind == .PlusToken or nodeKind == .MinusToken;
}

pub fn isAdditiveOperatorOrHigher(nodeKind: kind.Kind) bool {
    return isAdditiveOperator(nodeKind) or isMultiplicativeOperatorOrHigher(nodeKind);
}

pub fn isShiftOperator(nodeKind: kind.Kind) bool {
    return nodeKind == .LessThanLessThanToken or nodeKind == .GreaterThanGreaterThanToken or nodeKind == .GreaterThanGreaterThanGreaterThanToken;
}

pub fn isShiftOperatorOrHigher(nodeKind: kind.Kind) bool {
    return isShiftOperator(nodeKind) or isAdditiveOperatorOrHigher(nodeKind);
}

pub fn isEqualityOperator(nodeKind: kind.Kind) bool {
    return nodeKind == .EqualsEqualsToken or nodeKind == .EqualsEqualsEqualsToken or nodeKind == .ExclamationEqualsToken or nodeKind == .ExclamationEqualsEqualsToken;
}

pub fn isCompoundLikeAssignment(tree: *ast.Ast, assignment: ast_gen.NodeIndex) bool {
    const right = skipParentheses(tree, tree.getNode(assignment).BinaryExpression.Right);
    if (tree.getKind(right) == .BinaryExpression) {
        const op = tree.getNode(right).BinaryExpression.OperatorToken;
        return isShiftOperatorOrHigher(tree.getKind(op));
    }
    return false;
}

pub fn isInCompoundLikeAssignment(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const target = getAssignmentTarget(tree, node);
    if (target != 0) {
        if (isAssignmentExpression(tree, target, true)) {
            return isCompoundLikeAssignment(tree, target);
        }
    }
    return false;
}
pub fn getDeclarationOfKind(a: anytype, b: anytype, c: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    _ = c;
    return 0;
}
pub fn getLocalSymbolOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn getTypeParameterOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}
pub fn getLeftOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn parameters(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .MethodDeclaration => |n| return n.Parameters,
        .GetAccessor => |n| return n.Parameters,
        .SetAccessor => |n| return n.Parameters,
        .Constructor => |n| return n.Parameters,
        .FunctionDeclaration => |n| return n.Parameters,
        .FunctionExpression => |n| return n.Parameters,
        .ArrowFunction => |n| return n.Parameters,
        else => return 0,
    }
}
pub fn isPropertyDeclaration(a: anytype) bool {
    _ = a;
    return false;
}
pub fn isPrivateIdentifier(a: anytype) bool {
    _ = a;
    return false;
}
pub fn canHaveDecorators(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const nodeKind = getKind(tree, nodeIndex);
    switch (nodeKind) {
        .ClassDeclaration, .ClassExpression, .PropertyDeclaration, .MethodDeclaration, .GetAccessor, .SetAccessor, .Parameter => return true,
        else => return false,
    }
}

pub fn getRightOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn loc(a: anytype) ast.NodeIndex {
    _ = a;
    return 0;
}
pub fn hasAccessorModifier(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    return (getModifierFlags(tree, node) & ModifierFlags.Accessor) != 0;
}
pub fn isSimpleInlineableExpression(a: anytype) bool {
    _ = a;
    return false;
}
pub fn some(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}

pub fn moveRangePastModifiers(a: anytype) ast.NodeIndex {
    _ = a;
    return 0;
}

pub fn dotDotDotToken(a: anytype) ast.NodeIndex {
    _ = a;
    return 0;
}
pub fn asteriskToken(a: anytype) ast.NodeIndex {
    _ = a;
    return 0;
}

fn ForEachChildBoolVisitor(comptime ContextType: type) type {
    return struct {
        tree: *ast.Ast,
        context: ContextType,
        check: *const fn (ContextType, ast_gen.NodeIndex) bool,

        pub fn visitNode(self: *@This(), n: ast_gen.NodeIndex) anyerror!void {
            if (n == 0) return;
            if (self.check(self.context, n)) {
                return error.Found;
            }
            try for_each.forEachChild(self.tree, n, self);
        }

        pub fn visitList(self: *@This(), listIndex: ast_gen.NodeIndex) anyerror!void {
            if (listIndex == 0) return;
            const nodes = self.tree.getNodeList(listIndex);
            for (nodes) |n| {
                try self.visitNode(n);
            }
        }
    };
}

pub fn forEachChildBool(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex, context: anytype, check: anytype) bool {
    const ContextType = @TypeOf(context);
    var visitor = ForEachChildBoolVisitor(ContextType){
        .tree = tree,
        .context = context,
        .check = check,
    };

    for_each.forEachChild(tree, nodeIndex, &visitor) catch |err| {
        if (err == error.Found) return true;
        return false;
    };
    return false;
}

pub fn isThisInTypeQuery(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    if (!isThisIdentifier(tree, nodeIndex)) return false;
    var node = nodeIndex;
    var parent = tree.getNodeParent(node);
    while (parent != 0 and tree.getKind(parent) == .QualifiedName and tree.getNode(parent).QualifiedName.Left == node) {
        node = parent;
        parent = tree.getNodeParent(node);
    }
    return parent != 0 and tree.getKind(parent) == .TypeQuery;
}

pub fn skipPartiallyEmittedExpressions(tree: *ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    var current = node;
    while (tree.getKind(current) == .PartiallyEmittedExpression) {
        current = tree.getNode(current).PartiallyEmittedExpression.Expression;
    }
    return current;
}
pub fn getModuleSpecifierOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}
pub fn isRequireCall(tree: anytype, node: ast_gen.NodeIndex, requireStringLiteralLikeArgument: bool) bool {
    if (tree.getKind(node) != .CallExpression) return false;
    const callExpr = tree.getNode(node).CallExpression;
    const expr = callExpr.Expression;
    if (expr == 0) return false;
    if (tree.getKind(expr) != .Identifier) return false;
    if (!std.mem.eql(u8, getText(tree, expr), "require")) return false;

    const args = tree.getNodeList(callExpr.Arguments);
    if (args.len != 1) return false;

    if (!requireStringLiteralLikeArgument) return true;
    const argKind = tree.getKind(args[0]);
    return argKind == .StringLiteral or argKind == .NoSubstitutionTemplateLiteral;
}

pub fn isSourceFile(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}

pub fn getNodeFlags(a: anytype, b: anytype) u32 {
    _ = a;
    _ = b;
    return 0;
}
pub fn getAssignmentTarget(tree: *ast.Ast, start_node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    var node = start_node;
    while (true) {
        const parent = tree.getNodeParent(node);
        if (parent == 0) return 0;
        const node_kind = tree.getKind(parent);
        switch (node_kind) {
            .BinaryExpression => {
                const bin = tree.getNode(parent).BinaryExpression;
                const opKind = tree.getKind(bin.OperatorToken);
                if (isAssignmentOperator(opKind) and bin.Left == node) {
                    return parent;
                }
                return 0;
            },
            .PrefixUnaryExpression => {
                const un = tree.getNode(parent).PrefixUnaryExpression;
                if (un.Operator == @intFromEnum(kind.Kind.PlusPlusToken) or un.Operator == @intFromEnum(kind.Kind.MinusMinusToken)) {
                    return parent;
                }
                return 0;
            },
            .PostfixUnaryExpression => {
                const un = tree.getNode(parent).PostfixUnaryExpression;
                if (un.Operator == @intFromEnum(kind.Kind.PlusPlusToken) or un.Operator == @intFromEnum(kind.Kind.MinusMinusToken)) {
                    return parent;
                }
                return 0;
            },
            .ForOfStatement => {
                const forInOrOf = tree.getNode(parent).ForOfStatement;
                if (forInOrOf.Initializer == node) {
                    return parent;
                }
                return 0;
            },
            .ForInStatement => {
                const forInOrOf = tree.getNode(parent).ForInStatement;
                if (forInOrOf.Initializer == node) {
                    return parent;
                }
                return 0;
            },
            .ParenthesizedExpression, .ArrayLiteralExpression, .SpreadElement, .NonNullExpression => {
                node = parent;
            },
            .SpreadAssignment => {
                node = tree.getNodeParent(parent);
            },
            .ShorthandPropertyAssignment => {
                if (tree.getNode(parent).ShorthandPropertyAssignment.name != node) return 0;
                node = tree.getNodeParent(parent);
            },
            .PropertyAssignment => {
                if (tree.getNode(parent).PropertyAssignment.name == node) return 0;
                node = tree.getNodeParent(parent);
            },
            else => return 0,
        }
    }
}
pub fn isAssignmentOperator(op: kind.Kind) bool {
    return @intFromEnum(op) >= @intFromEnum(kind.Kind.EqualsToken) and @intFromEnum(op) <= @intFromEnum(kind.Kind.CaretEqualsToken);
}

pub fn isDeclarationStatement(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    _ = a;
    _ = nodeIndex;
    return false; // stub
}

pub fn isVariableStatement(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    _ = a;
    _ = nodeIndex;
    return false; // stub
}

const for_each = @import("for_each_child.zig");
pub const forEachChild = for_each.forEachChild;

pub fn getFirstToken(nodeIndex: ast_gen.NodeIndex, tree: *ast.Ast) ast_gen.NodeIndex {
    if (nodeIndex == 0) return 0;
    const nodeTag = std.meta.activeTag(tree.getNode(nodeIndex));
    if (nodeTag == .Identifier or kind.isTokenKind(@enumFromInt(@intFromEnum(nodeTag)))) {
        return 0;
    }

    const Closure = struct {
        firstChild: ast_gen.NodeIndex = 0,
        tree: *ast.Ast,
        pub fn visitNode(ctx: *@This(), n: ast_gen.NodeIndex) anyerror!void {
            if (n != 0) {
                ctx.firstChild = n;
                return error.Stop;
            }
        }
        pub fn visitList(ctx: *@This(), list: u32) anyerror!void {
            if (list == 0) return;
            const nodes = ctx.tree.getNodeList(list);
            if (nodes.len > 0) {
                return ctx.visitNode(nodes[0]);
            }
        }
    };
    var closure = Closure{ .tree = tree };
    _ = for_each.forEachChild(tree, nodeIndex, &closure) catch {};

    if (closure.firstChild == 0) return 0;

    const firstChildTag = std.meta.activeTag(tree.getNode(closure.firstChild));
    if (kind.isTokenKind(@enumFromInt(@intFromEnum(firstChildTag)))) {
        return closure.firstChild;
    }
    return getFirstToken(closure.firstChild, tree);
}

pub fn isLogicalOrCoalescingBinaryOperator(op: kind.Kind) bool {
    return op == .AmpersandAmpersandToken or op == .BarBarToken or op == .QuestionQuestionToken;
}

pub fn isLogicalBinaryOperator(op: kind.Kind) bool {
    return op == .AmpersandAmpersandToken or op == .BarBarToken;
}

pub fn isLogicalOrCoalescingAssignmentOperator(op: kind.Kind) bool {
    return op == .AmpersandAmpersandEqualsToken or op == .BarBarEqualsToken or op == .QuestionQuestionEqualsToken;
}

pub fn isLogicalExpression(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    if (node == .BinaryExpression) {
        const op = tree.getKind(node.BinaryExpression.OperatorToken);
        return isLogicalOrCoalescingBinaryOperator(op);
    }
    return false;
}

pub fn isLogicalOrCoalescingAssignmentExpression(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    if (node == .BinaryExpression) {
        const bin = node.BinaryExpression;
        const op = tree.getKind(bin.OperatorToken);
        if (isLogicalOrCoalescingAssignmentOperator(op)) {
            return true;
        }
    }
    return false;
}

pub fn isStringLiteralLike(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    return node == .StringLiteral or node == .NoSubstitutionTemplateLiteral;
}

pub fn isBooleanLiteral(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    return node == .TrueKeyword or node == .FalseKeyword;
}

pub fn isLocalsContainer(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .SourceFile, .Block, .ModuleBlock, .CatchClause, .ForStatement, .ForInStatement, .ForOfStatement, .WithStatement, .ClassDeclaration, .ClassExpression, .FunctionDeclaration, .FunctionExpression, .ArrowFunction, .MethodDeclaration, .MethodSignature, .GetAccessor, .SetAccessor, .Constructor, .TypeAliasDeclaration, .InterfaceDeclaration, .EnumDeclaration, .ModuleDeclaration, .MappedType, .JsxElement, .JsxFragment => return true,
        else => return false,
    }
}

pub fn skipParentheses(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
    var current = nodeIndex;
    while (current != 0 and tree.getNode(current) == .ParenthesizedExpression) {
        current = tree.getNode(current).ParenthesizedExpression.Expression;
    }
    return current;
}

pub fn isDestructuringAssignment(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    if (node == .BinaryExpression) {
        const bin = node.BinaryExpression;
        if (tree.getNode(bin.OperatorToken) == .EqualsToken) {
            const left = skipParentheses(tree, bin.Left);
            const leftNode = tree.getNode(left);
            return leftNode == .ObjectLiteralExpression or leftNode == .ArrayLiteralExpression;
        }
    }
    return false;
}

pub fn isAssignmentTarget(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    return getAssignmentTarget(tree, nodeIndex) != 0;
}

pub fn getExpressionOfNode(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
    switch (tree.getNode(nodeIndex)) {
        .PropertyAccessExpression => |n| return n.Expression,
        .ElementAccessExpression => |n| return n.Expression,
        .CallExpression => |n| return n.Expression,
        .NonNullExpression => |n| return n.Expression,
        .ParenthesizedExpression => |n| return n.Expression,
        else => return 0,
    }
}

pub fn isEntityNameExpression(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    return node == .Identifier or (node == .PropertyAccessExpression and isEntityNameExpression(tree, node.PropertyAccessExpression.Expression));
}

pub fn isOutermostOptionalChain(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const parent = tree.getNodeParent(nodeIndex);
    return !isOptionalChain(tree, parent); // Need real implementation later
}

pub fn isExpressionOfOptionalChainRoot(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const parent = tree.getNodeParent(nodeIndex);
    return isOptionalChainRoot(tree, parent) and getExpressionOfNode(tree, parent) == nodeIndex;
}

pub fn isOptionalChainRoot(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    // Need real implementation later
    _ = tree;
    _ = nodeIndex;
    return false;
}

pub fn isPartOfTypeQuery(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    var current = nodeIndex;
    while (current != 0) {
        const nodeKind = a.getNode(current);
        if (nodeKind != .QualifiedName and nodeKind != .Identifier) break;
        current = a.getNodeParent(current);
    }
    return current != 0 and a.getNode(current) == .TypeQuery;
}

const ParentFixer = struct {
    tree: *ast.Ast,
    parent: ast.NodeIndex,

    pub fn visitNode(self: *ParentFixer, node: ast.NodeIndex) anyerror!void {
        if (node == 0) return;
        self.tree.setNodeParent(node, self.parent);
        var fixer = ParentFixer{
            .tree = self.tree,
            .parent = node,
        };
        try for_each.forEachChild(self.tree, node, &fixer);
    }

    pub fn visitList(self: *ParentFixer, list: u32) anyerror!void {
        if (list == 0) return;
        const nodes = self.tree.getNodeList(list);
        for (nodes) |child| {
            try self.visitNode(child);
        }
    }
};

pub fn fixupParentReferences(tree: *ast.Ast, root: ast.NodeIndex) anyerror!void {
    if (root == 0) return;
    var fixer = ParentFixer{
        .tree = tree,
        .parent = tree.getNodeParent(root),
    };
    try for_each.forEachChild(tree, root, &fixer);
}

pub const AccessKind = enum {
    Read,
    Write,
    ReadWrite,
};

fn reverseAccessKind(ak: AccessKind) AccessKind {
    switch (ak) {
        .Read => return .Write,
        .Write => return .Read,
        .ReadWrite => return .ReadWrite,
    }
}

pub fn accessKind(tree: *ast.Ast, start_node: ast_gen.NodeIndex) AccessKind {
    const parent = tree.getNodeParent(start_node);
    if (parent == 0) return .Read;

    const parentNode = tree.getNode(parent);
    switch (tree.getKind(parent)) {
        .ParenthesizedExpression => return accessKind(tree, parent),
        .PrefixUnaryExpression => {
            const op = parentNode.PrefixUnaryExpression.Operator;
            if (op == @intFromEnum(kind.Kind.PlusPlusToken) or op == @intFromEnum(kind.Kind.MinusMinusToken)) {
                return .ReadWrite;
            }
            return .Read;
        },
        .PostfixUnaryExpression => {
            const op = parentNode.PostfixUnaryExpression.Operator;
            if (op == @intFromEnum(kind.Kind.PlusPlusToken) or op == @intFromEnum(kind.Kind.MinusMinusToken)) {
                return .ReadWrite;
            }
            return .Read;
        },
        .BinaryExpression => {
            const bin = parentNode.BinaryExpression;
            if (bin.Left == start_node) {
                const op = tree.getKind(bin.OperatorToken);
                if (isAssignmentOperator(op)) {
                    if (op == .EqualsToken) {
                        return .Write;
                    }
                    return .ReadWrite;
                }
            }
            return .Read;
        },
        .PropertyAccessExpression => {
            if (parentNode.PropertyAccessExpression.name != start_node) {
                return .Read;
            }
            return accessKind(tree, parent);
        },
        .PropertyAssignment => {
            const parentAccess = accessKind(tree, tree.getNodeParent(parent));
            if (start_node == parentNode.PropertyAssignment.name) {
                return reverseAccessKind(parentAccess);
            }
            return parentAccess;
        },
        .ShorthandPropertyAssignment => {
            if (start_node == parentNode.ShorthandPropertyAssignment.ObjectAssignmentInitializer) {
                return .Read;
            }
            return accessKind(tree, tree.getNodeParent(parent));
        },
        .ArrayLiteralExpression => return accessKind(tree, parent),
        .ForOfStatement => {
            if (start_node == parentNode.ForOfStatement.Initializer) return .Write;
            return .Read;
        },
        .ForInStatement => {
            if (start_node == parentNode.ForInStatement.Initializer) return .Write;
            return .Read;
        },
        else => return .Read,
    }
}

pub fn isWriteOnlyAccess(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    return accessKind(tree, node) == .Write;
}

pub fn isWriteAccess(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    return accessKind(tree, node) != .Read;
}

pub fn hasContextSensitiveParameters(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (getTypeParametersOfNode(tree, node).len == 0) {
        const params = getParametersOfNode(tree, node);
        for (params) |p| {
            if (getTypeOfNode(tree, p) == 0) return true;
        }
        if (!isArrowFunction(tree, node)) {
            if (params.len > 0 and isThisParameter(tree, params[0])) {
                // explicit this param, not context sensitive via this
            } else {
                return (tree.getNodeFlags(node) & NodeFlags.ContainsThis) != 0;
            }
        }
    }
    return false;
}

const ReturnStatementVisitor = struct {
    visitor: *const fn (node: ast_gen.NodeIndex, context: ?*anyopaque) bool,
    context: ?*anyopaque,
    tree: *ast.Ast,

    pub fn visit(self: *ReturnStatementVisitor, node: ast_gen.NodeIndex) bool {
        const node_kind = self.tree.getKind(node);
        if (node_kind == .ReturnStatement) {
            return self.visitor(node, self.context);
        }
        switch (node_kind) {
            .CaseBlock, .Block, .IfStatement, .DoStatement, .WhileStatement, .ForStatement, .ForInStatement, .ForOfStatement, .WithStatement, .SwitchStatement, .CaseClause, .DefaultClause, .LabeledStatement, .TryStatement, .CatchClause => {
                return forEachChildBool(self.tree, node, self, visit);
            },
            else => return false,
        }
    }
};

pub fn forEachReturnStatement(tree: *ast.Ast, body: ast_gen.NodeIndex, visitor: *const fn (node: ast_gen.NodeIndex, context: ?*anyopaque) bool, context: ?*anyopaque) bool {
    var v = ReturnStatementVisitor{ .visitor = visitor, .context = context, .tree = tree };
    return v.visit(body);
}

pub fn isArrowFunction(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    return tree.getKind(node) == .ArrowFunction;
}

pub fn isWriteAccessForReference(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const decl = getDeclarationFromName(tree, node);
    if (decl != 0 and declarationIsWriteAccess(tree, decl)) {
        return true;
    }
    return tree.getKind(node) == .DefaultKeyword or isWriteAccess(tree, node);
}

pub fn getDeclarationFromName(tree: *ast.Ast, name_node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (name_node == 0) return 0;
    const parent = tree.getNodeParent(name_node);
    if (parent == 0) return 0;

    const kind_ = tree.getKind(name_node);
    if (kind_ == .StringLiteral or kind_ == .NoSubstitutionTemplateLiteral or kind_ == .NumericLiteral) {
        if (isComputedPropertyName(tree, parent)) {
            return tree.getNodeParent(parent);
        }
        return getDeclarationFromNameForIdentifier(tree, name_node, parent);
    } else if (kind_ == .Identifier) {
        return getDeclarationFromNameForIdentifier(tree, name_node, parent);
    } else if (kind_ == .PrivateIdentifier) {
        if (isDeclaration(tree, parent) and getNameOfNode(tree, parent) == name_node) {
            return parent;
        }
    }
    return 0;
}

fn getDeclarationFromNameForIdentifier(tree: *ast.Ast, name_node: ast_gen.NodeIndex, parent: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (isDeclaration(tree, parent)) {
        if (getNameOfNode(tree, parent) == name_node) {
            return parent;
        }
        return 0;
    }
    if (tree.getKind(parent) == .QualifiedName) {
        const tag = tree.getNodeParent(parent);
        if (tree.getKind(tag) == .JSDocParameterTag and getNameOfNode(tree, tag) == parent) {
            return tag;
        }
        return 0;
    }
    const binExp = tree.getNodeParent(parent);
    if (binExp != 0 and tree.getKind(binExp) == .BinaryExpression and getAssignmentDeclarationKind(tree, binExp) != .None) {
        const binNode = tree.getNode(binExp).BinaryExpression;
        var leftHasSymbol = false;
        if (binNode.Left != 0 and tree.getNodeSymbol(binNode.Left) != null) {
            leftHasSymbol = true;
        }
        if (leftHasSymbol or tree.getNodeSymbol(binExp) != null) {
            const declName = if (tree.getKind(binNode.Left) == .PropertyAccessExpression)
                tree.getNode(binNode.Left).PropertyAccessExpression.name
            else
                binNode.Left;
            if (declName == name_node) {
                return binExp;
            }
        }
    }
    return 0;
}

pub fn declarationIsWriteAccess(tree: *ast.Ast, decl: ast_gen.NodeIndex) bool {
    if (decl == 0) return false;

    const flags = tree.getNodeFlags(decl);
    if ((flags & @intFromEnum(ast.NodeFlags.Ambient)) != 0) return true;

    switch (tree.getKind(decl)) {
        .BinaryExpression, .BindingElement, .ClassDeclaration, .ClassExpression, .DefaultKeyword, .EnumDeclaration, .EnumMember, .ExportSpecifier, .ImportClause, .ImportEqualsDeclaration, .ImportSpecifier, .InterfaceDeclaration, .JSDocCallbackTag, .JSDocTypedefTag, .JsxAttribute, .ModuleDeclaration, .NamespaceExportDeclaration, .NamespaceImport, .NamespaceExport, .Parameter, .ShorthandPropertyAssignment, .TypeAliasDeclaration, .TypeParameter => return true,

        .PropertyAssignment => {
            return !isArrayLiteralOrObjectLiteralDestructuringPattern(tree, tree.getNodeParent(decl));
        },

        .FunctionDeclaration => return tree.getNode(decl).FunctionDeclaration.body != 0,
        .FunctionExpression => return tree.getNode(decl).FunctionExpression.body != 0,
        .Constructor => return tree.getNode(decl).Constructor.body != 0,
        .MethodDeclaration => return tree.getNode(decl).MethodDeclaration.body != 0,
        .GetAccessor => return tree.getNode(decl).GetAccessor.body != 0,
        .SetAccessor => return tree.getNode(decl).SetAccessor.body != 0,

        .VariableDeclaration => {
            const hasInit = tree.getNode(decl).VariableDeclaration.initializer != 0;
            return hasInit or tree.getKind(tree.getNodeParent(decl)) == .CatchClause;
        },
        .PropertyDeclaration => {
            const hasInit = tree.getNode(decl).PropertyDeclaration.initializer != 0;
            return hasInit or tree.getKind(tree.getNodeParent(decl)) == .CatchClause;
        },

        .MethodSignature, .PropertySignature, .JSDocPropertyTag, .JSDocParameterTag => return false,

        else => @panic("Unhandled case in declarationIsWriteAccess"),
    }
}

pub fn isArrayLiteralOrObjectLiteralDestructuringPattern(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const start_kind = tree.getKind(node);
    if (start_kind != .ArrayLiteralExpression and start_kind != .ObjectLiteralExpression) {
        return false;
    }

    var current = node;
    while (current != 0) {
        const parent = tree.getNodeParent(current);
        if (parent == 0) return false;
        const parentKind = tree.getKind(parent);

        if (parentKind == .BinaryExpression) {
            const bin = tree.getNode(parent).BinaryExpression;
            if (bin.Left == current and tree.getKind(bin.OperatorToken) == .EqualsToken) return true;
        }
        if (parentKind == .ForOfStatement) {
            const forOf = tree.getNode(parent).ForOfStatement;
            if (forOf.Initializer == current) return true;
        }
        if (parentKind == .PropertyAssignment) {
            current = tree.getNodeParent(parent);
            continue;
        }
        if (parentKind == .ArrayLiteralExpression or parentKind == .ObjectLiteralExpression) {
            current = parent;
            continue;
        }
        return false;
    }
    return false;
}

pub fn isImportCall(tree: *ast_pkg.Ast, node: ast_gen.NodeIndex) bool {
    if (tree.getNodeKind(node) == .CallExpression) {
        const expr = tree.getNode(node).CallExpression.Expression;
        return tree.getNodeKind(expr) == .ImportKeyword;
    }
    return false;
}

pub fn getContainingClass(tree: *ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    return findAncestor(tree, getParent(tree, node), isClassLike);
}
