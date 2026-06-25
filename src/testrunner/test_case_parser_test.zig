const std = @import("std");
const test_case_parser = @import("test_case_parser.zig");

test "makeUnitsFromTest" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const code =
        \\// @strict: true
        \\// @noEmit: true
        \\// @filename: firstFile.ts
        \\function foo() { return "a"; }
        \\// normal comment
        \\// @filename: secondFile.ts
        \\// some other comment
        \\function bar() { return "b"; }
    ;

    var result = try test_case_parser.makeUnitsFromTest(allocator, code, "simpleTest.ts");
    defer {
        for (result.testUnitData) |unit| {
            allocator.free(unit.content);
            allocator.free(unit.name);
        }
        allocator.free(result.testUnitData);
        var symlink_iter = result.symlinks.keyIterator();
        while (symlink_iter.next()) |k| {
            allocator.free(k.*);
            allocator.free(result.symlinks.get(k.*).?);
        }
        result.symlinks.deinit();
    }

    try std.testing.expectEqual(@as(usize, 2), result.testUnitData.len);

    try std.testing.expectEqualStrings("firstFile.ts", result.testUnitData[0].name);
    try std.testing.expectEqualStrings("function foo() { return \"a\"; }\n// normal comment", result.testUnitData[0].content);

    try std.testing.expectEqualStrings("secondFile.ts", result.testUnitData[1].name);
    try std.testing.expectEqualStrings("// some other comment\nfunction bar() { return \"b\"; }", result.testUnitData[1].content);

    try std.testing.expect(result.tsConfig == null);
    try std.testing.expect(result.tsConfigFileUnitData == null);
    try std.testing.expectEqual(@as(usize, 0), result.symlinks.count());
}
