const std = @import("std");

pub const Runner = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        enumerateTestFiles: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) anyerror![][]const u8,
        runTests: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) anyerror!void,
    };

    pub fn enumerateTestFiles(self: Runner, allocator: std.mem.Allocator) ![][]const u8 {
        return self.vtable.enumerateTestFiles(self.ptr, allocator);
    }

    pub fn runTests(self: Runner, allocator: std.mem.Allocator) !void {
        return self.vtable.runTests(self.ptr, allocator);
    }
};

pub fn runTests(allocator: std.mem.Allocator, runners: []const Runner) !void {
    for (runners) |runner| {
        try runner.runTests(allocator);
    }
}
