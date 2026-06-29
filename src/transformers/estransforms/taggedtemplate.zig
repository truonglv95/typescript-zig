const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const visitor = @import("../../ast/visitor.zig");
const transformers = @import("../transformer.zig");
const factory_pkg = @import("../../printer/factory.zig");
const TokenFlags = @import("../../scanner/scanner.zig").TokenFlags;

pub const TaggedTemplateTransformer = struct {
    allocator: std.mem.Allocator,
    transformer: *transformers.Transformer,
    currentSourceFile: ast.NodeIndex = 0,
    taggedTemplateStringDeclarations: std.ArrayListUnmanaged(ast.NodeIndex),

    pub fn new(allocator: std.mem.Allocator, opt: *transformers.TransformOptions) !*transformers.Transformer {
        const tx = try allocator.create(TaggedTemplateTransformer);
        tx.allocator = allocator;
        tx.taggedTemplateStringDeclarations = .empty;
        tx.currentSourceFile = 0;
        tx.transformer = try transformers.Transformer.init(allocator, visit, tx, opt.context);
        return tx.transformer;
    }

    fn visit(ctx: ?*anyopaque, v: *visitor.NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        const self = @as(*TaggedTemplateTransformer, @ptrCast(@alignCast(ctx.?)));
        if (node == 0) return 0;

        const tree = v.tree;
        const nodeKind = tree.getNodeKind(node);
        switch (nodeKind) {
            .SourceFile => {
                return self.visitSourceFile(v, node);
            },
            .TaggedTemplateExpression => {
                return self.visitTaggedTemplateExpression(v, node);
            },
            else => {
                return v.visitEachChild(node);
            },
        }
    }

    fn visitSourceFile(self: *TaggedTemplateTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        self.currentSourceFile = node;
        self.taggedTemplateStringDeclarations.clearRetainingCapacity();
        if (std.mem.indexOfScalar(u8, v.tree.sourceText, '\\') == null) return node;
        if (!containsInvalidTaggedTemplate(v.tree, node)) return node;

        const visited = v.visitEachChild(node);

        const result = if (self.taggedTemplateStringDeclarations.items.len > 0) result_block: {
            const tree = v.tree;
            const visitedSourceFile = tree.getNode(visited).SourceFile;
            const statements = tree.getNodeList(visitedSourceFile.Statements);

            var newStatements = std.ArrayList(ast.NodeIndex).empty;
            defer newStatements.deinit(self.allocator);
            newStatements.appendSlice(self.allocator, statements) catch unreachable;

            const varDeclList = self.transformer.factory.newVariableDeclarationList(
                self.transformer.factory.newNodeList(self.taggedTemplateStringDeclarations.items),
                0,
            );
            const varStmt = self.transformer.factory.newVariableStatement(0, varDeclList);
            newStatements.append(self.allocator, varStmt) catch unreachable;

            const stmtList = self.transformer.factory.newNodeList(newStatements.items);
            tree.positions.items[stmtList] = tree.positions.items[visitedSourceFile.Statements];

            break :result_block self.transformer.factory.updateSourceFile(
                visited,
                visitedSourceFile,
                stmtList,
                visitedSourceFile.EndOfFileToken,
            );
        } else visited;

        self.transformer.emitContext.addEmitHelpers(result, self.transformer.emitContext.readEmitHelpers());
        return result;
    }

    fn visitTaggedTemplateExpression(self: *TaggedTemplateTransformer, v: *visitor.NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        const tree = v.tree;
        const n = tree.getNode(node).TaggedTemplateExpression;
        const tag = v.visitNode(n.Tag);
        const template = n.Template;

        if (!hasInvalidEscape(tree, template)) {
            return self.transformer.factory.updateTaggedTemplateExpression(
                node,
                n,
                tag,
                n.QuestionDotToken orelse 0,
                n.TypeArguments orelse 0,
                v.visitNode(template),
                n.Flags,
            );
        }

        const f = self.transformer.factory;

        // Build template arguments
        var templateArguments = std.ArrayList(ast.NodeIndex).empty;
        defer templateArguments.deinit(self.allocator);

        // Placeholder for the template object
        templateArguments.append(self.allocator, 0) catch unreachable;

        var cookedStrings = std.ArrayList(ast.NodeIndex).empty;
        defer cookedStrings.deinit(self.allocator);

        var rawStrings = std.ArrayList(ast.NodeIndex).empty;
        defer rawStrings.deinit(self.allocator);

        const templateKind = tree.getNodeKind(template);
        if (templateKind == .NoSubstitutionTemplateLiteral) {
            cookedStrings.append(self.allocator, createTemplateCooked(f, tree, template)) catch unreachable;
            rawStrings.append(self.allocator, getRawLiteral(f, tree, template)) catch unreachable;
        } else if (templateKind == .TemplateExpression) {
            const te = tree.getNode(template).TemplateExpression;
            cookedStrings.append(self.allocator, createTemplateCooked(f, tree, te.Head)) catch unreachable;
            rawStrings.append(self.allocator, getRawLiteral(f, tree, te.Head)) catch unreachable;

            const spans = tree.getNodeList(te.TemplateSpans);
            for (spans) |spanIdx| {
                const span = tree.getNode(spanIdx).TemplateSpan;
                cookedStrings.append(self.allocator, createTemplateCooked(f, tree, span.Literal)) catch unreachable;
                rawStrings.append(self.allocator, getRawLiteral(f, tree, span.Literal)) catch unreachable;
                templateArguments.append(self.allocator, v.visitNode(span.Expression)) catch unreachable;
            }
        }

        const cookedArray = f.newArrayLiteralExpression(f.newNodeList(cookedStrings.items), false);
        const rawArray = f.newArrayLiteralExpression(f.newNodeList(rawStrings.items), false);

        // Helper call __makeTemplateObject(cookedArray, rawArray)
        self.transformer.emitContext.requestEmitHelper(&@import("../../printer/helpers.zig").makeTemplateObjectHelper);
        const helperName = f.newIdentifier("__makeTemplateObject");
        const helperArgs = f.newNodeList(&[_]ast.NodeIndex{ cookedArray, rawArray });
        const helperCall = f.newCallExpression(helperName, @as(u32, 0), @as(u32, 0), helperArgs, @as(u32, 0));

        const ast_utils = @import("../../ast/ast_utils.zig");
        if (ast_utils.isExternalModule(tree, self.currentSourceFile)) {
            const tempVar = f.createUniqueName("templateObject") catch unreachable;

            const varDecl = f.newVariableDeclaration(tempVar, 0, 0, 0);
            self.taggedTemplateStringDeclarations.append(self.allocator, varDecl) catch unreachable;

            const assignExpr = f.newBinaryExpression(
                0,
                tempVar,
                0,
                f.newToken(.{ .EqualsToken = {} }),
                helperCall,
            );
            const orExpr = f.newBinaryExpression(
                0,
                tempVar,
                0,
                f.newToken(.{ .BarBarToken = {} }),
                assignExpr,
            );
            templateArguments.items[0] = orExpr;
        } else {
            templateArguments.items[0] = helperCall;
        }

        const argsList = f.newNodeList(templateArguments.items);
        const call = f.newCallExpression(tag, @as(u32, 0), @as(u32, 0), argsList, @as(u32, 0));
        tree.positions.items[call] = tree.positions.items[node];
        return call;
    }
};

