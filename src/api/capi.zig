const std = @import("std");
const parser_pkg = @import("../parser/parser.zig");
const binder_pkg = @import("../binder/binder.zig");
const checker_pkg = @import("../checker/checker.zig");

/// C API: Khởi tạo và phân tích mã nguồn TypeScript
/// Hàm này được Go (qua CGO) gọi trực tiếp. Nó nhận chuỗi và trả về mã lỗi (0 = success).
pub export fn zig_ts_parse_and_check(source: [*]const u8, length: usize) i32 {
    const src = source[0..length];

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = parser_pkg.Parser.init(allocator, src);
    defer parser.deinit();

    // Giả định parse toàn bộ file
    const sourceFileIndex = parser.parseSourceFile() catch return -1;

    var binder = binder_pkg.Binder.init(allocator, &parser.ast) catch unreachable;
    defer binder.deinit();
    binder.bindSourceFile(sourceFileIndex) catch return -2;

    var checker = checker_pkg.Checker.init(allocator, &binder);
    defer checker.deinit();

    _ = checker.checkStatement(sourceFileIndex) catch return -4;

    if (parser.parseDiagnosticsCount > 0) {

    }
    return @as(i32, @intCast(parser.parseDiagnosticsCount));
}

/// C API: Chỉ phân tích mã nguồn TypeScript (Phục vụ Task 3.3)
pub export fn zig_ts_parse(source: [*]const u8, length: usize) i32 {
    const src = source[0..length];

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = parser_pkg.Parser.init(allocator, src);
    defer parser.deinit();

    _ = parser.parseSourceFile() catch return -1;

    return 0; // Success
}

/// C API: Get symbol count
pub export fn zig_ts_parse_and_bind_symbol_count(source: [*]const u8, length: usize) i32 {
    const src = source[0..length];

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = parser_pkg.Parser.init(allocator, src);
    defer parser.deinit();

    const sourceFileIndex = parser.parseSourceFile() catch return -1;

    var binder = binder_pkg.Binder.init(allocator, &parser.ast) catch unreachable;
    defer binder.deinit();
    binder.bindSourceFile(sourceFileIndex) catch return -2;

    const symbols = binder.symbols.items;
    return @as(i32, @intCast(symbols.len - 1));
}
