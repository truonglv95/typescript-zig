const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const NodeIndex = ast_gen.NodeIndex;
const types = @import("types.zig");
const TypeIndex = types.TypeIndex;
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const SymbolIndex = checker_mod.SymbolIndex;
const SignatureIndex = checker_mod.SignatureIndex;

pub fn getSymbolsInScope(c: *Checker, location: NodeIndex, meaning: u32) []const SymbolIndex {
    if ((c.ast.getNodeFlags(location) & ast.NodeFlags.InWithStatement) != 0) {
        return &[_]SymbolIndex{};
    }

    var symbols = std.AutoHashMap(SymbolIndex, void).init(c.arena.allocator());
    var isStaticSymbol = false;

    var current: NodeIndex = location;

    while (current != 0) {
        if (c.canHaveLocals(current) and c.ast.getLocals(current) != 0 and !c.ast.isGlobalSourceFile(current)) {
            const locals = c.ast.getSymbolTable(c.ast.getLocals(current));
            for (locals) |sym| {
                if ((c.getSymbolFlags(sym) & meaning) != 0) {
                    symbols.put(sym, {}) catch unreachable;
                }
            }
        }

        const kind = c.ast.getKind(current);
        if (kind == .SourceFile and c.ast.isExternalModule(current) or kind == .ModuleDeclaration) {
            const exports = c.ast.getSymbolTable(c.getSymbolOfDeclaration(current).exports);
            for (exports) |sym| {
                if (c.ast.getDeclarationOfKind(sym, .ExportSpecifier) == 0 and
                    c.ast.getDeclarationOfKind(sym, .NamespaceExport) == 0 and
                    !std.mem.eql(u8, c.ast.identifier_text(c.ast.symbol_name(sym)), "default"))
                {
                    if ((c.getSymbolFlags(sym) & (meaning & ast.SymbolFlags.ModuleMember)) != 0) {
                        symbols.put(sym, {}) catch unreachable;
                    }
                }
            }
        } else if (kind == .EnumDeclaration) {
            const exports = c.ast.getSymbolTable(c.getSymbolOfDeclaration(current).exports);
            for (exports) |sym| {
                if ((c.getSymbolFlags(sym) & (meaning & ast.SymbolFlags.EnumMember)) != 0) {
                    symbols.put(sym, {}) catch unreachable;
                }
            }
        } else if (kind == .ClassExpression) {
            const className = c.ast.classExpression_name(current);
            if (className != 0) {
                const sym = c.ast.getSymbol(current);
                if ((c.getSymbolFlags(sym) & meaning) != 0) {
                    symbols.put(sym, {}) catch unreachable;
                }
            }
            if (!isStaticSymbol) {
                const members = c.getMembersOfSymbol(c.getSymbolOfDeclaration(current));
                for (members) |sym| {
                    if ((c.getSymbolFlags(sym) & (meaning & ast.SymbolFlags.Type)) != 0) {
                        symbols.put(sym, {}) catch unreachable;
                    }
                }
            }
        } else if (kind == .ClassDeclaration or kind == .InterfaceDeclaration) {
            if (!isStaticSymbol) {
                const members = c.getMembersOfSymbol(c.getSymbolOfDeclaration(current));
                for (members) |sym| {
                    if ((c.getSymbolFlags(sym) & (meaning & ast.SymbolFlags.Type)) != 0) {
                        symbols.put(sym, {}) catch unreachable;
                    }
                }
            }
        } else if (kind == .FunctionExpression) {
            const funcName = c.ast.functionExpression_name(current);
            if (funcName != 0) {
                const sym = c.ast.getSymbol(current);
                if ((c.getSymbolFlags(sym) & meaning) != 0) {
                    symbols.put(sym, {}) catch unreachable;
                }
            }
        }

        if (c.introducesArgumentsExoticObject(current)) {
            if ((c.getSymbolFlags(c.argumentsSymbol) & meaning) != 0) {
                symbols.put(c.argumentsSymbol, {}) catch unreachable;
            }
        }

        isStaticSymbol = c.ast.isStatic(current);
        current = c.ast.getParent(current);
    }

    const globals = c.ast.getSymbolTable(c.globals);
    for (globals) |sym| {
        if ((c.getSymbolFlags(sym) & meaning) != 0) {
            symbols.put(sym, {}) catch unreachable;
        }
    }

    var result = std.ArrayList(SymbolIndex).init(c.arena.allocator());
    var it = symbols.keyIterator();
    while (it.next()) |sym| {
        const name = c.ast.identifier_text(c.ast.symbol_name(sym.*));
        if (!std.mem.eql(u8, name, "this")) {
            result.append(sym.*) catch unreachable;
        }
    }

    return result.items;
}

pub fn getExportsOfModule(c: *Checker, symbol: SymbolIndex) []const SymbolIndex {
    return c.getExportsOfModuleAsArray(symbol);
}

pub fn isValidPropertyAccess(c: *Checker, node: NodeIndex, propertyName: []const u8) bool {
    const kind = c.ast.getKind(node);
    if (kind == .PropertyAccessExpression) {
        const expr = c.ast.propertyAccessExpression_expression(node);
        const isSuper = c.ast.getKind(expr) == .SuperKeyword;
        return c.isValidPropertyAccessWithType(node, isSuper, propertyName, c.getWidenedType(c.checkExpression(expr)));
    } else if (kind == .QualifiedName) {
        const left = c.ast.qualifiedName_left(node);
        return c.isValidPropertyAccessWithType(node, false, propertyName, c.getWidenedType(c.checkExpression(left)));
    } else if (kind == .ImportType) {
        return c.isValidPropertyAccessWithType(node, false, propertyName, c.getTypeFromTypeNode(node));
    }
    unreachable;
}

