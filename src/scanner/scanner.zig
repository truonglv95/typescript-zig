const std = @import("std");
const kind = @import("../ast/kind.zig");
const maps = @import("maps.zig");

pub const TokenFlags = struct {
    pub const None: u16 = 0;
    pub const PrecedingLineBreak: u16 = 1 << 0;
    pub const PrecedingJSDocComment: u16 = 1 << 1;
    pub const Unterminated: u16 = 1 << 2;
    pub const ExtendedUnicodeEscape: u16 = 1 << 3;
    pub const Scientific: u16 = 1 << 4;
    pub const Octal: u16 = 1 << 5;
    pub const HexSpecifier: u16 = 1 << 6;
    pub const BinarySpecifier: u16 = 1 << 7;
    pub const OctalSpecifier: u16 = 1 << 8;
    pub const ContainsSeparator: u16 = 1 << 9;
    pub const UnicodeEscape: u16 = 1 << 10;
    pub const ContainsInvalidEscape: u16 = 1 << 11;
    pub const ContainsInvalidStringEscape: u16 = 1 << 12;
    pub const SingleQuote: u16 = 1 << 13;
    pub const BinaryOrOctalSpecifier: u16 = BinarySpecifier | OctalSpecifier;
    pub const NumericLiteralFlags: u16 = Scientific | Octal | HexSpecifier | BinaryOrOctalSpecifier | ContainsSeparator;
};

pub const ScannerState = struct {
    pos: usize,
    fullStartPos: usize,
    tokenStart: usize,
    token: kind.Kind,
    tokenValue: []const u8,
    tokenFlags: u16,
    skipJSDocLeadingAsterisks: usize,
};

