//! Display parts writer — captures classified text for hover/signature help.
//!
//! Port of `internal/ls/displaypartswriter.go` (217 LOC).
//!
//! Implements a text writer that captures classified text runs for VS Code
//! colorized labels while also building a plain string. When VS capability
//! is false, only the plain string is built.
const std = @import("std");


/// A classified text run (for VS Code colorized hover).
pub const VSClassifiedTextRun = struct {
    classification_type_name: []const u8,
    text: []const u8,
};

/// Classification type names for VS Code.
pub const ClassificationTypeName = enum {
    text,
    keyword,
    class_name,
    enum_name,
    interface_name,
    module_name,
    type_parameter_name,
    parameter_name,
    property,
    enum_member,
    function_name,
    method_name,
    field_name,
    local_name,
    namespace_name,
    operator,
    punctuation,
    string,
    number,
    comment,
    type_alias,
    label,

    pub fn toString(self: ClassificationTypeName) []const u8 {
        return @tagName(self);
    }
};

/// A display parts writer that captures classified text runs.
/// Port of Go's `displayPartsWriter`.
pub const DisplayPartsWriter = struct {
    builder: std.ArrayList(u8),
    runs: std.ArrayListUnmanaged(VSClassifiedTextRun),
    vs_capability: bool,
    last_written: []const u8 = "",
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, vs_capability: bool) DisplayPartsWriter {
        return .{
            .builder = std.ArrayList(u8).empty,
            .runs = .empty,
            .vs_capability = vs_capability,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DisplayPartsWriter) void {
        self.builder.deinit(self.allocator);
        self.runs.deinit(self.allocator);
    }

    /// Adds a classified text run.
    fn addRun(self: *DisplayPartsWriter, classification: ClassificationTypeName, text: []const u8) void {
        if (text.len == 0) return;
        if (self.vs_capability) {
            self.runs.append(self.allocator, .{
                .classification_type_name = classification.toString(),
                .text = text,
            }) catch {};
        }
        self.last_written = text;
        self.builder.appendSlice(self.allocator, text) catch {};
    }

    /// Writes text with an explicit classification type.
    pub fn writeClassified(self: *DisplayPartsWriter, text: []const u8, classification: ClassificationTypeName) void {
        self.addRun(classification, text);
    }

    /// Writes plain text (no classification).
    pub fn write(self: *DisplayPartsWriter, text: []const u8) void {
        self.writeClassified(text, .text);
    }

    /// Writes a keyword.
    pub fn writeKeyword(self: *DisplayPartsWriter, text: []const u8) void {
        self.writeClassified(text, .keyword);
    }

    /// Writes a type name (class, interface, enum, etc.).
    pub fn writeType(self: *DisplayPartsWriter, text: []const u8) void {
        self.writeClassified(text, .class_name);
    }

    /// Writes a parameter name.
    pub fn writeParameter(self: *DisplayPartsWriter, text: []const u8) void {
        self.writeClassified(text, .parameter_name);
    }

    /// Writes a function/method name.
    pub fn writeFunction(self: *DisplayPartsWriter, text: []const u8) void {
        self.writeClassified(text, .function_name);
    }

    /// Writes a property/field name.
    pub fn writeProperty(self: *DisplayPartsWriter, text: []const u8) void {
        self.writeClassified(text, .property);
    }

    /// Writes punctuation (parentheses, commas, etc.).
    pub fn writePunctuation(self: *DisplayPartsWriter, text: []const u8) void {
        self.writeClassified(text, .punctuation);
    }

    /// Writes a space.
    pub fn writeSpace(self: *DisplayPartsWriter) void {
        self.write(" ");
    }

    /// Gets the accumulated plain string.
    pub fn string(self: *const DisplayPartsWriter) []const u8 {
        return self.builder.items;
    }

    /// Gets the classified text runs.
    pub fn getRuns(self: *const DisplayPartsWriter) []const VSClassifiedTextRun {
        return self.runs.items;
    }

    /// Clears all accumulated content.
    pub fn clear(self: *DisplayPartsWriter) void {
        self.builder.clearRetainingCapacity();
        self.runs.clearRetainingCapacity();
        self.last_written = "";
    }

    /// Copies content from another writer.
    pub fn writeFrom(self: *DisplayPartsWriter, other: *const DisplayPartsWriter) void {
        self.builder.appendSlice(self.allocator, other.string()) catch {};
        if (self.vs_capability) {
            self.runs.appendSlice(self.allocator, other.getRuns()) catch {};
        }
        if (other.last_written.len > 0) {
            self.last_written = other.last_written;
        }
    }
};
