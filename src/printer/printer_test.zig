const std = @import("std");
const parser = @import("../parser/parser.zig");
const printer_pkg = @import("printer.zig");
const factory_pkg = @import("factory.zig");
const emitcontext_pkg = @import("emitcontext.zig");
const textwriter_pkg = @import("textwriter.zig");

const test_data = @import("printer_test_cases.zig");
const test_cases = test_data.test_cases;

test "Printer Emit Test Cases from Go" {
    const alloc = std.testing.allocator;

    for (test_cases) |tc| {
        if (std.mem.startsWith(u8, tc.title, "Jsx")) continue;
        var arena = std.heap.ArenaAllocator.init(alloc);
        defer arena.deinit();
        const arena_alloc = arena.allocator();

        var p = parser.Parser.init(arena_alloc, tc.input);
        defer p.deinit();
        
        std.debug.print("Parsing {s}\n", .{tc.title});
        var astIndex: u32 = 0;
        if (std.mem.eql(u8, tc.title, "ExpressionWithTypeArguments")) {
            const expr = try p.parseExpressionWithTypeArguments();
            // Wrap in an ExpressionStatement to get the trailing semicolon
            const stmt = try p.ast.pushNode(.{ .ExpressionStatement = .{ .Flags = 0, .Expression = expr } });
            // Wrap in a SourceFile
            const stmts = try p.ast.pushNodeList(&.{stmt});
            astIndex = try p.ast.pushNode(.{ .SourceFile = .{ .Flags = 0, .Symbol = 0, .Statements = stmts, .EndOfFileToken = 0 } });
        } else {
            astIndex = try p.parseSourceFile();
        }
        var factory = factory_pkg.NodeFactory.init(arena_alloc, &p.ast);
        defer factory.deinit();
        
        var emit_ctx = emitcontext_pkg.EmitContext.init(arena_alloc, &p.ast, &factory);
        var text_writer = textwriter_pkg.TextWriter.init(arena_alloc, "\n", 4);
        defer text_writer.deinit();
        
        var emit_writer = text_writer.getEmitTextWriter();
        var pr = printer_pkg.Printer.init(&p.ast, &emit_ctx, &emit_writer);

        try pr.printSourceFile(astIndex);
        const output = text_writer.string();
        
        // Trim trailing newline if it exists to match Go test output precisely
        var actual = output;
        if (std.mem.endsWith(u8, actual, "\n")) {
            actual = actual[0..actual.len - 1];
        }
        const expected = tc.output;

        if (!std.mem.eql(u8, actual, expected)) {
            std.debug.print("FAIL: {s}\nExpected: '{s}'\nActual: '{s}'\n", .{ tc.title, expected, actual });
            try std.testing.expectEqualStrings(expected, actual);
        }
    }
}
