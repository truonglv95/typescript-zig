const std = @import("std");
const ast = @import("../ast/ast.zig");
const json = std.json;
const stringutil = @import("../stringutil/stringutil.zig");

// Placeholders for missing modules that will be implemented later
const lsproto = struct {
    pub const Position = struct {
        line: u32,
        character: u32,
    };
    pub const Range = struct {
        start: Position,
        end: Position,
    };
    pub const Location = struct {
        uri: []const u8,
        range: Range,
    };
};

const lsconv = struct {
    pub fn fileNameToDocumentURI(allocator: std.mem.Allocator, fileName: []const u8) ![]const u8 {
        _ = allocator;
        return fileName; // simplified
    }
};

const testrunner = struct {
    pub const ParseTestFilesOptions = struct {
        allowImplicitFirstFile: bool,
    };

    pub fn parseTestFilesAndSymlinksWithOptions(
        allocator: std.mem.Allocator,
        contents: []const u8,
        fileName: []const u8,
        parseContent: anytype,
        options: ParseTestFilesOptions,
    ) !struct {
        files: []const TestFileWithMarkers,
        symlinks: std.StringHashMap([]const u8),
        globalOptions: std.StringHashMap([]const u8),
    } {
        _ = allocator;
        _ = contents;
        _ = fileName;
        _ = parseContent;
        _ = options;
        return error.NotImplemented;
    }
};

pub const MarkerIndex = u32;

pub const RangeMarker = struct {
    fileName: []const u8,
    range: ast.TextRange,
    lsRange: lsproto.Range,
    markerIndex: ?MarkerIndex,

    pub fn lsPos(self: *const RangeMarker) lsproto.Position {
        return self.lsRange.start;
    }

    pub fn getName(self: *const RangeMarker, markers: []const Marker) ?[]const u8 {
        if (self.markerIndex) |idx| {
            return markers[idx].name;
        }
        return null;
    }

    pub fn lsLocation(self: *const RangeMarker, allocator: std.mem.Allocator) !lsproto.Location {
        return lsproto.Location{
            .uri = try lsconv.fileNameToDocumentURI(allocator, self.fileName),
            .range = self.lsRange,
        };
    }
};

pub const Marker = struct {
    fileName: []const u8,
    position: i32,
    lsPosition: lsproto.Position,
    name: ?[]const u8,
    data: ?json.Value,

    pub fn lsPos(self: *const Marker) lsproto.Position {
        return self.lsPosition;
    }

    pub fn makerWithSymlink(self: *const Marker, fileName: []const u8) Marker {
        return Marker{
            .fileName = fileName,
            .position = self.position,
            .lsPosition = self.lsPosition,
            .name = self.name,
            .data = self.data,
        };
    }
};

pub const TestData = struct {
    allocator: std.mem.Allocator,
    files: std.ArrayList(*TestFileInfo),
    markerPositions: std.StringHashMap(MarkerIndex),
    markers: std.ArrayList(Marker),
    symlinks: std.StringHashMap([]const u8),
    globalOptions: std.StringHashMap([]const u8),
    ranges: std.ArrayList(RangeMarker),

    pub fn deinit(self: *TestData) void {
        self.files.deinit();
        self.markerPositions.deinit();
        self.markers.deinit();
        self.symlinks.deinit();
        self.globalOptions.deinit();
        self.ranges.deinit();
    }

    pub fn isStateBaseliningEnabled(self: *const TestData) bool {
        if (self.globalOptions.get("statebaseline")) |val| {
            return std.mem.eql(u8, val, "true");
        }
        return false;
    }
};

pub const TestFileWithMarkers = struct {
    file: *TestFileInfo,
    markers: []Marker,
    ranges: []RangeMarker,
};

fn isStateBaseliningEnabledStr(globalOptions: std.StringHashMap([]const u8)) bool {
    if (globalOptions.get("statebaseline")) |val| {
        return std.mem.eql(u8, val, "true");
    }
    return false;
}

