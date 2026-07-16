const std = @import("std");
const vfs = @import("../../vfs/vfs.zig");

pub const TestFile = struct {
    unitName: []const u8,
    content: []const u8,
};

pub const OutputRecorderFS = struct {
    fs: *vfs.FS,
    outputsMut: std.Thread.Mutex = .{},
    outputsMap: std.StringHashMap(usize),
    outputs: std.ArrayList(*TestFile),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, base_fs: *vfs.FS) OutputRecorderFS {
        return .{
            .fs = base_fs,
            .outputsMap = std.StringHashMap(usize).init(allocator),
            .outputs = std.ArrayList(*TestFile).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *OutputRecorderFS) void {
        var it = self.outputsMap.keyIterator();
        while (it.next()) |k| {
            self.allocator.free(k.*);
        }
        self.outputsMap.deinit();
        for (self.outputs.items) |item| {
            self.allocator.free(item.unitName);
            self.allocator.free(item.content);
            self.allocator.destroy(item);
        }
        self.outputs.deinit();
    }

    pub fn writeFile(self: *OutputRecorderFS, path: []const u8, data: []const u8) !void {
        try self.fs.writeFile(path, data);
        const real_path = try self.fs.realpath(self.allocator, path);
        defer self.allocator.free(real_path);

        self.outputsMut.lock();
        defer self.outputsMut.unlock();

        if (self.outputsMap.get(real_path)) |index| {
            const item = self.outputs.items[index];
            self.allocator.free(item.content);
            item.content = try self.allocator.dupe(u8, data);
        } else {
            const index = self.outputs.items.len;
            const item = try self.allocator.create(TestFile);
            item.unitName = try self.allocator.dupe(u8, real_path);
            item.content = try self.allocator.dupe(u8, data);
            
            const key_dupe = try self.allocator.dupe(u8, real_path);
            try self.outputsMap.put(key_dupe, index);
            try self.outputs.append(item);
        }
    }

    pub const vtable = vfs.FS.VTable{
        .useCaseSensitiveFileNames = struct { fn w(ptr: *anyopaque) bool { return @as(*OutputRecorderFS, @ptrCast(@alignCast(ptr))).fs.useCaseSensitiveFileNames(); } }.w,
        .fileExists = struct { fn w(ptr: *anyopaque, path: []const u8) bool { return @as(*OutputRecorderFS, @ptrCast(@alignCast(ptr))).fs.fileExists(path); } }.w,
        .directoryExists = struct { fn w(ptr: *anyopaque, path: []const u8) bool { return @as(*OutputRecorderFS, @ptrCast(@alignCast(ptr))).fs.directoryExists(path); } }.w,
        .readFile = struct { fn w(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) ?[]u8 { return @as(*OutputRecorderFS, @ptrCast(@alignCast(ptr))).fs.readFile(allocator, path); } }.w,
        .writeFile = struct { fn w(ptr: *anyopaque, path: []const u8, data: []const u8) !void { return @as(*OutputRecorderFS, @ptrCast(@alignCast(ptr))).writeFile(path, data); } }.w,
        .appendFile = struct { fn w(ptr: *anyopaque, path: []const u8, data: []const u8) !void { return @as(*OutputRecorderFS, @ptrCast(@alignCast(ptr))).fs.appendFile(path, data); } }.w,
        .remove = struct { fn w(ptr: *anyopaque, path: []const u8) !void { return @as(*OutputRecorderFS, @ptrCast(@alignCast(ptr))).fs.remove(path); } }.w,
        .chtimes = struct { fn w(ptr: *anyopaque, path: []const u8, atime: i128, mtime: i128) !void { return @as(*OutputRecorderFS, @ptrCast(@alignCast(ptr))).fs.chtimes(path, atime, mtime); } }.w,
        .getAccessibleEntries = struct { fn w(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) vfs.Entries { return @as(*OutputRecorderFS, @ptrCast(@alignCast(ptr))).fs.getAccessibleEntries(allocator, path); } }.w,
        .stat = struct { fn w(ptr: *anyopaque, path: []const u8) ?vfs.FileInfo { return @as(*OutputRecorderFS, @ptrCast(@alignCast(ptr))).fs.stat(path); } }.w,
        .walkDir = struct { fn w(ptr: *anyopaque, root: []const u8, walk_fn: vfs.WalkDirFunc) !void { return @as(*OutputRecorderFS, @ptrCast(@alignCast(ptr))).fs.walkDir(root, walk_fn); } }.w,
        .realpath = struct { fn w(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) ?[]const u8 { return @as(*OutputRecorderFS, @ptrCast(@alignCast(ptr))).fs.realpath(allocator, path); } }.w,
    };

    pub fn toFS(self: *OutputRecorderFS) vfs.FS {
        return .{ .ptr = self, .vtable = &vtable };
    }


    pub fn getOutputs(self: *OutputRecorderFS, allocator: std.mem.Allocator) ![]*TestFile {
        self.outputsMut.lock();
        defer self.outputsMut.unlock();

        const result = try allocator.alloc(*TestFile, self.outputs.items.len);
        for (self.outputs.items, 0..) |item, i| {
            const dupe_item = try allocator.create(TestFile);
            dupe_item.unitName = try allocator.dupe(u8, item.unitName);
            dupe_item.content = try allocator.dupe(u8, item.content);
            result[i] = dupe_item;
        }
        return result;
    }
};

pub fn newOutputRecorderFS(allocator: std.mem.Allocator, base_fs: *vfs.FS) !vfs.FS {
    const recorder = try allocator.create(OutputRecorderFS);
    recorder.* = OutputRecorderFS.init(allocator, base_fs);
    return recorder.toFS();
}
