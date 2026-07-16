const std = @import("std");
const structcodec = @import("structcodec.zig");

pub const SemanticTokenType = enum([]const u8) {
    namespace = "namespace",
    type_ = "type",
    class = "class",
    enum_ = "enum",
    interface = "interface",
    struct_ = "struct",
    typeParameter = "typeParameter",
    parameter = "parameter",
    variable = "variable",
    property = "property",
    enumMember = "enumMember",
    event = "event",
    function = "function",
    method = "method",
    macro = "macro",
    keyword = "keyword",
    modifier = "modifier",
    comment = "comment",
    string = "string",
    number = "number",
    regexp = "regexp",
    operator = "operator",
    decorator = "decorator",
    label = "label",
};

pub const SemanticTokenModifier = enum([]const u8) {
    declaration = "declaration",
    definition = "definition",
    readonly = "readonly",
    static = "static",
    deprecated = "deprecated",
    abstract = "abstract",
    async = "async",
    modification = "modification",
    documentation = "documentation",
    defaultLibrary = "defaultLibrary",
};

pub const DocumentDiagnosticReportKind = enum([]const u8) {
    Full = "full",
    Unchanged = "unchanged",
};

pub const ErrorCode = enum(i32) {
    ParseError = -32700,
    InvalidRequest = -32600,
    MethodNotFound = -32601,
    InvalidParams = -32602,
    InternalError = -32603,
    ServerNotInitialized = -32002,
    UnknownErrorCode = -32001,
    RequestFailed = -32803,
    ServerCancelled = -32802,
    ContentModified = -32801,
    RequestCancelled = -32800,
};

pub const FoldingRangeKind = enum([]const u8) {
    Comment = "comment",
    Imports = "imports",
    Region = "region",
};

pub const SymbolKind = enum(u32) {
    File = 1,
    Module = 2,
    Namespace = 3,
    Package = 4,
    Class = 5,
    Method = 6,
    Property = 7,
    Field = 8,
    Constructor = 9,
    Enum = 10,
    Interface = 11,
    Function = 12,
    Variable = 13,
    Constant = 14,
    String = 15,
    Number = 16,
    Boolean = 17,
    Array = 18,
    Object = 19,
    Key = 20,
    Null = 21,
    EnumMember = 22,
    Struct = 23,
    Event = 24,
    Operator = 25,
    TypeParameter = 26,
};

pub const SymbolTag = enum(u32) {
    Deprecated = 1,
};

pub const UniquenessLevel = enum([]const u8) {
    document = "document",
    project = "project",
    group = "group",
    scheme = "scheme",
    global = "global",
};

pub const MonikerKind = enum([]const u8) {
    import = "import",
    export_ = "export",
    local = "local",
};

pub const InlayHintKind = enum(u32) {
    Type = 1,
    Parameter = 2,
};

pub const MessageType = enum(u32) {
    Error = 1,
    Warning = 2,
    Info = 3,
    Log = 4,
    Debug = 5,
};

pub const TextDocumentSyncKind = enum(u32) {
    None = 0,
    Full = 1,
    Incremental = 2,
};

pub const TextDocumentSaveReason = enum(u32) {
    Manual = 1,
    AfterDelay = 2,
    FocusOut = 3,
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

pub const CompletionItemTag = enum(u32) {
    Deprecated = 1,
};

pub const InsertTextFormat = enum(u32) {
    PlainText = 1,
    Snippet = 2,
};

pub const InsertTextMode = enum(u32) {
    asIs = 1,
    adjustIndentation = 2,
};

pub const DocumentHighlightKind = enum(u32) {
    Text = 1,
    Read = 2,
    Write = 3,
};

pub const CodeActionKind = enum([]const u8) {
    Empty = "",
    QuickFix = "quickfix",
    Refactor = "refactor",
    RefactorExtract = "refactor.extract",
    RefactorInline = "refactor.inline",
    RefactorMove = "refactor.move",
    RefactorRewrite = "refactor.rewrite",
    Source = "source",
    SourceOrganizeImports = "source.organizeImports",
    SourceFixAll = "source.fixAll",
};

pub const CodeActionTag = enum(u32) {
    LLMGenerated = 1,
};

pub const TraceValue = enum([]const u8) {
    Off = "off",
    Messages = "messages",
    Verbose = "verbose",
};

pub const MarkupKind = enum([]const u8) {
    PlainText = "plaintext",
    Markdown = "markdown",
};

pub const LanguageKind = enum([]const u8) {
    ABAP = "abap",
    WindowsBat = "bat",
    BibTeX = "bibtex",
    Clojure = "clojure",
    Coffeescript = "coffeescript",
    C = "c",
    CPP = "cpp",
    CSharp = "csharp",
    CSS = "css",
    D = "d",
    Delphi = "pascal",
    Diff = "diff",
    Dart = "dart",
    Dockerfile = "dockerfile",
    Elixir = "elixir",
    Erlang = "erlang",
    FSharp = "fsharp",
    GitCommit = "git-commit",
    GitRebase = "git-rebase",
    Go = "go",
    Groovy = "groovy",
    Handlebars = "handlebars",
    Haskell = "haskell",
    HTML = "html",
    Ini = "ini",
    Java = "java",
    JavaScript = "javascript",
    JavaScriptReact = "javascriptreact",
    JSON = "json",
    LaTeX = "latex",
    Less = "less",
    Lua = "lua",
    Makefile = "makefile",
    Markdown = "markdown",
    ObjectiveC = "objective-c",
    ObjectiveCPP = "objective-cpp",
    Pascal = "pascal",
    Perl = "perl",
    Perl6 = "perl6",
    PHP = "php",
    Plaintext = "plaintext",
    Powershell = "powershell",
    Pug = "jade",
    Python = "python",
    R = "r",
    Razor = "razor",
    Ruby = "ruby",
    Rust = "rust",
    SCSS = "scss",
    SASS = "sass",
    Scala = "scala",
    ShaderLab = "shaderlab",
    ShellScript = "shellscript",
    SQL = "sql",
    Swift = "swift",
    TypeScript = "typescript",
    TypeScriptReact = "typescriptreact",
    TeX = "tex",
    VisualBasic = "vb",
    XML = "xml",
    XSL = "xsl",
    YAML = "yaml",
};

pub const InlineCompletionTriggerKind = enum(u32) {
    Invoked = 1,
    Automatic = 2,
};

pub const PositionEncodingKind = enum([]const u8) {
    UTF8 = "utf-8",
    UTF16 = "utf-16",
    UTF32 = "utf-32",
};

pub const FileChangeType = enum(u32) {
    Created = 1,
    Changed = 2,
    Deleted = 3,
};

pub const WatchKind = enum(u32) {
    Create = 1,
    Change = 2,
    Delete = 4,
};

pub const DiagnosticSeverity = enum(u32) {
    Error = 1,
    Warning = 2,
    Information = 3,
    Hint = 4,
};

pub const DiagnosticTag = enum(u32) {
    Unnecessary = 1,
    Deprecated = 2,
};

pub const CompletionTriggerKind = enum(u32) {
    Invoked = 1,
    TriggerCharacter = 2,
    TriggerForIncompleteCompletions = 3,
};

pub const ApplyKind = enum(u32) {
    Replace = 1,
    Merge = 2,
};

pub const SignatureHelpTriggerKind = enum(u32) {
    Invoked = 1,
    TriggerCharacter = 2,
    ContentChange = 3,
};

pub const CodeActionTriggerKind = enum(u32) {
    Invoked = 1,
    Automatic = 2,
};

pub const FileOperationPatternKind = enum([]const u8) {
    file = "file",
    folder = "folder",
};

pub const ResourceOperationKind = enum([]const u8) {
    Create = "create",
    Rename = "rename",
    Delete = "delete",
};

pub const FailureHandlingKind = enum([]const u8) {
    Abort = "abort",
    Transactional = "transactional",
    TextOnlyTransactional = "textOnlyTransactional",
    Undo = "undo",
};

pub const PrepareSupportDefaultBehavior = enum(u32) {
    Identifier = 1,
};

pub const TokenFormat = enum([]const u8) {
    Relative = "relative",
};

pub const LogVerbosity = enum(i32) {
    Off = 0,
    Trace = 1,
    Debug = 2,
    Info = 3,
    Warning = 4,
    Error = 5,
};

pub const VSReferenceKind = enum(i32) {
    Inactive = 0,
    Comment = 1,
    String = 2,
    Read = 3,
    Write = 4,
    Reference = 5,
    Name = 6,
    Qualified = 7,
    TypeArgument = 8,
    TypeConstraint = 9,
    BaseType = 10,
    Constructor = 11,
    Destructor = 12,
    Import = 13,
    Declaration = 14,
    AddressOf = 15,
    NotReference = 16,
    Unknown = 17,
};

pub const CodeLensKind = enum([]const u8) {
    References = "references",
    Implementations = "implementations",
};

pub const AutoImportFixKind = enum(i32) {
    UseNamespace = 0,
    JsdocTypeImport = 1,
    AddToExisting = 2,
    AddNew = 3,
    PromoteTypeOnly = 4,
};

pub const ImportKind = enum(i32) {
    Named = 0,
    Default = 1,
    Namespace = 2,
    CommonJS = 3,
};

pub const AddAsTypeOnly = enum(i32) {
    Allowed = 1,
    Required = 2,
    NotAllowed = 4,
};

pub const ClassificationTypeName = enum([]const u8) {
    Keyword = "keyword",
    Punctuation = "punctuation",
    Operator = "operator",
    WhiteSpace = "whitespace",
    Text = "text",
    String = "string",
    Number = "number",
    Comment = "comment",
    ClassName = "class name",
    InterfaceName = "interface name",
    EnumName = "enum name",
    ModuleName = "module name",
    MethodName = "method name",
    ParameterName = "parameter name",
    PropertyName = "property name",
    FieldName = "field name",
    LocalName = "local name",
    TypeParameterName = "type parameter name",
    Identifier = "identifier",
};

pub const ImplementationParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
};

pub const Location = struct {
    // @json("uri")
    uri: []const u8,
    // @json("range")
    range: Range,
};

pub const ImplementationRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("id")
    id: ?[]const u8,
};

pub const TypeDefinitionParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
};

pub const TypeDefinitionRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("id")
    id: ?[]const u8,
};

pub const WorkspaceFolder = struct {
    // @json("uri")
    uri: []const u8,
    // @json("name")
    name: []const u8,
};

pub const DidChangeWorkspaceFoldersParams = struct {
    // @json("event")
    event: WorkspaceFoldersChangeEvent,
};

pub const ConfigurationParams = struct {
    // @json("items")
    items: []ConfigurationItem,
};

pub const DocumentColorParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
};

pub const ColorInformation = struct {
    // @json("range")
    range: Range,
    // @json("color")
    color: Color,
};

