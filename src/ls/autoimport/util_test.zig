const std = @import("std");
const testing = std.testing;
const util = @import("util.zig");

test "wordIndices" {
    const Test = struct {
        input: []const u8,
        expectedWords: []const []const u8,
    };

    const tests = [_]Test{
        // Basic camelCase
        .{
            .input = "camelCase",
            .expectedWords = &[_][]const u8{ "camelCase", "Case" },
        },
        // snake_case
        .{
            .input = "snake_case",
            .expectedWords = &[_][]const u8{ "snake_case", "case" },
        },
        // ParseURL - uppercase sequence followed by lowercase
        .{
            .input = "ParseURL",
            .expectedWords = &[_][]const u8{ "ParseURL", "URL" },
        },
        // XMLHttpRequest - multiple uppercase sequences
        .{
            .input = "XMLHttpRequest",
            .expectedWords = &[_][]const u8{ "XMLHttpRequest", "HttpRequest", "Request" },
        },
        // Single word lowercase
        .{
            .input = "hello",
            .expectedWords = &[_][]const u8{ "hello" },
        },
        // Single word uppercase
        .{
            .input = "HELLO",
            .expectedWords = &[_][]const u8{ "HELLO" },
        },
        // Mixed with numbers
        .{
            .input = "parseHTML5Parser",
            .expectedWords = &[_][]const u8{ "parseHTML5Parser", "HTML5Parser", "Parser" },
        },
        // Underscore variations
        .{
            .input = "__proto__",
            .expectedWords = &[_][]const u8{ "__proto__", "proto__" },
        },
        .{
            .input = "_private_member",
            .expectedWords = &[_][]const u8{ "_private_member", "member" },
        },
        // Single character
        .{
            .input = "a",
            .expectedWords = &[_][]const u8{ "a" },
        },
        .{
            .input = "A",
            .expectedWords = &[_][]const u8{ "A" },
        },
        // Consecutive underscores
        .{
            .input = "test__double__underscore",
            .expectedWords = &[_][]const u8{ "test__double__underscore", "double__underscore", "underscore" },
        },
    };

    for (tests) |tt| {
        const indices = try util.wordIndices(testing.allocator, tt.input);
        defer testing.allocator.free(indices);

        var actualWords = std.ArrayList([]const u8).empty;
        defer actualWords.deinit(testing.allocator);

        for (indices) |idx| {
            try actualWords.append(testing.allocator, tt.input[idx..]);
        }

        try testing.expectEqual(tt.expectedWords.len, actualWords.items.len);
        for (tt.expectedWords, 0..) |expected, i| {
            try testing.expectEqualStrings(expected, actualWords.items[i]);
        }
    }
}

test "GetPackageRealpathFuncs_FollowsNodeModulesSymlinks" {
    // TODO: implement TestGetPackageRealpathFuncs_FollowsNodeModulesSymlinks
}

test "GetPackageRealpathFuncs_DuplicateCacheKeys" {
    // TODO: implement TestGetPackageRealpathFuncs_DuplicateCacheKeys
}

test "GetPackageRealpathFuncs_NonSymlinkedPackageWithSymlinkedDeps" {
    // TODO: implement TestGetPackageRealpathFuncs_NonSymlinkedPackageWithSymlinkedDeps
}
