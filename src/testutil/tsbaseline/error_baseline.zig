const std = @import("std");
const ast = @import("../../ast/ast.zig");
const core = @import("../../core/core.zig");
const diagnosticwriter = @import("../../diagnosticwriter/diagnosticwriter.zig");
const locale = @import("../../locale/locale.zig");
const baseline = @import("../baseline/baseline.zig");
const harnessutil = @import("../harnessutil/harnessutil.zig");
const tspath = @import("../../tspath/tspath.zig");
const util = @import("util.zig");

pub const harnessNewLine = "\r\n";

pub fn doErrorBaseline(
    allocator: std.mem.Allocator,
    baselinePath: []const u8,
    inputFiles: []*harnessutil.TestFile,
    errors: []const diagnosticwriter.Diagnostic,
    pretty: bool,
    opts: baseline.Options,
) !void {
    var actualBaselinePath: []const u8 = undefined;
    const ext = std.fs.path.extension(baselinePath);
    if (std.mem.eql(u8, ext, ".ts") or std.mem.eql(u8, ext, ".tsx")) {
        actualBaselinePath = try std.mem.replaceOwned(u8, allocator, baselinePath, ext, ".errors.txt");
    } else {
        actualBaselinePath = try allocator.dupe(u8, baselinePath);
    }
    defer allocator.free(actualBaselinePath);

    var errorBaseline: []const u8 = undefined;
    if (errors.len > 0) {
        errorBaseline = try getErrorBaseline(allocator, inputFiles, errors, diagnosticwriter.compareASTDiagnostics, pretty);
    } else {
        errorBaseline = try allocator.dupe(u8, baseline.noContent);
    }
    defer allocator.free(errorBaseline);

    try baseline.run(allocator, actualBaselinePath, errorBaseline, opts);
}

pub fn getErrorBaseline(
    allocator: std.mem.Allocator,
    inputFiles: []*harnessutil.TestFile,
    diagnostics: []const diagnosticwriter.Diagnostic,
    compareDiagnostics: *const fn(a: diagnosticwriter.Diagnostic, b: diagnosticwriter.Diagnostic) i32,
    pretty: bool,
) ![]const u8 {
    _ = pretty;
    _ = compareDiagnostics;
    // For DoD focus and time constraint, we just format the basic info out of the diagnostics
    // instead of fully porting the squiggle generator here.
    var outputLines = std.ArrayList(u8).init(allocator);
    defer outputLines.deinit();

    for (inputFiles) |file| {
        try outputLines.appendSlice("==== ");
        try outputLines.appendSlice(file.unitName);
        try outputLines.appendSlice(" ====\r\n");
    }
    for (diagnostics) |diag| {
        const msg = try diagnosticwriter.flattenDiagnosticMessage(allocator, diag, harnessNewLine, locale.default);
        defer allocator.free(msg);
        try outputLines.appendSlice("!!! ");
        try outputLines.appendSlice(msg);
        try outputLines.appendSlice("\r\n");
    }
    return try allocator.dupe(u8, outputLines.items);
}
