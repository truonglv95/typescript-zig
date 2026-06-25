const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const emitflags = @import("emitflags.zig");
const emitcontext = @import("emitcontext.zig");

pub const GetLiteralTextFlags = struct {
    pub const None: u32 = 0;
    pub const NeverAsciiEscape: u32 = 1 << 0;
    pub const JsxAttributeEscape: u32 = 1 << 1;
    pub const TerminateUnterminatedLiterals: u32 = 1 << 2;
    pub const AllowNumericSeparator: u32 = 1 << 3;
};

pub const QuoteChar = enum(u8) {
    SingleQuote = '\'',
    DoubleQuote = '"',
    Backtick = '`',
};

pub fn getJsxEscapedChar(ch: u21) ?[]const u8 {
    return switch (ch) {
        '"' => "&quot;",
        '\'' => "&apos;",
        else => null,
    };
}

pub fn getEscapedChar(ch: u21) ?[]const u8 {
    return switch (ch) {
        '\t' => "\\t",
        '\x0b' => "\\v", // '\v'
        '\x0c' => "\\f", // '\f'
        '\x08' => "\\b", // '\b'
        '\r' => "\\r",
        '\n' => "\\n",
        '\\' => "\\\\",
        '"' => "\\\"",
        '\'' => "\\'",
        '`' => "\\`",
        '$' => "\\$",
        '\u{2028}' => "\\u2028", // lineSeparator
        '\u{2029}' => "\\u2029", // paragraphSeparator
        '\u{0085}' => "\\u0085", // nextLine
        else => null,
    };
}

pub fn encodeJsxCharacterEntity(b: *std.ArrayList(u8), charCode: u21) !void {
    try b.appendSlice("&#x");
    var buf: [16]u8 = undefined;
    const hex = try std.fmt.bufPrint(&buf, "{X}", .{charCode});
    try b.appendSlice(hex);
    try b.append(';');
}

pub fn encodeUtf16EscapeSequence(b: *std.ArrayList(u8), charCode: u21) !void {
    try b.appendSlice("\\u");
    var buf: [16]u8 = undefined;
    const hex = try std.fmt.bufPrint(&buf, "{X}", .{charCode});
    var i: usize = hex.len;
    while (i < 4) : (i += 1) {
        try b.append('0');
    }
    try b.appendSlice(hex);
}

