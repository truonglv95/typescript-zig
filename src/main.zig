const std = @import("std");
const parser = @import("parser/parser.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

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

    var p = parser.Parser.init(allocator, sourceText);
    defer p.deinit();

    const astIndex = try p.parseSourceFile();
    _ = astIndex;

}
