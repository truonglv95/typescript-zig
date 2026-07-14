const std = @import("std");
const core = @import("../core/core.zig");
const debug = @import("../debug/debug.zig");
const scanner = @import("../scanner/scanner.zig");
const stringutil = @import("../stringutil/stringutil.zig");
const tspath = @import("../tspath/tspath.zig");
const util = @import("util.zig");
const lineinfo = @import("lineinfo.zig");
const decoder = @import("decoder.zig");

pub const Host = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        useCaseSensitiveFileNames: *const fn (ptr: *anyopaque) bool,
        getECMALineInfo: *const fn (ptr: *anyopaque, fileName: []const u8) ?*lineinfo.ECMALineInfo,
        readFile: *const fn (ptr: *anyopaque, fileName: []const u8) ?[]const u8,
    };

    pub inline fn useCaseSensitiveFileNames(self: Host) bool {
        return self.vtable.useCaseSensitiveFileNames(self.ptr);
    }

    pub inline fn getECMALineInfo(self: Host, fileName: []const u8) ?*lineinfo.ECMALineInfo {
        return self.vtable.getECMALineInfo(self.ptr, fileName);
    }

    pub inline fn readFile(self: Host, fileName: []const u8) ?[]const u8 {
        return self.vtable.readFile(self.ptr, fileName);
    }
};

pub const MappedPosition = struct {
    generatedPosition: isize,
    sourcePosition: isize,
    sourceIndex: decoder.SourceIndex,
    nameIndex: decoder.NameIndex,

    pub fn isSourceMappedPosition(self: *const MappedPosition) bool {
        return self.sourceIndex != decoder.MissingSource and self.sourcePosition != missingPosition;
    }
};

pub const missingPosition: isize = -1;

pub const SourceMappedPosition = MappedPosition;

pub const RawSourceMap = struct {
    version: i32 = 0,
    file: []const u8 = "",
    sourceRoot: []const u8 = "",
    sources: [][]const u8 = &[_][]const u8{},
    sourcesContent: []?[]const u8 = &[_]?[]const u8{},
    names: [][]const u8 = &[_][]const u8{},
    mappings: []const u8 = "",
};

pub const DocumentPositionMapper = struct {
    useCaseSensitiveFileNames: bool,
    sourceFileAbsolutePaths: [][]const u8,
    sourceToSourceIndexMap: std.StringHashMap(decoder.SourceIndex),
    generatedAbsoluteFilePath: []const u8,

    generatedMappings: []*MappedPosition,
    sourceMappings: std.AutoHashMap(decoder.SourceIndex, []*SourceMappedPosition),

    allocator: std.mem.Allocator,

    pub fn deinit(self: *DocumentPositionMapper) void {
        self.sourceToSourceIndexMap.deinit();
        var it = self.sourceMappings.valueIterator();
        while (it.next()) |list| {
            self.allocator.free(list.*);
        }
        self.sourceMappings.deinit();
        self.allocator.free(self.sourceFileAbsolutePaths);
        self.allocator.free(self.generatedMappings);
        self.allocator.destroy(self);
    }

    pub fn getSourcePosition(d: ?*DocumentPositionMapper, loc: *const DocumentPosition) ?DocumentPosition {
        const self = d orelse return null;
        if (self.generatedMappings.len == 0) {
            return null;
        }

        const targetIndex = binarySearchMappedPosition(self.generatedMappings, loc.pos);
        if (targetIndex < 0 or targetIndex >= self.generatedMappings.len) {
            return null;
        }

        const mapping = self.generatedMappings[@as(usize, @intCast(targetIndex))];
        if (!mapping.isSourceMappedPosition()) {
            return null;
        }

        return DocumentPosition{
            .fileName = self.sourceFileAbsolutePaths[@as(usize, @intCast(mapping.sourceIndex))],
            .pos = mapping.sourcePosition,
        };
    }

    pub fn getGeneratedPosition(d: ?*DocumentPositionMapper, loc: *const DocumentPosition) ?DocumentPosition {
        const self = d orelse return null;
        // Assume GetCanonicalFileName allocates or returns slice; based on tspath it allocates
        const canonical = tspath.getCanonicalFileName(self.allocator, loc.fileName, self.useCaseSensitiveFileNames) catch return null;
        defer self.allocator.free(canonical);
        const sourceIndex = self.sourceToSourceIndexMap.get(canonical) orelse return null;

        if (sourceIndex < 0 or sourceIndex >= self.sourceMappings.count()) {
            return null;
        }

        const sourceMappings = self.sourceMappings.get(sourceIndex) orelse return null;
        const targetIndex = binarySearchSourceMappedPosition(sourceMappings, loc.pos);

        if (targetIndex < 0 or targetIndex >= sourceMappings.len) {
            return null;
        }

        const mapping = sourceMappings[@as(usize, @intCast(targetIndex))];
        if (mapping.sourceIndex != sourceIndex) {
            return null;
        }

        return DocumentPosition{
            .fileName = self.generatedAbsoluteFilePath,
            .pos = mapping.generatedPosition,
        };
    }
};

