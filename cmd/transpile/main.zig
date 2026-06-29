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
const referenceresolver = @import("tsc").referenceresolver;

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

    var compiler_options = core.CompilerOptions{};

    // Parse compiler options from test file headers
    var line_it = std.mem.splitScalar(u8, content, '\n');
    while (line_it.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (!std.mem.startsWith(u8, trimmed, "// @")) {
            if (trimmed.len > 0 and !std.mem.startsWith(u8, trimmed, "//")) {
                break;
            }
            continue;
        }
        const opt_part = trimmed[4..];
        var colon_it = std.mem.splitScalar(u8, opt_part, ':');
        const key = std.mem.trim(u8, colon_it.next() orelse "", " \t\r\n");
        const val = std.mem.trim(u8, colon_it.next() orelse "", " \t\r\n");
        if (key.len == 0 or val.len == 0) continue;

        if (std.mem.eql(u8, key, "target")) {
            if (std.ascii.eqlIgnoreCase(val, "es3") or std.ascii.eqlIgnoreCase(val, "es5")) {
                compiler_options.target = .ES5;
            } else if (std.ascii.eqlIgnoreCase(val, "es2015") or std.ascii.eqlIgnoreCase(val, "es6")) {
                compiler_options.target = .ES2015;
            } else if (std.ascii.eqlIgnoreCase(val, "es2016")) {
                compiler_options.target = .ES2016;
            } else if (std.ascii.eqlIgnoreCase(val, "es2017")) {
                compiler_options.target = .ES2017;
            } else if (std.ascii.eqlIgnoreCase(val, "es2018")) {
                compiler_options.target = .ES2018;
            } else if (std.ascii.eqlIgnoreCase(val, "es2019")) {
                compiler_options.target = .ES2019;
            } else if (std.ascii.eqlIgnoreCase(val, "es2020")) {
                compiler_options.target = .ES2020;
            } else if (std.ascii.eqlIgnoreCase(val, "es2021")) {
                compiler_options.target = .ES2021;
            } else if (std.ascii.eqlIgnoreCase(val, "es2022")) {
                compiler_options.target = .ES2022;
            } else if (std.ascii.eqlIgnoreCase(val, "es2023")) {
                compiler_options.target = .ES2023;
            } else if (std.ascii.eqlIgnoreCase(val, "es2024")) {
                compiler_options.target = .ES2024;
            } else if (std.ascii.eqlIgnoreCase(val, "es2025")) {
                compiler_options.target = .ES2025;
            } else if (std.ascii.eqlIgnoreCase(val, "esnext")) {
                compiler_options.target = .ESNext;
            }
        } else if (std.mem.eql(u8, key, "jsx")) {
            if (std.ascii.eqlIgnoreCase(val, "preserve")) {
                compiler_options.jsx = .Preserve;
            } else if (std.ascii.eqlIgnoreCase(val, "react")) {
                compiler_options.jsx = .React;
            } else if (std.ascii.eqlIgnoreCase(val, "react-jsx")) {
                compiler_options.jsx = .ReactJSX;
            } else if (std.ascii.eqlIgnoreCase(val, "react-jsxdev")) {
                compiler_options.jsx = .ReactJSXDev;
            } else if (std.ascii.eqlIgnoreCase(val, "react-native")) {
                compiler_options.jsx = .ReactNative;
            }
        } else if (std.mem.eql(u8, key, "experimentalDecorators")) {
            compiler_options.experimentalDecorators = std.mem.eql(u8, val, "true");
        } else if (std.mem.eql(u8, key, "declaration")) {
            compiler_options.declaration = std.mem.eql(u8, val, "true");
        } else if (std.mem.eql(u8, key, "emitDecoratorMetadata")) {
            compiler_options.emitDecoratorMetadata = std.mem.eql(u8, val, "true");
        }
    }

    // 1. Parse TS source to AST
    var p = parser_pkg.Parser.init(alloc, content);
    if (std.mem.endsWith(u8, filepath, ".tsx") or std.mem.endsWith(u8, filepath, ".jsx")) {
        p.setLanguageVariant(.JSX);
    }
    const astIndex = try p.parseSourceFile();

    // 2. Setup Compiler Context
    var factory = factory_pkg.NodeFactory.init(alloc, &p.ast);
    var emit_ctx = emitcontext_pkg.EmitContext.init(alloc, &p.ast, &factory);

    // 2.5 Run Binder and Checker
    const binder_pkg = @import("tsc").binder_pkg;
    var b = try binder_pkg.Binder.init(alloc, &p.ast);
    try b.bindSourceFile(astIndex);

    const checker_pkg = @import("tsc").checker_pkg;
    var chk = checker_pkg.Checker.init(alloc, &b);
    try chk.checkStatement(astIndex);

    var emit_resolver = emitresolver_pkg.EmitResolver{};
    var ref_resolver = referenceresolver.ReferenceResolver.init(&p.ast, .{});
    ref_resolver.binder = &b;
    ref_resolver.compilerOptions = &compiler_options;

    std.debug.print("experimentalDecorators: {any}\n", .{compiler_options.experimentalDecorators});
    std.debug.print("emitDecoratorMetadata: {any}\n", .{compiler_options.emitDecoratorMetadata});

    var options = transformers_pkg.transformer.TransformOptions{
        .compilerOptions = &compiler_options,
        .context = &emit_ctx,
        .resolver = &ref_resolver,
        .emitResolver = &emit_resolver,
    };
    // 3. Transform (Runtime Syntax + Type Erasure)
    const runtimesyntax = transformers_pkg.tstransforms.runtimesyntax;
    const usingTx = try transformers_pkg.estransforms.using.UsingDeclarationTransformer.newUsingDeclarationTransformer(alloc, &options);
    const runtimeSyntaxTx = try runtimesyntax.RuntimeSyntaxTransformer.newRuntimeSyntaxTransformer(alloc, &options);
    const typeEraserTx = try typeeraser.TypeEraserTransformer.newTypeEraserTransformer(alloc, &options);
    const importElisionTx = try transformers_pkg.tstransforms.importelision.ImportElisionTransformer.new(alloc, &options);
    const metadataTx = try transformers_pkg.tstransforms.metadata.MetadataTransformer.new(alloc, &options);
    const legacyDecoratorsTx = transformers_pkg.tstransforms.legacydecorators.LegacyDecoratorsTransformer.new(alloc, &options);
    const constEnumInliningTx = try transformers_pkg.inliners.ConstEnumInliningTransformer.new(alloc, &options);
    const esmodule = transformers_pkg.moduletransforms.esmodule;
    const esModuleTx = try esmodule.ESModuleTransformer.newESModuleTransformer(alloc, &options);
    const esDecoratorTx = try transformers_pkg.estransforms.esdecorator.ESDecoratorTransformer.new(alloc, &options);
    const classFieldsTx = try transformers_pkg.estransforms.classfields.ClassFieldsTransformer.new(alloc, &options);
    const taggedTemplateTx = try transformers_pkg.estransforms.taggedtemplate.TaggedTemplateTransformer.new(alloc, &options);
    const jsxTx = try transformers_pkg.jsxtransforms.JSXTransformer.new(alloc, &options);
    const objectRestTx = try transformers_pkg.estransforms.objectrestspread.ObjectRestTransformer.new(alloc, &options);
    const asyncTx = try transformers_pkg.estransforms.async_transform.AsyncTransformer.new(alloc, &options);

    var transformers_buf: [16]*transformers_pkg.transformer.Transformer = undefined;
    var tr_len: usize = 0;
    if (compiler_options.emitDecoratorMetadata orelse false) {
        transformers_buf[tr_len] = metadataTx;
        tr_len += 1;
    }
    transformers_buf[tr_len] = typeEraserTx;
    tr_len += 1;
    transformers_buf[tr_len] = importElisionTx;
    tr_len += 1;
    // This port's const-enum inliner gathers values directly from enum AST
    // nodes, so it must run before RuntimeSyntax elides const declarations.
    // The Go implementation runs later because its resolver retains those
    // values independently of the transformed tree.
    transformers_buf[tr_len] = constEnumInliningTx;
    tr_len += 1;
    transformers_buf[tr_len] = runtimeSyntaxTx;
    tr_len += 1;
    if (compiler_options.experimentalDecorators orelse false) {
        transformers_buf[tr_len] = legacyDecoratorsTx;
        tr_len += 1;
    }
    if (compiler_options.jsx == .React or compiler_options.jsx == .ReactJSX or compiler_options.jsx == .ReactJSXDev) {
        transformers_buf[tr_len] = jsxTx;
        tr_len += 1;
    }
    transformers_buf[tr_len] = usingTx;
    tr_len += 1;
    transformers_buf[tr_len] = esDecoratorTx;
    tr_len += 1;
    transformers_buf[tr_len] = classFieldsTx;
    tr_len += 1;
    transformers_buf[tr_len] = objectRestTx;
    tr_len += 1;
    transformers_buf[tr_len] = asyncTx;
    tr_len += 1;
    transformers_buf[tr_len] = taggedTemplateTx;
    tr_len += 1;
    transformers_buf[tr_len] = esModuleTx;
    tr_len += 1;

    var tx = try transformers_pkg.chain.ChainedTransformer.init(alloc, transformers_buf[0..tr_len], &options);
    const transformedIndex = tx.transformSourceFile(astIndex);
    emit_ctx.addEmitHelpers(transformedIndex, emit_ctx.readEmitHelpers());
    if (compiler_options.emitDecoratorMetadata orelse false) {
        emit_ctx.requestEmitHelper(&@import("tsc").helpers.metadataHelper);
        emit_ctx.addEmitHelpers(transformedIndex, emit_ctx.readEmitHelpers());
    }
    if (compiler_options.experimentalDecorators orelse false) {
        emit_ctx.requestEmitHelper(&@import("tsc").helpers.decorateHelper);
        emit_ctx.addEmitHelpers(transformedIndex, emit_ctx.readEmitHelpers());
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
