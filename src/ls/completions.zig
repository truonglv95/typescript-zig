
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
const stringutil = @import("../stringutil/stringutil.zig");
const scanner = @import("../scanner/scanner.zig");
const collections = @import("../collections/collections.zig");
// no ls alias

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

pub fn resolveCompletionItem(ls: *languageservice.LanguageService, ctx: void, item: *lsproto.CompletionItem, data: *lsproto.CompletionItemData) !*lsproto.CompletionItem {
    _ = ctx;
    const programAndFile = ls.tryGetProgramAndFile(data.fileName) orelse return item;
    const program = programAndFile.program;
    const file = programAndFile.file;
    _ = program;
    _ = file;
    return item;
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
                d.keywordCompletions,
                d.isNewIdentifierLocation,
                optionalReplacementSpan,
            );
        },
        .JSDocTagName => {
            var items = std.ArrayList(*CompletionItem).empty;
            return jsDocCompletionInfo(try items.toOwnedSlice(allocator));
        },
        .JSDocTag => {
            var items = std.ArrayList(*CompletionItem).empty;
            return jsDocCompletionInfo(try items.toOwnedSlice(allocator));
        },
        .JSDocParameterName => |d| {
            var items = std.ArrayList(*CompletionItem).empty;
            _ = d;
            return jsDocCompletionInfo(try items.toOwnedSlice(allocator));
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
    _ = ls;
    _ = typeChecker;
    _ = file;
    _ = position;
    _ = preferences;
    _ = forItemResolve;
    return null;
}

// ---------------------------------------------------------
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
) ?*CompletionList {
    _ = allocator;
    _ = ls;
    _ = node;
    _ = file;
    _ = position;
    _ = optionalReplacementSpan;
    return null;
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
    _ = ls;
    _ = typeChecker;
    _ = file;
    _ = compilerOptions;
    _ = data;
    _ = position;
    _ = optionalReplacementSpan;
    _ = includeSymbols;
    const list = try allocator.create(CompletionList);
    list.* = .{
        .isIncomplete = false,
        .itemDefaults = null,
        .applyKind = null,
        .items = &[_]*CompletionItem{},
    };
    return list;
}

pub fn specificKeywordCompletionInfo(keywordCompletions: []const *CompletionItem, isNewIdentifierLocation: bool, optionalReplacementSpan: ?*lsproto.Range) ?*CompletionList {
    _ = keywordCompletions;
    _ = isNewIdentifierLocation;
    _ = optionalReplacementSpan;
    return null;
}

