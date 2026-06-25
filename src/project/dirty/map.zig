const std = @import("std");

pub fn MapEntry(comptime K: type, comptime V: type) type {
    return struct {
        key: K,
        original: ?V = null,
        value: V,
        dirty: bool = false,
        is_delete: bool = false,
    };
}

pub fn Map(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();
        const Entry = MapEntry(K, V);
        
        allocator: std.mem.Allocator,
        base: std.AutoHashMap(K, V),
        dirty: std.AutoHashMap(K, *Entry),
        
        pub fn init(allocator: std.mem.Allocator, base: std.AutoHashMap(K, V)) Self {
            return .{
                .allocator = allocator,
                .base = base,
                .dirty = std.AutoHashMap(K, *Entry).init(allocator),
            };
        }

        pub fn get(self: *Self, key: K) ?*Entry {
            if (self.dirty.get(key)) |entry| {
                if (entry.is_delete) return null;
                return entry;
            }
            if (self.base.get(key)) |value| {
                const entry = self.allocator.create(Entry) catch @panic("OOM");
                entry.* = .{
                    .key = key,
                    .original = value,
                    .value = value,
                    .dirty = false,
                };
                return entry;
            }
            return null;
        }

        pub fn add(self: *Self, key: K, value: V) void {
            const entry = self.allocator.create(Entry) catch @panic("OOM");
            entry.* = .{
                .key = key,
                .value = value,
                .dirty = true,
            };
            self.dirty.put(key, entry) catch @panic("OOM");
        }

        pub fn finalize(self: *Self) !struct { std.AutoHashMap(K, V), bool } {
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
                if (entry.is_delete) {
                    _ = result.remove(entry.key);
                } else {
                    try result.put(entry.key, entry.value);
                }
            }
            return .{ result, true };
        }
    };
}
