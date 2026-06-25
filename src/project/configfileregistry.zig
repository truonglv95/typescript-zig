const std = @import("std");
const core = @import("../core/core.zig");
const tspath = @import("../tspath/tspath.zig");
const tsoptions = @import("../tsoptions/tsoptions.zig");
const project = @import("project.zig");
const watch = @import("watch.zig");

pub const ConfigFileEntry = struct {
    fileName: []const u8,
    pendingReload: project.PendingReload,
    commandLine: ?*tsoptions.ParsedCommandLine = null,
    
    retainingProjects: std.StringHashMap(void),
    retainingOpenFiles: std.StringHashMap(void),
    retainingConfigs: std.StringHashMap(void),
    
    rootFilesWatch: ?*watch.WatchedFiles(watch.PatternsAndIgnored) = null,

    pub fn clone(self: *const ConfigFileEntry, allocator: std.mem.Allocator) !*ConfigFileEntry {
        var c = try allocator.create(ConfigFileEntry);
        c.* = .{
            .fileName = self.fileName,
            .pendingReload = self.pendingReload,
            .commandLine = self.commandLine,
            .retainingProjects = try self.cloneMap(allocator, &self.retainingProjects),
            .retainingOpenFiles = try self.cloneMap(allocator, &self.retainingOpenFiles),
            .retainingConfigs = try self.cloneMap(allocator, &self.retainingConfigs),
            .rootFilesWatch = self.rootFilesWatch, // Assuming watched files can be shared by ref
        };
        return c;
    }

    fn cloneMap(self: *const ConfigFileEntry, allocator: std.mem.Allocator, map: *const std.StringHashMap(void)) !std.StringHashMap(void) {
        _ = self;
        var new_map = std.StringHashMap(void).init(allocator);
        var it = map.keyIterator();
        while (it.next()) |k| {
            try new_map.put(k.*, {});
        }
        return new_map;
    }
};

pub const ConfigFileNames = struct {
    nearestConfigFileName: []const u8,
    ancestors: std.StringHashMap([]const u8),

    pub fn clone(self: *const ConfigFileNames, allocator: std.mem.Allocator) !*ConfigFileNames {
        var c = try allocator.create(ConfigFileNames);
        c.* = .{
            .nearestConfigFileName = self.nearestConfigFileName,
            .ancestors = std.StringHashMap([]const u8).init(allocator),
        };
        var it = self.ancestors.iterator();
        while (it.next()) |entry| {
            try c.ancestors.put(entry.key_ptr.*, entry.value_ptr.*);
        }
        return c;
    }
};

pub const ConfigFileRegistry = struct {
    configs: std.StringArrayHashMap(*ConfigFileEntry),
    configFileNames: std.StringArrayHashMap(*ConfigFileNames),
    customConfigFileName: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, customConfigFileName: []const u8) ConfigFileRegistry {
        return .{
            .configs = std.StringArrayHashMap(*ConfigFileEntry).init(allocator),
            .configFileNames = std.StringArrayHashMap(*ConfigFileNames).init(allocator),
            .customConfigFileName = customConfigFileName,
            .allocator = allocator,
        };
    }

    pub fn getConfig(self: *ConfigFileRegistry, path: tspath.Path) ?*tsoptions.ParsedCommandLine {
        if (self.configs.get(path)) |entry| {
            return entry.commandLine;
        }
        return null;
    }

    pub fn getConfigFileName(self: *ConfigFileRegistry, path: tspath.Path) []const u8 {
        if (self.configFileNames.get(path)) |entry| {
            return entry.nearestConfigFileName;
        }
        return "";
    }

    pub fn getAncestorConfigFileName(self: *ConfigFileRegistry, path: tspath.Path, higherThanConfig: []const u8) []const u8 {
        if (self.configFileNames.get(path)) |entry| {
            if (entry.ancestors.get(higherThanConfig)) |ancestor| {
                return ancestor;
            }
        }
        return "";
    }

    pub fn clone(self: *ConfigFileRegistry) !*ConfigFileRegistry {
        var c = try self.allocator.create(ConfigFileRegistry);
        c.* = ConfigFileRegistry.init(self.allocator, self.customConfigFileName);
        
        var it = self.configs.iterator();
        while (it.next()) |entry| {
            try c.configs.put(entry.key_ptr.*, try entry.value_ptr.*.clone(self.allocator));
        }

        var it2 = self.configFileNames.iterator();
        while (it2.next()) |entry| {
            try c.configFileNames.put(entry.key_ptr.*, try entry.value_ptr.*.clone(self.allocator));
        }

        return c;
    }
};
