const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const types = @import("types.zig");
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const nodebuilderimpl = @import("nodebuilderimpl.zig");
// const printer = @import("printer/emitcontext.zig"); // placeholder, need to know path to printer

pub const VerbosityContext = struct {
    level: usize = 0,
    maxTruncationLength: usize = 0,
    canIncreaseVerbosity: bool = false,
    truncated: bool = false,
};

pub const NodeBuilder = struct {
    ctxStack: std.ArrayListUnmanaged(*nodebuilderimpl.NodeBuilderContext) = .empty,
    // host: Host
    impl: *nodebuilderimpl.NodeBuilderImpl,
    verbosity: ?*VerbosityContext = null,

    pub fn enterContext(
        b: *NodeBuilder,
        enclosingDeclaration: ast_gen.NodeIndex,
        flags: nodebuilderimpl.Flags,
        internalFlags: nodebuilderimpl.InternalFlags,
    ) void {
        var verbosityLevel: isize = -1;
        var maxTruncationLength: usize = 0;
        if (b.verbosity) |v| {
            verbosityLevel = @intCast(v.level);
            maxTruncationLength = v.maxTruncationLength;
        }
        b.ctxStack.append(b.impl.c.allocator, &b.impl.ctx) catch unreachable;

        b.impl.ctx = .{
            // host
            // tracker
            .flags = flags,
            .internalFlags = internalFlags,
            .maxExpansionDepth = verbosityLevel,
            .maxTruncationLength = maxTruncationLength,
            .enclosingDeclaration = enclosingDeclaration,
            .enclosingFile = 0, // ast.getSourceFileOfNode(enclosingDeclaration)
        };
        // b.impl.ctx.tracker = NewSymbolTrackerImpl
    }

    pub fn propagateVerbosityOut(b: *NodeBuilder) void {
        if (b.verbosity) |v| {
            if (b.impl.ctx.canIncreaseExpansionDepth) {
                v.canIncreaseVerbosity = true;
            }
            if (b.impl.ctx.expansionTruncated) {
                v.truncated = true;
            }
        }
    }

    pub fn popContext(b: *NodeBuilder) void {
        if (b.ctxStack.items.len == 0) {
            // b.impl.ctx = null;
        } else {
            const popped = b.ctxStack.pop();
            b.impl.ctx = popped.?.*;
        }
    }

    pub fn exitContext(b: *NodeBuilder, result: ast_gen.NodeIndex) ast_gen.NodeIndex {
        b.propagateVerbosityOut();
        b.exitContextCheck();
        b.popContext();
        if (b.impl.ctx.encounteredError) {
            return 0; // null node
        }
        return result;
    }

    pub fn exitContextSlice(b: *NodeBuilder, result: []const ast_gen.NodeIndex) []const ast_gen.NodeIndex {
        b.propagateVerbosityOut();
        b.exitContextCheck();
        b.popContext();
        if (b.impl.ctx.encounteredError) {
            return &[_]ast_gen.NodeIndex{};
        }
        return result;
    }

    pub fn exitContextCheck(b: *NodeBuilder) void {
        if (b.impl.ctx.truncating and b.impl.ctx.flags.NoTruncation) {
            // b.impl.ctx.tracker.ReportTruncationError()
        }
    }

    pub fn indexInfoToIndexSignatureDeclaration(b: *NodeBuilder, info: types.IndexInfoIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: nodebuilderimpl.Flags, internalFlags: nodebuilderimpl.InternalFlags) ast_gen.NodeIndex {
        b.enterContext(enclosingDeclaration, flags, internalFlags);
        return b.exitContext(b.impl.indexInfoToIndexSignatureDeclaration(info));
    }

    pub fn serializeReturnTypeForSignature(b: *NodeBuilder, signatureDeclaration: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: nodebuilderimpl.Flags, internalFlags: nodebuilderimpl.InternalFlags) ast_gen.NodeIndex {
        b.enterContext(enclosingDeclaration, flags, internalFlags);
        return b.exitContext(b.impl.serializeReturnTypeForSignature(signatureDeclaration));
    }

    pub fn serializeTypeParametersForSignature(b: *NodeBuilder, signatureDeclaration: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: nodebuilderimpl.Flags, internalFlags: nodebuilderimpl.InternalFlags) []const ast_gen.NodeIndex {
        b.enterContext(enclosingDeclaration, flags, internalFlags);
        return b.exitContextSlice(b.impl.serializeTypeParametersForSignature(signatureDeclaration));
    }

    pub fn serializeTypeForDeclaration(b: *NodeBuilder, declaration: ast_gen.NodeIndex, symbol: types.SymbolIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: nodebuilderimpl.Flags, internalFlags: nodebuilderimpl.InternalFlags) ast_gen.NodeIndex {
        b.enterContext(enclosingDeclaration, flags, internalFlags);
        return b.exitContext(b.impl.serializeTypeForDeclaration(declaration, symbol));
    }

    pub fn serializeTypeForExpression(b: *NodeBuilder, expr: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: nodebuilderimpl.Flags, internalFlags: nodebuilderimpl.InternalFlags) ast_gen.NodeIndex {
        b.enterContext(enclosingDeclaration, flags, internalFlags);
        return b.exitContext(b.impl.serializeTypeForExpression(expr));
    }

    pub fn signatureToSignatureDeclaration(b: *NodeBuilder, signature: types.SignatureIndex, kind: ast_gen.SyntaxKind, enclosingDeclaration: ast_gen.NodeIndex, flags: nodebuilderimpl.Flags, internalFlags: nodebuilderimpl.InternalFlags) ast_gen.NodeIndex {
        b.enterContext(enclosingDeclaration, flags, internalFlags);
        return b.exitContext(b.impl.signatureToSignatureDeclaration(signature, kind));
    }

    pub fn expandSymbolForHover(b: *NodeBuilder, symbol: types.SymbolIndex, meaning: types.SymbolFlags) []const ast_gen.NodeIndex {
        b.enterContext(0, .{}, .{});
        return b.exitContextSlice(b.impl.expandSymbolForHover(symbol, meaning));
    }

    pub fn symbolToEntityName(b: *NodeBuilder, symbol: types.SymbolIndex, meaning: types.SymbolFlags, enclosingDeclaration: ast_gen.NodeIndex, flags: nodebuilderimpl.Flags, internalFlags: nodebuilderimpl.InternalFlags) ast_gen.NodeIndex {
        b.enterContext(enclosingDeclaration, flags, internalFlags);
        return b.exitContext(b.impl.symbolToEntityName(symbol, meaning));
    }

    pub fn symbolToExpression(b: *NodeBuilder, symbol: types.SymbolIndex, meaning: types.SymbolFlags, enclosingDeclaration: ast_gen.NodeIndex, flags: nodebuilderimpl.Flags, internalFlags: nodebuilderimpl.InternalFlags) ast_gen.NodeIndex {
        b.enterContext(enclosingDeclaration, flags, internalFlags);
        return b.exitContext(b.impl.symbolToExpression(symbol, meaning));
    }

    pub fn symbolToNode(b: *NodeBuilder, symbol: types.SymbolIndex, meaning: types.SymbolFlags, enclosingDeclaration: ast_gen.NodeIndex, flags: nodebuilderimpl.Flags, internalFlags: nodebuilderimpl.InternalFlags) ast_gen.NodeIndex {
        b.enterContext(enclosingDeclaration, flags, internalFlags);
        return b.exitContext(b.impl.symbolToNode(symbol, meaning));
    }

    pub fn symbolToParameterDeclaration(b: *NodeBuilder, symbol: types.SymbolIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: nodebuilderimpl.Flags, internalFlags: nodebuilderimpl.InternalFlags) ast_gen.NodeIndex {
        b.enterContext(enclosingDeclaration, flags, internalFlags);
        return b.exitContext(b.impl.symbolToParameterDeclaration(symbol));
    }

    pub fn symbolToTypeParameterDeclarations(b: *NodeBuilder, symbol: types.SymbolIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: nodebuilderimpl.Flags, internalFlags: nodebuilderimpl.InternalFlags) []const ast_gen.NodeIndex {
        b.enterContext(enclosingDeclaration, flags, internalFlags);
        return b.exitContextSlice(b.impl.symbolToTypeParameterDeclarations(symbol));
    }

    pub fn typeParameterToDeclaration(b: *NodeBuilder, parameter: types.TypeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: nodebuilderimpl.Flags, internalFlags: nodebuilderimpl.InternalFlags) ast_gen.NodeIndex {
        b.enterContext(enclosingDeclaration, flags, internalFlags);
        return b.exitContext(b.impl.typeParameterToDeclaration(parameter));
    }

    pub fn typePredicateToTypePredicateNode(b: *NodeBuilder, predicate: types.TypePredicateIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: nodebuilderimpl.Flags, internalFlags: nodebuilderimpl.InternalFlags) ast_gen.NodeIndex {
        b.enterContext(enclosingDeclaration, flags, internalFlags);
        return b.exitContext(b.impl.typePredicateToTypePredicateNode(predicate));
    }

    pub fn typeToTypeNode(b: *NodeBuilder, typ: types.TypeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: nodebuilderimpl.Flags, internalFlags: nodebuilderimpl.InternalFlags) ast_gen.NodeIndex {
        b.enterContext(enclosingDeclaration, flags, internalFlags);
        return b.exitContext(b.impl.typeToTypeNode(typ));
    }

    pub fn tryJSTypeNodeToTypeNode(b: *NodeBuilder, node: ast_gen.NodeIndex, enclosingDeclaration: ast_gen.NodeIndex, flags: nodebuilderimpl.Flags, internalFlags: nodebuilderimpl.InternalFlags) ast_gen.NodeIndex {
        b.enterContext(enclosingDeclaration, flags, internalFlags);
        return b.exitContext(b.impl.tryJSTypeNodeToTypeNode(node));
    }
    pub fn emitContext(b: *NodeBuilder) *anyopaque {
        return b.impl.e;
    }
};

pub fn getNodeBuilder(c: *Checker) *NodeBuilder {
    _ = c;
    return undefined; // stub
}

pub fn getNodeBuilderEx(c: *Checker, verbosity: ?*VerbosityContext) *NodeBuilder {
    _ = c;
    _ = verbosity;
    return undefined; // stub
}

pub fn newNodeBuilderEx(c: *Checker, emitContext_: *anyopaque, idToSymbol_: *anyopaque) *NodeBuilder {
    _ = c;
    _ = emitContext_;
    _ = idToSymbol_;
    return undefined; // stub
}

pub fn simplifyModifiers(b: *NodeBuilder, modifiers: []const ast_gen.NodeIndex) []const ast_gen.NodeIndex {
    _ = b;
    _ = modifiers;
    return &[_]ast_gen.NodeIndex{};
}

pub fn simplifyClassDeclaration(b: *NodeBuilder, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    _ = b;
    _ = node;
    return 0; // stub
}

pub fn newNodeBuilder(c: *Checker) *NodeBuilder {
    _ = c;
    _ = c;
    // b = alloc
    // b.impl = newNodeBuilderImpl(c, emitContext, idToSymbol)
    return undefined; // stub
}
