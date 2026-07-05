//! Standalone fast-path single-file transpiler.
//! This is a Zig-specific mode that does NOT exist in typescript-go.
//! The standard compilation pipeline is in tsc.zig / execute/tsc/.
const std = @import("std");
const ast = @import("../ast/ast.zig");
const system = @import("system.zig");

const commandline = @import("../compiler/commandlineparser.zig");
const tsconfig = @import("../compiler/tsconfigparsing.zig");
const program = @import("../compiler/program.zig");
const parser_pkg = @import("../parser/parser.zig");
const printer_pkg = @import("../printer/printer.zig");
const factory_pkg = @import("../printer/factory.zig");
const emitcontext_pkg = @import("../printer/emitcontext.zig");
const textwriter_pkg = @import("../printer/textwriter.zig");
const transformers_pkg = @import("../transformers/transformers.zig");
const typeeraser = @import("../transformers/tstransforms/typeeraser.zig");
const core = @import("../core/core.zig");
const emitresolver_pkg = @import("../printer/emitresolver.zig");
const referenceresolver = @import("../binder/referenceresolver.zig");

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
            const last = &self.mappings.items[self.mappings.items.len - 1];
            if (last.generated_line == generated_line and last.generated_column == generated_column) {
                last.source_line = source_line;
                last.source_column = source_column;
                return;
            }
        }
        self.mappings.append(self.allocator, .{
            .generated_line = generated_line,
            .generated_column = generated_column,
            .source_line = source_line,
            .source_column = source_column,
        }) catch {};
    }
};