pub fn parseTestData(allocator: std.mem.Allocator, contents: []const u8, fileName: []const u8) !TestData {
    var files = std.ArrayList(*TestFileInfo).init(allocator);
    var markerPositions = std.StringHashMap(MarkerIndex).init(allocator);
    var markers = std.ArrayList(Marker).init(allocator);
    var ranges = std.ArrayList(RangeMarker).init(allocator);

    const parsed = try testrunner.parseTestFilesAndSymlinksWithOptions(
        allocator,
        contents,
        fileName,
        parseFileContent,
        .{ .allowImplicitFirstFile = true },
    );

    var hasTSConfig = false;
    for (parsed.files) |file_data| {
        try files.append(file_data.file);
        hasTSConfig = hasTSConfig or isConfigFile(file_data.file.fileName);

        const markerOffset = @as(u32, @intCast(markers.items.len));
        try markers.appendSlice(file_data.markers);

        var translatedRanges = std.ArrayList(RangeMarker).init(allocator);
        defer translatedRanges.deinit();
        for (file_data.ranges) |r| {
            var newRange = r;
            if (newRange.markerIndex) |idx| {
                newRange.markerIndex = idx + markerOffset;
            }
            try translatedRanges.append(newRange);
        }
        try ranges.appendSlice(translatedRanges.items);

        for (file_data.markers, 0..) |marker, i| {
            const currentMarkerIndex = markerOffset + @as(u32, @intCast(i));
            if (marker.name == null) {
                if (marker.data != null) {
                    continue;
                }
                return error.UnnamedMarker;
            }
            const name = marker.name.?;
            if (markerPositions.contains(name)) {
                return error.DuplicateMarkerName;
            }
            try markerPositions.put(name, currentMarkerIndex);
        }
    }

    if (hasTSConfig and hasUnsupportedGlobalOptionsWithConfig(parsed.globalOptions) and !isStateBaseliningEnabledStr(parsed.globalOptions)) {
        return error.UnsupportedGlobalOptionsWithConfig;
    }

    return TestData{
        .allocator = allocator,
        .files = files,
        .markerPositions = markerPositions,
        .markers = markers,
        .symlinks = parsed.symlinks,
        .globalOptions = parsed.globalOptions,
        .ranges = ranges,
    };
}

fn hasUnsupportedGlobalOptionsWithConfig(globalOptions: std.StringHashMap([]const u8)) bool {
    var it = globalOptions.keyIterator();
    while (it.next()) |option| {
        if (std.ascii.eqlIgnoreCase(option.*, "symlink") or
            std.ascii.eqlIgnoreCase(option.*, "link") or
            std.ascii.eqlIgnoreCase(option.*, "usecasesensitivefilenames"))
        {
            continue;
        }
        return true;
    }
    return false;
}

fn isConfigFile(fileName: []const u8) bool {
    return std.ascii.endsWithIgnoreCase(fileName, "tsconfig.json") or
        std.ascii.endsWithIgnoreCase(fileName, "jsconfig.json");
}

const LocationInformation = struct {
    position: i32,
    sourcePosition: usize,
    sourceLine: i32,
    sourceColumn: i32,
};

const RangeLocationInformation = struct {
    loc: LocationInformation,
    markerIndex: ?MarkerIndex,
};

pub const TestFileInfo = struct {
    fileName: []const u8,
    content: []const u8,
    emit: bool,

    pub fn text(self: *const TestFileInfo) []const u8 {
        return self.content;
    }
};

const emitThisFileOption = "emitthisfile";

const ParserState = enum {
    none,
    inSlashStarMarker,
    inObjectMarker,
};

