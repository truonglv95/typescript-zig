const std = @import("std");
const core = @import("../../core/core.zig");

pub const IndentStyle = enum {
    None,
    Block,
    Smart,
};

pub const SemicolonPreference = enum {
    Ignore,
    Insert,
    Remove,
};

pub const EditorSettings = struct {
    baseIndentSize: i32 = 0,
    indentSize: i32 = 4,
    tabSize: i32 = 4,
    newLineCharacter: []const u8 = "\n",
    convertTabsToSpaces: core.Tristate = .True,
    indentStyle: IndentStyle = .Smart,
    trimTrailingWhitespace: core.Tristate = .True,
};

pub const FormatCodeSettings = struct {
    editorSettings: EditorSettings,
    insertSpaceAfterCommaDelimiter: core.Tristate = .True,
    insertSpaceAfterSemicolonInForStatements: core.Tristate = .True,
    insertSpaceBeforeAndAfterBinaryOperators: core.Tristate = .True,
    insertSpaceAfterConstructor: core.Tristate = .False,
    insertSpaceAfterKeywordsInControlFlowStatements: core.Tristate = .True,
    insertSpaceAfterFunctionKeywordForAnonymousFunctions: core.Tristate = .False,
    insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis: core.Tristate = .False,
    insertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets: core.Tristate = .False,
    insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces: core.Tristate = .True,
    insertSpaceAfterOpeningAndBeforeClosingEmptyBraces: core.Tristate = .False,
    insertSpaceAfterOpeningAndBeforeClosingTemplateStringBraces: core.Tristate = .False,
    insertSpaceAfterOpeningAndBeforeClosingJsxExpressionBraces: core.Tristate = .False,
    insertSpaceAfterTypeAssertion: core.Tristate = .False,
    insertSpaceBeforeFunctionParenthesis: core.Tristate = .False,
    placeOpenBraceOnNewLineForFunctions: core.Tristate = .False,
    placeOpenBraceOnNewLineForControlBlocks: core.Tristate = .False,
    insertSpaceBeforeTypeAnnotation: core.Tristate = .False,
    indentMultiLineObjectLiteralBeginningOnBlankLine: core.Tristate = .False,
    semicolons: SemicolonPreference = .Ignore,
    indentSwitchCase: core.Tristate = .True,
};

pub fn getDefaultFormatCodeSettings() FormatCodeSettings {
    return FormatCodeSettings{
        .editorSettings = EditorSettings{
            .indentSize = 4,
            .tabSize = 4,
            .newLineCharacter = "\n",
            .convertTabsToSpaces = .True,
            .indentStyle = .Smart,
            .trimTrailingWhitespace = .True,
        },
    };
}

pub fn fromLSFormatOptions(f: FormatCodeSettings, opt: *const @import("../../lsp/lsproto/lsproto.zig").FormattingOptions) FormatCodeSettings {
    var updated = f;
    updated.editorSettings.tabSize = @intCast(opt.tabSize);
    updated.editorSettings.indentSize = @intCast(opt.tabSize);
    updated.editorSettings.convertTabsToSpaces = core.boolToTristate(opt.insertSpaces);
    if (opt.trimTrailingWhitespace) |t| {
        updated.editorSettings.trimTrailingWhitespace = core.boolToTristate(t);
    }
    return updated;
}
