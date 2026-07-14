const std = @import("std");
const version_mod = @import("version.zig");
const Version = version_mod.Version;

pub const ComparatorOperator = enum {
    less_than,
    less_than_equal,
    equal,
    greater_than_equal,
    greater_than,

    pub fn format(self: ComparatorOperator, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .less_than => try writer.writeAll("<"),
            .less_than_equal => try writer.writeAll("<="),
            .equal => try writer.writeAll("="),
            .greater_than_equal => try writer.writeAll(">="),
            .greater_than => try writer.writeAll(">"),
        }
    }
};

pub const VersionComparator = struct {
    operator: ComparatorOperator,
    operand: Version,
};

pub const VersionRange = struct {
    alternatives: [][]VersionComparator,

    pub fn format(self: VersionRange, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        var written = false;

        for (self.alternatives, 0..) |alternative, i| {
            if (i > 0) try writer.writeAll(" || ");
            for (alternative, 0..) |comparator, j| {
                if (j > 0) try writer.writeAll(" ");
                try writer.print("{}{}", .{ comparator.operator, comparator.operand });
                written = true;
            }
        }

        if (!written) {
            try writer.writeAll("*");
        }
    }

    pub fn testVersion(self: VersionRange, version: *const Version) bool {
        if (self.alternatives.len == 0) return true;

        for (self.alternatives) |alternative| {
            var all_match = true;
            for (alternative) |comparator| {
                const cmp = version.compare(&comparator.operand);
                const matched = switch (comparator.operator) {
                    .less_than => cmp == .lt,
                    .less_than_equal => cmp == .lt or cmp == .eq,
                    .equal => cmp == .eq,
                    .greater_than_equal => cmp == .gt or cmp == .eq,
                    .greater_than => cmp == .gt,
                };
                if (!matched) {
                    all_match = false;
                    break;
                }
            }
            if (all_match) return true;
        }

        return false;
    }
};

const PartialVersion = struct {
    version: Version,
    major_str: []const u8,
    minor_str: []const u8,
    patch_str: []const u8,
};

fn isWildcard(text: []const u8) bool {
    return std.mem.eql(u8, text, "*") or std.mem.eql(u8, text, "x") or std.mem.eql(u8, text, "X");
}

fn parsePartial(allocator: std.mem.Allocator, text: []const u8) !PartialVersion {
    // pattern: (?i)^([x*0]|[1-9]\d*)(?:\.([x*0]|[1-9]\d*)(?:\.([x*0]|[1-9]\d*)(?:-([a-z0-9-.]+))?(?:\+([a-z0-9-.]+))?)?)?$
    if (text.len == 0) return error.InvalidVersion;

    var i: usize = 0;
    var start = i;

    // Parse major
    while (i < text.len and text[i] != '.' and text[i] != '-' and text[i] != '+') : (i += 1) {}
    const major_str = text[start..i];
    if (major_str.len == 0) return error.InvalidVersion;

    var minor_str: []const u8 = "*";
    var patch_str: []const u8 = "*";
    var prerelease_str: []const u8 = "";
    var build_str: []const u8 = "";

    if (i < text.len and text[i] == '.') {
        i += 1;
        start = i;
        while (i < text.len and text[i] != '.' and text[i] != '-' and text[i] != '+') : (i += 1) {}
        minor_str = text[start..i];
        if (minor_str.len == 0) return error.InvalidVersion;

        if (i < text.len and text[i] == '.') {
            i += 1;
            start = i;
            while (i < text.len and text[i] != '-' and text[i] != '+') : (i += 1) {}
            patch_str = text[start..i];
            if (patch_str.len == 0) return error.InvalidVersion;

            if (i < text.len and text[i] == '-') {
                i += 1;
                start = i;
                while (i < text.len and text[i] != '+') : (i += 1) {}
                prerelease_str = text[start..i];
                if (prerelease_str.len == 0) return error.InvalidVersion;
            }

            if (i < text.len and text[i] == '+') {
                i += 1;
                build_str = text[i..];
                if (build_str.len == 0) return error.InvalidVersion;
                i = text.len;
            }
        }
    }

    if (i != text.len) return error.InvalidVersion;

    var major_num: u32 = 0;
    var minor_num: u32 = 0;
    var patch_num: u32 = 0;

    if (isWildcard(major_str)) {
        // all wildcards
    } else {
        major_num = try std.fmt.parseInt(u32, major_str, 10);
        if (!isWildcard(minor_str)) {
            minor_num = try std.fmt.parseInt(u32, minor_str, 10);
            if (!isWildcard(patch_str)) {
                patch_num = try std.fmt.parseInt(u32, patch_str, 10);
            }
        }
    }

    var prerelease = std.ArrayList([]const u8).empty;
    if (prerelease_str.len > 0) {
        var it = std.mem.splitScalar(u8, prerelease_str, '.');
        while (it.next()) |part| {
            try prerelease.append(allocator, part);
        }
    }

    var build = std.ArrayList([]const u8).empty;
    if (build_str.len > 0) {
        var it = std.mem.splitScalar(u8, build_str, '.');
        while (it.next()) |part| {
            try build.append(allocator, part);
        }
    }

    return PartialVersion{
        .version = Version{
            .major = major_num,
            .minor = minor_num,
            .patch = patch_num,
            .prerelease = try prerelease.toOwnedSlice(allocator),
            .build = try build.toOwnedSlice(allocator),
        },
        .major_str = major_str,
        .minor_str = minor_str,
        .patch_str = patch_str,
    };
}