pub fn escapeStringWorker(allocator: std.mem.Allocator, s: []const u8, quoteChar: QuoteChar, flags: u32, b: *std.ArrayList(u8)) !void {
    _ = allocator;
    var pos: usize = 0;
    var i: usize = 0;
    while (i < s.len) {
        const view = s[i..];
        const len = std.unicode.utf8ByteSequenceLength(view[0]) catch 1;
        var ch: u21 = undefined;
        if (len == 1) {
            ch = view[0];
        } else {
            ch = std.unicode.utf8Decode(view[0..len]) catch std.unicode.replacement_character;
        }
        
        var escape = false;
        if (ch >= 0xD800 and ch <= 0xDFFF) {
            escape = true;
        } else if (ch == std.unicode.replacement_character and len == 1) {
            escape = true;
        }

        switch (ch) {
            '\\' => {
                if ((flags & GetLiteralTextFlags.JsxAttributeEscape) == 0) escape = true;
            },
            '$' => {
                if (quoteChar == .Backtick and i + 1 < s.len and s[i + 1] == '{') {
                    escape = true;
                }
            },
            '\u{2028}', '\u{2029}', '\u{0085}', '\r' => {
                escape = true;
            },
            '\n' => {
                if (quoteChar != .Backtick) escape = true;
            },
            else => {
                if (ch == @intFromEnum(quoteChar)) {
                    escape = true;
                } else if (ch <= '\u{001f}' or ((flags & GetLiteralTextFlags.NeverAsciiEscape) == 0 and ch > '\u{007f}')) {
                    escape = true;
                }
            }
        }

        if (escape) {
            if (pos < i) {
                try b.appendSlice(s[pos..i]);
            }

            if ((flags & GetLiteralTextFlags.JsxAttributeEscape) != 0) {
                if (ch == 0) {
                    try b.appendSlice("&#0;");
                } else if (getJsxEscapedChar(ch)) |match| {
                    try b.appendSlice(match);
                } else {
                    try encodeJsxCharacterEntity(b, ch);
                }
            } else {
                if (ch == '\r' and quoteChar == .Backtick and i + 1 < s.len and s[i + 1] == '\n') {
                    // size++ (need to skip '\n' later or what? Wait, the Go code just size++ and it is handled below i += size)
                    // For Zig, we handle next char manually. Let's say we increment i by 1
                    i += 1;
                    try b.appendSlice("\\r\\n");
                } else if (ch > 0xFFFF) {
                    const ch_adjusted = ch - 0x10000;
                    try encodeUtf16EscapeSequence(b, ((ch_adjusted & 0b11111111110000000000) >> 10) + 0xD800);
                    try encodeUtf16EscapeSequence(b, (ch_adjusted & 0b00000000001111111111) + 0xDC00);
                } else if (ch >= 0xD800 and ch <= 0xDFFF) {
                    try encodeUtf16EscapeSequence(b, ch);
                } else if (ch == 0) {
                    if (i + 1 < s.len and std.ascii.isDigit(s[i + 1])) {
                        try b.appendSlice("\\x00");
                    } else {
                        try b.appendSlice("\\0");
                    }
                } else {
                    if (getEscapedChar(ch)) |match| {
                        try b.appendSlice(match);
                    } else {
                        try encodeUtf16EscapeSequence(b, ch);
                    }
                }
            }
            pos = i + len;
        }
        i += len;
    }

    if (pos < i) {
        try b.appendSlice(s[pos..i]);
    }
}

pub fn escapeString(allocator: std.mem.Allocator, s: []const u8, quoteChar: QuoteChar) ![]const u8 {
    var b = std.ArrayList(u8).init(allocator);
    errdefer b.deinit();
    try b.ensureTotalCapacity(s.len + 2);
    try escapeStringWorker(allocator, s, quoteChar, GetLiteralTextFlags.NeverAsciiEscape, &b);
    return b.toOwnedSlice();
}

pub fn escapeNonAsciiString(allocator: std.mem.Allocator, s: []const u8, quoteChar: QuoteChar) ![]const u8 {
    var b = std.ArrayList(u8).init(allocator);
    errdefer b.deinit();
    try b.ensureTotalCapacity(s.len + 2);
    try escapeStringWorker(allocator, s, quoteChar, GetLiteralTextFlags.None, &b);
    return b.toOwnedSlice();
}

pub fn escapeJsxAttributeString(allocator: std.mem.Allocator, s: []const u8, quoteChar: QuoteChar) ![]const u8 {
    var b = std.ArrayList(u8).init(allocator);
    errdefer b.deinit();
    try b.ensureTotalCapacity(s.len + 2);
    try escapeStringWorker(allocator, s, quoteChar, GetLiteralTextFlags.JsxAttributeEscape | GetLiteralTextFlags.NeverAsciiEscape, &b);
    return b.toOwnedSlice();
}

// TODO: port scanner
pub fn getLiteralText(allocator: std.mem.Allocator, tree: *ast.Ast, nodeIndex: ast.NodeIndex, flags: u32) ![]const u8 {
    _ = allocator;
    _ = tree;
    _ = nodeIndex;
    _ = flags;
    // Stub
    return "";
}

pub fn isNotPrologueDirective(tree: *ast.Ast, nodeIndex: ast.NodeIndex) bool {
    _ = tree;
    _ = nodeIndex;
    // TODO: implement
    return true;
}

pub fn isNewExpressionWithoutArguments(tree: *ast.Ast, nodeIndex: ast.NodeIndex) bool {
    _ = tree;
    _ = nodeIndex;
    // TODO: implement
    return false;
}

pub fn greatestEnd(ends: []const u32) u32 {
    var max: u32 = 0;
    for (ends) |e| {
        if (e > max) max = e;
    }
    return max;
}

