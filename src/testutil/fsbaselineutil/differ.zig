const std = @import("std");
const iovfs = @import("../vfs/iovfs.zig");

pub const DiffEntry = struct {
    content: []const u8,
    mTime: i64,
    isWritten: bool,
    symlinkTarget: []const u8,
};

pub const Snapshot = struct {
    snap: std.StringHashMap(*DiffEntry),
};

pub const FSDiffer = struct {
    fs: *iovfs.MapFS,
    // defaultLibs: *collections.SyncSet([]const u8),
    writtenFiles: *@import("../../collections/collections.zig").Set([]const u8),
    serializedDiff: ?*Snapshot = null,

    pub fn init(allocator: std.mem.Allocator, fsFromMap: *iovfs.MapFS) *FSDiffer {
        const differ = allocator.create(FSDiffer) catch @panic("OOM");
        const collections = @import("../../collections/collections.zig");
        const writtenFiles = allocator.create(collections.Set([]const u8)) catch @panic("OOM");
        writtenFiles.* = collections.Set_init([]const u8, allocator);
        differ.* = .{
            .fs = fsFromMap,
            .writtenFiles = writtenFiles,
            .serializedDiff = null,
        };
        return differ;
    }

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
        self.writtenFiles.deinit();
        allocator.destroy(self.writtenFiles);
        allocator.destroy(self);
    }

    pub fn sanitizeInternalSymbolName(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
        if (std.mem.indexOf(u8, s, "\u{FFFD}@") == null) {
            return allocator.dupe(u8, s);
        }
        var list = std.ArrayList(u8).init(allocator);
        var i: usize = 0;
        while (i < s.len) {
            if (std.mem.startsWith(u8, s[i..], "\u{FFFD}@")) {
                const end = std.mem.indexOfAny(u8, s[i..], " \n\r\t,;") orelse s.len - i;
                const match = s[i .. i + end];
                if (std.mem.lastIndexOfScalar(u8, match, '@')) |idStart| {
                    try list.appendSlice(match[0..idStart]);
                    try list.appendSlice("@<symbolId>");
                } else {
                    try list.appendSlice(match);
                }
                i += end;
            } else {
                try list.append(s[i]);
                i += 1;
            }
        }
        return try list.toOwnedSlice();
    }

    pub fn baselineFSwithDiff(self: *FSDiffer, allocator: std.mem.Allocator, baselineWriter: anytype) !void {
        var snap = std.StringHashMap(*DiffEntry).init(allocator);
        var diffs = std.StringHashMap([]const u8).init(allocator);
        defer diffs.deinit();

        self.fs.mu.lockShared();
        defer self.fs.mu.unlockShared();

        var it = self.fs.files.iterator();
        while (it.next()) |entry| {
            const path = entry.key_ptr.*;
            const data = entry.value_ptr.*;

            const content = try sanitizeInternalSymbolName(allocator, data);
            
            const newEntry = try allocator.create(DiffEntry);
            newEntry.* = .{
                .content = content,
                .mTime = 0,
                .isWritten = self.writtenFiles.contains(path),
                .symlinkTarget = "",
            };
            try snap.put(try allocator.dupe(u8, path), newEntry);

            try self.addFsEntryDiff(allocator, &diffs, newEntry, path);
        }

        if (self.serializedDiff) |oldSnap| {
            var oldIt = oldSnap.snap.iterator();
            while (oldIt.next()) |oldEntry| {
                const path = oldEntry.key_ptr.*;
                if (!self.fs.files.contains(path)) {
                    try self.addFsEntryDiff(allocator, &diffs, null, path);
                }
            }
        }

        const newSnapshot = try allocator.create(Snapshot);
        newSnapshot.* = .{ .snap = snap };
        
        if (self.serializedDiff) |oldSnap| {
            var oldIt = oldSnap.snap.iterator();
            while (oldIt.next()) |oldEntry| {
                allocator.free(oldEntry.key_ptr.*);
                allocator.free(oldEntry.value_ptr.*.content);
                allocator.free(oldEntry.value_ptr.*.symlinkTarget);
                allocator.destroy(oldEntry.value_ptr.*);
            }
            oldSnap.snap.deinit();
            allocator.destroy(oldSnap);
        }
        self.serializedDiff = newSnapshot;

        var keys = std.ArrayList([]const u8).init(allocator);
        defer keys.deinit();
        var diffIt = diffs.iterator();
        while (diffIt.next()) |d_entry| {
            try keys.append(d_entry.key_ptr.*);
        }
        std.mem.sort([]const u8, keys.items, {}, struct {
            fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                return std.mem.order(u8, a, b) == .lt;
            }
        }.lessThan);

        for (keys.items) |path| {
            try std.fmt.format(baselineWriter, "//// [{s}] {s}\n", .{ path, diffs.get(path).? });
        }
        try std.fmt.format(baselineWriter, "\n", .{});
        self.writtenFiles.clearRetainingCapacity(); // Reset written files after baseline
    }

    fn addFsEntryDiff(self: *FSDiffer, allocator: std.mem.Allocator, diffs: *std.StringHashMap([]const u8), newEntry: ?*DiffEntry, path: []const u8) !void {
        var oldEntry: ?*DiffEntry = null;
        if (self.serializedDiff) |snap| {
            if (snap.snap.get(path)) |o| {
                oldEntry = o;
            }
        }

        if (oldEntry == null) {
            if (newEntry) |n| {
                if (n.symlinkTarget.len > 0) {
                    diffs.put(path, try std.fmt.allocPrint(allocator, "-> {s} *new*", .{n.symlinkTarget})) catch {};
                } else {
                    diffs.put(path, try std.fmt.allocPrint(allocator, "*new* \n{s}", .{n.content})) catch {};
                }
            }
        } else if (newEntry == null) {
            diffs.put(path, "*deleted*") catch {};
        } else if (!std.mem.eql(u8, newEntry.?.content, oldEntry.?.content)) {
            diffs.put(path, try std.fmt.allocPrint(allocator, "*modified* \n{s}", .{newEntry.?.content})) catch {};
        } else if (newEntry.?.isWritten) {
            diffs.put(path, "*rewrite with same content*") catch {};
        } else if (newEntry.?.mTime != oldEntry.?.mTime) {
            diffs.put(path, "*mTime changed*") catch {};
        }
    }

    pub fn changedPaths(self: *FSDiffer, allocator: std.mem.Allocator) ![]FileChange {
        if (self.serializedDiff == null) return &[_]FileChange{};

        var changes = std.ArrayList(FileChange).init(allocator);
        const oldSnap = self.serializedDiff.?;

        self.fs.mu.lockShared();
        defer self.fs.mu.unlockShared();

        var it = self.fs.files.iterator();
        while (it.next()) |entry| {
            const path = entry.key_ptr.*;
            const data = entry.value_ptr.*;

            if (oldSnap.snap.get(path)) |oldEntry| {
                if (!std.mem.eql(u8, data, oldEntry.content) or 0 != oldEntry.mTime) { // mTime stub
                    try changes.append(.{ .path = try allocator.dupe(u8, path), .deleted = false });
                }
            } else {
                try changes.append(.{ .path = try allocator.dupe(u8, path), .deleted = false });
            }
        }

        var oldIt = oldSnap.snap.iterator();
        while (oldIt.next()) |oldEntry| {
            const path = oldEntry.key_ptr.*;
            if (!self.fs.files.contains(path)) {
                try changes.append(.{ .path = try allocator.dupe(u8, path), .deleted = true });
            }
        }

        return try changes.toOwnedSlice();
    }
};

pub const FileChange = struct {
    path: []const u8,
    deleted: bool,
};
