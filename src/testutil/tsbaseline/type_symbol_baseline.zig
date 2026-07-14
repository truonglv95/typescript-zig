const std = @import("std");
const ast = @import("../../ast/ast.zig");
const checker = @import("../../checker/checker.zig");
const compiler = @import("../../compiler/compiler.zig");
const core = @import("../../core/core.zig");
const nodebuilder = @import("../../nodebuilder/nodebuilder.zig");
const printer = @import("../../printer/printer.zig");
const scanner = @import("../../scanner/scanner.zig");
const baseline = @import("../baseline/baseline.zig");
const harnessutil = @import("../harnessutil/harnessutil.zig");
const tspath = @import("../../tspath/tspath.zig");
const util = @import("util.zig");

pub fn doTypeAndSymbolBaseline(
    allocator: std.mem.Allocator,
    baselinePath: []const u8,
    header: []const u8,
    program: compiler.ProgramLike,
    allFiles: []*harnessutil.TestFile,
    opts: baseline.Options,
    skipTypeBaselines: bool,
    skipSymbolBaselines: bool,
    hasErrorBaseline: bool,
) !void {
    _ = skipTypeBaselines;
    _ = skipSymbolBaselines;
    _ = hasErrorBaseline;

    var walker = try TypeWriterWalker.init(allocator, program);
    defer walker.deinit();

    const typesOpts = opts; // modify as needed
    
    // type baseline
    try checkBaselines(allocator, baselinePath, allFiles, &walker, header, typesOpts, false);

    // symbol baseline
    try checkBaselines(allocator, baselinePath, allFiles, &walker, header, opts, true);
}

const TypeWriterWalker = struct {
    allocator: std.mem.Allocator,
    program: compiler.ProgramLike,

    pub fn init(allocator: std.mem.Allocator, program: compiler.ProgramLike) !TypeWriterWalker {
        return TypeWriterWalker{
            .allocator = allocator,
            .program = program,
        };
    }

    pub fn deinit(self: *TypeWriterWalker) void {
        _ = self;
    }
};

fn checkBaselines(
    allocator: std.mem.Allocator,
    baselinePath: []const u8,
    allFiles: []*harnessutil.TestFile,
    walker: *TypeWriterWalker,
    header: []const u8,
    opts: baseline.Options,
    isSymbolBaseline: bool,
) !void {
    const fullExtension = if (isSymbolBaseline) ".symbols" else ".types";
    var actualBaselinePath: []const u8 = undefined;
    const ext = std.fs.path.extension(baselinePath);
    if (std.mem.eql(u8, ext, ".ts") or std.mem.eql(u8, ext, ".tsx")) {
        actualBaselinePath = try std.mem.replaceOwned(u8, allocator, baselinePath, ext, fullExtension);
    } else {
        actualBaselinePath = try allocator.dupe(u8, baselinePath);
    }
    defer allocator.free(actualBaselinePath);

    const fullBaseline = try generateBaseline(allocator, allFiles, walker, header, isSymbolBaseline);
    defer allocator.free(fullBaseline);

    try baseline.run(allocator, actualBaselinePath, fullBaseline, opts);
}

fn generateBaseline(
    allocator: std.mem.Allocator,
    allFiles: []*harnessutil.TestFile,
    walker: *TypeWriterWalker,
    header: []const u8,
    isSymbolBaseline: bool,
) ![]const u8 {
    _ = isSymbolBaseline;
    _ = walker;
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    for (allFiles) |file| {
        try result.appendSlice("=== ");
        try result.appendSlice(file.unitName);
        try result.appendSlice(" ===\r\n");
        // Simplified parsing, assume we just emit something
    }

    if (result.items.len > 0) {
        return std.fmt.allocPrint(allocator, "//// [{s}] ////\r\n\r\n{s}", .{ header, result.items });
    }
    return try allocator.dupe(u8, baseline.noContent);
}
