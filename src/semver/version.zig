const std = @import("std");

pub const Version = struct {
    major: u32 = 0,
    minor: u32 = 0,
    patch: u32 = 0,
    prerelease: []const []const u8 = &[_][]const u8{},
    build: []const []const u8 = &[_][]const u8{},

    pub const zero = Version{
        .prerelease = &[_][]const u8{"0"},
    };

    pub fn incrementMajor(self: Version) Version {
        return Version{
            .major = self.major + 1,
        };
    }

    pub fn incrementMinor(self: Version) Version {
        return Version{
            .major = self.major,
            .minor = self.minor + 1,
        };
    }

    pub fn incrementPatch(self: Version) Version {
        return Version{
            .major = self.major,
            .minor = self.minor,
            .patch = self.patch + 1,
        };
    }

    pub fn compare(a: ?*const Version, b: ?*const Version) std.math.Order {
        if (a == null and b == null) return .eq;
        if (a == null) return .lt;
        if (b == null) return .gt;

        const a_val = a.?;
        const b_val = b.?;

        if (a_val.major != b_val.major) return std.math.order(a_val.major, b_val.major);
        if (a_val.minor != b_val.minor) return std.math.order(a_val.minor, b_val.minor);
        if (a_val.patch != b_val.patch) return std.math.order(a_val.patch, b_val.patch);

        return comparePreReleaseIdentifiers(a_val.prerelease, b_val.prerelease);
    }

    pub fn format(self: Version, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{d}.{d}.{d}", .{ self.major, self.minor, self.patch });
        if (self.prerelease.len > 0) {
            try writer.writeByte('-');
            for (self.prerelease, 0..) |part, i| {
                if (i > 0) try writer.writeByte('.');
                try writer.writeAll(part);
            }
        }
        if (self.build.len > 0) {
            try writer.writeByte('+');
            for (self.build, 0..) |part, i| {
                if (i > 0) try writer.writeByte('.');
                try writer.writeAll(part);
            }
        }
    }
};

pub fn comparePreReleaseIdentifiers(left: []const []const u8, right: []const []const u8) std.math.Order {
    if (left.len == 0) {
        if (right.len == 0) return .eq;
        return .gt;
    } else if (right.len == 0) {
        return .lt;
    }

    const min_len = @min(left.len, right.len);
    for (0..min_len) |i| {
        const cmp = comparePreReleaseIdentifier(left[i], right[i]);
        if (cmp != .eq) return cmp;
    }

    return std.math.order(left.len, right.len);
}

fn isNumericIdentifier(text: []const u8) bool {
    if (text.len == 0) return false;
    if (text[0] == '0' and text.len > 1) return false;
    for (text) |c| {
        if (!std.ascii.isDigit(c)) return false;
    }
    return true;
}

fn comparePreReleaseIdentifier(left: []const u8, right: []const u8) std.math.Order {
    const cmp = std.mem.order(u8, left, right);
    if (cmp == .eq) return cmp;

    const left_is_numeric = isNumericIdentifier(left);
    const right_is_numeric = isNumericIdentifier(right);

    if (left_is_numeric or right_is_numeric) {
        if (!right_is_numeric) return .lt;
        if (!left_is_numeric) return .gt;

        const left_num = std.fmt.parseInt(u32, left, 10) catch {
            return std.math.order(left.len, right.len);
        };
        const right_num = std.fmt.parseInt(u32, right, 10) catch {
            return std.math.order(left.len, right.len);
        };
        return std.math.order(left_num, right_num);
    }

    return cmp;
}

pub const ParseError = error{
    InvalidVersion,
    OutOfMemory,
};

fn isValidPrereleasePart(text: []const u8) bool {
    if (text.len == 0) return false;
    if (isNumericIdentifier(text)) return true;
    for (text) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '-') return false;
    }
    return true;
}

fn isValidBuildPart(text: []const u8) bool {
    if (text.len == 0) return false;
    for (text) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '-') return false;
    }
    return true;
}

pub fn tryParseVersion(allocator: std.mem.Allocator, text: []const u8) !Version {
    var result = Version{};
    if (text.len == 0) return ParseError.InvalidVersion;

    var i: usize = 0;

    // Parse major
    var start = i;
    while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) {}
    if (start == i) return ParseError.InvalidVersion;
    if (text[start] == '0' and i > start + 1) return ParseError.InvalidVersion;
    result.major = std.fmt.parseInt(u32, text[start..i], 10) catch return ParseError.InvalidVersion;

    if (i == text.len) return result;
    if (text[i] != '.') return ParseError.InvalidVersion;
    i += 1;

    // Parse minor
    start = i;
    while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) {}
    if (start == i) return ParseError.InvalidVersion;
    if (text[start] == '0' and i > start + 1) return ParseError.InvalidVersion;
    result.minor = std.fmt.parseInt(u32, text[start..i], 10) catch return ParseError.InvalidVersion;

    if (i == text.len) return result;
    if (text[i] != '.') return ParseError.InvalidVersion;
    i += 1;

    // Parse patch
    start = i;
    while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) {}
    if (start == i) return ParseError.InvalidVersion;
    if (text[start] == '0' and i > start + 1) return ParseError.InvalidVersion;
    result.patch = std.fmt.parseInt(u32, text[start..i], 10) catch return ParseError.InvalidVersion;

    if (i == text.len) return result;

    if (text[i] == '-') {
        i += 1;
        start = i;
        while (i < text.len and text[i] != '+') : (i += 1) {}
        const prereleaseStr = text[start..i];
        if (prereleaseStr.len == 0) return ParseError.InvalidVersion;
        var it = std.mem.splitScalar(u8, prereleaseStr, '.');
        var list = std.ArrayList([]const u8).empty;
        errdefer list.deinit(allocator);
        while (it.next()) |part| {
            if (!isValidPrereleasePart(part)) return ParseError.InvalidVersion;
            try list.append(allocator, part);
        }
        result.prerelease = try list.toOwnedSlice(allocator);
    }

    if (i < text.len and text[i] == '+') {
        i += 1;
        start = i;
        const buildStr = text[start..];
        if (buildStr.len == 0) return ParseError.InvalidVersion;
        var it = std.mem.splitScalar(u8, buildStr, '.');
        var list = std.ArrayList([]const u8).empty;
        errdefer list.deinit(allocator);
        while (it.next()) |part| {
            if (!isValidBuildPart(part)) return ParseError.InvalidVersion;
            try list.append(allocator, part);
        }
        result.build = try list.toOwnedSlice(allocator);
        i = text.len;
    }

    if (i != text.len) return ParseError.InvalidVersion;

    return result;
}

pub fn mustParse(allocator: std.mem.Allocator, text: []const u8) Version {
    return tryParseVersion(allocator, text) catch unreachable;
}
