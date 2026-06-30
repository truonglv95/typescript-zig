const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_mod = @import("../ast/ast.zig");
const emitcontext = @import("emitcontext.zig");
const emittextwriter = @import("emittextwriter.zig");
const precedence = @import("../ast/precedence.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const helpers_mod = @import("helpers.zig");

pub const Printer = struct {
    pub const SourceMapHook = struct {
        context: *anyopaque,
        addMapping: *const fn (*anyopaque, usize, usize, usize, usize) void,
    };

    tree: *ast_mod.Ast,
    context: *emitcontext.EmitContext,
    writer: *emittextwriter.EmitTextWriter,
    currentSourceFile: ast_mod.NodeIndex,
    sourceMapHook: ?SourceMapHook,
    sourceLineStarts: []const usize,
    currentNode: ast_mod.NodeIndex,
    generatedNameCandidates: std.StringHashMapUnmanaged(void),

    pub fn init(
        tree: *ast_mod.Ast,
        context: *emitcontext.EmitContext,
        writer: *emittextwriter.EmitTextWriter,
    ) Printer {
        return .{
            .tree = tree,
            .context = context,
            .writer = writer,
            .currentSourceFile = 0,
            .sourceMapHook = null,
            .sourceLineStarts = &.{},
            .currentNode = 0,
            .generatedNameCandidates = .empty,
        };
    }

    pub fn setSourceMapHook(self: *Printer, hook: SourceMapHook) void {
        self.sourceMapHook = hook;
        var starts = std.ArrayListUnmanaged(usize).empty;
        starts.append(self.context.allocator, 0) catch return;
        for (self.tree.sourceText, 0..) |byte, index| {
            if (byte == '\n') starts.append(self.context.allocator, index + 1) catch return;
        }
        self.sourceLineStarts = starts.items;
    }

    pub fn printSourceFile(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        self.currentSourceFile = nodeIndex;
        if (nodeIndex == 0) return;
        const node = self.tree.getNode(nodeIndex);
        if (node != .SourceFile) return;

        const sourceFile = node.SourceFile;
        const ListFormat = @import("emit_list.zig").ListFormat;
        if (try self.emitHelpers(nodeIndex)) {
            self.writer.writeLine();
        }
        // SourceFileStatements format: MultiLine
        try self.printList(ListFormat.MultiLine, sourceFile.Statements);
    }

    pub fn emitHelpers(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!bool {
        var helpersEmitted = false;
        if (self.context.getEmitHelpers(nodeIndex)) |helpers_list| {
            var sorted_helpers: std.ArrayList(*const helpers_mod.EmitHelper) = .empty;
            defer sorted_helpers.deinit(self.context.allocator);
            try sorted_helpers.appendSlice(self.context.allocator, helpers_list);

            var i: usize = 0;
            while (i < sorted_helpers.items.len) : (i += 1) {
                var j: usize = i + 1;
                while (j < sorted_helpers.items.len) : (j += 1) {
                    const px = sorted_helpers.items[i].priority orelse 999;
                    const py = sorted_helpers.items[j].priority orelse 999;
                    if (px > py) {
                        const temp = sorted_helpers.items[i];
                        sorted_helpers.items[i] = sorted_helpers.items[j];
                        sorted_helpers.items[j] = temp;
                    }
                }
            }

            for (sorted_helpers.items) |helper| {
                var helper_indent: usize = 0;
                var line_it = std.mem.splitScalar(u8, helper.text, '\n');
                while (line_it.next()) |line| {
                    if (helper.preserveIndent) {
                        self.writer.write(line);
                        self.writer.writeLine();
                        continue;
                    }
                    const trimmed = std.mem.trim(u8, line, " \t\r");
                    if (trimmed.len == 0) continue;
                    const starts_with_close = trimmed[0] == '}';
                    const render_indent = if (starts_with_close and helper_indent > 0) helper_indent - 1 else helper_indent;
                    var indent_index: usize = 0;
                    while (indent_index < render_indent) : (indent_index += 1) self.writer.increaseIndent();
                    self.writer.write(trimmed);
                    self.writer.writeLine();
                    indent_index = 0;
                    while (indent_index < render_indent) : (indent_index += 1) self.writer.decreaseIndent();
                    var opens: usize = 0;
                    var closes: usize = 0;
                    for (trimmed) |char| {
                        if (char == '{') opens += 1;
                        if (char == '}') closes += 1;
                    }
                    if (opens >= closes) {
                        helper_indent += opens - closes;
                    } else {
                        helper_indent -|= closes - opens;
                    }
                }
                helpersEmitted = true;
            }
        }
        return helpersEmitted;
    }

    pub fn printNode(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        if (nodeIndex == 0) return;
        self.recordSourceMapping(nodeIndex);
        const node = self.tree.getNode(nodeIndex);
        switch (node) {
            .Unknown => try self.printUnknown(nodeIndex),
            .EndOfFile => try self.printEndOfFile(nodeIndex),
            .SingleLineCommentTrivia => try self.printSingleLineCommentTrivia(nodeIndex),
            .MultiLineCommentTrivia => try self.printMultiLineCommentTrivia(nodeIndex),
            .NewLineTrivia => try self.printNewLineTrivia(nodeIndex),
            .WhitespaceTrivia => try self.printWhitespaceTrivia(nodeIndex),
            .ConflictMarkerTrivia => try self.printConflictMarkerTrivia(nodeIndex),
            .NonTextFileMarkerTrivia => try self.printNonTextFileMarkerTrivia(nodeIndex),
            .NumericLiteral => try self.printNumericLiteral(nodeIndex),
            .BigIntLiteral => try self.printBigIntLiteral(nodeIndex),
            .StringLiteral => try self.printStringLiteral(nodeIndex),
            .JsxText => try self.printJsxText(nodeIndex),
            .JsxTextAllWhiteSpaces => try self.printJsxTextAllWhiteSpaces(nodeIndex),
            .RegularExpressionLiteral => try self.printRegularExpressionLiteral(nodeIndex),
            .NoSubstitutionTemplateLiteral => try self.printNoSubstitutionTemplateLiteral(nodeIndex),
            .TemplateHead => try self.printTemplateHead(nodeIndex),
            .TemplateMiddle => try self.printTemplateMiddle(nodeIndex),
            .TemplateTail => try self.printTemplateTail(nodeIndex),
            .OpenBraceToken => try self.printOpenBraceToken(nodeIndex),
            .CloseBraceToken => try self.printCloseBraceToken(nodeIndex),
            .OpenParenToken => try self.printOpenParenToken(nodeIndex),
            .CloseParenToken => try self.printCloseParenToken(nodeIndex),
            .OpenBracketToken => try self.printOpenBracketToken(nodeIndex),
            .CloseBracketToken => try self.printCloseBracketToken(nodeIndex),
            .DotToken => try self.printDotToken(nodeIndex),
            .DotDotDotToken => try self.printDotDotDotToken(nodeIndex),
            .SemicolonToken => try self.printSemicolonToken(nodeIndex),
            .CommaToken => try self.printCommaToken(nodeIndex),
            .QuestionDotToken => try self.printQuestionDotToken(nodeIndex),
            .LessThanToken => try self.printLessThanToken(nodeIndex),
            .LessThanSlashToken => try self.printLessThanSlashToken(nodeIndex),
            .GreaterThanToken => try self.printGreaterThanToken(nodeIndex),
            .LessThanEqualsToken => try self.printLessThanEqualsToken(nodeIndex),
            .GreaterThanEqualsToken => try self.printGreaterThanEqualsToken(nodeIndex),
            .EqualsEqualsToken => try self.printEqualsEqualsToken(nodeIndex),
            .ExclamationEqualsToken => try self.printExclamationEqualsToken(nodeIndex),
            .EqualsEqualsEqualsToken => try self.printEqualsEqualsEqualsToken(nodeIndex),
            .ExclamationEqualsEqualsToken => try self.printExclamationEqualsEqualsToken(nodeIndex),
            .EqualsGreaterThanToken => try self.printEqualsGreaterThanToken(nodeIndex),
            .PlusToken => try self.printPlusToken(nodeIndex),
            .MinusToken => try self.printMinusToken(nodeIndex),
            .AsteriskToken => try self.printAsteriskToken(nodeIndex),
            .AsteriskAsteriskToken => try self.printAsteriskAsteriskToken(nodeIndex),
            .SlashToken => try self.printSlashToken(nodeIndex),
            .PercentToken => try self.printPercentToken(nodeIndex),
            .PlusPlusToken => try self.printPlusPlusToken(nodeIndex),
            .MinusMinusToken => try self.printMinusMinusToken(nodeIndex),
            .LessThanLessThanToken => try self.printLessThanLessThanToken(nodeIndex),
            .GreaterThanGreaterThanToken => try self.printGreaterThanGreaterThanToken(nodeIndex),
            .GreaterThanGreaterThanGreaterThanToken => try self.printGreaterThanGreaterThanGreaterThanToken(nodeIndex),
            .AmpersandToken => try self.printAmpersandToken(nodeIndex),
            .BarToken => try self.printBarToken(nodeIndex),
            .CaretToken => try self.printCaretToken(nodeIndex),
            .ExclamationToken => try self.printExclamationToken(nodeIndex),
            .TildeToken => try self.printTildeToken(nodeIndex),
            .AmpersandAmpersandToken => try self.printAmpersandAmpersandToken(nodeIndex),
            .BarBarToken => try self.printBarBarToken(nodeIndex),
            .QuestionToken => try self.printQuestionToken(nodeIndex),
            .ColonToken => try self.printColonToken(nodeIndex),
            .AtToken => try self.printAtToken(nodeIndex),
            .QuestionQuestionToken => try self.printQuestionQuestionToken(nodeIndex),
            .BacktickToken => try self.printBacktickToken(nodeIndex),
            .HashToken => try self.printHashToken(nodeIndex),
            .EqualsToken => try self.printEqualsToken(nodeIndex),
            .PlusEqualsToken => try self.printPlusEqualsToken(nodeIndex),
            .MinusEqualsToken => try self.printMinusEqualsToken(nodeIndex),
            .AsteriskEqualsToken => try self.printAsteriskEqualsToken(nodeIndex),
            .AsteriskAsteriskEqualsToken => try self.printAsteriskAsteriskEqualsToken(nodeIndex),
            .SlashEqualsToken => try self.printSlashEqualsToken(nodeIndex),
            .PercentEqualsToken => try self.printPercentEqualsToken(nodeIndex),
            .LessThanLessThanEqualsToken => try self.printLessThanLessThanEqualsToken(nodeIndex),
            .GreaterThanGreaterThanEqualsToken => try self.printGreaterThanGreaterThanEqualsToken(nodeIndex),
            .GreaterThanGreaterThanGreaterThanEqualsToken => try self.printGreaterThanGreaterThanGreaterThanEqualsToken(nodeIndex),
            .AmpersandEqualsToken => try self.printAmpersandEqualsToken(nodeIndex),
            .BarEqualsToken => try self.printBarEqualsToken(nodeIndex),
            .BarBarEqualsToken => try self.printBarBarEqualsToken(nodeIndex),
            .AmpersandAmpersandEqualsToken => try self.printAmpersandAmpersandEqualsToken(nodeIndex),
            .QuestionQuestionEqualsToken => try self.printQuestionQuestionEqualsToken(nodeIndex),
            .CaretEqualsToken => try self.printCaretEqualsToken(nodeIndex),
            .Identifier => try self.printIdentifier(nodeIndex),
            .PrivateIdentifier => try self.printPrivateIdentifier(nodeIndex),
            .JSDocCommentTextToken => try self.printJSDocCommentTextToken(nodeIndex),
            .BreakKeyword => try self.printBreakKeyword(nodeIndex),
            .CaseKeyword => try self.printCaseKeyword(nodeIndex),
            .CatchKeyword => try self.printCatchKeyword(nodeIndex),
            .ClassKeyword => try self.printClassKeyword(nodeIndex),
            .ConstKeyword => try self.printConstKeyword(nodeIndex),
            .ContinueKeyword => try self.printContinueKeyword(nodeIndex),
            .DebuggerKeyword => try self.printDebuggerKeyword(nodeIndex),
            .DefaultKeyword => try self.printDefaultKeyword(nodeIndex),
            .DeleteKeyword => try self.printDeleteKeyword(nodeIndex),
            .DoKeyword => try self.printDoKeyword(nodeIndex),
            .ElseKeyword => try self.printElseKeyword(nodeIndex),
            .EnumKeyword => try self.printEnumKeyword(nodeIndex),
            .ExportKeyword => try self.printExportKeyword(nodeIndex),
            .ExtendsKeyword => try self.printExtendsKeyword(nodeIndex),
            .FalseKeyword => try self.printFalseKeyword(nodeIndex),
            .FinallyKeyword => try self.printFinallyKeyword(nodeIndex),
            .ForKeyword => try self.printForKeyword(nodeIndex),
            .FunctionKeyword => try self.printFunctionKeyword(nodeIndex),
            .IfKeyword => try self.printIfKeyword(nodeIndex),
            .ImportKeyword => try self.printImportKeyword(nodeIndex),
            .InKeyword => try self.printInKeyword(nodeIndex),
            .InstanceOfKeyword => try self.printInstanceOfKeyword(nodeIndex),
            .NewKeyword => try self.printNewKeyword(nodeIndex),
            .NullKeyword => try self.printNullKeyword(nodeIndex),
            .ReturnKeyword => try self.printReturnKeyword(nodeIndex),
            .SuperKeyword => try self.printSuperKeyword(nodeIndex),
            .SwitchKeyword => try self.printSwitchKeyword(nodeIndex),
            .ThisKeyword => try self.printThisKeyword(nodeIndex),
            .ThrowKeyword => try self.printThrowKeyword(nodeIndex),
            .TrueKeyword => try self.printTrueKeyword(nodeIndex),
            .TryKeyword => try self.printTryKeyword(nodeIndex),
            .TypeOfKeyword => try self.printTypeOfKeyword(nodeIndex),
            .VarKeyword => try self.printVarKeyword(nodeIndex),
            .VoidKeyword => try self.printVoidKeyword(nodeIndex),
            .WhileKeyword => try self.printWhileKeyword(nodeIndex),
            .WithKeyword => try self.printWithKeyword(nodeIndex),
            .ImplementsKeyword => try self.printImplementsKeyword(nodeIndex),
            .InterfaceKeyword => try self.printInterfaceKeyword(nodeIndex),
            .LetKeyword => try self.printLetKeyword(nodeIndex),
            .PackageKeyword => try self.printPackageKeyword(nodeIndex),
            .PrivateKeyword => try self.printPrivateKeyword(nodeIndex),
            .ProtectedKeyword => try self.printProtectedKeyword(nodeIndex),
            .PublicKeyword => try self.printPublicKeyword(nodeIndex),
            .StaticKeyword => try self.printStaticKeyword(nodeIndex),
            .YieldKeyword => try self.printYieldKeyword(nodeIndex),
            .AbstractKeyword => try self.printAbstractKeyword(nodeIndex),
            .AccessorKeyword => try self.printAccessorKeyword(nodeIndex),
            .AsKeyword => try self.printAsKeyword(nodeIndex),
            .AssertsKeyword => try self.printAssertsKeyword(nodeIndex),
            .AssertKeyword => try self.printAssertKeyword(nodeIndex),
            .DeferKeyword => try self.printDeferKeyword(nodeIndex),
            .AnyKeyword => try self.printAnyKeyword(nodeIndex),
            .AsyncKeyword => try self.printAsyncKeyword(nodeIndex),
            .AwaitKeyword => try self.printAwaitKeyword(nodeIndex),
            .BooleanKeyword => try self.printBooleanKeyword(nodeIndex),
            .ConstructorKeyword => try self.printConstructorKeyword(nodeIndex),
            .DeclareKeyword => try self.printDeclareKeyword(nodeIndex),
            .GetKeyword => try self.printGetKeyword(nodeIndex),
            .ImmediateKeyword => try self.printImmediateKeyword(nodeIndex),
            .InferKeyword => try self.printInferKeyword(nodeIndex),
            .IntrinsicKeyword => try self.printIntrinsicKeyword(nodeIndex),
            .IsKeyword => try self.printIsKeyword(nodeIndex),
            .KeyOfKeyword => try self.printKeyOfKeyword(nodeIndex),
            .ModuleKeyword => try self.printModuleKeyword(nodeIndex),
            .NamespaceKeyword => try self.printNamespaceKeyword(nodeIndex),
            .NeverKeyword => try self.printNeverKeyword(nodeIndex),
            .OutKeyword => try self.printOutKeyword(nodeIndex),
            .ReadonlyKeyword => try self.printReadonlyKeyword(nodeIndex),
            .RequireKeyword => try self.printRequireKeyword(nodeIndex),
            .NumberKeyword => try self.printNumberKeyword(nodeIndex),
            .ObjectKeyword => try self.printObjectKeyword(nodeIndex),
            .SatisfiesKeyword => try self.printSatisfiesKeyword(nodeIndex),
            .SetKeyword => try self.printSetKeyword(nodeIndex),
            .StringKeyword => try self.printStringKeyword(nodeIndex),
            .SymbolKeyword => try self.printSymbolKeyword(nodeIndex),
            .TypeKeyword => try self.printTypeKeyword(nodeIndex),
            .UndefinedKeyword => try self.printUndefinedKeyword(nodeIndex),
            .UniqueKeyword => try self.printUniqueKeyword(nodeIndex),
            .UnknownKeyword => try self.printUnknownKeyword(nodeIndex),
            .UsingKeyword => try self.printUsingKeyword(nodeIndex),
            .FromKeyword => try self.printFromKeyword(nodeIndex),
            .GlobalKeyword => try self.printGlobalKeyword(nodeIndex),
            .BigIntKeyword => try self.printBigIntKeyword(nodeIndex),
            .OverrideKeyword => try self.printOverrideKeyword(nodeIndex),
            .OfKeyword => try self.printOfKeyword(nodeIndex),
            .QualifiedName => try self.printQualifiedName(nodeIndex),
            .ComputedPropertyName => try self.printComputedPropertyName(nodeIndex),
            .TypeParameter => try self.printTypeParameter(nodeIndex),
            .Parameter => try self.printParameter(nodeIndex),
            .Decorator => try self.printDecorator(nodeIndex),
            .PropertySignature => try self.printPropertySignature(nodeIndex),
            .PropertyDeclaration => try self.printPropertyDeclaration(nodeIndex),
            .MethodSignature => try self.printMethodSignature(nodeIndex),
            .MethodDeclaration => try self.printMethodDeclaration(nodeIndex),
            .ClassStaticBlockDeclaration => try self.printClassStaticBlockDeclaration(nodeIndex),
            .Constructor => try self.printConstructor(nodeIndex),
            .GetAccessor => try self.printGetAccessor(nodeIndex),
            .SetAccessor => try self.printSetAccessor(nodeIndex),
            .CallSignature => try self.printCallSignature(nodeIndex),
            .ConstructSignature => try self.printConstructSignature(nodeIndex),
            .IndexSignature => try self.printIndexSignature(nodeIndex),
            .TypePredicate => try self.printTypePredicate(nodeIndex),
            .TypeReference => try self.printTypeReference(nodeIndex),
            .FunctionType => try self.printFunctionType(nodeIndex),
            .ConstructorType => try self.printConstructorType(nodeIndex),
            .TypeQuery => try self.printTypeQuery(nodeIndex),
            .TypeLiteral => try self.printTypeLiteral(nodeIndex),
            .ArrayType => try self.printArrayType(nodeIndex),
            .TupleType => try self.printTupleType(nodeIndex),
            .OptionalType => try self.printOptionalType(nodeIndex),
            .RestType => try self.printRestType(nodeIndex),
            .UnionType => try self.printUnionType(nodeIndex),
            .IntersectionType => try self.printIntersectionType(nodeIndex),
            .ConditionalType => try self.printConditionalType(nodeIndex),
            .InferType => try self.printInferType(nodeIndex),
            .ParenthesizedType => try self.printParenthesizedType(nodeIndex),
            .ThisType => try self.printThisType(nodeIndex),
            .TypeOperator => try self.printTypeOperator(nodeIndex),
            .IndexedAccessType => try self.printIndexedAccessType(nodeIndex),
            .MappedType => try self.printMappedType(nodeIndex),
            .LiteralType => try self.printLiteralType(nodeIndex),
            .NamedTupleMember => try self.printNamedTupleMember(nodeIndex),
            .TemplateLiteralType => try self.printTemplateLiteralType(nodeIndex),
            .TemplateLiteralTypeSpan => try self.printTemplateLiteralTypeSpan(nodeIndex),
            .ImportType => try self.printImportType(nodeIndex),
            .ObjectBindingPattern => try self.printObjectBindingPattern(nodeIndex),
            .ArrayBindingPattern => try self.printArrayBindingPattern(nodeIndex),
            .BindingElement => try self.printBindingElement(nodeIndex),
            .ArrayLiteralExpression => try self.printArrayLiteralExpression(nodeIndex),
            .ObjectLiteralExpression => try self.printObjectLiteralExpression(nodeIndex),
            .PropertyAccessExpression => try self.printPropertyAccessExpression(nodeIndex),
            .ElementAccessExpression => try self.printElementAccessExpression(nodeIndex),
            .CallExpression => try self.printCallExpression(nodeIndex),
            .NewExpression => try self.printNewExpression(nodeIndex),
            .TaggedTemplateExpression => try self.printTaggedTemplateExpression(nodeIndex),
            .TypeAssertionExpression => try self.printTypeAssertionExpression(nodeIndex),
            .ParenthesizedExpression => try self.printParenthesizedExpression(nodeIndex),
            .FunctionExpression => try self.printFunctionExpression(nodeIndex),
            .ArrowFunction => try self.printArrowFunction(nodeIndex),
            .DeleteExpression => try self.printDeleteExpression(nodeIndex),
            .TypeOfExpression => try self.printTypeOfExpression(nodeIndex),
            .VoidExpression => try self.printVoidExpression(nodeIndex),
            .AwaitExpression => try self.printAwaitExpression(nodeIndex),
            .PrefixUnaryExpression => try self.printPrefixUnaryExpression(nodeIndex),
            .PostfixUnaryExpression => try self.printPostfixUnaryExpression(nodeIndex),
            .BinaryExpression => try self.printBinaryExpression(nodeIndex),
            .ConditionalExpression => try self.printConditionalExpression(nodeIndex),
            .TemplateExpression => try self.printTemplateExpression(nodeIndex),
            .YieldExpression => try self.printYieldExpression(nodeIndex),
            .SpreadElement => try self.printSpreadElement(nodeIndex),
            .ClassExpression => try self.printClassExpression(nodeIndex),
            .OmittedExpression => try self.printOmittedExpression(nodeIndex),
            .ExpressionWithTypeArguments => try self.printExpressionWithTypeArguments(nodeIndex),
            .AsExpression => try self.printAsExpression(nodeIndex),
            .NonNullExpression => try self.printNonNullExpression(nodeIndex),
            .MetaProperty => try self.printMetaProperty(nodeIndex),
            .SyntheticExpression => try self.printSyntheticExpression(nodeIndex),
            .SatisfiesExpression => try self.printSatisfiesExpression(nodeIndex),
            .TemplateSpan => try self.printTemplateSpan(nodeIndex),
            .SemicolonClassElement => try self.printSemicolonClassElement(nodeIndex),
            .Block => try @import("emit_stmt.zig").printBlock(self, nodeIndex),
            .EmptyStatement => try self.printEmptyStatement(nodeIndex, false),
            .VariableStatement => try self.printVariableStatement(nodeIndex),
            .ExpressionStatement => try self.printExpressionStatement(nodeIndex),
            .IfStatement => try self.printIfStatement(nodeIndex),
            .DoStatement => try self.printDoStatement(nodeIndex),
            .WhileStatement => try self.printWhileStatement(nodeIndex),
            .ForStatement => try self.printForStatement(nodeIndex),
            .ForInStatement => try self.printForInStatement(nodeIndex),
            .ForOfStatement => try self.printForOfStatement(nodeIndex),
            .ContinueStatement => try self.printContinueStatement(nodeIndex),
            .BreakStatement => try self.printBreakStatement(nodeIndex),
            .ReturnStatement => try self.printReturnStatement(nodeIndex),
            .WithStatement => try self.printWithStatement(nodeIndex),
            .SwitchStatement => try self.printSwitchStatement(nodeIndex),
            .LabeledStatement => try self.printLabeledStatement(nodeIndex),
            .ThrowStatement => try self.printThrowStatement(nodeIndex),
            .TryStatement => try self.printTryStatement(nodeIndex),
            .DebuggerStatement => try self.printDebuggerStatement(nodeIndex),
            .VariableDeclaration => try self.printVariableDeclaration(nodeIndex),
            .VariableDeclarationList => try self.printVariableDeclarationList(nodeIndex),
            .FunctionDeclaration => try self.printFunctionDeclaration(nodeIndex),
            .ClassDeclaration => try self.printClassDeclaration(nodeIndex),
            .InterfaceDeclaration => try self.printInterfaceDeclaration(nodeIndex),
            .TypeAliasDeclaration => try self.printTypeAliasDeclaration(nodeIndex),
            .EnumDeclaration => try self.printEnumDeclaration(nodeIndex),
            .ModuleDeclaration => try self.printModuleDeclaration(nodeIndex),
            .ModuleBlock => try self.printModuleBlock(nodeIndex),
            .CaseBlock => try @import("emit_stmt.zig").printCaseBlock(self, nodeIndex),
            .NamespaceExportDeclaration => try self.printNamespaceExportDeclaration(nodeIndex),
            .ImportEqualsDeclaration => try self.printImportEqualsDeclaration(nodeIndex),
            .ImportDeclaration => try self.printImportDeclaration(nodeIndex),
            .ImportClause => try self.printImportClause(nodeIndex),
            .NamespaceImport => try self.printNamespaceImport(nodeIndex),
            .NamedImports => try self.printNamedImports(nodeIndex),
            .ImportSpecifier => try self.printImportSpecifier(nodeIndex),
            .ExportAssignment => try self.printExportAssignment(nodeIndex),
            .ExportDeclaration => try self.printExportDeclaration(nodeIndex),
            .NamedExports => try self.printNamedExports(nodeIndex),
            .NamespaceExport => try self.printNamespaceExport(nodeIndex),
            .ExportSpecifier => try self.printExportSpecifier(nodeIndex),
            .MissingDeclaration => try self.printMissingDeclaration(nodeIndex),
            .ExternalModuleReference => try self.printExternalModuleReference(nodeIndex),
            .JsxElement => try self.printJsxElement(nodeIndex),
            .JsxSelfClosingElement => try self.printJsxSelfClosingElement(nodeIndex),
            .JsxOpeningElement => try self.printJsxOpeningElement(nodeIndex),
            .JsxClosingElement => try self.printJsxClosingElement(nodeIndex),
            .JsxFragment => try self.printJsxFragment(nodeIndex),
            .JsxOpeningFragment => try self.printJsxOpeningFragment(nodeIndex),
            .JsxClosingFragment => try self.printJsxClosingFragment(nodeIndex),
            .JsxAttribute => try self.printJsxAttribute(nodeIndex),
            .JsxAttributes => try self.printJsxAttributes(nodeIndex),
            .JsxSpreadAttribute => try self.printJsxSpreadAttribute(nodeIndex),
            .JsxExpression => try self.printJsxExpression(nodeIndex),
            .JsxNamespacedName => try self.printJsxNamespacedName(nodeIndex),
            .CaseClause => try @import("emit_stmt.zig").printCaseClause(self, nodeIndex),
            .DefaultClause => try @import("emit_stmt.zig").printDefaultClause(self, nodeIndex),
            .HeritageClause => try self.printHeritageClause(nodeIndex),
            .CatchClause => try @import("emit_stmt.zig").printCatchClause(self, nodeIndex),
            .ImportAttributes => try self.printImportAttributes(nodeIndex),
            .ImportAttribute => try self.printImportAttribute(nodeIndex),
            .PropertyAssignment => try self.printPropertyAssignment(nodeIndex),
            .ShorthandPropertyAssignment => try self.printShorthandPropertyAssignment(nodeIndex),
            .SpreadAssignment => try self.printSpreadAssignment(nodeIndex),
            .EnumMember => try @import("emit_decl.zig").printEnumMember(self, nodeIndex),
            .SourceFile => try self.printSourceFile(nodeIndex),
            .JSDocTypeExpression => try self.printJSDocTypeExpression(nodeIndex),
            .JSDocNameReference => try self.printJSDocNameReference(nodeIndex),
            .JSDocAllType => try self.printJSDocAllType(nodeIndex),
            .JSDocNullableType => try self.printJSDocNullableType(nodeIndex),
            .JSDocNonNullableType => try self.printJSDocNonNullableType(nodeIndex),
            .JSDocOptionalType => try self.printJSDocOptionalType(nodeIndex),
            .JSDocVariadicType => try self.printJSDocVariadicType(nodeIndex),
            .JSDoc => try self.printJSDoc(nodeIndex),
            .JSDocText => try self.printJSDocText(nodeIndex),
            .JSDocTypeLiteral => try self.printJSDocTypeLiteral(nodeIndex),
            .JSDocSignature => try self.printJSDocSignature(nodeIndex),
            .JSDocLink => try self.printJSDocLink(nodeIndex),
            .JSDocLinkCode => try self.printJSDocLinkCode(nodeIndex),
            .JSDocLinkPlain => try self.printJSDocLinkPlain(nodeIndex),
            .JSDocUnknownTag => try self.printJSDocUnknownTag(nodeIndex),
            .JSDocAugmentsTag => try self.printJSDocAugmentsTag(nodeIndex),
            .JSDocImplementsTag => try self.printJSDocImplementsTag(nodeIndex),
            .JSDocDeprecatedTag => try self.printJSDocDeprecatedTag(nodeIndex),
            .JSDocPublicTag => try self.printJSDocPublicTag(nodeIndex),
            .JSDocPrivateTag => try self.printJSDocPrivateTag(nodeIndex),
            .JSDocProtectedTag => try self.printJSDocProtectedTag(nodeIndex),
            .JSDocReadonlyTag => try self.printJSDocReadonlyTag(nodeIndex),
            .JSDocOverrideTag => try self.printJSDocOverrideTag(nodeIndex),
            .JSDocCallbackTag => try self.printJSDocCallbackTag(nodeIndex),
            .JSDocOverloadTag => try self.printJSDocOverloadTag(nodeIndex),
            .JSDocParameterTag => try self.printJSDocParameterTag(nodeIndex),
            .JSDocReturnTag => try self.printJSDocReturnTag(nodeIndex),
            .JSDocThisTag => try self.printJSDocThisTag(nodeIndex),
            .JSDocTypeTag => try self.printJSDocTypeTag(nodeIndex),
            .JSDocTemplateTag => try self.printJSDocTemplateTag(nodeIndex),
            .JSDocTypedefTag => try self.printJSDocTypedefTag(nodeIndex),
            .JSDocSeeTag => try self.printJSDocSeeTag(nodeIndex),
            .JSDocPropertyTag => try self.printJSDocPropertyTag(nodeIndex),
            .JSDocThrowsTag => try self.printJSDocThrowsTag(nodeIndex),
            .JSDocSatisfiesTag => try self.printJSDocSatisfiesTag(nodeIndex),
            .JSDocImportTag => try self.printJSDocImportTag(nodeIndex),
            .SyntaxList => try self.printSyntaxList(nodeIndex),
            .JSTypeAliasDeclaration => try self.printJSTypeAliasDeclaration(nodeIndex),
            .JSImportDeclaration => try self.printJSImportDeclaration(nodeIndex),
            .NotEmittedStatement => try self.printNotEmittedStatement(nodeIndex),
            .PartiallyEmittedExpression => try self.printPartiallyEmittedExpression(nodeIndex),
            .SyntheticReferenceExpression => try self.printSyntheticReferenceExpression(nodeIndex),
            .NotEmittedTypeElement => try self.printNotEmittedTypeElement(nodeIndex),
        }
    }

    fn recordSourceMapping(self: *Printer, nodeIndex: ast_mod.NodeIndex) void {
        const hook = self.sourceMapHook orelse return;
        var original = nodeIndex;
        var depth: usize = 0;
        while (depth < 16) : (depth += 1) {
            const next = self.context.getOriginal(original);
            if (next == 0 or next == original) break;
            original = next;
        }
        if (original >= self.tree.positions.items.len) return;
        const range = self.tree.positions.items[original];
        if (range.end <= range.pos or range.pos >= self.tree.sourceText.len) return;

        var low: usize = 0;
        var high = self.sourceLineStarts.len;
        while (low < high) {
            const middle = low + (high - low) / 2;
            if (self.sourceLineStarts[middle] <= range.pos) low = middle + 1 else high = middle;
        }
        const line = if (low == 0) 0 else low - 1;
        const column = range.pos - self.sourceLineStarts[line];
        hook.addMapping(hook.context, self.writer.getLine(), self.writer.getColumn(), line, column);
    }

    fn printTriviaText(self: *Printer, nodeIndex: ast_mod.NodeIndex) void {
        if (nodeIndex >= self.tree.positions.items.len) return;
        const range = self.tree.positions.items[nodeIndex];
        if (range.end <= range.pos or range.end > self.tree.sourceText.len) return;
        self.writer.write(self.tree.sourceText[range.pos..range.end]);
    }

    pub const printNumericLiteral = @import("emit_expr.zig").printNumericLiteral;
    pub const printBigIntLiteral = @import("emit_expr.zig").printBigIntLiteral;
    pub const printStringLiteral = @import("emit_expr.zig").printStringLiteral;
    pub const printRegularExpressionLiteral = @import("emit_expr.zig").printRegularExpressionLiteral;
    pub const printNoSubstitutionTemplateLiteral = @import("emit_expr.zig").printNoSubstitutionTemplateLiteral;
    pub const printIdentifier = @import("emit_expr.zig").printIdentifier;
    pub const printPrivateIdentifier = @import("emit_expr.zig").printPrivateIdentifier;
    pub const printArrayLiteralExpression = @import("emit_expr.zig").printArrayLiteralExpression;
    pub const printObjectLiteralExpression = @import("emit_expr.zig").printObjectLiteralExpression;
    pub const printPropertyAccessExpression = @import("emit_expr.zig").printPropertyAccessExpression;
    pub const printElementAccessExpression = @import("emit_expr.zig").printElementAccessExpression;
    pub const printCallExpression = @import("emit_expr.zig").printCallExpression;
    pub const printNewExpression = @import("emit_expr.zig").printNewExpression;
    pub const printTaggedTemplateExpression = @import("emit_expr.zig").printTaggedTemplateExpression;
    pub const printTypeAssertionExpression = @import("emit_expr.zig").printTypeAssertionExpression;
    pub const printParenthesizedExpression = @import("emit_expr.zig").printParenthesizedExpression;
    pub const printFunctionExpression = @import("emit_expr.zig").printFunctionExpression;
    pub const printArrowFunction = @import("emit_expr.zig").printArrowFunction;
    pub const printDeleteExpression = @import("emit_expr.zig").printDeleteExpression;
    pub const printTypeOfExpression = @import("emit_expr.zig").printTypeOfExpression;
    pub const printVoidExpression = @import("emit_expr.zig").printVoidExpression;
    pub const printAwaitExpression = @import("emit_expr.zig").printAwaitExpression;
    pub const printPrefixUnaryExpression = @import("emit_expr.zig").printPrefixUnaryExpression;
    pub const printPostfixUnaryExpression = @import("emit_expr.zig").printPostfixUnaryExpression;
    pub const printBinaryExpression = @import("emit_expr.zig").printBinaryExpression;
    pub const printConditionalExpression = @import("emit_expr.zig").printConditionalExpression;
    pub const printTemplateExpression = @import("emit_expr.zig").printTemplateExpression;
    pub const printYieldExpression = @import("emit_expr.zig").printYieldExpression;
    pub const printSpreadElement = @import("emit_expr.zig").printSpreadElement;
    pub const printClassExpression = @import("emit_expr.zig").printClassExpression;
    pub const printOmittedExpression = @import("emit_expr.zig").printOmittedExpression;
    pub const printAsExpression = @import("emit_expr.zig").printAsExpression;
    pub const printNonNullExpression = @import("emit_expr.zig").printNonNullExpression;
    pub const printExpressionWithTypeArguments = @import("emit_expr.zig").printExpressionWithTypeArguments;
    pub const printSatisfiesExpression = @import("emit_expr.zig").printSatisfiesExpression;
    pub const printPartiallyEmittedExpression = @import("emit_expr.zig").printPartiallyEmittedExpression;
    pub const isEmptyBlock = @import("emit_stmt.zig").isEmptyBlock;
    pub const printBlock = @import("emit_stmt.zig").printBlock;
    pub const printVariableStatement = @import("emit_stmt.zig").printVariableStatement;
    pub const printEmptyStatement = @import("emit_stmt.zig").printEmptyStatement;
    pub const printExpressionStatement = @import("emit_stmt.zig").printExpressionStatement;
    pub const printIIFEWithParenthesizedCallee = @import("emit_stmt.zig").printIIFEWithParenthesizedCallee;
    pub const printIfStatement = @import("emit_stmt.zig").printIfStatement;
    pub const printWhileClause = @import("emit_stmt.zig").printWhileClause;
    pub const printDoStatement = @import("emit_stmt.zig").printDoStatement;
    pub const printWhileStatement = @import("emit_stmt.zig").printWhileStatement;
    pub const printForInitializer = @import("emit_stmt.zig").printForInitializer;
    pub const printForStatement = @import("emit_stmt.zig").printForStatement;
    pub const printForInStatement = @import("emit_stmt.zig").printForInStatement;
    pub const printForOfStatement = @import("emit_stmt.zig").printForOfStatement;
    pub const printContinueStatement = @import("emit_stmt.zig").printContinueStatement;
    pub const printBreakStatement = @import("emit_stmt.zig").printBreakStatement;
    pub const printReturnStatement = @import("emit_stmt.zig").printReturnStatement;
    pub const printWithStatement = @import("emit_stmt.zig").printWithStatement;
    pub const printSwitchStatement = @import("emit_stmt.zig").printSwitchStatement;
    pub const printLabeledStatement = @import("emit_stmt.zig").printLabeledStatement;
    pub const printThrowStatement = @import("emit_stmt.zig").printThrowStatement;
    pub const printTryStatement = @import("emit_stmt.zig").printTryStatement;
    pub const printDebuggerStatement = @import("emit_stmt.zig").printDebuggerStatement;
    pub const printNotEmittedStatement = @import("emit_stmt.zig").printNotEmittedStatement;
    pub const printVariableDeclaration = @import("emit_decl.zig").printVariableDeclaration;
    pub const printVariableDeclarationList = @import("emit_decl.zig").printVariableDeclarationList;
    pub const printFunctionDeclaration = @import("emit_decl.zig").printFunctionDeclaration;
    pub const printClassDeclaration = @import("emit_decl.zig").printClassDeclaration;
    pub const printInterfaceDeclaration = @import("emit_decl.zig").printInterfaceDeclaration;
    pub const printTypeAliasDeclaration = @import("emit_decl.zig").printTypeAliasDeclaration;
    pub const printEnumDeclaration = @import("emit_decl.zig").printEnumDeclaration;
    pub const printModuleDeclaration = @import("emit_decl.zig").printModuleDeclaration;
    pub const printParameter = @import("emit_decl.zig").printParameter;
    pub const printPropertyDeclaration = @import("emit_decl.zig").printPropertyDeclaration;
    pub const printList = @import("emit_list.zig").printList;
    pub const printModifiers = @import("emit_list.zig").printModifiers;
    pub const printTypeArguments = @import("emit_list.zig").printTypeArguments;
    pub const printTypeParameters = @import("emit_list.zig").printTypeParameters;
    pub fn printUnknown(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        _ = self;
        _ = nodeIndex;
    }
    pub fn printEndOfFile(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        _ = self;
        _ = nodeIndex;
    }
    pub fn printSingleLineCommentTrivia(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        self.printTriviaText(nodeIndex);
    }
    pub fn printMultiLineCommentTrivia(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        self.printTriviaText(nodeIndex);
    }
    pub fn printNewLineTrivia(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        _ = nodeIndex;
        self.writer.writeLine();
    }
    pub fn printWhitespaceTrivia(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        self.printTriviaText(nodeIndex);
    }
    pub fn printConflictMarkerTrivia(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        self.printTriviaText(nodeIndex);
    }
    pub fn printNonTextFileMarkerTrivia(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        self.printTriviaText(nodeIndex);
    }
    pub fn printJsxText(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JsxText;
        self.writer.writeLiteral(node.Text);
    }
    pub fn printJsxTextAllWhiteSpaces(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        // The parser intentionally represents all-whitespace JSX text without
        // payload; its normalized spacing is handled by the surrounding list.
        _ = self;
        _ = nodeIndex;
    }
    pub fn printTemplateHead(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).TemplateHead;
        self.writer.writeLiteral("`");
        self.writer.writeLiteral(node.Text);
        self.writer.writeLiteral("${");
    }
    pub fn printTemplateMiddle(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).TemplateMiddle;
        self.writer.writeLiteral("}");
        self.writer.writeLiteral(node.Text);
        self.writer.writeLiteral("${");
    }
    pub fn printTemplateTail(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).TemplateTail;
        self.writer.writeLiteral("}");
        self.writer.writeLiteral(node.Text);
        self.writer.writeLiteral("`");
    }
    pub fn printOpenBraceToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printCloseBraceToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printOpenParenToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printCloseParenToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printOpenBracketToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printCloseBracketToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printDotToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printDotDotDotToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printSemicolonToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printCommaToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printQuestionDotToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printLessThanToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printLessThanSlashToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printGreaterThanToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printLessThanEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printGreaterThanEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printEqualsEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printExclamationEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printEqualsEqualsEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printExclamationEqualsEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printEqualsGreaterThanToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printPlusToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printMinusToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printAsteriskToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printAsteriskAsteriskToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printSlashToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printPercentToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printPlusPlusToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printMinusMinusToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printLessThanLessThanToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printGreaterThanGreaterThanToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printGreaterThanGreaterThanGreaterThanToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printAmpersandToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printBarToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printCaretToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printExclamationToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printTildeToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printAmpersandAmpersandToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printBarBarToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printQuestionToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printColonToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printAtToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printQuestionQuestionToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printBacktickToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printHashToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printPlusEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printMinusEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printAsteriskEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printAsteriskAsteriskEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printSlashEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printPercentEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printLessThanLessThanEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printGreaterThanGreaterThanEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printGreaterThanGreaterThanGreaterThanEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printAmpersandEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printBarEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printBarBarEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printAmpersandAmpersandEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printQuestionQuestionEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printCaretEqualsToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printJSDocCommentTextToken(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printBreakKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printCaseKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printCatchKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printClassKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printConstKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printContinueKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printDebuggerKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printDefaultKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printDeleteKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printDoKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printElseKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printEnumKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printExportKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printExtendsKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printFalseKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printFinallyKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printForKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printFunctionKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printIfKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printImportKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printInKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printInstanceOfKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printNewKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printNullKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printReturnKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printSuperKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printSwitchKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printThisKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printThrowKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printTrueKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printTryKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printTypeOfKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printVarKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printVoidKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printWhileKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printWithKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printImplementsKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printInterfaceKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printLetKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printPackageKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printPrivateKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printProtectedKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printPublicKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printStaticKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printYieldKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printAbstractKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printAccessorKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printAsKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printAssertsKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printAssertKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printDeferKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printAnyKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printAsyncKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printAwaitKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printBooleanKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printConstructorKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printDeclareKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printGetKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printImmediateKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printInferKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printIntrinsicKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printIsKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printKeyOfKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printModuleKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printNamespaceKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printNeverKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printOutKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printReadonlyKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printRequireKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printNumberKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printObjectKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printSatisfiesKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printSetKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printStringKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printSymbolKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printTypeKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printUndefinedKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printUniqueKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printUnknownKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printUsingKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printFromKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printGlobalKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printBigIntKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printOverrideKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printOfKeyword(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.emitTokenNode(nodeIndex);
    }
    pub fn printQualifiedName(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).QualifiedName;
        try self.printNode(node.Left);
        self.writer.writePunctuation(".");
        try self.printNode(node.Right);
    }
    pub fn printComputedPropertyName(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ComputedPropertyName;
        self.writer.writePunctuation("[");
        try self.printNode(node.Expression);
        self.writer.writePunctuation("]");
    }
    pub fn printTypeParameter(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).TypeParameter;
        if (node.modifiers != null and node.modifiers.? != 0) {
            try self.printModifiers(node.modifiers.?);
        }
        try self.printNode(node.name);
        if (node.Constraint != null and node.Constraint.? != 0) {
            self.writer.writeSpace(" ");
            self.writer.writeKeyword("extends");
            self.writer.writeSpace(" ");
            try self.printNode(node.Constraint.?);
        }
        if (node.DefaultType != null and node.DefaultType.? != 0) {
            self.writer.writeSpace(" ");
            self.writer.writeOperator("=");
            self.writer.writeSpace(" ");
            try self.printNode(node.DefaultType.?);
        }
    }
    pub const printDecorator = @import("emit_decl.zig").printDecorator;
    pub fn printPropertySignature(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).PropertySignature;
        if (node.modifiers) |modifiers| {
            try self.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
        }
        try self.printNode(node.name);
        if (node.PostfixToken) |postfix| {
            try self.printNode(postfix);
        }
        if (node.Type != null and node.Type.? != 0) {
            self.writer.writePunctuation(":");
            self.writer.writeSpace(" ");
            try self.printNode(node.Type.?);
        }
        self.writer.writeTrailingSemicolon(";");
    }
    pub fn printMethodSignature(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).MethodSignature;
        if (node.modifiers) |modifiers| {
            try self.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
        }
        try self.printNode(node.name);
        if (node.PostfixToken) |postfix| {
            try self.printNode(postfix);
        }
        if (node.TypeParameters) |typeParams| {
            try self.printList(@import("emit_list.zig").ListFormat.TypeParameters, typeParams);
        }
        try self.printList(@import("emit_list.zig").ListFormat.Parameters, node.Parameters);
        if (node.Type != null and node.Type.? != 0) {
            self.writer.writePunctuation(":");
            self.writer.writeSpace(" ");
            try self.printNode(node.Type.?);
        }
        self.writer.writeTrailingSemicolon(";");
    }
    pub fn printMethodDeclaration(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).MethodDeclaration;

        try self.printModifiers(node.modifiers orelse 0);

        if (node.AsteriskToken) |t| {
            try self.printNode(t);
        }

        try self.printNode(node.name);

        if (node.PostfixToken) |t| {
            try self.printNode(t);
        }

        try @import("emit_decl.zig").printSignature(self, nodeIndex);

        if (node.Body) |b| {
            self.writer.writeSpace(" ");
            try @import("emit_stmt.zig").printFunctionBody(self, b);
        } else {
            self.writer.writeTrailingSemicolon(";");
        }
    }
    pub fn printClassStaticBlockDeclaration(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ClassStaticBlockDeclaration;
        self.writer.writeKeyword("static");
        self.writer.writeSpace(" ");
        const body = self.tree.getNode(node.Body).Block;
        if (!body.MultiLine) {
            self.writer.writePunctuation("{");
            self.writer.writeSpace(" ");
            const statements = self.tree.getNodeList(body.Statements);
            for (statements, 0..) |statement, index| {
                if (index > 0) self.writer.writeSpace(" ");
                try self.printNode(statement);
            }
            if (statements.len != 0) self.writer.writeSpace(" ");
            self.writer.writePunctuation("}");
        } else {
            try self.printNode(node.Body);
        }
    }
    pub fn printConstructor(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).Constructor;
        try @import("emit_list.zig").printModifiersEx(self, node.modifiers orelse 0, false);
        self.writer.writeKeyword("constructor");
        try @import("emit_decl.zig").printSignature(self, nodeIndex);
        if (node.Body) |b| {
            self.writer.writeSpace(" ");
            try @import("emit_stmt.zig").printFunctionBody(self, b);
        } else {
            self.writer.writeTrailingSemicolon(";");
        }
    }
    pub fn printGetAccessor(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).GetAccessor;
        try self.printModifiers(node.modifiers orelse 0);
        self.writer.writeKeyword("get");
        self.writer.writeSpace(" ");
        try self.printNode(node.name);
        try @import("emit_decl.zig").printSignature(self, nodeIndex);
        if (node.Body) |b| {
            self.writer.writeSpace(" ");
            try @import("emit_stmt.zig").printFunctionBody(self, b);
        } else {
            self.writer.writeTrailingSemicolon(";");
        }
    }
    pub fn printSetAccessor(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).SetAccessor;
        try self.printModifiers(node.modifiers orelse 0);
        self.writer.writeKeyword("set");
        self.writer.writeSpace(" ");
        try self.printNode(node.name);
        try @import("emit_decl.zig").printSignature(self, nodeIndex);
        if (node.Body) |b| {
            self.writer.writeSpace(" ");
            try @import("emit_stmt.zig").printFunctionBody(self, b);
        } else {
            self.writer.writeTrailingSemicolon(";");
        }
    }
    pub fn printCallSignature(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).CallSignature;
        if (node.TypeParameters != null and node.TypeParameters.? != 0) {
            try self.printList(@import("emit_list.zig").ListFormat.TypeParameters, node.TypeParameters.?);
        }
        try self.printList(@import("emit_list.zig").ListFormat.Parameters, node.Parameters);
        if (node.Type != null and node.Type.? != 0) {
            self.writer.writePunctuation(":");
            self.writer.writeSpace(" ");
            try self.printNode(node.Type.?);
        }
        self.writer.writeTrailingSemicolon(";");
    }
    pub fn printConstructSignature(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ConstructSignature;
        self.writer.writeKeyword("new");
        self.writer.writeSpace(" ");
        if (node.TypeParameters != null and node.TypeParameters.? != 0) {
            try self.printList(@import("emit_list.zig").ListFormat.TypeParameters, node.TypeParameters.?);
        }
        try self.printList(@import("emit_list.zig").ListFormat.Parameters, node.Parameters);
        if (node.Type != null and node.Type.? != 0) {
            self.writer.writePunctuation(":");
            self.writer.writeSpace(" ");
            try self.printNode(node.Type.?);
        }
        self.writer.writeTrailingSemicolon(";");
    }
    pub fn printIndexSignature(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).IndexSignature;
        if (node.modifiers != null and node.modifiers.? != 0) {
            try self.emitList(null, nodeIndex, node.modifiers.?, @import("emit_list.zig").ListFormat.Modifiers);
        }
        self.writer.writePunctuation("[");
        try self.printList(@import("emit_list.zig").ListFormat.IndexSignatureParameters, node.Parameters);
        self.writer.writePunctuation("]");
        if (node.Type != null and node.Type.? != 0) {
            self.writer.writePunctuation(":");
            self.writer.writeSpace(" ");
            try self.printNode(node.Type.?);
        }
        self.writer.writeTrailingSemicolon(";");
    }
    pub fn printTypePredicate(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex);
        if (node.TypePredicate.AssertsModifier) |assertsModifier| {
            try self.printNode(assertsModifier);
            self.writer.writeSpace(" ");
        }
        try self.printNode(node.TypePredicate.ParameterName);
        if (node.TypePredicate.Type != null and node.TypePredicate.Type.? != 0) {
            self.writer.writeSpace(" ");
            self.writer.writeKeyword("is");
            self.writer.writeSpace(" ");
            try self.printNode(node.TypePredicate.Type.?);
        }
    }
    pub fn printTypeReference(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).TypeReference;
        try self.printNode(node.TypeName);
        if (node.TypeArguments != null and node.TypeArguments.? != 0) {
            try self.printTypeArguments(node.TypeArguments.?);
        }
    }
    pub fn printFunctionType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).FunctionType;
        if (node.modifiers) |modifiers| {
            try self.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
        }
        if (node.TypeParameters) |typeParams| {
            try self.printList(@import("emit_list.zig").ListFormat.TypeParameters, typeParams);
        }
        try self.printList(@import("emit_list.zig").ListFormat.Parameters, node.Parameters);
        if (node.Type) |typeNode| {
            self.writer.writeSpace(" ");
            self.writer.writePunctuation("=>");
            self.writer.writeSpace(" ");
            try self.printNode(typeNode);
        }
    }

    pub fn printConstructorType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ConstructorType;
        if (node.modifiers) |modifiers| {
            try self.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
        }
        self.writer.writeKeyword("new");
        self.writer.writeSpace(" ");
        if (node.TypeParameters) |typeParams| {
            try self.printList(@import("emit_list.zig").ListFormat.TypeParameters, typeParams);
        }
        try self.printList(@import("emit_list.zig").ListFormat.Parameters, node.Parameters);
        if (node.Type) |typeNode| {
            self.writer.writeSpace(" ");
            self.writer.writePunctuation("=>");
            self.writer.writeSpace(" ");
            try self.printNode(typeNode);
        }
    }
    pub fn printTypeQuery(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).TypeQuery;
        self.writer.writeKeyword("typeof");
        self.writer.writeSpace(" ");
        try self.printNode(node.ExprName);
        if (node.TypeArguments) |typeArgs| {
            try self.printTypeArguments(typeArgs);
        }
    }
    pub fn printTypeLiteral(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).TypeLiteral;
        self.writer.writePunctuation("{");

        const listLen = self.tree.getNodeList(node.Members).len;
        if (listLen > 0) {
            try self.printList(@import("emit_list.zig").ListFormat.TypeLiteralMembers, node.Members);
        }

        self.writer.writePunctuation("}");
    }
    pub fn printArrayType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ArrayType;
        try self.printNode(node.ElementType);
        self.writer.writePunctuation("[");
        self.writer.writePunctuation("]");
    }
    pub fn printTupleType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).TupleType;
        self.writer.writePunctuation("[");
        const format = if ((node.Flags & @import("../ast/ast_utils.zig").NodeFlags.Synthesized) != 0)
            @import("emit_list.zig").ListFormat.CommaDelimited | @import("emit_list.zig").ListFormat.SpaceBetweenSiblings | @import("emit_list.zig").ListFormat.SingleLine
        else
            @import("emit_list.zig").ListFormat.TupleTypeElements;
        try self.printList(format, node.Elements);
        self.writer.writePunctuation("]");
    }
    pub fn printOptionalType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).OptionalType;
        try self.printNode(node.Type);
        self.writer.writePunctuation("?");
    }
    pub fn printRestType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).RestType;
        self.writer.writePunctuation("...");
        try self.printNode(node.Type);
    }
    pub fn printUnionType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).UnionType;
        try self.printList(@import("emit_list.zig").ListFormat.UnionTypeElements, node.Types);
    }
    pub fn printIntersectionType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).IntersectionType;
        try self.printList(@import("emit_list.zig").ListFormat.IntersectionTypeElements, node.Types);
    }
    pub fn printConditionalType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ConditionalType;
        try self.printNode(node.CheckType);
        self.writer.writeSpace(" ");
        self.writer.writeKeyword("extends");
        self.writer.writeSpace(" ");
        try self.printNode(node.ExtendsType);
        self.writer.writeSpace(" ");
        self.writer.writePunctuation("?");
        self.writer.writeSpace(" ");
        try self.printNode(node.TrueType);
        self.writer.writeSpace(" ");
        self.writer.writePunctuation(":");
        self.writer.writeSpace(" ");
        try self.printNode(node.FalseType);
    }
    pub fn printInferType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).InferType;
        self.writer.writeKeyword("infer");
        self.writer.writeSpace(" ");
        try self.printNode(node.TypeParameter);
    }
    pub fn printParenthesizedType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ParenthesizedType;
        self.writer.writePunctuation("(");
        try self.printNode(node.Type);
        self.writer.writePunctuation(")");
    }
    pub fn printThisType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        _ = nodeIndex;
        self.writer.writeKeyword("this");
    }
    pub fn printTypeOperator(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).TypeOperator;
        const opKind = @as(@import("../ast/kind.zig").Kind, @enumFromInt(node.Operator));
        if (opKind == .KeyOfKeyword) {
            self.writer.writeKeyword("keyof");
        } else if (opKind == .UniqueKeyword) {
            self.writer.writeKeyword("unique");
        } else if (opKind == .ReadonlyKeyword) {
            self.writer.writeKeyword("readonly");
        }
        self.writer.writeSpace(" ");
        try self.printNode(node.Type);
    }
    pub fn printIndexedAccessType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).IndexedAccessType;
        try self.printNode(node.ObjectType);
        self.writer.writePunctuation("[");
        try self.printNode(node.IndexType);
        self.writer.writePunctuation("]");
    }
    pub fn printMappedType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).MappedType;
        self.writer.writePunctuation("{");
        self.writer.writeLine();
        self.writer.increaseIndent();
        if (node.ReadonlyToken) |r| {
            const rTag = std.meta.activeTag(self.tree.getNode(r));
            try self.printNode(r);
            if (rTag != .ReadonlyKeyword) {
                self.writer.writeKeyword("readonly");
            }
            self.writer.writeSpace(" ");
        }
        self.writer.writePunctuation("[");
        const typeParamNode = self.tree.getNode(node.TypeParameter).TypeParameter;
        if (typeParamNode.modifiers != null and typeParamNode.modifiers.? != 0) {
            try self.printModifiers(typeParamNode.modifiers.?);
        }
        try self.printNode(typeParamNode.name);
        if (typeParamNode.Constraint != null and typeParamNode.Constraint.? != 0) {
            self.writer.writeSpace(" ");
            self.writer.writeKeyword("in");
            self.writer.writeSpace(" ");
            try self.printNode(typeParamNode.Constraint.?);
        }
        if (node.NameType) |name| {
            self.writer.writeSpace(" ");
            self.writer.writeKeyword("as");
            self.writer.writeSpace(" ");
            try self.printNode(name);
        }
        self.writer.writePunctuation("]");
        if (node.QuestionToken) |q| {
            const qTag = std.meta.activeTag(self.tree.getNode(q));
            try self.printNode(q);
            if (qTag != .QuestionToken) {
                self.writer.writePunctuation("?");
            }
        }
        if (node.Type != null and node.Type.? != 0) {
            self.writer.writePunctuation(":");
            self.writer.writeSpace(" ");
            try self.printNode(node.Type.?);
        }
        self.writer.writePunctuation(";");
        if (node.Members) |members| {
            if (self.tree.getNodeList(members).len > 0) {
                self.writer.writeLine();
                try self.printList(@import("emit_list.zig").ListFormat.TypeLiteralMembers & ~@import("emit_list.zig").ListFormat.Indented, members);
            }
        }
        self.writer.decreaseIndent();
        self.writer.writeLine();
        self.writer.writePunctuation("}");
    }
    pub fn printLiteralType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex);
        try self.printNode(node.LiteralType.Literal);
    }
    pub fn printNamedTupleMember(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).NamedTupleMember;
        if (node.DotDotDotToken) |dot| {
            try self.printNode(dot);
        }
        try self.printNode(node.name);
        if (node.QuestionToken) |q| {
            try self.printNode(q);
        }
        self.writer.writePunctuation(":");
        self.writer.writeSpace(" ");
        try self.printNode(node.Type);
    }
    pub fn printTemplateLiteralType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).TemplateLiteralType;
        try self.printNode(node.Head);
        if (node.TemplateSpans != 0) {
            try self.printList(0, node.TemplateSpans);
        }
    }
    pub fn printTemplateLiteralTypeSpan(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).TemplateLiteralTypeSpan;
        try self.printNode(node.Type);
        try self.printNode(node.Literal);
    }
    pub fn printImportType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ImportType;
        if (node.IsTypeOf != 0) {
            self.writer.writeKeyword("typeof ");
        }
        self.writer.writeKeyword("import");
        self.writer.writePunctuation("(");
        try self.printNode(node.Argument);
        if (node.Attributes != null and node.Attributes.? != 0) {
            self.writer.writePunctuation(",");
            self.writer.writeSpace(" ");

            const attrNode = self.tree.getNode(node.Attributes.?).ImportAttributes;
            self.writer.writePunctuation("{");
            self.writer.writeSpace(" ");
            if (attrNode.Token == @intFromEnum(@import("../ast/kind.zig").Kind.WithKeyword)) {
                self.writer.writeKeyword("with");
            } else {
                self.writer.writeKeyword("assert");
            }
            self.writer.writePunctuation(":");
            self.writer.writeSpace(" ");
            try self.emitList(null, node.Attributes.?, attrNode.Attributes, @import("emit_list.zig").ListFormat.ImportAttributesElements);
            self.writer.writeSpace(" ");
            self.writer.writePunctuation("}");
        }
        self.writer.writePunctuation(")");
        if (node.Qualifier != null and node.Qualifier.? != 0) {
            self.writer.writePunctuation(".");
            try self.printNode(node.Qualifier.?);
        }
        if (node.TypeArguments != null and node.TypeArguments.? != 0) {
            try self.printTypeArguments(node.TypeArguments.?);
        }
    }
    pub fn printObjectBindingPattern(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ObjectBindingPattern;
        self.writer.writePunctuation("{");
        try self.printList(@import("emit_list.zig").ListFormat.ObjectBindingPatternElements, node.Elements);
        self.writer.writePunctuation("}");
    }
    pub fn printArrayBindingPattern(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ArrayBindingPattern;
        self.writer.writePunctuation("[");
        try self.printList(@import("emit_list.zig").ListFormat.ArrayBindingPatternElements, node.Elements);
        self.writer.writePunctuation("]");
    }
    pub fn printBindingElement(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).BindingElement;
        if (node.DotDotDotToken) |t| {
            if (t != 0) try self.printNode(t);
        }
        if (node.PropertyName) |pn| {
            if (pn != 0) {
                try self.printNode(pn);
                self.writer.writePunctuation(":");
                self.writer.writeSpace(" ");
            }
        }
        if (node.name) |n| {
            if (n != 0) {
                try self.printNode(n);
                if (node.Initializer) |init_val| {
                    if (init_val != 0) {
                        self.writer.writeSpace(" ");
                        self.writer.writeOperator("=");
                        self.writer.writeSpace(" ");
                        try self.printNode(init_val);
                    }
                }
            }
        }
    }
    pub fn printMetaProperty(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        return @import("emit_expr.zig").printMetaProperty(self, nodeIndex);
    }
    pub fn printSyntheticExpression(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        _ = self;
        _ = nodeIndex;
    }
    pub fn printTemplateSpan(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).TemplateSpan;
        try self.printNode(node.Expression);
        try self.printNode(node.Literal);
    }
    pub fn printSemicolonClassElement(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        _ = nodeIndex;
        self.writer.writeTrailingSemicolon(";");
    }
    pub fn printModuleBlock(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ModuleBlock;
        self.writer.writePunctuation("{");

        const statements = node.Statements;
        const statementsList = if (statements == 0) &[_]ast_mod.NodeIndex{} else self.tree.getNodeList(statements);

        if (statementsList.len == 0) {
            self.writer.writeSpace(" ");
        } else {
            const format = @import("emit_list.zig").ListFormat.MultiLineBlockStatements;
            try self.emitList(Printer.printNode, nodeIndex, statements, format);
        }

        self.writer.writePunctuation("}");
    }
    pub fn printNamespaceExportDeclaration(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).NamespaceExportDeclaration;
        if (node.modifiers) |modifiers| {
            try self.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
        }
        self.writer.writeKeyword("export");
        self.writer.writeSpace(" ");
        self.writer.writeKeyword("as");
        self.writer.writeSpace(" ");
        self.writer.writeKeyword("namespace");
        self.writer.writeSpace(" ");
        try self.printNode(node.name);
        self.writer.writePunctuation(";");
    }
    pub fn printImportEqualsDeclaration(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ImportEqualsDeclaration;
        if (node.modifiers) |modifiers| {
            try self.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
        }
        self.writer.writeKeyword("import");
        self.writer.writeSpace(" ");
        if (node.IsTypeOnly != 0) {
            self.writer.writeKeyword("type");
            self.writer.writeSpace(" ");
        }
        try self.printNode(node.name);
        self.writer.writeSpace(" ");
        self.writer.writePunctuation("=");
        self.writer.writeSpace(" ");
        try self.printNode(node.ModuleReference);
        self.writer.writeTrailingSemicolon(";");
    }
    pub fn printImportDeclaration(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ImportDeclaration;
        if (node.modifiers) |modifiers| {
            try self.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
        }
        self.writer.writeKeyword("import");
        self.writer.writeSpace(" ");
        if (node.ImportClause) |importClause| {
            if (importClause != 0) {
                try self.printNode(importClause);
                self.writer.writeSpace(" ");
                self.writer.writeKeyword("from");
                self.writer.writeSpace(" ");
            }
        }
        try self.printNode(node.ModuleSpecifier);
        if (node.Attributes) |attributes| {
            self.writer.writeSpace(" ");
            try self.printNode(attributes);
        }
        self.writer.writeTrailingSemicolon(";");
    }
    pub fn printImportClause(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ImportClause;
        if (node.PhaseModifier) |phaseMod| {
            if (phaseMod != 0) {
                self.writer.writeKeyword("type");
                self.writer.writeSpace(" ");
            }
        }
        if (node.name) |name| {
            if (name != 0) {
                try self.printNode(name);
                if (node.NamedBindings) |bindings| {
                    if (bindings != 0) {
                        self.writer.writePunctuation(",");
                        self.writer.writeSpace(" ");
                    }
                }
            }
        }
        if (node.NamedBindings) |bindings| {
            if (bindings != 0) {
                try self.printNode(bindings);
            }
        }
    }
    pub fn printNamespaceImport(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).NamespaceImport;
        self.writer.writePunctuation("*");
        self.writer.writeSpace(" ");
        self.writer.writeKeyword("as");
        self.writer.writeSpace(" ");
        try self.printNode(node.name);
    }
    pub fn printNamedImports(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).NamedImports;
        self.writer.writePunctuation("{");
        try self.emitList(null, nodeIndex, node.Elements, @import("emit_list.zig").ListFormat.NamedImportsOrExportsElements);
        self.writer.writePunctuation("}");
    }
    pub fn printImportSpecifier(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ImportSpecifier;
        if (node.IsTypeOnly != 0) {
            self.writer.writeKeyword("type");
            self.writer.writeSpace(" ");
        }
        if (node.PropertyName) |propName| {
            if (propName != 0) {
                try self.printNode(propName);
                self.writer.writeSpace(" ");
                self.writer.writeKeyword("as");
                self.writer.writeSpace(" ");
            }
        }
        try self.printNode(node.name);
    }
    pub fn printExportAssignment(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ExportAssignment;

        if (node.modifiers) |modifiers| {
            try self.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
        }

        self.writer.writeKeyword("export");
        self.writer.writeSpace(" ");
        if (node.IsExportEquals != 0) {
            self.writer.writePunctuation("=");
        } else {
            self.writer.writeKeyword("default");
        }
        self.writer.writeSpace(" ");
        try self.printNode(node.Expression);
        self.writer.writePunctuation(";");
    }
    pub fn printExportDeclaration(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ExportDeclaration;
        if (node.modifiers) |modifiers| {
            try self.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
        }
        self.writer.writeKeyword("export");
        self.writer.writeSpace(" ");
        if (node.IsTypeOnly != 0) {
            self.writer.writeKeyword("type");
            self.writer.writeSpace(" ");
        }
        if (node.ExportClause) |exportClause| {
            if (exportClause != 0) {
                try self.printNode(exportClause);
            } else {
                self.writer.writePunctuation("*");
            }
        } else {
            self.writer.writePunctuation("*");
        }
        if (node.ModuleSpecifier) |moduleSpecifier| {
            if (moduleSpecifier != 0) {
                self.writer.writeSpace(" ");
                self.writer.writeKeyword("from");
                self.writer.writeSpace(" ");
                try self.printNode(moduleSpecifier);
            }
        }
        if (node.Attributes) |attributes| {
            if (attributes != 0) {
                self.writer.writeSpace(" ");
                try self.printNode(attributes);
            }
        }
        self.writer.writePunctuation(";");
    }
    pub fn printNamedExports(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).NamedExports;
        self.writer.writePunctuation("{");
        try self.emitList(null, nodeIndex, node.Elements, @import("emit_list.zig").ListFormat.NamedImportsOrExportsElements);
        self.writer.writePunctuation("}");
    }
    pub fn printNamespaceExport(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).NamespaceExport;
        self.writer.writePunctuation("*");
        self.writer.writeSpace(" ");
        self.writer.writeKeyword("as");
        self.writer.writeSpace(" ");
        try self.printNode(node.name);
    }
    pub fn printExportSpecifier(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ExportSpecifier;
        if (node.IsTypeOnly != 0) {
            self.writer.writeKeyword("type");
            self.writer.writeSpace(" ");
        }
        if (node.PropertyName) |propertyName| {
            try self.printNode(propertyName);
            self.writer.writeSpace(" ");
            self.writer.writeKeyword("as");
            self.writer.writeSpace(" ");
        }
        try self.printNode(node.name);
    }
    pub fn printMissingDeclaration(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        _ = self;
        _ = nodeIndex;
    }
    pub fn printExternalModuleReference(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ExternalModuleReference;
        self.writer.writeKeyword("require");
        self.writer.writePunctuation("(");
        try self.printNode(node.Expression);
        self.writer.writePunctuation(")");
    }
    pub fn printJsxElement(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JsxElement;
        try self.printNode(node.OpeningElement);
        try self.emitList(Printer.printNode, nodeIndex, node.Children, @import("emit_list.zig").ListFormat.JsxElementOrFragmentChildren);
        try self.printNode(node.ClosingElement);
    }
    pub fn printJsxSelfClosingElement(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JsxSelfClosingElement;
        self.writer.writePunctuation("<");
        try self.printNode(node.TagName);
        if (node.TypeArguments) |typeArgs| {
            if (typeArgs != 0) try self.printTypeArguments(typeArgs);
        }
        self.writer.writeSpace(" ");
        try self.printNode(node.Attributes);
        self.writer.writePunctuation("/>");
    }
    pub fn printJsxOpeningElement(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JsxOpeningElement;
        self.writer.writePunctuation("<");
        try self.printNode(node.TagName);
        if (node.TypeArguments) |typeArgs| {
            if (typeArgs != 0) try self.printTypeArguments(typeArgs);
        }
        const hasAttr = if (node.Attributes != 0) self.tree.getNode(node.Attributes).JsxAttributes.Properties != 0 and self.tree.getNodeList(self.tree.getNode(node.Attributes).JsxAttributes.Properties).len > 0 else false;
        if (hasAttr) {
            self.writer.writeSpace(" ");
        }
        try self.printNode(node.Attributes);
        self.writer.writePunctuation(">");
    }
    pub fn printJsxClosingElement(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JsxClosingElement;
        self.writer.writePunctuation("</");
        try self.printNode(node.TagName);
        self.writer.writePunctuation(">");
    }
    pub fn printJsxFragment(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JsxFragment;
        try self.printNode(node.OpeningFragment);
        try self.emitList(Printer.printNode, nodeIndex, node.Children, @import("emit_list.zig").ListFormat.JsxElementOrFragmentChildren);
        try self.printNode(node.ClosingFragment);
    }
    pub fn printJsxOpeningFragment(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        _ = nodeIndex;
        self.writer.writePunctuation("<");
        self.writer.writePunctuation(">");
    }
    pub fn printJsxClosingFragment(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        _ = nodeIndex;
        self.writer.writePunctuation("</");
        self.writer.writePunctuation(">");
    }
    pub fn printJsxAttribute(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JsxAttribute;
        try self.printNode(node.name);
        if (node.Initializer) |init_val| {
            if (init_val != 0) {
                self.writer.writePunctuation("=");
                try self.printNode(init_val);
            }
        }
    }
    pub fn printJsxAttributes(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JsxAttributes;
        try self.emitList(Printer.printNode, nodeIndex, node.Properties, @import("emit_list.zig").ListFormat.JsxElementAttributes);
    }
    pub fn printJsxSpreadAttribute(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JsxSpreadAttribute;
        self.writer.writePunctuation("{...");
        try self.printNode(node.Expression);
        self.writer.writePunctuation("}");
    }
    pub fn printJsxExpression(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JsxExpression;
        self.writer.writePunctuation("{");
        if (node.DotDotDotToken) |t| {
            if (t != 0) try self.printNode(t);
        }
        if (node.Expression) |expr| {
            if (expr != 0) try self.printNode(expr);
        }
        self.writer.writePunctuation("}");
    }
    pub fn printJsxNamespacedName(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JsxNamespacedName;
        try self.printNode(node.Namespace);
        self.writer.writePunctuation(":");
        try self.printNode(node.name);
    }
    pub const printHeritageClause = @import("emit_decl.zig").printHeritageClause;
    pub fn printCatchClause(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).CatchClause;
        self.writer.writeKeyword("catch");
        self.writer.writeSpace(" ");
        if (node.VariableDeclaration) |declaration| if (declaration != 0) {
            self.writer.writePunctuation("(");
            try self.printNode(declaration);
            self.writer.writePunctuation(")");
            self.writer.writeSpace(" ");
        };
        try self.printNode(node.Block);
    }
    pub fn printImportAttributes(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ImportAttributes;
        if (node.Token == @intFromEnum(@import("../ast/kind.zig").Kind.WithKeyword)) {
            self.writer.writeKeyword("with");
        } else {
            self.writer.writeKeyword("assert");
        }
        self.writer.writeSpace(" ");
        try self.emitList(null, nodeIndex, node.Attributes, @import("emit_list.zig").ListFormat.ImportAttributesElements);
    }
    pub fn printImportAttribute(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).ImportAttribute;
        try self.printNode(node.name);
        self.writer.writePunctuation(":");
        self.writer.writeSpace(" ");
        try self.printNode(node.Value);
    }
    pub fn printPropertyAssignment(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try @import("emit_expr.zig").printPropertyAssignment(self, nodeIndex);
    }
    pub fn printShorthandPropertyAssignment(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try @import("emit_expr.zig").printShorthandPropertyAssignment(self, nodeIndex);
    }
    pub fn printSpreadAssignment(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try @import("emit_expr.zig").printSpreadAssignment(self, nodeIndex);
    }
    pub fn printJSDocTypeExpression(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        self.writer.writePunctuation("{");
        try self.printNode(self.tree.getNode(nodeIndex).JSDocTypeExpression.Type);
        self.writer.writePunctuation("}");
    }
    pub fn printJSDocNameReference(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.printNode(self.tree.getNode(nodeIndex).JSDocNameReference.name);
    }
    pub fn printJSDocAllType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        _ = nodeIndex;
        self.writer.writePunctuation("*");
    }
    pub fn printJSDocNullableType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        self.writer.writePunctuation("?");
        try self.printNode(self.tree.getNode(nodeIndex).JSDocNullableType.Type);
    }
    pub fn printJSDocNonNullableType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        self.writer.writePunctuation("!");
        try self.printNode(self.tree.getNode(nodeIndex).JSDocNonNullableType.Type);
    }
    pub fn printJSDocOptionalType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.printNode(self.tree.getNode(nodeIndex).JSDocOptionalType.Type);
        self.writer.writePunctuation("=");
    }
    pub fn printJSDocVariadicType(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        self.writer.writePunctuation("...");
        try self.printNode(self.tree.getNode(nodeIndex).JSDocVariadicType.Type);
    }
    pub fn printJSDoc(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDoc;
        self.writer.writeComment("/**");
        if (node.Comment != 0) {
            self.writer.writeSpace(" ");
            try self.printNode(node.Comment);
        }
        if (node.Tags) |tags| if (tags != 0) {
            for (self.tree.getNodeList(tags)) |tag| {
                self.writer.writeLine();
                self.writer.writeComment(" * ");
                try self.printNode(tag);
            }
        };
        self.writer.writeLine();
        self.writer.writeComment(" */");
    }
    pub fn printJSDocText(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        self.writer.writeComment(self.tree.getNode(nodeIndex).JSDocText.text);
    }
    pub fn printJSDocTypeLiteral(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocTypeLiteral;
        self.writer.writePunctuation("{");
        if (node.JSDocPropertyTags) |tags| if (tags != 0) try self.printList(@import("emit_list.zig").ListFormat.CommaDelimited | @import("emit_list.zig").ListFormat.SpaceBetweenSiblings, tags);
        self.writer.writePunctuation("}");
    }
    pub fn printJSDocSignature(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocSignature;
        if (node.TypeParameters) |types| if (types != 0) try self.printTypeParameters(types);
        self.writer.writePunctuation("(");
        try self.printList(@import("emit_list.zig").ListFormat.Parameters, node.Parameters);
        self.writer.writePunctuation(")");
        if (node.Type) |return_type| if (return_type != 0) {
            self.writer.writePunctuation(":");
            self.writer.writeSpace(" ");
            try self.printNode(return_type);
        };
    }
    pub fn printJSDocLink(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocLink;
        self.writer.writeComment("{@link ");
        if (node.name) |name| try self.printNode(name);
        if (node.text.len != 0) self.writer.writeComment(node.text);
        self.writer.writeComment("}");
    }
    pub fn printJSDocLinkCode(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocLinkCode;
        self.writer.writeComment("{@linkcode ");
        if (node.name) |name| try self.printNode(name);
        if (node.text.len != 0) self.writer.writeComment(node.text);
        self.writer.writeComment("}");
    }
    pub fn printJSDocLinkPlain(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocLinkPlain;
        self.writer.writeComment("{@linkplain ");
        if (node.name) |name| try self.printNode(name);
        if (node.text.len != 0) self.writer.writeComment(node.text);
        self.writer.writeComment("}");
    }
    fn printJSDocComment(self: *Printer, comment: ?u32) anyerror!void {
        if (comment) |value| if (value != 0) {
            self.writer.writeSpace(" ");
            try self.printNode(value);
        };
    }
    fn printJSDocTagParts(self: *Printer, tag_name: u32, payload: ?u32, comment: ?u32) anyerror!void {
        self.writer.writePunctuation("@");
        try self.printNode(tag_name);
        if (payload) |value| if (value != 0) {
            self.writer.writeSpace(" ");
            try self.printNode(value);
        };
        try self.printJSDocComment(comment);
    }
    pub fn printJSDocUnknownTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocUnknownTag;
        try self.printJSDocTagParts(node.TagName, null, node.Comment);
    }
    pub fn printJSDocAugmentsTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocAugmentsTag;
        try self.printJSDocTagParts(node.TagName, node.ClassName, node.Comment);
    }
    pub fn printJSDocImplementsTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocImplementsTag;
        try self.printJSDocTagParts(node.TagName, node.ClassName, node.Comment);
    }
    pub fn printJSDocDeprecatedTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocDeprecatedTag;
        try self.printJSDocTagParts(node.TagName, null, node.Comment);
    }
    pub fn printJSDocPublicTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocPublicTag;
        try self.printJSDocTagParts(node.TagName, null, node.Comment);
    }
    pub fn printJSDocPrivateTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocPrivateTag;
        try self.printJSDocTagParts(node.TagName, null, node.Comment);
    }
    pub fn printJSDocProtectedTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocProtectedTag;
        try self.printJSDocTagParts(node.TagName, null, node.Comment);
    }
    pub fn printJSDocReadonlyTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocReadonlyTag;
        try self.printJSDocTagParts(node.TagName, null, node.Comment);
    }
    pub fn printJSDocOverrideTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocOverrideTag;
        try self.printJSDocTagParts(node.TagName, null, node.Comment);
    }
    pub fn printJSDocCallbackTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocCallbackTag;
        try self.printJSDocTagParts(node.TagName, node.name, null);
        self.writer.writeSpace(" ");
        try self.printNode(node.TypeExpression);
        try self.printJSDocComment(node.Comment);
    }
    pub fn printJSDocOverloadTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocOverloadTag;
        try self.printJSDocTagParts(node.TagName, node.TypeExpression, node.Comment);
    }
    pub fn printJSDocParameterTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocParameterTag;
        self.writer.writePunctuation("@");
        try self.printNode(node.TagName);
        if (node.IsNameFirst == 0 and node.TypeExpression != null) {
            self.writer.writeSpace(" ");
            try self.printNode(node.TypeExpression.?);
        }
        self.writer.writeSpace(" ");
        if (node.IsBracketed != 0) self.writer.writePunctuation("[");
        try self.printNode(node.name);
        if (node.IsBracketed != 0) self.writer.writePunctuation("]");
        if (node.IsNameFirst != 0 and node.TypeExpression != null) {
            self.writer.writeSpace(" ");
            try self.printNode(node.TypeExpression.?);
        }
        try self.printJSDocComment(node.Comment);
    }
    pub fn printJSDocReturnTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocReturnTag;
        try self.printJSDocTagParts(node.TagName, node.TypeExpression, node.Comment);
    }
    pub fn printJSDocThisTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocThisTag;
        try self.printJSDocTagParts(node.TagName, node.TypeExpression, node.Comment);
    }
    pub fn printJSDocTypeTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocTypeTag;
        try self.printJSDocTagParts(node.TagName, node.TypeExpression, node.Comment);
    }
    pub fn printJSDocTemplateTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocTemplateTag;
        self.writer.writePunctuation("@");
        try self.printNode(node.TagName);
        if (node.Constraint != 0) {
            self.writer.writeSpace(" ");
            try self.printNode(node.Constraint);
        }
        self.writer.writeSpace(" ");
        try self.printList(@import("emit_list.zig").ListFormat.CommaDelimited | @import("emit_list.zig").ListFormat.SpaceBetweenSiblings, node.TypeParameters);
        try self.printJSDocComment(node.Comment);
    }
    pub fn printJSDocTypedefTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocTypedefTag;
        try self.printJSDocTagParts(node.TagName, node.TypeExpression, null);
        if (node.name) |name| {
            self.writer.writeSpace(" ");
            try self.printNode(name);
        }
        try self.printJSDocComment(node.Comment);
    }
    pub fn printJSDocSeeTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocSeeTag;
        try self.printJSDocTagParts(node.TagName, node.NameExpression, node.Comment);
    }
    pub fn printJSDocPropertyTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocPropertyTag;
        self.writer.writePunctuation("@");
        try self.printNode(node.TagName);
        if (node.IsNameFirst == 0 and node.TypeExpression != null) {
            self.writer.writeSpace(" ");
            try self.printNode(node.TypeExpression.?);
        }
        self.writer.writeSpace(" ");
        if (node.IsBracketed != 0) self.writer.writePunctuation("[");
        try self.printNode(node.name);
        if (node.IsBracketed != 0) self.writer.writePunctuation("]");
        if (node.IsNameFirst != 0 and node.TypeExpression != null) {
            self.writer.writeSpace(" ");
            try self.printNode(node.TypeExpression.?);
        }
        try self.printJSDocComment(node.Comment);
    }
    pub fn printJSDocThrowsTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocThrowsTag;
        try self.printJSDocTagParts(node.TagName, node.TypeExpression, node.Comment);
    }
    pub fn printJSDocSatisfiesTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocSatisfiesTag;
        try self.printJSDocTagParts(node.TagName, node.TypeExpression, node.Comment);
    }
    pub fn printJSDocImportTag(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const node = self.tree.getNode(nodeIndex).JSDocImportTag;
        self.writer.writePunctuation("@");
        try self.printNode(node.TagName);
        self.writer.writeSpace(" ");
        if (node.ImportClause) |clause| if (clause != 0) {
            try self.printNode(clause);
            self.writer.writeSpace(" ");
            self.writer.writeKeyword("from");
            self.writer.writeSpace(" ");
        };
        try self.printNode(node.ModuleSpecifier);
        if (node.Attributes) |attributes| if (attributes != 0) {
            self.writer.writeSpace(" ");
            try self.printNode(attributes);
        };
        try self.printJSDocComment(node.Comment);
    }
    pub fn printSyntaxList(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        const children = self.tree.getNode(nodeIndex).SyntaxList.Children;
        for (self.tree.getNodeList(children)) |child| try self.printNode(child);
    }
    pub fn printJSTypeAliasDeclaration(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.printTypeAliasDeclaration(nodeIndex);
    }
    pub fn printJSImportDeclaration(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.printImportDeclaration(nodeIndex);
    }
    pub fn printSyntheticReferenceExpression(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        try self.printNode(self.tree.getNode(nodeIndex).SyntheticReferenceExpression.Expression);
    }
    pub fn printNotEmittedTypeElement(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        _ = self;
        _ = nodeIndex;
    }
    pub fn enterNode(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!u32 {
        const previous = self.currentNode;
        self.currentNode = nodeIndex;
        self.recordSourceMapping(nodeIndex);
        return previous;
    }
    pub fn exitNode(self: *Printer, nodeIndex: ast_mod.NodeIndex, state: u32) anyerror!void {
        if (self.currentNode == nodeIndex) self.currentNode = state;
    }

    pub fn writeTokenText(self: *Printer, token: @import("../ast/kind.zig").Kind, writeKind: anytype, pos: usize) anyerror!usize {
        const textOpt = @import("utilities.zig").tokenToString(token);
        if (textOpt) |text| {
            const kindName = @tagName(writeKind);
            if (std.mem.eql(u8, kindName, "Punctuation")) {
                self.writer.writePunctuation(text);
            } else if (std.mem.eql(u8, kindName, "Keyword")) {
                self.writer.writeKeyword(text);
            } else if (std.mem.eql(u8, kindName, "Operator")) {
                self.writer.writeOperator(text);
            } else {
                self.writer.write(text);
            }
            return pos + text.len;
        }
        return pos;
    }

    pub fn enterToken(self: *Printer, token: @import("../ast/kind.zig").Kind, pos: usize, parent: ast_mod.NodeIndex, flags: u32) anyerror!u32 {
        _ = token;
        _ = pos;
        _ = flags;
        return try self.enterNode(parent);
    }

    pub fn exitToken(self: *Printer, token: @import("../ast/kind.zig").Kind, pos: usize, parent: ast_mod.NodeIndex, previousState: u32) anyerror!void {
        _ = token;
        _ = pos;
        try self.exitNode(parent, previousState);
    }

    pub fn emitToken(self: *Printer, token: @import("../ast/kind.zig").Kind, pos: usize, kind: anytype, parent: ast_mod.NodeIndex) anyerror!usize {
        return try self.emitTokenEx(token, pos, kind, parent, 0);
    }
    pub fn emitLabelIdentifier(self: *Printer, label: u32) anyerror!void {
        if (label != 0) {
            try self.printNode(label);
        }
    }

    pub fn generateNames(self: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
        if (nodeIndex == 0) return;
        const Visitor = struct {
            printer: *Printer,

            pub fn visitNode(visitor: *@This(), child: ast_mod.NodeIndex) anyerror!void {
                if (child == 0) return;
                if (visitor.printer.tree.getNode(child) == .Identifier) {
                    const text = ast_utils.getText(visitor.printer.tree, child);
                    if (text.len != 0) try visitor.printer.generatedNameCandidates.put(visitor.printer.context.allocator, text, {});
                }
                try ast_mod.forEachChild(visitor.printer.tree, child, visitor);
            }

            pub fn visitList(visitor: *@This(), list: u32) anyerror!void {
                if (list == 0) return;
                for (visitor.printer.tree.getNodeList(list)) |child| try visitor.visitNode(child);
            }
        };
        var visitor = Visitor{ .printer = self };
        try visitor.visitNode(nodeIndex);
    }
    pub fn emitModifierList(self: *Printer, nodeIndex: ast_mod.NodeIndex, modifiersOpt: ?u32, flags: bool) anyerror!void {
        _ = flags;
        if (modifiersOpt) |modifiers| {
            try self.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
        }
    }

    pub fn emitVariableDeclarationList(self: *Printer, list: u32) anyerror!void {
        if (list != 0) {
            try self.printNode(list);
        }
    }
    pub fn emitExpression(self: *Printer, expr: u32, prec: u32) anyerror!void {
        if (expr == 0) return;
        const prec_enum: precedence.OperatorPrecedence = @enumFromInt(@as(i32, @intCast(prec)));
        const skipped = precedence.skipPartiallyEmittedExpressions(self.tree, expr);
        const expr_prec = precedence.getExpressionPrecedence(self.tree, skipped);
        const parens = @intFromEnum(expr_prec) < @intFromEnum(prec_enum);
        if (parens) {
            self.writer.writePunctuation("(");
        }
        try self.printNode(expr);
        if (parens) {
            self.writer.writePunctuation(")");
        }
    }
    pub fn emitEmbeddedStatement(self: *Printer, nodeIndex: u32, stmt: u32) anyerror!void {
        if (stmt != 0) {
            if (std.meta.activeTag(self.tree.getNode(stmt)) == .Block) {
                self.writer.writeSpace(" ");
                try self.printNode(stmt);
            } else if (self.tree.getNode(stmt) == .ExpressionStatement and self.tree.getNode(nodeIndex) == .IfStatement and (self.tree.getNode(nodeIndex).IfStatement.Flags & (1 << 31)) != 0) {
                self.writer.writeSpace(" ");
                try self.printNode(stmt);
            } else {
                self.writer.writeLine();
                self.writer.increaseIndent();
                try self.printNode(stmt);
                self.writer.decreaseIndent();
            }
        }
    }
    pub const OperatorPrecedenceComma: u32 = 0;

    pub fn isImmediatelyInvokedFunctionExpressionOrArrowFunction(self: *Printer, expr: u32) bool {
        const skipped = precedence.skipPartiallyEmittedExpressions(self.tree, expr);
        if (self.tree.getNode(skipped) != .CallExpression) return false;
        const callee = precedence.skipPartiallyEmittedExpressions(self.tree, self.tree.getNode(skipped).CallExpression.Expression);
        return switch (self.tree.getNode(callee)) {
            .FunctionExpression, .ArrowFunction => true,
            else => false,
        };
    }

    pub fn getLeftmostExpression(self: *Printer, nodeIndex: u32, stopAtCallExpressions: bool) u32 {
        return precedence.getLeftmostExpression(self.tree, nodeIndex, stopAtCallExpressions);
    }
    pub fn skipPartiallyEmittedExpressions(self: *Printer, nodeIndex: u32) u32 {
        return precedence.skipPartiallyEmittedExpressions(self.tree, nodeIndex);
    }

    pub fn emitKeywordNode(self: *Printer, nodeIndex: u32) anyerror!void {
        if (nodeIndex != 0) {
            const nodeTag = std.meta.activeTag(self.tree.getNode(nodeIndex));
            if (nodeTag == .AwaitKeyword) {
                self.writer.writeKeyword("await");
            }
        }
    }
    pub fn emitExpressionNoASI(self: *Printer, expr: u32, prec: u32) anyerror!void {
        try self.emitExpression(expr, prec);
    }
    pub fn emitBlock(self: *Printer, block: u32) anyerror!void {
        if (block != 0) {
            try self.printNode(block);
        }
    }

    pub fn rangeEndIsOnSameLineAsRangeStart(self: *Printer, start: u32, end: u32, node: u32) bool {
        _ = node;
        if (start > end or end > self.tree.sourceText.len) return false;
        return std.mem.indexOfScalar(u8, self.tree.sourceText[start..end], '\n') == null;
    }
    pub fn shouldEmitOnSingleLine(self: *Printer, nodeIndex: u32) bool {
        return (self.context.getEmitFlags(nodeIndex) & @import("emitflags.zig").EmitFlags.SingleLine) != 0;
    }
    pub fn shouldEmitBlockFunctionBodyOnSingleLine(self: *Printer, bodyIndex: u32) bool {
        const node = self.tree.getNode(bodyIndex);
        if (node != .Block) return false;
        const block = node.Block;
        if (self.shouldEmitOnSingleLine(bodyIndex)) {
            return true;
        }
        if (block.MultiLine) {
            return false;
        }
        if (bodyIndex < self.tree.positions.items.len) {
            const loc = self.tree.positions.items[bodyIndex];
            if (loc.pos != 0 or loc.end != 0) {
                const utils = @import("utilities.zig");
                if (!utils.rangeIsOnSingleLine(self.tree, .{ .pos = loc.pos, .end = loc.end }, self.currentSourceFile)) {
                    return false;
                }
            }
        }
        return true;
    }
    pub fn emitTokenNode(self: *Printer, tokenIndexOpt: ?u32) anyerror!void {
        if (tokenIndexOpt) |tokenIndex| {
            const tokenKind = std.meta.activeTag(self.tree.getNode(tokenIndex));
            _ = try self.emitToken(tokenKind, 0, .Punctuation, tokenIndex);
        }
    }
    pub fn writeLineOrSpace(self: *Printer, parent: u32, node1: u32, node2: u32) anyerror!void {
        _ = node1;
        _ = node2;
        if (self.shouldEmitOnSingleLine(parent)) {
            self.writer.writeSpace(" ");
            return;
        }
        self.writer.writeLine();
    }
    pub fn getLinesBetweenPositions(self: *Printer, pos1: u32, pos2: u32) u32 {
        if (pos1 >= pos2 or pos2 > self.tree.sourceText.len) return 0;
        var lines: u32 = 0;
        for (self.tree.sourceText[pos1..pos2]) |c| {
            if (c == '\n') {
                lines += 1;
            }
        }
        return lines;
    }
    pub fn emitCaseBlock(self: *Printer, block: u32) anyerror!void {
        if (block != 0) {
            try self.printNode(block);
        }
    }
    pub fn emitStatement(self: *Printer, stmt: u32) anyerror!void {
        if (stmt != 0) {
            try self.printNode(stmt);
        }
    }

    pub fn emitTypeArguments(self: *Printer, nodeIndex: u32, typeArgs: ?u32) anyerror!void {
        _ = nodeIndex;
        if (typeArgs) |list| if (list != 0) try self.printTypeArguments(list);
    }
    pub fn emitCatchClause(self: *Printer, clause: u32) anyerror!void {
        if (clause != 0) {
            try self.printNode(clause);
        }
    }

    pub fn emitList(self: *Printer, printElement: anytype, parent: u32, list: u32, format: u32) anyerror!void {
        _ = printElement;
        _ = parent;
        try @import("emit_list.zig").printList(self, format, list);
    }

    pub fn emitTokenEx(self: *Printer, token: @import("../ast/kind.zig").Kind, pos: usize, kind: anytype, parent: u32, format: u32) anyerror!usize {
        const state = try self.enterToken(token, pos, parent, format);
        const newPos = try self.writeTokenText(token, kind, pos);
        try self.exitToken(token, newPos, parent, state);
        return newPos;
    }
};

// test "basic printer - function declaration" {
//     // ... test commented out
// }

pub const EmitResolver = struct {
    pub fn getTypeReferenceSerializationKind(self: *EmitResolver, a: anytype, b: anytype) u32 {
        _ = self;
        _ = a;
        _ = b;
        return 0;
    }
};

pub const EmitFlags = struct {
    pub const NoComments: u32 = 1;
    pub const NoTrailingComments: u32 = 2;
    pub const StartOnNewLine: u32 = 4;
    pub const NoSourceMap: u32 = 8;
    pub const NoNestedSourceMaps: u32 = 16;
};
