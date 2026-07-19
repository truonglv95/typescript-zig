const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const EmitTextWriter = @import("emittextwriter.zig").EmitTextWriter;

pub const TextWriter = struct {
    newLine: []const u8,
    indentSize: usize,
    allocator: std.mem.Allocator,
    builder: std.ArrayListUnmanaged(u8),
    lastWritten: []const u8,
    indent: usize,
    lineStart: bool,
    lineCount: usize,
    linePos: usize,
    hasTrailingCommentState: bool,

    pub fn init(allocator: std.mem.Allocator, newLine: []const u8, indentSize: usize) TextWriter {
        const actualIndentSize = if (indentSize == 0) 4 else indentSize;
        return TextWriter{
            .newLine = newLine,
            .indentSize = actualIndentSize,
            .allocator = allocator,
            .builder = .empty,
            .lastWritten = "",
            .indent = 0,
            .lineStart = true,
            .lineCount = 0,
            .linePos = 0,
            .hasTrailingCommentState = false,
        };
    }

    pub fn deinit(self: *TextWriter) void {
        self.builder.deinit(self.allocator);
    }

    pub fn getEmitTextWriter(self: *TextWriter) EmitTextWriter {
        return EmitTextWriter{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    pub fn clear(self: *TextWriter) void {
        self.builder.clearRetainingCapacity();
        self.lastWritten = "";
        self.indent = 0;
        self.lineStart = true;
        self.lineCount = 0;
        self.linePos = 0;
        self.hasTrailingCommentState = false;
    }

    pub fn grow(self: *TextWriter, n: usize) !void {
        try self.builder.ensureUnusedCapacity(self.allocator, n);
    }

    pub fn decreaseIndent(self: *TextWriter) void {
        if (self.indent > 0) {
            self.indent -= 1;
        }
    }

    pub fn getColumn(self: *const TextWriter) usize {
        if (self.lineStart) {
            return self.indent * self.indentSize;
        }
        // Count bytes as an approximation of UTF-16 code units for now.
        return self.builder.items.len - self.linePos;
    }

    pub fn getIndent(self: *const TextWriter) usize {
        return self.indent;
    }

    pub fn getLine(self: *const TextWriter) usize {
        return self.lineCount;
    }

    pub fn string(self: *const TextWriter) []const u8 {
        return self.builder.items;
    }

    pub fn getTextPos(self: *const TextWriter) usize {
        return self.builder.items.len;
    }

    pub fn hasTrailingComment(self: *const TextWriter) bool {
        return self.hasTrailingCommentState;
    }

    pub fn hasTrailingWhitespace(self: *const TextWriter) bool {
        if (self.builder.items.len == 0) return false;
        if (self.lastWritten.len == 0) return false;
        const lastChar = self.lastWritten[self.lastWritten.len - 1];
        return std.ascii.isWhitespace(lastChar);
    }

    pub fn increaseIndent(self: *TextWriter) void {
        self.indent += 1;
    }

    pub fn isAtStartOfLine(self: *const TextWriter) bool {
        return self.lineStart;
    }

    pub fn rawWrite(self: *TextWriter, s: []const u8) void {
        if (s.len > 0) {
            self.builder.appendSlice(self.allocator, s) catch {};
            self.lastWritten = s;
            self.hasTrailingCommentState = false;
        }
        self.updateLineCountAndPosFor(s);
    }

    fn updateLineCountAndPosFor(self: *TextWriter, s: []const u8) void {
        var count: usize = 0;
        var lastLineStart: usize = 0;
        var i: usize = 0;
        
        while (i < s.len) {
            if (s[i] == '\n') {
                count += 1;
                lastLineStart = i + 1;
            } else if (s[i] == '\r') {
                if (i + 1 < s.len and s[i+1] == '\n') {
                    count += 1;
                    lastLineStart = i + 2;
                    i += 1;
                } else {
                    count += 1;
                    lastLineStart = i + 1;
                }
            }
            i += 1;
        }

        if (count > 0) {
            self.lineCount += count;
            const curLen = self.builder.items.len;
            self.linePos = curLen - s.len + lastLineStart;
            self.lineStart = (self.linePos == curLen);
            return;
        }
        self.lineStart = false;
    }

    fn getIndentString(self: *TextWriter) void {
        if (self.indent == 0) return;
        const totalSpaces = self.indent * self.indentSize;
        self.builder.appendNTimes(self.allocator, ' ', totalSpaces) catch {};
    }

    fn writeText(self: *TextWriter, s: []const u8) void {
        if (s.len > 0) {
            if (self.lineStart) {
                self.getIndentString();
                self.lineStart = false;
            }
            // Guard against aliasing: if `s` is anywhere within the builder's
            // allocated capacity, appending may either alias with the
            // destination range or be invalidated by growth. Copy to a
            // temporary buffer first.
            const items_ptr = @intFromPtr(self.builder.items.ptr);
            const cap_end = items_ptr + self.builder.capacity;
            const s_ptr = @intFromPtr(s.ptr);
            const s_end = s_ptr + s.len;
            if (s_ptr >= items_ptr and s_end <= cap_end) {
                var stack_buf: [256]u8 = undefined;
                if (s.len <= stack_buf.len) {
                    @memcpy(stack_buf[0..s.len], s);
                    self.builder.appendSlice(self.allocator, stack_buf[0..s.len]) catch {};
                } else {
                    const tmp = self.allocator.alloc(u8, s.len) catch return;
                    defer self.allocator.free(tmp);
                    @memcpy(tmp, s);
                    self.builder.appendSlice(self.allocator, tmp) catch {};
                }
            } else {
                self.builder.appendSlice(self.allocator, s) catch {};
            }
            self.lastWritten = s;
            self.updateLineCountAndPosFor(s);
        }
    }

    pub fn write(self: *TextWriter, s: []const u8) void {
        if (s.len > 0) {
            self.hasTrailingCommentState = false;
        }
        self.writeText(s);
    }

    pub fn writeComment(self: *TextWriter, text: []const u8) void {
        if (text.len > 0) {
            self.hasTrailingCommentState = true;
        }
        self.writeText(text);
    }

    pub fn writeKeyword(self: *TextWriter, text: []const u8) void {
        self.write(text);
    }

    fn writeLineRaw(self: *TextWriter) void {
        self.builder.appendSlice(self.allocator, self.newLine) catch {};
        self.lastWritten = self.newLine;
        self.lineCount += 1;
        self.linePos = self.builder.items.len;
        self.lineStart = true;
        self.hasTrailingCommentState = false;
    }

    pub fn writeLine(self: *TextWriter) void {
        if (!self.lineStart) {
            self.writeLineRaw();
        }
    }

    pub fn writeLineForce(self: *TextWriter, force: bool) void {
        if (!self.lineStart or force) {
            self.writeLineRaw();
        }
    }

    pub fn writeLiteral(self: *TextWriter, s: []const u8) void {
        self.write(s);
    }

    pub fn writeOperator(self: *TextWriter, text: []const u8) void {
        self.write(text);
    }

    pub fn writeParameter(self: *TextWriter, text: []const u8) void {
        self.write(text);
    }

    pub fn writeProperty(self: *TextWriter, text: []const u8) void {
        self.write(text);
    }

    pub fn writePunctuation(self: *TextWriter, text: []const u8) void {
        self.write(text);
    }

    pub fn writeSpace(self: *TextWriter, text: []const u8) void {
        self.write(text);
    }

    pub fn writeStringLiteral(self: *TextWriter, text: []const u8) void {
        self.write(text);
    }

    pub fn writeSymbol(self: *TextWriter, text: []const u8, symbol: ast_gen.SymbolIndex) void {
        _ = symbol;
        self.write(text);
    }

    pub fn writeTrailingSemicolon(self: *TextWriter, text: []const u8) void {
        self.write(text);
    }

    const vtable = EmitTextWriter.VTable{
        .write = struct { fn f(ptr: *anyopaque, s: []const u8) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).write(s); } }.f,
        .writeTrailingSemicolon = struct { fn f(ptr: *anyopaque, text: []const u8) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).writeTrailingSemicolon(text); } }.f,
        .writeComment = struct { fn f(ptr: *anyopaque, text: []const u8) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).writeComment(text); } }.f,
        .writeKeyword = struct { fn f(ptr: *anyopaque, text: []const u8) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).writeKeyword(text); } }.f,
        .writeOperator = struct { fn f(ptr: *anyopaque, text: []const u8) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).writeOperator(text); } }.f,
        .writePunctuation = struct { fn f(ptr: *anyopaque, text: []const u8) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).writePunctuation(text); } }.f,
        .writeSpace = struct { fn f(ptr: *anyopaque, text: []const u8) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).writeSpace(text); } }.f,
        .writeStringLiteral = struct { fn f(ptr: *anyopaque, text: []const u8) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).writeStringLiteral(text); } }.f,
        .writeParameter = struct { fn f(ptr: *anyopaque, text: []const u8) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).writeParameter(text); } }.f,
        .writeProperty = struct { fn f(ptr: *anyopaque, text: []const u8) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).writeProperty(text); } }.f,
        .writeSymbol = struct { fn f(ptr: *anyopaque, text: []const u8, symbol: ast_gen.SymbolIndex) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).writeSymbol(text, symbol); } }.f,
        .writeLine = struct { fn f(ptr: *anyopaque) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).writeLine(); } }.f,
        .writeLineForce = struct { fn f(ptr: *anyopaque, force: bool) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).writeLineForce(force); } }.f,
        .increaseIndent = struct { fn f(ptr: *anyopaque) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).increaseIndent(); } }.f,
        .decreaseIndent = struct { fn f(ptr: *anyopaque) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).decreaseIndent(); } }.f,
        .clear = struct { fn f(ptr: *anyopaque) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).clear(); } }.f,
        .string = struct { fn f(ptr: *anyopaque) []const u8 { return @as(*TextWriter, @ptrCast(@alignCast(ptr))).string(); } }.f,
        .rawWrite = struct { fn f(ptr: *anyopaque, s: []const u8) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).rawWrite(s); } }.f,
        .writeLiteral = struct { fn f(ptr: *anyopaque, s: []const u8) void { @as(*TextWriter, @ptrCast(@alignCast(ptr))).writeLiteral(s); } }.f,
        .getTextPos = struct { fn f(ptr: *anyopaque) usize { return @as(*TextWriter, @ptrCast(@alignCast(ptr))).getTextPos(); } }.f,
        .getLine = struct { fn f(ptr: *anyopaque) usize { return @as(*TextWriter, @ptrCast(@alignCast(ptr))).getLine(); } }.f,
        .getColumn = struct { fn f(ptr: *anyopaque) usize { return @as(*TextWriter, @ptrCast(@alignCast(ptr))).getColumn(); } }.f,
        .getIndent = struct { fn f(ptr: *anyopaque) usize { return @as(*TextWriter, @ptrCast(@alignCast(ptr))).getIndent(); } }.f,
        .isAtStartOfLine = struct { fn f(ptr: *anyopaque) bool { return @as(*TextWriter, @ptrCast(@alignCast(ptr))).isAtStartOfLine(); } }.f,
        .hasTrailingComment = struct { fn f(ptr: *anyopaque) bool { return @as(*TextWriter, @ptrCast(@alignCast(ptr))).hasTrailingComment(); } }.f,
        .hasTrailingWhitespace = struct { fn f(ptr: *anyopaque) bool { return @as(*TextWriter, @ptrCast(@alignCast(ptr))).hasTrailingWhitespace(); } }.f,
    };
};
