const std = @import("std");
const ast = @import("../ast/ast.zig");
// const compiler = @import("../compiler/compiler.zig");
// const tsoptions = @import("../tsoptions/tsoptions.zig");
// const diagnostics = @import("../diagnostics/diagnostics.zig");

const system = @import("system.zig");

pub const CommandLineTesting = ?*anyopaque;

pub const ExitStatus = enum {
    Success,
    DiagnosticsPresent_OutputsSkipped,
    DiagnosticsPresent_OutputsGenerated,
    NotImplemented,
};

pub const CommandLineResult = struct {
    status: ExitStatus,
    watcher: ?*anyopaque = null, // Placeholder for Watcher
};

pub fn startTracingIfNeeded(sys: *system.System, config: *anyopaque, testing: CommandLineTesting) ?*anyopaque {
    _ = sys;
    _ = config;
    _ = testing;
    return null;
}

pub fn stopTracing(sys: *system.System, tr: ?*anyopaque) void {
    _ = sys;
    _ = tr;
}

pub fn commandLine(ctx: *anyopaque, sys: *system.System, commandLineArgs: [][]const u8, testing: CommandLineTesting) CommandLineResult {
    if (commandLineArgs.len > 0) {
        const cmd = commandLineArgs[0];
        if (std.mem.eql(u8, cmd, "-b") or std.mem.eql(u8, cmd, "--b") or std.mem.eql(u8, cmd, "-build") or std.mem.eql(u8, cmd, "--build")) {
            return tscBuildCompilation(ctx, sys, commandLineArgs, testing);
        }
    }
    return tscCompilation(ctx, sys, commandLineArgs, testing);
}

fn tscBuildCompilation(ctx: *anyopaque, sys: *system.System, args: [][]const u8, testing: CommandLineTesting) CommandLineResult {
    _ = ctx;
    _ = sys;
    _ = args;
    _ = testing;
    // TODO: Implement build compilation
    return .{ .status = .NotImplemented };
}

fn tscCompilation(ctx: *anyopaque, sys: *system.System, args: [][]const u8, testing: CommandLineTesting) CommandLineResult {
    _ = ctx;
    _ = sys;
    _ = args;
    _ = testing;
    // TODO: Implement regular compilation
    return .{ .status = .NotImplemented };
}

fn performIncrementalCompilation() CommandLineResult {
    return .{ .status = .NotImplemented };
}

fn performCompilation() CommandLineResult {
    return .{ .status = .NotImplemented };
}

fn showConfig() void {}
