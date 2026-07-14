const std = @import("std");
const diagnostics = @import("../../diagnostics/diagnostics.zig");
const lsproto = @import("../../lsp/lsproto.zig");
const project = @import("../../project/project.zig");

pub const ClientMock = struct {
    allocator: std.mem.Allocator,

    ctx: ?*anyopaque = null,
    isActiveFunc: ?*const fn(ctx: ?*anyopaque) bool = null,
    progressFinishFunc: ?*const fn(ctx: ?*anyopaque, message: *diagnostics.Message, args: [][]const u8) void = null,
    progressStartFunc: ?*const fn(ctx: ?*anyopaque, message: *diagnostics.Message, args: [][]const u8) void = null,
    publishDiagnosticsFunc: ?*const fn(ctx: ?*anyopaque, params: *project.PublishDiagnosticsParams) anyerror!void = null,
    refreshCodeLensFunc: ?*const fn(ctx: ?*anyopaque) anyerror!void = null,
    refreshDiagnosticsFunc: ?*const fn(ctx: ?*anyopaque) anyerror!void = null,
    refreshInlayHintsFunc: ?*const fn(ctx: ?*anyopaque) anyerror!void = null,
    sendTelemetryFunc: ?*const fn(ctx: ?*anyopaque, telemetry: *project.TelemetryEvent) anyerror!void = null,
    unwatchFilesFunc: ?*const fn(ctx: ?*anyopaque, id: project.WatcherID) anyerror!void = null,
    watchFilesFunc: ?*const fn(ctx: ?*anyopaque, id: project.WatcherID, watchers: []*project.FileSystemWatcher) anyerror!void = null,

    calls: struct {
        isActive: std.ArrayList(void),
        progressFinish: std.ArrayList(ProgressCall),
        progressStart: std.ArrayList(ProgressCall),
        publishDiagnostics: std.ArrayList(PublishDiagnosticsCall),
        refreshCodeLens: std.ArrayList(void),
        refreshDiagnostics: std.ArrayList(void),
        refreshInlayHints: std.ArrayList(void),
        sendTelemetry: std.ArrayList(SendTelemetryCall),
        unwatchFiles: std.ArrayList(UnwatchFilesCall),
        watchFiles: std.ArrayList(WatchFilesCall),
    },

    pub const ProgressCall = struct {
        message: *diagnostics.Message,
    };

    pub const PublishDiagnosticsCall = struct {
        params: *project.PublishDiagnosticsParams,
    };

    pub const SendTelemetryCall = struct {
        telemetry: *project.TelemetryEvent,
    };

    pub const UnwatchFilesCall = struct {
        id: project.WatcherID,
    };

    pub const WatchFilesCall = struct {
        id: project.WatcherID,
        watchers: []*project.FileSystemWatcher,
    };



    pub fn init(allocator: std.mem.Allocator) ClientMock {
        return .{
            .allocator = allocator,
            .calls = .{
                .isActive = std.ArrayList(void).empty,
                .progressFinish = std.ArrayList(ProgressCall).empty,
                .progressStart = std.ArrayList(ProgressCall).empty,
                .publishDiagnostics = std.ArrayList(PublishDiagnosticsCall).empty,
                .refreshCodeLens = std.ArrayList(void).empty,
                .refreshDiagnostics = std.ArrayList(void).empty,
                .refreshInlayHints = std.ArrayList(void).empty,
                .sendTelemetry = std.ArrayList(SendTelemetryCall).empty,
                .unwatchFiles = std.ArrayList(UnwatchFilesCall).empty,
                .watchFiles = std.ArrayList(WatchFilesCall).empty,
            },
        };
    }

    pub fn deinit(self: *ClientMock) void {
        self.calls.isActive.deinit();
        self.calls.progressFinish.deinit();
        self.calls.progressStart.deinit();
        self.calls.publishDiagnostics.deinit();
        self.calls.refreshCodeLens.deinit();
        self.calls.refreshDiagnostics.deinit();
        self.calls.refreshInlayHints.deinit();
        self.calls.sendTelemetry.deinit();
        self.calls.unwatchFiles.deinit();
        self.calls.watchFiles.deinit();
    }

    pub fn isActive(self: *ClientMock) bool {
        self.calls.isActive.append({}) catch {};
        if (self.isActiveFunc) |f| {
            return f(self.ctx);
        }
        return false;
    }

    pub fn progressFinish(self: *ClientMock, message: *diagnostics.Message, args: [][]const u8) void {
        self.calls.progressFinish.append(.{ .message = message }) catch {};
        if (self.progressFinishFunc) |f| {
            f(self.ctx, message, args);
        }
    }

    pub fn progressStart(self: *ClientMock, message: *diagnostics.Message, args: [][]const u8) void {
        self.calls.progressStart.append(.{ .message = message }) catch {};
        if (self.progressStartFunc) |f| {
            f(self.ctx, message, args);
        }
    }

    pub fn publishDiagnostics(self: *ClientMock, params: *project.PublishDiagnosticsParams) anyerror!void {
        try self.calls.publishDiagnostics.append(.{ .params = params });
        if (self.publishDiagnosticsFunc) |f| {
            return f(self.ctx, params);
        }
    }

    pub fn refreshCodeLens(self: *ClientMock) !void {
        try self.calls.refreshCodeLens.append({});
        if (self.refreshCodeLensFunc) |f| {
            return f(self.ctx);
        }
    }

    pub fn refreshDiagnostics(self: *ClientMock) !void {
        try self.calls.refreshDiagnostics.append({});
        if (self.refreshDiagnosticsFunc) |f| {
            return f(self.ctx);
        }
    }

    pub fn refreshInlayHints(self: *ClientMock) !void {
        try self.calls.refreshInlayHints.append({});
        if (self.refreshInlayHintsFunc) |f| {
            return f(self.ctx);
        }
    }

    pub fn sendTelemetry(self: *ClientMock, telemetry: *project.TelemetryEvent) anyerror!void {
        try self.calls.sendTelemetry.append(.{ .telemetry = telemetry });
        if (self.sendTelemetryFunc) |f| {
            return f(self.ctx, telemetry);
        }
    }

    pub fn unwatchFiles(self: *ClientMock, id: project.WatcherID) !void {
        try self.calls.unwatchFiles.append(.{ .id = id });
        if (self.unwatchFilesFunc) |f| {
            return f(self.ctx, id);
        }
    }

    pub fn watchFiles(self: *ClientMock, id: project.WatcherID, watchers: []*project.FileSystemWatcher) anyerror!void {
        try self.calls.watchFiles.append(.{ .id = id, .watchers = watchers });
        if (self.watchFilesFunc) |f| {
            return f(self.ctx, id, watchers);
        }
    }

    pub fn isActiveCalls(self: *ClientMock) []const void {
        return self.calls.isActive.items;
    }

    pub fn watchFilesCalls(self: *ClientMock) []const WatchFilesCall {
        return self.calls.watchFiles.items;
    }
};
