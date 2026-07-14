const std = @import("std");
const core = @import("../core/core.zig");

pub const SourceIndex = i32;
pub const NameIndex = i32;

pub const MissingSource: SourceIndex = -1;
pub const MissingName: NameIndex = -1;
pub const MissingLineOrColumn: i32 = -1;
pub const MissingUTF16Column: core.UTF16Offset = -1;

pub const Mapping = struct {
    generatedLine: i32,
    generatedCharacter: core.UTF16Offset,
    sourceIndex: SourceIndex,
    sourceLine: i32,
    sourceCharacter: core.UTF16Offset,
    nameIndex: NameIndex,

    pub fn equals(self: *const Mapping, other: *const Mapping) bool {
        return self == other or (self.generatedLine == other.generatedLine and
            self.generatedCharacter == other.generatedCharacter and
            self.sourceIndex == other.sourceIndex and
            self.sourceLine == other.sourceLine and
            self.sourceCharacter == other.sourceCharacter and
            self.nameIndex == other.nameIndex);
    }

    pub fn isSourceMapping(self: *const Mapping) bool {
        return self.sourceIndex != MissingSource and
            self.sourceLine != MissingLineOrColumn and
            self.sourceCharacter != MissingUTF16Column;
    }
};

pub const MappingsDecoder = struct {
    mappings: []const u8,
    done: bool,
    pos: usize,
    generatedLine: i32,
    generatedCharacter: core.UTF16Offset,
    sourceIndex: SourceIndex,
    sourceLine: i32,
    sourceCharacter: core.UTF16Offset,
    nameIndex: NameIndex,
    err: ?[]const u8,
    mappingArena: std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator, mappings: []const u8) MappingsDecoder {
        return .{
            .mappings = mappings,
            .done = false,
            .pos = 0,
            .generatedLine = 0,
            .generatedCharacter = 0,
            .sourceIndex = 0,
            .sourceLine = 0,
            .sourceCharacter = 0,
            .nameIndex = 0,
            .err = null,
            .mappingArena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: *MappingsDecoder) void {
        self.mappingArena.deinit();
    }

    pub fn mappingsString(self: *const MappingsDecoder) []const u8 {
        return self.mappings;
    }

    pub fn getPos(self: *const MappingsDecoder) usize {
        return self.pos;
    }

    pub fn getError(self: *const MappingsDecoder) ?[]const u8 {
        return self.err;
    }

    pub fn state(self: *MappingsDecoder) !*Mapping {
        return self.captureMapping(true, true);
    }

    pub const Iterator = struct {
        decoder: *MappingsDecoder,

        pub fn next(self: *Iterator) !?*Mapping {
            const result = try self.decoder.nextMapping();
            if (result.done) return null;
            return result.value;
        }
    };

    pub fn values(self: *MappingsDecoder) Iterator {
        return .{ .decoder = self };
    }

    pub const NextResult = struct {
        value: ?*Mapping,
        done: bool,
    };

    pub fn nextMapping(d: *MappingsDecoder) !NextResult {
        while (!d.done and d.pos < d.mappings.len) {
            const ch = d.mappings[d.pos];
            if (ch == ';') {
                d.generatedLine += 1;
                d.generatedCharacter = 0;
                d.pos += 1;
                continue;
            }

            if (ch == ',') {
                d.pos += 1;
                continue;
            }

            var has_source = false;
            var has_name = false;
            d.generatedCharacter += @as(core.UTF16Offset, @intCast(d.base64VLQFormatDecode()));
            if (d.hasReportedError()) {
                return d.stopIterating();
            }
            if (d.generatedCharacter < 0) {
                return d.setErrorAndStopIterating("Invalid generatedCharacter found");
            }

            if (!d.isSourceMappingSegmentEnd()) {
                has_source = true;

                d.sourceIndex += @as(SourceIndex, @intCast(d.base64VLQFormatDecode()));
                if (d.hasReportedError()) {
                    return d.stopIterating();
                }
                if (d.sourceIndex < 0) {
                    return d.setErrorAndStopIterating("Invalid sourceIndex found");
                }
                if (d.isSourceMappingSegmentEnd()) {
                    return d.setErrorAndStopIterating("Unsupported Format: No entries after sourceIndex");
                }

                d.sourceLine += @as(i32, @intCast(d.base64VLQFormatDecode()));
                if (d.hasReportedError()) {
                    return d.stopIterating();
                }
                if (d.sourceLine < 0) {
                    return d.setErrorAndStopIterating("Invalid sourceLine found");
                }
                if (d.isSourceMappingSegmentEnd()) {
                    return d.setErrorAndStopIterating("Unsupported Format: No entries after sourceLine");
                }

                d.sourceCharacter += @as(core.UTF16Offset, @intCast(d.base64VLQFormatDecode()));
                if (d.hasReportedError()) {
                    return d.stopIterating();
                }
                if (d.sourceCharacter < 0) {
                    return d.setErrorAndStopIterating("Invalid sourceCharacter found");
                }

                if (!d.isSourceMappingSegmentEnd()) {
                    has_name = true;
                    d.nameIndex += @as(NameIndex, @intCast(d.base64VLQFormatDecode()));
                    if (d.hasReportedError()) {
                        return d.stopIterating();
                    }
                    if (d.nameIndex < 0) {
                        return d.setErrorAndStopIterating("Invalid nameIndex found");
                    }

                    if (!d.isSourceMappingSegmentEnd()) {
                        return d.setErrorAndStopIterating("Unsupported Error Format: Entries after nameIndex");
                    }
                }
            }

            return NextResult{ .value = try d.captureMapping(has_source, has_name), .done = false };
        }

        return d.stopIterating();
    }

    fn captureMapping(d: *MappingsDecoder, has_source: bool, has_name: bool) !*Mapping {
        const mapping = try d.mappingArena.allocator().create(Mapping);
        mapping.* = .{
            .generatedLine = d.generatedLine,
            .generatedCharacter = d.generatedCharacter,
            .sourceIndex = if (has_source) d.sourceIndex else MissingSource,
            .sourceLine = if (has_source) d.sourceLine else MissingLineOrColumn,
            .sourceCharacter = if (has_source) d.sourceCharacter else MissingUTF16Column,
            .nameIndex = if (has_name) d.nameIndex else MissingName,
        };
        return mapping;
    }

    fn stopIterating(d: *MappingsDecoder) NextResult {
        d.done = true;
        return .{ .value = null, .done = true };
    }

    fn setError(d: *MappingsDecoder, err: []const u8) void {
        d.err = err;
    }

    fn setErrorAndStopIterating(d: *MappingsDecoder, err: []const u8) NextResult {
        d.setError(err);
        return d.stopIterating();
    }

    fn hasReportedError(d: *const MappingsDecoder) bool {
        return d.err != null;
    }

    fn isSourceMappingSegmentEnd(d: *const MappingsDecoder) bool {
        return d.pos == d.mappings.len or d.mappings[d.pos] == ',' or d.mappings[d.pos] == ';';
    }

    fn base64VLQFormatDecode(d: *MappingsDecoder) i32 {
        var more_digits = true;
        var shift_count: u5 = 0;
        var value: i32 = 0;
        while (more_digits) : (d.pos += 1) {
            if (d.pos >= d.mappings.len) {
                d.setError("Error in decoding base64VLQFormatDecode, past the mapping string");
                return -1;
            }

            const current_byte = base64FormatDecode(d.mappings[d.pos]);
            if (current_byte == -1) {
                d.setError("Invalid character in VLQ");
                return -1;
            }

            more_digits = (current_byte & 32) != 0;

            const part = (current_byte & 31);
            value = value | (@as(i32, @intCast(part)) << shift_count);
            shift_count += 5;
        }

        if ((value & 1) == 0) {
            value = value >> 1;
        } else {
            value = value >> 1;
            value = -value;
        }

        return value;
    }
};

fn base64FormatDecode(ch: u8) i32 {
    return switch (ch) {
        'A'...'Z' => ch - 'A',
        'a'...'z' => ch - 'a' + 26,
        '0'...'9' => ch - '0' + 52,
        '+' => 62,
        '/' => 63,
        else => -1,
    };
}
