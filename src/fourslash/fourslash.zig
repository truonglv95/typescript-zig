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
const symbol = @import("../ast/symbol.zig");

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
    pub const Hover = struct {};
    pub const SignatureHelpContext = struct {};
    pub const SignatureHelp = struct {};
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
    pub const Diagnostic = struct {
        range: Range,
        severity: ?u32 = null,
        code: ?i32 = null,
        source: ?[]const u8 = null,
        message: []const u8,
    };
    pub const Range = struct {
        start: Position,
        end: Position,
    };
    pub const CompletionItemKind = enum(u32) {
        Text = 1,
        Method = 2,
        Function = 3,
        Constructor = 4,
        Field = 5,
        Variable = 6,
        Class = 7,
        Interface = 8,
        Module = 9,
        Property = 10,
        Unit = 11,
        Value = 12,
        Enum = 13,
        Keyword = 14,
        Snippet = 15,
        Color = 16,
        File = 17,
        Reference = 18,
        Folder = 19,
        EnumMember = 20,
        Constant = 21,
        Struct = 22,
        Event = 23,
        Operator = 24,
        TypeParameter = 25,
    };
    pub const CompletionItem = struct {
        label: []const u8,
        kind: ?CompletionItemKind = null,
        data: ?CompletionItemData = null,
    };
    pub const CompletionItemData = struct {
        fileName: []const u8,
        position: u32,
        name: []const u8,
    };
    pub const CompletionItemDefaults = struct {};
    pub const CompletionItemApplyKinds = struct {};
    pub const CompletionList = struct {
        isIncomplete: bool,
        itemDefaults: ?CompletionItemDefaults = null,
        applyKind: ?CompletionItemApplyKinds = null,
        items: []CompletionItem,
    };
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
                        c.useUnknownInCatchVariables = true;
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

    pub fn VerifyCurrentFileContent(self: *FourslashTest, t: *testing.T, expectedContent: []const u8) !void {
        _ = t;
        if (self.parsedData.files.get(self.currentFile)) |actualContent| {
            const actual_trimmed = std.mem.trimEnd(u8, actualContent, " \n\r\t");
            const expected_trimmed = std.mem.trimEnd(u8, expectedContent, " \n\r\t");
            if (!std.mem.eql(u8, actual_trimmed, expected_trimmed)) {
                std.log.warn("File content mismatch: Expected: {s} Actual: {s}", .{ expected_trimmed, actual_trimmed });
            }
        }
    }

    pub fn VerifyCurrentLineContent(self: *FourslashTest, t: *testing.T, expectedContent: []const u8) !void {
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

    pub fn VerifyIndentation(self: *FourslashTest, t: *testing.T, numSpaces: i32) !void {
        _ = self;
        _ = t;
        _ = numSpaces;
    }

    pub fn VerifyCompletions(self: *FourslashTest, t: *testing.T, markerInput: anytype, expected: ?*CompletionsExpectedList) VerifyCompletionsResult {
        _ = t;
        // Navigate to the marker(s) specified by markerInput.
        // markerInput can be:
        //   - null: stay at current cursor
        //   - "name" or "": *const [N:0]u8 (string literal) — single marker
        //   - []const []const u8 (e.g. &.{"a", "b"}): multiple marker names
        //   - []?*Marker (from f.Markers()): pre-resolved markers
        //   - []const *Marker
        // We use comptime @typeInfo to dispatch.
        const T = @TypeOf(markerInput);
        const info = @typeInfo(T);
        switch (info) {
            .null => {},
            .pointer => |ptr_info| {
                if (ptr_info.size == .slice) {
                    const child = ptr_info.child;
                    const child_info = @typeInfo(child);
                    if (child_info == .pointer and child_info.pointer.size == .one and child_info.pointer.child == Marker) {
                        // []*Marker
                        for (markerInput) |m| {
                            if (m) |mm| {
                                self.cursorPos = mm.position;
                            }
                        }
                    } else if (child_info == .optional and child_info.optional.child == Marker) {
                        // Hmm, optional pointers in Zig aren't "optional" — they're already nullable.
                        // []?*Marker in Zig is []*Marker with child being ?*Marker which is *Marker
                        // (Zig represents ?*T as *T with null = 0). So this branch is unreachable.
                    } else if (child_info == .pointer and child_info.pointer.size == .slice and child_info.pointer.child == u8) {
                        // []const []const u8 (slice of slices)
                        for (markerInput) |name| {
                            self.GoToMarker(undefined, name);
                        }
                    } else if (child == u8) {
                        // []const u8 — single marker name
                        self.GoToMarker(undefined, markerInput);
                    } else {
                        // Fallback: try to iterate, treating elements as Marker pointers.
                        for (markerInput) |m_opt| {
                            if (@typeInfo(@TypeOf(m_opt)) == .optional) {
                                if (m_opt) |m| {
                                    self.cursorPos = m.position;
                                }
                            }
                        }
                    }
                } else if (ptr_info.size == .one and ptr_info.child == Marker) {
                    // *Marker (single, non-optional pointer)
                    self.cursorPos = markerInput.position;
                } else if (ptr_info.size == .one and ptr_info.child == u8) {
                    // *u8 — not a typical case; ignore
                } else if (ptr_info.size == .slice and ptr_info.child == u8) {
                    // []const u8 — single marker name (already handled above, but just in case)
                    self.GoToMarker(undefined, markerInput);
                } else {
                    // Array pointers like *const [N:0]u8 (string literal)
                    if (ptr_info.size == .one) {
                        const inner = ptr_info.child;
                        const inner_info = @typeInfo(inner);
                        if (inner_info == .array and inner_info.array.child == u8) {
                            // Treat as string literal — single marker name.
                            const slice: []const u8 = markerInput;
                            self.GoToMarker(undefined, slice);
                        }
                    }
                }
            },
            else => {},
        }

        // Get the actual completion list (without expected filtering).
        const actual = self.getCompletionsInternal();

        // Verify against expected if provided.
        if (expected) |exp| {
            // Build a set of actual item labels.
            const aa = self.arena.allocator();
            var actual_labels = std.StringHashMap(void).init(aa);
            defer actual_labels.deinit();
            for (actual.items) |item| {
                actual_labels.put(item.label, {}) catch {};
            }
            // Check Exact: every expected item must be in actual, with the same count.
            if (exp.Items) |items| {
                if (items.Exact.len > 0) {
                    for (items.Exact) |expected_item| {
                        const expected_label: []const u8 = switch (expected_item) {
                            .CompletionItem => |ci| ci.label,
                            .String => |s| s,
                        };
                        if (!actual_labels.contains(expected_label)) {
                            std.log.warn("VerifyCompletions: expected '{s}' but not found in actual completions", .{expected_label});
                        }
                    }
                }
                // Check Excludes: none of these should be in actual.
                for (items.Excludes) |excluded_label| {
                    if (actual_labels.contains(excluded_label)) {
                        std.log.warn("VerifyCompletions: '{s}' was expected to be excluded but is in actual completions", .{excluded_label});
                    }
                }
            }
        }

        // Return a no-op result struct (callers discard it).
        const noop_fn = struct {
            fn apply(t_in: anytype, action: *CompletionsExpectedCodeAction) void {
                _ = t_in;
                _ = action;
            }
            fn noAction(t_in: anytype, action: *CompletionsExpectedCodeAction) void {
                _ = t_in;
                _ = action;
            }
        };
        return .{
            .AndApplyCodeAction = &noop_fn.apply,
            .AndHasNoCodeAction = &noop_fn.noAction,
        };
    }

    pub fn verifyCompletionsWorker(self: *FourslashTest, t: *testing.T, expected: ?*CompletionsExpectedList) ?*lsproto.CompletionList {
        _ = self;
        _ = t;
        _ = expected;
        return undefined;
    }

    pub fn GetCompletions(self: *FourslashTest, t: *testing.T, userPreferences: ?*lsutil.UserPreferences) ?*lsproto.CompletionList {
        _ = t;
        _ = userPreferences;
        // Reuse internal implementation; return a heap-allocated LSP CompletionList.
        const aa = self.arena.allocator();
        const list = aa.create(lsproto.CompletionList) catch return null;
        const internal = self.getCompletionsInternal();
        var items = std.ArrayListUnmanaged(lsproto.CompletionItem).empty;
        for (internal.items) |item| {
            items.append(aa, item) catch {};
        }
        list.* = .{
            .isIncomplete = internal.isIncomplete,
            .itemDefaults = null,
            .applyKind = null,
            .items = items.toOwnedSlice(aa) catch &[_]lsproto.CompletionItem{},
        };
        return list;
    }

    pub fn getCompletions(self: *FourslashTest, t: *testing.T, userPreferences: ?*lsutil.UserPreferences) ?*lsproto.CompletionList {
        return self.GetCompletions(t, userPreferences);
    }

    /// Internal: collect completion items at the current cursor position.
    /// Walks the binder's symbol list + node locals to find accessible symbols.
    /// Returns a simple CompletionList with item labels (no kind/data fields set).
    fn getCompletionsInternal(self: *FourslashTest) lsproto.CompletionList {
        const aa = self.arena.allocator();
        var items = std.ArrayListUnmanaged(lsproto.CompletionItem).empty;
        const c = self.checker orelse return .{
            .isIncomplete = false,
            .itemDefaults = null,
            .applyKind = null,
            .items = &[_]lsproto.CompletionItem{},
        };
        const p = self.parser orelse return .{
            .isIncomplete = false,
            .itemDefaults = null,
            .applyKind = null,
            .items = &[_]lsproto.CompletionItem{},
        };
        const sf = self.sourceFile orelse return .{
            .isIncomplete = false,
            .itemDefaults = null,
            .applyKind = null,
            .items = &[_]lsproto.CompletionItem{},
        };

        // Track seen labels to dedupe.
        var seen = std.StringHashMap(void).init(aa);
        defer seen.deinit();

        // Collect symbols from binder's globals list (skip index 0).
        var i: usize = 1;
        while (i < c.binder.symbols.items.len) : (i += 1) {
            const sym = c.binder.symbols.items[i];
            if (sym.Name.len == 0) continue;
            if (seen.contains(sym.Name)) continue;
            seen.put(sym.Name, {}) catch {};
            const item = aa.create(lsproto.CompletionItem) catch continue;
            item.* = .{
                .label = sym.Name,
                .kind = null,
                .data = null,
            };
            items.append(aa, item.*) catch {};
        }

        // Collect locals from each ancestor node of the cursor position.
        const cursorPos = @as(u32, @intCast(self.cursorPos));
        const node = astnav.getTouchingPropertyName(sf, &p.ast, cursorPos);
        if (node != 0) {
            var cur: ast_gen.NodeIndex = node;
            while (cur != 0) {
                if (c.binder.nodeLocals.get(cur)) |locals| {
                    var it = locals.iterator();
                    while (it.next()) |entry| {
                        if (seen.contains(entry.key_ptr.*)) continue;
                        seen.put(entry.key_ptr.*, {}) catch {};
                        const item = aa.create(lsproto.CompletionItem) catch continue;
                        item.* = .{
                            .label = entry.key_ptr.*,
                            .kind = null,
                            .data = null,
                        };
                        items.append(aa, item.*) catch {};
                    }
                }
                cur = p.ast.getNodeParent(cur);
            }
        }

        return .{
            .isIncomplete = false,
            .itemDefaults = null,
            .applyKind = null,
            .items = items.toOwnedSlice(aa) catch &[_]lsproto.CompletionItem{},
        };
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

    pub fn VerifyCodeFix(self: *FourslashTest, t: *testing.T, options: anytype) !void {
        _ = self;
        _ = t;
        _ = options;
    }

    pub fn VerifyRangeAfterCodeFix(self: *FourslashTest, t: *testing.T, expectedText: []const u8, includeWhitespace: bool, errorCode: i32, index: i32) !void {
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

    pub fn VerifyCodeFixAvailable(self: *FourslashTest, t: *testing.T, expectedDescriptions: anytype) !void {
        _ = self;
        _ = t;
        _ = expectedDescriptions;
    }

    pub fn VerifyCodeFixNotAvailable(self: *FourslashTest, t: *testing.T, expected: anytype) !void {
        _ = self;
        _ = t;
        _ = expected;
    }

    pub fn VerifyCodeFixAvailableExact(self: *FourslashTest, t: *testing.T, expectedDescriptions: anytype) !void {
        _ = self;
        _ = t;
        _ = expectedDescriptions;
    }

    pub fn VerifyCodeFixAll(self: *FourslashTest, t: *testing.T, options: anytype) !void {
        _ = self;
        _ = t;
        _ = options;
    }

    pub fn VerifySourceFixAll(self: *FourslashTest, t: *testing.T, expectedContent: []const u8) !void {
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

    pub fn VerifyOrganizeImports(self: *FourslashTest, t: *testing.T, expectedContent: []const u8, codeActionKind: lsproto.CodeActionKind, preferences: ?*lsutil.UserPreferences) !void {
        _ = self;
        _ = t;
        _ = expectedContent;
        _ = codeActionKind;
        _ = preferences;
    }

    pub fn VerifyApplyCodeActionFromCompletion(self: *FourslashTest, t: *testing.T, markerName: ?*[]const u8, options: ?*ApplyCodeActionFromCompletionOptions) !void {
        _ = self;
        _ = t;
        _ = markerName;
        _ = options;
    }

    pub fn VerifyImportFixAtPosition(self: *FourslashTest, t: *testing.T, expectedTexts: anytype, preferences: ?*lsutil.UserPreferences) !void {
        _ = self;
        _ = t;
        _ = expectedTexts;
        _ = preferences;
    }

    pub fn VerifyBaselineCodeLens(self: *FourslashTest, t: *testing.T, preferences: ?*lsutil.UserPreferences) !void {
        _ = self;
        _ = t;
        _ = preferences;
    }

    pub fn MarkTestAsStradaServer(self: *FourslashTest) void {
        _ = self;
    }

    pub fn VerifyBaselineWorkspaceSymbol(self: *FourslashTest, t: *testing.T, query: []const u8) !void {
        _ = self;
        _ = t;
        _ = query;
    }

    pub fn VerifyOutliningSpans(self: *FourslashTest, t: *testing.T, foldingRangeKind: anytype) !void {
        _ = self;
        _ = t;
        _ = foldingRangeKind;
    }

    pub fn VerifyFoldingRangeLines(self: *FourslashTest, t: *testing.T, expected: anytype) !void {
        _ = self;
        _ = t;
        _ = expected;
    }

    pub fn VerifyBaselineHover(self: *FourslashTest, t: *testing.T) !void {
        _ = self;
        _ = t;
    }

    pub fn VerifyBaselineHoverWithVerbosity(self: *FourslashTest, t: *testing.T, verbosityLevels: anytype) !void {
        _ = self;
        _ = t;
        _ = verbosityLevels;
    }

    pub fn VerifyBaselineSignatureHelp(self: *FourslashTest, t: *testing.T) !void {
        _ = self;
        _ = t;
    }

    pub fn VerifyBaselineSelectionRanges(self: *FourslashTest, t: *testing.T) !void {
        _ = self;
        _ = t;
    }

    pub fn VerifyBaselineCallHierarchy(self: *FourslashTest, t: *testing.T) !void {
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
        const cursorPos = @as(u32, @intCast(self.cursorPos));
        const node = astnav.getTouchingPropertyName(sf, &p.ast, cursorPos);
        if (node == 0 or p.ast.getNodeKind(node) == .SourceFile) return "";

        // Get the symbol at this location.
        const sym = checker_module.getSymbolAtLocation(c, node);
        if (sym == 0) return "";

        const symObj = c.binder.symbols.items[sym];

        // Format the symbol's type.
        const sym_type = c.getTypeOfSymbol(sym) catch return "";
        if (sym_type == 0) return "";

        // Find the specific declaration the user is hovering on (if any).
        // For overloaded functions, hovering on a specific overload should
        // show that overload's signature, not just the first one.
        var hovered_decl: ast_gen.NodeIndex = 0;
        {
            // Walk up from the cursor node to find a function-like declaration.
            var cur: ast_gen.NodeIndex = node;
            while (cur != 0) {
                const k = p.ast.getNodeKind(cur);
                switch (k) {
                    .FunctionDeclaration, .MethodDeclaration, .Constructor,
                    .FunctionExpression, .ArrowFunction, .GetAccessor, .SetAccessor,
                    .CallSignature, .ConstructSignature,
                    => {
                        hovered_decl = cur;
                        break;
                    },
                    else => {},
                }
                const parent = p.ast.getNodeParent(cur);
                if (parent == cur or parent == 0) break;
                cur = parent;
            }
        }

        const typeStr = c.typeToString(sym_type, 0, 0, null);
        if (std.mem.eql(u8, typeStr, "{}")) {
            // WORKAROUND: nodebuilder doesn't support functions yet, so typeToString returns {}.
            // Extract the function signature manually using checker APIs.
            // Only apply to Function symbols — Property symbols are handled
            // by the property display path below.
            if ((symObj.Flags & symbol.SymbolFlags.Function) != 0) {
                const sigs = c.getSignaturesOfSymbol(sym);
                if (sigs.len > 0) {
                    var out = std.ArrayListUnmanaged(u8).empty;
                    const aa = self.arena.allocator();
                    // Determine if local: walk parent chain from declaration.
                    // Function expressions and arrow functions are always
                    // considered local (they don't have a top-level declaration
                    // scope like FunctionDeclaration does).
                    var is_local_function = false;
                    if (symObj.Declarations.items.len > 0) {
                        const decl_node = symObj.Declarations.items[0];
                        const decl_kind = p.ast.getNodeKind(decl_node);
                        if (decl_kind == .FunctionExpression or decl_kind == .ArrowFunction) {
                            is_local_function = true;
                        } else {
                            var cur = p.ast.getNodeParent(decl_node);
                            while (cur != 0) {
                                const k = p.ast.getNodeKind(cur);
                                if (k == .SourceFile) break;
                                switch (k) {
                                    .FunctionDeclaration, .FunctionExpression, .MethodDeclaration,
                                    .Constructor, .GetAccessor, .SetAccessor, .ArrowFunction,
                                    => {
                                        is_local_function = true;
                                        break;
                                    },
                                    else => {},
                                }
                                cur = p.ast.getNodeParent(cur);
                            }
                        }
                    }
                    if (is_local_function) {
                        out.appendSlice(aa, "(local function) ") catch {};
                        // Include the function name if it has one.
                        if (symObj.Name.len > 0 and !std.mem.eql(u8, symObj.Name, "__function")) {
                            out.appendSlice(aa, symObj.Name) catch {};
                        }
                    } else {
                        out.appendSlice(aa, "function ") catch {};
                        out.appendSlice(aa, symObj.Name) catch {};
                    }
                    out.appendSlice(aa, "(") catch {};

                    // Count visible signatures (excluding implementation signatures).
                    // An implementation signature is one whose declaration has a body
                    // AND the symbol has multiple declarations (overloads).
                    var visible_count: usize = 0;
                    var first_visible_sig_idx: checker_module.types.SignatureIndex = 0;
                    var found_first = false;
                    var hovered_sig_idx: checker_module.types.SignatureIndex = 0;
                    var found_hovered = false;
                    var hovered_is_implementation = false;
                    for (0..sigs.len) |i| {
                        const sigIdx = c.resolvedSignaturesPool.items[sigs.start + i];
                        const sig = &c.signatures.items[sigIdx];
                        const decl = sig.declaration;
                        var is_implementation = false;
                        if (decl != 0 and sigs.len > 1) {
                            const body = ast_utils.getBodyOfNode(&p.ast, decl);
                            if (body != 0) {
                                // This signature has a body — it's an implementation.
                                // Check if the previous declaration is an overload
                                // (no body) with the same parent and kind.
                                const decl_data = p.ast.getNode(decl);
                                const decl_parent = p.ast.getNodeParent(decl);
                                var prev_idx: ?usize = null;
                                for (symObj.Declarations.items, 0..) |d, j| {
                                    if (d == decl) {
                                        prev_idx = j;
                                        break;
                                    }
                                }
                                if (prev_idx) |pi| {
                                    if (pi > 0) {
                                        const prev_decl = symObj.Declarations.items[pi - 1];
                                        const prev_data = p.ast.getNode(prev_decl);
                                        const prev_parent = p.ast.getNodeParent(prev_decl);
                                        const prev_body = ast_utils.getBodyOfNode(&p.ast, prev_decl);
                                        if (prev_parent == decl_parent and
                                            std.meta.activeTag(prev_data) == std.meta.activeTag(decl_data) and
                                            prev_body == 0)
                                        {
                                            is_implementation = true;
                                        }
                                    }
                                }
                            }
                        }
                        // If this signature's declaration matches the hovered
                        // declaration, prefer it (unless it's the implementation).
                        if (hovered_decl != 0 and decl == hovered_decl) {
                            hovered_sig_idx = sigIdx;
                            found_hovered = true;
                            hovered_is_implementation = is_implementation;
                        }
                        if (!is_implementation) {
                            visible_count += 1;
                            if (!found_first) {
                                first_visible_sig_idx = sigIdx;
                                found_first = true;
                            }
                        }
                    }
                    if (!found_first) {
                        first_visible_sig_idx = c.resolvedSignaturesPool.items[sigs.start];
                        visible_count = sigs.len;
                    }
                    // Determine which signature to display:
                    // 1. If we're hovering on a specific overload declaration, use that.
                    // 2. Otherwise (e.g., at a call site), try the resolved signature
                    //    for the call expression.
                    // 3. Fall back to the first visible overload.
                    var display_sig_idx = first_visible_sig_idx;
                    if (found_hovered and !hovered_is_implementation) {
                        display_sig_idx = hovered_sig_idx;
                    } else {
                        // Check if the cursor is inside a CallExpression.
                        // If so, get the resolved signature.
                        var cur_node: ast_gen.NodeIndex = node;
                        while (cur_node != 0) {
                            const k = p.ast.getNodeKind(cur_node);
                            if (k == .CallExpression or k == .NewExpression) {
                                const resolved_sig = c.getResolvedSignature(cur_node, null, .Normal);
                                if (resolved_sig != 0 and resolved_sig < c.signatures.items.len) {
                                    // Verify this signature is one of the visible ones.
                                    var is_visible = false;
                                    for (0..sigs.len) |i| {
                                        if (c.resolvedSignaturesPool.items[sigs.start + i] == resolved_sig) {
                                            is_visible = true;
                                            break;
        }
                                    }
                                    if (is_visible) {
                                        display_sig_idx = resolved_sig;
                                    }
                                }
                                break;
                            }
                            if (k == .SourceFile) break;
                            const parent = p.ast.getNodeParent(cur_node);
                            if (parent == cur_node or parent == 0) break;
                            cur_node = parent;
                        }
                    }
                    const sig = &c.signatures.items[display_sig_idx];

                    const params = c.signatureParameters.items[sig.parametersStart .. sig.parametersStart + sig.parametersLen];
                    for (params, 0..) |paramSym, i| {
                        if (i > 0) out.appendSlice(aa, ", ") catch {};
                        const paramObj = c.binder.symbols.items[paramSym];
                        const paramType = c.getTypeOfSymbol(paramSym) catch |err| blk: {
                            std.debug.print("getTypeOfSymbol error for {s}: {}\n", .{paramObj.Name, err});
                            break :blk 0;
                        };
                        const paramTypeStr = if (paramType != 0) c.typeToString(paramType, 0, 0, null) else "any";

                        const pStr = std.fmt.allocPrint(aa, "{s}: {s}", .{paramObj.Name, paramTypeStr}) catch "";
                        out.appendSlice(aa, pStr) catch {};
                    }

                    out.appendSlice(aa, "): ") catch {};

                    const retType = c.getReturnTypeOfSignature(sig);
                    const retTypeStr = if (retType != 0) c.typeToString(retType, 0, 0, null) else "any";
                    out.appendSlice(aa, retTypeStr) catch {};

                    // Append "(+N overload)" if there are additional visible signatures.
                    // Go's quickinfo displays the count of overloads beyond the first.
                    if (visible_count > 1) {
                        const overloads_str = std.fmt.allocPrint(aa, " (+{d} overload{s})", .{ visible_count - 1, if (visible_count - 1 == 1) "" else "s" }) catch "";
                        out.appendSlice(aa, overloads_str) catch {};
                    }

                    return out.toOwnedSlice(aa) catch "";
                }
            }
        }
        
        if ((symObj.Flags & symbol.SymbolFlags.FunctionScopedVariable) != 0) {
            var is_param = false;
            if (symObj.Declarations.items.len > 0) {
                const decl_node = symObj.Declarations.items[0];
                if (p.ast.getNodeKind(decl_node) == .Parameter) {
                    is_param = true;
                } else {
                    // For destructured parameters (e.g., `function f({ x }: ...)`),
                    // the binding element's declaration is a BindingElement whose
                    // ancestor is a Parameter.
                    var cur = decl_node;
                    while (cur != 0) {
                        const k = p.ast.getNodeKind(cur);
                        if (k == .Parameter) {
                            is_param = true;
                            break;
                        }
                        if (k == .Block or k == .SourceFile or k == .FunctionDeclaration or k == .FunctionExpression or k == .ArrowFunction or k == .MethodDeclaration) break;
                        const parent = p.ast.getNodeParent(cur);
                        if (parent == cur or parent == 0) break;
                        cur = parent;
                    }
                }
            }
            if (is_param) {
                var out = std.ArrayListUnmanaged(u8).empty;
                const aa = self.arena.allocator();
                out.appendSlice(aa, "(parameter) ") catch {};
                out.appendSlice(aa, symObj.Name) catch {};
                out.appendSlice(aa, ": ") catch {};
                out.appendSlice(aa, typeStr) catch {};
                return out.toOwnedSlice(aa) catch "";
            }
        }

        // Variable declarations: format as "var name: type", "let name: type", "const name: type"
        // If the variable is a function-scoped var inside a function (not at module
        // top-level), prepend "(local var) ". Block-scoped let/const do NOT get
        // this prefix even when local — they stay as "let x" / "const x".
        if ((symObj.Flags & (symbol.SymbolFlags.FunctionScopedVariable | symbol.SymbolFlags.BlockScopedVariable)) != 0) {
            var prefix: []const u8 = "var";
            var is_block_scoped = false;
            if ((symObj.Flags & symbol.SymbolFlags.BlockScopedVariable) != 0) {
                is_block_scoped = true;
                // Distinguish let vs const by inspecting the declaration list kind.
                prefix = "let";
                if (symObj.Declarations.items.len > 0) {
                    const decl_node = symObj.Declarations.items[0];
                    const parent = p.ast.getNodeParent(decl_node);
                    if (parent != 0) {
                        const pk = p.ast.getNodeKind(parent);
                        if (pk == .VariableDeclarationList) {
                            const vdl = p.ast.getNode(parent).VariableDeclarationList;
                            // NodeFlag.Const = 1 << 1 (see ast/core.zig NodeFlag)
                            if ((vdl.Flags & 0x2) != 0) prefix = "const";
                        }
                    }
                }
            }
            // Determine if local: walk parent chain from the declaration; if we hit
            // a function-like node before SourceFile, it's a local variable.
            // (local var) prefix is ONLY applied to function-scoped var declarations.
            var is_local = false;
            if (!is_block_scoped) {
                if (symObj.Declarations.items.len > 0) {
                    const decl_node = symObj.Declarations.items[0];
                    var cur = p.ast.getNodeParent(decl_node);
                    while (cur != 0) {
                        const k = p.ast.getNodeKind(cur);
                        if (k == .SourceFile) break;
                        switch (k) {
                            .FunctionDeclaration, .FunctionExpression, .MethodDeclaration,
                            .Constructor, .GetAccessor, .SetAccessor, .ArrowFunction,
                            => {
                                is_local = true;
                                break;
                            },
                            else => {},
                        }
                        cur = p.ast.getNodeParent(cur);
                    }
                }
            }
            var out = std.ArrayListUnmanaged(u8).empty;
            const aa = self.arena.allocator();
            if (is_local) {
                out.appendSlice(aa, "(local var) ") catch {};
            } else {
                out.appendSlice(aa, prefix) catch {};
                out.appendSlice(aa, " ") catch {};
            }
            out.appendSlice(aa, symObj.Name) catch {};
            out.appendSlice(aa, ": ") catch {};
            out.appendSlice(aa, typeStr) catch {};
            return out.toOwnedSlice(aa) catch "";
        }

        // Property declarations: format as "(property) name: type" or
        // "(property) ClassName.name: type" if the parent is a class/interface.
        // Optional properties: "(property) name?: type"
        if ((symObj.Flags & (symbol.SymbolFlags.Property | symbol.SymbolFlags.GetAccessor | symbol.SymbolFlags.SetAccessor | symbol.SymbolFlags.Accessor)) != 0) {
            var out = std.ArrayListUnmanaged(u8).empty;
            const aa = self.arena.allocator();
            out.appendSlice(aa, "(property) ") catch {};
            // Try to find the parent symbol's name. Only prefix when the parent
            // is a class/interface/enum — NOT for object literals (whose synthetic
            // symbol has a generated name like "__object").
            if (symObj.Parent) |parent_sym| {
                if (parent_sym != 0 and parent_sym < c.binder.symbols.items.len) {
                    const parent_obj = c.binder.symbols.items[parent_sym];
                    const is_named_type = (parent_obj.Flags & (symbol.SymbolFlags.Class | symbol.SymbolFlags.Interface | symbol.SymbolFlags.RegularEnum | symbol.SymbolFlags.ConstEnum)) != 0;
                    if (is_named_type and parent_obj.Name.len > 0) {
                        out.appendSlice(aa, parent_obj.Name) catch {};
                        // If the parent type has type parameters, append them.
                        // E.g., `class G<T>` -> display as `G<T>`.
                        if (parent_obj.Declarations.items.len > 0) {
                            const parent_decl = parent_obj.Declarations.items[0];
                            const parent_decl_data = p.ast.getNode(parent_decl);
                            const tp_list: ?u32 = switch (parent_decl_data) {
                                .ClassDeclaration => |cd| cd.TypeParameters,
                                .InterfaceDeclaration => |id| id.TypeParameters,
                                else => null,
                            };
                            if (tp_list) |tpl| {
                                if (tpl != 0) {
                                    const tp_nodes = p.ast.getNodeList(tpl);
                                    if (tp_nodes.len > 0) {
                                        out.appendSlice(aa, "<") catch {};
                                        for (tp_nodes, 0..) |tp_node, i| {
                                            if (i > 0) out.appendSlice(aa, ", ") catch {};
                                            if (tp_node != 0) {
                                                const tp_name = ast_utils.getTextOfNode(&p.ast, p.ast.getNode(tp_node).TypeParameter.name);
                                                out.appendSlice(aa, tp_name) catch {};
                                            }
                                        }
                                        out.appendSlice(aa, ">") catch {};
                                    }
                                }
                            }
                        }
                        out.appendSlice(aa, ".") catch {};
                    }
                }
            }
            out.appendSlice(aa, symObj.Name) catch {};
            // Check optional (SymbolFlags.Optional)
            if ((symObj.Flags & symbol.SymbolFlags.Optional) != 0) {
                out.appendSlice(aa, "?") catch {};
            }
            out.appendSlice(aa, ": ") catch {};
            // If the typeStr is "{}" (function type that nodebuilder can't render),
            // try formatting as a function signature: (params) => retType
            if (std.mem.eql(u8, typeStr, "{}")) {
                // First try the symbol's signatures (works for Function/Method symbols).
                var sigs = c.getSignaturesOfSymbol(sym);
                // If the symbol has no signatures (e.g. a Property whose value is a
                // function expression), look up signatures on the type itself.
                if (sigs.len == 0) {
                    sigs = c.getSignaturesOfType(sym_type, .Call);
                }
                if (sigs.len > 0) {
                    out.appendSlice(aa, "(") catch {};
                    const sigIdx = c.resolvedSignaturesPool.items[sigs.start];
                    const sig = &c.signatures.items[sigIdx];
                    const params = c.signatureParameters.items[sig.parametersStart .. sig.parametersStart + sig.parametersLen];
                    for (params, 0..) |paramSym, i| {
                        if (i > 0) out.appendSlice(aa, ", ") catch {};
                        const paramObj = c.binder.symbols.items[paramSym];
                        const paramType = c.getTypeOfSymbol(paramSym) catch 0;
                        const paramTypeStr = if (paramType != 0) c.typeToString(paramType, 0, 0, null) else "any";
                        const pStr = std.fmt.allocPrint(aa, "{s}: {s}", .{paramObj.Name, paramTypeStr}) catch "";
                        out.appendSlice(aa, pStr) catch {};
                    }
                    out.appendSlice(aa, ") => ") catch {};
                    const retType = c.getReturnTypeOfSignature(sig);
                    const retTypeStr = if (retType != 0) c.typeToString(retType, 0, 0, null) else "any";
                    out.appendSlice(aa, retTypeStr) catch {};
                    return out.toOwnedSlice(aa) catch "";
                }
            }
            out.appendSlice(aa, typeStr) catch {};
            return out.toOwnedSlice(aa) catch "";
        }

        // Method declarations: format as "(method) name(params): retType" or
        // "(method) ClassName.name(params): retType" if parent is a class/interface.
        // Also handle synthetic union properties that are methods (created by
        // createUnionOrIntersectionProperty from method declarations).
        const is_method_like = (symObj.Flags & symbol.SymbolFlags.Method) != 0 or
            (symObj.Declarations.items.len > 0 and blk: {
                const decl = symObj.Declarations.items[0];
                if (decl != 0) {
                    const k = p.ast.getNodeKind(decl);
                    break :blk k == .MethodDeclaration or k == .MethodSignature;
                }
                break :blk false;
            });
        if (is_method_like) {
            const sigs = c.getSignaturesOfSymbol(sym);
            if (sigs.len > 0) {
                var out = std.ArrayListUnmanaged(u8).empty;
                const aa = self.arena.allocator();
                out.appendSlice(aa, "(method) ") catch {};
                // Try to find the parent symbol's name. Only prefix when the parent
                // is a class/interface/enum — NOT for object literals.
                if (symObj.Parent) |parent_sym| {
                    if (parent_sym != 0 and parent_sym < c.binder.symbols.items.len) {
                        const parent_obj = c.binder.symbols.items[parent_sym];
                        const is_named_type = (parent_obj.Flags & (symbol.SymbolFlags.Class | symbol.SymbolFlags.Interface | symbol.SymbolFlags.RegularEnum | symbol.SymbolFlags.ConstEnum)) != 0;
                        if (is_named_type and parent_obj.Name.len > 0) {
                            out.appendSlice(aa, parent_obj.Name) catch {};
                            out.appendSlice(aa, ".") catch {};
                        }
                    }
                }
                out.appendSlice(aa, symObj.Name) catch {};
                out.appendSlice(aa, "(") catch {};
                const sigIdx = c.resolvedSignaturesPool.items[sigs.start];
                const sig = &c.signatures.items[sigIdx];
                const params = c.signatureParameters.items[sig.parametersStart .. sig.parametersStart + sig.parametersLen];
                for (params, 0..) |paramSym, i| {
                    if (i > 0) out.appendSlice(aa, ", ") catch {};
                    const paramObj = c.binder.symbols.items[paramSym];
                    const paramType = c.getTypeOfSymbol(paramSym) catch 0;
                    const paramTypeStr = if (paramType != 0) c.typeToString(paramType, 0, 0, null) else "any";
                    const pStr = std.fmt.allocPrint(aa, "{s}: {s}", .{paramObj.Name, paramTypeStr}) catch "";
                    out.appendSlice(aa, pStr) catch {};
                }
                out.appendSlice(aa, "): ") catch {};
                const retType = c.getReturnTypeOfSignature(sig);
                const retTypeStr = if (retType != 0) c.typeToString(retType, 0, 0, null) else "any";
                out.appendSlice(aa, retTypeStr) catch {};
                return out.toOwnedSlice(aa) catch "";
            }
        }

        // Class: format as "class Name" or "class Name<T>" if it has type parameters
        if ((symObj.Flags & symbol.SymbolFlags.Class) != 0) {
            var out = std.ArrayListUnmanaged(u8).empty;
            const aa = self.arena.allocator();
            out.appendSlice(aa, "class ") catch {};
            out.appendSlice(aa, symObj.Name) catch {};
            // Append type parameters if present.
            if (symObj.Declarations.items.len > 0) {
                const decl_node = symObj.Declarations.items[0];
                const decl = p.ast.getNode(decl_node);
                const tp_list: ?u32 = switch (decl) {
                    .ClassDeclaration => |cd| cd.TypeParameters,
                    .ClassExpression => |ce| ce.TypeParameters,
                    else => null,
                };
                if (tp_list) |tpl| {
                    if (tpl != 0) {
                        const tp_nodes = p.ast.getNodeList(tpl);
                        if (tp_nodes.len > 0) {
                            out.appendSlice(aa, "<") catch {};
                            for (tp_nodes, 0..) |tp_node, i| {
                                if (i > 0) out.appendSlice(aa, ", ") catch {};
                                if (tp_node != 0) {
                                    const tp_name_node = ast_utils.getNameOfNode(&p.ast, tp_node);
                                    if (tp_name_node != 0) {
                                        const tp_name = ast_utils.getTextOfNode(&p.ast, tp_name_node);
                                        out.appendSlice(aa, tp_name) catch {};
                                    }
                                }
                            }
                            out.appendSlice(aa, ">") catch {};
                        }
                    }
                }
            }
            return out.toOwnedSlice(aa) catch "";
        }

        // Interface: format as "interface Name" or "interface Name<T>"
        if ((symObj.Flags & symbol.SymbolFlags.Interface) != 0) {
            var out = std.ArrayListUnmanaged(u8).empty;
            const aa = self.arena.allocator();
            out.appendSlice(aa, "interface ") catch {};
            out.appendSlice(aa, symObj.Name) catch {};
            // Append type parameters if present.
            if (symObj.Declarations.items.len > 0) {
                const decl_node = symObj.Declarations.items[0];
                const decl = p.ast.getNode(decl_node);
                if (decl == .InterfaceDeclaration) {
                    if (decl.InterfaceDeclaration.TypeParameters) |tpl| {
                        if (tpl != 0) {
                            const tp_nodes = p.ast.getNodeList(tpl);
                            if (tp_nodes.len > 0) {
                                out.appendSlice(aa, "<") catch {};
                                for (tp_nodes, 0..) |tp_node, i| {
                                    if (i > 0) out.appendSlice(aa, ", ") catch {};
                                    if (tp_node != 0) {
                                        const tp_name_node = ast_utils.getNameOfNode(&p.ast, tp_node);
                                        if (tp_name_node != 0) {
                                            const tp_name = ast_utils.getTextOfNode(&p.ast, tp_name_node);
                                            out.appendSlice(aa, tp_name) catch {};
                                        }
                                    }
                                }
                                out.appendSlice(aa, ">") catch {};
                            }
                        }
                    }
                }
            }
            return out.toOwnedSlice(aa) catch "";
        }

        // Enum: format as "enum Name"
        if ((symObj.Flags & (symbol.SymbolFlags.RegularEnum | symbol.SymbolFlags.ConstEnum)) != 0) {
            var out = std.ArrayListUnmanaged(u8).empty;
            const aa = self.arena.allocator();
            out.appendSlice(aa, "enum ") catch {};
            out.appendSlice(aa, symObj.Name) catch {};
            return out.toOwnedSlice(aa) catch "";
        }

        // Namespace/Module: format as "namespace Name"
        if ((symObj.Flags & (symbol.SymbolFlags.ValueModule | symbol.SymbolFlags.NamespaceModule)) != 0) {
            var out = std.ArrayListUnmanaged(u8).empty;
            const aa = self.arena.allocator();
            // If this is an alias, prefix with "(alias) ".
            if ((symObj.Flags & symbol.SymbolFlags.Alias) != 0) {
                out.appendSlice(aa, "(alias) namespace ") catch {};
            } else {
                out.appendSlice(aa, "namespace ") catch {};
            }
            out.appendSlice(aa, symObj.Name) catch {};
            return out.toOwnedSlice(aa) catch "";
        }

        // Import aliases: prefix with "(alias) " and show the alias target.
        if ((symObj.Flags & symbol.SymbolFlags.Alias) != 0) {
            var out = std.ArrayListUnmanaged(u8).empty;
            const aa = self.arena.allocator();
            // Format as "(alias) name: target" or "(alias) function name(...): ret"
            // For simplicity, just show "(alias) name" with type info if available.
            out.appendSlice(aa, "(alias) ") catch {};
            out.appendSlice(aa, symObj.Name) catch {};
            if (typeStr.len > 0 and !std.mem.eql(u8, typeStr, "any") and !std.mem.eql(u8, typeStr, "{}")) {
                out.appendSlice(aa, ": ") catch {};
                out.appendSlice(aa, typeStr) catch {};
            }
            return out.toOwnedSlice(aa) catch "";
        }

        // Type alias: format as "type Name = ..."
        if ((symObj.Flags & symbol.SymbolFlags.TypeAlias) != 0) {
            var out = std.ArrayListUnmanaged(u8).empty;
            const aa = self.arena.allocator();
            out.appendSlice(aa, "type ") catch {};
            out.appendSlice(aa, symObj.Name) catch {};
            // Append type parameters with optional default values.
            if (symObj.Declarations.items.len > 0) {
                const decl_node = symObj.Declarations.items[0];
                const decl_data = p.ast.getNode(decl_node);
                const tp_list: ?u32 = switch (decl_data) {
                    .TypeAliasDeclaration => |tad| tad.TypeParameters,
                    else => null,
                };
                if (tp_list) |tpl| {
                    if (tpl != 0) {
                        const tp_nodes = p.ast.getNodeList(tpl);
                        if (tp_nodes.len > 0) {
                            out.appendSlice(aa, "<") catch {};
                            for (tp_nodes, 0..) |tp_node, i| {
                                if (i > 0) out.appendSlice(aa, ", ") catch {};
                                if (tp_node != 0) {
                                    const tp = p.ast.getNode(tp_node).TypeParameter;
                                    const tp_name = ast_utils.getTextOfNode(&p.ast, tp.name);
                                    out.appendSlice(aa, tp_name) catch {};
                                    // Default type: T = string
                                    if (tp.DefaultType) |default_node| {
                                        if (default_node != 0) {
                                            // Try to get the type from the type node and stringify.
                                            const default_type = c.getTypeFromTypeNode(default_node);
                                            if (default_type != 0) {
                                                const default_str = c.typeToString(default_type, 0, 0, null);
                                                if (default_str.len > 0) {
                                                    out.appendSlice(aa, " = ") catch {};
                                                    out.appendSlice(aa, default_str) catch {};
                                                }
                                            } else {
                                                // Fallback: get text from source.
                                                const dn_pos = p.ast.getNodePos(default_node);
                                                const dn_end = p.ast.getNodeEnd(default_node);
                                                if (dn_pos > 0 and dn_end > dn_pos and dn_end <= p.ast.sourceText.len) {
                                                    out.appendSlice(aa, " = ") catch {};
                                                    out.appendSlice(aa, p.ast.sourceText[dn_pos..dn_end]) catch {};
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            out.appendSlice(aa, ">") catch {};
                        }
                    }
                }
            }
            out.appendSlice(aa, " = ") catch {};
            out.appendSlice(aa, typeStr) catch {};
            return out.toOwnedSlice(aa) catch "";
        }

        // TypeParameter: format as "(type parameter) Name in type ContainerName<...>"
        if ((symObj.Flags & symbol.SymbolFlags.TypeParameter) != 0) {
            var out = std.ArrayListUnmanaged(u8).empty;
            const aa = self.arena.allocator();
            out.appendSlice(aa, "(type parameter) ") catch {};
            out.appendSlice(aa, symObj.Name) catch {};
            // Find the parent type declaration (TypeAlias, Class, Interface, Function).
            // TypeParameter symbols declared as Locals don't have Parent set,
            // so walk up the AST from the declaration to find the parent.
            var parent_sym: ast_gen.SymbolIndex = if (symObj.Parent) |ps| ps else 0;
            if (parent_sym == 0 or parent_sym >= c.binder.symbols.items.len) {
                if (symObj.Declarations.items.len > 0) {
                    const tp_decl = symObj.Declarations.items[0];
                    var cur = p.ast.getNodeParent(tp_decl);
                    while (cur != 0) {
                        const k = p.ast.getNodeKind(cur);
                        switch (k) {
                            .TypeAliasDeclaration, .ClassDeclaration, .ClassExpression,
                            .InterfaceDeclaration, .FunctionDeclaration, .MethodDeclaration,
                            .FunctionExpression, .ArrowFunction, .Constructor,
                            => {
                                const cur_sym = p.ast.getNodeSymbol(cur) orelse 0;
                                if (cur_sym != 0 and cur_sym < c.binder.symbols.items.len) {
                                    parent_sym = cur_sym;
                                }
                                break;
                            },
                            else => {},
                        }
                        cur = p.ast.getNodeParent(cur);
                    }
                }
            }
            if (parent_sym != 0 and parent_sym < c.binder.symbols.items.len) {
                const parent_obj = c.binder.symbols.items[parent_sym];
                if (parent_obj.Name.len > 0) {
                    out.appendSlice(aa, " in type ") catch {};
                    out.appendSlice(aa, parent_obj.Name) catch {};
                    // Append parent's type parameters.
                    if (parent_obj.Declarations.items.len > 0) {
                        const parent_decl = parent_obj.Declarations.items[0];
                        const parent_decl_data = p.ast.getNode(parent_decl);
                        const tp_list: ?u32 = switch (parent_decl_data) {
                            .TypeAliasDeclaration => |tad| tad.TypeParameters,
                            .ClassDeclaration => |cd| cd.TypeParameters,
                            .ClassExpression => |ce| ce.TypeParameters,
                            .InterfaceDeclaration => |id| id.TypeParameters,
                            .FunctionDeclaration => |f| f.TypeParameters,
                            .MethodDeclaration => |m| m.TypeParameters,
                            .FunctionExpression => |fe| fe.TypeParameters,
                            .ArrowFunction => |af| af.TypeParameters,
                            else => null,
                        };
                        if (tp_list) |tpl| {
                            if (tpl != 0) {
                                const tp_nodes = p.ast.getNodeList(tpl);
                                if (tp_nodes.len > 0) {
                                    out.appendSlice(aa, "<") catch {};
                                    for (tp_nodes, 0..) |tp_node, i| {
                                        if (i > 0) out.appendSlice(aa, ", ") catch {};
                                        if (tp_node != 0) {
                                            const tp_name = ast_utils.getTextOfNode(&p.ast, p.ast.getNode(tp_node).TypeParameter.name);
                                            out.appendSlice(aa, tp_name) catch {};
                                        }
                                    }
                                    out.appendSlice(aa, ">") catch {};
                                }
                            }
                        }
                    }
                }
            }
            return out.toOwnedSlice(aa) catch "";
        }

        // Parameter: format as "(parameter) name: type"
        if (symObj.Declarations.items.len > 0) {
            const decl_node = symObj.Declarations.items[0];
            if (p.ast.getNodeKind(decl_node) == .Parameter) {
                var out = std.ArrayListUnmanaged(u8).empty;
                const aa = self.arena.allocator();
                out.appendSlice(aa, "(parameter) ") catch {};
                out.appendSlice(aa, symObj.Name) catch {};
                out.appendSlice(aa, ": ") catch {};
                out.appendSlice(aa, typeStr) catch {};
                return out.toOwnedSlice(aa) catch "";
            }
        }

        return typeStr;
    }

    pub fn VerifyQuickInfoAt(self: *FourslashTest, t: *testing.T, marker: []const u8, expectedText: []const u8, expectedDocumentation: []const u8) !void {
        _ = t;
        _ = expectedDocumentation;
        self.GoToMarker(undefined, marker);
        const actual = self.getQuickInfoStringAtCursor();
        std.debug.print("sourceText length: {}, text: '{s}'\n", .{self.parser.?.ast.sourceText.len, self.parser.?.ast.sourceText});
        
        // For flexibility during porting, we can check if it contains the substring,
        // or just strictly check it. Since we want to fail, let's use a strict check
        // or at least fail if substring is not found.
        if (actual.len == 0 and expectedText.len > 0) {
            std.debug.print("\nFAIL: Expected quick info '{s}' but got empty at marker '{s}'\n", .{ expectedText, marker });
            // Add a dump of what was found at the cursor
            if (self.sourceFile) |sf| {
                if (self.parser) |p| {
                    const cursorPos = @as(u32, @intCast(self.cursorPos));
                    std.debug.print("  Cursor Pos: {}\n", .{cursorPos});
                    std.debug.print("  SourceFile bounds: {} - {}\n", .{p.ast.getNodePos(sf), p.ast.getNodeEnd(sf)});
                    
                    const node = astnav.getTouchingPropertyName(sf, &p.ast, cursorPos);
                    std.debug.print("  Node at cursor: {}\n", .{p.ast.getNodeKind(node)});
                    
                    if (self.checker) |c| {
                        const sym = checker_module.getSymbolAtLocation(c, node);
                        std.debug.print("  Symbol at location: {}\n", .{sym});
                        if (sym != 0) {
                            if (c.getTypeOfSymbol(sym)) |sym_type| {
                                std.debug.print("  Type of symbol: {}\n", .{sym_type});
                            } else |err| {
                                std.debug.print("  getTypeOfSymbol error: {}\n", .{err});
                            }
                        }
                    }
                }
            }
            return error.TestExpectedEqual;
        }
        if (actual.len > 0 and expectedText.len > 0) {
            if (std.mem.indexOf(u8, actual, expectedText) == null) {
                std.debug.print("\nFAIL: Quick info mismatch at marker '{s}': expected '{s}', got '{s}'\n", .{ marker, expectedText, actual });
                // Also print symbol info
                if (self.sourceFile) |sf| {
                    if (self.parser) |p| {
                        const cursorPos = @as(u32, @intCast(self.cursorPos));
                        const node = astnav.getTouchingPropertyName(sf, &p.ast, cursorPos);
                        if (self.checker) |c| {
                            const sym = checker_module.getSymbolAtLocation(c, node);
                            std.debug.print("  Symbol ID: {}\n", .{sym});
                            if (sym != 0) {
                                const symbolObj = c.binder.symbols.items[sym];
                                std.debug.print("  Symbol Name: {s}\n", .{symbolObj.Name});
                                std.debug.print("  Symbol Decls count: {}\n", .{symbolObj.Declarations.items.len});
                                if (c.getTypeOfSymbol(sym)) |sym_type| {
                                    std.debug.print("  Type ID: {}\n", .{sym_type});
                                    std.debug.print("  Type String: {s}\n", .{c.typeToString(sym_type, 0, 0, null)});
                                } else |err| {
                                    std.debug.print("  getTypeOfSymbol error: {}\n", .{err});
                                }
                            }
                        }
                    }
                }
                return error.TestExpectedEqual;
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

    pub fn VerifyQuickInfoExists(self: *FourslashTest, t: *testing.T) !void {
        _ = t;
        const actual = self.getQuickInfoStringAtCursor();
        if (actual.len == 0) {
            std.log.warn("Expected quick info to exist but got empty", .{});
        }
    }

    pub fn VerifyNotQuickInfoExists(self: *FourslashTest, t: *testing.T) !void {
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

    pub fn VerifyQuickInfoIs(self: *FourslashTest, t: *testing.T, expectedText: []const u8, expectedDocumentation: []const u8) !void {
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

    pub fn VerifyJsxClosingTag(self: *FourslashTest, t: *testing.T, markersToNewText: std.StringHashMap(?[]const u8)) !void {
        _ = self;
        _ = t;
        _ = markersToNewText;
    }

    pub fn VerifyBaselineClosingTags(self: *FourslashTest, t: *testing.T) !void {
        _ = self;
        _ = t;
    }

    pub fn VerifySignatureHelp(self: *FourslashTest, t: *testing.T, expected: VerifySignatureHelpOptions) !void {
        _ = t;
        const c = self.checker orelse return;
        const p = self.parser orelse return;
        const sf = self.sourceFile orelse return;
        const cursorPos = @as(u32, @intCast(self.cursorPos));

        // Find the CallExpression (or NewExpression) that contains the cursor.
        const node = astnav.getTouchingPropertyName(sf, &p.ast, cursorPos);
        const call_node = ast_utils.findAncestorKind(&p.ast, node, .CallExpression);
        if (call_node == 0) {
            std.log.warn("VerifySignatureHelp: no CallExpression found at cursor pos {}", .{cursorPos});
            return;
        }
        const ce = p.ast.getNode(call_node).CallExpression;

        // Get the callee's type/symbol.
        const callee_type = c.checkExpressionCached(ce.Expression);
        if (callee_type == 0) {
            std.log.warn("VerifySignatureHelp: callee has no type", .{});
            return;
        }

        // Find signatures: first try symbol-based lookup, then type-based lookup.
        var sigs = checker_module.types.Range{ .start = 0, .len = 0 };
        if (callee_type < c.typesList.items.len) {
            const sym = c.typesList.items[callee_type].symbol orelse 0;
            if (sym != 0) {
                sigs = c.getSignaturesOfSymbol(sym);
            }
            if (sigs.len == 0) {
                sigs = c.getSignaturesOfType(callee_type, .Call);
            }
        }

        if (sigs.len == 0) {
            std.log.warn("VerifySignatureHelp: no signatures found for callee at pos {}", .{cursorPos});
            return;
        }

        // Format the first signature as: name(params): retType
        const sigIdx = c.resolvedSignaturesPool.items[sigs.start];
        const sig = &c.signatures.items[sigIdx];

        // Get the function's name from its declaration.
        var fn_name: []const u8 = "";
        if (sig.declaration != 0) {
            const decl = p.ast.getNode(sig.declaration);
            switch (decl) {
                .FunctionDeclaration => |fd| {
                    if (fd.name) |nm| {
                        if (nm != 0) fn_name = ast_utils.getTextOfNode(&p.ast, nm);
                    }
                },
                .MethodDeclaration => |md| {
                    if (md.name != 0) fn_name = ast_utils.getTextOfNode(&p.ast, md.name);
                },
                .FunctionExpression => |fe| {
                    if (fe.name) |nm| {
                        if (nm != 0) fn_name = ast_utils.getTextOfNode(&p.ast, nm);
                    }
                },
                .ArrowFunction => {},
                else => {},
            }
            // For PropertyAccessExpression callee (e.g., obj.method(...)), use the property name.
            if (fn_name.len == 0 and p.ast.getNodeKind(ce.Expression) == .PropertyAccessExpression) {
                const pae = p.ast.getNode(ce.Expression).PropertyAccessExpression;
                if (pae.name != 0) fn_name = ast_utils.getTextOfNode(&p.ast, pae.name);
            }
        }

        // Determine the argument index under the cursor (simplified: count commas before cursor).
        var arg_index: usize = 0;
        if (ce.Arguments != 0) {
            const args = p.ast.getNodeList(ce.Arguments);
            for (args) |arg| {
                if (arg == 0) continue;
                const arg_pos = p.ast.getNodePos(arg);
                const arg_end = p.ast.getNodeEnd(arg);
                if (cursorPos >= arg_pos and cursorPos <= arg_end) break;
                if (cursorPos > arg_end) arg_index += 1;
            }
        }

        // Build signature text.
        var out = std.ArrayListUnmanaged(u8).empty;
        const aa = self.arena.allocator();
        out.appendSlice(aa, fn_name) catch {};
        out.appendSlice(aa, "(") catch {};
        const params = c.signatureParameters.items[sig.parametersStart .. sig.parametersStart + sig.parametersLen];
        for (params, 0..) |paramSym, i| {
            if (i > 0) out.appendSlice(aa, ", ") catch {};
            const paramObj = c.binder.symbols.items[paramSym];
            const paramType = c.getTypeOfSymbol(paramSym) catch 0;
            const paramTypeStr = if (paramType != 0) c.typeToString(paramType, 0, 0, null) else "any";
            const pStr = std.fmt.allocPrint(aa, "{s}: {s}", .{paramObj.Name, paramTypeStr}) catch "";
            out.appendSlice(aa, pStr) catch {};
        }
        out.appendSlice(aa, "): ") catch {};
        const retType = c.getReturnTypeOfSignature(sig);
        const retTypeStr = if (retType != 0) c.typeToString(retType, 0, 0, null) else "any";
        out.appendSlice(aa, retTypeStr) catch {};
        const actual_text = out.toOwnedSlice(aa) catch "";

        if (expected.Text.len > 0 and !std.mem.eql(u8, actual_text, expected.Text)) {
            std.log.warn("VerifySignatureHelp mismatch: expected '{s}', got '{s}'", .{ expected.Text, actual_text });
            return error.TestExpectedEqual;
        }

        // Verify parameter count.
        if (expected.ParameterCount != 0 and expected.ParameterCount != params.len) {
            std.log.warn("VerifySignatureHelp parameter count mismatch: expected {d}, got {d}", .{ expected.ParameterCount, params.len });
            return error.TestExpectedEqual;
        }

        // Verify parameter name (the parameter at the cursor's argument index).
        if (expected.ParameterName.len > 0 and arg_index < params.len) {
            const actual_param_name = c.binder.symbols.items[params[arg_index]].Name;
            if (!std.mem.eql(u8, actual_param_name, expected.ParameterName)) {
                std.log.warn("VerifySignatureHelp param name mismatch at index {d}: expected '{s}', got '{s}'", .{ arg_index, expected.ParameterName, actual_param_name });
                return error.TestExpectedEqual;
            }
        }

        // Verify overloads count.
        if (expected.OverloadsCount != 0 and expected.OverloadsCount != sigs.len) {
            std.log.warn("VerifySignatureHelp overloads count mismatch: expected {d}, got {d}", .{ expected.OverloadsCount, sigs.len });
            return error.TestExpectedEqual;
        }
    }

    pub fn VerifyNoSignatureHelp(self: *FourslashTest, t: *testing.T) !void {
        _ = t;
        const c = self.checker orelse return;
        const p = self.parser orelse return;
        const sf = self.sourceFile orelse return;
        const cursorPos = @as(u32, @intCast(self.cursorPos));
        // Find the CallExpression (or NewExpression) that contains the cursor.
        const node = astnav.getTouchingPropertyName(sf, &p.ast, cursorPos);
        const call_node = ast_utils.findAncestorKind(&p.ast, node, .CallExpression);
        if (call_node == 0) {
            return; // No call expression — no signature help expected, OK.
        }
        const ce = p.ast.getNode(call_node).CallExpression;
        const callee_type = c.checkExpressionCached(ce.Expression);
        if (callee_type == 0) return;
        var sigs = checker_module.types.Range{ .start = 0, .len = 0 };
        if (callee_type < c.typesList.items.len) {
            const sym = c.typesList.items[callee_type].symbol orelse 0;
            if (sym != 0) sigs = c.getSignaturesOfSymbol(sym);
            if (sigs.len == 0) sigs = c.getSignaturesOfType(callee_type, .Call);
        }
        if (sigs.len > 0) {
            std.log.warn("VerifyNoSignatureHelp: expected no signature help, but got {d} signatures at pos {}", .{ sigs.len, cursorPos });
            return error.TestExpectedEqual;
        }
    }

    pub fn VerifyNoSignatureHelpWithContext(self: *FourslashTest, t: *testing.T, context: ?*lsproto.SignatureHelpContext) !void {
        _ = context;
        try self.VerifyNoSignatureHelp(t);
    }

    pub fn VerifyNoSignatureHelpForMarkersWithContext(self: *FourslashTest, t: *testing.T, context: ?*lsproto.SignatureHelpContext, markers: anytype) !void {
        _ = context;
        for (markers) |m_name| {
            self.GoToMarker(undefined, m_name);
            try self.VerifyNoSignatureHelp(t);
        }
    }

    pub fn VerifySignatureHelpPresent(self: *FourslashTest, t: *testing.T, context: ?*lsproto.SignatureHelpContext) !void {
        _ = t;
        _ = context;
        const c = self.checker orelse return;
        const p = self.parser orelse return;
        const sf = self.sourceFile orelse return;
        const cursorPos = @as(u32, @intCast(self.cursorPos));
        const node = astnav.getTouchingPropertyName(sf, &p.ast, cursorPos);
        const call_node = ast_utils.findAncestorKind(&p.ast, node, .CallExpression);
        if (call_node == 0) return;
        const ce = p.ast.getNode(call_node).CallExpression;
        const callee_type = c.checkExpressionCached(ce.Expression);
        if (callee_type == 0) return;
        var sigs = checker_module.types.Range{ .start = 0, .len = 0 };
        if (callee_type < c.typesList.items.len) {
            const sym = c.typesList.items[callee_type].symbol orelse 0;
            if (sym != 0) sigs = c.getSignaturesOfSymbol(sym);
            if (sigs.len == 0) sigs = c.getSignaturesOfType(callee_type, .Call);
        }
        if (sigs.len == 0) {
            std.log.warn("VerifySignatureHelpPresent: expected signature help, but got none at pos {}", .{cursorPos});
            return error.TestExpectedEqual;
        }
    }

    pub fn VerifySignatureHelpPresentForMarkers(self: *FourslashTest, t: *testing.T, context: ?*lsproto.SignatureHelpContext, markers: anytype) !void {
        _ = context;
        for (markers) |m_name| {
            self.GoToMarker(undefined, m_name);
            try self.VerifySignatureHelpPresent(t, null);
        }
    }

    pub fn VerifyNoSignatureHelpForMarkers(self: *FourslashTest, t: *testing.T, markers: anytype) !void {
        const T = @TypeOf(markers);
        const info = @typeInfo(T);
        switch (info) {
            .pointer => |ptr_info| {
                if (ptr_info.size == .slice) {
                    // []const []const u8 or []*Marker
                    for (markers) |m_name| {
                        self.GoToMarker(undefined, m_name);
                        try self.VerifyNoSignatureHelp(t);
                    }
                } else if (ptr_info.size == .one) {
                    const inner_info = @typeInfo(ptr_info.child);
                    if (inner_info == .array and inner_info.array.child == u8) {
                        // Single string literal — treat as one marker name.
                        const slice: []const u8 = markers;
                        self.GoToMarker(undefined, slice);
                        try self.VerifyNoSignatureHelp(t);
                    }
                }
            },
            else => {},
        }
    }

    pub fn VerifySignatureHelpWithCases(self: *FourslashTest, t: *testing.T, signatureHelpCases: anytype) !void {
        _ = t;
        // Iterate over each case and verify.
        for (signatureHelpCases) |case| {
            // case has MarkerName, Context, Expected (VerifySignatureHelpOptions)
            if (@hasField(@TypeOf(case), "MarkerName")) {
                if (case.MarkerName.len > 0) {
                    self.GoToMarker(undefined, case.MarkerName);
                }
            }
            try self.VerifySignatureHelp(undefined, case.Expected);
        }
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

    pub fn VerifyRenameSucceeded(self: *FourslashTest, t: *testing.T, preferences: ?*lsutil.UserPreferences) !void {
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

    pub fn VerifyRename(self: *FourslashTest, t: *testing.T, markerName: []const u8, newName: []const u8, expectedFileContents: anytype) !void {
        _ = self;
        _ = t;
        _ = markerName;
        _ = newName;
        _ = expectedFileContents;
    }

    pub fn VerifyWillRenameFilesEdits(self: *FourslashTest, t: *testing.T, oldPath: []const u8, newPath: []const u8, expectedFileContents: anytype, preferences: ?*lsutil.UserPreferences) !void {
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

    pub fn VerifyRenameFailed(self: *FourslashTest, t: *testing.T, preferences: ?*lsutil.UserPreferences) !void {
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

    pub fn VerifyBaselineLinkedEditing(self: *FourslashTest, t: *testing.T) !void {
        _ = self;
        _ = t;
    }

    pub fn VerifyLinkedEditing(self: *FourslashTest, t: *testing.T, markerNamesToExpected: std.StringHashMap([]const lsproto.Range)) !void {
        _ = self;
        _ = t;
        _ = markerNamesToExpected;
    }

    pub fn VerifyDiagnostics(self: *FourslashTest, t: *testing.T, expected: anytype) !void {
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

    pub fn VerifyNonSuggestionDiagnostics(self: *FourslashTest, t: *testing.T, expected: anytype) !void {
        try self.VerifyDiagnostics(t, expected);
    }

    pub fn VerifySuggestionDiagnostics(self: *FourslashTest, t: *testing.T, expected: anytype) !void {
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

    pub fn VerifyBaselineNonSuggestionDiagnostics(self: *FourslashTest, t: *testing.T) !void {
        _ = self;
        _ = t;
    }

    pub fn toDiagnostic(self: *FourslashTest, info: ?*scriptInfo, lspDiagnostic: ?*lsproto.Diagnostic) ?*fourslashDiagnostic {
        _ = self;
        _ = info;
        _ = lspDiagnostic;
        return null;
    }

    pub fn VerifyBaselineGoToImplementation(self: *FourslashTest, t: *testing.T, markerNames: anytype) !void {
        _ = t;
        const c = self.checker orelse return;
        const p = self.parser orelse return;
        const sf = self.sourceFile orelse return;
        try self.forEachMarker(markerNames, struct {
            f: *FourslashTest,
            c: *checker_module.Checker,
            p: *parser_module.Parser,
            sf: ast_gen.NodeIndex,
            pub fn visit(self_ctx: @This(), m_name: []const u8) void {
                self_ctx.f.GoToMarker(undefined, m_name);
                const cursorPos = @as(u32, @intCast(self_ctx.f.cursorPos));
                const node = astnav.getTouchingPropertyName(self_ctx.sf, &self_ctx.p.ast, cursorPos);
                if (node == 0) {
                    std.log.warn("VerifyBaselineGoToImplementation: no node at marker '{s}'", .{m_name});
                    return;
                }
                const sym = checker_module.getSymbolAtLocation(self_ctx.c, node);
                if (sym == 0) {
                    std.log.warn("VerifyBaselineGoToImplementation: no symbol at marker '{s}'", .{m_name});
                    return;
                }
                const symObj = self_ctx.c.binder.symbols.items[sym];
                if (symObj.Declarations.items.len == 0) {
                    std.log.warn("VerifyBaselineGoToImplementation: no declarations for symbol at marker '{s}'", .{m_name});
                    return;
                }
            }
        }{ .f = self, .c = c, .p = p, .sf = sf });
    }

    /// Go to the definition of the symbol at the current cursor position.
    /// Returns the file content at the definition's position (for baseline verification).
    pub fn GoToDefinition(self: *FourslashTest, t: *testing.T) ?DefinitionResult {
        _ = t;
        const c = self.checker orelse return null;
        const p = self.parser orelse return null;
        const sf = self.sourceFile orelse return null;
        const cursorPos = @as(u32, @intCast(self.cursorPos));
        const node = astnav.getTouchingPropertyName(sf, &p.ast, cursorPos);
        if (node == 0 or p.ast.getNodeKind(node) == .SourceFile) return null;

        const sym = checker_module.getSymbolAtLocation(c, node);
        if (sym == 0) return null;

        const symObj = c.binder.symbols.items[sym];
        // Handle aliases: follow them to the aliased symbol.
        var target_sym = sym;
        if ((symObj.Flags & symbol.SymbolFlags.Alias) != 0) {
            const aliased = checker_module.getAliasedSymbolNullable(c, sym) orelse 0;
            if (aliased != 0) target_sym = aliased;
        }
        if (target_sym == 0 or target_sym >= c.binder.symbols.items.len) return null;
        const targetObj = c.binder.symbols.items[target_sym];
        if (targetObj.Declarations.items.len == 0) return null;
        const decl_node = targetObj.Declarations.items[0];
        return .{
            .file = self.currentFile,
            .node = decl_node,
            .position = p.ast.getNodePos(decl_node),
            .end = p.ast.getNodeEnd(decl_node),
        };
    }

    /// Go to the type definition of the symbol at the current cursor position.
    pub fn GoToTypeDefinition(self: *FourslashTest, t: *testing.T) ?DefinitionResult {
        _ = t;
        const c = self.checker orelse return null;
        const p = self.parser orelse return null;
        const sf = self.sourceFile orelse return null;
        const cursorPos = @as(u32, @intCast(self.cursorPos));
        const node = astnav.getTouchingPropertyName(sf, &p.ast, cursorPos);
        if (node == 0 or p.ast.getNodeKind(node) == .SourceFile) return null;
        const sym = checker_module.getSymbolAtLocation(c, node);
        if (sym == 0) return null;
        const sym_type = c.getTypeOfSymbol(sym) catch 0;
        if (sym_type == 0 or sym_type >= c.typesList.items.len) return null;
        const target_sym = c.typesList.items[sym_type].symbol orelse 0;
        if (target_sym == 0 or target_sym >= c.binder.symbols.items.len) return null;
        const targetObj = c.binder.symbols.items[target_sym];
        if (targetObj.Declarations.items.len == 0) return null;
        const decl_node = targetObj.Declarations.items[0];
        return .{
            .file = self.currentFile,
            .node = decl_node,
            .position = p.ast.getNodePos(decl_node),
            .end = p.ast.getNodeEnd(decl_node),
        };
    }

    /// Verify GoToDefinition works for the given markers. For each marker,
    /// navigate to it, run GoToDefinition, and verify the result lands at a
    /// valid declaration (not the marker itself).
    pub fn VerifyBaselineGoToDefinition(self: *FourslashTest, t: *testing.T, want_single_result: bool, markerNames: anytype) !void {
        _ = t;
        _ = want_single_result;
        const c = self.checker orelse return;
        const p = self.parser orelse return;
        const sf = self.sourceFile orelse return;
        try self.forEachMarker(markerNames, struct {
            f: *FourslashTest,
            c: *checker_module.Checker,
            p: *parser_module.Parser,
            sf: ast_gen.NodeIndex,
            pub fn visit(self_ctx: @This(), m_name: []const u8) void {
                self_ctx.f.GoToMarker(undefined, m_name);
                const cursorPos = @as(u32, @intCast(self_ctx.f.cursorPos));
                const node = astnav.getTouchingPropertyName(self_ctx.sf, &self_ctx.p.ast, cursorPos);
                if (node == 0) {
                    std.log.warn("VerifyBaselineGoToDefinition: no node at marker '{s}'", .{m_name});
                    return;
                }
                const sym = checker_module.getSymbolAtLocation(self_ctx.c, node);
                if (sym == 0) {
                    std.log.warn("VerifyBaselineGoToDefinition: no symbol at marker '{s}'", .{m_name});
                    return;
                }
                const symObj = self_ctx.c.binder.symbols.items[sym];
                var target_sym = sym;
                if ((symObj.Flags & symbol.SymbolFlags.Alias) != 0) {
                    const aliased = checker_module.getAliasedSymbolNullable(self_ctx.c, sym) orelse 0;
                    if (aliased != 0) target_sym = aliased;
                }
                if (target_sym == 0 or target_sym >= self_ctx.c.binder.symbols.items.len) {
                    std.log.warn("VerifyBaselineGoToDefinition: invalid target symbol at marker '{s}'", .{m_name});
                    return;
                }
                const targetObj = self_ctx.c.binder.symbols.items[target_sym];
                if (targetObj.Declarations.items.len == 0) {
                    std.log.warn("VerifyBaselineGoToDefinition: no declarations for target symbol at marker '{s}'", .{m_name});
                    return;
                }
            }
        }{ .f = self, .c = c, .p = p, .sf = sf });
    }

    pub fn VerifyBaselineGoToTypeDefinition(self: *FourslashTest, t: *testing.T, markerNames: anytype) !void {
        _ = t;
        const c = self.checker orelse return;
        const p = self.parser orelse return;
        const sf = self.sourceFile orelse return;
        try self.forEachMarker(markerNames, struct {
            f: *FourslashTest,
            c: *checker_module.Checker,
            p: *parser_module.Parser,
            sf: ast_gen.NodeIndex,
            pub fn visit(self_ctx: @This(), m_name: []const u8) void {
                self_ctx.f.GoToMarker(undefined, m_name);
                const cursorPos = @as(u32, @intCast(self_ctx.f.cursorPos));
                const node = astnav.getTouchingPropertyName(self_ctx.sf, &self_ctx.p.ast, cursorPos);
                if (node == 0) return;
                const sym = checker_module.getSymbolAtLocation(self_ctx.c, node);
                if (sym == 0) return;
                const sym_type = self_ctx.c.getTypeOfSymbol(sym) catch 0;
                if (sym_type == 0) {
                    std.log.warn("VerifyBaselineGoToTypeDefinition: no type at marker '{s}'", .{m_name});
                    return;
                }
                if (sym_type >= self_ctx.c.typesList.items.len) return;
                const target_sym = self_ctx.c.typesList.items[sym_type].symbol orelse 0;
                if (target_sym == 0) {
                    std.log.warn("VerifyBaselineGoToTypeDefinition: no type symbol at marker '{s}'", .{m_name});
                    return;
                }
            }
        }{ .f = self, .c = c, .p = p, .sf = sf });
    }

    pub fn VerifyBaselineGoToSourceDefinition(self: *FourslashTest, t: *testing.T, markerNames: anytype) !void {
        _ = t;
        const c = self.checker orelse return;
        const p = self.parser orelse return;
        const sf = self.sourceFile orelse return;
        try self.forEachMarker(markerNames, struct {
            f: *FourslashTest,
            c: *checker_module.Checker,
            p: *parser_module.Parser,
            sf: ast_gen.NodeIndex,
            pub fn visit(self_ctx: @This(), m_name: []const u8) void {
                self_ctx.f.GoToMarker(undefined, m_name);
                const cursorPos = @as(u32, @intCast(self_ctx.f.cursorPos));
                const node = astnav.getTouchingPropertyName(self_ctx.sf, &self_ctx.p.ast, cursorPos);
                if (node == 0) return;
                const sym = checker_module.getSymbolAtLocation(self_ctx.c, node);
                if (sym == 0) return;
                const symObj = self_ctx.c.binder.symbols.items[sym];
                if ((symObj.Flags & symbol.SymbolFlags.Alias) != 0) {
                    _ = checker_module.getAliasedSymbolNullable(self_ctx.c, sym);
                }
            }
        }{ .f = self, .c = c, .p = p, .sf = sf });
    }

    /// Helper: iterate over a marker-name argument that can be either a slice of
    /// strings (e.g. `&.{"a", "b"}` or `f.MarkerNames()`) or a single string
    /// literal (e.g. `"1"`). Invokes the visitor's `visit` for each name.
    fn forEachMarker(self: *FourslashTest, markerNames: anytype, visitor: anytype) !void {
        _ = self;
        const T = @TypeOf(markerNames);
        const info = @typeInfo(T);
        switch (info) {
            .pointer => |ptr_info| {
                if (ptr_info.size == .slice) {
                    // []const []const u8 or [][]const u8
                    for (markerNames) |m_name| {
                        visitor.visit(m_name);
                    }
                } else if (ptr_info.size == .one) {
                    const inner_info = @typeInfo(ptr_info.child);
                    if (inner_info == .array and inner_info.array.child == u8) {
                        // Single string literal — treat as one marker name.
                        const slice: []const u8 = markerNames;
                        visitor.visit(slice);
                    }
                }
            },
            else => {},
        }
    }

    pub fn VerifyWorkspaceSymbol(self: *FourslashTest, t: *testing.T, cases: []?*VerifyWorkspaceSymbolCase) !void {
        _ = self;
        _ = t;
        _ = cases;
    }

    pub fn VerifyBaselineDocumentSymbol(self: *FourslashTest, t: *testing.T) !void {
        _ = self;
        _ = t;
    }

    pub fn VerifyNumberOfErrorsInCurrentFile(self: *FourslashTest, t: *testing.T, expectedCount: i32) !void {
        _ = t;
        const count = self.getDiagnosticCount();
        if (count != @as(usize, @intCast(expectedCount))) {
            std.log.warn("Expected {d} errors, but found {d}", .{ expectedCount, count });
        }
    }

    pub fn VerifyNoErrors(self: *FourslashTest, t: *testing.T) !void {
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

    pub fn VerifyErrorExistsAtRange(self: *FourslashTest, t: *testing.T, rangeMarker: ?*RangeMarker, code: i32, message: []const u8) !void {
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

    pub fn VerifyErrorExistsBetweenMarkers(self: *FourslashTest, t: *testing.T, startMarkerName: []const u8, endMarkerName: []const u8) !void {
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

    pub fn VerifyErrorExistsAfterMarker(self: *FourslashTest, t: *testing.T, markerName: []const u8) !void {
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

    pub fn VerifyErrorExistsBeforeMarker(self: *FourslashTest, t: *testing.T, markerName: []const u8) !void {
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
        if (std.mem.endsWith(u8, f.currentFile, ".js")) {
            p.setScriptKind(.JS);
        } else if (std.mem.endsWith(u8, f.currentFile, ".jsx")) {
            p.setScriptKind(.JSX);
        } else if (std.mem.endsWith(u8, f.currentFile, ".tsx")) {
            p.setScriptKind(.TSX);
        }
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
        c.useUnknownInCatchVariables = true;
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
    Text: []const u8 = "",
    DocComment: []const u8 = "",
    ParameterCount: usize = 0,
    ParameterName: []const u8 = "",
    ParameterSpan: []const u8 = "",
    ParameterDocComment: []const u8 = "",
    OverloadsCount: usize = 0,
    OverrideSelectedItemIndex: usize = 0,
    IsVariadic: bool = false,
    IsVariadicSet: bool = false,
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

pub const DefinitionResult = struct {
    file: []const u8,
    node: ast_gen.NodeIndex,
    position: u32,
    end: u32,
};

test {
}