pub const DocumentColorRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("id")
    id: ?[]const u8,
};

pub const ColorPresentationParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("color")
    color: Color,
    // @json("range")
    range: Range,
};

pub const ColorPresentation = struct {
    // @json("label")
    label: []const u8,
    // @json("textEdit")
    textEdit: ?TextEdit,
    // @json("additionalTextEdits")
    additionalTextEdits: ?[]TextEdit,
};

pub const WorkDoneProgressOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const TextDocumentRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
};

pub const FoldingRangeParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
};

pub const FoldingRange = struct {
    // @json("startLine")
    startLine: u32,
    // @json("startCharacter")
    startCharacter: ?u32,
    // @json("endLine")
    endLine: u32,
    // @json("endCharacter")
    endCharacter: ?u32,
    // @json("kind")
    kind: ?FoldingRangeKind,
    // @json("collapsedText")
    collapsedText: ?[]const u8,
};

pub const FoldingRangeRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("id")
    id: ?[]const u8,
};

pub const DeclarationParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
};

pub const DeclarationRegistrationOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("id")
    id: ?[]const u8,
};

pub const SelectionRangeParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("positions")
    positions: []Position,
};

pub const SelectionRange = struct {
    // @json("range")
    range: Range,
    // @json("parent")
    parent: ?SelectionRange,
};

pub const SelectionRangeRegistrationOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("id")
    id: ?[]const u8,
};

pub const WorkDoneProgressCreateParams = struct {
    // @json("token")
    token: ProgressToken,
};

pub const WorkDoneProgressCancelParams = struct {
    // @json("token")
    token: ProgressToken,
};

pub const CallHierarchyPrepareParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
};

pub const CallHierarchyItem = struct {
    // @json("name")
    name: []const u8,
    // @json("kind")
    kind: SymbolKind,
    // @json("tags")
    tags: ?[]SymbolTag,
    // @json("detail")
    detail: ?[]const u8,
    // @json("uri")
    uri: []const u8,
    // @json("range")
    range: Range,
    // @json("selectionRange")
    selectionRange: Range,
    // @json("data")
    data: ?CallHierarchyItemData,
};

pub const CallHierarchyRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("id")
    id: ?[]const u8,
};

pub const CallHierarchyIncomingCallsParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("item")
    item: CallHierarchyItem,
};

pub const CallHierarchyIncomingCall = struct {
    // @json("from")
    from: CallHierarchyItem,
    // @json("fromRanges")
    fromRanges: []Range,
};

pub const CallHierarchyOutgoingCallsParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("item")
    item: CallHierarchyItem,
};

pub const CallHierarchyOutgoingCall = struct {
    // @json("to")
    to: CallHierarchyItem,
    // @json("fromRanges")
    fromRanges: []Range,
};

pub const SemanticTokensParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
};

pub const SemanticTokens = struct {
    // @json("resultId")
    resultId: ?[]const u8,
    // @json("data")
    data: []u32,
};

pub const SemanticTokensPartialResult = struct {
    // @json("data")
    data: []u32,
};

pub const SemanticTokensRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("legend")
    legend: SemanticTokensLegend,
    // @json("range")
    range: ?std.json.Value,
    // @json("full")
    full: ?std.json.Value,
    // @json("id")
    id: ?[]const u8,
};

pub const SemanticTokensDeltaParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("previousResultId")
    previousResultId: []const u8,
};

pub const SemanticTokensDelta = struct {
    // @json("resultId")
    resultId: ?[]const u8,
    // @json("edits")
    edits: []SemanticTokensEdit,
};

pub const SemanticTokensDeltaPartialResult = struct {
    // @json("edits")
    edits: []SemanticTokensEdit,
};

pub const SemanticTokensRangeParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("range")
    range: Range,
};

pub const ShowDocumentParams = struct {
    // @json("uri")
    uri: []const u8,
    // @json("external")
    external: ?bool,
    // @json("takeFocus")
    takeFocus: ?bool,
    // @json("selection")
    selection: ?Range,
};

pub const ShowDocumentResult = struct {
    // @json("success")
    success: bool,
};

pub const LinkedEditingRangeParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
};

pub const LinkedEditingRanges = struct {
    // @json("ranges")
    ranges: []Range,
    // @json("wordPattern")
    wordPattern: ?[]const u8,
};

pub const LinkedEditingRangeRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("id")
    id: ?[]const u8,
};

pub const CreateFilesParams = struct {
    // @json("files")
    files: []FileCreate,
};

pub const WorkspaceEdit = struct {
    // @json("changes")
    changes: ?std.json.ObjectMap,
    // @json("documentChanges")
    documentChanges: ?[]std.json.Value,
    // @json("changeAnnotations")
    changeAnnotations: ?std.json.ObjectMap,
};

pub const FileOperationRegistrationOptions = struct {
    // @json("filters")
    filters: []FileOperationFilter,
};

pub const RenameFilesParams = struct {
    // @json("files")
    files: []FileRename,
};

pub const DeleteFilesParams = struct {
    // @json("files")
    files: []FileDelete,
};

pub const MonikerParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
};

pub const Moniker = struct {
    // @json("scheme")
    scheme: []const u8,
    // @json("identifier")
    identifier: []const u8,
    // @json("unique")
    unique: UniquenessLevel,
    // @json("kind")
    kind: ?MonikerKind,
};

pub const MonikerRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const TypeHierarchyPrepareParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
};

pub const TypeHierarchyItem = struct {
    // @json("name")
    name: []const u8,
    // @json("kind")
    kind: SymbolKind,
    // @json("tags")
    tags: ?[]SymbolTag,
    // @json("detail")
    detail: ?[]const u8,
    // @json("uri")
    uri: []const u8,
    // @json("range")
    range: Range,
    // @json("selectionRange")
    selectionRange: Range,
    // @json("data")
    data: ?TypeHierarchyItemData,
};

pub const TypeHierarchyRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("id")
    id: ?[]const u8,
};

pub const TypeHierarchySupertypesParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("item")
    item: TypeHierarchyItem,
};

pub const TypeHierarchySubtypesParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("item")
    item: TypeHierarchyItem,
};

pub const InlineValueParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("range")
    range: Range,
    // @json("context")
    context: InlineValueContext,
};

pub const InlineValueRegistrationOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("id")
    id: ?[]const u8,
};

pub const InlayHintParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("range")
    range: Range,
};

pub const InlayHint = struct {
    // @json("position")
    position: Position,
    // @json("label")
    label: std.json.Value,
    // @json("kind")
    kind: ?InlayHintKind,
    // @json("textEdits")
    textEdits: ?[]TextEdit,
    // @json("tooltip")
    tooltip: ?std.json.Value,
    // @json("paddingLeft")
    paddingLeft: ?bool,
    // @json("paddingRight")
    paddingRight: ?bool,
    // @json("data")
    data: ?InlayHintData,
};

pub const InlayHintRegistrationOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("resolveProvider")
    resolveProvider: ?bool,
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("id")
    id: ?[]const u8,
};

pub const DocumentDiagnosticParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("identifier")
    identifier: ?[]const u8,
    // @json("previousResultId")
    previousResultId: ?[]const u8,
};

pub const DocumentDiagnosticReportPartialResult = struct {
    // @json("relatedDocuments")
    relatedDocuments: std.json.ObjectMap,
};

pub const DiagnosticServerCancellationData = struct {
    // @json("retriggerRequest")
    retriggerRequest: bool,
};

pub const DiagnosticRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("identifier")
    identifier: ?[]const u8,
    // @json("interFileDependencies")
    interFileDependencies: bool,
    // @json("workspaceDiagnostics")
    workspaceDiagnostics: bool,
    // @json("id")
    id: ?[]const u8,
};

pub const WorkspaceDiagnosticParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("identifier")
    identifier: ?[]const u8,
    // @json("previousResultIds")
    previousResultIds: []PreviousResultId,
};

pub const WorkspaceDiagnosticReport = struct {
    // @json("items")
    items: []WorkspaceDocumentDiagnosticReport,
};

pub const WorkspaceDiagnosticReportPartialResult = struct {
    // @json("items")
    items: []WorkspaceDocumentDiagnosticReport,
};

pub const InlineCompletionParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("context")
    context: InlineCompletionContext,
};

pub const InlineCompletionList = struct {
    // @json("items")
    items: []InlineCompletionItem,
};

pub const InlineCompletionItem = struct {
    // @json("insertText")
    insertText: std.json.Value,
    // @json("filterText")
    filterText: ?[]const u8,
    // @json("range")
    range: ?Range,
    // @json("command")
    command: ?Command,
};

pub const InlineCompletionRegistrationOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("id")
    id: ?[]const u8,
};

pub const TextDocumentContentParams = struct {
    // @json("uri")
    uri: []const u8,
};

pub const TextDocumentContentResult = struct {
    // @json("text")
    text: []const u8,
};

pub const TextDocumentContentRegistrationOptions = struct {
    // @json("schemes")
    schemes: [][]const u8,
    // @json("id")
    id: ?[]const u8,
};

pub const TextDocumentContentRefreshParams = struct {
    // @json("uri")
    uri: []const u8,
};

pub const RegistrationParams = struct {
    // @json("registrations")
    registrations: []Registration,
};

pub const UnregistrationParams = struct {
    // @json("unregisterations")
    unregisterations: []Unregistration,
};

pub const InitializeParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("processId")
    processId: ?i32,
    // @json("clientInfo")
    clientInfo: ?ClientInfo,
    // @json("locale")
    locale: ?[]const u8,
    // @json("rootPath")
    rootPath: ??[]const u8,
    // @json("rootUri")
    rootUri: ?[]const u8,
    // @json("capabilities")
    capabilities: ClientCapabilities,
    // @json("initializationOptions")
    initializationOptions: ??InitializationOptions,
    // @json("trace")
    trace: ?TraceValue,
    // @json("workspaceFolders")
    workspaceFolders: ??[]WorkspaceFolder,
};

pub const InitializeResult = struct {
    // @json("capabilities")
    capabilities: ServerCapabilities,
    // @json("serverInfo")
    serverInfo: ?ServerInfo,
};

pub const InitializeError = struct {
    // @json("retry")
    retry: bool,
};

pub const InitializedParams = struct {};

pub const DidChangeConfigurationParams = struct {
    // @json("settings")
    settings: std.json.Value,
};

pub const DidChangeConfigurationRegistrationOptions = struct {
    // @json("section")
    section: ?std.json.Value,
};

pub const ShowMessageParams = struct {
    // @json("type")
    type_: MessageType,
    // @json("message")
    message: []const u8,
};

pub const ShowMessageRequestParams = struct {
    // @json("type")
    type_: MessageType,
    // @json("message")
    message: []const u8,
    // @json("actions")
    actions: ?[]MessageActionItem,
};

