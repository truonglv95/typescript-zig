const std = @import("std");

pub fn Stack(comptime T: type) type {
    return struct {
        const Self = @This();
        items: std.ArrayListUnmanaged(T) = .empty,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit(self.allocator);
        }

        pub fn push(self: *Self, item: T) !void {
            try self.items.append(self.allocator, item);
        }

        pub fn pop(self: *Self) ?T {
            if (self.items.items.len == 0) return null;
            return self.items.pop();
        }

        pub fn peek(self: *const Self) ?T {
            if (self.items.items.len == 0) return null;
            return self.items.items[self.items.items.len - 1];
        }

        pub fn len(self: *const Self) usize {
            return self.items.items.len;
        }
        
        pub fn isEmpty(self: *const Self) bool {
            return self.items.items.len == 0;
        }
    };
}
