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

const SourceMapping = struct {
    generated_line: usize,
    generated_column: usize,
    source_line: usize,
    source_column: usize,
};

const SourceMapRecorder = struct {
    allocator: std.mem.Allocator,
    mappings: std.ArrayList(SourceMapping),

    fn add(context: *anyopaque, generated_line: usize, generated_column: usize, source_line: usize, source_column: usize) void {
        const self: *SourceMapRecorder = @ptrCast(@alignCast(context));
        if (self.mappings.items.len > 0) {
            const last = self.mappings.items[self.mappings.items.len - 1];
            if (last.generated_line == generated_line and last.generated_column == generated_column) return;
        }
        self.mappings.append(self.allocator, .{
            .generated_line = generated_line,
            .generated_column = generated_column,
            .source_line = source_line,
            .source_column = source_column,
        }) catch {};
    }
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();

    _ = args.next(); // skip executable name

    const filepath = args.next() orelse {
        std.debug.print("Usage: transpile <file.ts> [output.js]\n", .{});
        std.process.exit(1);
    };

    const outpath = args.next();

    try transpileFile(init, filepath, outpath, null, null, null);
}

pub fn transpileFile(init: std.process.Init, filepath: []const u8, outpath: ?[]const u8, override_options: ?*const core.CompilerOptions, semantic_program: ?*@import("tsc").program.Program, semantic_file: ?@import("tsc").program.FileId) !void {
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();
    const alloc = arena.allocator();

    var threaded = std.Io.Threaded.init(alloc, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const content = try std.Io.Dir.cwd().readFileAlloc(io, filepath, alloc, @enumFromInt(std.math.maxInt(usize)));

    var compiler_options = core.CompilerOptions{};
    if (std.mem.endsWith(u8, filepath, ".mts") or std.mem.endsWith(u8, filepath, ".mjs") or std.mem.endsWith(u8, filepath, ".cts") or std.mem.endsWith(u8, filepath, ".cjs")) compiler_options.moduleDetection = .Force;
    var package_is_module = false;

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
        const raw_val = std.mem.trim(u8, colon_it.next() orelse "", " \t\r\n");
        var val = std.mem.trim(u8, if (std.mem.indexOfScalar(u8, raw_val, ',')) |comma| raw_val[0..comma] else raw_val, " \t\r\n");
        if (std.mem.endsWith(u8, val, ";")) {
            val = std.mem.trim(u8, val[0 .. val.len - 1], " \t\r\n");
        }
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
        } else if (std.mem.eql(u8, key, "module")) {
            if (std.ascii.eqlIgnoreCase(val, "commonjs")) compiler_options.module = .CommonJS else if (std.ascii.eqlIgnoreCase(val, "preserve")) compiler_options.module = .Preserve else if (std.ascii.eqlIgnoreCase(val, "esnext")) compiler_options.module = .ESNext else if (std.ascii.eqlIgnoreCase(val, "nodenext")) compiler_options.module = .NodeNext else if (std.ascii.eqlIgnoreCase(val, "node16")) compiler_options.module = .Node16;
        } else if (std.mem.eql(u8, key, "packageType")) {
            package_is_module = std.ascii.eqlIgnoreCase(val, "module");
        } else if (std.mem.eql(u8, key, "experimentalDecorators")) {
            compiler_options.experimentalDecorators = std.mem.eql(u8, val, "true");
        } else if (std.mem.eql(u8, key, "declaration")) {
            compiler_options.declaration = std.mem.eql(u8, val, "true");
        } else if (std.mem.eql(u8, key, "allowJs")) {
            compiler_options.allowJs = std.mem.eql(u8, val, "true");
        } else if (std.mem.eql(u8, key, "importHelpers")) {
            compiler_options.importHelpers = std.mem.eql(u8, val, "true");
        } else if (std.mem.eql(u8, key, "emitDecoratorMetadata")) {
            compiler_options.emitDecoratorMetadata = std.mem.eql(u8, val, "true");
        } else {
            inline for (std.meta.fields(core.CompilerOptions)) |field| {
                if (std.mem.eql(u8, key, field.name)) {
                    if (field.type == ?bool) {
                        @field(compiler_options, field.name) = std.ascii.eqlIgnoreCase(val, "true");
                    } else if (field.type == ?[]const u8) {
                        @field(compiler_options, field.name) = val;
                    }
                }
            }
        }
    }

    if (override_options) |overrides| mergeCompilerOptions(&compiler_options, overrides);

    // 1. Parse TS source to AST
    var p = parser_pkg.Parser.init(alloc, content);
    p.setScriptKind(scriptKindForPath(filepath));
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

    var declaration_output: ?[]const u8 = null;
    var declaration_mappings: ?[]const SourceMapping = null;
    if ((compiler_options.declaration orelse false) or (compiler_options.composite orelse false)) {
        var declaration_factory = factory_pkg.NodeFactory.init(alloc, &p.ast);
        var declaration_context = emitcontext_pkg.EmitContext.init(alloc, &p.ast, &declaration_factory);
        const declaration_tx = try @import("tsc").declarations.DeclarationTransformer.new(alloc, &declaration_context, semantic_program, semantic_file);
        const declaration_file = declaration_tx.transformSourceFile(astIndex);
        var declaration_writer = textwriter_pkg.TextWriter.init(alloc, "\n", 4);
        var declaration_emit_writer = declaration_writer.getEmitTextWriter();
        var declaration_printer = printer_pkg.Printer.init(&p.ast, &declaration_context, &declaration_emit_writer);
        var declaration_recorder = SourceMapRecorder{ .allocator = alloc, .mappings = .empty };
        if (compiler_options.declarationMap orelse false) declaration_printer.setSourceMapHook(.{ .context = &declaration_recorder, .addMapping = SourceMapRecorder.add });
        try declaration_printer.printSourceFile(declaration_file);
        declaration_output = declaration_writer.string();
        declaration_mappings = declaration_recorder.mappings.items;
    }

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
    const commonJsTx = try transformers_pkg.moduletransforms.commonjs.CommonJSModuleTransformer.new(alloc, &options);
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
    const module_kind = compiler_options.module orelse .None;
    const extension_forces_commonjs = std.mem.endsWith(u8, filepath, ".cts") or std.mem.endsWith(u8, filepath, ".cjs");
    const extension_forces_esm = std.mem.endsWith(u8, filepath, ".mts") or std.mem.endsWith(u8, filepath, ".mjs");
    const legacy_default_commonjs = module_kind == .None and (compiler_options.allowJs orelse false) and @intFromEnum(compiler_options.target orelse core.ScriptTarget.Latest) <= @intFromEnum(core.ScriptTarget.ES5);
    transformers_buf[tr_len] = if (extension_forces_commonjs or (!extension_forces_esm and (module_kind == .CommonJS or legacy_default_commonjs or ((module_kind == .Node16 or module_kind == .NodeNext) and !package_is_module)))) commonJsTx else esModuleTx;
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
    var source_map_recorder = SourceMapRecorder{ .allocator = alloc, .mappings = .empty };
    if ((compiler_options.sourceMap orelse false) or (compiler_options.inlineSourceMap orelse false) or (compiler_options.declarationMap orelse false)) pr.setSourceMapHook(.{ .context = &source_map_recorder, .addMapping = SourceMapRecorder.add });

    try pr.printSourceFile(transformedIndex);

    // 5. Output JS code
    const output = text_writer.string();
    if (!(compiler_options.emitDeclarationOnly orelse false)) {
        if (outpath) |out_path_str| {
            if (std.fs.path.dirname(out_path_str)) |directory| try std.Io.Dir.cwd().createDirPath(io, directory);
            var js_data = output;
            if (compiler_options.inlineSourceMap orelse false) {
                const map = try sourceMapText(alloc, filepath, out_path_str, source_map_recorder.mappings.items, &compiler_options, content);
                const encoded = try alloc.alloc(u8, std.base64.standard.Encoder.calcSize(map.len));
                _ = std.base64.standard.Encoder.encode(encoded, map);
                js_data = try withSourceMapUrl(alloc, output, try std.fmt.allocPrint(alloc, "data:application/json;base64,{s}", .{encoded}));
            } else if (compiler_options.sourceMap orelse false) {
                const map_path = try std.fmt.allocPrint(alloc, "{s}.map", .{out_path_str});
                const map = try sourceMapText(alloc, filepath, out_path_str, source_map_recorder.mappings.items, &compiler_options, content);
                try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = map_path, .data = map });
                js_data = try withSourceMapUrl(alloc, output, try sourceMapUrl(alloc, compiler_options.mapRoot, std.fs.path.basename(map_path)));
            }
            try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = out_path_str, .data = js_data });
        } else {
            std.debug.print("{s}\n", .{output});
        }
    }
    if (declaration_output) |text| {
        const declaration_path = try declarationPath(alloc, filepath, outpath, compiler_options.declarationDir);
        if (std.fs.path.dirname(declaration_path)) |directory| try std.Io.Dir.cwd().createDirPath(io, directory);
        var declaration_data = text;
        if (compiler_options.declarationMap orelse false) {
            const map_path = try std.fmt.allocPrint(alloc, "{s}.map", .{declaration_path});
            const recorded = declaration_mappings orelse &.{};
            const map = try sourceMapText(alloc, filepath, declaration_path, if (recorded.len != 0) recorded else source_map_recorder.mappings.items, &compiler_options, content);
            try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = map_path, .data = map });
            declaration_data = try withSourceMapUrl(alloc, text, try sourceMapUrl(alloc, compiler_options.mapRoot, std.fs.path.basename(map_path)));
        }
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = declaration_path, .data = declaration_data });
    }
}

