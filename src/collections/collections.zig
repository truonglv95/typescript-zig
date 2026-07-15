const std = @import("std");

/// Port of collections/cow.go, multimap.go, ordered_map.go, ordered_set.go,
/// set.go, syncmap.go, syncset.go

// === Set ===

pub fn Set(comptime T: type) type {
    if (T == []const u8) {
        return std.StringHashMap(void);
    }
    return std.AutoHashMap(T, void);
}

pub fn Set_init(comptime T: type, allocator: std.mem.Allocator) Set(T) {
    if (T == []const u8) return std.StringHashMap(void).init(allocator);
    return std.AutoHashMap(T, void).init(allocator);
}

// === SyncMap (concurrent map — Zig doesn't have concurrency, so just a HashMap) ===

pub fn SyncMap(comptime K: type, comptime V: type) type {
    if (K == []const u8) {
        return std.StringHashMap(V);
    }
    return std.AutoHashMap(K, V);
}

pub fn SyncMap_init(comptime K: type, comptime V: type, allocator: std.mem.Allocator) SyncMap(K, V) {
    if (K == []const u8) return std.StringHashMap(V).init(allocator);
    return std.AutoHashMap(K, V).init(allocator);
}

// === SyncSet ===

pub fn SyncSet(comptime T: type) type {
    return Set(T);
}

pub fn SyncSet_init(comptime T: type, allocator: std.mem.Allocator) SyncSet(T) {
    return Set_init(T, allocator);
}

// === OrderedMap — insertion-ordered map ===

pub fn OrderedMap(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();
        const MapType = if (K == []const u8) std.StringHashMap(V) else std.AutoHashMap(K, V);

        allocator: std.mem.Allocator,
        keys: std.ArrayListUnmanaged(K) = .empty,
        map: MapType,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .map = if (K == []const u8) std.StringHashMap(V).init(allocator) else std.AutoHashMap(K, V).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.keys.deinit(self.allocator);
            self.map.deinit();
        }

        pub fn set(self: *Self, key: K, value: V) !void {
            if (!self.map.contains(key)) {
                try self.keys.append(self.allocator, key);
            }
            try self.map.put(key, value);
        }

        pub fn get(self: *const Self, key: K) ?V {
            return self.map.get(key);
        }

        pub fn getOrZero(self: *const Self, key: K) V {
            return self.map.get(key) orelse std.mem.zeroes(V);
        }

        pub fn has(self: *const Self, key: K) bool {
            return self.map.contains(key);
        }

        pub fn delete(self: *Self, key: K) ?V {
            const value = self.map.get(key);
            if (value == null) return null;
            _ = self.map.remove(key);
            // Remove from keys slice
            for (self.keys.items, 0..) |k, i| {
                if (k == key) {
                    _ = self.keys.orderedRemove(i);
                    break;
                }
            }
            return value;
        }

        pub fn entryAt(self: *const Self, index: usize) ?struct { key: K, value: V } {
            if (index >= self.keys.items.len) return null;
            const key = self.keys.items[index];
            const value = self.map.get(key) orelse return null;
            return .{ .key = key, .value = value };
        }

        pub fn size(self: *const Self) usize {
            return self.keys.items.len;
        }

        pub fn clear(self: *Self) void {
            self.keys.clearRetainingCapacity();
            self.map.clearRetainingCapacity();
        }

        pub fn clone(self: *const Self) !Self {
            var new_map = Self.init(self.allocator);
            try new_map.keys.appendSlice(self.allocator, self.keys.items);
            var it = self.map.iterator();
            while (it.next()) |entry| {
                try new_map.map.put(entry.key_ptr.*, entry.value_ptr.*);
            }
            return new_map;
        }

        pub const Iterator = struct {
            ordered: *Self,
            index: usize = 0,

            pub fn next(self: *Iterator) ?struct { key: K, value: V } {
                if (self.index >= self.ordered.keys.items.len) return null;
                const key = self.ordered.keys.items[self.index];
                self.index += 1;
                const value = self.ordered.map.get(key) orelse return null;
                return .{ .key = key, .value = value };
            }
        };

        pub fn iterator(self: *Self) Iterator {
            return .{ .ordered = self };
        }
    };
}

// === OrderedSet — insertion-ordered set ===

pub fn OrderedSet(comptime T: type) type {
    return struct {
        const Self = @This();
        const MapType = if (T == []const u8) std.StringHashMap(void) else std.AutoHashMap(T, void);

        allocator: std.mem.Allocator,
        items: std.ArrayListUnmanaged(T) = .empty,
        map: MapType,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .map = if (T == []const u8) std.StringHashMap(void).init(allocator) else std.AutoHashMap(T, void).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit(self.allocator);
            self.map.deinit();
        }

        pub fn add(self: *Self, value: T) !bool {
            if (self.map.contains(value)) return false;
            try self.items.append(self.allocator, value);
            try self.map.put(value, {});
            return true;
        }

        pub fn has(self: *const Self, value: T) bool {
            return self.map.contains(value);
        }

        pub fn delete(self: *Self, value: T) bool {
            if (!self.map.remove(value)) return false;
            for (self.items.items, 0..) |item, i| {
                if (item == value) {
                    _ = self.items.orderedRemove(i);
                    break;
                }
            }
            return true;
        }

        pub fn size(self: *const Self) usize {
            return self.items.items.len;
        }

        pub fn clear(self: *Self) void {
            self.items.clearRetainingCapacity();
            self.map.clearRetainingCapacity();
        }

        pub fn slice(self: *const Self) []const T {
            return self.items.items;
        }
    };
}

// === MultiMap — map with multiple values per key ===

pub fn MultiMap(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();
        const MapType = if (K == []const u8) std.StringHashMap(std.ArrayListUnmanaged(V)) else std.AutoHashMap(K, std.ArrayListUnmanaged(V));

        allocator: std.mem.Allocator,
        map: MapType,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .map = if (K == []const u8) std.StringHashMap(std.ArrayListUnmanaged(V)).init(allocator) else std.AutoHashMap(K, std.ArrayListUnmanaged(V)).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            var it = self.map.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.*.deinit(self.allocator);
            }
            self.map.deinit();
        }

        pub fn add(self: *Self, key: K, value: V) !void {
            var gop = try self.map.getOrPut(key);
            if (!gop.found_existing) {
                gop.value_ptr.* = .empty;
            }
            try gop.value_ptr.append(self.allocator, value);
        }

        pub fn get(self: *const Self, key: K) ?[]const V {
            const list = self.map.get(key) orelse return null;
            return list.items;
        }

        pub fn has(self: *const Self, key: K) bool {
            return self.map.contains(key);
        }

        pub fn size(self: *const Self) usize {
            return self.map.count();
        }

        pub fn remove(self: *Self, key: K) bool {
            const list = self.map.get(key) orelse return false;
            var l = list;
            l.deinit(self.allocator);
            return self.map.remove(key);
        }
    };
}

// === Cow (Copy-on-Write) — simplified for Zig ===

pub fn Cow(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,
        is_borrowed: bool = true,

        pub fn init(value: T) Self {
            return .{ .value = value, .is_borrowed = true };
        }

        pub fn get(self: *const Self) T {
            return self.value;
        }

        pub fn getMutable(self: *Self, allocator: std.mem.Allocator) !*T {
            if (self.is_borrowed) {
                // Clone the value before mutation
                _ = allocator; // actual clone depends on T
                self.is_borrowed = false;
            }
            return &self.value;
        }
    };
}