pub const Scanner = struct {
    allocator: std.mem.Allocator,
    text: []const u8,
    end: usize,
    skipTrivia: bool,
    
    state: ScannerState,
    containsNonASCII: bool,

    pub fn init(allocator: std.mem.Allocator, text: []const u8) Scanner {
        return .{
            .allocator = allocator,
            .text = text,
            .end = text.len,
            .skipTrivia = true,
            .containsNonASCII = false,
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
    }

    pub fn resetPos(self: *Scanner, pos: usize) void {
        self.state.pos = pos;
        self.state.fullStartPos = pos;
        self.state.tokenStart = pos;
        self.state.token = kind.Kind.Unknown;
        self.state.tokenValue = "";
        self.state.tokenFlags = 0;
    }

    pub fn getToken(self: *const Scanner) kind.Kind {
        return self.state.token;
    }

    pub fn getTokenValue(self: *const Scanner) []const u8 {
        return self.state.tokenValue;
    }

    pub fn getTokenFlags(self: *const Scanner) u16 {
        return self.state.tokenFlags;
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
                '(' => { self.state.pos += 1; self.state.token = kind.Kind.OpenParenToken; return self.state.token; },
                ')' => { self.state.pos += 1; self.state.token = kind.Kind.CloseParenToken; return self.state.token; },
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
                ',' => { self.state.pos += 1; self.state.token = kind.Kind.CommaToken; return self.state.token; },
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
                ':' => { self.state.pos += 1; self.state.token = kind.Kind.ColonToken; return self.state.token; },
                ';' => { self.state.pos += 1; self.state.token = kind.Kind.SemicolonToken; return self.state.token; },
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
                '[' => { self.state.pos += 1; self.state.token = kind.Kind.OpenBracketToken; return self.state.token; },
                ']' => { self.state.pos += 1; self.state.token = kind.Kind.CloseBracketToken; return self.state.token; },
                '{' => { self.state.pos += 1; self.state.token = kind.Kind.OpenBraceToken; return self.state.token; },
                '}' => { self.state.pos += 1; self.state.token = kind.Kind.CloseBraceToken; return self.state.token; },
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
                '^' => { self.state.pos += 1; self.state.token = kind.Kind.CaretToken; return self.state.token; },
                '~' => { self.state.pos += 1; self.state.token = kind.Kind.TildeToken; return self.state.token; },
                '@' => { self.state.pos += 1; self.state.token = kind.Kind.AtToken; return self.state.token; },
                '`' => {
                    self.state.token = self.scanTemplateAndSetTokenValue(false);
                    return self.state.token;
                },
                '#' => {
                    const start = self.state.pos;
                    self.state.pos += 1;
                    if (self.state.pos < self.end) {
                        const b = self.char();
                        if ((b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z') or b == '_' or b == '$') {
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
                        while (self.state.pos < self.end and self.char() != '\n') {
                            self.state.pos += 1;
                        }
                        continue;
                    } else if (next == '*') {
                        self.state.pos += 2;
                        while (self.state.pos < self.end) {
                            if (self.char() == '*' and self.charAt(1) == '/') {
                                self.state.pos += 2;
                                break;
                            }
                            self.state.pos += 1;
                        }
                        continue;
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
                    const start = self.state.pos;
                    self.state.pos += 1;
                    while (self.state.pos < self.end) {
                        const b = self.char();
                        if ((b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z') or (b >= '0' and b <= '9') or b == '_' or b == '$' or b == '\\' or b >= 0x80) {
                            self.state.pos += 1;
                        } else {
                            break;
                        }
                    }
                    self.state.tokenValue = self.text[start..self.state.pos];
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
                    self.state.tokenValue = self.scanString();
                    self.state.token = kind.Kind.StringLiteral;
                    return self.state.token;
                },
                else => {
                    self.state.pos += 1;
                    self.state.token = kind.Kind.Unknown;
                    return self.state.token;
                }
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
            if ((b >= '0' and b <= '9') or b == '.') {
                self.state.pos += 1;
            } else if (b == 'e' or b == 'E') {
                self.state.pos += 1;
                const sign = self.char();
                if (sign == '+' or sign == '-') self.state.pos += 1;
                while (self.state.pos < self.end) {
                    const eb = self.char();
                    if (eb >= '0' and eb <= '9') {
                        self.state.pos += 1;
                    } else {
                        break;
                    }
                }
                self.state.tokenFlags |= TokenFlags.Scientific;
            } else {
                break;
            }
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
            if ((b >= '0' and b <= '9') or (b >= 'a' and b <= 'f') or (b >= 'A' and b <= 'F')) {
                self.state.pos += 1;
            } else {
                break;
            }
        }
    }

    fn scanBinaryDigits(self: *Scanner) void {
        while (self.state.pos < self.end) {
            const b = self.char();
            if (b == '0' or b == '1') {
                self.state.pos += 1;
            } else {
                break;
            }
        }
    }

    fn scanOctalDigits(self: *Scanner) void {
        while (self.state.pos < self.end) {
            const b = self.char();
            if (b >= '0' and b <= '7') {
                self.state.pos += 1;
            } else {
                break;
            }
        }
    }

    fn scanString(self: *Scanner) []const u8 {
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
                // slow path placeholder (TODO: decode escape sequence)
                self.state.pos += 2;
                continue;
            }
            if (ch == '\n' or ch == '\r') {
                self.state.tokenFlags |= TokenFlags.Unterminated;
                break;
            }
            self.state.pos += 1;
        }
        
        return self.text[start..self.state.pos];
    }

    pub fn hasPrecedingLineBreak(self: *const Scanner) bool {
        return (self.state.tokenFlags & TokenFlags.PrecedingLineBreak) != 0;
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
                parts.append(self.allocator, self.text[start..self.state.pos]) catch unreachable;
                self.state.pos += 1;
                // Simplified escape sequence scanning
                if (self.char() != 0) {
                    self.state.pos += 1;
                    parts.append(self.allocator, self.text[self.state.pos-1..self.state.pos]) catch unreachable;
                }
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
            @memcpy(buf[offset..offset+part.len], part);
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

    pub fn scanJSDocToken(self: *Scanner) kind.Kind {
        self.state.fullStartPos = self.state.pos;
        self.state.tokenFlags = TokenFlags.None;

        if (self.state.pos >= self.end) {
            self.state.token = kind.Kind.EndOfFileToken;
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
                self.state.tokenValue = self.text[self.state.tokenStart..self.state.pos];
                self.state.token = kind.Kind.Identifier;
                return self.state.token;
            },
            else => {
                self.state.token = kind.Kind.Unknown;
                return self.state.token;
            }
        }
    }
};
