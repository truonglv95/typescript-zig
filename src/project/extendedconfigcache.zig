const std = @import("std");
const tspath = @import("../tspath/tspath.zig");
const tsoptions = @import("../tsoptions/tsoptions.zig");
const ownercache = @import("ownercache.zig");

pub const ExtendedConfigParseArgs = struct {
    fileName: []const u8,
    content: []const u8,
    fs: *anyopaque, // replace FileSource
    resolutionStack: []tspath.Path,
    host: *anyopaque, // replace tsoptions.ParseConfigHost
    cache: *anyopaque, // replace tsoptions.ExtendedConfigCache
};

pub const ExtendedConfigCacheEntry = struct {
    extendedConfig: *tsoptions.ExtendedConfigCacheEntry,
    hash: u128,
};

pub const ExtendedConfigCache = ownercache.OwnerCache(tspath.Path, *ExtendedConfigCacheEntry, ExtendedConfigParseArgs);

pub fn hash(entry: *tsoptions.ExtendedConfigCacheEntry, args: ExtendedConfigParseArgs) u128 {
    _ = entry;
    _ = args;
    // Mock hash calculation because we don't have the exact FileSource yet
    return 0;
}

pub fn newExtendedConfigCache(allocator: std.mem.Allocator) ExtendedConfigCache {
    return ExtendedConfigCache.init(
        allocator,
        parseExtendedConfig,
        isExpired,
    );
}

fn parseExtendedConfig(path: tspath.Path, args: ExtendedConfigParseArgs) *ExtendedConfigCacheEntry {
    _ = path;
    _ = args;
    @panic("Not implemented: parseExtendedConfig requires full tsoptions port");
}

fn isExpired(path: tspath.Path, entry: *ExtendedConfigCacheEntry, args: ExtendedConfigParseArgs) bool {
    _ = path;
    if (entry.hash == 0) return true;
    return entry.hash != hash(entry.extendedConfig, args);
}
