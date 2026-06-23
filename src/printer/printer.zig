const std = @import("std");
const ast_mod = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");

/// Printer converts an AST (from the parser) into JavaScript source text.
/// TypeScript-specific constructs (type annotations, interfaces, type aliases,
/// as-expressions, non-null assertions, etc.) are dropped.
pub const Printer = struct {
    allocator: std.mem.Allocator,
    tree: *ast_mod.Ast,
    output: std.ArrayListUnmanaged(u8),
    indentLevel: u32,

    pub fn init(allocator: std.mem.Allocator, tree: *ast_mod.Ast) Printer {
        return .{
            .allocator = allocator,
            .tree = tree,
            .output = .empty,
            .indentLevel = 0,
        };
    }

    pub fn deinit(self: *Printer) void {
        self.output.deinit(self.allocator);
    }

    pub fn getOutput(self: *const Printer) []const u8 {
        return self.output.items;
    }

    // -------------------------------------------------------------------------
    // Low-level write helpers
    // -------------------------------------------------------------------------

    fn write(self: *Printer, s: []const u8) anyerror!void {
        try self.output.appendSlice(self.allocator, s);
    }

    fn writeByte(self: *Printer, b: u8) anyerror!void {
        try self.output.append(self.allocator, b);
    }

    /// Write current indentation (4 spaces per level).
    fn writeIndent(self: *Printer) anyerror!void {
        var i: u32 = 0;
        while (i < self.indentLevel) : (i += 1) {
            try self.write("    ");
        }
    }

    /// Write a newline followed by indentation.
    fn writeLine(self: *Printer) anyerror!void {
        try self.writeByte('\n');
        try self.writeIndent();
    }

    fn increaseIndent(self: *Printer) void {
        self.indentLevel += 1;
    }

    fn decreaseIndent(self: *Printer) void {
        if (self.indentLevel > 0) self.indentLevel -= 1;
    }

    // -------------------------------------------------------------------------
    // Token → operator string
    // -------------------------------------------------------------------------

    /// Given a NodeIndex that holds an operator token (void tag in NodeData),
    /// return the corresponding JavaScript operator string.
    fn tokenToString(self: *Printer, tokenIndex: u32) []const u8 {
        const node = self.tree.getNode(tokenIndex);
        return switch (node) {
            .PlusToken => "+",
            .MinusToken => "-",
            .AsteriskToken => "*",
            .AsteriskAsteriskToken => "**",
            .SlashToken => "/",
            .PercentToken => "%",
            .PlusPlusToken => "++",
            .MinusMinusToken => "--",
            .LessThanToken => "<",
            .GreaterThanToken => ">",
            .LessThanEqualsToken => "<=",
            .GreaterThanEqualsToken => ">=",
            .EqualsEqualsToken => "==",
            .ExclamationEqualsToken => "!=",
            .EqualsEqualsEqualsToken => "===",
            .ExclamationEqualsEqualsToken => "!==",
            .LessThanLessThanToken => "<<",
            .GreaterThanGreaterThanToken => ">>",
            .GreaterThanGreaterThanGreaterThanToken => ">>>",
            .AmpersandToken => "&",
            .BarToken => "|",
            .CaretToken => "^",
            .ExclamationToken => "!",
            .TildeToken => "~",
            .AmpersandAmpersandToken => "&&",
            .BarBarToken => "||",
            .QuestionQuestionToken => "??",
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
            .BarBarEqualsToken => "||=",
            .AmpersandAmpersandEqualsToken => "&&=",
            .QuestionQuestionEqualsToken => "??=",
            .CaretEqualsToken => "^=",
            .InKeyword => "in",
            .InstanceOfKeyword => "instanceof",
            .CommaToken => ",",
            .EqualsGreaterThanToken => "=>",
            else => "??",
        };
    }

    // -------------------------------------------------------------------------
    // Public entry point
    // -------------------------------------------------------------------------

    pub fn printSourceFile(self: *Printer, nodeIndex: u32) anyerror!void {
        const node = self.tree.getNode(nodeIndex);
        switch (node) {
            .SourceFile => |sf| {
                const stmts = self.tree.getNodeList(sf.Statements);
                for (stmts) |stmtIdx| {
                    try self.printStatement(stmtIdx);
                }
            },
            else => try self.printStatement(nodeIndex),
        }
    }

    // -------------------------------------------------------------------------
    // Statement printer
    // -------------------------------------------------------------------------

    fn printStatement(self: *Printer, nodeIndex: u32) anyerror!void {
        if (nodeIndex == 0) return;
        const node = self.tree.getNode(nodeIndex);
        switch (node) {
            .SourceFile => |sf| {
                const stmts = self.tree.getNodeList(sf.Statements);
                for (stmts) |stmtIdx| {
                    try self.printStatement(stmtIdx);
                }
            },

            // ---------------------------------------------------------------
            // Block
            // ---------------------------------------------------------------
            .Block => |blk| {
                try self.write("{");
                self.increaseIndent();
                const stmts = self.tree.getNodeList(blk.Statements);
                for (stmts) |stmtIdx| {
                    try self.writeLine();
                    try self.printStatement(stmtIdx);
                }
                self.decreaseIndent();
                if (blk.Statements != 0) {
                    const stmts2 = self.tree.getNodeList(blk.Statements);
                    if (stmts2.len > 0) {
                        try self.writeLine();
                    }
                }
                try self.write("}");
            },

            // ---------------------------------------------------------------
            // FunctionDeclaration
            // ---------------------------------------------------------------
            .FunctionDeclaration => |fd| {
                try self.write("function ");
                if (fd.name) |nameIdx| {
                    const nameNode = self.tree.getNode(nameIdx);
                    if (nameNode == .Identifier) {
                        try self.write(nameNode.Identifier.Text);
                    }
                }
                try self.write("(");
                try self.printParameterList(fd.Parameters);
                try self.write(") ");
                if (fd.Body) |bodyIdx| {
                    try self.printStatement(bodyIdx);
                } else {
                    try self.write("{}");
                }
                try self.writeByte('\n');
            },

            // ---------------------------------------------------------------
            // ClassDeclaration
            // ---------------------------------------------------------------
            .ClassDeclaration => |cd| {
                try self.write("class ");
                if (cd.name) |nameIdx| {
                    const nameNode = self.tree.getNode(nameIdx);
                    if (nameNode == .Identifier) {
                        try self.write(nameNode.Identifier.Text);
                    }
                }
                // HeritageClauses (extends / implements)
                if (cd.HeritageClauses) |hcListIdx| {
                    const hcList = self.tree.getNodeList(hcListIdx);
                    for (hcList) |hcIdx| {
                        const hc = self.tree.getNode(hcIdx);
                        if (hc == .HeritageClause) {
                            // Only emit 'extends', skip 'implements'
                            const types = self.tree.getNodeList(hc.HeritageClause.Types);
                            if (types.len > 0) {
                                // Check if it's an extends clause by looking at the token
                                // Token 95 = ExtendsKeyword
                                if (hc.HeritageClause.Token == 95) {
                                    try self.write(" extends ");
                                    try self.printExpression(types[0]);
                                    var i: usize = 1;
                                    while (i < types.len) : (i += 1) {
                                        try self.write(", ");
                                        try self.printExpression(types[i]);
                                    }
                                }
                            }
                        }
                    }
                }
                try self.write(" {");
                self.increaseIndent();
                const members = self.tree.getNodeList(cd.Members);
                for (members) |memberIdx| {
                    try self.writeLine();
                    try self.printClassMember(memberIdx);
                }
                self.decreaseIndent();
                if (members.len > 0) {
                    try self.writeLine();
                }
                try self.write("}");
                try self.writeByte('\n');
            },

            // ---------------------------------------------------------------
            // VariableStatement
            // ---------------------------------------------------------------
            .VariableStatement => |vs| {
                try self.printVariableDeclarationList(vs.DeclarationList);
                try self.write(";");
                try self.writeByte('\n');
            },

            // ---------------------------------------------------------------
            // ReturnStatement
            // ---------------------------------------------------------------
            .ReturnStatement => |rs| {
                try self.write("return");
                if (rs.Expression) |exprIdx| {
                    if (exprIdx != 0) {
                        try self.write(" ");
                        try self.printExpression(exprIdx);
                    }
                }
                try self.write(";");
            },

            // ---------------------------------------------------------------
            // IfStatement
            // ---------------------------------------------------------------
            .IfStatement => |is_| {
                try self.write("if (");
                try self.printExpression(is_.Expression);
                try self.write(") ");
                try self.printStatement(is_.ThenStatement);
                if (is_.ElseStatement) |elseIdx| {
                    if (elseIdx != 0) {
                        try self.write(" else ");
                        try self.printStatement(elseIdx);
                    }
                }
                try self.writeByte('\n');
            },

            // ---------------------------------------------------------------
            // WhileStatement
            // ---------------------------------------------------------------
            .WhileStatement => |ws| {
                try self.write("while (");
                try self.printExpression(ws.Expression);
                try self.write(") ");
                try self.printStatement(ws.Statement);
                try self.writeByte('\n');
            },

            // ---------------------------------------------------------------
            // DoStatement
            // ---------------------------------------------------------------
            .DoStatement => |ds| {
                try self.write("do ");
                try self.printStatement(ds.Statement);
                try self.write(" while (");
                try self.printExpression(ds.Expression);
                try self.write(");");
                try self.writeByte('\n');
            },

            // ---------------------------------------------------------------
            // ForStatement
            // ---------------------------------------------------------------
            .ForStatement => |fs| {
                try self.write("for (");
                if (fs.Initializer) |initIdx| {
                    if (initIdx != 0) {
                        const initNode = self.tree.getNode(initIdx);
                        if (initNode == .VariableDeclarationList) {
                            try self.printVariableDeclarationList(initIdx);
                        } else {
                            try self.printExpression(initIdx);
                        }
                    }
                }
                try self.write("; ");
                if (fs.Condition) |condIdx| {
                    if (condIdx != 0) try self.printExpression(condIdx);
                }
                try self.write("; ");
                if (fs.Incrementor) |incrIdx| {
                    if (incrIdx != 0) try self.printExpression(incrIdx);
                }
                try self.write(") ");
                try self.printStatement(fs.Statement);
                try self.writeByte('\n');
            },

            // ---------------------------------------------------------------
            // ForInStatement / ForOfStatement
            // ---------------------------------------------------------------
            .ForInStatement => |fio| {
                try self.write("for (");
                const initNode = self.tree.getNode(fio.Initializer);
                if (initNode == .VariableDeclarationList) {
                    try self.printVariableDeclarationList(fio.Initializer);
                } else {
                    try self.printExpression(fio.Initializer);
                }
                try self.write(" in ");
                try self.printExpression(fio.Expression);
                try self.write(") ");
                try self.printStatement(fio.Statement);
                try self.writeByte('\n');
            },
            .ForOfStatement => |fio| {
                try self.write("for (");
                if (fio.AwaitModifier != null) try self.write("await ");
                const initNode = self.tree.getNode(fio.Initializer);
                if (initNode == .VariableDeclarationList) {
                    try self.printVariableDeclarationList(fio.Initializer);
                } else {
                    try self.printExpression(fio.Initializer);
                }
                try self.write(" of ");
                try self.printExpression(fio.Expression);
                try self.write(") ");
                try self.printStatement(fio.Statement);
                try self.writeByte('\n');
            },

            // ---------------------------------------------------------------
            // ExpressionStatement
            // ---------------------------------------------------------------
            .ExpressionStatement => |es| {
                try self.printExpression(es.Expression);
                try self.write(";");
                try self.writeByte('\n');
            },

            // ---------------------------------------------------------------
            // ThrowStatement
            // ---------------------------------------------------------------
            .ThrowStatement => |ts| {
                try self.write("throw ");
                try self.printExpression(ts.Expression);
                try self.write(";");
                try self.writeByte('\n');
            },

            // ---------------------------------------------------------------
            // TryStatement
            // ---------------------------------------------------------------
            .TryStatement => |ts| {
                try self.write("try ");
                try self.printStatement(ts.TryBlock);
                if (ts.CatchClause) |ccIdx| {
                    if (ccIdx != 0) {
                        const ccNode = self.tree.getNode(ccIdx);
                        if (ccNode == .CatchClause) {
                            try self.write(" catch");
                            if (ccNode.CatchClause.VariableDeclaration) |vdIdx| {
                                if (vdIdx != 0) {
                                    try self.write("(");
                                    const vdNode = self.tree.getNode(vdIdx);
                                    if (vdNode == .VariableDeclaration) {
                                        const nameNode = self.tree.getNode(vdNode.VariableDeclaration.name);
                                        if (nameNode == .Identifier) {
                                            try self.write(nameNode.Identifier.Text);
                                        }
                                    }
                                    try self.write(")");
                                }
                            } else {
                                try self.write(" ");
                            }
                            try self.printStatement(ccNode.CatchClause.Block);
                        }
                    }
                }
                if (ts.FinallyBlock) |fbIdx| {
                    if (fbIdx != 0) {
                        try self.write(" finally ");
                        try self.printStatement(fbIdx);
                    }
                }
                try self.writeByte('\n');
            },

            // ---------------------------------------------------------------
            // BreakStatement / ContinueStatement
            // ---------------------------------------------------------------
            .BreakStatement => |bs| {
                try self.write("break");
                if (bs.Label) |lIdx| {
                    if (lIdx != 0) {
                        try self.write(" ");
                        try self.printExpression(lIdx);
                    }
                }
                try self.write(";");
                try self.writeByte('\n');
            },
            .ContinueStatement => |cs| {
                try self.write("continue");
                if (cs.Label) |lIdx| {
                    if (lIdx != 0) {
                        try self.write(" ");
                        try self.printExpression(lIdx);
                    }
                }
                try self.write(";");
                try self.writeByte('\n');
            },

            // ---------------------------------------------------------------
            // SwitchStatement
            // ---------------------------------------------------------------
            .SwitchStatement => |ss| {
                try self.write("switch (");
                try self.printExpression(ss.Expression);
                try self.write(") {");
                self.increaseIndent();
                const cbNode = self.tree.getNode(ss.CaseBlock);
                if (cbNode == .CaseBlock) {
                    const clauses = self.tree.getNodeList(cbNode.CaseBlock.Clauses);
                    for (clauses) |clauseIdx| {
                        try self.writeLine();
                        const clause = self.tree.getNode(clauseIdx);
                        if (clause == .CaseClause) {
                            try self.write("case ");
                            try self.printExpression(clause.CaseClause.Expression);
                            try self.write(":");
                            self.increaseIndent();
                            const caseStmts = self.tree.getNodeList(clause.CaseClause.Statements);
                            for (caseStmts) |stmtIdx| {
                                try self.writeLine();
                                try self.printStatement(stmtIdx);
                            }
                            self.decreaseIndent();
                        } else if (clause == .DefaultClause) {
                            try self.write("default:");
                            self.increaseIndent();
                            const defStmts = self.tree.getNodeList(clause.DefaultClause.Statements);
                            for (defStmts) |stmtIdx| {
                                try self.writeLine();
                                try self.printStatement(stmtIdx);
                            }
                            self.decreaseIndent();
                        }
                    }
                }
                self.decreaseIndent();
                try self.writeLine();
                try self.write("}");
                try self.writeByte('\n');
            },

            // ---------------------------------------------------------------
            // LabeledStatement
            // ---------------------------------------------------------------
            .LabeledStatement => |ls| {
                try self.printExpression(ls.Label);
                try self.write(": ");
                try self.printStatement(ls.Statement);
            },

            // ---------------------------------------------------------------
            // DebuggerStatement
            // ---------------------------------------------------------------
            .DebuggerStatement => {
                try self.write("debugger;");
                try self.writeByte('\n');
            },

            // ---------------------------------------------------------------
            // EmptyStatement
            // ---------------------------------------------------------------
            .EmptyStatement => {
                try self.write(";");
                try self.writeByte('\n');
            },

            // ---------------------------------------------------------------
            // TypeScript-only declarations → skip entirely
            // ---------------------------------------------------------------
            .InterfaceDeclaration,
            .TypeAliasDeclaration,
            .EnumDeclaration,
            => {},

            // ---------------------------------------------------------------
            // VariableDeclaration (when used as a standalone statement)
            // ---------------------------------------------------------------
            .VariableDeclaration => |vd| {
                const nameNode = self.tree.getNode(vd.name);
                if (nameNode == .Identifier) {
                    try self.write(nameNode.Identifier.Text);
                }
                if (vd.Initializer) |initIdx| {
                    if (initIdx != 0) {
                        try self.write(" = ");
                        try self.printExpression(initIdx);
                    }
                }
            },

            // ---------------------------------------------------------------
            // ExportAssignment / ImportDeclaration / ExportDeclaration – basic
            // ---------------------------------------------------------------
            .ExportAssignment => |ea| {
                if (ea.IsExportEquals != 0) {
                    try self.write("module.exports = ");
                } else {
                    try self.write("export default ");
                }
                try self.printExpression(ea.Expression);
                try self.write(";");
                try self.writeByte('\n');
            },

            // Unknown / unsupported – emit nothing
            else => {},
        }
    }

    // -------------------------------------------------------------------------
    // Class member printer
    // -------------------------------------------------------------------------

    fn printClassMember(self: *Printer, nodeIndex: u32) anyerror!void {
        if (nodeIndex == 0) return;
        const node = self.tree.getNode(nodeIndex);
        switch (node) {
            .MethodDeclaration => |md| {
                // Emit method name
                try self.printPropertyName(md.name);
                try self.write("(");
                try self.printParameterList(md.Parameters);
                try self.write(") ");
                if (md.Body) |bodyIdx| {
                    try self.printStatement(bodyIdx);
                } else {
                    try self.write("{}");
                }
            },
            .PropertyDeclaration => |pd| {
                // Property declarations with initializers: name = value;
                try self.printPropertyName(pd.name);
                if (pd.Initializer) |initIdx| {
                    if (initIdx != 0) {
                        try self.write(" = ");
                        try self.printExpression(initIdx);
                    }
                }
                try self.write(";");
            },
            .Constructor => {
                // constructor(){}  – the parser currently stubs this as void
                try self.write("constructor() {}");
            },
            .GetAccessor => |ga| {
                try self.write("get ");
                try self.printPropertyName(ga.name);
                try self.write("(");
                try self.printParameterList(ga.Parameters);
                try self.write(") ");
                if (ga.Body) |bodyIdx| {
                    try self.printStatement(bodyIdx);
                } else {
                    try self.write("{}");
                }
            },
            .SetAccessor => |sa| {
                try self.write("set ");
                try self.printPropertyName(sa.name);
                try self.write("(");
                try self.printParameterList(sa.Parameters);
                try self.write(") ");
                if (sa.Body) |bodyIdx| {
                    try self.printStatement(bodyIdx);
                } else {
                    try self.write("{}");
                }
            },
            // Skip type-only members
            .PropertySignature,
            .MethodSignature,
            .IndexSignature,
            .SemicolonClassElement,
            => {},
            else => {},
        }
    }

    // -------------------------------------------------------------------------
    // Helpers for parameters and variable declarations
    // -------------------------------------------------------------------------

    /// Print parameter list inside parens (without the parens themselves).
    fn printParameterList(self: *Printer, listIndex: u32) anyerror!void {
        const params = self.tree.getNodeList(listIndex);
        var i: usize = 0;
        while (i < params.len) : (i += 1) {
            if (i > 0) try self.write(", ");
            const pIdx = params[i];
            const pNode = self.tree.getNode(pIdx);
            if (pNode == .Parameter) {
                const p = pNode.Parameter;
                if (p.DotDotDotToken != null) try self.write("...");
                const nameNode = self.tree.getNode(p.name);
                if (nameNode == .Identifier) {
                    try self.write(nameNode.Identifier.Text);
                }
                if (p.Initializer) |initIdx| {
                    if (initIdx != 0) {
                        try self.write(" = ");
                        try self.printExpression(initIdx);
                    }
                }
            }
        }
    }

    /// Print a VariableDeclarationList (let/const/var name = init, ...).
    fn printVariableDeclarationList(self: *Printer, listIndex: u32) anyerror!void {
        const listNode = self.tree.getNode(listIndex);
        if (listNode != .VariableDeclarationList) return;
        const vdl = listNode.VariableDeclarationList;
        // Determine keyword from Flags
        const keyword: []const u8 = blk: {
            if ((vdl.Flags & ast_utils.NodeFlags.Const) != 0) break :blk "const";
            if ((vdl.Flags & ast_utils.NodeFlags.Let) != 0) break :blk "let";
            break :blk "var";
        };
        try self.write(keyword);
        try self.write(" ");
        const decls = self.tree.getNodeList(vdl.Declarations);
        var i: usize = 0;
        while (i < decls.len) : (i += 1) {
            if (i > 0) try self.write(", ");
            try self.printVariableDeclaration(decls[i]);
        }
    }

    fn printVariableDeclaration(self: *Printer, nodeIndex: u32) anyerror!void {
        const node = self.tree.getNode(nodeIndex);
        if (node != .VariableDeclaration) return;
        const vd = node.VariableDeclaration;
        const nameNode = self.tree.getNode(vd.name);
        if (nameNode == .Identifier) {
            try self.write(nameNode.Identifier.Text);
        } else {
            // Binding pattern
            try self.printExpression(vd.name);
        }
        if (vd.Initializer) |initIdx| {
            if (initIdx != 0) {
                try self.write(" = ");
                try self.printExpression(initIdx);
            }
        }
    }

    /// Print a property name (Identifier, StringLiteral, NumericLiteral, or ComputedPropertyName).
    fn printPropertyName(self: *Printer, nodeIndex: u32) anyerror!void {
        const node = self.tree.getNode(nodeIndex);
        switch (node) {
            .Identifier => |id| try self.write(id.Text),
            .StringLiteral => |sl| {
                try self.writeByte('"');
                try self.write(sl.Text);
                try self.writeByte('"');
            },
            .NumericLiteral => |nl| try self.write(nl.Text),
            .ComputedPropertyName => |cpn| {
                try self.write("[");
                try self.printExpression(cpn.Expression);
                try self.write("]");
            },
            else => try self.printExpression(nodeIndex),
        }
    }

    // -------------------------------------------------------------------------
    // Expression printer
    // -------------------------------------------------------------------------

    fn printExpression(self: *Printer, nodeIndex: u32) anyerror!void {
        if (nodeIndex == 0) return;
        const node = self.tree.getNode(nodeIndex);
        switch (node) {
            // ---------------------------------------------------------------
            // Literals
            // ---------------------------------------------------------------
            .Identifier => |id| try self.write(id.Text),
            .PrivateIdentifier => |pi| try self.write(pi.Text),

            .StringLiteral => |sl| {
                try self.writeByte('"');
                try self.write(sl.Text);
                try self.writeByte('"');
            },
            .NumericLiteral => |nl| try self.write(nl.Text),
            .BigIntLiteral => |bl| try self.write(bl.Text),
            .RegularExpressionLiteral => |rl| try self.write(rl.Text),

            .TrueKeyword => try self.write("true"),
            .FalseKeyword => try self.write("false"),
            .NullKeyword => try self.write("null"),
            .ThisKeyword => try self.write("this"),
            .SuperKeyword => try self.write("super"),
            .UndefinedKeyword => try self.write("undefined"),

            // ---------------------------------------------------------------
            // NoSubstitutionTemplateLiteral → `text`
            // ---------------------------------------------------------------
            .NoSubstitutionTemplateLiteral => |tl| {
                try self.writeByte('`');
                try self.write(tl.Text);
                try self.writeByte('`');
            },

            // ---------------------------------------------------------------
            // TemplateExpression → `head${span}...`
            // ---------------------------------------------------------------
            .TemplateExpression => |te| {
                try self.writeByte('`');
                const headNode = self.tree.getNode(te.Head);
                if (headNode == .TemplateHead) {
                    try self.write(headNode.TemplateHead.Text);
                }
                const spans = self.tree.getNodeList(te.TemplateSpans);
                for (spans) |spanIdx| {
                    const spanNode = self.tree.getNode(spanIdx);
                    if (spanNode == .TemplateSpan) {
                        try self.write("${");
                        try self.printExpression(spanNode.TemplateSpan.Expression);
                        try self.write("}");
                        const litNode = self.tree.getNode(spanNode.TemplateSpan.Literal);
                        switch (litNode) {
                            .TemplateMiddle => |tm| try self.write(tm.Text),
                            .TemplateTail => |tt| try self.write(tt.Text),
                            else => {},
                        }
                    }
                }
                try self.writeByte('`');
            },

            // ---------------------------------------------------------------
            // BinaryExpression
            // ---------------------------------------------------------------
            .BinaryExpression => |be| {
                try self.printExpression(be.Left);
                try self.write(" ");
                try self.write(self.tokenToString(be.OperatorToken));
                try self.write(" ");
                try self.printExpression(be.Right);
            },

            // ---------------------------------------------------------------
            // PrefixUnaryExpression
            // ---------------------------------------------------------------
            .PrefixUnaryExpression => |pu| {
                // Operator is a Kind value encoded as u32, not a NodeIndex
                const opStr = self.kindToUnaryString(pu.Operator);
                try self.write(opStr);
                try self.printExpression(pu.Operand);
            },

            // ---------------------------------------------------------------
            // PostfixUnaryExpression
            // ---------------------------------------------------------------
            .PostfixUnaryExpression => |pu| {
                try self.printExpression(pu.Operand);
                const opStr = self.kindToUnaryString(pu.Operator);
                try self.write(opStr);
            },

            // ---------------------------------------------------------------
            // CallExpression
            // ---------------------------------------------------------------
            .CallExpression => |ce| {
                try self.printExpression(ce.Expression);
                if (ce.QuestionDotToken != null) try self.write("?.");
                try self.write("(");
                const args = self.tree.getNodeList(ce.Arguments);
                var i: usize = 0;
                while (i < args.len) : (i += 1) {
                    if (i > 0) try self.write(", ");
                    try self.printExpression(args[i]);
                }
                try self.write(")");
            },

            // ---------------------------------------------------------------
            // NewExpression
            // ---------------------------------------------------------------
            .NewExpression => |ne| {
                try self.write("new ");
                try self.printExpression(ne.Expression);
                try self.write("(");
                if (ne.Arguments) |argsIdx| {
                    const args = self.tree.getNodeList(argsIdx);
                    var i: usize = 0;
                    while (i < args.len) : (i += 1) {
                        if (i > 0) try self.write(", ");
                        try self.printExpression(args[i]);
                    }
                }
                try self.write(")");
            },

            // ---------------------------------------------------------------
            // PropertyAccessExpression
            // ---------------------------------------------------------------
            .PropertyAccessExpression => |pa| {
                try self.printExpression(pa.Expression);
                if (pa.QuestionDotToken != null) {
                    try self.write("?.");
                } else {
                    try self.write(".");
                }
                const nameNode = self.tree.getNode(pa.name);
                if (nameNode == .Identifier) {
                    try self.write(nameNode.Identifier.Text);
                } else if (nameNode == .PrivateIdentifier) {
                    try self.write(nameNode.PrivateIdentifier.Text);
                }
            },

            // ---------------------------------------------------------------
            // ElementAccessExpression
            // ---------------------------------------------------------------
            .ElementAccessExpression => |ea| {
                try self.printExpression(ea.Expression);
                if (ea.QuestionDotToken != null) try self.write("?.");
                try self.write("[");
                try self.printExpression(ea.ArgumentExpression);
                try self.write("]");
            },

            // ---------------------------------------------------------------
            // ArrowFunction
            // ---------------------------------------------------------------
            .ArrowFunction => |af| {
                try self.write("(");
                try self.printParameterList(af.Parameters);
                try self.write(") => ");
                if (af.Body) |bodyIdx| {
                    const bodyNode = self.tree.getNode(bodyIdx);
                    if (bodyNode == .Block) {
                        try self.printStatement(bodyIdx);
                    } else {
                        try self.printExpression(bodyIdx);
                    }
                }
            },

            // ---------------------------------------------------------------
            // FunctionExpression
            // ---------------------------------------------------------------
            .FunctionExpression => |fe| {
                try self.write("function");
                if (fe.name) |nameIdx| {
                    const nameNode = self.tree.getNode(nameIdx);
                    if (nameNode == .Identifier) {
                        try self.writeByte(' ');
                        try self.write(nameNode.Identifier.Text);
                    }
                }
                try self.write("(");
                try self.printParameterList(fe.Parameters);
                try self.write(") ");
                if (fe.Body) |bodyIdx| {
                    try self.printStatement(bodyIdx);
                } else {
                    try self.write("{}");
                }
            },

            // ---------------------------------------------------------------
            // ObjectLiteralExpression
            // ---------------------------------------------------------------
            .ObjectLiteralExpression => |ole| {
                try self.write("{");
                const props = self.tree.getNodeList(ole.Properties);
                if (props.len > 0 and ole.MultiLine != 0) {
                    self.increaseIndent();
                }
                var i: usize = 0;
                while (i < props.len) : (i += 1) {
                    if (i > 0) try self.write(",");
                    if (ole.MultiLine != 0) {
                        try self.writeLine();
                    } else if (i > 0) {
                        try self.write(" ");
                    }
                    try self.printObjectProperty(props[i]);
                }
                if (props.len > 0 and ole.MultiLine != 0) {
                    self.decreaseIndent();
                    try self.writeLine();
                }
                try self.write("}");
            },

            // ---------------------------------------------------------------
            // ArrayLiteralExpression
            // ---------------------------------------------------------------
            .ArrayLiteralExpression => |ale| {
                try self.write("[");
                const elems = self.tree.getNodeList(ale.Elements);
                var i: usize = 0;
                while (i < elems.len) : (i += 1) {
                    if (i > 0) try self.write(", ");
                    try self.printExpression(elems[i]);
                }
                try self.write("]");
            },

            // ---------------------------------------------------------------
            // ConditionalExpression
            // ---------------------------------------------------------------
            .ConditionalExpression => |ce| {
                try self.printExpression(ce.Condition);
                try self.write(" ? ");
                try self.printExpression(ce.WhenTrue);
                try self.write(" : ");
                try self.printExpression(ce.WhenFalse);
            },

            // ---------------------------------------------------------------
            // ParenthesizedExpression
            // ---------------------------------------------------------------
            .ParenthesizedExpression => |pe| {
                try self.write("(");
                try self.printExpression(pe.Expression);
                try self.write(")");
            },

            // ---------------------------------------------------------------
            // AsExpression → drop type cast, emit only expression
            // ---------------------------------------------------------------
            .AsExpression => |ae| {
                try self.printExpression(ae.Expression);
            },

            // ---------------------------------------------------------------
            // SatisfiesExpression → drop type, emit only expression
            // ---------------------------------------------------------------
            .SatisfiesExpression => |se| {
                try self.printExpression(se.Expression);
            },

            // ---------------------------------------------------------------
            // NonNullExpression → drop !, emit only expression
            // ---------------------------------------------------------------
            .NonNullExpression => |nne| {
                try self.printExpression(nne.Expression);
            },

            // ---------------------------------------------------------------
            // TypeOfExpression
            // ---------------------------------------------------------------
            .TypeOfExpression => |te| {
                try self.write("typeof ");
                try self.printExpression(te.Expression);
            },

            // ---------------------------------------------------------------
            // VoidExpression
            // ---------------------------------------------------------------
            .VoidExpression => |ve| {
                try self.write("void ");
                try self.printExpression(ve.Expression);
            },

            // ---------------------------------------------------------------
            // AwaitExpression
            // ---------------------------------------------------------------
            .AwaitExpression => |ae| {
                try self.write("await ");
                try self.printExpression(ae.Expression);
            },

            // ---------------------------------------------------------------
            // DeleteExpression
            // ---------------------------------------------------------------
            .DeleteExpression => |de| {
                try self.write("delete ");
                try self.printExpression(de.Expression);
            },

            // ---------------------------------------------------------------
            // SpreadElement
            // ---------------------------------------------------------------
            .SpreadElement => |se| {
                try self.write("...");
                try self.printExpression(se.Expression);
            },

            // ---------------------------------------------------------------
            // YieldExpression
            // ---------------------------------------------------------------
            .YieldExpression => |ye| {
                try self.write("yield");
                if (ye.AsteriskToken != null) try self.write("*");
                if (ye.Expression) |exprIdx| {
                    if (exprIdx != 0) {
                        try self.write(" ");
                        try self.printExpression(exprIdx);
                    }
                }
            },

            // ---------------------------------------------------------------
            // TypeAssertion → drop type annotation
            // ---------------------------------------------------------------
            .TypeAssertionExpression => |ta| {
                try self.printExpression(ta.Expression);
            },

            // ---------------------------------------------------------------
            // ClassExpression
            // ---------------------------------------------------------------
            .ClassExpression => |ce| {
                try self.write("class");
                if (ce.name) |nameIdx| {
                    const nameNode = self.tree.getNode(nameIdx);
                    if (nameNode == .Identifier) {
                        try self.write(" ");
                        try self.write(nameNode.Identifier.Text);
                    }
                }
                try self.write(" {");
                self.increaseIndent();
                const members = self.tree.getNodeList(ce.Members);
                for (members) |memberIdx| {
                    try self.writeLine();
                    try self.printClassMember(memberIdx);
                }
                self.decreaseIndent();
                if (members.len > 0) try self.writeLine();
                try self.write("}");
            },

            // ---------------------------------------------------------------
            // ExpressionWithTypeArguments (heritage clause types)
            // ---------------------------------------------------------------
            .ExpressionWithTypeArguments => |ewta| {
                try self.printExpression(ewta.Expression);
            },

            // ---------------------------------------------------------------
            // QualifiedName → A.B
            // ---------------------------------------------------------------
            .QualifiedName => |qn| {
                try self.printExpression(qn.Left);
                try self.write(".");
                try self.printExpression(qn.Right);
            },

            // ---------------------------------------------------------------
            // MetaProperty (e.g. new.target, import.meta)
            // ---------------------------------------------------------------
            .MetaProperty => |mp| {
                const kwNode = self.tree.getNode(mp.KeywordToken);
                _ = kwNode;
                // Just emit the keyword + .name
                try self.printExpression(mp.name);
            },

            // Unknown / unsupported – emit nothing
            else => {},
        }
    }

    // -------------------------------------------------------------------------
    // Object property helper
    // -------------------------------------------------------------------------

    fn printObjectProperty(self: *Printer, nodeIndex: u32) anyerror!void {
        if (nodeIndex == 0) return;
        const node = self.tree.getNode(nodeIndex);
        switch (node) {
            .PropertyAssignment => |pa| {
                try self.printPropertyName(pa.name);
                try self.write(": ");
                try self.printExpression(pa.Initializer);
            },
            .ShorthandPropertyAssignment => |spa| {
                const nameNode = self.tree.getNode(spa.name);
                if (nameNode == .Identifier) try self.write(nameNode.Identifier.Text);
                if (spa.ObjectAssignmentInitializer) |initIdx| {
                    if (initIdx != 0) {
                        try self.write(" = ");
                        try self.printExpression(initIdx);
                    }
                }
            },
            .SpreadAssignment => |sa| {
                try self.write("...");
                try self.printExpression(sa.Expression);
            },
            .MethodDeclaration => |md| {
                try self.printPropertyName(md.name);
                try self.write("(");
                try self.printParameterList(md.Parameters);
                try self.write(") ");
                if (md.Body) |bodyIdx| {
                    try self.printStatement(bodyIdx);
                } else {
                    try self.write("{}");
                }
            },
            else => try self.printExpression(nodeIndex),
        }
    }

    // -------------------------------------------------------------------------
    // Operator kind → string (for unary operators stored as Kind u32 value)
    // -------------------------------------------------------------------------

    fn kindToUnaryString(_: *const Printer, kindValue: u32) []const u8 {
        // Map Kind enum integer values to operator strings.
        // PlusPlusToken = 45, MinusMinusToken = 46, PlusToken = 39,
        // MinusToken = 40, ExclamationToken = 53, TildeToken = 54
        return switch (kindValue) {
            39 => "+",   // PlusToken
            40 => "-",   // MinusToken
            45 => "++",  // PlusPlusToken
            46 => "--",  // MinusMinusToken
            53 => "!",   // ExclamationToken
            54 => "~",   // TildeToken
            113 => "typeof ", // TypeOfKeyword
            115 => "void ",   // VoidKeyword
            134 => "await ",  // AwaitKeyword
            else => "",
        };
    }
};

