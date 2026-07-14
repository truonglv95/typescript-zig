const std = @import("std");

pub const Fixture = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        name: *const fn(ptr: *anyopaque) []const u8,
        path: *const fn(ptr: *anyopaque) []const u8,
        skipIfNotExist: *const fn(ptr: *anyopaque) void,
        readFile: *const fn(ptr: *anyopaque, allocator: std.mem.Allocator) anyerror![]const u8,
        deinit: *const fn(ptr: *anyopaque, allocator: std.mem.Allocator) void,
    };

    pub fn name(self: Fixture) []const u8 {
        return self.vtable.name(self.ptr);
    }

    pub fn path(self: Fixture) []const u8 {
        return self.vtable.path(self.ptr);
    }

    pub fn skipIfNotExist(self: Fixture) void {
        self.vtable.skipIfNotExist(self.ptr);
    }

    pub fn readFile(self: Fixture, allocator: std.mem.Allocator) anyerror![]const u8 {
        return self.vtable.readFile(self.ptr, allocator);
    }

    pub fn deinit(self: Fixture, allocator: std.mem.Allocator) void {
        self.vtable.deinit(self.ptr, allocator);
    }
};

const FromFile = struct {
    name_str: []const u8,
    path_str: []const u8,
    contents: ?[]const u8 = null,

    pub fn name(ptr: *anyopaque) []const u8 {
        const self: *FromFile = @ptrCast(@alignCast(ptr));
        return self.name_str;
    }

    pub fn path(ptr: *anyopaque) []const u8 {
        const self: *FromFile = @ptrCast(@alignCast(ptr));
        return self.path_str;
    }

    pub fn skipIfNotExist(ptr: *anyopaque) void {
        _ = ptr;
    }

    pub fn readFile(ptr: *anyopaque, allocator: std.mem.Allocator) anyerror![]const u8 {
        const self: *FromFile = @ptrCast(@alignCast(ptr));
        if (self.contents) |c| {
            return c;
        }
        var file = try std.fs.cwd().openFile(self.path_str, .{});
        defer file.close();
        self.contents = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        return self.contents.?;
    }

    pub fn deinit(ptr: *anyopaque, allocator: std.mem.Allocator) void {
        const self: *FromFile = @ptrCast(@alignCast(ptr));
        if (self.contents) |c| {
            allocator.free(c);
        }
        allocator.free(self.name_str);
        allocator.free(self.path_str);
        allocator.destroy(self);
    }
};

pub fn fromFile(allocator: std.mem.Allocator, name_str: []const u8, path_str: []const u8) !Fixture {
    const obj = try allocator.create(FromFile);
    obj.* = .{
        .name_str = try allocator.dupe(u8, name_str),
        .path_str = try allocator.dupe(u8, path_str),
    };
    return Fixture{
        .ptr = obj,
        .vtable = &.{
            .name = FromFile.name,
            .path = FromFile.path,
            .skipIfNotExist = FromFile.skipIfNotExist,
            .readFile = FromFile.readFile,
            .deinit = FromFile.deinit,
        },
    };
}

const FromString = struct {
    name_str: []const u8,
    path_str: []const u8,
    contents: []const u8,

    pub fn name(ptr: *anyopaque) []const u8 {
        const self: *FromString = @ptrCast(@alignCast(ptr));
        return self.name_str;
    }

    pub fn path(ptr: *anyopaque) []const u8 {
        const self: *FromString = @ptrCast(@alignCast(ptr));
        return self.path_str;
    }

    pub fn skipIfNotExist(ptr: *anyopaque) void {
        _ = ptr;
    }

    pub fn readFile(ptr: *anyopaque, allocator: std.mem.Allocator) anyerror![]const u8 {
        _ = allocator;
        const self: *FromString = @ptrCast(@alignCast(ptr));
        return self.contents;
    }

    pub fn deinit(ptr: *anyopaque, allocator: std.mem.Allocator) void {
        const self: *FromString = @ptrCast(@alignCast(ptr));
        allocator.free(self.name_str);
        allocator.free(self.path_str);
        allocator.free(self.contents);
        allocator.destroy(self);
    }
};

pub fn fromString(allocator: std.mem.Allocator, name_str: []const u8, path_str: []const u8, contents: []const u8) !Fixture {
    const obj = try allocator.create(FromString);
    obj.* = .{
        .name_str = try allocator.dupe(u8, name_str),
        .path_str = try allocator.dupe(u8, path_str),
        .contents = try allocator.dupe(u8, contents),
    };
    return Fixture{
        .ptr = obj,
        .vtable = &.{
            .name = FromString.name,
            .path = FromString.path,
            .skipIfNotExist = FromString.skipIfNotExist,
            .readFile = FromString.readFile,
            .deinit = FromString.deinit,
        },
    };
}
