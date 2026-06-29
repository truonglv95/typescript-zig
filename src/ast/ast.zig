const std = @import("std");
const kind = @import("kind.zig");
const ast_gen = @import("ast_generated.zig");
pub const flow = @import("flow.zig");

pub const NodeIndex = u32;
pub const SourceFile = opaque {};

pub const forEachChild = @import("for_each_child.zig").forEachChild;

pub const TextRange = struct {
    pos: u32,
    end: u32,
};

pub const SourceFileParseOptions = struct {
    FileName: []const u8,
    Path: []const u8,
};

/// Hệ thống AST dựa trên Data-Oriented Design.
/// Toàn bộ các Node sẽ được phân bổ phẳng trên `nodes` array, không dùng Pointer.
pub const Ast = struct {
    pub fn getSymbolParent(self: *Ast, a: anytype) u32 {
        _ = self;
        _ = a;
        return 0;
    }

    sourceText: []const u8,
    symbols: std.ArrayListUnmanaged(u32),
    allocator: std.mem.Allocator,
    nodes: std.MultiArrayList(ast_gen.NodeData),
    extraData: std.ArrayListUnmanaged(u32),
    parents: std.ArrayListUnmanaged(ast_gen.NodeIndex),
    positions: std.ArrayListUnmanaged(TextRange),
    localSymbols: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, ast_gen.SymbolIndex),
    jsdocCache: std.AutoHashMapUnmanaged(ast_gen.NodeIndex, []const ast_gen.NodeIndex),
    hasLazyJSDoc: bool,

    pub fn getNodeKind(self: *Ast, node: ast_gen.NodeIndex) std.meta.Tag(ast_gen.NodeData) {
        if (node == 0) return .Unknown;
        return std.meta.activeTag(self.getNode(node));
    }

    pub fn init(allocator: std.mem.Allocator) Ast {
        var a = Ast{
            .sourceText = "",
            .allocator = allocator,
            .symbols = .empty,
            .nodes = .{},
            .extraData = .empty,
            .parents = .empty,
            .positions = .empty,
            .localSymbols = .empty,
            .jsdocCache = .empty,
            .hasLazyJSDoc = false,
        };
        // Reserve index 0 as "null/empty"
        a.nodes.append(allocator, .{ .Unknown = void{} }) catch unreachable;
        a.extraData.append(allocator, 0) catch unreachable;
        a.parents.append(allocator, 0) catch unreachable;
        a.positions.append(allocator, .{ .pos = 0, .end = 0 }) catch unreachable;
        return a;
    }

    pub fn deinit(self: *Ast) void {
        var it = self.jsdocCache.valueIterator();
        while (it.next()) |val| {
            self.allocator.free(val.*);
        }
        self.jsdocCache.deinit(self.allocator);
        self.nodes.deinit(self.allocator);
        self.extraData.deinit(self.allocator);
        self.parents.deinit(self.allocator);
        self.positions.deinit(self.allocator);
        self.localSymbols.deinit(self.allocator);
        self.symbols.deinit(self.allocator);
    }

    /// Thêm một Node mới vào AST và trả về NodeIndex (chính là u32 pointer).
    pub fn pushNode(self: *Ast, node: ast_gen.NodeData) !ast_gen.NodeIndex {
        const index = @as(u32, @intCast(self.nodes.len));
        try self.nodes.append(self.allocator, node);
        try self.parents.append(self.allocator, 0); // Default parent is 0
        try self.positions.append(self.allocator, .{ .pos = 0, .end = 0 });
        return index;
    }

    pub fn pushTokenNode(self: *Ast, token: kind.Kind) !ast_gen.NodeIndex {
        @setEvalBranchQuota(10000);
        inline for (std.meta.fields(kind.Kind)) |f| {
            if (token == @as(kind.Kind, @enumFromInt(f.value))) {
                if (@hasField(ast_gen.NodeData, f.name)) {
                    if (@TypeOf(@field(@as(ast_gen.NodeData, undefined), f.name)) == void) {
                        return self.pushNode(@unionInit(ast_gen.NodeData, f.name, {}));
                    }
                }
            }
        }
        return self.pushNode(.{ .Unknown = {} });
    }

    /// Thêm một danh sách các NodeIndex vào `extraData` array (Mô hình DoD).
    /// Phần tử đầu tiên sẽ lưu độ dài của mảng (bit cao nhất dành cho hasTrailingComma), theo sau là các index.
    pub fn pushNodeListWithTrailingComma(self: *Ast, items: []const NodeIndex, hasTrailingComma: bool) !u32 {
        const startIndex = @as(u32, @intCast(self.extraData.items.len));
        var lengthAndFlag = @as(u32, @intCast(items.len));
        if (hasTrailingComma) {
            lengthAndFlag |= (1 << 31);
        }
        try self.extraData.append(self.allocator, lengthAndFlag);
        try self.extraData.appendSlice(self.allocator, items);
        return startIndex;
    }

    pub fn pushNodeList(self: *Ast, items: []const NodeIndex) !u32 {
        return self.pushNodeListWithTrailingComma(items, false);
    }

    /// Lấy một Node tại index cụ thể.
    pub fn getNode(self: *Ast, index: NodeIndex) ast_gen.NodeData {
        if (index >= self.nodes.len) {
            return .{ .Unknown = {} };
        }
        return self.nodes.get(index);
    }

    /// Lấy danh sách NodeIndex từ extraData
    pub fn getNodeList(self: *Ast, index: u32) []const NodeIndex {
        if (index == 0) return &[_]NodeIndex{};
        const lengthAndFlag = self.extraData.items[index];
        const len = lengthAndFlag & 0x7FFFFFFF;
        return self.extraData.items[index + 1 .. index + 1 + len];
    }

    pub fn listHasTrailingComma(self: *Ast, index: u32) bool {
        if (index == 0) return false;
        const lengthAndFlag = self.extraData.items[index];
        return (lengthAndFlag & (1 << 31)) != 0;
    }

    pub fn getNodeParent(self: *Ast, index: NodeIndex) NodeIndex {
        return self.parents.items[index];
    }

    pub fn setNodeParent(self: *Ast, index: NodeIndex, parentIndex: NodeIndex) void {
        self.parents.items[index] = parentIndex;
    }

    pub fn setNodeSymbol(self: *Ast, index: NodeIndex, symbolIndex: ast_gen.SymbolIndex) void {
        var node = self.getNode(index);
        switch (node) {
            inline else => |*n| {
                if (@TypeOf(n.*) != void) {
                    if (@hasField(@TypeOf(n.*), "Symbol")) {
                        n.Symbol = symbolIndex;
                        self.nodes.set(index, node);
                    }
                }
            },
        }
    }

    pub fn getNodeSymbol(self: *Ast, index: NodeIndex) ?ast_gen.SymbolIndex {
        const node = self.getNode(index);
        switch (node) {
            inline else => |n| {
                if (@TypeOf(n) != void) {
                    if (@hasField(@TypeOf(n), "Symbol")) {
                        return if (n.Symbol != 0) n.Symbol else null;
                    }
                }
                return null;
            },
        }
    }
    pub fn getNodeFlags(self: *Ast, index: NodeIndex) u32 {
        const node = self.getNode(index);
        switch (node) {
            inline else => |n| {
                if (@TypeOf(n) != void and @hasField(@TypeOf(n), "Flags")) return n.Flags;
                return 0;
            },
        }
    }

    pub fn setNodeFlags(self: *Ast, index: NodeIndex, flags: u32) void {
        var node = self.getNode(index);
        switch (node) {
            inline else => |*n| {
                if (@TypeOf(n.*) != void and @hasField(@TypeOf(n.*), "Flags")) n.Flags = flags;
            },
        }
        self.nodes.set(index, node);
    }
};

pub const SubtreeContainsDecorators: u32 = 0;

pub const NodeFlagsAmbient: u32 = 0;

pub const ModifierFlagsAmbient: u32 = 0;
pub const ModifierFlagsAbstract: u32 = 0;
pub const ModifierFlagsExport: u32 = 0;

pub const ModifierFlagsDefault: u32 = 0;

pub const NodeFlagsLet = 1;
