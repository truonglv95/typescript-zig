const std = @import("std");
const testing = std.testing;

const diagnostics = @import("../diagnostics/diagnostics.zig");
const progress = @import("progress.zig");

const ProgressCall = struct {
    method: []const u8,
    token: []const u8,
    title: []const u8 = "",
    msg: []const u8 = "",
};

const FakeProgressReporter = struct {
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex = .{},
    calls: std.ArrayList(ProgressCall),
    is_done: bool = false,

    pub fn init(allocator: std.mem.Allocator) FakeProgressReporter {
        return .{
            .allocator = allocator,
            .calls = std.ArrayList(ProgressCall).init(allocator),
        };
    }

    pub fn deinit(self: *FakeProgressReporter) void {
        for (self.calls.items) |call| {
            self.allocator.free(call.method);
            self.allocator.free(call.token);
            self.allocator.free(call.title);
            self.allocator.free(call.msg);
        }
        self.calls.deinit();
    }

    pub fn getReporter(self: *FakeProgressReporter) progress.ProgressReporter {
        return .{
            .ptr = self,
            .vtable = &.{
                .isDone = isDone,
                .createWorkDoneProgress = createWorkDoneProgress,
                .sendProgressBegin = sendProgressBegin,
                .sendProgressReport = sendProgressReport,
                .sendProgressEnd = sendProgressEnd,
            },
        };
    }

    pub fn done(self: *FakeProgressReporter) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.is_done = true;
    }

    pub fn getCalls(self: *FakeProgressReporter) ![]ProgressCall {
        self.mutex.lock();
        defer self.mutex.unlock();
        const clone = try self.allocator.alloc(ProgressCall, self.calls.items.len);
        for (self.calls.items, 0..) |item, i| {
            clone[i] = .{
                .method = try self.allocator.dupe(u8, item.method),
                .token = try self.allocator.dupe(u8, item.token),
                .title = try self.allocator.dupe(u8, item.title),
                .msg = try self.allocator.dupe(u8, item.msg),
            };
        }
        return clone;
    }

    pub fn freeCalls(self: *FakeProgressReporter, calls_array: []ProgressCall) void {
        for (calls_array) |call| {
            self.allocator.free(call.method);
            self.allocator.free(call.token);
            self.allocator.free(call.title);
            self.allocator.free(call.msg);
        }
        self.allocator.free(calls_array);
    }

    fn isDone(ptr: *anyopaque) bool {
        const self: *FakeProgressReporter = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.is_done;
    }

    fn createWorkDoneProgress(ptr: *anyopaque, token: []const u8) void {
        const self: *FakeProgressReporter = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();
        self.calls.append(.{
            .method = self.allocator.dupe(u8, "create") catch unreachable,
            .token = self.allocator.dupe(u8, token) catch unreachable,
        }) catch unreachable;
    }

    fn sendProgressBegin(ptr: *anyopaque, token: []const u8, title: []const u8, message: []const u8) void {
        const self: *FakeProgressReporter = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();
        self.calls.append(.{
            .method = self.allocator.dupe(u8, "begin") catch unreachable,
            .token = self.allocator.dupe(u8, token) catch unreachable,
            .title = self.allocator.dupe(u8, title) catch unreachable,
            .msg = self.allocator.dupe(u8, message) catch unreachable,
        }) catch unreachable;
    }

    fn sendProgressReport(ptr: *anyopaque, token: []const u8, message: []const u8) void {
        const self: *FakeProgressReporter = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();
        self.calls.append(.{
            .method = self.allocator.dupe(u8, "report") catch unreachable,
            .token = self.allocator.dupe(u8, token) catch unreachable,
            .msg = self.allocator.dupe(u8, message) catch unreachable,
        }) catch unreachable;
    }

    fn sendProgressEnd(ptr: *anyopaque, token: []const u8) void {
        const self: *FakeProgressReporter = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();
        self.calls.append(.{
            .method = self.allocator.dupe(u8, "end") catch unreachable,
            .token = self.allocator.dupe(u8, token) catch unreachable,
        }) catch unreachable;
    }
};

