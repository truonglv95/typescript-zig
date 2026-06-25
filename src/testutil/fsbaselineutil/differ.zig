const std = @import("std");

pub const DiffEntry = struct {
    content: []const u8,
    mTime: i64,
    isWritten: bool,
    symlinkTarget: []const u8,
};

pub const Snapshot = struct {
    snap: std.StringHashMap(*DiffEntry),
    // defaultLibs: *collections.SyncSet([]const u8),
};

pub const FSDiffer = struct {
    // fs: iovfs.FsWithSys,
    // defaultLibs: *const fn() *collections.SyncSet([]const u8),
    // writtenFiles: *collections.SyncSet([]const u8),
    serializedDiff: ?*Snapshot = null,

    pub fn deinit(self: *FSDiffer, allocator: std.mem.Allocator) void {
        if (self.serializedDiff) |snap| {
            var it = snap.snap.iterator();
            while (it.next()) |entry| {
                allocator.free(entry.key_ptr.*);
                allocator.free(entry.value_ptr.*.content);
                allocator.free(entry.value_ptr.*.symlinkTarget);
                allocator.destroy(entry.value_ptr.*);
            }
            snap.snap.deinit();
            allocator.destroy(snap);
        }
    }

    pub fn baselineFSwithDiff(self: *FSDiffer, allocator: std.mem.Allocator, baseline: anytype) !void {
        _ = self;
        _ = allocator;
        _ = baseline;
        // TODO: Implement fs baseline differ
        unreachable;
    }

    pub fn sanitizeInternalSymbolName(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
        // Replaces internal symbol names of shape \uFFFD@symbolName@123 with \uFFFD@symbolName@<symbolId>
        if (std.mem.indexOf(u8, s, "\u{FFFD}@") == null) {
            return allocator.dupe(u8, s);
        }
        // TODO: implement regex replace
        return allocator.dupe(u8, s);
    }
    
    pub fn changedPaths(self: *FSDiffer, allocator: std.mem.Allocator) ![]FileChange {
        _ = self;
        _ = allocator;
        // TODO: implement
        unreachable;
    }
};

pub const FileChange = struct {
    path: []const u8,
    deleted: bool,
};