pub const MessageActionItem = struct {
    // @json("title")
    title: []const u8,
};

pub const LogMessageParams = struct {
    // @json("type")
    type_: MessageType,
    // @json("message")
    message: []const u8,
};

pub const DidOpenTextDocumentParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentItem,
};

pub const DidChangeTextDocumentParams = struct {
    // @json("textDocument")
    textDocument: VersionedTextDocumentIdentifier,
    // @json("contentChanges")
    contentChanges: []TextDocumentContentChangeEvent,
};

pub const TextDocumentChangeRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("syncKind")
    syncKind: TextDocumentSyncKind,
};

pub const DidCloseTextDocumentParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
};

pub const DidSaveTextDocumentParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("text")
    text: ?[]const u8,
};

pub const TextDocumentSaveRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("includeText")
    includeText: ?bool,
};

pub const WillSaveTextDocumentParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("reason")
    reason: TextDocumentSaveReason,
};

pub const TextEdit = struct {
    // @json("range")
    range: Range,
    // @json("newText")
    newText: []const u8,
};

pub const DidChangeWatchedFilesParams = struct {
    // @json("changes")
    changes: []FileEvent,
};

pub const DidChangeWatchedFilesRegistrationOptions = struct {
    // @json("watchers")
    watchers: []FileSystemWatcher,
};

pub const PublishDiagnosticsParams = struct {
    // @json("uri")
    uri: []const u8,
    // @json("version")
    version: ?i32,
    // @json("diagnostics")
    diagnostics: []Diagnostic,
};

pub const CompletionParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("context")
    context: ?CompletionContext,
};

pub const CompletionItem = struct {
    // @json("label")
    label: []const u8,
    // @json("labelDetails")
    labelDetails: ?CompletionItemLabelDetails,
    // @json("kind")
    kind: ?CompletionItemKind,
    // @json("tags")
    tags: ?[]CompletionItemTag,
    // @json("detail")
    detail: ?[]const u8,
    // @json("documentation")
    documentation: ?std.json.Value,
    // @json("deprecated")
    deprecated: ?bool,
    // @json("preselect")
    preselect: ?bool,
    // @json("sortText")
    sortText: ?[]const u8,
    // @json("filterText")
    filterText: ?[]const u8,
    // @json("insertText")
    insertText: ?[]const u8,
    // @json("insertTextFormat")
    insertTextFormat: ?InsertTextFormat,
    // @json("insertTextMode")
    insertTextMode: ?InsertTextMode,
    // @json("textEdit")
    textEdit: ?std.json.Value,
    // @json("textEditText")
    textEditText: ?[]const u8,
    // @json("additionalTextEdits")
    additionalTextEdits: ?[]TextEdit,
    // @json("commitCharacters")
    commitCharacters: ?[][]const u8,
    // @json("command")
    command: ?Command,
    // @json("data")
    data: ?CompletionItemData,
};

pub const CompletionList = struct {
    // @json("isIncomplete")
    isIncomplete: bool,
    // @json("itemDefaults")
    itemDefaults: ?CompletionItemDefaults,
    // @json("applyKind")
    applyKind: ?CompletionItemApplyKinds,
    // @json("items")
    items: []CompletionItem,
};

pub const CompletionRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("triggerCharacters")
    triggerCharacters: ?[][]const u8,
    // @json("allCommitCharacters")
    allCommitCharacters: ?[][]const u8,
    // @json("resolveProvider")
    resolveProvider: ?bool,
    // @json("completionItem")
    completionItem: ?ServerCompletionItemOptions,
};

pub const HoverParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("verbosityLevel")
    verbosityLevel: ?i32,
};

pub const Hover = struct {
    // @json("contents")
    contents: std.json.Value,
    // @json("range")
    range: ?Range,
    // @json("canIncreaseVerbosity")
    canIncreaseVerbosity: bool,
};

pub const HoverRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const SignatureHelpParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("context")
    context: ?SignatureHelpContext,
};

pub const SignatureHelp = struct {
    // @json("signatures")
    signatures: []SignatureInformation,
    // @json("activeSignature")
    activeSignature: ?u32,
    // @json("activeParameter")
    activeParameter: ??u32,
};

pub const SignatureHelpRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("triggerCharacters")
    triggerCharacters: ?[][]const u8,
    // @json("retriggerCharacters")
    retriggerCharacters: ?[][]const u8,
};

pub const DefinitionParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
};

pub const DefinitionRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const ReferenceParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("context")
    context: ReferenceContext,
};

pub const ReferenceRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const DocumentHighlightParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
};

pub const DocumentHighlight = struct {
    // @json("range")
    range: Range,
    // @json("kind")
    kind: ?DocumentHighlightKind,
};

pub const DocumentHighlightRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const DocumentSymbolParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
};

pub const SymbolInformation = struct {
    // @json("name")
    name: []const u8,
    // @json("kind")
    kind: SymbolKind,
    // @json("tags")
    tags: ?[]SymbolTag,
    // @json("containerName")
    containerName: ?[]const u8,
    // @json("deprecated")
    deprecated: ?bool,
    // @json("location")
    location: Location,
};

pub const DocumentSymbol = struct {
    // @json("name")
    name: []const u8,
    // @json("detail")
    detail: ?[]const u8,
    // @json("kind")
    kind: SymbolKind,
    // @json("tags")
    tags: ?[]SymbolTag,
    // @json("deprecated")
    deprecated: ?bool,
    // @json("range")
    range: Range,
    // @json("selectionRange")
    selectionRange: Range,
    // @json("children")
    children: ?[]DocumentSymbol,
};

pub const DocumentSymbolRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("label")
    label: ?[]const u8,
};

pub const CodeActionParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("range")
    range: Range,
    // @json("context")
    context: CodeActionContext,
};

pub const Command = struct {
    // @json("title")
    title: []const u8,
    // @json("tooltip")
    tooltip: ?[]const u8,
    // @json("command")
    command: []const u8,
    // @json("arguments")
    arguments: ?[]std.json.Value,
};

pub const CodeAction = struct {
    // @json("title")
    title: []const u8,
    // @json("kind")
    kind: ?CodeActionKind,
    // @json("diagnostics")
    diagnostics: ?[]Diagnostic,
    // @json("isPreferred")
    isPreferred: ?bool,
    // @json("disabled")
    disabled: ?CodeActionDisabled,
    // @json("edit")
    edit: ?WorkspaceEdit,
    // @json("command")
    command: ?Command,
    // @json("data")
    data: ?CodeActionData,
    // @json("tags")
    tags: ?[]CodeActionTag,
};

pub const CodeActionRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("codeActionKinds")
    codeActionKinds: ?[]CodeActionKind,
    // @json("documentation")
    documentation: ?[]CodeActionKindDocumentation,
    // @json("resolveProvider")
    resolveProvider: ?bool,
};

pub const WorkspaceSymbolParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("query")
    query: []const u8,
};

pub const WorkspaceSymbol = struct {
    // @json("name")
    name: []const u8,
    // @json("kind")
    kind: SymbolKind,
    // @json("tags")
    tags: ?[]SymbolTag,
    // @json("containerName")
    containerName: ?[]const u8,
    // @json("location")
    location: std.json.Value,
    // @json("data")
    data: ?WorkspaceSymbolData,
};

pub const WorkspaceSymbolRegistrationOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("resolveProvider")
    resolveProvider: ?bool,
};

pub const CodeLensParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
};

pub const CodeLens = struct {
    // @json("range")
    range: Range,
    // @json("command")
    command: ?Command,
    // @json("data")
    data: ?CodeLensData,
};

pub const CodeLensRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("resolveProvider")
    resolveProvider: ?bool,
};

pub const DocumentLinkParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
};

pub const DocumentLink = struct {
    // @json("range")
    range: Range,
    // @json("target")
    target: ?[]const u8,
    // @json("tooltip")
    tooltip: ?[]const u8,
    // @json("data")
    data: ?DocumentLinkData,
};

pub const DocumentLinkRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("resolveProvider")
    resolveProvider: ?bool,
};

pub const DocumentFormattingParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("options")
    options: FormattingOptions,
};

pub const DocumentFormattingRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const DocumentRangeFormattingParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("range")
    range: Range,
    // @json("options")
    options: FormattingOptions,
};

pub const DocumentRangeFormattingRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("rangesSupport")
    rangesSupport: ?bool,
};

pub const DocumentRangesFormattingParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("ranges")
    ranges: []Range,
    // @json("options")
    options: FormattingOptions,
};

pub const DocumentOnTypeFormattingParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("ch")
    ch: []const u8,
    // @json("options")
    options: FormattingOptions,
};

pub const DocumentOnTypeFormattingRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("firstTriggerCharacter")
    firstTriggerCharacter: []const u8,
    // @json("moreTriggerCharacter")
    moreTriggerCharacter: ?[][]const u8,
};

pub const RenameParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("newName")
    newName: []const u8,
};

pub const RenameRegistrationOptions = struct {
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("prepareProvider")
    prepareProvider: ?bool,
};

pub const PrepareRenameParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
};

pub const ExecuteCommandParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
    // @json("command")
    command: []const u8,
    // @json("arguments")
    arguments: ?[]std.json.Value,
};

pub const ExecuteCommandRegistrationOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("commands")
    commands: [][]const u8,
};

pub const ApplyWorkspaceEditParams = struct {
    // @json("label")
    label: ?[]const u8,
    // @json("edit")
    edit: WorkspaceEdit,
    // @json("metadata")
    metadata: ?WorkspaceEditMetadata,
};

pub const ApplyWorkspaceEditResult = struct {
    // @json("applied")
    applied: bool,
    // @json("failureReason")
    failureReason: ?[]const u8,
    // @json("failedChange")
    failedChange: ?u32,
};

pub const WorkDoneProgressBegin = struct {
    // @json("kind")
    kind: []const u8,
    // @json("title")
    title: []const u8,
    // @json("cancellable")
    cancellable: ?bool,
    // @json("message")
    message: ?[]const u8,
    // @json("percentage")
    percentage: ?u32,
};

pub const WorkDoneProgressReport = struct {
    // @json("kind")
    kind: []const u8,
    // @json("cancellable")
    cancellable: ?bool,
    // @json("message")
    message: ?[]const u8,
    // @json("percentage")
    percentage: ?u32,
};

pub const WorkDoneProgressEnd = struct {
    // @json("kind")
    kind: []const u8,
    // @json("message")
    message: ?[]const u8,
};

pub const SetTraceParams = struct {
    // @json("value")
    value: TraceValue,
};

pub const LogTraceParams = struct {
    // @json("message")
    message: []const u8,
    // @json("verbose")
    verbose: ?[]const u8,
};

pub const CancelParams = struct {
    // @json("id")
    id: std.json.Value,
};

