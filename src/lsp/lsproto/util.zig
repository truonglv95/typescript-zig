const std = @import("std");
const lsproto = @import("lsp_generated.zig");

pub fn comparePositions(pos: lsproto.Position, other: lsproto.Position) std.math.Order {
    const line_comp = std.math.order(pos.line, other.line);
    if (line_comp != .eq) {
        return line_comp;
    }
    return std.math.order(pos.character, other.character);
}

pub fn compareRanges(lsRange: lsproto.Range, other: lsproto.Range) std.math.Order {
    const start_comp = comparePositions(lsRange.start, other.start);
    if (start_comp != .eq) {
        return start_comp;
    }
    return comparePositions(lsRange.end, other.end);
}

pub fn asString(m: lsproto.StringOrMarkupContent) []const u8 {
    // StringOrMarkupContent maps to std.json.Value in our python generator because it's an `or` type.
    // Wait, in lsp_generated.zig, what is StringOrMarkupContent? It's std.json.Value.
    switch (m) {
        .string => |s| return s,
        .object => |obj| {
            if (obj.get("value")) |val| {
                if (val == .string) return val.string;
            }
        },
        else => {},
    }
    return "";
}
