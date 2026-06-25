const std = @import("std");
const ast_mod = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const Printer = @import("printer.zig").Printer;

pub const ListFormat = struct {
    pub const None: u32 = 0;

    // Line separators
    pub const SingleLine: u32 = 0;
    pub const MultiLine: u32 = 1 << 0;
    pub const PreserveLines: u32 = 1 << 1;
    pub const LinesMask: u32 = SingleLine | MultiLine | PreserveLines;

    // Delimiters
    pub const NotDelimited: u32 = 0;
    pub const BarDelimited: u32 = 1 << 2;
    pub const AmpersandDelimited: u32 = 1 << 3;
    pub const CommaDelimited: u32 = 1 << 4;
    pub const AsteriskDelimited: u32 = 1 << 5;
    pub const DelimitersMask: u32 = BarDelimited | AmpersandDelimited | CommaDelimited | AsteriskDelimited;

    pub const AllowTrailingComma: u32 = 1 << 6;

    // Whitespace
    pub const Indented: u32 = 1 << 7;
    pub const SpaceBetweenBraces: u32 = 1 << 8;
    pub const SpaceBetweenSiblings: u32 = 1 << 9;

    // Brackets/Braces
    pub const Braces: u32 = 1 << 10;
    pub const Parenthesis: u32 = 1 << 11;
    pub const AngleBrackets: u32 = 1 << 12;
    pub const SquareBrackets: u32 = 1 << 13;
    pub const BracketsMask: u32 = Braces | Parenthesis | AngleBrackets | SquareBrackets;

    pub const OptionalIfNil: u32 = 1 << 14;
    pub const OptionalIfEmpty: u32 = 1 << 15;
    pub const Optional: u32 = OptionalIfNil | OptionalIfEmpty;

    // Other
    pub const PreferNewLine: u32 = 1 << 16;
    pub const NoTrailingNewLine: u32 = 1 << 17;
    pub const NoInterveningComments: u32 = 1 << 18;
    pub const NoSpaceIfEmpty: u32 = 1 << 19;
    pub const SingleElement: u32 = 1 << 20;
    pub const SpaceAfterList: u32 = 1 << 21;

    // Precomputed Formats
    pub const Modifiers: u32 = SingleLine | SpaceBetweenSiblings | NoInterveningComments | SpaceAfterList;
    pub const TypeArguments: u32 = CommaDelimited | SpaceBetweenSiblings | SingleLine | AngleBrackets | Optional;
    pub const TypeParameters: u32 = CommaDelimited | SpaceBetweenSiblings | SingleLine | AngleBrackets | Optional;
    pub const IndexSignatureParameters: u32 = CommaDelimited | SpaceBetweenSiblings | SingleLine;
    pub const EnumMembers: u32 = CommaDelimited | SpaceBetweenSiblings | MultiLine | Indented | AllowTrailingComma;
    pub const Parameters: u32 = CommaDelimited | SpaceBetweenSiblings | SingleLine | Parenthesis;
    pub const MultiLineBlockStatements: u32 = Indented | MultiLine;
    pub const SingleLineFunctionBodyStatements: u32 = SingleLine | SpaceBetweenSiblings | SpaceBetweenBraces;
    pub const VariableDeclarationList: u32 = CommaDelimited | SpaceBetweenSiblings | SingleLine;
    pub const JsxElementOrFragmentChildren: u32 = SingleLine | NoInterveningComments;
    pub const JsxElementAttributes: u32 = SingleLine | SpaceBetweenSiblings | NoInterveningComments;
    pub const ClassMembers: u32 = MultiLine | SpaceBetweenSiblings | Indented;
    pub const ObjectBindingPatternElements: u32 = SingleLine | AllowTrailingComma | SpaceBetweenBraces | CommaDelimited | SpaceBetweenSiblings | NoSpaceIfEmpty;
    pub const ArrayBindingPatternElements: u32 = SingleLine | AllowTrailingComma | CommaDelimited | SpaceBetweenSiblings | NoSpaceIfEmpty;
    pub const TypeLiteralMembers: u32 = MultiLine | SpaceBetweenSiblings | Indented;
    pub const TupleTypeElements: u32 = CommaDelimited | SpaceBetweenSiblings | MultiLine | Indented;
    pub const UnionTypeElements: u32 = BarDelimited | SpaceBetweenSiblings | SingleLine;
    pub const IntersectionTypeElements: u32 = AmpersandDelimited | SpaceBetweenSiblings | SingleLine;
    pub const ObjectLiteralExpressionProperties: u32 = Braces | AllowTrailingComma;
    pub const CaseBlockClauses: u32 = Indented | MultiLine;
    pub const CaseOrDefaultClauseStatements: u32 = MultiLine | SpaceBetweenSiblings | NoTrailingNewLine;
    pub const NamedImportsOrExportsElements: u32 = CommaDelimited | SpaceBetweenSiblings | SpaceBetweenBraces | SingleLine | NoSpaceIfEmpty;
    pub const ImportAttributesElements: u32 = Braces | CommaDelimited | SpaceBetweenSiblings | SpaceBetweenBraces | SingleLine | NoSpaceIfEmpty;
};

