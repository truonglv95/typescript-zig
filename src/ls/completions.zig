
const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const autoimport = @import("autoimport/autoimport.zig");
const string_completions = @import("string_completions.zig");
const keyword_completions = @import("keyword_completions.zig");
const lsutil = @import("lsutil.zig");

pub const ErrNeedsAutoImports = error.NeedsAutoImports;

pub const CompletionItem = struct {
    lspItem: *lsproto.CompletionItem,
    symbol: u32,
};

pub const CompletionList = struct {
    isIncomplete: bool,
    itemDefaults: ?*lsproto.CompletionItemDefaults,
    applyKind: ?*lsproto.CompletionItemApplyKinds,
    items: []*CompletionItem,

    pub fn toLSP(self: *CompletionList, allocator: std.mem.Allocator) !lsproto.CompletionList {
        var items = std.ArrayListUnmanaged(lsproto.CompletionItem).empty;
        errdefer items.deinit(allocator);
        for (self.items) |item| {
            try items.append(allocator, item.lspItem.*);
        }
        return lsproto.CompletionList{
            .isIncomplete = self.isIncomplete,
            .itemDefaults = if (self.itemDefaults) |d| d.* else null,
            .applyKind = if (self.applyKind) |k| k.* else null,
            .items = try items.toOwnedSlice(allocator),
        };
    }
};

pub fn provideCompletion(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    documentURI: lsproto.DocumentUri,
    LSPPosition: lsproto.Position,
    context: ?*lsproto.CompletionContext,
) !lsproto.CompletionResponse {
    const programAndFile = ls.getProgramAndFile(documentURI);
    const file = programAndFile.file;

    var triggerCharacter: ?[]const u8 = null;
    if (context) |ctx| {
        triggerCharacter = ctx.triggerCharacter;
    }

    const script = ls.getScript(file);
    const position = ls.converters.lineAndCharacterToPosition(script, LSPPosition);

    var completionListInternal = try getCompletionsAtPosition(ls, allocator, file, position, triggerCharacter, false);

    if (completionListInternal == null) {
        return lsproto.CompletionResponse{ .CompletionItemsOrListOrNull = null };
    }

    const completionList = try ensureItemData(allocator, script.file_name, position, try completionListInternal.?.toLSP(allocator));
    return lsproto.CompletionResponse{ .CompletionItemsOrListOrNull = .{ .list = completionList } };
}

pub fn resolveCompletionItem(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    item: *lsproto.CompletionItem,
    data: *lsproto.CompletionItemData,
) !lsproto.CompletionResolveResponse {
    _ = allocator;
    _ = ls;
    _ = data;
    // STUB: Needs full 1:1 port later, keep existing logic for now
    return lsproto.CompletionResolveResponse{ .CompletionItem = item.* };
}

fn ensureItemData(allocator: std.mem.Allocator, fileName: []const u8, pos: u32, list: lsproto.CompletionList) !*lsproto.CompletionList {
    const pList = try allocator.create(lsproto.CompletionList);
    pList.* = list;
    for (pList.items) |*item| {
        if (item.data == null) {
            item.data = lsproto.CompletionItemData{
                .fileName = fileName,
                .position = pos,
                .name = item.label,
            };
        }
    }
    return pList;
}

// ---------------------------------------------------------
// NEW DATA STRUCTURES 
// ---------------------------------------------------------

pub const CompletionData = union(enum) {
    Data: CompletionDataData,
    Keyword: CompletionDataKeyword,
    JSDocTagName: void,
    JSDocTag: void,
    JSDocParameterName: CompletionDataJSDocParameterName,
};

pub const CompletionDataData = struct {
    symbols: []checker.SymbolIndex,
    autoImports: []autoimport.view.View.FixAndExport,
    completionKind: CompletionKind,
    isInSnippetScope: bool,
    propertyAccessToConvert: ast.NodeIndex, // PropertyAccessExpressionNode
    isNewIdentifierLocation: bool,
    location: ast.NodeIndex,
    keywordFilters: KeywordCompletionFilters,
    literals: []LiteralValue,
    symbolToOriginInfoMap: std.AutoHashMapUnmanaged(usize, *SymbolOriginInfo),
    symbolToSortTextMap: std.AutoHashMapUnmanaged(checker.SymbolIndex, SortText),
    recommendedCompletion: checker.SymbolIndex,
    previousToken: ast.NodeIndex,
    contextToken: ast.NodeIndex,
    jsxInitializer: JsxInitializer,
    insideJSDocTagTypeExpression: bool,
    isTypeOnlyLocation: bool,
    isJsxIdentifierExpected: bool,
    isRightOfOpenTag: bool,
    isRightOfDotOrQuestionDot: bool,
    importStatementCompletion: ?*ImportStatementCompletionInfo,
    hasUnresolvedAutoImports: bool,
    defaultCommitCharacters: [][]const u8,
};

pub const CompletionDataKeyword = struct {
    keywordCompletions: []*CompletionItem,
    isNewIdentifierLocation: bool,
};

pub const CompletionDataJSDocParameterName = struct {
    tag: ast.NodeIndex, // JSDocParameterOrPropertyTag
};

pub const ImportStatementCompletionInfo = struct {
    isKeywordOnlyCompletion: bool,
    keywordCompletion: ast.SyntaxKind,
    isNewIdentifierLocation: bool,
    isTopLevelTypeOnly: bool,
    couldBeTypeOnlyImportSpecifier: bool,
    replacementSpan: ?*lsproto.Range,
};

pub const JsxInitializer = struct {
    isInitializer: bool,
    initializer: ast.NodeIndex, // IdentifierNode
};

pub const KeywordCompletionFilters = enum {
    None,
    All,
    ClassElementKeywords,
    InterfaceElementKeywords,
    ConstructorParameterKeywords,
    FunctionLikeBodyKeywords,
    TypeAssertionKeywords,
    TypeKeywords,
    TypeKeyword,
};

pub fn keywordFiltersFromSyntaxKind(keywordCompletion: ast.SyntaxKind) KeywordCompletionFilters {
    switch (keywordCompletion) {
        .TypeKeyword => return .TypeKeyword,
        else => @panic("Unknown mapping from ast.SyntaxKind to KeywordCompletionFilters"),
    }
}

pub const CompletionKind = enum {
    None,
    ObjectPropertyDeclaration,
    Global,
    PropertyAccess,
    MemberLike,
    String,
};

pub const TriggerCharacters = [_][]const u8{ ".", "\"", "'", "`", "/", "@", "<", "#", " ", "*" };
pub const allCommitCharacters = [_][]const u8{ ".", ",", ";" };
pub const noCommaCommitCharacters = [_][]const u8{ ".", ";" };
pub const emptyCommitCharacters = [_][]const u8{};

