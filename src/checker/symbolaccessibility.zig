const std = @import("std");
const ast = @import("../ast/ast.zig");
const types = @import("types.zig");
const checker = @import("checker.zig");
const Checker = checker.Checker;
const printer = @import("../printer/printer.zig");
const emitresolver = @import("../printer/emitresolver.zig");

pub const SymbolTableID = u64;

pub const stKindShift = 61;
pub const stKindLocals: SymbolTableID = 0 << stKindShift;
pub const stKindExports: SymbolTableID = 1 << stKindShift;
pub const stKindMembers: SymbolTableID = 2 << stKindShift;
pub const stKindGlobals: SymbolTableID = 3 << stKindShift;
pub const stKindResolvedExports: SymbolTableID = 4 << stKindShift;
pub const stKindMask: SymbolTableID = ((1 << 3) - 1) << stKindShift; // actually (iota-1) << stKindShift in go: so 4 << 61

pub fn symbolTableIDFromLocals(node: ast.NodeIndex) SymbolTableID {
    return stKindLocals | @as(SymbolTableID, @intCast(node));
}

pub fn symbolTableIDFromExports(sym: ast.SymbolIndex) SymbolTableID {
    return stKindExports | @as(SymbolTableID, @intCast(sym));
}

pub fn symbolTableIDFromResolvedExports(sym: ast.SymbolIndex) SymbolTableID {
    return stKindResolvedExports | @as(SymbolTableID, @intCast(sym));
}

pub fn symbolTableIDFromMembers(sym: ast.SymbolIndex) SymbolTableID {
    return stKindMembers | @as(SymbolTableID, @intCast(sym));
}

pub fn symbolTableIDFromGlobals() SymbolTableID {
    return stKindGlobals;
}

pub const AccessibleSymbolChainContext = struct {
    symbol: ast.SymbolIndex,
    enclosingDeclaration: ?ast.NodeIndex,
    meaning: ast.SymbolFlags,
    useOnlyExternalAliasing: bool,
    visitedSymbolTablesMap: *std.AutoHashMapUnmanaged(ast.SymbolIndex, std.AutoHashMapUnmanaged(SymbolTableID, void)),
};

pub fn isTypeSymbolAccessible(c: *Checker, typeSymbol: ast.SymbolIndex, enclosingDeclaration: ?ast.NodeIndex) bool {
    const access = isSymbolAccessibleWorker(c, typeSymbol, enclosingDeclaration, ast.SymbolFlags.Type, false, true);
    return access.accessibility == .Accessible;
}

pub fn isValueSymbolAccessible(c: *Checker, symbol: ast.SymbolIndex, enclosingDeclaration: ?ast.NodeIndex) bool {
    const access = isSymbolAccessibleWorker(c, symbol, enclosingDeclaration, ast.SymbolFlags.Value, false, true);
    return access.accessibility == .Accessible;
}

pub fn isSymbolAccessibleByFlags(c: *Checker, symbol: ast.SymbolIndex, enclosingDeclaration: ?ast.NodeIndex, flags: ast.SymbolFlags) bool {
    const access = isSymbolAccessibleWorker(c, symbol, enclosingDeclaration, flags, false, false);
    return access.accessibility == .Accessible;
}

pub fn isSymbolAccessibleWorker(c: *Checker, symbol: ?ast.SymbolIndex, enclosingDeclaration: ?ast.NodeIndex, meaning: ast.SymbolFlags, shouldComputeAliasesToMakeVisible: bool, allowModules: bool) emitresolver.SymbolAccessibilityResult {
    _ = c; _ = symbol; _ = enclosingDeclaration; _ = meaning; _ = shouldComputeAliasesToMakeVisible; _ = allowModules;
    return .{ .accessibility = .Accessible }; // Stub
}

