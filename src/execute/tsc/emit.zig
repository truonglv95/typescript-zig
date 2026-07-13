const std = @import("std");

//! TSC emit and report statistics.
//!
//! Port of `internal/execute/tsc/emit.go` (152 LOC).
//!
//! Coordinates the emit phase: emits files, reports diagnostics,
//! and optionally prints statistics.

const compile = @import("compile.zig");
const statistics = @import("statistics.zig");
const compiler = @import("../../compiler/compiler.zig");
const diagnostics = @import("../../diagnostics/diagnostics.zig");

/// Input for the emit phase. Port of Go's `EmitInput`.
pub const EmitInput = struct {
    program: *compiler.Program,
    report_diagnostic: ?*const fn (diag: diagnostics.Diagnostic) void = null,
    write_file: ?compiler.WriteFile = null,
    compile_times: ?*compile.CompileTimes = null,
};

/// Emits files and reports errors. Returns a `CompileAndEmitResult`.
/// Port of Go's `EmitFilesAndReportErrors`.
pub fn emitFilesAndReportErrors(input: EmitInput) compile.CompileAndEmitResult {
    _ = input;
    // Full implementation requires:
    // 1. Call program.emit()
    // 2. Collect diagnostics from emit result
    // 3. Report each diagnostic via report_diagnostic
    // 4. Return CompileAndEmitResult with status
    // For now, return success with no diagnostics.
    return .{
        .diagnostics = &.{},
        .emit_result = null,
        .status = .Success,
        .times = null,
    };
}

/// Emits files, reports errors, and optionally prints statistics.
/// Port of Go's `EmitAndReportStatistics`.
pub fn emitAndReportStatistics(input: EmitInput) struct { result: compile.CompileAndEmitResult, stats: ?statistics.Statistics } {
    const result = emitFilesAndReportErrors(input);
    if (result.status != .Success) {
        return .{ .result = result, .stats = null };
    }

    // TODO(phase2.10): collect statistics from program when
    // --diagnostics or --extendedDiagnostics is set.
    return .{ .result = result, .stats = null };
}
