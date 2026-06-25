const std = @import("std");

pub const Logger = struct {
    ptr: *anyopaque,
    logFn: *const fn(ptr: *anyopaque, msg: []const u8) void,
    verboseFn: *const fn(ptr: *anyopaque) bool,
    
    pub fn log(self: Logger, msg: []const u8) void {
        self.logFn(self.ptr, msg);
    }
    
    pub fn isVerbose(self: Logger) bool {
        return self.verboseFn(self.ptr);
    }
};

pub const StdLogger = struct {
    verbose: bool = false,

    pub fn log(self: *StdLogger, msg: []const u8) void {
        _ = self;
        std.debug.print("[log] {s}\n", .{msg});
    }

    pub fn isVerbose(self: *StdLogger) bool {
        return self.verbose;
    }

    pub fn logger(self: *StdLogger) Logger {
        return .{
            .ptr = self,
            .logFn = struct { fn f(ptr: *anyopaque, m: []const u8) void { @as(*StdLogger, @ptrCast(@alignCast(ptr))).log(m); } }.f,
            .verboseFn = struct { fn f(ptr: *anyopaque) bool { return @as(*StdLogger, @ptrCast(@alignCast(ptr))).isVerbose(); } }.f,
        };
    }
};

pub const TestLogger = struct {
    allocator: std.mem.Allocator,
    logs: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) !*TestLogger {
        const ptr = try allocator.create(TestLogger);
        ptr.* = .{
            .allocator = allocator,
            .logs = std.ArrayList([]const u8).empty,
        };
        return ptr;
    }

    pub fn log(self: *TestLogger, msg: []const u8) void {
        self.logs.append(self.allocator, msg) catch {};
    }

    pub fn isVerbose(self: *const TestLogger) bool {
        _ = self;
        return true;
    }

    pub fn string(self: *TestLogger) []const u8 {
        var builder = std.ArrayList(u8).empty;
        for (self.logs.items) |item| {
            builder.appendSlice(self.allocator, item) catch {};
            builder.append(self.allocator, '\n') catch {};
        }
        return builder.toOwnedSlice(self.allocator) catch "";
    }

    pub fn logger(self: *TestLogger) Logger {
        return .{
            .ptr = self,
            .logFn = struct { fn f(ptr: *anyopaque, m: []const u8) void { @as(*TestLogger, @ptrCast(@alignCast(ptr))).log(m); } }.f,
            .verboseFn = struct { fn f(ptr: *anyopaque) bool { return @as(*const TestLogger, @ptrCast(@alignCast(ptr))).isVerbose(); } }.f,
        };
    }
};