fn scriptKindForPath(path: []const u8) core.ScriptKind {
    if (std.mem.endsWith(u8, path, ".jsx")) return .JSX;
    if (std.mem.endsWith(u8, path, ".js") or std.mem.endsWith(u8, path, ".mjs") or std.mem.endsWith(u8, path, ".cjs")) return .JS;
    if (std.mem.endsWith(u8, path, ".tsx")) return .TSX;
    if (std.mem.endsWith(u8, path, ".json")) return .JSON;
    return .TS;
}

fn withSourceMapUrl(allocator: std.mem.Allocator, text: []const u8, map_name: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}{s}//# sourceMappingURL={s}\n", .{ text, if (std.mem.endsWith(u8, text, "\n")) "" else "\n", map_name });
}

fn sourceMapUrl(allocator: std.mem.Allocator, map_root: ?[]const u8, map_name: []const u8) ![]const u8 {
    if (map_root) |root| return std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ root, if (std.mem.endsWith(u8, root, "/")) "" else "/", map_name });
    return allocator.dupe(u8, map_name);
}

fn sourceMapText(allocator: std.mem.Allocator, source: []const u8, generated: []const u8, mappings: []const SourceMapping, options: *const core.CompilerOptions, source_content: []const u8) ![]const u8 {
    var encoded: std.ArrayList(u8) = .empty;
    var generated_line: usize = 0;
    var generated_column: i64 = 0;
    var source_line: i64 = 0;
    var source_column: i64 = 0;
    var first_segment = true;
    for (mappings) |mapping| {
        while (generated_line < mapping.generated_line) : (generated_line += 1) {
            try encoded.append(allocator, ';');
            generated_column = 0;
            first_segment = true;
        }
        if (!first_segment) try encoded.append(allocator, ',');
        try appendVlq(allocator, &encoded, @as(i64, @intCast(mapping.generated_column)) - generated_column);
        generated_column = @intCast(mapping.generated_column);
        try appendVlq(allocator, &encoded, 0);
        try appendVlq(allocator, &encoded, @as(i64, @intCast(mapping.source_line)) - source_line);
        source_line = @intCast(mapping.source_line);
        try appendVlq(allocator, &encoded, @as(i64, @intCast(mapping.source_column)) - source_column);
        source_column = @intCast(mapping.source_column);
        first_segment = false;
    }
    const Map = struct { version: u8 = 3, file: []const u8, sourceRoot: []const u8, sources: []const []const u8, names: []const []const u8 = &.{}, mappings: []const u8, sourcesContent: ?[]const []const u8 = null };
    return std.json.Stringify.valueAlloc(allocator, Map{
        .file = std.fs.path.basename(generated),
        .sourceRoot = options.sourceRoot orelse "",
        .sources = &.{std.fs.path.basename(source)},
        .mappings = encoded.items,
        .sourcesContent = if (options.inlineSources orelse false) &.{source_content} else null,
    }, .{ .emit_null_optional_fields = false });
}

