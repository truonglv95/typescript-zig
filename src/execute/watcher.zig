const std = @import("std");
const ast = @import("../ast/ast.zig");
const fswatch = @import("../fswatch/fswatch.zig");
const watchmanager = @import("watchmanager/watchmanager.zig");

pub const CachedSourceFile = struct {
    file: ast.NodeIndex,
    modTime: i64,
};

pub const Watcher = struct {
    allocator: std.mem.Allocator,
    sys: *anyopaque,
    configFileName: []const u8,
    configModified: bool,
    configHasErrors: bool,
    configFilePaths: std.ArrayListUnmanaged([]const u8),
    
    sourceFileCache: std.StringHashMapUnmanaged(CachedSourceFile),
    configMtimes: std.StringHashMapUnmanaged(i64),
    
    wm: *watchmanager.WatchManager,

    pub fn init(allocator: std.mem.Allocator, sys: *anyopaque, wm: *watchmanager.WatchManager) Watcher {
        return .{
            .allocator = allocator,
            .sys = sys,
            .wm = wm,
            .configFileName = "",
            .configModified = false,
            .configHasErrors = false,
            .configFilePaths = .empty,
            .sourceFileCache = .empty,
            .configMtimes = .empty,
        };
    }

    pub fn deinit(self: *Watcher) void {
        self.configFilePaths.deinit(self.allocator);
        self.sourceFileCache.deinit(self.allocator);
        self.configMtimes.deinit(self.allocator);
    }

    pub fn start(self: *Watcher, ctx: *anyopaque) void {
        _ = ctx;
        self.wm.lock();
        
        // Initial build setup
        self.doBuild() catch {
            self.wm.signalDoCycle(); // force overflow
        };
        self.wm.unlock();
    }

    pub fn doCycle(self: *Watcher) void {
        self.wm.lock();
        defer self.wm.unlock();

        const drain_result = self.wm.drainEvents();
        const changedPaths = drain_result.changed;
        const overflow = drain_result.overflow;
        defer {
            var cp = changedPaths;
            cp.deinit(self.allocator);
        }

        const hasEvents = changedPaths.count() > 0 or overflow;

        if (self.recheckTsConfig()) {
            return;
        }

        if (hasEvents and !overflow and !self.configModified) {
            if (self.isRelevantChange(changedPaths)) {
                self.evictChangedSourceFiles(changedPaths);
            } else {
                // Not relevant, skip
                return;
            }
        } else if (overflow) {
            // Evict all
            self.sourceFileCache.clearRetainingCapacity();
        } else if (!hasEvents and !self.configModified) {
            return; // Nothing to do
        }

        // reportWatchStatus
        self.doBuild() catch {
            self.wm.signalDoCycle(); // Trigger next cycle immediately to retry
        };
    }

    pub fn isRelevantChange(self: *Watcher, changedPaths: std.StringHashMapUnmanaged(fswatch.EventKind)) bool {
        _ = self;
        // In real implementation, check if changedPaths match known dependencies or config files
        if (changedPaths.count() > 0) return true;
        return false;
    }

    pub fn evictChangedSourceFiles(self: *Watcher, changedPaths: std.StringHashMapUnmanaged(fswatch.EventKind)) void {
        var it = changedPaths.keyIterator();
        while (it.next()) |path_ptr| {
            _ = self.sourceFileCache.remove(path_ptr.*);
        }
    }

    pub fn doBuild(self: *Watcher) !void {
        if (self.configModified) {
            self.sourceFileCache.clearRetainingCapacity();
        }

        // Simulate compiling and updating file maps
        // ...
        
        self.configModified = false;
    }

    pub fn recheckTsConfig(self: *Watcher) bool {
        if (self.configFileName.len == 0) return false;
        
        if (!self.configHasErrors and self.configFilePaths.items.len > 0) {
            // Check mtime
            var changed = false;
            for (self.configFilePaths.items) |path| {
                if (!self.configMtimes.contains(path)) {
                    changed = true;
                    break;
                }
            }
            if (!changed) return false;
        }
        
        // Re-parse config
        self.configHasErrors = false;
        return false;
    }
};
