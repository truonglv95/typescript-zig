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
    // Zig 0.16: use linux.openat with O_RDONLY | O_DIRECTORY.
    const path = "./submodule/typescript-go/_submodules/TypeScript/tests";
    const rc = std.os.linux.openat(std.os.linux.AT.FDCWD, path, .{ .ACCMODE = .RDONLY, .DIRECTORY = true }, 0);
    const err = std.os.linux.errno(rc);
    if (err != .SUCCESS) return false;
    _ = std.os.linux.close(@intCast(rc));
    return true;
}

/// Call this at the top of any test that requires the TypeScript submodule.
/// Returns `error.SkipZigTest` when the submodule isn't checked out, so the
/// test is reported as skipped rather than failed.
pub fn SkipIfNoTypeScriptSubmodule() !void {
    const exists = try typeScriptSubmoduleExists(std.heap.page_allocator);
    if (!exists) return error.SkipZigTest;
}
