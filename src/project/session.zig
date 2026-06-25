const std = @import("std");
const core = @import("../core/core.zig");
const tspath = @import("../tspath/tspath.zig");
const project = @import("project.zig");
const filechange = @import("filechange.zig");
const autoimport = @import("../ls/autoimport/registry.zig");
const lsproto = @import("../lsp/lsproto.zig");

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

pub const Snapshot = opaque {
    pub fn autoImportRegistry(self: *Snapshot) ?*autoimport.Registry {
        _ = self; return null;
    }
    pub fn getDefaultProject(self: *Snapshot, uri: []const u8) ?*project.Project {
        _ = self; _ = uri; return null;
    }
};

pub const SnapshotChange = struct {
    reason: UpdateReason = .Unknown,
    fileChanges: filechange.FileChangeSummary,
    // ataChanges: ATAChanges,
    // apiRequest: ...
};

pub const Session = struct {
    options: *SessionOptions,
    startTime: i64,
    
    snapshotID: std.atomic.Value(u64),
    
    snapshot: ?*Snapshot = null,
    
    scheduledSnapshotUpdateGeneration: u64 = 0,
    
    pendingFileChanges: std.ArrayList(filechange.FileChange),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, args: *SessionInit) Session {
        return .{
            .options = args.options,
            .startTime = 0,
            .snapshotID = std.atomic.Value(u64).init(0),
            .pendingFileChanges = std.ArrayList(filechange.FileChange).empty,
            .allocator = allocator,
        };
    }

    pub fn getCurrentLanguageServiceWithAutoImports(self: *Session, uri: []const u8) !void {
        _ = self; _ = uri;
    }
    pub fn didOpenFile(self: *Session, uri: []const u8, version: i32, text: []const u8, lang: anytype) !void {
        _ = self; _ = uri; _ = version; _ = text; _ = lang;
    }
    pub fn didChangeFile(self: *Session, uri: []const u8, version: i32, changes: anytype) !void {
        _ = self; _ = uri; _ = version; _ = changes;
    }
    pub fn getLanguageService(self: *Session, uri: []const u8) !void {
        _ = self; _ = uri;
    }
    pub fn didCloseFile(self: *Session, uri: []const u8) !void {
        _ = self; _ = uri;
    }
    pub fn didChangeWatchedFiles(self: *Session, events: []const lsproto.FileEvent) !void {
        _ = self; _ = events;
    }
    pub fn cancelScheduledSnapshotUpdate(self: *Session) void {
        self.scheduledSnapshotUpdateGeneration += 1;
        // background task cancellation omitted
    }

    // flushChanges returns the currently pending changes. 
    // In DoD, we return allocated or arena-backed structures.
    pub fn flushChanges(self: *Session) !struct { filechange.FileChangeSummary, std.StringArrayHashMap(void) } {
        const summary = filechange.FileChangeSummary.init(self.allocator);
        // process pendingFileChanges into summary...
        self.pendingFileChanges.clearRetainingCapacity();
        
        const overlays = std.StringArrayHashMap(void).init(self.allocator);
        return .{ summary, overlays };
    }

    pub fn updateSnapshotRef(self: *Session, overlays: std.StringArrayHashMap(void), change: SnapshotChange) !*Snapshot {
        _ = overlays;
        _ = change;
        // Create new snapshot logic goes here
        if (self.snapshot) |s| return s;
        // mock return
        return @ptrCast(self); 
    }
};
