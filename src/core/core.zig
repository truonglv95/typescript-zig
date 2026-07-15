const std = @import("std");

/// Port of core/core.go — utility functions (Filter, Map, Find, etc.)
/// Port of core/binarysearch.go — BinarySearchUniqueFunc
/// Port of core/nodemodules.go — Node core module lookups
/// Port of core/pattern.go — wildcard pattern matching
/// Port of core/languagevariant.go — LanguageVariant
/// Port of core/context.go — cancellation context

// === LanguageVariant ===

pub const LanguageVariant = enum(u32) {
    Standard = 0,
    JSX = 1,
};

// === Basic types ===

pub const TextPos = usize;
pub const UTF16Offset = i32;

pub const Tristate = enum(u8) {
    Unknown = 0,
    True = 1,
    False = 2,

    pub fn isTrue(self: Tristate) bool {
        return self == .True;
    }
    pub fn isFalse(self: Tristate) bool {
        return self == .False;
    }
    pub fn isUnknown(self: Tristate) bool {
        return self == .Unknown;
    }
    pub fn isTrueOrUnknown(self: Tristate) bool {
        return self == .True or self == .Unknown;
    }
    pub fn isFalseOrUnknown(self: Tristate) bool {
        return self == .False or self == .Unknown;
    }
};

// === ScriptTarget, ModuleKind, etc. (from existing code) ===

pub const ScriptTarget = enum(u32) {
    None = 0, ES5 = 1, ES2015 = 2, ES2016 = 3, ES2017 = 4, ES2018 = 5,
    ES2019 = 6, ES2020 = 7, ES2021 = 8, ES2022 = 9, ES2023 = 10, ES2024 = 11,
    ES2025 = 12, ESNext = 99, JSON = 100,
    pub const Latest = ScriptTarget.ESNext;
};

pub const CompilerOptions = @import("compiler_options_generated.zig").CompilerOptions;
pub const PathsMappings = @import("compiler_options_generated.zig").PathsMappings;

pub const ModuleKind = enum(u32) {
    None = 0, CommonJS = 1, AMD = 2, UMD = 3, System = 4, ES2015 = 5,
    ES2020 = 6, ES2022 = 7, ESNext = 99, Node16 = 100, NodeNext = 199, Preserve = 200,
};

pub const ResolutionMode = ModuleKind;

pub const ModuleResolutionKind = enum(u32) {
    Classic = 1, NodeJs = 2, Node16 = 3, NodeNext = 99, Bundler = 100,
};

pub const ModuleDetectionKind = enum(u32) { Legacy = 1, Auto = 2, Force = 3 };
pub const JsxEmit = enum(u32) { None = 0, Preserve = 1, ReactNative = 2, React = 3, ReactJSX = 4, ReactJSXDev = 5 };
pub const NewLineKind = enum(u32) { CarriageReturnLineFeed = 0, LineFeed = 1 };
pub const ImportsNotUsedAsValues = enum(u32) { Remove = 0, Preserve = 1, Error = 2 };
pub const PollingWatchKind = enum(u32) { FixedInterval = 0, PriorityInterval = 1, DynamicPriority = 2, FixedChunkSize = 3 };
pub const WatchFileKind = enum(u32) { FixedPollingInterval = 0, PriorityPollingInterval = 1, DynamicPriorityPolling = 2, UseFsEvents = 3, UseFsEventsOnParentDirectory = 4 };
pub const WatchDirectoryKind = enum(u32) { UseFsEvents = 0, FixedPollingInterval = 1, DynamicPriorityPolling = 2, FixedChunkSizePolling = 3 };
pub const TokenFlags = enum(u32) { None = 0 };
pub const ScriptKind = enum(u32) { Unknown = 0, JS = 1, JSX = 2, TS = 3, TSX = 4, External = 5, JSON = 6, Deferred = 7 };

pub const TypeAcquisition = struct {
    enable: bool = false,
    include: ?[][]const u8 = null,
    exclude: ?[][]const u8 = null,
};

pub const WatchOptions = struct {};

// === Slice utility functions (port of core.go) ===

