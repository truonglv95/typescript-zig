const std = @import("std");

//! TSC compile types and entry points.
//!
//! Port of `internal/execute/tsc/compile.go` (80 LOC).
//!
//! Defines the `System` interface, `ExitStatus`, `CommandLineResult`,
//! and `CompileTimes` types used by the tsc CLI.

const vfs = @import("../../vfs/vfs.zig");
const compiler = @import("../../compiler/compiler.zig");
const diagnostics = @import("../../diagnostics/diagnostics.zig");

/// Exit status codes returned by the tsc CLI.
/// Port of Go's `ExitStatus` enum.
pub const ExitStatus = enum(i32) {
    Success = 0,
    DiagnosticsPresent_OutputsSkipped = 1,
    DiagnosticsPresent_OutputsGenerated = 2,
    InvalidProject_OutputsSkipped = 3,
    ProjectReferenceCycle_OutputsSkipped = 4,
    NotImplemented = 5,
};

/// A watcher interface for `--watch` mode.
pub const Watcher = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        doCycle: *const fn (ptr: *anyopaque) void,
    };

    pub fn doCycle(self: Watcher) void {
        self.vtable.doCycle(self.ptr);
    }
};

/// Result of parsing command-line arguments.
pub const CommandLineResult = struct {
    status: ExitStatus,
    watcher: ?Watcher = null,
};

/// Testing callbacks for CLI test harness.
pub const CommandLineTesting = ?*anyopaque;

/// Compile timing breakdown.
pub const CompileTimes = struct {
    config_time_ns: i128 = 0,
    parse_time_ns: i128 = 0,
    bind_time_ns: i128 = 0,
    check_time_ns: i128 = 0,
    total_time_ns: i128 = 0,
    emit_time_ns: i128 = 0,
    build_info_read_time_ns: i128 = 0,
    changes_compute_time_ns: i128 = 0,
};

/// Result of compiling and emitting.
pub const CompileAndEmitResult = struct {
    diagnostics: []const diagnostics.Diagnostic = &.{},
    emit_result: ?*compiler.EmitResult = null,
    status: ExitStatus = .Success,
    times: ?CompileTimes = null,
};
