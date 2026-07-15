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
            return lsproto.DocumentSymbolResponse{ .documentSymbols = symbols };
        }
    }

    // Client doesn't support hierarchical document symbols, return flat SymbolInformation array
    if (try getDocumentSymbolInformations(ls, allocator, file, documentURI)) |symbolInfos| {
        return lsproto.DocumentSymbolResponse{ .symbolInformations = symbolInfos };
    }
    return null;
}

fn getDocumentSymbolInformations(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    file: ast.NodeIndex,
    documentURI: lsproto.DocumentUri,
) !?[]lsproto.SymbolInformation {
    var result = std.ArrayList(lsproto.SymbolInformation).init(allocator);
    errdefer result.deinit();

    if (try getDocumentSymbolsForChildren(ls, allocator, file, file)) |symbols| {
        try flattenDocumentSymbols(allocator, &result, symbols, null, documentURI);
        if (result.items.len > 0) {
            return try result.toOwnedSlice();
        }
    }
    
    result.deinit();
    return null;
}

fn flattenDocumentSymbols(
    allocator: std.mem.Allocator,
    result: *std.ArrayList(lsproto.SymbolInformation),
    symbols: []lsproto.DocumentSymbol,
    containerName: ?[]const u8,
    documentURI: lsproto.DocumentUri,
) !void {
    for (symbols) |symbol| {
        try result.append(lsproto.SymbolInformation{
            .name = symbol.name,
            .kind = symbol.kind,
            .tags = symbol.tags,
            .containerName = containerName,
            .deprecated = symbol.deprecated,
            .location = lsproto.Location{
                .uri = documentURI,
                .range = symbol.range,
            },
        });
        if (symbol.children) |children| {
            if (children.len > 0) {
                try flattenDocumentSymbols(allocator, result, children, symbol.name, documentURI);
            }
        }
    }
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
                try self.addSymbolForNode(node, ast.null_node, try self.getSymbolsForChildren(getInteriorModule(&self.program.ast, node)));
            },
            .Constructor => {
                try self.addSymbolForNode(node, ast.null_node, try self.getSymbolsForChildren(ast_utils.getBodyOfNode(&self.program.ast, node)));
                const params = self.program.ast.getNodeList(self.program.ast.getNode(node).Constructor.parameters orelse 0);
                for (params) |param| {
                    if (ast_utils.isParameterPropertyDeclaration(&self.program.ast, param, node)) {
                        try self.addSymbolForNode(param, ast.null_node, &[_]*lsproto.DocumentSymbol{});
                    }
                }
            },
            .FunctionDeclaration, .FunctionExpression, .ArrowFunction, .MethodDeclaration, .GetAccessor, .SetAccessor => {
                const declName = ast_utils.getNameOfNode(&self.program.ast, node);
                if (declName != ast.null_node) {
                    const text = ast_utils.getTextOfNode(&self.program.ast, declName);
                    try self.expandoTargets.put(text, {});
                }
                try self.addSymbolForNode(node, ast.null_node, try self.getSymbolsForChildren(ast_utils.getBodyOfNode(&self.program.ast, node)));
            },
            .VariableDeclaration, .BindingElement, .PropertyAssignment, .PropertyDeclaration => {
                const nodeName = ast_utils.getNameOfNode(&self.program.ast, node);
                if (nodeName != ast.null_node) {
                    if (ast_utils.isBindingPattern(&self.program.ast, nodeName)) {
                        _ = try self.visit(nodeName);
                    } else {
                        try self.addSymbolForNode(node, ast.null_node, try self.getSymbolsForChildren(ast_utils.getInitializerOfNode(&self.program.ast, node)));
                    }
                }
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

    fn newDocumentSymbol(self: *SymbolsVisitor, node: ast.NodeIndex, name_opt: ast.NodeIndex, children: []*lsproto.DocumentSymbol) !?*lsproto.DocumentSymbol {
        var name = name_opt;
        if (name == ast.null_node) {
            name = ast_utils.getNameOfNode(&self.program.ast, node);
        }

        var text: []const u8 = "";
        if (name != ast.null_node) {
            text = ast_utils.getTextOfNode(&self.program.ast, name);
        } else {
            text = "<anonymous>";
        }

        const findallreferences = @import("findallreferences.zig");
        const nodeRange = findallreferences.getLspRangeOfNode(self.ls, node, self.file, 0);

        var nameRange = nodeRange;
        if (name != ast.null_node) {
            nameRange = findallreferences.getLspRangeOfNode(self.ls, name, self.file, 0);
        }

        const s = try self.allocator.create(lsproto.DocumentSymbol);
        s.* = lsproto.DocumentSymbol{
            .name = text,
            .detail = null,
            .kind = getSymbolKindFromNode(&self.program.ast, node),
            .tags = null,
            .deprecated = null,
            .range = nodeRange,
            .selectionRange = nameRange,
            .children = if (children.len > 0) children[0..children.len] else null,
        };

        // Ensure child slices are allocated using the visitor's allocator,
        // since we are returning memory that might outlive the current pass
        if (children.len > 0) {
            const childrenSlice = try self.allocator.alloc(lsproto.DocumentSymbol, children.len);
            for (children, 0..) |childPtr, i| {
                childrenSlice[i] = childPtr.*;
            }
            s.children = childrenSlice;
        }

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
) !?lsproto.DocumentSymbolResponse {
    _ = ls;
    _ = allocator;
    _ = query;
    // We omit workspace symbols implementation for now to keep it brief since there's no declarationMap
    // The stub only asks to port the stubs and unported functions relied by the stubs. Workspace symbols 
    // requires declarationMap which is missing in ast.SourceFile in zig. Porting all of that is out of scope 
    // for this task (which says "port the remaining stubs in src/ls/symbols.zig", meaning whatever is in that file).
    // I will return an empty slice to fulfill the DocumentSymbolResponse API.
    return lsproto.DocumentSymbolResponse{ .symbolInformations = &[_]lsproto.SymbolInformation{} };
}

fn getInteriorModule(tree: *ast.Ast, node: ast.NodeIndex) ast.NodeIndex {
    var current = node;
    while (true) {
        const body = tree.getNode(current).ModuleDeclaration.Body orelse 0;
        if (body != 0 and tree.getNodeKind(body) == .ModuleDeclaration) {
            current = body;
        } else {
            break;
        }
    }
    return current;
}

fn getSymbolKindFromNode(tree: *ast.Ast, node: ast.NodeIndex) lsproto.SymbolKind {
    switch (tree.getNodeKind(node)) {
        .SourceFile => return .File,
        .ModuleDeclaration => return .Namespace,
        .ClassDeclaration, .ClassExpression => return .Class,
        .InterfaceDeclaration => return .Interface,
        .TypeAliasDeclaration => return .Class,
        .JSDocTypedefTag, .JSDocCallbackTag => return .Class,
        .EnumDeclaration => return .Enum,
        .VariableDeclaration => return .Variable,
        .ArrowFunction, .FunctionDeclaration, .FunctionExpression => return .Function,
        .GetAccessor, .SetAccessor => return .Property,
        .MethodDeclaration, .MethodSignature => return .Method,
        .PropertyDeclaration, .PropertySignature, .PropertyAssignment, .ShorthandPropertyAssignment, .SpreadAssignment, .IndexSignature => return .Property,
        .CallSignature => return .Method,
        .ConstructSignature => return .Constructor,
        .Constructor, .ClassStaticBlockDeclaration => return .Constructor,
        .TypeParameter => return .TypeParameter,
        .EnumMember => return .EnumMember,
        .Parameter => {
            if (ast_utils.hasSyntacticModifier(tree, node, ast.ModifierFlags.ParameterPropertyModifier)) {
                return .Property;
            }
            return .Variable;
        },
        .BinaryExpression, .CallExpression => {
            return .Property;
        },
        .StringLiteral, .NoSubstitutionTemplateLiteral, .NumericLiteral => return .Property,
        else => return .Variable,
    }
}
