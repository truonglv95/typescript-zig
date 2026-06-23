const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const symbol = @import("../ast/symbol.zig");
const ast = @import("../ast/ast.zig");
const binder = @import("binder.zig");

pub const NameResolver = struct {
    ast: *ast.Ast,
    binder: *binder.Binder,

    pub fn init(a: *ast.Ast, b: *binder.Binder) NameResolver {
        return .{
            .ast = a,
            .binder = b,
        };
    }

    pub fn resolve(self: *NameResolver, startLocation: ast_gen.NodeIndex, name: []const u8, meaning: u32) ?ast_gen.SymbolIndex {
        var location: ast_gen.NodeIndex = startLocation;

        while (location != 0) {
            if (self.binder.nodeLocals.get(location)) |locals| {
                if (locals.get(name)) |symIndex| {
                    const sym = self.binder.symbols.items[symIndex];
                    if ((sym.Flags & meaning) != 0) {
                        return symIndex;
                    }
                }
            }
            location = self.ast.parents.items[location];
        }

        return null;
    }
};
