const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");

pub const EmitTextWriter = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        write: *const fn (ptr: *anyopaque, s: []const u8) void,
        writeTrailingSemicolon: *const fn (ptr: *anyopaque, text: []const u8) void,
        writeComment: *const fn (ptr: *anyopaque, text: []const u8) void,
        writeKeyword: *const fn (ptr: *anyopaque, text: []const u8) void,
        writeOperator: *const fn (ptr: *anyopaque, text: []const u8) void,
        writePunctuation: *const fn (ptr: *anyopaque, text: []const u8) void,
        writeSpace: *const fn (ptr: *anyopaque, text: []const u8) void,
        writeStringLiteral: *const fn (ptr: *anyopaque, text: []const u8) void,
        writeParameter: *const fn (ptr: *anyopaque, text: []const u8) void,
        writeProperty: *const fn (ptr: *anyopaque, text: []const u8) void,
        writeSymbol: *const fn (ptr: *anyopaque, text: []const u8, symbol: ast_gen.SymbolIndex) void,
        writeLine: *const fn (ptr: *anyopaque) void,
        writeLineForce: *const fn (ptr: *anyopaque, force: bool) void,
        increaseIndent: *const fn (ptr: *anyopaque) void,
        decreaseIndent: *const fn (ptr: *anyopaque) void,
        clear: *const fn (ptr: *anyopaque) void,
        string: *const fn (ptr: *anyopaque) []const u8,
        rawWrite: *const fn (ptr: *anyopaque, s: []const u8) void,
        writeLiteral: *const fn (ptr: *anyopaque, s: []const u8) void,
        getTextPos: *const fn (ptr: *anyopaque) usize,
        getLine: *const fn (ptr: *anyopaque) usize,
        getColumn: *const fn (ptr: *anyopaque) usize,
        getIndent: *const fn (ptr: *anyopaque) usize,
        isAtStartOfLine: *const fn (ptr: *anyopaque) bool,
        hasTrailingComment: *const fn (ptr: *anyopaque) bool,
        hasTrailingWhitespace: *const fn (ptr: *anyopaque) bool,
    };

    pub inline fn write(self: EmitTextWriter, s: []const u8) void {
        self.vtable.write(self.ptr, s);
    }

    pub inline fn writeTrailingSemicolon(self: EmitTextWriter, text: []const u8) void {
        self.vtable.writeTrailingSemicolon(self.ptr, text);
    }

    pub inline fn writeComment(self: EmitTextWriter, text: []const u8) void {
        self.vtable.writeComment(self.ptr, text);
    }

    pub inline fn writeKeyword(self: EmitTextWriter, text: []const u8) void {
        self.vtable.writeKeyword(self.ptr, text);
    }

    pub inline fn writeOperator(self: EmitTextWriter, text: []const u8) void {
        self.vtable.writeOperator(self.ptr, text);
    }

    pub inline fn writePunctuation(self: EmitTextWriter, text: []const u8) void {
        self.vtable.writePunctuation(self.ptr, text);
    }

    pub inline fn writeSpace(self: EmitTextWriter, text: []const u8) void {
        self.vtable.writeSpace(self.ptr, text);
    }

    pub inline fn writeStringLiteral(self: EmitTextWriter, text: []const u8) void {
        self.vtable.writeStringLiteral(self.ptr, text);
    }

    pub inline fn writeParameter(self: EmitTextWriter, text: []const u8) void {
        self.vtable.writeParameter(self.ptr, text);
    }

    pub inline fn writeProperty(self: EmitTextWriter, text: []const u8) void {
        self.vtable.writeProperty(self.ptr, text);
    }

    pub inline fn writeSymbol(self: EmitTextWriter, text: []const u8, symbol: ast_gen.SymbolIndex) void {
        self.vtable.writeSymbol(self.ptr, text, symbol);
    }

    pub inline fn writeLine(self: EmitTextWriter) void {
        self.vtable.writeLine(self.ptr);
    }

    pub inline fn writeLineForce(self: EmitTextWriter, force: bool) void {
        self.vtable.writeLineForce(self.ptr, force);
    }

    pub inline fn increaseIndent(self: EmitTextWriter) void {
        self.vtable.increaseIndent(self.ptr);
    }

    pub inline fn decreaseIndent(self: EmitTextWriter) void {
        self.vtable.decreaseIndent(self.ptr);
    }

    pub inline fn clear(self: EmitTextWriter) void {
        self.vtable.clear(self.ptr);
    }

    pub inline fn string(self: EmitTextWriter) []const u8 {
        return self.vtable.string(self.ptr);
    }

    pub inline fn rawWrite(self: EmitTextWriter, s: []const u8) void {
        self.vtable.rawWrite(self.ptr, s);
    }

    pub inline fn writeLiteral(self: EmitTextWriter, s: []const u8) void {
        self.vtable.writeLiteral(self.ptr, s);
    }

    pub inline fn getTextPos(self: EmitTextWriter) usize {
        return self.vtable.getTextPos(self.ptr);
    }

    pub inline fn getLine(self: EmitTextWriter) usize {
        return self.vtable.getLine(self.ptr);
    }

    pub inline fn getColumn(self: EmitTextWriter) usize {
        return self.vtable.getColumn(self.ptr);
    }

    pub inline fn getIndent(self: EmitTextWriter) usize {
        return self.vtable.getIndent(self.ptr);
    }

    pub inline fn isAtStartOfLine(self: EmitTextWriter) bool {
        return self.vtable.isAtStartOfLine(self.ptr);
    }

    pub inline fn hasTrailingComment(self: EmitTextWriter) bool {
        return self.vtable.hasTrailingComment(self.ptr);
    }

    pub inline fn hasTrailingWhitespace(self: EmitTextWriter) bool {
        return self.vtable.hasTrailingWhitespace(self.ptr);
    }
};