pub const SortText = enum {
    LocalDeclarationPriority,
    LocationPriority,
    OptionalMember,
    MemberDeclaredBySpreadAssignment,
    SuggestedClassMembers,
    GlobalsOrKeywords,
    AutoImportSuggestions,
    ClassMemberSnippets,
    JavascriptIdentifiers,

    pub fn asString(self: SortText) []const u8 {
        switch (self) {
            .LocalDeclarationPriority => return "10",
            .LocationPriority => return "11",
            .OptionalMember => return "12",
            .MemberDeclaredBySpreadAssignment => return "13",
            .SuggestedClassMembers => return "14",
            .GlobalsOrKeywords => return "15",
            .AutoImportSuggestions => return "16",
            .ClassMemberSnippets => return "17",
            .JavascriptIdentifiers => return "18",
        }
    }
};

pub fn deprecateSortText(allocator: std.mem.Allocator, original: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "z{s}", .{original});
}

pub fn sortBelow(allocator: std.mem.Allocator, original: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}1", .{original});
}

pub const SymbolOriginInfoKind = enum {
    ThisType,
    SymbolMember,
    Promise,
    Nullable,
    TypeOnlyAlias,
    ObjectLiteralMethod,
    Ignore,
    ComputedPropertyName,
};

pub const SymbolOriginInfo = struct {
    kind: SymbolOriginInfoKind,
    isDefaultExport: bool,
    isFromPackageJson: bool,
    fileName: []const u8,
    data: SymbolOriginInfoData,
};

pub const SymbolOriginInfoData = union(enum) {
    None: void,
    ObjectLiteralMethod: *SymbolOriginInfoObjectLiteralMethod,
    TypeOnlyAlias: *SymbolOriginInfoTypeOnlyAlias,
    ComputedPropertyName: *SymbolOriginInfoComputedPropertyName,
};

pub const SymbolOriginInfoObjectLiteralMethod = struct {
    insertText: []const u8,
    labelDetails: ?*lsproto.CompletionItemLabelDetails,
    isSnippet: bool,
};

pub const SymbolOriginInfoTypeOnlyAlias = struct {
    declaration: ast.NodeIndex, // TypeOnlyImportDeclaration
};

pub const SymbolOriginInfoComputedPropertyName = struct {
    symbolName: []const u8,
};

pub const CompletionSource = enum {
    ThisProperty,
    ClassMemberSnippet,
    TypeOnlyAlias,
    ObjectLiteralMethodSnippet,
    SwitchCases,
    ObjectLiteralMemberWithComma,
};

pub const LiteralValue = union(enum) {
    String: []const u8,
    Number: f64,
    PseudoBigInt: void,
};

pub const GlobalsSearch = enum {
    Continue,
    Success,
    Fail,
};

// ---------------------------------------------------------
// CORE 1:1 PORT FUNCTIONS
// ---------------------------------------------------------

pub fn getCompletionsAtPosition(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    file: compiler.FileId,
    position: u32,
    triggerCharacter: ?[]const u8,
    includeSymbols: bool,
) !?*CompletionList {
    const tokens = getRelevantTokens(ls, position, file);
    const previousToken = tokens.previousToken;
    
    if (triggerCharacter != null) {
        if (!isInString(ls, file, position, previousToken) and !isValidTrigger(ls, file, triggerCharacter.?, previousToken, position)) {
            return null;
        }
    }

    if (triggerCharacter != null and std.mem.eql(u8, triggerCharacter.?, " ")) {
        if (ls.userPreferences().includeCompletionsForImportStatements == .True) {
            const list = try allocator.create(CompletionList);
            list.* = .{
                .isIncomplete = true,
                .itemDefaults = null,
                .applyKind = null,
                .items = &[_]*CompletionItem{},
            };
            return list;
        }
        return null;
    }

    if (getJSDocSnippetCompletion(ls, allocator, file, position)) |jsDocSnippetCompletion| {
        return jsDocSnippetCompletion;
    }

    const compilerOptions = ls.getProgram().opts;

    const chk = ls.getTypeCheckerForFile(file);

    if (try getStringLiteralCompletions(ls, allocator, file, position, previousToken, chk, &compilerOptions, includeSymbols)) |stringCompletions| {
        return stringCompletions;
    }

    const tree = ls.getAst(file);
    if (previousToken != 0) {
        const pKind = tree.getNodeKind(previousToken);
        if (pKind == .BreakKeyword or pKind == .ContinueKeyword or pKind == .Identifier) {
            const parent = tree.getNodeParent(previousToken);
            const parentKind = tree.getNodeKind(parent);
            if (parentKind == .BreakStatement or parentKind == .ContinueStatement) {
                return getLabelCompletionsAtPosition(
                    ls,
                    allocator,
                    parent,
                    file,
                    position,
                    getOptionalReplacementSpan(ls, previousToken, file),
                );
            }
        }
    }

    const preferences = ls.userPreferences();
    const data = try getCompletionData(ls, allocator, chk, file, position, preferences, false);
    if (data == null) {
        return null;
    }

    switch (data.?) {
        .Data => |d| {
            const optionalReplacementSpan = getOptionalReplacementSpan(ls, d.location, file);
            return completionInfoFromData(
                ls,
                allocator,
                chk,
                file,
                &compilerOptions,
                d,
                position,
                optionalReplacementSpan,
                includeSymbols,
            );
        },
        .Keyword => |d| {
            const optionalReplacementSpan = getOptionalReplacementSpan(ls, previousToken, file);
            return specificKeywordCompletionInfo(
                ls,
                allocator,
                position,
                file,
                d.keywordCompletions,
                d.isNewIdentifierLocation,
                optionalReplacementSpan,
            );
        },
        .JSDocTagName => {
            var items = std.ArrayList(*CompletionItem).empty;
            return jsDocCompletionInfo(ls, allocator, position, file, try items.toOwnedSlice(allocator));
        },
        .JSDocTag => {
            var items = std.ArrayList(*CompletionItem).empty;
            return jsDocCompletionInfo(ls, allocator, position, file, try items.toOwnedSlice(allocator));
        },
        .JSDocParameterName => |d| {
            var items = std.ArrayList(*CompletionItem).empty;
            _ = d;
            return jsDocCompletionInfo(ls, allocator, position, file, try items.toOwnedSlice(allocator));
        },
    }
}

pub fn getCompletionData(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    typeChecker: *checker.Checker,
    file: compiler.FileId,
    position: u32,
    preferences: lsutil.UserPreferences,
    forItemResolve: bool,
) !?CompletionData {
    _ = allocator;
    // STUB: Just return null for now to keep build passing and allow iterative porting.
    _ = ls;
    _ = typeChecker;
    _ = file;
    _ = position;
    _ = preferences;
    _ = forItemResolve;
    return null;
}

// ---------------------------------------------------------
// STUBS FOR DEPENDENCIES
// ---------------------------------------------------------

pub const RelevantTokens = struct {
    contextToken: ast.NodeIndex,
    previousToken: ast.NodeIndex,
};