test "StartFinishBeforeDelay" {
    var reporter = FakeProgressReporter.init(testing.allocator);
    defer reporter.deinit();

    var p = try progress.ProjectLoadingProgress.init(testing.allocator, reporter.getReporter(), 100);
    defer p.deinit();

    try p.start("myProject");
    try p.finish("myProject");

    std.time.sleep(200 * std.time.ns_per_ms);

    const calls = try reporter.getCalls();
    defer reporter.freeCalls(calls);

    try testing.expectEqual(@as(usize, 0), calls.len);
}

test "ShowsAfterDelay" {
    var reporter = FakeProgressReporter.init(testing.allocator);
    defer reporter.deinit();

    var p = try progress.ProjectLoadingProgress.init(testing.allocator, reporter.getReporter(), 50);
    defer p.deinit();

    try p.start("myProject");

    std.time.sleep(100 * std.time.ns_per_ms);

    const calls1 = try reporter.getCalls();
    defer reporter.freeCalls(calls1);

    try testing.expectEqual(@as(usize, 2), calls1.len);
    try testing.expectEqualStrings("create", calls1[0].method);
    try testing.expectEqualStrings("begin", calls1[1].method);

    try p.finish("myProject");

    // Wait slightly to let the event loop process finish.
    std.time.sleep(10 * std.time.ns_per_ms);

    const calls2 = try reporter.getCalls();
    defer reporter.freeCalls(calls2);

    try testing.expectEqualStrings("end", calls2[calls2.len - 1].method);
}

test "ReportsMultipleOperations" {
    var reporter = FakeProgressReporter.init(testing.allocator);
    defer reporter.deinit();

    var p = try progress.ProjectLoadingProgress.init(testing.allocator, reporter.getReporter(), 50);
    defer p.deinit();

    try p.start("projA");
    try p.start("projB");

    std.time.sleep(100 * std.time.ns_per_ms);

    const calls1 = try reporter.getCalls();
    defer reporter.freeCalls(calls1);

    try testing.expect(calls1.len >= 2);
    try testing.expectEqualStrings("create", calls1[0].method);
    try testing.expectEqualStrings("begin", calls1[1].method);

    try p.finish("projA");
    std.time.sleep(10 * std.time.ns_per_ms);

    const calls2 = try reporter.getCalls();
    defer reporter.freeCalls(calls2);

    var found_report = false;
    for (calls2) |c| {
        if (std.mem.eql(u8, c.method, "report")) found_report = true;
    }
    try testing.expect(found_report);

    try p.finish("projB");
    std.time.sleep(10 * std.time.ns_per_ms);

    const calls3 = try reporter.getCalls();
    defer reporter.freeCalls(calls3);
    try testing.expectEqualStrings("end", calls3[calls3.len - 1].method);
}

test "RefCounting" {
    var reporter = FakeProgressReporter.init(testing.allocator);
    defer reporter.deinit();

    var p = try progress.ProjectLoadingProgress.init(testing.allocator, reporter.getReporter(), 50);
    defer p.deinit();

    try p.start("proj");
    try p.start("proj");

    std.time.sleep(100 * std.time.ns_per_ms);

    try p.finish("proj");
    std.time.sleep(10 * std.time.ns_per_ms);

    const calls1 = try reporter.getCalls();
    defer reporter.freeCalls(calls1);
    for (calls1) |c| {
        try testing.expect(!std.mem.eql(u8, c.method, "end"));
    }

    try p.finish("proj");
    std.time.sleep(10 * std.time.ns_per_ms);

    const calls2 = try reporter.getCalls();
    defer reporter.freeCalls(calls2);
    try testing.expectEqualStrings("end", calls2[calls2.len - 1].method);
}