fn parseComparator(allocator: std.mem.Allocator, op: []const u8, text: []const u8) ![]VersionComparator {
    var operator: ComparatorOperator = .equal;
    if (std.mem.eql(u8, op, "<")) operator = .less_than else if (std.mem.eql(u8, op, "<=")) operator = .less_than_equal else if (std.mem.eql(u8, op, "=")) operator = .equal else if (std.mem.eql(u8, op, ">=")) operator = .greater_than_equal else if (std.mem.eql(u8, op, ">")) operator = .greater_than else if (op.len > 0 and op[0] != '~' and op[0] != '^') return error.InvalidOperator;

    const result = try parsePartial(allocator, text);

    var comparators_result = std.ArrayList(VersionComparator).empty;
    errdefer comparators_result.deinit(allocator);

    if (!isWildcard(result.major_str)) {
        if (std.mem.eql(u8, op, "~")) {
            try comparators_result.append(allocator, .{ .operator = .greater_than_equal, .operand = result.version });
            const secondVersion = if (isWildcard(result.minor_str)) result.version.incrementMajor() else result.version.incrementMinor();
            try comparators_result.append(allocator, .{ .operator = .less_than, .operand = secondVersion });
        } else if (std.mem.eql(u8, op, "^")) {
            try comparators_result.append(allocator, .{ .operator = .greater_than_equal, .operand = result.version });
            const secondVersion = if (result.version.major > 0 or isWildcard(result.minor_str))
                result.version.incrementMajor()
            else if (result.version.minor > 0 or isWildcard(result.patch_str))
                result.version.incrementMinor()
            else
                result.version.incrementPatch();
            try comparators_result.append(allocator, .{ .operator = .less_than, .operand = secondVersion });
        } else if (std.mem.eql(u8, op, "<") or std.mem.eql(u8, op, ">=")) {
            var version = result.version;
            if (isWildcard(result.minor_str) or isWildcard(result.patch_str)) {
                version.prerelease = Version.zero.prerelease;
            }
            try comparators_result.append(allocator, .{ .operator = operator, .operand = version });
        } else if (std.mem.eql(u8, op, "<=") or std.mem.eql(u8, op, ">")) {
            var version = result.version;
            var op_to_use = operator;
            if (isWildcard(result.minor_str)) {
                op_to_use = if (operator == .less_than_equal) .less_than else .greater_than_equal;
                version = version.incrementMajor();
                version.prerelease = Version.zero.prerelease;
            } else if (isWildcard(result.patch_str)) {
                op_to_use = if (operator == .less_than_equal) .less_than else .greater_than_equal;
                version = version.incrementMinor();
                version.prerelease = Version.zero.prerelease;
            }
            try comparators_result.append(allocator, .{ .operator = op_to_use, .operand = version });
        } else if (std.mem.eql(u8, op, "=") or op.len == 0) {
            operator = .equal;
            if (isWildcard(result.minor_str) or isWildcard(result.patch_str)) {
                var firstVersion = result.version;
                firstVersion.prerelease = Version.zero.prerelease;
                var secondVersion = if (isWildcard(result.minor_str)) result.version.incrementMajor() else result.version.incrementMinor();
                secondVersion.prerelease = Version.zero.prerelease;
                try comparators_result.append(allocator, .{ .operator = .greater_than_equal, .operand = firstVersion });
                try comparators_result.append(allocator, .{ .operator = .less_than, .operand = secondVersion });
            } else {
                try comparators_result.append(allocator, .{ .operator = operator, .operand = result.version });
            }
        } else {
            return error.InvalidOperator;
        }
    } else {
        if (std.mem.eql(u8, op, "<") or std.mem.eql(u8, op, ">")) {
            try comparators_result.append(allocator, .{ .operator = .less_than, .operand = Version.zero });
        }
    }

    return try comparators_result.toOwnedSlice(allocator);
}

