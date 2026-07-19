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
    combinedContent: []const u8 = "",

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
    const parsedFiles = try test_case_parser.parseTestFilesAndSymlinksWithOptions(test_case_parser.TestUnit, aa, content, "test.ts", test_case_parser.TestFileParser.parse, test_case_parser.ParseTestFilesOptions{ .allowImplicitFirstFile = true });

    for (parsedFiles.units.items) |unit| {
        var cleanContent = std.ArrayListUnmanaged(u8).empty;
        var i: usize = 0;
        
        const rawContent = unit.content;
        
        // Stack for ranges
        var openRanges = std.ArrayListUnmanaged(usize).empty;

        while (i < rawContent.len) {
            if (i + 1 < rawContent.len and rawContent[i] == '/' and rawContent[i+1] == '*') {
                const end = std.mem.indexOf(u8, rawContent[i+2..], "*/");
                if (end) |endIdx| {
                    const markerName = std.mem.trim(u8, rawContent[i+2 .. i+2+endIdx], " \t\r\n");
                    // Check if it's a valid Fourslash marker (alphanumeric/underscore or empty)
                    var isValid = true;
                    for (markerName) |c| {
                        if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '$') {
                            isValid = false;
                            break;
                        }
                    }
                    if (isValid) {
                        var marker = try aa.create(Marker);
                        marker.name = markerName;
                        marker.position = cleanContent.items.len;
                        // Don't overwrite an existing marker with the same name:
                        // fourslash tests reuse marker names across edits, and
                        // Go's parser keeps the FIRST occurrence's position.
                        // Overwriting here would break tests that insert text
                        // and then verify at the original marker position.
                        if (result.markerPositions.get(markerName) == null) {
                            try result.markerPositions.put(markerName, marker);
                        }
                        i += 2 + endIdx + 2;
                        continue;
                    }
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

    // Build combined content for multi-file tests.
    // Only include .ts and .tsx files (skip .js, .d.ts, .json).
    // Also skip files with `export =` (CommonJS) to avoid parser issues.
    if (result.files.count() > 1) {
        var combined = std.ArrayListUnmanaged(u8).empty;
        var offset: usize = 0;
        for (parsedFiles.units.items) |unit| {
            const fileContent = result.files.get(unit.name) orelse continue;
            // Skip non-TypeScript files.
            if (std.mem.endsWith(u8, unit.name, ".json") or
                std.mem.endsWith(u8, unit.name, ".js") or
                std.mem.endsWith(u8, unit.name, ".d.ts"))
            {
                continue;
            }
            // Skip files with `export =` (causes parser issues when concatenated).
            if (std.mem.indexOf(u8, fileContent, "export =") != null) {
                continue;
            }
            // Adjust marker positions for this file.
            var i: usize = 0;
            const raw = unit.content;
            while (i < raw.len) {
                if (i + 1 < raw.len and raw[i] == '/' and raw[i+1] == '*') {
                    const end_idx = std.mem.indexOf(u8, raw[i+2..], "*/");
                    if (end_idx) |ei| {
                        const markerName = std.mem.trim(u8, raw[i+2 .. i+2+ei], " \t\r\n");
                        var isValid = true;
                        for (markerName) |ch| {
                            if (!std.ascii.isAlphanumeric(ch) and ch != '_') {
                                isValid = false;
                                break;
                            }
                        }
                        if (isValid) {
                            if (result.markerPositions.get(markerName)) |m| {
                                m.position = m.position + offset;
                            }
                        }
                        i += 2 + ei + 2;
                        continue;
                    }
                }
                i += 1;
            }
            combined.appendSlice(aa, fileContent) catch {};
            combined.appendSlice(aa, "\n") catch {};
            offset = combined.items.len;
        }
        result.combinedContent = combined.toOwnedSlice(aa) catch "";
    }

    return result;
}
