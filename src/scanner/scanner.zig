const std = @import("std");

pub fn getECMALineOfPosition(text: []const u8, pos: usize) i64 {
    const end = if (pos > text.len) text.len else pos;
    const slice = text[0..end];
    var line: i64 = 0;
    for (slice) |c| {
        if (c == '\n') {
            line += 1;
        }
    }
    return line;
}
const stringutil = @import("../stringutil/stringutil.zig");
const identifier_pkg = @import("../stringutil/identifier.zig");
const ast = @import("../ast/ast.zig");
const kind = @import("../ast/kind.zig");
const maps = @import("maps.zig");
const core = @import("../core/core.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");

pub const ErrorCallback = *const fn (ctx: ?*anyopaque, diagnostic: *const diagnostics.Message, start: usize, length: usize, args: []const []const u8) void;

pub const TokenFlags = struct {
    pub const None: u32 = 0;
    pub const PrecedingLineBreak: u32 = 1 << 0;
    pub const PrecedingJSDocComment: u32 = 1 << 1;
    pub const Unterminated: u32 = 1 << 2;
    pub const ExtendedUnicodeEscape: u32 = 1 << 3;
    pub const Scientific: u32 = 1 << 4;
    pub const Octal: u32 = 1 << 5;
    pub const HexSpecifier: u32 = 1 << 6;
    pub const BinarySpecifier: u32 = 1 << 7;
    pub const OctalSpecifier: u32 = 1 << 8;
    pub const ContainsSeparator: u32 = 1 << 9;
    pub const UnicodeEscape: u32 = 1 << 10;
    pub const ContainsInvalidEscape: u32 = 1 << 11;
    pub const ContainsInvalidStringEscape: u32 = 1 << 12; // HexEscape is TokenFlagsHexEscape = 1 << 12 in Go
    pub const ContainsLeadingZero: u32 = 1 << 13;
    pub const ContainsInvalidSeparator: u32 = 1 << 14;
    pub const PrecedingJSDocLeadingAsterisks: u32 = 1 << 15;
    pub const SingleQuote: u32 = 1 << 16;
    pub const PrecedingJSDocWithDeprecated: u32 = 1 << 17;
    pub const PrecedingJSDocWithSeeOrLink: u32 = 1 << 18;

    pub const BinaryOrOctalSpecifier: u32 = BinarySpecifier | OctalSpecifier;
    pub const NumericLiteralFlags: u32 = Scientific | Octal | ContainsLeadingZero | (HexSpecifier | BinaryOrOctalSpecifier) | ContainsSeparator | ContainsInvalidSeparator;
};

pub const ScannerState = struct {
    pos: usize,
    fullStartPos: usize,
    tokenStart: usize,
    token: kind.Kind,
    tokenValue: []const u8,
    tokenFlags: u32,
    skipJSDocLeadingAsterisks: usize,
};

