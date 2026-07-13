const std = @import("std");

//! TSC statistics reporting.
//!
//! Port of `internal/execute/tsc/statistics.go` (157 LOC).
//!
//! Reports compilation statistics (timings, memory, file counts) when
//! the `--diagnostics` or `--extendedDiagnostics` flag is set.

const compile = @import("compile.zig");

/// Compilation statistics. Port of Go's `Statistics` struct.
pub const Statistics = struct {
    /// Number of source files in the program.
    file_count: u32 = 0,
    /// Number of lines of code across all source files.
    line_count: u32 = 0,
    /// Number of nodes in all ASTs.
    node_count: u32 = 0,
    /// Number of identifiers in all ASTs.
    identifier_count: u32 = 0,
    /// Number of symbols in the binder.
    symbol_count: u32 = 0,
    /// Number of types in the checker.
    type_count: u32 = 0,
    /// Compile times breakdown.
    times: compile.CompileTimes = .{},
    /// Memory allocated (in bytes).
    allocated_memory: u64 = 0,
    /// Whether this is extended diagnostics (more detail).
    is_extended: bool = false,

    /// Prints statistics to the given writer.
    /// Port of Go's `Statistics.printStatistics`.
    pub fn print(self: Statistics, writer: anytype) !void {
        try writer.print("Files:                          {d}\n", .{self.file_count});
        try writer.print("Lines of Library:               {d}\n", .{self.line_count});
        try writer.print("Lines of TypeScript:            {d}\n", .{self.line_count});
        try writer.print("Nodes:                          {d}\n", .{self.node_count});
        try writer.print("Identifiers:                    {d}\n", .{self.identifier_count});
        try writer.print("Symbols:                        {d}\n", .{self.symbol_count});
        try writer.print("Types:                          {d}\n", .{self.type_count});
        try writer.print("Time:                           {d}ms\n", .{@divTrunc(self.times.total_time_ns, std.time.ns_per_ms)});

        if (self.is_extended) {
            try self.printExtended(writer);
        }
    }

    fn printExtended(self: Statistics, writer: anytype) !void {
        try writer.print("\nExtended Statistics:\n", .{});
        try writer.print("Config time:                    {d}ms\n", .{@divTrunc(self.times.config_time_ns, std.time.ns_per_ms)});
        try writer.print("Parse time:                     {d}ms\n", .{@divTrunc(self.times.parse_time_ns, std.time.ns_per_ms)});
        try writer.print("Bind time:                      {d}ms\n", .{@divTrunc(self.times.bind_time_ns, std.time.ns_per_ms)});
        try writer.print("Check time:                     {d}ms\n", .{@divTrunc(self.times.check_time_ns, std.time.ns_per_ms)});
        try writer.print("Emit time:                      {d}ms\n", .{@divTrunc(self.times.emit_time_ns, std.time.ns_per_ms)});
        try writer.print("Build info read time:           {d}ms\n", .{@divTrunc(self.times.build_info_read_time_ns, std.time.ns_per_ms)});
        try writer.print("Changes compute time:           {d}ms\n", .{@divTrunc(self.times.changes_compute_time_ns, std.time.ns_per_ms)});
        if (self.allocated_memory > 0) {
            try writer.print("Memory allocated:               {d} bytes\n", .{self.allocated_memory});
        }
    }
};
