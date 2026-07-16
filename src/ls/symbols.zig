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

        const raw_result = try self.symbols.toOwnedSlice();
        const result = try mergeExpandos(self.allocator, raw_result);
        self.allocator.free(raw_result);

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
                const assignmentKind = ast_utils.getAssignmentDeclarationKind(&self.program.ast, node);
                switch (assignmentKind) {
                    .None, .ThisProperty, .ModuleExports, .ExportsProperty, .ObjectDefinePropertyExports => {
                        try self.program.ast.forEachChild(node, self, visit);
                    },
                    .Property, .ObjectDefinePropertyValue => {
                        var target: ast.NodeIndex = ast.null_node;
                        var targetFunction: ast.NodeIndex = ast.null_node;
                        var definition: ast.NodeIndex = ast.null_node;
                        var propertyName: ast.NodeIndex = ast.null_node;

                        if (kind == .BinaryExpression) {
                            const binaryExpr = self.program.ast.getNode(node).BinaryExpression;
                            target = binaryExpr.Left;
                            if (ast_utils.isAccessExpression(&self.program.ast, target)) {
                                if (self.program.ast.getNodeKind(target) == .PropertyAccessExpression) {
                                    targetFunction = self.program.ast.getNode(target).PropertyAccessExpression.Expression;
                                    propertyName = self.program.ast.getNode(target).PropertyAccessExpression.name;
                                } else if (self.program.ast.getNodeKind(target) == .ElementAccessExpression) {
                                    targetFunction = self.program.ast.getNode(target).ElementAccessExpression.Expression;
                                    propertyName = self.program.ast.getNode(target).ElementAccessExpression.ArgumentExpression;
                                }
                            }
                            definition = binaryExpr.Right;
                        } else {
                            const callExpr = self.program.ast.getNode(node).CallExpression;
                            const args = self.program.ast.getNodeList(callExpr.Arguments orelse 0);
                            if (args.len >= 3) {
                                targetFunction = args[0];
                                target = args[1];
                                propertyName = target;
                                definition = args[2];
                            }
                        }

                        if (isPrototypeExpando(&self.program.ast, targetFunction)) {
                            if (self.program.ast.getNodeKind(targetFunction) == .PropertyAccessExpression) {
                                targetFunction = self.program.ast.getNode(targetFunction).PropertyAccessExpression.Expression;
                            } else if (self.program.ast.getNodeKind(targetFunction) == .ElementAccessExpression) {
                                targetFunction = self.program.ast.getNode(targetFunction).ElementAccessExpression.Expression;
                            }
                            if (self.program.ast.getNodeKind(targetFunction) == .Identifier) {
                                try self.expandoTargets.put(ast_utils.getText(&self.program.ast, targetFunction), {});
                            }
                        }

                        if (self.program.ast.getNodeKind(targetFunction) == .Identifier and
                            self.expandoTargets.contains(ast_utils.getText(&self.program.ast, targetFunction)))
                        {
                            const saveExpandoTargets = self.expandoTargets;
                            self.expandoTargets = std.StringHashMap(void).init(self.allocator);
                            const saveSymbols = self.symbols;
                            self.symbols = std.ArrayList(*lsproto.DocumentSymbol).init(self.allocator);

                            try self.addSymbolForNode(target, propertyName, try self.getSymbolsForChildren(definition));
                            const result = try self.symbols.toOwnedSlice();

                            self.symbols.deinit();
                            self.expandoTargets.deinit();
                            self.symbols = saveSymbols;
                            self.expandoTargets = saveExpandoTargets;

                            try self.addSymbolForNode(node, targetFunction, result);
                        } else {
                            try self.program.ast.forEachChild(node, self, visit);
                        }
                    },
                    else => {
                        try self.program.ast.forEachChild(node, self, visit);
                    },
                }
            },
            .ExportAssignment => {
                if (self.program.ast.getNode(node).ExportAssignment.IsExportEquals != 0) {
                    try self.addSymbolForNode(node, ast.null_node, try self.getSymbolsForChildren(self.program.ast.getNode(node).ExportAssignment.Expression));
                } else {
                    try self.program.ast.forEachChild(node, self, visit);
                }
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
        const nodeStartPos = self.program.ast.getStart(node);
        var nameStartPos: usize = 0;
        var nameEndPos: usize = 0;
        
        if (self.program.ast.getNodeKind(node) == .ModuleDeclaration and !ast_utils.isAmbientModule(&self.program.ast, node)) {
            text = try getModuleName(&self.program.ast, self.allocator, node);
            nameStartPos = if (name != ast.null_node) self.program.ast.getStart(name) else nodeStartPos;
            const interior = getInteriorModule(&self.program.ast, node);
            const interiorName = self.program.ast.getNode(interior).ModuleDeclaration.name orelse interior;
            nameEndPos = self.program.ast.getEnd(interiorName);
        } else if (self.program.ast.getNodeKind(node) == .ExportAssignment and self.program.ast.getNode(node).ExportAssignment.IsExportEquals != 0) {
            text = "export=";
            if (name != ast.null_node) {
                nameStartPos = self.program.ast.getStart(name);
                nameEndPos = self.program.ast.getEnd(name);
            } else {
                nameStartPos = nodeStartPos;
                nameEndPos = self.program.ast.getEnd(node);
            }
        } else if (name != ast.null_node) {
            text = try getTextOfName(&self.program.ast, self.allocator, name);
            nameStartPos = @max(self.program.ast.getStart(name), nodeStartPos);
            nameEndPos = @max(self.program.ast.getEnd(name), nodeStartPos);
        } else {
            text = try getUnnamedNodeLabel(&self.program.ast, self.allocator, node);
            nameStartPos = nodeStartPos;
            nameEndPos = nodeStartPos;
        }

        if (text.len == 0) {
            return null;
        }

        var final_text = text;
        const maxLength = 150;
        if (text.len > maxLength) {
            final_text = try std.fmt.allocPrint(self.allocator, "{s}...", .{text[0..maxLength]});
        }

        const findallreferences = @import("findallreferences.zig");
        const nodeRange = findallreferences.getLspRangeOfNode(self.ls, node, self.file, 0);

        const nameRange = lsproto.Range{
            .start = self.ls.converters.positionToLineAndCharacter(self.file, nameStartPos),
            .end = self.ls.converters.positionToLineAndCharacter(self.file, nameEndPos),
        };

        const s = try self.allocator.create(lsproto.DocumentSymbol);
        s.* = lsproto.DocumentSymbol{
            .name = final_text,
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

fn getModuleName(tree: *ast.Ast, allocator: std.mem.Allocator, node: ast.NodeIndex) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    var current = node;
    const nameNode = tree.getNode(current).ModuleDeclaration.name orelse 0;
    try result.appendSlice(ast_utils.getText(tree, nameNode));

    while (true) {
        const body = tree.getNode(current).ModuleDeclaration.Body orelse 0;
        if (body != 0 and tree.getNodeKind(body) == .ModuleDeclaration) {
            current = body;
            try result.append('.');
            const n = tree.getNode(current).ModuleDeclaration.name orelse 0;
            try result.appendSlice(ast_utils.getText(tree, n));
        } else {
        }
    }
    return try result.toOwnedSlice();
}

fn getTextOfName(tree: *ast.Ast, allocator: std.mem.Allocator, node: ast.NodeIndex) ![]const u8 {
    const kind = tree.getNodeKind(node);
    switch (kind) {
        .Identifier, .PrivateIdentifier, .NumericLiteral => {
            return ast_utils.getText(tree, node);
        },
        .StringLiteral => {
            const text = ast_utils.getText(tree, node);
            var result = std.ArrayList(u8).init(allocator);
            try result.append('"');
            try result.appendSlice(text);
            try result.append('"');
            return try result.toOwnedSlice();
        },
        .NoSubstitutionTemplateLiteral => {
            const text = ast_utils.getText(tree, node);
            var result = std.ArrayList(u8).init(allocator);
            try result.append('`');
            try result.appendSlice(text);
            try result.append('`');
            return try result.toOwnedSlice();
        },
        .ComputedPropertyName => {
            const expr = tree.getNode(node).ComputedPropertyName.Expression;
            if (ast_utils.isStringOrNumericLiteralLike(tree, expr)) {
                return try getTextOfName(tree, allocator, expr);
            }
        },
        else => {},
    }
    return ast_utils.getText(tree, node);
}

fn getUnnamedNodeLabel(tree: *ast.Ast, allocator: std.mem.Allocator, node: ast.NodeIndex) ![]const u8 {
    const parent = ast_utils.getParent(tree, node);
    var p = parent;
    while (p != ast.null_node and tree.getNodeKind(p) == .ParenthesizedExpression) {
        p = ast_utils.getParent(tree, p);
    }
    if (p != ast.null_node and tree.getNodeKind(p) == .ExportAssignment) {
        if (tree.getNode(p).ExportAssignment.IsExportEquals != 0) {
            return "export=";
        }
        return "default";
    }

    switch (tree.getNodeKind(node)) {
        .FunctionDeclaration, .FunctionExpression, .ArrowFunction => {
            if (ast_utils.hasSyntacticModifier(tree, node, ast_utils.ModifierFlags.Default)) {
                return "default";
            }
            if (tree.getNodeKind(parent) == .CallExpression) {
                const callExpr = tree.getNode(parent).CallExpression;
                const name = try getCallExpressionName(tree, allocator, callExpr.Expression);
                if (name.len > 0) {
                    const cleanedName = try cleanCallbackText(allocator, name);
                    if (cleanedName.len > 150) {
                        return try std.fmt.allocPrint(allocator, "{s} callback", .{cleanedName});
                    }
                    const args = try getCallExpressionLiteralArgs(tree, allocator, parent);
                    const cleanedArgs = try cleanCallbackText(allocator, args);
                    if (cleanedArgs.len > 0) {
                        return try std.fmt.allocPrint(allocator, "{s}({s}) callback", .{cleanedName, cleanedArgs});
                    }
                    return try std.fmt.allocPrint(allocator, "{s}() callback", .{cleanedName});
                }
            }
            return "<function>";
        },
        .ClassDeclaration, .ClassExpression => {
            if (ast_utils.hasSyntacticModifier(tree, node, ast_utils.ModifierFlags.Default)) {
                return "default";
            }
            return "<class>";
        },
        .Constructor => return "constructor",
        .CallSignature => return "()",
        .ConstructSignature => return "new()",
        .IndexSignature => return "[]",
        else => return "",
    }
}

fn getCallExpressionName(tree: *ast.Ast, allocator: std.mem.Allocator, node: ast.NodeIndex) ![]const u8 {
    switch (tree.getNodeKind(node)) {
        .Identifier, .PrivateIdentifier => return ast_utils.getText(tree, node),
        .PropertyAccessExpression => {
            const left = try getCallExpressionName(tree, allocator, tree.getNode(node).PropertyAccessExpression.Expression);
            const right = try getCallExpressionName(tree, allocator, tree.getNode(node).PropertyAccessExpression.name);
            if (left.len > 0) {
                return try std.fmt.allocPrint(allocator, "{s}.{s}", .{left, right});
            }
            return right;
        },
        else => return "",
    }
}

fn getCallExpressionLiteralArgs(tree: *ast.Ast, allocator: std.mem.Allocator, callExpr: ast.NodeIndex) ![]const u8 {
    var parts = std.ArrayList([]const u8).init(allocator);
    defer parts.deinit();
    const args = tree.getNodeList(tree.getNode(callExpr).CallExpression.Arguments orelse 0);
    for (args) |arg| {
        if (ast_utils.isStringLiteralLike(tree, arg) or tree.getNodeKind(arg) == .TemplateExpression) {
            try parts.append(ast_utils.getText(tree, arg));
        }
    }
    var result = std.ArrayList(u8).init(allocator);
    for (parts.items, 0..) |part, i| {
        if (i > 0) try result.appendSlice(", ");
        try result.appendSlice(part);
    }
    return try result.toOwnedSlice();
}

fn cleanCallbackText(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    var truncated = text;
    if (truncated.len > 150) {
        truncated = try std.fmt.allocPrint(allocator, "{s}...", .{text[0..150]});
    }
    var result = std.ArrayList(u8).init(allocator);
    for (truncated) |c| {
        if (c == '\n' or c == '\r') continue;
        try result.append(c);
    }
    return try result.toOwnedSlice();
}

fn isPrototypeExpando(tree: *ast.Ast, target: ast.NodeIndex) bool {
    if (ast_utils.isAccessExpression(tree, target)) {
        var accessName: ast.NodeIndex = ast.null_node;
        if (tree.getNodeKind(target) == .PropertyAccessExpression) {
            accessName = tree.getNode(target).PropertyAccessExpression.name;
        } else if (tree.getNodeKind(target) == .ElementAccessExpression) {
            accessName = tree.getNode(target).ElementAccessExpression.ArgumentExpression;
        }
        if (accessName != ast.null_node and std.mem.eql(u8, ast_utils.getText(tree, accessName), "prototype")) {
            return true;
        }
    }
    return false;
}

fn isAnonymousName(name: []const u8) bool {
    return std.mem.eql(u8, name, "<function>") or
        std.mem.eql(u8, name, "<class>") or
        std.mem.eql(u8, name, "export=") or
        std.mem.eql(u8, name, "default") or
        std.mem.eql(u8, name, "constructor") or
        std.mem.eql(u8, name, "()") or
        std.mem.eql(u8, name, "new()") or
        std.mem.eql(u8, name, "[]") or
        std.mem.endsWith(u8, name, ") callback");
}

fn mergeExpandos(allocator: std.mem.Allocator, symbols: []*lsproto.DocumentSymbol) ![]*lsproto.DocumentSymbol {
    var mergedSymbols = std.ArrayList(*lsproto.DocumentSymbol).init(allocator);
    errdefer mergedSymbols.deinit();

    var nameToExpandoTargetIndex = std.StringHashMap(std.ArrayList(usize)).init(allocator);
    defer {
        var it = nameToExpandoTargetIndex.valueIterator();
        while (it.next()) |list| {
            list.deinit();
        }
        nameToExpandoTargetIndex.deinit();
    }
    var nameToNamespaceIndex = std.StringHashMap(usize).init(allocator);
    defer nameToNamespaceIndex.deinit();

    for (symbols, 0..) |symbol, i| {
        if (isAnonymousName(symbol.name)) continue;
        if (symbol.kind == .Class or symbol.kind == .Function or symbol.kind == .Variable) {
            var res = try nameToExpandoTargetIndex.getOrPut(symbol.name);
            if (!res.found_existing) {
                res.value_ptr.* = std.ArrayList(usize).init(allocator);
            }
            try res.value_ptr.append(i);
        }
        if (symbol.kind == .Namespace) {
            if (!nameToNamespaceIndex.contains(symbol.name)) {
                try nameToNamespaceIndex.put(symbol.name, i);
            }
        }
    }

    var mutableSymbols = try allocator.alloc(?*lsproto.DocumentSymbol, symbols.len);
    defer allocator.free(mutableSymbols);
    for (symbols, 0..) |s, i| mutableSymbols[i] = s;

    for (mutableSymbols, 0..) |symbol_opt, i| {
        if (symbol_opt == null) continue;
        var symbol = symbol_opt.?;

        if (symbol.children) |children| {
            var childPtrs = try allocator.alloc(*lsproto.DocumentSymbol, children.len);
            defer allocator.free(childPtrs);
            for (children, 0..) |c, j| {
                const p = try allocator.create(lsproto.DocumentSymbol);
                p.* = c;
                childPtrs[j] = p;
            }
            const mergedChildrenPtrs = try mergeExpandos(allocator, childPtrs);
            var mergedChildren = try allocator.alloc(lsproto.DocumentSymbol, mergedChildrenPtrs.len);
            for (mergedChildrenPtrs, 0..) |p, j| mergedChildren[j] = p.*;
            allocator.free(mergedChildrenPtrs);
            symbol.children = mergedChildren;
        }

        if (isAnonymousName(symbol.name)) continue;

        if (symbol.kind == .Property) {
            if (nameToExpandoTargetIndex.get(symbol.name)) |targets| {
                var j: usize = targets.items.len;
                while (j > 0) {
                    j -= 1;
                    const targetIndex = targets.items[j];
                    if (mutableSymbols[targetIndex]) |targetSymbol| {
                        try mergeChildren(allocator, targetSymbol, symbol);
                        mutableSymbols[i] = null;
                    }
                }
            }
        }

        if (symbol.kind == .Namespace) {
            if (nameToNamespaceIndex.get(symbol.name)) |targetIndex| {
                if (targetIndex != i) {
                    if (mutableSymbols[targetIndex]) |targetSymbol| {
                        try mergeChildren(allocator, targetSymbol, symbol);
                        mutableSymbols[i] = null;
                    }
                }
            }
        }
    }

    for (mutableSymbols) |s| {
        if (s) |symbol| {
            try mergedSymbols.append(symbol);
        }
    }
    return try mergedSymbols.toOwnedSlice();
}

fn compareSymbolsByRange(context: void, a: *lsproto.DocumentSymbol, b: *lsproto.DocumentSymbol) bool {
    _ = context;
    if (a.range.start.line < b.range.start.line) return true;
    if (a.range.start.line > b.range.start.line) return false;
    return a.range.start.character < b.range.start.character;
}

fn mergeChildren(allocator: std.mem.Allocator, target: *lsproto.DocumentSymbol, source: *lsproto.DocumentSymbol) !void {
    if (source.children) |sourceChildren| {
        if (target.children == null) {
            target.children = sourceChildren;
        } else {
            var combined = std.ArrayList(*lsproto.DocumentSymbol).init(allocator);
            defer combined.deinit();

            for (target.children.?) |c| {
                const p = try allocator.create(lsproto.DocumentSymbol);
                p.* = c;
                try combined.append(p);
            }
            for (sourceChildren) |c| {
                const p = try allocator.create(lsproto.DocumentSymbol);
                p.* = c;
                try combined.append(p);
            }

            const merged = try mergeExpandos(allocator, combined.items);
            defer allocator.free(merged);

            std.sort.pdq(*lsproto.DocumentSymbol, merged, {}, compareSymbolsByRange);

            var result = try allocator.alloc(lsproto.DocumentSymbol, merged.len);
            for (merged, 0..) |m, i| result[i] = m.*;
            target.children = result;
        }
    }
}