pub fn getRelevantTokens(ls: *languageservice.LanguageService, position: u32, file: compiler.FileId) RelevantTokens {
    _ = ls;
    _ = position;
    _ = file;
    _ = ls;
    _ = position;
    _ = file;
    return .{ .contextToken = 0, .previousToken = 0 };
}

pub fn isInString(ls: *languageservice.LanguageService, file: compiler.FileId, position: u32, previousToken: ast.NodeIndex) bool {
    _ = ls;
    _ = file;
    _ = position;
    _ = previousToken;
    _ = ls;
    _ = file;
    _ = position;
    _ = previousToken;
    return false;
}

pub fn isValidTrigger(ls: *languageservice.LanguageService, file: compiler.FileId, triggerCharacter: []const u8, contextToken: ast.NodeIndex, position: u32) bool {
    _ = ls;
    _ = file;
    _ = triggerCharacter;
    _ = contextToken;
    _ = position;
    _ = ls;
    _ = file;
    _ = triggerCharacter;
    _ = contextToken;
    _ = position;
    return true;
}

pub fn getJSDocSnippetCompletion(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, file: compiler.FileId, position: u32) ?*CompletionList {
    _ = allocator;
    _ = ls;
    _ = file;
    _ = position;
    _ = ls;
    _ = file;
    _ = position;
    return null;
}

pub fn getStringLiteralCompletions(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    file: compiler.FileId,
    position: u32,
    previousToken: ast.NodeIndex,
    chk: *checker.Checker,
    compilerOptions: *const compiler.ProgramOptions,
    includeSymbols: bool,
) !?*CompletionList {
    _ = allocator;
    _ = ls;
    _ = file;
    _ = position;
    _ = previousToken;
    _ = chk;
    _ = compilerOptions;
    _ = includeSymbols;
    return null;
}

pub fn getLabelCompletionsAtPosition(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    node: ast.NodeIndex,
    file: compiler.FileId,
    position: u32,
    optionalReplacementSpan: ?*lsproto.Range,
) *CompletionList {
    _ = allocator;
    _ = ls;
    _ = node;
    _ = file;
    _ = position;
    _ = optionalReplacementSpan;
    return undefined; // STUB
}

pub fn getOptionalReplacementSpan(ls: *languageservice.LanguageService, node: ast.NodeIndex, file: compiler.FileId) ?*lsproto.Range {
    _ = ls;
    _ = node;
    _ = file;
    _ = ls;
    _ = node;
    _ = file;
    return null;
}

pub fn completionInfoFromData(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    typeChecker: *checker.Checker,
    file: compiler.FileId,
    compilerOptions: *const compiler.ProgramOptions,
    data: CompletionDataData,
    position: u32,
    optionalReplacementSpan: ?*lsproto.Range,
    includeSymbols: bool,
) !*CompletionList {
    _ = allocator;
    _ = ls;
    _ = typeChecker;
    _ = file;
    _ = compilerOptions;
    _ = data;
    _ = position;
    _ = optionalReplacementSpan;
    _ = includeSymbols;
    return undefined; // STUB
}

pub fn specificKeywordCompletionInfo(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    position: u32,
    file: compiler.FileId,
    keywordCompletions: []*CompletionItem,
    isNewIdentifierLocation: bool,
    optionalReplacementSpan: ?*lsproto.Range,
) *CompletionList {
    _ = allocator;
    _ = ls;
    _ = position;
    _ = file;
    _ = keywordCompletions;
    _ = isNewIdentifierLocation;
    _ = optionalReplacementSpan;
    return undefined; // STUB
}

pub fn jsDocCompletionInfo(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    position: u32,
    file: compiler.FileId,
    items: []*CompletionItem,
) *CompletionList {
    _ = allocator;
    _ = ls;
    _ = position;
    _ = file;
    _ = items;
    return undefined; // STUB
}

// ---------------------------------------------------------
// UTILS
// ---------------------------------------------------------

pub fn symbolToCompletionItemKind(flags: u32) lsproto.CompletionItemKind {
    const SymbolFlags = @import("../ast/symbol.zig").SymbolFlags;
    if (flags & SymbolFlags.Function != 0) return .Function;
    if (flags & SymbolFlags.Class != 0) return .Class;
    if (flags & SymbolFlags.Interface != 0) return .Interface;
    if (flags & SymbolFlags.TypeAlias != 0) return .Struct;
    if (flags & SymbolFlags.RegularEnum != 0 or flags & SymbolFlags.ConstEnum != 0) return .Enum;
    if (flags & SymbolFlags.EnumMember != 0) return .EnumMember;
    if (flags & SymbolFlags.Module != 0) return .Module;
    if (flags & SymbolFlags.Method != 0) return .Method;
    if (flags & SymbolFlags.Property != 0 or flags & SymbolFlags.GetAccessor != 0 or flags & SymbolFlags.SetAccessor != 0) return .Property;
    if (flags & SymbolFlags.TypeParameter != 0) return .TypeParameter;
    if (flags & SymbolFlags.Constructor != 0) return .Constructor;
    if (flags & SymbolFlags.BlockScopedVariable != 0 or flags & SymbolFlags.FunctionScopedVariable != 0) return .Variable;
    return .Variable;
}

// --- AUTO-GENERATED STUBS FOR ALL REMAINING FUNCTIONS ---

// STUB: func (l *LanguageService) GetCompletionsAtPosition(ctx context.Context, file *ast.SourceFile, position int, triggerCharacter *string, includeSymbols bool) (*CompletionList, error)
pub fn GetCompletionsAtPosition(ls: *languageservice.LanguageService, ctx: void, file: ?*compiler.FileId, position: u32, triggerCharacter: ?*[]const u8, includeSymbols: bool) ?**CompletionList {
    _ = ls;
    _ = ctx;
    _ = file;
    _ = position;
    _ = triggerCharacter;
    _ = includeSymbols;
    return null;
}

// STUB: func DeprecateSortText(original SortText) SortText
pub fn DeprecateSortText(original: SortText) SortText {
    _ = original;
    return undefined;
}

// STUB: func (origin *symbolOriginInfo) symbolName() string
pub fn symbolName(origin: *SymbolOriginInfo) []const u8 {
    _ = origin;
    return undefined;
}

// STUB: func (s *symbolOriginInfo) asObjectLiteralMethod() *SymbolOriginInfoObjectLiteralMethod
pub fn asObjectLiteralMethod() ?*SymbolOriginInfoObjectLiteralMethod {
    return null;
}

// STUB: func (l *CompletionList) toLSP() *lsproto.CompletionList
pub fn toLSP(list: *CompletionList) ?*lsproto.CompletionList {
    _ = list;
    return null;
}


// STUB: func getDefaultCommitCharacters(isNewIdentifierLocation bool) []string
pub fn getDefaultCommitCharacters(isNewIdentifierLocation: bool) []const []const u8 {
    _ = isNewIdentifierLocation;
    return undefined;
}