fn binarySearchMappedPosition(mappings: []*MappedPosition, pos: isize) isize {
    var low: isize = 0;
    var high: isize = @as(isize, @intCast(mappings.len)) - 1;
    var result: isize = -1;
    while (low <= high) {
        const mid = low + @divTrunc((high - low), 2);
        const diff = mappings[@as(usize, @intCast(mid))].generatedPosition - pos;
        if (diff < 0) {
            low = mid + 1;
            result = low;
        } else if (diff > 0) {
            high = mid - 1;
            result = low;
        } else {
            return mid;
        }
    }
    return result;
}

fn binarySearchSourceMappedPosition(mappings: []*SourceMappedPosition, pos: isize) isize {
    var low: isize = 0;
    var high: isize = @as(isize, @intCast(mappings.len)) - 1;
    var result: isize = -1;
    while (low <= high) {
        const mid = low + @divTrunc((high - low), 2);
        const diff = mappings[@as(usize, @intCast(mid))].sourcePosition - pos;
        if (diff < 0) {
            low = mid + 1;
            result = low;
        } else if (diff > 0) {
            high = mid - 1;
            result = low;
        } else {
            return mid;
        }
    }
    return result;
}

pub const DocumentPosition = struct {
    fileName: []const u8,
    pos: isize,
};

