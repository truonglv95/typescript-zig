const std = @import("std");
const ast = @import("../../ast/ast.zig");
const compiler = @import("../../compiler/compiler.zig");
const diagnostics = @import("../../diagnostics/diagnostics.zig");
const system = @import("../system.zig");

pub const DiagnosticReporter = *const fn (*ast.Diagnostic) void;

pub fn quietDiagnosticReporter(diagnostic: *ast.Diagnostic) void {
    _ = diagnostic;
}

pub fn createDiagnosticReporter(sys: *system.System, writer: anytype, options: *compiler.CompilerOptions) DiagnosticReporter {
    _ = sys;
    _ = writer;
    if (options.quiet orelse false) {
        return quietDiagnosticReporter;
    }
    // TODO: format diagnostics with color and context
    return quietDiagnosticReporter;
}
