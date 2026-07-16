const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const lsp_gen = @import("../lsp/lsproto/lsp_generated.zig");
const scanner = @import("../scanner/scanner.zig");

// tokenTypes defines the order of token types for encoding
pub const tokenTypes = [_]lsp_gen.SemanticTokenType{
    .namespace,
    .class,
    .enum_,
    .interface,
    .struct_,
    .typeParameter,
    .type_,
    .parameter,
    .variable,
    .property,
    .enumMember,
    .decorator,
    .event,
    .function,
    .method,
    .macro,
    .label,
    .comment,
    .string,
    .keyword,
    .number,
    .regexp,
    .operator,
};

// tokenModifiers defines the order of token modifiers for encoding
pub const tokenModifiers = [_]lsp_gen.SemanticTokenModifier{
    .declaration,
    .definition,
    .readonly,
    .static,
    .deprecated,
    .abstract,
    .async,
    .modification,
    .documentation,
    .defaultLibrary,
    // "local" is not in lsp_gen.SemanticTokenModifier, so we don't map it to LSP client
};

pub const TokenType = enum(u32) {
    namespace = 0,
    class,
    enum_,
    interface,
    struct_,
    typeParameter,
    type_,
    parameter,
    variable,
    property,
    enumMember,
    decorator,
    event,
    function,
    method,
    macro,
    label,
    comment,
    string,
    keyword,
    number,
    regexp,
    operator,
};

pub const TokenModifier = packed struct {
    declaration: bool = false,
    definition: bool = false,
    readonly: bool = false,
    static: bool = false,
    deprecated: bool = false,
    abstract: bool = false,
    async: bool = false,
    modification: bool = false,
    documentation: bool = false,
    defaultLibrary: bool = false,
    local: bool = false,
    _padding: u5 = 0,

    pub fn toInt(self: TokenModifier) u16 {
        return @bitCast(self);
    }
};

pub const SemanticToken = struct {
    node: ast_gen.NodeIndex,
    tokenType: TokenType,
    tokenModifier: TokenModifier,
};

fn containsString(slice: [][]const u8, str: []const u8) bool {
    var s = str;
    if (std.mem.endsWith(u8, s, "_")) {
        s = s[0 .. s.len - 1];
    }
    for (slice) |item| {
        if (std.mem.eql(u8, item, s)) {
            return true;
        }
    }
    return false;
}

pub fn semanticTokensLegend(allocator: std.mem.Allocator, clientCapabilities: ?lsproto.SemanticTokensClientCapabilities) !lsproto.SemanticTokensLegend {
    var types = std.ArrayList([]const u8).init(allocator);
    var modifiers = std.ArrayList([]const u8).init(allocator);

    if (clientCapabilities) |caps| {
        for (tokenTypes) |t| {
            if (containsString(caps.tokenTypes, @tagName(t))) {
                var s = @tagName(t);
                if (std.mem.endsWith(u8, s, "_")) s = s[0 .. s.len - 1];
                try types.append(s);
            }
        }
        for (tokenModifiers) |m| {
            if (containsString(caps.tokenModifiers, @tagName(m))) {
                var s = @tagName(m);
                if (std.mem.endsWith(u8, s, "_")) s = s[0 .. s.len - 1];
                try modifiers.append(s);
            }
        }
    } else {
        for (tokenTypes) |t| {
            var s = @tagName(t);
            if (std.mem.endsWith(u8, s, "_")) s = s[0 .. s.len - 1];
            try types.append(s);
        }
        for (tokenModifiers) |m| {
            var s = @tagName(m);
            if (std.mem.endsWith(u8, s, "_")) s = s[0 .. s.len - 1];
            try modifiers.append(s);
        }
    }

    return lsproto.SemanticTokensLegend{
        .tokenTypes = try types.toOwnedSlice(),
        .tokenModifiers = try modifiers.toOwnedSlice(),
    };
}

