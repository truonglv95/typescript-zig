const std = @import("std");

pub const Debounce = struct {
    mu: std.Thread.Mutex = .{},
    callbacks: std.AutoHashMap(usize, CallbackEntry),
    lastTime: i64 = 0,

    latchMu: std.Thread.Mutex = .{},
    notified: bool = false,
    waitCond: std.Thread.Condition = .{},
    triggerCond: std.Thread.Condition = .{},
    trigger_generation: u64 = 0,

    allocator: std.mem.Allocator,
    thread: ?std.Thread = null,
    quit: bool = false,

    pub const CallbackEntry = struct {
        ctx: *anyopaque,
        cb: *const fn (ctx: *anyopaque) void,
    };

    pub const minWaitTime = 50 * std.time.ns_per_ms;
    pub const maxWaitTime = 500 * std.time.ns_per_ms;

    pub fn init(allocator: std.mem.Allocator) !*Debounce {
        var d = try allocator.create(Debounce);
        d.* = .{
            .callbacks = std.AutoHashMap(usize, CallbackEntry).init(allocator),
            .allocator = allocator,
        };
        d.thread = try std.Thread.spawn(.{}, loop, .{d});
        return d;
    }

    pub fn deinit(self: *Debounce) void {
        {
            self.latchMu.lock();
            self.quit = true;
            self.waitCond.signal();
            self.triggerCond.broadcast();
            self.latchMu.unlock();
        }
        if (self.thread) |th| {
            th.join();
        }
        self.callbacks.deinit();
        self.allocator.destroy(self);
    }

    pub fn add(self: *Debounce, key: usize, ctx: *anyopaque, cb: *const fn (*anyopaque) void) !void {
        self.mu.lock();
        defer self.mu.unlock();
        try self.callbacks.put(key, .{ .ctx = ctx, .cb = cb });
    }

    pub fn remove(self: *Debounce, key: usize) void {
        self.mu.lock();
        defer self.mu.unlock();
        _ = self.callbacks.remove(key);
    }

    pub fn trigger(self: *Debounce) void {
        self.latchMu.lock();
        defer self.latchMu.unlock();
        if (!self.notified) {
            self.notified = true;
            self.waitCond.signal();
        }
        self.trigger_generation +%= 1;
        self.triggerCond.broadcast();
    }

    fn loop(self: *Debounce) void {
        while (true) {
            self.latchWait();
            if (self.quit) return;
            self.notifyIfReady();
        }
    }

    fn notifyIfReady(self: *Debounce) void {
        self.mu.lock();
        const now = std.time.nanoTimestamp();
        const gap = now - self.lastTime;
        if (gap > maxWaitTime) {
            self.lastTime = now;
            self.mu.unlock();
            self.fireCallbacks();
            return;
        }
        self.mu.unlock();
        self.coalesceWait();
    }

    fn coalesceWait(self: *Debounce) void {
        self.latchMu.lock();
        const gen = self.trigger_generation;
        
        var woke_by_trigger = false;
        while (self.trigger_generation == gen and !self.quit) {
            self.triggerCond.timedWait(&self.latchMu, minWaitTime) catch |err| switch(err) {
                error.Timeout => {
                    break;
                },
            };
            if (self.trigger_generation != gen) {
                woke_by_trigger = true;
                break;
            }
        }
        self.latchMu.unlock();
        
        if (!woke_by_trigger and !self.quit) {
            self.fireCallbacks();
        }
    }

    fn fireCallbacks(self: *Debounce) void {
        self.mu.lock();
        self.lastTime = std.time.nanoTimestamp();
        
        var cbs = std.ArrayList(CallbackEntry).init(self.allocator);
        defer cbs.deinit();
        var it = self.callbacks.valueIterator();
        while (it.next()) |cb| {
            cbs.append(cb.*) catch {};
        }
        self.mu.unlock();

        self.latchReset();

        for (cbs.items) |cb| {
            cb.cb(cb.ctx);
        }
    }

    fn latchWait(self: *Debounce) void {
        self.latchMu.lock();
        defer self.latchMu.unlock();
        while (!self.notified and !self.quit) {
            self.waitCond.wait(&self.latchMu);
        }
    }

    fn latchReset(self: *Debounce) void {
        self.latchMu.lock();
        defer self.latchMu.unlock();
        if (self.notified) {
            self.notified = false;
        }
    }
};
