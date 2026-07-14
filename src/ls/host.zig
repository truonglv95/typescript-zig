const std = @import("std");
const autoimport = @import("../project/autoimport.zig");
const compiler = @import("../compiler/program.zig");
const lsconv = @import("lsconv.zig");
const lsutil = @import("lsutil/lsutil.zig");
const sourcemap = @import("../sourcemap/sourcemap.zig");

pub const Host = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        useCaseSensitiveFileNames: *const fn (ptr: *anyopaque) bool,
        readFile: *const fn (ptr: *anyopaque, path: []const u8, allocator: std.mem.Allocator) ?[]const u8,
        converters: *const fn (ptr: *anyopaque) *lsconv.Converters,
        getPreferences: *const fn (ptr: *anyopaque, activeFile: []const u8) lsutil.UserPreferences,
        getECMALineInfo: *const fn (ptr: *anyopaque, fileName: []const u8) *sourcemap.lineinfo.ECMALineInfo,
        autoImportRegistry: *const fn (ptr: *anyopaque) *anyopaque,

        // Used for module specifier completions.
        // ! Do not use for anything else, as this violates the principle that
        // the host is a snapshot-in-time.
        readDirectory: *const fn (
            ptr: *anyopaque,
            currentDir: []const u8,
            path: []const u8,
            extensions: []const []const u8,
            excludes: []const []const u8,
            includes: []const []const u8,
            depth: usize,
            allocator: std.mem.Allocator,
        ) []const []const u8,
        getDirectories: *const fn (ptr: *anyopaque, path: []const u8, allocator: std.mem.Allocator) []const []const u8,
        directoryExists: *const fn (ptr: *anyopaque, path: []const u8) bool,
        fileExists: *const fn (ptr: *anyopaque, path: []const u8) bool,
    };

    pub inline fn useCaseSensitiveFileNames(self: Host) bool {
        return self.vtable.useCaseSensitiveFileNames(self.ptr);
    }

    pub inline fn readFile(self: Host, path: []const u8, allocator: std.mem.Allocator) ?[]const u8 {
        return self.vtable.readFile(self.ptr, path, allocator);
    }

    pub inline fn converters(self: Host) *lsconv.Converters {
        return self.vtable.converters(self.ptr);
    }

    pub inline fn getPreferences(self: Host, activeFile: []const u8) lsutil.UserPreferences {
        return self.vtable.getPreferences(self.ptr, activeFile);
    }

    pub inline fn getECMALineInfo(self: Host, fileName: []const u8) *sourcemap.ECMALineInfo {
        return self.vtable.getECMALineInfo(self.ptr, fileName);
    }

    pub inline fn autoImportRegistry(self: Host) *autoimport.Registry {
        return self.vtable.autoImportRegistry(self.ptr);
    }

    pub inline fn readDirectory(
        self: Host,
        currentDir: []const u8,
        path: []const u8,
        extensions: []const []const u8,
        excludes: []const []const u8,
        includes: []const []const u8,
        depth: usize,
        allocator: std.mem.Allocator,
    ) []const []const u8 {
        return self.vtable.readDirectory(self.ptr, currentDir, path, extensions, excludes, includes, depth, allocator);
    }

    pub inline fn getDirectories(self: Host, path: []const u8, allocator: std.mem.Allocator) []const []const u8 {
        return self.vtable.getDirectories(self.ptr, path, allocator);
    }

    pub inline fn directoryExists(self: Host, path: []const u8) bool {
        return self.vtable.directoryExists(self.ptr, path);
    }

    pub inline fn fileExists(self: Host, path: []const u8) bool {
        return self.vtable.fileExists(self.ptr, path);
    }
};