pub const ProgressParams = struct {
    // @json("token")
    token: ProgressToken,
    // @json("value")
    value: std.json.Value,
};

pub const TextDocumentPositionParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
};

pub const WorkDoneProgressParams = struct {
    // @json("workDoneToken")
    workDoneToken: ?ProgressToken,
};

pub const PartialResultParams = struct {
    // @json("partialResultToken")
    partialResultToken: ?ProgressToken,
};

pub const LocationLink = struct {
    // @json("originSelectionRange")
    originSelectionRange: ?Range,
    // @json("targetUri")
    targetUri: []const u8,
    // @json("targetRange")
    targetRange: Range,
    // @json("targetSelectionRange")
    targetSelectionRange: Range,
};

pub const Range = struct {
    // @json("start")
    start: Position,
    // @json("end")
    end: Position,
};

pub const ImplementationOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const StaticRegistrationOptions = struct {
    // @json("id")
    id: ?[]const u8,
};

pub const TypeDefinitionOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const WorkspaceFoldersChangeEvent = struct {
    // @json("added")
    added: []WorkspaceFolder,
    // @json("removed")
    removed: []WorkspaceFolder,
};

pub const ConfigurationItem = struct {
    // @json("scopeUri")
    scopeUri: ?[]const u8,
    // @json("section")
    section: ?[]const u8,
};

pub const TextDocumentIdentifier = struct {
    // @json("uri")
    uri: []const u8,
};

pub const Color = struct {
    // @json("red")
    red: f64,
    // @json("green")
    green: f64,
    // @json("blue")
    blue: f64,
    // @json("alpha")
    alpha: f64,
};

pub const DocumentColorOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const FoldingRangeOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const DeclarationOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const Position = struct {
    // @json("line")
    line: u32,
    // @json("character")
    character: u32,
};

pub const SelectionRangeOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const CallHierarchyOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const SemanticTokensOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("legend")
    legend: SemanticTokensLegend,
    // @json("range")
    range: ?std.json.Value,
    // @json("full")
    full: ?std.json.Value,
};

pub const SemanticTokensEdit = struct {
    // @json("start")
    start: u32,
    // @json("deleteCount")
    deleteCount: u32,
    // @json("data")
    data: ?[]u32,
};

pub const LinkedEditingRangeOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const FileCreate = struct {
    // @json("uri")
    uri: []const u8,
};

pub const TextDocumentEdit = struct {
    // @json("textDocument")
    textDocument: OptionalVersionedTextDocumentIdentifier,
    // @json("edits")
    edits: []std.json.Value,
};

pub const CreateFile = struct {
    // @json("kind")
    kind: []const u8,
    // @json("annotationId")
    annotationId: ?ChangeAnnotationIdentifier,
    // @json("uri")
    uri: []const u8,
    // @json("options")
    options: ?CreateFileOptions,
};

pub const RenameFile = struct {
    // @json("kind")
    kind: []const u8,
    // @json("annotationId")
    annotationId: ?ChangeAnnotationIdentifier,
    // @json("oldUri")
    oldUri: []const u8,
    // @json("newUri")
    newUri: []const u8,
    // @json("options")
    options: ?RenameFileOptions,
};

pub const DeleteFile = struct {
    // @json("kind")
    kind: []const u8,
    // @json("annotationId")
    annotationId: ?ChangeAnnotationIdentifier,
    // @json("uri")
    uri: []const u8,
    // @json("options")
    options: ?DeleteFileOptions,
};

pub const ChangeAnnotation = struct {
    // @json("label")
    label: []const u8,
    // @json("needsConfirmation")
    needsConfirmation: ?bool,
    // @json("description")
    description: ?[]const u8,
};

pub const FileOperationFilter = struct {
    // @json("scheme")
    scheme: ?[]const u8,
    // @json("pattern")
    pattern: FileOperationPattern,
};

pub const FileRename = struct {
    // @json("oldUri")
    oldUri: []const u8,
    // @json("newUri")
    newUri: []const u8,
};

pub const FileDelete = struct {
    // @json("uri")
    uri: []const u8,
};

pub const MonikerOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const TypeHierarchyOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const InlineValueContext = struct {
    // @json("frameId")
    frameId: i32,
    // @json("stoppedLocation")
    stoppedLocation: Range,
};

pub const InlineValueText = struct {
    // @json("range")
    range: Range,
    // @json("text")
    text: []const u8,
};

pub const InlineValueVariableLookup = struct {
    // @json("range")
    range: Range,
    // @json("variableName")
    variableName: ?[]const u8,
    // @json("caseSensitiveLookup")
    caseSensitiveLookup: bool,
};

pub const InlineValueEvaluatableExpression = struct {
    // @json("range")
    range: Range,
    // @json("expression")
    expression: ?[]const u8,
};

pub const InlineValueOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const InlayHintLabelPart = struct {
    // @json("value")
    value: []const u8,
    // @json("tooltip")
    tooltip: ?std.json.Value,
    // @json("location")
    location: ?Location,
    // @json("command")
    command: ?Command,
};

pub const MarkupContent = struct {
    // @json("kind")
    kind: MarkupKind,
    // @json("value")
    value: []const u8,
};

pub const InlayHintOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("resolveProvider")
    resolveProvider: ?bool,
};

pub const RelatedFullDocumentDiagnosticReport = struct {
    // @json("kind")
    kind: []const u8,
    // @json("resultId")
    resultId: ?[]const u8,
    // @json("items")
    items: []Diagnostic,
    // @json("relatedDocuments")
    relatedDocuments: ?std.json.ObjectMap,
};

pub const RelatedUnchangedDocumentDiagnosticReport = struct {
    // @json("kind")
    kind: []const u8,
    // @json("resultId")
    resultId: []const u8,
    // @json("relatedDocuments")
    relatedDocuments: ?std.json.ObjectMap,
};

pub const FullDocumentDiagnosticReport = struct {
    // @json("kind")
    kind: []const u8,
    // @json("resultId")
    resultId: ?[]const u8,
    // @json("items")
    items: []Diagnostic,
};

pub const UnchangedDocumentDiagnosticReport = struct {
    // @json("kind")
    kind: []const u8,
    // @json("resultId")
    resultId: []const u8,
};

pub const DiagnosticOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("identifier")
    identifier: ?[]const u8,
    // @json("interFileDependencies")
    interFileDependencies: bool,
    // @json("workspaceDiagnostics")
    workspaceDiagnostics: bool,
};

pub const PreviousResultId = struct {
    // @json("uri")
    uri: []const u8,
    // @json("value")
    value: []const u8,
};

pub const TextDocumentItem = struct {
    // @json("uri")
    uri: []const u8,
    // @json("languageId")
    languageId: LanguageKind,
    // @json("version")
    version: i32,
    // @json("text")
    text: []const u8,
};

pub const InlineCompletionContext = struct {
    // @json("triggerKind")
    triggerKind: InlineCompletionTriggerKind,
    // @json("selectedCompletionInfo")
    selectedCompletionInfo: ?SelectedCompletionInfo,
};

pub const StringValue = struct {
    // @json("kind")
    kind: []const u8,
    // @json("value")
    value: []const u8,
};

pub const InlineCompletionOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const TextDocumentContentOptions = struct {
    // @json("schemes")
    schemes: [][]const u8,
};

pub const Registration = struct {
    // @json("id")
    id: []const u8,
};

pub const Unregistration = struct {
    // @json("id")
    id: []const u8,
    // @json("method")
    method: []const u8,
};

pub const WorkspaceFoldersInitializeParams = struct {
    // @json("workspaceFolders")
    workspaceFolders: ??[]WorkspaceFolder,
};

pub const ServerCapabilities = struct {
    // @json("positionEncoding")
    positionEncoding: ?PositionEncodingKind,
    // @json("textDocumentSync")
    textDocumentSync: ?std.json.Value,
    // @json("completionProvider")
    completionProvider: ?CompletionOptions,
    // @json("hoverProvider")
    hoverProvider: ?std.json.Value,
    // @json("signatureHelpProvider")
    signatureHelpProvider: ?SignatureHelpOptions,
    // @json("declarationProvider")
    declarationProvider: ?std.json.Value,
    // @json("definitionProvider")
    definitionProvider: ?std.json.Value,
    // @json("typeDefinitionProvider")
    typeDefinitionProvider: ?std.json.Value,
    // @json("implementationProvider")
    implementationProvider: ?std.json.Value,
    // @json("referencesProvider")
    referencesProvider: ?std.json.Value,
    // @json("documentHighlightProvider")
    documentHighlightProvider: ?std.json.Value,
    // @json("documentSymbolProvider")
    documentSymbolProvider: ?std.json.Value,
    // @json("codeActionProvider")
    codeActionProvider: ?std.json.Value,
    // @json("codeLensProvider")
    codeLensProvider: ?CodeLensOptions,
    // @json("documentLinkProvider")
    documentLinkProvider: ?DocumentLinkOptions,
    // @json("colorProvider")
    colorProvider: ?std.json.Value,
    // @json("workspaceSymbolProvider")
    workspaceSymbolProvider: ?std.json.Value,
    // @json("documentFormattingProvider")
    documentFormattingProvider: ?std.json.Value,
    // @json("documentRangeFormattingProvider")
    documentRangeFormattingProvider: ?std.json.Value,
    // @json("documentOnTypeFormattingProvider")
    documentOnTypeFormattingProvider: ?DocumentOnTypeFormattingOptions,
    // @json("renameProvider")
    renameProvider: ?std.json.Value,
    // @json("foldingRangeProvider")
    foldingRangeProvider: ?std.json.Value,
    // @json("selectionRangeProvider")
    selectionRangeProvider: ?std.json.Value,
    // @json("executeCommandProvider")
    executeCommandProvider: ?ExecuteCommandOptions,
    // @json("callHierarchyProvider")
    callHierarchyProvider: ?std.json.Value,
    // @json("linkedEditingRangeProvider")
    linkedEditingRangeProvider: ?std.json.Value,
    // @json("semanticTokensProvider")
    semanticTokensProvider: ?std.json.Value,
    // @json("monikerProvider")
    monikerProvider: ?std.json.Value,
    // @json("typeHierarchyProvider")
    typeHierarchyProvider: ?std.json.Value,
    // @json("inlineValueProvider")
    inlineValueProvider: ?std.json.Value,
    // @json("inlayHintProvider")
    inlayHintProvider: ?std.json.Value,
    // @json("diagnosticProvider")
    diagnosticProvider: ?std.json.Value,
    // @json("inlineCompletionProvider")
    inlineCompletionProvider: ?std.json.Value,
    // @json("workspace")
    workspace: ?WorkspaceOptions,
    // @json("experimental")
    experimental: ?ExperimentalServerCapabilities,
    // @json("_vs_onAutoInsertProvider")
    _vs_onAutoInsertProvider: ?VSOnAutoInsertOptions,
    // @json("_vs_referencesProvider")
    _vs_referencesProvider: ?bool,
};

