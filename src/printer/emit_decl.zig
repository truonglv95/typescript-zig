const std = @import("std");
const ast_mod = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const kind = @import("../ast/kind.zig");
const Printer = @import("printer.zig").Printer;

// Port of DECLARATIONS printing logic from Go to Zig

pub fn printSignature(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex);
    var typeParameters: ?ast_gen.NodeListIndex = null;
    var parameters: ast_gen.NodeListIndex = 0;
    var returnType: ?ast_gen.NodeIndex = null;
    
    switch (node) {
        .MethodDeclaration => |n| {
            typeParameters = n.TypeParameters;
            parameters = n.Parameters;
            returnType = n.Type;
        },
        .GetAccessor => |n| {
            typeParameters = n.TypeParameters;
            parameters = n.Parameters;
            returnType = n.Type;
        },
        .SetAccessor => |n| {
            typeParameters = n.TypeParameters;
            parameters = n.Parameters;
            returnType = n.Type;
        },
        .Constructor => |n| {
            typeParameters = n.TypeParameters;
            parameters = n.Parameters;
            returnType = n.Type;
        },
        else => return,
    }
    
    if (typeParameters) |tp| {
        if (tp != 0) {
            try printer.printList(@import("emit_list.zig").ListFormat.TypeParameters, tp);
        }
    }
    
    try printer.printList(@import("emit_list.zig").ListFormat.Parameters, parameters);
    
    if (returnType) |rt| {
        if (rt != 0) {
            printer.writer.writePunctuation(":");
            printer.writer.writeSpace(" ");
            try printer.printNode(rt);
        }
    }
}

pub fn printVariableDeclaration(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).VariableDeclaration;
    
    try printer.printNode(node.name);
    
    if (node.ExclamationToken) |token| {
        try printer.printNode(token);
    }
    
    if (node.Type) |type_node| {
        if (type_node != 0) {
            printer.writer.writePunctuation(":");
            printer.writer.writeSpace(" ");
            try printer.printNode(type_node);
        }
    }
    
    if (node.Initializer) |init| {
        if (init != 0) {
            printer.writer.writeSpace(" ");
            printer.writer.writePunctuation("=");
            printer.writer.writeSpace(" ");
            try printer.printNode(init);
        }
    }
}

pub fn printVariableDeclarationList(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).VariableDeclarationList;
    const flags = ast_utils.getCombinedNodeFlags(printer.tree, nodeIndex);
    
    if ((flags & ast_utils.NodeFlags.Using) != 0) {
        if ((flags & ast_utils.NodeFlags.AwaitUsing) == ast_utils.NodeFlags.AwaitUsing) {
            printer.writer.writeKeyword("await");
            printer.writer.writeSpace(" ");
            printer.writer.writeKeyword("using");
        } else {
            printer.writer.writeKeyword("using");
        }
    } else if ((flags & ast_utils.NodeFlags.Const) != 0) {
        printer.writer.writeKeyword("const");
    } else if ((flags & ast_utils.NodeFlags.Let) != 0) {
        printer.writer.writeKeyword("let");
    } else {
        printer.writer.writeKeyword("var");
    }
    
    printer.writer.writeSpace(" ");
    try printer.emitList(null, nodeIndex, node.Declarations, @import("emit_list.zig").ListFormat.VariableDeclarationList);
}

pub fn printFunctionDeclaration(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).FunctionDeclaration;
    
    if (node.modifiers) |modifiers| {
        try printer.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
    }
    
    printer.writer.writeKeyword("function");
    if (node.AsteriskToken) |token| {
        try printer.printNode(token);
    }
    printer.writer.writeSpace(" ");
    
    if (node.name) |name| {
        try printer.printNode(name);
    }
    
    if (node.TypeParameters) |type_params| {
        try printer.printList(@import("emit_list.zig").ListFormat.TypeParameters, type_params);
    }
    
    try printer.printList(@import("emit_list.zig").ListFormat.Parameters, node.Parameters);
    
    if (node.Type) |ret_type| {
        printer.writer.writePunctuation(":");
        printer.writer.writeSpace(" ");
        try printer.printNode(ret_type);
    }
    
    if (node.Body) |body| {
        printer.writer.writeSpace(" ");
        try printer.printNode(body);
    } else {
        printer.writer.writeTrailingSemicolon(";");
    }
}

