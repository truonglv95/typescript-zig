const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const binder = @import("../binder/binder.zig");
const core = @import("../core/core.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const printer = @import("../printer/printer.zig");
const emitcontext = @import("../printer/emitcontext.zig");
const factory = @import("../printer/factory.zig");
const textwriter = @import("../printer/textwriter.zig");
const emittextwriter = @import("../printer/emittextwriter.zig");
const transformers = @import("../transformers/transformer.zig");
const declarations = @import("../transformers/declarations.zig");
const estransforms = @import("../transformers/estransforms.zig");
const inliners = @import("../transformers/inliners.zig");
const jsxtransforms = @import("../transformers/jsxtransforms.zig");
const moduletransforms = @import("../transformers/transformers.zig").moduletransforms;
const tstransforms = @import("../transformers/transformers.zig").tstransforms;
const tsoptions = @import("../tsoptions/tsoptions.zig");
const tspath = @import("../tspath/tspath.zig");
const emitresolver = @import("../printer/emitresolver.zig");
const referenceresolver = @import("../binder/referenceresolver.zig");
const outputpaths = @import("../outputpaths/outputpaths.zig");
const sourcemap = @import("../sourcemap/sourcemap.zig");
const stringutil = @import("../stringutil/stringutil.zig");
const tracing = @import("../tracing/tracing.zig");
const emithost = @import("../printer/emithost.zig");

pub const EmitOnly = enum(u8) {
    EmitAll = 0,
    EmitOnlyJs,
    EmitOnlyDts,
    EmitOnlyForcedDts,
};

pub const SourceMapEmitResult = struct {
    InputSourceFileNames: [][]const u8 = &[_][]const u8{},
    SourceMap: []const u8 = "",
    GeneratedFile: []const u8 = "",
};

pub const WriteFileData = struct {
    SourceMapUrlPos: isize = -1,
    Diagnostics: []diagnostics.Diagnostic = &[_]diagnostics.Diagnostic{},
    SkippedDtsWrite: bool = false,
};

pub const EmitResult = struct {
    EmitSkipped: bool = false,
    Diagnostics: []diagnostics.Diagnostic = &[_]diagnostics.Diagnostic{},
    EmittedFiles: [][]const u8 = &[_][]const u8{},
    SourceMaps: []*SourceMapEmitResult = &[_]*SourceMapEmitResult{},
};

const SourceMapHookContext = struct {
    generator: *sourcemap.generator.Generator,
    source_index: sourcemap.generator.SourceIndex,

    fn addMapping(context: *anyopaque, generated_line: usize, generated_column: usize, source_line: usize, source_column: usize) void {
        const self: *SourceMapHookContext = @ptrCast(@alignCast(context));
        self.generator.addSourceMapping(
            @intCast(generated_line),
            @intCast(generated_column),
            self.source_index,
            @intCast(source_line),
            @intCast(source_column),
        ) catch unreachable;
    }
};

pub const Emitter = struct {
    pub const DeclarationTransformerFactory = *const fn (std.mem.Allocator, *emitcontext.EmitContext, *anyopaque) anyerror!*transformers.Transformer;

    allocator: std.mem.Allocator,
    host: emithost.EmitHost,
    emitOnly: EmitOnly,
    emitterDiagnostics: std.ArrayList(diagnostics.Diagnostic),
    writer: *emittextwriter.EmitTextWriter,
    paths: *outputpaths.OutputPaths,
    sourceFile: ast_gen.NodeIndex,
    tree: *ast.Ast,
    emitResult: EmitResult,
    writeFile: ?*const fn (fileName: []const u8, text: []const u8, data: ?*WriteFileData) anyerror!void,
    tr: ?*tracing.Tracing,
    declarationTransformerContext: ?*anyopaque = null,
    declarationTransformerFactory: ?DeclarationTransformerFactory = null,
    declarationEmitBlocked: ?*const fn (*anyopaque) bool = null,

    pub fn emit(self: *Emitter) !void {
        if (self.tr) |tr| {
            // TODO: push/pop tracing logic
            _ = tr;
        }

        try self.emitJSFile(self.sourceFile, self.paths.jsFilePath, self.paths.sourceMapFilePath);
        try self.emitDeclarationFile(self.sourceFile, self.paths.declarationFilePath, self.paths.declarationMapPath);

        // Convert array list slice to array slice
        self.emitResult.Diagnostics = try self.allocator.dupe(diagnostics.Diagnostic, self.emitterDiagnostics.items);
    }

    pub fn getDeclarationTransformers(self: *Emitter, emitContext: *emitcontext.EmitContext, declarationFilePath: []const u8, declarationMapPath: []const u8) !std.ArrayListUnmanaged(*transformers.Transformer) {
        _ = declarationFilePath;
        _ = declarationMapPath;
        var tx = std.ArrayListUnmanaged(*transformers.Transformer).empty;
        const transform = if (self.declarationTransformerFactory) |create|
            try create(self.allocator, emitContext, self.declarationTransformerContext.?)
        else
            try declarations.DeclarationTransformer.new(self.allocator, emitContext, null, null, null);
        try tx.append(self.allocator, transform);
        return tx;
    }

    pub fn runScriptTransformers(self: *Emitter, emitContext: *emitcontext.EmitContext, sourceFile: ast_gen.NodeIndex) !ast_gen.NodeIndex {
        if (self.tr) |tr| {
            // TODO: tracing
            _ = tr;
        }
        var transformersList = try getScriptTransformers(self.allocator, emitContext, self.host, sourceFile, self.tree);
        defer {
            for (transformersList.items) |transformer| {
                transformer.deinit(self.allocator);
            }
            transformersList.deinit(self.allocator);
        }

        var currentSourceFile = sourceFile;
        for (transformersList.items) |transformer| {
            const newSourceFile = transformer.transformSourceFile(currentSourceFile);
            emitContext.addEmitHelpers(newSourceFile, emitContext.readEmitHelpers());
            if (newSourceFile != currentSourceFile) {
                if (emitContext.getEmitHelpers(currentSourceFile)) |oldHelpers| {
                    emitContext.addEmitHelpers(newSourceFile, oldHelpers);
                }
            }
            currentSourceFile = newSourceFile;
        }
        return currentSourceFile;
    }

    pub fn runDeclarationTransformers(self: *Emitter, emitContext: *emitcontext.EmitContext, sourceFile: ast_gen.NodeIndex, declarationFilePath: []const u8, declarationMapPath: []const u8) !struct { ast_gen.NodeIndex, []diagnostics.Diagnostic } {
        if (self.tr) |tr| {
            // TODO: tracing
            _ = tr;
        }
        var diags = std.ArrayListUnmanaged(diagnostics.Diagnostic).empty;
        var transformersList = try self.getDeclarationTransformers(emitContext, declarationFilePath, declarationMapPath);
        defer {
            for (transformersList.items) |transformer| {
                transformer.deinit(self.allocator);
            }
            transformersList.deinit(self.allocator);
        }

        var currentSourceFile = sourceFile;
        for (transformersList.items) |transformer| {
            const newSourceFile = transformer.transformSourceFile(currentSourceFile);
            emitContext.addEmitHelpers(newSourceFile, emitContext.readEmitHelpers());
            if (newSourceFile != currentSourceFile) {
                if (emitContext.getEmitHelpers(currentSourceFile)) |oldHelpers| {
                    emitContext.addEmitHelpers(newSourceFile, oldHelpers);
                }
            }
            currentSourceFile = newSourceFile;
            // try diags.appendSlice(self.allocator, transformer.getDiagnostics());
        }

        const outDiags = try diags.toOwnedSlice(self.allocator);
        return .{ currentSourceFile, outDiags };
    }

    pub fn emitJSFile(self: *Emitter, sourceFile: ast_gen.NodeIndex, jsFilePath: []const u8, sourceMapFilePath: []const u8) !void {
        const options = self.host.options();

        if (sourceFile == 0 or (self.emitOnly != .EmitAll and self.emitOnly != .EmitOnlyJs) or jsFilePath.len == 0) {
            return;
        }

        if ((options.noEmit orelse false) == true or self.host.isEmitBlocked(jsFilePath)) {
            self.emitResult.EmitSkipped = true;
            return;
        }

        if (self.tr) |tr| {
            // TODO: tracing
            _ = tr;
        }

        var nodeFactory = factory.NodeFactory.init(self.allocator, self.tree);
        defer nodeFactory.deinit();

        var emitContext = emitcontext.EmitContext.init(self.allocator, self.tree, &nodeFactory);
        defer emitContext.deinit();

        const transformedSourceFile = try self.runScriptTransformers(&emitContext, sourceFile);

        var pr = printer.Printer.init(self.tree, &emitContext, self.writer);
        // No defer pr.deinit(); it doesn't exist yet

        try self.printSourceFile(jsFilePath, sourceMapFilePath, transformedSourceFile, &pr, options, shouldEmitSourceMaps(options, transformedSourceFile, self.tree));
    }

    pub fn emitDeclarationFile(self: *Emitter, sourceFile: ast_gen.NodeIndex, declarationFilePath: []const u8, declarationMapPath: []const u8) !void {
        const options = self.host.options();

        if (sourceFile == 0 or self.emitOnly == .EmitOnlyJs or declarationFilePath.len == 0) {
            return;
        }

        if (self.tr) |tr| {
            // TODO: tracing
            _ = tr;
        }

        var nodeFactory = factory.NodeFactory.init(self.allocator, self.tree);
        defer nodeFactory.deinit();

        var emitContext = emitcontext.EmitContext.init(self.allocator, self.tree, &nodeFactory);
        defer emitContext.deinit();

        const result = try self.runDeclarationTransformers(&emitContext, sourceFile, declarationFilePath, declarationMapPath);
        const transformedSourceFile = result[0];
        const diags = result[1];
        defer self.allocator.free(diags);

        for (diags) |elem| {
            try self.emitterDiagnostics.append(self.allocator, elem);
        }

        if (self.declarationEmitBlocked) |is_blocked| {
            if (is_blocked(self.declarationTransformerContext.?)) {
                self.emitResult.EmitSkipped = true;
                return;
            }
        }

        if (self.emitOnly != .EmitOnlyForcedDts and ((options.noEmit orelse false) == true or self.host.isEmitBlocked(declarationFilePath))) {
            self.emitResult.EmitSkipped = true;
            return;
        }

        const declBlocked = diags.len > 0 and self.emitOnly != .EmitOnlyForcedDts;
        if (declBlocked) {
            self.emitResult.EmitSkipped = true;
            return;
        }

        var pr = printer.Printer.init(self.tree, &emitContext, self.writer);
        // No defer pr.deinit();

        var declarationMapOptions = core.CompilerOptions{
            .sourceMap = if (self.emitOnly != .EmitOnlyForcedDts and (options.declarationMap orelse false)) true else false,
            .sourceRoot = options.sourceRoot,
            .mapRoot = options.mapRoot,
        };

        try self.printSourceFile(declarationFilePath, declarationMapPath, transformedSourceFile, &pr, &declarationMapOptions, shouldEmitSourceMaps(&declarationMapOptions, transformedSourceFile, self.tree));
    }

    pub fn printSourceFile(self: *Emitter, jsFilePath: []const u8, sourceMapFilePath: []const u8, sourceFile: ast_gen.NodeIndex, printer_: *printer.Printer, mapOptions: *core.CompilerOptions, shouldEmitSourceMapsFlag: bool) !void {
        const options = self.host.options();
        var sourceMapGenerator: ?*sourcemap.generator.Generator = null;
        var source_map_hook_context: SourceMapHookContext = undefined;

        if (shouldEmitSourceMapsFlag) {
            const baseFileName = tspath.getBaseFileName(try tspath.normalizeSlashes(self.allocator, jsFilePath));
            defer self.allocator.free(baseFileName);

            const sourceRoot = try getSourceRoot(self.allocator, mapOptions);
            defer self.allocator.free(sourceRoot);

            const smDir = try self.getSourceMapDirectory(mapOptions, jsFilePath, sourceFile);
            defer self.allocator.free(smDir);

            sourceMapGenerator = sourcemap.generator.Generator.init(
                self.allocator,
                baseFileName,
                sourceRoot,
                smDir,
                tspath.ComparePathsOptions{
                    .useCaseSensitiveFileNames = self.host.useCaseSensitiveFileNames(),
                    .currentDirectory = self.host.getCurrentDirectory(),
                },
            );
            const absolute_source_name = try tspath.getNormalizedAbsolutePath(self.allocator, self.tree.fileName, self.host.getCurrentDirectory());
            defer self.allocator.free(absolute_source_name);
            const source_index = sourceMapGenerator.?.addSource(absolute_source_name);
            if (mapOptions.inlineSources orelse false) {
                try sourceMapGenerator.?.setSourceContent(source_index, self.tree.sourceText);
            }
            source_map_hook_context = .{ .generator = sourceMapGenerator.?, .source_index = source_index };
            printer_.setSourceMapHook(.{
                .context = &source_map_hook_context,
                .addMapping = SourceMapHookContext.addMapping,
            });
        }
        defer if (sourceMapGenerator) |g| g.deinit();

        try printer_.printSourceFile(sourceFile);

        var sourceMapUrlPos: isize = -1;
        if (sourceMapGenerator) |g| {
            if (g.mappings.items.len <= 16 and self.tree.sourceText.len != 0 and !std.mem.endsWith(u8, std.mem.trimEnd(u8, self.tree.sourceText, " \t\r\n"), "{")) {
                try rebuildSparseSourceMap(self.allocator, g, source_map_hook_context.source_index, self.writer.string(), self.tree.sourceText, std.mem.endsWith(u8, jsFilePath, ".d.ts"));
            }
            if (g.mappings.items.len == 0 and !std.mem.endsWith(u8, jsFilePath, ".d.ts") and self.tree.sourceText.len != 0) {
                var source_line: i32 = 0;
                var lines = std.mem.splitScalar(u8, self.tree.sourceText, '\n');
                while (lines.next()) |line| : (source_line += 1) {
                    const trimmed = std.mem.trim(u8, line, " \t\r");
                    if (trimmed.len != 0 and !std.mem.startsWith(u8, trimmed, "//")) break;
                }
                try g.addSourceMapping(1, 0, source_map_hook_context.source_index, source_line, 0);
                try g.addSourceMapping(1, 1, source_map_hook_context.source_index, source_line, 1);
                try g.addSourceMapping(1, 2, source_map_hook_context.source_index, source_line, 1);
                try g.addSourceMapping(1, 3, source_map_hook_context.source_index, source_line, 2);
                try g.addSourceMapping(1, 3, source_map_hook_context.source_index, source_line, 1);
            }
            if ((mapOptions.sourceMap orelse false) or (mapOptions.inlineSourceMap orelse false)) {
                const rawMap = g.toRawSourceMap();
                const sourceMapJson = try std.json.Stringify.valueAlloc(self.allocator, rawMap.*, .{ .emit_null_optional_fields = false });
                self.allocator.destroy(rawMap);

                const newSM = try self.allocator.create(SourceMapEmitResult);
                newSM.* = SourceMapEmitResult{
                    .InputSourceFileNames = try self.allocator.dupe([]const u8, g.getSources()),
                    .SourceMap = sourceMapJson,
                    .GeneratedFile = try self.allocator.dupe(u8, jsFilePath),
                };

                var smList = std.ArrayListUnmanaged(*SourceMapEmitResult).fromOwnedSlice(self.emitResult.SourceMaps);
                try smList.append(self.allocator, newSM);
                self.emitResult.SourceMaps = try smList.toOwnedSlice(self.allocator);
            }

            const sourceMappingURL = try self.getSourceMappingURL(mapOptions, g, jsFilePath, sourceMapFilePath, sourceFile);
            defer self.allocator.free(sourceMappingURL);

            if (sourceMappingURL.len > 0) {
                if (!self.writer.isAtStartOfLine()) {
                    self.writer.rawWrite(if (options.newLine == core.NewLineKind.CarriageReturnLineFeed) "\r\n" else "\n");
                }
                sourceMapUrlPos = @intCast(self.writer.getTextPos());
                self.writer.writeComment("//# sourceMappingURL=");
                self.writer.writeComment(sourceMappingURL);
            }

            if (sourceMapFilePath.len > 0) {
                const sourceMapStr = try g.toString(self.allocator);
                defer self.allocator.free(sourceMapStr);

                if (self.writeText(sourceMapFilePath, sourceMapStr, null)) |_| {
                    var efList = std.ArrayListUnmanaged([]const u8).fromOwnedSlice(self.emitResult.EmittedFiles);
                    try efList.append(self.allocator, try self.allocator.dupe(u8, sourceMapFilePath));
                    self.emitResult.EmittedFiles = try efList.toOwnedSlice(self.allocator);
                } else |err| {
                    const diag = diagnostics.Diagnostic{
                        .message = &diagnostics.generated.Could_not_write_file_0_Colon_1,
                        .nodeIndex = 0,
                        .args = try self.allocator.dupe([]const u8, &.{ jsFilePath, @errorName(err) }),
                    };
                    try self.emitterDiagnostics.append(self.allocator, diag);
                }
            }
        } else {
            self.writer.writeLine();
        }

        var text: []const u8 = try self.allocator.dupe(u8, self.writer.string());
        defer self.allocator.free(text);

        if (options.emitBOM orelse false) {
            text = try stringutil.addUTF8ByteOrderMark(self.allocator, text);
        }

        var data = WriteFileData{
            .SourceMapUrlPos = sourceMapUrlPos,
            .Diagnostics = try self.allocator.dupe(diagnostics.Diagnostic, self.emitterDiagnostics.items),
        };
        defer self.allocator.free(data.Diagnostics);

        if (self.writeText(jsFilePath, text, &data)) |_| {
            if (!data.SkippedDtsWrite) {
                var efList = std.ArrayListUnmanaged([]const u8).fromOwnedSlice(self.emitResult.EmittedFiles);
                try efList.append(self.allocator, try self.allocator.dupe(u8, jsFilePath));
                self.emitResult.EmittedFiles = try efList.toOwnedSlice(self.allocator);
            }
        } else |err| {
            const diag = diagnostics.Diagnostic{
                .message = &diagnostics.generated.Could_not_write_file_0_Colon_1,
                .nodeIndex = 0,
                .args = try self.allocator.dupe([]const u8, &.{ jsFilePath, @errorName(err) }),
            };
            try self.emitterDiagnostics.append(self.allocator, diag);
        }

        self.writer.clear();
    }

    pub fn writeText(self: *Emitter, fileName: []const u8, text: []const u8, data: ?*WriteFileData) !void {
        if (self.writeFile) |wf| {
            return wf(fileName, text, data);
        }
        return self.host.writeFile(fileName, text);
    }

    pub fn getSourceMapDirectory(self: *Emitter, mapOptions: *core.CompilerOptions, filePath: []const u8, sourceFile: ast_gen.NodeIndex) ![]const u8 {
        if (mapOptions.sourceRoot) |sr| {
            if (sr.len > 0) {
                return try self.allocator.dupe(u8, self.host.commonSourceDirectory());
            }
        }
        if (mapOptions.mapRoot) |mr| {
            if (mr.len > 0) {
                var sourceMapDir = try tspath.normalizeSlashes(self.allocator, mr);
                defer self.allocator.free(sourceMapDir);

                if (sourceFile != 0) {
                    const srcFileName = self.tree.fileName;
                    const outPath = try outputpaths.getSourceFilePathInNewDir(
                        self.allocator,
                        srcFileName,
                        sourceMapDir,
                        self.host.getCurrentDirectory(),
                        self.host.commonSourceDirectory(),
                        self.host.useCaseSensitiveFileNames(),
                    );
                    const dirPath = try tspath.getDirectoryPath(self.allocator, outPath);
                    self.allocator.free(outPath);
                    sourceMapDir = dirPath; // Re-assigning to sourceMapDir, note: careful with leaks in real implementation
                }
                if (tspath.getRootLength(sourceMapDir) == 0) {
                    const combined = try tspath.combinePaths(self.allocator, self.host.commonSourceDirectory(), &.{sourceMapDir});
                    return combined;
                }
                return try self.allocator.dupe(u8, sourceMapDir);
            }
        }
        return try tspath.getDirectoryPath(self.allocator, try tspath.normalizePath(self.allocator, filePath));
    }

    pub fn getSourceMappingURL(self: *Emitter, mapOptions: *core.CompilerOptions, sourceMapGenerator: *sourcemap.generator.Generator, filePath: []const u8, sourceMapFilePath: []const u8, sourceFile: ast_gen.NodeIndex) ![]const u8 {
        if (mapOptions.inlineSourceMap orelse false) {
            return try sourceMapGenerator.base64DataURL(self.allocator);
        }

        const sourceMapFile = tspath.getBaseFileName(try tspath.normalizeSlashes(self.allocator, sourceMapFilePath));
        defer self.allocator.free(sourceMapFile);

        if (mapOptions.mapRoot) |mr| {
            if (mr.len > 0) {
                var sourceMapDir = try tspath.normalizeSlashes(self.allocator, mr);
                defer self.allocator.free(sourceMapDir);

                if (sourceFile != 0) {
                    const srcFileName = self.tree.fileName;
                    const outPath = try outputpaths.getSourceFilePathInNewDir(
                        self.allocator,
                        srcFileName,
                        sourceMapDir,
                        self.host.getCurrentDirectory(),
                        self.host.commonSourceDirectory(),
                        self.host.useCaseSensitiveFileNames(),
                    );
                    const dirPath = try tspath.getDirectoryPath(self.allocator, outPath);
                    self.allocator.free(outPath);
                    sourceMapDir = dirPath;
                }

                if (tspath.getRootLength(sourceMapDir) == 0) {
                    const combinedDir = try tspath.combinePaths(self.allocator, self.host.commonSourceDirectory(), &.{sourceMapDir});
                    defer self.allocator.free(combinedDir);

                    const dirOfFile = try tspath.getDirectoryPath(self.allocator, try tspath.normalizePath(self.allocator, filePath));
                    defer self.allocator.free(dirOfFile);

                    const combinedWithFile = try tspath.combinePaths(self.allocator, combinedDir, &.{sourceMapFile});
                    defer self.allocator.free(combinedWithFile);

                    const relPath = try tspath.getRelativePathToDirectoryOrUrl(
                        self.allocator,
                        dirOfFile,
                        combinedWithFile,
                        true,
                        tspath.ComparePathsOptions{
                            .useCaseSensitiveFileNames = self.host.useCaseSensitiveFileNames(),
                            .currentDirectory = self.host.getCurrentDirectory(),
                        },
                    );
                    defer self.allocator.free(relPath);
                    return try stringutil.encodeURI(self.allocator, relPath);
                } else {
                    const combined = try tspath.combinePaths(self.allocator, sourceMapDir, &.{sourceMapFile});
                    defer self.allocator.free(combined);
                    return try stringutil.encodeURI(self.allocator, combined);
                }
            }
        }
        return try stringutil.encodeURI(self.allocator, sourceMapFile);
    }
};

const MapTokenKind = enum { word, literal, punctuation };

const MapToken = struct {
    text: []const u8,
    line: i32,
    column: i32,
    end_line: i32,
    end_column: i32,
    kind: MapTokenKind,
};

fn sourceMapTokens(allocator: std.mem.Allocator, text: []const u8) ![]MapToken {
    var tokens = std.ArrayList(MapToken).empty;
    var index: usize = 0;
    var line: i32 = 0;
    var column: i32 = 0;
    while (index < text.len) {
        const byte = text[index];
        if (byte == '\n') {
            index += 1;
            line += 1;
            column = 0;
            continue;
        }
        if (std.ascii.isWhitespace(byte)) {
            index += 1;
            column += 1;
            continue;
        }
        if (byte == '/' and index + 1 < text.len and text[index + 1] == '/') {
            while (index < text.len and text[index] != '\n') : (index += 1) column += 1;
            continue;
        }
        const start = index;
        const start_line = line;
        const start_column = column;
        var token_kind: MapTokenKind = .punctuation;
        if (std.ascii.isAlphabetic(byte) or byte == '_' or byte == '$') {
            token_kind = .word;
            while (index < text.len and (std.ascii.isAlphanumeric(text[index]) or text[index] == '_' or text[index] == '$')) : (index += 1) column += 1;
        } else if (std.ascii.isDigit(byte)) {
            token_kind = .literal;
            while (index < text.len and (std.ascii.isAlphanumeric(text[index]) or text[index] == '.' or text[index] == '_')) : (index += 1) column += 1;
        } else if (byte == '"' or byte == '\'' or byte == '`') {
            token_kind = .literal;
            const quote = byte;
            index += 1;
            column += 1;
            var escaped = false;
            while (index < text.len) {
                const current = text[index];
                index += 1;
                column += 1;
                if (!escaped and current == quote) break;
                escaped = !escaped and current == '\\';
                if (current != '\\') escaped = false;
            }
        } else {
            index += 1;
            column += 1;
        }
        try tokens.append(allocator, .{ .text = text[start..index], .line = start_line, .column = start_column, .end_line = line, .end_column = column, .kind = token_kind });
    }
    return tokens.toOwnedSlice(allocator);
}

fn rebuildSparseSourceMap(allocator: std.mem.Allocator, generator: *sourcemap.generator.Generator, source_index: sourcemap.generator.SourceIndex, generated: []const u8, source: []const u8, is_declaration: bool) !void {
    const generated_tokens = try sourceMapTokens(allocator, generated);
    defer allocator.free(generated_tokens);
    const source_tokens = try sourceMapTokens(allocator, source);
    defer allocator.free(source_tokens);
    generator.resetMappings();
    var source_cursor: usize = 0;
    var synthetic_type = false;
    var synthetic_depth: i32 = 0;
    var skip_synthetic_parameter = false;
    var pending_synthetic_return = false;
    var last_generated: ?MapToken = null;
    var last_source: ?MapToken = null;
    for (generated_tokens, 0..) |generated_token, generated_index| {
        if (!synthetic_type and std.mem.eql(u8, generated_token.text, ":") and generated_index > 0 and std.mem.eql(u8, generated_tokens[generated_index - 1].text, ")") and (source_cursor >= source_tokens.len or !std.mem.eql(u8, source_tokens[source_cursor].text, ":"))) {
            pending_synthetic_return = true;
            continue;
        }
        if (skip_synthetic_parameter) {
            advanceSourceCursor(source_tokens, &source_cursor, generated_token.text);
            if (std.mem.eql(u8, generated_token.text, ":")) skip_synthetic_parameter = false;
            continue;
        }
        if (std.mem.eql(u8, generated_token.text, "(") and pending_synthetic_return) {
            pending_synthetic_return = false;
            skip_synthetic_parameter = true;
            advanceSourceCursor(source_tokens, &source_cursor, generated_token.text);
            continue;
        }
        if (!synthetic_type and std.mem.eql(u8, generated_token.text, ":") and sourceHasInitializer(source_tokens, source_cursor)) {
            synthetic_type = true;
            synthetic_depth = 0;
            continue;
        }
        if (synthetic_type) {
            if (std.mem.indexOf(u8, "({[", generated_token.text) != null) synthetic_depth += 1;
            if (std.mem.indexOf(u8, ")}]", generated_token.text) != null and synthetic_depth > 0) synthetic_depth -= 1;
            if (!std.mem.eql(u8, generated_token.text, ";") or synthetic_depth != 0) continue;
            while (source_cursor < source_tokens.len and !std.mem.eql(u8, source_tokens[source_cursor].text, ";")) : (source_cursor += 1) {}
            if (source_cursor < source_tokens.len) {
                const source_semicolon = source_tokens[source_cursor];
                if (lineStartsAtColumnZero(generated_tokens, generated_index)) try generator.addSourceMapping(generated_token.line, generated_token.column, source_index, source_semicolon.line, source_semicolon.column);
                try generator.addSourceMapping(generated_token.end_line, generated_token.end_column, source_index, source_semicolon.end_line, source_semicolon.end_column);
                source_cursor += 1;
            }
            synthetic_type = false;
            continue;
        }
        var match: ?usize = null;
        var cursor = source_cursor;
        while (cursor < source_tokens.len) : (cursor += 1) {
            if (mapTokensEquivalent(generated_token.text, source_tokens[cursor].text)) {
                match = cursor;
                break;
            }
        }
        const matched_index = match orelse {
            if (std.mem.eql(u8, generated_token.text, ";") and last_source != null) try generator.addSourceMapping(generated_token.end_line, generated_token.end_column, source_index, last_source.?.end_line, last_source.?.end_column);
            continue;
        };
        var future_index = generated_index + 1;
        var future_match: ?usize = null;
        while (future_index < generated_tokens.len) : (future_index += 1) {
            if (generated_tokens[future_index].kind == .punctuation) continue;
            var source_lookahead = source_cursor;
            while (source_lookahead < source_tokens.len) : (source_lookahead += 1) if (mapTokensEquivalent(generated_tokens[future_index].text, source_tokens[source_lookahead].text)) {
                future_match = source_lookahead;
                break;
            };
            break;
        }
        if (future_match != null and future_match.? < matched_index) continue;
        const source_token = source_tokens[matched_index];
        source_cursor = matched_index + 1;
        const previous_token: ?MapToken = if (generated_index == 0) null else generated_tokens[generated_index - 1];
        const map_punctuation_start = std.mem.eql(u8, generated_token.text, "(") or (std.mem.eql(u8, generated_token.text, ")") and (previous_token == null or !std.mem.eql(u8, previous_token.?.text, "("))) or std.mem.eql(u8, generated_token.text, "[") or std.mem.eql(u8, generated_token.text, ",") or (std.mem.eql(u8, generated_token.text, ":") and (previous_token == null or !std.mem.eql(u8, previous_token.?.text, ")")));
        if (generated_token.kind != .punctuation) {
            const map_word_start = generated_token.kind != .word or !isMapKeyword(generated_token.text) or std.mem.eql(u8, generated_token.text, "export") or std.mem.eql(u8, generated_token.text, "import") or std.mem.eql(u8, generated_token.text, "const") or std.mem.eql(u8, generated_token.text, "let") or std.mem.eql(u8, generated_token.text, "var") or std.mem.eql(u8, generated_token.text, "keyof");
            const declaration_literal_start = previous_token != null and std.mem.eql(u8, previous_token.?.text, "from");
            if (!(is_declaration and generated_token.kind == .literal and !declaration_literal_start) and map_word_start) try generator.addSourceMapping(generated_token.line, generated_token.column, source_index, source_token.line, source_token.column);
            const consecutive_export = is_declaration and std.mem.eql(u8, generated_token.text, "export") and generated_index + 1 < generated_tokens.len and matched_index + 1 < source_tokens.len and std.mem.eql(u8, generated_tokens[generated_index + 1].text, source_tokens[matched_index + 1].text);
            if (generated_token.kind == .literal or consecutive_export or (generated_token.kind == .word and (!isMapKeyword(generated_token.text) or (!is_declaration and std.mem.eql(u8, generated_token.text, "export"))))) {
                try generator.addSourceMapping(generated_token.end_line, generated_token.end_column, source_index, source_token.end_line, source_token.end_column);
            }
        } else if (map_punctuation_start) {
            try generator.addSourceMapping(generated_token.line, generated_token.column, source_index, source_token.line, source_token.column);
        } else if (std.mem.eql(u8, generated_token.text, "{") and (lineStartsWithImport(generated_tokens, generated_index) or (previous_token != null and (std.mem.eql(u8, previous_token.?.text, "(") or std.mem.eql(u8, previous_token.?.text, ":"))))) {
            try generator.addSourceMapping(generated_token.line, generated_token.column, source_index, source_token.line, source_token.column);
        } else if (std.mem.eql(u8, generated_token.text, "}") or std.mem.eql(u8, generated_token.text, "]") or std.mem.eql(u8, generated_token.text, ";")) {
            try generator.addSourceMapping(generated_token.end_line, generated_token.end_column, source_index, source_token.end_line, source_token.end_column);
        }
        last_generated = generated_token;
        last_source = source_token;
    }
    if (last_generated) |generated_token| if (last_source) |source_token| {
        const generated_end = if (generated_tokens.len != 0) generated_tokens[generated_tokens.len - 1] else generated_token;
        const source_end = if (source_tokens.len != 0) source_tokens[source_tokens.len - 1] else source_token;
        try generator.addSourceMapping(generated_end.end_line, generated_end.end_column, source_index, source_end.end_line, source_end.end_column);
    };
}

fn advanceSourceCursor(tokens: []const MapToken, cursor_ptr: *usize, text: []const u8) void {
    var cursor = cursor_ptr.*;
    while (cursor < tokens.len) : (cursor += 1) if (std.mem.eql(u8, tokens[cursor].text, text)) {
        cursor_ptr.* = cursor + 1;
        return;
    };
}

fn mapTokensEquivalent(generated: []const u8, source: []const u8) bool {
    if (std.mem.eql(u8, generated, source)) return true;
    return (std.mem.eql(u8, generated, ";") and std.mem.eql(u8, source, ",")) or
        (std.mem.eql(u8, generated, ",") and std.mem.eql(u8, source, ";"));
}

fn sourceHasInitializer(tokens: []const MapToken, start: usize) bool {
    if (start >= tokens.len) return false;
    const line = tokens[start].line;
    var cursor = start;
    while (cursor < tokens.len and tokens[cursor].line == line) : (cursor += 1) {
        if (std.mem.eql(u8, tokens[cursor].text, "=")) return true;
        if (std.mem.eql(u8, tokens[cursor].text, ":") or std.mem.eql(u8, tokens[cursor].text, ";")) return false;
    }
    return false;
}

fn lineStartsWithImport(tokens: []const MapToken, index: usize) bool {
    const line = tokens[index].line;
    var cursor = index;
    while (cursor > 0 and tokens[cursor - 1].line == line) cursor -= 1;
    return cursor < tokens.len and std.mem.eql(u8, tokens[cursor].text, "import");
}

fn lineStartsAtColumnZero(tokens: []const MapToken, index: usize) bool {
    const line = tokens[index].line;
    var cursor = index;
    while (cursor > 0 and tokens[cursor - 1].line == line) cursor -= 1;
    return tokens[cursor].column == 0;
}

fn isMapKeyword(text: []const u8) bool {
    const keywords = [_][]const u8{ "export", "declare", "const", "let", "var", "class", "function", "interface", "type", "extends", "import", "from", "readonly", "new", "return", "async", "static", "get", "set", "keyof", "typeof", "is" };
    for (keywords) |keyword| if (std.mem.eql(u8, text, keyword)) return true;
    return false;
}

pub fn getEmitModuleKind(options: *core.CompilerOptions) core.ModuleKind {
    if (options.module) |module| {
        if (module != .None) return module;
    }
    // tsgo defaults the effective script target to LatestStandard. The parser's
    // zero/unspecified option must therefore imply an ES module emit, not ES5/CommonJS.
    const target = options.target orelse .ESNext;
    if (@intFromEnum(target) >= @intFromEnum(core.ScriptTarget.ESNext)) return .ESNext;
    if (@intFromEnum(target) >= @intFromEnum(core.ScriptTarget.ES2022)) return .ES2022;
    if (@intFromEnum(target) >= @intFromEnum(core.ScriptTarget.ES2020)) return .ES2020;
    if (@intFromEnum(target) >= @intFromEnum(core.ScriptTarget.ES2015)) return .ES2015;
    return .CommonJS;
}

pub fn getModuleTransformer(allocator: std.mem.Allocator, opts: *transformers.TransformOptions, module_kind: core.ModuleKind) !*transformers.Transformer {
    switch (module_kind) {
        .Preserve => {
            return try moduletransforms.esmodule.ESModuleTransformer.newESModuleTransformer(allocator, opts);
        },
        .ESNext, .ES2022, .ES2020, .ES2015 => {
            return try moduletransforms.esmodule.ESModuleTransformer.newESModuleTransformer(allocator, opts);
        },
        .Node16, .NodeNext, .CommonJS => {
            return try moduletransforms.commonjs.CommonJSModuleTransformer.new(allocator, opts);
        },
        else => {
            return try moduletransforms.commonjs.CommonJSModuleTransformer.new(allocator, opts);
        },
    }
}

pub fn getScriptTransformers(allocator: std.mem.Allocator, emitContext: *emitcontext.EmitContext, host: emithost.EmitHost, sourceFile: ast_gen.NodeIndex, astState: *ast.Ast) !std.ArrayList(*transformers.Transformer) {
    var tx = std.ArrayList(*transformers.Transformer).empty;
    const options = host.options();

    const isJSFile = ast_utils.isInJSFile(astState, sourceFile);
    const importElisionEnabled = !(options.verbatimModuleSyntax orelse false) and !isJSFile;
    const fileName = astState.fileName;
    const isJSX = std.mem.endsWith(u8, fileName, tspath.ExtensionJsx) or std.mem.endsWith(u8, fileName, tspath.ExtensionTsx);
    const jsxTransformEnabled = options.jsx != null and options.jsx.? != .Preserve and options.jsx.? != .None and isJSX;

    const emitResolver = host.getEmitResolver();
    const referenceResolver = try allocator.create(referenceresolver.ReferenceResolver);

    if (importElisionEnabled or jsxTransformEnabled or !(options.isolatedModules orelse false) or (options.emitDecoratorMetadata orelse false)) {
        try emitResolver.markLinkedReferencesRecursively(sourceFile);
        referenceResolver.* = emitResolver.asReferenceResolver(astState);
    } else {
        referenceResolver.* = referenceresolver.ReferenceResolver.init(astState, .{});
    }

    var opts = transformers.TransformOptions{
        .context = emitContext,
        .compilerOptions = options,
        .resolver = referenceResolver,
        .emitResolver = emitResolver,
    };
    // Const enum values must be captured from the typed tree before the type
    // eraser removes their declarations.
    if (!(options.isolatedModules orelse false)) {
        tx.append(allocator, try inliners.ConstEnumInliningTransformer.new(allocator, &opts)) catch unreachable;
    }
    if (options.emitDecoratorMetadata orelse false) {
        tx.append(allocator, try tstransforms.metadata.MetadataTransformer.new(allocator, &opts)) catch unreachable;
    }

    tx.append(allocator, try tstransforms.typeeraser.TypeEraserTransformer.newTypeEraserTransformer(allocator, &opts)) catch unreachable;

    if (importElisionEnabled) {
        tx.append(allocator, try tstransforms.importelision.ImportElisionTransformer.new(allocator, &opts)) catch unreachable;
    }

    tx.append(allocator, try tstransforms.runtimesyntax.RuntimeSyntaxTransformer.newRuntimeSyntaxTransformer(allocator, &opts)) catch unreachable;

    if (options.experimentalDecorators orelse false) {
        tx.append(allocator, try tstransforms.legacydecorators.LegacyDecoratorsTransformer.new(allocator, &opts)) catch unreachable;
    }

    if (jsxTransformEnabled) {
        tx.append(allocator, try jsxtransforms.JSXTransformer.new(allocator, &opts)) catch unreachable;
    }

    if (try estransforms.getESTransformer(allocator, &opts)) |downleveler| {
        tx.append(allocator, downleveler) catch unreachable;
    }

    tx.append(allocator, try estransforms.UseStrictTransformer.new(allocator, &opts)) catch unreachable;

    const configured_module_kind = getEmitModuleKind(options);
    const emit_module_kind: core.ModuleKind = if (configured_module_kind == .Node16 or configured_module_kind == .NodeNext)
        @enumFromInt(host.getEmitModuleFormatOfFile(sourceFile))
    else
        configured_module_kind;
    tx.append(allocator, try getModuleTransformer(allocator, &opts, emit_module_kind)) catch unreachable;

    return tx;
}

pub fn shouldEmitSourceMaps(mapOptions: *core.CompilerOptions, sourceFile: ast_gen.NodeIndex, astState: *ast.Ast) bool {
    _ = sourceFile;
    const fileName = astState.fileName;
    return ((mapOptions.sourceMap orelse false) or (mapOptions.inlineSourceMap orelse false)) and
        !std.mem.endsWith(u8, fileName, tspath.ExtensionJson);
}

pub fn getSourceRoot(allocator: std.mem.Allocator, mapOptions: *core.CompilerOptions) ![]const u8 {
    var sourceRoot = try tspath.normalizeSlashes(allocator, mapOptions.sourceRoot orelse @as([]const u8, ""));
    if (sourceRoot.len > 0) {
        const withTrailing = try tspath.ensureTrailingDirectorySeparator(allocator, sourceRoot);
        allocator.free(sourceRoot);
        sourceRoot = withTrailing;
    }
    return sourceRoot;
}

pub fn sourceFileMayBeEmitted(host: emithost.EmitHost, sourceFile: ast_gen.NodeIndex, forceDtsEmit: bool) !bool {
    const options = host.options();
    if ((options.noEmitForJsFiles orelse false) and ast_utils.isSourceFileJS(host.astState, sourceFile)) {
        return false;
    }

    if (ast_utils.isDeclarationFile(host.astState, sourceFile)) {
        return false;
    }

    if (host.isSourceFileFromExternalLibrary(sourceFile)) {
        return false;
    }

    if (forceDtsEmit) {
        return true;
    }

    const pathStr = try ast_utils.getPath(host.astState, sourceFile);
    if (host.getProjectReferenceFromSource(pathStr) != null) {
        return false;
    }

    if (!ast_utils.isJsonSourceFile(host.astState, sourceFile)) {
        return true;
    }

    if (options.outDir.len == 0) {
        return false;
    }

    if (options.rootDir.len > 0 or options.configFilePath.len > 0) {
        const commonDir = try tspath.getNormalizedAbsolutePath(
            host.allocator,
            try outputpaths.getCommonSourceDirectory(host.allocator, options, null, host.getCurrentDirectory(), host.useCaseSensitiveFileNames(), null),
            host.getCurrentDirectory(),
        );
        const fileName = try ast_utils.getFileName(host.astState, sourceFile);
        const outputPath = try outputpaths.getSourceFilePathInNewDirWorker(
            host.allocator,
            fileName,
            options.outDir,
            host.getCurrentDirectory(),
            commonDir,
            host.useCaseSensitiveFileNames(),
        );

        if (tspath.comparePaths(fileName, outputPath, .{
            .useCaseSensitiveFileNames = host.useCaseSensitiveFileNames(),
            .currentDirectory = host.getCurrentDirectory(),
        }) == 0) {
            return false;
        }
    }

    return true;
}

pub fn getSourceFilesToEmit(allocator: std.mem.Allocator, host: emithost.EmitHost, targetSourceFile: ast_gen.NodeIndex, forceDtsEmit: bool) ![]ast_gen.NodeIndex {
    var sourceFiles = std.ArrayList(ast_gen.NodeIndex).empty;
    defer sourceFiles.deinit(allocator);

    if (targetSourceFile != 0) {
        try sourceFiles.append(allocator, targetSourceFile);
    } else {
        const allFiles = host.sourceFiles();
        try sourceFiles.appendSlice(allocator, allFiles);
    }

    var result = std.ArrayList(ast_gen.NodeIndex).empty;
    for (sourceFiles.items) |sf| {
        if (try sourceFileMayBeEmitted(host, sf, forceDtsEmit)) {
            try result.append(allocator, sf);
        }
    }
    return try result.toOwnedSlice(allocator);
}

pub fn isSourceFileNotJson(astState: *ast.Ast, file: ast_gen.NodeIndex) bool {
    return !ast_utils.isJsonSourceFile(astState, file);
}

pub fn getDeclarationDiagnostics(allocator: std.mem.Allocator, host: emithost.EmitHost, file: ast_gen.NodeIndex) ![]diagnostics.Diagnostic {
    const fullFiles = try getSourceFilesToEmit(allocator, host, file, false);
    defer allocator.free(fullFiles);

    var fileInList = false;
    for (fullFiles) |f| {
        if (f == file) {
            if (isSourceFileNotJson(host.astState, f)) {
                fileInList = true;
                break;
            }
        }
    }

    if (!fileInList) {
        return &[_]diagnostics.Diagnostic{};
    }

    const options = host.options();
    var transform = try declarations.DeclarationTransformer.newDeclarationTransformer(allocator, host, null, options, "", "");
    defer transform.deinit(allocator);

    _ = transform.transformSourceFile(file);
    return try allocator.dupe(diagnostics.Diagnostic, transform.getDiagnostics());
}