// STUB: func isRecommendedCompletionMatch(localSymbol *ast.Symbol, recommendedCompletion *ast.Symbol, typeChecker *checker.Checker) bool
pub fn isRecommendedCompletionMatch(localSymbol: ?*checker.SymbolIndex, recommendedCompletion: ?*checker.SymbolIndex, typeChecker: ?**checker.Checker) bool {
    _ = localSymbol;
    _ = recommendedCompletion;
    _ = typeChecker;
    return false;
}

// STUB: func getWordLengthAndStart(sourceFile *ast.SourceFile, position int) (wordLength int, wordStart rune)
pub fn getWordLengthAndStart(sourceFile: ?*compiler.FileId, position: u32) u32 {
    _ = sourceFile;
    _ = position;
    return 0;
}

// STUB: func trimElementAccess(text string) string
pub fn trimElementAccess(text: []const u8) []const u8 {
    _ = text;
    return undefined;
}

// STUB: func getDotAccessor(file *ast.SourceFile, position int) string
pub fn getDotAccessor(file: ?*compiler.FileId, position: u32) []const u8 {
    _ = file;
    _ = position;
    return undefined;
}

// STUB: func strPtrIsEmpty(ptr *string) bool
pub fn strPtrIsEmpty(ptr: ?*[]const u8) bool {
    _ = ptr;
    return false;
}

// STUB: func strPtrTo(v string) *string
pub fn strPtrTo(v: []const u8) ?*[]const u8 {
    _ = v;
    return null;
}

// STUB: func boolToPtr(v bool) *bool
pub fn boolToPtr(v: bool) ?*bool {
    _ = v;
    return null;
}

// STUB: func getLineOfPosition(file *ast.SourceFile, pos int) int
pub fn getLineOfPosition(file: ?*compiler.FileId, pos: u32) u32 {
    _ = file;
    _ = pos;
    return 0;
}

// STUB: func getLineEndOfPosition(file *ast.SourceFile, pos int) int
pub fn getLineEndOfPosition(file: ?*compiler.FileId, pos: u32) u32 {
    _ = file;
    _ = pos;
    return 0;
}

// STUB: func isClassLikeMemberCompletion(symbol *ast.Symbol, location *ast.Node, file *ast.SourceFile) bool
pub fn isClassLikeMemberCompletion(symbol: ?*checker.SymbolIndex, location: ?*ast.NodeIndex, file: ?*compiler.FileId) bool {
    _ = symbol;
    _ = location;
    _ = file;
    return false;
}

// STUB: func symbolAppearsToBeTypeOnly(symbol *ast.Symbol, typeChecker *checker.Checker) bool
pub fn symbolAppearsToBeTypeOnly(symbol: ?*checker.SymbolIndex, typeChecker: ?**checker.Checker) bool {
    _ = symbol;
    _ = typeChecker;
    return false;
}

// STUB: func originIsIgnore(origin *symbolOriginInfo) bool
pub fn originIsIgnore(origin: *SymbolOriginInfo) bool {
    _ = origin;
    _ = origin;
    return false;
}

// STUB: func originIncludesSymbolName(origin *symbolOriginInfo) bool
pub fn originIncludesSymbolName(origin: *SymbolOriginInfo) bool {
    _ = origin;
    _ = origin;
    return false;
}

// STUB: func originIsComputedPropertyName(origin *symbolOriginInfo) bool
pub fn originIsComputedPropertyName(origin: *SymbolOriginInfo) bool {
    _ = origin;
    _ = origin;
    return false;
}

// STUB: func originIsObjectLiteralMethod(origin *symbolOriginInfo) bool
pub fn originIsObjectLiteralMethod(origin: *SymbolOriginInfo) bool {
    _ = origin;
    _ = origin;
    return false;
}

// STUB: func originIsThisTypeNode(origin *symbolOriginInfo) bool
pub fn originIsThisTypeNode(origin: *SymbolOriginInfo) bool {
    _ = origin;
    _ = origin;
    return false;
}

// STUB: func originIsTypeOnlyAlias(origin *symbolOriginInfo) bool
pub fn originIsTypeOnlyAlias(origin: *SymbolOriginInfo) bool {
    _ = origin;
    _ = origin;
    return false;
}

// STUB: func originIsSymbolMember(origin *symbolOriginInfo) bool
pub fn originIsSymbolMember(origin: *SymbolOriginInfo) bool {
    _ = origin;
    _ = origin;
    return false;
}

// STUB: func originIsNullableMember(origin *symbolOriginInfo) bool
pub fn originIsNullableMember(origin: *SymbolOriginInfo) bool {
    _ = origin;
    _ = origin;
    return false;
}

// STUB: func originIsPromise(origin *symbolOriginInfo) bool
pub fn originIsPromise(origin: *SymbolOriginInfo) bool {
    _ = origin;
    _ = origin;
    return false;
}

// STUB: func getSourceFromOrigin(origin *symbolOriginInfo) string
pub fn getSourceFromOrigin(origin: *SymbolOriginInfo) []const u8 {
    _ = origin;
    _ = origin;
    return undefined;
}

// STUB: func isStringLiteralOrTemplate(node *ast.Node) bool
pub fn isStringLiteralOrTemplate(node: ?*ast.NodeIndex) bool {
    _ = node;
    return false;
}

// STUB: func binaryExpressionMayBeOpenTag(binaryExpression *ast.BinaryExpression) bool
pub fn binaryExpressionMayBeOpenTag(binaryExpression: ?*ast.BinaryExpression) bool {
    _ = binaryExpression;
    return false;
}

// STUB: func isCheckedFile(file *ast.SourceFile, compilerOptions *core.CompilerOptions) bool
pub fn isCheckedFile(file: ?*compiler.FileId, compilerOptions: ?*const compiler.ProgramOptions) bool {
    _ = file;
    _ = compilerOptions;
    return false;
}

// STUB: func isContextTokenValueLocation(contextToken *ast.Node) bool
pub fn isContextTokenValueLocation(contextToken: ?*ast.NodeIndex) bool {
    _ = contextToken;
    return false;
}

// STUB: func isPossiblyTypeArgumentPosition(token *ast.Node, sourceFile *ast.SourceFile, typeChecker *checker.Checker) bool
pub fn isPossiblyTypeArgumentPosition(token: ?*ast.NodeIndex, sourceFile: ?*compiler.FileId, typeChecker: ?**checker.Checker) bool {
    _ = token;
    _ = sourceFile;
    _ = typeChecker;
    return false;
}

// STUB: func isContextTokenTypeLocation(contextToken *ast.Node) bool
pub fn isContextTokenTypeLocation(contextToken: ?*ast.NodeIndex) bool {
    _ = contextToken;
    return false;
}

