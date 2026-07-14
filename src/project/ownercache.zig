const std = @import("std");

pub fn OwnerCacheEntry(comptime V: type) type {
    return struct {
        mu: std.Thread.Mutex = .{},
        value: V,
        owners: std.AutoHashMap(u64, void),
    };
}

pub fn OwnerCache(comptime K: type, comptime V: type, comptime LoadArgs: type) type {
    return struct {
        const Self = @This();
        const Entry = OwnerCacheEntry(V);

        entries: std.AutoHashMap(K, *Entry),
        mu: std.Thread.Mutex = .{},
        allocator: std.mem.Allocator,

        isExpiredFn: ?*const fn (K, V, LoadArgs) bool,
        parseFn: *const fn (K, LoadArgs) V,

        pub fn init(allocator: std.mem.Allocator, parseFn: *const fn (K, LoadArgs) V, isExpiredFn: ?*const fn (K, V, LoadArgs) bool) Self {
            return .{
                .entries = std.AutoHashMap(K, *Entry).init(allocator),
                .allocator = allocator,
                .isExpiredFn = isExpiredFn,
                .parseFn = parseFn,
            };
        }

        pub fn loadAndAcquire(self: *Self, identity: K, owner: u64, loadArgs: LoadArgs) V {
            self.mu.lock();
            const res = self.entries.getOrPut(identity) catch @panic("OOM");
            var entry: *Entry = undefined;
            if (!res.found_existing) {
                entry = self.allocator.create(Entry) catch @panic("OOM");
                entry.* = .{
                    .value = undefined,
                    .owners = std.AutoHashMap(u64, void).init(self.allocator),
                };
                res.value_ptr.* = entry;
                
                entry.mu.lock();
                self.mu.unlock();
                
                entry.value = self.parseFn(identity, loadArgs);
                entry.owners.put(owner, {}) catch @panic("OOM");
                entry.mu.unlock();
                return entry.value;
            } else {
                entry = res.value_ptr.*;
                entry.mu.lock();
                self.mu.unlock();
                
                if (entry.owners.count() == 0) {
                    entry.mu.unlock();
                    return self.loadAndAcquire(identity, owner, loadArgs);
                }
                
                if (self.isExpiredFn) |isExpired| {
                    if (isExpired(identity, entry.value, loadArgs)) {
                        entry.value = self.parseFn(identity, loadArgs);
                    }
                }
                
                entry.owners.put(owner, {}) catch @panic("OOM");
                entry.mu.unlock();
                return entry.value;
            }
        }

        pub fn release(self: *Self, identity: K, owner: u64) void {
            self.mu.lock();
            if (self.entries.get(identity)) |entry| {
                entry.mu.lock();
                _ = entry.owners.remove(owner);
                if (entry.owners.count() == 0) {
                    _ = self.entries.remove(identity);
                }
                entry.mu.unlock();
            }
            self.mu.unlock();
        }
    };
}
