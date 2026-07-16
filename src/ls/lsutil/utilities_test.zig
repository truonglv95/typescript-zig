const std = @import("std");
const ast = @import("../../ast/ast.zig");
const core = @import("../../core/core.zig");
const parser = @import("../../parser/parser.zig");
const utilities = @import("utilities.zig");
const organizeimports = @import("organizeimports.zig");
const userpreferences = @import("userpreferences.zig");
const OrganizeImportsSort = userpreferences.OrganizeImportsSort;

fn parseTS(allocator: std.mem.Allocator, text: []const u8) !*parser.Parser {
    var p = try allocator.create(parser.Parser);
    p.* = parser.Parser.init(allocator, text);
    p.setScriptKind(.TS);
    _ = try p.parseSourceFile();
    return p;
}

test "ProbablyUsesSemicolons" {
    const allocator = std.testing.allocator;

    const tests = [_]struct {
        name: []const u8,
        src: []const u8,
        want: bool,
    }{
        .{
            .name = "mixed semicolons and ASI favors semicolons when ratio exceeds one fifth",
            .src = "let a = 1;\nlet b = 2;\nlet c = 3\nlet d = 4\nlet e = 5\n",
            .want = true,
        },
        .{
            .name = "consistent ASI with no semicolons",
            .src = "let a = 1\nlet b = 2\nlet c = 3\n",
            .want = false,
        },
        .{
            .name = "consistent semicolons",
            .src = "let a = 1;\nlet b = 2;\nlet c = 3;\n",
            .want = true,
        },
    };

    for (tests) |tt| {
        var p = try parseTS(allocator, tt.src);
        defer {
            p.deinit();
            allocator.destroy(p);
        }
        
        const got = utilities.probablyUsesSemicolons(&p.ast);
        try std.testing.expectEqual(tt.want, got);
    }
}

test "ResolveOrganizeImportsSort" {
    const tests = [_]struct {
        name: []const u8,
        preferences: userpreferences.UserPreferences,
        want: OrganizeImportsSort,
    }{
        .{
            .name = "explicit sort wins",
            .preferences = .{
                .organizeImportsSort = .Ordinal,
                .organizeImportsCollation = .Unicode,
                .organizeImportsIgnoreCase = .True,
            },
            .want = .Ordinal,
        },
        .{
            .name = "unicode case-sensitive maps to natural",
            .preferences = .{
                .organizeImportsCollation = .Unicode,
                .organizeImportsIgnoreCase = .False,
            },
            .want = .Natural,
        },
        .{
            .name = "unicode ignore case maps to natural ignore case",
            .preferences = .{
                .organizeImportsCollation = .Unicode,
                .organizeImportsIgnoreCase = .True,
            },
            .want = .NaturalIgnoreCase,
        },
        .{
            .name = "unicode auto maps to auto",
            .preferences = .{
                .organizeImportsCollation = .Unicode,
                .organizeImportsIgnoreCase = .Unknown,
            },
            .want = .Auto,
        },
        .{
            .name = "ordinal case-sensitive maps to ordinal",
            .preferences = .{
                .organizeImportsCollation = .Ordinal,
                .organizeImportsIgnoreCase = .False,
            },
            .want = .Ordinal,
        },
        .{
            .name = "ordinal ignore case maps to ordinal ignore case",
            .preferences = .{
                .organizeImportsCollation = .Ordinal,
                .organizeImportsIgnoreCase = .True,
            },
            .want = .OrdinalIgnoreCase,
        },
        .{
            .name = "ordinal auto maps to auto",
            .preferences = .{
                .organizeImportsCollation = .Ordinal,
                .organizeImportsIgnoreCase = .Unknown,
            },
            .want = .Auto,
        },
    };

    for (tests) |tt| {
        const got = organizeimports.resolveOrganizeImportsSort(tt.preferences);
        try std.testing.expectEqual(tt.want, got);
    }
}

test "CompareOrganizeImportsNaturalStrings" {
    const comparer = organizeimports.getOrganizeImportsPresetStringComparer(.NaturalIgnoreCase);

    const tests = [_]struct {
        name: []const u8,
        a: []const u8,
        b: []const u8,
        want: i32,
    }{
        .{
            .name = "numeric runs sort by numeric value",
            .a = "a2",
            .b = "a100",
            .want = -1,
        },
        .{
            .name = "numeric runs ignore leading zeros",
            .a = "a02",
            .b = "a2",
            .want = 0,
        },
        .{
            .name = "longer sequence is larger",
            .a = "a2b",
            .b = "a2",
            .want = 1,
        },
        .{
            .name = "accents",
            .a = "À",
            .b = "B",
            .want = -1,
        },
        .{
            .name = "accents 2",
            .a = "A",
            .b = "À",
            .want = -1,
        },
        .{
            .name = "punctuation",
            .a = "app-init",
            .b = "app/app",
            .want = -1,
        },
    };

    for (tests) |tt| {
        const got = comparer(tt.a, tt.b);
        try std.testing.expectEqual(tt.want, got);
    }
}
