const std = @import("std");
const program_pkg = @import("program.zig");
const core = @import("../core/core.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const emitter_mod = @import("emitter.zig");

// System interface is loosely defined here or we can just use io
// But tsc.zig uses `system.System`. Let's just use what's passed in.
// We will define a minimal facade.

pub const Compiler = struct {
    allocator: std.mem.Allocator,
    program: program_pkg.Program,

    pub fn init(allocator: std.mem.Allocator, args: program_pkg.ProgramOptions) Compiler {
        return .{
            .allocator = allocator,
            .program = program_pkg.Program.init(allocator, args),
        };
    }

    pub fn deinit(self: *Compiler) void {
        self.program.deinit();
    }

    pub fn performCompilation(self: *Compiler, io: std.Io) !void {
        try self.program.load(io);
        try self.program.bind();
        try self.program.link();
        try self.program.check();
    }

    pub fn getDiagnostics(self: *Compiler) []program_pkg.ProgramDiagnostic {
        return self.program.diagnostics.items;
    }

    pub fn hasErrorDiagnostics(self: *Compiler) bool {
        return self.program.hasErrorDiagnostics();
    }

    pub fn emitFiles(self: *Compiler) !?*emitter_mod.EmitResult {
        return self.program.emit(.EmitAll);
    }
};