pub fn createDocumentPositionMapper(allocator: std.mem.Allocator, host: Host, sourceMap: *const RawSourceMap, mapPath: []const u8) !*DocumentPositionMapper {
    const mapDirectory = tspath.getDirectoryPath(mapPath);
    var sourceRoot: []const u8 = undefined;
    if (sourceMap.sourceRoot.len != 0) {
        sourceRoot = try tspath.getNormalizedAbsolutePath(allocator, sourceMap.sourceRoot, mapDirectory);
    } else {
        sourceRoot = mapDirectory;
    }
    const generatedAbsoluteFilePath = try tspath.getNormalizedAbsolutePath(allocator, sourceMap.file, mapDirectory);
    var sourceFileAbsolutePaths = try allocator.alloc([]const u8, sourceMap.sources.len);
    for (sourceMap.sources, 0..) |source, i| {
        sourceFileAbsolutePaths[i] = try tspath.getNormalizedAbsolutePath(allocator, source, sourceRoot);
    }

    const useCaseSensitiveFileNames = host.useCaseSensitiveFileNames();
    var sourceToSourceIndexMap = std.StringHashMap(decoder.SourceIndex).init(allocator);
    for (sourceFileAbsolutePaths, 0..) |source, i| {
        const canon = try tspath.getCanonicalFileName(allocator, source, useCaseSensitiveFileNames);
        try sourceToSourceIndexMap.put(canon, @as(decoder.SourceIndex, @intCast(i)));
    }

    var decodedMappings = std.ArrayList(*MappedPosition).init(allocator);
    var generatedMappings = std.ArrayList(*MappedPosition).init(allocator);
    var sourceMappings = std.AutoHashMap(decoder.SourceIndex, std.ArrayList(*SourceMappedPosition)).init(allocator);

    var dec = decoder.MappingsDecoder.init(allocator, sourceMap.mappings);
    defer dec.deinit();

    var decValues = dec.values();
    while (try decValues.next()) |mapping| {
        var generatedPosition: isize = -1;
        const genLineInfo = host.getECMALineInfo(generatedAbsoluteFilePath);
        if (genLineInfo) |li| {
            generatedPosition = @as(isize, @intCast(scanner.computePositionOfLineAndUTF16Character(
                li.lineStarts,
                @as(usize, @intCast(mapping.generatedLine)),
                @as(usize, @intCast(mapping.generatedCharacter)),
                li.text,
                true,
            )));
        }

        var sourcePosition: isize = -1;
        if (mapping.isSourceMapping()) {
            const srcLineInfo = host.getECMALineInfo(sourceFileAbsolutePaths[@as(usize, @intCast(mapping.sourceIndex))]);
            if (srcLineInfo) |li| {
                sourcePosition = @as(isize, @intCast(scanner.computePositionOfLineAndUTF16Character(
                    li.lineStarts,
                    @as(usize, @intCast(mapping.sourceLine)),
                    @as(usize, @intCast(mapping.sourceCharacter)),
                    li.text,
                    true,
                )));
            }
        }

        const mp = try allocator.create(MappedPosition);
        mp.* = .{
            .generatedPosition = generatedPosition,
            .sourceIndex = mapping.sourceIndex,
            .sourcePosition = sourcePosition,
            .nameIndex = mapping.nameIndex,
        };
        try decodedMappings.append(mp);
    }

    if (dec.getError() != null) {
        decodedMappings.clearRetainingCapacity();
    }

    for (decodedMappings.items) |mapping| {
        if (!mapping.isSourceMappedPosition()) {
            continue;
        }
        const sourceIndex = mapping.sourceIndex;
        var list = sourceMappings.get(sourceIndex) orelse std.ArrayList(*SourceMappedPosition).init(allocator);
        
        const smp = try allocator.create(SourceMappedPosition);
        smp.* = .{
            .generatedPosition = mapping.generatedPosition,
            .sourceIndex = sourceIndex,
            .sourcePosition = mapping.sourcePosition,
            .nameIndex = mapping.nameIndex,
        };
        try list.append(smp);
        try sourceMappings.put(sourceIndex, list);
    }

    var sourceMappingsIter = sourceMappings.iterator();
    while (sourceMappingsIter.next()) |entry| {
        const list = entry.value_ptr.*;
        std.mem.sort(*SourceMappedPosition, list.items, {}, struct {
            fn lessThan(_: void, a: *SourceMappedPosition, b: *SourceMappedPosition) bool {
                return a.sourcePosition < b.sourcePosition;
            }
        }.lessThan);
        
        var deduplicated = std.ArrayList(*SourceMappedPosition).init(allocator);
        for (list.items) |item| {
            if (deduplicated.items.len == 0) {
                try deduplicated.append(item);
            } else {
                const last = deduplicated.items[deduplicated.items.len - 1];
                if (!(last.generatedPosition == item.generatedPosition and
                    last.sourceIndex == item.sourceIndex and
                    last.sourcePosition == item.sourcePosition)) {
                    try deduplicated.append(item);
                }
            }
        }
        try sourceMappings.put(entry.key_ptr.*, deduplicated);
        list.deinit();
    }

    try generatedMappings.appendSlice(decodedMappings.items);
    var deduplicatedGen = std.ArrayList(*MappedPosition).init(allocator);
    std.mem.sort(*MappedPosition, generatedMappings.items, {}, struct {
        fn lessThan(_: void, a: *MappedPosition, b: *MappedPosition) bool {
            return a.generatedPosition < b.generatedPosition;
        }
    }.lessThan);

    for (generatedMappings.items) |item| {
        if (deduplicatedGen.items.len == 0) {
            try deduplicatedGen.append(item);
        } else {
            const last = deduplicatedGen.items[deduplicatedGen.items.len - 1];
            if (!(last.generatedPosition == item.generatedPosition and
                last.sourceIndex == item.sourceIndex and
                last.sourcePosition == item.sourcePosition)) {
                try deduplicatedGen.append(item);
            }
        }
    }
    
    var finalSourceMappings = std.AutoHashMap(decoder.SourceIndex, []*SourceMappedPosition).init(allocator);
    var it = sourceMappings.iterator();
    while (it.next()) |entry| {
        try finalSourceMappings.put(entry.key_ptr.*, try entry.value_ptr.toOwnedSlice());
    }
    sourceMappings.deinit();

    const dpm = try allocator.create(DocumentPositionMapper);
    dpm.* = .{
        .allocator = allocator,
        .useCaseSensitiveFileNames = useCaseSensitiveFileNames,
        .sourceFileAbsolutePaths = sourceFileAbsolutePaths,
        .sourceToSourceIndexMap = sourceToSourceIndexMap,
        .generatedAbsoluteFilePath = generatedAbsoluteFilePath,
        .generatedMappings = try deduplicatedGen.toOwnedSlice(),
        .sourceMappings = finalSourceMappings,
    };
    return dpm;
}