/// Filter a slice, keeping elements where f returns true.
pub fn Filter(comptime T: type, allocator: std.mem.Allocator, slice: []const T, f: *const fn (T) bool) ![]T {
    var result = std.ArrayList(T).empty;
    for (slice) |item| {
        if (f(item)) try result.append(allocator, item);
    }
    return result.toOwnedSlice(allocator);
}

/// Map a slice of T to a slice of U.
pub fn Map(comptime T: type, comptime U: type, allocator: std.mem.Allocator, slice: []const T, f: *const fn (T) U) ![]U {
    var result = try allocator.alloc(U, slice.len);
    for (slice, 0..) |item, i| {
        result[i] = f(item);
    }
    return result;
}

/// Find the first element where f returns true.
pub fn Find(comptime T: type, slice: []const T, f: *const fn (T) bool) ?T {
    for (slice) |item| {
        if (f(item)) return item;
    }
    return null;
}

/// Find the index of the first element where f returns true.
pub fn FindIndex(comptime T: type, slice: []const T, f: *const fn (T) bool) usize {
    for (slice, 0..) |item, i| {
        if (f(item)) return i;
    }
    return slice.len;
}

/// Returns true if any element matches f.
pub fn Some(comptime T: type, slice: []const T, f: *const fn (T) bool) bool {
    for (slice) |item| {
        if (f(item)) return true;
    }
    return false;
}

/// Returns true if all elements match f.
pub fn Every(comptime T: type, slice: []const T, f: *const fn (T) bool) bool {
    for (slice) |item| {
        if (!f(item)) return false;
    }
    return true;
}

/// Count elements where f returns true.
pub fn CountWhere(comptime T: type, slice: []const T, f: *const fn (T) bool) usize {
    var count: usize = 0;
    for (slice) |item| {
        if (f(item)) count += 1;
    }
    return count;
}

/// Concatenate two slices.
pub fn Concatenate(comptime T: type, allocator: std.mem.Allocator, s1: []const T, s2: []const T) ![]T {
    var result = try allocator.alloc(T, s1.len + s2.len);
    @memcpy(result[0..s1.len], s1);
    @memcpy(result[s1.len..], s2);
    return result;
}

/// Returns true if s1 and s2 contain the same elements in the same order.
pub fn Same(comptime T: type, s1: []const T, s2: []const T) bool {
    if (s1.len != s2.len) return false;
    for (s1, s2) |a, b| {
        if (a != b) return false;
    }
    return true;
}

/// FirstOrNil returns the first element or zero value.
pub fn FirstOrNil(comptime T: type, slice: []const T) ?T {
    if (slice.len == 0) return null;
    return slice[0];
}

/// LastOrNil returns the last element or zero value.
pub fn LastOrNil(comptime T: type, slice: []const T) ?T {
    if (slice.len == 0) return null;
    return slice[slice.len - 1];
}

/// FirstNonZero returns the first non-zero value.
pub fn FirstNonZero(comptime T: type, values: []const T) ?T {
    for (values) |v| {
        if (v != std.mem.zeroes(T)) return v;
    }
    return null;
}

/// OrElse returns the first non-zero value, or a default.
pub fn OrElse(comptime T: type, value: ?T, default: T) T {
    return value orelse default;
}

// === Binary Search (port of binarysearch.go) ===

/// BinarySearchUniqueFunc — binary search assuming at most one match.
pub fn BinarySearchUniqueFunc(comptime T: type, slice: []const T, cmp: *const fn (usize, T) i32) struct { index: usize, found: bool } {
    const n = slice.len;
    if (n == 0) return .{ .index = 0, .found = false };
    var low: usize = 0;
    var high: usize = n - 1;
    while (low <= high) {
        const middle = low + ((high - low) >> 1);
        const value = cmp(middle, slice[middle]);
        if (value < 0) {
            low = middle + 1;
        } else if (value > 0) {
            if (middle == 0) break;
            high = middle - 1;
        } else {
            return .{ .index = middle, .found = true };
        }
    }
    return .{ .index = low, .found = false };
}

// === Pattern matching (port of pattern.go) ===