// STUB: func symbolCanBeReferencedAtTypeLocation(symbol *ast.Symbol, typeChecker *checker.Checker, seenModules void) bool
pub fn symbolCanBeReferencedAtTypeLocation(symbol: ?*checker.SymbolIndex, typeChecker: ?**checker.Checker, seenModules: void) bool {
    _ = symbol;
    _ = typeChecker;
    _ = seenModules;
    return false;
}

// STUB: func nonAliasCanBeReferencedAtTypeLocation(symbol *ast.Symbol, typeChecker *checker.Checker, seenModules void) bool
pub fn nonAliasCanBeReferencedAtTypeLocation(symbol: ?*checker.SymbolIndex, typeChecker: ?**checker.Checker, seenModules: void) bool {
    _ = symbol;
    _ = typeChecker;
    _ = seenModules;
    return false;
}

// STUB: func getPropertiesForCompletion(t *checker.Type, typeChecker *checker.Checker) []*ast.Symbol
pub fn getPropertiesForCompletion(t: ?*checker.Type, typeChecker: ?**checker.Checker) []const ?*checker.SymbolIndex {
    _ = t;
    _ = typeChecker;
    return undefined;
}

// STUB: func getLeftMostName(e *ast.Expression) *ast.IdentifierNode
pub fn getLeftMostName(e: ?*ast.Expression) ?*ast.IdentifierNode {
    _ = e;
    return null;
}

// STUB: func getFirstSymbolInChain(symbol *ast.Symbol, enclosingDeclaration *ast.Node, typeChecker *checker.Checker) *ast.Symbol
pub fn getFirstSymbolInChain(symbol: ?*checker.SymbolIndex, enclosingDeclaration: ?*ast.NodeIndex, typeChecker: ?**checker.Checker) ?*checker.SymbolIndex {
    _ = symbol;
    _ = enclosingDeclaration;
    _ = typeChecker;
    return null;
}

// STUB: func isModuleSymbol(symbol *ast.Symbol) bool
pub fn isModuleSymbol(symbol: ?*checker.SymbolIndex) bool {
    _ = symbol;
    return false;
}

// STUB: func getNullableSymbolOriginInfoKind(kind SymbolOriginInfoKind, insertQuestionDot bool) SymbolOriginInfoKind
pub fn getNullableSymbolOriginInfoKind(kind: SymbolOriginInfoKind, insertQuestionDot: bool) SymbolOriginInfoKind {
    _ = kind;
    _ = insertQuestionDot;
    return undefined;
}

// STUB: func isStaticProperty(symbol *ast.Symbol) bool
pub fn isStaticProperty(symbol: ?*checker.SymbolIndex) bool {
    _ = symbol;
    return false;
}

// STUB: func getContextualTypeForConditionalExpression(conditionalExpr *ast.Node, position int, file *ast.SourceFile, typeChecker *checker.Checker) *checker.Type
pub fn getContextualTypeForConditionalExpression(conditionalExpr: ?*ast.NodeIndex, position: u32, file: ?*compiler.FileId, typeChecker: ?**checker.Checker) ?*checker.Type {
    _ = conditionalExpr;
    _ = position;
    _ = file;
    _ = typeChecker;
    return null;
}

// STUB: func getContextualType(previousToken *ast.Node, position int, file *ast.SourceFile, typeChecker *checker.Checker) *checker.Type
pub fn getContextualType(previousToken: ?*ast.NodeIndex, position: u32, file: ?*compiler.FileId, typeChecker: ?**checker.Checker) ?*checker.Type {
    _ = previousToken;
    _ = position;
    _ = file;
    _ = typeChecker;
    return null;
}

// STUB: func getSwitchedType(caseClause *ast.CaseOrDefaultClauseNode, typeChecker *checker.Checker) *checker.Type
pub fn getSwitchedType(caseClause: ?*ast.CaseOrDefaultClauseNode, typeChecker: ?**checker.Checker) ?*checker.Type {
    _ = caseClause;
    _ = typeChecker;
    return null;
}

// STUB: func isEqualityOperatorKind(kind ast.Kind) bool
pub fn isEqualityOperatorKind(kind: ast.Kind) bool {
    _ = kind;
    return false;
}

// STUB: func isLiteral(t *checker.Type) bool
pub fn isLiteral(t: ?*checker.Type) bool {
    _ = t;
    return false;
}

// STUB: func getRecommendedCompletion(previousToken *ast.Node, contextualType *checker.Type, typeChecker *checker.Checker) *ast.Symbol
pub fn getRecommendedCompletion(previousToken: ?*ast.NodeIndex, contextualType: ?*checker.Type, typeChecker: ?**checker.Checker) ?*checker.SymbolIndex {
    _ = previousToken;
    _ = contextualType;
    _ = typeChecker;
    return null;
}

// STUB: func isAbstractConstructorSymbol(symbol *ast.Symbol) bool
pub fn isAbstractConstructorSymbol(symbol: ?*checker.SymbolIndex) bool {
    _ = symbol;
    return false;
}

// STUB: func startsWithQuote(s string) bool
pub fn startsWithQuote(s: []const u8) bool {
    _ = s;
    return false;
}

// STUB: func getClosestSymbolDeclaration(contextToken *ast.Node, location *ast.Node) *ast.Declaration
pub fn getClosestSymbolDeclaration(contextToken: ?*ast.NodeIndex, location: ?*ast.NodeIndex) ?*ast.Declaration {
    _ = contextToken;
    _ = location;
    return null;
}

// STUB: func isArrowFunctionBody(node *ast.Node) bool
pub fn isArrowFunctionBody(node: ?*ast.NodeIndex) bool {
    _ = node;
    return false;
}

// STUB: func isInTypeParameterDefault(contextToken *ast.Node) bool
pub fn isInTypeParameterDefault(contextToken: ?*ast.NodeIndex) bool {
    _ = contextToken;
    return false;
}

// STUB: func isDeprecated(symbol *ast.Symbol, typeChecker *checker.Checker) bool
pub fn isDeprecated(symbol: ?*checker.SymbolIndex, typeChecker: ?**checker.Checker) bool {
    _ = symbol;
    _ = typeChecker;
    return false;
}

// STUB: func (l *LanguageService) getReplacementRangeForContextToken(file *ast.SourceFile, contextToken *ast.Node, position int) *lsproto.Range
pub fn getReplacementRangeForContextToken(ls: *languageservice.LanguageService, file: ?*compiler.FileId, contextToken: ?*ast.NodeIndex, position: u32) ?**lsproto.Range {
    _ = ls;
    _ = file;
    _ = contextToken;
    _ = position;
    return null;
}

// STUB: func (l *LanguageService) createRangeFromStringLiteralLikeContent(file *ast.SourceFile, node *ast.StringLiteralLike, position int) *lsproto.Range
pub fn createRangeFromStringLiteralLikeContent(ls: *languageservice.LanguageService, file: ?*compiler.FileId, node: ?*ast.StringLiteralLike, position: u32) ?**lsproto.Range {
    _ = ls;
    _ = file;
    _ = node;
    _ = position;
    return null;
}