pub fn parseFileContent(allocator: std.mem.Allocator, fileName: []const u8, contentRaw: []const u8, fileOptions: std.StringHashMap([]const u8)) !TestFileWithMarkers {
    const normFileName = fileName;
    const content = try chompLeadingSpace(allocator, contentRaw);

    var output = std.ArrayList(u8).init(allocator);
    var markers = std.ArrayList(Marker).init(allocator);
    var openRanges = std.ArrayList(RangeLocationInformation).init(allocator);
    var rangeMarkers = std.ArrayList(RangeMarker).init(allocator);

    var difference: usize = 0;
    var line: i32 = 1;
    var column: i32 = 1;
    var openMarker: ?LocationInformation = null;
    var lastNormalCharPosition: usize = 0;

    var state = ParserState.none;
    var previousCharacter: u21 = std.unicode.utf8ReplacementCharacter;

    var i: usize = 0;
    while (i < content.len) {
        const charLen = std.unicode.utf8ByteSequenceLength(content[i]) catch 1;
        const currentCharacter = std.unicode.utf8Decode(content[i .. i + charLen]) catch std.unicode.utf8ReplacementCharacter;

        switch (state) {
            .none => {
                if (previousCharacter == '[' and currentCharacter == '|') {
                    try openRanges.append(.{
                        .loc = .{
                            .position = @as(i32, @intCast(i - 1)) - @as(i32, @intCast(difference)),
                            .sourcePosition = i - 1,
                            .sourceLine = line,
                            .sourceColumn = column,
                        },
                        .markerIndex = null,
                    });
                    if (i - 1 > lastNormalCharPosition) {
                        try output.appendSlice(content[lastNormalCharPosition .. i - 1]);
                    }
                    lastNormalCharPosition = i + charLen;
                    difference += 2;
                } else if (previousCharacter == '|' and currentCharacter == ']') {
                    if (openRanges.items.len == 0) return error.FoundRangeEndWithNoMatchingStart;
                    const rangeStart = openRanges.pop();
                    try rangeMarkers.append(.{
                        .fileName = normFileName,
                        .range = .{
                            .pos = @as(u32, @intCast(rangeStart.loc.position)),
                            .end = @as(u32, @intCast(@as(i32, @intCast(i - 1)) - @as(i32, @intCast(difference)))),
                        },
                        .lsRange = undefined,
                        .markerIndex = rangeStart.markerIndex,
                    });
                    if (i - 1 > lastNormalCharPosition) {
                        try output.appendSlice(content[lastNormalCharPosition .. i - 1]);
                    }
                    lastNormalCharPosition = i + charLen;
                    difference += 2;
                } else if (previousCharacter == '/' and currentCharacter == '*') {
                    state = .inSlashStarMarker;
                    openMarker = .{
                        .position = @as(i32, @intCast(i - 1)) - @as(i32, @intCast(difference)),
                        .sourcePosition = i - 1,
                        .sourceLine = line,
                        .sourceColumn = column - 1,
                    };
                } else if (previousCharacter == '{' and currentCharacter == '|') {
                    state = .inObjectMarker;
                    openMarker = .{
                        .position = @as(i32, @intCast(i - 1)) - @as(i32, @intCast(difference)),
                        .sourcePosition = i - 1,
                        .sourceLine = line,
                        .sourceColumn = column,
                    };
                    if (i - 1 > lastNormalCharPosition) {
                        try output.appendSlice(content[lastNormalCharPosition .. i - 1]);
                    }
                }
            },
            .inObjectMarker => {
                if (previousCharacter == '|' and currentCharacter == '}') {
                    const objectMarkerData = std.mem.trim(u8, content[openMarker.?.sourcePosition + 2 .. i - 1], " \t\r\n");
                    const marker = try getObjectMarker(allocator, normFileName, openMarker.?, objectMarkerData);
                    try markers.append(marker);

                    if (openRanges.items.len > 0) {
                        openRanges.items[openRanges.items.len - 1].markerIndex = @as(u32, @intCast(markers.items.len - 1));
                    }

                    lastNormalCharPosition = i + charLen;
                    difference += (i + charLen) - openMarker.?.sourcePosition;
                    openMarker = null;
                    state = .none;
                }
            },
            .inSlashStarMarker => {
                if (previousCharacter == '*' and currentCharacter == '/') {
                    const markerNameText = std.mem.trim(u8, content[openMarker.?.sourcePosition + 2 .. i - 1], " \t\r\n");
                    const marker = Marker{
                        .fileName = normFileName,
                        .position = openMarker.?.position,
                        .lsPosition = undefined,
                        .name = try allocator.dupe(u8, markerNameText),
                        .data = null,
                    };
                    try markers.append(marker);

                    if (openRanges.items.len > 0) {
                        openRanges.items[openRanges.items.len - 1].markerIndex = @as(u32, @intCast(markers.items.len - 1));
                    }

                    if (openMarker.?.sourcePosition > lastNormalCharPosition) {
                        try output.appendSlice(content[lastNormalCharPosition .. openMarker.?.sourcePosition]);
                    }
                    lastNormalCharPosition = i + charLen;
                    difference += (i + charLen) - openMarker.?.sourcePosition;
                    openMarker = null;
                    state = .none;
                } else if (!std.ascii.isAlphanumeric(@as(u8, @intCast(currentCharacter))) and
                    currentCharacter != '$' and currentCharacter != '_')
                {
                    if (currentCharacter == '*' and i < content.len - 1 and content[i + 1] == '/') {
                        // The marker is about to be closed, ignore the 'invalid' char
                    } else {
                        if (i > lastNormalCharPosition) {
                            try output.appendSlice(content[lastNormalCharPosition .. i]);
                        }
                        lastNormalCharPosition = i;
                        openMarker = null;
                        state = .none;
                    }
                }
            },
        }

        if (currentCharacter == '\n' and previousCharacter == '\r') {
            i += charLen;
            continue;
        } else if (currentCharacter == '\n' or currentCharacter == '\r') {
            line += 1;
            column = 1;
            i += charLen;
            continue;
        }
        column += 1;
        if (i >= lastNormalCharPosition) {
            previousCharacter = currentCharacter;
        } else {
            previousCharacter = std.unicode.utf8ReplacementCharacter;
        }
        i += charLen;
    }

    if (lastNormalCharPosition < content.len) {
        try output.appendSlice(content[lastNormalCharPosition..]);
    }

    if (openRanges.items.len > 0) return error.UnterminatedRange;
    if (openMarker != null) return error.UnterminatedMarker;

    const outputString = try output.toOwnedSlice();

    for (markers.items) |*m| {
        m.lsPosition = lsproto.Position{ .line = 0, .character = 0 };
    }
    
    std.mem.sort(RangeMarker, rangeMarkers.items, {}, compareRangeMarkers);

    for (rangeMarkers.items) |*r| {
        r.lsRange = lsproto.Range{
            .start = lsproto.Position{ .line = 0, .character = 0 },
            .end = lsproto.Position{ .line = 0, .character = 0 },
        };
    }

    const emit = if (fileOptions.get(emitThisFileOption)) |val| std.mem.eql(u8, val, "true") else false;
    const testFileInfo = try allocator.create(TestFileInfo);
    testFileInfo.* = .{
        .fileName = try allocator.dupe(u8, normFileName),
        .content = outputString,
        .emit = emit,
    };

    return TestFileWithMarkers{
        .file = testFileInfo,
        .markers = try markers.toOwnedSlice(),
        .ranges = try rangeMarkers.toOwnedSlice(),
    };
}