fn getOpeningBracket(format: u32) []const u8 {
    switch (format & ListFormat.BracketsMask) {
        ListFormat.Braces => return "{",
        ListFormat.Parenthesis => return "(",
        ListFormat.AngleBrackets => return "<",
        ListFormat.SquareBrackets => return "[",
        else => unreachable,
    }
}

fn getClosingBracket(format: u32) []const u8 {
    switch (format & ListFormat.BracketsMask) {
        ListFormat.Braces => return "}",
        ListFormat.Parenthesis => return ")",
        ListFormat.AngleBrackets => return ">",
        ListFormat.SquareBrackets => return "]",
        else => unreachable,
    }
}

pub fn emitList(printer: *Printer, parentNode: ?ast_mod.NodeIndex, nodeListIndex: ast_mod.NodeIndex, listFormat: u32) anyerror!void {
    _ = parentNode;
    const format = listFormat;
    
    const children = if (nodeListIndex == 0) &[_]ast_mod.NodeIndex{} else printer.tree.getNodeList(nodeListIndex);
    const hasTrailingComma = if (nodeListIndex == 0) false else printer.tree.listHasTrailingComma(nodeListIndex);
    
    if (format == ListFormat.Modifiers) {
        if (children.len == 0) {
            return;
        }
    }
    if ((format & ListFormat.Optional) != 0 and children.len == 0) {
        return;
    }

    const isEmpty = children.len == 0;

    if ((format & ListFormat.BracketsMask) != 0) {
        printer.writer.writePunctuation(getOpeningBracket(format));
    }

    if (isEmpty) {
        std.debug.print("EMPTY LIST format: {d}, multiLine: {d}\n", .{format, format & @import("emit_list.zig").ListFormat.MultiLine});
        if ((format & ListFormat.MultiLine) != 0) {
            printer.writer.writeLine();
        } else if ((format & ListFormat.SpaceBetweenBraces) != 0 and (format & ListFormat.NoSpaceIfEmpty) == 0) {
            printer.writer.writeSpace(" ");
        }
    } else {
        try printListItems(printer, format, children, hasTrailingComma);
    }

    if ((format & ListFormat.BracketsMask) != 0) {
        printer.writer.writePunctuation(getClosingBracket(format));
    } else if ((format & ListFormat.SpaceAfterList) != 0 and !isEmpty) {
        const lastChild = children[children.len - 1];
        if (std.meta.activeTag(printer.tree.getNode(lastChild)) == .Decorator) {
            printer.writer.writeLine();
        } else {
            printer.writer.writeSpace(" ");
        }
    }
}

pub fn printList(printer: *Printer, format: u32, listIndex: ast_mod.NodeIndex) anyerror!void {
    std.debug.print("printList called with listIndex: {d}\n", .{listIndex});
    try emitList(printer, null, listIndex, format);
}

