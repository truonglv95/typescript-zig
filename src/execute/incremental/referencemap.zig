const std = @import("std");

//! Reference map for incremental compilation.
//!
//! Port of `internal/execute/incremental/referencemap.go` (52 LOC).
//!
//! Tracks which files reference which other files (via imports, triple-
//! slash references, etc.) and provides reverse lookup (referencedBy).

const tspath = @import("../../tspath/tspath.zig");

/// A bidirectional map of file references.
/// Port of Go's `referenceMap`.
pub const ReferenceMap = struct {
    /// path -> set of paths it references.
    references: std.StringHashMapUnmanaged(std.StringHashMapUnmanaged(void)),
    /// path -> set of paths that reference it (lazily computed).
    referenced_by: ?std.StringHashMapUnmanaged(std.StringHashMapUnmanaged(void)) = null,
    allocator: std.mem.Allocator,
    mu: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) ReferenceMap {
        return .{
            .references = .empty,
            .allocator = allocator,
            .mu = .{},
        };
    }

    pub fn deinit(self: *ReferenceMap) void {
        var iter = self.references.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.references.deinit(self.allocator);
        if (self.referenced_by) |*rb| {
            var rb_iter = rb.iterator();
            while (rb_iter.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
            }
            rb.deinit(self.allocator);
        }
    }

    /// Stores the set of references for `path`.
    pub fn storeReferences(self: *ReferenceMap, path: []const u8, refs: []const []const u8) void {
        self.mu.lock();
        defer self.mu.unlock();
        // Invalidate the referenced_by cache.
        if (self.referenced_by) |*rb| {
            var rb_iter = rb.iterator();
            while (rb_iter.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
            }
            rb.deinit(self.allocator);
            self.referenced_by = null;
        }
        var set = std.StringHashMapUnmanaged(void).empty;
        for (refs) |ref| {
            _ = set.put(self.allocator, ref, {}) catch {};
        }
        _ = self.references.put(self.allocator, path, set) catch {};
    }

    /// Gets the set of paths referenced by `path`.
    pub fn getReferences(self: *ReferenceMap, path: []const u8) ?std.StringHashMapUnmanaged(void) {
        self.mu.lock();
        defer self.mu.unlock();
        return self.references.get(path);
    }

    /// Gets all paths that have references.
    pub fn getPathsWithReferences(self: *ReferenceMap, allocator: std.mem.Allocator) ![][]const u8 {
        self.mu.lock();
        defer self.mu.unlock();
        var result = std.ArrayListUnmanaged([]const u8).empty;
        var iter = self.references.keyIterator();
        while (iter.next()) |key| {
            try result.append(allocator, key.*);
        }
        return result.toOwnedSlice(allocator);
    }

    /// Gets all paths that reference `path` (reverse lookup).
    /// Lazily builds the `referenced_by` map on first call.
    pub fn getReferencedBy(self: *ReferenceMap, path: []const u8) []const []const u8 {
        self.mu.lock();
        defer self.mu.unlock();
        // Lazily build the reverse map.
        if (self.referenced_by == null) {
            self.referenced_by = std.StringHashMapUnmanaged(std.StringHashMapUnmanaged(void)).empty;
            var iter = self.references.iterator();
            while (iter.next()) |entry| {
                var ref_iter = entry.value_ptr.iterator();
                while (ref_iter.next()) |ref| {
                    const gop = self.referenced_by.?.getOrPut(self.allocator, ref.key_ptr.*) catch continue;
                    if (!gop.found_existing) {
                        gop.value_ptr.* = std.StringHashMapUnmanaged(void).empty;
                    }
                    _ = gop.value_ptr.put(self.allocator, entry.key_ptr.*, {}) catch {};
                }
            }
        }
        // Look up the reverse references.
        if (self.referenced_by.?.get(path)) |set| {
            // Collect keys into a slice.
            var result = std.ArrayListUnmanaged([]const u8).empty;
            var iter = set.keyIterator();
            while (iter.next()) |key| {
                result.append(self.allocator, key.*) catch break;
            }
            return result.toOwnedSlice(self.allocator) catch &.{};
        }
        return &.{};
    }
};
