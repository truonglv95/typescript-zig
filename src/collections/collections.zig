const std = @import("std");

pub fn Set(comptime T: type) type {
    if (T == []const u8) {
        return std.StringHashMap(void);
    }
    return std.AutoHashMap(T, void);
}

pub fn SyncMap(comptime K: type, comptime V: type) type {
    if (K == []const u8) {
        return std.StringHashMap(V);
    }
    return std.AutoHashMap(K, V);
}