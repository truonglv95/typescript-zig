const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const kind = @import("../ast/kind.zig");
const scanner_pkg = @import("../scanner/scanner.zig");
const core = @import("../core/core.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const jsdoc = @import("jsdoc.zig");

pub const ParsingContext = enum(u32) {
    SourceElements = 0,
    BlockStatements,
    SwitchClauses,
    SwitchClauseStatements,
    TypeMembers,
    ClassMembers,
    EnumMembers,
    HeritageClauseElement,
    VariableDeclarations,
    ObjectBindingElements,
    ArrayBindingElements,
    ArgumentExpressions,
    ObjectLiteralMembers,
    JsxAttributes,
    JsxChildren,
    ArrayLiteralMembers,
    Parameters,
    JSDocParameters,
    RestProperties,
    TypeParameters,
    TypeArguments,
    TupleElementTypes,
    HeritageClauses,
    ImportOrExportSpecifiers,
    ImportAttributes,
    JSDocComment,
    Count,
};

pub const JSDocInfo = struct {
    parent: ast_gen.NodeIndex,
    jsDocs: []const ast_gen.NodeIndex,
};

pub const JSDocScannerInfo = usize;
pub const jsdocScannerInfoHasJSDoc: JSDocScannerInfo = 1 << 0;
pub const jsdocScannerInfoHasDeprecated: JSDocScannerInfo = 1 << 1;
pub const jsdocScannerInfoHasSeeOrLink: JSDocScannerInfo = 1 << 2;

pub const Parser = struct {
    allocator: std.mem.Allocator,
    scanner: scanner_pkg.Scanner,
    ast: ast.Ast,
    languageVariant: core.LanguageVariant,
    scriptKind: core.ScriptKind = .TS,
    sourceText: []const u8,

    // Trạng thái Parser
    token: kind.Kind,
    parseDiagnosticsCount: u32 = 0,
    lastErrorPos: i32 = -1,
    parsingContexts: u32 = 0,
    disallowInContext: bool = false,
    contextFlags: u32 = 0,

    diagnostics: std.ArrayListUnmanaged(diagnostics.Diagnostic) = .empty,
    jsdocDiagnostics: std.ArrayListUnmanaged(diagnostics.Diagnostic) = .empty,
    jsdocInfos: std.ArrayListUnmanaged(JSDocInfo) = .empty,
    jsdocCommentRangesSpace: std.ArrayListUnmanaged(scanner_pkg.CommentRange) = .empty,
    hasDeprecatedTag: bool = false,
    inJSDocType: bool = false,

    pub fn setContextFlags(self: *Parser, val: u32, on: bool) void {
        if (on) {
            self.contextFlags |= val;
        } else {
            self.contextFlags &= ~val;
        }
    }

    pub fn isJavaScript(self: *const Parser) bool {
        return self.scriptKind == .JS or self.scriptKind == .JSX;
    }

    pub fn setScriptKind(self: *Parser, kind_val: core.ScriptKind) void {
        self.scriptKind = kind_val;
        self.setLanguageVariant(switch (kind_val) {
            .JSX, .TSX => .JSX,
            else => .Standard,
        });
    }

    pub fn jsdocScannerInfo(self: *Parser) JSDocScannerInfo {
        if (!self.scanner.hasPrecedingJSDocComment()) {
            return 0;
        }
        var info: JSDocScannerInfo = jsdocScannerInfoHasJSDoc;
        if (self.scanner.hasPrecedingJSDocWithDeprecatedTag()) {
            info |= jsdocScannerInfoHasDeprecated;
        }
        if (self.scanner.hasPrecedingJSDocWithSeeOrLink()) {
            info |= jsdocScannerInfoHasSeeOrLink;
        }
        return info | (self.scanner.getTokenFullStart() << 8);
    }

    pub const Mark = struct {
        scanner: scanner_pkg.Scanner,
        token: kind.Kind,
        nodes_len: usize,
        extraData_len: usize,
        parseDiagnosticsCount: u32,
        lastErrorPos: i32,
        jsdocInfos_len: usize,
    };

    pub fn mark(self: *Parser) Mark {
        return .{
            .scanner = self.scanner,
            .token = self.token,
            .nodes_len = self.ast.nodes.len,
            .extraData_len = self.ast.extraData.items.len,
            .parseDiagnosticsCount = self.parseDiagnosticsCount,
            .lastErrorPos = self.lastErrorPos,
            .jsdocInfos_len = self.jsdocInfos.items.len,
        };
    }

    pub fn rewind(self: *Parser, m: Mark) void {
        self.scanner = m.scanner;
        self.token = m.token;
        self.ast.nodes.len = m.nodes_len;
        self.ast.extraData.items.len = m.extraData_len;
        self.parseDiagnosticsCount = m.parseDiagnosticsCount;
        self.lastErrorPos = m.lastErrorPos;
        self.jsdocInfos.items.len = m.jsdocInfos_len;
    }

    // =========================================================================
    // Go 1:1 Parity - Speculative Parsing
    // =========================================================================

    /// Executes a callback in a speculative state. If it returns false, or we just want
    /// to peek ahead without committing, we rewind the state.
    pub fn lookAhead(self: *Parser, comptime callback: fn (*Parser) bool) bool {
        const state = self.mark();
        const result = callback(self);
        self.rewind(state);
        return result;
    }

    /// Tries to parse using the callback. If it fails (returns 0 or null NodeIndex),
    /// it rewinds. If it succeeds, it commits the parse.
    pub fn tryParse(self: *Parser, comptime callback: fn (*Parser) ast_gen.NodeIndex) ast_gen.NodeIndex {
        const state = self.mark();
        const result = callback(self);
        if (result == 0) {
            self.rewind(state);
        }
        return result;
    }

    /// Try to parse a list. If fails, rewind.
    pub fn tryParseList(self: *Parser, comptime callback: fn (*Parser) u32) u32 {
        const state = self.mark();
        const result = callback(self);
        if (result == 0) {
            self.rewind(state);
        }
        return result;
    }

    // =========================================================================
    // isListElement — Full Go 1:1 parity
    // =========================================================================
    pub fn isListElement(self: *Parser, parsingContext: ParsingContext, inErrorRecovery: bool) bool {
        switch (parsingContext) {
            .SourceElements, .BlockStatements, .SwitchClauseStatements => {
                return !(self.token == kind.Kind.SemicolonToken and inErrorRecovery) and self.isStartOfStatement();
            },
            .SwitchClauses => {
                return self.token == kind.Kind.CaseKeyword or self.token == kind.Kind.DefaultKeyword;
            },
            .TypeMembers => {
                return self.lookAhead(struct {
                    fn run(p: *Parser) bool {
                        return p.scanTypeMemberStart();
                    }
                }.run);
            },
            .ClassMembers => {
                return self.lookAhead(struct {
                    fn run(p: *Parser) bool {
                        return p.scanClassMemberStart();
                    }
                }.run) or (self.token == kind.Kind.SemicolonToken and !inErrorRecovery);
            },
            .EnumMembers => {
                return self.token == kind.Kind.OpenBracketToken or self.isLiteralPropertyName();
            },
            .ObjectLiteralMembers => {
                switch (self.token) {
                    .OpenBracketToken, .AsteriskToken, .DotDotDotToken, .DotToken => return true,
                    else => return self.isLiteralPropertyName(),
                }
            },
            .RestProperties => {
                return self.isLiteralPropertyName();
            },
            .ObjectBindingElements => {
                return self.token == kind.Kind.OpenBracketToken or self.token == kind.Kind.DotDotDotToken or self.isLiteralPropertyName();
            },
            .ImportAttributes => {
                return self.isImportAttributeName();
            },
            .HeritageClauseElement => {
                if (self.token == kind.Kind.OpenBraceToken) {
                    return self.isValidHeritageClauseObjectLiteral();
                }
                if (!inErrorRecovery) {
                    return self.isStartOfLeftHandSideExpression() and !self.isHeritageClauseExtendsOrImplementsKeyword();
                }
                return self.isIdentifier() and !self.isHeritageClauseExtendsOrImplementsKeyword();
            },
            .VariableDeclarations => {
                return self.isIdentifier() or self.token == kind.Kind.OpenBraceToken or self.token == kind.Kind.OpenBracketToken;
            },
            .ArrayBindingElements => {
                return self.token == kind.Kind.CommaToken or self.token == kind.Kind.DotDotDotToken or self.isIdentifier() or self.token == kind.Kind.OpenBracketToken or self.token == kind.Kind.OpenBraceToken;
            },
            .TypeParameters => {
                return self.token == kind.Kind.InKeyword or self.token == kind.Kind.ConstKeyword or self.isIdentifier();
            },
            .ArrayLiteralMembers => {
                if (self.token == kind.Kind.CommaToken or self.token == kind.Kind.DotToken) return true;
                return self.token == kind.Kind.DotDotDotToken or self.isStartOfExpression();
            },
            .ArgumentExpressions => {
                return self.token == kind.Kind.DotDotDotToken or self.isStartOfExpression();
            },
            .Parameters, .JSDocParameters => {
                return self.isStartOfParameter();
            },
            .TypeArguments, .TupleElementTypes => {
                return self.token == kind.Kind.CommaToken or self.isStartOfType();
            },
            .HeritageClauses => {
                return self.isHeritageClause();
            },
            .ImportOrExportSpecifiers => {
                // bail out if the next token is [FromKeyword StringLiteral].
                if (self.token == kind.Kind.FromKeyword) {
                    var tmp = self.scanner;
                    const next = tmp.scan();
                    if (next == kind.Kind.StringLiteral) return false;
                }
                if (self.token == kind.Kind.StringLiteral) return true;
                return self.isTokenOrKeyword();
            },
            .JsxAttributes => {
                return self.isTokenOrKeyword() or self.token == kind.Kind.OpenBraceToken;
            },
            .JsxChildren, .JSDocComment => {
                return true;
            },
            .Count => return false,
        }
    }

    // =========================================================================
    // isListTerminator — Full Go 1:1 parity
    // =========================================================================
    pub fn isListTerminator(self: *Parser, parsingContext: ParsingContext) bool {
        // EOF always terminates any list
        if (self.token == kind.Kind.EndOfFile) return true;
        switch (parsingContext) {
            .BlockStatements, .SwitchClauses, .TypeMembers, .ClassMembers, .EnumMembers, .ObjectLiteralMembers, .ObjectBindingElements, .ImportOrExportSpecifiers, .ImportAttributes => {
                return self.token == kind.Kind.CloseBraceToken;
            },
            .SwitchClauseStatements => {
                return self.token == kind.Kind.CloseBraceToken or self.token == kind.Kind.CaseKeyword or self.token == kind.Kind.DefaultKeyword;
            },
            .HeritageClauseElement => {
                return self.token == kind.Kind.OpenBraceToken or self.token == kind.Kind.ExtendsKeyword or self.token == kind.Kind.ImplementsKeyword;
            },
            .VariableDeclarations => {
                return self.canParseSemicolon() or self.token == kind.Kind.InKeyword or self.token == kind.Kind.OfKeyword or self.token == kind.Kind.EqualsGreaterThanToken;
            },
            .TypeParameters => {
                return self.token == kind.Kind.GreaterThanToken or self.token == kind.Kind.OpenParenToken or self.token == kind.Kind.OpenBraceToken or self.token == kind.Kind.ExtendsKeyword or self.token == kind.Kind.ImplementsKeyword;
            },
            .ArgumentExpressions => {
                return self.token == kind.Kind.CloseParenToken or self.token == kind.Kind.SemicolonToken;
            },
            .ArrayLiteralMembers, .TupleElementTypes, .ArrayBindingElements => {
                return self.token == kind.Kind.CloseBracketToken;
            },
            .JSDocParameters, .Parameters, .RestProperties => {
                return self.token == kind.Kind.CloseParenToken or self.token == kind.Kind.CloseBracketToken;
            },
            .TypeArguments => {
                return self.token != kind.Kind.CommaToken;
            },
            .HeritageClauses => {
                return self.token == kind.Kind.OpenBraceToken or self.token == kind.Kind.CloseBraceToken;
            },
            .JsxAttributes => {
                return self.token == kind.Kind.GreaterThanToken or self.token == kind.Kind.SlashToken;
            },
            .JsxChildren => {
                // terminates on </
                if (self.token == kind.Kind.LessThanToken) {
                    var tmp = self.scanner;
                    const next = tmp.scan();
                    return next == kind.Kind.SlashToken;
                }
                return false;
            },
            .SourceElements => return self.token == kind.Kind.EndOfFile,
            .JSDocComment => return false,
            .Count => return false,
        }
    }

    // =========================================================================
    // Helper predicates
    // =========================================================================

    /// Returns true if current token is an identifier or keyword (for tokenIsIdentifierOrKeyword Go parity)
    pub fn isTokenOrKeyword(self: *Parser) bool {
        return self.isIdentifier() or kind.isKeyword(self.token);
    }

    pub fn isIdentifierOrKeyword(self: *Parser) bool {
        return self.isIdentifier() or kind.isKeyword(self.token);
    }

    /// Checks if the current token starts a type (simplified but parity with Go's isStartOfType)
    pub fn isStartOfType(self: *Parser) bool {
        switch (self.token) {
            .AnyKeyword, .UnknownKeyword, .StringKeyword, .NumberKeyword, .BigIntKeyword, .BooleanKeyword, .ReadonlyKeyword, .SymbolKeyword, .UniqueKeyword, .VoidKeyword, .UndefinedKeyword, .NullKeyword, .ThisKeyword, .TypeOfKeyword, .NeverKeyword, .OpenBraceToken, .OpenBracketToken, .LessThanToken, .BarToken, .AmpersandToken, .NewKeyword, .StringLiteral, .NumericLiteral, .BigIntLiteral, .TrueKeyword, .FalseKeyword, .ObjectKeyword, .AsteriskToken, .QuestionToken, .ExclamationToken, .DotDotDotToken, .InferKeyword, .ImportKeyword, .IntrinsicKeyword, .NoSubstitutionTemplateLiteral, .TemplateHead => return true,
            .FunctionKeyword => return true,
            .OpenParenToken => return true, // (type) or (params) =>
            else => return self.isIdentifier(),
        }
    }

    /// isHeritageClause: current token is 'extends' or 'implements'
    pub fn isHeritageClause(self: *Parser) bool {
        return self.token == kind.Kind.ExtendsKeyword or self.token == kind.Kind.ImplementsKeyword;
    }

    /// isHeritageClauseExtendsOrImplementsKeyword: 'extends'/'implements' followed by expression start
    pub fn isHeritageClauseExtendsOrImplementsKeyword(self: *Parser) bool {
        if (!self.isHeritageClause()) return false;
        return self.lookAhead(struct {
            fn run(p: *Parser) bool {
                p.nextToken();
                return p.isStartOfExpression();
            }
        }.run);
    }

    /// isImportAttributeName: identifier, keyword, or string literal
    pub fn isImportAttributeName(self: *Parser) bool {
        return self.isTokenOrKeyword() or self.token == kind.Kind.StringLiteral;
    }

    /// isBindingIdentifierOrPrivateIdentifierOrPattern
    pub fn isBindingIdentifierOrPrivateIdentifierOrPattern(self: *Parser) bool {
        return self.token == kind.Kind.OpenBraceToken or self.token == kind.Kind.OpenBracketToken or self.token == kind.Kind.PrivateIdentifier or self.isIdentifier();
    }

    /// scanTypeMemberStart: lookAhead predicate for TypeMembers list
    fn scanTypeMemberStart(self: *Parser) bool {
        if (self.token == kind.Kind.OpenParenToken or self.token == kind.Kind.LessThanToken or
            self.token == kind.Kind.GetKeyword or self.token == kind.Kind.SetKeyword)
        {
            return true;
        }
        var idToken = false;
        // Eat modifiers
        while (self.isModifierKind(self.token)) {
            idToken = true;
            self.nextToken();
        }
        if (self.token == kind.Kind.OpenBracketToken) return true;
        if (self.isLiteralPropertyName()) {
            idToken = true;
            self.nextToken();
        }
        if (idToken) {
            return self.token == kind.Kind.OpenParenToken or self.token == kind.Kind.LessThanToken or
                self.token == kind.Kind.QuestionToken or self.token == kind.Kind.ColonToken or
                self.token == kind.Kind.CommaToken or self.canParseSemicolon();
        }
        return false;
    }

    pub fn nextTokenIsIdentifierOrKeywordOrGreaterThan(self: *Parser) bool {
        self.nextToken();
        return self.isIdentifier() or kind.isKeyword(self.token) or self.token == kind.Kind.GreaterThanToken;
    }

    pub fn nextTokenIsIdentifier(self: *Parser) bool {
        self.nextToken();
        return self.isIdentifier();
    }

    /// scanClassMemberStart: lookAhead predicate for ClassMembers list
    fn scanClassMemberStart(self: *Parser) bool {
        if (self.token == kind.Kind.AtToken) return true;
        var idToken = kind.Kind.Unknown;
        // Eat modifiers; if class modifier found → definitely a member
        while (self.isModifierKind(self.token)) {
            idToken = self.token;
            if (self.isClassMemberModifier(idToken)) return true;
            self.nextToken();
        }
        if (self.token == kind.Kind.AsteriskToken) return true;
        if (self.isLiteralPropertyName()) {
            idToken = self.token;
            self.nextToken();
        }
        if (self.token == kind.Kind.OpenBracketToken) return true;
        if (idToken != kind.Kind.Unknown) {
            if (!kind.isKeyword(idToken) or idToken == kind.Kind.SetKeyword or idToken == kind.Kind.GetKeyword) {
                return true;
            }
            switch (self.token) {
                .OpenParenToken, .LessThanToken, .ExclamationToken, .ColonToken, .EqualsToken, .QuestionToken => return true,
                else => return self.canParseSemicolon(),
            }
        }
        return false;
    }

    /// isClassMemberModifier: protected/private/public/static
    pub fn isClassMemberModifier(self: *Parser, k: kind.Kind) bool {
        _ = self;
        switch (k) {
            .PrivateKeyword, .ProtectedKeyword, .PublicKeyword, .StaticKeyword, .AccessorKeyword => return true,
            else => return false,
        }
    }

    pub fn abortParsingListOrMoveToNextToken(self: *Parser, parsingContext: ParsingContext) bool {
        _ = parsingContext;
        self.parseError("Expected token in delimited list"); // Stub for parsingContextErrors
        if (self.isInSomeParsingContext()) {
            return true;
        }
        self.nextToken();
        return false;
    }

    pub fn isInSomeParsingContext(self: *Parser) bool {
        var i: u32 = 0;
        while (i < @intFromEnum(ParsingContext.Count)) : (i += 1) {
            if ((self.parsingContexts & (@as(u32, 1) << @as(u5, @intCast(i)))) != 0) {
                const ctx: ParsingContext = @enumFromInt(i);
                if (self.isListElement(ctx, true) or self.isListTerminator(ctx)) {
                    return true;
                }
            }
        }
        return false;
    }

    pub fn isLiteralPropertyName(self: *Parser) bool {
        return self.isIdentifierOrKeyword() or self.token == kind.Kind.StringLiteral or self.token == kind.Kind.NumericLiteral;
    }

    pub fn canParseSemicolon(self: *Parser) bool {
        return self.token == kind.Kind.SemicolonToken or self.token == kind.Kind.CloseBraceToken or self.token == kind.Kind.EndOfFile or self.scanner.hasPrecedingLineBreak();
    }

    pub fn isStartOfStatement(self: *Parser) bool {
        switch (self.token) {
            .AtToken, .SemicolonToken, .OpenBraceToken, .VarKeyword, .LetKeyword, .UsingKeyword, .FunctionKeyword, .ClassKeyword, .EnumKeyword, .IfKeyword, .DoKeyword, .WhileKeyword, .ForKeyword, .ContinueKeyword, .BreakKeyword, .ReturnKeyword, .WithKeyword, .SwitchKeyword, .ThrowKeyword, .TryKeyword, .DebuggerKeyword, .CatchKeyword, .FinallyKeyword => return true,

            .ImportKeyword => return self.isStartOfDeclaration() or self.isNextTokenOpenParenOrLessThanOrDot(),

            .ConstKeyword, .ExportKeyword => return self.isStartOfDeclaration(),

            .AsyncKeyword, .DeclareKeyword, .InterfaceKeyword, .ModuleKeyword, .NamespaceKeyword, .TypeKeyword, .GlobalKeyword => return true,

            .AccessorKeyword, .PublicKeyword, .PrivateKeyword, .ProtectedKeyword, .StaticKeyword, .ReadonlyKeyword => {
                return self.isStartOfDeclaration() or !self.lookAhead(struct {
                    fn run(p: *Parser) bool {
                        return p.nextTokenIsIdentifierOrKeywordOnSameLine();
                    }
                }.run);
            },

            else => return self.isStartOfExpression(),
        }
    }

    pub fn isStartOfExpression(self: *Parser) bool {
        if (self.isIdentifier()) return true;
        switch (self.token) {
            .ThisKeyword, .SuperKeyword, .NullKeyword, .TrueKeyword, .FalseKeyword, .NumericLiteral, .BigIntLiteral, .StringLiteral, .NoSubstitutionTemplateLiteral, .TemplateHead, .OpenParenToken, .OpenBracketToken, .OpenBraceToken, .FunctionKeyword, .ClassKeyword, .NewKeyword, .SlashToken, .SlashEqualsToken, .PlusToken, .MinusToken, .TildeToken, .ExclamationToken, .DeleteKeyword, .TypeOfKeyword, .VoidKeyword, .PlusPlusToken, .MinusMinusToken, .LessThanToken, .AwaitKeyword, .YieldKeyword, .ImportKeyword => return true,
            else => {},
        }

        const opPrec = @import("expression.zig").getBinaryOperatorPrecedence(self.token);
        if (opPrec != .Invalid) {
            return true;
        }

        return false;
    }

    pub fn isStartOfParameter(self: *Parser) bool {
        return self.token == kind.Kind.AtToken or self.token == kind.Kind.DotDotDotToken or self.isIdentifier() or self.token == kind.Kind.ThisKeyword or self.token == kind.Kind.OpenBracketToken or self.token == kind.Kind.OpenBraceToken;
    }

    pub fn isNextTokenOpenParenOrLessThanOrDot(self: *Parser) bool {
        const saved = self.mark();
        defer self.rewind(saved);
        self.nextToken();
        return self.token == kind.Kind.OpenParenToken or self.token == kind.Kind.LessThanToken or self.token == kind.Kind.DotToken;
    }

    pub fn parseList(self: *Parser, parsingContext: ParsingContext, comptime parseElement: fn (*Parser) anyerror!ast_gen.NodeIndex) anyerror!ast_gen.NodeListIndex {
        const saveParsingContexts = self.parsingContexts;
        self.parsingContexts |= @as(u32, 1) << @as(u5, @intCast(@intFromEnum(parsingContext)));

        var list = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer list.deinit(self.allocator);

        while (!self.isListTerminator(parsingContext)) {
            if (self.isListElement(parsingContext, false)) {
                const element = try parseElement(self);
                try list.append(self.allocator, element);
                continue;
            }
            if (self.abortParsingListOrMoveToNextToken(parsingContext)) {
                break;
            }
        }

        self.parsingContexts = saveParsingContexts;
        return self.ast.pushNodeList(list.items);
    }

    pub fn parseDelimitedList(self: *Parser, parsingContext: ParsingContext, comptime parseElement: fn (*Parser) ast_gen.NodeIndex) ast_gen.NodeIndex {
        const saveParsingContexts = self.parsingContexts;
        self.parsingContexts |= @as(u32, 1) << @as(u5, @intCast(@intFromEnum(parsingContext)));

        var list = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer list.deinit(self.allocator);
        var hasTrailingComma = false;

        while (true) {
            if (self.isListElement(parsingContext, false)) {
                const startPos = self.scanner.state.pos;
                const element = parseElement(self);
                if (element == 0) {
                    self.parsingContexts = saveParsingContexts;
                    return 0; // Failed to parse element
                }
                list.append(self.allocator, element) catch return 0;

                hasTrailingComma = self.parseOptional(kind.Kind.CommaToken);
                if (hasTrailingComma) {
                    continue;
                }
                if (self.isListTerminator(parsingContext)) {
                    break;
                }

                if (self.token != kind.Kind.CommaToken and parsingContext == .EnumMembers) {
                    self.parseError("An enum member must be followed by a comma");
                } else {
                    _ = self.parseExpected(kind.Kind.CommaToken);
                }

                // Error recovery trick: Semicolon object literal members
                if ((parsingContext == .ObjectLiteralMembers or parsingContext == .ImportAttributes) and self.token == kind.Kind.SemicolonToken and !self.scanner.hasPrecedingLineBreak()) {
                    self.nextToken();
                }

                if (startPos == self.scanner.state.pos) {
                    self.nextToken(); // Prevent infinite loop
                }
            } else {
                if (self.isListTerminator(parsingContext)) {
                    break;
                }
                if (self.abortParsingListOrMoveToNextToken(parsingContext)) {
                    break;
                }
            }
        }

        self.parsingContexts = saveParsingContexts;
        return self.ast.pushNodeListWithTrailingComma(list.items, hasTrailingComma) catch 0;
    }

    pub fn init(allocator: std.mem.Allocator, text: []const u8) Parser {
        const scanner = scanner_pkg.Scanner.init(allocator, text);
        var p = Parser{
            .allocator = allocator,
            .scanner = scanner,
            .ast = ast.Ast.init(allocator),
            .languageVariant = .Standard,
            .scriptKind = .TS,
            .sourceText = text,
            .token = kind.Kind.Unknown,
            .parseDiagnosticsCount = 0,
            .contextFlags = 0,
        };
        // Quét token đầu tiên mồi cho quá trình parse
        p.nextToken();
        return p;
    }

    pub fn setLanguageVariant(self: *Parser, variant: core.LanguageVariant) void {
        self.languageVariant = variant;
        self.scanner.languageVariant = variant;
    }

    pub fn deinit(self: *Parser) void {
        self.ast.deinit();
        self.scanner.deinit();
        self.diagnostics.deinit(self.allocator);
        self.jsdocDiagnostics.deinit(self.allocator);
        self.jsdocInfos.deinit(self.allocator);
        self.jsdocCommentRangesSpace.deinit(self.allocator);
    }

    pub fn diagnosticCount(self: *const Parser) u32 {
        return self.parseDiagnosticsCount;
    }

    pub fn nextToken(self: *Parser) void {
        self.token = self.scanner.scan();
    }

    pub fn nextTokenJSDoc(self: *Parser) kind.Kind {
        self.token = self.scanner.scanJSDocToken();
        return self.token;
    }

    pub fn nextJSDocCommentTextToken(self: *Parser, inBackticks: bool) kind.Kind {
        self.token = self.scanner.scanJSDocCommentTextToken(inBackticks);
        return self.token;
    }

    pub fn reScanGreaterThanToken(self: *Parser) kind.Kind {
        self.token = self.scanner.reScanGreaterThanToken();
        return self.token;
    }

    pub fn reScanAsteriskEqualsToken(self: *Parser) kind.Kind {
        self.token = self.scanner.reScanAsteriskEqualsToken();
        return self.token;
    }

    pub fn reScanQuestionToken(self: *Parser) kind.Kind {
        self.token = self.scanner.reScanQuestionToken();
        return self.token;
    }

    pub fn setNodeStartPos(self: *Parser, node: ast_gen.NodeIndex, start_pos: usize) void {
        if (node != 0 and node < self.ast.positions.items.len) {
            self.ast.positions.items[node].pos = @intCast(start_pos);
        }
    }

    pub fn parseSourceFile(self: *Parser) anyerror!ast_gen.NodeIndex {
        self.ast.sourceText = self.sourceText;
        const statements = try self.parseList(.SourceElements, parseStatement);
        var eof_jsdoc_info = self.jsdocScannerInfo();
        if (eof_jsdoc_info == 0) {
            if (std.mem.lastIndexOf(u8, self.sourceText, "/**")) |comment_start| {
                if (std.mem.lastIndexOf(u8, self.sourceText, "*/")) |comment_end| {
                    if (comment_end >= comment_start and std.mem.trim(u8, self.sourceText[comment_end + 2 ..], " \t\r\n").len == 0) {
                        eof_jsdoc_info = jsdocScannerInfoHasJSDoc | (comment_start << 8);
                    }
                }
            }
        }
        const endOfFileToken = try self.ast.pushNode(.{ .EndOfFile = void{} });
        _ = try jsdoc.withJSDoc(self, endOfFileToken, eof_jsdoc_info);

        var final_statements = statements;
        if (self.isJavaScript()) {
            const original_list_slice = self.ast.getNodeList(statements);
            const cloned_list = try self.allocator.dupe(ast_gen.NodeIndex, original_list_slice);
            defer self.allocator.free(cloned_list);
            const interleaved = try jsdoc.reparseJSDocDeclarations(self, cloned_list, endOfFileToken);
            final_statements = try self.ast.pushNodeList(interleaved);
            self.allocator.free(interleaved);
        }

        const sourceFileIndex = try self.ast.pushNode(.{ .SourceFile = .{
            .Symbol = 0,
            .Flags = if (self.isJavaScript()) @import("../ast/ast_utils.zig").NodeFlags.JavaScriptFile else 0,
            .Statements = final_statements,
            .EndOfFileToken = endOfFileToken,
            .ExternalModuleIndicator = null,
            .CommonJSModuleIndicator = null,
        } });

        self.ast.setNodePosition(sourceFileIndex, 0, @intCast(self.sourceText.len));

        var sourceFileNode = self.ast.getNode(sourceFileIndex);
        sourceFileNode.SourceFile.ExternalModuleIndicator = @import("../ast/ast_utils.zig").isFileProbablyExternalModule(&self.ast, sourceFileIndex);
        self.ast.nodes.set(sourceFileIndex, sourceFileNode);

        try @import("../ast/ast_utils.zig").fixupParentReferences(&self.ast, sourceFileIndex);
        @import("../ast/position_fixup.zig").fillMissingNodePositions(&self.ast, sourceFileIndex);

        // Copy comment directives from scanner to AST
        try self.ast.commentDirectives.appendSlice(self.allocator, self.scanner.commentDirectives.items);

        // Parse pragmas
        try self.getCommentPragmas(&self.ast.pragmas);

        // Process pragmas into fields
        try self.processPragmasIntoFields(self.ast.pragmas.items);

        // Collect external module references
        try self.collectExternalModuleReferences(sourceFileIndex);

        // Copy diagnostics
        try self.ast.diagnostics.appendSlice(self.allocator, self.diagnostics.items);
        try self.ast.jsdocDiagnostics.appendSlice(self.allocator, self.jsdocDiagnostics.items);

        return sourceFileIndex;
    }

    pub fn isStartOfDeclaration(self: *Parser) bool {
        return self.lookAhead(struct {
            fn run(p: *Parser) bool {
                var tempScanner = p.scanner;
                var tok = p.token;
                while (true) {
                    switch (tok) {
                        kind.Kind.VarKeyword, kind.Kind.LetKeyword, kind.Kind.ConstKeyword, kind.Kind.FunctionKeyword, kind.Kind.ClassKeyword, kind.Kind.EnumKeyword => return true,
                        kind.Kind.InterfaceKeyword, kind.Kind.TypeKeyword => {
                            tok = tempScanner.scan();
                            if (tempScanner.hasPrecedingLineBreak()) return false;
                            return tok == kind.Kind.Identifier;
                        },
                        kind.Kind.ModuleKeyword, kind.Kind.NamespaceKeyword => {
                            tok = tempScanner.scan();
                            if (tempScanner.hasPrecedingLineBreak()) return false;
                            return tok == kind.Kind.Identifier or tok == kind.Kind.StringLiteral;
                        },
                        kind.Kind.AbstractKeyword, kind.Kind.AwaitKeyword => {
                            tok = tempScanner.scan();
                            if (tempScanner.hasPrecedingLineBreak()) return false;
                            if (tok == kind.Kind.UsingKeyword) {
                                tok = tempScanner.scan();
                                if (tempScanner.hasPrecedingLineBreak()) return false;
                                return tok == kind.Kind.Identifier or tok == kind.Kind.OpenBraceToken or tok == kind.Kind.OpenBracketToken;
                            }
                            continue;
                        },
                        kind.Kind.AccessorKeyword, kind.Kind.AsyncKeyword, kind.Kind.DeclareKeyword, kind.Kind.PrivateKeyword, kind.Kind.ProtectedKeyword, kind.Kind.PublicKeyword, kind.Kind.ReadonlyKeyword, kind.Kind.StaticKeyword => {
                            tok = tempScanner.scan();
                            if (tempScanner.hasPrecedingLineBreak()) return false;
                            continue;
                        },
                        kind.Kind.GlobalKeyword => {
                            tok = tempScanner.scan();
                            return tok == kind.Kind.OpenBraceToken or tok == kind.Kind.Identifier or tok == kind.Kind.ExportKeyword;
                        },
                        kind.Kind.ExportKeyword => {
                            tok = tempScanner.scan();
                            if (tok == kind.Kind.EqualsToken or tok == kind.Kind.AsteriskToken or tok == kind.Kind.OpenBraceToken or
                                tok == kind.Kind.DefaultKeyword or tok == kind.Kind.AsKeyword or tok == kind.Kind.AtToken)
                            {
                                return true;
                            }
                            if (tok == kind.Kind.TypeKeyword) {
                                tok = tempScanner.scan();
                                if (tok == kind.Kind.AsteriskToken or tok == kind.Kind.OpenBraceToken) return true;
                                if ((kind.isKeyword(tok) or tok == kind.Kind.Identifier) and !tempScanner.hasPrecedingLineBreak()) return true;
                            }
                            continue;
                        },
                        kind.Kind.ImportKeyword => {
                            tok = tempScanner.scan();
                            return tok != kind.Kind.OpenParenToken and tok != kind.Kind.LessThanToken and tok != kind.Kind.DotToken;
                        },
                        else => return false,
                    }
                }
            }
        }.run);
    }

    pub fn parseStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const jsdoc_info = self.jsdocScannerInfo();
        const result = try self.parseStatementWorker();
        _ = try jsdoc.withJSDoc(self, result, jsdoc_info);
        return result;
    }

    pub fn parseStatementWorker(self: *Parser) anyerror!ast_gen.NodeIndex {
        switch (self.token) {
            kind.Kind.SemicolonToken => return self.parseEmptyStatement(),
            kind.Kind.OpenBraceToken => return self.parseBlock(),
            kind.Kind.VarKeyword => return self.parseVariableStatement(null, 0),
            kind.Kind.LetKeyword => {
                if (self.isLetDeclaration()) {
                    return self.parseVariableStatement(null, 0);
                }
                return self.parseExpressionStatement();
            },
            kind.Kind.UsingKeyword => {
                if (self.isUsingDeclaration()) {
                    return self.parseVariableStatement(null, 0);
                } else {
                    return self.parseExpressionStatement();
                }
            },
            kind.Kind.AwaitKeyword => {
                if (self.nextIsUsingDeclaration()) {
                    return self.parseVariableStatement(null, 0);
                } else {
                    return self.parseExpressionStatement();
                }
            },
            kind.Kind.FunctionKeyword => return self.parseFunctionDeclaration(null, 0),
            kind.Kind.ClassKeyword => return self.parseClassDeclaration(null, 0),
            kind.Kind.IfKeyword => return self.parseIfStatement(),
            kind.Kind.DoKeyword => return self.parseDoStatement(),
            kind.Kind.WhileKeyword => return self.parseWhileStatement(),
            kind.Kind.ForKeyword => return self.parseForOrForInOrForOfStatement(),
            kind.Kind.ContinueKeyword => return self.parseContinueStatement(),
            kind.Kind.BreakKeyword => return self.parseBreakStatement(),
            kind.Kind.ReturnKeyword => return self.parseReturnStatement(),
            kind.Kind.WithKeyword => return self.parseWithStatement(),
            kind.Kind.SwitchKeyword => return self.parseSwitchStatement(),
            kind.Kind.ThrowKeyword => return self.parseThrowStatement(),
            kind.Kind.TryKeyword, kind.Kind.CatchKeyword, kind.Kind.FinallyKeyword => return self.parseTryStatement(),
            kind.Kind.DebuggerKeyword => return self.parseDebuggerStatement(),
            kind.Kind.AtToken => return self.parseDeclaration(),
            kind.Kind.ImportKeyword => {
                var tempScanner = self.scanner;
                const next = tempScanner.scan();
                if (next == kind.Kind.OpenParenToken or next == kind.Kind.LessThanToken or next == kind.Kind.DotToken) {
                    return self.parseExpressionStatement();
                }
                return self.parseDeclaration();
            },
            kind.Kind.ConstKeyword => {
                if (self.peekNextToken() == kind.Kind.EnumKeyword) {
                    return self.parseDeclaration();
                }
                return self.parseVariableStatement(null, 0);
            },
            kind.Kind.AsyncKeyword, kind.Kind.InterfaceKeyword, kind.Kind.TypeKeyword, kind.Kind.ModuleKeyword, kind.Kind.NamespaceKeyword, kind.Kind.DeclareKeyword, kind.Kind.EnumKeyword, kind.Kind.ExportKeyword, kind.Kind.PrivateKeyword, kind.Kind.ProtectedKeyword, kind.Kind.PublicKeyword, kind.Kind.AbstractKeyword, kind.Kind.AccessorKeyword, kind.Kind.StaticKeyword, kind.Kind.ReadonlyKeyword, kind.Kind.GlobalKeyword => {
                if (self.isStartOfDeclaration()) {
                    return self.parseDeclaration();
                } else {
                    return self.parseExpressionStatement();
                }
            },
            else => {
                return self.parseExpressionStatement();
            },
        }
    }

    pub fn parseExpressionStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        const expr = try @import("expression.zig").parseExpression(self);

        if (self.token == kind.Kind.ColonToken and std.meta.activeTag(self.ast.getNode(expr)) == .Identifier) {
            _ = self.nextToken(); // consume ':'
            const statement = try self.parseStatement();
            const stmt = try self.ast.pushNode(.{ .LabeledStatement = .{
                .Flags = 0,
                .Label = expr,
                .Statement = statement,
            } });
            self.setNodeStartPos(stmt, start_pos);
            return stmt;
        }

        self.parseSemicolon();
        const es_end = self.scanner.state.tokenStart;

        const stmt = try self.ast.pushNode(.{ .ExpressionStatement = .{
            .Flags = 0,
            .Expression = expr,
        } });
        if (stmt != 0 and stmt < self.ast.positions.items.len) {
            self.ast.positions.items[stmt] = .{ .pos = @intCast(start_pos), .end = @intCast(es_end) };
        }
        return stmt;
    }

    pub fn parseEmptyStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        self.parseSemicolon();
        const stmt = try self.ast.pushNode(.{ .EmptyStatement = .{ .Flags = 0 } });
        self.setNodeStartPos(stmt, start_pos);
        return stmt;
    }

    pub fn parseDoStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.DoKeyword);
        const statement = try self.parseStatement();
        _ = self.parseExpected(kind.Kind.WhileKeyword);
        _ = self.parseExpected(kind.Kind.OpenParenToken);
        const expression = try @import("expression.zig").parseExpression(self);
        _ = self.parseExpected(kind.Kind.CloseParenToken);
        _ = self.parseOptional(kind.Kind.SemicolonToken);
        const stmt = try self.ast.pushNode(.{ .DoStatement = .{ .Flags = 0, .Statement = statement, .Expression = expression } });
        self.setNodeStartPos(stmt, start_pos);
        return stmt;
    }

    pub fn parseContinueStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.ContinueKeyword);
        var label: ?ast_gen.NodeIndex = null;
        if (!self.isSemicolon()) {
            if (self.isIdentifier()) {
                label = try self.parseIdentifier();
            }
        }
        self.parseSemicolon();
        const stmt = try self.ast.pushNode(.{ .ContinueStatement = .{ .Flags = 0, .Label = label } });
        self.setNodeStartPos(stmt, start_pos);
        return stmt;
    }

    pub fn parseBreakStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.BreakKeyword);
        var label: ?ast_gen.NodeIndex = null;
        if (!self.isSemicolon()) {
            if (self.isIdentifier()) {
                label = try self.parseIdentifier();
            }
        }
        self.parseSemicolon();
        const stmt = try self.ast.pushNode(.{ .BreakStatement = .{ .Flags = 0, .Label = label } });
        self.setNodeStartPos(stmt, start_pos);
        return stmt;
    }

    pub fn parseWithStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.WithKeyword);
        _ = self.parseExpected(kind.Kind.OpenParenToken);
        const expression = try @import("expression.zig").parseExpression(self);
        _ = self.parseExpected(kind.Kind.CloseParenToken);
        const statement = try self.parseStatement();
        const stmt = try self.ast.pushNode(.{ .WithStatement = .{ .Flags = 0, .Expression = expression, .Statement = statement } });
        self.setNodeStartPos(stmt, start_pos);
        return stmt;
    }

    pub fn parseCaseBlock(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.OpenBraceToken);
        var clauses_arr = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer clauses_arr.deinit(self.allocator);
        while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
            const clause = try self.parseCaseOrDefaultClause();
            try clauses_arr.append(self.allocator, clause);
        }
        const clauses = try self.ast.pushNodeList(clauses_arr.items);
        _ = self.parseExpected(kind.Kind.CloseBraceToken);
        const block = try self.ast.pushNode(.{ .CaseBlock = .{ .Flags = 0, .Clauses = clauses } });
        self.setNodeStartPos(block, start_pos);
        return block;
    }

    pub fn parseCaseOrDefaultClause(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        if (self.token == kind.Kind.CaseKeyword) {
            self.nextToken();
            const expression = try @import("expression.zig").parseExpression(self);
            _ = self.parseExpected(kind.Kind.ColonToken);
            const statements = try self.parseList(.SwitchClauseStatements, parseStatement);
            const clause = try self.ast.pushNode(.{ .CaseClause = .{ .Flags = 0, .Expression = expression, .Statements = statements } });
            self.setNodeStartPos(clause, start_pos);
            return clause;
        } else {
            _ = self.parseExpected(kind.Kind.DefaultKeyword);
            _ = self.parseExpected(kind.Kind.ColonToken);
            const statements = try self.parseList(.SwitchClauseStatements, parseStatement);
            const clause = try self.ast.pushNode(.{ .DefaultClause = .{ .Flags = 0, .Expression = 0, .Statements = statements } }); // 0 for missing expression
            self.setNodeStartPos(clause, start_pos);
            return clause;
        }
    }

    pub fn parseSwitchStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.SwitchKeyword);
        _ = self.parseExpected(kind.Kind.OpenParenToken);
        const expression = try @import("expression.zig").parseExpression(self);
        _ = self.parseExpected(kind.Kind.CloseParenToken);
        const caseBlock = try self.parseCaseBlock();
        const stmt = try self.ast.pushNode(.{ .SwitchStatement = .{ .Flags = 0, .Expression = expression, .CaseBlock = caseBlock } });
        self.setNodeStartPos(stmt, start_pos);
        return stmt;
    }

    pub fn parseThrowStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.ThrowKeyword);
        var expression: ast_gen.NodeIndex = 0;
        if (!self.scanner.hasPrecedingLineBreak()) {
            expression = try @import("expression.zig").parseExpression(self);
        } else {
            expression = try self.ast.pushNode(.{ .Identifier = .{ .Flags = 0, .Text = "" } });
        }
        self.parseSemicolon();
        const stmt = try self.ast.pushNode(.{ .ThrowStatement = .{ .Flags = 0, .Expression = expression } });
        self.setNodeStartPos(stmt, start_pos);
        return stmt;
    }

    pub fn parseCatchClause(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.CatchKeyword);
        var variableDeclaration: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.OpenParenToken)) {
            variableDeclaration = try self.parseVariableDeclaration();
            _ = self.parseExpected(kind.Kind.CloseParenToken);
        }
        const block = try self.parseBlock();
        const clause = try self.ast.pushNode(.{ .CatchClause = .{ .Flags = 0, .VariableDeclaration = variableDeclaration, .Block = block } });
        self.setNodeStartPos(clause, start_pos);
        return clause;
    }

    pub fn parseTryStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.TryKeyword);
        const tryBlock = try self.parseBlock();
        var catchClause: ?ast_gen.NodeIndex = null;
        if (self.token == kind.Kind.CatchKeyword) {
            catchClause = try self.parseCatchClause();
        }
        var finallyBlock: ?ast_gen.NodeIndex = null;
        if (catchClause == null or self.token == kind.Kind.FinallyKeyword) {
            _ = self.parseExpected(kind.Kind.FinallyKeyword);
            finallyBlock = try self.parseBlock();
        }
        const stmt = try self.ast.pushNode(.{ .TryStatement = .{ .Flags = 0, .TryBlock = tryBlock, .CatchClause = catchClause, .FinallyBlock = finallyBlock } });
        self.setNodeStartPos(stmt, start_pos);
        return stmt;
    }

    pub fn parseDebuggerStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        self.nextToken();
        self.parseSemicolon();
        const stmt = try self.ast.pushNode(.{ .DebuggerStatement = .{ .Flags = 0 } }); // stub
        self.setNodeStartPos(stmt, start_pos);
        return stmt;
    }

    pub fn parseDeclaration(self: *Parser) anyerror!ast_gen.NodeIndex {
        const modifiers = try self.parseModifiers();
        const modifierFlags = self.modifiersToFlags(modifiers);
        return self.parseDeclarationWorker(modifiers, modifierFlags);
    }

    pub fn parseTypeParameterWrapper(self: *Parser) ast_gen.NodeIndex {
        return self.parseTypeParameter() catch 0;
    }

    pub fn parseTypeParameters(self: *Parser) anyerror!?ast_gen.NodeListIndex {
        if (self.token == kind.Kind.LessThanToken) {
            self.nextToken(); // consume `<`
            const typeParametersList = self.parseDelimitedList(.TypeParameters, parseTypeParameterWrapper);
            _ = self.parseExpected(kind.Kind.GreaterThanToken);
            return typeParametersList;
        }
        return null;
    }

    pub fn parseTypeParameter(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        var modifierList = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer modifierList.deinit(self.allocator);

        while (true) {
            if (self.token == kind.Kind.ConstKeyword or self.token == kind.Kind.InKeyword or self.token == kind.Kind.OutKeyword) {
                const modNode = try self.ast.pushTokenNode(self.token);
                try modifierList.append(self.allocator, modNode);
                self.nextToken();
            } else {
                break;
            }
        }

        const modifiers = if (modifierList.items.len > 0) try self.ast.pushNodeList(modifierList.items) else null;
        const name = self.parseIdentifier() catch 0;

        var constraint: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.ExtendsKeyword)) {
            constraint = self.parseType() catch 0;
        }

        var defaultType: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.EqualsToken)) {
            defaultType = self.parseType() catch 0;
        }

        const param = try self.ast.pushNode(.{ .TypeParameter = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = 0,
            .name = name,
            .Constraint = constraint,
            .Expression = null,
            .DefaultType = defaultType,
        } });
        self.setNodeStartPos(param, start_pos);
        if (param != 0 and param < self.ast.positions.items.len) {
            var end_pos = self.ast.getNodeEnd(name);
            if (constraint) |c_node| {
                if (c_node != 0) {
                    end_pos = self.ast.getNodeEnd(c_node);
                }
            }
            if (defaultType) |d_node| {
                if (d_node != 0) {
                    end_pos = self.ast.getNodeEnd(d_node);
                }
            }
            self.ast.positions.items[param].end = @intCast(end_pos);
        }
        return param;
    }

    pub fn parseDeclarationWorker(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        switch (self.token) {
            kind.Kind.VarKeyword, kind.Kind.LetKeyword, kind.Kind.ConstKeyword => {
                return self.parseVariableStatement(modifiers, modifierFlags);
            },
            kind.Kind.UsingKeyword => {
                if (self.isUsingDeclaration()) {
                    return self.parseVariableStatement(modifiers, modifierFlags);
                } else {
                    return self.parseExpressionStatement();
                }
            },
            kind.Kind.FunctionKeyword => {
                return self.parseFunctionDeclaration(modifiers, modifierFlags);
            },
            kind.Kind.ClassKeyword => {
                return self.parseClassDeclaration(modifiers, modifierFlags);
            },
            kind.Kind.InterfaceKeyword => {
                return self.parseInterfaceDeclaration(modifiers, modifierFlags);
            },
            kind.Kind.TypeKeyword => {
                return self.parseTypeAliasDeclaration(modifiers, modifierFlags);
            },
            kind.Kind.EnumKeyword => {
                return self.parseEnumDeclaration(modifiers, modifierFlags);
            },
            kind.Kind.ModuleKeyword, kind.Kind.NamespaceKeyword, kind.Kind.GlobalKeyword => {
                return self.parseModuleDeclaration(modifiers, modifierFlags);
            },
            kind.Kind.ImportKeyword => {
                return self.parseImportDeclaration(modifiers, modifierFlags);
            },
            kind.Kind.ExportKeyword => {
                return self.parseExportDeclaration(modifiers, modifierFlags);
            },
            kind.Kind.DefaultKeyword => {
                // This happens when `export` was consumed as a modifier, but `default` was not.
                // So it's an `export default <expression>`
                self.nextToken();
                const expression = try @import("expression.zig").parseExpression(self);
                self.parseSemicolon();
                return self.ast.pushNode(.{
                    .ExportAssignment = .{
                        .Symbol = 0,
                        .Flags = 0,
                        .modifiers = modifiers,
                        .modifierFlags = modifierFlags,
                        .IsExportEquals = 0,
                        .Type = 0, // Should be null or 0? ast_gen says optional NodeIndex or 0? Wait, it's 0 usually? Or null? Let's check.
                        // Actually, I'll just use what I had in parseExportDeclaration
                        .Expression = expression,
                    },
                });
            },
            else => {
                // Return a MissingDeclaration if nothing matched
                self.nextToken();
                return self.ast.pushNode(.{ .Unknown = void{} });
            },
        }
    }

    pub fn parseSignatureMember(self: *Parser, kindTag: kind.Kind) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        if (kindTag == .ConstructSignature) {
            _ = self.parseExpected(kind.Kind.NewKeyword);
        }
        const typeParameters = try self.parseTypeParameters();
        const parameters = try self.parseParameters();
        const returnType = try self.parseReturnTypeAnnotation();
        self.parseTypeMemberSemicolon();

        if (kindTag == .ConstructSignature) {
            const sig = try self.ast.pushNode(.{ .ConstructSignature = .{
                .Flags = 0,
                .Symbol = 0,
                .TypeParameters = typeParameters,
                .Parameters = parameters,
                .Type = returnType,
                .FullSignature = null,
            } });
            self.setNodeStartPos(sig, start_pos);
            return sig;
        } else {
            const sig = try self.ast.pushNode(.{ .CallSignature = .{
                .Flags = 0,
                .Symbol = 0,
                .TypeParameters = typeParameters,
                .Parameters = parameters,
                .Type = returnType,
                .FullSignature = null,
            } });
            self.setNodeStartPos(sig, start_pos);
            return sig;
        }
    }

    pub fn parseTypeMember(self: *Parser) anyerror!ast_gen.NodeIndex {
        const member_start = self.scanner.state.tokenStart;
        if (self.token == kind.Kind.OpenParenToken or self.token == kind.Kind.LessThanToken) {
            return self.parseSignatureMember(.CallSignature);
        }
        if (self.token == kind.Kind.NewKeyword) {
            var tempScanner = self.scanner;
            const nextTok = tempScanner.scan();
            if (nextTok == kind.Kind.OpenParenToken or nextTok == kind.Kind.LessThanToken) {
                return self.parseSignatureMember(.ConstructSignature);
            }
        }

        const modifiers = try self.parseModifiers();
        const modifierFlags = self.modifiersToFlags(modifiers);

        var isGet = false;
        var isSet = false;
        if (self.token == kind.Kind.GetKeyword) {
            var tempScanner = self.scanner;
            const tok = tempScanner.scan();
            if (tok == kind.Kind.OpenBracketToken or tok == kind.Kind.AsteriskToken or tok == kind.Kind.Identifier or kind.isKeyword(tok) or tok == kind.Kind.StringLiteral or tok == kind.Kind.NumericLiteral or tok == kind.Kind.BigIntLiteral) {
                isGet = true;
                self.nextToken(); // consume get
            }
        } else if (self.token == kind.Kind.SetKeyword) {
            var tempScanner = self.scanner;
            const tok = tempScanner.scan();
            if (tok == kind.Kind.OpenBracketToken or tok == kind.Kind.AsteriskToken or tok == kind.Kind.Identifier or kind.isKeyword(tok) or tok == kind.Kind.StringLiteral or tok == kind.Kind.NumericLiteral or tok == kind.Kind.BigIntLiteral) {
                isSet = true;
                self.nextToken(); // consume set
            }
        }

        if (self.isIndexSignature()) {
            const sig = try self.parseIndexSignatureDeclaration(modifiers, modifierFlags);
            self.setNodeStartPos(sig, member_start);
            return sig;
        }

        const name = try self.parsePropertyName();

        var questionToken: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.QuestionToken)) {
            questionToken = try self.ast.pushTokenNode(kind.Kind.QuestionToken);
        }

        if (self.token == kind.Kind.OpenParenToken or self.token == kind.Kind.LessThanToken) {
            const typeParameters = try self.parseTypeParameters();
            const parameters = try self.parseParameters();
            const returnType = try self.parseReturnTypeAnnotation();
            self.parseTypeMemberSemicolon();
            if (isGet) {
                const sig = try self.ast.pushNode(.{ .GetAccessor = .{
                    .Flags = 0,
                    .Symbol = 0,
                    .modifiers = modifiers,
                    .modifierFlags = modifierFlags,
                    .name = name,
                    .TypeParameters = typeParameters,
                    .Parameters = parameters,
                    .Type = returnType,
                    .Body = null,
                    .PostfixToken = questionToken,
                    .FullSignature = null,
                    .AsteriskToken = null,
                } });
                self.setNodeStartPos(sig, member_start);
                return sig;
            } else if (isSet) {
                const sig = try self.ast.pushNode(.{ .SetAccessor = .{
                    .Flags = 0,
                    .Symbol = 0,
                    .modifiers = modifiers,
                    .modifierFlags = modifierFlags,
                    .name = name,
                    .TypeParameters = typeParameters,
                    .Parameters = parameters,
                    .Type = returnType,
                    .Body = null,
                    .PostfixToken = questionToken,
                    .FullSignature = null,
                    .AsteriskToken = null,
                } });
                self.setNodeStartPos(sig, member_start);
                return sig;
            } else {
                const sig = try self.ast.pushNode(.{ .MethodSignature = .{
                    .Flags = 0,
                    .Symbol = 0,
                    .modifiers = modifiers,
                    .modifierFlags = modifierFlags,
                    .name = name,
                    .PostfixToken = questionToken,
                    .TypeParameters = typeParameters,
                    .Parameters = parameters,
                    .Type = returnType,
                    .FullSignature = null,
                } });
                self.setNodeStartPos(sig, member_start);
                return sig;
            }
        } else {
            const typeNode = try self.parseTypeAnnotation();
            var initializer: ?ast_gen.NodeIndex = null;
            if (self.parseOptional(kind.Kind.EqualsToken)) {
                initializer = try @import("expression.zig").parseAssignmentExpressionOrHigher(self);
            }
            self.parseTypeMemberSemicolon();
            const sig = try self.ast.pushNode(.{ .PropertySignature = .{
                .Flags = 0,
                .Symbol = 0,
                .modifiers = modifiers,
                .modifierFlags = modifierFlags,
                .name = name,
                .PostfixToken = questionToken,
                .Type = typeNode orelse 0,
                .Initializer = initializer orelse 0,
            } });
            self.setNodeStartPos(sig, member_start);
            return sig;
        }
    }

    pub fn parseInterfaceDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.InterfaceKeyword);
        const name = try self.parseIdentifier();
        const typeParameters = try self.parseTypeParameters();
        const heritageClauses = try self.parseHeritageClauses();

        _ = self.parseExpected(kind.Kind.OpenBraceToken);
        var members_arr = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer members_arr.deinit(self.allocator);
        while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
            const startPos = self.scanner.state.pos;
            const memberNode = try self.parseTypeMember();
            try members_arr.append(self.allocator, memberNode);
            if (self.scanner.state.pos == startPos) {
                self.nextToken(); // force advance if stuck
            }
        }
        _ = self.parseExpected(kind.Kind.CloseBraceToken);
        const iface_end = self.scanner.state.tokenStart;
        const members = try self.ast.pushNodeList(members_arr.items);

        const decl = try self.ast.pushNode(.{ .InterfaceDeclaration = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .name = name,
            .TypeParameters = typeParameters,
            .HeritageClauses = heritageClauses,
            .Members = members,
        } });
        if (decl != 0 and decl < self.ast.positions.items.len) {
            self.ast.positions.items[decl] = .{ .pos = @intCast(start_pos), .end = @intCast(iface_end) };
        }
        return decl;
    }

    pub fn parseTypeAliasDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.TypeKeyword);
        const name = try self.parseIdentifier();
        const typeParameters = try self.parseTypeParameters();
        _ = self.parseExpected(kind.Kind.EqualsToken);
        const typeNode = try self.parseType();
        const type_alias_end = self.scanner.state.tokenStart;
        self.parseSemicolon();

        const decl = try self.ast.pushNode(.{ .TypeAliasDeclaration = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .name = name,
            .TypeParameters = typeParameters,
            .Type = typeNode,
        } });
        if (decl != 0 and decl < self.ast.positions.items.len) {
            self.ast.positions.items[decl] = .{ .pos = @intCast(start_pos), .end = @intCast(type_alias_end) };
        }
        return decl;
    }

    pub fn parseEnumDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.EnumKeyword);
        const name = try self.parseIdentifier();

        _ = self.parseExpected(kind.Kind.OpenBraceToken);
        var members_arr = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer members_arr.deinit(self.allocator);
        while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
            const memberNode = try self.parseEnumMember();
            try members_arr.append(self.allocator, memberNode);
            if (self.token == kind.Kind.CommaToken) {
                self.nextToken();
            } else {
                break;
            }
        }
        _ = self.parseOptional(kind.Kind.CommaToken);
        _ = self.parseExpected(kind.Kind.CloseBraceToken);
        const enum_end = self.scanner.state.tokenStart;
        const members = try self.ast.pushNodeList(members_arr.items);

        const decl = try self.ast.pushNode(.{ .EnumDeclaration = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .name = name,
            .Members = members,
        } });
        if (decl != 0 and decl < self.ast.positions.items.len) {
            self.ast.positions.items[decl] = .{ .pos = @intCast(start_pos), .end = @intCast(enum_end) };
        }
        return decl;
    }

    pub fn parseEnumMember(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        const name = try self.parsePropertyName();
        var initializer: ?ast_gen.NodeIndex = null;
        if (self.token == kind.Kind.EqualsToken) {
            self.nextToken();
            initializer = try @import("expression.zig").parseAssignmentExpressionOrHigher(self);
        }
        const member = try self.ast.pushNode(.{ .EnumMember = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = null,
            .modifierFlags = 0,
            .name = name,
            .PostfixToken = null,
            .Initializer = initializer,
        } });
        self.setNodeStartPos(member, start_pos);
        return member;
    }

    fn parseModuleBlock(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.OpenBraceToken);

        const statements = try self.parseList(.BlockStatements, parseStatement);
        _ = self.parseExpected(kind.Kind.CloseBraceToken);

        const block = try self.ast.pushNode(.{ .ModuleBlock = .{
            .Flags = 0,
            .Statements = statements,
        } });
        self.setNodeStartPos(block, start_pos);
        return block;
    }

    pub fn parseModuleOrNamespaceDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32, nested: bool, keyword: kind.Kind, flags: u32, start_pos: usize) anyerror!ast_gen.NodeIndex {
        var name: ?ast_gen.NodeIndex = null;
        if (nested) {
            name = try self.parseIdentifierName();
        } else {
            name = try self.parseIdentifier();
        }

        var body: ?ast_gen.NodeIndex = null;
        const nodeFlags = flags;
        if (self.parseOptional(kind.Kind.DotToken)) {
            // Implicit export modifier for nested namespace?
            // In zig we just set NestedNamespace flag for the inner module
            body = try self.parseModuleOrNamespaceDeclaration(null, 0, true, keyword, 0, self.scanner.state.tokenStart);
            if (body != null and body.? != 0) {
                var inner_node = self.ast.getNode(body.?);
                if (inner_node == .ModuleDeclaration) {
                    inner_node.ModuleDeclaration.Flags |= @import("../ast/ast_utils.zig").NodeFlags.NestedNamespace;
                    self.ast.nodes.set(body.?, inner_node);
                }
            }
        } else {
            body = try self.parseModuleBlock();
        }
        const ns_end = self.scanner.state.tokenStart;

        const decl = try self.ast.pushNode(.{ .ModuleDeclaration = .{
            .Symbol = 0,
            .Flags = nodeFlags,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .AsteriskToken = null,
            .Body = body,
            .Keyword = @intFromEnum(keyword),
            .name = name.?,
        } });
        if (decl != 0 and decl < self.ast.positions.items.len) {
            self.ast.positions.items[decl] = .{ .pos = @intCast(start_pos), .end = @intCast(ns_end) };
        }
        return decl;
    }

    pub fn parseModuleDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        var keyword: kind.Kind = kind.Kind.ModuleKeyword;
        var flags: u32 = 0;
        var isAmbientExternal = false;

        if (self.token == kind.Kind.GlobalKeyword) {
            keyword = kind.Kind.GlobalKeyword;
            flags |= @import("../ast/ast_utils.zig").NodeFlags.GlobalAugmentation;
            isAmbientExternal = true;
        } else {
            if (self.parseOptional(kind.Kind.NamespaceKeyword)) {
                keyword = kind.Kind.NamespaceKeyword;
                flags |= @import("../ast/ast_utils.zig").NodeFlags.Namespace;
            } else {
                _ = self.parseExpected(kind.Kind.ModuleKeyword);
                if (self.token == kind.Kind.StringLiteral) {
                    isAmbientExternal = true;
                }
            }
        }

        if (isAmbientExternal) {
            var name: ?ast_gen.NodeIndex = null;
            if (keyword == kind.Kind.GlobalKeyword) {
                name = try self.parseIdentifier();
            } else {
                name = try @import("expression.zig").parseLiteralExpression(self);
            }

            var body: ?ast_gen.NodeIndex = null;
            if (self.token == kind.Kind.OpenBraceToken) {
                body = try self.parseModuleBlock();
            } else {
                self.parseSemicolon();
            }
            const mod_end = self.scanner.state.tokenStart;

            const decl = try self.ast.pushNode(.{ .ModuleDeclaration = .{
                .Symbol = 0,
                .Flags = flags,
                .modifiers = modifiers,
                .modifierFlags = modifierFlags,
                .AsteriskToken = null,
                .Body = body,
                .Keyword = @intFromEnum(keyword),
                .name = name orelse 0,
            } });
            if (decl != 0 and decl < self.ast.positions.items.len) {
                self.ast.positions.items[decl] = .{ .pos = @intCast(start_pos), .end = @intCast(mod_end) };
            }
            return decl;
        }

        return self.parseModuleOrNamespaceDeclaration(modifiers, modifierFlags, false, keyword, flags, start_pos);
    }

    pub fn parseImportDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        const statement_start = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.ImportKeyword);

        var isTypeOnly: u32 = 0;
        var phaseModifier: ?ast_gen.NodeIndex = null;

        if (self.token == kind.Kind.TypeKeyword) {
            var tempScanner = self.scanner;
            const nextTok = tempScanner.scan();
            if (nextTok == kind.Kind.AsteriskToken or nextTok == kind.Kind.OpenBraceToken or ((nextTok == kind.Kind.Identifier or kind.isKeyword(nextTok)) and nextTok != kind.Kind.FromKeyword and nextTok != kind.Kind.EqualsToken and nextTok != kind.Kind.CommaToken)) {
                isTypeOnly = 1;
                phaseModifier = try self.ast.pushNode(.{ .TypeKeyword = void{} });
                self.nextToken(); // consume type keyword
            }
        }

        // Handle `import identifier = require(...)` or `import identifier = namespace.path` (ImportEquals)
        if (self.token == kind.Kind.Identifier or kind.isKeyword(self.token)) {
            var tempScanner = self.scanner;
            const nextTok = tempScanner.scan();
            if (nextTok == kind.Kind.EqualsToken) {
                // This is an ImportEqualsDeclaration
                const name = try self.parseIdentifier();
                self.nextToken(); // consume '='
                // Parse the module reference: require("...") or a namespace path
                var moduleReference: ast_gen.NodeIndex = 0;
                if (self.token == kind.Kind.RequireKeyword) {
                    self.nextToken(); // consume 'require'
                    _ = self.parseExpected(kind.Kind.OpenParenToken);
                    if (self.token == kind.Kind.StringLiteral) {
                        const str_expr = try @import("expression.zig").parseExpression(self);
                        moduleReference = try self.ast.pushNode(.{ .ExternalModuleReference = .{
                            .Flags = 0,
                            .Expression = str_expr,
                        } });
                    }
                    _ = self.parseExpected(kind.Kind.CloseParenToken);
                    self.parseSemicolon();
                    const decl = try self.ast.pushNode(.{ .ImportEqualsDeclaration = .{
                        .Symbol = 0,
                        .Flags = 0,
                        .modifiers = modifiers,
                        .modifierFlags = modifierFlags,
                        .IsTypeOnly = isTypeOnly,
                        .name = name,
                        .ModuleReference = moduleReference,
                    } });
                    self.ast.positions.items[decl].pos = @intCast(statement_start);
                    return decl;
                } else {
                    // Namespace/entity name path
                    moduleReference = try self.parseIdentifier();
                    while (self.parseOptional(kind.Kind.DotToken)) {
                        const right = try self.parseIdentifier();
                        moduleReference = try self.ast.pushNode(.{ .QualifiedName = .{
                            .Flags = 0,
                            .Left = moduleReference,
                            .Right = right,
                        } });
                    }
                    self.parseSemicolon();
                    const decl = try self.ast.pushNode(.{ .ImportEqualsDeclaration = .{
                        .Symbol = 0,
                        .Flags = 0,
                        .modifiers = modifiers,
                        .modifierFlags = modifierFlags,
                        .IsTypeOnly = isTypeOnly,
                        .name = name,
                        .ModuleReference = moduleReference,
                    } });
                    self.ast.positions.items[decl].pos = @intCast(statement_start);
                    return decl;
                }
            }
        }

        var importClause: ?ast_gen.NodeIndex = null;
        if (self.token != kind.Kind.StringLiteral and self.token != kind.Kind.SemicolonToken) {
            importClause = try self.parseImportClause(phaseModifier);
        }

        if (self.token == kind.Kind.FromKeyword or (self.token == kind.Kind.Identifier and std.mem.eql(u8, self.scanner.state.tokenValue, "from"))) {
            self.nextToken();
        }

        const moduleSpecifier = if (self.token == kind.Kind.StringLiteral) try @import("expression.zig").parseExpression(self) else 0;

        const attributes = try self.parseImportAttributes();

        self.parseSemicolon();
        const decl = try self.ast.pushNode(.{ .ImportDeclaration = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .ImportClause = importClause orelse 0,
            .ModuleSpecifier = moduleSpecifier,
            .Attributes = attributes,
        } });
        self.setNodeStartPos(decl, statement_start);
        return decl;
    }

    pub fn parseImportAttributes(self: *Parser) anyerror!?ast_gen.NodeIndex {
        var attributes: ?ast_gen.NodeIndex = null;
        if (self.token == kind.Kind.AssertKeyword or self.token == kind.Kind.WithKeyword or (self.token == kind.Kind.Identifier and std.mem.eql(u8, self.scanner.state.tokenValue, "with"))) {
            const attrToken = self.token;
            self.nextToken();
            if (self.token == kind.Kind.OpenBraceToken) {
                self.nextToken();
                var elements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
                defer elements.deinit(self.allocator);
                while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
                    const nameNode = try self.parsePropertyName();
                    _ = self.parseExpected(kind.Kind.ColonToken);
                    const valueNode = try @import("expression.zig").parseAssignmentExpressionOrHigher(self);
                    const attrNode = try self.ast.pushNode(.{ .ImportAttribute = .{
                        .Flags = 0,
                        .name = nameNode,
                        .Value = valueNode,
                    } });
                    try elements.append(self.allocator, attrNode);
                    if (self.token == kind.Kind.CommaToken) {
                        self.nextToken();
                    } else {
                        break;
                    }
                }
                const elementsList = try self.ast.pushNodeList(elements.items);
                _ = self.parseExpected(kind.Kind.CloseBraceToken);
                attributes = try self.ast.pushNode(.{ .ImportAttributes = .{
                    .Flags = 0,
                    .Token = @intFromEnum(attrToken),
                    .Attributes = elementsList,
                    .MultiLine = 0,
                } });
            }
        }
        return attributes;
    }

    fn parseImportClause(self: *Parser, phaseModifier: ?ast_gen.NodeIndex) anyerror!ast_gen.NodeIndex {
        var name: ?ast_gen.NodeIndex = null;
        var namedBindings: ?ast_gen.NodeIndex = null;

        if (self.token == kind.Kind.Identifier) {
            name = try self.parseIdentifier();
            if (self.token == kind.Kind.CommaToken) {
                self.nextToken();
            }
        }

        if (self.token == kind.Kind.AsteriskToken) {
            // NamespaceImport - simplified
            self.nextToken();
            if (self.token == kind.Kind.AsKeyword) self.nextToken();
            const nsName = try self.parseIdentifier();
            namedBindings = try self.ast.pushNode(.{ .NamespaceImport = .{
                .Symbol = 0,
                .name = nsName,
                .Flags = 0,
            } });
        } else if (self.token == kind.Kind.OpenBraceToken) {
            // NamedImports
            self.nextToken();
            var elements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
            defer elements.deinit(self.allocator);

            while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
                var specIsTypeOnly: u32 = 0;
                var propertyName: ?ast_gen.NodeIndex = null;
                var specName = try self.parseModuleExportName();

                var isTypeKeyword = false;
                const specNode = self.ast.getNode(specName);
                if (specNode == .Identifier) {
                    if (std.mem.eql(u8, specNode.Identifier.Text, "type")) {
                        isTypeKeyword = true;
                    }
                }

                if (isTypeKeyword and self.token != kind.Kind.CommaToken and self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.AsKeyword) {
                    specIsTypeOnly = 1;
                    propertyName = try self.parseModuleExportName();
                    if (self.token == kind.Kind.AsKeyword) {
                        self.nextToken();
                        specName = try self.parseModuleExportName();
                    } else {
                        specName = propertyName.?;
                        propertyName = null;
                    }
                } else {
                    if (self.token == kind.Kind.AsKeyword) {
                        self.nextToken();
                        propertyName = specName;
                        specName = try self.parseModuleExportName();
                    }
                }

                const specifier = try self.ast.pushNode(.{ .ImportSpecifier = .{
                    .Symbol = 0,
                    .PropertyName = propertyName,
                    .name = specName,
                    .Flags = 0,
                    .IsTypeOnly = specIsTypeOnly,
                } });
                try elements.append(self.allocator, specifier);

                if (self.token == kind.Kind.CommaToken) {
                    self.nextToken();
                } else {
                    break;
                }
            }
            if (self.token == kind.Kind.CloseBraceToken) {
                self.nextToken();
            }
            namedBindings = try self.ast.pushNode(.{ .NamedImports = .{
                .Elements = try self.ast.pushNodeList(elements.items),
                .Flags = 0,
            } });
        }

        return self.ast.pushNode(.{ .ImportClause = .{
            .Symbol = 0,
            .PhaseModifier = phaseModifier,
            .name = name,
            .NamedBindings = namedBindings,
            .Flags = 0,
        } });
    }

    pub fn parseExportDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.ExportKeyword);
        if (self.token == kind.Kind.DefaultKeyword) {
            self.nextToken();
            const expression = try @import("expression.zig").parseExpression(self);
            self.parseSemicolon();
            const decl = try self.ast.pushNode(.{ .ExportAssignment = .{
                .Symbol = 0,
                .Flags = 0,
                .modifiers = modifiers,
                .modifierFlags = modifierFlags,
                .IsExportEquals = 0,
                .Type = 0,
                .Expression = expression,
            } });
            self.setNodeStartPos(decl, start_pos);
            return decl;
        } else if (self.token == kind.Kind.EqualsToken) {
            self.nextToken();
            const expression = try @import("expression.zig").parseExpression(self);
            self.parseSemicolon();
            const decl = try self.ast.pushNode(.{ .ExportAssignment = .{
                .Symbol = 0,
                .Flags = 0,
                .modifiers = modifiers,
                .modifierFlags = modifierFlags,
                .IsExportEquals = 1,
                .Type = 0,
                .Expression = expression,
            } });
            self.setNodeStartPos(decl, start_pos);
            return decl;
        } else if (self.token == kind.Kind.AsKeyword) {
            self.nextToken();
            _ = self.parseExpected(kind.Kind.NamespaceKeyword);
            const name = try self.parseIdentifier();
            self.parseSemicolon();
            const decl = try self.ast.pushNode(.{ .NamespaceExportDeclaration = .{
                .Symbol = 0,
                .Flags = 0,
                .modifiers = modifiers,
                .modifierFlags = modifierFlags,
                .name = name,
            } });
            self.setNodeStartPos(decl, start_pos);
            return decl;
        } else {
            var exportClause: ?ast_gen.NodeIndex = null;
            var isTypeOnly: u1 = 0;
            if (self.parseOptional(kind.Kind.TypeKeyword)) {
                isTypeOnly = 1;
            }
            if (self.token == kind.Kind.OpenBraceToken) {
                self.nextToken();
                var elements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
                defer elements.deinit(self.allocator);
                while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
                    const startPos = self.scanner.state.pos;

                    var specIsTypeOnly: u32 = 0;
                    var propertyName: ?ast_gen.NodeIndex = null;
                    var specName = try self.parseModuleExportName();

                    var isTypeKeyword = false;
                    const specNode = self.ast.getNode(specName);
                    if (specNode == .Identifier) {
                        if (std.mem.eql(u8, specNode.Identifier.Text, "type")) {
                            isTypeKeyword = true;
                        }
                    }

                    if (isTypeKeyword and self.token != kind.Kind.CommaToken and self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.AsKeyword) {
                        specIsTypeOnly = 1;
                        propertyName = try self.parseModuleExportName();
                        if (self.token == kind.Kind.AsKeyword) {
                            self.nextToken();
                            specName = try self.parseModuleExportName();
                        } else {
                            specName = propertyName.?;
                            propertyName = null;
                        }
                    } else {
                        if (self.token == kind.Kind.AsKeyword) {
                            self.nextToken();
                            propertyName = specName;
                            specName = try self.parseModuleExportName();
                        }
                    }

                    const specifier = try self.ast.pushNode(.{ .ExportSpecifier = .{
                        .Flags = 0,
                        .Symbol = 0,
                        .name = specName,
                        .PropertyName = propertyName,
                        .IsTypeOnly = specIsTypeOnly,
                    } });
                    try elements.append(self.allocator, specifier);
                    if (self.token == kind.Kind.CommaToken) {
                        self.nextToken();
                    }
                    if (self.scanner.state.pos == startPos) {
                        self.nextToken(); // force advance
                    }
                }
                _ = self.parseExpected(kind.Kind.CloseBraceToken);
                const elementsList = try self.ast.pushNodeList(elements.items);
                exportClause = try self.ast.pushNode(.{ .NamedExports = .{
                    .Flags = 0,
                    .Elements = elementsList,
                } });
            } else if (self.token == kind.Kind.AsteriskToken) {
                self.nextToken();
                if (self.token == kind.Kind.AsKeyword) {
                    self.nextToken();
                    const nsName = try self.parseIdentifier();
                    exportClause = try self.ast.pushNode(.{ .NamespaceExport = .{
                        .Symbol = 0,
                        .name = nsName,
                        .Flags = 0,
                    } });
                } else {
                    exportClause = 0;
                }
            }

            var moduleSpecifier: ast_gen.NodeIndex = 0;
            if (self.token == kind.Kind.FromKeyword or (self.token == kind.Kind.Identifier and std.mem.eql(u8, self.scanner.state.tokenValue, "from"))) {
                self.nextToken();
                if (self.token == kind.Kind.StringLiteral) {
                    moduleSpecifier = try @import("expression.zig").parseExpression(self);
                }
            } else if (self.token == kind.Kind.FromKeyword) {
                self.nextToken();
                if (self.token == kind.Kind.StringLiteral) {
                    moduleSpecifier = try @import("expression.zig").parseExpression(self);
                }
            }

            const attributes = try self.parseImportAttributes();

            self.parseSemicolon();
            const decl = try self.ast.pushNode(.{ .ExportDeclaration = .{
                .Symbol = 0,
                .Flags = 0,
                .modifiers = modifiers,
                .modifierFlags = modifierFlags,
                .IsTypeOnly = isTypeOnly,
                .ExportClause = exportClause orelse 0,
                .ModuleSpecifier = moduleSpecifier,
                .Attributes = attributes,
            } });
            self.setNodeStartPos(decl, start_pos);
            return decl;
        }
    }

    pub fn isSemicolon(self: *Parser) bool {
        return self.token == kind.Kind.SemicolonToken or self.token == kind.Kind.CloseBraceToken or self.token == kind.Kind.EndOfFile or self.scanner.hasPrecedingLineBreak();
    }

    pub fn parseVariableStatement(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        const declarationList = try self.parseVariableDeclarationList();
        self.parseSemicolon();

        const stmt = try self.ast.pushNode(.{ .VariableStatement = .{
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .DeclarationList = declarationList,
        } });
        self.setNodeStartPos(stmt, start_pos);
        return stmt;
    }

    pub fn parseVariableDeclarationList(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        var flags: u32 = 0;
        if (self.token == kind.Kind.LetKeyword) {
            flags |= @import("../ast/ast_utils.zig").NodeFlags.Let;
            self.nextToken();
        } else if (self.token == kind.Kind.ConstKeyword) {
            flags |= @import("../ast/ast_utils.zig").NodeFlags.Const;
            self.nextToken();
        } else if (self.token == kind.Kind.UsingKeyword) {
            flags |= @import("../ast/ast_utils.zig").NodeFlags.Using;
            self.nextToken();
        } else if (self.token == kind.Kind.AwaitKeyword) {
            flags |= @import("../ast/ast_utils.zig").NodeFlags.AwaitUsing;
            self.nextToken();
            // Should be UsingKeyword now
            if (self.token == kind.Kind.UsingKeyword) {
                self.nextToken();
            }
        } else if (self.token == kind.Kind.VarKeyword) {
            self.nextToken();
        }

        const declarations = self.parseDelimitedList(.VariableDeclarations, parseVariableDeclarationWrapper);

        const list = try self.ast.pushNode(.{ .VariableDeclarationList = .{
            .Flags = flags,
            .Declarations = declarations,
        } });
        self.setNodeStartPos(list, start_pos);
        return list;
    }

    pub fn parseObjectBindingElement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        var dotDotDotToken: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.DotDotDotToken)) {
            dotDotDotToken = try self.ast.pushTokenNode(kind.Kind.DotDotDotToken);
        }

        const tokenIsIdentifier = self.isIdentifier();
        var propertyName: ?ast_gen.NodeIndex = try self.parsePropertyName();
        var name: ?ast_gen.NodeIndex = null;

        if (tokenIsIdentifier and self.token != kind.Kind.ColonToken) {
            name = propertyName;
            propertyName = null;
        } else {
            _ = self.parseExpected(kind.Kind.ColonToken);
            name = try self.parseIdentifierOrPattern();
        }

        var initializer: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.EqualsToken)) {
            initializer = try @import("expression.zig").parseAssignmentExpressionOrHigher(self);
        }

        const elem = try self.ast.pushNode(.{ .BindingElement = .{
            .Symbol = 0,
            .Flags = 0,
            .DotDotDotToken = dotDotDotToken,
            .PropertyName = propertyName,
            .name = name.?,
            .Initializer = initializer,
        } });
        self.setNodeStartPos(elem, start_pos);
        return elem;
    }

    pub fn parseArrayBindingElement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        var dotDotDotToken: ?ast_gen.NodeIndex = null;
        var name: ?ast_gen.NodeIndex = null;
        var initializer: ?ast_gen.NodeIndex = null;

        if (self.token != kind.Kind.CommaToken and self.token != kind.Kind.CloseBracketToken) {
            if (self.parseOptional(kind.Kind.DotDotDotToken)) {
                dotDotDotToken = try self.ast.pushTokenNode(kind.Kind.DotDotDotToken);
            }
            name = try self.parseIdentifierOrPattern();

            if (self.parseOptional(kind.Kind.EqualsToken)) {
                initializer = try @import("expression.zig").parseAssignmentExpressionOrHigher(self);
            }
        }

        const elem = try self.ast.pushNode(.{ .BindingElement = .{
            .Symbol = 0,
            .Flags = 0,
            .DotDotDotToken = dotDotDotToken,
            .PropertyName = null,
            .name = name,
            .Initializer = initializer,
        } });
        self.setNodeStartPos(elem, start_pos);
        return elem;
    }

    pub fn parseObjectBindingElementWrapper(self: *Parser) ast_gen.NodeIndex {
        return self.parseObjectBindingElement() catch 0;
    }

    pub fn parseObjectBindingPattern(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.OpenBraceToken);
        const elements = self.parseDelimitedList(.ObjectBindingElements, parseObjectBindingElementWrapper);
        _ = self.parseExpected(kind.Kind.CloseBraceToken);
        const pattern = try self.ast.pushNode(.{ .ObjectBindingPattern = .{ .Flags = 0, .Elements = elements } });
        self.setNodeStartPos(pattern, start_pos);
        return pattern;
    }

    pub fn parseArrayBindingElementWrapper(self: *Parser) ast_gen.NodeIndex {
        return self.parseArrayBindingElement() catch 0;
    }

    pub fn parseArrayBindingPattern(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.OpenBracketToken);
        const elements = self.parseDelimitedList(.ArrayBindingElements, parseArrayBindingElementWrapper);
        _ = self.parseExpected(kind.Kind.CloseBracketToken);
        const pattern = try self.ast.pushNode(.{ .ArrayBindingPattern = .{ .Flags = 0, .Elements = elements } });
        self.setNodeStartPos(pattern, start_pos);
        return pattern;
    }

    pub fn parseIdentifierOrPattern(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.token == kind.Kind.OpenBracketToken) {
            return self.parseArrayBindingPattern();
        }
        if (self.token == kind.Kind.OpenBraceToken) {
            return self.parseObjectBindingPattern();
        }
        return self.parseIdentifier();
    }

    pub fn parseVariableDeclaration(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        const jsdoc_info = self.jsdocScannerInfo();
        const name = try self.parseIdentifierOrPattern();
        const nameNode = self.ast.getNode(name);
        if (nameNode == .Identifier) {}

        var exclamationToken: ?ast_gen.NodeIndex = null;
        if (self.token == kind.Kind.ExclamationToken and !self.scanner.hasPrecedingLineBreak()) {
            exclamationToken = try self.ast.pushNode(.{ .ExclamationToken = void{} });
            self.nextToken();
        }

        const typeNode = try self.parseTypeAnnotation();
        var initializer: ?ast_gen.NodeIndex = null;

        if (self.parseOptional(kind.Kind.EqualsToken)) {
            initializer = try @import("expression.zig").parseAssignmentExpressionOrHigher(self);
        }

        const result = try self.ast.pushNode(.{
            .VariableDeclaration = .{
                .Symbol = 0,
                .Flags = 0,
                .name = name,
                .ExclamationToken = exclamationToken,
                .Type = typeNode,
                .Initializer = initializer,
            },
        });
        self.setNodeStartPos(result, start_pos);
        _ = try jsdoc.withJSDoc(self, result, jsdoc_info);
        return result;
    }

    pub fn parseVariableDeclarationWrapper(self: *Parser) ast_gen.NodeIndex {
        return self.parseVariableDeclaration() catch self.ast.pushNode(.{ .Unknown = void{} }) catch 0;
    }

    pub fn parseIfStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.IfKeyword);
        _ = self.parseExpected(kind.Kind.OpenParenToken);
        const expression = try @import("expression.zig").parseExpression(self);
        _ = self.parseExpected(kind.Kind.CloseParenToken);

        const thenStatement = try self.parseStatement();

        var elseStatement: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.ElseKeyword)) {
            elseStatement = try self.parseStatement();
        }

        const stmt = try self.ast.pushNode(.{ .IfStatement = .{
            .Flags = 0,
            .Expression = expression,
            .ThenStatement = thenStatement,
            .ElseStatement = elseStatement,
        } });
        self.setNodeStartPos(stmt, start_pos);
        return stmt;
    }

    pub fn parseReturnStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.ReturnKeyword);

        var expression: ?ast_gen.NodeIndex = null;
        if (self.token != kind.Kind.SemicolonToken and self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile and !self.scanner.hasPrecedingLineBreak()) {
            expression = try @import("expression.zig").parseExpression(self);
        }
        self.parseSemicolon();
        const ret_end = self.scanner.state.tokenStart;

        const stmt = try self.ast.pushNode(.{ .ReturnStatement = .{
            .Flags = 0,
            .Expression = expression,
        } });
        if (stmt != 0 and stmt < self.ast.positions.items.len) {
            self.ast.positions.items[stmt] = .{ .pos = @intCast(start_pos), .end = @intCast(ret_end) };
        }
        return stmt;
    }

    pub fn parseBlock(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.OpenBraceToken);
        const multiLine = self.scanner.hasPrecedingLineBreak();

        const statements = try self.parseList(.BlockStatements, parseStatement);
        _ = self.parseExpected(kind.Kind.CloseBraceToken);
        // After consuming `}`, scanner.state.tokenStart points to the
        // position immediately after `}` — capture it as the block's end.
        const end_pos = self.scanner.state.tokenStart;

        const block = try self.ast.pushNode(.{ .Block = .{
            .Flags = 0,
            .Statements = statements,
            .MultiLine = multiLine,
        } });
        if (block != 0 and block < self.ast.positions.items.len) {
            self.ast.positions.items[block] = .{ .pos = @intCast(start_pos), .end = @intCast(end_pos) };
        }
        return block;
    }

    pub fn parseWhileStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.WhileKeyword);
        _ = self.parseExpected(kind.Kind.OpenParenToken);
        const expression = try @import("expression.zig").parseExpression(self);
        _ = self.parseExpected(kind.Kind.CloseParenToken);

        const statement = try self.parseStatement();

        const stmt = try self.ast.pushNode(.{ .WhileStatement = .{
            .Flags = 0,
            .Statement = statement,
            .Expression = expression,
        } });
        self.setNodeStartPos(stmt, start_pos);
        return stmt;
    }

    pub fn parseForOrForInOrForOfStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.ForKeyword);
        var awaitToken: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.AwaitKeyword)) {
            awaitToken = try self.ast.pushNode(.{ .AwaitKeyword = void{} });
        }

        _ = self.parseExpected(kind.Kind.OpenParenToken);

        var initializer: ?ast_gen.NodeIndex = null;
        if (self.token != kind.Kind.SemicolonToken) {
            if (self.token == kind.Kind.LetKeyword or self.token == kind.Kind.ConstKeyword or self.token == kind.Kind.VarKeyword or self.isUsingDeclaration() or self.nextIsUsingDeclaration()) {
                const savedDisallowIn = self.disallowInContext;
                self.disallowInContext = true;
                initializer = try self.parseVariableDeclarationList();
                self.disallowInContext = savedDisallowIn;
            } else {
                const savedDisallowIn = self.disallowInContext;
                self.disallowInContext = true;
                initializer = try @import("expression.zig").parseExpression(self);
                self.disallowInContext = savedDisallowIn;
            }
        }

        if (self.parseOptional(kind.Kind.InKeyword)) {
            const expression = try @import("expression.zig").parseExpression(self);
            _ = self.parseExpected(kind.Kind.CloseParenToken);
            const statement = try self.parseStatement();

            const stmt = try self.ast.pushNode(.{
                .ForInStatement = .{
                    .Flags = 0,
                    .AwaitModifier = awaitToken,
                    .Initializer = initializer orelse 0, // Should not be null for ForIn, but parser handles errors
                    .Expression = expression,
                    .Statement = statement,
                },
            });
            self.setNodeStartPos(stmt, start_pos);
            return stmt;
        } else if (self.parseOptional(kind.Kind.OfKeyword)) {
            const expression = try @import("expression.zig").parseAssignmentExpressionOrHigher(self);
            _ = self.parseExpected(kind.Kind.CloseParenToken);
            const statement = try self.parseStatement();

            const stmt = try self.ast.pushNode(.{ .ForOfStatement = .{
                .Flags = 0,
                .AwaitModifier = awaitToken,
                .Initializer = initializer orelse 0,
                .Expression = expression,
                .Statement = statement,
            } });
            self.setNodeStartPos(stmt, start_pos);
            return stmt;
        }

        _ = self.parseExpected(kind.Kind.SemicolonToken);

        var condition: ?ast_gen.NodeIndex = null;
        if (self.token != kind.Kind.SemicolonToken and self.token != kind.Kind.CloseParenToken) {
            condition = try @import("expression.zig").parseExpression(self);
        }
        _ = self.parseExpected(kind.Kind.SemicolonToken);

        var incrementor: ?ast_gen.NodeIndex = null;
        if (self.token != kind.Kind.CloseParenToken) {
            incrementor = try @import("expression.zig").parseExpression(self);
        }
        _ = self.parseExpected(kind.Kind.CloseParenToken);

        const statement = try self.parseStatement();

        const stmt = try self.ast.pushNode(.{ .ForStatement = .{
            .Flags = 0,
            .Statement = statement,
            .Initializer = initializer,
            .Condition = condition,
            .Incrementor = incrementor,
        } });
        self.setNodeStartPos(stmt, start_pos);
        return stmt;
    }

    pub fn parseParameter(self: *Parser) anyerror!ast_gen.NodeIndex {
        const param_start = self.scanner.state.tokenStart;
        const jsdoc_info = self.jsdocScannerInfo();
        const modifiers = try self.parseModifiers();
        const modifierFlags = self.modifiersToFlags(modifiers);

        var dotDotDotToken: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.DotDotDotToken)) {
            dotDotDotToken = try self.ast.pushTokenNode(kind.Kind.DotDotDotToken);
        }

        // In JSDoc function types, parameters can be just types without
        // names: {function (string): void}. When inJSDocType is true and
        // the current token is the start of a type (not an identifier),
        // skip the parameter name and parse the type directly.
        if (self.inJSDocType and self.isStartOfType() and self.token != kind.Kind.ThisKeyword) {
            // JSDoc parameter: just a type, no name.
            const paramType: ?ast_gen.NodeIndex = try self.parseType();
            var questionToken2: ?ast_gen.NodeIndex = null;
            if (self.parseOptional(kind.Kind.QuestionToken)) {
                questionToken2 = try self.ast.pushTokenNode(kind.Kind.QuestionToken);
            }
            var initializer: ?ast_gen.NodeIndex = null;
            if (self.parseOptional(kind.Kind.EqualsToken)) {
                initializer = try @import("expression.zig").parseAssignmentExpressionOrHigher(self);
            }
            const result = try self.ast.pushNode(.{ .Parameter = .{
                .Symbol = 0,
                .Flags = 0,
                .modifiers = modifiers,
                .modifierFlags = modifierFlags,
                .DotDotDotToken = dotDotDotToken,
                .name = 0,
                .QuestionToken = questionToken2,
                .Type = paramType,
                .Initializer = initializer,
            } });
            self.setNodeStartPos(result, param_start);
            _ = try jsdoc.withJSDoc(self, result, jsdoc_info);
            return result;
        }

        // Handle `this` as a special parameter name (e.g., `this: T`)
        const paramName = if (self.token == kind.Kind.ThisKeyword) blk: {
            const this_start = self.scanner.state.tokenStart;
            const nameNode = try self.ast.pushNode(.{ .Identifier = .{ .Flags = 0, .Text = "this" } });
            self.nextToken();
            // Set both pos and end so getTouchingPropertyName can find this
            // node when the cursor is inside the `this` keyword.
            const this_end = self.scanner.state.tokenStart;
            if (nameNode != 0 and nameNode < self.ast.positions.items.len) {
                self.ast.positions.items[nameNode] = .{ .pos = @intCast(this_start), .end = @intCast(this_end) };
            }
            break :blk nameNode;
        } else try self.parseIdentifierOrPattern();

        var questionToken: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.QuestionToken)) {
            questionToken = try self.ast.pushTokenNode(kind.Kind.QuestionToken);
        }

        const paramType = try self.parseTypeAnnotation();

        var initializer: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.EqualsToken)) {
            initializer = try @import("expression.zig").parseAssignmentExpressionOrHigher(self);
        }

        const result = try self.ast.pushNode(.{ .Parameter = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .DotDotDotToken = dotDotDotToken,
            .name = paramName,
            .QuestionToken = questionToken,
            .Type = paramType,
            .Initializer = initializer,
        } });
        self.setNodeStartPos(result, param_start);
        _ = try jsdoc.withJSDoc(self, result, jsdoc_info);
        return result;
    }

    pub fn parseParameterWrapper(self: *Parser) ast_gen.NodeIndex {
        return self.parseParameter() catch 0;
    }

    pub fn parseParameters(self: *Parser) anyerror!ast_gen.NodeListIndex {
        _ = self.parseExpected(kind.Kind.OpenParenToken);
        const parametersList = self.parseDelimitedList(.Parameters, parseParameterWrapper);
        _ = self.parseExpected(kind.Kind.CloseParenToken);
        return parametersList;
    }

    pub fn parseFunctionDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        const function_start = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.FunctionKeyword);
        var asteriskToken: ?ast_gen.NodeIndex = null;
        if (self.token == kind.Kind.AsteriskToken) {
            asteriskToken = try self.ast.pushNode(.{ .AsteriskToken = void{} });
            _ = self.nextToken();
        }

        var name: ?ast_gen.NodeIndex = null;
        if (self.isIdentifier()) {
            name = try self.parseIdentifier();
        }

        const typeParameters = try self.parseTypeParameters();

        const parameters = try self.parseParameters();

        const returnType = try self.parseReturnTypeAnnotation();

        var body: ?ast_gen.NodeIndex = null;
        if (self.token == kind.Kind.OpenBraceToken) {
            body = try self.parseBlock();
        } else {
            self.parseSemicolon();
        }
        const fn_end = self.scanner.state.tokenStart;

        const decl = try self.ast.pushNode(.{ .FunctionDeclaration = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .TypeParameters = typeParameters,
            .Parameters = parameters,
            .Type = returnType,
            .FullSignature = null,
            .AsteriskToken = asteriskToken,
            .Body = body,
            .name = name,
        } });
        if (decl != 0 and decl < self.ast.positions.items.len) {
            self.ast.positions.items[decl] = .{ .pos = @intCast(function_start), .end = @intCast(fn_end) };
        }
        return decl;
    }

    pub fn parseFunctionExpression(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        var modifiers: ?ast_gen.NodeListIndex = null;
        if (self.token == kind.Kind.AsyncKeyword) {
            modifiers = try self.parseModifiers();
        }
        const modifierFlags = self.modifiersToFlags(modifiers);
        _ = self.parseExpected(kind.Kind.FunctionKeyword);
        var asteriskToken: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.AsteriskToken)) {
            asteriskToken = try self.ast.pushNode(.{ .AsteriskToken = void{} });
        }
        var name: ?ast_gen.NodeIndex = null;
        if (self.isIdentifier()) {
            name = try self.parseIdentifier();
        }
        const typeParameters = try self.parseTypeParameters();
        const parameters = try self.parseParameters();
        const returnType = try self.parseReturnTypeAnnotation();

        var body: ?ast_gen.NodeIndex = null;
        if (self.token == kind.Kind.OpenBraceToken) {
            body = try self.parseBlock();
        } else {
            _ = self.parseExpected(kind.Kind.OpenBraceToken);
        }
        // Capture end position from the body's end (or current scanner
        // position if body is missing).
        const body_end = if (body) |b| self.ast.getNodeEnd(b) else self.scanner.state.tokenStart;
        const end_pos = if (body_end != 0) body_end else self.scanner.state.tokenStart;

        const expr = try self.ast.pushNode(.{ .FunctionExpression = .{
            .Flags = 0,
            .Symbol = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .TypeParameters = typeParameters,
            .Parameters = parameters,
            .Type = returnType,
            .FullSignature = null,
            .AsteriskToken = asteriskToken,
            .Body = body,
            .name = name,
        } });
        if (expr != 0 and expr < self.ast.positions.items.len) {
            self.ast.positions.items[expr] = .{ .pos = @intCast(start_pos), .end = @intCast(end_pos) };
        }
        return expr;
    }

    pub fn parseDecorator(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.AtToken);
        const expr = try @import("expression.zig").parseLeftHandSideExpressionOrHigher(self);
        const decorator = try self.ast.pushNode(.{ .Decorator = .{
            .Flags = 0,
            .Expression = expr,
        } });
        self.setNodeStartPos(decorator, start_pos);
        return decorator;
    }

    fn modifiersToFlags(self: *Parser, modifiers: ?ast_gen.NodeListIndex) u32 {
        var flags: u32 = 0;
        if (modifiers) |list| {
            for (self.ast.getNodeList(list)) |mod_index| {
                const mod_node = self.ast.getNode(mod_index);
                switch (mod_node) {
                    .ExportKeyword => flags |= @import("../ast/ast_utils.zig").ModifierFlags.Export,
                    .DeclareKeyword => flags |= @import("../ast/ast_utils.zig").ModifierFlags.Ambient,
                    .PublicKeyword => flags |= @import("../ast/ast_utils.zig").ModifierFlags.Public,
                    .PrivateKeyword => flags |= @import("../ast/ast_utils.zig").ModifierFlags.Private,
                    .ProtectedKeyword => flags |= @import("../ast/ast_utils.zig").ModifierFlags.Protected,
                    .ReadonlyKeyword => flags |= @import("../ast/ast_utils.zig").ModifierFlags.Readonly,
                    .OverrideKeyword => flags |= @import("../ast/ast_utils.zig").ModifierFlags.Override,
                    .DefaultKeyword => flags |= @import("../ast/ast_utils.zig").ModifierFlags.Default,
                    .InKeyword => flags |= @import("../ast/ast_utils.zig").ModifierFlags.In,
                    .OutKeyword => flags |= @import("../ast/ast_utils.zig").ModifierFlags.Out,
                    .StaticKeyword => flags |= @import("../ast/ast_utils.zig").ModifierFlags.Static,
                    .AccessorKeyword => flags |= @import("../ast/ast_utils.zig").ModifierFlags.Accessor,
                    else => {},
                }
            }
        }
        return flags;
    }

    pub fn parseModifiers(self: *Parser) anyerror!?ast_gen.NodeListIndex {
        return self.parseModifiersEx(false);
    }

    pub fn parseModifiersEx(self: *Parser, stopOnStartOfClassStaticBlock: bool) anyerror!?ast_gen.NodeListIndex {
        var list = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer list.deinit(self.allocator);

        while (true) {
            if (self.token == kind.Kind.AtToken) {
                const dec = try self.parseDecorator();
                try list.append(self.allocator, dec);
            } else if (self.isModifierKind(self.token)) {
                if (stopOnStartOfClassStaticBlock and self.token == kind.Kind.StaticKeyword and self.peekNextToken() == kind.Kind.OpenBraceToken) {
                    break;
                }
                // consume modifier
                const modNode = try self.ast.pushNode(switch (self.token) {
                    kind.Kind.ExportKeyword => .{ .ExportKeyword = void{} },
                    kind.Kind.DeclareKeyword => .{ .DeclareKeyword = void{} },
                    kind.Kind.PublicKeyword => .{ .PublicKeyword = void{} },
                    kind.Kind.PrivateKeyword => .{ .PrivateKeyword = void{} },
                    kind.Kind.ProtectedKeyword => .{ .ProtectedKeyword = void{} },
                    kind.Kind.ReadonlyKeyword => .{ .ReadonlyKeyword = void{} },
                    kind.Kind.OverrideKeyword => .{ .OverrideKeyword = void{} },
                    kind.Kind.DefaultKeyword => .{ .DefaultKeyword = void{} },
                    kind.Kind.InKeyword => .{ .InKeyword = void{} },
                    kind.Kind.OutKeyword => .{ .OutKeyword = void{} },
                    kind.Kind.StaticKeyword => .{ .StaticKeyword = void{} },
                    kind.Kind.AccessorKeyword => .{ .AccessorKeyword = void{} },
                    kind.Kind.AbstractKeyword => .{ .AbstractKeyword = void{} },
                    kind.Kind.AsyncKeyword => .{ .AsyncKeyword = void{} },
                    kind.Kind.ConstKeyword => .{ .ConstKeyword = void{} },
                    else => .{ .Unknown = void{} }, // Fallback for other modifiers if any
                });
                try list.append(self.allocator, modNode);
                self.nextToken();
            } else {
                break;
            }
        }

        if (list.items.len > 0) {
            return try self.ast.pushNodeList(list.items);
        }
        return null;
    }

    fn peekNextToken(self: *Parser) kind.Kind {
        var tempScanner = self.scanner;
        return tempScanner.scan();
    }

    pub fn isBindingIdentifier(self: *Parser) bool {
        return self.token == kind.Kind.Identifier or @intFromEnum(self.token) > @intFromEnum(kind.Kind.WithKeyword);
    }

    fn isLetDeclaration(self: *Parser) bool {
        return self.lookAhead(struct {
            pub fn run(p: *Parser) bool {
                _ = p.nextToken();
                return p.isBindingIdentifier() or p.token == kind.Kind.OpenBraceToken or p.token == kind.Kind.OpenBracketToken;
            }
        }.run);
    }

    fn isUsingDeclaration(self: *Parser) bool {
        var tempScanner = self.scanner;
        const next = tempScanner.scan();
        if (tempScanner.hasPrecedingLineBreak()) {
            return false;
        }
        return next == kind.Kind.Identifier or next == kind.Kind.OpenBraceToken or next == kind.Kind.OpenBracketToken;
    }

    fn nextIsUsingDeclaration(self: *Parser) bool {
        var tempScanner = self.scanner;
        const next = tempScanner.scan();
        if (next != kind.Kind.UsingKeyword or tempScanner.hasPrecedingLineBreak()) {
            return false;
        }
        const nextNext = tempScanner.scan();
        if (tempScanner.hasPrecedingLineBreak()) {
            return false;
        }
        return nextNext == kind.Kind.Identifier or nextNext == kind.Kind.OpenBraceToken or nextNext == kind.Kind.OpenBracketToken;
    }

    pub fn isModifierKind(self: *Parser, token: kind.Kind) bool {
        switch (token) {
            kind.Kind.PublicKeyword, kind.Kind.PrivateKeyword, kind.Kind.ProtectedKeyword, kind.Kind.ReadonlyKeyword, kind.Kind.StaticKeyword, kind.Kind.AbstractKeyword, kind.Kind.AsyncKeyword, kind.Kind.DeclareKeyword, kind.Kind.OverrideKeyword, kind.Kind.AccessorKeyword => return true,

            kind.Kind.InKeyword, kind.Kind.OutKeyword => {
                const next = self.peekNextToken();
                return switch (next) {
                    kind.Kind.ColonToken, kind.Kind.CommaToken, kind.Kind.EqualsToken, kind.Kind.SemicolonToken, kind.Kind.CloseParenToken, kind.Kind.CloseBraceToken, kind.Kind.EndOfFile => false,
                    else => true,
                };
            },

            kind.Kind.ConstKeyword => {
                const next = self.peekNextToken();
                return next == kind.Kind.EnumKeyword;
            },
            kind.Kind.ExportKeyword => {
                var tempScanner = self.scanner;
                const next = tempScanner.scan();
                if (next == kind.Kind.TypeKeyword) {
                    const next2 = tempScanner.scan();
                    return next2 != kind.Kind.AsteriskToken and next2 != kind.Kind.AsKeyword and next2 != kind.Kind.OpenBraceToken;
                }
                if (next == kind.Kind.DefaultKeyword) {
                    const next2 = tempScanner.scan();
                    return switch (next2) {
                        kind.Kind.ClassKeyword, kind.Kind.FunctionKeyword, kind.Kind.InterfaceKeyword, kind.Kind.AtToken => true,
                        kind.Kind.AbstractKeyword => {
                            const next3 = tempScanner.scan();
                            return next3 == kind.Kind.ClassKeyword and !tempScanner.hasPrecedingLineBreak();
                        },
                        kind.Kind.AsyncKeyword => {
                            const next3 = tempScanner.scan();
                            return next3 == kind.Kind.FunctionKeyword and !tempScanner.hasPrecedingLineBreak();
                        },
                        else => false,
                    };
                }
                return switch (next) {
                    kind.Kind.ClassKeyword, kind.Kind.FunctionKeyword, kind.Kind.InterfaceKeyword, kind.Kind.EnumKeyword, kind.Kind.NamespaceKeyword, kind.Kind.ModuleKeyword, kind.Kind.DeclareKeyword, kind.Kind.ConstKeyword, kind.Kind.LetKeyword, kind.Kind.VarKeyword, kind.Kind.AbstractKeyword, kind.Kind.AsyncKeyword, kind.Kind.AtToken, kind.Kind.ImportKeyword => true,
                    else => false,
                };
            },
            kind.Kind.DefaultKeyword => {
                const next = self.peekNextToken();
                return switch (next) {
                    kind.Kind.ClassKeyword, kind.Kind.FunctionKeyword, kind.Kind.InterfaceKeyword, kind.Kind.AsyncKeyword, kind.Kind.AbstractKeyword, kind.Kind.AtToken => true,
                    else => false,
                };
            },
            else => return false,
        }
    }

    fn lookAheadAccessor(self: *Parser) bool {
        const state = self.scanner.state;
        const token = self.token;
        self.nextToken();
        const isAccessor = self.token != kind.Kind.OpenParenToken and self.token != kind.Kind.LessThanToken and self.token != kind.Kind.ColonToken and self.token != kind.Kind.EqualsToken and self.token != kind.Kind.SemicolonToken;
        self.scanner.state = state;
        self.token = token;
        return isAccessor;
    }

    fn parseAccessorDeclaration(self: *Parser, modifiers: ?ast_gen.NodeIndex, modifierFlags: u32, isGetAccessor: bool) anyerror!ast_gen.NodeIndex {
        const memberName = try self.parsePropertyName();
        const typeParameters = try self.parseTypeParameters();
        const parameters = try self.parseParameters();
        const returnType = try self.parseReturnTypeAnnotation();
        var body: ?ast_gen.NodeIndex = null;
        if (self.token == kind.Kind.OpenBraceToken) {
            body = try self.parseBlock();
        } else {
            self.parseSemicolon();
        }
        if (isGetAccessor) {
            return self.ast.pushNode(.{ .GetAccessor = .{ .Symbol = 0, .Flags = 0, .modifiers = modifiers, .modifierFlags = modifierFlags, .name = memberName, .Parameters = parameters, .Type = returnType, .Body = body, .AsteriskToken = null, .PostfixToken = null, .TypeParameters = typeParameters, .FullSignature = null } });
        } else {
            return self.ast.pushNode(.{ .SetAccessor = .{ .Symbol = 0, .Flags = 0, .modifiers = modifiers, .modifierFlags = modifierFlags, .name = memberName, .Parameters = parameters, .Type = returnType, .Body = body, .AsteriskToken = null, .PostfixToken = null, .TypeParameters = typeParameters, .FullSignature = null } });
        }
    }

    pub fn parseClassElement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const jsdoc_info = self.jsdocScannerInfo();
        const result = try self.parseClassElementWorker();
        _ = try jsdoc.withJSDoc(self, result, jsdoc_info);
        return result;
    }

    fn parseClassElementWorker(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.token == kind.Kind.SemicolonToken) {
            const start_pos = self.scanner.state.tokenStart;
            self.nextToken();
            const elem = try self.ast.pushNode(.{ .SemicolonClassElement = .{
                .Symbol = 0,
                .Flags = 0,
            } });
            self.setNodeStartPos(elem, start_pos);
            return elem;
        }

        const element_start = self.scanner.state.tokenStart;
        const modifiers = try self.parseModifiersEx(true);
        const modifierFlags = self.modifiersToFlags(modifiers);

        if (self.token == kind.Kind.StaticKeyword and self.peekNextToken() == kind.Kind.OpenBraceToken) {
            self.nextToken(); // consume static
            const body = try self.parseBlock();
            const decl = try self.ast.pushNode(.{ .ClassStaticBlockDeclaration = .{
                .Flags = 0,
                .Symbol = 0,
                .modifiers = modifiers,
                .modifierFlags = modifierFlags,
                .Body = body,
            } });
            self.setNodeStartPos(decl, element_start);
            return decl;
        }

        if (self.token == kind.Kind.GetKeyword and self.lookAheadAccessor()) {
            self.nextToken();
            const decl = try self.parseAccessorDeclaration(modifiers, modifierFlags, true);
            self.setNodeStartPos(decl, element_start);
            return decl;
        }
        if (self.token == kind.Kind.SetKeyword and self.lookAheadAccessor()) {
            self.nextToken();
            const decl = try self.parseAccessorDeclaration(modifiers, modifierFlags, false);
            self.setNodeStartPos(decl, element_start);
            return decl;
        }

        if (self.token == kind.Kind.ConstructorKeyword or (self.token == kind.Kind.StringLiteral and std.mem.eql(u8, self.scanner.state.tokenValue, "constructor")) or (self.token == kind.Kind.Identifier and std.mem.eql(u8, self.scanner.state.tokenValue, "constructor"))) {
            const isConstructor = if (self.token != kind.Kind.ConstructorKeyword) self.lookAhead(struct {
                fn run(p1: *Parser) bool {
                    p1.nextToken();
                    return p1.token == kind.Kind.OpenParenToken;
                }
            }.run) else true;

            if (isConstructor) {
                self.nextToken(); // consume constructor keyword or identifier
                const typeParameters = try self.parseTypeParameters();
                const parameters = try self.parseParameters();
                const returnType = try self.parseReturnTypeAnnotation();

                var body: ?ast_gen.NodeIndex = null;
                if (self.token == kind.Kind.OpenBraceToken) {
                    body = try self.parseBlock();
                } else {
                    self.parseSemicolon();
                }

                const decl = try self.ast.pushNode(.{ .Constructor = .{
                    .Flags = 0,
                    .Symbol = 0,
                    .modifiers = modifiers,
                    .modifierFlags = modifierFlags,
                    .TypeParameters = typeParameters,
                    .Parameters = parameters,
                    .Type = returnType,
                    .FullSignature = null,
                    .AsteriskToken = null,
                    .Body = body,
                } });
                self.setNodeStartPos(decl, element_start);
                return decl;
            }
        }

        if (self.isIndexSignature()) {
            const decl = try self.parseIndexSignatureDeclaration(modifiers, modifierFlags);
            self.setNodeStartPos(decl, element_start);
            return decl;
        }

        // Simple property or method declaration for now.
        const memberName = try self.parsePropertyName();

        var postfixToken: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.QuestionToken)) {
            postfixToken = try self.ast.pushTokenNode(kind.Kind.QuestionToken);
        }

        // Method vs Property
        if (self.token == kind.Kind.OpenParenToken or self.token == kind.Kind.LessThanToken) {
            // Method
            const typeParameters = try self.parseTypeParameters();
            const parameters = try self.parseParameters();
            const returnType = try self.parseReturnTypeAnnotation();

            var body: ?ast_gen.NodeIndex = null;
            if (self.token == kind.Kind.OpenBraceToken) {
                body = try self.parseBlock();
            } else {
                self.parseSemicolon();
            }

            const decl = try self.ast.pushNode(.{ .MethodDeclaration = .{
                .Symbol = 0,
                .Flags = 0,
                .modifiers = modifiers,
                .modifierFlags = modifierFlags,
                .AsteriskToken = null,
                .name = memberName,
                .PostfixToken = postfixToken,
                .TypeParameters = typeParameters,
                .Parameters = parameters,
                .Type = returnType,
                .FullSignature = null,
                .Body = body,
            } });
            self.setNodeStartPos(decl, element_start);
            return decl;
        } else {
            // Property
            if (postfixToken == null and !self.scanner.hasPrecedingLineBreak()) {
                if (self.parseOptional(kind.Kind.ExclamationToken)) {
                    postfixToken = try self.ast.pushTokenNode(kind.Kind.ExclamationToken);
                }
            }
            const typeNode = try self.parseTypeAnnotation();

            var initializer: ?ast_gen.NodeIndex = null;
            if (self.parseOptional(kind.Kind.EqualsToken)) {
                initializer = try @import("expression.zig").parseAssignmentExpressionOrHigher(self);
            }
            self.parseSemicolon();

            const decl = try self.ast.pushNode(.{ .PropertyDeclaration = .{
                .Symbol = 0,
                .Flags = 0,
                .modifiers = modifiers,
                .modifierFlags = modifierFlags,
                .name = memberName,
                .PostfixToken = postfixToken,
                .Type = typeNode,
                .Initializer = initializer,
            } });
            self.setNodeStartPos(decl, element_start);
            return decl;
        }
    }

    pub fn parseClassExpression(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.ClassKeyword);
        var name: ?ast_gen.NodeIndex = null;
        if (self.isIdentifier() and self.token != kind.Kind.ExtendsKeyword and self.token != kind.Kind.ImplementsKeyword) {
            name = try self.parseIdentifier();
        }

        const typeParameters = try self.parseTypeParameters();
        const heritageClauses = try self.parseHeritageClauses();

        _ = self.parseExpected(kind.Kind.OpenBraceToken);
        var members_arr = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer members_arr.deinit(self.allocator);

        while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
            const startPos = self.scanner.state.pos;

            const memberNode = try self.parseClassElement();
            try members_arr.append(self.allocator, memberNode);

            if (self.scanner.state.pos == startPos) {
                self.nextToken(); // force advance
            }
        }

        _ = self.parseExpected(kind.Kind.CloseBraceToken);
        // After consuming `}`, capture end position.
        const class_end = self.scanner.state.tokenStart;
        const members = try self.ast.pushNodeList(members_arr.items);

        const expr = try self.ast.pushNode(.{ .ClassExpression = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .name = name orelse 0,
            .TypeParameters = typeParameters,
            .HeritageClauses = heritageClauses orelse 0,
            .Members = members,
        } });
        if (expr != 0 and expr < self.ast.positions.items.len) {
            self.ast.positions.items[expr] = .{ .pos = @intCast(start_pos), .end = @intCast(class_end) };
        }
        return expr;
    }

    pub fn parseExpressionWithTypeArguments(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        const expression = try @import("expression.zig").parseLeftHandSideExpressionOrHigher(self);
        const expressionNode = self.ast.getNode(expression);
        if (std.meta.activeTag(expressionNode) == .ExpressionWithTypeArguments) {
            return expression;
        }

        var typeArguments: ?ast_gen.NodeListIndex = null;
        if (self.token == kind.Kind.LessThanToken) {
            typeArguments = try self.parseTypeArguments();
        }

        const node = try self.ast.pushNode(.{ .ExpressionWithTypeArguments = .{ .Flags = 0, .Expression = expression, .TypeArguments = typeArguments } });
        self.setNodeStartPos(node, start_pos);
        return node;
    }

    pub fn isStartOfLeftHandSideExpression(self: *Parser) bool {
        return switch (self.token) {
            kind.Kind.ThisKeyword, kind.Kind.SuperKeyword, kind.Kind.NullKeyword, kind.Kind.TrueKeyword, kind.Kind.FalseKeyword, kind.Kind.NumericLiteral, kind.Kind.BigIntLiteral, kind.Kind.StringLiteral, kind.Kind.NoSubstitutionTemplateLiteral, kind.Kind.TemplateHead, kind.Kind.OpenParenToken, kind.Kind.OpenBracketToken, kind.Kind.OpenBraceToken, kind.Kind.FunctionKeyword, kind.Kind.ClassKeyword, kind.Kind.NewKeyword, kind.Kind.SlashToken, kind.Kind.SlashEqualsToken, kind.Kind.RegularExpressionLiteral, kind.Kind.ImportKeyword, kind.Kind.PrivateIdentifier => true,
            else => self.isIdentifier(),
        };
    }

    pub fn isValidHeritageClauseObjectLiteral(self: *Parser) bool {
        const snapshot = self.mark();
        defer self.rewind(snapshot);

        self.nextToken();
        if (self.token == kind.Kind.CloseBraceToken) {
            self.nextToken();
            const next = self.token;
            return next == kind.Kind.CommaToken or next == kind.Kind.OpenBraceToken or next == kind.Kind.ExtendsKeyword or next == kind.Kind.ImplementsKeyword;
        }
        return true;
    }

    pub fn parseHeritageClause(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        const tokenKind = self.token;
        self.nextToken();
        var types = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer types.deinit(self.allocator);
        while (true) {
            if (self.token == kind.Kind.OpenBraceToken) {
                if (!self.isValidHeritageClauseObjectLiteral()) {
                    break;
                }
            } else if (self.token == kind.Kind.ExtendsKeyword or self.token == kind.Kind.ImplementsKeyword) {
                break;
            }

            if (!self.isStartOfLeftHandSideExpression()) {
                break;
            }

            const t = try self.parseExpressionWithTypeArguments();
            try types.append(self.allocator, t);
            if (!self.parseOptional(kind.Kind.CommaToken)) {
                break;
            }
        }
        const typesList = try self.ast.pushNodeList(types.items);
        const clause = try self.ast.pushNode(.{ .HeritageClause = .{ .Flags = 0, .Token = @intFromEnum(tokenKind), .Types = typesList } });
        self.setNodeStartPos(clause, start_pos);
        return clause;
    }

    pub fn parseHeritageClauses(self: *Parser) anyerror!?ast_gen.NodeListIndex {
        if (self.token == kind.Kind.ExtendsKeyword or self.token == kind.Kind.ImplementsKeyword) {
            var clauses = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
            defer clauses.deinit(self.allocator);
            while (self.token == kind.Kind.ExtendsKeyword or self.token == kind.Kind.ImplementsKeyword) {
                const clause = try self.parseHeritageClause();
                try clauses.append(self.allocator, clause);
            }
            return try self.ast.pushNodeList(clauses.items);
        }
        return null;
    }

    pub fn parseClassDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.ClassKeyword);
        var name: ?ast_gen.NodeIndex = null;
        if (self.isIdentifier() and self.token != kind.Kind.ExtendsKeyword and self.token != kind.Kind.ImplementsKeyword) {
            name = try self.parseIdentifier();
        }

        const typeParameters = try self.parseTypeParameters();
        const heritageClauses = try self.parseHeritageClauses();

        _ = self.parseExpected(kind.Kind.OpenBraceToken);
        var members_arr = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer members_arr.deinit(self.allocator);

        while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
            const startPos = self.scanner.state.pos;

            const memberNode = try self.parseClassElement();
            try members_arr.append(self.allocator, memberNode);

            if (self.scanner.state.pos == startPos) {
                self.nextToken(); // force advance
            }
        }

        _ = self.parseExpected(kind.Kind.CloseBraceToken);
        // After consuming `}`, capture end position.
        const class_end = self.scanner.state.tokenStart;
        const members = try self.ast.pushNodeList(members_arr.items);

        const decl = try self.ast.pushNode(.{ .ClassDeclaration = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .name = name,
            .TypeParameters = typeParameters,
            .HeritageClauses = heritageClauses,
            .Members = members,
        } });
        if (decl != 0 and decl < self.ast.positions.items.len) {
            self.ast.positions.items[decl] = .{ .pos = @intCast(start_pos), .end = @intCast(class_end) };
        }
        return decl;
    }

    pub fn parseTypeAnnotation(self: *Parser) anyerror!?ast_gen.NodeIndex {
        if (self.parseOptional(kind.Kind.ColonToken)) {
            return try self.parseType();
        }
        return null;
    }

    /// Parse type annotation for return type positions (function/arrow return types).
    /// These can be type predicates: `paramName is Type` or `asserts paramName is Type`.
    pub fn parseReturnTypeAnnotation(self: *Parser) anyerror!?ast_gen.NodeIndex {
        if (self.parseOptional(kind.Kind.ColonToken)) {
            return try self.parseTypeOrTypePredicate();
        }
        return null;
    }

    /// Parse a type or type predicate (e.g., `x is number`).
    /// Type predicates can only appear in return type positions.
    pub fn parseTypeOrTypePredicate(self: *Parser) anyerror!ast_gen.NodeIndex {
        // Check for `this is Type` type predicate.
        if (self.token == kind.Kind.ThisKeyword) {
            const savedState = self.mark();
            const thisNode = try self.ast.pushNode(.{ .ThisType = .{ .Flags = 0 } });
            self.nextToken(); // consume 'this'
            if (self.token == kind.Kind.IsKeyword and !self.scanner.hasPrecedingLineBreak()) {
                self.nextToken(); // consume 'is'
                const typeNode = try self.parseType();
                return self.ast.pushNode(.{ .TypePredicate = .{
                    .Flags = 0,
                    .AssertsModifier = null,
                    .ParameterName = thisNode,
                    .Type = typeNode,
                } });
            }
            self.rewind(savedState);
        }
        if (self.isIdentifier()) {
            const savedState = self.mark();
            const id = try self.parseIdentifier();
            // Check for `identifier is type` (type predicate)
            if (self.token == kind.Kind.IsKeyword and !self.scanner.hasPrecedingLineBreak()) {
                self.nextToken(); // consume 'is'
                const typeNode = try self.parseType();
                return self.ast.pushNode(.{ .TypePredicate = .{
                    .Flags = 0,
                    .AssertsModifier = null,
                    .ParameterName = id,
                    .Type = typeNode,
                } });
            }
            self.rewind(savedState);
        }
        return try self.parseType();
    }

    pub fn nextTokenIsIdentifierOrKeywordOnSameLine(self: *Parser) bool {
        const saved = self.mark();
        defer self.rewind(saved);
        self.nextToken();
        return !self.scanner.hasPrecedingLineBreak() and (self.isIdentifier() or kind.isKeyword(self.token));
    }

    pub fn parseAssertsTypePredicate(self: *Parser) anyerror!ast_gen.NodeIndex {
        const assertsModifier = try self.ast.pushNode(.{ .AssertsKeyword = void{} });
        self.nextToken(); // consume 'asserts'

        var parameterName: ast_gen.NodeIndex = 0;
        if (self.token == kind.Kind.ThisKeyword) {
            parameterName = try self.ast.pushNode(.{ .ThisType = .{ .Flags = 0 } });
            self.nextToken();
        } else {
            parameterName = try self.parseIdentifier();
        }

        var typeNode: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.IsKeyword)) {
            typeNode = try self.parseType();
        }

        return self.ast.pushNode(.{ .TypePredicate = .{
            .Flags = 0,
            .AssertsModifier = assertsModifier,
            .ParameterName = parameterName,
            .Type = typeNode,
        } });
    }

    pub fn parseTypeArguments(self: *Parser) anyerror!?ast_gen.NodeListIndex {
        if (self.token != kind.Kind.LessThanToken) return null;
        const saveMark = self.mark();
        errdefer self.rewind(saveMark);
        self.nextToken(); // consume `<`

        var typeArgs = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer typeArgs.deinit(self.allocator);

        while (self.token != kind.Kind.GreaterThanToken and self.token != kind.Kind.EndOfFile) {
            const t = try self.parseType();
            try typeArgs.append(self.allocator, t);

            if (self.token == kind.Kind.CommaToken) {
                self.nextToken();
                continue;
            }
            // Not `>` or `,` — e.g. `i < 10;` — abort without consuming further tokens.
            break;
        }

        if (self.token != kind.Kind.GreaterThanToken) {
            self.rewind(saveMark);
            return null;
        }
        self.nextToken(); // consume `>`

        return try self.ast.pushNodeList(typeArgs.items);
    }

    pub fn parseEntityName(self: *Parser) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        const end_pos = self.scanner.getTokenEnd();
        const text = self.scanner.state.tokenValue;
        var entity = try self.ast.pushNode(.{ .Identifier = .{
            .Flags = 0,
            .Text = text,
        } });
        self.ast.positions.items[entity] = .{ .pos = @intCast(start_pos), .end = @intCast(end_pos) };
        self.nextToken();

        while (self.token == kind.Kind.DotToken) {
            self.nextToken(); // consume dot
            const right_start = self.scanner.state.tokenStart;
            const right_end = self.scanner.getTokenEnd();
            const rightText = self.scanner.state.tokenValue;
            const right = try self.ast.pushNode(.{ .Identifier = .{
                .Flags = 0,
                .Text = rightText,
            } });
            self.ast.positions.items[right] = .{ .pos = @intCast(right_start), .end = @intCast(right_end) };
            self.nextToken(); // consume identifier

            entity = try self.ast.pushNode(.{ .QualifiedName = .{
                .Flags = 0,
                .Left = entity,
                .Right = right,
            } });
            self.ast.positions.items[entity] = .{ .pos = @intCast(start_pos), .end = @intCast(right_end) };
        }
        return entity;
    }

    pub fn pushKeywordNode(self: *Parser, nodeData: ast_gen.NodeData) !ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        const end_pos = self.scanner.getTokenEnd();
        const node = try self.ast.pushNode(nodeData);
        self.setNodeStartPos(node, start_pos);
        self.ast.positions.items[node].end = @intCast(end_pos);
        self.nextToken();
        return node;
    }

    pub fn parsePrimaryType(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.token == kind.Kind.NumberKeyword) {
            return try self.pushKeywordNode(.{ .NumberKeyword = void{} });
        } else if (self.token == kind.Kind.StringKeyword) {
            return try self.pushKeywordNode(.{ .StringKeyword = void{} });
        } else if (self.token == kind.Kind.BooleanKeyword) {
            return try self.pushKeywordNode(.{ .BooleanKeyword = void{} });
        } else if (self.token == kind.Kind.AnyKeyword) {
            return try self.pushKeywordNode(.{ .AnyKeyword = void{} });
        } else if (self.token == kind.Kind.UnknownKeyword) {
            return try self.pushKeywordNode(.{ .UnknownKeyword = void{} });
        } else if (self.token == kind.Kind.NeverKeyword) {
            return try self.pushKeywordNode(.{ .NeverKeyword = void{} });
        } else if (self.token == kind.Kind.VoidKeyword) {
            return try self.pushKeywordNode(.{ .VoidKeyword = void{} });
        } else if (self.token == kind.Kind.UndefinedKeyword) {
            return try self.pushKeywordNode(.{ .UndefinedKeyword = void{} });
        } else if (self.token == kind.Kind.SymbolKeyword) {
            return try self.pushKeywordNode(.{ .SymbolKeyword = void{} });
        } else if (self.token == kind.Kind.ThisKeyword) {
            const this_start = self.scanner.state.tokenStart;
            self.nextToken();
            const this_end = self.scanner.state.tokenStart;
            const node = try self.ast.pushNode(.{ .ThisType = .{ .Flags = 0 } });
            if (node != 0 and node < self.ast.positions.items.len) {
                self.ast.positions.items[node] = .{ .pos = @intCast(this_start), .end = @intCast(this_end) };
            }
            return node;
        } else if (self.token == kind.Kind.ObjectKeyword) {
            return try self.pushKeywordNode(.{ .ObjectKeyword = void{} });
        } else if (self.token == kind.Kind.BigIntKeyword) {
            return try self.pushKeywordNode(.{ .BigIntKeyword = void{} });
        } else if (self.token == kind.Kind.IntrinsicKeyword) {
            return try self.pushKeywordNode(.{ .IntrinsicKeyword = void{} });
        } else if (self.token == kind.Kind.NoSubstitutionTemplateLiteral or self.token == kind.Kind.StringLiteral or self.token == kind.Kind.NumericLiteral or self.token == kind.Kind.BigIntLiteral) {
            const tokenKind = self.token;
            const text = self.scanner.state.tokenValue;
            const tokenFlags = self.scanner.getTokenFlags();
            self.nextToken();
            var literal: ast_gen.NodeIndex = 0;
            if (tokenKind == kind.Kind.NoSubstitutionTemplateLiteral) {
                literal = try self.ast.pushNode(.{ .NoSubstitutionTemplateLiteral = .{ .Symbol = 0, .Flags = 0, .Text = text, .TokenFlags = tokenFlags, .RawText = "", .TemplateFlags = @as(u16, @intCast(tokenFlags & 0xFFFF)) } });
            } else if (tokenKind == kind.Kind.StringLiteral) {
                literal = try self.ast.pushNode(.{ .StringLiteral = .{ .Flags = 0, .Text = text, .TokenFlags = tokenFlags } });
            } else if (tokenKind == kind.Kind.NumericLiteral) {
                literal = try self.ast.pushNode(.{ .NumericLiteral = .{ .Flags = 0, .Text = text, .TokenFlags = tokenFlags } });
            } else if (tokenKind == kind.Kind.BigIntLiteral) {
                literal = try self.ast.pushNode(.{ .BigIntLiteral = .{ .Flags = 0, .Text = text, .TokenFlags = tokenFlags } });
            }
            return try self.ast.pushNode(.{ .LiteralType = .{ .Flags = 0, .Literal = literal } });
        } else if (self.token == kind.Kind.PlusToken or self.token == kind.Kind.MinusToken) {
            const operator = self.token;
            self.nextToken();
            const tokenKind = self.token;
            const text = self.scanner.state.tokenValue;
            const tokenFlags = self.scanner.getTokenFlags();
            self.nextToken();
            var operand: ast_gen.NodeIndex = 0;
            if (tokenKind == kind.Kind.NumericLiteral) {
                operand = try self.ast.pushNode(.{ .NumericLiteral = .{ .Flags = 0, .Text = text, .TokenFlags = tokenFlags } });
            } else if (tokenKind == kind.Kind.BigIntLiteral) {
                operand = try self.ast.pushNode(.{ .BigIntLiteral = .{ .Flags = 0, .Text = text, .TokenFlags = tokenFlags } });
            } else {
                operand = try self.ast.pushNode(.{ .Unknown = void{} });
            }
            const prefix = try self.ast.pushNode(.{ .PrefixUnaryExpression = .{ .Flags = 0, .Operator = @intFromEnum(operator), .Operand = operand } });
            return try self.ast.pushNode(.{ .LiteralType = .{ .Flags = 0, .Literal = prefix } });
        } else if (self.token == kind.Kind.TrueKeyword or self.token == kind.Kind.FalseKeyword or self.token == kind.Kind.NullKeyword) {
            const tokenKind = self.token;
            self.nextToken();
            var literal: ast_gen.NodeIndex = 0;
            if (tokenKind == kind.Kind.TrueKeyword) {
                literal = try self.ast.pushNode(.{ .TrueKeyword = void{} });
            } else if (tokenKind == kind.Kind.FalseKeyword) {
                literal = try self.ast.pushNode(.{ .FalseKeyword = void{} });
            } else if (tokenKind == kind.Kind.NullKeyword) {
                literal = try self.ast.pushNode(.{ .NullKeyword = void{} });
            }
            return try self.ast.pushNode(.{ .LiteralType = .{ .Flags = 0, .Literal = literal } });
        } else if (self.token == kind.Kind.TemplateHead) {
            return try self.parseTemplateLiteralType();
        } else if (self.token == kind.Kind.AssertsKeyword and self.nextTokenIsIdentifierOrKeywordOnSameLine()) {
            return try self.parseAssertsTypePredicate();
        } else if (self.token == kind.Kind.TypeOfKeyword) {
            if (self.lookAhead(struct {
                fn run(p: *Parser) bool {
                    p.nextToken();
                    return p.token == kind.Kind.ImportKeyword;
                }
            }.run)) {
                return try self.parseImportType();
            }
            const type_query_start = self.scanner.state.tokenStart;
            self.nextToken();

            // Should be parseEntityName, and optionally typeArguments
            const exprName = try self.parseEntityName();
            var typeArguments: ?ast_gen.NodeListIndex = null;
            if (self.token == kind.Kind.LessThanToken and !self.scanner.hasPrecedingLineBreak()) {
                typeArguments = try self.parseTypeArguments();
            }
            const type_query_end = self.scanner.state.tokenStart;
            const type_query_node = try self.ast.pushNode(.{ .TypeQuery = .{ .Flags = 0, .ExprName = exprName, .TypeArguments = typeArguments } });
            if (type_query_node != 0 and type_query_node < self.ast.positions.items.len) {
                self.ast.positions.items[type_query_node] = .{ .pos = @intCast(type_query_start), .end = @intCast(type_query_end) };
            }
            return type_query_node;
        } else if (self.token == kind.Kind.ImportKeyword) {
            return try self.parseImportType();
        } else if (self.isIdentifier() or kind.isKeyword(self.token)) {
            const type_ref_start = self.scanner.state.tokenStart;
            const typeName = try self.parseEntityName();

            var typeArguments: ?ast_gen.NodeListIndex = null;
            if (self.token == kind.Kind.LessThanToken) {
                typeArguments = try self.parseTypeArguments();
            }
            const type_ref_end = self.scanner.state.tokenStart;
            const type_ref_node = try self.ast.pushNode(.{ .TypeReference = .{
                .Flags = 0,
                .TypeArguments = typeArguments,
                .TypeName = typeName,
            } });
            if (type_ref_node != 0 and type_ref_node < self.ast.positions.items.len) {
                self.ast.positions.items[type_ref_node] = .{ .pos = @intCast(type_ref_start), .end = @intCast(type_ref_end) };
            }
            return type_ref_node;
        } else if (self.token == kind.Kind.OpenBraceToken) {
            const start_pos = self.scanner.state.tokenStart;
            if (self.nextIsStartOfMappedType()) {
                return try self.parseMappedType();
            }
            self.nextToken();
            var members_arr = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
            defer members_arr.deinit(self.allocator);
            while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
                const startPos = self.scanner.state.pos;
                const memberNode = try self.parseTypeMember();
                try members_arr.append(self.allocator, memberNode);
                if (self.scanner.state.pos == startPos) {
                    self.nextToken(); // force advance if stuck
                }
            }
            _ = self.parseExpected(kind.Kind.CloseBraceToken);
            const members = try self.ast.pushNodeList(members_arr.items);
            const lit = try self.ast.pushNode(.{ .TypeLiteral = .{ .Flags = 0, .Symbol = 0, .Members = members } });
            self.setNodeStartPos(lit, start_pos);
            return lit;
        } else if (self.token == kind.Kind.OpenBracketToken) {
            return try self.parseTupleType();
        } else if (self.token == kind.Kind.OpenParenToken) {
            self.nextToken();
            const typeNode = try self.parseType();
            _ = self.parseExpected(kind.Kind.CloseParenToken);
            return try self.ast.pushNode(.{ .ParenthesizedType = .{ .Flags = 0, .Type = typeNode } });
        } else if (self.token == kind.Kind.AsteriskToken) {
            return try jsdoc.parseJSDocAllType(self);
        } else if (self.token == kind.Kind.QuestionToken) {
            return try jsdoc.parseJSDocNullableType(self);
        } else if (self.token == kind.Kind.ExclamationToken) {
            return try jsdoc.parseJSDocNonNullableType(self);
        }

        switch (self.token) {
            kind.Kind.BarToken, kind.Kind.AmpersandToken, kind.Kind.CloseBraceToken, kind.Kind.CloseBracketToken, kind.Kind.CloseParenToken, kind.Kind.CommaToken, kind.Kind.SemicolonToken, kind.Kind.ColonToken, kind.Kind.EqualsToken, kind.Kind.GreaterThanToken, kind.Kind.EndOfFile => {
                return self.ast.pushNode(.{ .Unknown = void{} });
            },
            else => {
                self.nextToken();
                return self.ast.pushNode(.{ .Unknown = void{} });
            },
        }
    }

    pub fn parseTemplateLiteralType(self: *Parser) anyerror!ast_gen.NodeIndex {
        const headText = self.scanner.state.tokenValue;
        const head = try self.ast.pushNode(.{ .TemplateHead = .{ .Flags = 0, .Text = headText, .TokenFlags = self.scanner.state.tokenFlags, .RawText = "", .TemplateFlags = @as(u16, @intCast(self.scanner.state.tokenFlags & 0xFFFF)) } });
        self.nextToken();

        var spans = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        while (true) {
            const spanType = try self.parseType();

            if (self.token == kind.Kind.CloseBraceToken) {
                self.token = self.scanner.reScanTemplateToken(false);
            } else {
                // error recovery
            }

            var litNode: ast_gen.NodeIndex = 0;
            if (self.token == kind.Kind.TemplateMiddle) {
                litNode = try self.ast.pushNode(.{ .TemplateMiddle = .{ .Flags = 0, .TokenFlags = self.scanner.state.tokenFlags, .Text = self.scanner.state.tokenValue, .RawText = "", .TemplateFlags = @as(u16, @intCast(self.scanner.state.tokenFlags & 0xFFFF)) } });
            } else {
                litNode = try self.ast.pushNode(.{ .TemplateTail = .{ .Flags = 0, .TokenFlags = self.scanner.state.tokenFlags, .Text = self.scanner.state.tokenValue, .RawText = "", .TemplateFlags = @as(u16, @intCast(self.scanner.state.tokenFlags & 0xFFFF)) } });
            }
            self.nextToken();

            const span = try self.ast.pushNode(.{ .TemplateLiteralTypeSpan = .{
                .Flags = 0,
                .Type = spanType,
                .Literal = litNode,
            } });
            try spans.append(self.allocator, span);

            const litNodeType = self.ast.nodes.get(litNode);
            if (litNodeType != .TemplateMiddle) {
                break;
            }
        }

        const templateSpans = try self.ast.pushNodeList(spans.items);

        return self.ast.pushNode(.{ .TemplateLiteralType = .{
            .Flags = 0,
            .Head = head,
            .TemplateSpans = templateSpans,
        } });
    }

    pub fn parseOptional(self: *Parser, t: kind.Kind) bool {
        if (self.token == t) {
            self.nextToken();
            return true;
        }
        return false;
    }

    pub fn parseOptionalToken(self: *Parser, t: kind.Kind) ast_gen.NodeIndex {
        if (self.token == t) {
            const tokenKind = self.token;
            self.nextToken();
            return self.ast.pushTokenNode(tokenKind) catch 0;
        }
        return 0;
    }

    pub fn parseExpected(self: *Parser, t: kind.Kind) bool {
        if (self.token == t) {
            self.nextToken();
            return true;
        }
        self.parseError("Expected token");
        self.nextToken();
        return false;
    }

    pub fn parseExpectedToken(self: *Parser, t: kind.Kind) ast_gen.NodeIndex {
        const token = self.parseOptionalToken(t);
        if (token == 0) {
            self.parseError("Expected token");
            return self.ast.pushNode(.{ .Token = .{ .Kind = t } }) catch 0;
        }
        return token;
    }

    pub fn parsePropertyName(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.token == kind.Kind.StringLiteral) {
            const start_pos = self.scanner.state.tokenStart;
            const end_pos = self.scanner.getTokenEnd();
            const text = self.scanner.getTokenValue();
            const tokenFlags = self.scanner.getTokenFlags();
            self.nextToken();
            const node = try self.ast.pushNode(.{ .StringLiteral = .{ .Flags = 0, .Text = text, .TokenFlags = tokenFlags } });
            self.ast.positions.items[node] = .{ .pos = @intCast(start_pos), .end = @intCast(end_pos) };
            return node;
        } else if (self.token == kind.Kind.NumericLiteral or self.token == kind.Kind.BigIntLiteral) {
            const start_pos = self.scanner.state.tokenStart;
            const end_pos = self.scanner.getTokenEnd();
            const text = self.scanner.state.tokenValue;
            const tokenKind = self.token;
            self.nextToken();
            const node = if (tokenKind == kind.Kind.NumericLiteral)
                try self.ast.pushNode(.{ .NumericLiteral = .{ .Flags = 0, .Text = text, .TokenFlags = 0 } })
            else
                try self.ast.pushNode(.{ .BigIntLiteral = .{ .Flags = 0, .Text = text, .TokenFlags = 0 } });
            self.ast.positions.items[node] = .{ .pos = @intCast(start_pos), .end = @intCast(end_pos) };
            return node;
        } else if (self.token == kind.Kind.OpenBracketToken) {
            const start_pos = self.scanner.state.tokenStart;
            self.nextToken();
            const expr = try @import("expression.zig").parseExpression(self);
            _ = self.parseExpected(kind.Kind.CloseBracketToken);
            const node = try self.ast.pushNode(.{ .ComputedPropertyName = .{ .Flags = 0, .Expression = expr } });
            self.setNodeStartPos(node, start_pos);
            return node;
        } else if (self.token == kind.Kind.PrivateIdentifier) {
            const start_pos = self.scanner.state.tokenStart;
            const end_pos = self.scanner.getTokenEnd();
            const text = self.scanner.state.tokenValue;
            self.nextToken();
            const node = try self.ast.pushNode(.{ .PrivateIdentifier = .{ .Flags = 0, .Text = text } });
            self.ast.positions.items[node] = .{ .pos = @intCast(start_pos), .end = @intCast(end_pos) };
            return node;
        } else {
            return self.parseIdentifierName();
        }
    }

    pub fn parseModuleExportName(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.token == kind.Kind.StringLiteral) {
            const start_pos = self.scanner.state.tokenStart;
            const end_pos = self.scanner.getTokenEnd();
            const text = self.scanner.state.tokenValue;
            const tokenFlags = self.scanner.getTokenFlags();
            self.nextToken();
            const node = try self.ast.pushNode(.{ .StringLiteral = .{ .Flags = 0, .Text = text, .TokenFlags = tokenFlags } });
            self.ast.positions.items[node] = .{ .pos = @intCast(start_pos), .end = @intCast(end_pos) };
            return node;
        }
        return self.parseIdentifierName();
    }

    pub fn parseIdentifierName(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.token == kind.Kind.Identifier or kind.isKeyword(self.token)) {
            const start_pos = self.scanner.state.tokenStart;
            const end_pos = self.scanner.getTokenEnd();
            const text = self.scanner.state.tokenValue;
            self.nextToken();
            const node = try self.ast.pushNode(.{ .Identifier = .{
                .Flags = 0,
                .Text = text,
            } });
            self.ast.positions.items[node] = .{ .pos = @intCast(start_pos), .end = @intCast(end_pos) };
            return node;
        }
        return self.parseIdentifier();
    }

    pub fn parseIdentifier(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.isIdentifier()) {
            const start_pos = self.scanner.state.tokenStart;
            const end_pos = self.scanner.getTokenEnd();
            const text = self.scanner.state.tokenValue;
            self.nextToken();
            const node = try self.ast.pushNode(.{ .Identifier = .{
                .Flags = 0,
                .Text = text,
            } });
            self.ast.positions.items[node] = .{ .pos = @intCast(start_pos), .end = @intCast(end_pos) };
            return node;
        }
        self.parseError("Expected identifier");
        return self.ast.pushNode(.{ .Identifier = .{
            .Flags = 0,
            .Text = "",
        } });
    }

    pub fn parsePrivateIdentifier(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.token == kind.Kind.PrivateIdentifier) {
            const text = self.scanner.state.tokenValue;
            self.nextToken();
            return self.ast.pushNode(.{ .PrivateIdentifier = .{ .Flags = 0, .Text = text } });
        }
        self.parseError("Expected private identifier");
        return self.ast.pushNode(.{ .PrivateIdentifier = .{ .Flags = 0, .Text = "" } });
    }

    pub fn createMissingIdentifier(self: *Parser) anyerror!ast_gen.NodeIndex {
        return self.ast.pushNode(.{ .Identifier = .{ .Flags = 0, .Text = "" } });
    }

    pub fn tryParseImportClause(self: *Parser, identifier: ?ast_gen.NodeIndex, pos: usize, phaseModifier: kind.Kind, skipJSDocLeadingAsterisks: bool) anyerror!?ast_gen.NodeIndex {
        if (identifier != null or self.token == kind.Kind.AsteriskToken or self.token == kind.Kind.OpenBraceToken) {
            var namedBindings: ?ast_gen.NodeIndex = null;
            if (identifier == null or self.parseOptional(kind.Kind.CommaToken)) {
                if (skipJSDocLeadingAsterisks) {
                    self.scanner.setSkipJSDocLeadingAsterisks(true);
                }
                if (self.token == kind.Kind.AsteriskToken) {
                    self.nextToken();
                    if (self.token == kind.Kind.AsKeyword) self.nextToken();
                    const nsName = try self.parseIdentifier();
                    namedBindings = try self.ast.pushNode(.{ .NamespaceImport = .{
                        .Symbol = 0,
                        .name = nsName,
                        .Flags = 0,
                    } });
                } else if (self.token == kind.Kind.OpenBraceToken) {
                    const start_brace = self.scanner.getTokenFullStart();
                    self.nextToken();
                    var elements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
                    defer elements.deinit(self.allocator);
                    while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
                        var specIsTypeOnly: u32 = 0;
                        var propertyName: ?ast_gen.NodeIndex = null;
                        var specName = try self.parseModuleExportName();

                        var isTypeKeyword = false;
                        const specNode = self.ast.getNode(specName);
                        if (specNode == .Identifier) {
                            if (std.mem.eql(u8, specNode.Identifier.Text, "type")) {
                                isTypeKeyword = true;
                            }
                        }

                        if (isTypeKeyword and self.token != kind.Kind.CommaToken and self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.AsKeyword) {
                            specIsTypeOnly = 1;
                            propertyName = try self.parseModuleExportName();
                            if (self.token == kind.Kind.AsKeyword) {
                                self.nextToken();
                                specName = try self.parseModuleExportName();
                            } else {
                                specName = propertyName.?;
                                propertyName = null;
                            }
                        } else {
                            if (self.token == kind.Kind.AsKeyword) {
                                self.nextToken();
                                propertyName = specName;
                                specName = try self.parseModuleExportName();
                            }
                        }

                        const specifier = try self.ast.pushNode(.{ .ImportSpecifier = .{
                            .Symbol = 0,
                            .PropertyName = propertyName,
                            .name = specName,
                            .Flags = 0,
                            .IsTypeOnly = specIsTypeOnly,
                        } });
                        try elements.append(self.allocator, specifier);

                        if (self.token == kind.Kind.CommaToken) {
                            self.nextToken();
                        } else {
                            break;
                        }
                    }
                    _ = self.parseExpected(kind.Kind.CloseBraceToken);
                    const namedImports = try self.ast.pushNode(.{ .NamedImports = .{
                        .Flags = 0,
                        .Elements = try self.ast.pushNodeList(elements.items),
                    } });
                    if (namedImports < self.ast.positions.items.len) {
                        self.ast.positions.items[namedImports] = .{ .pos = @intCast(start_brace), .end = @intCast(self.scanner.getTokenEnd()) };
                    }
                    namedBindings = namedImports;
                }
                if (skipJSDocLeadingAsterisks) {
                    self.scanner.setSkipJSDocLeadingAsterisks(false);
                }
            }
            const phaseModifierNode = if (phaseModifier == .TypeKeyword)
                try self.ast.pushNode(.{ .TypeKeyword = void{} })
            else
                null;
            const result = try self.ast.pushNode(.{ .ImportClause = .{
                .Symbol = 0,
                .Flags = 0,
                .PhaseModifier = phaseModifierNode,
                .name = identifier,
                .NamedBindings = namedBindings,
            } });
            if (result < self.ast.positions.items.len) {
                self.ast.positions.items[result] = .{ .pos = @intCast(pos), .end = @intCast(self.scanner.getTokenEnd()) };
            }
            _ = self.parseExpected(kind.Kind.FromKeyword);
            return result;
        }
        return null;
    }

    pub fn parseError(self: *Parser, msg: []const u8) void {
        const pos = @as(i32, @intCast(self.scanner.state.pos));
        if (pos == self.lastErrorPos) return;
        self.parseDiagnosticsCount += 1;
        self.lastErrorPos = pos;

        var message: *const diagnostics.Message = &diagnostics.generated.Identifier_expected;
        var args: []const []const u8 = &[_][]const u8{};
        if (std.mem.eql(u8, msg, "';' expected.")) {
            message = &diagnostics.generated.X_0_expected;
            args = &[_][]const u8{";"};
        } else if (std.mem.eql(u8, msg, "An enum member must be followed by a comma")) {
            message = &diagnostics.generated.Trailing_comma_not_allowed;
        }

        self.diagnostics.append(self.allocator, .{
            .message = message,
            .nodeIndex = 0,
            .args = args,
            .pos = @intCast(self.scanner.state.tokenStart),
        }) catch {};
    }

    pub fn isIndexSignature(self: *Parser) bool {
        if (self.token != kind.Kind.OpenBracketToken) return false;
        return self.lookAhead(nextIsUnambiguouslyIndexSignature);
    }

    fn nextIsUnambiguouslyIndexSignature(self: *Parser) bool {
        self.nextToken();
        if (self.token == kind.Kind.DotDotDotToken or self.token == kind.Kind.CloseBracketToken) {
            return true;
        }

        if (self.isModifierKind(self.token)) {
            self.nextToken();
            if (self.isIdentifier()) {
                return true;
            }
        } else if (!self.isIdentifier()) {
            return false;
        } else {
            self.nextToken();
        }

        if (self.token == kind.Kind.ColonToken or self.token == kind.Kind.CommaToken) {
            return true;
        }

        if (self.token != kind.Kind.QuestionToken) {
            return false;
        }

        self.nextToken();
        return self.token == kind.Kind.ColonToken or self.token == kind.Kind.CommaToken or self.token == kind.Kind.CloseBracketToken;
    }

    pub fn isStartOfFunctionTypeOrConstructorType(self: *Parser) bool {
        if (self.token == kind.Kind.LessThanToken) return true;
        if (self.token == kind.Kind.NewKeyword) return true;
        // JSDoc `function (params) => type` syntax — check that after
        // `function` there's an open paren. Use mark/rewind for safety.
        if (self.token == kind.Kind.FunctionKeyword) {
            return self.lookAhead(struct {
                fn run(p: *Parser) bool {
                    p.nextToken(); // consume 'function'
                    return p.token == kind.Kind.OpenParenToken;
                }
            }.run);
        }

        if (self.token == kind.Kind.OpenParenToken) {
            var tempScanner = self.scanner;
            var tok = tempScanner.scan();
            if (tok == kind.Kind.CloseParenToken or tok == kind.Kind.DotDotDotToken) {
                return true;
            }

            while (tok == kind.Kind.PublicKeyword or tok == kind.Kind.PrivateKeyword or tok == kind.Kind.ProtectedKeyword or tok == kind.Kind.ReadonlyKeyword or tok == kind.Kind.OverrideKeyword or tok == kind.Kind.InKeyword or tok == kind.Kind.OutKeyword) {
                tok = tempScanner.scan();
            }

            if (tok == kind.Kind.Identifier or @intFromEnum(tok) > @intFromEnum(kind.Kind.WithKeyword)) {
                tok = tempScanner.scan();
                if (tok == kind.Kind.ColonToken or tok == kind.Kind.CommaToken or tok == kind.Kind.QuestionToken or tok == kind.Kind.EqualsToken) {
                    return true;
                }
                if (tok == kind.Kind.CloseParenToken) {
                    tok = tempScanner.scan();
                    if (tok == kind.Kind.EqualsGreaterThanToken) {
                        return true;
                    }
                }
            } else if (tok == kind.Kind.OpenBraceToken or tok == kind.Kind.OpenBracketToken) {
                // For destructuring patterns like ({ a, b }: ...) or ([a, b]: ...)
                // we use mark/rewind to speculatively parse the binding pattern
                const savedState = self.mark();
                self.nextToken(); // consume '('
                _ = self.parseIdentifierOrPattern() catch {
                    self.rewind(savedState);
                    return false;
                };
                // After pattern, check for parameter declaration tokens
                const afterPattern = self.token;
                self.rewind(savedState);
                if (afterPattern == kind.Kind.ColonToken or
                    afterPattern == kind.Kind.CommaToken or
                    afterPattern == kind.Kind.QuestionToken or
                    afterPattern == kind.Kind.EqualsToken or
                    afterPattern == kind.Kind.CloseParenToken)
                {
                    return true;
                }
            }
        }
        return false;
    }

    pub fn parseImportType(self: *Parser) anyerror!ast_gen.NodeIndex {
        const isTypeOf = self.parseOptional(kind.Kind.TypeOfKeyword);
        _ = self.parseExpected(kind.Kind.ImportKeyword);
        _ = self.parseExpected(kind.Kind.OpenParenToken);
        const typeNode = try self.parseType();
        var attributes: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.CommaToken)) {
            _ = self.parseExpected(kind.Kind.OpenBraceToken);
            const currentToken = self.token;
            if (currentToken == kind.Kind.WithKeyword or currentToken == kind.Kind.AssertKeyword) {
                self.nextToken();
            }
            _ = self.parseExpected(kind.Kind.ColonToken);

            if (self.token == kind.Kind.OpenBraceToken) {
                self.nextToken();
                var elements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
                defer elements.deinit(self.allocator);
                while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
                    const nameNode = try self.parsePropertyName();
                    _ = self.parseExpected(kind.Kind.ColonToken);
                    const valueNode = try @import("expression.zig").parseAssignmentExpressionOrHigher(self);
                    const attrNode = try self.ast.pushNode(.{ .ImportAttribute = .{
                        .Flags = 0,
                        .name = nameNode,
                        .Value = valueNode,
                    } });
                    try elements.append(self.allocator, attrNode);
                    if (self.token == kind.Kind.CommaToken) {
                        self.nextToken();
                    } else {
                        break;
                    }
                }
                _ = self.parseExpected(kind.Kind.CloseBraceToken);
                const attributesList = try self.ast.pushNodeList(elements.items);
                attributes = try self.ast.pushNode(.{ .ImportAttributes = .{
                    .Flags = 0,
                    .Token = @intFromEnum(currentToken),
                    .Attributes = attributesList,
                    .MultiLine = 0,
                } });
            }

            _ = self.parseOptional(kind.Kind.CommaToken);
            _ = self.parseExpected(kind.Kind.CloseBraceToken);
        }
        _ = self.parseExpected(kind.Kind.CloseParenToken);
        var qualifier: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.DotToken)) {
            qualifier = try self.parseEntityName();
        }
        var typeArguments: ?ast_gen.NodeListIndex = null;
        if (self.token == kind.Kind.LessThanToken) {
            typeArguments = try self.parseTypeArguments();
        }
        return self.ast.pushNode(.{ .ImportType = .{
            .Flags = 0,
            .IsTypeOf = if (isTypeOf) 1 else 0,
            .Argument = typeNode,
            .Attributes = attributes,
            .Qualifier = qualifier,
            .TypeArguments = typeArguments,
        } });
    }

    pub fn parseFunctionOrConstructorType(self: *Parser, hasAbstractModifier: bool) anyerror!ast_gen.NodeIndex {
        var modifiers: ?ast_gen.NodeListIndex = null;
        if (hasAbstractModifier) {
            const abstractMod = try self.ast.pushNode(.{ .AbstractKeyword = void{} });
            modifiers = try self.ast.pushNodeList(&[_]ast_gen.NodeIndex{abstractMod});
        }

        const isConstructorType = self.parseOptional(kind.Kind.NewKeyword);
        // JSDoc `function (params) => type` — consume the `function` keyword.
        _ = self.parseOptional(kind.Kind.FunctionKeyword);
        const typeParameters = try self.parseTypeParameters();
        const parameters = try self.parseParameters();
        var returnType: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.EqualsGreaterThanToken)) {
            returnType = try self.parseTypeOrTypePredicate();
        }

        if (isConstructorType) {
            return self.ast.pushNode(.{ .ConstructorType = .{
                .Symbol = 0,
                .Flags = 0,
                .modifiers = modifiers,
                .modifierFlags = 0,
                .TypeParameters = typeParameters,
                .Parameters = parameters,
                .Type = returnType,
                .FullSignature = null,
            } });
        } else {
            return self.ast.pushNode(.{ .FunctionType = .{
                .Symbol = 0,
                .Flags = 0,
                .modifiers = modifiers,
                .modifierFlags = 0,
                .TypeParameters = typeParameters,
                .Parameters = parameters,
                .Type = returnType,
                .FullSignature = null,
            } });
        }
    }

    pub fn parseType(self: *Parser) anyerror!ast_gen.NodeIndex {
        const hasAbstractModifier = self.parseOptional(kind.Kind.AbstractKeyword);
        if (hasAbstractModifier or self.isStartOfFunctionTypeOrConstructorType()) {
            return self.parseFunctionOrConstructorType(hasAbstractModifier);
        }

        const typeNode = try self.parseUnionTypeOrHigher();

        if (!self.scanner.hasPrecedingLineBreak() and self.parseOptional(kind.Kind.ExtendsKeyword)) {
            const extendsType = try self.parseType();
            _ = self.parseExpected(kind.Kind.QuestionToken);
            const trueType = try self.parseType();
            _ = self.parseExpected(kind.Kind.ColonToken);
            const falseType = try self.parseType();

            return self.ast.pushNode(.{ .ConditionalType = .{
                .Flags = 0,
                .CheckType = typeNode,
                .ExtendsType = extendsType,
                .TrueType = trueType,
                .FalseType = falseType,
            } });
        }

        return typeNode;
    }

    pub fn parseMethodDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32, asteriskToken: ?ast_gen.NodeIndex, name: ast_gen.NodeIndex, postfixToken: ?ast_gen.NodeIndex, start_pos: usize) anyerror!ast_gen.NodeIndex {
        const typeParameters = try self.parseTypeParameters();
        const parameters = try self.parseParameters();
        const returnType = try self.parseReturnTypeAnnotation();
        var body: ?ast_gen.NodeIndex = null;
        if (self.token == kind.Kind.OpenBraceToken) {
            body = try self.parseBlock();
        } else {
            self.parseSemicolon();
        }

        const decl = try self.ast.pushNode(.{ .MethodDeclaration = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .name = name,
            .PostfixToken = postfixToken,
            .TypeParameters = typeParameters,
            .Parameters = parameters,
            .Type = returnType,
            .FullSignature = null,
            .AsteriskToken = asteriskToken,
            .Body = body,
        } });
        self.setNodeStartPos(decl, start_pos);
        return decl;
    }

    pub fn nextIsStartOfMappedType(self: *Parser) bool {
        const m = self.mark();
        defer self.rewind(m);
        self.nextToken(); // skip OpenBraceToken
        if (self.token == kind.Kind.PlusToken or self.token == kind.Kind.MinusToken) {
            self.nextToken();
            if (self.token != kind.Kind.ReadonlyKeyword) return false;
            self.nextToken();
        } else if (self.token == kind.Kind.ReadonlyKeyword) {
            self.nextToken();
        }
        if (self.token == kind.Kind.OpenBracketToken) {
            self.nextToken();
            if (self.isIdentifier()) {
                self.nextToken();
                return self.token == kind.Kind.InKeyword;
            }
        }
        return false;
    }

    pub fn parseMappedType(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.OpenBraceToken);
        var readonlyToken: ?ast_gen.NodeIndex = null;
        if (self.token == kind.Kind.ReadonlyKeyword or self.token == kind.Kind.PlusToken or self.token == kind.Kind.MinusToken) {
            const t = self.token;
            self.nextToken();
            readonlyToken = switch (t) {
                .ReadonlyKeyword => try self.ast.pushNode(.{ .ReadonlyKeyword = void{} }),
                .PlusToken => try self.ast.pushNode(.{ .PlusToken = void{} }),
                .MinusToken => try self.ast.pushNode(.{ .MinusToken = void{} }),
                else => unreachable,
            };
            if (t != kind.Kind.ReadonlyKeyword) {
                _ = self.parseExpected(kind.Kind.ReadonlyKeyword);
            }
        }
        _ = self.parseExpected(kind.Kind.OpenBracketToken);
        const typeParameter = try self.parseMappedTypeParameter();
        var nameType: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.AsKeyword)) {
            nameType = try self.parseType();
        }
        _ = self.parseExpected(kind.Kind.CloseBracketToken);
        var questionToken: ?ast_gen.NodeIndex = null;
        if (self.token == kind.Kind.QuestionToken or self.token == kind.Kind.PlusToken or self.token == kind.Kind.MinusToken) {
            const t = self.token;
            self.nextToken();
            questionToken = switch (t) {
                .QuestionToken => try self.ast.pushNode(.{ .QuestionToken = void{} }),
                .PlusToken => try self.ast.pushNode(.{ .PlusToken = void{} }),
                .MinusToken => try self.ast.pushNode(.{ .MinusToken = void{} }),
                else => unreachable,
            };
            if (t != kind.Kind.QuestionToken) {
                _ = self.parseExpected(kind.Kind.QuestionToken);
            }
        }
        const typeNode = try self.parseTypeAnnotation();
        self.parseTypeMemberSemicolon();

        var members_arr = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer members_arr.deinit(self.allocator);
        while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
            const startPos = self.scanner.state.pos;
            const memberNode = try self.parseTypeMember();
            try members_arr.append(self.allocator, memberNode);
            if (self.scanner.state.pos == startPos) {
                self.nextToken(); // force advance if stuck
            }
        }
        _ = self.parseExpected(kind.Kind.CloseBraceToken);
        const members = try self.ast.pushNodeList(members_arr.items);
        return try self.ast.pushNode(.{ .MappedType = .{
            .Flags = 0,
            .Symbol = 0,
            .ReadonlyToken = readonlyToken,
            .TypeParameter = typeParameter,
            .NameType = nameType,
            .QuestionToken = questionToken,
            .Type = typeNode,
            .Members = members,
        } });
    }

    pub fn parseMappedTypeParameter(self: *Parser) anyerror!ast_gen.NodeIndex {
        const name = try self.parseIdentifierName();
        _ = self.parseExpected(kind.Kind.InKeyword);
        const typeNode = try self.parseType();
        return try self.ast.pushNode(.{ .TypeParameter = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = null,
            .modifierFlags = 0,
            .name = name,
            .Constraint = typeNode,
            .Expression = null,
            .DefaultType = null,
        } });
    }

    pub fn parseIntersectionTypeOrHigher(self: *Parser) anyerror!ast_gen.NodeIndex {
        const hasLeadingOperator = self.parseOptional(kind.Kind.AmpersandToken);
        var typeNode = try self.parseTypeOperatorOrHigher();

        if (self.token == kind.Kind.AmpersandToken or hasLeadingOperator) {
            var types = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
            defer types.deinit(self.allocator);
            try types.append(self.allocator, typeNode);

            while (self.parseOptional(kind.Kind.AmpersandToken)) {
                try types.append(self.allocator, try self.parseTypeOperatorOrHigher());
            }

            const typesList = try self.ast.pushNodeList(types.items);
            typeNode = try self.ast.pushNode(.{ .IntersectionType = .{
                .Flags = 0,
                .Types = typesList,
            } });
        }

        return typeNode;
    }

    pub fn parseUnionTypeOrHigher(self: *Parser) anyerror!ast_gen.NodeIndex {
        const hasLeadingOperator = self.parseOptional(kind.Kind.BarToken);
        var typeNode = try self.parseIntersectionTypeOrHigher();

        if (self.token == kind.Kind.BarToken or hasLeadingOperator) {
            var types = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
            defer types.deinit(self.allocator);
            try types.append(self.allocator, typeNode);

            while (self.parseOptional(kind.Kind.BarToken)) {
                try types.append(self.allocator, try self.parseIntersectionTypeOrHigher());
            }

            const typesList = try self.ast.pushNodeList(types.items);
            typeNode = try self.ast.pushNode(.{ .UnionType = .{
                .Flags = 0,
                .Types = typesList,
            } });
        }

        return typeNode;
    }

    pub fn parseInferType(self: *Parser) anyerror!ast_gen.NodeIndex {
        self.nextToken(); // consume 'infer'
        const typeParameter = try self.parseTypeParameter();
        return self.ast.pushNode(.{ .InferType = .{
            .Flags = 0,
            .TypeParameter = typeParameter,
        } });
    }

    pub fn parseTypeOperatorOrHigher(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.token == kind.Kind.InferKeyword) {
            return try self.parseInferType();
        } else if (self.token == kind.Kind.KeyOfKeyword or self.token == kind.Kind.UniqueKeyword or self.token == kind.Kind.ReadonlyKeyword) {
            // Stub for parseTypeOperator for now
            const operator = self.token;
            self.nextToken();
            const typeNode = try self.parseTypeOperatorOrHigher();
            return self.ast.pushNode(.{ .TypeOperator = .{
                .Flags = 0,
                .Operator = @intFromEnum(operator),
                .Type = typeNode,
            } });
        }

        var typeNode = try self.parsePrimaryType();
        while (!self.scanner.hasPrecedingLineBreak()) {
            if (self.token == kind.Kind.OpenBracketToken) {
                self.nextToken();

                var isIndexedAccess = false;
                if (self.token != kind.Kind.CloseBracketToken) {
                    isIndexedAccess = true;
                }

                if (isIndexedAccess) {
                    const indexType = try self.parseType();
                    _ = self.parseExpected(kind.Kind.CloseBracketToken);
                    typeNode = try self.ast.pushNode(.{ .IndexedAccessType = .{
                        .Flags = 0,
                        .ObjectType = typeNode,
                        .IndexType = indexType,
                    } });
                } else {
                    _ = self.parseExpected(kind.Kind.CloseBracketToken);
                    typeNode = try self.ast.pushNode(.{ .ArrayType = .{
                        .Flags = 0,
                        .ElementType = typeNode,
                    } });
                }
            } else if (self.inJSDocType and self.token == kind.Kind.ExclamationToken) {
                self.nextToken();
                typeNode = try self.ast.pushNode(.{ .JSDocNonNullableType = .{
                    .Flags = 0,
                    .Type = typeNode,
                } });
            } else if (self.inJSDocType and self.token == kind.Kind.QuestionToken) {
                // If next token is start of a type we have a conditional type - don't consume
                if (self.lookAhead(struct {
                    fn check(p: *Parser) bool {
                        p.nextToken();
                        return p.isStartOfType();
                    }
                }.check)) break;
                self.nextToken();
                typeNode = try self.ast.pushNode(.{ .JSDocNullableType = .{
                    .Flags = 0,
                    .Type = typeNode,
                } });
            } else {
                break;
            }
        }
        return typeNode;
    }

    pub fn parseTypeElement(self: *Parser) anyerror!ast_gen.NodeIndex {
        const element_start = self.scanner.state.tokenStart;
        if (self.token == kind.Kind.OpenParenToken or self.token == kind.Kind.LessThanToken) {
            const typeParameters = try self.parseTypeParameters();
            const parameters = try self.parseParameters();
            var returnType: ?ast_gen.NodeIndex = null;
            if (self.parseOptional(kind.Kind.ColonToken)) {
                returnType = try self.parseType();
            }
            _ = self.parseOptional(kind.Kind.SemicolonToken) or self.parseOptional(kind.Kind.CommaToken);
            const sig = try self.ast.pushNode(.{ .CallSignature = .{
                .Flags = 0,
                .TypeParameters = typeParameters,
                .Parameters = parameters,
                .Type = returnType,
            } });
            self.setNodeStartPos(sig, element_start);
            return sig;
        }

        if (self.token == kind.Kind.NewKeyword) {
            var tempScanner = self.scanner;
            const tok = tempScanner.scan();
            if (tok == kind.Kind.OpenParenToken or tok == kind.Kind.LessThanToken) {
                self.nextToken(); // consume new
                const typeParameters = try self.parseTypeParameters();
                const parameters = try self.parseParameters();
                var returnType: ?ast_gen.NodeIndex = null;
                if (self.parseOptional(kind.Kind.ColonToken)) {
                    returnType = try self.parseType();
                }
                _ = self.parseOptional(kind.Kind.SemicolonToken) or self.parseOptional(kind.Kind.CommaToken);
                const sig = try self.ast.pushNode(.{ .ConstructSignature = .{
                    .Flags = 0,
                    .TypeParameters = typeParameters,
                    .Parameters = parameters,
                    .Type = returnType,
                } });
                self.setNodeStartPos(sig, element_start);
                return sig;
            }
        }

        if (self.isIndexSignature()) {
            _ = self.parseExpected(kind.Kind.OpenBracketToken);
            const parameter = try self.parseParameter();
            _ = self.parseExpected(kind.Kind.CloseBracketToken);
            const returnType = try self.parseTypeAnnotation();
            _ = self.parseOptional(kind.Kind.SemicolonToken) or self.parseOptional(kind.Kind.CommaToken);
            var parametersList = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
            defer parametersList.deinit(self.allocator);
            try parametersList.append(self.allocator, parameter);
            const parameters = try self.ast.pushNodeList(parametersList.items);
            const sig = try self.ast.pushNode(.{ .IndexSignature = .{
                .Flags = 0,
                .modifiers = null,
                .modifierFlags = 0,
                .TypeParameters = null,
                .Parameters = parameters,
                .Type = returnType orelse 0,
                .FullSignature = null,
            } });
            self.setNodeStartPos(sig, element_start);
            return sig;
        }

        var isGet = false;
        var isSet = false;
        var name: ast_gen.NodeIndex = 0;

        if (self.token == kind.Kind.GetKeyword) {
            var tempScanner = self.scanner;
            _ = tempScanner.scan();
            if (self.isIdentifier() or self.token == kind.Kind.StringLiteral or self.token == kind.Kind.NumericLiteral or self.token == kind.Kind.BigIntLiteral) {
                isGet = true;
                self.nextToken();
            }
        } else if (self.token == kind.Kind.SetKeyword) {
            var tempScanner = self.scanner;
            _ = tempScanner.scan();
            if (self.isIdentifier() or self.token == kind.Kind.StringLiteral or self.token == kind.Kind.NumericLiteral or self.token == kind.Kind.BigIntLiteral) {
                isSet = true;
                self.nextToken();
            }
        }

        name = try self.parsePropertyName();
        const questionToken = if (self.parseOptional(kind.Kind.QuestionToken)) try self.ast.pushNode(.{ .QuestionToken = void{} }) else null;

        if (self.token == kind.Kind.OpenParenToken or self.token == kind.Kind.LessThanToken) {
            const typeParameters = try self.parseTypeParameters();
            const parameters = try self.parseParameters();
            var returnType: ?ast_gen.NodeIndex = null;
            if (self.parseOptional(kind.Kind.ColonToken)) {
                returnType = try self.parseType();
            }
            _ = self.parseOptional(kind.Kind.SemicolonToken) or self.parseOptional(kind.Kind.CommaToken);

            if (isGet) {
                const sig = try self.ast.pushNode(.{ .GetAccessor = .{
                    .Flags = 0,
                    .modifiers = null,
                    .modifierFlags = 0,
                    .name = name,
                    .TypeParameters = typeParameters,
                    .Parameters = parameters,
                    .Type = returnType,
                    .Body = null,
                    .PostfixToken = null,
                    .FullSignature = null,
                    .AsteriskToken = null,
                } });
                self.setNodeStartPos(sig, element_start);
                return sig;
            } else if (isSet) {
                const sig = try self.ast.pushNode(.{ .SetAccessor = .{
                    .Flags = 0,
                    .modifiers = null,
                    .modifierFlags = 0,
                    .name = name,
                    .TypeParameters = typeParameters,
                    .Parameters = parameters,
                    .Type = returnType,
                    .Body = null,
                    .PostfixToken = null,
                    .FullSignature = null,
                    .AsteriskToken = null,
                } });
                self.setNodeStartPos(sig, element_start);
                return sig;
            } else {
                const sig = try self.ast.pushNode(.{ .MethodSignature = .{
                    .Flags = 0,
                    .modifiers = null,
                    .modifierFlags = 0,
                    .name = name,
                    .PostfixToken = questionToken,
                    .TypeParameters = typeParameters,
                    .Parameters = parameters,
                    .Type = returnType,
                } });
                self.setNodeStartPos(sig, element_start);
                return sig;
            }
        } else {
            const typeNode = try self.parseTypeAnnotation();
            _ = self.parseOptional(kind.Kind.SemicolonToken) or self.parseOptional(kind.Kind.CommaToken);

            const sig = try self.ast.pushNode(.{ .PropertySignature = .{
                .Flags = 0,
                .modifiers = null,
                .modifierFlags = 0,
                .name = name,
                .PostfixToken = questionToken orelse 0,
                .Type = typeNode orelse 0,
                .Initializer = 0,
            } });
            self.setNodeStartPos(sig, element_start);
            return sig;
        }
    }

    pub fn isIdentifier(self: *Parser) bool {
        if (self.token == kind.Kind.Identifier) {
            return true;
        }
        return @intFromEnum(self.token) > @intFromEnum(kind.Kind.WithKeyword);
    }

    pub fn parseSemicolon(self: *Parser) void {
        if (self.parseOptional(kind.Kind.SemicolonToken)) {
            return;
        }
        if (self.scanner.hasPrecedingLineBreak() or self.token == kind.Kind.CloseBraceToken or self.token == kind.Kind.EndOfFile) {
            return;
        }
        self.parseError("';' expected.");
    }

    /// Type members can be separated by commas OR (possibly ASI) semicolons.
    /// See: https://www.typescriptlang.org/docs/handbook/2/objects.html
    pub fn parseIndexSignatureDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        const start_pos = self.scanner.state.tokenStart;
        _ = self.parseExpected(kind.Kind.OpenBracketToken);
        const parameter = try self.parseParameter();
        _ = self.parseExpected(kind.Kind.CloseBracketToken);
        const returnType = try self.parseTypeAnnotation();
        self.parseTypeMemberSemicolon();

        var parametersList = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer parametersList.deinit(self.allocator);
        try parametersList.append(self.allocator, parameter);
        const parameters = try self.ast.pushNodeList(parametersList.items);

        const sig = try self.ast.pushNode(.{ .IndexSignature = .{
            .Flags = 0,
            .Symbol = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .TypeParameters = null,
            .Parameters = parameters,
            .Type = returnType orelse 0,
            .FullSignature = null,
        } });
        self.setNodeStartPos(sig, start_pos);
        return sig;
    }

    pub fn parseTypeMemberSemicolon(self: *Parser) void {
        // We allow type members to be separated by commas or (possibly ASI) semicolons.
        // First check if it was a comma. If so, we're done with the member.
        if (self.parseOptional(kind.Kind.CommaToken)) {
            return;
        }
        // Didn't have a comma. We must have a (possible ASI) semicolon.
        self.parseSemicolon();
    }

    fn parseTupleType(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.OpenBracketToken);
        var elements_arr = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer elements_arr.deinit(self.allocator);
        while (self.token != kind.Kind.CloseBracketToken and self.token != kind.Kind.EndOfFile) {
            const element = try self.parseTupleElementNameOrTupleElementType();
            try elements_arr.append(self.allocator, element);
            if (self.token == kind.Kind.CommaToken) {
                self.nextToken();
            } else {
                break;
            }
        }
        _ = self.parseExpected(kind.Kind.CloseBracketToken);
        const elements = try self.ast.pushNodeList(elements_arr.items);
        return self.ast.pushNode(.{ .TupleType = .{ .Flags = 0, .Elements = elements } });
    }

    fn parseTupleElementType(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.token == kind.Kind.DotDotDotToken) {
            self.nextToken();
            const typeNode = try self.parseType();
            return self.ast.pushNode(.{ .RestType = .{ .Flags = 0, .Type = typeNode } });
        }
        const typeNode = try self.parseType();
        if (self.token == kind.Kind.QuestionToken) {
            self.nextToken();
            return self.ast.pushNode(.{ .OptionalType = .{ .Flags = 0, .Type = typeNode } });
        }
        return typeNode;
    }

    fn parseTupleElementNameOrTupleElementType(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.scanStartOfNamedTupleElement()) {
            var dotDotDotToken: ?ast_gen.NodeIndex = null;
            if (self.parseOptional(kind.Kind.DotDotDotToken)) {
                dotDotDotToken = try self.ast.pushNode(.{ .DotDotDotToken = void{} });
            }
            const name = try self.parseIdentifierName();
            var questionToken: ?ast_gen.NodeIndex = null;
            if (self.parseOptional(kind.Kind.QuestionToken)) {
                questionToken = try self.ast.pushNode(.{ .QuestionToken = void{} });
            }
            _ = self.parseExpected(kind.Kind.ColonToken);
            const typeNode = try self.parseTupleElementType();
            return self.ast.pushNode(.{ .NamedTupleMember = .{
                .Flags = 0,
                .Symbol = 0,
                .DotDotDotToken = dotDotDotToken,
                .name = name,
                .QuestionToken = questionToken,
                .Type = typeNode,
            } });
        }
        return self.parseTupleElementType();
    }

    fn scanStartOfNamedTupleElement(self: *Parser) bool {
        var tempScanner = self.scanner;
        var token = self.token;
        if (token == kind.Kind.DotDotDotToken) {
            token = tempScanner.scan();
        }
        if (token == kind.Kind.Identifier or kind.isKeyword(token)) {
            const next1 = tempScanner.scan();
            if (next1 == kind.Kind.ColonToken) return true;
            if (next1 == kind.Kind.QuestionToken) {
                const next2 = tempScanner.scan();
                if (next2 == kind.Kind.ColonToken) return true;
            }
        }
        return false;
    }

    pub fn getCommentPragmas(self: *Parser, pragmas: *std.ArrayListUnmanaged(ast.Pragma)) !void {
        var commentRanges = std.ArrayList(scanner_pkg.CommentRange).empty;
        defer commentRanges.deinit(self.allocator);
        try scanner_pkg.getLeadingCommentRanges(self.allocator, &commentRanges, self.sourceText, 0);
        for (commentRanges.items) |commentRange| {
            const comment = self.sourceText[commentRange.pos..commentRange.end];
            try self.extractPragmas(commentRange, comment, pragmas);
        }
    }

    fn extractPragmas(self: *Parser, commentRange: scanner_pkg.CommentRange, text: []const u8, pragmas: *std.ArrayListUnmanaged(ast.Pragma)) !void {
        if (commentRange.kind == .SingleLineCommentTrivia) {
            var pos: usize = 2;
            const tripleSlash = (pos < text.len and text[pos] == '/');
            if (tripleSlash) {
                pos += 1;
            }
            pos = skipBlanks(text, pos);
            if (tripleSlash and pos < text.len and text[pos] == '<') {
                const tagName = extractName(text, pos + 1);
                if (!std.mem.eql(u8, tagName, "reference")) {
                    return;
                }
                pos += 10;
                var args = std.ArrayList(ast.PragmaArgument).empty;
                errdefer {
                    for (args.items) |arg| {
                        self.allocator.free(arg.name);
                        self.allocator.free(arg.value);
                    }
                    args.deinit(self.allocator);
                }
                while (true) {
                    pos = skipBlanks(text, pos);
                    if (std.mem.startsWith(u8, text[pos..], "/>")) {
                        break;
                    }
                    const argName = extractName(text, pos);
                    if (argName.len == 0) {
                        break;
                    }
                    pos = skipBlanks(text, pos + argName.len);
                    if (!(pos < text.len and text[pos] == '=')) {
                        break;
                    }
                    pos = skipBlanks(text, pos + 1);
                    var value_buf: []const u8 = "";
                    const ok = extractQuotedString(text, pos, &value_buf);
                    if (!ok) {
                        break;
                    }
                    const name_dup = try self.allocator.dupe(u8, argName);
                    const val_dup = try self.allocator.dupe(u8, value_buf);
                    try args.append(self.allocator, .{
                        .pos = @intCast(commentRange.pos + pos + 1),
                        .end = @intCast(commentRange.pos + pos + 1 + value_buf.len),
                        .name = name_dup,
                        .value = val_dup,
                    });
                    pos += value_buf.len + 2;
                }
                const name_dup = try self.allocator.dupe(u8, "reference");
                try pragmas.append(self.allocator, .{
                    .pos = commentRange.pos,
                    .end = commentRange.end,
                    .kind = commentRange.kind,
                    .hasTrailingNewLine = commentRange.hasTrailingNewLine,
                    .name = name_dup,
                    .args = try args.toOwnedSlice(self.allocator),
                });
                return;
            }
            if (pos < text.len and text[pos] == '@') {
                pos += 1;
                const pragmaName = extractName(text, pos);
                if (std.mem.eql(u8, pragmaName, "ts-check") or std.mem.eql(u8, pragmaName, "ts-nocheck")) {
                    const name_dup = try self.allocator.dupe(u8, pragmaName);
                    try pragmas.append(self.allocator, .{
                        .pos = commentRange.pos,
                        .end = commentRange.end,
                        .kind = commentRange.kind,
                        .hasTrailingNewLine = commentRange.hasTrailingNewLine,
                        .name = name_dup,
                        .args = &[_]ast.PragmaArgument{},
                    });
                }
                return;
            }
        }
        if (commentRange.kind == .MultiLineCommentTrivia) {
            var text_trimmed = text;
            if (std.mem.endsWith(u8, text_trimmed, "*/")) {
                text_trimmed = text_trimmed[0 .. text_trimmed.len - 2];
            }
            var pos: usize = 2;
            while (true) {
                pos = skipTo(text_trimmed, pos, "@");
                if (pos == @as(usize, @bitCast(@as(isize, -1)))) {
                    break;
                }
                const namePos = pos + 1;
                const nameEnd = skipNonBlanks(text_trimmed, namePos);
                if (nameEnd == namePos) {
                    pos += 1;
                    continue;
                }
                const lineEnd = lineEndPos(text_trimmed, pos);
                const pragmaName = std.ascii.allocLowerString(self.allocator, text_trimmed[namePos..nameEnd]) catch |err| return err;
                defer self.allocator.free(pragmaName);
                if (std.mem.eql(u8, pragmaName, "jsx") or std.mem.eql(u8, pragmaName, "jsxfrag") or std.mem.eql(u8, pragmaName, "jsximportsource") or std.mem.eql(u8, pragmaName, "jsxruntime")) {
                    const start = skipBlanks(text_trimmed, nameEnd);
                    const argEnd = skipNonBlanks(text_trimmed, start);
                    if (argEnd != start) {
                        var args = try self.allocator.alloc(ast.PragmaArgument, 1);
                        args[0] = .{
                            .pos = @intCast(commentRange.pos + start),
                            .end = @intCast(commentRange.pos + argEnd),
                            .name = try self.allocator.dupe(u8, "factory"),
                            .value = try self.allocator.dupe(u8, text_trimmed[start..argEnd]),
                        };
                        const name_dup = try self.allocator.dupe(u8, pragmaName);
                        try pragmas.append(self.allocator, .{
                            .pos = commentRange.pos,
                            .end = commentRange.end,
                            .kind = commentRange.kind,
                            .hasTrailingNewLine = commentRange.hasTrailingNewLine,
                            .name = name_dup,
                            .args = args,
                        });
                    }
                }
                pos = lineEnd;
            }
        }
    }

    fn skipBlanks(text: []const u8, pos: usize) usize {
        var p = pos;
        while (p < text.len and (text[p] == ' ' or text[p] == '\t')) {
            p += 1;
        }
        return p;
    }

    fn skipNonBlanks(text: []const u8, pos: usize) usize {
        var p = pos;
        while (p < text.len and text[p] != ' ' and text[p] != '\t' and text[p] != '\r' and text[p] != '\n') {
            p += 1;
        }
        return p;
    }

    fn skipTo(text: []const u8, pos: usize, s: []const u8) usize {
        if (pos >= text.len) {
            return @as(usize, @bitCast(@as(isize, -1)));
        }
        if (std.mem.indexOf(u8, text[pos..], s)) |i| {
            return pos + i;
        }
        return @as(usize, @bitCast(@as(isize, -1)));
    }

    fn lineEndPos(text: []const u8, pos: usize) usize {
        var p = pos;
        while (p < text.len) {
            if (p < text.len and (text[p] == '\n' or text[p] == '\r')) {
                return p;
            }
            p += 1;
        }
        return text.len;
    }

    fn extractName(text: []const u8, pos: usize) []const u8 {
        var p = pos;
        while (p < text.len and ((text[p] >= 'A' and text[p] <= 'Z') or (text[p] >= 'a' and text[p] <= 'z') or text[p] == '-')) {
            p += 1;
        }
        return text[pos..p];
    }

    fn extractQuotedString(text: []const u8, pos: usize, out_val: *[]const u8) bool {
        if (pos >= text.len) {
            return false;
        }
        const quote = text[pos];
        if (quote != '\'' and quote != '"') {
            return false;
        }
        var p = pos + 1;
        const start = p;
        while (p < text.len and text[p] != quote) {
            p += 1;
        }
        if (p >= text.len) {
            return false;
        }
        out_val.* = text[start..p];
        return true;
    }

    fn processPragmasIntoFields(self: *Parser, pragmas: []const ast.Pragma) !void {
        self.ast.checkJsDirective = null;
        self.ast.referencedFiles.clearRetainingCapacity();
        self.ast.typeReferenceDirectives.clearRetainingCapacity();
        self.ast.libReferenceDirectives.clearRetainingCapacity();

        for (pragmas) |pragma| {
            if (std.mem.eql(u8, pragma.name, "reference")) {
                var types_arg: ?ast.PragmaArgument = null;
                var lib_arg: ?ast.PragmaArgument = null;
                var path_arg: ?ast.PragmaArgument = null;
                var resolution_mode_arg: ?ast.PragmaArgument = null;
                var preserve_arg: ?ast.PragmaArgument = null;
                var no_default_lib_arg: ?ast.PragmaArgument = null;

                for (pragma.args) |arg| {
                    if (std.mem.eql(u8, arg.name, "types")) {
                        types_arg = arg;
                    } else if (std.mem.eql(u8, arg.name, "lib")) {
                        lib_arg = arg;
                    } else if (std.mem.eql(u8, arg.name, "path")) {
                        path_arg = arg;
                    } else if (std.mem.eql(u8, arg.name, "resolution-mode")) {
                        resolution_mode_arg = arg;
                    } else if (std.mem.eql(u8, arg.name, "preserve")) {
                        preserve_arg = arg;
                    } else if (std.mem.eql(u8, arg.name, "no-default-lib")) {
                        no_default_lib_arg = arg;
                    }
                }

                if (no_default_lib_arg != null and std.mem.eql(u8, no_default_lib_arg.?.value, "true")) {
                    // Ignored
                } else if (types_arg) |types| {
                    var parsed: core.ResolutionMode = .None;
                    if (resolution_mode_arg) |mode| {
                        parsed = self.parseResolutionMode(mode.value);
                    }
                    try self.ast.typeReferenceDirectives.append(self.allocator, .{
                        .pos = types.pos,
                        .end = types.end,
                        .fileName = try self.allocator.dupe(u8, types.value),
                        .resolutionMode = parsed,
                        .preserve = (preserve_arg != null and std.mem.eql(u8, preserve_arg.?.value, "true")),
                    });
                } else if (lib_arg) |lib| {
                    try self.ast.libReferenceDirectives.append(self.allocator, .{
                        .pos = lib.pos,
                        .end = lib.end,
                        .fileName = try self.allocator.dupe(u8, lib.value),
                        .resolutionMode = .None,
                        .preserve = (preserve_arg != null and std.mem.eql(u8, preserve_arg.?.value, "true")),
                    });
                } else if (path_arg) |path| {
                    try self.ast.referencedFiles.append(self.allocator, .{
                        .pos = path.pos,
                        .end = path.end,
                        .fileName = try self.allocator.dupe(u8, path.value),
                        .resolutionMode = .None,
                        .preserve = (preserve_arg != null and std.mem.eql(u8, preserve_arg.?.value, "true")),
                    });
                } else {
                    self.parseError("Invalid reference directive syntax");
                }
            } else if (std.mem.eql(u8, pragma.name, "ts-check") or std.mem.eql(u8, pragma.name, "ts-nocheck")) {
                if (self.ast.checkJsDirective == null or pragma.pos > self.ast.checkJsDirective.?.pos) {
                    self.ast.checkJsDirective = .{
                        .enabled = std.mem.eql(u8, pragma.name, "ts-check"),
                        .pos = pragma.pos,
                        .end = pragma.end,
                    };
                }
            }
        }
    }

    fn parseResolutionMode(self: *Parser, mode: []const u8) core.ResolutionMode {
        _ = self;
        if (std.mem.eql(u8, mode, "import")) {
            return .ESNext;
        } else if (std.mem.eql(u8, mode, "require")) {
            return .CommonJS;
        }
        return .None;
    }

    fn collectExternalModuleReferences(self: *Parser, sourceFileIndex: ast_gen.NodeIndex) !void {
        const sourceFileNode = self.ast.getNode(sourceFileIndex).SourceFile;
        const statements = self.ast.getNodeList(sourceFileNode.Statements);
        for (statements) |statement| {
            try self.collectModuleReferences(sourceFileIndex, statement, false);
        }

        const flags = self.ast.getNodeFlags(sourceFileIndex);
        const is_js = self.isJavaScript();
        if ((flags & @import("../ast/ast_utils.zig").NodeFlags.PossiblyContainsDynamicImport) != 0 or is_js) {
            var i: u32 = 1;
            while (i < self.ast.nodes.len) : (i += 1) {
                const node = self.ast.getNode(i);
                if (node == .CallExpression) {
                    const call = node.CallExpression;
                    const expr_kind = self.ast.getNodeKind(call.Expression);
                    if (expr_kind == .ImportKeyword) {
                        const args = self.ast.getNodeList(call.Arguments);
                        if (args.len > 0) {
                            try self.ast.imports.append(self.allocator, args[0]);
                        }
                    } else if (expr_kind == .Identifier) {
                        const id = self.ast.getNode(call.Expression).Identifier;
                        if (std.mem.eql(u8, id.Text, "require")) {
                            const args = self.ast.getNodeList(call.Arguments);
                            if (args.len > 0) {
                                try self.ast.imports.append(self.allocator, args[0]);
                            }
                        }
                    }
                }
            }
        }
    }

    fn collectModuleReferences(self: *Parser, sourceFileIndex: ast_gen.NodeIndex, nodeIndex: ast_gen.NodeIndex, inAmbientModule: bool) !void {
        const node = self.ast.getNode(nodeIndex);
        const is_any_import_reexport = switch (node) {
            .ImportDeclaration, .ImportEqualsDeclaration, .ExportDeclaration, .JSImportDeclaration, .ExportAssignment => true,
            else => false,
        };
        if (is_any_import_reexport) {
            var moduleNameExpr: ast_gen.NodeIndex = 0;
            switch (node) {
                .ImportDeclaration => |n| moduleNameExpr = n.ModuleSpecifier,
                .JSImportDeclaration => |n| moduleNameExpr = n.ModuleSpecifier,
                .ExportDeclaration => |n| moduleNameExpr = n.ModuleSpecifier orelse 0,
                .ImportEqualsDeclaration => |n| {
                    if (self.ast.getNodeKind(n.ModuleReference) == .ExternalModuleReference) {
                        moduleNameExpr = self.ast.getNode(n.ModuleReference).ExternalModuleReference.Expression;
                    }
                },
                else => {},
            }
            if (moduleNameExpr != 0 and self.ast.getNodeKind(moduleNameExpr) == .StringLiteral) {
                const moduleName = self.ast.getNode(moduleNameExpr).StringLiteral.Text;
                const is_relative = std.mem.startsWith(u8, moduleName, "./") or std.mem.startsWith(u8, moduleName, "../") or std.mem.startsWith(u8, moduleName, "/");
                if (moduleName.len > 0 and (!inAmbientModule or !is_relative)) {
                    try self.ast.imports.append(self.allocator, moduleNameExpr);
                    if (self.ast.usesUriStyleNodeCoreModules != .True and self.ast.getNode(sourceFileIndex).SourceFile.EndOfFileToken != 0) {
                        if (std.mem.startsWith(u8, moduleName, "node:")) {
                            self.ast.usesUriStyleNodeCoreModules = .True;
                        } else if (self.ast.usesUriStyleNodeCoreModules == .Unknown) {
                            const unprefixed_core_modules = &[_][]const u8{ "fs", "path", "os", "child_process", "crypto", "http", "https", "net", "stream", "util" };
                            var is_unprefixed_core = false;
                            for (unprefixed_core_modules) |core_mod| {
                                if (std.mem.eql(u8, moduleName, core_mod)) {
                                    is_unprefixed_core = true;
                                    break;
                                }
                            }
                            if (is_unprefixed_core) {
                                self.ast.usesUriStyleNodeCoreModules = .False;
                            }
                        }
                    }
                }
            }
            return;
        }
        if (node == .ModuleDeclaration) {
            const decl = node.ModuleDeclaration;
            const name_kind = self.ast.getNodeKind(decl.name);
            const nameText = if (name_kind == .StringLiteral) self.ast.getNode(decl.name).StringLiteral.Text else (if (name_kind == .Identifier) self.ast.getNode(decl.name).Identifier.Text else "");
            const is_ambient = @import("../ast/ast_utils.zig").isAmbientModule(&self.ast, nodeIndex);
            const is_external = @import("../ast/ast_utils.zig").isExternalModule(&self.ast, sourceFileIndex);
            const is_relative = std.mem.startsWith(u8, nameText, "./") or std.mem.startsWith(u8, nameText, "../") or std.mem.startsWith(u8, nameText, "/");

            if (is_external or (inAmbientModule and !is_relative)) {
                try self.ast.moduleAugmentations.append(self.allocator, decl.name);
            } else if (!inAmbientModule and is_ambient) {
                const name_dup = try self.allocator.dupe(u8, nameText);
                try self.ast.ambientModuleNames.append(self.allocator, name_dup);
                if (decl.Body) |body| {
                    if (self.ast.getNodeKind(body) == .ModuleBlock) {
                        const block = self.ast.getNode(body).ModuleBlock;
                        const block_statements = self.ast.getNodeList(block.Statements);
                        for (block_statements) |statement| {
                            try self.collectModuleReferences(sourceFileIndex, statement, true);
                        }
                    }
                }
            }
        }
    }
};

pub fn parseSourceFile(allocator: std.mem.Allocator, options: ast.SourceFileParseOptions, text: []const u8, scriptKind: core.ScriptKind) anyerror!ast_gen.NodeIndex {
    _ = options;
    var p = Parser.init(allocator, text);
    p.setScriptKind(scriptKind);
    defer p.deinit();
    return p.parseSourceFile();
}
