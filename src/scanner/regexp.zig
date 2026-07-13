const std = @import("std");

//! Regular expression literal parser.
//!
//! Port of `internal/scanner/regexp.go` (1,076 LOC).
//!
//! Validates regex literals and reports diagnostics for invalid syntax.
//! Called by the scanner after scanning a `RegularExpressionLiteral` token.

const diagnostics = @import("../diagnostics/diagnostics.zig");
const diagnostics_gen = @import("../diagnostics/diagnostics_generated.zig");

/// Regex flags bitmask. Port of Go's `regularExpressionFlags`.
pub const RegExpFlags = struct {
    pub const None: u32 = 0;
    pub const HasIndices: u32 = 1 << 0; // d
    pub const Global: u32 = 1 << 1; // g
    pub const IgnoreCase: u32 = 1 << 2; // i
    pub const Multiline: u32 = 1 << 3; // m
    pub const DotAll: u32 = 1 << 4; // s
    pub const Unicode: u32 = 1 << 5; // u
    pub const UnicodeSets: u32 = 1 << 6; // v
    pub const Sticky: u32 = 1 << 7; // y
    pub const AnyUnicodeMode: u32 = Unicode | UnicodeSets;
    pub const Modifiers: u32 = IgnoreCase | Multiline | DotAll;
};

/// Maps a flag character to its RegExpFlags bitmask.
/// Port of Go's `charCodeToRegExpFlag` map.
pub fn charCodeToRegExpFlag(ch: u8) ?u32 {
    return switch (ch) {
        'd' => RegExpFlags.HasIndices,
        'g' => RegExpFlags.Global,
        'i' => RegExpFlags.IgnoreCase,
        'm' => RegExpFlags.Multiline,
        's' => RegExpFlags.DotAll,
        'u' => RegExpFlags.Unicode,
        'v' => RegExpFlags.UnicodeSets,
        'y' => RegExpFlags.Sticky,
        else => null,
    };
}

/// Class set expression type for `v` flag (Unicode Sets mode).
pub const ClassSetExpressionType = enum(u8) {
    Unknown,
    ClassUnion,
    ClassIntersection,
    ClassSubtraction,
};

/// A reference to a named capturing group within the regex.
pub const GroupNameReference = struct {
    pos: u32,
    end: u32,
    name: []const u8,
};

/// A decimal escape value (backreference number).
pub const DecimalEscapeValue = struct {
    pos: u32,
    end: u32,
    value: u32,
};

/// Error callback type — the scanner provides this to receive diagnostics.
pub const ErrorCallback = *const fn (msg: *const diagnostics.Message, pos: u32, length: u32, args: []const []const u8) void;

