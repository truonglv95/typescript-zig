const std = @import("std");

pub fn DynamicQueue(comptime T: type) type {
    return struct {
        items: std.ArrayListUnmanaged(T),
        mutex: std.Thread.Mutex,
        cond: std.Thread.Condition,

        const Self = @This();

        pub fn init() Self {
            return .{
                .items = .empty,
                .mutex = .{},
                .cond = .{},
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.items.deinit(allocator);
        }

        pub fn put(self: *Self, allocator: std.mem.Allocator, item: T, cancel_flag: *const std.atomic.Value(bool)) !void {
            if (cancel_flag.load(.seq_cst)) {
                return error.Canceled;
            }

            self.mutex.lock();
            defer self.mutex.unlock();

            try self.items.append(allocator, item);
            self.cond.signal();
        }

        pub fn get(self: *Self, cancel_flag: *const std.atomic.Value(bool)) !T {
            if (cancel_flag.load(.seq_cst)) {
                return error.Canceled;
            }

            self.mutex.lock();
            defer self.mutex.unlock();

            while (self.items.items.len == 0) {
                if (cancel_flag.load(.seq_cst)) {
                    return error.Canceled;
                }
                // Wake up every 10ms to check for cancellation
                _ = self.cond.timedWait(&self.mutex, 10 * std.time.ns_per_ms) catch {};
            }

            return self.items.orderedRemove(0);
        }
    };
}

const testing = std.testing;

test "DynamicQueue FIFO" {
    var queue = DynamicQueue(usize).init();
    defer queue.deinit(testing.allocator);

    const cancel_flag = std.atomic.Value(bool).init(false);

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        try queue.put(testing.allocator, i, &cancel_flag);
    }

    i = 0;
    while (i < 1000) : (i += 1) {
        const got = try queue.get(&cancel_flag);
        try testing.expectEqual(i, got);
    }
}

test "DynamicQueue Get cancellation" {
    var queue = DynamicQueue(usize).init();
    defer queue.deinit(testing.allocator);

    var cancel_flag = std.atomic.Value(bool).init(true);

    const result = queue.get(&cancel_flag);
    try testing.expectError(error.Canceled, result);
}

test "DynamicQueue Put cancellation while state unavailable" {
    var queue = DynamicQueue(usize).init();
    defer queue.deinit(testing.allocator);

    // Lock the mutex manually to simulate state unavailable.
    queue.mutex.lock();

    var cancel_flag = std.atomic.Value(bool).init(true);

    const put_result = queue.put(testing.allocator, 1, &cancel_flag);
    try testing.expectError(error.Canceled, put_result);

    queue.mutex.unlock();
    cancel_flag.store(false, .seq_cst);

    try queue.put(testing.allocator, 2, &cancel_flag);
    const got = try queue.get(&cancel_flag);
    try testing.expectEqual(@as(usize, 2), got);
}
