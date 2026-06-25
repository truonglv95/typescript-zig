const core = @import("../core/core.zig");

pub const Source = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        text: *const fn (ptr: *anyopaque) []const u8,
        fileName: *const fn (ptr: *anyopaque) []const u8,
        ecmaLineMap: *const fn (ptr: *anyopaque) []core.TextPos,
    };

    pub inline fn text(self: Source) []const u8 {
        return self.vtable.text(self.ptr);
    }

    pub inline fn fileName(self: Source) []const u8 {
        return self.vtable.fileName(self.ptr);
    }

    pub inline fn ecmaLineMap(self: Source) []core.TextPos {
        return self.vtable.ecmaLineMap(self.ptr);
    }
};
