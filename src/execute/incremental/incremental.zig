const std = @import("std");
const ast = @import("../../ast/ast.zig");
const compiler = @import("../../compiler/compiler.zig");

// Skeleton for incremental compilation
pub const BuildInfoReader = struct {
    host: *compiler.CompilerHost,

    pub fn init(host: *compiler.CompilerHost) BuildInfoReader {
        return .{
            .host = host,
        };
    }
};

pub const IncrementalProgram = struct {
    program: *compiler.Program,
    oldProgram: ?*compiler.Program,

    pub fn init(program: *compiler.Program, oldProgram: ?*compiler.Program) IncrementalProgram {
        return .{
            .program = program,
            .oldProgram = oldProgram,
        };
    }

    pub fn getProgram(self: *IncrementalProgram) *compiler.Program {
        return self.program;
    }
};

pub fn readBuildInfoProgram(options: *compiler.CompilerOptions, reader: BuildInfoReader, host: *compiler.CompilerHost) ?*compiler.Program {
    _ = options;
    _ = reader;
    _ = host;
    return null;
}