pub fn isAnySymbolAccessible(c: *Checker, symbols: []const ast.SymbolIndex, enclosingDeclaration: ?ast.NodeIndex, initialSymbol: ast.SymbolIndex, meaning: ast.SymbolFlags, shouldComputeAliasesToMakeVisible: bool, allowModules: bool) ?emitresolver.SymbolAccessibilityResult {
    if (symbols.len == 0) {
        return null;
    }

    var hadAccessibleChain: ?ast.SymbolIndex = null;
    var earlyModuleBail = false;

    for (symbols) |symbol| {
        const accessibleSymbolChain = c.getAccessibleSymbolChain(symbol, enclosingDeclaration, meaning, false);
        if (accessibleSymbolChain.len > 0) {
            hadAccessibleChain = symbol;
            const hasAccessibleDeclarations = c.resolver.hasVisibleDeclarations(accessibleSymbolChain[0], shouldComputeAliasesToMakeVisible);
            if (hasAccessibleDeclarations) |res| {
                return res;
            }
        }
        if (allowModules) {
            const symNode = c.binder.ast.getSymbol(symbol);
            for (symNode.declarations) |decl| {
                if (c.hasNonGlobalAugmentationExternalModuleSymbol(decl)) {
                    if (shouldComputeAliasesToMakeVisible) {
                        earlyModuleBail = true;
                        break;
                    }
                    return .{ .accessibility = .Accessible };
                }
            }
            if (earlyModuleBail) {
                continue;
            }
        }

        const containers = c.getContainersOfSymbol(symbol, enclosingDeclaration, meaning);
        var nextMeaning = meaning;
        if (initialSymbol == symbol) {
            nextMeaning = getQualifiedLeftMeaning(meaning);
        }
        const parentResult = c.isAnySymbolAccessible(containers, enclosingDeclaration, initialSymbol, nextMeaning, shouldComputeAliasesToMakeVisible, allowModules);
        if (parentResult) |res| {
            return res;
        }
    }

    if (earlyModuleBail) {
        return .{ .accessibility = .Accessible };
    }

    if (hadAccessibleChain) |hadChain| {
        var moduleName: ?[]const u8 = null;
        if (hadChain != initialSymbol) {
            moduleName = c.symbolToStringEx(hadChain, enclosingDeclaration, ast.SymbolFlags.Namespace, types.SymbolFormatFlags.AllowAnyNodeKind);
        }
        return .{
            .accessibility = .NotAccessible,
            .errorSymbolName = c.symbolToStringEx(initialSymbol, enclosingDeclaration, meaning, types.SymbolFormatFlags.AllowAnyNodeKind),
            .errorModuleName = moduleName,
        };
    }
    return null;
}

pub fn hasNonGlobalAugmentationExternalModuleSymbol(c: *Checker, declaration: ast.NodeIndex) bool {
    const a = c.binder.ast;
    return ast.isModuleWithStringLiteralName(a, declaration) or
        (a.getNodeKind(declaration) == .SourceFile and ast.isExternalOrCommonJSModule(a, declaration));
}

pub fn getQualifiedLeftMeaning(rightMeaning: ast.SymbolFlags) ast.SymbolFlags {
    if (rightMeaning.Value) {
        return ast.SymbolFlags{ .Value = true };
    }
    return ast.SymbolFlags{ .Namespace = true };
}

