const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const types = @import("types.zig");
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;

pub const PseudoChecker = struct {
    strictNullChecks: bool,
    exactOptionalPropertyTypes: bool,

    pub fn init(strictNullChecks: bool, exactOptionalPropertyTypes: bool) PseudoChecker {
        return .{
            .strictNullChecks = strictNullChecks,
            .exactOptionalPropertyTypes = exactOptionalPropertyTypes,
        };
    }
};
