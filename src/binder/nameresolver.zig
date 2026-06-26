const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const symbol = @import("../ast/symbol.zig");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const core = @import("../core/core.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const binder = @import("binder.zig");

pub const NameResolver = struct {
    ast: *ast.Ast,
    binder: *binder.Binder,
    compilerOptions: ?*core.CompilerOptions,

    Globals: ?*symbol.SymbolTable = null,
    ArgumentsSymbol: ?ast_gen.SymbolIndex = null,
    RequireSymbol: ?ast_gen.SymbolIndex = null,

    GetSymbolOfDeclaration: ?*const fn (self: *NameResolver, node: ast_gen.NodeIndex) ?ast_gen.SymbolIndex = null,
    Error: ?*const fn (self: *NameResolver, location: ast_gen.NodeIndex, message: *const diagnostics.Message, args: []const []const u8) ?diagnostics.Diagnostic = null,
    Lookup: ?*const fn (self: *NameResolver, symbols: *symbol.SymbolTable, name: []const u8, meaning: u32) ?ast_gen.SymbolIndex = null,
    SymbolReferenced: ?*const fn (self: *NameResolver, sym: ast_gen.SymbolIndex, meaning: u32) void = null,
    SetRequiresScopeChangeCache: ?*const fn (self: *NameResolver, node: ast_gen.NodeIndex, value: ?bool) void = null,
    GetRequiresScopeChangeCache: ?*const fn (self: *NameResolver, node: ast_gen.NodeIndex) ?bool = null,
    OnPropertyWithInvalidInitializer: ?*const fn (self: *NameResolver, location: ast_gen.NodeIndex, name: []const u8, declaration: ast_gen.NodeIndex, result: ?ast_gen.SymbolIndex) bool = null,
    OnFailedToResolveSymbol: ?*const fn (self: *NameResolver, location: ast_gen.NodeIndex, name: []const u8, meaning: u32, nameNotFoundMessage: *const diagnostics.Message) void = null,
    OnSuccessfullyResolvedSymbol: ?*const fn (self: *NameResolver, location: ast_gen.NodeIndex, result: ast_gen.SymbolIndex, meaning: u32, lastLocation: ast_gen.NodeIndex, associatedDeclarationForContainingInitializerOrBindingName: ast_gen.NodeIndex, withinDeferredContext: bool) void = null,

    pub fn init(a: *ast.Ast, b: *binder.Binder, opts: ?*core.CompilerOptions) NameResolver {
        return .{
            .ast = a,
            .binder = b,
            .compilerOptions = opts,
        };
    }

    pub fn resolve(
        self: *NameResolver,
        startLocation: ast_gen.NodeIndex,
        name: []const u8,
        meaning: u32,
        nameNotFoundMessage: ?*const diagnostics.Message,
        isUse: bool,
        excludeGlobals: bool,
    ) ?ast_gen.SymbolIndex {
        var result: ?ast_gen.SymbolIndex = null;
        var lastLocation: ast_gen.NodeIndex = 0;
        var lastSelfReferenceLocation: ast_gen.NodeIndex = 0;
        var propertyWithInvalidInitializer: ast_gen.NodeIndex = 0;
        var associatedDeclarationForContainingInitializerOrBindingName: ast_gen.NodeIndex = 0;
        var withinDeferredContext: bool = false;
        var grandparent: ast_gen.NodeIndex = 0;
        const originalLocation = startLocation;
        const nameIsConst = std.mem.eql(u8, name, "const");

        var location = startLocation;

        loop: while (location != 0) {
            if (nameIsConst and @import("../ast/ast_utils.zig").isConstAssertion(self.ast, location)) {
                return null;
            }

            if (ast_utils.isModuleOrEnumDeclaration(self.ast, location) and lastLocation != 0 and ast_utils.getNameOfNode(self.ast, location) == lastLocation) {
                lastLocation = location;
                location = self.ast.getNodeParent(location);
                continue;
            }
            if (self.binder.nodeLocals.getPtr(location)) |locals| {
                if (!ast_utils.isGlobalSourceFile(self.ast, location) or self.Globals == null) {
                    result = self.lookup(&locals.unmanaged, name, meaning);
                    if (result != null) {
                        var useResult = true;
                        if (ast_utils.isFunctionLike(std.meta.activeTag(self.ast.getNode(location))) and lastLocation != 0 and lastLocation != ast_utils.getBodyOfNode(self.ast, location)) {
                            const resultSym = self.binder.symbols.items[result.?];
                            const lastLocationData = self.ast.getNode(lastLocation);
                            const lastLocationKind = std.meta.activeTag(lastLocationData);
                            const lastLocationFlags = self.ast.getNodeFlags(lastLocation);

                            if ((meaning & resultSym.Flags & symbol.SymbolFlags.Type) != 0 and lastLocationKind != .JSDoc) {
                                useResult = (resultSym.Flags & symbol.SymbolFlags.TypeParameter) != 0 and
                                    ((lastLocationFlags & ast_utils.NodeFlags.Synthesized) != 0 or
                                        lastLocation == ast_utils.getTypeOfNode(self.ast, location) or
                                        lastLocationKind == .Parameter or
                                        lastLocationKind == .JSDocParameterTag or
                                        lastLocationKind == .JSDocReturnTag or
                                        lastLocationKind == .TypeParameter);
                            }
                            if ((meaning & resultSym.Flags & symbol.SymbolFlags.Variable) != 0) {
                                if (self.useOuterVariableScopeInParameter(result.?, location, lastLocation)) {
                                    useResult = false;
                                } else if ((resultSym.Flags & symbol.SymbolFlags.FunctionScopedVariable) != 0) {
                                    useResult = lastLocationKind == .Parameter or
                                        (lastLocationFlags & ast_utils.NodeFlags.Synthesized) != 0 or
                                        (lastLocation == ast_utils.getTypeOfNode(self.ast, location) and ast_utils.findAncestor(self.ast, resultSym.ValueDeclaration, ast_utils.isParameterDeclaration) != 0);
                                }
                            }
                        } else if (std.meta.activeTag(self.ast.getNode(location)) == .ConditionalType) {
                            useResult = lastLocation == ast_utils.getTrueTypeOfConditionalType(self.ast, location);
                        }

                        if (useResult) {
                            break :loop;
                        }
                        result = null;
                    }
                }
            }

            withinDeferredContext = withinDeferredContext or getIsDeferredContext(self.ast, location, lastLocation);

            const locationKind = std.meta.activeTag(self.ast.getNode(location));
            switch (locationKind) {
                .SourceFile, .ModuleDeclaration => {
                    if (locationKind == .SourceFile and !ast_utils.isExternalOrCommonJSModule(self.ast, location)) {
                        // skip switch, continue to next parent
                    } else {
                        const moduleSymbol = self.getSymbolOfDeclaration(location);
                        if (moduleSymbol != null) {
                            if (self.binder.symbolExports.getPtr(moduleSymbol.?)) |moduleExports| {
                                var skipNormalLookup = false;
                                if (ast_utils.isSourceFile(self.ast, location) or (ast_utils.isModuleDeclaration(self.ast, location) and (ast_utils.getNodeFlags(self.ast, location) & ast_utils.NodeFlags.Ambient) != 0 and !ast_utils.isGlobalScopeAugmentation(self.ast, location))) {
                                    result = moduleExports.get("default");
                                    if (result != null) {
                                        const localSymbol = getLocalSymbolForExportDefault(self.ast, self.binder, result.?);
                                        if (localSymbol != null) {
                                            const resSym = self.binder.symbols.items[result.?];
                                            const locSym = self.binder.symbols.items[localSymbol.?];
                                            if ((resSym.Flags & meaning) != 0 and std.mem.eql(u8, locSym.Name, name)) {
                                                break :loop;
                                            }
                                        }
                                        result = null;
                                    }

                                    if (moduleExports.get(name)) |moduleExportIdx| {
                                        const moduleExport = self.binder.symbols.items[moduleExportIdx];
                                        if (moduleExport.Flags == symbol.SymbolFlags.Alias and (ast_utils.getDeclarationOfKind(self.ast, moduleExportIdx, .ExportSpecifier) != 0 or ast_utils.getDeclarationOfKind(self.ast, moduleExportIdx, .NamespaceExport) != 0)) {
                                            skipNormalLookup = true;
                                        }
                                    }
                                }

                                if (!skipNormalLookup and !std.mem.eql(u8, name, "default")) {
                                    result = self.lookup(&moduleExports.unmanaged, name, meaning & (symbol.SymbolFlags.Value | symbol.SymbolFlags.Type | symbol.SymbolFlags.Namespace | symbol.SymbolFlags.Alias));
                                    if (result != null) {
                                        const resSym = self.binder.symbols.items[result.?];
                                        if (ast_utils.isSourceFile(self.ast, location) and ast_utils.getCommonJSModuleIndicator(self.ast, location) != 0 and (resSym.Flags & symbol.SymbolFlags.Type) == 0) {
                                            result = null;
                                        } else {
                                            break :loop;
                                        }
                                    }
                                }
                            }
                        }
                    }
                },
                .EnumDeclaration => {
                    const enumSymbol = self.getSymbolOfDeclaration(location);
                    if (enumSymbol != null) {
                        if (self.binder.symbolExports.getPtr(enumSymbol.?)) |exports| {
                            result = self.lookup(&exports.unmanaged, name, meaning & symbol.SymbolFlags.EnumMember);
                            if (result != null) {
                                if (nameNotFoundMessage != null and (if (self.compilerOptions) |opts| opts.isolatedModules orelse false else false) and (self.ast.getNodeFlags(location) & ast_utils.NodeFlags.Ambient) == 0) {
                                    const resSym = self.binder.symbols.items[result.?];
                                    if (ast_utils.getSourceFileOfNode(self.ast, location) != ast_utils.getSourceFileOfNode(self.ast, resSym.ValueDeclaration orelse 0)) {
                                        const isolatedModulesLikeFlagName = if ((if (self.compilerOptions) |opts| opts.verbatimModuleSyntax orelse false else false)) "verbatimModuleSyntax" else "isolatedModules";
                                        const enumSymStr = self.binder.symbols.items[enumSymbol.?].Name;
                                        self.reportError(originalLocation, &diagnostics.generated.Cannot_access_0_from_another_file_without_qualification_when_1_is_enabled_Use_2_instead, &[_][]const u8{ name, isolatedModulesLikeFlagName, enumSymStr });
                                    }
                                }
                                break :loop;
                            }
                        }
                    }
                },
                .PropertyDeclaration => {
                    if (!ast_utils.isStatic(self.ast, location)) {
                        const parent = self.ast.parents.items[location];
                        const ctor = ast_utils.findConstructorDeclaration(self.ast, parent);
                        if (ctor != 0) {
                            if (self.binder.nodeLocals.getPtr(ctor)) |ctorLocals| {
                                if (self.lookup(&ctorLocals.unmanaged, name, meaning & symbol.SymbolFlags.Value) != null) {
                                    propertyWithInvalidInitializer = location;
                                }
                            }
                        }
                    }
                },
                .ClassDeclaration, .ClassExpression, .InterfaceDeclaration => {
                    const sym = self.getSymbolOfDeclaration(location);
                    if (sym != null) {
                        if (self.binder.symbolMembers.getPtr(sym.?)) |members| {
                            result = self.lookup(&members.unmanaged, name, meaning & symbol.SymbolFlags.Type);
                            if (result != null) {
                                if (!isTypeParameterSymbolDeclaredInContainer(self.ast, self.binder, result.?, location)) {
                                    result = null;
                                } else {
                                    if (lastLocation != 0 and ast_utils.isStatic(self.ast, lastLocation)) {
                                        if (nameNotFoundMessage != null) {
                                            self.reportError(originalLocation, &diagnostics.generated.Static_members_cannot_reference_class_type_parameters, &[_][]const u8{});
                                        }
                                        return null;
                                    }
                                    break :loop;
                                }
                            }
                        }
                    }

                    if (locationKind == .ClassExpression and (meaning & symbol.SymbolFlags.Class) != 0) {
                        const className = ast_utils.getNameOfNode(self.ast, location);
                        if (className != 0 and std.mem.eql(u8, name, ast_utils.getTextOfNode(self.ast, className))) {
                            result = ast_utils.getSymbolOfNode(self.ast, location);
                            break :loop;
                        }
                    }
                },
                .ExpressionWithTypeArguments => {
                    const parent = self.ast.parents.items[location];
                    if (lastLocation == ast_utils.getExpressionOfNode(self.ast, location) and ast_utils.isHeritageClause(self.ast, parent) and ast_utils.getTokenOfHeritageClause(self.ast, parent) == .ExtendsKeyword) {
                        const container = self.ast.parents.items[parent];
                        if (ast_utils.isClassLike(self.ast, container)) {
                            const sym = self.getSymbolOfDeclaration(container);
                            if (sym != null) {
                                if (self.binder.symbolMembers.getPtr(sym.?)) |members| {
                                    result = self.lookup(&members.unmanaged, name, meaning & symbol.SymbolFlags.Type);
                                    if (result != null) {
                                        if (nameNotFoundMessage != null) {
                                            self.reportError(originalLocation, &diagnostics.generated.Base_class_expressions_cannot_reference_class_type_parameters, &[_][]const u8{});
                                        }
                                        return null;
                                    }
                                }
                            }
                        }
                    }
                },
                .ComputedPropertyName => {
                    const parent = self.ast.parents.items[location];
                    grandparent = self.ast.parents.items[parent];
                    if (ast_utils.isClassLike(self.ast, grandparent) or ast_utils.isInterfaceDeclaration(self.ast, grandparent)) {
                        const sym = self.getSymbolOfDeclaration(grandparent);
                        if (sym != null) {
                            if (self.binder.symbolMembers.getPtr(sym.?)) |members| {
                                result = self.lookup(&members.unmanaged, name, meaning & symbol.SymbolFlags.Type);
                                if (result != null) {
                                    if (nameNotFoundMessage != null) {
                                        self.reportError(originalLocation, &diagnostics.generated.A_computed_property_name_cannot_reference_a_type_parameter_from_its_containing_type, &[_][]const u8{});
                                    }
                                    return null;
                                }
                            }
                        }
                    }
                },
                .MethodDeclaration, .Constructor, .GetAccessor, .SetAccessor, .FunctionDeclaration => {
                    if ((meaning & symbol.SymbolFlags.Variable) != 0 and std.mem.eql(u8, name, "arguments")) {
                        result = self.getArgumentsSymbol();
                        break :loop;
                    }
                },
                .FunctionExpression => {
                    if ((meaning & symbol.SymbolFlags.Variable) != 0 and std.mem.eql(u8, name, "arguments")) {
                        result = self.getArgumentsSymbol();
                        break :loop;
                    }
                    if ((meaning & symbol.SymbolFlags.Function) != 0) {
                        const functionName = ast_utils.getNameOfNode(self.ast, location);
                        if (functionName != 0 and std.mem.eql(u8, name, ast_utils.getTextOfNode(self.ast, functionName))) {
                            result = ast_utils.getSymbolOfNode(self.ast, location);
                            break :loop;
                        }
                    }
                },
                .Decorator => {
                    const parent = self.ast.parents.items[location];
                    if (parent != 0 and std.meta.activeTag(self.ast.getNode(parent)) == .Parameter) {
                        location = parent;
                    }
                    const newParent = self.ast.parents.items[location];
                    if (newParent != 0 and (ast_utils.isClassElement(self.ast, newParent) or std.meta.activeTag(self.ast.getNode(newParent)) == .ClassDeclaration)) {
                        location = newParent;
                    }
                },
                .Parameter => {
                    const paramName = ast_utils.getNameOfNode(self.ast, location);
                    const initializer = ast_utils.getInitializerOfNode(self.ast, location);
                    if (lastLocation != 0 and (lastLocation == initializer or (lastLocation == paramName and ast_utils.isBindingPattern(self.ast, lastLocation)))) {
                        if (associatedDeclarationForContainingInitializerOrBindingName == 0) {
                            associatedDeclarationForContainingInitializerOrBindingName = location;
                        }
                    }
                },
                .BindingElement => {
                    const beName = ast_utils.getNameOfNode(self.ast, location);
                    const initializer = ast_utils.getInitializerOfNode(self.ast, location);
                    if (lastLocation != 0 and (lastLocation == initializer or (lastLocation == beName and ast_utils.isBindingPattern(self.ast, lastLocation)))) {
                        if (ast_utils.isPartOfParameterDeclaration(self.ast, location) and associatedDeclarationForContainingInitializerOrBindingName == 0) {
                            associatedDeclarationForContainingInitializerOrBindingName = location;
                        }
                    }
                },
                .InferType => {
                    if ((meaning & symbol.SymbolFlags.TypeParameter) != 0) {
                        const typeParam = ast_utils.getTypeParameterOfNode(self.ast, location);
                        const paramName = ast_utils.getNameOfNode(self.ast, typeParam);
                        if (paramName != 0 and std.mem.eql(u8, name, ast_utils.getTextOfNode(self.ast, paramName))) {
                            result = ast_utils.getSymbolOfNode(self.ast, typeParam);
                            break :loop;
                        }
                    }
                },
                .ExportSpecifier => {
                    const propName = ast_utils.getPropertyNameOfNode(self.ast, location);
                    const parent = self.ast.parents.items[location];
                    const parentParent = if (parent != 0) self.ast.parents.items[parent] else 0;
                    if (lastLocation != 0 and lastLocation == propName and parentParent != 0 and ast_utils.getModuleSpecifierOfNode(self.ast, parentParent) != 0) {
                        location = self.ast.parents.items[parentParent];
                    }
                },
                else => {},
            }

            if (isSelfReferenceLocation(self.ast, location, lastLocation)) {
                lastSelfReferenceLocation = location;
            }
            lastLocation = location;
            location = self.ast.parents.items[location];
        }

        if (isUse and result != null and (lastSelfReferenceLocation == 0 or result.? != ast_utils.getSymbolOfNode(self.ast, lastSelfReferenceLocation))) {
            if (self.SymbolReferenced) |cb| {
                cb(self, result.?, meaning);
            }
        }

        if (result == null and !excludeGlobals) {
            if (self.Globals) |g| {
                result = self.lookup(g, name, meaning | symbol.SymbolFlags.GlobalLookup);
            }
        }

        if (result == null) {
            if (originalLocation != 0 and ast_utils.isInJSFile(self.ast, originalLocation)) {
                const parent = self.ast.parents.items[originalLocation];
                if (parent != 0 and ast_utils.isRequireCall(self.ast, parent, false)) {
                    return self.RequireSymbol;
                }
            }
        }

        if (nameNotFoundMessage != null) {
            if (propertyWithInvalidInitializer != 0 and self.OnPropertyWithInvalidInitializer != null) {
                if (self.OnPropertyWithInvalidInitializer.?(self, originalLocation, name, propertyWithInvalidInitializer, result)) {
                    return null;
                }
            }
            if (result == null) {
                if (self.OnFailedToResolveSymbol) |cb| {
                    cb(self, originalLocation, name, meaning, nameNotFoundMessage.?);
                }
            } else {
                if (self.OnSuccessfullyResolvedSymbol) |cb| {
                    cb(self, originalLocation, result.?, meaning, lastLocation, associatedDeclarationForContainingInitializerOrBindingName, withinDeferredContext);
                }
            }
        }

        return result;
    }

    fn useOuterVariableScopeInParameter(self: *NameResolver, result: ast_gen.SymbolIndex, location: ast_gen.NodeIndex, lastLocation: ast_gen.NodeIndex) bool {
        if (ast_utils.isParameterDeclaration(self.ast, lastLocation)) {
            const body = ast_utils.getBodyOfNode(self.ast, location);
            const resSym = self.binder.symbols.items[result];
            if (body != 0 and resSym.ValueDeclaration != 0) {
                const resPos = ast_utils.getPosOfNode(self.ast, resSym.ValueDeclaration);
                const resEnd = ast_utils.getEndOfNode(self.ast, resSym.ValueDeclaration);
                const bodyPos = ast_utils.getPosOfNode(self.ast, body);
                const bodyEnd = ast_utils.getEndOfNode(self.ast, body);

                if (resPos >= bodyPos and resEnd <= bodyEnd) {
                    const functionLocation = location;
                    var declarationRequiresScopeChange: ?bool = null;

                    if (self.GetRequiresScopeChangeCache) |cb| {
                        declarationRequiresScopeChange = cb(self, functionLocation);
                    }

                    if (declarationRequiresScopeChange == null) {
                        const params = ast_utils.getParametersOfNode(self.ast, functionLocation);
                        var someRequires = false;
                        for (params) |param| {
                            if (self.requiresScopeChange(param)) {
                                someRequires = true;
                                break;
                            }
                        }
                        declarationRequiresScopeChange = someRequires;

                        if (self.SetRequiresScopeChangeCache) |cb| {
                            cb(self, functionLocation, declarationRequiresScopeChange);
                        }
                    }

                    return declarationRequiresScopeChange != true;
                }
            }
        }
        return false;
    }

    fn requiresScopeChange(self: *NameResolver, node: ast_gen.NodeIndex) bool {
        const name = ast_utils.getNameOfNode(self.ast, node);
        if (self.requiresScopeChangeWorker(name)) return true;
        const initializer = ast_utils.getInitializerOfNode(self.ast, node);
        if (initializer != 0 and self.requiresScopeChangeWorker(initializer)) return true;
        return false;
    }

    fn requiresScopeChangeWorker(self: *NameResolver, node: ast_gen.NodeIndex) bool {
        if (node == 0) return false;
        const nodeKind = std.meta.activeTag(self.ast.getNode(node));
        switch (nodeKind) {
            .ArrowFunction, .FunctionExpression, .FunctionDeclaration, .Constructor => return false,
            .MethodDeclaration, .GetAccessor, .SetAccessor, .PropertyAssignment => return self.requiresScopeChangeWorker(ast_utils.getNameOfNode(self.ast, node)),
            .PropertyDeclaration => {
                if (ast_utils.hasStaticModifier(self.ast, node)) {
                    return !(if (self.compilerOptions) |opts| opts.useDefineForClassFields orelse false else false);
                }
                return self.requiresScopeChangeWorker(ast_utils.getNameOfNode(self.ast, node));
            },
            else => {
                if (ast_utils.isNullishCoalesce(self.ast, node) or ast_utils.isOptionalChain(self.ast, node)) {
                    return @intFromEnum(if (self.compilerOptions) |opts| opts.target orelse core.ScriptTarget.ES5 else core.ScriptTarget.ES5) < @intFromEnum(core.ScriptTarget.ES2020);
                }
                if (ast_utils.isBindingElement(self.ast, node) and ast_utils.getDotDotDotTokenOfNode(self.ast, node) != 0 and ast_utils.isObjectBindingPattern(self.ast, self.ast.parents.items[node])) {
                    return @intFromEnum(if (self.compilerOptions) |opts| opts.target orelse core.ScriptTarget.ES5 else core.ScriptTarget.ES5) < @intFromEnum(core.ScriptTarget.ES2017);
                }
                if (ast_utils.isTypeNode(self.ast, node)) {
                    return false;
                }
                return ast_utils.forEachChildBool(self.ast, node, self, struct {
                    fn visit(ctx: *NameResolver, child: ast_gen.NodeIndex) bool {
                        return ctx.requiresScopeChangeWorker(child);
                    }
                }.visit);
            },
        }
    }

    fn reportError(self: *NameResolver, location: ast_gen.NodeIndex, message: *const diagnostics.Message, args: []const []const u8) void {
        if (self.Error) |cb| {
            _ = cb(self, location, message, args);
        }
    }

    pub fn getSymbolOfDeclaration(self: *NameResolver, node: ast_gen.NodeIndex) ?ast_gen.SymbolIndex {
        if (self.GetSymbolOfDeclaration) |cb| {
            return cb(self, node);
        }
        return self.ast.getNodeSymbol(node);
    }

    pub fn lookup(self: *NameResolver, symbols: *symbol.SymbolTable, name: []const u8, meaning: u32) ?ast_gen.SymbolIndex {
        if (self.Lookup) |cb| {
            return cb(self, symbols, name, meaning);
        }
        if (meaning != 0) {
            if (symbols.get(name)) |symIdx| {
                const sym = self.binder.symbols.items[symIdx];
                if ((sym.Flags & meaning) != 0) {
                    return symIdx;
                }
            }
        }
        return null;
    }

    pub fn getArgumentsSymbol(self: *NameResolver) ast_gen.SymbolIndex {
        if (self.ArgumentsSymbol == null) {
            var sym = std.mem.zeroes(symbol.Symbol);
            sym.Name = "arguments";
            sym.Flags = symbol.SymbolFlags.Property | symbol.SymbolFlags.Transient;
            self.binder.symbols.append(self.binder.allocator, sym) catch unreachable;
            self.ArgumentsSymbol = @as(u32, @intCast(self.binder.symbols.items.len - 1));
        }
        return self.ArgumentsSymbol.?;
    }
};

fn getLocalSymbolForExportDefault(a: *ast.Ast, b: *binder.Binder, symIndex: ast_gen.SymbolIndex) ?ast_gen.SymbolIndex {
    if (!isExportDefaultSymbol(a, b, symIndex)) {
        return null;
    }
    const sym = b.symbols.items[symIndex];
    if (sym.Declarations.items.len == 0) return null;

    for (sym.Declarations.items) |decl| {
        const localSym = ast_utils.getLocalSymbolOfNode(a, decl);
        if (localSym != 0) {
            return localSym;
        }
    }
    return null;
}

fn isExportDefaultSymbol(a: *ast.Ast, b: *binder.Binder, symIndex: ast_gen.SymbolIndex) bool {
    if (symIndex == 0) return false;
    const sym = b.symbols.items[symIndex];
    if (sym.Declarations.items.len > 0) {
        return ast_utils.hasSyntacticModifier(a, sym.Declarations.items[0], ast_utils.ModifierFlags.Default);
    }
    return false;
}

fn getIsDeferredContext(a: *ast.Ast, location: ast_gen.NodeIndex, lastLocation: ast_gen.NodeIndex) bool {
    const kind = std.meta.activeTag(a.getNode(location));
    if (kind != .ArrowFunction and kind != .FunctionExpression) {
        return ast_utils.isTypeQueryNode(a, location) or
            ((ast_utils.isFunctionLikeDeclaration(a, location) or (kind == .PropertyDeclaration and !ast_utils.isStatic(a, location))) and
                (lastLocation == 0 or lastLocation != ast_utils.getNameOfNode(a, location)));
    }
    if (lastLocation != 0 and lastLocation == ast_utils.getNameOfNode(a, location)) {
        return false;
    }
    if (ast_utils.getAsteriskTokenOfNode(a, location) != 0 or ast_utils.hasSyntacticModifier(a, location, ast_utils.ModifierFlags.Async)) {
        return true;
    }
    return ast_utils.getImmediatelyInvokedFunctionExpression(a, location) == 0;
}

fn isTypeParameterSymbolDeclaredInContainer(a: *ast.Ast, b: *binder.Binder, symIndex: ast_gen.SymbolIndex, container: ast_gen.NodeIndex) bool {
    const sym = b.symbols.items[symIndex];
    for (sym.Declarations.items) |decl| {
        if (std.meta.activeTag(a.getNode(decl)) == .TypeParameter) {
            const parent = a.parents.items[decl];
            if (parent == container) {
                return true;
            }
        }
    }
    return false;
}

fn isSelfReferenceLocation(a: *ast.Ast, node: ast_gen.NodeIndex, lastLocation: ast_gen.NodeIndex) bool {
    const kind = std.meta.activeTag(a.getNode(node));
    switch (kind) {
        .Parameter => return lastLocation != 0 and lastLocation == ast_utils.getNameOfNode(a, node),
        .FunctionDeclaration, .ClassDeclaration, .InterfaceDeclaration, .EnumDeclaration, .TypeAliasDeclaration, .JSTypeAliasDeclaration, .ModuleDeclaration => return true,
        else => return false,
    }
}