pub const ServerInfo = struct {
    // @json("name")
    name: []const u8,
    // @json("version")
    version: ?[]const u8,
};

pub const VersionedTextDocumentIdentifier = struct {
    // @json("uri")
    uri: []const u8,
    // @json("version")
    version: i32,
};

pub const SaveOptions = struct {
    // @json("includeText")
    includeText: ?bool,
};

pub const FileEvent = struct {
    // @json("uri")
    uri: []const u8,
    // @json("type")
    type_: FileChangeType,
};

pub const FileSystemWatcher = struct {
    // @json("globPattern")
    globPattern: GlobPattern,
    // @json("kind")
    kind: ?WatchKind,
};

pub const Diagnostic = struct {
    // @json("range")
    range: Range,
    // @json("severity")
    severity: ?DiagnosticSeverity,
    // @json("code")
    code: ?std.json.Value,
    // @json("codeDescription")
    codeDescription: ?CodeDescription,
    // @json("source")
    source: ?[]const u8,
    // @json("message")
    message: std.json.Value,
    // @json("tags")
    tags: ?[]DiagnosticTag,
    // @json("relatedInformation")
    relatedInformation: ?[]DiagnosticRelatedInformation,
    // @json("data")
    data: ?DiagnosticData,
};

pub const CompletionContext = struct {
    // @json("triggerKind")
    triggerKind: CompletionTriggerKind,
    // @json("triggerCharacter")
    triggerCharacter: ?[]const u8,
};

pub const CompletionItemLabelDetails = struct {
    // @json("detail")
    detail: ?[]const u8,
    // @json("description")
    description: ?[]const u8,
};

pub const InsertReplaceEdit = struct {
    // @json("newText")
    newText: []const u8,
    // @json("insert")
    insert: Range,
    // @json("replace")
    replace: Range,
};

pub const CompletionItemDefaults = struct {
    // @json("commitCharacters")
    commitCharacters: ?[][]const u8,
    // @json("editRange")
    editRange: ?std.json.Value,
    // @json("insertTextFormat")
    insertTextFormat: ?InsertTextFormat,
    // @json("insertTextMode")
    insertTextMode: ?InsertTextMode,
    // @json("data")
    data: ?CompletionItemDefaultsData,
};

pub const CompletionItemApplyKinds = struct {
    // @json("commitCharacters")
    commitCharacters: ?ApplyKind,
    // @json("data")
    data: ?ApplyKind,
};

pub const CompletionOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("triggerCharacters")
    triggerCharacters: ?[][]const u8,
    // @json("allCommitCharacters")
    allCommitCharacters: ?[][]const u8,
    // @json("resolveProvider")
    resolveProvider: ?bool,
    // @json("completionItem")
    completionItem: ?ServerCompletionItemOptions,
};

pub const HoverOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const SignatureHelpContext = struct {
    // @json("triggerKind")
    triggerKind: SignatureHelpTriggerKind,
    // @json("triggerCharacter")
    triggerCharacter: ?[]const u8,
    // @json("isRetrigger")
    isRetrigger: bool,
    // @json("activeSignatureHelp")
    activeSignatureHelp: ?SignatureHelp,
};

pub const SignatureInformation = struct {
    // @json("label")
    label: []const u8,
    // @json("documentation")
    documentation: ?std.json.Value,
    // @json("parameters")
    parameters: ?[]ParameterInformation,
    // @json("activeParameter")
    activeParameter: ??u32,
    // @json("_vs_colorizedLabel")
    _vs_colorizedLabel: ?VSClassifiedTextElement,
};

pub const SignatureHelpOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("triggerCharacters")
    triggerCharacters: ?[][]const u8,
    // @json("retriggerCharacters")
    retriggerCharacters: ?[][]const u8,
};

pub const DefinitionOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const ReferenceContext = struct {
    // @json("includeDeclaration")
    includeDeclaration: bool,
};

pub const ReferenceOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const DocumentHighlightOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const BaseSymbolInformation = struct {
    // @json("name")
    name: []const u8,
    // @json("kind")
    kind: SymbolKind,
    // @json("tags")
    tags: ?[]SymbolTag,
    // @json("containerName")
    containerName: ?[]const u8,
};

pub const DocumentSymbolOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("label")
    label: ?[]const u8,
};

pub const CodeActionContext = struct {
    // @json("diagnostics")
    diagnostics: []Diagnostic,
    // @json("only")
    only: ?[]CodeActionKind,
    // @json("triggerKind")
    triggerKind: ?CodeActionTriggerKind,
};

pub const CodeActionDisabled = struct {
    // @json("reason")
    reason: []const u8,
};

pub const CodeActionOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("codeActionKinds")
    codeActionKinds: ?[]CodeActionKind,
    // @json("documentation")
    documentation: ?[]CodeActionKindDocumentation,
    // @json("resolveProvider")
    resolveProvider: ?bool,
};

pub const LocationUriOnly = struct {
    // @json("uri")
    uri: []const u8,
};

pub const WorkspaceSymbolOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("resolveProvider")
    resolveProvider: ?bool,
};

pub const CodeLensOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("resolveProvider")
    resolveProvider: ?bool,
};

pub const DocumentLinkOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("resolveProvider")
    resolveProvider: ?bool,
};

pub const FormattingOptions = struct {
    // @json("tabSize")
    tabSize: u32,
    // @json("insertSpaces")
    insertSpaces: bool,
    // @json("trimTrailingWhitespace")
    trimTrailingWhitespace: ?bool,
    // @json("insertFinalNewline")
    insertFinalNewline: ?bool,
    // @json("trimFinalNewlines")
    trimFinalNewlines: ?bool,
};

pub const DocumentFormattingOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
};

pub const DocumentRangeFormattingOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("rangesSupport")
    rangesSupport: ?bool,
};

pub const DocumentOnTypeFormattingOptions = struct {
    // @json("firstTriggerCharacter")
    firstTriggerCharacter: []const u8,
    // @json("moreTriggerCharacter")
    moreTriggerCharacter: ?[][]const u8,
};

pub const RenameOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("prepareProvider")
    prepareProvider: ?bool,
};

pub const PrepareRenamePlaceholder = struct {
    // @json("range")
    range: Range,
    // @json("placeholder")
    placeholder: []const u8,
};

pub const PrepareRenameDefaultBehavior = struct {
    // @json("defaultBehavior")
    defaultBehavior: bool,
};

pub const ExecuteCommandOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("commands")
    commands: [][]const u8,
};

pub const WorkspaceEditMetadata = struct {
    // @json("isRefactoring")
    isRefactoring: ?bool,
};

pub const SemanticTokensLegend = struct {
    // @json("tokenTypes")
    tokenTypes: [][]const u8,
    // @json("tokenModifiers")
    tokenModifiers: [][]const u8,
};

pub const SemanticTokensFullDelta = struct {
    // @json("delta")
    delta: ?bool,
};

pub const OptionalVersionedTextDocumentIdentifier = struct {
    // @json("uri")
    uri: []const u8,
    // @json("version")
    version: ?i32,
};

pub const AnnotatedTextEdit = struct {
    // @json("range")
    range: Range,
    // @json("newText")
    newText: []const u8,
    // @json("annotationId")
    annotationId: ChangeAnnotationIdentifier,
};

pub const SnippetTextEdit = struct {
    // @json("range")
    range: Range,
    // @json("snippet")
    snippet: StringValue,
    // @json("annotationId")
    annotationId: ?ChangeAnnotationIdentifier,
};

pub const ResourceOperation = struct {
    // @json("kind")
    kind: []const u8,
    // @json("annotationId")
    annotationId: ?ChangeAnnotationIdentifier,
};

pub const CreateFileOptions = struct {
    // @json("overwrite")
    overwrite: ?bool,
    // @json("ignoreIfExists")
    ignoreIfExists: ?bool,
};

pub const RenameFileOptions = struct {
    // @json("overwrite")
    overwrite: ?bool,
    // @json("ignoreIfExists")
    ignoreIfExists: ?bool,
};

pub const DeleteFileOptions = struct {
    // @json("recursive")
    recursive: ?bool,
    // @json("ignoreIfNotExists")
    ignoreIfNotExists: ?bool,
};

pub const FileOperationPattern = struct {
    // @json("glob")
    glob: []const u8,
    // @json("matches")
    matches: ?FileOperationPatternKind,
    // @json("options")
    options: ?FileOperationPatternOptions,
};

pub const WorkspaceFullDocumentDiagnosticReport = struct {
    // @json("kind")
    kind: []const u8,
    // @json("resultId")
    resultId: ?[]const u8,
    // @json("items")
    items: []Diagnostic,
    // @json("uri")
    uri: []const u8,
    // @json("version")
    version: ?i32,
};

pub const WorkspaceUnchangedDocumentDiagnosticReport = struct {
    // @json("kind")
    kind: []const u8,
    // @json("resultId")
    resultId: []const u8,
    // @json("uri")
    uri: []const u8,
    // @json("version")
    version: ?i32,
};

pub const SelectedCompletionInfo = struct {
    // @json("range")
    range: Range,
    // @json("text")
    text: []const u8,
};

pub const ClientInfo = struct {
    // @json("name")
    name: []const u8,
    // @json("version")
    version: ?[]const u8,
};

pub const ClientCapabilities = struct {
    // @json("workspace")
    workspace: ?WorkspaceClientCapabilities,
    // @json("textDocument")
    textDocument: ?TextDocumentClientCapabilities,
    // @json("window")
    window: ?WindowClientCapabilities,
    // @json("general")
    general: ?GeneralClientCapabilities,
    // @json("experimental")
    experimental: ?ExperimentalClientCapabilities,
    // @json("_vs_supportsVisualStudioExtensions")
    _vs_supportsVisualStudioExtensions: ?bool,
    // @json("_vs_supportedSnippetVersion")
    _vs_supportedSnippetVersion: ?i32,
    // @json("_vs_supportsNotIncludingTextInTextDocumentDidOpen")
    _vs_supportsNotIncludingTextInTextDocumentDidOpen: ?bool,
    // @json("_vs_supportsIconExtensions")
    _vs_supportsIconExtensions: ?bool,
    // @json("_vs_supportsDiagnosticRequests")
    _vs_supportsDiagnosticRequests: ?bool,
};

pub const TextDocumentSyncOptions = struct {
    // @json("openClose")
    openClose: ?bool,
    // @json("change")
    change: ?TextDocumentSyncKind,
    // @json("willSave")
    willSave: ?bool,
    // @json("willSaveWaitUntil")
    willSaveWaitUntil: ?bool,
    // @json("save")
    save: ?std.json.Value,
};

