const std = @import("std");
const diagnostics = @import("../diagnostics/diagnostics.zig");

pub const WatcherID = []const u8;
pub const FileSystemWatcher = opaque {};
pub const PublishDiagnosticsParams = opaque {};
pub const TelemetryEvent = opaque {};

pub const Client = struct {
    ptr: *anyopaque,
    
    // Callbacks to avoid interface dispatch overhead (C-style vtable)
    watchFilesFn: *const fn (ptr: *anyopaque, id: WatcherID, watchers: []*FileSystemWatcher) anyerror!void,
    unwatchFilesFn: *const fn (ptr: *anyopaque, id: WatcherID) anyerror!void,
    refreshDiagnosticsFn: *const fn (ptr: *anyopaque) anyerror!void,
    publishDiagnosticsFn: *const fn (ptr: *anyopaque, params: *PublishDiagnosticsParams) anyerror!void,
    refreshInlayHintsFn: *const fn (ptr: *anyopaque) anyerror!void,
    refreshCodeLensFn: *const fn (ptr: *anyopaque) anyerror!void,
    progressStartFn: *const fn (ptr: *anyopaque, message: *diagnostics.Message, args: [][]const u8) void,
    progressFinishFn: *const fn (ptr: *anyopaque, message: *diagnostics.Message, args: [][]const u8) void,
    sendTelemetryFn: *const fn (ptr: *anyopaque, telemetry: *TelemetryEvent) anyerror!void,
    isActiveFn: *const fn (ptr: *anyopaque) bool,

    pub fn watchFiles(self: Client, id: WatcherID, watchers: []*FileSystemWatcher) !void {
        return self.watchFilesFn(self.ptr, id, watchers);
    }
    
    pub fn unwatchFiles(self: Client, id: WatcherID) !void {
        return self.unwatchFilesFn(self.ptr, id);
    }

    pub fn refreshDiagnostics(self: Client) !void {
        return self.refreshDiagnosticsFn(self.ptr);
    }

    pub fn isActive(self: Client) bool {
        return self.isActiveFn(self.ptr);
    }
    
    // And so on for the rest...
};
