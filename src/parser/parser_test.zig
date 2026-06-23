const std = @import("std");
const parser_pkg = @import("parser.zig");

test "Parser integration on testdata" {
    const allocator = std.testing.allocator;

    const test_dirs = [_][]const u8{
        "/Users/truong/Documents/typescript-zig/submodule/typescript-go/testdata/tests/cases/compiler",
    };

    var total_files: usize = 0;
    var passed_files: usize = 0;

    for (test_dirs) |dir_path| {
        var dir = std.fs.openIterableDirAbsolute(dir_path, .{}) catch |err| {

            continue;
        };
        defer dir.close();

        var walker = try dir.walk(allocator);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            if (entry.kind == .file and std.mem.endsWith(u8, entry.basename, ".ts")) {
                total_files += 1;

                const file = try dir.openFile(entry.path, .{});
                defer file.close();

                const file_size = try file.getEndPos();
                const content = try file.readToEndAlloc(allocator, file_size);
                defer allocator.free(content);

                var p = parser_pkg.Parser.init(allocator, content);
                defer p.deinit();

                const ast_index = p.parseSourceFile() catch |err| {

                    continue;
                };
                
                _ = ast_index; // Ignore result for now, just ensure it doesn't crash
                passed_files += 1;
            }
        }
    }


    try std.testing.expectEqual(total_files, passed_files);
}
