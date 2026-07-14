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
    var active = std.ArrayList(*transformers.Transformer).empty;
    defer active.deinit(allocator);

    const target = options.target orelse .None;

    const experimentalDecorators = options.experimentalDecorators orelse false;
    const useDefineForClassFields = options.useDefineForClassFields orelse false;

    const esDecoratorActive = !experimentalDecorators and !(target == .ESNext and useDefineForClassFields);
    const classFieldsActive = @intFromEnum(target) < @intFromEnum(core.ScriptTarget.ES2022) or !useDefineForClassFields;
    const usingActive = target != .ESNext;
    const taggedTemplateActive = @intFromEnum(target) < @intFromEnum(core.ScriptTarget.ES2018);
    const objectRestActive = @intFromEnum(target) < @intFromEnum(core.ScriptTarget.ES2018);
    const asyncActive = @intFromEnum(target) < @intFromEnum(core.ScriptTarget.ES2017);

    if (usingActive) {
        try active.append(allocator, try using.UsingDeclarationTransformer.newUsingDeclarationTransformer(allocator, opts));
    }
    if (esDecoratorActive) {
        try active.append(allocator, try esdecorator.ESDecoratorTransformer.new(allocator, opts));
    }
    if (classFieldsActive) {
        try active.append(allocator, try classfields.ClassFieldsTransformer.new(allocator, opts));
    }
    if (objectRestActive) {
        try active.append(allocator, try objectrestspread.ObjectRestTransformer.new(allocator, opts));
    }
    if (asyncActive) {
        try active.append(allocator, try async_transform.AsyncTransformer.new(allocator, opts));
    }
    if (taggedTemplateActive) {
        try active.append(allocator, try taggedtemplate.TaggedTemplateTransformer.new(allocator, opts));
    }

    if (active.items.len == 0) return null;
    if (active.items.len == 1) return active.items[0];

    const components = try allocator.dupe(*transformers.Transformer, active.items);
    return try chain.ChainedTransformer.init(allocator, components, opts);
}

pub const UseStrictTransformer = struct {
    base: transformers.Transformer,
    allocator: std.mem.Allocator,
    compilerOptions: *const core.CompilerOptions,

    pub fn new(allocator: std.mem.Allocator, opt: *transformers.TransformOptions) !*transformers.Transformer {
        const tx = try allocator.create(UseStrictTransformer);
        tx.allocator = allocator;
        tx.compilerOptions = opt.compilerOptions;
        tx.base = (try transformers.Transformer.init(allocator, visit, tx, opt.context)).*;
        return &tx.base;
    }

    fn visit(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const self: *UseStrictTransformer = @ptrCast(@alignCast(ctx));
        if (v.tree.getNode(node) == .SourceFile) {
            return self.visitSourceFile(v, node);
        }
        return v.visitEachChild(node);
    }

    fn visitSourceFile(self: *UseStrictTransformer, v: *visitor.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = v.tree;
        const sourceFile = tree.getNode(node).SourceFile;

        const isExternalModule = @import("../ast/ast_utils.zig").isExternalModule(tree, node);
        const moduleKind = @import("../compiler/emitter.zig").getEmitModuleKind(@constCast(self.compilerOptions));

        // ESM is always strict
        if (isExternalModule and @intFromEnum(moduleKind) >= @intFromEnum(core.ModuleKind.ES2015)) {
            if (moduleKind == .Preserve or @intFromEnum(moduleKind) >= @intFromEnum(core.ModuleKind.ES2015)) return node;
        }

        const statements = v.tree.getNodeList(sourceFile.Statements);
        const new_statements = self.base.factory.ensureUseStrict(statements) catch statements;

        if (statements.ptr == new_statements.ptr) return node;

        const statementsListIndex = v.tree.pushNodeList(new_statements) catch return node;
        return self.base.factory.updateSourceFile(node, sourceFile, statementsListIndex, sourceFile.EndOfFileToken);
    }
};

pub fn transformES(context: anytype) void {
    _ = context;
}
