const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");

pub const CodeLensKind = enum {
    References,
    Implementations,
};

pub const CodeLens = struct {
    line: u32,
    character: u32,
    kind: CodeLensKind,
    node: ast_gen.NodeIndex,
};

fn computeLineAndCharacter(source_text: []const u8, pos: u32) struct { line: u32, character: u32 } {
    var line: u32 = 0;
    var line_start: u32 = 0;
    const limit = if (pos < source_text.len) pos else source_text.len;
    for (source_text[0..limit], 0..) |c, i| {
        if (c == '\n') {
            line += 1;
            line_start = @intCast(i + 1);
        }
    }
    const character = if (pos >= line_start) pos - line_start else 0;
    return .{ .line = line, .character = character };
}

const CodeLensVisitor = struct {
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    references_enabled: bool,
    implementations_enabled: bool,
    result: *std.ArrayListUnmanaged(CodeLens),
    last_symbol: ast_gen.SymbolIndex = 0,

    pub fn visitNode(self: *@This(), node: ast_gen.NodeIndex) anyerror!void {
        if (node == 0) return;

        const current_symbol = self.tree.getNodeSymbol(node) orelse 0;
        const previous_symbol = self.last_symbol;

        if (current_symbol != 0 and current_symbol != self.last_symbol) {
            self.last_symbol = current_symbol;

            const pos = self.tree.getNodePos(node);
            const loc = computeLineAndCharacter(self.tree.sourceText, pos);

            if (self.references_enabled and isValidReferenceLensNode(self.tree, node)) {
                try self.result.append(self.allocator, .{
                    .line = loc.line,
                    .character = loc.character,
                    .kind = .References,
                    .node = node,
                });
            }

            if (self.implementations_enabled and isValidImplementationsCodeLensNode(self.tree, node)) {
                try self.result.append(self.allocator, .{
                    .line = loc.line,
                    .character = loc.character,
                    .kind = .Implementations,
                    .node = node,
                });
            }
        }

        try ast.forEachChild(self.tree, node, self);
        self.last_symbol = previous_symbol;
    }

    pub fn visitList(self: *@This(), list: u32) anyerror!void {
        for (self.tree.getNodeList(list)) |child| {
            try self.visitNode(child);
        }
    }
};

pub fn collectCodeLenses(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    source_file: ast_gen.NodeIndex,
    references_enabled: bool,
    implementations_enabled: bool,
) ![]CodeLens {
    var result = std.ArrayListUnmanaged(CodeLens).empty;
    errdefer result.deinit(allocator);

    if (source_file == 0) return result.toOwnedSlice(allocator);
    const sf = tree.getNode(source_file);
    if (sf != .SourceFile) return result.toOwnedSlice(allocator);

    var visitor = CodeLensVisitor{
        .allocator = allocator,
        .tree = tree,
        .references_enabled = references_enabled,
        .implementations_enabled = implementations_enabled,
        .result = &result,
    };
    try visitor.visitNode(source_file);

    return result.toOwnedSlice(allocator);
}

fn isValidReferenceLensNode(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const kind = tree.getNodeKind(node);
    switch (kind) {
        .ClassDeclaration,
        .InterfaceDeclaration,
        .TypeAliasDeclaration,
        .EnumDeclaration,
        .ModuleDeclaration,
        .FunctionDeclaration,
        .MethodDeclaration,
        .PropertyDeclaration,
        => return true,
        else => return false,
    }
}

fn isValidImplementationsCodeLensNode(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const kind = tree.getNodeKind(node);
    switch (kind) {
        .ClassDeclaration,
        .InterfaceDeclaration,
        .MethodDeclaration,
        .PropertyDeclaration,
        => return true,
        else => return false,
    }
}