pub fn provideDocumentSemanticTokens(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.SemanticTokensParams,
    clientCapabilities: ?lsproto.SemanticTokensClientCapabilities,
) !?lsproto.SemanticTokens {
    const programAndFile = ls.getProgramAndFile(params.textDocument.uri);
    const file = programAndFile.file;

    const chk = ls.getTypeCheckerForFile(file);

    const tokens = try collectSemanticTokens(allocator, chk, file, ls.program);
    defer allocator.free(tokens);

    if (tokens.len == 0) {
        return null;
    }

    const tree = chk.binder.ast;
    const encoded = try encodeSemanticTokens(allocator, tokens, file, tree, ls, clientCapabilities);

    return lsproto.SemanticTokens{
        .data = encoded,
    };
}

pub fn provideDocumentSemanticTokensRange(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    params: *lsproto.SemanticTokensRangeParams,
    clientCapabilities: ?lsproto.SemanticTokensClientCapabilities,
) !?lsproto.SemanticTokens {
    const programAndFile = ls.getProgramAndFile(params.textDocument.uri);
    const file = programAndFile.file;

    const chk = ls.getTypeCheckerForFile(file);

    const script = ls.getScript(file);
    const start = ls.converters.lineAndCharacterToPosition(script, params.range.start);
    const end = ls.converters.lineAndCharacterToPosition(script, params.range.end);

    const tokens = try collectSemanticTokensInRange(allocator, chk, file, ls.program, @intCast(start), @intCast(end));
    defer allocator.free(tokens);

    if (tokens.len == 0) {
        return null;
    }

    const tree = chk.binder.ast;
    const encoded = try encodeSemanticTokens(allocator, tokens, file, tree, ls, clientCapabilities);

    return lsproto.SemanticTokens{
        .data = encoded,
    };
}

pub fn collectSemanticTokens(allocator: std.mem.Allocator, chk: *checker.Checker, file: compiler.FileId, program: *compiler.Program) ![]SemanticToken {
    return try collectSemanticTokensInRange(allocator, chk, file, program, 0, std.math.maxInt(u32));
}

const Visitor = struct {
    allocator: std.mem.Allocator,
    chk: *checker.Checker,
    file: compiler.FileId,
    program: *compiler.Program,
    spanStart: u32,
    spanEnd: u32,
    tokens: std.ArrayList(SemanticToken),
    inJSXElement: bool,

    pub fn visit(self: *@This(), node: ast_gen.NodeIndex) void {
        if (node == 0) return;
        const tree = self.chk.binder.ast;

        const nodeEnd = tree.getNodeEnd(node);
        const nodePos = tree.getNodePos(node);
        if (nodePos >= self.spanEnd or nodeEnd <= self.spanStart) {
            return;
        }

        const prevInJSXElement = self.inJSXElement;
        const kind = tree.getKind(node);
        if (kind == .JsxElement or kind == .JsxSelfClosingElement) {
            self.inJSXElement = true;
        } else if (kind == .JsxExpression) {
            self.inJSXElement = false;
        }

        if (kind == .Identifier and tree.getTextOfNode(node).len > 0 and !self.inJSXElement and !isInImportClause(tree, node) and !isInfinityOrNaNString(tree.getTextOfNode(node))) {
            var symbol = self.chk.getSymbolAtLocation(node);
            if (symbol != 0) {
                if ((self.chk.getSymbolFlags(symbol) & ast_gen.SymbolFlags.Alias) != 0) {
                    symbol = self.chk.getAliasedSymbol(symbol);
                }

                const meaning = self.chk.getMeaningFromLocation(node);
                if (classifySymbol(self.chk, symbol, meaning)) |tokenTypeOpt| {
                    var tokenType = tokenTypeOpt;
                    var tokenModifier = TokenModifier{};

                    const parent = tree.parents.items[node];
                    if (parent != 0) {
                        const parentKind = tree.getKind(parent);
                        const parentIsDeclaration = ast_utils.isBindingElement(tree, parent) or tokenFromDeclarationMapping(parentKind) == tokenType;
                        if (parentIsDeclaration) {
                            const parentName = ast_utils.getNameOfDeclaration(tree, parent);
                            if (parentName == node) {
                                tokenModifier.declaration = true;
                            }
                        }
                    }

                    if (tokenType == .parameter and ast_utils.isRightSideOfQualifiedNameOrPropertyAccess(tree, node)) {
                        tokenType = .property;
                    }

                    tokenType = reclassifyByType(self.chk, node, tokenType);

                    const decl = self.chk.getSymbolValueDeclaration(symbol);
                    if (decl != 0) {
                        const modifiers = ast_utils.getCombinedModifierFlags(tree, decl);
                        const nodeFlags = ast_utils.getCombinedNodeFlags(tree, decl);

                        if ((modifiers & ast_gen.ModifierFlags.Static) != 0) {
                            tokenModifier.static = true;
                        }
                        if ((modifiers & ast_gen.ModifierFlags.Async) != 0) {
                            tokenModifier.async = true;
                        }
                        if (tokenType != .class and tokenType != .interface) {
                            if ((modifiers & ast_gen.ModifierFlags.Readonly) != 0 or (nodeFlags & ast_gen.NodeFlags.Const) != 0 or (self.chk.getSymbolFlags(symbol) & ast_gen.SymbolFlags.EnumMember) != 0) {
                                tokenModifier.readonly = true;
                            }
                        }
                        if ((tokenType == .variable or tokenType == .function) and isLocalDeclaration(tree, decl, self.file)) {
                            tokenModifier.local = true;
                        }
                    }

                    self.tokens.append(.{
                        .node = node,
                        .tokenType = tokenType,
                        .tokenModifier = tokenModifier,
                    }) catch unreachable;
                }
            }
        }

        ast_utils.forEachChild(tree, node, self, visitNode);
        self.inJSXElement = prevInJSXElement;
    }

    fn visitNode(self: *@This(), node: ast_gen.NodeIndex) void {
        self.visit(node);
    }
};

