const std = @import("std");
const tsc = @import("tsc");
const OsSystem = tsc.sys_pkg.OsSystem;

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();

    var iterator = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer iterator.deinit();
    _ = iterator.next() orelse "tsc"; // executable name

    var raw_args = std.ArrayList([]const u8).empty;
    while (iterator.next()) |arg| try raw_args.append(allocator, arg);

    if (raw_args.items.len == 0) {
        std.debug.print("Version 0.1.0\nUsage: tsc [options] <files...>\n", .{});
        return;
    }

    var os_sys = OsSystem.init(allocator);
    var sys = os_sys.sys();

    const result = tsc.execute.tsc.commandLine(&os_sys, &sys, raw_args.items, null);
    switch (result.status) {
        .Success => {},
        .DiagnosticsPresent_OutputsSkipped, .DiagnosticsPresent_OutputsGenerated => {
            std.process.exit(1);
        },
        .NotImplemented => {
            std.debug.print("Command not implemented.\n", .{});
            std.process.exit(1);
        },
    }
}
