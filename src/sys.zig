const std = @import("std");
const system = @import("execute/system.zig");

pub const OsSystem = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) OsSystem {
        return .{
            .allocator = allocator,
        };
    }

    pub fn sys(self: *OsSystem) system.System {
        return .{
            .context = self,
            .writerFn = writerFn,
            .defaultLibraryPathFn = defaultLibraryPathFn,
            .getCurrentDirectoryFn = getCurrentDirectoryFn,
            .writeOutputIsTTYFn = writeOutputIsTTYFn,
            .getWidthOfTerminalFn = getWidthOfTerminalFn,
            .getEnvironmentVariableFn = getEnvironmentVariableFn,
            .nowFn = nowFn,
            .sinceStartFn = sinceStartFn,
        };
    }

    fn writerFn(ctx: *anyopaque) *anyopaque {
        _ = ctx;
        return undefined;
    }

    fn defaultLibraryPathFn(ctx: *anyopaque) []const u8 {
        _ = ctx;
        return "";
    }

    fn getCurrentDirectoryFn(ctx: *anyopaque) []const u8 {
        _ = ctx;
        return ".";
    }

    fn writeOutputIsTTYFn(ctx: *anyopaque) bool {
        _ = ctx;
        return false;
    }

    fn getWidthOfTerminalFn(ctx: *anyopaque) usize {
        _ = ctx;
        return 80;
    }

    fn getEnvironmentVariableFn(ctx: *anyopaque, name: []const u8) ?[]const u8 {
        _ = ctx;
        _ = name;
        return null;
    }

    fn nowFn(ctx: *anyopaque) i64 {
        _ = ctx;
        return 0;
    }

    fn sinceStartFn(ctx: *anyopaque) i64 {
        _ = ctx;
        return 0;
    }
};
