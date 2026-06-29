const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const core = @import("../core/core.zig");
const transformer_mod = @import("transformer.zig");
const visitor_mod = @import("../ast/visitor.zig");
const emitflags = @import("../printer/emitflags.zig");

/// Classic JSX transform (`jsx: react`). Automatic-runtime imports are kept
/// separate because they require source-file import synthesis and resolver
/// integration that the current standalone emitter does not yet provide.
pub const JSXTransformer = struct {
    transformer: *transformer_mod.Transformer,
    allocator: std.mem.Allocator,
    compiler_options: *core.CompilerOptions,
    uses_jsx: bool = false,
    uses_jsxs: bool = false,
    classic_factory: []const u8 = "React.createElement",

    pub fn new(allocator: std.mem.Allocator, opt: *transformer_mod.TransformOptions) !*transformer_mod.Transformer {
        const tx = try allocator.create(JSXTransformer);
        tx.allocator = allocator;
        tx.compiler_options = opt.compilerOptions;
        tx.uses_jsx = false;
        tx.uses_jsxs = false;
        tx.classic_factory = "React.createElement";
        tx.transformer = try transformer_mod.Transformer.init(allocator, visit, tx, opt.context);
        return tx.transformer;
    }

    fn visit(ctx: ?*anyopaque, v: *visitor_mod.NodeVisitor, node: ast.NodeIndex) ast.NodeIndex {
        const self: *JSXTransformer = @ptrCast(@alignCast(ctx.?));
        if (node == 0) return 0;
        return switch (v.tree.getNode(node)) {
            .SourceFile => |n| self.transformSourceFile(v, node, n),
            .JsxElement => |n| self.transformElement(v, n.OpeningElement, n.Children),
            .JsxSelfClosingElement => |n| self.transformOpeningLike(v, n.TagName, n.Attributes, 0),
            .JsxFragment => |n| self.transformFragment(v, n.Children),
            .JsxExpression => |n| if (n.Expression) |expression| v.visitNode(expression) else 0,
            .JsxText => |n| self.transformText(v, n.Text),
            else => v.visitEachChild(node),
        };
    }

    fn isAutomatic(self: *JSXTransformer) bool {
        return self.compiler_options.jsx == .ReactJSX or self.compiler_options.jsx == .ReactJSXDev;
    }

    fn transformSourceFile(self: *JSXTransformer, v: *visitor_mod.NodeVisitor, node_index: ast.NodeIndex, node: ast_gen.SourceFileNode) ast.NodeIndex {
        self.uses_jsx = false;
        self.uses_jsxs = false;
        self.classic_factory = findPragmaValue(v.tree.sourceText, "@jsx ") orelse "React.createElement";
        const visited = v.visitEachChild(node_index);
        if (!self.isAutomatic() or (!self.uses_jsx and !self.uses_jsxs)) return visited;

        const visited_source = v.tree.getNode(visited).SourceFile;
        var statements = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer statements.deinit(self.allocator);
        statements.append(self.allocator, self.createRuntimeImport(v)) catch unreachable;
        statements.appendSlice(self.allocator, v.tree.getNodeList(visited_source.Statements)) catch unreachable;
        return self.transformer.factory.updateSourceFile(
            visited,
            visited_source,
            self.transformer.factory.newNodeList(statements.items),
            node.EndOfFileToken,
        );
    }

    fn transformElement(self: *JSXTransformer, v: *visitor_mod.NodeVisitor, opening: ast.NodeIndex, children: ast.NodeIndex) ast.NodeIndex {
        const data = v.tree.getNode(opening).JsxOpeningElement;
        return self.transformOpeningLike(v, data.TagName, data.Attributes, children);
    }

    fn transformFragment(self: *JSXTransformer, v: *visitor_mod.NodeVisitor, children: ast.NodeIndex) ast.NodeIndex {
        if (self.isAutomatic()) {
            return self.createAutomaticCall(v, self.transformer.factory.newIdentifier("_Fragment"), 0, children);
        }
        const react = self.transformer.factory.newIdentifier("React");
        const fragment = self.transformer.factory.newPropertyAccessExpression(
            react,
            0,
            self.transformer.factory.newIdentifier("Fragment"),
            0,
        );
        return self.createElementCall(v, fragment, 0, children);
    }

    fn transformOpeningLike(self: *JSXTransformer, v: *visitor_mod.NodeVisitor, tag_name: ast.NodeIndex, attributes: ast.NodeIndex, children: ast.NodeIndex) ast.NodeIndex {
        const tag = self.transformTagName(v, tag_name);
        if (self.isAutomatic()) return self.createAutomaticCall(v, tag, attributes, children);
        const props = self.transformAttributes(v, attributes);
        return self.createElementCall(v, tag, props, children);
    }

    fn createAutomaticCall(self: *JSXTransformer, v: *visitor_mod.NodeVisitor, tag: ast.NodeIndex, attributes: ast.NodeIndex, children: ast.NodeIndex) ast.NodeIndex {
        var properties = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer properties.deinit(self.allocator);
        if (attributes != 0) {
            const attrs = v.tree.getNode(v.tree.getNode(attributes).JsxAttributes.Properties);
            const attrs_list = switch (attrs) {
                .SyntaxList => |n| v.tree.getNodeList(n.Children),
                else => v.tree.getNodeList(v.tree.getNode(attributes).JsxAttributes.Properties),
            };
            for (attrs_list) |attribute| {
                switch (v.tree.getNode(attribute)) {
                    .JsxAttribute => |n| properties.append(self.allocator, self.transformer.factory.newPropertyAssignment(
                        0,
                        self.transformAttributeName(v, n.name),
                        0,
                        0,
                        self.transformAttributeInitializer(v, n.Initializer orelse 0),
                    )) catch unreachable,
                    .JsxSpreadAttribute => |n| {
                        const expression = v.visitNode(n.Expression);
                        if (v.tree.getNode(expression) == .ObjectLiteralExpression) {
                            const object = v.tree.getNode(expression).ObjectLiteralExpression;
                            properties.appendSlice(self.allocator, v.tree.getNodeList(object.Properties)) catch unreachable;
                        } else {
                            properties.append(self.allocator, self.transformer.factory.newSpreadAssignment(expression)) catch unreachable;
                        }
                    },
                    else => {},
                }
            }
        }

        var semantic_children = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer semantic_children.deinit(self.allocator);
        if (children != 0) {
            for (v.tree.getNodeList(children)) |child| {
                const expression = v.visitNode(child);
                if (expression != 0) semantic_children.append(self.allocator, expression) catch unreachable;
            }
        }
        if (semantic_children.items.len == 1) {
            properties.append(self.allocator, self.transformer.factory.newPropertyAssignment(0, self.transformer.factory.newIdentifier("children"), 0, 0, semantic_children.items[0])) catch unreachable;
        } else if (semantic_children.items.len > 1) {
            const array = self.transformer.factory.newArrayLiteralExpression(self.transformer.factory.newNodeList(semantic_children.items), false);
            properties.append(self.allocator, self.transformer.factory.newPropertyAssignment(0, self.transformer.factory.newIdentifier("children"), 0, 0, array)) catch unreachable;
        }

        const static_children = semantic_children.items.len > 1;
        if (static_children) self.uses_jsxs = true else self.uses_jsx = true;
        const callee = self.transformer.factory.newIdentifier(if (static_children) "_jsxs" else "_jsx");
        const props = self.transformer.factory.newObjectLiteralExpression(self.transformer.factory.newNodeList(properties.items), @as(u32, if (properties.items.len >= 5) 2 else 0));
        const args = [_]ast.NodeIndex{ tag, props };
        return self.transformer.factory.newCallExpression(callee, 0, 0, self.transformer.factory.newNodeList(&args), 0);
    }

    fn createRuntimeImport(self: *JSXTransformer, v: *visitor_mod.NodeVisitor) ast.NodeIndex {
        var specifiers = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer specifiers.deinit(self.allocator);
        if (self.uses_jsx) specifiers.append(self.allocator, self.createImportSpecifier(v, "jsx", "_jsx")) catch unreachable;
        if (self.uses_jsxs) specifiers.append(self.allocator, self.createImportSpecifier(v, "jsxs", "_jsxs")) catch unreachable;
        // Fragments are referenced whenever `_Fragment` was synthesized. It is
        // harmless to include it only when the identifier occurs in the tree;
        // for now fragments mark both automatic call paths through this flag.
        const named_imports = v.tree.pushNode(.{ .NamedImports = .{ .Flags = 0, .Elements = self.transformer.factory.newNodeList(specifiers.items) } }) catch unreachable;
        const import_clause = v.tree.pushNode(.{ .ImportClause = .{
            .Flags = 0,
            .Symbol = 0,
            .PhaseModifier = null,
            .name = null,
            .NamedBindings = named_imports,
        } }) catch unreachable;
        return v.tree.pushNode(.{ .ImportDeclaration = .{
            .Flags = 0,
            .modifiers = null,
            .modifierFlags = 0,
            .Symbol = 0,
            .ImportClause = import_clause,
            .ModuleSpecifier = self.transformer.factory.newStringLiteral("react/jsx-runtime", false),
            .Attributes = null,
        } }) catch unreachable;
    }

    fn createImportSpecifier(self: *JSXTransformer, v: *visitor_mod.NodeVisitor, imported: []const u8, local: []const u8) ast.NodeIndex {
        return v.tree.pushNode(.{ .ImportSpecifier = .{
            .Flags = 0,
            .Symbol = 0,
            .IsTypeOnly = 0,
            .PropertyName = self.transformer.factory.newIdentifier(imported),
            .name = self.transformer.factory.newIdentifier(local),
        } }) catch unreachable;
    }

    fn transformTagName(self: *JSXTransformer, v: *visitor_mod.NodeVisitor, tag_name: ast.NodeIndex) ast.NodeIndex {
        return switch (v.tree.getNode(tag_name)) {
            .Identifier => |n| if (isIntrinsicTag(n.Text))
                self.transformer.factory.newStringLiteral(n.Text, false)
            else
                v.visitNode(tag_name),
            .JsxNamespacedName => |n| blk: {
                const namespace = ast_utils.getText(v.tree, n.Namespace);
                const name = ast_utils.getText(v.tree, n.name);
                const text = std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ namespace, name }) catch unreachable;
                break :blk self.transformer.factory.newStringLiteral(text, false);
            },
            else => v.visitNode(tag_name),
        };
    }

    fn transformAttributes(self: *JSXTransformer, v: *visitor_mod.NodeVisitor, attributes: ast.NodeIndex) ast.NodeIndex {
        if (attributes == 0) return 0;
        const properties_list = v.tree.getNode(attributes).JsxAttributes.Properties;
        const attributes_slice = v.tree.getNodeList(properties_list);
        if (attributes_slice.len == 0) return 0;

        var properties = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer properties.deinit(self.allocator);
        for (attributes_slice) |attribute| {
            switch (v.tree.getNode(attribute)) {
                .JsxAttribute => |n| {
                    const name = self.transformAttributeName(v, n.name);
                    const initializer = self.transformAttributeInitializer(v, n.Initializer orelse 0);
                    properties.append(self.allocator, self.transformer.factory.newPropertyAssignment(0, name, 0, 0, initializer)) catch unreachable;
                },
                .JsxSpreadAttribute => |n| {
                    properties.append(self.allocator, self.transformer.factory.newSpreadAssignment(v.visitNode(n.Expression))) catch unreachable;
                },
                else => {},
            }
        }
        return self.transformer.factory.newObjectLiteralExpression(self.transformer.factory.newNodeList(properties.items), false);
    }

    fn transformAttributeName(self: *JSXTransformer, v: *visitor_mod.NodeVisitor, name: ast.NodeIndex) ast.NodeIndex {
        return switch (v.tree.getNode(name)) {
            .Identifier => v.visitNode(name),
            .JsxNamespacedName => |n| blk: {
                const namespace = ast_utils.getText(v.tree, n.Namespace);
                const local_name = ast_utils.getText(v.tree, n.name);
                const text = std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ namespace, local_name }) catch unreachable;
                break :blk self.transformer.factory.newStringLiteral(text, false);
            },
            else => v.visitNode(name),
        };
    }

    fn transformAttributeInitializer(self: *JSXTransformer, v: *visitor_mod.NodeVisitor, initializer: ast.NodeIndex) ast.NodeIndex {
        if (initializer == 0) return self.transformer.factory.newToken(.{ .TrueKeyword = {} });
        return switch (v.tree.getNode(initializer)) {
            .StringLiteral => |n| self.newDecodedString(v, n.Text, (n.TokenFlags & (1 << 16)) != 0),
            .JsxExpression => |n| if (n.Expression) |expression| v.visitNode(expression) else self.transformer.factory.newToken(.{ .TrueKeyword = {} }),
            else => v.visitNode(initializer),
        };
    }

    fn createElementCall(self: *JSXTransformer, v: *visitor_mod.NodeVisitor, tag: ast.NodeIndex, props: ast.NodeIndex, children: ast.NodeIndex) ast.NodeIndex {
        var args = std.ArrayListUnmanaged(ast.NodeIndex).empty;
        defer args.deinit(self.allocator);
        args.append(self.allocator, tag) catch unreachable;
        args.append(self.allocator, if (props != 0) props else self.transformer.factory.newToken(.{ .NullKeyword = {} })) catch unreachable;

        if (children != 0) {
            for (v.tree.getNodeList(children)) |child| {
                const child_kind = v.tree.getNodeKind(child);
                const expression = v.visitNode(child);
                if (expression != 0) {
                    if (child_kind == .JsxElement or child_kind == .JsxSelfClosingElement or child_kind == .JsxFragment) {
                        self.transformer.emitContext.addEmitFlags(expression, emitflags.EmitFlags.StartOnNewLine) catch unreachable;
                    }
                    args.append(self.allocator, expression) catch unreachable;
                }
            }
        }

        const callee = self.createDottedName(self.classic_factory);
        return self.transformer.factory.newCallExpression(callee, 0, 0, self.transformer.factory.newNodeList(args.items), 0);
    }

    fn createDottedName(self: *JSXTransformer, text: []const u8) ast.NodeIndex {
        var parts = std.mem.splitScalar(u8, text, '.');
        var expression = self.transformer.factory.newIdentifier(parts.next() orelse text);
        while (parts.next()) |part| {
            expression = self.transformer.factory.newPropertyAccessExpression(expression, 0, self.transformer.factory.newIdentifier(part), 0);
        }
        return expression;
    }

    fn transformText(self: *JSXTransformer, v: *visitor_mod.NodeVisitor, text: []const u8) ast.NodeIndex {
        const decoded = decodeEntities(self.allocator, text);
        const normalized = normalizeJsxText(self.allocator, decoded);
        if (normalized.len == 0) return 0;
        if (containsLoneSurrogateEntity(text)) return self.newRawEscapedString(v, normalized);
        return self.transformer.factory.newStringLiteral(normalized, false);
    }

    fn newDecodedString(self: *JSXTransformer, v: *visitor_mod.NodeVisitor, text: []const u8, single_quote: bool) ast.NodeIndex {
        const decoded = decodeEntities(self.allocator, text);
        if (containsLoneSurrogateEntity(text)) return self.newRawEscapedString(v, decoded);
        return self.transformer.factory.newStringLiteral(decoded, single_quote);
    }

    fn newRawEscapedString(self: *JSXTransformer, v: *visitor_mod.NodeVisitor, text: []const u8) ast.NodeIndex {
        _ = self;
        return v.tree.pushNode(.{ .StringLiteral = .{
            .Text = text,
            .TokenFlags = 1 << 30,
            .Flags = 0,
        } }) catch unreachable;
    }
};

