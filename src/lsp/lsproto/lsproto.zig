const std = @import("std");

pub const DocumentUri = struct {
    pub fn fileName(self: *const @This()) []const u8 { _ = self; return ""; }
};
pub const Position = struct { line: u32 = 0, character: u32 = 0 };
pub const Range = struct { start: Position = .{}, end: Position = .{} };
pub const Location = struct { uri: DocumentUri = .{}, range: Range = .{} };
pub const ReferencesResponse = struct { LocationsOrNull: union(enum) { locations: ?[]Location } };
pub const ReferenceParams = struct { context: struct { includeDeclaration: bool = false }, textDocument: struct { uri: DocumentUri = .{} }, position: Position = .{} };
pub const HoverParams = struct { textDocument: struct { uri: DocumentUri = .{}, hover: struct { contentFormat: u32 = 0 } }, position: Position = .{}, verbosityLevel: ?u32 = null };
pub const HoverOrNull = struct { hover: ?*anyopaque };
pub const RenameParams = struct { textDocument: struct { uri: DocumentUri = .{} }, position: Position = .{}, newName: []const u8 = "" };
pub const WorkspaceEdit = struct { changes: std.StringHashMap([]TextEdit) };
pub const TextEdit = struct { range: Range, newText: []const u8 };
pub const DocumentSymbol = struct { name: []const u8, detail: ?[]const u8, kind: enum { Variable }, tags: ?[]const u8, deprecated: ?bool, range: Range, selectionRange: Range, children: ?[]DocumentSymbol };
pub const SymbolInformation = struct {};
pub fn getClientCapabilities() struct { textDocument: struct { hover: struct { contentFormat: u32 = 0 }, documentSymbol: struct { hierarchicalDocumentSymbolSupport: bool = false } } } { return .{ .textDocument = .{ .hover = .{ .contentFormat = 0 }, .documentSymbol = .{ .hierarchicalDocumentSymbolSupport = false } } }; }
pub fn preferredMarkupKind(format: u32) u32 { return format; }

pub const DocumentDiagnosticResponse = struct {};
pub const DefinitionResponse = struct {};
pub const CompletionContext = struct {};
pub const CompletionResponse = struct {};
pub const CodeActionParams = struct {};
pub const CodeAction = struct {};
pub const SemanticTokensParams = struct {};
pub const SemanticTokens = struct {};
pub const DocumentHighlight = struct {};
pub const SignatureHelp = struct {};
pub const FoldingRange = struct {};
pub const InlayHintParams = struct {};
pub const InlayHint = struct {};
pub const CallHierarchyPrepareParams = struct {};
pub const CallHierarchyItem = struct {};
pub const CallHierarchyIncomingCallsParams = struct {};
pub const CallHierarchyIncomingCall = struct {};
pub const CallHierarchyOutgoingCallsParams = struct {};
pub const CallHierarchyOutgoingCall = struct {};
pub const SelectionRangeParams = struct {};
pub const SelectionRange = struct {};
pub const FileSystemWatcher = struct {};
pub const PublishDiagnosticsParams = struct {};
pub const TelemetryEvent = struct {};
pub const Message = struct {};
pub const RequestMessage = struct {};
pub const ResponseMessage = struct {};
pub const ErrorCode = enum { methodNotFound };
pub const CompletionItem = struct {};
pub const CompletionItemDefaults = struct {};
pub const CompletionItemApplyKinds = struct {};
pub const CompletionList = struct {};
pub const CompletionItemData = struct {};
pub const PositionEncodingKind = enum { utf8 };
