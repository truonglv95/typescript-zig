const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const kind = @import("../ast/kind.zig");
const scanner_pkg = @import("../scanner/scanner.zig");

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

pub const Parser = struct {
    allocator: std.mem.Allocator,
    scanner: scanner_pkg.Scanner,
    ast: ast.Ast,

    // Trạng thái Parser
    token: kind.Kind,
    parseDiagnosticsCount: u32 = 0,
    lastErrorPos: i32 = -1,
    parsingContexts: u32 = 0,

        pub const Mark = struct {
        scanner: scanner_pkg.Scanner,
        token: kind.Kind,
        nodes_len: usize,
        extraData_len: usize,
        parseDiagnosticsCount: u32,
        lastErrorPos: i32,
    };

    pub fn mark(self: *Parser) Mark {
        return .{
            .scanner = self.scanner,
            .token = self.token,
            .nodes_len = self.ast.nodes.len,
            .extraData_len = self.ast.extraData.items.len,
            .parseDiagnosticsCount = self.parseDiagnosticsCount,
            .lastErrorPos = self.lastErrorPos,
        };
    }

    pub fn rewind(self: *Parser, m: Mark) void {
        self.scanner = m.scanner;
        self.token = m.token;
        self.ast.nodes.len = m.nodes_len;
        self.ast.extraData.items.len = m.extraData_len;
        self.parseDiagnosticsCount = m.parseDiagnosticsCount;
        self.lastErrorPos = m.lastErrorPos;
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

    pub fn isListElement(self: *Parser, parsingContext: ParsingContext, inErrorRecovery: bool) bool {
        switch (parsingContext) {
            .SourceElements, .BlockStatements, .SwitchClauseStatements => {
                // If we're in error recovery, then we don't want to treat ';' as an empty statement.
                return !(self.token == kind.Kind.SemicolonToken and inErrorRecovery) and self.isStartOfStatement();
            },
            .ArgumentExpressions => {
                return self.token == kind.Kind.DotDotDotToken or self.isStartOfExpression();
            },
            .ArrayLiteralMembers => {
                if (self.token == kind.Kind.CommaToken or self.token == kind.Kind.DotToken) return true;
                return self.token == kind.Kind.DotDotDotToken or self.isStartOfExpression();
            },
            .ObjectLiteralMembers => {
                if (self.token == kind.Kind.OpenBracketToken or self.token == kind.Kind.AsteriskToken or self.token == kind.Kind.DotDotDotToken or self.token == kind.Kind.DotToken) return true;
                return self.isLiteralPropertyName();
            },
            .TypeParameters => {
                return self.token == kind.Kind.InKeyword or self.token == kind.Kind.ConstKeyword or self.isIdentifier();
            },
            .Parameters => {
                return self.isStartOfParameter();
            },
            .VariableDeclarations => {
                return self.isIdentifier() or self.token == kind.Kind.OpenBraceToken or self.token == kind.Kind.OpenBracketToken;
            },
            else => return false, // Stubbed for other contexts
        }
    }

    pub fn isListTerminator(self: *Parser, parsingContext: ParsingContext) bool {
        switch (parsingContext) {
            .BlockStatements, .SwitchClauseStatements => return self.token == kind.Kind.CloseBraceToken,
            .VariableDeclarations => return self.token == kind.Kind.InKeyword or self.token == kind.Kind.OfKeyword or self.token == kind.Kind.EqualsGreaterThanToken or self.canParseSemicolon(),
            .ArgumentExpressions => return self.token == kind.Kind.CloseParenToken,
            .ArrayLiteralMembers => return self.token == kind.Kind.CloseBracketToken,
            .ObjectLiteralMembers => return self.token == kind.Kind.CloseBraceToken,
            .TypeParameters => return self.token == kind.Kind.GreaterThanToken,
            .Parameters => return self.token == kind.Kind.CloseParenToken,
            .SourceElements => return self.token == kind.Kind.EndOfFile,
            else => return false,
        }
    }

    pub fn abortParsingListOrMoveToNextToken(self: *Parser, parsingContext: ParsingContext) bool {
        _ = parsingContext; // Stub
        self.parseError("Expected token in delimited list");
        self.nextToken();
        return false;
    }

    pub fn isIdentifierOrKeyword(self: *Parser) bool {
        return self.isIdentifier() or kind.isKeyword(self.token);
    }

    pub fn isLiteralPropertyName(self: *Parser) bool {
        return self.isIdentifierOrKeyword() or self.token == kind.Kind.StringLiteral or self.token == kind.Kind.NumericLiteral;
    }

    pub fn canParseSemicolon(self: *Parser) bool {
        return self.token == kind.Kind.SemicolonToken or self.token == kind.Kind.CloseBraceToken or self.token == kind.Kind.EndOfFile or self.scanner.hasPrecedingLineBreak();
    }

    pub fn isStartOfStatement(self: *Parser) bool {
        switch (self.token) {
            .SemicolonToken, .OpenBraceToken, .VarKeyword, .LetKeyword,
            .ConstKeyword, .IfKeyword, .DoKeyword, .WhileKeyword,
            .ForKeyword, .ContinueKeyword, .BreakKeyword, .ReturnKeyword,
            .WithKeyword, .SwitchKeyword, .ThrowKeyword, .TryKeyword,
            .FunctionKeyword, .ClassKeyword, .DebuggerKeyword, .AtToken => return true,
            else => return self.isStartOfExpression(),
        }
    }

    pub fn isStartOfExpression(self: *Parser) bool {
        if (self.isIdentifier()) return true;
        switch (self.token) {
            .ThisKeyword, .SuperKeyword, .NullKeyword, .TrueKeyword, .FalseKeyword,
            .NumericLiteral, .BigIntLiteral, .StringLiteral, .NoSubstitutionTemplateLiteral,
            .TemplateHead, .OpenParenToken, .OpenBracketToken, .OpenBraceToken,
            .FunctionKeyword, .ClassKeyword, .NewKeyword, .SlashToken, .SlashEqualsToken,
            .PlusToken, .MinusToken, .TildeToken, .ExclamationToken, .DeleteKeyword,
            .TypeOfKeyword, .VoidKeyword, .PlusPlusToken, .MinusMinusToken, .LessThanToken,
            .AwaitKeyword, .YieldKeyword, .ImportKeyword => return true,
            else => return false,
        }
    }

    pub fn isStartOfParameter(self: *Parser) bool {
        return self.token == kind.Kind.AtToken or self.token == kind.Kind.DotDotDotToken or self.isIdentifier() or self.token == kind.Kind.ThisKeyword or self.token == kind.Kind.OpenBracketToken or self.token == kind.Kind.OpenBraceToken;
    }

    pub fn parseDelimitedList(self: *Parser, parsingContext: ParsingContext, comptime parseElement: fn (*Parser) ast_gen.NodeIndex) ast_gen.NodeIndex {
        const saveParsingContexts = self.parsingContexts;
        self.parsingContexts |= @as(u32, 1) << @as(u5, @intCast(@intFromEnum(parsingContext)));
        
        var list = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer list.deinit(self.allocator);

        while (true) {
            if (self.isListElement(parsingContext, false)) {
                const startPos = self.scanner.state.pos;
                const element = parseElement(self);
                if (element == 0) {
                    self.parsingContexts = saveParsingContexts;
                    return 0; // Failed to parse element
                }
                list.append(self.allocator, element) catch return 0;
                
                if (self.parseOptional(kind.Kind.CommaToken)) {
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
                continue;
            }
            if (self.isListTerminator(parsingContext)) {
                break;
            }
            if (self.abortParsingListOrMoveToNextToken(parsingContext)) {
                break;
            }
        }
        
        self.parsingContexts = saveParsingContexts;
        if (list.items.len == 0) return 0;
        return self.ast.pushNodeList(list.items) catch 0;
    }

    pub fn init(allocator: std.mem.Allocator, text: []const u8) Parser {
        var p = Parser{
            .allocator = allocator,
            .scanner = scanner_pkg.Scanner.init(allocator, text),
            .ast = ast.Ast.init(allocator),
            .token = kind.Kind.Unknown,
            .parseDiagnosticsCount = 0,
        };
        // Quét token đầu tiên mồi cho quá trình parse
        p.nextToken();
        return p;
    }

    pub fn deinit(self: *Parser) void {
        self.ast.deinit();
    }

    pub fn nextToken(self: *Parser) void {
        self.token = self.scanner.scan();
    }

    pub fn reScanGreaterThanToken(self: *Parser) kind.Kind {
        self.token = self.scanner.reScanGreaterThanToken();
        return self.token;
    }

    pub fn parseSourceFile(self: *Parser) anyerror!ast_gen.NodeIndex {
        // Trong Typescript-Go:
        // func (p *Parser) parseSourceFileWorker() *ast.SourceFile { ... }

        var statements_arr = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer statements_arr.deinit(self.allocator);

        while (self.token != kind.Kind.EndOfFile) {
            const stmt = try self.parseStatement();
            try statements_arr.append(self.allocator, stmt); 
        }

        const statements = try self.ast.pushNodeList(statements_arr.items);
        const endOfFileToken = try self.ast.pushNode(.{ .EndOfFile = void{} });

        const sourceFileIndex = try self.ast.pushNode(.{ .SourceFile = .{
            .Symbol = 0,
            .Flags = 0,
            .Statements = statements,
            .EndOfFileToken = endOfFileToken,
            .ExternalModuleIndicator = null,
            .CommonJSModuleIndicator = null,
        } });

        var sourceFileNode = self.ast.getNode(sourceFileIndex);
        sourceFileNode.SourceFile.ExternalModuleIndicator = @import("../ast/ast_utils.zig").isFileProbablyExternalModule(&self.ast, sourceFileIndex);
        self.ast.nodes.set(sourceFileIndex, sourceFileNode); 

        return sourceFileIndex;
    }


    pub fn isStartOfDeclaration(self: *Parser) bool {
        if (self.token == kind.Kind.EnumKeyword) {
            return true;
        }
        if (self.token == kind.Kind.DeclareKeyword or self.token == kind.Kind.ModuleKeyword or self.token == kind.Kind.NamespaceKeyword or self.token == kind.Kind.InterfaceKeyword or self.token == kind.Kind.TypeKeyword or self.token == kind.Kind.GlobalKeyword) {
            var tempScanner = self.scanner;
            const next = tempScanner.scan();
            if (next == kind.Kind.Identifier or next == kind.Kind.StringLiteral or kind.isKeyword(next) or next == kind.Kind.OpenBraceToken) {
                if (!tempScanner.hasPrecedingLineBreak()) {
                    return true;
                }
            }
        }
        if (self.token == kind.Kind.ExportKeyword) { 
            var tempScanner = self.scanner;
            const next = tempScanner.scan();
            if (next == kind.Kind.EqualsToken or next == kind.Kind.AsteriskToken or next == kind.Kind.OpenBraceToken or
                next == kind.Kind.DefaultKeyword or next == kind.Kind.AsKeyword or next == kind.Kind.AtToken) {
                return true;
            }
            if (next == kind.Kind.TypeKeyword) {
                const next2 = tempScanner.scan();
                if (next2 == kind.Kind.AsteriskToken or next2 == kind.Kind.OpenBraceToken) {
                    return true;
                }
                if ((kind.isKeyword(next2) or next2 == kind.Kind.Identifier) and !tempScanner.hasPrecedingLineBreak()) {
                    return true;
                }
            }
        }
        if (self.isModifierKind(self.token)) {
            return true;
        }
        return false;
    }

    pub fn parseStatement(self: *Parser) anyerror!ast_gen.NodeIndex { 
        switch (self.token) {
            kind.Kind.SemicolonToken => return self.parseEmptyStatement(),
            kind.Kind.OpenBraceToken => return self.parseBlock(),
            kind.Kind.VarKeyword => return self.parseVariableStatement(null, 0),
            kind.Kind.LetKeyword => {
                // TODO: if (p.isLetDeclaration()) return p.parseVariableStatement()
                return self.parseVariableStatement(null, 0);
            },
            kind.Kind.UsingKeyword => {
                if (self.isUsingDeclaration()) {
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
            kind.Kind.ForKeyword => return self.parseForStatement(), // TODO: parseForOrForInOrForOfStatement
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
        const startPos = self.scanner.state.pos;
        const expr = try @import("expression.zig").parseExpression(self);
        
        self.parseSemicolon();

        if (self.scanner.state.pos == startPos) {
            // Error recovery: Nếu chưa tiêu thụ được token nào, ép buộc nhảy qua token tiếp theo để tránh vòng lặp vô hạn
            self.nextToken();
        }

        return self.ast.pushNode(.{ .ExpressionStatement = .{
            .Flags = 0,
            .Expression = expr,
        } });
    }

    pub fn parseEmptyStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        self.parseSemicolon();
        return self.ast.pushNode(.{ .EmptyStatement = .{ .Flags = 0 } });
    }

    pub fn parseDoStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.DoKeyword);
        const statement = try self.parseStatement();
        _ = self.parseExpected(kind.Kind.WhileKeyword);
        _ = self.parseExpected(kind.Kind.OpenParenToken);
        const expression = try @import("expression.zig").parseExpression(self);
        _ = self.parseExpected(kind.Kind.CloseParenToken);
        _ = self.parseOptional(kind.Kind.SemicolonToken);
        return self.ast.pushNode(.{ .DoStatement = .{ .Flags = 0, .Statement = statement, .Expression = expression } });
    }

    pub fn parseContinueStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.ContinueKeyword);
        var label: ?ast_gen.NodeIndex = null;
        if (!self.isSemicolon()) {
            if (self.isIdentifier()) {
                label = try self.parseIdentifier();
            }
        }
        self.parseSemicolon();
        return self.ast.pushNode(.{ .ContinueStatement = .{ .Flags = 0, .Label = label } });
    }

    pub fn parseBreakStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.BreakKeyword);
        var label: ?ast_gen.NodeIndex = null;
        if (!self.isSemicolon()) {
            if (self.isIdentifier()) {
                label = try self.parseIdentifier();
            }
        }
        self.parseSemicolon();
        return self.ast.pushNode(.{ .BreakStatement = .{ .Flags = 0, .Label = label } });
    }

    pub fn parseWithStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.WithKeyword);
        _ = self.parseExpected(kind.Kind.OpenParenToken);
        const expression = try @import("expression.zig").parseExpression(self);
        _ = self.parseExpected(kind.Kind.CloseParenToken);
        const statement = try self.parseStatement();
        return self.ast.pushNode(.{ .WithStatement = .{ .Flags = 0, .Expression = expression, .Statement = statement } });
    }

    pub fn parseCaseBlock(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.OpenBraceToken);
        var clauses_arr = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer clauses_arr.deinit(self.allocator);
        while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
            const clause = try self.parseCaseOrDefaultClause();
            try clauses_arr.append(self.allocator, clause);
        }
        const clauses = try self.ast.pushNodeList(clauses_arr.items);
        _ = self.parseExpected(kind.Kind.CloseBraceToken);
        return self.ast.pushNode(.{ .CaseBlock = .{ .Flags = 0, .Clauses = clauses } });
    }

    pub fn parseCaseOrDefaultClause(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.token == kind.Kind.CaseKeyword) {
            self.nextToken();
            const expression = try @import("expression.zig").parseExpression(self);
            _ = self.parseExpected(kind.Kind.ColonToken);
            
            var statements_arr = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
            defer statements_arr.deinit(self.allocator);
            while (self.token != kind.Kind.CaseKeyword and self.token != kind.Kind.DefaultKeyword and self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
                const stmt = try self.parseStatement();
                try statements_arr.append(self.allocator, stmt); 
            }
            const statements = try self.ast.pushNodeList(statements_arr.items);
            return self.ast.pushNode(.{ .CaseClause = .{ .Flags = 0, .Expression = expression, .Statements = statements } });
        } else {
            _ = self.parseExpected(kind.Kind.DefaultKeyword);
            _ = self.parseExpected(kind.Kind.ColonToken);
            
            var statements_arr = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
            defer statements_arr.deinit(self.allocator);
            while (self.token != kind.Kind.CaseKeyword and self.token != kind.Kind.DefaultKeyword and self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
                const stmt = try self.parseStatement();
                try statements_arr.append(self.allocator, stmt); 
            }
            const statements = try self.ast.pushNodeList(statements_arr.items);
            return self.ast.pushNode(.{ .DefaultClause = .{ .Flags = 0, .Expression = 0, .Statements = statements } }); // 0 for missing expression
        }
    }

    pub fn parseSwitchStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.SwitchKeyword);
        _ = self.parseExpected(kind.Kind.OpenParenToken);
        const expression = try @import("expression.zig").parseExpression(self);
        _ = self.parseExpected(kind.Kind.CloseParenToken);
        const caseBlock = try self.parseCaseBlock();
        return self.ast.pushNode(.{ .SwitchStatement = .{ .Flags = 0, .Expression = expression, .CaseBlock = caseBlock } });
    }

    pub fn parseThrowStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.ThrowKeyword);
        var expression: ast_gen.NodeIndex = 0;
        if (!self.scanner.hasPrecedingLineBreak()) {
            expression = try @import("expression.zig").parseExpression(self);
        } else {
            // stub missing identifier
        }
        self.parseSemicolon();
        return self.ast.pushNode(.{ .ThrowStatement = .{ .Flags = 0, .Expression = expression } });
    }

    pub fn parseCatchClause(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.CatchKeyword);
        var variableDeclaration: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.OpenParenToken)) {
            variableDeclaration = try self.parseVariableDeclaration();
            _ = self.parseExpected(kind.Kind.CloseParenToken);
        }
        const block = try self.parseBlock();
        return self.ast.pushNode(.{ .CatchClause = .{ .Flags = 0, .VariableDeclaration = variableDeclaration, .Block = block } });
    }

    pub fn parseTryStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
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
        return self.ast.pushNode(.{ .TryStatement = .{ .Flags = 0, .TryBlock = tryBlock, .CatchClause = catchClause, .FinallyBlock = finallyBlock } });
    }

    pub fn parseDebuggerStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        self.nextToken();
        self.parseSemicolon();
        return self.ast.pushNode(.{ .DebuggerStatement = .{ .Flags = 0 } }); // stub
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
        var modifierList = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer modifierList.deinit(self.allocator);
        
        while (true) {
            if (self.token == kind.Kind.ConstKeyword or self.token == kind.Kind.InKeyword or self.token == kind.Kind.OutKeyword) {
                const modNode = try self.ast.pushNode(.{ .Unknown = void{} });
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

        return self.ast.pushNode(.{ .TypeParameter = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = 0,
            .name = name,
            .Constraint = constraint,
            .Expression = null,
            .DefaultType = defaultType,
        } });
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
                return self.ast.pushNode(.{ .ExportAssignment = .{
            .Symbol = 0,
                    .Flags = 0,
                    .modifiers = modifiers,
                    .modifierFlags = modifierFlags,
                    .IsExportEquals = 0,
                    .Type = 0, // Should be null or 0? ast_gen says optional NodeIndex or 0? Wait, it's 0 usually? Or null? Let's check.
                    // Actually, I'll just use what I had in parseExportDeclaration
                    .Expression = expression,
                } });
            },
            else => {
                // Return a MissingDeclaration if nothing matched
                self.nextToken();
                return self.ast.pushNode(.{ .Unknown = void{} });
            }
        }
    }

    pub fn parseTypeMember(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.token == kind.Kind.OpenParenToken or self.token == kind.Kind.LessThanToken) {
            const typeParameters = try self.parseTypeParameters();
            const parameters = try self.parseParameters();
            const returnType = try self.parseReturnTypeAnnotation();
            self.parseTypeMemberSemicolon();
            return self.ast.pushNode(.{ .MethodSignature = .{
                .Flags = 0,
                .Symbol = 0,
                .modifiers = null,
                .modifierFlags = 0,
                .name = 0,
                .PostfixToken = null,
                .TypeParameters = typeParameters,
                .Parameters = parameters,
                .Type = returnType,
                .FullSignature = null,
            } });
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
        
        const name = try self.parsePropertyName();
        
        var questionToken: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.QuestionToken)) {
            questionToken = try self.ast.pushNode(.{ .Unknown = void{} });
        }
        
        if (self.token == kind.Kind.OpenParenToken or self.token == kind.Kind.LessThanToken) {
            const typeParameters = try self.parseTypeParameters();
            const parameters = try self.parseParameters();
            const returnType = try self.parseReturnTypeAnnotation();
            self.parseTypeMemberSemicolon();
            if (isGet) {
                return self.ast.pushNode(.{ .GetAccessor = .{
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
            } else if (isSet) {
                return self.ast.pushNode(.{ .SetAccessor = .{
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
            } else {
                return self.ast.pushNode(.{ .MethodSignature = .{
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
            }
        } else {
            const typeNode = try self.parseTypeAnnotation();
            var initializer: ?ast_gen.NodeIndex = null;
            if (self.parseOptional(kind.Kind.EqualsToken)) {
                initializer = try @import("expression.zig").parseAssignmentExpressionOrHigher(self);
            }
            self.parseTypeMemberSemicolon();
            return self.ast.pushNode(.{ .PropertySignature = .{
                .Flags = 0,
                .Symbol = 0,
                .modifiers = modifiers,
                .modifierFlags = modifierFlags,
                .name = name,
                .PostfixToken = questionToken,
                .Type = typeNode orelse 0,
                .Initializer = initializer orelse 0,
            } });
        }
    }

    pub fn parseInterfaceDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
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
        const members = try self.ast.pushNodeList(members_arr.items);

        return self.ast.pushNode(.{ .InterfaceDeclaration = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .name = name,
            .TypeParameters = typeParameters,
            .HeritageClauses = heritageClauses,
            .Members = members,
        } });
    }

    pub fn parseTypeAliasDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.TypeKeyword);
        const name = try self.parseIdentifier();
        const typeParameters = try self.parseTypeParameters();
        _ = self.parseExpected(kind.Kind.EqualsToken);
        const typeNode = try self.parseType();
        self.parseSemicolon();
        
        return self.ast.pushNode(.{ .TypeAliasDeclaration = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .name = name,
            .TypeParameters = typeParameters,
            .Type = typeNode,
        } });
    }

    pub fn parseEnumDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
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
        const members = try self.ast.pushNodeList(members_arr.items);

        return self.ast.pushNode(.{ .EnumDeclaration = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .name = name,
            .Members = members,
        } });
    }

    pub fn parseEnumMember(self: *Parser) anyerror!ast_gen.NodeIndex {
        const name = try self.parsePropertyName();
        var initializer: ?ast_gen.NodeIndex = null;
        if (self.token == kind.Kind.EqualsToken) {
            self.nextToken();
            initializer = try @import("expression.zig").parseAssignmentExpressionOrHigher(self);
        }
        return self.ast.pushNode(.{ .EnumMember = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = null,
            .modifierFlags = 0,
            .name = name,
            .PostfixToken = null,
            .Initializer = initializer,
        } });
    }

    fn parseModuleBlock(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.OpenBraceToken);

        var statements_arr = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer statements_arr.deinit(self.allocator);

        while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
            const stmt = try self.parseStatement();
            try statements_arr.append(self.allocator, stmt); 
        }

        const statements = try self.ast.pushNodeList(statements_arr.items);
        _ = self.parseExpected(kind.Kind.CloseBraceToken);

        return self.ast.pushNode(.{ .ModuleBlock = .{
            .Flags = 0,
            .Statements = statements,
        } });
    }

    pub fn parseModuleDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        var keyword: ast_gen.NodeIndex = 0;
        var name: ?ast_gen.NodeIndex = null;
        if (self.token == kind.Kind.GlobalKeyword) {
            keyword = try self.ast.pushNode(.{ .Unknown = void{} });
            name = try self.parseIdentifier(); // global is parsed as identifier
        } else {
            keyword = try self.ast.pushNode(.{ .Unknown = void{} });
            if (!self.parseOptional(kind.Kind.NamespaceKeyword)) {
                _ = self.parseExpected(kind.Kind.ModuleKeyword);
                if (self.token == kind.Kind.StringLiteral) {
                    name = try @import("expression.zig").parseLiteralExpression(self);
                }
            }
            if (name == null) {
                name = try self.parseIdentifier();
            }
        }
        
        var body: ?ast_gen.NodeIndex = null;
        if (self.token == kind.Kind.OpenBraceToken) {
            body = try self.parseModuleBlock();
        } else {
            self.parseSemicolon();
        }
        return self.ast.pushNode(.{ .ModuleDeclaration = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .AsteriskToken = null,
            .Body = body,
            .Keyword = keyword,
            .name = name.?,
        } });
    }

    pub fn parseImportDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.ImportKeyword);
        
        var isTypeOnly: u32 = 0;
        var phaseModifier: ?ast_gen.NodeIndex = null;
        
        if (self.token == kind.Kind.TypeKeyword) {
            var tempScanner = self.scanner;
            const nextTok = tempScanner.scan();
            if (nextTok == kind.Kind.AsteriskToken or nextTok == kind.Kind.OpenBraceToken or ((nextTok == kind.Kind.Identifier or kind.isKeyword(nextTok)) and nextTok != kind.Kind.FromKeyword and nextTok != kind.Kind.EqualsToken and nextTok != kind.Kind.CommaToken)) {
                isTypeOnly = 1;
                phaseModifier = try self.ast.pushNode(.{ .Unknown = void{} });
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
                        moduleReference = try @import("expression.zig").parseExpression(self);
                    }
                    _ = self.parseExpected(kind.Kind.CloseParenToken);
                    self.parseSemicolon();
                    return self.ast.pushNode(.{ .ImportEqualsDeclaration = .{
                        .Symbol = 0,
                        .Flags = 0,
                        .modifiers = modifiers,
                        .modifierFlags = modifierFlags,
                        .IsTypeOnly = isTypeOnly,
                        .name = name,
                        .ModuleReference = moduleReference,
                    } });
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
                    return self.ast.pushNode(.{ .ImportEqualsDeclaration = .{
                        .Symbol = 0,
                        .Flags = 0,
                        .modifiers = modifiers,
                        .modifierFlags = modifierFlags,
                        .IsTypeOnly = isTypeOnly,
                        .name = name,
                        .ModuleReference = moduleReference,
                    } });
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

        // Skip import attributes
        if (self.token == kind.Kind.AssertKeyword or self.token == kind.Kind.WithKeyword or (self.token == kind.Kind.Identifier and std.mem.eql(u8, self.scanner.state.tokenValue, "with"))) {
            self.nextToken();
            if (self.token == kind.Kind.OpenBraceToken) {
                var braceCount: u32 = 1;
                self.nextToken();
                while (braceCount > 0 and self.token != kind.Kind.EndOfFile) {
                    if (self.token == kind.Kind.OpenBraceToken) braceCount += 1;
                    if (self.token == kind.Kind.CloseBraceToken) braceCount -= 1;
                    self.nextToken();
                }
            }
        }

        self.parseSemicolon();
        return self.ast.pushNode(.{ .ImportDeclaration = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .ImportClause = importClause orelse 0,
            .ModuleSpecifier = moduleSpecifier,
            .Attributes = null,
        } });
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
            }});
        } else if (self.token == kind.Kind.OpenBraceToken) {
            // NamedImports
            self.nextToken();
            var elements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
            defer elements.deinit(self.allocator);
            
            while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
                var propertyName: ?ast_gen.NodeIndex = null;
                var specName = try self.parseIdentifierName();
                
                if (self.token == kind.Kind.AsKeyword) {
                    self.nextToken();
                    propertyName = specName;
                    specName = try self.parseIdentifier();
                }

                const specifier = try self.ast.pushNode(.{ .ImportSpecifier = .{
                    .Symbol = 0,
                    .PropertyName = propertyName,
                    .name = specName,
                    .Flags = 0,
                    .IsTypeOnly = 0,
                }});
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
            }});
        }

        return self.ast.pushNode(.{ .ImportClause = .{
            .Symbol = 0,
            .PhaseModifier = phaseModifier,
            .name = name,
            .NamedBindings = namedBindings,
            .Flags = 0,
        }});
    }

    pub fn parseExportDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.ExportKeyword);
        if (self.token == kind.Kind.DefaultKeyword) {
            self.nextToken();
            const expression = try @import("expression.zig").parseExpression(self);
            self.parseSemicolon();
            return self.ast.pushNode(.{ .ExportAssignment = .{
                .Symbol = 0,
                .Flags = 0,
                .modifiers = modifiers,
                .modifierFlags = modifierFlags,
                .IsExportEquals = 0,
                .Type = 0,
                .Expression = expression,
            } });
        } else if (self.token == kind.Kind.EqualsToken) {
            self.nextToken();
            const expression = try @import("expression.zig").parseExpression(self);
            self.parseSemicolon();
            return self.ast.pushNode(.{ .ExportAssignment = .{
                .Symbol = 0,
                .Flags = 0,
                .modifiers = modifiers,
                .modifierFlags = modifierFlags,
                .IsExportEquals = 1,
                .Type = 0,
                .Expression = expression,
            } });
        } else {
            var exportClause: ?ast_gen.NodeIndex = null;
            var isTypeOnly: u1 = 0;
            if (self.parseOptional(kind.Kind.TypeKeyword)) {
                isTypeOnly = 1;
            }
            if (self.token == kind.Kind.OpenBraceToken) {
                self.nextToken();
                var elements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
                while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
                    const startPos = self.scanner.state.pos;
                    const nameNode = try self.parseIdentifierName();
                    const specifier = try self.ast.pushNode(.{ .ExportSpecifier = .{
                        .Flags = 0,
                        .Symbol = 0,
                        .name = nameNode,
                        .PropertyName = null,
                        .IsTypeOnly = 0,
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

            // Skip import attributes
            if (self.token == kind.Kind.AssertKeyword or self.token == kind.Kind.WithKeyword or (self.token == kind.Kind.Identifier and std.mem.eql(u8, self.scanner.state.tokenValue, "with"))) {
                self.nextToken();
                if (self.token == kind.Kind.OpenBraceToken) {
                    var braceCount: u32 = 1;
                    self.nextToken();
                    while (braceCount > 0 and self.token != kind.Kind.EndOfFile) {
                        if (self.token == kind.Kind.OpenBraceToken) braceCount += 1;
                        if (self.token == kind.Kind.CloseBraceToken) braceCount -= 1;
                        self.nextToken();
                    }
                }
            }

            self.parseSemicolon();
            return self.ast.pushNode(.{ .ExportDeclaration = .{
                .Symbol = 0,
                .Flags = 0,
                .modifiers = modifiers,
                .modifierFlags = modifierFlags,
                .IsTypeOnly = isTypeOnly,
                .ExportClause = exportClause orelse 0,
                .ModuleSpecifier = moduleSpecifier,
                .Attributes = null,
            } });
        }
    }

    pub fn isSemicolon(self: *Parser) bool {
        return self.token == kind.Kind.SemicolonToken or self.token == kind.Kind.CloseBraceToken or self.token == kind.Kind.EndOfFile or self.scanner.hasPrecedingLineBreak();
    }

    pub fn parseVariableStatement(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        const declarationList = try self.parseVariableDeclarationList();
        self.parseSemicolon();

        return self.ast.pushNode(.{ .VariableStatement = .{
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .DeclarationList = declarationList,
        } });
    }

    pub fn parseVariableDeclarationList(self: *Parser) anyerror!ast_gen.NodeIndex {
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
        } else if (self.token == kind.Kind.VarKeyword) {
            self.nextToken();
        }

        const declarations = self.parseDelimitedList(.VariableDeclarations, parseVariableDeclarationWrapper);

        return self.ast.pushNode(.{ .VariableDeclarationList = .{
            .Flags = flags,
            .Declarations = declarations,
        } });
    }

    pub fn parseObjectBindingElement(self: *Parser) anyerror!ast_gen.NodeIndex {
        var dotDotDotToken: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.DotDotDotToken)) {
            dotDotDotToken = try self.ast.pushNode(.{ .Unknown = void{} });
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
        
        return self.ast.pushNode(.{ .BindingElement = .{
            .Symbol = 0,
            .Flags = 0,
            .DotDotDotToken = dotDotDotToken,
            .PropertyName = propertyName,
            .name = name.?,
            .Initializer = initializer,
        } });
    }

    pub fn parseArrayBindingElement(self: *Parser) anyerror!ast_gen.NodeIndex {
        var dotDotDotToken: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.DotDotDotToken)) {
            dotDotDotToken = try self.ast.pushNode(.{ .Unknown = void{} });
        }
        const name = try self.parseIdentifierOrPattern();
        
        var initializer: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.EqualsToken)) {
            initializer = try @import("expression.zig").parseAssignmentExpressionOrHigher(self);
        }
        
        return self.ast.pushNode(.{ .BindingElement = .{
            .Symbol = 0,
            .Flags = 0,
            .DotDotDotToken = dotDotDotToken,
            .PropertyName = null,
            .name = name,
            .Initializer = initializer,
        } });
    }

    pub fn parseObjectBindingPattern(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.OpenBraceToken);
        var elements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer elements.deinit(self.allocator);
        
        while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
            const startPos = self.scanner.state.pos;
            const element = try self.parseObjectBindingElement();
            try elements.append(self.allocator, element);
            
            if (self.scanner.state.pos == startPos) {
                self.nextToken();
            }
            if (!self.parseOptional(kind.Kind.CommaToken)) {
                break;
            }
        }
        _ = self.parseExpected(kind.Kind.CloseBraceToken);
        const elementsList = try self.ast.pushNodeList(elements.items);
        return self.ast.pushNode(.{ .ObjectBindingPattern = .{ .Flags = 0, .Elements = elementsList } });
    }

    pub fn parseArrayBindingPattern(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.OpenBracketToken);
        var elements = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer elements.deinit(self.allocator);
        
        while (self.token != kind.Kind.CloseBracketToken and self.token != kind.Kind.EndOfFile) {
            if (self.token == kind.Kind.CommaToken) {
                const omitted = try self.ast.pushNode(.{ .OmittedExpression = .{ .Flags = 0 } });
                try elements.append(self.allocator, omitted);
                self.nextToken();
                continue;
            }
            
            const startPos = self.scanner.state.pos;
            const element = try self.parseArrayBindingElement();
            try elements.append(self.allocator, element);
            
            if (self.scanner.state.pos == startPos) {
                self.nextToken();
            }
            if (!self.parseOptional(kind.Kind.CommaToken)) {
                break;
            }
        }
        _ = self.parseExpected(kind.Kind.CloseBracketToken);
        const elementsList = try self.ast.pushNodeList(elements.items);
        return self.ast.pushNode(.{ .ArrayBindingPattern = .{ .Flags = 0, .Elements = elementsList } });
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
        const name = try self.parseIdentifierOrPattern();
        const nameNode = self.ast.getNode(name);
        if (nameNode == .Identifier) {
            std.debug.print("Parsing var: {s} (errors so far: {d})\n", .{nameNode.Identifier.Text, self.parseDiagnosticsCount});
        }

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

        return self.ast.pushNode(.{
            .VariableDeclaration = .{
            .Symbol = 0,
                .Flags = 0,
                .name = name,
                .ExclamationToken = exclamationToken,
                .Type = typeNode,
                .Initializer = initializer,
            },
        });
    }

    pub fn parseVariableDeclarationWrapper(self: *Parser) ast_gen.NodeIndex {
        return self.parseVariableDeclaration() catch self.ast.pushNode(.{ .Unknown = void{} }) catch 0;
    }

    pub fn parseIfStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.IfKeyword);
        _ = self.parseExpected(kind.Kind.OpenParenToken);
        const expression = try @import("expression.zig").parseExpression(self);
        _ = self.parseExpected(kind.Kind.CloseParenToken);

        const thenStatement = try self.parseStatement();

        var elseStatement: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.ElseKeyword)) {
            elseStatement = try self.parseStatement();
        }

        return self.ast.pushNode(.{ .IfStatement = .{
            .Flags = 0,
            .Expression = expression,
            .ThenStatement = thenStatement,
            .ElseStatement = elseStatement,
        } });
    }

    pub fn parseReturnStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.ReturnKeyword);

        var expression: ?ast_gen.NodeIndex = null;
        if (self.token != kind.Kind.SemicolonToken and self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile and !self.scanner.hasPrecedingLineBreak()) {
            expression = try @import("expression.zig").parseExpression(self);
        }
        self.parseSemicolon();

        return self.ast.pushNode(.{ .ReturnStatement = .{
            .Flags = 0,
            .Expression = expression,
        } });
    }

    pub fn parseBlock(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.OpenBraceToken);
        const multiLine = if (self.scanner.hasPrecedingLineBreak()) @as(u32, 1) else 0;

        var statements_arr = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer statements_arr.deinit(self.allocator);

        while (self.token != kind.Kind.CloseBraceToken and self.token != kind.Kind.EndOfFile) {
            const stmt = try self.parseStatement();
            try statements_arr.append(self.allocator, stmt); 
        }

        const statements = try self.ast.pushNodeList(statements_arr.items);
        _ = self.parseExpected(kind.Kind.CloseBraceToken);

        return self.ast.pushNode(.{ .Block = .{
            .Flags = 0,
            .Statements = statements,
            .MultiLine = multiLine,
        } });
    }

    pub fn parseWhileStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.WhileKeyword);
        _ = self.parseExpected(kind.Kind.OpenParenToken);
        const expression = try @import("expression.zig").parseExpression(self);
        _ = self.parseExpected(kind.Kind.CloseParenToken);

        const statement = try self.parseStatement();

        return self.ast.pushNode(.{ .WhileStatement = .{
            .Flags = 0,
            .Statement = statement,
            .Expression = expression,
        } });
    }

    pub fn parseForStatement(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.ForKeyword);
        var awaitToken: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.AwaitKeyword)) {
            awaitToken = try self.ast.pushNode(.{ .Unknown = void{} });
        }
        
        _ = self.parseExpected(kind.Kind.OpenParenToken);

        var initializer: ?ast_gen.NodeIndex = null;
        if (self.token != kind.Kind.SemicolonToken) {
            if (self.token == kind.Kind.LetKeyword or self.token == kind.Kind.ConstKeyword or self.token == kind.Kind.VarKeyword) {
                initializer = try self.parseVariableDeclarationList();
            } else {
                initializer = try @import("expression.zig").parseExpression(self);
            }
        }
        
        if (self.parseOptional(kind.Kind.InKeyword)) {
            const expression = try @import("expression.zig").parseExpression(self);
            _ = self.parseExpected(kind.Kind.CloseParenToken);
            const statement = try self.parseStatement();
            
            return self.ast.pushNode(.{ .ForInStatement = .{
                .Flags = 0,
                .AwaitModifier = awaitToken,
                .Initializer = initializer orelse 0, // Should not be null for ForIn, but parser handles errors
                .Expression = expression,
                .Statement = statement,
            } });
        } else if (self.parseOptional(kind.Kind.OfKeyword)) {
            const expression = try @import("expression.zig").parseAssignmentExpressionOrHigher(self);
            _ = self.parseExpected(kind.Kind.CloseParenToken);
            const statement = try self.parseStatement();
            
            return self.ast.pushNode(.{ .ForOfStatement = .{
                .Flags = 0,
                .AwaitModifier = awaitToken,
                .Initializer = initializer orelse 0,
                .Expression = expression,
                .Statement = statement,
            } });
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

        return self.ast.pushNode(.{ .ForStatement = .{
            .Flags = 0,
            .Statement = statement,
            .Initializer = initializer,
            .Condition = condition,
            .Incrementor = incrementor,
        } });
    }

    pub fn parseParameter(self: *Parser) anyerror!ast_gen.NodeIndex {
        const modifiers = try self.parseModifiers();
        const modifierFlags = self.modifiersToFlags(modifiers);

        var dotDotDotToken: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.DotDotDotToken)) {
            dotDotDotToken = try self.ast.pushNode(.{ .Unknown = void{} });
        }

        // Handle `this` as a special parameter name (e.g., `this: T`)
        const paramName = if (self.token == kind.Kind.ThisKeyword) blk: {
            const nameNode = try self.ast.pushNode(.{ .Identifier = .{ .Flags = 0, .Text = "this" } });
            self.nextToken();
            break :blk nameNode;
        } else try self.parseIdentifierOrPattern();

        var questionToken: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.QuestionToken)) {
            questionToken = try self.ast.pushNode(.{ .Unknown = void{} });
        }

        const paramType = try self.parseTypeAnnotation();
        
        var initializer: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.EqualsToken)) {
            initializer = try @import("expression.zig").parseAssignmentExpressionOrHigher(self);
        }

        return self.ast.pushNode(.{ .Parameter = .{
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
        _ = self.parseExpected(kind.Kind.FunctionKeyword);
        var asteriskToken: ?ast_gen.NodeIndex = null;
        if (self.token == kind.Kind.AsteriskToken) {
            asteriskToken = try self.ast.pushNode(.{ .Unknown = void{} });
            self.nextToken();
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

        return self.ast.pushNode(.{ .FunctionDeclaration = .{
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
    }

    pub fn parseFunctionExpression(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.FunctionKeyword);
        var asteriskToken: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.AsteriskToken)) {
            asteriskToken = try self.ast.pushNode(.{ .Unknown = void{} });
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
        
        return self.ast.pushNode(.{ .FunctionExpression = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = null,
            .modifierFlags = 0,
            .TypeParameters = typeParameters,
            .Parameters = parameters,
            .Type = returnType,
            .FullSignature = null,
            .AsteriskToken = asteriskToken,
            .Body = body,
            .name = name,
        } });
    }

    pub fn parseDecorator(self: *Parser) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.AtToken);
        const expr = try @import("expression.zig").parseLeftHandSideExpressionOrHigher(self);
        return self.ast.pushNode(.{ .Decorator = .{
            .Flags = 0,
            .Expression = expr,
        } });
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
                    else => .{ .Unknown = void{} },
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

    fn isUsingDeclaration(self: *Parser) bool {
        var tempScanner = self.scanner;
        const next = tempScanner.scan();
        if (tempScanner.hasPrecedingLineBreak()) {
            return false;
        }
        return next == kind.Kind.Identifier or next == kind.Kind.OpenBraceToken or next == kind.Kind.OpenBracketToken;
    }

    fn isModifierKind(self: *Parser, token: kind.Kind) bool {
        switch (token) {
            kind.Kind.PublicKeyword,
            kind.Kind.PrivateKeyword,
            kind.Kind.ProtectedKeyword,
            kind.Kind.ReadonlyKeyword,
            kind.Kind.StaticKeyword,
            kind.Kind.AbstractKeyword,
            kind.Kind.AsyncKeyword,
            kind.Kind.DeclareKeyword,
            kind.Kind.OverrideKeyword,
            kind.Kind.AccessorKeyword => return true,
            
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
        // Accessors do not have type parameters in TS, but we can parse them just in case or skip
        const parameters = try self.parseParameters();
        const returnType = try self.parseReturnTypeAnnotation();
        var body: ?ast_gen.NodeIndex = null;
        if (self.token == kind.Kind.OpenBraceToken) {
            body = try self.parseBlock();
        } else {
            self.parseSemicolon();
        }
        if (isGetAccessor) {
            return self.ast.pushNode(.{ .GetAccessor = .{ .Symbol = 0, .Flags = 0, .modifiers = modifiers, .modifierFlags = modifierFlags, .name = memberName, .Parameters = parameters, .Type = returnType, .Body = body, .AsteriskToken = null, .PostfixToken = null, .TypeParameters = null, .FullSignature = null } });
        } else {
            return self.ast.pushNode(.{ .SetAccessor = .{ .Symbol = 0, .Flags = 0, .modifiers = modifiers, .modifierFlags = modifierFlags, .name = memberName, .Parameters = parameters, .Type = returnType, .Body = body, .AsteriskToken = null, .PostfixToken = null, .TypeParameters = null, .FullSignature = null } });
        }
    }

    pub fn parseClassElement(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.token == kind.Kind.SemicolonToken) {
            self.nextToken();
            return self.ast.pushNode(.{ .SemicolonClassElement = .{
            .Symbol = 0,
                .Flags = 0,
            } });
        }
        
        const modifiers = try self.parseModifiersEx(true);
        const modifierFlags = self.modifiersToFlags(modifiers);
        
        if (self.token == kind.Kind.StaticKeyword and self.peekNextToken() == kind.Kind.OpenBraceToken) {
            self.nextToken(); // consume static
            const body = try self.parseBlock();
            return self.ast.pushNode(.{ .ClassStaticBlockDeclaration = .{
                .Flags = 0,
                .Symbol = 0,
                .modifiers = modifiers,
                .modifierFlags = modifierFlags,
                .Body = body,
            } });
        }
        
        if (self.token == kind.Kind.GetKeyword and self.lookAheadAccessor()) {
            self.nextToken();
            return self.parseAccessorDeclaration(modifiers, modifierFlags, true);
        }
        if (self.token == kind.Kind.SetKeyword and self.lookAheadAccessor()) {
            self.nextToken();
            return self.parseAccessorDeclaration(modifiers, modifierFlags, false);
        }

        // Simple property or method declaration for now.
        const memberName = try self.parsePropertyName();
        
        var postfixToken: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.QuestionToken)) {
            postfixToken = try self.ast.pushNode(.{ .Unknown = void{} });
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
            
            return self.ast.pushNode(.{ .MethodDeclaration = .{
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
        } else {
            // Property
            if (postfixToken == null and !self.scanner.hasPrecedingLineBreak()) {
                if (self.parseOptional(kind.Kind.ExclamationToken)) {
                    postfixToken = try self.ast.pushNode(.{ .Unknown = void{} });
                }
            }
            const typeNode = try self.parseTypeAnnotation();
            
            var initializer: ?ast_gen.NodeIndex = null;
            if (self.parseOptional(kind.Kind.EqualsToken)) {
                initializer = try @import("expression.zig").parseAssignmentExpressionOrHigher(self);
            }
            self.parseSemicolon();
            
            return self.ast.pushNode(.{ .PropertyDeclaration = .{
            .Symbol = 0,
                .Flags = 0,
                .modifiers = modifiers,
                .modifierFlags = modifierFlags,
                .name = memberName,
                .PostfixToken = postfixToken,
                .Type = typeNode,
                .Initializer = initializer,
            } });
        }
    }


    pub fn parseClassExpression(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32) anyerror!ast_gen.NodeIndex {
        _ = self.parseExpected(kind.Kind.ClassKeyword);
        var name: ?ast_gen.NodeIndex = null;
        if (self.isIdentifier()) {
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
        const members = try self.ast.pushNodeList(members_arr.items);

        return self.ast.pushNode(.{ .ClassExpression = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .name = name orelse 0,
            .TypeParameters = typeParameters,
            .HeritageClauses = heritageClauses orelse 0,
            .Members = members,
        } });
    }

    pub fn parseExpressionWithTypeArguments(self: *Parser) anyerror!ast_gen.NodeIndex {
        const expression = try @import("expression.zig").parseLeftHandSideExpressionOrHigher(self);
        var typeArguments: ?ast_gen.NodeListIndex = null;
        if (self.token == kind.Kind.LessThanToken) {
            typeArguments = try self.parseTypeArguments();
        }
        
        if (typeArguments != null) {
            return self.ast.pushNode(.{ .ExpressionWithTypeArguments = .{ .Flags = 0, .Expression = expression, .TypeArguments = typeArguments } });
        }
        return expression;
    }

    pub fn isStartOfLeftHandSideExpression(self: *Parser) bool {
        return switch (self.token) {
            kind.Kind.ThisKeyword,
            kind.Kind.SuperKeyword,
            kind.Kind.NullKeyword,
            kind.Kind.TrueKeyword,
            kind.Kind.FalseKeyword,
            kind.Kind.NumericLiteral,
            kind.Kind.BigIntLiteral,
            kind.Kind.StringLiteral,
            kind.Kind.NoSubstitutionTemplateLiteral,
            kind.Kind.TemplateHead,
            kind.Kind.OpenParenToken,
            kind.Kind.OpenBracketToken,
            kind.Kind.OpenBraceToken,
            kind.Kind.FunctionKeyword,
            kind.Kind.ClassKeyword,
            kind.Kind.NewKeyword,
            kind.Kind.SlashToken,
            kind.Kind.SlashEqualsToken,
            kind.Kind.RegularExpressionLiteral,
            kind.Kind.ImportKeyword,
            kind.Kind.PrivateIdentifier => true,
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
        return self.ast.pushNode(.{ .HeritageClause = .{ .Flags = 0, .Token = @intFromEnum(tokenKind), .Types = typesList } });
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
        _ = self.parseExpected(kind.Kind.ClassKeyword);
        var name: ?ast_gen.NodeIndex = null;
        if (self.isIdentifier()) {
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
        const members = try self.ast.pushNodeList(members_arr.items);

        return self.ast.pushNode(.{ .ClassDeclaration = .{
            .Symbol = 0,
            .Flags = 0,
            .modifiers = modifiers,
            .modifierFlags = modifierFlags,
            .name = name,
            .TypeParameters = typeParameters,
            .HeritageClauses = heritageClauses,
            .Members = members,
        } });
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
            parameterName = try self.ast.pushNode(.{ .ThisType = void{} });
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
        self.nextToken(); // consume `<`
        
        var typeArgs = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        defer typeArgs.deinit(self.allocator);
        
        while (self.token != kind.Kind.GreaterThanToken and self.token != kind.Kind.EndOfFile) {
            const startPos = self.scanner.state.pos;
            const t = try self.parseType();
            try typeArgs.append(self.allocator, t);
            
            if (self.token == kind.Kind.CommaToken) {
                self.nextToken();
            }
            
            if (self.scanner.state.pos == startPos) {
                self.nextToken();
            }
        }
        
        _ = self.parseExpected(kind.Kind.GreaterThanToken);
        
        return try self.ast.pushNodeList(typeArgs.items);
    }

    
    pub fn parseEntityName(self: *Parser) anyerror!ast_gen.NodeIndex {
        const text = self.scanner.state.tokenValue;
        var entity = try self.ast.pushNode(.{ .Identifier = .{
            .Flags = 0,
            .Text = text,
        } });
        self.nextToken();

        while (self.token == kind.Kind.DotToken) {
            self.nextToken(); // consume dot
            const rightText = self.scanner.state.tokenValue;
            const right = try self.ast.pushNode(.{ .Identifier = .{
                .Flags = 0,
                .Text = rightText,
            } });
            self.nextToken(); // consume identifier

            entity = try self.ast.pushNode(.{ .QualifiedName = .{
                .Flags = 0,
                .Left = entity,
                .Right = right,
            } });
        }
        return entity;
    }

    pub fn parsePrimaryType(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.token == kind.Kind.NumberKeyword) {
            self.nextToken();
            return try self.ast.pushNode(.{ .NumberKeyword = void{} });
        } else if (self.token == kind.Kind.StringKeyword) {
            self.nextToken();
            return try self.ast.pushNode(.{ .StringKeyword = void{} });
        } else if (self.token == kind.Kind.BooleanKeyword) {
            self.nextToken();
            return try self.ast.pushNode(.{ .BooleanKeyword = void{} });
        } else if (self.token == kind.Kind.AnyKeyword) {
            self.nextToken();
            return try self.ast.pushNode(.{ .AnyKeyword = void{} });
        } else if (self.token == kind.Kind.UnknownKeyword) {
            self.nextToken();
            return try self.ast.pushNode(.{ .UnknownKeyword = void{} });
        } else if (self.token == kind.Kind.NeverKeyword) {
            self.nextToken();
            return try self.ast.pushNode(.{ .NeverKeyword = void{} });
        } else if (self.token == kind.Kind.VoidKeyword) {
            self.nextToken();
            return try self.ast.pushNode(.{ .VoidKeyword = void{} });
        } else if (self.token == kind.Kind.UndefinedKeyword) {
            self.nextToken();
            return try self.ast.pushNode(.{ .UndefinedKeyword = void{} });
        } else if (self.token == kind.Kind.SymbolKeyword) {
            self.nextToken();
            return try self.ast.pushNode(.{ .SymbolKeyword = void{} });
        } else if (self.token == kind.Kind.ObjectKeyword) {
            self.nextToken();
            return try self.ast.pushNode(.{ .ObjectKeyword = void{} });
        } else if (self.token == kind.Kind.NoSubstitutionTemplateLiteral or self.token == kind.Kind.StringLiteral or self.token == kind.Kind.NumericLiteral or self.token == kind.Kind.BigIntLiteral) {
            const text = self.scanner.state.tokenValue;
            const tokenKind = self.token;
            self.nextToken();
            var literal: ast_gen.NodeIndex = 0;
            if (tokenKind == kind.Kind.NoSubstitutionTemplateLiteral) {
                literal = try self.ast.pushNode(.{ .NoSubstitutionTemplateLiteral = .{ .Symbol = 0, .Flags = 0, .Text = text, .TokenFlags = 0, .RawText = "", .TemplateFlags = 0 } });
            } else if (tokenKind == kind.Kind.StringLiteral) {
                literal = try self.ast.pushNode(.{ .StringLiteral = .{ .Flags = 0, .Text = text, .TokenFlags = 0 } });
            } else if (tokenKind == kind.Kind.NumericLiteral) {
                literal = try self.ast.pushNode(.{ .NumericLiteral = .{ .Flags = 0, .Text = text, .TokenFlags = 0 } });
            } else if (tokenKind == kind.Kind.BigIntLiteral) {
                literal = try self.ast.pushNode(.{ .BigIntLiteral = .{ .Flags = 0, .Text = text, .TokenFlags = 0 } });
            }
            return try self.ast.pushNode(.{ .LiteralType = .{ .Flags = 0, .Literal = literal } });
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
            self.nextToken();
            
            // Should be parseEntityName, and optionally typeArguments
            const exprName = try self.parseEntityName();
            var typeArguments: ?ast_gen.NodeListIndex = null;
            if (self.token == kind.Kind.LessThanToken and !self.scanner.hasPrecedingLineBreak()) {
                typeArguments = try self.parseTypeArguments();
            }
            return try self.ast.pushNode(.{ .TypeQuery = .{ .Flags = 0, .ExprName = exprName, .TypeArguments = typeArguments } });
        } else if (self.isIdentifier() or kind.isKeyword(self.token)) {
            const typeName = try self.parseEntityName();

            var typeArguments: ?ast_gen.NodeListIndex = null;
            if (self.token == kind.Kind.LessThanToken) {
                typeArguments = try self.parseTypeArguments();
            }

            return try self.ast.pushNode(.{ .TypeReference = .{
                .Flags = 0,
                .TypeArguments = typeArguments,
                .TypeName = typeName,
            } });
        } else if (self.token == kind.Kind.OpenBraceToken) {
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
            return try self.ast.pushNode(.{ .TypeLiteral = .{ .Flags = 0, .Symbol = 0, .Members = members } });
        } else if (self.token == kind.Kind.OpenBracketToken) {
            return try self.parseTupleType();
        } else if (self.token == kind.Kind.OpenParenToken) {
            self.nextToken();
            const typeNode = try self.parseType();
            _ = self.parseExpected(kind.Kind.CloseParenToken);
            return typeNode;
        }

        self.nextToken();
        return self.ast.pushNode(.{ .Unknown = void{} });
    }

    pub fn parseTemplateLiteralType(self: *Parser) anyerror!ast_gen.NodeIndex {
        const headText = self.scanner.state.tokenValue;
        const head = try self.ast.pushNode(.{ .TemplateHead = .{ .Flags = 0, .Text = headText, .TokenFlags = 0, .RawText = "", .TemplateFlags = 0 } });
        self.nextToken();

        var spans = std.ArrayListUnmanaged(ast_gen.NodeIndex).empty;
        while (true) {
            const spanType = try self.parseType();
            
            if (self.token == kind.Kind.CloseBraceToken) {
                self.token = self.scanner.reScanTemplateToken(false);
            } else {
                std.debug.print("parseTemplateLiteralType error recovery: token is .{s} at pos {d}\n", .{ @tagName(self.token), self.scanner.state.pos });
                // error recovery
            }

            var litNode: ast_gen.NodeIndex = 0;
            if (self.token == kind.Kind.TemplateMiddle) {
                litNode = try self.ast.pushNode(.{ .TemplateMiddle = .{ .Flags = 0, .TokenFlags = self.scanner.state.tokenFlags, .Text = self.scanner.state.tokenValue, .RawText = "", .TemplateFlags = 0 } });
            } else {
                litNode = try self.ast.pushNode(.{ .TemplateTail = .{ .Flags = 0, .TokenFlags = self.scanner.state.tokenFlags, .Text = self.scanner.state.tokenValue, .RawText = "", .TemplateFlags = 0 } });
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
            return self.ast.pushNode(.{ .Token = .{ .Kind = tokenKind } }) catch 0;
        }
        return 0;
    }

    pub fn parseExpected(self: *Parser, t: kind.Kind) bool {
        if (self.token == t) {
            self.nextToken();
            return true;
        }
        self.parseError("Expected token"); // We will expand this to use diagnostics format later
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
            const text = self.scanner.state.tokenValue;
            self.nextToken();
            return self.ast.pushNode(.{ .StringLiteral = .{ .Flags = 0, .Text = text, .TokenFlags = 0 } });
        } else if (self.token == kind.Kind.NumericLiteral or self.token == kind.Kind.BigIntLiteral) {
            const text = self.scanner.state.tokenValue;
            const tokenKind = self.token;
            self.nextToken();
            if (tokenKind == kind.Kind.NumericLiteral) {
                return self.ast.pushNode(.{ .NumericLiteral = .{ .Flags = 0, .Text = text, .TokenFlags = 0 } });
            } else {
                return self.ast.pushNode(.{ .BigIntLiteral = .{ .Flags = 0, .Text = text, .TokenFlags = 0 } });
            }
        } else if (self.token == kind.Kind.OpenBracketToken) {
            self.nextToken();
            const expr = try @import("expression.zig").parseExpression(self);
            _ = self.parseExpected(kind.Kind.CloseBracketToken);
            return self.ast.pushNode(.{ .ComputedPropertyName = .{ .Flags = 0, .Expression = expr } });
        } else if (self.token == kind.Kind.PrivateIdentifier) {
            const text = self.scanner.state.tokenValue;
            self.nextToken();
            return self.ast.pushNode(.{ .PrivateIdentifier = .{ .Flags = 0, .Text = text } });
        } else {
            return self.parseIdentifierName();
        }
    }

pub fn parseIdentifierName(self: *Parser) anyerror!ast_gen.NodeIndex {
    if (self.token == kind.Kind.Identifier or kind.isKeyword(self.token)) {
        const text = self.scanner.state.tokenValue;
        self.nextToken();
        return self.ast.pushNode(.{ .Identifier = .{
            .Flags = 0,
            .Text = text,
        } });
    }
    return self.parseIdentifier();
}

    pub fn parseIdentifier(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.isIdentifier()) {
            const text = self.scanner.state.tokenValue;
            self.nextToken();
            return self.ast.pushNode(.{ .Identifier = .{
                .Flags = 0,
                .Text = text,
            } });
        }
        self.parseError("Expected identifier");
        return self.ast.pushNode(.{ .Identifier = .{
            .Flags = 0,
            .Text = "",
        } });
    }

    pub fn parseError(self: *Parser, msg: []const u8) void {
        const pos = @as(i32, @intCast(self.scanner.state.pos));
        if (pos == self.lastErrorPos) return;
        std.debug.print("parseError at pos {d}: {s} at token {s}\n", .{pos, msg, @tagName(self.token)});
        self.parseDiagnosticsCount += 1;
        self.lastErrorPos = pos;
    }

    pub fn isIndexSignature(self: *Parser) bool {
        if (self.token != kind.Kind.OpenBracketToken) return false;
        
        var tempScanner = self.scanner;
        var tok = tempScanner.scan();
        
        // [id: ...
        // [id, ...
        // [id?, ...
        // [id?: ...
        // [id?]
        
        // Skip identifier
        if (tok == kind.Kind.Identifier or tok == kind.Kind.StringLiteral or tok == kind.Kind.NumericLiteral or tok == kind.Kind.BigIntLiteral or @intFromEnum(tok) > @intFromEnum(kind.Kind.WithKeyword)) {
            tok = tempScanner.scan();
        } else if (tok == kind.Kind.DotDotDotToken) {
            return true;
        } else {
            return false;
        }
        
        if (tok == kind.Kind.ColonToken or tok == kind.Kind.CommaToken) {
            return true;
        }
        
        if (tok == kind.Kind.QuestionToken) {
            tok = tempScanner.scan();
            if (tok == kind.Kind.ColonToken or tok == kind.Kind.CommaToken or tok == kind.Kind.CloseBracketToken) {
                return true;
            }
        }
        
        return false;
    }


    pub fn isStartOfFunctionTypeOrConstructorType(self: *Parser) bool {
        if (self.token == kind.Kind.LessThanToken) return true;
        if (self.token == kind.Kind.NewKeyword) return true;

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

    pub fn parseFunctionOrConstructorType(self: *Parser) anyerror!ast_gen.NodeIndex {
        const isConstructorType = self.parseOptional(kind.Kind.NewKeyword);
        const typeParameters = try self.parseTypeParameters();
        const parameters = try self.parseParameters();
        var returnType: ?ast_gen.NodeIndex = null;
        if (self.parseOptional(kind.Kind.EqualsGreaterThanToken)) {
            returnType = try self.parseType();
        }

        if (isConstructorType) {
            return self.ast.pushNode(.{ .ConstructorType = .{
                .Symbol = 0,
                .Flags = 0,
                .modifiers = null,
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
                .modifiers = null,
                .modifierFlags = 0,
                .TypeParameters = typeParameters,
                .Parameters = parameters,
                .Type = returnType,
                .FullSignature = null,
            } });
        }
    }

    pub fn parseType(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.isStartOfFunctionTypeOrConstructorType()) {
            return self.parseFunctionOrConstructorType();
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

    pub fn parseMethodDeclaration(self: *Parser, modifiers: ?ast_gen.NodeListIndex, modifierFlags: u32, asteriskToken: ?ast_gen.NodeIndex, name: ast_gen.NodeIndex, postfixToken: ?ast_gen.NodeIndex) anyerror!ast_gen.NodeIndex {
        const typeParameters = try self.parseTypeParameters();
        const parameters = try self.parseParameters();
        const returnType = try self.parseReturnTypeAnnotation();
        var body: ?ast_gen.NodeIndex = null;
        if (self.token == kind.Kind.OpenBraceToken) {
            body = try self.parseBlock();
        } else {
            self.parseSemicolon();
        }
        
        return self.ast.pushNode(.{ .MethodDeclaration = .{
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
            } else {
                break;
            }
        }
        return typeNode;

    }

    pub fn parseTypeElement(self: *Parser) anyerror!ast_gen.NodeIndex {
        if (self.token == kind.Kind.OpenParenToken or self.token == kind.Kind.LessThanToken) {
            const typeParameters = try self.parseTypeParameters();
            const parameters = try self.parseParameters();
            var returnType: ?ast_gen.NodeIndex = null;
            if (self.parseOptional(kind.Kind.ColonToken)) {
                returnType = try self.parseType();
            }
            _ = self.parseOptional(kind.Kind.SemicolonToken) or self.parseOptional(kind.Kind.CommaToken);
            return self.ast.pushNode(.{ .CallSignature = .{
                .Flags = 0,
                .TypeParameters = typeParameters,
                .Parameters = parameters,
                .Type = returnType,
            } });
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
                return self.ast.pushNode(.{ .ConstructSignature = .{
                    .Flags = 0,
                    .TypeParameters = typeParameters,
                    .Parameters = parameters,
                    .Type = returnType,
                } });
            }
        }
        
        if (self.token == kind.Kind.OpenBracketToken) {
            self.nextToken();
            var nesting: u32 = 1;
            while (nesting > 0 and self.token != kind.Kind.EndOfFile) {
                if (self.token == kind.Kind.OpenBracketToken) nesting += 1;
                if (self.token == kind.Kind.CloseBracketToken) nesting -= 1;
                self.nextToken();
            }
            const returnType = try self.parseTypeAnnotation();
            _ = self.parseOptional(kind.Kind.SemicolonToken) or self.parseOptional(kind.Kind.CommaToken);
            return self.ast.pushNode(.{ .IndexSignature = .{
                .Flags = 0,
                .modifiers = null,
                .modifierFlags = 0,
                .TypeParameters = null,
                .Parameters = 0,
                .Type = returnType orelse 0,
                .FullSignature = null,
            } });
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
                return self.ast.pushNode(.{ .GetAccessor = .{
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
            } else if (isSet) {
                return self.ast.pushNode(.{ .SetAccessor = .{
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
            } else {
                return self.ast.pushNode(.{ .MethodSignature = .{
                    .Flags = 0,
                    .modifiers = null,
                    .modifierFlags = 0,
                    .name = name,
                    .PostfixToken = questionToken,
                    .TypeParameters = typeParameters,
                    .Parameters = parameters,
                    .Type = returnType,
                } });
            }
        } else {
            const typeNode = try self.parseTypeAnnotation();
            _ = self.parseOptional(kind.Kind.SemicolonToken) or self.parseOptional(kind.Kind.CommaToken);
            
            return self.ast.pushNode(.{ .PropertySignature = .{
                .Flags = 0,
                .modifiers = null,
                .modifierFlags = 0,
                .name = name,
                .PostfixToken = questionToken orelse 0,
                .Type = typeNode orelse 0,
                .Initializer = 0,
            } });
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
            var dotDotDotToken: ?u32 = null;
            if (self.parseOptional(kind.Kind.DotDotDotToken)) {
                dotDotDotToken = try self.ast.pushNode(.{ .Unknown = void{} });
            }
            const name = try self.parseIdentifierName();
            var questionToken: ?u32 = null;
            if (self.parseOptional(kind.Kind.QuestionToken)) {
                questionToken = try self.ast.pushNode(.{ .Unknown = void{} });
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
};
