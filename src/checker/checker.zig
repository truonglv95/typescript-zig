const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const ast = @import("../ast/ast.zig");
const symbol = @import("../ast/symbol.zig");
const binder = @import("../binder/binder.zig");
const nameresolver = @import("../binder/nameresolver.zig");
const types = @import("types.zig");

pub const Checker = struct {
    allocator: std.mem.Allocator,
    binder: *binder.Binder,
    resolver: nameresolver.NameResolver,
    typesList: std.ArrayListUnmanaged(types.Type),

    // Cache for intrinsic types to avoid duplicates
    numberTypeIndex: ?u32 = null,
    anyTypeIndex: ?u32 = null,
    stringTypeIndex: ?u32 = null,
    booleanTypeIndex: ?u32 = null,
    voidTypeIndex: ?u32 = null,
    undefinedTypeIndex: ?u32 = null,
    nullTypeIndex: ?u32 = null,
    unknownTypeIndex: ?u32 = null,

    pub fn init(allocator: std.mem.Allocator, b: *binder.Binder) Checker {
        return .{
            .allocator = allocator,
            .binder = b,
            .resolver = nameresolver.NameResolver.init(b.ast, b),
            .typesList = std.ArrayListUnmanaged(types.Type).empty,
        };
    }

    pub fn deinit(self: *Checker) void {
        self.typesList.deinit(self.allocator);
    }

    fn createType(self: *Checker, t: types.Type) !u32 {
        const index = @as(u32, @intCast(self.typesList.items.len));
        try self.typesList.append(self.allocator, t);
        return index;
    }

    pub fn getNumberType(self: *Checker) !u32 {
        if (self.numberTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .Flags = types.TypeFlags.Number, .ObjectFlags = 0, .Symbol = null, .Data = .{ .Intrinsic = {} } });
        self.numberTypeIndex = idx;
        return idx;
    }

    pub fn getAnyType(self: *Checker) !u32 {
        if (self.anyTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .Flags = types.TypeFlags.Any, .ObjectFlags = 0, .Symbol = null, .Data = .{ .Intrinsic = {} } });
        self.anyTypeIndex = idx;
        return idx;
    }

    pub fn getStringType(self: *Checker) !u32 {
        if (self.stringTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .Flags = types.TypeFlags.String, .ObjectFlags = 0, .Symbol = null, .Data = .{ .Intrinsic = {} } });
        self.stringTypeIndex = idx;
        return idx;
    }

    pub fn getBooleanType(self: *Checker) !u32 {
        if (self.booleanTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .Flags = types.TypeFlags.Boolean, .ObjectFlags = 0, .Symbol = null, .Data = .{ .Intrinsic = {} } });
        self.booleanTypeIndex = idx;
        return idx;
    }

    pub fn getVoidType(self: *Checker) !u32 {
        if (self.voidTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .Flags = types.TypeFlags.Void, .ObjectFlags = 0, .Symbol = null, .Data = .{ .Intrinsic = {} } });
        self.voidTypeIndex = idx;
        return idx;
    }

    pub fn getUndefinedType(self: *Checker) !u32 {
        if (self.undefinedTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .Flags = types.TypeFlags.Undefined, .ObjectFlags = 0, .Symbol = null, .Data = .{ .Intrinsic = {} } });
        self.undefinedTypeIndex = idx;
        return idx;
    }

    pub fn getTypeOfSymbol(self: *Checker, symIndex: u32) anyerror!u32 {
        const sym = self.binder.symbols.items[symIndex];
        if (sym.ValueDeclaration) |declIndex| {
            return try self.getTypeOfNode(declIndex);
        }
        return try self.getAnyType();
    }

    pub fn getTypeOfNode(self: *Checker, nodeIndex: u32) anyerror!u32 {
        const node = self.binder.ast.getNode(nodeIndex);
        switch (node) {
            .Parameter => |p| {
                if (p.Type) |typeNodeIndex| {
                    return try self.getTypeOfNode(typeNodeIndex);
                }
                return try self.getAnyType();
            },
            .NumberKeyword => return try self.getNumberType(),
            .StringKeyword => return try self.getStringType(),
            .BooleanKeyword => return try self.getBooleanType(),
            .VoidKeyword => return try self.getVoidType(),
            .UndefinedKeyword => return try self.getUndefinedType(),
            .AnyKeyword => return try self.getAnyType(),
            .VariableDeclaration => |decl| {
                if (decl.Type) |typeNode| return try self.getTypeOfNode(typeNode);
                if (decl.Initializer) |initExpr| return try self.checkExpression(initExpr);
                return try self.getAnyType();
            },
            .PropertyDeclaration => |p| {
                if (p.Type) |typeNode| return try self.getTypeOfNode(typeNode);
                if (p.Initializer) |initExpr| return try self.checkExpression(initExpr);
                return try self.getAnyType();
            },
            .PropertySignature => {
                return try self.getAnyType();
            },
            .MethodDeclaration => |m| {
                if (m.Type) |t| return try self.getTypeOfNode(t);
                return try self.getAnyType();
            },
            .FunctionDeclaration => |f| {
                if (f.Type) |t| return try self.getTypeOfNode(t);
                return try self.getAnyType();
            },
            else => return try self.getAnyType(),
        }
    }

    pub fn checkExpression(self: *Checker, nodeIndex: u32) anyerror!u32 {
        const node = self.binder.ast.getNode(nodeIndex);
        switch (node) {
            .Identifier => |id| {
                if (self.resolver.resolve(nodeIndex, id.Text, symbol.SymbolFlags.Value)) |symIndex| {
                    return try self.getTypeOfSymbol(symIndex);
                }
                return try self.getAnyType();
            },
            .TrueKeyword, .FalseKeyword => return try self.getBooleanType(),
            .StringLiteral => |s| {
                return try self.createType(.{
                    .Flags = types.TypeFlags.StringLiteral,
                    .ObjectFlags = 0,
                    .Symbol = null,
                    .Data = .{ .StringLiteral = .{ .text = s.Text } },
                });
            },
            .NumericLiteral => |n| {
                const value = std.fmt.parseFloat(f64, n.Text) catch 0.0;
                return try self.createType(.{
                    .Flags = types.TypeFlags.NumberLiteral,
                    .ObjectFlags = 0,
                    .Symbol = null,
                    .Data = .{ .NumberLiteral = .{ .value = value } },
                });
            },
            .BinaryExpression => |bin| {
                const leftType = try self.checkExpression(bin.Left);
                const rightType = try self.checkExpression(bin.Right);

                const leftNode = self.typesList.items[leftType];
                const rightNode = self.typesList.items[rightType];

                if (leftNode.Flags == types.TypeFlags.Number and rightNode.Flags == types.TypeFlags.Number) {
                    return try self.getNumberType();
                }
                return try self.getAnyType();
            },
            else => return try self.getAnyType(),
        }
    }

    pub fn checkStatement(self: *Checker, nodeIndex: u32) anyerror!void {
        const node = self.binder.ast.getNode(nodeIndex);
        switch (node) {
            .ReturnStatement => |ret| {
                if (ret.Expression) |expr| {
                    _ = try self.checkExpression(expr);
                }
            },
            .VariableStatement => |varStmt| {
                try self.checkStatement(varStmt.DeclarationList);
            },
            .VariableDeclarationList => |varList| {
                if (varList.Declarations != 0) {
                    const decls = self.binder.ast.getNodeList(varList.Declarations);
                    for (decls) |decl| {
                        try self.checkStatement(decl);
                    }
                }
            },
            .VariableDeclaration => |decl| {
                // Infer from initializer if exists
                var initType = try self.getAnyType();
                if (decl.Initializer) |initExpr| {
                    initType = try self.checkExpression(initExpr);
                }
                
                // If type annotation exists, use it
                var declaredType = try self.getAnyType();
                if (decl.Type) |typeNode| {
                    declaredType = try self.getTypeOfNode(typeNode);
                }

                // If no type annotation, infer from initializer
                _ = if (decl.Type != null) declaredType else initType;
            },
            .Block => |blk| {
                if (blk.Statements != 0) {
                    const stmts = self.binder.ast.getNodeList(blk.Statements);
                    for (stmts) |stmt| {
                        try self.checkStatement(stmt);
                    }
                }
            },
            .FunctionDeclaration => |f| {
                if (f.Body) |body| {
                    try self.checkStatement(body);
                }
            },
            .SourceFile => |sf| {
                if (sf.Statements != 0) {
                    const stmts = self.binder.ast.getNodeList(sf.Statements);
                    for (stmts) |stmt| {
                        try self.checkStatement(stmt);
                    }
                }
            },
            else => {},
        }
    }
};
