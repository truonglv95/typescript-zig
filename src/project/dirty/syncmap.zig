const std = @import("std");

pub fn SyncMapEntry(comptime K: type, comptime V: type) type {
    return struct {
        mu: std.Thread.Mutex = .{},
        key: K,
        original: ?V = null,
        value: V,
        dirty: bool = false,
        is_delete: bool = false,
    };
}

pub fn SyncMap(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();
        const Entry = SyncMapEntry(K, V);
        
        allocator: std.mem.Allocator,
        base: std.AutoHashMap(K, V),
        dirty: std.AutoHashMap(K, *Entry),
        dirty_mu: std.Thread.RwLock = .{},
        
        pub fn init(allocator: std.mem.Allocator, base: std.AutoHashMap(K, V)) Self {
            return .{
                .allocator = allocator,
                .base = base,
                .dirty = std.AutoHashMap(K, *Entry).init(allocator),
            };
        }

        pub fn load(self: *Self, key: K) ?*Entry {
            self.dirty_mu.lockShared();
            if (self.dirty.get(key)) |entry| {
                self.dirty_mu.unlockShared();
                entry.mu.lock();
                defer entry.mu.unlock();
                if (entry.is_delete) return null;
                return entry;
            }
            self.dirty_mu.unlockShared();

            if (self.base.get(key)) |value| {
                var entry = self.allocator.create(Entry) catch @panic("OOM");
                entry.* = .{
                    .key = key,
                    .original = value,
                    .value = value,
                };
                return entry;
            }
            return null;
        }

        pub fn finalize(self: *Self) !struct { std.AutoHashMap(K, V), bool } {
            self.dirty_mu.lockShared();
            defer self.dirty_mu.unlockShared();

            if (self.dirty.count() == 0) {
                return .{ self.base, false };
            }
            var result = std.AutoHashMap(K, V).init(self.allocator);
            var base_it = self.base.iterator();
            while (base_it.next()) |b| {
                try result.put(b.key_ptr.*, b.value_ptr.*);
            }
            
            var dirty_it = self.dirty.iterator();
            while (dirty_it.next()) |d| {
                const entry = d.value_ptr.*;
                entry.mu.lock();
                if (entry.is_delete) {
                    _ = result.remove(entry.key);
                } else if (entry.dirty) {
                    try result.put(entry.key, entry.value);
                }
                entry.mu.unlock();
            }
            return .{ result, true };
        }
    };
}
