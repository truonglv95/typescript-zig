const std = @import("std");
const parser_pkg = @import("../parser/parser.zig");
const binder_pkg = @import("../binder/binder.zig");
const checker_pkg = @import("../checker/checker.zig");
const diagnostics_pkg = @import("../diagnostics/diagnostics.zig");
const printer_pkg = @import("../printer/printer.zig");

/// C API: Khởi tạo và phân tích mã nguồn TypeScript
/// Hàm này được Go (qua CGO) gọi trực tiếp. Nó nhận chuỗi và trả về mã lỗi (0 = success).
pub export fn zig_ts_parse_and_check(source: [*]const u8, length: usize, is_jsx: u8) i32 {
    const src = source[0..length];

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = parser_pkg.Parser.init(allocator, src);
    if (is_jsx != 0) {
        parser.setLanguageVariant(.JSX);
    }
    defer parser.deinit();

    // Giả định parse toàn bộ file
    const sourceFileIndex = parser.parseSourceFile() catch return -1;

    var binder = binder_pkg.Binder.init(allocator, &parser.ast) catch unreachable;
    defer binder.deinit();
    binder.bindSourceFile(sourceFileIndex) catch return -2;

    var checker = checker_pkg.Checker.init(allocator, &binder);
    defer checker.deinit();

    _ = checker.checkStatementAdHoc(sourceFileIndex) catch return -4;

    if (parser.parseDiagnosticsCount > 0) {}
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

/// C API: Phân tích và sinh mã JavaScript (Code Generation)
/// Caller phải giải phóng buffer với zig_ts_free_buffer
pub export fn zig_ts_print(
    source: [*]const u8,
    length: usize,
    out_buf: *[*]u8,
    out_len: *usize,
) i32 {
    const src = source[0..length];

    const allocator = std.heap.page_allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var parser = parser_pkg.Parser.init(arena_alloc, src);
    defer parser.deinit();

    const sourceFileIndex = parser.parseSourceFile() catch {
        return -1;
    };

    if (parser.parseDiagnosticsCount > 0) {
        return -2; // Syntax errors present
    }

    // Note: Need to initialize context and writer correctly based on printer.zig
    var factory = @import("../printer/factory.zig").NodeFactory.init(allocator, &parser.ast);
    defer factory.deinit();
    var emit_ctx = @import("../printer/emitcontext.zig").EmitContext.init(allocator, &parser.ast, &factory);
    var text_writer = @import("../printer/textwriter.zig").TextWriter.init(allocator, "\n", 4);
    defer text_writer.deinit();
    var emit_writer = text_writer.getEmitTextWriter();
    var printer = printer_pkg.Printer.init(&parser.ast, &emit_ctx, &emit_writer);

    printer.printSourceFile(sourceFileIndex) catch return -3;
    const output = text_writer.string();
    const buf = allocator.dupe(u8, output) catch return -4;
    out_buf.* = buf.ptr;
    out_len.* = buf.len;
    return 0; // Success
}

/// C API: Get symbol count
pub export fn zig_ts_parse_and_bind_symbol_count(source: [*]const u8, length: usize, is_jsx: u8) i32 {
    const src = source[0..length];

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = parser_pkg.Parser.init(allocator, src);
    if (is_jsx != 0) {
        parser.setLanguageVariant(.JSX);
    }
    defer parser.deinit();

    const sourceFileIndex = parser.parseSourceFile() catch return -1;

    var binder = binder_pkg.Binder.init(allocator, &parser.ast) catch unreachable;
    defer binder.deinit();
    binder.bindSourceFile(sourceFileIndex) catch return -2;

    const symbols = binder.symbols.items;

    if (symbols.len > 10 and symbols.len < 100) {
        std.debug.print("Zig Symbol Count: {d}\n", .{symbols.len - 1});
        for (symbols[1..]) |sym| {
            std.debug.print("Zig Symbol: {s}\n", .{sym.Name});
        }
    }

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
    _ = checker.checkStatementAdHoc(sourceFileIndex) catch {};

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

/// C API: Export Binder state as JSON
pub export fn zig_ts_get_binder_state(
    source: [*]const u8,
    length: usize,
    out_buf: *[*]u8,
    out_len: *usize,
) i32 {
    const src = source[0..length];
    const allocator = std.heap.page_allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var parser = parser_pkg.Parser.init(arena_alloc, src);
    defer parser.deinit();

    const sourceFileIndex = parser.parseSourceFile() catch {
        const err = "{\"nodes\":[]}";
        const buf = allocator.dupe(u8, err) catch return -1;
        out_buf.* = buf.ptr;
        out_len.* = buf.len;
        return -1;
    };

    var binder = binder_pkg.Binder.init(arena_alloc, &parser.ast) catch {
        const err = "{\"nodes\":[]}";
        const buf = allocator.dupe(u8, err) catch return -2;
        out_buf.* = buf.ptr;
        out_len.* = buf.len;
        return -2;
    };
    defer binder.deinit();
    binder.bindSourceFile(sourceFileIndex) catch {};

    var json = std.ArrayListUnmanaged(u8).empty;

    json.appendSlice(arena_alloc, "{\"nodes\":[") catch return -3;

    var first = true;
    for (0..parser.ast.nodes.len) |i| {
        if (!first) {
            json.append(arena_alloc, ',') catch return -3;
        }
        first = false;

        json.appendSlice(arena_alloc, "{\"index\":") catch return -3;
        var idx_buf: [32]u8 = undefined;
        json.appendSlice(arena_alloc, std.fmt.bufPrint(&idx_buf, "{d}", .{i}) catch "0") catch return -3;

        json.appendSlice(arena_alloc, ",\"kind\":") catch return -3;
        var kind_buf: [32]u8 = undefined;
        json.appendSlice(arena_alloc, std.fmt.bufPrint(&kind_buf, "{d}", .{@intFromEnum(parser.ast.nodes.items(.tags)[i])}) catch "0") catch return -3;

        // Symbol
        const symIdx = parser.ast.getNodeSymbol(@as(u32, @intCast(i)));
        if (symIdx != null and symIdx.? != 0) {
            const sym = binder.symbols.items[symIdx.?];
            json.appendSlice(arena_alloc, ",\"symbolName\":\"") catch return -3;
            for (sym.Name) |c| {
                if (c == '"') {
                    json.appendSlice(arena_alloc, "\\\"") catch return -3;
                } else if (c == '\\') {
                    json.appendSlice(arena_alloc, "\\\\") catch return -3;
                } else if (c == 0xFE) {
                    json.appendSlice(arena_alloc, "__") catch return -3;
                } else {
                    json.append(arena_alloc, c) catch return -3;
                }
            }
            json.appendSlice(arena_alloc, "\",\"symbolFlags\":") catch return -3;
            var flag_buf: [32]u8 = undefined;
            json.appendSlice(arena_alloc, std.fmt.bufPrint(&flag_buf, "{d}", .{sym.Flags}) catch "0") catch return -3;
        }

        // LocalSymbol
        const localSymIdx = parser.ast.localSymbols.get(@as(u32, @intCast(i)));
        if (localSymIdx != null and localSymIdx.? != 0) {
            const sym = binder.symbols.items[localSymIdx.?];
            json.appendSlice(arena_alloc, ",\"localSymName\":\"") catch return -3;
            for (sym.Name) |c| {
                if (c == '"') {
                    json.appendSlice(arena_alloc, "\\\"") catch return -3;
                } else if (c == '\\') {
                    json.appendSlice(arena_alloc, "\\\\") catch return -3;
                } else if (c == 0xFE) {
                    json.appendSlice(arena_alloc, "__") catch return -3;
                } else {
                    json.append(arena_alloc, c) catch return -3;
                }
            }
            json.appendSlice(arena_alloc, "\",\"localSymFlags\":") catch return -3;
            var flag_buf: [32]u8 = undefined;
            json.appendSlice(arena_alloc, std.fmt.bufPrint(&flag_buf, "{d}", .{sym.Flags}) catch "0") catch return -3;
        }

        // LocalsCount
        if (binder.nodeLocals.get(@as(u32, @intCast(i)))) |localsMap| {
            json.appendSlice(arena_alloc, ",\"localsCount\":") catch return -3;
            var count_buf: [32]u8 = undefined;
            json.appendSlice(arena_alloc, std.fmt.bufPrint(&count_buf, "{d}", .{localsMap.count()}) catch "0") catch return -3;

            json.appendSlice(arena_alloc, ",\"localsKeys\":[") catch return -3;
            var it = localsMap.iterator();
            var first_key = true;
            // Collect keys and sort them so they match Go
            var keys = std.ArrayListUnmanaged([]const u8).empty;
            while (it.next()) |entry| {
                keys.append(arena_alloc, entry.key_ptr.*) catch return -3;
            }
            std.mem.sort([]const u8, keys.items, {}, struct {
                fn lessThan(ctx: void, a: []const u8, b: []const u8) bool {
                    _ = ctx;
                    return std.mem.order(u8, a, b) == .lt;
                }
            }.lessThan);
            for (keys.items) |k| {
                if (!first_key) json.append(arena_alloc, ',') catch return -3;
                first_key = false;
                json.append(arena_alloc, '"') catch return -3;

                // Escape __ (we use internal name missing here directly)
                const is_missing = std.mem.eql(u8, k, "__missing");
                if (is_missing) {
                    json.appendSlice(arena_alloc, "__missing") catch return -3;
                } else {
                    // escape \xFE to __
                    var out_k = std.ArrayListUnmanaged(u8).empty;
                    var k_i: usize = 0;
                    while (k_i < k.len) {
                        if (k[k_i] == 0xFE) {
                            out_k.appendSlice(arena_alloc, "__") catch return -3;
                            k_i += 1;
                        } else if (k[k_i] == '"') {
                            out_k.appendSlice(arena_alloc, "\\\"") catch return -3;
                            k_i += 1;
                        } else if (k[k_i] == '\\') {
                            out_k.appendSlice(arena_alloc, "\\\\") catch return -3;
                            k_i += 1;
                        } else {
                            out_k.append(arena_alloc, k[k_i]) catch return -3;
                            k_i += 1;
                        }
                    }
                    json.appendSlice(arena_alloc, out_k.items) catch return -3;
                }
                json.append(arena_alloc, '"') catch return -3;
            }
            json.append(arena_alloc, ']') catch return -3;
        }

        json.append(arena_alloc, '}') catch return -3;
    }

    json.appendSlice(arena_alloc, "]}") catch return -3;

    const result = allocator.dupe(u8, json.items) catch return -3;
    out_buf.* = result.ptr;
    out_len.* = result.len;

    return 0;
}

pub const TokenInfo = extern struct {
    kind: i32,
    start: i32,
    end: i32,
};

pub export fn zig_ts_scan(
    source: [*]const u8,
    length: usize,
    out_tokens: *[*]TokenInfo,
    out_count: *usize,
) i32 {
    const src = source[0..length];
    const allocator = std.heap.page_allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const scanner_pkg = @import("../scanner/scanner.zig");
    var scanner = scanner_pkg.Scanner.init(arena_alloc, src);
    scanner.skipTrivia = false;

    var tokenList = std.ArrayListUnmanaged(TokenInfo).empty;

    while (true) {
        const k = scanner.scan();
        tokenList.append(arena_alloc, .{
            .kind = @intFromEnum(k),
            .start = @as(i32, @intCast(scanner.state.tokenStart)),
            .end = @as(i32, @intCast(scanner.state.pos)),
        }) catch return -1;

        if (k == .EndOfFile) {
            break;
        }
    }

    const final_tokens = allocator.dupe(TokenInfo, tokenList.items) catch return -2;
    out_tokens.* = final_tokens.ptr;
    out_count.* = final_tokens.len;

    return 0;
}

pub export fn zig_ts_free_tokens(buf: [*]TokenInfo, len: usize) void {
    const allocator = std.heap.page_allocator;
    allocator.free(buf[0..len]);
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

/// C API: Export AST node kinds to verify creation order
pub export fn zig_ts_get_ast_node_kinds(
    source: [*]const u8,
    length: usize,
    out_kinds: *[*]u16,
    out_count: *usize,
) i32 {
    return zig_ts_get_ast_node_kinds_ex(source, length, 3, out_kinds, out_count);
}

/// C API: Export AST node kinds with explicit script_kind
/// script_kind: 1=JS, 2=JSX, 3=TS (default), 4=TSX
pub export fn zig_ts_get_ast_node_kinds_ex(
    source: [*]const u8,
    length: usize,
    script_kind: u32,
    out_kinds: *[*]u16,
    out_count: *usize,
) i32 {
    const src = source[0..length];
    const allocator = std.heap.page_allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var parser = parser_pkg.Parser.init(arena_alloc, src);
    defer parser.deinit();

    // Set language variant based on script kind:
    // JS=1, JSX=2, TS=3, TSX=4
    const is_jsx = (script_kind == 2 or script_kind == 4);
    if (is_jsx) {
        parser.setLanguageVariant(.JSX);
    }

    _ = parser.parseSourceFile() catch return -1;

    const count = parser.ast.nodes.len;

    // index 0 is Unknown reserve. Let's just dump ALL including 0.
    var kinds = allocator.alloc(u16, count) catch return -2;

    const tags = parser.ast.nodes.items(.tags);
    for (tags, 0..) |tag, i| {
        kinds[i] = @intFromEnum(tag);
    }

    out_kinds.* = kinds.ptr;
    out_count.* = kinds.len;

    return 0;
}

pub export fn zig_ts_free_ast_node_kinds(buf: [*]u16, len: usize) void {
    const allocator = std.heap.page_allocator;
    allocator.free(buf[0..len]);
}
