const std = @import("std");
const core = @import("../../core/core.zig");

pub const LSPLineStarts = []const core.TextPos;

pub const LSPLineMap = struct {
    line_starts: LSPLineStarts,
    ascii_only: bool,

    pub fn computeIndexOfLineStart(self: *const LSPLineMap, target_pos: core.TextPos) usize {
        var lo: usize = 0;
        var hi: usize = self.line_starts.len;

        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            if (self.line_starts[mid] <= target_pos) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        return lo - 1;
    }

    pub fn computeLineAndCharacter(self: *const LSPLineMap, target_pos: core.TextPos) core.TextPos {
        const line = self.computeIndexOfLineStart(target_pos);
        return .{
            .line = line,
            .character = target_pos - self.line_starts[line],
        };
    }
};

pub fn computeLSPLineStarts(allocator: std.mem.Allocator, text: []const u8) !LSPLineMap {
    var line_starts = std.ArrayList(core.TextPos).empty;
    errdefer line_starts.deinit(allocator);

    var ascii_only = true;
    const text_len: core.TextPos = @intCast(text.len);
    var pos: core.TextPos = 0;
    var line_start: core.TextPos = 0;

    while (pos < text_len) {
        const b = text[pos];
        if (b < 128) {
            pos += 1;
            switch (b) {
                '\r' => {
                    if (pos < text_len and text[pos] == '\n') {
                        pos += 1;
                    }
                    try line_starts.append(allocator, line_start);
                    line_start = pos;
                },
                '\n' => {
                    try line_starts.append(allocator, line_start);
                    line_start = pos;
                },
                else => {},
            }
        } else {
            const size = std.unicode.utf8ByteSequenceLength(b) catch 1;
            pos += @intCast(size);
            ascii_only = false;
        }
    }
    try line_starts.append(allocator, line_start);

    return LSPLineMap{
        .line_starts = try line_starts.toOwnedSlice(allocator),
        .ascii_only = ascii_only,
    };
}

