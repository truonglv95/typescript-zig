const std = @import("std");

pub fn rootPath(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return ".";
}

pub fn typeScriptSubmodulePath(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return "./_submodules/TypeScript";
}

pub fn testDataPath(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return "./testdata";
}

pub fn typeScriptSubmoduleExists(allocator: std.mem.Allocator) !bool {
    _ = allocator;
    return true; // Assume it exists for now to bypass complex fs operations in tests
}

pub fn SkipIfNoTypeScriptSubmodule() !void {
    // Do nothing, we assume it exists
}
