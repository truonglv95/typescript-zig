const std = @import("std");

/// Root path of the typescript-zig project (where build.zig lives).
/// Always returns "." — callers join relative paths from here.
pub fn rootPath(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return ".";
}

/// Path to the nested `microsoft/TypeScript` submodule (the JS test corpus)
/// inside `submodule/typescript-go/_submodules/TypeScript`.
///
/// This submodule is on the `tsgo-port` branch and ships the conformance
/// test cases used by the compiler baseline runner.
pub fn typeScriptSubmodulePath(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return "./submodule/typescript-go/_submodules/TypeScript";
}

/// Path to the typescript-go `testdata/` directory (compiler baselines,
/// fourslash fixtures).
pub fn testDataPath(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return "./submodule/typescript-go/testdata";
}

/// Returns true iff the nested TypeScript submodule has been checked out
/// (i.e., the directory is non-empty). When false, conformance/regression
/// tests that depend on `tests/cases/conformance/` should be skipped.
pub fn typeScriptSubmoduleExists(allocator: std.mem.Allocator) !bool {
    _ = allocator;
    const path = "./submodule/typescript-go/_submodules/TypeScript";
    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch return false;
    defer dir.close();
    var iter = dir.iterate();
    // We need an Io instance for Zig 0.16's API; fall back to assuming
    // exists if the directory opens successfully and has at least one entry.
    // The full iterate API requires an Io param in 0.16, so we use a simpler
    // stat-based check: if the directory contains a `tests/` subdir, it's
    // been checked out.
    var test_dir = std.fs.cwd().openDir("./submodule/typescript-go/_submodules/TypeScript/tests", .{}) catch return false;
    test_dir.close();
    return true;
}

/// Call this at the top of any test that requires the TypeScript submodule.
/// Returns `error.SkipZigTest` when the submodule isn't checked out, so the
/// test is reported as skipped rather than failed.
pub fn SkipIfNoTypeScriptSubmodule() !void {
    const exists = try typeScriptSubmoduleExists(std.heap.page_allocator);
    if (!exists) return error.SkipZigTest;
}
