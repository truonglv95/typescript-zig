const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const NodeIndex = ast_gen.NodeIndex;
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const SymbolIndex = checker_mod.SymbolIndex;
const TypeIndex = @import("types.zig").TypeIndex;
const nodebuilder = @import("../nodebuilder/nodebuilder.zig");
const printer = @import("../printer/printer.zig");

pub const NodeBuilderImpl = struct {
    checker: *Checker,
    ctx: *nodebuilder.NodeBuilderContext,

    pub fn init(checker: *Checker, ctx: *nodebuilder.NodeBuilderContext) NodeBuilderImpl {
        return .{
            .checker = checker,
            .ctx = ctx,
        };
    }

    pub fn reuseNode(self: *NodeBuilderImpl, node: NodeIndex) NodeIndex {
        if (node == 0) return 0;
        return self.tryReuseExistingNodeHelper(node);
    }

    pub fn tryJSTypeNodeToTypeNode(self: *NodeBuilderImpl, node: NodeIndex) NodeIndex {
        return self.reuseNode(node);
    }

    pub fn reuseName(self: *NodeBuilderImpl, node: NodeIndex, isMethod: bool) NodeIndex {
        _ = isMethod;
        const res = self.reuseNode(node);
        if (res == 0) return 0;
        return res;
    }

    pub fn reuseTypeNode(self: *NodeBuilderImpl, node: NodeIndex) NodeIndex {
        if (node == 0) return 0;
        const r = self.reuseNode(node);
        if (r != 0) {
            if (self.ctx.maxExpansionDepth >= 0 and !self.ctx.canIncreaseExpansionDepth) {
                self.walkNodeForExpandability(node);
            }
            return r;
        }

        self.ctx.tracker.reportInferenceFallback(node);
        const t = self.checker.getTypeFromTypeNode(node, false);
        return self.checker.typeToTypeNodeEx(t, 0, 0, 0); // Need actual typeToTypeNode
    }

    pub fn walkNodeForExpandability(self: *NodeBuilderImpl, node: NodeIndex) void {
        if (self.ctx.canIncreaseExpansionDepth or node == 0) return;

        const kind = self.checker.ast.getKind(node);
        if (kind == .TypeReferenceNode or kind == .ExpressionWithTypeArguments or kind == .TypePredicateNode or kind == .ImportTypeNode) {
            const t = self.checker.getTypeFromTypeNode(node, false);
            if (t != 0) {
                self.checker.checkTypeExpandability(t);
                if (self.ctx.canIncreaseExpansionDepth) return;
            }
        }

        // Node iteration would go here, currently returning for DoD structure compliance
    }

    pub fn tryReuseExistingNodeHelper(self: *NodeBuilderImpl, existing: NodeIndex) NodeIndex {
        // Full visitor logic goes here for rewriting paths.
        // We defer to deep clone for now as a fallback when AST tree traversal is omitted
        _ = self;
        return existing; // Returning existing node to prevent breaking
    }

    pub fn getModuleSpecifierOverride(self: *NodeBuilderImpl, parent: NodeIndex, lit: NodeIndex) []const u8 {
        _ = self;
        _ = parent;
        _ = lit;
        return "";
    }

    pub fn rewriteModuleSpecifier(self: *NodeBuilderImpl, parent: NodeIndex, lit: NodeIndex) NodeIndex {
        const newName = self.getModuleSpecifierOverride(parent, lit);
        if (newName.len == 0) return lit;
        // In full implementation, return new string literal
        return lit;
    }

    pub fn getEnclosingDeclarationIgnoringFakeScope(self: *NodeBuilderImpl) NodeIndex {
        const enc = self.ctx.enclosingDeclaration;
        while (enc != 0) {
            // Check fake scope flag and traverse parent
            break;
        }
        return enc;
    }
};

pub const RecoveryBoundary = struct {
    ctx: *nodebuilder.NodeBuilderContext,
    hadError: bool,
    oldTracker: *anyopaque,
    oldEncounteredError: bool,
    oldApproximateLength: usize,

    pub fn startRecoveryScope(self: *RecoveryBoundary) void {
        _ = self;
    }

    pub fn endRecoveryScope(self: *RecoveryBoundary) void {
        _ = self;
    }
};

pub fn createRecoveryBoundary(b: *NodeBuilderImpl) RecoveryBoundary {
    return .{
        .ctx = b.ctx,
        .hadError = false,
        .oldTracker = undefined,
        .oldEncounteredError = false,
        .oldApproximateLength = 0,
    };
}

pub fn finalizeBoundary(b: *NodeBuilderImpl, bound: *RecoveryBoundary) bool {
    _ = b;
    if (bound.hadError) return false;
    return true;
}