pub fn collectSemanticTokensInRange(allocator: std.mem.Allocator, chk: *checker.Checker, file: compiler.FileId, program: *compiler.Program, spanStart: u32, spanEnd: u32) ![]SemanticToken {
    var visitor = Visitor{
        .allocator = allocator,
        .chk = chk,
        .file = file,
        .program = program,
        .spanStart = spanStart,
        .spanEnd = spanEnd,
        .tokens = std.ArrayList(SemanticToken).init(allocator),
        .inJSXElement = false,
    };

    const tree = chk.binder.ast;
    const root = tree.sourceFiles.items[file];
    visitor.visit(root);

    return visitor.tokens.toOwnedSlice();
}

fn classifySymbol(chk: *checker.Checker, symbol: ast_gen.SymbolIndex, meaning: ast_gen.SemanticMeaning) ?TokenType {
    const flags = chk.getSymbolFlags(symbol);
    if ((flags & ast_gen.SymbolFlags.Class) != 0) return .class;
    if ((flags & ast_gen.SymbolFlags.Enum) != 0) return .enum_;
    if ((flags & ast_gen.SymbolFlags.TypeAlias) != 0) return .type_;
    if ((flags & ast_gen.SymbolFlags.Interface) != 0) {
        if ((@intFromEnum(meaning) & @intFromEnum(ast_gen.SemanticMeaning.Type)) != 0) {
            return .interface;
        }
    }
    if ((flags & ast_gen.SymbolFlags.TypeParameter) != 0) return .typeParameter;

    var decl = chk.getSymbolValueDeclaration(symbol);
    if (decl == 0) {
        const decls = chk.symbols.items[symbol].Declarations.items;
        if (decls.len > 0) {
            decl = decls[0];
        }
    }
    if (decl != 0) {
        if (ast_utils.isBindingElement(chk.binder.ast, decl)) {
            decl = getDeclarationForBindingElement(chk.binder.ast, decl);
        }
        if (tokenFromDeclarationMapping(chk.binder.ast.getKind(decl))) |tt| {
            return tt;
        }
    }
    return null;
}