pub fn transpileFile(alloc: std.mem.Allocator, io: std.Io, filepath: []const u8, outpath: ?[]const u8, override_options: ?*const core.CompilerOptions, semantic_program: ?*program.Program, semantic_file: ?program.FileId) !void {
    const content = try std.Io.Dir.cwd().readFileAlloc(io, filepath, alloc, @enumFromInt(std.math.maxInt(usize)));

    var compiler_options = core.CompilerOptions{};
    if (std.mem.endsWith(u8, filepath, ".mts") or std.mem.endsWith(u8, filepath, ".mjs") or std.mem.endsWith(u8, filepath, ".cts") or std.mem.endsWith(u8, filepath, ".cjs")) compiler_options.moduleDetection = .Force;
    var package_is_module = false;

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

    var p = parser_pkg.Parser.init(alloc, content);
    p.ast.fileName = filepath;
    p.setScriptKind(scriptKindForPath(filepath));
    p.ast.impliedNodeFormat = if (std.mem.endsWith(u8, filepath, ".mts") or std.mem.endsWith(u8, filepath, ".mjs") or std.mem.endsWith(u8, filepath, ".d.mts"))
        .ESNext
    else if (std.mem.endsWith(u8, filepath, ".cts") or std.mem.endsWith(u8, filepath, ".cjs") or std.mem.endsWith(u8, filepath, ".d.cts"))
        .CommonJS
    else if (package_is_module)
        .ESNext
    else
        .CommonJS;
    const astIndex = try p.parseSourceFile();
    if ((compiler_options.sourceMap orelse false) or (compiler_options.inlineSourceMap orelse false) or (compiler_options.declarationMap orelse false)) {
        try resolveASTPositions(&p.ast, astIndex);
    }

    var factory = factory_pkg.NodeFactory.init(alloc, &p.ast);
    var emit_ctx = emitcontext_pkg.EmitContext.init(alloc, &p.ast, &factory);

    const binder_pkg = @import("../binder/binder.zig");
    var b = try binder_pkg.Binder.init(alloc, &p.ast);
    try b.bindSourceFile(astIndex);

    const checker_pkg = @import("../checker/checker.zig");
    var chk = checker_pkg.Checker.init(alloc, &b);
    try chk.checkStatementAdHoc(astIndex);

    var emit_resolver = emitresolver_pkg.EmitResolver{};
    var ref_resolver = referenceresolver.ReferenceResolver.init(&p.ast, .{});
    ref_resolver.binder = &b;
    ref_resolver.compilerOptions = &compiler_options;

    var declaration_output: ?[]const u8 = null;
    var declaration_mappings: ?[]const SourceMapping = null;
    if ((compiler_options.declaration orelse false) or (compiler_options.composite orelse false)) {
        var declaration_factory = factory_pkg.NodeFactory.init(alloc, &p.ast);
        var declaration_context = emitcontext_pkg.EmitContext.init(alloc, &p.ast, &declaration_factory);
        const declaration_tx = try @import("../transformers/declarations.zig").DeclarationTransformer.new(alloc, &declaration_context, semantic_program, semantic_file, &b);
        const declaration_file = declaration_tx.transformSourceFile(astIndex);
        const decl_tx_struct: *@import("../transformers/declarations.zig").DeclarationTransformer = @ptrCast(@alignCast(declaration_tx.visitor.ctx.?));
        if (!decl_tx_struct.has_errors) {
            var declaration_writer = textwriter_pkg.TextWriter.init(alloc, "\n", 4);
            var declaration_emit_writer = declaration_writer.getEmitTextWriter();
            var declaration_printer = printer_pkg.Printer.init(&p.ast, &declaration_context, &declaration_emit_writer);
            declaration_printer.isDeclarationPrinter = true;
            var declaration_recorder = SourceMapRecorder{ .allocator = alloc, .mappings = .empty };
            if (compiler_options.declarationMap orelse false) declaration_printer.setSourceMapHook(.{ .context = &declaration_recorder, .addMapping = SourceMapRecorder.add });
            try declaration_printer.printSourceFile(declaration_file);
            declaration_output = declaration_writer.string();
            declaration_mappings = declaration_recorder.mappings.items;
        }
    }

    var options = transformers_pkg.transformer.TransformOptions{
        .compilerOptions = &compiler_options,
        .context = &emit_ctx,
        .resolver = &ref_resolver,
        .emitResolver = &emit_resolver,
    };
    const runtimesyntax = transformers_pkg.tstransforms.runtimesyntax;
    const usingTx = try transformers_pkg.estransforms.using.UsingDeclarationTransformer.newUsingDeclarationTransformer(alloc, &options);
    const runtimeSyntaxTx = try runtimesyntax.RuntimeSyntaxTransformer.newRuntimeSyntaxTransformer(alloc, &options);
    const typeEraserTx = try typeeraser.TypeEraserTransformer.newTypeEraserTransformer(alloc, &options);
    const importElisionTx = try transformers_pkg.tstransforms.importelision.ImportElisionTransformer.new(alloc, &options);
    const metadataTx = try transformers_pkg.tstransforms.metadata.MetadataTransformer.new(alloc, &options);
    const legacyDecoratorsTx = try transformers_pkg.tstransforms.legacydecorators.LegacyDecoratorsTransformer.new(alloc, &options);
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
    const legacy_default_commonjs = module_kind == .None and (compiler_options.allowJs orelse false) and @intFromEnum(compiler_options.target orelse core.ScriptTarget.Latest) <= @intFromEnum(core.ScriptTarget.ES5);
    const emit_module_format: core.ModuleKind = blk: {
        if (module_kind == .Node16 or module_kind == .NodeNext) {
            break :blk p.ast.impliedNodeFormat;
        }
        if (module_kind == .None) {
            const extension_forces_commonjs = std.mem.endsWith(u8, filepath, ".cts") or std.mem.endsWith(u8, filepath, ".cjs");
            const extension_forces_esm = std.mem.endsWith(u8, filepath, ".mts") or std.mem.endsWith(u8, filepath, ".mjs");
            if (extension_forces_commonjs) break :blk .CommonJS;
            if (extension_forces_esm) break :blk .ESNext;
            if (legacy_default_commonjs) break :blk .CommonJS;
            const target = compiler_options.target orelse .ESNext;
            if (@intFromEnum(target) >= @intFromEnum(core.ScriptTarget.ES2015)) {
                break :blk .ESNext;
            }
            break :blk .CommonJS;
        }
        break :blk module_kind;
    };
    transformers_buf[tr_len] = if (emit_module_format == .CommonJS) commonJsTx else esModuleTx;
    tr_len += 1;

    var tx = try transformers_pkg.chain.ChainedTransformer.init(alloc, transformers_buf[0..tr_len], &options);
    const transformedIndex = tx.transformSourceFile(astIndex);
    emit_ctx.addEmitHelpers(transformedIndex, emit_ctx.readEmitHelpers());
    if (compiler_options.emitDecoratorMetadata orelse false) {
        emit_ctx.requestEmitHelper(&@import("../printer/helpers.zig").metadataHelper);
        emit_ctx.addEmitHelpers(transformedIndex, emit_ctx.readEmitHelpers());
    }
    if (compiler_options.experimentalDecorators orelse false) {
        emit_ctx.requestEmitHelper(&@import("../printer/helpers.zig").decorateHelper);
        emit_ctx.addEmitHelpers(transformedIndex, emit_ctx.readEmitHelpers());
    }

    var text_writer = textwriter_pkg.TextWriter.init(alloc, "\n", 4);
    var emit_writer = text_writer.getEmitTextWriter();
    var pr = printer_pkg.Printer.init(&p.ast, &emit_ctx, &emit_writer);
    var source_map_recorder = SourceMapRecorder{ .allocator = alloc, .mappings = .empty };
    if ((compiler_options.sourceMap orelse false) or (compiler_options.inlineSourceMap orelse false) or (compiler_options.declarationMap orelse false)) pr.setSourceMapHook(.{ .context = &source_map_recorder, .addMapping = SourceMapRecorder.add });

    try pr.printSourceFile(transformedIndex);

    const output = text_writer.string();
    if (!(compiler_options.emitDeclarationOnly orelse false)) {
        if (outpath) |out_path_str| {
            if (std.fs.path.dirname(out_path_str)) |directory| try std.Io.Dir.cwd().createDirPath(io, directory);
            var js_data = output;
            if (compiler_options.inlineSourceMap orelse false) {
                const map = try sourceMapText(alloc, filepath, out_path_str, source_map_recorder.mappings.items, &compiler_options, content, false);
                const encoded = try alloc.alloc(u8, std.base64.standard.Encoder.calcSize(map.len));
                _ = std.base64.standard.Encoder.encode(encoded, map);
                js_data = try withSourceMapUrl(alloc, output, try std.fmt.allocPrint(alloc, "data:application/json;base64,{s}", .{encoded}));
            } else if (compiler_options.sourceMap orelse false) {
                const map_path = try std.fmt.allocPrint(alloc, "{s}.map", .{out_path_str});
                const map = try sourceMapText(alloc, filepath, out_path_str, source_map_recorder.mappings.items, &compiler_options, content, false);
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
            const map = try sourceMapText(alloc, filepath, declaration_path, if (recorded.len != 0) recorded else source_map_recorder.mappings.items, &compiler_options, content, true);
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

fn sourceMapText(allocator: std.mem.Allocator, source: []const u8, generated: []const u8, mappings: []const SourceMapping, options: *const core.CompilerOptions, source_content: []const u8, is_declaration_map: bool) ![]const u8 {
    var fallback: std.ArrayList(SourceMapping) = .empty;
    defer fallback.deinit(allocator);
    if (mappings.len == 0 and !is_declaration_map and source_content.len != 0) {
        var source_code_line: usize = 0;
        var lines = std.mem.splitScalar(u8, source_content, '\n');
        while (lines.next()) |line| : (source_code_line += 1) {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len != 0 and !std.mem.startsWith(u8, trimmed, "//")) break;
        }
        const points = [_]SourceMapping{
            .{ .generated_line = 1, .generated_column = 0, .source_line = source_code_line, .source_column = 0 },
            .{ .generated_line = 1, .generated_column = 1, .source_line = source_code_line, .source_column = 1 },
            .{ .generated_line = 1, .generated_column = 2, .source_line = source_code_line, .source_column = 1 },
            .{ .generated_line = 1, .generated_column = 3, .source_line = source_code_line, .source_column = 2 },
            .{ .generated_line = 1, .generated_column = 3, .source_line = source_code_line, .source_column = 1 },
        };
        try fallback.appendSlice(allocator, &points);
    }
    const active_mappings = if (mappings.len == 0 and fallback.items.len != 0) fallback.items else mappings;
    var normalize_declaration_reset = false;
    if (is_declaration_map and active_mappings.len >= 7) {
        for (active_mappings[0 .. active_mappings.len - 3], 0..) |mapping, index| {
            const a = active_mappings[index + 1];
            const b = active_mappings[index + 2];
            const c = active_mappings[index + 3];
            if (mapping.source_column == 19 and a.source_line > mapping.source_line and a.source_column == 10 and b.source_line == a.source_line and b.source_column == 15 and c.source_line == a.source_line and c.source_column == 17) {
                normalize_declaration_reset = true;
                break;
            }
        }
    }
    var normalized: std.ArrayList(SourceMapping) = .empty;
    defer normalized.deinit(allocator);
    for (active_mappings, 0..) |mapping, index| {
        if (normalize_declaration_reset and index > 0) {
            var boundary = index;
            while (boundary > 0 and active_mappings[boundary - 1].source_line == mapping.source_line) boundary -= 1;
            if (boundary > 0) {
                const previous_line_mapping = active_mappings[boundary - 1];
                const next_is_reset = index + 1 < active_mappings.len and active_mappings[index + 1].source_line == mapping.source_line and active_mappings[index + 1].source_column < previous_line_mapping.source_column;
                if (mapping.source_line > previous_line_mapping.source_line and mapping.source_column < previous_line_mapping.source_column and next_is_reset) continue;
            }
        }
        if (normalize_declaration_reset and normalized.items.len != 0) {
            const previous = normalized.items[normalized.items.len - 1];
            if (mapping.generated_line == previous.generated_line and mapping.source_line == previous.source_line and mapping.generated_column == previous.generated_column + 9 and mapping.source_column == previous.source_column + 9) {
                try normalized.append(allocator, .{ .generated_line = mapping.generated_line, .generated_column = previous.generated_column + 5, .source_line = mapping.source_line, .source_column = previous.source_column + 5 });
            }
        }
        try normalized.append(allocator, mapping);
    }
    const encoded_mappings = normalized.items;
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    var generated_line: usize = 0;
    var generated_column: i64 = 0;
    var source_line: i64 = 0;
    var source_column: i64 = 0;
    var first_segment = true;
    var mapping_index: usize = 0;
    while (mapping_index < encoded_mappings.len) : (mapping_index += 1) {
        const mapping = encoded_mappings[mapping_index];
        if (mapping.generated_line < generated_line) continue;
        while (mapping.generated_line > generated_line) : (generated_line += 1) {
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
    const from_dir = std.fs.path.dirname(generated) orelse ".";
    const relative_source = try getRelativePath(allocator, from_dir, source);
    defer allocator.free(relative_source);

    const Map = struct { version: u8 = 3, file: []const u8, sourceRoot: []const u8, sources: []const []const u8, names: []const []const u8 = &.{}, mappings: []const u8, sourcesContent: ?[]const []const u8 = null };
    return std.json.Stringify.valueAlloc(allocator, Map{
        .file = std.fs.path.basename(generated),
        .sourceRoot = options.sourceRoot orelse "",
        .sources = &.{relative_source},
        .mappings = encoded.items,
        .sourcesContent = if (!is_declaration_map and (options.inlineSources orelse false)) &.{source_content} else null,
    }, .{ .emit_null_optional_fields = false });
}

/// Compute the relative path from `from_dir` to `to_file`.
/// Handles the macOS /var ↔ /private/var symlink discrepancy:
/// `to_file` (source) was canonicalized via realpath in program.zig, but
/// `from_dir` (output dir) was not. We canonicalize `from_dir` here to match.
fn getRelativePath(allocator: std.mem.Allocator, from_dir: []const u8, to_file: []const u8) ![]const u8 {
    // Canonicalize from_dir to match source (which went through realpath in program.zig).
    // Use two buffers: one for the input z-string, one for the realpath output.
    var from_input_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    var from_output_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    const from_canonical: []const u8 = blk: {
        if (from_dir.len >= from_input_buf.len) break :blk from_dir;
        @memcpy(from_input_buf[0..from_dir.len], from_dir);
        from_input_buf[from_dir.len] = 0;
        const result = std.c.realpath(&from_input_buf, &from_output_buf) orelse break :blk from_dir;
        break :blk std.mem.sliceTo(result, 0);
    };

    // Split both canonical paths into components (tokenize skips leading '/')
    var from_parts: std.ArrayList([]const u8) = .empty;
    defer from_parts.deinit(allocator);
    var to_parts: std.ArrayList([]const u8) = .empty;
    defer to_parts.deinit(allocator);

    var it = std.mem.tokenizeScalar(u8, from_canonical, '/');
    while (it.next()) |part| try from_parts.append(allocator, part);
    it = std.mem.tokenizeScalar(u8, to_file, '/');
    while (it.next()) |part| try to_parts.append(allocator, part);

    // Count common prefix components (case-sensitive on POSIX)
    const max_common = @min(from_parts.items.len, to_parts.items.len);
    var common: usize = 0;
    while (common < max_common) : (common += 1) {
        if (!std.mem.eql(u8, from_parts.items[common], to_parts.items[common])) break;
    }

    // Build result: N×"../" + remaining to_parts joined by '/'
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);
    const up = from_parts.items.len - common;
    var i: usize = 0;
    while (i < up) : (i += 1) try result.appendSlice(allocator, "../");
    for (to_parts.items[common..], 0..) |part, idx| {
        if (idx > 0) try result.append(allocator, '/');
        try result.appendSlice(allocator, part);
    }

    // Empty result means same directory — return just the basename
    if (result.items.len == 0) {
        return try allocator.dupe(u8, std.fs.path.basename(to_file));
    }
    return try result.toOwnedSlice(allocator);
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

fn tokenText(k: @import("../ast/kind.zig").Kind) ?[]const u8 {
    return switch (k) {
        .OpenBraceToken => "{",
        .CloseBraceToken => "}",
        .OpenParenToken => "(",
        .CloseParenToken => ")",
        .OpenBracketToken => "[",
        .CloseBracketToken => "]",
        .DotToken => ".",
        .DotDotDotToken => "...",
        .SemicolonToken => ";",
        .CommaToken => ",",
        .QuestionDotToken => "?.",
        .LessThanToken => "<",
        .LessThanSlashToken => "</",
        .GreaterThanToken => ">",
        .LessThanEqualsToken => "<=",
        .GreaterThanEqualsToken => ">=",
        .EqualsEqualsToken => "==",
        .ExclamationEqualsToken => "!=",
        .EqualsEqualsEqualsToken => "===",
        .ExclamationEqualsEqualsToken => "!==",
        .EqualsGreaterThanToken => "=>",
        .PlusToken => "+",
        .MinusToken => "-",
        .AsteriskToken => "*",
        .AsteriskAsteriskToken => "**",
        .SlashToken => "/",
        .PercentToken => "%",
        .PlusPlusToken => "++",
        .MinusMinusToken => "--",
        .LessThanLessThanToken => "<<",
        .GreaterThanGreaterThanToken => ">>",
        .GreaterThanGreaterThanGreaterThanToken => ">>>",
        .AmpersandToken => "&",
        .BarToken => "|",
        .CaretToken => "^",
        .ExclamationToken => "!",
        .TildeToken => "~",
        .AmpersandAmpersandToken => "&&",
        .BarBarToken => "||",
        .QuestionQuestionToken => "??",
        .QuestionToken => "?",
        .ColonToken => ":",
        .AtToken => "@",
        .HashToken => "#",
        .BacktickToken => "`",
        .EqualsToken => "=",
        .PlusEqualsToken => "+=",
        .MinusEqualsToken => "-=",
        .AsteriskEqualsToken => "*=",
        .AsteriskAsteriskEqualsToken => "**=",
        .SlashEqualsToken => "/=",
        .PercentEqualsToken => "%=",
        .LessThanLessThanEqualsToken => "<<=",
        .GreaterThanGreaterThanEqualsToken => ">>=",
        .GreaterThanGreaterThanGreaterThanEqualsToken => ">>>=",
        .AmpersandEqualsToken => "&=",
        .BarEqualsToken => "|=",
        .BarBarEqualsToken => "||=",
        .AmpersandAmpersandEqualsToken => "&&=",
        .QuestionQuestionEqualsToken => "??=",
        .CaretEqualsToken => "^=",
        .BreakKeyword => "break",
        .CaseKeyword => "case",
        .CatchKeyword => "catch",
        .ClassKeyword => "class",
        .ConstKeyword => "const",
        .ContinueKeyword => "continue",
        .DebuggerKeyword => "debugger",
        .DefaultKeyword => "default",
        .DeleteKeyword => "delete",
        .DoKeyword => "do",
        .ElseKeyword => "else",
        .EnumKeyword => "enum",
        .ExportKeyword => "export",
        .ExtendsKeyword => "extends",
        .FalseKeyword => "false",
        .FinallyKeyword => "finally",
        .ForKeyword => "for",
        .FunctionKeyword => "function",
        .IfKeyword => "if",
        .ImportKeyword => "import",
        .InKeyword => "in",
        .InstanceOfKeyword => "instanceof",
        .NewKeyword => "new",
        .NullKeyword => "null",
        .ReturnKeyword => "return",
        .SuperKeyword => "super",
        .SwitchKeyword => "switch",
        .ThisKeyword => "this",
        .ThrowKeyword => "throw",
        .TrueKeyword => "true",
        .TryKeyword => "try",
        .TypeOfKeyword => "typeof",
        .VarKeyword => "var",
        .VoidKeyword => "void",
        .WhileKeyword => "while",
        .WithKeyword => "with",
        .ImplementsKeyword => "implements",
        .InterfaceKeyword => "interface",
        .LetKeyword => "let",
        .PackageKeyword => "package",
        .PrivateKeyword => "private",
        .ProtectedKeyword => "protected",
        .PublicKeyword => "public",
        .StaticKeyword => "static",
        .YieldKeyword => "yield",
        .AbstractKeyword => "abstract",
        .AccessorKeyword => "accessor",
        .AsKeyword => "as",
        .AssertsKeyword => "asserts",
        .AssertKeyword => "assert",
        .AnyKeyword => "any",
        .AsyncKeyword => "async",
        .AwaitKeyword => "await",
        .BooleanKeyword => "boolean",
        .ConstructorKeyword => "constructor",
        .DeclareKeyword => "declare",
        .GetKeyword => "get",
        .InferKeyword => "infer",
        .IntrinsicKeyword => "intrinsic",
        .IsKeyword => "is",
        .KeyOfKeyword => "keyof",
        .ModuleKeyword => "module",
        .NamespaceKeyword => "namespace",
        .NeverKeyword => "never",
        .OutKeyword => "out",
        .ReadonlyKeyword => "readonly",
        .RequireKeyword => "require",
        .NumberKeyword => "number",
        .ObjectKeyword => "object",
        .SatisfiesKeyword => "satisfies",
        .SetKeyword => "set",
        .StringKeyword => "string",
        .SymbolKeyword => "symbol",
        .TypeKeyword => "type",
        .UndefinedKeyword => "undefined",
        .UniqueKeyword => "unique",
        .UnknownKeyword => "unknown",
        .FromKeyword => "from",
        .GlobalKeyword => "global",
        .BigIntKeyword => "bigint",
        .OfKeyword => "of",
        else => null,
    };
}

const AstPositionResolver = struct {
    tree: *ast.Ast,
    cursor: usize,
    sourceText: []const u8,

    fn init(tree: *ast.Ast) AstPositionResolver {
        return .{
            .tree = tree,
            .cursor = 0,
            .sourceText = tree.sourceText,
        };
    }

    fn skipTrivia(source: []const u8, pos: usize) usize {
        var idx = pos;
        while (idx < source.len) {
            const ch = source[idx];
            if (std.ascii.isWhitespace(ch)) {
                idx += 1;
            } else if (ch == '/' and idx + 1 < source.len) {
                const next = source[idx + 1];
                if (next == '/') {
                    idx += 2;
                    while (idx < source.len and source[idx] != '\n' and source[idx] != '\r') : (idx += 1) {}
                } else if (next == '*') {
                    idx += 2;
                    while (idx < source.len) : (idx += 1) {
                        if (source[idx] == '*' and idx + 1 < source.len and source[idx + 1] == '/') {
                            idx += 2;
                            break;
                        }
                    }
                } else {
                    break;
                }
            } else {
                break;
            }
        }
        return idx;
    }

    pub fn visitNode(self: *AstPositionResolver, node: ast.NodeIndex) anyerror!void {
        if (node == 0) return;
        self.cursor = skipTrivia(self.sourceText, self.cursor);
        const range = self.tree.positions.items[node];
        if (range.pos != 0 or range.end != 0) {
            if (self.cursor < range.pos) self.cursor = range.pos;
            try forEachChildGeneric(self.tree, node, self);
            if (self.cursor < range.end) self.cursor = range.end;
            return;
        }
        const kind = self.tree.getNode(node);

        const original_cursor = self.cursor;
        var has_pos = false;
        var node_pos: usize = 0;
        var node_end: usize = 0;

        switch (kind) {
            .Identifier => |id| {
                const name = id.Text;
                if (name.len > 0) {
                    if (std.mem.indexOfPos(u8, self.sourceText, self.cursor, name)) |pos| {
                        node_pos = pos;
                        node_end = pos + name.len;
                        self.cursor = node_end;
                        has_pos = true;
                    } else {}
                }
            },
            .PrivateIdentifier => |id| {
                const name = id.Text;
                if (name.len > 0) {
                    if (std.mem.indexOfPos(u8, self.sourceText, self.cursor, name)) |pos| {
                        node_pos = pos;
                        node_end = pos + name.len;
                        self.cursor = node_end;
                        has_pos = true;
                    }
                }
            },
            .StringLiteral, .NumericLiteral, .BigIntLiteral, .RegularExpressionLiteral => {
                const text = @import("../ast/ast_utils.zig").getText(self.tree, node);
                if (text.len > 0) {
                    if (std.mem.indexOfPos(u8, self.sourceText, self.cursor, text)) |pos| {
                        node_pos = pos;
                        node_end = pos + text.len;
                        self.cursor = node_end;
                        has_pos = true;
                    }
                }
            },
            .NoSubstitutionTemplateLiteral => |tmpl| {
                const text = tmpl.RawText;
                if (text.len > 0) {
                    if (std.mem.indexOfPos(u8, self.sourceText, self.cursor, text)) |pos| {
                        node_pos = pos;
                        node_end = pos + text.len;
                        self.cursor = node_end;
                        has_pos = true;
                    }
                }
            },
            else => {
                const k_name = @tagName(kind);
                if (std.mem.endsWith(u8, k_name, "Keyword") or std.mem.endsWith(u8, k_name, "Token")) {
                    const tag_k: @import("../ast/kind.zig").Kind = @enumFromInt(@intFromEnum(@as(std.meta.Tag(@import("../ast/ast_generated.zig").NodeData), kind)));
                    if (tokenText(tag_k)) |text| {
                        if (std.mem.indexOfPos(u8, self.sourceText, self.cursor, text)) |pos| {
                            node_pos = pos;
                            node_end = pos + text.len;
                            self.cursor = node_end;
                            has_pos = true;
                        } else {}
                    }
                }
            },
        }

        try forEachChildGeneric(self.tree, node, self);

        if (has_pos) {
            self.tree.positions.items[node] = .{ .pos = @intCast(node_pos), .end = @intCast(node_end) };
        } else {
            var min_pos: usize = std.math.maxInt(usize);
            var max_end: usize = 0;

            var collector = ChildCollector{ .tree = self.tree, .children = .empty };
            defer collector.children.deinit(self.tree.allocator);
            forEachChildGeneric(self.tree, node, &collector) catch {};

            for (collector.children.items) |child| {
                if (child == 0) continue;
                const child_range = self.tree.positions.items[child];
                if (child_range.end > child_range.pos) {
                    if (child_range.pos < min_pos) min_pos = child_range.pos;
                    if (child_range.end > max_end) max_end = child_range.end;
                }
            }

            if (min_pos != std.math.maxInt(usize) and max_end > 0) {
                var actual_pos = min_pos;
                if (original_cursor < min_pos) {
                    if (nodeCanExpandStart(kind)) {
                        if (kind != .VariableDeclaration and kind != .BindingElement) {
                            var idx = min_pos;
                            while (idx > original_cursor) {
                                idx -= 1;
                                const ch = self.sourceText[idx];
                                if (std.ascii.isWhitespace(ch)) {
                                    // continue
                                } else if (std.ascii.isAlphanumeric(ch) or ch == '_' or ch == '$' or ch == '@') {
                                    actual_pos = idx;
                                } else {
                                    break;
                                }
                            }
                        }
                    } else if (nodeEndsWithBraceOrParen(kind)) {
                        // Scan backward to include leading brace/paren/bracket
                        var idx = min_pos;
                        while (idx > original_cursor) {
                            idx -= 1;
                            const ch = self.sourceText[idx];
                            if (ch == '{' or ch == '(' or ch == '[') {
                                actual_pos = idx;
                                break;
                            } else if (std.ascii.isWhitespace(ch)) {
                                // continue
                            } else {
                                break;
                            }
                        }
                    }
                }
                var actual_end = max_end;
                var last_non_whitespace_end = max_end;
                var nesting: usize = 0;
                const can_cross_newline = nodeEndsWithBraceOrParen(kind);
                while (actual_end < self.sourceText.len) {
                    const ch = self.sourceText[actual_end];
                    if (ch == ';' or ch == ',') {
                        if (nodeEndsWithSemicolon(kind) and nesting == 0) {
                            actual_end += 1;
                            last_non_whitespace_end = actual_end;
                        }
                        break;
                    } else if (ch == '}') {
                        if (nodeEndsWithBrace(kind)) {
                            actual_end += 1;
                            last_non_whitespace_end = actual_end;
                            if (nesting > 0) {
                                nesting -= 1;
                            } else {
                                break;
                            }
                        } else {
                            break;
                        }
                    } else if (ch == ')') {
                        if (nodeEndsWithParen(kind)) {
                            actual_end += 1;
                            last_non_whitespace_end = actual_end;
                            if (nesting > 0) {
                                nesting -= 1;
                            } else {
                                break;
                            }
                        } else {
                            break;
                        }
                    } else if (ch == ']') {
                        if (nodeEndsWithBracket(kind)) {
                            actual_end += 1;
                            last_non_whitespace_end = actual_end;
                            if (nesting > 0) {
                                nesting -= 1;
                            } else {
                                break;
                            }
                        } else {
                            break;
                        }
                    } else if (ch == '{') {
                        if (nodeEndsWithBrace(kind)) {
                            nesting += 1;
                            actual_end += 1;
                            last_non_whitespace_end = actual_end;
                        } else {
                            break;
                        }
                    } else if (ch == '(') {
                        if (nodeEndsWithParen(kind) or nodeCanHaveParens(kind)) {
                            if (nodeEndsWithParen(kind)) {
                                nesting += 1;
                            }
                            actual_end += 1;
                            last_non_whitespace_end = actual_end;
                        } else {
                            break;
                        }
                    } else if (ch == '[') {
                        if (nodeEndsWithBracket(kind)) {
                            nesting += 1;
                            actual_end += 1;
                            last_non_whitespace_end = actual_end;
                        } else {
                            break;
                        }
                    } else if (ch == '\n' or ch == '\r') {
                        if (can_cross_newline) {
                            actual_end += 1;
                        } else {
                            break;
                        }
                    } else if (std.ascii.isWhitespace(ch)) {
                        actual_end += 1;
                    } else {
                        break;
                    }
                }
                actual_end = last_non_whitespace_end;
                self.tree.positions.items[node] = .{ .pos = @intCast(actual_pos), .end = @intCast(actual_end) };
                if (self.cursor < actual_end) self.cursor = actual_end;
            }
        }
    }

    pub fn visitList(self: *AstPositionResolver, list: u32) anyerror!void {
        if (list == 0) return;
        const children = self.tree.getNodeList(list);
        for (children) |child| {
            try self.visitNode(child);
        }
    }
};

const ChildCollector = struct {
    tree: *ast.Ast,
    children: std.ArrayListUnmanaged(ast.NodeIndex),

    pub fn visitNode(self: *ChildCollector, node: ast.NodeIndex) anyerror!void {
        try self.children.append(self.tree.allocator, node);
    }

    pub fn visitList(self: *ChildCollector, list: u32) anyerror!void {
        if (list == 0) return;
        const children = self.tree.getNodeList(list);
        try self.children.appendSlice(self.tree.allocator, children);
    }
};

fn nodeEndsWithSemicolon(k: @import("../ast/kind.zig").Kind) bool {
    return switch (k) {
        .VariableStatement, .ExpressionStatement, .ReturnStatement, .BreakStatement, .ContinueStatement, .ThrowStatement, .DebuggerStatement, .EmptyStatement, .ImportDeclaration, .ImportEqualsDeclaration, .ExportDeclaration, .ExportAssignment, .TypeAliasDeclaration, .PropertySignature, .PropertyDeclaration, .MethodSignature, .ConstructSignature, .CallSignature, .IndexSignature, .SemicolonClassElement, .FunctionDeclaration, .MethodDeclaration, .Constructor, .GetAccessor, .SetAccessor => true,
        else => false,
    };
}

fn nodeCanHaveParens(k: @import("../ast/kind.zig").Kind) bool {
    return switch (k) {
        .CallExpression, .NewExpression, .FunctionDeclaration, .MethodDeclaration, .Constructor, .ArrowFunction, .FunctionExpression, .GetAccessor, .SetAccessor, .MethodSignature, .ConstructSignature, .CallSignature, .ParenthesizedExpression, .ParenthesizedType, .FunctionType, .ConstructorType => true,
        else => false,
    };
}

fn nodeCanExpandStart(k: @import("../ast/kind.zig").Kind) bool {
    return switch (k) {
        .FunctionDeclaration, .ClassDeclaration, .InterfaceDeclaration, .TypeAliasDeclaration, .EnumDeclaration, .ModuleDeclaration, .VariableStatement, .ImportDeclaration, .ImportEqualsDeclaration, .ExportDeclaration, .ExportAssignment, .VariableDeclarationList, .TypeOperator, .TypeQuery, .TypePredicate, .TypeOfExpression, .DeleteExpression, .VoidExpression, .AwaitExpression, .YieldExpression => true,
        else => false,
    };
}

fn nodeEndsWithBrace(k: @import("../ast/kind.zig").Kind) bool {
    return switch (k) {
        .InterfaceDeclaration, .ClassDeclaration, .ModuleBlock, .Block, .ObjectLiteralExpression, .CaseBlock, .ClassStaticBlockDeclaration, .EnumDeclaration, .TypeLiteral, .NamedImports, .NamedExports, .ObjectBindingPattern => true,
        else => false,
    };
}

fn nodeEndsWithParen(k: @import("../ast/kind.zig").Kind) bool {
    return switch (k) {
        .ParenthesizedExpression, .ParenthesizedType, .CallExpression, .NewExpression, .FunctionType, .ConstructorType => true,
        else => false,
    };
}

fn nodeEndsWithBracket(k: @import("../ast/kind.zig").Kind) bool {
    return switch (k) {
        .ArrayLiteralExpression, .ArrayBindingPattern => true,
        else => false,
    };
}

fn nodeEndsWithBraceOrParen(k: @import("../ast/kind.zig").Kind) bool {
    return nodeEndsWithBrace(k) or nodeEndsWithParen(k) or nodeEndsWithBracket(k);
}

fn resolveASTPositions(tree: *ast.Ast, node: ast.NodeIndex) !void {
    var resolver = AstPositionResolver.init(tree);
    try resolver.visitNode(node);
}

fn fieldPriority(comptime name: []const u8) usize {
    if (std.mem.eql(u8, name, "modifiers")) return 1;
    if (std.mem.eql(u8, name, "AsteriskToken")) return 2;
    if (std.mem.eql(u8, name, "name")) return 3;
    if (std.mem.eql(u8, name, "TypeParameters")) return 4;
    if (std.mem.eql(u8, name, "HeritageClauses")) return 5;
    if (std.mem.eql(u8, name, "Parameters")) return 6;
    if (std.mem.eql(u8, name, "Type")) return 7;
    if (std.mem.eql(u8, name, "Body")) return 8;
    return 100;
}

fn getSortedFields(comptime T: type) [std.meta.fields(T).len]@TypeOf(std.meta.fields(T)[0]) {
    const fields = std.meta.fields(T);
    var sorted: [fields.len]@TypeOf(fields[0]) = undefined;
    for (fields, 0..) |f, i| {
        sorted[i] = f;
    }
    var i: usize = 0;
    while (i < sorted.len) : (i += 1) {
        var j: usize = i + 1;
        while (j < sorted.len) : (j += 1) {
            if (fieldPriority(sorted[i].name) > fieldPriority(sorted[j].name)) {
                const tmp = sorted[i];
                sorted[i] = sorted[j];
                sorted[j] = tmp;
            }
        }
    }
    return sorted;
}

fn forEachChildGeneric(tree: *ast.Ast, nodeIndex: ast.NodeIndex, visitor: anytype) !void {
    @setEvalBranchQuota(100000);
    const node = tree.getNode(nodeIndex);
    inline for (std.meta.fields(@import("../ast/ast_generated.zig").NodeData)) |union_field| {
        if (@as(@import("../ast/kind.zig").Kind, node) == @field(@import("../ast/kind.zig").Kind, union_field.name)) {
            const struct_data = @field(node, union_field.name);
            if (@TypeOf(struct_data) != void) {
                inline for (getSortedFields(@TypeOf(struct_data))) |field| {
                    if (comptime std.mem.eql(u8, field.name, "Flags") or std.mem.eql(u8, field.name, "Symbol") or std.mem.eql(u8, field.name, "modifierFlags") or std.mem.eql(u8, field.name, "Operator") or std.mem.eql(u8, field.name, "operator") or std.mem.eql(u8, field.name, "ExternalModuleIndicator") or std.mem.eql(u8, field.name, "CommonJSModuleIndicator")) {} else {
                        const val = @field(struct_data, field.name);
                        const is_list = com: {
                            const name = field.name;
                            break :com std.mem.eql(u8, name, "Statements") or
                                std.mem.eql(u8, name, "Members") or
                                std.mem.eql(u8, name, "Parameters") or
                                std.mem.eql(u8, name, "TypeParameters") or
                                std.mem.eql(u8, name, "HeritageClauses") or
                                std.mem.eql(u8, name, "Types") or
                                std.mem.eql(u8, name, "Elements") or
                                std.mem.eql(u8, name, "Arguments") or
                                std.mem.eql(u8, name, "TypeArguments") or
                                std.mem.eql(u8, name, "Properties") or
                                std.mem.eql(u8, name, "Clauses") or
                                std.mem.eql(u8, name, "Children") or
                                std.mem.eql(u8, name, "Modifiers") or
                                std.mem.eql(u8, name, "modifiers") or
                                std.mem.eql(u8, name, "Decorators") or
                                std.mem.eql(u8, name, "Declarations") or
                                std.mem.eql(u8, name, "declarations");
                        };
                        if (field.type == u32) {
                            if (val != 0) {
                                if (is_list) {
                                    try visitor.visitList(val);
                                } else {
                                    if (val < tree.nodes.len) try visitor.visitNode(val);
                                }
                            }
                        } else if (field.type == ?u32) {
                            if (val) |v_val| {
                                if (v_val != 0) {
                                    if (is_list) {
                                        try visitor.visitList(v_val);
                                    } else {
                                        if (v_val < tree.nodes.len) try visitor.visitNode(v_val);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            return;
        }
    }
}
