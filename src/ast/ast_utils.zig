const std = @import("std");
const ast = @import("ast.zig");
const ast_gen = @import("ast_generated.zig");
const kind = @import("kind.zig");

pub const ModifierFlags = struct {
    pub const None: u32 = 0;
    pub const Export: u32 = 1 << 0;
    pub const Ambient: u32 = 1 << 1;
    pub const Public: u32 = 1 << 2;
    pub const Private: u32 = 1 << 3;
    pub const Protected: u32 = 1 << 4;
    pub const Readonly: u32 = 1 << 5;
    
    pub const Override: u32 = 1 << 6;
    pub const ParameterPropertyModifier: u32 = Public | Private | Protected | Readonly | Override;
    pub const Default: u32 = 1 << 7;
    pub const Static: u32 = 1 << 8;
    pub const Accessor: u32 = 1 << 9;
    pub const In: u32 = 1 << 13;
    pub const Out: u32 = 1 << 14;
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

pub fn isExternalModuleReference(a: *ast.Ast, nodeIndex: ast_gen.NodeIndex) bool {
    const node = a.getNode(nodeIndex);
    return node == .ExternalModuleReference;
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

pub fn isExternalModule(a: *ast.Ast, sourceFileIndex: ast_gen.NodeIndex) bool {
    const sourceFileNode = a.getNode(sourceFileIndex).SourceFile;
    if (sourceFileNode.ExternalModuleIndicator) |_| {
        return true;
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
    std.debug.print("hasDynamicName node={} index={}\n", .{a.getNode(nodeIndex), nodeIndex});

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