fn tokenFromDeclarationMapping(kind: ast_gen.SyntaxKind) ?TokenType {
    switch (kind) {
        .VariableDeclaration => return .variable,
        .Parameter => return .parameter,
        .PropertyDeclaration => return .property,
        .ModuleDeclaration => return .namespace,
        .EnumDeclaration => return .enum_,
        .EnumMember => return .enumMember,
        .ClassDeclaration, .ClassExpression => return .class,
        .MethodDeclaration => return .method,
        .FunctionDeclaration, .FunctionExpression => return .function,
        .MethodSignature => return .method,
        .GetAccessor, .SetAccessor => return .property,
        .PropertySignature => return .property,
        .InterfaceDeclaration => return .interface,
        .TypeAliasDeclaration => return .type_,
        .TypeParameter => return .typeParameter,
        .PropertyAssignment, .ShorthandPropertyAssignment => return .property,
        else => return null,
    }
}

fn reclassifyByType(chk: *checker.Checker, node: ast_gen.NodeIndex, tt: TokenType) TokenType {
    if (tt == .variable or tt == .property or tt == .parameter) {
        const typ = chk.getTypeAtLocation(node);
        if (typ != 0) {
            var hasConstructSigs = false;
            var hasCallSigs = false;
            var hasNoProperties = false;

            const constructSigs = chk.getSignaturesOfType(typ, .Construct);
            if (constructSigs.items.len > 0) hasConstructSigs = true;

            const callSigs = chk.getSignaturesOfType(typ, .Call);
            if (callSigs.items.len > 0) hasCallSigs = true;

            const props = chk.getPropertiesOfObjectType(typ);
            if (props.len == 0) hasNoProperties = true;
            // Note: full union type iteration omitted to keep it simple, similar to DOD

            if (tt != .parameter and hasConstructSigs) {
                return .class;
            }

            if (hasCallSigs) {
                if (hasNoProperties or isExpressionInCallExpression(chk.binder.ast, node)) {
                    if (tt == .property) return .method;
                    return .function;
                }
            }
        }
    }
    return tt;
}

fn isLocalDeclaration(tree: *ast.Ast, declArg: ast_gen.NodeIndex, file: compiler.FileId) bool {
    var decl = declArg;
    if (ast_utils.isBindingElement(tree, decl)) {
        decl = getDeclarationForBindingElement(tree, decl);
    }
    if (tree.getKind(decl) == .VariableDeclaration) {
        const parent = tree.parents.items[decl];
        if (parent != 0 and tree.getKind(parent) == .CatchClause) {
            return tree.getSourceFileOfNode(decl) == file;
        }
        if (parent != 0 and tree.getKind(parent) == .VariableDeclarationList) {
            const grandparent = tree.parents.items[parent];
            if (grandparent != 0) {
                const greatGrandparent = tree.parents.items[grandparent];
                return (tree.getKind(greatGrandparent) != .SourceFile or tree.getKind(grandparent) == .CatchClause) and tree.getSourceFileOfNode(decl) == file;
            }
        }
    } else if (tree.getKind(decl) == .FunctionDeclaration) {
        const parent = tree.parents.items[decl];
        return parent != 0 and tree.getKind(parent) != .SourceFile and tree.getSourceFileOfNode(decl) == file;
    }
    return false;
}

fn getDeclarationForBindingElement(tree: *ast.Ast, elementArg: ast_gen.NodeIndex) ast_gen.NodeIndex {
    var element = elementArg;
    while (true) {
        const parent = tree.parents.items[element];
        if (parent != 0 and ast_utils.isBindingPattern(tree, parent)) {
            const grandparent = tree.parents.items[parent];
            if (grandparent != 0 and ast_utils.isBindingElement(tree, grandparent)) {
                element = grandparent;
                continue;
            }
            return tree.parents.items[parent];
        }
        return element;
    }
}

fn isInImportClause(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const parent = tree.parents.items[node];
    if (parent == 0) return false;
    const kind = tree.getKind(parent);
    return kind == .ImportClause or kind == .ImportSpecifier or kind == .NamespaceImport;
}

