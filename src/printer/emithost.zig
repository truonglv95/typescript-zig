const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");

const core = @import("../core/core.zig");

// Placeholders for types that are not yet fully ported.
pub const CompilerOptions = core.CompilerOptions;
pub const ModuleKind = u32;
pub const Path = []const u8;
pub const SourceOutputAndProjectReference = opaque {};
pub const EmitResolver = @import("emitresolver.zig").EmitResolver;

pub const EmitHost = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        options: *const fn (ptr: *anyopaque) *CompilerOptions,
        sourceFiles: *const fn (ptr: *anyopaque) []const ast_gen.NodeIndex,
        useCaseSensitiveFileNames: *const fn (ptr: *anyopaque) bool,
        getCurrentDirectory: *const fn (ptr: *anyopaque) []const u8,
        commonSourceDirectory: *const fn (ptr: *anyopaque) []const u8,
        isEmitBlocked: *const fn (ptr: *anyopaque, file: []const u8) bool,
        writeFile: *const fn (ptr: *anyopaque, fileName: []const u8, text: []const u8) anyerror!void,
        getEmitModuleFormatOfFile: *const fn (ptr: *anyopaque, file: ast_gen.NodeIndex) ModuleKind,
        getEmitResolver: *const fn (ptr: *anyopaque) *EmitResolver,
        getProjectReferenceFromSource: *const fn (ptr: *anyopaque, path: Path) ?*SourceOutputAndProjectReference,
        isSourceFileFromExternalLibrary: *const fn (ptr: *anyopaque, file: ast_gen.NodeIndex) bool,
    };

    pub inline fn options(self: EmitHost) *CompilerOptions {
        return self.vtable.options(self.ptr);
    }

    pub inline fn sourceFiles(self: EmitHost) []const ast_gen.NodeIndex {
        return self.vtable.sourceFiles(self.ptr);
    }

    pub inline fn useCaseSensitiveFileNames(self: EmitHost) bool {
        return self.vtable.useCaseSensitiveFileNames(self.ptr);
    }

    pub inline fn getCurrentDirectory(self: EmitHost) []const u8 {
        return self.vtable.getCurrentDirectory(self.ptr);
    }

    pub inline fn commonSourceDirectory(self: EmitHost) []const u8 {
        return self.vtable.commonSourceDirectory(self.ptr);
    }

    pub inline fn isEmitBlocked(self: EmitHost, file: []const u8) bool {
        return self.vtable.isEmitBlocked(self.ptr, file);
    }

    pub inline fn writeFile(self: EmitHost, fileName: []const u8, text: []const u8) anyerror!void {
        return self.vtable.writeFile(self.ptr, fileName, text);
    }

    pub inline fn getEmitModuleFormatOfFile(self: EmitHost, file: ast_gen.NodeIndex) ModuleKind {
        return self.vtable.getEmitModuleFormatOfFile(self.ptr, file);
    }

    pub inline fn getEmitResolver(self: EmitHost) *EmitResolver {
        return self.vtable.getEmitResolver(self.ptr);
    }

    pub inline fn getProjectReferenceFromSource(self: EmitHost, path: Path) ?*SourceOutputAndProjectReference {
        return self.vtable.getProjectReferenceFromSource(self.ptr, path);
    }

    pub inline fn isSourceFileFromExternalLibrary(self: EmitHost, file: ast_gen.NodeIndex) bool {
        return self.vtable.isSourceFileFromExternalLibrary(self.ptr, file);
    }
};
