const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");

pub fn provideDocumentSymbols(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    documentURI: lsproto.DocumentUri,
) !?[]lsproto.DocumentSymbol {
    const caps = lsproto.getClientCapabilities();
    const programAndFile = ls.getProgramAndFile(documentURI);
    const file = programAndFile.file;

    if (caps.textDocument.documentSymbol.hierarchicalDocumentSymbolSupport) {
        if (try getDocumentSymbolsForChildren(ls, allocator, file, file)) |symbols| {
            return symbols;
        }
    }
    
    // Stub out flat SymbolInformation if not hierarchical
    return null;
}

const SymbolsVisitor = struct {
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    program: *compiler.Program,
    file: ast.NodeIndex,
    symbols: std.ArrayList(*lsproto.DocumentSymbol),
    expandoTargets: std.StringHashMap(void),

    pub fn init(ls: *languageservice.LanguageService, allocator: std.mem.Allocator, file: ast.NodeIndex) SymbolsVisitor {
        return .{
            .ls = ls,
            .allocator = allocator,
            .program = ls.getProgram(),
            .file = file,
            .symbols = std.ArrayList(*lsproto.DocumentSymbol).init(allocator),
            .expandoTargets = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn deinit(self: *SymbolsVisitor) void {
        self.symbols.deinit();
        self.expandoTargets.deinit();
    }

    pub fn getSymbolsForChildren(self: *SymbolsVisitor, node: ast.NodeIndex) ![]*lsproto.DocumentSymbol {
        if (node == ast.null_node) return &[_]*lsproto.DocumentSymbol{};

        // We save the current state and recurse, similar to Go's closure capture logic
        const saveExpandoTargets = self.expandoTargets;
        self.expandoTargets = std.StringHashMap(void).init(self.allocator);
        const saveSymbols = self.symbols;
        self.symbols = std.ArrayList(*lsproto.DocumentSymbol).init(self.allocator);

        try self.program.ast.forEachChild(node, self, visit);

        const result = try self.symbols.toOwnedSlice();
        
        self.symbols.deinit();
        self.expandoTargets.deinit();
        
        self.symbols = saveSymbols;
        self.expandoTargets = saveExpandoTargets;

        return result;
    }

    fn addSymbolForNode(self: *SymbolsVisitor, node: ast.NodeIndex, name: ast.NodeIndex, children: []*lsproto.DocumentSymbol) !void {
        const flags = self.program.ast.getNodeFlags(node);
        if (flags & ast.NodeFlags.Reparsed == 0) {
            const symbol = try self.newDocumentSymbol(node, name, children);
            if (symbol) |s| {
                try self.symbols.append(s);
            }
        }
    }

    fn visit(self: *SymbolsVisitor, node: ast.NodeIndex) !bool {
        const kind = self.program.ast.getNodeKind(node);
        
        switch (kind) {
            .ClassDeclaration, .ClassExpression, .InterfaceDeclaration, .EnumDeclaration => {
                try self.addSymbolForNode(node, ast.null_node, try self.getSymbolsForChildren(node));
            },
            .ModuleDeclaration => {
                // stub for interior module
                try self.addSymbolForNode(node, ast.null_node, try self.getSymbolsForChildren(node));
            },
            .Constructor => {
                // stub for body
                try self.addSymbolForNode(node, ast.null_node, try self.getSymbolsForChildren(node));
            },
            .FunctionDeclaration, .FunctionExpression, .ArrowFunction, .MethodDeclaration, .GetAccessor, .SetAccessor => {
                // stub for body
                try self.addSymbolForNode(node, ast.null_node, try self.getSymbolsForChildren(node));
            },
            .VariableDeclaration, .BindingElement, .PropertyAssignment, .PropertyDeclaration => {
                // stub for initializer
                try self.addSymbolForNode(node, ast.null_node, try self.getSymbolsForChildren(node));
            },
            .SpreadAssignment => {
                try self.addSymbolForNode(node, ast.null_node, &[_]*lsproto.DocumentSymbol{});
            },
            .MethodSignature, .PropertySignature, .CallSignature, .ConstructSignature, .IndexSignature, .EnumMember, .ShorthandPropertyAssignment, .TypeAliasDeclaration, .ImportEqualsDeclaration, .ExportSpecifier => {
                try self.addSymbolForNode(node, ast.null_node, &[_]*lsproto.DocumentSymbol{});
            },
            .ImportClause => {
                try self.addSymbolForNode(node, ast.null_node, &[_]*lsproto.DocumentSymbol{});
            },
            .BinaryExpression, .CallExpression => {
                try self.program.ast.forEachChild(node, self, visit);
            },
            .ExportAssignment => {
                try self.program.ast.forEachChild(node, self, visit);
            },
            else => {
                try self.program.ast.forEachChild(node, self, visit);
            },
        }

        return false;
    }

    fn newDocumentSymbol(self: *SymbolsVisitor, node: ast.NodeIndex, name: ast.NodeIndex, children: []*lsproto.DocumentSymbol) !?*lsproto.DocumentSymbol {
        _ = name; _ = children;
        
        // Mocking the document symbol creation for now to satisfy the skeleton
        const s = try self.allocator.create(lsproto.DocumentSymbol);
        s.* = lsproto.DocumentSymbol{
            .name = "StubSymbol",
            .detail = null,
            .kind = .Variable,
            .tags = null,
            .deprecated = null,
            .range = lsproto.Range{ .start = .{ .line = 0, .character = 0 }, .end = .{ .line = 0, .character = 0 } },
            .selectionRange = lsproto.Range{ .start = .{ .line = 0, .character = 0 }, .end = .{ .line = 0, .character = 0 } },
            .children = null,
        };
        _ = node;
        return s;
    }
};

pub fn getDocumentSymbolsForChildren(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    node: ast.NodeIndex,
    file: ast.NodeIndex,
) !?[]lsproto.DocumentSymbol {
    var visitor = SymbolsVisitor.init(ls, allocator, file);
    defer visitor.deinit();

    const children = try visitor.getSymbolsForChildren(node);
    
    // We flatten out the []*lsproto.DocumentSymbol to []lsproto.DocumentSymbol 
    // for returning to the main LS response struct wrapper.
    if (children.len == 0) return null;
    
    var result = try allocator.alloc(lsproto.DocumentSymbol, children.len);
    for (children, 0..) |c, i| {
        result[i] = c.*;
    }
    return result;
}

pub fn provideWorkspaceSymbols(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    query: []const u8,
) !?[]lsproto.SymbolInformation {
    _ = ls; _ = allocator; _ = query;
    // stub
    return null;
}