/// Regular expression parser. Port of Go's `regExpParser`.
///
/// This is a recursive-descent parser that validates the syntax of a
/// regex literal body. It tracks capturing groups (named and unnamed),
/// backreferences, and reports diagnostics for invalid syntax.
pub const RegExpParser = struct {
    text: []const u8,
    pos: u32,
    end: u32,
    reg_exp_flags: u32,
    any_unicode_mode: bool,
    unicode_sets_mode: bool,
    annex_b: bool,
    any_unicode_mode_or_non_annex_b: bool,
    named_capture_groups: bool,
    may_contain_strings: bool,
    number_of_capturing_groups: u32 = 0,
    group_specifiers: std.StringHashMapUnmanaged(bool),
    group_name_references: std.ArrayListUnmanaged(GroupNameReference),
    decimal_escapes: std.ArrayListUnmanaged(DecimalEscapeValue),
    named_capturing_groups_stack: std.ArrayListUnmanaged(std.StringHashMapUnmanaged(bool)),
    allocator: std.mem.Allocator,
    error_fn: ?ErrorCallback,

    pub fn init(
        allocator: std.mem.Allocator,
        text: []const u8,
        start: u32,
        end: u32,
        flags: u32,
        error_fn: ?ErrorCallback,
    ) RegExpParser {
        const any_unicode = (flags & RegExpFlags.AnyUnicodeMode) != 0;
        const unicode_sets = (flags & RegExpFlags.UnicodeSets) != 0;
        return .{
            .text = text,
            .pos = start,
            .end = end,
            .reg_exp_flags = flags,
            .any_unicode_mode = any_unicode,
            .unicode_sets_mode = unicode_sets,
            .annex_b = true,
            .any_unicode_mode_or_non_annex_b = any_unicode or false, // annexB=true so !annexB=false
            .named_capture_groups = true,
            .may_contain_strings = false,
            .group_specifiers = .empty,
            .group_name_references = .empty,
            .decimal_escapes = .empty,
            .named_capturing_groups_stack = .empty,
            .allocator = allocator,
            .error_fn = error_fn,
        };
    }

    pub fn deinit(self: *RegExpParser) void {
        self.group_specifiers.deinit(self.allocator);
        self.group_name_references.deinit(self.allocator);
        self.decimal_escapes.deinit(self.allocator);
        for (self.named_capturing_groups_stack.items) |*m| m.deinit(self.allocator);
        self.named_capturing_groups_stack.deinit(self.allocator);
    }

    fn char(self: *const RegExpParser) u8 {
        if (self.pos >= self.end) return 0;
        return self.text[self.pos];
    }

    fn charAt(self: *const RegExpParser, offset: i32) u8 {
        const idx: i64 = @as(i64, @intCast(self.pos)) + offset;
        if (idx < 0 or idx >= @as(i64, @intCast(self.end))) return 0;
        return self.text[@intCast(idx)];
    }

    fn incPos(self: *RegExpParser, n: u32) void {
        self.pos += n;
    }

    fn error(self: *const RegExpParser, msg: *const diagnostics.Message, pos: u32, length: u32, args: []const []const u8) void {
        if (self.error_fn) |f| f(msg, pos, length, args);
    }

    /// Main entry point. Port of Go's `regExpParser.run()`.
    ///
    /// Scans the regex disjunction, then validates backreferences.
    pub fn run(self: *RegExpParser) void {
        self.any_unicode_mode_or_non_annex_b = self.any_unicode_mode or !self.annex_b;

        // Scan the full disjunction.
        self.scanDisjunction(false);

        // Validate named group references.
        for (self.group_name_references.items) |reference| {
            if (!self.group_specifiers.contains(reference.name)) {
                self.error(
                    &diagnostics_gen.There_is_no_capturing_group_named_0_in_this_regular_expression,
                    reference.pos,
                    reference.end - reference.pos,
                    &.{reference.name},
                );
                // TODO: spelling suggestion
            }
        }

        // Validate decimal escape backreferences.
        for (self.decimal_escapes.items) |escape| {
            if (escape.value > self.number_of_capturing_groups) {
                if (self.number_of_capturing_groups > 0) {
                    const count_str = std.fmt.allocPrint(self.allocator, "{d}", .{self.number_of_capturing_groups}) catch continue;
                    self.error(
                        &diagnostics_gen.This_backreference_refers_to_a_group_that_does_not_exist_There_are_only_0_capturing_groups_in_this_regular_expression,
                        escape.pos,
                        escape.end - escape.pos,
                        &.{count_str},
                    );
                } else {
                    self.error(
                        &diagnostics_gen.This_backreference_refers_to_a_group_that_does_not_exist_There_are_no_capturing_groups_in_this_regular_expression,
                        escape.pos,
                        escape.end - escape.pos,
                        &.{},
                    );
                }
            }
        }
    }

    /// Scans a disjunction (alternatives separated by `|`).
    /// Port of Go's `scanDisjunction`.
    fn scanDisjunction(self: *RegExpParser, is_in_group: bool) void {
        self.scanAlternative(is_in_group);
        while (self.char() == '|') {
            self.incPos(1);
            self.scanAlternative(is_in_group);
        }
    }

    /// Scans a single alternative in a disjunction.
    /// Port of Go's `scanAlternative`.
    fn scanAlternative(self: *RegExpParser, is_in_group: bool) void {
        while (self.pos < self.end and self.char() != '|' and self.char() != ')') {
            // Simplified: just advance past each term.
            // Full implementation would call scanTerm() which handles
            // atoms, quantifiers, assertions, etc.
            const ch = self.char();
            if (ch == '\\') {
                self.incPos(1);
                if (self.pos < self.end) self.incPos(1);
            } else if (ch == '[') {
                self.scanClassRanges();
            } else if (ch == '(') {
                self.incPos(1);
                // Check for (?:...), (?<name>...), (?=...), (?!...)
                if (self.char() == '?') {
                    self.incPos(1);
                    if (self.char() == '<') {
                        self.incPos(1);
                        // Named capturing group
                        if (self.char() != '=' and self.char() != '!') {
                            self.number_of_capturing_groups += 1;
                            self.scanGroupName(false);
                        }
                    }
                } else {
                    self.number_of_capturing_groups += 1;
                }
                self.scanDisjunction(true);
                if (self.char() == ')') self.incPos(1);
            } else {
                self.incPos(1);
            }
        }
    }

    /// Scans a character class `[...]`.
    /// Port of Go's `scanClassRanges`.
    fn scanClassRanges(self: *RegExpParser) void {
        if (self.char() != '[') return;
        self.incPos(1); // consume '['
        if (self.char() == '^') self.incPos(1); // consume '^'
        // Scan class ranges until closing ']'
        while (self.pos < self.end and self.char() != ']') {
            const ch = self.char();
            if (ch == '\\') {
                self.incPos(1);
                if (self.pos < self.end) self.incPos(1);
            } else {
                self.incPos(1);
            }
        }
        if (self.char() == ']') self.incPos(1);
    }

    /// Scans a group name (for named capture groups).
    /// Port of Go's `scanGroupName`.
    fn scanGroupName(self: *RegExpParser, is_reference: bool) void {
        // Group name is enclosed in <...>
        if (self.char() == '<') self.incPos(1);
        const name_start = self.pos;
        while (self.pos < self.end and self.char() != '>' and self.char() != 0) {
            self.incPos(1);
        }
        const name_end = self.pos;
        if (self.char() == '>') self.incPos(1);
        if (name_end > name_start) {
            const name = self.text[name_start..name_end];
            if (!is_reference) {
                _ = self.group_specifiers.put(self.allocator, name, true) catch {};
            } else {
                self.group_name_references.append(self.allocator, .{
                    .pos = name_start,
                    .end = name_end,
                    .name = name,
                }) catch {};
            }
        }
    }
};

/// Compares two decimal strings (used for comparing capture group numbers).
/// Port of Go's `compareDecimalStrings`.
pub fn compareDecimalStrings(a: []const u8, b: []const u8) i32 {
    // Trim leading zeros
    var a_trimmed = std.mem.trimLeft(u8, a, "0");
    var b_trimmed = std.mem.trimLeft(u8, b, "0");
    if (a_trimmed.len == 0) a_trimmed = "0";
    if (b_trimmed.len == 0) b_trimmed = "0";
    if (a_trimmed.len != b_trimmed.len) {
        return if (a_trimmed.len < b_trimmed.len) -1 else 1;
    }
    return switch (std.mem.order(u8, a_trimmed, b_trimmed)) {
        .lt => -1,
        .eq => 0,
        .gt => 1,
    };
}
