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
    const is_string = K == []const u8;
    const BaseMap = if (is_string) std.StringHashMap(V) else std.AutoHashMap(K, V);
    const DirtyMap = if (is_string) std.StringHashMap(*MapEntry(K, V)) else std.AutoHashMap(K, *MapEntry(K, V));

    return struct {
        const Self = @This();
        const Entry = MapEntry(K, V);

        allocator: std.mem.Allocator,
        base: BaseMap,
        dirty: DirtyMap,

        pub fn init(allocator: std.mem.Allocator, base: BaseMap) Self {
            return .{
                .allocator = allocator,
                .base = base,
                .dirty = DirtyMap.init(allocator),
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

        pub fn finalize(self: *Self) !struct { BaseMap, bool } {
            if (self.dirty.count() == 0) {
                return .{ self.base, false };
            }
            var result = BaseMap.init(self.allocator);
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

        pub fn tryDelete(self: *Self, key: K) bool {
            if (self.get(key)) |entry| {
                entry.is_delete = true;
                if (!entry.dirty) {
                    entry.dirty = true;
                    self.dirty.put(key, entry) catch @panic("OOM");
                }
                return true;
            }
            return false;
        }

        pub fn delete(self: *Self, key: K) void {
            if (!self.tryDelete(key)) {
                @panic("tried to delete a non-existent entry");
            }
        }

        pub fn changeIf(self: *Self, key: K, cond: *const fn (V) bool, apply: *const fn (*V) void) bool {
            if (self.get(key)) |entry| {
                if (entry.is_delete) @panic("tried to change deleted entry");
                if (cond(entry.value)) {
                    if (!entry.dirty) {
                        entry.dirty = true;
                        self.dirty.put(key, entry) catch @panic("OOM");
                    }
                    apply(&entry.value);
                    return true;
                }
            }
            return false;
        }

        pub fn range(self: *Self, fn_call: *const fn (*Entry) bool) void {
            var seen_in_dirty = std.StringHashMap(void).init(self.allocator);
            defer seen_in_dirty.deinit();

            var dirty_it = self.dirty.iterator();
            while (dirty_it.next()) |entry| {
                seen_in_dirty.put(entry.key_ptr.*, {}) catch @panic("OOM");
                if (!entry.value_ptr.*.is_delete and !fn_call(entry.value_ptr.*)) {
                    break;
                }
            }
            var base_it = self.base.iterator();
            while (base_it.next()) |entry| {
                if (seen_in_dirty.contains(entry.key_ptr.*)) {
                    continue;
                }
                var map_entry = Entry{
                    .key = entry.key_ptr.*,
                    .original = entry.value_ptr.*,
                    .value = entry.value_ptr.*,
                    .dirty = false,
                };
                if (!fn_call(&map_entry)) {
                    break;
                }
            }
        }
    };
}