pub const WorkspaceOptions = struct {
    // @json("workspaceFolders")
    workspaceFolders: ?WorkspaceFoldersServerCapabilities,
    // @json("fileOperations")
    fileOperations: ?FileOperationOptions,
    // @json("textDocumentContent")
    textDocumentContent: ?std.json.Value,
};

pub const TextDocumentContentChangePartial = struct {
    // @json("range")
    range: Range,
    // @json("rangeLength")
    rangeLength: ?u32,
    // @json("text")
    text: []const u8,
};

pub const TextDocumentContentChangeWholeDocument = struct {
    // @json("text")
    text: []const u8,
};

pub const CodeDescription = struct {
    // @json("href")
    href: []const u8,
};

pub const DiagnosticRelatedInformation = struct {
    // @json("location")
    location: Location,
    // @json("message")
    message: []const u8,
};

pub const EditRangeWithInsertReplace = struct {
    // @json("insert")
    insert: Range,
    // @json("replace")
    replace: Range,
};

pub const ServerCompletionItemOptions = struct {
    // @json("labelDetailsSupport")
    labelDetailsSupport: ?bool,
};

pub const MarkedStringWithLanguage = struct {
    // @json("language")
    language: []const u8,
    // @json("value")
    value: []const u8,
};

pub const ParameterInformation = struct {
    // @json("label")
    label: std.json.Value,
    // @json("documentation")
    documentation: ?std.json.Value,
};

pub const CodeActionKindDocumentation = struct {
    // @json("kind")
    kind: CodeActionKind,
    // @json("command")
    command: Command,
};

pub const FileOperationPatternOptions = struct {
    // @json("ignoreCase")
    ignoreCase: ?bool,
};

pub const WorkspaceClientCapabilities = struct {
    // @json("applyEdit")
    applyEdit: ?bool,
    // @json("workspaceEdit")
    workspaceEdit: ?WorkspaceEditClientCapabilities,
    // @json("didChangeConfiguration")
    didChangeConfiguration: ?DidChangeConfigurationClientCapabilities,
    // @json("didChangeWatchedFiles")
    didChangeWatchedFiles: ?DidChangeWatchedFilesClientCapabilities,
    // @json("symbol")
    symbol: ?WorkspaceSymbolClientCapabilities,
    // @json("executeCommand")
    executeCommand: ?ExecuteCommandClientCapabilities,
    // @json("workspaceFolders")
    workspaceFolders: ?bool,
    // @json("configuration")
    configuration: ?bool,
    // @json("semanticTokens")
    semanticTokens: ?SemanticTokensWorkspaceClientCapabilities,
    // @json("codeLens")
    codeLens: ?CodeLensWorkspaceClientCapabilities,
    // @json("fileOperations")
    fileOperations: ?FileOperationClientCapabilities,
    // @json("inlineValue")
    inlineValue: ?InlineValueWorkspaceClientCapabilities,
    // @json("inlayHint")
    inlayHint: ?InlayHintWorkspaceClientCapabilities,
    // @json("diagnostics")
    diagnostics: ?DiagnosticWorkspaceClientCapabilities,
    // @json("foldingRange")
    foldingRange: ?FoldingRangeWorkspaceClientCapabilities,
    // @json("textDocumentContent")
    textDocumentContent: ?TextDocumentContentClientCapabilities,
};

pub const TextDocumentClientCapabilities = struct {
    // @json("synchronization")
    synchronization: ?TextDocumentSyncClientCapabilities,
    // @json("filters")
    filters: ?TextDocumentFilterClientCapabilities,
    // @json("completion")
    completion: ?CompletionClientCapabilities,
    // @json("hover")
    hover: ?HoverClientCapabilities,
    // @json("signatureHelp")
    signatureHelp: ?SignatureHelpClientCapabilities,
    // @json("declaration")
    declaration: ?DeclarationClientCapabilities,
    // @json("definition")
    definition: ?DefinitionClientCapabilities,
    // @json("typeDefinition")
    typeDefinition: ?TypeDefinitionClientCapabilities,
    // @json("implementation")
    implementation: ?ImplementationClientCapabilities,
    // @json("references")
    references: ?ReferenceClientCapabilities,
    // @json("documentHighlight")
    documentHighlight: ?DocumentHighlightClientCapabilities,
    // @json("documentSymbol")
    documentSymbol: ?DocumentSymbolClientCapabilities,
    // @json("codeAction")
    codeAction: ?CodeActionClientCapabilities,
    // @json("codeLens")
    codeLens: ?CodeLensClientCapabilities,
    // @json("documentLink")
    documentLink: ?DocumentLinkClientCapabilities,
    // @json("colorProvider")
    colorProvider: ?DocumentColorClientCapabilities,
    // @json("formatting")
    formatting: ?DocumentFormattingClientCapabilities,
    // @json("rangeFormatting")
    rangeFormatting: ?DocumentRangeFormattingClientCapabilities,
    // @json("onTypeFormatting")
    onTypeFormatting: ?DocumentOnTypeFormattingClientCapabilities,
    // @json("rename")
    rename: ?RenameClientCapabilities,
    // @json("foldingRange")
    foldingRange: ?FoldingRangeClientCapabilities,
    // @json("selectionRange")
    selectionRange: ?SelectionRangeClientCapabilities,
    // @json("publishDiagnostics")
    publishDiagnostics: ?PublishDiagnosticsClientCapabilities,
    // @json("callHierarchy")
    callHierarchy: ?CallHierarchyClientCapabilities,
    // @json("semanticTokens")
    semanticTokens: ?SemanticTokensClientCapabilities,
    // @json("linkedEditingRange")
    linkedEditingRange: ?LinkedEditingRangeClientCapabilities,
    // @json("moniker")
    moniker: ?MonikerClientCapabilities,
    // @json("typeHierarchy")
    typeHierarchy: ?TypeHierarchyClientCapabilities,
    // @json("inlineValue")
    inlineValue: ?InlineValueClientCapabilities,
    // @json("inlayHint")
    inlayHint: ?InlayHintClientCapabilities,
    // @json("diagnostic")
    diagnostic: ?DiagnosticClientCapabilities,
    // @json("inlineCompletion")
    inlineCompletion: ?InlineCompletionClientCapabilities,
};

pub const WindowClientCapabilities = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("showMessage")
    showMessage: ?ShowMessageRequestClientCapabilities,
    // @json("showDocument")
    showDocument: ?ShowDocumentClientCapabilities,
};

pub const GeneralClientCapabilities = struct {
    // @json("staleRequestSupport")
    staleRequestSupport: ?StaleRequestSupportOptions,
    // @json("regularExpressions")
    regularExpressions: ?RegularExpressionsClientCapabilities,
    // @json("markdown")
    markdown: ?MarkdownClientCapabilities,
    // @json("positionEncodings")
    positionEncodings: ?[]PositionEncodingKind,
};

pub const WorkspaceFoldersServerCapabilities = struct {
    // @json("supported")
    supported: ?bool,
    // @json("changeNotifications")
    changeNotifications: ?std.json.Value,
};

pub const FileOperationOptions = struct {
    // @json("didCreate")
    didCreate: ?FileOperationRegistrationOptions,
    // @json("willCreate")
    willCreate: ?FileOperationRegistrationOptions,
    // @json("didRename")
    didRename: ?FileOperationRegistrationOptions,
    // @json("willRename")
    willRename: ?FileOperationRegistrationOptions,
    // @json("didDelete")
    didDelete: ?FileOperationRegistrationOptions,
    // @json("willDelete")
    willDelete: ?FileOperationRegistrationOptions,
};

pub const RelativePattern = struct {
    // @json("baseUri")
    baseUri: std.json.Value,
    // @json("pattern")
    pattern: Pattern,
};

pub const TextDocumentFilterLanguage = struct {
    // @json("language")
    language: []const u8,
    // @json("scheme")
    scheme: ?[]const u8,
    // @json("pattern")
    pattern: ?GlobPattern,
};

pub const TextDocumentFilterScheme = struct {
    // @json("language")
    language: ?[]const u8,
    // @json("scheme")
    scheme: []const u8,
    // @json("pattern")
    pattern: ?GlobPattern,
};

pub const TextDocumentFilterPattern = struct {
    // @json("language")
    language: ?[]const u8,
    // @json("scheme")
    scheme: ?[]const u8,
    // @json("pattern")
    pattern: GlobPattern,
};

pub const WorkspaceEditClientCapabilities = struct {
    // @json("documentChanges")
    documentChanges: ?bool,
    // @json("resourceOperations")
    resourceOperations: ?[]ResourceOperationKind,
    // @json("failureHandling")
    failureHandling: ?FailureHandlingKind,
    // @json("normalizesLineEndings")
    normalizesLineEndings: ?bool,
    // @json("changeAnnotationSupport")
    changeAnnotationSupport: ?ChangeAnnotationsSupportOptions,
    // @json("metadataSupport")
    metadataSupport: ?bool,
    // @json("snippetEditSupport")
    snippetEditSupport: ?bool,
};

pub const DidChangeConfigurationClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
};

pub const DidChangeWatchedFilesClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("relativePatternSupport")
    relativePatternSupport: ?bool,
};

pub const WorkspaceSymbolClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("symbolKind")
    symbolKind: ?ClientSymbolKindOptions,
    // @json("tagSupport")
    tagSupport: ?ClientSymbolTagOptions,
    // @json("resolveSupport")
    resolveSupport: ?ClientSymbolResolveOptions,
};

pub const ExecuteCommandClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
};

pub const SemanticTokensWorkspaceClientCapabilities = struct {
    // @json("refreshSupport")
    refreshSupport: ?bool,
};

pub const CodeLensWorkspaceClientCapabilities = struct {
    // @json("refreshSupport")
    refreshSupport: ?bool,
};

pub const FileOperationClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("didCreate")
    didCreate: ?bool,
    // @json("willCreate")
    willCreate: ?bool,
    // @json("didRename")
    didRename: ?bool,
    // @json("willRename")
    willRename: ?bool,
    // @json("didDelete")
    didDelete: ?bool,
    // @json("willDelete")
    willDelete: ?bool,
};

pub const InlineValueWorkspaceClientCapabilities = struct {
    // @json("refreshSupport")
    refreshSupport: ?bool,
};

pub const InlayHintWorkspaceClientCapabilities = struct {
    // @json("refreshSupport")
    refreshSupport: ?bool,
};

pub const DiagnosticWorkspaceClientCapabilities = struct {
    // @json("refreshSupport")
    refreshSupport: ?bool,
};

pub const FoldingRangeWorkspaceClientCapabilities = struct {
    // @json("refreshSupport")
    refreshSupport: ?bool,
};

pub const TextDocumentContentClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
};

pub const TextDocumentSyncClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("willSave")
    willSave: ?bool,
    // @json("willSaveWaitUntil")
    willSaveWaitUntil: ?bool,
    // @json("didSave")
    didSave: ?bool,
};

