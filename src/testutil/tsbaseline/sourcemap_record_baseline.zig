const std = @import("std");
const core = @import("../../core/core.zig");
const baseline = @import("../baseline/baseline.zig");
const harnessutil = @import("../harnessutil/harnessutil.zig");
const tspath = @import("../../tspath/tspath.zig");
const util = @import("util.zig");

pub fn doSourcemapRecordBaseline(
    allocator: std.mem.Allocator,
    baselinePath: []const u8,
    header: []const u8,
    options: *core.CompilerOptions,
    result: *harnessutil.CompilationResult,
    harnessSettings: *harnessutil.HarnessOptions,
    opts: baseline.Options,
) !void {
    _ = header;
    _ = harnessSettings;
    var actual: []const u8 = baseline.noContent;
    
    if (options.sourceMap.isTrue() or options.inlineSourceMap.isTrue() or options.declarationMap.isTrue()) {
        const sourceMapRecord = try result.getSourceMapRecord(allocator);
        defer allocator.free(sourceMapRecord);
        const record = try util.removeTestPathPrefixes(allocator, sourceMapRecord, false);
        
        if (!(options.noEmitOnError.isTrue() and result.diagnostics.items.len > 0) and record.len > 0) {
            actual = record; // Ownership of record should be managed carefully, here we assume it's passed or freed later
        } else {
            allocator.free(record);
        }
    }

    var actualBaselinePath: []const u8 = undefined;
    const ext = std.fs.path.extension(baselinePath);
    if (std.mem.eql(u8, ext, ".ts") or std.mem.eql(u8, ext, ".tsx")) {
        actualBaselinePath = try tspath.changeExtension(allocator, baselinePath, ".sourcemap.txt");
    } else {
        actualBaselinePath = try allocator.dupe(u8, baselinePath);
    }
    defer allocator.free(actualBaselinePath);

    try baseline.run(allocator, actualBaselinePath, actual, opts);
    if (actual.ptr != baseline.noContent.ptr) {
        allocator.free(actual);
    }
}
