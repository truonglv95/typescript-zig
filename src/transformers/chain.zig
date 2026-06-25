const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const emitcontext = @import("../printer/emitcontext.zig");
const transformer_mod = @import("transformer.zig");

pub const ChainedTransformer = struct {
    transformer: *transformer_mod.Transformer,
    components: []*transformer_mod.Transformer,

    pub fn init(allocator: std.mem.Allocator, components: []*transformer_mod.Transformer, opt: *transformer_mod.TransformOptions) !*transformer_mod.Transformer {
        const ch = try allocator.create(ChainedTransformer);
        ch.components = components;
        
        ch.transformer = try transformer_mod.Transformer.init(allocator, visit, ch, opt.context);
        return ch.transformer;
    }

    pub fn deinit(self: *ChainedTransformer, allocator: std.mem.Allocator) void {
        for (self.components) |comp| {
            comp.deinit(allocator);
        }
        allocator.free(self.components);
        allocator.destroy(self);
    }

    fn visit(ctx: ?*anyopaque, visitor: *visitor_mod.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = visitor;
        const self = @as(*ChainedTransformer, @ptrCast(@alignCast(ctx.?)));
        const tree = self.transformer.emitContext.tree;
        
        if (node == 0) return 0;
        if (tree.getNode(node) != .SourceFile) {
            std.debug.panic("Chained transform passed non-sourcefile initial node", .{});
        }
        
        var result = node;
        for (self.components) |comp| {
            result = comp.transformSourceFile(result);
        }
        return result;
    }
};

const visitor_mod = @import("../ast/visitor.zig");
