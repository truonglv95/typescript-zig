const std = @import("std");
const core = @import("../core/core.zig");
const tspath = @import("../tspath/tspath.zig");
const filechange = @import("filechange.zig");

pub const FileHandleTag = enum {
    diskFile,
    overlay,
};

pub const FileBase = struct {
    fileName: []const u8,
    content: []const u8,
    hash: u128,
};

pub const DiskFile = struct {
    base: FileBase,
    needsReload: bool,
    realpathPath: tspath.Path,
};

pub const Overlay = struct {
    base: FileBase,
    version: i32,
    kind: core.ScriptKind,
    matchesDiskText: bool,
};

pub const FileHandle = union(FileHandleTag) {
    diskFile: DiskFile,
    overlay: Overlay,

    pub fn content(self: *const FileHandle) []const u8 {
        switch (self.*) {
            .diskFile => |*d| return d.base.content,
            .overlay => |*o| return o.base.content,
        }
    }

    pub fn hash(self: *const FileHandle) u128 {
        switch (self.*) {
            .diskFile => |*d| return d.base.hash,
            .overlay => |*o| return o.base.hash,
        }
    }

    pub fn fileName(self: *const FileHandle) []const u8 {
        switch (self.*) {
            .diskFile => |*d| return d.base.fileName,
            .overlay => |*o| return o.base.fileName,
        }
    }

    pub fn version(self: *const FileHandle) i32 {
        switch (self.*) {
            .diskFile => return 0,
            .overlay => |*o| return o.version,
        }
    }

    pub fn matchesDiskText(self: *const FileHandle) bool {
        switch (self.*) {
            .diskFile => |*d| return !d.needsReload,
            .overlay => |*o| return o.matchesDiskText,
        }
    }

    pub fn isOverlay(self: *const FileHandle) bool {
        return self.* == .overlay;
    }

    pub fn kind(self: *const FileHandle) core.ScriptKind {
        switch (self.*) {
            .diskFile => |*d| return core.getScriptKindFromFileName(d.base.fileName),
            .overlay => |*o| return o.kind,
        }
    }
};

pub const OverlayFS = struct {
    toPath: *const fn ([]const u8) tspath.Path,
    overlays: std.StringHashMap(Overlay),
    mu: std.Thread.RwLock = .{},
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, toPathFn: *const fn ([]const u8) tspath.Path) OverlayFS {
        return .{
            .toPath = toPathFn,
            .overlays = std.StringHashMap(Overlay).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn getFile(self: *OverlayFS, fileName: []const u8) ?FileHandle {
        self.mu.lockShared();
        defer self.mu.unlockShared();

        const path = self.toPath(fileName);
        if (self.overlays.get(path)) |overlay| {
            return FileHandle{ .overlay = overlay };
        }

        // normally we would read from disk here
        return null;
    }

    pub fn processChanges(self: *OverlayFS, changes: []const filechange.FileChange) !struct { filechange.FileChangeSummary, std.StringHashMap(Overlay) } {
        self.mu.lock();
        defer self.mu.unlock();

        var result = filechange.FileChangeSummary.init(self.allocator);
        var newOverlays = try self.cloneOverlays(self.allocator, &self.overlays);

        // mock process logic:
        for (changes) |change| {
            if (change.kind == .Open) {
                result.opened = change.uri;
                try newOverlays.put(self.toPath(change.uri), Overlay{
                    .base = .{ .fileName = change.uri, .content = change.content, .hash = 0 },
                    .version = change.version,
                    .kind = core.getScriptKindFromFileName(change.uri),
                    .matchesDiskText = false,
                });
            } else if (change.kind == .Close) {
                try result.closed.put(change.uri, {});
                _ = newOverlays.swapRemove(self.toPath(change.uri));
            } else if (change.kind == .Change) {
                try result.changed.put(change.uri, {});
                if (newOverlays.getPtr(self.toPath(change.uri))) |o| {
                    o.version = change.version;
                }
            }
        }

        self.overlays = newOverlays;
        return .{ result, newOverlays };
    }

    fn cloneOverlays(self: *OverlayFS, allocator: std.mem.Allocator, map: *const std.StringHashMap(Overlay)) !std.StringHashMap(Overlay) {
        _ = self;
        var new_map = std.StringHashMap(Overlay).init(allocator);
        var it = map.iterator();
        while (it.next()) |entry| {
            try new_map.put(entry.key_ptr.*, entry.value_ptr.*);
        }
        return new_map;
    }
};
