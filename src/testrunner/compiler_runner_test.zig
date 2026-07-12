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
    defer {
        for (runners.items) |runner| {
            runner.deinit();
        }
    }

    var pass_count: usize = 0;
    var fail_count: usize = 0;

    for (runners.items) |runner| {
        const files = try runner.EnumerateTestFiles();
        for (files) |file| {
            const baseFile = tspath.GetBaseFileName(file);
            // Run all test files
            runner.runTest(file) catch |err| {
                std.debug.print("TEST FAILED: {s} with error {}\n", .{ baseFile, err });
                fail_count += 1;
                continue;
            };
            pass_count += 1;
        }
    }
    std.debug.print("\n=== COMPILER TEST RESULTS ===\n", .{});
    std.debug.print("Passed: {}\n", .{pass_count});
    std.debug.print("Failed: {}\n", .{fail_count});

    if (fail_count > 0) {
        return error.TestsFailed;
    }
}