pub fn getWithAlternativeContainers(c: *Checker, container: ast.SymbolIndex, symbol: ast.SymbolIndex, enclosingDeclaration: ?ast.NodeIndex, meaning: ast.SymbolFlags) []const ast.SymbolIndex {
    const arena = c.allocator; // Using checker arena since we return slice
    
    var additionalContainers = std.ArrayList(ast.SymbolIndex).init(arena);
    const containerSym = c.binder.ast.getSymbol(container);
    for (containerSym.declarations) |d| {
        if (c.getFileSymbolIfFileSymbolExportEqualsContainer(d, container)) |fileSym| {
            additionalContainers.append(fileSym) catch unreachable;
        }
    }
    
    var reexportContainers: []const ast.SymbolIndex = &[_]ast.SymbolIndex{};
    if (enclosingDeclaration) |decl| {
        reexportContainers = c.getAlternativeContainingModules(symbol, decl);
    }
    
    const objectLiteralContainer = c.getVariableDeclarationOfObjectLiteral(container, meaning);
    const leftMeaning = getQualifiedLeftMeaning(meaning);
    
    if (enclosingDeclaration != null and
        (c.getSymbolFlags(container).toU32() & leftMeaning.toU32()) != 0 and
        c.getAccessibleSymbolChain(container, enclosingDeclaration, ast.SymbolFlags{ .Namespace = true }, false).len > 0) {
        
        var res = std.ArrayList(ast.SymbolIndex).init(arena);
        res.append(container) catch unreachable;
        res.appendSlice(additionalContainers.items) catch unreachable;
        res.appendSlice(reexportContainers) catch unreachable;
        if (objectLiteralContainer) |olc| {
            res.append(olc) catch unreachable;
        }
        return res.toOwnedSlice() catch unreachable;
    }
    
    var variableMatches = std.ArrayList(ast.SymbolIndex).init(arena);
    if (meaning.Value and
        (c.getSymbolFlags(container).toU32() & leftMeaning.toU32()) == 0 and
        c.getSymbolFlags(container).Type and
        (c.getDeclaredTypeOfSymbol(container).flags.toU32() & types.TypeFlags.Object.toU32()) != 0) {
        
        const Context = struct {
            c: *Checker,
            leftMeaning: ast.SymbolFlags,
            containerType: types.TypeIndex,
            matches: *std.ArrayList(ast.SymbolIndex),
        };
        var ctx = Context{
            .c = c,
            .leftMeaning = leftMeaning,
            .containerType = c.getDeclaredTypeOfSymbol(container),
            .matches = &variableMatches,
        };
        
        const Callback = struct {
            fn callback(innerCtx: *Context, t: ast.SymbolTable, tableId: SymbolTableID, ignoreQualification: bool, isLocalNameLookup: bool, node: ?ast.NodeIndex) bool {
                _ = tableId; _ = ignoreQualification; _ = isLocalNameLookup; _ = node;
                var found = false;
                var it = t.iterator();
                while (it.next()) |entry| {
                    const s = entry.value_ptr.*;
                    if ((innerCtx.c.getSymbolFlags(s).toU32() & innerCtx.leftMeaning.toU32()) != 0 and innerCtx.c.getTypeOfSymbol(s) == innerCtx.containerType) {
                        innerCtx.matches.append(s) catch unreachable;
                        found = true;
                    }
                }
                return found;
            }
        };
        _ = c.someSymbolTableInScope(enclosingDeclaration, &ctx, Callback.callback);
        c.sortSymbols(variableMatches.items);
    }
    
    var res = std.ArrayList(ast.SymbolIndex).init(arena);
    res.appendSlice(variableMatches.items) catch unreachable;
    res.appendSlice(additionalContainers.items) catch unreachable;
    res.append(container) catch unreachable;
    if (objectLiteralContainer) |olc| {
        res.append(olc) catch unreachable;
    }
    res.appendSlice(reexportContainers) catch unreachable;
    
    return res.toOwnedSlice() catch unreachable;
}