// STUB: func quotePropertyName(file *ast.SourceFile, preferences lsutil.UserPreferences, name string) string
pub fn quotePropertyName(file: ?*compiler.FileId, preferences: lsutil.UserPreferences, name: []const u8) []const u8 {
    _ = file;
    _ = preferences;
    _ = name;
    return undefined;
}

// STUB: func isStringAndEmptyAnonymousObjectIntersection(typeChecker *checker.Checker, t *checker.Type) bool
pub fn isStringAndEmptyAnonymousObjectIntersection(typeChecker: ?**checker.Checker, t: ?*checker.Type) bool {
    _ = typeChecker;
    _ = t;
    return false;
}

// STUB: func areIntersectedTypesAvoidingStringReduction(typeChecker *checker.Checker, t1 *checker.Type, t2 *checker.Type) bool
pub fn areIntersectedTypesAvoidingStringReduction(typeChecker: ?**checker.Checker, t1: ?*checker.Type, t2: ?*checker.Type) bool {
    _ = typeChecker;
    _ = t1;
    _ = t2;
    return false;
}

// STUB: func escapeSnippetText(text string) string
pub fn escapeSnippetText(text: []const u8) []const u8 {
    _ = text;
    return undefined;
}

// STUB: func isNamedImportsOrExports(node *ast.Node) bool
pub fn isNamedImportsOrExports(node: ?*ast.NodeIndex) bool {
    _ = node;
    return false;
}

// STUB: func generateIdentifierForArbitraryString(text string) string
pub fn generateIdentifierForArbitraryString(text: []const u8) []const u8 {
    _ = text;
    return undefined;
}

// STUB: func getCompletionsSymbolKind(kind lsutil.ScriptElementKind) lsproto.CompletionItemKind
pub fn getCompletionsSymbolKind(kind: lsutil.ScriptElementKind) lsproto.CompletionItemKind {
    _ = kind;
    return undefined;
}

// STUB: func CompareCompletionEntries(a, b *lsproto.CompletionItem) int
pub fn CompareCompletionEntries(arg0: void, b: ?*lsproto.CompletionItem) u32 {
    _ = arg0;
    _ = b;
    return 0;
}

// STUB: func cloneItems(items []*lsproto.CompletionItem) []*CompletionItem
pub fn cloneItems(items: []const ?*lsproto.CompletionItem) []const ?**CompletionItem {
    _ = items;
    return undefined;
}

// STUB: func getKeywordCompletions(keywordFilter KeywordCompletionFilters, filterOutTsOnlyKeywords bool) []*CompletionItem
pub fn getKeywordCompletions(keywordFilter: KeywordCompletionFilters, filterOutTsOnlyKeywords: bool) []const ?**CompletionItem {
    _ = keywordFilter;
    _ = filterOutTsOnlyKeywords;
    return undefined;
}

// STUB: func getTypescriptKeywordCompletions(keywordFilter KeywordCompletionFilters) []*lsproto.CompletionItem
pub fn getTypescriptKeywordCompletions(keywordFilter: KeywordCompletionFilters) []const ?*lsproto.CompletionItem {
    _ = keywordFilter;
    return undefined;
}

// STUB: func isTypeScriptOnlyKeyword(kind ast.Kind) bool
pub fn isTypeScriptOnlyKeyword(kind: ast.Kind) bool {
    _ = kind;
    return false;
}

// STUB: func isFunctionLikeBodyKeyword(kind ast.Kind) bool
pub fn isFunctionLikeBodyKeyword(kind: ast.Kind) bool {
    _ = kind;
    return false;
}

// STUB: func isClassMemberCompletionKeyword(kind ast.Kind) bool
pub fn isClassMemberCompletionKeyword(kind: ast.Kind) bool {
    _ = kind;
    return false;
}

// STUB: func isInterfaceOrTypeLiteralCompletionKeyword(kind ast.Kind) bool
pub fn isInterfaceOrTypeLiteralCompletionKeyword(kind: ast.Kind) bool {
    _ = kind;
    return false;
}

// STUB: func isContextualKeywordInAutoImportableExpressionSpace(keyword string) bool
pub fn isContextualKeywordInAutoImportableExpressionSpace(keyword: []const u8) bool {
    _ = keyword;
    return false;
}

// STUB: func getContextualKeywords(file *ast.SourceFile, contextToken *ast.Node, position int) []*lsproto.CompletionItem
pub fn getContextualKeywords(file: ?*compiler.FileId, contextToken: ?*ast.NodeIndex, position: u32) []const ?*lsproto.CompletionItem {
    _ = file;
    _ = contextToken;
    _ = position;
    return undefined;
}

// STUB: func isMemberCompletionKind(kind CompletionKind) bool
pub fn isMemberCompletionKind(kind: CompletionKind) bool {
    _ = kind;
    return false;
}

// STUB: func tryGetFunctionLikeBodyCompletionContainer(contextToken *ast.Node) *ast.Node
pub fn tryGetFunctionLikeBodyCompletionContainer(contextToken: ?*ast.NodeIndex) ?*ast.NodeIndex {
    _ = contextToken;
    return null;
}

// STUB: func keywordForNode(node *ast.Node) ast.Kind
pub fn keywordForNode(node: ?*ast.NodeIndex) ast.Kind {
    _ = node;
    return undefined;
}

// STUB: func getScopeNode(initialToken *ast.Node, position int, file *ast.SourceFile) *ast.Node
pub fn getScopeNode(initialToken: ?*ast.NodeIndex, position: u32, file: ?*compiler.FileId) ?*ast.NodeIndex {
    _ = initialToken;
    _ = position;
    _ = file;
    return null;
}

// STUB: func isSnippetScope(scopeNode *ast.Node) bool
pub fn isSnippetScope(scopeNode: ?*ast.NodeIndex) bool {
    _ = scopeNode;
    return false;
}

// STUB: func isProbablyGlobalType(t *checker.Type, file *ast.SourceFile, typeChecker *checker.Checker) bool
pub fn isProbablyGlobalType(t: ?*checker.Type, file: ?*compiler.FileId, typeChecker: ?**checker.Checker) bool {
    _ = t;
    _ = file;
    _ = typeChecker;
    return false;
}

// STUB: func tryGetTypeLiteralNode(node *ast.Node) *ast.TypeLiteralNodeNode
pub fn tryGetTypeLiteralNode(node: ?*ast.NodeIndex) ?*ast.TypeLiteralNodeNode {
    _ = node;
    return null;
}

// STUB: func getConstraintOfTypeArgumentProperty(node *ast.Node, typeChecker *checker.Checker) *checker.Type
pub fn getConstraintOfTypeArgumentProperty(node: ?*ast.NodeIndex, typeChecker: ?**checker.Checker) ?*checker.Type {
    _ = node;
    _ = typeChecker;
    return null;
}