const TokenFlagsIsInvalid = TokenFlags.Octal | TokenFlags.ContainsLeadingZero | TokenFlags.ContainsInvalidSeparator | TokenFlags.ContainsInvalidEscape;

fn createTemplateCooked(f: *factory_pkg.NodeFactory, tree: *ast.Ast, template: ast.NodeIndex) ast.NodeIndex {
    const nodeData = tree.getNode(template);
    const templateFlags = switch (nodeData) {
        .NoSubstitutionTemplateLiteral => |n| n.TemplateFlags,
        .TemplateHead => |n| n.TemplateFlags,
        .TemplateMiddle => |n| n.TemplateFlags, // middle is not used directly as whole template but just in case
        .TemplateTail => |n| n.TemplateFlags,
        else => 0,
    };
    if (templateFlags & TokenFlagsIsInvalid != 0) {
        return f.newVoidZeroExpression();
    }
    const text = switch (nodeData) {
        .NoSubstitutionTemplateLiteral => |n| n.Text,
        .TemplateHead => |n| n.Text,
        .TemplateMiddle => |n| n.Text,
        .TemplateTail => |n| n.Text,
        else => "",
    };
    return f.newStringLiteral(text, false);
}

fn containsInvalidTaggedTemplate(tree: *ast.Ast, node: ast.NodeIndex) bool {
    if (node == 0) return false;
    if (tree.getNode(node) == .TaggedTemplateExpression and hasInvalidEscape(tree, tree.getNode(node).TaggedTemplateExpression.Template)) return true;
    const Context = struct {
        tree: *ast.Ast,
        fn check(ctx: *@This(), child: ast.NodeIndex) bool {
            return containsInvalidTaggedTemplate(ctx.tree, child);
        }
    };
    var context = Context{ .tree = tree };
    return @import("../../ast/ast_utils.zig").forEachChildBool(tree, node, &context, Context.check);
}

