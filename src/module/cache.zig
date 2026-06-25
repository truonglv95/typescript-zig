const std = @import("std");
const core = @import("../core/core.zig");
const packagejson = @import("../packagejson/packagejson.zig");
const types = @import("types.zig");

pub fn ModeAwareCache(comptime T: type) type {
    return std.AutoHashMap(types.ModeAwareCacheKey, T);
}

pub const ModuleResolutionCacheKey = struct {
    containingDirectory: []const u8,
    moduleName: []const u8,
    resolutionMode: core.ResolutionMode,
    redirectConfigName: []const u8,
};

pub const ModuleResolutionCache = struct {
    cache: std.AutoHashMap(ModuleResolutionCacheKey, *types.ResolvedModule),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ModuleResolutionCache {
        return .{
            .cache = std.AutoHashMap(ModuleResolutionCacheKey, *types.ResolvedModule).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn get(self: *ModuleResolutionCache, key: ModuleResolutionCacheKey) ?*types.ResolvedModule {
        return self.cache.get(key);
    }

    pub fn set(self: *ModuleResolutionCache, key: ModuleResolutionCacheKey, value: *types.ResolvedModule) !void {
        try self.cache.put(key, value);
    }
};

pub const TypeRefDirectiveResolutionCacheKey = struct {
    containingDirectory: []const u8,
    typeReferenceName: []const u8,
    resolutionMode: core.ResolutionMode,
    redirectConfigName: []const u8,
    fromInferredTypesContainingFile: bool,
};

pub const TypeRefDirectiveResolutionCache = struct {
    cache: std.AutoHashMap(TypeRefDirectiveResolutionCacheKey, *types.ResolvedTypeReferenceDirective),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TypeRefDirectiveResolutionCache {
        return .{
            .cache = std.AutoHashMap(TypeRefDirectiveResolutionCacheKey, *types.ResolvedTypeReferenceDirective).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn get(self: *TypeRefDirectiveResolutionCache, key: TypeRefDirectiveResolutionCacheKey) ?*types.ResolvedTypeReferenceDirective {
        return self.cache.get(key);
    }

    pub fn set(self: *TypeRefDirectiveResolutionCache, key: TypeRefDirectiveResolutionCacheKey, value: *types.ResolvedTypeReferenceDirective) !void {
        try self.cache.put(key, value);
    }
};

pub const Caches = struct {
    packageJsonInfoCache: *packagejson.InfoCache,
    moduleResolutionCache: ModuleResolutionCache,
    typeRefDirectiveResolutionCache: TypeRefDirectiveResolutionCache,

    pub fn init(allocator: std.mem.Allocator, currentDirectory: []const u8, useCaseSensitiveFileNames: bool, options: *const core.CompilerOptions) !Caches {
        _ = options;
        const infoCache = try allocator.create(packagejson.InfoCache);
        infoCache.* = packagejson.InfoCache.init(allocator, currentDirectory, useCaseSensitiveFileNames);
        return Caches{
            .packageJsonInfoCache = infoCache,
            .moduleResolutionCache = ModuleResolutionCache.init(allocator),
            .typeRefDirectiveResolutionCache = TypeRefDirectiveResolutionCache.init(allocator),
        };
    }
};