// STUB: func tryGetObjectLikeCompletionContainer(contextToken *ast.Node, position int, file *ast.SourceFile) *ast.ObjectLiteralLike
pub fn tryGetObjectLikeCompletionContainer(contextToken: ?*ast.NodeIndex, position: u32, file: ?*compiler.FileId) ?*ast.ObjectLiteralLike {
    _ = contextToken;
    _ = position;
    _ = file;
    return null;
}

// STUB: func tryGetObjectLiteralContextualType(node *ast.ObjectLiteralExpressionNode, typeChecker *checker.Checker) *checker.Type
pub fn tryGetObjectLiteralContextualType(node: ?*ast.ObjectLiteralExpressionNode, typeChecker: ?**checker.Checker) ?*checker.Type {
    _ = node;
    _ = typeChecker;
    return null;
}

// STUB: func getApparentProperties(t *checker.Type, node *ast.Node, typeChecker *checker.Checker) []*ast.Symbol
pub fn getApparentProperties(t: ?*checker.Type, node: ?*ast.NodeIndex, typeChecker: ?**checker.Checker) []const ?*checker.SymbolIndex {
    _ = t;
    _ = node;
    _ = typeChecker;
    return undefined;
}

// STUB: func containsNonPublicProperties(props []*ast.Symbol) bool
pub fn containsNonPublicProperties(props: []const ?*checker.SymbolIndex) bool {
    _ = props;
    return false;
}

// STUB: func isCurrentlyEditingNode(node *ast.Node, file *ast.SourceFile, position int) bool
pub fn isCurrentlyEditingNode(node: ?*ast.NodeIndex, file: ?*compiler.FileId, position: u32) bool {
    _ = node;
    _ = file;
    _ = position;
    return false;
}

// STUB: func setMemberDeclaredBySpreadAssignment(declaration *ast.Node, members *void, typeChecker *checker.Checker)
pub fn setMemberDeclaredBySpreadAssignment(declaration: ?*ast.NodeIndex, members: ?*void, typeChecker: ?**checker.Checker) void {
    _ = declaration;
    _ = members;
    _ = typeChecker;
}

// STUB: func tryGetConstructorLikeCompletionContainer(contextToken *ast.Node) *ast.ConstructorDeclarationNode
pub fn tryGetConstructorLikeCompletionContainer(contextToken: ?*ast.NodeIndex) ?*ast.ConstructorDeclarationNode {
    _ = contextToken;
    return null;
}

// STUB: func isConstructorParameterCompletion(node *ast.Node) bool
pub fn isConstructorParameterCompletion(node: ?*ast.NodeIndex) bool {
    _ = node;
    return false;
}

// STUB: func isFromObjectTypeDeclaration(node *ast.Node) bool
pub fn isFromObjectTypeDeclaration(node: ?*ast.NodeIndex) bool {
    _ = node;
    return false;
}

// STUB: func tryGetContainingJsxElement(contextToken *ast.Node, file *ast.SourceFile) *ast.JsxOpeningLikeElement
pub fn tryGetContainingJsxElement(contextToken: ?*ast.NodeIndex, file: ?*compiler.FileId) ?*ast.JsxOpeningLikeElement {
    _ = contextToken;
    _ = file;
    return null;
}

// STUB: func isTypeKeywordTokenOrIdentifier(node *ast.Node) bool
pub fn isTypeKeywordTokenOrIdentifier(node: ?*ast.NodeIndex) bool {
    _ = node;
    return false;
}

// STUB: func isInStringOrRegularExpressionOrTemplateLiteral(contextToken *ast.Node, position int) bool
pub fn isInStringOrRegularExpressionOrTemplateLiteral(contextToken: ?*ast.NodeIndex, position: u32) bool {
    _ = contextToken;
    _ = position;
    return false;
}

// STUB: func isVariableDeclarationListButNotTypeArgument(node *ast.Node, file *ast.SourceFile, typeChecker *checker.Checker) bool
pub fn isVariableDeclarationListButNotTypeArgument(node: ?*ast.NodeIndex, file: ?*compiler.FileId, typeChecker: ?**checker.Checker) bool {
    _ = node;
    _ = file;
    _ = typeChecker;
    return false;
}

// STUB: func isFunctionLikeButNotConstructor(kind ast.Kind) bool
pub fn isFunctionLikeButNotConstructor(kind: ast.Kind) bool {
    _ = kind;
    return false;
}

// STUB: func isPreviousPropertyDeclarationTerminated(contextToken *ast.Node, file *ast.SourceFile, position int) bool
pub fn isPreviousPropertyDeclarationTerminated(contextToken: ?*ast.NodeIndex, file: ?*compiler.FileId, position: u32) bool {
    _ = contextToken;
    _ = file;
    _ = position;
    return false;
}

// STUB: func isDotOfNumericLiteral(contextToken *ast.Node, file *ast.SourceFile) bool
pub fn isDotOfNumericLiteral(contextToken: ?*ast.NodeIndex, file: ?*compiler.FileId) bool {
    _ = contextToken;
    _ = file;
    return false;
}

// STUB: func isInJsxText(contextToken *ast.Node, location *ast.Node) bool
pub fn isInJsxText(contextToken: ?*ast.NodeIndex, location: ?*ast.NodeIndex) bool {
    _ = contextToken;
    _ = location;
    return false;
}

// STUB: func clientSupportsItemLabelDetails(ctx context.Context) bool
pub fn clientSupportsItemLabelDetails(ctx: void) bool {
    _ = ctx;
    return false;
}

// STUB: func clientSupportsItemSnippet(ctx context.Context) bool
pub fn clientSupportsItemSnippet(ctx: void) bool {
    _ = ctx;
    return false;
}

// STUB: func clientSupportsItemCommitCharacters(ctx context.Context) bool
pub fn clientSupportsItemCommitCharacters(ctx: void) bool {
    _ = ctx;
    return false;
}

// STUB: func clientSupportsItemInsertReplace(ctx context.Context) bool
pub fn clientSupportsItemInsertReplace(ctx: void) bool {
    _ = ctx;
    return false;
}

// STUB: func clientSupportsDefaultCommitCharacters(ctx context.Context) bool
pub fn clientSupportsDefaultCommitCharacters(ctx: void) bool {
    _ = ctx;
    return false;
}

// STUB: func clientSupportsDefaultEditRange(ctx context.Context) bool
pub fn clientSupportsDefaultEditRange(ctx: void) bool {
    _ = ctx;
    return false;
}

// STUB: func getArgumentInfoForCompletions(node *ast.Node, position int, file *ast.SourceFile, typeChecker *checker.Checker) *argumentInfoForCompletions
pub fn getArgumentInfoForCompletions(node: ?*ast.NodeIndex, position: u32, file: ?*compiler.FileId, typeChecker: ?**checker.Checker) void {
    _ = node;
    _ = position;
    _ = file;
    _ = typeChecker;
    return null;
}

