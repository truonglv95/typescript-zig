const std = @import("std");
const system = @import("execute/system.zig");

pub const OsSystem = struct {
    allocator: std.mem.Allocator,
    cwd: []const u8,

    pub fn init(allocator: std.mem.Allocator) OsSystem {
        const pwd = "/Users/truong/Documents/typescript-zig";
        return .{
            .allocator = allocator,
            .cwd = allocator.dupe(u8, pwd) catch ".",
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
        const self: *OsSystem = @ptrCast(@alignCast(ctx));
        return self.cwd;
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
