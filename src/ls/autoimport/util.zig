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
    return null;
}

pub fn getModuleIDAndFileNameOfModuleSymbol(ast: *ast_pkg.Ast, symbol: ast_gen.SymbolIndex) struct { module_id: ModuleID, file_name: []const u8 } {
    _ = ast;
    _ = symbol;
    return .{ .module_id = "", .file_name = "" };
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
    _ = nodeModulesDir;
    _ = fs;
    return collections.Set([]const u8).init(allocator);
}

pub fn getDefaultLikeExportNameFromDeclaration(ast: *ast_pkg.Ast, symbol: ast_gen.SymbolIndex) []const u8 {
    _ = ast;
    _ = symbol;
    return "";
}

pub fn getResolvedPackageNames(ctx: anytype, program: *compiler.Program) collections.Set([]const u8) {
    _ = ctx;
    _ = program;
    return undefined; // We cannot easily mock a non-error Set without an allocator
}

pub fn addProjectReferenceOutputMappings(program: *compiler.Program, result: *std.StringHashMap([]const u8)) void {
    _ = program;
    _ = result;
}

pub const CheckerPool = struct {
    allocator: std.mem.Allocator,
    program: *checker.Program,
    max_size: i32,
    created: std.atomic.Value(i32),
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,
    pool: std.ArrayListUnmanaged(*checker.Checker),

    pub fn init(allocator: std.mem.Allocator, program: *checker.Program) !*CheckerPool {
        const self = try allocator.create(CheckerPool);
        const max_size: i32 = @intCast(std.Thread.getCpuCount() catch 1);
        self.* = .{
            .allocator = allocator,
            .program = program,
            .max_size = max_size,
            .created = std.atomic.Value(i32).init(0),
            .mutex = .{},
            .condition = .{},
            .pool = .empty,
        };
        try self.pool.ensureTotalCapacity(allocator, @intCast(max_size));
        return self;
    }

    pub fn deinit(self: *CheckerPool) void {
        self.pool.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub const CheckerAndRelease = struct {
        checker: *checker.Checker,
        release: *const fn (*CheckerPool, *checker.Checker) void,
    };

    pub fn getChecker(self: *CheckerPool) !CheckerAndRelease {
        self.mutex.lock();
        if (self.pool.items.len > 0) {
            const ch = self.pool.pop();
            self.mutex.unlock();
            return .{ .checker = ch, .release = releaseChecker };
        }
        self.mutex.unlock();

        while (true) {
            const current = self.created.load(.monotonic);
            if (current >= self.max_size) {
                self.mutex.lock();
                defer self.mutex.unlock();
                while (self.pool.items.len == 0) {
                    self.condition.wait(&self.mutex);
                }
                const ch = self.pool.pop();
                return .{ .checker = ch, .release = releaseChecker };
            }
            if (self.created.cmpxchgStrong(current, current + 1, .monotonic, .monotonic) == null) {
                const ch = try checker.Checker.init(self.allocator, self.program, null);
                return .{ .checker = ch, .release = releaseChecker };
            }
        }
    }

    fn releaseChecker(self: *CheckerPool, ch: *checker.Checker) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.pool.appendAssumeCapacity(ch);
        self.condition.signal();
    }

    pub fn getCreatedCount(self: *CheckerPool) i32 {
        return self.created.load(.monotonic);
    }
};

pub fn createCheckerPool(allocator: std.mem.Allocator, program: *checker.Program) !*CheckerPool {
    return CheckerPool.init(allocator, program);
}

pub fn addPackageJsonDependencies(contents: *packagejson.PackageJson, deps: *collections.Set([]const u8)) void {
    _ = contents;
    _ = deps;
}

pub const PackageRealpathFuncs = struct {
    toRealpath: *const fn ([]const u8) []const u8,
    toSymlink: *const fn ([]const u8) []const u8,
};

pub fn getPackageRealpathFuncs(fs: *vfs.FS, packageDir: []const u8) PackageRealpathFuncs {
    _ = fs;
    _ = packageDir;
    return undefined;
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

pub fn getModuleResolver(host: anytype, realpathFn: *const fn ([]const u8) []const u8, opts: module.ResolverOptions) *module.Resolver {
    _ = host;
    _ = realpathFn;
    _ = opts;
    return undefined;
}
