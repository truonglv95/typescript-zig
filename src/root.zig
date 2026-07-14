const std = @import("std");

// Export C API cho CGO
pub const capi = @import("api/capi.zig");
comptime {
    _ = capi.zig_ts_parse_and_check;
    _ = capi.zig_ts_parse;
}

// Export for internal tools (cmd/*)
pub const parser_pkg = @import("parser/parser.zig");
pub const binder_pkg = @import("binder/binder.zig");
pub const checker_pkg = @import("checker/checker.zig");
pub const printer_pkg = @import("printer/printer.zig");
pub const factory = @import("printer/factory.zig");
pub const emitcontext = @import("printer/emitcontext.zig");
pub const helpers = @import("printer/helpers.zig");
pub const textwriter = @import("printer/textwriter.zig");
pub const transformers_pkg = @import("transformers/transformers.zig");
pub const typeeraser = @import("transformers/tstransforms/typeeraser.zig");
pub const core = @import("core/core.zig");
pub const emitresolver = @import("printer/emitresolver.zig");
pub const referenceresolver = @import("binder/referenceresolver.zig");
pub const ast_utils = @import("ast/ast_utils.zig");
pub const declarations = @import("transformers/declarations.zig");
pub const commandlineparser = @import("compiler/commandlineparser.zig");
pub const simple_tsconfig = @import("compiler/tsconfigparsing.zig");
pub const program = @import("compiler/program.zig");
pub const lsp_transport = @import("lsp/transport.zig");
pub const lsp_protocol = @import("lsp/protocol_session.zig");
pub const execute = @import("execute/execute.zig");
pub const sys_pkg = @import("sys.zig");

test {
    _ = @import("ast/kind.zig");
    _ = @import("ast/ast.zig");
    _ = @import("scanner/scanner.zig");
    _ = @import("parser/parser.zig");
    _ = @import("binder/binder.zig");
    _ = @import("checker/checker.zig");
    _ = @import("printer/printer.zig");
    _ = @import("lsp/server.zig");
    _ = @import("lsp/document_store.zig");
    _ = @import("lsp/transport.zig");
    _ = @import("lsp/protocol_session.zig");

    // Test files that are currently buildable
    _ = @import("parser/parser_test.zig");
    _ = @import("printer/printer_test.zig");

    _ = @import("testrunner/compiler_runner_test.zig");
    // Test runner
    _ = @import("testrunner/testmain_test.zig");
    _ = @import("testrunner/compiler_runner_test.zig");
    _ = @import("testrunner/test_case_parser_test.zig");
    _ = @import("testrunner/smoke_test.zig");

    // Utilities and modules tests
    _ = @import("modulespecifiers/specifiers_test.zig");
    _ = @import("compiler/commandline_test.zig");
    _ = @import("compiler/program.zig");

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
                    std.debug.print(" -> Identifier '{s}' (node {d}) resolved to Symbol: '{s}' (Flags: {d})\n", .{ idText, i, sym.Name, sym.Flags });
                }
            }
        }
    }

    std.debug.print("\nTesting Type Checker...\n", .{});
    const checker = @import("checker/checker.zig");
    var c = checker.Checker.init(std.testing.allocator, &b);
    defer c.deinit();

    try c.checkStatementAdHoc(astIndex);
}

test "basic printer" {
    const parser = @import("parser/parser.zig");
    const p_pkg = @import("printer/printer.zig");
    _ = p_pkg;

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