fn parseHyphen(allocator: std.mem.Allocator, left: []const u8, right: []const u8) ![]VersionComparator {
    const left_res = try parsePartial(allocator, left);
    const right_res = try parsePartial(allocator, right);

    var comparators = std.ArrayList(VersionComparator).empty;
    errdefer comparators.deinit(allocator);

    if (!isWildcard(left_res.major_str)) {
        try comparators.append(allocator, .{ .operator = .greater_than_equal, .operand = left_res.version });
    }

    if (!isWildcard(right_res.major_str)) {
        var operator: ComparatorOperator = undefined;
        var operand = right_res.version;

        if (isWildcard(right_res.minor_str)) {
            operand = operand.incrementMajor();
            operator = .less_than;
        } else if (isWildcard(right_res.patch_str)) {
            operand = operand.incrementMinor();
            operator = .less_than;
        } else {
            operator = .less_than_equal;
        }

        try comparators.append(allocator, .{ .operator = operator, .operand = operand });
    }

    return try comparators.toOwnedSlice(allocator);
}

pub fn tryParseVersionRange(allocator: std.mem.Allocator, text: []const u8) !VersionRange {
    var alternatives = std.ArrayList([]VersionComparator).empty;
    errdefer alternatives.deinit(allocator);

    var or_it = std.mem.splitSequence(u8, std.mem.trim(u8, text, " \t\r\n"), "||");
    while (or_it.next()) |r_untrimmed| {
        const r = std.mem.trim(u8, r_untrimmed, " \t\r\n");
        if (r.len == 0) continue;

        var comparators = std.ArrayList(VersionComparator).empty;
        errdefer comparators.deinit(allocator);

        // Check for hyphen match. A bit tricky without regex.
        // Look for " - " in `r`.
        const hyphen_idx = std.mem.indexOf(u8, r, " - ");
        if (hyphen_idx != null) {
            const left = std.mem.trim(u8, r[0..hyphen_idx.?], " \t\r\n");
            const right = std.mem.trim(u8, r[hyphen_idx.? + 3 ..], " \t\r\n");
            const parsed = try parseHyphen(allocator, left, right);
            try comparators.appendSlice(allocator, parsed);
        } else {
            var space_it = std.mem.tokenizeAny(u8, r, " \t\r\n");
            while (space_it.next()) |simple| {
                // Parse operator and operand
                var op: []const u8 = "";
                var operand: []const u8 = simple;

                if (std.mem.startsWith(u8, simple, "<=")) {
                    op = "<=";
                    operand = simple[2..];
                } else if (std.mem.startsWith(u8, simple, ">=")) {
                    op = ">=";
                    operand = simple[2..];
                } else if (simple[0] == '~' or simple[0] == '^' or simple[0] == '<' or simple[0] == '>' or simple[0] == '=') {
                    op = simple[0..1];
                    operand = simple[1..];
                }

                // operand might be empty if there's a space after operator, e.g. ">= 1.0.0"
                if (operand.len == 0) {
                    if (space_it.next()) |next_operand| {
                        operand = next_operand;
                    } else {
                        return error.InvalidVersionRange;
                    }
                }

                const parsed = try parseComparator(allocator, op, operand);
                try comparators.appendSlice(allocator, parsed);
            }
        }
        try alternatives.append(allocator, try comparators.toOwnedSlice(allocator));
    }

    return VersionRange{ .alternatives = try alternatives.toOwnedSlice(allocator) };
}
