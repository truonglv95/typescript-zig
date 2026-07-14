const std = @import("std");

pub const RefCountCacheOptions = struct {
    disableDeletion: bool = false,
};

pub fn RefCountCacheEntry(comptime V: type) type {
    return struct {
        mu: std.Thread.Mutex = .{},
        value: V,
        refCount: i32,
    };
}

pub fn RefCountCache(comptime K: type, comptime V: type, comptime AcquireArgs: type) type {
    return struct {
        const Self = @This();
        const Entry = RefCountCacheEntry(V);

        options: RefCountCacheOptions,
        entries: std.AutoHashMap(K, *Entry),
        mu: std.Thread.Mutex = .{},
        allocator: std.mem.Allocator,
        parseFn: *const fn (K, AcquireArgs) V,

        pub fn init(allocator: std.mem.Allocator, options: RefCountCacheOptions, parseFn: *const fn (K, AcquireArgs) V) Self {
            return .{
                .options = options,
                .entries = std.AutoHashMap(K, *Entry).init(allocator),
                .allocator = allocator,
                .parseFn = parseFn,
            };
        }

        pub fn acquire(self: *Self, identity: K, acquireArgs: AcquireArgs) V {
            self.mu.lock();
            const res = self.entries.getOrPut(identity) catch @panic("OOM");
            var entry: *Entry = undefined;
            if (!res.found_existing) {
                entry = self.allocator.create(Entry) catch @panic("OOM");
                entry.* = .{
                    .value = undefined,
                    .refCount = 1,
                };
                res.value_ptr.* = entry;
                
                entry.mu.lock();
                self.mu.unlock();
                
                entry.value = self.parseFn(identity, acquireArgs);
                entry.mu.unlock();
                return entry.value;
            } else {
                entry = res.value_ptr.*;
                entry.mu.lock();
                self.mu.unlock();
                
                if (entry.refCount <= 0 and !self.options.disableDeletion) {
                    entry.mu.unlock();
                    return self.acquire(identity, acquireArgs);
                }
                entry.refCount += 1;
                entry.mu.unlock();
                return entry.value;
            }
        }

        pub fn deref(self: *Self, identity: K) void {
            self.mu.lock();
            if (self.entries.get(identity)) |entry| {
                entry.mu.lock();
                entry.refCount -= 1;
                if (entry.refCount <= 0 and !self.options.disableDeletion) {
                    _ = self.entries.remove(identity);
                    entry.mu.unlock();
                } else {
                    entry.mu.unlock();
                }
            } else {
                self.mu.unlock();
            }
        }
    };
}
