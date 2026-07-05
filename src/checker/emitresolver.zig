const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const types = @import("types.zig");
const checker = @import("checker.zig");
const checker_utils = @import("utilities.zig");
const relater = @import("relater.zig");
const binder = @import("../binder/binder.zig");
const core = @import("../core/core.zig");

// Links for jsx
pub const JSXLinks = struct {
    importRef: ast_gen.NodeIndex = 0,
};

pub const Tristate = enum(u8) {
    Unknown = 0,
    True = 1,
    False = 2,
};

// Links for declarations
pub const DeclarationLinks = struct {
    isVisible: Tristate = .Unknown, // if declaration is depended upon by exported declarations
};

pub const DeclarationFileLinks = struct {
    aliasesMarked: bool = false, // if file has had alias visibility marked
};

pub const SymbolAccessibilityResult = struct {
    accessibility: u32, // stub for printer.SymbolAccessibilityResult
    aliasesToMakeVisible: ?[]ast_gen.NodeIndex = null,
    errorSymbolName: ?[]const u8 = null,
    errorNode: ast_gen.NodeIndex = 0,
};

pub const TypeReferenceSerializationKind = enum(u32) {
    Unknown,
    TypeWithConstructSignatureAndValue,
    VoidNullableOrNeverType,
    NumberLikeType,
    BigIntLikeType,
    StringLikeType,
    BooleanType,
    ArrayLikeType,
    ESSymbolType,
    Promise,
    TypeWithCallSignature,
    ObjectType,
};

