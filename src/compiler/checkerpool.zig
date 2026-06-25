const std = @import("std");
const ast = @import("../ast/pkg.zig");
const checker = @import("../checker/pkg.zig");
const core = @import("../core/pkg.zig");
const tracing = @import("../tracing/pkg.zig");

// Assuming Program is accessible or will be
const Program = @import("program.zig").Program;

pub const CheckerPool = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        getChecker: *const fn (ptr: *anyopaque, ctx: ?*anyopaque, file: ?ast.SourceFileIndex) *checker.Checker,
    };

    pub fn getChecker(self: CheckerPool, ctx: ?*anyopaque, file: ?ast.SourceFileIndex) *checker.Checker {
        return self.vtable.getChecker(self.ptr, ctx, file);
    }
};

pub const CheckerPoolImpl = struct {
    program: *Program,
    tracing: ?*tracing.Tracing,

    createCheckersOnce: std.once,
    checkers: []?*checker.Checker,
    locks: []std.Thread.Mutex,
    fileAssociations: std.AutoHashMap(ast.SourceFileIndex, *checker.Checker),

    // In a full DoD implementation, we might avoid pointers to Checkers and use indices into an array
};
