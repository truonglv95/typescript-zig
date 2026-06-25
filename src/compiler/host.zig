const std = @import("std");
const ast = @import("../ast/ast.zig");
const core = @import("../core/core.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const parser = @import("../parser/parser.zig");
const tsoptions = @import("../tsoptions/tsoptions.zig");
const tspath = @import("../tspath/tspath.zig");
const vfs = @import("../vfs/vfs.zig");
const cachedvfs = @import("../vfs/cachedvfs.zig");

pub const CompilerHost = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        fs: *const fn (ptr: *anyopaque) *vfs.FS,
        defaultLibraryPath: *const fn (ptr: *anyopaque) []const u8,
        getCurrentDirectory: *const fn (ptr: *anyopaque) []const u8,
        trace: *const fn (ptr: *anyopaque, msg: *const diagnostics.Message, args: [][]const u8) void,
        getSourceFile: *const fn (ptr: *anyopaque, opts: ast.SourceFileParseOptions) ?ast.NodeIndex,
        getResolvedProjectReference: *const fn (ptr: *anyopaque, fileName: []const u8, path: tspath.Path) ?*tsoptions.ParsedCommandLine,
    };

    pub fn fs(self: CompilerHost) *vfs.FS {
        return self.vtable.fs(self.ptr);
    }
    pub fn defaultLibraryPath(self: CompilerHost) []const u8 {
        return self.vtable.defaultLibraryPath(self.ptr);
    }
    pub fn getCurrentDirectory(self: CompilerHost) []const u8 {
        return self.vtable.getCurrentDirectory(self.ptr);
    }
    pub fn trace(self: CompilerHost, msg: *const diagnostics.Message, args: [][]const u8) void {
        return self.vtable.trace(self.ptr, msg, args);
    }
    pub fn getSourceFile(self: CompilerHost, opts: ast.SourceFileParseOptions) ?ast.NodeIndex {
        return self.vtable.getSourceFile(self.ptr, opts);
    }
    pub fn getResolvedProjectReference(self: CompilerHost, fileName: []const u8, path: tspath.Path) ?*tsoptions.ParsedCommandLine {
        return self.vtable.getResolvedProjectReference(self.ptr, fileName, path);
    }
};

pub const CompilerHostImpl = struct {
    currentDirectory: []const u8,
    fs_val: *vfs.FS,
    defaultLibraryPath_val: []const u8,
    extendedConfigCache: *tsoptions.ExtendedConfigCache,
    traceFn: ?*const fn (msg: *const diagnostics.Message, args: [][]const u8) void,

    pub fn newCachedFSCompilerHost(
        allocator: std.mem.Allocator,
        currentDirectory: []const u8,
        fs_impl: *vfs.FS,
        defaultLibraryPath_param: []const u8,
        extendedConfigCache: *tsoptions.ExtendedConfigCache,
        traceFn: ?*const fn (msg: *const diagnostics.Message, args: [][]const u8) void,
    ) *CompilerHostImpl {
        return newCompilerHost(allocator, currentDirectory, cachedvfs.from(allocator, fs_impl), defaultLibraryPath_param, extendedConfigCache, traceFn);
    }

    pub fn newCompilerHost(
        allocator: std.mem.Allocator,
        currentDirectory: []const u8,
        fs_impl: *vfs.FS,
        defaultLibraryPath_param: []const u8,
        extendedConfigCache: *tsoptions.ExtendedConfigCache,
        traceFn: ?*const fn (msg: *const diagnostics.Message, args: [][]const u8) void,
    ) *CompilerHostImpl {
        const host = allocator.create(CompilerHostImpl) catch unreachable;
        host.* = .{
            .currentDirectory = currentDirectory,
            .fs_val = fs_impl,
            .defaultLibraryPath_val = defaultLibraryPath_param,
            .extendedConfigCache = extendedConfigCache,
            .traceFn = traceFn,
        };
        return host;
    }

    pub fn fs(ptr: *anyopaque) *vfs.FS {
        const self: *CompilerHostImpl = @ptrCast(@alignCast(ptr));
        return self.fs_val;
    }

    pub fn defaultLibraryPath(ptr: *anyopaque) []const u8 {
        const self: *CompilerHostImpl = @ptrCast(@alignCast(ptr));
        return self.defaultLibraryPath_val;
    }

    pub fn getCurrentDirectory(ptr: *anyopaque) []const u8 {
        const self: *CompilerHostImpl = @ptrCast(@alignCast(ptr));
        return self.currentDirectory;
    }

    pub fn trace(ptr: *anyopaque, msg: *const diagnostics.Message, args: [][]const u8) void {
        const self: *CompilerHostImpl = @ptrCast(@alignCast(ptr));
        if (self.traceFn) |t| {
            t(msg, args);
        }
    }

    pub fn getSourceFile(ptr: *anyopaque, opts: ast.SourceFileParseOptions) ?ast.NodeIndex {
        const self: *CompilerHostImpl = @ptrCast(@alignCast(ptr));
        const text = self.fs_val.readFile(opts.fileName) orelse return null;
        return parser.parseSourceFile(opts, text, core.getScriptKindFromFileName(opts.fileName));
    }

    pub fn getResolvedProjectReference(ptr: *anyopaque, fileName: []const u8, path: tspath.Path) ?*tsoptions.ParsedCommandLine {
        const self: *CompilerHostImpl = @ptrCast(@alignCast(ptr));
        const commandLine = tsoptions.getParsedCommandLineOfConfigFilePath(fileName, path, null, null, self.compilerHost(), self.extendedConfigCache);
        return commandLine;
    }

    const vtable = CompilerHost.VTable{
        .fs = fs,
        .defaultLibraryPath = defaultLibraryPath,
        .getCurrentDirectory = getCurrentDirectory,
        .trace = trace,
        .getSourceFile = getSourceFile,
        .getResolvedProjectReference = getResolvedProjectReference,
    };

    pub fn compilerHost(self: *CompilerHostImpl) CompilerHost {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }
};
