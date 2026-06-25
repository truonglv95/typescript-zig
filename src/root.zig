const std = @import("std");

// Export C API cho CGO
pub const capi = @import("api/capi.zig");
comptime {
    _ = capi.zig_ts_parse_and_check;
    _ = capi.zig_ts_parse;
}

test {
    _ = @import("ast/kind.zig");
    _ = @import("ast/ast.zig");
    _ = @import("scanner/scanner.zig");
    _ = @import("parser/parser.zig");
    _ = @import("binder/binder.zig");
    _ = @import("checker/checker.zig");
    _ = @import("printer/printer.zig");
    _ = @import("lsp/server.zig");

    // Test files that are currently buildable
    _ = @import("parser/parser_test.zig");
    _ = @import("printer/printer_test.zig");

    // Test runner
    _ = @import("testrunner/testmain_test.zig");
    _ = @import("testrunner/compiler_runner_test.zig");
    _ = @import("testrunner/test_case_parser_test.zig");

    // Utilities and modules tests
    _ = @import("modulespecifiers/specifiers_test.zig");
    _ = @import("compiler/commandline_test.zig");
    
    // Core compiler tests
    _ = @import("transformers/tstransforms/typeeraser_test.zig");
    
    // Language Service tests
    _ = @import("ls/lsconv/converters_test.zig");
    _ = @import("ls/lsutil/userpreferences_test.zig");
    _ = @import("ls/lsutil/utilities_test.zig");
    _ = @import("ls/autoimport/index_test.zig");
    _ = @import("ls/autoimport/testmain_test.zig");
    _ = @import("ls/autoimport/util_test.zig");
    _ = @import("ls/autoimport/registry_test.zig");
    _ = @import("ls/autoimport/aliasresolver_crash_test.zig");
}

test "basic parser integration" {
    const parser = @import("parser/parser.zig");
    const symbol = @import("ast/symbol.zig");

    const sourceText =
        \\function add(x: number, y: number): number {
        \\    return x + y;
        \\}
        \\let a: number = 42;
        \\let b = 100;
        \\class Calculator {
        \\    result: number;
        \\    compute() {
        \\        let z = a + b;
        \\    }
        \\}
    ;

    var p = parser.Parser.init(std.testing.allocator, sourceText);
    defer p.deinit();

    const astIndex = try p.parseSourceFile();

    const binder = @import("binder/binder.zig");
    var b = try binder.Binder.init(std.testing.allocator, &p.ast);
    defer b.deinit();

    try b.bindSourceFile(astIndex);

    std.debug.print("Parse & Bind successful! Total AST Nodes: {d}\n", .{p.ast.nodes.len});
    std.debug.print("Total Symbols created: {d}\n", .{b.symbols.items.len});
    std.debug.print("Total Scope Containers (nodeLocals map): {d}\n", .{b.nodeLocals.count()});
    for (b.symbols.items) |sym| {
        std.debug.print(" - Symbol: {s} (Flags: {d})\n", .{ sym.Name, sym.Flags });
    }

    std.debug.print("\nTesting Name Resolution...\n", .{});
    var resolver = @import("binder/nameresolver.zig").NameResolver.init(&p.ast, &b, null);
    for (0..p.ast.nodes.len) |i| {
        const node = p.ast.nodes.get(i);
        if (node == .Identifier) {
            const idText = node.Identifier.Text;
            if (std.mem.eql(u8, idText, "x") or std.mem.eql(u8, idText, "y")) {
                if (resolver.resolve(@as(u32, @intCast(i)), idText, symbol.SymbolFlags.FunctionScopedVariable | symbol.SymbolFlags.BlockScopedVariable, null, false, false)) |symIndex| {
                    const sym = b.symbols.items[symIndex];
                    std.debug.print(" -> Identifier '{s}' (node {d}) resolved to Symbol: '{s}' (Flags: {d})\n", .{idText, i, sym.Name, sym.Flags});
                }
            }
        }
    }

    std.debug.print("\nTesting Type Checker...\n", .{});
    const checker = @import("checker/checker.zig");
    var c = checker.Checker.init(std.testing.allocator, &b);
    defer c.deinit();
    
    try c.checkStatement(astIndex);
}

test "basic printer" {
    const parser = @import("parser/parser.zig");
    const printer_pkg = @import("printer/printer.zig");
    _ = printer_pkg;

    const sourceText =
        \\function greet(name: string): string {
        \\    return "Hello, " + name;
        \\}
        \\const x: number = 42;
    ;

    var p = parser.Parser.init(std.testing.allocator, sourceText);
    defer p.deinit();

    const astIndex = try p.parseSourceFile();
    _ = astIndex;

    // var pr = printer_pkg.Printer.init(std.testing.allocator, &p.ast, null);
    // defer pr.deinit();

    // try pr.printSourceFile(astIndex);
    // const output = pr.getOutput();

    // std.debug.print("\n[basic printer test output]\n{s}\n", .{output});

    // try std.testing.expect(std.mem.indexOf(u8, output, "function") != null);
    // Must NOT contain TypeScript type annotations
    // try std.testing.expect(std.mem.indexOf(u8, output, ": string") == null);
    // try std.testing.expect(std.mem.indexOf(u8, output, ": number") == null);
}

pub const diagnostics = @import("diagnostics/diagnostics.zig");

test "refAllDecls flow" {
    std.testing.refAllDecls(@import("checker/flow.zig"));
}