fn printListItems(printer: *Printer, format: u32, children: []const ast_mod.NodeIndex, hasTrailingComma: bool) anyerror!void {
    if ((format & ListFormat.Indented) != 0) {
        printer.writer.increaseIndent();
    }

    var previousSibling: ?ast_mod.NodeIndex = null;

    for (children, 0..) |child, i| {
        if (std.meta.activeTag(printer.tree.getNode(child)) == .EmptyStatement) {
            if (format == ListFormat.CaseOrDefaultClauseStatements) {
                printer.writer.writeSpace(" ");
            }
            try printer.printNode(child);
            continue;
        }

        // Delimiter
        if ((format & ListFormat.AsteriskDelimited) != 0) {
            printer.writer.writeLine();
            printer.writer.writeSpace(" ");
            printer.writer.writePunctuation("*");
            printer.writer.writeSpace(" ");
        } else if (previousSibling != null) {
            writeDelimiter(printer, format);

            if ((format & ListFormat.MultiLine) != 0) {
                printer.writer.writeLine();
            } else if ((format & ListFormat.SpaceBetweenSiblings) != 0) {
                if (std.meta.activeTag(printer.tree.getNode(previousSibling.?)) == .Decorator) {
                    printer.writer.writeLine();
                } else if (std.meta.activeTag(printer.tree.getNode(child)) == .Decorator) {
                    printer.writer.writeSpace(" ");
                    printer.writer.writeLine();
                } else {
                    printer.writer.writeSpace(" ");
                }
            }
        } else {
            // First item, but we might need leading newline for multiline list
            if ((format & ListFormat.MultiLine) != 0 or std.meta.activeTag(printer.tree.getNode(child)) == .Decorator) {
                printer.writer.writeLine();
            } else if ((format & ListFormat.SpaceBetweenBraces) != 0) {
                printer.writer.writeSpace(" ");
            }
        }

        try printer.printNode(child);
        previousSibling = child;

        // Comma if we are trailing and LFAllowTrailingComma
        if (i == children.len - 1) {
            // If the original source had a trailing comma, or if the last element is an OmittedExpression, we MUST write a trailing comma.
            if ((format & ListFormat.CommaDelimited) != 0 and (hasTrailingComma or std.meta.activeTag(printer.tree.getNode(child)) == .OmittedExpression)) {
                printer.writer.writePunctuation(",");
            }
        }
    }

    if ((format & ListFormat.Indented) != 0) {
        printer.writer.decreaseIndent();
    }

    if ((format & ListFormat.MultiLine) != 0 and (format & ListFormat.NoTrailingNewLine) == 0) {
        printer.writer.writeLine();
    } else if ((format & ListFormat.SpaceBetweenBraces) != 0) {
        printer.writer.writeSpace(" ");
    }
}

fn writeDelimiter(printer: *Printer, format: u32) void {
    switch (format & ListFormat.DelimitersMask) {
        ListFormat.NotDelimited => {},
        ListFormat.CommaDelimited => {
            printer.writer.writePunctuation(",");
        },
        ListFormat.BarDelimited => {
            printer.writer.writeSpace(" ");
            printer.writer.writePunctuation("|");
        },
        ListFormat.AsteriskDelimited => {
            printer.writer.writeSpace(" ");
            printer.writer.writePunctuation("*");
            printer.writer.writeSpace(" ");
        },
        ListFormat.AmpersandDelimited => {
            printer.writer.writeSpace(" ");
            printer.writer.writePunctuation("&");
        },
        else => {},
    }
}

pub fn printModifiers(printer: *Printer, listIndex: ast_mod.NodeIndex) anyerror!void {
    try printModifiersEx(printer, listIndex, true);
}

pub fn printModifiersEx(printer: *Printer, listIndex: ast_mod.NodeIndex, allowDecorators: bool) anyerror!void {
    if (listIndex != 0) {
        if (!allowDecorators) {
            // Filter out decorators
            var hasModifiers = false;
            const items = printer.tree.getNodeList(listIndex);
            for (items) |item| {
                if (printer.tree.getNode(item) != .Decorator) {
                    hasModifiers = true;
                    break;
                }
            }
            if (!hasModifiers) return;
            
            // Collect non-decorator modifiers and print them
            var nonDecorators = std.ArrayListUnmanaged(ast_mod.NodeIndex).empty;
            defer nonDecorators.deinit(printer.tree.allocator);
            for (items) |item| {
                if (printer.tree.getNode(item) != .Decorator) {
                    try nonDecorators.append(printer.tree.allocator, item);
                }
            }
            
            const tempNodeList = try printer.tree.pushNodeList(nonDecorators.items);
            try printList(printer, ListFormat.Modifiers, tempNodeList);
        } else {
            try printList(printer, ListFormat.Modifiers, listIndex);
        }
    }
}

pub fn printTypeArguments(printer: *Printer, listIndex: ast_mod.NodeIndex) anyerror!void {
    if (listIndex != 0) {
        try printList(printer, ListFormat.TypeArguments, listIndex);
    }
}

pub fn printTypeParameters(printer: *Printer, listIndex: ast_mod.NodeIndex) anyerror!void {
    if (listIndex != 0) {
        try printList(printer, ListFormat.TypeParameters, listIndex);
    }
}
