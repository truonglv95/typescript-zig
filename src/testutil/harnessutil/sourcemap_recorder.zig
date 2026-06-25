const std = @import("std");

pub const WriterAggregator = struct {
    list: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) WriterAggregator {
        return .{ .list = std.ArrayList(u8).init(allocator) };
    }

    pub fn deinit(self: *WriterAggregator) void {
        self.list.deinit();
    }

    pub fn writeString(self: *WriterAggregator, s: []const u8) !void {
        try self.list.appendSlice(s);
    }

    pub fn writeStringf(self: *WriterAggregator, comptime format: []const u8, args: anytype) !void {
        var writer = self.list.writer();
        try std.fmt.format(writer, format, args);
    }

    pub fn writeLine(self: *WriterAggregator, s: []const u8) !void {
        try self.list.appendSlice(s);
        try self.list.appendSlice("\r\n");
    }

    pub fn writeLinef(self: *WriterAggregator, comptime format: []const u8, args: anytype) !void {
        try self.writeStringf(format, args);
        try self.list.appendSlice("\r\n");
    }
};

pub const SourceMapSpanWithDecodeErrors = struct {
    sourceMapSpan: *anyopaque,
    decodeErrors: [][]const u8,
};

pub const DecodedMapping = struct {
    sourceMapSpan: *anyopaque,
    err: ?anyerror,
};

pub const SourceMapDecoder = struct {
    sourceMapMappings: []const u8,
    mappings: *anyopaque,

    pub fn decodeNextEncodedSourceMapSpan(self: *SourceMapDecoder) !*DecodedMapping {
        _ = self;
        unreachable;
    }

    pub fn hasCompletedDecoding(self: *SourceMapDecoder) bool {
        _ = self;
        unreachable;
    }

    pub fn getRemainingDecodeString(self: *SourceMapDecoder) []const u8 {
        _ = self;
        unreachable;
    }
};

pub const SourceMapSpanWriter = struct {
    sourceMapRecorder: *WriterAggregator,
    sourceMapSources: [][]const u8,
    sourceMapNames: [][]const u8,
    jsFile: *anyopaque,
    jsLineMap: []u32,
    tsCode: []const u8,
    tsLineMap: []u32,
    spansOnSingleLine: []SourceMapSpanWithDecodeErrors,
    prevWrittenSourcePos: usize,
    nextJsLineToWrite: usize,
    spanMarkerContinues: bool,
    sourceMapDecoder: *SourceMapDecoder,

    // ... methods ...
};
