const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const NodeIndex = ast_gen.NodeIndex;
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const SymbolIndex = checker_mod.SymbolIndex;
const TypeIndex = @import("types.zig").TypeIndex;
const nodebuilderimpl = @import("nodebuilderimpl.zig");
const NodeBuilderImpl = nodebuilderimpl.NodeBuilderImpl;
const NodeBuilderContext = nodebuilderimpl.NodeBuilderContext;

pub fn reuseNode(b: *NodeBuilderImpl, node: NodeIndex) NodeIndex {
    if (node == 0) return 0;
    return tryReuseExistingNodeHelper(b, node);
}

pub fn tryJSTypeNodeToTypeNode(b: *NodeBuilderImpl, node: NodeIndex) NodeIndex {
    return reuseNode(b, node);
}

pub fn reuseName(b: *NodeBuilderImpl, node: NodeIndex, isMethod: bool) NodeIndex {
    _ = isMethod;
    const res = reuseNode(b, node);
    if (res == 0) return 0;
    return res;
}

pub fn reuseTypeNode(b: *NodeBuilderImpl, node: NodeIndex) NodeIndex {
    if (node == 0) return 0;
    const r = reuseNode(b, node);
    if (r != 0) {
        if (b.ctx.maxExpansionDepth >= 0 and !b.ctx.canIncreaseExpansionDepth) {
            walkNodeForExpandability(b, node);
        }
        return r;
    }

    // b.ctx.tracker.ReportInferenceFallback(node);
    const t = b.c.getTypeFromTypeNode(node, false);
    _ = t;
    return 0; // b.typeToTypeNode(t);
}

pub fn walkNodeForExpandability(b: *NodeBuilderImpl, node: NodeIndex) void {
    if (b.ctx.canIncreaseExpansionDepth or node == 0) return;

    const kind = b.c.binder.ast.getNodeKind(node);
    if (kind == .TypeReferenceNode or kind == .ExpressionWithTypeArguments or kind == .TypePredicateNode or kind == .ImportTypeNode) {
        const t = b.c.getTypeFromTypeNode(node, false);
        if (t != 0) {
            b.c.checkTypeExpandability(t);
            if (b.ctx.canIncreaseExpansionDepth) return;
        }
    }
}

pub fn tryReuseExistingNodeHelper(b: *NodeBuilderImpl, existing: NodeIndex) NodeIndex {
    _ = b;
    return existing;
}

pub fn getModuleSpecifierOverride(b: *NodeBuilderImpl, parent: NodeIndex, lit: NodeIndex) []const u8 {
    _ = b;
    _ = parent;
    _ = lit;
    return "";
}

pub fn rewriteModuleSpecifier(b: *NodeBuilderImpl, parent: NodeIndex, lit: NodeIndex) NodeIndex {
    const newName = getModuleSpecifierOverride(b, parent, lit);
    if (newName.len == 0) return lit;
    return lit;
}

pub fn getEnclosingDeclarationIgnoringFakeScope(b: *NodeBuilderImpl) NodeIndex {
    const enc = b.ctx.enclosingDeclaration;
    return enc;
}

pub const RecoveryBoundary = struct {
    ctx: *NodeBuilderContext,
    hadError: bool,
    oldEncounteredError: bool,
    oldApproximateLength: usize,

    pub fn markError(self: *RecoveryBoundary) void {
        self.hadError = true;
    }

    pub fn startRecoveryScope(self: *RecoveryBoundary) void {
        _ = self;
    }

    pub fn endRecoveryScope(self: *RecoveryBoundary) void {
        _ = self;
    }
};

pub fn createRecoveryBoundary(b: *NodeBuilderImpl) RecoveryBoundary {
    return .{
        .ctx = &b.ctx,
        .hadError = false,
        .oldEncounteredError = b.ctx.encounteredError,
        .oldApproximateLength = b.ctx.approximateLength,
    };
}

pub fn finalizeBoundary(b: *NodeBuilderImpl, bound: *RecoveryBoundary) bool {
    _ = b;
    if (bound.hadError) return false;
    return true;
}

pub const WrappingTracker = struct {
    wrapped: ?*anyopaque,
    bound: *RecoveryBoundary,

    pub fn reportInaccessibleThisError(self: *WrappingTracker) void {
        self.bound.markError();
        // self.wrapped.reportInaccessibleThisError();
    }

    pub fn reportInaccessibleUniqueSymbolError(self: *WrappingTracker) void {
        self.bound.markError();
        // self.wrapped.reportInaccessibleUniqueSymbolError();
    }

    pub fn reportInferenceFallback(self: *WrappingTracker, node: NodeIndex) void {
        _ = self;
        _ = node;
        // self.wrapped.reportInferenceFallback(node);
    }

    pub fn reportLikelyUnsafeImportRequiredError(self: *WrappingTracker, specifier: []const u8, symbolName: []const u8) void {
        self.bound.markError();
        _ = specifier;
        _ = symbolName;
        // self.wrapped.reportLikelyUnsafeImportRequiredError(specifier, symbolName);
    }

    pub fn reportNonSerializableProperty(self: *WrappingTracker, propertyName: []const u8) void {
        self.bound.markError();
        _ = propertyName;
        // self.wrapped.reportNonSerializableProperty(propertyName);
    }

    pub fn reportNonlocalAugmentation(self: *WrappingTracker, containingFile: NodeIndex, parentSymbol: SymbolIndex, augmentingSymbol: SymbolIndex) void {
        _ = self;
        _ = containingFile;
        _ = parentSymbol;
        _ = augmentingSymbol;
        // self.wrapped.reportNonlocalAugmentation(containingFile, parentSymbol, augmentingSymbol);
    }

    pub fn reportPrivateInBaseOfClassExpression(self: *WrappingTracker, propertyName: []const u8) void {
        self.bound.markError();
        _ = propertyName;
        // self.wrapped.reportPrivateInBaseOfClassExpression(propertyName);
    }

    pub fn reportTruncationError(self: *WrappingTracker) void {
        _ = self;
        // self.wrapped.reportTruncationError();
    }

    pub fn trackSymbol(self: *WrappingTracker, symbol: SymbolIndex, enclosingDeclaration: NodeIndex, meaning: u32) bool {
        // self.bound.trackedSymbols.append(...)
        _ = self;
        _ = symbol;
        _ = enclosingDeclaration;
        _ = meaning;
        return false;
    }

    pub fn reportCyclicStructureError(self: *WrappingTracker) void {
        self.bound.markError();
        // self.wrapped.reportCyclicStructureError();
    }

    pub fn pushErrorFallbackNode(self: *WrappingTracker, node: NodeIndex) void {
        _ = self;
        _ = node;
        // self.wrapped.pushErrorFallbackNode(node);
    }

    pub fn popErrorFallbackNode(self: *WrappingTracker) void {
        _ = self;
        // self.wrapped.popErrorFallbackNode();
    }
};

pub fn newWrappingTracker(inner: ?*anyopaque, bound: *RecoveryBoundary) WrappingTracker {
    return .{
        .wrapped = inner,
        .bound = bound,
    };
}

pub fn getExistingNodeTreeVisitor(b: *NodeBuilderImpl, bound: *RecoveryBoundary) *anyopaque {
    _ = b;
    _ = bound;
    return undefined; // Stub visitor
}