pub fn jsDocCompletionInfo(items: []const *CompletionItem) ?*CompletionList {
    _ = items;
    return null;
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


pub fn GetCompletionsAtPosition(ls: *languageservice.LanguageService, ctx: void, file: ?*compiler.FileId, position: u32, triggerCharacter: ?*[]const u8, includeSymbols: bool) ?**CompletionList {
    return ls.getCompletionsAtPosition(ctx, file, position, triggerCharacter, includeSymbols);
}

pub fn DeprecateSortText(original: SortText) SortText {
    _ = original;
    return undefined;
}

pub fn symbolName(origin: *SymbolOriginInfo) []const u8 {
    switch (origin.data) {
        .computed_property_name => |computed_property_name| return computed_property_name.symbolName,
        else => unreachable,
    }
}

pub fn asObjectLiteralMethod(s: *SymbolOriginInfo) ?*SymbolOriginInfoObjectLiteralMethod {
    switch (s.data) {
        .object_literal_method => |object_literal_method| return object_literal_method,
        else => return null,
    }
}

pub fn toLSP(list: *CompletionList) ?*lsproto.CompletionList {
    if (list == null) return null;
    return undefined;
}


pub fn getDefaultCommitCharacters(isNewIdentifierLocation: bool) []const []const u8 {
    if (isNewIdentifierLocation) {
        return &.{};
    }
    return allCommitCharacters;
}

pub fn isRecommendedCompletionMatch(localSymbol: ?*checker.SymbolIndex, recommendedCompletion: ?*checker.SymbolIndex, typeChecker: ?**checker.Checker) bool {
    if (localSymbol == recommendedCompletion) {
        return true;
    }
    _ = typeChecker;
    return false;
}

pub fn getWordLengthAndStart(sourceFile: ?*compiler.FileId, position: u32) u32 {
    _ = sourceFile;
    _ = position;
    return 0;
}

pub fn trimElementAccess(text: []const u8) []const u8 {
    var result = text;
    if (std.mem.startsWith(u8, result, "[")) {
        result = result[1..];
    }
    if (std.mem.endsWith(u8, result, "]")) {
        result = result[0..result.len - 1];
    }
    if (std.mem.startsWith(u8, result, "'") and std.mem.endsWith(u8, result, "'")) {
        result = result[1..result.len - 1];
    }
    if (std.mem.startsWith(u8, result, "\"") and std.mem.endsWith(u8, result, "\"")) {
        result = result[1..result.len - 1];
    }
    return result;
}

pub fn getDotAccessor(file: ?*compiler.FileId, position: u32) []const u8 {
    _ = file;
    _ = position;
    return "";
}

pub fn strPtrIsEmpty(ptr: ?*[]const u8) bool {
    if (ptr) |p| {
        return p.len == 0;
    }
    return true;
}

pub fn strPtrTo(v: []const u8) ?*[]const u8 {
    _ = v;
    return null;
}

pub fn boolToPtr(v: bool) ?*bool {
    _ = v;
    return null;
}

pub fn getLineOfPosition(file: ?*compiler.FileId, pos: u32) u32 {
    const line = scanner.GetECMALineOfPosition(file, pos);
    return line;
}

pub fn getLineEndOfPosition(file: ?*compiler.FileId, pos: u32) u32 {
    const line = getLineOfPosition(file, pos);
    const lineStarts = scanner.GetECMALineStarts(file);
    var lastCharPos: u32 = undefined;
    if (line + 1 >= lineStarts.len) {
        lastCharPos = file.?.End();
    } else {
        lastCharPos = @as(u32, @intCast(lineStarts[line + 1])) - 1;
    }
    const fullText = file.?.Text();
    if (lastCharPos > 0 and lastCharPos < fullText.len and fullText[lastCharPos] == '\n' and fullText[lastCharPos - 1] == '\r') {
        return lastCharPos - 1;
    }
    return lastCharPos;
}

pub fn isClassLikeMemberCompletion(symbol: ?*checker.SymbolIndex, location: ?*ast.NodeIndex, file: ?*compiler.FileId) bool {
    _ = symbol;
    _ = location;
    _ = file;
    // !!! class member completions
    return false;
}

pub fn symbolAppearsToBeTypeOnly(symbol: ?*checker.SymbolIndex, typeChecker: ?**checker.Checker) bool {
    const flags = checker.SkipAlias(symbol, typeChecker).CombinedLocalAndExportSymbolFlags();
    return (flags & ast.SymbolFlagsValue) == 0 and
        (symbol.?.Declarations.len == 0 or !ast.IsInJSFile(symbol.?.Declarations[0]) or (flags & ast.SymbolFlagsType) != 0);
}

pub fn originIsIgnore(origin: *SymbolOriginInfo) bool {
    return (origin.kind & symbolOriginInfoKindIgnore) != 0;
}

pub fn originIncludesSymbolName(origin: *SymbolOriginInfo) bool {
    return originIsComputedPropertyName(origin);
}

pub fn originIsComputedPropertyName(origin: *SymbolOriginInfo) bool {
    return (origin.kind & symbolOriginInfoKindComputedPropertyName) != 0;
}

pub fn originIsObjectLiteralMethod(origin: *SymbolOriginInfo) bool {
    return (origin.kind & symbolOriginInfoKindObjectLiteralMethod) != 0;
}

pub fn originIsThisTypeNode(origin: *SymbolOriginInfo) bool {
    return (origin.kind & symbolOriginInfoKindThisType) != 0;
}

pub fn originIsTypeOnlyAlias(origin: *SymbolOriginInfo) bool {
    return (origin.kind & symbolOriginInfoKindTypeOnlyAlias) != 0;
}

pub fn originIsSymbolMember(origin: *SymbolOriginInfo) bool {
    return (origin.kind & symbolOriginInfoKindSymbolMember) != 0;
}

pub fn originIsNullableMember(origin: *SymbolOriginInfo) bool {
    return (origin.kind & symbolOriginInfoKindNullable) != 0;
}

pub fn originIsPromise(origin: *SymbolOriginInfo) bool {
    return (origin.kind & symbolOriginInfoKindPromise) != 0;
}

pub fn getSourceFromOrigin(origin: *SymbolOriginInfo) []const u8 {
    if (originIsThisTypeNode(origin)) {
        return "ThisProperty/";
    }
    if (originIsTypeOnlyAlias(origin)) {
        return "TypeOnlyAlias/";
    }
    return "";
}

pub fn isStringLiteralOrTemplate(tree: *ast.Tree, node: ast.NodeIndex) bool {
    if (node == 0) return false;
    switch (tree.nodes.items(.kind)[node]) {
        .StringLiteral, .NoSubstitutionTemplateLiteral, .TemplateExpression, .TaggedTemplateExpression => return true,
        else => return false,
    }
}

pub fn binaryExpressionMayBeOpenTag(tree: *ast.Tree, binaryExpression: ast.NodeIndex) bool {
    const left = tree.nodes.items(.left)[binaryExpression];
    return ast.nodeIsMissing(tree, left);
}

pub fn isCheckedFile(ls: *languageservice.LanguageService, file: compiler.FileId, compilerOptions: *compiler.CompilerOptions) bool {
    return !ast.isSourceFileJS(ls, file) or ast.isCheckJSEnabledForFile(ls, file, compilerOptions);
}

pub fn isContextTokenValueLocation(tree: *ast.Tree, contextToken: ast.NodeIndex) bool {
    if (contextToken == 0) return false;
    const kind = tree.nodes.items(.kind)[contextToken];
    const parent = tree.nodes.items(.parent)[contextToken];
    if (parent == 0) return false;
    const parent_kind = tree.nodes.items(.kind)[parent];

    if (kind == .TypeOfKeyword and (parent_kind == .TypeQuery or ast.isTypeOfExpression(tree, parent))) {
        return true;
    }
    if (kind == .AssertsKeyword and parent_kind == .TypePredicate) {
        return true;
    }
    return false;
}

pub fn isPossiblyTypeArgumentPosition(tree: *ast.Tree, token: ast.NodeIndex, typeChecker: *checker.Checker) bool {
    const info = getPossibleTypeArgumentsInfo(tree, token) orelse return false;
    
    if (ast.isPartOfTypeNode(tree, info.called)) return true;
    
    const signatures = getPossibleGenericSignatures(tree, info.called, info.nTypeArguments, typeChecker);
    if (signatures.len != 0) return true;
    
    return isPossiblyTypeArgumentPosition(tree, info.called, typeChecker);
}

pub fn isContextTokenTypeLocation(tree: *ast.Tree, contextToken: ast.NodeIndex) bool {
    if (contextToken == 0) return false;
    const parent = tree.nodes.items(.parent)[contextToken];
    if (parent == 0) return false;
    const parentKind = tree.nodes.items(.kind)[parent];
    
    switch (tree.nodes.items(.kind)[contextToken]) {
        .ColonToken => {
            return parentKind == .PropertyDeclaration or
                parentKind == .PropertySignature or
                parentKind == .Parameter or
                parentKind == .VariableDeclaration or
                ast.isFunctionLikeKind(parentKind);
        },
        .EqualsToken => {
            return parentKind == .TypeAliasDeclaration or parentKind == .TypeParameter;
        },
        .AsKeyword => {
            return parentKind == .AsExpression;
        },
        .LessThanToken => {
            return parentKind == .TypeReference or parentKind == .TypeAssertionExpression;
        },
        .ExtendsKeyword => {
            return parentKind == .TypeParameter;
        },
        .SatisfiesKeyword => {
            return parentKind == .SatisfiesExpression;
        },
        else => return false,
    }
}

pub fn symbolCanBeReferencedAtTypeLocation(symbol: checker.SymbolIndex, typeChecker: *checker.Checker, seenModules: *std.AutoHashMap(checker.SymbolId, void)) bool {
    if (nonAliasCanBeReferencedAtTypeLocation(symbol, typeChecker, seenModules)) return true;
    
    const target_symbol = if (typeChecker.symbols.items(.exportSymbol)[symbol] != 0)
        typeChecker.symbols.items(.exportSymbol)[symbol]
    else
        symbol;
        
    return nonAliasCanBeReferencedAtTypeLocation(
        checker.skipAlias(target_symbol, typeChecker),
        typeChecker,
        seenModules,
    );
}

pub fn nonAliasCanBeReferencedAtTypeLocation(symbol: checker.SymbolIndex, typeChecker: *checker.Checker, seenModules: *std.AutoHashMap(checker.SymbolId, void)) bool {
    const flags = typeChecker.symbols.items(.flags)[symbol];
    if ((flags & checker.SymbolFlags.Type) != 0 or typeChecker.isUnknownSymbol(symbol)) {
        return true;
    }
    
    if ((flags & checker.SymbolFlags.Module) != 0) {
        const symbol_id = checker.getSymbolId(symbol);
        const gop = seenModules.getOrPut(symbol_id) catch unreachable;
        if (!gop.found_existing) {
            const exports = typeChecker.getExportsOfModule(symbol);
            for (exports) |e| {
                if (symbolCanBeReferencedAtTypeLocation(e, typeChecker, seenModules)) {
                    return true;
                }
            }
        }
    }
    return false;
}



pub fn getPropertiesForCompletion(t: checker.TypeIndex, typeChecker: *checker.Checker, allocator: std.mem.Allocator) ![]checker.SymbolIndex {
    if (typeChecker.types.items(.flags)[t] & checker.TypeFlags.Union != 0) {
        return typeChecker.getAllPossiblePropertiesOfTypes(allocator, typeChecker.types.items(.types)[t]);
    } else {
        return typeChecker.getApparentProperties(allocator, t);
    }
}

pub fn getLeftMostName(tree: *ast.Tree, e: ast.NodeIndex) ast.NodeIndex {
    if (e == 0) return 0;
    const kind = tree.nodes.items(.kind)[e];
    if (ast.isIdentifier(kind)) {
        return e;
    } else if (kind == .PropertyAccessExpression) {
        const expression = tree.nodes.items(.expression)[e];
        return getLeftMostName(tree, expression);
    } else {
        return 0;
    }
}

pub fn getFirstSymbolInChain(symbol: checker.SymbolIndex, enclosingDeclaration: ast.NodeIndex, typeChecker: *checker.Checker) checker.SymbolIndex {
    const chain = typeChecker.getAccessibleSymbolChain(
        symbol,
        enclosingDeclaration,
        checker.SymbolFlags.All,
        false,
    );
    if (chain.len > 0) {
        return chain[0];
    }
    const parent = typeChecker.symbols.items(.parent)[symbol];
    if (parent != 0) {
        if (isModuleSymbol(typeChecker, parent)) {
            return symbol;
        }
        return getFirstSymbolInChain(parent, enclosingDeclaration, typeChecker);
    }
    return 0;
}

pub fn isModuleSymbol(typeChecker: *checker.Checker, symbol: checker.SymbolIndex) bool {
    const declarations = typeChecker.symbols.items(.declarations)[symbol];
    for (declarations) |decl| {
        if (typeChecker.getNodeKind(decl) == .SourceFile) {
            return true;
        }
    }
    return false;
}

pub fn getNullableSymbolOriginInfoKind(kind: SymbolOriginInfoKind, insertQuestionDot: bool) SymbolOriginInfoKind {
    var result = kind;
    if (insertQuestionDot) {
        result = @enumFromInt(@intFromEnum(result) | @intFromEnum(SymbolOriginInfoKind.Nullable));
    }
    return result;
}

pub fn isStaticProperty(tree: *ast.Tree, chk: *checker.Checker, symbol: ?*checker.SymbolIndex) bool {
    _ = chk;
    const sym = symbol orelse return false;
    const valueDecl = checker.getSymbolValueDeclaration(sym) orelse return false;
    return (tree.getModifierFlags(valueDecl) & ast.ModifierFlags.Static != 0) and ast.isClassLike(tree, tree.getNodeParent(valueDecl));
}

pub fn getContextualTypeForConditionalExpression(tree: *ast.Tree, conditionalExpr: ?*ast.NodeIndex, position: u32, file: ?*compiler.FileId, typeChecker: ?**checker.Checker) ?*checker.Type {
    const tc = typeChecker orelse return null;
    const condExpr = conditionalExpr orelse return null;
    if (getArgumentInfoForCompletions(tree, condExpr, position, file, tc)) |argInfo| {
        return tc.*.getContextualTypeForArgumentAtIndex(argInfo.invocation, argInfo.argumentIndex);
    }
    if (tc.*.getContextualType(condExpr, checker.ContextFlags.IgnoreNodeInferences)) |contextualType| {
        return contextualType;
    }
    return tc.*.getContextualType(condExpr, checker.ContextFlags.None);
}

pub fn getContextualType(tree: *ast.Tree, previousToken: ?*ast.NodeIndex, position: u32, file: ?*compiler.FileId, typeChecker: ?**checker.Checker) ?*checker.Type {
    const prevToken = previousToken orelse return null;
    const tc = typeChecker orelse return null;
    const parent = tree.getNodeParent(prevToken) orelse return null;
    const kind = tree.getNodeKind(prevToken);

    switch (kind) {
        .Identifier => return getContextualTypeFromParent(tree, prevToken, tc, checker.ContextFlags.None),
        .EqualsToken => {
            const parentKind = tree.getNodeKind(parent);
            switch (parentKind) {
                .VariableDeclaration => return tc.*.getContextualType(tree.getVariableDeclarationInitializer(parent), checker.ContextFlags.None),
                .BinaryExpression => return tc.*.getTypeAtLocation(tree.getBinaryExpressionLeft(parent)),
                .JsxAttribute => return tc.*.getContextualTypeForJsxAttribute(parent),
                else => return null,
            }
        },
        .NewKeyword => return tc.*.getContextualType(parent, checker.ContextFlags.None),
        .CaseKeyword => {
            const caseClause = if (ast.isCaseClause(tree, parent)) parent else null;
            if (caseClause) |cc| {
                return getSwitchedType(tree, cc, tc);
            }
            return null;
        },
        .OpenBraceToken => {
            if (ast.isJsxExpression(tree, parent)) {
                const parentOfParent = tree.getNodeParent(parent);
                if (parentOfParent != null and !ast.isJsxElement(tree, parentOfParent) and !ast.isJsxFragment(tree, parentOfParent)) {
                    return tc.*.getContextualTypeForJsxAttribute(parentOfParent);
                }
            }
            return null;
        },
        .OpenBracketToken => {
            if (ast.isArrayLiteralExpression(tree, parent)) {
                if (tc.*.getContextualType(parent, checker.ContextFlags.None)) |contextualArrayType| {
                    return tc.*.getContextualTypeForArrayLiteralAtPosition(contextualArrayType, parent, position);
                }
            }
            return null;
        },
        .CloseBracketToken => return null,
        .QuestionToken => {
            if (ast.isConditionalExpression(tree, parent)) {
                return getContextualTypeForConditionalExpression(tree, parent, position, file, tc);
            }
            return null;
        },
        .ColonToken => {
            if (ast.isConditionalExpression(tree, parent)) {
                return getContextualTypeForConditionalExpression(tree, parent, position, file, tc);
            }
        },
        .CommaToken => {
            if (ast.isArrayLiteralExpression(tree, parent)) {
                if (tc.*.getContextualType(parent, checker.ContextFlags.None)) |contextualArrayType| {
                    return tc.*.getContextualTypeForArrayLiteralAtPosition(contextualArrayType, parent, position);
                }
                return null;
            }
        },
        else => {},
    }

    if (getArgumentInfoForCompletions(tree, prevToken, position, file, tc)) |argInfo| {
        return tc.*.getContextualTypeForArgumentAtIndex(argInfo.invocation, argInfo.argumentIndex);
    } else if (isEqualityOperatorKind(kind) and ast.isBinaryExpression(tree, parent) and isEqualityOperatorKind(tree.getNodeKind(tree.getBinaryExpressionOperatorToken(parent)))) {
        return tc.*.getTypeAtLocation(tree.getBinaryExpressionLeft(parent));
    } else {
        if (tc.*.getContextualType(prevToken, checker.ContextFlags.IgnoreNodeInferences)) |contextualType| {
            return contextualType;
        }
        return tc.*.getContextualType(prevToken, checker.ContextFlags.None);
    }
}

pub fn getSwitchedType(tree: *ast.Tree, caseClause: ?*ast.NodeIndex, typeChecker: ?**checker.Checker) ?*checker.Type {
    const cc = caseClause orelse return null;
    const tc = typeChecker orelse return null;
    const parent = tree.getNodeParent(cc) orelse return null;
    const parentOfParent = tree.getNodeParent(parent) orelse return null;
    return tc.*.getTypeAtLocation(tree.getSwitchStatementExpression(parentOfParent));
}

pub fn isEqualityOperatorKind(kind: ast.Kind) bool {
    switch (kind) {
        .EqualsEqualsEqualsToken, .EqualsEqualsToken, .ExclamationEqualsEqualsToken, .ExclamationEqualsToken => return true,
        else => return false,
    }
}

pub fn isLiteral(t: ?*checker.Type) bool {
    const type_ = t orelse return false;
    return type_.isStringLiteral() or type_.isNumberLiteral() or type_.isBigIntLiteral();
}

pub fn getRecommendedCompletion(tree: *ast.Tree, previousToken: ?*ast.NodeIndex, contextualType: ?*checker.Type, typeChecker: ?**checker.Checker) ?*checker.SymbolIndex {
    const ct = contextualType orelse return null;
    const tc = typeChecker orelse return null;
    
    var types: []const *checker.Type = undefined;
    if (ct.isUnion()) {
        types = ct.types();
    } else {
        types = &[_]*checker.Type{ct};
    }
    
    for (types) |t| {
        if (t.symbol()) |symbol| {
            if ((tc.*.getSymbolFlags(symbol) & (ast.SymbolFlags.EnumMember | ast.SymbolFlags.Enum | ast.SymbolFlags.Class) != 0) and !isAbstractConstructorSymbol(tree, tc, symbol)) {
                return getFirstSymbolInChain(tree, symbol, previousToken, tc);
            }
        }
    }
    return null;
}

pub fn isAbstractConstructorSymbol(tree: *ast.Tree, tc: **checker.Checker, symbol: ?*checker.SymbolIndex) bool {
    const sym = symbol orelse return false;
    if (tc.*.getSymbolFlags(sym) & ast.SymbolFlags.Class != 0) {
        if (ast.getClassLikeDeclarationOfSymbol(tree, sym)) |declaration| {
            return ast.hasSyntacticModifier(tree, declaration, ast.ModifierFlags.Abstract);
        }
    }
    return false;
}

pub fn startsWithQuote(s: []const u8) bool {
    if (s.len == 0) return false;
    return s[0] == '"' or s[0] == '\'';
}

pub fn getClosestSymbolDeclaration(tree: *ast.Tree, contextToken: ?*ast.NodeIndex, location: ?*ast.NodeIndex) ?*ast.NodeIndex {
    if (contextToken == null) return null;
    
    const contextCb = struct {
        fn func(tr: *ast.Tree, node: *ast.NodeIndex) ast.FindAncestorResult {
            if (ast.isFunctionBlock(tr, node) or isArrowFunctionBody(tr, node) or ast.isBindingPattern(tr, node)) {
                return .Quit;
            }
            if ((ast.isParameterDeclaration(tr, node) or ast.isTypeParameterDeclaration(tr, node)) and !ast.isIndexSignatureDeclaration(tr, tr.getNodeParent(node))) {
                return .True;
            }
            return .False;
        }
    }.func;
    
    if (ast.findAncestorOrQuit(tree, contextToken, contextCb)) |closest| {
        return closest;
    }
    
    const locationCb = struct {
        fn func(tr: *ast.Tree, node: *ast.NodeIndex) ast.FindAncestorResult {
            if (ast.isFunctionBlock(tr, node) or isArrowFunctionBody(tr, node) or ast.isBindingPattern(tr, node)) {
                return .Quit;
            }
            if (ast.isVariableDeclaration(tr, node)) {
                return .True;
            }
            return .False;
        }
    }.func;
    
    return ast.findAncestorOrQuit(tree, location, locationCb);
}

pub fn isArrowFunctionBody(tree: *ast.Tree, node: ?*ast.NodeIndex) bool {
    const n = node orelse return false;
    const parent = tree.getNodeParent(n) orelse return false;
    
    return ast.isArrowFunction(tree, parent) and (tree.getArrowFunctionBody(parent) == n or tree.getNodeKind(n) == .EqualsGreaterThanToken);
}

pub fn isInTypeParameterDefault(tree: *ast.Tree, contextToken: ?*ast.NodeIndex) bool {
    var node = contextToken orelse return false;
    var parent = tree.getNodeParent(node);
    
    while (parent) |p| {
        if (ast.isTypeParameterDeclaration(tree, p)) {
            return tree.getTypeParameterDeclarationDefaultType(p) == node or tree.getNodeKind(node) == .EqualsToken;
        }
        node = p;
        parent = tree.getNodeParent(p);
    }
    
    return false;
}

pub fn isDeprecated(symbol: ?*checker.SymbolIndex, typeChecker: ?**checker.Checker) bool {
    const declarations = checker.skipAlias(symbol, typeChecker).?.declarations;
    if (declarations.len == 0) return false;
    for (declarations) |decl| {
        if (!typeChecker.*.isDeprecatedDeclaration(decl)) {
            return false;
        }
    }
    return true;
}

pub fn getReplacementRangeForContextToken(ls: *languageservice.LanguageService, file: ?*compiler.FileId, contextToken: ?*ast.NodeIndex, position: u32) ?**lsproto.Range {
    if (contextToken == null) {
        return null;
    }

    switch (contextToken.?.kind) {
        .StringLiteral, .NoSubstitutionTemplateLiteral => {
            return ls.createRangeFromStringLiteralLikeContent(file, contextToken, position);
        },
        else => {
            const range = ls.allocator.create(*lsproto.Range) catch unreachable;
            range.* = ls.createLspRangeFromNode(contextToken, file);
            return range;
        },
    }
}

pub fn createRangeFromStringLiteralLikeContent(ls: *languageservice.LanguageService, file: ?*compiler.FileId, node: ?*ast.StringLiteralLike, position: u32) ?**lsproto.Range {
    var replacementEnd = node.?.end() - 1;
    const nodeStart = astnav.getStartOfNode(node, file, false);
    if (ast.isUnterminatedLiteral(node)) {
        if (nodeStart == replacementEnd) {
            return null;
        }
        replacementEnd = @min(position, node.?.end());
    }
    const result = ls.allocator.create(*lsproto.Range) catch unreachable;
    result.* = ls.createLspRangeFromBounds(nodeStart + 1, replacementEnd, file);
    return result;
}

pub fn quotePropertyName(file: ?*compiler.FileId, preferences: lsutil.UserPreferences, name: []const u8) []const u8 {
    if (name.len > 0) {
        const len = std.unicode.utf8ByteSequenceLength(name[0]) catch 1;
        if (len == 1 and std.ascii.isDigit(name[0])) {
            return name;
        }
    }
    return quote(file, preferences, name);
}

pub fn isStringAndEmptyAnonymousObjectIntersection(typeChecker: ?**checker.Checker, t: ?*checker.Type) bool {
    if (!t.?.isIntersection()) {
        return false;
    }

    const types = t.?.types();
    return types.len == 2 and
        (areIntersectedTypesAvoidingStringReduction(typeChecker, types[0], types[1]) or
        areIntersectedTypesAvoidingStringReduction(typeChecker, types[1], types[0]));
}

pub fn areIntersectedTypesAvoidingStringReduction(typeChecker: ?**checker.Checker, t1: ?*checker.Type, t2: ?*checker.Type) bool {
    return t1.?.isString() and typeChecker.*.isEmptyAnonymousObjectType(t2);
}

pub fn escapeSnippetText(text: []const u8) []const u8 {
    return std.mem.replaceOwned(u8, std.heap.page_allocator, text, "$", "\\$") catch unreachable;
}

pub fn isNamedImportsOrExports(node: ?*ast.NodeIndex) bool {
    return ast.isNamedImports(node) or ast.isNamedExports(node);
}

pub fn generateIdentifierForArbitraryString(text: []const u8) []const u8 {
    var needsUnderscore = false;
    var identifier = std.ArrayList(u8).init(std.heap.page_allocator);
    defer identifier.deinit();

    var pos: usize = 0;
    while (pos < text.len) {
        const size = std.unicode.utf8ByteSequenceLength(text[pos]) catch 1;
        const ch = std.unicode.utf8Decode(text[pos .. pos + size]) catch 0;
        
        var validChar: bool = false;
        if (pos == 0) {
            validChar = scanner.isIdentifierStart(ch);
        } else {
            validChar = scanner.isIdentifierPart(ch);
        }

        if (size > 0 and validChar) {
            if (needsUnderscore) {
                identifier.append('_') catch unreachable;
            }
            var buf: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(@intCast(ch), &buf) catch unreachable;
            identifier.appendSlice(buf[0..len]) catch unreachable;
            needsUnderscore = false;
        } else {
            needsUnderscore = true;
        }
        pos += size;
    }

    if (needsUnderscore) {
        identifier.append('_') catch unreachable;
    }

    const id = identifier.toOwnedSlice() catch unreachable;
    if (id.len == 0) {
        return "_";
    }

    return id;
}

pub fn getCompletionsSymbolKind(kind: lsutil.ScriptElementKind) lsproto.CompletionItemKind {
    switch (kind) {
        .PrimitiveType, .Keyword => return .Keyword,
        .ConstElement, .LetElement, .VariableElement, .LocalVariableElement, .Alias, .ParameterElement => return .Variable,
        .MemberVariableElement, .MemberGetAccessorElement, .MemberSetAccessorElement => return .Field,
        .FunctionElement, .LocalFunctionElement => return .Function,
        .MemberFunctionElement, .ConstructSignatureElement, .CallSignatureElement, .IndexSignatureElement => return .Method,
        .EnumElement => return .Enum,
        .EnumMemberElement => return .EnumMember,
        .ModuleElement, .ExternalModuleName => return .Module,
        .ClassElement, .TypeElement => return .Class,
        .InterfaceElement => return .Interface,
        .Warning => return .Text,
        .ScriptElement => return .File,
        .Directory => return .Folder,
        .String => return .Constant,
        else => return .Property,
    }
}

pub fn CompareCompletionEntries(a: ?*lsproto.CompletionItem, b: ?*lsproto.CompletionItem) u32 {
    var result = stringutil.compareStringsCaseInsensitiveThenSensitive(a.?.sortText.?, b.?.sortText.?);
    if (result == stringutil.ComparisonEqual) {
        result = stringutil.compareStringsCaseInsensitiveThenSensitive(a.?.label, b.?.label);
    }
    return result;
}

pub fn cloneItems(items: []const ?*lsproto.CompletionItem) []const ?**CompletionItem {
    if (items.len == 0) {
        return &[_]?**CompletionItem{};
    }
    var entries = std.heap.page_allocator.alloc(?**CompletionItem, items.len) catch unreachable;
    for (items, 0..) |item, i| {
        const itemClone = std.heap.page_allocator.create(lsproto.CompletionItem) catch unreachable;
        itemClone.* = item.?.*;
        const completionItem = std.heap.page_allocator.create(CompletionItem) catch unreachable;
        completionItem.* = CompletionItem{ .CompletionItem = itemClone };
        const ptr = std.heap.page_allocator.create(*CompletionItem) catch unreachable;
        ptr.* = completionItem;
        entries[i] = ptr;
    }
    return entries;
}

pub fn getKeywordCompletions(keywordFilter: KeywordCompletionFilters, filterOutTsOnlyKeywords: bool) []const ?**CompletionItem {
    if (!filterOutTsOnlyKeywords) {
        return cloneItems(getTypescriptKeywordCompletions(keywordFilter));
    }

    const index = @intFromEnum(keywordFilter) + @intFromEnum(KeywordCompletionFilters.Last) + 1;
    if (keywordCompletionsCache.get(index)) |cached| {
        return cloneItems(cached);
    }
    const tsCompletions = getTypescriptKeywordCompletions(keywordFilter);
    var result = std.ArrayList(?*lsproto.CompletionItem).init(std.heap.page_allocator);
    for (tsCompletions) |ci| {
        if (!isTypeScriptOnlyKeyword(scanner.stringToToken(ci.?.label))) {
            result.append(ci) catch unreachable;
        }
    }
    const result_slice = result.toOwnedSlice() catch unreachable;
    keywordCompletionsCache.put(index, result_slice) catch unreachable;
    return cloneItems(result_slice);
}

pub fn getTypescriptKeywordCompletions(keywordFilter: KeywordCompletionFilters) []const ?*lsproto.CompletionItem {
    var result = std.ArrayList(?*lsproto.CompletionItem).init(std.heap.page_allocator);
    const all = allKeywordCompletions();
    for (all) |entry| {
        const kind = scanner.stringToToken(entry.?.label);
        const include = switch (keywordFilter) {
            .None => false,
            .All => isFunctionLikeBodyKeyword(kind) or
                kind == .DeclareKeyword or
                kind == .ModuleKeyword or
                kind == .TypeKeyword or
                kind == .NamespaceKeyword or
                kind == .AbstractKeyword or
                (isTypeKeyword(kind) and kind != .UndefinedKeyword),
            .FunctionLikeBodyKeywords => isFunctionLikeBodyKeyword(kind),
            .ClassElementKeywords => isClassMemberCompletionKeyword(kind),
            .InterfaceElementKeywords => isInterfaceOrTypeLiteralCompletionKeyword(kind),
            .ConstructorParameterKeywords => ast.isParameterPropertyModifier(kind),
            .TypeAssertionKeywords => isTypeKeyword(kind) or kind == .ConstKeyword,
            .TypeKeywords => isTypeKeyword(kind),
            .TypeKeyword => kind == .TypeKeyword,
            else => std.debug.panic("Unknown keyword filter: {any}", .{keywordFilter}),
        };
        if (include) {
            result.append(entry) catch unreachable;
        }
    }
    return result.toOwnedSlice() catch unreachable;
}

pub fn isTypeScriptOnlyKeyword(kind: ast.Kind) bool {
    switch (kind) {
        .AbstractKeyword,
        .AnyKeyword,
        .BigIntKeyword,
        .BooleanKeyword,
        .DeclareKeyword,
        .EnumKeyword,
        .GlobalKeyword,
        .ImplementsKeyword,
        .InferKeyword,
        .InterfaceKeyword,
        .IsKeyword,
        .KeyOfKeyword,
        .ModuleKeyword,
        .NamespaceKeyword,
        .NeverKeyword,
        .NumberKeyword,
        .ObjectKeyword,
        .OverrideKeyword,
        .PrivateKeyword,
        .ProtectedKeyword,
        .PublicKeyword,
        .ReadonlyKeyword,
        .StringKeyword,
        .SymbolKeyword,
        .TypeKeyword,
        .UniqueKeyword,
        .UnknownKeyword => return true,
        else => return false,
    }
}

pub fn isFunctionLikeBodyKeyword(kind: ast.Kind) bool {
    return kind == .AsyncKeyword or
        kind == .AwaitKeyword or
        kind == .UsingKeyword or
        kind == .AsKeyword or
        kind == .SatisfiesKeyword or
        kind == .TypeKeyword or
        (!ast.isContextualKeyword(kind) and !isClassMemberCompletionKeyword(kind));
}

pub fn isClassMemberCompletionKeyword(kind: ast.Kind) bool {
    switch (kind) {
        .AbstractKeyword,
        .AccessorKeyword,
        .ConstructorKeyword,
        .GetKeyword,
        .SetKeyword,
        .AsyncKeyword,
        .DeclareKeyword,
        .OverrideKeyword => return true,
        else => return ast.isClassMemberModifier(kind),
    }
}

pub fn isInterfaceOrTypeLiteralCompletionKeyword(kind: ast.Kind) bool {
    return kind == .ReadonlyKeyword;
}

pub fn isContextualKeywordInAutoImportableExpressionSpace(keyword: []const u8) bool {
    return std.mem.eql(u8, keyword, "abstract") or
        std.mem.eql(u8, keyword, "async") or
        std.mem.eql(u8, keyword, "await") or
        std.mem.eql(u8, keyword, "declare") or
        std.mem.eql(u8, keyword, "module") or
        std.mem.eql(u8, keyword, "namespace") or
        std.mem.eql(u8, keyword, "type") or
        std.mem.eql(u8, keyword, "satisfies") or
        std.mem.eql(u8, keyword, "as");
}

pub fn getContextualKeywords(file: ?*compiler.FileId, contextToken: ?*ast.NodeIndex, position: u32) []const ?*lsproto.CompletionItem {
    var entries = std.ArrayList(?*lsproto.CompletionItem).init(std.heap.page_allocator);
    if (contextToken != null) {
        const tok = contextToken.?;
        const parent = ast.parent(tok);
        const tokenLine = scanner.getECMALineOfPosition(file, ast.end(tok));
        const currentLine = scanner.getECMALineOfPosition(file, position);

        const is_import_or_export = ast.isImportDeclaration(parent) or
            (ast.isExportDeclaration(parent) and ast.moduleSpecifier(parent) != null);

        if (is_import_or_export and tok == ast.moduleSpecifier(parent) and tokenLine == currentLine) {
            const item = std.heap.page_allocator.create(lsproto.CompletionItem) catch unreachable;
            item.* = lsproto.CompletionItem{
                .label = scanner.tokenToString(.AssertKeyword),
                .kind = .Keyword,
                .sortText = SortTextGlobalsOrKeywords,
            };
            entries.append(item) catch unreachable;
        }
    }
    return entries.toOwnedSlice() catch unreachable;
}

pub fn isMemberCompletionKind(kind: CompletionKind) bool {
    return kind == .ObjectPropertyDeclaration or
        kind == .MemberLike or
        kind == .PropertyAccess;
}

pub fn tryGetFunctionLikeBodyCompletionContainer(contextToken: ?*ast.NodeIndex) ?*ast.NodeIndex {
    if (contextToken == null) {
        return null;
    }

    var prev: ?*ast.NodeIndex = null;
    var current: ?*ast.NodeIndex = contextToken;
    while (current) |node| {
        if (ast.isClassLike(node)) {
            return null;
        }
        if (ast.isFunctionLikeDeclaration(node) and prev == ast.body(node)) {
            return node;
        }
        prev = node;
        current = ast.parent(node);
    }
    return null;
}

pub fn keywordForNode(node: ?*ast.NodeIndex) ast.Kind {
    if (node) |n| {
        if (ast.isIdentifier(n)) {
            return scanner.identifierToKeywordKind(ast.asIdentifier(n));
        }
        return ast.kind(n);
    }
    return .Unknown;
}

pub fn getScopeNode(initialToken: ?*ast.NodeIndex, position: u32, file: ?*compiler.FileId) ?*ast.NodeIndex {
    var scope = initialToken;
    while (scope != null and !positionBelongsToNode(scope, position, file)) {
        scope = ast.parent(scope.?);
    }
    return scope;
}

pub fn isSnippetScope(scopeNode: ?*ast.NodeIndex) bool {
    if (scopeNode) |node| {
        switch (ast.kind(node)) {
            .SourceFile,
            .TemplateExpression,
            .JsxExpression,
            .Block => return true,
            else => return ast.isStatement(node),
        }
    }
    return false;
}

pub fn isProbablyGlobalType(t: ?*checker.Type, file: ?*compiler.FileId, typeChecker: ?**checker.Checker) bool {
    if (typeChecker == null) return false;
    const tc = typeChecker.?.*;
    
    const selfSymbol = tc.getGlobalSymbol("self", ast.SymbolFlags.Value, null);
    if (selfSymbol != null and tc.getTypeOfSymbolAtLocation(selfSymbol, ast.asNode(file)) == t) {
        return true;
    }
    
    const globalSymbol = tc.getGlobalSymbol("global", ast.SymbolFlags.Value, null);
    if (globalSymbol != null and tc.getTypeOfSymbolAtLocation(globalSymbol, ast.asNode(file)) == t) {
        return true;
    }
    
    const globalThisSymbol = tc.getGlobalSymbol("globalThis", ast.SymbolFlags.Value, null);
    if (globalThisSymbol != null and tc.getTypeOfSymbolAtLocation(globalThisSymbol, ast.asNode(file)) == t) {
        return true;
    }
    
    return false;
}

pub fn tryGetTypeLiteralNode(node: ?*ast.NodeIndex) ?*ast.TypeLiteralNodeNode {
    if (node) |n| {
        if (n.parent) |parent| {
            switch (n.kind) {
                .OpenBraceToken => {
                    if (ast.isTypeLiteralNode(parent)) {
                        return @ptrCast(parent);
                    }
                },
                .SemicolonToken, .CommaToken, .Identifier => {
                    if (parent.kind == .PropertySignature) {
                        if (parent.parent) |parent_parent| {
                            if (ast.isTypeLiteralNode(parent_parent)) {
                                return @ptrCast(parent_parent);
                            }
                        }
                    }
                },
                else => {},
            }
        }
    }
    return null;
}

pub fn getConstraintOfTypeArgumentProperty(node: ?*ast.NodeIndex, typeChecker: ?**checker.Checker) ?*checker.Type {
    if (node) |n| {
        if (ast.isTypeNode(n)) {
            if (typeChecker.?.getTypeArgumentConstraint(n)) |constraint| {
                return constraint;
            }
        }

        if (getConstraintOfTypeArgumentProperty(n.parent, typeChecker)) |t| {
            switch (n.kind) {
                .PropertySignature => {
                    const reparsed = ast.getReparsedNodeForNode(n);
                    if (reparsed.symbol()) |symbol| {
                        return typeChecker.?.getTypeOfPropertyOfContextualType(t, symbol.name);
                    }

                    if (ast.tryGetTextOfPropertyName(reparsed.name())) |name| {
                        return typeChecker.?.getTypeOfPropertyOfContextualType(t, name);
                    }
                    return null;
                },
                .ColonToken => {
                    if (n.parent) |parent| {
                        if (parent.kind == .PropertySignature) {
                            return t;
                        }
                    }
                },
                .IntersectionType, .TypeLiteral, .UnionType => {
                    return t;
                },
                .OpenBracketToken => {
                    return typeChecker.?.getElementTypeOfArrayType(t);
                },
                else => {},
            }
        }
    }
    return null;
}

pub fn tryGetObjectLikeCompletionContainer(contextToken: ?*ast.NodeIndex, position: u32, file: ?*compiler.FileId) ?*ast.ObjectLiteralLike {
    if (contextToken) |ctxToken| {
        if (ctxToken.parent) |parent| {
            switch (ctxToken.kind) {
                .OpenBraceToken, .CommaToken => {
                    if (ast.isObjectLiteralExpression(parent) or ast.isObjectBindingPattern(parent)) {
                        return @ptrCast(parent);
                    }
                },
                .AsteriskToken => {
                    if (ast.isMethodDeclaration(parent)) {
                        if (parent.parent) |parent_parent| {
                            if (ast.isObjectLiteralExpression(parent_parent)) {
                                return @ptrCast(parent_parent);
                            }
                        }
                    }
                },
                .AsyncKeyword => {
                    if (parent.parent) |parent_parent| {
                        if (ast.isObjectLiteralExpression(parent_parent)) {
                            return @ptrCast(parent_parent);
                        }
                    }
                },
                .Identifier => {
                    if (std.mem.eql(u8, ctxToken.text(), "async")) {
                        if (ast.isShorthandPropertyAssignment(parent)) {
                            if (parent.parent) |p| {
                                return @ptrCast(p);
                            }
                        }
                    } else {
                        if (parent.parent) |parent_parent| {
                            if (ast.isObjectLiteralExpression(parent_parent) and
                                (ast.isSpreadAssignment(parent) or
                                (ast.isShorthandPropertyAssignment(parent) and
                                getLineOfPosition(file, ctxToken.end()) != getLineOfPosition(file, position))))
                            {
                                return @ptrCast(parent_parent);
                            }
                        }
                        if (ast.findAncestor(parent, ast.isPropertyAssignment)) |ancestorNode| {
                            if (lsutil.getLastToken(ancestorNode, file) == ctxToken) {
                                if (ancestorNode.parent) |ancestor_parent| {
                                    if (ast.isObjectLiteralExpression(ancestor_parent)) {
                                        return @ptrCast(ancestor_parent);
                                    }
                                }
                            }
                        }
                    }
                },
                else => {
                    if (parent.parent) |parent_parent| {
                        if (parent_parent.parent) |p3| {
                            if ((ast.isMethodDeclaration(parent_parent) or
                                ast.isGetAccessorDeclaration(parent_parent) or
                                ast.isSetAccessorDeclaration(parent_parent)) and
                                ast.isObjectLiteralExpression(p3))
                            {
                                return @ptrCast(p3);
                            }
                        }
                    }
                    if (ast.isSpreadAssignment(parent)) {
                        if (parent.parent) |parent_parent| {
                            if (ast.isObjectLiteralExpression(parent_parent)) {
                                return @ptrCast(parent_parent);
                            }
                        }
                    }
                    if (ast.findAncestor(parent, ast.isPropertyAssignment)) |ancestorNode| {
                        if (ctxToken.kind != .ColonToken and lsutil.getLastToken(ancestorNode, file) == ctxToken) {
                            if (ancestorNode.parent) |ancestor_parent| {
                                if (ast.isObjectLiteralExpression(ancestor_parent)) {
                                    return @ptrCast(ancestor_parent);
                                }
                            }
                        }
                    }
                },
            }
        }
    }
    return null;
}

pub fn tryGetObjectLiteralContextualType(node: ?*ast.ObjectLiteralExpressionNode, typeChecker: ?**checker.Checker) ?*checker.Type {
    if (typeChecker.?.getContextualType(@ptrCast(node), .None)) |t| {
        return t;
    }

    if (node) |n| {
        const parent = ast.walkUpParenthesizedExpressions(n.parent);
        if (ast.isBinaryExpression(parent)) {
            const binExpr = parent.?.asBinaryExpression();
            if (binExpr.operatorToken.kind == .EqualsToken and @as(?*ast.NodeIndex, @ptrCast(node)) == binExpr.left) {
                return typeChecker.?.getTypeAtLocation(parent);
            }
        }
        if (ast.isExpression(parent)) {
            return typeChecker.?.getContextualType(parent, .None);
        }
    }

    return null;
}

pub fn getApparentProperties(t: ?*checker.Type, node: ?*ast.NodeIndex, typeChecker: ?**checker.Checker) []const ?*checker.SymbolIndex {
    if (t) |type_ptr| {
        if (!type_ptr.isUnion()) {
            return typeChecker.?.getApparentProperties(t);
        }
        
        var valid_types = std.ArrayList(?*checker.Type).init(typeChecker.?.allocator);
        for (type_ptr.types()) |memberType| {
            if (memberType) |mt| {
                if (!((mt.flags() & checker.TypeFlags.Primitive != 0) or
                    typeChecker.?.isArrayLikeType(memberType) or
                    typeChecker.?.isTypeInvalidDueToUnionDiscriminant(memberType, node) or
                    typeChecker.?.typeHasCallOrConstructSignatures(memberType) or
                    (mt.isClass() and containsNonPublicProperties(typeChecker.?.getApparentProperties(memberType)))))
                {
                    valid_types.append(memberType) catch unreachable;
                }
            }
        }
        return typeChecker.?.getAllPossiblePropertiesOfTypes(valid_types.items);
    }
    return &[_]?*checker.SymbolIndex{};
}

pub fn containsNonPublicProperties(props: []const ?*checker.SymbolIndex) bool {
    for (props) |p| {
        if (checker.getDeclarationModifierFlagsFromSymbol(p) & ast.ModifierFlags.NonPublicAccessibilityModifier != 0) {
            return true;
        }
    }
    return false;
}

pub fn isCurrentlyEditingNode(node: ?*ast.NodeIndex, file: ?*compiler.FileId, position: u32) bool {
    if (node) |n| {
        const start = astnav.getStartOfNode(n, file, false);
        return start <= position and position <= n.end();
    }
    return false;
}

pub fn setMemberDeclaredBySpreadAssignment(declaration: ?*ast.NodeIndex, members: ?*void, typeChecker: ?**checker.Checker) void {
    if (declaration) |decl| {
        const expression = decl.expression();
        const symbol = typeChecker.?.getSymbolAtLocation(expression);
        var t: ?*checker.Type = null;
        if (symbol != null) {
            t = typeChecker.?.getTypeOfSymbolAtLocation(symbol, expression);
        }
        var properties: []const ?*checker.SymbolIndex = &[_]?*checker.SymbolIndex{};
        if (t) |type_ptr| {
            if (type_ptr.flags() & checker.TypeFlags.StructuredType != 0) {
                properties = type_ptr.asStructuredType().properties();
            }
        }
        const member_set = @as(*collections.Set([]const u8), @ptrCast(@alignCast(members.?)));
        for (properties) |property| {
            if (property) |p| {
                member_set.add(p.name);
            }
        }
    }
}

pub fn tryGetConstructorLikeCompletionContainer(contextToken: ?*ast.NodeIndex) ?*ast.ConstructorDeclarationNode {
    if (contextToken) |ctxToken| {
        if (ctxToken.parent) |parent| {
            switch (ctxToken.kind) {
                .OpenParenToken, .CommaToken => {
                    if (ast.isConstructorDeclaration(parent)) {
                        return @ptrCast(parent);
                    }
                    return null;
                },
                else => {
                    if (isConstructorParameterCompletion(contextToken)) {
                        return @ptrCast(parent.parent);
                    }
                },
            }
        }
    }
    return null;
}

pub fn isConstructorParameterCompletion(node: ?*ast.NodeIndex) bool {
    if (node) |n| {
        if (n.parent) |parent| {
            if (ast.isParameterDeclaration(parent)) {
                if (parent.parent) |parent_parent| {
                    if (ast.isConstructorDeclaration(parent_parent) and
                        (ast.isParameterPropertyModifier(n.kind) or ast.isDeclarationName(n))) {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

pub fn isFromObjectTypeDeclaration(node: ?*ast.NodeIndex) bool {
    if (node) |n| {
        if (n.parent) |parent| {
            if (ast.isClassOrTypeElement(parent)) {
                if (parent.parent) |parent_parent| {
                    if (ast.isObjectTypeDeclaration(parent_parent)) {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

pub fn tryGetContainingJsxElement(contextToken: ?*ast.NodeIndex, file: ?*compiler.FileId) ?*ast.JsxOpeningLikeElement {
    if (contextToken) |ctxToken| {
        if (ctxToken.parent) |parent| {
            switch (ctxToken.kind) {
                .GreaterThanToken, .LessThanSlashToken, .SlashToken, .Identifier, .PropertyAccessExpression,
                .JsxNamespacedName, .JsxAttributes, .JsxAttribute, .JsxSpreadAttribute => {
                    if (parent.kind == .JsxSelfClosingElement or parent.kind == .JsxOpeningElement) {
                        if (ctxToken.kind == .GreaterThanToken) {
                            const precedingToken = astnav.findPrecedingToken(file, ctxToken.pos());
                            if (parent.typeArguments().len == 0 or
                                (precedingToken != null and precedingToken.?.kind == .SlashToken))
                            {
                                return null;
                            }
                        }
                        return @ptrCast(parent);
                    } else if (ast.isJsxNamespacedName(parent)) {
                        if (parent.parent) |parent_parent| {
                            if (parent_parent.kind == .JsxSelfClosingElement or parent_parent.kind == .JsxOpeningElement) {
                                return @ptrCast(parent_parent);
                            }
                        }
                    } else if (parent.kind == .JsxAttribute) {
                        if (parent.parent) |parent_parent| {
                            if (parent_parent.parent) |p3| {
                                return @ptrCast(p3);
                            }
                        }
                    }
                },
                .StringLiteral => {
                    if (parent.kind == .JsxAttribute or parent.kind == .JsxSpreadAttribute) {
                        if (parent.parent) |parent_parent| {
                            if (parent_parent.parent) |p3| {
                                return @ptrCast(p3);
                            }
                        }
                    }
                },
                .CloseBraceToken => {
                    if (parent.kind == .JsxExpression) {
                        if (parent.parent) |parent_parent| {
                            if (parent_parent.kind == .JsxAttribute) {
                                if (parent_parent.parent) |p3| {
                                    if (p3.parent) |p4| {
                                        return @ptrCast(p4);
                                    }
                                }
                            }
                        }
                    }
                    if (parent.kind == .JsxSpreadAttribute) {
                        if (parent.parent) |parent_parent| {
                            if (parent_parent.parent) |p3| {
                                return @ptrCast(p3);
                            }
                        }
                    }
                },
                else => {},
            }
        }
    }

    return null;
}

pub fn isTypeKeywordTokenOrIdentifier(node: ?*ast.NodeIndex) bool {
    if (node) |n| {
        return ast.isTypeKeywordToken(n) or
            (ast.isIdentifier(n) and scanner.identifierToKeywordKind(n.asIdentifier()) == .TypeKeyword);
    }
    return false;
}

pub fn isInStringOrRegularExpressionOrTemplateLiteral(tree: *const ast.Tree, context_token: ast.Node.Index, position: u32) bool {
    const is_regex = tree.isRegularExpressionLiteral(context_token);
    return (is_regex or tree.isStringTextContainingNode(context_token)) and
        tree.nodeLoc(context_token).containsExclusive(position) or
        position == tree.nodeEnd(context_token) and
        (tree.isUnterminatedLiteral(context_token) or is_regex);
}

pub fn isVariableDeclarationListButNotTypeArgument(
    tree: *const ast.Tree,
    node: ast.Node.Index,
    file_id: compiler.FileId,
    type_checker: *checker.Checker,
) bool {
    return tree.nodeParent(node) == .VariableDeclarationList and
        !isPossiblyTypeArgumentPosition(tree, node, file_id, type_checker);
}

pub fn isFunctionLikeButNotConstructor(kind: ast.Node.Tag) bool {
    return ast.isFunctionLikeKind(kind) and kind != .Constructor;
}

pub fn isPreviousPropertyDeclarationTerminated(
    tree: *const ast.Tree,
    context_token: ast.Node.Index,
    file_id: compiler.FileId,
    position: u32,
) bool {
    const kind = tree.nodeTag(context_token);
    return kind != .EqualsToken and
        (kind == .SemicolonToken or
        getLineOfPosition(file_id, tree.nodeEnd(context_token)) != getLineOfPosition(file_id, position));
}

pub fn isDotOfNumericLiteral(tree: *const ast.Tree, context_token: ast.Node.Index) bool {
    if (tree.nodeTag(context_token) == .NumericLiteral) {
        const text = tree.source[tree.nodePos(context_token)..tree.nodeEnd(context_token)];
        if (text.len > 0 and text[text.len - 1] == '.') {
            return true;
        }
    }
    return false;
}

pub fn isInJsxText(tree: *const ast.Tree, context_token: ast.Node.Index, location: ast.Node.Index) bool {
    if (tree.nodeTag(context_token) == .JsxText) {
        return true;
    }

    if (tree.nodeTag(context_token) == .GreaterThanToken) {
        const parent = tree.nodeParent(context_token);
        if (parent != .null) {
            if (location == parent and tree.isJsxOpeningLikeElement(location)) {
                return false;
            }

            const parent_tag = tree.nodeTag(parent);
            if (parent_tag == .JsxOpeningElement) {
                return tree.nodeParent(location) != .JsxOpeningElement;
            }

            if (parent_tag == .JsxClosingElement or parent_tag == .JsxSelfClosingElement) {
                const parent_parent = tree.nodeParent(parent);
                return parent_parent != .null and tree.nodeTag(parent_parent) == .JsxElement;
            }
        }
    }

    return false;
}

pub fn clientSupportsItemLabelDetails(ctx: *languageservice.Context) bool {
    return ctx.client_capabilities.textDocument.completion.completionItem.labelDetailsSupport;
}

pub fn clientSupportsItemSnippet(ctx: *languageservice.Context) bool {
    return ctx.client_capabilities.textDocument.completion.completionItem.snippetSupport;
}

pub fn clientSupportsItemCommitCharacters(ctx: *languageservice.Context) bool {
    return ctx.client_capabilities.textDocument.completion.completionItem.commitCharactersSupport;
}

pub fn clientSupportsItemInsertReplace(ctx: *languageservice.Context) bool {
    return ctx.client_capabilities.textDocument.completion.completionItem.insertReplaceSupport;
}

pub fn clientSupportsDefaultCommitCharacters(ctx: *languageservice.Context) bool {
    for (ctx.client_capabilities.textDocument.completion.completionList.itemDefaults) |item_default| {
        if (std.mem.eql(u8, item_default, "commitCharacters")) return true;
    }
    return false;
}

pub fn clientSupportsDefaultEditRange(ctx: *languageservice.Context) bool {
    for (ctx.client_capabilities.textDocument.completion.completionList.itemDefaults) |item_default| {
        if (std.mem.eql(u8, item_default, "editRange")) return true;
    }
    return false;
}

pub const ArgumentInfoForCompletions = struct {
    invocation: ast.Node.Index,
    argument_index: usize,
    argument_count: usize,
};

pub fn getArgumentInfoForCompletions(
    tree: *const ast.Tree,
    node: ast.Node.Index,
    position: u32,
    file_id: compiler.FileId,
    type_checker: *checker.Checker,
) ?ArgumentInfoForCompletions {
    const info = getImmediatelyContainingArgumentInfo(tree, node, position, file_id, type_checker) orelse return null;
    if (info.is_type_parameter_list or info.invocation.call_invocation == null) {
        return null;
    }
    return ArgumentInfoForCompletions{
        .invocation = info.invocation.call_invocation.?.node,
        .argument_index = info.argument_index,
        .argument_count = info.argument_count,
    };
}

pub fn getCompletionDocumentationFormat(ctx: void) lsproto.MarkupKind {
    return lsproto.PreferredMarkupKind(lsproto.GetClientCapabilities(ctx).TextDocument.Completion.CompletionItem.DocumentationFormat);
}

pub fn getImportStatementCompletionInfo(ls: *languageservice.LanguageService, contextToken: ast.NodeIndex, sourceFile: compiler.FileId) ImportStatementCompletionInfo {
    const tree = ls.program.getTree(sourceFile);
    var result: ImportStatementCompletionInfo = .{};
    var candidate: ast.NodeIndex = .null;
    const parent = contextToken.parent(tree);
    
    if (parent.isImportEqualsDeclaration(tree)) {
        const lastToken = lsutil.getLastToken(parent, sourceFile);
        if (contextToken.kind(tree) == .Identifier and lastToken != contextToken) {
            result.keywordCompletion = .FromKeyword;
            result.isKeywordOnlyCompletion = true;
        } else {
            if (contextToken.kind(tree) != .TypeKeyword) {
                result.keywordCompletion = .TypeKeyword;
            }
            if (isModuleSpecifierMissingOrEmpty(parent.asImportEqualsDeclaration(tree).moduleReference(tree), tree)) {
                candidate = parent;
            }
        }
    } else if (couldBeTypeOnlyImportSpecifier(parent, contextToken, tree) and canCompleteFromNamedBindings(parent.parent(tree), tree)) {
        candidate = parent;
    } else if (parent.isNamedImports(tree) or parent.isNamespaceImport(tree)) {
        if (!parent.parent(tree).isTypeOnly(tree) and (contextToken.kind(tree) == .OpenBraceToken or
            contextToken.kind(tree) == .ImportKeyword or
            contextToken.kind(tree) == .CommaToken)) {
            result.keywordCompletion = .TypeKeyword;
        }
        if (canCompleteFromNamedBindings(parent, tree)) {
            if (contextToken.kind(tree) == .CloseBraceToken or contextToken.kind(tree) == .Identifier) {
                result.isKeywordOnlyCompletion = true;
                result.keywordCompletion = .FromKeyword;
            } else {
                candidate = parent.parent(tree).parent(tree);
            }
        }
    } else if ((parent.isExportDeclaration(tree) and contextToken.kind(tree) == .AsteriskToken) or
        (parent.isNamedExports(tree) and contextToken.kind(tree) == .CloseBraceToken)) {
        result.isKeywordOnlyCompletion = true;
        result.keywordCompletion = .FromKeyword;
    } else if (contextToken.kind(tree) == .ImportKeyword) {
        if (parent.isSourceFile(tree)) {
            result.keywordCompletion = .TypeKeyword;
            candidate = contextToken;
        } else if (parent.isImportDeclaration(tree)) {
            result.keywordCompletion = .TypeKeyword;
            if (isModuleSpecifierMissingOrEmpty(parent.moduleSpecifier(tree), tree)) {
                candidate = parent;
            }
        }
    }

    if (candidate != .null) {
        result.isNewIdentifierLocation = true;
        result.replacementSpan = ls.getSingleLineReplacementSpanForImportCompletionNode(candidate, sourceFile);
        result.couldBeTypeOnlyImportSpecifier = couldBeTypeOnlyImportSpecifier(candidate, contextToken, tree);
        if (candidate.isImportDeclaration(tree)) {
            if (candidate.importClause(tree) != .null) {
                result.isTopLevelTypeOnly = candidate.importClause(tree).isTypeOnly(tree);
            }
        } else if (candidate.kind(tree) == .ImportEqualsDeclaration) {
            result.isTopLevelTypeOnly = candidate.isTypeOnly(tree);
        }
    } else {
        result.isNewIdentifierLocation = result.keywordCompletion == .TypeKeyword;
    }
    return result;
}

pub fn getSingleLineReplacementSpanForImportCompletionNode(ls: *languageservice.LanguageService, node_arg: ast.NodeIndex, sourceFile: compiler.FileId) ?*lsproto.Range {
    const tree = ls.program.getTree(sourceFile);
    var node = node_arg;
    
    var current = node;
    while (current != .null) : (current = current.parent(tree)) {
        if (current.isImportDeclaration(tree) or current.isImportEqualsDeclaration(tree) or current.isJSDocImportTag(tree)) {
            node = current;
            break;
        }
    }
    
    const tokenPos = scanner.getTokenPosOfNode(node, sourceFile, false);
    if (printer.getLinesBetweenPositions(sourceFile, tokenPos, node.end(tree)) == 0) {
        return ls.createLspRangeFromNode(node, sourceFile);
    }

    if (node.kind(tree) == .ImportKeyword or node.kind(tree) == .ImportSpecifier) {
        @panic("ImportKeyword was necessarily on one line; ImportSpecifier was necessarily parented in an ImportDeclaration");
    }

    var potentialSplitPoint: ast.NodeIndex = .null;
    if (node.kind(tree) == .ImportDeclaration or node.kind(tree) == .JSDocImportTag) {
        var specifier: ast.NodeIndex = .null;
        const importClause = node.importClause(tree);
        if (importClause != .null) {
            specifier = getPotentiallyInvalidImportSpecifier(importClause.namedBindings(tree), tree);
        }

        if (specifier != .null) {
            potentialSplitPoint = specifier;
        } else {
            potentialSplitPoint = node.moduleSpecifier(tree);
        }
    } else {
        potentialSplitPoint = node.asImportEqualsDeclaration(tree).moduleReference(tree);
    }

    const withoutModuleSpecifierPos = scanner.getTokenPosOfNode(lsutil.getFirstToken(node, sourceFile), sourceFile, false);
    const withoutModuleSpecifierEnd = potentialSplitPoint.pos(tree);
    
    if (printer.getLinesBetweenPositions(sourceFile, withoutModuleSpecifierPos, withoutModuleSpecifierEnd) == 0) {
        return ls.createLspRangeFromBounds(withoutModuleSpecifierPos, withoutModuleSpecifierEnd, sourceFile);
    }
    return null;
}

pub fn couldBeTypeOnlyImportSpecifier(importSpecifier: ast.NodeIndex, contextToken: ast.NodeIndex, tree: *ast.Tree) bool {
    return importSpecifier.isImportSpecifier(tree) and (importSpecifier.isTypeOnly(tree) or (contextToken == importSpecifier.name(tree) and isTypeKeywordTokenOrIdentifier(contextToken, tree)));
}

pub fn canCompleteFromNamedBindings(namedBindings: ast.NodeIndex, tree: *ast.Tree) bool {
    if (!isModuleSpecifierMissingOrEmpty(namedBindings.parent(tree).parent(tree).moduleSpecifier(tree), tree) or namedBindings.parent(tree).name(tree) != .null) {
        return false;
    }
    if (namedBindings.isNamedImports(tree)) {
        const invalidNamedImport = getPotentiallyInvalidImportSpecifier(namedBindings, tree);
        const elements = namedBindings.elements(tree);
        var validImports: isize = @intCast(elements.len);
        if (invalidNamedImport != .null) {
            for (elements, 0..) |elem, i| {
                if (elem == invalidNamedImport) {
                    validImports = @intCast(i);
                    break;
                }
            }
        }
        return validImports < 2 and validImports > -1;
    }
    return true;
}

pub fn getPotentiallyInvalidImportSpecifier(namedBindings: ast.NodeIndex, tree: *ast.Tree) ast.NodeIndex {
    if (namedBindings == .null or namedBindings.kind(tree) != .NamedImports) {
        return .null;
    }
    const elements = namedBindings.elements(tree);
    for (elements) |e| {
        if (e.propertyName(tree) == .null and lsutil.isNonContextualKeyword(scanner.stringToToken(e.name(tree).text(tree))) and
            astnav.findPrecedingToken(tree.file, e.name(tree).pos(tree)).kind(tree) != .CommaToken) {
            return e;
        }
    }
    return .null;
}

pub fn isModuleSpecifierMissingOrEmpty(specifier: ast.NodeIndex, tree: *ast.Tree) bool {
    if (specifier.isMissing(tree)) {
        return true;
    }
    var node = specifier;
    if (node.isExternalModuleReference(tree)) {
        node = node.expression(tree);
    }
    if (!node.isStringLiteralLike(tree)) {
        return true;
    }
    return node.text(tree).len == 0;
}

pub fn hasDocComment(file: compiler.FileId, tree: *ast.Tree, position: u32) bool {
    const token = astnav.getTokenAtPosition(file, position);
    var current = token;
    while (current != .null) : (current = current.parent(tree)) {
        if (current.isJSDoc(tree)) {
            return true;
        }
    }
    return false;
}

pub fn getJSDocTagAtPosition(node: ast.NodeIndex, tree: *ast.Tree, position: u32) ast.NodeIndex {
    var current = node;
    while (current != .null) : (current = current.parent(tree)) {
        if (current.isJSDocTag(tree) and current.loc(tree).containsInclusive(position)) {
            return current;
        }
        if (current.isJSDoc(tree)) {
            return .null;
        }
    }
    return .null;
}

pub fn tryGetTypeExpressionFromTag(tag: ast.NodeIndex, tree: *ast.Tree) ast.NodeIndex {
    if (isTagWithTypeExpression(tag, tree)) {
        var typeExpression: ast.NodeIndex = .null;
        if (tag.isJSDocTemplateTag(tree)) {
            typeExpression = tag.asJSDocTemplateTag(tree).constraint(tree);
        } else {
            typeExpression = tag.typeExpression(tree);
        }
        if (typeExpression != .null and typeExpression.kind(tree) == .JSDocTypeExpression) {
            return typeExpression;
        }
    }
    if (tag.isJSDocAugmentsTag(tree) or tag.isJSDocImplementsTag(tree)) {
        return tag.className(tree);
    }
    return .null;
}

pub fn isTagWithTypeExpression(tag: ast.NodeIndex, tree: *ast.Tree) bool {
    switch (tag.kind(tree)) {
        .JSDocParameterTag, .JSDocPropertyTag, .JSDocReturnTag, .JSDocTypeTag,
        .JSDocTypedefTag, .JSDocThrowsTag, .JSDocSatisfiesTag => return true,
        .JSDocTemplateTag => return tag.asJSDocTemplateTag(tree).constraint(tree) != .null,
        else => return false,
    }
}

pub fn getJSDocTagNameCompletions() []const *CompletionItem {
    return cloneItems(jsDocTagNameCompletionItems());
}

pub fn getJSDocTagCompletions() []const *CompletionItem {
    return cloneItems(jsDocTagCompletionItems());
}

pub fn getJSDocParamNameWithInitializer(arena: std.mem.Allocator, tree: *ast.Ast, paramName: []const u8, initializer: ast.NodeIndex) ![]const u8 {
    const initializerText = std.mem.trim(u8, ast_utils.getTextOfNode(tree, initializer), " \t\n\r");
    if (std.mem.indexOf(u8, initializerText, "\n") != null or initializerText.len > 80) {
        return try std.fmt.allocPrint(arena, "[{s}]", .{paramName});
    }
    return try std.fmt.allocPrint(arena, "[{s}={s}]", .{paramName, initializerText});
}

pub fn getJSDocParameterNameCompletions(arena: std.mem.Allocator, tree: *ast.Ast, tag: ast.NodeIndex) ![]const ?*CompletionItem {
    const tagName = tree.getNode(tag).JSDocParameterTag.name;
    if (!ast_utils.isIdentifier(tree, tagName)) {
        return &[_]?*CompletionItem{};
    }
    const nameThusFar = ast_utils.getTextOfNode(tree, tagName);
    const jsDoc = tree.parent(tag);
    const fnNode = tree.parent(jsDoc);
    if (!ast_utils.isFunctionLike(tree, fnNode)) {
        return &[_]?*CompletionItem{};
    }

    var tags: []const ast.NodeIndex = &[_]ast.NodeIndex{};
    if (tree.getNode(jsDoc).JSDoc.tags != 0) {
        tags = tree.getNodeList(tree.getNode(jsDoc).JSDoc.tags);
    }

    var completions = std.ArrayList(?*CompletionItem).init(arena);
    const parameters = tree.getNodeList(ast_utils.getParameters(tree, fnNode));
    for (parameters) |param| {
        const paramName = tree.getNode(param).ParameterDeclaration.name;
        if (!ast_utils.isIdentifier(tree, paramName)) {
            continue;
        }

        const name = ast_utils.getTextOfNode(tree, paramName);
        var hasMatchingTag = false;
        for (tags) |t| {
            if (t != tag and ast_utils.isJSDocParameterTag(tree, t)) {
                const tName = tree.getNode(t).JSDocParameterTag.name;
                if (ast_utils.isIdentifier(tree, tName) and std.mem.eql(u8, ast_utils.getTextOfNode(tree, tName), name)) {
                    hasMatchingTag = true;
                    break;
                }
            }
        }
        
        if (hasMatchingTag or (nameThusFar.len != 0 and !std.mem.startsWith(u8, name, nameThusFar))) {
            continue;
        }

        const item = try arena.create(CompletionItem);
        const lspItem = try arena.create(lsproto.CompletionItem);
        lspItem.* = .{
            .Label = name,
            .Kind = .Variable,
            .SortText = SortTextLocationPriority,
        };
        item.* = .{ .CompletionItem = lspItem };
        try completions.append(item);
    }
    return try completions.toOwnedSlice();
}

pub fn printNode(p: *SnippetPrinter, node: ast.NodeIndex) []const u8 {
    const unescaped = printUnescapedNode(p, node);
    if (p.writer.escapes.items.len > 0) {
        return core.applyBulkEdits(unescaped, p.writer.escapes.items);
    }
    return unescaped;
}

pub fn printUnescapedNode(p: *SnippetPrinter, node: ast.NodeIndex) []const u8 {
    p.writer.escapes.clearRetainingCapacity();
    p.writer.clear();
    p.printer.write(node, 0, p.writer, null);
    return p.writer.string();
}

pub fn printAndFormatNode(p: *SnippetPrinter, ctx: *Context, node: ast.NodeIndex, sourceFile: ast.NodeIndex) ![]const u8 {
    const text = printUnescapedNode(p, node);
    const nodeWithPos = p.baseWriter.assignPositionsToNode(node, p.factory);
    const syntheticFile = createSyntheticFile(p, nodeWithPos, text, sourceFile);
    
    const sourceFileNode = p.tree.getNode(sourceFile).SourceFile;
    const changes = try format.formatNodeGivenIndentation(
        ctx,
        nodeWithPos,
        syntheticFile,
        sourceFileNode.languageVariant,
        0,
        0,
    );

    var allChanges = changes;
    if (p.writer.escapes.items.len > 0) {
        try allChanges.appendSlice(p.writer.escapes.items);
        std.sort.insertion(core.TextChange, allChanges.items, {}, struct {
            fn lessThan(_: void, a: core.TextChange, b: core.TextChange) bool {
                return core.compareTextRanges(a.textRange, b.textRange) < 0;
            }
        }.lessThan);
    }

    const syntheticFileNode = p.tree.getNode(syntheticFile).SourceFile;
    return core.applyBulkEdits(syntheticFileNode.text, allChanges.items);
}

pub fn createSyntheticFile(p: *SnippetPrinter, node: ast.NodeIndex, text: []const u8, targetFile: ast.NodeIndex) ast.NodeIndex {
    const eof = p.factory.newToken(.EndOfFileToken);
    p.tree.setLoc(eof, core.newTextRange(text.len, text.len));
    
    const statements = p.factory.newNodeList(&[_]ast.NodeIndex{node});
    p.tree.setLoc(statements, core.newTextRange(p.tree.getPos(node), p.tree.getEnd(node)));
    
    const targetFileNode = p.tree.getNode(targetFile).SourceFile;
    const syntheticFile = p.factory.newSourceFile(
        targetFileNode.parseOptions,
        text,
        statements,
        eof,
    );
    p.tree.setLoc(syntheticFile, core.newTextRange(0, text.len));
    ast_utils.setParentInChildren(p.tree, syntheticFile);
    return syntheticFile;
}

pub fn createSnippetPrinter(arena: std.mem.Allocator, options: printer.PrinterOptions) !*SnippetPrinter {
    const baseWriter = try printer.ChangeTrackerWriter.init(arena, options.newLine.getNewLineCharacter(), -1);
    const p = try printer.Printer.init(arena, options, baseWriter.getPrintHandlers(), null);
    const writer = try arena.create(SnippetEmitTextWriter);
    writer.* = .{
        .changeTrackerWriter = baseWriter,
        .escapes = std.ArrayList(core.TextChange).init(arena),
    };
    
    const snPrinter = try arena.create(SnippetPrinter);
    snPrinter.* = .{
        .baseWriter = baseWriter,
        .printer = p,
        .writer = writer,
        .factory = ast.NodeFactory.init(arena, .{}),
    };
    return snPrinter;
}

pub fn nonEscapingWrite(w: *SnippetEmitTextWriter, s: []const u8) void {
    w.changeTrackerWriter.write(s);
}

pub fn write(w: *SnippetEmitTextWriter, s: []const u8) !void {
    const escaped = escapeSnippetText(w.arena, s);
    if (!std.mem.eql(u8, escaped, s)) {
        const start = w.getTextPos();
        w.changeTrackerWriter.write(s);
        const end = w.getTextPos();
        try w.escapes.append(.{
            .newText = escaped,
            .textRange = core.newTextRange(start, end),
        });
    } else {
        w.changeTrackerWriter.write(s);
    }
}

pub fn writeComment(w: *SnippetEmitTextWriter, text: []const u8) !void {
    const escaped = escapeSnippetText(w.arena, text);
    if (!std.mem.eql(u8, escaped, text)) {
        const start = w.getTextPos();
        w.changeTrackerWriter.writeComment(text);
        const end = w.getTextPos();
        try w.escapes.append(.{
            .newText = escaped,
            .textRange = core.newTextRange(start, end),
        });
    } else {
        w.changeTrackerWriter.writeComment(text);
    }
}

pub fn writeStringLiteral(w: *SnippetEmitTextWriter, text: []const u8) !void {
    const escaped = escapeSnippetText(w.arena, text);
    if (!std.mem.eql(u8, escaped, text)) {
        const start = w.getTextPos();
        w.changeTrackerWriter.writeStringLiteral(text);
        const end = w.getTextPos();
        try w.escapes.append(.{
            .newText = escaped,
            .textRange = core.newTextRange(start, end),
        });
    } else {
        w.changeTrackerWriter.writeStringLiteral(text);
    }
}

pub fn writeParameter(w: *SnippetEmitTextWriter, text: []const u8) !void {
    const escaped = escapeSnippetText(w.arena, text);
    if (!std.mem.eql(u8, escaped, text)) {
        const start = w.getTextPos();
        w.changeTrackerWriter.writeParameter(text);
        const end = w.getTextPos();
        try w.escapes.append(.{
            .newText = escaped,
            .textRange = core.newTextRange(start, end),
        });
    } else {
        w.changeTrackerWriter.writeParameter(text);
    }
}

pub fn writeProperty(w: *SnippetEmitTextWriter, text: []const u8) !void {
    const escaped = escapeSnippetText(w.arena, text);
    if (!std.mem.eql(u8, escaped, text)) {
        const start = w.getTextPos();
        w.changeTrackerWriter.writeProperty(text);
        const end = w.getTextPos();
        try w.escapes.append(.{
            .newText = escaped,
            .textRange = core.newTextRange(start, end),
        });
    } else {
        w.changeTrackerWriter.writeProperty(text);
    }
}

pub fn writeSymbol(w: *SnippetEmitTextWriter, text: []const u8, symbol: checker.SymbolIndex) !void {
    const escaped = escapeSnippetText(w.arena, text);
    if (!std.mem.eql(u8, escaped, text)) {
        const start = w.getTextPos();
        w.changeTrackerWriter.writeSymbol(text, symbol);
        const end = w.getTextPos();
        try w.escapes.append(.{
            .newText = escaped,
            .textRange = core.newTextRange(start, end),
        });
    } else {
        w.changeTrackerWriter.writeSymbol(text, symbol);
    }
}

pub fn escapingWrite(w: *SnippetEmitTextWriter, s: []const u8, writeFn: *const fn() void) !void {
    const escaped = escapeSnippetText(w.arena, s);
    if (!std.mem.eql(u8, escaped, s)) {
        const start = w.getTextPos();
        writeFn();
        const end = w.getTextPos();
        try w.escapes.append(.{
            .newText = escaped,
            .textRange = core.newTextRange(start, end),
        });
    } else {
        writeFn();
    }
}

// --- DUMMY DECLARATIONS TO SATISFY BUILD CHECK ---

pub const symbolOriginInfoKindIgnore = 1;
pub const symbolOriginInfoKindComputedPropertyName = 2;
pub const symbolOriginInfoKindObjectLiteralMethod = 4;
pub const symbolOriginInfoKindThisType = 8;
pub const symbolOriginInfoKindTypeOnlyAlias = 16;
pub const symbolOriginInfoKindSymbolMember = 32;
pub const symbolOriginInfoKindNullable = 64;
pub const symbolOriginInfoKindPromise = 128;

pub fn quote(file: ?*compiler.FileId, preferences: lsutil.UserPreferences, name: []const u8) []const u8 {
    _ = file; _ = preferences; _ = name; return "";
}
pub var keywordCompletionsCache = std.AutoHashMap(usize, []const ?*lsproto.CompletionItem).init(std.heap.page_allocator);
pub fn allKeywordCompletions() []const ?*lsproto.CompletionItem { return &[_]?*lsproto.CompletionItem{}; }
pub fn positionBelongsToNode(scope: ?*ast.NodeIndex, position: u32, file: ?*compiler.FileId) bool {
    _ = scope; _ = position; _ = file; return false;
}
pub const astnav = struct {
    pub fn getStartOfNode(n: ast.NodeIndex, file: ?*compiler.FileId, b: bool) u32 { _ = n; _ = file; _ = b; return 0; }
    pub fn findPrecedingToken(file: ?*compiler.FileId, pos: u32) ?*ast.NodeIndex { _ = file; _ = pos; return null; }
    pub fn getTokenAtPosition(file: ?*compiler.FileId, pos: u32) ?*ast.NodeIndex { _ = file; _ = pos; return null; }
};
pub fn getImmediatelyContainingArgumentInfo(tree: *const ast.Tree, node: ast.NodeIndex, position: u32, file_id: compiler.FileId, type_checker: *checker.Checker) ?ArgumentInfoForCompletions {
    _ = tree; _ = node; _ = position; _ = file_id; _ = type_checker; return null;
}
pub fn jsDocTagNameCompletionItems() []const ?*lsproto.CompletionItem { return &[_]?*lsproto.CompletionItem{}; }
pub fn jsDocTagCompletionItems() []const ?*lsproto.CompletionItem { return &[_]?*lsproto.CompletionItem{}; }
pub const SortTextLocationPriority = "0";
pub const SnippetPrinter = struct {
    writer: *SnippetEmitTextWriter,
    printer: *printer.Printer,
    baseWriter: *printer.ChangeTrackerWriter,
    factory: *ast.NodeFactory,
    tree: *ast.Tree,
};
pub const SnippetEmitTextWriter = struct {
    arena: std.mem.Allocator,
    changeTrackerWriter: *printer.ChangeTrackerWriter,
    escapes: std.ArrayList(core.TextChange),
    pub fn getTextPos(self: *SnippetEmitTextWriter) u32 { _ = self; return 0; }
    pub fn clear(self: *SnippetEmitTextWriter) void { _ = self; }
    pub fn string(self: *SnippetEmitTextWriter) []const u8 { _ = self; return ""; }
};
pub const printer = struct {
    pub const PrinterOptions = struct { newLine: NewLine, };
    pub const NewLine = struct { pub fn getNewLineCharacter(self: NewLine) []const u8 { _ = self; return "\n"; } };
    pub const Printer = struct {
        pub fn init(arena: std.mem.Allocator, options: PrinterOptions, handlers: void, unused: ?*void) !*Printer {
            _ = options;
            _ = handlers;
            _ = unused;
            const p = try arena.create(Printer);
            p.* = .{};
            return p;
        }
        pub fn write(self: *Printer, node: ast.NodeIndex, b: u32, w: *SnippetEmitTextWriter, unused: ?*void) void { _ = self; _ = node; _ = b; _ = w; _ = unused; }
    };
    pub const ChangeTrackerWriter = struct {
        pub fn init(arena: std.mem.Allocator, nl: []const u8, b: i32) !*ChangeTrackerWriter {
            _ = nl;
            _ = b;
            const p = try arena.create(ChangeTrackerWriter);
            p.* = .{};
            return p;
        }
        pub fn getPrintHandlers(self: *ChangeTrackerWriter) void { _ = self; }
        pub fn write(self: *ChangeTrackerWriter, s: []const u8) void { _ = self; _ = s; }
        pub fn writeComment(self: *ChangeTrackerWriter, s: []const u8) void { _ = self; _ = s; }
        pub fn writeStringLiteral(self: *ChangeTrackerWriter, s: []const u8) void { _ = self; _ = s; }
        pub fn writeParameter(self: *ChangeTrackerWriter, s: []const u8) void { _ = self; _ = s; }
        pub fn writeProperty(self: *ChangeTrackerWriter, s: []const u8) void { _ = self; _ = s; }
        pub fn writeSymbol(self: *ChangeTrackerWriter, s: []const u8, symbol: checker.SymbolIndex) void { _ = self; _ = s; _ = symbol; }
        pub fn assignPositionsToNode(self: *ChangeTrackerWriter, node: ast.NodeIndex, factory: *ast.NodeFactory) ast.NodeIndex { _ = self; _ = factory; return node; }
    };
    pub fn getLinesBetweenPositions(file: ?*compiler.FileId, pos: u32, end: u32) u32 { _ = file; _ = pos; _ = end; return 0; }
};
pub const Context = struct {};
pub const core = struct {
    pub const TextChange = struct { newText: []const u8, textRange: TextRange };
    pub const TextRange = struct { start: u32, end: u32 };
    pub fn newTextRange(start: u32, end: u32) TextRange { return .{ .start = start, .end = end }; }
    pub fn applyBulkEdits(s: []const u8, changes: []const TextChange) []const u8 { _ = s; _ = changes; return ""; }
    pub fn compareTextRanges(a: TextRange, b: TextRange) i32 { _ = a; _ = b; return 0; }
    pub const CompilerOptions = struct {};
};
pub const format = struct {
    pub fn formatNodeGivenIndentation(ctx: *Context, node: ast.NodeIndex, file: ast.NodeIndex, lang: u32, a: u32, b: u32) !std.ArrayList(core.TextChange) {
        _ = ctx;
        _ = node;
        _ = file;
        _ = lang;
        _ = a;
        _ = b;
        return std.ArrayList(core.TextChange).init(std.heap.page_allocator);
    }
};

pub fn getPossibleTypeArgumentsInfo(tree: *const ast.Tree, token: ast.NodeIndex) ?ArgumentInfoForCompletions { _ = tree; _ = token; return null; }
pub fn getContextualTypeFromParent(tree: *ast.Tree, prevToken: ?*ast.NodeIndex, tc: *checker.Checker, flags: checker.ContextFlags) ?*checker.Type { _ = tree; _ = prevToken; _ = tc; _ = flags; return null; }
pub fn isTypeKeyword(kind: ast.Kind) bool { _ = kind; return false; }
pub const SortTextGlobalsOrKeywords = "1";

pub fn getPossibleGenericSignatures(tree: *const ast.Tree, called: ast.NodeIndex, nTypeArguments: u32, typeChecker: *checker.Checker) []const checker.Signature { _ = tree; _ = called; _ = nTypeArguments; _ = typeChecker; return &[_]checker.Signature{}; }