fn isExpressionInCallExpression(tree: *ast.Ast, nodeArg: ast_gen.NodeIndex) bool {
    var node = nodeArg;
    while (ast_utils.isRightSideOfQualifiedNameOrPropertyAccess(tree, node)) {
        node = tree.parents.items[node];
    }
    const parent = tree.parents.items[node];
    return parent != 0 and tree.getKind(parent) == .CallExpression and tree.getNode(parent).CallExpression.expression == node;
}

fn isInfinityOrNaNString(text: []const u8) bool {
    return std.mem.eql(u8, text, "Infinity") or std.mem.eql(u8, text, "NaN");
}

pub fn encodeSemanticTokens(allocator: std.mem.Allocator, tokens: []SemanticToken, file: compiler.FileId, tree: *ast.Ast, ls: *languageservice.LanguageService, clientCapabilities: ?lsproto.SemanticTokensClientCapabilities) ![]u32 {
    var typeMapping = std.AutoHashMap(TokenType, u32).init(allocator);
    defer typeMapping.deinit();
    var modifierMapping = std.AutoHashMap(lsp_gen.SemanticTokenModifier, u32).init(allocator);
    defer modifierMapping.deinit();

    var clientIdx: u32 = 0;
    for (tokenTypes, 0..) |serverType, i| {
        if (clientCapabilities == null or containsString(clientCapabilities.?.tokenTypes, @tagName(serverType))) {
            try typeMapping.put(@enumFromInt(i), clientIdx);
            clientIdx += 1;
        }
    }

    var clientBit: u32 = 0;
    for (tokenModifiers) |serverModifier| {
        if (clientCapabilities == null or containsString(clientCapabilities.?.tokenModifiers, @tagName(serverModifier))) {
            try modifierMapping.put(serverModifier, clientBit);
            clientBit += 1;
        }
    }

    var encoded = std.ArrayList(u32).init(allocator);
    var prevLine: u32 = 0;
    var prevChar: u32 = 0;

    const script = ls.getScript(file);

    for (tokens) |token| {
        const clientTypeIdxOpt = typeMapping.get(token.tokenType);
        if (clientTypeIdxOpt == null) {
            continue;
        }
        const clientTypeIdx = clientTypeIdxOpt.?;

        var clientModifierMask: u32 = 0;
        inline for (std.meta.fields(TokenModifier)) |field| {
            if (field.type == bool and @field(token.tokenModifier, field.name)) {
                for (tokenModifiers) |serverModifier| {
                    if (std.mem.eql(u8, @tagName(serverModifier), field.name)) {
                        if (modifierMapping.get(serverModifier)) |bit| {
                            clientModifierMask |= (@as(u32, 1) << @intCast(bit));
                        }
                    }
                }
            }
        }

        const tokenStart = scanner.getTokenPosOfNode(tree, token.node, false);
        const tokenEnd = tree.getNodeEnd(token.node);

        const startPos = ls.converters.positionToLineAndCharacter(script, tokenStart);
        const endPos = ls.converters.positionToLineAndCharacter(script, tokenEnd);

        var tokenLength: u32 = 0;
        if (startPos.line == endPos.line) {
            tokenLength = endPos.character - startPos.character;
        } else {
            // we should panic or skip, let's skip
            continue;
        }

        const line = startPos.line;
        const char = startPos.character;

        if (encoded.items.len > 0 and (line < prevLine or (line == prevLine and char <= prevChar))) {
            continue;
        }

        const deltaLine = line - prevLine;
        var deltaChar: u32 = 0;
        if (deltaLine == 0) {
            deltaChar = char - prevChar;
        } else {
            deltaChar = char;
        }

        try encoded.append(deltaLine);
        try encoded.append(deltaChar);
        try encoded.append(tokenLength);
        try encoded.append(clientTypeIdx);
        try encoded.append(clientModifierMask);

        prevLine = line;
        prevChar = char;
    }

    return encoded.toOwnedSlice();
}
