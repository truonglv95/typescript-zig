const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const emitcontext = @import("../printer/emitcontext.zig");
const factory = @import("../printer/factory.zig");
const visitor = @import("../ast/visitor.zig");
const core = @import("../core/core.zig");
const referenceresolver = @import("../binder/referenceresolver.zig");
const emitresolver = @import("../printer/emitresolver.zig");

pub const Transformer = struct {
    emitContext: *emitcontext.EmitContext,
    factory: *factory.NodeFactory,
    visitor: *visitor.NodeVisitor,

    pub fn init(
        allocator: std.mem.Allocator,
        visitFn: *const fn (ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex,
        ctx: ?*anyopaque,
        ec: *emitcontext.EmitContext,
    ) !*Transformer {
        const tx = try allocator.create(Transformer);
        tx.emitContext = ec;
        tx.factory = ec.factory;
        tx.visitor = ec.newNodeVisitor(visitFn, ctx, .{});
        return tx;
    }

    pub fn deinit(self: *Transformer, allocator: std.mem.Allocator) void {
        allocator.destroy(self.visitor);
        allocator.destroy(self);
    }

    pub fn transformSourceFile(self: *Transformer, file: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.visitor.visitSourceFile(file);
    }

    pub fn extractModifiers(self: *Transformer, modifiers: ast.NodeIndex, flags: u32) ast.NodeIndex {
        const ast_utils = @import("../ast/ast_utils.zig");
        return ast_utils.extractModifiers(self.emitContext.tree, modifiers, flags);
    }
};

pub const TransformOptions = struct {
    context: *emitcontext.EmitContext,
    compilerOptions: *core.CompilerOptions,
    resolver: ?*referenceresolver.ReferenceResolver = null,
    emitResolver: *emitresolver.EmitResolver,
    // getEmitModuleFormatOfFile
};

pub const TransformerFactory = *const fn (allocator: std.mem.Allocator, opt: *TransformOptions) anyerror!?*Transformer;

pub fn isGeneratedIdentifier(a: anytype, b: anytype) bool {
    _ = a;
    _ = b;
    return false;
}