fn isIntrinsicTag(text: []const u8) bool {
    if (text.len == 0) return false;
    return std.ascii.isLower(text[0]) or std.mem.indexOfScalar(u8, text, '-') != null;
}

fn findPragmaValue(text: []const u8, marker: []const u8) ?[]const u8 {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        var trimmed = std.mem.trim(u8, line, " \t\r");
        if (std.mem.startsWith(u8, trimmed, "*")) trimmed = std.mem.trim(u8, trimmed[1..], " \t");
        if (!std.mem.startsWith(u8, trimmed, marker)) continue;
        var value = trimmed[marker.len..];
        const end = std.mem.indexOfAny(u8, value, " \t\r\n*") orelse value.len;
        value = value[0..end];
        if (value.len > 0) return value;
    }
    return null;
}

fn normalizeJsxText(allocator: std.mem.Allocator, text: []const u8) []const u8 {
    var result = std.ArrayListUnmanaged(u8).empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    var line_index: usize = 0;
    while (lines.next()) |raw_line| : (line_index += 1) {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0) continue;
        if (result.items.len > 0) result.append(allocator, ' ') catch unreachable;
        result.appendSlice(allocator, line) catch unreachable;
    }
    return result.toOwnedSlice(allocator) catch "";
}

fn decodeEntities(allocator: std.mem.Allocator, text: []const u8) []const u8 {
    if (std.mem.indexOfScalar(u8, text, '&') == null) return text;
    var result = std.ArrayListUnmanaged(u8).empty;
    var pos: usize = 0;
    while (pos < text.len) {
        const amp_rel = std.mem.indexOfScalar(u8, text[pos..], '&') orelse {
            result.appendSlice(allocator, text[pos..]) catch unreachable;
            break;
        };
        const amp = pos + amp_rel;
        result.appendSlice(allocator, text[pos..amp]) catch unreachable;
        const semi_rel = std.mem.indexOfScalar(u8, text[amp + 1 ..], ';') orelse {
            result.appendSlice(allocator, text[amp..]) catch unreachable;
            break;
        };
        const semi = amp + 1 + semi_rel;
        if (std.mem.indexOfScalar(u8, text[amp + 1 .. semi], '&')) |next_amp| {
            result.appendSlice(allocator, text[amp .. amp + 1 + next_amp]) catch unreachable;
            pos = amp + 1 + next_amp;
            continue;
        }
        const entity = text[amp + 1 .. semi];
        if (decodeEntity(entity)) |codepoint| {
            var buffer: [4]u8 = undefined;
            const length = std.unicode.utf8Encode(codepoint, &buffer) catch {
                if (codepoint >= 0xd800 and codepoint <= 0xdfff) {
                    var escape_buffer: [6]u8 = undefined;
                    const escape = std.fmt.bufPrint(&escape_buffer, "\\u{X:0>4}", .{codepoint}) catch unreachable;
                    result.appendSlice(allocator, escape) catch unreachable;
                } else {
                    result.appendSlice(allocator, text[amp .. semi + 1]) catch unreachable;
                }
                pos = semi + 1;
                continue;
            };
            result.appendSlice(allocator, buffer[0..length]) catch unreachable;
        } else {
            result.appendSlice(allocator, text[amp .. semi + 1]) catch unreachable;
        }
        pos = semi + 1;
    }
    return result.toOwnedSlice(allocator) catch text;
}