fn getRawLiteral(f: *factory_pkg.NodeFactory, tree: *ast.Ast, node: ast.NodeIndex) ast.NodeIndex {
    const nodeData = tree.getNode(node);
    const rawText = switch (nodeData) {
        .NoSubstitutionTemplateLiteral => |n| n.RawText,
        .TemplateHead => |n| n.RawText,
        .TemplateMiddle => |n| n.RawText,
        .TemplateTail => |n| n.RawText,
        else => "",
    };

    var text = rawText;
    if (text.len == 0) {
        const range = tree.positions.items[node];
        var pos = range.pos;
        pos = @as(u32, @intCast(@import("../../scanner/scanner.zig").skipTrivia(tree.sourceText, pos)));
        const end = range.end;
        var fullText = tree.sourceText[pos..end];

        const kindVal = tree.getNodeKind(node);
        const isLast = (kindVal == .NoSubstitutionTemplateLiteral or kindVal == .TemplateTail);
        const endLen: usize = if (isLast) 1 else 2;
        if (fullText.len >= 1 + endLen) {
            text = fullText[1 .. fullText.len - endLen];
        } else {
            text = "";
        }
    }

    var normalized = std.ArrayList(u8).empty;
    defer normalized.deinit(f.allocator);

    var i: usize = 0;
    while (i < text.len) {
        if (i + 1 < text.len and text[i] == '\r' and text[i + 1] == '\n') {
            normalized.append(f.allocator, '\n') catch unreachable;
            i += 2;
        } else if (text[i] == '\r') {
            normalized.append(f.allocator, '\n') catch unreachable;
            i += 1;
        } else {
            normalized.append(f.allocator, text[i]) catch unreachable;
            i += 1;
        }
    }

    const final_text = f.allocator.dupe(u8, normalized.items) catch unreachable;
    // This is a synthesized string literal containing the template's raw
    // characters. Keep its source range synthesized so the printer escapes
    // backslashes instead of copying the raw text into a quoted JS string.
    return f.newStringLiteral(final_text, false);
}

fn hasInvalidEscape(tree: *ast.Ast, template: ast.NodeIndex) bool {
    const templateKind = tree.getNodeKind(template);
    if (templateKind == .NoSubstitutionTemplateLiteral) {
        const n = tree.getNode(template).NoSubstitutionTemplateLiteral;
        return (n.TemplateFlags & TokenFlags.ContainsInvalidEscape) != 0;
    } else if (templateKind == .TemplateExpression) {
        const te = tree.getNode(template).TemplateExpression;
        const head = tree.getNode(te.Head).TemplateHead;
        if ((head.TemplateFlags & TokenFlags.ContainsInvalidEscape) != 0) {
            return true;
        }
        const spans = tree.getNodeList(te.TemplateSpans);
        for (spans) |spanIdx| {
            const span = tree.getNode(spanIdx).TemplateSpan;
            const literal = tree.getNode(span.Literal);
            const literalFlags = switch (literal) {
                .TemplateMiddle => |m| m.TemplateFlags,
                .TemplateTail => |t| t.TemplateFlags,
                else => 0,
            };
            if ((literalFlags & TokenFlags.ContainsInvalidEscape) != 0) {
                return true;
            }
        }
    }
    return false;
}