fn appendVlq(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: i64) !void {
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    var vlq: u64 = if (value < 0) (@as(u64, @intCast(-value)) << 1) | 1 else @as(u64, @intCast(value)) << 1;
    while (true) {
        var digit: u8 = @intCast(vlq & 31);
        vlq >>= 5;
        if (vlq != 0) digit |= 32;
        try output.append(allocator, alphabet[digit]);
        if (vlq == 0) break;
    }
}

fn declarationPath(allocator: std.mem.Allocator, input: []const u8, js_output: ?[]const u8, declaration_dir: ?[]const u8) ![]const u8 {
    const base = js_output orelse input;
    const extension: []const u8 = if (std.mem.endsWith(u8, input, ".mts") or std.mem.endsWith(u8, input, ".mjs")) ".d.mts" else if (std.mem.endsWith(u8, input, ".cts") or std.mem.endsWith(u8, input, ".cjs")) ".d.cts" else ".d.ts";
    const file_name = try std.fmt.allocPrint(allocator, "{s}{s}", .{ std.fs.path.stem(base), extension });
    if (declaration_dir) |directory| {
        const base_dir = std.fs.path.dirname(base) orelse ".";
        var dir = directory;
        while (dir.len > 0 and (dir[0] == '/' or dir[0] == '\\')) {
            dir = dir[1..];
        }
        return std.fs.path.join(allocator, &.{ base_dir, dir, file_name });
    }
    return std.fs.path.join(allocator, &.{ std.fs.path.dirname(base) orelse ".", file_name });
}

fn mergeCompilerOptions(target: *core.CompilerOptions, overrides: *const core.CompilerOptions) void {
    inline for (std.meta.fields(core.CompilerOptions)) |field| {
        const value = @field(overrides, field.name);
        if (@typeInfo(field.type) == .optional and value != null) @field(target, field.name) = value;
    }
}
