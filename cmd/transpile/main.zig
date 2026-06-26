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
        std.debug.print("Usage: transpile <file.ts>\n", .{});
        std.process.exit(1);
    };

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
    var emit_resolver = emitresolver_pkg.EmitResolver{};

    var options = transformers_pkg.transformer.TransformOptions{
        .compilerOptions = &compiler_options,
        .context = &emit_ctx,
        .emitResolver = &emit_resolver,
    };
    
    // 3. Transform (Type Erasure)
    var tx = try typeeraser.TypeEraserTransformer.newTypeEraserTransformer(alloc, &options);
    const transformedIndex = tx.transformSourceFile(astIndex);

    // 4. Print JS to TextWriter
    var text_writer = textwriter_pkg.TextWriter.init(alloc, "\n", 4);
    var emit_writer = text_writer.getEmitTextWriter();
    var pr = printer_pkg.Printer.init(&p.ast, &emit_ctx, &emit_writer);

    try pr.printSourceFile(transformedIndex);

    // 5. Output JS code
    const output = text_writer.string();
    std.debug.print("{s}\n", .{output});
}