pub const Scanner = struct {
    allocator: std.mem.Allocator,
    text: []const u8,
    end: usize,
    languageVariant: core.LanguageVariant,
    scriptTarget: core.ScriptTarget,
    onError: ?ErrorCallback,
    onErrorCtx: ?*anyopaque,
    skipTrivia: bool,

    state: ScannerState,
    containsNonASCII: bool,
    commentDirectives: std.ArrayList(ast.CommentDirective),

    pub fn init(allocator: std.mem.Allocator, text: []const u8) Scanner {
        return .{
            .allocator = allocator,
            .text = text,
            .end = text.len,
            .languageVariant = .Standard,
            .scriptTarget = .Latest,
            .onError = null,
            .onErrorCtx = null,
            .skipTrivia = true,
            .containsNonASCII = false,
            .commentDirectives = .empty,
            .state = .{
                .pos = 0,
                .fullStartPos = 0,
                .tokenStart = 0,
                .token = kind.Kind.Unknown,
                .tokenValue = "",
                .tokenFlags = 0,
                .skipJSDocLeadingAsterisks = 0,
            },
        };
    }

    // =========================================================================
    // Go 1:1 Parity - State Management & Getters
    // =========================================================================

    pub fn mark(self: *Scanner) ScannerState {
        return self.state;
    }

    pub fn rewind(self: *Scanner, state: ScannerState) void {
        self.state = state;
    }

    pub fn reset(self: *Scanner) void {
        self.state.pos = 0;
        self.state.fullStartPos = 0;
        self.state.tokenStart = 0;
        self.state.token = kind.Kind.Unknown;
        self.state.tokenValue = "";
        self.state.tokenFlags = 0;
        self.state.skipJSDocLeadingAsterisks = 0;
        self.containsNonASCII = false;
        self.commentDirectives.clearRetainingCapacity(self.allocator);
    }

    pub fn deinit(self: *Scanner) void {
        self.commentDirectives.deinit(self.allocator);
    }

    pub fn processCommentDirective(self: *Scanner, start: usize, end: usize, multiline: bool) void {
        var pos = start;
        if (multiline) {
            while (pos < end and (self.text[pos] == ' ' or self.text[pos] == '\t')) {
                pos += 1;
            }
            while (pos < end and (self.text[pos] == '/' or self.text[pos] == '*')) {
                pos += 1;
            }
        } else {
            pos += 2;
            while (pos < end and self.text[pos] == '/') {
                pos += 1;
            }
        }
        while (pos < end and (self.text[pos] == ' ' or self.text[pos] == '\t')) {
            pos += 1;
        }
        if (!(pos < end and self.text[pos] == '@')) {
            return;
        }
        pos += 1;
        var dir_kind: ast.CommentDirectiveKind = .Unknown;
        if (std.mem.startsWith(u8, self.text[pos..], "ts-expect-error")) {
            dir_kind = .ExpectError;
        } else if (std.mem.startsWith(u8, self.text[pos..], "ts-ignore")) {
            dir_kind = .Ignore;
        } else {
            return;
        }
        self.commentDirectives.append(self.allocator, .{
            .pos = @intCast(start),
            .end = @intCast(end),
            .kind = dir_kind,
        }) catch {};
    }

    pub fn resetPos(self: *Scanner, pos: usize) void {
        self.state.pos = pos;
        self.state.fullStartPos = pos;
        self.state.tokenStart = pos;
        self.state.token = kind.Kind.Unknown;
        self.state.tokenValue = "";
        self.state.tokenFlags = 0;
    }

    pub fn setSkipJSDocLeadingAsterisks(self: *Scanner, skip: bool) void {
        if (skip) {
            self.state.skipJSDocLeadingAsterisks += 1;
        } else {
            self.state.skipJSDocLeadingAsterisks -= 1;
        }
    }

    pub fn setSkipTrivia(self: *Scanner, skip: bool) void {
        self.skipTrivia = skip;
    }

    pub fn getToken(self: *const Scanner) kind.Kind {
        return self.state.token;
    }

    pub fn getTokenValue(self: *const Scanner) []const u8 {
        return self.state.tokenValue;
    }

    pub fn getTokenFlags(self: *const Scanner) u32 {
        return self.state.tokenFlags;
    }

    pub fn hasPrecedingJSDocComment(self: *const Scanner) bool {
        return (self.state.tokenFlags & TokenFlags.PrecedingJSDocComment) != 0;
    }

    pub fn hasPrecedingJSDocLeadingAsterisks(self: *const Scanner) bool {
        return (self.state.tokenFlags & TokenFlags.PrecedingJSDocLeadingAsterisks) != 0;
    }

    pub fn hasPrecedingJSDocWithDeprecatedTag(self: *const Scanner) bool {
        return (self.state.tokenFlags & TokenFlags.PrecedingJSDocWithDeprecated) != 0;
    }

    pub fn hasPrecedingJSDocWithSeeOrLink(self: *const Scanner) bool {
        return (self.state.tokenFlags & TokenFlags.PrecedingJSDocWithSeeOrLink) != 0;
    }

    pub fn getTokenStart(self: *const Scanner) usize {
        return self.state.tokenStart;
    }

    pub fn getTokenEnd(self: *const Scanner) usize {
        return self.state.pos;
    }

    pub fn getTokenFullStart(self: *const Scanner) usize {
        return self.state.fullStartPos;
    }

    pub fn getTokenText(self: *const Scanner) []const u8 {
        return self.text[self.state.tokenStart..self.state.pos];
    }

    inline fn char(self: *Scanner) u8 {
        if (self.state.pos >= self.end) return 0;
        return self.text[self.state.pos];
    }

    pub fn emitError(self: *Scanner, diagnostic: *const diagnostics.Message) void {
        self.errorAt(diagnostic, self.state.pos, 0, &[_][]const u8{});
    }

    pub fn errorAt(self: *Scanner, diagnostic: *const diagnostics.Message, pos: usize, length: usize, args: []const []const u8) void {
        if (self.onError) |cb| {
            cb(self.onErrorCtx, diagnostic, pos, length, args);
        }
    }

    pub fn scanInvalidCharacter(self: *Scanner) void {
        const size = if (self.state.pos < self.end) @as(usize, 1) else @as(usize, 0); // utf8 decode size needed later
        self.errorAt(&diagnostics.generated.Invalid_character, self.state.pos, size, &[_][]const u8{});
        self.state.pos += size;
        self.state.token = kind.Kind.Unknown;
    }

    fn isConflictMarkerTrivia(self: *Scanner, pos: usize) bool {
        if (pos + 1 >= self.end or self.text[pos + 1] != self.text[pos]) return false;

        const atLineStart = pos == 0 or self.text[pos - 1] == '\n' or self.text[pos - 1] == '\r';
        if (atLineStart) {
            const ch = self.text[pos];
            const markerLength = 7;
            if (pos + markerLength < self.end) {
                for (0..markerLength) |i| {
                    if (self.text[pos + i] != ch) return false;
                }
                return ch == '=' or self.text[pos + markerLength] == ' ';
            }
        }
        return false;
    }

    fn scanConflictMarkerTrivia(self: *Scanner, pos: usize) usize {
        self.errorAt(&diagnostics.generated.Merge_conflict_marker_encountered, pos, 7, &[_][]const u8{});
        const ch = self.text[pos];
        var current_pos = pos;

        if (ch == '<' or ch == '>') {
            while (current_pos < self.end) {
                const c = self.text[current_pos];
                if (c == '\n' or c == '\r') break;
                current_pos += 1;
            }
        } else {
            while (current_pos < self.end) {
                const c = self.text[current_pos];
                if ((c == '=' or c == '>') and c != ch and self.isConflictMarkerTrivia(current_pos)) {
                    break;
                }
                current_pos += 1;
            }
        }
        return current_pos;
    }

    inline fn charAt(self: *Scanner, offset: usize) u8 {
        if (self.state.pos + offset >= self.end) return 0;
        return self.text[self.state.pos + offset];
    }

    pub fn scan(self: *Scanner) kind.Kind {
        self.state.fullStartPos = self.state.pos;
        self.state.tokenFlags = TokenFlags.None;

        while (true) {
            const ch = self.char();
            self.state.tokenStart = self.state.pos;

            switch (ch) {
                0 => {
                    if (self.state.pos >= self.end) {
                        self.state.token = kind.Kind.EndOfFile;
                        return self.state.token;
                    }
                    self.state.pos += 1;
                },
                '\t', 0x0B, 0x0C, ' ' => {
                    self.state.pos += 1;
                    if (self.skipTrivia) continue;
                    while (self.state.pos < self.end) {
                        const next = self.char();
                        if (next != '\t' and next != 0x0B and next != 0x0C and next != ' ') break;
                        self.state.pos += 1;
                    }
                    self.state.token = kind.Kind.WhitespaceTrivia;
                    return self.state.token;
                },
                '\n', '\r' => {
                    self.state.tokenFlags |= TokenFlags.PrecedingLineBreak;
                    if (self.skipTrivia) {
                        self.state.pos += 1;
                        while (self.state.pos < self.end) {
                            const b = self.char();
                            if (b == ' ' or (b >= '\t' and b <= '\r')) {
                                self.state.pos += 1;
                            } else break;
                        }
                        continue;
                    }
                    if (ch == '\r' and self.charAt(1) == '\n') {
                        self.state.pos += 2;
                    } else {
                        self.state.pos += 1;
                    }
                    self.state.token = kind.Kind.NewLineTrivia;
                    return self.state.token;
                },
                '!' => {
                    if (self.charAt(1) == '=') {
                        if (self.charAt(2) == '=') {
                            self.state.pos += 3;
                            self.state.token = kind.Kind.ExclamationEqualsEqualsToken;
                        } else {
                            self.state.pos += 2;
                            self.state.token = kind.Kind.ExclamationEqualsToken;
                        }
                    } else {
                        self.state.pos += 1;
                        self.state.token = kind.Kind.ExclamationToken;
                    }
                    return self.state.token;
                },
                '%' => {
                    if (self.charAt(1) == '=') {
                        self.state.pos += 2;
                        self.state.token = kind.Kind.PercentEqualsToken;
                    } else {
                        self.state.pos += 1;
                        self.state.token = kind.Kind.PercentToken;
                    }
                    return self.state.token;
                },
                '&' => {
                    const next = self.charAt(1);
                    if (next == '&') {
                        if (self.charAt(2) == '=') {
                            self.state.pos += 3;
                            self.state.token = kind.Kind.AmpersandAmpersandEqualsToken;
                        } else {
                            self.state.pos += 2;
                            self.state.token = kind.Kind.AmpersandAmpersandToken;
                        }
                    } else if (next == '=') {
                        self.state.pos += 2;
                        self.state.token = kind.Kind.AmpersandEqualsToken;
                    } else {
                        self.state.pos += 1;
                        self.state.token = kind.Kind.AmpersandToken;
                    }
                    return self.state.token;
                },
                '(' => {
                    self.state.pos += 1;
                    self.state.token = kind.Kind.OpenParenToken;
                    return self.state.token;
                },
                ')' => {
                    self.state.pos += 1;
                    self.state.token = kind.Kind.CloseParenToken;
                    return self.state.token;
                },
                '*' => {
                    const next = self.charAt(1);
                    if (next == '=') {
                        self.state.pos += 2;
                        self.state.token = kind.Kind.AsteriskEqualsToken;
                    } else if (next == '*') {
                        if (self.charAt(2) == '=') {
                            self.state.pos += 3;
                            self.state.token = kind.Kind.AsteriskAsteriskEqualsToken;
                        } else {
                            self.state.pos += 2;
                            self.state.token = kind.Kind.AsteriskAsteriskToken;
                        }
                    } else {
                        self.state.pos += 1;
                        if (self.state.skipJSDocLeadingAsterisks != 0 and
                            (self.state.tokenFlags & TokenFlags.PrecedingJSDocLeadingAsterisks) == 0 and
                            (self.state.tokenFlags & TokenFlags.PrecedingLineBreak) != 0)
                        {
                            self.state.tokenFlags |= TokenFlags.PrecedingJSDocLeadingAsterisks;
                            continue;
                        }
                        self.state.token = kind.Kind.AsteriskToken;
                    }
                    return self.state.token;
                },
                '+' => {
                    const next = self.charAt(1);
                    if (next == '=') {
                        self.state.pos += 2;
                        self.state.token = kind.Kind.PlusEqualsToken;
                    } else if (next == '+') {
                        self.state.pos += 2;
                        self.state.token = kind.Kind.PlusPlusToken;
                    } else {
                        self.state.pos += 1;
                        self.state.token = kind.Kind.PlusToken;
                    }
                    return self.state.token;
                },
                ',' => {
                    self.state.pos += 1;
                    self.state.token = kind.Kind.CommaToken;
                    return self.state.token;
                },
                '-' => {
                    const next = self.charAt(1);
                    if (next == '=') {
                        self.state.pos += 2;
                        self.state.token = kind.Kind.MinusEqualsToken;
                    } else if (next == '-') {
                        self.state.pos += 2;
                        self.state.token = kind.Kind.MinusMinusToken;
                    } else {
                        self.state.pos += 1;
                        self.state.token = kind.Kind.MinusToken;
                    }
                    return self.state.token;
                },
                '.' => {
                    const next = self.charAt(1);
                    if (next >= '0' and next <= '9') {
                        self.state.token = self.scanNumber();
                    } else if (next == '.' and self.charAt(2) == '.') {
                        self.state.pos += 3;
                        self.state.token = kind.Kind.DotDotDotToken;
                    } else {
                        self.state.pos += 1;
                        self.state.token = kind.Kind.DotToken;
                    }
                    return self.state.token;
                },
                ':' => {
                    self.state.pos += 1;
                    self.state.token = kind.Kind.ColonToken;
                    return self.state.token;
                },
                ';' => {
                    self.state.pos += 1;
                    self.state.token = kind.Kind.SemicolonToken;
                    return self.state.token;
                },
                '<' => {
                    const next = self.charAt(1);
                    if (next == '=') {
                        self.state.pos += 2;
                        self.state.token = kind.Kind.LessThanEqualsToken;
                    } else if (next == '<') {
                        if (self.charAt(2) == '=') {
                            self.state.pos += 3;
                            self.state.token = kind.Kind.LessThanLessThanEqualsToken;
                        } else {
                            self.state.pos += 2;
                            self.state.token = kind.Kind.LessThanLessThanToken;
                        }
                    } else {
                        self.state.pos += 1;
                        self.state.token = kind.Kind.LessThanToken;
                    }
                    return self.state.token;
                },
                '=' => {
                    const next = self.charAt(1);
                    if (next == '=') {
                        const next2 = self.charAt(2);
                        if (next2 == '=') {
                            self.state.pos += 3;
                            self.state.token = kind.Kind.EqualsEqualsEqualsToken;
                        } else {
                            self.state.pos += 2;
                            self.state.token = kind.Kind.EqualsEqualsToken;
                        }
                    } else if (next == '>') {
                        self.state.pos += 2;
                        self.state.token = kind.Kind.EqualsGreaterThanToken;
                    } else {
                        self.state.pos += 1;
                        self.state.token = kind.Kind.EqualsToken;
                    }
                    return self.state.token;
                },
                '>' => {
                    self.state.pos += 1;
                    self.state.token = kind.Kind.GreaterThanToken;
                    return self.state.token;
                },
                '?' => {
                    if (self.charAt(1) == '.' and !std.ascii.isDigit(self.charAt(2))) {
                        self.state.pos += 2;
                        self.state.token = kind.Kind.QuestionDotToken;
                        return self.state.token;
                    } else if (self.charAt(1) == '?') {
                        if (self.charAt(2) == '=') {
                            self.state.pos += 3;
                            self.state.token = kind.Kind.QuestionQuestionEqualsToken;
                            return self.state.token;
                        } else {
                            self.state.pos += 2;
                            self.state.token = kind.Kind.QuestionQuestionToken;
                            return self.state.token;
                        }
                    } else {
                        self.state.pos += 1;
                        self.state.token = kind.Kind.QuestionToken;
                        return self.state.token;
                    }
                },
                '[' => {
                    self.state.pos += 1;
                    self.state.token = kind.Kind.OpenBracketToken;
                    return self.state.token;
                },
                ']' => {
                    self.state.pos += 1;
                    self.state.token = kind.Kind.CloseBracketToken;
                    return self.state.token;
                },
                '{' => {
                    self.state.pos += 1;
                    self.state.token = kind.Kind.OpenBraceToken;
                    return self.state.token;
                },
                '}' => {
                    self.state.pos += 1;
                    self.state.token = kind.Kind.CloseBraceToken;
                    return self.state.token;
                },
                '|' => {
                    if (self.charAt(1) == '|') {
                        self.state.pos += 2;
                        self.state.token = kind.Kind.BarBarToken;
                    } else {
                        self.state.pos += 1;
                        self.state.token = kind.Kind.BarToken;
                    }
                    return self.state.token;
                },
                '^' => {
                    self.state.pos += 1;
                    self.state.token = kind.Kind.CaretToken;
                    return self.state.token;
                },
                '~' => {
                    self.state.pos += 1;
                    self.state.token = kind.Kind.TildeToken;
                    return self.state.token;
                },
                '@' => {
                    self.state.pos += 1;
                    self.state.token = kind.Kind.AtToken;
                    return self.state.token;
                },
                '`' => {
                    self.state.token = self.scanTemplateAndSetTokenValue(false);
                    return self.state.token;
                },
                '#' => {
                    if (self.charAt(1) == '!') {
                        if (self.state.pos == 0) {
                            self.state.pos += 2;
                            while (self.state.pos < self.end) {
                                const c = self.char();
                                if (c == '\n' or c == '\r') {
                                    break;
                                }
                                self.state.pos += 1;
                            }
                            continue;
                        }
                        self.errorAt(&diagnostics.generated.X_can_only_be_used_at_the_start_of_a_file, self.state.pos, 2, &[_][]const u8{"#!"});
                        self.state.pos += 1;
                        self.state.token = kind.Kind.Unknown;
                        return self.state.token;
                    }

                    const start = self.state.pos;
                    self.state.pos += 1;
                    if (self.state.pos < self.end) {
                        const b = self.char();
                        if (b == ' ' or b == '\t' or (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z') or b == '_' or b == '$') {
                            while (self.state.pos < self.end) {
                                const c = self.char();
                                if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_' or c == '$') {
                                    self.state.pos += 1;
                                } else {
                                    break;
                                }
                            }
                            self.state.tokenValue = self.text[start..self.state.pos];
                            self.state.token = kind.Kind.PrivateIdentifier;
                            return self.state.token;
                        }
                    }
                    self.state.token = kind.Kind.HashToken;
                    return self.state.token;
                },
                '/' => {
                    const next = self.charAt(1);
                    if (next == '/') {
                        self.state.pos += 2;
                        while (self.state.pos < self.end) {
                            const c = self.char();
                            if (c == '\n' or c == '\r') break;
                            self.state.pos += 1;
                        }
                        self.processCommentDirective(self.state.tokenStart, self.state.pos, false);
                        if (self.skipTrivia) continue;
                        self.state.token = kind.Kind.SingleLineCommentTrivia;
                        return self.state.token;
                    } else if (next == '*') {
                        const isJSDoc = (self.charAt(2) != '/');
                        var lastLineStart = self.state.tokenStart;
                        self.state.pos += 2;
                        while (self.state.pos < self.end) {
                            const c = self.char();
                            if (c == '*' and self.charAt(1) == '/') {
                                self.state.pos += 2;
                                break;
                            }
                            const is_lb = stringutil.isLineBreak(c);
                            self.state.pos += 1;
                            if (is_lb) {
                                lastLineStart = self.state.pos;
                                self.state.tokenFlags |= TokenFlags.PrecedingLineBreak;
                            }
                        }
                        if (isJSDoc) {
                            self.state.tokenFlags |= TokenFlags.PrecedingJSDocComment;
                            self.scanJSDocCommentForTags(self.text[self.state.tokenStart..self.state.pos]);
                        }
                        self.processCommentDirective(lastLineStart, self.state.pos, true);
                        if (self.skipTrivia) continue;
                        self.state.token = kind.Kind.MultiLineCommentTrivia;
                        return self.state.token;
                    } else if (next == '=') {
                        self.state.pos += 2;
                        self.state.token = kind.Kind.SlashEqualsToken;
                    } else {
                        self.state.pos += 1;
                        self.state.token = kind.Kind.SlashToken;
                    }
                    return self.state.token;
                },
                'a'...'z', 'A'...'Z', '_', '$', '\\', '\x80'...'\xff' => {
                    if (ch == '\\') {
                        if (self.charAt(1) != 'u') {
                            self.state.pos += 1;
                            self.state.token = kind.Kind.Unknown;
                            return self.state.token;
                        }
                        const c2 = self.charAt(2);
                        if (c2 != '{' and !((c2 >= '0' and c2 <= '9') or (c2 >= 'a' and c2 <= 'f') or (c2 >= 'A' and c2 <= 'F'))) {
                            self.state.pos += 1;
                            self.state.token = kind.Kind.Unknown;
                            return self.state.token;
                        }
                    } else if (ch >= 0x80) {
                        const len = std.unicode.utf8ByteSequenceLength(self.text[self.state.pos]) catch 0;
                        if (len == 0 or self.state.pos + len > self.end) {
                            self.state.pos = self.end;
                            self.state.token = kind.Kind.NonTextFileMarkerTrivia;
                            return self.state.token;
                        }
                        _ = std.unicode.utf8Decode(self.text[self.state.pos .. self.state.pos + len]) catch {
                            self.state.pos = self.end;
                            self.state.token = kind.Kind.NonTextFileMarkerTrivia;
                            return self.state.token;
                        };
                    }
                    const start = self.state.pos;
                    while (self.state.pos < self.end) {
                        const b = self.char();
                        if ((b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z') or (b >= '0' and b <= '9') or b == '_' or b == '$') {
                            self.state.pos += 1;
                        } else if (b == '\\') {
                            if (self.charAt(1) == 'u') {
                                const c2 = self.charAt(2);
                                if (c2 != '{' and !((c2 >= '0' and c2 <= '9') or (c2 >= 'a' and c2 <= 'f') or (c2 >= 'A' and c2 <= 'F'))) {
                                    break;
                                }
                                self.state.pos += 2;
                            } else {
                                break;
                            }
                        } else if (b >= 0x80) {
                            const len = std.unicode.utf8ByteSequenceLength(self.text[self.state.pos]) catch 0;
                            if (len == 0 or self.state.pos + len > self.end) break;
                            _ = std.unicode.utf8Decode(self.text[self.state.pos .. self.state.pos + len]) catch break;
                            self.state.pos += len;
                        } else {
                            break;
                        }
                    }
                    self.state.tokenValue = self.unescapeIdentifier(self.text[start..self.state.pos]);
                    if (maps.textToKeyword.get(self.state.tokenValue)) |kw| {
                        self.state.token = kw;
                    } else {
                        self.state.token = kind.Kind.Identifier;
                    }
                    return self.state.token;
                },
                '0'...'9' => {
                    self.state.token = self.scanNumber();
                    return self.state.token;
                },
                '"', '\'' => {
                    self.state.tokenValue = self.scanString(false);
                    self.state.token = kind.Kind.StringLiteral;
                    return self.state.token;
                },
                else => {
                    self.state.pos += 1;
                    self.state.token = kind.Kind.Unknown;
                    return self.state.token;
                },
            }
        }
    }

    fn scanNumber(self: *Scanner) kind.Kind {
        const start = self.state.pos;

        if (self.char() == '0') {
            self.state.pos += 1;
            const next = self.char();
            if (next == 'x' or next == 'X') {
                self.state.pos += 1;
                self.scanHexDigits();
                self.state.tokenFlags |= TokenFlags.HexSpecifier;
                if (self.char() == 'n') {
                    self.state.pos += 1;
                    self.state.tokenValue = self.text[start..self.state.pos];
                    return kind.Kind.BigIntLiteral;
                }
                self.state.tokenValue = self.text[start..self.state.pos];
                return kind.Kind.NumericLiteral;
            }
            if (next == 'b' or next == 'B') {
                self.state.pos += 1;
                self.scanBinaryDigits();
                self.state.tokenFlags |= TokenFlags.BinarySpecifier;
                if (self.char() == 'n') {
                    self.state.pos += 1;
                    self.state.tokenValue = self.text[start..self.state.pos];
                    return kind.Kind.BigIntLiteral;
                }
                self.state.tokenValue = self.text[start..self.state.pos];
                return kind.Kind.NumericLiteral;
            }
            if (next == 'o' or next == 'O') {
                self.state.pos += 1;
                self.scanOctalDigits();
                self.state.tokenFlags |= TokenFlags.OctalSpecifier;
                if (self.char() == 'n') {
                    self.state.pos += 1;
                    self.state.tokenValue = self.text[start..self.state.pos];
                    return kind.Kind.BigIntLiteral;
                }
                self.state.tokenValue = self.text[start..self.state.pos];
                return kind.Kind.NumericLiteral;
            }
        }

        while (self.state.pos < self.end) {
            const b = self.char();
            if ((b >= '0' and b <= '9') or b == '_') {
                self.state.pos += 1;
            } else {
                break;
            }
        }

        if (self.char() == '.') {
            self.state.pos += 1;
            while (self.state.pos < self.end) {
                const b = self.char();
                if ((b >= '0' and b <= '9') or b == '_') {
                    self.state.pos += 1;
                } else {
                    break;
                }
            }
        }

        const c = self.char();
        if (c == 'e' or c == 'E') {
            self.state.pos += 1;
            const sign = self.char();
            if (sign == '+' or sign == '-') self.state.pos += 1;
            while (self.state.pos < self.end) {
                const eb = self.char();
                if ((eb >= '0' and eb <= '9') or eb == '_') {
                    self.state.pos += 1;
                } else {
                    break;
                }
            }
            self.state.tokenFlags |= TokenFlags.Scientific;
        }

        if (self.char() == 'n') {
            self.state.pos += 1;
            self.state.tokenValue = self.text[start..self.state.pos];
            return kind.Kind.BigIntLiteral;
        }
        self.state.tokenValue = self.text[start..self.state.pos];
        return kind.Kind.NumericLiteral;
    }

    fn scanHexDigits(self: *Scanner) void {
        while (self.state.pos < self.end) {
            const b = self.char();
            if ((b >= '0' and b <= '9') or (b >= 'a' and b <= 'f') or (b >= 'A' and b <= 'F') or b == '_') {
                self.state.pos += 1;
            } else {
                break;
            }
        }
    }

    fn scanBinaryDigits(self: *Scanner) void {
        while (self.state.pos < self.end) {
            const b = self.char();
            if (b == '0' or b == '1' or b == '_') {
                self.state.pos += 1;
            } else {
                break;
            }
        }
    }

    fn scanOctalDigits(self: *Scanner) void {
        while (self.state.pos < self.end) {
            const b = self.char();
            if ((b >= '0' and b <= '7') or b == '_') {
                self.state.pos += 1;
            } else {
                break;
            }
        }
    }

    fn scanString(self: *Scanner, jsxAttributeString: bool) []const u8 {
        const quote = self.char();
        if (quote == '\'') self.state.tokenFlags |= TokenFlags.SingleQuote;
        self.state.pos += 1;
        const start = self.state.pos;

        // Fast path for simple strings
        while (self.state.pos < self.end) {
            const ch = self.char();
            if (ch == quote) {
                const val = self.text[start..self.state.pos];
                self.state.pos += 1;
                return val;
            }
            if (ch == '\\') {
                if (!jsxAttributeString) {
                    // slow path placeholder (TODO: decode escape sequence)
                    self.state.pos += 2;
                    continue;
                }
            }
            if (ch == '\n' or ch == '\r') {
                if (!jsxAttributeString) {
                    self.state.tokenFlags |= TokenFlags.Unterminated;
                    break;
                }
            }
            self.state.pos += 1;
        }

        return self.text[start..self.state.pos];
    }

    pub fn hasPrecedingLineBreak(self: *const Scanner) bool {
        return (self.state.tokenFlags & TokenFlags.PrecedingLineBreak) != 0;
    }

    pub fn reScanAsteriskEqualsToken(self: *Scanner) kind.Kind {
        if (self.state.token != kind.Kind.AsteriskEqualsToken) {
            @panic("'reScanAsteriskEqualsToken' should only be called on a '*='");
        }
        self.state.pos = self.state.tokenStart + 1;
        self.state.token = kind.Kind.EqualsToken;
        return self.state.token;
    }

    pub fn reScanQuestionToken(self: *Scanner) kind.Kind {
        if (self.state.token != kind.Kind.QuestionQuestionToken) {
            @panic("'reScanQuestionToken' should only be called on a '??'");
        }
        self.state.pos = self.state.tokenStart + 1;
        self.state.token = kind.Kind.QuestionToken;
        return self.state.token;
    }

    pub fn reScanSlashToken(self: *Scanner) kind.Kind {
        if (self.state.token == kind.Kind.SlashToken or self.state.token == kind.Kind.SlashEqualsToken) {
            var p = self.state.tokenStart + 1;
            var inEscape = false;
            var inCharacterClass = false;

            var isTerminated = false;
            while (p < self.end) {
                const ch = self.text[p];
                if (ch == '\n' or ch == '\r') {
                    // Unterminated regex
                    self.state.tokenFlags |= TokenFlags.Unterminated;
                    break;
                }
                if (inEscape) {
                    inEscape = false;
                    p += 1;
                    continue;
                }
                if (ch == '/' and !inCharacterClass) {
                    isTerminated = true;
                    break;
                }
                if (ch == '[') {
                    inCharacterClass = true;
                } else if (ch == '\\') {
                    inEscape = true;
                } else if (ch == ']') {
                    inCharacterClass = false;
                }
                p += 1;
            }

            const endOfRegExpBody = p;
            if (isTerminated) {
                p += 1; // Consume closing slash

                // Consume flags
                while (p < self.end) {
                    const ch = self.text[p];
                    if ((ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z')) {
                        p += 1;
                    } else {
                        break;
                    }
                }
            } else if ((self.state.tokenFlags & TokenFlags.Unterminated) != 0) {
                p = self.state.tokenStart + 1;
                inEscape = false;
                var characterClassDepth: i32 = 0;
                var inDecimalQuantifier = false;
                var groupDepth: i32 = 0;
                while (p < endOfRegExpBody) {
                    const ch = self.text[p];
                    if (inEscape) {
                        inEscape = false;
                    } else if (ch == '\\') {
                        inEscape = true;
                    } else if (ch == '[') {
                        characterClassDepth += 1;
                    } else if (ch == ']' and characterClassDepth != 0) {
                        characterClassDepth -= 1;
                    } else if (characterClassDepth == 0) {
                        if (ch == '{') {
                            inDecimalQuantifier = true;
                        } else if (ch == '}' and inDecimalQuantifier) {
                            inDecimalQuantifier = false;
                        } else if (!inDecimalQuantifier) {
                            if (ch == '(') {
                                groupDepth += 1;
                            } else if (ch == ')' and groupDepth != 0) {
                                groupDepth -= 1;
                            } else if (ch == ')' or ch == ']' or ch == '}') {
                                break;
                            }
                        }
                    }
                    p += 1;
                }
                while (p > self.state.tokenStart + 1) {
                    const prev_ch = self.text[p - 1];
                    if (stringutil.isWhiteSpaceLike(@as(u21, prev_ch)) or prev_ch == ';') {
                        p -= 1;
                    } else {
                        break;
                    }
                }
            }

            self.state.pos = p;
            self.state.token = kind.Kind.RegularExpressionLiteral;
            self.state.tokenValue = self.text[self.state.tokenStart..self.state.pos];
        }
        return self.state.token;
    }
    pub fn scanTemplateAndSetTokenValue(self: *Scanner, isTaggedTemplate: bool) kind.Kind {
        _ = isTaggedTemplate;
        const startedWithBacktick = self.char() == '`';
        self.state.pos += 1;
        var start = self.state.pos;
        var parts = std.ArrayListUnmanaged([]const u8).empty;
        defer parts.deinit(self.allocator);
        var token: kind.Kind = undefined;

        while (true) {
            while (self.state.pos < self.end) {
                const b = self.char();
                if (b == '`' or b == '$' or b == '\\' or b == '\r') {
                    break;
                }
                self.state.pos += 1;
            }
            const ch = self.char();
            if (ch == 0 or ch == '`') {
                parts.append(self.allocator, self.text[start..self.state.pos]) catch unreachable;
                if (ch == '`') {
                    self.state.pos += 1;
                } else {
                    self.state.tokenFlags |= TokenFlags.Unterminated;
                }
                token = if (startedWithBacktick) kind.Kind.NoSubstitutionTemplateLiteral else kind.Kind.TemplateTail;
                break;
            }
            if (ch == '$' and self.charAt(1) == '{') {
                parts.append(self.allocator, self.text[start..self.state.pos]) catch unreachable;
                self.state.pos += 2;
                token = if (startedWithBacktick) kind.Kind.TemplateHead else kind.Kind.TemplateMiddle;
                break;
            }
            if (ch == '\\') {
                var next_pos: usize = self.state.pos;
                const escape_start = self.state.pos;
                const valid = validateTemplateEscape(self.text, escape_start, &next_pos);
                if (!valid) {
                    self.state.tokenFlags |= TokenFlags.ContainsInvalidEscape;
                }
                parts.append(self.allocator, self.text[start..next_pos]) catch unreachable;
                self.state.pos = next_pos;
                start = self.state.pos;
                continue;
            }
            if (ch == '\r') {
                parts.append(self.allocator, self.text[start..self.state.pos]) catch unreachable;
                self.state.pos += 1;
                if (self.char() == '\n') {
                    self.state.pos += 1;
                }
                parts.append(self.allocator, "\n") catch unreachable;
                start = self.state.pos;
                continue;
            }
            self.state.pos += 1;
        }

        var total_len: usize = 0;
        for (parts.items) |part| {
            total_len += part.len;
        }
        var buf = self.allocator.alloc(u8, total_len) catch unreachable;
        var offset: usize = 0;
        for (parts.items) |part| {
            @memcpy(buf[offset .. offset + part.len], part);
            offset += part.len;
        }
        self.state.tokenValue = buf;
        return token;
    }

    pub fn reScanTemplateToken(self: *Scanner, isTaggedTemplate: bool) kind.Kind {
        self.state.pos = self.state.tokenStart;
        self.state.tokenFlags &= ~TokenFlags.Unterminated;
        self.state.token = self.scanTemplateAndSetTokenValue(!isTaggedTemplate);
        return self.state.token;
    }

    pub fn reScanHashToken(self: *Scanner) kind.Kind {
        if (self.state.token == kind.Kind.PrivateIdentifier) {
            self.state.pos = self.state.tokenStart + 1;
            self.state.token = kind.Kind.HashToken;
        }
        return self.state.token;
    }

    pub fn reScanGreaterThanToken(self: *Scanner) kind.Kind {
        if (self.state.token == kind.Kind.GreaterThanToken) {
            self.state.pos = self.state.tokenStart + 1;
            if (self.char() == '>') {
                if (self.charAt(1) == '>') {
                    if (self.charAt(2) == '=') {
                        self.state.pos += 3;
                        self.state.token = kind.Kind.GreaterThanGreaterThanGreaterThanEqualsToken;
                    } else {
                        self.state.pos += 2;
                        self.state.token = kind.Kind.GreaterThanGreaterThanGreaterThanToken;
                    }
                } else if (self.charAt(1) == '=') {
                    self.state.pos += 2;
                    self.state.token = kind.Kind.GreaterThanGreaterThanEqualsToken;
                } else {
                    self.state.pos += 1;
                    self.state.token = kind.Kind.GreaterThanGreaterThanToken;
                }
            } else if (self.char() == '=') {
                self.state.pos += 1;
                self.state.token = kind.Kind.GreaterThanEqualsToken;
            }
        }
        return self.state.token;
    }

    // =========================================================================
    // Go 1:1 Parity - JSDoc Scanning
    // =========================================================================

    pub fn canFollowJSDocAt(self: *const Scanner) bool {
        if (self.state.pos >= self.text.len) {
            return true;
        }
        const c_info = getUtf8CodePoint(self.text, self.state.pos);
        return identifier_pkg.isIdentifierStart(c_info.code_point, 0) or
            stringutil.isWhiteSpaceSingleLine(c_info.code_point) or
            stringutil.isLineBreak(c_info.code_point);
    }

    pub fn scanJSDocToken(self: *Scanner) kind.Kind {
        self.state.fullStartPos = self.state.pos;
        self.state.tokenFlags = TokenFlags.None;

        if (self.state.pos >= self.end) {
            self.state.token = kind.Kind.EndOfFile;
            return self.state.token;
        }

        self.state.tokenStart = self.state.pos;
        const ch = self.char();
        self.state.pos += 1;

        switch (ch) {
            '\t', '\x0B', '\x0C', ' ' => {
                while (self.state.pos < self.end) {
                    const ch2 = self.char();
                    if (ch2 != '\t' and ch2 != '\x0B' and ch2 != '\x0C' and ch2 != ' ') break;
                    self.state.pos += 1;
                }
                self.state.token = kind.Kind.WhitespaceTrivia;
                return self.state.token;
            },
            '@' => {
                self.state.token = kind.Kind.AtToken;
                return self.state.token;
            },
            '\r' => {
                if (self.char() == '\n') {
                    self.state.pos += 1;
                }
                self.state.tokenFlags |= TokenFlags.PrecedingLineBreak;
                self.state.token = kind.Kind.NewLineTrivia;
                return self.state.token;
            },
            '\n' => {
                self.state.tokenFlags |= TokenFlags.PrecedingLineBreak;
                self.state.token = kind.Kind.NewLineTrivia;
                return self.state.token;
            },
            '*' => {
                self.state.token = kind.Kind.AsteriskToken;
                return self.state.token;
            },
            '{' => {
                self.state.token = kind.Kind.OpenBraceToken;
                return self.state.token;
            },
            '}' => {
                self.state.token = kind.Kind.CloseBraceToken;
                return self.state.token;
            },
            '[' => {
                self.state.token = kind.Kind.OpenBracketToken;
                return self.state.token;
            },
            ']' => {
                self.state.token = kind.Kind.CloseBracketToken;
                return self.state.token;
            },
            '<' => {
                self.state.token = kind.Kind.LessThanToken;
                return self.state.token;
            },
            '>' => {
                self.state.token = kind.Kind.GreaterThanToken;
                return self.state.token;
            },
            '=' => {
                self.state.token = kind.Kind.EqualsToken;
                return self.state.token;
            },
            ',' => {
                self.state.token = kind.Kind.CommaToken;
                return self.state.token;
            },
            '.' => {
                self.state.token = kind.Kind.DotToken;
                return self.state.token;
            },
            '`' => {
                self.state.token = kind.Kind.BacktickToken;
                return self.state.token;
            },
            'a'...'z', 'A'...'Z', '_', '$' => {
                // Simplified identifier scanning for JSDoc
                while (self.state.pos < self.end) {
                    const ch2 = self.char();
                    if ((ch2 >= 'a' and ch2 <= 'z') or (ch2 >= 'A' and ch2 <= 'Z') or (ch2 >= '0' and ch2 <= '9') or ch2 == '_' or ch2 == '$') {
                        self.state.pos += 1;
                    } else {
                        break;
                    }
                }
                self.state.tokenValue = self.unescapeIdentifier(self.text[self.state.tokenStart..self.state.pos]);
                self.state.token = kind.Kind.Identifier;
                return self.state.token;
            },
            else => {
                self.state.token = kind.Kind.Unknown;
                return self.state.token;
            },
        }
    }

    fn hasJSDocTag(text: []const u8, tag: []const u8) bool {
        if (!std.mem.startsWith(u8, text, tag)) {
            return false;
        }
        if (text.len == tag.len) {
            return true;
        }
        const ch = text[tag.len];
        return ch == ' ' or ch == '\t' or ch == '\n' or ch == '\r' or ch == '}' or ch == '*';
    }

    fn scanJSDocCommentForTags(self: *Scanner, comment_text: []const u8) void {
        var text = comment_text;
        while (true) {
            const idx = std.mem.indexOfScalar(u8, text, '@') orelse return;
            text = text[idx + 1 ..];
            if ((self.state.tokenFlags & TokenFlags.PrecedingJSDocWithDeprecated) == 0 and hasJSDocTag(text, "deprecated")) {
                self.state.tokenFlags |= TokenFlags.PrecedingJSDocWithDeprecated;
            }
            if ((self.state.tokenFlags & TokenFlags.PrecedingJSDocWithSeeOrLink) == 0 and
                (hasJSDocTag(text, "see") or hasJSDocTag(text, "link") or hasJSDocTag(text, "linkcode") or hasJSDocTag(text, "linkplain")))
            {
                self.state.tokenFlags |= TokenFlags.PrecedingJSDocWithSeeOrLink;
            }
            if ((self.state.tokenFlags & (TokenFlags.PrecedingJSDocWithDeprecated | TokenFlags.PrecedingJSDocWithSeeOrLink)) ==
                (TokenFlags.PrecedingJSDocWithDeprecated | TokenFlags.PrecedingJSDocWithSeeOrLink))
            {
                return;
            }
        }
    }

    pub fn scanJSDocCommentTextToken(self: *Scanner, inBackticks: bool) kind.Kind {
        self.state.fullStartPos = self.state.pos;
        self.state.tokenFlags = TokenFlags.None;
        if (self.state.pos >= self.end) {
            self.state.token = kind.Kind.EndOfFile;
            return self.state.token;
        }
        self.state.tokenStart = self.state.pos;
        while (self.state.pos < self.end) {
            const ch = self.char();
            if (ch == '\n' or ch == '\r' or ch == '`') {
                break;
            }
            if (!inBackticks) {
                if (ch == '{') {
                    break;
                } else if (ch == '@' and self.state.pos > 0) {
                    const preceding = self.text[self.state.pos - 1];
                    if (preceding == ' ' or preceding == '\t') {
                        if (self.state.pos + 1 < self.end) {
                            const next_ch = self.charAt(1);
                            if (identifier_pkg.isIdentifierStart(next_ch, 0)) {
                                break;
                            }
                        }
                    }
                }
            }
            const len = std.unicode.utf8ByteSequenceLength(self.text[self.state.pos]) catch 1;
            if (self.state.pos + len <= self.end) {
                self.state.pos += len;
            } else {
                self.state.pos = self.end;
            }
        }
        if (self.state.pos == self.state.tokenStart) {
            return self.scanJSDocToken();
        }
        self.state.tokenValue = self.text[self.state.tokenStart..self.state.pos];
        self.state.token = kind.Kind.JSDocCommentTextToken;
        return self.state.token;
    }

    // =========================================================================
    // JSX Scanning — ported 1:1 from Go scanner.go
    // =========================================================================

    pub fn reScanJsxToken(self: *Scanner, allowMultilineJsxText: bool) kind.Kind {
        self.state.pos = self.state.fullStartPos;
        self.state.tokenStart = self.state.fullStartPos;
        self.state.token = self.scanJsxTokenEx(allowMultilineJsxText);
        return self.state.token;
    }

    pub fn scanJsxToken(self: *Scanner) kind.Kind {
        return self.scanJsxTokenEx(true);
    }

    pub fn scanJsxTokenEx(self: *Scanner, allowMultilineJsxText: bool) kind.Kind {
        self.state.fullStartPos = self.state.pos;
        self.state.tokenStart = self.state.pos;
        if (self.state.pos >= self.end) {
            self.state.token = kind.Kind.EndOfFile;
            return self.state.token;
        }
        const ch = self.char();
        switch (ch) {
            '<' => {
                if (self.state.pos + 1 < self.end and self.text[self.state.pos + 1] == '/') {
                    self.state.pos += 2;
                    self.state.token = kind.Kind.LessThanSlashToken;
                } else {
                    self.state.pos += 1;
                    self.state.token = kind.Kind.LessThanToken;
                }
            },
            '{' => {
                self.state.pos += 1;
                self.state.token = kind.Kind.OpenBraceToken;
            },
            else => {
                // Scan JSX text content
                var firstNonWhitespace: i64 = 0;
                while (self.state.pos < self.end) {
                    const c = self.text[self.state.pos];
                    if (c == '{' or c == '<') break;
                    if (c == '>') {
                        // error: unexpected >
                        self.state.pos += 1;
                        continue;
                    } else if (c == '}') {
                        // error: unexpected }
                        self.state.pos += 1;
                        continue;
                    }
                    const isLineBreak = (c == '\n' or c == '\r' or c == 0x2028 or c == 0x2029);
                    if (isLineBreak and firstNonWhitespace == 0) {
                        firstNonWhitespace = -1;
                    } else if (!allowMultilineJsxText and isLineBreak and firstNonWhitespace > 0) {
                        break;
                    } else if (!stringutil.isWhiteSpaceLike(@as(u21, c))) {
                        if (firstNonWhitespace == -1) firstNonWhitespace = 0;
                        if (firstNonWhitespace == 0) firstNonWhitespace = @as(i64, @intCast(self.state.pos));
                    }
                    self.state.pos += 1;
                }
                self.state.tokenValue = self.text[self.state.fullStartPos..self.state.pos];
                self.state.token = kind.Kind.JsxText;
                if (firstNonWhitespace == -1) {
                    self.state.token = kind.Kind.JsxTextAllWhiteSpaces;
                }
            },
        }
        return self.state.token;
    }

    /// Scans a JSX identifier — same as normal identifier but allows '-' in the middle
    pub fn scanJsxIdentifier(self: *Scanner) kind.Kind {
        if (self.state.token == kind.Kind.Identifier or kind.isKeyword(self.state.token)) {
            while (self.state.pos < self.end) {
                const c = self.text[self.state.pos];
                if (c == '-') {
                    // append '-' to current token value
                    const old = self.state.tokenValue;
                    var buf = std.ArrayListUnmanaged(u8).empty;
                    buf.appendSlice(self.allocator, old) catch break;
                    buf.append(self.allocator, '-') catch break;
                    self.state.pos += 1;
                    // scan more identifier parts
                    const parts = self.scanIdentifierParts();
                    buf.appendSlice(self.allocator, parts) catch {};
                    self.state.tokenValue = buf.toOwnedSlice(self.allocator) catch old;
                } else {
                    const oldPos = self.state.pos;
                    const old = self.state.tokenValue;
                    const parts = self.scanIdentifierParts();
                    if (self.state.pos == oldPos) break;
                    var buf = std.ArrayListUnmanaged(u8).empty;
                    buf.appendSlice(self.allocator, old) catch break;
                    buf.appendSlice(self.allocator, parts) catch {};
                    self.state.tokenValue = buf.toOwnedSlice(self.allocator) catch old;
                }
            }
            self.state.token = maps.textToKeyword.get(self.state.tokenValue) orelse kind.Kind.Identifier;
        }
        return self.state.token;
    }

    /// Scans a JSX attribute value (string literal after '=')
    pub fn scanJsxAttributeValue(self: *Scanner) kind.Kind {
        self.state.fullStartPos = self.state.pos;
        // Skip whitespace
        while (self.state.pos < self.end and stringutil.isWhiteSpaceLike(@as(u21, self.text[self.state.pos]))) {
            self.state.pos += 1;
        }
        self.state.tokenStart = self.state.pos;
        if (self.state.pos < self.end) {
            const c = self.text[self.state.pos];
            if (c == '"' or c == '\'') {
                self.state.tokenValue = self.scanString(true);
                self.state.token = kind.Kind.StringLiteral;
                return self.state.token;
            }
        }
        return self.scan();
    }

    pub fn scanIdentifierParts(self: *Scanner) []const u8 {
        const start = self.state.pos;
        while (self.state.pos < self.end) {
            const ch = self.char();
            if (identifier_pkg.isIdentifierPart(@as(u21, ch), @as(u8, @intCast(@intFromEnum(self.scriptTarget))))) {
                self.state.pos += 1;
                continue;
            }
            if (ch > 127) {
                // Approximate size handling
                self.state.pos += 1;
                continue;
            }
            break;
        }
        return self.text[start..self.state.pos];
    }

    pub fn unescapeIdentifier(self: *Scanner, value: []const u8) []const u8 {
        var has_escape = false;
        for (value) |c| {
            if (c == '\\') {
                has_escape = true;
                break;
            }
        }
        if (!has_escape) return value;
        var buf = std.ArrayListUnmanaged(u8).empty;
        var i: usize = 0;
        while (i < value.len) {
            if (value[i] == '\\' and i + 1 < value.len and value[i + 1] == 'u') {
                i += 2;
                var cp: u32 = 0;
                if (i < value.len and value[i] == '{') {
                    i += 1;
                    while (i < value.len and value[i] != '}') : (i += 1) {
                        const c = value[i];
                        cp = cp * 16 + (if (c >= '0' and c <= '9') c - '0' else if (c >= 'a' and c <= 'f') c - 'a' + 10 else if (c >= 'A' and c <= 'F') c - 'A' + 10 else @as(u32, 0));
                    }
                    if (i < value.len and value[i] == '}') i += 1;
                } else {
                    var j: usize = 0;
                    while (j < 4 and i < value.len) : (j += 1) {
                        const c = value[i];
                        cp = cp * 16 + (if (c >= '0' and c <= '9') c - '0' else if (c >= 'a' and c <= 'f') c - 'a' + 10 else if (c >= 'A' and c <= 'F') c - 'A' + 10 else @as(u32, 0));
                        i += 1;
                    }
                }
                if (cp > 0 and cp <= 0x10FFFF) {
                    var out: [4]u8 = undefined;
                    if (std.unicode.utf8Encode(@as(u21, @intCast(cp)), &out)) |len| {
                        buf.appendSlice(self.allocator, out[0..len]) catch {};
                    } else |_| {}
                }
            } else {
                buf.append(self.allocator, value[i]) catch {};
                i += 1;
            }
        }
        return buf.toOwnedSlice(self.allocator) catch value;
    }
};

pub fn skipTrivia(text: []const u8, pos: usize) usize {
    var p = pos;
    while (p < text.len) {
        const c = text[p];
        if (c == ' ' or c == '\t' or c == '\r' or c == '\n') {
            p += 1;
        } else {
            break;
        }
    }
    return p;
}

pub const SkipTriviaOptions = struct {
    stopAtComments: bool = false,
    inJSDoc: bool = false,
};

pub fn skipTriviaEx(text: []const u8, pos: usize, options: SkipTriviaOptions) usize {
    _ = options;
    return skipTrivia(text, pos);
}

pub fn getTokenPosOfNode(tree: *ast.Ast, node: ast.NodeIndex, includeJSDoc: bool) u32 {
    _ = includeJSDoc; // JSDoc not fully supported yet in AST nodes
    if (tree.positions.items[node].pos == tree.positions.items[node].end) {
        return tree.positions.items[node].pos;
    }
    const nodeTag = std.meta.activeTag(tree.getNode(node));
    if (nodeTag == .JsxText) {
        return skipTriviaEx(tree.sourceText, tree.positions.items[node].pos, .{ .stopAtComments = true });
    }
    const nodeFlags = tree.getNodeFlags(node);
    const inJSDoc = nodeFlags & @import("../ast/ast_utils.zig").NodeFlags.JSDoc != 0;
    return skipTriviaEx(tree.sourceText, tree.positions.items[node].pos, .{ .inJSDoc = inJSDoc });
}

// =========================================================================
// JSDoc and Comment Ranges Parsing Helpers
// =========================================================================

pub const CommentRange = struct {
    pos: u32,
    end: u32,
    kind: kind.Kind,
    hasTrailingNewLine: bool,
};

pub fn getLeadingCommentRanges(allocator: std.mem.Allocator, commentRanges: *std.ArrayList(CommentRange), text: []const u8, pos: u32) !void {
    try getCommentRanges(allocator, commentRanges, text, pos, false, false);
}

pub fn getLeadingCommentRangesFromFullStart(allocator: std.mem.Allocator, commentRanges: *std.ArrayList(CommentRange), text: []const u8, pos: u32) !void {
    try getCommentRanges(allocator, commentRanges, text, pos, false, true);
}

pub fn getTrailingCommentRanges(allocator: std.mem.Allocator, commentRanges: *std.ArrayList(CommentRange), text: []const u8, pos: u32) !void {
    try getCommentRanges(allocator, commentRanges, text, pos, true, true);
}

pub fn getCommentRanges(allocator: std.mem.Allocator, commentRanges: *std.ArrayList(CommentRange), text: []const u8, start_pos: u32, trailing: bool, collect_at_start: bool) !void {
    var pos = start_pos;
    var pendingPos: u32 = 0;
    var pendingEnd: u32 = 0;
    var pendingKind: kind.Kind = .Unknown;
    var pendingHasTrailingNewLine = false;
    var hasPendingCommentRange = false;
    var collecting = collect_at_start;
    if (pos == 0) {
        collecting = true;
        if (isShebangTrivia(text, pos)) {
            pos = scanShebangTrivia(text, pos);
        }
    }

    while (pos < text.len) {
        const ch_info = getUtf8CodePoint(text, pos);
        const ch = ch_info.code_point;
        const size = ch_info.size;

        switch (ch) {
            '\r' => {
                if (pos + 1 < text.len and text[pos + 1] == '\n') {
                    pos += 1;
                }
                pos += 1;
                if (trailing) {
                    break;
                }
                collecting = true;
                if (hasPendingCommentRange) {
                    pendingHasTrailingNewLine = true;
                }
                continue;
            },
            '\n' => {
                pos += 1;
                if (trailing) {
                    break;
                }
                collecting = true;
                if (hasPendingCommentRange) {
                    pendingHasTrailingNewLine = true;
                }
                continue;
            },
            '\t', 0x0B, 0x0C, ' ' => {
                pos += 1;
                continue;
            },
            '/' => {
                var nextChar: u8 = 0;
                if (pos + 1 < text.len) {
                    nextChar = text[pos + 1];
                }
                var hasTrailingNewLine = false;
                if (nextChar == '/' or nextChar == '*') {
                    const k: kind.Kind = if (nextChar == '/') .SingleLineCommentTrivia else .MultiLineCommentTrivia;
                    const startPos = pos;
                    pos += 2;
                    if (nextChar == '/') {
                        while (pos < text.len) {
                            const c_info = getUtf8CodePoint(text, pos);
                            if (stringutil.isLineBreak(c_info.code_point)) {
                                hasTrailingNewLine = true;
                                break;
                            }
                            pos += c_info.size;
                        }
                    } else {
                        if (std.mem.indexOfPos(u8, text, pos, "*/")) |idx| {
                            pos = @as(u32, @intCast(idx + 2));
                        } else {
                            pos = @as(u32, @intCast(text.len));
                        }
                    }

                    if (collecting) {
                        if (hasPendingCommentRange) {
                            try commentRanges.append(allocator, .{
                                .pos = pendingPos,
                                .end = pendingEnd,
                                .kind = pendingKind,
                                .hasTrailingNewLine = pendingHasTrailingNewLine,
                            });
                        }
                        pendingPos = startPos;
                        pendingEnd = pos;
                        pendingKind = k;
                        pendingHasTrailingNewLine = hasTrailingNewLine;
                        hasPendingCommentRange = true;
                    }
                    continue;
                }
                break;
            },
            else => {
                if (ch > 127 and stringutil.isWhiteSpaceLike(ch)) {
                    if (hasPendingCommentRange and stringutil.isLineBreak(ch)) {
                        pendingHasTrailingNewLine = true;
                    }
                    pos += size;
                    continue;
                }
                break;
            },
        }
    }

    if (hasPendingCommentRange) {
        try commentRanges.append(allocator, .{
            .pos = pendingPos,
            .end = pendingEnd,
            .kind = pendingKind,
            .hasTrailingNewLine = pendingHasTrailingNewLine,
        });
    }
}

pub fn isShebangTrivia(text: []const u8, pos: u32) bool {
    if (text.len < 2) return false;
    std.debug.assert(pos == 0); // Shebangs check must only be done at the start of the file
    return text[0] == '#' and text[1] == '!';
}

pub fn scanShebangTrivia(text: []const u8, start_pos: u32) u32 {
    var pos = start_pos + 2;
    while (pos < text.len) {
        const c_info = getUtf8CodePoint(text, pos);
        if (stringutil.isLineBreak(c_info.code_point)) {
            break;
        }
        pos += c_info.size;
    }
    return pos;
}

const Utf8Info = struct {
    code_point: u21,
    size: u3,
};

pub fn getUtf8CodePoint(text: []const u8, pos: usize) Utf8Info {
    const remaining = text[pos..];
    if (remaining.len == 0) return .{ .code_point = 0, .size = 0 };
    const first = remaining[0];
    if (first < 128) {
        return .{ .code_point = first, .size = 1 };
    }
    const len = std.unicode.utf8ByteSequenceLength(first) catch return .{ .code_point = first, .size = 1 };
    if (len > remaining.len) {
        return .{ .code_point = first, .size = 1 };
    }
    const cp = std.unicode.utf8Decode(remaining[0..len]) catch return .{ .code_point = first, .size = 1 };
    return .{ .code_point = cp, .size = @as(u3, @intCast(len)) };
}

pub fn getJSDocCommentRanges(allocator: std.mem.Allocator, commentRanges: *std.ArrayList(CommentRange), tree: *ast.Ast, node: ast.NodeIndex, text: []const u8) !void {
    const nodeTag = std.meta.activeTag(tree.getNode(node));
    const nodePos = tree.positions.items[node].pos;
    const nodeEnd = tree.positions.items[node].end;

    switch (nodeTag) {
        .Parameter, .TypeParameter, .FunctionExpression, .ArrowFunction, .ParenthesizedExpression, .VariableDeclaration, .ExportSpecifier => {
            try getTrailingCommentRanges(allocator, commentRanges, text, nodePos);
            try getLeadingCommentRanges(allocator, commentRanges, text, nodePos);
        },
        else => {
            try getLeadingCommentRanges(allocator, commentRanges, text, nodePos);
        },
    }

    // Filter out comments that don't match the JSDoc criteria
    var i: usize = 0;
    while (i < commentRanges.items.len) {
        const comment = commentRanges.items[i];
        const commentLen = comment.end - comment.pos;
        const shouldDelete = comment.end > nodeEnd or
            commentLen < 4 or
            text[comment.pos + 1] != '*' or
            text[comment.pos + 2] != '*' or
            text[comment.pos + 3] == '/';

        if (shouldDelete) {
            _ = commentRanges.orderedRemove(i);
        } else {
            i += 1;
        }
    }
}

fn validateTemplateEscape(text: []const u8, start: usize, pos_ptr: *usize) bool {
    var p = start + 1;
    if (p >= text.len) {
        pos_ptr.* = text.len;
        return false;
    }
    const ch = text[p];
    p += 1;
    switch (ch) {
        '0' => {
            if (p < text.len and text[p] >= '0' and text[p] <= '9') {
                pos_ptr.* = p + 1;
                return false;
            }
            pos_ptr.* = p;
            return true;
        },
        '1'...'7' => {
            if (p < text.len and text[p] >= '0' and text[p] <= '7') {
                p += 1;
            }
            pos_ptr.* = p;
            return false;
        },
        '8', '9' => {
            pos_ptr.* = p;
            return false;
        },
        'b', 't', 'n', 'v', 'f', 'r', '\'', '"', '\\', '\n', '\r' => {
            pos_ptr.* = p;
            return true;
        },
        'x' => {
            var valid = true;
            var count: usize = 0;
            while (count < 2) : (count += 1) {
                if (p < text.len and std.ascii.isHex(text[p])) {
                    p += 1;
                } else {
                    valid = false;
                    break;
                }
            }
            pos_ptr.* = p;
            return valid;
        },
        'u' => {
            if (p < text.len and text[p] == '{') {
                p += 1;
                var val: u32 = 0;
                var has_digits = false;
                while (p < text.len and text[p] != '}') : (p += 1) {
                    const digit = text[p];
                    if (std.ascii.isHex(digit)) {
                        has_digits = true;
                        const d_val = if (digit >= '0' and digit <= '9')
                            digit - '0'
                        else if (digit >= 'a' and digit <= 'f')
                            digit - 'a' + 10
                        else
                            digit - 'A' + 10;
                        val = (val << 4) | d_val;
                    } else {
                        pos_ptr.* = p;
                        return false;
                    }
                }
                if (!has_digits or p >= text.len or text[p] != '}') {
                    pos_ptr.* = p;
                    return false;
                }
                p += 1; // skip '}'
                pos_ptr.* = p;
                return val <= 0x10FFFF;
            } else {
                var valid = true;
                var count: usize = 0;
                while (count < 4) : (count += 1) {
                    if (p < text.len and std.ascii.isHex(text[p])) {
                        p += 1;
                    } else {
                        valid = false;
                        break;
                    }
                }
                pos_ptr.* = p;
                return valid;
            }
        },
        else => {
            pos_ptr.* = p;
            return true;
        },
    }
}