pub fn isValidPropertyAccessForCompletions(c: *Checker, node: NodeIndex, t: TypeIndex, property: SymbolIndex) bool {
    const isSuper = c.ast.getKind(node) == .PropertyAccessExpression and c.ast.getKind(c.ast.propertyAccessExpression_expression(node)) == .SuperKeyword;
    return c.isPropertyAccessible(node, isSuper, false, t, property);
}

pub fn getAllPossiblePropertiesOfTypes(c: *Checker, types_arr: []const TypeIndex) []const SymbolIndex {
    const unionType = c.getUnionType(types_arr);
    if ((c.getTypeFlags(unionType) & types.TypeFlags.Union) == 0) {
        return c.getAugmentedPropertiesOfType(unionType);
    }

    var props = std.AutoHashMap(SymbolIndex, void).init(c.arena.allocator());
    for (types_arr) |memberType| {
        const augmentedProps = c.getAugmentedPropertiesOfType(memberType);
        for (augmentedProps) |p| {
            if (!props.contains(p)) {
                const prop = c.createUnionOrIntersectionProperty(unionType, c.ast.symbol_name(p), false);
                if (prop != 0) {
                    props.put(prop, {}) catch unreachable;
                }
            }
        }
    }

    var result = std.ArrayList(SymbolIndex).init(c.arena.allocator());
    var it = props.keyIterator();
    while (it.next()) |p| {
        result.append(p.*) catch unreachable;
    }
    return result.items;
}

pub fn isUnknownSymbol(c: *Checker, symbol: SymbolIndex) bool {
    return symbol == c.unknownSymbol;
}

pub fn isUndefinedSymbol(c: *Checker, symbol: SymbolIndex) bool {
    return symbol == c.undefinedSymbol;
}

pub fn isArgumentsSymbol(c: *Checker, symbol: SymbolIndex) bool {
    return symbol == c.argumentsSymbol;
}

pub fn getNonOptionalType(c: *Checker, t: TypeIndex) TypeIndex {
    return c.removeOptionalTypeMarker(t);
}

pub fn getStringIndexType(c: *Checker, t: TypeIndex) TypeIndex {
    return c.getIndexTypeOfType(t, c.stringType);
}

pub fn getNumberIndexType(c: *Checker, t: TypeIndex) TypeIndex {
    return c.getIndexTypeOfType(t, c.numberType);
}

pub fn getElementTypeOfArrayType(c: *Checker, t: TypeIndex) TypeIndex {
    return c.getElementTypeOfArrayType(t);
}

pub fn getCallSignatures(c: *Checker, t: TypeIndex) []const SignatureIndex {
    return c.getSignaturesOfType(t, 0); // SignatureKind.Call
}

pub fn getConstructSignatures(c: *Checker, t: TypeIndex) []const SignatureIndex {
    return c.getSignaturesOfType(t, 1); // SignatureKind.Construct
}

pub fn getAliasTypeArguments(c: *Checker, node: NodeIndex) []const TypeIndex {
    return c.getAliasTypeArguments(node);
}

pub fn getTypeArguments(c: *Checker, t: TypeIndex) []const TypeIndex {
    return c.getTypeArguments(t);
}

pub fn getAliasedSymbol(c: *Checker, symbol: SymbolIndex) SymbolIndex {
    return c.getAliasedSymbol(symbol);
}

pub fn resolveName(c: *Checker, name: []const u8, location: NodeIndex, meaning: u32, excludeGlobals: bool) SymbolIndex {
    return c.resolveName(location, name, meaning, 0, true, excludeGlobals);
}

pub fn getSymbol(c: *Checker, node: NodeIndex) SymbolIndex {
    return c.ast.getSymbol(node);
}

pub fn getDeclaredTypeOfSymbol(c: *Checker, symbol: SymbolIndex) TypeIndex {
    return c.getDeclaredTypeOfSymbol(symbol);
}

pub fn getTypeOfSymbolAtLocation(c: *Checker, symbol: SymbolIndex, node: NodeIndex) TypeIndex {
    return c.getTypeOfSymbolAtLocation(symbol, node);
}

pub fn getContextualType(c: *Checker, node: NodeIndex, contextFlags: u32) TypeIndex {
    return c.getContextualType(node, contextFlags);
}

pub fn getFullyQualifiedName(c: *Checker, symbol: SymbolIndex) []const u8 {
    return c.getFullyQualifiedName(symbol);
}

pub fn getSignatureFromDeclaration(c: *Checker, declaration: NodeIndex) SignatureIndex {
    return c.getSignatureFromDeclaration(declaration);
}

pub fn isOptionalParameter(c: *Checker, node: NodeIndex) bool {
    return c.isOptionalParameter(node);
}

pub fn getConstantValue(c: *Checker, node: NodeIndex) ?f64 {
    return c.getConstantValue(node);
}

pub fn isImplementationOfOverload(c: *Checker, node: NodeIndex) ?bool {
    return c.isImplementationOfOverload(node);
}

pub fn getTypeAtLocation(c: *Checker, node: NodeIndex) TypeIndex {
    return c.getTypeAtLocation(node);
}

pub fn getReturnTypeOfSignature(c: *Checker, signature: SignatureIndex) TypeIndex {
    return c.getReturnTypeOfSignature(signature);
}
