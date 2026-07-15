const std = @import("std");
const test_case_parser = @import("../testrunner/test_case_parser.zig");

pub const Marker = struct {
    name: []const u8,
    position: usize,
};

pub const RangeMarker = struct {
    name: ?[]const u8,
    start: usize,
    end: usize,
};

pub const ParsedTestData = struct {
    arena: *std.heap.ArenaAllocator,
    files: std.StringHashMap([]const u8),
    markerPositions: std.StringHashMap(*Marker),
    ranges: std.ArrayListUnmanaged(*RangeMarker),

    pub fn deinit(self: *ParsedTestData) void {
        const arena_ptr = self.arena;
        const child_alloc = arena_ptr.child_allocator;
        arena_ptr.deinit();
        child_alloc.destroy(arena_ptr);
    }
};

pub fn parseTestData(allocator: std.mem.Allocator, content: []const u8) !*ParsedTestData {
    var arena = try allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(allocator);
    const aa = arena.allocator();

    var result = try aa.create(ParsedTestData);
    result.arena = arena;
    result.files = std.StringHashMap([]const u8).init(aa);
    result.markerPositions = std.StringHashMap(*Marker).init(aa);
    result.ranges = std.ArrayListUnmanaged(*RangeMarker).empty;

    // Split files
    const parsedFiles = try test_case_parser.makeUnitsFromTest(aa, content, "test.ts");

    for (parsedFiles.testUnitData) |unit| {
        var cleanContent = std.ArrayListUnmanaged(u8).empty;
        var i: usize = 0;
        
        const rawContent = unit.content;
        
        // Stack for ranges
        var openRanges = std.ArrayListUnmanaged(usize).empty;

        while (i < rawContent.len) {
            if (i + 1 < rawContent.len and rawContent[i] == '/' and rawContent[i+1] == '*') {
                const end = std.mem.indexOf(u8, rawContent[i..], "*/");
                if (end) |endIdx| {
                    const markerName = std.mem.trim(u8, rawContent[i+2 .. i+endIdx], " \t\r\n");
                    var marker = try aa.create(Marker);
                    marker.name = markerName;
                    marker.position = cleanContent.items.len;
                    try result.markerPositions.put(markerName, marker);
                    i += endIdx + 2;
                    continue;
                }
            } else if (i + 1 < rawContent.len and rawContent[i] == '[' and rawContent[i+1] == '|') {
                try openRanges.append(aa, cleanContent.items.len);
                i += 2;
                continue;
            } else if (i + 1 < rawContent.len and rawContent[i] == '|' and rawContent[i+1] == ']') {
                if (openRanges.items.len > 0) {
                    const start = openRanges.pop().?;
                    var range = try aa.create(RangeMarker);
                    range.start = start;
                    range.end = cleanContent.items.len;
                    range.name = null; // No name attached here, would need object marker parsing
                    try result.ranges.append(aa, range);
                }
                i += 2;
                continue;
            } else if (i + 1 < rawContent.len and rawContent[i] == '{' and rawContent[i+1] == '|') {
                // Object markers {| name: "foo" |}
                const end = std.mem.indexOf(u8, rawContent[i..], "|}");
                if (end) |endIdx| {
                    i += endIdx + 2;
                    continue; // Skip object markers for now
                }
            }
            
            try cleanContent.append(aa, rawContent[i]);
            i += 1;
        }

        try result.files.put(unit.name, try cleanContent.toOwnedSlice(aa));
    }

    return result;
}
