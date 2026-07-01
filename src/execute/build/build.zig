const std = @import("std");
const ast = @import("../../ast/ast.zig");
const compiler = @import("../../compiler/compiler.zig");
const tsc = @import("../tsc/emit.zig");

// Skeleton for project build
pub const Options = struct {
    sys: *anyopaque, // placeholder
    command: *anyopaque, // placeholder
    testing: ?*anyopaque, // placeholder
};

pub const Orchestrator = struct {
    options: Options,

    pub fn init(options: Options) Orchestrator {
        return .{
            .options = options,
        };
    }

    pub fn start(self: *Orchestrator) tsc.CompileAndEmitResult {
        _ = self;
        return .{
            .status = .NotImplemented,
            .diagnostics = &.{},
            .emitResult = null,
            .times = undefined,
        };
    }
};
