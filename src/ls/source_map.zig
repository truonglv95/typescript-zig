const std = @import("std");

//! Source map utilities for language service.
//!
//! Port of `internal/ls/source_map.go` (134 LOC).
//!
//! Provides source map range mapping between generated .js files and
//! their original .ts source files, used for debugging and go-to-definition
//! in generated files.

/// A mapping from a generated file position to a source file position.
pub const SourceMapMapping = struct {
    /// Position in the generated file.
    generated_line: u32,
    generated_column: u32,
    /// Position in the source file.
    source_line: u32,
    source_column: u32,
    /// Source file name (if the source map references multiple files).
    source: ?[]const u8 = null,
};

/// A decoded source map.
pub const SourceMap = struct {
    file: []const u8 = "",
    source_root: []const u8 = "",
    sources: []const []const u8 = &.{},
    mappings: std.ArrayListUnmanaged(SourceMapMapping) = .empty,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SourceMap {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *SourceMap) void {
        self.mappings.deinit(self.allocator);
    }

    /// Finds the source position for a given generated position.
    pub fn getSourcePosition(self: *const SourceMap, generated_line: u32, generated_column: u32) ?SourceMapMapping {
        // Binary search for the closest mapping before the given position.
        var lo: usize = 0;
        var hi: usize = self.mappings.items.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            const m = self.mappings.items[mid];
            if (m.generated_line < generated_line or
                (m.generated_line == generated_line and m.generated_column <= generated_column))
            {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        if (lo > 0) return self.mappings.items[lo - 1];
        return null;
    }
};
