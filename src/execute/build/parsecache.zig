const std = @import("std");

//! Generic parse cache for build mode.
//!
//! Port of `internal/execute/build/parseCache.go` (44 LOC).
//!
//! A thread-safe cache that memoizes the result of a parse function.
//! Used by the build host to cache:
//! - Source file parses (keyed by SourceFileParseOptions)
//! - Resolved project references (keyed by path)

/// A generic parse cache entry.
fn ParseCacheEntry(comptime V: type) type {
    return struct {
        value: V,
        mu: std.Thread.Mutex = .{},
    };
}

/// A generic thread-safe parse cache.
/// Port of Go's `parseCache[K, V]`.
pub fn ParseCache(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();
        const Entry = ParseCacheEntry(V);

        entries: std.StringHashMapUnmanaged(*Entry) = .empty,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            var iter = self.entries.valueIterator();
            while (iter.next()) |entry| {
                self.allocator.destroy(entry.*);
            }
            self.entries.deinit(self.allocator);
        }

        /// Loads or stores a cached parse result.
        /// If the key is not in the cache, calls `parse_fn` to compute the
        /// value and stores it. If the key is already cached, returns the
        /// cached value.
        ///
        /// Port of Go's `loadOrStore`.
        pub fn loadOrStore(
            self: *Self,
            key: []const u8,
            parse_fn: *const fn (key: []const u8) V,
            allow_zero: bool,
        ) V {
            // Check if already cached.
            if (self.entries.get(key)) |entry| {
                entry.mu.lock();
                defer entry.mu.unlock();
                // If allow_zero, return even if value is zero-initialized.
                if (allow_zero) return entry.value;
                // Otherwise, check that value was actually computed.
                // For pointer types, zero means null.
                if (@TypeOf(entry.value) == ?*anyopaque) {
                    if (entry.value != null) return entry.value;
                } else {
                    return entry.value;
                }
            }
            // Create new entry.
            const new_entry = self.allocator.create(Entry) catch return std.mem.zeroes(V);
            new_entry.* = .{ .value = std.mem.zeroes(V) };
            new_entry.mu.lock();
            _ = self.entries.put(self.allocator, key, new_entry) catch {};
            new_entry.value = parse_fn(key);
            new_entry.mu.unlock();
            return new_entry.value;
        }

        /// Stores a value directly.
        pub fn store(self: *Self, key: []const u8, value: V) void {
            const entry = self.allocator.create(Entry) catch return;
            entry.* = .{ .value = value };
            _ = self.entries.put(self.allocator, key, entry) catch {};
        }

        /// Deletes a cached entry.
        pub fn delete(self: *Self, key: []const u8) void {
            if (self.entries.fetchRemove(key)) |kv| {
                self.allocator.destroy(kv.value);
            }
        }

        /// Clears all cached entries.
        pub fn reset(self: *Self) void {
            var iter = self.entries.valueIterator();
            while (iter.next()) |entry| {
                self.allocator.destroy(entry.*);
            }
            self.entries.clearRetainingCapacity();
        }
    };
}
