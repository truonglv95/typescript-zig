const std = @import("std");
const parser_pkg = @import("tsc").parser_pkg;
const printer_pkg = @import("tsc").printer_pkg;
const factory_pkg = @import("tsc").factory;
const emitcontext_pkg = @import("tsc").emitcontext;
const textwriter_pkg = @import("tsc").textwriter;
const transformers_pkg = @import("tsc").transformers_pkg;
const typeeraser = @import("tsc").typeeraser;
const core = @import("tsc").core;
const emitresolver_pkg = @import("tsc").emitresolver;

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();

    _ = args.next(); // skip executable name

    const filepath = args.next() orelse {
        std.debug.print("Usage: transpile <file.ts> [output.js]\n", .{});
        std.process.exit(1);
    };

    const outpath = args.next();

    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();
    const alloc = arena.allocator();

    var threaded = std.Io.Threaded.init(alloc, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const content = try std.Io.Dir.cwd().readFileAlloc(io, filepath, alloc, @enumFromInt(std.math.maxInt(usize)));

    // 1. Parse TS source to AST
    var p = parser_pkg.Parser.init(alloc, content);
    const astIndex = try p.parseSourceFile();

    // 2. Setup Compiler Context
    var factory = factory_pkg.NodeFactory.init(alloc, &p.ast);
    var emit_ctx = emitcontext_pkg.EmitContext.init(alloc, &p.ast, &factory);
    var compiler_options = core.CompilerOptions{};

    // 2.5 Run Binder and Checker
    const binder_pkg = @import("tsc").binder_pkg;
    var b = try binder_pkg.Binder.init(alloc, &p.ast);
    try b.bindSourceFile(astIndex);

    const checker_pkg = @import("tsc").checker_pkg;
    var chk = checker_pkg.Checker.init(alloc, &b);
    try chk.checkStatement(astIndex);

    var emit_resolver = emitresolver_pkg.EmitResolver{};

    var options = transformers_pkg.transformer.TransformOptions{
        .compilerOptions = &compiler_options,
        .context = &emit_ctx,
        .emitResolver = &emit_resolver,
    };
    const statements = p.ast.getNodeList(p.ast.getNode(astIndex).SourceFile.Statements);
    std.debug.print("AST statements len: {d}\n", .{statements.len});
    for (statements) |stmt| {
        std.debug.print("  stmt: {any}\n", .{std.meta.activeTag(p.ast.getNode(stmt))});
        if (p.ast.getNode(stmt) == .VariableStatement) {
            const n = p.ast.getNode(stmt).VariableStatement;
            std.debug.print("    DeclarationList: {d}\n", .{n.DeclarationList});
            const dl = p.ast.getNode(n.DeclarationList).VariableDeclarationList;
            std.debug.print("    dl.Flags: {d}\n", .{dl.Flags});
        }
    }

    // 3. Transform (Runtime Syntax + Type Erasure)
    const runtimesyntax = transformers_pkg.tstransforms.runtimesyntax;
    const usingTx = try transformers_pkg.estransforms.using.UsingDeclarationTransformer.newUsingDeclarationTransformer(alloc, &options);
    const runtimeSyntaxTx = try runtimesyntax.RuntimeSyntaxTransformer.newRuntimeSyntaxTransformer(alloc, &options);
    const typeEraserTx = try typeeraser.TypeEraserTransformer.newTypeEraserTransformer(alloc, &options);
    // const metadataTx = try metadata.MetadataTransformer.newMetadataTransformer(alloc, &options);
    // const legacyDecoratorsTx = try legacydecorators.LegacyDecoratorsTransformer.newLegacyDecoratorsTransformer(alloc, &options);
    // const esmodule = transformers_pkg.moduletransforms.esmodule;
    // const esModuleTx = try esmodule.ESModuleTransformer.newESModuleTransformer(alloc, &options);

    var transformers = [_]*transformers_pkg.transformer.Transformer{
        typeEraserTx,
        usingTx,
        runtimeSyntaxTx,
        // esModuleTx,
    };

    // We will run TypeEraser FIRST, because that's the correct order in TS!

    var tx = try transformers_pkg.chain.ChainedTransformer.init(alloc, &transformers, &options);
    const transformedIndex = tx.transformSourceFile(astIndex);

    const transformedNode = p.ast.getNode(transformedIndex);
    if (transformedNode == .SourceFile) {
        const stats = p.ast.getNodeList(transformedNode.SourceFile.Statements);
        std.debug.print("TRANSFORMED SOURCE FILE STATEMENTS LEN: {d}\n", .{stats.len});
    }

    // std.debug.print("Original astIndex: {d}\n", .{astIndex});
    // std.debug.print("Transformed transformedIndex: {d}\n", .{transformedIndex});
    // const s_node = p.ast.getNode(transformedIndex).SourceFile;
    // std.debug.print("Transformed SourceFile Statements List: {d}\n", .{s_node.Statements});

    // 4. Print JS to TextWriter
    var text_writer = textwriter_pkg.TextWriter.init(alloc, "\n", 4);
    var emit_writer = text_writer.getEmitTextWriter();
    var pr = printer_pkg.Printer.init(&p.ast, &emit_ctx, &emit_writer);

    try pr.printSourceFile(transformedIndex);

    // 5. Output JS code
    const output = text_writer.string();
    if (outpath) |out_path_str| {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = out_path_str, .data = output });
    } else {
        std.debug.print("{s}\n", .{output});
    }
}
