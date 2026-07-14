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

pub fn encodeJsxCharacterEntity(allocator: std.mem.Allocator, b: *std.ArrayList(u8), charCode: u21) !void {
    try b.appendSlice(allocator, "&#x");
    var buf: [16]u8 = undefined;
    const hex = try std.fmt.bufPrint(&buf, "{X}", .{charCode});
    try b.appendSlice(allocator, hex);
    try b.append(allocator, ';');
}

pub fn encodeUtf16EscapeSequence(allocator: std.mem.Allocator, b: *std.ArrayList(u8), charCode: u21) !void {
    try b.appendSlice(allocator, "\\u");
    var buf: [16]u8 = undefined;
    const hex = try std.fmt.bufPrint(&buf, "{X}", .{charCode});
    var i: usize = hex.len;
    while (i < 4) : (i += 1) {
        try b.append(allocator, '0');
    }
    try b.appendSlice(allocator, hex);
}

pub fn escapeStringWorker(allocator: std.mem.Allocator, s: []const u8, quoteChar: QuoteChar, flags: u32, b: *std.ArrayList(u8)) !void {
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
            },
        }

        if (escape) {
            if (pos < i) {
                try b.appendSlice(allocator, s[pos..i]);
            }

            if ((flags & GetLiteralTextFlags.JsxAttributeEscape) != 0) {
                if (ch == 0) {
                    try b.appendSlice(allocator, "&#0;");
                } else if (getJsxEscapedChar(ch)) |match| {
                    try b.appendSlice(allocator, match);
                } else {
                    try encodeJsxCharacterEntity(allocator, b, ch);
                }
            } else {
                if (ch == '\r' and quoteChar == .Backtick and i + 1 < s.len and s[i + 1] == '\n') {
                    // size++ (need to skip '\n' later or what? Wait, the Go code just size++ and it is handled below i += size)
                    // For Zig, we handle next char manually. Let's say we increment i by 1
                    i += 1;
                    try b.appendSlice(allocator, "\\r\\n");
                } else if (ch > 0xFFFF) {
                    const ch_adjusted = ch - 0x10000;
                    try encodeUtf16EscapeSequence(allocator, b, ((ch_adjusted & 0b11111111110000000000) >> 10) + 0xD800);
                    try encodeUtf16EscapeSequence(allocator, b, (ch_adjusted & 0b00000000001111111111) + 0xDC00);
                } else if (ch >= 0xD800 and ch <= 0xDFFF) {
                    try encodeUtf16EscapeSequence(allocator, b, ch);
                } else if (ch == 0) {
                    if (i + 1 < s.len and std.ascii.isDigit(s[i + 1])) {
                        try b.appendSlice(allocator, "\\x00");
                    } else {
                        try b.appendSlice(allocator, "\\0");
                    }
                } else {
                    if (getEscapedChar(ch)) |match| {
                        try b.appendSlice(allocator, match);
                    } else {
                        try encodeUtf16EscapeSequence(allocator, b, ch);
                    }
                }
            }
            pos = i + len;
        }
        i += len;
    }

    if (pos < i) {
        try b.appendSlice(allocator, s[pos..i]);
    }
}

pub fn escapeString(allocator: std.mem.Allocator, s: []const u8, quoteChar: QuoteChar) ![]const u8 {
    var b = std.ArrayList(u8).empty;
    errdefer b.deinit(allocator);
    try b.ensureTotalCapacity(allocator, s.len + 2);
    try escapeStringWorker(allocator, s, quoteChar, GetLiteralTextFlags.NeverAsciiEscape, &b);
    return b.toOwnedSlice(allocator);
}

pub fn escapeNonAsciiString(allocator: std.mem.Allocator, s: []const u8, quoteChar: QuoteChar) ![]const u8 {
    var b = std.ArrayList(u8).empty;
    errdefer b.deinit(allocator);
    try b.ensureTotalCapacity(allocator, s.len + 2);
    try escapeStringWorker(allocator, s, quoteChar, GetLiteralTextFlags.None, &b);
    return b.toOwnedSlice(allocator);
}

pub fn escapeJsxAttributeString(allocator: std.mem.Allocator, s: []const u8, quoteChar: QuoteChar) ![]const u8 {
    var b = std.ArrayList(u8).empty;
    errdefer b.deinit(allocator);
    try b.ensureTotalCapacity(allocator, s.len + 2);
    try escapeStringWorker(allocator, s, quoteChar, GetLiteralTextFlags.JsxAttributeEscape | GetLiteralTextFlags.NeverAsciiEscape, &b);
    return b.toOwnedSlice(allocator);
}

pub fn getLiteralText(allocator: std.mem.Allocator, tree: *ast.Ast, nodeIndex: ast.NodeIndex, flags: u32) ![]const u8 {
    _ = allocator;
    _ = flags;
    return ast_utils.getTextOfNode(tree, nodeIndex);
}

pub fn isNotPrologueDirective(tree: *ast.Ast, nodeIndex: ast.NodeIndex) bool {
    return !ast_utils.isPrologueDirective(tree, nodeIndex);
}

pub fn isNewExpressionWithoutArguments(tree: *ast.Ast, nodeIndex: ast.NodeIndex) bool {
    if (tree.getNodeKind(nodeIndex) != .NewExpression) return false;
    const node = tree.getNode(nodeIndex).NewExpression;
    return node.Arguments == ast.null_node or node.Arguments == null;
}

pub fn greatestEnd(ends: []const u32) u32 {
    var max: u32 = 0;
    for (ends) |e| {
        if (e > max) max = e;
    }
    return max;
}