// =============================================================================
// Tests
// =============================================================================

test "basic printer - function declaration" {
    const parser_pkg = @import("../parser/parser.zig");

    const sourceText =
        \\function add(x: number, y: number): number {
        \\    return x + y;
        \\}
    ;

    var p = parser_pkg.Parser.init(std.testing.allocator, sourceText);
    defer p.deinit();

    const astIndex = try p.parseSourceFile();

    var printer = Printer.init(std.testing.allocator, &p.ast);
    defer printer.deinit();

    try printer.printSourceFile(astIndex);

    const output = printer.getOutput();
    std.debug.print("\n--- Printer output ---\n{s}\n--- end ---\n", .{output});

    // Verify output contains 'function' keyword
    try std.testing.expect(std.mem.indexOf(u8, output, "function") != null);
    // Verify return is present
    try std.testing.expect(std.mem.indexOf(u8, output, "return") != null);
    // No type annotations should appear
    try std.testing.expect(std.mem.indexOf(u8, output, ": number") == null);
}

test "printer - variable statement" {
    const parser_pkg = @import("../parser/parser.zig");

    const sourceText =
        \\const x: number = 42;
        \\let y = "hello";
        \\var z = true;
    ;

    var p = parser_pkg.Parser.init(std.testing.allocator, sourceText);
    defer p.deinit();

    const astIndex = try p.parseSourceFile();

    var printer = Printer.init(std.testing.allocator, &p.ast);
    defer printer.deinit();

    try printer.printSourceFile(astIndex);

    const output = printer.getOutput();
    std.debug.print("\n--- Printer variable output ---\n{s}\n--- end ---\n", .{output});

    try std.testing.expect(std.mem.indexOf(u8, output, "const") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "let") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "var") != null);
    // No type annotations
    try std.testing.expect(std.mem.indexOf(u8, output, ": number") == null);
}

test "printer - class declaration" {
    const parser_pkg = @import("../parser/parser.zig");

    const sourceText =
        \\class Foo {
        \\    compute() {
        \\        let z = 1 + 2;
        \\    }
        \\}
    ;

    var p = parser_pkg.Parser.init(std.testing.allocator, sourceText);
    defer p.deinit();

    const astIndex = try p.parseSourceFile();

    var printer = Printer.init(std.testing.allocator, &p.ast);
    defer printer.deinit();

    try printer.printSourceFile(astIndex);

    const output = printer.getOutput();
    std.debug.print("\n--- Printer class output ---\n{s}\n--- end ---\n", .{output});

    try std.testing.expect(std.mem.indexOf(u8, output, "class") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Foo") != null);
}
