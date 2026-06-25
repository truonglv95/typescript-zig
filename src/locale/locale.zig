const std = @import("std");

pub const Locale = []const u8;

pub var default: Locale = "";

// We don't have a direct equivalent of context.Context in Zig yet,
// so we stub these out or they might need to be passed down manually.

pub fn parse(locale_str: []const u8) ?Locale {
    // Basic language tag validation could go here.
    // For now, we just return the string.
    if (locale_str.len == 0) return null;
    return locale_str;
}
