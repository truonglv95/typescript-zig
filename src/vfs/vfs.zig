const std = @import("std");

pub const Entries = struct {
    files: []const []const u8 = &.{},
    directories: []const []const u8 = &.{},
};

pub const FS = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        useCaseSensitiveFileNames: *const fn (ptr: *anyopaque) bool,
        fileExists: *const fn (ptr: *anyopaque, path: []const u8) bool,
        directoryExists: *const fn (ptr: *anyopaque, path: []const u8) bool,
        readFile: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) ?[]u8,
        writeFile: *const fn (ptr: *anyopaque, path: []const u8, data: []const u8) anyerror!void,
        getAccessibleEntries: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) Entries,
        realpath: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) ?[]const u8,
    };

    pub fn useCaseSensitiveFileNames(self: FS) bool {
        return self.vtable.useCaseSensitiveFileNames(self.ptr);
    }

    pub fn fileExists(self: FS, path: []const u8) bool {
        return self.vtable.fileExists(self.ptr, path);
    }

    pub fn directoryExists(self: FS, path: []const u8) bool {
        return self.vtable.directoryExists(self.ptr, path);
    }

    pub fn readFile(self: FS, allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
        return self.vtable.readFile(self.ptr, allocator, path);
    }

    pub fn writeFile(self: FS, path: []const u8, data: []const u8) !void {
        return self.vtable.writeFile(self.ptr, path, data);
    }

    pub fn getAccessibleEntries(self: FS, allocator: std.mem.Allocator, path: []const u8) Entries {
        return self.vtable.getAccessibleEntries(self.ptr, allocator, path);
    }

    pub fn realpath(self: FS, allocator: std.mem.Allocator, path: []const u8) ?[]const u8 {
        return self.vtable.realpath(self.ptr, allocator, path);
    }
};
