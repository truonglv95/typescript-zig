const std = @import("std");
const ast = @import("../../ast/ast.zig");
const program_mod = @import("../../compiler/program.zig");
const emitter_mod = @import("../../compiler/emitter.zig");
const core = @import("../../core/core.zig");
const diagnostics = @import("../../diagnostics/diagnostics.zig");
const system = @import("../system.zig");

pub const CompileTimes = struct {
    configTime: i64 = 0,
    bindTime: i64 = 0,
    checkTime: i64 = 0,
    emitTime: i64 = 0,
    totalTime: i64 = 0,
};

pub const ExitStatus = enum {
    Success,
    DiagnosticsPresent_OutputsSkipped,
    DiagnosticsPresent_OutputsGenerated,
    NotImplemented,
};

pub const CompileAndEmitResult = struct {
    status: ExitStatus,
    diagnostics: []diagnostics.Diagnostic,
    emitResult: ?*emitter_mod.EmitResult,
    times: *CompileTimes,
};

pub const EmitInput = struct {
    sys: *system.System,
    program: *program_mod.Program,
    options: *core.CompilerOptions,
    reportDiagnostic: *const fn (*diagnostics.Diagnostic) void,
    reportErrorSummary: *const fn ([]*diagnostics.Diagnostic) void,
    writer: *anyopaque,
    compileTimes: *CompileTimes,
    // tracing etc.
};

pub fn emitAndReportStatistics(input: EmitInput) !CompileAndEmitResult {
    var result = try emitFilesAndReportErrors(input);
    if (result.status != .Success) {
        return result;
    }
    // statistics logic goes here

    if (result.emitResult) |er| {
        if (er.EmitSkipped and result.diagnostics.len > 0) {
            result.status = .DiagnosticsPresent_OutputsSkipped;
        } else if (result.diagnostics.len > 0) {
            result.status = .DiagnosticsPresent_OutputsGenerated;
        }
    }
    return result;
}

pub fn emitFilesAndReportErrors(input: EmitInput) !CompileAndEmitResult {
    // Port of tsgo's logic: get bind & check diags, then emit JS
    var allDiagnostics = std.ArrayList(diagnostics.Diagnostic).empty;
    defer allDiagnostics.deinit(input.program.allocator);

    // 1. Get global/bind diagnostics (simplified for now)
    // 2. Get semantic diagnostics
    for (input.program.units.items) |unit| {
        if (unit.is_default_library) continue;
        if (std.mem.endsWith(u8, unit.path, ".d.ts")) continue;

        // TODO: actually run binder/checker here or it should be run before?
        // In Go, GetDiagnosticsOfAnyProgram calls GetBindDiagnostics and GetSemanticDiagnostics.
        // For now we assume the Program has already been checked or we run the checker here.
        // We will just collect program diagnostics.
    }
    // allDiagnostics.appendSlice(input.program.allocator, input.program.diagnostics.items) catch {};

    // 3. Emit
    var emit_result: ?*emitter_mod.EmitResult = null;
    if (!(input.options.listFilesOnly orelse false)) {
        // Assume EmitAll
        if (input.program.emit(.EmitAll)) |er| {
            emit_result = er;
            allDiagnostics.appendSlice(input.program.allocator, er.Diagnostics) catch {};
        } else |err| {
            return err;
            // Handle error
        }
    }

    // TODO: listFiles

    // input.reportErrorSummary(allDiagnostics.items);

    return .{
        .status = .Success,
        .diagnostics = allDiagnostics.toOwnedSlice(input.program.allocator) catch &[_]diagnostics.Diagnostic{},
        .emitResult = emit_result,
        .times = input.compileTimes,
    };
}