pub fn getAlternativeContainingModules(c: *Checker, symbol: ast.SymbolIndex, enclosingDeclaration: ?ast.NodeIndex) []const ast.SymbolIndex {
    if (enclosingDeclaration == null) {
        return &[_]ast.SymbolIndex{};
    }
    const decl = enclosingDeclaration.?;
    const containingFile = c.binder.ast.getSourceFileOfNode(decl);
    const id = decl;
    
    const gop = c.symbolContainerLinks.getOrPut(c.allocator, symbol) catch unreachable;
    if (!gop.found_existing) {
        gop.value_ptr.* = types.ContainingSymbolLinks{};
    }
    var links = gop.value_ptr;
    
    if (links.extendedContainersByFile == null) {
        links.extendedContainersByFile = std.AutoHashMapUnmanaged(ast.NodeIndex, []const ast.SymbolIndex).empty;
    }
    
    if (links.extendedContainersByFile.?.get(id)) |existing| {
        return existing;
    }
    
    const arena = c.allocator;
    var results = std.ArrayList(ast.SymbolIndex).init(arena);
    
    const imports = c.binder.ast.getImports(containingFile);
    if (imports.len > 0) {
        for (imports) |importRef| {
            if (ast.nodeIsSynthesized(c.binder.ast, importRef)) {
                continue;
            }
            const resolvedModule = c.resolveExternalModuleName(decl, importRef, true);
            if (resolvedModule) |rm| {
                if (c.getAliasForSymbolInContainer(rm, symbol)) |_| {
                    results.append(rm) catch unreachable;
                }
            }
        }
        if (results.items.len > 0) {
            links.extendedContainersByFile.?.put(arena, id, results.items) catch unreachable;
            return results.items;
        }
    }

    if (links.extendedContainers) |ext| {
        return ext;
    }
    
    const otherFiles = c.binder.program.sourceFiles; // Wait, program is not in binder, we'll see if it compiles
    for (otherFiles) |file| {
        if (!ast.isExternalModule(c.binder.ast, file)) {
            continue;
        }
        const sym = c.getSymbolOfDeclaration(file);
        if (c.getAliasForSymbolInContainer(sym, symbol)) |_| {
            results.append(sym) catch unreachable;
        }
    }
    links.extendedContainers = results.items;
    return results.items;
}

pub fn getVariableDeclarationOfObjectLiteral(c: *Checker, symbol: ast.SymbolIndex, meaning: ast.SymbolFlags) ?ast.SymbolIndex {
    _ = c; _ = symbol; _ = meaning;
    return null; // Stub
}

pub fn hasExternalModuleSymbol(c: *Checker, declaration: ast.NodeIndex) bool {
    _ = c; _ = declaration;
    return false; // Stub
}

pub fn getExternalModuleContainer(c: *Checker, declaration: ast.NodeIndex) ?ast.SymbolIndex {
    _ = c; _ = declaration;
    return null; // Stub
}

pub fn getFileSymbolIfFileSymbolExportEqualsContainer(c: *Checker, d: ast.NodeIndex, container: ast.SymbolIndex) ?ast.SymbolIndex {
    _ = c; _ = d; _ = container;
    return null; // Stub
}

pub fn getContainersOfSymbol(c: *Checker, symbol: ast.SymbolIndex, enclosingDeclaration: ?ast.NodeIndex, meaning: ast.SymbolFlags) []const ast.SymbolIndex {
    _ = c; _ = symbol; _ = enclosingDeclaration; _ = meaning;
    return &[_]ast.SymbolIndex{}; // Stub
}

pub fn getAliasForSymbolInContainer(c: *Checker, container: ast.SymbolIndex, symbol: ast.SymbolIndex) ?ast.SymbolIndex {
    _ = c; _ = container; _ = symbol;
    return null; // Stub
}

pub fn getAccessibleSymbolChain(c: *Checker, symbol: ast.SymbolIndex, enclosingDeclaration: ?ast.NodeIndex, meaning: ast.SymbolFlags, useOnlyExternalAliasing: bool) []const ast.SymbolIndex {
    _ = c; _ = symbol; _ = enclosingDeclaration; _ = meaning; _ = useOnlyExternalAliasing;
    return &[_]ast.SymbolIndex{}; // Stub
}

pub fn getAccessibleSymbolChainEx(c: *Checker, ctx: AccessibleSymbolChainContext) []const ast.SymbolIndex {
    _ = c; _ = ctx;
    return &[_]ast.SymbolIndex{}; // Stub
}

pub fn getAccessibleSymbolChainFromSymbolTable(c: *Checker, ctx: AccessibleSymbolChainContext, t: ast.SymbolTable, tableId: SymbolTableID, ignoreQualification: bool, isLocalNameLookup: bool) []const ast.SymbolIndex {
    _ = c; _ = ctx; _ = t; _ = tableId; _ = ignoreQualification; _ = isLocalNameLookup;
    return &[_]ast.SymbolIndex{}; // Stub
}

