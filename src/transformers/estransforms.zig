const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const visitor = @import("../ast/visitor.zig");
const core = @import("../core/core.zig");
const transformers = @import("transformer.zig");
const chain = @import("chain.zig");

// Import the individual transformers
const using = @import("estransforms/using.zig");
const classfields = @import("estransforms/classfields.zig");
const esdecorator = @import("estransforms/esdecorator.zig");
const taggedtemplate = @import("estransforms/taggedtemplate.zig");
const objectrestspread = @import("estransforms/objectrestspread.zig");
const async_transform = @import("estransforms/async.zig");

pub fn getESTransformer(allocator: std.mem.Allocator, opts: *transformers.TransformOptions) !?*transformers.Transformer {
    const options = opts.compilerOptions;
    var active = std.ArrayList(*transformers.Transformer).init(allocator);
    defer active.deinit();

    const target = options.getEmitScriptTarget();

    const experimentalDecorators = options.experimentalDecorators.isTrue();
    const useDefineForClassFields = options.getUseDefineForClassFields();

    const esDecoratorActive = !experimentalDecorators and !(target == .ESNext and useDefineForClassFields);
    const classFieldsActive = @intFromEnum(target) < @intFromEnum(core.ScriptTarget.ES2022) or !useDefineForClassFields;
    const usingActive = target != .ESNext;
    const taggedTemplateActive = @intFromEnum(target) < @intFromEnum(core.ScriptTarget.ES2018);
    const objectRestActive = @intFromEnum(target) < @intFromEnum(core.ScriptTarget.ES2018);
    const asyncActive = @intFromEnum(target) < @intFromEnum(core.ScriptTarget.ES2017);

    if (usingActive) {
        try active.append(try using.UsingDeclarationTransformer.newUsingDeclarationTransformer(allocator, opts));
    }
    if (esDecoratorActive) {
        try active.append(try esdecorator.ESDecoratorTransformer.new(allocator, opts));
    }
    if (classFieldsActive) {
        try active.append(try classfields.ClassFieldsTransformer.new(allocator, opts));
    }
    if (objectRestActive) {
        try active.append(try objectrestspread.ObjectRestTransformer.new(allocator, opts));
    }
    if (asyncActive) {
        try active.append(try async_transform.AsyncTransformer.new(allocator, opts));
    }
    if (taggedTemplateActive) {
        try active.append(try taggedtemplate.TaggedTemplateTransformer.new(allocator, opts));
    }

    if (active.items.len == 0) return null;
    if (active.items.len == 1) return active.items[0];

    const components = try allocator.dupe(*transformers.Transformer, active.items);
    return try chain.ChainedTransformer.init(allocator, components, opts);
}

pub const UseStrictTransformer = struct {
    base: transformers.Transformer,
    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, opt: *transformers.TransformOptions) !*transformers.Transformer {
        const tx = try allocator.create(UseStrictTransformer);
        tx.allocator = allocator;
        tx.base = (try transformers.Transformer.init(allocator, visit, tx, opt.context)).*;
        return &tx.base;
    }

    fn visit(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = ctx;
        return v.visitEachChild(node);
    }
};

pub fn transformES(context: anytype) void {
    _ = context;
}
