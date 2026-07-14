pub const Converters = struct {
    pub fn lineAndCharacterToPosition(self: *Converters, file: anytype, position: anytype) u32 {
        _ = self;
        _ = file;
        _ = position;
        return 0;
    }
    pub fn toLSPRange(self: *const Converters, script: anytype, text_range: anytype) @import("../lsp/lsproto/lsproto.zig").Range {
        _ = self;
        _ = script;
        _ = text_range;
        return .{};
    }
    pub fn positionToLineAndCharacter(self: *Converters, script: anytype, pos: anytype) @import("../lsp/lsproto/lsproto.zig").Position {
        _ = self;
        _ = script;
        _ = pos;
        return .{ .line = 0, .character = 0 };
    }
};

const std = @import("std");

pub const Script = struct {
    file_name: []const u8,
    content: []const u8,
};

pub fn fileNameToDocumentURI(allocator: std.mem.Allocator, filename: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "file://{s}", .{filename});
}

pub fn documentURIToFileName(allocator: std.mem.Allocator, uri: []const u8) ![]const u8 {
    if (std.mem.startsWith(u8, uri, "file://")) {
        return try allocator.dupe(u8, uri["file://".len..]);
    }
    return try allocator.dupe(u8, uri);
}
