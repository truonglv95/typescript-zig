const std = @import("std");
const host_module = @import("../ls/host.zig");
const lsconv = @import("../ls/lsconv.zig");
const lsutil = @import("../ls/lsutil/lsutil.zig");
const sourcemap = @import("../sourcemap/sourcemap.zig");
const autoimport = @import("../project/autoimport.zig");
const documents = @import("document_store.zig");

pub const SessionHost = struct {
    allocator: std.mem.Allocator,
    store: *documents.DocumentStore,
    converters_instance: *lsconv.Converters,

    pub fn init(allocator: std.mem.Allocator, store: *documents.DocumentStore) !*SessionHost {
        const self = try allocator.create(SessionHost);
        const conv = try allocator.create(lsconv.Converters);
        conv.* = lsconv.Converters{
            .get_line_map = getLineMap,
            .get_line_map_ctx = self,
        };
        self.* = .{
            .allocator = allocator,
            .store = store,
            .converters_instance = conv,
        };
        return self;
    }

    pub fn deinit(self: *SessionHost) void {
        self.allocator.destroy(self.converters_instance);
        self.allocator.destroy(self);
    }

    pub fn host(self: *SessionHost) host_module.Host {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    fn getLineMap(ctx: *anyopaque, fileName: []const u8) ?*lsconv.LineMap {
        _ = ctx;
        _ = fileName;
        return null;
    }

    const vtable = host_module.Host.VTable{
        .useCaseSensitiveFileNames = useCaseSensitiveFileNames,
        .readFile = readFile,
        .converters = converters,
        .getPreferences = getPreferences,
        .getECMALineInfo = getECMALineInfo,
        .autoImportRegistry = autoImportRegistry,
        .readDirectory = readDirectory,
        .getDirectories = getDirectories,
        .directoryExists = directoryExists,
        .fileExists = fileExists,
    };

    fn useCaseSensitiveFileNames(ptr: *anyopaque) bool {
        _ = ptr;
        return true;
    }

    fn readFile(ptr: *anyopaque, path: []const u8, allocator: std.mem.Allocator) ?[]const u8 {
        const self: *SessionHost = @ptrCast(@alignCast(ptr));
        if (self.store.get(path)) |doc| {
            return allocator.dupe(u8, doc.text) catch null;
        }
        return null;
    }

    fn converters(ptr: *anyopaque) *lsconv.Converters {
        const self: *SessionHost = @ptrCast(@alignCast(ptr));
        return self.converters_instance;
    }

    fn getPreferences(ptr: *anyopaque, activeFile: []const u8) lsutil.UserPreferences {
        _ = ptr;
        _ = activeFile;
        return .{};
    }

    fn getECMALineInfo(ptr: *anyopaque, fileName: []const u8) ?*sourcemap.ECMALineInfo {
        _ = ptr;
        _ = fileName;
        return null;
    }

    fn autoImportRegistry(ptr: *anyopaque) ?*autoimport.Registry {
        _ = ptr;
        return null;
    }

    fn readDirectory(
        ptr: *anyopaque,
        currentDir: []const u8,
        path: []const u8,
        extensions: []const []const u8,
        excludes: []const []const u8,
        includes: []const []const u8,
        depth: usize,
        allocator: std.mem.Allocator,
    ) []const []const u8 {
        _ = ptr;
        _ = currentDir;
        _ = path;
        _ = extensions;
        _ = excludes;
        _ = includes;
        _ = depth;
        _ = allocator;
        return &.{};
    }

    fn getDirectories(ptr: *anyopaque, path: []const u8, allocator: std.mem.Allocator) []const []const u8 {
        _ = ptr;
        _ = path;
        _ = allocator;
        return &.{};
    }

    fn directoryExists(ptr: *anyopaque, path: []const u8) bool {
        _ = ptr;
        _ = path;
        return false;
    }

    fn fileExists(ptr: *anyopaque, path: []const u8) bool {
        const self: *SessionHost = @ptrCast(@alignCast(ptr));
        return self.store.get(path) != null;
    }
};
