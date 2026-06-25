const std = @import("std");
const ast = @import("../ast/ast.zig");
const compiler = @import("../compiler/program.zig");
const autoimport = @import("../project/autoimport.zig");
const lsconv = @import("lsconv.zig");
const lsutil = @import("lsutil/lsutil.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const sourcemap = @import("../sourcemap/sourcemap.zig");
const tspath = @import("../tspath/tspath.zig");
const vfsmatch = @import("../vfs/vfsmatch.zig");
const host_module = @import("host.zig");
const diagnostics = @import("diagnostics.zig");
const definition = @import("definition.zig");
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
    documentPositionMappers: std.StringHashMapUnmanaged(*sourcemap.DocumentPositionMapper),

    pub fn init(
        allocator: std.mem.Allocator,
        projectPath: tspath.Path,
        program: *compiler.Program,
        host: host_module.Host,
        activeFile: []const u8,
    ) !*LanguageService {
        const self = try allocator.create(LanguageService);
        self.* = .{
            .allocator = allocator,
            .projectPath = projectPath,
            .host = host,
            .program = program,
            .converters = host.converters(),
            .activeConfig = host.getPreferences(activeFile),
            .documentPositionMappers = .{},
        };
        return self;
    }

    pub fn deinit(self: *LanguageService) void {
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
        file: ast.NodeIndex,
    };

    pub fn tryGetProgramAndFile(self: *LanguageService, fileName: []const u8) ProgramAndFile {
        const program = self.getProgram();
        const file = program.getSourceFile(fileName);
        return .{ .program = program, .file = file };
    }

    pub fn getProgramAndFile(self: *LanguageService, documentURI: lsproto.DocumentUri) ProgramAndFile {
        const fileName = documentURI.fileName();
        const res = self.tryGetProgramAndFile(fileName);
        if (res.file == ast.null_node) {
            std.debug.panic("file not found: {s}", .{fileName});
        }
        return res;
    }

    pub fn getDocumentPositionMapper(self: *LanguageService, fileName: []const u8) *sourcemap.DocumentPositionMapper {
        if (self.documentPositionMappers.get(fileName)) |d| {
            return d;
        }
        const d = sourcemap.getDocumentPositionMapper(self, fileName);
        self.documentPositionMappers.put(self.allocator, fileName, d) catch @panic("OOM");
        return d;
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

    pub fn provideHover(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        params: *lsproto.HoverParams,
    ) !lsproto.HoverOrNull {
        return hover.provideHover(self, allocator, params);
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

    pub fn provideCodeActions(
        self: *LanguageService,
        allocator: std.mem.Allocator,
        params: *lsproto.CodeActionParams,
    ) !?[]lsproto.CodeAction {
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
    ) !?lsproto.SignatureHelp {
        return signaturehelp.provideSignatureHelp(self, allocator, documentURI, position);
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
    ) !?[]lsproto.DocumentSymbol {
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
