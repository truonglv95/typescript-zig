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
const transformers = @import("../transformers/transformer.zig");
const declarations = @import("../transformers/declarations.zig");
const estransforms = @import("../transformers/estransforms.zig");
const inliners = @import("../transformers/inliners.zig");
const jsxtransforms = @import("../transformers/jsxtransforms.zig");
const moduletransforms = @import("../transformers/moduletransforms.zig");
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
    writer: *printer.EmitTextWriter,
    paths: *outputpaths.OutputPaths,
    sourceFile: ast_gen.NodeIndex,
    emitResult: EmitResult,
    writeFile: ?*const fn(fileName: []const u8, text: []const u8, data: ?*WriteFileData) anyerror!void,
    tr: ?*tracing.Tracing,

    pub fn emit(self: *Emitter) !void {
        if (self.tr) |tr| {
            // TODO: push/pop tracing logic
            _ = tr;
        }

        try self.emitJSFile(self.sourceFile, self.paths.JsFilePath(), self.paths.SourceMapFilePath());
        try self.emitDeclarationFile(self.sourceFile, self.paths.DeclarationFilePath(), self.paths.DeclarationMapPath());
        
        // Convert array list slice to array slice
        self.emitResult.Diagnostics = try self.allocator.dupe(diagnostics.Diagnostic, self.emitterDiagnostics.items);
    }

    pub fn getDeclarationTransformers(self: *Emitter, emitContext: *emitcontext.EmitContext, declarationFilePath: []const u8, declarationMapPath: []const u8) !std.ArrayList(*declarations.DeclarationTransformer) {
        var tx = std.ArrayList(*declarations.DeclarationTransformer).init(self.allocator);
        const transform = try declarations.DeclarationTransformer.newDeclarationTransformer(self.allocator, self.host, emitContext, self.host.options(), declarationFilePath, declarationMapPath);
        try tx.append(transform);
        return tx;
    }

    pub fn runScriptTransformers(self: *Emitter, emitContext: *emitcontext.EmitContext, sourceFile: ast_gen.NodeIndex) !ast_gen.NodeIndex {
        if (self.tr) |tr| {
            // TODO: tracing
            _ = tr;
        }
        var transformersList = try getScriptTransformers(self.allocator, emitContext, self.host, sourceFile);
        defer {
            for (transformersList.items) |transformer| {
                transformer.deinit(self.allocator);
            }
            transformersList.deinit();
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
        var diags = std.ArrayList(diagnostics.Diagnostic).init(self.allocator);
        var currentSourceFile = sourceFile;

        var transformersList = try self.getDeclarationTransformers(emitContext, declarationFilePath, declarationMapPath);
        defer {
            for (transformersList.items) |transformer| {
                transformer.deinit(self.allocator);
            }
            transformersList.deinit();
        }

        for (transformersList.items) |transformer| {
            currentSourceFile = transformer.transformSourceFile(currentSourceFile);
            try diags.appendSlice(transformer.getDiagnostics());
        }

        const outDiags = try diags.toOwnedSlice();
        return .{ currentSourceFile, outDiags };
    }

    pub fn emitJSFile(self: *Emitter, sourceFile: ast_gen.NodeIndex, jsFilePath: []const u8, sourceMapFilePath: []const u8) !void {
        const options = self.host.options();

        if (sourceFile == 0 or (self.emitOnly != .EmitAll and self.emitOnly != .EmitOnlyJs) or jsFilePath.len == 0) {
            return;
        }

        if (options.noEmit == core.TSTrue or self.host.isEmitBlocked(jsFilePath)) {
            self.emitResult.EmitSkipped = true;
            return;
        }

        if (self.tr) |tr| {
            // TODO: tracing
            _ = tr;
        }

        var nodeFactory = factory.NodeFactory.init(self.allocator, self.host.astState);
        defer nodeFactory.deinit();

        var emitContext = emitcontext.EmitContext.init(self.allocator, self.host.astState, &nodeFactory);
        defer emitContext.deinit();

        const transformedSourceFile = try self.runScriptTransformers(&emitContext, sourceFile);

        const printerOptions = printer.PrinterOptions{
            .removeComments = options.removeComments.isTrue(),
            .newLine = options.newLine,
            .noEmitHelpers = options.noEmitHelpers.isTrue(),
            .sourceMap = options.sourceMap.isTrue(),
            .inlineSourceMap = options.inlineSourceMap.isTrue(),
            .inlineSources = options.inlineSources.isTrue(),
            .target = options.target,
        };

        var pr = printer.Printer.init(self.host.astState, &emitContext, self.writer, printerOptions, printer.PrintHandlers{});
        defer pr.deinit();

        try self.printSourceFile(jsFilePath, sourceMapFilePath, transformedSourceFile, &pr, options, shouldEmitSourceMaps(options, transformedSourceFile, self.host.astState));
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

        var nodeFactory = factory.NodeFactory.init(self.allocator, self.host.astState);
        defer nodeFactory.deinit();

        var emitContext = emitcontext.EmitContext.init(self.allocator, self.host.astState, &nodeFactory);
        defer emitContext.deinit();

        const result = try self.runDeclarationTransformers(&emitContext, sourceFile, declarationFilePath, declarationMapPath);
        const transformedSourceFile = result[0];
        const diags = result[1];
        defer self.allocator.free(diags);

        for (diags) |elem| {
            try self.emitterDiagnostics.append(elem);
        }

        if (self.emitOnly != .EmitOnlyForcedDts and (options.noEmit == core.TSTrue or self.host.isEmitBlocked(declarationFilePath))) {
            self.emitResult.EmitSkipped = true;
            return;
        }

        const declBlocked = diags.len > 0 and self.emitOnly != .EmitOnlyForcedDts;
        if (declBlocked) {
            self.emitResult.EmitSkipped = true;
            return;
        }

        const printerOptions = printer.PrinterOptions{
            .removeComments = options.removeComments.isTrue(),
            .newLine = options.newLine,
            .noEmitHelpers = true,
            .target = options.getEmitScriptTarget(),
            .sourceMap = self.emitOnly != .EmitOnlyForcedDts and options.declarationMap.isTrue(),
            .inlineSourceMap = options.inlineSourceMap.isTrue(),
            .onlyPrintJSDocStyle = true,
            .omitBraceSourceMapPositions = true,
        };

        var pr = printer.Printer.init(self.host.astState, &emitContext, self.writer, printerOptions, printer.PrintHandlers{});
        defer pr.deinit();

        var declarationMapOptions = core.CompilerOptions{
            .sourceMap = if (self.emitOnly != .EmitOnlyForcedDts and options.declarationMap.isTrue()) core.TSTrue else core.TSFalse,
            .sourceRoot = options.sourceRoot,
            .mapRoot = options.mapRoot,
        };

        try self.printSourceFile(declarationFilePath, declarationMapPath, transformedSourceFile, &pr, &declarationMapOptions, shouldEmitSourceMaps(&declarationMapOptions, transformedSourceFile, self.host.astState));
    }

    pub fn printSourceFile(self: *Emitter, jsFilePath: []const u8, sourceMapFilePath: []const u8, sourceFile: ast_gen.NodeIndex, printer_: *printer.Printer, mapOptions: *core.CompilerOptions, shouldEmitSourceMapsFlag: bool) !void {
        const options = self.host.options();
        var sourceMapGenerator: ?*sourcemap.Generator = null;

        if (shouldEmitSourceMapsFlag) {
            const baseFileName = tspath.getBaseFileName(tspath.normalizeSlashes(self.allocator, jsFilePath));
            defer self.allocator.free(baseFileName);
            
            const sourceRoot = try getSourceRoot(self.allocator, mapOptions);
            defer self.allocator.free(sourceRoot);
            
            const smDir = try self.getSourceMapDirectory(mapOptions, jsFilePath, sourceFile);
            defer self.allocator.free(smDir);

            sourceMapGenerator = try sourcemap.Generator.init(
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

        try printer_.write(sourceFile, sourceFile, self.writer, sourceMapGenerator);

        var sourceMapUrlPos: isize = -1;
        if (sourceMapGenerator) |g| {
            if (mapOptions.sourceMap.isTrue() or mapOptions.inlineSourceMap.isTrue()) {
                const newSM = try self.allocator.create(SourceMapEmitResult);
                newSM.* = SourceMapEmitResult{
                    .InputSourceFileNames = try self.allocator.dupe([]const u8, g.sources()),
                    .SourceMap = try self.allocator.dupe(u8, g.rawSourceMap()),
                    .GeneratedFile = try self.allocator.dupe(u8, jsFilePath),
                };
                
                var smList = std.ArrayList(*SourceMapEmitResult).fromOwnedSlice(self.allocator, self.emitResult.SourceMaps);
                try smList.append(newSM);
                self.emitResult.SourceMaps = try smList.toOwnedSlice();
            }

            const sourceMappingURL = try self.getSourceMappingURL(mapOptions, g, jsFilePath, sourceMapFilePath, sourceFile);
            defer self.allocator.free(sourceMappingURL);

            if (sourceMappingURL.len > 0) {
                if (!self.writer.isAtStartOfLine()) {
                    try self.writer.rawWrite(if (options.newLine == core.NewLineKindCRLF) "\r\n" else "\n");
                }
                sourceMapUrlPos = @intCast(self.writer.getTextPos());
                try self.writer.writeComment("//# sourceMappingURL=");
                try self.writer.writeComment(sourceMappingURL);
            }

            if (sourceMapFilePath.len > 0) {
                const sourceMapStr = try g.toString(self.allocator);
                defer self.allocator.free(sourceMapStr);
                
                if (self.writeText(sourceMapFilePath, sourceMapStr, null)) |_| {
                    var efList = std.ArrayList([]const u8).fromOwnedSlice(self.allocator, self.emitResult.EmittedFiles);
                    try efList.append(try self.allocator.dupe(u8, sourceMapFilePath));
                    self.emitResult.EmittedFiles = try efList.toOwnedSlice();
                } else |err| {
                    const diag = diagnostics.CompilerDiagnostic.init(diagnostics.Could_not_write_file_0_Colon_1, &.{ jsFilePath, @errorName(err) });
                    try self.emitterDiagnostics.append(diag);
                }
            }
        } else {
            try self.writer.writeLine();
        }

        var text = try self.allocator.dupe(u8, self.writer.string());
        defer self.allocator.free(text);
        
        if (options.emitBOM.isTrue()) {
            text = try stringutil.addUTF8ByteOrderMark(self.allocator, text);
        }

        var data = WriteFileData{
            .SourceMapUrlPos = sourceMapUrlPos,
            .Diagnostics = try self.allocator.dupe(diagnostics.Diagnostic, self.emitterDiagnostics.items),
        };
        defer self.allocator.free(data.Diagnostics);

        if (self.writeText(jsFilePath, text, &data)) |_| {
            if (!data.SkippedDtsWrite) {
                var efList = std.ArrayList([]const u8).fromOwnedSlice(self.allocator, self.emitResult.EmittedFiles);
                try efList.append(try self.allocator.dupe(u8, jsFilePath));
                self.emitResult.EmittedFiles = try efList.toOwnedSlice();
            }
        } else |err| {
            const diag = diagnostics.CompilerDiagnostic.init(diagnostics.Could_not_write_file_0_Colon_1, &.{ jsFilePath, @errorName(err) });
            try self.emitterDiagnostics.append(diag);
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
        if (mapOptions.sourceRoot.len > 0) {
            return try self.allocator.dupe(u8, self.host.commonSourceDirectory());
        }
        if (mapOptions.mapRoot.len > 0) {
            var sourceMapDir = try tspath.normalizeSlashes(self.allocator, mapOptions.mapRoot);
            defer self.allocator.free(sourceMapDir);

            if (sourceFile != 0) {
                const srcFileName = try ast_utils.getFileName(self.host.astState, sourceFile);
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
                const combined = try tspath.combinePaths(self.allocator, self.host.commonSourceDirectory(), sourceMapDir);
                return combined;
            }
            return try self.allocator.dupe(u8, sourceMapDir);
        }
        return try tspath.getDirectoryPath(self.allocator, try tspath.normalizePath(self.allocator, filePath));
    }

    pub fn getSourceMappingURL(self: *Emitter, mapOptions: *core.CompilerOptions, sourceMapGenerator: *sourcemap.Generator, filePath: []const u8, sourceMapFilePath: []const u8, sourceFile: ast_gen.NodeIndex) ![]const u8 {
        if (mapOptions.inlineSourceMap.isTrue()) {
            return try sourceMapGenerator.base64DataURL(self.allocator);
        }

        const sourceMapFile = try tspath.getBaseFileName(try tspath.normalizeSlashes(self.allocator, sourceMapFilePath));
        defer self.allocator.free(sourceMapFile);

        if (mapOptions.mapRoot.len > 0) {
            var sourceMapDir = try tspath.normalizeSlashes(self.allocator, mapOptions.mapRoot);
            defer self.allocator.free(sourceMapDir);

            if (sourceFile != 0) {
                const srcFileName = try ast_utils.getFileName(self.host.astState, sourceFile);
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
                const combinedDir = try tspath.combinePaths(self.allocator, self.host.commonSourceDirectory(), sourceMapDir);
                defer self.allocator.free(combinedDir);

                const dirOfFile = try tspath.getDirectoryPath(self.allocator, try tspath.normalizePath(self.allocator, filePath));
                defer self.allocator.free(dirOfFile);

                const combinedWithFile = try tspath.combinePaths(self.allocator, combinedDir, sourceMapFile);
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
                const combined = try tspath.combinePaths(self.allocator, sourceMapDir, sourceMapFile);
                defer self.allocator.free(combined);
                return try stringutil.encodeURI(self.allocator, combined);
            }
        }
        return try stringutil.encodeURI(self.allocator, sourceMapFile);
    }
};

pub fn getModuleTransformer(allocator: std.mem.Allocator, opts: *transformers.TransformOptions) !*transformers.Transformer {
    switch (opts.compilerOptions.getEmitModuleKind()) {
        core.ModuleKindPreserve => {
            return try moduletransforms.ESModuleTransformer.newESModuleTransformer(allocator, opts);
        },
        core.ModuleKindESNext,
        core.ModuleKindES2022,
        core.ModuleKindES2020,
        core.ModuleKindES2015,
        core.ModuleKindNode20,
        core.ModuleKindNode18,
        core.ModuleKindNode16,
        core.ModuleKindNodeNext,
        core.ModuleKindCommonJS => {
            return try moduletransforms.ImpliedModuleTransformer.newImpliedModuleTransformer(allocator, opts);
        },
        else => {
            return try moduletransforms.CommonJSModuleTransformer.newCommonJSModuleTransformer(allocator, opts);
        },
    }
}

pub fn getScriptTransformers(allocator: std.mem.Allocator, emitContext: *emitcontext.EmitContext, host: emithost.EmitHost, sourceFile: ast_gen.NodeIndex) !std.ArrayList(*transformers.Transformer) {
    var tx = std.ArrayList(*transformers.Transformer).init(allocator);
    const options = host.options();

    const isJSFile = ast_utils.isInJSFile(host.astState, sourceFile);
    const importElisionEnabled = !options.verbatimModuleSyntax.isTrue() and !isJSFile;
    const jsxTransformEnabled = options.getJSXTransformEnabled() and ast_utils.getLanguageVariant(host.astState, sourceFile) == core.LanguageVariantJSX;

    const emitResolver = host.getEmitResolver();
    var referenceResolver: binder.ReferenceResolver = undefined;

    if (importElisionEnabled or jsxTransformEnabled or !options.getIsolatedModules() or options.emitDecoratorMetadata.isTrue()) {
        try emitResolver.markLinkedReferencesRecursively(sourceFile);
        referenceResolver = emitResolver.asReferenceResolver();
    } else {
        referenceResolver = binder.ReferenceResolver.init(host.astState, options, .{});
    }

    var opts = transformers.TransformOptions{
        .context = emitContext,
        .compilerOptions = options,
        .resolver = &referenceResolver,
        .emitResolver = emitResolver,
        .getEmitModuleFormatOfFile = &host.getEmitModuleFormatOfFile,
    };

    if (options.emitDecoratorMetadata.isTrue()) {
        tx.append(try tstransforms.MetadataTransformer.new(allocator, &opts)) catch unreachable;
    }

    tx.append(try tstransforms.TypeEraserTransformer.newTypeEraserTransformer(allocator, &opts)) catch unreachable;

    if (importElisionEnabled) {
        tx.append(try tstransforms.ImportElisionTransformer.new(allocator, &opts)) catch unreachable;
    }

    tx.append(try tstransforms.RuntimeSyntaxTransformer.newRuntimeSyntaxTransformer(allocator, &opts)) catch unreachable;

    if (options.experimentalDecorators.isTrue()) {
        tx.append(try tstransforms.LegacyDecoratorsTransformer.new(allocator, &opts)) catch unreachable;
    }

    if (jsxTransformEnabled) {
        tx.append(try jsxtransforms.JSXTransformer.new(allocator, &opts)) catch unreachable;
    }

    if (try estransforms.getESTransformer(allocator, &opts)) |downleveler| {
        tx.append(downleveler) catch unreachable;
    }

    tx.append(try estransforms.UseStrictTransformer.new(allocator, &opts)) catch unreachable;

    tx.append(try getModuleTransformer(allocator, &opts)) catch unreachable;

    if (!options.getIsolatedModules()) {
        tx.append(try inliners.ConstEnumInliningTransformer.new(allocator, &opts)) catch unreachable;
    }

    return tx;
}

pub fn shouldEmitSourceMaps(mapOptions: *core.CompilerOptions, sourceFile: ast_gen.NodeIndex, astState: *ast.Ast) bool {
    const fileName = ast_utils.getFileName(astState, sourceFile) catch "";
    return (mapOptions.sourceMap.isTrue() or mapOptions.inlineSourceMap.isTrue()) and
        !tspath.fileExtensionIs(fileName, tspath.ExtensionJson);
}

pub fn getSourceRoot(allocator: std.mem.Allocator, mapOptions: *core.CompilerOptions) ![]const u8 {
    var sourceRoot = try tspath.normalizeSlashes(allocator, mapOptions.sourceRoot);
    if (sourceRoot.len > 0) {
        const withTrailing = try tspath.ensureTrailingDirectorySeparator(allocator, sourceRoot);
        allocator.free(sourceRoot);
        sourceRoot = withTrailing;
    }
    return sourceRoot;
}

pub fn sourceFileMayBeEmitted(host: emithost.EmitHost, sourceFile: ast_gen.NodeIndex, forceDtsEmit: bool) !bool {
    const options = host.options();
    if (options.noEmitForJsFiles.isTrue() and ast_utils.isSourceFileJS(host.astState, sourceFile)) {
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
    var sourceFiles = std.ArrayList(ast_gen.NodeIndex).init(allocator);
    defer sourceFiles.deinit();

    if (targetSourceFile != 0) {
        try sourceFiles.append(targetSourceFile);
    } else {
        const allFiles = host.sourceFiles();
        try sourceFiles.appendSlice(allFiles);
    }

    var result = std.ArrayList(ast_gen.NodeIndex).init(allocator);
    for (sourceFiles.items) |sf| {
        if (try sourceFileMayBeEmitted(host, sf, forceDtsEmit)) {
            try result.append(sf);
        }
    }
    return try result.toOwnedSlice();
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
