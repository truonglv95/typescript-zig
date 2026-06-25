const std = @import("std");
const bundled = @import("../bundled/bundled.zig");
const collections = @import("../collections/collections.zig");
const repo = @import("../repo/repo.zig");
const tspath = @import("../tspath/tspath.zig");
const testrunner = @import("compiler_runner.zig");

const assert = std.debug.assert;

// Runs the new compiler tests and produces baselines (e.g. `test1.symbols`).
test "Local" {
    try runCompilerTests(std.testing.allocator, false);
}

// Runs the old compiler tests, and produces new baselines (e.g. `test1.symbols`)
// and a diff between the new and old baselines (e.g. `test1.symbols.diff`).
test "Submodule" {
    try runCompilerTests(std.testing.allocator, true);
}

fn runCompilerTests(allocator: std.mem.Allocator, isSubmodule: bool) !void {
    if (isSubmodule) {
        try repo.SkipIfNoTypeScriptSubmodule();
    }

    if (!bundled.Embedded) {
        // Without embedding, we'd need to read all of the lib files out from disk into the MapFS.
        // Just skip this for now.
        return error.Skip; // "bundled files are not embedded"
    }

    var runners = std.ArrayList(*testrunner.CompilerBaselineRunner).empty;
    defer runners.deinit(allocator);

    try runners.append(allocator, try testrunner.CompilerBaselineRunner.init(allocator, .Regression, isSubmodule));
    try runners.append(allocator, try testrunner.CompilerBaselineRunner.init(allocator, .Conformance, isSubmodule));

    var seenTests = std.StringHashMap(void).init(allocator);
    defer seenTests.deinit();

    for (runners.items) |runner| {
        const files = try runner.EnumerateTestFiles();
        for (files) |file| {
            const baseFile = tspath.GetBaseFileName(file);
            assert(!seenTests.contains(baseFile)); // Duplicate test file
            try seenTests.put(baseFile, {});
        }
    }

    for (runners.items) |runner| {
        try runner.RunTests();
    }
    for (runners.items) |runner| {
        runner.deinit();
    }
}