pub fn printClassDeclaration(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ClassDeclaration;
    
    if (node.modifiers) |modifiers| {
        try printer.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
    }
    
    printer.writer.writeKeyword("class");
    
    if (node.name) |name| {
        printer.writer.writeSpace(" ");
        try printer.printNode(name);
    }
    
    if (node.TypeParameters) |type_params| {
        try printer.emitList(null, nodeIndex, type_params, @import("emit_list.zig").ListFormat.TypeParameters);
    }
    
    if (node.HeritageClauses) |clauses| {
        if (clauses != 0 and printer.tree.getNodeList(clauses).len > 0) {
            printer.writer.writeSpace(" ");
            try printer.emitList(null, nodeIndex, clauses, @import("emit_list.zig").ListFormat.SingleLine | @import("emit_list.zig").ListFormat.SpaceBetweenSiblings);
        }
    }
    
    printer.writer.writeSpace(" ");
    printer.writer.writePunctuation("{");
    try printer.emitList(null, nodeIndex, node.Members, @import("emit_list.zig").ListFormat.MultiLineBlockStatements);
    printer.writer.writePunctuation("}");
}

pub fn printInterfaceDeclaration(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).InterfaceDeclaration;
    
    if (node.modifiers) |modifiers| {
        try printer.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
    }
    
    printer.writer.writeKeyword("interface");
    printer.writer.writeSpace(" ");
    try printer.printNode(node.name);
    
    if (node.TypeParameters) |type_params| {
        try printer.emitList(null, nodeIndex, type_params, @import("emit_list.zig").ListFormat.TypeParameters);
    }
    
    if (node.HeritageClauses) |clauses| {
        printer.writer.writeSpace(" ");
        try printer.emitList(null, nodeIndex, clauses, @import("emit_list.zig").ListFormat.SingleLine | @import("emit_list.zig").ListFormat.SpaceBetweenSiblings);
    }
    
    printer.writer.writeSpace(" ");
    printer.writer.writePunctuation("{");
    try printer.emitList(null, nodeIndex, node.Members, @import("emit_list.zig").ListFormat.MultiLineBlockStatements);
    printer.writer.writePunctuation("}");
}

pub fn printTypeAliasDeclaration(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).TypeAliasDeclaration;
    
    if (node.modifiers) |modifiers| {
        try printer.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
    }
    
    printer.writer.writeKeyword("type");
    printer.writer.writeSpace(" ");
    try printer.printNode(node.name);
    
    if (node.TypeParameters) |type_params| {
        try printer.emitList(null, nodeIndex, type_params, @import("emit_list.zig").ListFormat.TypeParameters);
    }
    
    printer.writer.writeSpace(" ");
    printer.writer.writePunctuation("=");
    printer.writer.writeSpace(" ");
    
    try printer.printNode(node.Type);
    
    printer.writer.writeTrailingSemicolon(";");
}

pub fn printEnumDeclaration(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).EnumDeclaration;
    
    if (node.modifiers) |modifiers| {
        try printer.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
    }
    
    printer.writer.writeKeyword("enum");
    printer.writer.writeSpace(" ");
    try printer.printNode(node.name);
    
    printer.writer.writeSpace(" ");
    printer.writer.writePunctuation("{");
    
    try printer.emitList(Printer.printNode, nodeIndex, node.Members, @import("emit_list.zig").ListFormat.EnumMembers);
    
    printer.writer.writePunctuation("}");
}

