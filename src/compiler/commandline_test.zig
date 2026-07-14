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

test "Command Line Parser - negated boolean flag" {
    const allocator = std.testing.allocator;
    var args = [_][]const u8{ "--watch", "--noWatch", "index.ts" };
    var parsed = try cli.parseCommandLine(allocator, &args);
    defer parsed.deinit(allocator);

    try std.testing.expectEqual(@as(?bool, false), parsed.options.watch);
    try std.testing.expectEqual(@as(usize, 1), parsed.fileNames.items.len);
    try std.testing.expectEqualStrings("index.ts", parsed.fileNames.items[0]);
}

test "Command Line Parser - list and modern enum options" {
    const allocator = std.testing.allocator;
    var args = [_][]const u8{ "--moduleResolution", "bundler", "--lib", "es2022,dom", "index.ts" };
    var parsed = try cli.parseCommandLine(allocator, &args);
    defer parsed.deinit(allocator);
    try std.testing.expectEqual(core.ModuleResolutionKind.Bundler, parsed.options.moduleResolution.?);
    try std.testing.expectEqualStrings("es2022", parsed.options.lib.?[0]);
    try std.testing.expectEqualStrings("dom", parsed.options.lib.?[1]);
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
