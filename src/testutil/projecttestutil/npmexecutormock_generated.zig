const std = @import("std");
const ata = @import("../../project/ata/ata.zig");

pub const NpmExecutorMock = struct {
    allocator: std.mem.Allocator,
    
    // We use a context and function pointer for the mock function
    ctx: ?*anyopaque = null,
    npmInstallFunc: ?*const fn(ctx: ?*anyopaque, cwd: []const u8, args: []const []const u8) anyerror![]u8 = null,

    calls: struct {
        npmInstall: std.ArrayList(Call),
    },

    pub const Call = struct {
        cwd: []const u8,
        args: []const []const u8,
    };
    


    pub fn init(allocator: std.mem.Allocator) NpmExecutorMock {
        return .{
            .allocator = allocator,
            .calls = .{
                .npmInstall = std.ArrayList(Call).empty,
            },
        };
    }

    pub fn deinit(self: *NpmExecutorMock) void {
        self.calls.npmInstall.deinit();
    }

    pub fn npmInstall(self: *NpmExecutorMock, cwd: []const u8, args: []const []const u8) ![]u8 {
        try self.calls.npmInstall.append(.{
            .cwd = cwd,
            .args = args,
        });

        if (self.npmInstallFunc) |f| {
            return f(self.ctx, cwd, args);
        }
        return &[_]u8{};
    }

    pub fn npmInstallCalls(self: *NpmExecutorMock) []const Call {
        return self.calls.npmInstall.items;
    }
};
