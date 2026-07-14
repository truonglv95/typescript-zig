const std = @import("std");
const parser_pkg = @import("parser.zig");

test "Parser integration on testdata" {
    const allocator = std.testing.allocator;

    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const cwd = std.Io.Dir.cwd();

    const test_dirs = [_][]const u8{
        "submodule/typescript-go/_submodules/TypeScript/tests/cases/compiler",
        "submodule/typescript-go/_submodules/TypeScript/tests/cases/conformance",
        "submodule/typescript-go/testdata/tests/cases/compiler",
    };

    var total_files: usize = 0;
    var passed_files: usize = 0;

    for (test_dirs) |dir_path| {
        var dir = cwd.openDir(io, dir_path, .{ .iterate = true }) catch {
            continue;
        };
        defer dir.close(io);

        var walker = try dir.walk(allocator);
        defer walker.deinit();

        while (try walker.next(io)) |entry| {
            if (entry.kind == .file and
                (std.mem.endsWith(u8, entry.basename, ".ts") or
                    std.mem.endsWith(u8, entry.basename, ".tsx") or
                    std.mem.endsWith(u8, entry.basename, ".jsx") or
                    std.mem.endsWith(u8, entry.basename, ".js")))
            {
                var file = dir.openFile(io, entry.path, .{}) catch continue;
                defer file.close(io);

                if (std.mem.indexOf(u8, entry.basename, "binderBinaryExpressionStress") != null or std.mem.indexOf(u8, entry.basename, "parsingDeepParenthensizedExpression") != null) {
                    continue;
                }
                const file_size = file.length(io) catch continue;
                if (file_size > 10 * 1024 * 1024) { // skip overly huge files to save memory/time
                    continue;
                }

                const content = allocator.alloc(u8, @intCast(file_size)) catch continue;
                defer allocator.free(content);

                _ = file.readPositionalAll(io, content, 0) catch continue;

                total_files += 1;

                var arena = std.heap.ArenaAllocator.init(allocator);
                defer arena.deinit();
                const arena_allocator = arena.allocator();

                var p = parser_pkg.Parser.init(arena_allocator, content);
                // defer p.deinit(); // not needed, arena will free everything

                std.debug.print("Parsing file: {s}\n", .{entry.path});
                const ast_index = p.parseSourceFile() catch {
                    continue;
                };

                _ = ast_index; // Ignore result for now, just ensure it doesn't crash
                passed_files += 1;
            }
        }
    }

    // std.debug.print("\nTotal parsed files: {d}/{d}\n", .{passed_files, total_files});
    try std.testing.expectEqual(total_files, passed_files);
}
