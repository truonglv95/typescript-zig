const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const symbol = @import("../ast/symbol.zig");
const ast = @import("../ast/ast.zig");
const nameresolver = @import("nameresolver.zig");
const ast_utils = @import("../ast/ast_utils.zig");

pub const ReferenceResolverHooks = struct {
    GetResolvedSymbol: ?*const fn (node: ast_gen.NodeIndex) ?ast_gen.SymbolIndex = null,
    GetMergedSymbol: ?*const fn (sym: ast_gen.SymbolIndex) ?ast_gen.SymbolIndex = null,
    GetParentOfSymbol: ?*const fn (sym: ast_gen.SymbolIndex) ?ast_gen.SymbolIndex = null,
    GetSymbolOfDeclaration: ?*const fn (declaration: ast_gen.NodeIndex) ?ast_gen.SymbolIndex = null,
    ResolveName: ?*const fn (location: ast_gen.NodeIndex, name: []const u8, meaning: u32, nameNotFoundMessage: ?*const anyopaque, isUse: bool, excludeGlobals: bool) ?ast_gen.SymbolIndex = null,
    GetTypeOnlyAliasDeclaration: ?*const fn (sym: ast_gen.SymbolIndex, excludes: u32) ?ast_gen.NodeIndex = null,
    GetExportSymbolOfValueSymbolIfExported: ?*const fn (sym: ast_gen.SymbolIndex) ?ast_gen.SymbolIndex = null,
    GetElementAccessExpressionName: ?*const fn (expression: ast_gen.NodeIndex) ?[]const u8 = null,
};

