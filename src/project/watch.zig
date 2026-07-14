const std = @import("std");
const core = @import("../core/core.zig");
const tspath = @import("../tspath/tspath.zig");

pub const WatcherID = []const u8;

pub const PatternsAndIgnored = struct {
    directoriesOutsideWorkspace: [][]const u8,
    patternsInsideWorkspace: [][]const u8,
    ignored: std.StringHashMap(void),
};

pub const WatchKind = u32;

pub fn WatchedFiles(comptime T: type) type {
    return struct {
        const Self = @This();
        
        name: []const u8,
        watchKind: WatchKind,
        hasRelativePatternCapability: bool,
        input: T,
        
        id: u64 = 0,
        
        pub fn init(name: []const u8, kind: WatchKind, rel: bool, input: T) Self {
            return .{
                .name = name,
                .watchKind = kind,
                .hasRelativePatternCapability = rel,
                .input = input,
            };
        }
        
        pub fn clone(self: *const Self, input: T) Self {
            return .{
                .name = self.name,
                .watchKind = self.watchKind,
                .hasRelativePatternCapability = self.hasRelativePatternCapability,
                .input = input,
                .id = self.id,
            };
        }
    };
}

pub const WatchRegistry = struct {
    entries: std.StringHashMap(usize),
    pending: std.StringHashMap(void),
    mu: std.Thread.Mutex = .{},
    
    pub fn init(allocator: std.mem.Allocator) WatchRegistry {
        return .{
            .entries = std.StringHashMap(usize).init(allocator),
            .pending = std.StringHashMap(void).init(allocator),
        };
    }
};