pub const TextDocumentFilterClientCapabilities = struct {
    // @json("relativePatternSupport")
    relativePatternSupport: ?bool,
};

pub const CompletionClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("completionItem")
    completionItem: ?ClientCompletionItemOptions,
    // @json("completionItemKind")
    completionItemKind: ?ClientCompletionItemOptionsKind,
    // @json("insertTextMode")
    insertTextMode: ?InsertTextMode,
    // @json("contextSupport")
    contextSupport: ?bool,
    // @json("completionList")
    completionList: ?CompletionListCapabilities,
};

pub const HoverClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("contentFormat")
    contentFormat: ?[]MarkupKind,
};

pub const SignatureHelpClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("signatureInformation")
    signatureInformation: ?ClientSignatureInformationOptions,
    // @json("contextSupport")
    contextSupport: ?bool,
};

pub const DeclarationClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("linkSupport")
    linkSupport: ?bool,
};

pub const DefinitionClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("linkSupport")
    linkSupport: ?bool,
};

pub const TypeDefinitionClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("linkSupport")
    linkSupport: ?bool,
};

pub const ImplementationClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("linkSupport")
    linkSupport: ?bool,
};

pub const ReferenceClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
};

pub const DocumentHighlightClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
};

pub const DocumentSymbolClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("symbolKind")
    symbolKind: ?ClientSymbolKindOptions,
    // @json("hierarchicalDocumentSymbolSupport")
    hierarchicalDocumentSymbolSupport: ?bool,
    // @json("tagSupport")
    tagSupport: ?ClientSymbolTagOptions,
    // @json("labelSupport")
    labelSupport: ?bool,
};

pub const CodeActionClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("codeActionLiteralSupport")
    codeActionLiteralSupport: ?ClientCodeActionLiteralOptions,
    // @json("isPreferredSupport")
    isPreferredSupport: ?bool,
    // @json("disabledSupport")
    disabledSupport: ?bool,
    // @json("dataSupport")
    dataSupport: ?bool,
    // @json("resolveSupport")
    resolveSupport: ?ClientCodeActionResolveOptions,
    // @json("honorsChangeAnnotations")
    honorsChangeAnnotations: ?bool,
    // @json("documentationSupport")
    documentationSupport: ?bool,
    // @json("tagSupport")
    tagSupport: ?CodeActionTagOptions,
};

pub const CodeLensClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("resolveSupport")
    resolveSupport: ?ClientCodeLensResolveOptions,
};

pub const DocumentLinkClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("tooltipSupport")
    tooltipSupport: ?bool,
};

pub const DocumentColorClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
};

pub const DocumentFormattingClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
};

pub const DocumentRangeFormattingClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("rangesSupport")
    rangesSupport: ?bool,
};

pub const DocumentOnTypeFormattingClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
};

pub const RenameClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("prepareSupport")
    prepareSupport: ?bool,
    // @json("prepareSupportDefaultBehavior")
    prepareSupportDefaultBehavior: ?PrepareSupportDefaultBehavior,
    // @json("honorsChangeAnnotations")
    honorsChangeAnnotations: ?bool,
};

pub const FoldingRangeClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("rangeLimit")
    rangeLimit: ?u32,
    // @json("lineFoldingOnly")
    lineFoldingOnly: ?bool,
    // @json("foldingRangeKind")
    foldingRangeKind: ?ClientFoldingRangeKindOptions,
    // @json("foldingRange")
    foldingRange: ?ClientFoldingRangeOptions,
};

pub const SelectionRangeClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
};

pub const PublishDiagnosticsClientCapabilities = struct {
    // @json("relatedInformation")
    relatedInformation: ?bool,
    // @json("tagSupport")
    tagSupport: ?ClientDiagnosticsTagOptions,
    // @json("codeDescriptionSupport")
    codeDescriptionSupport: ?bool,
    // @json("dataSupport")
    dataSupport: ?bool,
    // @json("versionSupport")
    versionSupport: ?bool,
};

pub const CallHierarchyClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
};

pub const SemanticTokensClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("requests")
    requests: ClientSemanticTokensRequestOptions,
    // @json("tokenTypes")
    tokenTypes: [][]const u8,
    // @json("tokenModifiers")
    tokenModifiers: [][]const u8,
    // @json("formats")
    formats: []TokenFormat,
    // @json("overlappingTokenSupport")
    overlappingTokenSupport: ?bool,
    // @json("multilineTokenSupport")
    multilineTokenSupport: ?bool,
    // @json("serverCancelSupport")
    serverCancelSupport: ?bool,
    // @json("augmentsSyntaxTokens")
    augmentsSyntaxTokens: ?bool,
};

pub const LinkedEditingRangeClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
};

pub const MonikerClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
};

pub const TypeHierarchyClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
};

pub const InlineValueClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
};

pub const InlayHintClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("resolveSupport")
    resolveSupport: ?ClientInlayHintResolveOptions,
};

pub const DiagnosticClientCapabilities = struct {
    // @json("relatedInformation")
    relatedInformation: ?bool,
    // @json("tagSupport")
    tagSupport: ?ClientDiagnosticsTagOptions,
    // @json("codeDescriptionSupport")
    codeDescriptionSupport: ?bool,
    // @json("dataSupport")
    dataSupport: ?bool,
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
    // @json("relatedDocumentSupport")
    relatedDocumentSupport: ?bool,
    // @json("markupMessageSupport")
    markupMessageSupport: ?bool,
};

pub const InlineCompletionClientCapabilities = struct {
    // @json("dynamicRegistration")
    dynamicRegistration: ?bool,
};

pub const ShowMessageRequestClientCapabilities = struct {
    // @json("messageActionItem")
    messageActionItem: ?ClientShowMessageActionItemOptions,
};

pub const ShowDocumentClientCapabilities = struct {
    // @json("support")
    support: bool,
};

pub const StaleRequestSupportOptions = struct {
    // @json("cancel")
    cancel: bool,
    // @json("retryOnContentModified")
    retryOnContentModified: [][]const u8,
};

pub const RegularExpressionsClientCapabilities = struct {
    // @json("engine")
    engine: RegularExpressionEngineKind,
    // @json("version")
    version: ?[]const u8,
};

pub const MarkdownClientCapabilities = struct {
    // @json("parser")
    parser: []const u8,
    // @json("version")
    version: ?[]const u8,
    // @json("allowedTags")
    allowedTags: ?[][]const u8,
};

pub const ChangeAnnotationsSupportOptions = struct {
    // @json("groupsOnLabel")
    groupsOnLabel: ?bool,
};

pub const ClientSymbolKindOptions = struct {
    // @json("valueSet")
    valueSet: ?[]SymbolKind,
};

pub const ClientSymbolTagOptions = struct {
    // @json("valueSet")
    valueSet: []SymbolTag,
};

pub const ClientSymbolResolveOptions = struct {
    // @json("properties")
    properties: [][]const u8,
};

pub const ClientCompletionItemOptions = struct {
    // @json("snippetSupport")
    snippetSupport: ?bool,
    // @json("commitCharactersSupport")
    commitCharactersSupport: ?bool,
    // @json("documentationFormat")
    documentationFormat: ?[]MarkupKind,
    // @json("deprecatedSupport")
    deprecatedSupport: ?bool,
    // @json("preselectSupport")
    preselectSupport: ?bool,
    // @json("tagSupport")
    tagSupport: ?CompletionItemTagOptions,
    // @json("insertReplaceSupport")
    insertReplaceSupport: ?bool,
    // @json("resolveSupport")
    resolveSupport: ?ClientCompletionItemResolveOptions,
    // @json("insertTextModeSupport")
    insertTextModeSupport: ?ClientCompletionItemInsertTextModeOptions,
    // @json("labelDetailsSupport")
    labelDetailsSupport: ?bool,
};

pub const ClientCompletionItemOptionsKind = struct {
    // @json("valueSet")
    valueSet: ?[]CompletionItemKind,
};

pub const CompletionListCapabilities = struct {
    // @json("itemDefaults")
    itemDefaults: ?[][]const u8,
    // @json("applyKindSupport")
    applyKindSupport: ?bool,
};

pub const ClientSignatureInformationOptions = struct {
    // @json("documentationFormat")
    documentationFormat: ?[]MarkupKind,
    // @json("parameterInformation")
    parameterInformation: ?ClientSignatureParameterInformationOptions,
    // @json("activeParameterSupport")
    activeParameterSupport: ?bool,
    // @json("noActiveParameterSupport")
    noActiveParameterSupport: ?bool,
};

pub const ClientCodeActionLiteralOptions = struct {
    // @json("codeActionKind")
    codeActionKind: ClientCodeActionKindOptions,
};

pub const ClientCodeActionResolveOptions = struct {
    // @json("properties")
    properties: [][]const u8,
};

pub const CodeActionTagOptions = struct {
    // @json("valueSet")
    valueSet: []CodeActionTag,
};

pub const ClientCodeLensResolveOptions = struct {
    // @json("properties")
    properties: [][]const u8,
};

pub const ClientFoldingRangeKindOptions = struct {
    // @json("valueSet")
    valueSet: ?[]FoldingRangeKind,
};

pub const ClientFoldingRangeOptions = struct {
    // @json("collapsedText")
    collapsedText: ?bool,
};

pub const DiagnosticsCapabilities = struct {
    // @json("relatedInformation")
    relatedInformation: ?bool,
    // @json("tagSupport")
    tagSupport: ?ClientDiagnosticsTagOptions,
    // @json("codeDescriptionSupport")
    codeDescriptionSupport: ?bool,
    // @json("dataSupport")
    dataSupport: ?bool,
};

pub const ClientSemanticTokensRequestOptions = struct {
    // @json("range")
    range: ?std.json.Value,
    // @json("full")
    full: ?std.json.Value,
};

pub const ClientInlayHintResolveOptions = struct {
    // @json("properties")
    properties: [][]const u8,
};

pub const ClientShowMessageActionItemOptions = struct {
    // @json("additionalPropertiesSupport")
    additionalPropertiesSupport: ?bool,
};

pub const CompletionItemTagOptions = struct {
    // @json("valueSet")
    valueSet: []CompletionItemTag,
};

pub const ClientCompletionItemResolveOptions = struct {
    // @json("properties")
    properties: [][]const u8,
};

pub const ClientCompletionItemInsertTextModeOptions = struct {
    // @json("valueSet")
    valueSet: []InsertTextMode,
};

pub const ClientSignatureParameterInformationOptions = struct {
    // @json("labelOffsetSupport")
    labelOffsetSupport: ?bool,
};

pub const ClientCodeActionKindOptions = struct {
    // @json("valueSet")
    valueSet: []CodeActionKind,
};

