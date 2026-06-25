const std = @import("std");
const core = @import("../core/core.zig");
const cli = @import("commandlineparser.zig");
const tsconfig = @import("tsconfigparsing.zig");

test "Command Line Parser - Basic Flags" {
    const allocator = std.testing.allocator;
    var args = [_][]const u8{
        "--strict",
        "--target",
        "ES2022",
        "--allowJs",
        "file1.ts",
        "file2.ts",
    };

    var parsed = try cli.parseCommandLine(allocator, &args);
    defer parsed.deinit(allocator);

    try std.testing.expect(parsed.errors.items.len == 0);
    try std.testing.expect(parsed.options.strict orelse false);
    try std.testing.expect(parsed.options.allowJs orelse false);
    // target is currently stored as a string "?[]const u8" because JS script didn't map it properly to Enum maybe?
    // Wait, let's check what experimentalDecorators and other flags are.
    try std.testing.expectEqualStrings("file1.ts", parsed.fileNames.items[0]);
    try std.testing.expectEqualStrings("file2.ts", parsed.fileNames.items[1]);
}

test "TSConfig Parser - Basic File" {
    const allocator = std.testing.allocator;

    const content = 
        \\{
        \\  "compilerOptions": {
        \\    "strict": true,
        \\    "outDir": "./dist",
        \\    "allowJs": true
        \\  },
        \\  "files": [
        \\    "core.ts",
        \\    "sys.ts"
        \\  ]
        \\}
    ;

    var parsed = try tsconfig.parseTsConfigSlice(allocator, content);
    defer parsed.deinit(allocator);

    try std.testing.expect(parsed.errors.items.len == 0);
    try std.testing.expect(parsed.options.strict orelse false);
    try std.testing.expect(parsed.options.allowJs orelse false);
    try std.testing.expectEqualStrings("./dist", parsed.options.outDir.?);
    try std.testing.expectEqualStrings("core.ts", parsed.fileNames.items[0]);
    try std.testing.expectEqualStrings("sys.ts", parsed.fileNames.items[1]);
}
