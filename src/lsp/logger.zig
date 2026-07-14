const std = @import("std");

pub const LogVerbosity = enum(u8) {
    Off = 0,
    Error = 1,
    Warning = 2,
    Info = 3,
    Log = 4,
    Debug = 5,
    Trace = 6,
};

pub const MessageType = enum {
    Error,
    Warning,
    Info,
    Log,
    Debug,
};

fn maxVerbosityForMessageType(msgType: MessageType) LogVerbosity {
    return switch (msgType) {
        .Error => .Error,
        .Warning => .Warning,
        .Info, .Log => .Info,
        .Debug => .Debug,
    };
}

pub const LspLogger = struct {
    server: ?*anyopaque,
    mutex: std.Thread.Mutex,
    verbosity: LogVerbosity,

    const Self = @This();

    pub fn init(server: ?*anyopaque) Self {
        return .{
            .server = server,
            .mutex = .{},
            .verbosity = .Info,
        };
    }

    fn sendLogMessage(self: *Self, msgType: MessageType, message: []const u8) void {
        self.mutex.lock();
        const verbosity = self.verbosity;
        self.mutex.unlock();

        if (verbosity == .Off or @intFromEnum(verbosity) > @intFromEnum(maxVerbosityForMessageType(msgType))) {
            return;
        }

        // Just output to stderr for now
        std.debug.print("{s}: {s}\n", .{ @tagName(msgType), message });
    }

    pub fn log(self: *Self, msg: []const u8) void {
        self.sendLogMessage(.Info, msg);
    }

    pub fn logf(self: *Self, comptime format: []const u8, args: anytype) void {
        var buf: [4096]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, format, args) catch return;
        self.sendLogMessage(.Info, msg);
    }

    pub fn isVerbose(self: *Self) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return @intFromEnum(self.verbosity) >= @intFromEnum(LogVerbosity.Trace) and @intFromEnum(self.verbosity) <= @intFromEnum(LogVerbosity.Debug);
    }

    pub fn setVerbose(self: *Self, verbose: bool) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (verbose) {
            self.verbosity = .Debug;
        } else {
            self.verbosity = .Info;
        }
    }

    pub fn isTracing(self: *Self) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.verbosity == .Trace;
    }

    pub fn setVerbosity(self: *Self, verbosity: LogVerbosity) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.verbosity = verbosity;
    }

    pub fn err(self: *Self, msg: []const u8) void {
        self.sendLogMessage(.Error, msg);
    }

    pub fn errf(self: *Self, comptime format: []const u8, args: anytype) void {
        var buf: [4096]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, format, args) catch return;
        self.sendLogMessage(.Error, msg);
    }

    pub fn warn(self: *Self, msg: []const u8) void {
        self.sendLogMessage(.Warning, msg);
    }

    pub fn warnf(self: *Self, comptime format: []const u8, args: anytype) void {
        var buf: [4096]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, format, args) catch return;
        self.sendLogMessage(.Warning, msg);
    }

    pub fn info(self: *Self, msg: []const u8) void {
        self.sendLogMessage(.Info, msg);
    }

    pub fn infof(self: *Self, comptime format: []const u8, args: anytype) void {
        var buf: [4096]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, format, args) catch return;
        self.sendLogMessage(.Info, msg);
    }
};

const testing = std.testing;

test "LspLogger basic" {
    var logger = LspLogger.init(null);
    logger.setVerbosity(.Debug);
    try testing.expectEqual(true, logger.isVerbose());
    logger.info("Test log");
}
