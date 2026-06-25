const std = @import("std");
const stringutil = @import("../../stringutil/stringutil.zig");

pub fn dedent(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    var lines = std.ArrayList([]const u8).init(allocator);
    defer {
        for (lines.items) |item| {
            allocator.free(item);
        }
        lines.deinit();
    }

    var it = std.mem.splitScalar(u8, text, '\n');
    var startLine: isize = -1;
    var lastLine: usize = 0;

    while (it.next()) |orig_line| {
        var line = orig_line;
        var firstNonWhite: isize = -1;
        for (line, 0..) |c, j| {
            if (!stringutil.isWhiteSpaceLike(c)) {
                firstNonWhite = @intCast(j);
                break;
            }
        }
        
        var modified_line: []u8 = try allocator.dupe(u8, line);
        if (firstNonWhite > 0) {
            const fnw: usize = @intCast(firstNonWhite);
            var new_prefix = std.ArrayList(u8).init(allocator);
            defer new_prefix.deinit();
            
            for (line[0..fnw]) |c| {
                if (c == '\t') {
                    try new_prefix.appendSlice("    ");
                } else {
                    try new_prefix.append(c);
                }
            }
            try new_prefix.appendSlice(line[fnw..]);
            allocator.free(modified_line);
            modified_line = try new_prefix.toOwnedSlice();
        }

        const trimmed = std.mem.trim(u8, modified_line, " \t\r");
        if (trimmed.len != 0) {
            if (startLine == -1) {
                startLine = @intCast(lines.items.len);
            }
            lastLine = lines.items.len;
        }
        try lines.append(modified_line);
    }

    if (startLine == -1) {
        startLine = 0;
    }
    
    var slice_lines = lines.items[@intCast(startLine) .. lastLine + 1];
    var mappedLines = try allocator.alloc([]const u8, slice_lines.len);
    defer allocator.free(mappedLines);
    
    for (slice_lines, 0..) |line, idx| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) {
            mappedLines[idx] = "";
        } else {
            mappedLines[idx] = line;
        }
    }
    
    const indentation = stringutil.guessIndentation(mappedLines);
    if (indentation > 0) {
        for (slice_lines, 0..) |line, idx| {
            if (line.len > indentation) {
                slice_lines[idx] = line[indentation..];
            } else {
                slice_lines[idx] = "";
            }
        }
    }
    
    var result = std.ArrayList(u8).init(allocator);
    for (slice_lines, 0..) |line, idx| {
        if (idx > 0) try result.append('\n');
        try result.appendSlice(line);
    }
    
    return result.toOwnedSlice();
}
