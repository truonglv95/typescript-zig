const std = @import("std");
const core = @import("../core/core.zig");

pub const ECMALineInfo = struct {
    text: []const u8,
    lineStarts: core.ECMALineStarts,

    pub fn create(allocator: std.mem.Allocator, text: []const u8, lineStarts: core.ECMALineStarts) !*ECMALineInfo {
        const li = try allocator.create(ECMALineInfo);
        li.* = .{
            .text = text,
            .lineStarts = lineStarts,
        };
        return li;
    }

    pub fn lineCount(self: *const ECMALineInfo) usize {
        return self.lineStarts.len;
    }

    pub fn lineText(self: *const ECMALineInfo, line: usize) []const u8 {
        const pos = self.lineStarts[line];
        var end: core.TextPos = undefined;
        if (line + 1 < self.lineStarts.len) {
            end = self.lineStarts[line + 1];
        } else {
            end = @as(core.TextPos, @intCast(self.text.len));
        }
        return self.text[@as(usize, @intCast(pos))..@as(usize, @intCast(end))];
    }
};
