const std = @import("std");

pub fn equateStringCaseInsensitive(a: []const u8, b: []const u8) bool {
    return std.ascii.eqlIgnoreCase(a, b);
}

pub fn equateStringCaseSensitive(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub const Comparison = enum(i8) {
    LessThan = -1,
    Equal = 0,
    GreaterThan = 1,
};

pub fn compareStringsCaseInsensitive(a: []const u8, b: []const u8) Comparison {
    if (std.mem.eql(u8, a, b)) {
        return .Equal;
    }
    const cmp = std.ascii.orderIgnoreCase(a, b);
    return switch (cmp) {
        .lt => .LessThan,
        .eq => .Equal,
        .gt => .GreaterThan,
    };
}

pub fn compareStringsCaseSensitive(a: []const u8, b: []const u8) Comparison {
    const cmp = std.mem.order(u8, a, b);
    return switch (cmp) {
        .lt => .LessThan,
        .eq => .Equal,
        .gt => .GreaterThan,
    };
}

pub fn hasPrefix(s: []const u8, prefix: []const u8, caseSensitive: bool) bool {
    if (caseSensitive) {
        return std.mem.startsWith(u8, s, prefix);
    }
    if (prefix.len > s.len) return false;
    return std.ascii.eqlIgnoreCase(s[0..prefix.len], prefix);
}

pub fn hasSuffix(s: []const u8, suffix: []const u8, caseSensitive: bool) bool {
    if (caseSensitive) {
        return std.mem.endsWith(u8, s, suffix);
    }
    if (suffix.len > s.len) return false;
    return std.ascii.eqlIgnoreCase(s[s.len - suffix.len ..], suffix);
}

pub fn compareStringsCaseInsensitiveEslintCompatible(a: []const u8, b: []const u8) Comparison {
    if (std.mem.eql(u8, a, b)) {
        return .Equal;
    }
    // Very naive stub
    return compareStringsCaseInsensitive(a, b);
}
