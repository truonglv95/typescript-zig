const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const types = @import("types.zig");
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const nodebuilderimpl = @import("nodebuilderimpl.zig");
const NodeBuilderImpl = nodebuilderimpl.NodeBuilderImpl;
const factory_pkg = @import("../printer/factory.zig");
const core = @import("../core/core.zig");

// scope management for nodebuilder

pub const CloneContextScope = struct {
    old_typeParameterNames: std.AutoHashMapUnmanaged(types.TypeIndex, ast_gen.NodeIndex),
    old_typeParameterNamesByText: std.StringHashMapUnmanaged(void),
    old_typeParameterNamesByTextNextNameCount: std.StringHashMapUnmanaged(usize),
    old_typeParameterSymbolList: std.AutoHashMapUnmanaged(ast_gen.SymbolIndex, void),

    pub fn restore(self: *const CloneContextScope, b: *NodeBuilderImpl) void {
        b.ctx.typeParameterNames = self.old_typeParameterNames;
        b.ctx.typeParameterNamesByText = self.old_typeParameterNamesByText;
        b.ctx.typeParameterNamesByTextNextNameCount = self.old_typeParameterNamesByTextNextNameCount;
        b.ctx.typeParameterSymbolList = self.old_typeParameterSymbolList;
    }
};

pub fn cloneNodeBuilderContext(b: *NodeBuilderImpl) !CloneContextScope {
    const scope = CloneContextScope{
        .old_typeParameterNames = b.ctx.typeParameterNames,
        .old_typeParameterNamesByText = b.ctx.typeParameterNamesByText,
        .old_typeParameterNamesByTextNextNameCount = b.ctx.typeParameterNamesByTextNextNameCount,
        .old_typeParameterSymbolList = b.ctx.typeParameterSymbolList,
    };

    b.ctx.typeParameterNames = try b.ctx.typeParameterNames.clone(b.c.allocator);
    b.ctx.typeParameterNamesByText = try b.ctx.typeParameterNamesByText.clone(b.c.allocator);
    b.ctx.typeParameterNamesByTextNextNameCount = try b.ctx.typeParameterNamesByTextNextNameCount.clone(b.c.allocator);
    b.ctx.typeParameterSymbolList = try b.ctx.typeParameterSymbolList.clone(b.c.allocator);

    return scope;
}

pub const SymbolTypeScope = struct {
    old_type: ?types.TypeIndex,
    symbol: ast_gen.SymbolIndex,

    pub fn restore(self: *const SymbolTypeScope, b: *NodeBuilderImpl) void {
        if (self.old_type) |old| {
            b.ctx.enclosingSymbolTypes.put(b.c.allocator, self.symbol, old) catch unreachable;
        } else {
            _ = b.ctx.enclosingSymbolTypes.remove(self.symbol);
        }
    }
};

pub fn addSymbolTypeToContext(b: *NodeBuilderImpl, symbol: ast_gen.SymbolIndex, t: types.TypeIndex) !SymbolTypeScope {
    const old_type = b.ctx.enclosingSymbolTypes.get(symbol);
    try b.ctx.enclosingSymbolTypes.put(b.c.allocator, symbol, t);
    return SymbolTypeScope{ .old_type = old_type, .symbol = symbol };
}

pub const SignatureScopeResult = struct {
    expandedParams: []const ast_gen.SymbolIndex,
    cleanup: NewScopeCleanup,
};

pub fn enterSignatureScope(b: *NodeBuilderImpl, signature: types.SignatureIndex) !SignatureScopeResult {
    const expandedParams = b.c.getExpandedParameters(signature, true);
    const sigData = b.c.signatures.items[signature];
    const originalParameters = b.c.signatureParameters.items[sigData.parametersStart .. sigData.parametersStart + sigData.parametersLen];
    const typeParameters = b.c.signatureTypeParameters.items[sigData.typeParametersStart .. sigData.typeParametersStart + sigData.typeParametersLen];
    const cleanup = try enterNewScope(b, sigData.declaration, expandedParams, typeParameters, originalParameters, sigData.mapper);
    return SignatureScopeResult{ .expandedParams = expandedParams, .cleanup = cleanup };
}

pub const NewScopeCleanup = struct {
    cleanupContext: CloneContextScope,
    oldEnclosingDecl: ast_gen.NodeIndex,
    // mapper is missing from ctx currently, so we don't save it
    // oldMapper: ?types.TypeMapperIndex,

    pub fn restore(self: *const NewScopeCleanup, b: *NodeBuilderImpl) void {
        self.cleanupContext.restore(b);
        b.ctx.enclosingDeclaration = self.oldEnclosingDecl;
        // b.ctx.mapper = self.oldMapper;
    }
};

pub fn enterNewScope(
    b: *NodeBuilderImpl,
    declaration: ast_gen.NodeIndex,
    expandedParams: []const ast_gen.SymbolIndex,
    typeParameters: []const types.TypeIndex,
    originalParameters: []const ast_gen.SymbolIndex,
    mapper: types.TypeMapperIndex,
) !NewScopeCleanup {
    _ = declaration;
    _ = expandedParams;
    _ = typeParameters;
    _ = originalParameters;
    _ = mapper;
    const cleanupContext = try cloneNodeBuilderContext(b);
    const oldEnclosingDecl = b.ctx.enclosingDeclaration;

    // TODO: pushFakeScope logic for params and typeParams

    return NewScopeCleanup{
        .cleanupContext = cleanupContext,
        .oldEnclosingDecl = oldEnclosingDecl,
    };
}
