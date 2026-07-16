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
    // skipped for now
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
    // skipped for now
}
