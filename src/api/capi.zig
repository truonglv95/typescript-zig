const std = @import("std");
const parser_pkg = @import("../parser/parser.zig");
const binder_pkg = @import("../binder/binder.zig");
const checker_pkg = @import("../checker/checker.zig");
const diagnostics_pkg = @import("../diagnostics/diagnostics.zig");

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

/// C API: Get diagnostics as JSON
/// Caller phải giải phóng buffer với zig_ts_free_buffer
pub export fn zig_ts_get_diagnostics(
    source: [*]const u8,
    length: usize,
    out_buf: *[*]u8,
    out_len: *usize,
) i32 {
    const src = source[0..length];

    // Dùng page_allocator trực tiếp để caller có thể free
    const allocator = std.heap.page_allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var parser = parser_pkg.Parser.init(arena_alloc, src);
    defer parser.deinit();

    const sourceFileIndex = parser.parseSourceFile() catch {
        const err = "{\"error\":\"parse_failed\"}";
        const buf = allocator.dupe(u8, err) catch return -1;
        out_buf.* = buf.ptr;
        out_len.* = buf.len;
        return -1;
    };

    var binder = binder_pkg.Binder.init(arena_alloc, &parser.ast) catch {
        const err = "{\"error\":\"bind_failed\"}";
        const buf = allocator.dupe(u8, err) catch return -2;
        out_buf.* = buf.ptr;
        out_len.* = buf.len;
        return -2;
    };
    defer binder.deinit();
    binder.bindSourceFile(sourceFileIndex) catch {};

    var checker = checker_pkg.Checker.init(arena_alloc, &binder);
    defer checker.deinit();
    _ = checker.checkStatement(sourceFileIndex) catch {};

    // Build JSON diagnostics array
    var json = std.ArrayListUnmanaged(u8).empty;
    defer json.deinit(arena_alloc);

    json.appendSlice(arena_alloc, "{\"parseDiagnostics\":") catch return -3;
    json.append(arena_alloc, '[') catch return -3;

    var first = true;
    for (binder.diagnosticsList.items) |diag| {
        if (!first) {
            json.append(arena_alloc, ',') catch return -3;
        }
        first = false;
        json.appendSlice(arena_alloc, "{\"code\":") catch return -3;
        var code_buf: [16]u8 = undefined;
        const code_str = std.fmt.bufPrint(&code_buf, "{d}", .{diag.message.code}) catch "0";
        json.appendSlice(arena_alloc, code_str) catch return -3;
        json.appendSlice(arena_alloc, ",\"category\":") catch return -3;
        const cat: u8 = @intFromEnum(diag.message.category);
        var cat_buf: [4]u8 = undefined;
        const cat_str = std.fmt.bufPrint(&cat_buf, "{d}", .{cat}) catch "0";
        json.appendSlice(arena_alloc, cat_str) catch return -3;
        json.appendSlice(arena_alloc, ",\"node\":") catch return -3;
        var node_buf: [16]u8 = undefined;
        const node_str = std.fmt.bufPrint(&node_buf, "{d}", .{diag.nodeIndex}) catch "0";
        json.appendSlice(arena_alloc, node_str) catch return -3;
        json.append(arena_alloc, '}') catch return -3;
    }
    json.append(arena_alloc, ']') catch return -3;

    // Add parse error count
    json.appendSlice(arena_alloc, ",\"parseErrorCount\":") catch return -3;
    var pe_buf: [16]u8 = undefined;
    const pe_str = std.fmt.bufPrint(&pe_buf, "{d}", .{parser.parseDiagnosticsCount}) catch "0";
    json.appendSlice(arena_alloc, pe_str) catch return -3;
    json.append(arena_alloc, '}') catch return -3;

    // Copy to page_allocator so caller can free
    const result = allocator.dupe(u8, json.items) catch return -3;
    out_buf.* = result.ptr;
    out_len.* = result.len;

    return 0;
}

/// C API: Free buffer allocated by zig_ts_get_diagnostics
pub export fn zig_ts_free_buffer(buf: [*]u8, len: usize) void {
    std.heap.page_allocator.free(buf[0..len]);
}

/// C API: Get node count from parsing
pub export fn zig_ts_get_node_count(source: [*]const u8, length: usize) i32 {
    const src = source[0..length];

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = parser_pkg.Parser.init(allocator, src);
    defer parser.deinit();

    _ = parser.parseSourceFile() catch return -1;

    return @as(i32, @intCast(parser.ast.nodes.len));
}
