const std = @import("std");

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
const RangeMarker = struct {};
const stateBaseline = struct {};
const lsconv = struct {
    pub const LSPLineMap = struct {};
    pub const Converters = struct {};
};
const lsutil = struct {
    pub const UserPreferences = struct {};
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
        _ = t;
        _ = info;
        _ = params;
        _ = baselineProjects;
        // Calls baselines, lsptestutil.SendRequest, then handles response
        return undefined;
    }

    pub fn sendNotification(self: *FourslashTest, comptime Params: type, t: *testing.T, info: lsproto.NotificationInfo(Params), params: Params) void {
        _ = t;
        _ = info;
        _ = params;
        // Calls updateState, baselines, lsptestutil.SendNotification
    }

    pub fn GoToMarkerOrRange(self: *FourslashTest, t: *testing.T, markerOrRange: MarkerOrRange) void {
        _ = self;
        _ = t;
        _ = markerOrRange;
    }

    pub fn GoToMarker(self: *FourslashTest, t: *testing.T, markerName: []const u8) void {
        _ = self;
        _ = t;
        _ = markerName;
    }

    pub fn goToMarker(self: *FourslashTest, t: *testing.T, markerOrRange: MarkerOrRange) void {
        _ = self;
        _ = t;
        _ = markerOrRange;
    }

    pub fn GoToEOF(self: *FourslashTest, t: *testing.T) void {
        _ = self;
        _ = t;
    }

    pub fn GoToBOF(self: *FourslashTest, t: *testing.T) void {
        _ = self;
        _ = t;
    }

    pub fn GoToPosition(self: *FourslashTest, t: *testing.T, position: i32) void {
        _ = self;
        _ = t;
        _ = position;
    }

    pub fn goToPosition(self: *FourslashTest, t: *testing.T, position: lsproto.Position) void {
        _ = self;
        _ = t;
        _ = position;
    }

    pub fn GoToEachMarker(self: *FourslashTest, t: *testing.T, markerNames: [][]const u8, action: anytype, index: i32)  {
        _ = self;
        _ = t;
        _ = markerNames;
        _ = action;
        _ = index;
        return undefined;
    }

    pub fn GoToEachRange(self: *FourslashTest, t: *testing.T, action: anytype, rangeMarker: ?*RangeMarker)  {
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
        _ = self;
        _ = t;
        _ = filename;
    }

    pub fn GoToFileNumber(self: *FourslashTest, t: *testing.T, index: i32) void {
        _ = self;
        _ = t;
        _ = index;
    }

    pub fn Markers(self: *FourslashTest) []?*Marker {
        _ = self;
        return undefined;
    }

    pub fn MarkerNames(self: *FourslashTest) [][]const u8 {
        _ = self;
        return undefined;
    }

    pub fn MarkerByName(self: *FourslashTest, t: *testing.T, name: []const u8) ?*Marker {
        _ = self;
        _ = t;
        _ = name;
        return undefined;
    }

    pub fn Ranges(self: *FourslashTest) []?*RangeMarker {
        _ = self;
        return undefined;
    }

    pub fn getRangesInFile(self: *FourslashTest, fileName: []const u8) []?*RangeMarker {
        _ = self;
        _ = fileName;
        return undefined;
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
        _ = self;
        _ = t;
        _ = filename;
    }

    pub fn FormatSelection(self: *FourslashTest, t: *testing.T, startMarkerName: []const u8, endMarkerName: []const u8) void {
        _ = self;
        _ = t;
        _ = startMarkerName;
        _ = endMarkerName;
    }

    pub fn VerifyCurrentFileContent(self: *FourslashTest, t: *testing.T, expectedContent: []const u8) void {
        _ = self;
        _ = t;
        _ = expectedContent;
    }

    pub fn VerifyCurrentLineContent(self: *FourslashTest, t: *testing.T, expectedContent: []const u8) void {
        _ = self;
        _ = t;
        _ = expectedContent;
    }

    pub fn VerifyIndentation(self: *FourslashTest, t: *testing.T, numSpaces: i32) void {
        _ = self;
        _ = t;
        _ = numSpaces;
    }

    pub fn VerifyCompletions(self: *FourslashTest, t: *testing.T, markerInput: MarkerInput, expected: ?*CompletionsExpectedList) VerifyCompletionsResult {
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

    pub fn verifyCompletionsItems(self: *FourslashTest, t: *testing.T, prefix: []const u8, actual: []?*lsproto.CompletionItem, expected: ?*CompletionsExpectedItems) void {
        _ = self;
        _ = t;
        _ = prefix;
        _ = actual;
        _ = expected;
    }

    pub fn verifyCompletionsAreExactly(self: *FourslashTest, t: *testing.T, prefix: []const u8, actual: []?*lsproto.CompletionItem, expected: []CompletionsExpectedItem) void {
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

    pub fn VerifyCodeFix(self: *FourslashTest, t: *testing.T, options: VerifyCodeFixOptions) void {
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

    pub fn VerifyCodeFixAvailable(self: *FourslashTest, t: *testing.T, expectedDescriptions: [][]const u8) void {
        _ = self;
        _ = t;
        _ = expectedDescriptions;
    }

    pub fn VerifyCodeFixNotAvailable(self: *FourslashTest, t: *testing.T, expected: anytype) void {
        _ = self;
        _ = t;
        _ = expected;
    }

    pub fn VerifyCodeFixAvailableExact(self: *FourslashTest, t: *testing.T, expectedDescriptions: [][]const u8) void {
        _ = self;
        _ = t;
        _ = expectedDescriptions;
    }

    pub fn VerifyCodeFixAll(self: *FourslashTest, t: *testing.T, options: VerifyCodeFixAllOptions) void {
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

    pub fn VerifyImportFixAtPosition(self: *FourslashTest, t: *testing.T, expectedTexts: [][]const u8, preferences: ?*lsutil.UserPreferences) void {
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

    pub fn VerifyFoldingRangeLines(self: *FourslashTest, t: *testing.T, expected: []FoldingRangeLineExpected) void {
        _ = self;
        _ = t;
        _ = expected;
    }

    pub fn VerifyBaselineHover(self: *FourslashTest, t: *testing.T) void {
        _ = self;
        _ = t;
    }

    pub fn VerifyBaselineHoverWithVerbosity(self: *FourslashTest, t: *testing.T, verbosityLevels: map[string][]int) void {
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

    pub fn lookupMarkersOrGetRanges(self: *FourslashTest, t: *testing.T, markers: [][]const u8) []MarkerOrRange {
        _ = self;
        _ = t;
        _ = markers;
        return undefined;
    }

    pub fn Insert(self: *FourslashTest, t: *testing.T, text: []const u8) void {
        _ = self;
        _ = t;
        _ = text;
    }

    pub fn InsertLine(self: *FourslashTest, t: *testing.T, text: []const u8) void {
        _ = self;
        _ = t;
        _ = text;
    }

    pub fn Backspace(self: *FourslashTest, t: *testing.T, count: i32) void {
        _ = self;
        _ = t;
        _ = count;
    }

    pub fn DeleteAtCaret(self: *FourslashTest, t: *testing.T, count: i32) void {
        _ = self;
        _ = t;
        _ = count;
    }

    pub fn Paste(self: *FourslashTest, t: *testing.T, text: []const u8) void {
        _ = self;
        _ = t;
        _ = text;
    }

    pub fn ReplaceLine(self: *FourslashTest, t: *testing.T, lineIndex: i32, text: []const u8) void {
        _ = self;
        _ = t;
        _ = lineIndex;
        _ = text;
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
        _ = self;
        _ = t;
        _ = start;
        _ = length;
        _ = text;
    }

    pub fn replaceWorker(self: *FourslashTest, t: *testing.T, start: i32, length: i32, text: []const u8) void {
        _ = self;
        _ = t;
        _ = start;
        _ = length;
        _ = text;
    }

    pub fn typeText(self: *FourslashTest, t: *testing.T, text: []const u8) void {
        _ = self;
        _ = t;
        _ = text;
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

    pub fn VerifyQuickInfoAt(self: *FourslashTest, t: *testing.T, marker: []const u8, expectedText: []const u8, expectedDocumentation: []const u8) void {
        _ = self;
        _ = t;
        _ = marker;
        _ = expectedText;
        _ = expectedDocumentation;
    }

    pub fn getQuickInfoAtCurrentPosition(self: *FourslashTest, t: *testing.T) ?*lsproto.Hover {
        _ = self;
        _ = t;
        return undefined;
    }

    pub fn VerifyQuickInfoExists(self: *FourslashTest, t: *testing.T) void {
        _ = self;
        _ = t;
    }

    pub fn VerifyNotQuickInfoExists(self: *FourslashTest, t: *testing.T) void {
        _ = self;
        _ = t;
    }

    pub fn quickInfoIsEmpty(self: *FourslashTest, t: *testing.T) anytype {
        _ = self;
        _ = t;
        return undefined;
    }

    pub fn VerifyQuickInfoIs(self: *FourslashTest, t: *testing.T, expectedText: []const u8, expectedDocumentation: []const u8) void {
        _ = self;
        _ = t;
        _ = expectedText;
        _ = expectedDocumentation;
    }

    pub fn VerifyJsxClosingTag(self: *FourslashTest, t: *testing.T, markersToNewText: map[string]*string) void {
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

    pub fn BaselineAutoImportsCompletions(self: *FourslashTest, t: *testing.T, markerNames: [][]const u8) void {
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

    pub fn VerifyRename(self: *FourslashTest, t: *testing.T, markerName: []const u8, newName: []const u8, expectedFileContents: map[string]string) void {
        _ = self;
        _ = t;
        _ = markerName;
        _ = newName;
        _ = expectedFileContents;
    }

    pub fn VerifyWillRenameFilesEdits(self: *FourslashTest, t: *testing.T, oldPath: []const u8, newPath: []const u8, expectedFileContents: map[string]string, preferences: ?*lsutil.UserPreferences) void {
        _ = self;
        _ = t;
        _ = oldPath;
        _ = newPath;
        _ = expectedFileContents;
        _ = preferences;
    }

    pub fn getPathUpdater(self: *FourslashTest, param_0: anytype, newPath: []const u8) anytype {
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

    pub fn GetRangesByText(self: *FourslashTest) anytype {
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

    pub fn VerifyLinkedEditing(self: *FourslashTest, t: *testing.T, markerNamesToExpected: map[string][]lsproto.Range) void {
        _ = self;
        _ = t;
        _ = markerNamesToExpected;
    }

    pub fn VerifyDiagnostics(self: *FourslashTest, t: *testing.T, expected: []?*lsproto.Diagnostic) void {
        _ = self;
        _ = t;
        _ = expected;
    }

    pub fn VerifyNonSuggestionDiagnostics(self: *FourslashTest, t: *testing.T, expected: []?*lsproto.Diagnostic) void {
        _ = self;
        _ = t;
        _ = expected;
    }

    pub fn VerifySuggestionDiagnostics(self: *FourslashTest, t: *testing.T, expected: []?*lsproto.Diagnostic) void {
        _ = self;
        _ = t;
        _ = expected;
    }

    pub fn verifyDiagnostics(self: *FourslashTest, t: *testing.T, expected: []?*lsproto.Diagnostic, filterDiagnostics: anytype) bool {
        _ = self;
        _ = t;
        _ = expected;
        _ = filterDiagnostics;
        return undefined;
    }

    pub fn getDiagnostics(self: *FourslashTest, t: *testing.T, fileName: []const u8) []?*lsproto.Diagnostic {
        _ = self;
        _ = t;
        _ = fileName;
        return undefined;
    }

    pub fn VerifyBaselineNonSuggestionDiagnostics(self: *FourslashTest, t: *testing.T) void {
        _ = self;
        _ = t;
    }

    pub fn toDiagnostic(self: *FourslashTest, scriptInfo: ?*scriptInfo, lspDiagnostic: ?*lsproto.Diagnostic) ?*fourslashDiagnostic {
        _ = self;
        _ = scriptInfo;
        _ = lspDiagnostic;
        return undefined;
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
        _ = self;
        _ = t;
        _ = expectedCount;
    }

    pub fn VerifyNoErrors(self: *FourslashTest, t: *testing.T) void {
        _ = self;
        _ = t;
    }

    pub fn VerifyErrorExistsAtRange(self: *FourslashTest, t: *testing.T, rangeMarker: ?*RangeMarker, code: i32, message: []const u8) void {
        _ = self;
        _ = t;
        _ = rangeMarker;
        _ = code;
        _ = message;
    }

    pub fn VerifyErrorExistsBetweenMarkers(self: *FourslashTest, t: *testing.T, startMarkerName: []const u8, endMarkerName: []const u8) void {
        _ = self;
        _ = t;
        _ = startMarkerName;
        _ = endMarkerName;
    }

    pub fn VerifyErrorExistsAfterMarker(self: *FourslashTest, t: *testing.T, markerName: []const u8) void {
        _ = self;
        _ = t;
        _ = markerName;
    }

    pub fn VerifyErrorExistsBeforeMarker(self: *FourslashTest, t: *testing.T, markerName: []const u8) void {
        _ = self;
        _ = t;
        _ = markerName;
    }

};

pub fn getBaseFileNameFromTest(t: *testing.T) []const u8 {
    _ = t;
    return "dummy";
}

pub fn NewFourslash(t: *testing.T, capabilities: *lsproto.ClientCapabilities, content: []const u8) *FourslashTest {
    _ = t;
    _ = capabilities;
    _ = content;
    // Uses ParseTestData, sets up VFS, creates lsp server options, initializes LSPClient, calls f.initialize()
    return undefined;
}

const diagnostics = struct {
    pub const Category = enum { Error, Warning, Suggestion, Message };
};
const harnessutil = struct {
    pub const TestFile = struct {};
};
const Marker = struct {};

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
    AndApplyCodeAction: *const fn(t: *std.testing.T, expectedAction: *CompletionsExpectedCodeAction) void,
    AndHasNoCodeAction: *const fn(t: *std.testing.T, unexpectedAction: *CompletionsExpectedCodeAction) void,
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

