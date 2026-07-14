const std = @import("std");
pub const WindowLogMessageInfo = struct {
    pub fn newNotificationMessage(args: anytype) !WindowLogMessageInfo { _ = args; return .{}; }
    pub fn message(self: *const WindowLogMessageInfo) []const u8 { _ = self; return ""; }
};
pub const FileSystemWatcher = struct {};
pub const DocumentUri = []const u8;
pub const TextDocumentContentChangePartialOrWholeDocument = union(enum) {
    PartialDocument: struct { text: []const u8 },
    WholeDocument: struct { text: []const u8 },
};
pub const FileEvent = struct {
    type: enum { Created, Changed, Deleted },
    uri: []const u8,
};
