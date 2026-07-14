const std = @import("std");

// ATA (Automatic Type Acquisition) subsystem stub
// Will be expanded with typesmap, discovertypings, and npm install behaviors.
pub const ATA = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ATA {
        return .{
            .allocator = allocator,
        };
    }
};
