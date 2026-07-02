const std = @import("std");
const core = @import("../core/core.zig");
const tspath = @import("../tspath/tspath.zig");

pub const SourceIndex = u32;
pub const NameIndex = u32;

pub const sourceIndexNotSet: SourceIndex = std.math.maxInt(SourceIndex);
pub const nameIndexNotSet: NameIndex = std.math.maxInt(NameIndex);
pub const notSet: i32 = -1;
pub const notSetUTF16: core.UTF16Offset = -1;

pub const RawSourceMap = struct {
    version: i32,
    file: []const u8,
    sourceRoot: []const u8,
    sources: [][]const u8,
    names: [][]const u8,
    mappings: []const u8,
    sourcesContent: ?[]?[]const u8,
};

pub const Generator = struct {
    allocator: std.mem.Allocator,
    pathOptions: tspath.ComparePathsOptions,
    file: []const u8,
    sourceRoot: []const u8,
    sourcesDirectoryPath: []const u8,
    rawSources: std.ArrayList([]const u8),
    sources: std.ArrayList([]const u8),
    sourceToSourceIndexMap: std.StringHashMap(SourceIndex),
    sourcesContent: std.ArrayList(?[]const u8),
    names: std.ArrayList([]const u8),
    nameToNameIndexMap: std.StringHashMap(NameIndex),
    mappings: std.ArrayList(u8),
    lastGeneratedLine: i32 = 0,
    lastGeneratedCharacter: core.UTF16Offset = 0,
    lastSourceIndex: SourceIndex = 0,
    lastSourceLine: i32 = 0,
    lastSourceCharacter: core.UTF16Offset = 0,
    lastNameIndex: NameIndex = 0,
    hasLast: bool = false,
    pendingGeneratedLine: i32 = 0,
    pendingGeneratedCharacter: core.UTF16Offset = 0,
    pendingSourceIndex: SourceIndex = 0,
    pendingSourceLine: i32 = 0,
    pendingSourceCharacter: core.UTF16Offset = 0,
    pendingNameIndex: NameIndex = 0,
    hasPending: bool = false,
    hasPendingSource: bool = false,
    hasPendingName: bool = false,

    pub fn init(allocator: std.mem.Allocator, file: []const u8, sourceRoot: []const u8, sourcesDirectoryPath: []const u8, options: tspath.ComparePathsOptions) *Generator {
        const gen = allocator.create(Generator) catch unreachable;
        gen.* = Generator{
            .allocator = allocator,
            .file = allocator.dupe(u8, file) catch unreachable,
            .sourceRoot = allocator.dupe(u8, sourceRoot) catch unreachable,
            .sourcesDirectoryPath = allocator.dupe(u8, sourcesDirectoryPath) catch unreachable,
            .pathOptions = options,
            .rawSources = .empty,
            .sources = .empty,
            .sourceToSourceIndexMap = std.StringHashMap(SourceIndex).init(allocator),
            .sourcesContent = .empty,
            .names = .empty,
            .nameToNameIndexMap = std.StringHashMap(NameIndex).init(allocator),
            .mappings = .empty,
        };
        return gen;
    }

    pub fn deinit(self: *Generator) void {
        self.allocator.free(self.file);
        self.allocator.free(self.sourceRoot);
        self.allocator.free(self.sourcesDirectoryPath);
        self.rawSources.deinit(self.allocator);
        for (self.sources.items) |source| self.allocator.free(source);
        self.sources.deinit(self.allocator);
        self.sourceToSourceIndexMap.deinit();
        self.sourcesContent.deinit(self.allocator);
        self.names.deinit(self.allocator);
        self.nameToNameIndexMap.deinit();
        self.mappings.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn getSources(self: *Generator) [][]const u8 {
        return self.rawSources.items;
    }

    pub fn addSource(self: *Generator, fileName: []const u8) SourceIndex {
        var source = tspath.getRelativePathToDirectoryOrUrl(
            self.allocator,
            self.sourcesDirectoryPath,
            fileName,
            true, // isAbsolutePathAnUrl
            self.pathOptions,
        ) catch unreachable;
        if (source.len == 0 and std.fs.path.isAbsolute(self.sourcesDirectoryPath) and std.fs.path.isAbsolute(fileName)) {
            self.allocator.free(source);
            const effective_file_name = if (std.mem.startsWith(u8, fileName, "/private/var/") and std.mem.startsWith(u8, self.sourcesDirectoryPath, "/var/")) fileName[8..] else fileName;
            source = std.fs.path.relativePosix(self.allocator, ".", self.sourcesDirectoryPath, effective_file_name) catch self.allocator.dupe(u8, tspath.getBaseFileName(fileName)) catch unreachable;
        } else if (source.len == 0) {
            self.allocator.free(source);
            source = self.allocator.dupe(u8, tspath.getBaseFileName(fileName)) catch unreachable;
        }

        if (self.sourceToSourceIndexMap.get(source)) |sourceIndex| {
            return sourceIndex;
        } else {
            const sourceIndex: SourceIndex = @intCast(self.sources.items.len);
            self.sources.append(self.allocator, source) catch unreachable;
            self.rawSources.append(self.allocator, fileName) catch unreachable;
            self.sourceToSourceIndexMap.put(source, sourceIndex) catch unreachable;
            return sourceIndex;
        }
    }

    pub fn setSourceContent(self: *Generator, sourceIndex: SourceIndex, content: []const u8) !void {
        if (sourceIndex == sourceIndexNotSet or sourceIndex >= self.sources.items.len) {
            return error.SourceIndexOutOfRange;
        }
        while (self.sourcesContent.items.len <= sourceIndex) {
            self.sourcesContent.append(self.allocator, null) catch unreachable;
        }
        self.sourcesContent.items[sourceIndex] = content;
    }

    pub fn addName(self: *Generator, name: []const u8) NameIndex {
        if (self.nameToNameIndexMap.get(name)) |nameIndex| {
            return nameIndex;
        } else {
            const nameIndex: NameIndex = @intCast(self.names.items.len);
            self.names.append(self.allocator, name) catch unreachable;
            self.nameToNameIndexMap.put(name, nameIndex) catch unreachable;
            return nameIndex;
        }
    }

    fn isNewGeneratedPosition(self: *Generator, generatedLine: i32, generatedCharacter: core.UTF16Offset) bool {
        return !self.hasPending or
            self.pendingGeneratedLine != generatedLine or
            self.pendingGeneratedCharacter != generatedCharacter;
    }

    fn isBacktrackingSourcePosition(self: *Generator, sourceIndex: SourceIndex, sourceLine: i32, sourceCharacter: core.UTF16Offset) bool {
        return sourceIndex != sourceIndexNotSet and
            sourceLine != notSet and
            sourceCharacter != notSetUTF16 and
            self.pendingSourceIndex == sourceIndex and
            (self.pendingSourceLine > sourceLine or
                (self.pendingSourceLine == sourceLine and self.pendingSourceCharacter > sourceCharacter));
    }

    fn shouldCommitMapping(self: *Generator) bool {
        return self.hasPending and (!self.hasLast or
            self.lastGeneratedLine != self.pendingGeneratedLine or
            self.lastGeneratedCharacter != self.pendingGeneratedCharacter or
            self.lastSourceIndex != self.pendingSourceIndex or
            self.lastSourceLine != self.pendingSourceLine or
            self.lastSourceCharacter != self.pendingSourceCharacter or
            self.lastNameIndex != self.pendingNameIndex);
    }

    fn appendMappingCharCode(self: *Generator, charCode: u8) void {
        self.mappings.append(self.allocator, charCode) catch unreachable;
    }

    fn appendBase64VLQ(self: *Generator, inValue_: i32) void {
        var inValue = inValue_;
        if (inValue < 0) {
            inValue = ((-inValue) << 1) + 1;
        } else {
            inValue = inValue << 1;
        }

        while (true) {
            var currentDigit: i32 = inValue & 31;
            inValue = inValue >> 5;
            if (inValue > 0) {
                currentDigit = currentDigit | 32;
            }
            self.appendMappingCharCode(base64FormatEncode(@intCast(currentDigit)));
            if (inValue <= 0) {
                break;
            }
        }
    }

    fn commitPendingMapping(self: *Generator) void {
        if (!self.shouldCommitMapping()) {
            return;
        }

        if (self.lastGeneratedLine < self.pendingGeneratedLine) {
            while (true) {
                self.appendMappingCharCode(';');
                self.lastGeneratedLine += 1;
                if (self.lastGeneratedLine >= self.pendingGeneratedLine) {
                    break;
                }
            }
            self.lastGeneratedCharacter = 0;
        } else {
            if (self.lastGeneratedLine != self.pendingGeneratedLine) {
                @panic("generatedLine cannot backtrack");
            }
            if (self.hasLast) {
                self.appendMappingCharCode(',');
            }
        }

        self.appendBase64VLQ(self.pendingGeneratedCharacter - self.lastGeneratedCharacter);
        self.lastGeneratedCharacter = self.pendingGeneratedCharacter;

        if (self.hasPendingSource) {
            self.appendBase64VLQ(@as(i32, @intCast(self.pendingSourceIndex)) - @as(i32, @intCast(self.lastSourceIndex)));
            self.lastSourceIndex = self.pendingSourceIndex;

            self.appendBase64VLQ(self.pendingSourceLine - self.lastSourceLine);
            self.lastSourceLine = self.pendingSourceLine;

            self.appendBase64VLQ(self.pendingSourceCharacter - self.lastSourceCharacter);
            self.lastSourceCharacter = self.pendingSourceCharacter;

            if (self.hasPendingName) {
                self.appendBase64VLQ(@as(i32, @intCast(self.pendingNameIndex)) - @as(i32, @intCast(self.lastNameIndex)));
                self.lastNameIndex = self.pendingNameIndex;
            }
        }

        self.hasLast = true;
    }

    fn addMapping(self: *Generator, generatedLine: i32, generatedCharacter: core.UTF16Offset, sourceIndex: SourceIndex, sourceLine: i32, sourceCharacter: core.UTF16Offset, nameIndex: NameIndex) void {
        if (self.isNewGeneratedPosition(generatedLine, generatedCharacter) or
            self.isBacktrackingSourcePosition(sourceIndex, sourceLine, sourceCharacter))
        {
            self.commitPendingMapping();
            self.pendingGeneratedLine = generatedLine;
            self.pendingGeneratedCharacter = generatedCharacter;
            self.hasPendingSource = false;
            self.hasPendingName = false;
            self.hasPending = true;
        }

        if (sourceIndex != sourceIndexNotSet and sourceLine != notSet and sourceCharacter != notSetUTF16) {
            self.pendingSourceIndex = sourceIndex;
            self.pendingSourceLine = sourceLine;
            self.pendingSourceCharacter = sourceCharacter;
            self.hasPendingSource = true;
            if (nameIndex != nameIndexNotSet) {
                self.pendingNameIndex = nameIndex;
                self.hasPendingName = true;
            }
        }
    }

    pub fn addGeneratedMapping(self: *Generator, generatedLine: i32, generatedCharacter: core.UTF16Offset) !void {
        if (generatedLine < self.pendingGeneratedLine) {
            return error.GeneratedLineCannotBacktrack;
        }
        if (generatedCharacter < 0) {
            return error.GeneratedCharacterCannotBeNegative;
        }
        self.addMapping(generatedLine, generatedCharacter, sourceIndexNotSet, notSet, notSetUTF16, nameIndexNotSet);
    }

    pub fn addSourceMapping(self: *Generator, generatedLine: i32, generatedCharacter: core.UTF16Offset, sourceIndex: SourceIndex, sourceLine: i32, sourceCharacter: core.UTF16Offset) !void {
        if (generatedLine < self.pendingGeneratedLine) {
            return error.GeneratedLineCannotBacktrack;
        }
        if (generatedCharacter < 0) {
            return error.GeneratedCharacterCannotBeNegative;
        }
        if (sourceIndex == sourceIndexNotSet or sourceIndex >= self.sources.items.len) {
            return error.SourceIndexOutOfRange;
        }
        if (sourceLine < 0) {
            return error.SourceLineCannotBeNegative;
        }
        if (sourceCharacter < 0) {
            return error.SourceCharacterCannotBeNegative;
        }
        self.addMapping(generatedLine, generatedCharacter, sourceIndex, sourceLine, sourceCharacter, nameIndexNotSet);
    }

    pub fn addNamedSourceMapping(self: *Generator, generatedLine: i32, generatedCharacter: core.UTF16Offset, sourceIndex: SourceIndex, sourceLine: i32, sourceCharacter: core.UTF16Offset, nameIndex: NameIndex) !void {
        if (generatedLine < self.pendingGeneratedLine) {
            return error.GeneratedLineCannotBacktrack;
        }
        if (generatedCharacter < 0) {
            return error.GeneratedCharacterCannotBeNegative;
        }
        if (sourceIndex == sourceIndexNotSet or sourceIndex >= self.sources.items.len) {
            return error.SourceIndexOutOfRange;
        }
        if (sourceLine < 0) {
            return error.SourceLineCannotBeNegative;
        }
        if (sourceCharacter < 0) {
            return error.SourceCharacterCannotBeNegative;
        }
        if (nameIndex == nameIndexNotSet or nameIndex >= self.names.items.len) {
            return error.NameIndexOutOfRange;
        }
        self.addMapping(generatedLine, generatedCharacter, sourceIndex, sourceLine, sourceCharacter, nameIndex);
    }

    pub fn resetMappings(self: *Generator) void {
        self.mappings.clearRetainingCapacity();
        self.lastGeneratedLine = 0;
        self.lastGeneratedCharacter = 0;
        self.lastSourceIndex = 0;
        self.lastSourceLine = 0;
        self.lastSourceCharacter = 0;
        self.lastNameIndex = 0;
        self.hasLast = false;
        self.pendingGeneratedLine = 0;
        self.pendingGeneratedCharacter = 0;
        self.pendingSourceIndex = 0;
        self.pendingSourceLine = 0;
        self.pendingSourceCharacter = 0;
        self.pendingNameIndex = 0;
        self.hasPending = false;
        self.hasPendingSource = false;
        self.hasPendingName = false;
    }

    pub fn toRawSourceMap(self: *Generator) *RawSourceMap {
        self.commitPendingMapping();
        const map = self.allocator.create(RawSourceMap) catch unreachable;
        map.* = RawSourceMap{
            .version = 3,
            .file = self.file,
            .sourceRoot = self.sourceRoot,
            .sources = self.sources.items,
            .names = self.names.items,
            .mappings = self.mappings.items,
            .sourcesContent = if (self.sourcesContent.items.len == 0) null else self.sourcesContent.items,
        };
        return map;
    }

    pub fn base64DataURL(self: *Generator, allocator: std.mem.Allocator) ![]const u8 {
        const rawMap = self.toRawSourceMap();
        const out = try std.json.Stringify.valueAlloc(allocator, rawMap.*, .{ .emit_null_optional_fields = false });
        self.allocator.destroy(rawMap);
        defer allocator.free(out);

        const encoder = std.base64.standard.Encoder;
        const encodedLen = encoder.calcSize(out.len);

        var base64Url = try std.ArrayListUnmanaged(u8).initCapacity(allocator, 29 + encodedLen);
        defer base64Url.deinit(allocator);
        try base64Url.appendSlice(allocator, "data:application/json;base64,");

        const start = base64Url.items.len;
        base64Url.items.len += encodedLen;
        _ = encoder.encode(base64Url.items[start..], out);

        return base64Url.toOwnedSlice(allocator);
    }

    pub fn toString(self: *Generator, allocator: std.mem.Allocator) ![]const u8 {
        const rawMap = self.toRawSourceMap();
        const out = try std.json.Stringify.valueAlloc(allocator, rawMap.*, .{ .emit_null_optional_fields = false });
        self.allocator.destroy(rawMap);
        return out;
    }
};

fn base64FormatEncode(value: u8) u8 {
    if (value < 26) {
        return 'A' + value;
    } else if (value < 52) {
        return 'a' + value - 26;
    } else if (value < 62) {
        return '0' + value - 52;
    } else if (value == 62) {
        return '+';
    } else if (value == 63) {
        return '/';
    } else {
        @panic("not a base64 value");
    }
}
