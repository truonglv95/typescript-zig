const std = @import("std");

//! Text change tracker — records edits to source files.
//!
//! Port of `internal/ls/change/tracker.go` (751 LOC).
//!
//! The change tracker accumulates text edits (insertions, deletions,
//! replacements) and produces `TextEdit` arrays for LSP responses.

const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");

/// Leading trivia option.
pub const LeadingTriviaOption = enum(u8) {
    None = 0,
    Exclude = 1,
    IncludeAll = 2,
    JSDoc = 3,
    StartLine = 4,
};

/// Trailing trivia option.
pub const TrailingTriviaOption = enum(u8) {
    None = 0,
    Exclude = 1,
    ExcludeWhitespace = 2,
    Include = 3,
};

/// Options for inserting/replacing a node.
pub const NodeOptions = struct {
    prefix: []const u8 = "",
    suffix: []const u8 = "",
    indentation: ?u32 = null,
    delta: ?i32 = null,
    leading_trivia_option: LeadingTriviaOption = .None,
    trailing_trivia_option: TrailingTriviaOption = .None,
    joiner: []const u8 = "",
};

/// The kind of tracker edit.
pub const TrackerEditKind = enum(u8) {
    Text = 1,
    Remove = 2,
    ReplaceWithSingleNode = 3,
    ReplaceWithMultipleNodes = 4,
};

/// A text range (start line/char to end line/char).
pub const Range = struct {
    start: Position,
    end: Position,
    pub const Position = struct { line: u32, character: u32 };
};

/// A single tracker edit.
pub const TrackerEdit = struct {
    kind: TrackerEditKind,
    range: Range,
    new_text: []const u8 = "",
    node: ast_gen.NodeIndex = 0,
    nodes: []const ast_gen.NodeIndex = &.{},
    options: NodeOptions = .{},
};

/// The change tracker.
pub const ChangeTracker = struct {
    edits: std.ArrayListUnmanaged(TrackerEdit) = .empty,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ChangeTracker {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *ChangeTracker) void {
        self.edits.deinit(self.allocator);
    }

    pub fn insertText(self: *ChangeTracker, range: Range, new_text: []const u8) void {
        self.edits.append(self.allocator, .{ .kind = .Text, .range = range, .new_text = new_text }) catch {};
    }

    pub fn deleteRange(self: *ChangeTracker, range: Range) void {
        self.edits.append(self.allocator, .{ .kind = .Remove, .range = range }) catch {};
    }

    pub fn replaceWithNode(self: *ChangeTracker, range: Range, node: ast_gen.NodeIndex, options: NodeOptions) void {
        self.edits.append(self.allocator, .{ .kind = .ReplaceWithSingleNode, .range = range, .node = node, .options = options }) catch {};
    }

    pub fn replaceWithNodes(self: *ChangeTracker, range: Range, nodes: []const ast_gen.NodeIndex, options: NodeOptions) void {
        self.edits.append(self.allocator, .{ .kind = .ReplaceWithMultipleNodes, .range = range, .nodes = nodes, .options = options }) catch {};
    }

    pub fn getEdits(self: *const ChangeTracker) []const TrackerEdit {
        return self.edits.items;
    }

    pub fn hasChanges(self: *const ChangeTracker) bool {
        return self.edits.items.len > 0;
    }
};