pub const EmitResolver = struct {
    chk: *checker.Checker,
    jsxLinks: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, JSXLinks) = .empty,
    declarationLinks: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, DeclarationLinks) = .empty,
    declarationFileLinks: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, DeclarationFileLinks) = .empty,
    referenceResolver: ?*binder.ReferenceResolver = null,

    pub fn init(chk: *checker.Checker) EmitResolver {
        return .{
            .chk = chk,
        };
    }

    pub fn deinit(self: *EmitResolver, allocator: std.mem.Allocator) void {
        self.jsxLinks.deinit(allocator);
        self.declarationLinks.deinit(allocator);
        self.declarationFileLinks.deinit(allocator);
    }

    pub fn getJsxFactoryEntity(self: *EmitResolver, location: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self;
        _ = location;
        return 0; // Stub
    }

    pub fn getJsxFragmentFactoryEntity(self: *EmitResolver, location: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self;
        _ = location;
        return 0; // Stub
    }

    pub fn isOptionalParameter(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        return self.chk.isOptionalParameter(node);
    }

    pub fn isLateBound(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        if (node == 0) return false;
        if (ast.nodeIsSynthesized(self.chk.tree, node)) return false;

        const symbol = self.chk.getSymbolOfDeclaration(node) orelse return false;
        const sym = self.chk.getSymbolData(symbol);
        return (sym.CheckFlags & types.CheckFlags.Late) != 0;
    }

    pub fn getEnumMemberValue(self: *EmitResolver, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self;
        _ = node;
        return 0; // Stub returning NodeIndex instead of evaluator.Result
    }

    pub fn isDeclarationVisible(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        if (node == 0) return false;
        if (ast_utils.nodeIsSynthesized(self.chk.tree, node)) return false;

        const links = self.declarationLinks.get(node);
        if (links) |l| {
            if (l.isVisible != .Unknown) return l.isVisible == .True;
        }

        const isVisible = self.determineIfDeclarationIsVisible(node);
        const entry = self.declarationLinks.getOrPutValue(self.chk.allocator, node, .{ .isVisible = if (isVisible) .True else .False }) catch unreachable;
        entry.value_ptr.isVisible = if (isVisible) .True else .False;
        return isVisible;
    }

    fn determineIfDeclarationIsVisible(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        const tree = self.chk.tree;
        const kind = tree.nodes.items(.tag)[node];

        switch (kind) {
            .JSDocCallbackTag, .JSDocTypedefTag => {
                const parent = ast_utils.getParent(tree, node);
                if (parent != 0) {
                    const pparent = ast_utils.getParent(tree, parent);
                    if (pparent != 0) {
                        const ppparent = ast_utils.getParent(tree, pparent);
                        return ppparent != 0 and ast_utils.isSourceFile(tree, ppparent);
                    }
                }
                return false;
            },
            .BindingElement => {
                const parent = ast_utils.getParent(tree, node);
                if (parent == 0) return false;
                const pparent = ast_utils.getParent(tree, parent);
                return self.isDeclarationVisible(pparent);
            },
            .VariableDeclaration, .ModuleDeclaration, .ClassDeclaration, .InterfaceDeclaration, .TypeAliasDeclaration, .JSTypeAliasDeclaration, .FunctionDeclaration, .EnumDeclaration, .ImportEqualsDeclaration => {
                if (kind == .VariableDeclaration) {
                    const name = ast_utils.getName(tree, node);
                    if (ast_utils.isBindingPattern(tree, name)) {
                        if (ast_utils.getElements(tree, name).len == 0) return false;
                    }
                }

                const isExtModAug = (kind == .ModuleDeclaration and tree.nodes.items(.tag)[ast_utils.getName(tree, node)] == .StringLiteral);
                const isImplicitJSDoc = (kind == .JSDocTypedefTag or kind == .JSDocCallbackTag) and (ast_utils.getParent(tree, node) != 0 and ast_utils.getParent(tree, ast_utils.getParent(tree, node)) != 0 and ast_utils.getParent(tree, ast_utils.getParent(tree, ast_utils.getParent(tree, node))) != 0 and ast_utils.isSourceFile(tree, ast_utils.getParent(tree, ast_utils.getParent(tree, ast_utils.getParent(tree, node)))));

                if (isExtModAug or isImplicitJSDoc) {
                    return true;
                }

                const parent = ast_utils.getDeclarationContainer(tree, node);
                const flags = ast_utils.getCombinedModifierFlags(tree, node);

                if ((flags & ast_gen.ModifierFlags.Export) == 0 and
                    !(kind != .ImportEqualsDeclaration and tree.nodes.items(.tag)[parent] != .SourceFile and (ast_utils.getFlags(tree, parent) & ast_gen.NodeFlags.Ambient) != 0))
                {
                    return ast_utils.isGlobalSourceFile(tree, parent);
                }
                return self.isDeclarationVisible(parent);
            },
            .PropertyDeclaration, .PropertySignature, .GetAccessor, .SetAccessor, .MethodDeclaration, .MethodSignature => {
                if (self.getEffectiveDeclarationFlags(node, ast_gen.ModifierFlags.Private | ast_gen.ModifierFlags.Protected) != 0) {
                    return false;
                }
                return self.isDeclarationVisible(ast_utils.getParent(tree, node));
            },
            .Constructor, .ConstructSignature, .CallSignature, .IndexSignature, .Parameter, .ModuleBlock, .FunctionType, .ConstructorType, .TypeLiteral, .TypeReference, .ArrayType, .TupleType, .UnionType, .IntersectionType, .ParenthesizedType, .NamedTupleMember => {
                return self.isDeclarationVisible(ast_utils.getParent(tree, node));
            },
            .ImportClause, .NamespaceImport, .ImportSpecifier => {
                return false;
            },
            .TypeParameter, .SourceFile, .NamespaceExportDeclaration => {
                return true;
            },
            .ExportAssignment => {
                return false;
            },
            .ExportSpecifier => {
                const parent = ast_utils.getParent(tree, node);
                if (parent == 0) return false;
                const exportDecl = ast_utils.getParent(tree, parent);
                if (exportDecl != 0 and tree.nodes.items(.tag)[exportDecl] == .ExportDeclaration) {
                    const expDecl = tree.nodes.get(exportDecl).ExportDeclaration;
                    if (expDecl.ModuleSpecifier == 0) {
                        return self.isDeclarationVisible(ast_utils.getParent(tree, exportDecl));
                    }
                }
                return false;
            },
            else => return false,
        }
    }

    pub fn precalculateDeclarationEmitVisibility(self: *EmitResolver, file: ast_gen.NodeIndex) void {
        _ = self;
        _ = file;
    }

    pub fn isEntityNameVisible(self: *EmitResolver, entityName: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex) SymbolAccessibilityResult {
        _ = self;
        _ = entityName;
        _ = enclosingDeclaration;
        return .{ .accessibility = 0 }; // Stub
    }

    pub fn isImplementationOfOverload(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        return self.chk.isImplementationOfOverload(node) orelse false;
    }

    pub fn isImportRequiredByAugmentation(self: *EmitResolver, decl: ast_gen.NodeIndex) bool {
        _ = self;
        _ = decl;
        return false; // Stub
    }

    pub fn isDefinitelyReferenceToGlobalSymbolObject(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        _ = self;
        _ = node;
        return false; // Stub
    }

    pub fn requiresAddingImplicitUndefined(self: *EmitResolver, declaration: ast_gen.NodeIndex, symbol: ast_gen.SymbolIndex, enclosingDeclaration: ast_gen.NodeIndex) bool {
        _ = self;
        _ = declaration;
        _ = symbol;
        _ = enclosingDeclaration;
        return false; // Stub
    }

    pub fn requiresAddingImplicitUndefinedUnsafe(self: *EmitResolver, declaration: ast_gen.NodeIndex, symbol: ast_gen.SymbolIndex, enclosingDeclaration: ast_gen.NodeIndex) bool {
        _ = self;
        _ = declaration;
        _ = symbol;
        _ = enclosingDeclaration;
        return false; // Stub
    }

    pub fn isLiteralConstDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        if (node == 0) return false;
        if (ast_utils.nodeIsSynthesized(self.chk.tree, node)) return false;

        const tree = self.chk.tree;
        const kind = tree.nodes.items(.tag)[node];

        const isReadonly = checker_utils.isDeclarationReadonly(tree, node);
        const isVarConst = kind == .VariableDeclaration and (ast_utils.getCombinedNodeFlags(tree, node) & ast_gen.NodeFlags.BlockScoped) == ast_gen.NodeFlags.Const;

        if (isReadonly or isVarConst) {
            const symbol = self.chk.getSymbolOfDeclaration(node) orelse return false;
            const t = self.chk.getTypeOfSymbol(symbol);
            return relater.isFreshLiteralType(self.chk, t);
        }
        return false;
    }

    pub fn isExpandoFunctionDeclarationUnsafe(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        if (node == 0) return false;
        if (ast_utils.nodeIsSynthesized(self.chk.tree, node)) return false;

        const props = self.getPropertiesOfContainerFunction(node);
        for (props) |prop| {
            const sym = self.chk.getSymbolData(prop);
            if (sym.ValueDeclaration) |vd| {
                if (vd != 0 and self.chk.tree.nodes.items(.tag)[vd] == .BinaryExpression) {
                    return true;
                }
            }
        }
        return false;
    }

    pub fn isExpandoFunctionDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        return self.isExpandoFunctionDeclarationUnsafe(node);
    }

    pub fn isSymbolAccessible(self: *EmitResolver, symbol: ast_gen.SymbolIndex, enclosingDeclaration: ast_gen.NodeIndex, meaning: u32, shouldComputeAliasToMarkVisible: bool) SymbolAccessibilityResult {
        _ = self;
        _ = symbol;
        _ = enclosingDeclaration;
        _ = meaning;
        _ = shouldComputeAliasToMarkVisible;
        return .{ .accessibility = 0 }; // Stub
    }

    fn isConstEnumOrConstEnumOnlyModule(c: *checker.Checker, symbol: ast_gen.SymbolIndex) bool {
        const flags = c.getSymbolFlags(symbol);
        return (flags & ast_gen.SymbolFlags.ConstEnum) != 0 or (flags & ast_gen.SymbolFlags.ConstEnumOnlyModule) != 0;
    }

    // Removed resolveAliasStub from here, moved down

    // Removed getTypeOnlyAliasDeclarationStub from here, moved down

    fn getSymbolFlagsExStub(c: *checker.Checker, symbol: ast_gen.SymbolIndex, excludeTypeOnlyMeanings: bool, excludeLocalMeanings: bool) u32 {
        _ = excludeTypeOnlyMeanings;
        _ = excludeLocalMeanings;
        return c.getSymbolFlags(symbol); // Stub
    }

    fn resolveExternalModuleSymbolStub(c: *checker.Checker, symbol: ast_gen.SymbolIndex, dontResolveAlias: bool) void {
        _ = c;
        _ = symbol;
        _ = dontResolveAlias;
    }

    fn isCommonJSModuleExports(tree: *ast_gen.Tree, node: ast_gen.NodeIndex) bool {
        _ = tree;
        _ = node;
        return false; // Stub
    }

    pub fn isReferencedAliasDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        const c = self.checker;
        if (!c.canCollectSymbolAliasAccessibilityData or !ast_utils.isParseTreeNode(c.binder.ast, node)) {
            return true;
        }

        if (ast_utils.isAliasSymbolDeclaration(c.binder.ast, node)) {
            const symbol = c.getSymbolOfDeclaration(node);
            if (symbol != 0) {
                if (c.aliasSymbolLinks.get(symbol)) |aliasLinks| {
                    if (aliasLinks.referenced) {
                        return true;
                    }
                    if (aliasLinks.aliasTarget) |target| {
                        if ((ast_utils.getCombinedModifierFlags(c.binder.ast, node) & ast_gen.ModifierFlags.Export) != 0 and
                            (c.getSymbolFlags(target) & ast_gen.SymbolFlags.Value) != 0 and
                            !isConstEnumOrConstEnumOnlyModule(c, target))
                        {
                            return true;
                        }
                    }
                }
            }
        }
        return false;
    }

    pub fn isAliasResolvedToValue(self: *EmitResolver, symbol: ast_gen.SymbolIndex, excludeTypeOnlyValues: bool) bool {
        const c = self.checker;
        if (symbol == 0) return false;

        const decl = c.getSymbolValueDeclaration(symbol);
        if (decl != 0) {
            const container = ast_utils.getSourceFileOfNode(c.binder.ast, decl);
            if (container != 0) {
                const fileSymbol = c.getSymbolOfDeclaration(container);
                resolveExternalModuleSymbolStub(c, fileSymbol, false);
            }
        }

        const target = checker.Checker.getExportSymbolOfValueSymbolIfExported(c, resolveAliasStub(c, symbol));
        if (target == c.unknownSymbol) {
            return !excludeTypeOnlyValues or getTypeOnlyAliasDeclarationStub(c, symbol) == 0;
        }

        const flags = getSymbolFlagsExStub(c, symbol, excludeTypeOnlyValues, true);
        return (flags & ast_gen.SymbolFlags.Value) != 0 and !isConstEnumOrConstEnumOnlyModule(c, target);
    }

    pub fn isValueAliasDeclarationWorker(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        const c = self.checker;
        const tree = c.binder.ast;

        switch (tree.nodes.items[node].tag) {
            .ImportEqualsDeclaration => return self.isAliasResolvedToValue(c.getSymbolOfDeclaration(node), false),
            .ImportClause, .NamespaceImport, .ImportSpecifier, .ExportSpecifier => {
                const symbol = c.getSymbolOfDeclaration(node);
                return symbol != 0 and self.isAliasResolvedToValue(symbol, true);
            },
            .ExportDeclaration => {
                const exportClause = tree.nodes.items[node].data.ExportDeclaration.exportClause;
                if (exportClause != 0) {
                    if (tree.nodes.items[exportClause].tag == .NamespaceExport) return true;
                    if (tree.nodes.items[exportClause].tag == .NamedExports) {
                        const elements = tree.nodes.items[exportClause].data.NamedExports.elements;
                        for (tree.node_slices.items[elements.start .. elements.start + elements.len]) |elem| {
                            if (self.isValueAliasDeclaration(elem)) return true;
                        }
                    }
                }
                return false;
            },
            .ExportAssignment => {
                const expression = tree.nodes.items[node].data.ExportAssignment.expression;
                if (expression != 0 and tree.nodes.items[expression].tag == .Identifier) {
                    return self.isAliasResolvedToValue(c.getSymbolOfDeclaration(node), true);
                }
                return true;
            },
            .BinaryExpression => {
                if (isCommonJSModuleExports(tree, node)) {
                    const right = tree.nodes.items[node].data.BinaryExpression.right;
                    if (tree.nodes.items[right].tag == .Identifier) {
                        return self.isAliasResolvedToValue(c.getSymbolOfDeclaration(node), true);
                    }
                }
                return true;
            },
            else => return false,
        }
    }

    pub fn isValueAliasDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        const c = self.checker;
        if (!c.canCollectSymbolAliasAccessibilityData or !ast_utils.isParseTreeNode(c.binder.ast, node)) {
            return true;
        }

        return self.isValueAliasDeclarationWorker(node);
    }

    pub fn isTopLevelValueImportEqualsWithEntityName(self: *EmitResolver, node: ast_gen.NodeIndex) bool {
        const c = self.checker;
        const tree = c.binder.ast;

        if (!c.canCollectSymbolAliasAccessibilityData) {
            return true;
        }

        const parent = ast_utils.getParent(tree, node);
        if (!ast_utils.isParseTreeNode(tree, node) or tree.nodes.items[node].tag != .ImportEqualsDeclaration or parent == 0 or tree.nodes.items[parent].tag != .SourceFile) {
            return false;
        }

        const moduleRef = tree.nodes.items[node].data.ImportEqualsDeclaration.moduleReference;
        if (ast_utils.nodeIsMissing(tree, moduleRef) or tree.nodes.items[moduleRef].tag == .ExternalModuleReference) {
            return false;
        }

        return self.isAliasResolvedToValue(c.getSymbolOfDeclaration(node), false);
    }

    fn markLinkedReferencesRecursivelyVisitor(c: *checker.Checker, tree: *ast_gen.Tree, node: ast_gen.NodeIndex) void {
        if (tree.nodes.items[node].tag == .ImportEqualsDeclaration and (ast_utils.getCombinedModifierFlags(tree, node) & ast_gen.ModifierFlags.Export) == 0) {
            return; // These are deferred and marked in a chain when referenced
        }
        if (tree.nodes.items[node].tag == .ImportDeclaration) {
            return; // likewise, these are ultimately what get marked by calls on other nodes - we want to skip them
        }

        // c.markLinkedReferences(node, ReferenceHintUnspecified, 0, 0); // Stub

        ast_utils.forEachChild(tree, node, c, markLinkedReferencesRecursivelyVisitorCb);
    }

    fn markLinkedReferencesRecursivelyVisitorCb(c: *checker.Checker, tree: *ast_gen.Tree, child: ast_gen.NodeIndex) bool {
        markLinkedReferencesRecursivelyVisitor(c, tree, child);
        return false;
    }

    pub fn markLinkedReferencesRecursively(self: *EmitResolver, file: ast_gen.NodeIndex) void {
        if (file != 0) {
            ast_utils.forEachChild(self.checker.binder.ast, file, self.checker, markLinkedReferencesRecursivelyVisitorCb);
        }
    }

    pub fn getExternalModuleFileFromDeclaration(self: *EmitResolver, declaration: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self;
        _ = declaration;
        return 0; // Stub
    }

    pub fn getReferenceResolver(self: *EmitResolver) *binder.ReferenceResolver {
        if (self.referenceResolver == null) {
            const alloc = self.chk.allocator;
            const res = alloc.create(binder.ReferenceResolver) catch unreachable;
            res.* = binder.ReferenceResolver.init(self.chk.tree, .{}); // TODO: ReferenceResolverHooks
            self.referenceResolver = res;
        }
        return self.referenceResolver.?;
    }

    pub fn getReferencedExportContainer(self: *EmitResolver, node: ast_gen.NodeIndex, prefixLocals: bool) ast_gen.NodeIndex {
        return self.getReferenceResolver().getReferencedExportContainer(node, prefixLocals);
    }

    pub fn setReferencedImportDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex, ref: ast_gen.NodeIndex) void {
        _ = self;
        _ = node;
        _ = ref;
    }

    pub fn getReferencedImportDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = self.chk.tree;
        if (!ast_utils.isParseTreeNode(tree, node)) {
            if (self.jsxLinks.get(node)) |links| {
                return links.importRef;
            }
            return 0;
        }

        const symbol = self.chk.getReferencedValueOrAliasSymbol(node);
        if (ast_utils.isNonLocalAlias(self.chk.getSymbolFlags(symbol), ast_gen.SymbolFlags.Value) and self.chk.getTypeOnlyAliasDeclarationEx(symbol, ast_gen.SymbolFlags.Value) == 0) {
            return self.chk.getDeclarationOfAliasSymbol(symbol);
        }
        return 0;
    }

    pub fn getReferencedValueDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        if (!ast_utils.isParseTreeNode(self.chk.tree, node)) return 0;
        return self.getReferenceResolver().getReferencedValueDeclaration(node);
    }

    pub fn getReferencedValueDeclarations(self: *EmitResolver, node: ast_gen.NodeIndex) []const ast_gen.NodeIndex {
        if (!ast_utils.isParseTreeNode(self.chk.tree, node)) return &[_]ast_gen.NodeIndex{};
        return self.getReferenceResolver().getReferencedValueDeclarations(node);
    }

    pub fn isNameResolvable(self: *EmitResolver, location: ast_gen.NodeIndex, name: []const u8) bool {
        const symbol = self.chk.resolveName(location, name, ast_gen.SymbolFlags.Value | ast_gen.SymbolFlags.Type | ast_gen.SymbolFlags.Namespace, null, false, false);
        return symbol != 0;
    }

    pub fn getElementAccessExpressionName(self: *EmitResolver, expression: ast_gen.NodeIndex) []const u8 {
        if (!ast_utils.isParseTreeNode(self.chk.tree, expression)) return "";
        return self.getReferenceResolver().getElementAccessExpressionName(expression);
    }

    pub fn getReferencedMemberValueDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        if (!ast_utils.isParseTreeNode(self.chk.tree, node)) return 0;
        return self.getReferenceResolver().getReferencedMemberValueDeclaration(node);
    }

    pub fn createReturnTypeOfSignatureDeclaration(self: *EmitResolver, emitContext: anytype, signatureDeclaration: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: u32, internalFlags: u32, tracker: anytype) ast_gen.NodeIndex {
        _ = tracker;
        const original = emitContext.parseNode(signatureDeclaration);
        if (original == 0) {
            return emitContext.factory.newKeywordTypeNode(ast_gen.SyntaxKind.AnyKeyword);
        }
        var b = self.chk.getNodeBuilderEx();
        return b.serializeReturnTypeForSignature(original, enclosingDeclaration, @bitCast(flags), @bitCast(internalFlags));
    }

    pub fn createTypeParametersOfSignatureDeclaration(self: *EmitResolver, emitContext: anytype, signatureDeclaration: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: u32, internalFlags: u32, tracker: anytype) []const ast_gen.NodeIndex {
        _ = tracker;
        const original = emitContext.parseNode(signatureDeclaration);
        if (original == 0) return &[_]ast_gen.NodeIndex{};
        var b = self.chk.getNodeBuilderEx();
        return b.serializeTypeParametersForSignature(original, enclosingDeclaration, @bitCast(flags), @bitCast(internalFlags));
    }

    pub fn createTypeOfDeclaration(self: *EmitResolver, emitContext: anytype, declaration: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: u32, internalFlags: u32, tracker: anytype) ast_gen.NodeIndex {
        _ = tracker;
        const original = emitContext.parseNode(declaration);
        if (original == 0) {
            return emitContext.factory.newKeywordTypeNode(ast_gen.SyntaxKind.AnyKeyword);
        }
        var b = self.chk.getNodeBuilderEx();
        const symbol = self.chk.getSymbolOfDeclaration(original) orelse 0;
        return b.serializeTypeForDeclaration(original, symbol, enclosingDeclaration, @bitCast(flags), @bitCast(internalFlags));
    }

    pub fn createLiteralConstValue(self: *EmitResolver, emitContext: anytype, node: ast_gen.NodeIndex, tracker: anytype) ast_gen.NodeIndex {
        _ = self;
        _ = emitContext;
        _ = node;
        _ = tracker;
        return 0; // Stub
    }

    pub fn createTypeOfExpression(self: *EmitResolver, emitContext: anytype, expression: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: u32, internalFlags: u32, tracker: anytype) ast_gen.NodeIndex {
        _ = tracker;
        const expr = emitContext.parseNode(expression);
        if (expr == 0) {
            return emitContext.factory.newKeywordTypeNode(ast_gen.SyntaxKind.AnyKeyword);
        }
        var b = self.chk.getNodeBuilderEx();
        return b.serializeTypeForExpression(expr, enclosingDeclaration, @bitCast(flags), @bitCast(internalFlags));
    }

    pub fn createLateBoundIndexSignatures(self: *EmitResolver, emitContext: anytype, container: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: u32, internalFlags: u32, tracker: anytype) []const ast_gen.NodeIndex {
        _ = self;
        _ = emitContext;
        _ = container;
        _ = enclosingDeclaration;
        _ = flags;
        _ = internalFlags;
        _ = tracker;
        return &[_]ast_gen.NodeIndex{}; // Stub
    }

    pub fn getEffectiveDeclarationFlags(self: *EmitResolver, node: ast_gen.NodeIndex, flags: u32) u32 {
        return self.chk.getEffectiveDeclarationFlags(node, flags);
    }

    pub fn getResolutionModeOverride(self: *EmitResolver, node: ast_gen.NodeIndex) u32 {
        return self.chk.getResolutionModeOverride(node, true);
    }

    pub fn getConstantValue(self: *EmitResolver, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.chk.getConstantValue(node); // Assuming getConstantValue returns NodeIndex instead of `any` like in Go
    }

    fn isTypeOnlyImportOrExportDeclaration(tree: *ast_gen.Tree, node: ast_gen.NodeIndex) bool {
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

    fn resolveAliasStub(c: *checker.Checker, symbol: ast_gen.SymbolIndex) ast_gen.SymbolIndex {
        if (c.aliasSymbolLinks.get(symbol)) |links| {
            if (links.aliasTarget) |target| return target;
        }
        return symbol; // Stub
    }

    fn getTypeOnlyAliasDeclarationStub(c: *checker.Checker, symbol: ast_gen.SymbolIndex) ast_gen.NodeIndex {
        if (c.aliasSymbolLinks.get(symbol)) |links| {
            if (links.typeOnlyDeclaration) |decl| return decl;
        }
        return 0; // Stub
    }

    fn getFirstIdentifier(tree: *ast_gen.Tree, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        var current = node;
        while (current != 0) {
            switch (tree.nodes.items[current].tag) {
                .Identifier => return current,
                .QualifiedName => current = tree.nodes.items[current].data.QualifiedName.left,
                .PropertyAccessExpression => current = tree.nodes.items[current].data.PropertyAccessExpression.expression,
                else => break,
            }
        }
        return current;
    }

    pub fn getTypeReferenceSerializationKind(self: *EmitResolver, typeName: ast_gen.NodeIndex, location: ast_gen.NodeIndex) TypeReferenceSerializationKind {
        const c = self.checker;
        const tree = c.binder.ast;

        if (typeName == 0 or location == 0) {
            return .Unknown;
        }

        var isTypeOnly = false;
        if (tree.nodes.items[typeName].tag == .QualifiedName) {
            const firstId = getFirstIdentifier(tree, typeName);
            const rootValueSymbol = checker.Checker.resolveEntityName(c, firstId, ast_gen.SymbolFlags.Value, true, true, location);
            if (rootValueSymbol != 0) {
                const declarations = c.binder.symbols.items[rootValueSymbol].declarations;
                if (declarations.len > 0) {
                    isTypeOnly = true;
                    for (c.binder.symbol_declarations.items[declarations.start .. declarations.start + declarations.len]) |decl| {
                        if (!isTypeOnlyImportOrExportDeclaration(tree, decl)) {
                            isTypeOnly = false;
                            break;
                        }
                    }
                }
            }
        }

        const valueSymbol = checker.Checker.resolveEntityName(c, typeName, ast_gen.SymbolFlags.Value, true, true, location);
        var resolvedValueSymbol = valueSymbol;
        if (valueSymbol != 0 and (c.getSymbolFlags(valueSymbol) & ast_gen.SymbolFlags.Alias) != 0) {
            resolvedValueSymbol = resolveAliasStub(c, valueSymbol);
        }

        isTypeOnly = isTypeOnly or (valueSymbol != 0 and getTypeOnlyAliasDeclarationStub(c, valueSymbol) != 0);

        const typeSymbol = checker.Checker.resolveEntityName(c, typeName, ast_gen.SymbolFlags.Type, true, true, location);
        var resolvedTypeSymbol = typeSymbol;
        if (typeSymbol != 0 and (c.getSymbolFlags(typeSymbol) & ast_gen.SymbolFlags.Alias) != 0) {
            resolvedTypeSymbol = resolveAliasStub(c, typeSymbol);
        }

        isTypeOnly = isTypeOnly or (typeSymbol != 0 and getTypeOnlyAliasDeclarationStub(c, typeSymbol) != 0);

        if (resolvedValueSymbol != 0 and resolvedValueSymbol == resolvedTypeSymbol) {
            const globalPromiseSymbol = c.getGlobalPromiseConstructorSymbol() catch 0;
            if (globalPromiseSymbol != 0 and resolvedValueSymbol == globalPromiseSymbol) {
                return .Promise;
            }

            const constructorType = c.getTypeOfSymbol(resolvedValueSymbol) catch 0;
            if (constructorType != 0 and checker.Checker.isConstructorType(c, constructorType)) {
                if (isTypeOnly) {
                    return .TypeWithCallSignature;
                }
                return .TypeWithConstructSignatureAndValue;
            }
        }

        if (resolvedTypeSymbol == 0) {
            if (isTypeOnly) {
                return .ObjectType;
            }
            return .Unknown;
        }

        const type_ = c.getDeclaredTypeOfSymbol(resolvedTypeSymbol) catch 0;
        if (checker.Checker.isErrorType(c, type_)) {
            if (isTypeOnly) {
                return .ObjectType;
            }
            return .Unknown;
        }

        const tflags = c.typesList.items[type_].flags;
        if ((tflags & types.TypeFlags.AnyOrUnknown) != 0) {
            return .ObjectType;
        } else if (checker.Checker.isTypeAssignableToKind(c, type_, types.TypeFlags.Void | types.TypeFlags.Nullable | types.TypeFlags.Never)) {
            return .VoidNullableOrNeverType;
        } else if (checker.Checker.isTypeAssignableToKind(c, type_, types.TypeFlags.BooleanLike)) {
            return .BooleanType;
        } else if (checker.Checker.isTypeAssignableToKind(c, type_, types.TypeFlags.NumberLike)) {
            return .NumberLikeType;
        } else if (checker.Checker.isTypeAssignableToKind(c, type_, types.TypeFlags.BigIntLike)) {
            return .BigIntLikeType;
        } else if (checker.Checker.isTypeAssignableToKind(c, type_, types.TypeFlags.StringLike)) {
            return .StringLikeType;
        } else if (checker.Checker.isTupleType(c, type_)) {
            return .ArrayLikeType;
        } else if (checker.Checker.isTypeAssignableToKind(c, type_, types.TypeFlags.ESSymbolLike)) {
            return .ESSymbolType;
        } else if (checker.Checker.isFunctionType(c, type_)) {
            return .TypeWithCallSignature;
        } else if (checker.Checker.isArrayType(c, type_)) {
            return .ArrayLikeType;
        } else {
            return .ObjectType;
        }
    }

    pub fn getPropertiesOfContainerFunction(self: *EmitResolver, node: ast_gen.NodeIndex) []const ast_gen.SymbolIndex {
        if (node == 0) return &[_]ast_gen.SymbolIndex{};
        const symbol = self.chk.getSymbolOfDeclaration(node) orelse return &[_]ast_gen.SymbolIndex{};
        return self.chk.getPropertiesOfType(self.chk.getTypeOfSymbol(symbol));
    }

    pub fn tryJSTypeNodeToTypeNode(self: *EmitResolver, emitContext: anytype, typeNode: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: u32, internalFlags: u32, tracker: anytype) ast_gen.NodeIndex {
        _ = tracker;
        const c = self.checker;

        const requestNodeBuilder = c.getNodeBuilderEx();
        // Since nodebuilder is mostly stubbed, we'll assume it accepts flags and internalFlags as u32 via bitCast
        return requestNodeBuilder.tryJSTypeNodeToTypeNode(emitContext.parseNode(typeNode), enclosingDeclaration, @bitCast(flags), @bitCast(internalFlags));
    }

    pub fn getBaseDeclarationsForPropertyDeclaration(self: *EmitResolver, node: ast_gen.NodeIndex) []const ast_gen.NodeIndex {
        if (node == 0) return &[_]ast_gen.NodeIndex{};
        const c = self.checker;

        const s = c.getSymbolOfDeclaration(node) orelse return &[_]ast_gen.NodeIndex{};
        const parentSymbol = c.getSymbolParent(s);
        if (parentSymbol == 0) return &[_]ast_gen.NodeIndex{};

        const parentType = c.getDeclaredTypeOfSymbol(parentSymbol) catch 0;
        if (parentType == 0) return &[_]ast_gen.NodeIndex{};

        const bases = checker.Checker.getBaseTypes(c, parentType) catch &[_]types.TypeIndex{};
        const name = c.getSymbolName(s);
        for (bases) |b| {
            const baseProp = c.getPropertyOfObjectType(b, name);
            if (baseProp != 0) {
                const declarations = c.getSymbolDeclarations(baseProp);
                if (declarations.len > 0) {
                    return declarations;
                }
            }
        }
        return &[_]ast_gen.NodeIndex{};
    }
};