// STUB: func getCompletionDocumentationFormat(ctx context.Context) lsproto.MarkupKind
pub fn getCompletionDocumentationFormat(ctx: void) lsproto.MarkupKind {
    _ = ctx;
    return undefined;
}

// STUB: func (l *LanguageService) getImportStatementCompletionInfo(contextToken *ast.Node, sourceFile *ast.SourceFile) importStatementCompletionInfo
pub fn getImportStatementCompletionInfo(ls: *languageservice.LanguageService, contextToken: ?*ast.NodeIndex, sourceFile: ?*compiler.FileId) ImportStatementCompletionInfo {
    _ = ls;
    _ = contextToken;
    _ = sourceFile;
    return undefined;
}

// STUB: func (l *LanguageService) getSingleLineReplacementSpanForImportCompletionNode(node *ast.Node) *lsproto.Range
pub fn getSingleLineReplacementSpanForImportCompletionNode(ls: *languageservice.LanguageService, node: ?*ast.NodeIndex) ?**lsproto.Range {
    _ = ls;
    _ = node;
    return null;
}

// STUB: func couldBeTypeOnlyImportSpecifier(importSpecifier *ast.Node, contextToken *ast.Node) bool
pub fn couldBeTypeOnlyImportSpecifier(importSpecifier: ?*ast.NodeIndex, contextToken: ?*ast.NodeIndex) bool {
    _ = importSpecifier;
    _ = contextToken;
    return false;
}

// STUB: func canCompleteFromNamedBindings(namedBindings *ast.NamedImportBindings) bool
pub fn canCompleteFromNamedBindings(namedBindings: ?*ast.NamedImportBindings) bool {
    _ = namedBindings;
    return false;
}

// STUB: func getPotentiallyInvalidImportSpecifier(namedBindings *ast.NamedImportBindings) *ast.Node
pub fn getPotentiallyInvalidImportSpecifier(namedBindings: ?*ast.NamedImportBindings) ?*ast.NodeIndex {
    _ = namedBindings;
    return null;
}

// STUB: func isModuleSpecifierMissingOrEmpty(specifier *ast.Expression) bool
pub fn isModuleSpecifierMissingOrEmpty(specifier: ?*ast.Expression) bool {
    _ = specifier;
    return false;
}

// STUB: func hasDocComment(file *ast.SourceFile, position int) bool
pub fn hasDocComment(file: ?*compiler.FileId, position: u32) bool {
    _ = file;
    _ = position;
    return false;
}

// STUB: func getJSDocTagAtPosition(node *ast.Node, position int) *ast.Node
pub fn getJSDocTagAtPosition(node: ?*ast.NodeIndex, position: u32) ?*ast.NodeIndex {
    _ = node;
    _ = position;
    return null;
}

// STUB: func tryGetTypeExpressionFromTag(tag *ast.Node) *ast.Node
pub fn tryGetTypeExpressionFromTag(tag: ?*ast.NodeIndex) ?*ast.NodeIndex {
    _ = tag;
    return null;
}

// STUB: func isTagWithTypeExpression(tag *ast.Node) bool
pub fn isTagWithTypeExpression(tag: ?*ast.NodeIndex) bool {
    _ = tag;
    return false;
}

// STUB: func getJSDocTagNameCompletions() []*CompletionItem
pub fn getJSDocTagNameCompletions() []const ?**CompletionItem {
    return undefined;
}

// STUB: func getJSDocTagCompletions() []*CompletionItem
pub fn getJSDocTagCompletions() []const ?**CompletionItem {
    return undefined;
}

// STUB: func getJSDocParamNameWithInitializer(paramName string, initializer *ast.Expression) string
pub fn getJSDocParamNameWithInitializer(paramName: []const u8, initializer: ?*ast.Expression) []const u8 {
    _ = paramName;
    _ = initializer;
    return undefined;
}

// STUB: func getJSDocParameterNameCompletions(tag *ast.JSDocParameterOrPropertyTag) []*CompletionItem
pub fn getJSDocParameterNameCompletions(tag: ?*ast.JSDocParameterOrPropertyTag) []const ?**CompletionItem {
    _ = tag;
    return undefined;
}

// STUB: func (p *snippetPrinter) printNode(node *ast.Node) string
pub fn printNode(node: ?*ast.NodeIndex) []const u8 {
    _ = node;
    return undefined;
}

// STUB: func (p *snippetPrinter) printUnescapedNode(node *ast.Node) string
pub fn printUnescapedNode(node: ?*ast.NodeIndex) []const u8 {
    _ = node;
    return undefined;
}

// STUB: func (p *snippetPrinter) printAndFormatNode(ctx context.Context, node *ast.Node, sourceFile *ast.SourceFile) string
pub fn printAndFormatNode(ctx: void, node: ?*ast.NodeIndex, sourceFile: ?*compiler.FileId) []const u8 {
    _ = ctx;
    _ = node;
    _ = sourceFile;
    return undefined;
}

// STUB: func (p *snippetPrinter) createSyntheticFile(node *ast.Node, text string, targetFile *ast.SourceFile) *ast.SourceFile
pub fn createSyntheticFile(node: ?*ast.NodeIndex, text: []const u8, targetFile: ?*compiler.FileId) ?*compiler.FileId {
    _ = node;
    _ = text;
    _ = targetFile;
    return null;
}

// STUB: func createSnippetPrinter(options void) *snippetPrinter
pub fn createSnippetPrinter(options: void) void {
    _ = options;
    return null;
}

// STUB: func (w *snippetEmitTextWriter) nonEscapingWrite(s string)
pub fn nonEscapingWrite(s: []const u8) void {
    _ = s;
}

// STUB: func (w *snippetEmitTextWriter) Write(s string)
pub fn Write(s: []const u8) void {
    _ = s;
}

// STUB: func (w *snippetEmitTextWriter) WriteComment(text string)
pub fn WriteComment(text: []const u8) void {
    _ = text;
}

// STUB: func (w *snippetEmitTextWriter) WriteStringLiteral(text string)
pub fn WriteStringLiteral(text: []const u8) void {
    _ = text;
}

// STUB: func (w *snippetEmitTextWriter) WriteParameter(text string)
pub fn WriteParameter(text: []const u8) void {
    _ = text;
}

// STUB: func (w *snippetEmitTextWriter) WriteProperty(text string)
pub fn WriteProperty(text: []const u8) void {
    _ = text;
}

// STUB: func (w *snippetEmitTextWriter) WriteSymbol(text string, symbol *ast.Symbol)
pub fn WriteSymbol(text: []const u8, symbol: ?*checker.SymbolIndex) void {
    _ = text;
    _ = symbol;
}

// STUB: func (w *snippetEmitTextWriter) escapingWrite(s string, write func())
pub fn escapingWrite(s: []const u8, write: *const fn() void) void {
    _ = s;
    _ = write;
    return undefined;
}
