const std = @import("std");
const repo = @import("../../repo/paths.zig");
const filefixture = @import("../filefixture/filefixture.zig");

pub fn getBenchFixtures(allocator: std.mem.Allocator) ![]filefixture.Fixture {
    const ts_path = try repo.typeScriptSubmodulePath(allocator);

    var fixtures = std.ArrayList(filefixture.Fixture).init(allocator);
    errdefer fixtures.deinit();

    try fixtures.append(filefixture.fromString("empty.ts", "empty.ts", ""));

    {
        const path = try std.fs.path.join(allocator, &[_][]const u8{ ts_path, "src/compiler/checker.ts" });
        try fixtures.append(filefixture.fromFile("checker.ts", path));
    }

    {
        const path = try std.fs.path.join(allocator, &[_][]const u8{ ts_path, "src/lib/dom.generated.d.ts" });
        try fixtures.append(filefixture.fromFile("dom.generated.d.ts", path));
    }

    {
        const path = try std.fs.path.join(allocator, &[_][]const u8{ ts_path, "Herebyfile.mjs" });
        try fixtures.append(filefixture.fromFile("Herebyfile.mjs", path));
    }

    {
        const path = try std.fs.path.join(allocator, &[_][]const u8{ ts_path, "tests/cases/compiler/jsxComplexSignatureHasApplicabilityError.tsx" });
        try fixtures.append(filefixture.fromFile("jsxComplexSignatureHasApplicabilityError.tsx", path));
    }

    return fixtures.toOwnedSlice();
}
