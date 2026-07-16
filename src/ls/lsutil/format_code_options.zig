const std = @import("std");
const core = @import("../../core/core.zig");
const lsproto = @import("../../lsp/lsproto/lsproto.zig");
const printer = @import("../../printer/printer.zig");

pub const IndentStyle = enum(u8) {
    none,
    block,
    smart,
};

pub fn parseIndentStyle(v: std.json.Value) IndentStyle {
    switch (v) {
        .string => |s| {
            if (std.ascii.eqlIgnoreCase(s, "none")) return .none;
            if (std.ascii.eqlIgnoreCase(s, "block")) return .block;
            if (std.ascii.eqlIgnoreCase(s, "smart")) return .smart;
        },
        .integer => |i| {
            return @enumFromInt(@as(u8, @intCast(i)));
        },
        .float => |f| {
            return @enumFromInt(@as(u8, @intFromFloat(f)));
        },
        else => {},
    }
    return .smart;
}

pub const SemicolonPreference = enum {
    ignore,
    insert,
    remove,
};

pub fn parseSemicolonPreference(v: std.json.Value) SemicolonPreference {
    switch (v) {
        .string => |s| {
            if (std.ascii.eqlIgnoreCase(s, "ignore")) return .ignore;
            if (std.ascii.eqlIgnoreCase(s, "insert")) return .insert;
            if (std.ascii.eqlIgnoreCase(s, "remove")) return .remove;
        },
        else => {},
    }
    return .ignore;
}

pub const EditorSettings = struct {
    baseIndentSize: i32 = 0,
    indentSize: i32 = 0,
    tabSize: i32 = 0,
    newLineCharacter: []const u8 = "\n",
    convertTabsToSpaces: core.Tristate = .unknown,
    indentStyle: IndentStyle = .smart,
    trimTrailingWhitespace: core.Tristate = .unknown,
};

pub const FormatCodeSettings = struct {
    editorSettings: EditorSettings = .{},
    insertSpaceAfterCommaDelimiter: core.Tristate = .unknown,
    insertSpaceAfterSemicolonInForStatements: core.Tristate = .unknown,
    insertSpaceBeforeAndAfterBinaryOperators: core.Tristate = .unknown,
    insertSpaceAfterConstructor: core.Tristate = .unknown,
    insertSpaceAfterKeywordsInControlFlowStatements: core.Tristate = .unknown,
    insertSpaceAfterFunctionKeywordForAnonymousFunctions: core.Tristate = .unknown,
    insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis: core.Tristate = .unknown,
    insertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets: core.Tristate = .unknown,
    insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces: core.Tristate = .unknown,
    insertSpaceAfterOpeningAndBeforeClosingEmptyBraces: core.Tristate = .unknown,
    insertSpaceAfterOpeningAndBeforeClosingTemplateStringBraces: core.Tristate = .unknown,
    insertSpaceAfterOpeningAndBeforeClosingJsxExpressionBraces: core.Tristate = .unknown,
    insertSpaceAfterTypeAssertion: core.Tristate = .unknown,
    insertSpaceBeforeFunctionParenthesis: core.Tristate = .unknown,
    placeOpenBraceOnNewLineForFunctions: core.Tristate = .unknown,
    placeOpenBraceOnNewLineForControlBlocks: core.Tristate = .unknown,
    insertSpaceBeforeTypeAnnotation: core.Tristate = .unknown,
    indentMultiLineObjectLiteralBeginningOnBlankLine: core.Tristate = .unknown,
    semicolons: SemicolonPreference = .ignore,
    indentSwitchCase: core.Tristate = .unknown,

    pub fn toLSFormatOptions(self: *const FormatCodeSettings) lsproto.FormattingOptions {
        const trimTrailingWhitespace = self.editorSettings.trimTrailingWhitespace.isTrue();
        return .{
            .tabSize = @intCast(self.editorSettings.tabSize),
            .insertSpaces = self.editorSettings.convertTabsToSpaces.isTrue(),
            .trimTrailingWhitespace = trimTrailingWhitespace,
            .insertFinalNewline = null,
            .trimFinalNewlines = null,
        };
    }
};

pub fn fromLSFormatOptions(f: FormatCodeSettings, opt: *const lsproto.FormattingOptions) FormatCodeSettings {
    var updatedSettings = f;
    updatedSettings.editorSettings.tabSize = @intCast(opt.tabSize);
    updatedSettings.editorSettings.indentSize = @intCast(opt.tabSize);
    updatedSettings.editorSettings.convertTabsToSpaces = core.boolToTristate(opt.insertSpaces);
    if (opt.trimTrailingWhitespace) |trim| {
        updatedSettings.editorSettings.trimTrailingWhitespace = core.boolToTristate(trim);
    }
    return updatedSettings;
}

pub fn getDefaultFormatCodeSettings() FormatCodeSettings {
    return .{
        .editorSettings = .{
            .indentSize = printer.getDefaultIndentSize(),
            .tabSize = printer.getDefaultIndentSize(),
            .newLineCharacter = "\n",
            .convertTabsToSpaces = .ts_true,
            .indentStyle = .smart,
            .trimTrailingWhitespace = .ts_true,
        },
        .insertSpaceAfterConstructor = .ts_false,
        .insertSpaceAfterCommaDelimiter = .ts_true,
        .insertSpaceAfterSemicolonInForStatements = .ts_true,
        .insertSpaceBeforeAndAfterBinaryOperators = .ts_true,
        .insertSpaceAfterKeywordsInControlFlowStatements = .ts_true,
        .insertSpaceAfterFunctionKeywordForAnonymousFunctions = .ts_false,
        .insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis = .ts_false,
        .insertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets = .ts_false,
        .insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces = .ts_true,
        .insertSpaceAfterOpeningAndBeforeClosingTemplateStringBraces = .ts_false,
        .insertSpaceAfterOpeningAndBeforeClosingJsxExpressionBraces = .ts_false,
        .insertSpaceBeforeFunctionParenthesis = .ts_false,
        .placeOpenBraceOnNewLineForFunctions = .ts_false,
        .placeOpenBraceOnNewLineForControlBlocks = .ts_false,
        .semicolons = .ignore,
        .indentSwitchCase = .ts_true,
    };
}
