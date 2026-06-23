const std = @import("std");
const kind = @import("kind.zig");
const ast_gen = @import("ast_generated.zig");

pub const NodeIndex = u32;

/// Hệ thống AST dựa trên Data-Oriented Design.
/// Toàn bộ các Node sẽ được phân bổ phẳng trên `nodes` array, không dùng Pointer.
pub const Ast = struct {
    allocator: std.mem.Allocator,
    nodes: std.MultiArrayList(ast_gen.NodeData),
    extraData: std.ArrayListUnmanaged(u32),
    parents: std.ArrayListUnmanaged(ast_gen.NodeIndex),

    pub fn init(allocator: std.mem.Allocator) Ast {
        var a = Ast{
            .allocator = allocator,
            .nodes = .{},
            .extraData = .empty,
            .parents = .empty,
        };
        // Reserve index 0 as "null/empty"
        a.nodes.append(allocator, .{ .Unknown = void{} }) catch unreachable;
        a.extraData.append(allocator, 0) catch unreachable;
        a.parents.append(allocator, 0) catch unreachable;
        return a;
    }

    pub fn deinit(self: *Ast) void {
        self.nodes.deinit(self.allocator);
        self.extraData.deinit(self.allocator);
        self.parents.deinit(self.allocator);
    }

    /// Thêm một Node mới vào AST và trả về NodeIndex (chính là u32 pointer).
    pub fn pushNode(self: *Ast, node: ast_gen.NodeData) !ast_gen.NodeIndex {
        const index = @as(u32, @intCast(self.nodes.len));
        try self.nodes.append(self.allocator, node);
        try self.parents.append(self.allocator, 0); // Default parent is 0
        return index;
    }

    /// Thêm một danh sách các NodeIndex vào `extraData` array (Mô hình DoD).
    /// Phần tử đầu tiên sẽ lưu độ dài của mảng, theo sau là các index.
    pub fn pushNodeList(self: *Ast, items: []const NodeIndex) !u32 {
        const startIndex = @as(u32, @intCast(self.extraData.items.len));
        try self.extraData.append(self.allocator, @as(u32, @intCast(items.len)));
        try self.extraData.appendSlice(self.allocator, items);
        return startIndex;
    }

    /// Lấy một Node tại index cụ thể.
    pub fn getNode(self: *Ast, index: NodeIndex) ast_gen.NodeData {
        if (index >= self.nodes.len) {

        }
        return self.nodes.get(index);
    }

    /// Lấy danh sách NodeIndex từ extraData
    pub fn getNodeList(self: *Ast, startIndex: u32) []const NodeIndex {
        if (startIndex == 0) return &[_]NodeIndex{};
        if (startIndex >= self.extraData.items.len) {

            return &[_]NodeIndex{};
        }
        const len = self.extraData.items[startIndex];
        if (startIndex + 1 + len > self.extraData.items.len) {

            return &[_]NodeIndex{};
        }
        return self.extraData.items[startIndex + 1 .. startIndex + 1 + len];
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
            }
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
            }
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
