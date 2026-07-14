const std = @import("std");

pub const ProgressReporter = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        isDone: *const fn (ptr: *anyopaque) bool,
        createWorkDoneProgress: *const fn (ptr: *anyopaque, token: []const u8) void,
        sendProgressBegin: *const fn (ptr: *anyopaque, token: []const u8, title: []const u8, message: []const u8) void,
        sendProgressReport: *const fn (ptr: *anyopaque, token: []const u8, message: []const u8) void,
        sendProgressEnd: *const fn (ptr: *anyopaque, token: []const u8) void,
    };

    pub fn isDone(self: ProgressReporter) bool { return self.vtable.isDone(self.ptr); }
    pub fn createWorkDoneProgress(self: ProgressReporter, token: []const u8) void { self.vtable.createWorkDoneProgress(self.ptr, token); }
    pub fn sendProgressBegin(self: ProgressReporter, token: []const u8, title: []const u8, message: []const u8) void { self.vtable.sendProgressBegin(self.ptr, token, title, message); }
    pub fn sendProgressReport(self: ProgressReporter, token: []const u8, message: []const u8) void { self.vtable.sendProgressReport(self.ptr, token, message); }
    pub fn sendProgressEnd(self: ProgressReporter, token: []const u8) void { self.vtable.sendProgressEnd(self.ptr, token); }
};

pub const ProgressEvent = struct {
    message: []const u8,
    finish: bool,
};

pub const ProjectLoadingProgress = struct {
    reporter: ProgressReporter,
    allocator: std.mem.Allocator,
    delay_ms: u64,
    
    mutex: std.Thread.Mutex,
    cond: std.Thread.Condition,
    events: std.ArrayListUnmanaged(ProgressEvent),
    thread: ?std.Thread,

    pub fn init(allocator: std.mem.Allocator, reporter: ProgressReporter, delay_ms: u64) !*ProjectLoadingProgress {
        const self = try allocator.create(ProjectLoadingProgress);
        self.* = .{
            .reporter = reporter,
            .allocator = allocator,
            .delay_ms = delay_ms,
            .mutex = .{},
            .cond = .{},
            .events = .empty,
            .thread = null,
        };
        self.thread = try std.Thread.spawn(.{}, run, .{self});
        return self;
    }

    pub fn deinit(self: *ProjectLoadingProgress) void {
        self.mutex.lock();
        // Wait for thread to exit by checking isDone on reporter
        self.mutex.unlock();
        if (self.thread) |th| {
            th.join();
        }
        self.events.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn start(self: *ProjectLoadingProgress, message: []const u8) !void {
        if (self.reporter.isDone()) return;
        self.mutex.lock();
        defer self.mutex.unlock();
        
        try self.events.append(self.allocator, .{ .message = message, .finish = false });
        self.cond.signal();
    }

    pub fn finish(self: *ProjectLoadingProgress, message: []const u8) !void {
        if (self.reporter.isDone()) return;
        self.mutex.lock();
        defer self.mutex.unlock();
        
        try self.events.append(self.allocator, .{ .message = message, .finish = true });
        self.cond.signal();
    }

    fn run(self: *ProjectLoadingProgress) void {
        var loading = std.StringHashMap(usize).init(self.allocator);
        defer loading.deinit();

        var token: ?[]const u8 = null;
        var token_id: usize = 0;
        var begun = false;
        var delay_fired = false;
        var delay_start: ?i64 = null;

        while (!self.reporter.isDone()) {
            self.mutex.lock();
            while (self.events.items.len == 0 and !self.reporter.isDone()) {
                if (delay_start != null and !delay_fired) {
                    const now = std.time.milliTimestamp();
                    const elapsed = now - delay_start.?;
                    if (elapsed >= self.delay_ms) {
                        break;
                    }
                    _ = self.cond.timedWait(&self.mutex, (self.delay_ms - @as(u64, @intCast(elapsed))) * std.time.ns_per_ms) catch {};
                } else {
                    _ = self.cond.timedWait(&self.mutex, 10 * std.time.ns_per_ms) catch {};
                }
            }
            
            if (self.reporter.isDone()) {
                self.mutex.unlock();
                return;
            }

            var local_events = std.ArrayList(ProgressEvent).init(self.allocator);
            if (self.events.items.len > 0) {
                local_events.appendSlice(self.events.items) catch {};
                self.events.clearRetainingCapacity();
            }
            self.mutex.unlock();

            for (local_events.items) |ev| {
                if (!ev.finish) {
                    const count = loading.get(ev.message) orelse 0;
                    loading.put(ev.message, count + 1) catch {};
                    
                    if (token == null) {
                        token_id += 1;
                        // In a real app we'd format a string, but here we just use static for brevity
                        token = "tsgo-loading-token";
                        begun = false;
                        if (self.delay_ms == 0) {
                            delay_fired = true;
                            self.reporter.createWorkDoneProgress(token.?);
                        } else {
                            delay_fired = false;
                            delay_start = std.time.milliTimestamp();
                        }
                    }
                    
                    if (delay_fired) {
                        begun = self.beginOrReport(token.?, ev.message, begun);
                    }
                } else {
                    const count = loading.get(ev.message) orelse 0;
                    if (count <= 1) {
                        _ = loading.remove(ev.message);
                    } else {
                        loading.put(ev.message, count - 1) catch {};
                    }
                    
                    if (token != null) {
                        if (loading.count() == 0) {
                            if (begun) {
                                self.reporter.sendProgressEnd(token.?);
                            }
                            delay_start = null;
                            token = null;
                        } else if (delay_fired) {
                            var first_key: ?[]const u8 = null;
                            var it = loading.keyIterator();
                            if (it.next()) |key| {
                                first_key = key.*;
                            }
                            if (first_key) |key| {
                                self.reporter.sendProgressReport(token.?, key);
                            }
                        }
                    }
                }
            }
            local_events.deinit();

            // Check timer
            if (token != null and !delay_fired and delay_start != null) {
                const now = std.time.milliTimestamp();
                if (now - delay_start.? >= self.delay_ms) {
                    delay_fired = true;
                    if (loading.count() > 0) {
                        self.reporter.createWorkDoneProgress(token.?);
                        var first_key: ?[]const u8 = null;
                        var it = loading.keyIterator();
                        if (it.next()) |key| {
                            first_key = key.*;
                        }
                        if (first_key) |key| {
                            begun = self.beginOrReport(token.?, key, begun);
                        }
                    }
                }
            }
        }
    }

    fn beginOrReport(self: *ProjectLoadingProgress, token: []const u8, text: []const u8, begun: bool) bool {
        if (!begun) {
            self.reporter.sendProgressBegin(token, "Loading", text);
        } else {
            self.reporter.sendProgressReport(token, text);
        }
        return true;
    }
};

const testing = std.testing;

test "Progress Basic" {
    // Basic test just to ensure no syntax errors
}
