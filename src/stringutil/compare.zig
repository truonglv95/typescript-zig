const std = @import("std");

/// Port of stringutil/compare.go — string comparison utilities.

pub fn equateStringCaseInsensitive(a: []const u8, b: []const u8) bool {
    return std.ascii.eqlIgnoreCase(a, b);
}

pub fn equateStringCaseSensitive(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub fn getStringEqualityComparer(ignore_case: bool) *const fn ([]const u8, []const u8) bool {
    if (ignore_case) return &equateStringCaseInsensitive;
    return &equateStringCaseSensitive;
}

pub const Comparison = enum(i8) {
    LessThan = -1,
    Equal = 0,
    GreaterThan = 1,
};

pub fn compareStringsCaseInsensitive(a: []const u8, b: []const u8) Comparison {
    if (std.mem.eql(u8, a, b)) return .Equal;
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

pub fn getStringComparer(ignore_case: bool) *const fn ([]const u8, []const u8) Comparison {
    if (ignore_case) return &compareStringsCaseInsensitive;
    return &compareStringsCaseSensitive;
}

pub fn hasPrefix(s: []const u8, prefix: []const u8, case_sensitive: bool) bool {
    if (case_sensitive) return std.mem.startsWith(u8, s, prefix);
    if (prefix.len > s.len) return false;
    return std.ascii.eqlIgnoreCase(s[0..prefix.len], prefix);
}

pub fn hasSuffix(s: []const u8, suffix: []const u8, case_sensitive: bool) bool {
    if (case_sensitive) return std.mem.endsWith(u8, s, suffix);
    if (suffix.len > s.len) return false;
    return std.ascii.eqlIgnoreCase(s[s.len - suffix.len ..], suffix);
}

/// Port of HasPrefixAndSuffixWithoutOverlap.
pub fn hasPrefixAndSuffixWithoutOverlap(s: []const u8, prefix: []const u8, suffix: []const u8, case_sensitive: bool) bool {
    if (prefix.len + suffix.len > s.len) return false;
    return hasPrefix(s, prefix, case_sensitive) and hasSuffix(s, suffix, case_sensitive);
}

/// Port of CompareStringsCaseInsensitiveThenSensitive.
pub fn compareStringsCaseInsensitiveThenSensitive(a: []const u8, b: []const u8) Comparison {
    const cmp = compareStringsCaseInsensitive(a, b);
    if (cmp != .Equal) return cmp;
    return compareStringsCaseSensitive(a, b);
}

/// Port of CompareStringsCaseInsensitiveEslintCompatible.
/// Uses toLowerCase for ESLint compatibility.
pub fn compareStringsCaseInsensitiveEslintCompatible(a: []const u8, b: []const u8) Comparison {
    if (std.mem.eql(u8, a, b)) return .Equal;
    // Compare using lowercased versions
    const cmp = std.ascii.orderIgnoreCase(a, b);
    return switch (cmp) {
        .lt => .LessThan,
        .eq => .Equal,
        .gt => .GreaterThan,
    };
}