// emitEnumMember
pub fn printEnumMember(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).EnumMember;
    const state = try printer.enterNode(nodeIndex);
    
    try printer.printNode(node.name);
    
    if (node.Initializer) |init| {
        if (init != 0) {
            printer.writer.writeSpace(" ");
            _ = try printer.emitToken(.EqualsToken, 0, .Operator, nodeIndex);
            printer.writer.writeSpace(" ");
            try printer.printNode(init);
        }
    }
    try printer.exitNode(nodeIndex, state);
}

pub fn printModuleDeclaration(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).ModuleDeclaration;
    
    if (node.modifiers) |modifiers| {
        try printer.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
    }
    
    if ((node.Flags & @import("../ast/ast_utils.zig").NodeFlags.NestedNamespace) == 0) { // NestedNamespace
        if (node.Keyword != 0) {
            const kw: @import("../ast/kind.zig").Kind = @enumFromInt(node.Keyword);
            if (kw != .GlobalKeyword) {
                if (kw == .NamespaceKeyword) {
                    printer.writer.writeKeyword("namespace");
                } else {
                    printer.writer.writeKeyword("module");
                }
                printer.writer.writeSpace(" ");
            }
        } else {
            printer.writer.writeKeyword("module");
            printer.writer.writeSpace(" ");
        }
    }
    
    try printer.printNode(node.name);
    
    if (node.Body) |body| {
        if (body != 0 and printer.tree.getNode(body) == .ModuleDeclaration) {
            printer.writer.writePunctuation(".");
            try printer.printNode(body);
        } else {
            printer.writer.writeSpace(" ");
            try printer.printNode(body);
        }
    } else {
        printer.writer.writeTrailingSemicolon(";");
    }
}

pub fn printParameter(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).Parameter;
    
    if (node.modifiers) |modifiers| {
        try printer.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
    }
    
    if (node.DotDotDotToken) |token| {
        try printer.printNode(token);
    }
    
    try printer.printNode(node.name);
    
    if (node.QuestionToken) |token| {
        try printer.printNode(token);
    }
    
    if (node.Type) |type_node| {
        printer.writer.writePunctuation(":");
        printer.writer.writeSpace(" ");
        try printer.printNode(type_node);
    }
    
    if (node.Initializer) |init| {
        printer.writer.writeSpace(" ");
        printer.writer.writePunctuation("=");
        printer.writer.writeSpace(" ");
        try printer.printNode(init);
    }
}

pub fn printPropertyDeclaration(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).PropertyDeclaration;
    
    if (node.modifiers) |modifiers| {
        try printer.emitList(null, nodeIndex, modifiers, @import("emit_list.zig").ListFormat.Modifiers);
    }
    
    try printer.printNode(node.name);
    
    if (node.PostfixToken) |token| {
        try printer.printNode(token);
    }
    
    if (node.Type) |type_node| {
        printer.writer.writePunctuation(":");
        printer.writer.writeSpace(" ");
        try printer.printNode(type_node);
    }
    
    if (node.Initializer) |init| {
        printer.writer.writeSpace(" ");
        printer.writer.writePunctuation("=");
        printer.writer.writeSpace(" ");
        try printer.printNode(init);
    }
    
    printer.writer.writeTrailingSemicolon(";");
}

pub fn printHeritageClause(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).HeritageClause;
    if (node.Token == @intFromEnum(kind.Kind.ExtendsKeyword)) {
        printer.writer.writeKeyword("extends");
    } else if (node.Token == @intFromEnum(kind.Kind.ImplementsKeyword)) {
        printer.writer.writeKeyword("implements");
    }
    printer.writer.writeSpace(" ");
    const format = @import("emit_list.zig").ListFormat.CommaDelimited | @import("emit_list.zig").ListFormat.SpaceBetweenSiblings | @import("emit_list.zig").ListFormat.SingleLine;
    try printer.emitList(null, nodeIndex, node.Types, format);
}

pub fn printDecorator(printer: *Printer, nodeIndex: ast_mod.NodeIndex) anyerror!void {
    const node = printer.tree.getNode(nodeIndex).Decorator;
    printer.writer.writePunctuation("@");
    try printer.printNode(node.Expression);
}
