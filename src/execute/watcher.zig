const std = @import("std");
const ast = @import("../ast/ast.zig");
// const compiler = @import("../compiler/compiler.zig");
// const watchmanager = @import("../watchmanager/watchmanager.zig");

pub const CachedSourceFile = struct {
    file: ast.NodeIndex, // DoD: using NodeIndex instead of *ast.SourceFile
    modTime: i64,
};

// watchCompilerHost embeds compiler.CompilerHost in Go
pub const WatchCompilerHost = struct {
    // host: *compiler.CompilerHost,
    cache: std.StringHashMap(CachedSourceFile),
};

pub const Watcher = struct {
    allocator: std.mem.Allocator,
    sys: *anyopaque,
    configFileName: []const u8,
    // config: *tsoptions.ParsedCommandLine,
    // compilerOptionsFromCommandLine: *core.CompilerOptions,
    configModified: bool,
    configHasErrors: bool,
    configFilePaths: std.ArrayList([]const u8),
    
    sourceFileCache: std.StringHashMap(CachedSourceFile),
    // wm: *watchmanager.WatchManager,
    // seenFiles: std.StringHashMap(void),
    configMtimes: std.StringHashMap(i64),

    pub fn init(allocator: std.mem.Allocator, sys: *anyopaque) Watcher {
        return .{
            .allocator = allocator,
            .sys = sys,
            .configFileName = "",
            .configModified = false,
            .configHasErrors = false,
            .configFilePaths = std.ArrayList([]const u8).init(allocator),
            .sourceFileCache = std.StringHashMap(CachedSourceFile).init(allocator),
            .configMtimes = std.StringHashMap(i64).init(allocator),
        };
    }

    pub fn deinit(self: *Watcher) void {
        self.configFilePaths.deinit();
        self.sourceFileCache.deinit();
        self.configMtimes.deinit();
    }

    pub fn start(self: *Watcher, ctx: *anyopaque) void {
        _ = self;
        _ = ctx;
        // TODO: Implement Watcher.start
    }

    pub fn doCycle(self: *Watcher) void {
        _ = self;
        // TODO: Implement Watcher.DoCycle
    }

    pub fn doBuild(self: *Watcher) !void {
        _ = self;
        // TODO: Implement Watcher.doBuild
    }

    pub fn evictChangedSourceFiles(self: *Watcher, changedPaths: std.StringHashMap(u32)) void {
        _ = self;
        _ = changedPaths;
        // TODO: evict caches
    }
};
