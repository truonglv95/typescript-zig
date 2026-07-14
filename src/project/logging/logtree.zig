const std = @import("std");

pub const LogEntry = struct {
    seq: u64,
    time: i64,
    message: []const u8,
    child: ?*LogTree,
};

pub const Mutex = struct {
    pub fn lock(self: *Mutex) void {
        _ = self;
    }
    pub fn unlock(self: *Mutex) void {
        _ = self;
    }
};

pub const LogTree = struct {
    name: []const u8,
    mu: Mutex = .{},
    logs: std.ArrayList(*LogEntry),
    root: *LogTree,
    level: usize = 0,
    verbose: bool = false,

    count: std.atomic.Value(i32) = std.atomic.Value(i32).init(0),
    stringLength: std.atomic.Value(i32) = std.atomic.Value(i32).init(0),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !*LogTree {
        const tree = try allocator.create(LogTree);
        tree.* = .{
            .name = name,
            .logs = std.ArrayList(*LogEntry).empty,
            .root = tree,
            .allocator = allocator,
        };
        return tree;
    }

    pub fn add(self: *LogTree, logEntry: *LogEntry) void {
        _ = self.root.stringLength.fetchAdd(@as(i32, @intCast(self.level + 15 + logEntry.message.len + 1)), .monotonic);
        _ = self.root.count.fetchAdd(1, .monotonic);
        self.mu.lock();
        defer self.mu.unlock();
        self.logs.append(self.allocator, logEntry) catch @panic("OOM");
    }

    pub fn log(self: *LogTree, message: []const u8) void {
        const entry = self.allocator.create(LogEntry) catch @panic("OOM");
        entry.* = .{
            .seq = 0,
            .time = std.time.milliTimestamp(),
            .message = self.allocator.dupe(u8, message) catch @panic("OOM"),
            .child = null,
        };
        self.add(entry);
    }

    pub fn embed(self: *LogTree, logs: *LogTree) void {
        const c = logs.count.load(.monotonic);
        _ = self.root.stringLength.fetchAdd(logs.stringLength.load(.monotonic) + c * @as(i32, @intCast(self.level)), .monotonic);
        _ = self.root.count.fetchAdd(c, .monotonic);
        const entry = self.allocator.create(LogEntry) catch @panic("OOM");
        entry.* = .{
            .seq = 0,
            .time = std.time.milliTimestamp(),
            .message = logs.name,
            .child = logs,
        };
        self.add(entry);
    }

    pub fn fork(self: *LogTree, message: []const u8) !*LogTree {
        const child = try self.allocator.create(LogTree);
        child.* = .{
            .name = message,
            .logs = std.ArrayList(*LogEntry).empty,
            .root = self.root,
            .level = self.level + 1,
            .verbose = self.verbose,
            .allocator = self.allocator,
        };
        const entry = try self.allocator.create(LogEntry);
        entry.* = .{
            .seq = 0,
            .time = 0,
            .message = self.allocator.dupe(u8, message) catch @panic("OOM"),
            .child = child,
        };
        self.add(entry);
        return child;
    }
};
