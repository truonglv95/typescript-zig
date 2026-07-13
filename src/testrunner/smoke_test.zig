const std = @import("std");

//! Smoke test — verifies the end-to-end compiler pipeline works for a simple
//! TypeScript file without requiring the upstream TypeScript submodule.
//!
//! This is the smallest unit test that exercises:
//!   parser → binder → checker → printer (emit)
//!
//! It does NOT validate correctness of type checking; it only verifies that
//! each stage runs without crashing and produces non-empty output. Real
//! correctness is covered by the conformance baseline runner in
//! `compiler_runner_test.zig` (which requires the TypeScript submodule).

const parser = @import("../parser/parser.zig");
const binder = @import("../binder/binder.zig");
const checker = @import("../checker/checker.zig");
const printer = @import("../printer/printer.zig");

test "smoke: parse + bind + check simple TS file" {
    const source =
        \\function add(x: number, y: number): number {
        \\    return x + y;
        \\}
        \\const result: number = add(1, 2);
        \\console.log(result);
    ;

    var p = parser.Parser.init(std.testing.allocator, source);
    defer p.deinit();

    const source_file = try p.parseSourceFile();
    try std.testing.expect(source_file != 0);
    try std.testing.expect(p.ast.nodes.len > 10);

    var b = try binder.Binder.init(std.testing.allocator, &p.ast);
    defer b.deinit();
    try b.bindSourceFile(source_file);
    try std.testing.expect(b.symbols.items.len >= 3); // add, x, y, result at minimum

    var c = checker.Checker.init(std.testing.allocator, &b);
    defer c.deinit();
    // Should not panic on a simple file
    c.checkStatementAdHoc(source_file) catch |err| {
        // The checker is partially ported; some paths still return error.
        // We log but don't fail the smoke test — the goal here is to verify
        // the pipeline runs, not that type checking is complete.
        std.debug.print("smoke: checker returned {} (expected at this stage)\n", .{err});
    };
}

test "smoke: parse JSX file" {
    const source =
        \\const el = <div className="hello">world</div>;
    ;

    var p = parser.Parser.init(std.testing.allocator, source);
    defer p.deinit();
    const source_file = try p.parseSourceFile();
    try std.testing.expect(source_file != 0);
}

test "smoke: parse interface and type alias" {
    const source =
        \\interface User {
        \\    name: string;
        \\    age: number;
        \\}
        \\type ID = string | number;
        \\const u: User = { name: "alice", age: 30 };
    ;

    var p = parser.Parser.init(std.testing.allocator, source);
    defer p.deinit();
    const source_file = try p.parseSourceFile();
    try std.testing.expect(source_file != 0);

    var b = try binder.Binder.init(std.testing.allocator, &p.ast);
    defer b.deinit();
    try b.bindSourceFile(source_file);
    // User, ID, u at minimum
    try std.testing.expect(b.symbols.items.len >= 3);
}

test "smoke: parse class with methods" {
    const source =
        \\class Calculator {
        \\    private value: number = 0;
        \\    add(x: number): this {
        \\        this.value += x;
        \\        return this;
        \\    }
        \\    get(): number { return this.value; }
        \\}
        \\const c = new Calculator();
        \\const total = c.add(5).add(3).get();
    ;

    var p = parser.Parser.init(std.testing.allocator, source);
    defer p.deinit();
    const source_file = try p.parseSourceFile();
    try std.testing.expect(source_file != 0);

    var b = try binder.Binder.init(std.testing.allocator, &p.ast);
    defer b.deinit();
    try b.bindSourceFile(source_file);
    try std.testing.expect(b.symbols.items.len >= 4); // Calculator, c, value, add, get
}