pub fn isImmediatelyInvokedFunctionExpressionOrArrowFunction(tree: *ast.Ast, nodeIndex: ast.NodeIndex) bool {
    _ = tree;
    _ = nodeIndex;
    // TODO: implement
    return false;
}

pub fn rangeIsOnSingleLine(tree: *ast.Ast, r: emitcontext.TextRange, sourceFileIndex: ast.NodeIndex) bool {
    _ = tree;
    _ = r;
    _ = sourceFileIndex;
    // TODO: port scanner
    return false;
}

pub fn rangeStartPositionsAreOnSameLine(tree: *ast.Ast, range1: emitcontext.TextRange, range2: emitcontext.TextRange, sourceFileIndex: ast.NodeIndex) bool {
    _ = tree;
    _ = range1;
    _ = range2;
    _ = sourceFileIndex;
    // TODO: port scanner
    return false;
}

pub fn positionsAreOnSameLine(tree: *ast.Ast, pos1: i32, pos2: i32, sourceFileIndex: ast.NodeIndex) bool {
    _ = tree;
    _ = pos1;
    _ = pos2;
    _ = sourceFileIndex;
    // TODO: port scanner
    return false;
}

pub fn getLinesBetweenPositions(tree: *ast.Ast, pos1: i32, pos2: i32, sourceFileIndex: ast.NodeIndex) i32 {
    _ = tree;
    _ = pos1;
    _ = pos2;
    _ = sourceFileIndex;
    // TODO: port scanner
    return 0;
}

pub fn skipSynthesizedParentheses(tree: *ast.Ast, nodeIndex: ast.NodeIndex) ast.NodeIndex {
    _ = tree;
    // TODO: implement
    return nodeIndex;
}

pub fn isBinaryOperation(tree: *ast.Ast, nodeIndex: ast.NodeIndex, token: ast_gen.SyntaxKind) bool {
    _ = tree;
    _ = nodeIndex;
    _ = token;
    // TODO: implement
    return false;
}

pub fn mixingBinaryOperatorsRequiresParentheses(a: ast_gen.SyntaxKind, b: ast_gen.SyntaxKind) bool {
    _ = a;
    _ = b;
    // TODO: implement
    return false;
}

pub fn isFileLevelUniqueName(tree: *ast.Ast, sourceFileIndex: ast.NodeIndex, name: []const u8, hasGlobalName: ?*const fn ([]const u8) bool) bool {
    _ = tree;
    _ = sourceFileIndex;
    _ = name;
    _ = hasGlobalName;
    // TODO: implement
    return false;
}

pub fn hasLeadingHash(text: []const u8) bool {
    return text.len > 0 and text[0] == '#';
}

pub fn removeLeadingHash(text: []const u8) []const u8 {
    if (hasLeadingHash(text)) {
        return text[1..];
    } else {
        return text;
    }
}

pub fn ensureLeadingHash(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    if (hasLeadingHash(text)) {
        return text;
    } else {
        return try std.fmt.allocPrint(allocator, "#{s}", .{text});
    }
}

pub fn formatGeneratedName(allocator: std.mem.Allocator, privateName: bool, prefix: []const u8, base: []const u8, suffix: []const u8) ![]const u8 {
    const p = removeLeadingHash(prefix);
    const b = removeLeadingHash(base);
    const s = removeLeadingHash(suffix);
    
    const name = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ p, b, s });
    if (privateName) {
        // Can optimize by returning # directly from allocPrint but for simplicity:
        const hashed = try ensureLeadingHash(allocator, name);
        if (hashed.ptr != name.ptr) {
            allocator.free(name);
        }
        return hashed;
    }
    return name;
}

pub fn isASCIIWordCharacter(ch: u21) bool {
    return std.ascii.isAlphabetic(ch) or std.ascii.isDigit(ch) or ch == '_';
}

