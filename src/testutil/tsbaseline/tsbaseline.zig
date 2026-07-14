const std = @import("std");
pub const error_baseline = @import("error_baseline.zig");
pub const js_emit_baseline = @import("js_emit_baseline.zig");
pub const module_resolution_baseline = @import("module_resolution_baseline.zig");
pub const sourcemap_baseline = @import("sourcemap_baseline.zig");
pub const sourcemap_record_baseline = @import("sourcemap_record_baseline.zig");
pub const type_symbol_baseline = @import("type_symbol_baseline.zig");
pub const util = @import("util.zig");

pub const BaselineOptions = struct {
    Subfolder: []const u8 = "",
    IsSubmodule: bool = false,
    SkipDiffWithOld: bool = false,
};

pub fn DoErrorBaseline(
    allocator: std.mem.Allocator,
    configuredName: []const u8,
    files: anytype,
    diagnostics: anytype,
    pretty: bool,
    options: BaselineOptions,
) !void {
    _ = allocator;
    _ = configuredName;
    _ = files;
    _ = diagnostics;
    _ = pretty;
    _ = options;
}

pub fn DoJSEmitBaseline(
    allocator: std.mem.Allocator,
    configuredName: []const u8,
    header: []const u8,
    options: anytype,
    result: anytype,
    tsConfigFiles: anytype,
    toBeCompiled: anytype,
    otherFiles: anytype,
    harnessOptions: anytype,
    baselineOptions: BaselineOptions,
) !void {
    _ = allocator;
    _ = configuredName;
    _ = header;
    _ = options;
    _ = result;
    _ = tsConfigFiles;
    _ = toBeCompiled;
    _ = otherFiles;
    _ = harnessOptions;
    _ = baselineOptions;
}

pub fn DoSourcemapBaseline(
    allocator: std.mem.Allocator,
    configuredName: []const u8,
    header: []const u8,
    options: anytype,
    result: anytype,
    harnessOptions: anytype,
    baselineOptions: BaselineOptions,
) !void {
    _ = allocator;
    _ = configuredName;
    _ = header;
    _ = options;
    _ = result;
    _ = harnessOptions;
    _ = baselineOptions;
}

pub fn DoSourcemapRecordBaseline(
    allocator: std.mem.Allocator,
    configuredName: []const u8,
    header: []const u8,
    options: anytype,
    result: anytype,
    harnessOptions: anytype,
    baselineOptions: BaselineOptions,
) !void {
    _ = allocator;
    _ = configuredName;
    _ = header;
    _ = options;
    _ = result;
    _ = harnessOptions;
    _ = baselineOptions;
}

pub fn DoTypeAndSymbolBaseline(
    allocator: std.mem.Allocator,
    configuredName: []const u8,
    header: []const u8,
    program: anytype,
    allFiles: anytype,
    baselineOptions: BaselineOptions,
    a: bool,
    b: bool,
    c: bool,
) !void {
    _ = allocator;
    _ = configuredName;
    _ = header;
    _ = program;
    _ = allFiles;
    _ = baselineOptions;
    _ = a;
    _ = b;
    _ = c;
}

pub fn DoModuleResolutionBaseline(
    allocator: std.mem.Allocator,
    configuredName: []const u8,
    trace: []const u8,
    baselineOptions: BaselineOptions,
) !void {
    _ = allocator;
    _ = configuredName;
    _ = trace;
    _ = baselineOptions;
}
