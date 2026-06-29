const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const kind = @import("../ast/kind.zig");
const core = @import("../core/core.zig");
const transformer_mod = @import("transformer.zig");
const visitor_mod = @import("../ast/visitor.zig");
const ast_utils = @import("../ast/ast_utils.zig");

fn isSpecialEscape(ch: u8) bool {
    return switch (ch) {
        'n', 't', 'r', 'b', 'f', 'v', '0', 'x', 'u', '\\', '\'', '"' => true,
        else => false,
    };
}

fn escapeNonAscii(allocator: std.mem.Allocator, text: []const u8) []const u8 {
    var list = std.ArrayListUnmanaged(u8).empty;
    defer list.deinit(allocator);

    var i: usize = 0;
    while (i < text.len) {
        const b = text[i];
        if (b == '\\' and i + 1 < text.len) {
            const next_ch = text[i + 1];
            if (isSpecialEscape(next_ch)) {
                list.append(allocator, '\\') catch unreachable;
                i += 1;
            } else {
                i += 1;
            }
        } else if (b < 128) {
            list.append(allocator, b) catch unreachable;
            i += 1;
        } else {
            const cp_len = std.unicode.utf8ByteSequenceLength(b) catch 1;
            if (i + cp_len <= text.len) {
                list.appendSlice(allocator, text[i .. i + cp_len]) catch unreachable;
                i += cp_len;
            } else {
                list.append(allocator, b) catch unreachable;
                i += 1;
            }
        }
    }
    return list.toOwnedSlice(allocator) catch text;
}

pub const ConstEnumInliningTransformer = struct {
    transformer: *transformer_mod.Transformer,
    compilerOptions: *core.CompilerOptions,
    constEnumValues: std.StringHashMap(ast_gen.NodeIndex),
    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, opt: *transformer_mod.TransformOptions) !*transformer_mod.Transformer {
        const tx = try allocator.create(ConstEnumInliningTransformer);
        tx.compilerOptions = opt.compilerOptions;
        tx.constEnumValues = std.StringHashMap(ast_gen.NodeIndex).init(allocator);
        tx.allocator = allocator;

        tx.transformer = try transformer_mod.Transformer.init(allocator, visit, tx, opt.context);
        return tx.transformer;
    }

    fn elide(self: *ConstEnumInliningTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.transformer.emitContext.newNotEmittedStatement(node) catch 0;
    }

    fn visit(ctx: ?*anyopaque, visitor: *visitor_mod.NodeVisitor, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const self = @as(*ConstEnumInliningTransformer, @ptrCast(@alignCast(ctx.?)));
        const tree = visitor.tree;

        if (node == 0) return 0;

        const nodeData = tree.getNode(node);
        switch (nodeData) {
            .EnumDeclaration => |n| {
                if (ast_utils.hasSyntacticModifier(tree, node, ast_utils.ModifierFlags.Const)) {
                    const nameNode = tree.getNode(n.name);
                    if (nameNode == .Identifier) {
                        const enumName = nameNode.Identifier.Text;
                        const members = tree.getNodeList(n.Members);
                        var currentVal: u32 = 0;
                        for (members) |memberNode| {
                            const member = tree.getNode(memberNode).EnumMember;
                            const memberNameNode = tree.getNode(member.name);
                            if (memberNameNode == .Identifier) {
                                const memberNameText = memberNameNode.Identifier.Text;
                                var valueNode: ast_gen.NodeIndex = 0;
                                if (member.Initializer) |init| {
                                    if (init != 0) {
                                        valueNode = init;
                                        const valNode = tree.getNode(valueNode);
                                        if (valNode == .StringLiteral) {
                                            const valText = valNode.StringLiteral.Text;
                                            // Decode legacy escapes such as `\€` to their semantic
                                            // value, but leave output escaping to the printer.
                                            const semantic_text = escapeNonAscii(self.allocator, valText);
                                            valueNode = self.transformer.factory.newStringLiteral(semantic_text, valNode.StringLiteral.TokenFlags);
                                        }
                                    }
                                }

                                if (valueNode == 0) {
                                    var buf: [32]u8 = undefined;
                                    const text = std.fmt.bufPrint(&buf, "{d}", .{currentVal}) catch unreachable;
                                    const strValue = self.allocator.dupe(u8, text) catch unreachable;
                                    valueNode = self.transformer.factory.newNumericLiteral(strValue, 0);
                                }

                                const key = std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ enumName, memberNameText }) catch unreachable;
                                self.constEnumValues.put(key, valueNode) catch {};

                                if (tree.getNode(valueNode) == .NumericLiteral) {
                                    if (std.fmt.parseInt(u32, tree.getNode(valueNode).NumericLiteral.Text, 10)) |val| {
                                        currentVal = val + 1;
                                    } else |_| {
                                        currentVal += 1;
                                    }
                                } else {
                                    currentVal += 1;
                                }
                            }
                        }
                    }
                    return self.elide(node);
                }
            },
            .PropertyAccessExpression => |n| {
                const exprNode = tree.getNode(n.Expression);
                const nameNode = tree.getNode(n.name);
                if (exprNode == .Identifier and nameNode == .Identifier) {
                    const enumName = exprNode.Identifier.Text;
                    const memberName = nameNode.Identifier.Text;
                    const key = std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ enumName, memberName }) catch unreachable;
                    if (self.constEnumValues.get(key)) |valNode| {
                        return valNode;
                    }
                }
            },
            else => {},
        }

        return visitor.visitEachChild(node);
    }
};