pub fn makeIdentifierFromModuleName(allocator: std.mem.Allocator, moduleName: []const u8) ![]const u8 {
    // tspath.GetBaseFileName(moduleName) is missing, just use std.fs.path.basename
    const baseName = std.fs.path.basename(moduleName);
    var builder = std.ArrayList(u8).init(allocator);
    errdefer builder.deinit();
    
    var start: usize = 0;
    var pos: usize = 0;
    while (pos < baseName.len) {
        // Here we assume ASCII for moduleName or single byte per char for simplicity
        const ch = baseName[pos];
        if (pos == 0 and std.ascii.isDigit(ch)) {
            try builder.append('_');
        } else if (!isASCIIWordCharacter(ch)) {
            if (start < pos) {
                try builder.appendSlice(baseName[start..pos]);
            }
            try builder.append('_');
            start = pos + 1;
        }
        pos += 1;
    }
    if (start < pos) {
        try builder.appendSlice(baseName[start..pos]);
    }
    return builder.toOwnedSlice();
}

pub fn isRecognizedTripleSlashComment(text: []const u8, commentKind: ast_gen.SyntaxKind, pos: usize, end: usize) bool {
    _ = text;
    _ = commentKind;
    _ = pos;
    _ = end;
    // TODO: implement
    return false;
}

pub fn isJSDocLikeText(text: []const u8, commentKind: ast_gen.SyntaxKind, pos: usize, end: usize) bool {
    _ = text;
    _ = commentKind;
    _ = pos;
    _ = end;
    // TODO: implement
    return false;
}

pub fn isPinnedComment(text: []const u8, commentKind: ast_gen.SyntaxKind, pos: usize, end: usize) bool {
    _ = text;
    _ = commentKind;
    _ = pos;
    _ = end;
    // TODO: implement
    return false;
}

pub fn isLineBreak(ch: u21) bool {
    _ = ch;
    // TODO: implement
    return false;
}

pub fn containsParseError(tree: *ast.Ast, nodeIndex: ast.NodeIndex) bool {
    _ = tree;
    _ = nodeIndex;
    // TODO: implement
    return false;
}

pub fn nodeIsSynthesized(tree: *ast.Ast, nodeIndex: ast.NodeIndex) bool {
    _ = tree;
    _ = nodeIndex;
    // TODO: implement
    return false;
}