fn compareRangeMarkers(context: void, a: RangeMarker, b: RangeMarker) bool {
    _ = context;
    if (a.range.pos != b.range.pos) {
        return a.range.pos < b.range.pos;
    }
    return b.range.end < a.range.end;
}

fn getObjectMarker(allocator: std.mem.Allocator, fileName: []const u8, location: LocationInformation, text: []const u8) !Marker {
    const jsonStr = try std.fmt.allocPrint(allocator, "{{ {s} }}", .{text});
    defer allocator.free(jsonStr);

    var parsedValue = try std.json.parseFromSliceLeaky(json.Value, allocator, jsonStr, .{});

    if (parsedValue != .object or parsedValue.object.count() == 0) {
        return error.EmptyObjectMarker;
    }

    var marker = Marker{
        .fileName = fileName,
        .position = location.position,
        .lsPosition = undefined,
        .name = null,
        .data = parsedValue,
    };

    if (parsedValue.object.get("name")) |nameVal| {
        if (nameVal == .string and nameVal.string.len > 0) {
            marker.name = nameVal.string;
        }
    }

    return marker;
}

fn chompLeadingSpace(allocator: std.mem.Allocator, content: []const u8) ![]const u8 {
    var it = std.mem.splitScalar(u8, content, '\n');
    var isIndented = true;
    while (it.next()) |line| {
        if (line.len > 0 and line[0] != ' ') {
            isIndented = false;
            break;
        }
    }
    if (!isIndented) return content;

    var result = std.ArrayList(u8).init(allocator);
    it = std.mem.splitScalar(u8, content, '\n');
    var first = true;
    while (it.next()) |line| {
        if (!first) {
            try result.append('\n');
        }
        first = false;
        if (line.len > 0) {
            try result.appendSlice(line[1..]);
        }
    }
    return try result.toOwnedSlice();
}