pub fn isImmediatelyInvokedFunctionExpressionOrArrowFunction(tree: *ast.Ast, nodeIndex: ast.NodeIndex) bool {
    var node = ast_utils.skipPartiallyEmittedExpressions(tree, nodeIndex);
    if (tree.getNodeKind(node) != .CallExpression) {
        return false;
    }
    const callExpr = tree.getNode(node).CallExpression;
    node = ast_utils.skipPartiallyEmittedExpressions(tree, callExpr.Expression);
    const kind = tree.getNodeKind(node);
    return kind == .FunctionExpression or kind == .ArrowFunction;
}

pub fn rangeIsOnSingleLine(tree: *ast.Ast, r: emitcontext.TextRange, sourceFileIndex: ast.NodeIndex) bool {
    _ = sourceFileIndex;
    if (r.pos > r.end or r.end > @as(i64, @intCast(tree.sourceText.len))) return false;
    const start: usize = @intCast(r.pos);
    const end: usize = @intCast(r.end);
    const text = tree.sourceText[start..end];
    return std.mem.indexOfAny(u8, text, "\r\n") == null;
}

pub fn rangeStartPositionsAreOnSameLine(tree: *ast.Ast, range1: emitcontext.TextRange, range2: emitcontext.TextRange, sourceFileIndex: ast.NodeIndex) bool {
    return positionsAreOnSameLine(tree, range1.pos, range2.pos, sourceFileIndex);
}

pub fn positionsAreOnSameLine(tree: *ast.Ast, pos1: i32, pos2: i32, sourceFileIndex: ast.NodeIndex) bool {
    _ = sourceFileIndex;
    if (pos1 < 0 or pos2 < 0) return false;
    const p1: usize = @intCast(pos1);
    const p2: usize = @intCast(pos2);
    if (p1 == p2) return true;

    const start = @min(p1, p2);
    const end = @max(p1, p2);
    if (start >= tree.sourceText.len) return false;
    const safe_end = @min(end, tree.sourceText.len);

    const slice = tree.sourceText[start..safe_end];
    return std.mem.indexOfAny(u8, slice, "\r\n") == null;
}

pub fn getLinesBetweenPositions(tree: *ast.Ast, pos1: i32, pos2: i32, sourceFileIndex: ast.NodeIndex) i32 {
    _ = sourceFileIndex;
    if (pos1 < 0 or pos2 < 0) return 0;
    const p1: usize = @intCast(pos1);
    const p2: usize = @intCast(pos2);
    if (p1 == p2) return 0;

    const start = @min(p1, p2);
    const end = @max(p1, p2);
    if (start >= tree.sourceText.len) return 0;
    const safe_end = @min(end, tree.sourceText.len);

    const slice = tree.sourceText[start..safe_end];
    var count: i32 = 0;
    for (slice) |c| {
        if (c == '\n') count += 1;
    }
    return count;
}

pub fn skipSynthesizedParentheses(tree: *ast.Ast, nodeIndex: ast.NodeIndex) ast.NodeIndex {
    var current = nodeIndex;
    while (tree.getNodeKind(current) == .ParenthesizedExpression and ast_utils.nodeIsSynthesized(tree, current)) {
        current = tree.getNode(current).ParenthesizedExpression.Expression;
    }
    return current;
}

pub fn isBinaryOperation(tree: *ast.Ast, nodeIndex: ast.NodeIndex, token: ast_gen.SyntaxKind) bool {
    if (tree.getNodeKind(nodeIndex) == .BinaryExpression) {
        return tree.getNode(nodeIndex).BinaryExpression.OperatorToken == token;
    }
    return false;
}

pub fn mixingBinaryOperatorsRequiresParentheses(a: ast_gen.SyntaxKind, b: ast_gen.SyntaxKind) bool {
    return a != b and
        (a != .AsteriskToken and a != .SlashToken or b != .AsteriskToken and b != .SlashToken) and
        (a != .PlusToken and a != .MinusToken or b != .PlusToken and b != .MinusToken);
}

pub fn isFileLevelUniqueName(tree: *ast.Ast, sourceFileIndex: ast.NodeIndex, name: []const u8, hasGlobalName: ?*const fn ([]const u8) bool) bool {
    _ = tree;
    _ = sourceFileIndex;
    if (hasGlobalName) |has_global| {
        if (has_global(name)) return false;
    }
    return true;
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
    if (commentKind == .SingleLineCommentTrivia and end - pos > 2) {
        if (text[pos + 1] == '/' and text[pos + 2] == '/') {
            const commentText = text[pos + 3 .. end];
            if (std.mem.indexOf(u8, commentText, "<reference") != null) return true;
            if (std.mem.indexOf(u8, commentText, "<amd-dependency") != null) return true;
            if (std.mem.indexOf(u8, commentText, "<amd-module") != null) return true;
        }
    }
    return false;
}

pub fn isJSDocLikeText(text: []const u8, commentKind: ast_gen.SyntaxKind, pos: usize, end: usize) bool {
    return commentKind == .MultiLineCommentTrivia and
        end - pos >= 5 and
        text[pos + 2] == '*' and
        text[pos + 3] != '/';
}

pub fn isPinnedComment(text: []const u8, commentKind: ast_gen.SyntaxKind, pos: usize, end: usize) bool {
    return commentKind == .MultiLineCommentTrivia and
        end - pos > 5 and
        text[pos + 2] == '!';
}

pub fn isLineBreak(ch: u21) bool {
    return ch == '\n' or ch == '\r' or ch == 0x2028 or ch == 0x2029;
}

pub fn containsParseError(tree: *ast.Ast, nodeIndex: ast.NodeIndex) bool {
    _ = tree;
    _ = nodeIndex;
    return false;
}

pub fn nodeIsSynthesized(tree: *ast.Ast, nodeIndex: ast.NodeIndex) bool {
    return ast_utils.nodeIsSynthesized(tree, nodeIndex);
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
