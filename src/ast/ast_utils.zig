const std = @import("std");
const ast = @import("ast.zig");
const ast_gen = @import("ast_generated.zig");
const kind = @import("kind.zig");
const ast_pkg = @import("ast.zig");

pub fn isTypeOnly(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .ImportEqualsDeclaration => |n| return n.IsTypeOnly,
        .ExportDeclaration => |n| return n.IsTypeOnly,
        .ImportSpecifier => |n| return n.IsTypeOnly,
        .ExportSpecifier => |n| return n.IsTypeOnly,
        .ImportClause => |n| return n.IsTypeOnly,
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

pub const OEKAllExceptAssertionsOrExpressionsWithTypeArguments = 1;

pub fn isJSDocTypeAssertion(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    _ = a;
    _ = nodeIndex;
    return false;
}

pub fn skipOuterExpressions(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex, flags: u32) ast_gen.NodeIndex {
    _ = a;
    _ = flags;
    return nodeIndex;
}

pub fn isEnumConst(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    _ = a;
    _ = nodeIndex;
    return false;
}

pub fn isBinaryExpression(nodeData: ast_gen.NodeData) bool {
    _ = nodeData;
    return false;
}

pub fn getSourceFileOfNode(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
    var curr = nodeIndex;
    while (curr != 0) {
        if (tree.getNode(curr) == .SourceFile) return curr;
        curr = tree.getNodeParent(curr);
    }
    return 0;
}

pub fn isNonLocalAlias(tree: *ast_pkg.Ast, symIndex: ast_gen.SymbolIndex, excludes: u32) bool {
    const sym = tree.symbols.items[symIndex];
    return (sym.Flags & (@import("symbol.zig").SymbolFlags.Alias | excludes)) == @import("symbol.zig").SymbolFlags.Alias;
}

pub fn getName(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .ModuleDeclaration => |n| return n.name,
        .EnumDeclaration => |n| return n.name,
        else => return 0,
    }
}

pub fn isAliasSymbolDeclaration(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .ImportEqualsDeclaration, .NamespaceExportDeclaration, .NamespaceImport, .NamespaceExport, .ImportSpecifier, .ExportSpecifier => return true,
        .ImportClause => |n| return n.name != 0,
        .ExportAssignment => return false, // TODO: expressionIsAlias
        .VariableDeclaration, .BindingElement => return false, // TODO: isVariableDeclarationInitializedToRequire
        else => return false,
    }
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
    return (a.getNodeFlags(nodeIndex) & NodeFlags.JavaScriptFile) != 0;
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

pub fn hasDecorators(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    _ = a;
    _ = nodeIndex;
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

        if (root != 0 and std.meta.activeTag(astTree.getNode(root)) == .VariableStatement) {
            flags |= astTree.getNodeFlags(root);
        }
    }
    return flags;
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
        else => return 0,
    }
}

pub fn isGlobalSourceFile(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = a.getNode(nodeIndex);
    return node == .SourceFile and !isExternalModule(a, nodeIndex);
}

