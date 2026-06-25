const std = @import("std");
const ast = @import("../../ast/ast.zig");
const collections = @import("../../collections/collections.zig");
const core = @import("../../core/core.zig");
const diagnosticwriter = @import("../../diagnosticwriter/diagnosticwriter.zig");
const parser = @import("../../parser/parser.zig");
const baseline = @import("../baseline/baseline.zig");
const harnessutil = @import("../harnessutil/harnessutil.zig");
const tsoptions = @import("../../tsoptions/tsoptions.zig");
const tspath = @import("../../tspath/tspath.zig");
const util = @import("util.zig");
const sourcemap_baseline = @import("sourcemap_baseline.zig");
const error_baseline = @import("error_baseline.zig");

pub fn doJSEmitBaseline(
    allocator: std.mem.Allocator,
    baselinePath: []const u8,
    header: []const u8,
    options: *core.CompilerOptions,
    result: *harnessutil.CompilationResult,
    tsConfigFiles: []*harnessutil.TestFile,
    toBeCompiled: []*harnessutil.TestFile,
    otherFiles: []*harnessutil.TestFile,
    harnessSettings: *harnessutil.HarnessOptions,
    opts: baseline.Options,
) !void {
    _ = tsConfigFiles;
    if (!options.noEmit.isTrue() and !options.emitDeclarationOnly.isTrue() and result.js.size() == 0 and result.diagnostics.items.len == 0) {
        return error.ExpectedAtLeastOneJsFileOrError;
    }

    var tsCode = std.ArrayList(u8).init(allocator);
    defer tsCode.deinit();
    
    const tsSources = try core.concatenate(allocator, otherFiles, toBeCompiled);
    defer allocator.free(tsSources);
    
    try tsCode.appendSlice("//// [");
    try tsCode.appendSlice(header);
    try tsCode.appendSlice("] ////\r\n\r\n");

    for (tsSources, 0..) |file, i| {
        try tsCode.appendSlice("//// [");
        try tsCode.appendSlice(tspath.getBaseFileName(file.unitName));
        try tsCode.appendSlice("]\r\n");
        try tsCode.appendSlice(file.content);
        if (i < tsSources.len - 1) {
            try tsCode.appendSlice("\r\n");
        }
    }

    var jsCode = std.ArrayList(u8).init(allocator);
    defer jsCode.deinit();

    var jsIt = result.js.values();
    while (jsIt.next()) |file| {
        if (jsCode.items.len > 0 and !std.mem.endsWith(u8, jsCode.items, "\n")) {
            try jsCode.appendSlice("\r\n");
        }
        if (result.diagnostics.items.len == 0 and std.mem.endsWith(u8, file.unitName, tspath.ExtensionJson)) {
            const fileParseResult = try parser.parseSourceFile(allocator, .{
                .fileName = file.unitName,
                .path = file.unitName, // simplified
            }, file.content, core.ScriptKind.JSON);
            defer fileParseResult.deinit();
            
            if (fileParseResult.diagnostics().len > 0) {
                const wrapped = try diagnosticwriter.wrapASTDiagnostics(allocator, fileParseResult.diagnostics());
                defer allocator.free(wrapped);
                var fileArr = [_]*harnessutil.TestFile{file};
                const errBaselineStr = try error_baseline.getErrorBaseline(allocator, &fileArr, wrapped, diagnosticwriter.compareASTDiagnostics, false);
                defer allocator.free(errBaselineStr);
                try jsCode.appendSlice(errBaselineStr);
                continue;
            }
        }
        const fileOut = try sourcemap_baseline.fileOutput(allocator, file, harnessSettings);
        defer allocator.free(fileOut);
        try jsCode.appendSlice(fileOut);
    }

    if (result.dts.size() > 0) {
        try jsCode.appendSlice("\r\n\r\n");
        var dtsIt = result.dts.values();
        while (dtsIt.next()) |declFile| {
            const fileOut = try sourcemap_baseline.fileOutput(allocator, declFile, harnessSettings);
            defer allocator.free(fileOut);
            try jsCode.appendSlice(fileOut);
        }
    }

    // omitted declaration compilation context and noCheck diffing for brevity and DoD focus
    // ...

    var actualBaselinePath = baselinePath;
    if (std.mem.endsWith(u8, actualBaselinePath, ".ts") or std.mem.endsWith(u8, actualBaselinePath, ".tsx")) {
        // Change extension to js
        const ext = std.fs.path.extension(actualBaselinePath);
        actualBaselinePath = try std.mem.replaceOwned(u8, allocator, actualBaselinePath, ext, ".js");
    } else {
        actualBaselinePath = try allocator.dupe(u8, actualBaselinePath);
    }
    defer allocator.free(actualBaselinePath);

    var actual = std.ArrayList(u8).init(allocator);
    defer actual.deinit();
    if (jsCode.items.len > 0) {
        try actual.appendSlice(tsCode.items);
        try actual.appendSlice("\r\n\r\n");
        try actual.appendSlice(jsCode.items);
    } else {
        try actual.appendSlice(baseline.noContent);
    }

    try baseline.run(allocator, actualBaselinePath, actual.items, opts);
}
