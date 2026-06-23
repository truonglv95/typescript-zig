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

    /// Resolve tên symbol bắt đầu từ node `startLocation` trở lên scope chain.
    /// Tuân thủ đúng TypeScript scope resolution: block → function → file → global
    pub fn resolve(self: *NameResolver, startLocation: ast_gen.NodeIndex, name: []const u8, meaning: u32) ?ast_gen.SymbolIndex {
        var location: ast_gen.NodeIndex = startLocation;

        while (location != 0) {
            // Check locals của container node hiện tại
            if (self.binder.nodeLocals.get(location)) |locals| {
                if (locals.get(name)) |symIndex| {
                    const sym = self.binder.symbols.items[symIndex];
                    if ((sym.Flags & meaning) != 0) {
                        return symIndex;
                    }
                }
            }

            // Check symbol exports của node (nếu là module/class)
            if (self.binder.symbolExports.get(location)) |exports| {
                if (exports.get(name)) |symIndex| {
                    const sym = self.binder.symbols.items[symIndex];
                    if ((sym.Flags & meaning) != 0) {
                        return symIndex;
                    }
                }
            }

            location = self.ast.parents.items[location];
        }

        // Không tìm thấy trong scope chain – fallback: tìm trong tất cả symbols (global-like)
        return self.resolveGlobal(name, meaning);
    }

    /// Tìm symbol trong global scope (node 0 = SourceFile locals)
    fn resolveGlobal(self: *NameResolver, name: []const u8, meaning: u32) ?ast_gen.SymbolIndex {
        // File node là index 1 (index 0 là sentinel)
        if (self.binder.nodeLocals.get(1)) |locals| {
            if (locals.get(name)) |symIndex| {
                const sym = self.binder.symbols.items[symIndex];
                if ((sym.Flags & meaning) != 0) {
                    return symIndex;
                }
            }
        }

        // Fallback: linear scan qua tất cả symbols
        for (self.binder.symbols.items, 0..) |sym, i| {
            if (i == 0) continue; // skip sentinel
            if (std.mem.eql(u8, sym.Name, name) and (sym.Flags & meaning) != 0) {
                return @as(ast_gen.SymbolIndex, @intCast(i));
            }
        }

        return null;
    }

    /// Resolve member access: `object.member`
    /// Tìm kiếm trong symbol.Members của object type
    pub fn resolveMember(self: *NameResolver, objectSymIndex: ast_gen.SymbolIndex, memberName: []const u8, meaning: u32) ?ast_gen.SymbolIndex {
        const sym = self.binder.symbols.items[objectSymIndex];

        // Check members
        for (sym.Members.items) |entry| {
            if (std.mem.eql(u8, entry.name, memberName)) {
                const memberSym = self.binder.symbols.items[entry.symbolIndex];
                if ((memberSym.Flags & meaning) != 0) {
                    return entry.symbolIndex;
                }
            }
        }

        // Check exports (for modules/namespaces)
        for (sym.Exports.items) |entry| {
            if (std.mem.eql(u8, entry.name, memberName)) {
                const exportSym = self.binder.symbols.items[entry.symbolIndex];
                if ((exportSym.Flags & meaning) != 0) {
                    return entry.symbolIndex;
                }
            }
        }

        return null;
    }

    /// Resolve symbol từ symbolMembers map của binder
    pub fn resolveFromSymbolMembers(self: *NameResolver, symIndex: ast_gen.SymbolIndex, memberName: []const u8, meaning: u32) ?ast_gen.SymbolIndex {
        if (self.binder.symbolMembers.get(symIndex)) |members| {
            if (members.get(memberName)) |memberSymIdx| {
                const memberSym = self.binder.symbols.items[memberSymIdx];
                if ((memberSym.Flags & meaning) != 0) {
                    return memberSymIdx;
                }
            }
        }
        return null;
    }
};
