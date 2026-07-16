const std = @import("std");
const ast = @import("../ast/ast.zig");
const compiler = @import("../compiler/program.zig");
const checker = @import("../checker/checker.zig");
const types = @import("../checker/types.zig");
const autoimport = @import("../project/autoimport.zig");
const lsconv = @import("lsconv.zig");
const lsutil = @import("lsutil/lsutil.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const sourcemap = @import("../sourcemap/sourcemap.zig");
const tspath = @import("../tspath/tspath.zig");
const vfsmatch = @import("../vfs/vfsmatch.zig");
const host_module = @import("host.zig");
const diagnostics = @import("diagnostics.zig");
const api = @import("api.zig");
const astnav = @import("../astnav/tokens.zig");
const autoinsert = @import("autoinsert.zig");
const definition = @import("definition.zig");
const format = @import("format.zig");
const hover = @import("hover.zig");
const completions = @import("completions.zig");
const codeactions = @import("codeactions.zig");
const semantictokens = @import("semantictokens.zig");
const documenthighlights = @import("documenthighlights.zig");
const rename = @import("rename.zig");
const organizeimports = @import("organizeimports.zig");
const signaturehelp = @import("signaturehelp.zig");
const folding = @import("folding.zig");
const inlay_hints = @import("inlay_hints.zig");
const callhierarchy = @import("callhierarchy.zig");
const symbols = @import("symbols.zig");
const selectionranges = @import("selectionranges.zig");

pub const ErrNeedsAutoImports = error.NeedsAutoImports;

pub const LanguageService = struct {
    allocator: std.mem.Allocator,
    projectPath: tspath.Path,
    host: host_module.Host,
    activeConfig: lsutil.UserPreferences,
    program: *compiler.Program,
    converters: *lsconv.Converters,
    documentPositionMappers: std.StringHashMapUnmanaged(*sourcemap.source_mapper.DocumentPositionMapper),
    checker_cache: std.AutoHashMap(compiler.FileId, *checker.Checker),

    pub fn init(
        allocator: std.mem.Allocator,
        projectPath: tspath.Path,
        program: *compiler.Program,
        host: host_module.Host,
        activeFile: []const u8,
    ) !*LanguageService {
        const self = try allocator.create(LanguageService);
        self.* = LanguageService{
            .allocator = allocator,
            .projectPath = projectPath,
            .host = host,
            .activeConfig = host.getPreferences(activeFile),
            .program = program,
            .converters = host.converters(),
            .documentPositionMappers = .{},
            .checker_cache = std.AutoHashMap(compiler.FileId, *checker.Checker).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *LanguageService) void {
        var it = self.checker_cache.valueIterator();
        while (it.next()) |chk_ptr| {
            chk_ptr.*.deinit();
            self.allocator.destroy(chk_ptr.*);
        }
        self.checker_cache.deinit();
        self.documentPositionMappers.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn toPath(self: *LanguageService, fileName: []const u8) tspath.Path {
        return tspath.toPath(fileName, self.program.getCurrentDirectory(), self.useCaseSensitiveFileNames());
    }

    pub fn getProgram(self: *LanguageService) *compiler.Program {
        return self.program;
    }

    pub fn userPreferences(self: *LanguageService) lsutil.UserPreferences {
        return self.activeConfig;
    }

    pub fn formatOptions(self: *LanguageService) lsutil.FormatCodeSettings {
        return self.activeConfig.formatCodeSettings;
    }

    pub const ProgramAndFile = struct {
        program: *compiler.Program,
        file: compiler.FileId,
    };

    pub fn tryGetProgramAndFile(self: *LanguageService, fileName: []const u8) ?ProgramAndFile {
        const program = self.getProgram();
        const file = program.getFileId(fileName) orelse return null;
        return .{ .program = program, .file = file };
    }

    pub fn getProgramAndFile(self: *LanguageService, documentURI: lsproto.DocumentUri) ProgramAndFile {
        const fileName = documentURI.fileName();
        const res = self.tryGetProgramAndFile(fileName);
        if (res == null) {
            std.debug.panic("file not found: {s}", .{fileName});
        }
        return res.?;
    }

    pub fn getMappedLocation(self: *LanguageService, fileName: []const u8, fileRange: ast.TextRange) lsproto.Location {
        const startPos = self.tryGetSourcePosition(fileName, @as(isize, @intCast(fileRange.pos)));
        if (startPos == null) {
            const script = self.getScript(self.program.getFileId(fileName).?);
            const lspRange = self.converters.toLSPRange(script, fileRange);
            return lsproto.Location{
                .uri = lsconv.fileNameToDocumentURI(self.allocator, fileName) catch @panic("OOM"),
                .range = lspRange,
            };
        }
        var endPos = self.tryGetSourcePosition(fileName, @as(isize, @intCast(fileRange.end)));
        if (endPos == null or !std.mem.eql(u8, endPos.?.fileName, startPos.?.fileName) or endPos.?.pos < startPos.?.pos) {
            endPos = sourcemap.source_mapper.DocumentPosition{
                .fileName = startPos.?.fileName,
                .pos = startPos.?.pos + @as(isize, @intCast(fileRange.end - fileRange.pos)),
            };
        }
        const newRange = ast.TextRange{ .pos = @intCast(startPos.?.pos), .end = @intCast(endPos.?.pos) };
        const script = self.getScript(self.program.getFileId(startPos.?.fileName).?);
        const lspRange = self.converters.toLSPRange(script, newRange);
        return lsproto.Location{
            .uri = lsconv.fileNameToDocumentURI(self.allocator, startPos.?.fileName) catch @panic("OOM"),
            .range = lspRange,
        };
    }

    pub fn tryGetSourcePosition(self: *LanguageService, fileName: []const u8, position: isize) ?sourcemap.source_mapper.DocumentPosition {
        const newPos = self.tryGetSourcePositionWorker(fileName, position);
        if (newPos) |pos| {
            if (self.readFile(pos.fileName) == null) {
                return null;
            }
        }
        return newPos;
    }

    pub fn tryGetSourcePositionWorker(self: *LanguageService, fileName: []const u8, position: isize) ?sourcemap.source_mapper.DocumentPosition {
        if (!tspath.isDeclarationFileName(fileName)) {
            return null;
        }

        const positionMapper = self.getDocumentPositionMapper(fileName);
        const posToQuery = sourcemap.source_mapper.DocumentPosition{ .fileName = fileName, .pos = position };
        const documentPos = positionMapper.getSourcePosition(&posToQuery) orelse return null;
        if (self.tryGetSourcePositionWorker(documentPos.fileName, documentPos.pos)) |newPos| {
            return newPos;
        }
        return documentPos;
    }

    pub fn getDocumentPositionMapper(self: *LanguageService, fileName: []const u8) *sourcemap.DocumentPositionMapper {
        if (self.documentPositionMappers.get(fileName)) |d| {
            return d;
        }
        const d = sourcemap.getDocumentPositionMapper(self, fileName);
        self.documentPositionMappers.put(self.allocator, fileName, d) catch @panic("OOM");
        return d;
    }

    pub fn getAst(self: *LanguageService, file: compiler.FileId) *ast.Ast {
        return self.program.getUnit(file).tree();
    }

    pub fn getSourceFileNode(self: *LanguageService, file: compiler.FileId) ast.NodeIndex {
        return self.program.getUnit(file).source_file;
    }

    pub fn getScript(self: *LanguageService, file: compiler.FileId) lsconv.Script {
        const unit = self.program.getUnit(file);
        return .{
            .file_name = unit.path,
            .content = unit.content,
        };
    }

    pub fn getTypeCheckerForFile(self: *LanguageService, file: compiler.FileId) *checker.Checker {
        if (self.checker_cache.get(file)) |chk| {
            return chk;
        }
        const unit = self.program.getUnit(file);
        const bound = self.program.getBinder(file) orelse @panic("no binder for file");
        const chk = self.allocator.create(checker.Checker) catch @panic("OOM");
        chk.* = checker.Checker.init(self.allocator, bound);
        chk.checkStatementAdHoc(unit.source_file) catch unreachable;
        self.checker_cache.put(file, chk) catch @panic("OOM");
        return chk;
    }

    pub fn getSymbolAtPosition(self: *LanguageService, fileName: []const u8, position: u32) !ast.SymbolIndex {
        const res = self.tryGetProgramAndFile(fileName) orelse return api.ErrNoSourceFile;
        const a = self.getAst(res.file);
        const source_file = self.getSourceFileNode(res.file);
        const node = astnav.getTokenAtPosition(source_file, a, position);
        if (node == 0) return api.ErrNoTokenAtPosition;

        const chk = self.getTypeCheckerForFile(res.file);
        return chk.getSymbolAtLocation(node);
    }

    pub fn getSymbolAtLocation(self: *LanguageService, file: compiler.FileId, node: ast.NodeIndex) ast.SymbolIndex {
        const chk = self.getTypeCheckerForFile(file);
        return chk.getSymbolAtLocation(node);
    }

    pub fn getTypeOfSymbol(self: *LanguageService, file: compiler.FileId, symbol: ast.SymbolIndex) types.TypeIndex {
        const chk = self.getTypeCheckerForFile(file);
        return chk.getTypeOfSymbolAtLocation(symbol, 0);
    }

    pub fn readFile(self: *LanguageService, fileName: []const u8) ?[]const u8 {
        return self.host.readFile(fileName, self.allocator);
    }

    pub fn useCaseSensitiveFileNames(self: *LanguageService) bool {
        return self.host.useCaseSensitiveFileNames();
    }

    pub fn getECMALineInfo(self: *LanguageService, fileName: []const u8) *sourcemap.ECMALineInfo {
        return self.host.getECMALineInfo(fileName);
    }

    pub fn getPreparedAutoImportView(self: *LanguageService, fromFile: ast.NodeIndex) !?*autoimport.View {
        if (self.userPreferences().includeCompletionsForModuleExports.isFalse()) {
            return null;
        }
        const registry = self.host.autoImportRegistry();
        const file_name = self.program.getAstNode(fromFile).source_file.fileName;
        if (!registry.isPreparedForImportingFile(file_name, self.projectPath, self.userPreferences())) {
            return ErrNeedsAutoImports;
        }

        return autoimport.NewView(self.allocator, registry, fromFile, self.projectPath, self.program, self.userPreferences().moduleSpecifierPreferences());
    }

    pub fn getCurrentAutoImportView(self: *LanguageService, fromFile: ast.NodeIndex) *autoimport.View {
        return autoimport.NewView(
            self.allocator,
            self.host.autoImportRegistry(),
            fromFile,
            self.projectPath,
            self.program,
            self.userPreferences().moduleSpecifierPreferences(),
        );
    }

    pub fn directoryExists(self: *LanguageService, path: []const u8) bool {
        return self.host.directoryExists(path);
    }

    pub fn readDirectory(self: *LanguageService, path: []const u8, extensions: []const []const u8, includes: []const []const u8) []const []const u8 {
        return self.host.readDirectory(self.program.getCurrentDirectory(), path, extensions, &[_][]const u8{}, includes, vfsmatch.unlimitedDepth, self.allocator);
    }

    pub fn getDirectories(self: *LanguageService, path: []const u8) []const []const u8 {
        return self.host.getDirectories(path, self.allocator);
    }

    pub fn provideDiagnostics(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        uri: lsproto.DocumentUri,
    ) !lsproto.DocumentDiagnosticResponse {
        return diagnostics.provideDiagnostics(self, allocator, uri);
    }

    pub fn provideDefinition(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        documentURI: lsproto.DocumentUri,
        position: lsproto.Position,
    ) !lsproto.DefinitionResponse {
        return definition.provideDefinition(self, allocator, documentURI, position);
    }

    pub fn provideOnAutoInsert(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        params: *lsproto.VSOnAutoInsertParams,
    ) !?lsproto.VSOnAutoInsertResponse {
        return autoinsert.provideOnAutoInsert(self, allocator, params);
    }

    pub fn provideHover(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        params: *lsproto.HoverParams,
    ) !lsproto.HoverOrNull {
        return hover.provideHover(self, allocator, params);
    }

    pub fn provideFormatDocument(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        documentURI: lsproto.DocumentUri,
        options: *const lsproto.FormattingOptions,
    ) !lsproto.TextEditsOrNull {
        return format.provideFormatDocument(self, allocator, documentURI, options);
    }

    pub fn provideFormatDocumentRange(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        documentURI: lsproto.DocumentUri,
        options: *const lsproto.FormattingOptions,
        range: lsproto.Range,
    ) !lsproto.TextEditsOrNull {
        return format.provideFormatDocumentRange(self, allocator, documentURI, options, range);
    }

    pub fn provideFormatDocumentOnType(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        documentURI: lsproto.DocumentUri,
        options: *const lsproto.FormattingOptions,
        position: lsproto.Position,
        character: []const u8,
    ) !lsproto.TextEditsOrNull {
        return format.provideFormatDocumentOnType(self, allocator, documentURI, options, position, character);
    }

    pub fn provideCompletion(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        documentURI: lsproto.DocumentUri,
        position: lsproto.Position,
        context: ?*lsproto.CompletionContext,
    ) !lsproto.CompletionResponse {
        return completions.provideCompletion(self, allocator, documentURI, position, context);
    }

    pub fn resolveCompletionItem(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        item: *lsproto.CompletionItem,
        data: *lsproto.CompletionItemData,
    ) !lsproto.CompletionResolveResponse {
        return completions.resolveCompletionItem(self, allocator, item, data);
    }

    pub fn provideCodeActions(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        params: *lsproto.CodeActionParams,
    ) !?[]lsproto.CommandOrCodeAction {
        return codeactions.getCodeActions(self, allocator, params);
    }

    pub fn provideDocumentSemanticTokens(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        params: *lsproto.SemanticTokensParams,
    ) !?lsproto.SemanticTokens {
        return semantictokens.provideDocumentSemanticTokens(self, allocator, params);
    }

    pub fn provideDocumentHighlights(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        documentURI: lsproto.DocumentUri,
        position: lsproto.Position,
    ) !?[]lsproto.DocumentHighlight {
        return documenthighlights.provideDocumentHighlights(self, allocator, documentURI, position);
    }

    pub fn provideRenameEdits(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        params: *lsproto.RenameParams,
    ) !?lsproto.WorkspaceEdit {
        return rename.provideRenameEdits(self, allocator, params);
    }

    pub fn organizeImports(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        params: *lsproto.CodeActionParams,
    ) !?[]lsproto.CodeAction {
        return organizeimports.organizeImports(self, allocator, params);
    }

    pub fn provideSignatureHelp(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        documentURI: lsproto.DocumentUri,
        position: lsproto.Position,
        context: ?lsproto.SignatureHelpContext,
    ) !?lsproto.SignatureHelp {
        return signaturehelp.provideSignatureHelp(self, allocator, documentURI, position, context);
    }

    pub fn provideFoldingRanges(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        documentURI: lsproto.DocumentUri,
    ) !?[]lsproto.FoldingRange {
        return folding.provideFoldingRanges(self, allocator, documentURI);
    }

    pub fn provideInlayHints(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        params: *lsproto.InlayHintParams,
    ) !?[]lsproto.InlayHint {
        return inlay_hints.provideInlayHints(self, allocator, params);
    }

    pub fn prepareCallHierarchy(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        params: *lsproto.CallHierarchyPrepareParams,
    ) !?[]lsproto.CallHierarchyItem {
        return callhierarchy.prepareCallHierarchy(self, allocator, params);
    }

    pub fn provideCallHierarchyIncomingCalls(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        params: *lsproto.CallHierarchyIncomingCallsParams,
    ) !?[]lsproto.CallHierarchyIncomingCall {
        return callhierarchy.provideCallHierarchyIncomingCalls(self, allocator, params);
    }

    pub fn provideCallHierarchyOutgoingCalls(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        params: *lsproto.CallHierarchyOutgoingCallsParams,
    ) !?[]lsproto.CallHierarchyOutgoingCall {
        return callhierarchy.provideCallHierarchyOutgoingCalls(self, allocator, params);
    }

    pub fn provideDocumentSymbols(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        documentURI: lsproto.DocumentUri,
    ) !?lsproto.DocumentSymbolResponse {
        return symbols.provideDocumentSymbols(self, allocator, documentURI);
    }

    pub fn provideWorkspaceSymbols(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        query: []const u8,
    ) !?[]lsproto.SymbolInformation {
        return symbols.provideWorkspaceSymbols(self, allocator, query);
    }

    pub fn provideSelectionRanges(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        params: *lsproto.SelectionRangeParams,
    ) !?[]lsproto.SelectionRange {
        return selectionranges.provideSelectionRanges(self, allocator, params);
    }
};