pub const ReferenceResolver = struct {
    hooks: ReferenceResolverHooks,
    resolver: ?*nameresolver.NameResolver,
    tree: *ast.Ast,

    pub fn init(tree: *ast.Ast, hooks: ReferenceResolverHooks) ReferenceResolver {
        return .{
            .tree = tree,
            .hooks = hooks,
            .resolver = null,
        };
    }

    pub fn getResolvedSymbol(self: *ReferenceResolver, node: ast_gen.NodeIndex) ?ast_gen.SymbolIndex {
        if (node != 0) {
            if (self.hooks.GetResolvedSymbol) |hook| {
                return hook(node);
            }
        }
        return null;
    }

    pub fn getMergedSymbol(self: *ReferenceResolver, sym: ?ast_gen.SymbolIndex) ?ast_gen.SymbolIndex {
        if (sym) |s| {
            if (self.hooks.GetMergedSymbol) |hook| {
                return hook(s);
            }
            return s;
        }
        return null;
    }

    pub fn getParentOfSymbol(self: *ReferenceResolver, sym: ?ast_gen.SymbolIndex) ?ast_gen.SymbolIndex {
        if (sym) |s| {
            if (self.hooks.GetParentOfSymbol) |hook| {
                return hook(s);
            }
            return self.tree.getSymbolParent(s);
        }
        return null;
    }

    pub fn getSymbolOfDeclaration(self: *ReferenceResolver, declaration: ast_gen.NodeIndex) ?ast_gen.SymbolIndex {
        if (declaration != 0) {
            if (self.hooks.GetSymbolOfDeclaration) |hook| {
                return hook(declaration);
            }
            return self.tree.getNodeSymbol(declaration);
        }
        return null;
    }

    pub fn getReferencedValueSymbol(self: *ReferenceResolver, reference: ast_gen.NodeIndex, startInDeclarationContainer: bool) ?ast_gen.SymbolIndex {
        const resolvedSymbol = self.getResolvedSymbol(reference);
        if (resolvedSymbol != null) {
            return resolvedSymbol;
        }

        var location = reference;
        const parent = self.tree.getNodeParent(reference);
        if (startInDeclarationContainer and parent != 0 and ast_utils.isDeclaration(self.tree, parent)) {
            // Need to port GetDeclarationContainer from Go to ast_utils if missing
            // For now use parent's parent as rough approximation
            location = self.tree.getNodeParent(parent);
        }

        // We skip hooks.ResolveName for now as it's checker specific.
        
        if (self.resolver) |r| {
            _ = r;
            // TODO: Extract text of identifier
            // return r.resolve(location, text, symbol.SymbolFlags.ExportValue | symbol.SymbolFlags.Value | symbol.SymbolFlags.Alias);
        }
        return null;
    }

    pub fn isTypeOnlyAliasDeclaration(self: *ReferenceResolver, symIndex: ?ast_gen.SymbolIndex) bool {
        if (symIndex) |s| {
            if (self.hooks.GetTypeOnlyAliasDeclaration) |hook| {
                if (hook(s, symbol.SymbolFlags.Value) != null) return true;
            }

            var nodeOpt = self.getDeclarationOfAliasSymbol(s);
            while (nodeOpt) |nodeIndex| {
                if (nodeIndex == 0) break;
                const node = self.tree.getNode(nodeIndex);
                switch (node) {
                    .ImportEqualsDeclaration, .ExportDeclaration => {
                        return ast_utils.isTypeOnly(self.tree, nodeIndex);
                    },
                    .ImportClause, .ImportSpecifier, .ExportSpecifier => {
                        if (ast_utils.isTypeOnly(self.tree, nodeIndex)) {
                            return true;
                        }
                        nodeOpt = self.tree.getNodeParent(nodeIndex);
                        continue;
                    },
                    .NamedImports, .NamedExports => {
                        nodeOpt = self.tree.getNodeParent(nodeIndex);
                        continue;
                    },
                    else => break,
                }
            }
        }
        return false;
    }

    pub fn getDeclarationOfAliasSymbol(self: *ReferenceResolver, symIndex: ?ast_gen.SymbolIndex) ?ast_gen.NodeIndex {
        if (symIndex) |s| {
            const sym = self.tree.symbols.items[s];
            if (sym.Declarations) |decls| {
                var i: usize = decls.items.len;
                while (i > 0) {
                    i -= 1;
                    const decl = decls.items[i];
                    if (ast_utils.isAliasSymbolDeclaration(self.tree, decl)) {
                        return decl;
                    }
                }
            }
        }
        return null;
    }

    pub fn getExportSymbolOfValueSymbolIfExported(self: *ReferenceResolver, symIndex: ?ast_gen.SymbolIndex) ?ast_gen.SymbolIndex {
        if (symIndex) |s| {
            if (self.hooks.GetExportSymbolOfValueSymbolIfExported) |hook| {
                if (hook(s)) |res| return res;
            }
            const sym = self.tree.symbols.items[s];
            var current = s;
            if ((sym & symbol.SymbolFlags.ExportValue) != 0 and 0 != 0) {
                current = 0;
            }
            return self.getMergedSymbol(current);
        }
        return null;
    }

    pub fn getReferencedExportContainer(self: *ReferenceResolver, nodeIndex: ast_gen.NodeIndex, prefixLocals: bool) ?ast_gen.NodeIndex {
        const parentIndex = self.tree.getNodeParent(nodeIndex);
        var startInDeclarationContainer = false;
        if (parentIndex != 0) {
            const parent = self.tree.getNode(parentIndex);
            if (parent == .ModuleDeclaration or parent == .EnumDeclaration) {
                if (ast_utils.getName(self.tree, parentIndex) == nodeIndex) {
                    startInDeclarationContainer = true;
                }
            }
        }
        if (self.getReferencedValueSymbol(nodeIndex, startInDeclarationContainer)) |originalSymbol| {
            var symIndex = originalSymbol;
            var sym = self.tree.symbols.items[symIndex];
            if ((sym & symbol.SymbolFlags.ExportValue) != 0) {
                const exportSymOpt = self.getMergedSymbol(0);
                if (exportSymOpt) |exportSymIndex| {
                    const exportSym = self.tree.symbols.items[exportSymIndex];
                    if (!prefixLocals and (exportSym & symbol.SymbolFlags.ExportHasLocal) != 0 and (exportSym & symbol.SymbolFlags.Variable) == 0) {
                        return null;
                    }
                    symIndex = exportSymIndex;
                    sym = exportSym;
                }
            }
            if (self.getParentOfSymbol(symIndex)) |parentSymbolIndex| {
                const parentSymbol = self.tree.symbols.items[parentSymbolIndex];
                if ((parentSymbol & symbol.SymbolFlags.ValueModule) != 0 and false) {
                    const valDecl = parentSymbol.ValueDeclaration.?;
                    if (self.tree.getNode(valDecl) == .SourceFile) {
                        const symbolFile = valDecl;
                        const referenceFile = ast_utils.getSourceFileOfNode(self.tree, nodeIndex);
                        const symbolIsUmdExport = symbolFile != referenceFile;
                        if (symbolIsUmdExport) return null;
                        return symbolFile;
                    }
                }
                
                var curr = self.tree.getNodeParent(nodeIndex);
                while (curr != 0) {
                    const cNode = self.tree.getNode(curr);
                    if (cNode == .ModuleDeclaration or cNode == .EnumDeclaration) {
                        if (self.getSymbolOfDeclaration(curr) == parentSymbolIndex) {
                            return curr;
                        }
                    }
                    curr = self.tree.getNodeParent(curr);
                }
            }
        }
        return null;
    }

    pub fn getReferencedImportDeclaration(self: *ReferenceResolver, nodeIndex: ast_gen.NodeIndex) ?ast_gen.NodeIndex {
        if (self.getReferencedValueSymbol(nodeIndex, false)) |symIndex| {
            if (ast_utils.isNonLocalAlias(self.tree, symIndex, symbol.SymbolFlags.Value) and !self.isTypeOnlyAliasDeclaration(symIndex)) {
                return self.getDeclarationOfAliasSymbol(symIndex);
            }
        }
        return null;
    }

    pub fn getReferencedValueDeclaration(self: *ReferenceResolver, nodeIndex: ast_gen.NodeIndex) ?ast_gen.NodeIndex {
        if (self.getReferencedValueSymbol(nodeIndex, false)) |symIndex| {
            if (self.getExportSymbolOfValueSymbolIfExported(symIndex)) |exportSymIndex| {
                _ = self.tree.symbols.items[exportSymIndex];
                if (null) |vd| {
                    if (vd != 0) return vd;
                }
            }
        }
        return null;
    }

    pub fn getElementAccessExpressionName(self: *ReferenceResolver, expressionIndex: ast_gen.NodeIndex) []const u8 {
        if (expressionIndex != 0) {
            if (self.hooks.GetElementAccessExpressionName) |hook| {
                if (hook(expressionIndex)) |name| return name;
            }
        }
        return "";
    }

    pub fn getReferencedMemberValueDeclaration(self: *ReferenceResolver, nodeIndex: ast_gen.NodeIndex) ?ast_gen.NodeIndex {
        var sOpt = self.getResolvedSymbol(nodeIndex);
        if (sOpt == null) {
            if (self.tree.getNodeSymbol(nodeIndex)) |nodeSym| {
                sOpt = self.getMergedSymbol(nodeSym);
            }
        }
        if (sOpt) |s| {
            if (self.getExportSymbolOfValueSymbolIfExported(s)) |exportSymIndex| {
                _ = self.tree.symbols.items[exportSymIndex];
                if (null) |vd| {
                    if (vd != 0) return vd;
                }
            }
        }
        return null;
    }
};
