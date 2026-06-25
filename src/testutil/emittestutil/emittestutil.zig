const std = @import("std");
const ast = @import("../../ast/ast.zig");
const core = @import("../../core/core.zig");
const printer = @import("../../printer/printer.zig");
const parsetestutil = @import("../parsetestutil/parsetestutil.zig");

// Checks that pretty-printing the given file matches the expected output.
pub fn checkEmit(allocator: std.mem.Allocator, emit_context: *printer.EmitContext, file: *ast.SourceFile, expected: []const u8) !void {
    var p = printer.Printer.init(
        allocator,
        printer.PrinterOptions{
            .new_line = core.NewLineKind.lf,
        },
        printer.PrintHandlers{},
        emit_context,
    );

    const text = try p.emitSourceFile(file);
    defer allocator.free(text);

    const actual = if (std.mem.endsWith(u8, text, "\n")) text[0 .. text.len - 1] else text;
    try std.testing.expectEqualStrings(expected, actual);

    const file2 = try parsetestutil.parseTypeScript(allocator, text, file.language_variant == core.LanguageVariant.jsx);
    try parsetestutil.checkDiagnosticsMessage(file2, "error on reparse: ");
}
