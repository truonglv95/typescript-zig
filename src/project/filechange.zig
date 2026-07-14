const std = @import("std");

pub const DocumentUri = []const u8;
pub const LanguageKind = u32;

pub const excessiveChangeThreshold = 1000;

pub const FileChangeKind = enum {
    Open,
    Close,
    Change,
    Save,
    WatchCreate,
    WatchChange,
    WatchDelete,

    pub fn isWatchKind(self: FileChangeKind) bool {
        return self == .WatchCreate or self == .WatchChange or self == .WatchDelete;
    }
};

pub const TextDocumentContentChangePartialOrWholeDocument = struct {
    text: []const u8,
};

pub const FileChange = struct {
    kind: FileChangeKind,
    uri: DocumentUri,
    version: i32 = 0,
    content: []const u8 = "",
    languageKind: LanguageKind = 0,
    changes: []const TextDocumentContentChangePartialOrWholeDocument = &[_]TextDocumentContentChangePartialOrWholeDocument{},
};

pub const FileChangeSummary = struct {
    opened: DocumentUri = "",
    reopened: DocumentUri = "",
    closed: std.StringHashMap(void),
    changed: std.StringHashMap(void),
    created: std.StringHashMap(void),
    deleted: std.StringHashMap(void),
    includesWatchChangeOutsideNodeModules: bool = false,
    invalidateAll: bool = false,

    pub fn init(allocator: std.mem.Allocator) FileChangeSummary {
        return .{
            .closed = std.StringHashMap(void).init(allocator),
            .changed = std.StringHashMap(void).init(allocator),
            .created = std.StringHashMap(void).init(allocator),
            .deleted = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn isEmpty(self: *const FileChangeSummary) bool {
        return !self.invalidateAll and self.opened.len == 0 and self.reopened.len == 0 and self.closed.count() == 0 and self.changed.count() == 0 and self.created.count() == 0 and self.deleted.count() == 0;
    }

    pub fn hasExcessiveWatchEvents(self: *const FileChangeSummary) bool {
        return self.invalidateAll or self.created.count() + self.deleted.count() + self.changed.count() > excessiveChangeThreshold;
    }

    pub fn hasExcessiveNonCreateWatchEvents(self: *const FileChangeSummary) bool {
        return self.invalidateAll or self.deleted.count() + self.changed.count() > excessiveChangeThreshold;
    }

    pub fn merge(self: *FileChangeSummary, src: *const FileChangeSummary) !void {
        if (src.isEmpty()) return;
        if (src.invalidateAll) self.invalidateAll = true;

        var it1 = src.changed.keyIterator();
        while (it1.next()) |k| try self.changed.put(k.*, {});

        var it2 = src.created.keyIterator();
        while (it2.next()) |k| try self.created.put(k.*, {});

        var it3 = src.deleted.keyIterator();
        while (it3.next()) |k| try self.deleted.put(k.*, {});

        if (src.includesWatchChangeOutsideNodeModules) {
            self.includesWatchChangeOutsideNodeModules = true;
        }
    }
};