fn decodeEntity(entity: []const u8) ?u21 {
    if (entity.len == 0) return null;
    if (entity[0] == '#') {
        var digits = entity[1..];
        var base: u8 = 10;
        if (digits.len > 0 and digits[0] == 'x') {
            base = 16;
            digits = digits[1..];
        }
        if (digits.len == 0) return null;
        const value = std.fmt.parseInt(u21, digits, base) catch return null;
        if (value > 0x10ffff) return null;
        return value;
    }
    if (std.mem.eql(u8, entity, "amp")) return '&';
    if (std.mem.eql(u8, entity, "lt")) return '<';
    if (std.mem.eql(u8, entity, "gt")) return '>';
    if (std.mem.eql(u8, entity, "quot")) return '"';
    if (std.mem.eql(u8, entity, "apos")) return '\'';
    if (std.mem.eql(u8, entity, "nbsp")) return 0x00a0;
    return null;
}

fn containsLoneSurrogateEntity(text: []const u8) bool {
    var pos: usize = 0;
    while (std.mem.indexOf(u8, text[pos..], "&#")) |relative| {
        const start = pos + relative + 2;
        const semi_relative = std.mem.indexOfScalar(u8, text[start..], ';') orelse return false;
        const entity = text[start .. start + semi_relative];
        var digits = entity;
        var base: u8 = 10;
        if (digits.len > 0 and digits[0] == 'x') {
            base = 16;
            digits = digits[1..];
        }
        if (std.fmt.parseInt(u21, digits, base)) |value| {
            if (value >= 0xd800 and value <= 0xdfff) return true;
        } else |_| {}
        pos = start + semi_relative + 1;
        if (pos >= text.len) break;
    }
    return false;
}
