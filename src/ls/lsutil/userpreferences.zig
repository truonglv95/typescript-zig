const std = @import("std");
const core = @import("../../core/core.zig");
const json = @import("../../json/json.zig");
const modulespecifiers = @import("../../modulespecifiers/specifiers.zig");
const vfsmatch = @import("../../vfs/vfsmatch.zig");
const formatcodeoptions = @import("formatcodeoptions.zig");

pub const QuotePreference = enum {
    Unknown,
    Auto,
    Double,
    Single,
};

pub const JsxAttributeCompletionStyle = enum {
    Unknown,
    Auto,
    Braces,
    None,
};

pub const IncludeInlayParameterNameHints = enum {
    None,
    All,
    Literals,
};

pub const OrganizeImportsCollation = enum {
    Ordinal,
    Unicode,
};

pub const OrganizeImportsCaseFirst = enum {
    False,
    Lower,
    Upper,
};

pub const OrganizeImportsTypeOrder = enum {
    Auto,
    Last,
    Inline,
    First,
};

pub const InlayHintsPreferences = struct {
    includeInlayParameterNameHints: IncludeInlayParameterNameHints = .None,
    includeInlayParameterNameHintsWhenArgumentMatchesName: core.Tristate = .Unknown,
    includeInlayFunctionParameterTypeHints: core.Tristate = .Unknown,
    includeInlayVariableTypeHints: core.Tristate = .Unknown,
    includeInlayVariableTypeHintsWhenTypeMatchesName: core.Tristate = .Unknown,
    includeInlayPropertyDeclarationTypeHints: core.Tristate = .Unknown,
    includeInlayFunctionLikeReturnTypeHints: core.Tristate = .Unknown,
    includeInlayEnumMemberValueHints: core.Tristate = .Unknown,
};

pub const CodeLensUserPreferences = struct {
    referencesCodeLensEnabled: core.Tristate = .Unknown,
    implementationsCodeLensEnabled: core.Tristate = .Unknown,
    referencesCodeLensShowOnAllFunctions: core.Tristate = .Unknown,
    implementationsCodeLensShowOnInterfaceMethods: core.Tristate = .Unknown,
    implementationsCodeLensShowOnAllClassMethods: core.Tristate = .Unknown,
};

pub const UserPreferences = struct {
    formatCodeSettings: formatcodeoptions.FormatCodeSettings = formatcodeoptions.getDefaultFormatCodeSettings(),
    quotePreference: QuotePreference = .Unknown,
    lazyConfiguredProjectsFromExternalProject: core.Tristate = .Unknown,
    maximumHoverLength: i32 = 0,
    
    includeCompletionsForModuleExports: core.Tristate = .True,
    includeCompletionsForImportStatements: core.Tristate = .True,
    includeAutomaticOptionalChainCompletions: core.Tristate = .Unknown,
    includeCompletionsWithClassMemberSnippets: core.Tristate = .Unknown,
    includeCompletionsWithObjectLiteralMethodSnippets: core.Tristate = .Unknown,
    jsxAttributeCompletionStyle: JsxAttributeCompletionStyle = .Unknown,
    
    importModuleSpecifierPreference: modulespecifiers.ImportModuleSpecifierPreference = .Shortest,
    importModuleSpecifierEnding: modulespecifiers.ImportModuleSpecifierEndingPreference = .Auto,
    autoImportSpecifierExcludeRegexes: [][]const u8 = &[_][]const u8{},
    autoImportFileExcludePatterns: [][]const u8 = &[_][]const u8{},
    autoImportEntrypointDirectorySearch: core.Tristate = .Unknown,
    preferTypeOnlyAutoImports: core.Tristate = .Unknown,
    
    organizeImportsIgnoreCase: core.Tristate = .Unknown,
    organizeImportsCollation: OrganizeImportsCollation = .Ordinal,
    organizeImportsLocale: []const u8 = "",
    organizeImportsNumericCollation: core.Tristate = .Unknown,
    organizeImportsAccentCollation: core.Tristate = .Unknown,
    organizeImportsCaseFirst: OrganizeImportsCaseFirst = .False,
    organizeImportsTypeOrder: OrganizeImportsTypeOrder = .Auto,
    
    allowTextChangesInNewFiles: core.Tristate = .Unknown,
    useAliasesForRename: core.Tristate = .Unknown,
    allowRenameOfImportPath: core.Tristate = .True,
    provideRefactorNotApplicableReason: core.Tristate = .True,
    
    inlayHints: InlayHintsPreferences = .{},
    codeLens: CodeLensUserPreferences = .{},
    
    preferGoToSourceDefinition: bool = false,
    excludeLibrarySymbolsInNavTo: core.Tristate = .True,
    
    disableSuggestions: core.Tristate = .Unknown,
    disableLineTextInReferences: core.Tristate = .True,
    displayPartsForJSDoc: core.Tristate = .True,
    reportStyleChecksAsWarnings: core.Tristate = .True,
    
    disableAutomaticTypeAcquisition: core.Tristate = .Unknown,
    automaticTypeAcquisitionEnabled: core.Tristate = .Unknown,
    
    customConfigFileName: []const u8 = "",

    pub fn isATADisabled(self: UserPreferences) bool {
        if (!self.automaticTypeAcquisitionEnabled.isUnknown()) {
            return !self.automaticTypeAcquisitionEnabled.isTrue();
        }
        return self.disableAutomaticTypeAcquisition.isTrue();
    }
};

pub fn newDefaultUserPreferences() UserPreferences {
    return UserPreferences{};
}
