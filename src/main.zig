const std = @import("std");
const core = @import("core/core.zig");
const program = @import("compiler/program.zig");
const execute = @import("execute/tsc.zig");
const sys = @import("sys.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var osSys = sys.OsSystem.init(allocator);
    var system = osSys.sys();

    // Setup args
    const argsList: [][]const u8 = &[_][]const u8{};

    const result = execute.commandLine(undefined, &system, argsList, null);
    if (result.status != .Success) {
        std.process.exit(1);
    }
}
