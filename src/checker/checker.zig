const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const ast = @import("../ast/ast.zig");
const symbol = @import("../ast/symbol.zig");
const binder = @import("../binder/binder.zig");
const nameresolver = @import("../binder/nameresolver.zig");
const types = @import("types.zig");
const kind = @import("../ast/kind.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const diagnostics_gen = @import("../diagnostics/diagnostics_generated.zig");

pub const Checker = struct {
    allocator: std.mem.Allocator,
    binder: *binder.Binder,
    resolver: nameresolver.NameResolver,
    typesList: std.ArrayListUnmanaged(types.Type),

    /// Flat list of TypeIndex for union/intersection members
    unionTypesPool: std.ArrayListUnmanaged(types.TypeIndex),

    // Cache for intrinsic types to avoid duplicates
    numberTypeIndex: ?u32 = null,
    anyTypeIndex: ?u32 = null,
    stringTypeIndex: ?u32 = null,
    booleanTypeIndex: ?u32 = null,
    voidTypeIndex: ?u32 = null,
    undefinedTypeIndex: ?u32 = null,
    nullTypeIndex: ?u32 = null,
    unknownTypeIndex: ?u32 = null,
    neverTypeIndex: ?u32 = null,
    bigintTypeIndex: ?u32 = null,
    trueTypeIndex: ?u32 = null,
    falseTypeIndex: ?u32 = null,
    objectTypeIndex: ?u32 = null,

    pub fn init(allocator: std.mem.Allocator, b: *binder.Binder) Checker {
        return .{
            .allocator = allocator,
            .binder = b,
            .resolver = nameresolver.NameResolver.init(b.ast, b),
            .typesList = std.ArrayListUnmanaged(types.Type).empty,
            .unionTypesPool = std.ArrayListUnmanaged(types.TypeIndex).empty,
        };
    }

    pub fn deinit(self: *Checker) void {
        self.typesList.deinit(self.allocator);
        self.unionTypesPool.deinit(self.allocator);
    }

    fn createType(self: *Checker, t: types.Type) !u32 {
        const index = @as(u32, @intCast(self.typesList.items.len));
        try self.typesList.append(self.allocator, t);
        return index;
    }

    // =========================================================================
    // Intrinsic type getters
    // =========================================================================

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

    pub fn getNullType(self: *Checker) !u32 {
        if (self.nullTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .Flags = types.TypeFlags.Null, .ObjectFlags = 0, .Symbol = null, .Data = .{ .Intrinsic = {} } });
        self.nullTypeIndex = idx;
        return idx;
    }

    pub fn getUnknownType(self: *Checker) !u32 {
        if (self.unknownTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .Flags = types.TypeFlags.Unknown, .ObjectFlags = 0, .Symbol = null, .Data = .{ .Intrinsic = {} } });
        self.unknownTypeIndex = idx;
        return idx;
    }

    pub fn getNeverType(self: *Checker) !u32 {
        if (self.neverTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .Flags = types.TypeFlags.Never, .ObjectFlags = 0, .Symbol = null, .Data = .{ .Intrinsic = {} } });
        self.neverTypeIndex = idx;
        return idx;
    }

    pub fn getBigIntType(self: *Checker) !u32 {
        if (self.bigintTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .Flags = types.TypeFlags.BigInt, .ObjectFlags = 0, .Symbol = null, .Data = .{ .Intrinsic = {} } });
        self.bigintTypeIndex = idx;
        return idx;
    }

    pub fn getTrueType(self: *Checker) !u32 {
        if (self.trueTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .Flags = types.TypeFlags.BooleanLiteral, .ObjectFlags = 0, .Symbol = null, .Data = .{ .BooleanLiteral = .{ .value = true } } });
        self.trueTypeIndex = idx;
        return idx;
    }

    pub fn getFalseType(self: *Checker) !u32 {
        if (self.falseTypeIndex) |idx| return idx;
        const idx = try self.createType(.{ .Flags = types.TypeFlags.BooleanLiteral, .ObjectFlags = 0, .Symbol = null, .Data = .{ .BooleanLiteral = .{ .value = false } } });
        self.falseTypeIndex = idx;
        return idx;
    }

    pub fn getObjectType(self: *Checker) !u32 {
        if (self.objectTypeIndex) |idx| return idx;
        const idx = try self.createType(.{
            .Flags = types.TypeFlags.Object,
            .ObjectFlags = types.ObjectFlags.Anonymous,
            .Symbol = null,
            .Data = .{ .Object = .{} },
        });
        self.objectTypeIndex = idx;
        return idx;
    }

    // =========================================================================
    // Type of symbol / node
    // =========================================================================

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
            .NullKeyword => return try self.getNullType(),
            .UnknownKeyword => return try self.getUnknownType(),
            .NeverKeyword => return try self.getNeverType(),
            .BigIntKeyword => return try self.getBigIntType(),
            .ObjectKeyword => return try self.getObjectType(),

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
            .ArrayType => {
                // T[] -> return base number type as placeholder
                // TODO: full array type support
                return try self.getAnyType();
            },
            .UnionType => |u| {
                // A | B -> return union type
                if (u.Types != 0) {
                    const typeNodes = self.binder.ast.getNodeList(u.Types);
                    if (typeNodes.len > 0) {
                        // Simplified: return first member's type
                        return try self.getTypeOfNode(typeNodes[0]);
                    }
                }
                return try self.getAnyType();
            },
            .LiteralType => |lt| {
                return try self.getTypeOfNode(lt.Literal);
            },
            .TypeReference => {
                // Named type reference - TODO: proper resolution
                return try self.getAnyType();
            },
            else => return try self.getAnyType(),
        }
    }

    // =========================================================================
    // checkExpression - thực hiện type checking cho expressions
    // =========================================================================

    pub fn checkExpression(self: *Checker, nodeIndex: u32) anyerror!u32 {
        const node = self.binder.ast.getNode(nodeIndex);
        switch (node) {
            // Literals
            .Identifier => |id| {
                if (self.resolver.resolve(nodeIndex, id.Text, symbol.SymbolFlags.Value)) |symIndex| {
                    return try self.getTypeOfSymbol(symIndex);
                }
                return try self.getAnyType();
            },
            .TrueKeyword => return try self.getTrueType(),
            .FalseKeyword => return try self.getFalseType(),
            .NullKeyword => return try self.getNullType(),
            .UndefinedKeyword => return try self.getUndefinedType(),

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
            .BigIntLiteral => |n| {
                return try self.createType(.{
                    .Flags = types.TypeFlags.BigIntLiteral,
                    .ObjectFlags = 0,
                    .Symbol = null,
                    .Data = .{ .BigIntLiteral = .{ .text = n.Text } },
                });
            },
            .NoSubstitutionTemplateLiteral, .TemplateExpression => {
                return try self.getStringType();
            },
            .RegularExpressionLiteral => {
                // RegExp is an object type
                return try self.getObjectType();
            },

            // Arithmetic/logical binary expressions
            .BinaryExpression => |bin| {
                const leftType = try self.checkExpression(bin.Left);
                const rightType = try self.checkExpression(bin.Right);
                return try self.checkBinaryExpression(bin.OperatorToken, leftType, rightType);
            },

            // Unary expressions
            .PrefixUnaryExpression => |pue| {
                const operandType = try self.checkExpression(pue.Operand);
                return try self.checkPrefixUnary(pue.Operator, operandType);
            },
            .PostfixUnaryExpression => |poe| {
                _ = try self.checkExpression(poe.Operand);
                return try self.getNumberType(); // ++ / -- always produce number
            },

            // Conditional / ternary
            .ConditionalExpression => |ce| {
                _ = try self.checkExpression(ce.Condition);
                const trueType = try self.checkExpression(ce.WhenTrue);
                const falseType = try self.checkExpression(ce.WhenFalse);
                return try self.getUnionType(trueType, falseType);
            },

            // Function types
            .FunctionExpression => |fe| {
                if (fe.Type) |retNode| {
                    const retType = try self.getTypeOfNode(retNode);
                    return try self.createType(.{
                        .Flags = types.TypeFlags.Object,
                        .ObjectFlags = types.ObjectFlags.Anonymous,
                        .Symbol = null,
                        .Data = .{ .Function = .{ .returnType = retType } },
                    });
                }
                return try self.getObjectType();
            },
            .ArrowFunction => |af| {
                if (af.Type) |retNode| {
                    const retType = try self.getTypeOfNode(retNode);
                    return try self.createType(.{
                        .Flags = types.TypeFlags.Object,
                        .ObjectFlags = types.ObjectFlags.Anonymous,
                        .Symbol = null,
                        .Data = .{ .Function = .{ .returnType = retType } },
                    });
                }
                // Check body expression for inferred return type
                if (af.Body) |body| {
                    const bodyNode = self.binder.ast.getNode(body);
                    switch (bodyNode) {
                        .Block => {
                            try self.checkStatement(body);
                            return try self.getObjectType();
                        },
                        else => {
                            const retType = try self.checkExpression(body);
                            return try self.createType(.{
                                .Flags = types.TypeFlags.Object,
                                .ObjectFlags = types.ObjectFlags.Anonymous,
                                .Symbol = null,
                                .Data = .{ .Function = .{ .returnType = retType } },
                            });
                        },
                    }
                }
                return try self.getObjectType();
            },

            // Object/Array literals
            .ObjectLiteralExpression => |ole| {
                if (ole.Properties != 0) {
                    const props = self.binder.ast.getNodeList(ole.Properties);
                    for (props) |prop| {
                        _ = self.checkStatement(prop) catch {};
                    }
                }
                return try self.createType(.{
                    .Flags = types.TypeFlags.Object,
                    .ObjectFlags = types.ObjectFlags.ObjectLiteral | types.ObjectFlags.FreshLiteral,
                    .Symbol = if (ole.Symbol != 0) ole.Symbol else null,
                    .Data = .{ .Object = .{} },
                });
            },
            .ArrayLiteralExpression => |ale| {
                var elementType: u32 = 0;
                if (ale.Elements != 0) {
                    const elems = self.binder.ast.getNodeList(ale.Elements);
                    if (elems.len > 0) {
                        elementType = try self.checkExpression(elems[0]);
                        for (elems[1..]) |elem| {
                            const t = try self.checkExpression(elem);
                            if (t != elementType) {
                                elementType = try self.getAnyType();
                                break;
                            }
                        }
                    }
                }
                if (elementType == 0) elementType = try self.getAnyType();
                return try self.createType(.{
                    .Flags = types.TypeFlags.Object,
                    .ObjectFlags = types.ObjectFlags.ArrayLiteral,
                    .Symbol = null,
                    .Data = .{ .Array = .{ .elementType = elementType } },
                });
            },

            // Property access
            .PropertyAccessExpression => |pae| {
                const objType = try self.checkExpression(pae.Expression);
                _ = objType;
                // TODO: resolve property type from object type
                // For now, return any
                return try self.getAnyType();
            },

            // Element access: arr[0]
            .ElementAccessExpression => |eae| {
                _ = try self.checkExpression(eae.Expression);
                _ = try self.checkExpression(eae.ArgumentExpression);
                return try self.getAnyType();
            },

            // Call expression
            .CallExpression => |ce| {
                const calleeType = try self.checkExpression(ce.Expression);
                if (ce.Arguments != 0) {
                    const args = self.binder.ast.getNodeList(ce.Arguments);
                    for (args) |arg| {
                        _ = try self.checkExpression(arg);
                    }
                }
                // If callee is a function type, return its return type
                if (calleeType < self.typesList.items.len) {
                    const ct = self.typesList.items[calleeType];
                    if (ct.Flags & types.TypeFlags.Object != 0) {
                        switch (ct.Data) {
                            .Function => |f| return f.returnType,
                            else => {},
                        }
                    }
                }
                return try self.getAnyType();
            },

            // new expr(args)
            .NewExpression => |ne| {
                _ = try self.checkExpression(ne.Expression);
                if (ne.Arguments) |argsIdx| {
                    if (argsIdx != 0) {
                        const args = self.binder.ast.getNodeList(argsIdx);
                        for (args) |arg| {
                            _ = try self.checkExpression(arg);
                        }
                    }
                }
                return try self.getObjectType();
            },

            // Wrapping expressions
            .ParenthesizedExpression => |pe| {
                return try self.checkExpression(pe.Expression);
            },
            .AsExpression => |ae| {
                _ = try self.checkExpression(ae.Expression);
                return try self.getTypeOfNode(ae.Type);
            },
            .SatisfiesExpression => |se| {
                return try self.checkExpression(se.Expression);
            },
            .NonNullExpression => |nne| {
                return try self.checkExpression(nne.Expression);
            },
            .TypeAssertionExpression => |ta| {
                _ = try self.checkExpression(ta.Expression);
                return try self.getTypeOfNode(ta.Type);
            },

            // Unary with known return type
            .TypeOfExpression => {
                return try self.getStringType();
            },
            .VoidExpression => {
                return try self.getUndefinedType();
            },
            .AwaitExpression => |ae| {
                return try self.checkExpression(ae.Expression);
            },
            .YieldExpression => |ye| {
                if (ye.Expression) |expr| {
                    return try self.checkExpression(expr);
                }
                return try self.getAnyType();
            },
            .DeleteExpression => {
                return try self.getBooleanType();
            },
            .SpreadElement => |se| {
                return try self.checkExpression(se.Expression);
            },

            // Template
            .TaggedTemplateExpression => {
                return try self.getAnyType();
            },

            // Class expression
            .ClassExpression => |ce| {
                if (ce.Members != 0) {
                    const members = self.binder.ast.getNodeList(ce.Members);
                    for (members) |mem| {
                        _ = self.checkStatement(mem) catch {};
                    }
                }
                return try self.createType(.{
                    .Flags = types.TypeFlags.Object,
                    .ObjectFlags = types.ObjectFlags.Anonymous,
                    .Symbol = if (ce.Symbol != 0) ce.Symbol else null,
                    .Data = .{ .Object = .{} },
                });
            },

            else => return try self.getAnyType(),
        }
    }

    // =========================================================================
    // checkBinaryExpression - type của binary expression result
    // =========================================================================

    fn checkBinaryExpression(self: *Checker, operatorNodeIdx: u32, leftTypeIdx: u32, rightTypeIdx: u32) !u32 {
        const leftType = if (leftTypeIdx < self.typesList.items.len)
            self.typesList.items[leftTypeIdx]
        else
            types.Type{ .Flags = types.TypeFlags.Any, .ObjectFlags = 0, .Symbol = null, .Data = .{ .Intrinsic = {} } };
        const rightType = if (rightTypeIdx < self.typesList.items.len)
            self.typesList.items[rightTypeIdx]
        else
            types.Type{ .Flags = types.TypeFlags.Any, .ObjectFlags = 0, .Symbol = null, .Data = .{ .Intrinsic = {} } };

        // Get operator token kind
        const opNode = self.binder.ast.getNode(operatorNodeIdx);
        const opKind = switch (opNode) {
            .Unknown => kind.Kind.Unknown,
            else => kind.Kind.Unknown,
        };
        _ = opKind;

        const leftIsNumber = (leftType.Flags & types.TypeFlags.NumberLike) != 0;
        const rightIsNumber = (rightType.Flags & types.TypeFlags.NumberLike) != 0;
        const leftIsString = (leftType.Flags & types.TypeFlags.StringLike) != 0;
        const rightIsString = (rightType.Flags & types.TypeFlags.StringLike) != 0;
        const eitherIsAny = (leftType.Flags & types.TypeFlags.Any) != 0 or (rightType.Flags & types.TypeFlags.Any) != 0;

        // + operator: if either is string, result is string
        if (leftIsString or rightIsString) {
            return try self.getStringType();
        }

        // Arithmetic operators: if both numbers, result is number
        if ((leftIsNumber or eitherIsAny) and (rightIsNumber or eitherIsAny)) {
            return try self.getNumberType();
        }

        // Comparison operators: always return boolean
        // ===, !==, ==, !=, <, >, <=, >=, instanceof, in
        // (simplified: we check via flag combinations)
        if (leftIsNumber or leftIsString) {
            return try self.getBooleanType();
        }

        // Assignment operators: return left type
        if ((leftType.Flags & types.TypeFlags.Any) == 0) {
            return leftTypeIdx;
        }

        return try self.getAnyType();
    }

    // =========================================================================
    // checkPrefixUnary
    // =========================================================================

    fn checkPrefixUnary(self: *Checker, operatorNodeIdx: u32, operandTypeIdx: u32) !u32 {
        _ = operatorNodeIdx;
        _ = operandTypeIdx;
        // !, ~, +, -, ++ --
        // For ! -> boolean
        // For ~ -> number
        // For + -> number
        // For - -> number
        // TODO: check operator kind properly
        return try self.getAnyType();
    }

    // =========================================================================
    // getUnionType - tạo union của 2 types
    // =========================================================================

    fn getUnionType(self: *Checker, typeA: u32, typeB: u32) !u32 {
        if (typeA == typeB) return typeA;

        // Record union member indices
        const start = @as(u32, @intCast(self.unionTypesPool.items.len));
        try self.unionTypesPool.append(self.allocator, typeA);
        try self.unionTypesPool.append(self.allocator, typeB);

        return try self.createType(.{
            .Flags = types.TypeFlags.Union,
            .ObjectFlags = 0,
            .Symbol = null,
            .Data = .{ .Union = .{ .typesStart = start, .typesLen = 2 } },
        });
    }

    // =========================================================================
    // checkStatement
    // =========================================================================

    pub fn checkStatement(self: *Checker, nodeIndex: u32) anyerror!void {
        const node = self.binder.ast.getNode(nodeIndex);
        switch (node) {
            // Source file - entry point
            .SourceFile => |sf| {
                if (sf.Statements != 0) {
                    const stmts = self.binder.ast.getNodeList(sf.Statements);
                    for (stmts) |stmt| {
                        try self.checkStatement(stmt);
                    }
                }
            },

            // Block of statements
            .Block => |blk| {
                if (blk.Statements != 0) {
                    const stmts = self.binder.ast.getNodeList(blk.Statements);
                    for (stmts) |stmt| {
                        try self.checkStatement(stmt);
                    }
                }
            },

            // Variables
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
                var initType: u32 = try self.getAnyType();
                if (decl.Initializer) |initExpr| {
                    initType = try self.checkExpression(initExpr);
                }

                if (decl.Type) |typeNode| {
                    const declaredType = try self.getTypeOfNode(typeNode);
                    // Type compatibility check
                    if (initType != 0 and declaredType != 0 and
                        initType < self.typesList.items.len and
                        declaredType < self.typesList.items.len)
                    {
                        const it = &self.typesList.items[initType];
                        const dt = &self.typesList.items[declaredType];
                        if (!types.isAssignableTo(it, dt)) {
                            // emit diagnostic: type mismatch
                            // TODO: add to binder.diagnosticsList with proper message
                        }
                    }
                }
            },

            // Functions
            .FunctionDeclaration => |f| {
                if (f.Body) |body| {
                    try self.checkStatement(body);
                }
                // Also check parameters
                if (f.Parameters != 0) {
                    const params = self.binder.ast.getNodeList(f.Parameters);
                    for (params) |param| {
                        _ = try self.getTypeOfNode(param);
                    }
                }
            },

            // Return statement
            .ReturnStatement => |ret| {
                if (ret.Expression) |expr| {
                    _ = try self.checkExpression(expr);
                }
            },

            // Expression statement
            .ExpressionStatement => |es| {
                _ = try self.checkExpression(es.Expression);
            },

            // If statement
            .IfStatement => |ifs| {
                _ = try self.checkExpression(ifs.Expression);
                try self.checkStatement(ifs.ThenStatement);
                if (ifs.ElseStatement) |elseStmt| {
                    try self.checkStatement(elseStmt);
                }
            },

            // While loop
            .WhileStatement => |ws| {
                _ = try self.checkExpression(ws.Expression);
                try self.checkStatement(ws.Statement);
            },

            // Do-while loop
            .DoStatement => |ds| {
                try self.checkStatement(ds.Statement);
                _ = try self.checkExpression(ds.Expression);
            },

            // For loop
            .ForStatement => |fs| {
                if (fs.Initializer) |initializer_node| {
                    // init can be variable declaration list or expression
                    const initNode = self.binder.ast.getNode(initializer_node);
                    switch (initNode) {
                        .VariableDeclarationList => try self.checkStatement(initializer_node),
                        else => _ = try self.checkExpression(initializer_node),
                    }
                }
                if (fs.Condition) |cond| {
                    _ = try self.checkExpression(cond);
                }
                if (fs.Incrementor) |incr| {
                    _ = try self.checkExpression(incr);
                }
                try self.checkStatement(fs.Statement);
            },

            // For-in / For-of
            .ForInStatement, .ForOfStatement => |fio| {
                _ = try self.checkExpression(fio.Expression);
                try self.checkStatement(fio.Statement);
            },

            // Switch
            .SwitchStatement => |ss| {
                _ = try self.checkExpression(ss.Expression);
                try self.checkStatement(ss.CaseBlock);
            },
            .CaseBlock => |cb| {
                if (cb.Clauses != 0) {
                    const clauses = self.binder.ast.getNodeList(cb.Clauses);
                    for (clauses) |clause| {
                        try self.checkStatement(clause);
                    }
                }
            },
            .CaseClause => |cc| {
                _ = try self.checkExpression(cc.Expression);
                if (cc.Statements != 0) {
                    const stmts = self.binder.ast.getNodeList(cc.Statements);
                    for (stmts) |stmt| {
                        try self.checkStatement(stmt);
                    }
                }
            },
            .DefaultClause => |dc| {
                if (dc.Statements != 0) {
                    const stmts = self.binder.ast.getNodeList(dc.Statements);
                    for (stmts) |stmt| {
                        try self.checkStatement(stmt);
                    }
                }
            },

            // Throw
            .ThrowStatement => |ts| {
                _ = try self.checkExpression(ts.Expression);
            },

            // Try-catch-finally
            .TryStatement => |ts| {
                try self.checkStatement(ts.TryBlock);
                if (ts.CatchClause) |catchNode| {
                    try self.checkStatement(catchNode);
                }
                if (ts.FinallyBlock) |finallyNode| {
                    try self.checkStatement(finallyNode);
                }
            },
            .CatchClause => |cc| {
                try self.checkStatement(cc.Block);
            },

            // Classes
            .ClassDeclaration => |cd| {
                if (cd.Members != 0) {
                    const members = self.binder.ast.getNodeList(cd.Members);
                    for (members) |mem| {
                        try self.checkStatement(mem);
                    }
                }
            },
            .MethodDeclaration => |m| {
                if (m.Body) |body| {
                    try self.checkStatement(body);
                }
                if (m.Parameters != 0) {
                    const params = self.binder.ast.getNodeList(m.Parameters);
                    for (params) |param| {
                        _ = try self.getTypeOfNode(param);
                    }
                }
            },
            .Constructor => {},
            .GetAccessor => |ga| {
                if (ga.Body) |body| {
                    try self.checkStatement(body);
                }
            },
            .SetAccessor => |sa| {
                if (sa.Body) |body| {
                    try self.checkStatement(body);
                }
            },
            .PropertyDeclaration => |pd| {
                if (pd.Initializer) |pd_init| {
                    _ = try self.checkExpression(pd_init);
                }
            },

            // Labeled statement
            .LabeledStatement => |ls| {
                try self.checkStatement(ls.Statement);
            },

            // Export assignment: export = expr
            .ExportAssignment => |ea| {
                _ = try self.checkExpression(ea.Expression);
            },

            // ExpressionStatement cho arrow/function expressions
            .ArrowFunction, .FunctionExpression => {
                _ = try self.checkExpression(nodeIndex);
            },

            // Import/Export declarations (no type checking needed here)
            .ImportDeclaration, .ExportDeclaration => {},

            // Interface/TypeAlias: type-only, no runtime checking
            .InterfaceDeclaration, .TypeAliasDeclaration => {},

            // Enum
            .EnumDeclaration => |ed| {
                if (ed.Members != 0) {
                    const members = self.binder.ast.getNodeList(ed.Members);
                    for (members) |mem| {
                        const memNode = self.binder.ast.getNode(mem);
                        switch (memNode) {
                            .EnumMember => |em| {
                                if (em.Initializer) |initIdx| {
                                    _ = try self.checkExpression(initIdx);
                                }
                            },
                            else => {},
                        }
                    }
                }
            },

            // break / continue / debugger: nothing to check
            .BreakStatement, .ContinueStatement, .DebuggerStatement, .EmptyStatement => {},

            // Module block
            .ModuleBlock => |mb| {
                if (mb.Statements != 0) {
                    const stmts = self.binder.ast.getNodeList(mb.Statements);
                    for (stmts) |stmt| {
                        try self.checkStatement(stmt);
                    }
                }
            },

            // Property assignment trong object literal
            .PropertyAssignment => |pa| {
                _ = try self.checkExpression(pa.Initializer);
            },
            .ShorthandPropertyAssignment => |spa| {
                if (spa.ObjectAssignmentInitializer) |initExpr| {
                    _ = try self.checkExpression(initExpr);
                }
            },

            else => {},
        }
    }
};