pub const Pattern = struct {
    text: []const u8,
    star_index: i32, // -1 for exact match

    pub fn tryParse(pattern: []const u8) Pattern {
        const star = std.mem.indexOfScalar(u8, pattern, '*');
        if (star == null) return .{ .text = pattern, .star_index = -1 };
        const si: i32 = @intCast(star.?);
        // Check for second star
        if (si + 1 < @as(i32, @intCast(pattern.len))) {
            if (std.mem.indexOfScalar(u8, pattern[@as(usize, @intCast(si + 1))..], '*') != null) {
                return .{ .text = "", .star_index = -2 }; // invalid
            }
        }
        return .{ .text = pattern, .star_index = si };
    }

    pub fn isValid(self: Pattern) bool {
        return self.star_index == -1 or self.star_index < @as(i32, @intCast(self.text.len));
    }

    pub fn matches(self: Pattern, candidate: []const u8) bool {
        if (self.star_index == -1) return std.mem.eql(u8, self.text, candidate);
        if (self.star_index < 0) return false;
        const si: usize = @intCast(self.star_index);
        const prefix = self.text[0..si];
        const suffix = self.text[si + 1 ..];
        if (candidate.len < prefix.len + suffix.len) return false;
        return std.mem.startsWith(u8, candidate, prefix) and std.mem.endsWith(u8, candidate, suffix);
    }

    pub fn matchedText(self: Pattern, candidate: []const u8) []const u8 {
        if (self.star_index == -1) return "";
        const si: usize = @intCast(self.star_index);
        const suffix_len = self.text.len - si - 1;
        return candidate[si .. candidate.len - suffix_len];
    }
};

/// FindBestPatternMatch — find the best matching pattern.
pub fn FindBestPatternMatch(comptime T: type, values: []const T, get_pattern: *const fn (T) Pattern, candidate: []const u8) ?T {
    var best: ?T = null;
    var longest_match_prefix_length: i32 = -1;
    for (values) |value| {
        const pattern = get_pattern(value);
        if ((pattern.star_index == -1 or pattern.star_index > longest_match_prefix_length) and pattern.matches(candidate)) {
            best = value;
            longest_match_prefix_length = pattern.star_index;
        }
    }
    return best;
}

// === Node core modules (port of nodemodules.go) ===

pub fn isNodeCoreModule(module_name: []const u8) bool {
    // Check unprefixed modules
    for (unprefixed_node_core_modules) |mod| {
        if (std.mem.eql(u8, mod, module_name)) return true;
    }
    // Check node: prefixed
    if (std.mem.startsWith(u8, module_name, "node:")) {
        const unprefixed = module_name[5..];
        for (unprefixed_node_core_modules) |mod| {
            if (std.mem.eql(u8, mod, unprefixed)) return true;
        }
    }
    // Check exclusively prefixed
    for (exclusively_prefixed_node_core_modules) |mod| {
        if (std.mem.eql(u8, mod, module_name)) return true;
    }
    return false;
}

pub fn nonRelativeModuleNameForTypingCache(module_name: []const u8) []const u8 {
    if (isNodeCoreModule(module_name)) return "node";
    return module_name;
}

const unprefixed_node_core_modules = [_][]const u8{
    "assert", "assert/strict", "async_hooks", "buffer", "child_process",
    "cluster", "console", "constants", "crypto", "dgram", "diagnostics_channel",
    "dns", "dns/promises", "domain", "events", "fs", "fs/promises",
    "http", "http2", "https", "inspector", "inspector/promises",
    "module", "net", "os", "path", "path/posix", "path/win32",
    "perf_hooks", "process", "punycode", "querystring", "readline",
    "readline/promises", "repl", "stream", "stream/consumers", "stream/promises",
    "stream/web", "string_decoder", "sys", "timers", "timers/promises",
    "tls", "trace_events", "tty", "url", "util", "util/types",
    "v8", "vm", "wasi", "worker_threads", "zlib",
};

const exclusively_prefixed_node_core_modules = [_][]const u8{
    "node:quic", "node:sea", "node:sqlite", "node:test", "node:test/reporters",
};

// === unorderedEqual (for backward compat) ===

pub fn unorderedEqual(comptime T: type, a: []const T, b: []const T) bool {
    if (a.len != b.len) return false;
    for (a) |item| {
        var found = false;
        for (b) |other| {
            if (item == other) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }
    return true;
}

// === IfElse (port of core.go IfElse) ===

pub fn IfElse(comptime T: type, condition: bool, true_val: T, false_val: T) T {
    return if (condition) true_val else false_val;
}
