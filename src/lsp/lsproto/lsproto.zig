const std = @import("std");

pub const DocumentUri = struct {
    pub fn fileName(self: *const @This()) []const u8 {
        _ = self;
        return "";
    }
};
pub const Position = struct { line: u32 = 0, character: u32 = 0 };
pub const Range = struct { start: Position = .{}, end: Position = .{} };
pub const Location = struct { uri: DocumentUri = .{}, range: Range = .{} };
pub const ReferencesResponse = struct { LocationsOrNull: union(enum) { locations: ?[]Location } };
pub const ReferenceParams = struct { context: struct { includeDeclaration: bool = false }, textDocument: struct { uri: DocumentUri = .{} }, position: Position = .{} };
pub const MarkupContent = struct { kind: u32, value: []const u8 };
pub const Hover = struct {
    contents: struct { markupContent: MarkupContent },
    range: ?Range,
    canIncreaseVerbosity: bool,
};
pub const HoverParams = struct { textDocument: struct { uri: DocumentUri = .{}, hover: struct { contentFormat: u32 = 0 } }, position: Position = .{}, verbosityLevel: ?u32 = null };
pub const HoverOrNull = struct { hover: ?*Hover };
pub const RenameParams = struct { textDocument: struct { uri: DocumentUri = .{} }, position: Position = .{}, newName: []const u8 = "" };
pub const WorkspaceEdit = struct { changes: std.StringHashMap([]TextEdit) };
pub const TextEdit = struct { range: Range, newText: []const u8 };
pub const DocumentSymbol = struct { name: []const u8, detail: ?[]const u8, kind: enum { Variable }, tags: ?[]const u8, deprecated: ?bool, range: Range, selectionRange: Range, children: ?[]DocumentSymbol };
pub const SymbolInformation = struct {};
pub fn getClientCapabilities() struct { textDocument: struct { definition: struct { linkSupport: bool = false }, hover: struct { contentFormat: u32 = 0 }, documentSymbol: struct { hierarchicalDocumentSymbolSupport: bool = false } } } {
    return .{ .textDocument = .{ .definition = .{ .linkSupport = false }, .hover = .{ .contentFormat = 0 }, .documentSymbol = .{ .hierarchicalDocumentSymbolSupport = false } } };
}
pub fn preferredMarkupKind(format: u32) u32 {
    return format;
}

pub const DocumentDiagnosticResponse = struct {};
pub const DefinitionResponse = struct { LocationOrLocationsOrDefinitionLinksOrNull: union(enum) { locations: ?[]Location } };
pub const CompletionContext = struct {
    triggerCharacter: ?[]const u8 = null,
};
pub const CompletionResponse = struct {
    CompletionItemsOrListOrNull: ?union(enum) {
        items: []CompletionItem,
        list: *CompletionList,
    } = null,
};
pub const CodeActionParams = struct {};
pub const CodeAction = struct {
    title: []const u8,
    kind: ?[]const u8 = null,
    edit: ?WorkspaceEdit = null,
};
pub const SemanticTokensParams = struct {};
pub const SemanticTokens = struct {};
pub const DocumentHighlightKind = enum(u32) {
    Text = 1,
    Read = 2,
    Write = 3,
};
pub const DocumentHighlight = struct {
    range: Range,
    kind: ?DocumentHighlightKind = null,
};
pub const SignatureHelp = struct {
    signatures: []SignatureInformation,
    activeSignature: ?u32 = null,
    activeParameter: ?u32 = null,
};
pub const ParameterInformation = struct {
    label: []const u8,
    documentation: ?[]const u8 = null,
};
pub const FoldingRange = struct {
    startLine: u32,
    startCharacter: ?u32 = null,
    endLine: u32,
    endCharacter: ?u32 = null,
    kind: ?[]const u8 = null,
};
pub const SignatureInformation = struct {
    label: []const u8,
    documentation: ?[]const u8 = null,
    parameters: ?[]ParameterInformation = null,
    activeParameter: ?u32 = null,
};
pub const InlayHintParams = struct {
    textDocument: struct { uri: DocumentUri },
    range: Range,
};
pub const InlayHint = struct {
    position: Position,
    label: []const u8,
    kind: ?u32 = null,
};
pub const CallHierarchyPrepareParams = struct {
    textDocument: struct { uri: DocumentUri },
    position: Position,
};
pub const CallHierarchyItem = struct {
    name: []const u8,
    kind: u32,
    uri: DocumentUri,
    range: Range,
    selectionRange: Range,
};
pub const CallHierarchyIncomingCallsParams = struct {};
pub const CallHierarchyIncomingCall = struct {};
pub const CallHierarchyOutgoingCallsParams = struct {};
pub const CallHierarchyOutgoingCall = struct {};
pub const SelectionRangeParams = struct {
    textDocument: struct { uri: DocumentUri },
    positions: []Position,
};
pub const SelectionRange = struct {
    range: Range,
    parent: ?*SelectionRange = null,
};
pub const FileSystemWatcher = struct {};
pub const PublishDiagnosticsParams = struct {};
pub const TelemetryEvent = struct {};
pub const Message = struct {};
pub const RequestMessage = struct {};
pub const ResponseMessage = struct {};
pub const ErrorCode = enum { methodNotFound };
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
pub const CompletionItemDefaults = struct {};
pub const CompletionItemApplyKinds = struct {};
pub const CompletionList = struct {
    isIncomplete: bool,
    itemDefaults: ?CompletionItemDefaults = null,
    applyKind: ?CompletionItemApplyKinds = null,
    items: []CompletionItem,
};
pub const CompletionItemData = struct {
    fileName: []const u8,
    position: u32,
    name: []const u8,
};
pub const PositionEncodingKind = enum { utf8 };

pub const SignatureHelpTriggerKind = enum(u32) {
    Invoked = 1,
    TriggerCharacter = 2,
    ContentChange = 3,
};

pub const SignatureHelpContext = struct {
    triggerKind: SignatureHelpTriggerKind,
    triggerCharacter: ?[]const u8 = null,
    isRetrigger: bool,
    activeSignatureHelp: ?SignatureHelp = null,
};
