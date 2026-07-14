const std = @import("std");
const baseline = @import("../baseline/baseline.zig");

pub fn doModuleResolutionBaseline(
    allocator: std.mem.Allocator,
    baselinePath: []const u8,
    trace: []const u8,
    opts: baseline.Options,
) !void {
    var actualBaselinePath: []const u8 = undefined;
    const ext = std.fs.path.extension(baselinePath);
    if (std.mem.eql(u8, ext, ".ts") or std.mem.eql(u8, ext, ".tsx")) {
        actualBaselinePath = try std.mem.replaceOwned(u8, allocator, baselinePath, ext, ".trace.json");
    } else {
        actualBaselinePath = try allocator.dupe(u8, baselinePath);
    }
    defer allocator.free(actualBaselinePath);

    var errorBaseline: []const u8 = undefined;
    if (trace.len > 0) {
        errorBaseline = trace;
    } else {
        errorBaseline = baseline.noContent;
    }
    try baseline.run(allocator, actualBaselinePath, errorBaseline, opts);
}