pub fn getDocumentPositionMapper(allocator: std.mem.Allocator, host: Host, generatedFileName: []const u8) ?*DocumentPositionMapper {
    var mapFileName = tryGetSourceMappingURL(host, generatedFileName);
    if (mapFileName.len != 0) {
        const result = tryParseBase64Url(mapFileName);
        if (result.isBase64Url) {
            if (result.parseableUrl.len != 0) {
                const decodedBuffer = allocator.alloc(u8, std.base64.standard.Decoder.calcSizeForSlice(result.parseableUrl) catch 0) catch return null;
                defer allocator.free(decodedBuffer);
                std.base64.standard.Decoder.decode(decodedBuffer, result.parseableUrl) catch {
                    return null;
                };
                return convertDocumentToSourceMapper(allocator, host, decodedBuffer, generatedFileName);
            }
            mapFileName = "";
        }
    }

    var possibleMapLocations = std.ArrayList([]const u8).init(allocator);
    defer possibleMapLocations.deinit();
    
    if (mapFileName.len != 0) {
        possibleMapLocations.append(mapFileName) catch {};
    }
    const withMap = std.fmt.allocPrint(allocator, "{s}.map", .{generatedFileName}) catch return null;
    defer allocator.free(withMap);
    possibleMapLocations.append(withMap) catch {};

    for (possibleMapLocations.items) |location| {
        const resolvedMapFileName = tspath.getNormalizedAbsolutePath(allocator, location, tspath.getDirectoryPath(generatedFileName)) catch continue;
        defer allocator.free(resolvedMapFileName);
        
        if (host.readFile(resolvedMapFileName)) |mapFileContents| {
            return convertDocumentToSourceMapper(allocator, host, mapFileContents, resolvedMapFileName);
        }
    }
    return null;
}

fn convertDocumentToSourceMapper(allocator: std.mem.Allocator, host: Host, contents: []const u8, mapFileName: []const u8) ?*DocumentPositionMapper {
    var parsed = std.json.parseFromSlice(RawSourceMap, allocator, contents, .{ .ignore_unknown_fields = true }) catch return null;
    defer parsed.deinit();
    const sourceMap = &parsed.value;

    if (sourceMap.version != 3) {
        return null;
    }
    if (sourceMap.sources.len == 0 or sourceMap.file.len == 0 or sourceMap.mappings.len == 0) {
        return null;
    }

    for (sourceMap.sourcesContent) |content| {
        if (content != null) {
            return null;
        }
    }

    return createDocumentPositionMapper(allocator, host, sourceMap, mapFileName) catch null;
}

fn tryGetSourceMappingURL(host: Host, fileName: []const u8) []const u8 {
    const lineInfo = host.getECMALineInfo(fileName);
    return util.tryGetSourceMappingURL(lineInfo);
}

const ParseBase64UrlResult = struct {
    parseableUrl: []const u8,
    isBase64Url: bool,
};

fn tryParseBase64Url(url: []const u8) ParseBase64UrlResult {
    var remaining = url;
    if (!std.mem.startsWith(u8, remaining, "data:")) {
        return .{ .parseableUrl = "", .isBase64Url = false };
    }
    remaining = remaining["data:".len..];
    
    if (!std.mem.startsWith(u8, remaining, "application/json;")) {
        return .{ .parseableUrl = "", .isBase64Url = true };
    }
    remaining = remaining["application/json;".len..];
    
    if (std.mem.startsWith(u8, remaining, "charset=")) {
        remaining = remaining["charset=".len..];
        if (remaining.len < "utf-8;".len or !std.ascii.eqlIgnoreCase(remaining[0.."utf-8;".len], "utf-8;")) {
            return .{ .parseableUrl = "", .isBase64Url = true };
        }
        remaining = remaining["utf-8;".len..];
    }
    
    if (!std.mem.startsWith(u8, remaining, "base64,")) {
        return .{ .parseableUrl = "", .isBase64Url = true };
    }
    remaining = remaining["base64,".len..];
    
    for (remaining) |r| {
        if (!(stringutil.isASCIILetter(r) or stringutil.isDigit(r) or r == '+' or r == '/' or r == '=')) {
            return .{ .parseableUrl = "", .isBase64Url = true };
        }
    }
    return .{ .parseableUrl = remaining, .isBase64Url = true };
}