pub const ClientDiagnosticsTagOptions = struct {
    // @json("valueSet")
    valueSet: []DiagnosticTag,
};

pub const ClientSemanticTokensRequestFullDelta = struct {
    // @json("delta")
    delta: ?bool,
};

pub const InitializationOptions = struct {
    // @json("disablePushDiagnostics")
    disablePushDiagnostics: ?bool,
    // @json("codeLensShowLocationsCommandName")
    codeLensShowLocationsCommandName: ?[]const u8,
    // @json("userPreferences")
    userPreferences: ?std.json.Value,
    // @json("enableTelemetry")
    enableTelemetry: ?bool,
    // @json("logVerbosity")
    logVerbosity: ?LogVerbosity,
};

pub const AutoImportFix = struct {
    // @json("kind")
    kind: AutoImportFixKind,
    // @json("name")
    name: []const u8,
    // @json("importKind")
    importKind: ImportKind,
    // @json("useRequire")
    useRequire: bool,
    // @json("addAsTypeOnly")
    addAsTypeOnly: AddAsTypeOnly,
    // @json("moduleSpecifier")
    moduleSpecifier: []const u8,
    // @json("importIndex")
    importIndex: i32,
    // @json("usagePosition")
    usagePosition: ?Position,
    // @json("namespacePrefix")
    namespacePrefix: []const u8,
};

pub const CompletionItemData = struct {
    // @json("fileName")
    fileName: []const u8,
    // @json("position")
    position: i32,
    // @json("source")
    source: []const u8,
    // @json("name")
    name: []const u8,
    // @json("autoImport")
    autoImport: ?AutoImportFix,
};

pub const CodeLensData = struct {
    // @json("kind")
    kind: CodeLensKind,
    // @json("uri")
    uri: []const u8,
};

pub const ExperimentalServerCapabilities = struct {
    // @json("customSourceDefinitionProvider")
    customSourceDefinitionProvider: ?bool,
    // @json("customMultiDocumentHighlightProvider")
    customMultiDocumentHighlightProvider: ?bool,
};

pub const ExperimentalClientCapabilities = struct {
    // @json("hoverVerbosityLevel")
    hoverVerbosityLevel: ?bool,
};

pub const VSOnAutoInsertOptions = struct {
    // @json("_vs_triggerCharacters")
    _vs_triggerCharacters: [][]const u8,
};

pub const VSReferenceItem = struct {
    // @json("_vs_id")
    _vs_id: i32,
    // @json("_vs_definitionId")
    _vs_definitionId: ?i32,
    // @json("_vs_kind")
    _vs_kind: ?[]VSReferenceKind,
    // @json("_vs_location")
    _vs_location: Location,
    // @json("_vs_definitionText")
    _vs_definitionText: ?VSClassifiedTextElement,
    // @json("_vs_projectName")
    _vs_projectName: ?[]const u8,
    // @json("_vs_containingType")
    _vs_containingType: ?[]const u8,
};

pub const VSOnAutoInsertParams = struct {
    // @json("_vs_textDocument")
    _vs_textDocument: TextDocumentIdentifier,
    // @json("_vs_position")
    _vs_position: Position,
    // @json("_vs_ch")
    _vs_ch: []const u8,
};

pub const VSOnAutoInsertResponseItem = struct {
    // @json("_vs_textEditFormat")
    _vs_textEditFormat: InsertTextFormat,
    // @json("_vs_textEdit")
    _vs_textEdit: TextEdit,
};

pub const RequestFailureTelemetryEvent = struct {
    // @json("eventName")
    eventName: []const u8,
    // @json("telemetryPurpose")
    telemetryPurpose: []const u8,
    // @json("properties")
    properties: RequestFailureTelemetryProperties,
};

pub const RequestFailureTelemetryProperties = struct {
    // @json("errorCode")
    errorCode: []const u8,
    // @json("requestMethod")
    requestMethod: []const u8,
    // @json("stack")
    stack: []const u8,
};

pub const ProfileParams = struct {
    // @json("dir")
    dir: []const u8,
};

pub const ProfileResult = struct {
    // @json("file")
    file: []const u8,
};

pub const InitializeAPISessionParams = struct {
    // @json("pipe")
    pipe: ?[]const u8,
};

pub const InitializeAPISessionResult = struct {
    // @json("sessionId")
    sessionId: []const u8,
    // @json("pipe")
    pipe: []const u8,
};

pub const ProjectInfoParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
};

pub const ProjectInfoResult = struct {
    // @json("configFilePath")
    configFilePath: []const u8,
};

pub const SetLogVerbosityParams = struct {
    // @json("verbosity")
    verbosity: LogVerbosity,
};

pub const PerformanceStatsTelemetryEvent = struct {
    // @json("eventName")
    eventName: []const u8,
    // @json("telemetryPurpose")
    telemetryPurpose: []const u8,
    // @json("measurements")
    measurements: PerformanceStatsTelemetryMeasurements,
};

pub const PerformanceStatsTelemetryMeasurements = struct {
    // @json("openFileCount")
    openFileCount: f64,
    // @json("uptimeSeconds")
    uptimeSeconds: f64,
    // @json("projectCount")
    projectCount: f64,
    // @json("configCount")
    configCount: f64,
    // @json("cachedDiskFileCount")
    cachedDiskFileCount: f64,
    // @json("memoryUsedBytes")
    memoryUsedBytes: f64,
    // @json("goMemLimit")
    goMemLimit: f64,
    // @json("goGCPercent")
    goGCPercent: f64,
    // @json("heapGoalBytes")
    heapGoalBytes: f64,
    // @json("heapLiveBytes")
    heapLiveBytes: f64,
    // @json("heapObjectCount")
    heapObjectCount: f64,
    // @json("heapStackBytes")
    heapStackBytes: f64,
    // @json("heapReleasedBytes")
    heapReleasedBytes: f64,
    // @json("heapFreeBytes")
    heapFreeBytes: f64,
    // @json("gcScanHeapBytes")
    gcScanHeapBytes: f64,
    // @json("goMaxProcs")
    goMaxProcs: f64,
    // @json("goroutineCount")
    goroutineCount: f64,
    // @json("gcCyclesTotal")
    gcCyclesTotal: f64,
    // @json("gcCPUSeconds")
    gcCPUSeconds: f64,
    // @json("userCPUSeconds")
    userCPUSeconds: f64,
    // @json("systemMemTotal")
    systemMemTotal: f64,
    // @json("systemMemUsed")
    systemMemUsed: f64,
    // @json("autoImportProjectBucketCount")
    autoImportProjectBucketCount: f64,
    // @json("autoImportNodeModulesBucketCount")
    autoImportNodeModulesBucketCount: f64,
    // @json("autoImportUniquePackageCount")
    autoImportUniquePackageCount: f64,
    // @json("autoImportProjectExportCount")
    autoImportProjectExportCount: f64,
    // @json("autoImportNodeModulesExportCount")
    autoImportNodeModulesExportCount: f64,
    // @json("autoImportProjectFileCount")
    autoImportProjectFileCount: f64,
    // @json("autoImportNodeModulesFileCount")
    autoImportNodeModulesFileCount: f64,
    // @json("autoImportNodeModulesUnfilteredBucketCount")
    autoImportNodeModulesUnfilteredBucketCount: f64,
};

pub const ProjectInfoTelemetryEvent = struct {
    // @json("eventName")
    eventName: []const u8,
    // @json("telemetryPurpose")
    telemetryPurpose: []const u8,
    // @json("properties")
    properties: std.json.ObjectMap,
    // @json("measurements")
    measurements: ProjectInfoTelemetryMeasurements,
};

pub const ProjectInfoTelemetryMeasurements = struct {
    // @json("jsFileCount")
    jsFileCount: f64,
    // @json("jsFileSize")
    jsFileSize: f64,
    // @json("jsxFileCount")
    jsxFileCount: f64,
    // @json("jsxFileSize")
    jsxFileSize: f64,
    // @json("tsFileCount")
    tsFileCount: f64,
    // @json("tsFileSize")
    tsFileSize: f64,
    // @json("tsxFileCount")
    tsxFileCount: f64,
    // @json("tsxFileSize")
    tsxFileSize: f64,
    // @json("dtsFileCount")
    dtsFileCount: f64,
    // @json("dtsFileSize")
    dtsFileSize: f64,
};

pub const MultiDocumentHighlight = struct {
    // @json("uri")
    uri: []const u8,
    // @json("highlights")
    highlights: []DocumentHighlight,
};

pub const MultiDocumentHighlightParams = struct {
    // @json("textDocument")
    textDocument: TextDocumentIdentifier,
    // @json("position")
    position: Position,
    // @json("filesToSearch")
    filesToSearch: [][]const u8,
};

pub const VSClassifiedTextRun = struct {
    // @json("ClassificationTypeName")
    ClassificationTypeName: []const u8,
    // @json("Text")
    Text: []const u8,
    // @json("MarkerTagType")
    MarkerTagType: ?[]const u8,
    // @json("Style")
    Style: ?i32,
    // @json("_vs_type")
    _vs_type: []const u8,
};

pub const VSClassifiedTextElement = struct {
    // @json("Runs")
    Runs: []VSClassifiedTextRun,
    // @json("_vs_type")
    _vs_type: []const u8,
};

pub const CallHierarchyItemData = struct {};

pub const TypeHierarchyItemData = struct {};

pub const InlayHintData = struct {};

pub const CodeActionData = struct {};

pub const WorkspaceSymbolData = struct {};

pub const DocumentLinkData = struct {};

pub const DiagnosticData = struct {};

pub const CompletionItemDefaultsData = struct {};

pub const ColorPresentationRegistrationOptions = struct {
    // @json("workDoneProgress")
    workDoneProgress: ?bool,
    // @json("documentSelector")
    documentSelector: ?DocumentSelector,
};

pub const Definition = std.json.Value;

pub const DefinitionLink = LocationLink;

pub const LSPArray = []std.json.Value;

pub const LSPAny = std.json.Value;

pub const Declaration = std.json.Value;

pub const DeclarationLink = LocationLink;

pub const InlineValue = std.json.Value;

pub const DocumentDiagnosticReport = std.json.Value;

pub const PrepareRenameResult = std.json.Value;

pub const DocumentSelector = []DocumentFilter;

pub const ProgressToken = std.json.Value;

pub const ChangeAnnotationIdentifier = []const u8;

pub const WorkspaceDocumentDiagnosticReport = std.json.Value;

pub const TextDocumentContentChangeEvent = std.json.Value;

pub const MarkedString = std.json.Value;

pub const DocumentFilter = TextDocumentFilter;

pub const LSPObject = std.json.ObjectMap;

pub const GlobPattern = std.json.Value;

pub const TextDocumentFilter = std.json.Value;

pub const Pattern = []const u8;

pub const RegularExpressionEngineKind = []const u8;
