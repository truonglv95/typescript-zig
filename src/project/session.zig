const std = @import("std");
const core = @import("../core/core.zig");
const tspath = @import("../tspath/tspath.zig");
const project = @import("project.zig");
const filechange = @import("filechange.zig");
const autoimport = @import("../ls/autoimport/registry.zig");
const lsproto = @import("../lsp/lsproto.zig");
const snapshot_pkg = @import("snapshot.zig");

pub const UpdateReason = enum {
    Unknown,
    DidOpenFile,
    DidCloseFile,
    DidChangeCompilerOptionsForInferredProjects,
    RequestedLanguageServicePendingChanges,
    RequestedLanguageServiceProjectNotLoaded,
    RequestedLanguageServiceForFileNotOpen,
    RequestedLanguageServiceProjectDirty,
    RequestedLoadProjectTree,
    RequestedLanguageServiceWithAutoImports,
    IdleCleanDiskCache,
};

pub const SessionOptions = struct {
    currentDirectory: []const u8,
    defaultLibraryPath: []const u8,
    typingsLocation: []const u8,
    // positionEncoding: lsproto.PositionEncodingKind,
    watchEnabled: bool,
    loggingEnabled: bool,
    telemetryEnabled: bool,
    pushDiagnosticsEnabled: bool,
    debounceDelayMs: u64,
};

pub const SessionInit = struct {
    options: *SessionOptions,
    // fs: *vfs.FS,
    // parseCache: *ParseCache,
};

pub const SnapshotChange = struct {
    reason: UpdateReason = .Unknown,
    fileChanges: filechange.FileChangeSummary,
    requestedFile: ?[]const u8 = null,
    // ataChanges: ATAChanges,
    // apiRequest: ...
};

pub const Session = struct {
    options: *SessionOptions,
    startTime: i64,

    snapshotID: std.atomic.Value(u64),

    snapshot: ?*snapshot_pkg.Snapshot = null,

    scheduledSnapshotUpdateGeneration: u64 = 0,

    pendingFileChanges: std.ArrayList(filechange.FileChange),
    overlays: std.StringHashMap(void),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, args: *SessionInit) Session {
        return .{
            .options = args.options,
            .startTime = 0,
            .snapshotID = std.atomic.Value(u64).init(0),
            .pendingFileChanges = std.ArrayList(filechange.FileChange).empty,
            .overlays = std.StringHashMap(void).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn getCurrentLanguageServiceWithAutoImports(self: *Session, uri: []const u8) !void {
        _ = try self.getSnapshot(.RequestedLanguageServiceWithAutoImports, uri);
    }

    pub fn getSnapshot(self: *Session, reason: UpdateReason, requestedFile: ?[]const u8) !*snapshot_pkg.Snapshot {
        self.cancelScheduledSnapshotUpdate();

        var summary = filechange.FileChangeSummary.init(self.allocator);
        const flushed = try self.flushChanges(&summary);

        if (flushed or self.snapshot == null) {
            self.snapshot = try self.updateSnapshotRef(self.overlays, SnapshotChange{
                .reason = reason,
                .fileChanges = summary,
                .requestedFile = requestedFile,
            });
        } else if (reason == .RequestedLanguageServiceWithAutoImports) {
            self.snapshot = try self.updateSnapshotRef(self.overlays, SnapshotChange{
                .reason = reason,
                .fileChanges = summary, // empty
                .requestedFile = requestedFile,
            });
        }

        return self.snapshot.?;
    }

    pub fn didOpenFile(self: *Session, uri: []const u8, version: i32, text: []const u8, lang: anytype) !void {
        _ = lang;
        self.cancelScheduledSnapshotUpdate();
        try self.pendingFileChanges.append(self.allocator, .{
            .kind = .Open,
            .uri = uri,
            .version = version,
            .content = text,
        });
    }

    pub fn didChangeFile(self: *Session, uri: []const u8, version: i32, changes: anytype) !void {
        _ = changes;
        self.cancelScheduledSnapshotUpdate();
        try self.pendingFileChanges.append(self.allocator, .{
            .kind = .Change,
            .uri = uri,
            .version = version,
        });
    }

    pub fn getLanguageService(self: *Session, uri: []const u8) !void {
        _ = uri;
        _ = try self.getSnapshot(.RequestedLanguageServicePendingChanges, null);
    }

    pub fn didCloseFile(self: *Session, uri: []const u8) !void {
        self.cancelScheduledSnapshotUpdate();
        try self.pendingFileChanges.append(self.allocator, .{
            .kind = .Close,
            .uri = uri,
        });
    }

    pub fn didChangeWatchedFiles(self: *Session, events: []const lsproto.FileEvent) !void {
        self.cancelScheduledSnapshotUpdate();
        for (events) |event| {
            try self.pendingFileChanges.append(self.allocator, .{
                .kind = if (event.type == .Created) .WatchCreate else if (event.type == .Changed) .WatchChange else .WatchDelete,
                .uri = event.uri,
            });
        }
    }

    pub fn cancelScheduledSnapshotUpdate(self: *Session) void {
        self.scheduledSnapshotUpdateGeneration += 1;
    }

    pub fn flushChanges(self: *Session, summary: *filechange.FileChangeSummary) !bool {
        if (self.pendingFileChanges.items.len == 0) return false;

        for (self.pendingFileChanges.items) |change| {
            switch (change.kind) {
                .Open => {
                    summary.opened = change.uri;
                    try self.overlays.put(change.uri, {});
                },
                .Close => {
                    try summary.closed.put(change.uri, {});
                    _ = self.overlays.remove(change.uri);
                },
                .Change => {
                    try summary.changed.put(change.uri, {});
                    try self.overlays.put(change.uri, {});
                },
                .Save => {},
                .WatchCreate => try summary.created.put(change.uri, {}),
                .WatchChange => try summary.changed.put(change.uri, {}),
                .WatchDelete => try summary.deleted.put(change.uri, {}),
            }
        }
        self.pendingFileChanges.clearRetainingCapacity();
        return true;
    }

    pub fn updateSnapshotRef(self: *Session, overlays: std.StringHashMap(void), change: SnapshotChange) !*snapshot_pkg.Snapshot {
        if (self.snapshot) |snap| {
            return try snap.clone(self.allocator, change, overlays, self);
        }

        // Initial snapshot
        const newSnapshotID = self.snapshotID.fetchAdd(1, .monotonic) + 1;
        const newSnapshot = try snapshot_pkg.Snapshot.init(
            self.allocator,
            newSnapshotID,
            null, // fs
            self.options,
            null, // config
            null, // inferred
            null, // autoImports
            null, // autoImportsWatch
        );
        return newSnapshot;
    }
};