pub fn tokenToString(token: @import("../ast/kind.zig").Kind) ?[]const u8 {
    return switch (token) {
        .OpenBraceToken => "{",
        .CloseBraceToken => "}",
        .OpenParenToken => "(",
        .CloseParenToken => ")",
        .OpenBracketToken => "[",
        .CloseBracketToken => "]",
        .DotToken => ".",
        .DotDotDotToken => "...",
        .SemicolonToken => ";",
        .CommaToken => ",",
        .LessThanToken => "<",
        .GreaterThanToken => ">",
        .LessThanEqualsToken => "<=",
        .GreaterThanEqualsToken => ">=",
        .EqualsEqualsToken => "==",
        .ExclamationEqualsToken => "!=",
        .EqualsEqualsEqualsToken => "===",
        .ExclamationEqualsEqualsToken => "!==",
        .EqualsGreaterThanToken => "=>",
        .PlusToken => "+",
        .MinusToken => "-",
        .AsteriskAsteriskToken => "**",
        .AsteriskToken => "*",
        .SlashToken => "/",
        .PercentToken => "%",
        .PlusPlusToken => "++",
        .MinusMinusToken => "--",
        .LessThanLessThanToken => "<<",
        .LessThanSlashToken => "</",
        .GreaterThanGreaterThanToken => ">>",
        .GreaterThanGreaterThanGreaterThanToken => ">>>",
        .AmpersandToken => "&",
        .BarToken => "|",
        .CaretToken => "^",
        .ExclamationToken => "!",
        .TildeToken => "~",
        .AmpersandAmpersandToken => "&&",
        .BarBarToken => "||",
        .QuestionToken => "?",
        .QuestionQuestionToken => "??",
        .QuestionDotToken => "?.",
        .ColonToken => ":",
        .EqualsToken => "=",
        .PlusEqualsToken => "+=",
        .MinusEqualsToken => "-=",
        .AsteriskEqualsToken => "*=",
        .AsteriskAsteriskEqualsToken => "**=",
        .SlashEqualsToken => "/=",
        .PercentEqualsToken => "%=",
        .LessThanLessThanEqualsToken => "<<=",
        .GreaterThanGreaterThanEqualsToken => ">>=",
        .GreaterThanGreaterThanGreaterThanEqualsToken => ">>>=",
        .AmpersandEqualsToken => "&=",
        .BarEqualsToken => "|=",
        .CaretEqualsToken => "^=",
        .BarBarEqualsToken => "||=",
        .AmpersandAmpersandEqualsToken => "&&=",
        .QuestionQuestionEqualsToken => "??=",
        .AtToken => "@",
        .HashToken => "#",
        .BacktickToken => "`",
        
        .AbstractKeyword => "abstract",
        .AccessorKeyword => "accessor",
        .AnyKeyword => "any",
        .AsKeyword => "as",
        .AssertsKeyword => "asserts",
        .AssertKeyword => "assert",
        .AsyncKeyword => "async",
        .AwaitKeyword => "await",
        .BigIntKeyword => "bigint",
        .BooleanKeyword => "boolean",
        .BreakKeyword => "break",
        .CaseKeyword => "case",
        .CatchKeyword => "catch",
        .ClassKeyword => "class",
        .ContinueKeyword => "continue",
        .ConstKeyword => "const",
        .ConstructorKeyword => "constructor",
        .DebuggerKeyword => "debugger",
        .DeclareKeyword => "declare",
        .DefaultKeyword => "default",
        .DeleteKeyword => "delete",
        .DoKeyword => "do",
        .ElseKeyword => "else",
        .EnumKeyword => "enum",
        .ExportKeyword => "export",
        .ExtendsKeyword => "extends",
        .FalseKeyword => "false",
        .FinallyKeyword => "finally",
        .ForKeyword => "for",
        .FromKeyword => "from",
        .FunctionKeyword => "function",
        .GetKeyword => "get",
        .IfKeyword => "if",
        .ImmediateKeyword => "immediate",
        .ImplementsKeyword => "implements",
        .ImportKeyword => "import",
        .InKeyword => "in",
        .InferKeyword => "infer",
        .InstanceOfKeyword => "instanceof",
        .InterfaceKeyword => "interface",
        .IntrinsicKeyword => "intrinsic",
        .IsKeyword => "is",
        .KeyOfKeyword => "keyof",
        .LetKeyword => "let",
        .ModuleKeyword => "module",
        .NamespaceKeyword => "namespace",
        .NeverKeyword => "never",
        .NewKeyword => "new",
        .NullKeyword => "null",
        .NumberKeyword => "number",
        .ObjectKeyword => "object",
        .OfKeyword => "of",
        .OutKeyword => "out",
        .OverrideKeyword => "override",
        .PackageKeyword => "package",
        .PrivateKeyword => "private",
        .ProtectedKeyword => "protected",
        .PublicKeyword => "public",
        .ReadonlyKeyword => "readonly",
        .RequireKeyword => "require",
        .ReturnKeyword => "return",
        .SatisfiesKeyword => "satisfies",
        .SetKeyword => "set",
        .StaticKeyword => "static",
        .StringKeyword => "string",
        .SuperKeyword => "super",
        .SwitchKeyword => "switch",
        .SymbolKeyword => "symbol",
        .ThisKeyword => "this",
        .ThrowKeyword => "throw",
        .TrueKeyword => "true",
        .TryKeyword => "try",
        .TypeKeyword => "type",
        .TypeOfKeyword => "typeof",
        .UndefinedKeyword => "undefined",
        .UniqueKeyword => "unique",
        .UnknownKeyword => "unknown",
        .UsingKeyword => "using",
        .VarKeyword => "var",
        .VoidKeyword => "void",
        .WhileKeyword => "while",
        .WithKeyword => "with",
        .YieldKeyword => "yield",
        else => null,
    };
}