pub fn getSymbolTableAliases(c: *Checker, symbols: ast.SymbolTable, tableId: SymbolTableID) []const ast.SymbolIndex {
    _ = c; _ = symbols; _ = tableId;
    return &[_]ast.SymbolIndex{}; // Stub
}

pub fn trySymbolTable(c: *Checker, ctx: AccessibleSymbolChainContext, symbols: ast.SymbolTable, tableId: SymbolTableID, ignoreQualification: bool, isLocalNameLookup: bool) []const ast.SymbolIndex {
    _ = c; _ = ctx; _ = symbols; _ = tableId; _ = ignoreQualification; _ = isLocalNameLookup;
    return &[_]ast.SymbolIndex{}; // Stub
}

pub fn compareSymbolChainsWorker(c: *Checker, a: []const ast.SymbolIndex, b: []const ast.SymbolIndex) i32 {
    _ = c; _ = a; _ = b;
    return 0; // Stub
}

pub fn isUMDExportSymbol(c: *Checker, symbol: ast.SymbolIndex) bool {
    _ = c; _ = symbol;
    return false; // Stub
}

pub fn isNamespaceReexportDeclaration(c: *Checker, node: ast.NodeIndex) bool {
    _ = c; _ = node;
    return false; // Stub
}

pub fn getCandidateListForSymbol(c: *Checker, ctx: AccessibleSymbolChainContext, symbolFromSymbolTable: ast.SymbolIndex, resolvedImportedSymbol: ast.SymbolIndex, ignoreQualification: bool) []const ast.SymbolIndex {
    _ = c; _ = ctx; _ = symbolFromSymbolTable; _ = resolvedImportedSymbol; _ = ignoreQualification;
    return &[_]ast.SymbolIndex{}; // Stub
}

pub fn isAccessible(c: *Checker, ctx: AccessibleSymbolChainContext, symbolFromSymbolTable: ast.SymbolIndex, resolvedAliasSymbol: ?ast.SymbolIndex, ignoreQualification: bool) bool {
    _ = c; _ = ctx; _ = symbolFromSymbolTable; _ = resolvedAliasSymbol; _ = ignoreQualification;
    return false; // Stub
}

pub fn canQualifySymbol(c: *Checker, ctx: AccessibleSymbolChainContext, symbolFromSymbolTable: ast.SymbolIndex, meaning: ast.SymbolFlags) bool {
    _ = c; _ = ctx; _ = symbolFromSymbolTable; _ = meaning;
    return false; // Stub
}

pub fn needsQualification(c: *Checker, symbol: ast.SymbolIndex, enclosingDeclaration: ?ast.NodeIndex, meaning: ast.SymbolFlags) bool {
    _ = c; _ = symbol; _ = enclosingDeclaration; _ = meaning;
    return false; // Stub
}

pub fn isPropertyOrMethodDeclarationSymbol(c: *Checker, symbol: ast.SymbolIndex) bool {
    _ = c; _ = symbol;
    return false; // Stub
}

pub fn someSymbolTableInScope(c: *Checker, enclosingDeclaration: ?ast.NodeIndex, callback: *const fn(ast.SymbolTable, SymbolTableID, bool, bool, ?ast.NodeIndex) bool) bool {
    _ = c; _ = enclosingDeclaration; _ = callback;
    return false; // Stub
}

pub fn getClassExpressionNameTable(c: *Checker, location: ast.NodeIndex) ?ast.SymbolTable {
    _ = c; _ = location;
    return null; // Stub
}

pub fn isSymbolAccessible(c: *Checker, symbol: ast.SymbolIndex, enclosingDeclaration: ?ast.NodeIndex, meaning: ast.SymbolFlags, shouldComputeAliasesToMakeVisible: bool) emitresolver.SymbolAccessibilityResult {
    return isSymbolAccessibleWorker(c, symbol, enclosingDeclaration, meaning, shouldComputeAliasesToMakeVisible, true);
}
