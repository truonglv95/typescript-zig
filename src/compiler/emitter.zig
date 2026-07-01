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

pub const Emitter = struct {
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
        const transform = try declarations.DeclarationTransformer.new(self.allocator, emitContext, null, null, null);
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
            currentSourceFile = transformer.transformSourceFile(currentSourceFile);
        }
        return currentSourceFile;
    }

    pub fn runDeclarationTransformers(self: *Emitter, emitContext: *emitcontext.EmitContext, sourceFile: ast_gen.NodeIndex, declarationFilePath: []const u8, declarationMapPath: []const u8) !struct { ast_gen.NodeIndex, []diagnostics.Diagnostic } {
        if (self.tr) |tr| {
            // TODO: tracing
            _ = tr;
        }
        var diags = std.ArrayListUnmanaged(diagnostics.Diagnostic).empty;
        var currentSourceFile = sourceFile;

        var transformersList = try self.getDeclarationTransformers(emitContext, declarationFilePath, declarationMapPath);
        defer {
            for (transformersList.items) |transformer| {
                transformer.deinit(self.allocator);
            }
            transformersList.deinit(self.allocator);
        }

        for (transformersList.items) |transformer| {
            currentSourceFile = transformer.transformSourceFile(currentSourceFile);
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
        }
        defer if (sourceMapGenerator) |g| g.deinit();

        try printer_.printSourceFile(sourceFile);

        var sourceMapUrlPos: isize = -1;
        if (sourceMapGenerator) |g| {
            if ((mapOptions.sourceMap orelse false) or (mapOptions.inlineSourceMap orelse false)) {
                const rawMap = g.toRawSourceMap();
                var out = std.ArrayListUnmanaged(u8).empty;
                defer out.deinit(self.allocator);
                try out.print(self.allocator, "{}", .{std.json.fmt(rawMap.*, .{})});
                const sourceMapJson = try self.allocator.dupe(u8, out.items);
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

pub fn getModuleTransformer(allocator: std.mem.Allocator, opts: *transformers.TransformOptions) !*transformers.Transformer {
    switch (opts.compilerOptions.module orelse .None) {
        .Preserve => {
            return try moduletransforms.esmodule.ESModuleTransformer.newESModuleTransformer(allocator, opts);
        },
        .ESNext, .ES2022, .ES2020, .ES2015, .Node16, .NodeNext, .CommonJS => {
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
    var referenceResolver: referenceresolver.ReferenceResolver = undefined;

    if (importElisionEnabled or jsxTransformEnabled or !(options.isolatedModules orelse false) or (options.emitDecoratorMetadata orelse false)) {
        try emitResolver.markLinkedReferencesRecursively(sourceFile);
        referenceResolver = emitResolver.asReferenceResolver();
    } else {
        referenceResolver = referenceresolver.ReferenceResolver.init(astState, .{});
    }

    var opts = transformers.TransformOptions{
        .context = emitContext,
        .compilerOptions = options,
        .resolver = &referenceResolver,
        .emitResolver = emitResolver,
    };
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

    tx.append(allocator, try getModuleTransformer(allocator, &opts)) catch unreachable;

    if (!(options.isolatedModules orelse false)) {
        tx.append(allocator, try inliners.ConstEnumInliningTransformer.new(allocator, &opts)) catch unreachable;
    }

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
