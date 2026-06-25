const std = @import("std");

pub const Queue = struct {
    wg: std.Thread.WaitGroup = .{},
    mu: std.Thread.RwLock = .{},
    closed: bool = false,

    pub fn init() Queue {
        return .{};
    }

    pub fn enqueue(self: *Queue, ctx: *anyopaque, fnPtr: *const fn(*anyopaque) void) void {
        self.mu.lockShared();
        if (self.closed) {
            self.mu.unlockShared();
            return;
        }
        self.mu.unlockShared();

        // Start wg counter
        self.wg.start();
        
        // Spawn thread
        const thread = std.Thread.spawn(.{}, struct {
            fn run(wg: *std.Thread.WaitGroup, f: *const fn(*anyopaque) void, c: *anyopaque) void {
                defer wg.finish();
                f(c);
            }
        }.run, .{&self.wg, fnPtr, ctx}) catch {
            self.wg.finish();
            return;
        };
        thread.detach();
    }

    pub fn wait(self: *Queue) void {
        self.wg.wait();
    }

    pub fn close(self: *Queue) void {
        self.mu.lock();
        self.closed = true;
        self.mu.unlock();
    }
};
