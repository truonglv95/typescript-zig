const std = @import("std");
const ast_pkg = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const ast_utils = @import("../../ast/ast_utils.zig");
const collections = @import("../../collections/collections.zig");
const core = @import("../../core/core.zig");
const module = @import("../../module/module.zig");
const modulespecifiers = @import("../../modulespecifiers/modulespecifiers.zig");
const packagejson = @import("../../packagejson/packagejson.zig");
const tspath = @import("../../tspath/tspath.zig");
const vfs = @import("../../vfs/vfs.zig");
const checker = @import("../../checker/checker.zig");
const compiler = @import("../../compiler/program.zig");

pub const ModuleID = []const u8;

pub fn tryGetModuleIDAndFileNameOfModuleSymbol(ast: *ast_pkg.Ast, symbol: ast_gen.SymbolIndex) ?struct { module_id: ModuleID, file_name: []const u8 } {
    _ = ast;
    _ = symbol;
    @panic("TODO: tryGetModuleIDAndFileNameOfModuleSymbol");
}

pub fn getModuleIDAndFileNameOfModuleSymbol(ast: *ast_pkg.Ast, symbol: ast_gen.SymbolIndex) struct { module_id: ModuleID, file_name: []const u8 } {
    _ = ast;
    _ = symbol;
    @panic("TODO: getModuleIDAndFileNameOfModuleSymbol");
}

pub fn wordIndices(allocator: std.mem.Allocator, s: []const u8) ![]usize {
    var indices = std.ArrayList(usize).empty;
    errdefer indices.deinit(allocator);

    var byte_index: usize = 0;
    while (byte_index < s.len) {
        const rune_len = std.unicode.utf8ByteSequenceLength(s[byte_index]) catch 1;
        const rune_value = std.unicode.utf8Decode(s[byte_index .. byte_index + rune_len]) catch s[byte_index];

        if (byte_index == 0) {
            try indices.append(allocator, byte_index);
            byte_index += rune_len;
            continue;
        }

        if (rune_value == '_') {
            if (byte_index + 1 < s.len and s[byte_index + 1] != '_') {
                try indices.append(allocator, byte_index + 1);
            }
            byte_index += rune_len;
            continue;
        }

        if (isUpper(rune_value)) {
            // Find last rune
            var last_rune: u21 = 0;
            var i = byte_index;
            while (i > 0) {
                i -= 1;
                if (std.unicode.utf8ByteSequenceLength(s[i])) |_| {
                    last_rune = std.unicode.utf8Decode(s[i..byte_index]) catch 0;
                    break;
                } else |_| {}
            }

            // Find next rune
            var next_rune: u21 = 0;
            if (byte_index + rune_len < s.len) {
                const next_len = std.unicode.utf8ByteSequenceLength(s[byte_index + rune_len]) catch 1;
                if (byte_index + rune_len + next_len <= s.len) {
                    next_rune = std.unicode.utf8Decode(s[byte_index + rune_len .. byte_index + rune_len + next_len]) catch s[byte_index + rune_len];
                }
            }

            if (isLower(last_rune) or (byte_index + 1 < s.len and isLower(next_rune))) {
                try indices.append(allocator, byte_index);
            }
        }

        byte_index += rune_len;
    }
    return indices.toOwnedSlice(allocator);
}

fn isUpper(c: u21) bool {
    return c >= 'A' and c <= 'Z';
}

fn isLower(c: u21) bool {
    return c >= 'a' and c <= 'z';
}

pub fn getPackageNamesInNodeModules(allocator: std.mem.Allocator, nodeModulesDir: []const u8, fs: *vfs.FS) !collections.Set([]const u8) {
    _ = allocator;
    _ = nodeModulesDir;
    _ = fs;
    @panic("TODO: getPackageNamesInNodeModules");
}

pub fn getDefaultLikeExportNameFromDeclaration(ast: *ast_pkg.Ast, symbol: ast_gen.SymbolIndex) []const u8 {
    _ = ast;
    _ = symbol;
    @panic("TODO: getDefaultLikeExportNameFromDeclaration");
}

pub fn getResolvedPackageNames(ctx: anytype, program: *compiler.Program) collections.Set([]const u8) {
    _ = ctx;
    _ = program;
    @panic("TODO: getResolvedPackageNames");
}

pub fn addProjectReferenceOutputMappings(program: *compiler.Program, result: *std.StringHashMap([]const u8)) void {
    _ = program;
    _ = result;
    @panic("TODO: addProjectReferenceOutputMappings");
}

pub fn createCheckerPool(allocator: std.mem.Allocator, program: *checker.Program) !struct {
    getChecker: *const fn() *checker.Checker,
    closePool: *const fn() void,
    getCreatedCount: *const fn() i32,
} {
    _ = allocator;
    _ = program;
    @panic("TODO: createCheckerPool");
}

pub fn addPackageJsonDependencies(contents: *packagejson.PackageJson, deps: *collections.Set([]const u8)) void {
    _ = contents;
    _ = deps;
    @panic("TODO: addPackageJsonDependencies");
}

pub const PackageRealpathFuncs = struct {
    toRealpath: *const fn([]const u8) []const u8,
    toSymlink: *const fn([]const u8) []const u8,
};

pub fn getPackageRealpathFuncs(fs: *vfs.FS, packageDir: []const u8) PackageRealpathFuncs {
    _ = fs;
    _ = packageDir;
    @panic("TODO: getPackageRealpathFuncs");
}

pub const ResolutionHost = struct {
    fs: *vfs.FS,
    currentDirectory: []const u8,
    
    pub fn getCurrentDirectory(self: *ResolutionHost) []const u8 {
        return self.currentDirectory;
    }
    
    pub fn getFS(self: *ResolutionHost) *vfs.FS {
        return self.fs;
    }
};

pub fn getModuleResolver(host: anytype, realpathFn: *const fn([]const u8) []const u8, opts: module.ResolverOptions) *module.Resolver {
    _ = host;
    _ = realpathFn;
    _ = opts;
    @panic("TODO: getModuleResolver");
}