test "NewTokenAfterEnd" {
    var reporter = FakeProgressReporter.init(testing.allocator);
    defer reporter.deinit();

    var p = try progress.ProjectLoadingProgress.init(testing.allocator, reporter.getReporter(), 50);
    defer p.deinit();

    try p.start("proj");
    std.time.sleep(100 * std.time.ns_per_ms);

    const calls1 = try reporter.getCalls();
    const first_token = try testing.allocator.dupe(u8, calls1[0].token);
    defer testing.allocator.free(first_token);
    reporter.freeCalls(calls1);

    try p.finish("proj");
    std.time.sleep(10 * std.time.ns_per_ms);

    try p.start("proj2");
    std.time.sleep(100 * std.time.ns_per_ms);

    const calls2 = try reporter.getCalls();
    defer reporter.freeCalls(calls2);

    var second_token: ?[]const u8 = null;
    for (calls2) |c| {
        if (std.mem.eql(u8, c.method, "create") and !std.mem.eql(u8, c.token, first_token)) {
            second_token = c.token;
            break;
        }
    }
    try testing.expect(second_token != null);

    try p.finish("proj2");
}

test "StartBeforeDelayThenMoreAfterDelay" {
    var reporter = FakeProgressReporter.init(testing.allocator);
    defer reporter.deinit();

    var p = try progress.ProjectLoadingProgress.init(testing.allocator, reporter.getReporter(), 50);
    defer p.deinit();

    try p.start("projA");
    std.time.sleep(100 * std.time.ns_per_ms);

    try p.start("projB");
    std.time.sleep(10 * std.time.ns_per_ms);

    const calls1 = try reporter.getCalls();
    defer reporter.freeCalls(calls1);
    try testing.expectEqualStrings("report", calls1[calls1.len - 1].method);

    try p.finish("projA");
    try p.finish("projB");
}

test "FinishWithNoActiveToken" {
    var reporter = FakeProgressReporter.init(testing.allocator);
    defer reporter.deinit();

    var p = try progress.ProjectLoadingProgress.init(testing.allocator, reporter.getReporter(), 50);
    defer p.deinit();

    try p.finish("proj");
    std.time.sleep(10 * std.time.ns_per_ms);

    const calls = try reporter.getCalls();
    defer reporter.freeCalls(calls);
    try testing.expectEqual(@as(usize, 0), calls.len);
}

test "ShutdownDuringStartAndFinish" {
    var reporter = FakeProgressReporter.init(testing.allocator);
    reporter.done();

    var p = try progress.ProjectLoadingProgress.init(testing.allocator, reporter.getReporter(), 50);

    try p.start("proj");
    try p.finish("proj");

    p.deinit();
}

test "ZeroDelay" {
    var reporter = FakeProgressReporter.init(testing.allocator);
    defer reporter.deinit();

    var p = try progress.ProjectLoadingProgress.init(testing.allocator, reporter.getReporter(), 0);
    defer p.deinit();

    try p.start("proj");
    std.time.sleep(10 * std.time.ns_per_ms);

    const calls1 = try reporter.getCalls();
    defer reporter.freeCalls(calls1);
    try testing.expectEqual(@as(usize, 2), calls1.len);
    try testing.expectEqualStrings("create", calls1[0].method);
    try testing.expectEqualStrings("begin", calls1[1].method);

    try p.finish("proj");
    std.time.sleep(10 * std.time.ns_per_ms);

    const calls2 = try reporter.getCalls();
    defer reporter.freeCalls(calls2);
    try testing.expectEqualStrings("end", calls2[calls2.len - 1].method);
}

test "FinishBeforeDelayNoBegun" {
    var reporter = FakeProgressReporter.init(testing.allocator);
    defer reporter.deinit();

    var p = try progress.ProjectLoadingProgress.init(testing.allocator, reporter.getReporter(), 100);
    defer p.deinit();

    try p.start("proj");
    try p.finish("proj");

    std.time.sleep(150 * std.time.ns_per_ms);

    const calls = try reporter.getCalls();
    defer reporter.freeCalls(calls);
    for (calls) |c| {
        try testing.expect(!std.mem.eql(u8, c.method, "end"));
    }
}
