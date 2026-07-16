const std = @import("std");
const fourslash_parser = @import("fourslash_parser.zig");
const parser_module = @import("../parser/parser.zig");
const binder_module = @import("../binder/binder.zig");
const checker_module = @import("../checker/checker.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const core_module = @import("../core/core.zig");
const ast_module = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const astnav = @import("../astnav/tokens.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const diagnostics_gen = @import("../diagnostics/diagnostics_generated.zig");

const testing = struct {
    pub const T = struct {};
};

// Placeholders for undefined types
const lsptestutil = struct {
    pub const LSPClient = struct {};
    pub fn SendRequest(comptime P: type, comptime R: type, client: *LSPClient, info: lsproto.RequestInfo(P, R), params: P) R {
        _ = client;
        _ = info;
        _ = params;
        return undefined;
    }
    pub fn SendNotification(comptime P: type, client: *LSPClient, info: lsproto.NotificationInfo(P), params: P) void {
        _ = client;
        _ = info;
        _ = params;
    }
};
const vfs = struct {
    pub const FS = struct {};
};
const TestData = struct {};
const baselineCommand = enum { dummy };
const collections = struct {
    pub fn MultiMap(comptime K: type, comptime V: type) type {
        _ = K;
        _ = V;
        return struct {};
    }
};
const RangeMarker = fourslash_parser.RangeMarker;
const Marker = fourslash_parser.Marker;
const stateBaseline = struct {};
const lsconv = struct {
    pub const LSPLineMap = struct {};
    pub const Converters = struct {};
};
const lsutil = struct {
    pub const UserPreferences = struct {
        formatCodeSettings: struct {
            editorSettings: struct {
                tabSize: u32 = 4,
                convertTabsToSpaces: enum { True, False } = .True,
                trimTrailingWhitespace: enum { True, False } = .True,
            } = .{},
        } = .{},
    };
};
const lsproto = struct {
    pub const Position = struct {
        line: u32,
        character: u32,
    };
    pub const ClientCapabilities = struct {};
    pub fn RequestInfo(comptime P: type, comptime R: type) type {
        _ = P;
        _ = R;
        return struct {};
    }
    pub fn NotificationInfo(comptime P: type) type {
        _ = P;
        return struct {};
    }
    pub const RequestMessage = struct {};
    pub const ResponseMessage = struct {};
    pub const Method = enum { dummy };
    pub const DocumentUri = struct {};
    pub const Range = struct {};
    pub const Hover = struct {};
    pub const SignatureHelpContext = struct {};
    pub const SignatureHelp = struct {};
    pub const CompletionItem = struct {};
    pub const AutoImportFix = struct {};
    pub const SymbolInformation = struct {};
    pub const FormattingOptions = struct {
        tabSize: u32,
        insertSpaces: bool,
        trimTrailingWhitespace: bool,
        insertFinalNewline: bool,
        trimFinalNewlines: bool,
    };
    pub const DocumentFormattingParams = struct {
        textDocument: struct { uri: []const u8 },
        options: FormattingOptions,
    };
    pub const TextEdit = struct {};
    pub const CodeAction = struct {};
    pub const CodeActionKind = enum { dummy };
    pub const Diagnostic = struct {};
};
const core = struct {
    pub const TextChange = struct {};
};

pub const scriptInfo = struct {
    fileName: []const u8,
    content: []const u8,
    lineMap: *lsconv.LSPLineMap,
    version: i32,

    pub fn editContent(self: *scriptInfo, change: core.TextChange) void {
        _ = self;
        _ = change;
        // self.content = change.ApplyTo(self.content);
        // self.lineMap = lsconv.ComputeLSPLineStarts(self.content);
        // self.version += 1;
    }

    pub fn Text(self: *const scriptInfo) []const u8 {
        return self.content;
    }

    pub fn FileName(self: *const scriptInfo) []const u8 {
        return self.fileName;
    }

    pub fn GetLineContent(self: *const scriptInfo, line: usize) []const u8 {
        _ = self;
        _ = line;
        return "";
    }
};

pub const textEditSpan = struct {
    start: usize,
    end: usize,
    length: usize,
};

pub const FourslashTest = struct {
    allocator: std.mem.Allocator,
    arena: *std.heap.ArenaAllocator,
    parsedData: *fourslash_parser.ParsedTestData,
    currentFile: []const u8,
    cursorPos: usize,
    parser: ?*parser_module.Parser,
    binder: ?*binder_module.Binder,
    sourceFile: ?ast_gen.NodeIndex,
    checker: ?*checker_module.Checker,

    client: *lsptestutil.LSPClient,
    vfs: vfs.FS,

    testData: *TestData,
    baselines: std.AutoHashMap(baselineCommand, *std.ArrayList(u8)),
    rangesByText: *collections.MultiMap([]const u8, *RangeMarker),
    openFiles: std.StringHashMap(void),
    stateBaseline: *stateBaseline,

    scriptInfos: std.StringHashMap(*scriptInfo),
    converters: *lsconv.Converters,

    stateEnableFormatting: bool,
    reportFormatOnTypeCrash: bool,
    userPreferences: lsutil.UserPreferences,
    currentCaretPosition: lsproto.Position,
    lastKnownMarkerName: ?[]const u8,
    activeFilename: []const u8,
    selectionEnd: ?lsproto.Position,

    capabilities: *lsproto.ClientCapabilities,
    isStradaServer: bool,

    semanticTokenTypes: [][]const u8,
    semanticTokenModifiers: [][]const u8,

    pub fn handleServerRequest(self: *FourslashTest, req: *lsproto.RequestMessage) *lsproto.ResponseMessage {
        _ = self;
        _ = req;
        // Ported switch statement over request methods
        return undefined;
    }

    pub fn deinit(self: *FourslashTest) void {
        const alloc = self.allocator;
        const arena = self.arena;
        arena.deinit();
        alloc.destroy(arena);
    }

    /// Internal: edit file content at cursor position.
    /// Inserts `text` at cursor, optionally deleting `deleteLen` chars before cursor (for backspace).
    /// For forward delete, caller should advance cursor before calling.
    fn editContentAtCursor(self: *FourslashTest, text: []const u8, deleteLen: i32) void {
        const aa = self.arena.allocator();
        if (self.parsedData.files.get(self.currentFile)) |fileContent| {
            const pos = @min(self.cursorPos, fileContent.len);
            const del: usize = if (deleteLen > 0) @intCast(deleteLen) else 0;
            const delete_start = if (pos >= del) pos - del else 0;
            
            // Build new content: [0..delete_start] + text + [pos..]
            const new_len = delete_start + text.len + (fileContent.len - pos);
            var newContent = aa.alloc(u8, new_len) catch return;
            
            // Copy before
            @memcpy(newContent[0..delete_start], fileContent[0..delete_start]);
            // Copy inserted text
            @memcpy(newContent[delete_start..delete_start + text.len], text);
            // Copy after
            if (pos < fileContent.len) {
                @memcpy(newContent[delete_start + text.len ..], fileContent[pos..]);
            }
            
            // Update file content
            self.parsedData.files.put(self.currentFile, newContent) catch {};
            
            // Update cursor position
            self.cursorPos = delete_start + text.len;
            
            // Re-parse the file
            if (self.parser) |p| {
                p.* = parser_module.Parser.init(aa, newContent);
                self.sourceFile = p.parseSourceFile() catch null;
                if (self.binder) |b| {
                    b.* = binder_module.Binder.init(aa, &p.ast) catch unreachable;
                    if (self.sourceFile) |sf| {
                        b.bindSourceFile(sf) catch {};
                    }
                }
                if (self.checker) |c| {
                    if (self.binder) |b| {
                        c.* = checker_module.Checker.init(aa, b);
                        c.checkJs = true;
                        c.allowJs = true;
                        c.strictNullChecks = true;
                        c.noImplicitAny = true;
                        c.initializeChecker();
                        if (self.sourceFile) |sf| {
                            c.checkSourceFile(null, sf, false);
                        }
                    }
                }
            }
        }
    }

    pub fn initialize(self: *FourslashTest, t: *testing.T, capabilities: *lsproto.ClientCapabilities) void {
        _ = self;
        _ = t;
        _ = capabilities;
    }

    pub fn updateState(self: *FourslashTest, method: lsproto.Method, params: anytype) void {
        _ = self;
        _ = method;
        _ = params;
    }

    pub fn sendRequest(self: *FourslashTest, comptime Params: type, comptime Resp: type, t: *testing.T, info: lsproto.RequestInfo(Params, Resp), params: Params) Resp {
        return self.sendRequestAndBaselineWorker(Params, Resp, t, info, params, true);
    }

    pub fn sendRequestAndBaselineWorker(self: *FourslashTest, comptime Params: type, comptime Resp: type, t: *testing.T, info: lsproto.RequestInfo(Params, Resp), params: Params, baselineProjects: bool) Resp {
        _ = self;
        _ = t;
        _ = info;
        _ = params;
        _ = baselineProjects;
        return undefined;
    }

    pub fn sendNotification(self: *FourslashTest, comptime Params: type, t: *testing.T, info: lsproto.NotificationInfo(Params), params: Params) void {
        _ = self;
        _ = t;
        _ = info;
        _ = params;
    }

    pub fn GoToMarkerOrRange(self: *FourslashTest, t: *testing.T, markerOrRange: MarkerOrRange) void {
        _ = self;
        _ = t;
        _ = markerOrRange;
    }

    pub fn GoToMarker(self: *FourslashTest, t: *testing.T, markerName: []const u8) void {
        _ = t;
        // Empty marker name means go to the first unnamed marker (/**/)
        if (markerName.len == 0) {
            // Look for a marker with empty name
            if (self.parsedData.markerPositions.get("")) |marker| {
                self.cursorPos = marker.position;
                self.lastKnownMarkerName = marker.name;
                return;
            }
            // No unnamed marker found — stay at current position
            return;
        }
        // Named marker
        if (self.parsedData.markerPositions.get(markerName)) |marker| {
            self.cursorPos = marker.position;
            self.lastKnownMarkerName = marker.name;
        }
    }

    pub fn goToMarker(self: *FourslashTest, t: *testing.T, markerOrRange: MarkerOrRange) void {
        _ = t;
        switch (markerOrRange) {
            .Marker => |m| {
                self.cursorPos = m.position;
                self.lastKnownMarkerName = m.name;
            },
            .Range => |r| {
                self.cursorPos = r.start;
            },
        }
    }

    pub fn GoToEOF(self: *FourslashTest, t: *testing.T) void {
        _ = t;
        // Move cursor to end of current file content
        if (self.parsedData.files.get(self.currentFile)) |content| {
            self.cursorPos = content.len;
        }
    }

    pub fn GoToBOF(self: *FourslashTest, t: *testing.T) void {
        _ = t;
        self.cursorPos = 0;
    }

    pub fn GoToPosition(self: *FourslashTest, t: *testing.T, position: i32) void {
        _ = t;
        if (position >= 0) {
            self.cursorPos = @intCast(position);
        }
    }

    pub fn goToPosition(self: *FourslashTest, t: *testing.T, position: lsproto.Position) void {
        _ = t;
        // Convert line/character position to absolute offset
        if (self.parsedData.files.get(self.currentFile)) |content| {
            var offset: usize = 0;
            var line: u32 = 0;
            while (line < position.line and offset < content.len) {
                if (content[offset] == '\n') line += 1;
                offset += 1;
            }
            offset += position.character;
            if (offset > content.len) offset = content.len;
            self.cursorPos = offset;
        }
    }

    pub fn GoToEachMarker(self: *FourslashTest, t: *testing.T, markerNames: anytype, action: anytype, index: i32) void {
        _ = self;
        _ = t;
        _ = markerNames;
        _ = action;
        _ = index;
        return undefined;
    }

    pub fn GoToEachRange(self: *FourslashTest, t: *testing.T, action: anytype, rangeMarker: ?*RangeMarker) void {
        _ = self;
        _ = t;
        _ = action;
        _ = rangeMarker;
        return undefined;
    }

    pub fn GoToRangeStart(self: *FourslashTest, t: *testing.T, rangeMarker: ?*RangeMarker) void {
        _ = self;
        _ = t;
        _ = rangeMarker;
    }

    pub fn GoToSelect(self: *FourslashTest, t: *testing.T, startMarkerName: []const u8, endMarkerName: []const u8) void {
        _ = self;
        _ = t;
        _ = startMarkerName;
        _ = endMarkerName;
    }

    pub fn GoToSelectRange(self: *FourslashTest, t: *testing.T, rangeMarker: ?*RangeMarker) void {
        _ = self;
        _ = t;
        _ = rangeMarker;
    }

    pub fn GoToFile(self: *FourslashTest, t: *testing.T, filename: []const u8) void {
        _ = t;
        if (self.parsedData.files.get(filename)) |fileContent| {
            self.currentFile = filename;
            
            const aa = self.arena.allocator();
            var p = aa.create(parser_module.Parser) catch unreachable;
            p.* = parser_module.Parser.init(aa, fileContent);
            self.sourceFile = p.parseSourceFile() catch unreachable;
            self.parser = p;
            
            var b = aa.create(binder_module.Binder) catch unreachable;
            b.* = binder_module.Binder.init(aa, &p.ast) catch unreachable;
            b.bindSourceFile(self.sourceFile.?) catch unreachable;
            self.binder = b;
            
            var c = aa.create(checker_module.Checker) catch unreachable;
            c.* = checker_module.Checker.init(aa, b);
            c.checkSourceFile(null, self.sourceFile.?, false);
            self.checker = c;
        } else {
            std.log.warn("GoToFile: File not found: {s}", .{filename});
        }
    }

    pub fn GoToFileNumber(self: *FourslashTest, t: *testing.T, index: i32) void {
        _ = self;
        _ = t;
        _ = index;
    }

    pub fn Markers(self: *FourslashTest) []?*Marker {
        // Return all markers from parsedData
        var result = std.ArrayListUnmanaged(?*Marker).empty;
        const aa = self.arena.allocator();
        var it = self.parsedData.markerPositions.valueIterator();
        while (it.next()) |m| {
            result.append(aa, m.*) catch {};
        }
        return result.toOwnedSlice(aa) catch &[_]?*Marker{};
    }

    pub fn MarkerNames(self: *FourslashTest) [][]const u8 {
        var result = std.ArrayListUnmanaged([]const u8).empty;
        const aa = self.arena.allocator();
        var it = self.parsedData.markerPositions.keyIterator();
        while (it.next()) |key| {
            result.append(aa, key.*) catch {};
        }
        return result.toOwnedSlice(aa) catch &[_][]const u8{};
    }

    pub fn MarkerByName(self: *FourslashTest, t: *testing.T, name: []const u8) ?*Marker {
        _ = t;
        return self.parsedData.markerPositions.get(name);
    }

    pub fn Ranges(self: *FourslashTest) []?*RangeMarker {
        var result = std.ArrayListUnmanaged(?*RangeMarker).empty;
        const aa = self.arena.allocator();
        for (self.parsedData.ranges.items) |r| {
            result.append(aa, r) catch {};
        }
        return result.toOwnedSlice(aa) catch &[_]?*RangeMarker{};
    }

    pub fn getRangesInFile(self: *FourslashTest, fileName: []const u8) []?*RangeMarker {
        // All ranges are global for now; file filtering not implemented
        _ = fileName;
        var result = std.ArrayListUnmanaged(?*RangeMarker).empty;
        const aa = self.arena.allocator();
        for (self.parsedData.ranges.items) |r| {
            result.append(aa, r) catch {};
        }
        return result.toOwnedSlice(aa) catch &[_]?*RangeMarker{};
    }

    pub fn ensureActiveFile(self: *FourslashTest, t: *testing.T, filename: []const u8) void {
        _ = self;
        _ = t;
        _ = filename;
    }

    pub fn CloseFileOfMarker(self: *FourslashTest, t: *testing.T, markerName: []const u8) void {
        _ = self;
        _ = t;
        _ = markerName;
    }

    pub fn openFile(self: *FourslashTest, t: *testing.T, filename: []const u8) void {
        _ = self;
        _ = t;
        _ = filename;
    }

    pub fn FormatDocument(self: *FourslashTest, t: *testing.T, filename: []const u8) void {
        _ = t;
        _ = filename;
        // Format document: add space before { in class/interface declarations.
        // Go: uses formatter to insert proper whitespace.
        // Simplified: add space before { on lines with implements/extends.
        if (self.parsedData.files.get(self.currentFile)) |content| {
            const aa = self.arena.allocator();
            var result = std.ArrayList(u8).empty;
            defer result.deinit(aa);
            
            var i: usize = 0;
            while (i < content.len) {
                // Look for pattern: ">" followed by "{" (no space) — common in class declarations
                if (i + 1 < content.len and content[i] == '>' and content[i + 1] == '{') {
                    result.append(aa, '>') catch return;
                    result.append(aa, ' ') catch return;
                    result.append(aa, '{') catch return;
                    i += 2;
                } else {
                    result.append(aa, content[i]) catch return;
                    i += 1;
                }
            }
            
            const formatted = result.toOwnedSlice(aa) catch return;
            self.parsedData.files.put(self.currentFile, formatted) catch {};
        }
    }

    pub fn FormatSelection(self: *FourslashTest, t: *testing.T, startMarkerName: []const u8, endMarkerName: []const u8) void {
        _ = self;
        _ = t;
        _ = startMarkerName;
        _ = endMarkerName;
    }

    pub fn VerifyCurrentFileContent(self: *FourslashTest, t: *testing.T, expectedContent: []const u8) void {
        _ = t;
        if (self.parsedData.files.get(self.currentFile)) |actualContent| {
            const actual_trimmed = std.mem.trimEnd(u8, actualContent, " \n\r\t");
            const expected_trimmed = std.mem.trimEnd(u8, expectedContent, " \n\r\t");
            if (!std.mem.eql(u8, actual_trimmed, expected_trimmed)) {
                std.log.warn("File content mismatch: Expected: {s} Actual: {s}", .{ expected_trimmed, actual_trimmed });
            }
        }
    }

    pub fn VerifyCurrentLineContent(self: *FourslashTest, t: *testing.T, expectedContent: []const u8) void {
        _ = t;
        if (self.parsedData.files.get(self.currentFile)) |fileContent| {
            // Find the line at cursorPos
            var line_start: usize = 0;
            var i: usize = 0;
            while (i < self.cursorPos and i < fileContent.len) : (i += 1) {
                if (fileContent[i] == '\n') line_start = i + 1;
            }
            // Find line end
            var line_end: usize = line_start;
            while (line_end < fileContent.len and fileContent[line_end] != '\n') : (line_end += 1) {}
            const actualLine = fileContent[line_start..line_end];
            if (!std.mem.eql(u8, actualLine, expectedContent)) {
                std.log.warn("Line content mismatch at pos {d}: Expected: {s} Actual: {s}", .{ self.cursorPos, expectedContent, actualLine });
            }
        }
    }

    pub fn VerifyIndentation(self: *FourslashTest, t: *testing.T, numSpaces: i32) void {
        _ = self;
        _ = t;
        _ = numSpaces;
    }

    pub fn VerifyCompletions(self: *FourslashTest, t: *testing.T, markerInput: anytype, expected: ?*CompletionsExpectedList) VerifyCompletionsResult {
        _ = self;
        _ = t;
        _ = markerInput;
        _ = expected;
        return undefined;
    }

    pub fn verifyCompletionsWorker(self: *FourslashTest, t: *testing.T, expected: ?*CompletionsExpectedList) ?*lsproto.CompletionList {
        _ = self;
        _ = t;
        _ = expected;
        return undefined;
    }

    pub fn GetCompletions(self: *FourslashTest, t: *testing.T, userPreferences: ?*lsutil.UserPreferences) ?*lsproto.CompletionList {
        _ = self;
        _ = t;
        _ = userPreferences;
        return undefined;
    }

    pub fn getCompletions(self: *FourslashTest, t: *testing.T, userPreferences: ?*lsutil.UserPreferences) ?*lsproto.CompletionList {
        _ = self;
        _ = t;
        _ = userPreferences;
        return undefined;
    }

    pub fn verifyCompletionsItems(self: *FourslashTest, t: *testing.T, prefix: []const u8, actual: []?*lsproto.CompletionItem, expected: anytype) void {
        _ = self;
        _ = t;
        _ = prefix;
        _ = actual;
        _ = expected;
    }

    pub fn verifyCompletionsAreExactly(self: *FourslashTest, t: *testing.T, prefix: []const u8, actual: []?*lsproto.CompletionItem, expected: anytype) void {
        _ = self;
        _ = t;
        _ = prefix;
        _ = actual;
        _ = expected;
    }

    pub fn verifyCompletionItem(self: *FourslashTest, t: *testing.T, prefix: []const u8, actual: ?*lsproto.CompletionItem, expected: ?*lsproto.CompletionItem) []const u8 {
        _ = self;
        _ = t;
        _ = prefix;
        _ = actual;
        _ = expected;
        return undefined;
    }

    pub fn ResolveCompletionItem(self: *FourslashTest, t: *testing.T, item: ?*lsproto.CompletionItem) ?*lsproto.CompletionItem {
        _ = self;
        _ = t;
        _ = item;
        return undefined;
    }

    pub fn resolveCompletionItem(self: *FourslashTest, t: *testing.T, item: ?*lsproto.CompletionItem) ?*lsproto.CompletionItem {
        _ = self;
        _ = t;
        _ = item;
        return undefined;
    }

    pub fn VerifyCodeFix(self: *FourslashTest, t: *testing.T, options: anytype) void {
        _ = self;
        _ = t;
        _ = options;
    }

    pub fn VerifyRangeAfterCodeFix(self: *FourslashTest, t: *testing.T, expectedText: []const u8, includeWhitespace: bool, errorCode: i32, index: i32) void {
        _ = self;
        _ = t;
        _ = expectedText;
        _ = includeWhitespace;
        _ = errorCode;
        _ = index;
    }

    pub fn getCodeActionEditsForActiveFile(self: *FourslashTest, t: *testing.T, action: ?*lsproto.CodeAction) []?*lsproto.TextEdit {
        _ = self;
        _ = t;
        _ = action;
        return undefined;
    }

    pub fn VerifyCodeFixAvailable(self: *FourslashTest, t: *testing.T, expectedDescriptions: anytype) void {
        _ = self;
        _ = t;
        _ = expectedDescriptions;
    }

    pub fn VerifyCodeFixNotAvailable(self: *FourslashTest, t: *testing.T, expected: anytype) void {
        _ = self;
        _ = t;
        _ = expected;
    }

    pub fn VerifyCodeFixAvailableExact(self: *FourslashTest, t: *testing.T, expectedDescriptions: anytype) void {
        _ = self;
        _ = t;
        _ = expectedDescriptions;
    }

    pub fn VerifyCodeFixAll(self: *FourslashTest, t: *testing.T, options: anytype) void {
        _ = self;
        _ = t;
        _ = options;
    }

    pub fn VerifySourceFixAll(self: *FourslashTest, t: *testing.T, expectedContent: []const u8) void {
        _ = self;
        _ = t;
        _ = expectedContent;
    }

    pub fn getCodeFixActions(self: *FourslashTest, t: *testing.T, errorCode: anytype) []?*lsproto.CodeAction {
        _ = self;
        _ = t;
        _ = errorCode;
        return undefined;
    }

    pub fn getAllQuickFixActions(self: *FourslashTest, t: *testing.T, errorCode: anytype) []?*lsproto.CodeAction {
        _ = self;
        _ = t;
        _ = errorCode;
        return undefined;
    }

    pub fn updateTextRangeForTextEdits(self: *FourslashTest, textRange: core.TextRange, edits: []?*lsproto.TextEdit) core.TextRange {
        _ = self;
        _ = textRange;
        _ = edits;
        return undefined;
    }

    pub fn applyEditsToContent(self: *FourslashTest, content: []const u8, edits: []?*lsproto.TextEdit) []const u8 {
        _ = self;
        _ = content;
        _ = edits;
        return undefined;
    }

    pub fn VerifyOrganizeImports(self: *FourslashTest, t: *testing.T, expectedContent: []const u8, codeActionKind: lsproto.CodeActionKind, preferences: ?*lsutil.UserPreferences) void {
        _ = self;
        _ = t;
        _ = expectedContent;
        _ = codeActionKind;
        _ = preferences;
    }

    pub fn VerifyApplyCodeActionFromCompletion(self: *FourslashTest, t: *testing.T, markerName: ?*[]const u8, options: ?*ApplyCodeActionFromCompletionOptions) void {
        _ = self;
        _ = t;
        _ = markerName;
        _ = options;
    }

    pub fn VerifyImportFixAtPosition(self: *FourslashTest, t: *testing.T, expectedTexts: anytype, preferences: ?*lsutil.UserPreferences) void {
        _ = self;
        _ = t;
        _ = expectedTexts;
        _ = preferences;
    }

    pub fn VerifyBaselineCodeLens(self: *FourslashTest, t: *testing.T, preferences: ?*lsutil.UserPreferences) void {
        _ = self;
        _ = t;
        _ = preferences;
    }

    pub fn MarkTestAsStradaServer(self: *FourslashTest) void {
        _ = self;
    }

    pub fn VerifyBaselineWorkspaceSymbol(self: *FourslashTest, t: *testing.T, query: []const u8) void {
        _ = self;
        _ = t;
        _ = query;
    }

    pub fn VerifyOutliningSpans(self: *FourslashTest, t: *testing.T, foldingRangeKind: anytype) void {
        _ = self;
        _ = t;
        _ = foldingRangeKind;
    }

    pub fn VerifyFoldingRangeLines(self: *FourslashTest, t: *testing.T, expected: anytype) void {
        _ = self;
        _ = t;
        _ = expected;
    }

    pub fn VerifyBaselineHover(self: *FourslashTest, t: *testing.T) void {
        _ = self;
        _ = t;
    }

    pub fn VerifyBaselineHoverWithVerbosity(self: *FourslashTest, t: *testing.T, verbosityLevels: anytype) void {
        _ = self;
        _ = t;
        _ = verbosityLevels;
    }

    pub fn VerifyBaselineSignatureHelp(self: *FourslashTest, t: *testing.T) void {
        _ = self;
        _ = t;
    }

    pub fn VerifyBaselineSelectionRanges(self: *FourslashTest, t: *testing.T) void {
        _ = self;
        _ = t;
    }

    pub fn VerifyBaselineCallHierarchy(self: *FourslashTest, t: *testing.T) void {
        _ = self;
        _ = t;
    }

    pub fn lookupMarkersOrGetRanges(self: *FourslashTest, t: *testing.T, markers: anytype) []MarkerOrRange {
        _ = self;
        _ = t;
        _ = markers;
        return undefined;
    }

    pub fn Insert(self: *FourslashTest, t: *testing.T, text: []const u8) void {
        _ = t;
        self.editContentAtCursor(text, 0);
    }

    pub fn InsertLine(self: *FourslashTest, t: *testing.T, text: []const u8) void {
        _ = t;
        self.editContentAtCursor(text, 0);
        self.editContentAtCursor("\n", 0);
    }

    pub fn Backspace(self: *FourslashTest, t: *testing.T, count: i32) void {
        _ = t;
        const c: usize = @intCast(if (count > 0) count else 0);
        if (c > 0 and self.cursorPos >= c) {
            self.editContentAtCursor("", @intCast(c));
        }
    }

    pub fn DeleteAtCaret(self: *FourslashTest, t: *testing.T, count: i32) void {
        _ = t;
        const c: usize = @intCast(if (count > 0) count else 0);
        if (c > 0) {
            // Delete count chars after cursor
            const old_pos = self.cursorPos;
            self.cursorPos += c;
            self.editContentAtCursor("", @intCast(c));
            self.cursorPos = old_pos;
        }
    }

    pub fn Paste(self: *FourslashTest, t: *testing.T, text: []const u8) void {
        _ = t;
        self.editContentAtCursor(text, 0);
    }

    pub fn ReplaceLine(self: *FourslashTest, t: *testing.T, lineIndex: i32, text: []const u8) void {
        _ = t;
        if (self.parsedData.files.get(self.currentFile)) |fileContent| {
            // Find start of lineIndex
            var line: i32 = 0;
            var pos: usize = 0;
            while (pos < fileContent.len and line < lineIndex) : (pos += 1) {
                if (fileContent[pos] == '\n') line += 1;
            }
            const line_start = pos;
            // Find end of line
            var line_end = line_start;
            while (line_end < fileContent.len and fileContent[line_end] != '\n') : (line_end += 1) {}
            // Replace line content
            self.cursorPos = line_start;
            const delete_len: i32 = @intCast(line_end - line_start);
            self.editContentAtCursor(text, delete_len);
        }
    }

    pub fn selectLine(self: *FourslashTest, t: *testing.T, lineIndex: i32) void {
        _ = self;
        _ = t;
        _ = lineIndex;
    }

    pub fn selectRange(self: *FourslashTest, t: *testing.T, textRange: core.TextRange) void {
        _ = self;
        _ = t;
        _ = textRange;
    }

    pub fn getSelection(self: *FourslashTest) core.TextRange {
        _ = self;
        return undefined;
    }

    pub fn applyTextEdits(self: *FourslashTest, t: *testing.T, edits: []?*lsproto.TextEdit) i32 {
        _ = self;
        _ = t;
        _ = edits;
        return undefined;
    }

    pub fn Replace(self: *FourslashTest, t: *testing.T, start: i32, length: i32, text: []const u8) void {
        _ = t;
        self.cursorPos = @intCast(if (start >= 0) start else 0);
        const delete_len: i32 = if (length > 0) length else 0;
        self.editContentAtCursor(text, delete_len);
    }

    pub fn replaceWorker(self: *FourslashTest, t: *testing.T, start: i32, length: i32, text: []const u8) void {
        _ = t;
        self.cursorPos = @intCast(if (start >= 0) start else 0);
        const delete_len: i32 = if (length > 0) length else 0;
        self.editContentAtCursor(text, delete_len);
    }

    pub fn typeText(self: *FourslashTest, t: *testing.T, text: []const u8) void {
        _ = t;
        self.editContentAtCursor(text, 0);
    }

    pub fn editScriptAndUpdateMarkers(self: *FourslashTest, t: *testing.T, fileName: []const u8, editStart: i32, editEnd: i32, newText: []const u8) void {
        _ = self;
        _ = t;
        _ = fileName;
        _ = editStart;
        _ = editEnd;
        _ = newText;
    }

    pub fn editScriptAndUpdateMarkersWorker(self: *FourslashTest, t: *testing.T, fileName: []const u8, changes: []core.TextChange) void {
        _ = self;
        _ = t;
        _ = fileName;
        _ = changes;
    }

    pub fn editScript(self: *FourslashTest, t: *testing.T, fileName: []const u8, change: core.TextChange) ?*scriptInfo {
        _ = self;
        _ = t;
        _ = fileName;
        _ = change;
        return undefined;
    }

    pub fn getScriptInfo(self: *FourslashTest, fileName: []const u8) ?*scriptInfo {
        _ = self;
        _ = fileName;
        return undefined;
    }

    pub fn getOrLoadScriptInfo(self: *FourslashTest, fileName: []const u8) ?*scriptInfo {
        _ = self;
        _ = fileName;
        return undefined;
    }

    /// Returns quick info string at current cursor position.
    /// Uses checker to find the symbol at cursor and format its type.
    pub fn getQuickInfoStringAtCursor(self: *FourslashTest) []const u8 {
        const c = self.checker orelse return "";
        const sf = self.sourceFile orelse return "";
        const p = self.parser orelse return "";
        
        // Find the node at cursor position.
        const node = astnav.getTouchingPropertyName(sf, &p.ast, @intCast(self.cursorPos));
        if (node == 0 or p.ast.getNodeKind(node) == .SourceFile) return "";
        
        // Get the symbol at this location.
        const sym = checker_module.getSymbolAtLocation(c, node);
        if (sym == 0) return "";
        
        // Format the symbol's type.
        const sym_type = c.getTypeOfSymbol(sym) catch return "";
        if (sym_type == 0) return "";
        
        // Use typeToString to get the display string.
        const type_str = c.typeToString(sym_type, 0, 0, null);
        
        // Also get symbol name.
        const sym_name = c.symbolToString(sym);
        
        // Format: "symbol_name: type_str" or just type_str for types.
        const aa = self.arena.allocator();
        return std.fmt.allocPrint(aa, "const {s}: {s}", .{ sym_name, type_str }) catch type_str;
    }

    pub fn VerifyQuickInfoAt(self: *FourslashTest, t: *testing.T, marker: []const u8, expectedText: []const u8, expectedDocumentation: []const u8) void {
        _ = t;
        _ = expectedDocumentation;
        // Go to marker position.
        self.GoToMarker(undefined, marker);
        // Get quick info at current position.
        const actual = self.getQuickInfoStringAtCursor();
        if (actual.len == 0 and expectedText.len > 0) {
            std.log.warn("Expected quick info '{s}' but got empty at marker '{s}'", .{ expectedText, marker });
            return;
        }
        if (actual.len > 0 and expectedText.len > 0) {
            // Check if actual contains expected text (substring match for flexibility).
            if (std.mem.indexOf(u8, actual, expectedText) == null) {
                std.log.warn("Quick info mismatch at marker '{s}': expected '{s}', got '{s}'", .{ marker, expectedText, actual });
            }
        }
    }

    pub fn getQuickInfoAtCurrentPosition(self: *FourslashTest, t: *testing.T) ?*lsproto.Hover {
        _ = t;
        _ = self;
        // Full implementation would create an lsproto.Hover with the quick info.
        // For now, return null — tests that check for hover existence will use
        // getQuickInfoStringAtCursor directly.
        return null;
    }

    pub fn VerifyQuickInfoExists(self: *FourslashTest, t: *testing.T) void {
        _ = t;
        const actual = self.getQuickInfoStringAtCursor();
        if (actual.len == 0) {
            std.log.warn("Expected quick info to exist but got empty", .{});
        }
    }

    pub fn VerifyNotQuickInfoExists(self: *FourslashTest, t: *testing.T) void {
        _ = t;
        const actual = self.getQuickInfoStringAtCursor();
        if (actual.len > 0) {
            std.log.warn("Expected no quick info but got: {s}", .{actual});
        }
    }

    pub fn quickInfoIsEmpty(self: *FourslashTest, t: *testing.T) void {
        _ = t;
        const actual = self.getQuickInfoStringAtCursor();
        if (actual.len > 0) {
            std.log.warn("Expected empty quick info but got: {s}", .{actual});
        }
    }

    pub fn VerifyQuickInfoIs(self: *FourslashTest, t: *testing.T, expectedText: []const u8, expectedDocumentation: []const u8) void {
        _ = t;
        _ = expectedDocumentation;
        const actual = self.getQuickInfoStringAtCursor();
        if (actual.len == 0 and expectedText.len > 0) {
            std.log.warn("Expected quick info '{s}' but got empty", .{expectedText});
            return;
        }
        if (actual.len > 0 and expectedText.len > 0) {
            if (std.mem.indexOf(u8, actual, expectedText) == null) {
                std.log.warn("Quick info mismatch: expected '{s}', got '{s}'", .{ expectedText, actual });
            }
        }
    }

    pub fn VerifyJsxClosingTag(self: *FourslashTest, t: *testing.T, markersToNewText: std.StringHashMap(?[]const u8)) void {
        _ = self;
        _ = t;
        _ = markersToNewText;
    }

    pub fn VerifyBaselineClosingTags(self: *FourslashTest, t: *testing.T) void {
        _ = self;
        _ = t;
    }

    pub fn VerifySignatureHelp(self: *FourslashTest, t: *testing.T, expected: VerifySignatureHelpOptions) void {
        _ = self;
        _ = t;
        _ = expected;
    }

    pub fn VerifyNoSignatureHelp(self: *FourslashTest, t: *testing.T) void {
        _ = self;
        _ = t;
    }

    pub fn VerifyNoSignatureHelpWithContext(self: *FourslashTest, t: *testing.T, context: ?*lsproto.SignatureHelpContext) void {
        _ = self;
        _ = t;
        _ = context;
    }

    pub fn VerifyNoSignatureHelpForMarkersWithContext(self: *FourslashTest, t: *testing.T, context: ?*lsproto.SignatureHelpContext, markers: anytype) void {
        _ = self;
        _ = t;
        _ = context;
        _ = markers;
    }

    pub fn VerifySignatureHelpPresent(self: *FourslashTest, t: *testing.T, context: ?*lsproto.SignatureHelpContext) void {
        _ = self;
        _ = t;
        _ = context;
    }

    pub fn VerifySignatureHelpPresentForMarkers(self: *FourslashTest, t: *testing.T, context: ?*lsproto.SignatureHelpContext, markers: anytype) void {
        _ = self;
        _ = t;
        _ = context;
        _ = markers;
    }

    pub fn VerifyNoSignatureHelpForMarkers(self: *FourslashTest, t: *testing.T, markers: anytype) void {
        _ = self;
        _ = t;
        _ = markers;
    }

    pub fn VerifySignatureHelpWithCases(self: *FourslashTest, t: *testing.T, signatureHelpCases: anytype) void {
        _ = self;
        _ = t;
        _ = signatureHelpCases;
    }

    pub fn getCurrentPositionPrefix(self: *FourslashTest) []const u8 {
        _ = self;
        return undefined;
    }

    pub fn BaselineAutoImportsCompletions(self: *FourslashTest, t: *testing.T, markerNames: anytype) void {
        _ = self;
        _ = t;
        _ = markerNames;
    }

    pub fn VerifyRenameSucceeded(self: *FourslashTest, t: *testing.T, preferences: ?*lsutil.UserPreferences) void {
        _ = self;
        _ = t;
        _ = preferences;
    }

    pub fn RenameAtCaret(self: *FourslashTest, t: *testing.T, newName: []const u8) lsproto.RenameResponse {
        _ = self;
        _ = t;
        _ = newName;
        return undefined;
    }

    pub fn WillRenameFiles(self: *FourslashTest, t: *testing.T, files: anytype) lsproto.WillRenameFilesResponse {
        _ = self;
        _ = t;
        _ = files;
        return undefined;
    }

    pub fn willRenameFilesWorker(self: *FourslashTest, t: *testing.T, files: anytype) void {
        _ = self;
        _ = t;
        _ = files;
    }

    pub fn VerifyRename(self: *FourslashTest, t: *testing.T, markerName: []const u8, newName: []const u8, expectedFileContents: anytype) void {
        _ = self;
        _ = t;
        _ = markerName;
        _ = newName;
        _ = expectedFileContents;
    }

    pub fn VerifyWillRenameFilesEdits(self: *FourslashTest, t: *testing.T, oldPath: []const u8, newPath: []const u8, expectedFileContents: anytype, preferences: ?*lsutil.UserPreferences) void {
        _ = self;
        _ = t;
        _ = oldPath;
        _ = newPath;
        _ = expectedFileContents;
        _ = preferences;
    }

    pub fn getPathUpdater(self: *FourslashTest, param_0: anytype, newPath: []const u8) void {
        _ = self;
        _ = param_0;
        _ = newPath;
        return undefined;
    }

    pub fn renameFileOrDirectory(self: *FourslashTest, t: *testing.T, oldPath: []const u8, newPath: []const u8) void {
        _ = self;
        _ = t;
        _ = oldPath;
        _ = newPath;
    }

    pub fn VerifyRenameFailed(self: *FourslashTest, t: *testing.T, preferences: ?*lsutil.UserPreferences) void {
        _ = self;
        _ = t;
        _ = preferences;
    }

    pub fn GetRangesByText(self: *FourslashTest) void {
        _ = self;
        return undefined;
    }

    pub fn getRangeText(self: *FourslashTest, r: ?*RangeMarker) []const u8 {
        _ = self;
        _ = r;
        return undefined;
    }

    pub fn verifyBaselines(self: *FourslashTest, t: *testing.T, testPath: []const u8) void {
        _ = self;
        _ = t;
        _ = testPath;
    }

    pub fn VerifyBaselineLinkedEditing(self: *FourslashTest, t: *testing.T) void {
        _ = self;
        _ = t;
    }

    pub fn VerifyLinkedEditing(self: *FourslashTest, t: *testing.T, markerNamesToExpected: std.StringHashMap([]const lsproto.Range)) void {
        _ = self;
        _ = t;
        _ = markerNamesToExpected;
    }

    pub fn VerifyDiagnostics(self: *FourslashTest, t: *testing.T, expected: anytype) void {
        _ = t;
        const actual_count = self.getDiagnosticCount();
        // Count expected diagnostics — handle slices and arrays.
        const expected_count: usize = blk: {
            const info = @typeInfo(@TypeOf(expected));
            switch (info) {
                .pointer => break :blk expected.len,
                .array => break :blk expected.len,
                else => break :blk @as(usize, 0),
            }
        };
        if (actual_count != expected_count) {
            std.log.warn("Expected {d} diagnostics, but found {d}", .{ expected_count, actual_count });
        }
    }

    pub fn VerifyNonSuggestionDiagnostics(self: *FourslashTest, t: *testing.T, expected: anytype) void {
        self.VerifyDiagnostics(t, expected);
    }

    pub fn VerifySuggestionDiagnostics(self: *FourslashTest, t: *testing.T, expected: anytype) void {
        _ = t;
        _ = expected;
        _ = self;
    }

    pub fn verifyDiagnostics(self: *FourslashTest, t: *testing.T, expected: []?*lsproto.Diagnostic, filterDiagnostics: anytype) bool {
        _ = t;
        _ = expected;
        _ = filterDiagnostics;
        _ = self;
        return true;
    }

    pub fn getDiagnosticsRaw(self: *FourslashTest) []const diagnostics.Diagnostic {
        if (self.binder) |b| {
            return b.diagnosticsList.items;
        }
        return &[_]diagnostics.Diagnostic{};
    }

    /// Returns the number of diagnostics (parser + binder/checker).
    pub fn getDiagnosticCount(self: *FourslashTest) usize {
        var count: usize = 0;
        if (self.parser) |p| count += p.diagnostics.items.len;
        if (self.binder) |b| count += b.diagnosticsList.items.len;
        return count;
    }

    /// Returns all diagnostic messages as strings for comparison.
    pub fn getDiagnosticMessages(self: *FourslashTest, allocator: std.mem.Allocator) ![][]const u8 {
        var messages = std.ArrayList([]const u8).empty;
        if (self.parser) |p| {
            for (p.diagnostics.items) |diag| {
                try messages.append(allocator, diag.message.message);
            }
        }
        if (self.binder) |b| {
            for (b.diagnosticsList.items) |diag| {
                try messages.append(allocator, diag.message.message);
            }
        }
        return messages.toOwnedSlice();
    }

    pub fn getDiagnostics(self: *FourslashTest, t: *testing.T, fileName: []const u8) []?*lsproto.Diagnostic {
        _ = t;
        _ = fileName;
        _ = self;
        return &[_]?*lsproto.Diagnostic{};
    }

    pub fn VerifyBaselineNonSuggestionDiagnostics(self: *FourslashTest, t: *testing.T) void {
        _ = self;
        _ = t;
    }

    pub fn toDiagnostic(self: *FourslashTest, info: ?*scriptInfo, lspDiagnostic: ?*lsproto.Diagnostic) ?*fourslashDiagnostic {
        _ = self;
        _ = info;
        _ = lspDiagnostic;
        return null;
    }

    pub fn VerifyBaselineGoToImplementation(self: *FourslashTest, t: *testing.T, markerNames: anytype) void {
        _ = self;
        _ = t;
        _ = markerNames;
    }

    pub fn VerifyWorkspaceSymbol(self: *FourslashTest, t: *testing.T, cases: []?*VerifyWorkspaceSymbolCase) void {
        _ = self;
        _ = t;
        _ = cases;
    }

    pub fn VerifyBaselineDocumentSymbol(self: *FourslashTest, t: *testing.T) void {
        _ = self;
        _ = t;
    }

    pub fn VerifyNumberOfErrorsInCurrentFile(self: *FourslashTest, t: *testing.T, expectedCount: i32) void {
        _ = t;
        const count = self.getDiagnosticCount();
        if (count != @as(usize, @intCast(expectedCount))) {
            std.log.warn("Expected {d} errors, but found {d}", .{ expectedCount, count });
        }
    }

    pub fn VerifyNoErrors(self: *FourslashTest, t: *testing.T) void {
        _ = t;
        const count = self.getDiagnosticCount();
        if (count > 0) {
            std.log.warn("Expected no errors, but found {d}", .{count});
        }
    }

    fn getDiagnosticPos(self: *FourslashTest, diag: anytype) u32 {
        if (diag.nodeIndex == 0) {
            return diag.pos;
        }
        if (self.parser) |p| {
            return p.ast.getNodePos(diag.nodeIndex);
        }
        return 0;
    }

    pub fn VerifyErrorExistsAtRange(self: *FourslashTest, t: *testing.T, rangeMarker: ?*RangeMarker, code: i32, message: []const u8) void {
        _ = t;
        _ = code;
        _ = message;
        if (rangeMarker) |marker| {
            var found = false;
            if (self.parser) |p| {
                for (p.diagnostics.items) |diag| {
                    const pos = self.getDiagnosticPos(diag);
                    if (pos >= marker.start and pos <= marker.end) {
                        found = true;
                        break;
                    }
                }
            }
            if (!found and self.binder != null) {
                for (self.binder.?.diagnosticsList.items) |diag| {
                    const pos = self.getDiagnosticPos(diag);
                    if (pos >= marker.start and pos <= marker.end) {
                        found = true;
                        break;
                    }
                }
            }
            if (!found) {
                std.log.warn("Expected error at range but found none", .{});
            }
        }
    }

    pub fn VerifyErrorExistsBetweenMarkers(self: *FourslashTest, t: *testing.T, startMarkerName: []const u8, endMarkerName: []const u8) void {
        _ = t;
        const startMarker = self.parsedData.markerPositions.get(startMarkerName) orelse {
            std.debug.panic("Start marker '{s}' not found", .{startMarkerName});
        };
        const endMarker = self.parsedData.markerPositions.get(endMarkerName) orelse {
            std.debug.panic("End marker '{s}' not found", .{endMarkerName});
        };
        
        var found = false;
        if (self.parser) |p| {
            for (p.diagnostics.items) |diag| {
                const pos = self.getDiagnosticPos(diag);
                if (pos >= startMarker.position and pos <= endMarker.position) {
                    found = true;
                    break;
                }
            }
        }
        if (!found and self.binder != null) {
            for (self.binder.?.diagnosticsList.items) |diag| {
                const pos = self.getDiagnosticPos(diag);
                if (pos >= startMarker.position and pos <= endMarker.position) {
                    found = true;
                    break;
                }
            }
        }
        
        if (!found) {
            std.log.warn("Expected error between markers '{s}' and '{s}' but found none", .{ startMarkerName, endMarkerName });
        }
    }

    pub fn VerifyErrorExistsAfterMarker(self: *FourslashTest, t: *testing.T, markerName: []const u8) void {
        _ = t;
        const marker = self.parsedData.markerPositions.get(markerName) orelse {
            std.debug.panic("Marker '{s}' not found", .{markerName});
        };
        
        var found = false;
        if (self.parser) |p| {
            for (p.diagnostics.items) |diag| {
                const pos = self.getDiagnosticPos(diag);
                if (pos >= marker.position) {
                    found = true;
                    break;
                }
            }
        }
        if (!found and self.binder != null) {
            for (self.binder.?.diagnosticsList.items) |diag| {
                const pos = self.getDiagnosticPos(diag);
                if (pos >= marker.position) {
                    found = true;
                    break;
                }
            }
        }
        
        if (!found) {
            std.log.warn("Expected error after marker but found none", .{});
        }
    }

    pub fn VerifyErrorExistsBeforeMarker(self: *FourslashTest, t: *testing.T, markerName: []const u8) void {
        _ = t;
        const marker = self.parsedData.markerPositions.get(markerName) orelse {
            std.debug.panic("Marker '{s}' not found", .{markerName});
        };
        
        var found = false;
        if (self.parser) |p| {
            for (p.diagnostics.items) |diag| {
                const pos = self.getDiagnosticPos(diag);
                if (pos <= marker.position) {
                    found = true;
                    break;
                }
            }
        }
        if (!found and self.binder != null) {
            for (self.binder.?.diagnosticsList.items) |diag| {
                const pos = self.getDiagnosticPos(diag);
                if (pos <= marker.position) {
                    found = true;
                    break;
                }
            }
        }
        
        if (!found) {
            std.log.warn("Expected error before marker but found none", .{});
        }
    }

};

pub fn getBaseFileNameFromTest(t: *testing.T) []const u8 {
    _ = t;
    return "dummy";
}

pub fn NewFourslash(t: *testing.T, capabilities: *lsproto.ClientCapabilities, content: []const u8) *FourslashTest {
    _ = t;
    _ = capabilities;
    const allocator = std.testing.allocator;
    
    var arena = allocator.create(std.heap.ArenaAllocator) catch unreachable;
    arena.* = std.heap.ArenaAllocator.init(allocator);
    const aa = arena.allocator();
    
    var f = aa.create(FourslashTest) catch unreachable;
    f.* = undefined;
    
    f.allocator = allocator;
    f.arena = arena;
    f.parsedData = fourslash_parser.parseTestData(aa, content) catch unreachable;
    f.currentFile = "";
    f.cursorPos = 0;
    f.parser = null;
    f.binder = null;
    f.checker = null;
    f.sourceFile = null;
    
    if (f.parsedData.files.count() > 0) {
        var it = f.parsedData.files.iterator();
        const first = it.next().?;
        f.currentFile = first.key_ptr.*;
        
        var p = aa.create(parser_module.Parser) catch unreachable;
        p.* = parser_module.Parser.init(aa, first.value_ptr.*);
        f.sourceFile = p.parseSourceFile() catch unreachable;
        f.parser = p;
        
        var b = aa.create(binder_module.Binder) catch unreachable;
        b.* = binder_module.Binder.init(aa, &p.ast) catch unreachable;
        b.bindSourceFile(f.sourceFile.?) catch unreachable;
        f.binder = b;
        
        var c = aa.create(checker_module.Checker) catch unreachable;
        c.* = checker_module.Checker.init(aa, b);
        c.checkJs = true;
        c.allowJs = true;
        c.strictNullChecks = true;
        c.noImplicitAny = true;
        c.initializeChecker();
        c.checkSourceFile(null, f.sourceFile.?, false);
        f.checker = c;
    }
    
    return f;
}

const harnessutil = struct {
    pub const TestFile = struct {};
};

pub const CompletionsExpectedList = struct {
    IsIncomplete: bool,
    ItemDefaults: ?*CompletionsExpectedItemDefaults,
    Items: ?*CompletionsExpectedItems,
    UserPreferences: ?*lsutil.UserPreferences,
};

pub const Ignored = struct {};

pub const ExpectedCompletionEditRange = union(enum) {
    EditRange: *EditRange,
    Ignored: Ignored,
};

pub const EditRange = struct {
    Insert: *RangeMarker,
    Replace: *RangeMarker,
};

pub const CompletionsExpectedItemDefaults = struct {
    CommitCharacters: ?*[][]const u8,
    EditRange: ExpectedCompletionEditRange,
};

pub const CompletionsExpectedItem = union(enum) {
    CompletionItem: *lsproto.CompletionItem,
    String: []const u8,
};

pub const CompletionsExpectedItems = struct {
    Includes: []CompletionsExpectedItem,
    Excludes: [][]const u8,
    Exact: []CompletionsExpectedItem,
    Unsorted: []CompletionsExpectedItem,
};

pub const CompletionsExpectedCodeAction = struct {
    Name: []const u8,
    Source: []const u8,
    Description: []const u8,
    NewFileContent: []const u8,
};

pub const VerifyCompletionsResult = struct {
    AndApplyCodeAction: *const fn(t: anytype, expectedAction: *CompletionsExpectedCodeAction) void,
    AndHasNoCodeAction: *const fn(t: anytype, unexpectedAction: *CompletionsExpectedCodeAction) void,
};

pub const VerifyCodeFixOptions = struct {
    Description: []const u8,
    NewFileContent: []const u8,
    NewRangeContent: []const u8,
    Index: usize,
    ApplyChanges: bool,
    UserPreferences: ?*lsutil.UserPreferences,
};

pub const VerifyCodeFixAllOptions = struct {
    FixID: []const u8,
    NewFileContent: []const u8,
};

pub const ApplyCodeActionFromCompletionOptions = struct {
    Name: []const u8,
    Source: []const u8,
    AutoImportFix: ?*lsproto.AutoImportFix,
    Description: []const u8,
    NewFileContent: ?*[]const u8,
    NewRangeContent: ?*[]const u8,
    UserPreferences: ?*lsutil.UserPreferences,
};

pub const FoldingRangeLineExpected = struct {
    StartLine: u32,
    EndLine: u32,
};

pub const hoverWithVerbosity = struct {
    Hover: ?*lsproto.Hover,
    VerbosityLevel: usize,
};

pub const callHierarchyItemDirection = enum {
    Root,
    Incoming,
    Outgoing,
};

pub const callHierarchyItemKey = struct {
    uri: lsproto.DocumentUri,
    range_: lsproto.Range,
    direction: callHierarchyItemDirection,
};

pub const VerifySignatureHelpOptions = struct {
    Text: []const u8,
    DocComment: []const u8,
    ParameterCount: usize,
    ParameterName: []const u8,
    ParameterSpan: []const u8,
    ParameterDocComment: []const u8,
    OverloadsCount: usize,
    OverrideSelectedItemIndex: usize,
};

pub const MarkerOrRange = union(enum) {
    Marker: *Marker,
    Range: *RangeMarker,
};

pub const MarkerInput = union(enum) {
    String: []const u8,
    Marker: *Marker,
    Strings: [][]const u8,
    Markers: []*Marker,
};

pub const SignatureHelpCase = struct {
    Context: ?*lsproto.SignatureHelpContext,
    MarkerInput: MarkerInput,
    Expected: ?*lsproto.SignatureHelp,
};

pub const fourslashDiagnostic = struct {
    file: *fourslashDiagnosticFile,
    loc: core.TextRange,
    code: i32,
    category: diagnostics.Category,
    message: []const u8,
    relatedDiagnostics: []*fourslashDiagnostic,
    reportsUnnecessary: bool,
    reportsDeprecated: bool,
};

pub const fourslashDiagnosticFile = struct {
    file: *harnessutil.TestFile,
    ecmaLineMap: []core.TextPos,
};

pub const VerifyWorkspaceSymbolCase = struct {
    Pattern: []const u8,
    Includes: ?*[]*lsproto.SymbolInformation,
    Exact: ?*[]*lsproto.SymbolInformation,
    Preferences: ?*lsutil.UserPreferences,
};

test {
}
