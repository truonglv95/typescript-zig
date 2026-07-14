const std = @import("std");
const core = @import("../../core/core.zig");
const json = @import("../../json/json.zig");
const sourcemap = @import("../../sourcemap/sourcemap.zig");
const baseline = @import("../baseline/baseline.zig");
const harnessutil = @import("../harnessutil/harnessutil.zig");
const tspath = @import("../../tspath/tspath.zig");
const util = @import("util.zig");

pub fn doSourcemapBaseline(
    allocator: std.mem.Allocator,
    baselinePath: []const u8,
    header: []const u8,
    options: *core.CompilerOptions,
    result: *harnessutil.CompilationResult,
    harnessSettings: *harnessutil.HarnessOptions,
    opts: baseline.Options,
) !void {
    _ = header;
    const declMaps = options.getAreDeclarationMapsEnabled();
    if (options.inlineSourceMap.isTrue()) {
        if (result.maps.size() > 0 and !declMaps) {
            return error.NoSourceMapFilesShouldBeGenerated;
        }
        return;
    } else if (options.sourceMap.isTrue() or declMaps) {
        var expectedMapCount: usize = 0;
        if (options.sourceMap.isTrue()) {
            expectedMapCount += result.getNumberOfJSFiles(false);
        }
        if (declMaps) {
            expectedMapCount += result.getNumberOfJSFiles(true);
        }
        if (result.maps.size() != expectedMapCount) {
            return error.NumberOfSourceMapFilesShouldBeSameAsJsFiles;
        }

        var sourceMapCode: []const u8 = undefined;
        var sourceMapCodeBuilder = std.ArrayList(u8).init(allocator);
        defer sourceMapCodeBuilder.deinit();

        if ((options.noEmitOnError.isTrue() and result.diagnostics.items.len != 0) or result.maps.size() == 0) {
            sourceMapCode = try allocator.dupe(u8, baseline.noContent);
        } else {
            var it = result.maps.values();
            while (it.next()) |sourceMap| {
                if (sourceMapCodeBuilder.items.len > 0) {
                    try sourceMapCodeBuilder.appendSlice("\r\n");
                }
                const output = try fileOutput(allocator, sourceMap, harnessSettings);
                defer allocator.free(output);
                try sourceMapCodeBuilder.appendSlice(output);
                if (!options.inlineSourceMap.isTrue()) {
                    const link = try createSourceMapPreviewLink(allocator, sourceMap, result);
                    defer allocator.free(link);
                    try sourceMapCodeBuilder.appendSlice(link);
                }
            }
            sourceMapCode = try allocator.dupe(u8, sourceMapCodeBuilder.items);
        }
        defer allocator.free(sourceMapCode);

        var actualBaselinePath: []const u8 = undefined;
        const ext = std.fs.path.extension(baselinePath);
        if (std.mem.eql(u8, ext, ".ts") or std.mem.eql(u8, ext, ".tsx")) {
            actualBaselinePath = try tspath.changeExtension(allocator, baselinePath, tspath.ExtensionJs ++ ".map");
        } else {
            actualBaselinePath = try allocator.dupe(u8, baselinePath);
        }
        defer allocator.free(actualBaselinePath);

        try baseline.run(allocator, actualBaselinePath, sourceMapCode, opts);
    }
}

pub fn fileOutput(allocator: std.mem.Allocator, file: *harnessutil.TestFile, settings: *harnessutil.HarnessOptions) ![]const u8 {
    var fileName: []const u8 = undefined;
    if (settings.fullEmitPaths) {
        fileName = try util.removeTestPathPrefixes(allocator, file.unitName, false);
    } else {
        fileName = try allocator.dupe(u8, tspath.getBaseFileName(file.unitName));
    }
    defer allocator.free(fileName);
    return std.fmt.allocPrint(allocator, "//// [{s}]\r\n{s}", .{ fileName, file.content });
}

fn createSourceMapPreviewLink(allocator: std.mem.Allocator, sourceMap: *harnessutil.TestFile, result: *harnessutil.CompilationResult) ![]const u8 {
    var sourcemapJSON = try json.unmarshal(sourcemap.RawSourceMap, allocator, sourceMap.content);
    defer sourcemapJSON.deinit(allocator);

    var outputJSFile: ?*harnessutil.TestFile = null;
    for (result.outputs().items) |td| {
        if (std.mem.endsWith(u8, td.unitName, sourcemapJSON.file)) {
            outputJSFile = td;
            break;
        }
    }

    if (outputJSFile == null) return try allocator.dupe(u8, "");

    var sourceTDs = std.ArrayList(*harnessutil.TestFile).init(allocator);
    defer sourceTDs.deinit();

    for (sourcemapJSON.sources) |s| {
        var found: ?*harnessutil.TestFile = null;
        for (result.inputs().items) |td| {
            if (std.mem.endsWith(u8, td.unitName, s)) {
                found = td;
                break;
            }
        }
        if (found) |f| {
            try sourceTDs.append(f);
        } else {
            return try allocator.dupe(u8, "");
        }
    }

    var hash = std.ArrayList(u8).init(allocator);
    defer hash.deinit();

    try hash.appendSlice("\n//// https://sokra.github.io/source-map-visualization#base64,");
    
    const outputJsChunk = try base64EncodeChunk(allocator, outputJSFile.?.content);
    defer allocator.free(outputJsChunk);
    try hash.appendSlice(outputJsChunk);
    try hash.appendSlice(",");

    const sourceMapChunk = try base64EncodeChunk(allocator, sourceMap.content);
    defer allocator.free(sourceMapChunk);
    try hash.appendSlice(sourceMapChunk);

    for (sourceTDs.items) |td| {
        try hash.appendSlice(",");
        const tdChunk = try base64EncodeChunk(allocator, td.content);
        defer allocator.free(tdChunk);
        try hash.appendSlice(tdChunk);
    }
    try hash.appendSlice("\n");
    return try allocator.dupe(u8, hash.items);
}

fn base64EncodeChunk(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    const encoded_len = std.base64.standard.Encoder.calcSize(s.len);
    const buf = try allocator.alloc(u8, encoded_len);
    _ = std.base64.standard.Encoder.encode(buf, s);
    return buf;
}