pub fn isFunctionLike(tag: std.meta.Tag(@import("ast_generated.zig").NodeData)) bool {
    switch (tag) {
        .FunctionDeclaration, .MethodDeclaration, .GetAccessor, .SetAccessor, .Constructor, .FunctionExpression, .ArrowFunction => return true,
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
    Instantiated,
    ConstEnumOnly,
    Unknown,
};

pub fn getModuleInstanceState(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ModuleInstanceState {
    const node = tree.getNode(nodeIndex);
    if (node != .ModuleDeclaration) return .Instantiated;
    const body = tree.getNode(nodeIndex).ModuleDeclaration.Body;
    if (body) |b| {
        return getModuleInstanceStateCached(tree, b);
    }
    return .Instantiated;
}

fn getModuleInstanceStateCached(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ModuleInstanceState {
    // Basic implementation that avoids caching/recursion limit for now
    return getModuleInstanceStateWorker(tree, nodeIndex);
}

fn getModuleInstanceStateWorker(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ModuleInstanceState {
    const node = tree.getNode(nodeIndex);
    switch (node) {
        .InterfaceDeclaration, .TypeAliasDeclaration, .JSTypeAliasDeclaration => return .NonInstantiated,
        .EnumDeclaration => {
            if (hasSyntacticModifier(tree, nodeIndex, ModifierFlags.Const)) return .ConstEnumOnly;
            return .Instantiated;
        },
        .ImportDeclaration, .JSImportDeclaration, .ImportEqualsDeclaration => {
            if (!hasSyntacticModifier(tree, nodeIndex, ModifierFlags.Export)) return .NonInstantiated;
            return .Instantiated;
        },
        .ExportDeclaration => {
            // Simplified for now
            return .Instantiated;
        },
        .ModuleBlock => {
            var state: ModuleInstanceState = .NonInstantiated;
            const block = tree.getNode(nodeIndex).ModuleBlock;
            for (tree.getNodeList(block.Statements)) |stmt| {
                const childState = getModuleInstanceStateCached(tree, stmt);
                if (childState == .Instantiated) return .Instantiated;
                if (childState == .ConstEnumOnly) state = .ConstEnumOnly;
            }
            return state;
        },
        .ModuleDeclaration => return getModuleInstanceState(tree, nodeIndex),
        else => return .Instantiated,
    }
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
    return 0;
}

pub fn getModifierFlags(tree: *ast.Ast, node: ast.NodeIndex) u32 {
    _ = tree;
    _ = node;
    return 0;
}

pub fn extractModifiers(context: anytype, modifiers: ast.NodeIndex, mask: u32) ast.NodeIndex {
    _ = context;
    _ = mask;
    return modifiers;
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
pub fn isIdentifierReference(tree: *ast.Ast, node: ast.NodeIndex, parent: ast.NodeIndex) bool {
    _ = tree;
    _ = node;
    _ = parent;
    return false;
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
    _ = tree;
    _ = node;
    return false;
}
pub fn isIdentifier(tree: *ast.Ast, node: ast.NodeIndex) bool {
    _ = tree;
    _ = node;
    return false;
}
pub fn mostOriginal(tree: *ast.Ast, node: ast.NodeIndex) ast.NodeIndex {
    _ = tree;
    return node;
}
pub fn classElementOrClassElementParameterIsDecorated(tree: *ast.Ast, legacyDecorators: bool, nodeIndex: ast.NodeIndex, containerIndex: ast.NodeIndex) bool {
    _ = tree;
    _ = legacyDecorators;
    _ = nodeIndex;
    _ = containerIndex;
    return false;
}
pub fn getText(tree: *ast.Ast, node: ast.NodeIndex) []const u8 {
    _ = tree;
    _ = node;
    return "";
}

pub fn isEnumDeclaration(tree: *ast.Ast, node: ast.NodeIndex) bool {
    _ = tree;
    _ = node;
    return false;
}
pub fn isBindingPattern(tree: *ast.Ast, node: ast.NodeIndex) bool {
    _ = tree;
    _ = node;
    return false;
}

pub fn isModuleDeclaration(tree: *ast.Ast, node: ast.NodeIndex) bool {
    _ = tree;
    _ = node;
    return false;
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
pub fn childIsDecorated(a: anytype, b: anytype, c: anytype) bool {
    _ = a;
    _ = b;
    _ = c;
    return false;
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
    _ = ctx;
    _ = node;
    return 0;
}

pub fn isConstructorDeclaration(tree: *ast.Ast, node: ast.NodeIndex) bool {
    _ = tree;
    _ = node;
    return false;
}

pub fn setParent(a: anytype, b: anytype, c: anytype) void {
    _ = a;
    _ = b;
    _ = c;
}
pub fn withPos(a: anytype, b: anytype) ast.TextRange {
    _ = a;
    _ = b;
    return ast.TextRange{ .pos = 0, .end = 0 };
}

pub fn getParent(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}
pub fn getPos(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}
pub fn getTypeNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn setLoc(a: anytype, b: anytype, c: anytype) void {
    _ = a;
    _ = b;
    _ = c;
}
pub fn skipTypeParentheses(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}
pub fn getMembersOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn getLoc(a: anytype, b: anytype) ast.TextRange {
    _ = a;
    _ = b;
    return ast.TextRange{ .pos = 0, .end = 0 };
}
pub fn getAssertsModifierOfTypePredicate(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}
pub fn getAllAccessorDeclarations(a: anytype, b: anytype, c: anytype) struct { firstAccessor: ast.NodeIndex, secondAccessor: ast.NodeIndex, getAccessor: ast.NodeIndex, setAccessor: ast.NodeIndex } {
    _ = a;
    _ = b;
    _ = c;
    return .{ .firstAccessor = 0, .secondAccessor = 0, .getAccessor = 0, .setAccessor = 0 };
}

pub fn getLiteralOfLiteralTypeNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}
pub fn getParametersOfNode(a: anytype, b: anytype) []const ast.NodeIndex {
    _ = a;
    _ = b;
    return &[_]ast.NodeIndex{};
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

pub fn classOrConstructorParameterIsDecorated(a: anytype, b: anytype, c: anytype) bool {
    _ = a;
    _ = b;
    _ = c;
    return false;
}
pub fn getFirstConstructorWithBody(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
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
pub fn isDeclaration(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
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

pub fn getTextOfNode(a: anytype, b: anytype) []const u8 {
    _ = a;
    _ = b;
    return "";
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

pub fn getBodyOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
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
pub fn getPosOfNode(a: anytype, b: anytype) u32 {
    _ = a;
    _ = b;
    return 0;
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
pub fn getEndOfNode(a: anytype, b: anytype) u32 {
    _ = a;
    _ = b;
    return 0;
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
    return false;
}

pub fn isPropertyAccessExpression(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
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

pub fn getKind(a: anytype) std.meta.Tag(ast_gen.NodeData) {
    _ = a;
    return .Unknown;
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

pub fn getFlags(a: anytype) u32 {
    _ = a;
    return 0;
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

pub fn name(a: anytype) ast.NodeIndex {
    _ = a;
    return 0;
}
pub fn expression(a: anytype) ast.NodeIndex {
    _ = a;
    return 0;
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
pub fn nodesLen(a: anytype) u32 {
    _ = a;
    return 0;
}

pub fn members(a: anytype) ast.NodeIndex {
    _ = a;
    return 0;
}

pub fn questionDotToken(a: anytype) ast.NodeIndex {
    _ = a;
    return 0;
}
pub fn isComputedPropertyName(a: anytype) bool {
    _ = a;
    return false;
}
pub fn initializer(a: anytype) ast.NodeIndex {
    _ = a;
    return 0;
}
pub fn getNodes(a: anytype) []const ast.NodeIndex {
    _ = a;
    return &.{};
}
pub fn getOperatorTokenOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}

pub fn getBody(a: anytype) ast.NodeIndex {
    _ = a;
    return 0;
}
pub fn decorators(a: anytype) ast.NodeIndex {
    _ = a;
    return 0;
}
pub fn isStatic(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}
pub fn getInitializerOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}
pub fn hasStaticModifier(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
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
pub fn isOptionalChain(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
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

pub fn isInterfaceDeclaration(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}
pub fn isClassElement(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}

pub fn getCommonJSModuleIndicator(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}
pub fn isLeftHandSideExpression(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
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

pub fn parameters(a: anytype) ast.NodeIndex {
    _ = a;
    return 0;
}
pub fn isPropertyDeclaration(a: anytype) bool {
    _ = a;
    return false;
}
pub fn isPrivateIdentifier(a: anytype) bool {
    _ = a;
    return false;
}
pub fn canHaveDecorators(a: anytype) bool {
    _ = a;
    return false;
}
pub fn nodeOrChildIsDecorated(a: anytype, b: anytype, c: anytype, d: anytype) bool {
    _ = a;
    _ = b;
    _ = c;
    _ = d;
    return false;
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
pub fn hasAccessorModifier(a: anytype) bool {
    _ = a;
    return false;
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

pub fn forEachChildBool(a: anytype, b: anytype, c: anytype, d: anytype) bool {
    _ = a;
    _ = b;
    _ = c;
    _ = d;
    return false;
}

pub fn skipPartiallyEmittedExpressions(a: anytype) ast.NodeIndex {
    _ = a;
    return 0;
}
pub fn getModuleSpecifierOfNode(a: anytype, b: anytype) ast.NodeIndex {
    _ = a;
    _ = b;
    return 0;
}
pub fn isRequireCall(a: anytype, b: anytype, c: anytype) bool {
    _ = a;
    _ = b;
    _ = c;
    return false;
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

pub fn isAssignmentOperator(op: anytype) bool {
    _ = op;
    return false;
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

pub fn isLogicalOrCoalescingBinaryOperator(op: ast_gen.NodeData) bool {
    return op == .AmpersandAmpersandToken or op == .BarBarToken or op == .QuestionQuestionToken;
}

pub fn isLogicalOrCoalescingAssignmentOperator(op: ast_gen.NodeData) bool {
    return op == .AmpersandAmpersandEqualsToken or op == .BarBarEqualsToken or op == .QuestionQuestionEqualsToken;
}

pub fn isLogicalExpression(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    if (node == .BinaryExpression) {
        const op = tree.getNode(node.BinaryExpression.OperatorToken);
        return isLogicalOrCoalescingBinaryOperator(op);
    }
    return false;
}

pub fn isLogicalOrCoalescingAssignmentExpression(tree: *ast_pkg.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = tree.getNode(nodeIndex);
    if (node == .BinaryExpression) {
        const op = tree.getNode(node.BinaryExpression.OperatorToken);
        return isLogicalOrCoalescingAssignmentOperator(op);
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
    const parent = tree.getNodeParent(nodeIndex);
    if (parent == 0) return false;
    const parentNode = tree.getNode(parent);
    if (parentNode == .BinaryExpression) {
        const bin = parentNode.BinaryExpression;
        if (bin.Left == nodeIndex and isAssignmentOperator(tree.getNode(bin.OperatorToken))) return true;
    }
    return false;
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
